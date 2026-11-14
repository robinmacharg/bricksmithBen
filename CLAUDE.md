# Bricksmith: notes for agents and contributors

Bricksmith is a macOS LEGO CAD app (LDraw editor), written in Objective-C and C. It is being ported to Swift.
Read these first:
- **[docs/LEARNINGS.md](docs/LEARNINGS.md): read this first.** It lists mistakes already made and gotchas already hit. Add an entry whenever something bites.
- [docs/swift-port-plan.md](docs/swift-port-plan.md): the plan. It covers phases, interop rules, the per-class recipe and exit gates.
- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md): how the code is organised.
- [docs/TESTING.md](docs/TESTING.md): how to test, plus the manual smoke checklist.
- [docs/port-status.md](docs/port-status.md): per-file phase and status ledger. Keep it current.
- [docs/KNOWN-BUGS.md](docs/KNOWN-BUGS.md): bugs found along the way. They are recorded, not fixed, until P12.

## Toolchain
- Use only the Xcode 26.3 built-in Swift (6.2.4). No external toolchains or swiftly.
- Project: `trunk/Bricksmith/Bricksmith.xcodeproj`, scheme `Bricksmith`.
- Build: `scripts/build.sh` (Debug) or `scripts/build.sh --release`. These always do a clean build into
  `build/DerivedData`, and fail on any compiler warning that isn't in `docs/warnings-baseline*.txt`.
  - Re-record a baseline with `--update-baseline`, but only deliberately, and explain why in the commit.
  - Tests: `scripts/test.sh` (arrives in P1).
- The shell is zsh, so quote globs and paths that contain spaces (`"trunk/Test Data"`).

## Versioning
- The Swift port is version **4.0.x**. Each phase merged to `master` bumps the patch number.
- Major follow-ons, such as Metal, bump the minor number (4.1.0).
- Releases and the appcast are manual.

## Git conventions
- Branches are stacked and dated: `YYYYMMDD-topic`, where the date is the day the branch was cut. Each phase
  branch starts from the previous phase's tip. Restack with `git rebase --update-refs`.
- Every commit builds and passes tests. During porting, put one class in each commit.
- Tag `snapshot-20261114-pre-swift-plan` marks the app before the port started.
- Don't push to `origin` unless asked. Don't commit `trunk/Bricksmith/Source/LDraw.zip`, a local backup.

## Porting rules (summary; the plan is authoritative)
- Ported classes keep their ObjC runtime names: `@objc(OriginalName)`. Xibs, Info.plist and NSCoding archives depend on them.
- ObjC can't subclass Swift, so port **leaves before roots** in any class hierarchy, UI classes included.
- No NSException may unwind through Swift. No `init` may return a substitute object. Swift can't see ObjC ivars.
  P4 removes all three patterns before any model class is ported. The plan's §6 recipe has a grep checklist for them.
- Tests must never touch real user defaults or the developer's LDraw library. Use the test-mode launch guard,
  `+[LDrawPaths setOverrideLDrawPath:]` (the defaults key is `"LDraw Path"`, with a space), and a fixture library
  copied to a temp directory. `scripts/test.sh` fails if the real defaults change.
- C stays C in this plan: `MatrixMath.c`, `GLMatrixMath.c`, `MeshSmooth.c` and LSynth. C → Swift is a **recorded
  follow-on goal** (plan §9), and so is Metal.
- Steps marked **🧑 HUMAN GATE** in the plan need a person's sign-off. Stop and ask; don't sign off yourself.
- Coverage before porting: tier A (model and format) ≥ 90%, tier B (libraries and app logic) ≥ 80%, plus the
  mutation smoke test (plan §5 P2).
- Don't change preference key strings, NSCoding keys, or `write` output. The golden tests enforce this.
- A port commit never edits goldens.
- **Don't fix bugs during the port.** Log them in [docs/KNOWN-BUGS.md](docs/KNOWN-BUGS.md) and add a test that asserts
  the correct behaviour, wrapped in `withKnownIssue("BUG-nnn: …")`. Fixes happen after the port, in phase P12.
- OpenGL stays. Keep GL behind the `LDrawRenderer` / `RenderBackend` seam.
