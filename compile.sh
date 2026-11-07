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

"$nasm" -O32700 -w+orphan-labels -DPMWV=33 -o pmodewu.exe pmodew.nasm
test "$(sha256sum pmodewu.exe)" = "debfc84a0278890a8676b49220b607decf4d7772da98cbe96b69ba4a294c6db0  pmodewu.exe"
"$nasm" -O32700 -w+orphan-labels -DPMWV=33 -DUNC=1 -o pmodewv.exe pmodew.nasm
test "$(sha256sum pmodewv.exe)" = "72f772ba75920d82aa3f9a4dafa486549be7a5f7bdba27d0c34521b588339dc2  pmodewv.exe"
"$nasm" -O0 -w+orphan-labels -DPMWV=33 -o pmwca pmwcax.nasm
chmod +x pmwca
./pmwca pmodewu.exe pmodew.exe  # This runs on Linux i386, Linux amd64 and FreeBSD i386.
test "$(sha256sum pmodew.exe )" = "5a2a94207e0830efd835048d81b562097d77267e4b5e8afe4136ad2c8f667764  pmodew.exe"

: "$0" OK.
