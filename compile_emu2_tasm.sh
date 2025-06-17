#! /bin/sh --
# by pts@fazekas.hu at Tue Jun 17 14:23:29 CEST 2025
set -e
unset LANG LANGUAGE
export LC_ALL=C  # For reproducible builds.
export TZ=GMT  # For reproducible builds.
test "$ZSH_VERSION" && set -y 2>/dev/null  # SH_WORD_SPLIT for zsh(1). It's an invalid option in bash(1), and it's harmful (prevents echo) in ash(1).

test "$0" = "${0%/*}" || cd "${0%/*}"

emu2="${2:-tools/emu2-lc-2021.01}"  # Works with EMU2 (tools/emu2-lc-2021.01), kvikdos (tools/kvikdos-v1) and dosbox-nox.
bat_file="${1-compile.bat}"

cr="$(printf '\r')"
if ! test "$cr"; then echo "fatal: could not produce CR" >&2; exit 2; fi
rm -f pmodew.exe
rm -f pmodewv.exe
cmdarg=
case "$emu2" in
 emu2-lc* | */emu2-lc*) echo lc ;;
 emu2* | */emu2*)
  rm -f pmodew.exe*   # Not needed for emu2-lc: When writing files, emu2 tries to find a longer filename, e.g. it finds pmodew.exe.foo for pmodew.exe.
  rm -f pmodewv.exe*  # Not needed for emu2-lc: When writing files, emu2 tries to find a longer filename.
  ;;
 dosbox[.-]nox* | */dosbox[.-]nox*) cmdarg=" --cmd" ;;
esac
echo "info: using DOS emulator: $emu2$cmdarg" >&2
exec <"$bat_file"  # Open it as stdin. Fail quickly if it doesn't exist.

# Poor man's DOS .bat executor.
# It prints all commands, and it stops at the first failure.
# !!! When writing files, emu2 tries to find a longer filename.
while read line; do  # Read next line from "$bat_file".
  line="${line%$cr}"
  line="$(echo $line)"  # Perform word splitting on whitespace.
  if test "$?" != 0; then echo "fatal: error parsing line: $line" >&2; exit 2; fi
  line="${line#\@}"
  test "$line" = exit && break
  case "$line" in
   "" | rem\ * | echo\ on | echo\ off) ;;
   echo\ *) echo "${line#* }" ;;
   -*) echo "fatal: command starts with dash: $line" >&2; exit 2 ;;  # Prevent unwanted command-line arguments to "$emu2".
   *) echo "dos: $line" >&2; "$emu2" $cmdarg $line </dev/null || exit "$?" ;;
  esac
done

set -x
if test -f pmodew.exe; then
  test "$(sha256sum pmodew.exe)" = "5a2a94207e0830efd835048d81b562097d77267e4b5e8afe4136ad2c8f667764  pmodew.exe"  # Same as of pmodew133.exe (PMODEW.EXE in the official pmw133.zip on 1997-01-01).
elif test -f pmodewv.exe; then
  # Don't do a $(sha256sum pmodewv.exe), because the .exe file depends on the version of TLINK used.
  :
else
  set +x
  echo "fatal: output file not found" >&2; exit 3
fi

: "$0" OK. >&2
