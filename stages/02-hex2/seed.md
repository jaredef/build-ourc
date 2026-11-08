# Stage 02: hex2, layout references

hex2 is hex1 plus two references that resolve a label to a *number* instead of a displacement: its output offset,
and its address. Entry points, buffer addresses and size fields stop being computed by hand, and a program no
longer has to be built once just to measure its own size.

```text
hex1 input + offset references + address references on stdin -> raw bytes on stdout
```

Any program satisfying Y1-Y7 is a conformant hex2. `check.sh` tests every one of them.

## Null style (what hex1 leaves open)

```text
branches are symbolic, but every absolute address, entry point and size field is still a hand-computed number
the classic error is an address off by a few bytes, found only when the program crashes
```

## Constraints, in order

### Y1. Conservativity: hex2 is a hex1

On input with no offset or address reference, hex2 behaves exactly as hex1 (X1-X5), on both the language tests
and the executable fixtures. Inside comments, the new markers are comment text.

*Checked by:* hex1's KATs (imported into `kat-<target>.tsv`), `transparent-chars.hex2`,
`layout-refs-in-comment.hex2`, capacity, and conservativity on hex1's executable fixtures (same output as hex1;
they still build, run and exit 42).

### Y2. `&X` emits the label's output offset

Four bytes, little-endian: `offset(X)`, the number of bytes emitted before label X.

*Forces:* sizes and file offsets become symbolic. A label at the end of the output gives the file size.
*Checked by:* `offset-forward.hex2`, `offset-backward.hex2`, and the executable fixture.

### Y3. `=X` emits the label's address

The address form is fixed by the target, because the target fixes where code is loaded.

| Target | Emits | Value |
|---|---|---|
| x86-64 | 4 bytes, little-endian | `BASE + offset(X)`, with `BASE = 0x400000`, the ELF load base (an 8-byte field is written as `=X 00 00 00 00`) |
| arm64 | 8 bytes, little-endian | `0x100000000 + 0x2b0 + offset(X)`: the preferred `__TEXT` address of a code *body* that the Mach-O envelope places at file offset `0x2b0` |

On arm64 this is a *preferred* address, for load-command and metadata fields. macOS loads code at a randomized
address (PIE), so executable code must not use it to reach data; use PC-relative instructions (`adr`, `adrp`).

*Forces:* entry points and data addresses become symbolic.
*Checked by:* `address-forward.hex2`, `address-backward.hex2`, and on x86 the executable fixture (`e_entry = =c`).

### Y4. Every reference has a fixed width, counted on every pass

`}X` (x86) and `@X`/`!X` (arm64) take 4 bytes; `&X` takes 4; `=X` takes 4 on x86 and 8 on arm64. A two-pass hex2
must count these widths on the first pass exactly as it emits them on the second.

*Forces:* forward layout references resolve correctly.
*Checked by:* `both-forward.hex2` and the forward KATs.

### Y5. Determinism and streams, as hex0

### Y5a. Capacity: at least 65536 input bytes, held in full

As hex1 (X5a). hex2's own source and M0's source must fit: one earlier realization's were 50600 and 50598
bytes.

*Checked by:* the capacity check.

### Y6. Self-hosting

hex2 rebuilds itself exactly from its own source. An earlier arm64 realization's source is plain hex; an earlier x86 one uses hex1
labels.

### Y7. Built by hex1

hex1 builds the first hex2 from a source in hex1's language (labels and branch references, but no `&` or `=`).

**One source or two.** Y6 and Y7 may be met by one source, written without `&` and `=` (then Y6 holds by Y1, and
says little about the new references), or by two: hex2's own source using `&` / `=` for Y6, and a bootstrap
without them for Y7. With two, both must give the same binary; the check compares them, but keeping them in step
is the author's job. Record which you chose.

**The bootstrap's own size is the one number hex2 cannot remove.** The bootstrap is in hex1's language, so its
`p_filesz` (or Mach-O sizes) must be written as a number. Count it by hand, or take it from one probe build of the
bootstrap (with any placeholder) and write it in; either is conformant, and the comment should say which. After
hex2 exists, no source needs this again.

## Preconditions (obligations on the author of a hex2 source)

hex1's P1-P4, and: every `&` and `=` is followed by its name character, and names a label that is defined.

## Choices left to the resolver

As hex1. The arm64 address constants (`0x100000000`, `0x2b0`) are tied to the Mach-O envelope described in targets/arm64-macos.md; a
different envelope must restate them, and Y3 then changes with it.

## Induced properties

- **No hand-computed addresses or sizes.** An ELF can set `e_entry = =c` and `p_filesz = &e` and be right by
  construction (x86 executable fixture). A Mach-O can set its entry offset and section offset to `&c` (arm64
  executable fixture).
- **No measuring build.** Sizes come from the layout itself (once hex2 exists; see Y7).

## What hex2 does not name

`=` and `&` resolve labels, and labels mark positions in the *output*. Memory past the end of the file (the
zero-filled buffers of `p_memsz`, a stack frame) has no label, so its addresses are still chosen by hand and
written as constants. That is not a violation of traps T6, which is about positions inside the file.
