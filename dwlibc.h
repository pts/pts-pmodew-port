/*
 * dwlibc.h: C header for libc to create combined DOS--Win32 .exe programs
 *     and Linux i386 ELF-32 programs
 * by pts@fazekas.hu at Sun Nov  8 19:07:07 CET 2026
 *
 * Use the dwlibcc tool on Linux to build your programs using dwlibc. For
 * example, a hello-world C program:
 *
 *   #include <dwlibc.h>
 *   void print(const char *msg) { (void)!write(1, msg, strlen(msg)); }
 *   int main(int argc, char **argv) {
 *     (void)argc; (void)argv;
 *     print("Hello, World!\r\n");
 *     return 0;
 *   }
 *
 * Compile it with:
 *
 *   ./dwlibcc -s -Os -W -Wall -Wextra -o prog.exe prog.c
 *
 * The generated prog.exe will run on DOS (with a 80386 or later CPU),
 * Windows (Win32 i386, also on 64-bit Intel Windows using WoW64), Windows
 * emulators (such as Wine) and and OS/2 >=2.0 DOS window.
 *
 * dwlibc uses OpenWatcom v2 C compiler (wcc386) and frontend (owcc) and a
 * custom modified PMODE/W 1.33 DOS extender as the DOS stub to make the
 * program run on DOS.
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
 *   int main(int argc, char **argv) {
 *     (void)argc; (void)argv;
 *     print("Hello, World!\r\n");
 *     return 0;
 *   }
 *
 * An alternative which avoids parsing the command-line string, thus it is
 * using main1(...) instead of main(...):
 *
 *   #define _LIBC_USE_MAIN1
 *   #include <dwlibc.h>
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
#ifndef __DOS__
#  ifndef __NT__
#    ifndef __LINUX__
#      ifndef __ANYOS__
#        error Need target __DOS__ or __NT__, __LINUX__ or __ANYOS__.
#      endif
#    endif
#  endif
#endif
#ifdef __FREEBSD__
#  ifndef __LINUX__
#    error Missing __LINUX__ for __FREEBSD__.
#  endif
#endif
#ifdef __LINUX__
#  ifdef __DOS__
#    error Conflict between __LINUX__ and __DOS__.
#  endif
#  ifdef __NT__
#    error Conflict between __LINUX__ and __NT__.
#  endif
#endif
#ifdef __ANYOS__
#  ifdef __LINUX__
#    error Conflict between __ANYOS__ and __LINUX__.
#  endif
#  ifdef __DOS__
#    error Conflict between __ANYOS__ and __DOS__.
#  endif
#  ifdef __NT__
#    error Conflict between __ANYOS__ and __NT__.
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
#ifdef __DOSMC__
#  error Unexpected libc dosmc __DOSMC__.
#endif
/* According to https://catfox.life/2022/04/16/the-musl-preprocessor-debate/
 * , musl libc doesn't define a preprocessor macro to identify it.
 */

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

typedef long off_t;

/* Some well-known exit code arguments of _exit(...) and exit(...). */
#define EXIT_SUCCESS 0
#define EXIT_FAILURE 1

/* Standard file descriptors (fd arguments). */
#define STDIN_FILENO  0
#define STDOUT_FILENO 1
#define STDERR_FILENO 2

/* whence arguments of lseek(...). */
#define SEEK_SET 0
#define SEEK_CUR 1
#define SEEK_END 2

#ifdef __cplusplus
#  define NULL 0
#else
#  define NULL ((void*)0)
#endif

#define EOF (-1)  /* Indicates end-of-file (EOF) or error. */

#if 0  /* For 2-argument and 3-argument open(...), which we don't provide. */
#  define O_RDONLY 0  /* flags bitfield value below. */
#  define O_WRONLY 1
#  define O_RDWR   2
#  define O_BINARY 0  /* All I/O is binary, no CTRF-to-LF conversion. */
#  define O_CREAT  ...  /* Value portable. */
#  define O_TRUNC  ...  /* Value portable. */
#  define O_APPEND ...  /* Value portable. */
#endif

#undef offsetof
#define offsetof(type,member) ((size_t) &((type*)0)->member)

/* --- Internal helper macros for function declarations. */

#ifdef __NT__
#  define __DWLIBCABI1 static __inline
#  define __DWLIBCABI2 /*__declspec(dllimport)*/
#  ifdef __DOS__  /* While still #ifdef __NT__. */
#    define __DWLIBCABI3 static __inline
#  else
#    define __DWLIBCABI3
#  endif
#else
#  define __DWLIBCABI1
#  define __DWLIBCABI2
#  define __DWLIBCABI3
#endif

/* --- Function declarations. */

#define _LIBC_HAVE_OPEN00  /* Similar to https://github.com/pts/ssmcc */
#define _LIBC_HAVE_CREAT1

#ifdef _LIBC_USE_MAIN  /* Can be defined by the user. */
#  ifdef _LIBC_USE_MAIN1  /* Can be defined by the user. */
#    error Conflict between _LIBC_USE_MAIN and _LIBC_USE_MAIN1.
#  endif
#else
#  ifndef _LIBC_USE_MAIN1
#    define _LIBC_USE_MAIN  /* main(...) is the default, not main1(...). */
#  endif
#endif

#ifdef _LIBC_USE_MAIN  /* Can be defined by the user. */
  int __watcall main(int argc, char **argv);
#else
  /* The entire command line is passed without leading whitespace (space or
   * TAB == '\t') and without the program command name (argv[0]). The
   * program has to split it to individual arguments. The program has to
   * implement it instead of main(...).
   */
  int __watcall main1(const char *cmdline);
#endif

/* Helper for standard C program, see example above. */
#ifdef _LIBC_USE_MAIN
#  define main1_ignore_cmdline() do { (void)argc; (void)argv; } while (0)
#else
#  define main1_ignore_cmdline() (void)cmdline
#endif

#ifndef __ANYOS__
/* Equivalent to open(pathname, O_RDONLY | O_BINARY), but a full-fledged
 * open(2) is not provided by dwlibc . Returns -1 on error. Unlike in
 * regular libcs, the retuned file descriptor can be negative and still be
 * valid.
 */
__DWLIBCABI1 int open00(const char *pathname);

/* Almost equivalent to creat(pathname, 0666), except for O_BINARY.
 * Equivalent to open(pathname, O_WRONLY | O_CREAT | O_TRUNC | O_BINARY,
 * 0666), but a full-fledged open(2) or create(2) are not provided by
 * dwlibc. Returns -1 on error. Unlike in regular libcs, the retuned file
 * descriptor can be negative and still be valid.
 */
__DWLIBCABI1 int creat1(const char *pathname);

__DWLIBCABI1 int close(int fd);

__DWLIBCABI1 ssize_t read(int fd, void *buf, size_t count);

__DWLIBCABI1 ssize_t write(int fd, const void *buf, size_t count);

/* Returns bool indicating whether fd is a terminal (interactive text
 * console).
 */
__DWLIBCABI1 int isatty(int fd);

/* If you seek beyond the end of the file, and you write something, the
 * bytes in-between will be undefined (verified on MS-DOS 6.22 and Windows
 * 95), because DOS and Windows 95--98--ME don't zero-initialize those bytes
 * on disk. Windows NT and Unix-like systems do. but at this layer of
 * abstraction this can't be guaranteed.
  */
__DWLIBCABI1 off_t lseek(int fd, off_t offset, int whence);

static __inline int ftruncate(int fd, off_t size);

/* Same as: ftruncate(fd, lseek(fd, 0, SEEK_CUR)). This is not a standard C
 * or POSIX function.
 */
__DWLIBCABI1 int ftruncate_here(int fd);

/* remove(...) and unlink(...) are equivalent. */
__DWLIBCABI1 int remove(const char *pathname);
__DWLIBCABI1 int unlink(const char *pathname);

/* Returns NULL iff the passed size is 0 or if there is not enough memory.
 * Otherwise it returns a pointer which is aligned to a multiple of 4 bytes.
 * dwlibc doesn't support freeing memory, only malloc is supported.
 */
static __inline void *malloc(size_t size);

/* exit(...) and _exit(...) are equivalent in dwlibc. */
__DWLIBCABI3 __declspec(noreturn) void  exit(unsigned char exit_code);
__DWLIBCABI3 __declspec(noreturn) void _exit(unsigned char exit_code);
#endif  /* #ifndef __ANYOS__ */

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
char *strchr(const char *s, int c);  /* BSD has index(...). */
int strcmp(const char *s1, const char *s2);
char *strcpy(char *dest, const char *src);
size_t strlen(const char *s);
int strncmp(const char *s1, const char *s2, size_t n);

int isalnum(int c);
int isalpha(int c);
int isascii(int c);
int isdigit(int c);
int islower(int c);
int isprint(int c);
int isspace(int c);
int isupper(int c);
int isxdigit(int c);

int tolower(int c);
int toupper(int c);

/* Swaps the corresponding bytes in the specified regions. Not a standard
 * C function, but useful.
  */
void memswap(void *a, void *b, size_t size);

/* Swaps the corresponding 32-words in the specified regions. Not a standard
 * C function, but useful.
  */
void memswap32(void *a, void *b, size_t count);

/* Same signature as qsort(3), but it implements the fast-in-worst-case
 * heapsort. It is not stable. For a stable but very slow
 * qsort(3) implementation, see fyi/c_qsort.c.
 *
 * Worst case execution time: O(n*log(n)): less than 3*n*log_2(n)
 * comparisons and swaps. (The number of swaps is usually a bit smaller than
 * the number of comparisons.) The average number of comparisons is
 * 2*n*log_2(n)-O(n). It is very fast if all values are the same (but still
 * does lots of comparisons and swaps). It is not especially faster than
 * average if the input is already ascending or descending (with unique
 * values),
 *
 * Uses a constant amount of memory in addition to the input/output array.
 *
 * Based on heapsort algorithm H from Knuth TAOCP 5.2.3. The original uses a
 * temporary variable (of `size' bytes) and copies elements between it and
 * the array. That code was changed to swaps within the original array.
 */
static __inline void qsort(
    void *base, size_t n, size_t size,
    int /*__watcall*/ (*cmp)(const void *a, const void *b));

#ifndef __GNUC__
   /* For this to work with __GNUC__, we muset make sure that if the
    * function taking the `...' arguments is __attribute__((noinline)).
    *
    * Everything below is i386-only.
    */
  typedef char *va_list;
#  define va_start(ap, last) ((ap) = (char*)&(last) + ((sizeof(last)+3)&~3), \
      (void)0)
#  define va_arg(ap, type) ((ap) += (sizeof(type)+3)&~3, \
      *(type*)((ap) - ((sizeof(type)+3)&~3)))
#  define va_copy(dest, src) ((dest) = (src), (void)0)
#  define va_end(ap) /*((ap) = 0, (void)0)*/  /* Same as with the `= 0'. */
#endif

/* --- Register usage of main and main1. */

/* It must not modify `ebp', otherwise the OpenWatcom C compiler omits the
 * `pop ebp' between the `mov esp, ebp' and the `ret'.
 */
#ifdef _LIBC_USE_MAIN
#  pragma aux main  __modify [__eax __ebx __ecx __edx __esi __edi]
#endif
#ifdef _LIBC_USE_MAIN1
#  pragma aux main1 __modify [__eax __ebx __ecx __edx __esi __edi]
#endif

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

#ifdef _LIBC_USE_MAIN
#  define main0() int main(int argc, char **argv)
#  define main0_argv1() ((void)argc, argv[0] ? argv[1] : NULL)
#  define main0_exit0() return EXIT_SUCCESS
#  define main0_exit(exit_code) return (exit_code)
#  define main0_is_progarg_null(arg) ((arg) == NULL)
#endif
#ifdef _LIBC_USE_MAIN1
#  define main0() int main1(const char *__main0_cmdline)
#  define main0_argv1() __main0_cmdline
#  define main0_exit0() do { return 0; } while (0)
#  define main0_exit(exit_code) _exit(exit_code)
#  define main0_is_progarg_null(arg) 0  /* Size optimization, never NULL. */
#endif

/* --- Implementation of system-agnostic functions. */

/* static __inline int isalnum(int c) { return (c >= 'A' && c <= 'Z') ||
 *     (c >= 'a' && c <= 'z') || (c >= '0' && c <= '9'); }
 */
#pragma aux isalnum = "sub al, 48"  "cmp al, 10"  "jc @$1"  "add al, 48" \
    "or al, 32"  "sub al, 97"  "cmp al, 26"  "@$1: sbb eax, eax" \
    "neg eax"  __value [__eax] __parm [__eax] __modify __exact [__eax]

/* static __inline int isalpha(int c) { return (c >= 'A' && c <= 'Z') ||
 *     (c >= 'a' && c <= 'z'); }
 */
#pragma aux isalpha = "or al, 32"  "sub al, 97"  "cmp al, 26" \
    "sbb eax, eax"  "neg eax" \
    __value [__eax] __parm [__eax] __modify __exact [__eax]

/* static __inline int isascii(int c) { return c >= 0 && c <= 127; } */
#pragma aux isascii = "cmp al, 127+1"  "sbb eax, eax"  "neg eax" \
    __value [__eax] __parm [__eax] __modify __exact [__eax]

/* static __inline int isdigit(int c) { return c >= '0' && c <= '9'; } */
#pragma aux isdigit = "sub al, 48"  "cmp al, 10"  "sbb eax, eax"  "neg eax" \
    __value [__eax] __parm [__eax] __modify __exact [__eax]

/* static __inline int islower(int c) { return c >= 'a' && c <= 'z'; } */
#pragma aux islower = "sub al, 97"  "cmp al, 26"  "sbb eax, eax"  "neg eax" \
    __value [__eax] __parm [__eax] __modify __exact [__eax]

/* static __inline int isprint(int c) { return c >= 32 && c <= 126; } */
#pragma aux isprint = "sub al, 32"  "cmp al, 126-32+1"  "sbb eax, eax" \
    "neg eax"  __value [__eax] __parm [__eax] __modify __exact [__eax]

/* static __inline int isspace(int c) { return (c >= '\t' && c <= '\r') ||
 *     c == ' '; }
 */
#pragma aux isspace = "sub al, 9"  "cmp al, 13-9+1"  "jc short @$1" \
    "sub al, 32-9"  "cmp al, 1"  "@$1: sbb eax, eax"  "neg eax" \
    __value [__eax] __parm [__eax] __modify __exact [__eax]

/* static __inline int isupper(int c) { return c >= 'A' && c <= 'Z'; } */
#pragma aux isupper = "sub al, 65"  "cmp al, 26"  "sbb eax, eax"  "neg eax" \
    __value [__eax] __parm [__eax] __modify __exact [__eax]

/* static __inline int isxdigit(int c) { return (c >= 'A' && c <= 'F') ||
 *     (c >= 'a' && c <= 'f') || (c >= '0' && c <= '9'); }
 */
#pragma aux isxdigit = "sub al, 48"  "cmp al, 10"  "jc short @$1" \
    "or al, 32"  "sub al, 97-48"  "cmp al, 6"  "@$1: sbb eax, eax" \
    "neg eax"  __value [__eax] __parm [__eax] __modify __exact [__eax]

/* static __inline int tolower(int c) { return c >= 'A' && c <= 'Z' ?
 *     c + 'a' - 'A' : i; }
 */
#pragma aux tolower = "sub al, 65"  "cmp al, 25"  "ja short @$1" \
    "add al, 32"  "@$1: add al, 65" \
    __value [__eax] __parm [__eax] __modify __exact [__eax]

/* static __inline int toupper(int c) { return c >= 'a' && c <= 'z' ?
 *     c + 'A' - 'a' : i; }
 */
#pragma aux toupper = "sub al, 97"  "cmp al, 25"  "ja short @$1" \
    "add al, -32"  "@$1: add al, 97" \
    __value [__eax] __parm [__eax] __modify __exact [__eax]

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

#pragma aux strncmp = "jecxz equal"  "next: lodsb"  "scasb"  "je same_char" \
    "sbb eax, eax"  "sbb eax, -1"  "jmp short done"  "same_char:" \
    "test al, al"  "jz equal"  "loop next"  "equal: xor eax, eax"  "done:" \
    __value [__eax] __parm [__esi] [__edi] [__ecx] \
    __modify __exact [__eax __ecx __esi __edx]

#pragma aux memswap = "jecxz done"  "again: mov al, [edi]"  "xchg al, [edx]" \
    "stosb"  "inc edx"  "loop again"  "done:" __parm [__edi] [__edx] [__ecx] \
    __modify __exact [__al __edi __edx __ecx]

#pragma aux memswap32 = "jecxz done"  "again: mov eax, [edi]" \
    "xchg eax, [edx]"  "stosd"  "add edx, 4"  "loop again"  "done:" \
    __parm [__edi] [__edx] [__ecx] __modify __exact [__al __edi __edx __ecx]

static __inline void qsort(
    void *base, size_t n, size_t size,
    int /*__watcall*/ (*cmp)(const void *a, const void *b)) {
  char *ap = (char*)base, *lp = ap + size * (n >> 1);
  char *rp = ap + size * (n - 1), *tp, *ip, *jp;
  if (n < 2) return;
  for (;;) {
    if (lp != ap) {
      tp = lp -= size;
    } else {
      memswap(ap, rp, size);
      if ((rp -= size) == ap) break;
      tp = ap;
    }
    jp = lp;
    for (;;) {
      ip = jp;
      jp += (jp - ap) + size;
      if (jp > rp) break;
      if (jp < rp && cmp(jp, jp + size) < 0) jp += size;
      if (!(cmp(tp, jp) < 0)) break;
      memswap(ip, jp, size);
      tp = jp;
    }
    memswap(ip, tp, size);
  }
}

extern size_t __dwlibc_alloc_remaining, __dwlibc_alloc_next_bsize;
extern unsigned char *__dwlibc_alloc_end;

/* --- Command-line argument parser. */

#if defined(_LIBC_USE_MAIN) && (defined(__DOS__) || defined(__NT__))
/* Parses the first argument of the Windows command-line (specified in EAX)
 * in place. Returns (in EAX) the pointer to the rest of the command-line.
 * The parsed argument will be available as NUL-terminated string at the
 * same location as the input.
 *
 * Similar to CommandLineToArgvW(...) in SHELL32.DLL, but doesn't aim for
 * 100% accuracy, especially that it doesn't support non-ASCII characters
 * beyond ANSI well, and that other implementations are also buggy (in
 * different ways).
 *
 * It treats only space and tab and a few others as whitespece. (The Wine
 * version of CommandLineToArgvA.c treats only space and tab as whitespace).
 *
 * This is based on the incorrect and incomplete description in:
 * https://learn.microsoft.com/en-us/windows/win32/api/shellapi/nf-shellapi-commandlinetoargvw
 *
 * See https://nullprogram.com/blog/2022/02/18/ for a more detailed writeup
 * and a better installation.
 *
 * https://github.com/futurist/CommandLineToArgvA/blob/master/CommandLineToArgvA.c
 * has the 3*n rule, which Wine 1.6.2 doesn't seem to have. It also has special
 * parsing rules for argv[0] (the program name).
 *
 * There is the CommandLineToArgvW function in SHELL32.DLL available since
 * Windows NT 3.5 (not in Windows NT 3.1). For alternative implementations,
 * see:
 *
 * * https://github.com/futurist/CommandLineToArgvA
 *   (including a copy from Wine sources).
 * * http://alter.org.ua/en/docs/win/args/
 * * http://alter.org.ua/en/docs/win/args_port/
 */
static __inline char * __watcall __dwlibc_parse_first_arg(char *pw) {
  const char *p;
  const char *q;
  char c;
  char is_quote = 0;
  for (p = pw; c = *p, c == ' ' || c == '\t' || c == '\n' || c == '\v'; ++p) {}
  if (*p == '\0') { *pw = '\0'; return pw; }
  for (;;) {
    if ((c = *p) == '\0') goto after_arg;
    ++p;
    if (c == '\\') {
      for (q = p; c = *q, c == '\\'; ++q) {}
      if (c == '"') {
        for (; p < q; p += 2) {
          *pw++ = '\\';
        }
        if (p != q) {
          is_quote ^= 1;
        } else {
          *pw++ = '"';
          ++p;  /* Skip over the '"'. */
        }
      } else {
        *pw++ = '\\';
        for (; p != q; ++p) {
          *pw++ = '\\';
        }
      }
    } else if (c == '"') {
      is_quote ^= 1;
    } else if (!is_quote && (c == ' ' || c == '\t' || c == '\n' || c == '\v')) {
      if (p - 1 != pw) --p;  /* Don't clobber the rest with '\0' below. */
     after_arg:
      *pw = '\0';
      return (char*)p;
    } else {
      *pw++ = c;  /* Overwrite in-place. */
    }
  }
}

/* It takes the char *cmdline in EAX and the char *argv0 in EDX, and returns
 * int argc in EAX and char **argv in EDX. It ruins EBX and ECX.
 *
 * It pushes the char *arg pointers to the stack,
 * and it will kep them there until it returns. It also modifies the cmdline
 * string in place, replacing some whitespace characters with NULs.
 *
 * !! TODO(pts): Apply some limit so that it doesn't overflow the stack.
 */
#define __DWLIBC_ASMB_CMDLINE_TO_ARGV \
    __asm { push 0 }  /* NULL marks end of argv array. */ \
    __asm { push edx }  /* Save EDX as argv[0]. */  \
    __asm { xor ecx, ecx } \
    __asm { inc ecx }  /* ECX := 1 (current argc). */ \
    __asm { argv_next: } \
    __asm { mov edx, eax }  /* Save EAX (remaining command line). */ \
    __asm { call __dwlibc_parse_first_arg } \
    __asm { cmp eax, edx } \
    __asm { db 74h, 4 }  /* je argv_end */  /* No more arguments in argv. */ \
    __asm { inc ecx }  /* argc += 1. */ \
    __asm { push edx }  /* Push argv[i]. */ \
    __asm { db 0ebh, -15 }  /* jmp argv_next */ \
    __asm { argv_end: mov eax, esp } \
    __asm { push ecx }  /* Save argc. */ \
    __asm { reverse_ptrs: }  /* Reverse NULL-terminated char** list at EAX. */ \
    __asm { lea edx, [eax-4] } \
    __asm { next1: add edx, 4 } \
    __asm { cmp dword ptr [edx], 0 } \
    __asm { db 075h, -8 }  /* jne short next1 */ \
    __asm { cmp edx, eax } \
    __asm { db 074h, 21 }  /* je short nothing */ \
    __asm { sub edx, 4 } \
    __asm { db 0ebh, 12 }  /* jmp short cmp2 */ \
    __asm { next2: mov ecx, [eax] } \
    __asm { xchg ecx, [edx] } \
    __asm { mov [eax], ecx } \
    __asm { add eax, 4 } \
    __asm { sub edx, 4 } \
    __asm { cmp2: cmp eax, edx } \
    __asm { db 72h, -16 }  /* jb short next2 */ \
    __asm { nothing: } \
    __asm { reverse_ptrs_done: pop eax }  /* Restore EAX := argc. */ \
    __asm { mov edx, esp }  /* EDX := argv. */
#ifdef __DOS__
#  define __DWLIBC_ASMS_DOS_GETARGV0 0x20  /* Size of the code below. */
#  define __DWLIBC_ASMB_DOS_GETARGV0 \
    __asm { mov ebx, [eax+2ch] }  /* BX := environment selector. */ \
    __asm { push eax } __asm { mov ax, 6 }__asm { int 31h } \
    __asm { shl ecx, 16 } __asm { movzx edi, dx } \
    __asm { add edi, ecx }  /* EDI := first env var (NAME=value). */ \
    __asm { or ecx, -1 }  /* Unlimited `repne scasb' below. */ \
    __asm { mov al, 0 } \
    __asm { skip_env_vars_loop: repne scasb }  /* Skip single env var. */ \
    __asm { scasb } \
    __asm { db 75h, -5 }  /* jne short skip_env_vars_loop */ \
    __asm { lea edx, [edi+2] }  /* EDX := fully qualified argv[0]. */ \
    __asm { pop eax }
#endif  /* #ifdef __DOS__ */
#endif  /* #if defined(_LIBC_USE_MAIN) && (defined(__DOS__) || defined(__NT__)) */

/* --- Win32 implementation. Mostly dark magic in OpenWatcom C and inline
 * assembly.
 */

#if defined(__NT__) && !defined(__LINUX__)

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
typedef HANDLE          HMODULE;
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
__DWLIBCABI2 BOOL __stdcall WriteFile(
    HANDLE hFile, LPCVOID lpBuffer, DWORD nNumberOfBytesToWrite,
    LPDWORD lpNumberOfBytesWritten, LPOVERLAPPED lpOverlapped);
__DWLIBCABI2 BOOL __stdcall ReadFile(
    HANDLE hFile, LPVOID lpBuffer, DWORD nNumberOfBytesToRead,
    LPDWORD lpNumberOfBytesRead, LPOVERLAPPED lpOverlapped);
__DWLIBCABI2 LPSTR __stdcall GetCommandLineA(void);
__DWLIBCABI2 DWORD __stdcall GetFileType(HANDLE hFile);
__DWLIBCABI2 LPVOID __stdcall VirtualAlloc(LPVOID lpAddress,
    SIZE_T dwSize, DWORD flAllocationType, DWORD flProtect);
__DWLIBCABI2 BOOL __stdcall DeleteFileA(LPCSTR lpFileName);
__DWLIBCABI2 BOOL __stdcall CloseHandle(HANDLE hObject);
__DWLIBCABI2 DWORD __stdcall SetFilePointer(HANDLE hFile,
    LONG lDinstanceToMove, PLONG *lpDistanceToMoveHigh,
    DWORD dwMoveMethod);
__DWLIBCABI2 HANDLE __stdcall CreateFileA(
    LPCSTR lpFileName, DWORD dwDesiredAccess, DWORD dwShareMode,
    LPSECURITY_ATTRIBUTES lpSecurityAttributes, DWORD dwCreationDisposition,
    DWORD dwFlagsAndAttributes, HANDLE hTemplateFile);
__DWLIBCABI2 DWORD __stdcall GetModuleFileNameA(
    HMODULE hModule, LPSTR lpFilename, DWORD nSize);
__DWLIBCABI2 BOOL __stdcall SetEndOfFile(HANDLE hFile);

/* nStdHandle for GetStdHandle(...): */
#define STD_INPUT_HANDLE    ((DWORD)-10)
#define STD_OUTPUT_HANDLE   ((DWORD)-11)
#define STD_ERROR_HANDLE    ((DWORD)-12)

#define INVALID_HANDLE_VALUE ((HANDLE)(LONG_PTR)-1)

#define FILE_TYPE_CHAR ((DWORD)2)

/* deDesiredAccess for CreateFileA(...) (bitfield): */
#define GENERIC_READ  0x80000000L
#define GENERIC_WRITE 0x40000000L

/* dwCreationDisposition for CreateFileA(...): */
#define CREATE_NEW          1L
#define CREATE_ALWAYS       2L
#define OPEN_EXISTING       3L
#define OPEN_ALWAYS         4L
#define TRUNCATE_EXISTING   5L

/* dwFlagsAndAttributes for CreateFileA(...): */
#define FILE_ATTRIBUTE_NORMAL 0x00000080L

/* dwShareMode for CreateFileA(...) (bitfield): */
#define FILE_SHARE_READ     0x00000001L
#define FILE_SHARE_WRITE    0x00000002L
#define FILE_SHARE_DELETE   0x00000004L

/* flAllocationType for VirtualAlloc(...). */
#define MEM_COMMIT  0x1000L
#define MEM_RESERVE 0x2000L

/* flProtect for VirtualAlloc(...). */
#define PAGE_READWRITE         0x04L
#define PAGE_EXECUTE_READWRITE 0x40L

extern HANDLE __dwlibc_std_handles[3];

#ifdef __DOS__  /* While still #ifdef __NT__. */
  extern char __dwlibc_is_dos;
#  define __DWLIBC_DEFINE_IS_DOS char __dwlibc_is_dos;
#  define __DWLIBC_ASMB_EXIT __asm { jmp _exit }
#  define __DWLIBC_ASMB_START \
    /* cld shouldn't be need at Win32 entry. */ \
    __asm { stc } __asm { clc } __asm { cld }  /* Signature. */ \
    __asm { xor eax, eax }  /* DOS entry point is after this. */
  int __dwlibc_dos_open00(const char *pathname);
#  pragma aux __dwlibc_dos_open00 = "mov ax, 3d00h"  "int 21h" \
    "jnc ok"  "sbb eax, eax"  "ok:" \
    __value [__eax] __parm [__edx] __modify __exact [__eax __ecx]
  int __dwlibc_dos_creat1(const char *pathname);
#  pragma aux __dwlibc_dos_creat1 = "mov ah, 3ch"  "xor ecx, ecx"  "int 21h" \
    "jnc ok"  "sbb eax, eax"  "ok:" \
    __value [__eax] __parm [__edx] __modify __exact [__eax __ecx]
  int __dwlibc_dos_close(int fd);
#  pragma aux __dwlibc_dos_close = "mov ah, 3eh"  "int 21h"  "sbb eax, eax" \
    __value [__eax] __parm [__ebx] __modify __exact [__eax]
  ssize_t __dwlibc_dos_read(int fd, void *buf, size_t count);
#  pragma aux __dwlibc_dos_read = \
    "mov ah, 3fh"  "int 21h"  "jnc ok"  "sbb eax, eax"  "ok:" \
    __value [__eax] __parm [__ebx] [__edx] [__ecx] __modify __exact [__eax]
  ssize_t __dwlibc_dos_write(int fd, const void *buf, size_t count);
#  pragma aux __dwlibc_dos_write = \
    "xor eax, eax"  "jecxz ok"  "mov ah, 40h"  "int 21h" \
    "jnc ok"  "sbb eax, eax"  "ok:" \
    __value [__eax] __parm [__ebx] [__edx] [__ecx] __modify __exact [__eax]
  int __dwlibc_dos_isatty(int fd);
#  pragma aux __dwlibc_dos_isatty = \
     "mov ax, 4400h"  "int 21h"  "mov eax, 0"  "jc done" \
    "test dl, dl"  "jns done"  "inc eax"  "done:" \
    __value [__eax] __parm [__ebx] __modify __exact [__eax __edx]
  off_t __dwlibc_dos_lseek(int fd, off_t offset, int whence);
#  pragma aux __dwlibc_dos_lseek = "mov ah, 42h"  "mov ecx, edx" \
    "shr ecx, 16"  "int 21h"  "sbb ecx, ecx"  "jc done"  "shl edx, 16" \
    "mov dx, ax"  "mov ecx, edx"  "done: xchg eax, ecx" __value [__eax] \
    __parm [__ebx] [__edx] [__eax] __modify __exact [__eax __ecx __edx]
  int __dwlibc_dos_ftruncate_here(int fd);
#  pragma aux __dwlibc_dos_ftruncate_here = \
    "xor ecx, ecx"  "mov ah, 40h"  "int 21h" "sbb eax, eax" \
    __parm [__ebx] __value [__eax] __modify __exact [__eax __ecx]
  int __dwlibc_dos_remove(const char *pathname);
#  pragma aux __dwlibc_dos_remove = "mov ah, 41h"  "int 21h"  "sbb eax, eax" \
    __value [__eax] __parm [__edx] __modify __exact [__eax]
  __declspec(noreturn) void __dwlibc_dos_exit(unsigned char exit_code);
#  pragma aux __dwlibc_dos_exit = \
    "mov ah, 4ch"  "int 21h"  __parm [__al] __modify __exact []
  static __inline __declspec(noreturn) void  exit(unsigned char exit_code) {
    if (__dwlibc_is_dos) __dwlibc_dos_exit(exit_code);
    ExitProcess(exit_code);
  }
  static __inline __declspec(noreturn) void _exit(unsigned char exit_code) {
    if (__dwlibc_is_dos) __dwlibc_dos_exit(exit_code);
    ExitProcess(exit_code);
  }
#else
#  define __DWLIBC_DEFINE_IS_DOS
#  define __DWLIBC_ASMB_EXIT \
    __asm { movzx eax, al } __asm { push eax } __asm { call ExitProcess }
#  define __DWLIBC_ASMB_START __asm { call GetCommandLineA }
#  pragma aux  exit = "movzx eax, al"  "push eax" "call ExitProcess" \
     __parm [__al] __modify __exact []
#  pragma aux _exit = "movzx eax, al"  "push eax" "call ExitProcess" \
     __parm [__al] __modify __exact []
#endif

static __inline int open00(const char *pathname) {
  /* !! DOS */
  int fd;
#ifdef __DOS__  /* While still #ifdef __NT__. */
  if (__dwlibc_is_dos) return __dwlibc_dos_open00(pathname);
#endif
  if ((fd = (int)CreateFileA(pathname,
      GENERIC_READ, FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE,
      NULL, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, NULL)) !=
      -1  /* (int)INVALID_HANDLE_VALUE */) fd += 3;
  return fd;
}

static __inline int creat1(const char *pathname) {
  /* !! DOS */
  int fd;
#ifdef __DOS__  /* While still #ifdef __NT__. */
  if (__dwlibc_is_dos) return __dwlibc_dos_creat1(pathname);
#endif
  if ((fd = (int)CreateFileA(pathname,
      GENERIC_WRITE, FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE,
      NULL, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, NULL)) !=
      -1 /* INVALID_HANDLE_VALUE */) fd += 3;
  return fd;
}

static __inline int close(int fd) {
#ifdef __DOS__  /* While still #ifdef __NT__. */
  if (__dwlibc_is_dos) return __dwlibc_dos_close(fd);
#endif
  return ((unsigned)fd >= 3 && !CloseHandle((HANDLE)((unsigned)fd - 3))) ?
      -1 : 0;
}

static __inline ssize_t read(int fd, void *buf, size_t count) {
  DWORD read_count;
#ifdef __DOS__  /* While still #ifdef __NT__. */
  if (__dwlibc_is_dos) return __dwlibc_dos_read(fd, buf, count);
#endif
  fd = (unsigned)fd < 3 ? (int)__dwlibc_std_handles[fd] : (unsigned)fd - 3;
  return ReadFile((HANDLE)fd, buf, count, &read_count, NULL) ?
      read_count : -1;
}

static __inline ssize_t write(
    int fd, const void *buf, size_t count) {
  DWORD written_count;
#ifdef __DOS__  /* While still #ifdef __NT__. */
  if (__dwlibc_is_dos) return __dwlibc_dos_write(fd, buf, count);
#endif
  fd = (unsigned)fd < 3 ? (int)__dwlibc_std_handles[fd] : (unsigned)fd - 3;
  return WriteFile((HANDLE)fd, buf, count, &written_count, NULL)
      ? written_count : -1;
}

/* Returns bool indicating whether fd is a terminal (interactive text
 * console).
 */
static __inline int isatty(int fd) {
#ifdef __DOS__  /* While still #ifdef __NT__. */
  if (__dwlibc_is_dos) return __dwlibc_dos_isatty(fd);
#endif
  fd = (unsigned)fd < 3 ? (int)__dwlibc_std_handles[fd] : (unsigned)fd - 3;
  return GetFileType((HANDLE)fd) == FILE_TYPE_CHAR;
}

static __inline off_t lseek(int fd, off_t offset, int whence) {
#ifdef __DOS__  /* While still #ifdef __NT__. */
  if (__dwlibc_is_dos) return __dwlibc_dos_lseek(fd, offset, whence);
#endif
  fd = (unsigned)fd < 3 ? (int)__dwlibc_std_handles[fd] : (unsigned)fd - 3;
  /* SetFilePointer(...) returns (DWORD)-1 on error. Good. */
  return (off_t)SetFilePointer((HANDLE)fd, offset, NULL, whence);
}

static __inline int ftruncate_here(int fd) {
#ifdef __DOS__  /* While still #ifdef __NT__. */
  if (__dwlibc_is_dos) return __dwlibc_dos_ftruncate_here(fd);
#endif
  fd = (unsigned)fd < 3 ? (int)__dwlibc_std_handles[fd] : (unsigned)fd - 3;
  return SetEndOfFile((HANDLE)fd) ? 0 : -1;
}

static __inline int ftruncate(int fd, off_t size) {
  off_t old_fpos, got_fpos;
  int got_trunc;
#ifdef __DOS__
  if (!__dwlibc_is_dos)
#endif
     fd = (unsigned)fd < 3 ? (int)__dwlibc_std_handles[fd] : (unsigned)fd - 3;
  old_fpos =
#ifdef __DOS__  /* While still #ifdef __NT__. */
      (__dwlibc_is_dos) ? __dwlibc_dos_lseek(fd, 0, SEEK_CUR) :
#endif
      (off_t)SetFilePointer((HANDLE)fd, 0, NULL, SEEK_CUR);
  if (old_fpos == -1) return -1;
  got_fpos =
#ifdef __DOS__  /* While still #ifdef __NT__. */
      (__dwlibc_is_dos) ? __dwlibc_dos_lseek(fd, size, SEEK_SET) :
#endif
      (off_t)SetFilePointer((HANDLE)fd, size, NULL, SEEK_SET);
  if (got_fpos != size) return -1;
  got_trunc =
#ifdef __DOS__  /* While still #ifdef __NT__. */
      (__dwlibc_is_dos) ? __dwlibc_dos_ftruncate_here(fd) :
#endif
      SetEndOfFile((HANDLE)fd) ? 0 : -1;
  got_fpos =
#ifdef __DOS__  /* While still #ifdef __NT__. */
      (__dwlibc_is_dos) ? __dwlibc_dos_lseek(fd, old_fpos, SEEK_SET) :
#endif
      (off_t)SetFilePointer((HANDLE)fd, old_fpos, NULL, SEEK_SET);
  /* This leaves the file pointer at the wrong laction if the last lseek
   * (to old_fpos) has failed, which is very unlikely, because lseek
   * fails very rarely.
   */
  return (got_fpos != old_fpos || got_trunc) ? -1 : 0;
}

static __inline int remove(const char *pathname) {
#ifdef __DOS__  /* While still #ifdef __NT__. */
  if (__dwlibc_is_dos) return __dwlibc_dos_remove(pathname);
#endif
  return DeleteFileA(pathname) ? 0 : - 1;
}

static __inline int unlink(const char *pathname) {
#ifdef __DOS__  /* While still #ifdef __NT__. */
  if (__dwlibc_is_dos) return __dwlibc_dos_remove(pathname);
#endif
  return DeleteFileA(pathname) ? 0 : - 1;
}

#ifdef _LIBC_USE_MAIN
  extern char __dwlibc_module_fn[0x110];
#endif

static __inline const char * __watcall __dwlibc_win32cmdline(
    char *cmdline) {
#ifdef __DOS__  /* While still #ifdef __NT__. */
  if (cmdline) {
    ++__dwlibc_is_dos;
    cmdline += 0x80;  /* Skip first half of DOS PSP. */
    cmdline[1 + *(unsigned char*)cmdline] = '\0';  /* Change CR to NUL. */
    for (++cmdline; *cmdline == ' ' || *cmdline == '\t'; ++cmdline) {}
    return cmdline;
  }
  cmdline = GetCommandLineA();
#endif
#ifdef _LIBC_USE_MAIN
  GetModuleFileNameA(NULL, __dwlibc_module_fn, sizeof(__dwlibc_module_fn));
#endif
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
#ifdef _LIBC_USE_MAIN
#  ifdef __DOS__  /* While still #ifdef __NT__. */
#    define __DWLIBC_ASMB_WIN32_GETARGV0 \
        __asm { test eax, eax } \
        __asm { db 74h, __DWLIBC_ASMS_DOS_GETARGV0 }  /* Skip next line. */ \
        __DWLIBC_ASMB_DOS_GETARGV0  /* EDX := argv0 on DOS. */
#  else
#    define __DWLIBC_ASMB_WIN32_GETARGV0
#  endif
#  define main(argspec1, argspec2) \
      /*int*/ __declspec(naked) __watcall _dwlibcstart(void) { \
      __DWLIBC_ASMB_START __asm { mov edx, offset __dwlibc_module_fn } \
      __DWLIBC_ASMB_WIN32_GETARGV0 \
      __asm { argv0_ok: call __dwlibc_win32cmdline } \
      __DWLIBC_ASMB_CMDLINE_TO_ARGV  /* Takes EAX, EDX. */ \
      __asm { call main } __DWLIBC_ASMB_EXIT } \
      HANDLE __dwlibc_std_handles[3]; __DWLIBC_DEFINE_IS_DOS \
      size_t __dwlibc_alloc_remaining, __dwlibc_alloc_next_bsize; \
      unsigned char *__dwlibc_alloc_end; \
      char __dwlibc_module_fn[0x110]; \
      void *cstart_; int _argc;  /* Pacify wlink. */ \
      int main(argspec1, argspec2)
#endif
#ifdef _LIBC_USE_MAIN1
#  define main1(argspec1) \
      /*int*/ __declspec(naked) __watcall _dwlibcstart(void) { \
      __DWLIBC_ASMB_START __asm { call __dwlibc_win32cmdline } \
      __asm { call main1 } __DWLIBC_ASMB_EXIT } \
      HANDLE __dwlibc_std_handles[3]; __DWLIBC_DEFINE_IS_DOS \
      size_t __dwlibc_alloc_remaining, __dwlibc_alloc_next_bsize; \
      unsigned char *__dwlibc_alloc_end; \
      int main1(argspec1)
#endif

#endif  /* #if defined(__NT__) && !defined(__LINUX__) */

/* --- DOS implementation. Mostly dark magic in OpenWatcom C and inline
 * assembly.
 */

#if defined(__DOS__) && !defined(__NT__) && !defined(__LINUX__)

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
 * selectors. Also ES == DS, and PSP is at DS:EAX. BSS is already
 * zero-initialized.
 */
#ifdef _LIBC_USE_MAIN
#  define main(argspec1, argspec2) \
      /*int*/ __declspec(naked) __watcall _dwlibcstart(void) { \
      __asm { cld }  /* Not needed for regular PMODE/W. */ \
      __DWLIBC_ASMB_DOS_GETARGV0  /* EDX := argv[0]. */ \
      __asm { sub eax, -80h }  /* EAX := DOS cmdline. */ \
      __asm { call __dwlibc_doscmdline } \
      __DWLIBC_ASMB_CMDLINE_TO_ARGV  /* Takes EAX, EDX. */ \
      __asm { call main } __asm { mov ah, 4ch } __asm { int 21h } } \
      size_t __dwlibc_alloc_remaining, __dwlibc_alloc_next_bsize; \
      unsigned char *__dwlibc_alloc_end; \
      void *cstart_; int _argc;  /* Pacify wlink. */ \
      int main(argspec1, argspec2)
#endif
#ifdef _LIBC_USE_MAIN1
#  define main1(argspec1) \
      /*int*/ __declspec(naked) __watcall _dwlibcstart(void) { \
      __asm { cld }  /* Not needed for regular PMODE/W. */ \
      __asm { sub eax, -80h }  /* EAX := DOS cmdline. */ \
      __asm { call __dwlibc_doscmdline } \
      __asm { call main1 } __asm { mov ah, 4ch } __asm { int 21h } } \
      size_t __dwlibc_alloc_remaining, __dwlibc_alloc_next_bsize; \
      unsigned char *__dwlibc_alloc_end; \
      int main1(argspec1)
#endif

#pragma aux  exit = "mov ah, 4ch"  "int 21h"  __parm [__al] __modify __exact []
#pragma aux _exit = "mov ah, 4ch"  "int 21h"  __parm [__al] __modify __exact []

#pragma aux open00 = "mov ax, 3d00h"  "int 21h" \
    "jnc ok"  "sbb eax, eax"  "ok:" \
    __value [__eax] __parm [__edx] __modify __exact [__eax __ecx]

#pragma aux creat1 = "mov ah, 3ch"  "xor ecx, ecx"  "int 21h" \
    "jnc ok"  "sbb eax, eax"  "ok:" \
    __value [__eax] __parm [__edx] __modify __exact [__eax __ecx]

#pragma aux close = "mov ah, 3eh"  "int 21h"  "sbb eax, eax" \
    __value [__eax] __parm [__ebx] __modify __exact [__eax]

#pragma aux read = "mov ah, 3fh"  "int 21h"  "jnc ok"  "sbb eax, eax"  "ok:" \
    __value [__eax] __parm [__ebx] [__edx] [__ecx] __modify __exact [__eax]

#pragma aux write = "xor eax, eax"  "jecxz ok"  "mov ah, 40h"  "int 21h" \
    "jnc ok"  "sbb eax, eax"  "ok:" \
    __value [__eax] __parm [__ebx] [__edx] [__ecx] __modify __exact [__eax]

/* Just returns whether fd is a character device. (On Unix, there are
 * non-TTY character devices, but this implementation pretends that they
 * don't exist.) It works correctly on
 * [kvikdos](https://github.com/pts/kvikdos), emu2 and (windowed) DOSBox.
 * OpenWatcom v2 libc does the same (
 * https://github.com/open-watcom/open-watcom-v2/blob/2d1ea451c2dbde4f1efd26e14c6dea3b15a1b42b/bld/clib/environ/c/isatt.c#L58C10-L59
 * ).
 */
#pragma aux isatty = "mov ax, 4400h"  "int 21h"  "mov eax, 0"  "jc done" \
    "test dl, dl"  "jns done"  "inc eax"  "done:" \
    __value [__eax] __parm [__ebx] __modify __exact [__eax __edx]

#pragma aux lseek = "mov ah, 42h"  "mov ecx, edx" \
    "shr ecx, 16"  "int 21h"  "sbb ecx, ecx"  "jc done"  "shl edx, 16" \
    "mov dx, ax"  "mov ecx, edx"  "done: xchg eax, ecx" __value [__eax] \
    __parm [__ebx] [__edx] [__eax] __modify __exact [__eax __ecx __edx]

#pragma aux ftruncate_here = \
    "xor ecx, ecx"  "mov ah, 40h"  "int 21h"  "sbb eax, eax" \
    __parm [__ebx] __value [__eax] __modify __exact [__eax __ecx]

#if 0  /* Similar implementation, different error handling. */
  int ftruncate_alt(int fd, off_t size) {
#  pragma aux ftruncate_alt =  "mov esi, edx"  /* Save argument size. */ \
    "xchg ebx, eax"  /* EBX := EAX (filehandle); EBX := junk. */ \
    "mov ax, 4201h"  /* SEEK_CUR. */ \
    "xor ecx, ecx"  "xor edx, edx"  "int 21h"  "jc done" \
    "xchg edx, eax"  /* DX := AX (low word); EAX := junk. */ \
    "xchg ecx, eax"  /* CX := AX (high word); EAX := junk. */ \
    "push ecx"  "push edx"  "mov edx, esi"  "mov ecx, esi"  "shr ecx, 16" \
    "mov ax, 4200h"  /* SEEK_SET to ESI. */ \
    "int 21h"  "jc done"  "mov ah, 40h"  "xor ecx, ecx" \
    "int 21h"  /* Truncate. */ \
    "jc done"  "pop edx"  "pop ecx"  "mov ax, 4200h"  /* SEEK_SET back. */ \
    "int 21h"  "done:"  "sbb eax, eax" \
    __value [__eax] __parm [__eax] [__edx] __modify __exact [__ebx __ecx __esi]
#endif

static __inline int ftruncate(int fd, off_t size) {
  off_t old_fpos;
  if ((old_fpos = lseek(fd, 0, SEEK_CUR)) == -1) return -1;
  if (lseek(fd, size, SEEK_SET) != size) return -1;
  size = ftruncate_here(fd);
  /* This leaves the file pointer at the wrong location if the last lseek
   * (to old_fpos) has failed, which is very unlikely, because lseek
   * fails very rarely.
   */
  return (lseek(fd, old_fpos, SEEK_SET) != old_fpos || size) ? -1 : 0;
}

#pragma aux remove = "mov ah, 41h"  "int 21h"  "sbb eax, eax" \
    __value [__eax] __parm [__edx] __modify __exact [__eax]
#pragma aux unlink = "mov ah, 41h"  "int 21h"  "sbb eax, eax" \
    __value [__eax] __parm [__edx] __modify __exact [__eax]

#endif  /* #if defined(__DOS__) && !defined(__NT__) && !defined(__LINUX__) */

#if defined(__DOS__) && !defined(__LINUX__)
/* Allocates bsize bytes using DPMI and returns the starting address.
 * Returns NULL iff bsize is 0 or if there is not enough memory.
 * According to https://www.delorie.com/djgpp/doc/dpmi/api/310501.html ,
 * but not the DPMI specification
 * (https://www.phatcode.net/res/262/files/dpmi09.html#13.2), the returned
 * pointer will be aligned to a multiple of 16 bytes (paragraph).
 */
void *__dwlibc_dpmi_alloc(size_t bsize);
#pragma aux __dwlibc_dpmi_alloc = "xor eax, eax"  "jecxz done"  "push eax" \
    "shld ebx, ecx, 16"  "mov ax, 501h"  "int 31h"  "pop eax" \
    "jc short done"  "xchg eax, ebx"  "shl eax, 16"  "xchg ax, cx"  "done:" \
    __value [__eax] __parm [__ecx] \
    __modify __exact [__eax __ebx __ecx __esi __edi]
#endif  /* #ifdef __DOS__ */

/* --- Common parts of the Linux i386 and FreeBSD i386 implementations. */

#if defined(__LINUX__) && !defined(__DOS__) && !defined(__NT__)

#ifdef _LIBC_USE_MAIN1
/* Returns the number of bytes needed by append_arg_quoted(arg).
 * Based on
 * https://learn.microsoft.com/en-us/archive/blogs/twistylittlepassagesallalike/everyone-quotes-command-line-arguments-the-wrong-way
 */
static __inline size_t __watcall __dwlibc_get_arg_quoted_size(
    const char *arg) {
  const char *p;
  size_t size = 1;  /* It starts with space even if it's the first argument. */
  size_t bsc;  /* Backslash count. */
  for (p = arg; *p != '\0' && *p != ' ' && *p != '\t' && *p != '\n' &&
                *p != '\v' && *p != '"'; ++p) {}
  if (p != arg && *p == '\0') return size + (p - arg);  /* No need to quote. */
  size += 2;  /* Two '"' quotes, one on each side. */
  for (p = arg; ; ++p) {
    for (bsc = 0; *p == '\\'; ++p, ++bsc) {}
    if (*p == '\0') {
      size += bsc << 1;
      break;
    }
    if (*p == '"') bsc = (bsc << 1) + 1;
    size += bsc + 1;
  }
  return size;
}

/* Appends the quoted (escaped) arg to pout, always starting with a space,
 * and returns the new pout. Implements the inverse of parts of
 * CommandLineToArgvW(...). Implementation corresponds to
 * get_arg_quoted_size(arg). Based on
 * https://learn.microsoft.com/en-us/archive/blogs/twistylittlepassagesallalike/everyone-quotes-command-line-arguments-the-wrong-way
 */
static __inline char * __watcall __dwlibc_append_arg_quoted(
    char *pout, const char *arg) {
  const char *p;
  size_t bsc;  /* Backslash count. */
  *pout++ = ' ';  /* It starts with space even if it's the first argument. */
  for (p = arg; *p != '\0' && *p != ' ' && *p != '\t' && *p != '\n' &&
                *p != '\v' && *p != '"'; ++p) {}
  if (p != arg && *p == '\0') {  /* No need to quote. */
    for (p = arg; *p != '\0'; *pout++ = *p++) {}
    return pout;
  }
  *pout++ = '"';
  for (p = arg; ; *pout++ = *p++) {
    for (bsc = 0; *p == '\\'; ++p, ++bsc) {}
    if (*p == '\0') {
      for (bsc <<= 1; bsc != 0; --bsc, *pout++ = '\\') {}
      break;
    }
    if (*p == '"') bsc = (bsc << 1) + 1;
    for (; bsc != 0; --bsc, *pout++ = '\\') {}
  }
  *pout++ = '"';
  return pout;
}
#endif /* #ifdef _LIBC_USE_MAIN1 */

extern char _edata[], _end[];  /* Populated by wlink. */

/* It is the responsibility of the kernel to fill the entire BSS with NUL
 * bytes. However, some early Linux kernels (such as 1.0 and 1.0.4, but not
 * 5.4.0) fail to do so for first last page of _BSS (i.e. the page which
 * overlaps with _TEXT) if an overlay (i.e. resource data) is present in the
 * file. Hence we fill it manually.
 *
 * This doesn't work if _BSS is empty (because wlink generates _end == 0
 * then), but for us it's never empty, it always has e.g.
 * __dwlibc_alloc_end.
 */
#define __DWLIBC_ASMB_FILLBSSPAGE1 \
    __asm { mov esi, offset _end   }  /* End of _BSS.  */ \
    __asm { mov edi, offset _edata }  /* End of _DATA. */ \
    __asm { mov ecx, edi } \
    __asm { add ecx,  1000h-1 } \
    __asm { and ecx, -1000h }  /* Round up to i386 page boundary. */ \
    __asm { cmp ecx, esi } \
    __asm { db 76h, 2 }  /* jna short have_end_in_ecx */ \
    __asm { mov ecx, esi }  /* Stop at end of _BSS, within first page. */ \
    __asm { have_end_in_ecx: sub ecx, edi } \
    __asm { xor eax, eax } __asm { rep stosb }
#define __DWLIBC_ASMB_GET_ARGV \
    __asm { pop eax }  /* EAX := argc. */ \
    __asm { test eax, eax } __asm { mov eax, esp }  /* EAX := argv. */\
    __asm { db 74h, 3 }  /* jz short argv_ok */ \
    __asm { add eax, 4 }  /* Skip argv[0]. */ __asm { argv_ok: }
#define __DWLIBC_ASMB_ARGV_TO_CMDLINE \
    __asm { mov esi, eax }  /* ESI := argv. */ \
    __asm { xchg ecx, eax }  /* ECX := argv; EAX := junk. */ \
    __asm { mov edx, 1+1+3 } \
    __asm { measure_loop: lodsd } \
    __asm { test eax, eax } \
    __asm { db 74h, 9 }  /* jz short after_measure_loop */ \
    __asm { call __dwlibc_get_arg_quoted_size } \
    __asm { add edx, eax } \
    __asm { db 0ebh, -14 }  /* jmp short measure_loop */ \
    __asm { after_measure_loop: and edx, -4 }  /* Up dword, +3 above. */ \
    __asm { sub esp, edx }  /* alloca() on the stack. */ \
    __asm { mov eax, esp }  /* EAX := allocated cmdline. */ \
    __asm { join_loop: mov edx, [ecx] } \
    __asm { test edx, edx } \
    __asm { db 74h, 10 }  /* jz short after_join_loop */ \
    __asm { add ecx, 4 } \
    __asm { call __dwlibc_append_arg_quoted } \
    __asm { db 0ebh, -16 }  /* jmp short join_loop */ \
    __asm { after_join_loop: cmp eax, esp } \
    __asm { mov [eax], dl }  /* DL == 0. Trailing NUL. */ \
    __asm { db 74h, 3 }  /* je short cmdline_ok */ \
    __asm { mov eax, esp }  /* Restore return value: cmdline. */ \
    __asm { inc eax }  /* Skip first space. */  \
    __asm { cmdline_ok: }

#endif  /* #if defined(__LINUX__) && !defined(__DOS__) && !defined(__NT__) */

/* --- Linux i386 implementation. */

#if defined(__LINUX__) && !defined(__FREEBSD__) && !defined(__DOS__) && !defined(__NT__)

/* Actually, this defines the _dwlibcstart_ function. We do it using a macro
 * so that _dwlibcstart_ is only defined where the C source file defines
 * `int main1(const char *cmdline) { ... }'. The benefit is that the program
 * can be split to multiple C source files, and only one of them will define
 * _dwlibcstart_ and thus the `redefinition of _dwlibcstart_' error by wlink
 * is avoided. As a negative side effect of this hack, it is not possible to
 * reference main1 anywhere else in the source C file.
 *
 * This implements the 32-bit i386 program entry point the Linux kernel
 * jumps to.
 */
#ifdef _LIBC_USE_MAIN
#  define main(argspec1, argspec2) \
      /*int*/ __declspec(naked) __watcall _dwlibcstart(void) { \
      /*__asm { cld }*/  /* Not needed for Linux. */ \
      __DWLIBC_ASMB_FILLBSSPAGE1 \
      __asm { pop eax }  /* EAX := argc. */ \
      __asm { mov edx, esp }  /* EDX := argv. */ \
      __asm { call main }  /* Takes EAX, EDX. */ \
      __asm { movzx ebx, al } __asm { xor eax, eax } __asm { inc eax } \
      __asm { int 80h } } \
      size_t __dwlibc_alloc_remaining, __dwlibc_alloc_next_bsize; \
      unsigned char *__dwlibc_alloc_end; \
      void *cstart_; int _argc;  /* Pacify wlink. */ \
      int main(argspec1, argspec2)
#endif
#ifdef _LIBC_USE_MAIN1
#  define main1(argspec1) \
      /*int*/ __declspec(naked) __watcall _dwlibcstart(void) { \
      /*__asm { cld }*/  /* Not needed for Linux. */ \
      __DWLIBC_ASMB_FILLBSSPAGE1 \
      __DWLIBC_ASMB_GET_ARGV __DWLIBC_ASMB_ARGV_TO_CMDLINE \
      __asm { call main1 } \
      __asm { movzx ebx, al } __asm { xor eax, eax } __asm { inc eax } \
      __asm { int 80h } } \
      size_t __dwlibc_alloc_remaining, __dwlibc_alloc_next_bsize; \
      unsigned char *__dwlibc_alloc_end; \
      int main1(argspec1)
#endif

#pragma aux  exit = "movzx ebx, al"  "xor eax, eax"  "inc eax"  "int 80h" \
    __parm [__al] __modify __exact []
#pragma aux _exit = "movzx ebx, al"  "xor eax, eax"  "inc eax"  "int 80h" \
    __parm [__al] __modify __exact []

/* !!! Add j... short everywhere, even above. */

#pragma aux open00 = "push 5"  "pop eax"  "push 0"  "pop ecx" \
    "int 80h"  "test eax, eax"  "jns short done"  "or eax, -1"  "done:" \
    __value [__eax] __parm [__ebx] __modify __exact [__eax __ecx]

/* !! Call creat(2) instead. */
#pragma aux creat1 = "push 5"  "pop eax"  "mov ecx, 241h"  "mov edx, 666q" \
    "int 80h"  "test eax, eax"  "jns short done"  "or eax, -1"  "done:" \
    __value [__eax] __parm [__ebx] __modify __exact [__eax __ecx __edx]

#pragma aux close = "push 6"  "pop eax"  "int 80h"  "test eax, eax" \
    "jns short done"  "or eax, -1"  "done:" \
    __value [__eax] __parm [__ebx] __modify __exact [__eax]

#pragma aux read = "push 3"  "pop eax"  "int 80h"  "test eax, eax" \
    "jns short done"  "or eax, -1"  "done:" \
    __value [__eax] __parm [__ebx] [__ecx] [__edx] __modify __exact [__eax]

#pragma aux write = "push 4"  "pop eax"  "int 80h"  "test eax, eax" \
    "jns short done"  "or eax, -1"  "done:" \
    __value [__eax] __parm [__ebx] [__ecx] [__edx] __modify __exact [__eax]

/* Does `return ioctl(fd, TCGETS, buf_0x24) == 0;'. */
#pragma aux isatty = "push 54"  "pop eax"  "sub esp, 24h"  "mov ecx, 5401h" \
    "mov edx, esp"  "int 80h"  "add esp, 24h"  "cmp eax, 1"  "sbb eax, eax" \
    "neg eax" \
    __value [__eax] __parm [__ebx] __modify __exact [__eax __ecx __edx]

#pragma aux lseek = "push 19"  "pop eax"  "int 80h"  "test eax, eax" \
    "jns short done"  "or eax, -1"  "done:" \
    __value [__eax] __parm [__ebx] [__ecx] [__edx] __modify __exact [__eax]

#pragma aux ftruncate_here = "push 19"  "pop eax"  "xor ecx, ecx" \
    "xor edx, edx"  "inc edx"  "int 80h"  "js short error"  "xchg ecx, eax" \
    "push 93"  "pop eax"  "int 80h"  "test eax, eax"  "jns short done" \
    "error: or eax, -1"  "done:" \
    __value [__eax] __parm [__ebx] __modify __exact [__eax __ecx __edx]

int __dwlibc_ftruncate_low(int fd, off_t size);
#pragma aux __dwlibc_ftruncate_low = "push ebx"  "xchg ebx, eax" \
    "xchg ecx, edx"  "push 93"  "pop eax"  "int 80h" "xchg ecx, edx" \
    "pop ebx"  "test eax, eax"  "jns short done"  "or eax, -1"  "done:" \
    __value [__eax] __parm [__eax] [__edx] __modify __exact [__eax]

static __inline int ftruncate(int fd, off_t size) {
  return __dwlibc_ftruncate_low(fd, size);
}

#pragma aux remove = "push 10"  "pop eax"  "int 80h"  "test eax, eax" \
    "jns short done"  "or eax, -1"  "done:" \
    __value [__eax] __parm [__ebx] __modify __exact [__eax]
#pragma aux unlink = "push 10"  "pop eax"  "int 80h"  "test eax, eax" \
    "jns short done"  "or eax, -1"  "done:" \
    __value [__eax] __parm [__ebx] __modify __exact [__eax]

void *__dwlibc_mmap_alloc(size_t bsize);
/* 0x22 == (MAP.PRIVATE|MAP.ANONYMOUS_LINUX).
 * 3 == (PROT_READ|PROT_WRITE).
 * 90 == SYS_Linux.ioctl.
 */
#pragma aux __dwlibc_mmap_alloc = "xor ebx, ebx" \
    "push ebx"  "push -1"  "push 22h"  "push 3"  "push eax"  "push ebx" \
    "mov ebx, esp"  "push 90"  "pop eax"  "int 80h"  "add esp, 6*4" \
    "cmp eax, -255"  "jb short done"  "or eax, -1"  "done:" \
    __value [__eax] __parm [__eax] __modify __exact [__eax __ebx]

#endif  /* #if defined(__LINUX__) && !defined(__FREEBSD__) && !defined(__DOS__) && !defined(__NT__) */

/* --- Combined Linux--FreeBSD i386 implementation. */

#if defined(__FREEBSD__) && !defined(__DOS__) && !defined(__NT__)

extern char __dwlibc_is_freebsd;

/*
 * We detect FreeBSD (and set __dwlibc_is_freebsd) like this: pass a
 * negative fd to SYS_write, and we are running on FreeBSD if the result in
 * EAX is positive (i.e. errno); otherwise it's Linux (i.e. -errno).
 *
 * The previous detection used SYS_getpid and checked CF after `int 80h'.
 * This worked on modern Linux kernels (who don't change CF, but FreeBSD
 * i386 sets CF=0 upon success), but `int 80h' Linux 1.0.4 sets CF=0, so it
 * didn't work. Checking the sign of the errno return value is more robust.
 */
#define __DWLIBC_ASMB_DETECT_FREEBSD \
    __asm { xor edx, edx }  __asm { xor ecx, ecx } __asm { or ebx, -1 } \
    __asm { push 4 } __asm { pop eax } __asm { push edx } __asm { push ecx } \
    __asm { push ebx } __asm { push eax } __asm { int 80h } \
    __asm { add esp, 4*4 } __asm { not eax } __asm { shr eax, 31 } \
    __asm { mov [__dwlibc_is_freebsd], al }

/* Actually, this defines the _dwlibcstart_ function. We do it using a macro
 * so that _dwlibcstart_ is only defined where the C source file defines
 * `int main1(const char *cmdline) { ... }'. The benefit is that the program
 * can be split to multiple C source files, and only one of them will define
 * _dwlibcstart_ and thus the `redefinition of _dwlibcstart_' error by wlink
 * is avoided. As a negative side effect of this hack, it is not possible to
 * reference main1 anywhere else in the source C file.
 *
 * This implements the 32-bit i386 program entry point the Linux kernel or
 * the FreeBSD jumps to.
 */
#ifdef _LIBC_USE_MAIN
#  define main(argspec1, argspec2) \
      /*int*/ __declspec(naked) __watcall _dwlibcstart(void) { \
      /*__asm { cld }*/  /* Not needed for Linux. */ \
      __DWLIBC_ASMB_DETECT_FREEBSD \
      __DWLIBC_ASMB_FILLBSSPAGE1 \
      __asm { pop eax }  /* EAX := argc. */ \
      __asm { mov edx, esp }  /* EDX := argv. */ \
      __asm { call main }  /* Takes EAX, EDX. */ \
      __asm { movzx ebx, al } __asm { xor eax, eax } __asm { inc eax } \
      __asm { push ebx } __asm { push ebx } __asm { int 80h } } \
      char __dwlibc_is_freebsd; \
      size_t __dwlibc_alloc_remaining, __dwlibc_alloc_next_bsize; \
      unsigned char *__dwlibc_alloc_end; \
      void *cstart_; int _argc;  /* Pacify wlink. */ \
      int main(argspec1, argspec2)
#endif
#ifdef _LIBC_USE_MAIN1
#  define main1(argspec1) \
      /*int*/ __declspec(naked) __watcall _dwlibcstart(void) { \
      /*__asm { cld }*/  /* Not needed for Linux. */ \
      __DWLIBC_ASMB_DETECT_FREEBSD \
      __DWLIBC_ASMB_FILLBSSPAGE1 \
      __DWLIBC_ASMB_GET_ARGV __DWLIBC_ASMB_ARGV_TO_CMDLINE \
      __DWLIBC_ASMB_INIT_STACKLOWNEG  /* Ruins EBX. */ \
      __asm { call main1 } \
      __asm { movzx ebx, al } __asm { xor eax, eax } __asm { inc eax } \
      __asm { push ebx } __asm { push ebx } __asm { int 80h } } \
      char __dwlibc_is_freebsd; \
      size_t __dwlibc_alloc_remaining, __dwlibc_alloc_next_bsize; \
      unsigned char *__dwlibc_alloc_end; \
      __DWLIBC_DEFINE_STACKLOWNEG \
      int main1(argspec1)
#endif

#pragma aux  exit = "movzx ebx, al"  "xor eax, eax"  "inc eax"  "push ebx" \
    "push ebx"  "int 80h" __parm [__al] __modify __exact []
#pragma aux _exit = "movzx ebx, al"  "xor eax, eax"  "inc eax"  "push ebx" \
    "push ebx"  "int 80h" __parm [__al] __modify __exact []

#pragma aux open00 = "push 5"  "pop eax" \
    "cmp [__dwlibc_is_freebsd], ah"  "jne short freebsd" \
    "push 0"  "pop ecx"  "int 80h" \
    "test eax, eax"  "jns short done"  "jmp short bad" \
    "freebsd: push 0"  "push ebx"  "push eax"  "int 80h" \
    "lea esp, [esp+3*4]"  "jnc short done"  "bad: or eax, -1"  "done:" \
    __value [__eax] __parm [__ebx] __modify __exact [__eax __ecx]

#pragma aux creat1 = "push 5"  "pop eax" \
    "cmp [__dwlibc_is_freebsd], ah"  "jne short freebsd" \
    "mov ecx, 241h"  "mov edx, 666q"  "int 80h" \
    "test eax, eax"  "jns short done"  "jmp short bad" \
    "freebsd: push 666q"  "push 601h"  "push ebx"  "push eax"  "int 80h" \
    "lea esp, [esp+4*4]"  "jnc short done"  "bad: or eax, -1"  "done:" \
    __value [__eax] __parm [__ebx] __modify __exact [__eax __ecx __edx]

#pragma aux close = "push 6"  "pop eax" \
    "cmp [__dwlibc_is_freebsd], ah"  "jne short freebsd" "int 80h" \
    "test eax, eax"  "jns short done"  "jmp short bad" \
    "freebsd: push ebx"  "push eax"  "int 80h" \
    "lea esp, [esp+2*4]"  "jnc short done"  "bad: or eax, -1"  "done:" \
    __value [__eax] __parm [__ebx] __modify __exact [__eax]

#pragma aux read = "push 3"  "pop eax" \
    "cmp [__dwlibc_is_freebsd], ah"  "jne short freebsd" "int 80h" \
    "test eax, eax"  "jns short done"  "jmp short bad" \
    "freebsd: push edx"  "push ecx"  "push ebx"  "push eax"  "int 80h" \
    "lea esp, [esp+4*4]"  "jnc short done"  "bad: or eax, -1"  "done:" \
    __value [__eax] __parm [__ebx] [__ecx] [__edx] __modify __exact [__eax]

#pragma aux write = "push 4"  "pop eax" \
    "cmp [__dwlibc_is_freebsd], ah"  "jne short freebsd" "int 80h" \
    "test eax, eax"  "jns short done"  "jmp short bad" \
    "freebsd: push edx"  "push ecx"  "push ebx"  "push eax"  "int 80h" \
    "lea esp, [esp+4*4]"  "jnc short done"  "bad: or eax, -1"  "done:" \
    __value [__eax] __parm [__ebx] [__ecx] [__edx] __modify __exact [__eax]

/* Does `return ioctl(fd, TCGETS//TIOCGETA, buf_0x2c) == 0;'. */
#pragma aux isatty = "push 54"  "pop eax"  "sub esp, 2ch"  "mov edx, esp" \
    "cmp [__dwlibc_is_freebsd], ah"  "jne short freebsd" \
    "mov ecx, 5401h"  "int 80h"  "jmp short got" \
    "freebsd: push edx"  "push 402c7413h"  "push ebx"  "push eax"  "int 80h" \
    "lea esp, [esp+4*4]"  "jnc short got"  "sbb eax, eax" \
    "got: add esp, 2ch"  "cmp eax, 1"  "sbb eax, eax"  "neg eax" \
    __value [__eax] __parm [__ebx] __modify __exact [__eax __ecx __edx]

#pragma aux lseek = "push 19"  "pop eax"  \
    "cmp [__dwlibc_is_freebsd], ah"  "jne short freebsd" "int 80h" \
    "test eax, eax"  "jns short done"  "jmp short bad" \
    "freebsd: push edx"  "mov eax, ecx"  "cdq"  "push edx"  "push eax" \
    "push eax"  "push ebx"  "push eax"  "xor eax, eax"  "mov al, 199"  \
    "int 80h"  "lea esp, [esp+5*4]"  "jc short bad1"  "test edx, edx" \
    "pop edx"  "jnz short bad"  "test eax, eax"  "jns short done" \
    "db 0a8h"  "bad1: pop edx"  "bad: or eax, -1"  "done:" \
    __value [__eax] __parm [__ebx] [__ecx] [__edx] __modify __exact [__eax]

#pragma aux ftruncate_here = "push 19"  "pop eax" \
    "cmp [__dwlibc_is_freebsd], ah"  "jne short freebsd"  "xor ecx, ecx" \
    "xor edx, edx"  "inc edx"  "int 80h"  "js short bad"  "xchg ecx, eax" \
    "push 93"  "pop eax"  "int 80h"  "test eax, eax"  "jns short done" \
    "jmp short bad"  "freebsd: mov al, 199"  "push 1"  "push 0"  "push 0" \
    "push eax"  "push ebx"  "push eax"  "int 80h"  "lea esp, [esp+6*4]"  \
    "jc short bad"  "push edx"  "push eax"  "xor eax, eax"  "mov al, 201" \
    "push eax"  "push ebx"  "push eax"  "int 80h" \
    "lea esp, [esp+5*4]"  "jnc short done"  "bad: or eax, -1"  "done:" \
    __value [__eax] __parm [__ebx] __modify __exact [__eax __ecx __edx]

int __dwlibc_ftruncate_low(int fd, off_t size);
#pragma aux __dwlibc_ftruncate_low = "push ebx"  "xchg ebx, eax" \
    "xchg ecx, edx"  "push 93"  "pop eax"  "cmp [__dwlibc_is_freebsd], ah" \
    "jne short freebsd"  "int 80h"  "mov ecx, edx"  \
    "test eax, eax"  "jns short done"  "jmp short bad"  "freebsd: push edx" \
    "xchg eax, ecx"  "cdq"  "push edx"  "push eax"  "push eax"  "push ebx" \
    "xor eax, eax"  "mov al, 201"  "push eax"  "int 80h" \
    "lea esp, [esp+5*4]"  "pop ecx"  "jnc short done"  "bad: or eax, -1" \
    "done: pop ebx" \
    __value [__eax] __parm [__eax] [__edx] __modify __exact [__eax]
static __inline int ftruncate(int fd, off_t size) {
  return __dwlibc_ftruncate_low(fd, size);
}

#pragma aux remove = "push 10"  "pop eax" \
    "cmp [__dwlibc_is_freebsd], ah"  "jne short freebsd" "int 80h" \
    "test eax, eax"  "jns short done"  "jmp short bad" \
    "freebsd: push ebx"  "push eax"  "int 80h" \
    "lea esp, [esp+2*4]"  "jnc short done"  "bad: or eax, -1"  "done:" \
    __value [__eax] __parm [__ebx] __modify __exact [__eax]
#pragma aux unlink = "push 10"  "pop eax" \
    "cmp [__dwlibc_is_freebsd], ah"  "jne short freebsd" "int 80h" \
    "test eax, eax"  "jns short done"  "jmp short bad" \
    "freebsd: push ebx"  "push eax"  "int 80h" \
    "lea esp, [esp+2*4]"  "jnc short done"  "bad: or eax, -1"  "done:" \
    __value [__eax] __parm [__ebx] __modify __exact [__eax]

void *__dwlibc_mmap_alloc(size_t bsize);
/* 0x22 == (MAP.PRIVATE|MAP.ANONYMOUS_LINUX).
 * 0x1002 == (MAP.PRIVATE|MAP.ANONYMOUS_FREEBSD).
 * 3 == (PROT_READ|PROT_WRITE).
 * 90 == SYS_Linux.ioctl.
 */
#pragma aux __dwlibc_mmap_alloc = "xor ebx, ebx"  "push ebx"  "push ebx" \
    "push ebx"  "push -1"  "push 22h"  "push 3"  "push eax"  "push ebx" \
    "cmp [__dwlibc_is_freebsd], bl"  "jne short freebsd" \
    "mov ebx, esp"  "push 90"  "pop eax"  "int 80h" \
    "cmp eax, -255"  "jb short done"  "or eax, -1"  "jmp short done" \
    "freebsd: mov word ptr [esp+3*4], 1002h"  "mov bl, 197"  "xchg eax, ebx" \
    "push eax"  "int 80h"  "pop ebx" \
    "jnc short done"  "sbb eax, eax"  "done: add esp, 8*4" \
    __value [__eax] __parm [__eax] __modify __exact [__eax __ebx]

#endif  /* #if defined(__FREEBSD__) && !defined(__DOS__) && !defined(__NT__) */

/* --- Memory allocator. */

#ifndef __ANYOS__
static __inline void *malloc(size_t size) {
  unsigned char *p;
  size_t bsize;
  if ((int)size <= 0) return NULL;
  size = (size + 3) & ~3;  /* Force alignment of everything to 4. */
  /* We don't allocate a new block for each malloc(...) call so that we
   * don't risk running out of XMS handles on some DPMI hosts. Instead of
   * that we allocate large blocks (starting at 256 KiB and doubling it each
   * time), and portion them out here.
   */
  if (size <= __dwlibc_alloc_remaining) {  /* Take from current block. */
    p = __dwlibc_alloc_end - __dwlibc_alloc_remaining;
    __dwlibc_alloc_remaining -= size;
    return (void*)p;
  }
  /* At this point we will allocate a new block, and effectively waste the
   * remaining __dwlibc_alloc_remaining bytes in the current block.
   */
  if (!(bsize = __dwlibc_alloc_next_bsize)) bsize = 1 << 18;  /* 256 KiB. */
  while (bsize < size) {  /* At least size rounded to the next power of 2. */
    if ((int)(bsize <<= 1) <= 0) return NULL;
  }
  for (;;) {
#ifdef __NT__
#  ifdef __DOS__  /* While still #ifdef __NT__. */
    p = (__dwlibc_is_dos) ? __dwlibc_dpmi_alloc(bsize) :
        VirtualAlloc(NULL, bsize, MEM_COMMIT, PAGE_READWRITE);
#  else  /* VirtualAlloc(...) returns a page-aligned (4 KiB) pointer. */
    p = VirtualAlloc(NULL, bsize, MEM_COMMIT, PAGE_READWRITE);
#  endif
#else
#  ifdef __DOS__
    p = __dwlibc_dpmi_alloc(bsize);
#  else
#    ifdef __LINUX__
    p = __dwlibc_mmap_alloc(bsize);
#    else
#      error Unknown system for malloc(...).
    p = NULL;
#    endif
#  endif
#endif
    if (p) break;
    /* Minimum bsize is 4 KiB. */
    if ((bsize >>= 1) < (1 << 12) || bsize < size) return NULL;
  }
  __dwlibc_alloc_next_bsize = ((int)(bsize << 1) > 0) ? bsize << 1 : bsize;
  __dwlibc_alloc_end = p + bsize;
  __dwlibc_alloc_remaining = bsize - size;
  return (void*)p;
}
#endif  /* #ifndef __ANYOS__ */

#endif  /* #ifdef _DWLIBC_H */
