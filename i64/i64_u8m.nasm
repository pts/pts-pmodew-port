bits 32
cpu 386
section _TEXT  USE32 class=CODE align=1

global __I8M
global __U8M
__I8M:
__U8M:  ; Multiplies (sign doesn't matter) EDX:EAX by ECX:EBX, stores the product in EDX:EAX.
		test edx, edx
		jne short .1
		test ecx, ecx
		jne short .1
		mul ebx
		ret
.1:		push eax
		push edx
		mul ecx
		mov ecx, eax
		pop eax
		mul ebx
		add ecx, eax
		pop eax
		mul ebx
		add edx, ecx
		ret
