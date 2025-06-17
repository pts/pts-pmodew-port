#! /bin/sh --
# by pts@fazekas.hu at Thu Jun 12 11:50:15 CEST 2025
set -ex
unset LANG LANGUAGE INC LIB LIBDIR WLINK_LNK INCLUDE
export LC_ALL=C TZ=GMT

test "$0" = "${0%/*}" || cd "${0%/*}"

# Tested and found working: TASM 2.0, 2.01, 2.02, 2.5, 2.51, 3.0, 3.1, 3.2i, 3.2, 4.1, 5.0, 5.2, 5.3.
# It's not working with TASM 1.0 and 1.01: they don't have the /m2 command-line flag (for optimization).
# It's not working with TASM 3.0 and 3.1 in kvikdos, they fail with `int 0x03' in kvikdos.
tasm_exe="${1:-tasm41.exe}"
# Tested and found working: TLINK 2.0, 3.0, 3.01, 4.0, 4.01.
# It's not working with WLINK in OpenWatcom 2.0 2023-03-04, it generates incorrect relocations.
tlink_exe="${2:-tlink40.exe}"
kvikdos="${3:-$HOME/prg/kvikdos/kvikdos}"

case "$tasm_exe" in
 t32*.exe | tasm32*.exe)
  dosbox.nox.static --cmd --mem-mb=3 mwperun.exe "$tasm_exe" /t /ml /m2 /zn /q /dPMWV=33 pmodewe
  dosbox.nox.static --cmd --mem-mb=3 mwperun.exe "$tasm_exe" /t /ml /m2 /zn /q /dPMWV=33 pmodewk
  dosbox.nox.static --cmd --mem-mb=3 mwperun.exe "$tasm_exe" /t /ml /m2 /zn /q /dPMWV=33 /dUNC pmodewe,pmodewev
  dosbox.nox.static --cmd --mem-mb=3 mwperun.exe "$tasm_exe" /t /ml /m2 /zn /q /dPMWV=33 /dUNC pmodewk,pmodewkv
  dosbox.nox.static --cmd --mem-mb=3 mwperun.exe "$tasm_exe" /t /ml /m2 /zn /q /dPMWV=33 pmwca
  ;;
 tasm[12]*.exe)  # The /zn flag has been introduced in TASM 3.0.
  "$kvikdos" "$tasm_exe" /t /ml /m2 /q /dPMWV=33 pmodewe
  "$kvikdos" "$tasm_exe" /t /ml /m2 /q /dPMWV=33 pmodewk
  "$kvikdos" "$tasm_exe" /t /ml /m2 /q /dPMWV=33 /dUNC pmodewe,pmodewev
  "$kvikdos" "$tasm_exe" /t /ml /m2 /q /dPMWV=33 /dUNC pmodewk,pmodewkv
  "$kvikdos" "$tasm_exe" /t /ml /m2 /q /dPMWV=33 pmwca  # Default input extension: .asm. Default output extension: .obj.
  ;;
 tasm3[01]*.exe)  # They produce `int 3' in kvikdos. Without --mem-mb=2, they just hang in dosbox.nox.static.
  dosbox.nox.static --cmd --mem-mb=2 "$tasm_exe" /t /ml /m2 /zn /q /dPMWV=33 pmodewe
  dosbox.nox.static --cmd --mem-mb=2 "$tasm_exe" /t /ml /m2 /zn /q /dPMWV=33 pmodewk
  dosbox.nox.static --cmd --mem-mb=2 "$tasm_exe" /t /ml /m2 /zn /q /dPMWV=33 /dUNC pmodewe,pmodewev
  dosbox.nox.static --cmd --mem-mb=2 "$tasm_exe" /t /ml /m2 /zn /q /dPMWV=33 /dUNC pmodewk,pmodewkv
  dosbox.nox.static --cmd --mem-mb=2 "$tasm_exe" /t /ml /m2 /zn /q /dPMWV=33 pmwca
  ;;
 *.exe)
  "$kvikdos" "$tasm_exe" /t /ml /m2 /zn /q /dPMWV=33 pmodewe
  "$kvikdos" "$tasm_exe" /t /ml /m2 /zn /q /dPMWV=33 pmodewk
  "$kvikdos" "$tasm_exe" /t /ml /m2 /zn /q /dPMWV=33 /dUNC pmodewe,pmodewev
  "$kvikdos" "$tasm_exe" /t /ml /m2 /zn /q /dPMWV=33 /dUNC pmodewk,pmodewkv
  "$kvikdos" "$tasm_exe" /t /ml /m2 /zn /q /dPMWV=33 pmwca
  ;;
 *)
  if test "$tasm_exe" = "${tasm_exe#*/}"; then tasm_exe="./$tasm_exe"; fi
  "$tasm_exe" /t /ml /m2 /zn /q /dPMWV=33 pmodewe
  "$tasm_exe" /t /ml /m2 /zn /q /dPMWV=33 pmodewk
  "$tasm_exe" /t /ml /m2 /zn /q /dPMWV=33 /dUNC pmodewe,pmodewev
  "$tasm_exe" /t /ml /m2 /zn /q /dPMWV=33 /dUNC pmodewk,pmodewkv
  "$tasm_exe" /t /ml /m2 /zn /q /dPMWV=33 pmwca
  ;;
esac
"$kvikdos" "$tlink_exe" /3 /x pmodewe  pmodewk ,pmodewu.exe
"$kvikdos" "$tlink_exe" /3 /x pmodewev pmodewkv,pmodewv.exe
"$kvikdos" "$tlink_exe" /t /x pmwca

rm -f pmodewc.exe
"$kvikdos" pmwca.com pmodewu.exe pmodewc.exe  # Compress and add pmodew_config.
test "$(sha256sum pmodewc.exe)" = "5a2a94207e0830efd835048d81b562097d77267e4b5e8afe4136ad2c8f667764  pmodewc.exe"  # Same as of pmodew133.exe (PMODEW.EXE in the official pmw133.zip on 1997-01-01).

# Now pmodewv.exe is already ready to be used as a stub by OpenWatcom:
#
#   owcc -bpmodew -Wl,op -Wl,stub=pmodewv.exe -s -Os -fno-stack-check -march=i386 -W -Wall -o hdxc.exe hdx.c
#   wcl386 -l=pmodew -'"op"' -'"stub=pmodewv.exe"' -os -s -W -w4 -3r -fo=.o -fr -q -fe=hdxc.exe hdx.c

# We don't check the checksum, because DOS .exe headers depend on the TLINK
# version. Processing the output with execons.c would make it consistent.
#test "$(sha256sum pmodewv.exe)" = "4890ffd8fcf52b24bb91eb9896464a366851ac74849031288ecef935a767a7f1  pmodewv.exe"

# No need to make the output consistent (i.e. bitwise identical) across TASM
# (and TLINK) versions, because pmwc.c below would make its output
# consistent anyway.
if false; then
  rm -f pmodewu.exe
  if true; then
    test "$WATCOM"
    test -f "$WATCOM/lh/stdio.h"
    export INCLUDE="$WATCOM/lh"  # For OpenWatcom.
    owcc -blinux -Os -s -fno-stack-check -march=i386 -W -Wall -o execons execons.c
    unset INCLUDE
    ./execons pmodewu.exe
  elif false; then
    gcc -W -Wall -s -O2 -o execons execons.c
    ./execons pmodewu.exe
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
    "$kvikdos" execons.exe pmodewu.exe
  elif false; then
    rm -f execons.exe
    test "$WATCOM"
    test -f "$WATCOM/h/stdio.h"
    export INCLUDE="$WATCOM/h"  # For OpenWatcom.
    owcc -bdos -Os -s -fno-stack-check -march=i086 -W -Wall -o execons.exe execons.c
    unset INCLUDE
    "$kvikdos" execons.exe pmodewu.exe
  elif false; then
    minicc -o execons execons.c
    ./execons pmodewu.exe
  else
    : '! Missing compiler for execons.c' >&2
    false
  fi

  #cmp ../pmodewu.exe pmodewu.exe
  test "$(sha256sum pmodewu.exe)" = "8f8dfc58a6b4936b872cf81498ef98326f5e38d666fa0c3574b6757b53fe7119  pmodewu.exe"  # /dPMWV=1.33.
  #test "$(sha256sum pmodewu.exe)" = "d4271dc2162922c78fa5c6b94a360ca0fa4852c95a7f18c54e03177d96c18e1f  pmodewu.exe" # /dPMWV=1.34.
fi

rm -f pmodewc.exe
if false; then
  minicc -DPMWV=33 -o pmwc pmwc.c
  ./pmwc pmodewu.exe pmodewc.exe
elif false; then
  gcc -g -O2 -g -W -Wall -DPMWV=33 -o pmwc pmwc.c
  valgrind ./pmwc pmodewu.exe pmodewc.exe
elif true; then
  test "$WATCOM"
  test -f "$WATCOM/lh/stdio.h"
  export INCLUDE="$WATCOM/lh"  # For OpenWatcom.
  owcc -blinux -Os -s -fno-stack-check -march=i386 -W -Wall -DPMWV=33 -o pmwc pmwc.c
  unset INCLUDE
  ./pmwc pmodewu.exe pmodewc.exe
elif true; then
  test "$WATCOM"
  test -f "$WATCOM/h/stdio.h"
  export INCLUDE="$WATCOM/h"  # For OpenWatcom.
  owcc -bdos -mcmodel=c -Os -s -fno-stack-check -march=i086 -W -Wall -DPMWV=33 -o pmwc.exe pmwc.c
  unset INCLUDE
  "$kvikdos" pmwc.exe pmodewu.exe pmodewc.exe
fi
#test "$(sha256sum pmodewc.exe)" = "2c453d800d04413c5798c3428b55fb4c71d6987027acc876aef2bdd9c5d865a8  pmodewc.exe"  # Same as of pmodew133r.exe.   For -DCOMPRESS_BITS=16 -DCOMPRESS_BITREV=1 -DCOMPRESS_M1BITFIRST=0 -DCOMPRESS_EARLYNEXTBLOCK=0 -DCOMPRESS_LONGDIST=0 .
#test "$(sha256sum pmodewc.exe)" = "3868bdb478ec59ea75bde9eeb87b0cb9615a6f368419519df085f1a53ea2cc56  pmodewc.exe"  # Same as of pmodew133rr.exe.  For -DCOMPRESS_BITS=16 -DCOMPRESS_BITREV=1 -DCOMPRESS_M1BITFIRST=1 -DCOMPRESS_EARLYNEXTBLOCK=0 -DCOMPRESS_LONGDIST=0 .
#test "$(sha256sum pmodewc.exe)" = "1b90ffce71198f5a39238afce205c8fcc3b2da383ac85cf08123f4c3fbc8e6b5  pmodewc.exe"  # Same as of pmodew133rrr.exe. For -DCOMPRESS_BITS=16 -DCOMPRESS_BITREV=1 -DCOMPRESS_M1BITFIRST=1 -DCOMPRESS_EARLYNEXTBLOCK=1 -DCOMPRESS_LONGDIST=0 .
test "$(sha256sum pmodewc.exe)" = "5a2a94207e0830efd835048d81b562097d77267e4b5e8afe4136ad2c8f667764  pmodewc.exe"  # Same as of pmodew133.exe (PMODEW.EXE in the official pmw133.zip on 1997-01-01). For -DCOMPRESS_BITS=16 -DCOMPRESS_BITREV=1 -DCOMPRESS_M1BITFIRST=1 -DCOMPRESS_EARLYNEXTBLOCK=1 -DCOMPRESS_LONGDIST=1 .

if true; then  # No need for debugging.
  nasm-0.98.39 -O0 -w+orphan-labels -DPMWV -DCEXEFN="'pmodewc.exe'" -DHUEXEFN="'pmodewu.exe'" -o dec.com dec.nasm
  "$kvikdos" dec.com >pmodew.uprog.exe
  cmp pmodew.uprog.exe pmodewu.exe
else  # Debugging.
  test "$WATCOM"
  test -f "$WATCOM/lh/stdio.h"
  export INCLUDE="$WATCOM/lh"  # For OpenWatcom.
  owcc -blinux -Os -s -fno-stack-check -march=i386 -W -Wall -DPMWV=33 -DDEBUG -o pmwc pmwc.c
  unset INCLUDE
  ./pmwc pmodewu.exe pmodewc.exe >pmodewc.log

  nasm-0.98.39 -O0 -w+orphan-labels -DPMWV -DCEXEFN="'pmodewc.exe'" -DDEBUG -o dec.com dec.nasm
  "$kvikdos" dec.com >dec.log  # This is slow, it takes a few seconds.
  <pmodewc.log grep '^[LDE]' >pmodewc.lde.log
  <dec.log grep '^[LDE]' >dec.lde.log
  diff pmodewc.lde.log dec.lde.log

  if test -f pmodew133.exe; then
    nasm-0.98.39 -O0 -w+orphan-labels -DPMWV -DCEXEFN="'pmodew133.exe'" -DDEBUG -o deco133.com dec.nasm
    "$kvikdos" deco133.com >deco133.log  # This is slow, it takes a few seconds.
    <deco133.log grep '^[LDE]' >deco133.lde.log
    <deco133.log grep '^[LE]' >deco133.le.log
    <dec.log grep '^[LE]' >dec.le.log
    <pmodewc.log grep '^[LdDE]' >pmodewc.ldde.log
  fi

  perl -we 'use integer; use strict;
      die("fatal: open A: $ARGV[0]\n") if !open(A, "< $ARGV[0]");
      die("fatal: open B: $ARGV[1]\n") if !open(B, "< $ARGV[1]");
      my $lb;
      my $bigc = 0; my $nonbigc = 0; my $last_length = "0000";
      while (defined($lb = <B>)) {
        if ($lb =~ s@^d,(?=[^,\r\n])@@) {
          chomp($lb);
          my @hex_distances = split(/,/, $lb);
          my $length = hex($last_length);
          die("fatal: missing E before D\n") if !$length;
          die("fatal: bad length\n") if $length < 2;
          my $min_distance = hex($hex_distances[-1]);  # Smallest.
          my $max_distance_limit = ($length == 2) ? (($min_distance <= 0xfe) ? 0xfe : 0xffff) : (($min_distance <= 0xff) ? 0xff : ($min_distance <= 0x3ff) ? 0x3ff : 0xffff);
          my @limited_hex_distances = grep { hex($_) <= $max_distance_limit } @hex_distances;
          die("fatal: unexpected EOF in B after d\n") if !defined($lb = <B>);
          die("fatal: expected D in B after d\n") if $lb !~ m@^D@;
          my $la = <A>;
          die("fatal: unexpected EOF in A after D in b\n") if !defined($la);
          die("fatal: expected D in A after d in B\n") if $la !~ s@^D@@;
          chomp($la);
          if ($la eq $limited_hex_distances[0]) {
            ++$bigc;
          } else {
            ++$nonbigc;
            print("$la -- @limited_hex_distances -- $last_length\n");
          }
        } else {
          $last_length = $1 if $lb =~ m@^E(.*)@;
          my $la = <A>;
          die("fatal: unexpected EOF in A\n") if !defined($la);
          chomp($la), chomp($lb), die("fatal: mismatch in A and B: ($la) vs ($lb)\n") if $la ne $lb;
        }
      }
      { my $la; die("fatal: missing EOF in A\n") if defined($la = <A>); }
      print(STDERR "info: bigc=$bigc nonbigc=$nonbigc\n");
      ' deco133.lde.log pmodewc.ldde.log
fi

: "$0" OK.
