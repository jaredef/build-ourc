# Target: arm64 macOS (Apple Silicon)

The target fixes three things and nothing else: the executable container, how the program talks to the kernel,
and how instructions are encoded. On macOS the container is most of the work. The algorithm body of hex0 is a few
hundred bytes; the envelope the loader will accept, with its code signature, is about 16 KB.

## Container: a signed Mach-O that dyld will load

macOS on arm64 does not run unsigned code, and it does not load fully static executables. The minimal accepted
shape, as measured:

| Load command | Content | Hard constraint measured |
|---|---|---|
| `LC_SEGMENT_64 __PAGEZERO` | vmaddr 0, vmsize `0x100000000` (4 GB), no file bytes | **must be at least 4 GB**: a smaller one is killed at exec (SIGKILL, measured on macOS 15) |
| `LC_SEGMENT_64 __TEXT` | vmaddr `0x100000000`, file offset 0, one 16 KB page, with a `__text` section for the body | the header and load commands live inside this segment |
| `LC_SEGMENT_64 __LINKEDIT` | the page after `__TEXT`; holds the metadata below and the signature | |
| `LC_SYMTAB` | a minimal symbol table | **required**: dyld aborts without it (status 134) |
| `LC_DYLD_CHAINED_FIXUPS` or `LC_DYSYMTAB` | minimal tables (no imports) | **at least one of the two is required**: with neither, the process crashes before the entry point (139). Either alone is enough |
| `LC_LOAD_DYLINKER` | `/usr/lib/dyld` | **required** (SIGKILL without it) |
| `LC_MAIN` | entry offset (file offset of the body), stack size | **required** (SIGKILL without it). The stack size must be **non-zero** and at least the body's stack frame **plus about 16 KB** for dyld: a 128 KB frame crashed at a stack size of `0x20000` and ran at `0x24000`. A stack size of 0 means "inherit the caller's limit", which makes the program fail under a small `ulimit -s` |
| `LC_CODE_SIGNATURE` | offset and size of the signature blob in `__LINKEDIT` | **required** |
| `LC_DYLD_EXPORTS_TRIE`, `LC_LOAD_DYLIB` (libSystem), `LC_UUID`, `LC_BUILD_VERSION`, `LC_SOURCE_VERSION`, `LC_FUNCTION_STARTS`, `LC_DATA_IN_CODE` | standard values | **optional**: each can be removed, and all together, and the seed still runs and reproduces itself. libSystem is not needed, because the program makes no library calls |

Measured by removing each load command in turn, then combinations, re-signing, and running (macOS 15.6.1). The
smallest envelope that runs has eight load commands: the three segments, `LC_DYLD_CHAINED_FIXUPS` (or
`LC_DYSYMTAB`), `LC_SYMTAB`, `LC_LOAD_DYLINKER`, `LC_MAIN`, `LC_CODE_SIGNATURE`.

**The code signature** is an embedded SuperBlob containing an ad hoc CodeDirectory: flags `adhoc` +
`linker-signed`, SHA-256, 4 KB pages, one hash per page of the file up to the signature's own offset. Change any
byte before the signature and the page hash no longer matches: the kernel kills the process at launch. The check
for hex0 verifies this both ways (a good fixture verifies and runs; a one-byte corruption fails verification).

Two consequences for the chain:
- Every stage's *output* that is meant to run must carry its own valid signature. The hex stages do not compute
  SHA-256: the signature is data in the source, computed once when the source is written. The M0 stage is where a
  macro vocabulary for the envelope becomes worthwhile.
- `codesign --verify` and `otool` may be used to *inspect* a result. Using `codesign -s` to *produce* a signature
  puts a host tool in the build and breaks the chain (`RESOLVER.md`).

## Kernel interface: raw system calls

`svc #0x80`; number in `x16`; arguments in `x0`, `x1`, `x2`; result in `x0`. The carry flag is set on error, with
a positive errno in `x0` (unlike Linux, which returns a negative value). The kernel reads only `x16`: the `svc`
immediate is ignored (every one of its 16 bits can be changed; `#0x80` is convention). Only the low 8 bits of the
exit status are visible to the parent. A failed `read` or `write` is not reported unless the program checks the
carry flag.

| Call | Number | Used for |
|---|---:|---|
| `exit` | 1 | exit with a status |
| `read` | 3 | read stdin (fd 0) |
| `write` | 4 | write stdout (fd 1) |

## Instruction encoding

The Arm ARM (A64). Every instruction is 4 bytes, little-endian. Branches count in instructions, not bytes: `b` is
`0x14000000 | ((target - here) >> 2)` in 26 bits, measured from the branch itself (not from its end, as on x86). A
branch target must be 4-byte aligned; hex1's check rejects an unaligned one.

## Running the checks

`check.sh arm64-macos ...` must run on an Apple Silicon Mac, natively. Rosetta and emulators are not substitutes:
the loader and signature checks are the point.
