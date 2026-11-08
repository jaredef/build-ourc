# Resolver Contract

A resolver is whatever turns a stage's constraints into a working binary: a large language model, a person, or a
program. This contract is the same for all of them. It is written so that a model given this package and nothing
else can do the work, and so that the result can be judged without trusting the model.

## Inputs a resolver may use

- This repository.
- Public facts about the target: the executable format (ELF64, Mach-O), the instruction encodings (Intel SDM
  Vol. 2, the Arm ARM), the system-call numbers and calling convention, and the code-signing format on macOS. The
  `targets/` files list exactly which facts each stage needs.
- The binaries it has already built and checked for earlier stages.

## Inputs a resolver may not use

- A compiler, assembler or linker, to produce any byte of a stage. (They may be used to *read* a result, for
  example disassembling to check your own encoding, the way `objdump` is used as an oracle in the audits.)
- Any existing implementation of these stages, from anywhere: another repository, the web, memory of a known
  realization. The point is to find out whether these constraints alone determine a working chain.
- Any stage's bytes built by something other than the stage below it.

## What a resolver produces, per stage

1. **The source**, written in the language of the stage below. For hex0 that is commented hex: every byte written
   by hand, each with a comment saying what it is. For hex1 onward it is written in hex0, hex1 or hex2 source.
2. **The binary**, built from that source by the previous stage's binary (for hex0: by any means once, then by
   itself; see `stages/00-hex0/seed.md`, constraint H9).
3. **A derivation record**: first, the resolver's provenance (what it had seen before, which tools touched the
   result; see `AGENTS.md`). Then, for each numbered constraint in the stage's `seed.md`, where in the source it is
   satisfied, and for each trap in `traps.md`, how the source avoids it. This is what makes the bytes trace to
   constraints rather than to a remembered instance.
4. **Its own executable test.** The judged executable fixtures are held out, so a resolver writes one per stage
   (each stage's `seed.md` gives the shape) and records the result. It is the only executable evidence a resolver
   can produce before judging.

## How a resolver is judged

```sh
stages/NN-stage/check.sh <target> <candidate-binary> <candidate-source>
```

`check.sh` prints one line per check and exits 0 only if every check passes. It runs on the target itself; there
is no emulation, because loader and signature acceptance are part of what is being checked. A candidate need not
be byte-identical to any other realization. It must satisfy the constraints, and the checks test the constraints, not the
bytes.

## The loop

```text
read seed.md + traps.md + the target file
-> write the source, recording which constraint each part satisfies
-> build the binary with the previous stage
-> run check.sh
-> on failure: the failing line names a constraint; return to that constraint, not to the symptom
-> on pass: write the derivation record; move to the next stage
```

A failure the seeds cannot explain is the most valuable outcome: it means a constraint the chain relies on is
missing from the seed. Record it; that is how `traps.md` grew.
