#!/usr/bin/env bash
# The whole chain, closed: rebuild every stage from source in a fresh directory, each one ONLY by the stage below,
# check every self-host, and print each binary's size and hash. The stage checks prove one link at a time; this
# proves the links connect (STYLE.md, constraint 10).
#
#   check-chain.sh <target> <hex0-binary> <hex0-source> \
#                  <hex1-bootstrap-source> <hex1-source> \
#                  <hex2-bootstrap-source> <hex2-source> \
#                  <m0-source>
#
#   hex0-binary            the one binary made "by any means once" (hex0 seed.md, H9); it must rebuild itself
#   hex1-bootstrap-source  hex1 in hex0's language (hand-resolved)        -> built by hex0
#   hex1-source            hex1's own source (may be the same file)      -> built by hex1, must equal it
#   hex2-bootstrap-source  hex2 in hex1's language                       -> built by hex1
#   hex2-source            hex2's own source (may be the same file)      -> built by hex2, must equal it
#   m0-source              M0 in hex2's language                         -> built by hex2
#
# Inputs are always regular files (hex0 traps T1). Exit 0 iff every step holds.
set -uo pipefail
[ $# = 8 ] || { sed -n '7,17p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 2; }
TARGET="$1"; shift
case "$TARGET" in
  x86_64-linux) [ "$(uname -s)/$(uname -m)" = "Linux/x86_64" ] || { echo "x86_64-linux must run on x86-64 Linux" >&2; exit 2; } ;;
  arm64-macos)  [ "$(uname -s)/$(uname -m)" = "Darwin/arm64" ] || { echo "arm64-macos must run on Apple Silicon macOS" >&2; exit 2; } ;;
  *) echo "unknown target: $TARGET" >&2; exit 2 ;;
esac
for f in "$@"; do [ -f "$f" ] || { echo "not found: $f" >&2; exit 2; }; done
SEED="$1"; S0="$2"; B1="$3"; S1="$4"; B2="$5"; S2="$6"; S3="$7"
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
pass=0; fail=0
ok(){ echo "PASS $1"; pass=$((pass+1)); }
no(){ echo "FAIL $1"; fail=$((fail+1)); }
sz(){ wc -c < "$1" | tr -d ' '; }
hash(){ if command -v sha256sum >/dev/null; then sha256sum "$1" | cut -d' ' -f1; else shasum -a 256 "$1" | cut -d' ' -f1; fi; }
# build <builder> <source> <out>: the builder is run on the source file, nothing else produces <out>
build(){ "$1" < "$2" > "$3" 2>/dev/null; local rc=$?; chmod +x "$3"; return $rc; }
same(){ cmp -s "$1" "$2"; }

cp "$SEED" "$W/seed"; chmod +x "$W/seed"
build "$W/seed" "$S0" "$W/hex0"
if same "$W/hex0" "$W/seed"; then ok "hex0  the seed rebuilds itself from its source (H9)"; else no "hex0  seed < hex0-source != seed"; fi
build "$W/hex0" "$S0" "$W/hex0.2"
if same "$W/hex0.2" "$W/hex0"; then ok "hex0  fixed point: hex0 < hex0-source == hex0"; else no "hex0  not a fixed point"; fi

build "$W/hex0" "$B1" "$W/hex1"
if [ -s "$W/hex1" ]; then ok "hex1  built by hex0 from the bootstrap (X7): $(sz "$W/hex1") bytes"; else no "hex1  hex0 < hex1-bootstrap gave nothing"; fi
build "$W/hex1" "$S1" "$W/hex1.2"
if same "$W/hex1.2" "$W/hex1"; then ok "hex1  self-host: hex1 < hex1-source == the hex0 build (X6)"; else no "hex1  hex1 < hex1-source != hex0 < hex1-bootstrap"; fi

build "$W/hex1" "$B2" "$W/hex2"
if [ -s "$W/hex2" ]; then ok "hex2  built by hex1 from the bootstrap (Y7): $(sz "$W/hex2") bytes"; else no "hex2  hex1 < hex2-bootstrap gave nothing"; fi
build "$W/hex2" "$S2" "$W/hex2.2"
if same "$W/hex2.2" "$W/hex2"; then ok "hex2  self-host: hex2 < hex2-source == the hex1 build (Y6)"; else no "hex2  hex2 < hex2-source != hex1 < hex2-bootstrap"; fi

build "$W/hex2" "$S3" "$W/m0"
if [ -s "$W/m0" ]; then ok "m0    built by hex2 (Z10): $(sz "$W/m0") bytes"; else no "m0    hex2 < m0-source gave nothing"; fi

echo "--- the chain (size, sha256)"
for s in hex0 hex1 hex2 m0; do [ -f "$W/$s" ] && printf '%-5s %6s  %s\n' "$s" "$(sz "$W/$s")" "$(hash "$W/$s")"; done
echo "chain $TARGET: $pass passed, $fail failed"
[ "$fail" = 0 ]
