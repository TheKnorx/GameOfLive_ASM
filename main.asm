BITS 64


section .bss
	; Reserving at least a double-word for each variable out of convenience so that the content gets automatically zero extended to 64bit registers. 
	; Dont want to reserve less than that and begin zero-extending every damn register I might need in 32/64bit later on
	FIELD_WIDTH:  	resd 0x1 	; reserved 1 doubleword for the field width (--> max 2^32 bits ~ 536.8MB)
	FIELD_HEIGHT: 	resd 0x1 	; 				... 			field height 			...
	GENERATIONS: 	resd 0x1 	; 				...				generations 			...
	FIELD_AREA: 	resd 0x1 	; reserve a dword --> 1 quadword is would be 2^64 bits ~ 2*10^9GB, so wayyyyy too much --> we do a <2^32 mod height*width> for ensuring a guaranteed fit

	FIELDS_ARRAY: 	resq 0x2 	; reserve two qwords for two pointers that point to the allocated game fields

section .data
	USAGE_TEXT: 	"Usage: %s <field-width> <field-height> <amount of generations>", 0xA, 0x00
section .text

global main
global FIELD_WIDTH, FIELD_HEIGHT, FIELD_AREA, FIELDS_ARRAY
; project functions that may not return
extern try_ascii_to_int
; project functions
extern 
; glibc functions:
extern printf


; function for simulating the generations
; ()[]
simulate:
	nop

; main entry point of program
; we expect the width, the height of the game field as well as the amount of generations to simulate via command line arguments
; (int argc at rdi, char** argv at rsi)[int return-code]
main: 
	; Prolog
    push    rbp
    mov     rbp, rsp
    and     rsp, -16

    ; Additional registers for additional storage:
    push 	r12

    .read_cmd_args: 	; check existance of cmd arguments and fill variables accordingly; !we might not get back from this procedure!
    	cmp 	rdi, 0x4 			; check if all 3 (+1) arguments were passed to the program
    	jne		.print_usage 		; if there are cmd args missing, print usage and exit
    	; else continue to parse arguments

    	mov 	r12, rsi 			; save rsi argument table pointer to r12

    	; get field width: 
    	mov 	rdi, [r12 + 0x8]	; ptr to ascii encoded field width number
    	call 	try_ascii_to_int 	; convert ascii number to actual integer 
    	mov 	[FIELD_WIDTH], eax 	; move int into field width variable

    	; get field height
    	mov 	rdi, [r12+0x8*2] 	; ptr to ascii encoded field height number
    	mov 	try_ascii_to_int 	; convert ascii number to actual integer
    	mov 	[FIELD_HEIGHT], eax ; move int into field height variable

    	; get amount of generations to simulate
    	mov 	rdi, [r12+0x8*3] 	; ptr to ascii encoded generation number
    	mov 	try_ascii_to_int 	; convert ascii number to actuall integer
    	mov 	[GENERATIONS], eax 	; move int into generations variable

    	; calculate the field area
    	mov 	eax, [FIELD_WIDTH] 	; move field width into implicit operand eax for MUL
    	mul 	[FIELD_HEIGHT] 		; multiply field width with field height --> if no overflow: result in aex & OF/CF = 0; else in edx:eax & OF/CF=1
    	jo  	overflow			; if OF=1, handle the MUL overflow of edx
    	jc 		overflow			; if CF=1, handle the MUL overflow of edx

    	.overflow:  ; the field width and height were to big for a 32 bit integer, so we do a 2^32 mod width*height
    		mov 	[FIELD_AREA], edx 		; we do this by just writing the upper/left bits of the result into the field area variable
    		jmp 	.init_field 			; jump out of the cmd parse procedure and into the next one
    	.normal: 
    		mov 	[FIELD_ARE], eax 		; mov result of MUL into field area variable
    		; fall through to next procedure


    .init_field:  ; init the game field; !we might not get back from this procedure!
    	call 	alloc_fields		; allocate the two game fields
    	call 	configure_field 	; now we fill the field with some predefined values

    call 	simulate 		; simulate the generations

    .cleanup:  ; end the program by cleaning up
    	; by freeing the allocated fields
    	call 	free_fields
    	; by poping all pushed registers
    	pop 	r12
    	jmp 	.return

    .print_usage:
    	; int printf(const char *restrict format, ...);
    	xor 	rax, rax 			; clear rax for std*-glibc function
    	mov 	rdi, USAGE_TEXT		; const char* to format string
    	; first format parameter already in rsi --> argv[0]
    	call 	printf
    	; fall through to .return procedure

    .return:  ; do the epilog
    	; Epilog
	    mov     rsp, rbp
	    pop     rbp
	    ret
