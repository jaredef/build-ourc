#!/usr/bin/env bash
# hex1 conformance check: the constraints X1-X7 in seed.md.
#
#   check.sh <target> <candidate-hex1> <candidate-source> <hex0-binary> <source-hex0-builds-the-candidate-from>
#
# The last two arguments prove the candidate was built by the stage below (STYLE.md constraint 10). They may be
# omitted while iterating; the chain check then fails, so a final run must include them.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"; STAGE=hex1
. "$HERE/../../lib/check-lib.sh"
setup "$@"

check_built_by_previous X7
check_self_host X6
check_kats "$HERE/fixtures/kat-$TARGET.tsv" "$HERE/fixtures/kat"
check_same_as_previous X1 "$HERE/../00-hex0/fixtures/mini-$TARGET.hex"
check_capacity X5a
case "$TARGET" in
  x86_64-linux) check_runs X3 "$HERE/fixtures/run-jump-x86_64-linux.hex1" ;;
  arm64-macos)  check_runs X3 "$HERE/fixtures/run-test-b-arm64-macos.hex1"
                check_runs X3 "$HERE/fixtures/run-test-bl-back-arm64-macos.hex1" ;;
esac
finish
