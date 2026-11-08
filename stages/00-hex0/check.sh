#!/usr/bin/env bash
# hex0 conformance check.
#
#   check.sh <target> <candidate-hex0-binary> <candidate-commented-source>
#   target: x86_64-linux | arm64-macos
#
# Checks the constraints in seed.md (H1-H10), not the bytes of any reference: a conformant hex0 need not be
# byte-identical to any other realization. Runs natively on the target only. Host tools (od, cmp, file, codesign --verify)
# are used to INSPECT results, never to produce a byte of the candidate. Exit 0 iff every check passes.
# Uses the shared helpers in lib/check-lib.sh, like every other stage.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"; STAGE=hex0
. "$HERE/../../lib/check-lib.sh"
[ $# = 3 ] || { echo "usage: check.sh <x86_64-linux|arm64-macos> <candidate-binary> <candidate-source>" >&2; exit 2; }
setup "$@"

# H9 -- self-hosting: the candidate rebuilds itself, byte for byte, from its own commented source; and its own
# bytes, as bare hex, reproduce it.
check_self_host H9
check_raw_fixed_point H9

# H1-H7 -- the language, from the KAT table.
check_kats "$HERE/fixtures/kat.tsv" "$HERE/fixtures/kat"

# H8 -- capacity: a 65536-byte dense source, and a comment-heavy one of the same size (capacity counts comments).
check_capacity H8

# H10 -- authorship: hex0 builds a native executable that the target's loader accepts and runs (exit 42).
M="$HERE/fixtures/mini-$TARGET.hex"
check_runs H10 "$M"
if [ -f "$M" ] && [ "$TARGET" = arm64-macos ]; then
  runb "$C" "$M" "$W/bad"; printf '\000' | dd of="$W/bad" bs=1 count=1 conv=notrunc 2>/dev/null
  if codesign --verify "$W/bad" 2>/dev/null; then no "H10 signature boundary: a corrupted copy still verifies (the check itself is broken)"
  else ok "H10 signature boundary: a one-byte corruption fails verification"; fi
fi
finish
