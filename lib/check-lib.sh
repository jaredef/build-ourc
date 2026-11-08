# Shared helpers for the stage checks (sourced, not run). Host tools here (od, cmp, codesign --verify) only
# INSPECT results; none produces a byte of a candidate.
#
# A stage check.sh sets STAGE, sources this file, calls `setup "$@"`, then the check_* functions, then `finish`.
#   setup <target> <candidate> <candidate-source> [<previous-stage-binary> <source-for-previous-stage>]

setup(){
  [ $# = 3 ] || [ $# = 5 ] || { echo "usage: check.sh <x86_64-linux|arm64-macos> <candidate> <candidate-source> [<previous-stage-binary> <source-for-previous-stage>]" >&2; exit 2; }
  TARGET="$1"
  case "$TARGET" in
    x86_64-linux) [ "$(uname -s)/$(uname -m)" = "Linux/x86_64" ] || { echo "x86_64-linux checks must run on x86-64 Linux (no emulation)" >&2; exit 2; } ;;
    arm64-macos)  [ "$(uname -s)/$(uname -m)" = "Darwin/arm64" ] || { echo "arm64-macos checks must run on Apple Silicon macOS (no emulation)" >&2; exit 2; } ;;
    *) echo "unknown target: $TARGET" >&2; exit 2 ;;
  esac
  for f in "${@:2}"; do [ -f "$f" ] || { echo "not found: $f" >&2; exit 2; }; done
  W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
  CAND_ORIG="$2"; SRC="$3"; cp "$2" "$W/cand"; chmod +x "$W/cand"; C="$W/cand"
  PREV=""; PREVSRC=""
  if [ $# = 5 ]; then cp "$4" "$W/prev"; chmod +x "$W/prev"; PREV="$W/prev"; PREVSRC="$5"; fi
  pass=0; fail=0
}
ok(){ echo "PASS $1"; pass=$((pass+1)); }
no(){ echo "FAIL $1"; fail=$((fail+1)); }
hexof(){ od -An -v -tx1 "$1" | tr -d ' \n'; }
# Inputs are always regular files, never pipes (hex0 traps.md T1).
runb(){ "$1" < "$2" > "$3" 2>/dev/null; }
sz(){ wc -c < "$1" | tr -d ' '; }

# The previous stage builds the candidate from a source in the previous stage's language (STYLE.md, constraint 10).
check_built_by_previous(){ # $1 = constraint id
  if [ -z "$PREV" ]; then no "$1  built by the previous stage: not checked (pass <previous-stage-binary> <source-for-previous-stage>)"; return; fi
  if runb "$PREV" "$PREVSRC" "$W/byprev" && cmp -s "$W/byprev" "$C"; then ok "$1  built by the previous stage: previous < its source == candidate"
  else no "$1  built by the previous stage: previous < its source gave $(sz "$W/byprev") bytes, != candidate ($(sz "$C"))"; fi
}
# The candidate rebuilds itself from its own source.
check_self_host(){ # $1 = constraint id
  if runb "$C" "$SRC" "$W/self" && cmp -s "$W/self" "$C"; then ok "$1  self-host: candidate < its source == candidate"
  else no "$1  self-host: candidate < its source gave $(sz "$W/self") bytes, != candidate ($(sz "$C"))"; fi
}
# KAT table: input<TAB>expected-hex-or-"-"<TAB>constraint<TAB>failure-meaning. $1 table, $2 dir of inputs.
check_kats(){
  while IFS=$'\t' read -r in want cons why; do
    case "$in" in ''|\#*) continue ;; esac
    runb "$C" "$2/$in" "$W/k"; rc=$?
    got="$(hexof "$W/k")"; [ "$want" = "-" ] && want=""
    if [ "$rc" = 0 ] && [ "$got" = "$want" ]; then ok "$cons  $in"
    else no "$cons  $in: got '${got:-<empty>}' rc=$rc, want '${want:-<empty>}'; a failing $STAGE is $why"; fi
  done < "$1"
}
# Expected-error inputs: the candidate must exit non-zero with the given status. $1 table (input<TAB>status<TAB>constraint<TAB>meaning)
check_errors(){
  while IFS=$'\t' read -r in want cons why; do
    case "$in" in ''|\#*) continue ;; esac
    runb "$C" "$2/$in" "$W/e"; rc=$?
    if [ "$rc" = "$want" ] || { [ "$want" = nz ] && [ "$rc" != 0 ]; }; then ok "$cons  $in: exits $rc"
    else no "$cons  $in: exit $rc, want $want; a failing $STAGE is $why"; fi
  done < "$1"
}
# Conservativity: on input the previous stage accepts, the candidate's output equals the previous stage's.
check_same_as_previous(){ # $1 constraint, $2 input
  [ -f "$2" ] || { echo "JUDGE $1  conservativity on $(basename "$2"): fixture held out; run by the judge"; return; }
  if [ -z "$PREV" ]; then no "$1  conservativity on $(basename "$2"): not checked (no previous-stage binary given)"; return; fi
  runb "$PREV" "$2" "$W/p1"; runb "$C" "$2" "$W/p2"
  if cmp -s "$W/p1" "$W/p2"; then ok "$1  conservativity: same output as the previous stage on $(basename "$2")"
  else no "$1  conservativity: output differs from the previous stage on $(basename "$2")"; fi
}
# Build an executable fixture with the candidate and run it: on macOS the signature must verify; exit must be 42.
check_runs(){ # $1 constraint, $2 fixture
  [ -f "$2" ] || { echo "JUDGE $1  executable fixtures: held out; run by the judge"; return; }
  local n; n="$(basename "$2")"; runb "$C" "$2" "$W/x"; chmod +x "$W/x"
  if [ "$TARGET" = arm64-macos ] && ! codesign --verify "$W/x" 2>/dev/null; then
    no "$1  $n: the built Mach-O's signature does not verify (some resolved byte is wrong)"; return; fi
  ( "$W/x" ) >/dev/null 2>&1; local st=$?
  if [ "$st" = 42 ]; then ok "$1  $n: builds, runs, exits 42"; else no "$1  $n: built program exited $st, want 42"; fi
}
check_capacity(){ # $1 constraint: a 65536-byte dense source decodes in full
  perl -e 'print "5a" x 32768' > "$W/dense"
  if runb "$C" "$W/dense" "$W/dense.out" && [ "$(sz "$W/dense.out")" = 32768 ]; then ok "$1  capacity: 65536-byte source -> 32768 bytes"
  else no "$1  capacity: 65536-byte source gave $(sz "$W/dense.out") bytes, want 32768"; fi
  # Capacity is counted in INPUT bytes, comments included (hex0 H8): a comment-heavy source of the same size.
  # 10922 lines of "4a #c\n" = 65532 bytes; each line is one byte of output.
  perl -e 'print "4a #c\n" x 10922' > "$W/commented"
  if runb "$C" "$W/commented" "$W/commented.out" && [ "$(sz "$W/commented.out")" = 10922 ]; then ok "$1  capacity: 65532-byte commented source -> 10922 bytes"
  else no "$1  capacity: 65532-byte commented source gave $(sz "$W/commented.out") bytes, want 10922 (comments count toward capacity)"; fi
}
# The candidate's own bytes, written back as bare hex, reproduce it (hex0 H9).
check_raw_fixed_point(){ # $1 constraint
  hexof "$C" > "$W/raw.hex"
  if runb "$C" "$W/raw.hex" "$W/raw.bin" && cmp -s "$W/raw.bin" "$C"; then ok "$1  raw fixed point: candidate < hex(candidate) == candidate"
  else no "$1  raw fixed point: candidate < hex(candidate) != candidate"; fi
}
finish(){ echo "$STAGE $TARGET: $pass passed, $fail failed"; [ "$fail" = 0 ]; }
