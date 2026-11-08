# hex1 traps

> Numbers here that describe "an earlier realization" or "the reference" are measurements, not constraints
> (`STYLE.md`, "Constraints and measurements"): they show how a mistake appears; they are not a layout to copy.

Measured while building and auditing real hex1s on both targets.

## T1. Counting the displacement from the wrong place

**Shows up as:** every branch lands 4 bytes off (x86: a crash or a trap instruction; arm64: wrong code, or a
signature mismatch in the executable fixtures).
**Why:** x86 rel32 counts from the end of the 4-byte field; arm64 counts from the branch instruction itself. The
two targets disagree, and each is easy to apply to the other.
**Touches:** X3. **Checked by:** `arm64-self-branch.hex1` (a branch to itself is 0 on arm64), `arm64-forward-bl.hex1`,
`x86-forward-ref.hex1`.

## T2. Not counting a reference's 4 bytes on the first pass

**Shows up as:** backward branches are right and forward ones are off by 4 per reference in between.
**Why:** on the first pass a reference's value is unknown, so it is tempting to skip it. But its 4 bytes still
occupy output, and every later label's offset depends on that.
**Touches:** X4. **Checked by:** the forward KATs.

## T3. Recording a label's input position instead of its output offset

**Shows up as:** labels drift by however much comment text and whitespace comes before them.
**Touches:** X2, X4. **Checked by:** the `*-across-comment` KATs.

## T4. Decoding the label name as a hex digit

**Shows up as:** `:a` emits a nibble and the label is never defined.
**Why:** the name character is read by the general "is it a digit" path instead of being consumed by `:`.
**Touches:** X2. **Checked by:** `label-name-not-a-digit.hex1`.

## T5. Dropping the sign of a backward arm64 branch

**Shows up as:** forward branches work, backward ones go forward or to 0.
**Why:** `imm26` is two's complement in 26 bits. The negative displacement must be masked to 26 bits, not clamped
or shifted without sign.
**Touches:** X3. **Checked by:** `arm64-backward-bl.hex1`.

## T6. Absolute addresses in an arm64 macOS body

**Shows up as:** works in one run and crashes in another, or the loader refuses the image.
**Why:** macOS executables load at a randomized (PIE) address, and the loader rejects non-PIE images. The
reference keeps its input, output and label buffers on the stack (input at `sp`, output at `sp + 0x10000`, labels
at `sp + 0x20000`) so the body needs no absolute address at all.
**Avoid:** address everything relative to `sp` or to the program counter.

## T7. Assuming a system call preserves your registers

**Shows up as:** a buffer pointer that is fine before `read` and wrong after it (macOS).
**Why:** treat the system call as clobbering everything you have not saved yourself. An earlier realization keeps
long-lived values in registers it controls and re-derives the rest.

## T8. macOS: re-running a binary at the same path while testing

**Shows up as:** a binary with correct bytes refuses to run, after an earlier version at the same path hung.
**Why:** the kernel caches signature state per file. A test harness that overwrites one path can be poisoned by
an earlier run. `check.sh` builds each fixture under a fresh temporary directory.
**Touches:** nothing in hex1 itself; a harness trap.

## T9. Bootstrapping hex1 from its labeled source with hex0

**Shows up as:** hex0 "builds" the labeled source into garbage: it ignores `:` and `}`/`@`/`!`, but decodes any
label *name* that happens to be a hex digit, and emits no displacement bytes at all.
**Why:** hex0 does not understand labels. The first hex1 must come from a hand-resolved source (X7).
**Avoid:** write the bootstrap source with every displacement resolved by hand and explained in a comment, build
it with hex0, then let that hex1 build the labeled source, and check that both binaries agree.
