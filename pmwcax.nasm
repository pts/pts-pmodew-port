;
; pmwcax.nasm: PMODE/W stub compressor, 386 assembly implementation for NASM 0.98.39--, as a combined Linux i386 and FreeBSD i386 program
; by pts@fazekas.hu at Sat Jun 21 12:29:43 CEST 2025
;
; Compile with: nasm -O0 -w+orphan-labels -o pmwca pmwcax.nasm && chmod +x pmwca
; Minimum NASM version needed: 0.98.39
;
; End-to-end check: tools/nasm-0.98.39.upx -O0 -w+orphan-labels -f bin -o pmwca pmwcax.nasm && chmod +x pmwca && ./pmwca pmodewu.exe pmodew.exe && cmp pmodew133.exe pmodew.exe && echo OK
; End-to-end check: tools/nasm-0.98.39.upx -O0 -w+orphan-labels -f bin -DDEBUG -o pmwca pmwcax.nasm && chmod +x pmwca && ./pmwca pmodewu.exe pmodew.exe >pmwca.log && <pmodewc.log grep '^[BLDEXY]' >pmodewc.bldexy.log && diff pmodewc.bldexy.log pmwca.log && cmp pmodew133.exe pmodew.exe && echo OK
;
; There is an eqivalent NASM 0.98.39-- source of this program in pwmca.nasm.
;
; This compressor is quite slow because scans the same data may times
; looking for longer and longer repetition. On a real 386 CPU from 1985) it
; may take several minutes. (How long would it take on an 586 CPU in 1997?)
; Adding a hashtable or lookup table would make it significantly faster.
;
; !! Check diff with `nasm -O999999999'. It seems to be OK now.
; !! speed optimization: For compress, add a lookup table which finds the previous occurrence of a word (2 bytes) in O(1) time.
;
; The __watcall calling convention passes the first 3 function arguments in
; EAX, EDX, EBX respectively, returns the result in EAX, and the callee has
; to preserve ECX, ESI, EDI and EBP, and also EDX if not used as an
; argument, and also EBX if not used as an argument.
;
; The __cdecl calling convention passes all function arguments in [esp+1*4],
; [esp+2*4], [esp+3*4] etc. respectively, returns the result in EAX, and the
; callee has to preserve EBX, ESI, EDI and EBP. The caller cleans up the
; arguments from the stack.
;
; The __stdcall calling convention passes the all function arguments in
; [esp+1*4], [esp+2*4], [esp+3*4] etc. respectively, returns the result in
; EAX, and the callee has to preserve EBX, ESI, EDI and EBP. Unlike in
; __cdecl, the callee cleans up the arguments from the stack.
;

; --- Connfiguration.

%ifdef OS_WIN32  ; Can be specified on the command line. !! Implement it.
  %error ERROR_OS_WIN32_UNIMPLEMENTED
  db 1/0
%endif

%ifndef PMWV  ; Can be specified on the command line.
  %define PMWV 33
%else
  %assign PMWV PMWV  ; Make sure it's an integer (expression), convert it to integer constant.
%endif

; ---

bits 32
cpu 386

BASE equ 0x600000  ; Must be divisible by 0x10000 == 64 KiB for 16-bit offset access. The standard value is 0x8048000.
org BASE

OSABI:
.SYSV: equ 0
.Linux: equ 3
.FreeBSD: equ 9

Ehdr_OSABI equ OSABI.FreeBSD  ; The program works natively on both Linux i386 and FreeBSD i386.
;Ehdr_OSABI equ OSABI.Linux  ; The program works natively on Linux i386, but not FreeBSD i386.

Elf32_Ehdr:  ; ELF-32 i386 header.
		db 0x7f, 'ELF', 1, 1, 1, Ehdr_OSABI, 0, 0, 0, 0, 0, 0, 0, 0, 2, 0, 3, 0
		dd 1, _start, Elf32_Phdr-$$, 0, 0
		dw Elf32_Phdr-$$, 0x20, 1, 0x28, 0, 0
Elf32_Phdr:	dd 1, 0, $$, 0, file_end-$$, mem_end-$$, 7, 0x1000

_start:
%if 1
  %ifndef OS_WIN32
		; Entry point (_start) of the Linux i386 executable. Same for SVR3 i386, SVR4 i386, FreeBSD i386 and macOS i386 up to the end of envp.
		; Now the stack looks like (from top to bottom):
		;   dword [esp]: argc
		;   dword [esp+4]: argv[0] pointer
		;   esp+8...: argv[1..] pointers
		;   NULL that ends argv[]
		;   environment pointers
		;   NULL that ends envp[]
		;   ELF Auxiliary Table
		;   argv strings
		;   environment strings
		;   program name
		;   NULL
		push byte 4  ; SYS_write for both Linux i386 and FreeBSD.
		pop eax
		xor edx, edx  ; Argument count of Linux i386 SYS_write.
		push edx  ; Argument count of FreeBSD SYS_write.
		xor ecx, ecx  ; Argument buf of Linux i386 SYS_write.
		push ecx  ; Argument buf of FreeBSD SYS_write.
		or ebx, byte -1  ; Argument fd of Linux i386 SYS_write.
		push ebx  ; Argument fd of FreeBSD SYS_write.
		push eax  ; Fake return address for FreeBSD syscall.
		int 0x80  ; Linux i386 and FreeBSD i386 syscall. It fails because of the negative fd.
		add esp, byte 4*4  ; Clean up syscall arguments above.
		not eax
		shr eax, 31  ; EAX := sign(EAX). Linux becomes 0 (because SYS_write has returned a negative errno value: -EBADF), FreeBSD becomes 1.
		mov [___M_is_freebsd], al
		; The previous detection used SYS_getpid and checked CF
		; after `int 0x80'. This worked on modern Linux kernels (who
		; don't change CF, but FreeBSD i386 sets CF=0 upon success),
		; but `int 0x80' Linux 1.0.4 sets CF=0, so it didn't work.
		; Checking the sign of the errno return value is more
		; robust.
		;call __M_start_isatty_stdin
		;call __M_start_isatty_stdout
		pop eax  ; argc.
		mov edx, esp  ; argv.
  %else  ; %ifndef OS_WIN32
    ; !! Write it.
  %endif  ; %ifndef OS_WIN32
		call main_
		; Fall through to _exit.
%endif  ; %ifdef __NEED_start
%if 1
  global exit_
  exit_:  ; __attribute__((noreturn)) void __watcall exit(int status);
		; Fall through to __exit.
%endif  ; %ifdef __NEED_exit_
%if 1
  global _exit_
  _exit_:  ; __attribute__((noreturn)) void __watcall _exit(int exit_code);
		push eax  ; Argument exit_code.
  %ifdef OS_WIN32
		call _ExitProcess@4  ; Doesn't return.
  %else
		push eax  ; Fake return address for FreeBSD i386 syscall.
		xchg ebx, eax  ; EBX := EAX (exit_code); EAX := junk. Linux i386 syscall needs the 1st argument in EBX. FreeBSD i386 needs it in [esp+4].
		xor eax, eax
		inc eax  ; EAX := FreeBSD i386 and Linux i386 SYS_exit (1).
		int 0x80  ; FreeBSD i386 and Linux i386 syscall. Doesn't return.
  %endif
		; Not reached.
%endif  ; %ifdef __NEED__exit_

; Exits the process with a fatal error (2 bytes of error message in BP).
fatal:		mov [fatal_msg.code], bp
		xor eax, eax
		mov al, 2  ; EAX := STDERR_FILENO.
		mov edx, fatal_msg  ; DS:EDX := pointer to start of buffer to be written.
		xor ebx, ebx
		mov bl, fatal_msg.end-fatal_msg  ; EBX := number of bytes to write.
		call write_
		xor eax, eax
		inc eax  ; EAX := EXIT_FAILURE == 1.
		jmp short exit_  ; Doesn't return.

; If EAX < 0, exits the process with a fatal error (2 bytes of error message
; in BP), otherwise returns. Keeps all registers except for EFLAGS intact.
fatal_if_eax_lt_0:
		test eax, eax
		js short fatal
		ret

; argc is in EAX, argv is in EDX. Returns exit code in EAX.
main_:  ; int __watcall main(int argc, char **argv);
		; Falls through.

parse_command_line:  ; Usage: ./pmwca <uncompressed-input.exe> [<compressed-output.exe>]
		mov esi, edx  ; ESI := EDX (argv).
		lodsd  ; EAX := argv[0]. Program name.
		mov bp, 'MI'  ; Missing input filename.
		test eax, eax
		jz short fatal
		lodsd  ; EAX := argv[1]. Input filename <uncompressed-input.exe>.
		test eax, eax
		jz short fatal
		push eax  ; Save offset of input filename. `pop eax' in make_exe_headers_consistent and write_cdata will pop it.
		xchg edx, eax  ; EDX: Save offset of input filename. Will be used in read_udata.
		lodsd  ; EAX := argv[2]. Output filename <compressed-output.exe>.
		push eax  ; Save offset of output filename. Can be NULL. Will be popped by `pop eax' in sort_relocs and write_cdata.
		test eax, eax
		jz short .done
		lodsd  ; EAX := argv[3]. NULL.
		mov bp, 'TA'  ; Too many command-line arguments.
		test eax, eax
		jnz short fatal
.done:		; Falls through.

EXEHDRSIZE equ 0x200  ; Size of DOS .exe header created by TLINK.

read_udata:
		xchg eax, edx  ; EAX := input filename; EDX := junk.
		xor edx, edx  ; EDX := O_RDONLY == 0.
		;xor ebx, ebx  ; No need to set mode if not creating the file (with O_CREAT).
		call simple_open_
		mov bp, 'OI'  ; Error opening input file.
		call fatal_if_eax_lt_0
		mov ecx, eax  ; ECX := filehandle of input file.
		;mov eax, ...  ; EAX == filehandle of input file.
		mov edx, uexehdr  ; DS:EDX == pointer to start of buffer to read uexehdr to.
		mov esi, edx  ; DS:ESI := DS:EDX == pointer to start of uexehdr. Will be used after the reading.
		mov ebx, EXEHDRSIZE  ; Maximum number of bytes to read.
		call read_
		mov bp, 'RH'  ; File read error reading the uncompressed DOS .exe header.
		call fatal_if_eax_lt_0
		mov bp, 'HT'  ; DOS .exe header too short.
		cmp ax, strict word EXEHDRSIZE
		jne short .j_fatal
		mov bp, 'MZ'
		cmp [esi+0*2], bp  ; signature.
		jne short .j_fatal  ; Bad DOS .exe signature.
		cmp word [esi+4*2], byte EXEHDRSIZE>>4  ; hdrsize.
		mov bp, 'HS'  ; Unsupported DOS .exe header size (hdrsize).
		jne short .j_fatal
		mov eax, ecx  ; EAX := filehandle of input file.
		mov edx, udata  ; DS:EDX == pointer to start of buffer to read to.
		mov ebx, udata.bufend-udata  ; Maximum number of bytes to read.
		call read_
		mov bp, 'RD'  ; File read error reading the uncompressed DOS .exe image.
		call fatal_if_eax_lt_0
		add eax, strict dword udata
		cmp ax, strict word udata.bufend  ; This assumes to opposites of ERROR_BASE_NOT_64KIB_ALIGNED and ERROR_UDATA_MEMORY_IMAGE_TOO_LARGE.
		jb short .usize_ok
		mov bp, 'TL'  ; Input file too long.
.j_fatal:	jmp near fatal
.usize_ok:	push eax  ; Save offset of end of udata. Will be popped by `pop edx' in sort_relocs.
		mov eax, ecx  ; EAX := filehandle of input file.
		call close_
		; Now: DS:ESI == pointer to start of uexehdr.
		; Falls through.

sort_relocs:
		movzx ecx, word [esi+3*2]  ; nreloc.
		test ecx, ecx
		mov bp, 'NR'  ; No relocations. (apply_relocs) depends on a nonzero nreloc value.
		jz short read_udata.j_fatal
		cmp ecx, byte (EXEHDRSIZE-0x1c)>>2
.fatal_tr:	mov bp, 'TR'  ; Too many relocations.
		ja short read_udata.j_fatal
		movzx edi, word [esi+12*2]  ; relocpos.
		cmp di, strict word EXEHDRSIZE
		mov bp, 'RP'  ; Relocations start too late.
		jnb short read_udata.j_fatal
		lea eax, [ecx*4+edi] ; EAX := (nreloc<<2)+relocpos.
		cmp ax, strict word EXEHDRSIZE
		ja short .fatal_tr
		lea eax, [edi+uexehdr]  ; EAX := uexehdr+relocpos.
		mov edx, ecx  ; nreloc.
%if 0  ; Test sort4.
		mov eax, cdata
		mov dword [eax], 69
		mov dword [eax+4], 68
		mov dword [eax+8], 67
		mov dword [eax+12], 66
		mov dword [eax+16], 65
		mov edx, 5
		call sort4
		mov eax, 1  ; STDOUT_FILENO
		mov edx, cdata
		mov ebx, 5*4
		call write_
%endif
		call sort4  ; Sorts relocations by (segment descending, then offset ascending). Ruins EAX, EBX, EDX, ESI, EBP and EFLAGS. Keeps ECX and EDI.
		pop edx  ; Restore EDX := offset of end of udata.
		pop eax  ; Restore EAX := offset of output filename.
		test eax, eax
		jnz strict near squeeze_relocs  ; Jump if output filename has been specified.
		; Falls through.

make_exe_headers_consistent:
		mov ebx, uexehdr
		movzx esi, word [ebx+12*2]  ; relocpos.
		;movzx ecx, word [ebx+3*2]  ; ECX still contains nreloc.
		lea edi, [ebx+ecx*4+0x3e-4]
		push edi  ; Save uexehdr+0x3e+(nreloc<<2)-4.
		cmp esi, byte 0x3e
		je short .relocpos_ok  ; TLINK 3.0-- generates relocpos == 0x3e, so it jumps. It doesn't jump for TLINK 2.0.
		mov bp, 'ER'  ; Unexpected large relocpos in DOS .exe. TLINK doesn't generate relocpos > 0x3e.
		ja short read_udata.j_fatal
		add esi, ebx  ; ESI := uexehdr+relocpos.
		lea esi, [esi+ecx*4-4]
		std
		rep movsd  ; memmove(uexehdr + 0x3e, uexehdr + relocpos, nreloc << 2);
		cld
		mov word [ebx+12*2], 0x3e  ; Set relocpos in uexehdr.
.relocpos_ok:	lea edi, [ebx+0x1a]  ; EDI := uexehdr+0x1a.
		mov eax, 1<<16
		stosd  ; Set noverlay in uexehdr to 0; set word [uexehdr+0x1c] to 1, imitating TLINK.
		; Thie word [uexehdr+0x1e] value seems to depend on the TLINK version number.
		;
		; * TLINK 2.0: dw 0x20fb, 0x6a72
		; * TLINK 3.0--4.01 (last tlink.exe running on a 8086, we imitate this): dw 0x30fb, 0x726a
		; * TLINK 5.0--5.1--??: (used by pmw133src/PMODEW.EXE): dw 0x50fb, 0x726a
		; * TLINK 7.0: dw 0x61fb, 0x726a
		mov eax, 0x726a30fb  ; For word [uexehdr+020], we imitate TLINK 3.0--4.01--7.0. TLINK 2.0 generates 0x6a72 here.
		stosd  ; Set word [uexehdr+0x1e] to 0x30fb; set word [uexehdr+0x20] to 0x726a.
		mov cl, (0x3e-0x22)>>2  ; Sets the whole ECX, because higher bytes are already 0 because of the `rep' abvoe.
		xor eax, eax
		rep stosd  ; memset(uexehdr + 0x22, 0, 0x3e - 0x22);
		pop edi  ; Restore EDI := uexehdr+0x3e+(nreloc<<2)-4.
		scasd  ; EDI += 4. EDI := uexehdr+0x3e+(nreloc<<2).
		mov ecx, uexehdr+EXEHDRSIZE
		sub ecx, edi
		; For speed, we could have done `rep stosw' instead (but not `rep stosd', because it's not divisible by 4). Newer Intel CPUs do a fast `rep stosb' anyway.
		rep stosb  ; memset(uexehdr + 0x3e + (nreloc << 2), 0, EXEHDRSIZE - 0x3e - (nreloc << 2));
		pop eax  ; Restore EAX := offset of input filename.
		sub edx, udata
		push edx  ; Save number of DOS .exe image bytes to write.
		mov edx, O_WRONLY|O_CREAT|O_TRUNC  ; flags.
		mov ebx, 666o  ; mode.
		call simple_open_
		mov bp, 'OR'  ; Error opening input file for rewriting.
		call fatal_if_eax_lt_0
		;mov eax, ...  ; EAX == filehandle of output file.
		push eax  ; Filehandle of output file.
		mov edx, uexehdr  ; DS:EDX == pointer to start of buffer to be written.
		mov ebx, EXEHDRSIZE  ; Number of bytes to write.
		call write_
		mov bp, 'WR'  ; File write error.
		call fatal_if_eax_lt_0
		pop eax  ; Restore EAX := filehandle of output file.
		mov edx, udata  ; DS:EDX == pointer to start of buffer to be written.
		pop ebx  ; Number of DOS .exe image bytes to write.
		jmp strict near final_write

squeeze_relocs:  ; Converts each relocation from dword-sized (offset, segment) pair to word-sized offset+0x100.
		push eax  ; Again, save offset of output filename.
		lea esi, [edi+uexehdr]  ; ESI := uexehdr+relocpos.  Source of (offset, segment) pairs.
		mov edi, creloc  ; DS:EDI := pointer to the squeezed relocations.
		;mov cx, [si+3*2]  ; CX == nreloc. Nonzero.
		push ecx  ; Save nreloc.
		push edi  ; Save creloc.
.next:		lodsw
		xchg ebx, eax  ; BX := offset of the relocation; AX := junk.
		inc bh  ; BX += 0x100.
		lodsw
		shl eax, 4  ; AX <<= 4. Convert from real-mode segment value to byte offset.
		add eax, ebx
		stosw
		loop .next
		; Falls through.

build_preparator_buf:
		mov esi, udata
		mov edi, cdata
		;mov edx, ...  ; EDX is already correct: EDX := offset of end of udata.
		call compress  ; Append compressed data to DS:EDI == ES:EDI. Ruins EAX, EBX, ECX, EDX, ESI, EBP, EFLAGS. Sets EDS:EDI to pointer to end of cdata.
		pop esi  ; Restore ESI := creloc.
		pop ecx  ; Restore ECX := nreloc.
		lea ebx, [dword edi-(preparator_buf-$$+BASE)]  ; EBX := csize + (cdata - preparator_buf).
		times 2 add ebx, ecx  ; EBX := csize + (nreloc << 1) + (cdata - preparator_buf).
		mov [apply_relocs.u_nreloc], cl  ; It fits to 1 byte, we've checked it above at 'TR'.
		rep movsw  ; Append compressed relocationss to DS:EDI == ES:EDI.
		; Now: DS:EDI == pointer to the end of cdata.
		mov eax, ebx
		and ah, 1  ; AX &= 0x1ff.
		mov [cexehdr.lastsize], ax
		lea eax, [ebx+0x1ff]  ; Round up.
		shr eax, 1
		mov [cexehdr.nblocks], ah  ; Set low byte. The high byte will remain 0.
		sub ebx, byte 0x20  ; EBX := csize + (nreloc << 1) + (cdata - preparator_buf) - (chdrsize << 4).
		lea eax, [ebx+1]  ; Round up.
		shr eax, 1
		mov [copy_code.word_count], ax  ; Number of words to copy.
		mov esi, uexehdr+7*2  ; U_SS.
		lodsw  ; AX := U_SS; SI += 2 (to U_SP).
		mov [cexehdr.ss], ax
		mov [jump_to_program.u_ss], ax
		lea ebx, [ebx+0xf]  ; Round up.
		shr ebx, 4  ; EBX := (csize + (nreloc << 1) + (cdata - preparator_buf) - (chdrsize << 4) + 0xf) >> 4.
		add ax, strict word ((0x100+0xf)>>4)+1  ; Why the +1? Maybe it's related to the bug in the original PMODE/W compressor.
		add eax, ebx  ; AX := (U_SS + ((0x100 + 0xf) >> 4)) + ((csize + (nreloc << 1) + (cdata - preparator_buf) - (chdrsize << 4) + 0xf) >> 4) + 1.
		mov [cexehdr.minalloc], ax  ; The value computed above is larger than needed, so this is wasting memory at runtime. This is probably a bug in the original PMODE/W compressor.
		lodsw  ; AX := U_SP. SI += 2 (to U_CHECKSUM).
		mov [jump_to_program.u_sp], ax
		times 2 inc esi  ; Ignore U_CHECKSUM (will be ignored). SI += 2 (to U_IP).
		lodsd  ; EAX := U_IP|U_CS<<16. ESI += 4 (to U_RELOCPOS).
		mov [uncompressed_start_far_ptr.u_ip], eax  ; Set U_IP and U_CS.
		; Now: DS:DI == pointer to the end of cdata.
		; Falls through.

write_cdata:	pop eax  ; Restore EAX := offset of output filename.
		pop edx  ; Discard offset of input filename.
		mov edx, O_WRONLY|O_CREAT|O_TRUNC  ; flags.
		mov ebx, 666o  ; mode.
		call simple_open_
		mov bp, 'OO'  ; Error opening output file.
		call fatal_if_eax_lt_0
		;mov eax, ...  ; EAX == filehandle of output file.
		mov edx, preparator_buf  ; DS:EDX == pointer to start of buffer to be written.
		mov ebx, edi  ; Pointer to the end of cdata.
		sub ebx, edx  ; EBX := EDI - preparator_buf. EBX == number of bytes to write.
		; Fall through.

final_write:	call write_
		mov bp, 'WR'  ; File write error.
		call fatal_if_eax_lt_0
%if 0  ; No need to close the output file, DOS will close it right below, when to process exits.
		mov eax, ...  ; Close file using handle.
		call close_
%endif
		xor eax, eax  ; EXIT_SUCCESS == 0.
		ret  ; Return from main(...), exit from the program.

%if 1
  %ifndef OS_WIN32
    ; Input: syscall number in dword [ESP], return address in dword [ESP+4], arg1 in EAX, arg2 in EDX, arg3 in EDX.
    ; It assumes same syscall number and behavior for FreeBSD i386 and Linux i386.
    simple_syscall3_WAT:
		xchg ecx, [esp]  ; ECX := syscall number; save ECX.
		push ebx  ; Save.
		push edx  ; Save.
		push ebx  ; arg3 for FreeBSD i386.
		push edx  ; arg2 for FreeBSD i386.
		push eax  ; arg1 for FreeBSD i386.
		xchg eax, ecx  ; EAX := syscall number; ECX := junk (arg1).
		cmp byte [___M_is_freebsd], 0
		jne short .freebsd
		pop ebx  ; arg1 for Linux i386.
		pop ecx  ; arg2 for Linux i386.
		pop edx  ; arg3 for Linux i386.
		int 0x80  ; Linux i386 syscall.
		test eax, eax
		; Sign check is good for most syscalls, but not time(2) or mmap2(2).
		; For mmap2(2), do: cmp eax, -0x100 ++ jna .final_result
		jns short .done
		or eax, byte -1  ; EAX := -1.
		jmp short .done
      .freebsd:
		push eax  ; Fake return address for FreeBSD i386 syscall.
		int 0x80  ; FreeBSD i386 syscall.
		jnc short .ok
		sbb eax, eax  ; EAX := -1, indicating error.
    .ok:	add esp, byte 4*4  ; Discard fake return address, arg1, arg2, arg3.
    .done:	pop edx  ; Restore.
		pop ebx  ; Restore.
		pop ecx  ; Restore.
		ret
  %endif
%endif

%if 1
  global read_
  read_:  ; ssize_t __watcall read(int fd, void *buf, size_t count);
  %ifdef OS_WIN32
		push dword _ReadFile@20
		jmp short read_write_helper
  %else
		push byte 3  ; FreeBSD i386 and Linux i386 SYS_read.
		jmp short simple_syscall3_WAT
  %endif
%endif

%if 1
  global write_
  write_:  ; ssize_t __watcall write(int fd, const void *buf, size_t count);
  %ifdef OS_WIN32
		push dword _WriteFile@20
		jmp short read_write_helper
		; Fall through to __M_write_growany_.
  %else
		push byte 4  ; FreeBSD i386 and Linux i386 SYS_write.
		jmp short simple_syscall3_WAT
  %endif
%endif

O_RDONLY equ 0
O_WRONLY equ 1
O_CREAT equ 100o  ; Linux.
O_TRUNC equ 1000o  ; Linux.

%if 1
  %ifndef OS_WIN32
    __M_raw_open_:  ; int __watcall __M_fopen_open(const char *pathname, int flags, mode_t mode);
		push byte 5  ; FreeBSD i386 and Linux i386 SYS_open.
		jmp short simple_syscall3_WAT
  %endif
%endif

%if 1
  %if 1
    global simple_open_
    simple_open_:  ; int __watcall simple_open_(const char *pathname, int flags, ... mode_t mode);
    ; This function only works with flags==O_RDONLY or flags==(O_WRONLY|O_CREAT|O_TRUNC).
    %ifdef OS_WIN32  ; !! Write it (__M_fopen_open_), take care of __watcall.
    %else  ;  %ifdef OS_WIN32
		push ebx  ; Save for __watcall.
		push edx  ; Save for __watcall.
		cmp byte [___M_is_freebsd], 0
		je short .flags_done
		; This only fixes the flags with which _fopen(...) calls open(...). The other flags value is O_RDONLY, which doesn't have to be changed.
		cmp dx, 1101o  ; flags: Linux   (O_WRONLY | O_CREAT | O_TRUNC) == (1 | 100o | 1000o).
		jne short .flags_done
		mov dx, 0x601  ; flags: FreeBSD (O_WRONLY | O_CREAT | O_TRUNC) == (1 | 0x200 | 0x400) == 0x601. In the SYSV i386 calling convention, it's OK to modify an argument on the stack.
        .flags_done:
		call __M_raw_open_  ; For proper stack usage (with `push' above and `pop's below).
		pop edx  ; Restore for __watcall.
		pop ebx  ; Restore for __watcall.
		ret
    %endif
  %endif
%endif

%if 1
  global close_
  close_:  ; int __watcall close(int fd);;
  %ifdef OS_WIN32  ; !! Write it.
  %else
		push byte 6  ; FreeBSD i386 and Linux i386 SYS_close.
		jmp short simple_syscall3_WAT
  %endif
%endif

; Compares relocation dword [ds:esi] to dword [ds:edi]. It compares by
; (segment descending, then offset ascending). Thus first it compares the
; segment values (reversed), and if they are equal, it compares the offset
; values. Returns CF indicating that the first is smaller than the second.
;
; Ruins: AX and EFLAGS.
is_reloc_less:
		mov ax, [esi+2]  ; First segment.
		cmp [edi+2], ax  ; Compare to second segment, in reverse (descending) order.
		jne short .done  ; CF is already correct: CF == 1 if second is less, CF == 0 otherwise.
		mov ax, [esi]  ; First offset.
		cmp ax, [edi]  ; Compare to second offset.
		; CF is already correct: CF == 1 if first is less, CF == 0 otherwise.
.done:		ret

; Sorts an array of 4 bytes each using the comparison function is_reloc_less.
; May or may not be stable.
;
; Uses a constant amount of memory in addition to the input/output array.
;
; Inputs: DS:AX: pointer to the start of the array; DX: number of array elements.
; Ruins: AX, DX, EFLAGS.
;
; typedef unsigned size_t;
; #define SIZE 4
; extern char is_reloc_less(const void *a, const void *b);
; #pragma aux is_reloc_less __parm [__esi] [__edi] __modify [__ax] __value [__cf]  /* OpenWatcom C compiler doesn't actually support __value [__cf]. */
; extern void memswap4(void *a, void *b);
; #pragma aux memswap4 __parm [__esi] [__edi] __modify [__eax]
; void sort4(void *base, size_t n);
; #pragma aux heapsort4 __parm [__eax] [__edx] __modify [__eax __ebx __edx __esi __ebp]
sort4:
%ifdef FASTSORT
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
  .var_lp equ -1*4
  .var_tp equ -2*4
  .var_jp4 equ -3*4
  .var_ijp equ -4*4
		push ecx  ; Save.
		push edi  ; Save.
		mov ebp, esp
		sub esp, byte 4*4
		xchg ecx, eax  ; ECX (ap) := base; EAX := junk.
		mov ebx, edx
		shr ebx, 1
		shl ebx, 2
		mov esi, ecx
		add esi, ebx
		mov [ebp+.var_lp], esi
		mov ebx, edx
		shl ebx, 2
		sub ebx, byte 4  ; EBX (rp) := ap + SIZE * (n - 1).
		add ebx, ecx
		cmp edx, byte 2  ; n < 2.
		jb short .done  ; if (n < 2) return;
  .1:		mov eax, [ebp+.var_lp]
		cmp ecx, eax
		je short .2  ; Jump if this is false: if (lp != ap)
		sub dword [ebp+.var_lp], byte 4  ; lp -= SIZE.
		mov eax, [ebp+.var_lp]
		mov [ebp+.var_tp], eax
		jmp short .3
  .2:		mov edi, ebx
		mov esi, eax
		;call memswap4  ; memswap4(ap, rp);  ; Swaps dword [ds:esi] with dword [ds:edi]. Ruins: EAX and EFLAGS.
		mov eax, [esi]
		xchg eax, [edi]
		mov [esi], eax
		sub ebx, byte 4
		cmp ebx, ecx
		je short .done  ; if ((rp -= SIZE) == ap) break;
		mov [ebp+.var_tp], ecx
  .3:		mov edx, [ebp+.var_lp]
  .4:		mov [ebp+.var_ijp], edx
		mov eax, edx
		sub eax, ecx
		add eax, byte 4
		add edx, eax
		cmp edx, ebx
		ja short .7
		jae short .5
		mov eax, edx
		add eax, byte 4
		mov [ebp+.var_jp4], eax
		mov edi, eax
		mov esi, edx
		call is_reloc_less  ; is_reloc_less(jp, jp + SIZE).
		;test al, al
		;je short .5  ; Jump if not less.
		jnc short .5  ; if (!is_reloc_less(tp, jp)) break;  ; Jump if not less.
		mov edx, [ebp+.var_jp4]
  .5:		mov edi, edx  ; jp += SIZE.
		mov esi, [ebp+.var_tp]
		call is_reloc_less
		;test al, al
		;je short .7  ; Jump if not less.
		jnc short .7  ; Jump if not less.
		mov edi, edx
		mov esi, [ebp+.var_ijp]
		;call memswap4  ; Swaps dword [ds:esi] with dword [ds:edi]. Ruins: EAX and EFLAGS.
		mov eax, [esi]
		xchg eax, [edi]
		mov [esi], eax
		mov [ebp+.var_tp], edx
		jmp short .4
  .7:		mov edi, [ebp+.var_tp]
		mov esi, [ebp+.var_ijp]
		;call memswap4  ; memswap4(ip, jp);  Swaps dword [ds:esi] with dword [ds:edi]. Ruins: EAX and EFLAGS.
		mov eax, [esi]
		xchg eax, [edi]
		mov [esi], eax
		jmp short .1
  .done:	mov esp, ebp
		pop edi  ; Restore.
		pop ecx  ; Restore.
		ret
%else
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
  ;       if (is_reloc_less(cur, cur - SIZE)) {
  ;         oldcur = cur;
  ;         do {
  ;           cur -= SIZE;
  ;         } while (cur != (char*)base && is_reloc_less(oldcur, cur - SIZE));
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
		push ecx  ; Save.
		push edi  ; Save.
		cmp edx, byte 1  ; Argument n.
		jbe short .done
		xchg eax, edx  ; EAX := EDX (argument n); EDX := old_EAX (argument base).
		mov ebp, edx  ; EBP will keep holding argument base throughout the rest of the function.
		lea ebx, [ebp+4]  ; EBX (cur) := base + SIZE.
		shl eax, 2  ; EAX *= 4.
		add edx, eax  ; EDX (var_end) := base + SIZE * n.
  .next:	lea edi, [ebx-4]
		mov esi, ebx  ; ESI := EBX *cur).
		call is_reloc_less  ; is_reloc_less(cur, cur - SIZE).
		jnc short .continue  ; Jump if not less.
		mov esi, ebx  ; ESI (oldcur) := EBX (cur).
  .scan_next:	mov ebx, edi  ; EBX (cur) -= SIZE.
		cmp ebx, ebp  ; while (cur != base ...)
		je short .rotate
		lea edi, [ebx-4]
		call is_reloc_less  ; is_reloc_less(oldcur, cur - SIZE).
		jc short .scan_next  ; Jump if less.
  .rotate:	; Now, until .continue, we will rotate the region EBX...(ESI+4) right (forward) by a dword (SIZE == 4).
		; That is, save `dword [esi]' to EAX, then copy from EBX...ESI to (EBX+4)..(ESI+4), then restore `dword [ebx]' from EAX.
		; We are allowed to ruin EAX, ECX, ESI, EDI and EFLAGS until .continue.
		mov ecx, esi
		sub ecx, ebx
		shr ecx, 2  ; Convert byte count to dword count.
		mov edi, esi
		lodsd  ; Save highest dword to EAX.
		lea esi, [esi-2*4]
		std
		rep movsd
		cld  ; Restore DF := 0, we are not allowed to ruin that flag.
		stosd  ; Restore highest dword to the lowest position.
		; Rotation done. Now AX, CX (== 0), SI, DI and EFLAGS are ruined.
  .continue:	lea ebx, [ebx+4]  ; EBX (cur) := EBX + 4 (newcur).
		cmp ebx, edx  ; cur != end.
		jne short .next
  .done:	pop edi  ; Restore.
		pop ecx  ; Restore.
		ret
%endif

CR equ 13
LF equ 10

%ifdef DEBUG
  ; Writes the byte in AL to stdout and flushed stdout.
  putcharf:  ; TODO(pts): Add line buffering for faster operation.
		push ebx  ; Save.
		push edx  ; Save.
		push eax  ; Save and also use it as a buffer (buf) for write_.
		xor eax, eax
		inc eax  ; EAX := STDOUT_FILENO == 1.
		mov edx, esp  ; Offset of the pushed AL byte value.
		mov ebx, eax  ; EBX := 1. Number of bytes to write.
		call write_
		pop eax  ; Restore and clean up.
		pop edx  ; Restore.
		pop ebx  ; Restore.
		ret

  print_nibble:	push ax
		add al, '0'
		cmp al, '9'
		jna short .ok
		add al, 'a'-'0'-10
  .ok:		call putcharf
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
		call putcharf
		mov al, [esi]
		call print_al
		mov al, LF
		call putcharf
		pop ax
		ret

  print_distance:
		push ax
		mov al, 'D'
		call putcharf
  .ax:		pop ax
		push ax
		call print_ax
  .lf:		mov al, LF
		call putcharf
		pop ax
		ret

  print_length:	push ax
		mov al, 'E'
		call putcharf
		jmp short print_distance.ax

  ; Prints the bit in CF. Also ruins CF.
  print_bit:	push ax
		pushf
		mov al, 'B'
		call putcharf
		mov al, '0'
		popf
		adc al, 0
		call putcharf
		jmp short print_distance.lf

  print_m1:	push ax
		mov al, 'X'
		call putcharf
  .al:		pop ax
		push ax
		call print_al
		jmp short print_distance.lf

  print_m1101:	push ax
		mov al, 'Y'
		call putcharf
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
; Input: SS:EBP points to the local variables of the compress function.
; Input: DS:EDI == ES:EDI points to the end of the compressed output data (cdata_end == cdata_cur).
; Output: EDI incremented when a new 16-bit block (tag) word is emitted to DS:EDI == ES:EDI.
; Input and output: The offset of the current 16-bit block (tag) word value is in word [ebp+compress.var_block_ofs]. The segment is DS == ES. Will be modified.
; Input and output: The block (tag) next-write power-of-two bitmask is in word [ebp+compress.var_bitmask]. Will be modified.
; Ruins: FLAGS (incuding CF).
emit_bit:
.var_bitmask equ 4*4  ; Only 16 of the 32 bits are used. Same as compress.var_bitmask.
.var_block_ofs equ 2*4  ; Same as compress.var_block_ofs.
%ifdef DEBUG
		pushf
		call print_bit
		popf
%endif
		push eax  ; Save.
		push ebx  ; Save.
		mov ebx, [ebp+.var_block_ofs]
		mov ax, [ebp+.var_bitmask]
		jnc short .done_or  ; Uses the CF value at the beginning of emit_bit.
		or [ebx], ax
.done_or:	add ax, ax
		jnz short .done
		mov [ebp+.var_block_ofs], edi
		stosw  ; Append new 16-bit block (tag) word value, with initial value of 0. Uses ES:DI.
		inc eax  ; AX := 1.
.done:		mov [ebp+.var_bitmask], ax
		pop ebx  ; Restore.
		pop eax  ; Restore.
		ret

MAX_LENGTH equ 270
MAX_DISTANCE_FOR_LENGTH_2 equ 0x800-1
MAX_DISTANCE equ 0x1000-1

; Compresses bytes starting at DS:ESI == ES:ESI until DS:EDX == ES:EDX (EDX is
; not a byte count, but an offset!), writing the compressed stream to DS:EDI
; == ES:EDI, using a variant of LZSS. The input must not be empty.
;
; The input must be shorter than 64 KiB (unchecked), i.e. EDX-ESI <= 0xffff.
;
; Output: DS:EDI == ES:EDI: offset of the end of the compressed output data.
; Ruins: EAX, EBX, ECX, EDX, ESI, EBP, FLAGS.
compress:
.var_bitmask equ 4*4  ; Only 16 of the 32 bits are used. Same as emit_bit.var_bitmask.
.var_udata_end equ 3*4
.var_block_ofs equ 2*4  ; Same as emit_bit.var_block_ofs.
.var_cdata_cur equ 1*4
.var_udata_start equ 0*4
		xor eax, eax
		inc eax
		push eax  ; word [ebp+.var_bitmask]: Save initial block (tag) next-write power-of-two bitmask.
		push edx  ; word [ebp+.var_udata_end]: Save offset of the end of the uncompressed input data (udata_end). Sometimes EDI is used instead of this. Remains constant throughout the function.
%ifdef DEBUG
		mov ecx, edx
		sub ecx, esi
		jnc short .edx_esi_ok
		int3
.edx_esi_ok:
%endif
		movsb  ; Uses DS:ESI and ES:EDI. Copy literal byte to compressed output data.
		push edi  ; word [ebp+.var_block_ofs]: Save offset of the current 16-bit block (tag) word value. The segment is DS == ES.
		dec eax ; EAX := 0.
		stosw  ; Initial 16-bit block (tag) word value (0).
		push edi  ; word [ebp+.var_cdata_cur]: Save offset of the end of the compressed output data (cdata_end == cdata_cur). Will be incremented throughout the function.
		dec esi
		push esi  ; word [ebp+.var_udata_start]: Save offset of the start of the uncompressed input data (udata_start). Remains constant throughout the function.
%ifdef DEBUG
		call print_literal  ; Value: `byte [esi]'.
%endif
		inc esi  ; Skip over literal byte in the uncompressed input data.
		mov ebp, esp
		jmp strict near .next_byte
		; Registers through the .next_start loop below:
		; * EAX, EBX: scratch.
		; * ECX: maximum match length starting at DS:ESI. Remains until the next .next_byte (i.e. right after ESI is increased).
		; * EDX: best (longest) match length so far.
		; * DS:ESI == ES:ESI: points to the current byte of the udata to compress. Remains unchanged until .got_literal_or_match.
		; * DS:EDI == ES:EDI: points to the first byte of the next match candidate (EDI <= ESI).
		; * EBP: best distance corresponding to the length in the best match so far.
.next_start:	; Now: ECX <= 0xffff, thus ECX == CX. Now: EAX <= MAX_DISTANCE == 0xfff, thus EAX == AX. Now EAX == previous current distance.
		dec edi  ; Update match start.
		inc eax  ; Update current distance.
		cmp ax, strict word MAX_DISTANCE
		ja short .got_literal_or_match  ; If distance is too large, then ignore the match and all possible larger-distance matches.
		pop ebx  ; Restore EBX := udata_start.
		push ebx  ; Save udata_start.
		push ecx  ; Save.
		mov cx, MAX_DISTANCE
		sub ecx, eax
		sub ebx, edi
		neg ebx
		inc ebx  ; EBX := EDI-(udata_start-1).
		cmp ebx, ecx
		jae short .cx_ok2
		mov ecx, ebx  ; ECX := min(MAX_DISTANCE-EAX, EDI-(udata_start-1)).
.cx_ok2:	xchg ebx, eax  ; EBX := EAX; EAX := junk.
		add ebx, edi
		mov al, [esi]  ; First byte.
		std
		repne scasb  ; Uses ES:EDI. Try to find the first byte backward which matches the first byte (AL).
		cld
		pop ecx  ; Restore.
		jne short .got_literal_or_match
.found_first_byte:
		inc edi
		sub ebx, edi
		xchg eax, ebx  ; EAX := EBX (distance); EBX := junk.
.find_common_prefix_length:
		; Finds the (longest) common prefix length of the ECX bytes starting at DS:ESI and ES:EDI.
		; Input: DS:ESI points to byte string a, ES:EDI points to byte string b, ECX: number of bytes.
		; Output: EBX: longest common prefix length.
		; Ruins: FLAGS, ECX.
		push esi  ; Save.
		push edi  ; Save.
		mov ebx, ecx
		repe cmpsb  ; Uses DS:SI and ES:DI. Also reads and modifies SI, DI and CX.
		je short .after_inc
		inc ecx
.after_inc:	dw 0xd987  ; xchg ebx, ecx  ; ECX := maximum match length starting at DS:ESI. NASM 2.16.03 produces different output. We imitate NASM 0.98.39 for consistency.
		sub ebx, ecx
		neg ebx  ; EBX := longest common prefix length.
		pop edi  ; Restore.
		pop esi  ; Restore.
		cmp ebx, byte 2
		ja short .longer_than_2
		cmp ax, strict word MAX_DISTANCE_FOR_LENGTH_2
		ja short .keep_best  ; Ignore the match if distance is too large.
.longer_than_2:	cmp ebx, edx
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
		;   EBX == 2 ? (BP > 0xfe || AX <= 0xfe) : (BP > 0x3ff || AX <= (BP <= 0xff ? 0xff : 0x3ff)).
		cmp ebx, byte 2
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
		ja short .check_eq_length_3plus_large_distance
.check_eq_length_3plus_small_distance:
		cmp ax, 0xff
		jmp short .check_eq_cjmp
.check_eq_length_3plus_large_distance:
		cmp ax, 0x3ff
.check_eq_cjmp:
		ja short .keep_best
.new_best:	mov edx, ebx  ; Found longer length. Update best length.
		mov ebp, eax  ; Update distance corresponding to best length.
.keep_best:	pop ebx  ; Restore EBX := udata_start.
		push ebx  ; Save udata_start.
		cmp edi, ebx
		jne short .j_next_start
.got_literal_or_match:
		mov ebx, ebp  ; EBX := best distance.
		mov ebp, esp
		mov edi, [ebp+.var_cdata_cur]  ; cdata_end == cdata_cur.
		cmp edx, byte 2
		jae short .match
.literal:	clc
		call emit_bit
%ifdef DEBUG
		call print_literal
%endif
		movsb  ; Copies a literal byte from DS:SI to ES:DI. Also skips over literal byte in the uncompressed input data (SI += 1).
		jmp short .next_byte
.match:		add esi, edx  ; Skip over matched bytes in the uncompresed input data.
		call emit_match  ; Ruins EAX, EBX, ECX, EDX, EFLAGS. Modifies EDI. Keeps ESI and EBP intact.
		; Falls through to .next_byte.
.next_byte:	mov [ebp+.var_cdata_cur], edi  ; cdata_end == cdata_cur.
		mov ecx, [ebp+.var_udata_end]  ; udata_end.
		sub ecx, esi  ; High word of ECX becomes 0, because the input data is alsways shorter than 64 KiB. Thus CX == ECX.
		; Now ECX <= 0xffff (because of the opposite of ERROR_UDATA_MEMORY_IMAGE_TOO_LARGE), thus ECX == CX.
		jz short .done
%ifdef DEBUG
		jnc short .ecx_ok
		int3
.ecx_ok:
%endif
		cmp cx, MAX_LENGTH
		jb short .cx_ok
		mov cx, MAX_LENGTH
.cx_ok:		; ECX will keep holding the maximum match length starting at DS:ESI, until the next .next_byte (i.e. when ESI is increased).
		mov edi, esi
		xor edx, edx  ; Best length so far. No need to initialize BP (best distance) here.
		xor eax, eax
		dec eax  ; EAX := -1. Initial current distance. Will be incremented to 0 at the beginning of .next_start.
.j_next_start:	jmp strict near .next_start
.done:		stc
		call emit_bit  ; Emit end-of-stream (EOS) sequence.
		clc
		call emit_bit
		mov al, 0
		do_emit_m1  ; In AL.
		clc
		call emit_bit
		; Now: EDI == the correct, final value for cdata_end == cdata_cur.
		add esp, byte 5*4  ; Clean up local variables from the stack.
		ret

; Emits CL (1 <= CL <= 7) bits from AH, highest (of the CL) bits first. Assumes the high 3 bytes of ECX are 0.
; Ruins: CL (sets it to 0), AH, EFLAGS.
emit_bits:	ror ah, cl
.next:		rol ah, 1
		call emit_bit
		loop .next
		ret

; Emits an encoded match == (distance, length) == (EBX, EDX) pair. 0 <= EBX <= 0xfff; 2 <= EDX <= 270. If EDX == 2, then also EBX <= 0x7ff.
; Input: SS:EBP points to the local variables of the compress function.
; Input: DS:EDI == ES:EDI points to the end of the compressed output data (cdata_end == cdata_cur).
; Output: EDI incremented as emit_match and its subfunctions write compressed output bytes to DS:DI == ES:DI.
; Keeps ESI and EBP intact.
; Ruins: EAX, EBX, ECX, EDX, FLAGS.
emit_match:
		xor ecx, ecx  ; For emit_bits.
%ifdef DEBUG
		mov eax, ebx
%else
		xchg eax, ebx  ; EAX := distance; EBX := junk.
%endif
		stc
		call emit_bit
		cmp edx, byte 3  ; Also CF := (len == 2).
		cmc  ; CF := (len != 2).
		call emit_bit
		mov cl, 3
		cmp edx, byte 2
		jne short .dist_3plus
.dist_2:	cmp ax, strict word 0xff
		jae short .dist_2_big
.dist_2_small:	inc eax
		do_emit_m1  ; In AL.
		clc
		call emit_bit
		jmp short .after_bits
.dist_2_big:	do_emit_m1  ; In AL.
		stc
		call emit_bit
		;mov cl, 3  ; Not needed, set above.
		call emit_bits  ; Assumes CL == 3.
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
		;mov cl, 3  ; Not needed, set above.
		cmp ah, cl
		jna short .dist_bits  ; Jumps with CL == 3 and 0 <= AH <= 3. No need for `and ah, 3' here. Because of 0 <= AH <= 3, the next `print bit' of 3 bits will start with a 0 bit.
.dist_3plus_big:
		stc
		call emit_bit
		inc ecx  ; CL := 4.
.dist_bits:	call emit_bits
.len:
%ifdef DEBUG
		mov eax, edx
%else
		xchg eax, edx  ; EAX := length; EDX := junk.
%endif
		cmp eax, strict byte 7
		jae short .len_mid_or_big
.len_short:	xchg ecx, eax  ; ECX := length; AX := junk.
		times 2 dec ecx  ; ECX := length - 2. 0 <= ECX <= 268.
		mov ah, 1  ; Prints (1..3) 0 bits and a 1 bit.
		jmp short .len_bits
.len_mid_or_big:
		sub eax, strict byte 15
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
		xchg eax, edx  ; AX := DX (length); DX := junk.
		call print_length
		xchg eax, ebx  ; AX := BX (distance); BX := junk.
		call print_distance
		cmp eax, MAX_DISTANCE
		jna short .distance_ok
		int3
.distance_ok:
%endif
		ret

fatal_msg:	db 'pmwca: fatal: '
.code:		db '??'
%ifdef OS_WIN32
		db CR, LF
%else
		db LF
%endif
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
.noverlay:	dw 0       ; Overlay number. Unused.

padding:	dd 0       ; At file offset 0x1c. Unused.

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

%if PMWV==33
  copyright:	db 'PMODE/W v1.33 DOS extender - Copyright 1994-1997, Daredevil and Tran.'
%elif PMWV==34
  copyright:	db 'PMODE/W v1.34 DOS extender - Copyright 1994-2000, Daredevil and Tran.'
%else
  %error ERROR_UNSUPPORTED_PMWV PMWV
  db 1/0
%endif

uncompressed_start_far_ptr:
.u_ip: dw 0  ; build_preparator_buf will populate it.
.u_cs: dw 0  ; build_preparator_buf will populate it.

bits 16
cpu 8086

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
.get_bit:	shr bp, 1  ; CF := the first bit in a block to be used is its lowest bit.
		dec dl  ; Doesn't modify CF.
		jnz short .get_bit.ret
		lodsw
		dw _mov_bp_ax  ; `xchg bp, ax' would have been shorter here.
		mov dl, 0x10  ; Again, 0x10 == 16 are available in BP.
.get_bit.ret:	ret
.match_1_1:	call .get_bit
		jnc short .match_1_1_0
.match_1_1_1:	call .get_bit
		adc cl, 1
		shl cl, 1
.match_1_1_1.next:
		call .get_bit
		rcl bh, 1
		loop .match_1_1_1.next  ; Then falls through to .match_1_1_0.
.match_1_1_0:	mov dh, 2
		mov cl, 4
.match_1_1_0.next:
		inc dh
		call .get_bit
		jc short .copy_match_count_dh
		loop .match_1_1_0.next
		call .get_bit
		jnc short .match_1_1_0_0
.match_1_1_0_1:	lodsb
		dw _mov_cl_al
		add cx, byte 0xf
		jmp short .copy_match
.match_1_1_0_0:	dw _xor_dh_dh
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
.start:		call .get_bit
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
.after_decompress:  ; Falls through to apply_relocs.

apply_relocs:
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
file_end:
absolute $  ; Don't emit bytes anymore, just reserve.
cdata:		resb MAX_CSIZE+MAX_CRELSIZE  ; Must come directly after preparator_buf.end, without alignment.

udata:		resb MAX_USIZE
.bufend:
%if BASE&0xffff
  %error ERROR_BASE_NOT_64KIB_ALIGNED
  db 1/0
%endif
%if $-$$>0xffff
  %error ERROR_UDATA_MEMORY_IMAGE_TOO_LARGE
  db 1/0
%endif

		resb ($$-$)&3  ; Align to dword boundary.
uexehdr:	resb EXEHDRSIZE  ; Uncompressed DOS .exe header.
creloc: equ uexehdr+0x1c  ; Temporary buffer for compressed relocations.

___M_is_freebsd: resb 1  ; Are we actually running under FreeBSD (rathar than Linux)?
mem_end:
