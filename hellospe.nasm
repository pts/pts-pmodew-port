;
; hellospe.nasm: a 32-bit DOS-extended hello-world program using the simple PE builder
; by pts@fazekas.hu at Sat Nov  7 03:16:44 CET 2026
;
; Compile with: nasm -O32700 -w+orphan-labels -o hellospe.exe hellospe.nasm
; Minimum NASM version needed: 0.98.39
;

%define SPE_EntryPoint _start  ; Activate the simple PE builder.
%include 'pmodew.nasm'

_start:
		spe_pic_delta_to ebp
		mov ah, 9  ; Print '$'-terminated message starting at EDX.
		lea edx, [ebp+msg]  ; +EBP for position-independent code.
		int 0x21  ; DOS-extended syscall.
		mov ax, 0x4c00  ; Exit successfully.
		int 0x21  ; DOS-extended syscall.

msg:		db 'Hello, World!', 13, 10, '$'

spe_end
