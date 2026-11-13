;
; pmodew.nasm: PMODE/W stub, 386 assembly implementation for NASM 0.98.39--, as a DOS .exe program
; by pts@fazekas.hu at Wed Jun 18 12:29:59 CEST 2025
;
; Compile uncompressed, ready-to-use stub with: nasm-0.98.39 -O32700 -w+orphan-labels -DPMWV=33 -DUNC -o pmodewv.exe pmodew.nasm
; Compile compress-before-use stub with: nasm-0.98.39 -O32700 -w+orphan-labels -DPMWV=33 -o pmodewu.exe pmodew.nasm
; Minimum NASM version needed: 0.98.39
;
; The output of NASM for this file is bytewise identical to the output of
; TASM 2.0--5.3 + TLINK 3.0--4.1. Different versions of TLINK produce
; different but equivalent values within the first 0x200 bytes. After
; compressing pmodewu.exe (to pmodew.exe), the linker version doesn't make
; any difference.
;
; When dropping the requirement of bytewise identical output to TASM in the
; future, look at the comments with `Diff:' in them.
;
; --- # 7/27/2023 - PMODE/W is now released under the MIT License
;
; Copyright (c) 1994-2023 Charles Scheffold & Tomasz Pytel.
;
; Permission is hereby granted, free of charge, to any person obtaining a
; copy of this software and associated documentation files (the "Software"),
; to deal in the Software without restriction, including without limitation
; the rights to use, copy, modify, merge, publish, distribute, sublicense,
; and/or sell copies of the Software, and to permit persons to whom the
; Software is furnished to do so, subject to the following conditions:
;
; The above copyright notice and this permission notice shall be included in
; all copies or substantial portions of the Software.
;
; THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
; IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
; FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
; THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
; LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
; FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
; DEALINGS IN THE SOFTWARE.
;
; ---
;
; PMODE/W hooks the following int 21h calls (in AH): 09h 1ah 1bh 1ch 1fh 25h
; 2fh 32h 34h 35h 39h 3ah 3bh 3ch 3dh 3fh 40h 41h 43h 47h 48h 49h 4ah 4bh
; 4ch 4eh 4fh 51h 56h 5bh 62h 0ffh.
;
; PMODE/W supports the following int 31h (DPMI) calls (in AX, full list in
; int31functbl), which is a subset of DPMI 0.9:
;
; * 0000h Allocate LDT descriptors
; * 0001h Free LDT Descriptor
; * 0002h Segment to Descriptor
; * 0003h Get Next Selector Increment Value
; * 0006h Get Segment Base Address
; * 0007h Set Segment Base Address
; * 0008h Set Segment Limit
; * 0009h Set Descriptor Access Rights
; * 000ah Create Code Segment Alias Descriptor
; * 000bh Get Descriptor
; * 000ch Set Descriptor
; * 0100h Allocate DOS Memory Block
; * 0101h Free DOS Memory Block
; * 0102h Resize DOS Memory Block
; * 0200h Get Real Mode Interrupt Vector
; * 0201h Set Real Mode Interrupt Vector
; * 0202h (-DEXCEPTIONS=1) Get Processor Exception Handler Vector
; * 0203h (-DEXCEPTIONS=1) Set Processor Exception Handler Vector
; * 0204h Get Protected Mode Interrupt Vector
; * 0205h Set Protected Mode Interrupt Vector
; * 0300h Simulate Real Mode Interrupt
; * 0301h Call Real Mode Procedure With Far Return Frame
; * 0302h Call Real Mode Procedure With Iret Frame
; * 0303h Allocate Real Mode Call-Back Address
; * 0304h Free Real Mode Call-Back Address
; * 0305h Get State Save/Restore Addresses
; * 0306h Get Raw Mode Switch Addresses
; * 0400h (-DGETVERSION=1) Get Version
; * 0500h (-DFREEMEMINFO=1) Get Free Memory Information
; * 0501h Allocate Memory Block
; * 0502h Free Memory Block
; * 0503h Resize Memory Block
; * 05ffh (PMODE/W internal, do not call) Initialize Protected Mode System
; * 0600h (fake, always returns CF=0 success) Lock Linear Region
; * 0601h (fake, always returns CF=0 success) Unlock Linear Region
; * 0702h (fake, always returns CF=0 success) Mark Page as Demand Paging Candidate
; * 0703h (fake, always returns CF=0 success) Discard Page Contents
; * 0800h (-DINT3108FUNC=1) Physical Address Mapping
; * 0801h (-DINT3108FUNC=1, DPMI 1.0) Free Physical Address Mapping
; * 0900h Get and Disable Virtual Interrupt State
; * 0901h Get and Enable Virtual Interrupt State
; * 0902h Get Virtual Interrupt State
;
; DPMI 0.9 specification formatted as nice HTML: https://web.archive.org/web/20240915000218/https://www.phatcode.net/res/262/files/dpmi09.html
;
; ---
;
; Map of conventional memory (i.e. within the first 640 KiB) when PMODE/W is
; running, positions and sizes measured in paragraphs (0x10 == 16 bytes)
; from start of memory (linear address 0), in any mode:
;
; * 0: real-mode interrupt vector table (IVT) of 400h>>4 paragraphs.
; * 40h: BIOS and DOS data area of ~=200h>>4 paragraphs.
; * ~=60h: DOS data, DOS process code and data. It includes memory of command.com running PMODE/W.
; * ...
; * _pspseg-1: DOS MCB of the PSP.
; * _pspseg: First half of the PSP of the pmodew.exe DOS process.
; * _pspseg+8: Second half of the PSP. It contains the command-line string starting with the length byte.
; * _pspseg+10h: (pmodewk>>4)==PMODE_TEXT (PMODE kernel by Tran) segment code and data. This is where pmodew.exe is loaded from file offset .hdrsize>>4.
; * _pspseg+10h+~=21ch: (pmodewe>>4)==pmcode16 segment code and data (PMODE/W DOS extender stub code by Daredevil). Initially CS points to it, and IP == -pmodewe+_pm16start.
; * _pspseg+10h+~=3d7h: pmstack segment uninitialized data (stack space at startup) of STACK_SIZE>>4 == 40h paragraphs. Initially SS points to it, and SP == STACK_SIZE. !! Is it used after initialization? !! Isn't it too large?
;
; Then, in DPMI mode:
;
; * _membase after calling _pm_init == _pspseg+10h+~=3d7h+40h: DPMI DOS extender private data of SI paragraphs (as returned in SI by int 2fh, AX == 1687h call).
;
; Then, in VCPI mode:
;
; * aligment for VCPI pagetables == _membase after calling _pm_init == _pspseg+10h+~=3d7h+40h: 0..0ffh paragraphs.
; * pagetablesbase>>4: VCPI pagetable data of (min(PM_PAGETABLES,pagetables_needed_for_max_mem)<<8)+187h paragraphs.
;
; Then, in non-DPMI mode (i.e. VCPI, XMS or raw mode):

; * idtbase>>4: IDT data of 80h paragraphs.
; * rmstackbase: real-mode stacks of PM_RMSTACKLEN*PM_RMSTACKS paragraphs.
; * pmstackbase>>4 == rmstacktop: protected-mdoe stacks, PM_PMSTACKLEN*PM_PMSTACKS paragraphs.
; * callbackseg == pmstacktop>>4 == callbackbase>>4: callback data of ((PM_CALLBACKS+5)*25+0fh)>>4) paragraphs.
; * gdtseg == gdtbase>>4: GDT of ((PM_SELECTORS+15)*8+0fh)>>4 paragraphs.
;
; Then, in any mode:

; * _int21lowbufseg == _int21lowbufptr>>4: data transfer buffer for extended int 21h, Size is _int21lowbufsize>>4 == 100h paragraphs.
; * _int21lowdtaseg == dtabufptr<<4 == initial _int21dtaoff: int 21h DTA buffer. Size is DTABUFSIZE>>4 == 20h paragraphs. Also used for reading the first 200h bytes of the .exe, looking for headers. DOS needs only 100h bytes of DTA.
; * _membase before calling _loadexe: Some 32-bit .exe image data. Some of it may be loaded to extended memory (above 1 MiB).
; * final _membase: Right after all of the above. Unused memory follows.
; * ...
; * _memtop: End of DOS memory block. PMODE/W will return the conventional memory between the final _membase and _memtop to DOS before jumping to the 32-bit .exe entry point.
;
; So the total conventional memory usage, in paragraphs, is the sum of:
;
; * internal DOS memory structures: unknown
; * DOS MCB: 1
; * PSP: 10h
; * PMODE_TEXT segment: ~=21ch, depends on the compile-time configuration of PMODE/W.
; * pmcode16 segment: ~=3d7h, depends on the compile-time configuration of PMODE/W.
; * pmstack segment: 40h
; * DPMI DOS extender private data: unknown. Present only in DPMI mode.
; * alignment for VCPI pagetables: 0..0ffh. Only if VCPI mode.
; * VCPI pagetables: (min(PM_PAGETABLES,pagetables_needed_for_max_mem)<<8)+187h. Only if VCPI mode.
; * IDT: 80h. Present only in non-DPMI mode.
; * real-mode stacks: PM_RMSTACKLEN*PM_RMSTACKS. Present only in non-DPMI mode.
; * protected-mode stacks: PM_PMSTACKLEN*PM_PMSTACKS. Present only in non-DPMI mode.
; * callbacks: (((PM_CALLBACKS+5)*25+0fh)>>4). Present only in non-DPMI mode.
; * GDT: (((PM_SELECTORS+15)*8+0fh)>>4). Present only in non-DPMI mode.
; * data transfer buffer for extended int 21h: 100h
; * int 21h DTA buffer: 20h
; * parts of the 32-bit .exe image loaded to conventional memory: unknown
;
; So the maximum PMODE/W conventional memory overhead with the default
; load-time configuration settings (PM_PAGETABLES == 4 && PM_SELECTORS ==
; 100h && PM_RMSTACKLEN == 40h && PM_PMSTACKLEN == 80h && PM_RMSTACKS == 8
; && PM_PMSTACKS == 8 && PM_CALLBACKS == 20h) in non-DPMI mode is 1 + 10h +
; 21ch + 3d7h + 40h + 0ffh + (4<<8)+187h + 80h + 40h*8 + 80h*8 +
; (((20h+5)*25+0fh)>>4) + (((100h+15)*8+0fh)>>4) + 100h + 20h paragraphs ==
; 152ch paragraphs == 84.6875 KiB.
;
; ---
;
; TODO(pts): Add manual sizes to do -O0 instead of -O32700 (with both NASM 0.98.39 and newer).

; --- Compile-time configuration.
;
; See also load-time configuration later.

%ifdef SPE_EntryPoint  ; Compile-time configuration for the simple PE builder. The program may override each setting with a `%define'.
  %ifndef   UNC
    %define UNC 1
  %endif
  %ifndef   LOGO
    %define LOGO 0
  %endif
  %ifndef   SIZEOPT
    %define SIZEOPT 1
  %endif
  %ifndef   LOADSPE
    %define LOADSPE 3
  %endif
  %ifndef   LOADLE
    %define LOADLE 0
  %endif
  %ifndef   LOADPMW1
    %define LOADPMW1 0
  %endif
  %ifndef   INT3108FUNC
    %define INT3108FUNC 0
  %endif
  %ifndef   INT1B
    %define INT1B 2  ; exit(254) on Ctrl-<Break>.
  %endif
  %ifndef   INT31VENDOR
    %define INT31VENDOR 0
  %endif
  %ifndef   INT33
    %define INT33 0
  %endif
  %ifndef   FREEMEMINFO
    %define FREEMEMINFO 0
  %endif
  %ifndef   GETVERSION
    %define GETVERSION 0
  %endif
  %ifndef   ABORTMSGTTY
    %define ABORTMSGTTY 1
  %endif
  %ifndef   EXITCODE
    %define EXITCODE 1
  %endif
  %ifndef   FEWRELOCS
    %define FEWRELOCS 0  ; FEWRELOCS==1 only needed if we use >=3 PE sections. But we use only 1.
  %endif
  %ifndef   SPEDOSONLY
    %define SPEDOSONLY 1  ; Setting this prevents Windows from recognize this program as a Win32 i386 PE .exe (and then failing at runtime). 32-bit i386 Windows will run it as a DOS .exe instead. Comment this out to make static analysis tools (such as GNU objdump) work.
  %endif

  %define SPE_end SPE_end  ; Define the label later.
  %define SPE_bssend SPE_bssend  ; Define the label later.
  ;%define SPE_EntryPoint SPE_EntryPoint  ; Define the label later. Already defined.
%endif
; This is the simple PE builder, it can be activated using `%define
; SPE_EntryPoint ...'.
;
; If the simple PE builder is active, then pmodew.nasm not only builds the
; DOS stub of the DOS extender PMODE/W, but it builds a simple i386 PE .exe
; program file directly, with the uncompressed PMODE/W DOS extender in its
; DOS stub, so thes program will run on DOS and in OS/2 >=2.0 DOS window.
;
; Example hello-world program (hellospe.nasm):
;
;   %define SPE_EntryPoint _start  ; Activate the simple PE builder.
;   %include 'pmodew.nasm'
;   _start:
;           spe_pic_delta_to ebp
;           mov ah, 9  ; Print '$'-terminated message starting at EDX.
;           lea edx, [ebp+msg]  ; +EBP for position-independent code.
;           int 0x21  ; DOS-extended syscall.
;           mov ax, 0x4c00  ; Exit successfully.
;           int 0x21  ; DOS-extended syscall.
;   msg:    db 'Hello, World!', 13, 10, '$'
;   spe_end
;
; Build it with: nasm -O32700 -w+orphan-labels -o hellospe.exe hellospe.nasm
;
; See helluspe.nasm for an example which uses more features of the simple PE
; builder.
;
; Limitations:
;
; * These are the limitations of the simple PE builder. The simple PE loader
;   has its own, less restrictive limitations.
; * Building Win32 i386 .exe programs is not supported, because the the
;   simple PE builder can't build the import table, and the import table is
;   needed for calling Win32 API functions like ExitProcess(...).
; * To make sure that the .exe program files built are not misdetected as
; * Win32 i386 .exe programs, the simple PE builder emits an incorrect PE
;   header file offset (41h instead of 40h) at file offset 3ch.
; * Relocations are not supported, so for each global variable access, a
;   helper register value should be added to the address (see
;   `spe_pic_delta_to ebp' in the example above.
; * Only the uncompressed PMODE/W DOS extender DOS stub is supported.
;   Compressing it would make the resulting .exe file exactly 3 KiB shorter
;   (because of PE .FileAlignment == 200h), but by compression we'd lose the
;   simplicity of creating the .exe file in a single run of NASM.
; * The global namespace is polluted with internal PMODE/W labels and
;   macros.
; * Only a single section (combined code, data and BSS) is supported.
; * It can't generate debug info (such as labels and source line numbers).
; * The entire program must be compiled in a single run of NASM. This can
;   be slow or need too much memory for large programs. It can also lead
;   to label collisions (dependening on the quality of the soruce code).

%ifndef PMWV  ; Can be specified on the command line.
  %define PMWV 33  ; Generate PMODE/W version 1.33.
  ;%define PMWV 34  ; Generate PMODE/W version 1.34.
%else
  %assign PMWV PMWV  ; Make sure it's an integer (expression), convert it to integer constant.
%endif

%ifndef UNC  ; Can be specified on the command line.
  %define UNC 0   ; Generate non-working, uncompressed DOS .exe (pmodewu.exe), which will have to be compressed by pmwc to produce the working, compressed, final, release pmodew.exe.
  ;%define UNC 1  ; Generate the working, remains-uncompressed DOS .exe stub (pmodewv.exe), which contains the pmodew_config at the beginning of the MZ .exe image. Longer that pmodew.exe, but it is faster to create, and it is useful for testing.
%elifidn (UNC), ()
  %define UNC 1
%else
  %assign UNC UNC  ; Make sure it's an integer (expression), convert it to integer constant.
%endif

%ifndef DEBUG  ; Can be specified on the command line.
  %define DEBUG 0   ; Disable debug code.
  ;%define DEBUG 1  ; Enable  debug code. Not implemented.
%elifidn (DEBUG), ()
  %define DEBUG 1
%else
  %assign DEBUG DEBUG  ; Make sure it's an integer (expression), convert it to integer constant.
%endif

%ifndef LOGO  ; Can be specified on the command line.
  %define LOGO 1   ; Display the logo and the copyright message upon startup, if instructed by the runtime config.
  ;%define LOGO 0  ; Never display the logo and the copyright message upon startup, don't even include them in the .exe.
%elifidn (LOGO), ()
  %define LOGO 1
%else
  %assign LOGO LOGO  ; Make sure it's an integer (expression), convert it to integer constant.
%endif

%ifndef CONFIGTYPE  ; Can be specified on the command line.
  %define CONFIGTYPE 0   ; Use ==1 if UNC==0 (default, for bytewise identical pmodew.exe) or LOADSPE!=0, ==3 for UNC==1 and LOADSPE==0.
  ;%define CONFIGTYPE 1  ; When loading pmodew_config from beginning of the MZ .exe image, support 2 <= hdrsize <= 4. and the behavior is undefined if hdrsize is larger. It's for bytewise identical pmodew.exe. Most users should use ==2 or ==3 instead. Ignored if VARTYPE!=1 or LOADSPE>0.
  ;%define CONFIGTYPE 2  ; When loading pmodew_config from beginning of the MZ .exe image, support 2 <= hdrsize <= 30, and it fail cleanly for larger values. Ignored if VARTYPE!=1 or LOADSPE>0.
  ;%define CONFIGTYPE 3  ; When loading pmodew_config from beginning of the MZ .exe image, support 2 <= hdrsize <= 0xffff (unlimited), and  fail cleanly for larger values. Ignored if VARTYPE!=1 or LOADSPE>0.
%elifidn (CONFIGTYPE), ()
  %define CONFIGTYPE 3
%else
  %assign CONFIGTYPE CONFIGTYPE  ; Make sure it's an integer (expression), convert it to integer constant.
%endif
%ifndef SIZEOPT  ; Can be specified on the command line.
  %define SIZEOPT 0   ; Disable size optimizations. This is to reproduce a bitwise identical pmodewu.exe and pmodew.exe output.
  ;%define SIZEOPT 1  ; Enable  size optimizations to make pmodew.exe a few bytes (up to 10 bytes) shorter. It doesn't make it slower.
%elifidn (SIZEOPT), ()
  %define SIZEOPT 1
%else
  %assign SIZEOPT SIZEOPT  ; Make sure it's an integer (expression), convert it to integer constant.
%endif

%ifndef PMW1UNCOMP  ; Can be specified on the command line.
  %define PMW1UNCOMP 0   ; PMW1-format 32-bit payloads are compressed. Uncompressed payloads are not supported.
  ;%define PMW1UNCOMP 1  ; PMW1-format 32-bit payloads are uncompressed. Compressed payloads are not supported.
%elifidn (PMW1UNCOMP), ()
  %define PMW1UNCOMP 1
%else
  %assign PMW1UNCOMP PMW1UNCOMP  ; Make sure it's an integer (expression), convert it to integer constant.
%endif

%ifndef LOADLE  ; Can be specified on the command line.
  %define LOADLE 1   ; Enable  loading of LE-format 32-bit payloads. These are always uncompressed.
  ;%define LOADLE 0  ; Disable loading of LE-format 32-bit payloads.
%elifidn (LOADLE), ()
  %define LOADLE 1
%else
  %assign LOADLE LOADLE  ; Make sure it's an integer (expression), convert it to integer constant.
%endif

%ifndef LOADPMW1  ; Can be specified on the command line.
  %define LOADPMW1 1   ; Enable  loading of PMW1-format 32-bit payloads. These are either compressed or uncompressed, determined at compile time (PMW1UNCOMP), there is no autodetection.
  ;%define LOADPMW1 0  ; Disable loading of PMW1-format 32-bit payloads.
%elifidn (LOADPMW1), ()
  %define LOADPMW1 1
%else
  %assign LOADPMW1 LOADPMW1  ; Make sure it's an integer (expression), convert it to integer constant.
%endif

%ifndef LOADSPE  ; Can be specified on the command line.
  %define LOADSPE 0   ; Disable loading of simple PE-format 32-bit payloads.
  ;%define LOADSPE 1  ; Enable  loading of simple PE-format 32-bit payloads. PMODE/W is compressed, the payload is uncompressed.
  ;%define LOADSPE 2  ; Enable  loading of simple PE-format 32-bit payloads, with some features removed or shortened. PMODE/W is compressed, the payload is uncompressed.
  ;%define LOADSPE 3  ; Enable  loading of simple PE-format 32-bit payloads, shorten PMODE/W initialization error messages. PMODE/W is compressed, the payload is uncompressed.
%elifidn (LOADSPE), ()
  %define LOADSPE 1
%else
  %assign LOADSPE LOADSPE  ; Make sure it's an integer (expression), convert it to integer constant.
%endif
%if CONFIGTYPE==0
  %if UNC==0 || LOADSPE
    %define CONFIGTYPE 1  ; For bytewise identical pmodew.exe.
  %else
    %define CONFIGTYPE 3
  %endif
%endif
; The simple PE loader (with signature simPloEd) is not part of PMODE/W,
; it's an extension written by pts. It can load i386 PE .exe program
; files, with many limitations:
;
; * Minimum CPU requirement: 80386. Win32 and PMODE/W also need this.
; * The PMODE/W stub with the simple PE loader is not able to load any other
;   file formats, i.e. LOADLE and LOADPMW1 must be 0. This is checked at
;   compile time.
; * The data directory must have 16 entries, i.e. NumberOfRvaAndSizes must
;   be 16. This is checked.
; * The number of PE sections must be between 1 and 5 inclusive, i.e.
;   NumberOfSections must be at least 1 and ant most 5. This is checked.
; * The simple PE loader allocates a static buffer of SizeOfStackCommit
;   bytes (rounded up to a multiple of 4) for the stack. The stack will not
;   grow.
; * The simple PE loader loads all PE sections to an arbitrary, page aligned
;   (linear address is a multiple of 1000h) memory location, not to
;   ImageBase.
; * The simple PE loader applies the PE relocations (in
;   IMAGE_DIRECTORY_ENTRY_BASERELOC) unless disabled with -DSPERELOC=0 at
;   compile time. The simple PE loader supports only the HIGHLOW and
;   ABSOLUTE (no-op) relocation types (unchecked), each relocation block
;   must be nonempty (unchecked), and each relocation must point to a valid
;   dword location within a loaded PE section (unchecked).
; * The simple PE loader doesn't load any DLLs (in
;   IMAGE_DIRECTORY_ENTRY_IMPORT), not even kernel32.dll. The payload should
;   keep using int 21h (DOS-extended) and int 31h (DPMI) services provided
;   by the PMODE/W stub for memory allocation and I/O.
; * The simple PE loader uses the PE entry point (AddressOfEntryPoint) by
;   default (SPECUSTOMENTRY==0), but with -DSPECUSTOMENTRY=1, it uses the
;   last 2 bytes (SizeOfRawData-2) of the first section as the entry point,
;   and with -DSPECUSTOMENTRY=2 (only if there is an import table), it uses
;   AddressOfEntryPoint+5 as the entry point. This is to avoid API and ABI
;   conflicts with Win32, which uses AddressOfEntryPoint. This way the same
;   PE .exe program file, with the same PE sections can be used as separate
;   Win32 and DOS-extended programs sharing some code and data. Native Win32
;   can still be detected even with the default
;   -DSPECUSTOMENTRY=0, see below.
; * The simple PE loader doesn't allocate any heap memory, it ignores
;   SizeOfHeapReserve and SizeOfHeapCommit.
; * The simple PE loader allocates a memory block of SizeOfImage +
;   SizeOfStackCommit bytes (rounded up to dword boundary). This value is
;   not checked against the section sizes.
; * The simple PE loader initializes FS to the same value as DS == ES == SS.
;   This is different from Win32, which initializes FS to a selector to the
;   Thread Information Block (TIB) or TEB, containing pointers to
;   Structured Exception Handling (SEH) and the Process Environment Block
;   (PEB). Thus the Simple PE loader doesn't support SEH.
;
; Limitations if CONFIGTYPE==2 (non-default, designed to be used as a DOS
; stub embedded into the PE .exe file with OpenWatcom v2 `wlink format
; windows nt option stub=pmodewd.exe'):
;
; * The load-time configuration is loaded from the beginning of the DOS MZ
;   exe image, which is file offset 40h when created by wlink. The maximum
;   allowed file offset ix 1eh (checked).
; * The PE header can start at any file offset.
; * The PE header must be at most 1c0h bytes long, i.e.
; * MumberOfSections must be at most 5. This is checked.
; * The simple PE loader treats the lowest bit of the PE header file offset
;   (byte at file offset 3ch) as 0, even if that byte is odd. This is so
;   that this bit can be intentionally set to 1 to prevent Win32 from
;   loading an incompatible PE .exe. Please note that wlink always sets the
;   bit to 0.
; * Before loading any section data, the simple PE loader loads the first
;   0x200 bytes of the the .exe file to the memory location above. Then it
;   copies the 15h == 21 bytes of load-time configuration data to 20h == 32
;   bytes after the memory location above. Then it loads the PE header (1c0h
;   bytes, even if the PE header is shorter) to 40h == 64 bytes after the
;   memory location above. Then it sets the lowest bit of byte offset 3ch
;   after the memory location above (so that the program can detect that it
;   is running on DOS rather than Win32). All this is different from how how
;   Win32 loads the beginning of the PE .exe program file in front of the
;   first section.
;
; Limitations if CONFIGTYPE!=2 (default):
;
; * The load-time configuration is loaded from file offset 20h.
; * The PE header must start at file offset 40h. This is checked.
; * (The PMODE/W stub MZ .exe image must start at file offset 200h. This is
;   checked.)
; * The PE section header must end at file offset 200h, i.e. SizeOfHeaders
;   must be 200h. This is checked.
; * Before loading any section data, the simple PE loader loads the first
;   0x200 bytes of the the .exe file to the memory location above. (This is
;   compatible with how Win32 loads a PE .exe program file.)
;
; Because of the limitations above, the simple PE loader isn't suitable for
; running existing Win32 programs on DOS. For that, use the HX DOS extender
; or WDOSX (after doing some conversion of the .exe file).
;
; The simple PE loader initializes the CPU registers like this:
;
; * CS:EIP points to the simple PE DOS-extended entry point (see above),
;   which is 2 bytes before the end of the firt section (SizeOfRawData-2).
; * SS:ESP points to the end (top) of the allocated stack space allocated
;   (see above). Most of it, but not the top 200h bytes are zero-initialized
;   (i.e. filled with NUL bytes).
; * DS:EAX points to the PSP segment. The command-line string is at
;   DS:EAX+80h as a Pascal string (first byte contains the length of the
;   rest), and then terminated by byte CR == 13.
; * CS is a zero-based, read-execute, linear code segment selector.
; * DS == ES == SS == FS == GS are zero-based, read-write, linear data
;   segment selectors with the same value.
; * EBX == ECX == EDX == ESI == EDI == EBP == 0.
; * DF=0 (cld).
; * EFLAGS set using `sub ebx, ebx': OF=0, SF=0, ZF=1, AF=0, PF=1 and CF=0.
;
; Here is how to get access to the environment in the 32-bit PE payload:
;
;   mov bx, [eax+2ch]  ; BX := environment selector got from the PSP.
;   mov ax, 6  ; DPMI Get Segment Base Address.
;   int 31h  ; DPMI call.
;   shl ecx, 16
;   movzx edx, dx
;   add edx, ecx  ; EDX := linear base address of the first env var.
;
; Here are ways detect whether the PE .exe program is running on native
; Win32 or on DOS with the simple PE loader:
;
; * `test byte [ImageBase+3ch], 1' (if relocated) sets ZF := 0 when running
;   on DOS with the simple PE loader, and ZF := 1 when running on native
;   Win32. That's because the simple PE loader changes the PE header file
;   offset from 40h to 41h in memory. The test is hardto pull of from
;   OpenWatcom v2 C code, because it's not possible to get an instruction
;   with the relocated ImageBase.
;
; * If -DSPECUSTOMENTRY=2 is used, then the program starts on Win32 at
;   ImageBase+AddressOfEntryPoint, and on DOS, the simple PE loader starts
;   it there iff there is no import table (i.e. it's a DOS-only program),
;   and at ImageBase+AddressOfEntryPoint+5 if there is (i.e. it's a
;   DOS--Win32 combined program). The entry points can set a global variable
;   to a different value, which can be checked later.
;
; * If -DSPECUSTOMENTRY=1 is used, then the program starts on Win32 at
;   ImageBase+AddressOfEntryPoint, and on DOS, the simple PE loader starts
;   it at the last 2 bytes (SizeOfRawData-2) of the first section. The entry
;   points can set a global variable to a different value, which can be
;   checked later.
;
; * If -DSPECUSTOMENTRY=0 is used, then `cmp dword [ImageBase+0c4h], byte
;   -1' (if relocated) sets ZF := 1 when running on DOS with the simple PE
;   loader, and ZF := 0 when running on native Win32. That's because the
;   simple PE loader sets this value dword [ImageBase+0c4h == ImageBase +
;   spefofs.pehdr.IMAGE_DIRECTORY_ENTRY_IMPORT+peidd.Size] == dword
;   [ImageBase+0c4h] to -1 (== 0xffffffff), and Win32 keeps it unchanged,
;   and the file always contains an even value for Win32.
;
; * Detect DOS with the simple PE loader by checking e.g. that dword
;   [__imp_ExitProcess] hasn't been modified. Compare it against the
;   original value, which is a nonzero RVA value pointing to db 0, 0,
;   'ExitProcess', 0; this is a bit hard to extract, because the linker
;   determines it.

%ifndef SPERELOC  ; Can be specified on the command line.
  %define SPERELOC 1   ; Enable  applying of relocations (in IMAGE_DIRECTORY_ENTRY_BASERELOC) in the simple PE payload.
  ;%define SPERELOC 0  ; Disable applying of relocations (in IMAGE_DIRECTORY_ENTRY_BASERELOC) in the simple PE payload.
%elifidn (SPERELOC), ()
  %define SPERELOC 1
%else
  %assign SPERELOC SPERELOC  ; Make sure it's an integer (expression), convert it to integer constant.
%endif

%ifndef SPECUSTOMENTRY  ; Can be specified on the command line.
  %define SPECUSTOMENTRY 0   ; Use AddressOfEntryPoint in the PE header as the entry point.
  ;%define SPECUSTOMENTRY 1  ; Use the last 2 bytes (SizeOfRawData-2) of the first section as the entry point.
  ;%define SPECUSTOMENTRY 2  ; If there is an import table (IMAGE_DIRECTORY_ENTRY_IMPORT.RVA is nonzero), use AddressOfEntryPoint+5, otherwise use AddressOfEntryPoint as the entry point.
%elifidn (SPECUSTOMENTRY), ()
  %define SPECUSTOMENTRY 1
%else
  %assign SPECUSTOMENTRY SPECUSTOMENTRY  ; Make sure it's an integer (expression), convert it to integer constant.
%endif

%ifndef SPEDOSONLY  ; Can be specified on the command line.
  %define SPEDOSONLY 0   ; Make Windows, Wine and static analysis tools recognize the .exe as a Win32 PE .exe. Windows and Wine will run it directly. OS/2 >=2.0 DOS window and DOS will run it using the embedded PMODE/W.
  ;%define SPEDOSONLY 1  ; Make Windows, Wine and static analysis tools recognize the .exe as a DOS .exe. 32-bit i386 Windows, OS/2 >=2.0 DOS window and DOS will run it using the embedded PMODE/W. Wine and 64-bit Windows won't run it.
  ;%define SPEDOSONLY 2  ; Like ==1, but the simple PE loader will run it even if the PE header file offset field in the header is changed back to 40h manually. Most users need ==1 instead.
%elifidn (SPEDOSONLY), ()
  %define SPEDOSONLY 1
%else
  %assign SPEDOSONLY SPEDOSONLY  ; Make sure it's an integer (expression), convert it to integer constant.
%endif

%ifndef SPESIZEIMG  ; Can be specified on the command line.
  %define SPESIZEIMG 1   ; Use SizeOfImage when determining how many bytes to allocate for the simple PE image.
  ;%define SPESIZEIMG 0  ; Use the largest section .VirtualAddress+.VirtualSize when determining how many bytes to allocate for the simple PE image.
%elifidn (SPESIZEIMG), ()
  %define SPESIZEIMG 1
%else
  %assign SPESIZEIMG SPESIZEIMG  ; Make sure it's an integer (expression), convert it to integer constant.
%endif

%if (LOADLE|LOADPMW1|LOADSPE)==0
  %error ERROR_SUPPORT_FOR_ALL_PAYLOAD_FORMATS_DISABLED
  times -1 nop
%endif

%ifndef EXCEPTIONS  ; Can be specified on the command line.
  %define EXCEPTIONS 1   ; Enable  DPMI processor exception handler API (int 31h, AX == 202h and AX == 203h).
  ;%define EXCEPTIONS 0  ; Disable DPMI processor exception handler API (int 31h, AX == 202h and AX == 203h).
%elifidn (EXCEPTIONS), ()
  %define EXCEPTIONS 1
%else
  %assign EXCEPTIONS EXCEPTIONS  ; Make sure it's an integer (expression), convert it to integer constant.
%endif

%ifndef EXITCODE  ; Can be specified on the command line.
  %define EXITCODE 0   ; Disable reporting deterministic DOS process exit codes on fatal error.
  ;%define EXITCODE 1  ; Enable  reporting deterministic DOS process exit codes on fatal error.
%elifidn (EXITCODE), ()
  %define EXITCODE 1
%else
  %assign EXITCODE EXITCODE  ; Make sure it's an integer (expression), convert it to integer constant.
%endif

%ifndef FEWRELOCS  ; Can be specified on the command line.
  %define FEWRELOCS 0   ; Disable code changes which use fewer DOS MZ .exe relocations.
  ;%define FEWRELOCS 1  ; Enable  code changes which use fewer DOS MZ .exe relocations. Thease are useful to increase _MAX_UNC_PE_SECTIONS by 1 %if UNC && LOADSPE && INT1B==0 && INT33==0.
%elifidn (FEWRELOCS), ()
  %define FEWRELOCS 1
%else
  %assign FEWRELOCS FEWRELOCS  ; Make sure it's an integer (expression), convert it to integer constant.
%endif

%ifndef SHORTMSG  ; Can be specified on the command line.
  %define SHORTMSG 0   ; Print the original PMODE/W 1.33 error messages.
  ;%define SHORTMSG 1  ; Print short error messages.
%elifidn (SHORTMSG), ()
  %define SHORTMSG 1
%else
  %assign SHORTMSG SHORTMSG  ; Make sure it's an integer (expression), convert it to integer constant.
%endif

%ifndef ABORTMSGTTY  ; Can be specified on the command line.
  %define ABORTMSGTTY 0   ; Write the exception abort message directly to video memory.
  ;%define ABORTMSGTTY 1  ; Write the exception abort message to the video TTY console (int 10h, AH == 0eh). This is useful for some text-only DOS emulators.
  ;%define ABORTMSGTTY 2  ; Write the exception abort message to DOS stdout (int 21h, AH == 2). This is useful for some text-only DOS emulators.
  ;%define ABORTMSGTTY 3  ; Write the exception abort message to using undocumented DOS fast character write (int 29h). This is useful for some text-only DOS emulators.
%elifidn (ABORTMSGTTY), ()
  %define ABORTMSGTTY 1
%else
  %assign ABORTMSGTTY ABORTMSGTTY  ; Make sure it's an integer (expression), convert it to integer constant.
%endif

%ifndef FREEMEMINFO  ; Can be specified on the command line.
  %define FREEMEMINFO 1   ; Enable  DPMI get free memory information API (int 31h, AX == 500h).
  ;%define FREEMEMINFO 0  ; Disable DPMI get free memory information API (int 31h, AX == 500h).
%elifidn (FREEMEMINFO), ()
  %define FREEMEMINFO 1
%else
  %assign FREEMEMINFO FREEMEMINFO  ; Make sure it's an integer (expression), convert it to integer constant.
%endif

%ifndef GETVERSION  ; Can be specified on the command line.
  %define GETVERSION 1   ; Enable  DPMI get version API (int 31h, AX == 400h).
  ;%define GETVERSION 0  ; Disable DPMI get version API (int 31h, AX == 400h).
%elifidn (GETVERSION), ()
  %define GETVERSION 1
%else
  %assign GETVERSION GETVERSION  ; Make sure it's an integer (expression), convert it to integer constant.
%endif

%ifndef INT3108FUNC  ; Can be specified on the command line.
  %define INT3108FUNC 1   ; Enable  DPMI physical address mapping API (int 31h, AX == 8000h and AX == 8001h).
  ;%define INT3108FUNC 0  ; Disable DPMI physical address mapping API (int 31h, AX == 8000h and AX == 8001h).
%elifidn (INT3108FUNC), ()
  %define INT3108FUNC 1
%else
  %assign INT3108FUNC INT3108FUNC  ; Make sure it's an integer (expression), convert it to integer constant.
%endif

%ifndef INT1B  ; Can be specified on the command line.
  %define INT1B 1   ; Enable  handling of the Ctrl-Break interrupt (int 1bh). At the beginning of each `int 1bh' call, PMODE/W checks if Ctrl-<Break> was press. If so, it exits with code 0 (success).
  ;%define INT1B 2  ; Enable  handling of the Ctrl-Break interrupt (int 1bh). At the beginning of each `int 1bh' call, PMODE/W checks if Ctrl-<Break> was press. If so, it exits with code 0feh == 254 (failure).
  ;%define INT1B 0  ; Disable handling of the Ctrl-Break interrupt (int 1bh).
%elifidn (INT1B), ()
  %define INT1B 1
%else
  %assign INT1B INT1B  ; Make sure it's an integer (expression), convert it to integer constant.
%endif
; DOSBox 0.74-3 doesn't support sending Ctrl-<Break> to the program via int
; 1bh. Ctrl-<Break> and Ctrl-<ScrolLock> presses will be ignored. When
; running on MS-DOS running in QEMU, the Ctrl-<Break> gets delivered as int
; 1bh.
;
; Regular DOS is more eager to stop the program at Ctrl-<Break>. For example
; it can do so while it is waiting for keyboard input (int 21h with AH ==
; 1). PMODE/W will only stop the program at a subsequent int 21h call after
; the keypress, so the user has to press another key after Ctrl-<Break>, then
; they have to wait for an int 21h call.

%ifndef INT31VENDOR  ; Can be specified on the command line.
  %define INT31VENDOR 1   ; Enable  vendor-specific PMODE/W extension DPMI APIs (int 31h, AX == 0a00h and AX == 0eeffh).
  ;%define INT31VENDOR 0  ; Disable vendor-specific PMODE/W extension DPMI APIs (int 31h, AX == 0a00h and AX == 0eeffh).
%elifidn (INT31VENDOR), ()
  %define INT31VENDOR 1
%else
  %assign INT31VENDOR INT31VENDOR  ; Make sure it's an integer (expression), convert it to integer constant.
%endif

%ifndef INT33  ; Can be specified on the command line.
  %define INT33 1   ; Enable  handling of the mouse interrupt (int 33h).
  ;%define INT33 0  ; Disable handling of the mouse interrupt (int 33h).
%elifidn (INT33), ()
  %define INT33 1
%else
  %assign INT33 INT33  ; Make sure it's an integer (expression), convert it to integer constant.
%endif

%ifndef OPENTYPE  ; Can be specified on the command line. Determines how PMODE/W finds the filename of the payload .exe file to open.
  %define OPENTYPE 1   ; Open the currently running .exe file. Useful when PMODE/W is used as a stub at the beginning of the payload .exe file.
  ;%define OPENTYPE 2  ; Open the .exe file with filename as a NUL-terminated string at 0:4c0h == 40h:0c0h. At most 40h == 64 bytes can be stored there.
  ;%define OPENTYPE 3  ; Open the .exe file specified at the beginning of the command line (space-separated), and removes that filename from the command line.
%elifidn (OPENTYPE), ()
  %define OPENTYPE 1
%else
  %assign OPENTYPE OPENTYPE  ; Make sure it's an integer (expression), convert it to integer constant.
%endif

%ifndef VARTYPE  ; Can be specified on the command line. Determines how PMODE/W finds the 32-bit payload (LE or PMW1) in the payload .exe file.
  %define VARTYPE 1   ; Use the pmodew_config at the first 15h bytes of the MZ .exe image (file offset hdrsize<<4) as load-time configuration.
  ;%define VARTYPE 2  ; Use the hardcoded default values (PM_*) as load-time configuration.
%elifidn (VARTYPE), ()
  %define VARTYPE 1
%else
  %assign VARTYPE VARTYPE  ; Make sure it's an integer (expression), convert it to integer constant.
%endif

%ifndef MEMDEBUG  ; Can be specified on the command line.
  %define MEMDEBUG 0   ; Disable memory usage debugging. Most users want it disable like this.
  ;%define MEMDEBUG 1  ; Enable  memory usage debugging.
%elifidn (MEMDEBUG), ()
  %define MEMDEBUG 1
%else
  %assign MEMDEBUG MEMDEBUG  ; Make sure it's an integer (expression), convert it to integer constant.
%endif

%if LOADSPE && LOADLE
  %error ERROR_LOADSPE_CONFLICTS_WITH_LOADLE
  times -1 nop
%endif
%if LOADSPE && LOADPMW1
  %error ERROR_LOADSPE_CONFLICTS_WITH_LOADPMW1
  times -1 nop
%endif

; --- Macros.

%macro multipush 1-*
  %rep %0
    push %1
    %rotate 1
  %endrep
%endmacro

%macro multipop 1-*
  %rep %0
    pop %1
    %rotate 1
  %endrep
%endmacro

; Near jump to %1 if condition %1 is met, with a non-invertible condition.
%macro _jmp_cond_near_ni 2
  j%1 %%jump
  jmp short %%skip
  %%jump: jmp strict near %2
  %%skip:
%endm

; TASM-compatible near jump to %2 if condition %1 is met. 1 byte longer than necessary.
%macro jmp_cond_near 2
  ; Diff: TASM encodes the near jump 1 byte longer than needed.
  ; When TASM-compatibility is dropped, this can be optimized to `j%1 strict near %2' if _jmp_cond_near_ni is not used.
  %ifidn (%1), (ecxz)
    _jmp_cond_near_ni %1, %2
  %elifidn (%1), (cxz)
    _jmp_cond_near_ni %1, %2
  %else
    j%-1 %%skip
    jmp strict near %2
    %%skip:
  %endif
%endm

; dw for the last argument, but db first for all previous arguments.
%macro lastdw 1-*
  %rep %0-1
    db %1
    %rotate 1
  %endrep
  dw %1
%endm

; dd for the last argument, but db first for all previous arguments.
%macro lastdd 1-*
  %rep %0-1
    db %1
    %rotate 1
  %endrep
  dd %1
%endm

%define __R8IDX_al 0
%define __R8IDX_cl 1
%define __R8IDX_dl 2
%define __R8IDX_bl 3
%define __R8IDX_ah 4
%define __R8IDX_ch 5
%define __R8IDX_dh 6
%define __R8IDX_bh 7

%define __R16IDX_ax 0
%define __R16IDX_cx 1
%define __R16IDX_dx 2
%define __R16IDX_bx 3
%define __R16IDX_sp 4
%define __R16IDX_bp 5
%define __R16IDX_si 6
%define __R16IDX_di 7

%define __R32IDX_eax 0
%define __R32IDX_ecx 1
%define __R32IDX_edx 2
%define __R32IDX_ebx 3
%define __R32IDX_esp 4
%define __R32IDX_ebp 5
%define __R32IDX_esi 6
%define __R32IDX_edi 7

%define __STRIP_E_eax ax
%define __STRIP_E_ebx bx
%define __STRIP_E_ecx cx
%define __STRIP_E_edx dx
%define __STRIP_E_esi si
%define __STRIP_E_edi di
%define __STRIP_E_ebp bp
%define __STRIP_E_esp sp

; Registers for short xchg.
%define __XCHGSR_ax
%define __XCHGSR_eax

%macro __fixrr 3  ; Internal helper.
  %ifdef __R8IDX_%2
    dw (%1)|0xc002|(__R8IDX_%2)<<11|(__R8IDX_%3)<<8
  %elifdef __R16IDX_%2
    dw (%1)|0xc003|(__R16IDX_%2)<<11|(__R16IDX_%3)<<8
  %else
    o32
    dw (%1)|0xc003|(__R32IDX_%2)<<11|(__R32IDX_%3)<<8
  %endif
%endm

%macro _mov 2  ; Example: _mov ax, bx
  ; Diff: TASM encodes register-register operations differently.
  __fixrr 0x8a, %1, %2
%endm
%macro _xchg 2  ; Example: _xchg bx, cx
  ; Diff: TASM encodes register-register operations differently from NASM 2.16.03. No diff between TASM and NASM 0.98.39--2.13.02.
  %ifdef __XCHGSR_%1
    xchg %1, %2
  %elifdef __XCHGSR_%2
    xchg %1, %2
  %else
    __fixrr 0x84, %1, %2
  %endif
%endm
%macro _add 2  ; Example: _add ax, bx
  ; Diff: TASM encodes register-register operations differently.
  __fixrr 0x00, %1, %2
%endm
%macro _or 2  ; Example: _or ax, bx
  ; Diff: TASM encodes register-register operations differently.
  __fixrr 0x08, %1, %2
%endm
%macro _sub 2  ; Example: _sub ax, bx
  ; Diff: TASM encodes register-register operations differently.
  __fixrr 0x28, %1, %2
%endm
%macro _xor 2  ; Example: _xor ax, bx
  ; Diff: TASM encodes register-register operations differently.
  __fixrr 0x30, %1, %2
%endm
%macro _cmp 2  ; Example: _cmp ax, bx
  ; Diff: TASM encodes register-register operations differently.
  __fixrr 0x38, %1, %2
%endm

%macro fixstr 2  ; Example: `fixstr fs a32, lodsd' --> `o32 fs a32 lodsw'.
  ; Diff: TASM encodes the o32 == 0x66 prefix, then the segment prefix, then the data size prefix (a32), NASM does it the other way round.
  %ifidn (%2), (lodsd)
    o32
    %1 lodsw
  %elifidn (%2), (stosd)
    o32
    %1 stosw
  %elifidn (%2), (scasd)
    o32
    %1 scasw
  %elifidn (%2), (movsd)
    o32
    %1 movsw
  %elifidn (%2), (cmpsd)
    o32
    %1 cmpsw
  %else
    %error ERROR_BAD_FIXSTR_INSTRUCTION %2
    times -1 nop
  %endif
%endm

%macro fixstr 3  ; Example: `fixstr repe, a32, scasd' --> `repe o32 fs a32 scasw'.
  ; Diff: TASM encodes the o32 == 0x66 prefix, then the segment prefix, then the data size prefix (a32), NASM does it the other way round.
  %1
  fixstr %2, %3
%endm

%macro __fixpre 3  ; Internal helper.
  o32  ; db 0x66
  %1 __STRIP_E_%2, %3
%endm
%macro __fixpre2 3  ; Internap helper.
  o32  ; db 0x66
  %1 %2, __STRIP_E_%3
%endm

%macro fixpre_cmp_dword_byte 2  ; Example `fixpre_cmp_dword_byte [gs:33h*4],0' --> cmp dword [gs:33h*4],byte 0' --> `o32' ++ `cmp word [gs:33h*4],byte 0'.
  ; Diff: TASM encodes the o32 == 0x66 prefix, then the segment prefix, NASM does it the other way round.
  o32
  cmp word %1, byte %2
%endm
%macro fixpre_push_dword 1  ; Example: fixpre_push_dword [cs:-pmodewk+exceptionevect+si]
  ; Diff: TASM encodes the o32 == 0x66 prefix, then the segment prefix, NASM does it the other way round.
  o32
  push word %1
%endm
%macro fixpre_pop_dword 1  ; Example: fixpre_pop_dword [es:-pmodewk+pmstackesp]
  ; Diff: TASM encodes the o32 == 0x66 prefix, then the segment prefix, NASM does it the other way round.
  o32
  pop word %1
%endm
%macro fixpre_jmp_dword 1  ; Example: fixpre_jmp_dword far [cs:-pmodewe+_int21vectoff]
  ; Diff: TASM encodes the o32 == 0x66 prefix, then the segment prefix, NASM does it the other way round.
  o32
  jmp word %1
%endm
%macro fixpre_call_dword 1  ; Example: fixpre_call_dword [cs:-pmodewe+_int330Ccalloff]
  ; Diff: TASM encodes the o32 == 0x66 prefix, then the segment prefix, NASM does it the other way round.
  o32
  call word %1
%endm
%macro fixpre_mov 2  ; Example: fixpre_mov edi,[cs:-pmodewe+_int21lowbufptr]
  ; Diff: TASM encodes the o32 == 0x66 prefix, then the segment prefix, NASM does it the other way round.
  __fixpre mov, %1, %2
%endm
%macro fixpre_xchg 2  ; Example: fixpre_xchg eax,[fs:-pmodewk+pmstackesp]
  ; Diff: TASM encodes the o32 == 0x66 prefix, then the segment prefix, NASM does it the other way round.
  __fixpre xchg, %1, %2
%endm
%macro fixpre_cmp 2  ; Example: fixpre_cmp ebx,[cs:-pmodewe+_int21lowbufsize]
  ; Diff: TASM encodes the o32 == 0x66 prefix, then the segment prefix, NASM does it the other way round.
  __fixpre cmp, %1, %2
%endm
%macro fixpre_add 2  ; Example: fixpre_add eax,[gs:2ch]
  ; Diff: TASM encodes the o32 == 0x66 prefix, then the segment prefix, NASM does it the other way round.
  __fixpre add, %1, %2
%endm
%macro fixpre_sub 2  ; Example: fixpre_sub ecx,[gs:100h]
  ; Diff: TASM encodes the o32 == 0x66 prefix, then the segment prefix, NASM does it the other way round.
  __fixpre sub, %1, %2
%endm
%macro fixpre2_mov 2  ; Example: fixpre2_mov edi,[cs:-pmodewe+_int21lowbufptr]
  ; Diff: TASM encodes the o32 == 0x66 prefix, then the segment prefix, NASM does it the other way round.
  __fixpre2 mov, %1, %2
%endm
%macro fixpre2_add 2  ; Example: fixpre2_add [cs:-pmodewk+pmstacktop],eax
  ; Diff: TASM encodes the o32 == 0x66 prefix, then the segment prefix, NASM does it the other way round.
  __fixpre2 add, %1, %2
%endm

%macro fixpre_movzx_word 3  ; Example: `fixpre_movzx_word esi, cs, -pmodewe+_int21lowdtaseg' --> `movzx esi,word [cs:-pmodewe+_int21lowdtaseg]'.
  ; Diff: TASM encodes the o32 == 0x66 prefix, then the segment prefix, NASM does it the other way round.
  o32
  %2
  dw 0xb70f
  %ifdef __R32IDX_%1
    lastdw 6|((__R32IDX_%1)<<3), %3
  %else
    %error ERROR_BAD_R32 %1
    times -1 nop
  %endif
%endm
%macro fixpre_movzx_byte 3  ; Example: `fixpre_movzx_byte ecx,cs,-pmodewk+_pm_pampagemax' --> movzx ecx,byte [cs:-pmodewk+_pm_pampagemax]'.
  ; Diff: TASM encodes the o32 == 0x66 prefix, then the segment prefix, NASM does it the other way round.
  o32
  %2
  dw 0xb60f
  %ifdef __R32IDX_%1
    lastdw 6|((__R32IDX_%1)<<3), %3
  %else
    %error ERROR_BAD_R32 %1
    times -1 nop
  %endif
%endm

; --- Macros for building relocations.

%macro reloc_seg 2  ; Example: reloc_seg pmodewk, PMODE_TEXT
  align 0x10, db 0
  %1:
  %assign __seg_base $-exe_image
  %2 equ ($-exe_image)>>4
%endm

%define __reloc_count_z 0  ; Number of relocations in the segment at the beginning of exe_image (e.g. PMODE_TEXT).
%define __reloc_count_nz 0  ; Number of relocations in the segments not at the beginning of exe_image (e.g. pmode16).
%macro __set_reloc 3  ; Internal helper.
  %if __seg_base
    __reloc_nz_ofs_%1 equ (%3)-exe_image-__seg_base
    __reloc_nz_seg_%1 equ __seg_base>>4
  %else
    __reloc_z_ofs_%1 equ (%3)-exe_image-__seg_base
    __reloc_z_seg_%1 equ __seg_base>>4
  %endif
  %assign __reloc_count_%2 %1+1
%endm
%macro __reloc 1  ; Internal helper.
  %if __seg_base
    __set_reloc __reloc_count_nz, nz, %1
  %else
    __set_reloc __reloc_count_z, z, %1
  %endif
%endm
%macro reloc 1+
  %1
  __reloc $-2
%endm
%macro reloc2 1+
  %1
  __reloc $-4
%endm

%macro __emit_reloc 1  ; Internal helper. %1 is the unsigned integer value of __reloci.
  dw __reloc_ofs_%1, __reloc_seg_%1
  %assign __reloci __reloci+1
%endm
%macro emit_relocs 1  ; %2 is count limit.
  %assign __reloc_limit %1
  %assign __reloci 0
  %rep %1
    __emit_reloc __reloci
  %endrep
%endm

%macro __finalize_reloc_zero 1  ; Internal helper. %3 is the unsigned integer value of destination __relocj.
  __reloc_ofs_%1 equ 0
  __reloc_seg_%1 equ 0
  %assign __relocj __relocj+1
%endm
%macro __finalize_reloc 3  ; Internal helper. %1 is nz or z; %2 is the unsigned integer value of source __reloci; %3 is the unsigned integer value of destination __relocj.
  __reloc_ofs_%3 equ __reloc_%1_ofs_%2
  __reloc_seg_%3 equ __reloc_%1_seg_%2
  %assign __reloci __reloci+1
  %assign __relocj __relocj+1
%endm
%macro finalize_relocs 0
  %assign __reloc_count __reloc_count_nz+__reloc_count_z
  %if __reloc_limit<__reloc_count
    ; Solution: update the count in `emit_relocs' to the 2nd number printed below.
    %error ERROR_TOO_MANY_RELOCS __reloc_limit, change it to at least: emit_count __reloc_count
    times -1 nop
  %endif
  %define __relocj 0
  %define __reloci 0
  %rep __reloc_count_nz  ; Emit relocations with nonero segment first. This is to imitate the relocation order of TASM+TLINK in PMODE/W 1.33.
    __finalize_reloc nz, __reloci, __relocj
  %endrep
  %define __reloci 0
  %rep __reloc_count_z
    __finalize_reloc z, __reloci, __relocj
  %endrep
  NRELOC equ __relocj
  %if __reloc_limit>__relocj
    %rep __reloc_limit-__relocj
      __finalize_reloc_zero __relocj
    %endrep
  %endif
%endm

; --- Load-time configuration.
;
; PMODE/W also has load-time configuration which can be changed using e.g. a
; hex editor after compilation. Load-time configuration defaults are stored in
; the source code in 3 places:
;
; * pmodew_config in pmwca.nasm and pmwcax.nasm: used in the compressed pmodew.exe (-DUNC=0 -DVARTYPE=1).
; * pmodew_config in pmodew.nasm: used in the uncompressed pmodewv.exe (-DUNC=1 -DVARTYPE=1).
; * PM_... constants in pmodew.nasm: used with -DVARTYPE=2.
;
; These values are will be copied to _pm_config_except_for_lowmin and
; _pm16_lowmin when the .exe payload is loaded by _openexe2, and then used
; from there.

%macro pm_default 2
  %ifndef %1  ; If %1 is defined, it must be defined to itself, e.g. `%define PM_PAGETABLES PM_PAGETABLES', then the value can be set with `PM_PAGETABLES equ 1'.
    %define %1 %1
    %1 equ %2
  %endif
%endm

; This NASM macro workaround is unfortunately verbose. But there is now
; easier way to make `%define PM_MAXEXTMEM 0x10000' and `nasm
; -DPM_MAXEXTMEM=0x10000' work.
%ifdef PM_PAGETABLES
  $PM_PAGETABLES equ PM_PAGETABLES
  %define PM_PAGETABLES PM_PAGETABLES
%endif
%ifdef PM_SELECTORS
  $PM_SELECTORS equ PM_SELECTORS
  %define PM_SELECTORS PM_SELECTORS
%endif
%ifdef PM_RMSTACKLEN
  $PM_RMSTACKLEN equ PM_RMSTACKLEN
  %define PM_RMSTACKLEN PM_RMSTACKLEN
%endif
%ifdef PM_PMSTACKLEN
  $PM_PMSTACKLEN equ PM_PMSTACKLEN
  %define PM_PMSTACKLEN PM_PMSTACKLEN
%endif
%ifdef PM_RMSTACKS
  $PM_RMSTACKS equ PM_RMSTACKS
  %define PM_RMSTACKS PM_RMSTACKS
%endif
%ifdef PM_PMSTACKS
  $PM_PMSTACKS equ PM_PMSTACKS
  %define PM_PMSTACKS PM_PMSTACKS
%endif
%ifdef PM_CALLBACKS
  $PM_CALLBACKS equ PM_CALLBACKS
  %define PM_CALLBACKS PM_CALLBACKS
%endif
%ifdef PM_MODE
  $PM_MODE equ PM_MODE
  %define PM_MODE PM_MODE
%endif
%ifdef PM_PAMPAGEMAX
  $PM_PAMPAGEMAX equ PM_PAMPAGEMAX
  %define PM_PAMPAGEMAX PM_PAMPAGEMAX
%endif
%ifdef PM_CRAP
  $PM_CRAP equ PM_CRAP
  %define PM_CRAP PM_CRAP
%endif
%ifdef PM_OPTIONS
  $PM_OPTIONS equ PM_OPTIONS
  %define PM_OPTIONS PM_OPTIONS
%endif
%ifdef PM_MAXEXTMEM
  $PM_MAXEXTMEM equ PM_MAXEXTMEM
  %define PM_MAXEXTMEM PM_MAXEXTMEM
%endif
%ifdef PM_LOWMIN
  $PM_LOWMIN equ PM_LOWMIN
  %define PM_LOWMIN PM_LOWMIN
%endif

%ifdef SPE_EntryPoint  ; Load-time configuration default values for the simple PE builder. The program may override each setting with a `%define'.
  %if INT1B
    CALLBACKS1 equ 1
    PMSTACKS1  equ 1
  %else
    CALLBACKS1 equ 0
    PMSTACKS1  equ 0
  %endif

  ; The defaults later below would also work, but this uses less memory.
  pm_default	PM_MAXEXTMEM,	64<<20		; 64 MiB. Maximum extended memory to allocate, in bytes.
  pm_default	PM_PAGETABLES, (PM_MAXEXTMEM+0x3fffff)>>22  ; Number of page tables under VCPI. Each page table makes 4 MiB of memory available.
  pm_default	PM_SELECTORS,	4		; Maximum number of selectors under VCPI/XMS/raw. Minimum working value is 4.
  pm_default	PM_RMSTACKLEN,	0x100>>4	; Default: dw 0x40. Real-mode stack length, in para (10h bytes). Will be multipled with .rmstacks. Value matters, 0x100 bytes should be enough.
  pm_default	PM_PMSTACKLEN,	0x100>>4	; Default: dw 0x80. Protected-mode stack length, in para (10h bytes). Will be multipled with .pmstacks, so value doesn't matter.
  pm_default	PM_RMSTACKS,	1		; Real-mode stack nesting. Minimum working value is 1.
  pm_default	PM_PMSTACKS,	PMSTACKS1	; Protected-mode stack nesting. Minimum working value is 0.
  pm_default	PM_CALLBACKS,	CALLBACKS1	; Number of real-mode callbacks.
  pm_default	PM_MODE,	0		; Mode bits. mode&1 means: detect VCPI before DPMI.
  pm_default	PM_PAMPAGEMAX,	0		; Maximum number of physical address mapping pages. Not relevant, our PMODE/W has the feature disabled (-DINT3108FUNC=1).
  pm_default	PM_OPTIONS,	0		; Option bits. options&1 means: display copyright message.
%endif

; Load-time configuration default values.
; Used for (-DUNC=1 -DVARRTYPE=1) via pmodew_config below.
; Used for -DVARTYPE=2 via _openexe2_vartype_2.
pm_default	PM_PAGETABLES,	4
pm_default	PM_SELECTORS,	100h
pm_default	PM_RMSTACKLEN,	40h
pm_default	PM_PMSTACKLEN,	80h
pm_default	PM_RMSTACKS,	8
pm_default	PM_PMSTACKS,	8
pm_default	PM_CALLBACKS,	20h
pm_default	PM_MODE,	1
pm_default	PM_PAMPAGEMAX,	1
pm_default	PM_CRAP,	0
pm_default	PM_OPTIONS,	1
pm_default	PM_MAXEXTMEM,	7fffffffh
pm_default	PM_LOWMIN,	0

%macro emit_pmodew_config 0
  pmodew_config:  ; Default configuration for PMODE/W. Read manually from the beginning of the MZ .exe image (hdrsize<<<4).
  .pagetables:	db PM_PAGETABLES	; @0:   db 4. Number of page tables under VCPI. Each page table makes 4 MiB of memory available. _pm_pagetables
  .selectors:	dw PM_SELECTORS		; @1:   dw 100h. Maximum number of selectors under VCPI/XMS/raw. _pm_selectors
  .rmstacklen:	dw PM_RMSTACKLEN	; @3:   dw 40h. Real-mode stack length, in para (10h bytes). _pm_rmstacklen
  .pmstacklen:	dw PM_PMSTACKLEN	; @5:   dw 80h. Protected-mode stack length, in para (10h bytes). _pm_pmstacklen
  .rmstacks:	db PM_RMSTACKS		; @7:   db 8. Real-mode stack nesting. _pm_rmstacks
  .pmstacks:	db PM_PMSTACKS		; @8:   db 8. Protected-mode stack nesting. _pm_pmstacks
  .callbacks:	db PM_CALLBACKS		; @9:   db 20h. Number of real-mode callbacks. _pm_callbacks
  .mode:	db PM_MODE		; @0ah: db 1. Mode bits. mode&1 means: detect VCPI before DPMI. _pm_mode
  .pampagemax:	db PM_PAMPAGEMAX	; @0bh: db 1. Maximum number of physical address mapping pages. Also called as .pamapping. _pm_pampagemax
  .crap:	dw PM_CRAP		; @0ch: dw 0. Unused. _pm_crap
  .options:	db PM_OPTIONS		; @0eh: db 1. Option bits. options&1 means: display copyright message. _pm_options
  .maxextmem:	dd PM_MAXEXTMEM		; @0fh: dd 7fffffffh. Maximum extended memory to allocate, in bytes. _pm_maxextmem
  .lowmin:	dw PM_LOWMIN		; @13h: dw 0. Amount of low (below the first 1 MiB) memory to try and save. Loaded by _openexe2 to somewhere else. _pm16_lowmin
  .end:		; @15h.
%endm
pmodew_config._size equ 15h

; --- DOS .exe header.

bits 16
cpu 386

HDRSIZE equ 0x20
%if UNC && LOADSPE
  ; !! TODO(pts): Decrease .NumberOfRvaAndSizes from 16 to 10, save 6*8 bytes, increase _MAX_UNC_PE_SECTIONS by 1.
  %if FEWRELOCS && INT1B==0 && INT33==0
    _MAX_UNC_PE_SECTIONS equ 3  ; 20 MZ .exe relocations use 20*4 bytes, which take away 2 PE section definitions (0x28 bytes each).
  %else
    _MAX_UNC_PE_SECTIONS equ 2  ; 22 or 26 MZ .exe relocations use 22*4 or 26*4 bytes, which take away 3 PE section definitions (0x28 bytes each).
  %endif
  RELOCPOS equ 0x200-5*0x28+_MAX_UNC_PE_SECTIONS*0x28
  RELOC_LIMIT equ (0x200-RELOCPOS)>>2
%else
  RELOCPOS equ 0x3e
  RELOC_LIMIT equ 32  ; Increase this limit if you add many more relocations. PMODE/W 1.33 has 26 with LOADSPE==0 (default).
%endif
STACKSIZE equ 0x400  ; Stub stack size in byte. Keep this >=0x40.

exe_header:  ; DOS .exe header: http://justsolve.archiveteam.org/wiki/MS-DOS_EXE
; load module length == 0x3f6e.
.signature:	db 'MZ'
.lastsize:	dw (exe_end-exe_header)&0x1ff  ; Length of load module mod 200H.
.nblocks:	dw (exe_end-exe_header+0x1ff)>>9  ; Number of 200H pages in load module.
.nreloc:	dw NRELOC  ; Number of relocation items; no relocations.
.hdrsize:	dw HDRSIZE  ; Size of header in paragraphs.
;.minalloc:	dw ((mem_end-exe_image+0xf)>>4)-((exe_end-exe_header+0x1ff)>>9<<5)+HDRSIZE  ; Minimum number of paragraphs required above load mod.  ; This would be the correct formula.
.minalloc:	dw ((((exe_end-exe_image)&0xf)+0xf)>>4)+((STACKSIZE+1)>>4)  ; Minimum number of paragraphs required above load mod.  ; This implements the incorrect (but large enough to be safe) formula used by TLINK 2.0--7.0.
.maxalloc:	dw -1  ; Maximum number of paragraphs required above load mod.
.ss:		dw pmstack  ; Offset of stack segment in load module.
.sp:		dw STACKSIZE  ; Initial value of SP.
.checksum:	dw 0  ; Checksum.
.ip:		dw -pmodewe+_pm16start  ; Initial value of IP.
.cs:		dw pmcode16  ; Offset of code segment within load module (segment).
.relocpos:	dw RELOCPOS  ; File offset of first relocation item.
.noverlay:	dw 0  ; Overlay number.

.one:		dw 1  ; Seems to be 1 for TLINK 2.0--

%if UNC && LOADSPE
pm_default SPE_ImageBase, 0x400000
%ifndef SPE_EntryPoint
  pm_default SPE_AddressOfEntryPoint, '????'
%endif
times 0x20-($-exe_header) db 0
emit_pmodew_config
db 'PMODE/W'  ; Signature. Unchecked.
times 0x3c-($-exe_header) db 0  ; Empty.
pehdr_fofs_ptr:
%if SPEDOSONLY
	dd pehdr-exe_header+1  ; The +1 (== 0x41) makes Windows, Wine and static analysis tools recognize the .exe as a DOS .exe (rather than a Win32 .exe). 32-bit i386 Windows, OS/2 >=2.0 DOS window and DOS will run it using the embedded PMODE/W. Wine and 64-bit Windows won't run it.
%else
	dd pehdr-exe_header  ; 0x40 == 40h == 64.
%endif
pe:
.IMAGE_FILE_RELOCS_STRIPPED equ 1
.IMAGE_FILE_EXECUTABLE_IMAGE equ 2
.IMAGE_FILE_LINE_NUMS_STRIPPED equ 4
.IMAGE_FILE_LOCAL_SYMS_STRIPPED equ 8
.IMAGE_FILE_BYTES_REVERSED_LO equ 0x80  ; Deprecated, shouldn't be specified.
.IMAGE_FILE_32BIT_MACHINE equ 0x100
.IMAGE_FILE_DEBUG_STRIPPED equ 0x200
.IMAGE_FILE_DLL equ 0x2000  ; Shouldn't be specified for .exe.
pehdr:  ; @0x40.
; This below is not a perfectly valid PE header, it's just an unfinished
; example template of how a real PE header supported by the simple PE loader
; would look like.
IMAGE_NT_HEADERS:  ; ..@0x40.
..@0x40:
.Signature: dd 'PE'
IMAGE_FILE_HEADER:
.Machine: dw 0x14c  ; CPU type == ISA == i386.
.NumberOfSections: dw (IMAGE_SECTION_HEADER_end-IMAGE_SECTION_HEADER)/0x28  ; 1 here. Valid valus are 1..5 for the simple PE loader. The upper limit is less (_MAX_UNC_PE_SECTIONS) for -DUNC.
.TimeDateStamp: dd 0  ; 0 works as an unset timestamp.
.PointerToSymbolTable: dd 0
.NumberOfSymbols: dd 0
.SizeOfOptionalHeader: dw IMAGE_OPTIONAL_HEADER_end-IMAGE_OPTIONAL_HEADER  ; @0x54. 0xe0. Depends on .NumberOfRvaAndSizes.
.Characteristics: dw pe.IMAGE_FILE_EXECUTABLE_IMAGE|pe.IMAGE_FILE_LINE_NUMS_STRIPPED|pe.IMAGE_FILE_LOCAL_SYMS_STRIPPED|pe.IMAGE_FILE_32BIT_MACHINE|pe.IMAGE_FILE_DEBUG_STRIPPED|pe.IMAGE_FILE_BYTES_REVERSED_LO  ; 0x39e. Doesn't have pe.IMAGE_FILE_RELOCS_STRIPPED or pe.IMAGE_FILE_DLL.
IMAGE_OPTIONAL_HEADER:  ; @0x58.
.Magic: dw 0x10b  ; i386.
.MajorLinkerVersion: db 6  ; Even 2 could work.
.MinorLinkerVersion: db 0
.SizeOfCode: dd 0  ; 0 works.
.SizeOfInitializedData: dd 0  ; 0 works.
.SizeOfUninitializedData: dd 0   ; 0 works.
.AddressOfEntryPoint:  ; RVA. The actual virtual memory address where execution starts is .ImageBase.AddressOfEntryPoint.
%ifdef SPE_EntryPoint
		dd (SPE_EntryPoint)-(SPE_ImageBase)
%else
		dd SPE_AddressOfEntryPoint
%endif
.BaseOfCode: dd 0x1000
.BaseOfData: dd 0x1000
.ImageBase: dd SPE_ImageBase  ; 0x400000 is the typical, most compatible value.
.SectionAlignment: dd 0x1000
.FileAlignment: dd 0x200
.MajorOperatingSystemVersion: dw 4  ; 1 would be equally good.
.MinorOperatingSystemVersion: dw 0
.MajorImageVersion: dw 0
.MinorImageVersion: dw 0
.MajorSubsystemVersion: dw 3
.MinorSubsystemVersion: dw 10  ; (3, 1) works on Windows NT 3.1. (4, 0) needs Windows NT 4.0 or later, or Windows 95 or later.
.Win32VersionValue: dd 0  ; reserved1.
.SizeOfImage:  ; .VirtualAddress+.VirtualSize of the last-in-memory section, minus .ImageBase. Must be a multiple of SectionAlignment.
%ifdef SPE_bssend  ; A label.
		dd (SPE_bssend-SPE_sections+0xfff)&~0xfff  ; Correct for a single section.
%elifdef SPE_end  ; A label.
		dd (SPE_end-SPE_sections+0xfff)&~0xfff  ; Correct for a single section.
%else
		dd '????'
%endif
.SizeOfHeaders: dd 0x200  ; Windows NT 3.1 and 4.0 require that (.SizeOfHeaders+0xfff)&0xfff == IMAGE_SECTION_HEADER_0.VirtualAddress, and for each subsequent section, .VirtualAddress == (prev.VirtualAddress+prev.VirtualSize+0xfff)^~0xfff, i.e. there are no memory gaps.
.CheckSum: dd 0
.Subsystem: dw 3  ; NT subsystem. Windows CUI. The Windows GUI would be 2.
.DllCharacteristics: dw 0
.SizeOfStackReserve: dd 0x1000  ; Must be at least .SizeOfStackCommit. Must be a multiple of 0x1000.
.SizeOfStackCommit: dd 0x1000  ; 4 KiB of stack is the minimum. Must be a multiple of 0x1000.
.SizeOfHeapReserve: dd 0  ; Must be at least .SizeOfHeapCommit. Must be a multiple of 0x1000.
.SizeOfHeapCommit: dd 0  ; HeapAlloc(...) uses it. An empty heap (== 0) is OK. Must be a multiple of 0x1000.
.LoaderFlags: dd 0  ; Also address of TLS index.
.NumberOfRvaAndSizes: dd (IMAGE_DATA_DIRECTORY_end-IMAGE_DATA_DIRECTORY)>>3  ; 16. 16 is the most compatible, and the simple PE loader requires it (this can be changed). 10 works with all versions of Windows, Wine and recent ReactOS. !! TODO(pts): Make the simple PE loader support any value (between 6 and 16).
IMAGE_DATA_DIRECTORY:
IMAGE_DIRECTORY_ENTRY_EXPORT:  ; 0. Export.
..@0x0b8: dd 0, 0
IMAGE_DIRECTORY_ENTRY_IMPORT:  ; 1. Import.
..@0x0c0: dd 0, 0  ; The simple PE loader ignores it. If filled no nonzero, the Win32 PE loader will do the DLL imports based on it.
IMAGE_DIRECTORY_ENTRY_RESOURCE:  ; 2. Resource.
..@0x0c8: dd 0, 0
IMAGE_DIRECTORY_ENTRY_EXCEPTION:  ; 3. Exception.
..@0x0d0: dd 0, 0
IMAGE_DIRECTORY_ENTRY_SECURITY:  ; 4. Security. Certificates.
..@0x0d8: dd 0, 0
IMAGE_DIRECTORY_ENTRY_BASERELOC:  ; 5. Base relocation.
%ifdef SPE_end
		dd 0, 0
%else
..@0x0e0: dd '?????', '?????'  ; Set both to 0 if you don't have any relocations.
%endif
IMAGE_DIRECTORY_ENTRY_DEBUG:  ; 6. Debug.
..@0x0e8: dd 0, 0
IMAGE_DIRECTORY_ENTRY_ARCHITECTURE:  ; 7. Description. Architecture.
..@0x0f0: dd 0, 0
IMAGE_DIRECTORY_ENTRY_GLOBALPTR:  ; 8. Global pointer. Special.
..@0x0f8: dd 0, 0
IMAGE_DIRECTORY_ENTRY_TLS:  ; 9. Thread local storage.
..@0x100: dd 0, 0
%if 1 ; Changing this to `%if 0' would still work all versions of Windows, Wine and recent ReactOS.
IMAGE_DIRECTORY_ENTRY_LOAD_CONFIG:  ; 10. Load configuration.
..@0x108: dd 0, 0
IMAGE_DIRECTORY_ENTRY_BOUND_IMPORT:  ; 11. Bound import.
..@0x110: dd 0, 0
IMAGE_DIRECTORY_ENTRY_IAT:  ; 12. Import address table.
..@0x118: dd 0, 0
IMAGE_DIRECTORY_ENTRY_DELAY_IMPORT:  ; 13. Delay Import.
..@0x120: dd 0, 0
IMAGE_DIRECTORY_ENTRY_COM_DESCRIPTOR:  ; 14. COM descriptor. CLR runtime. Nonzero for .NET .exe.
..@0x128: dd 0, 0
IMAGE_DIRECTORY_ENTRY_RESERVED:  ; 15. Reserved.
..@0x130: dd 0, 0
%endif
..@0x138:  ; This mill change to @0x108 if we remove 16-10 entries.
IMAGE_DATA_DIRECTORY_end:  ; @0x138.
IMAGE_OPTIONAL_HEADER_end:  ; @0x138.
IMAGE_SECTION_HEADER:  ; @0x138.
IMAGE_SECTION_HEADER_0:  ; @0x138. 0x28 == 40 bytes.
.Name:			db '.text', 0, 0, 0
.VirtualSize:  ; Number of bytes to map to memory. Can be odd, no need to align it.
%ifdef SPE_bssend  ; A label.
			dd SPE_bssend-SPE_sections  ; Correct for a single section.
%elifdef SPE_end
			dd SPE_end-SPE_sections  ; Correct for a single section.
%else
			dd  '????'
%endif
.VirtualAddress:	dd  0x1000  ; RVA. This is the minimum value. It must be a positive multiple of .SectionAlignment. Actual virtual memory address is .ImageBase+.section.VirtualAddress.
.SizeOfRawData:  ; Number of bytes to load from file offset .PointerToRawData. Must be a multiple of .FileAlignment except for the last section (where it can match .VirtualAddrees).
%ifdef SPE_end
			dd SPE_end-SPE_sections  ; Correct for a single section.
%else
			dd  '????'
%endif
.PointerToRawData:	dd SPE_sections-exe_header  ; Must be a multiple of .FileAlignment.
.PointerToRelocations:	dd 0
.PointerToLineNumbers:	dd 0
.NumberOfRelocations:	dw 0
.NumberOfLineNumbers:	dw 0
.Characteristics:	dd 0xe0000060 ;  .Characteristics == (CODE|INIT_DATA|READABLE|WRITABLE_EXECUTABLE).
; Typical characteristics for section .text (CODE): 0x60000020 == (CODE|EXECUTABLE|READABLE).
; Typical characteristics for section .data (DATA) and .idata: 0xc0000040 == (INIT_DATA|READABLE|WRITABLE).
; Typical characteristics for section .reloc: 0x50000040 == (INIT_DATA|SHARED|READABLE).
IMAGE_SECTION_HEADER_end:
IMAGE_SECTION_HEADER_1: equ $+0*0x28  ; @0x160. 0x28 == 40 bytes.
IMAGE_SECTION_HEADER_2: equ $+1*0x28  ; @0x198. 0x28 == 40 bytes.
IMAGE_SECTION_HEADER_3: equ $+2*0x28  ; @0x1b0. 0x28 == 40 bytes.
IMAGE_SECTION_HEADER_4: equ $+3*0x28  ; @0x1d8. 0x28 == 40 bytes. The simple PE loader supports 1..5 sections.
after_pehdr:
%else
; This value seems to depend on the TLINK version number.
;
; * TLINK 2.0: dw 0x20fb, 0x6a72
; * TLINK 3.0--4.01 (last tlink.exe running on a 8086, we imitate this): dw 0x30fb, 0x726a
; * TLINK 5.0--5.1--??: (used by pmw133src/PMODEW.EXE): dw 0x50fb, 0x726a
; * TLINK 7.0: dw 0x61fb, 0x726a
.linker_id:	dw 0x30fb, 0x726a  ; We imitate TLINK 3.0--4.01.
%endif

.padding1:	times RELOCPOS-($-exe_header) db 0

.relocs:  ; (offset, offset) pairs with exe_image as the base.
		emit_relocs RELOC_LIMIT
.relocs.end:

.padding2:	times (HDRSIZE<<4)-($-exe_header) db 0

exe_image:

; --- Based on pmodewk.asm.

; PMODE/W DPMI/VCPI/XMS/raw protected mode interface kernel.
; Copyright (c) 1994, 1996, Tran (a.k.a. Thomas Pytel).

; PMODE_TEXT equ 0  ; For pmodew.exe.
; pmodewk:  ; equ exe_image
reloc_seg pmodewk, PMODE_TEXT  ; PMODE_TEXT segment word public use16 'CODE'
;assume  cs:PMODE_TEXT, ds:PMODE_TEXT

%if UNC && LOADSPE==0  ; Must be at te beginning of the .exe image, _openexe2 with VARTYPE==1 (default) is looking for it there.
emit_pmodew_config
padding_after_config: align 2, db 0
%endif

; --- Back to pmodewk.asm.
;
; DATA
;
SELCODE         equ 08h                   ; PMODE_TEXT code selector
SELDATA         equ 10h                   ; selector of entire memory space
SELZERO         equ 18h                   ; callback DS selector
SELCALLBACKDS   equ 20h                   ; callback DS selector
SELREAL         equ SELDATA               ; real mode attributes selector
SELVCPICODE     equ 28h                   ; VCPI call code selector
SEL40           equ 40h                   ; selector 40h of BIOS data table
SELVCPITSS      equ 48h                   ; TSS selector for VCPI

SYSSELECTORS    equ 10                    ; number of system selectors in GDT
FREESELECTORS   equ SYSSELECTORS+4        ; base of free selectors

%define ANY 0  ; In TASM, `db ANY' becomes `db ?'. In NASM, it becomes `db 0'.

align 2, db 0

vcpistrucaddx   dd      -pmodewk+vcpi_cr3    ; VCPI switch structure linear address
oldint15vector  dw      -pmodewk+int15       ; preserved INT 15h vector
		reloc dw PMODE_TEXT
int3vector      dd      -pmodewk+intrmatrix+3; protected mode INT 3 vector
		dw      SELCODE

selzero         dw      SELZERO         ; for immediate segreg loading
selcallbackds   dw      SELCALLBACKDS   ; for immediate segreg loading
seldata         dw      SELDATA         ; for immediate segreg loading

dpmiepmode      dd      ANY             ; DPMI enter pmode addx
codebase        dd      ANY             ; PMODE_TEXT linear address
vcpiswitchstack dd      ANY             ; VCPI temporary mode switch stack

pmstacklen      dd      ANY             ; protected mode stack length in bytes
pmstackbase     dd      ANY             ; bottom of protected mode stack area
pmstacktop      dd      ANY             ; top of protected mode stack area
callbackbase    dd      ANY             ; base of real mode callbacks
callbackseg     dw      ANY             ; segment of callbacks

rawextmemused   dw      0               ; raw extended memory used in K

int1ccallback   dd      ANY             ; INT 1Ch callback address
int23callback   dd      ANY             ; INT 23h callback address
int24callback   dd      ANY             ; INT 24h callback address

rmstackbase     dw      ANY             ; bottom of real mode stack area
rmstacktop      dw      ANY             ; top of real mode stack area

pmstackesp      dd      ANY             ; for functions 0300h, 0301h, 0302h
pmstackss       dw      ANY

gdtfree         dw      8*FREESELECTORS ; base of free selectors
gdtseg          dw      ANY             ; segment of GDT
gdtlimit        dw      ANY             ; GDT limit
gdtbase         dd      ANY             ; GDT base

idtlimit        dw      7ffh            ; IDT limit
idtbase         dd      ANY             ; IDT base
rmidtlimit      dw      3ffh            ; real mode IDT limit
rmidtbase       dd      0               ; real mode IDT base

rmtopmswrout    dw      -pmodewk+v_rmtopmsw  ; addx of real to protected routine
pmtormswrout    dd      -pmodewk+v_pmtormsw  ; addx of protected to real routine

processortype   db      ANY             ; processor type
pmodetype       db      2               ; protected mode type
picslave        db      70h             ; PIC slave base interrupt
picmaster       db      8               ; PIC master base interrupt

defirqintnum    db      08h,09h,0ah,0bh,0ch,0dh,0eh,0fh
		db      70h,71h,72h,73h,74h,75h,76h,77h

cleanuptype     db      6
pagetablenum    db      ANY
oldpicmasks     dw      ANY

pagetablebase   dd      ANY             ; base of page table area
pagetabletop    dd      ANY             ; top of page table area
pagetablefree   dd      ANY
pagetablepages  dd      ANY

; These must have the same size and order as pmodew_config.
_pm_config_except_for_lowmin:
_pm_pagetables  db      ANY
_pm_selectors   dw      ANY
_pm_rmstacklen  dw      ANY
_pm_pmstacklen  dw      ANY
_pm_rmstacks    db      ANY
_pm_pmstacks    db      ANY
_pm_callbacks   db      ANY
_pm_mode        db      ANY
_pm_pampagemax  db      ANY
_pm_crap        dw      ANY
_pm_options     db      ANY
_pm_maxextmem   dd      ANY
;_pm16_lowmin   dw      ANY  ; _pm16_lowmin is in segment pmode16.
_pm_config_except_for_lowmin.end:  ; == _pm_config_except_for_lowmin+13h

tempd0:                                 ; temporary variables
tempw0:
tempb0          db      ANY
tempb1          db      ANY
tempw1:
tempb2          db      ANY
tempb3          db      ANY
tempd1:
tempw2:
tempb4          db      ANY
tempb5          db      ANY
tempw3:
tempb6          db      ANY
tempb7          db      ANY

extmemsize      dd      0
extmembase      dd      ANY
extmemlast      dd      ANY

%if INT3108FUNC
pampagebase     dd      ANY
pampagetop      dd      ANY
pampagemask     dw      ANY
%endif

xms_callip      dw      ANY             ; XMS driver offset
xms_callcs      dw      ANY             ; XMS driver segment
xms_handle      dw      ANY
xms_mem         dw      0  ; Amount of memory in KiB available for allocation using XMS.

irqhookmap      dw      0

vcpi_memused    db      0, ANY          ; bit 0: XMS used

vcpi_cr3        dd      ANY             ; VCPI CR3 value for protected mode
vcpi_gdtaddx    dd      -pmodewk+gdtlimit    ; linear addx of GDT limit and base
vcpi_idtaddx    dd      -pmodewk+idtlimit    ; linear addx of IDT limit and base
vcpi_selldt     dw      0               ; LDT selector for protected mode
vcpi_seltss     dw      SELVCPITSS      ; TSS selector for protected mode
vcpi_eip        dd      -pmodewk+v_rmtopmswpm; destination EIP in protected mode
vcpi_cs         dw      SELCODE         ; destination CS in protected mode

vcpi_calleip    dd      ANY             ; VCPI protected mode call offset
vcpi_callcs     dw      SELVCPICODE     ; VCPI protected mode call selector

inittbl         dw      -pmodewk+r_init,-pmodewk+x_init,-pmodewk+v_init,-pmodewk+d_init
cleanuptbl      dw      -pmodewk+cleanup0,-pmodewk+cleanup1,-pmodewk+cleanup2,-pmodewk+cleanup3

int31functbl    dw      0900h,0901h,0902h
		dw      0000h,0001h,0002h,0003h,0006h,0007h,0008h,0009h
		dw      0200h,0201h,0204h,0205h
		dw      0305h,0306h
%if GETVERSION
		dw	0400h
%endif
		dw      000ah,000bh,000ch
		dw      0100h,0101h,0102h
		dw      0300h,0301h,0302h
		dw      0303h,0304h
%if FREEMEMINFO
		dw      0500h
%endif
		dw	0501h,0502h,0503h
		dw      0600h,0601h,0702h,0703h

%if INT3108FUNC
		dw      0800h,0801h
%endif

%if EXCEPTIONS
		dw      0202h,0203h
%endif

		dw      05ffh

INT31FUNCNUM    equ ($ - int31functbl) / 2

int31routtbl    dw      -pmodewk+int310900,-pmodewk+int310901,-pmodewk+int310902
		dw      -pmodewk+int310000,-pmodewk+int310001,-pmodewk+int310002,-pmodewk+int310003
		dw      -pmodewk+int310006,-pmodewk+int310007,-pmodewk+int310008,-pmodewk+int310009
		dw      -pmodewk+int310200,-pmodewk+int310201,-pmodewk+int310204,-pmodewk+int310205
		dw      -pmodewk+int310305,-pmodewk+int310306
%if GETVERSION
		dw	-pmodewk+int310400
%endif
		dw      -pmodewk+int31000a,-pmodewk+int31000b,-pmodewk+int31000c
		dw      -pmodewk+int310100,-pmodewk+int310101,-pmodewk+int310102
		dw      -pmodewk+int310300,-pmodewk+int310301,-pmodewk+int310302
		dw      -pmodewk+int310303,-pmodewk+int310304
%if FREEMEMINFO
int3105routtbl:
		dw      -pmodewk+int310500nomem
%else
int3105routtbl: equ $-2
%endif
		dw	-pmodewk+int31fail,-pmodewk+int31fail,-pmodewk+int31fail
		dw      -pmodewk+int31ok,-pmodewk+int31ok,-pmodewk+int31ok,-pmodewk+int31ok

%if INT3108FUNC
int3108routtbl  dw      -pmodewk+int31ok,-pmodewk+int31ok
%endif

%if EXCEPTIONS
		dw      -pmodewk+int310202,-pmodewk+int310203
%endif

		dw      -pmodewk+int3105ff

%if EXCEPTIONS

align 2, nop
exceptionivect  dw      -pmodewk+intrmatrix + 00h, 0, SELCODE
		dw      -pmodewk+intrmatrix + 01h, 0, SELCODE
		dw      -pmodewk+intrmatrix + 02h, 0, SELCODE
		dw      -pmodewk+intrmatrix + 03h, 0, SELCODE
		dw      -pmodewk+intrmatrix + 04h, 0, SELCODE
		dw      -pmodewk+intrmatrix + 05h, 0, SELCODE
		dw      -pmodewk+intrmatrix + 06h, 0, SELCODE
		dw      -pmodewk+intrmatrix + 07h, 0, SELCODE
		dw      -pmodewk+intrmatrix + 08h, 0, SELCODE
		dw      -pmodewk+intrmatrix + 09h, 0, SELCODE
		dw      -pmodewk+intrmatrix + 0ah, 0, SELCODE
		dw      -pmodewk+intrmatrix + 0bh, 0, SELCODE
		dw      -pmodewk+intrmatrix + 0ch, 0, SELCODE
		dw      -pmodewk+intrmatrix + 0dh, 0, SELCODE
		dw      -pmodewk+intrmatrix + 0eh, 0, SELCODE

exceptionevect  dw      -pmodewk+exception_def, 0, SELCODE
		dw      -pmodewk+exception_def, 0, SELCODE
		dw      -pmodewk+exception_def, 0, SELCODE
		dw      -pmodewk+exception_def, 0, SELCODE
		dw      -pmodewk+exception_def, 0, SELCODE
		dw      -pmodewk+exception_def, 0, SELCODE
		dw      -pmodewk+exception_def, 0, SELCODE
		dw      -pmodewk+exception_def, 0, SELCODE
		dw      -pmodewk+exception_def, 0, SELCODE
		dw      -pmodewk+exception_def, 0, SELCODE
		dw      -pmodewk+exception_def, 0, SELCODE
		dw      -pmodewk+exception_def, 0, SELCODE
		dw      -pmodewk+exception_def, 0, SELCODE
		dw      -pmodewk+exception_def, 0, SELCODE
		dw      -pmodewk+exception_def, 0, SELCODE

exceptionecsize db      0,0,0,0,0,0,0,0,4,0,4,4,4,4,4

abortrmstacktop dw      ANY             ; top of real mode stack for abort

%if SIZEOPT==0
aborts_hexctbl  db      '0123456789ABCDEF'
%endif

aborts_pmwabort:
%if LOADSPE==3 || SHORTMSG
		db      '[PM]: '
%else
		db      '[PMODE/W]: '
%endif
		db	'Abort: ',0

aborts_xception db      'Exception: ',0
aborts_callback db      'No PM stack for callback!',0
aborts_IRQtoPM  db      'No PM stack for IRQ redirection!',0
aborts_INTtoRM  db      'No RM stack for INT redirection!',0
aborts_INT3103  db      'No PM stack for INT 31h AH = 03h!',0

aborts_xerrcode db      'Error code: ',0
aborts_xeax     db      'EAX: ',0
aborts_xebx     db      'EBX: ',0
aborts_xecx     db      'ECX: ',0
aborts_xedx     db      'EDX: ',0
aborts_xesi     db      'ESI: ',0
aborts_xedi     db      'EDI: ',0
aborts_xebp     db      'EBP: ',0
aborts_xesp     db      'ESP: ',0
aborts_xds      db      'DS: ',0
aborts_xes      db      'ES: ',0
aborts_xfs      db      'FS: ',0
aborts_xgs      db      'GS: ',0
aborts_xss      db      'SS: ',0
aborts_xcs      db      'CS: ',0
aborts_xeip     db      'EIP: ',0
aborts_xeflags  db      'EFLAGS: ',0
aborts_xcr0     db      'CR0: ',0
aborts_xcr2     db      'CR2: ',0

aborts_tbl      dw      -pmodewk+aborts_xception, -pmodewk+aborts_callback, -pmodewk+aborts_IRQtoPM
		dw      -pmodewk+aborts_INTtoRM, -pmodewk+aborts_INT3103

%endif

;
; DETECT/INIT CODE
;

intrmatrix:                             ; INT redirectors for all INTs

;
; Get protected mode info
; Out:
;   AX = return code:
;     0000h = successful
;     0001h = no 80386+ detected
;     0002h = system already in protected mode and no VCPI or DPMI found
;     0003h = DPMI - host is not 32bit
;   CF = set on error, if no error:
;     BX = number of paragraphs needed for protected mode data (may be 0)
;     CL = processor type:
;       02h = 80286
;       03h = 80386
;       04h = 80486
;       05h = 80586
;       06h-FFh = reserved for future use
;     CH = protected mode type:
;       00h = raw
;       01h = XMS
;       02h = VCPI
;       03h = DPMI
;
_pm_info:
	multipush dx, si, di, bp, ds, es, bx, cx    ; preserve registers

	push cs                         ; DS = CS (PMODE_TEXT)
	pop ds

	call .detect_processor         ; get processor type

	mov ax,1                        ; error code in case no processor 386+
	cmp cl,3                        ; is processor 386+?
	jae short .04

	jmp .infofail                  ; if no, no VCPI

.04:
	mov [-pmodewk+processortype],cl ; store processor type

	mov ax,4300h                    ; chek for XMS
	int 2fh
	cmp al,80h
	jne short .01

	push es                         ; preserve ES, INT 2Fh destroys it

	mov ax,4310h                    ; get XMS driver address
	int 2fh

	mov [-pmodewk+xms_callip],bx    ; store XMS driver address
	mov [-pmodewk+xms_callcs],es

	mov ah,30h                      ; crap fix for Win95 HIMEM.SYS
	int 21h

	mov ah,8  ; XMS query free extended memory.
	call far [-pmodewk+xms_callip]  ; AX := size of largest free XMS block in KiB; DX := total size of free XMS memory in KiB.
	mov [-pmodewk+xms_mem],ax  ; xms_mem := size of largest free XMS block in KiB.

	pop es                          ; restore ES (buffer segment)

.01:
	test byte [-pmodewk+_pm_mode],1  ; check order of DPMI/VCPI detection
	jz short .infof0

	call .detect_VCPI              ; check for VCPI first
	call .detect_DPMI              ; check for DPMI second
	jmp short .infof2              ; neither found, go on to XMS check

.infof0:
	call .detect_DPMI              ; check for DPMI first
	call .detect_VCPI              ; check for VCPI second

.infof2:
	smsw ax                         ; AX = machine status word
	and ax,strict word 1                        ; is system in protected mode?
	mov al,2                        ; error code in case protected mode
	jnz short .infofail            ; if in protected mode, fail

	cmp word [-pmodewk+xms_mem],0                   ; if XMS present, pmode type is XMS
	seta ch

	mov bx,80h                      ; BX = memory requirement (IDT)

.infof1:
	movzx ax,byte [-pmodewk+_pm_rmstacks]           ; size of real mode stack area
	imul ax,[-pmodewk+_pm_rmstacklen]
	_add bx,ax

	movzx ax,byte [-pmodewk+_pm_pmstacks]           ; size of protected mode stack area
	imul ax,[-pmodewk+_pm_pmstacklen]
	_add bx,ax

	movzx ax,byte [-pmodewk+_pm_callbacks]          ; size of callbacks
	imul ax,25
	add ax,strict word 0fh
	shr ax,4
	_add bx,ax

	mov ax,[-pmodewk+_pm_selectors]            ; size of GDT
	add ax,strict word 1+FREESELECTORS+1
	shr ax,1
	_add bx,ax

	jmp short .infook              ; go to done ok

.infofail:
	multipop cx, bx                       ; restore BX and CX
	stc                             ; carry set, failed
	jmp short .infodone

.infook:
	mov cl,[-pmodewk+processortype]
	mov [-pmodewk+pmodetype],ch                ; store pmode type

	add sp,4                        ; skip BX and CX on stack
	_xor ax,ax                       ; success code, also clear carry flag

.infodone:
	multipop es, ds, bp, di, si, dx           ; restore other registers
	retf                            ; return

.detect_DPMI:                          ; detect a DPMI host
	pop bp                          ; pop return address from stack

	mov ax,1687h                    ; check for DPMI
	int 2fh

	_or ax,ax                        ; DPMI present?
	jnz short .detect_DPMIdone     ; if no, exit routine

	mov al,3                        ; error code in case DPMI not 32bit
	test bl,1                       ; is DPMI 32bit?
	jz .infofail                   ; if no, fail

	mov al,1                        ; error code in case no processor 386+
	cmp cl,3                        ; is processor 386+? (redundant)
	jb .infofail                   ; if no, fail

	mov [-pmodewk+dpmiepmode+0],di   ; store DPMI initial mode switch addx
	mov [-pmodewk+dpmiepmode+2],es

	_mov bx,si                       ; BX = number of paragraphs needed
	mov ch,3                        ; pmode type is 3 (DPMI)

	jmp .infook                    ; go to done ok

.detect_DPMIdone:
	jmp bp                          ; return to calling routine

.detect_VCPI:                           ; detect a VCPI server
	pop bp                          ; pop return address from stack

	_xor ax,ax                       ; get INT 67h vector
	mov es,ax
	mov ax,[es:67h*4]
	or ax,[es:67h*4+2]              ; is vector NULL
	jz short .detect_VCPIdone       ; if yes, no VCPI

	mov ax,0de00h                   ; call VCPI installation check
	int 67h
	_or ah,ah                        ; AH returned as 0?
	jnz short .detect_VCPIdone      ; if no, no VCPI

	mov dx,[-pmodewk+xms_mem]
	_mov cx,dx

	jcxz .02

	mov ah,9  ; Allocate DX KiB of memory using XMS.
	call far [-pmodewk+xms_callip]
	_mov di,dx

%if ($-intrmatrix)<100h
  %assign V ($-intrmatrix)
  %error ERROR_1 V
  times -1 nop
%endif

rmirqvector equ $                            ; backed up real mode IRQ vectors

	_or ax,ax
	jnz short .02

	_xor cx,cx

.02:
	mov ax,0de03h
	int 67h

	movzx esi,cx
	shr esi,2
	lea esi,[esi+edx+3ffh]
	shr esi,10
	inc si

	jcxz .03

	_mov dx,di
	mov ah,0ah  ; XMS free extended memory block.
	call far [-pmodewk+xms_callip]

.03:
	movzx bx,byte [-pmodewk+_pm_pagetables]         ; BX = VCPI page table memory needed
	_cmp bx,si
	jb short .00

	_mov bx,si

.00:
	mov [-pmodewk+pagetablenum],bl

	_xchg bl,bh                      ; 100h paragraphs per page table
	add bx,100h+0ffh+7+80h          ; + page dir + align buf + TSS + IDT

%if ($-rmirqvector)<4*10h
  %error ERROR_2
  times -1 nop
%endif

passupintregs equ $

	mov ch,2                        ; pmode type is 2 (VCPI)

	jmp .infof1                    ; go to figure other memory needed

.detect_VCPIdone:
	jmp bp                          ; return to calling routine

.detect_processor:                     ; get processor: 286, 386, 486, or 586
	_xor cl,cl                       ; processor type 0 in case of exit

	pushf                           ; transfer FLAGS to BX
	pop bx

	_mov ax,bx                       ; try to clear high 4 bits of FLAGS
	and ah,0fh

	push ax                         ; transfer AX to FLAGS
	popf
	pushf                           ; transfer FLAGS back to AX
	pop ax

	and ah,0f0h                     ; isolate high 4 bits
	cmp ah,0f0h
	je short .detect_processordone ; if bits are set, CPU is 8086/8

	mov cl,2                        ; processor type 2 in case of exit

	or bh,0f0h                      ; try to set high 4 bits of FLAGS

	push bx                         ; transfer BX to FLAGS
	popf
	pushf                           ; transfer FLAGS to AX
	pop ax

	and ah,0f0h                     ; isolate high 4 bits
	jz short .detect_processordone ; if bits are not set, CPU is 80286

	inc cx                          ; processor type 3 in case of exit

	multipush eax, ebx              ; preserve 32bit registers

	pushfd                          ; transfer EFLAGS to EBX
	pop ebx

	_mov eax,ebx                     ; try to flip AC bit in EFLAGS
	xor eax,40000h

	push eax                        ; transfer EAX to EFLAGS
	popfd
	pushfd                          ; transfer EFLAGS back to EAX
	pop eax

	_xor eax,ebx                     ; AC bit fliped?
	jz short .detect_processordone2; if no, CPU is 386

	inc cx                          ; processor type 4 in case of exit

	_mov eax,ebx                     ; try to flip ID bit in EFLAGS
	xor eax,200000h

	push eax                        ; transfer EAX to EFLAGS
	popfd
	pushfd                          ; transfer EFLAGS back to EAX
	pop eax

	_xor eax,ebx                     ; ID bit fliped?
	jz short .detect_processordone2; if no, CPU is 486

	multipush ecx, edx

	mov eax,1                       ; get CPU features
	db 0fh, 0a2h                    ; cpuid instruction, for TASM <=3.2

	and ah,0fh

	multipop edx, ecx

	_mov cl,ah                       ; processor type from CPUID

.detect_processordone2:
	multipop ebx, eax               ; restore 32bit registers

.detect_processordone:
	ret                             ; return

;
; Initialize protected mode
; In:
;   ES = real mode segment for protected mode data (ignored if not needed)
; Out:
;   AX = return code:
;     0004h = could not enable A20 gate
;     0005h = DPMI - could not enter 32bit protected mode
;     0006h = DPMI - could not allocate needed selectors
;   CF = set on error, if no error:
;     ESP = high word clear
;     CS = 16bit selector for real mode CS with limit of 64k
;     SS = selector for real mode SS with limit of 64k
;     DS = selector for real mode DS with limit of 64k
;     ES = selector for PSP with limit of 100h
;     FS = 0 (NULL selector)
;     GS = 0 (NULL selector)
;
_pm_init:
	pushad
	push ds
	_mov bp,sp
	cld

	push cs                         ; DS = PMODE_TEXT
	pop ds

	call getrmirqvectors

%if FEWRELOCS  ; Do it without relocation.
	_xor eax,eax
	mov ax,cs                        ; set base addx of PMODE_TEXT
%else
	reloc2 mov eax,PMODE_TEXT        ; set base addx of PMODE_TEXT
%endif

%if ($-passupintregs)<32h+40h
  %error ERROR_3
  times -1 nop
%endif

vcpisstacktop:                          ; top of VCPI mode switch stack

	shl eax,4
	mov [-pmodewk+codebase],eax

	add [-pmodewk+vcpi_gdtaddx],eax            ; adjust addresses for VCPI structure
	add [-pmodewk+vcpi_idtaddx],eax
	add [-pmodewk+vcpistrucaddx],eax

	movzx bx,byte [-pmodewk+pmodetype]              ; jump to appropriate init code
	shl bx,1
	jmp word [-pmodewk+inittbl+bx]

d_init:                                 ; DPMI protected mode init
	call backupints

	pop ds                          ; get original caller DS from stack
	mov ax,1                        ; enter DPMI protected mode
	call far [cs:-pmodewk+dpmiepmode]
	push ds                         ; put DS back onto stack
	jnc short dvxr_init             ; error? if not, go on with init

	mov bx,6                        ; error entering protected mode, set
	cmp ax,strict word 8011h                    ;  error code and abort
	stc
	je short init_done
	dec bx                          ; error code 5, not 6

init_done:                              ; return with return code
	mov [bp+30],bx
	pop ds
	popad
	retf

%if ($-vcpisstacktop)<44
  %error ERROR_4
  times -1 nop
%endif

dvxr_init:                              ; DPMI/VCPI/XMS/raw common init tail
	mov cx,1                        ; allocate selector for return code
	_xor ax,ax
	int 31h
	jnc short .dvxr_initf0

%if EXITCODE
	mov al,0fch                     ; exit(252); Not merging it to `mov ax,...' for better compressibility.
%endif
	mov ah,4ch                      ; could not allocate selector
	int 21h                         ; terminate DOS process

.dvxr_initf0:
	_mov bp,sp                       ; BP = SP for screwing with the stack
	_mov bx,ax                       ; new code descriptor for return

	mov ax,0007h                    ; set base address of calling segment
	mov dx,[bp+36]
	_mov cx,dx
	shl dx,4
	shr cx,12
	int 31h

	inc ax                          ; set selector limit of 64k
	_xor cx,cx
	mov dx,0ffffh
	int 31h

	inc ax                          ; set selector type and access rights
	mov dx,cs                       ; get DPL from current CPL, and access
	lar cx,dx                       ;  rights and type from current CS
	shr cx,8                        ; type is already 16bit code segment
	int 31h

.dvxr_initdone:
	mov [bp+36],bx                  ; store selector in return address
	_xor bx,bx                       ; init successful, carry clear
	jmp init_done

backupints:
	push es

	push cs
	pop es

	_xor cx,cx
	mov ds,cx                       ; back up real mode INT vectors

	mov di,-pmodewk+rmintvector
	_xor si,si
	mov ch,2
	rep movsw

	in al,0a1h                      ; back up PIC masks
	_mov ah,al
	in al,21h
	mov [cs:-pmodewk+oldpicmasks],ax

	pop es
	ret

extmemadjust:
	fixpre_mov eax,[cs:-pmodewk+_pm_maxextmem]
	_cmp esi,eax
	jb short .00

	and ah,0fch
	_mov esi,eax

.00:
	ret

rmintvector:                            ; backed up real mode INT vectors

enablea20:                              ; hardware enable gate A20
	pushf
	multipush fs, gs
	cli

	_xor ax,ax                       ; set A20 test segments 0 and 0ffffh
	mov fs,ax
	dec ax
	mov gs,ax

	call enablea20test              ; is A20 already enabled?
	jz short .enablea20done        ; if yes, done

	in al,92h                       ; PS/2 A20 enable
	or al,2
	jmp short $+2
	jmp short $+2
	jmp short $+2
	out 92h,al

	call enablea20test              ; is A20 enabled?
	jz short .enablea20done        ; if yes, done

	call enablea20kbwait            ; AT A20 enable
	jnz short .enablea20f0

	mov al,0d1h
	out 64h,al

	call enablea20kbwait
	jnz short .enablea20f0

	mov al,0dfh
	out 60h,al

	call enablea20kbwait

.enablea20f0:                          ; wait for A20 to enable
	mov cx,800h                     ; do 800h tries

.enablea20l0:
	call enablea20test              ; is A20 enabled?
	jz .enablea20done              ; if yes, done

	call enablea20readtick
	_mov ah,al

.enablea20l1:                          ; wait a single tick
	call enablea20readtick

	_cmp al,ah
	je .enablea20l1

	loop .enablea20l0              ; loop for another try

	push bp
	_mov bp,sp                       ; error, A20 did not enable
	mov bx,4                        ; error code 4
	mov word [bp+8],-pmodewk+init_done       ; set init_done return address
	pop bp

.enablea20done:
	multipop gs, fs
	popf
	ret

enablea20readtick:
	in al,40h                       ; get current tick counter

	jmp short $+2
	jmp short $+2
	jmp short $+2

	in al,40h

	ret

enablea20kbwait:                        ; wait for safe to write to 8042
	_xor cx,cx

.enablea20kbwaitl0:
	jmp short $+2
	jmp short $+2
	jmp short $+2

	in al,64h                       ; read 8042 status

	test al,2                       ; buffer full?
	loopnz .enablea20kbwaitl0      ; if yes, loop

	ret

enablea20test:                          ; test for enabled A20
	mov al,[fs:0]                   ; get byte from 0:0
	_mov ah,al                       ; preserve old byte
	not al                          ; modify byte
	xchg al,[gs:10h]                ; put modified byte to 0ffffh:10h
	cmp ah,[fs:0]                   ; set zero if byte at 0:0 not modified
	mov [gs:10h],al                 ; put back old byte at 0ffffh:10h

	ret                             ; return, zero if A20 enabled

getrmirqvectors:
	multipush ds, es

	mov ax,870h

	push cs
	pop es
	_xor cx,cx
	mov ds,cx

	mov di,-pmodewk+rmirqvector

.00l:
	_mov cl,ah
	_mov si,cx
	shl si,2
	mov cl,2*8
	rep movsw

	shl ax,8
	jnz .00l

	multipop es, ds
	ret

r_init:                                 ; raw protected mode init
	mov ah,88h                      ; how much extended memory free
	int 15h  ; AX = number of contiguous 1k blocks of memory starting at linear address 100000h (1 MiB).

	_or ax,ax                        ; if none, done with raw init
	jz xr_init

	movzx esi,ax                    ; convert AX K to ptr to top of mem
	add esi,400h
	shl esi,10

	call enablea20                  ; enable A20

	push ds                         ; preserve ES (buffer segment)

	_xor cx,cx                       ; ES -> 0 (interrupt vector table)
	mov ds,cx
	lds bx,[4*19h]               ; ES:BX -> int vector table

	mov edx,'VDIS'                  ; Its reverse is 'SIDV' for TASM.
	mov eax,100000h                 ; initial free extended memory base
	cmp [bx+12h],edx             ; VDISK memory allocation?
	jne short .r_initf0             ; if present, get base of free mem

	mov eax,[bx+2ch]             ; get first free byte of extended mem
	add eax,03ffh                   ; align on kilobyte
	and eax,0fffc00h                ; address is only 24bit

.r_initf0:
	dec cx                          ; ES -> 0ffffh for ext mem addressing
	mov ds,cx

	cmp [13h],edx                ; VDISK memory allocation?
	jne short .r_initf1             ; if present, get base of free mem

	movzx ebx,word [2eh]         ; get first free K of extended memory
	shl ebx,10                      ; adjust K to bytes

	_cmp eax,ebx                     ; pick larger of 2 addresses
	ja short .r_initf1

	_mov eax,ebx

.r_initf1:
	pop ds                          ; restore ES (buffer segment)

	mov [-pmodewk+extmembase],eax              ; store base of raw extended memory
	_sub esi,eax
	jbe xr_init

	call extmemadjust
	mov [-pmodewk+extmemsize],esi

	shr esi,10
	mov [-pmodewk+rawextmemused],si

	push es

	inc cx
	mov es,cx

	call cleanup0
	fixpre2_mov [-pmodewk+oldint15vector],eax

	pop es

	_xor al,al
	jmp short xr_init2              ; go to XMS/raw continue init

x_init:                                 ; XMS protected mode init
	mov ah,3  ; XMS enable A20.
	call far [-pmodewk+xms_callip]

	mov bx,4                        ; error code 0004h in case of error
	cmp ax,strict word 1                        ; error enabling A20?
	jc init_done                    ; if yes, exit with error 0004h

	movzx esi,word [-pmodewk+xms_mem]
	shl esi,10
	call extmemadjust

	_or esi,esi
	jz short xr_init

	_mov edx,esi
	shr edx,10
	mov ah,9  ; Allocate DX KiB of memory using XMS.
	call far [-pmodewk+xms_callip]

	_or ax,ax
	jz short xr_init

	mov [-pmodewk+xms_handle],dx

	mov ah,0ch  ; XMS lock extended memory block, so that the XMS manager won't move it in physical memory.
	call far [-pmodewk+xms_callip]

	_or ax,ax
	jz short .00

	shl edx,16
	_mov dx,bx

	mov [-pmodewk+extmemsize],esi
	mov [-pmodewk+extmembase],edx

.00:
	mov al,2

xr_init2:
	mov [-pmodewk+cleanuptype],al

xr_init:                                ; XMS/raw common init tail
	mov word [-pmodewk+rmtopmswrout],-pmodewk+xr_rmtopmsw; set XMS/raw mode switch addresses
	mov dword [-pmodewk+pmtormswrout],-pmodewk+xr_pmtormsw

	jmp vxr_init                    ; go to VCPI/XMS/raw continue init

v_init:                                 ; VCPI protected mode init
	mov ax,0de0ah                   ; get PIC mappings
	int 67h
	_mov ch,bl
	mov [-pmodewk+picslave],cx

	call getrmirqvectors

	mov dx,es                       ; align data area on page
	add dx,0ffh
	_xor dl,dl
	mov es,dx

	movzx eax,dx                    ; set base and top of page table area
	inc ah
	mov fs,ax                       ; FS = segment of first page table

	shl eax,4
	mov [-pmodewk+pagetablebase],eax
	movzx ecx,byte [-pmodewk+pagetablenum]
	shl ecx,12
	_add eax,ecx
	mov [-pmodewk+pagetabletop],eax  ; !! Unused variable, remove it. (Is it really unused?)

	_xor di,di                       ; clear page dir and first page table
	mov cx,1000h
	_xor ax,ax
	rep stosw

	mov gs,dx                       ; GS = segment of page directory
	push fs                         ; ES = segment of first page table
	pop es

	push ss                         ; stack space for VCPI descriptors
	pop ds
	sub sp,8*3
	_mov si,sp

	_xor edi,edi                     ; get VCPI protected mode interface
	mov ax,0de01h
	int 67h

	push cs                         ; DS = PMODE_TEXT
	pop ds

	mov eax,[-pmodewk+pagetablebase]
	_add eax,edi
	add [-pmodewk+pagetablefree],eax

	mov [-pmodewk+vcpi_calleip],ebx            ; store protected mode VCPI call EIP
	movzx si,dh                     ; get physical address of page dir
	shl si,2                        ;  from first page table for CR3
	fixstr fs, lodsd
	mov [-pmodewk+vcpi_cr3],eax

.v_initl0:
	and byte [es:di+1],0f1h         ; clear bits 9-11 in copied page table
	sub di,4
	jnc .v_initl0

	mov dx,es                       ; DX = current page table segment
	_xor ebx,ebx                     ; index in page dir, also loop counter
	jmp short .v_initf0

.v_initl1:
	_xor di,di                       ; clear page table
	mov ch,8
	_xor ax,ax
	rep stosw

.v_initf0:
	inc dh                          ; increment page table segment
	mov es,dx

	fixstr fs, lodsd                ; set physical address of page table
	fixpre2_mov [gs:ebx*4],eax      ;  in page directory

	inc bx                          ; increment index in page directory
	cmp bl,[-pmodewk+pagetablenum]             ; at end of page tables?
	jb .v_initl1                    ; if no, loop

	push dx                         ; preserve seg of TSS for later use

	mov eax,[-pmodewk+vcpi_cr3]                ; set CR3 in TSS
	fixpre2_mov [es:1ch],eax
	lastdd 0x66, 0x26, 0xc7, 0x06, 64h, 0, 680000h  ; mov dword [es:64h],680000h      ; set offset of I/O permission bitmap  ; Diff: TASM encodes the 0x66 prefix, then the segment prefix, NASM does it the other way round.

	add dx,7                        ; increment next data area ptr
	mov es,dx

vxr_init:                               ; VCPI/XMS/raw common init tail
	_xor eax,eax                     ; set IDT base address
	mov ax,es
	shl eax,4
	mov [-pmodewk+idtbase],eax
	mov ax,es

	movzx bx,byte [-pmodewk+_pm_rmstacks]           ; set top and base of real mode stack
	imul bx,[-pmodewk+_pm_rmstacklen]          ;  area for interrupt redirection
	add ax,strict word 80h                      ;  from protected mode
	mov [-pmodewk+rmstackbase],ax
	_add ax,bx
	mov [-pmodewk+rmstacktop],ax

%if EXCEPTIONS
	mov [-pmodewk+abortrmstacktop],ax          ; store stack top for possible abort
%endif

	_xor di,di                       ; set up IDT
	mov dx,[-pmodewk+picslave]
	_xor ecx,ecx

.vxr_initl0:
	_mov bl,cl                       ; isolate high 5 bits of int num
	and bl,0f8h

%if EXCEPTIONS
	cmp cl,0eh                      ; one of the low 0eh interrupts?
	ja short .00                    ; if no, skip exception init

	lea eax,[10000h*SELCODE+4*ecx+-pmodewk+exception_intlowentry]

	_cmp bl,dh                       ; IRQs mapped normal?
	jne short .02                   ; if no, normal exception redirection

	imul eax,ecx,13h                ; address of exception/IRQ entry
	lea eax,[10000h*SELCODE+eax-13h*8+-pmodewk+exception_irqlowentry]

.02:
	stosd                           ; store low dword of IDT entry

	jmp short .01
%endif

.00:
	_mov bh,bl
	_mov eax,ecx
	and al,7

	_cmp bl,dl                       ; one of the high IRQs?
	jne short .04

	mov bh,70h

.04:
	_cmp bl,dh                       ; one of the low IRQs?
	jne short .03

	mov bh,8

.03:
	_or al,bh
	lea eax,[SELCODE*10000h+eax+-pmodewk+intrmatrix]
	stosd                           ; store low dword of IDT entry

	mov ah,8fh                      ; trap gate type

	cmp bh,8                        ; default IRQ mapping?
	je short .01                    ; if yes, interrupt gate type

	cmp bh,70h                      ; default IRQ mapping?
	jne short .vxr_initl0f0         ; if no, trap gate type

.01:
	mov ah,8eh                      ; interrupt gate type

.vxr_initl0f0:
	and eax,0000ff00h               ; prepare gate type
	stosd                           ; store high dword of IDT entry

	inc cl                          ; increment interrupt number
	jnz .vxr_initl0                 ; loop if more interrupts to go

	mov word [es:8*31h],-pmodewk+int31  ; protected mode INT 31h
	mov word [es:8*3],-pmodewk+intr  ; protected mode INT 3

	mov es,[-pmodewk+rmstacktop]               ; set next data area ptr to end of
					;  real mode stack area

	_xor eax,eax                     ; set protected mode stack area base
	mov ax,es                       ;  for callbacks
	shl eax,4
	mov [-pmodewk+pmstackbase],eax

	movzx ecx,word [-pmodewk+_pm_pmstacklen]        ; set protected mode stack area top
	movzx ebx,byte [-pmodewk+_pm_pmstacks]          ;  for callbacks
	shl ecx,4
	mov [-pmodewk+pmstacklen],ecx              ; protected mode stack size in bytes
	db 66h, 0fh, 0afh, 0d9h          ; `imul ebx,ecx' instuction, TASM 2.0 incorrectly generates `imul bx,cx'.
	_add ebx,eax
	mov [-pmodewk+pmstacktop],ebx              ; protected mode stack area top

	movzx cx,byte [-pmodewk+_pm_callbacks]          ; CX = number of callbacks
	_or cl,cl                        ; any callbacks?
	jz short .vxr_initf3           ; if no, done with this part

	mov [-pmodewk+callbackbase],ebx            ; top of stacks is base of callbacks
	shr ebx,4                       ; BX = seg of callback area
	mov [-pmodewk+callbackseg],bx

	mov ds,bx                       ; ES = seg of callback area
	_xor di,di                       ; location within callback seg
	mov ax,6866h

.vxr_initl1:
	mov word [di],6066h          ; PUSHAD instruction
	mov [di+2],ah           ; PUSH WORD instruction
	mov word [di+3],0            ; immediate 0 used as free flag
	mov [di+5],ax           ; PUSH DWORD instruction
	mov byte [di+11],0b9h        ; MOV CX,? instruction
	mov [di+14],ax          ; PUSH DWORD instruction
	mov byte [di+20],0eah        ; JMP FAR PTR ?:? intruction
	mov word [di+21],-pmodewk+callback
	reloc mov word [di+23],PMODE_TEXT

	add di,25                       ; increment ptr to callback
	dec cl                          ; decrement loop counter
	jnz .vxr_initl1                 ; if more callbacks to do, loop

	push cs
	pop ds

	add di,0fh                      ; align next data area on paragraph
	shr di,4
	_add bx,di
	mov es,bx                       ; set ES to base of next data area
.vxr_initf3:

	_xor eax,eax                     ; set GDT base address
	mov ax,es                       ;  for callbacks
	mov [-pmodewk+gdtseg],ax                   ; store segment of GDT
	shl eax,4
	mov [-pmodewk+gdtbase],eax

	mov cx,[-pmodewk+_pm_selectors]            ; set GDT limit
	shl cx,3
	add cx,8*5+8*SYSSELECTORS-1
	mov [-pmodewk+gdtlimit],cx

	_xor di,di                       ; clear GDT with all 0
	inc cx
	shr cx,1
	_xor eax,eax
	rep stosw

	cmp byte [-pmodewk+pmodetype],2                 ; if under VCPI, do VCPI GDT set up
	jne short .vxr_initf1

	pop ax                          ; restore TSS seg from stack
	shl eax,4                       ; set up TSS selector in GDT
	fixpre2_mov [es:SELVCPITSS+2],eax
	mov byte [es:SELVCPITSS],67h
	mov byte [es:SELVCPITSS+5],89h

	mov eax,-pmodewk+vcpisstacktop       ; set up temporary switch stack
	add eax,[-pmodewk+codebase]
	mov [-pmodewk+vcpiswitchstack],eax

	mov di,SELVCPICODE              ; copy 3 VCPI descriptors from stack
	_mov si,sp                       ;  to GDT
	mov cl,4*3
	rep ss movsw

	add sp,8*3                      ; adjust stack

.vxr_initf1:
	push es
	pop ds

	mov ax,-1
	mov dx,0df92h
	mov [SELZERO],ax             ; set SELZERO descriptor
	mov [SELZERO+5],dx
	mov [SELCALLBACKDS],ax       ; set callback DS descriptor
	mov [SELCALLBACKDS+5],dx

	mov dx,1092h                    ; DX = access rights
	_mov cx,ax                       ; CX = limit (64k)
	mov bx,SEL40                    ; BX = index to SEL40 descriptor
	mov ax,40h                      ; set SEL40 descriptor
	call vxr_initsetdsc

	mov bx,SELDATA                  ; BX = index to SELDATA descriptor
	mov ax,cs                       ; set SELDATA descriptor (PMODE_TEXT)
	call vxr_initsetdsc

	mov dl,9ah                      ; DX = access rights
	mov bl,SELCODE                  ; BX = index to SELCODE descriptor
	call vxr_initsetdsc2            ; set SELCODE descriptor (PMODE_TEXT)

	mov bl,8*SYSSELECTORS           ; BX = base of free descriptors
	push bx                         ; store selector

	mov ax,ss                       ; set caller SS descriptor
	mov dx,5092h
	call vxr_initsetdsc

	_mov ax,bx                       ; set caller DS descriptor and put DS
	xchg ax,[bp]                    ;  selector on stack for exit
	call vxr_initsetdsc

	push bx                         ; get PSP segment
	mov ah,51h
	int 21h
	_mov si,bx
	pop bx

	mov fs,si                       ; set caller environment descriptor
	mov ax,[fs:2ch]
	_or ax,ax                        ; is environment seg 0?
	jz short .vxr_initf0           ; if yes, dont convert to descriptor
	mov [fs:2ch],bx                 ; store selector value in PSP
	call vxr_initsetdsc

.vxr_initf0:
	_mov ax,si                       ; set caller PSP descriptor
	_xor ch,ch                       ; limit is 100h bytes
	call vxr_initsetdsc

%if ($-rmintvector)<400h
  %error ERROR_5
  times -1 nop
%endif

abortstackbase:                         ; abort protected mode stack base

	push cs                         ; set up INT redirector matrix
	pop es
	mov di,-pmodewk+intrmatrix
	inc cx
	mov al,0cch
	rep stosb

	call backupints

	lea ebp,[ebx-8]                 ; BP = PSP descriptor, just set
	pop dx                          ; DX = SS descriptor, from stack
	mov cx,SELZERO                  ; CX = ES descriptor, SELZERO
	movzx ebx,sp                    ; EBX = SP, current SP - same stack
	mov ax,SELCODE                  ; AX = DS descriptor, SELCODE
	mov edi,-pmodewk+vxr_pinit           ; target EIP
	_mov si,ax                       ; target CS is SELCODE, same segment

	jmp word [cs:-pmodewk+rmtopmswrout]             ; jump to mode switch routine

vxr_pinit:                              ; VCPI/XMS/raw protected mode init
	mov ebx,[-pmodewk+codebase]                ; get callbacks for DOS error ints
	dw 6667h,0bb8dh,-pmodewk+passupintregs,0 ; LEA EDI,[EBX+passupintregs]
	mov ax,303h

	mov esi,-pmodewk+int1c               ; INT 1Ch callback
	int 31h

	multipush cx, dx

	mov esi,-pmodewk+int23               ; INT 23h callback
	int 31h

	multipush cx, dx

	mov esi,-pmodewk+int24               ; INT 24h callback
	int 31h

	multipush cx, dx

	mov es,bp                       ; ES = PSP selector
	mov ds,[-pmodewk+seldata]                  ; DS = SELDATA selector

	pop dword [-pmodewk+int24callback]               ; store callback addresses
	pop dword [-pmodewk+int23callback]
	pop dword [-pmodewk+int1ccallback]

	jmp dvxr_init

vxr_initsetdsc:                         ; set descriptor for VCPI/XMS/raw init
	movzx eax,ax                    ; EAX = base of segment
	shl eax,4

vxr_initsetdsc2:
	mov [bx],cx                  ; limit = CX
	mov [bx+2],eax               ; base address = EAX
	mov [bx+5],dx                ; access rights = DX

	add bx,8                        ; increment descriptor index
	ret

int15:                                  ; real mode INT 15h handler
	cmp ah,88h                      ; function 88h?
	je short .int15f0               ; if yes, need to process

	jmp far [cs:-pmodewk+oldint15vector]     ; no, go on to old INT 15h handler

.int15f0:
	pushf                           ; call old int 15h handler
	call far [cs:-pmodewk+oldint15vector]

	sub ax,[cs:-pmodewk+rawextmemused]         ; adjust AX by extended memory used

	push bp                         ; clear carry flag on stack for IRET
	_mov bp,sp
	and byte [bp+6],0feh
	pop bp

	iret                            ; return with new AX extended memory

%if ($-abortstackbase)<0a0h
  %error ERROR_6
  times -1 nop
%endif

abortstacktop:

;
; Clean up after protected mode
; Out:
;   EAX,EBX,ECX,EDX,ESI,EDI,EBP - ?
;
_pm_cleanup:
	multipush ds, es
	cld

	push cs
	pop ds

	_xor cx,cx
	mov es,cx

	mov ax,[-pmodewk+oldpicmasks]              ; old PIC masks

	call restoreRMints              ; restore real mode INT stuff

	movzx bx,byte [-pmodewk+cleanuptype]
	call [bx+-pmodewk+cleanuptbl]

	multipop es, ds
	retf

cleanup0:
	mov eax,[-pmodewk+oldint15vector]
	fixpre_xchg eax,[es:4*15h]

cleanup3:
	ret

cleanup1:
	mov dx,[-pmodewk+xms_handle]
	mov ah,0dh  ; XMS unlock extended memory block.
	call far [-pmodewk+xms_callip]

	mov ah,0ah  ; XMS free extended memory block.
	call far [-pmodewk+xms_callip]

	ret

cleanup2:
	mov esi,[-pmodewk+pagetablefree]
	mov ecx,[-pmodewk+pagetablepages]
	_or ecx,ecx
	jz short .00

	_mov ebx,esi
	and si,0fh
	shr ebx,4
	mov ds,bx
	mov di,8000h

.00l:
	mov edx,[si]
	and dx,0f000h
	mov ax,0de05h
	int 67h

	add si,4
	_cmp si,di
	jb short .01

	_sub si,di
	add bh,8
	mov ds,bx

.01:
	dec ecx
	jnz .00l

	push cs
	pop ds

.00:
	test byte [-pmodewk+vcpi_memused],1
	jnz cleanup1

	ret

restoreRMints:
	out 21h,al                      ; set PICs
	_mov al,ah
	out 0a1h,al

	_xor di,di                       ; restore real mode INT vectors
	mov si,-pmodewk+rmintvector
	mov cx,44h
	rep movsw
	add di,4
	add si,4
	mov cx,1bah
	rep movsw

	ret

;
; PROTECTED MODE KERNEL CODE
;

v_rmtopmsw:                             ; VCPI real to protected switch
	pushf                           ; store FLAGS
	cli
	push cs                         ; DS = PMODE_TEXT
	pop ds
	pop word [-pmodewk+tempw0]      ; move FLAGS from stack to temp
	mov [-pmodewk+tempw1],ax        ; store AX (protected mode DS)
	mov [-pmodewk+tempw2],si        ; store SI (protected mode CS)
	mov esi,[-pmodewk+vcpistrucaddx]  ; ESI = linear addx of VCPI structure
	mov ax,0de0ch                   ; VCPI switch to protected mode
	int 67h
v_rmtopmswpm:
	mov ss,dx                       ; load protected mode SS:ESP
	_mov esp,ebx
	mov ds,[cs:-pmodewk+tempw1]     ; load protected mode DS
	mov es,cx                       ; load protected mode ES
	_xor ax,ax
	mov fs,ax                       ; load protected mode FS with NULL
	mov gs,ax                       ; load protected mode GS with NULL
	pushfd                          ; store EFLAGS
	mov ax,[cs:-pmodewk+tempw0]     ; move bits 0-11 of old FLAGS onto
	and ah,0fh                      ;  stack for IRETD
	mov [esp],ax
	fixpre_push_dword [cs:-pmodewk+tempd1]          ; store protected mode target CS
	push edi                        ; store protected mode target EIP
	iretd                           ; go to targed addx in protected mode

v_pmtormsw:                             ; VCPI protected to real switch
	pushf                           ; store FLAGS
	cli
	push ax                         ; store AX (real mode DS)
	mov ds,[cs:-pmodewk+selzero]    ; DS -> 0 (beginning of memory)
	movzx ebx,bx                    ; clear high word of EBX, real mode SP
	movzx edx,dx                    ; clear high word of EDX, real mode SS
	fixpre_mov eax,[cs:-pmodewk+vcpiswitchstack]      ; EAX -> top of temporary switch stack
	mov dword [eax+32],0         ; store real mode GS
	mov dword [eax+28],0         ; store real mode FS
	movzx ecx,cx                    ; clear high word of ECX, real mode ES
	mov [eax+20],ecx             ; store real mode ES
	pop cx                          ; move real mode DS from protected
	mov [eax+24],ecx             ;  mode stack to VCPI call stack
	mov [eax+16],edx             ; store real mode SS
	mov [eax+12],ebx             ; store real mode SP
	reloc2 mov dword [eax+4],PMODE_TEXT             ; store real mode CS
	mov dword [eax+0],-pmodewk+.v_pmtormswf0     ; store real mode IP
	pop bx                          ; restore FLAGS from stack
	mov ss,[cs:-pmodewk+selzero]               ; SS -> 0 (beginning of memory)
	_mov esp,eax                     ; ESP = stack ptr for VCPI call
	mov ax,0de0ch                   ; VCPI switch to real mode (V86)
	fixpre_call_dword far [cs:-pmodewk+vcpi_calleip]
.v_pmtormswf0:
	push bx                         ; store old FLAGS
	push si                         ; store target CS in real mode
	push di                         ; store target IP in real mode
	iret                            ; go to target addx in real mode

xr_rmtopmsw:                            ; XMS/raw real to protected switch
	pushfd                          ; store EFLAGS
	cli
	push ax                         ; store AX (protected mode DS)
	lidt [cs:-pmodewk+idtlimit]     ; load protected mode IDT
	lgdt [cs:-pmodewk+gdtlimit]     ; load protected mode GDT
	mov eax,cr0                     ; switch to protected mode
	or al,1
	mov cr0,eax
	jmp SELCODE:-pmodewk+$+5        ; JMP FAR PTR SELCODE:$+4 (clear prefetch que)
	pop ds                          ; load protected mode DS
	mov es,cx                       ; load protected mode ES
	_xor ax,ax
	mov fs,ax                       ; load protected mode FS with NULL
	mov gs,ax                       ; load protected mode GS with NULL
	pop eax
	mov ss,dx                       ; load protected mode SS:ESP
	_mov esp,ebx
	and ah,0bfh                     ; set NT=0 in old EFLAGS
	push ax                         ; set current FLAGS
	popf
	push eax                        ; store old EFLAGS
	push esi                        ; store protected mode target CS
	push edi                        ; store protected mode target EIP
	iretd                           ; go to targed addx in protected mode

xr_pmtormsw:                            ; XMS/raw protected to real switch
	pushf                           ; store FLAGS
	cli
	push ax                         ; store AX (real mode DS)
	mov ax,SELDATA
	mov ds,ax                       ; DS -> PMODEW_TEXT
	pop word [-pmodewk+tempw0]      ; move real mode DS from stack to temp
	pop word [-pmodewk+tempw1]      ; move FLAGS from stack to temp
	mov es,ax                       ; load descriptors with real mode seg
	mov fs,ax                       ;  attributes
	mov gs,ax
	mov ss,ax                       ; load descriptor with real mode attr
	movzx esp,bx                    ; load real mode SP, high word 0
	lidt [-pmodewk+rmidtlimit]      ; load real mode IDT
	mov eax,cr0                     ; switch to real mode
	and al,0feh
	mov cr0,eax
	reloc jmp PMODE_TEXT:-pmodewk+$+5     ; JMP FAR PTR PMODE_TEXT:$+4 (clear prefetch que)
	mov ss,dx                       ; load real mode SS
	mov ds,[cs:-pmodewk+tempw0]     ; load real mode DS
	mov es,cx                       ; load real mode ES
	_xor ax,ax
	mov fs,ax                       ; load real mode FS with NULL
	mov gs,ax                       ; load real mode GS with NULL
	push word [cs:-pmodewk+tempw1]  ; store old FLAGS
	push si                         ; store real mode target CS
	push di                         ; store real mode target IP
	iret                            ; go to target addx in real mode

vxr_saverestorepm:                      ; VCPI/XMS/raw save/restore status
	db 66h                          ; no save/restore needed, 32bit RETF

vxr_saverestorerm:                      ; VCPI/XMS/raw save/restore status
	retf                            ; no save/restore needed, 16bit RETF

callback:                               ; real mode callback handler
	_mov ax,sp                       ; preserve SS:SP for callback
	push ss
	push ax

	multipush gs, fs, ds, es        ; preserve real mode regs for callback
	pushf                           ; preserve FLAGS for callback

	cli
	cld

	push cs
	pop ds

	mov ebp,[-pmodewk+pmstacktop]           ; EBP = ESP for protected mode
	_mov ebx,ebp                     ; set EBX to next stack location
	sub ebx,[-pmodewk+pmstacklen]
	mov [-pmodewk+pmstacktop],ebx           ; update ptr for possible reenterancy

	cmp ebx,[-pmodewk+pmstackbase]          ; exceeded protected mode stack space?
	jb abort_callback               ; if yes, abort

	_xor eax,eax                     ; EAX = base address of SS
	mov ax,ss
	shl eax,4

	movzx ebx,sp                    ; EBX = current linear SS:SP
	_add ebx,eax

	mov es,[-pmodewk+gdtseg]                ; set for protected mode callback DS
	or eax,92000000h                ;  base address in GDT
	fixpre2_mov [es:SELCALLBACKDS+2],eax

	mov ax,SELZERO                  ; DS selector for protected mode
	_mov dx,ax                       ; SS selector = DS selector
	mov si,SELCODE                  ; target protected mode CS:EIP
	mov edi,-pmodewk+.callbackf0

	jmp word [-pmodewk+rmtopmswrout]             ; go to protected mode

.callbackf0:
	mov edi,[esp+14]                ; EDI -> register structure from stack

	lea esi,[esp+24]                ; copy general registers from stack
	mov ecx,8                       ;  to register structure
	fixstr rep, a32, movsd

	_mov esi,esp                    ; copy FLAGS, ES, DS, FG, and GS
	mov cl,5
	rep a32 movsw

	fixstr a32, lodsd               ; EAX = real mode SS:SP from stack
	add ax,strict word 42           ; adjust SP for stuff on stack
	fixpre2_mov [es:edi+4],eax      ; put in register structure

	mov ds,[cs:-pmodewk+selcallbackds]         ; DS = callback DS selector
	sub edi,42                      ; EDI -> register structure
	movzx esi,ax                    ; ESI = old real mode SP
	_xchg esp,ebp                    ; ESP = protected mode stack

	pushfd                          ; push flags for IRETD from callback
	db 66h                          ; push 32bit CS for IRETD
	push cs
	push dword -pmodewk+.callbackf1  ; push 32bit EIP for IRETD

	movzx eax,word [ebp+22]         ; EAX = target CS of callback
	push eax                        ; push 32bit CS for RETF to callback
	push dword [ebp+18]             ; push 32bit EIP for retf

	db 66h                          ; 32bit RETF to callback
	retf

.callbackf1:
	cli
	cld

	push es                         ; DS:ESI = register structure
	pop ds
	_mov esi,edi

	mov es,[cs:-pmodewk+selzero]               ; ES -> 0 (beginning of memory)

	movzx ebx,word [esi+2eh]        ; EBX = real mode SP from structure
	movzx edx,word [esi+30h]        ; EDX = real mode SS from structure
	sub bx,42                       ; subtract size of vars to be put

	mov ebp,[esi+0ch]               ; EBP = pushed ESP from real mode
	_mov bp,bx                       ; EBP = old high & new low word of ESP

	_mov edi,edx                     ; EDI -> real mode base of stack
	shl edi,4                       ;  of vars to be stored
	_add edi,ebx

	mov ecx,8                       ; copy general registers to stack
	fixstr rep, a32, movsd

	mov eax,[esi+6]                 ; EAX = return FS and GS for real mode
	fixstr a32, stosd               ; store on real mode stack for return

	mov eax,[esi+10]                ; EAX = return CS:IP for real mode
	fixstr a32, stosd               ; store on real mode stack for return
	mov ax,[esi]                    ; AX = return FLAGS for real mode
	a32 stosw          ; store on real mode stack for return

	mov ax,[esi+4]                  ; AX = return DS for real mode
	mov cx,[esi+2]                  ; CX = return ES for real mode

	mov di,-pmodewk+.callbackf2
	reloc mov si,PMODE_TEXT               ; real mode target CS:IP

	db 66h                          ; JMP DWORD PTR, as in 32bit offset,
	jmp [cs:-pmodewk+pmtormswrout]  ;  not seg:16bit offset

.callbackf2:
	_mov esp,ebp                     ; restore total ESP, old high word

	fixpre_mov eax,[cs:-pmodewk+pmstacklen]           ; restore top of protected mode stack
	fixpre2_add [cs:-pmodewk+pmstacktop],eax

	popad                           ; get callback return general regs
	multipop fs, gs                 ; get callback return FS and GS values
	iret                            ; go to callback return CS:IP

rmirqmatrix:
%rep 16
	push ax
	call rmintr
%endrep

rmintr:
	pop ax
	sub ax,strict word -pmodewk+rmirqmatrix+4
	shr ax,2

	pushad
	multipush ds, es, fs, gs

	push cs
	pop ds

	mov ebp,[-pmodewk+pmstacktop]
	_mov ebx,ebp
	sub ebx,[-pmodewk+pmstacklen]
	mov [-pmodewk+pmstacktop],ebx

	cmp ebx,[-pmodewk+pmstackbase]
	jb abort_IRQtoPM

	xor al,8
	_mov si,ax
	and al,7
	shr si,3
	or al,[word -pmodewk+picslave+si]  ; `Diff: effective address `word' is because of missed TASM optimization.
	mov [-pmodewk+.rmintrintnum],al

	mov edi,-pmodewk+.rmintrf0
	mov si,SELCODE
	mov dx,SELZERO
	_mov cx,dx
	_mov ax,dx

	mov bp,ss
	shl ebp,16
	_mov bp,sp

	jmp word [cs:-pmodewk+rmtopmswrout]

.rmintrf0:
	db 0cdh
.rmintrintnum  db      ANY

	shld edx,ebp,16
	_mov bx,bp

	mov di,-pmodewk+.rmintrf1
	reloc mov si,PMODE_TEXT

	db 66h
	jmp [cs:-pmodewk+pmtormswrout]

.rmintrf1:
	fixpre_mov eax,[cs:-pmodewk+pmstacklen]
	fixpre2_add [cs:-pmodewk+pmstacktop],eax

	mov ax,[esp+20]
	shl eax,16
	_or esp,eax

	multipop gs, fs, es, ds
	popad
	pop ax
	iret

intr:                                   ; general interrupt redirector
	cmp word [esp+4],SELCODE        ; INT redirection or internal INT 3?
	je short intrredirect           ; if not INT 3, jump to redirection

%if EXCEPTIONS
	jmp exception_intlowentry+4*3   ; go to exception 3 handler
%else
	fixpre_jmp_dword far [cs:-pmodewk+int3vector]  ; INT 3, jump to INT 3 vector
%endif

intrredirect:
	mov [esp+8],eax                 ; store EAX for later POPAD
	mov eax,[esp]                   ; get address in redirection matrix
	add esp,8                       ; discard EIP and CS from INT 3

	multipush ecx, edx, ebx, esp, ebp, esi, edi  ; store rest of registers for POPAD
	multipush ds, es, fs, gs
	cld

	push cs
	pop ds

	mov edi,[-pmodewk+codebase]             ; EDI = offset of PMODE_TEXT from 0

	mov dx,[-pmodewk+rmstacktop]            ; DX = SS for real mode redirection
	movzx ebp,dx                    ; EBP -> top of real mode stack
	shl ebp,4

	mov bx,[-pmodewk+_pm_rmstacklen]        ; get size of real mode stack
	_sub dx,bx                       ; adjust DX to next stack location
	shl bx,4                        ; set real mode SP to top of stack

	mov ds,[-pmodewk+selzero]    ; DS -> 0 (beginning of memory)
	mov [dword -pmodewk+rmstacktop+edi],dx       ; update ptr for possible reenterancy  ; `Diff: effective address `dword' is because of missed TASM optimization.

	cmp dx,[cs:-pmodewk+rmstackbase]           ; exceeded real mode stack space?
	jb abort_INTtoRM                ; if yes, abort

	mov [ds:ebp-2],ss               ; store SS:ESP on real mode stack  ; The `ds:' prefix is needed, because EBP defaults to SS.
	fixpre2_mov [ds:ebp-6],esp

	sub ax,strict word -pmodewk+intrmatrix+1         ; AX = int number
	_mov ah,al                       ; AH = high 5 bits of int number
	and ah,0f8h

	cmp ah,8                        ; low IRQ?
	je short intrirq                ; if yes, do IRQ

	cmp ah,70h                      ; high IRQ?
	jne short intrint               ; if no, do INT (with general regs)

	sub ah,8

intrirq:                                ; an IRQ redirection
	reloc2 lastdd 0x66, 0x3e, 0x67, 0xc7, 0x45, 0xf6, PMODE_TEXT  ; mov dword [ds:ebp-10],PMODE_TEXT  ; Diff: TASM encodes the 0x66 prefix, then the segment prefix, NASM does it the other way round.
	mov word [ds:ebp-12],-pmodewk+.intrirqf0

	movzx ecx,al
	mov edi,[ecx*4]

	_sub al,ah
	_mov cl,al
	bt [cs:-pmodewk+irqhookmap],cx
	jnc short .intrirqf2

	fixpre_mov edi,[cs:-pmodewk+rmirqvector+ecx*4]

.intrirqf2:
	shld esi,edi,16
	sub bx,6+6                      ; adjust real mode SP for stored vars

	db 66h                          ; JMP DWORD PTR, as in 32bit offset,
	jmp [cs:-pmodewk+pmtormswrout]  ;  not seg:16bit offset

.intrirqf0:
	mov ax,SELZERO                  ; DS selector value for protected mode
	_mov cx,ax                       ; ES selector value for protected mode
	pop ebx                         ; get protected mode SS:ESP from stack
	pop dx
	mov si,SELCODE                  ; target CS:EIP in protected mode
	mov edi,-pmodewk+.intrirqf1

	jmp word [cs:-pmodewk+rmtopmswrout]             ; go back to protected mode

.intrirqf1:
	fixpre_mov edi,[cs:-pmodewk+codebase]             ; restore top of real mode stack
	mov ax,[cs:-pmodewk+_pm_rmstacklen]
	add [dword -pmodewk+rmstacktop+edi],ax  ; Diff: effective address `dword' is because of missed TASM optimization.

	multipop gs, fs, es, ds                 ; restore all registers
	popad
	iretd

intrint:                                ; an INT redirection
	mov [-pmodewk+.intrintintnum+edi],al  ; modify code with interrupt number

	mov es,[cs:-pmodewk+selzero]               ; copy registers from protected mode
	lea edi,[ebp-28h]               ;  stack to real mode stack

	mov ax,[esp+30h]                ; copy flags from protected mode stack
	a32 stosw

	lea esi,[esp+8]
	mov ecx,8
	fixstr rep, ss a32, movsd

	sub bx,28h                      ; adjust real mode SP for stored vars

	mov di,-pmodewk+.intrintf0
	reloc mov si,PMODE_TEXT               ; real mode target CS:IP

	db 66h                          ; JMP DWORD PTR, as in 32bit offset,
	jmp [cs:-pmodewk+pmtormswrout]  ;  not seg:16bit offset

.intrintf0:
	popf
	popad                           ; load regs with int call values

	db 0cdh                         ; INT .intrirqintnum
.intrintintnum db      ANY

	pushad                          ; store registers on stack
	pushf                           ; store flags on stack
	cli

	_xor eax,eax                     ; EAX = linear ptr to SS
	mov ax,ss
	shl eax,4
	movzx ebp,sp                    ; EBP = SP

	mov ebx,[bp+22h]                ; get protected mode SS:ESP from stack
	mov dx,[bp+26h]

	_add ebp,eax                     ; EBP -> stored regs on stack

	mov ax,SELZERO                  ; DS selector value for protected mode
	_mov cx,ax                       ; ES selector value for protected mode
	mov si,SELCODE                  ; target CS:EIP in protected mode
	mov edi,-pmodewk+.intrintf1

	jmp word [cs:-pmodewk+rmtopmswrout]             ; go back to protected mode

.intrintf1:
	fixpre_mov edi,[cs:-pmodewk+codebase]             ; restore top of real mode stack
	mov ax,[cs:-pmodewk+_pm_rmstacklen]
	add [dword -pmodewk+rmstacktop+edi],ax  ; `Diff: effective address `dword' is because of missed TASM optimization.

	mov ax,[ds:ebp]                 ; move return FLAGS from real mode
	and ax,strict word 8d5h                     ;  stack to protected mode stack
	mov bx,[esp+30h]
	and bx,~8d5h
	_or ax,bx
	mov [esp+30h],ax

	_mov eax,ebp                     ; restore return registers from real
	mov edi,[eax+2]                 ;  mode stack
	mov esi,[eax+6]
	mov ebp,[eax+10]
	mov ebx,[eax+18]
	mov edx,[eax+22]
	mov ecx,[eax+26]
	mov eax,[eax+30]

	multipop gs, fs, es, ds         ; restore segment regs
	add esp,20h                     ; skip old general registers on stack
	iretd

int1c:                                  ; INT 1Ch pass-up interface
	call passupintinit

	int 1ch

passupintdone:
	mov ax,6

passupintdone2:
	cli
	cld

	add [esp+2eh],ax

	mov eax,32h
	_mov ecx,eax
	_mov esi,esp

	push edi

	push es
	pop ds
	rep a32 movsb
	pop edi

	_add esp,eax

	iretd

passupintinit:
	pop bp

	mov eax,[esi]
	fixpre2_mov [es:edi+2ah],eax
	mov ax,[esi+4]
	mov [es:edi+20h],ax

	_mov esi,edi
	mov ecx,32h
	_sub esp,ecx
	_mov edi,esp

	push esi

	push es
	pop ds
	rep a32 movsb
	pop edi

	jmp bp

int23:                                  ; DOS INT 23h pass-up interface
	call passupintinit

	_mov ebp,esp

	clc
	sti
	int 23h

	_mov esp,ebp

	setc al
	mov ah,[esp+20h]
	and ah,0feh
	_or al,ah
	mov [esp+20h],al

	mov ax,4
	jmp passupintdone2

int24:                                  ; DOS INT 24h pass-up mode interface
	mov dx,ds
	_mov bx,si

	call passupintinit

	push edi

	mov ds,dx
	lea si,[bx+6+20]
	std

	lodsd
	push eax
	lodsd
	push eax
	lodsd
	push eax
	lodsd
	push eax
	lodsd
	push eax
	lodsd
	push eax

	mov bp,es
	movzx esi,word [esp+24+4+8]
	movzx eax,word [esp+24+4+4]
	shl esi,4
	_add esi,eax
	mov di,[esp+24+4]
	mov ax,[esp+24+4+1ch]

	sti
	int 24h

	add esp,24
	pop edi

	mov [esp+1ch],al

	jmp passupintdone

;
; EXCEPTIONS
;
%if EXCEPTIONS

exception_intlowentry:                  ; raw exception entry points

%macro irp1 0-*
  %rep %0  ; %1 is num.
    push %1
    jmp short exception_intlow
    %rotate 1
  %endrep
%endmacro

irp1 0,1,2,3,4,5,6,7,8,9,10,11,12,13,14

%if ($-exception_intlowentry)!=4*15
  %error ERROR_7
  times -1 nop
%endif

exception_intlow:
	jmp exception

exception_irqlowentry:                  ; common IRQ/exception entry points

%macro irp2 0-*
  %rep %0  ; %1 is num.
    push ax
    mov ax,(100h * ((%1) + 8)) + 0bh
    out 20h,al
    in al,20h
    test al,1<<(%1)
    jz short exception_irqlow
    pop ax
    fixpre_jmp_dword far [cs:-pmodewk+exceptionivect+6*8+6*(%1)]
    %rotate 1
  %endrep
%endmacro

irp2    0,1,2,3,4,5,6

%if ($-exception_irqlowentry)!=13h*7
  %error ERROR_8
  times -1 nop
%endif

exception_irqlow:
	shr ax,8                        ; store exception number on stack
	xchg ax,[esp]

exception:                              ; main exception dispatch
	push 0
	pushad                          ; store registers for possible dump

	movzx si,byte [esp+32+2]        ; SI = exception number
	lastdw 0x66, 0x2e, 0x0f, 0xb6, 0x9c, -pmodewk+exceptionecsize  ; movzx ebx,byte [cs:-pmodewk+exceptionecsize+si]  ; EBX = error code field size  ; Diff: TASM encodes the 0x66 prefix, then the segment prefix, NASM does it the other way round.
	mov [esp+32],bl                 ; store error code field size

	mov ax,ss                       ; exception stack frame SS
	push eax
	lea eax,[esp+4*1+32+4+4*3]      ; exception stack frame ESP
	push eax
	mov eax,[esp+4*2+32+4+ebx+8]    ; exception stack frame EFLAGS
	push eax
	mov ax,[esp+4*3+32+4+ebx+4]     ; exception stack frame CS
	push eax
	mov eax,[esp+4*4+32+4+ebx+0]    ; exception stack frame EIP
	push eax
	mov eax,[esp+4*5+32+4]          ; exception stack frame error code
	push eax

	lea esi,[2*esi+esi]             ; EDI = position of exception address
	shl si,1

	db 66h, 0eh                     ; `push large cs' instruction. (TASM 2.51 would emit just `db eh' == `push cs')  ; push addresses for exception
	push dword -pmodewk+exception_done
	fixpre_push_dword [cs:-pmodewk+exceptionevect+si+4]
	fixpre_push_dword [cs:-pmodewk+exceptionevect+si]

	mov esi,[esp+4*4+4*6+4]         ; registers at point of exception
	mov ebx,[esp+4*4+4*6+16]
	mov eax,[esp+4*4+4*6+28]

	db 66h                          ; 32bit RETF to exception handler
	retf

exception_done:                         ; end of exception entry point
	cli                             ; exception handler returned

	mov [esp+4*6+24],ebx            ; preserve returned EAX and EBX
	mov [esp+4*6+28],eax

	movzx ebx,byte [esp+4*6+32]     ; EBX = error code field size

	mov eax,[esp+4]                 ; copy return EIP from exception frame
	mov [esp+4*6+32+4+ebx+0],eax
	mov eax,[esp+8]                 ; copy return CS from exception frame
	mov [esp+4*6+32+4+ebx+4],eax

	lea eax,[esp+ebx+4*6+32+4]      ; calculate stack pointer for exit
	mov [esp+4*6+32],eax            ; store on stack

	add esp,4*6+4*6                 ; clean up stack and regs and return
	pop ebx
	pop eax
	mov esp,[esp]

	iretd

; Displays a hex register dump on the screen (video memory). This is only
; enabled %if EXCEPTIONS. For instruction int3, it will be `Exception: 03'.
; Example dump:
;
; [PMODE/W]: Abort: 00
; Exception: 0C
; Error code: 73127443
; EAX: 00001234  EBX: 12345678  ECX: 00001234  EDX: 12345678
; ESI: 00001234  EDI: 12345678  EBP: 03657245  ESP: 12345678
; DS: 1234  ES: 2345  FS: 8583  GS: 1295  SS: 2587  CS: 1746
; EIP: 04571346
; EFLAGS: 10538692
; CR0: 86425789  CR2: 01362334
exception_def:                          ; default exception handler (aborts)
	multipush es, ds                ; preserve selectors for dump

	; [PMODE/W]: Abort: 00
	; Exception:
	_xor bp,bp                       ; start abort sequence
	call abort_start

	mov dx,[esp+2*2+4*8+32+2]       ; DX = exception number
	push dx                         ; preserve exception number

	; 0C
	call abort_puthexnum2           ; put exception number
	call abort_nextline

	pop bx                          ; BX = exception number

	cmp byte [cs:-pmodewk+exceptionecsize+bx],0  ; error code present?
	je short .00                   ; if no, skip error code put

	; Error code: 73127443
	mov si,-pmodewk+aborts_xerrcode   ; put error code
	call abort_putstr
	mov edx,[esp+2*2+2*4]
	call abort_puthexnum8
	call abort_nextline

.00:
	; EAX: 00001234
	mov si,-pmodewk+aborts_xeax       ; put EAX
	call abort_putstr
	mov edx,[esp+2*2+4*8+28]
	call abort_puthexnum8

	; EBX: 12345678
	mov si,-pmodewk+aborts_xebx       ; put EBX
	call abort_putstr
	mov edx,[esp+2*2+4*8+16]
	call abort_puthexnum8

	; ECX: 00001234
	mov si,-pmodewk+aborts_xecx       ; put ECX
	call abort_putstr
	mov edx,[esp+2*2+4*8+24]
	call abort_puthexnum8

	; EDX: 12345678
	mov si,-pmodewk+aborts_xedx       ; put EDX
	call abort_putstr
	mov edx,[esp+2*2+4*8+20]
	call abort_puthexnum8

	call abort_nextline

	; ESI: 00001234
	mov si,-pmodewk+aborts_xesi       ; put ESI
	call abort_putstr
	mov edx,[esp+2*2+4*8+4]
	call abort_puthexnum8

	; EDI: 12345678
	mov si,-pmodewk+aborts_xedi       ; put EDI
	call abort_putstr
	mov edx,[esp+2*2+4*8+0]
	call abort_puthexnum8

	; EBP: 03657245
	mov si,-pmodewk+aborts_xebp       ; put EBP
	call abort_putstr
	mov edx,[esp+2*2+4*8+8]
	call abort_puthexnum8

	; ESP: 12345678
	mov si,-pmodewk+aborts_xesp       ; put ESP
	call abort_putstr
	mov edx,[esp+2*2+18h]
	call abort_puthexnum8

	call abort_nextline

	; DS: 1234
	mov si,-pmodewk+aborts_xds        ; put DS
	call abort_putstr
	pop dx
	call abort_puthexnum4

	; ES: 2345
	mov si,-pmodewk+aborts_xes        ; put ES
	call abort_putstr
	pop dx
	call abort_puthexnum4

	; FS: 8583
	mov si,-pmodewk+aborts_xfs        ; put FS
	call abort_putstr
	mov dx,fs
	call abort_puthexnum4

	; GS: 1295
	mov si,-pmodewk+aborts_xgs        ; put GS
	call abort_putstr
	mov dx,gs
	call abort_puthexnum4

	; SS: 2587
	mov si,-pmodewk+aborts_xss        ; put SS
	call abort_putstr
	mov dx,ss
	call abort_puthexnum4

	; CS: 1746
	mov si,-pmodewk+aborts_xcs        ; put CS
	call abort_putstr
	mov dx,[esp+10h]
	call abort_puthexnum4

	call abort_nextline

	; EIP: 04571346
	mov si,-pmodewk+aborts_xeip       ; put EIP
	call abort_putstr
	mov edx,[esp+0ch]
	call abort_puthexnum8

	call abort_nextline

	; EFLAGS: 10538692
	mov si,-pmodewk+aborts_xeflags    ; put EFLAGS
	call abort_putstr
	mov edx,[esp+14h]
	call abort_puthexnum8

	call abort_nextline

	; CR0: 86425789
	mov si,-pmodewk+aborts_xcr0       ; put CR0
	call abort_putstr
	mov edx,cr0
	call abort_puthexnum8

	; CR2: 01362334
	mov si,-pmodewk+aborts_xcr2       ; put CR2
	call abort_putstr
	mov edx,cr2
	call abort_puthexnum8

	; Printing as finishes. This moves the cursor, and exits.
%if SIZEOPT
abort_exit:                             ; exit after abnormal termination
%if ABORTMSGTTY
	call abort_nextline
%else
	mov ah,2                        ; position cursor at bottom of screen
	_xor bh,bh
	mov dx,0800h
	int 10h
%endif

%if EXITCODE
	mov al,0fbh                     ; exit(251); Not merging it to `mov ax,...' for better compressibility.
%endif
	mov ah,4ch                      ; aborted because of a protected mode exception
	int 21h                         ; terminate DOS process
%else
	jmp abort_exit                  ; finish abort
%endif

abort_callback:                         ; ran out of PM stacks in callback
	mov bp,1                        ; abort string 1

abort_rm:                               ; real mode abort
	_xor ax,ax
	_xor cx,cx
	mov dx,SELDATA
	mov ebx,-pmodewk+abortstacktop
	mov si,SELCODE
	mov edi,-pmodewk+abort_pm

	jmp word [cs:-pmodewk+rmtopmswrout]

abort_IRQtoPM:                          ; ran out of PM stacks in RM->PM IRQ
	mov bp,2                        ; abort string 2

	jmp short abort_rm

abort_INTtoRM:                          ; ran out of RM stacks in PM->RM INT
	mov bp,3                        ; abort string 3

	jmp short abort_pm

abort_INT3103:                          ; ran out of RM stacks in INT 31h 03h
	mov bp,4                        ; abort string 4

abort_pm:                               ; protected mode abort
	call abort_start

	jmp abort_exit

%if ABORTMSGTTY
abort_putc2:  ; Prints AL, then AH.
	call abort_putc
	mov al, ah
	; Fall through to abort_putc.

abort_putc:
%if ABORTMSGTTY==1
	push ax  ; Save.
	push bx  ; Save.
	mov ah, 0eh  ; Write text in teletype (TTY) mode.
	xor bx, bx  ; Write to page 0 in text mode. In graphics mode, BL should be the color (typically white==7, we have black==0 here).
	int 10h  ; BIOS video syscall.
	pop bx  ; Restore.
	pop ax  ; Restore.
%elif ABORTMSGTTY==2
	push ax  ; Save.
	push dx  ; Save.
	mov ah, 2  ; Write character to stdout.
	mov dl, al
	int 21h  ; DOS syscall.
	pop dx  ; Restore.
	pop ax  ; Restore.
%elif ABORTMSGTTY==3
	int 29h  ; Undocumented DOS fast write character syscall. On DOS 2.x and 3.x, simply calls BIOS video int 10h with AH == 0eh.
%endif
	ret
%endif


abort_putstr:
	lodsb

	_or al,al
	jz short .00

%if ABORTMSGTTY
	call abort_putc
%else
	a32 stosw
%endif
	jmp short abort_putstr

.00:
	ret

abort_nextline:
%if ABORTMSGTTY
	mov ax, 13 | 10<<8  ; CRLF.
	jmp short abort_putc2
%else
	add bp,2*80
	_mov di,bp
	ret
%endif
	; Not reached.

abort_puthexnum:
	_xor bx,bx

.00l:
	rol edx,4
%if SIZEOPT
	_mov al,dl
	and al,0fh
	add al,'0'
	cmp al,'9'
	jbe short .have_char_in_al
	add al,'A'-10-'0'  ; 7.
.have_char_in_al:
%else
	_mov bl,dl
	and bl,0fh
	mov al,[-pmodewk+aborts_hexctbl+bx]
%endif

%if ABORTMSGTTY
	call abort_putc
%else
	a32 stosw
%endif

	dec cl
	jnz .00l

%if ABORTMSGTTY
	mov ax, ' ' | ' '<<8
	jmp short abort_putc2
%else
	mov al,' '
	a32 stosw
	a32 stosw
	ret
%endif
	; Not reached.

abort_puthexnum2:
	shl edx,24
	mov cl,2

	jmp short abort_puthexnum

abort_puthexnum4:
	shl edx,16
	mov cl,4

	jmp short abort_puthexnum

abort_puthexnum8:
	mov cl,8

	jmp short abort_puthexnum

; In addition to some initalization, this prints:
;
; [PMODE/W]: Abort: 00
; Exception: (with space at the end)
abort_start:                            ; abort, stabilize system
	cli
	cld

	push bp                         ; store abort number
	push bp

	mov ds,[cs:-pmodewk+seldata]               ; DS -> PMODE_TEXT
	mov es,[-pmodewk+selzero]                  ; ES -> 0 (beginning of memory)

	mov ax,[-pmodewk+abortrmstacktop]          ; copy old top of real mode stack
	mov [-pmodewk+rmstacktop],ax

	mov al,20h                      ; clear pending IRQs
	out 20h,al
	out 0a0h,al

	mov ax,0ffffh                   ; mask offset all IRQs

	call restoreRMints              ; restore real mode INT environment

%if ABORTMSGTTY<=1
	mov ax,3                        ; set 80x25 text mode
	int 10h
%endif

%if ABORTMSGTTY
	call abort_nextline             ; Start a new line, in case the output is mid-line.
%else
	mov ebp,0b8000h                 ; EBP -> current TTY row start. 0b8000:0 is sthe start of the 80x25 text screen
	_mov edi,ebp                    ; EDI -> current TTY column
	mov ah,7                        ; AH = text color
%endif

	; [PMODE/W]: Abort: 00
	mov si,-pmodewk+aborts_pmwabort      ; put first string of abort
	call abort_putstr
	pop dx                          ; put abort number
	call abort_puthexnum2
	call abort_nextline

	; Exception: (with space a the end)
	pop bx                          ; put abort string
	_xor bh,bh
	_add bl,bl
	mov si,[-pmodewk+aborts_tbl+bx]
	jmp abort_putstr                ; put abort string and return
	; Printing continues in exception_def, below `call abort_start'.

%if SIZEOPT==0
abort_exit:                             ; exit after abnormal termination
%if ABORTMSGTTY
	call abort_nextline
%else
	mov ah,2                        ; position cursor at bottom of screen
	_xor bh,bh
	mov dx,0800h
	int 10h
%endif

%if EXITCODE
	mov al,0fbh                     ; exit(251); Not merging it to `mov ax,...' for better compressibility.
%endif
	mov ah,4ch                      ; aborted because of a protected mode exception
	int 21h                         ; terminate DOS process
%endif

%else
abort_callback:                         ; ran out of PM stacks in callback
abort_IRQtoPM:                          ; ran out of PM stacks in RM->PM IRQ
abort_INTtoRM:                          ; ran out of RM stacks in PM->RM INT
abort_INT3103:                          ; ran out of RM stacks in INT 31h 03h
	cli                             ; make sure we are not interrupted

	in al,61h                       ; beep
	or al,3
	out 61h,al

	jmp $                           ; now hang
%endif

;
; INT 31h INTERFACE
;

int31:                                  ; protected mode INT 31h handler
	cli
	cld
	multipush ds, es, fs, gs                ; push regs needed
	pushad
	mov ds,[cs:-pmodewk+selzero]               ; DS -> 0 (beginning of memory)
	mov fs,[cs:-pmodewk+seldata]               ; FS -> PMODE_TEXT

	push bx
	mov bx,(INT31FUNCNUM-1)*2       ; number of functions to check
.int31l0:
	cmp ax,[cs:-pmodewk+int31functbl+bx]      ; found function value?
	jne short .int31l0c

	mov bx,[cs:-pmodewk+int31routtbl+bx]      ; yes, go to appropriate handler
	xchg bx,[esp]
	ret

.int31l0c:
	dec bx                          ; no, continue loop
	dec bx
	jns .int31l0

	pop bx                          ; no function found
	jmp short int31fail

int31failbx:                            ; INT 31h return fail with BX,AX
	mov [esp+16],bx                 ; put CX onto stack for POPAD

int31failax:                            ; INT 31h return fail with AX
	mov [esp+28],ax                 ; put AX onto stack for POPAD

int31fail:                              ; INT 31h return fail, pop all regs
	popad
	multipop gs, fs, es, ds

int31failnopop:                         ; INT 31h return fail with carry set
	or byte [esp+8],1               ; set carry in EFLAGS on stack
	iretd

int31okedx:                             ; INT 31h return ok with EDX,CX,AX
	mov [esp+20],edx                ; put EDX onto stack for POPAD
	jmp short int31okcx

int31okcx:                              ; INT 31h return ok with CX,DX,AX
	mov [esp+24],cx                 ; put CX onto stack for POPAD

int31okdx:                              ; INT 31h return ok with DX,AX
	mov [esp+20],dx                 ; put DX onto stack for POPAD

int31okax:                              ; INT 31h return ok with AX
	mov [esp+28],ax                 ; put AX onto stack for POPAD

int31ok:                                ; INT 31h return ok, pop all regs
	popad

int31oknopopgeneral:                    ; INT 31h return ok, pop all segregs
	multipop gs, fs, es, ds

int31oknopop:                           ; INT 31h return ok with carry clear
	and byte [esp+8],0feh           ; clear carry in EFLAGS on stack
	iretd

;
; DESCRIPTOR FUNCTIONS
;

int31testsel:                           ; test for valid selector BX
	pop bp                          ; pop return address

	cmp bx,[cs:-pmodewk+gdtlimit]              ; selector BX out of range?
	ja int31fail                    ; if yes, fail with error 8022h

	fixpre_mov edi,[cs:-pmodewk+gdtbase]              ; get base of GDT
	and bl,0f8h                     ; mask offset table index and RPL
	movzx ebx,bx                    ; EBX = selector index

	test byte [edi+ebx+6],10h    ; is descriptor used?
	jz int31fail                    ; if descriptor not used, fail 8022h

	jmp bp                          ; return ok

int31testaccess:                        ; test access bits in CX
	pop bp                          ; pop return address

	test ch,20h                     ; test MUST BE 0 bit in CH
	jnz int31fail                   ; if not 0, error 8021h

	test cl,90h                     ; test present and MUST BE 1 bits
	jz int31fail                    ; if both 0, error 8021h
	jpo int31fail                   ; if unequal, error 8021h

	test cl,60h                     ; test DPL
	jnz int31fail                   ; if not 0, error 8021h

	test cl,8                       ; if code, more tests needed
	jz short .int31testselok       ; if data, skip code tests

	test cl,6                       ; test conforming and readable bits
	jz int31fail                    ; if both 0, error 8021h
	jpe int31fail                   ; if equal, error 8021h

.int31testselok:
	jmp bp                          ; return ok

int310000:                              ; allocate descriptors
	_or cx,cx                        ; if CX = 0, error 8021h
	jz int31fail

	fixpre_mov edx,[cs:-pmodewk+gdtbase]              ; get base of GDT
	fixpre_movzx_word eax,cs,-pmodewk+gdtlimit           ; EAX = last selector index
	and al,0f8h

	_mov bx,cx                       ; BX = number of selectors to find
.int310000l0:
	test byte [edx+eax+6],10h    ; is descriptor used?
	jnz short .int310000l0f0

	dec bx                          ; found free descriptor, dec counter
	jnz short .int310000l0f1        ; continue if need to find more

	_mov ebx,eax                     ; found all descriptors requested
.int310000l1:
	mov dword [edx+ebx],0        ; set entire new descriptor
	mov dword [edx+ebx+4],109200h
	add bx,8                        ; increment selector index
	dec cx                          ; dec counter of descriptors to mark
	jnz .int310000l1                ; loop if more to mark

	jmp int31okax                   ; return ok, with AX

.int310000l0f0:
	_mov bx,cx                       ; reset number of selectors to find

.int310000l0f1:
	sub ax,strict word 8                        ; dec current selector counter
	cmp ax,strict word 8*SYSSELECTORS           ; more descriptors to go?
	jae .int310000l0               ; if yes, loop

	jmp int31fail                   ; did not find descriptors

int310001:                              ; free descriptor
	call int31testsel               ; test for valid selector BX

	and byte [edi+ebx+6],0efh    ; mark descriptor as free

	mov cx,4                        ; zero any segregs loaded with BX
	lea ebp,[esp+32]                ; EBP -> selectors on stack
.int310001l0:
	cmp [ebp],bx                    ; selector = BX?
	jne short .int310001l0f0        ; if no, continue loop

	mov word [ebp],0                ; zero selector on stack

.int310001l0f0:
	add ebp,2                       ; increment selector ptr
	loop .int310001l0               ; loop

	jmp int31ok                     ; return ok

int310002:                              ; segment to descriptor
	mov ecx,09200000h               ; convert seg value to descriptor val
	_mov cx,bx
	shl ecx,4

	fixpre_mov edi,[cs:-pmodewk+gdtbase]              ; EDI -> base of GDT
	mov eax,8*FREESELECTORS

	jmp short .00

.00l:
	cmp [edi+eax+2],ecx
	je short .01

	add ax,strict word 8

.00:
	cmp ax,[cs:-pmodewk+gdtfree]
	jb .00l

	test byte [edi+eax+6],10h    ; is descriptor used?
	jnz int31fail                   ; if used, fail

	mov word [edi+eax],-1        ; set up descriptor
	mov [edi+eax+2],ecx
	mov word [edi+eax+6],10h

	add word [fs:-pmodewk+gdtfree],8         ; set new base of free selectors

.01:
	jmp int31okax                   ; return ok with selector

int310003:                              ; get selector increment value mov
	mov ax,8                        ; selector increment value is 8
	jmp int31okax                   ; return ok, with AX

int310006:                              ; get segment base address
	call int31testsel               ; test for valid selector BX

	mov dx,[edi+ebx+2]           ; low word of 32bit linear address
	mov cl,[edi+ebx+4]           ; high word of 32bit linear address
	mov ch,[edi+ebx+7]

	jmp int31okcx                   ; return ok, with CX, DX, AX

int310007:                              ; set segment base address
	call int31testsel               ; test for valid selector BX

	mov [edi+ebx+2],dx           ; low word of 32bit linear address
	mov [edi+ebx+4],cl           ; high word of 32bit linear address
	mov [edi+ebx+7],ch

	jmp int31ok                     ; return ok

int310008:                              ; set segment limit
	call int31testsel               ; test for valid selector BX

	cmp cx,0fh                      ; limit greater than 1M?
	jbe short .int310008f0

	_mov ax,dx                       ; yup, limit greater than 1M
	and ax,strict word 0fffh
	cmp ax,strict word 0fffh                    ; low 12 bits set?
	jne int31fail                   ; if no, error 8021h

	shrd dx,cx,12                   ; DX = low 16 bits of page limit
	shr cx,12                       ; CL = high 4 bits of page limit
	or cl,80h                       ; set granularity bit in CL

.int310008f0:
	mov [edi+ebx],dx             ; put low word of limit
	and byte [edi+ebx+6],70h     ; mask offset G and high nybble of limit
	or [edi+ebx+6],cl            ; put high nybble of limit

	jmp int31ok                     ; return ok

int310009:                              ; set descriptor access rights
	call int31testsel               ; test for valid selector BX

	call int31testaccess            ; test access bits in CX

	or ch,10h                       ; set AVL bit, descriptor used
	and ch,0f0h                     ; mask offset low nybble of CH
	and byte [edi+ebx+6],0fh     ; mask offset high nybble access rights
	or [edi+ebx+6],ch            ; or in high access rights byte
	mov [edi+ebx+5],cl           ; put low access rights byte

	jmp int31ok                     ; return ok

int31000a:                              ; create alias descriptor
	call int31testsel               ; test for valid selector BX

	mov cx,1                        ; allocate descriptor
	_xor ax,ax
	int 31h
	jc int31fail                    ; if failed, descriptor unavailable

	push ax                         ; preserve allocated selector

	push ds                         ; copy descriptor and set type data
	pop es
	movzx edi,ax                    ; EDI = target selector
	fixpre_mov esi,[cs:-pmodewk+gdtbase]              ; ESI -> GDT
	_add edi,esi                    ; adjust to target descriptor in GDT
	_add esi,ebx                    ; adjust to source descriptor in GDT

	fixstr a32, movsd               ; copy descriptor
	fixstr a32, lodsd
	mov ah,92h                      ; set descriptor type - R/W up data
	fixstr a32, stosd

	pop ax                          ; restore allocated selector

	jmp int31okax                   ; return ok, with AX

int31000b:                              ; get descriptor
	call int31testsel               ; test for valid selector BX

	lea esi,[edi+ebx]               ; ESI -> descriptor in GDT
	mov edi,[esp]                   ; get EDI buffer ptr from stack
	fixstr a32, movsd               ; copy descriptor
	fixstr a32, movsd

	jmp int31ok                     ; return ok

int31000c:                              ; set descriptor
	call int31testsel               ; test for valid selector BX

	mov esi,[esp]                   ; ESI = EDI buffer ptr from stack
	mov cx,[es:esi+5]               ; get access rights from descriptor
	call int31testaccess            ; test access bits in CX

	push ds                         ; swap DS and ES, target and source
	push es
	pop ds
	pop es

	_add edi,ebx                     ; adjust EDI to descriptor in GDT
	fixstr a32, movsd      ; copy descriptor
	a32 movsw
	a32 lodsw
	or al,10h                       ; set descriptor AVL bit
	a32 stosw

	jmp int31ok                     ; return ok

;
; DOS MEMORY BLOCK FUNCTIONS
;

int310100:                              ; allocate DOS memory block
	mov ah,48h
	call int3101doscall
	jc int31failbx

	_mov dx,ax

	mov bx,ds
	mov ax,0ah
	int 31h
	jnc short .int310100f0

	mov ah,49h
	call int3101doscall
	jmp int31fail

.int310100f0:
	_mov bx,ax
	push dx

	_mov cx,dx
	shl dx,4
	shr cx,12
	mov ax,7
	int 31h

	_mov dx,bx
	pop ax
	jmp int31okdx

int310101:                              ; free DOS memory block
	_mov si,dx
	mov ah,49h
	call int3101dossegcall
	_mov bx,si
	jc int31failax

	jmp int310001

int310102:                              ; resize DOS memory block
	mov ah,4ah
	call int3101dossegcall
	jc int31failbx

	jmp int31ok

int3101dossegcall:
	pop bp

	multipush ax, bx
	_mov bx,dx
	mov ax,6
	int 31h
	multipop bx, ax
	jc int31fail

	shrd dx,cx,4
	push bp

int3101doscall:
	_xor ecx,ecx
	push ecx
	sub esp,0ah
	push dx
	push cx
	pushad

	push ss
	pop es
	_mov edi,esp

	mov bl,21h
	mov ax,300h
	int 31h

	mov bx,[esp+10h]
	mov ax,[esp+1ch]

	lea esp,[esp+32h]
	pop bp
	jc int31fail

	bt word [esp-14h],0
	jmp bp

;
; INTERRUPT FUNCTIONS
;

int31remapIRQnum:                       ; remap logical IRQ number to physical
	multipush ax, cx

	mov cx,[cs:-pmodewk+picslave]
	_mov bh,bl
	and bh,0f8h
	_mov al,bl
	and al,7

	cmp bh,70h
	jne short .00

	_mov bl,cl
	jmp short .01

.00:
	cmp bh,8
	jne short .01

	_mov bl,ch

.01:
	_or bl,al

	multipop cx, ax
	ret

int310200:                              ; get real mode interrupt vector
	movzx ebx,bl                    ; EBX = BL (interrupt number)
	shl bx,2                        ; BX -> interrupt vector

	mov dx,[ebx]                 ; load real mode vector offset
	mov cx,[ebx+2]               ; load real mode vector segment

	jmp int31okcx                   ; return ok, with CX, DX, AX

int310201:                              ; set real mode interrupt vector
	movzx ebx,bl                    ; EBX = BL (interrupt number)
	shl bx,2                        ; BX -> interrupt vector

	mov [ebx],dx                 ; set real mode vector offset
	mov [ebx+2],cx               ; set real mode vector segment

	jmp int31ok                     ; return ok

int310204:                              ; get protected mode interrupt vector
	call int31remapIRQnum           ; remap logical IRQ number to physical

	movzx ebx,bl                    ; EBX = BL (interrupt number)

%if EXCEPTIONS
	cmp bl,0eh                      ; exception interrupt?
	ja short .00                   ; if no, process normally

	lea ebx,[ebx*2+ebx]             ; adjust for location in vector table
	shl bx,1

	fixpre_mov edx,[cs:-pmodewk+exceptionivect+bx] ; get offset of vector
	mov cx,[cs:-pmodewk+exceptionivect+bx+4] ; get selector of vector

	jmp int31okedx                  ; return ok, with EDX, CX, AX
%else
	cmp bl,3                        ; INT 3 vector?
	je short .int310204f00         ; if yes, go to special INT 3 handling
%endif

.00:
	shl ebx,3                       ; adjust for location in IDT
	fixpre_add ebx,[cs:-pmodewk+idtbase]              ; add base of IDT

	mov edx,[ebx+4]    ; get high word of offset
	mov dx,[ebx]        ; get low word of offset
	mov cx,[ebx+2]      ; get selector

	jmp int31okedx                  ; return ok, with EDX, CX, AX

%if EXCEPTIONS==0
.int310204f00:
	fixpre_mov edx,[cs:-pmodewk+int3vector+0]  ; get offset of INT 3
	mov cx,[cs:-pmodewk+int3vector+4]        ; get selector of INT 3

	jmp int31okedx                  ; return ok, with EDX, CX, AX
%endif

int310205:                              ; set protected mode interrupt vector
	call int31remapIRQnum           ; remap logical IRQ number to physical

	_xchg bx,cx                     ; swap int number with int selector
	call int31testsel               ; test for valid selector BX
	_xchg bx,cx                     ; swap int number with int selector

	_mov bh,bl                      ; isolate IRQ base interrupt number
	and bh,0f8h
	mov ax,[cs:-pmodewk+picslave]   ; AX = PIC interrupt numbers

	_cmp bh,ah                      ; low IRQ?
	je short .int310205f2

	_cmp bh,al                      ; high IRQ?
	jne short .int310205f1

	sub bh,8

.int310205f2:
	movzx eax,bl                    ; EAX = IRQ number
	_sub al,bh
	lastdd 0x66, 0x64, 0x67, 0x0f, 0xb6, 0xb8, -pmodewk+defirqintnum  ; movzx edi,byte [dword fs:-pmodewk+defirqintnum+eax]  ; EDI = default IRQ interrupt number  ; `Diff: effective address `dword' (but effectively `word') is because of missed TASM optimization.  ; Diff: TASM encodes the 0x66 prefix, then the segment prefix, NASM does it the other way round.

	cmp cx,SELCODE                  ; setting to default handler?
	je short .int310205f3

	bts [fs:-pmodewk+irqhookmap],ax            ; no, set up real mode pass-up hook
	lea esi,[-pmodewk+rmirqmatrix+eax*4]
	reloc add esi, strict dword PMODE_TEXT<<16
	mov [edi*4],esi

	jmp short .int310205f1

.int310205f3:
	btr [fs:-pmodewk+irqhookmap],ax            ; resetting default handler
	jnc short .int310205f1

	fixpre_mov esi,[cs:-pmodewk+rmirqvector+eax*4]
	mov [edi*4],esi              ; restore real mode vector to old one

.int310205f1:                          ; check for real mode pass-up INTs
	movzx ebx,bl                    ; EBX = BL (interrupt number)

	_xor si,si                       ; index 0, INT 1Ch

	cmp bl,1ch                      ; INT 1Ch timer interrupt?
	je short .int310205f4

	add si,4                        ; index 1, INT 23h

	cmp bl,23h                      ; DOS break interrupt?
	je short .int310205f4

	add si,4                        ; index 2, INT 24h

	cmp bl,24h                      ; DOS critical error interrupt?
	jne short .int310205f5

.int310205f4:
	lea edi,[4*ebx]                 ; EDI = rel mode interrupt vector addx
	fixpre_mov eax,[cs:-pmodewk+rmintvector+di]      ; get old RM pass up int vector

	cmp cx,SELCODE                  ; resetting original vector?
	je short .int310205f6          ; if yes, restore RM int vector

	fixpre_mov eax,[word cs:-pmodewk+int1ccallback+si]    ; get callback address for pass up int  ; `Diff: effective address `word' is because of missed TASM optimization.

.int310205f6:
	mov [di],eax                 ; store new RM interrupt address

.int310205f5:                          ; set actual vector
%if EXCEPTIONS
	cmp bl,0eh                      ; exception interrupt?
	ja short .00                   ; if no, process normally

	lea ebx,[ebx*2+ebx]             ; adjust for location in vector table
	shl bx,1

	fixpre2_mov [fs:-pmodewk+exceptionivect+bx],edx ; set offset of vector
	mov [fs:-pmodewk+exceptionivect+bx+4],cx ; set selector of vector

	jmp int31ok                     ; return ok
%else
	cmp bl,3                        ; INT 3 vector?
	jne short .00                  ; if no, normal interrupt vector set

	fixpre2_mov [fs:-pmodewk+int3vector+0],edx      ; set offset of INT 3
	mov [fs:-pmodewk+int3vector+4],cx        ; set selector of INT 3

	jmp int31ok                     ; return ok
%endif

.00:
	shl ebx,3                       ; adjust for location in PM IDT
	fixpre_add ebx,[cs:-pmodewk+idtbase]              ; add base of IDT

	mov [ebx],dx        ; set low word of offset
	shr edx,16
	mov [ebx+6],dx      ; set high word of offset
	mov [ebx+2],cx      ; set selector

	jmp int31ok                     ; return ok

int310900:                              ; get and disable interrupt state
	btc word [esp+28h+8],9      ; test and clear IF bit in EFLAGS

int310900f0:
	setc al                         ; set AL = carry (IF flag from EFLAGS)

int310900f1:
	add esp,20h                     ; adjust stack

	jmp int31oknopopgeneral         ; return ok, dont pop general regs

int310901:                              ; get and enable interrupt state
	bts word [esp+28h+8],9      ; test and set IF bit in EFLAGS

	jmp int310900f0                 ; return ok, dont pop registers

int310902:                              ; get interrupt state
	bt word [esp+28h+8],9       ; just test IF bit in EFLAGS

	jmp int310900f0                 ; return ok, dont pop registers

;
; REAL/PROTECTED MODE TRANSLATION FUNCTIONS
;

int310300:                              ; simulate real mode interrupt
	movzx ebx,bl                    ; get real mode INT CS:IP
	mov ebp,[ebx*4]
	jmp short int31030201           ; go to common code

int310301:                              ; call real mode FAR procedure
					; same start as function 0302h
int310302:                              ; call real mode IRET procedure
	fixpre_mov ebp,[es:edi+2ah]  ; get target CS:IP from structure

int31030201:                            ; common to 0300h, 0301h, and 0302h
	db 0x66, 0x26, 0x67, 0x0f, 0xb7, 0x5f, 0x2e  ; movzx ebx,word [es:edi+2eh] ; EBX = SP from register structure  ; Diff: TASM encodes the 0x66 prefix, then the segment prefix, NASM does it the other way round.
	db 0x66, 0x26, 0x67, 0x0f, 0xb7, 0x57, 0x30  ; movzx edx,word [es:edi+30h] ; EDX = SS from register structure  ; Diff: TASM encodes the 0x66 prefix, then the segment prefix, NASM does it the other way round.


	_mov ax,bx                       ; check if caller provided stack
	_or ax,dx
	jnz short .int31030201f3       ; if yes, go on to set stack

	mov dx,[cs:-pmodewk+rmstacktop]            ; DX = SS for real mode redirection
	mov bx,[cs:-pmodewk+_pm_rmstacklen]        ; get size of real mode stack
	_sub dx,bx                       ; adjust DX to next stack location

	cmp dx,[cs:-pmodewk+rmstackbase]           ; exceeded real mode stack space?
	jb abort_INT3103                ; if yes, abort

	mov [fs:-pmodewk+rmstacktop],dx            ; update ptr for possible reenterancy
	shl bx,4                        ; adjust BX from paragraphs to bytes

.int31030201f3:
	lea edi,[edx*4]                 ; EDI -> top of real mode stack
	lea edi,[edi*4+ebx]

	mov ax,ss                       ; preserve top of stack parms for
	xchg ax,[fs:-pmodewk+pmstackss]            ;  possible reenterancy
	push ax
	lea eax,[esp-4]
	fixpre_xchg eax,[fs:-pmodewk+pmstackesp]
	push eax

	movzx eax,cx                    ; EAX = length of stack parms
	shl ax,1
	sub bx,2eh                      ; adjust real mode SP for needed vars
	_sub bx,ax                       ; adjust real mode SP for stack parms

	push ds                         ; swap DS and ES
	push es
	pop ds
	pop es

	std                             ; string copy backwards

	sub edi,2                       ; copy stack parms from protected mode
	movzx ecx,cx                    ;  stack to real mode stack
	lea esi,[esp+ecx*2+3ah-2]
	rep ss a32 movsw

	mov esi,[esp+6]                 ; ESI = offset of structure from stack
	mov ax,[esi+20h]                ; AX = FLAGS from register structure

	cmp byte [esp+34],1         ; check AL on stack for function code
	je short .int31030201f4        ; if function 0301h, go on

	and ah,0fch                     ; 0300h or 0302h, clear IF and TF flag
	a32 stosw          ; store data for real mode return IRET

	dec bx                          ; decrement stack pointer for FLAGS
	dec bx

.int31030201f4:
	cld                             ; string copy forward

	lea edi,[edx*4]                 ; EDI -> bottom of stack
	lea edi,[edi*4+ebx]

	mov cl,8                        ; copy general regs to real mode stack
	fixstr rep, a32, movsd

	add esi,6                       ; copy FS and GS to real mode stack
	fixstr a32, movsd

%if 0 ; `%if SIZEOPT' disabled. It doesn't make the compressed .exe any shorter.
	reloc mov dword [es:edi+6],(-pmodewk+.int31030201f1)|(PMODE_TEXT<<16)  ; return address from call
%else
	reloc mov word [es:edi+8],PMODE_TEXT      ; return address from call
	mov word [es:edi+6],-pmodewk+.int31030201f1
%endif

	mov [es:edi+4],ax               ; store FLAGS for real mode IRET maybe
	fixpre2_mov [es:edi],ebp      ; put call address to real mode stack

	mov cx,[esi-8]                  ; real mode ES from register structure
	mov ax,[esi-6]                  ; real mode DS from register structure

%if FEWRELOCS  ; Do it without relocation.
	mov si,[es:edi+8]               ; SI := real mode target CS == relocated(PMODE_TEXT).
	mov di,-pmodewk+.int31030201f0  ; DI := real mode target IP
%else
	mov di,-pmodewk+.int31030201f0  ; DI := real mode target IP
	reloc mov si,PMODE_TEXT         ; SI := real mode target CS == relocated(PMODE_TEXT).
%endif

	                                ; JMP DWORD PTR, as in 32bit offset,
	fixpre_jmp_dword [cs:-pmodewk+pmtormswrout]    ;  not seg:16bit offset

.int31030201f0:                        ; real mode INT, FAR, or IRET call
	popad                           ; load regs with call values
	multipop fs, gs

	iret                            ; go to call address

.int31030201f1:
	multipush gs, fs, ds, es                ; store registers on stack
	pushf                           ; store flags on stack
	pushad
	cli

	mov ax,ss                       ; EAX = linear ptr to SS
	movzx eax,ax
	shl eax,4

	movzx ebp,sp                    ; EBP -> stored regs on stack
	_add ebp,eax

	fixpre_mov ebx,[cs:-pmodewk+pmstackesp]           ; get protected mode SS:ESP
	mov dx,[cs:-pmodewk+pmstackss]

	mov edi,-pmodewk+.int31030201f2     ; target CS:EIP in protected mode
	mov si,SELCODE
	mov cx,SELDATA                  ; ES selector value for protected mode
	mov ax,SELZERO                  ; DS selector value for protected mode

	jmp word [cs:-pmodewk+rmtopmswrout]             ; go back to protected mode

.int31030201f2:
	cld

	push es                         ; FS = ES (SELDATA)
	pop fs

	fixpre_pop_dword [es:-pmodewk+pmstackesp]               ; restore old stack parameter length
	pop word [es:-pmodewk+pmstackss]

	mov es,[esp+36]        ; get structure ES:EDI from stack
	mov edi,[esp]
	_mov esi,ebp                     ; copy return regs from real mode
	mov ecx,15h                     ;  stack to register structure
	rep a32 movsw

	fixpre_cmp_dword_byte [es:edi+4],0      ; stack provided by caller?
	jne int31ok                     ; if yes, done now

	mov ax,[cs:-pmodewk+_pm_rmstacklen]        ; restore top of real mode stack
	add [fs:-pmodewk+rmstacktop],ax

	jmp int31ok                     ; return ok

int310303:                              ; allocate real mode callback address
	mov bl,[cs:-pmodewk+_pm_callbacks]         ; CL = total number of callbacks
	_or bl,bl                        ; are there any?
	jz int31fail                    ; if no, error 8015h

	fixpre_mov edx,[cs:-pmodewk+callbackbase]         ; EDX -> base of callbacks
	_mov ecx,edx                     ; for later use

.int310303l0:
	cmp word [edx+3],0          ; is this callback free?
	jz short .int310303f0          ; if yes, allocate

	add edx,25                      ; increment ptr to callback
	dec bl                          ; decrement loop counter
	jnz .int310303l0               ; if more callbacks to check, loop

	jmp int31fail                   ; no free callback, error 8015h

.int310303f0:
	mov bx,[esp+38]                 ; BX = caller DS from stack
	mov [edx+3],bx                  ; store callback parms in callback
	mov [edx+7],esi
	mov [edx+12],es
	mov [edx+16],edi

	_sub edx,ecx                     ; DX = offset of callback
	shr ecx,4                       ; CX = segment of callback

	jmp int31okcx                   ; return ok, with CX, DX, AX

int310304:                              ; free real mode callback address
	cmp cx,[cs:-pmodewk+callbackseg]           ; valid callback segment?
	jne int31fail                   ; if no, error 8024h

	movzx ebx,dx                    ; EBX = offset of callback

	_xor ax,ax                      ; check if valid offset
	_xchg dx,ax
	mov cx,25
	div cx

	_or dx,dx                        ; is there a remainder
	jnz int31fail                   ; if yes, not valid, error 8024h

	_or ah,ah                        ; callback index too big?
	jnz int31fail                   ; if yes, not valid, error 8024h

	cmp al,[cs:-pmodewk+_pm_callbacks]         ; callback index out of range?
	jae int31fail                   ; if yes, not valid, error 8024h

	fixpre_add ebx,[cs:-pmodewk+callbackbase]         ; EBX -> callback
	mov word [ebx+3],0          ; set callback as free

	jmp int31ok                     ; return ok

;
; MISC FUNCTIONS
;

int310305:                              ; get state save/restore addresses
	_xor ax,ax                       ; size needed is none
	mov cx,-pmodewk+vxr_saverestorerm    ; same offset of 16bit RETF
	mov edi,-pmodewk+vxr_saverestorepm   ; offset of simple 32bit RETF

int310305f0:
	mov si,cs                       ; selector of routine is this one
	reloc mov bx,PMODE_TEXT         ; real mode seg of RETF

	jmp int310900f1

int310306:                              ; get raw mode switch addresses
	fixpre_mov edi,[cs:-pmodewk+pmtormswrout]         ; offset in this seg of rout
	mov cx,[cs:-pmodewk+rmtopmswrout]          ; offset of rout in real mode

	jmp int310305f0

%if GETVERSION
int310400:                              ; get version
	mov ax,5ah                      ; return version 0.9
	mov bx,3                        ; capabilities
	mov cl,[cs:-pmodewk+processortype]         ; processor type
	mov dx,[cs:-pmodewk+picslave]   ; master and slave PIC values

	jmp int310900f1
%endif

;
; EXTENDED MEMORY FUNCTIONS
;

int3105ff:                              ; initialize protected mode system
	cmp byte [cs:-pmodewk+pmodetype],2
	jne .00

	fixpre_movzx_byte esi,cs,-pmodewk+pagetablenum
	shl esi,12

	fixpre_mov ecx,[cs:-pmodewk+pagetablebase]
	fixpre_mov ebx,[cs:-pmodewk+pagetablefree]
	_add esi,ecx
	_sub esi,ebx

	shl esi,10

	call extmemadjust
	_xor ebp,ebp
	shr esi,12
	jz short .01

	mov byte [fs:-pmodewk+cleanuptype],4

	_mov eax,ebx
	_sub eax,ecx
	shl eax,10
	fixpre2_mov [fs:-pmodewk+extmembase],eax

.00l:
	mov ax,0de04h
	fixpre_call_dword far [cs:-pmodewk+vcpi_calleip]

	_or ah,ah
	jnz short .01

	and dh,0f0h
	mov dl,7
	mov [ebx],edx

	inc ebp
	add ebx,4

	dec esi
	jnz .00l

.01:
	fixpre2_mov [fs:-pmodewk+pagetablepages],ebp

	jz .03

	_mov esi,ebp
	shl esi,12
	fixpre_sub esi,[cs:-pmodewk+_pm_maxextmem]
	jae .03

	neg esi
	shr esi,12
	jz .03

	fixpre_movzx_word ecx,cs,-pmodewk+xms_mem
	_or cx,cx
	jz .03

	fixpre_movzx_byte eax,cs,-pmodewk+pagetablenum
	shl eax,12
	fixpre_add eax,[cs:-pmodewk+pagetablebase]
	_sub eax,ebx
	shr eax,2

	_cmp esi,eax
	jb short .06

	_mov esi,eax

.06:
	multipush ebx, edi

	push ss
	pop es
	sub esp,32h
	_mov edi,esp

	_xor ebx,ebx
	; The size optimization of using EDI instead of ESP here wouldn't make the compressed pmodew.exe shorter.
	mov [esp+20h],bx
	mov [esp+2eh],ebx
	fixpre_mov eax,[cs:-pmodewk+xms_callip]
	mov [esp+2ah],eax

	shl esi,2
	_cmp esi,ecx
	jb short .05

	_mov esi,ecx

.05:
	mov [esp+14h],si
	mov byte [esp+1dh],9
	_xor cx,cx
	mov ax,301h
	int 31h

	cmp [esp+1ch],bx
	je short .04

	mov ax,[esp+14h]
	mov [fs:-pmodewk+xms_handle],ax
	or byte [fs:-pmodewk+vcpi_memused],1

	mov byte [esp+1dh],0ch
	mov ax,301h
	int 31h

	cmp [esp+1ch],bx
	je short .04

	mov ax,[esp+14h]
	shl eax,16
	mov ax,[esp+10h]

	lea ebx,[eax+0fffh]
	and bx,0f000h
	_sub ebx,eax
	_add eax,ebx

	shl esi,10
	_sub esi,ebx
	shr esi,12
	jz short .04

	push ds
	pop es

	mov edi,[esp+32h+4]
	or al,7

.02l:
	fixstr a32, stosd

	inc ebp
	add eax,1000h

	dec esi
	jnz .02l

	mov [esp+32h+4],edi

.04:
	add esp,32h

	multipop edi, ebx

.03:
	fixpre_mov eax,[cs:-pmodewk+vcpi_cr3]
	mov cr3,eax

%if INT3108FUNC
	fixpre_movzx_byte ecx,cs,-pmodewk+_pm_pampagemax
	_sub ebp,ecx
	jnc short .02

	_add ecx,ebp
	_xor ebp,ebp
%endif

.02:
	shl ebp,12
	fixpre2_mov [fs:-pmodewk+extmemsize],ebp

%if INT3108FUNC
	_or cl,cl
	jz .00

	push edi

	push ds
	pop es

	_mov esi,ecx
	shl esi,2
	neg esi
	_add esi,ebx

	fixpre_mov edx,[cs:-pmodewk+pagetablebase]

	_mov edi,esi
	_sub edi,edx
	shl edi,10
	push edi

	_mov ebp,ecx

	shl ecx,10
	_xor eax,eax
	fixstr rep, a32, stosd
	push edi

	lea edi,[edx-800h]

	_xor ebx,ebx
	cmp byte [cs:-pmodewk+processortype],3
	seta bl
	cmp bl,1
	cmc
	rcl bx,4

.01l:
	fixstr a32, lodsd
	_or eax,ebx
	fixstr a32, stosd

	dec ebp
	jnz .01l

	pop ecx
	pop eax
	pop edi

	fixpre2_mov [fs:-pmodewk+pampagetop],ecx
	fixpre2_mov [fs:-pmodewk+pampagebase],eax
	mov [fs:-pmodewk+pampagemask],bx

	mov word [fs:-pmodewk+int3108routtbl+0],-pmodewk+int310800
	mov word [fs:-pmodewk+int3108routtbl+2],-pmodewk+int310801

	fixpre_mov eax,[cs:-pmodewk+vcpi_cr3]
	mov cr3,eax
%endif

.00:
	fixpre_mov esi,[cs:-pmodewk+extmemsize]
	fixpre_mov edx,[cs:-pmodewk+extmembase]

	_or esi,esi
	jz int31ok

	sub esi,12
	lea ebx,[edx+esi+8]
	fixpre2_mov [fs:-pmodewk+extmemlast],ebx

	mov eax,80000000h
	mov [edx],eax
	mov [edx+4],esi
	mov [ebx],eax

%if FREEMEMINFO
	mov word [fs:-pmodewk+int3105routtbl+0],-pmodewk+int310500
%endif
	mov word [fs:-pmodewk+int3105routtbl+2],-pmodewk+int310501
	mov word [fs:-pmodewk+int3105routtbl+4],-pmodewk+int310502
	mov word [fs:-pmodewk+int3105routtbl+6],-pmodewk+int310503

	jmp int31ok

%if FREEMEMINFO
int310500:                              ; get free memory information
	fixpre_mov ebp,[cs:-pmodewk+extmemlast]
	fixpre_mov esi,[cs:-pmodewk+extmembase]
	_xor eax,eax

@l00l:
	mov ebx,[esi]
	btr ebx,31
	jc short @l01

	_cmp ebx,eax
	jb short @l01

	_mov eax,ebx

@l01:
	lea esi,[esi+ebx+4]

	_cmp esi,ebp
	jb @l00l

@l00:
	jmp short int310500mem

int310500nomem:
	_xor eax,eax

int310500mem:
	fixstr a32, stosd
	mov ecx,0bh
	or eax,-1
	fixstr rep, a32, stosd

	jmp int31ok
%endif

int310501:                              ; allocate a block of memory
	call int3105blocksize

	_mov eax,ebx
	call _pma_alloc

int310501got:
	_or eax,eax
	jz int31fail

	_mov di,ax
	_mov cx,ax
	shr eax,16
	_mov si,ax
	_mov bx,ax

	mov [esp+4],si                  ; put SI onto stack for POPAD
	mov [esp],di                    ; put DI onto stack for POPAD
	mov [esp+16],bx                 ; put BX onto stack for POPAD
	mov [esp+24],cx                 ; put CX onto stack for POPAD

	jmp int31ok

int3105blocksize:
	pop bp

	cmp bx,7fffh
	jae int31fail

	shl ebx,16
	_mov bx,cx

	jmp bp

int310502:                              ; free a block of memory
	shl esi,16
	_mov si,di
	_mov eax,esi
	call _pma_free

	jmp int31ok

int310503:                              ; resize a block of memory
	call int3105blocksize

	shl esi,16
	_mov si,di
	_mov eax,esi

	push -pmodewk+int310501got
	jmp _pma_realloc

_pma_alloc:                             ; allocate a block
	push ebx
	push edi

	add eax, 3
	and al, ~3

	fixpre_mov ebp,[cs:-pmodewk+extmemlast]
	fixpre_mov edi,[cs:-pmodewk+extmembase]

@a00l:
	mov ebx,[edi]
	_cmp ebx,eax
	jl short @a01
	je short @a02

	_sub ebx,eax
	sub ebx,4
	mov [edi+eax+4],ebx

@a02:
	or eax,80000000h
	mov [edi],eax
	lea eax,[edi+4]
	jmp short @a00

@a01:
	and ebx,7fffffffh
	lea edi,[edi+ebx+4]

	_cmp edi,ebp
	jb @a00l

@a03:
	_xor eax,eax

@a00:
	pop edi
	pop ebx
	ret

_pma_free:                              ; free a block
	call pma_findblock
	jnc short @f00

	mov ecx,[edi+ebx+4]
	btr ecx,31
	jc short @f01

	lea ebx,[ebx+ecx+4]

@f01:
	mov ecx,[esi]
	btr ecx,31
	jc short @f02

	_mov edi,esi
	lea ebx,[ebx+ecx+4]

@f02:
	mov [edi],ebx

@f00:
	ret

_pma_realloc:                           ; reallocate (resize) a block
	push ds
	pop es

	lea edx,[ebx+3]
	and dl,0fch

	call pma_findblock
	mov eax,0
	jnc @r00

	_cmp ebx,edx
	ja @r02
	je @r01

	mov ecx,[edi+ebx+4]
	btr ecx,31
	jc short @r03

	lea eax,[ecx+ebx+4]
	_cmp eax,edx
	ja @r04
	je @r05

	mov ecx,[esi]
	btr ecx,31
	jc short @r06

	lea ecx,[ecx+eax+4]
	_cmp ecx,edx
	jb short @r06

	_mov ebx,eax
	jmp short @r07

@r03:
	mov ecx,[esi]
	btr ecx,31
	jc short @r06

	lea ecx,[ecx+ebx+4]
	_cmp ecx,edx
	jb short @r06

@r07:
	_xchg edi,esi
	add esi,4
	lea eax,[edx+80000000h]
	fixstr a32, stosd
	_mov eax,edi

	_xchg ecx,ebx
	shr ecx,2
	fixstr rep, a32, movsd

	_sub ebx,edx
	je short @r00

	sub ebx,4
	mov [eax+edx],ebx
	jmp short @r00

@r06:
	_mov eax,edx
	call _pma_alloc
	_or eax,eax
	jz short @r00

	_xchg edi,eax
	lea esi,[eax+4]
	_mov edx,edi

	_mov ecx,ebx
	shr ecx,2
	fixstr rep, a32, movsd

	add eax,4
	call _pma_free

	_mov eax,edx
	jmp short @r00

@r04:
	_mov ebx,eax

@r02:
	_sub ebx,edx
	sub ebx,4
	db 0x66, 0x67, 0x8d, 0x44, 0x1a, 0x08  ; lea eax,[edx+ebx+4+4]  ; Diff: NASM 0.98.39 produces the same output as TASM, but NASM 2.13.02 produces different output.

	mov ecx,[edi+eax]
	btr ecx,31
	jc short @r09

	lea ebx,[ebx+ecx+4]

@r09:
	mov [edi+edx+4],ebx

@r05:
	or edx,80000000h
	mov [edi],edx

@r01:
	lea eax,[edi+4]

@r00:
	ret

pma_findblock:                          ; find a block and test if used
	fixpre_mov ebp,[cs:-pmodewk+extmemlast]
	fixpre_mov edi,[cs:-pmodewk+extmembase]
	lea ebx,[eax-4]

@fb00l:
	_cmp edi,ebx
	je short @fb00

	_mov esi,edi
	mov ecx,[edi]
	and ecx,7fffffffh
	lea edi,[edi+ecx+4]

	_cmp edi,ebp
	jb @fb00l

@fb01:
	clc
	ret

@fb00:
	mov ebx,[edi]
	btr ebx,31
	ret

;
; PHYSICAL ADDRESS MAPPING FUNCTIONS
;
%if INT3108FUNC

int310800:
	push ds
	pop es

	shl ebx,16
	_mov bx,cx

	shl esi,16
	_mov si,di

	cmp esi,0
	jle int31fail

	lea esi,[esi+ebx+0fffh]

	push ebx

	shr ebx,12
	shr esi,12
	_sub ebx,esi
	neg ebx

	call pamlmalloc

	pop eax

	_cmp edx,ebx
	jb int31fail

	_mov edx,eax
	and ax,strict word 0f000h
	_mov ecx,eax
	mov al,7
	or ax,[cs:-pmodewk+pampagemask]

	_mov edi,esi

.00l:
	fixstr a32, stosd
	add eax,1000h

	dec ebx
	jnz .00l

	or byte [esi+1],2           ; set first allocated page as first
	or byte [edi-3],4           ; set last allocated page as last

	fixpre_sub esi,[cs:-pmodewk+pampagebase]
	shl esi,10
	bts esi,31

	_sub edx,ecx
	_add edx,esi

	mov [esp+24],dx                 ; put CX onto stack for POPAD
	shr edx,16
	mov [esp+16],dx                 ; put BX onto stack for POPAD

int3108done:
	fixpre_mov eax,[cs:-pmodewk+vcpi_cr3]
	mov cr3,eax

	jmp int31ok

pamlmalloc:                             ; check for linear memory block
	fixpre_mov edi,[cs:-pmodewk+pampagebase]          ; EDI = search ptr in page table

	fixpre_movzx_byte ecx,cs,-pmodewk+_pm_pampagemax  ; ECX = count of pages to search
	shl ecx,10

	_xor edx,edx                     ; EDX = largest linear block found
	_xor eax,eax                     ; EAX = search unit, free entry (0)

	push ebx                        ; preserve EBX, memory requested

.00l:
	jecxz .01                ; if no more entries, done

	fixstr repne, a32, scasd   ; search for first next free entry
	jne short .01                  ; if no more free, go on

	_mov ebp,ecx                     ; EBP = current count
	lea ebx,[edi-4]                 ; EBX = start of free block

	fixstr repe, a32, scasd          ; search for end of free linear block
	jne short .00                    ; if previous entry not free, go on

	inc ebp                          ; previous entry free, extra one

.00:
	_sub ebp,ecx                     ; EBP = number of free pages in block

	_cmp ebp,edx                     ; new block larger than last largest?
	jb .00l                        ; if no, loop

	_mov esi,ebx                     ; ESI = ptr to largest block found
	_mov edx,ebp                     ; size of new largest block found

	cmp ebp,[esp]                   ; block sufficient for memory request?
	jb .00l                        ; if no, loop

.01:
	pop ebx                         ; restore EBX, memory requested

	ret                             ; return

int310801:
	push ds
	pop es

	btc bx,15
	jnc int31fail

	shl ebx,16
	_mov bx,cx
	shr ebx,10
	and bl,0fch

	fixpre_add ebx,[cs:-pmodewk+pampagebase]
	fixpre_cmp ebx,[cs:-pmodewk+pampagetop]
	jae int31fail

	test byte [ebx+1],2
	jz int31fail

.00l:
	_xor eax,eax
	xchg eax,[ebx]

	add ebx,4
	test ah,4

	jz .00l

	jmp int3108done
%endif

;
; EXCEPTIONS
;
%if EXCEPTIONS

int31exceptionnum:                      ; test and set up exception number
	pop bp

	cmp bl,20h                      ; exception number too high?
	jae int31fail                   ; if yes, fail

	_xor bh,bh                       ; BX = position in vector table
	lea ebx,[2*ebx+ebx]

	cmp bl,6*0eh                    ; check if exception supported

        lastdd 0x66, 0x67, 0x8d, 0x1c, 0x5d, -pmodewk+exceptionevect  ; lea ebx,[2*ebx+-pmodewk+exceptionevect]  ; Diff: TASM and NASM encode this instruction differently.

	jmp bp

int310202:                              ; get processor exception vector
	call int31exceptionnum          ; process exception number

	mov cx,cs                       ; CX:EDX = NULL exception vector
	mov edx,0

	ja short .00                   ; jump if exception not supported

	fixpre_mov edx,[cs:bx]                 ; CX:EDX = exception vector
	mov cx,[cs:bx+4]

.00:
	jmp int31okedx                  ; return ok, with EDX, CX, AX

int310203:                              ; get processor exception vector
	_xchg bx,cx                      ; swap exception number with selector
	call int31testsel               ; test for valid selector BX
	_xchg bx,cx                      ; swap exception selector with number

	call int31exceptionnum          ; process exception number
	ja int31ok                      ; done if exception not supported

	fixpre2_mov [fs:bx],edx                 ; store exception vector
	mov [fs:bx+4],cx

	jmp int31ok                     ; return ok
%endif

;times 0x21c0-($-exe_image) db 0  ; This is a no-op if the size of PMODE_TEXT above remains unchanged.

; --- Based on pmodewe.asm.

;
; PMODE/W DOS Extender - Main Code
;

PMWVER_MAJOR    equ 1
PMWVER_MINOR    equ PMWV

; pmcode16 equ 0x21c  ; For pmodew.exe. It can be e.g. 0x1f9 with some compile-time configuration.
; pmodewe:  ; == equ exe_image+0x21c0  ; equ exe_image+(pmcode16<<4).  ; For pmodew.exe.
reloc_seg pmodewe, pmcode16  ; pmcode16 segment para public use16 'CODE'
;assume cs:pmcode16,ds:pmcode16

%if DEBUG
  %error ERROR_DEBUG_NOT_IMPLEMENTED
  times -1 nop
  ;include debug.inc
%endif
;
; DATA
;
errmsgtbl       dw -pmodewe+errmsg0,-pmodewe+errmsg1,-pmodewe+errmsg2,-pmodewe+errmsg3
		dw -pmodewe+errmsg4,-pmodewe+errmsg5,-pmodewe+errmsg6,-pmodewe+errmsg7
%if LOADSPE==0
		dw -pmodewe+errmsg8,-pmodewe+errmsg9
%endif

%if LOADSPE==3 || SHORTMSG
pmodemsg        db '[PM]: ',36
errmsg0         db 'out of memory!',13,10,36  ; _memoryerr.
errmsg1         db 'no 386+ CPU!',13,10,36  ; Returned as AX=1 CF=1 by _pm_info.
errmsg2         db 'already in PM without DMPI or VCPI!',13,10,36  ; Returned as AX=2 CF=1 by _pm_info.
errmsg3         db 'DPMI host not 32-bit!',13,10,36  ; Returned as AX=3 CF=1 by _pm_info.
errmsg4         db 'A20 error!',13,10,36  ; Returned as AX=4 CF=1 by _pm_init.
errmsg5         db 'DPMI error!',13,10,36  ; _exiterror.  Also returned as AX=5 CF=1 by _pm_init.
errmsg6         db 'selector error!',13,10,36  ; _descriptorerr. Also returned as AX=6 CF=1 by _pm_init.
errmsg7         db 'bad EXE!',13,10,36  ; _loaderror.
%else
pmodemsg        db '[PMODE/W]: $'
errmsg0         db 'Not Enough Memory Available!',36  ; _memoryerr.
errmsg1         db '80386+ Not Detected!',36  ; Returned as AX=1 CF=1 by _pm_info.
errmsg2         db 'System Already In Protected Mode And No VCPI or DPMI found!',36  ; Returned as AX=2 CF=1 by _pm_info.
errmsg3         db 'DPMI Host Is Not 32bit!',36  ; Returned as AX=3 CF=1 by _pm_info.
errmsg4         db 'A20 Error!',36  ; Returned as AX=4 CF=1 by _pm_init.
errmsg5         db 'DPMI Error!',36  ; _exiterror.  Also returned as AX=5 CF=1 by _pm_init.
errmsg6         db 'Unable To Allocate Needed DPMI Selectors!',36  ; _descriptorerr. Also returned as AX=6 CF=1 by _pm_init.
errmsg7         db 'Error Loading EXE!',36  ; _loaderror.
%endif
%if LOADSPE==0
errmsg8         db 'Unrecognized Fixup Data!',36  ; _unknownerror.
errmsg9         db '16bit Fixup Overflow!',36  ; _16biterror.
%endif

%if PMWV==34
%if LOGO
_copyrightmsg   db 'PMODE/W DOS Extender v1.34',10,13
		db 'Copyright (C) 1994-2000, Charles Scheffold and Thomas Pytel'
%endif
%elif PMWV==33
%if LOGO
_copyrightmsg   db 'PMODE/W DOS Extender v1.33',10,13
		db 'Copyright (C) 1994-1997, Charles Scheffold and Thomas Pytel'
%endif
%else
  %error ERROR_UNSUPPORTED_PMWV PMWV
  times -1 nop
%endif
%if LOGO
		db 0,10,13,'$'
%endif

align 4, db 0

%if LOADPMW1 && PMW1UNCOMP==0
decode_bufsize          equ 4096
decode_bufbase          dd ANY   ;decode_buf
decode_bufthreshold     dd ANY   ;decode_buf + decode_bufsize - 16
decode_bufend           dd ANY   ;decode_buf + decode_bufsize
decode_filesize         dd ANY
decode_handle           dw ANY
%endif

_pm16_lowmin    dw ANY

_selbuf         dw ANY  ; Points to _dtabufptr. Size: 100h.
_selcode        dw ANY
_selzero        dw ANY
_selpsp         dw ANY
_selfixup       dw ANY
_exehandle      dw ANY
_pspseg         dw ANY
_envseg         dw ANY
_selrights      dw ANY

_cr0valuerm     dd ANY

_membase        dd ANY
_memtop         dd ANY
%if MEMDEBUG
_membase1	dw ANY  ; Value of _membase (== ES) before calling _pm_init.
_membase2	dw ANY  ; Value of _membase right after _pm_init has returned.
_membase3	dw ANY  ; Value of _membase right before calling _loadexe.
%endif

%if LOADLE || LOADPMW1
FIXUPBUFMIN     equ 4000h         ; Must be a multiple of 16 or you will become
_fixupbufptr    dd ANY           ; a wart on the ass of some big fat dude.
_fixupbufsize   dd ANY
%endif

DTABUFSIZE       equ 200h          ; Must remain at 200h or above
_dtabufptr      dd ANY  ; Size: 200h. Points to linear address (_int21lowdtaseg<<4).
_dtabufptr100h  dd ANY  ; Size: 100h. Points to linear address (_int21lowdtaseg<<4)+100h.

_exebaseoffset  dd ANY

%if LOADLE || LOADPMW1
MAXOBJECTS       equ 16
_objectlocs     times MAXOBJECTS dd ANY
_objectrtoff:
_objectpageidx  times MAXOBJECTS dd ANY
_objectrtblocks:
_objectpagenum  times MAXOBJECTS dd ANY
_objectflags    times MAXOBJECTS dd ANY
_objectsels     times MAXOBJECTS dd ANY

_nextobjectloc  dd ANY
_numobjects     dd ANY
_currentobject  dd ANY

_oldfilepos1    dd ANY
_datapagesloc   dd ANY
%endif

%if INT31VENDOR
_oldint31off    dd ANY
_oldint31sel    dw ANY
%endif

%if LOADSPE
_init_eip       dd ANY  ; EIP of the payload entry point. CS will be 0-based 32-bit data selector.
_init_esp       dd ANY  ; ESP of the payload entry point. DS and SS will be 0-based 32-bit data selector. ES will be the PSP selector.
%else
_init_csobj     dd ANY
_init_csoff     dd ANY
_init_ssobj     dd ANY
_init_ssoff     dd ANY
%endif

_pmode_process  db ANY
_pmode_systype  db ANY  ; Must come directly after _pmode_process.
_inpmode        db 0  ; Possible values: 0 (false), 0xff (true).

borfixgdt       dd 00000000h,00000000h
		dd 0000ffffh,00009200h

borfixgdtaddx   dw 0fh,-pmodewe+borfixgdt,0

;
; INTERRUPT VARIABLES
;

_termrmvect             dd ANY

_int21lowbufseg         dw ANY
_int21lowbufptr         dd ANY

_int21vectoff           dd ANY
_int21vectsel           dw ANY
_int21datasel           dw ANY
_int21datasel64         dw ANY
_int21lowdtaseg         dw ANY
_int21lowbufsel         dw ANY
_int21dtasel            dw ANY
_int21dtaoff            dd ANY

%if INT33
_int33vectoff           dd ANY
_int33vectsel           dw ANY
%endif

%if PMWV==33
  %if INT33 || INT1B
    _int33cursorbufseg  dw ANY
  %endif
%endif
%if INT33
  _int33mousebufsize    dd ANY
  _int33callback        dd 0
  _int33entryflag       db 0
  _int330Ccalloff       dd ANY
  _int330Ccallsel       dw ANY
%endif
%if PMWV!=33
  %if INT33 || INT1B
    _int33cursorbufseg  dw ANY
  %endif
%endif

%if INT1B
_int1Bcallback          dd 0
_int1Bflag              db 0
%endif

_int21lowbufsize        dd 1000h ; MUST Be A Multiple Of 4 Or You Will Suffer!
				 ; (1000h Bytes Is The Minimum)
%if LOGO==0
_copyrightmsg: equ $-1  ; Points to a NUL byte.
%endif

_edi                   equ 0
_esi                   equ 4
_ebp                   equ 8
_ebx                   equ 10h
_edx                   equ 14h
_ecx                   equ 18h
_eax                   equ 1ch
_flags                 equ 20h
_es                    equ 22h
_ds                    equ 24h
_fs                    equ 26h
_gs                    equ 28h
_ip                    equ 2ah
_cs                    equ 2ch
_sp                    equ 2eh
_ss                    equ 30h

;
; EXE DECOMPRESSION CODE
;

%if LOADPMW1 && PMW1UNCOMP==0
;include decode.asm

;
; Decompress from disk to memory.
; In:
;   EDI -> buffer to decode to
;   DS - data selector
;   ES - buffer and output selector
; Out:
;   EAX, EBX, ECX, EDX, ESI, EDI, EBP - ANY
;
decode:
	mov esi,[-pmodewe+decode_bufend]
	call decode_read
	es a32 movsb
	_xor dl,dl
	jmp short decode_decode
decode_extended:
	call decode_getbit
	jnc short decode_length
	call decode_getbit
	adc cl,1
	shl cl,1
.00l:
	call decode_getbit
	rcl bh,1
	loop .00l
decode_length:
	mov dh,2
	mov cl,4
.00l:
	inc dh
	call decode_getbit
	jc short decode_movestringdh
	loop .00l
	call decode_getbit
	jnc short decode_length3bit
	es a32 lodsb
	_mov cl,al
	add ecx,15
	jmp short decode_movestring
decode_length3bit:
	_xor dh,dh
	mov cl,3
.00l:
	call decode_getbit
	rcl dh,1
	loop .00l
	add dh,7
decode_movestringdh:
	_mov cl,dh
	jmp short decode_movestring
decode_movestring2:
	mov cl,2
decode_movestring:
	neg ebx
	dec ebx
.00l:
	mov al,[es:edi+ebx]
	a32 stosb
	loop .00l
decode_decode:
	cmp esi,[-pmodewe+decode_bufthreshold]
	jb short .00
	call decode_read
.00:
	call decode_getbit
	jc short code
	es a32 movsb
	jmp decode_decode
code:
	_xor ebx,ebx
	es a32 lodsb
	_mov bl,al
	call decode_getbit
	jc short decode_extended
	call decode_getbit
	jc short decode_code11
	dec ebx
	jns decode_movestring2
	ret
decode_code11:
	mov cl,3
.00l:
	call decode_getbit
	rcl bh,1
	loop .00l
	jmp short decode_movestring2
decode_getbit:
	dec dl
	jns short .00
	fixstr es a32, lodsd
	_mov ebp,eax
	mov dl,31
.00:
	shl ebp,1
	ret
decode_read:
	multipush edx, edi
	mov edi,[-pmodewe+decode_bufbase]
	push edi
	mov ecx,[-pmodewe+decode_bufend]
	_sub ecx,esi
	_mov edx,ecx
	_mov eax,ecx
	rep es a32 movsb
	pop esi
	mov ecx,decode_bufsize
	_sub ecx,eax
	mov eax,[-pmodewe+decode_filesize]
	_cmp ecx,eax
	jbe short .00
	_mov ecx,eax
.00:
	mov bx,[-pmodewe+decode_handle]
	mov ah,3fh
	int 21h
	sub [-pmodewe+decode_filesize],eax
	multipop edi, edx
	_xor ecx,ecx
	ret
%endif  ; %if PMW1UNCOMP==0

;
; 16-BIT REAL MODE CODE - EXECUTION BEGINS HERE
;
_pm16start:
	push cs
	pop ds
	cld

	reloc call PMODE_TEXT:-pmodewk+_pm_info        ; Get Protected Mode Info/Detect CPU
%if SIZEOPT
	jc _pmstartuperr
%else
	jmp_cond_near c, _pmstartuperr  ; jc strict near _pmstartuperr  ; Diff: TASM doesn't generate the 4-byte 386 `jc near' instruction, but generates a 5-byte `jnc ...' ++ `jmp near ...' combo.
%endif

	cmp ch,1                        ; Borland DPMI Fix For FS/GS
	ja _noborfix1

	cli

	_xor eax,eax
	mov ax,cs
	shl eax,4
	add [-pmodewe+borfixgdtaddx+2],eax

	lgdt [-pmodewe+borfixgdtaddx]

	mov eax,cr0
	or al,1
	mov cr0,eax

	jmp short $+2

	mov bx,8
	mov fs,bx
	mov gs,bx

	and al,0feh
	mov cr0,eax

	jmp short $+2

	sti

_noborfix1:

	mov [-pmodewe+_pspseg],es                  ; Get the PSP and Environment segments
	mov ax,[es:2ch]
	mov [-pmodewe+_envseg],ax

%if SIZEOPT
	mov ax,[es:2]
	mov [-pmodewe+_memtop],ax  ; High word of _memtop is already zero-initialized.
	mov ax,ss
	add ax,strict word (STACKSIZE+0xf)>>4
	mov [-pmodewe+_membase],ax  ; High word of _membase is already zero-initialized.
	; !! Even better size optimization?: initialize _membase dd (STACKSIZE+0xf)>>4, then here add [-pmodewe+_membase],ax
%else
	_xor eax,eax                     ; Get the Base and Top of Low Memory
	mov ax,[es:2]
	mov [-pmodewe+_memtop],eax
	mov ax,ss
	add ax,strict word (STACKSIZE+0xf)>>4
	mov [-pmodewe+_membase],eax
%endif

%if INT33 || INT1B
					; INT 33h Function 9 inherits the old
	mov [-pmodewe+_int33cursorbufseg],ss       ; real mode stack for its buffer
%endif

	mov eax,[-pmodewe+_int21lowbufsize]        ; Allocate the INT 21h Low Buffer
	call _getmem
	jc _memoryerr
	mov [-pmodewe+_int21lowbufseg],ax
	shl eax,4
	mov [-pmodewe+_int21lowbufptr],eax

	mov eax,DTABUFSIZE              ; Allocate the INT 21h Disk Transfer
	call _getmem                    ; Area (DTA) buffer. This buffer
	jc _memoryerr                   ; must remain 200h bytes or above
	mov [-pmodewe+_int21lowdtaseg],ax
	shl eax,4
	mov [-pmodewe+_dtabufptr],eax
	mov [-pmodewe+_int21dtaoff],eax
	add eax,100h
	mov [-pmodewe+_dtabufptr100h],eax

	; * _openexe does both _openexe1 and _openexe2.
	; * _openexe1 finds the filename of the .exe file to open.
	; * _openexe1 implementation changes depending on OPENTYPE.
	; * _openexe2 loads the load-time config, figures out where the
	;   32-bit payload (LE or PMW1) is within the .exe file, and then
	;   saves the figured-out file offset to dword
	;   [_int21lowdtaseg:3ch].
	; * _openexe2 implementation changes depending on VARTYPE.
	; * All implementations of _openexe2 take file offset of the 32-bit
	;   payload from the dword at .exe file offset 3ch.
	; * _loadexe seeks to the file offset of the 32-bit payload
	;   (accessed as [gs:3ch]) within the .exe file, and then loads the
	;   32-bit payload, decompresses it if needed, and applies the
	;   relocations.
	call _openexe  ; Open the EXE file for processing.
	reloc mov ax,PMODE_TEXT
	mov gs,ax                       ; Increase required callbacks for use
	add byte [gs:-pmodewk+_pm_callbacks],5          ; by PMODE/W

%if LOGO
	test byte [gs:-pmodewk+_pm_options],1
	jz short _nostartmsg
	mov dx,-pmodewe+_copyrightmsg
	call _pmsg                      ; Display startup message
_nostartmsg:
%endif

	reloc call PMODE_TEXT:-pmodewk+_pm_info                   ; Get Protected Mode Info again in
	jc _pmstartuperr                ; order to save the proper amount of
					; low memory required by PMODEWK which
					; is determined by the PM variables
					; modified in _openexe2
	movzx edx,bx

	mov eax,cr0                     ; Save the real mode value of CR0
	mov [-pmodewe+_cr0valuerm],eax
	fixpre_mov eax,[es:0ah]
	mov [-pmodewe+_termrmvect],eax

%if SIZEOPT
	mov [-pmodewe+_pmode_process],cx  ; Also updates _pmode_systype.
%else
	mov [-pmodewe+_pmode_process],cl
	mov [-pmodewe+_pmode_systype],ch
%endif

	db 66h,26h,0c7h,6,0ah,0         ; mov dword [es:0xa],-pmodewe+_termhandler+(pmcode16<<16)  ; Install the termination handler  ; Diff: TASM encodes the 0x66 prefix, then the segment prefix, NASM does it the other way round.
	reloc dw -pmodewe+_termhandler,pmcode16

;       MOV DWORD PTR ES:[0Ah], pmcode16:_termhandler

%if SIZEOPT==0
	_xor ax,ax                       ; EDX = PMODEWK's memory requirements
%endif
	mov ebx,[-pmodewe+_memtop]                 ;       in paragraphs
	sub ebx,[-pmodewe+_membase]
	_cmp bx,dx
%if SIZEOPT
	jb _memoryerr                   ; Exit if there is not enough memory
%else
	jb _pmstartuperr                ; Exit if there is not enough memory
%endif
	mov es,[-pmodewe+_membase]      ; otherwise set ES to the block of memory
%if SIZEOPT
	add [-pmodewe+_membase],dx
%else
	add [-pmodewe+_membase],edx
%endif
%if MEMDEBUG
	mov [-pmodewe+_membase1],es
	mov [-pmodewe+_membase2],es
	add [-pmodewe+_membase2],dx
%endif

	reloc call PMODE_TEXT:-pmodewk+_pm_init  ; Initialize and enter Protected Mode
	jc _pmstartuperr

;
; BEGINNING OF 16-BIT PROTECTED MODE CODE - INITIALIZATIONS
;

	mov byte [-pmodewe+_inpmode],0ffh               ; Set protected mode flag for error
					; functions

	mov [-pmodewe+_selpsp],es                  ; Store PSP selector

	_xor edi,edi
	or ecx,-1
	mov ax,cs
	lar dx,ax
	_mov dl,dh
	and dl,60h
	or dl,9ah                       ; Allocate a zero based 32bit code
	mov dh,0c0h                     ; descriptor using the same access
	call _initdescriptor            ; rights as the current CS
	mov [-pmodewe+_selcode],ax

	and dl,~8                       ; Allocate a zero based 32bit data
	mov [-pmodewe+_selrights],dx               ; descriptor using the same access
	call _initdescriptor            ; rights as the current CS

	mov gs,ax                       ; GS = 32bit data selector
	mov [-pmodewe+_selzero],ax
	mov [-pmodewe+_int21dtasel],ax
	mov [-pmodewe+_int21datasel],ax

	mov edi,[-pmodewe+_dtabufptr]              ; Allocate a 32bit data descriptor
	call _initdescriptor            ; based at the start of the DTA Buffer
	mov [-pmodewe+_selbuf],ax

	mov edi,[-pmodewe+_int21lowbufptr]         ; Allocate a 32bit data descriptor
	call _initdescriptor            ; based at the start of the INT 21h
	mov [-pmodewe+_int21lowbufsel],ax          ; Low Buffer

	cmp byte [-pmodewe+_pmode_systype],3            ; If the system type is not DPMI
	jz short _nomeminit1            ; then install DPMI memory system
	mov ax,5ffh
	int 31h
_nomeminit1:

	call _initdosext                ; Install 1Bh, 21h, and 33h handlers
	jc _exiterror

	; !! TODO(pts): Omit if not needed, add -DINT31VENDOR=0.
%if INT31VENDOR
	mov ax,204h
	mov bl,31h
	int 31h
	mov [-pmodewe+_oldint31sel],cx             ; Install INT 31h handler for vendor
	mov [-pmodewe+_oldint31off],edx            ; specific API function (0A00h). This
	mov ax,205h                     ; handler is installed regardless of
	mov cx,cs                       ; the system PMODE/W is running under
	mov edx,-pmodewe+_int310A00       ; and is needed in order for FPU
	int 31h                         ; emulation to work.
%endif
;
; PROTECTED MODE STARTUP
;

	push gs
	pop es                          ; ES = 32bit data selector
%if MEMDEBUG
	push word [-pmodewe+_membase]
	pop  word [-pmodewe+_membase3]
%endif
%if LOADSPE
	push es
	pop fs                          ; FS = 32bit data selector
	mov gs, [-pmodewe+_selbuf]
	call _loadSPE  ; Inlining it would make it longer.
%else
	call _loadexe                   ; Load LE/PMW1 EXE Into Memory
%endif
%if MEMDEBUG && 0  ; Dump all the membase values so far, and exit with a CPU exception.
	mov ebp, 12345601h  ; Exit reason indicator.
	movzx eax, word [-pmodewe+_membase1]
	movzx ebx, word [-pmodewe+_membase2]
	movzx ecx, word [-pmodewe+_membase3]
	movzx edx, word [-pmodewe+_membase]
	movzx esi, word [-pmodewe+_pspseg]
	ud2
%endif

	mov ah,3eh                      ; Close EXE file
	mov bx,[-pmodewe+_exehandle]
	int 21h

%if LOADSPE
	mov edx,[-pmodewe+_init_esp]
%else
	mov edx,[-pmodewe+_init_ssobj]
	mov edx,[-pmodewe+_objectlocs+edx*4-4]
	add edx,[-pmodewe+_init_ssoff]             ; Get initial SS:ESP
%endif

	mov ax,es
	mov ss,ax                       ; Setup stack selector
	_mov esp,edx                     ; and ESP

%if LOADSPE
	mov edx,[-pmodewe+_init_eip]
%else
	mov edx,[-pmodewe+_init_csobj]
	mov edx,[-pmodewe+_objectlocs+edx*4-4]
	add edx,[-pmodewe+_init_csoff]             ; Get initial CS:EIP
%endif

	push dword [-pmodewe+_selcode]         ; 4G 32bit CS
	push edx                        ; 32bit EIP for program start

	sub esp,32h
	_mov ebp,esp
%if SIZEOPT  ; Make it better compressible by moving the `sub esp,32h' and `mov byte [ebp+_eax+1],...' instructions together.
	mov byte [ebp+_eax+1],4ah   ; Resize PMODE/W's DOS memory block
	mov bx,[-pmodewe+_membase]
%else
	mov ebx,[-pmodewe+_membase]  ; We keep this longer version with EBX just for bitwise identical pmodew.exe output.
%endif
	mov ax,[-pmodewe+_pspseg]
	_sub bx,ax
%if MEMDEBUG && 0
	int3
%endif
	mov [ebp+_ebx],bx
	mov [ebp+_es],ax
%if SIZEOPT==0
	mov byte [ebp+_eax+1],4ah   ; Resize PMODE/W's DOS memory block
%endif
	call _realmodeint21             ; using real mode INT 21h Function 4Ah
	add esp,32h

%if LOADSPE
%if 0  ; Also correct but longer.
	mov ax, 6  ; DPMI Get Segment Base Address.
	mov bx, [-pmodewe+_selpsp]
	int 31h  ; DPMI call.
	xchg ax, cx  ; AX := high dword of the linear base address of PSP; CX := junk.
	shl eax, 16
	xchg ax, dx  ; AX := low  dword of the linear base address of PSP; DX := junk.
%else
	movzx eax, word [-pmodewe+_pspseg]
	shl eax, 4
%endif
	;push ss
	;pop es  ; ES := 32bit data selector. Not needed, it's already set.
	push es
	pop gs  ; GS := 32bit data selector.
	; Set the EBX := ECX := EDX := ESI := EDI := EBP := 0, and set some flags for reproducibility.
	sub ebp, ebp
	sub edi, edi
	sub esi, esi
	sub edx, edx
	sub ecx, ecx
	sub ebx, ebx  ; In EFLAGS, set OF=0, SF=0, ZF=1, AF=0, PF=1 and CF=0 according to the result.
%else
	mov es,[-pmodewe+_selpsp]                  ; ES = PSP selector
%endif

	push ss
	pop ds                          ; DS = 32bit data selector
%if 0  ; For debugging.
	jmp _descriptorerr
%endif
%if 0  ; For debugging.
	mov ah, 40h  ; Write to file.
	mov bx, 1  ; stdout.
	pop edx
	mov ecx, 0x1000
	int 21h  ; DOS-extended syscall.
	mov al,0fdh                     ; exit(253); Not merging it to `mov ax,...' for better compressibility.
	mov ah,4ch                      ; we stop right before jumping to the PE entry point for debugging
	int 21h                         ; terminate DOS process
%endif
	db 66h
	retf                            ; 32bit RETF to new CS:EIP

;
; SUBROUTINES
;

;
; Load The EXE Into Memory (LE or PMW1)
;
%if 0  ; This works in NASM.
db 'C'^66h ,'.'^66h ,' '^66h ,'S'^66h ,'C'^66h ,'H'^66h ,'E'^66h ,'F'^66h ,'F'^66h ,'O'^66h ,'L'^66h ,'D'^66h ,'/'^66h
db 'T'^66h ,'.'^66h ,' '^66h ,'P'^66h ,'Y'^66h ,'T'^66h ,'E'^66h ,'L'^66h
%endif

;
; Load A simple PE Executable - Must ONLY Be Called From _loadexe
;
%if LOADSPE
spefofs:
.mzhdr.signature: equ 0  ; dw.
.mzhdr.nreloc: equ 6  ; dw.
.mzhdr.hdrsize: equ 8  ; dw.
.pmodew_config: equ 20h  ; times 15h db.
.pehdr_fofs_ptr: equ 3ch  ; dd.
.pehdr: equ 40h
.pehdr.Signature: equ 40h  ; dd.
.pehdr.NumberOfSections: equ 46h  ; dw.
.pehdr.AddressOfEntryPoint: equ 68h  ; dd RVA. Ignored iff SPECUSTOMENTRY.
.pehdr.ImageBase: equ 74h  ; dd. Ignored iff SPERELOC==0.
.pehdr.SizeOfImage: equ 90h  ; dd.
.pehdr.SizeOfHeaders: equ 94h  ; dd.
.pehdr.SizeOfStackCommit: equ 0a4h  ; dd.
.pehdr.NumberOfRvaAndSizes: equ 0b4h  ; dd.
.pehdr.IMAGE_DATA_DIRECTORY: equ 0b8h  ; times 16 dd ?, ?. Ignored.
.pehdr.IMAGE_DIRECTORY_ENTRY_IMPORT: equ 0c0h  ; dd ? ?. Value ignored. For SPECUSTOMENTRY==0, dword [ImageBase+spefofs.pehdr.IMAGE_DIRECTORY_ENTRY_IMPORT+peidd.Size] will be overwritten with -1 (0xffffffff), which the entry point can use to detect SPE on DOS, because Win32 never has that value.
.pehdr.IMAGE_DIRECTORY_ENTRY_BASERELOC: equ 0e0h  ; dd ? ?. Ignored iff SPERELOC==0.
.pehdr.IMAGE_SECTION_HEADER: equ 138h  ; 28h bytes each.
pesechdr:  ; IMAGE_DATA_SECTION_HEADER.
.Name: equ 0*4 ; times 8 db. NUL-padded. Ignored.
.VirtualSize: equ 2*4  ; dd.
.VirtualAddress: equ 3*4  ; dd RVA. Divisible by 1000h. Not checked.
.SizeOfRawData: equ 4*4  ; dd.
.PointerToRawData: equ 5*4  ; dd file_offset.
.PointerToRelocations: equ 6*4  ; dd. Ignored.
.PointerToLineNumbers: equ 7*4  ; dd. Ignored.
.NumberOfRelocations: equ 8*4  ; dw. Ignored.
.NumberOfLineNumbers: equ 8*4+2  ; dw. Ignored.
.Characteristics: equ 9*4  ; dd. Ignored.
._size: equ 10*4

peidd:  ; IMAGE_DATA_DIRECTORY.
.VirtualAddress: equ 0*4  ; dd.
.Size: equ 1*4  ; dd.
._size: equ 2*4

_loadSPE:
; Allocates memory allocation for the PE image, loads the PE sections to the allocated memory, sets dword [-pmodewe+_init_eip], sets dword [-pmodewe+_init_esp].
; Input: GS == _selbuf == _dtabufptr containing the first 200h bytes of the .exe file; DS == pmodewe (== pmcode16) data selector; ES == FS == _selzero == zero-based data selector.
; Output: (no register value).
; Ruins: EAX, EBX, ECX, EDX, ESI, EDI, EBP, ES.
	push ds  ; Save.
	mov cx, [gs:spefofs.pehdr.NumberOfSections]  ; dw.
	push cx  ; Save NumberOfSections.
%if SPESIZEIMG
	mov edx, [gs:spefofs.pehdr.SizeOfImage]  ; Also contains the section containing relocations. Good. Unfortunately, this wastes <4 KiB of memory because of rounding up to SectionAlignment.
%else  ; Use the largest section .VirtualAddress+.VirtualSize.
	; !! TODO(pts): Add a low-memory option for the simple PE loader, which:
	; * omits the gap between 200h bytes after ImageBase and the first section
	; * loads only the IMAGE_DIRECTORY_ENTRY_BASERELOC.Size bytes from .rdata to a temporary locations (probably the PE .exe stack)
	; * after processing the relocations, it makes the stack containing them shorter, and releases some conventional memory, making _membase smalle
	; * it works with a smaller STACK_SIZE for initialization, and it releases that stack before jumping to the program
	mov si, spefofs.pehdr.IMAGE_SECTION_HEADER
%if SPERELOC  ; We need this workaround for PE .exe files created by OpenWatcom v2 wlink, beuse wlink sets .VirtualSize of section .reloc (with Characteristics == INIT_DATA|DISCARDABLE|READABLE) to 0.
	mov edx, [gs:si-spefofs.pehdr.IMAGE_SECTION_HEADER+spefofs.pehdr.IMAGE_DIRECTORY_ENTRY_BASERELOC+peidd.VirtualAddress]  ; EDX := largest RVA so far.
	test edx, edx
	jz short .reloc_rva_done
	add edx, [gs:si-spefofs.pehdr.IMAGE_SECTION_HEADER+spefofs.pehdr.IMAGE_DIRECTORY_ENTRY_BASERELOC+peidd.Size]
.reloc_rva_done:
%else
	xor edx, edx  ; EDX := largest RVA so far.
%endif
.section_size_loop:
	mov eax, [gs:si+pesechdr.VirtualAddress]
	add eax, [gs:si+pesechdr.VirtualSize]
	_cmp edx, eax
	jae .largest_rva_updated
	_mov edx, eax
.largest_rva_updated:
	add si, pesechdr._size
	loop .section_size_loop
	; Now: EDX == max(IMAGE_SECTION_HEADER[i].VirtualAddress+IMAGE_SECTION_HEADER[i].VirtualSize for i in xrange(NumberOfSections)).
%endif
	mov eax, [gs:spefofs.pehdr.SizeOfStackCommit]
	add eax, 3
	and al, ~3
	_xchg eax, edx  ; EAX := EDX; EDX := junk.
	add eax, 3
	and al, ~3
	_add eax, edx
.allocate_base:
	; Now: EAX == image_and_stack_size. (number of bytes to allocate).
	push eax  ; Save image_and_stack_size.
	call _malloc_aligned_SPE  ; Also ruins EBX. This is the only allocation done from _loadSPE. If it fails, it makes the process exit with a fatal error. Inlining would make it longer.
	pop ecx  ; Restore ECX := image_and_stack_size.
	_mov edi, eax  ; EDI := linear address of the actual image_ptr (instead of ImageBase).
	_add eax, ecx  ; ECX := linear address of the end of the image.
	mov [-pmodewe+_init_esp], eax
	mov bx, [-pmodewe+_exehandle]  ; This is the last instruction which needs DS == pmodewe data selector.
.fill_base:
	; Now: EDI == image_ptr; ECX == number of bytes allocated at the image_ptr, always divisible by 4.
	shr ecx, 2
	;mov es, [-pmodewe+_selzero]  ; Not needed, it's already set.
	_xor eax, eax
	push edi  ; Save.
	rep a32 stosd  ; This zero-initializes BSS. Fill the entire image (including the stack (ECX dwords starting at ES:EDI) with NUL bytes. Also sets ECX := 0.
.copy_hdr_to_base:
	; !! TODO(pts): With CONFIGTYPE==2, load the entire header again (everything in front of the first section. not just 200h bytes), set the lowest bit at pefofs.pehdr_fofs_ptr to 1.
	push gs
	pop ds  ; DS := _selbuf == _dtabufptr containing the first 200h bytes of the .exe file.
	_xor esi, esi
	pop eax  ; Restore EAX := image_ptr.
	_mov edi, eax  ; EDI := image_ptr (EAX).
	mov cl, 200h>>2  ; ECX := 200h>>2. This implementatios is shorter, and it works because ECX was 0.
	;mov es, [-pmodewe+_selzero]  ; Not needed, it's already set.
	rep a32 movsd  ; Copy the first 200h bytes of the .exe file to the image base. Win32 does the same. Also sets ECX := 0.
.load_sections:
	pop di  ; Restore DI := NumberOfSections.
	push es
	pop ds  ; DS := zero-based data selector.
	lea esi, [eax+spefofs.pehdr.IMAGE_SECTION_HEADER]
%if SPECUSTOMENTRY==2
	mov edx, [eax+spefofs.pehdr.AddressOfEntryPoint]
	_add edx, eax  ; dos_entry_point (EDX) := image_ptr+AddressOfEntryPoint.
	cmp [esi-spefofs.pehdr.IMAGE_SECTION_HEADER+spefofs.pehdr.IMAGE_DIRECTORY_ENTRY_IMPORT+peidd.VirtualAddress], ecx  ; We have ECX == 0 here.
	je short .have_entry_point_in_edx  ; This jumps iff there is no import table, i.e. it's a DOS-only PE program.
	add edx, byte 5  ; This is a DOS--Win32 combined PE program running on DOS, loaded by the simple PE loader. We start at AddressOfEntryPoint+5.
.have_entry_point_in_edx:
%elif SPECUSTOMENTRY
	mov edx, [esi+pesechdr.VirtualAddress]
	add edx, [esi+pesechdr.VirtualSize]
	lea edx, [edx+eax-2]  ; dos_entry_point (EDX) := image_ptr+IMAGE_SECTION_HEADER[0].VirtualAddress+IMAGE_SECTION_HEADER[0].SizeOfRawData-2.
%else
	; Set dword [ImageBase+spefofs.pehdr.IMAGE_DIRECTORY_ENTRY_IMPORT+peidd.Size] (== dword [ImageBase+0c4h]) := -1 (== 0xffffffff). The  entry point can check this to detect SPE on DOS, because Win32 never has that value.
	or dword [esi-spefofs.pehdr.IMAGE_SECTION_HEADER+spefofs.pehdr.IMAGE_DIRECTORY_ENTRY_IMPORT+peidd.Size], byte -1
	mov edx, [eax+spefofs.pehdr.AddressOfEntryPoint]
	_add edx, eax  ; dos_entry_point (EDX) := image_ptr+AddressOfEntryPoint.
%endif
	push edx  ; Save dos_entry_point (EDX). It will be put to [-pmodewe+_init_eip].
%if SPERELOC  ; We push 3 dwords here, which will be popped at the beginning of .apply_relocations below.
	mov edx, [eax+spefofs.pehdr.ImageBase]
	_sub edx, eax
	push edx  ; Save relocation delta.
	mov edx, [esi-spefofs.pehdr.IMAGE_SECTION_HEADER+spefofs.pehdr.IMAGE_DIRECTORY_ENTRY_BASERELOC+peidd.VirtualAddress]
	_add edx, eax
	push edx   ; Save linear address of relocation blocks.
	add edx, [esi-spefofs.pehdr.IMAGE_SECTION_HEADER+spefofs.pehdr.IMAGE_DIRECTORY_ENTRY_BASERELOC+peidd.Size]
	push edx  ; Save linear address of end of relocation blocks.
%endif
	push eax  ; Save image_ptr (EAX). It's used by .load_sections_loop.
.load_sections_loop:
	mov edx, [esi+pesechdr.PointerToRawData]  ; It's too late to use [gs:si+pesechdr.PointerToRawData], because _readfile has overwritten the first 200h bytes at GS:0.
	;call _seekfile  ; Seeks to file offset EDX in the .exe file. On error, it fails with a fatal error.
	_mov ecx, edx
	shr ecx, 16
	mov ax, 4200h ; Seek to file offset CX:DX in the .exe file.
	int 21h  ; DOS-extended syscall.
.jc_loaderror:  ; A full `.j_loaderror: jmp _loaderror' trampoline makes this code 2 bytes longer.
	jc _loaderror
	; Now: EAX, EDX and ECX are junk.
	pop edx  ; Restore EDX := image_ptr.
	push edx  ; Save image_ptr (EDX).
	add edx, [esi+pesechdr.VirtualAddress]  ; EDX := image_ptr (EDX) + section VirtualAddress.
	mov ecx, [esi+pesechdr.SizeOfRawData]
	;call _readfile  ; Reads ECX bytes to linear address EDX from the .exe file. On error, it fails with a fatal error.
	mov ah, 3fh  ; Read ECX bytes to DS:EDX from the .exe file.
	int 21h  ; DOS-extended syscall.
	jc short .jc_loaderror
	cmp eax, ecx
	jne _loaderror  ; If this jumps, then then not all ECX bytes have been read.
	add esi, pesechdr._size
	dec di
	jnz .load_sections_loop
%if SPERELOC
.apply_relocations:
	pop ebx  ; Restore EBX := image_ptr.
	pop ebp  ; Restore EBP := linear address of end of relocation blocks.
	pop esi  ; Restore ESI := linear address of relocation blocks.
	pop edi  ; Restore EDI := relocation delta.
	jmp short .maybe_next_relocation_block  ; We must jump here, in case there are no relocations at all, i.e. IMAGE_DIRECTORY_ENTRY_BASERELOC.Size == 0, thus ESI == EBP here.
.relocation_block_loop:
	mov edx, [esi]  ; EDX := PageRVA (EAX).
	_add edx, ebx
	mov ecx, [esi+4]  ; ECX := BlockSize (EAX).
	; We assume that the block is not empty, i.e. ECX >= 12 here. This is documented in the LOADSPE comment.
	_add ecx, esi  ; ECX := linear address of end of the relocation block.
	add esi, byte 8
.relocation_entry_loop:
	_xor eax, eax  ; We set EAX := 0 because we need to set the high word of EAX := 0.
	a32 lodsw  ; AX := next relocation entry. We assume that either it's of type ABSOLUTE (== 0) or HIGHLOW (== 3). This is document in the LOADSPE comment.
	sub ah, 0x30  ; Same size as the equivalent: sub ax, strict word 0x3000
	jb short .relocation_entry_done
	sub [eax+edx], edi  ; Apply relocation by adding relocation delta to the dword address to be relocated.
.relocation_entry_done:
	_cmp esi, ecx
	jne short .relocation_entry_loop
.maybe_next_relocation_block:
	_cmp esi, ebp
	jne short .relocation_block_loop
.after_relocation_block_loop:
%else
	pop eax  ; Discard image_ptr.
%endif
.done:
	pop eax  ; Restore EAX := dos_entry_point.
	pop ds  ; Restore.
	mov [-pmodewe+_init_eip], eax
	ret

_malloc_aligned_SPE:
; Allocates memory. Failes with a fatal error (_memoryerr) if allocation fails.
; Input: EAX: number of bytes to allocate.
; Output: EAX: linear address of the allocated block, will be page-aligned (multiple of 4096).
; Ruins: EBX, EFLAGS.
; Based on _loadobjects1.
%if MEMDEBUG && 0
	mov ebp, 12345603h  ; Exit reason indicator.
	int3
%endif
	push eax  ; Save size (EAX).
	mov ebx,[-pmodewe+_memtop]
	sub ebx,[-pmodewe+_membase]
	add eax,15
	shr eax,4
	_sub ebx,eax                     ; If there is not enough low memory, then try extended memory
	jb .tryhimem
	movzx eax,word [-pmodewe+_pm16_lowmin]
	_cmp ebx,eax                     ; If there is enough, make sure that _pm16_lowmin is satisfied
	jae .trylowmem
	pop eax  ; Restore EAX := size.
	push eax
	call _gethimem                   ; Try extended memory if _pm16_lowmin is not satisfied
	jnc short .ok
.trylowmem:
	pop eax  ; Restore EAX := size.
	push eax
	movzx ebx, byte [-pmodewe+_membase]
	neg bl
	shl bx,4  ; EBX := number of bytes to skip after _membase so that the returned EAX will be aligned to 1000h bytes.
	_add eax,ebx
	call _getmem  ; Allocate EAX bytes of low memory for this object. Also ruins EAX on error.
	jc short .tryhimem  ; Ruins EAX on error.
	shl eax,4  ; Convert SEGMENT:0 in EAX to linear address.
	_add eax,ebx                     ; Align block on 1000h bytes.
	jmp short .ok
.tryhimem:  ; Now: EAX == size.
	pop eax  ; Restore EAX := size.
	push eax
	call _gethimem                  ; Allocate EAX bytes of extended memory
	jc _memoryerr
.ok:
	pop ebx  ; Discard size.
	ret
%else
_loadexe:
	add word [-pmodewe+_pm16_lowmin],(FIXUPBUFMIN>>4)+1
	jnc short .l1f1
	or word [-pmodewe+_pm16_lowmin],-1
.l1f1:

	mov gs,[-pmodewe+_selbuf]                  ; Get LE/PMW1 location from EXE header
%ifdef PROG32FOFS  ; Can be specified on the command line or in another .nasm source file.
	fixpre_mov edx,[gs:(PROG32FOFS)]
%else
	fixpre_mov edx,[gs:3ch]
%endif
	mov [-pmodewe+_exebaseoffset],edx
	call _seekfile                             ; and seek to it

	mov ecx,4
	mov edx,[-pmodewe+_dtabufptr]              ; Read In Executable Signature
	call _readfile

%if LOADLE
	cmp word [gs:0],'LE'        ; Is it an LE?  Its reverse is 'EL' for TASM.
	jz _loadLE
%endif
%if LOADPMW1
	lastdd 0x66, 0x65, 0x81, 0x3e, 0, 0, 'PMW1'  ; cmp dword [gs:0],'PMW1'     ; Its reverse is '1WMP' for TASM.  ; Diff: TASM encodes the 0x66 prefix, then the segment prefix, NASM does it the other way round.
	jz _loadPMW1
%endif
	jmp _loaderror                  ; If none of the above, quit
%endif

;
; Load A PMW1 Executable - Must ONLY Be Called From _loadexe
;
%if LOADPMW1
_loadPMW1:
	mov ecx,24h
	add edx,4
	call _readfile                  ; Read in the rest of the PMW1 header

%if PMW1UNCOMP==0
	mov eax,[-pmodewe+_int21lowbufptr]         ; Fill the decompression variables
	mov [-pmodewe+decode_bufbase],eax
	add eax,decode_bufsize
	mov [-pmodewe+decode_bufend],eax
	sub eax,16
	mov [-pmodewe+decode_bufthreshold],eax
	mov ax,[-pmodewe+_exehandle]
	mov [-pmodewe+decode_handle],ax
%endif

	fixpre_mov eax,[gs:08h]                ; Get initial CS:EIP and SS:ESP
	fixpre_mov ebx,[gs:0ch]
	fixpre_mov ecx,[gs:10h]
	fixpre_mov edx,[gs:14h]
	mov [-pmodewe+_init_csobj],eax             ; Store them in the proper variables
	mov [-pmodewe+_init_csoff],ebx             ; for later use
	mov [-pmodewe+_init_ssobj],ecx
	mov [-pmodewe+_init_ssoff],edx

	fixpre_mov eax,[gs:24h]                ; Get the location of the actual
	add eax,[-pmodewe+_exebaseoffset]          ; program data
	mov [-pmodewe+_datapagesloc],eax

	fixpre_mov ebp,[gs:1ch]                ; Get the number of objects and exit
	cmp ebp,MAXOBJECTS              ; if there are too many
	ja _loaderror
	mov [-pmodewe+_numobjects],ebp
	fixpre_mov edx,[gs:18h]
	add edx,[-pmodewe+_exebaseoffset]
	call _seekfile                  ; Seek to the object table

	_xor ebp,ebp
_loadobjects_PMW1:
	call _loadobjects1              ; Allocate memory for current object

	fixpre_mov ecx,[gs:100h]
	fixpre_mov edx,[gs:114h]
	_cmp ecx,edx                     ; If VirtualSize > ActualSize
	jbe _nozerobss1_PMW1            ; then clear the extra memory
	push edi
	_sub ecx,edx
	_add edi,edx
	_xor al,al
	rep a32 stosb
	pop edi
_nozerobss1_PMW1:

%if PMW1UNCOMP
	fixpre_mov ecx,[gs:104h]
	_mov edx,edi
	call _readfile                  ; Read object data into memory
%else
	call _int213Fbuftoggle          ; Turn off read buffer transfer
	fixpre_mov ecx,[gs:104h]
	mov [-pmodewe+decode_filesize],ecx         ; Get the compressed block size
	pushad
	call decode                     ; Decompress object data to memory
	popad
	call _int213Fbuftoggle          ; Turn on read buffer transfer
%endif

_noreadobject1_PMW1:
	_mov eax,ecx                     ; Setup object variables and allocate
	call _loadobjects2              ; any needed object descriptors

	inc ebp
	cmp ebp,[-pmodewe+_numobjects]
	jnz _loadobjects_PMW1

	call _initfixupbuffer           ; Initialize buffer for fixups

	_xor ebp,ebp
_relocateobjects_PMW1:
	fixpre_mov edx,[gs:20h]
	add edx,[-pmodewe+_exebaseoffset]
	fixpre_mov ebx,[ds:-pmodewe+_objectrtblocks+ebp*4]

	_or ebx,ebx                      ; If there are no relocation blocks
	jz _norelocate1_PMW1            ; then proceed to the next object

	fixpre_add edx,[ds:-pmodewe+_objectrtoff+ebp*4]  ; Seek to beginning of relocation info
	call _seekfile                  ; for this object

_relocate1_PMW1:
	mov ecx,4
	mov edx,[-pmodewe+_dtabufptr100h]          ; Read in the size of the next
	call _readfile                  ; relocation block

%if 0  ; This is commented out in TASM. If enabled, it would compile in NASM.
        fixpre_movzx_word ecx,gs,gs:102h
        cmp ecx,[-pmodewe+_fixupbufsize]           ; Make sure it will fit in our fixup
        ja _loaderror                   ; buffer
%endif

%if PMW1UNCOMP
	fixpre_movzx_word ecx,gs,102h
	mov edx,[-pmodewe+_fixupbufptr]
	call _readfile                  ; Read in relocation block
%else
	call _int213Fbuftoggle          ; Turn off read buffer transfer
	mov edi,[-pmodewe+_fixupbufptr]
	fixpre_movzx_word ecx,gs,100h
	mov [-pmodewe+decode_filesize],ecx         ; Get compressed block size
	pushad
	call decode                     ; Decompress relocation data
	popad
	call _int213Fbuftoggle          ; Turn on read buffer transfer
%endif
	fixpre_movzx_word ecx,gs,102h
	mov [-pmodewe+_nextobjectloc],ecx
	mov [-pmodewe+_currentobject],ebp
	fixpre_mov edi,[ds:-pmodewe+_objectlocs+ebp*4]   ; EDI = Location of object

	_xor esi,esi                     ; ESI = 0
	multipush ebx, ebp
_relocate2_PMW1:
	fs a32 lodsb
	_mov dl,al                       ; DL = Relocation Type
	test dl,20h
	jnz _unknownerror

	fixstr fs a32, lodsd             ; ES:[EBX+EDI] -> Source
	_mov ebx,eax

	_xor eax,eax
	fs a32 lodsb
	_mov ecx,eax                     ; ECX = Target Object Number
	mov ebp,[-pmodewe+_objectlocs+ecx*4-4]    ; EBP = Target Object Offset

	fixstr fs a32, lodsd            ; EAX= Target Offset

	call _relocateitem              ; Process relocation item

	cmp esi,[-pmodewe+_nextobjectloc]          ; If not done, process the next
	jnz _relocate2_PMW1             ; relocation item

	multipop ebp, ebx

	dec ebx                         ; If not done, load the next block of
	jnz _relocate1_PMW1             ; relocation data

_norelocate1_PMW1:
	inc ebp
	cmp ebp,[-pmodewe+_numobjects]             ; If there are more objects, then
	jnz _relocateobjects_PMW1       ; process them

	ret
%endif

;
; Load An LE Executable - Must ONLY Be Called From _loadexe
;
%if LOADLE
_loadLE:
	mov ecx,0c0h
	add edx,4
	call _readfile                  ; Read in the rest of the LE header

	fixpre_mov eax,[gs:18h]                ; Get initial CS:EIP and SS:ESP
	fixpre_mov ebx,[gs:1ch]
	fixpre_mov ecx,[gs:20h]
	fixpre_mov edx,[gs:24h]
	mov [-pmodewe+_init_csobj],eax             ; Store them in the proper variables
	mov [-pmodewe+_init_csoff],ebx             ; for later use
	mov [-pmodewe+_init_ssobj],ecx
	mov [-pmodewe+_init_ssoff],edx

	fixpre_mov eax,[gs:80h]                ; Get the location of the actual
	mov [-pmodewe+_datapagesloc],eax           ; program data

	fixpre_mov ebp,[gs:44h]                ; Get the number of objects and exit
	cmp ebp,MAXOBJECTS              ; if there are too many
	ja _loaderror
	mov [-pmodewe+_numobjects],ebp
	fixpre_mov edx,[gs:40h]
	add edx,[-pmodewe+_exebaseoffset]
	call _seekfile                  ; Seek to the object table

	_xor ebp,ebp
_loadobjects_LE:
	call _loadobjects1              ; Allocate memory for current object

	fixpre_mov ecx,[gs:100h]
	fixpre_mov eax,[gs:110h]
	shl eax,12

	_mov edx,ebp
	inc edx
	cmp edx,[-pmodewe+_numobjects]
	jnz _loadobjects_LE_lastpage2
	fixpre_cmp_dword_byte [gs:110h],1
	jz _loadobjects_LE_lastpage1
	sub eax,1000h
	fixpre_add eax,[gs:2ch]
	jmp short _loadobjects_LE_lastpage2
_loadobjects_LE_lastpage1:
	fixpre_mov eax,[gs:2ch]
_loadobjects_LE_lastpage2:

	_mov edx,eax
	_sub edx,ecx
	jnc short _nozerobss1           ; Zero uninitialized data if necessary
	pushad
	_sub ecx,eax
	_add edi,eax
	_xor al,al
	rep a32 stosb			; This zero-initializes BSS.
	popad
	_mov edx,ecx
	_sub edx,eax
	_sub ecx,edx
	jz _noreadobject1
_nozerobss1:
	_mov edx,edi
	call _readfile                  ; Read object data into memory
_noreadobject1:

	_mov eax,ecx
	_mov edx,ecx
	and ax,strict word 0f000h
	and edx,0fffh
	jz short _loadobj1              ; Adjust data page additive size
	add eax,1000h                   ; accordingly
_loadobj1:
					; Setup object variables and allocate
	call _loadobjects2              ; any needed object descriptors

	inc ebp
	cmp ebp,[-pmodewe+_numobjects]
	jnz _loadobjects_LE

	call _initfixupbuffer           ; Initialize buffer for fixups

	_xor ebp,ebp
_relocateobjects:
	fixpre_mov edx,[gs:48h]
	add edx,[-pmodewe+_exebaseoffset]

	fixpre_cmp_dword_byte [ds:-pmodewe+_objectpagenum+ebp*4],0
	jz _norelocate2

	fixpre_mov eax,[ds:-pmodewe+_objectpageidx+ebp*4]
	lea edx,[edx+eax*4-4]           ; Seek to the first page table index
	call _seekfile                  ; for this object

	_xor ebx,ebx
_relocate1:
	mov ecx,4                       ; Read the next object page map entry
	mov edx,[-pmodewe+_dtabufptr100h]
	call _readfile
	call _filepos                   ; Save file position for later

	fixpre_movzx_word eax,gs,101h
	_or ax,ax
	jz _norelocate1                 ; Skip if no relocation on this page
	_xchg al,ah

	fixpre_mov edx,[gs:68h]                ; Seek to the fixup page table
	add edx,[-pmodewe+_exebaseoffset]
	lea edx,[edx+eax*4-4]
	call _seekfile

	mov ecx,8                       ; Read 2 fixup entries
	mov edx,[-pmodewe+_dtabufptr100h]
	call _readfile
	fixpre_mov eax,[gs:100h]               ; If the two entries are identical
	fixpre_cmp eax,[gs:104h]               ; then there is no relocation here
	jz _norelocate1                 ; and we can skip this page

	fixpre_mov esi,[gs:100h]
	fixpre_mov edx,[gs:6ch]
	add edx,[-pmodewe+_exebaseoffset]
	_add edx,esi                     ; Seek to the first fixup record
	call _seekfile                  ; for this page

	fixpre_mov ecx,[gs:104h]
	fixpre_sub ecx,[gs:100h]               ; If the total size of the fixup data
	cmp ecx,[-pmodewe+_fixupbufsize]           ; for this page is larger than our
	ja _loaderror                   ; buffer, then exit with an error
	mov edx,[-pmodewe+_fixupbufptr]
	call _readfile                  ; Read in the fixup data for this page

	fixpre_mov edi,[ds:-pmodewe+_objectlocs+ebp*4]
	_mov eax,ebx
	shl eax,12
	_add edi,eax                     ; EDI = Offset of the current 4k page

	mov [-pmodewe+_nextobjectloc],ecx
	mov [-pmodewe+_currentobject],ebp
	multipush ebx, ebp
	_xor esi,esi                     ; ESI = 0
_relocate2:
	fs a32 lodsw
	_mov dx,ax                       ; DX = Fixup flags/type
	test dx,0720h
	jnz _unknownerror

	fs a32 lodsw
	movsx ebx,ax                    ; ES:[EBX+EDI] -> Source

	_xor eax,eax
	fs a32 lodsb
	test dh,40h
	jz short _relocate2a
	mov ah,[fs:esi]
	inc esi
_relocate2a:
	_mov ecx,eax                     ; ECX = Target Object Number
	mov ebp,[-pmodewe+_objectlocs+ecx*4-4]    ; EBP = Target Object Offset

	_mov al,dl
	and al,0fh
	cmp al,2
	jz _relocate2b
	_xor eax,eax
	fs a32 lodsw
	test dh,10h
	jz short _relocate2b
	rol eax,16
	fs a32 lodsw
	rol eax,16
_relocate2b:                            ; EAX = Target Offset

	call _relocateitem              ; Process relocation item

	cmp esi,[-pmodewe+_nextobjectloc]          ; If not done, process the next
	jnz _relocate2                  ; relocation item
	multipop ebp, ebx
_norelocate1:

	mov edx,[-pmodewe+_oldfilepos1]
	call _seekfile                  ; Restore file position
	inc ebx
	fixpre_cmp ebx,[ds:-pmodewe+_objectpagenum+ebp*4]
	jnz _relocate1                  ; If not done, process next page
_norelocate2:
	inc ebp
	cmp ebp,[-pmodewe+_numobjects]
	jnz _relocateobjects            ;If not done, process next object

	ret
%endif

;
; SHARED LOADER ROUTINES USED BY _loadLE AND _loadPMW1
;
%if LOADLE || LOADPMW1

;
; Allocate Memory For An Object And Seek To The Object Data
;
_loadobjects1:
	mov ecx,18h                     ; Read info for this object
	mov edx,[-pmodewe+_dtabufptr100h]
	call _readfile
	call _filepos                   ; Save file position for later

	fixpre_mov eax,[gs:100h]               ; Allocate some memory for this object
	movzx edx,word [-pmodewe+_pm16_lowmin]
	mov edi,[-pmodewe+_memtop]
	sub edi,[-pmodewe+_membase]
	_mov ecx,eax
	add ecx,15
	shr ecx,4

	_sub edi,ecx                     ; If there is not enough low memory
	jc _loadtryhimem                ; then try extended memory

	_cmp edi,edx                     ; If there is enough, make sure that
	jae _loadtrylowmem              ; word [-pmodewe+_pm16_lowmin] is satisfied

	test byte [gs:108h+1],100000b
	jz _loadtrylowmem               ; Load 16bit objects into low memory

	call _gethimem                  ; Try extended memory if _pm16_lowmin is
	jnc _loadlowmemok               ; is not satisfied
_loadtrylowmem:
	mov ebx,[-pmodewe+_membase]
	and ebx,0ffh                    ; Make sure memory is 4096 byte aligned
	jz _loadlowmemok1
	dec bx
	xor bl,0ffh
	shl bx,4
	_add eax,ebx
_loadlowmemok1:
	call _getmem                    ; Allocate low memory for this object
	jc short _loadtryhimem
	shl eax,4
	_add eax,ebx                     ; Align block on 4096 bytes
	jmp short _loadlowmemok
_loadtryhimem:
	test byte [gs:108h+1],100000b
	jz _memoryerr                   ; If this is a 16bit object, exit
	fixpre_mov eax,[gs:100h]
	call _gethimem                  ; Allocate DPMI memory
	jc _memoryerr
_loadlowmemok:
	_mov edi,eax                     ; EDI = Memory block for this object

	mov edx,[-pmodewe+_datapagesloc]
	call _seekfile                  ; Seek to current object data location
	ret

;
; Setup Descriptors For Objects
;
_loadobjects2:
	add [-pmodewe+_datapagesloc],eax           ; Update information for object pages
	_mov bx,bp
	shl bx,2

	mov [-pmodewe+_objectlocs+bx],edi         ; Store object offset

	fixpre_mov eax,[gs:108h]
	mov [-pmodewe+_objectflags+bx],eax        ; Store object flags

	test eax,10000000000000b        ; If object is 32bit, store default
	jz _loadobj1a                   ; code & data selectors
	mov ax,[-pmodewe+_selcode]
	mov [-pmodewe+_objectsels+bx],ax
	mov ax,[-pmodewe+_selzero]
	mov [-pmodewe+_objectsels+bx+2],ax
	jmp short _loadobj1b
_loadobj1a:
	or ecx,-1                       ; If object is 16bit then allocate
	mov dx,[-pmodewe+_selrights]               ; new code and data descriptors
	call _initdescriptor
	mov [-pmodewe+_objectsels+bx+2],ax
	or dl,8
	call _initdescriptor
	mov [-pmodewe+_objectsels+bx],ax
_loadobj1b:
	fixpre_mov eax,[gs:10ch]
	mov [-pmodewe+_objectpageidx+bx],eax      ; Store object page table index
	fixpre_mov eax,[gs:110h]
	mov [-pmodewe+_objectpagenum+bx],eax      ; Store number of pages in object

	mov edx,[-pmodewe+_oldfilepos1]
	call _seekfile                  ; Seek to original file position
	ret

;
; Setup Pointers For The Fixup Buffer And Allocate A Descriptor For It
;
_initfixupbuffer:
	mov edi,[-pmodewe+_membase]                ; Allocate buffer for fixup information
	shl edi,4                       ; to later be discarded
	mov [-pmodewe+_fixupbufptr],edi
	or ecx,-1
	mov dx,[-pmodewe+_selrights]
	call _initdescriptor            ; Allocate a descriptor for the buffer
	mov [-pmodewe+_selfixup],ax
	mov fs,ax
	mov eax,[-pmodewe+_memtop]
	sub eax,[-pmodewe+_membase]
	shl eax,4
	mov [-pmodewe+_fixupbufsize],eax
	cmp eax,FIXUPBUFMIN             ; If the fixup buffer is too small
	jb _memoryerr                   ; exit with an error
	ret

;
; Relocate One Item
; In:
;   EAX - Target Offset
;   EBP - Zero Based Target Beginning Offset
;    DL - Fixup Type
;   ECX - Target Object Number
;   ES:[EBX+EDI] -> Pointer To Relocation Source
; Out:
;
;
_r_table        dw -pmodewe+_r_byteoffset
		dw -pmodewe+_r_unknown
		dw -pmodewe+_r_wordsegment
		dw -pmodewe+_r_16bitfarptr
		dw -pmodewe+_r_unknown
		dw -pmodewe+_r_16bitoffset
		dw -pmodewe+_r_32bitfarptr
		dw -pmodewe+_r_32bitoffset
		dw -pmodewe+_r_nearcalljmp
_relocateitem:
	push esi
	movzx esi,dl
	and esi,0fh
	cmp esi,8
	ja _unknownerror
	_or ebx,ebx
	js _r_done
	lastdd 0x67, 0xff, 0x24, 0x75, -pmodewe+_r_table  ; jmp [-pmodewe+_r_table+esi*2]  ; Diff: TASM and NASM encode this instruction differently.

_r_byteoffset:
	mov [es:ebx+edi],al
	jmp _r_done
_r_wordsegment:                         ; Segment/Selector
	call _r_segmentfixup
	mov [es:edi+ebx],bp
	jmp _r_done
	nop  ; Diff: TASM jump optimization wasn't smart enough.
_r_16bitfarptr:                         ; 16bit Far Pointer
	call _r_segmentfixup
	mov [es:ebx+edi],ax
	mov [es:ebx+edi+2],bp
	jmp _r_done
_r_16bitoffset:                         ; 16bit Offset
	mov [es:ebx+edi],ax
	jmp _r_done
_r_32bitfarptr:                         ; 32bit Far Pointer
	_add eax,ebp
	fixpre2_mov [es:ebx+edi],eax
	call _r_segmentfixup
	mov [es:ebx+edi+4],bp
	jmp _r_done
_r_32bitoffset:                         ; 32bit Offset
	_add eax,ebp
	fixpre2_mov [es:ebx+edi],eax
	jmp _r_done
_r_nearcalljmp:                         ; 16/32bit Near Call or Jump
	_add eax,ebp
	lea esi,[ebx+edi+4]
	_sub eax,esi
	mov ecx,[-pmodewe+_currentobject]
	test word [-pmodewe+_objectflags+ecx*4],10000000000000b
	jnz _r_nearcalljmp32
	lea ecx,[eax+32768+2]
	test ecx,0ffff0000h
	jnz _16biterror
	mov [es:ebx+edi],ax
	jmp _r_done
_r_nearcalljmp32:
	fixpre2_mov [es:ebx+edi],eax
	jmp _r_done
_r_unknown:
	jmp _unknownerror
_r_done:
	pop esi
	ret

_r_segmentfixup:
	mov esi,[-pmodewe+_currentobject]
	test word [-pmodewe+_objectflags+esi*4],1000000000000b
	jnz _r_wordsegment2
	test byte [-pmodewe+_objectflags+ecx*4-4],100b
	jz _r_wordsegment1
	mov bp,[-pmodewe+_objectsels+ecx*4-4]
	jmp short _r_wordsegment3
_r_wordsegment1:
	mov bp,[-pmodewe+_objectsels+ecx*4-2]
	jmp short _r_wordsegment3
_r_wordsegment2:
	shr ebp,4
;        test dl,10h
;        jz _r_wordsegment3
	test ebp,0ffff0000h
	jnz _16biterror
_r_wordsegment3:
	ret
%endif  ; LOADLE || LOADPMW1

;
; Setup A New Descriptor
; In:
;   EDI - Base Address
;    DX - Access Rights
;   ECX - Limit
; Out:
;    AX - Selector
;
_initdescriptor:
	multipush ebx, ecx, edx, ebp
	_mov ebp,ecx
	_xor ax,ax
	mov cx,1
	int 31h                         ; Allocate 1 descriptor
	jc short _initdescerr

	_xchg bx,ax
	mov ax,9
	_mov cx,dx
	int 31h                         ; Set descriptor access rights
	jc short _initdescerr

	mov ax,7
	_mov ecx,edi
	_mov dx,cx
	shr ecx,16
	int 31h                         ; Set descriptor base address
	jc short _initdescerr

	mov ax,8
	_mov ecx,ebp
	_mov dx,cx
	shr ecx,16
	int 31h                         ; Set descriptor limit
	jc short _initdescerr
	_mov ax,bx
	clc
_initdescerr:
	multipop ebp, edx, ecx, ebx
	jc _descriptorerr
	ret

%if LOADLE || LOADPMW1
;
; Quickie Read To Buffer
; In:
;   ECX - Number Of Bytes To Read
;   EDX - Zero Based Buffer Offset
; Out:
;   CF=0 Success
;   CF=1 Error
;
_readfile:
	multipush eax, bx
%if SIZEOPT  ; Make it more compressible, reusing repetition in _seekfile.
	mov bx,[-pmodewe+_exehandle]
	push ds
	mov ah,3fh
%else
	push ds
	mov ah,3fh
	mov bx,[-pmodewe+_exehandle]
%endif
	mov ds,[-pmodewe+_selzero]
	int 21h  ; This DOS-extended call changes EAX.
	pop ds
	; BUG: `cmp eax, ecx' ++ `jne _loaderror' is missing. We should
	; check that all the bytes we need have been read. However, that would
	; change pmodew.exe, so it wouldn't be bytewise identical anymore.
	multipop bx, eax
	jc _loaderror
	ret
%endif

%if LOADLE || LOADPMW1
;
; Seek To File Position
; In:
;    EDX - Position
; Out:
;   CF=0 Success
;   CF=1 Error
;
_seekfile:
%if SIZEOPT  ; Make it more compressible, reusing repetition in _readfile.
	multipush eax, bx
	mov bx,[-pmodewe+_exehandle]
%else
	multipush ax, bx
%endif
	multipush ecx, dx
	_mov ecx,edx
	shr ecx,16
	mov ax,4200h
%if SIZEOPT==0 ; Make it more compressible, reusing repetition in _readfile.
	mov bx,[-pmodewe+_exehandle]
%endif
	int 21h
	multipop dx, ecx
%if SIZEOPT  ; Make it more compressible, reusing repetition in _readfile.
	multipop bx, eax
%else
	multipop bx, ax
%endif
	jc _loaderror
	ret
%endif

%if LOADLE || LOADPMW1
;
; Get Current File Position
; In:
;    None
; Out:
;   _oldfilepos1 = File Position
;   CF=0 Success
;   CF=1 Error
;
_filepos:
	push bx
	_xor cx,cx
	_xor dx,dx
	mov ax,4201h
	mov bx,[-pmodewe+_exehandle]
	int 21h
	jc _loaderror
	mov [-pmodewe+_oldfilepos1+0],ax
	mov [-pmodewe+_oldfilepos1+2],dx
	pop bx
	ret
%endif

;
; Get Some Low Memory
; In:
;    EAX - Number Of Bytes To Get
; Out:
;   EAX - SEG:OFF Pointer (Offset Always 0)
;   CF=0 Success
;   CF=1 Error. Ruins EAX.
;
_getmem:
	add eax,15
	shr eax,4
	add eax,[-pmodewe+_membase]
	cmp eax,[-pmodewe+_memtop]
	ja _getmemerr
	xchg eax,[-pmodewe+_membase]
	clc
	jmp short $+3
_getmemerr:
	stc
	ret

;
; Get Some High Memory
; In:
;    EAX - Number Of Bytes To Get
; Out:
;   EAX - Absolute Address Of Block, will be page-aligned (multiple of 4096)
;   CF=0 Success
;   CF=1 Error
;
_gethimem:
	multipush bx, cx, si, di, edx, eax
	add eax,4095
	_mov cx,ax
	shr eax,16
	_mov bx,ax
	mov ax,501h
	int 31h                         ; Call DPMI for some memory
	jc short _gethimemerr
	_mov dx,bx                       ; Align it on a 4096 byte boundary
	shl edx,16
	_mov dx,cx
	_mov bx,dx
	and bx,4095
	jz _gethimem1
	dec bx
	xor bx,4095
_gethimem1:
	movzx eax,bx
	push eax
	add eax,[esp+4]
	_mov cx,ax
	shr eax,16
	_mov bx,ax
	mov ax,503h
	int 31h                         ; Resize the block if necessary
	jc short _gethimem2
	_mov dx,bx
	shl edx,16
	_mov dx,cx
_gethimem2:
	pop eax
	_add edx,eax
	mov [esp],edx
	clc
_gethimemerr:
	multipop eax, edx, di, si, cx, bx
	ret

%if LOADSPE==0  ; Unused with LOADSPE.
_16biterror:
	mov ax,9  ; The size optimization of doing `mov al,...' here would make the compressed pmodew.exe longer.
	jmp short _pmstartuperr
%endif
_descriptorerr:
	mov ax,6
	jmp short _pmstartuperr
_exiterror:
	mov ax,5
	jmp short _pmstartuperr
%if LOADSPE==0  ; Unused with LOADSPE.
_unknownerror:
	mov ax,8
	jmp short _pmstartuperr
%endif
_memoryerr:
	_xor ax,ax
	jmp short _pmstartuperr
_loaderror:
	mov ax,7
_pmstartuperr:
	_mov si,ax
	_add si,ax
	push cs
	pop ds
	mov dx,-pmodewe+pmodemsg
	call _pmsg
	mov dx,[word -pmodewe+errmsgtbl+si]  ; `Diff: effective address `word' is because of missed TASM optimization. In NASM, there is no displacement (0).
	call _pmsg
%if LOADSPE!=3
	mov ah,2
	mov dl,10  ; LF == '\n'.
	int 21h
%if SIZEOPT
	mov dl,13  ; CR == '\r'. TODO(pts): Add patch which makes it CR-LF instead of LF-CR.
%else
	add dl,3
%endif
	int 21h
%endif
%if EXITCODE
	mov al,0ffh                     ; exit(255); Not merging it to `mov ax,...' for better compressibility.
	mov ah,4ch                      ; fatal error at process startup, see errmsg0 etc. for reason
%else
	mov ax,4cffh                    ; fatal error at process startup, see errmsg0 etc. for reason
%endif
	int 21h                         ; terminate DOS process

_pmsg:
%if SIZEOPT
	mov ah,9
	cmp byte [-pmodewe+_inpmode],ah
	ja _pmerr1  ; This jumps if _inpmode == 0xff (true).
%else
	cmp byte [-pmodewe+_inpmode],0ffh
	jz _pmerr1
	mov ah,9
%endif
	int 21h
	ret
_pmerr1:
	sub esp,32h
	_mov ebp,esp
	mov byte [ebp+_eax+1],9
	reloc mov word [ebp+_ds],pmcode16
	mov [ebp+_edx],dx
	call _realmodeint21
	add esp,32h
	ret

;
; INT 1Bh, 21h, AND 33h EXTENSIONS
;

;
; Initialize All DOS/Mouse Extensions
; In:
;    GS - Zero-Based 4G Data Selector
;    DS - Data Selector Based At Current Segment
;    ES - PSP Selector
; Out:
;   CF=0 Success
;   CF=1 Error
;
_initdosext:
	pushad
	cld
	sub esp,32h
	_mov ebp,esp
%if SIZEOPT  ; Make it better compressible by moving the `sub esp,32h' and `mov byte [ebp+_eax+1],...' instructions together.
	mov byte [ebp+_eax+1],1ah
	mov word [ebp+_edx],0       ; Set the real mode DTA segment to
	mov dx,[-pmodewe+_int21lowdtaseg]
	mov [ebp+_ds],dx
	mov [-pmodewe+_int21datasel64],ds          ; Store the 16bit data selector
%else
	mov [-pmodewe+_int21datasel64],ds          ; Store the 16bit data selector
	mov dx,[-pmodewe+_int21lowdtaseg]
	mov [ebp+_ds],dx
	mov byte [ebp+_eax+1],1ah
	mov word [ebp+_edx],0       ; Set the real mode DTA segment to
%endif
	call _realmodeint21             ; our DTA buffer

	mov ax,204h
	mov bl,21h
	int 31h
	mov [-pmodewe+_int21vectsel],cx
	mov [-pmodewe+_int21vectoff],edx
	mov ax,205h
	mov cx,cs
	mov edx,-pmodewe+_int21handler
	int 31h                         ; Hook protected mode INT 21h

%if INT33
	fixpre_cmp_dword_byte [gs:33h*4],0  ; Check mouse driver interrupt vector
	jnz _nomousedriver1             ; and continue if its not 0
	mov word [-pmodewe+_int33handler],0cf66h
	jmp _nomousedriver2
_nomousedriver1:
;        xor ax,ax
	mov ax,21h
	int 33h                         ; Reset the mouse
;        or ax,ax
	cmp ax,strict word 21h
	jz _nomousedriver3              ; Don't install handler if it fails
	mov ax,15h
	int 33h                         ; Check mouse storage requirements
	movzx ebx,bx
	mov [-pmodewe+_int33mousebufsize],ebx
	cmp bx,1000h
	ja _initdosexterror             ; Quit if its too large
	mov esi,-pmodewe+_int330Cpmentry
	call _initgetcallback
	mov [-pmodewe+_int33callback],dx
	mov [-pmodewe+_int33callback+2],cx
_nomousedriver2:
	mov ax,204h
	mov bl,33h
	int 31h
	mov [-pmodewe+_int33vectsel],cx
	mov [-pmodewe+_int33vectoff],edx
	mov ax,205h
	mov cx,cs
	mov edx,-pmodewe+_int33handler
	int 31h                         ; Hook protected mode INT 33h
_nomousedriver3:
%endif

%if INT1B
	db 66h,65h,0c7h,6,6ch,0
	reloc dw -pmodewe+_int1Brmhandler,pmcode16  ; This reloc is present %if INT1B.

;       MOV DWORD PTR GS:[6Ch], pmcode16:_int1Brmhandler

	mov esi,-pmodewe+_int1Bpmchandler
	call _initgetcallback
	mov [-pmodewe+_int1Bcallback],dx
	mov [-pmodewe+_int1Bcallback+2],cx
	mov ax,205h
	mov bl,1bh
	mov cx,cs
	mov edx,-pmodewe+_int1Bhandler
	int 31h                         ; Hook protected mode INT 1Bh
%endif
	add esp,32h
	clc
	jmp _initdosextnoerror
_initdosexterror:
	add esp,32h
	stc
_initdosextnoerror:
	popad
_ret:
	ret

%if INT33 || INT1B
_initgetcallback:
	multipush ds, es
	mov ax,303h
	movzx edi,word [-pmodewe+_int33cursorbufseg]
	shl edi,4
	add edi,64
	push gs
	pop es
	push cs
	pop ds
	int 31h                         ; Allocate a real mode callback
	multipop es, ds
	jnc _ret
	add esp,2
	jmp short _initdosexterror
%endif

;
; INT 31H HANDLER
;
%if INT31VENDOR
;
; INT 31h Service 0A00h - Get API Entry Point
; In:
;   AX - 0A00h
; Out:
;   CF=0
;
; !! TODO(pts): Omit if not needed, add -DINT31VENDOR=0.
_int310A00:
	cmp ax,strict word 0a00h
	jnz short _int31not0A00
	and byte [esp+8],~1  ; CF := 0.
	; TODO(pts): According to https://www.phatcode.net/res/262/files/dpmi09.html#18 , this should set ES:EDI to the extended API entry point. But it doesn't do anything. Why?
	iretd
_int31not0A00:

;
; INT 31h Service 0EEFFh - Get DOS Extender Information
; This is not a standard service, call but it's supported by DOS extenders
; PMODE/2, DOS/32A, WDOSX and some versions of D3X.
; In:
;   AX - 0EEFFh
; Out:
;  EAX - 'WDMP'. It's reverse is 'PMDW' for TASM.
;  ES:EBX -> PMODE/W Copyright String
;   CH - Protected Mode System Type (0=Raw, 1=XMS, 2=VCPI, 3=DPMI)
;   CL - Processor Type (3=386, 4=486, 5=586)
;   DH - Extender MAJOR Version (Binary)
;   DL - Extender MINOR Version (Binary)
;   CF=0
;
; !! TODO(pts): Omit if not needed, add -DINT31VENDOR=0.
	cmp ax,strict word 0eeffh
	jnz short _int31not0EEFF
	mov eax,'WDMP'  ; It's reverse is 'PMDW' for TASM.
	mov es,[cs:-pmodewe+_selzero]
	_xor ebx,ebx
	reloc mov bx,pmcode16  ; This reloc is present %if INT31VENDOR.
	shl ebx,4
	add ebx,strict dword -pmodewe+_copyrightmsg
%if SIZEOPT
	mov cx,[cs:-pmodewe+_pmode_process]  ; Also sets CH := _pmode_systype.
%else
	mov ch,[cs:-pmodewe+_pmode_systype]
	mov cl,[cs:-pmodewe+_pmode_process]
%endif
%if SIZEOPT
	mov dx,(PMWVER_MAJOR<<8 | PMWVER_MINOR)
%else
	mov dh,PMWVER_MAJOR
	mov dl,PMWVER_MINOR
%endif
	and byte [esp+8],~1
	iretd
_int31not0EEFF:
	fixpre_jmp_dword far [cs:-pmodewe+_oldint31off]
%endif

;
; INT 33h Handler
;
%if INT33
_int33handler:
	pushad
	push es
	cld
	cmp ax,strict word 9
	jz _int3309
	cmp ax,strict word 0ch
	jz _int330C
	cmp ax,strict word 16h
	jz _int3316
	cmp ax,strict word 17h
	jz _int3317
	pop es
	popad
	fixpre_jmp_dword far [cs:-pmodewe+_int33vectoff]

;
; INT 33h Function 09h - Set Graphics Cursor Block
; In:
;   AX - 09h
;   BX - Horizontal Hot Spot
;   CX - Vertical Hot Spot
;   ES:EDX -> Mask
; Out:
;   None
;
_int3309:
	sub esp,32h
	_mov ebp,esp
	push ds
	mov [ebp+_eax],ax
	mov [ebp+_ebx],bx
	mov [ebp+_ecx],cx
	push es
	pop ds
	_mov esi,edx
	fixpre_movzx_word edi,cs,-pmodewe+_int33cursorbufseg
	mov [ebp+_es],di
	mov word [ebp+_edx],0
	shl edi,4
	mov es,[cs:-pmodewe+_int21datasel]
	mov ecx,64
	rep a32 movsb
	call _realmodeint33
	pop ds
	add esp,32h
	jmp _endint21handler

;
; INT 33h Function 0Ch - Set Interrupt Subroutine
; In:
;   AX - 0Ch
;   CX - Call Mask
;   ES:EDX -> Routine
; Out:
;   None
;
_int330C:
	sub esp,32h
	_mov ebp,esp
	push ds
	mov ds,[cs:-pmodewe+_int21datasel64]
	mov [ebp+_eax],ax
	mov [ebp+_ecx],cx
	reloc mov word [ebp+_es],pmcode16  ; This reloc is is present %if INT33.
	mov word [ebp+_edx],-pmodewe+_int330Crmentry
	_xor eax,eax
	mov ax,es
	_or eax,edx
	jnz short _int330C1
	mov [ebp+_es],dx
	mov [ebp+_edx],dx
;        mov word ptr [ebp+_ecx],dx
_int330C1:
	cli
	mov [-pmodewe+_int330Ccallsel],es
	mov [-pmodewe+_int330Ccalloff],edx
	call _realmodeint33
	sti
	pop ds
	add esp,32h
	jmp _endint21handler

_int330Crmentry:
	push ax
	mov al,1
	xchg al,[cs:-pmodewe+_int33entryflag]
	cmp al,1
	jz short _int330Crmexit
	pop ax
	jmp far [cs:-pmodewe+_int33callback]
_int330Crmreturn:
	mov byte [cs:-pmodewe+_int33entryflag],0
	retf
_int330Crmexit:
	pop ax
	retf

_int330Cpmentry:
	push ss
	push esp
	pushad
	multipush ds, es
	cld

	_xor eax,eax
	mov ax,ss
	lar eax,eax
	test eax,400000h
	jnz short _int330Cos2crap
	movzx esp,sp

%if 0  ; This works in NASM.
        xor eax,eax
        mov ax,ss
        lar eax,eax
        test eax,400000h
        jnz short _int330Cos2crap
        multipush es, edi
        sub sp,8

        movzx edi,sp
        mov bx,ss
        mov es,bx
        mov ax,0bh
        int 31h

        or byte [es:edi+6],40h
        mov ax,0ch
        mov bx,[cs:-pmodewe+_selfixup]
        int 31h

        movzx esp,sp
        mov ss,bx

        add esp,8
        multipop edi, es
%endif

_int330Cos2crap:
	reloc mov word [es:edi+_cs],pmcode16  ; This reloc is is present %if INT33.
	mov word [es:edi+_ip],-pmodewe+_int330Crmreturn
	db 0x66, 0x26, 0x67, 0x0f, 0xb7, 0x47, _eax  ; movzx eax,word [es:edi+_eax]  ; Diff: TASM encodes the 0x66 prefix, then the segment prefix, NASM does it the other way round.
	db 0x66, 0x26, 0x67, 0x0f, 0xb7, 0x5f, _ebx  ; movzx ebx,word [es:edi+_ebx]  ; Diff: TASM encodes the 0x66 prefix, then the segment prefix, NASM does it the other way round.
	db 0x66, 0x26, 0x67, 0x0f, 0xb7, 0x4f, _ecx  ; movzx ecx,word [es:edi+_ecx]  ; Diff: TASM encodes the 0x66 prefix, then the segment prefix, NASM does it the other way round.
	db 0x66, 0x26, 0x67, 0x0f, 0xb7, 0x57, _edx  ; movzx edx,word [es:edi+_edx]  ; Diff: TASM encodes the 0x66 prefix, then the segment prefix, NASM does it the other way round.
	db 0x66, 0x26, 0x67, 0x0f, 0xb7, 0x77, _esi  ; movzx esi,word [es:edi+_esi]  ; Diff: TASM encodes the 0x66 prefix, then the segment prefix, NASM does it the other way round.
	db 0x66, 0x26, 0x67, 0x0f, 0xb7, 0x3f        ; movzx edi,word [es:edi+_edi]  ; Diff: TASM encodes the 0x66 prefix, then the segment prefix, NASM does it the other way round.
	fixpre_call_dword far [cs:-pmodewe+_int330Ccalloff]
	multipop es, ds
	popad
	lss esp,[esp]
	add esp,2
	iretd

;
; INT 33h Function 16h - Save Mouse Driver State
; In:
;   AX - 16h
;   ES:EDX -> State Buffer
; Out:
;   None
;
_int3316:
	sub esp,32h
	_mov ebp,esp
	push ds
	mov [ebp+_eax],ax
	mov ax,[cs:-pmodewe+_int21lowbufseg]
	mov [ebp+_es],ax
	mov word [ebp+_edx],0
	push edx
	call _realmodeint33
	pop edx
	_mov edi,edx
	mov ds,[cs:-pmodewe+_int21datasel]
	fixpre_mov esi,[cs:-pmodewe+_int21lowbufptr]
	fixpre_mov ecx,[cs:-pmodewe+_int33mousebufsize]
	rep a32 movsb
	pop ds
	add esp,32h
	jmp _endint21handler

;
; INT 33h Function 17h - Restore Mouse Driver State
; In:
;   AX - 17h
;   ES:EDX -> State Buffer
; Out:
;   None
;
_int3317:
	sub esp,32h
	_mov ebp,esp
	push ds
	mov [ebp+_eax],ax
	push es
	pop ds
	_mov esi,edx
	mov es,[cs:-pmodewe+_int21datasel]
	fixpre_mov edi,[cs:-pmodewe+_int21lowbufptr]
	fixpre_mov ecx,[cs:-pmodewe+_int33mousebufsize]
	rep a32 movsb
	mov ax,[cs:-pmodewe+_int21lowbufseg]
	mov [ebp+_es],ax
	mov word [ebp+_edx],0
	call _realmodeint33
	pop ds
	add esp,32h
	jmp _endint21handler
%endif
;
; INT 21h Handler
;
_int21handler:
	pushad
	push es
%if INT1B
	cmp byte [cs:-pmodewe+_int1Bflag],1
	jnz _int21no1B
%if INT1B==2
	mov word [esp+1eh],4cfeh  ; exit(254);
%else
	mov word [esp+1eh],4c00h
%endif
;        jmp _int21tend
	jmp _int214C
_int21no1B:
%endif
	cld
	cmp ah,40h
	jb short _int21t1
	ja short _int21t2
	jz _int2140
_int21t1:
	cmp ah,39h
	jb short _int21t1a
	ja short _int21t1b
	jz _int2139
_int21t1a:
	cmp ah,9
	jz _int2109
	cmp ah,1ah
	jz _int211A
	cmp ah,1bh
	jz _int211B
	cmp ah,1ch
	jz _int211C
	cmp ah,1fh
	jz _int211F
	cmp ah,25h
	jz _int2125
	cmp ah,2fh
	jz _int212F
	cmp ah,32h
	jz _int2132
	cmp ah,34h
	jz _int2134
	cmp ah,35h
	jz _int2135
	jmp _int21tend
_int21t1b:
	cmp ah,3ah
	jz _int213A
	cmp ah,3bh
	jz _int213B
	cmp ah,3ch
	jz _int213C
	cmp ah,3dh
	jz _int213D
	cmp ah,3fh
	jz _int213F
	jmp short _int21tend
_int21t2:
	cmp ah,4ah
	jb short _int21t2a
	ja short _int21t2b
	jz _int214A
_int21t2a:
	cmp ah,41h
	jz _int2141
	cmp ah,43h
	jz _int2143
	cmp ah,47h
	jz _int2147
	cmp ah,48h
	jz _int2148
	cmp ah,49h
	jz _int2149
	jmp short _int21tend
_int21t2b:
	cmp ah,4bh
	jz _int214B
	cmp ah,4ch
	jz _int214C
	cmp ah,4eh
	jz _int214E
	cmp ah,4fh
	jz _int214F
	cmp ah,51h
	jz _int2151
	cmp ah,56h
	jz _int2156
	cmp ah,5bh
	jz _int213C
	cmp ah,62h
	jz _int2162
	cmp ah,0ffh
	jz _int21FF
_int21tend:
	pop es
	popad
	fixpre_jmp_dword far [cs:-pmodewe+_int21vectoff]

;
; DOS Termination Handler
;
_termhandler:
	pushfd
	pushad
%if 0  ; This works in NASM.
        mov ah,4dh                             ; TSRs will no longer work
        int 21h                                ; since this has been removed
        cmp ah,3
        jz _termnocr0
%endif
	reloc call PMODE_TEXT:-pmodewk+_pm_cleanup
	mov eax,cr0
	fixpre_cmp eax,[cs:-pmodewe+_cr0valuerm]
	jz short _termnocr0
	fixpre_mov eax,[cs:-pmodewe+_cr0valuerm]
	mov cr0,eax
_termnocr0:
	popad
	popfd
	movzx esp,sp
	jmp far [cs:-pmodewe+_termrmvect]

;
; INT 21h Service 9 - Output Character String
; In:
;   AH - 09h
;   DS:EDX -> $ Terminated String
; Out:
;   None
;
_int2109:
	sub esp,32h
	_mov ebp,esp

	push ds
	pop es
	_mov edi,edx

	or ecx,-1
	mov al,'$'
	repnz a32 scasb
	not ecx

	fixpre_cmp ecx,[cs:-pmodewe+_int21lowbufsize]
	jae _int2109a
	call _int2109sub1
	jmp short _int2109end
_int2109a:
	fixpre_mov edi,[cs:-pmodewe+_int21lowbufsize]
	dec edi
	_xchg ecx,ebx
_int2109b:
	_mov ecx,edi
	multipush edi, ebx
	call _int2109sub1
	multipop ebx, edi
	_add edx,edi
	_sub ebx,edi
	_cmp ebx,edi
	ja _int2109b
	_mov ecx,ebx
	call _int2109sub1
_int2109end:
	add esp,32h
	jmp _endint21handler

_int2109sub1:
	mov es,[cs:-pmodewe+_int21datasel]
	fixpre_mov edi,[cs:-pmodewe+_int21lowbufptr]
	_mov esi,edx
	rep a32 movsb
	mov byte [es:edi],'$'
	mov ax,[cs:-pmodewe+_int21lowbufseg]
	mov [ebp+_ds],ax
	mov byte [ebp+_eax+1],9
	mov word [ebp+_edx],0
	call _realmodeint21
	ret

;
; INT 21h Service 1Ah - Set Disk Transfer Area
; In:
;   AH - 1Ah
;   DS:EDX -> Buffer For DTA
; Out:
;   None
;
_int211A:
	mov es,[cs:-pmodewe+_int21datasel64]
	mov [es:-pmodewe+_int21dtasel],ds
	fixpre2_mov [es:-pmodewe+_int21dtaoff],edx
	sub esp,32h
	_mov ebp,esp
%if SIZEOPT  ; Make it better compressible by moving the `sub esp,32h' and `mov byte [ebp+_eax+1],...' instructions together.
	mov byte [ebp+_eax+1],1ah
	mov word [ebp+_edx],0
%endif
	mov dx,[cs:-pmodewe+_int21lowdtaseg]
	mov [ebp+_ds],dx
%if SIZEOPT==0
	mov byte [ebp+_eax+1],1ah
	mov word [ebp+_edx],0
%endif
	call _realmodeint21
	add esp,32h
	jmp _endint21handler

;
; INT 21h Service 1Bh - Get FAT Information For Default Drive
; In:
;   AH - 1Bh
; Out:
;   AL - Sectors Per Cluster
;   ECX - Bytes Per Sector
;   EDX - Clusters Per Disk
;   DS:EBX -> FAT ID Byte
;
_int211B:
	jmp _int211C

;
; INT 21h Service 1Ch - Get FAT Information For Drive
; In:
;   AH - 1Ch
;   DL - Drive Code
; Out:
;   AL - Sectors Per Cluster
;   ECX - Bytes Per Sector
;   EDX - Clusters Per Disk
;   DS:EBX -> FAT ID Byte
;
_int211C:
	sub esp,32h
	_mov ebp,esp
	mov [ebp+_eax+1],ah
	mov [ebp+_edx],dl
	push ax
	call _realmodeint21
	pop ax

	cmp ah,1fh
	jae _int211C1F
	movzx eax,word [ebp+_ecx]
	mov [ebp+50h-4],eax
	movzx eax,word [ebp+_edx]
	mov [ebp+50h-8],eax
_int211C1F:
	mov al,[ebp+_eax]
	mov [ebp+50h],al
	movzx eax,word [ebp+_ds]
	shl eax,4
	movzx ebx,word [ebp+_ebx]
	_add eax,ebx
	mov [ebp+50h-12],eax
	mov ds,[cs:-pmodewe+_int21datasel]

	add esp,32h
	jmp _endint21handler

;
; INT 21h Service 1Fh - Get Default Disk Parameter Block
; In:
;   AH - 1Fh
; Out:
;   AL - Error Status
;   DS:EBX -> Disk Parameter Block
;
_int211F:
	jmp _int211C

;
; INT 21h Service 25h - Set Interrupt Vector
; In:
;   AH - 25h
;   AL - Interrupt Number
;   DS:EDX -> Interrupt Routine
; Out:
;   None
;
_int2125:
	_mov bl,al
	mov ax,205h
	mov cx,ds
	int 31h
	jc _endint21error
	jmp _endint21handler

;
; INT 21h Service 2Fh - Get Disk Transfer Area
; In:
;   AH - 2Fh
; Out:
;   ES:EBX -> DTA
;
_int212F:
	fixpre_mov ebx,[cs:-pmodewe+_int21dtaoff]
	mov ax,[cs:-pmodewe+_int21dtasel]
	mov [esp],ax
	mov [esp+18],ebx
	jmp _endint21handler

;
; INT 21h Service 32h - Get Disk Parameter Block
; In:
;   AH - 32h
;   DL - Drive Number
; Out:
;   AL - Error Status
;   DS:EBX -> Disk Parameter Block
;
_int2132:
	jmp _int211C

;
; INT 21h Service 34h - Get Address Of InDOS Flag
; In:
;   AH - 34h
; Out:
;   ES:EBX -> InDOS Flag
;
_int2134:
	sub esp,32h
	_mov ebp,esp
	mov [ebp+_eax+1],ah
	call _realmodeint21

	movzx eax,word [ebp+_es]
	shl eax,4
	movzx ebx,word [ebp+_ebx]
	_add eax,ebx
	mov [ebp+50h-12],eax
	mov ax,[cs:-pmodewe+_int21datasel]
	mov [ebp+32h],ax

	add esp,32h
	jmp _endint21handler

;
; INT 21h Service 35h - Get Interrupt Vector
; In:
;   AH - 35h
;   AL - Interrupt Number
; Out:
;   ES:EBX -> Interrupt Routine
;
_int2135:
	_mov bl,al
	mov ax,204h
	int 31h
	mov [esp],cx
	mov [esp+18],edx
	jmp _endint21handler

;
; INT 21h Service 39h - Create Subdirectory
; In:
;   AH - 39h
;   DS:EDX -> ASCIIZ Path Name
; Out:
;   CF=0 Success
;   CF=1 Error
;
_int2139:
	sub esp,32h
	_mov ebp,esp
_int2139a:
	mov [ebp+_eax+1],ah
_int2139b:
	call _int21bufferpath
	jmp _endint21error_eax50h_0

;
; INT 21h Service 3Ah - Remove Subdirectory
; In:
;   AH - 3Ah
;   DS:EDX -> ASCIIZ Path Name
; Out:
;   CF=0 Success
;   CF=1 Error
;
_int213A:
	jmp _int2139

;
; INT 21h Service 3Bh - Set Directory
; In:
;   AH - 3Bh
;   DS:EDX -> ASCIIZ Path Name
; Out:
;   CF=0 Success
;   CF=1 Error
;
_int213B:
	jmp _int2139

;
; INT 21h Service 3Ch - Create File
; In:
;   AH - 3Ch
;   CX - Attribute
;   DS:EDX -> ASCIIZ Path Name
; Out:
;   CF=0 Success
;   CF=1 Error
;   EAX - Handle or Error Code If CF=1
;
_int213C:
	sub esp,32h
	_mov ebp,esp
	mov [ebp+_ecx],cx
	jmp short _int213Da

;
; INT 21h Service 3Dh - Open File
; In:
;   AH - 3Dh
;   AL - Open Code
;   DS:EDX -> ASCIIZ Path Name
; Out:
;   CF=0 Success
;   CF=1 Error
;   EAX - Handle or Error Code If CF=1
;
_int213D:
	sub esp,32h
	_mov ebp,esp
_int213Da:
	mov [ebp+_eax],ax

	call _int21bufferpath
	movzx eax,word [ebp+_eax]
	mov [ebp+50h],eax

	test byte [ebp+_flags],1
	jnz _int213Derr
	add esp,32h
	jmp _endint21handler
_int213Derr:
	add esp,32h
	jmp _endint21error

;
; INT 21h Service 3Fh - Read File
; In:
;   AH - 3Fh
;   BX - File Handle
;   ECX - Number Of Bytes To Read
;   DS:EDX -> Buffer To Read To
; Out:
;   CF=0 Success
;   CF=1 Error
;   EAX - Number Of Bytes Read or Error Code If CF=1
;
_int213F:
	push ds
	sub esp,32h
	_mov ebp,esp
	mov [ebp+_ebx],bx

	push ds
	pop es
	_mov edi,edx
	mov ds,[cs:-pmodewe+_int21datasel]

	mov ax,[cs:-pmodewe+_int21lowbufseg]
	mov [ebp+_ds],ax
	mov word [ebp+_edx],0

_int213Fmod1:
	times 4 nop

;       90h 90h 90h 90h | 67h 01h 55h 14h
;       nop nop nop nop | add word ptr [ebp+_edx],dx

	fixpre_cmp ecx,[cs:-pmodewe+_int21lowbufsize]
	ja _int213Fa
	mov byte [ebp+_eax+1],3fh
	mov [ebp+_ecx],cx
	push edi
	call _realmodeint21
	pop edi
	movzx eax,word [ebp+_eax]
	mov [ebp+32h+4+28],eax
	test byte [ebp+_flags],1
	jnz _int213Ferr
	_mov ecx,eax
	fixpre_mov esi,[cs:-pmodewe+_int21lowbufptr]
	jmp_cond_near ecxz, _int213Fend
_int213Fmod2:
	rep a32 movsb

;       F3h 67h A4h | 90h 90h 90h
;       rep movs... | nop nop nop

	jmp _int213Fend
_int213Fa:
	_mov ebx,ecx
	_xor edx,edx
_int213Fb:
	mov byte [ebp+_eax+1],3fh
	fixpre_mov eax,[cs:-pmodewe+_int21lowbufsize]
	mov [ebp+_ecx],ax
	multipush ebx, edi
	call _realmodeint21
	multipop edi, ebx
	movzx eax,word [ebp+_eax]
	test byte [ebp+_flags],1
	jz _int213Fc
	mov [ebp+32h+4+28],eax
	jmp _int213Ferr
_int213Fc:
	_add edx,eax
	fixpre_mov esi,[cs:-pmodewe+_int21lowbufptr]
	_mov ecx,eax
	jecxz _int213Fd
	rep a32 movsb
	fixpre_cmp eax,[cs:-pmodewe+_int21lowbufsize]
	jnz _int213Fd
	_sub ebx,eax
	fixpre_cmp ebx,[cs:-pmodewe+_int21lowbufsize]
	jae _int213Fb
	_or ebx,ebx
	jz _int213Fd
	mov byte [ebp+_eax+1],3fh
	mov [ebp+_ecx],bx
	push edi
	call _realmodeint21
	pop edi
	movzx eax,word [ebp+_eax]
	test byte [ebp+_flags],1
	jz _int213Fc1
	mov [ebp+32h+4+28],eax
	jmp _int213Ferr
_int213Fc1:
	_add edx,eax
	fixpre_mov esi,[cs:-pmodewe+_int21lowbufptr]
	_mov ecx,eax
	jecxz _int213Fd
	rep a32 movsb
_int213Fd:
	mov [ebp+32h+4+28],edx
_int213Fend:
	add esp,32h
	pop ds
	jmp _endint21handler
_int213Ferr:
	add esp,32h
	pop ds
	jmp _endint21error

;
; INT 21h Service 3Fh Read Buffer Toggle
;
_int213Fbuftoggle:
	xor dword [-pmodewe+_int213Fmod1],84C591F7h
	xor word [-pmodewe+_int213Fmod2],0F763h
	xor byte [-pmodewe+_int213Fmod2+2],34h
	ret

;
; INT 21h Service 40h - Write File
; In:
;   AH - 40h
;   BX - File Handle
;   ECX - Number Of Bytes To Write
;   DS:EDX -> Buffer To Write From
; Out:
;   CF=0 Success
;   CF=1 Error
;   EAX - Number Of Bytes Written or Error Code If CF=1
;
_int2140:
	sub esp,32h
	_mov ebp,esp
	mov [ebp+_ebx],bx

	_mov esi,edx
	mov es,[cs:-pmodewe+_int21datasel]

	mov ax,[cs:-pmodewe+_int21lowbufseg]
	mov [ebp+_ds],ax
	mov word [ebp+_edx],0

	fixpre_cmp ecx,[cs:-pmodewe+_int21lowbufsize]
	ja _int2140a
	mov byte [ebp+_eax+1],40h
	mov [ebp+_ecx],cx
	movzx ecx,cx
	jecxz _int2140z
	fixpre_mov edi,[cs:-pmodewe+_int21lowbufptr]
	rep a32 movsb
_int2140z:
	call _realmodeint21
	movzx eax,word [ebp+_eax]
	mov [ebp+32h+2+28],eax
	test byte [ebp+_flags],1
	jnz _int2140err
	jmp _int2140end
_int2140a:
	_mov ebx,ecx
	_xor edx,edx
_int2140b:
	mov byte [ebp+_eax+1],40h
	fixpre_mov eax,[cs:-pmodewe+_int21lowbufsize]
	mov [ebp+_ecx],ax
	movzx ecx,ax
	fixpre_mov edi,[cs:-pmodewe+_int21lowbufptr]
	rep a32 movsb
	push ebx
	call _realmodeint21
	pop ebx
	movzx eax,word [ebp+_eax]
	test byte [ebp+_flags],1
	jz _int2140c
	mov [ebp+32h+2+28],eax
	jmp _int2140err
_int2140c:
	_add edx,eax
	fixpre_cmp eax,[cs:-pmodewe+_int21lowbufsize]
	jnz _int2140d
	_sub ebx,eax
	fixpre_cmp ebx,[cs:-pmodewe+_int21lowbufsize]
	jae _int2140b
	_or ebx,ebx
	jz _int2140d
	mov byte [ebp+_eax+1],40h
	mov [ebp+_ecx],bx
	movzx ecx,bx
	fixpre_mov edi,[cs:-pmodewe+_int21lowbufptr]
	rep a32 movsb
	call _realmodeint21
	movzx eax,word [ebp+_eax]
	test byte [ebp+_flags],1
	jz _int2140c1
	mov [ebp+32h+2+28],eax
	jmp _int2140err
_int2140c1:
	_add edx,eax
_int2140d:
	mov [ebp+32h+2+28],edx
_int2140end:
	add esp,32h
	jmp _endint21handler
_int2140err:
	add esp,32h
	jmp _endint21error

;
; INT 21h Service 41h - Delete File
; In:
;   AH - 41h
;   DS:EDX -> ASCIIZ Path Name
; Out:
;   CF=0 Success
;   CF=1 Error
;
_int2141:
	jmp _int2139

;
; INT 21h Service 43h - Get/Set File Attributes
; In:
;   AH - 43h
;   AL - Function Code
;   CX - Desired Attributes
;   DS:EDX -> ASCIIZ Path Name
; Out:
;   CF=0 Success
;   CF=1 Error
;   EAX - Error Code If CF=1
;   ECX - Current Attributes
;
_int2143:
	sub esp,32h
	_mov ebp,esp
	mov [ebp+_eax],ax
	mov [ebp+_ecx],cx
	call _int21bufferpath
	movzx ecx,word [ebp+_ecx]
	mov [ebp+50h-4],ecx
	jmp _endint21error_eax50h_0

;
; INT 21h Service 47h - Get Directory Path
; In:
;   AH - 47h
;   DL - Drive Number
;   DS:ESI -> Buffer For Path
; Out:
;   CF=0 Success
;   CF=1 Error
;   EAX - Error Code If CF=1
;   DS:ESI -> Buffer For Path (Filled If CF=0)
;
_int2147:
	sub esp,32h
	_mov ebp,esp
	mov [ebp+_eax+1],ah
	mov [ebp+_edx],dl

	mov dword [ebp+50h],0

	mov ax,[cs:-pmodewe+_int21lowbufseg]
	mov [ebp+_ds],ax
	mov word [ebp+_esi],0
	call _realmodeint21

	test byte [ebp+_flags],1
	jnz _int2147err
	fixpre_mov edi,[cs:-pmodewe+_int21lowbufptr]
	mov es,[cs:-pmodewe+_int21datasel]
	or ecx,-1
	_xor al,al
	repnz a32 scasb
	not ecx
	push ds
	_sub edi,ecx
	_xchg esi,edi
	mov ax,es
	mov bx,ds
	mov es,bx
	mov ds,ax
	rep a32 movsb
	pop ds
	add esp,32h
	jmp _endint21handler
_int2147err:
	movzx eax,word [ebp+_eax]
	mov [ebp+50h],eax
	add esp,32h
	jmp _endint21error

;
; INT 21h Service 48h - Allocate Memory
; In:
;   AH - 48h
;   BX - Paragraphs To Allocate
; Out:
;   CF=0 Success
;   CF=1 Error
;   EAX - Selector To Memory If CF=0 or Error Code If CF=1
;   EBX - Maximum Paragraphs Available If CF=1
;
_int2148:
	mov ax,100h
	int 31h
	movzx edx,dx
	mov [esp+1eh],edx
	jnc _endint21handler
	movzx eax,ax
	mov [esp+1eh],eax
	movzx ebx,bx
	mov [esp+1eh-12],ebx
	jmp _endint21error

;
; INT 21h Service 49h - Free Memory
; In:
;   AH - 49h
;   ES - Selector
; Out:
;   CF=0 Success
;   CF=1 Error
;   ES  - Null Selector
;   EAX - Error Code If CF=1
;
_int2149:
	mov ax,101h
	mov dx,es
	int 31h
	jnc _int2149a
	movzx eax,ax
	mov [esp+1eh],eax
	jmp _endint21error
_int2149a:
	mov word [esp],0
	jmp _endint21handler

;
; INT 21h Service 4Ah - Change Memory Block Allocation
; In:
;   AH - 4Ah
;   BX - Total Paragraphs To Allocate
;   ES - Selector
; Out:
;   CF=0 Success
;   CF=1 Error
;   EAX - Error Code If CF=1
;   EBX - Maximum Paragraphs Available If CF=1
;
_int214A:
	mov ax,102h
	mov dx,es
	int 31h
	jnc _endint21handler
	movzx eax,ax
	mov [esp+1eh],eax
	movzx ebx,bx
	mov [esp+1eh-12],ebx
	jmp _endint21error

;
; INT 21h Service 4Bh, Function 00h - Load Program
; In:
;   AH - 4Bh
;   AL - 00h
;   DS:EDX -> Path Name
;   ES:EBX -> Parameter Block
; Out:
;   CF=0 Success
;   CF=1 Error
;
_int214B:
	sub esp,32h
	_mov ebp,esp
	mov [ebp+_eax],ax

	_or al,al
	jnz _int21err_leave_eax

	push es
	mov ax,ds
	mov es,ax
	_mov edi,edx

	or ecx,-1
	_xor al,al
	repnz a32 scasb
	not ecx

	mov es,[cs:-pmodewe+_int21datasel]
	fixpre_mov edi,[cs:-pmodewe+_int21lowbufptr]
	add edi,2048
	_mov esi,edx
	rep a32 movsb

	mov es,[cs:-pmodewe+_int21datasel]
	fixpre_mov edi,[cs:-pmodewe+_int21lowbufptr]
	mov ecx,22
	_xor al,al
	rep a32 stosb
	sub edi,22
	mov ax,[cs:-pmodewe+_int21lowbufseg]
	mov word [es:edi+2],22
	mov [es:edi+4],ax
	mov word [es:edi+6],5ch
	mov word [es:edi+10],6ch
	mov ax,[cs:-pmodewe+_pspseg]
	mov [es:edi+8],ax
	mov [es:edi+12],ax
	pop es

	multipush es, ds
	mov ds,[es:ebx+10]
	fixpre_mov esi,[es:ebx+6]
	mov es,[cs:-pmodewe+_int21datasel]
	fixpre_mov edi,[cs:-pmodewe+_int21lowbufptr]
	add edi,22
	movzx ecx,byte [esi]
	inc cx
	inc cx
	rep a32 movsb
	multipop ds, es

	multipush ds, es
	fixpre_mov edi,[es:ebx]
	mov es,[es:ebx+4]
	_mov esi,edi
	or ecx,-1
	_xor al,al
_int214B00a:
	repnz a32 scasb
	dec ecx
	a32 scasb
	jnz _int214B00a
	not ecx
	mov ax,100h
	_mov ebx,ecx
	shr ebx,4
	inc bx
	int 31h
	jc _int214B00err1
	push es
	pop ds
	mov es,dx
	_xor edi,edi
	rep a32 movsb
	mov es,[cs:-pmodewe+_int21lowbufsel]
	mov [es:0],ax
	clc
_int214B00err1:
	multipop es, ds
	jc _int21err_leave_eax

	mov ax,[cs:-pmodewe+_int21lowbufseg]
	mov [ebp+_ds],ax
	mov [ebp+_es],ax
	mov word [ebp+_ebx],0
	mov word [ebp+_edx],2048

	mov eax,cr0
	test al,4
	jz _int214Bnocp1
	and al,~4
	mov cr0,eax
	call _realmodeint21
	mov eax,cr0
	or al,4
	mov cr0,eax
	jmp short _int214Bnocp2
_int214Bnocp1:
	call _realmodeint21
_int214Bnocp2:
	mov ax,101h
	int 31h
	jmp _endint21error_eax50h_0

;
; INT 21h Service 4Ch - Terminate Process
; In:
;   AH - 4Ch
;   AL - Error Code
; Out:
;   None
;
_int214C:
%if INT33
	fixpre_mov edx,[cs:-pmodewe+_int33callback]
	_mov ecx,edx
	shr ecx,16
	mov ax,304h
	int 31h
_int214C_no33:
%endif
%if INT1B
	fixpre_mov edx,[cs:-pmodewe+_int1Bcallback]
	_mov ecx,edx
	shr ecx,16
	mov ax,304h
	int 31h
_int214C_no1B:
%endif
	jmp _int21tend

;
; INT 21h Service 4Eh - Search For First Filename Match
; In:
;   AH - 4Eh
;   CX - File Attribute
;   DS:EDX -> ASCIIZ Path Name
; Out:
;   CF=0 Success
;   CF=1 Error
;
_int214E:
	sub esp,32h
	_mov ebp,esp
%if SIZEOPT  ; Make it better compressible by moving the `_mov_ebp,esp' and `mov [ebp+_eax+1],ah' instructions together.
	mov [ebp+_eax+1],ah
	mov [ebp+_ecx],cx
%else
	mov [ebp+_ecx],cx
	mov [ebp+_eax+1],ah
%endif

	call _int21bufferpath

	mov dword [ebp+50h],0

	test byte [ebp+_flags],1
	jnz _int214Eerr
	push ds
	mov ds,[cs:-pmodewe+_int21datasel]
	fixpre_movzx_word esi,cs,-pmodewe+_int21lowdtaseg
	shl esi,4
	mov es,[cs:-pmodewe+_int21dtasel]
	fixpre_mov edi,[cs:-pmodewe+_int21dtaoff]
	mov ecx,43
	rep a32 movsb
	pop ds
	add esp,32h
	jmp _endint21handler
_int214Eerr:
	movzx eax,word [ebp+_eax]
	mov [ebp+50h],eax
	add esp,32h
	jmp _endint21error

;
; INT 21h Service 4Fh - Search For Next Filename Match
; In:
;   AH - 4Fh
; Out:
;   CF=0 Success
;   CF=1 Error
;
_int214F:
	sub esp,32h
	_mov ebp,esp
	mov [ebp+_eax+1],ah

	push ds
	mov es,[cs:-pmodewe+_int21datasel]
	fixpre_movzx_word edi,cs,-pmodewe+_int21lowdtaseg
	shl edi,4
	mov ds,[cs:-pmodewe+_int21dtasel]
	fixpre_mov esi,[cs:-pmodewe+_int21dtaoff]
	mov ecx,43
	rep a32 movsb
	pop ds

	call _realmodeint21

	mov dword [ebp+50h],0

	test byte [ebp+_flags],1
	jnz _int214Ferr
	push ds
	mov ds,[cs:-pmodewe+_int21datasel]
	fixpre_movzx_word esi,cs,-pmodewe+_int21lowdtaseg
	shl esi,4
	mov es,[cs:-pmodewe+_int21dtasel]
	fixpre_mov edi,[cs:-pmodewe+_int21dtaoff]
	mov ecx,43
	rep a32 movsb
	pop ds
	add esp,32h
	jmp _endint21handler
_int214Ferr:
	movzx eax,word [ebp+_eax]
	mov [ebp+50h],eax
	add esp,32h
	jmp _endint21error

;
; INT 21h Service 51h - Get PSP Segment
; In:
;   AH - 51h
; Out:
;   BX - PSP Segment Address
;
_int2151:
	mov ax,[cs:-pmodewe+_pspseg]
	mov [esp+18],ax
	jmp _endint21handler

;        sub esp,32h
;        mov ebp,esp
;        mov byte ptr [ebp+_eax+1],ah
;        call _realmodeint21
;
;        mov bx,[ebp+_ebx]
;        mov word ptr [ebp+50h-12],bx
;
;        add esp,32h
;        jmp _endint21handler

;
; INT 21h Service 56h - Rename File
; In:
;   AH - 56h
;   DS:EDX -> Old Filename
;   ES:EDI -> New Filename
; Out:
;   CF=0 Success
;   CF=1 Error
;
_int2156:
	sub esp,32h
	_mov ebp,esp
	mov [ebp+_eax+1],ah

	or ecx,-1
	_xor al,al
	repnz a32 scasb
	not ecx
	_sub edi,ecx
	push ds
	_mov esi,edi
	mov ax,es
	mov ds,ax
	mov es,[cs:-pmodewe+_int21datasel]
	fixpre_mov edi,[cs:-pmodewe+_int21lowbufptr]
	rep a32 movsb
	pop ds

	_mov ecx,edi
	fixpre_mov ebx,[cs:-pmodewe+_int21lowbufptr]
	_sub ecx,ebx
	_xchg ecx,ebx

	mov ax,ds
	mov es,ax
	_mov esi,edx
	_xchg esi,edi
	or ecx,-1
	_xor al,al
	repnz a32 scasb
	not ecx
	_sub edi,ecx
	_xchg esi,edi
	mov es,[cs:-pmodewe+_int21datasel]
	rep a32 movsb

	mov ax,[cs:-pmodewe+_int21lowbufseg]
	mov [ebp+_ds],ax
	mov [ebp+_es],ax
	mov word [ebp+_edi],0
	mov [ebp+_edx],bx
	call _realmodeint21

	jmp short _endint21error_eax50h_0

;
; INT 21h Service 62h - Get PSP Segment (returns selector)
; In:
;   AH - 62h
; Out:
;   BX - PSP Segment Address
;
_int2162:
	mov ax,[cs:-pmodewe+_selpsp]
	mov [esp+18],ax
	jmp _endint21handler

;
; INT 21h Service FFh - DOS Extender Check
; In:
;   AH - FFh
;   DX - 78h
; Out:
;   GS - Info Segment
;
_int21FF:
	cmp dx,78h
	jnz _int21FFend
	mov gs,[cs:-pmodewe+_int21lowbufsel]
	mov dword [esp+1eh],4734FFFFh
	jmp _endint21handler
_int21FFend:
	jmp _int21tend

;
; End Of INT 21h Handler
;
_endint21handler:
	pop es
	popad
	and byte [esp+8],~1
	iretd
_endint21error:
	pop es
	popad
	or byte [esp+8],1
	iretd

_endint21error_eax50h_0:
	mov dword [ebp+50h],0
_endint21error_eax50h:
	test byte [ebp+_flags],1
	jnz _int21err_eax50h
	add esp,32h
	jmp _endint21handler
_int21err_eax50h:
	movzx eax,word [ebp+_eax]
	mov [ebp+50h],eax
_int21err_leave_eax:
	add esp,32h
	jmp _endint21error

;
; Call Real Mode Interrupt Routine
;
%if INT33
_realmodeint33:
	mov bx,33h
	jmp short _realmodeintq
%endif
_realmodeint21:
; Ruins EAX, BX, CX.
	mov bx,21h
_realmodeintq:
	push es
	_xor eax,eax
	mov [ebp+_sp],eax
	mov [ebp+_flags],ax
	push ss
	pop es
	_mov edi,ebp
	mov ax,300h
	_xor cx,cx
	int 31h
	pop es
	ret

;
; Subroutine For Some INT 21h Functions
;
_int21bufferpath:
	push ds
	pop es
	_mov edi,edx

	or ecx,-1
	_xor al,al
	repnz a32 scasb
	not ecx

	mov es,[cs:-pmodewe+_int21datasel]
	fixpre_mov edi,[cs:-pmodewe+_int21lowbufptr]
	_mov esi,edx
	rep a32 movsb

	mov ax,[cs:-pmodewe+_int21lowbufseg]
	mov [ebp+_ds],ax
	mov word [ebp+_edx],0
	call _realmodeint21
	ret

;
; INT 1Bh Handler
;
%if INT1B
_int1Brmhandler:
	jmp far [cs:-pmodewe+_int1Bcallback]
_int1Brmreturn:
	iret

_int1Bpmchandler:
	reloc mov word [es:edi+_cs],pmcode16  ; This reloc is is present %if INT1B.
	mov word [es:edi+_ip],-pmodewe+_int1Brmreturn
	int 1bh
	iretd

_int1Bhandler:
	push ds
	mov ds,[cs:-pmodewe+_int21datasel64]
	mov byte [-pmodewe+_int1Bflag],1
	pop ds
	iretd
%endif

;
; SUPPLEMENTAL REAL MODE ROUTINES
;
%if OPENTYPE==1  ; Opens the currently running .exe file. Useful when PMODE/W is used as a stub at the beginning of the .exe file.
_openexe1_opentype_1:
_openexe1:
_openexe:
	multipush ds, es
	mov es,[-pmodewe+_envseg]
	push word [-pmodewe+_int21lowbufseg]
	pop ds
	_xor di,di

	or cx,-1  ; Pratically unlimted `repne scasb' below.
	_xor al,al
.00l:
	repne scasb  ; Skip a single environment variable.
	scasb
	jne .00l  ; If this jumps, it continues skipping the next environment variable.

	add di,2  ; Skip 2 more bytes. After this, ES:DI points to the full filename.
	_mov si,di

	or cx,-1
	repne scasb
	not cx

	_xor di,di
	multipush es, ds
	multipop es, ds

	rep movsb

	push es
	pop ds

	_xor dx,dx
	mov ax,3dc0h  ; Open file for reading: (private == not inheritable) | (full access permitted to all others) | (read access).
	int 21h
	multipop es, ds
	jc _loaderror
	jmp _openexe2  ; This is a no-op, openexe2 is right after this.
%endif

%if OPENTYPE==2  ; Opens the .exe file with filename as a NUL-terminated string at 0:4c0h == 40h:0c0h. At most 0x40 == 64 bytes can be stored there.
_openexe1_opentype_2:
_openexe1:
_openexe:
	push ds
	_xor ax,ax
	mov ds,ax
	mov dx,4c0h  ; NUL-terminated filename at 0:4c0h. Who put it there? Maybe another process. Typically 0x40 == 64 bytes fit here, because 50h:0 is print-screen status in the BIOS.
	mov ax,3dc0h  ; Open file for reading: (private == not inheritable) | (full access permitted to all others) | (read access).
	int 21h
	pop ds
	jc _loaderror
	jmp _openexe2  ; This is a no-op, openexe2 is right after this.
%endif

%if OPENTYPE==3  ; Opens the .exe file specified at the beginning of the command line (space-separated), and removes that filename from the command line.
_filename	times 128 db ANY
_openexe1_opentype_3:
_openexe1:
_openexe:
	cld
	multipush es, ds
	mov ds,[cs:-pmodewe+_pspseg]
	mov ax,cs
	mov es,ax
	mov di,-pmodewe+_filename
	mov si,80h  ; After this, DS:SI points to the 0dh-terminated, length-prefixed command-line (excluding the program name) in the PSP: PSPseg:80h.
	lodsb
	_or al,al
	jz _openexe3err  ; This jumps iff the command line is empty.
_openexe3a1:
	lodsb
	cmp al,20h
	jz _openexe3a1  ; Continue skipping initial spaces.
	mov cx,-1
	jmp _openexe3b
_openexe3a:
	lodsb
_openexe3b:
	cmp al,20h
	jz _openexe3c
	cmp al,0dh
	jz _openexe3c
	stosb
	dec cx
	jnz _openexe3a
	jmp _openexe3err  ; This can't possibly happen: filename in PSP is >=~64 KiB long.
_openexe3c:  ; Now DS:SI points to the terminating space (20h) or 0dh (end-of-string) after the program name.
	_xor al,al
	stosb
	_xor bl,bl
	dec si
	mov ax,ds
	mov es,ax
	mov di,81h
_openexe3d:  ; Copy the rest of the command-line back to the begnning of the command line.
	lodsb
	_or al,al
	cmp al,0dh
	jz _openexe3e
	inc bl
	stosb
	jmp _openexe3d
_openexe3e:
	stosb
	mov [es:80h],bl
	mov dx,-pmodewe+_filename
	push cs
	pop ds
	mov ax,3dc0h  ; Open file for reading: (private == not inheritable) | (full access permitted to all others) | (read access).
	int 21h
	multipop ds, es
	jc _loaderror
	jmp _openexe2
_openexe3err:
	multipop ds, es
	jmp _loaderror
%endif

%if VARTYPE==1  ; Loads pmodew_config from the first 15h bytes of the MZ .exe image (file offset hdrsize<<4). Also loads the file offset of the 32-bit payload from dword at file offset 3ch.

%if LOADSPE
_openexe2.j_loaderror:
	jmp _loaderror
%endif

_openexe2_vartype_1:
_openexe2:
	; Input: DS == pmode16, corresponding to pmodewe.
	mov [-pmodewe+_exehandle],ax
	push ds
	_mov bx,ax
	; Read the LE/PMW1 header and pmodew_config from the .exe.
%if LOADSPE
	mov cx, 200h  ; Must be at most DTABUFSIZE == 200h.
	mov ds, [-pmodewe+_int21lowdtaseg]
	_xor dx, dx
	mov ah, 3fh  ; Read from file using handle.
	int 21h
	jc short .j_loaderror
	_cmp ax, cx
	jne short .j_loaderror
  %if CONFIGTYPE==2
	mov di, spefofs.pmodew_config  ; 20h == 32.
	cmp word  [di-spefofs.pmodew_config+spefofs.mzhdr.signature], 'MZ'
	jne short .j_loaderror
	push es  ; Save.
	mov si, [di-spefofs.pmodew_config+spefofs.mzhdr.hdrsize]
	cmp si, (200h-pmodew_config._size)>>4
	ja short .j_loaderror
	shl si, 4
	push ds
	pop es  ; ES := DS, for rep movsb below.
	mov cx, pmodew_config._size  ; 15h == 21.
	rep movsb
	mov si, spefofs.pmodew_config  ; Used by the `rep movsb' below.
	mov dx, [si-spefofs.pmodew_config+spefofs.pehdr_fofs_ptr+0]
	mov cx, [si-spefofs.pmodew_config+spefofs.pehdr_fofs_ptr+2]  ; CX:DX == file offset of PE header.
	and dl, ~1  ; Ignore the lowest bit (SPEDOSONLY) of the file offset of PE header.
	mov ax, 4200h  ; Move file pointer using handle. whence (AL) := SEEK_SET (== 0).
	int 21h
	jc short .j_loaderror
	mov dx, spefofs.pehdr
	mov cx, 200h-spefofs.pehdr
	mov ah, 3fh  ; Read from file using handle.
	int 21h
	jc short .j_loaderror
	_cmp ax, cx
	jne short .j_loaderror
  %elif CONFIGTYPE==1
	mov si, spefofs.pmodew_config  ; Used by the `rep movsb' below.
  %else
    %error BAD_LOADSPE_CONFIGTYPE CONFIGTYPE
  %endif
  %if LOADSPE==2  ; Omit the check below to make pmodewu.exe and pmodew.exe shorter.
  %else
    %if CONFIGTYPE==2
	cmp dword [si-spefofs.pmodew_config+spefofs.pehdr.Signature], 'PE'
	jne short .j_loaderror
	or byte [si-spefofs.pmodew_config+spefofs.pehdr_fofs_ptr], 1
    %else
	cmp word  [si-spefofs.pmodew_config+spefofs.mzhdr.signature], 'MZ'
	jne short .j_loaderror
	cmp word  [si-spefofs.pmodew_config+spefofs.mzhdr.hdrsize], (160h+0fh)>>4  ; IMAGE_SECTION_HEADER_1 == exe_header+160h.
	jb short .j_loaderror
      %if SPEDOSONLY==2
	or byte [si-spefofs.pmodew_config+spefofs.pehdr_fofs_ptr], 1
	cmp dword [si-spefofs.pmodew_config+spefofs.pehdr_fofs_ptr], 41h
	jne short .j_loaderror
      %else
        %if SPEDOSONLY
	cmp dword [si-spefofs.pmodew_config+spefofs.pehdr_fofs_ptr], 41h
        %else
	cmp dword [si-spefofs.pmodew_config+spefofs.pehdr_fofs_ptr], 40h
        %endif
	jne short .j_loaderror
	or byte [si-spefofs.pmodew_config+spefofs.pehdr_fofs_ptr], 1
      %endif
	cmp dword [si-spefofs.pmodew_config+spefofs.pehdr.Signature], 'PE'
	jne short .j_loaderror
	cmp dword [si-spefofs.pmodew_config+spefofs.pehdr.SizeOfHeaders], 200h
	jne short .j_loaderror
    %endif
	cmp dword [si-spefofs.pmodew_config+spefofs.pehdr.NumberOfRvaAndSizes], 16
	jne short .j_loaderror
	mov cx,   [si-spefofs.pmodew_config+spefofs.pehdr.NumberOfSections]  ; dw.
	jcxz .j_loaderror
	cmp cx, 5
	ja short .j_loaderror
  %endif  ; %else LOADSPE==2
  %if CONFIGTYPE!=2
	push es  ; Save.
  %endif
%elif CONFIGTYPE==3
	mov cx, 200h  ; Must be at least 3ch, _loadexe uses dword [3ch] for the LE/PMW1 offset. Must be at most DTABUFSIZE == 200h.
	mov ds, [-pmodewe+_int21lowdtaseg]
	_xor dx, dx
	mov ah, 3fh  ; Read from file using handle.
	int 21h
	jc _loaderror
	mov dx, [8]  ; DX := hdrsize. Typical value created by OpenWatcom: 0bh (relocations between 40h and 0b0h, pmodew_config ends at 0b0h+21).
	_mov si, dx
	shl si, 4  ; Maximum .hdrsize supported: 0fffh.
	cmp dx, (200h-pmodew_config._size)>>4
	jbe .after_read_config  ; The default hdrsize created by TLINK is 20h, with SI == DX == 200h here. But when OpenWatcom embeds it as a stub, the hdrsize becomes 0dh, which is small, thus we don't (have to) seek or read.
.seek_for_config:
	_xor cx, cx  ; High word of file offset.
	shld cx, dx, 4
	_mov dx, si  ; CX:DX := hdrsize<<4.
	mov ax, 4200h  ; Move file pointer using handle. whence (AL) := SEEK_SET (== 0).
	int 21h
	jc _loaderror
.read_config_from_good_file_position:
	mov cx, pmodew_config._size  ; 15h == 21. Must be at most 3ch, _loadexe uses dword [gs:3ch] ([3ch] here) for the file offset of the 32-bit payload (LE or PMW1).
	_xor dx, dx
	mov ah, 3fh  ; Read from file using handle.
	int 21h
	jc _loaderror
	_xor si,si
.after_read_config:  ; Now: DS:SI points to the config (pmodew_config structure) read from the .EXE file.
	push es
%else
%if CONFIGTYPE>1  ; This makes sense. It supports 2 <= hdrsize <= 0x1e == 30.
	mov cx,200h  ; Must be at least 3ch, _loadexe uses dword [3ch] for the LE/PMW1 offset. Must be at most DTABUFSIZE == 200h.
%else  ; This is for bytewise identical original pmodew.exe. It supports 2 <= hdrsize <= 4.
	mov cx,40h+pmodew_config._size  ; pmodew_config._size == 15h == 21. Must be >=pmodew_config._size+(hdrsize>>4).
%endif
	mov ds,[-pmodewe+_int21lowdtaseg]
	_xor dx,dx
	mov ah,3fh  ; Read from file using handle.
	int 21h
	jc _loaderror
	push es
	mov si,[8]  ; SI := hdrsize. Typical values for compress PMODE/W pmodew.exe: hdrsize == 2 (pmodew.exe) or == 4 (when pmodew.exe embedded by WLINK as stub).
%if CONFIGTYPE>1  ; This makes sense. It supports 2 <= hdrsize <= 0x1e == 30.
	cmp si,(200h-pmodew_config._size)>>4
	ja _loaderror
%else  ; This is for bytewise identical original pmodew.exe. It carelessly omits the check for hdrsize <= 4.
%endif
	shl si,4
%endif
	reloc mov ax,PMODE_TEXT
	mov es,ax
	mov di,-pmodewk+_pm_config_except_for_lowmin
	mov cx,_pm_config_except_for_lowmin.end-_pm_config_except_for_lowmin  ; 13h == 19.
	rep movsb  ; Copy from pmodew_config to _pm_config_except_for_lowmin.
	lodsw
	multipop es, ds
	mov [-pmodewe+_pm16_lowmin],ax
	ret
%endif

%if VARTYPE==2  ; Uses the hardcoded default values (PM_*) for the _pm_config_except_for_lowmin and _pm16_lowmin. Also loads the file offset of the 32-bit payload from dword at file offset 3ch.
_openexe2_vartype_2:
_openexe2:
	; Input: DS == pmode16, corresponding to pmodewe.
	mov [-pmodewe+_exehandle],ax
	mov word [-pmodewe+_pm16_lowmin],PM_LOWMIN
	push ds
	_mov bx,ax
	mov cx,3ch+4  ; _loadexe uses dword [gs:3ch] (loaded to dword [3ch] here) for the file offset of the 32-bit payload (LE or PMW1).
	mov ds,[-pmodewe+_int21lowdtaseg]
	_xor dx,dx
	mov ah,3fh
	int 21h
	jc _loaderror
	reloc mov ax,PMODE_TEXT  ; PMODE_TEXT corresponds to pmodewk. This reloc is is present %if VARTYPE==2.
	mov ds,ax
	; TODO(pts): With -DUNC, copy from pmodew_config, also PM_LOWMIN above. This would break `./compile.sh --reproducible' (default) pmodewv.exe.
	; Populates _pm_config_except_for_lowmin using hardcoded default values.
	mov word [-pmodewk+_pm_pmstacklen],PM_PMSTACKLEN
	mov word [-pmodewk+_pm_rmstacklen],PM_RMSTACKLEN
	mov byte [-pmodewk+_pm_pmstacks],PM_PMSTACKS
	mov byte [-pmodewk+_pm_rmstacks],PM_RMSTACKS
	mov byte [-pmodewk+_pm_mode],PM_MODE
	mov word [-pmodewk+_pm_selectors],PM_SELECTORS
	mov byte [-pmodewk+_pm_callbacks],PM_CALLBACKS
	mov byte [-pmodewk+_pm_pagetables],PM_PAGETABLES
	mov dword [-pmodewk+_pm_maxextmem],PM_MAXEXTMEM
	mov byte [-pmodewk+_pm_pampagemax],PM_PAMPAGEMAX
	mov byte [-pmodewk+_pm_options],PM_OPTIONS
	pop ds
	ret
%endif

stack equ $+(($$-$)&0xf)
pmstack equ (stack-exe_image)>>4  ; pmstack segment para stack use16 'STACK'
stack_end equ stack+STACKSIZE

; --- Trailer.

exe_end:
mem_end equ stack_end
finalize_relocs
%if UNC && LOADSPE
  times (exe_header-$)&(200h-1) db 0  ; inpe.FileAlignment == 200h.
  SPE_sections:
  SPE_sections_va equ SPE_ImageBase+0x1000
  %ifdef SPE_EntryPoint
    cpu 386
    bits 32
    org SPE_sections_va-($-exe_header)  ; It's OK to set `org' even this late, after lots of assembly instructions in pmodew.nasm.
    %macro spe_pic_delta_to 1  ; %1 is an 32-bit register, typically EBP. It doesn't modify EFLAGS.
      call %%here
      %%here: pop %1  ; EBP := linear address to where .here has been loaded.
      lea %1, [%1-(SPE_sections_va+%%here-SPE_sections)]  ; EBP := linear address delta, for manual relocations. !! Add PE relocations, generate them.
    %endm
    %macro spe_bss 0  ; Mark the start of zero-initialized data (BSS). From now on, use resb etc. instructions.
      SPE_end:
      absolute $
      resb (SPE_sections-$)&3  ; Align to dword boundary.
      %define SPE_bss SPE_bss
      SPE_bss:
    %endm
    %macro spe_end 0  ; Put it at the end of your .nasm source file.
      %ifndef SPE_bss
        %define SPE_bss SPE_bss
        SPE_end:  ; End of initialized code and data. BSS starts after this.
        SPE_bss:  ; No need for alignment, because BSS is empty.
      %endif
      %if $-SPE_bss==0
        SPE_bssend: equ SPE_end
      %else
        SPE_bssend: equ $
      %endif
    %endm
  %endif
%endif

; __END__
