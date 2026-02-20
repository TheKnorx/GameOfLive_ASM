; This file contains the errno.h, converted to assembly and a string table for mapping the errno numbers to the strings
; The below C-style version of the errno codes can be found under @/usr/include/asm-generic/errno.h


; SPDX-License-Identifier: GPL-2.0 WITH Linux-syscall-note
%ifndef _ASM_GENERIC_ERRNO_H
%define _ASM_GENERIC_ERRNO_H
; %include <asm-generic/errno-base.h> :
	%ifndef _ASM_GENERIC_ERRNO_BASE_H
	%define _ASM_GENERIC_ERRNO_BASE_H
	%define	EPERM		 1	; Operation not permitted
	%define	ENOENT		 2	; No such file or directory
	%define	ESRCH		 3	; No such process
	%define	EINTR		 4	; Interrupted system call
	%define	EIO		 	 5	; I/O error
	%define	ENXIO		 6	; No such device or address
	%define	E2BIG		 7	; Argument list too long
	%define	ENOEXEC		 8	; Exec format error
	%define	EBADF		 9	; Bad file number
	%define	ECHILD		10	; No child processes
	%define	EAGAIN		11	; Try again
	%define	ENOMEM		12	; Out of memory
	%define	EACCES		13	; Permission denied
	%define	EFAULT		14	; Bad address
	%define	ENOTBLK		15	; Block device required
	%define	EBUSY		16	; Device or resource busy
	%define	EEXIST		17	; File exists
	%define	EXDEV		18	; Cross-device link
	%define	ENODEV		19	; No such device
	%define	ENOTDIR		20	; Not a directory
	%define	EISDIR		21	; Is a directory
	%define	EINVAL		22	; Invalid argument
	%define	ENFILE		23	; File table overflow
	%define	EMFILE		24	; Too many open files
	%define	ENOTTY		25	; Not a typewriter
	%define	ETXTBSY		26	; Text file busy
	%define	EFBIG		27	; File too large
	%define	ENOSPC		28	; No space left on device
	%define	ESPIPE		29	; Illegal seek
	%define	EROFS		30	; Read-only file system
	%define	EMLINK		31	; Too many links
	%define	EPIPE		32	; Broken pipe
	%define	EDOM		33	; Math argument out of domain of func
	%define	ERANGE		34	; Math result not representable
	%endif
	%define	EDEADLK		35	; Resource deadlock would occur
	%define	ENAMETOOLONG	36	; File name too long
	%define	ENOLCK		37	; No record locks available
	;
	; This error code is special: arch syscall entry code will return
	; -ENOSYS if users try to call a syscall that doesn't exist.  To keep
	; failures of syscalls that really do exist distinguishable from
	; failures due to attempts to use a nonexistent syscall, syscall
	; implementations should refrain from returning -ENOSYS.
	; 
	%define	ENOSYS		38	; Invalid system call number
	%define	ENOTEMPTY	39	; Directory not empty
	%define	ELOOP		40	; Too many symbolic links encountered
	%define	EWOULDBLOCK	EAGAIN	; Operation would block
	%define	ENOMSG		42	; No message of desired type
	%define	EIDRM		43	; Identifier removed
	%define	ECHRNG		44	; Channel number out of range
	%define	EL2NSYNC	45	; Level 2 not synchronized
	%define	EL3HLT		46	; Level 3 halted
	%define	EL3RST		47	; Level 3 reset
	%define	ELNRNG		48	; Link number out of range
	%define	EUNATCH		49	; Protocol driver not attached
	%define	ENOCSI		50	; No CSI structure available
	%define	EL2HLT		51	; Level 2 halted
	%define	EBADE		52	; Invalid exchange
	%define	EBADR		53	; Invalid request descriptor
	%define	EXFULL		54	; Exchange full
	%define	ENOANO		55	; No anode
	%define	EBADRQC		56	; Invalid request code
	%define	EBADSLT		57	; Invalid slot
	%define	EDEADLOCK	EDEADLK
	%define	EBFONT		59	; Bad font file format
	%define	ENOSTR		60	; Device not a stream
	%define	ENODATA		61	; No data available
	%define	ETIME		62	; Timer expired
	%define	ENOSR		63	; Out of streams resources
	%define	ENONET		64	; Machine is not on the network
	%define	ENOPKG		65	; Package not installed
	%define	EREMOTE		66	; Object is remote
	%define	ENOLINK		67	; Link has been severed
	%define	EADV		68	; Advertise error
	%define	ESRMNT		69	; Srmount error
	%define	ECOMM		70	; Communication error on send
	%define	EPROTO		71	; Protocol error
	%define	EMULTIHOP	72	; Multihop attempted
	%define	EDOTDOT		73	; RFS specific error
	%define	EBADMSG		74	; Not a data message
	%define	EOVERFLOW	75	; Value too large for defined data type
	%define	ENOTUNIQ	76	; Name not unique on network
	%define	EBADFD		77	; File descriptor in bad state
	%define	EREMCHG		78	; Remote address changed
	%define	ELIBACC		79	; Can not access a needed shared library
	%define	ELIBBAD		80	; Accessing a corrupted shared library
	%define	ELIBSCN		81	; .lib section in a.out corrupted
	%define	ELIBMAX		82	; Attempting to link in too many shared libraries
	%define	ELIBEXEC	83	; Cannot exec a shared library directly
	%define	EILSEQ		84	; Illegal byte sequence
	%define	ERESTART	85	; Interrupted system call should be restarted
	%define	ESTRPIPE	86	; Streams pipe error
	%define	EUSERS		87	; Too many users
	%define	ENOTSOCK	88	; Socket operation on non-socket
	%define	EDESTADDRREQ	89	; Destination address required
	%define	EMSGSIZE	90	; Message too long
	%define	EPROTOTYPE	91	; Protocol wrong type for socket
	%define	ENOPROTOOPT	92	; Protocol not available
	%define	EPROTONOSUPPORT	93	; Protocol not supported
	%define	ESOCKTNOSUPPORT	94	; Socket type not supported
	%define	EOPNOTSUPP	95	; Operation not supported on transport endpoint
	%define	EPFNOSUPPORT	96	; Protocol family not supported
	%define	EAFNOSUPPORT	97	; Address family not supported by protocol
	%define	EADDRINUSE	98	; Address already in use
	%define	EADDRNOTAVAIL	99	; Cannot assign requested address
	%define	ENETDOWN	100	; Network is down
	%define	ENETUNREACH	101	; Network is unreachable
	%define	ENETRESET	102	; Network dropped connection because of reset
	%define	ECONNABORTED	103	; Software caused connection abort
	%define	ECONNRESET	104	; Connection reset by peer
	%define	ENOBUFS		105	; No buffer space available
	%define	EISCONN		106	; Transport endpoint is already connected
	%define	ENOTCONN	107	; Transport endpoint is not connected
	%define	ESHUTDOWN	108	; Cannot send after transport endpoint shutdown
	%define	ETOOMANYREFS	109	; Too many references: cannot splice
	%define	ETIMEDOUT	110	; Connection timed out
	%define	ECONNREFUSED	111	; Connection refused
	%define	EHOSTDOWN	112	; Host is down
	%define	EHOSTUNREACH	113	; No route to host
	%define	EALREADY	114	; Operation already in progress
	%define	EINPROGRESS	115	; Operation now in progress
	%define	ESTALE		116	; Stale file handle
	%define	EUCLEAN		117	; Structure needs cleaning
	%define	ENOTNAM		118	; Not a XENIX named type file
	%define	ENAVAIL		119	; No XENIX semaphores available
	%define	EISNAM		120	; Is a named type file
	%define	EREMOTEIO	121	; Remote I/O error
	%define	EDQUOT		122	; Quota exceeded
	%define	ENOMEDIUM	123	; No medium found
	%define	EMEDIUMTYPE	124	; Wrong medium type
	%define	ECANCELED	125	; Operation Canceled
	%define	ENOKEY		126	; Required key not available
	%define	EKEYEXPIRED	127	; Key has expired
	%define	EKEYREVOKED	128	; Key has been revoked
	%define	EKEYREJECTED	129	; Key was rejected by service
	; for robust mutexes
	%define	EOWNERDEAD	130	; Owner died
	%define	ENOTRECOVERABLE	131	; State not recoverable
	%define ERFKILL		132	; Operation not possible due to RF-kill
	%define EHWPOISON	133	; Memory page has hardware error
%endif


;
; Begin of string table to map string descriptions to the error numbers
;
%ifndef _ERRNO_STRINGS_INC_
%define _ERRNO_STRINGS_INC_
	section .rodata
		error_0:	db "Invalid errno number (errno 0)", 0x00
		error_1:	db "Operation not permitted (errno 1)", 0x00
		error_2:	db "No such file or directory (errno 2)", 0x00
		error_3:	db "No such process (errno 3)", 0x00
		error_4:	db "Interrupted system call (errno 4)", 0x00
		error_5:	db "I/O error (errno 5)", 0x00
		error_6:	db "No such device or address (errno 6)", 0x00
		error_7:	db "Argument list too long (errno 7)", 0x00
		error_8:	db "Exec format error (errno 8)", 0x00
		error_9:	db "Bad file number (errno 9)", 0x00
		error_10:	db "No child processes (errno 10)", 0x00
		error_11:	db "Try again (errno 11)", 0x00
		error_12:	db "Out of memory (errno 12)", 0x00
		error_13:	db "Permission denied (errno 13)", 0x00
		error_14:	db "Bad address (errno 14)", 0x00
		error_15:	db "Block device required (errno 15)", 0x00
		error_16:	db "Device or resource busy (errno 16)", 0x00
		error_17:	db "File exists (errno 17)", 0x00
		error_18:	db "Cross-device link (errno 18)", 0x00
		error_19:	db "No such device (errno 19)", 0x00
		error_20:	db "Not a directory (errno 20)", 0x00
		error_21:	db "Is a directory (errno 21)", 0x00
		error_22:	db "Invalid argument (errno 22)", 0x00
		error_23:	db "File table overflow (errno 23)", 0x00
		error_24:	db "Too many open files (errno 24)", 0x00
		error_25:	db "Not a typewriter (errno 25)", 0x00
		error_26:	db "Text file busy (errno 26)", 0x00
		error_27:	db "File too large (errno 27)", 0x00
		error_28:	db "No space left on device (errno 28)", 0x00
		error_29:	db "Illegal seek (errno 29)", 0x00
		error_30:	db "Read-only file system (errno 30)", 0x00
		error_31:	db "Too many links (errno 31)", 0x00
		error_32:	db "Broken pipe (errno 32)", 0x00
		error_33:	db "Math argument out of domain of func (errno 33)", 0x00
		error_34:	db "Math result not representable (errno 34)", 0x00
		error_35:	db "Resource deadlock would occur (errno 35)", 0x00
		error_36:	db "File name too long (errno 36)", 0x00
		error_37:	db "No record locks available (errno 37)", 0x00
		error_38:	db "Invalid system call number (errno 38)", 0x00
		error_39:	db "Directory not empty (errno 39)", 0x00
		error_40:	db "Too many symbolic links encountered (errno 40)", 0x00
		error_41:	db "Operation would block (errno 11)", 0x00  ; this errno number is actually errno 11 in the standards but f* it
		error_42:	db "No message of desired type (errno 42)", 0x00
		error_43:	db "Identifier removed (errno 43)", 0x00
		error_44:	db "Channel number out of range (errno 44)", 0x00
		error_45:	db "Level 2 not synchronized (errno 45)", 0x00
		error_46:	db "Level 3 halted (errno 46)", 0x00
		error_47:	db "Level 3 reset (errno 47)", 0x00
		error_48:	db "Link number out of range (errno 48)", 0x00
		error_49:	db "Protocol driver not attached (errno 49)", 0x00
		error_50:	db "No CSI structure available (errno 50)", 0x00
		error_51:	db "Level 2 halted (errno 51)", 0x00
		error_52:	db "Invalid exchange (errno 52)", 0x00
		error_53:	db "Invalid request descriptor (errno 53)", 0x00
		error_54:	db "Exchange full (errno 54)", 0x00
		error_55:	db "No anode (errno 55)", 0x00
		error_56:	db "Invalid request code (errno 56)", 0x00
		error_57:	db "Invalid slot (errno 57)", 0x00
	    error_58:	db "Bad error number (errno 58)", 0x00
		error_59:	db "Bad font file format (errno 59)", 0x00
		error_60:	db "Device not a stream (errno 60)", 0x00
		error_61:	db "No data available (errno 61)", 0x00
		error_62:	db "Timer expired (errno 62)", 0x00
		error_63:	db "Out of streams resources (errno 63)", 0x00
		error_64:	db "Machine is not on the network (errno 64)", 0x00
		error_65:	db "Package not installed (errno 65)", 0x00
		error_66:	db "Object is remote (errno 66)", 0x00
		error_67:	db "Link has been severed (errno 67)", 0x00
		error_68:	db "Advertise error (errno 68)", 0x00
		error_69:	db "Srmount error (errno 69)", 0x00
		error_70:	db "Communication error on send (errno 70)", 0x00
		error_71:	db "Protocol error (errno 71)", 0x00
		error_72:	db "Multihop attempted (errno 72)", 0x00
		error_73:	db "RFS specific error (errno 73)", 0x00
		error_74:	db "Not a data message (errno 74)", 0x00
		error_75:	db "Value too large for defined data type (errno 75)", 0x00
		error_76:	db "Name not unique on network (errno 76)", 0x00
		error_77:	db "File descriptor in bad state (errno 77)", 0x00
		error_78:	db "Remote address changed (errno 78)", 0x00
		error_79:	db "Can not access a needed shared library (errno 79)", 0x00
		error_80:	db "Accessing a corrupted shared library (errno 80)", 0x00
		error_81:	db ".lib section in a.out corrupted (errno 81)", 0x00
		error_82:	db "Attempting to link in too many shared libraries (errno 82)", 0x00
		error_83:	db "Cannot exec a shared library directly (errno 83)", 0x00
		error_84:	db "Illegal byte sequence (errno 84)", 0x00
		error_85:	db "Interrupted system call should be restarted (errno 85)", 0x00
		error_86:	db "Streams pipe error (errno 86)", 0x00
		error_87:	db "Too many users (errno 87)", 0x00
		error_88:	db "Socket operation on non-socket (errno 88)", 0x00
		error_89:	db "Destination address required (errno 89)", 0x00
		error_90:	db "Message too long (errno 90)", 0x00
		error_91:	db "Protocol wrong type for socket (errno 91)", 0x00
		error_92:	db "Protocol not available (errno 92)", 0x00
		error_93:	db "Protocol not supported (errno 93)", 0x00
		error_94:	db "Socket type not supported (errno 94)", 0x00
		error_95:	db "Operation not supported on transport endpoint (errno 95)", 0x00
		error_96:	db "Protocol family not supported (errno 96)", 0x00
		error_97:	db "Address family not supported by protocol (errno 97)", 0x00
		error_98:	db "Address already in use (errno 98)", 0x00
		error_99:	db "Cannot assign requested address (errno 99)", 0x00
		error_100:	db "Network is down (errno 100)", 0x00
		error_101:	db "Network is unreachable (errno 101)", 0x00
		error_102:	db "Network dropped connection because of reset (errno 102)", 0x00
		error_103:	db "Software caused connection abort (errno 103)", 0x00
		error_104:	db "Connection reset by peer (errno 104)", 0x00
		error_105:	db "No buffer space available (errno 105)", 0x00
		error_106:	db "Transport endpoint is already connected (errno 106)", 0x00
		error_107:	db "Transport endpoint is not connected (errno 107)", 0x00
		error_108:	db "Cannot send after transport endpoint shutdown (errno 108)", 0x00
		error_109:	db "Too many references: cannot splice (errno 109)", 0x00
		error_110:	db "Connection timed out (errno 110)", 0x00
		error_111:	db "Connection refused (errno 111)", 0x00
		error_112:	db "Host is down (errno 112)", 0x00
		error_113:	db "No route to host (errno 113)", 0x00
		error_114:	db "Operation already in progress (errno 114)", 0x00
		error_115:	db "Operation now in progress (errno 115)", 0x00
		error_116:	db "Stale file handle (errno 116)", 0x00
		error_117:	db "Structure needs cleaning (errno 117)", 0x00
		error_118:	db "Not a XENIX named type file (errno 118)", 0x00
		error_119:	db "No XENIX semaphores available (errno 119)", 0x00
		error_120:	db "Is a named type file (errno 120)", 0x00
		error_121:	db "Remote I/O error (errno 121)", 0x00
		error_122:	db "Quota exceeded (errno 122)", 0x00
		error_123:	db "No medium found (errno 123)", 0x00
		error_124:	db "Wrong medium type (errno 124)", 0x00
		error_125:	db "Operation Canceled (errno 125)", 0x00
		error_126:	db "Required key not available (errno 126)", 0x00
		error_127:	db "Key has expired (errno 127)", 0x00
		error_128:	db "Key has been revoked (errno 128)", 0x00
		error_129:	db "Key was rejected by service (errno 129)", 0x00
		error_130:	db "Owner died (errno 130)", 0x00
		error_131:	db "State not recoverable (errno 131)", 0x00
		error_132:	db "Operation not possible due to RF-kill (errno 132)", 0x00
		error_133:	db "Memory page has hardware error (errno 133)", 0x00

	section .data
		; indicator for out-of-bounds checking 
		global sys_max_errno
		sys_max_errno: equ 133

		; list for indexing the errno strings given the errno number
		; indexing via [sys_errno_map+errno*8] + out-of-bounds checks
		global sys_errno_map
		sys_errno_map:
			dq error_0
			dq error_1
			dq error_2
			dq error_3
			dq error_4
			dq error_5
			dq error_6
			dq error_7
			dq error_8
			dq error_9
			dq error_10
			dq error_11
			dq error_12
			dq error_13
			dq error_14
			dq error_15
			dq error_16
			dq error_17
			dq error_18
			dq error_19
			dq error_20
			dq error_21
			dq error_22
			dq error_23
			dq error_24
			dq error_25
			dq error_26
			dq error_27
			dq error_28
			dq error_29
			dq error_30
			dq error_31
			dq error_32
			dq error_33
			dq error_34
			dq error_35
			dq error_36
			dq error_37
			dq error_38
			dq error_39
			dq error_40
			dq error_41
			dq error_42
			dq error_43
			dq error_44
			dq error_45
			dq error_46
			dq error_47
			dq error_48
			dq error_49
			dq error_50
			dq error_51
			dq error_52
			dq error_53
			dq error_54
			dq error_55
			dq error_56
			dq error_57
			dq error_58
			dq error_59
			dq error_60
			dq error_61
			dq error_62
			dq error_63
			dq error_64
			dq error_65
			dq error_66
			dq error_67
			dq error_68
			dq error_69
			dq error_70
			dq error_71
			dq error_72
			dq error_73
			dq error_74
			dq error_75
			dq error_76
			dq error_77
			dq error_78
			dq error_79
			dq error_80
			dq error_81
			dq error_82
			dq error_83
			dq error_84
			dq error_85
			dq error_86
			dq error_87
			dq error_88
			dq error_89
			dq error_90
			dq error_91
			dq error_92
			dq error_93
			dq error_94
			dq error_95
			dq error_96
			dq error_97
			dq error_98
			dq error_99
			dq error_100
			dq error_101
			dq error_102
			dq error_103
			dq error_104
			dq error_105
			dq error_106
			dq error_107
			dq error_108
			dq error_109
			dq error_110
			dq error_111
			dq error_112
			dq error_113
			dq error_114
			dq error_115
			dq error_116
			dq error_117
			dq error_118
			dq error_119
			dq error_120
			dq error_121
			dq error_122
			dq error_123
			dq error_124
			dq error_125
			dq error_126
			dq error_127
			dq error_128
			dq error_129
			dq error_130
			dq error_131
			dq error_132
			dq error_133

%endif