section .data
    ALLOC_ERROR_TEXT:   db "Calloc failed"
section .text

global try_alloc_fields, free_fields, clear_field
; Project internal functions and variables
extern FIELD_AREA, FIELDS_ARRAY
; glibc functions and variables
extern perror
; core.lib functions
extern sys_calloc, sys_free, sys_exit

%include "core.lib.inc"

; Try to allocate space for the two game fields
; If calloc returns with an, we exit from the program --> !We might not return from this function!
; (-)[-]
try_alloc_fields:  
    .enter: ENTER

    push    r12             ; make r12 available for storage
    xor     r12, r12        ; index for loop --> set to 0
    .for: 
        cmp     r12, 0x2        ; if r12 >= 2, then break the loop
        jge     .return         ;   by returning from this function

        ; allocate a game field and store it in the fields_array
        ; void *calloc(size_t nmemb, size_t size);
        xor     rax, rax        ; clear rax
        mov     rdi, [FIELD_AREA]; parameter nmemb
        mov     rsi, 0x1        ; parameter size - allocate nmemb units of size 1 byte
        call    sys_calloc      ; allocate memory --> rax = pointer to allocated memory
        test    rax, rax        ; if rax == NULL, the allocation failed
        jz      .failed         ;   and we print a error message and exit the program
        mov     [FIELDS_ARRAY+0x8*r12], rax  ; store pointer at correct array index in FIELDS_ARRAY
        ; continue allocating the next game field

        inc     r12             ; r12++
        jmp     .for            ; continue to next loop iteration

    .failed:  ; print some error information; !NORETURN!
        pop     r12
        ; void perror(const char *s);
        xor     rax, rax        ; clear rax
        mov     rdi, ALLOC_ERROR_TEXT  ; parameter s
        call    perror          ; print the error
        mov     rax, -1         ; move exit code into rax
        call    sys_exit        ; exit the program
        hlt                     ; we should never reach this code

    .return:
        pop     r12         ; pop the pushed register
        LEAVE
        ret


; function for clearing a field pointed to by rdi
; for the implementation we just use the assembly machine-gun 'rep movsb`
; (int* field_ptr)[-]
clear_field: 
    ; No prolog needed

    ; rdi already contains destination memory address
    mov     rcx, [FIELD_AREA]   ; move number of bytes to be replaced into counter register
    mov     al, 0x00            ; move char to replace the memory with into al --> here we use an empty byte
    cld                         ; clear direction flag so that we overwrite upwards from the base memory address
    rep stosb                   ; overwrite whole allocated memory with zeros

    ; No epilog needed
    ret



; free the allocated game field stored at the FIELDS_ARRAY array
; (-)[-]
free_fields:  
    .enter: ENTER

    push    r12             ; make r12 available for storage
    xor     r12, r12        ; index for loop --> set to 0
    .for: 
        cmp     r12, 0x2        ; if r12 >= 2, then break the loop
        jge     .return         ;   by returning from this function

        ; free the allocated game fields
        ; void free(void *_Nullable ptr);
        xor     rax, rax        ; clear rax
        mov     rdi, [FIELDS_ARRAY+0x8*r12]; parameter ptr
        call    sys_free            ; free allocated memory --> free has no return value
        ; continue allocating the next game field
        inc     r12             ; r12++
        jmp     .for            ; continue to next loop iteration

    .return:
        pop     r12         ; pop the pushed register
        LEAVE
        ret