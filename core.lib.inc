; File for storing constants that are shared by multiple files

; generell constants
%define NULL 			0x00       ; ((void *) 0)
%define EOF             -1

; syscall number constants: 
%define SYS_WRITE       1
%define SYS_OPEN        2
%define SYS_MMAP		9
%define SYS_MUNMAP  	11
%define SYS_MREMAP 		25
%define SYS_EXIT        60


; map constants: 
%define PROT_READ       0x01
%define PROT_WRITE      0x02
%define PROT_EXEC       0x04
%define PROT_NONE       0x00
%define MAP_SHARED      0x01
%define MAP_PRIVATE     0x02
%define MAP_FIXED       0x10
%define MAP_ANONYMOUS 	0x20
%define MREMAP_MAYMOVE 	0x01


; memory allocator constants
%define MEM_HEAD_LEN	0x08



; macro for doing the prolog
%macro ENTER 0
    push    rbp
    mov     rbp, rsp
    and     rsp, -16        ; align the stack to multiple of 16
%endmacro

; macro for doing the epilog
; not using 'leave` here cause of performance
%macro LEAVE 0
    mov     rsp, rbp
    pop     rbp
%endmacro