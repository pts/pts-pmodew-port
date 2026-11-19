/* by pts@fazekas.hu at Wed Nov 18 15:08:02 CET 2026
 *
 * Compile and run with: ./dwlibcc -bfreebsdx -s -Os -W -Wall -Wextra -Werror -std=c89 -o ftruncate_test ftruncate_test.c && ./ftruncate_test; echo $?
 * Compile and run with: ./dwlibcc -blinux -s -Os -W -Wall -Wextra -Werror -std=c89 -o ftruncate_test ftruncate_test.c && ./ftruncate_test; echo $?
 * Compile and run with: ./dwlibcc -s -Os -W -Wall -Wextra -Werror -std=c89 -o ftrt.exe ftruncate_test.c && dosbox.nox.static --cmd ftrt.exe; echo $?
 */

#define _LIBC_USE_MAIN0
#include <dwlibc.h>

static void write_stderr(const char *msg) {
  (void)!write(STDERR_FILENO, msg, strlen(msg));
}

static __declspec(noreturn) void fatal(const char *msg) {
  write_stderr("fatal: ");
  write_stderr(msg);
  write_stderr(_LIBC_NL_STR);
  _exit(2);
}

static char is_file_contents_size(int fd, const char *data, size_t data_size, char is_prefix) {
  const off_t file_pos = lseek(fd, 0, SEEK_CUR);
  const off_t file_size = (file_pos < 0) ? (off_t)-1 : lseek(fd, 0, SEEK_END);
  char buf[16];

  if (file_pos < 0) fatal("is/lseek_cur");
  if (file_size < 0) fatal("is/lseek_end");
  if ((is_prefix) ? (file_size < (off_t)data_size) : (file_size != (off_t)data_size)) fatal("is/bad_size");
  if (file_size > sizeof(buf)) fatal("is/file_too_long");
  if (lseek(fd, 0, SEEK_SET) != 0) fatal("is/lseek_start");
  if ((off_t)read(fd, buf, data_size) != (off_t)data_size) fatal("is/read");
  if (lseek(fd, file_pos, SEEK_SET) != file_pos) fatal("is/lseek_back");
  return memcmp(buf, data, data_size) == 0;
}

static char is_file_contents(int fd, const char *data) {
  return is_file_contents_size(fd, data, strlen(data), 0);
}

static char is_file_contents_prefix(int fd, const char *data) {
  return is_file_contents_size(fd, data, strlen(data), 1);
}

main0() {
  const char *filename;
  int fd;

  filename = main0_argv1();
  if (main0_is_progarg_null(filename) || filename[0] == '\0') filename = "ftrt.bin";
  if (_LIBC_HAS_OPEN_FAILED(fd = creat1(filename))) fatal("creat");
  close(fd);  /* We close it, because creat1(...) opens it for write-only (O_WRONLY). */
  if (_LIBC_HAS_OPEN_FAILED(fd = open(filename, O_RDWR))) fatal("open");
  if (write(fd, "TestData", 8) != 8) fatal("write");
  if (!is_file_contents(fd, "TestData")) fatal("is1");
#ifdef DEBUG  /* Can be defined on the command line. */
  write_stderr("1");
#endif

  if (lseek(fd, 0, SEEK_END) != 8) fatal("lseek0");
  if (ftruncate_here(fd) != 0) fatal("ftruncate_here0");
  if (lseek(fd, 0, SEEK_CUR) != 8) fatal("lseek0b");
  if (!is_file_contents(fd, "TestData")) fatal("is0");
#ifdef DEBUG  /* Can be defined on the command line. */
  write_stderr("2");
#endif

  if (lseek(fd, 0, SEEK_END) != 8) fatal("lseek1");
  if (ftruncate(fd, 8) != 0) fatal("ftruncate1");
  if (lseek(fd, 0, SEEK_CUR) != 8) fatal("lseek1b");
  if (!is_file_contents(fd, "TestData")) fatal("is1");
#ifdef DEBUG  /* Can be defined on the command line. */
  write_stderr("3");
#endif

  if (lseek(fd, -1, SEEK_END) != 7) fatal("lseek2");
  if (ftruncate_here(fd) != 0) fatal("ftruncate_here2");
  if (lseek(fd, 0, SEEK_CUR) != 7) fatal("lseek2b");
  if (!is_file_contents(fd, "TestDat")) fatal("is2");
#ifdef DEBUG  /* Can be defined on the command line. */
  write_stderr("4");
#endif

  if (lseek(fd, -2, SEEK_END) != 5) fatal("lseek3");
  if (ftruncate(fd, 9) != 0) fatal("ftruncate3");
  if (lseek(fd, 0, SEEK_CUR) != 5) fatal("lseek3b");
  if (lseek(fd, 0, SEEK_END) != 9) fatal("lseek3c");
#if 0  /* The last two bytes are not guaranteed to be '\0' on DOS and Windows 95--98--ME. */
  if (!is_file_contents_size(fd, "TestDat\0", 9)) fatal("is3");
#else
  if (!is_file_contents_prefix(fd, "TestDat")) fatal("is3");
#endif
#ifdef DEBUG  /* Can be defined on the command line. */
  write_stderr("5");
#endif

  if (lseek(fd, 5, SEEK_SET) != 5) fatal("lseek4");
  if (ftruncate(fd, 4) != 0) fatal("ftruncate4");
  if (lseek(fd, 0, SEEK_CUR) != 5) fatal("lseek4b");
  if (lseek(fd, 0, SEEK_END) != 4) fatal("lseek4c");
  if (!is_file_contents(fd, "Test")) fatal("is4");
#ifdef DEBUG  /* Can be defined on the command line. */
  write_stderr("6");
#endif

  if (lseek(fd, 9, SEEK_SET) != 9) fatal("lseek5");
  if (ftruncate_here(fd) != 0) fatal("ftruncate_here5");
  if (lseek(fd, 0, SEEK_CUR) != 9) fatal("lseek5b");
  if (!is_file_contents_prefix(fd, "Test")) fatal("is5");
#ifdef DEBUG  /* Can be defined on the command line. */
  write_stderr("7");
#endif

  close(fd);
  if (unlink(filename)) fatal("unlink");
  write_stderr("info: ftruncate_test OK." _LIBC_NL_STR);
  main0_exit0();
}
