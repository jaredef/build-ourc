# M0 traps

> Numbers here that describe "an earlier realization" or "the reference" are measurements, not constraints
> (`STYLE.md`, "Constraints and measurements"): they show how a mistake appears; they are not a layout to copy.

## T1. Reading `?WORD` as bytes instead of as a value

**Shows up as:** conditional branches come out byte-reversed.
**Why:** `?54000000:L` means the instruction value `0x54000000` (with imm19 patched in), emitted little-endian as
`60 00 00 54` for a 3-word forward branch. Reading `54000000` as the four bytes `54 00 00 00` is a different word.
**Touches:** Z4. **Checked by:** the imm19 KATs.

## T2. Patching imm19 at the wrong bits, or without its sign

**Shows up as:** conditional branches go to the wrong place, or backward ones go forward.
**Why:** imm19 occupies bits 5-23, and is two's complement in 19 bits.
**Touches:** Z4. **Checked by:** the imm19 KATs.

## T3. Silently accepting what should be an error

**Shows up as:** a source with a misspelled instruction assembles, and the program misbehaves later.
**Why:** treating an unknown token as "ignored", as hex0 treats unknown characters. M0's whole point is that this
stops.
**Touches:** Z8. **Checked by:** `fixtures/err.tsv`.

## T4. A comment that does not end at the newline

**Shows up as:** everything after the first comment vanishes.
**Touches:** Z1. **Checked by:** `comments.m0` and every executable fixture (they are commented).

## T5. Macro names that are valid hex

**Shows up as:** on an M0 that tries hex before macros, a macro named `dead` or `beef` is never expanded: the token
is decoded as hex instead.
**Why:** the bare-token grammar cannot tell a hex token from a macro named with hex digits. The arm64 reference resolves
macros first (measured: `%dead 4a` then `dead` emits `4a`), but a source should not depend on that.
**Avoid:** include a non-hex character in every macro name (`mov_x0`, `exit42`).

## T6. A pre-tokenizing port of a hex2 source

**Shows up as:** a hex2 source that worked fails in M0 with status 3.
**Why:** M0 is not conservative over hex2 (see `seed.md`). `4 a`, or single-character labels glued to hex
(`:a4a`), are fine in hex2 and errors or different tokens in M0.
**Avoid:** separate every hex pair, label and reference with whitespace when moving a source to M0.

## T7. Names as copies in a fixed-size table

**Shows up as:** long names collide or are truncated.
**Why:** copying names into small fixed slots. One earlier realization avoids it by keeping each name as a pointer and
length into the input buffer, which stays unchanged through both passes.

## T8. A full table that crashes instead of failing

**Shows up as:** M0 dies with SIGSEGV (status 139) and no output on a large source.
**Why:** fixed-size label and macro tables with no bound check. One measured realization crashed past 4525 labels
or 1238 macros: well above what Z8a requires, so it is conformant, but its overflow is silent corruption rather
than an error.
**Avoid:** check each table insert against its capacity and exit non-zero (Z8) when full; size the tables from the
largest source M0 must build (Z8a), with room to grow.

## T9. A macro body read as "the rest of the line"

**Shows up as:** stray bytes in the output right after a macro definition; an executable the loader refuses
("exec format error"), or a header shifted by a few bytes.
**Why:** `%NAME HEX` looks like it takes the rest of the line. It takes ONE token. `%hdr 7f454c46 02010100` defines
`hdr` as `7f454c46` and then emits `02 01 01 00` on the spot. Measured: a derivation of the x86-64 M0 test program
did exactly this and produced 8 stray bytes before the ELF header.
**Touches:** Z5. **Checked by:** `macro-body-one-token.m0`.
**Avoid:** write every multi-byte body as a single token (`%hdr 7f454c4602010100`).

## T10. An undefined label resolved to 0

**Shows up as:** a branch to the start of the output, or an address of the load base, with exit 0.
**Why:** hex1 and hex2 leave an undefined label unspecified (a precondition); carrying that over means a misspelled
label name assembles. Z8 makes it an error in M0.
**Touches:** Z8. **Checked by:** `err/undefined-label.m0`.
