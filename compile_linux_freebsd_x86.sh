#! /bin/sh --
#
# compile_linux_freebsd_x86.sh: build PMODE/W 1.33 on Linux i386 (or amd64) or FreeBSD i386
# by pts@fazekas.hu at Sun Jun 22 05:57:31 CEST 2025
#

set -ex
unset LANG LANGUAGE  # For reproducible builds.
export LC_ALL=C  # For reproducible builds.
export TZ=GMT  # For reproducible builds.
test "$ZSH_VERSION" && set -y 2>/dev/null  # SH_WORD_SPLIT for zsh(1). It's an invalid option in bash(1), and it's harmful (prevents echo) in ash(1).
test "$0" = "${0%/*}" || cd "${0%/*}"

tools/nasm-0.98.39.upx -O32700 -w+orphan-labels -DPMWV=33 -o pmodewu.exe pmodew.nasm
tools/nasm-0.98.39.upx -O32700 -w+orphan-labels -DPMWV=33 -DUNC=1 -o pmodewv.exe pmodew.nasm
tools/nasm-0.98.39.upx -O0 -w+orphan-labels -o pmwca pmwcax.nasm
chmod +x pmwca
./pmwca pmodewu.exe pmodew.exe

test "$1" || test "$(sha256sum pmodewv.exe)" = "f0acd20dca7f037ab04b262bb22a9ca7b34813ebeb57f2a9c9eafe2119eddb0d  pmodewv.exe"
test "$1" || test "$(sha256sum pmodewu.exe)" = "debfc84a0278890a8676b49220b607decf4d7772da98cbe96b69ba4a294c6db0  pmodewu.exe"

: "$0" OK.
