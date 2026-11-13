bits 32
cpu 386
section _TEXT  USE32 class=CODE align=1

global __U8D
__U8D:
; Divides (unsigned) EDX:EAX by ECX:EBX, stores the result in EDX:EAX and the modulo in ECX:EBX.
; Keeps other registers (except for EFLAGS) intact.
		or ecx, ecx
		jnz short .6		; Is ECX nonzero (divisor is >32 bits)? If yes, then do it the slow and complicated way.
		dec ebx
		jz short .5		; Is the divisor 1? Then just return the dividend as the result in EDX:EAX, and return 0 as the module on ECX:EBX.
		inc ebx
		cmp ebx, edx
		ja short .4		; Is the high half of the dividend (EDX) smaller than the divisor (EBX)? If yes, then the high half of the result (EDX) will be zero, and just do a 64bit/32bit == 32bit division (single `div' instruction at .4).
		mov ecx, eax
		mov eax, edx
		sub edx, edx
		div ebx
		xchg eax, ecx
.4:		div ebx			; Store the result in EAX and the modulo in EDX.
		mov ebx, edx		; Save the low half of the modulo to its final location (EBX).
		mov edx, ecx		; Set the high half of the result (either to 0 or based on the `div' above).
		sub ecx, ecx		; Set the high half of the modulo to 0 (because the divisor is 32-bit).
.5:		ret			; Early return if the divisor fits to 32 bits.
.6:		cmp ecx, edx
		jb short .8
		jne short .7
		cmp ebx, eax
		ja short .7
		sub eax, ebx
		mov ebx, eax
		sub ecx, ecx
		sub edx, edx
		mov eax, 1
		ret
.7:		sub ecx, ecx
		sub ebx, ebx
		xchg eax, ebx
		xchg edx, ecx
		ret
.8:		push ebp
		push esi
		push edi
		sub esi, esi
		mov edi, esi
		mov ebp, esi
.9:		add ebx, ebx
		adc ecx, ecx
		jb short .12
		inc ebp
		cmp ecx, edx
		jb short .9
		ja short .10
		cmp ebx, eax
		jbe short .9
.10:		clc
.11:		adc esi, esi
		adc edi, edi
		dec ebp
		js short .15
.12:		rcr ecx, 1
		rcr ebx, 1
		sub eax, ebx
		sbb edx, ecx
		cmc
		jb short .11
.13:		add esi, esi
		adc edi, edi
		dec ebp
		js short .14
		shr ecx, 1
		rcr ebx, 1
		add eax, ebx
		adc edx, ecx
		jae short .13
		jmp short .11
.14:		add eax, ebx
		adc edx, ecx
.15:		mov ebx, eax
		mov ecx, edx
		mov eax, esi
		mov edx, edi
		pop edi
		pop esi
		pop ebp
		ret
