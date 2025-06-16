;
; pmwca.c: PMODE/W stub compressor, 8086 assembly implementation, as a DOS .com program
; by pts@fazekas.hu at Sat Jun 14 11:40:42 CEST 2025
;
; Compile with: nasm -O0 -w+orphan-labels -DUEXEFN="'pmodewu.exe'" -DDEBUG -o pmwca.com pmwca.nasm
; Minimum NASM version needed: 0.98.39
;
; End-to-end check: nasm-0.98.39 -O0 -w+orphan-labels -f bin -o pmwca.com pmwca.nasm && time ~/prg/kvikdos/kvikdos pmwca.com pmodewu.exe pmodewc.exe && cmp pmodew133.exe pmodewc.exe && echo OK
; End-to-end check: nasm-0.98.39 -O0 -w+orphan-labels -f bin -DDEBUG -o pmwca.com pmwca.nasm && time ~/prg/kvikdos/kvikdos pmwca.com pmodewu.exe pmodewc.exe >pmwca.log && <pmwca.log grep '^[BLDE]' >pmwca.blde.log && diff pmodewc.blde.log pmwca.blde.log && cmp pmodew133.exe pmodewc.exe && echo OK
;
; This compressor is quite slow because scans the same data may times
; looking for longer and longer repetition. On a real 386 CPU from 1985) it
; may take several minutes. (How long would it take on an 586 CPU in 1997?)
; Adding a hashtable or lookup table would make it significantly faster.
;
; !! Convert from NASM to TASM syntax.
; !! Check diff with `nasm -O999999999'. It seems to be OK now.
; !! speed optimization: For compress, add a lookup table which finds the previous occurrence of a word (2 bytes) in O(1) time.
;

bits 16
cpu 8086
BASE equ 0x100  ; DOS .com program base `org' value, the first program byte is loaded to this offset.
org BASE

TAB equ 9
CR equ 13

start:  ; DOS .com program entry point.
		; Falls through.

parse_command_line:  ; Usage: pmwca.com <uncompressed-input.exe> <compressed-output.exe>
		mov si, 0x81  ; Offset of DOS command-line string within the PSP segment (== CS == DS == ES ==SS), terminated by CR.
.ws1:		lodsb
		cmp al, ' '
		je short .ws1
		cmp al, TAB
		je short .ws1
		cmp al, CR
		jne short .fn1i
		mov bp, 'MI'  ; Missing input filename.
		jmp short fatal
.fn1i:		mov dx, si
		dec dx  ; DX := offset of input filename.
.fn1:		lodsb
		cmp al, ' '
		je short .fn1e
		cmp al, TAB
		je short .fn1e
		cmp al, CR
		jne short .fn1
.fatal_mo:	mov bp, 'MO'  ; Missing output filename.
		jmp short fatal
.fn1e:		mov byte [si-1], 0  ; Modify command-line string in place: add terminating NUL for input filename.
.ws2:		lodsb
		cmp al, CR
		je short .fatal_mo
		cmp al, ' '
		je short .ws2
		cmp al, TAB
		je short .ws2
.fn2i:		dec si  ; SI := offset of output filename.
		push si  ; Save offset of output filename. Will be popped by `pop dx' in write_udata.
.fn2:		lodsb
		cmp al, ' '
		je short .fn2e
		cmp al, TAB
		je short .fn2e
		cmp al, CR
		jne short .fn2
.fn2e:		mov byte [si-1], 0  ; Modify command-line string in place: add terminating NUL for output filename.
		db 0xa8  ; Opcode of `test al, ...', to skip over the next `lodsb'.
.ws3:		lodsb
		cmp al, ' '
		je short .ws3
		cmp al, TAB
		je short .ws3
		cmp al, CR
		je short .done
.fatal_ta:	mov bp, 'TA'  ; Too many command-line arguments.
		; Falls through to fatal.

; Exits the process with a fatal error (2 bytes of error message in BP).
fatal:		mov [fatal_msg.code], bp
		mov ah, 0x40  ; Write to file using handle.
		mov bx, 2  ; STDERR_FILENO.
		mov dx, fatal_msg  ; DS:DI == pointer to start of buffer to be written.
		mov cx, fatal_msg.end-fatal_msg  ; CX == number of bytes to write.
		int 0x21  ; DOS syscall.
		mov ax, 0x4c01  ; Exit with exit code EXIT_FAILURE (1).
		int 0x21  ; DOS syscall. Doesn't return.

; If CF == 1, exits the process with a fatal error (2 bytes of error message
; in BP), otherwise returns. Keeps all registers including FLAGS intact.
fatal_if_c:	jc short fatal
		ret

parse_command_line.done:
		; Now: DX == offset of input filename (uncompressed DOS .exe); DI == offset of output filename (compressed DOS .exe).
		; Falls through.

EXEHDRSIZE equ 0x200  ; Size of DOS .exe header created by TLINK.

read_udata:	mov ax, 0x3d00  ; Open file for reading, using handle.
		;mov dx, ...  ; DX == offset of input filename.
		int 0x21  ; DOS syscall. Sets AX to the filehandle.
		mov bp, 'OI'  ; Error opening input file.
		call fatal_if_c
		xchg bx, ax  ; BX := filehandle of input file; AX := junk.
		mov ah, 0x3f  ; Read from file using handle.
		;mov bx, ...  ; BX == filehandle of input file.
		mov dx, uexehdr  ; DS:DX == pointer to start of buffer to read uexehdr to.
		mov cx, EXEHDRSIZE  ; Maximum number of bytes to read.
		int 0x21  ; DOS syscall. Sets AX to the number of bytes read.
		mov bp, 'RH'  ; File read error reading the uncompressed DOS .exe header.
		call fatal_if_c
		cmp ax, strict word EXEHDRSIZE
		je short .hdrsize_ok
		mov bp, 'HT'  ; Input file headers too short.
		jmp short fatal
.hdrsize_ok:	mov si, dx  ; DS:SI := DS:DX == pointer to start of uexehdr.
		mov bp, 'MZ'
		cmp [si+0*2], bp  ; signature.
		jne short fatal  ; Bad DOS .exe signature.
		cmp word [si+4*2], byte EXEHDRSIZE>>4  ; hdrsize.
		mov bp, 'HS'  ; Unsupported DOS .exe header size (hdrsize).
		jne short fatal
		mov ah, 0x3f  ; Read from file using handle.
		;mov bx, ...  ; BX == filehandle of input file.
		mov dx, udata  ; DS:DX == pointer to start of buffer to read to.
		mov cx, udata.bufend-udata  ; Maximum number of bytes to read.
		int 0x21  ; DOS syscall. Sets AX to the number of bytes read.
		mov bp, 'RD'  ; File read error reading the uncompressed DOS .exe image.
		call fatal_if_c
		add ax, strict word udata
		cmp ax, strict word udata.bufend
		jb short .usize_ok
		mov bp, 'TL'  ; Input file too long.
.j_fatal:	jmp short fatal
.usize_ok:	push ax  ; Save offset of end of udata.
		mov ah, 0x3e  ; Close file using handle.
		int 0x21  ; DOS syscall.
		; Now: DS:SI := DS:DX == pointer to start of uexehdr.
		; Falls through.

compress_relocs:
		mov cx, [si+3*2]  ; nreloc.
		test cx, cx
		mov bp, 'NR'  ; No relocations. (apply_relocations) depends on a nonzero nreloc value.
		jz short read_udata.j_fatal
		cmp cx, byte (EXEHDRSIZE-0x1c)>>2
.fatal_tr:	mov bp, 'TR'  ; Too many relocations.
		ja short read_udata.j_fatal
		mov di, [si+12*2]  ; relocpos.
		cmp di, strict word EXEHDRSIZE
		mov bp, 'RP'  ; Relocations start too late.
		jnb short read_udata.j_fatal
		mov ax, cx
		times 2 add ax, ax  ; AX := nreloc<<2.
		add ax, di  ; AX += relocpos.
		cmp ax, strict word EXEHDRSIZE
		ja short .fatal_tr
		lea ax, [word di+uexehdr]  ; AX := uexehdr+relocpos.
		mov dx, cx  ; nreloc.
		call heapsort4  ; Sorts relocations by (segment descending, then offset ascending). Ruins AX, BX, DX, SI, BP and FLAGS. Keeps CX and DI.
.squeeze_relocs:  ; Convert each relocation from dword-sized (offset, segment) pair to word-sized offset+0x100.
		lea si, [word di+uexehdr]  ; SI := uexehdr+relocpos.  Source of (offset, segment) pairs.
		mov di, creloc  ; DS:DI := pointer to the squeezed relocations.
		;mov cx, [si+3*2]  ; CX == nreloc. Nonzero.
.next:		lodsw
		xchg bx, ax  ; BX := offset of the relocation; AX := junk.
		inc bh  ; BX += 0x100.
		lodsw
		times 4 add ax, ax  ; AX <<= 4. Convert from real-mode segment value to byte offset.
		add ax, bx
		stosw
		loop .next
		; Falls through.

build_preparator_buf:
		mov si, udata
		pop cx  ; CX := offset of end of udata.
		mov di, cdata
		call compress  ; Append compressed data to DS:DI == ES:DI. Ruins AX, BX, CX, DX, SI, BP, FLAGS. Sets DS:DI to pointer to end of cdata.
		mov si, creloc
		mov cx, [uexehdr+3*2]  ; U_RELOC == nreloc. !! size optimization: Make it shorter by push+pop and passing end-of-udata to compress in DX instead of CX.
		lea bx, [word di-(preparator_buf-$$+BASE)]  ; BX := csize + (cdata - preparator_buf).
		times 2 add bx, cx  ; BX := csize + (nreloc << 1) + (cdata - preparator_buf).
		mov [apply_relocations.u_nreloc], cl  ; It fits to 1 byte, we've checked it above at 'TR'.
		rep movsw  ; Append compressed relocationss to DS:DI == ES:DI.
		; Now: DS:DI == pointer to the end of cdata.
		mov ax, bx
		and ax, strict word 0x1ff
		mov [cexehdr.lastsize], ax
		lea ax, [bx+0x1ff]  ; Round up.
		shr ax, 1
		mov [cexehdr.nblocks], ah  ; Set low byte. The high byte will remain 0.
		sub bx, byte 0x20  ; BX := csize + (nreloc << 1) + (cdata - preparator_buf) - (chdrsize << 4).
		lea ax, [bx+1]  ; Round up.
		shr ax, 1
		mov [copy_code.word_count], ax  ; Number of words to copy.
		lea si, [uexehdr+7*2]  ; U_SS.
		lodsw  ; AX := U_SS; SI += 2 (to U_SP).
		mov [cexehdr.ss], ax
		mov [jump_to_program.u_ss], ax
		lea bx, [bx+0xf]  ; Round up.
		mov cl, 4
		shr bx, cl  ; BX := (csize + (nreloc << 1) + (cdata - preparator_buf) - (chdrsize << 4) + 0xf) >> 4.
		add ax, strict word ((0x100+0xf)>>4)+1  ; Why the +1? Maybe it's related to the bug in the original PMODE/W compressor.
		add ax, bx  ; AX := (U_SS + ((0x100 + 0xf) >> 4)) + ((csize + (nreloc << 1) + (cdata - preparator_buf) - (chdrsize << 4) + 0xf) >> 4) + 1.
		mov [cexehdr.minalloc], ax  ; The value computed above is larger than needed, so this is wasting memory at runtime. This is probably a bug in the original PMODE/W compressor.
		lodsw  ; AX := U_SP. SI += 2 (to U_CHECKSUM).
		mov [jump_to_program.u_sp], ax
		lodsw  ; AX := U_CHECKSUM (will be ignored). SI += 2 (to U_IP).
		lodsw  ; AX := U_IP. SI += 2 (to U_CS).
		mov [uncompressed_start_far_ptr.u_ip], ax
		lodsw  ; AX := U_CS. SI += 2 (to U_RELOCPOS, will be ignored).
		mov [uncompressed_start_far_ptr.u_cs], ax
		; Now: DS:DI == pointer to the end of cdata.
		; Falls through.

write_cdata:	mov ah, 0x3c  ; Open file for writing, optionally create it, truncate it, using handle.
		xor cx, cx  ; File attributes: none.
		pop dx  ; Restore DX := output filename.
		int 0x21  ; DOS syscall. Sets AX to the filehandle.
		mov bp, 'OO'  ; Error opening input file.
		call fatal_if_c
		xchg bx, ax  ; BX := filehandle of input file; AX := junk.
		mov ah, 0x40  ; Write to file using handle.
		;mov bx, ...  ; BX == filehandle of output file.
		mov dx, preparator_buf  ; DS:DX == pointer to start of buffer to be written.
		mov cx, di  ; Pointer to the end of cdata.
		sub cx, dx  ; CX := DI - preparator_buf. CX == number of bytes to write.
		mov bp, 'WR'  ; File write error.
		int 0x21  ; DOS syscall.
		call fatal_if_c
%if 0  ; No need to close the output file, DOS will close it right below, when to process exits.
		mov ah, 0x3e  ; Close file using handle.
		int 0x21  ; DOS syscall.
%endif
		ret  ; Exit successfully (EXIT_SUCCESS) from DOS .com program.

; Compares relocation dword [ds:si] to dword [ds:di]. It compares by
; (segment descending, then offset ascending). Thus first it compares the
; segment values (reversed), and if they are equal, it compares the offset
; values. Returns CF indicating that the first is smaller than the second.
;
; Ruins: AX and FLAGS.
is_reloc_less:
		mov ax, [si+2]  ; First segment.
		cmp [di+2], ax  ; Compare to second segment, in reverse (descending) order.
		jne short .done  ; CF is already correct: CF == 1 if second is less, CF == 0 otherwise.
		mov ax, [si]  ; First offset.
		cmp ax, [di]  ; Compare to second offset.
		; CF is already correct: CF == 1 if first is less, CF == 0 otherwise.
.done:		ret

; Swaps dword [ds:si] with dword [ds:di].
; Ruins: AX and FLAGS.
memswap4:
		mov ax, [si+2]
		xchg ax, [di+2]
		mov [si+2], ax
		mov ax, [si]
		xchg ax, [di]
		mov [si], ax
		ret

; Sorts an array of 4 bytes each using the comparison function is_reloc_less.
; Based on heapsort algorithm H from Knuth TAOCP 5.2.3H. Not stable.
; Worst case execution time: O(n*log(n)), 3*n*log_2(n) comparisons, and
; fewer swaps.
;
; Inputs: DS:AX: pointer to the start of the array; DX: number of array elements.
; Ruins: AX, DX, FLAGS.
;
; Compared to Knuth's algorith, this implementation contains swaps instead
; of assignments to temporary variable with swaps.
;
; typedef unsigned size_t;
; #define SIZE 4
; extern char is_reloc_less(const void *a, const void *b);
; #pragma aux is_reloc_less __parm [__si] [__di] __modify [__ax] __value [__cf]  /* OpenWatcom C compiler doesn't actually support __value [__cf]. */
; extern void memswap4(void *a, void *b);
; #pragma aux memswap4 __parm [__si] [__di] __modify [__ax]
; void heapsort4(void *base, size_t n);
; #pragma aux heapsort4 __parm [__ax] [__dx] __modify [__ax __bx __dx __si __bp]
; void heapsort4(void *base, size_t n) {
;   char *ap = (char*)base, *lp = ap + SIZE * (n >> 1), *rp = ap + SIZE * (n - 1), *tp, *ip, *jp;
;   if (n < 2) return;
;   for (;;) {
;     if (lp != ap) {
;       tp = lp -= SIZE;
;     } else {
;       memswap4(ap, rp);
;       if ((rp -= SIZE) == ap) break;
;       tp = ap;
;     }
;     jp = lp;
;     for (;;) {
;       ip = jp;
;       jp += (jp - ap) + SIZE;
;       if (jp > rp) break;
;       if (jp < rp && is_reloc_less(jp, jp + SIZE)) jp += SIZE;
;       if (!is_reloc_less(tp, jp)) break;
;       memswap4(ip, jp);
;       tp = jp;
;     }
;     memswap4(ip, tp);
;   }
; }
;
; !! size optimization: Replace this heapsort implementation with a shorter but slower (O(n*n)) insertion sort.
heapsort4:
		push cx  ; Save.
		push di  ; Save.
		mov bp, sp
		sub sp, byte 8
		mov cx, ax
		mov bx, dx
		shr bx, 1
		shl bx, 1
		shl bx, 1
		mov si, ax
		add si, bx
		mov word [bp-2], si
		mov bx, dx
		shl bx, 1
		shl bx, 1
		sub bx, byte 4
		add bx, ax
		cmp dx, byte 2
		jb short .done
.1:		mov ax, word [bp-2]
		cmp cx, ax
		je short .2
		sub word [bp-2], byte 4
		mov ax, word [bp-2]
		mov word [bp-4], ax
		jmp short .3
.2:		mov di, bx
		mov si, ax
		call memswap4
		sub bx, byte 4
		cmp bx, cx
		je short .done
		mov word [bp-4], cx
.3:		mov dx, word [bp-2]
.4:		mov word [bp-8], dx
		mov ax, dx
		sub ax, cx
		add ax, strict word 4
		add dx, ax
		cmp dx, bx
		ja short .7
		jae short .5
		mov ax, dx
		add ax, strict word 4
		mov word [bp-6], ax
		mov di, ax
		mov si, dx
		call is_reloc_less
		;test al, al
		;je short .5  ; Jump if not less.
		jnc short .5  ; Jump if not less.
		mov dx, word [bp-6]
.5:		mov di, dx  ; jp += SIZE.
		mov si, word [bp-4]
		call is_reloc_less
		;test al, al
		;je short .7  ; Jump if not less.
		jnc short .7  ; Jump if not less.
		mov di, dx
		mov si, word [bp-8]
		call memswap4
		mov word [bp-4], dx
		jmp short .4
.7:		mov di, word [bp-4]
		mov si, word [bp-8]
		call memswap4
		jmp short .1
.done:		mov sp, bp
		pop di  ; Restore.
		pop cx  ; Restore.
		ret

%ifdef DEBUG
  LF equ 10

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

  print_ax:	push ax
		xchg al, ah
		call print_al
		mov al, ah
		call print_al
		pop ax
		ret

  print_literal:
		push ax
		mov al, 'L'
		int 0x29
		mov al, [si]
		call print_al
		mov al, LF
		int 0x29
		pop ax
		ret

  print_distance:
		push ax
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

  %macro do_emit_m1 0  ; Emits a byte in AL. Uses ES:DI.
    call print_m1
    stosb
  %endm
  %macro do_emit_m1101 0  ; Emits a byte in AL. Uses ES:DI.
    call print_m1101
    stosb
  %endm
%else
  %macro do_emit_m1 0  ; Emits a byte in AL. Uses ES:DI.
    stosb
  %endm
  %macro do_emit_m1101 0  ; Emits a byte in AL. Uses ES:DI.
    stosb
  %endm
%endif

; Emits a bit in CF, ruins CF.
; Input: SS:BP points to the local variables of the compress function.
; Input: DS:DI == ES:DI points to the end of the compressed output data (cdata_end == cdata_cur).
; Output: DI incremented when a new 16-bit block (tag) word is emitted to DS:DI == ES:DI.
; Input and output: The offset of the current 16-bit block (tag) word value is in word [bp+2*2]. The segment is DS == ES. Will be modified.
; Input and output: The block (tag) next-write power-of-two bitmask is in word [bp+4*2]. Will be modified.
; Ruins: FLAGS (incuding CF).
emit_bit:
%ifdef DEBUG
		pushf
		call print_bit
		popf
%endif
		push ax  ; Save.
		push bx  ; Save.
		mov bx, [bp+2*2]
		mov ax, [bp+4*2]
		jnc short .done_or  ; Uses the CF value at the beginning of emit_bit.
		or [bx], ax
.done_or:	add ax, ax
		jnz short .done
		mov [bp+2*2], di
		stosw  ; Append new 16-bit block (tag) word value, with initial value of 0. Uses ES:DI.
		inc ax  ; AX := 1.
.done:		mov [bp+4*2], ax
		pop bx  ; Restore.
		pop ax  ; Restore.
		ret

MAX_LENGTH equ 270
MAX_DISTANCE_FOR_LENGTH_2 equ 0x800-1
MAX_DISTANCE equ 0x1000-1

; Compresses bytes starting at DS:SI == ES:SI until DS:CX == ES:CX (CX is
; not a byte count, but an offset!), writing the compressed stream to DS:DI
; == ES:DI, using a variant of LZSS. The input must not be empty.
;
; Output: DS:DI == ES:DI: offset of the end of the compressed output data.
; Ruins: AX, BX, CX, DX, SI, BP, FLAGS.
compress:	mov ax, 1
		push ax  ; word [bp+4*2]: Save initial block (tag) next-write power-of-two bitmask.
		push cx  ; word [bp+3*2]: Save offset of the end of the uncompressed input data (udata_end). Sometimes DI is used instead of this. Remains constant throughout the function.
		movsb  ; Uses DS:SI and ES:DI. Copy literal byte to compressed output data.
		push di  ; word [bp+2*2]: Save offset of the current 16-bit block (tag) word value. The segment is DS == ES.
		dec ax ; AX := 0.
		stosw  ; Initial 16-bit block (tag) word value (0).
		push di  ; word [bp+1*2]: Save offset of the end of the compressed output data (cdata_end == cdata_cur). Will be incremented throughout the function.
		dec si
		push si  ; word [bp+0*2]: Save offset of the start of the uncompressed input data (udata_start). Remains constant throughout the function.
%ifdef DEBUG
		call print_literal  ; Value: `byte [si]'.
%endif
		inc si  ; Skip over literal byte in the uncompressed input data.
		mov bp, sp
.next_byte:	mov [bp+1*2], di  ; cdata_end == cdata_cur.
		mov cx, [bp+3*2]  ; udata_end.
		sub cx, si
		jz short .done
		cmp cx, MAX_LENGTH
		jb .cx_ok
		mov cx, MAX_LENGTH
.cx_ok:		; CX will keep holding the maximum match length starting at DS:SI, until the next .next_byte (i.e. when SI is increased).
		mov di, si
		xor dx, dx  ; Best length so far. No need to initialize BP (best distance) here.
		mov ax, -1  ; Current distance.
		jmp short .next_start
.done:		stc
		call emit_bit  ; Emit end-of-stream (EOS) sequence.
		clc
		call emit_bit
		mov al, 0
		do_emit_m1  ; In AL.
		clc
		call emit_bit
		; Now: DI == the correct, final value for cdata_end == cdata_cur.
		add sp, byte 5*2  ; Clean up local variables from the stack.
		ret
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
		mov bx, bp  ; BX := best distance.
		mov bp, sp
		mov di, [bp+1*2]  ; cdata_end == cdata_cur.
		cmp dx, byte 2
		jae short .match
.literal:
		clc
		call emit_bit
%ifdef DEBUG
		call print_literal
%endif
		movsb  ; Copies a literal byte from DS:SI to ES:DI. Also skips over literal byte in the uncompressed input data (SI += 1).
		jmp short .j_next_byte
.match:
		add si, dx  ; Skip over matched bytes in the uncompresed input data.
		call emit_match  ; Ruins AX, BX, CX, DX, DI, BP, FLAGS. Keeps SI and BP intact.
.j_next_byte:	jmp strict near .next_byte

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

; Emits an encoded match == (distance, length) == (BX, DX) pair. 0 <= BX <= 0xfff; 2 <= DX <= 270. If DX == 2, then also BX <= 0x7ff.
; Input: SS:BP points to the local variables of the compress function.
; Input: DS:DI == ES:DI points to the end of the compressed output data (cdata_end == cdata_cur).
; Output: DI incremented as emit_match and its subfunctions write compressed output bytes to DS:DI == ES:DI.
; Keeps SI and BP intact.
; Ruins: AX, BX, CX, DX, FLAGS.
emit_match:
%ifdef DEBUG
		mov ax, bx
%else
		xchg ax, bx  ; AX := distance; BX := junk.
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
		do_emit_m1  ; In AL.
		clc
		call emit_bit
		jmp short .after_bits
.dist_2_big:	do_emit_m1  ; In AL.
		stc
		call emit_bit
		mov cl, 3
		call emit_bits
		jmp short .after_bits
.dist_3plus:	do_emit_m1  ; In AL.
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
		do_emit_m1101  ; In AL.
.after_bits:
%ifdef DEBUG
		xchg ax, dx  ; AX := DX (length); DX := junk.
		call print_length
		xchg ax, bx  ; AX := BX (distance); BX := junk.
		call print_distance
%endif
		ret

fatal_msg:	db 'pmwca: fatal: '
.code:		db '??', 13, 10
.end:

; --- Code below here is not executed by compressor, but it is copied near
; the beginning of the compressed .exe.
;
; -- Code below here is not written by pts, but it was copied from the
; disassembly of the first 0x142 bytes of pmodew.exe in PMODE/W 1.33. pts
; has added automatic adjustment of offsets etc. To make it easier to
; understand, pts has also added comments, function names, labels and
; variable names.

preparator_buf:

cexehdr:  ; DOS .exe header of the compressed DOS .exe: http://justsolve.archiveteam.org/wiki/MS-DOS_EXE
; load module length = 0x2cdc
.signature:	db 'MZ'
.lastsize:	dw 0       ; Length of load module mod 200H. build_preparator_buf will populate it.
.nblocks:	dw 0       ; Number of 200H pages in load module. build_preparator_buf will populate its low byte.
.nreloc:	dw 0       ; Number of relocation items; no relocations.
.hdrsize:	dw 2       ; Size of header in paragraphs.
.minalloc:	dw 0       ; Minimum number of paragraphs required above load mod. build_preparator_buf will populate it with a value is larger than needed. This is probably a bug in the original PMODE/W compressor.
.maxalloc:	dw -1      ; Maximum number of paragraphs required above load mod.
.ss:		dw 0       ; Offset of stack segment in load module. Same as U_SS. build_preparator_buf will populate it.
.sp:		dw 0x100   ; Initial value of SP. Constant.
.checksum:	dw 0       ; Checksum.
.ip:		dw exe_start-exe_image  ; Initial value of IP.
.cs:		dw 0       ; Offset of code segment within load module (segment).
.relocpos:	dw 0x003e  ; File offset of first relocation item. Unused because of nreloc == 0.
.noverlay:	dw 0      ; Overlay number. Unused.

padding:	dd 0  ; At file offset 0x1c. Unused.

exe_image:

pmodew_config:
; * This is 0x15 == 21 bytes at compressed exe_image+0.
; * This is 0x15 == 21 bytes at uncompressed exe_image+0x8e, it's
;   zero-initialized there.
; * Here is how pmodew_config is loaded. When DOS loads the .exe with
;   the PMODE/W stub, it loads the pmodew_config here as well, but the
;   decompressor below ignores and overwrites it.
;   The PMODE/W function _openexe2 (with VARTYPE == 1) loads the first
;   0x15-2 == 21-2 bytes of this from the beginning of DOS .exe image (at
;   hdrsize<<4) to uncompressed exe_image+0x8e == _pm_pagetables. And then
;   it loads 2 more bytes to another uncompressed exe_image+0x196 ==
;   _lowmin. The loaded 0x13 bytes must fit to the first 0x40+0x15 bytes of
;   the .exe file. Typically it is between 0x20..0x35, so they fit.
.pagetables:	db 4  ; Number of page tables under VCPI.                                             _pm_pagetables:
.selectors:	dw 0x100  ; Max selectors under VCPI/XMS/raw.                                         _pm_selectors:
.rmstacklen:	dw 0x40  ; Real mode stack length, in para.                                           _pm_rmstacklen:
.pmstacklen:	dw 0x80  ; Protected mode stack length, in para.                                      _pm_pmstacklen:
.rmstacks:	db 8  ; Real mode stack nesting.                                                      _pm_rmstacks:
.pmstacks:	db 8  ; Protected mode stack nesting.                                                 _pm_pmstacks:
.callbacks:	db 0x20  ; Number of real mode callbacks.                                             _pm_callbacks:
.mode:		db 1  ; Mode bits.                                                                    _pm_mode:
.pamapping:	db 1  ; Physical address mappings pages max.                                          _pm_pampagemax:
.crap:		dw 0  ; Unused.
.options:	db 1  ; Option flags. 0 = hide copyright message; 1 == display copyright message.     _pm_options:
.extmax:	dd 0x7fffffff  ; Maximum extended memory to allocate.                                 _pm_maxextmem:
.lowmin:	dw 0  ; Amount of low memory to try and save. Loaded by _openexe2 to somewhere else.  _lowmin:

copyright: db 'PMODE/W v1.33 DOS extender - Copyright 1994-1997, Daredevil and Tran.'

uncompressed_start_far_ptr:
.u_ip: dw 0  ; build_preparator_buf will populate it.
.u_cs: dw 0  ; build_preparator_buf will populate it.

; Identical version of 8086 opcode encoding.
_mov_bl_al equ 0xd88a
_mov_bp_ax equ 0xe88b
_mov_bx_ax equ 0xd88b
_mov_cl_al equ 0xc88a
_mov_cl_dh equ 0xce8a
_mov_si_di equ 0xf78b
_xor_bx_bx equ 0xdb33
_xor_dh_dh equ 0xf632

exe_start:  ; Compressed .exe entry point.
copy_code:
		cld
		push ss  ; orig_CS+0x3d7 == orig_CS+U_SS.
		pop es  ; ES := orig_CS+0x3d7. DS remains PSP_segment == orig_cs-0x10.
		mov di, 0x100  ; The compressed SP value.
		dw _mov_si_di
		push di  ; 0x100.
		mov cx, 0  ; Number of words to copy: (cdata.end-exe_image+1)>>1. build_preparator_buf will populate it.
.word_count: equ $-2
		rep movsw  ; DS == orig_CS-0x10 == PSP_segment.
		push es  ; orig_CS+0x3d7.
		push ds  ; orig_CS-0x10.
		pop es   ; ES := orig_CS-0x10.
		pop ds   ; DS := orig_CS+0x3d7.
		pop di   ; DI := 0x100.
		mov si, cdata-exe_image+0x100  ; DS:SI now points to the start of the copy of cdata. Constant.
		push es  ; orig_CS-0x10. Will be popped by `pop ds' in jump_to_program.
		push cs  ; orig_CS == PSP_segment. Will be popped by `pop dx' in jump_to_program.
		movsb  ; Copy initial literal token.
		lodsw  ; AX := initial 16-bit block (tag) word value.
		dw _mov_bp_ax  ; BP will keep holding the block word throught decompression. `xchg bp, ax' would have been shorter.
		mov dl, 0x10  ; DL will keep holding the Number of bits remaining in the block word (BP). Starting at 0x10 == 16.
		push ds  ; Segment for the `retf' below: orig_CS+0x3d7.
		mov ax, decompress.start-exe_image+0x100
		push ax  ; Offset for the `retf' below: 0x100+0xd9 == 0x100 + decompress.literal.
		retf  ; Jump to (orig_CS+0x3d7):0x1d9, which is a copy of decompress.start == decompress.next_token.

decompress:  ; Entry point is decompress.start. It needs initialization, see above.
.get_bit:
		shr bp, 1  ; CF := the first bit in a block to be used is its lowest bit.
		dec dl  ; Doesn't modify CF.
		jnz .get_bit.ret
		lodsw
		dw _mov_bp_ax  ; `xchg bp, ax' would have been shorter here.
		mov dl, 0x10  ; Again, 0x10 == 16 are available in BP.
.get_bit.ret:
		ret
.match_1_1:
		call .get_bit
		jnc short .match_1_1_0
.match_1_1_1:
		call .get_bit
		adc cl, 1
		shl cl, 1
.match_1_1_1.next:
		call .get_bit
		rcl bh, 1
		loop .match_1_1_1.next  ; Then falls through to .match_1_1_0.
.match_1_1_0:
		mov dh, 2
		mov cl, 4
.match_1_1_0.next:
		inc dh
		call .get_bit
		jc short .copy_match_count_dh
		loop .match_1_1_0.next
		call .get_bit
		jnc short .match_1_1_0_0
.match_1_1_0_1:
		lodsb
		dw _mov_cl_al
		add cx, byte 0xf
		jmp short .copy_match
.match_1_1_0_0:
		dw _xor_dh_dh
		mov cl, 0x3
.match_1_1_0_0.next:
		call .get_bit
		rcl dh, 1
		loop .match_1_1_0_0.next
		add dh, 0x7
.copy_match_count_dh:
		dw _mov_cl_dh
		jmp short .copy_match
.copy_match_2_bytes:
		mov cl, 2  ; CX := 2. Assumes CH == 0. Falls through to .copy_match.
.copy_match:  ; Copies a match with (distance, length) == (BX, CX). The distance 0 means: copy the previously emitted byte (at [ES:DI-1]).
		neg bx  ; BX := -orig_distance.
		dec bx  ; BX := -orig_distance - 1.
.copy_match.next:
		mov al, [es:bx+di]  ; [es:..] prefix is not needed.
		stosb
		loop .copy_match.next
.next_token:
.start:
		call .get_bit
		jc short .match_1
.literal_0:  ; Indicated by CF==0.
		movsb  ; Copy literal byte from byte stream.
		jmp short .next_token
.match_1:  ; Indicated by CF==1.
		dw _xor_bx_bx
		call .get_bit
		lodsb  ; Get distance byte. Keeps CF intact.
		dw _mov_bl_al  ; BX (distance) := AL.  Keeps CF intact.
		jc short .match_1_1
.match_1_0:
		call .get_bit
		jc short .match_1_0_1
.match_1_0_0:
		sub bl, 1
		jc short .after_decompress
		jmp short .copy_match_2_bytes
.match_1_0_1:
		mov cl, 3
.match_1_0_1.next:
		call .get_bit
		rcl bh, 1
		loop .match_1_0_1.next
		jmp short .copy_match_2_bytes
.after_decompress:  ; Falls through to apply_relocations.

apply_relocations:
		pop dx  ; Restore DX := orig_CS, pushed by `push cs' in setup_code.
		add [uncompressed_start_far_ptr-exe_image+0x100+2], dx  ; Relocate segment in uncompressed_start_far_ptr.
		mov cl, 0  ; CX := U_NRELOC == (relocation_locations.end-relocation_locations)>>1 == number of relocations. Calculated.  ; CH is already 0. build_preparator_buf will populate it.
.u_nreloc: equ $-1
.next:		lodsw  ; Load next offset from relocation table. Format: an array of offsets usign segment orig_CS-0x10 == PSP_segment.
		dw _mov_bx_ax  ; `xchg bx, ax' would have been shorter.
		add [es:bx], dx  ; Apply single relocation.
		loop .next

jump_to_program:
		pop ds  ; Restore DS := PSP_segment. ES is already PSP_segment.
		cli
		add dx, strict word 0 ; U_SS. build_preparator_buf will populate it.
.u_ss: equ $-2
		mov ss, dx  ; SS := orig_CS+U_SS.
		mov sp, 0  ; U_SP. build_preparator_buf will populate it.
.u_sp: equ $-2
		sti
		jmp far [cs:uncompressed_start_far_ptr-exe_image+0x100]  ; Jump to uncompressed_start_far_ptr.

preparator_buf.end:

MAX_USIZE equ 0x7000  ; Large enough to fit the uncompressd pmodewu.exe (without its .exe header). Small enough to prevent overflow in ERROR_DOS_COM_MEMORY_IMAGE_TOO_LARGE.
MAX_CSIZE equ MAX_USIZE+((MAX_USIZE+7)>>3)  ; Worst case compressed data size: all tokens are literals. Matches are never longer than their corresponding literals.
MAX_CRELSIZE equ EXEHDRSIZE>>2  ; Absolue maximum which fits to EXEHDRSIZE bytes of DOS .exe header created by TLINK.
absolute $  ; Don't emit bytes anymore, just reserve.
cdata:		resb MAX_CSIZE+MAX_CRELSIZE  ; Must come directly after preparator_buf.end, without alignment.

udata:		resb MAX_USIZE
.bufend:

		resb ($$-$)&1  ; Align to word boundary.
uexehdr:		resb EXEHDRSIZE  ; Uncompressed DOS .exe header.
creloc: equ uexehdr+0x1c  ; Temporary buffer for compressed relocations.

%if $-$$>0xff00
  %error ERROR_DOS_COM_MEMORY_IMAGE_TOO_LARGE
  db 1/0
%endif

; __END__
