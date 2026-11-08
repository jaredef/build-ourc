# Stage 00: hex0, the seed

hex0 turns commented hexadecimal text into raw bytes. It is the only stage written directly as bytes, and it is
the root of trust for the whole chain, so it is kept small enough to read in full and to account for byte by byte.

```text
commented hex on stdin -> raw bytes on stdout
```

Any program that satisfies H1-H10 below is a conformant hex0, on any target. It does not need to match any other
realization byte for byte. `check.sh` tests every constraint here and nothing else.

## Below this stage

hex0 starts from marks that already mean digits: the mark `a` is taken to mean the bits `1010`. hex0 is
the first stage that runs as native machine code.

## Null style

```text
a file of bytes may be executed
there is no source text for it: every byte is computed and written by hand, with no record of why
```

## Constraints, in order

Each constraint names the property it forces. Removing any one of them changes what hex0 accepts or produces, and
the named `check.sh` line catches it.

### H1. The digit alphabet is `0-9` and `a-f`, lowercase only

Only these sixteen characters are digits. `A-F` are not digits; they are ignored like any other non-digit (H4).

*Forces:* one spelling for every byte, so a source has exactly one reading. The stages above must write lowercase.
*Checked by:* `lowercase-pair.hex`, `uppercase-ignored.hex`.

### H2. Two digits make one byte, the first digit is the high nibble

Digits are taken in order; each pair `hl` becomes the byte `16*h + l`.

*Forces:* byte boundaries come from the text, not from position or layout.
*Checked by:* `lowercase-pair.hex`, `all-256-bytes.hex`.

### H3. `#` starts a comment that runs through the end of the line

Every character from `#` up to and including the next newline (LF, `\n`; a lone CR does not end a comment)
produces nothing and changes nothing, including a half-finished pair: `4# note\na` is the byte `4a`.
A comment that reaches the end of the input simply ends there.

*Forces:* the source can explain every byte without changing it, so the source is its own audit record.
*Checked by:* `comment-keeps-nibble.hex`, `comment-at-eof.hex`, `comment-lone-cr.hex`, `comment-crlf.hex`.

### H4. Every other character is ignored

Any character that is not a digit and not `#` (spaces, tabs, newlines, carriage returns, punctuation, letters
outside `a-f`, uppercase) produces nothing and does not change the pending nibble.

*Forces:* layout is free, and the stages above can add new markers (`:`, `}`, `=`, `&`, `%`) that hex0 passes over
harmlessly. That is what lets each stage extend this one without changing it.
*Checked by:* `transparent-chars.hex`, `uppercase-ignored.hex`.

### H5. A digit left without a partner at the end produces nothing

An odd number of digits drops the final one. No half byte is ever emitted.

*Forces:* every emitted byte came from exactly two digits.
*Checked by:* `odd-trailing-nibble.hex`.

### H6. Output order is input order, and the same input always gives the same output

*Forces:* the output can be recomputed from the source by anyone, mechanically.
*Checked by:* `all-256-bytes.hex`, and the self-host checks.

### H7. Read stdin, write stdout, exit 0

Empty input produces empty output and exit status 0.

The converse does not hold: exit status 0 is not evidence of success. A hex0 this small reports no failure (a
failed `read` or `write`, input past capacity), so the chain judges every build by its bytes (H9), never by status.

A failed `read` (a negative result on Linux, the carry flag on macOS) may be treated as empty input (output
nothing, exit 0) or reported with a non-zero exit; either is conformant. What is not conformant is decoding
garbage: a failed `read` must not be taken as a byte count.

*Forces:* hex0 composes in a pipeline with no arguments, files or environment.
*Checked by:* `empty.hex`, `comment-at-eof.hex`, and every check (each requires exit 0).

### H8. Capacity: a source of at least 65536 bytes is read and decoded in full

When stdin is a regular file. Capacity is counted in **input bytes, comments included**, not in digits. What
happens past the capacity is not specified, and a single-read hex0 drops the excess silently, with exit 0, so keep
your own source (H9) and the next stage's well under it. Two earlier seeds did: 4975 bytes on x86-64, 50677 on
arm64 (77% of the window, because the Mach-O signature is written out as hex).

*Forces:* hex0 can build its own source and the next stage's.
*Checked by:* the two capacity checks: 65536 digits in, 32768 bytes out; and a 65532-byte source that is mostly
comments (`4a #c` per line), 10922 bytes out. The second is what "comments included" means.

### H9. Self-hosting

The binary rebuilds itself exactly from its own commented source: `hex0 < hex0-source == hex0`. Its own bytes,
written back as plain hex, also reproduce it.

How the very first binary comes to exist is outside the chain: write the bytes by any means, once, then let H9
close the loop. From then on the source, not that first act, is what is trusted: anyone can check that the source
produces the binary, and audit the source by reading it.

*Forces:* the trust root is closed. The binary contains nothing its commented source does not explain.
*Checked by:* the two H9 checks.

### H10. hex0 can author a native executable

Expanding the target's fixture (`fixtures/mini-<target>.hex`) yields a program that the target's loader accepts
and that exits with status 42. On macOS that includes a valid code signature, and a corrupted copy must fail
signature verification.

The envelope must also give the body what the body assumes. On macOS: a non-zero `LC_MAIN` stack size that covers
the body's stack frame plus about 16 KB, and at least one of `LC_DYLD_CHAINED_FIXUPS` or `LC_DYSYMTAB`. On Linux:
a `p_memsz` that covers zero-filled buffers, `ET_EXEC` if the code uses absolute addresses, and segment flags the
loader permits. `targets/` has the measured details.

*Forces:* hex0's output is executable on the target, not just bytes. That is what every stage above relies on.
*Checked by:* the H10 checks.

**Testing it yourself.** The judged fixture is held out, so write your own before you finish: a complete
executable as commented hex, built by your hex0, that exits 42. Its shape is the same as the judged one's:
- x86-64 Linux: the 64-byte ELF header and one 56-byte `PT_LOAD` program header, code at file offset `0x78`
  (`e_entry` = base + `0x78`), `p_filesz` = `p_memsz` = the file length, and the three instructions
  `mov eax, 60; mov edi, 42; syscall`. About 132 bytes.
- arm64 macOS: the eight-load-command envelope of `targets/arm64-macos.md`, a body of
  `mov x0, #42; mov x16, #1; svc #0x80`, and a signature computed over the bytes before it.
Record it in your derivation; it is the only evidence of H10 you can produce yourself.

## What the target decides (see `targets/`)

The container (ELF or signed Mach-O), the system-call numbers and convention, and the instruction encodings. On
macOS most of the binary is the envelope: the algorithm is a few hundred bytes, the signed container about 16 KB.

## Choices left to the resolver

These are free. An earlier realization made one choice for each; any other that keeps H1-H10 is equally conformant.

- One `read` into a fixed buffer, or a loop of reads.
- Buffering the whole output and writing once, or writing as you go.
- Where the buffers live (zero-filled memory past the file, or the stack).
- How the pending nibble is represented.
- Register allocation and instruction selection.

## Induced properties (what the whole stage forces)

- **A source that is its own proof.** With H3 and H9 together, the commented source both explains and reproduces
  the binary. Reading it is auditing the seed.
- **Room for the stages above.** H4 makes hex0 ignore every marker the next stages introduce, so hex1, hex2 and M0
  can each accept all hex0 input unchanged.
- **No hidden builder.** H9 means that once the seed exists, no other tool is involved in producing it again.
