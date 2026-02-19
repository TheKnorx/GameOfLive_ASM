BITS 64


section .bss
    ; Reserving a quad-word for each variable out of convenience so that we can use 64-bit everywhere and dont have mix 32- and 64-bit registers together
    ; Dont want to reserve less than that and begin to have a inconsistancy, perhaps writing the wrong values into registers when mixing 32 and 64 bit variables
    FIELD_WIDTH:    resq 0x1    ; reserved 1 quadword for the field width (--> max 2^64 bits ~ 2*10^9GB never gonna need that)
    FIELD_HEIGHT:   resq 0x1    ;               ...             field height            ...
    GENERATIONS:    resq 0x1    ;               ...             generations             ...
    FIELD_AREA:     resq 0x1    ; reserve a qword --> 1 quadword is would be 2^64 bits ~ 2*10^9GB, so wayyyyy too much --> we do a <2^32 mod height*width> for ensuring a guaranteed fit
    FIELDS_ARRAY:   resq 0x2    ; reserve two qwords for two pointers that point to the allocated game fields

section .data
    USAGE_TEXT:     db "Usage: %s <field-width> <field-height> <amount of generations>", 0xA, 0x00
section .text

global FIELD_WIDTH, FIELD_HEIGHT, FIELD_AREA, FIELDS_ARRAY, GENERATIONS
; project functions that may not return
extern try_alloc_fields
; project functions (that always return)
extern configure_field, free_fields, decide_cell_state, decide_cell_state, clear_field, ascii_to_int, try_write_game_field
; glibc functions:
extern printf
; core.lib functions
extern sys_atoi

%include "core.lib.inc"


; function for simulating the generations
; ()[]
simulate:
    .enter: ENTER
    
    push    rbx             ; make rbx available for storing loop index --> so it doesn't get garbled by function calls
    mov     rbx, [GENERATIONS] ; move amount of generations into index variable - we start counting from the top
    push    r12             ; make r12 available for storing which field to read from
    mov     r12, 0x1        ; set r12 to 1 --> we xor this on every loop so if we want to start at 0, we have to set it to 1 before
    
    push    r13             ; make r13 available for cell row index counter
    push    r14             ; make r14 available for cell column index counter

    ; write game field to start into file
    ; (int* field_to_save, int generation)[]
    mov     rdi, [FIELDS_ARRAY] ; parameter field_to_save - move pointer to first game field into rdi
    mov     rsi, rbx            ; parameter generations - move amount of generations into rsi
    call    try_write_game_field; write first game field to file; !we might not return from this call!

    .for_generation:  ; iterate through all generations simulating them
        cmp     rbx, 0          ; if rbx > 0 meaning still have to simulate some generations (>= cause of the initial dec at begin of loop)
        jle     .return         ; else we break the loop and return to main function
        xor     r12, 0x1        ; flip the current field to use

        ; init source and destination register with correct pointer
        ; this registers will be garbled, so we have to push them or later on migrate to callee-saved registers
        mov     rsi, [FIELDS_ARRAY+8*r12]  ; move field to read from into source index
        mov     rax, r12        ; move current field to read from into rax
        xor     rax, 0x1        ; flip it to get the field to write to
        mov     rdi, [FIELDS_ARRAY+8*rax]  ; move field to write to into destination index

        ; on every new generation we have to clear the field we will write to to not have an interference with cells of previous generations
        ; luckily, the field to write to is already in rdi but we also have to preserve all the registers --> we can re-use r13 and r14 for that
        mov     r13, rsi        ; save rsi in r13 for now
        mov     r14, rdi        ; save rdi in r14 for now
        call    clear_field     ; clear the field to write to
        mov     rsi, r13        ; restore rsi from r13
        mov     rdi, r14        ; restore rdi from r14

        xor     r13, r13        ; clear r13 and use it as row index
        .for_row:  ; iterate through all rows of the game field
            xor     r14, r14        ; clear r14 and use it as a column index
            .for_column:  ; iterate through all columns of the current row
                push    rdi             ; save rdi onto stack
                push    rsi             ; save rsi onto stack

                ; now we have to pass the field to read, the field to write to the decide_cell_state function
                ; along with the row and column index of the cell --> luckily the first two things are already correctly loaded
                mov     rdx, r13        ; move row index into parameter register rdx 
                mov     rcx, r14        ; move column index into parameter register rcx (--> thats why we cannot use rcx for counter stuff - gets garbled)
                call    decide_cell_state  ; let this function decide what to do with the cell

                pop     rsi             ; restore rsi from stack
                pop     rdi             ; restore rdi from stack

                inc     r14             ; r14++ (column counter ++)
                cmp     r14, [FIELD_WIDTH]; if r14 < FIELD_WIDTH
                jb      .for_column     ;   we continue the loop
                ; else we fall through and continue to next row if possible

            inc     r13             ; r13++ (row counter ++)
            cmp     r13, [FIELD_HEIGHT]; if r13 < FIELD_HEIGHT
            jb      .for_row        ;    we continue the loop 
            ; else we fall through and enter the next generation

        ; rdi already set for function parameter
        mov     rsi, rbx        ; move generations into rsi for parameter to function
        call    try_write_game_field  ; write current generation to file; !we might not return from this function! 
        dec     rbx             ; rbx--
        jmp     .for_generation ; continue the loop

    .return: 
        ; Restore pushed registers
        pop     r14         ; restore pushed r14
        pop     r13         ; restore pushed r13
        pop     r12         ; restore pushed r12
        pop     rbx         ; restore pushed rbx
        LEAVE
        ret


; main entry point of program - as long as we depend on glibc the real main sits in core.lib and acts like _start
; we expect the width, the height of the game field as well as the amount of generations to simulate via command line arguments
; (int argc at rdi, char** argv at rsi)[int return-code]
global _main
_main: 
    .enter: ENTER

    ; Additional registers for additional storage:
    push    r12

    .read_cmd_args:     ; check existance of cmd arguments and fill variables accordingly; !we might not get back from this section!
        cmp     rdi, 0x4            ; check if all 3 (+1) arguments were passed to the program
        jne     .print_usage        ; if there are cmd args missing, print usage and exit
        ; else continue to parse arguments - converting int with 'int atoi(const char *nptr);`

        mov     r12, rsi            ; save rsi argument table pointer to r12

        ; get field width: 
        mov     rdi, [r12 + 0x8]    ; parameter nptr - ptr to ascii encoded field width number
        call    sys_atoi            ; convert ascii number to actual integer 
        mov     [FIELD_WIDTH], rax  ; move int into field width variable

        ; get field height
        mov     rdi, [r12+0x8*2]    ; parameter nptr - ptr to ascii encoded field height number
        call    sys_atoi            ; convert ascii number to actual integer
        mov     [FIELD_HEIGHT], rax ; move int into field height variable

        ; get amount of generations to simulate
        mov     rdi, [r12+0x8*3]    ; parameter nptr - ptr to ascii encoded generation number
        call    sys_atoi            ; convert ascii number to actuall integer
        mov     [GENERATIONS], rax  ; move int into generations variable

        ; calculate the field area
        mov     rax, [FIELD_WIDTH]  ; move field width into implicit operand eax for MUL
        mul     qword [FIELD_HEIGHT]; multiply field width with field height
        ;jo      .overflow           ; if OF=1, handle the MUL overflow of edx
        ;jc      .overflow           ; if CF=1, handle the MUL overflow of edx

        ;.normal: 
        ;    mov     [FIELD_AREA], rax       ; mov result of MUL into field area variable
        ;    jmp     .init_field             ; jump out of the cmd parse procedure and into the next one
        ;.overflow:  ; the field width and height were to big for a 32 bit integer, so we do a 2^32 mod width*height
        ;    mov     [FIELD_AREA], rax       ; we do this by just writing the upper/left bits of the result into the field area variable
        ;    ; fall through to next procedure
        mov     [FIELD_AREA], rax       ; move result of MUL into field are variable
        ; fall through to next section

    .init_field:  ; init the game field; !we might not get back from this section!
        call    try_alloc_fields    ; allocate the two game fields
        call    configure_field     ; now we fill the field with some predefined values

    call    simulate        ; simulate the generations

    .cleanup:  ; end the program by cleaning up
        ; freeing the allocated fields
        call    free_fields
        jmp     .return

    .print_usage:
        ; int printf(const char *restrict format, ...);
        xor     rax, rax            ; clear rax for std*-glibc function
        mov     rdi, USAGE_TEXT     ; parameter format
        mov     rsi, [r12]          ; first format parameter
        call    printf
        ; fall through to .return section

    .return:  ; pop any pushed registers & do the epilog
        ;  pop pushed registers
        pop     r12

        ; set exit code to 0
        xor     rax, rax
        LEAVE
        ret
