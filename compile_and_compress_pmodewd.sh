#! /bin/sh --
#
# compile.sh: build PMODE/W 1.33 on Linux i386 (or amd64) or FreeBSD i386
# by pts@fazekas.hu at Thu Jun 12 11:50:15 CEST 2025
#
set -e
unset LANG LANGUAGE
export LC_ALL=C  # For reproducible builds.
export TZ=GMT  # For reproducible builds.
test "$0" = "${0%/*}" || cd "${0%/*}"
set -x

nasm=tools/nasm-0.98.39.upx
if test "$1"; then
  nasm="$1"
else
  "$nasm" -v >/dev/null 2>&1 || nasm=nasm  # Use the system nasm if the bundled "$nasm" doesn't work.
fi
apack1p="$HOME"/prg/apack1p/apack1p
upx="$HOME"/Downloads/dosasm2/toolset/bin/upx-3.94
upfx="$HOME"/Downloads/memtest86+/upfx/upfx.pl

"$nasm" -O32700 -w+orphan-labels -DPMWV=33 -DLOGO=0 -DSIZEOPT=1 -DCONFIGTYPE=2 -DLOADSPE=3 -DSPECUSTOMENTRY=2 -DLOADLE=0 -DLOADPMW1=0 -DEXCEPTIONS=1 -DINT3108FUNC=0 -DINT1B=2 -DINT33=0 -DINT31VENDOR=0 -DFREEMEMINFO=0 -DGETVERSION=0 -DABORTMSGTTY=1 -DEXITCODE=1 -DSHORTMSG=1 -o pmodewdu.exe pmodew.nasm
"$nasm" -O0 -w+orphan-labels -DPMWV=33 -DLOGO=0 -DCONFIGINEXEIMAGE=2 -DPM_SELECTORS=4 -o pmwca pmwcax.nasm
chmod +x ./pmwca
./pmwca pmodewdu.exe pmodewd.exe

"$apack1p" -q -q -t -1 -h -g pmodewdu.exe pmodewda.exe
"$upx" -q -q -q --ultra-brute --no-lzma -f -o pmodewdx.exe pmodewdu.exe
"$upfx" -q --exe --exehdr-size=0x20 pmodewdu.exe pmodewdf.exe 

ls -ld pmodewd.exe pmodewdu.exe pmodewda.exe pmodewdx.exe pmodewdf.exe

: "$0" OK.
