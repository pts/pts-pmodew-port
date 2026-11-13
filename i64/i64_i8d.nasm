bits 32
cpu 386
section _TEXT  USE32 class=CODE align=1

global __I8D
__I8D:
; Divides (signed) EDX:EAX by ECX:EBX, stores the result in EDX:EAX and the modulo in ECX:EBX.
; Keeps other registers (except for EFLAGS) intact.
extern __U8D
		or edx, edx
		js short .2
		or ecx, ecx
		js short .1
		jmp strict near __U8D  ; NASM linking could make this jump shorter, smart linking can't.
.1:		neg ecx
		neg ebx
		sbb ecx, byte 0
		call __U8D
		jmp short .4
.2:		neg edx
		neg eax
		sbb edx, byte 0
		or ecx, ecx
		jns short .3
		neg ecx
		neg ebx
		sbb ecx, byte 0
		call __U8D
		neg ecx
		neg ebx
		sbb ecx, byte 0
		ret
.3:		call __U8D
		neg ecx
		neg ebx
		sbb ecx, byte 0
.4:		neg edx
		neg eax
		sbb edx, byte 0
		ret
