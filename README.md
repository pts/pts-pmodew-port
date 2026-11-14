# pts-pmodew-port: source-level reproduction and port of the PMODE/W DOS extender

pts-pmodew-port is a source-level reproduction and port from Turbo Assembler
(TASM) to the Netwide Assembler (NASM) of the PMODE/W DOS extender versions
1.33 and 1.34, based on the PMODE/W 1.33--1.34 source code released on
2023-07-27 under the MIT license. pts-pmodew-port provides all necessary
source files (TASM, NASM and C) to compile PMODE/W 1.33, and the result will
be bytewise identical to the officially released pmodew.exe (1997-01-01).
Additionally, pts-pmodew-port has some new features (disabled by default) in
the NASM source. Such a new feature is the simple PE loader, which can load
a Win32 PE .exe program file.

Please note that pts-pmodew-port doesn't attempt to recreate the tools
bundled with PMODE/W 1.33: pmwbind.exe, pmwlite.exe, pmwsetup.exe and
pmwver.com. The source code of these tools is available in the original
[pmw133src.zip](http://www.sid6581.net/pmodew/pmw133src.zip).

## How to compile

There are many ways to compile pts-pmodew-port, choose the way below which
is most comfortable for you. On Linux i386 (and amd64), FreeBSD, DOS and
Windows, probably one of the NASM ways will be the most convenient, because
NASM is bundled with pts-pmodew-port, so you don't have to install anything.

### With NASM on Linux i386, Linux amd64 or FreeBSD i386

Just download the Git repo, and run `sh compile.sh`. The output file is
`pmodew.exe`.

A NASM precompiled for Linux i386 and FreeBSD i386 (same executable, detects
the operating system at startup) is bundled in the [tools/](tools/)
directory, and it will be used. There is no need to install any compiler or
assembler to your system.

Compilation also works in a Docker image.

### With NASM on DOS, Windows, Windows emulator or OS/2 DOS window

If your system supports long filenames (i.e. it can open a file with the
.nasm extension) (e.g Windows 95, Windows NT 4.0, and later Windows such as
Windows 10 and Windows 11), then just download the Git repo, and run
`compile_nasm_long`. The corresponding batch file is
[compile_nasm_long.bat](compile_nasm_long.bat). The output file is
`pmodew.exe`.

If you use Wine as a Windows emulator, here is how to run
[compile_nasm_long.bat](compile_nasm_long.bat) from the command line: `wine
cmd /c compile_nasm_long.bat`

If your system supports the classic DOS 8.3 filenames only, then download
the Git repo, copy (or rename) the file pmodew.nasm to pmodew.nas; copy
likewise the files pmwca.nasm, pmwcax.nasm, flexpe.nasm; and run `compilen`.
The corresponding batch file is [compilen.bat](compilen.bat). The output
file is `pmodew.exe`.

### With NASM and a C compiler on any system

A C compiler such as GCC is needed to compile the executable compressor
implemented in [pmwca.c](pmwca.c). Other C compilers may also work, because
it's written in C89 (ANSI C).

If you have a Unix-like system (such as Linux, FreeBSD, Docker image, macOS,
Windows WSL, MinGW), just download the Git repo, and run `sh
compile_nasm_gcc.sh`. The output file is `pmodew.exe`.

If you have another system with NASM and a C compiler installed, run the
commands in the file [compile_nasm_gcc.sh](compile_nasm_gcc.sh) manually,
modifying them to match the command-line flags your C compiler expects.

### With NASM on a DOS emulator running on a Unix-like system

You may want to try another, easier way first: NASM and a C compiler, see
above.

On Linux i386 (or amd64), just download the Git repo, and run `sh
compile_nasm_kvikdos.sh`. The output file is `pmodew.exe`.

[compile_nasm_kvikdos.sh](compile_nasm_kvikdos.sh) tries two emulators:
[kvikdos](https://github.com/pts/kvikdos) and
[emu2](https://github.com/dmsc/emu2), both precompiled for Linux i386 and
bundled with pts-pmodew-port. If you want to compile pts-pmodew-port on
another Unix-like system, then you have to build emu2 from source (see the
link above), copy the executable program file to `emu2` to the Git working
tree directory, and then run `sh compile_nasm_kvikdos.sh false ./emu2`. The
output file is `pmodew.exe`.

### With Turbo Assembler (TASM) on DOS, OS/2 or 32-bit i386 Windows

If you have Turbo Assembler >=2.0 (tasm.exe) and Turbo Link (tlink.exe)
running on DOS (or DOS emulator), OS/2 or 32-bit i386 Windows, then download
the Git repo, copy all .asm files, [compile.bat](compile.bat), tasm.exe and
tlink.exe to your DOS machine, and run `compile`. The output file is
`pmodew.exe`.

This is closest to the way PMODE/W was compiled by the original developers,
and it is based on the *mp.bat* batch file they have released as part of the
source code. However, they haven't released the executable compressor, that
has been added by pts-modew-port, and its invocation has been added to
[compile.bat](compile.bat).

### With Turbo Assembler (TASM) on 64-bit Windows (it doesn't work)

Compilation doesn't work directly on 64-bit Windows, because 64-bit Windows
isn't able to run the Turbo Link (tlink.exe) needed for the compilation.
You need 32-bit i386 Windows or a DOS emulator for that. tlink.exe is a
16-bit real-mode DOS program.

On 64-bit Windows it is recommended that you compile with NASM instead.

Please note that the tasm32.exe executable of Turbo Link indeed runs on
64-bit Windows, but it produces Win32 PE .exe executable output files, and
compiling PMODE/W needs a linker which produces DOS MZ .exe program files
instead.

### With Turbo Assembler (TASM) on a DOS emulator runing on a Unix-like system

For this you will need Turbo Assembler >=2.0 (tasm.exe) and Turbo Link
(tlink.exe, not tlink32.exe). You have to obtain these separately. If you
get a full package of an early version of TASM (2.x or 3.x), then Turbo Link
will be included.

On Linux i386 (or amd64), just download the Git repo, copy tasm.exe and
tlink.exe to the to the Git working thee directory, and run `sh
compile_tasm_tlink_kvikdos.sh`. The output file is `pmodew.exe`.

[compile_tasm_tlink_kvikdos.sh](compile_tasm_tlink_kvikdos.sh) tries two emulators:
[kvikdos](https://github.com/pts/kvikdos) and
[emu2](https://github.com/dmsc/emu2), both precompiled for Linux i386 and
bundled with pts-pmodew-port. If you want to compile pts-pmodew-port on
another Unix-like system, then you have to build emu2 from source (see the
link above), copy the executable program file to `emu2` to the Git working
tree directory, and then run `sh compile_tasm_tlink_kvikdos.sh tasm.exe
tlink.exe false ./emu2`. The output file is `pmodew.exe`.

## What's new in pts-pmodew-port

Source code portability improvements:

* The original TASM source code has been ported to all versions of Turbo
  Assembler >=2.0. Different versions produce slightly different output,
  which was made consistent using *db* instructions.
* The original TASM source code has been ported to the Netwide Assembler
  (NASM) >=0.98.39.
* Generation of both PMODE/W 1.33 and 1.34 pmodew.exe has been added using
  conditional compilation (*ifdef* etc.). These are all the differences:
  different version number, year and copyright string; 1 global variable has
  been moved to a few bytes earlier.

Source code additions:

* An executable compressor using a variant of LZSS has been written from
  scratch. Its DOS .exe output file for pmodew.exe is bytewise identical to
  of the executable compressor the original PMODE/W developers were using.
  However, they haven't shared that source code or any other detail, so this
  had to be reverse-engineered from scratch.

  The executable compressor has been implemented 3 times, 1
  system-independent, and the others targeting 4 systems in total:

  * [pmwc.c](pmwc.c) is in ANSI C (C89)
  * [pmwca.nasm](pmwca.nasm) is in NASM, targeting DOS 8086
  * [pmwcax.nasm](pmwcax.nasm) is in NASM, targeting Win32 i386, Linux i386
    and FreeBSD i386

* Creating an uncompressed, but working variant of pmodew.exe, pmodewv.exe
  has been added as a conditional compilation option (`tasm /dUNC=1` or
  `nasm  -DUNC=`). This way PMODE/W can be tested without using the
  executable compressor.

* Conditional compilation (*%ifdef*) has been added for multiple features to
  [pmodew.nasm](pmodew.nasm) (lots) and [pmodewe.asm](pmodewe.asm) (a few).

Feature additions:

* The simple PE loader (can be enabled with `nasm -DLOADSPE`) has been added
  to [pmodew.nasm](pmodew.nasm), see its documentation there.
  It can load a subset of i386 PE .exe
  program files which conform to its limitations. Please note that there is
  no Win32 emulation layer, so the code in those i386 PE .exe program files
  still has to use the `DOS (int 21h) and DPMI (int 31h) services for I/O,
  not the Win32 API. The simple PE loader can't be used to run existing
  Win32 i386 programs, because it doesn't process any DLL imports, and a
  DLL import (ExitProcess) is needed even from exiting the program.

  The simple PE loader can be used as a building block for creating
  ultraportable Win32 i386 console (command-line, CUI, text-mode) .exe
  program files, which run on:

  * 32-bit i386 Windows (Windows NT 3.1, Windows 95, or later, even Windows
    10 and Windows 11) directly
  * 64-bit amd64 Windows (including Windows 10 and Windows 11)
    using WoW64 built into Windows
  * Windows emulators such as Wine
  * DOS (with a 80836 orlater CPU) using PMODE/W in the DOS stub
  * OS/2 >=2.0 DOS window using PMODE/W in the DOS stub
  * DOS emulators (such as DOSBox) using PMODE/W in the DOS stub

  A convenient end-to-end build environment for such ultraportable
  .exe program files (including a C compiler and C library) is also provided
  by pts-pmodew-port, see [dwlibc.md](dwlibc.md).

* The simple PE builder (can be enabled with `%define SPE_EntryPoint ...`
  before the `%include 'pmodew.nasm'`) has been added to
  [pmodew.nasm](pmodew.nasm), see its documentation there. It can be used to
  create 32-bit DOS programs (using the DOS (int 21h) and DPMI (int 31h)
  services for I/O) containing PMODE/W with the simple PE loader enabled in
  the DOS stub, using a single run of NASM. No other tools are needed.
  See short example programs in [hellospe.nasm](hellospe.nasm) and
  [helluspe.nasm](helluspe.nasm).

  The overhead (including the MZ header, the PE header, the PMODE/W
  relocations and the PMODE/W code and data) is 0x3200 bytes == 12.5 KiB.
  Beyond that file offset it's only the user program code and data, which
  can be as short as 6 bytes (mov ax, 4c00h; int 21h) for a program which
  immediately exits successfully. The overhead when using a compressed
  PMODE/W in the DOS stub would be 0x2600 bytes == 9.5 KiB, thus 3 KiB
  shorter. But the simple PE builder doesn't support this compression.
  FYI the minimum overhead for a Win32 i386 PE .exe is 0x200 bytes == 0.5
  KiB plus the DLL import table (but the simple PE builder can't be used to
  build a Win32 i386 PE .exe).

## Original PMODE/W

The work in pts-pmodew-port is based on the original PMODE/W 1.33 source
code, distributed as
[pmw133src.zip](http://www.sid6581.net/pmodew/pmw133src.zip) under the MIT
license. The original source code contains the source code of all tools
as well, i.e. the C source of pmwbind.exe, the C source of pmwlite.exe,
the C source of pmwsetup.exe and the TASM assembly source of pmwver.com.
It also contains the documentation

The original binary releases of PMODE/W 1.33 in
[pmw113.zip](http://www.sid6581.net/pmodew/pmw133.zip) contains the
precompiled pmodew.exe, pmwbind.exe, pmwlite.exe, pmwsetup.exe and
pmwver.com, documentation and examples.

The alternative original binary release of PMODE/W 1.33i in
[pmw133i.zip](http://www.sid6581.net/pmodew/pmw133i.zip) contains
pmodewi.exe and pmodewic.exe, which are smaller versions of pmodew.exe with
many features removed. Similar smaller versions can be built from source
([pmodew.nasm](pmodew.nasm)) in pts-pmodew-port, by passing macro
definitions on the NASM command line (e.g. `nasm -DINT33=0 -DINT1B=0
-DSIZEOPT=1`).
