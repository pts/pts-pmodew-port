;
; wi64.nasm: poor man's way of building library file wi64.lib
; by pts@fazekas.hu at Fri Nov 13 19:24:07 CET 2026
;
; Compile with:  -O0 -w+orphan-labels -f bin -o wi64.lib wi64.nasm
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

%macro member 1  ; %1 is a string literal containing the object module filename.
  %%name: db %1      ; 0x9C: Member filename (could be terminated by '/') (16 bytes)
  times 16-($-%%name) db ' '
  db FAKE_TIMESTAMP  ; 0xAC: Modification timestamp in decimal ASCII (12 bytes)
  db '1000  '        ; 0xB8: Owner User ID (UID = 1000) in decimal ASCII (6 bytes)
  db '1000  '        ; 0xBE: Owner Group ID (GID = 1000) in decimal ASCII (6 bytes)
  db '100664  '      ; 0xC4: File mode (0100664 = regular file, rw-rw-r--) (8 bytes)
  dec10 %%size       ; 0xCC: Data size in bytes = 241 (0xF1) in decimal ASCII (10 bytes)
  db '`', 10         ; 0xD6: Header end-of-line magic: '`\n' (2 bytes)
  incbin %1
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

		symbol m_i8d,  '__I8D'
		symbol m_i8rs, '__I8RS'
		symbol m_u8d,  '__U8D'
		symbol m_u8ls, '__I8LS'
		symbol m_u8ls, '__U8LS'
		symbol m_u8m,  '__I8M'
		symbol m_u8m,  '__U8M'
		symbol m_u8rs, '__U8RS'

.symbol_count equ ($-.symbol_fofss)>>2
emit_symbol_names
.size equ $-m_symbol_table-60
times (m_symbol_table-$)&1 db 0

m_i8d:		member 'i8d.obj'
m_i8rs:		member 'i8rs.obj'
m_u8d:		member 'u8d.obj'
m_u8ls:		member 'u8ls.obj'
m_u8m:		member 'u8m.obj'
m_u8rs:		member 'u8rs.obj'

; __END__
