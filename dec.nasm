;
; dec.nasm: decompressor for the PMODE/W 1.33 stub and PMWLITE (both 1.33 and 1.34), as a DOS 8086 .com program
; by pts@fazekas.hu at Wed Jun 11 15:48:16 CEST 2025
;

%ifndef COMPRESS_BITS
  %error ERROR_MISSING_COMPRESS_BITS
  db 1/0
%else
  %assign COMPRESS_BITS COMPRESS_BITS
  %if COMPRESS_BITS!=16
    %error ERROR_UNSUPPORTED_COMPRESS_BITS COMPRESS_BITS
  %endif
%endif

%ifndef COMPRESS_BITREV
  %error ERROR_MISSING_COMPRESS_BITREV
  db 1/0
%else
  %assign COMPRESS_BITREV COMPRESS_BITREV
  %if COMPRESS_BITREV!=1
    %error ERROR_UNSUPPORTED_COMPRESS_BITREV COMPRESS_BITREV
  %endif
%endif

%ifndef COMPRESS_M1BITFIRST
  %error ERROR_MISSING_COMPRESS_M1BITFIRST
  db 1/0
%else
  %assign COMPRESS_M1BITFIRST COMPRESS_M1BITFIRST
%endif

%ifndef COMPRESS_EARLYNEXTBLOCK
  %error ERROR_MISSING_COMPRESS_EARLYNEXTBLOCK
  db 1/0
%else
  %assign COMPRESS_EARLYNEXTBLOCK COMPRESS_EARLYNEXTBLOCK
%endif

%ifndef CEXEFN
  %error ERROR_MISSING_CEXEFN
  db 1/0
  ;%define CEXEFN 'pmodewc.exe'
%endif

%define DEBUG 1

bits 16
cpu 8086
org 0x100

LF equ 10

udata: equ $-0x100-0x80+0x10000-0x5000  ; At most 0x5000 bytes (20 KiB) of uncompressed data.

start:		mov si, cdata
		mov di, udata
		jmp short decompress

%if DEBUG
print_nibble:	push ax
		add al, '0'
		cmp al, '9'
		jna short .ok
		add al, 'a'-'0'-10
.ok:		int 0x29
		pop ax
		ret

print_al:	push ax
		aam 0x10
		xchg al, ah
		call print_nibble
		mov al, ah
		call print_nibble
		pop ax
		ret

print_ax:
		push ax
		xchg al, ah
		call print_al
		mov al, ah
		call print_al
		pop ax
		ret

print_block:	push ax
		mov al, 'W'
		int 0x29
		pop ax
		push ax
.ax:		call print_ax
		mov al, LF
		int 0x29
		pop ax
		ret

print_literal:	push ax
		mov al, 'L'
		int 0x29
		mov al, [si]
		call print_al
		mov al, LF
		int 0x29
		pop ax
		ret

print_distance:	push ax
		mov al, 'D'
		int 0x29
		mov ax, bx
		jmp short print_block.ax

print_length:	push ax
		mov al, 'E'
		int 0x29
		mov ax, cx
		jmp short print_block.ax

print_m1:	pushf  ; Save because COMPRESS_M1BITFIRST needs the value of CF after this call.
		push ax
		mov al, 'X'
		int 0x29
		pop ax
		push ax
		call print_al
		mov al, LF
		int 0x29
		pop ax
		popf
		ret

print_m1101:	push ax
		mov al, 'Y'
		int 0x29
		pop ax
		push ax
		call print_al
		mov al, LF
		int 0x29
		pop ax
		ret
%endif

; --- PMWLITE-like decompressor.

decompress:
%if DEBUG
		call print_literal
%endif
		movsb  ; Copy initial literal token.
		lodsw  ; AX := initial 16-bit block (tag) word value.
%if DEBUG
		call print_block
%endif
		mov bp, ax  ; BP will keep holding the block word throught decompression. `xchg bp, ax' would have been shorter.
		mov dl, 0x10  ; DL will keep holding the Number of bits remaining in the block word (BP). Starting at 0x10 == 16.
		jmp short .next_token
.get_bit:
%if COMPRESS_EARLYNEXTBLOCK
		shr bp, 1  ; CF := the first bit in a block to be used is its lowest bit.
		dec dl  ; Doesn't modify CF.
		jnz .get_bit.ret
  %if DEBUG
		lodsw
  %endif
		mov bp, ax  ; `xchg bp, ax' would have been shorter here.
		mov dl, 0x10  ; Again, 0x10 == 16 are available in BP.
%else
		sub dl, 0x1
		jnc short .skip
		mov dl, 0xf
		lodsw
  %if DEBUG
		call print_block
  %endif
		xchg ax, bp
.skip:		shr bp, 1
%endif
.get_bit.ret:
%if DEBUG
		pushf
		mov al, 'B'
		int 0x29
		mov al, '0'
		adc al, 0
		int 0x29
		mov al, LF
		int 0x29
		popf
%endif
		ret
.match_1_1:
		call .get_bit
		jnc short .match_1_1_0
.match_1_1_1:
		call .get_bit
		adc cl, 0x1
		shl cl, 1
.match_1_1_1.next:
		call .get_bit
		rcl bh, 1
		loop .match_1_1_1.next  ; Then falls through to .match_1_1_0.
.match_1_1_0:
		mov dh, 0x2
		mov cl, 0x4
.match_1_1_0.next:
		inc dh
		call .get_bit
		jc short .copy_match_count_dh
		loop .match_1_1_0.next
		call .get_bit
		jnc short .match_1_1_0_0
.match_1_1_0_1:
		lodsb
%if DEBUG
		call print_m1101
%endif
		mov cl, al
		add cx, byte 0xf
		jmp short .copy_match
.match_1_1_0_0:
		xor dh, dh
		mov cl, 0x3
.match_1_1_0_0.next:
		call .get_bit
		rcl dh, 1
		loop .match_1_1_0_0.next
		add dh, 0x7
.copy_match_count_dh:
		mov cl, dh
		jmp short .copy_match
.copy_match_2_bytes:
		mov cl, 0x2  ; CX := 2. Assumes CH == 0. Falls through to .copy_match.
.copy_match:  ; Copies a match with (distance, length) == (BX, CX). The distance 0 means: copy the previously emitted byte (at [ES:DI-1]).
%if DEBUG
		call print_length  ; In CX.
		call print_distance  ; In BX.
%endif
		neg bx  ; BX := -orig_distance.
		dec bx  ; BX := -orig_distance - 1.
.copy_match.next:
		mov al, [es:bx+di]
		stosb
		loop .copy_match.next
.next_token:
		call .get_bit
		jc short .match_1
.literal_0:  ; Indicated by CF==0.
%if DEBUG
		call print_literal
%endif
		movsb  ; Copy literal byte from byte stream.
		jmp short .next_token
.match_1:  ; Indicated by CF==1.
		xor bx, bx
%if COMPRESS_M1BITFIRST
		call .get_bit
%endif
		lodsb  ; Get distance byte. Keeps CF intact.
  %if DEBUG
		call print_m1  ; Keeps CF intact.
  %endif
		mov bl, al  ; BX (distance) := AL.  Keeps CF intact.
%if COMPRESS_M1BITFIRST==0
		call .get_bit
%endif
		jc short .match_1_1
.match_1_0:
		call .get_bit
		jc short .match_1_0_1
.match_1_0_0:
		sub bl, 1
		jc short after_decompress
		jmp short .copy_match_2_bytes
.match_1_0_1:
		mov cl, 0x3
.match_1_0_1.next:
		call .get_bit
		rcl bh, 1
		loop .match_1_0_1.next
		jmp short .copy_match_2_bytes

after_decompress: ret

cdata:		incbin CEXEFN, 0x142, 11110

%if $-udata>0
  %error ERROR_COMPRESSED_DATA_TOO_LARGE
  db 1/0
%endif
