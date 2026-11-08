# Target: x86-64 Linux

The target fixes three things and nothing else: the executable container, how the program talks to the kernel,
and how instructions are encoded. Everything a stage *does* is in its `seed.md`; this file is only what the
platform demands.

## Container: a minimal static ELF64

One `PT_LOAD` segment is enough. No section headers, no interpreter, no dynamic linking.

| Fact | Value | Why it matters |
|---|---|---|
| ELF header | 64 bytes: `7f 45 4c 46`, class 64 (`02`), little-endian (`01`), version `01`, `e_type` 2 (EXEC), `e_machine` 62 (x86-64) | the kernel checks these before anything else |
| program header | 56 bytes, immediately after the ELF header (`e_phoff` 64, `e_phnum` 1) | the only load instruction the kernel needs |
| `p_flags` | 7 (R, W, X) | one segment then holds code and writable buffers |
| load base | `0x400000` (a conventional choice; any page-aligned non-zero address works) | `e_entry` = base + 0x78 when code follows the two headers |
| `p_filesz` | the exact file length | the kernel maps this many bytes |
| `p_memsz` | `p_filesz` + buffer space | bytes past the file are zero-filled: free, pre-zeroed buffers |
| `e_type` | 2 (`ET_EXEC`): loaded at its fixed address, no ASLR | code may then use 32-bit absolute addresses for its buffers (hex0 `traps.md`, T12) |

Fields the loader ignores (measured on Linux by flipping every bit of a minimal seed): `EI_OSABI` and the `e_ident`
padding, `e_flags`, the section-header fields (`e_shoff`, `e_shentsize`, `e_shnum`, `e_shstrndx`), `p_paddr`,
and most of `p_align`. They are free; every other field is load-bearing.

Policy: one `R|W|X` segment is accepted by stock Linux but refused where writable-and-executable mappings are
forbidden (SELinux `execmem`, PaX MPROTECT, some container profiles; hex0 `traps.md`, T13).

`stages/00-hex0` checks the container by building a 120-byte-header program that exits 42.

## Kernel interface: raw system calls

`syscall` instruction; number in `rax`; arguments in `rdi`, `rsi`, `rdx`; result in `rax` (negative errno on error).

| Call | Number | Used for |
|---|---:|---|
| `read` | 0 | read stdin (fd 0) into a buffer |
| `write` | 1 | write the output buffer to stdout (fd 1) |
| `exit` | 60 | exit with a status |

At process entry the System V ABI leaves the general registers zero except `rsp`. You may rely on that, but it is
cheaper to audit code that does not (see hex0 `traps.md`, T2).

The `syscall` instruction overwrites `rcx` and `r11`; every other register survives it (hex0 `traps.md`, T11).
Only the low 8 bits of the exit status are visible to the parent.

## Instruction encoding

Intel SDM Vol. 2. The traps measured in this chain: a missing REX.W prefix (32-bit vs 64-bit operation), and rel32
displacements counted from the *end* of the instruction. hex1's reference form is the rel32 displacement:
`target - (here + 4)`.

## Running the checks

`check.sh x86_64-linux ...` must run on x86-64 Linux itself. Do not substitute emulation (qemu-user): the check is
about what the real loader accepts.
