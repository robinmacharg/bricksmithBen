# Known bugs register

**Policy (agreed 2026-11-14):** bugs found during the Swift port are **recorded, not fixed**.
- Each bug gets an entry here and an **expected-failing test**: Swift Testing `withKnownIssue { … }` (or
  `XCTExpectFailure` in XCTest suites). The test asserts the *correct* behaviour.
- The port must keep the *current* behaviour, buggy or not. Goldens record what the app does today.
- When a known-issue test unexpectedly starts passing, Swift Testing reports it. That means a port changed
  behaviour, so investigate before going further.
- All fixes happen in phase **P12 (post-port bug fixing)**: one bug per commit, with `withKnownIssue` removed and
  goldens updated in that same commit.
- **Crashing bugs** can't use `withKnownIssue`. Assert the root cause directly, then record the crash with a Swift
  Testing exit test (`#expect(processExitsWith:)`) or a child-process test. A minimal guard in app code is a
  documented **last resort**, and an entry that uses one is marked `guarded`.

**Status values:**
- `open`: recorded, test marked expected-failing
- `guarded`: minimal crash guard only
- `fixed`: in P12, with the commit hash

**Severity values:** `crash`, `data-loss`, `wrong-output`, `UI`, `perf`, `cosmetic`.

| ID | Found | Severity | Area | Summary | Evidence | Test | Status |
|---|---|---|---|---|---|---|---|
| BUG-001 | 2026-11-14 survey | crash | Parser | An unknown line type (e.g. `11`, as exported by BrickLink Studio) crashes the parser, because `+[LDrawUtilities classForDirectiveBeginningWithLine:]` returns `Nil` and the result is then used as a class | `trunk/Test Data/Bad/spider gearbox v2 causes crash.ldr`; `Source/LDraw/Support/LDrawUtilities.m:99` | `ParserRobustnessTests.unknownLineType` (P2) | open |

<!-- Add new rows below. Keep IDs sequential. Put candidate bugs (suspected but not yet confirmed by a test)
     in the "Suspected" table, and move them up once a test confirms them. -->

## Suspected (not yet confirmed by a test)

| ID | Found | Area | Suspicion | Where | Confirm in |
|---|---|---|---|---|---|
| S1 | 2026-11-14 review | Parser | A malformed `!COLOUR` line returns a half-parsed `LDrawColor` instead of failing. `directive` is assigned before `finishParsing:` throws, the `@catch` doesn't clear it, and `finishParsing:`'s BOOL result is ignored | `LDrawMetaCommand.m:112,118,138,153`; `LDrawColor.m:205-217` | P2 row 2 |
| S2 | 2026-11-14 review | Parser | Truncated type-2 lines (e.g. `2 16 1 2`) parse silently: missing fields give `nil` → `floatValue` 0, and nothing is thrown. Types 3, 4 and 5 are probably the same | `LDrawLine.m:66-100` | P2 row 2 |
| S3 | 2026-11-14 review | Singletons | Lazy singleton init isn't synchronised (no `dispatch_once`). Latent while parsing is serial | `LDrawPaths.m:25-30`, `PartLibrary.m:86-89`, `ColorLibrary.m:49-60` | Probably fixed as a side effect of P7 (`static let`); record as fixed-by-port |
| S4 | 2026-11-14 review | Colours | A failed `LDConfig.ldr` load is never cached. `sharedColorLibrary` stays nil, every call re-parses, and colour lookups return nil | `ColorLibrary.m:54` | P2 row 6 |
| S5 | 2026-11-14 review | Prefs | `findLDrawPath` overwrites `LDRAW_PATH_KEY` on launch with whatever its search found. It probably only bites when the saved folder has gone missing | `LDrawApplication.m:723-724` | P2 row 10 / manual |
| S6 | 2026-11-14 review | Parser (MRC) | `LDrawMetaCommand` init: the `[self retain]`/`[self release]` balance on the exception path can return nil after release, and callers adding nil to an array would crash. Only reachable with misrouted malformed input | `LDrawMetaCommand.m:126,134,138,152` | P2 row 2; re-check after P3 (ARC) |
| S7 | 2026-11-14 review | Pasteboard | Copy and paste use non-secure `unarchiveObjectWithData:`. Not a functional bug, but a hardening item | `LDrawDocument.m:3763,6334` | P12 (hardening) |
| S8 | 2026-11-14 survey | Build | The deployment target (10.11) is below the SDK minimum (10.13), so Xcode silently builds for 10.13 | `project.pbxproj` | Fixed in P0 (a build setting, not app behaviour) |
