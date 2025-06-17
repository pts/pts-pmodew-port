@echo on
tasm.exe /t /ml /m2 /q /dPMWV=33 pmodewe
tasm.exe /t /ml /m2 /q /dPMWV=33 pmodewk
tlink.exe /3 /x pmodewe pmodewk,pmodewu.exe
tasm.exe /t /ml /m2 /q /dPMWV=33 pmwca
tlink.exe /t /x pmwca
pmwca.com pmodewu.exe pmodew.exe
@exit
