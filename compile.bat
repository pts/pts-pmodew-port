@echo on
tasm.exe /t /ml /m2 /q /dPMWV=33 pmodewe
tasm.exe /t /ml /m2 /q /dPMWV=33 pmodewk
tlink.exe /3 /x pmodewe  pmodewk ,pmodewu.exe
nasm.exe -O0 -w+orphan-labels -o pmwca.com pmwca.nas
pmwca.com pmodewu.exe pmodew.exe
@exit
