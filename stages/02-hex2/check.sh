#!/usr/bin/env bash
# hex2 conformance check: the constraints Y1-Y7 in seed.md.
#
#   check.sh <target> <candidate-hex2> <candidate-source> <hex1-binary> <source-hex1-builds-the-candidate-from>
#
# The last two arguments prove the candidate was built by the stage below; without them the chain check fails.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"; STAGE=hex2
. "$HERE/../../lib/check-lib.sh"
setup "$@"

check_built_by_previous Y7
check_self_host Y6
check_kats "$HERE/fixtures/kat-$TARGET.tsv" "$HERE/fixtures/kat"
check_capacity Y5a
# Y1 conservativity: on every hex1 executable fixture, hex2's output is hex1's.
for f in "$HERE"/../01-hex1/fixtures/run-*-"$TARGET".hex1; do check_same_as_previous Y1 "$f"; done
for f in "$HERE"/../01-hex1/fixtures/run-*-"$TARGET".hex1; do check_runs Y1 "$f"; done
for f in "$HERE"/fixtures/run-*-"$TARGET".hex2; do check_runs Y2 "$f"; done
finish
