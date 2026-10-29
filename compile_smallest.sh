#! /bin/sh --
#
# compile_smallest.sh: compiles the smallest possible variant of the PMODE/W DOS extender
# by pts@fazekas.hu at Tue Oct 27 04:41:00 CET 2026
#

set -e
unset LANG LANGUAGE INC LIB LIBDIR WLINK_LNK INCLUDE
export LC_ALL=C  # For reproducible builds.
export TZ=GMT  # For reproducible builds.
test "$ZSH_VERSION" && set -y 2>/dev/null  # SH_WORD_SPLIT for zsh(1). It's an invalid option in bash(1), and it's harmful (prevents echo) in ash(1).

test "$0" = "${0%/*}" || cd "${0%/*}"

nasm=tools/nasm-0.98.39.upx
# -DLOADPMW1=1 produces smaller code than -DLOADLE=1.
smallest_defs="-DLOGO=0 -DCONFIGINEXEIMAGE=1 -DPMW1UNCOMP=1 -DLOADLE=0 -DLOADPMW1=1 -DEXCEPTIONS=0 -DINT3108FUNC=0 -DINT1B=0 -DINT33=0"

set -ex

"$nasm" -O0 -w+orphan-labels -DPMWV=33 -DLOGO=0 -DCONFIGINEXEIMAGE=1 -o pmwca pmwcax.nasm
chmod +x pmwca

"$nasm" -O32700 -w+orphan-labels -DPMWV=33 -o pmodewu.exe pmodew.nasm
"$nasm" -O32700 -w+orphan-labels -DPMWV=33 -DUNC=1 -o pmodewv.exe pmodew.nasm
./pmwca pmodewu.exe pmodew.exe

"$nasm" -O32700 -w+orphan-labels -DPMWV=33 $smallest_defs -o pmodswu.exe pmodew.nasm
"$nasm" -O32700 -w+orphan-labels -DPMWV=33 -DUNC=1 $smallest_defs -o pmodswv.exe pmodew.nasm
./pmwca pmodswu.exe pmodsw.exe

ls -ld pmodew.exe pmodsw.exe  # 11484 vs 8978 bytes. wdosx.dx is 9720 bytes.

: "$0" OK.
