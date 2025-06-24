;
; flexpe.nasm: flexible Win32 PE .exe generation library for NASM 0.98.39--
; by pts@fazekas.hu at Tue Jun 24 04:06:40 CEST 2025
;
; Features:
;
; * Only a single run of NASM is required, which generates the final .exe.
;   (It uses the default binary output format: `nasm -f bin`.)
;   There is no special linking step.
; * Sections TEXT and BSS can touch each other without any bytes in-between.
;   This is useful for a user-defined data structure starting at the end of
;   TEXT and continuing at the beginning of BSS.
; * The generated Win32 .exe program file is compatible with a wide variety
;   of Windows versions and emulators: Windows NT 3.1--Windows 95--Windows
;   XP--Windows 11, ReactOS 0.4.14--, Wine 1.6.1--5.0, WDOSX DOS extender,
;   HX DOS extender.
; * It supports generating relocations. (This is needed by Win32s and
;   WDOSX.)
; * It works with any NASM `org' value, and it doesn't define any section.
;   (It does `absolute $` though between TEXT and BSS.)
; * The DOS stub at the beginning of the file is fully customizable and
;   replaceable, and it can have any size.
; * It allows overlapping the data between the DOS stub and the PE program.
;
; Limitations:
;
; * Sections .text, .rdata and .data (and also .idata and .reloc) are merged
;    to a single section TEXT (which is read-write and executable). BSS
;    (zero-initialized, read-write data) is a separate section.
; * Relocations must be indicated manually with the pe_r0, pe_r1 (etc.)
;   instruction prefixes.
; * All relocations must be put to the first 0xfff bytes of the section TEXT.
; * Only kernel32.dll is supported for function importing. You can work this
;   around by calling __imp_GetModuleHandle@4 and __imp_GetProcAddress@8.
; * Only Win32 console applications are supported, no GUI.
; * Some (unfortunately quite many) antivirus software mistakenly identifies
;   the generated .exe as malware.
;
; Compilation command: nasm -O0 -w+orphan-labels -o prog.exe prog.nasm
;
; Example program which justs exits with code 42:
;
;   %include 'flexpe.nasm'
;   pe_start_text _start
;   pe_kimport __imp__ExitProcess@4, 'ExitProcess'
;   _start:         push byte 42  ; Exit code.
;                   pe_kcall __imp__ExitProcess@4  ; It doesn't return.
;   pe_end
;
; Example hello-world program:
;
;   %include 'flexpe.nasm'
;   pe_start_text _start
;   pe_kimport __imp__GetStdHandle@4, 'GetStdHandle'
;   pe_kimport __imp__WriteFile@20, 'WriteFile'
;   pe_kimport __imp__ExitProcess@4, 'ExitProcess'
;   _start:         push byte -11  ; STD_OUTPUT_HANDLE.
;                   pe_kcall __imp__GetStdHandle@4
;                   push eax  ; Value is arbitrary, we allocate an output variable on the stack.
;                   mov ebx, esp
;                   push byte 0  ; Argument 5: lpOverlapped = 0.
;                   push ebx  ; Argument 4: Address of the output variable.
;                   push byte R_message.end-R_message  ; Argument 3: message size.
;                   pe_r0 push VADDR_TEXT(message)  ; Argument 2: message.
;                   push eax  ; Argument 1: stdout handle.
;                   pe_kcall __imp__WriteFile@20
;                   push byte 0  ; EXIT_SUCCESS == 0.
;                   pe_kcall __imp__ExitProcess@4  ; It doesn't return.
;   R_message:      db 'Hello, World!', 13, 10
;   .end:
;   pe_end
;
; !!! Test it on Windows 11.
; !!! Test it on Windows 95 (both) without the extra `dd 0' in IMAGE_IMPORT_DESCRIPTOR_3.
;
; Operating system and emulator compatibility:
;
; * WDOSX: it works.
; * HX DOS extender (dpmild32.exe 3.7.0 in HXRT 2.16): it works.
; * Win32s: it doesn't work, because Win32s supports only Win32 GUI applications.
;

%macro pe_stub 0  ; Creates a minimal (64-byte) DOS .exe stub for the PE which just fails with an error message when run from DOS.
  FILE_HEADER:
  IMAGE_DOS_HEADER:  ; DOS .exe header: http://justsolve.archiveteam.org/wiki/MS-DOS_EXE
  ; Based on https://github.com/pts/mininasm/blob/master/demo/hello/helloe.nasm
  .signature:	db 'MZ'
  .lastsize:	dw (.end-.signature)&0x1ff  ; The value 0 and 0x200 are equivalent here. Microsoft Linker 3.05 generates 0, so do we. Number of bytes in the last 0x200-byte block in the .exe file.
  .nblocks:	dw (.end-.signature+0x1ff)>>9  ; Number of 0x200-byte blocks in .exe file (rounded up).
  .nreloc	dw 0  ; No DOS relocations.
  .hdrsize	dw 0  ; Load .exe file to memory from the beginning.
  .code:
  %if 0  ; Produces identical .exe output even if we change it to 0.
    ;bits 16
    .minalloc:	db 0xb8, 3, 9  ; mov ax, 0x903  ; AH := 9, AL := junk. The number 3 matters for minalloc, see below. TODO(pts): Decrease 3 to 1 if nblocks == 2, decrease it to 0 if nblocks >= 3.
    .ss_minu_1:	db 0xba, 9, 1  ; mov dx, message+(0x100-$$)  ; (0x100-$$) to make it work with any `org'.
    .sp:	int 0x21  ; Print the message to stdout. https://stanislavs.org/helppc/int_21-9.html
    .checksum:	int 0x20  ; Exit. Requires CS == PSP. https://stanislavs.org/helppc/int_20.html
  %else
    .minalloc:	dw 0x03b8  ; To have enough room for the stack, we need minalloc >= ss+((sp+0xf)>>4)-0x20 == 0x315. kvikdos verifies it.
    .maxalloc:	dw 0xba09  ; Actual value doesn't matter.
    .ss:	dw 0x0118  ; Actual value doesn't matter as long as it matches minalloc. dw message
    .sp:	dw 0x21cd  ; Actual value doesn't matter. int 0x21
    .checksum:	dw 0x20cd  ; Actual value doesn't matter. int 0x20
  %endif
    .ip:	dw .code+(0x100-$$)  ; Entry point offset. (0x100-$$) to make it work with any `org'.
    .cs:	dw 0xfff0  ; CS := PSP upon entry.
  %if 0
    .relocpos:	dw ?  ; Doesn't matter, overlaps with 2 bytes of message: 'He'.
    .noverlay:	dw ?  ; Doesn't matter. overlaps with 2 bytes of message: 'll'.
    ; End of 0x1c-byte .exe header.
  %endif
  .message:	db 'This is a Win32 console program.', 13, 10, '$'
  .end:
  times 0x3c-($-FILE_HEADER) db 0  ; Fails to compile if the message is too long.
  dd IMAGE_NT_HEADERS-FILE_HEADER  ; Windows uses this dword pointer at file offset 0x3c to find the PE header.
  %define FILE_HEADER FILE_HEADER  ; Indicate to pe_header that the DOS .exe stub has been created.
%endm

%macro pe_set 2  ; Example: pe_set SizeOfStackReserve, 64<<10
  %ifndef __pe_%1  ; If defined, it's defined to itself.
    __pe_%1 equ %2
    %define __pe_%1 __pe_%1
  %endif
%endm

%macro pe_header 1  ; %1: entry point (_start) label.
  %ifndef FILE_HEADER
    pe_stub
  %endif
  bits 32
  ;PE_TEXT_FOFS equ 0x200  ; Will be defined later in pe_start_text for more flexibility. Must be positive and divisble by 0x200.
  ;PE_RVA_TEXT_0 equ 0x1000  ; Will be defined later in pe_start_text for more flexibility. Must be positive and divisble by 0x1000.
  ;PE_IMAGE_BASE equ 0x400000  ; Will be defined later in pe_start_text for more flexibility. Minimum value for efficient Windows 95: 0x400000. Must be positive and divisible by 0x1000.

  ; We don't add parens to the macro body, so that VADDR_TEXT(foo).bar works.
  %define VADDR_TEXT(name) (-SECTION_TEXT+PE_IMAGE_BASE+PE_RVA_TEXT_0)+R_ %+ name  ; May be called only in relocated instructions (i.e. lines starting with macros pe_r0, pe_r1 etc.).
  %define RVA_TEXT(addr) ((addr)-SECTION_TEXT+PE_RVA_TEXT_0)  ; Works for everything in the TEXT section.

  times (FILE_HEADER-$)&3 db 0  ; Align to a multiple of 4.
  IMAGE_NT_HEADERS:
  db 'PE', 0, 0

  IMAGE_FILE_HEADER:
  Machine: dw 0x14c  ; IMAGE_FILE_MACHINE_I386.
  NumberOfSections: dw (IMAGE_SECTION_HEADER_end-IMAGE_SECTION_HEADER)/40
  TimeDateStamp: dd 0
  PointerToSymbolTable: dd 0
  NumberOfSymbols: dd 0
  SizeOfOptionalHeader: dw IMAGE_OPTIONAL_HEADER32_end-IMAGE_OPTIONAL_HEADER32
  IMAGE_FILE_RELOCS_STRIPPED equ 1
  IMAGE_FILE_EXECUTABLE_IMAGE equ 2
  IMAGE_FILE_LINE_NUMS_STRIPPED equ 4
  IMAGE_FILE_LOCAL_SYMS_STRIPPED equ 8
  IMAGE_FILE_BYTES_REVERSED_LO equ 0x80  ; Deprecated, shouldn't be specified.
  IMAGE_FILE_32BIT_MACHINE equ 0x100
  IMAGE_FILE_DEBUG_STRIPPED equ 0x200
  IMAGE_FILE_DLL equ 0x2000  ; Shouldn't be specified for .exe.
  Characteristics: dw IMAGE_FILE_EXECUTABLE_IMAGE|IMAGE_FILE_LINE_NUMS_STRIPPED|IMAGE_FILE_LOCAL_SYMS_STRIPPED|IMAGE_FILE_32BIT_MACHINE|IMAGE_FILE_DEBUG_STRIPPED|IMAGE_FILE_BYTES_REVERSED_LO  ; Doesn't have IMAGE_FILE_RELOCS_STRIPPED.

  IMAGE_OPTIONAL_HEADER32:
  Magic: dw 0x10b  ; IMAGE_NT_OPTIONAL_HDR32_MAGIC.
  MajorLinkerVersion: db 6
  MinorLinkerVersion: db 0
  SizeOfCode: dd 0x00000000
  SizeOfInitializedData: dd 0x00000000
  SizeOfUninitializedData: dd 0x00000000
  AddressOfEntryPoint: dd RVA_TEXT(%1)  ; Also called starting address.
  BaseOfCode: dd PE_RVA_TEXT_0
  BaseOfData: dd PE_RVA_TEXT_0
  ImageBase: dd PE_IMAGE_BASE
  SectionAlignment: dd 0x1000  ; Single allowed value for Windows XP.
  FileAlignment: dd 0x200  ; Minimum value for Windows NT 3.1.
  MajorOperatingSystemVersion: dw 4
  MinorOperatingSystemVersion: dw 0
  MajorImageVersion: dw 0
  MinorImageVersion: dw 0
  MajorSubsystemVersion: dw 3   ; Windows NT 3.1.
  MinorSubsystemVersion: dw 10  ; Windows NT 3.1.
  Win32VersionValue: dd 0
  SizeOfImage: dd PE_RVA_TEXT_0+(SECTION_TEXT_end-SECTION_TEXT)+(SECTION_BSS_end-SECTION_BSS)
  SizeOfHeaders: dd IMAGE_NT_HEADERS_end-FILE_HEADER
  CheckSum: dd 0
  Subsystem: dw 3  ; IMAGE_SUBSYSTEM_WINDOWS_CUI; gcc -mconsole
  DllCharacteristics: dw 0
  SizeOfStackReserve: dd __pe_SizeOfStackReserve  ; Configurable with `pe_set SizeOfStackReserve, ...'.
  SizeOfStackCommit: dd __pe_SizeOfStackCommit  ; Configurable with `pe_set SizeOfStackCommit, ...'.
  SizeOfHeapReserve: dd __pe_SizeOfHeapReserve  ; Configurable with `pe_set SizeOfHeapReserve, ...'.
  SizeOfHeapCommit: dd __pe_SizeOfHeapCommit  ; Configurable with `pe_set SizeOfHeapCommit, ...'.
  LoaderFlags: dd 0
  NumberOfRvaAndSizes: dd (IMAGE_DATA_DIRECTORY_end-IMAGE_DATA_DIRECTORY)/8
  IMAGE_DATA_DIRECTORY:
  IMAGE_DIRECTORY_ENTRY_EXPORT:  ; 0.
  .VirtualAddress: dd 0
  .Size: dd 0
  IMAGE_DIRECTORY_ENTRY_IMPORT:  ; 1. Import directory.
  .VirtualAddress: dd RVA_TEXT(IMAGE_IMPORT_DESCRIPTORS)
  .Size: dd IMAGE_IMPORT_DESCRIPTORS_end-IMAGE_IMPORT_DESCRIPTORS
  IMAGE_DIRECTORY_ENTRY_RESOURCE:  ; 2.
  .VirtualAddress: dd 0
  .Size: dd 0
  IMAGE_DIRECTORY_ENTRY_EXCEPTION:  ; 3.
  .VirtualAddress: dd 0
  .Size: dd 0
  IMAGE_DIRECTORY_ENTRY_SECURITY:  ; 4.
  .VirtualAddress: dd 0
  .Size: dd 0
  IMAGE_DIRECTORY_ENTRY_BASERELOC:  ; 5. Base relocation directory.
  .VirtualAddress: dd RVA_TEXT(RELOC_BLOCKS)
  .Size: dd RELOC_BLOCKS_end-RELOC_BLOCKS
  IMAGE_DIRECTORY_ENTRY_DEBUG:  ; 6.
  .VirtualAddress: dd 0
  .Size: dd 0
  IMAGE_DIRECTORY_ENTRY_ARCHITECTURE:  ; 7.
  .VirtualAddress: dd 0
  .Size: dd 0
  IMAGE_DIRECTORY_ENTRY_GLOBALPTR:  ; 8.
  .VirtualAddress: dd 0
  .Size: dd 0
  IMAGE_DIRECTORY_ENTRY_TLS:  ; 9.
  .VirtualAddress: dd 0
  .Size: dd 0
  %if 0  ; !!! Either fix WDOSX (and Windows 95??) or apply to pts-tinype. Minimum for WDOSX to prevent crashes. move? Windows XP needs >=7 if relocations are present. Windows 95, Windows NT 3.1, Windows NT 4.0 and WDOSX need >=6 (the minimum for IMAGE_DIRECTORY_ENTRY_BASERELOC).
  IMAGE_DIRECTORY_ENTRY_LOAD_CONFIG:  ; 10.
  .VirtualAddress: dd 0
  .Size: dd 0
  IMAGE_DIRECTORY_ENTRY_BOUND_IMPORT:  ; 11.
  .VirtualAddress: dd 0
  .Size: dd 0
  IMAGE_DIRECTORY_ENTRY_IAT:  ; 12. Import address table. Omitted by OpenWatcom wlink(1).
  .VirtualAddress: dd RVA_TEXT(IMPORT_ADDRESS_TABLE)
  .Size: dd IMPORT_ADDRESS_TABLE_end-IMPORT_ADDRESS_TABLE
  ; These entries are not needed.
  IMAGE_DIRECTORY_ENTRY_DELAY_IMPORT:  ; 13.
  .VirtualAddress: dd 0
  .Size: dd 0
  IMAGE_DIRECTORY_ENTRY_COM_DESCRIPTOR:  ; 14. Nonzero for .NET .exe.
  .VirtualAddress: dd 0
  .Size: dd 0
  IMAGE_DIRECTORY_ENTRY_RESERVED:  ; 15.
  .VirtualAddress: dd 0
  .Size: dd 0
  %endif
  IMAGE_DATA_DIRECTORY_end:
  IMAGE_OPTIONAL_HEADER32_end:

  IMAGE_SECTION_HEADER:
  IMAGE_SECTION_HEADER__0:
  .Name: db '.text'
  times ($$-$)&7 db 0
  .VirtualSize: dd (SECTION_TEXT_end-SECTION_TEXT)+(SECTION_BSS_end-SECTION_BSS)
  .VirtualAddress: dd PE_RVA_TEXT_0
  .SizeOfRawData: dd SECTION_TEXT_end-SECTION_TEXT  ; Byte size in file. Windows NT 3.1 fails if this is larger than the actual file.
  .PointerToRawData: dd SECTION_TEXT-FILE_HEADER
  .PointerToRelocations: dd 0
  .PointerToLineNumbers: dd 0
  .NumberOfRelocations: dw 0
  .NumberOfLineNumbers: dw 0
  IMAGE_SCN_CNT_CODE equ 0x20
  IMAGE_SCN_MEM_EXECUTE equ 0x20000000
  IMAGE_SCN_MEM_READ equ 0x40000000
  IMAGE_SCN_CNT_INITIALIZED_DATA equ 0x40
  IMAGE_SCN_MEM_WRITE equ 0x80000000
  .Characteristics: dd IMAGE_SCN_CNT_CODE|IMAGE_SCN_MEM_EXECUTE|IMAGE_SCN_MEM_READ|IMAGE_SCN_CNT_INITIALIZED_DATA|IMAGE_SCN_MEM_WRITE
  IMAGE_SECTION_HEADER_end:

  IMAGE_NT_HEADERS_end:
  %define IMAGE_NT_HEADERS IMAGE_NT_HEADERS  ; Indicate to pe_start_text that IMAGE_NT_HEADERS has been emitted.
%endm

%macro pe_set_sizes 0
  %ifndef PE_RVA_TEXT_0
    PE_RVA_TEXT_0 equ 0x1000  ; Must be divisble by 0x1000.
    %define PE_RVA_TEXT_0 PE_RVA_TEXT_0
  %endif
  %if PE_RVA_TEXT_0<=0
    %error ERROR_PE_RVA_TEXT_0_MUST_BE_POSITIVE
    db 1/0
  %endif
  %if PE_RVA_TEXT_0&0xfff
    %error ERROR_RVA_TEXT_MUST_BE_PAGE_ALIGNED
    db 1/0
  %endif
  %ifndef PE_TEXT_FOFS
    %if $-FILE_HEADER<=0
      %error ERROR_FILE_HEADER_MUST_HAVE_BEEN_EMITTED_BY_PE_HEADER
      db 1/0
    %elif $-FILE_HEADER<=0x200  ; Round up.
      PE_TEXT_FOFS equ ($-FILE_HEADER+0x1ff)&~0x1ff  ; Must be divisble by 0x200. Round up.
    %else  ; Round down.
      PE_TEXT_FOFS equ ($-FILE_HEADER)&~0x1ff  ; Must be divisble by 0x200. Round down.
    %endif
    %define PE_TEXT_FOFS PE_TEXT_FOFS
  %endif
  %if PE_TEXT_FOFS<=0
    %error ERROR_PE_TEXT_FOFS_MUST_BE_POSITIVE
    db 1/0
  %endif
  %if PE_TEXT_FOFS&0x1ff
    %error ERROR_RVA_TEXT_MUST_BE_0x200_ALIGNED
    db 1/0
  %endif
  %if 0 && IMAGE_NT_HEADERS_end-FILE_HEADER>=0x800  ; Maximum for Win32s is 2048 bytes. We don't enforce it since Win32s can't run console programs anyway.
    %error ERROR_PE_HEADER_TOO_LONG_FOR_WIN32S
    db 1/0
  %endif
  %if IMAGE_NT_HEADERS_end-FILE_HEADER>PE_RVA_TEXT_0  ; Windows NT 3.51 and Windows XP (and possibly others, but not Wine 5.0) require it.
    %error ERROR_PE_HEADER_ENDS_AFTER_FIRST_SECTION_STARTS
    db 1/0
  %endif
%endm

%macro pe_start_text 0  ; For users who have already called pe_header.
  pe_start_text __PE_ENTRY_DEFINED_ELSEWERE__
%endm
%macro pe_start_text 1  ; %1: entry point (_start) label.
  %ifndef IMAGE_NT_HEADERS
    pe_header %1
  %endif
  pe_set_sizes  ; Sets PE_TEXT_FOFS, PE_RVA_TEXT_0.
  %if $-FILE_HEADER<PE_TEXT_FOFS
    times PE_TEXT_FOFS-($-FILE_HEADER) db 0
    SECTION_TEXT: equ $  ; `equ $' for symmetry with the %else branch.
  %else
    SECTION_TEXT: equ FILE_HEADER+PE_TEXT_FOFS
  %endif
  %define __reloc_count 0
  %define __kimport_count 0
%endm  ; pe_start_text.

%macro __remember_reloc 2  ; Internal helper. %1 is the unsigned integer value of __reloc_count. %2 is an address within section TEXT.
  __reloc_%1 equ %2
  %if (__reloc_%1-SECTION_TEXT)>0xfff
    %error ERROR_RELOC_VALUE_TOO_LARGE  ; Solution: move all relocations to the first 4 KiB within section TEXT.
    times -1 db 0
  %endif
  %assign __reloc_count __reloc_count+1
%endm
%macro pe_r0 1+  ; Indicates that there is a dword-sized relocation at the end of %1.
  %1
  __remember_reloc __reloc_count, $-4
%endm
%macro pe_r1 1+  ; Indicates that there is a dword-sized relocation 1 byte before the end of %1.
  %1
  __remember_reloc __reloc_count, $-4-1
%endm

%macro __kimport_low 3  ; Internal helper. %1 is the unsigned integer value of __kimport_count. %2 is the import label such as __imp__ExitProcess@4. %3 is the DLL function name string such as 'ExitProcess'.
  %define __kimport_label_%1 %2
  %define __kimport_namestr_%1 %3
  %assign __kimport_count __kimport_count+1
%endm
; Declares import from kernel32.dll.
;
; %1 is the import label such as __imp__ExitProcess@4. %2 is the DLL
; %function name string such as 'ExitProcess'.
;
; Example: pe_kimport __imp__ExitProcess@4, 'ExitProcess'
;
; Example call of imported function (6 bytes): pe_r0 call [VADDR_TEXT(__imp__ExitProcess@4]).
%macro pe_kimport 2
  __kimport_low __kimport_count, %1, %2
%endm

%macro __emit_kimport_namestr 1  ; Internal helper. %1 is the unsigned integer value of __kimporti.
  __kimport_nlabel_%1: db 0, 0, __kimport_namestr_%1, 0  ; The first `db 0, 0' is the hint value.
  %assign __kimporti __kimporti+1
%endm
%macro __emit_reloc 1  ; Internal helper. %1 is the unsigned integer value of __reloci.
  dw __reloc_%1-SECTION_TEXT+BASERELOC_HIGHLOW
  %assign __reloci __reloci+1
%endm

%macro __emit_kimport_label 2  ; Internal helper. %1 is the unsigned integer value of __kimporti. %2 is the label value, i.e. body of macro __kimport_label_%1.
  R_%2: dd RVA_TEXT(__kimport_nlabel_%1)
  %assign __kimporti __kimporti+1
%endm
%macro __emit_kimport_label 1  ; Internal helper. %1 is the unsigned integer value of __kimporti.
  __emit_kimport_label %1, __kimport_label_%1
%endm

; Must be called 0 or 1 time, between pe_start_text and pe_bss. Typically called right before pe_bss.
%macro pe_structures 0
  %ifdef __kimporti
    %error ERROR_PE_STRUCTURES_CALLED_MULTIPLE_TIMES
    db 1/0
  %endif
  __kimport_dllname: db 'kernel32.dll', 0
  %define __kimporti 0
  %rep __kimport_count
    __emit_kimport_namestr __kimporti
  %endrep

  times (FILE_HEADER-$)&3 db 0  ; Align to a multiple of 4. Is it needed by RELOC_BLOCKS or IMPORT_ADDRESS_TABLE?
  ; Without these relocation blocks, Win32s wouldn't be able to run the .exe.
  ; They are ignored by Wine, Windows NT, Windows 95 and Windows XP+.
  RELOC_BLOCKS:  ; https://learn.microsoft.com/en-us/windows/win32/debug/pe-format#the-reloc-section-image-only
  RELOC_BLOCK__0:  ; Each block must start on a 32-bit boundary.
  dd PE_RVA_TEXT_0  ; dd 0x1000  ; !! Use a larger base? What is the alignment?
  dd RELOC_BLOCK__0_end-RELOC_BLOCK__0      ; dd 0x10
  .relocs:
  BASERELOC_HIGHLOW equ 0x3000  ; IMAGE_REL_BASED_HIGHLOW (== 3) << 12. The lower 12 bits contain the actual offset where to apply the relocation.

  %define __reloci 0
  %rep __reloc_count
    __emit_reloc __reloci
  %endrep
  %if ($-.relocs)&2  ; !! Is this padding really needed? Which Windows version breaks without it?
    dw 0  ; Padding to even number of relocs. IMAGE_REL_BASED_ABSOLUTE to pad a block.
  %endif
  RELOC_BLOCK__0_end:
  RELOC_BLOCKS_end:

  ; Because of the modification, this must start after section TEXT.
  IMPORT_ADDRESS_TABLE:  ; Import address table. Modified by the PE loader before jumping to _entry.
  %define __kimporti 0
  %rep __kimport_count
    __emit_kimport_label __kimporti
  %endrep
  dd 0  ; Terminator needed after the function pointers in IMPORT_ADDRESS_TABLE by Windows 95, Windows NT 3.1, Windows NT 4.0, Windows XP, WDOSX and possibly others. Wine 5.0 doesn't need it.
  IMPORT_ADDRESS_TABLE_end:

  ; Windows 95 requires this to be part of a section; Windows NT 3.1 and
  ; Windows XP work if this is in the header.
  IMAGE_IMPORT_DESCRIPTORS:
  IMAGE_IMPORT_DESCRIPTOR_0:
  .OriginalFirstThunk: dd RVA_TEXT(IMPORT_ADDRESS_TABLE)
  .TimeDateStamp: dd 0
  .ForwarderChain: dd 0
  .Name: dd RVA_TEXT(__kimport_dllname)
  .FirstThunk: dd RVA_TEXT(IMPORT_ADDRESS_TABLE)
  IMAGE_IMPORT_DESCRIPTOR_1:  ; Last Import directory table, marks end-of-list.
  dd 0, 0, 0, 0, 0  ; Same fields as above, filled with 0s.
  IMAGE_IMPORT_DESCRIPTORS_end:
  IMAGE_IMPORT_DESCRIPTOR_2:
  dd 0, 0, 0, 0, 0  ; Same fields as above, filled with 0s. For Windows 95 4.00.950 C HeapAlloc(...) compatibility.
  IMAGE_IMPORT_DESCRIPTOR_3:
  dd 0, 0, 0, 0, 0  ; Same fields as above, filled with 0s. For Windows 95 4.00.950 C after-boot compatibility.
  dd 0  ; !!! Why this extra? Does Windows 95 need it? Test it again without it.
  %define pe_structures pe_structures  ; Indicate to pe_bss that pe_structures has been called.
%endm

%macro pe_bss 1  ; %1: Alignment, as a power of 2.
  %ifndef pe_structures  ; If not called yet, call it.
    pe_structures
  %endif
  SECTION_TEXT_end:
  absolute $  ; Don't emit bytes anymore, just reserve.
  resb (SECTION_TEXT-$)&((%1)-1)  ; Align it.
  SECTION_BSS:
  %define pe_bss pe_bss  ; Indicate to pe_end that pe_bss has been called.
%endm
%macro pe_bss 0
  pe_bss 4
%endm

%macro pe_end 0
  %ifndef pe_bss  ; If not called yet, call it.
    pe_bss 1
  %endif
  SECTION_BSS_end:
  %ifndef __pe_SizeOfStackReserve
    pe_set SizeOfStackReserve, 1<<20  ; 0x00100000.
  %endif
  %ifndef __pe_SizeOfStackCommit
    pe_set SizeOfStackCommit, 4<<10  ; 0x00001000.
  %endif
  %ifndef __pe_SizeOfHeapReserve
    pe_set SizeOfHeapReserve, 1<<20  ; 0x100000.
  %endif
  %ifndef __pe_SizeOfHeapCommit
    pe_set SizeOfHeapCommit, 4<<10  ; 0x1000.
  %endif
  %if __reloc_count!=__reloci
    %error ERROR_RELOC_FOUND_TOO_LATE
    db 1/0
  %endif
  %if __kimport_count!=__kimporti
    %error ERROR_KIMPORT_FOUND_TOO_LATE
    db 1/0
  %endif
  %ifndef PE_IMAGE_BASE  ; No need to define any earlier. This is to discourage users from using it in an `%if'. The proper usage is only in IMAGE_OPTIONAL_HEADER32.ImageBase pe_header.
    PE_IMAGE_BASE equ 0x400000  ; Minimum value for efficient Windows 95: 0x400000. Must be positive and divisible by 0x1000.
    %define PE_IMAGE_BASE PE_IMAGE_BASE
  %endif
  %if PE_IMAGE_BASE<=0
    %error ERROR_PE_IMAGE_BASE_MUST_BE_POSITIVE
    db 1/0
  %endif
  %if PE_IMAGE_BASE&0xfff
    %error ERROR_PE_IMAGE_BASE_MUST_BE_PAGE_ALIGNED
    db 1/0
  %endif
%endm

%macro pe_kcall 1  ; %1 is the label of an function imported by pe_kimport, e.g. __imp__ExitProcess@4.
  pe_r0 call dword [VADDR_TEXT(%1)]
%endm

; __END__
