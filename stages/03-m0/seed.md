# Stage 03: M0, the token assembler

M0 changes the input from a character stream to a token stream. Names can be words; each instruction encoding can
be written once as a named macro and reused; and a token M0 does not recognise is an error instead of being
silently ignored. With M0, an encoding mistake can live in one place only, and a typo stops the build.

```text
whitespace-separated tokens (hex, labels, references, macros) on stdin -> raw bytes on stdout, or an error exit
```

Any program satisfying Z1-Z10 is a conformant M0. `check.sh` tests every one of them.

## Null style (what hex2 leaves open)

```text
addresses and displacements are symbolic, but names are one character, so a large source runs out of names
every instruction is re-encoded by hand at every use: one wrong prefix byte, copied ten times, is ten bugs
a misspelled marker is silently ignored, like any other non-hex character
```

## Not conservative over hex2

hex1 and hex2 accept every input of the stage below unchanged. M0 does not, deliberately: it tokenizes. A hex digit
pair split by a space (`4 a`) is two odd-length tokens, which is an error (Z8). Every hex0-style source written
as whitespace-separated pairs (`7f 45 4c 46 ...`) is still valid M0.

## Constraints, in order

### Z1. Tokens and hex tokens

Tokens are maximal runs of non-whitespace characters. **Whitespace** is at least space (`0x20`), tab (`0x09`), LF
(`0x0a`) and CR (`0x0d`); whether other control bytes (`0x00`-`0x1f`, `0x7f`) separate tokens is unspecified, so a
source must not contain them outside comments. A token starting with `#` begins a comment that runs to the
end of the line (LF; a lone CR does not end it). A `#` inside a token does not start a comment: `4a#c` is one
unknown token (Z8). A token made of an even number of lowercase hex digits emits those bytes, in order.

*Checked by:* `hex-token.m0`, `hex-tokens-whitespace.m0`, `comments.m0`, `comment-lone-cr.m0`, `comment-crlf.m0`,
`raw-arm64-exit.m0`, and `err/hash-inside-token.m0`.

### Z2. `:NAME` defines a label

`NAME` is the rest of the token, any length. It binds to the current output offset and emits nothing.

*Checked by:* `labels-emit-nothing.m0`.

### Z3. References by name

The reference kinds of hex1 and hex2, with multi-character names:

| Target | Token | Emits |
|---|---|---|
| x86-64 | `}NAME` | 4-byte rel32, `offset(NAME) - (here + 4)` |
| x86-64 | `&NAME` | 4-byte output offset |
| x86-64 | `=NAME` | 4-byte address, `0x400000 + offset(NAME)` |
| arm64 | `@NAME` / `!NAME` | the whole `b` / `bl` instruction, imm26 = `(offset(NAME) - here) / 4` |
| arm64 | `&NAME` | 4-byte output offset |
| arm64 | `=NAME` | 8-byte preferred address, `0x1000002b0 + offset(NAME)` |

*Checked by:* the reference KATs on each target, and the executable fixtures.

### Z4. arm64: `?WORD:NAME` patches a 19-bit displacement into an instruction

`WORD` is eight hex digits giving an instruction's *value* (for example `54000000` is `b.eq` with a zero offset,
`34000000` is `cbz w0`). M0 replaces bits 5-23 with `imm19 = (offset(NAME) - here) / 4`, masked to 19 bits, and
emits the result little-endian. M0 owns only the displacement; the author owns the condition and register bits.

*Forces:* conditional branches and compare-and-branch become symbolic without M0 having to know their names.
*Checked by:* `arm64-bcond-forward.m0`, `arm64-bcond-backward.m0`, `arm64-cbz-forward.m0`.

### Z5. `%NAME HEX` defines a macro

The token after `%NAME` must be a hex token (Z1); it becomes the macro's body. The definition emits nothing. A
body that is not a hex token is an error (Z8).

The body is **exactly one token**, not the rest of the line. In `%x 4a 4b` the body is `4a`, and `4b` is an
ordinary hex token after the definition: it is emitted. Write a multi-byte body as one token (`%x 4a4b`).

*Checked by:* `macro-body-one-token.m0` (traps T9).

### Z6. A bare token equal to a defined macro emits its body

Macros must be defined before they are used. Using one earlier is an error (Z8).

*Forces:* each instruction encoding is written once and audited once (encode once, audit once).
*Checked by:* `macro-use.m0`; `macro-arm64-exit.m0` must equal `raw-arm64-exit.m0`; `bad-macro-body.m0` and
`macro-used-before-defined.m0` must fail; the macro executable fixture.

### Z7. Labels resolve against final offsets; every reference has a fixed width

Forward references work. Reference widths are as in Z3 and Z4, counted the same on every pass.

### Z8. Unknown tokens are errors

A bare token that is neither a defined macro nor a valid even-length hex token makes M0 exit with status 3 (the
chain's convention). A reference (`}NAME`, `&NAME`, `=NAME`, arm64 `@NAME` / `!NAME` / `?WORD:NAME`) to a label
that is defined nowhere in the input also exits 3: it is the same typo, one level up. Other errors (a bad macro
body, a macro used before definition) must exit non-zero.

A label defined more than once is a precondition violation (as in hex1, P2): behaviour is unspecified, and a
source must not rely on it. An M0 may reject it; it must not silently pick one definition for some references and
another for others.

*Forces:* a misspelled instruction name stops the build instead of decoding to garbage.
*Residual, by design:* a name that is itself valid hex (`dead`, `be`) cannot be told from a hex token, so do not
name macros that way.
*Checked by:* `fixtures/err.tsv` (including `undefined-label.m0`).

### Z8a. Capacity and tables

M0 must hold, at least: **131072 input bytes** (comments included), **1024 labels**, **512 macros**, and names of
**64 characters**. These are sized for what M0 exists to build: one earlier M0 source for a first C front end is
102437 bytes with 537 labels and 294 macros. Past these limits behaviour is unspecified; a good M0 exits non-zero
(Z8) rather than crashing, but the checks do not require it (traps T8).

*Checked by:* the capacity and table checks.

### Z9. M0 builds native executables

The executable fixtures, written in M0, build into programs the target runs and that exit 42. On macOS they carry
a signature over the correctly assembled bytes.

### Z10. Built by hex2

hex2 builds M0 from a source in hex2's language. M0 is the first stage that is **not** required to rebuild
itself: its successor (for example, the first front end of a compiler) is written in M0, and that is what M0 exists to build.

## Choices left to the resolver

How names are stored (one earlier realization stores them as pointers into the input buffer, which stays unchanged across
both passes, so no strings are copied); how the macro table is kept; one pass with back-patching or two passes.

## Induced properties

- **Encode once.** An instruction's bytes appear in one `%` definition; a wrong encoding is one fix, not many.
- **Names are words.** Labels and macros can be as long as they need to be; single-character collisions end.
- **Typos are loud.** Z8 means a source that assembles contains no misspelled instruction (except a name that is
  valid hex).
