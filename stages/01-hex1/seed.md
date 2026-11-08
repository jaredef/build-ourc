# Stage 01: hex1, labels and branch references

hex1 is hex0 plus names for positions. An author writes `:X` where a label goes and a reference where a branch
needs its displacement, and hex1 computes the displacement. That removes the one kind of arithmetic hex0's own
source cannot avoid.

```text
commented hex + one-character labels + branch references on stdin -> raw bytes on stdout
```

Any program satisfying X1-X7 is a conformant hex1. `check.sh` tests every one of them.

## Null style (what hex0 leaves open)

```text
every branch displacement is computed by hand, from byte counts, and written as hex
moving one instruction means recomputing every displacement that crosses it
```

## Constraints, in order

### X1. Conservativity: hex1 is a hex0

On input with no `:` and no reference marker, hex1 behaves exactly as hex0 (H1-H8): same bytes, same treatment of
comments, uppercase, odd digits, empty input, and capacity. Inside a comment, `:` and reference markers are
comment text.

*Forces:* every hex0 source is a hex1 source. The chain never loses ground.
*Checked by:* the `hex0-*` KATs, `refs-in-comment.hex1`, the capacity check, and conservativity on hex0's
`mini-<target>.hex` (hex1's output must equal hex0's).

### X2. `:` plus one character defines a label

The character right after `:`, whatever it is (including a hex digit), is the label's name. The definition binds
that name to the current *output* offset (the number of bytes emitted so far) and emits nothing.

*Forces:* positions become nameable, and layout (comments, spaces, other labels) cannot move them.
*Checked by:* `label-emits-nothing.hex1`, `label-name-not-a-digit.hex1`.

### X3. A reference emits the target's branch displacement to a label

The form is fixed by the target, because the target fixes how branches are encoded.

| Target | Token | Emits (4 bytes, little-endian) |
|---|---|---|
| x86-64 | `}X` | the signed 32-bit value `offset(X) - (here + 4)`: an x86 rel32, counted from the **end** of the field |
| arm64 | `@X` | the whole instruction `b X`: `0x14000000 \| imm26` |
| arm64 | `!X` | the whole instruction `bl X`: `0x94000000 \| imm26` |

`here` is the output offset where the reference's 4 bytes start. On arm64, `imm26 = (offset(X) - here) / 4`, kept
to its low 26 bits (two's complement for backward branches), and counted from the branch instruction **itself**.

*Forces:* no displacement is ever computed by hand, and the code remains correct wherever it is loaded (the
displacements are relative).
*Checked by:* the `x86-*` / `arm64-*` KATs, and the executable fixtures, which must build, run and exit 42.

### X4. References resolve against final offsets, forward and back

A reference may name a label defined later. Every reference takes exactly 4 output bytes when offsets are being
counted, so a two-pass hex1 must count those 4 bytes on the first pass too, before it knows the displacement.

*Forces:* code can be written in reading order; a forward branch needs no placeholder arithmetic.
*Checked by:* the forward-reference KATs, `x86-two-refs.hex1`, the `*-across-comment` KATs.

### X5. Determinism and streams, as hex0

Same input, same output; stdin to stdout; exit 0.

### X5a. Capacity: at least 65536 input bytes, held in full

Counted as in hex0 (H8): input bytes, comments included. Resolving forward references needs either the whole input
held (two passes) or every reference site remembered (back-patching); either way the capacity is a hard bound, not a
streaming window. hex1's own source must fit, with room: one earlier realization's was 50600 bytes (77%).
The label table must hold every distinct one-byte name (up to 256).

*Checked by:* the capacity check.

### X6. Self-hosting

hex1 rebuilds itself exactly from its own source: `hex1 < hex1-source == hex1`. The source may use labels and
references (that is the point), or be plain hex (then X1 makes this hold trivially; an earlier arm64 realization's source
is plain hex with every branch word written out).

A plain-hex source meets X6 without exercising labels at all, so it says little about hex1 itself. A resolver
should also show the labeled form: a source that uses `:` and references, built by hex1, giving the same binary as
the hand-resolved bootstrap (X7). Record which form your X6 source is.

*Checked by:* the X6 self-host check.

### X7. Built by hex0

The first hex1 binary is built by hex0, from a source in hex0's language: hex with every displacement resolved by
hand, each one shown in a comment (`# b +0x18: imm26 = 0x18/4 = 6`). That hand-resolved source is the bootstrap.
After it, hex1 can build itself from its labeled source (X6), and the two builds must agree.

*Forces:* the chain stays closed: nothing but hex0 and a written source produced hex1.
*Checked by:* the X7 check (pass hex0 and the bootstrap source to `check.sh`).

## Preconditions (obligations on the author of a hex1 source, not on hex1)

hex1 need not detect these; behaviour on violating input is unspecified, and a source must not rely on it.

- **P1.** Every `:` and every reference marker is followed by its one name character. A marker as the last byte
  of the input has no name: behaviour is unspecified, and hex1 must not read past the end of its input buffer to
  find one (a realization with a tight buffer would fault).
- **P2.** Every referenced label is defined exactly once.
- **P3.** arm64: every branch target is 4-byte aligned, and its displacement fits 26 bits (±128 MB).
- **P4.** Sources use lowercase hex.

## Choices left to the resolver

Two passes over a buffered input, or one pass with back-patching; how labels are stored (one earlier realization uses 256
slots, indexed by the name byte); buffer placement; register allocation.

## What hex1 does not resolve

Only the reference forms of X3. On x86-64 that is the 4-byte rel32: short branches (`eb`, `7x`: rel8) and any
other displacement width are still hand-computed. A source that wants every branch symbolic must use the rel32
forms (`e9`, `e8`, `0f 8x`), which are 3-4 bytes longer each. That is a size-for-safety trade, not a defect.

## Induced properties

- **No displacement arithmetic in authored code.** Moving code means moving text; hex1 recomputes the rest.
- **Self-hosting with names.** hex1's own source can be written with labels and still be checked, byte for byte,
  against the binary it builds.
- **Target-shaped references.** The form says *resolve a branch displacement*; the target says what a branch
  looks like. x86 puts the displacement in a field after the opcode, arm64 inside the instruction word. A port
  that copies x86's rel32 onto arm64 fails X3.
