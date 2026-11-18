# dwlibcc: C compiler toolchain to create standalone and combined executables

dwlibcc is a standalone C compiler toolchain with the ability to create
standalone (statically linked, no need to install, no need to copy any other
file to the target machine) and combined executable program files. Combined
means that the same program file runs on multiple operating systems. The two
combinations supported by dwlibcc are DOS--Win32 and Linux--FreeBSD. dwlibcc
runs on a Linux i386 (or amd64) host, and it can cross-compile to all its
supported targets. dwlibcc targets the i386 architecture (Intel 80386 or
later CPU) only.

To try dwlibcc quickly on Linux, run these commands:

```
git clone https://github.com/pts/pts-pmodew-port
cd pts-pmodew-port
./dwlibcc --prepare
./dwlibcc -s -Os -W -Wall -Wextra -Werror -std=c89 -o helldspe.exe helldspe.c
./dwlibcc -bfreebsdx -s -Os -W -Wall -Wextra -Werror -std=c89 -o helldspe helldspe.c
ls -l helldspe*
./helldspe
```

dwlibc includes all components needed to create executable program files:

* dwlibcc: C compiler driver, written as a Unix shell script.
* tools/owcc: Lower level C compiler sub-driver. Copied from OpenWatcom v2.
* tools/wcc386: C compiler frontend--backend which creates OMF object files.
  Copied from OpenWatcom v2.
* tools/wlink: Linker which creates executable program files.
  Copied from OpenWatcom v2.
* tools/sstrip: A post-processing tool which modifies executable program
  files slightly.
* dwlibc.h: Header-only implemetation of the C library (libc). It contains
  lots of i386 inline assembly in an OpenWatcom-specific syntax.
* pmodewd.exe: A modified PMODE/W 1.33 DOS extender which can load and run
  i386 PE .exe executable program files (rather than LE executables) on DOS.
* tools/nasm-0.98.39.upx: Assembler (Netwide Assembler, NASM) to build the
  PMODE/W DOS extender and the object files containing some libc functions.

Some of the components above are built from source (C or assembly) when
running `./dwlibcc --prepare`.

## System requirements

dwlibc itself runs only on Linux i386 (or amd64) systems, in Linux emulators
(such as WSL in Windows) and in Docker containers. The Linux distribution
doesn't matter, it runs on all of them. The instructions are for the
simplest case: running it from Linux command line.

The targets, i.e. executable program files created by dwlibc need an Intel
80386 or later or compatible CPU (all modern x86 CPUs are also fine). The
minimum total system memory (RAM) requirement for DOS is 640 KiB, and for
other systems it's whatever the system requires. The target operating system
requirements are:

* Target `-bdos32` works on any of these systems:
  * DOS >=2.0. (Works with or without himem.sys or emm386.exe.)
  * DOSBox >=0.74. Other DOS emulators supporting i386 should also work.
  * Windows 3.x running in enhanced mode.
  * OS/2 >=2.0 DOS window.
  * Windows 95, Windows 98 or Windows ME.
  * Windows NT >=3.1.
  * Windows 2000, Windows XP, Windows Vista, Windows 7, Windows 8.x, Windows
    10 or Windows 11, but only if it is running a 32-bit x86 kernel. Modern
    Windows 10 or 11 probably won't work, because most of these are
    typically running a 64-bit amd64 kernel.
* Target `-bwin32` works on any of these systems:
  * Windows 95, Windows 98 or Windows ME.
  * Windows NT >=3.1.
  * Windows 2000, Windows XP, Windows Vista, Windows 7, Windows 8.x, Windows
    10 or Windows 11, but only if it is running either a 32-bit x86 kernel
    or a 64-bit amd64 kernel. Thus modern Windows 10 or 11 also works.
  * Wine >=1.6.2 and possibly other Win32 emulators.
  * ReactOS >=0.4.14.
* Target `-bdoswin32` works on any of the system where `-bdos32` or
  `-bwin32` works.
* Target `-blinux` works on any of these systems:
  * Linux i386 kernel >=1.0. Any Linux distribution.
  * Linux amd64 (x86_64) kernel. Any Linux distribution.
  * Linux on any architecture using *qemu-i386*. Any Linux distribution.
  * FreeBSD i386 or FreeBSD amd64 with the [Linux emulator on
    FreeBSD](https://docs.freebsd.org/en/books/handbook/linuxemu/), which
    is disabled by default. Any Linux distribution, even without it.
  * Modern Windows using WSL or WSL2. Any Linux distribution.
* Target `-bfreebsdx` works on any of these systems:
  * Any system on which `-blinux` works. At startup time the program
    autodetects whether it is running on Linux or FreeBSD, and then uses the
    appropriate syscalls.
  * FreeBSD i386 >=3.0.
  * FreeBSD amd64 with *COMPAT\_FREEBSD32* enabled in the kernel.

## How to use dwlibc to build executable programs

dwlibc is distrubited as a Git repository (`git clone
https://github.com/pts/pts-pmodew-port`), which contains C source files,
NASM assembly source files and also executable program files (binaries)
precompiled and statically linked for Linux i386. There is no need to
install it, just run the `dwlibcc` command either by specifying its pathname
(e.g. `./dwlibcc`) or putting its directory to your `$PATH`.

You have to specify the target system as a `-b...` flag near the beginning
of your command-line arguments. The default is `dwlibcc -bdoswin32`.

You have to specify the output file name as `-o <filename>`. For DOS and
Win32 targets, also specify the .exe extension, e.g. `dwlibcc -bwin32 -o
prog.exe`.

Most command-line flags you pass to `dwlibcc` are passed on to `owcc`
(OpenWatcom v2 C compiler driver), for example, disable a warning like this:
`dwlibcc -Wno-n201`.

Please note that `dwlibcc`, just like `owcc` creates object files with the
extension .o, and doesn't remove them even after linking.

Example compile of a larger project:

```
git clone https://github.com/pts/luuzcat
(cd luuzcat && ../dwlibcc         -s -Os -W -Wall -Wextra -Werror -std=c89 -include dwlibc.h -DLIBC_PREINCLUDED -D_LIBC_USE_MAIN1 -o luuzcat.exe luuzcat.c unscolzh.c uncompact.c unopack.c unpack.c undeflate.c uncompress.c unfreeze.c)
(cd luuzcat && ../dwlibcc -blinux -s -Os -W -Wall -Wextra -Werror -std=c89 -include dwlibc.h -DLIBC_PREINCLUDED -D_LIBC_USE_MAIN1 -o luuzcat     luuzcat.c unscolzh.c uncompact.c unopack.c unpack.c undeflate.c uncompress.c unfreeze.c)
ls -ld luuzcat/luuzcat luuzcat/luuzcat.exe
```

Example compile of a larger project using more libc functions:

```
git clone https://github.com/pts/mininasm
(cd mininasm && ../dwlibcc         -s -Os -W -Wall -Wextra -Werror -std=c89 -include dwlibc.h -DCONFIG_SKIP_LIBC -o mininasm.exe mininasm.c)
(cd mininasm && ../dwlibcc -blinux -s -Os -W -Wall -Wextra -Werror -std=c89 -include dwlibc.h -DCONFIG_SKIP_LIBC -o mininasm     mininasm.c)
ls -ld mininasm/mininasm mininasm/mininasm.exe
```

Example compile of a larger project using even more libc functions:

```
git clone https://github.com/pts/minixbcc
minixbcc/cross.sh --no-cc --no-cpp "$PWD"/dwlibcc -bfreebsd -include dwlibc.h -s -Os -W -Wall -Wextra -Werror -std=c89 -D_LIBC_USE_FAKE_FREE -DLIBCH -DNOEXECUTABLE
ls -ld minixbcc/libexec/* minixbcc/*/*.a
```

General usage of dwlibcc:

* The dwlibcc command of dwlibcc is  a C compiler driver, which create
  stanalone, text-mode (console), combined DOS--Win32 .exe programs from C
  source. The same .exe runs on DOS (with a 80386 or later CPU), Windows
  (Win32 i386, also on 64-bit Intel Windows using WoW64), Windows
  emulators (such as Wine) and and OS/2 >=2.0 DOS window. There is no need
  to install anything or copy any other file (in addition to the program
  .exe file) to the target matchine, the generated program .exe file is
  standalone and self-contained.
* dwlibcc runs on Linux i386 (and amd64) only. That's partly restricted by
  the host systems the OpenWatcom v2 compiler supports. It would be
  possible to make it work on Win32 as well.
* dwlibcc accepts command-line flags and arguments just like the owcc C
  compiler driver in OpenWatcom v2, which is a bit similar to gcc. See
  example invocations above.
* dwlibcc uses owcc under the hood, it passes many flags to it by default,
  and after these dwlibcc-specific flags it passes almost all arguments
  the user has passed to dwlibcc.
* The dwlibcc-specific command-line flags must all be specified at the
  beginning of the dwlibcc command line (in any order). They are:
  * -bdoswin32 (default): Build combined DOS--Win32 .exe program file.
  * -bdos32: Build DOS-only .exe program file. It works on DOS >=2.0.
    It needs a 80386 or later CPU. If the program doesn't call
    malloc(...), it works even with just 640 KiB of RAM, even malloc(...)
    works. The memory requirement before the first malloc(...) call
    on DOS is: 21 KiB + SizeOfImage + SizeOfStackCommit.
  * -bwin32: Build Win32-only .exe program file. It works on Windows NT
    3.1 (1993) or later, and Windows 95 (1995), even on Windows 10 and
    Windows 11.
  * -blinux: Build Linux i386 ELF-32 executable program file. It works
    on Linux kernel >=1.0.
  * -bfreebsdx: Build combined Linux--FreeBSD i386 ELF-32 executable
    program file. It works on Linux kernel >=1.0 and FreeBSD >=3.0.
  * -bany: Build system-independent object files. All system-specific
    declarations (including I/O functions such as write(...)) will be
    hidden in <dwlibc.h>, and linking (if attempted) will fail with
    undefined symbols.
  * --nasm=...: NASM command name to build the PMODE/W DOS extender
    for -bdoswin32 and -bdos.
* The default program stack size is as little as 8 KiB. Specify something
  larger if needed, e.g. `-mstack=64k`. On Linux and FreeBSD, the stack
  size setting is ignored.

## Limitations of dwlibc

These are the current limitations:

* It supports creating text-mode (console) programs only, it doesn't
  support any GUI.
* The libc provides only a few functions:
  * File (and console) I/O: open, open00, create, create1, close, read,
    write, lseek, isatty, rename == unlink, ftruncate, ftruncate_here.
  * Process management: exit == _exit.
  * Dynamic memory: malloc only (no relloc, no free).
  * Integer helpers: abs, labs, _rotl, _rotr, _lrotl, _lrotr.
  * Strings: memchr, memcmp, memcpy, memset, strcat, strchr, strcmp,
    strcpy, strlen, strncpy, strrchr.
  * ASCII character classes: isalnum, isalpha, isascii, isdigit, islower,
    isprint, isspace, isupper, isxdigit.
  * ASCII character transformation: tolower, toupper.
  * No buffered file I/O, i.e. no printf, fwrite, putchar, scanf, fread.
  * (More functions can be added as needed.)
* It doesn't support function error codes (errno).
* It doesn't pass the environment variables (environ) to the program.
* All libc functions are inlined, so the more function call code locations
  you have, the larger your output .exe becomes. (This could be fixed by
  a redesign from header-only to .obj-in-.lib.)
* It doesn't do any CRLF-to-LF trasnlation, all I/O is binary. It supports
  8 bits (i.e. the ANSI encodings) in characters in filenames, on the
  command line and on the console.
* It doesn't support multithreaded programs.
* It doesn't support long filenames on DOS. (It could be added, first
  PMODE/W, then to the libx.)
* It doesn't support command-line strings longer than 126 bytes on DOS.
* The -bwin32 and -bdoswin32 .exe imports even those Win32 functions
  from kernel32.dll which it doesn't use. (This could be fixed by
  running wlink twice, and creating a shorter .lnk file in-between.)
* No floating-point support. (Some simple operations may work.) No
  floating-point emulation support.
* Compressed executables (such as with UPX) are not supported for `-bdos32`,
  -bdoswin32` and `-bfreebsdx` targets.
* There is no way to grow the stack, not even on Win32 (which supports
  growing it until it reaches size SizeOfStackReserve).
* It only works with files shorter than 2 GiB. The culprits are the *lseek*
  and *ftruncate* functions, which take a 32-bit signed integer. However,
  depending on the system (e.g. on Linux), even opening large files may
  fail.
