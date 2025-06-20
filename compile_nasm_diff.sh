#! /bin/sh --
#
# compile_nasm_diff.sh: compile with NASM default config, and compare in detail to the golden output
# by pts@fazekas.hu at Thu Jun 19 10:36:29 CEST 2025
#

set -ex
unset LANG LANGUAGE  # For reproducible builds.
export LC_ALL=C  # For reproducible builds.
export TZ=GMT  # For reproducible builds.
test "$ZSH_VERSION" && set -y 2>/dev/null  # SH_WORD_SPLIT for zsh(1). It's an invalid option in bash(1), and it's harmful (prevents echo) in ash(1).

test "$0" = "${0%/*}" || cd "${0%/*}"

ndisasm -b 16 -k 0,0x592 -k 0x23c0,0x38b pmodewu.exe.good >pmodewu.ndisasm
<pmodewu.ndisasm perl -ne 'next if !m@^\w@; die if !m@^(\w+\s+)\w+\s+(.*)@; my($x,$y) = ($1,$2); $y =~ s@-?0x[0-9a-f]+@N@g; print "$y\n"' >pmodewu.ndb
# -O32700 instead of -O999999999 for compatibility with 16-bit NASM 0.98.39.
nasm=tools/nasm-0.98.39.upx
nasm=nasm
nasm=./nasm-2.16.03
nasm="${1:-tools/nasm-0.98.39.upx}"
"$nasm" -O32700 -w+orphan-labels -DPMWV=33 -l pmodewn.lst -o pmodewn.exe pmodew.nasm  # 2>t.log
ndisasm -b 16 -k 0,0x592 -k 0x23c0,0x38b pmodewn.exe >pmodewn.ndisasm
<pmodewn.ndisasm perl -ne 'next if !m@^\w@; die if !m@^(\w+\s+)\w+\s+(.*)@; my($x,$y) = ($1,$2); $y =~ s@-?0x[0-9a-f]+@N@g; print "$y\n"' >pmodewn.ndb
if ! cmp pmodewu.ndisasm pmodewn.ndisasm; then
  export PERL_CODE='use integer; use strict;
    my $step = $ARGV[4] + 0;
    my $conf_enable_size_diffs = ($step > 0);  # Example: `mov ax, [si+0x5]` vs `mov ax, [word si+0x5]`.
    my $conf_enable_ignore_number_diffs = ($step > 1);  # Example: `mov ax, [ebx+ebx+0x5]`, `mov ax, [ebx*2+0x5]`, the number 0x5 is ignored.
    my $conf_enable_without_number_different_disasm_diffs = ($step > 2);  # Example: `mov ax, [ebx+ebx]`, `mov ax, [ebx*2]`.
    my $conf_enable_number_diffs = ($step > 3);  # Example: `mov ax, 0x1` vs `mov ax, 0x2`.
    my $conf_enable_without_number_same_disasm_diffs = ($step > 4);  # Example: two different, but same-size encodings for `mov ax, bx`.
    die 1 if !open(FU, "<", $ARGV[0]);
    die 2 if !open(FN, "<", $ARGV[1]);
    die 3 if !open(FL, "<", $ARGV[2]);
    my %a2l;  # Maps addresses to line numbers.
    my %l2s;  # Maps line numbers to source strings.
    my $ldelta = 0;  # Add this to an .lst line number to get the .nasm line number. This assumes no %include.
    while (<FL>) {
      die 4 if !s@^ *([1-9]\d*) @@;
      my $linenr = $1 + 0;
      die("fatal: .lst output probably not created by NASM 0.98.39\n") if $linenr != $.;  # This expects the output of NASM 0.98.39.
      if (m@^............................ <@) {
        --$ldelta;
        $a2l{$1} = $linenr + $ldelta if s@^(000[0-9A-F]{5}) @@ and !exists($a2l{$1});
      } else {
        $linenr += $ldelta;
        #die "!!$linenr $_\n" if $linenr == 1000;
        if (s@^(000[0-9A-F]{5}) @@) {
          # !! Instruction source line will not be found if it is a macro invocation.
          $a2l{$1} = $linenr, $l2s{$linenr} = $_ if !exists($l2s{$linenr});
          --$ldelta if m@^\S+-[ \n]@;  # For subsequent lines.
        }
      }
    }
    if (0) {  # Print line numbers of relocations.
      for my $a (0x2845, 0x28e1, 0x28fc, 0x2926, 0x2946, 0x321c, 0x32d0, 0x3346, 0x33f4, 0x3461, 0x3640, 0x3ee6, 0x3f5d, 0x208, 0x764, 0xb88, 0xe28, 0xeb0, 0xfd0, 0x1093, 0x1141, 0x11de, 0x1a83, 0x1c02, 0x1c21, 0x1d34) {
        my $s = "reloc";
        my $l0 = $a2l{sprintf("%08X", $a)}; my $l = defined($l0) ? $l0 : $a2l{sprintf("%08X", $a + 2)};
        die(sprintf("fatal: missing line for offset: 0x%x\n", $a)) if !defined($l);
        --$l;  # Print previous line number.
        $s .= "2" if !defined($l0);
        print("pmodew.nasm:$l: $s\n");
      }
      exit;
    }
    # Replace hex number in instruction with N.
    sub nonumber($) { my $s = $_[0]; $s =~ s@-?0x[0-9a-f]+@N@g; $s }
    my($su, $sn, $sua, $sna, $suh, $snh, $sun, $snn, $nu, $nn);
    my $sdelta = 0;
    my $diff_count = 0;
    while (defined($nu = <FU>)) {
      die 6 if !defined($nn = <FN>);
      if ($nu =~ m@^ +-@ and $nn =~ m@^ +-@) {  # Continuation lines.
        die  9 if $nu !~ s@^         -((?:[0-9A-F]{2})+)$@@;
        $suh .= $1;
        die 10 if $nn !~ s@^         -((?:[0-9A-F]{2})+)$@@;
        $snh .= $1;
        # Continued lines with matching length (and $conf_enable_non_size_diffs) may appear multiple times below. !! Fix it by looking ahead.
      } else {
        $su = $nu; $sn = $nn;
        die 7 if $su !~ s@^(000[0-9A-F]{5})  ((?:[0-9A-F]{2})+|skipping) @@;
        $sua = $1; $suh = $2;
        die 8 if $sn !~ s@^(000[0-9A-F]{5})  ((?:[0-9A-F]{2})+|skipping) @@;
        $sna = $1; $snh = $2;
      }
      if (sprintf("%08X", hex($sua) + $sdelta) ne $sna) {  # Unexpected.
        print(STDERR "\ngood addr: $sua $suh $su");
        print(STDERR   "bad  addr: $sna $snh $sn");
        die("fatal: ADDR MISMATCH, sdelta=$sdelta\n");  # Sanity check. Should not happen.
      } elsif ($suh eq $snh) {  # No diff.
      } elsif (($conf_enable_size_diffs and length($suh) ne length($snh)) or
               (($sun = nonumber($su)) eq ($snn = nonumber($sn))) ? (($conf_enable_number_diffs and $sun =~ m@N@) or ($conf_enable_without_number_same_disasm_diffs and $sun !~ m@N@)) :
               (($conf_enable_ignore_number_diffs and $sun =~ m@N@) or ($conf_enable_without_number_different_disasm_diffs and $sun !~ m@N@))) {
        ++$diff_count;
        print(STDERR "\ngood: $suh $su");
        print(STDERR   "bad:  $snh $sn");
        if (!defined($a2l{$sna})) { print(STDERR "$ARGV[3]:?: $sua\n") }
        elsif (!defined($l2s{$a2l{$sna}})) { print(STDERR "$ARGV[3]:$a2l{$sna}: $sua ?\n") }
        else { print(STDERR "$ARGV[3]:$a2l{$sna}: $sua $l2s{$a2l{$sna}}") }
        $sdelta += (length($snh) - length($suh)) >> 1;
      }
    }
    die 99 if defined(<FU>);
    if ($diff_count) { print(STDERR "fatal: found $diff_count diff@{[q(s)x($diff_count!=1)]}\n"); exit(2) }
    '
  for step in 1 2 3 4 5; do
    perl -we 'eval($ENV{PERL_CODE});die$@if$@' pmodewu.ndisasm pmodewn.ndisasm pmodewn.lst pmodewn.nasm "$step"
  done
fi
diff -u pmodewu.ndb pmodewn.ndb  # Just for sanity. The Perl script above with all `$conf_enable_... = 1' should have caught all this.
diff -u pmodewu.ndisasm pmodewn.ndisasm  # Just for sanity. The Perl script above with all `$conf_enable_... = 1' should have caught all this.
if ! cmp pmodewu.exe.good pmodewn.exe; then  # Also compares the DOS .exe headers and the initial variable values.
  cmp -l pmodewu.exe.good pmodewn.exe | perl -pe 's@^\s*(\d+)\s+([0-7]+)\s+([0-7]+)$@ sprintf("0x%04X 0x%02X 0x%02X", $1-1, oct($2), oct($3))  @e'
  false
fi

: "$0" OK.
