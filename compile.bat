@rem Run this on DOS, 32-bit Windows and OS/2 DOS window.
@echo on
@del pmodewu.exe
@del pmodewv.exe
@del pmodew.exe
@del pmwca.com
tasm /t /ml /m2 /q /dPMWV=33 pmodewe
@if errorlevel 1 goto done
tasm /t /ml /m2 /q /dPMWV=33 pmodewk
@if errorlevel 1 goto done
tlink /3 /x pmodewe pmodewk,pmodewu.exe
@if errorlevel 1 goto done
tasm /t /ml /m2 /q /dPMWV=33 pmwca
@if errorlevel 1 goto done
tlink /t /x pmwca
@if errorlevel 1 goto done
.\pmwca.com pmodewu.exe pmodew.exe
@if errorlevel 1 goto done
@echo compile OK.
@goto :done

:done
@echo off