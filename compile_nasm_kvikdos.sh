#! /bin/sh --
# by pts@fazekas.hu at Thu Jun 12 11:50:15 CEST 2025
set -e
unset LANG LANGUAGE
export LC_ALL=C  # For reproducible builds.
export TZ=GMT  # For reproducible builds.
test "$0" = "${0%/*}" || cd "${0%/*}"
set -x

nasmexe="${1:-tools/nasm.exe}"
kvikdos="${2:-tools/kvikdos-v1.upx}"    # https://github.com/pts/kvikdos runs on Linux i386 and Linux amd64 with KVM enabled.
emu2="${3:-tools/emu2-lc-2021.01.upx}"  # https://github.com/dmsc/emu2 runs on Linux i386 and Linux amd64, but it's much slower than kvikdos. emu2 can be compiled from source to any Unix system.

emudos="$kvikdos"
"$emudos" --kvm-check >/dev/null 2>&1 || emudos="$emu2"
for fn in flexpe.nas pmodew.nas pmwca.nas pmwcax.nas; do
  if ! test -f "$fn"; then
    ln -s "$fn"m "$fn"
    test -f "$fn"
  fi
done
rm -f pmodewu.exe pmodewv.exe pmodew.exe pmwca.com

"$emudos" "$nasmexe" -O32700 -w+orphan-labels -DPMWV=33 -o pmodewu.exe pmodew.nas
test "$(sha256sum pmodewu.exe)" = "debfc84a0278890a8676b49220b607decf4d7772da98cbe96b69ba4a294c6db0  pmodewu.exe"
"$emudos" "$nasmexe" -O32700 -w+orphan-labels -DPMWV=33 -DUNC=1 -o pmodewv.exe pmodew.nas
test "$(sha256sum pmodewv.exe)" = "72f772ba75920d82aa3f9a4dafa486549be7a5f7bdba27d0c34521b588339dc2  pmodewv.exe"
"$emudos" "$nasmexe" -O0 -w+orphan-labels -DPMWV=33 -o pmwca.com pmwca.nas
"$emudos" pmwca.com pmodewu.exe pmodew.exe
test "$(sha256sum pmodew.exe )" = "5a2a94207e0830efd835048d81b562097d77267e4b5e8afe4136ad2c8f667764  pmodew.exe"

: "$0" OK.
