@echo on
@del pmodewu.exe
@del pmodewv.exe
@del pmodew.exe
@del pmwca.exe
nasm.exe -O32700 -w+orphan-labels -DPMWV=33 -o pmodewu.exe pmodew.nas
nasm.exe -O32700 -w+orphan-labels -DPMWV=33 -DUNC=1 -o pmodewv.exe pmodew.nas
nasm.exe -O0 -w+orphan-labels -DPMWV=33 -DOS_WIN32 -DFN83 -o pmwca.exe pmwcax.nas
pmwca.exe pmodewu.exe pmodew.exe
@exit
