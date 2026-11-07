@rem Run this on DOS, Windows and OS/2 DOS window, all with long filename support.
@echo on
@del pmodewu.exe
@del pmodewv.exe
@del pmodew.exe
@del pmwca.exe
tools\nasm.exe -O32700 -w+orphan-labels -DPMWV=33 -o pmodewu.exe pmodew.nasm
@if errorlevel 1 goto done
tools\nasm.exe -O32700 -w+orphan-labels -DPMWV=33 -DUNC=1 -o pmodewv.exe pmodew.nasm
@if errorlevel 1 goto done
tools\nasm.exe -O0 -w+orphan-labels -DPMWV=33 -DOS_WIN32 -o pmwca.exe pmwcax.nasm
@if errorlevel 1 goto done
.\pmwca.exe pmodewu.exe pmodew.exe
@if errorlevel 1 goto done
@echo compile OK.
@goto :done

:done
@echo off