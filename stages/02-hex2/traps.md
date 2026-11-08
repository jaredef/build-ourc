# hex2 traps

> Numbers here that describe "an earlier realization" or "the reference" are measurements, not constraints
> (`STYLE.md`, "Constraints and measurements"): they show how a mistake appears; they are not a layout to copy.

## T1. A reference's width differs between passes

**Shows up as:** every label after a forward `=` or `&` is off by 4 (or 8).
**Why:** the first pass must reserve exactly the width the second pass will emit: 4 for `&`, 4 or 8 for `=`
depending on the target, 4 for branches.
**Touches:** Y4. **Checked by:** `both-forward.hex2`.

## T2. The wrong width for `=` on a target

**Shows up as:** the bytes after an address field shift, or the high half of a 64-bit field is missing.
**Why:** x86's `=` is 4 bytes (the high dword is written by hand as zeros); arm64's is 8.
**Touches:** Y3, Y4. **Checked by:** the address KATs.

## T3. arm64: forgetting the code offset in the address base

**Shows up as:** addresses `0x2b0` too low.
**Why:** the preferred address of a body byte is `__TEXT` base `0x100000000` **plus the body's file offset**
(`0x2b0` in the envelope of targets/arm64-macos.md) plus the label offset.
**Touches:** Y3. **Checked by:** the address KATs.

## T4. arm64: using `=` in a whole-file source

**Shows up as:** every `=` in a source that includes the Mach-O header comes out `0x2b0` too high.
**Why:** the arm64 `=` assumes its labels are offsets within the code body. In a source that writes the whole
file, label offsets already include the `0x2b0`.
**Avoid:** in whole-file sources use `&` (file offsets: section offset, entry offset, sizes) and write preferred
addresses as plain hex; that is what `run-layout-arm64-macos.hex2` does.

## T5. Absolute addresses in macOS executable code

**Shows up as:** code that works until the load address changes (every run, under PIE).
**Why:** `=` gives a *preferred* address. The real one is slid.
**Avoid:** reach data PC-relatively (`adr`, `adrp`), and keep `=` for metadata fields.

## T6. An off-by-4 hand-computed address (the reason hex2 exists)

**Shows up as:** a crash at the first data access, or a loader that rejects the entry point.
**Why:** before hex2, every such number was computed by hand; this was the most frequent error at this level of an earlier chain.
**Avoid:** after hex2 exists, never write an address or size as a literal in a stage source; use `=` and `&`.
