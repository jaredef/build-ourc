# Hex Chain Style

A Generative Computing Construction Style: a null style plus ordered, named constraints, where each constraint
forces a property, and the style is everything those constraints together force.
This document states the style for the whole chain; each stage's `seed.md` states its constraints in full.

## Null style

```text
bytes may be written to a file and the file may be executed
there is no source language, no symbolic name, no encoding discipline, and no trusted builder
```

At the null style every executable is hand-computed bytes. Nothing is checkable except by running it, and every
displacement, address, size and instruction encoding is a place an author can be silently wrong.

## Accumulated constraints

Each stage adds constraints to the one below. hex1 and hex2 never remove or change one: each accepts, unchanged,
every input of the stage below and produces the same bytes from it ("conservativity"). M0 deliberately changes the
representation, from characters to whitespace-separated tokens, so it rejects some hex2 input (a pair split by a
space); every source written as separated hex pairs is still valid M0.

| Order | Stage | Constraint added | Property it forces |
|---:|---|---|---|
| 1 | hex0 | pairs of lowercase hex digits become bytes, high nibble first | binary becomes writable as text |
| 2 | hex0 | `#` runs a comment to end of line; any other non-digit is ignored | the source is its own audit: comments explain bytes without changing them |
| 3 | hex0 | the seed rebuilds itself, byte for byte, from its own commented source | the trust root is closed: nothing outside the seed and its source built it |
| 4 | hex1 | `:X` binds a one-character name to the current output offset | positions become nameable |
| 5 | hex1 | a reference to a name emits the target's branch displacement to it, forward or back | branch and call displacements are never computed by hand |
| 6 | hex2 | references can also emit a name's load address, or its output offset | entry points, buffer addresses and size fields are never computed by hand, and no build has to be run once just to measure itself |
| 7 | M0 | the input is a token stream with multi-character names | names become words; single-character collisions end |
| 8 | M0 | `%NAME bytes` defines a macro; using `NAME` emits those bytes | each instruction encoding is written once and audited once, so an encoding error can live in one place only |
| 9 | M0 | a token that is neither a macro nor valid hex is an error (non-zero exit) | a typo fails loudly instead of decoding to garbage |
| 10 | all | each stage is built only by the stage below it, from source, on the target itself; hex0-hex2 also rebuild themselves | the chain has no compiler, assembler or linker in it, which is proven by running it |

## Induced properties

- **A bounded trust root.** The only thing written as raw bytes is hex0. It is small enough to read in full (269
  bytes on x86-64 Linux), and every byte of it can be named.
- **Arithmetic eliminated stage by stage.** Displacements (hex1), addresses and sizes (hex2), then instruction
  encodings (M0) stop being things an author computes. Each kind of mistake is removed at exactly one stage.
- **Self-hosting, observably.** hex0, hex1 and hex2 each rebuild themselves from their own source, and every stage
  is rebuilt by the stage below; both are checked by byte comparison, not claimed. M0 is built by hex2 and is not
  required to rebuild itself: what it exists to build is the next language up.
- **Target independence of the form.** The constraints above say nothing about ELF, Mach-O, x86-64 or arm64. A
  target fixes only the executable container, the system-call convention and the instruction encodings
  (`targets/`). Two targets realize one style.

## Generated artifact

```text
hex0 (hand-written bytes, self-hosting)
 -> hex1 (built by hex0)
 -> hex2 (built by hex1)
 -> M0   (built by hex2)
 -> anything written in M0, such as the first front end of a compiler
```

## Constraints and measurements

Two kinds of text appear in this package, and only one of them binds a resolver.

- **Constraints** are the numbered items in each `seed.md` (H1-H10, X1-X7, Y1-Y7, Z1-Z10) and the platform facts
  in `targets/`. Conformance is satisfying them; `check.sh` tests them.
- **Measurements** are everything a `traps.md` reports about "an earlier realization" or "the reference": its
  size, its buffer layout, its register use, the numbers it happened to choose. They are evidence of how a mistake
  shows up, never a requirement. A resolver that copies them is reproducing an instance (falsifier 4 below), and
  one that differs from them is not wrong.

## Falsifiers

The style is only a description, not a generative form, if any of these holds:

1. **A constraint can be removed and the artifact is unchanged.** Each stage's `check.sh` contains, for every
   constraint, a case that a stage violating it fails. If a constraint has no such case, it is prose, and the
   check is incomplete.
2. **A conformant implementation fails the next stage.** If an implementation passes a stage's check but cannot
   build the next stage from that stage's source, the seed is missing a constraint the chain relies on. (The
   `traps.md` files record the ones found so far.)
3. **A host tool is load-bearing.** If any stage's bytes depend on a compiler, assembler, linker, or a calculator
   script's output, rather than on the stage below, the chain is not closed.
4. **The derivation needed an existing implementation.** A resolver that passes only after reading one has copied
   an instance, not derived from the form, and the seeds under-determine the stage.
