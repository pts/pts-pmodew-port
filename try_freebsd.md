# How to try pmwca in FreeBSD 9.3 in QEMU on a Linux x86 host

1. Run `./compile.sh --asm=tools/nasm-0.98.39.upx` on the host to generate *pmwca*, *pmodewu.exe* and *pmodew.exe*.

2. On the host, install QEMU (*qemu-system-i386*), *xz-utils* (or something similar which provides the *unxz* command) and *genisoimage* (or something similar which provides the *mkisofs* command).  For example, on Debian or Ubuntu, do so by running `sudo apt-get install qemu-system-x86 xz-utils genisoimage`.

3. Download the file
   [FreeBSD-9.3-RELEASE-i386-20140711-r268512.qcow2](http://ftp-archive.freebsd.org/pub/FreeBSD-Archive/old-releases/VM-IMAGES/9.3-RELEASE/i386/Latest/FreeBSD-9.3-RELEASE-i386-20140711-r268512.qcow2.xz)
   (2014-07-11) and move it to the pmodew directory (next to *pmwca*), and `cd` to this directory in a terminal window.

4. Run this on the host: `unxz FreeBSD-9.3-RELEASE-i386-20140711-r268512.qcow2.xz`

5. Run this on the host to generate *cd.iso*: `mkisofs -R -J -input-charset utf-8 -o freebsd.iso pmwca pmodewu.exe pmodew.exe`

6. Run this on the host (and keep it running): `qemu-system-i386 -net none -m 256M -machine pc-1.0 -hda FreeBSD-9.3-RELEASE-i386-20140711-r268512.qcow2 -cdrom cd.iso`

7. After running the commands above on the host, the black QEMU window appears.

8. In the black QEMU window, wait about 10 seconds for the big boot prompt, press <2> for *Boot Single User*.

9. Wait for the `Enter full pathname of shell...` prompt, just press <Enter>.

10. At the `#` prompt, type and run (by pressing *Enter*): `mount -u -w /`

11. At the `#` prompt, type and run: `mount_cd9660 /dev/cd0 /var/tmp`. Check that the command displays no output on screen. If it does, than the test has failed.

12. At the `#` prompt, type and run: `rm -f /tmp/pmodew.exe`

13. At the `#` prompt, type and run: `/var/tmp/pmwca /var/tmp/pmodewu.exe /tmp/pmodew.exe`. Check that the command displays no output on screen. If it does, than the test has failed.

14. At the `#` prompt, type and run: `cmp /var/tmp/pmodew.exe /tmp/pmodew.exe`. Check that the command displays no output on screen. If it does, than the test has failed.

15. At the `#` prompt, type and run: `halt`

16. Wait about 10 more seconds for the ``The operating system has halted.' message, and manually close the QEMU window.

All done.
