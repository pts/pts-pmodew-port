#! /bin/sh --
# by pts@fazekas.hu at Tue Jun 17 15:32:01 CEST 2025
set -ex
unset LANG LANGUAGE
export LC_ALL=C  # For reproducible builds.
export TZ=GMT  # For reproducible builds.
test "$ZSH_VERSION" && set -y 2>/dev/null  # SH_WORD_SPLIT for zsh(1). It's an invalid option in bash(1), and it's harmful (prevents echo) in ash(1).

test "$0" = "${0%/*}" || cd "${0%/*}"

test -f pcdos320.img
mtools -c mcopy -bsomp -i pcdos320.img -n ::IBMBIO.COM ./
mtools -c mcopy -bsomp -i pcdos320.img -n ::IBMDOS.COM ./
mtools -c mcopy -bsomp -i pcdos320.img -n ::COMMAND.COM ./
dd if=/dev/zero of=mydos.img bs=10240 count=120
mtools -c mformat -i mydos.img -f 1200 ::
dd if=pcdos320.img of=mydos.img bs=3 count=1 conv=notrunc,sync
dd if=pcdos320.img of=mydos.img bs=1 skip=44 seek=44 count=468 conv=notrunc,sync
mtools -c mcopy -bsomp -i mydos.img -n IBMBIO.COM ::
mtools -c mcopy -bsomp -i mydos.img -n IBMDOS.COM ::
mtools -c mcopy -bsomp -i mydos.img -n COMMAND.COM ::
printf 'ver\r\nrem run: compile , then o' >autoexec.bat
mtools -c mcopy -bsomp -i mydos.img -n autoexec.bat ::AUTOEXEC.BAT
rm -f autoexec.bat
mtools -c mcopy -bsomp -i mydos.img -n atxoff.com ::ATXOFF.COM
mtools -c mcopy -bsomp -i mydos.img -n atxoff.com ::O.COM

# Copy build tools to the disk image.
if test -f nasm.exe.upx; then
  mtools -c mcopy -bsomp -i mydos.img -n nasm.exe.upx ::NASM.EXE  # Optional.
fi
mtools -c mcopy -bsomp -i mydos.img -n tasm20.exe ::TASM.EXE
mtools -c mcopy -bsomp -i mydos.img -n tlink20.exe ::TLINK.EXE

# Copy source files and build script to the disk image.
mtools -c mcopy -bsomp -i mydos.img -n pmodewe.asm ::PMODEWE.ASM
mtools -c mcopy -bsomp -i mydos.img -n pmodewk.asm ::PMODEWK.ASM
mtools -c mcopy -bsomp -i mydos.img -n decode.asm ::DECODE.ASM
mtools -c mcopy -bsomp -i mydos.img -n pmwca.asm ::PMWCA.ASM
mtools -c mcopy -bsomp -i mydos.img -n compile.bat ::COMPILE.BAT
mtools -c mcopy -bsomp -i mydos.img -n compilev.bat ::COMPILEV.BAT

# Drop -enable-kvm if your QEMU doesn't support it or doesn't work with it.
qemu-system-i386 -enable-kvm -M pc-1.0 -m 1 -nodefaults -drive file=mydos.img,format=raw,if=floppy -boot a -debugcon stdio -vga cirrus

rm -f pmodew.exe
mtools -c mcopy -bsomp -i mydos.img -n ::pmodew.exe ./
test "$(sha256sum pmodew.exe)" = "5a2a94207e0830efd835048d81b562097d77267e4b5e8afe4136ad2c8f667764  pmodew.exe"  # Same as of pmodew133.exe (PMODEW.EXE in the official pmw133.zip on 1997-01-01).

: "$0" OK.
