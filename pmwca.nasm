;
; pmwca.c: PMODE/W stub compressor, 8086 assembly implementation, as a DOS .com program
; by pts@fazekas.hu at Sat Jun 14 11:40:42 CEST 2025
;
; Compile with: nasm -O0 -w+orphan-labels -DUEXEFN="'pmodewu.exe'" -DDEBUG -o pmwca.com pmwca.nasm
; Minimum NASM version needed: 0.98.39
;
; End-to-end check: nasm-0.98.39 -O0 -w+orphan-labels -f bin -DUEXEFN="'pmodewu.exe'" -o pmwca.com pmwca.nasm && time ~/prg/kvikdos/kvikdos pmwca.com >pmwca.out && cmp pmodewc.lit.out pmwca.out && echo OK
; End-to-end check: nasm-0.98.39 -O0 -w+orphan-labels -f bin -DUEXEFN="'pmodewu.exe'" -DDEBUG -o pmwca.com pmwca.nasm && time ~/prg/kvikdos/kvikdos pmwca.com >pmwca.log && <pmwca.log grep '^[BLDE]' >pmwca.blde.log && diff pmodewc.blde.log pmwca.blde.log && echo OK
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

start:		mov si, udata
		mov cx, udata.end
		mov di, cdata
		call compress
%ifndef DEBUG
		mov ah, 0x40  ; Write to file using handle.
		mov bx, 1  ; STDOUT_FILENO.
		mov dx, cdata  ; DS:DI == pointer to start of buffer to be written.
		mov cx, di
		sub cx, dx  ; CX := DI - cdata. CX == number of bytes to write.
		int 0x21  ; DOS syscall.
%endif
		ret  ; Exit successfully (EXIT_SUCCESS) from DOS .com program.

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
.ax:		pop ax
		push ax
		call print_ax
.lf:		mov al, LF
		int 0x29
		pop ax
		ret

print_length:	push ax
		mov al, 'E'
		int 0x29
		jmp short print_distance.ax

; Prints the bit in CF. Also ruins CF.
print_bit:	push ax
		pushf
		mov al, 'B'
		int 0x29
		mov al, '0'
		popf
		adc al, 0
		int 0x29
		jmp short print_distance.lf

print_m1:	push ax
		mov al, 'X'
		int 0x29
.al:		pop ax
		push ax
		call print_al
		jmp short print_distance.lf

print_m1101:	push ax
		mov al, 'Y'
		int 0x29
		jmp short print_m1.al
%endif

; Compresses bytes starting at DS:SI == ES:SI until DS:CX == ES:CX (CX is
; not a byte count, but an offset!), writing the compressed stream to DS:DI
; == ES:DI, using a variant of LZSS. The input must not be empty.
;
; Output: DS:DI == ES:DI: offset of the end of the compressed output data.
;         DS:SI == ES:SI: offset of the start of the uncompressed input data (same as input).
;         DS:CX == ES:CX: offset of the end of the uncompressed input data (same as input).
; Ruins: AX, BX, DX, DI, BP, FLAGS.
; !! Check for overflow when populating cdata.
compress:	push cx  ; Save offset of the end of the uncompressed input data (udata_end). Remains constant throughout the function.
		movsb  ; Uses DS:SI and ES:DI. Copy literal byte to compressed output data.
		push di  ; Save offset of the end of the compressed output data (cdata_end == cdata_cur). Will be incremented throughout the function.
		dec si
		push si  ; Save offset of the start of the uncompressed input data (udata_start). Remains constant throughout the function.
%ifdef DEBUG
		call print_literal  ; Value: `byte [si]'.
%endif
		inc si  ; Skip over literal byte in the uncompressed input data.
		jmp strict near .next_byte
		; Registers through the .next_start loop below:
		; * AX, BX: scratch.
		; * CX: maximum match length starting at DS:SI. Remains until the next .next_byte (i.e. right after SI is increased).
		; * DX: best (longest) match length so far.
		; * DS:SI == ES:SI: points to the current byte of the udata to compress. Remains unchanged until .got_literal_or_match.
		; * DS:DI == ES:DI: points to the first byte of the next match candidate (DI <= SI).
		; * BP: best distance corresponding to the length in the best match so far.
.next_start:	dec di  ; Update match start.
		inc ax  ; Update current distance.
		cmp ax, strict word MAX_DISTANCE
		ja short .got_literal_or_match  ; If distance is too large, then ignore the match and all possible larger-distance matches.
		pop bx  ; Restore BX := udata_start.
		push bx  ; Save udata_start.
		push cx  ; Save.
		mov cx, MAX_DISTANCE
		sub cx, ax
		sub bx, di
		neg bx
		inc bx  ; BX := DI-(udata_start-1).
		cmp bx, cx
		jae short .cx_ok2
		mov cx, bx  ; CX := min(MAX_DISTANCE-AX, DI-(udata_start-1)).
.cx_ok2:	xchg bx, ax  ; BX := AX; AX := junk.
		add bx, di
		mov al, [si]  ; First byte.
		std
		repne scasb  ; Uses ES:DI. Try to find the first byte backward which matches the first byte (AL).
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
		repe cmpsb  ; Uses DS:SI and ES:DI. Also reads and modifies SI, DI and CX.
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
.keep_best:	pop bx  ; Restore BX := udata_start.
		push bx  ; Save udata_start.
		cmp di, bx
		jne short .next_start
.got_literal_or_match:
		cmp dx, byte 2
		jae short .match
.literal:
%ifdef DEBUG
		clc
		call print_bit
		call print_literal
%endif
		;mov bp, sp  ; !! Do this in .got_literal_or_match, with some `xchg bp, ...'.
		;mov di, [bp+1*2]  ; cdata_end == cdata_cur.
		pop bx  ; Restore BX := udata_start. Will be used only for `push bx' below.
		pop di  ; Restore DI := cdata_end == cdata_cur.
		movsb  ; Copies literal byte from DS:SI to ES:DI. Also skips over literal byte in the uncompressed input data (SI += 1).
		push di  ; Save cdata_end == cdata_cur.
		push bx  ; Save udata_start.
		jmp short .next_byte
.match:
		add si, dx  ; Skip over matched bytes in the uncompresed input data.
		call emit_match  ; Ruins AX, BX, CX, DX, DI, BP, FLAGS. Keeps SI intact
.next_byte:	mov bp, sp
		mov cx, [bp+2*2]  ; udata_end.
		sub cx, si
		jz short .done
		cmp cx, MAX_LENGTH
		jb .cx_ok
		mov cx, MAX_LENGTH
.cx_ok:		; CX will keep holding the maximum match length starting at DS:SI, until the next .next_byte (i.e. when SI is increased).
		mov di, si
		xor dx, dx  ; Best length so far. No need to initialize BP (best distance) here.
		mov ax, -1  ; Current distance.
		jmp near .next_start
.done:		stc
		call emit_bit  ; Emit end-of-stream (EOS) sequence.
		clc
		call emit_bit
		mov al, 0
		call emit_m1
		clc
		call emit_bit
		pop si  ; Restore SI := udata_start.
		pop di  ; Restore DI := cdata_end == cdata_cur.
		pop cx  ; Restore CX := udata_end.
		ret

%ifdef DEBUG
  ; Emits a bit in CF, ruins CF.
  emit_bit: equ print_bit
  ; Emits a byte in AL.
  emit_m1: equ print_m1
  ; Emits a byte in AL.
  emit_m1101: equ print_m1101
%else
  ; Emits a bit in CF, ruins CF.
  emit_bit:
  ; Emits a byte in AL.
  emit_m1:
  ; Emits a byte in AL.
  emit_m1101:
		ret
%endif

; Emits CL (1 <= CL <= 7) bits from AH, highest (of the CL) bits first.
; Ruins: CX (sets it to 0), FLAGS.
emit_bits:
		mov ch, 0
.next:		push ax  ; Save.
		shr ah, cl  ; CF := pint to print.
		pop ax  ; Restore.
		call emit_bit
		loop .next
		ret

; Emits an encoded match == (distance, length) == (BP, DX) pair. 0 <= BP <= 0xfff; 2 <= DX <= 270. If DX == 2, then also BP <= 0x7ff.
; Keeps SI intact.
; Ruins: AX, BX, CX, DX, DI, BP, FLAGS.
emit_match:
%ifdef DEBUG
		mov ax, bp
%else
		xchg ax, bp  ; AX := distance; BP := junk.
%endif
		stc
		call emit_bit
		cmp dx, byte 3  ; Also CF := (len == 2).
		cmc  ; CF := (len != 2).
		call emit_bit
		cmp dx, byte 2
		jne short .dist_3plus
.dist_2:	cmp ax, strict word 0xff
		jae short .dist_2_big
.dist_2_small:	inc ax
		call emit_m1
		clc
		call emit_bit
		jmp short .after_bits
.dist_2_big:	call emit_m1
		stc
		call emit_bit
		mov cl, 3
		call emit_bits
		jmp short .after_bits
.dist_3plus:	call emit_m1
		test ah, ah
		jnz short .dist_3plus_mid_or_big
.dist_3plus_small:
		clc
		call emit_bit
		jmp short .len
.dist_3plus_mid_or_big:
		stc
		call emit_bit
		mov cl, 3
		cmp ah, 4
		jae short .dist_3plus_big
.dist_3plus_mid:
		and ax, strict word 0x3ff  ; Same size as: `and ah, 3'. Makes the next `print bit' start with a 0 bit.
		jmp short .dist_bits  ; With CL == 3.
.dist_3plus_big:
		stc
		call emit_bit
		inc cx  ; CL := 4.
.dist_bits:	call emit_bits
.len:
%ifdef DEBUG
		mov ax, dx
%else
		xchg ax, dx  ; AX := length; DX := junk.
%endif
		cmp ax, strict word 7
		jae short .len_mid_or_big
.len_short:	xchg cx, ax  ; CX := length; AX := junk.
		times 2 dec cx  ; CX := length - 2.
		mov ah, 1  ; Prints (1..3) 0 bits and a 1 bit.
		jmp short .len_bits
.len_mid_or_big:
		sub ax, strict word 15
		jae short .len_big
.len_mid:	add al, 15-7
		and al, 7
		mov ah, al
		mov cl, 8  ; Prints 5 0 bits and 3 length bits.
.len_bits:	call emit_bits
		jmp short .after_bits
.len_big:	mov ah, 1
		mov cl, 5   ; Prints 4 0 bits and a 1 bit.
		call emit_bits
		call emit_m1101  ; Prints AL.
.after_bits:
%ifdef DEBUG
		xchg ax, dx  ; AX := DX (length); DX := junk.
		call print_length
		xchg ax, bp  ; AX := BP (distance); BP := junk.
		call print_distance
%endif
		ret

udata:		incbin UEXEFN, 0x200
.end:

absolute $
		resb ($-$$)&1
_bss:
cdata:		resb 0x5000

; __END__
