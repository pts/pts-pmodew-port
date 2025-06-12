#! /bin/sh --
# by pts@fazekas.hu at Thu Jun 12 11:50:15 CEST 2025
set -ex

test "$0" = "${0%/*}" || cd "${0%/*}"

# Tested and found working: TASM 2.0, 2.01, 2.02, 2.5, 2.51, 3.2i, 3.2, 4.1, 5.0, 5.2, 5.3.
# It's not working with TASM 1.0 and 1.01: they don't have the /m2 command-line flag (for optimization).
# It's not working with TASM 3.0 and 3.1: they hang (int 3 in kvikdos).
tasm_exe="${1:-tasm41.exe}"
# Tested and found working: TLINK 2.0, 3.0, 3.01, 4.0, 4.01.
# It's not working with WLINK in OpenWatcom 2.0 2023-03-04, it generates incorrect relocations.
tlink_exe="${2:-tlink40.exe}"
kvikdos="${3:-$HOME/prg/kvikdos/kvikdos}"

case "$tasm_exe" in
 t32*.exe | tasm32*.exe)
  dosbox.nox.static --cmd --mem-mb=3 mwperun.exe "$tasm_exe" /t /ml /m2 /zn /q /dPMWV=33 pmodewe
  dosbox.nox.static --cmd --mem-mb=3 mwperun.exe "$tasm_exe" /t /ml /m2 /zn /q /dPMWV=33 pmodewk
  ;;
 tasm[12]*.exe)  # The /zn flag has been introduced in TASM 3.0.
  "$kvikdos" "$tasm_exe" /t /ml /m2 /q /dPMWV=33 pmodewe
  "$kvikdos" "$tasm_exe" /t /ml /m2 /q /dPMWV=33 pmodewk
  ;;
 *.exe)
  "$kvikdos" "$tasm_exe" /t /ml /m2 /zn /q /dPMWV=33 pmodewe
  "$kvikdos" "$tasm_exe" /t /ml /m2 /zn /q /dPMWV=33 pmodewk
  ;;
 *)
  if test "$tasm_exe" = "${tasm_exe#*/}"; then tasm_exe="./$tasm_exe"; fi
  "$tasm_exe" /t /ml /m2 /zn /q /dPMWV=33 pmodewe
  "$tasm_exe" /t /ml /m2 /zn /q /dPMWV=33 pmodewk
  ;;
esac
"$kvikdos" "$tlink_exe" /3 /x pmodewe pmodewk,pmodew.exe
if true; then
  owcc -blinux -I"$WATCOM/lh" -Os -s -fno-stack-check -march=i386 -W -Wall -o execons execons.c
  ./execons pmodew.exe
elif false; then
  gcc -W -Wall -s -O2 -o execons execons.c
  ./execons pmodew.exe
elif false; then
  # Turbo C++ 1.01 free (??) license and free download (not available anymore):
  # https://web.archive.org/web/20090307213905/https://edn.embarcadero.com/article/21751
  #
  # > These historical files are provided to the Borland community free of
  # charge. They may be downloaded and used "as is" for personal use only.
  # No developer support is provided. Each individual product contains
  # copyright notices that are still in force. These files may not be made
  # available via the Internet or any hard copy media (e.g. diskette,
  # CDROM).
  #
  # Also works with Turbo C++ 1.00.
  rm -f execons.exe
  # Needs: tcc.exe, tlink.exe, tcch/*.h, c0s.obj, fp87.lib, maths.lib, cs.lib.
  "$kvikdos" tcc.exe -ms -Itcch -f87 execons.c  # !! What is the minimum set of files needed for compiling with Turbo C++ 1.01 (free)? Also for pmwc.c.
  "$kvikdos" execons.exe pmodew.exe
elif false; then
  rm -f execons.exe
  owcc -bdos -Os -s -fno-stack-check -march=i086 -W -Wall -o execons.exe execons.c
  "$kvikdos" execons.exe pmodew.exe
elif false; then
  minicc -o execons execons.c
  ./execons pmodew.exe
else
  : '! Missing compiler for execons.c' >&2
  false
fi

# Change the byte at 0x1c+3 from anything to 0x50. This is some kind of
# linker version number not used by DOS when loading the .exe.
#perl -pi -0777 -e 'substr($_, 0x1c, 4) = "\1\0\xfb\x50"' pmodew.exe

#cmp ../pmodew.exe pmodew.exe
test "$(sha256sum pmodew.exe)" = "8f8dfc58a6b4936b872cf81498ef98326f5e38d666fa0c3574b6757b53fe7119  pmodew.exe"  # /dPMWV=1.33.
#test "$(sha256sum pmodew.exe)" = "d4271dc2162922c78fa5c6b94a360ca0fa4852c95a7f18c54e03177d96c18e1f  pmodew.exe" # /dPMWV=1.34.

test -d "$WATCOM/lh"
owcc -blinux -I"$WATCOM/lh" -Os -s -fno-stack-check -march=i386 -W -Wall -DCOMPRESS_BITS=16 -DCOMPRESS_BITREV=1 -DCOMPRESS_LONGDIST=0 -DCOMPRESS_M1BITFIRST=0 -DCOMPRESS_EARLYNEXTBLOCK=0 -DDEBUG -o pmwc pmwc.c
./pmwc pmodew.exe pmodewc.exe >pmodewc.log
test "$(sha256sum pmodewc.exe)" = "2c453d800d04413c5798c3428b55fb4c71d6987027acc876aef2bdd9c5d865a8  pmodewc.exe"  # Same as of pmodew133r.exe.

: "$0" OK.
