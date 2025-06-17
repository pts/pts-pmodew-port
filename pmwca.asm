;
; pmwca.asm: PMODE/W stub compressor, 8086 assembly implementation for TASM 2.0--, as a DOS .com program
; by pts@fazekas.hu at Sat Jun 14 11:40:42 CEST 2025
;
; Compile with TASM 2.0--5.3 on DOS: tasm /t /ml /m2 /zn /q /dPMWV=33 /DEBUG pmwca
; Link with TLINK 2.0-- on DOS, creating pmwca.com: tlink /t /x pmwca
;
; End-to-end check: ~/prg/kvikdos/kvikdos tasm20.exe /t /ml /m2 /q /dPMWV=33 pmwca && ~/prg/kvikdos/kvikdos tlink20.exe /t /x pmwca && rm -f pmodew.exe && time ~/prg/kvikdos/kvikdos pmwca.com pmodewu.exe pmodew.exe && cmp pmodew133.exe pmodew.exe && echo OK
; End-to-end check: ~/prg/kvikdos/kvikdos tasm20.exe /t /ml /m2 /q /dPMWV=33 /dDEBUG pmwca && ~/prg/kvikdos/kvikdos tlink20.exe /t /x pmwca && rm -f pmodew.exe && time ~/prg/kvikdos/kvikdos pmwca.com pmodewu.exe pmodew.exe >pmwca.log && <pmwca.log grep '^[BLDE]' >pmwca.blde.log && diff pmodewc.blde.log pmwca.blde.log && cmp pmodew133.exe pmodew.exe && echo OK
;
; There is an eqivalent NASM 0.98.39-- source of this program in pwmca.nasm.
;
; This compressor is quite slow because scans the same data may times
; looking for longer and longer repetition. On a real 386 CPU from 1985) it
; may take several minutes. (How long would it take on an 586 CPU in 1997?)
; Adding a hashtable or lookup table would make it significantly faster.
;
;
; !! speed optimization: For compress, add a lookup table which finds the previous occurrence of a word (2 bytes) in O(1) time.
;

ideal  ; TASM IDEAL mode assembly syntax.
locals
jumps
p8086
segment CODE para public use16 'CODE'
assume cs:CODE, ds:CODE, es:CODE, ss:CODE
BASE = 100h  ; DOS .com program base `org' value, the first program byte is loaded to this offset.
org BASE
$$:  ; Emulate NASM base label.
strict_word equ  ; Ignore NASM construct `strict word'.
strict_near equ  ; Ignore NASM construct `strict near'.
byte_imm equ     ; Ignore NASM construct `byte' in front of immediates.

TAB = 9
CR = 13

ifndef PMWV  ; Can be defined on the command line.
  PMWVV = 33
else
  PMWVV = 0+(PMWV)  ; TASM 2.0 can't handle PMWVV being the same as PMWV.
endif

start:  ; DOS .com program entry point.
		; Falls through.

; Identical version of 8086 opcode encoding.
_nasm_mov_dx_si = 0f289h
_mov_dx_si = 0f28bh
_nasm_mov_si_dx = 0d689h
_mov_si_dx = 0f28dh
_nasm_mov_ax_cx = 0c889h
_mov_ax_cx = 0c18bh
_nasm_add_ax_ax = 0c001h
_add_ax_ax = 0c003h
_nasm_add_ax_di = 0f801h
_add_ax_di = 0c703h
_nasm_mov_dx_cx = 0ca89h
_mov_dx_cx = 0d18bh
_nasm_add_ax_bx = 0d801h
_add_ax_bx = 0c303h
_nasm_add_bx_cx = 0cb01h
_add_bx_cx = 0d903h
_nasm_mov_ax_bx = 0d889h
_mov_ax_bx = 0c38bh
_nasm_xor_cx_cx = 0c931h
_xor_cx_cx = 0c933h
_nasm_mov_cx_di = 0f989h
_mov_cx_di = 0cf8bh
_nasm_sub_cx_dx = 0d129h
_sub_cx_di = 0ca2bh
_nasm_mov_bp_dx = 0d589h
_mov_bp_dx = 0ea8bh
_nasm_add_dx_ax = 0c201h
_add_dx_ax = 0d003h
_nasm_mov_si_bx = 0de89h
_mov_si_bx = 0f38bh
_nasm_mov_bx_di = 0fb89h
_mov_bx_di = 0df8bh
_nasm_cmp_bx_bp = 0eb39h
_cmp_bx_bp = 0dd3bh
_nasm_mov_cx_si = 0f189h
_mov_cx_si = 0ce8bh
_nasm_sub_cx_bx = 0d929h
_sub_cx_bx = 0cb2bh
_nasm_cmp_bx_dx = 0d339h
_cmp_bx_dx = 0da3bh
_nasm_mov_bp_sp = 0e589h
_mov_bp_sp = 0ec8bh
_nasm_sub_cx_si = 0f129h
_sub_cx_si = 0ce2bh
_nasm_mov_di_si = 0f789h
_mov_di_si = 0fe8bh
_nasm_xor_dx_dx = 0d231h
_xor_dx_dx = 0d233h
_nasm_sub_cx_ax = 0c129h
_sub_cx_ax = 0c82bh
_nasm_sub_bx_di = 0fb29h
_sub_bx_di = 0df2bh
_nasm_cmp_bx_cx = 0cb39h
_cmp_bx_dx = 0d93bh
_nasm_mov_cx_bx = 0d989h
_mov_cx_bx = 0cb8bh
_nasm_add_bx_di = 0fb01h
_add_bx_di = 0df03h
_nasm_mov_bx_cx = 0cb89h
_mov_bx_cx = 0d98bh
_nasm_sub_bx_cx = 0cb29h
_sub_bx_cx = 0d92bh
_nasm_mov_dx_bx = 0da89h
_mov_dx_bx = 0d38bh
_nasm_mov_bp_ax = 0c589h
_mov_bp_ax = 0e88bh
_nasm_cmp_di_bx = 0df39h
_cmp_di_bx = 0fb3bh
_nasm_mov_bx_bp = 0eb89h
_mov_bx_bp = 0dd8bh
_nasm_add_si_dx = 0d601h
_add_si_dx = 0f203h
_nasm_mov_ah_al = 0c488h
_mov_ah_al = 0e08ah
_nasm_mov_cx_ax = 0c189h
_mov_cx_ax = 0c88bh
_nasm_mov_bx_dx = 0d389h
_mov_bx_dx = 0da8bh
_nasm_mov_si_ax = 0c689h
_mov_si_ax = 0f08bh
_nasm_add_si_bx = 0de01h
_add_si_bx = 0f303h
_nasm_add_bx_ax = 0c301h
_add_bx_ax = 0d803h
_nasm_cmp_cx_ax = 0c139h
_cmp_cx_ax = 0c83bh
_nasm_mov_di_bx = 0df89h
_mov_di_bx = 0fb8bh
_nasm_mov_ax_dx = 0d089h
_mov_ax_dx = 0c28bh
_nasm_sub_ax_cx = 0c829h
_sub_ax_cx = 0c12bh
_nasm_cmp_dx_bx = 0da39h
_cmp_dx_bx = 0d33bh
_nasm_mov_di_ax = 0c789h
_mov_di_ax = 0f88bh
_nasm_mov_di_dx = 0d789h
_mov_di_dx = 0fa8bh
_nasm_mov_sp_bp = 0ec89h
_mov_sp_bp = 0e58bh
_nasm_mov_al_ah = 0e088h
_mov_al_ah = 0c48ah

parse_command_line:  ; Usage: pmwca.com <uncompressed-input.exe> <compressed-output.exe>
		mov si, 81h  ; Offset of DOS command-line string within the PSP segment (== CS == DS == ES ==SS), terminated by CR.
@@ws1:		lodsb
		cmp al, ' '
		je short @@ws1
		cmp al, TAB
		je short @@ws1
		cmp al, CR
		jne short @@fn1i
		mov bp, 'IM'  ; 'MI': Missing input filename.
		jmp short fatal
@@fn1i:		dw _nasm_mov_dx_si
		dec dx  ; DX := offset of input filename.
@@fn1:		lodsb
		cmp al, ' '
		je short @@fn1e
		cmp al, TAB
		je short @@fn1e
		cmp al, CR
		jne short @@fn1
@@fatal_mo:	mov bp, 'OM'  ; 'MO': Missing output filename.
		jmp short fatal
@@fn1e:		mov [byte si-1], 0  ; Modify command-line string in place: add terminating NUL for input filename.
@@ws2:		lodsb
		cmp al, CR
		je short @@fatal_mo
		cmp al, ' '
		je short @@ws2
		cmp al, TAB
		je short @@ws2
@@fn2i:		dec si  ; SI := offset of output filename.
		push si  ; Save offset of output filename. Will be popped by `pop dx' in write_udata.
@@fn2:		lodsb
		cmp al, ' '
		je short @@fn2e
		cmp al, TAB
		je short @@fn2e
		cmp al, CR
		jne short @@fn2
@@fn2e:		mov [byte si-1], 0  ; Modify command-line string in place: add terminating NUL for output filename.
		db 0a8h  ; Opcode of `test al, @@..', to skip over the next `lodsb'.
@@ws3:		lodsb
		cmp al, ' '
		je short @@ws3
		cmp al, TAB
		je short @@ws3
		cmp al, CR
		je short parse_command_line@@done
@@fatal_ta:	mov bp, 'AT'  ; 'TA': Too many command-line arguments.
		; Falls through to fatal.

; Exits the process with a fatal error (2 bytes of error message in BP).
fatal:		mov [word fatal_msg@@code], bp
		mov ah, 40h  ; Write to file using handle.
		mov bx, 2  ; STDERR_FILENO.
		mov dx, offset fatal_msg  ; DS:DI == pointer to start of buffer to be written.
		mov cx, fatal_msg@@end-fatal_msg  ; CX == number of bytes to write.
		int 21h  ; DOS syscall.
		mov ax, 4c01h  ; Exit with exit code EXIT_FAILURE (1).
		int 21h  ; DOS syscall. Doesn't return.

; If CF == 1, exits the process with a fatal error (2 bytes of error message
; in BP), otherwise returns. Keeps all registers including FLAGS intact.
fatal_if_c:	jc short fatal
		ret

parse_command_line@@done:
		; Now: DX == offset of input filename (uncompressed DOS .exe); DI == offset of output filename (compressed DOS .exe).
		; Falls through.

EXEHDRSIZE = 200h  ; Size of DOS .exe header created by TLINK.

read_udata:	mov ax, 3d00h  ; Open file for reading, using handle.
		;mov dx, ...  ; DX == offset of input filename.
		int 21h  ; DOS syscall. Sets AX to the filehandle.
		mov bp, 'IO'  ; 'OI': Error opening input file.
		call fatal_if_c
		xchg bx, ax  ; BX := filehandle of input file; AX := junk.
		mov ah, 3fh  ; Read from file using handle.
		;mov bx, ...  ; BX == filehandle of input file.
		mov dx, offset uexehdr  ; DS:DX == pointer to start of buffer to read uexehdr to.
		mov cx, EXEHDRSIZE  ; Maximum number of bytes to read.
		int 21h  ; DOS syscall. Sets AX to the number of bytes read.
		mov bp, 'HR'  ; 'RH': File read error reading the uncompressed DOS .exe header.
		call fatal_if_c
		cmp ax, strict_word EXEHDRSIZE
		je short @@hdrsize_ok
		mov bp, 'TH'  ; 'HT': Input file headers too short.
		jmp short fatal
@@hdrsize_ok:	dw _nasm_mov_si_dx  ; DS:SI := DS:DX == pointer to start of uexehdr.
		mov bp, 'ZM'  ; 'MZ'.
		cmp [si+0*2], bp  ; signature.
		jne short fatal  ; 'MZ': Bad DOS .exe signature.
		cmp [word si+4*2], byte_imm EXEHDRSIZE shr 4  ; hdrsize.
		mov bp, 'SH'  ; 'HS': Unsupported DOS .exe header size (hdrsize).
		jne short fatal
		mov ah, 3fh  ; Read from file using handle.
		;mov bx, ...  ; BX == filehandle of input file.
		mov dx, offset udata  ; DS:DX == pointer to start of buffer to read to.
		mov cx, udata@@bufend-udata  ; Maximum number of bytes to read.
		int 21h  ; DOS syscall. Sets AX to the number of bytes read.
		mov bp, 'DR'  ; 'RD': File read error reading the uncompressed DOS .exe image.
		call fatal_if_c
		add ax, strict_word offset udata
		cmp ax, strict_word offset udata@@bufend
		jb short read_udata@@usize_ok
		mov bp, 'LT'  ; 'TL': Input file too long.
read_udata@@j_fatal:
		jmp short fatal
read_udata@@usize_ok:
		push ax  ; Save offset of end of udata.
		mov ah, 3eh  ; Close file using handle.
		int 21h  ; DOS syscall.
		; Now: DS:SI := DS:DX == pointer to start of uexehdr.
		; Falls through.

compress_relocs:
		mov cx, [si+3*2]  ; nreloc.
		test cx, cx
		mov bp, 'RN'  ; 'NR': No relocations. (apply_relocs) depends on a nonzero nreloc value.
		jz short read_udata@@j_fatal
		cmp cx, byte_imm (EXEHDRSIZE-1ch) shr 2
@@fatal_tr:	mov bp, 'RT'  ; 'TR': Too many relocations.
		ja short read_udata@@j_fatal
		mov di, [si+12*2]  ; relocpos.
		cmp di, strict_word EXEHDRSIZE
		mov bp, 'PR'  ; 'RP': Relocations start too late.
		jnb short read_udata@@j_fatal
		dw _nasm_mov_ax_cx
		dw _nasm_add_ax_ax  ; Continued below...
		dw _nasm_add_ax_ax  ; AX := nreloc<<2.
		dw _nasm_add_ax_di  ; AX += relocpos.
		cmp ax, strict_word EXEHDRSIZE
		ja short @@fatal_tr
		lea ax, [di+uexehdr]  ; AX := uexehdr+relocpos.
		dw _nasm_mov_dx_cx  ; nreloc.
		call sort4  ; Sorts relocations by (segment descending, then offset ascending). Ruins AX, BX, DX, SI, BP and FLAGS. Keeps CX and DI.
@@squeeze_relocs:  ; Convert each relocation from dword-sized (offset, segment) pair to word-sized offset+0x100.
		lea si, [di+uexehdr]  ; SI := uexehdr+relocpos.  Source of (offset, segment) pairs.
		mov di, offset creloc  ; DS:DI := pointer to the squeezed relocations.
		pop dx  ; DX := offset of end of udata.
		;mov cx, [si+3*2]  ; CX == nreloc. Nonzero.
		push cx  ; Save nreloc.
		push di  ; Save creloc.
@@next:		lodsw
		xchg bx, ax  ; BX := offset of the relocation; AX := junk.
		inc bh  ; BX += 0x100.
		lodsw
		dw _nasm_add_ax_ax  ; Continued below...
		dw _nasm_add_ax_ax  ; Continued below...
		dw _nasm_add_ax_ax  ; Continued below...
		dw _nasm_add_ax_ax  ; AX <<= 4. Convert from real-mode segment value to byte offset.
		dw _nasm_add_ax_bx
		stosw
		loop @@next
		; Falls through.

build_preparator_buf:
		mov si, offset udata
		mov di, offset cdata
		;mov dx, ...  ; DX is already correct: DX := offset of end of udata.
		call compress  ; Append compressed data to DS:DI == ES:DI. Ruins AX, BX, CX, DX, SI, BP, FLAGS. Sets DS:DI to pointer to end of cdata.
		pop si  ; Restore SI := creloc.
		pop cx  ; Restore CX := nreloc.
		lea bx, [word di-(preparator_buf-$$+BASE)]  ; BX := csize + (cdata - preparator_buf).
		dw _nasm_add_bx_cx  ; Continued below...
		dw _nasm_add_bx_cx  ; BX := csize + (nreloc << 1) + (cdata - preparator_buf).
		mov [byte apply_relocs@@u_nreloc], cl  ; It fits to 1 byte, we've checked it above at 'TR'.
		rep movsw  ; Append compressed relocationss to DS:DI == ES:DI.
		; Now: DS:DI == pointer to the end of cdata.
		dw _nasm_mov_ax_bx
		and ax, strict_word 1ffh
		mov [word cexehdr@@lastsize], ax
		lea ax, [bx+1ffh]  ; Round up.
		shr ax, 1
		mov [byte cexehdr@@nblocks], ah  ; Set low byte. The high byte will remain 0.
		sub bx, byte_imm 20h  ; BX := csize + (nreloc << 1) + (cdata - preparator_buf) - (chdrsize << 4).
		lea ax, [bx+1]  ; Round up.
		shr ax, 1
		mov [word copy_code@@word_count], ax  ; Number of words to copy.
		mov si, offset uexehdr+7*2  ; U_SS.
		lodsw  ; AX := U_SS; SI += 2 (to U_SP).
		mov [word cexehdr@@ss], ax
		mov [word jump_to_program@@u_ss], ax
		lea bx, [bx+0fh]  ; Round up.
		mov cl, 4
		shr bx, cl  ; BX := (csize + (nreloc << 1) + (cdata - preparator_buf) - (chdrsize << 4) + 0xf) >> 4.
		add ax, strict_word ((100h+0fh) shr 4)+1  ; Why the +1? Maybe it's related to the bug in the original PMODE/W compressor.
		dw _nasm_add_ax_bx  ; AX := (U_SS + ((0x100 + 0xf) >> 4)) + ((csize + (nreloc << 1) + (cdata - preparator_buf) - (chdrsize << 4) + 0xf) >> 4) + 1.
		mov [word cexehdr@@minalloc], ax  ; The value computed above is larger than needed, so this is wasting memory at runtime. This is probably a bug in the original PMODE/W compressor.
		lodsw  ; AX := U_SP. SI += 2 (to U_CHECKSUM).
		mov [word jump_to_program@@u_sp], ax
		lodsw  ; AX := U_CHECKSUM (will be ignored). SI += 2 (to U_IP).
		lodsw  ; AX := U_IP. SI += 2 (to U_CS).
		mov [word uncompressed_start_far_ptr@@u_ip], ax
		lodsw  ; AX := U_CS. SI += 2 (to U_RELOCPOS, will be ignored).
		mov [word uncompressed_start_far_ptr@@u_cs], ax
		; Now: DS:DI == pointer to the end of cdata.
		; Falls through.

write_cdata:	mov ah, 3ch  ; Open file for writing, optionally create it, truncate it, using handle.
		dw _nasm_xor_cx_cx  ; File attributes: none.
		pop dx  ; Restore DX := output filename.
		int 21h  ; DOS syscall. Sets AX to the filehandle.
		mov bp, 'OO'  ; 'OO': Error opening input file.
		call fatal_if_c
		xchg bx, ax  ; BX := filehandle of input file; AX := junk.
		mov ah, 40h  ; Write to file using handle.
		;mov bx, ...  ; BX == filehandle of output file.
		mov dx, offset preparator_buf  ; DS:DX == pointer to start of buffer to be written.
		dw _nasm_mov_cx_di  ; Pointer to the end of cdata.
		dw _nasm_sub_cx_dx  ; CX := DI - preparator_buf. CX == number of bytes to write.
		mov bp, 'RW'  ; 'WR': File write error.
		int 21h  ; DOS syscall.
		call fatal_if_c
if 0  ; No need to close the output file, DOS will close it right below, when to process exits.
		mov ah, 3eh  ; Close file using handle.
		int 21h  ; DOS syscall.
endif
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
		jne short @@done  ; CF is already correct: CF == 1 if second is less, CF == 0 otherwise.
		mov ax, [si]  ; First offset.
		cmp ax, [di]  ; Compare to second offset.
		; CF is already correct: CF == 1 if first is less, CF == 0 otherwise.
@@done:		ret

; Sorts an array of 4 bytes each using the comparison function is_reloc_less.
; May or may not be stable.
;
; Uses a constant amount of memory in addition to the input/output array.
;
; Inputs: DS:AX: pointer to the start of the array; DX: number of array elements.
; Ruins: AX, DX, FLAGS.
;
; typedef unsigned size_t;
; #define SIZE 4
; extern char is_reloc_less(const void *a, const void *b);
; #pragma aux is_reloc_less __parm [__si] [__di] __modify [__ax] __value [__cf]  /* OpenWatcom C compiler doesn't actually support __value [__cf]. */
; extern void memswap4(void *a, void *b);
; #pragma aux memswap4 __parm [__si] [__di] __modify [__ax]
; void sort4(void *base, size_t n);
; #pragma aux heapsort4 __parm [__ax] [__dx] __modify [__ax __bx __dx __si __bp]
sort4:
ifdef FASTSORT
  ; Based on heapsort algorithm H from Knuth TAOCP 5.2.3H. Not stable.
  ; Worst case execution time: O(n*log(n)), 3*n*log_2(n) comparisons, and
  ; fewer swaps.
  ;
  ; Compared to Knuth's algorith, this implementation contains swaps instead
  ; of assignments to temporary variable with swaps.
  ;
  ; void sort4(void *base, size_t n) {
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
  heapsort4:
		push cx  ; Save.
		push di  ; Save.
		dw _nasm_mov_bp_sp
		sub sp, byte_imm 8
		dw _nasm_mov_cx_ax
		dw _nasm_mov_bx_dx
		shr bx, 1
		shl bx, 1
		shl bx, 1
		dw _nasm_mov_si_ax
		dw _nasm_add_si_bx
		mov [word bp-2], si
		dw _nasm_mov_bx_dx
		shl bx, 1
		shl bx, 1
		sub bx, byte_imm 4
		dw _nasm_add_bx_ax
		cmp dx, byte_imm 2
		jb short @@done
  @@1:		mov ax, [word bp-2]
		dw _nasm_cmp_cx_ax
		je short @@2
		sub [word bp-2], byte_imm 4
		mov ax, [word bp-2]
		mov [word bp-4], ax
		jmp short @@3
  @@2:		dw _nasm_mov_di_bx
		dw _nasm_mov_si_ax
		call memswap4
		sub bx, byte_imm 4
		dw _nasm_cmp_bx_cx
		je short @@done
		mov [word bp-4], cx
  @@3:		mov dx, [word bp-2]
  @@4:		mov [word bp-8], dx
		dw _nasm_mov_ax_dx
		dw _nasm_sub_ax_cx
		add ax, strict_word 4
		dw _nasm_add_dx_ax
		dw _nasm_cmp_dx_bx
		ja short @@7
		jae short @@5
		dw _nasm_mov_ax_dx
		add ax, strict_word 4
		mov [word bp-6], ax
		dw _nasm_mov_di_ax
		dw _nasm_mov_si_dx
		call is_reloc_less
		;test al, al
		;je short @@5  ; Jump if not less.
		jnc short @@5  ; Jump if not less.
		mov dx, [word bp-6]
  @@5:		dw _nasm_mov_di_dx  ; jp += SIZE.
		mov si, [word bp-4]
		call is_reloc_less
		;test al, al
		;je short @@7  ; Jump if not less.
		jnc short @@7  ; Jump if not less.
		dw _nasm_mov_di_dx
		mov si, [word bp-8]
		call memswap4
		mov [word bp-4], dx
		jmp short @@4
  @@7:		mov di, [word bp-4]
		mov si, [word bp-8]
		call memswap4
		jmp short @@1
  @@done:	dw _nasm_mov_sp_bp
		pop di  ; Restore.
		pop cx  ; Restore.
		ret

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
else
  ; It implements insertion sort. It is stable. Its worst case is slower than
  ; of heapsort.
  ;
  ; Worst case number of comparisons and swaps: n*(n-1)/2. Best case is when
  ; the input is sorted: n-1 comparisons and 0 swaps.

  ; It implements swapping of elements by rotating a sequence of elements to
  ; the right by 1 element. It rotates one word at a time (unlike the C code).
  ;
  ; void sort4(void *base, size_t n) {
  ;   char *oldcur, *end, *newcur, *mid, tmp, *cur;
  ;   if (n >= 1) {  /* Equivalent to: if (n > 1) */
  ;     for (cur = (char*)base + SIZE, end = (char*)base + (SIZE * n);
  ;          cur != end;
  ;          cur = newcur) {
  ;       newcur = cur + SIZE;
  ;       if (is_less(cur, cur - SIZE)) {
  ;         oldcur = cur;
  ;         do {
  ;           cur -= SIZE;
  ;         } while (cur != (char*)base && is_less(oldcur, cur - SIZE));
  ;         /* memrotate(cur, oldcur, SIZE); */
  ;         while (oldcur != newcur) {
  ;           mid = oldcur;
  ;           tmp = *mid;
  ;           while (mid != cur) {
  ;             *mid = *(mid - SIZE);
  ;             mid -= SIZE;
  ;           }
  ;           *mid = tmp;
  ;           ++oldcur;
  ;           ++cur;
  ;         }
  ;       }
  ;     }
  ;   }
  ; }
  insertion_sort4:
		push cx  ; Save.
		push di  ; Save.
		cmp dx, byte_imm 1  ; Argument n.
		jbe short @@done
		xchg ax, dx  ; AX := DX (argument n); DX := old_AX (argument base).
		dw _nasm_mov_bp_dx  ; BX will keep holding argument base throughout the rest of the function.
		lea bx, [bp+4]  ; BX (cur) := base + SIZE.
		dw _nasm_add_ax_ax  ; Continued below...
		dw _nasm_add_ax_ax  ; AX *= 4.
		dw _nasm_add_dx_ax  ; DX (var_end) := base + SIZE * n.
  @@next:	lea di, [bx-4]
		dw _nasm_mov_si_bx  ; SI := BX *cur).
		call is_reloc_less  ; is_less(cur, cur - SIZE).
		jnc short @@continue  ; Jump if not less.
		dw _nasm_mov_si_bx  ; SI (oldcur) := BX (cur).
  @@scan_next:	dw _nasm_mov_bx_di  ; BX (cur) -= SIZE.
		dw _nasm_cmp_bx_bp  ; while (cur != base ...)
		je short @@rotate
		lea di, [bx-4]
		call is_reloc_less  ; is_less(oldcur, cur - SIZE).
		jc short @@scan_next  ; Jump if less.
  @@rotate:	; Now, until .continue, we will rotate the region BX...(SI+4) left (forward) by a dword (SIZE == 4).
		; That is, save `dword [si]' to tmp, then copy from BX...SI to (BX+4)..(SI+4), then restore `dword [bx]' from tmp.
		; We are allowed to ruin AX, CX, SI, DI and FLAGS until continue.
		dw _nasm_mov_cx_si
		dw _nasm_sub_cx_bx
		shr cx, 1  ; Convert byte count to word count.
		lea di, [si+2]
		std
		lodsw  ; Save second highest word to AX.
		push [word di]  ; Save highest word.
		rep movsw
		cld  ; Restore DF := 0, we are not allowed to ruin that flag.
		pop [word di]  ; Restore highest word.
		mov [bx], ax  ; Restore second highest word.
		; Rotation done. Now AX, CX (== 0), SI, DI and FLAGS are ruined.
  @@continue:	lea bx, [bx+4]  ; BX (cur) := BX + 4 (newcur).
		dw _nasm_cmp_bx_dx  ; cur != end.
		jne short @@next
  @@done:	pop di  ; Restore.
		pop cx  ; Restore.
		ret
endif

ifdef DEBUG
  LF = 10

  print_nibble:	push ax
		add al, '0'
		cmp al, '9'
		jna short @@ok
		add al, 'a'-'0'-10
  @@ok:		int 29h
		pop ax
		ret

  print_al:	push ax
		aam 10h
		xchg al, ah
		call print_nibble
		dw _nasm_mov_al_ah
		call print_nibble
		pop ax
		ret

  print_ax:	push ax
		xchg al, ah
		call print_al
		dw _nasm_mov_al_ah
		call print_al
		pop ax
		ret

  print_literal:
		push ax
		mov al, 'L'
		int 29h
		mov al, [si]
		call print_al
		mov al, LF
		int 29h
		pop ax
		ret

  print_distance:
		push ax
		mov al, 'D'
		int 29h
  print_distance@@ax:
		pop ax
		push ax
		call print_ax
  print_distance@@lf:
		mov al, LF
		int 29h
		pop ax
		ret

  print_length:	push ax
		mov al, 'E'
		int 29h
		jmp short print_distance@@ax

  ; Prints the bit in CF. Also ruins CF.
  print_bit:	push ax
		pushf
		mov al, 'B'
		int 29h
		mov al, '0'
		popf
		adc al, 0
		int 29h
		jmp short print_distance@@lf

  print_m1:	push ax
		mov al, 'X'
		int 29h
  print_m1@@al:	pop ax
		push ax
		call print_al
		jmp short print_distance@@lf

  print_m1101:	push ax
		mov al, 'Y'
		int 29h
		jmp short print_m1@@al

  macro do_emit_m1  ; Emits a byte in AL. Uses ES:DI.
    call print_m1
    stosb
  endm do_emit_m1
  macro do_emit_m1101  ; Emits a byte in AL. Uses ES:DI.
    call print_m1101
    stosb
  endm do_emit_m1101
else
  macro do_emit_m1  ; Emits a byte in AL. Uses ES:DI.
    stosb
  endm do_emit_m1
  macro do_emit_m1101  ; Emits a byte in AL. Uses ES:DI.
    stosb
  endm do_emit_m1101
endif

; Emits a bit in CF, ruins CF.
; Input: SS:BP points to the local variables of the compress function.
; Input: DS:DI == ES:DI points to the end of the compressed output data (cdata_end == cdata_cur).
; Output: DI incremented when a new 16-bit block (tag) word is emitted to DS:DI == ES:DI.
; Input and output: The offset of the current 16-bit block (tag) word value is in word [bp+2*2]. The segment is DS == ES. Will be modified.
; Input and output: The block (tag) next-write power-of-two bitmask is in word [bp+4*2]. Will be modified.
; Ruins: FLAGS (incuding CF).
emit_bit:
ifdef DEBUG
		pushf
		call print_bit
		popf
endif
		push ax  ; Save.
		push bx  ; Save.
		mov bx, [bp+2*2]
		mov ax, [bp+4*2]
		jnc short @@done_or  ; Uses the CF value at the beginning of emit_bit.
		or [bx], ax
@@done_or:	dw _nasm_add_ax_ax
		jnz short @@done
		mov [bp+2*2], di
		stosw  ; Append new 16-bit block (tag) word value, with initial value of 0. Uses ES:DI.
		inc ax  ; AX := 1.
@@done:		mov [bp+4*2], ax
		pop bx  ; Restore.
		pop ax  ; Restore.
		ret

MAX_LENGTH = 270
MAX_DISTANCE_FOR_LENGTH_2 = 800h-1
MAX_DISTANCE = 1000h-1

; Compresses bytes starting at DS:SI == ES:SI until DS:DX == ES:DX (DX is
; not a byte count, but an offset!), writing the compressed stream to DS:DI
; == ES:DI, using a variant of LZSS. The input must not be empty.
;
; Output: DS:DI == ES:DI: offset of the end of the compressed output data.
; Ruins: AX, BX, CX, DX, SI, BP, FLAGS.
compress:	mov ax, 1
		push ax  ; word [bp+4*2]: Save initial block (tag) next-write power-of-two bitmask.
		push dx  ; word [bp+3*2]: Save offset of the end of the uncompressed input data (udata_end). Sometimes DI is used instead of this. Remains constant throughout the function.
		movsb  ; Uses DS:SI and ES:DI. Copy literal byte to compressed output data.
		push di  ; word [bp+2*2]: Save offset of the current 16-bit block (tag) word value. The segment is DS == ES.
		dec ax ; AX := 0.
		stosw  ; Initial 16-bit block (tag) word value (0).
		push di  ; word [bp+1*2]: Save offset of the end of the compressed output data (cdata_end == cdata_cur). Will be incremented throughout the function.
		dec si
		push si  ; word [bp+0*2]: Save offset of the start of the uncompressed input data (udata_start). Remains constant throughout the function.
ifdef DEBUG
		call print_literal  ; Value: `byte [si]'.
endif
		inc si  ; Skip over literal byte in the uncompressed input data.
		dw _nasm_mov_bp_sp
@@next_byte:	mov [bp+1*2], di  ; cdata_end == cdata_cur.
		mov cx, [bp+3*2]  ; udata_end.
		dw _nasm_sub_cx_si
		jz short @@done
		cmp cx, MAX_LENGTH
		jb short @@cx_ok
		mov cx, MAX_LENGTH
@@cx_ok:	; CX will keep holding the maximum match length starting at DS:SI, until the next .next_byte (i.e. when SI is increased).
		dw _nasm_mov_di_si
		dw _nasm_xor_dx_dx  ; Best length so far. No need to initialize BP (best distance) here.
		mov ax, -1  ; Current distance.
		jmp short @@next_start
@@done:		stc
		call emit_bit  ; Emit end-of-stream (EOS) sequence.
		clc
		call emit_bit
		mov al, 0
		do_emit_m1  ; In AL.
		clc
		call emit_bit
		; Now: DI == the correct, final value for cdata_end == cdata_cur.
		add sp, byte_imm 5*2  ; Clean up local variables from the stack.
		ret
		; Registers through the .next_start loop below:
		; * AX, BX: scratch.
		; * CX: maximum match length starting at DS:SI. Remains until the next .next_byte (i.e. right after SI is increased).
		; * DX: best (longest) match length so far.
		; * DS:SI == ES:SI: points to the current byte of the udata to compress. Remains unchanged until .got_literal_or_match.
		; * DS:DI == ES:DI: points to the first byte of the next match candidate (DI <= SI).
		; * BP: best distance corresponding to the length in the best match so far.
@@next_start:	dec di  ; Update match start.
		inc ax  ; Update current distance.
		cmp ax, strict_word MAX_DISTANCE
		ja short @@got_literal_or_match  ; If distance is too large, then ignore the match and all possible larger-distance matches.
		pop bx  ; Restore BX := udata_start.
		push bx  ; Save udata_start.
		push cx  ; Save.
		mov cx, MAX_DISTANCE
		dw _nasm_sub_cx_ax
		dw _nasm_sub_bx_di
		neg bx
		inc bx  ; BX := DI-(udata_start-1).
		dw _nasm_cmp_bx_cx
		jae short @@cx_ok2
		dw _nasm_mov_cx_bx  ; CX := min(MAX_DISTANCE-AX, DI-(udata_start-1)).
@@cx_ok2:	xchg bx, ax  ; BX := AX; AX := junk.
		dw _nasm_add_bx_di
		mov al, [si]  ; First byte.
		std
		repne scasb  ; Uses ES:DI. Try to find the first byte backward which matches the first byte (AL).
		cld
		pop cx  ; Restore.
		jne short @@got_literal_or_match
@@found_first_byte:
		inc di
		dw _nasm_sub_bx_di
		xchg ax, bx  ; AX := BX (distance); BX := junk.
@@find_common_prefix_length:
		; Finds the (longest) common prefix length of the CX bytes starting at DS:SI and ES:DI.
		; Input: DS:SI points to byte string a, ES:DI points to byte string b, CX: number of bytes.
		; Output: BX: longest common prefix length.
		; Ruins: FLAGS, CX.
		push si  ; Save.
		push di  ; Save.
		dw _nasm_mov_bx_cx
		repe cmpsb  ; Uses DS:SI and ES:DI. Also reads and modifies SI, DI and CX.
		je short @@after_inc
		inc cx
@@after_inc:	xchg bx, cx  ; CX := maximum match length starting at DS:SI.
		dw _nasm_sub_bx_cx
		neg bx  ; BX := longest common prefix length.
		pop di  ; Restore.
		pop si  ; Restore.
		cmp bx, byte_imm 2
		ja short @@longer_than_2
		cmp ax, strict_word MAX_DISTANCE_FOR_LENGTH_2
		ja short @@keep_best  ; Ignore the match if distance is too large.
@@longer_than_2:
		dw _nasm_cmp_bx_dx
		jb short @@keep_best  ; Ignore the match if shorter than the previous best match.
		ja short @@new_best  ; Save match as best match if longer than the previous match.
		; Now we have the complicated case of the match (with
		; distance AX) with the same length (BX == DX) as a previous
		; match (with distance BP; BP < AX).
		;
		; We want to use this match as new best iff its bitstream
		; will be of the same number of bits (not longer) as the
		; previous match of the same size. The condition:
		;
		;   BX == 2 ? (BP > 0xfe || AX <= 0xfe) : (BP > 0x3ff || AX <= (BP <= 0xff ? 0xff : 0x3ff)).
		cmp bx, byte_imm 2
		ja short @@check_eq_length_3plus
@@check_eq_length_2:
		cmp bp, 0feh
		ja short @@new_best
		cmp ax, 0feh
		jmp short @@check_eq_cjmp
@@check_eq_length_3plus:
		cmp bp, 3ffh
		ja short @@new_best
		cmp bp, 0ffh
		ja short @@check_eq_length_3plus_large_distance
@@check_eq_length_3plus_small_distance:
		cmp ax, 0ffh
		jmp short @@check_eq_cjmp
@@check_eq_length_3plus_large_distance:
		cmp ax, 3ffh
@@check_eq_cjmp:
		ja short @@keep_best
@@new_best:	dw _nasm_mov_dx_bx  ; Found longer length. Update best length.
		dw _nasm_mov_bp_ax  ; Update distance corresponding to best length.
@@keep_best:	pop bx  ; Restore BX := udata_start.
		push bx  ; Save udata_start.
		dw _nasm_cmp_di_bx
		jne short @@next_start
@@got_literal_or_match:
		dw _nasm_mov_bx_bp  ; BX := best distance.
		dw _nasm_mov_bp_sp
		mov di, [bp+1*2]  ; cdata_end == cdata_cur.
		cmp dx, byte_imm 2
		jae short @@match
@@literal:	clc
		call emit_bit
ifdef DEBUG
		call print_literal
endif
		movsb  ; Copies a literal byte from DS:SI to ES:DI. Also skips over literal byte in the uncompressed input data (SI += 1).
		jmp short @@j_next_byte
@@match:	dw _nasm_add_si_dx  ; Skip over matched bytes in the uncompresed input data.
		call emit_match  ; Ruins AX, BX, CX, DX, DI, BP, FLAGS. Keeps SI and BP intact.
@@j_next_byte:	jmp strict_near @@next_byte

; Emits CL (1 <= CL <= 7) bits from AH, highest (of the CL) bits first.
; Ruins: CX (sets it to 0), FLAGS.
emit_bits:
		mov ch, 0
@@next:		push ax  ; Save.
		shr ah, cl  ; CF := pint to print.
		pop ax  ; Restore.
		call emit_bit
		loop @@next
		ret

; Emits an encoded match == (distance, length) == (BX, DX) pair. 0 <= BX <= 0xfff; 2 <= DX <= 270. If DX == 2, then also BX <= 0x7ff.
; Input: SS:BP points to the local variables of the compress function.
; Input: DS:DI == ES:DI points to the end of the compressed output data (cdata_end == cdata_cur).
; Output: DI incremented as emit_match and its subfunctions write compressed output bytes to DS:DI == ES:DI.
; Keeps SI and BP intact.
; Ruins: AX, BX, CX, DX, FLAGS.
emit_match:
ifdef DEBUG
		dw _nasm_mov_ax_bx
else
		xchg ax, bx  ; AX := distance; BX := junk.
endif
		stc
		call emit_bit
		cmp dx, byte_imm 3  ; Also CF := (len == 2).
		cmc  ; CF := (len != 2).
		call emit_bit
		cmp dx, byte_imm 2
		jne short @@dist_3plus
@@dist_2:	cmp ax, strict_word 0ffh
		jae short @@dist_2_big
@@dist_2_small:	inc ax
		do_emit_m1  ; In AL.
		clc
		call emit_bit
		jmp short @@after_bits
@@dist_2_big:	do_emit_m1  ; In AL.
		stc
		call emit_bit
		mov cl, 3
		call emit_bits
		jmp short @@after_bits
@@dist_3plus:	do_emit_m1  ; In AL.
		test ah, ah
		jnz short @@dist_3plus_mid_or_big
@@dist_3plus_small:
		clc
		call emit_bit
		jmp short @@len
@@dist_3plus_mid_or_big:
		stc
		call emit_bit
		mov cl, 3
		cmp ah, 4
		jae short @@dist_3plus_big
@@dist_3plus_mid:
		and ax, strict_word 3ffh  ; Same size as: `and ah, 3'. Makes the next `print bit' start with a 0 bit.
		jmp short @@dist_bits  ; With CL == 3.
@@dist_3plus_big:
		stc
		call emit_bit
		inc cx  ; CL := 4.
@@dist_bits:	call emit_bits
@@len:
ifdef DEBUG
		dw _nasm_mov_ax_dx
else
		xchg ax, dx  ; AX := length; DX := junk.
endif
		cmp ax, strict_word 7
		jae short @@len_mid_or_big
@@len_short:	xchg cx, ax  ; CX := length; AX := junk.
		dec cx  ; Continued below...
		dec cx  ; CX := length - 2.
		mov ah, 1  ; Prints (1..3) 0 bits and a 1 bit.
		jmp short @@len_bits
@@len_mid_or_big:
		sub ax, strict_word 15
		jae short @@len_big
@@len_mid:	add al, 15-7
		and al, 7
		dw _nasm_mov_ah_al
		mov cl, 8  ; Prints 5 0 bits and 3 length bits.
@@len_bits:	call emit_bits
		jmp short @@after_bits
@@len_big:	mov ah, 1
		mov cl, 5   ; Prints 4 0 bits and a 1 bit.
		call emit_bits
		do_emit_m1101  ; In AL.
@@after_bits:
ifdef DEBUG
		xchg ax, dx  ; AX := DX (length); DX := junk.
		call print_length
		xchg ax, bx  ; AX := BX (distance); BX := junk.
		call print_distance
endif
		ret

fatal_msg:	db 'pmwca: fatal: '
fatal_msg@@code: db '??', 13, 10
fatal_msg@@end:

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
cexehdr@@signature:	db 'MZ'
cexehdr@@lastsize:	dw 0       ; Length of load module mod 200H. build_preparator_buf will populate it.
cexehdr@@nblocks:	dw 0       ; Number of 200H pages in load module. build_preparator_buf will populate its low byte.
cexehdr@@nreloc:	dw 0       ; Number of relocation items; no relocations.
cexehdr@@hdrsize:	dw 2       ; Size of header in paragraphs.
cexehdr@@minalloc:	dw 0       ; Minimum number of paragraphs required above load mod. build_preparator_buf will populate it with a value is larger than needed. This is probably a bug in the original PMODE/W compressor.
cexehdr@@maxalloc:	dw -1      ; Maximum number of paragraphs required above load mod.
cexehdr@@ss:		dw 0       ; Offset of stack segment in load module. Same as U_SS. build_preparator_buf will populate it.
cexehdr@@sp:		dw 100h   ; Initial value of SP. Constant.
cexehdr@@checksum:	dw 0       ; Checksum.
cexehdr@@ip:		dw exe_start-exe_image  ; Initial value of IP.
cexehdr@@cs:		dw 0       ; Offset of code segment within load module (segment).
cexehdr@@relocpos:	dw 003eh  ; File offset of first relocation item. Unused because of nreloc == 0.
cexehdr@@noverlay:	dw 0      ; Overlay number. Unused.

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
@@pagetables:	db 4  ; Number of page tables under VCPI.                                             _pm_pagetables:
@@selectors:	dw 100h  ; Max selectors under VCPI/XMS/raw.                                         _pm_selectors:
@@rmstacklen:	dw 40h  ; Real mode stack length, in para.                                           _pm_rmstacklen:
@@pmstacklen:	dw 80h  ; Protected mode stack length, in para.                                      _pm_pmstacklen:
@@rmstacks:	db 8  ; Real mode stack nesting.                                                      _pm_rmstacks:
@@pmstacks:	db 8  ; Protected mode stack nesting.                                                 _pm_pmstacks:
@@callbacks:	db 20h  ; Number of real mode callbacks.                                             _pm_callbacks:
@@mode:		db 1  ; Mode bits.                                                                    _pm_mode:
@@pamapping:	db 1  ; Physical address mappings pages max.                                          _pm_pampagemax:
@@crap:		dw 0  ; Unused.
@@options:	db 1  ; Option flags. 0 = hide copyright message; 1 == display copyright message.     _pm_options:
@@extmax:	dd 7fffffffh  ; Maximum extended memory to allocate.                                 _pm_maxextmem:
@@lowmin:	dw 0  ; Amount of low memory to try and save. Loaded by _openexe2 to somewhere else.  _lowmin:

ife PMWVV-33
  copyright:	db 'PMODE/W v1.33 DOS extender - Copyright 1994-1997, Daredevil and Tran.'
elseife PMWVV-34
  copyright:	db 'PMODE/W v1.34 DOS extender - Copyright 1994-2000, Daredevil and Tran.'
else
  err 'ERROR_UNSUPPORTED_PMWV' PMWV
endif

uncompressed_start_far_ptr:
uncompressed_start_far_ptr@@u_ip: dw 0  ; build_preparator_buf will populate it.
uncompressed_start_far_ptr@@u_cs: dw 0  ; build_preparator_buf will populate it.

; Identical version of 8086 opcode encoding.
_mov_bl_al = 0d88ah
_mov_bp_ax = 0e88bh
_mov_bx_ax = 0d88bh
_mov_cl_al = 0c88ah
_mov_cl_dh = 0ce8ah
_mov_si_di = 0f78bh
_xor_bx_bx = 0db33h
_xor_dh_dh = 0f632h
_add_dx_strict_word = 0c281h  ; To force TASM to emit an `add dx, ...' instruction with a word-encoded immediate.

exe_start:  ; Compressed .exe entry point.
copy_code:
		cld
		push ss  ; orig_CS+0x3d7 == orig_CS+U_SS.
		pop es  ; ES := orig_CS+0x3d7. DS remains PSP_segment == orig_cs-0x10.
		mov di, 100h  ; The compressed SP value.
		dw _mov_si_di
		push di  ; 0x100.
		mov cx, 0  ; Number of words to copy: (cdata.end-exe_image+1)>>1. build_preparator_buf will populate it.
copy_code@@word_count = $-2
		rep movsw  ; DS == orig_CS-0x10 == PSP_segment.
		push es  ; orig_CS+0x3d7.
		push ds  ; orig_CS-0x10.
		pop es   ; ES := orig_CS-0x10.
		pop ds   ; DS := orig_CS+0x3d7.
		pop di   ; DI := 0x100.
		mov si, cdata-exe_image+100h  ; DS:SI now points to the start of the copy of cdata. Constant.
		push es  ; orig_CS-0x10. Will be popped by `pop ds' in jump_to_program.
		push cs  ; orig_CS == PSP_segment. Will be popped by `pop dx' in jump_to_program.
		movsb  ; Copy initial literal token.
		lodsw  ; AX := initial 16-bit block (tag) word value.
		dw _mov_bp_ax  ; BP will keep holding the block word throught decompression. `xchg bp, ax' would have been shorter.
		mov dl, 10h  ; DL will keep holding the Number of bits remaining in the block word (BP). Starting at 0x10 == 16.
		push ds  ; Segment for the `retf' below: orig_CS+0x3d7.
		mov ax, decompress@@start-exe_image+100h
		push ax  ; Offset for the `retf' below: 0x100+0xd9 == 0x100 + decompress.literal.
		retf  ; Jump to (orig_CS+0x3d7):0x1d9, which is a copy of decompress.start == decompress.next_token.

decompress:  ; Entry point is decompress.start. It needs initialization, see above.
decompress@@get_bit:
		shr bp, 1  ; CF := the first bit in a block to be used is its lowest bit.
		dec dl  ; Doesn't modify CF.
		jnz short @@get_bit_ret
		lodsw
		dw _mov_bp_ax  ; `xchg bp, ax' would have been shorter here.
		mov dl, 10h  ; Again, 0x10 == 16 are available in BP.
@@get_bit_ret:	ret
decompress@@match_1_1:
		call decompress@@get_bit
		jnc short @@match_1_1_0
@@match_1_1_1:	call decompress@@get_bit
		adc cl, 1
		shl cl, 1
@@match_1_1_1_next:
		call decompress@@get_bit
		rcl bh, 1
		loop @@match_1_1_1_next  ; Then falls through to .match_1_1_0.
@@match_1_1_0:	mov dh, 2
		mov cl, 4
@@match_1_1_0_next:
		inc dh
		call decompress@@get_bit
		jc short @@copy_match_count_dh
		loop @@match_1_1_0_next
		call decompress@@get_bit
		jnc short @@match_1_1_0_0
@@match_1_1_0_1:
		lodsb
		dw _mov_cl_al
		add cx, byte_imm 0fh
		jmp short decompress@@copy_match
@@match_1_1_0_0:
		dw _xor_dh_dh
		mov cl, 3h
@@match_1_1_0_0_next:
		call decompress@@get_bit
		rcl dh, 1
		loop @@match_1_1_0_0_next
		add dh, 7h
@@copy_match_count_dh:
		dw _mov_cl_dh
		jmp short decompress@@copy_match
decompress@@copy_match_2_bytes:
		mov cl, 2  ; CX := 2. Assumes CH == 0. Falls through to .copy_match.
decompress@@copy_match:  ; Copies a match with (distance, length) == (BX, CX). The distance 0 means: copy the previously emitted byte (at [ES:DI-1]).
		neg bx  ; BX := -orig_distance.
		dec bx  ; BX := -orig_distance - 1.
@@copy_match_next:
		mov al, [es:bx+di]  ; [es:..] prefix is not needed.
		stosb
		loop @@copy_match_next
decompress@@start:
@@next_token:
		call decompress@@get_bit
		jc short @@match_1
@@literal_0:  ; Indicated by CF==0.
		movsb  ; Copy literal byte from byte stream.
		jmp short @@next_token
@@match_1:  ; Indicated by CF==1.
		dw _xor_bx_bx
		call decompress@@get_bit
		lodsb  ; Get distance byte. Keeps CF intact.
		dw _mov_bl_al  ; BX (distance) := AL.  Keeps CF intact.
		jc short decompress@@match_1_1
@@match_1_0:
		call decompress@@get_bit
		jc short @@match_1_0_1
@@match_1_0_0:
		sub bl, 1
		jc short @@after_decompress
		jmp short decompress@@copy_match_2_bytes
@@match_1_0_1:
		mov cl, 3
@@match_1_0_1_next:
		call decompress@@get_bit
		rcl bh, 1
		loop @@match_1_0_1_next
		jmp short decompress@@copy_match_2_bytes
@@after_decompress:  ; Falls through to apply_relocs.

apply_relocs:
		pop dx  ; Restore DX := orig_CS, pushed by `push cs' in setup_code.
		add [uncompressed_start_far_ptr-exe_image+100h+2], dx  ; Relocate segment in uncompressed_start_far_ptr.
		mov cl, 0  ; CX := U_NRELOC == (relocation_locations.end-relocation_locations)>>1 == number of relocations. Calculated.  ; CH is already 0. build_preparator_buf will populate it.
apply_relocs@@u_nreloc = $-1
@@next:		lodsw  ; Load next offset from relocation table. Format: an array of offsets usign segment orig_CS-0x10 == PSP_segment.
		dw _mov_bx_ax  ; `xchg bx, ax' would have been shorter.
		add [es:bx], dx  ; Apply single relocation.
		loop @@next

jump_to_program:
		pop ds  ; Restore DS := PSP_segment. ES is already PSP_segment.
		cli
		dw _add_dx_strict_word, 0 ; U_SS. build_preparator_buf will populate it.
jump_to_program@@u_ss = $-2
		mov ss, dx  ; SS := orig_CS+U_SS.
		mov sp, 0  ; U_SP. build_preparator_buf will populate it.
jump_to_program@@u_sp = $-2
		sti
		jmp [dword cs:uncompressed_start_far_ptr-exe_image+100h]  ; Jump to uncompressed_start_far_ptr.

preparator_buf@@end:

MAX_USIZE = 7000h  ; Large enough to fit the uncompressd pmodewu.exe (without its .exe header). Small enough to prevent overflow in ERROR_DOS_COM_MEMORY_IMAGE_TOO_LARGE.
MAX_CSIZE = MAX_USIZE+((MAX_USIZE+7) shr 3)  ; Worst case compressed data size: all tokens are literals. Matches are never longer than their corresponding literals.
MAX_CRELSIZE = EXEHDRSIZE shr 2  ; Absolue maximum which fits to EXEHDRSIZE bytes of DOS .exe header created by TLINK.
;absolute $  ; Don't emit bytes anymore, just reserve. No need to indicate this in NASM.
cdata:		db MAX_CSIZE+MAX_CRELSIZE dup (?)  ; Must come directly after preparator_buf@@end, without alignment.

udata:		db MAX_USIZE dup (?)
udata@@bufend:

if ($$-$) and 1  ; Align to word boundary.
		db ?
endif
uexehdr:	db EXEHDRSIZE dup (?)  ; Uncompressed DOS .exe header.
creloc = uexehdr+1ch  ; Temporary buffer for compressed relocations.

; By TASM <=2.51: **Error** pmwca.ASM(1117) User generated error
; By TASM >=3.0 : **Error** pmwca.ASM(1115) User error: 'bad'
; No way to display any subsituted values.
; To make TASM >=3.0 display the error message, it must be put to quotes.
; Any extra tokens after the quoted string will be ignored.
if ($-$$) gt 0ff00h
  err 'ERROR_DOS_COM_MEMORY_IMAGE_TOO_LARGE'
endif

ends CODE
end start
