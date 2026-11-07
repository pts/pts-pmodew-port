;
; helluspe.nasm: a nontrivial 32-bit DOS-extended program using the simple PE builder
; by pts@fazekas.hu at Sat Nov  7 03:16:44 CET 2026
;
; Compile with: nasm -O32700 -w+orphan-labels -o helluspe.exe helluspe.nasm
; Minimum NASM version needed: 0.98.39
;
; This program prints a hello-world message, but it puts additional
; underscores ('_') in front of the exclamaation martk ('!'): one underscore
; for each character on the command line.
;

%ifndef USEBSS  ; Can be specified on the command line. This is part of configuration of helluspe.nasm.
  %define USEBSS 1   ; Use BSS for zero-initialized variables, omit the NUL bytes from the .exe file.
  ;%define USEBSS 0  ; Use explicit NUL bytes in the .exe file for zero-initialized variables.
%elifidn (USEBSS), ()
  %define USEBSS 1
%else
  %assign USEBSS USEBSS  ; Make sure it's an integer (expression), convert it to integer constant.
%endif

%ifndef FN83  ; Can be specified on the command line.
  %define FN83 0   ; Use long filenames in %include, i.e. .nasm extension.
  ;%define FN83 1  ; Use 8.3 filenames in %include, i.e. .nas extension.
%elifidn (FN83), ()
  %define FN83 1
%else
  %assign FN83 FN83  ; Make sure it's an integer (expression), convert it to integer constant.
%endif
%define SPE_EntryPoint _start  ; Activate the simple PE builder.
%define PM_MAXEXTMEM 0x10000 ; 64 KiB. Is smaller also enough?
;%define SPEDOSONLY 0  ; To make the PE header valid.
%if FN83
  %include 'pmodew.nas'
%else
  %include 'pmodew.nasm'
%endif

msg2:		db '!', 13, 10, '$'  ; We can mix code and data, so we start with data.

_start:
		; DPMI (int 0x31) services are also available here, but we don't use them.
		spe_pic_delta_to ebp
		push eax  ; Save address of PSP.
.print_msg1:
		mov ah, 9  ; Print '$'-terminated message starting at EDX.
		lea edx, [ebp+msg1]
		int 0x21  ; DOS-extended syscall.
.print_additional_underscores:
		pop esi  ; Restore ESI := address of PSP.
		sub esi, byte -80h  ; ESI := address of DOS command-line string.
		inc esi  ; Skip over length byte.
.whitespace_loop:
		lodsb  ; `cld' has been done by the simple PE loader.
		cmp al, ' '
		je short .whitespace_loop
		cmp al, 9  ; TAB.
		je short .whitespace_loop
		cmp al, 13  ; CR, terminator.
		je short .print_additional_underscores_done
		dec esi  ; Go back to the first non-whitespace character.
		lea edi, [ebp+underscores]
.collect_underscores_loop:  ; Print an underscore for each character on the command line.
		lodsb
		cmp al, 13  ; CR, terminator.
		je short .collect_underscores_done
%if 0  ; We could print a character here, but we don't want to. We want to demonstrate the usage of BSS by using the variable named underscores.
		mov ah, 2  ; Print character in DL.
		mov dl, '+'
		int 21h  ; DOS-extended syscall.
%endif
		add byte [edi], '_'  ; This deliberately relies on the fact that BSS is zero-initialized.
		inc edi
		jmp short .collect_underscores_loop
.collect_underscores_done:
		mov al, '$'
		stosb
		mov ah, 9  ; Print '$'-terminated message starting at EDX.
		lea edx, [ebp+underscores]
		int 0x21  ; DOS-extended syscall.
.print_additional_underscores_done:
.print_msg2:
		mov ah, 9  ; Print '$'-terminated message starting at EDX.
		lea edx, [ebp+msg2]
		int 0x21  ; DOS-extended syscall.
		mov ax, 0x4c00  ; Exit successfully.
		int 0x21  ; DOS-extended syscall.
		; Not reached.

msg1:		db 'Hello, World', '$'

%if USEBSS
  spe_bss
  underscores:	resb 0x80        ; This buffer is large enough, because the DOS command-line string is shorter than 0x80 bytes.
%else
  underscores:	times 0x80 db 0  ; This buffer is large enough, because the DOS command-line string is shorter than 0x80 bytes.
%endif

spe_end
