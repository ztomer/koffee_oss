# Changelog

Koffee's release notes live in the annotated git tags (`v0.1.0`, `v0.2.0`); this file is the
running list, newest first, so a reader does not have to read a tag's prose to learn what a
commit changed.

## Unreleased

**The shipped architectures are gated.** The Release build was arm64-only because `project.yml`
said `ARCHS: "arm64"`, and nothing failed if an x86_64 slice came back — a setting that is only
a setting is a convention, and the house rule (target-platform-policy) is that an unsupported
architecture is a HARD FAILURE, never a warning that builds anyway.

- `tools/arch_gate.sh` reads the supported set from ONE declared source (`project.yml`'s
  `ARCHS`), builds Release, reads the shipped Mach-O with `lipo -archs`, and fails if any
  architecture outside the declared set is in the binary — an embedded framework counts, it
  ships too. It fails closed: no binary, no declared `ARCHS`, an unreadable project file are
  all red.
- `tools/arch_gate_test.sh` is the calibration: it builds real Mach-O fixtures (the declared
  architecture, an undeclared one, and a universal binary carrying the slice that came back) and
  reads every red by its message, not only by its exit code.
- Both run in `tools/gate.sh --full`, after the swift gate — that gate wipes `.build` when it
  is cold, so a Release build made before it would be deleted before it could be read.

What a user sees: nothing. What a push sees: a tree that ships an x86_64 slice is refused.

Re-check on your own setup: `tools/arch_gate.sh` prints the declared set and the architectures of
the Release binary it built; `tools/arch_gate_test.sh` proves the check can still fail.
