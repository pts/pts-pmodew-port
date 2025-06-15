;
; pmwca.c: PMODE/W stub compressor, 8086 assembly implementation, as a DOS .com program
; by pts@fazekas.hu at Sat Jun 14 11:40:42 CEST 2025
;
; Compile with: nasm -O0 -w+orphan-labels -DUEXEFN="'pmodewu.exe'" -DDEBUG -o pmwca.com pmwca.nasm
; Minimum NASM version needed: 0.98.39
;
; End-to-end check: nasm-0.98.39 -O0 -w+orphan-labels -f bin -DUEXEFN="'pmodewu.exe'" -DDEBUG -o pmwca.com pmwca.nasm && time ~/prg/kvikdos/kvikdos pmwca.com >pmwca.log && diff pmodewc.lde.log pmwca.log && echo OK
;
; !! This implementation is incomplete. It only implements the LZSS-based data compression. It doesn't have any DOS .exe header processing.
; !! speed optimization: For compress, add a lookup table which finds the previous occurrence of a word (2 bytes) in O(1) time.
;

bits 16
cpu 8086
BASE equ 0x100  ; DOS .com program base `org' value, the first program byte is loaded to this offset.
org BASE

LF equ 10
MAX_LENGTH equ 270
MAX_DISTANCE_FOR_LENGTH_2 equ 0x800-1
MAX_DISTANCE equ 0x1000-1

start:		call compress
		ret

%ifdef DEBUG
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
.ax:		call print_ax
		mov al, LF
		int 0x29
		pop ax
		ret

print_length:	push ax
		mov al, 'E'
		int 0x29
		mov ax, cx
		jmp short print_distance.ax
%endif

compress:	mov si, udata
		jmp strict near .literal  ; Assume that the first byte was copied as a literal. Skip over it here.
.done:		ret
.next_byte:	mov cx, udata.end
		sub cx, si
		jz short .done
		cmp cx, MAX_LENGTH
		jb .cx_ok
		mov cx, MAX_LENGTH
.cx_ok:		; CX will keep holding the maximum match length starting at DS:SI, until the next .next_byte (i.e. when SI is increased).
		mov di, si
		xor dx, dx  ; Best length so far. No need to initialize BP (best distance) here.
		mov ax, -1  ; Current distance.
		; Registers through the .next_start loop below:
		; * AX, BX: scratch.
		; * CX: maximum match length starting at DS:SI. Remains until the next .next_byte (i.e. right after SI is increased).
		; * DX: best (longest) match length so far.
		; * DS:SI: points to the current byte of the udata to compress. Remains unchanged until .got_literal_or_match.
		; * DS:DI: points to the first byte of the next match candidate (DI <= SI).
		; * BP: best distance corresponding to the length in the best match so far.
.next_start:	dec di  ; Update match start.
		inc ax  ; Update current distance.
		cmp ax, strict word MAX_DISTANCE
		ja short .got_literal_or_match  ; If distance is too large, then ignore the match and all possible larger-distance matches.
		push cx  ; Save.
		mov cx, MAX_DISTANCE
		sub cx, ax
		lea bx, [word di-(udata-1-$$+BASE)]  ; Shorter form of `mov bx, di' ++ `sub bx, strict word udata-1'.
		cmp bx, cx
		jae .cx_ok2
		mov cx, bx  ; CX := min(MAX_DISTANCE-AX, DI-(udata-1)).
.cx_ok2:	xchg bx, ax  ; BX := AX; AX := junk.
		add bx, di
		mov al, [si]  ; First byte.
		std
		repne scasb  ; Try to find the first byte backward which matches the first byte (AL).
		cld
		pop cx  ; Restore.
		jne short .got_literal_or_match
.found_first_byte:
		inc di
		sub bx, di
		xchg ax, bx  ; AX := BX (distance); BX := junk.
.find_common_prefix_length:
		; Finds the (longest) common prefix length of the CX bytes starting at DS:SI and ES:DI.
		; Input: DS:SI points to byte string a, ES:DI points to byte string b, CX: number of bytes.
		; Output: BX: longest common prefix length.
		; Ruins: FLAGS, CX.
		push si  ; Save.
		push di  ; Save.
		mov bx, cx
		repe cmpsb  ; Also reads and modifies SI, DI and CX.
		je short .after_inc
		inc cx
.after_inc:	xchg bx, cx  ; CX := maximum match length starting at DS:SI.
		sub bx, cx
		neg bx  ; BX := longest common prefix length.
		pop di  ; Restore.
		pop si  ; Restore.
		cmp bx, byte 2
		ja short .longer_than_2
		cmp ax, strict word MAX_DISTANCE_FOR_LENGTH_2
		ja short .keep_best  ; Ignore the match if distance is too large.
.longer_than_2:	cmp bx, dx
		jb short .keep_best  ; Ignore the match if shorter than the previous best match.
		ja short .new_best  ; Save match as best match if longer than the previous match.
		; Now we have the complicated case of the match (with
		; distance AX) with the same length (BX == DX) as a previous
		; match (with distance BP; BP < AX).
		;
		; We want to use this match as new best iff its bitstream
		; will be of the same number of bits (not longer) as the
		; previous match of the same size. The condition:
		;
		;   BX == 2 ? (BP > 0xfe || AX <= 0xfe) : (BP > 0x3ff || AX <= (BP <= 0xff ? 0xff : 0x3ff)).
		cmp bx, byte 2
		ja short .check_eq_length_3plus
.check_eq_length_2:
		cmp bp, 0xfe
		ja short .new_best
		cmp ax, 0xfe
		jmp short .check_eq_cjmp
.check_eq_length_3plus:
		cmp bp, 0x3ff
		ja short .new_best
		cmp bp, 0xff
		ja .check_eq_length_3plus_large_distance
.check_eq_length_3plus_small_distance:
		cmp ax, 0xff
		jmp short .check_eq_cjmp
.check_eq_length_3plus_large_distance:
		cmp ax, 0x3ff
.check_eq_cjmp:
		ja short .keep_best
.new_best:	mov dx, bx  ; Found longer length. Update best length.
		mov bp, ax  ; Update distance corresponding to best length.
.keep_best:	cmp di, udata
		jne short .next_start
.got_literal_or_match:
		cmp dx, byte 2
		jae short .match
.literal:
%ifdef DEBUG
		call print_literal
%endif
		inc si  ; Skip over literal byte in udata.
		jmp short .cont
.match:
		add si, dx  ; Skip over matched bytes in udata.
%ifdef DEBUG
		mov cx, dx
		call print_length  ; In CX.
		mov bx, bp
		call print_distance  ; In BX.
%endif
.cont:		jmp near .next_byte

udata:		incbin UEXEFN, 0x200
.end:

absolute $
		resb ($-$$)&1
_bss:
cdata:
