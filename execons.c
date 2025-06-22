/*
 * execons.c: make DOS .exe created by various TLINK versions consistent
 * by pts@fazekas.hu at Thu Jun 12 12:03:01 CEST 2025
 *
 * This C program is architecture-independent and it works with any
 * sizeof(unsigned).
 *
 * This C program has been tested with GCC (both C and C++), Clang (both C
 * and C++), Turbo C, Borland C and Watcom C.
 */

#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#if defined(_WIN32) || defined(MSDOS) || defined(__MSDOS__) || defined(__NT__) || defined(__DOS__)
#  include <io.h>
#else
#  include <unistd.h>
#endif

#ifndef O_BINARY
#  define O_BINARY 0
#endif

/* !! TODO(pts): Make it smaller for x86. */
static unsigned get_le16(const unsigned char *p) {
  return p[0] | p[1] << 8;
}

/* !! TODO(pts): Make it smaller for x86. */
static void set_le16(unsigned char *p, unsigned v) {
  *p++ = v;
  *p = v >> 8;
}

/* Comprare two DOS .exe relocation entries for qsort(3). */
static int cmp_reloc(const void *va, const void *vb) {
  const unsigned aofs = get_le16((const unsigned char*)va);
  const unsigned aseg = get_le16((const unsigned char*)va + 2);
  const unsigned bofs = get_le16((const unsigned char*)vb);
  const unsigned bseg = get_le16((const unsigned char*)vb + 2);
#if 0  /* Compare by value. */
  /* TODO(pts): If sizeof(unsigned) >= 4, then just use `unsigned' instead of `unsigned long'. */
  const unsigned long aaddr = (aofs + ((unsigned long)aseg << 4)) & 0xfffffUL;
  const unsigned long baddr = (bofs + ((unsigned long)bseg << 4)) & 0xfffffUL;
  return aaddr < baddr ? -1 : aaddr != baddr;
#else  /* Compare by the order in pmw133src/PMODEW.EXE in http://www.sid6581.net/pmodew/pmw133src.zip */
  if (aseg != bseg) return bseg < aseg ? -1 : 1;  /* Segment descending. */
  return aofs < bofs ? -1 : aofs != bofs;  /* Offset ascending. */
#endif
}

static unsigned dirty_size;
static void mark_dirty(unsigned size) {
  if (size > dirty_size) dirty_size = size;
}

static unsigned char buf[0x1000];

static void set_buf_le16_dirty(unsigned ofs, unsigned v) {
  unsigned vold = get_le16(buf + ofs);
  if (v != vold) {
    set_le16(buf + ofs, v);
    ofs += 2;
    if (ofs > dirty_size) dirty_size = ofs;
  }
}

int main(int argc, char **argv) {
  const char *filename;
  int fd;
  unsigned hdrsize, nreloc, relocpos;

  (void)argc;
  if (!argv[0] || !argv[1] || argv[2]) {
    fprintf(stderr, "Usage: %s <prog.exe>\n", argv[0]);
    return 1;
  }
  filename = argv[1];
  if ((fd = open(filename, O_RDWR | O_BINARY)) < 0) {
    fprintf(stderr, "fatal: error opening DOS .exe: %s\n", filename);
    return 2;
  }
  if (read(fd, buf, sizeof(buf)) != (int)sizeof(buf)) {
    fprintf(stderr, "fatal: error reading DOS .exe headers: %s\n", filename);
    return 3;
  }
  if (get_le16(buf) != ('M' | 'Z' << 8)) {
    fprintf(stderr, "fatal: missing DOS .exe signature: %s\n", filename);
    return 10;
  }
  nreloc = get_le16(buf + 3 * 2);
  hdrsize = get_le16(buf + 4 * 2);
  relocpos = get_le16(buf + 12 * 2);
  if (hdrsize > sizeof(buf) >> 4) {
    fprintf(stderr, "fatal: unsupported: DOS .exe hdrsize too large: %s\n", filename);
    return 11;
  }
  if (nreloc) {
    if ((relocpos >> 4) >= hdrsize || (((hdrsize << 4) - relocpos) >> 2) < nreloc) {
      fprintf(stderr, "fatal: DOS .exe relocations don't fit in hdrsize: %s\n", filename);
      return 12;
    }
    if (relocpos < 0x3e && relocpos >= 0x1c && hdrsize > 3 && (((hdrsize << 4) - 0x3e) >> 2) >= nreloc) {
      /* OK with TLINK >=3.0 (it generates relocpos == 0x3e), but TLINK 2.0
       * generates relocpos == 0x22.
       */
      memmove(buf + 0x3e, buf + relocpos, nreloc << 2);
      memset(buf + relocpos, 0, 0x3e - relocpos);
      set_le16(buf + 12 * 2, relocpos = 0x3e);
    }
    /* Sort relocations for consistency.
     *
     * Without this the DOS .exe output of (TASM 5.3 + TLINK 4.01) would
     * differ from of (TASM 4.1 + TLINK 4.01).
     */
    qsort(buf + relocpos, nreloc, 4, cmp_reloc);
    mark_dirty(relocpos + (nreloc << 2));
  }
  if (hdrsize >= 2 && (nreloc == 0 || relocpos >= 0x20)) {
    set_buf_le16_dirty(0x1c, 1);
    /* This value seems to depend on the TLINK version number.
     *
     * * TLINK 2.0: dw 0x20fb, 0x6a72
     * * TLINK 3.0--4.01 (last tlink.exe running on a 8086, we imitate this): dw 0x30fb, 0x726a
     * * TLINK 5.0--5.1--??: (used by pmw133src/PMODEW.EXE): dw 0x50fb, 0x726a
     * * TLINK 7.0: dw 0x61fb, 0x726a
     */
    set_buf_le16_dirty(0x1e, 0x30fb);  /* We imitate TLINK 3.0--4.01. */
  }
  if (hdrsize >= 3 && (nreloc == 0 || relocpos >= 0x22)) {
    /* OK with TLINK >=3.0, but TLINK 2.0 generates 0x6a72 here. */
    set_buf_le16_dirty(0x20, 0x726a);  /* We imitate TLINK 3.0--4.01--7.0. */
  }
  if (dirty_size) {
    if (lseek(fd, 0, SEEK_SET) != 0) {
      fprintf(stderr, "fatal: error seeking in DOS .exe: %s\n", filename);
      return 4;
    }
    if (write(fd, buf, dirty_size) != (int)dirty_size) {
      fprintf(stderr, "fatal: error writing DOS .exe headers: %s\n", filename);
      return 5;
    }
  }
  return 0;
}
