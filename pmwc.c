/*
 * pmwc.c: PMODE/W stub compressor
 * by pts@fazekas.hu at Wed Jun 11 01:25:35 CEST 2025
 *
 * Compile with: owcc -blinux -I"$WATCOM/lh" -Os -s -fno-stack-check -march=i386 -W -Wall -Wno-n308 -DCOMPRESS_BITS=16 -DCOMPRESS_BITREV=1 -DCOMPRESS_M1BITFIRST=1 -DCOMPRESS_EARLYNEXTBLOCK=1 -DCOMPRESS_LONGDIST=1 -DDEBUG -o pmwc pmwc.c
 *
 * This compressor is not a general DOS .exe executable compressor (packer),
 * it has many hidden assumption of its input, not only its size (<~60 KiB,
 * typically 16 KiB).
 *
 * This compressor implements a variant of LZSS, with a stream encoding
 * similar to PMWLITE 1.34, but there are some feature differences (see FD?)
 * below.
 *
 * Feature differences (FD?) between the PMODE/W 1.33 stub compressor and PMWLITE (both 1.33 and 1.34) compression stream format:
 *
 * FD1. The PMODE/W 1.33 stub uses -DCOMPRESS_BITS=16 (block size is 16 bits rather than 32 bits); PMWLITE uses -DCOMPRESS_BITS=32.
 * FD2. The PMODE/W 1.33 stub uses -DCOMPRESS_BITREV=1 in the compressor.(bit order within a block is lowest bit first); PMWLITE uses -DCOMPRESS_BITREV=0.
 * FD3. The PMODE/W 1.33 stub uses -DCOMPRESS_M1BITFIRST=1 (the distance byte of match_1 is read after the next bit); PMWLITE uses -DCOMPRESS_M1BITFIRST=0.
 * FD4. The PMODE/W 1.33 stub uses -DCOMPRESS_EARLYNEXTBLOCK=1 (the next block is read at the end of the previous block, not later, when its first bit is first needed); PMWLITE uses -DCOMPRESS_EARLYNEXTBLOCK=0.
 * FD5. The PMODE/W 1.33 stub compressor uses -DCOMPRESS_LONGDIST=1 (for each match, the longest distance whose bit encoding is not longer than of the shortest distance is used, rather than the shortest distance), the decompressor doesn't care; PMWLITE uses -DCOMPRESS_LONGDIST=0.
 *
 * For DOS, this program can compiled with the small memory model (<64 KiB of data usage in total): `tcc -ms' or `owcc -mcmodel=s'.
 *
 * Pseudo-logic to decompress data:
 *
 * movestring2:
 *   len = 2;
 *
 * movestring:
 *   MOVE ($ - off, len);
 *
 * decode:
 *   literal_0:
 *     PUT (GETBYTE ());
 *
 *     GOTO decode;
 *
 *   match_1:
 *     off[0-7] = GETBYTE ();
 *
 *     match_1_0:
 *       match_1_0_0:
 *         if (!off)
 *           GOTOEXE ();
 *         off -= 1;
 *
 *         GOTO movestring2;
 *
 *       match_1_0_1:
 *         off[10] = GETBIT ();
 *         off[9] = GETBIT ();
 *         off[8] = GETBIT ();
 *
 *         GOTO movestring2;
 *
 *     match_1_1:
 *       match_1_1_1:
 *         count = GETBIT ();
 *
 *         REPEAT ((count + 1) * 2)
 *         {
 *           SHL (off[8-15], 1);
 *           off[8] = GETBIT ();
 *         }
 *
 *       match_1_1_0:
 *         len = 2;
 *
 *         REPEAT (4)
 *         {
 *           len ++;
 *
 *           if (GETBIT ())
 *             GOTO movestring;
 *         }
 *
 *         match_1_1_0_0:
 *           len = (len << 1) | GETBIT ();
 *           len = (len << 1) | GETBIT ();
 *           len = (len << 1) | GETBIT ();
 *           len += 7;
 *
 *           GOTO movestring;
 *
 *         match_1_1_0_1:
 *           len[0-7] = GETBYTE ();
 *           len += 15;
 *
 *           GOTO movestring;
 */

#if 0
#  include <mem.h>
#  include <malloc.h>
#endif
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#if defined(_WIN32) || defined(MSDOS) || defined(__MSDOS__) || defined(__NT__) || defined(__DOS__)
#  include <io.h>
#else
#  include <unistd.h>
#endif

#ifdef PMWV  /* Apply defaults to make the compiler command line shorter for DOS. */
#  ifndef COMPRESS_BITS
#    define COMPRESS_BITS 16
#  endif
#  ifndef COMPRESS_BITREV
#    define COMPRESS_BITREV 1
#  endif
#  ifndef COMPRESS_M1BITFIRST
#    define COMPRESS_M1BITFIRST 1
#  endif
#  ifndef COMPRESS_EARLYNEXTBLOCK
#    define COMPRESS_EARLYNEXTBLOCK 1
#  endif
#  ifndef COMPRESS_LONGDIST
#    define COMPRESS_LONGDIST 1
#  endif
#endif

#ifndef PMWV
#  define PMWV 33  /* PMODE/W Minor version number. The full version number is 1.33. */
#endif

#ifndef COMPRESS_BITS  /* !! Provide good defaults. */
#  error ERROR_MISSING_COMPRESS_BITS
#elif COMPRESS_BITS==8
#  define Compress Compress8
#elif COMPRESS_BITS==16
#  define Compress Compress16
#elif COMPRESS_BITS==32
#  define Compress Compress32
#else
#  error ERROR_BAD_COMPRESS_BITS COMPRESS_BITS
#endif

#ifndef COMPRESS_BITREV
#  error ERROR_MISSING_COMPRESS_BITREV
#elif COMPRESS_BITREV
#  undef  COMPRESS_BITREV
#  define COMPRESS_BITREV 1
#else
#  undef  COMPRESS_BITREV
#  define COMPRESS_BITREV 0
#endif

#ifndef COMPRESS_LONGDIST
#  error ERROR_MISSING_COMPRESS_LONGDIST
#elif COMPRESS_LONGDIST
#  undef  COMPRESS_LONGDIST
#  define COMPRESS_LONGDIST 1
#else
#  undef  COMPRESS_LONGDIST
#  define COMPRESS_LONGDIST 0
#endif

#ifndef COMPRESS_M1BITFIRST
#  error ERROR_MISSING_COMPRESS_M1BITFIRST
#elif COMPRESS_M1BITFIRST
#  undef  COMPRESS_M1BITFIRST
#  define COMPRESS_M1BITFIRST 1
#else
#  undef  COMPRESS_M1BITFIRST
#  define COMPRESS_M1BITFIRST 0
#endif

#ifndef COMPRESS_EARLYNEXTBLOCK
#  error ERROR_MISSING_COMPRESS_EARLYNEXTBLOCK
#elif COMPRESS_EARLYNEXTBLOCK
#  undef  COMPRESS_EARLYNEXTBLOCK
#  define COMPRESS_EARLYNEXTBLOCK 1
#else
#  undef  COMPRESS_EARLYNEXTBLOCK
#  define COMPRESS_EARLYNEXTBLOCK 0
#endif

#define ENCODE_NOTENOUGHMEM     -1
#define ENCODE_ERRORREADING     -2
#define ENCODE_ERRORWRITING     -3
#define ENCODE_EMPTY            -4

#define ENCODE_PROBESMAX        4080
#define ENCODE_PROBESMANY       100
#define ENCODE_PROBESNORM       30
#define ENCODE_PROBESFEW        10
#define ENCODE_PROBESMIN        4

/* --- encode.c */

static int PutCode(void);
static int BufInit(FILE *dst, FILE *src, unsigned size);
static void BufUninit(void);
static void BufPutBit(int b);
static void BufPutBits(int b, int c);
static int BufUpdate(void);
static int BufFlush(void);
static int HashInit(void);
static void HashUninit(void);
static void HashAdd(unsigned short h, int v);
static void HashDelete(unsigned short h);
static int HashFind(unsigned short h);
static int FindCommonPrefixLength(const unsigned char *s1, const unsigned char *s2, int size);
#if COMPRESS_EARLYNEXTBLOCK
static void BufInitBitOPos(void);
#else
#  define BufInitBitOPos() do {} while (0)
#endif

#ifdef DEBUG
#  include <stdio.h>
#endif


/* __WATCOMC__ has min(3), but glibc doesn't have min(3). */
static int mymin(int a, int b) { return a < b ? a : b; }

static unsigned char *mymincp(unsigned char *a, unsigned char *b) { return a < b ? a : b; }

#if COMPRESS_BITS==32
  /* !! TODO(pts): Make it smaller for x86 (with little-endian unaligned memory access). */
  static void set_le32(unsigned char *p, unsigned long v) {
    *p++ = v;
    *p = v >> 8;
    *p = v >> 16;
    *p = v >> 24;
  }
#endif

/* !! TODO(pts): Make it smaller for x86 (with little-endian unaligned memory access). */
static void set_le16(unsigned char *p, unsigned v) {
  *p++ = v;
  *p = v >> 8;
}
#define set_byte(p, v) (*(p) = (v))

#if COMPRESS_BITS==8
  typedef unsigned char bufbit_t;
#  define set_block_word(p, v) set_byte(p, v)
#elif COMPRESS_BITS==16
  typedef unsigned short bufbit_t;
#  define set_block_word(p, v) set_le16(p, v)
#elif COMPRESS_BITS==32
  typedef unsigned long bufbit_t;  /* 64-bit systems may have sizeof(bufbit_t) == 8. That's larger than the necessary 4, but it's harmless. */
#  define set_block_word(p, v) set_le32(p, v)
#else
#  error ERROR_BAD_COMPRESS_BITS COMPRESS_BITS
#endif
typedef char static_assert_sizeof_bufbit_t[sizeof(bufbit_t) >= COMPRESS_BITS >> 3 ? 1 : -1];

#if defined(__WATCOMC__) && defined(_M_I386) && !defined(__COMPACT__) && !defined(__LARGE__)  /* _M_I86 is not defined. */
#  pragma aux FindCommonPrefixLength = \
        "xor eax, eax", \
        "mov ebx, ecx", \
        "repe cmpsb", \
        "setne al", \
        "add ecx, eax", \
        "sub ebx, ecx", \
        __parm [__edi] [__esi] [__ecx] __modify [__eax __ebx __ecx __esi __edi] __value [__ebx];
#elif defined(__WATCOMC__) && !defined(_M_I386) && defined(_M_I86) && !defined(__HUGE__)
#  if defined(__SMALL__) || defined(__MEDIUM__)  /* Default pointers are segment:offset. */
#    pragma aux FindCommonPrefixLength = \
        "mov bx, cx", \
        "repe cmpsb", \
        "je L1", \
        "inc cx", \
        "L1: sub bx, cx", \
        __parm [__di] [__si] [__cx] __modify [__bx __cx __si __di] __value [__bx];
#  else  /* Default pointers contain offset only, segment is DS. */
#    pragma aux FindCommonPrefixLength = \
        "mov bx, cx", \
        "repe cmpsb", \
        "je L1", \
        "inc cx", \
        "L1: sub bx, cx", \
        __parm [__es __di] [__ds __si] [__cx] __modify [__bx __cx __si __di] __value [__bx];
#  endif
#else
/* TODO(pts): Add optimized inline assembly implementation for GCC i386 and amd64. */
/* Fallback implementation. Architecture-independent. */
static int FindCommonPrefixLength(const unsigned char *s1, const unsigned char *s2, int size) {
  int i;
  for (i = 0; i < size && s1[i] == s2[i]; ++i) {}
  return i;
}
#endif

#define DictBits        12
#define DictSize        (1 << DictBits)

#define BufInSize       0x2000
#define BufOutSize      0x1000

#define BufOutThreshold 512
#define BufInThreshold  512  /* This must be at least 270 (or a few more) because of the  while (CodeLen--)' in Compress(...). */

#define BufLPos(p)      ((int)((p) - BufIBase + BufLBase))
#define BufPPos(l)      (BufIBase + (l) - BufLBase)

#define BufPutByte(b)   (*OBuf++ = (b))

static unsigned char *OBuf;
#ifdef DEBUG
  static void BufPutLiteral(unsigned char b) {
    fprintf(stdout, "L%02x\n", (unsigned char)b);
    BufPutByte(b);
  }
  static void BufPutM1(unsigned char b) {
    fprintf(stdout, "X%02x\n", (unsigned char)b);
    BufPutByte(b);
  }
  static void BufPutM1101(unsigned char b) {
    fprintf(stdout, "Y%02x\n", (unsigned char)b);
    BufPutByte(b);
  }
#else
#  define BufPutLiteral(b) BufPutByte(b)
#  define BufPutM1(b) BufPutByte(b)
#  define BufPutM1101(b) BufPutByte(b)
#endif

#define HashBits        12
#define HashCount       (1 << HashBits)

#define HashVal(h)      ((unsigned short) (((h) >> (16 - HashBits)) + (h)) & \
                        (HashCount - 1))

#define HashFindInit()  (HashLastFound = -1)

/*
  DATA
*/
static int LPos, LSize;
static int MaxProbes;

static FILE *BufIHandle, *BufOHandle;

static int  BufLBase;
static int  BufLSize, BufTSize, BufEncodedSize;
static unsigned char *BufBitOPos;
static bufbit_t BufBitBuf;
static int BufBitCount;
static unsigned char *BufIBase, *BufITop, *BufIThreshold;
static unsigned char *BufOBase, *BufOTop, *BufOThreshold;
static unsigned char *IBuf;

static int   *HashVal, HashLink, HashLastFound;
static short *HashNext, *HashPrev, *HashBase, *HashTop;

/*
  CODE
*/

/*
  Compress data from input file to output file.
  In:
    dst - destination file handle (data will be written to the current pos)
    src - source file handle (data will be read from the current pos)
    size - size in bytes of block to compress
    probes - maximum number of probes to do per byte for string matches
  Out:
    int - size of compressed block or error code if compression failed
          (-1 = not enough mem, -2 = error reading file, -3 = error writing)
  Notes:
  ) During compression a progress percentage will be put to the current
    position on the screen in the format "%xx". After completion the
    compressed data as a percentage of the original size will be put in the
    format "xx%", and the cursor will be left right after that.
  ) Do not pass a size smaller than 2 bytes.
  ) If the compression fails, a partially compressed file may have been
    written to disk and you are responsible for cleaning it up.
  ) If compression is successful, file pointers are left at the end of the
    file blocks read and written.
*/
int Compress (FILE *dst, FILE *src, unsigned size, unsigned probes)
{
  int r, i, CodeLen;

  if (!size) return ENCODE_EMPTY;

  if (!HashInit ())
    return ENCODE_NOTENOUGHMEM;

  if ((r = BufInit (dst, src, size)) != 0)
  {
    HashUninit ();
    return r;
  }

  HashAdd (HashVal (*(unsigned short *)IBuf), 0);

  BufPutLiteral(*IBuf);
  ++IBuf;
  BufInitBitOPos();

  MaxProbes = (int)probes;
  if (MaxProbes < 1) MaxProbes = 1;

  LPos = 1;
  LSize = size-1;

  if (LSize) {
  for (;;) {
    CodeLen = PutCode ();  /* Returns: 1 <= CodeLen <= 270. */

    /* The `break;' here prevents the readning of uninitialized memory at NEXT_TO_ADD below. */
    if (!(LSize -= CodeLen)) break;

    if (LPos >= DictSize)
    {
      for (i=DictSize; i>DictSize-CodeLen; i--)
        HashDelete (HashVal (*(unsigned short *)(IBuf-i)));
    }
    else if (LPos+CodeLen >= DictSize)
    {
      for (i=LPos; i>LPos-(CodeLen-(DictSize-LPos)); i--)
        HashDelete (HashVal (*(unsigned short *)(IBuf-i)));
    }

    while (CodeLen--)
    {
      i = *(const unsigned short *)(IBuf++);  /* This is NEXT_TO_ADD, see above. */
      HashAdd (HashVal (i), LPos++);
    }

    if ((r = BufUpdate ()) != 0)
      break;
  }
  }

  if (!r)
  {
    BufPutBit(1);
#if COMPRESS_M1BITFIRST
    BufPutBit(0);
    BufPutM1(0);
#else
    BufPutM1(0);
    BufPutBit(0);
#endif
    BufPutBit(0);

    r = BufFlush ();
  }

  BufUninit ();
  HashUninit ();

  return r;
}

static int PutCode (void)
{
  int  off, len, hash, i0, i1, i2;
  unsigned char *c;
  unsigned char offb;
#if DEBUG  /* These variables are not thread-safe. */
  static unsigned short distances[0x1000];
  static unsigned short distancec;
#endif

  if (LSize == 1)
  {
    BufPutBit(0);
    BufPutLiteral(*IBuf);
    return 1;
  }

  hash = HashVal (*(unsigned short *)IBuf);
  len = 1;
  off = 0;  /* Pacify GCC (__GNCUC__) warning about off being used uninitialized. */

  HashFindInit ();

#if DEBUG
  distancec = 0;
#endif

  for (i2=0; ((i0 = HashFind (hash)) != -1) && (i2 < MaxProbes); i2++)
  {
    c = BufPPos (i0);
    i0 = (IBuf-1) - c;
    i1 = FindCommonPrefixLength(c, IBuf, mymin(270, LSize));

    if ((i1 == 2) && (i0 >= 0x800))
      continue;

#if DEBUG
    if (i1 > len) distancec = 0;  /* Discard shorter distances. */
    if (i1 >= len) {
      if (distancec == sizeof(distances) / sizeof(distances[0])) {
        fprintf(stderr, "fatal: too many distances for debug\n");
        exit(101);
      }
      distances[distancec++] = i0;  /* The order seems to be increasing. */
    }
#endif

    if (i1 > len) {
      off = i0;
      len = i1;
    } else if (i1 == len && len >= 2) {
      if (i0 <= off) {
        fprintf(stderr, "fatal: assert: distances are not in increasing order\n");  /* !! Return an error code instead. */
        exit(102);
      }
#if COMPRESS_LONGDIST  /* Keep the largest (longest) distance whose bitstream encoding will be the same number of bits (not longer). */
      if (len == 2 ? (off > 0xfe || i0 <= 0xfe) : (off > 0x3ff || i0 <= (off <= 0xff ? 0xff : 0x3ff))) {
        off = i0;
      }
#endif
    }
  }

  if (len < 2) {
    BufPutBit(0);
    BufPutLiteral(*IBuf);
  } else {
    /* Maximum distance (off): 0xfff == 4095. Maximum length (len): 270. */
    offb = (unsigned char)off;
    if (len == 2 && off < 255) ++offb;
    BufPutBit(1);
#if COMPRESS_M1BITFIRST
    BufPutBit(len != 2);
    BufPutM1(offb);
#else
    BufPutM1(offb);
    BufPutBit(len != 2);
#endif
    BufPutBit(off + (len == 2) >= 0x100);
    if (len == 2) {
      if (off >= 255) {
        BufPutBits((off >> 8) & 7, 3);
      }
    } else {
      if (off < 0x100) {
      } else if (off < 0x400) {
        BufPutBits((off >> 8) & 3, 3);
      } else {
        BufPutBits(0x10 | ((off >> 8) & 15), 5);
      }
      if (len < 7) {
        BufPutBits(1, len - 2);
      } else if (len < 15) {
        BufPutBits((len - 7) & 7, 8);
      } else {
        BufPutBits(1, 5);
        BufPutM1101(len - 15);
      }
    }
#ifdef DEBUG
    fprintf(stdout, "E%04x\n", len);
    fprintf(stdout, "d");
    while (distancec--) {
      fprintf(stdout, ",%04x", distances[distancec]);
    }
    fprintf(stdout, "\n");
    fprintf(stdout, "D%04x\n", off);
#endif
  }

  return len;
}

#if COMPRESS_EARLYNEXTBLOCK
static void BufInitBitOPos(void) {
#  ifdef DEBUG
  fprintf(stdout, "W?\n");
#  endif
  BufBitOPos = OBuf;
  OBuf += COMPRESS_BITS >> 3;
}
#endif

static int BufInit (FILE *dst, FILE *src, unsigned size)
{
  int r;

  if (!(BufOBase = malloc(BufOutSize)))
    return ENCODE_NOTENOUGHMEM;

  if (!(BufIBase = malloc(BufInSize)))
  {
    free (BufOBase);
    return ENCODE_NOTENOUGHMEM;
  }

  BufOTop = BufOBase + BufOutSize;
  BufOThreshold = BufOTop - BufOutThreshold;
  BufITop = BufIBase + BufInSize;
  BufIThreshold = BufITop - BufInThreshold;

  OBuf = BufOBase;
  IBuf = BufITop;

  BufIHandle = src;
  BufOHandle = dst;

  BufLBase = -BufInSize;
  BufLSize = size;
  BufTSize = size;
  BufEncodedSize = 0;

  BufBitOPos = NULL;
  BufBitBuf = 0;
  BufBitCount = 0;

  if ((r = BufUpdate ()) != 0)
  {
    BufUninit ();
    return r;
  }

  return 0;
}

static void BufUninit (void)
{
  free (BufIBase);
  free (BufOBase);
}

static void BufPutBit (int b)
{
#if COMPRESS_BITREV
  BufBitBuf |= b << BufBitCount;
#else
  BufBitBuf = (BufBitBuf << 1) | b;
#endif

#if COMPRESS_EARLYNEXTBLOCK
  ++BufBitCount;
#else
  if (++BufBitCount == 1) {
#ifdef DEBUG
    fprintf(stdout, "W?\n");
#endif
    BufBitOPos = OBuf;
    OBuf += COMPRESS_BITS >> 3;
  } else
#endif
  if (BufBitCount == COMPRESS_BITS) {
#ifdef DEBUG
    fprintf(stdout, "W%04x\n", BufBitBuf);
#endif
    set_block_word(BufBitOPos, BufBitBuf);
    BufBitBuf = 0;
    BufBitCount = 0;
#if COMPRESS_EARLYNEXTBLOCK
#  ifdef DEBUG
    fprintf(stdout, "W?\n");
#  endif
    BufBitOPos = OBuf;
    OBuf += COMPRESS_BITS >> 3;
#endif
  }
#ifdef DEBUG
  fprintf(stdout, "B%u\n", b);
#endif
}

static void BufPutBits (int b, int c)
{
#if 0  /* Wrong order. */
  for (; c > 0; --c, b >>= 1) {
    BufPutBit(b & 1);
  }
#elif 0  /* Still the wrong order. */
  int i;
  for (i = 0; i < c; ++i) {
    BufPutBit((b >> i) & 1);
  }
#else  /* Correct order: highest bit first. */
  while (c > 0) {
    BufPutBit((b >> --c) & 1);
  }
#endif
}

static int BufUpdate (void)
{
  int  i0, i1, i2;
  unsigned char *c;

  if (IBuf >= BufIThreshold)
  {
    c = IBuf - (BufInSize >> 1);
    i0 = BufITop - c;
    i1 = c - BufIBase;
    i2 = mymin(i1, BufLSize);

    memmove (BufIBase, c, i0);

    if(i2!=0){
        if((fread(BufITop-i1,i2,1,BufIHandle))<1)
        return ENCODE_ERRORREADING;
    }
    IBuf = BufIBase + (BufInSize >> 1);
    BufLBase += i1;
    BufLSize -= i2;
  }

  if (OBuf >= BufOThreshold)
  {
    c = mymincp(OBuf, BufBitOPos);
    i0 = BufOTop - c;
    i1 = c - BufOBase;

    if(i1!=0){
        if((fwrite(BufOBase,i1,1,BufOHandle))<1)
        return ENCODE_ERRORWRITING;
    }
    memmove (BufOBase, c, i0);

    OBuf -= i1;
    BufBitOPos = BufBitOPos - i1;
    BufEncodedSize += i1;

  }

  return 0;
}

static int BufFlush (void)
{
  int i;

#if COMPRESS_EARLYNEXTBLOCK
  if (1 /*BufBitOPos*/)  /* Always true, because end-of-stream (EOS) is expressed as bits. */
#else
  if (BufBitCount)
#endif
  {
#if COMPRESS_BITREV
    set_block_word(BufBitOPos, BufBitBuf);
#else
    set_block_word(BufBitOPos, BufBitBuf << (COMPRESS_BITS - BufBitCount));  /* This shift is OK (to be done as modulo 32 on the i386) even if BufBitCount == 0, beause then BufBitBuf is also 0. */
#endif
#ifdef DEBUG
    fprintf(stdout, "W%04x\n", get_le16(BufBitOPos));  /* TODO(pts): Make this depend on COMPRESS_BITS. */
#endif
  }

#ifdef DEBUG
  fprintf(stdout, "FLUSH %u\n", (unsigned)(OBuf - BufOBase));
  if (OBuf - BufOBase >= 4) {
    fprintf(stdout, "FLUSHLAST4 %02x %02x %02x %02x\n", (unsigned char)OBuf[-4], (unsigned char)OBuf[-3], (unsigned char)OBuf[-2], (unsigned char)OBuf[-1]);
  }
#endif

  i = OBuf - BufOBase;

  if((fwrite(BufOBase,i,1,BufOHandle))<1)
   return ENCODE_ERRORWRITING;

  BufEncodedSize += i;

  return BufEncodedSize;
}

static int HashInit (void)
{
  HashNext = HashPrev = HashBase = HashTop = 0;
  if (!(HashVal = malloc(DictSize * sizeof (int)))) goto err_cleanup;
  if (!(HashNext = malloc(DictSize * sizeof (short)))) goto err_cleanup;
  if (!(HashPrev = malloc(DictSize * sizeof (short)))) goto err_cleanup;
  if (!(HashBase = malloc(HashCount * sizeof (short)))) goto err_cleanup;
  if (!(HashTop = malloc(HashCount * sizeof (short)))) { err_cleanup:
    free (HashBase);
    free (HashPrev);
    free (HashNext);
    free (HashVal);
    return 0;
  }

  memset (HashBase, 0xff, HashCount * sizeof (short));
  memset (HashTop, 0xff, HashCount * sizeof (short));

  HashFindInit ();

  HashLink = 0;

  return 1;
}

static void HashUninit (void)
{
  free (HashTop);
  free (HashBase);
  free (HashPrev);
  free (HashNext);
  free (HashVal);
}

static void HashAdd (unsigned short h, int v)
{
  int i;

#if 0  /* This check seems unnecesary. */
  if (h >= DictSize) { fprintf(stderr, "fatal: assert: hash base location too large: 0x%x\n", h); exit(102); }
#endif
  i = HashBase[h];
  HashBase[h] = HashLink;

  HashVal[HashLink] = v;
  HashPrev[HashLink] = -1 - h;

  if (i < 0)
  {
    HashNext[HashLink] = -1 - h;
    HashTop[h] = HashLink;
  }
  else
  {
    HashNext[HashLink] = i;
    HashPrev[i] = HashLink;
  }

  HashLink ++;
}

static void HashDelete (unsigned short h)
{
  int i;

  i = HashTop[h];
  HashTop[h] = HashPrev[i];

  if (HashTop[h] < 0)
    HashBase[h] = -1;
  else
    HashNext[HashPrev[i]] = HashNext[i];

  if (--HashLink != i)
  {
    HashVal[i] = HashVal[HashLink];
    HashNext[i] = HashNext[HashLink];
    HashPrev[i] = HashPrev[HashLink];

    if (HashNext[i] < 0)
      HashTop[-1 - HashNext[i]] = i;
    else
      HashPrev[HashNext[i]] = i;

    if (HashPrev[i] < 0)
      HashBase[-1 - HashPrev[i]] = i;
    else
      HashNext[HashPrev[i]] = i;
  }
}

static int HashFind (unsigned short h)
{
  if (HashLastFound < 0)
  {
    if ((HashLastFound = HashBase[h]) < 0)
      return -1;
    else
      return HashVal[HashLastFound];
  }
  else
  {
    if ((HashLastFound = HashNext[HashLastFound]) < 0)
      return -1;
    else
      return HashVal[HashLastFound];
  }
}

/* --- */

static const int probes_ary[10] = {
    ENCODE_PROBESMIN,   /* 0 */
    ENCODE_PROBESMIN,   /* 1 */
    ENCODE_PROBESMIN,   /* 2 */
    ENCODE_PROBESMIN,   /* 3 */
    ENCODE_PROBESMIN,   /* 4 */
    ENCODE_PROBESMIN,   /* 5 */
    ENCODE_PROBESFEW,   /* 6 */
    ENCODE_PROBESNORM,  /* 7 */
    ENCODE_PROBESMANY,  /* 8 */
    ENCODE_PROBESMAX,   /* 9 */
};

static void fatal_s(const char *msg, const char *arg1) {
  fprintf(stderr, "fatal: %s: %s\n", msg, arg1);
  exit(2);
}

/* !! TODO(pts): Make it smaller for x86. */
static unsigned get_le16(const unsigned char *p) {
  return p[0] | p[1] << 8;
}

/* Comprares two DOS .exe relocation entries for qsort(3). */
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


#if PMWV == 33
static const char copyright[] = "PMODE/W v1.33 DOS extender - Copyright 1994-1997, Daredevil and Tran.";
#elif PMWV == 34
static const char copyright[] = "PMODE/W v1.34 DOS extender - Copyright 1994-2000, Daredevil and Tran.";
#else
#  error ERROR_UNSUPPORTED_PMWV PMWV
#endif
typedef char assert_sizeof_copyright[sizeof(copyright) - 1 == 0x45 ? 1 : -1];

/* The PMODE/W function _openexe2 (with VARTYPE == 1) will load these 0x15
 * bytes starting at file offset hrdsize << 4 ((word [8]) << 4) to the
 * _pm_... and _lowmin variables.
 *
 * pmwsetup.exe is a menu-driven text-mode tool to modify these config
 * values interactively.
 *
 * 0000   ??        _pm_pagetables: .pagetables: db 4  ; Number of page tables under VCPI.
 * 0001   ????      _pm_selectors: .selectors: dw 0x100  ; Max selectors under VCPI/XMS/raw.
 * 0003   ????      _pm_rmstacklen: .rmstacklen: dw 0x40  ; Real mode stack length, in para.
 * 0005   ????      _pm_pmstacklen: .pmstacklen: dw 0x80  ; Protected mode stack length, in para.
 * 0007   ??        _pm_rmstacks: .rmstacks: db 8  ; Real mode stack nesting.
 * 0008   ??        _pm_pmstacks: .pmstacks: db 8  ; Protected mode stack nesting.
 * 0009   ??        _pm_callbacks: .callbacks: db 0x20  ; Number of real mode callbacks.
 * 000A   ??        _pm_mode: .mode: db 1  ; Mode bits.
 * 000B   ??        _pm_pampagemax: .pamapping: db 1  ; Physical address mappings pages max.
 * 000C   ????      .crap: dw 0
 * 000E   ??        _pm_options: .options: db 1  ; Option flags. 0 = hide copyright message; 1 == display copyright message
 * 000F   ????????  _pm_maxextmem: .extmax: dd 0x7fffffff  ; Maximum extended memory to allocate.
 * 0013   ????      _lowmin: .lowmin: dw 0  ; Amount of low memory to try and save. Loaded by _openexe2 to somewhere else.
 * 0015
 *
 * @0x... offsets below are output compressed DOS .exe file offsets, and
 * also offsets within preparator_buf.
 */
static const char pmodew_config[] =
    /* @0x020 */ "\x04\x00\x01\x40\x00\x80\x00\x08\x08\x20\x01\x01\x00\x00\x01\xff"
    /* @0x030 */ "\xff\xff\x7f\x00\x00";
typedef char assert_sizeof_pmodew_config[sizeof(pmodew_config) - 1 == 0x15 ? 1 : -1];

/* TODO(pts): Add a TASM source for this. dec.nasm already has similar code. */
static const char preparator_code[] =
#if COMPRESS_BITS==16 && COMPRESS_BITREV==1  /* The decompressor below corresponds to these settings. */
    /* @0x07e */                                                         "\xfc\x16"
    /* @0x080 */ "\x07\xbf\x00\x01\x8b\xf7\x57\xb9\x00\x00\xf3\xa5\x06\x1e\x07\x1f"  /* word [0x88] will be overwritten below. */
    /* @0x090 */ "\x5f\xbe\x22\x02\x06\x0e\xa4\xad\x8b\xe8\xb2\x10\x1e\xb8\xd9\x01"
#  if COMPRESS_EARLYNEXTBLOCK  /* The decompressor below corresponds to these settings. */
    /* @0x0a0 */ "\x50\xcb\xd1\xed\xfe\xca\x75\x05\xad\x8b\xe8\xb2\x10\xc3\xe8\xf1"  /* COMPRESS_EARLYNEXTBLOCK==1 code here */
#  else
    /* @0x0a0 */ "\x50\xcb\x80\xea\x01\x73\x04\xb2\x0f\xad\x95\xd1\xed\xc3\xe8\xf1"  /* COMPRESS_EARLYNEXTBLOCK==0 code here */
#  endif
    /* @0x0b0 */ "\xff\x73\x0f\xe8\xec\xff\x80\xd1\x01\xd0\xe1\xe8\xe4\xff\xd0\xd7"
    /* @0x0c0 */ "\xe2\xf9\xb6\x02\xb1\x04\xfe\xc6\xe8\xd7\xff\x72\x1d\xe2\xf7\xe8"
    /* @0x0d0 */ "\xd0\xff\x73\x08\xac\x8a\xc8\x83\xc1\x0f\xeb\x14\x32\xf6\xb1\x03"
    /* @0x0e0 */ "\xe8\xbf\xff\xd0\xd6\xe2\xf9\x80\xc6\x07\x8a\xce\xeb\x02\xb1\x02"
    /* @0x0f0 */ "\xf7\xdb\x4b\x26\x8a\x01\xaa\xe2\xfa\xe8\xa6\xff\x72\x03\xa4\xeb"
#  if COMPRESS_M1BITFIRST  /* The decompressor below corresponds to these settings. */
    /* @0x100 */ "\xf8\x33\xdb\xe8\x9c\xff\xac\x8a\xd8\x72\xa3\xe8\x94\xff\x72\x07"  /* COMPRESS_M1BITFIRST==1 code here */
#  else
    /* @0x100 */ "\xf8\x33\xdb\xac\x8a\xd8\xe8\x99\xff\x72\xa3\xe8\x94\xff\x72\x07"  /* COMPRESS_M1BITFIRST==0 code here */
#  endif
    /* @0x110 */ "\x80\xeb\x01\x72\x0d\xeb\xd7\xb1\x03\xe8\x86\xff\xd0\xd7\xe2\xf9"
    /* @0x120 */ "\xeb\xcc"
#else
#  error ERROR_DECOMPRESSOR_NOT_IMPLEMENTED
#endif
    /* @0x122 */         "\x5a\x01\x16\x5c\x01\xb1\x00\xad\x8b\xd8\x26\x01\x17\xe2"  /* byte [0x128] will be overwritten with U_NRELOC below. */
    /* @0x130 */ "\xf8\x1f\xfa\x81\xc2\x00\x00\x8e\xd2\xbc\x00\x00\xfb\x2e\xff\x2e"  /* word [0x135] will be overwritten with U_SS and word [0x13a] will be overwritten with U_SP below. */
    /* @0x140 */ "\x5a\x01"
    /* @0x142 */ "";
typedef char assert_sizeof_preprartor_code[sizeof(preparator_code) - 1 == 0x142 - 0x7e ? 1 : -1];

static unsigned char preparator_buf[0x142];  /* -1 for the terminting NUL. */

unsigned char exehd[0x200];  /* Input, uncompressed DOS .exe. */

int main(int argc, char **argv) {
  const unsigned level = 9;
  char *srcfn, *dstfn;
  FILE *src, *dst;
  unsigned probes = probes_ary[level];
  unsigned csize, cimg_size, cnblocks;
  unsigned lastsize, nblocks, nreloc, hdrsize, minalloc, maxalloc, ss, sp, ip, cs, relocpos;
  unsigned img_start, img_size, u, mem_para;
  unsigned char *relocsrc;
  unsigned relocofs, relocseg;

  (void)argc;
  if (!argv[0] || !argv[1] || !argv[2]) {
    fprintf(stderr, "Usage: %s <input.exe> <compressed-output.exe>\n", argv[0]);
    return 1;
  }
  /* For probes >= 113 && probes <= 10000, the file size is the same. */
  if (argv[3]) probes = atoi(argv[3]);  /* !! Document it. */
  srcfn = argv[1]; dstfn = argv[2];
  if (!(src = fopen(srcfn, "rb"))) fatal_s("error opening source file", srcfn);
  if (!(dst = fopen(dstfn, "wb"))) fatal_s("error opening destination file", dstfn);
  if (fread(exehd, 1, sizeof(exehd), src) != sizeof(exehd)) fatal_s("error reading DOS .exe header", srcfn);
  if (get_le16(exehd) != ('M' | 'Z' << 8)) fatal_s("missing DOS .exe signature", srcfn);
  lastsize = get_le16(exehd + 1 * 2);
  nblocks = get_le16(exehd + 2 * 2);
  nreloc = get_le16(exehd + 3 * 2);
  hdrsize = get_le16(exehd + 4 * 2);
  minalloc = get_le16(exehd + 5 * 2);
  maxalloc = get_le16(exehd + 6 * 2);
  ss = get_le16(exehd + 7 * 2);
  sp = get_le16(exehd + 8 * 2);
  ip = get_le16(exehd + 10 * 2);
  cs = get_le16(exehd + 11 * 2);
  relocpos = get_le16(exehd + 12 * 2);
  if (nblocks > 0x7ff) fatal_s("DOS .exe nblocks too large", srcfn);  /* Turbo C++ 3 BOSS NE stub has nblocks > 0x7ff. We could do nblocks &= 0x7ff. */
  if (!nreloc) fatal_s("DOS .exe hsa no relocations", srcfn);  /* The `loop' in the preparator code doesn't work without relocations. */
  if (nreloc > 0xff) fatal_s("too many relocations in DOS .exe", srcfn);  /* Won't fit to single byte in preparator_buf. */
  if (minalloc == 0 || minalloc == 0xffff) fatal_s("unexpected minalloc in DOS .exe", srcfn);
  if (maxalloc != 0xffff) fatal_s("unexpected maxalloc in DOS .exe", srcfn);
  /* Not supported reading that many relocations to exehd. */
  if (relocpos >= sizeof(exehd) || ((sizeof(exehd) - relocpos) >> 1) < nreloc) fatal_s("unsupported: too many relocations in DOS .exe", srcfn);
  img_start = hdrsize << 4;
  img_size = ((lastsize & 0x1ff) ? (lastsize & 0x1ff) : 0x200) + ((nblocks - 1) << 9);  /* !! Check 16-bit overflow, or use `unsigned long'. */
  if (img_size <= img_start) fatal_s("source DOS .exe image size too small for header", srcfn);
  img_size -= img_start;
  mem_para = (nblocks << 5) - hdrsize;
  if (mem_para + minalloc < minalloc || mem_para + minalloc > 0xfffe) fatal_s("memory usage too large in source DOS .exe", srcfn);
  mem_para += minalloc;
  if (mem_para < ss + ((sp + 0xf) >> 4)) fatal_s("stack does not fit in preallocated memory in DOS .exe", srcfn);

  /* Sort relocations for consistency.
   *
   * TASM <=4.1 does the sorting (so this call is unnecesary), but TASM
   * >=5.0 doesn't. It doesn't depend on the TLINK version. Without this
   * call, the DOS .exe output of (TASM 5.3 + TLINK 4.01) would differ from
   * of (TASM 4.1 + TLINK 4.01).
   */
  qsort(exehd + relocpos, nreloc, 4, cmp_reloc);
  for (relocsrc = exehd + relocpos, u = 0; u < nreloc; ++u) {  /* Keep the original relocation order, for bitwise identical .exe output. */
    relocofs = get_le16(relocsrc + (u << 2));
    relocseg = get_le16(relocsrc + (u << 2) + 2);
    if (((relocseg + (relocofs >> 4)) & 0xffff) < relocseg) fatal_s("relocation overflow in source DOS .exe", srcfn);
    relocofs += (relocseg << 4) + 0x100;
    if (relocofs < 0x100 || relocofs - 0x100 + 2 > img_size) fatal_s("relocation beyond image size in source DOS .exe", srcfn);
    set_le16(exehd + (u << 1), relocofs);  /* Compressed relocation location: dw (2 bytes). */
  }
  memset(preparator_buf, 0, sizeof(preparator_buf));
  set_le16(preparator_buf + 0 * 2, 'M' | 'Z' << 8);  /* DOS .exe signature. */
  set_le16(preparator_buf + 4 * 2, 2);  /* hdrsize. */
  set_le16(preparator_buf + 6 * 2, 0xffff);  /* maxalloc. */
  set_le16(preparator_buf + 7 * 2, ss);  /* ss. */
  set_le16(preparator_buf + 8 * 2, 0x100);  /* sp. The value 0x100 is hardcoded in many places of the preparator code. */
  set_le16(preparator_buf + 10 * 2, 0x5e);  /* ip. */
  set_le16(preparator_buf + 12 * 2, 0x3e);  /* relocpos. Arbitrary, because nreloc == 0. */
  memcpy(preparator_buf + 0x20, pmodew_config, sizeof(pmodew_config) - 1);  /* 0x15 bytes. */
  memcpy(preparator_buf + 0x35, copyright, sizeof(copyright) - 1);  /* 0x45 bytes. */
  memcpy(preparator_buf + 0x7e, preparator_code, sizeof(preparator_code) - 1);  /* 0x142 - 0x7e bytes. */
  set_le16(preparator_buf + 0x7a, ip);  /* U_IP. */
  set_le16(preparator_buf + 0x7a + 2, cs);  /* U_CS. */
  set_byte(preparator_buf + 0x128, nreloc);  /* U_NRELOC. */
  set_le16(preparator_buf + 0x135, ss);  /* U_SS. */
  set_le16(preparator_buf + 0x13a, sp);  /* U_SP. */
  if (fseek(src, img_start, SEEK_SET)) fatal_s("error seeking in source DOS .exe", srcfn);
  if (fwrite(preparator_buf, 1, sizeof(preparator_buf), dst) != sizeof(preparator_buf)) fatal_s("error writing compressed DOS .exe preparator", dstfn);
  csize = Compress(dst, src, img_size, probes);
  if ((int)csize <= 0) { fflush(dst); fprintf(stderr, "fatal: pmwliteraw compression error: %d\n", (int)csize); return 2; }
  if (fwrite(exehd, 1, nreloc << 1, dst) != (nreloc << 1)) fatal_s("error writing compressed relocation locations", dstfn);
  if (fseek(dst, 0, SEEK_SET)) fatal_s("error seeking in compressed DOS .exe", dstfn);
  cimg_size = csize + (nreloc << 1) + (0x142 - 0x20);
  set_le16(preparator_buf + 1 * 2, (cimg_size + 0x20) & 0x1ff);  /* lastsize. */
  set_le16(preparator_buf + 2 * 2, cnblocks = (cimg_size + 0x20 + 0x1ff) >> 9);  /* nblocks. */
  (void)cnblocks;
  set_le16(preparator_buf + 0x88, (cimg_size + 1) >> 1);  /* Number of data and preparator code words to copy before decompression. */
#if 0  /* This would be a safe but tight way to specify minalloc, but PMODE/W 1.33 seems to be using a more generous, more wasteful formula. */
  set_le16(preparator_buf + 5 * 2, (ss + ((0x100 + 0xf) >> 4) + ((cimg_size + 0xf) >> 4)) - ((cnblocks << 5) - (0x20 >> 4)));  /* minalloc. */
#else
  set_le16(preparator_buf + 5 * 2, (ss + ((0x100 + 0xf) >> 4)) + ((cimg_size + 0xf) >> 4) + 1);  /* minalloc. */  /* !! Why this wasteful formula? */ /* !! Why the +1? */
#endif
  if (fwrite(preparator_buf, 1, sizeof(preparator_buf), dst) != sizeof(preparator_buf)) fatal_s("error writing compressed DOS .exe preparator again", dstfn);
  if (fflush(dst) || fclose(dst)) fatal_s("error closing compressed DOS .exe", dstfn);
  fclose(src);
  return 0;
}
