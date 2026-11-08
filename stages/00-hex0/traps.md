# hex0 traps

> Numbers here that describe "an earlier realization" or "the reference" are measurements, not constraints
> (`STYLE.md`, "Constraints and measurements"): they show how a mistake appears; they are not a layout to copy.

Mistakes measured while building and auditing real hex0s on both targets. Each says how it shows up, which
constraint it touches, and how to avoid it.

## T1. A pipe is not a file: one `read` can come back short

**Shows up as:** a large source decodes to fewer bytes than it should, and a different number each run.
**Why:** a hex0 that reads its input with a single `read` gets whatever is in the pipe at that moment. From a
regular file, one `read` returns the whole request.
**Touches:** H8.
**Avoid:** either loop until `read` returns 0, or always feed the source from a file. `check.sh` always uses files.
In an earlier audit this exact effect fooled a measurement harness: it compared against randomly truncated
output and over-counted the load-bearing bits by about 500.

## T2. Relying on registers being zero at entry

**Shows up as:** nothing, on the platform you tested; wrong output on another loader or OS.
**Why:** the x86-64 System V ABI starts the process with general registers zero, so code that skips initializing
them works. About 29% of an earlier realization's bits turn out to be free for reasons like this; they are harmless, but
code that depends on them is harder to audit and to port.
**Touches:** H6.
**Avoid:** initialize what you use, and say so in the comment.

## T3. Accepting uppercase

**Shows up as:** `4A` decodes to `4a` instead of nothing.
**Why:** an "is it a hex digit" test written for both cases. The chain's sources are lowercase, and the other
stages' rejection rules assume a single spelling.
**Touches:** H1. **Checked by:** `uppercase-ignored.hex`.

## T4. Resetting the pending nibble on a comment or a non-digit

**Shows up as:** `4# note\na` decodes to nothing, or `4 a` decodes to nothing.
**Why:** treating a comment or a space as the end of a pair.
**Touches:** H3, H4. **Checked by:** `comment-keeps-nibble.hex`, `transparent-chars.hex`.

## T5. Displacements counted from the wrong place

**Shows up as:** the seed crashes or loops on the first branch.
**Why:** x86 rel8/rel32 displacements count from the end of the instruction; arm64 branch offsets count in
instructions from the branch itself. hex0 has to compute these by hand; that is the one kind of arithmetic hex0's
own source cannot avoid, and the reason hex1 exists.
**Avoid:** for every branch, write the target offset and the arithmetic in the comment. An audit of an earlier x86 realization
verifies all 13 displacements land on instruction boundaries.

## T6. macOS: changing a byte invalidates the signature

**Shows up as:** the process is killed at launch (no output; status 137 or a "Killed" message).
**Why:** the code signature holds a SHA-256 hash of every 4 KB page before it. Any edit to the code or header
changes a page hash.
**Touches:** H10 (and H9: the seed itself is signed).
**Avoid:** treat the signature as data that is recomputed whenever anything before it changes, and recompute it
before testing. A calculator script may compute it (an earlier realization used one), but its output is then written into
the source by hand and checked; the script is never part of the build.

## T7. macOS: `__PAGEZERO` smaller than 4 GB

**Shows up as:** killed at exec, before any instruction runs.
**Why:** arm64 macOS requires the first 4 GB to be unmapped.
**Avoid:** `__PAGEZERO` vmsize `0x100000000`; put `__TEXT` at `0x100000000`.

## T8. A calculator script mistaken for the source

**Shows up as:** a source that only a script can regenerate.
**Why:** it is easiest to generate the first bytes with a script. An earlier macOS seed was written that way.
**Touches:** H9.
**Avoid:** the commented source is the source of record. A script may help write it once, but H9 must then hold
from that source alone, and no check may call the script.

## T9. Trusting the exit status

**Shows up as:** a build that "succeeded" (exit 0) but produced short or empty output.
**Why:** a hex0 this small checks nothing. A failed `read` (closed or unreadable stdin), a failed `write` (closed
or full stdout), and input past capacity all still exit 0 in both earlier seeds (measured on arm64; read from the
source on x86-64, where a negative `read` result makes the end pointer fall below the cursor, so nothing is
written).
**Touches:** H7, H8.
**Avoid:** judge every stage by comparing bytes (H9), never by exit status.

## T10. A read count larger than the gap to the output buffer

**Shows up as:** nothing on normal input; on oversized input the extra bytes land in the output buffer.
**Why:** if the input and output buffers are adjacent, the read count must not exceed the gap between them. An earlier
x86-64 realization had zero margin: it reads `0x10000` bytes into a buffer exactly `0x10000` below the output
buffer. An earlier arm64 realization's count can be raised freely in its 128 KB frame only because H8 leaves oversized input
unspecified.
**Touches:** H8.

## T11. x86-64: values kept in `rcx` or `r11` across `syscall`

**Shows up as:** a pointer or counter that is right before the `read` and wrong after it.
**Why:** the `syscall` instruction overwrites `rcx` (return address) and `r11` (flags), and the kernel returns its
result in `rax`. Every other general register survives. An earlier realization relies on this: it computes the end pointer
as `rsi + rax` right after `read`.
**Touches:** H6, H8.

## T12. x86-64: 32-bit absolute addresses in a position-independent image

**Shows up as:** a crash at the first buffer access.
**Why:** an earlier realization addresses its buffers with 32-bit immediates (`mov esi, 0x40010d`). That is only valid
because an `ET_EXEC` image loads at its fixed address, below 4 GB, without ASLR. Built as `ET_DYN` (PIE), the
same code would point at unmapped memory.
**Avoid:** use `e_type = ET_EXEC` with a low fixed base, or address everything relative to `rip`.

## T13. x86-64: a writable and executable segment under a strict policy

**Shows up as:** the kernel refuses to run the seed at all, on some hardened systems only.
**Why:** a minimal seed maps code and buffers in one `PT_LOAD` with `p_flags = R|W|X`. Stock Linux accepts this.
A policy that forbids writable-and-executable mappings (an SELinux `execmem` denial, PaX/grsecurity MPROTECT,
some container profiles) does not.
**Avoid:** know your machine; or use two segments, code `R|X` and buffers `R|W`, at the cost of a second program
header.

## T14. macOS: a stack size that does not cover the body's frame

**Shows up as:** a crash (status 139) on every input, including empty input; or a crash only when the caller has
lowered its stack limit (`ulimit -s`).
**Why:** a seed that keeps its buffers on the stack reserves them first (a 128 KB frame in one measured
realization). `LC_MAIN`'s stack size must be at least that frame plus about 16 KB that dyld uses itself, and it must
be non-zero: 0 means "inherit the caller's limit".
**Avoid:** set `LC_MAIN.stacksize` explicitly, with room to spare (1 MB is cheap: the stack is not file bytes).
