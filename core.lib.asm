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
    FORMAT_SPECIFIER_BEGIN: equ '%'     ; begin of a format specifyer followed by a character
    FORMAT_SPECIFIER_STRING:equ 's'     ; %s
    FORMAT_SPECIFIER_DIGET: equ 'd'     ; %d
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
    je      %%use_r10
    cmp     rbx, 0x02
    je      %%use_r8
    cmp     rbx, 0x03
    je      %%use_r9
    %%use_rdx:  
        mov     rax, rdx
        jmp     %%end
    %%use_r10:  
        mov     rax, r10 
        jmp     %%end
    %%use_r8:   
        mov     rax, r8
        jmp     %%end
    %%use_r9:   
        mov     rax, r9
        jmp     %%end
    %%end:
%endmacro

; glibc functions that are needed in the meantime to support the bridge between glibc and core.lib
extern fileno


; this procedure acts as a bridge between glibc and core.lib for now
; in the future, this routine should replace the _start routine of glibc 
_DEPRECATED_start_core_lib:
    .enter: ENTER
    ; we have to preserve the rdi and rsi registers cause we technically execute before main
    push    rdi
    push    rsi

    ; first initialize the stdio buffer with sys_malloc
    ; void *malloc(size_t size);
    mov     rdi, STDIO_BUFFER_SIZE ; parameter size
    call    sys_malloc      ; allocate memory for stdio buffer
    test    rax, rax        ; check if allocation was successful
    jz      .error          ; if it was not, terminate the program
    jmp     .return         ; else return from this procedure
    .error: 
        mov     rax, -1     ; parameter status move status code into rdi
        call    sys_exit    ; force exit of program
    .return: 
        mov     [STDIO_BUFFER_PTR], rax  ; move pointer to allocated memory into ptr storage variable
        ; now restore the rdi and rsi registers
        pop     rsi
        pop     rdi
        LEAVE
        ret

; this procedure acts as a teardown procedure of the program - free buffers and exits the program
; this section will be moved into the _start procedure in the future
_DEPRECATED_end_core_lib:
    .enter: ENTER
    ; free the stdio buffer
    ; void free(void *_Nullable ptr);
    mov     rdi, [STDIO_BUFFER_PTR]
    call    sys_free

    ; and then exit the program
    ; [[noreturn]] void _exit(int status);
    xor     rdi, rdi        ; parameter status - 0
    call    sys_exit        ; exit the program
    hlt                     ; execution shouldnt reach this point


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

    ; restore cmd args register for main function call
    pop     rsi
    pop     rdi 

    nop
    call    _main                       ; call main function
    nop

    .end_process:  ; end the process by cleaning up of program (freeing buffers etc...)
        ; free the stdio buffer
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
; <<< Also we only support the following format specifier: %d, %s
; <<< Additionally we do not support masking of format specifiers in any kind
; <<< And we also dont support more than 4 format arguments :/
global sys_fprintf
sys_fprintf: 
    .enter: ENTER 

    push    r12             ; make r12 available for storage
    push    r13             ; make r13 available for storage
    push    r15             ; make r14 available for storage
    push    r15             ; make r15 available for storage
    push    rbx             ; make rbx available for stoarge
    xor     rbx, rbx        ; use rbx as indicator which format specifier register to use

    ; xchg    rdi, rsi        ; exchange rdi and rsi values - parameter stream now in rsi and parameter format now in rdi
    ; now we write the string in rsi into the fd at parameter stream using sys_fputc and a for loop
    xor     rcx, rcx        ; clear index
    .for: 
        mov     al, [rsi+rcx]; move current char at index position into al
        test    al, al      ; check if al is empty = null terminator
        jz      .return     ; if its empty, return from this function
        ; else continue loop
        cmp     al, FORMAT_SPECIFIER_BEGIN ; check if al marks the beginning of a format specifier
        jne     .char       ; if it does not mark the beginning of a specifier, just output the char
        ; else fall through to handling the specifier
        .specifier: 
            add     rcx, 1
            ; next determin which register hold the value of this format specifier
            DETERMIN_SPECIFIER_REGISTER ; value is now in rax
            add    rbx, 0x01        ; increment format specifier register counter 

            mov     al, [rsi+rcx]; determin the actual kind of value specified by the specifier - eigther %d or %s
            cmp     al, FORMAT_SPECIFIER_STRING  ; check which specifier it is 

            .string:  ; if the specifier == %s, we call this function recursivly and just append the string to the buffer this way
                mov     r12, rdi    ; preserve rdi from function call
                mov     r13, rsi    ; preserve rsi from function call
                mov     r14, rdx    ; preserve rdx from function call
                mov     r15, r10    ; preserve r10 from function call
                push    r8          ; preserve r8  from function call
                push    r9          ; preserve r9  from function call

                ; int fprintf(FILE *restrict stream, const char *restrict format, ...)
                ; rdi - parameter stream - already in rdi
                mov     rsi, rax    ; parameter format - in our case its a format parameter
                call    sys_fprintf ; make recursive call - we ignore the return value

                mov     rdi, r12    ; restore rdi 
                mov     rsi, r13    ; restore rsi
                mov     rdx, r14    ; restore rdx 
                mov     r10, r15    ; restore r10
                pop     r8          ; restore r8
                pop     r9          ; restore r9
                jmp     .end_specifier ; jump to end of specifier section
            .digit:  ; if the specifier == %d, we call 

        .end_specifier:     jmp     .for  ; jmp to begin of loop
        .char: 

    add     rcx, 0x01       ; rcx++ - index++
    jmp     .for            ; repeat the loop


    .return: 
        pop     r13         ; restore pushed r13
        pop     r12         ; restore pushed r12
        mov     rax, rcx    ; move index into rax for returning
        lEAVE
        ret 


sys_printf: hlt
sys_snprintf: hlt
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

    .flush_buffer:  ; if we came here - sys_fflush guarantees that the indnex is 0, so we dont jmp here again --> if no error occured!
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
global sys_fflush
sys_fflush:
    .enter: ENTER

    cmp     word [STDIO_BUFFER_INDEX], 0x00  ; check if parameter nbyte == 0
    je      .normal         ; if nbyte == 0, then just return from this function
    ; else proceed with writing

    call fileno             ; extract the file-descriptor from the FILE* stream to get the parameter filedes
    mov     rdi, rax        ; parameter filedes - move the returned fd from fileno into rsi 
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
; >>> int open(const char *path, int oflag, ...);
; <<< we DO NOT return a ptr to a FILE-object, instead we return a file-descriptor!
global sys_fopen
sys_fopen:
    .enter: ENTER

    mov     rax, SYS_OPEN   ; move syscall number into rax
    ; rdi - parameter path - already in rdi with parameter pathname
    ; rsi - parameter oflag - already in rsi with parameter mode
    syscall                 ; execute syscall open
    test    rax, rax        ; check if syscall was successful
    js      .error          ; if it was not, handle the error and return from function
    jmp     .return         ; else return from this function --> rax = file descriptor 
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
