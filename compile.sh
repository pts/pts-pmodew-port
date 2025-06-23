#! /bin/sh --
# by pts@fazekas.hu at Thu Jun 12 11:50:15 CEST 2025
set -e
unset LANG LANGUAGE INC LIB LIBDIR WLINK_LNK INCLUDE
export LC_ALL=C  # For reproducible builds.
export TZ=GMT  # For reproducible builds.
test "$ZSH_VERSION" && set -y 2>/dev/null  # SH_WORD_SPLIT for zsh(1). It's an invalid option in bash(1), and it's harmful (prevents echo) in ash(1).

test "$0" = "${0%/*}" || cd "${0%/*}"

# Tested and found working: TASM 2.0, 2.01, 2.02, 2.5, 2.51, 3.0, 3.1, 3.2i, 3.2, 4.1, 5.0, 5.2, 5.3.
# It's not working with TASM 1.0 and 1.01: they don't have the /m2 command-line flag (for optimization).
# It's not working with TASM 3.0 and 3.1 in kvikdos, they fail with `int 0x03' in kvikdos.
asm_prog=tasm20.exe
# Tested and found working: TLINK 2.0, 3.0, 3.01, 4.0, 4.01.
# It's not working with WLINK in OpenWatcom 2.0 2023-03-04, it generates incorrect relocations.
tlink_exe=tlink20.exe
emudos=tools/kvikdos-v1
emudosflags=
nasm=tools/nasm-0.98.39.upx
pmwv=33
is_dd=
is_reproducible=1
do_consfix=
is_emu2=
is_explicit_kvikdos=
#is_nasm=  # Unconditionally overwritten below.
is_dnx=
compressor=asm

for arg in "$@"; do
  case "$arg" in --*) ;; -*) arg="-$arg" ;; *) arg="--$arg" ;; esac  # Make leading dashes optionol.
  case "$arg" in
   --asm=* | --asm-prog=*) asm_prog="${arg#*=}" ;;  # Assembler program command name. TASM or NASM.
   --tasm=*) echo "fatal: please use --asm=... instead of --tasm=..." >&2; exit 1 ;;  # To avoid confusion with --tasm20.exe.
   --tasm* | --t32*) asm_prog="${arg#--}" ;;
   --tlink=*) tlink_exe="${arg#*=}" ;;  # Unused and ignored if NASM is used.
   --tlink*.exe) tlink_exe="${arg#--}" ;;
   --nasm=*) nasm="${arg#*=}" ;;  # For --dd. Ignored if a NASM command is specified in --asm=... .
   --kvikdos=*) emudos="${arg#*=}"; is_emu2=; is_explicit_kvikdos=1; emudosflags=; is_dnx= ;;
   --kvikdos) emudos=tools/kvikdos-v1; is_emu2=; is_explicit_kvikdos=1; emudosflags=; is_dnx= ;;
   --emu2=*) emudos="${arg#*=}"; is_emu2=1; is_explicit_kvikdos=; emudosflags=; is_dnx= ;;
   --emu2) emudos=tools/emu2-lc-2021.01; is_emu2=1; is_explicit_kvikdos=; emudosflags=; is_dnx= ;;
   --dosbox | --dnx) emudos=dosbox.nox.static; is_emu2=; is_explicit_kvikdos=; emudosflags=--cmd; is_dnx=1 ;;
   --33 | --v33) pmwv=33 ;;
   --34 | --v34) pmwv=34 ;;
   --version=1.*) pmwv="${arg#*.}" ;;
   --dd | --decompress-debug | --debug-decompress) is_dd=1 ;;  # Enable decompression debugging. Slow.
   --co | --ro | --consistent | --reproducible) is_reproducible=1 ;;  # Enable reproducible output (i.e. consistent across NASM, TASM and TLINK versions) for for pmodewu.exe and pmodewv.exe. (pmodew.exe is always reproducible.)
   --no-co | --no-ro | --no-consistent | --no-reproducible) is_reproducible= ;;  # Disable reproducible output. Faster.
   --force-consfix | --force-execons) do_consfix=1 ;;  # Force running execons.c, even if not needed by --reproducible.
   --compressor[-=]c | --compressor[-=]minicc) compressor=minicc ;;  # Linux i386 ./pmwc compiled by minicc.
   --compressor[-=]gcc) compressor=gcc ;;  # Linux i386 ./pmwc compiled by https://github.com/pts/minilibc686 minicc.
   --compressor[-=]owcc-linux) compressor=owcc-linux ;;  # Linux i386 ./pmwc compiled by OpenWatcom owcc.
   --compressor[-=]turboc) compressor=turboc ;;  # DOS pmwc.exe compiled by Borland Turbo C++.
   --compressor[-=]owcc-dos) compressor=owcc-dos ;;  # DOS pmwc.exe compiled by OpenWatcom owcc.
   --compressor[-=]asm) compressor=asm ;;  #  DOS pmwca.com compiled with TASM .
   --compressor[-=]nasm16) compressor=nasm16 ;;  # DOS pmwca.com compiled with NASM.
   --compressor[-=]nasm32) compressor=nasm32 ;;  # Linux i386 ./pmwca compiled with NASM.
   --compressor[-=]win32 | --compressor[-=]nasmwin32) compressor=win32 ;;  # Win32 pmwca.exe compiled with NASM.
   *) echo "fatal: unknown command-line flag: $arg" >&2; exit 1 ;;
  esac
done
case "$asm_prog" in nasm* | */nasm*) is_nasm=1 ;; *) is_nasm= ;; esac
if test "$is_nasm"; then is_reproducible=1; nasm="$asm_prog"; fi
if test "$is_nasm" && test "$compressor" = asm; then compressor=nasm32; fi

rm -f pmwc.exe pmwca.com pmwca pmwca.exe pmwc.o pmwc.obj pmwca.o pmwca.obj pmwca2.com pmwca2
if test "$compressor" = nasm16; then
  compressor=pmwca.com
  set -x  # Echo all commands run.
  "$nasm" -O0 -w+orphan-labels -DPMWV="$pmwv" -o "$compressor" pmwca.nasm
  set +x
elif test "$compressor" = nasm32; then
  compressor=pmwca
  set -x  # Echo all commands run.
  "$nasm" -O0 -w+orphan-labels -DPMWV="$pmwv" -o "$compressor" pmwcax.nasm
  chmod +x "$compressor"
  set +x
elif test "$compressor" = win32; then
  compressor=pmwca.exe
  set -x  # Echo all commands run.
  "$nasm" -O0 -w+orphan-labels -DPMWV="$pmwv" -f obj -DOS_WIN32 -o pmwca.obj pmwcax.nasm
  wlink op q op start=_start op noext op nou op nored op d form win nt ru con=3.10 op h=4K com h=0 op st=1024K com st=4K f pmwca.obj n "pmwca.exe"  # !!! Generate pmwca.exe with `nasm -f bin', without wlink(1).
  set +x
elif test "$compressor" = asm; then
  :  # pmwca.com will be built by TASM + TLINK below.
elif test "$compressor" = minicc; then
  compressor=pmwc
  set -x  # Echo all commands run.
  minicc -DPMWV="$pmwv" -o "$compressor" pmwc.c
  set +x
elif test "$compressor" = gcc; then
  compressor=pmwc
  set -x  # Echo all commands run.
  gcc -s -O2 -ansi -pedantic -W -Wall -DPMWV="$pmwv" -o "$compressor" pmwc.c
  #gcc -O2 -ansi -pedantic -W -Wall -DPMWV="$pmwv" -o pmwc pmwc.c
  # !! valgrind ./pmwc pmodewu.exe pmodew.exe  # Works and it is faster without valgrind.
  set +x
elif test "$compressor" = owcc-linux; then
  compressor=pmwc
  set -x  # Echo all commands run.
  test "$WATCOM"
  test -f "$WATCOM/lh/stdio.h"
  export INCLUDE="$WATCOM/lh"  # For OpenWatcom.
  rm -f pmwc
  owcc -blinux -Os -s -fno-stack-check -march=i386 -W -Wall -DPMWV="$pmwv" -o "$compressor" pmwc.c
  set +x
  unset INCLUDE
elif test "$compressor" = turboc; then
  compressor=pmwc.exe
  set -x
  # Output file pmwc.exe is implicity derived from the .c source file nam,
  # it cannot be specified on the tcc.exe command line.
  #
  # With -f (or by default), emu.lib and maths.lib are also required for x87
  # emulation. With -f87, x86.lib and maths.lib are required instead. With
  # -f-, no emu.lib or math*.lib is required.
  #
  # !! What is the minimum set of files needed for compiling with Turbo C++ 1.01 (free)? tcc.exe tlink.exe cs.lib c0s.obj tcch/fcntl.h tcch/io.h tcch/stdarg.h tcch/stdio.h tcch/stdlib.h tcch/string.h .
  "$emudos" $emudosflags tcc.exe -ms -Itcch -f- -DPMWV="$pmwv" pmwc.c
  set +x
elif test "$compressor" = owcc-dos; then
  compressor=pmwc.exe
  set -x  # Echo all commands run.
  test "$WATCOM"
  test -f "$WATCOM/h/stdio.h"
  export INCLUDE="$WATCOM/h"  # For OpenWatcom.
  owcc -bdos -mcmodel=s -std=c89 -Os -s -fno-stack-check -march=i086 -W -Wall -DPMWV="$pmwv" -o "$compressor" pmwc.c
  set +x
  unset INCLUDE
else
  echo "fatal: unsupported compressor to build: $compressor" >&2
  exit 2
fi
rm -f pmwc.obj pmwc.o

if test "$is_nasm"; then
  set -x  # Echo all commands run.
  # -O32767 instead of -O999999999 for compatibility with 16-bit NASM 0.98.39.
  # This NASM invocation is one of the slowest compilation steps (!).
  "$nasm" -O32700 -w+orphan-labels -DPMWV="$pmwv" -o pmodewu.exe pmodew.nasm
  "$nasm" -O32700 -w+orphan-labels -DPMWV="$pmwv" -DUNC=1 -o pmodewv.exe pmodew.nasm
else
  if ! test "${asm_prog#tasm30*.exe}" && ! test "$is_emu2"; then
    # TASM 3.0 produces `int 3' in kvikdos. Without --mem-mb=2, TASM
    # 3.0 would just hang in --dnx. Solution: we run it in emu2 instead
    # of kvikdos.
    if test "$is_explicit_kvikdos"; then echo "fatal: can't run TASM 3.0 or 3.1 in kvikdos, please omit --kvikdos* to use emu2 instead for them" >&2; exit 1; fi
    if test "$is_dnx"; then
      if test "$emudosflags" = --cmd; then emudosflags="$emudosflags --mem-mb=2"; fi
    else
      emudos=tools/emu2-lc-2021.01
    fi
  fi
  set -x  # Echo all commands run.
  case "$asm_prog" in
   t32*.exe | tasm32*.exe)
    test "$is_reproducible" && do_consfix=1  # If TASM is 5.0--, then we have to run execons.c for reproducible output. Without that 2 relocations would be in the wrong order.
    dosbox.nox.static --cmd --mem-mb=3 mwperun.exe "$asm_prog" /t /ml /m2 /zn /q /dPMWV="$pmwv" pmodewe
    dosbox.nox.static --cmd --mem-mb=3 mwperun.exe "$asm_prog" /t /ml /m2 /zn /q /dPMWV="$pmwv" pmodewk
    dosbox.nox.static --cmd --mem-mb=3 mwperun.exe "$asm_prog" /t /ml /m2 /zn /q /dPMWV="$pmwv" /dUNC=1 pmodewe,pmodewev
    dosbox.nox.static --cmd --mem-mb=3 mwperun.exe "$asm_prog" /t /ml /m2 /zn /q /dPMWV="$pmwv" /dUNC=1 pmodewk,pmodewkv
    ! test "$compressor" = asm || dosbox.nox.static --cmd --mem-mb=3 mwperun.exe "$asm_prog" /t /ml /m2 /zn /q /dPMWV="$pmwv" pmwca
    ;;
   tasm[12]*.exe | tasm.exe)  # The /zn flag (no debug info) has been introduced in TASM 3.0.
    "$emudos" $emudosflags "$asm_prog" /t /ml /m2 /q /dPMWV="$pmwv" pmodewe
    "$emudos" $emudosflags "$asm_prog" /t /ml /m2 /q /dPMWV="$pmwv" pmodewk
    "$emudos" $emudosflags "$asm_prog" /t /ml /m2 /q /dPMWV="$pmwv" /dUNC=1 pmodewe,pmodewev
    "$emudos" $emudosflags "$asm_prog" /t /ml /m2 /q /dPMWV="$pmwv" /dUNC=1 pmodewk,pmodewkv
    ! test "$compressor" = asm || "$emudos" $emudosflags "$asm_prog" /t /ml /m2 /q /dPMWV="$pmwv" pmwca  # Default input extension: .asm. Default output extension: .obj.
    ;;
   *.exe)
    "$emudos" $emudosflags "$asm_prog" /t /ml /m2 /zn /q /dPMWV="$pmwv" pmodewe
    "$emudos" $emudosflags "$asm_prog" /t /ml /m2 /zn /q /dPMWV="$pmwv" pmodewk
    "$emudos" $emudosflags "$asm_prog" /t /ml /m2 /zn /q /dPMWV="$pmwv" /dUNC=1 pmodewe,pmodewev
    "$emudos" $emudosflags "$asm_prog" /t /ml /m2 /zn /q /dPMWV="$pmwv" /dUNC=1 pmodewk,pmodewkv
    ! test "$compressor" = asm || "$emudos" $emudosflags "$asm_prog" /t /ml /m2 /zn /q /dPMWV="$pmwv" pmwca
    ;;
   *)
    if test "$asm_prog" = "${asm_prog#*/}"; then asm_prog="./$asm_prog"; fi
    "$asm_prog" /t /ml /m2 /zn /q /dPMWV="$pmwv" pmodewe
    "$asm_prog" /t /ml /m2 /zn /q /dPMWV="$pmwv" pmodewk
    "$asm_prog" /t /ml /m2 /zn /q /dPMWV="$pmwv" /dUNC=1 pmodewe,pmodewev
    "$asm_prog" /t /ml /m2 /zn /q /dPMWV="$pmwv" /dUNC=1 pmodewk,pmodewkv
    ! test "$compressor" = asm || "$asm_prog" /t /ml /m2 /zn /q /dPMWV="$pmwv" pmwca
    ;;
  esac
  case "$tlink_exe" in
   tlink[34]*) ;;
   *) test "$is_reproducible" && do_consfix=1 ;;  # If TLINK is not 3.0--4.01, then we have to run execons.c for reproducible output. Without that relocations would be in the wrong position and header values would be different.
  esac
  "$emudos" $emudosflags "$tlink_exe" /3 /x pmodewe  pmodewk ,pmodewu.exe
  "$emudos" $emudosflags "$tlink_exe" /3 /x pmodewev pmodewkv,pmodewv.exe
  if test "$compressor" = asm; then
    "$emudos" $emudosflags "$tlink_exe" /t /x pmwca
    compressor=pmwca.com
  fi
fi

# Now pmodewv.exe is already ready to be used as a stub by OpenWatcom:
#
#   owcc -bpmodew -Wl,op -Wl,stub=pmodewv.exe -s -Os -fno-stack-check -march=i386 -W -Wall -o hdxc.exe hdx.c
#   wcl386 -l=pmodew -'"op"' -'"stub=pmodewv.exe"' -os -s -W -w4 -3r -fo=.o -fr -q -fe=hdxc.exe hdx.c

# Do post-processing to make pmodevu.exe and pmodewe.exe
# consistent across TLINK versions. Apart from the SHA256 checksum
# calculations, there is no need to do it for pmodewu.exe, because pmwc.c
# and pmwca.com make the final pmodew.exe consistent anyway. Also there is
# no need to do it for NASM output, because that's consistent out of the box.

# In the past we've been using execons.c for post-processing, but now we use
# single-argument pmwcc.. Thus we don't even compile execons.c here, hence the
# `if false'.
if false; then
  if true; then
    test "$WATCOM"
    test -f "$WATCOM/lh/stdio.h"
    export INCLUDE="$WATCOM/lh"  # For OpenWatcom.
    owcc -blinux -Os -s -fno-stack-check -march=i386 -W -Wall -o execons execons.c
    unset INCLUDE
    ./execons pmodewu.exe
    ./execons pmodewv.exe
  elif false; then
    gcc -W -Wall -s -O2 -o execons execons.c
    ./execons pmodewu.exe
    ./execons pmodewv.exe
  elif false; then
    minicc -o execons execons.c
    ./execons pmodewu.exe
    ./execons pmodewv.exe
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
    "$emudos" $emudosflags tcc.exe -ms -Itcch -f87 execons.c  # !! What is the minimum set of files needed for compiling with Turbo C++ 1.01 (free)?
    "$emudos" $emudosflags execons.exe pmodewu.exe
    "$emudos" $emudosflags execons.exe pmodewv.exe
  elif false; then
    rm -f execons.exe
    test "$WATCOM"
    test -f "$WATCOM/h/stdio.h"
    export INCLUDE="$WATCOM/h"  # For OpenWatcom.
    owcc -bdos -Os -s -fno-stack-check -march=i086 -W -Wall -o execons.exe execons.c
    unset INCLUDE
    "$emudos" $emudosflags execons.exe pmodewu.exe
    "$emudos" $emudosflags execons.exe pmodewv.exe
  else
    : '! Missing compiler for execons.c' >&2
    false
  fi
fi

rm -f pmodew.exe
if test "$compressor" = pmwc; then
  ./pmwc pmodewu.exe pmodew.exe  # Compress and add pmodew_config.
  if test "$do_consfix"; then
    ./pmwc pmodewu.exe  # The compression (two-argument pmwc.c) below would work even without this here.
    ./pmwc pmodewv.exe
  fi
elif test "$compressor" = pmwc.exe; then
  "$emudos" $emudosflags pmwc.exe pmodewu.exe pmodew.exe  # Compress and add pmodew_config.
  if test "$do_consfix"; then
    "$emudos" $emudosflags pmwc.exe pmodewu.exe  # The compression (two-argument pmwc.c) below would work even without this here.
    "$emudos" $emudosflags pmwc.exe pmodewv.exe
  fi
elif test "$compressor" = pmwca.com; then
  "$emudos" $emudosflags pmwca.com pmodewu.exe pmodew.exe  # Compress and add pmodew_config.
  if test "$do_consfix"; then
    "$emudos" $emudosflags pmwca.com pmodewu.exe  # The compression (two-argument pmwc.c) below would work even without this here.
    "$emudos" $emudosflags pmwca.com pmodewv.exe
  fi
elif test "$compressor" = pmwca; then
  ./pmwca pmodewu.exe pmodew.exe  # Compress and add pmodew_config.
  if test "$do_consfix"; then
    ./pmwca pmodewu.exe  # The compression (two-argument pmwc.c) below would work even without this here.
    ./pmwca pmodewv.exe
  fi
elif test "$compressor" = pmwca.exe; then
  dosbox.nox.static --cmd --mem-mb=2 mwperun.exe pmwca.exe pmodewu.exe pmodew.exe
  if test "$do_consfix"; then
    dosbox.nox.static --cmd --mem-mb=2 mwperun.exe pmwca.exe pmodewu.exe  # The compression (two-argument pmwc.c) below would work even without this here.
    dosbox.nox.static --cmd --mem-mb=2 mwperun.exe pmwca.exe pmodewv.exe
  fi
else
  : "! unsupported compressor: $compressor" >&2
  false
fi

if test "$pmwv" = 33; then
  #test "$(sha256sum pmodew.exe)" = "2c453d800d04413c5798c3428b55fb4c71d6987027acc876aef2bdd9c5d865a8  pmodew.exe"  # Same as of pmodew133r.exe.   For -DCOMPRESS_BITS=16 -DCOMPRESS_BITREV=1 -DCOMPRESS_M1BITFIRST=0 -DCOMPRESS_EARLYNEXTBLOCK=0 -DCOMPRESS_LONGDIST=0 .
  #test "$(sha256sum pmodew.exe)" = "3868bdb478ec59ea75bde9eeb87b0cb9615a6f368419519df085f1a53ea2cc56  pmodew.exe"  # Same as of pmodew133rr.exe.  For -DCOMPRESS_BITS=16 -DCOMPRESS_BITREV=1 -DCOMPRESS_M1BITFIRST=1 -DCOMPRESS_EARLYNEXTBLOCK=0 -DCOMPRESS_LONGDIST=0 .
  #test "$(sha256sum pmodew.exe)" = "1b90ffce71198f5a39238afce205c8fcc3b2da383ac85cf08123f4c3fbc8e6b5  pmodew.exe"  # Same as of pmodew133rrr.exe. For -DCOMPRESS_BITS=16 -DCOMPRESS_BITREV=1 -DCOMPRESS_M1BITFIRST=1 -DCOMPRESS_EARLYNEXTBLOCK=1 -DCOMPRESS_LONGDIST=0 .
  test "$(sha256sum pmodew.exe)" = "5a2a94207e0830efd835048d81b562097d77267e4b5e8afe4136ad2c8f667764  pmodew.exe"  # Same as of pmodew133.exe (PMODEW.EXE in the official pmw133.zip on 1997-01-01).
else
  test "$(sha256sum pmodew.exe)" = "b6813ff1f052dbe69b968a427a1eeceefe434519ca4cc5ddd43c501ed214de47  pmodew.exe"  # For PMWV=34.
fi

if test "$is_reproducible"; then
  if test "$pmwv" = 33; then
    test "$(sha256sum pmodewu.exe)" = "debfc84a0278890a8676b49220b607decf4d7772da98cbe96b69ba4a294c6db0  pmodewu.exe"  # /dPMWV=33
    test "$(sha256sum pmodewv.exe)" = "f0acd20dca7f037ab04b262bb22a9ca7b34813ebeb57f2a9c9eafe2119eddb0d  pmodewv.exe"  # /dPMWV=33 /dUNC=1
  else
    test "$(sha256sum pmodewu.exe)" = "7bb0de82fb0ed9c5ba6ad6f8772764a3fb47bc925a0e1a4bd7b64b698ffefb7f  pmodewu.exe"  # /dPMWV=34
    test "$(sha256sum pmodewv.exe)" = "fe01d303904677238ec5af7014de08495657407546a69a4d143446778e14c2e9  pmodewv.exe"  # /dPMWV=34 /dUNC=1
  fi
fi

if true; then  # Double-check that alternative compressor implementations produce the same output.
  rm -f pmodew.exe pmwca2.com
  "$nasm" -O0 -w+orphan-labels -DPMWV="$pmwv" -o pmwca2.com pmwca.nasm
  "$emudos" $emudosflags pmwca2.com pmodewu.exe pmodew.exe  # Compress and add pmodew_config.
  if test "$pmwv" = 33; then
    test "$(sha256sum pmodew.exe)" = "5a2a94207e0830efd835048d81b562097d77267e4b5e8afe4136ad2c8f667764  pmodew.exe"  # Same as of pmodew133.exe (PMODEW.EXE in the official pmw133.zip on 1997-01-01).
  else
    test "$(sha256sum pmodew.exe)" = "b6813ff1f052dbe69b968a427a1eeceefe434519ca4cc5ddd43c501ed214de47  pmodew.exe"  # For PMWV=34.
  fi
  rm -f pmodew.exe pmwca2
  "$nasm" -O0 -w+orphan-labels -DPMWV="$pmwv" -o pmwca2 pmwcax.nasm
  chmod +x pmwca2
  ./pmwca2 pmodewu.exe pmodew.exe  # Compress and add pmodew_config.
  if test "$pmwv" = 33; then
    test "$(sha256sum pmodew.exe)" = "5a2a94207e0830efd835048d81b562097d77267e4b5e8afe4136ad2c8f667764  pmodew.exe"  # Same as of pmodew133.exe (PMODEW.EXE in the official pmw133.zip on 1997-01-01).
  else
    test "$(sha256sum pmodew.exe)" = "b6813ff1f052dbe69b968a427a1eeceefe434519ca4cc5ddd43c501ed214de47  pmodew.exe"  # For PMWV=34.
  fi
fi

if ! test "$is_dd"; then  # No decompression debugging, so just do a simple (non-debug) decompression check.
  "$nasm" -O0 -w+orphan-labels -DPMWV -DCEXEFN="'pmodew.exe'" -DHUEXEFN="'pmodewu.exe'" -o dec.com dec.nasm
  "$emudos" $emudosflags dec.com >pmodew.uprog.exe
  cmp pmodew.uprog.exe pmodewu.exe
else  # Decompression debugging.
  test "$WATCOM"
  test -f "$WATCOM/lh/stdio.h"
  export INCLUDE="$WATCOM/lh"  # For OpenWatcom.
  owcc -blinux -Os -s -fno-stack-check -march=i386 -W -Wall -DPMWV="$pmwv" -DDEBUG -o pmwc pmwc.c
  unset INCLUDE
  ./pmwc pmodewu.exe pmodew.exe >pmodewc.log

  "$nasm" -O0 -w+orphan-labels -DPMWV -DCEXEFN="'pmodew.exe'" -DDEBUG -o dec.com dec.nasm
  "$emudos" $emudosflags dec.com >dec.log  # This is slow, it takes a few seconds.
  <pmodewc.log grep '^[LDE]' >pmodewc.lde.log
  <dec.log grep '^[LDE]' >dec.lde.log
  diff pmodewc.lde.log dec.lde.log

  if test -f "pmodew1$pmwv.exe"; then
    "$nasm" -O0 -w+orphan-labels -DPMWV -DCEXEFN="'pmodew1$pmwv.exe'" -DDEBUG -o deco.com dec.nasm  # pmodew133.exe or pmodew134.com.
    "$emudos" $emudosflags deco.com >deco.log  # This is slow, it takes a few seconds.
    <deco.log grep '^[LDE]' >deco.lde.log
    <deco.log grep '^[LE]' >deco.le.log
    <dec.log grep '^[LE]' >dec.le.log
    <pmodewc.log grep '^[LdDE]' >pmodewc.ldde.log
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
        ' deco.lde.log pmodewc.ldde.log
  fi
fi

: "$0" OK.
