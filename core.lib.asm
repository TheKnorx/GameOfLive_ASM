; This library contains functions and variables used by this project.
; Most functions are own implementations/replacments for glibc functions.
; The ultimate goal of this library is to replace the glibc usage across this project entirely

; Syscall register assignment: 
; rdi - rsi - rdx - r10 - r8 - r9 - rax = Syscall-number

; Functions in this file with have the following preceeding commentary layout:
; Replacement-function for:
; <glibc function signature>
; (Optional) --> needed libcalls: <names of need functions from this library> 
; (Optional) --> needed syscalls: <names of needed linux kernel syscalls>
; (Optional) --> needed asm-inst: <needed assembly instructions>
; (Optional) >>> <kernel syscall signatures> or <glibc function signatures>
; (Optional) <<< <additional implementation notes - behavior, special cases, ...>

; NOTE: all types (+ their extensions) in all signatures of the glibc functions
; are all seen as 64-bit/8-bytes in size here --> they take up one r* register each
; This is for protability purposes


section .bss
    SYS_ERRNO:          resd    0x01    ; custome errno status variable
    ; field for saving the pointer of the global stdio buffer --> allocated by _start routine
    ; As no multithreading is done here, we only implement one big buffer for every stdio operation 
    global STDIO_BUFFER_PTR
    STDIO_BUFFER_PTR:   resq    0x01
    STDIO_BUFFER_INDEX: resw    0x01    ; for saving the current length index-form of the buffer --> for knowing when to flush
section .data
    global  STDIO_BUFFER_SIZE
    STDIO_BUFFER_SIZE:  equ     0x0200  ; allocate 512 bytes for this stdio buffer  
section .text

%include "core.lib.inc"

; Macro for setting the sys_errno variable with the negated value in rax
%macro SET_ERRNO 0
    neg     eax             ; negate rax
    mov     [SYS_ERRNO], eax; store the value in eax into sys_errno
%endmacro

; Macro for dertermining which register holds the value of the format specifier
%macro DETERMIN_SPECIFIER_REGISTER 0
    ; what follows now can only be described as the most anoying thing every written
    cmp     rbx, 0x00 
    je      %%use_rdx
    cmp     rbx, 0x01
    je      %%use_rcx
    cmp     rbx, 0x02
    je      %%use_r8
    cmp     rbx, 0x03
    je      %%use_r9
    %%use_rdx:  
        mov     rax, r14
        jmp     %%end
    %%use_rcx:  
        mov     rax, r15 
        jmp     %%end
    %%use_r8:   
        mov     rax, [rbp-8*2]
        jmp     %%end
    %%use_r9:   
        mov     rax, [rbp-8*2]
        jmp     %%end
    %%end:
%endmacro

; Macro for preserving and restoring all registers for the sys_printf function; 
%macro PRESERVE_REGISTERS 0
    mov     r12, rdi    ; preserve rdi from function call
    mov     r13, rsi    ; preserve rsi from function call
    mov     r14, rdx    ; preserve rdx from function call
    mov     r15, r10    ; preserve r10 from function call
    push    r8          ; preserve r8  from function call
    push    r9          ; preserve r9  from function call
%endmacro
%macro RESTORE_REGISTERS 0
    mov     rdi, r12    ; restore rdi 
    mov     rsi, r13    ; restore rsi
    mov     rdx, r14    ; restore rdx 
    mov     r10, r15    ; restore r10
    pop     r8          ; restore r8
    pop     r9          ; restore r9
%endmacro


; for now, this procedure acts as a bridge between glibc and core.lib
; in the future, this routine should replace the _start routine of glibc 
global main
extern _main
main:  ; actually _start
    .align_stack: ENTER       ; align the stack to mod 16

    ; we have to preserve the rdi and rsi registers cause we execute after actuall _start
    push    rdi
    push    rsi

    .init_process:  ; init the process with all its buffers and stuff idk
        ; first initialize the stdio buffer with sys_malloc
        ; void *malloc(size_t size);
        mov     rdi, STDIO_BUFFER_SIZE  ; parameter size
        call    sys_malloc              ; allocate memory for stdio buffer
        test    rax, rax                ; check if allocation was successful
        jz      .exit_on_error          ; if it was not, terminate the program
        mov     [STDIO_BUFFER_PTR], rax ; else move pointer to allocated memory into ptr storage variable

    .run_process:
        ; restore cmd args register for main function call
        pop     rsi
        pop     rdi 

        nop
        call    _main                       ; call main function
        nop

    .end_process:  ; end the process by cleaning up of program (freeing buffers etc...)
        ; void free(void *_Nullable ptr);
        mov     rdi, [STDIO_BUFFER_PTR] ; parameter ptr
        call    sys_free                ; free the stdio buffer
        jmp     .exit_normal            ; we assume that if we came here the program ran successfully - so we exit as usual (with status 0)

    .exit_on_error: 
        mov     rax, -1     ; parameter status move status code into rdi
        call    sys_exit    ; force exit of program
    .exit_normal: 
        ; exit the program with status code 0
        ; [[noreturn]] void _exit(int status);
        xor     rdi, rdi        ; parameter status - 0
        call    sys_exit        ; exit the program
        hlt                     ; execution shouldnt reach this point


; Replacement-function for:
; int fprintf(FILE *restrict stream,
;             const char *restrict format, ...)
; <<< this function lays the foundation of all *printf functions
; <<< BUT we interpret the FILE* stream as a file-descriptor, not as a FILE object --> therefore we pass a fd here not a FILE*! 
; <<< We only support the following format specifier: %d and %s
; <<< Additionally we do not support masking of format specifiers like so: "%%", cause I am too lazy to implement this ;)
; <<< And we also dont support more than 4 format arguments :/ - rdx, rcx, r8, r9; cause this is not needed by the program itself
global sys_fprintf
sys_fprintf: 
    .enter:  ; Special prolog to preserver the last possible format string parameters using a fixed access point
        push    rbp
        mov     rbp, rsp
        push    r8          ; push/save r8 function argument onto stack --> access through [rbp-8*1]
        push    r9          ; push/save r9 function argument onto stack --> access through [rbp-8*2]
        and     rsp, -16

    push    r12             ; make r12 available for storage
    push    r13             ; make r13 available for storage
    push    r15             ; make r14 available for storage
    push    r15             ; make r15 available for storage
    push    rbx             ; make rbx available for stoarge
    mov     r12, rdi        ; preserve rdi from function call
    mov     r13, rsi        ; preserve rsi from function call
    mov     r14, rdx        ; preserve rdx from function call
    mov     r15, rcx        ; preserve rcx from function call
    xor     rbx, rbx        ; use rbx as indicator which format specifier register to use
    ; from this point on, we use the callee saved registers for accessing the function arguments 

    ; now loop through the chars of the string, print them out or handle a format specifier if we encounter one
    xor     rcx, rcx        ; use rcx as an index 
    .for: 
        mov     al, [r13+rcx]; move current char at index position into al
        test    al, al      ; check if al is empty = null terminator
        jz      .return     ; if its empty, return from this function
        ; else continue loop
        cmp     al, '%'     ; check if al marks the beginning of a format specifier
        jne     .char       ; if it does not mark the beginning of a specifier, just output the char
        ; else fall through to handling the specifier
        .specifier: 
            ; determin which register holds the value of this format specifier
            DETERMIN_SPECIFIER_REGISTER ; value is now in rax
            add     rbx, 0x01       ; increment format specifier register counter 
            add     rcx, 0x01       ; increment index --> set index to the specifier
            push    rcx             ; save rcx onto stack
            push    rax             ; save rax onto stack

            mov     al, [r13+rcx]   ; determin the actual kind of value specified by the specifier - eigther %d or %s
            cmp     al, 's'         ; check if its a string specifier
            jne     .digit          ; if its %d, then handle the digit
            ; else fall through to .string

            .string:  ; if the specifier == %s, we call this function recursivly and just append the string to the buffer this way
                pop     rax         ; restore format specifier parmameter value

                ; int fprintf(FILE *restrict stream, const char *restrict format, ...)
                mov     rdi, r12    ; parameter stream
                mov     rsi, rax    ; parameter format - in our case it doesnt contain any format specifier, just the string itself
                call    sys_fprintf ; make recursive call - we ignore the return value

                jmp     .end_specifier  ; jump to end of section 
            .digit:  ; if the specifier == %d, we call 
                ; char* itoa(char str[restrict .size], size_t size, int number)
                mov     rdi, 20     ; size of memory for a buffer - 20 is the max amount of digits in a 64 bit register
                call    sys_malloc  ; allocate buffer
                pop     rdx         ; parameter number - pop format specifier parmameter value into rdx 
                push    rax         ; store pointer to buffer in stack    
                mov     rdi, rax    ; parameter str[restrict .size]
                mov     rsi, 20     ; parameter size
                call    sys_itoa    ; convert int to ascii --> rax = modified ptr to buffer

                ; now we also do a recursive function call to put the created string into the stdio buffer
                ; int fprintf(FILE *restrict stream, const char *restrict format, ...)
                mov     rdi, r12    ; parameter stream - restore saved rdi from r12
                mov     rsi, rax    ; parameter format - created by sys_itoa - just a string without format parameters
                call    sys_fprintf ; make recursive call - we ignore the return value

                ; the string was put into the buffer (and possibly flushed) - now free the allocated buffer
                ; void free(void *_Nullable ptr);
                pop     rdi         ; parameter ptr - pop pushed rax/pointer from before into rdi
                call    sys_free    ; free the memory

                ; fall through to .end_specifier - end of section 
        .end_specifier: 
            pop     rcx             ; restore rcx counter variable
            jmp     .continue_loop  ; and continue the loop

        .char:  ; pass the char to fputc and fputc handles it from there
            ; int fputc(int c, FILE *stream);
            push    rcx             ; save rcx counter variable
            xor     rdi, rdi        ; clear rdi
            mov     dil, [r13+rcx]  ; parameter c - put the char from the string into 
            mov     rsi, r13        ; parameter stram - saved in r13
            call    sys_fputc       ; pass char along to fputc
            pop     rcx             ; restore rcx counter variable
            ; fall through to .continue_loop

        .continue_loop: 
            add     rcx, 0x01       ; rcx++ - index++
            jmp     .for            ; repeat the loop

    .return: 
        pop     rbx         ; restore pushed rbx
        pop     r15         ; restore pushed r15
        pop     r14         ; restore pushed r14
        pop     r13         ; restore pushed r13
        pop     r12         ; restore pushed r12
        mov     rax, rcx    ; move index into rax for returning
        LEAVE               ; we use the standard epilog so the pushed values from earlier simply get deleted
        ret 


; Replacement-function for: 
; int printf(const char *restrict format, ...);
; needed libcalls: sys_fprintf
; int fprintf(FILE *restrict stream, const char *restrict format, ...)
; <<< sys_fprintf is restricted in the amount of arguments it can take as format parameters
;     therefore printf is also restricted to that amount!
global sys_printf
sys_printf:
    ; no prolog or epilog needed cause we are just a simple bridge between user and sys_fprintf to stdout
    ; now move all the function arguments one to the left acording to the order in System V ABI passing convention
    ; except r9, whoms value just gets overwritten
    mov     r9, r8
    mov     r8, rcx
    mov     rcx, rdx
    mov     rdx, rsi 
    mov     rsi, rdi
    mov     rdi, STDOUT     ; parameter stream = stdout
    call    sys_fprintf     ; print to stdout --> rax = amount of chars printed
    ret                     ; return from function with rax

sys_perror: hlt


; Replacement-function for: 
; int fputc(int c, FILE *stream)
; --> needed libcalls: sys_fflush
; >>> int fflush(FILE *_Nullable stream);
; <<< as we dont test if the write would succeed everytime, EOF as error indicator is only returned when flushing the buffer - not before!
; <<< we dont really accept a FILE* object as second parameter (for fputc) but rather just a file-descriptor
global sys_fputc
sys_fputc: 
    .enter: ENTER

    push    rdi                 ; save parameter c onto stack for later usage
    jmp     .write_buffer       ; skip the following section

    .flush_buffer:  ; if we came here - sys_fflush guarantees that the index is 0, so we dont jmp here again --> if no error occured!
        mov     rdi, rsi        ; parameter stream - file descriptor to write to
        call    sys_fflush      ; flush the stdio buffer
        test    rax, rax        ; check if rax == 0
        jz      .write_buffer   ; if rax == 0: jump to write_buffer section
        ; else pop pushed rdi and jmp to error section
        add     rsp, 0x08       ; remove pushed rdi without poping it
        jmp     .error          ; if rax == 0: return from function as usual 

    .write_buffer:
        cmp     word [STDIO_BUFFER_INDEX], STDIO_BUFFER_SIZE    ; check if len < sizeof buffer
        jge     .flush_buffer           ; if len >= sizeof buffer: flush buffer but then fall through to this section again 
        ; else continue writing into the buffer 

        mov     dx, [STDIO_BUFFER_INDEX]; move into 16-bit register current index of buffer 
        movzx   rdx, dx                 ; migrate dx into rdx
        mov     rax, [STDIO_BUFFER_PTR] ; move pointer to stdio buffer into rax
        pop     rdi                     ; move into rdi the previously saved parameter c
        mov     [rax+rdx], dil          ; move parameter c (cast to char) into buffer
        add     word [STDIO_BUFFER_INDEX], 0x01; len+1 to make it represent the current length of the buffer - usage in fflush!
        ; return from function

    .normal: 
        xor     rax, rax        ; clear rax
        ; moving the parameter c from dil into rax is a bit risky - it works technically but its far from pretty engeneering :)
        mov     al, dil         ; move parameter c from rdx(/dil) into al (cast to unsigned char) for returning
    .error:  ; skip setting rax as rax is already set with the error from sys_fflush
    .return: 
        LEAVE
        ret

; Replacement-function for: 
; int fflush(FILE *_Nullable stream);
; --> needed syscalls: write
; --> needed libcalls: memset
; >>> ssize_t write(int fildes, const void *buf, size_t nbyte);
; >>> void *memset(void s[.n], int c, size_t n);
; <<< as we always use [STDIO_BUFFER_PTR] as the buf, and STDIO_BUFFER_LEN as nbyte,
; <<< we only need the file-descriptor passed to write - not like glibc where those infos are extracted out of the FILE* stream object
; <<< consequently the FILE* stream object is only a file-descriptor, not a real FILE* object like in glibc
; <<< we also consider the not-writing of all bytes in the buffer a hard error and return with EOF!
; <<< if parameter stream == 0: stream = stdout as default
global sys_fflush
sys_fflush:
    .enter: ENTER

    cmp     word [STDIO_BUFFER_INDEX], 0x00  ; check if parameter nbyte == 0
    je      .normal         ; if nbyte == 0, then just return from this function
    ; else proceed with writing

    test    rdi, rdi        ; check if rdi is empty --> NULL
    jnz     .check_fd_end   ; if its non-zero, just continue with execution
    mov     rdi, STDOUT     ; else use stdout as fd
    .check_fd_end:  ; label for skipping the previous instruction
    mov     rax, SYS_WRITE  ; move number of syscall into rax
    mov     rsi, [STDIO_BUFFER_PTR] ; parameter buf
    mov     dx, [STDIO_BUFFER_INDEX]; parameter nbyte
    movzx   rdx, dx         ; migrate dx into rdx
    syscall                 ; write buffer into location of file-descriptor
    test    rax, rax        ; check if rax is a negative number
    js      .error          ; if rax < 0: set errno and return from function
    cmp     rax, rdx        ; else check if bytes written == nbyte
    jne     .error          ; if they are not equal, set errno and return from function
    ; else reset all variables and stuff
    
    mov     rdi, [STDIO_BUFFER_PTR] ; parameter s[.n]
    mov     rsi, 0x00               ; parameter c - empty byte
    mov     dx, [STDIO_BUFFER_INDEX]; parameter n - just zero out the part of the buffer that we actually used
    movzx   rdx, dx                 ; migrate dx into rdx
    call    sys_memset              ; clear the buffer - ignore the return value 
    mov     word [STDIO_BUFFER_INDEX], 0x00  ; zero out len variable
    jmp     .normal                 ; return from function

    .error: 
        SET_ERRNO                   ; check syscall for errors and set sys_errno accordingly
        mov     rax, EOF            ; move EOF constant into rax
        jmp     .return             ; return from function
    .normal: xor    rax, rax        ; clear rax as we return with 0 on success
    .return:
        LEAVE
        ret


; Replacement-function for: 
; FILE *fopen(const char *restrict pathname, const char *restrict mode);
; --> needed syscalls: open
; >>> int open(const char *path, int oflag, ...);  - variadic argument mode
; <<< we DO NOT return a ptr to a FILE-object, instead we return a file-descriptor!
; <<< also we do not support variadic function arguments, just path and oflag
; <<< and we also ONLY support read (r) and write (w) as mode parameter
global sys_fopen
sys_fopen:
    .enter: ENTER

    ; determin which mode was passed to the function in parameter mode
    cmp     byte [rsi], 'w' ; check whether the mode is read or write using the first char in the mode string
    je      .write          ; mode == write
    jne     .read           ; move == read
    .write:  ; if we write, we automatically do a create if it does not exist and a trunciate of the content if it does
        mov     rsi, O_WRONLY | O_CREAT | O_TRUNC   ; parameter oflag  - write only from parameter mode
        mov     rdx, 0x1A4  ; also we have to set the mode to 0644
        jmp     .check_mode_end ; skip .read section
    .read: 
        mov     rsi, O_RDONLY   ; parameter oflag  - read only from parameter mode
        ; and fall through
    .check_mode_end:  ; label for skipping the above labels and continuing execution here

    mov     rax, SYS_OPEN   ; move syscall number into rax
    ; rdi - parameter path - already in rdi from parameter pathname
    syscall                 ; execute open syscall --> rax = file descriptor
    test    rax, rax        ; check if rax is a negative number
    js      .error          ; if rax < 0: set errno and return from function
    jmp     .return         ; else just return from this function
    .error: 
        SET_ERRNO
        mov     rax, -1     ; return -1 on failiure
    .return: 
        LEAVE
        ret


; Replacement-function for: 
; void *malloc(size_t size);
; --> needed syscalls: mmap
; >>> void *mmap(void addr[.length], size_t length, int prot, int flags,
;                int fd, off_t offset);
; <<< if size == 0: return invalid pointer NULL
global sys_malloc
sys_malloc: 
    .enter: ENTER

    cmp     rdi, 0x00   ; check if parameter size_t size is 0
    je      .invalid    ; if its 0, then return NULL
    ; else allocate the memory

    mov     rax, SYS_MMAP ; move syscall number into rax
    mov     rsi, rdi    ; parameter length = size_t size in rdi
    add     rsi, MEM_HEAD_LEN  ; add to length additional bytes for header
    push    rsi         ; push length to stack for later use - stack alignment doesnt matter now
    xor     rdi, rdi    ; parameter addr[.length] = NULL
    mov     rdx, PROT_READ | PROT_WRITE ; parameter prot
    mov     r10, MAP_PRIVATE | MAP_ANONYMOUS ; parameter flags
    mov     r8, -1      ; parameter fd = -1
    xor     r9, r9      ; parameter offset = 0
    syscall             ; Execute mmap --> rax = addr of allocated memory or MAP_FAILED

    test     rax, rax       ; check if rax is invalid / mmap failed 
    js      .error          ; if its invalid meaning negative, set rax to NULL and exit this function 
    ; else write allocation information into the memory block
    pop     rsi             ; get length from stack
    mov     [rax], rsi      ; move into the memory region the size of it that we pushed onto stack before
    lea     rax, [rax+MEM_HEAD_LEN]  ; add len of header to the pointer -> rax now points to usable memory
    jmp     .return          ; return from function

    .error:
        SET_ERRNO           ; set sys_errno with the value in rax (-eax)
        pop     rax         ; clear the pushed length
        ; also fall through to invalid section
    .invalid: 
        mov     rax, NULL   ; move NULL into rax
    .return:
        LEAVE
        ret


; Replacement-function for: 
; void *calloc(size_t nmemb, size_t size);
; --> needed libcalls: sys_malloc, sys_memset
; >>> void *malloc(size_t size);
; >>> void *memset(void s[.n], int c, size_t n);
; <<< if nmemb * size doesnt fit rax when multiplying, we ignore it and use rax anyways
global sys_calloc
sys_calloc: 
    .enter: ENTER

    mov     rax, rdi    ; move factor into rax for MUL
    xor     rdx, rdx    ; clear rdx so it doesnt mess with MUL
    mul     rsi         ; rsi*rax = size_t nmemb * size_t size
    push    rax         ; push rax to stack for later use
    mov     rdi, rax    ; parameter size = calculated memory size
    call    sys_malloc  ; allocate memory with sys_malloc --> ptr in rax

    test     rax, rax   ; compare if rax contains a valid pointer
    jz      .invalid    ; if it does not, immediately exit the function
    ; else zero out the memory
    mov     rdi, rax    ; parameter s[.n] = move pointer to memory into rdi
    mov     rsi, 0x00   ; parameter c = 0x00 (empty byte)
    pop     rdx         ; parameter n = size of memory pushed to stack from earlier
    call    sys_memset  ; set memory at adress in rdi to 0x00
    jmp     .return     ; return from function

    .invalid: 
        add     rsp, 0x08  ; remove pushed rax without poping it
    .return: 
        LEAVE
        ret


; Replacement-function for: 
; void *realloc(void *_Nullable ptr, size_t size);
; --> needed syscalls: mremap
; >>> void *mremap(void old_address[.old_size], size_t old_size,
;              size_t new_size, int flags, ... /* void *new_address */);
; <<< On error, we return the old pointer, but also set an errror-code (that follow the mremap convention for better debugging)
global sys_realloc
sys_realloc: 
    .enter: ENTER

    test    rdi, rdi        ; check if ptr is NULL or not
    jnz     .do_realloc     ; if its not NULL, proceed with a normal realloc
    ; else do a malloc like its specified in the standard: if ptr == NULL, then its like a malloc(size) call
    .do_malloc:
        mov     rdi, rsi    ; parameter size - discard NULL-ptr in rdi
        call    sys_malloc  ; allocate memory using sys_malloc --> rax = ptr to memory or NULL on error
        jmp     .return     ; return from function
    .do_realloc:
    push    rdi             ; save parameter ptr to stack for potential later use

    mov     rax, SYS_MREMAP ; move syscall number into rax
    lea     rdi, [rdi-MEM_HEAD_LEN] ; parameter old_address[.old_size] from parameter ptr in rdi (- len of header)
    lea     rdx, [rsi+MEM_HEAD_LEN] ; parameter new_size from parameter size in rsi (+ len of header)
    push    rdx             ; save parameter new_size in stack for later use
    mov     rsi, [rdi]      ; parameter old_size - stored in head of memory region
    mov     r10, MREMAP_MAYMOVE     ; parameter int flags
    syscall                 ; execute mremap --> rax = new address or neg number on error
    test    rax, rax        ; check if rax is a negativ number, meaning if we got an error
    js     .invalid         ; if the syscall returned an error, jmp to .invalid

    ; else add the size of the new memory region into the memory region
    pop     rsi             ; get new_size from stack
    mov     [rax], rsi      ; write new_size into memory header
    lea     rax, [rax+MEM_HEAD_LEN] ; move into rax the user-pointer
    add     rsp, 0x08       ; remove pushed parameter ptr from stack without poping it
    jmp     .return         ; return from function

    .invalid:  ; set rax to previous pointer to old memory
        SET_ERRNO           ; set sys_errno with the value in rax (-eax)
        pop     rax         ; clear the new_size from stack 
        pop     rax         ; get pushed old address from stack and save into rax
    .return: 
        LEAVE
        ret


; Replacement-function for: 
; void free(void *_Nullable ptr);
; --> needed syscalls: munmap
; >>> int munmap(void addr[.length], size_t length)
; <<< if munmap returned with an error, we also return the error here, but dont really care about it --> just in case
global sys_free
sys_free:
    ; no prolog or epilod needed

    cmp     rdi, NULL       ; compare if parameter ptr is 0
    je      .return          ; if its NULL, we do nothing
    ; else we free the memory

    mov     rax, SYS_MUNMAP ; move syscall number into rax
    lea     rdi, [rdi-MEM_HEAD_LEN]  ; parameter ptr - subtract the header-area from memory pointer
    mov     rsi, [rdi]      ; parameter length - is stored in the first 8 byte of the memory
    syscall                 ; free the memory pointed to by parameter ptr --> rax = success/error
    test    rax, rax        ; check if munmap failed
    js      .invalid        ; if there was an error, set SYS_ERRNO
    jmp     .return         ; else just leave and return from this function

    .invalid: 
        SET_ERRNO           ; set sys_errno with the value in rax (-eax)
    .return: ret
    
    
; Replacement-function for: 
; size_t strlen(const char *s);
global sys_strlen
sys_strlen: 
    ; no prolog or epilog needed

    xor     rax, rax        ; clear rax and use it as an index and for the length storage
    .for: 
        cmp     byte [rdi+rax], 0x00 ; compare current char to null-terminator
        je      .return     ; if it matches, return from function
        inc     rax         ; increment length
        jmp     .for        ; continue the loop

    sub     rax, 0x01       ; we have to exclude the null terminator
    .return: ret

; Replacement-function for:
; void *memset(void s[.n], int c, size_t n);
; --> needed asm-inst: rep stosb
global sys_memset
sys_memset:
    ; no prolog or epilog needed 

    ; rdi - parameter s[.n] - rdi already contains destination memory address
    mov     r9, rdi     ; save s[.n] into r9 for later use
    mov     rcx, rdx    ; move parameter n into counter register
    mov     al, sil     ; move parameter c into al
    cld                 ; clear direction flag so that we overwrite upwards from the base memory address
    rep stosb           ; overwrite whole allocated memory with char in al

    mov     rax, r9     ; move r9/s[.n] into rax for returning
    .return: ret


; Replacement-function for:
; void *memcpy(void dest[restrict .n], const void src[restrict .n],
;              size_t n);
; --> needed asm-inst: rep movsb
global sys_memcpy
sys_memcpy:
    ; no prolog or epilog needed 

    ; rdi - parameter dest[restrict .n] - rdi already contains destination memory address
    ; rsi - parameter src[restrict .n] - rsi already contains the source memory address
    mov     r9, rdi     ; save s[.n] into r9 for later use
    mov     rcx, rdx    ; move parameter n into counter register
    cld                 ; clear direction flag so that we overwrite upwards from the base memory address
    rep movsb           ; overwrite whole allocated memory with char in al

    mov     rax, r9     ; move r9/s[.n] into rax for returning
    .return: ret 

; Replacement function for:
; int atoi(const char *nptr);
global sys_atoi
sys_atoi:  
    .enter: ENTER

    ; init registers needed for convertion
    mov     rsi, rdi       ; copy ascii string into source register
    xor     rdi, rdi       ; clear rdi & use it for temporary storage of current extracted ascii char
    xor     rax, rax       ; clear rax for storing/returning the extracted number
    xor     rcx, rcx       ; clear counter registerfor indexing the string
    mov     r8, 0xA        ; factor for MUL to make space for next number
    .for:  ; loop through every ascii char
        mov    dil, [rsi+rcx]  ; move current byte to be converted into 8-bit part of rdx
        cmp    dil, 0x00       ; if the current byte is a null terminator
        je     .return         ; we are finished and return from this function
        ; else continue converting the ascii

        mul    r8              ; multiply rax by 10 so to make space for another number
        sub    dil, 0x30       ; sub 32 from ascii to convert it to int
        add    rax, rdi        ; add the int to rax
        inc    rcx             ; counter++
        jmp    .for            ; continue the loop

    .return:  ; return from function --> number in rax 
        LEAVE
        ret


; Own implementation of:
; char* itoa(char str[restrict .size], size_t size, int number)
; <<< str is a pointer to a buffer with a fixed length of size; parameter number is the number to be converted into ascii
; <<< this function does append the null terminator to the buffer --> so buffer has to be +1 for size
; <<< returns the amount of ints converted to ascii chars
; <<< this implementation implements itoa behavior with a mix of snprintf behavior
global sys_itoa
sys_itoa:
    ; no prolog or epilog needed
    ; we convert an integer into a ascii number by dividing the int by 10, adding to the rest 0x20 to make it ascii and appending it to a buffer
    ; as we convert the lowest digits first we have to store them backwards into the buffer (big endian)!
    ; buffer is already in rdi

    mov     r9, 0x0A            ; move into rcx the divisor - 10d
    mov     rcx, rsi            ; move size of buffer into index register
    sub     rcx, 0x01           ; decrement buffer size to make it a true array index len
    mov     byte [rdi+rcx], 0x00; move null terminator at end of buffer
    sub     rcx, 0x01           ; decrement buffer index
    mov     rax, rdx            ; move the int to be converted into rax for dividing
    .next:  ; convert one digit at the time
        test    rax, rax        ; check if rax is empty
        jz      .return         ; if its empty, we converted all digits, so we return from this function
        ; else we continue converting the next digit
        xor     rdx, rdx        ; clear rdx so it doesnt mess with the DIV
        div     r9              ; divide int in rax / 10 --> rest in rdx

        add     dl, 0x30        ; add to the rest 30 to make it a ascii number
        mov     byte[rdi+rcx], dl; write the converted ascii number to the buffer
        sub     rcx, 0x01       ; rcx-- or index--
        jmp     .next           ; convert the next number

    .return: 
        mov     rax, rdi        ; move pointer to buffer into rax
        ; now add the empty space at the beginning of the buffer from the pointer, so it points directly to the value
        add     rcx, 0x01       ; add one to index to compensate for ADD at end of loop
        lea     rax, [rax+rcx]  ; move pointer forward to value
        ret                     ; return with the pointer pointing the the start of the value



; Replacement function for:
; [[noreturn]] void _exit(int status); and [[noreturn]] void _Exit(int status);
; --> needed syscalls: exit
global sys_exit, sys_EXIT
sys_exit: 
    ; no prolog or epilog needed 
    mov     rax, SYS_EXIT   ; move syscall number into rax
    ; parameter status already in rdi
    syscall                 ; do a hard exit on program - without cleanup, without anything!
    hlt                     ; we should never get to this point
sys_EXIT: 
    jmp     sys_exit        ; we can literally jmp to the _exit implementation as we will never return from it anyways
