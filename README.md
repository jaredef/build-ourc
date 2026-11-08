<div align="center">

# build-ourc

**The seed of [ourc](https://github.com/jaredef/ourc), as constraints you can rebuild it from.**

[ourc.dev](https://ourc.dev)

![trusted seed](https://img.shields.io/badge/trusted_seed-~270_bytes-8A2BE2)
![stages](https://img.shields.io/badge/stages-hex0_→_hex1_→_hex2_→_M0-informational)
![no toolchain](https://img.shields.io/badge/compiler_%7C_assembler_%7C_linker-none-2ea44f)
![targets](https://img.shields.io/badge/targets-x86--64_Linux_%7C_arm64_macOS-blue)
![license](https://img.shields.io/badge/license-CC_BY_4.0-lightgrey)

</div>

## Where this sits

[ourc](https://github.com/jaredef/ourc) is a Rust compiler grown from 269 bytes of hand-written machine code: every
compiler in it is built by the one below, down to a seed small enough to read in one sitting. This repository is
that seed's bottom four stages (hex0, hex1, hex2, M0), restated as numbered constraints and executable checks, with
no implementation. Build them yourself from the constraints, run the checks, and you have re-derived ourc's root
of trust without trusting any of its bytes.

## The Hex Chain: a Generative Computing Construction Style

This package lets a resolver rebuild a machine-code bootstrap from its written constraints, with no compiler,
assembler or linker anywhere in the build. The resolver can be a large language model, a person, or any other
process. It receives only the constraints, produces the bytes itself, and an executable check decides whether
what it built conforms.

The chain is four stages. Each one is small enough to audit by hand, and each makes the next easier to write:

| Stage | Reads | Writes | Removes this kind of hand-work |
|---|---|---|---|
| `00-hex0` | commented hex | raw bytes | none: this is the seed, and it is hand-written bytes |
| `01-hex1` | hex + one-character labels | raw bytes | computing branch displacements by hand |
| `02-hex2` | hex + labels + absolute references | raw bytes | computing absolute addresses and size fields by hand |
| `03-m0` | named tokens, macros, labels | raw bytes | encoding instructions by hand (encode once, audit once) |

Each stage is built using the stage before it. Only hex0 is written directly as bytes, and hex0 can rebuild
itself from its own commented source. That is the whole trust root: about 270 bytes on x86-64 Linux, and a
small arm64 body inside a signed Mach-O envelope on macOS.

## How to use it

Agents: start with [`AGENTS.md`](AGENTS.md).

1. Read [`STYLE.md`](STYLE.md): the construction style as a whole (the null style, the ordered constraints, what
   each one forces, and what would show the style is only a description).
2. Read [`RESOLVER.md`](RESOLVER.md): the contract a resolver works under (what it may use, what it must
   produce, how it is judged).
3. Pick a target from [`targets/`](targets/). The target fixes the one thing that changes between platforms: the
   executable container, the system-call convention, and the instruction encodings.
4. Work the stages in order. Each `stages/NN-*/` holds:
   - `seed.md`: the stage's constraints, numbered. Satisfying all of them is conformance.
   - `traps.md`: mistakes measured on real derivations of this stage, and how each one shows up.
   - `fixtures/`: inputs the check runs, including inputs the stage must reject.
   - `check.sh`: the conformance check. Each stage README gives its arguments: your binary, your source, and the
     previous stage's binary with the source it built yours from (which proves the chain is closed).
5. A stage is done when its `check.sh` passes on your binary and you built that binary only from the stage below.
6. The chain is done when [`check-chain.sh`](check-chain.sh) passes: it rebuilds every stage from your sources in a
   fresh directory, each one only by the stage below, checks every self-host, and prints each binary's hash.
7. Each stage's `DERIVATION.md` starts with your provenance: what you had seen before, and which tools touched the
   result ([`AGENTS.md`](AGENTS.md)).

## Judging

The `check.sh` in each stage runs every language test. The executable checks (a stage must build small native
programs that the target runs, and on macOS that carry valid signatures) use fixtures that are held out of this
repository, because they contain complete executable containers. A judge runs them afterwards. They print as
`JUDGE` lines here.

## Provenance

The style form is constraint accumulation: a null style plus ordered constraints, each forcing a property
(`STYLE.md`). Everything needed to build the chain is in this repository.

## License

Copyright (c) 2026 Jared Foy. This work is licensed under the [Creative Commons Attribution 4.0 International
License](https://creativecommons.org/licenses/by/4.0/) (CC BY 4.0); see [`LICENSE`](LICENSE).
