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

nasm=tools/nasm-0.98.39.upx  # Supported here: NASM 0.98.39--2.13.02--2.16.03--
#nasm=nasm
#nasm=./nasm-2.16.03

tasm_exe=tasm20.exe  # Supported here: TASM 2.0--4.1 except for TASM 3.0 and TASM 3.1.
#tasm_exe=tasm201.exe
#tasm_exe=tasm202.exe
#tasm_exe=tasm202u.exe
#tasm_exe=tasm25.exe
#tasm_exe=tasm251.exe
#tasm_exe=tasmv32.exe
#tasm_exe=tasmv32i.exe
#tasm_exe=tasm40.exe
#tasm_exe=tasm41.exe

tlink_exe=tlink30.exe  # Supported here: TLINK 3.0--4.01.
#tlink_exe=tlink301.exe
#tlink_exe=tlink40.exe
#tlink_exe=tlink401.exe

kvikdos=tools/kvikdos-v1

case "$tasm_exe" in tasm2*) znflag= ;; *) znflag=/zn ;; esac

"$nasm" -O32700 -w+orphan-labels -DPMWV=33 -o pmodewnd.exe pmodew.nasm

"$kvikdos" "$tasm_exe" /t /ml /m2 $znflag /q /dPMWV=33 pmodewe,pmodewed
"$kvikdos" "$tasm_exe" /t /ml /m2 $znflag /q /dPMWV=33 pmodewk,pmodewkd
"$kvikdos" "$tlink_exe" /3 /x pmodewed pmodewkd,pmodewtd.exe

cmp pmodewtd.exe pmodewnd.exe

# !! Try these variations.
#for PMWV 33 34
#for UNC 0 1
#for DEBUG 0 1
#for PMW1UNCOMP 0 1
#for LOADLE 1 0
#for LOADPMW1 1 0
#for EXCEPTIONS 1 0
#for INT3108FUNC 1 0
#for INT1B 1 0
#for INT33 1 0
#for OPENTYPE 1 2 3
#for VARTYPE 1 2

: "$0" OK.
