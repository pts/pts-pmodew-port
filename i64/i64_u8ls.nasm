bits 32
cpu 386
section _TEXT  USE32 class=CODE align=1

global __I8LS
global __U8LS
__I8LS:  ; long long __watcall_but_ruins_ecx __I8LS(long long a, int b) { return a << b; }
__U8LS:  ; unsigned long long __watcall_but_ruins_ecx __U8LS(unsigned long long a, int b) { return a << b; }
; Input: EDX:EAX == a; EBX == b.
; Output: EDX:EAX == (a << b); EBX == b; ECX == junk.
		mov ecx, ebx
		;and cl, 0x3f  ; Not needed, CL&0x1f is used by shift instructions.
		test cl, 0x20
		jnz short .3
		shld edx, eax, cl
		shl eax, cl
		ret
.3:		mov edx, eax
		;sub cl, 0x20  ; Not needed, CL&0x1f is used by shift instructions.
		xor eax, eax
		shl edx, cl
		ret
