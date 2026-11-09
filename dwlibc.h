/*
 *
 * dwlibc.h: C header for libc to create combined DOS--Win32 .exe programs
 * by pts@fazekas.hu at Sun Nov  8 19:07:07 CET 2026
 *
 * Use the dwlibcc tool on Linux to build your programs using wdlibc. For
 * example, a hello-world C program:
 *
 *   #include <dwlibc.h>
 *   void print(const char *msg) { (void)!write(1, msg, strlen(msg)); }
 *   int main1(const char *cmdline) {
 *     (void)cmdline;
 *     print("Hello, World!\r\n");
 *     return 0;
 *   }
 *
 * Compile it with:
 *
 *   ./dwlibcc -bdos32 -s -Os -W -Wall -Wextra -o prog.exe prog.c
 *
 * dwlibc uses OpenWatcom v2 C compiler (wcc386) and frontend (owcc) and
 * custom modified PMODE/W 1.33 DOS extender as the DOS stub to make the
 * program run on DOS with a 80386 or later CPU.
 *
 * A slight change to make the source file portable to POSIX (and BSD) C:
 *
 *   #ifdef __DWLIBC__
 *   #  include <dwlibc.h>
 *   #else
 *   #  include <string.h>
 *   #  include <unistd.h>
 *   #endif
 *   void print(const char *msg) { (void)!write(1, msg, strlen(msg)); }
 *   int main1(const char *cmdline) {
 *     (void)cmdline;
 *     print("Hello, World!\r\n");
 *     return 0;
 *   }
 */
#ifndef _DWLIBC_H
#define _DWLIBC_H 1

#ifndef __WATCOMC__
#  error Need compiler __WATCOMC__.  /* https://open-watcom.github.io/ */
#endif
#ifdef __cplusplus
#  error Unexpected language C++ __cplusplus.
#endif
#ifndef __386__
#  error Need CPU __386__.
#endif
#ifdef __DOS__
#  ifdef __NT__
#    error Unexpected target both __DOS__ and __NT__.
#  endif
#else
#  ifndef __NT__
#    error Need target __DOS__ or __NT__.
#  endif
#endif
#ifdef __BEGIN__
#  error Unexpected target __BEGIN__.
#endif
#ifdef __OS2__
#  error Unexpected target __OS2__.
#endif
#ifdef __COM__
#  error Unexpected target __COM__.
#endif
#ifdef __LINUX__
#  error Unexpected target __LINUX__.
#endif
#ifdef _WCDATA  /* Defined in h/_comdef.h and lh/_comdef.h */
#  error Unexpected libc OpenWatcom _WCDATA.
#endif
#ifdef __GLIBC__
#  error Unexpected libc glibc __GLIBC__.
#endif
#ifdef __UCLIBC__
#  error Unexpected libc uClibc __UCLIBC__.
#endif
#ifdef __dietlibc__
#  error Unexpected libc diet libc __dietlibc__.
#endif
#ifdef __MINILIBC686__
#  error Unexpected libc minilibc686 __MINILIBC686__.
#endif

#ifdef __DWLIBC__
#  if (__DWLIBC__)!=1
#    error Unexpected value for __DWLIBC__.
#  endif
#  undef __DWLIBC__
#endif
#define __DWLIBC__ 1

/* --- Public macros, to be used in C files. */

typedef char int8_t;
typedef unsigned char uint8_t;
typedef short int16_t;
typedef unsigned short uint16_t;
typedef int int32_t;
typedef unsigned uint32_t;
typedef int ssize_t;
typedef unsigned size_t;
typedef int intptr_t;
typedef unsigned uintptr_t;
typedef long long int64_t;
typedef unsigned long long uint64_t;

typedef int off_t;

#define EXIT_SUCCESS 0
#define EXIT_FAILURE 1

#define STDIN_FILENO  0
#define STDOUT_FILENO 1
#define STDERR_FILENO 2

#define SEEK_SET 0
#define SEEK_CUR 1
#define SEEK_END 2

#ifdef __cplusplus
#  define NULL 0
#else
#  define NULL ((void*)0)
#endif

#define EOF -1  /* Indicates end-of-file (EOF) or error. */

/* --- Helper macros for function declarations. */

#ifdef __NT__
#  define __DWLIBCABI1 static __inline
#  define __DWLIBCABI2 /*__declspec(dllimport)*/
#else
#  define __DWLIBCABI1
#  define __DWLIBCABI2
#endif

/* --- Function declarations. */

/* The entire command-line is passed without leading whitespace. The
 * program has to split it to individual arguments. The program has to
 * implement it instead of main(...).
 */
int __watcall main1(const char *cmdline);

/* Only valid fd values are: STDIN_FILENO, STDOUT_FILENO, STDERR_FILENO. */
__DWLIBCABI1 ssize_t read(int fd, void *buf, size_t count);

/* Only valid fd values are: STDIN_FILENO, STDOUT_FILENO, STDERR_FILENO. */
__DWLIBCABI1 ssize_t write(int fd, const void *buf, size_t count);

/* Returns bool indicating whether fd is a terminal (interactive text
 * console).
 */
__DWLIBCABI1 int isatty(int fd);

__declspec(noreturn) void  exit(unsigned char exit_code);
__declspec(noreturn) void _exit(unsigned char exit_code);

int abs(int j);
long labs(long j);
unsigned _rotl(unsigned __value, unsigned __shift);
unsigned _rotr(unsigned __value, unsigned __shift);
unsigned long _lrotl(unsigned long __value, unsigned __shift);
unsigned long _lrotr(unsigned long __value, unsigned __shift);

void *memchr(const void *s, int c, size_t n);
int memcmp(const void *s1, const void *s2, size_t n);
void *memcpy(void *dest, const void *src, size_t n);
void *memset(void *s, int c, size_t n);
char *strcat(char *dest, const char *src);
char *strchr(const char *s, int c);
int strcmp(const char *s1, const char *s2);
char *strcpy(char *dest, const char *src);
size_t strlen(const char *s);

/* --- Implementation of the main0() API.
 *
 * Some programs define main0() instead of main(...), and use it like this:
 *
 * main0() {
 *   const char *argv1 = main0_argv1();
 *   if (main0_is_progarg_null(argv1)) main0_exit(4);
 *   if (argv1[0] == 'x') main0_exit(3);
 *   main0_exit0();
 * }
 */

#define main0() int main1(const char *__main0_cmdline)
#define main0_argv1() __main0_cmdline
#define main0_exit0() do { return 0; } while (0)
#define main0_exit(exit_code) _exit(exit_code)
#define main0_is_progarg_null(arg) 0  /* Size optimization, never NULL. */

/* --- Implementation of system-agnostic functions. */

/* To prevent wlink: Error! E2028: strlen_ is an undefined reference */
#pragma intrinsic(abs)
#pragma intrinsic(labs)
#pragma intrinsic(_rotl)
#pragma intrinsic(_rotr)
#pragma intrinsic(_lrotl)
#pragma intrinsic(_lrotr)
#pragma intrinsic(memchr)
#pragma intrinsic(memcmp)
#pragma intrinsic(memcpy)
#pragma intrinsic(memset)
#pragma intrinsic(strcat)
#pragma intrinsic(strchr)
#pragma intrinsic(strcmp)
#pragma intrinsic(strcpy)
#pragma intrinsic(strlen)  /* No error if function not available. */

/* --- Win32 implementation. */

#ifdef __NT__

/* TODO(pts): Hide these implementation details from the C program source. */

/*#include <windows.h>*/  /* Too much, also loads <ctype.h> etc. */

typedef unsigned long	ULONG;
typedef ULONG		*PULONG;
typedef unsigned short	USHORT;
typedef USHORT		*PUSHORT;
typedef unsigned char	UCHAR;
typedef UCHAR		*PUCHAR;
typedef char		*PSZ;
typedef unsigned long	DWORD;
typedef int		BOOL;
typedef unsigned char	BYTE;
typedef unsigned short	WORD;
typedef float		FLOAT;
typedef FLOAT		*PFLOAT;
typedef BOOL		*PBOOL;
typedef BOOL		*LPBOOL;
typedef BYTE		*PBYTE;
typedef BYTE		*LPBYTE;
typedef int		*PINT;
typedef int		*LPINT;
typedef WORD		*PWORD;
typedef WORD		*LPWORD;
typedef long		*LPLONG;
typedef DWORD		*PDWORD;
typedef DWORD		*LPDWORD;
typedef void		*LPVOID;
typedef const void	*LPCVOID;
typedef int		INT;
typedef unsigned int	UINT;
typedef unsigned int	*PUINT;
typedef void		*PVOID;
typedef void		*PVOID64;
typedef char		CHAR;
typedef short		SHORT;
typedef long		LONG;
typedef SHORT		*PSHORT;
typedef LONG		*PLONG;
typedef void		*HANDLE;
typedef HANDLE		*PHANDLE;
typedef BYTE		FCHAR;
typedef WORD		FSHORT;
typedef DWORD		FLONG;
typedef LONG		HRESULT;
typedef char		CCHAR;
typedef DWORD		LCID;
typedef PDWORD		PLCID;
typedef CHAR		*LPSTR;
typedef const CHAR	*LPCSTR;
typedef unsigned short	wchar_t;
typedef unsigned short	WCHAR;
typedef WCHAR		*LPWSTR;
typedef long		LONG_PTR;
typedef unsigned long	ULONG_PTR;
typedef ULONG_PTR	SIZE_T;

typedef struct _OVERLAPPED  *LPOVERLAPPED;
typedef struct _SECURITY_ATTRIBUTES *LPSECURITY_ATTRIBUTES;

/* kernel32.dll, <windows.h> */
__DWLIBCABI2 __declspec(noreturn) void __stdcall ExitProcess(
    UINT uExitCode);
__DWLIBCABI2 HANDLE __stdcall GetStdHandle(DWORD nStdHandle);
__DWLIBCABI2 BOOL   __stdcall WriteFile(
    HANDLE hFile, LPCVOID lpBuffer, DWORD nNumberOfBytesToWrite,
    LPDWORD lpNumberOfBytesWritten, LPOVERLAPPED lpOverlapped);
__DWLIBCABI2 BOOL   __stdcall ReadFile(
    HANDLE hFile, LPVOID lpBuffer, DWORD nNumberOfBytesToRead,
    LPDWORD lpNumberOfBytesRead, LPOVERLAPPED lpOverlapped);
__DWLIBCABI2 LPSTR  __stdcall GetCommandLineA(void);
__DWLIBCABI2 DWORD __stdcall GetFileType(HANDLE hFile);

/* nStdHandle for GetStdHandle(...): */
#define STD_INPUT_HANDLE    ((DWORD)-10)
#define STD_OUTPUT_HANDLE   ((DWORD)-11)
#define STD_ERROR_HANDLE    ((DWORD)-12)

#define INVALID_HANDLE_VALUE ((HANDLE)(LONG_PTR)-1)

#define FILE_TYPE_CHAR ((DWORD)2)

extern HANDLE __dwlibc_std_handles[3];

/* !! This included in the .o file even if unused, because of `call'. */
__DWLIBCABI1 ssize_t read(int fd, void *buf, size_t count) {
  DWORD read_count;
  return ReadFile(__dwlibc_std_handles[fd], buf, count, &read_count, NULL) ?
      read_count : -1;
}

__DWLIBCABI1 ssize_t write(
    int fd, const void *buf, size_t count) {
  DWORD written_count;
  return WriteFile(__dwlibc_std_handles[fd], buf, count, &written_count, NULL)
      ? written_count : -1;
}

/* Returns bool indicating whether fd is a terminal (interactive text
 * console).
 */
__DWLIBCABI1 int isatty(int fd) {
  return GetFileType(__dwlibc_std_handles[fd]) == FILE_TYPE_CHAR;
}

#pragma aux  exit = "movzx eax, al"  "push eax" "call ExitProcess" \
     __parm [__al] __modify __exact []
#pragma aux _exit = "movzx eax, al"  "push eax" "call ExitProcess" \
     __parm [__al] __modify __exact []

static __inline const char * __watcall __dwlibc_win32cmdline(
    const char *cmdline) {
  __dwlibc_std_handles[STDIN_FILENO ] = GetStdHandle(STD_INPUT_HANDLE );
  __dwlibc_std_handles[STDOUT_FILENO] = GetStdHandle(STD_OUTPUT_HANDLE);
  __dwlibc_std_handles[STDERR_FILENO] = GetStdHandle(STD_ERROR_HANDLE );
  if (*cmdline != ' ' && *cmdline != '\t') {  /* Skip program name. */
    if (*cmdline == '\"') {
      for (++cmdline; *cmdline != '\0' && *cmdline != '\"'; ++cmdline) {}
      if (*cmdline != '\0') ++cmdline;
    } else {
      for (; *cmdline != '\0' && *cmdline != ' ' || *cmdline == '\t';
           ++cmdline) {}
    }
  }
  for (; *cmdline == ' ' || *cmdline == '\t'; ++cmdline) {}
  return cmdline;
}

/* Actually, this defines the _dwlibcstart_ function. We do it using a macro
 * so that _dwlibcstart_ is only defined where the C source file defines
 * `int main1(const char *cmdline) { ... }'. The benefit is that the program
 * can be split to multiple C source files, and only one of them will define
 * _dwlibcstart_ and thus the `redefinition of _dwlibcstart_' error by wlink
 * is avoided. As a negative side effect of this hack, it is not possible to
 * reference main1 anywhere else in the source C file.
 *
 * This implements the 32-bit i386 program entry point Win32 jumps to. It
 * gets the standard file descriptor handles, it gets the command-line
 * string, calls main1(cmdline), and exits to Win32 with the return value of
 * main1(...) as the exit code. BSS is already zero-initialized.
 */
#define main1(argspec1) \
    /*int*/ __declspec(naked) __watcall _dwlibcstart(void) { \
    __asm { cld }  /* Shouldn't be needed. */ \
    __asm { call GetCommandLineA } \
    __asm { call __dwlibc_win32cmdline } \
    __asm { call main1 } \
    __asm { movzx eax, al } __asm { push eax } __asm { call ExitProcess } } \
    HANDLE __dwlibc_std_handles[3]; \
    int main1(argspec1)

#endif  /* #ifdef __NT__ */

/* --- DOS implementation. Mostly dark magic in OpenWatcom C. */

#ifdef __DOS__

/* According to https://catfox.life/2022/04/16/the-musl-preprocessor-debate/
 * , musl libc doesn't define a preprocessor macro to identify it. */

/* Magic incantation to emit a make wlink find a segment of class STACK, and
 * create a correct LE executable. As a side effect, it also silences the
 * wlink warning `Warning! W1014: stack segment not found'.
 *
 * Normally the segment name would be _STACK (rather than MYSTACK), but
 * wcc386 crashes with a Segmentation fault for that. wlink doesn't care
 * about the segment name.
 */
#pragma data_seg("MYSTACK", "STACK")
extern char __unused_stack1[1];
#pragma data_seg()

/* It must not modify `ebp', otherwise the OpenWatcom C compiler omits the
 * `pop ebp' between the `mov esp, ebp' and the `ret'.
 */
#pragma aux main1 __modify [__eax __ebx __ecx __edx __esi __edi]

static __inline const char * __watcall __dwlibc_doscmdline(char *cmdline) {
  cmdline[1 + *(unsigned char*)cmdline] = '\0';  /* Change CR to NUL. */
  for (++cmdline; *cmdline == ' ' || *cmdline == '\t'; ++cmdline) {}
  return cmdline;
}

/* Actually, this defines the _dwlibcstart_ function. We do it using a macro
 * so that _dwlibcstart_ is only defined where the C source file defines
 * `int main1(const char *cmdline) { ... }'. The benefit is that the program
 * can be split to multiple C source files, and only one of them will define
 * _dwlibcstart_ and thus the `redefinition of _dwlibcstart_' error by wlink
 * is avoided. As a negative side effect of this hack, it is not possible to
 * reference main1 anywhere else in the source C file.
 *
 * This implements the 32-bit i386 program entry point PMODE/W jumps to.
 * It gets the command-line string from PSP, calls main1(cmdline), and
 * exits to DOS with the return value of main1(...) as the exit code.
 # At entry, CS is a zero-based code selector, DS and SS are zero-based data
 * selectors. Either (ES == DS, and PSP is at DS:EAX) or (ES != DS, and PSP
 * is at ES:0). The latter is original PMODE/W behavior. BSS is already
 * zero-initialized.
 */
#define main1(argspec1) \
    /*int*/ __declspec(naked) __watcall _dwlibcstart(void) { \
    /* At LE startup, ES is the PSP selector. Get base from DPMI. */ \
    __asm { cld }  /* Shouldn't be needed. */ \
    __asm { mov ebx, es } __asm { mov edx, ds } __asm { cmp ebx, edx } \
    __asm { db 74h, 13 }  /* je skip */ \
    __asm { mov ax, 6 } __asm { int 31h } /* DPMI Get segment BX base. */ \
    __asm { xchg eax, ecx } __asm { shl eax, 16 } __asm { mov ax, dx } \
    __asm { skip: sub eax, -80h }  /* EAX := DOS cmdline. */ \
    __asm { push ds } __asm { pop es }  /* ES := zero-based segment. */ \
    __asm { call __dwlibc_doscmdline } \
    __asm { call main1 } __asm { mov ah, 4ch } __asm { int 21h } } \
    int main1(argspec1)

#pragma aux  exit = "mov ah, 4ch"  "int 21h"  __parm [__al] __modify __exact []
#pragma aux _exit = "mov ah, 4ch"  "int 21h"  __parm [__al] __modify __exact []

#pragma aux read = "mov ah, 3fh"  "int 21h"  "jnc ok"  "sbb eax, eax"  "ok:" \
    __value [__eax] __parm [__ebx] [__edx] [__ecx] __modify __exact [__eax]

#pragma aux write = "xor eax, eax"  "jecxz ok"  "mov ah, 40h"  "int 21h" \
    "jnc ok"  "sbb eax, eax"  "ok:"  \
    __value [__eax] __parm [__ebx] [__edx] [__ecx] __modify __exact [__eax]

/* Just returns whether fd is a character device. (On Unix, there are
 * non-TTY character devices, but this implementation pretends that they
 * don't exist.) It works correctly on
 * [kvikdos](https://github.com/pts/kvikdos), emu2 and (windowed) DOSBox.
 * OpenWatcom v2 libc does the same (
 * https://github.com/open-watcom/open-watcom-v2/blob/2d1ea451c2dbde4f1efd26e14c6dea3b15a1b42b/bld/clib/environ/c/isatt.c#L58C10-L59
 * ).
 */
#pragma aux isatty = "mov ax, 4400h"  "int 21h"  "mov eax, 0"  "jc done"  \
    "test dl, dl"  "jns done"  "inc eax"  "done:" \
    __value [__eax] __parm [__ebx] __modify __exact [__eax __ebx __edx]

#endif  /* #ifdef __DOS__ */

#endif  /* #ifdef _DWLIBC_H */
