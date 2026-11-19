;
; win32imp.nasm: poor man's way of building library file win32imp.lib
; by pts@fazekas.hu at Thu Nov 19 01:58:12 CET 2026
;
; Compile with:  -O0 -w+orphan-labels -f bin -o win32imp.lib win32imp.nasm
; Minimum NASM version needed: 0.98.39
;

%define FAKE_TIMESTAMP '1           '

%macro ddbe 1  ; Like `dd %1', but big-endian.
  db ((%1)>>24)&255, ((%1)>>16)&255, ((%1)>>8)&255, (%1)&255
%endm

%macro dec10 1  ; Emits %1 as 10 decimal bytes.
  ; This is s different rendering to what GNU ar(1) or wlib create. But wlink accepts it.
  db (%1)/1000000000 % 10+'0', (%1)/100000000 % 10+'0', (%1)/10000000 % 10+'0', (%1)/1000000 % 10+'0', (%1)/100000 % 10+'0', (%1)/10000 % 10+'0', (%1)/1000 % 10+'0', (%1)/100 % 10+'0', (%1)/10 % 10+'0', (%1) % 10+'0'
%endm

%macro member 2  ; %1 is a string literal containing the member filename (up to 16 bytes), %2 is a string literal containing the object module filename
  %%name: db %1      ; 0x9C: Member filename (could be terminated by '/') (16 bytes)
  times 16-($-%%name) db ' '
  db FAKE_TIMESTAMP  ; 0xAC: Modification timestamp in decimal ASCII (12 bytes)
  db '1000  '        ; 0xB8: Owner User ID (UID = 1000) in decimal ASCII (6 bytes)
  db '1000  '        ; 0xBE: Owner Group ID (GID = 1000) in decimal ASCII (6 bytes)
  db '100664  '      ; 0xC4: File mode (0100664 = regular file, rw-rw-r--) (8 bytes)
  dec10 %%size       ; 0xCC: Data size in bytes = 241 (0xF1) in decimal ASCII (10 bytes)
  db '`', 10         ; 0xD6: Header end-of-line magic: '`\n' (2 bytes)
  incbin %2
  %%size equ ($-%%name-60)
  times (%%name-$)&1 db 0  ; Align to multiple of 2.
%endm

%define __SYMBOL_COUNT 0
%macro __define_symbol 2
  %define __SYMBOL__%1 %2
%endm
%macro __emit_symbol_name 1
  db __SYMBOL__%1, 0
%endm
%macro symbol 2  ; %1 is a member label (m_...), %2 is a string literal containg the symbol name.
  ddbe (%1)-ar
  __define_symbol __SYMBOL_COUNT, %2
  %assign __SYMBOL_COUNT __SYMBOL_COUNT+1
%endm
%macro emit_symbol_names 0
  %assign __SYMBOL_I 0
  %rep __SYMBOL_COUNT
    __emit_symbol_name __SYMBOL_I
    %assign __SYMBOL_I __SYMBOL_I+1
  %endrep
%endm

ar:
.signature: db '!<arch>', 10

m_symbol_table:  ; Respected by wlink.
db '/               ' ; 0x08: File identifier '/' = Symbol Table (16 bytes)
db FAKE_TIMESTAMP     ; 0x18: Modification timestamp in decimal ASCII (12 bytes) !!!
db '0     '           ; 0x24: Owner User ID (UID) in decimal ASCII (6 bytes)
db '0     '           ; 0x2A: Owner Group ID (GID) in decimal ASCII (6 bytes)
db '0       '         ; 0x30: File mode (0 for symbol table) in octal ASCII (8 bytes)
dec10 .size           ; 0x38: Data size in bytes = 88 (0x58) in decimal ASCII (10 bytes)
db '`', 10            ; 0x42: Header end-of-line magic.
ddbe .symbol_count
.symbol_fofss:

		symbol	_CloseHandle@4,		'_CloseHandle@4'
		symbol	_CreateFileA@28,	'_CreateFileA@28'
		symbol	_DeleteFileA@4,		'_DeleteFileA@4'
		symbol	_ExitProcess@4,		'_ExitProcess@4'
		symbol	_GetCommandLineA@0,	'_GetCommandLineA@0'
		symbol	_GetFileType@4,		'_GetFileType@4'
		symbol	_GetLastError@4,	'_GetLastError@4'
		symbol	_GetModuleFileNameA@12,	'_GetModuleFileNameA@12'
		symbol	_GetModuleHandleA@4,	'_GetModuleHandleA@4'
		symbol	_GetProcAddress@8,	'_GetProcAddress@8'
		symbol	_GetStdHandle@4,	'_GetStdHandle@4'
		symbol	_GetVersion@0,		'_GetVersion@0'
		symbol	_MoveFileA@8,		'_MoveFileA@8'
		symbol	_ReadFile@20,		'_ReadFile@20'
		symbol	_SetEndOfFile@4,	'_SetEndOfFile@4'
		symbol	_SetFilePointer@16,	'_SetFilePointer@16'
		symbol	_VirtualAlloc@16,	'_VirtualAlloc@16'
		symbol	_WriteFile@20,		'_WriteFile@20'

.symbol_count equ ($-.symbol_fofss)>>2
emit_symbol_names
.size equ $-m_symbol_table-60
times (m_symbol_table-$)&1 db 0

_CloseHandle@4:		member	'CloseHandle',		'imp_CloseHandle.obj'
_CreateFileA@28:	member	'CreateFileA',		'imp_CreateFileA.obj'
_DeleteFileA@4:		member	'DeleteFileA',		'imp_DeleteFileA.obj'
_ExitProcess@4:		member	'ExitProcess',		'imp_ExitProcess.obj'
_GetCommandLineA@0:	member	'GetCommandLineA',	'imp_GetCommandLineA.obj'
_GetFileType@4:		member	'GetFileType',		'imp_GetFileType.obj'
_GetLastError@4:	member	'GetLastError',		'imp_GetLastError.obj'
_GetModuleFileNameA@12:	member	'GetModuleFileNam',	'imp_GetModuleFileNameA.obj'
_GetModuleHandleA@4:	member	'GetModuleHandleA',	'imp_GetModuleHandleA.obj'
_GetProcAddress@8:	member	'GetProcAddress',	'imp_GetProcAddress.obj'
_GetStdHandle@4:	member	'GetStdHandle',		'imp_GetStdHandle.obj'
_GetVersion@0:		member	'GetVersion',		'imp_GetVersion.obj'
_MoveFileA@8:		member	'MoveFileA',		'imp_MoveFileA.obj'
_ReadFile@20:		member	'ReadFile',		'imp_ReadFile.obj'
_SetEndOfFile@4:	member	'SetEndOfFile',		'imp_SetEndOfFile.obj'
_SetFilePointer@16:	member	'SetFilePointer',	'imp_SetFilePointer.obj'
_VirtualAlloc@16:	member	'VirtualAlloc',		'imp_VirtualAlloc.obj'
_WriteFile@20:		member	'WriteFile',		'imp_WriteFile.obj'

; __END__
