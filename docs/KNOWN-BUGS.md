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
| BUG-001 | 2026-11-14 survey | crash | Parser | An unknown line type crashes the parser. `11` is the example, as exported by BrickLink Studio. The sequence: `+[LDrawUtilities classForDirectiveBeginningWithLine:]` returns `Nil`; messaging `Nil` for `rangeOfDirectiveBeginningAtIndex:` gives `{0,0}`; `lineIndex` stops advancing; and `insertIndex` writes past the end of the `directives` heap buffer | `trunk/Test Data/Bad/spider gearbox v2 causes crash.ldr`; `LDrawUtilities.m:99`; `LDrawStep.m:166-190` | Root cause asserted directly, plus an exit/child-process test (P2 row 3) | open |

| BUG-002 | 2026-11-14 P0 smoke | UI (blocks feature) | Settings window never opens. The installed Bricksmith 3.1.0 (newer upstream code) stored the background and LSynth selection colours as **keyed** archives. This source reads colours with non-keyed `NSUnarchiver` (`-[NSUserDefaults colorForKey:]`), which returns nil for them, and `-[NSColorWell setColor:nil]` throws `NSInternalInconsistencyException`. The exception is swallowed by AppKit, so `-setDialogValues` aborts before the window is ordered front. Pre-existing, not a port regression | `UserDefaultsCategory.m` `colorForKey:`; `PreferencesDialogController.m` `setStylesTabValues`/`setLSynthTabValues`; reproduced with lldb plus a standalone `NSColorWell` check | P2 row 7: reading a keyed colour blob should return the colour (`withKnownIssue`). Settings open with such prefs: UI test (`withKnownIssue`) | open |
| BUG-003 | 2026-11-15 P2 row 1 | data-loss | Parser/colours | A part that uses a colour defined by a `0 !COLOUR` line **in the same file** is saved with code 16 (current colour) instead of its own code. During parsing, colour codes are resolved through the shared `ColorLibrary`, not the file's own definitions, so the lookup falls back to `LDrawCurrentColor`. The `!COLOUR` line itself survives | `Fixtures/ldr/03-colours.ldr` → golden; `LDrawUtilities parseColorFromField:`; `ColorLibrary colorForCode:` fallback | `KnownIssueTests.bug003LocalColourPreserved` | open |
| BUG-004 | 2026-11-15 P2 row 1 | data-loss | LSynth | Constraint parts between `0 SYNTH BEGIN` and a `0 SYNTH SHOW`/`HIDE` line are parsed and then thrown away (only the `PARSER_PARSING_CONSTRAINTS` state keeps them). Files without `SHOW`/`HIDE` therefore lose all their constraints on save, and the save also adds `0 SYNTH SHOW` and a blank line | `LDrawLSynth.m:~170-195`; `Fixtures/ldr/08-lsynth.ldr` vs `08b-lsynth-show.ldr` | `KnownIssueTests.bug004LSynthConstraintsPreserved` (+ control) | open |
<!-- Add new rows below. Keep IDs sequential. Put candidate bugs (suspected but not yet confirmed by a test)
     in the "Suspected" table, and move them up once a test confirms them. -->

## Suspected (not yet confirmed by a test)

"Row" refers to the P2 test-table rows in [swift-port-plan.md](swift-port-plan.md).

| ID | Found | Area | Suspicion | Where | Confirm in |
|---|---|---|---|---|---|
| S1 | 2026-11-14 review | Parser | A malformed `!COLOUR` line returns a half-parsed `LDrawColor` instead of failing. `directive` is assigned before `finishParsing:` throws, the `@catch` doesn't clear it, and `finishParsing:`'s BOOL result is ignored | `LDrawMetaCommand.m:~112,119,153`; `LDrawColor.m:205-217` | Row 3 |
| S2 | 2026-11-14 review | Parser | Truncated type-2 lines (e.g. `2 16 1 2`) parse silently. For a missing field, `readNextField:` returns an empty string, whose `floatValue` is 0, and nothing is thrown. Types 3, 4 and 5 are probably the same | `LDrawLine.m:66-100`; `LDrawUtilities.m:288-291` | Row 3 |
| S3 | 2026-11-14 review | Singletons | Lazy singleton init isn't synchronised (no `dispatch_once`). Latent while parsing is serial | `LDrawPaths.m:25-30`, `PartLibrary.m:86-89`, `ColorLibrary.m:49-60` | Expected to be fixed as a side effect of P7 (`static let`); record as fixed-by-port |
| S4 | 2026-11-14 review | Colours | A failed `LDConfig.ldr` load is never cached. `sharedColorLibrary` stays nil, every call re-parses, and colour lookups return nil | `ColorLibrary.m:54` | Row 7 |
| S5 | 2026-11-14 review | Prefs | `findLDrawPath` overwrites the `"LDraw Path"` default on launch with whatever its search found. It probably only bites when the saved folder has gone missing | `LDrawApplication.m:724-725` | Row 14 / manual |
| S6 | 2026-11-14 review | Parser | `LDrawMetaCommand` init returns **nil** when an exception is thrown before `directive` is assigned (e.g. the nonzero-line-type `@throw`). The retain/release is balanced. The nil then goes into the `directives[]` buffer and `addDirective:` | `LDrawMetaCommand.m:125,135,143,153`; `LDrawStep.m:180,211` | Row 3 |
| S7 | 2026-11-14 review | Pasteboard | Copy and paste use non-secure `unarchiveObjectWithData:`. Not a functional bug, but a hardening item | `LDrawDocument.m:3763,6334` | P12 (hardening) |
| S8 | 2026-11-14 survey | Build | The deployment target (10.11) is below the SDK minimum (10.13). Xcode warns about it for all three projects (`docs/warnings-baseline.txt`) | `project.pbxproj`; `Info.plist` `LSMinimumSystemVersion` | Fixed in P0 (a build setting, not app behaviour) |
| S9 | 2026-11-14 review 2 | Document | `readFromData:ofType:error:` writes `*outError` without checking for NULL. It would crash if a caller passes NULL | `LDrawDocument.m:476` | Row 10; P4 must keep this behaviour |
| S10 | 2026-11-14 P0 Release build | Library | `-[PartLibrary optimizedDrawableForPart:color:]` is marked "Not used". Its whole body is `assert()`, so in Release (`NDEBUG`) it falls off the end of a non-void method (undefined behaviour if it's ever called). Probably dead code | `PartLibrary.m:1012-1016` (`-Wreturn-type`, Release only) | P2 row 8: confirm there are no callers; delete in P7 |
| S11 | 2026-11-14 P0 Release build | LSynth CLI | In two-file mode, the error messages for a failed `fopen` print the uninitialised `dat_name`/`dst_name` (crash or garbage), and a stray debug `printf("%i %s")` writes to stdout. Bricksmith uses stdin/stdout mode (`-`), so the app isn't affected; only the CLI is | `lsynthcp.c:1176,1182,1187` (`-Wuninitialized`, Release only) | P2 row 13 (black-box CLI test) |
| S12 | 2026-11-14 P1 annotation | Paths | `-pathForPartName:` caches its search paths in a function-static on first call and never refreshes them. If the LDraw folder isn't set yet, `initWithObjects:` stops at the first nil and the cache stays empty, so no user parts are found until relaunch. Changing the folder in Preferences doesn't affect part lookup either | `LDrawPaths.m` `pathForPartName:` (cache now file-scope `PartSearchPaths`, cleared only by `+resetForTesting`) | P2 row 8 |
| S13 | 2026-11-14 P1 annotation | Paths | The search loop in `-pathForPartName:` doesn't `break`, so the **last** matching directory wins. The order is user official → user unofficial → internal official → internal unofficial, so the bundled copy overrides the user's library for duplicated names. The intent was probably first match | `LDrawPaths.m` `pathForPartName:` loop | P2 row 8 |
| S14 | 2026-11-15 P2 row 1 | Texture | Plain geometry inside `0 !TEXMAP START … END` is saved as `0 !: <geometry>`. If the LDraw spec treats `0 !:` lines as texture-aware-only, programs without TEXMAP support would stop seeing that geometry | `Fixtures/ldr/07-texmap.ldr` → golden | Check against the LDraw TEXMAP spec |
| S15 | 2026-11-15 P2 row 1 | Comments | `0 WRITE …` and `0 PRINT …` are saved as `0 // …`. Probably intentional (both are deprecated comment forms), but it rewrites the user's text | `Fixtures/ldr/06-comments-meta.ldr` → golden | Maintainer to decide whether this is a bug |
