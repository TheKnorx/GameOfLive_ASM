section .text

global configure_field, decide_cell_state
; Project internal functions and variables
extern FIELDS_ARRAY, FIELD_WIDTH, FIELD_AREA, FIELD_HEIGHT

%include "core.lib.inc"

; macro for checking if we found a neigbour and if so, increment the neighbour counter
; possible neighbour at al, neighbour counter at r13
%macro _CHECK_NEIGHBOUR 0
    cmp     al, 0x00            ; check if al is a dead cell
    je      %%dead              ; if its dead, skip it
    inc     r13                 ; else increment r13/neighbour counter
    %%dead:
%endmacro

; macro for intializing registers for and performing the function call to _get_coordinate, and accessing the field
; it takes two parameters: the register storing the y coordinate part, and the register storing the x part
%macro _ACCESS_FIELD 2
    ; (int* field_to_write, int y, int x)[int a]
    mov     rdi, %1             ; parameter y - move row_index into rsi
    mov     rsi, %2             ; parameter x - move column_index into rdx
    call    _get_coordinate     ; get the 1d coordinate in rax
    ; access the field with the calculated 1d coordinate
    mov     rdi, [rbp-8]        ; parameter field_to_write - move field_to_read pointer into rsi
    mov     al, [rdi+rax]       ; access the field with rdi+rax and write the value back to rax
    movzx   rax, al             ; migrate al into rax
%endmacro


; functio for configuring the field with a fixed pattern
; maybe I will add support for input of a pattern of cells later on...
; (-)[-]
configure_field:
    ; Special Cell Configuration:
    ;       OO             (24,25)(25,25)
    ;      OO       (23,26)(24,26)
    ;       O              (24,27)
    ; For the starting y-coordinate 25, we instead take the field area / 2
    ; All the following coordinates are for illustration only and do not match with the end-result!
    ; y-coordinate calculates with y-coordinate * row-width:
    ; Then add the x-coordinate to the result --> out comes a 1d coordinate representation of a 2d coordinate
    mov     rdi, [FIELDS_ARRAY] ; move pointer to game field into destination register

    ; move into rax the coordinate of the center of the game field
    ; we do this by adding the field area to the field width and then divide that shit by 2 (by shifting)
    mov     rax, [FIELD_AREA]   ; move field_area into rax
    add     rax, [FIELD_WIDTH]  ; move field_width into rax
    shr     rax, 0x01           ; shift one to the right --> divide rax by 2

    ; create the first two cells
    mov     byte [rdi+rax], 0x1 ; put a living cell at that coordinate of the game field
    mov     byte [rdi+rax-0x1], 0x1  ; also put a living cell at the next coordinate (24,25) of the game field

    ; move one row up and create next two cells
    add     rax, [FIELD_WIDTH]  ; add another row to rax --> we are now at (24,26)
    sub     rax, 0x01           ; subtract 1 from rax to get to x coodinate (24,y)
    mov     byte [rdi+rax], 0x1 ; put a living cell at that coordinate of the game field
    mov     byte [rdi+rax-0x1], 0x1 ; also put a living cell at the coordinate (23,26) of the game field

    ; move another row up and create last cell
    add     rax, [FIELD_WIDTH]  ; add another row --> we are not at (24,27)
    mov     byte [rdi+rax], 0x1 ; put a living cell there
    ; we are finished with this configuration --> return from this function

    ret


; procedure for perform modolo arithmetric 'x mod y' and return result
; important trick we do here is that if x is negativ, we add y to x before the mod
; (int x, int y)[int (x mod y)]
_modolo:
    cmp     rdi, 0x00           ; check if x is negativ
    jge     .mod                ; if not negative, we perform the mod
    .prepare_mod:               ; else we do the trick: x+=y before the mod
        add     rdi, rsi        ; add x+=y
    .mod:                       ; do the mod operation: x mod y
        mov     rax, rdi        ; move divident x into rax for implicit DIV operand
        xor     rdx, rdx        ; clear rdx so it doesnt mess with the divident --> RDX:RAX
        div     rsi             ; divide rax/rdi --> gives us the rest of the division in rdx
    mov     rax, rdx            ; move mod result into rax for returning
    ret                         ; return from procedure


; procedure for calculating the 1d coordinate (x) of a given 2d coodinate (x|y) and returning it in rax
; !We pass the coordinate in switched order!
; (int y, int x)[int a]
_get_coordinate:
    mov     rax, rdi            ; move rdi/y into rax for MUL operation
    mov     r9, rsi             ; save rsi/x to r9 for later use
    xor     rsi, rsi            ; clear rsi so it doesnt mess with the MUL --> RDX:RAX
    mov     rcx, [FIELD_WIDTH]  ; move field_width into rcx
    mul     rcx                 ; rax*rcx --> y*field_width --> result in rax

    ; now add the x coordinate to the 1d representation of y, 
    ; creating the full 1d representation of the coordinate (x, y)
    add     rax, r9             ; add x to y
    ret


; Given a row and column coordinate of a cell, determin the state of this cell and its neighbours
; and based on those findings decide whether the cell should live or not
; Then write the result to the game field --> this function abstracts completely from the main executable section 
; the handling and building of coordinates, as well the reading and writing of cell-information to the correct fields 
; (int* field_to_write @ rdi, int* field_to_read @ rsi, int row_index @ rdx, int column_index @ rcx)[-]
decide_cell_state:
    .enter: ENTER

    push    rsi                 ; push field_to_read to stack   --> access via @rbp-8   --> _FIELD_TO_READ_MEM
    push    rdi                 ; push field_to_write to stack  --> access via @rbp-2*8 --> _FIELD_TO_WRITE_MEM
    push    rbx                 ; make rbx available for storage--> for general temp storage of data
    push    r12                 ; ...  r12          ...         --> use as index for loops
    push    r13                 ; ...  r13          ...         --> use as neighbour count
    push    r14                 ; ...  r14          ...         --> use as storage for row_index
    push    r15                 ; ...  r15          ...         --> use as storage for column_index

    xor     r13, r13            ; clear r13
    mov     r14, rdx            ; save rdx/row_index into r14
    mov     r15, rcx            ; save rcx/column_index into r15

    ; if (field_to_read[row_index][ _modolo(column_index-1, FIELD_WIDTH) ]) neigbours++;
    ; using: (int x, int y)[int (x mod y)]
    .left: 
        ; mod(column_index-1, FIELD_WIDTH)
        mov     rdi, r15        ; parameter x - move column_index into rdi
        sub     rdi, 1          ; subtract 1 from parameter x
        mov     rsi, [FIELD_WIDTH]; parameter y - move field_width into rsi
        call    _modolo         ; column-1 mod field_width --> result in rax

        ; field_to_read[row_index][column_index-1]
        _ACCESS_FIELD r14, rax  ; get cell at position [r14][rax] in rax/al

        ; neighbours++
        _CHECK_NEIGHBOUR        ; use macro for comparing al and setting r13 accordingly

    ; if (field_to_read[row_index][ _modolo(column_index+1, FIELD_WIDTH) ]) neigbours++;
    .right: 
        ; mod(column_index+1, FIELD_WIDTH)
        mov     rdi, r15        ; parameter x - move column_index into rdi
        add     rdi, 1          ; add 1 to parameter x
        mov     rsi, [FIELD_WIDTH]; parameter y - move field_width into rsi
        call    _modolo         ; column+1 mod field_width --> result in rax

        ; field_to_read[row_index][ column_index+1 ]
        _ACCESS_FIELD r14, rax  ; get cell at position [r14][rax] in rax/al

        ; neighbours++
        _CHECK_NEIGHBOUR        ; use macro for comparing al and setting r13 accordingly

    ; for (int i = 0; i<3; i++) --> see .for section
    ;     if (field_to_read[ _modolo(row_index-1, FIELD_HEIGHT) ][ _modolo(column_index-1+i, FIELD_WIDTH) ]) 
    ;         neighbours++;
    .below: 
        ; _modolo(row_index-1, FIELD_HEIGHT)
        mov     rdi, r14        ; parameter x - move row_index into rdi
        sub     rdi, 0x01       ; move one row below the cell - parameter x -1
        mov     rsi, [FIELD_HEIGHT]; parameter y - move the field_height into rsi
        call    _modolo         ; row_index-1 mod field_height --> result in rax
        mov     rbx, rax        ; overwrite rbx with new (temporary) row_index 

    ; for (int i = 0; i<3; i++) 
    xor     r12, r12            ; clear index for loop
    .for:  ; iterate through the 3 positions below the cell from left to right using r12 as index
        cmp     r12, 0x03       ; compare r12 to 3
        jge     .break_below; if r12 >= 3, break the loop
        ; else continue iterating through below neighbours

        ; _modolo(column_index-1+i, FIELD_WIDTH)
        mov     rdi, r15        ; parameter x - move column_index into rdi
        sub     rdi, 0x01       ; rdi-- meaning column_index-1
        add     rdi, r12        ; add loop index to column_index
        mov     rsi, [FIELD_WIDTH]; parameter y - move field_width int rsi
        call    _modolo         ; column_index-1+i mod field_index --> result in rax

        ; field_to_read[ row_index-/+1 ][ column_index-1+i ]
        _ACCESS_FIELD rbx, rax  ; get cell at position [rbx][rax] in rax/al

        ; neighbours++
        _CHECK_NEIGHBOUR        ; use macro for comparing al and setting r13 accordingly

        inc     r12             ; increment index 
        jmp     .for            ; continue loop
    .break_below:
        
    ; for (int i = 0; i<3; i++) --> see .for section
    ;     if (field_to_read[ _modolo(row_index+1, FIELD_HEIGHT) ][ _modolo(column_index-1+i, FIELD_WIDTH) ]) 
    ;         neighbours++;
    .top: 
        ; we do the above using a little trick -> we reuse the for loop in .below
        ; when we enter this section for the first time, we read row_index from r14 and set r14 to -1, indicating that we alread have been here
        ; when we then come here again, and r14==-1, we skip this section
        ; -1 cause the row index can never be -1, so we can be pretty damn sure this is cause we have already been in this section
        cmp     r14, -1         ; did we execute this section already?
        je      .check          ; if yes, then check the neighbours and set the cell accordingly
        ; else we calculate the top neighbours

        push    r14             ; push r14 so that we can use its value later on in the .check section

        ; _modolo(row_index+1, FIELD_HEIGHT)
        mov     rdi, r14        ; parameter x - move row_index into rax
        add     rdi, 0x01       ; move one row above the cell - parameter x - 1
        mov     rsi, [FIELD_HEIGHT]; parameter y - move the field_height into rsi
        call    _modolo         ; row_index+1 mod field_height --> result in rax
        mov     rbx, rax        ; overwrite rbx with new (temporary) row_index 

        mov     r14, -1         ; set flag for section already executed 
        xor     r12, r12        ; clear index for loop
        jmp     .for            ; use the for loop from above again


    ; if (current_cell && 2 <= neighbours && neighbours <= 3) return 1;
    ; if (!current_cell && 3 == neighbours) return 1;
    ; /* else cell is dead */ return 0;
    .check:  ; section for checking, depending in the neighbours, the future state of given cell
        ; now first get the state of the current cell - we assume that the coordinates given already point
        ; to the current cell and dont have to be modolo'd or modified in any other way - except converting them to 1d
        pop     r14             ; restore the original row_index value from before

        _ACCESS_FIELD r14, r15  ; get cell at position [r14][r15] in rax/al

        cmp     al, 0x00        ; compare cell/al, it its alive or dead
        jne     .alive          ; if the value is not 0x00, its alive --> jmp to .alive
        ; else its dead --> fall through to .dead
        .dead: ; only if the cell as 3 neighbours, it revives. 
            cmp     r13, 0x03   ; compare the neighbours count to 3
            jne     .return     ; if the neighbours count != 3, skip it and return from the function
            jmp     .write_back ; else revive the cell --> jump to write_back of a 1 into the current location
        .alive: ; if neighbours e {2, 3}, the cell continues to live. Else it dies
            cmp     r13, 0x02   ; compare the neighbours count to 2
            setae   al          ; set al to 1 if its greater or equal

            cmp     r13, 0x03   ; compare the neighbours count to 3
            setbe   cl          ; set cl to 1 if its less or equal

            and     al, cl      ; if 2 <= neighbours <= 3, then an AND should result in 1, else it would be 0
            test    al, al      ; test outcome of AND operation
            jz     .return      ; al is 0, meaning it has too many neighbours, meaning we kill it, meaning we return from the function
            ; else fall through to the write_back
        .write_back:
            mov     rdi, r14    ; parameter y - move row_index into rdi
            mov     rsi, r15    ; parameter x - move column_index into rsi
            call    _get_coordinate; get the 1d coordinate in rax
            mov     rdi, [rbp-16]; move field_to_write into rdi
            mov     byte [rdi + rax], 0x01; set cell from rdi at the calculated coordinate to alive

    .return: 
        ; restore all pushed register
        pop     r15
        pop     r14
        pop     r13
        pop     r12
        pop     rbx
        add     rsp, 0x10       ; remove pushed rdi and rsi from stack
        LEAVE
        ret
