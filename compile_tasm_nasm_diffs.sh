#! /bin/sh --
#
# compile_tasm_nasm_diffs.sh: compile with both TASM and NASM in many different configs, check bytewise identical output
# by pts@fazekas.hu at Thu Jun 19 10:36:29 CEST 2025
#

set -ex
unset LANG LANGUAGE  # For reproducible builds.
export LC_ALL=C  # For reproducible builds.
export TZ=GMT  # For reproducible builds.
test "$ZSH_VERSION" && set -y 2>/dev/null  # SH_WORD_SPLIT for zsh(1). It's an invalid option in bash(1), and it's harmful (prevents echo) in ash(1).

test "$0" = "${0%/*}" || cd "${0%/*}"

nasm="${3:-tools/nasm-0.98.39.upx}"  # Supported here: NASM 0.98.39--2.13.02--2.16.03--
#nasm=nasm
#nasm=./nasm-2.16.03

tasm_exe="${1:-tasm20.exe}"  # Supported here: TASM 2.0--4.1 except for TASM 3.0 and TASM 3.1. TASM 5.0-- produces 2 relocations in the wrong order.
#tasm_exe=tasm201.exe
#tasm_exe=tasm202.exe
#tasm_exe=tasm202u.exe
#tasm_exe=tasm25.exe
#tasm_exe=tasm251.exe
#tasm_exe=tasmv32.exe
#tasm_exe=tasmv32i.exe
#tasm_exe=tasm40.exe
#tasm_exe=tasm41.exe

tlink_exe="${2:-tlink30.exe}"  # Supported here: TLINK 3.0--4.01. Other versions produce different values in the DOS .exe header.
#tlink_exe=tlink301.exe
#tlink_exe=tlink40.exe
#tlink_exe=tlink401.exe

kvikdos=tools/kvikdos-v1

case "$tasm_exe" in tasm[12.]*) znflag= ;; *) znflag=/zn ;; esac  # TASM 1.x and 2.x don't support the /zn flag (no debug info).

check() {
  local nasmdflag="-D$1" tasmdflag="/d$1"
  if test -z "$1"; then nasmdflag=; tasmdflag=; fi
  "$nasm" -O32700 -w+orphan-labels $nasmdflag -o pmodewnd.exe pmodew.nasm
  "$kvikdos" "$tasm_exe" /t /ml /m2 $znflag /q $tasmdflag pmodewe,pmodewed
  "$kvikdos" "$tasm_exe" /t /ml /m2 $znflag /q $tasmdflag pmodewk,pmodewkd
  "$kvikdos" "$tlink_exe" /3 /x pmodewed pmodewkd,pmodewtd.exe
  # Some variants need sorting of relocations: a few of them are in the wrong order. Oddly, the TLINK output for original is in good order.
  ! test "$1" || ./execons pmodewtd.exe
  if ! cmp pmodewtd.exe pmodewnd.exe; then
    ndisasm -b 16 -k 0,0x592 -k 0x23c0,0x38b pmodewnd.exe >pmodewnd.ndisasm
    ndisasm -b 16 -k 0,0x592 -k 0x23c0,0x38b pmodewtd.exe >pmodewtd.ndisasm
    diff -u pmodewtd.ndisasm pmodewnd.ndisasm >t.diff
    cmp -l pmodewtd.exe pmodewnd.exe  # Will fail.
  fi
}

check  # defaults="PMWV=33 UNC=0 DEBUG=0 PMW1UNCOMP=0 LOADLE=1 LOADPMW1=1 EXCEPTIONS=1 INT3108FUNC=1 INT1B=1 INT33=1 OPENTYPE=1 VARTYPE=1"
gcc -W -Wall -s -O2 -o execons execons.c
for PMWV in 33 34; do check "PMWV=$PMWV"; done
for UNC in 0 1; do check "UNC=$UNC"; done
#for DEBUG in 0 1; do check "DEBUG=$DEBUG"; done  # DEBUG=1 is not implemented, because the file debug.inc is missing.
for PMW1UNCOMP in 0 1; do check "PMW1UNCOMP=$PMW1UNCOMP"; done  # !! Bad relocation order?? with PMW1UNCOMP
for LOADLE in 1 0; do check "LOADLE=$LOADLE"; done
for LOADPMW1 in 1 0; do check "LOADPMW1=$LOADPMW1"; done
for EXCEPTIONS in 1 0; do check "EXCEPTIONS=$EXCEPTIONS"; done
for INT3108FUNC in 1 0; do check "INT3108FUNC=$INT3108FUNC"; done
for INT1B in 1 0; do check "INT1B=$INT1B"; done
for INT33 in 1 0; do check "INT33=$INT33"; done
for OPENTYPE in 1 2 3; do check "OPENTYPE=$OPENTYPE"; done
for VARTYPE in 1 2; do check "VARTYPE=$VARTYPE"; done

: "$0" OK.
