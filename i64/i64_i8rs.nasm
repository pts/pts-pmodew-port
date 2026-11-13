bits 32
cpu 386
section _TEXT  USE32 class=CODE align=1

global __I8RS
__I8RS:  ; long long __watcall_but_ruins_ecx __I8RS(long long a, int b) { return a >> b; }
; Input: EDX:EAX == a; EBX == b.
; Output: EDX:EAX == ((long long)a >> b); EBX == b; ECX == junk.
		mov ecx, ebx
		;and cl, 0x3f  ; Not needed, CL&0x1f is used by shift instructions.
		test cl, 0x20
		jnz short .2
		shrd eax, edx, cl
		sar edx, cl
		ret
.2:		mov eax, edx
		;sub cl, 0x20  ; Not needed, CL&0x1f is used by shift instructions.
		sar edx, 0x1f
		sar eax, cl
		ret
