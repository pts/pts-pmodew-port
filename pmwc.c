/*
 * pmwc.c: PMODE/W stub compressor
 * by pts@fazekas.hu at Wed Jun 11 01:25:35 CEST 2025
 *
 * Compile with: owcc -blinux -I"$WATCOM/lh" -Os -s -fno-stack-check -march=i386 -W -Wall -Wno-n308 -DCOMPRESS_BITS=16 -DCOMPRESS_BITREV=1 -DCOMPRESS_M1BITFIRST=0 -DCOMPRESS_EARLYNEXTBLOCK=0 -DCOMPRESS_LONGDIST=0 -DDEBUG -o pmwc pmwc.c
 *
 * This compressor is similar to PMWLITE 1.34, but there are some feature
 * differences (see FD?) below.
 *
 * Feature differences (FD?):
 *
 * FD1. Block size is 16 bits rather than 32 bits because of -DCOMPRESS_BITS=16 in the compressor. This matches the PMOE/W 1.33 stub compressor. PMWLITE 1.34 uses -DCOMPRESS_BITS=32.
 * FD2. Bit order within a block is lowest bit first because of -DCOMPRESS_BITREV=1 in the compressor. This matches the PMOE/W 1.33 stub compressor. PMWLITE 1.34 uses -DCOMPRESS_BITREV=0.
 * FD3. The distance byte of match_1 is read after the next bit if -DCOMPRESS_M1BITFIRST=1 is specified. -DCOMPRESS_M1BITFIRST=0 matches PMWLITE 1.34, but doesn't match the PMODE/W 1.33 stub compressor.
 * FD4. The next block is read at the end of the previous block, not later (when its first bit is needed) if -DCOMPRESS_EARLYNEXTBLOCK=1 is specified. -DCOMPRESS_EARLYNEXTBLOCK=0 matches PMWLITE 1.34, but doesn't match the PMODE/W 1.33 stub compressor.
 * FD5. The compressor doesn't emit the smallest possible distance for the given length (but it seems to use the largest??). !! Solution: Patch the compressor?
 *
 * !! make it bitwise identical by addressing FD5
 * !! get rid of inline assembly #pragma
 * !! use unsigned char everywhere
 * !! get rid of forcing little-endian
 * !! get rid of requirement of unaligned access
 * !! make sure it works with sizeof(unsigned) < 4
 * !! make sure it works with signed char and unsigned char
 */

#include <io.h>
#include <malloc.h>
#include <mem.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

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
#  error ERROR_COMPRESS_M1BITFIRST_1_NOT_IMPLEMENTED
#else
#  undef  COMPRESS_M1BITFIRST
#  define COMPRESS_M1BITFIRST 0
#endif

#ifndef COMPRESS_EARLYNEXTBLOCK
#  error ERROR_MISSING_COMPRESS_EARLYNEXTBLOCK
#elif COMPRESS_EARLYNEXTBLOCK
#  undef  COMPRESS_EARLYNEXTBLOCK
#  define COMPRESS_EARLYNEXTBLOCK 1
#  error ERROR_COMPRESS_EARLYNEXTBLOCK_1_NOT_IMPLEMENTED
#else
#  undef  COMPRESS_EARLYNEXTBLOCK
#  define COMPRESS_EARLYNEXTBLOCK 0
#endif

#define ENCODE_NOTENOUGHMEM     -1
#define ENCODE_ERRORREADING     -2
#define ENCODE_ERRORWRITING     -3

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
static int StringMatch(const char *s1, const char *s2, unsigned size);

#ifdef DEBUG
#  include <stdio.h>
#endif

#if COMPRESS_BITS==8
  typedef unsigned char bufbit_t;
#elif COMPRESS_BITS==16
  typedef unsigned short bufbit_t;
#elif COMPRESS_BITS==32
  typedef unsigned bufbit_t;  /* !! Depends on sizeof(int) == 4. */  /* !! Also depends on little-endian. */  /* !! Also depends on unaligned writes. */
#else
#  error ERROR_BAD_COMPRESS_BITS COMPRESS_BITS
#endif
typedef char static_assert_sizeof_bufbit_t[sizeof(bufbit_t) == COMPRESS_BITS >> 3 ? 1 : -1];
typedef char static_assert_sizeof_unsignedt[sizeof(unsigned) == 4];  /* !! Make it work without this. */

/*
  INFO
*/
// Disk to disk compression.
//

// Pseudo-logic to decompress data:
//
// movestring2:
//   len = 2;
//
// movestring:
//   MOVE ($ - off, len);
//
// decode:
//   literal_0:
//     PUT (GETBYTE ());
//
//     GOTO decode;
//
//   match_1:
//     off[0-7] = GETBYTE ();
//
//     match_1_0:
//       match_1_0_0:
//         if (!off)
//           GOTOEXE ();
//         off -= 1;
//
//         GOTO movestring2;
//
//       match_1_0_1:
//         off[10] = GETBIT ();
//         off[9] = GETBIT ();
//         off[8] = GETBIT ();
//
//         GOTO movestring2;
//
//     match_1_1:
//       match_1_1_1:
//         count = GETBIT ();
//
//         REPEAT ((count + 1) * 2)
//         {
//           SHL (off[8-15], 1);
//           off[8] = GETBIT ();
//         }
//
//       match_1_1_0:
//         len = 2;
//
//         REPEAT (4)
//         {
//           len ++;
//
//           if (GETBIT ())
//             GOTO movestring;
//         }
//
//         match_1_1_0_0:
//           len = (len << 1) | GETBIT ();
//           len = (len << 1) | GETBIT ();
//           len = (len << 1) | GETBIT ();
//           len += 7;
//
//           GOTO movestring;
//
//         match_1_1_0_1:
//           len[0-7] = GETBYTE ();
//           len += 15;
//
//           GOTO movestring;

/*
  INTERFACE
*/

#pragma aux StringMatch = \
        "mov ebx,ecx",\
        "repe cmpsb",\
        "mov eax,0",\
        "setne al",\
        "add ecx,eax",\
        "sub ebx,ecx",\
        parm [edi] [esi] [ecx] modify [eax ebx ecx esi edi] value [ebx];

#define DictBits        12
#define DictSize        (1 << DictBits)

#define BufInSize       0x20000
#define BufOutSize      0x2000

#define BufOutThreshold 512
#define BufInThreshold  512

#define BufLPos(p)      ((int)((p) - BufIBase + BufLBase))
#define BufPPos(l)      (BufIBase + (l) - BufLBase)

#define BufPutByte(b)   (*OBuf++ = (b))

static char *OBuf;
#ifdef DEBUG
  static void BufPutLiteral(char b) {
    fprintf(stdout, "L%02x\n", (unsigned char)b);
    BufPutByte(b);
  }
  static void BufPutM1(char b) {
    fprintf(stdout, "X%02x\n", (unsigned char)b);
    BufPutByte(b);
  }
  static void BufPutM1101(char b) {
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
static int      LPos, LSize, Show;
static unsigned MaxProbes;

static FILE *BufIHandle, *BufOHandle;

static int  BufLBase;
static int  BufLSize, BufTSize, BufEncodedSize;
static bufbit_t *BufBitOPos, BufBitBuf;
static int BufBitCount;
static char *BufIBase, *BufITop, *BufIThreshold;
static char *BufOBase, *BufOTop, *BufOThreshold;
static char *IBuf;

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
    show - show progress percentage during compression flag
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
int Compress (FILE *dst, FILE *src, unsigned size, unsigned probes, int show)
{
  int r, i, CodeLen;

  Show = show;

  if (!HashInit ())
    return ENCODE_NOTENOUGHMEM;

  if (r = BufInit (dst, src, size))
  {
    HashUninit ();
    return r;
  }

  HashAdd (HashVal (*(unsigned short *)IBuf), 0);

  BufPutLiteral (*IBuf);
  ++IBuf;

  MaxProbes = probes;

  LPos = 1;
  LSize = size-1;

  while (LSize)
  {
    CodeLen = PutCode ();

    LSize -= CodeLen;

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
      i = *(unsigned short *)(IBuf++);
      HashAdd (HashVal (i), LPos++);
    }

    if (r = BufUpdate ())
      break;
  }

  if (!r)
  {
    BufPutBit (1);
    BufPutM1 (0);
    BufPutBits (0, 2);

    r = BufFlush ();
  }

  BufUninit ();
  HashUninit ();

  return r;
}

static int PutCode (void)
{
  int  off, len, hash, i0, i1, i2;
  char *c;

  if (LSize == 1)
  {
    BufPutBit (0);
    BufPutLiteral (*IBuf);
    return 1;
  }

  hash = HashVal (*(unsigned short *)IBuf);
  len = 1;

  HashFindInit ();

  for (i2=0; ((i0 = HashFind (hash)) != -1) && (i2 < MaxProbes); i2++)
  {
    c = BufPPos (i0);
    i0 = (IBuf-1) - c;
    i1 = StringMatch (c, IBuf, min (270, LSize));

    if ((i1 == 2) && (i0 >= 0x800))
      continue;

#if COMPRESS_LONGDIST
    /* Pick the longest found distance (off). Hopefully this moves closer to PMODE/W 1.33 compression. However, it makes the compressed output longer. */
    if (i1 > len || (i1 == len && i0 > off))
#else
    if (i1 > len)
#endif
    {
      off = i0;
      len = i1;
    }
  }

  if (len < 2)
  {
    BufPutBit (0);
    BufPutLiteral (*IBuf);
  }
  else if (len == 2)
  {
    BufPutBit (1);

    if (off < 255)
    {
      BufPutM1 ((char)off + 1);
      BufPutBits (0, 2);
    }
    else
    {
      BufPutM1 ((char)off);
      BufPutBits (8 | ((off >> 8) & 7), 5);
    }
  }
  else
  {
    BufPutBit (1);
    BufPutM1 ((char)off);

    if (off < 0x100)
      BufPutBits (2, 2);
    else if (off < 0x400)
      BufPutBits (0x18 | ((off >> 8) & 3), 5);
    else
      BufPutBits (0x70 | ((off >> 8) & 15), 7);

    if (len < 7)
      BufPutBits (1, len - 2);
    else if (len < 15)
      BufPutBits ((len-7) & 7, 8);
    else
    {
      BufPutBits (1, 5);
      BufPutM1101 (len - 15);
    }
  }

  return len;
}

static int BufInit (FILE *dst, FILE *src, unsigned size)
{
  int r;

  if (!(BufOBase = malloc (BufOutSize)))
    return ENCODE_NOTENOUGHMEM;

  if (!(BufIBase = malloc (BufInSize)))
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

  BufBitBuf = 0;
  BufBitCount = 0;

  if (r = BufUpdate ())
  {
    BufUninit ();
    return r;
  }

  if (Show)
  {
//    fprintf (stdout, "%%00");
//    fflush (stdout);
//    cprintf ("%%00");
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

  if (++BufBitCount == 1)
  {
#ifdef DEBUG
  fprintf(stdout, "W?\n");
#endif
    BufBitOPos = (bufbit_t *)OBuf;
    OBuf += COMPRESS_BITS >> 3;
  }
  else if (BufBitCount == COMPRESS_BITS)
  {
#ifdef DEBUG
  fprintf(stdout, "W%04x\n", BufBitBuf);
#endif
    *BufBitOPos = BufBitBuf;
    BufBitBuf = 0;
    BufBitCount = 0;
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

//static void BufPutByte (int b)
//{
//  *OBuf++ = b;
//}

static int BufUpdate (void)
{
  int  i0, i1, i2;
  char *c;

  if (IBuf >= BufIThreshold)
  {
    c = IBuf - 0x10000;
    i0 = BufITop - c;
    i1 = c - BufIBase;
    i2 = min (i1, BufLSize);

    memmove (BufIBase, c, i0);

//    if (read (BufIHandle, BufITop - i1, i2) != i2)
//      return ENCODE_ERRORREADING;
    if(i2!=0){
        if((fread(BufITop-i1,i2,1,BufIHandle))<1)
        return ENCODE_ERRORREADING;
    }
    IBuf = BufIBase + 0x10000;
    BufLBase += i1;
    BufLSize -= i2;
  }

  if (OBuf >= BufOThreshold)
  {
    c = (char *)min ((int)OBuf, (int)BufBitOPos);
    i0 = BufOTop - c;
    i1 = c - BufOBase;

//    if (write (BufOHandle, BufOBase, i1) != i1)
//      return ENCODE_ERRORWRITING;
    if(i1!=0){
        if((fwrite(BufOBase,i1,1,BufOHandle))<1)
        return ENCODE_ERRORWRITING;
    }
    memmove (BufOBase, c, i0);

    OBuf -= i1;
    BufBitOPos = (bufbit_t *)((char *)BufBitOPos - i1);
    BufEncodedSize += i1;

    if (Show)
    {
//      fprintf (stdout, "\x08\x08%02d", BufLPos (IBuf) * 100 / BufTSize);
//      fflush (stdout);
//      cprintf ("\x08\x08%02d", BufLPos (IBuf) * 100 / BufTSize);
    }
  }

  return 0;
}

static int BufFlush (void)
{
  int i;

  if (BufBitCount) {
#if COMPRESS_BITREV
    *BufBitOPos = BufBitBuf;
#else
    *BufBitOPos = BufBitBuf << (COMPRESS_BITS - BufBitCount);
#endif
#ifdef DEBUG
    fprintf(stdout, "W%04x\n", *BufBitOPos);
#endif
  }

#ifdef DEBUG
  fprintf(stdout, "FLUSH %u\n", (unsigned)(OBuf - BufOBase));
  if (OBuf - BufOBase >= 4) {
    fprintf(stdout, "FLUSHLAST4 %02x %02x %02x %02x\n", (unsigned char)OBuf[-4], (unsigned char)OBuf[-3], (unsigned char)OBuf[-2], (unsigned char)OBuf[-1]);
  }
#endif

  i = OBuf - BufOBase;

//  if (write (BufOHandle, BufOBase, i) != i)
//    return ENCODE_ERRORWRITING;
  if((fwrite(BufOBase,i,1,BufOHandle))<1)
   return ENCODE_ERRORWRITING;

  BufEncodedSize += i;

  if (Show)
  {
//    fprintf (stdout, "\x08\x08\x08   \x08\x08\x08");
//    fflush (stdout);
//    cprintf ("\x08\x08\x08   \x08\x08\x08");

  }

  return BufEncodedSize;
}

static int HashInit (void)
{
  if (!(HashVal = malloc (DictSize * sizeof (int))))
    return 0;

  if (!(HashNext = malloc (DictSize * sizeof (short))))
  {
    free (HashVal);
    return 0;
  }

  if (!(HashPrev = malloc (DictSize * sizeof (short))))
  {
    free (HashNext);
    free (HashVal);
    return 0;
  }

  if (!(HashBase = malloc (HashCount * sizeof (short))))
  {
    free (HashPrev);
    free (HashNext);
    free (HashVal);
    return 0;
  }

  if (!(HashTop = malloc (HashCount * sizeof (short))))
  {
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

/* !! TODO(pts): Make it smaller for x86. */
static void set_le16(unsigned char *p, unsigned v) {
  *p++ = v;
  *p = v >> 8;
}

#define set_byte(p, v) (*(p) = (v))

enum sizes_t { expected_csize = 11110 };  /* !! Make it more generic, update header fields and code. */

static const char header[] =
    /* @0x000 */ "\x4d\x5a\xdc\x00\x17\x00\x00\x00\x02\x00\xb4\x06\xff\xff\xd7\x03"  /* MZ.............. */
    /* @0x010 */ "\x00\x01\x00\x00\x5e\x00\x00\x00\x3e\x00\x00\x00\x00\x00\x00\x00"  /* ................ */
    /* @0x020 */ "\x04\x00\x01\x40\x00\x80\x00\x08\x08\x20\x01\x01\x00\x00\x01\xff"  /* ......... ...... */
    /* @0x030 */ "\xff\xff\x7f\x00\x00\x50\x4d\x4f\x44\x45\x2f\x57\x20\x76\x31\x2e"  /* .....PMODE/W v1. */
    /* @0x040 */ "\x33\x33\x20\x44\x4f\x53\x20\x65\x78\x74\x65\x6e\x64\x65\x72\x20"  /* 33 DOS extender  */
    /* @0x050 */ "\x2d\x20\x43\x6f\x70\x79\x72\x69\x67\x68\x74\x20\x31\x39\x39\x34"  /* - Copyright 1994 */
    /* @0x060 */ "\x2d\x31\x39\x39\x37\x2c\x20\x44\x61\x72\x65\x64\x65\x76\x69\x6c"  /* -1997, Daredevil */
    /* @0x070 */ "\x20\x61\x6e\x64\x20\x54\x72\x61\x6e\x2e"                          /*  and Tran. */
    /* @0x07a */                                         "\x00\x00\x00\x00"  /* Will be overwritten with ip (U_IP) and cs (U_CS) below. */
#if COMPRESS_BITS==16 && COMPRESS_BITREV==1 && COMPRESS_M1BITFIRST==0 && COMPRESS_EARLYNEXTBLOCK==0  /* The compressor below corresponds to these settings. */
    /* @0x07e */                                                         "\xfc\x16"
    /* @0x080 */ "\x07\xbf\x00\x01\x8b\xf7\x57\xb9\x5e\x16\xf3\xa5\x06\x1e\x07\x1f"
    /* @0x090 */ "\x5f\xbe\x22\x02\x06\x0e\xa4\xad\x8b\xe8\xb2\x10\x1e\xb8\xd9\x01"
    /* @0x0a0 */ "\x50\xcb\x80\xea\x01\x73\x04\xb2\x0f\xad\x95\xd1\xed\xc3\xe8\xf1"
    /* @0x0b0 */ "\xff\x73\x0f\xe8\xec\xff\x80\xd1\x01\xd0\xe1\xe8\xe4\xff\xd0\xd7"
    /* @0x0c0 */ "\xe2\xf9\xb6\x02\xb1\x04\xfe\xc6\xe8\xd7\xff\x72\x1d\xe2\xf7\xe8"
    /* @0x0d0 */ "\xd0\xff\x73\x08\xac\x8a\xc8\x83\xc1\x0f\xeb\x14\x32\xf6\xb1\x03"
    /* @0x0e0 */ "\xe8\xbf\xff\xd0\xd6\xe2\xf9\x80\xc6\x07\x8a\xce\xeb\x02\xb1\x02"
    /* @0x0f0 */ "\xf7\xdb\x4b\x26\x8a\x01\xaa\xe2\xfa\xe8\xa6\xff\x72\x03\xa4\xeb"
    /* @0x100 */ "\xf8\x33\xdb\xac\x8a\xd8\xe8\x99\xff\x72\xa3\xe8\x94\xff\x72\x07"
    /* @0x110 */ "\x80\xeb\x01\x72\x0d\xeb\xd7\xb1\x03\xe8\x86\xff\xd0\xd7\xe2\xf9"
    /* @0x120 */ "\xeb\xcc\x5a\x01\x16\x5c\x01\xb1\x00\xad\x8b\xd8\x26\x01\x17\xe2"  /* byte @0x128 will be overwritten with nreloc below. */
    /* @0x130 */ "\xf8\x1f\xfa\x81\xc2\xd7\x03\x8e\xd2\xbc\x00\x04\xfb\x2e\xff\x2e"
    /* @0x140 */ "\x5a\x01"
    /* @0x142 */ "";
#else
#  error ERROR_DECOMPRESSOR_NOT_IMPLEMENTED
#endif

static unsigned char preparator_buf[sizeof(header) - 1];  /* -1 for the terminting NUL. */

unsigned char exehd[0x200];

int main(int argc, char **argv) {
  const unsigned level = 9;
  char *srcfn, *dstfn;
  FILE *src, *dst;
  unsigned probes = probes_ary[level];
  const int show = 0;
  int res;  /* Either a positive file size or an error. */
  unsigned lastsize, nblocks, nreloc, hdrsize, relocpos, ip, cs, img_start, img_size, u;
  unsigned char *relocsrc;
  unsigned relocofs, relocseg;

  (void)argc;
  if (!argv[0] || !argv[1] || !argv[2]) {
    fprintf(stderr, "Usage: %s <input.exe> <compressed-output.exe>\n");
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
  ip = get_le16(exehd + 10 * 2);
  cs = get_le16(exehd + 11 * 2);
  relocpos = get_le16(exehd + 12 * 2);
  if (nblocks > 0x7ff) fatal_s("DOS .exe nblocks too large", srcfn);  /* Turbo C++ 3 BOSS NE stub has nblocks > 0x7ff. */
  if (nreloc) {
    if (nreloc > 0xff) fatal_s("too many relocations in DOS .exe\n", srcfn);  /* Won't fit to single byte in preparator_buf. */
    /* Not supported reading that many relocations to exehd. */
    if (relocpos >= sizeof(exehd) || ((sizeof(exehd) - relocpos) >> 1) < nreloc) fatal_s("unsupported: too many relocations in DOS .exe", srcfn);
    for (relocsrc = exehd + relocpos, u = 0; u < nreloc; ++u) {  /* Keep the original relocation order, for bitwise identical .exe output. */
      relocofs = get_le16(relocsrc + (u << 2));
      relocseg = get_le16(relocsrc + (u << 2) + 2);
      if (((relocseg + (relocofs >> 4)) & 0xffff) < relocseg) fatal_s("relocation overflow in source DOS .exe", srcfn);
      relocofs += (relocseg << 4) + 0x100;
      if (relocofs < 0x100 || relocofs - 0x100 + 2 > img_size) fatal_s("relocation beyond image size in source DOS .exe", srcfn);
      set_le16(exehd + (u << 1), relocofs);  /* Compressed relocation location: dw (2 bytes). */
    }
  }
  img_start = hdrsize << 4;
  img_size = ((lastsize & 0x1ff) ? (lastsize & 0x1ff) : 0x200) + ((nblocks - 1) << 9) - img_start;
  if (fseek(src, img_start, SEEK_SET)) fatal_s("error seeking in source DOS .exe", srcfn);
  memcpy(preparator_buf, header, sizeof(preparator_buf));
  set_le16(preparator_buf + 0x7a, ip);  /* U_IP. */
  set_le16(preparator_buf + 0x7a + 2, cs);  /* U_CS. */
  set_byte(preparator_buf + 0x128, nreloc);  /* U_NRELOC. */
  if (fwrite(preparator_buf, 1, sizeof(preparator_buf), dst) != sizeof(preparator_buf)) fatal_s("error writing preparator exehdfer", dstfn);
  res = Compress(dst, src, img_size, probes, show);
  if (res <= 0) { fflush(dst); fprintf(stderr, "fatal: pmwliteraw compression error: %d\n", res); return 2; }
  if (res != expected_csize) { fflush(dst); fprintf(stderr, "fatal: unexpected compressed size: expecting %u, got %u\n", expected_csize, res); return 2; }
  if (fwrite(exehd, 1, nreloc << 1, dst) != (nreloc << 1)) fatal_s("error writing compressed relocation locations", dstfn);
  if (fflush(dst) || fclose(dst)) fatal_s("error closing destination file", dstfn);
  fclose(src);
  return res > 0 ? 0 : 3;
}
