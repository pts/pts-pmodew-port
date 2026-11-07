@rem Run this on DOS, Windows without long filename support and OS/2 DOS window.
@echo on
@del pmodewu.exe
@del pmodewv.exe
@del pmodew.exe
@del pmwca.exe
nasm.exe -O32700 -w+orphan-labels -DPMWV=33 -o pmodewu.exe pmodew.nas
@if errorlevel 1 goto done
nasm.exe -O32700 -w+orphan-labels -DPMWV=33 -DUNC=1 -o pmodewv.exe pmodew.nas
@if errorlevel 1 goto done
nasm.exe -O0 -w+orphan-labels -DPMWV=33 -DOS_WIN32 -DFN83 -o pmwca.exe pmwcax.nas
@if errorlevel 1 goto done
.\pmwca.exe pmodewu.exe pmodew.exe
@if errorlevel 1 goto done
@echo compile OK.
@goto :done

:done
@echo off