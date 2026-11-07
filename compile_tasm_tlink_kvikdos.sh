#! /bin/sh --
# by pts@fazekas.hu at Thu Jun 12 11:50:15 CEST 2025
set -e
unset LANG LANGUAGE
export LC_ALL=C  # For reproducible builds.
export TZ=GMT  # For reproducible builds.
test "$0" = "${0%/*}" || cd "${0%/*}"
set -x

tasmexe="${1:-tasm.exe}"
tlinkexe="${2:-tlink.exe}"
kvikdos="${3:-tools/kvikdos-v1.upx}"    # https://github.com/pts/kvikdos runs on Linux i386 and Linux amd64 with KVM enabled.
emu2="${4:-tools/emu2-lc-2021.01.upx}"  # https://github.com/dmsc/emu2 runs on Linux i386 and Linux amd64, but it's much slower than kvikdos. emu2 can be compiled from source to any Unix system.

emudos="$kvikdos"
"$emudos" --kvm-check >/dev/null 2>&1 || emudos="$emu2"
rm -f pmodewu.exe pmodewv.exe pmodew.exe pmwca.com

"$emudos" "$tasmexe" /t /ml /m2 /q /dPMWV=33 pmodewe
"$emudos" "$tasmexe" /t /ml /m2 /q /dPMWV=33 pmodewk
"$emudos" "$tlinkexe" /3 /x pmodewe pmodewk,pmodewu.exe
# Not checking, exect file contents depend on the version of tlink.exe:
#   test "$(sha256sum pmodewu.exe)" = "debfc84a0278890a8676b49220b607decf4d7772da98cbe96b69ba4a294c6db0  pmodewu.exe"
"$emudos" "$tasmexe" /t /ml /m2 /q /dPMWV=33 pmwca
"$emudos" "$tlinkexe" /t /x pmwca
"$emudos" pmwca.com pmodewu.exe pmodew.exe
test "$(sha256sum pmodew.exe )" = "5a2a94207e0830efd835048d81b562097d77267e4b5e8afe4136ad2c8f667764  pmodew.exe"

: "$0" OK.
