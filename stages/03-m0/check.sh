#!/usr/bin/env bash
# M0 conformance check: the constraints Z1-Z10 in seed.md.
#
#   check.sh <target> <candidate-m0> <hex2-binary> <source-hex2-builds-the-candidate-from>
#
# M0 is not required to rebuild itself (seed.md Z10); it must be built by hex2.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"; STAGE=M0
. "$HERE/../../lib/check-lib.sh"
[ $# = 4 ] || { echo "usage: check.sh <x86_64-linux|arm64-macos> <candidate-m0> <hex2-binary> <hex2-source-for-m0>" >&2; exit 2; }
setup "$1" "$2" "$4" "$3" "$4"

check_built_by_previous Z10
check_kats "$HERE/fixtures/kat-$TARGET.tsv" "$HERE/fixtures/kat"
check_errors "$HERE/fixtures/err.tsv" "$HERE/fixtures/err"
# Z8a: capacity and table minimums (sized for M0's successor).
lim(){ if runb "$C" "$W/lim" "$W/lim.out" && [ "$(hexof "$W/lim.out")" = "$2" ]; then ok "Z8a  $1"; else no "Z8a  $1: got '$(hexof "$W/lim.out" | head -c 16)' want '$2'"; fi; }
perl -e 'print "# ".("x" x 131060)."\n4a\n"' > "$W/lim"; lim "131072-byte source decodes in full" 4a
perl -e 'for (1..1024) { print ":l$_ 00\n" } print "&l1024\n"' > "$W/lim"; lim "1024 labels" "$(perl -e 'print "00" x 1024; printf "%02x%02x0000", 1023 % 256, int(1023 / 256)')"
perl -e 'for (1..512) { print "%m$_ 4a\n" } print "m512 m1\n"' > "$W/lim"; lim "512 macros" 4a4a
perl -e 'my $n = "n" x 64; print "00 :$n &$n\n"' > "$W/lim"; lim "64-character names" 0001000000
for f in "$HERE"/fixtures/run-*-"$TARGET".m0; do check_runs Z9 "$f"; done
finish
