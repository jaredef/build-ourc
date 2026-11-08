# Agent onboarding

You are a **resolver**: you turn written constraints into working machine code. This repository holds the
constraints for a four-stage bootstrap chain (hex0 -> hex1 -> hex2 -> M0) and the checks that judge what you build.
It holds no implementation of any stage, on purpose. The point of every task here is to find out whether these
constraints alone are enough to build a working chain.

## Read first

1. `README.md`: what the chain is and how the repository is laid out.
2. `STYLE.md`: the construction style (the ordered constraints and what each one forces).
3. `RESOLVER.md`: what you may use, what you must produce, how you are judged.
4. `targets/<target>.md`: the platform facts for the target you are building for.
5. `stages/<NN-stage>/seed.md` and `traps.md`: the constraints for your stage and the mistakes measured on it.

## Isolation (the rules that make the result mean something)

- Use only this repository and public facts about the target (instruction encodings, the executable format, the
  system-call convention) that you already know.
- Do not read, list or search anything outside this directory. Do not use the network.
- Do not look for, or reconstruct from memory, an existing implementation of hex0, hex1, hex2 or M0. Derive from
  the constraints.
- No compiler, assembler or linker may produce any byte of a stage. You may use tools to *inspect* your own result
  (`xxd`, `otool`, `objdump`, `codesign --verify`), and a calculator script (python3, perl) to compute values, as
  long as the values are written into your commented source and the source alone rebuilds the binary.

## Where your work goes

```text
work/<target>/<NN-stage>/
  <stage>.hand.hex or <stage>.labeled.hex   your source, every byte or token commented
  <stage>.bin                               the binary, built from that source by the previous stage
  DERIVATION.md                             the derivation record (below)
```

`work/` is ignored by git. Do not edit anything outside `work/` unless the task says so.

## The loop

```text
read seed.md + traps.md + the target file
-> write the source, noting which constraint each part satisfies
-> build the binary with the previous stage (hex0: by any means once, then by itself)
-> run the stage's check.sh (arguments are in the stage README and at the top of check.sh)
-> a FAIL line names a constraint: go back to that constraint, not to the symptom
-> repeat until every line is PASS or JUDGE
```

`JUDGE` lines are checks whose fixtures are held out of this repository. A judge runs them afterwards; you cannot,
and do not need to.

## The derivation record (`DERIVATION.md`)

- **Provenance, first.** What you had seen before starting that bears on this stage (another repository, an
  existing hex0 / hex1 / hex2 / M0, an earlier attempt), and which tools touched your result (the one-time
  bootstrap of hex0, calculator scripts, inspectors). "None" is an answer. A resolver that had seen an existing
  implementation can still produce a valid chain, but its run shows only that the seeds are *sufficient*, not that
  they *determine* the result (`STYLE.md`, falsifier 4); this section is how a judge tells the two apart.
- For each numbered constraint in the stage's `seed.md`: where in your source it is satisfied.
- For each trap in `traps.md`: how your source avoids it.
- Every place the seeds were unclear, insufficient or wrong, and what you assumed. This section is the most
  valuable part of the record: it is how the seeds get better.

## Checking the whole chain

When every stage is done, run `check-chain.sh` (top level). It rebuilds the chain from your sources in a fresh
directory, each stage by the one below, checks every self-host, and prints the hash of each binary. A chain that
passes every stage check but not this one was assembled from binaries built some other way.

## Finishing

End with a short report: did `check.sh` pass (apart from JUDGE lines), the binary's size, and the most important
gaps you found in the seeds. If you cannot finish, say exactly where you stopped and why; a partial result with an
honest record is useful, an unexplained one is not.
