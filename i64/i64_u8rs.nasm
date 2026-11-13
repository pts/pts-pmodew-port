bits 32
cpu 386
section _TEXT  USE32 class=CODE align=1

global __U8RS
__U8RS:  ; unsigned long long __watcall_but_ruins_ecx __U8RS(unsigned long long a, int b) { return a >> b; }
; Input: EDX:EAX == a; EBX == b.
; Output: EDX:EAX == ((unsigned long long)a >> b); EBX == b; ECX == junk.
		mov ecx, ebx
		;and cl, 0x3f  ; Not needed, CL&0x1f is used by shift instructions.
		test cl, 0x20
		jnz short .1
		shrd eax, edx, cl
		shr edx, cl
		ret
.1:		mov eax, edx
		;sub ecx, byte 0x20  ; Not needed, CL&0x1f is used by shift instructions.
		xor edx, edx
		shr eax, cl
		ret
