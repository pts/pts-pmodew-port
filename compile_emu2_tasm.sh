#! /bin/sh --
# by pts@fazekas.hu at Tue Jun 17 14:23:29 CEST 2025
set -e
unset LANG LANGUAGE
export LC_ALL=C  # For reproducible builds.
export TZ=GMT  # For reproducible builds.
test "$ZSH_VERSION" && set -y 2>/dev/null  # SH_WORD_SPLIT for zsh(1). It's an invalid option in bash(1), and it's harmful (prevents echo) in ash(1).

test "$0" = "${0%/*}" || cd "${0%/*}"

emu2="${2:-tools/emu2-2021.01}"
bat_file="${1-compile.bat}"

cr="$(printf '\r')"
if ! test "$cr"; then echo "fatal: could not produce CR" >&2; exit 2; fi
rm -f pmodew.exe
rm -f pmodew.exe*  # !!! When writing files, emu2 tries to find a longer filename.
rm -f pmodewv.exe
rm -f pmodewv.exe*  # !!! When writing files, emu2 tries to find a longer filename.
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
   *) echo "dos: $line" >&2; "$emu2" $line </dev/null || exit "$?" ;;
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
