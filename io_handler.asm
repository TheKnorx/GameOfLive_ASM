section .bss
    CURRENT_FILENAME:   resq 0x01   ; for storing the currently generated file name to write the game field into
    CURRENT_FILESTREAM: resq 0x01   ; for storing the current pointer to the opened file using the generated filename
section .data
    FILENAME:           db "gol_%05d.pbm", 0x00 ; file name for the game saved fields 
    FILENAME_START:     db "gol_", 0x00         ; start of filename
    FILENAME_END:       db ".pbm", 0x00         ; end   of filename
    FILENAME_PART_SIZE: equ 0x04                ; its convenient that FILENAME_START and _END are of the same size
    FILENAME_NR_SIZE:   equ 0x05                ; amount of digits the number can have
    FILENAME_SIZE:      equ 14                  ; size of filename after format expansion
    FOPEN_FILEMODE:     db "w", 0x00            ; file mode to open file with --> create on write
    FILE_PREMABEL:      db "P1", 0x0A, "%d %d", 0x0A, 0x00  ; .pbm files need this for beeing interpreted/displayed correcty
    ERROR_TEXT:         db "A fatal error occured", 0x00  ; error text to be displayed alongside with additional error information
section .text

global try_write_game_field
; core.lib functions
extern sys_malloc, sys_free, sys_exit, sys_fputc, sys_fflush, sys_fprintf, sys_fopen, sys_perror, sys_memcpy, sys_itoa, sys_memset
; project intern functions and variables
extern FIELD_AREA, FIELD_WIDTH, FIELD_HEIGHT, GENERATIONS

%include "core.lib.inc"


; function for writing a specified game field to a file for later creating that gif
; !we might not return from this function!
; this might get improved in the future by migrating to the usage of virtual memory instead of real file...
; (int* field_to_save, int generation)[]
try_write_game_field: 
    .enter: ENTER 

    push    r12             ; use as temp storage for generation and as index for iterating through the game field
    push    r13             ; use as a temp storage for the passed field pointer
    mov     r13, rdi        ; save field pointer into r13

    ; first "invert" the generation, cause in main we count from high to low
    mov     r12, [GENERATIONS]; move amount of generations into rax
    sub     r12, rsi        ; subtract absolute amount of gens from current "reverse" gen to get to the inverted real gen


    ; then allocate memory for the new file name
    ; void *malloc(size_t size);
    xor     rax, rax                ; clear rax
    mov     rdi, FILENAME_SIZE      ; parameter size - allocate exactly 14 bytes
    call    sys_malloc              ; allocate space for new filename
    cmp     rax, 0x00               ; check if the pointer from malloc is NULL
    je      .failed                 ; if its NULL, we print an error message and exit
    mov     [CURRENT_FILENAME], rax ; else we store the pointer in the variable

    ; now create the new filename and copy it into the allocated buffer
    ; int snprintf(char str[restrict .size], size_t size,
    ;              const char *restrict format, ...);
    ;xor     rax, rax                ; clear rax once again for glibc call
    ;mov     rdi, [CURRENT_FILENAME] ; parameter char str[restrict .size]
    ;mov     rsi, FILENAME_SIZE      ; parameter size
    ;mov     rdx, FILENAME           ; parameter char *restrict format
    ;mov     rcx, r12                ; format parameter - fill into the filename the generation
    ;call    snprintf                ; do the magick!
    ;cmp     rax, 0x00               ; compare return value of snprintf --> success means not negative
    ;jl      .failed                 ; the return value is negativ fuck --> print error and exit


    ; now create the new filename and copy it into the allocated buffer
    ; first copy the part of the filename into the buffer, that we know is always the same using
    ; void *memcpy(void dest[restrict .n], const void src[restrict .n], size_t n);
    mov     rdi, [CURRENT_FILENAME] ; parameter dest[restrict .n]
    mov     rsi, FILENAME_START   ; parameter src[restrict .n]
    mov     rdx, FILENAME_PART_SIZE ; parameter n
    call    sys_memcpy              ; copy the start of the filename into the buffer

    ; second convert the generation counter into ascii using
    ; char* itoa(char str[restrict .size], size_t size, int number)
    ; now we know that the number can only have 5 decimal places, so we can simply
    ; pass a pointer to the beginning of the number to itoa and itoa will copy the number into the right place
    ; given that of course that a possible space between the number and the FILENAME_START has to be padded with spaces using
    ; void *memset(void s[.n], int c, size_t n);
    push    r13                     ; make r13 available for storage
    mov     r13, [CURRENT_FILENAME] ; move pointer to filename buffer into r13
    lea     r13, [r13+FILENAME_PART_SIZE] ; move pointer to start of number
    xor     rax, rax                ; clear rax
    mov     rdi, r13                ; parameter s[.n]
    mov     rsi, '0'                ; parameter c - padd space with zeros
    mov     rdx, FILENAME_NR_SIZE   ; parameter n
    call    sys_memset              ; padd the space of the number with ascii zeros

    ; convert the generation number into a ascii number
    xor     rax, rax                ; clear rax
    mov     rdi, r13                ; parameter str[restrict .size]
    mov     rsi, FILENAME_NR_SIZE   ; parameter size
    add     rsi, 0x01               ; add 1 to parameter size to make room for \0
    mov     rdx, r12                ; parameter number
    call    sys_itoa                ; convert the number in r12 to ascii --> rax == ptr to ascii but we ignore it

    ; copy the end of the filename into the buffer
    lea     r13, [r13+FILENAME_NR_SIZE] ; move pointer to end of ascii number - r13 should now point to the returned \0 of itoa
    xor     rax, rax                ; clear rax
    mov     rdi, r13                ; parameter dest[restrict .n]
    mov     rsi, FILENAME_END       ; parameter src[restrict .n]
    mov     rdx, FILENAME_PART_SIZE ; parameter n
    call    sys_memcpy              ; copy the start of the filename into the buffer

    ; finally to make things round, append a \0 to the end of the filename buffer and pop r13
    lea     r13, [r13+FILENAME_PART_SIZE] ; move pointer to the very last byte of the buffer
    mov     byte [r13], 0x00        ; append a \0 to the end 
    pop     r13                     ; restore pushed r13


    ; next open the file using the newly generated filename
    ; FILE *fopen(const char *restrict pathname, const char *restrict mode);
    xor     rax, rax                ; clear rax
    mov     rdi, [CURRENT_FILENAME] ; parameter *restrict pathname
    mov     rsi, FOPEN_FILEMODE     ; parameter *restrict mode
    call    sys_fopen               ; create the new file and open it
    test    rax, rax                ; check return value of fopen --> success means != NULL
    jz      .failed                 ; the return value == NULL --> print error and exit
    mov     [CURRENT_FILESTREAM], rax; move file stream ptr into variable

    ; as the filename is not longer of use, free its allocated space
    ; void free(void *_Nullable ptr);
    xor     rax, rax                ; clear rax
    mov     rdi, [CURRENT_FILENAME] ; parameter ptr
    call    sys_free                ; free allocated memory

    ; next write the file premable into the file
    ; int fprintf(FILE *restrict stream,
    ;             const char *restrict format, ...);
    xor     rax, rax                ; clear rax
    mov     rdi, [CURRENT_FILESTREAM]; parameter stream
    mov     rsi, FILE_PREMABEL      ; parameter format
    mov     rdx, [FIELD_WIDTH]      ; first format parameter
    mov     rcx, [FIELD_HEIGHT]     ; second format parameter
    call    sys_fprintf             ; write the formatted premable into the file
    ; starting now, we skip watching for errors concerning file operations

    ; if we came till here, we are ready to write the cells into the file:
    xor     r12, r12        ; now use r12 as the index --> set r12/index to 0
    .for:  ; iterate through all cells and write them to the file
        cmp     r12, [FIELD_AREA]; if we indexed all cells
        jge     .return         ;   then leave the loop and consequently return from the function
        ; else continue writing 

        xor     rax, rax        ; clear rax
        xor     rdi, rdi        ; clear rdi
        mov     dil, [r13+r12]  ; move current cell into rdi (8 bit dil) --> parameter int c
        cmp     dil, 0x00       ; if there is no cell there, write a '0' to the file --> .dead
        jne     .alive          ; else write a '1' to the file --> .alive
        .dead:
            mov     dil, '0'    ; move the '0' char into dil
            jmp     .write      ; skip the .alive part and write char into file
        .alive:
            mov     dil, '1'    ; move the '1' char into dil
        .write:
        ; write char into file
        ; int fputc(int c, FILE *stream);
        xor     rax, rax        ; clear rax
        mov     rsi, [CURRENT_FILESTREAM]  ; parameter FILE *stream
        call    sys_fputc       ; write cell into file (--> gets buffered most likely by stdout)

        inc     r12             ; r12++ (index++)
        jmp     .for            ; continue the loop

    .failed:  ; print the error text alongside with additional error information and exit the program
        ; void perror(const char *s);
        xor     rax, rax        ; clear rax
        mov     rdi, ERROR_TEXT ; parameter const char *s
        call    sys_perror      ; print error text with additional error information
        mov     rax, -1         ; exit code
        call    sys_exit        ; exit the program
        hlt                     ; this code should never be reached

    .return: 
        ; int fflush(FILE *_Nullable stream);
        xor     rax, rax        ; clear rax
        mov     rdi, [CURRENT_FILESTREAM]  ; parameter stream
        call    sys_fflush      ; flush any buffer and write everything to the file
        pop     r13             ; restore pushed r13
        pop     r12             ; restore pushed r12
        LEAVE
        ret