# Bricksmith: Objective-C → Swift port plan

| | |
|---|---|
| Status | **v3.1**: two rounds of adversarial review incorporated (see [Appendix A](#appendix-a-adversarial-review-log)) |
| Date | 2026-11-14 |
| Toolchain | Xcode 26.3 (17C529), built-in Swift 6.2.4. No external toolchains |
| Out of scope | OpenGL → Metal (a later project; this plan prepares the seam) |
| Related | [ARCHITECTURE.md](ARCHITECTURE.md) · [TESTING.md](TESTING.md) · [port-status.md](port-status.md) · [KNOWN-BUGS.md](KNOWN-BUGS.md) |

**How to read this.** §1–4 give the goals, the facts that constrain the plan, the workflow, and the technical
rules. §5 has one section per phase, each with its tasks and exit criteria. §6 is the recipe for porting one class.
Steps marked **🧑 HUMAN GATE** need a person to sign off: an agent stops there and asks.

## 1. Goals and non-goals

**Goals**
1. Every Objective-C class in the app is ported to Swift, with today's behaviour preserved.
2. A characterisation test suite comes **before** any risky change, including finishing ARC, so regressions show
   up the moment they happen.
3. The UI is modernised where it's cheap and safe. This is done *separately* from porting it.
4. The renderer sits behind a Swift protocol, ready for a Metal backend later.

**Non-goals**
- Metal rendering. This is a follow-on goal (§9).
- Porting the C code to Swift. This is a follow-on goal (§4.1, §9).
- New features.
- **Bug fixes during the port.** Bugs are recorded in [KNOWN-BUGS.md](KNOWN-BUGS.md) with expected-failing
  tests and fixed in P12.

## 2. Starting point

- The work branch is `20251111-ARC-conversion`, with an MRC → ARC migration about 55% done (52 files ARC,
  41 files `-fno-objc-arc`).
- **State preserved:** commit `af3483f`, tagged `snapshot-20261114-pre-swift-plan`, builds in Debug with Xcode 26.3.
  `Source/LDraw.zip` (a local backup) is deliberately left untracked.
- There are no tests and no test target.
- The code is about 70k lines; [port-status.md](port-status.md) has the per-file breakdown.

### Facts that shape the plan (each verified against the code)

| Fact | Evidence | Consequence |
|---|---|---|
| Headers depend on the prefix header's macros (`OPEN_GL_HEADER`; `dispatch_queue_t`/`dispatch_group_t` → `void *` when `USE_BLOCKS 0`, guarding 49 `#if USE_BLOCKS` sites) | `Mac LDraw_Prefix.pch:31-40`, `LDrawPart.h:12`, `LDrawDirective.h:195` | Swift can't import the headers as they are. P1 makes them self-contained. |
| Headers are unannotated: no nullability or generics, 33 plain `typedef enum`s, string constants as `#define` | `MacLDraw.h` (123 `#define`s) | Adding annotations changes Swift spellings, so it happens in P1, **before** tests are written. |
| Parse errors use `@throw` and are caught in *another* class (44 `@throw`/`@try` sites) | `LDrawColor.m:205-217` → `LDrawMetaCommand.m` `@catch` | An NSException must not unwind through Swift. P4 converts these to error returns. |
| `-[LDrawMetaCommand initWithLines:…]` returns a substitute object | `LDrawMetaCommand.m:107-153` | A Swift init can't do this. P4 adds a factory. |
| Subclasses read superclass ivars directly. `LDrawDocument` has about 28 ivars and no properties | `LDrawLine.m:213,240,248`; `LDrawContainer.h:25`; `LDrawDocument.h` | Swift can't see ObjC ivars. P4 converts them to properties. |
| App launch writes the real defaults, loads the user's part library, creates the **shared GL context and inspector** that documents need, and starts Sparkle from the nib. Quitting writes defaults too | `LDrawApplication.m:53-84,421-475,483-502,512-529,712-735`; `LDrawDocument.m:453` (`CGLLockContext` on the shared context); `MainMenu.xib:716` | P1 adds a test-mode launch that keeps the GL context and inspector and suppresses every external side effect. |
| Singletons are lazy, can't be reset, and aren't thread-safe. Global statics change `write` output (`ColumnizesOutput`, `defaultAuthor` ← `NSFullUserName()`) | `ColorLibrary.m:44-103`, `PartLibrary.m:84-90`, `LDrawPaths.m:23-33`, `LDrawUtilities.m:26`, `LDrawApplication.m:430-431` | Tests need reset hooks, pinned statics, and serialised suites. |
| The LDraw folder preference key is `"LDraw Path"` (with a space) | `MacLDraw.h:35` | Tests inject the path through an override hook rather than launch arguments. |
| `PartCatalogBuilder` writes `parts.plist` into the LDraw folder | `PartCatalogBuilder.m:209` | Each run gets its own temp copy of the fixture library. |
| `write` emits **CRLF**. Inputs may be UTF-8 with a BOM, Latin-1 or MacRoman, and output is always UTF-8 | `LDrawModel.m:571`; `LDrawUtilities.m:376-387`; `LDrawDocument.m:534` | Fixtures and goldens are protected with `.gitattributes`, and tests compare **bytes**. |
| Document edit actions read the outline view's selection | `LDrawDocument.m:6050-6065`, `:858-875` | Document tests load the nib (the window isn't shown). |
| `+initialize` registers value transformers | `LDrawApplication.m:41` (before P4) | Swift can't define `+initialize`, so P4 moves it (done: `+registerValueTransformers`, called from `main.m`). |
| Colours in preferences are archived with non-keyed `NSArchiver` | `UserDefaultsCategory.m:22,41` | Tests cover both the reader **and** the writer format. |
| Info.plist hard-codes `LSMinimumSystemVersion` to `10.11.0`. Sparkle points at the live SourceForge appcast in every configuration | `Info.plist` | Debug and dev builds could update themselves to the release build. P0 fixes this. |
| `LDrawDataStream.m` isn't compiled; only its header is in the project | `project.pbxproj` | Excluded from porting. Delete it or leave it, at the maintainer's choice. |

## 3. Branching and workflow

**Branches are stacked and dated.** Names follow the existing `YYYYMMDD-topic` convention, where the date is the
day the branch was cut. Each phase branch is based on the tip of the one before:

```
master
 └─ 20251111-ARC-conversion          (existing; tip = snapshot tag)
     └─ 20261114-swift-port-plan     (this plan, docs/, CLAUDE.md)
         └─ YYYYMMDD-p0-build-hygiene
             └─ YYYYMMDD-p1-test-harness
                 └─ YYYYMMDD-p2-characterisation-tests
                     └─ YYYYMMDD-p3-arc-complete
                         └─ … one branch per phase or sub-phase (p6a, p6b, p9a, p9b …)
```

**Rules**
- Restack from the top with `git rebase --update-refs -x scripts/test.sh <base>`. The `-x` re-checks every commit.
- **Every commit builds and every test passes.** An expected failure from a known issue counts as passing. This keeps
  `git bisect` usable.
- During porting phases, one class (or one category or extension) per commit.
- Nothing is pushed to `origin` unless the maintainer asks.

**Merging and releasability**
- A branch merges to `master` bottom-up, and only after passing its exit gate.
- **`master` is releasable after every merge.** That's why big phases are split into sub-branches that can each pass
  a gate on their own.
- Releases and appcast changes stay manual, and are the maintainer's call.

**Stalls and rollback**
- If porting a class takes more than two serious attempts, mark it `stays-objc (accepted)` in port-status.md with the
  reason, and **🧑 HUMAN GATE**: decide whether to continue.
- Because the order is leaves-first, its ancestors stay ObjC too until it's resolved.
- A regression found late is fixed by **reverting** that class's port commit, which is possible because each class has
  its own commit. Then add the missing test and port again.

**Exit gate for every phase:**
1. `scripts/build.sh` succeeds, and the **de-duplicated warning text** diff against `docs/warnings-baseline.txt` shows
   no new warnings. Moved or renamed GL deprecation warnings are reviewed and the baseline updated in the same commit.
2. `scripts/test.sh` is green, and no known-issue test passes unexpectedly.
3. The perf check (`scripts/perf-compare.sh`) passes in phases that touch the hot classes (§4.6). **A skipped perf test
   fails the gate.**
4. The version's patch number is bumped (§8.6) in the merge commit to `master`.
5. **🧑 HUMAN GATE:** someone runs the manual smoke checklist ([TESTING.md](TESTING.md#manual-smoke-checklist)) with
   the full LDraw library, then records the sign-off (date and initials) in port-status.md.
6. [port-status.md](port-status.md) and [KNOWN-BUGS.md](KNOWN-BUGS.md) are up to date.

## 4. Key technical decisions

### 4.1 C stays C (C → Swift is a recorded follow-on goal)
These stay C for this plan:
- `MatrixMath.c`, `GLMatrixMath.c`, `OpenGLUtilities.c`, `MeshSmooth.c`
- LSynth (a separate CLI)

They are hot-path code that imports cleanly into Swift.

**Porting the C to Swift is a follow-on goal (§9), not part of this plan.** The P2 tests (MatrixMath at tier A, the
LSynth goldens, render snapshots) are written so they'll also guard that later work.

### 4.2 Swift mode
- **Swift 5 language mode**, with `SWIFT_STRICT_CONCURRENCY = minimal`, until P11.
- There is **one** bridging header, the app's. Tests reach everything through `@testable import Bricksmith`.
  Every header imported by the bridging header must be self-contained.

### 4.3 Deployment target, signing and updates
- **App: macOS 13.0** (*maintainer decision*: 11.0 is fine if reach matters more).
  - The current 10.11 is below the SDK floor of 10.13.
  - `LSMinimumSystemVersion` changes to `$(MACOSX_DEPLOYMENT_TARGET)`.
- **Test bundles: macOS 14.0.** This is a choice, not a hard requirement: the shipped `Testing` binary has `minos 14.0`.
- **Signing:** "Sign to Run Locally", with hardened runtime off for Debug and test hosting.
- **Sparkle:** off in Debug. The app delegate implements `updater:mayPerformUpdateCheck:error:` and returns NO under
  `#if DEBUG`, and in test mode. This writes no defaults, and Release behaviour is unchanged.
  - In tests, the delegate also returns NO from `updater:mayPerformUpdateCheck:error:`. That's the exact Sparkle 2.0.0
    selector; a wrong name fails silently, because the method is optional.

### 4.4 Interop rules
1. **Keep the ObjC runtime names.** `@objc(OriginalName)` on every ported class, and `@objc(sel:)` to keep the
   selectors. Xibs, `NSDocumentClass`, NSCoding archives and the pasteboard depend on them.
2. **ObjC can't subclass a Swift class.** Port leaves first and roots last in every hierarchy, UI included.
   - Swift extensions on ObjC classes are fine.
   - ObjC categories on `@objc` Swift classes are fine.
   - Swift **can't** see ObjC ivars.
3. **No NSException may cross into Swift.** Any `@try` that remains must sit entirely inside ObjC.
4. **No init may return a substitute object.** Use factories.
5. **`required` inits** for `[[self class] alloc] init]` in `copyWithZone:` (`LDrawDirective.m:172`) and for
   `init?(coder:)` along the decode chain.
6. **`@objc dynamic`** on anything accessed through KVC, KVO or bindings (221 xib bindings).
7. **No macros or plain enums.** Typed constants, `NS_ENUM`, `NS_TYPED_EXTENSIBLE_ENUM` (P1).
   - **The string values of preference keys and notification names don't change.** A test enforces this.
8. **ObjC `.h` files never import `Bricksmith-Swift.h`.** Use `@class` / `@protocol` forward declarations.
9. **Hide C fixed arrays** (`GLfloat glTransformation[16]`) behind `Matrix4` accessors.
10. **Keep C struct types** (`Point3` is byte-encoded by `LDrawQuadrilateral.m:189-193`). Don't redefine them in Swift.
11. **Signatures must match.** A Swift port's API must match the **generated Swift interface** of the ObjC header it
    replaces: optionality, element types, mutability. Check with Xcode's *Generated Interface* view, or
    `swift-synthesize-interface` if it's available. This keeps the tests compiling unchanged.

### 4.5 Testing frameworks
- **Swift Testing** for unit and characterisation tests.
- **XCTest** for `measure {}` perf tests and XCUITest.
- Tests are written **in Swift against the annotated ObjC API** (annotations land in P1) and run unchanged across the
  port.

### 4.6 Hot classes (perf-gated)
- `LDrawDirective`, `LDrawContainer`, `LDrawStep`, `LDrawModel`, `LDrawFile`, `LDrawPart`
- `LDrawLine`, `LDrawTriangle`, `LDrawQuadrilateral`, `LDrawConditionalLine`, `LDrawDrawableElement`
- `LDrawUtilities`, `PartLibrary`, `ColorLibrary`
- every renderer class (P8)

## 5. Phases

Sizes are relative (S < M < L < XL).

### P0: build hygiene (S)
- Set the version to **4.0.0** (§8.6).
- **Drop 3Dconnexion** (§8.2): its code, the framework, the link flags, and the pch's Carbon import if nothing else
  needs it.
- **Delete `LDrawDataStream.{h,m}`** (§8.7).
- Deployment target 13.0, `LSMinimumSystemVersion = $(MACOSX_DEPLOYMENT_TARGET)`, signing, and Sparkle off in Debug (§4.3).
- Add `.gitattributes` **before any fixture or golden exists**:
  - `*.ldr *.mpd *.dat -text`
  - `trunk/Fixtures/golden/** binary`
- Move the `LSynth` scheme from the committed `xcuserdata` to `xcshareddata`.
- Add `scripts/build.sh`: an xcodebuild wrapper with a scratch derived-data folder that writes the de-duplicated warning
  text. Record `docs/warnings-baseline.txt`.
- **Exit:** the §3 gate (no tests exist yet); the app opens `trunk/Test Data/Good/spider gearbox v2 opens.ldr`.

### P1: header hygiene, Swift-facing API and test harness (L)
**Header hygiene**
- Make every header self-contained (import Cocoa and GL explicitly).
- Move the `USE_BLOCKS` / `dispatch_*_t` hack, the build flags and the C imports from the pch into a self-contained
  `BricksmithBuildConfig.h`, imported where needed. *(Done: the file was named `BricksmithBuildConfig.h` rather
  than `LDrawDispatchCompat.h`.)* Don't delete the hack yet; P4 does that.

**Swift-facing API shaping.** This is compile-time only, with no behaviour change. It comes first so tests are written
against the final Swift spellings.
- The `typedef enum`s in bridged headers become `NS_ENUM(int, …)` / `NS_OPTIONS(int, …)`. The base type is `int` to
  keep size and `@encode` (L23). Open sets (`LDrawColorT`, `menuTagsT`) stay plain C enums. *(Done: 25 enums.)*
- The `MacLDraw.h`, `LDrawKeywords.h` and `LDrawPathNames.h` `#define`s become `FOUNDATION_EXPORT NSString * const`
  (notifications: `NSNotificationName`) with **identical string values**, verified mechanically (L24).
  *(Done: 175 constants.)*
- Informal protocols (`NSObject (LDrawGLViewDelegate)`) become formal `@protocol`s.

**Nullability and generics: added per header, alongside its first test** *(amended in v3.1)*
- A header gets `NS_ASSUME_NONNULL_BEGIN/END`, `nullable`, explicit `null_unspecified` for anything not verified,
  and lightweight generics **before, or in the same commit as, the first test that uses it.**
  - Annotations are claims, and the tests are the evidence. A wrong `nonnull` or generic traps at runtime in Swift
    instead of failing to compile.
  - Annotating every header with no tests to check against would create unverified claims. Leaving headers
    unannotated until P4 would break "tests unchanged", because Swift spellings would change under existing tests.
- Annotate a whole header at a time: clang's `-Wnullability-completeness` warns about every unannotated pointer once
  any pointer in the header is annotated (confirmed).
- Generics only where a test iterates the collection over real fixtures and asserts the element class.
- Unverified (`null_unspecified`) entries are logged in port-status.md.
- Once a header has tests, changing its annotations is a `[test-spelling]` commit (the P4 rule).

**Test bundle**
- `BricksmithTests`: Swift, hosted by the app, macOS 14, coverage on, `@testable import Bricksmith`.
- The app's bridging header and one placeholder Swift file are created here.

**Test-mode launch**, enabled when `XCTestConfigurationFilePath` is in the environment.

*Keep:* the shared GL context and the `Inspector` (documents need them).

*Skip:*
- `findLDrawPath` and the defaults write
- the catalog load
- the part browser and LSynth menu work in `applicationDidFinishLaunching:`
- every defaults write in `applicationWillTerminate:`

*Sparkle:* disabled (§4.3).

**Injection and isolation**
- `+[LDrawPaths setOverrideLDrawPath:]` (test-only) takes priority over defaults.
- `+resetForTesting` on `ColorLibrary`, `PartLibrary`, `LDrawPaths`, `ModelManager`, `MLCadIni` and the
  **`LDrawUtilities` statics** (`ColumnizesOutput`, `defaultAuthor`).
- A base test trait copies `Fixtures/ldraw-mini` to a temp directory, sets the override, resets the singletons,
  **pins `defaultAuthor` and the column setting**, and restores everything afterwards.
- Suites that touch singletons are `.serialized`.

**Defaults guard.** `scripts/test.sh` exports `com.AllenSmith.Bricksmith` defaults before and after the run and
**fails on any difference**. The isolation is checked by tooling, not just stated.

**Fixtures**
- `trunk/Fixtures/ldraw-mini/`: `LDConfig.ldr`, about 20 small parts and primitives, `parts.lst`, plus an
  `ATTRIBUTION.md`. This is allowed by maintainer decision §8.5 (the repo won't be released), and replacing the
  subset is a follow-on (§9).
- `scripts/fetch-ldraw.sh` downloads the full library into `~/Library/Caches`. It's gitignored, and tests that use it
  are tagged `.requiresFullLibrary`.

**Crash-safe expected failures.** Swift Testing exit tests (`#expect(processExitsWith:)`) **work from the hosted
bundle** (spike passed 2026-11-14, L25; kept as `HarnessExitTests`). The child process relaunches the app in test
mode, and app code is reachable from it.

**Scripts**
- `scripts/test.sh` (also writes per-class coverage and checks the tier targets in §5 P2)
- `scripts/perf-compare.sh`
- `scripts/mutation-smoke.sh` (the skeleton here; P2 adds the mutations)
- a `Bricksmith-Perf` scheme (Release, testability on)

**UI tests.** A `BricksmithUITests` target with one launch-and-open test.

**Exit:**
- A trivial parse test passes.
- The defaults guard is clean across 3 consecutive runs.
- **Swap spike** on a throwaway branch: a test against `TransformerIntMinus1` passes unchanged after that class is
  ported to Swift.
- §3 gate.

### P2: characterisation tests (L)
Tests run against **today's mixed MRC/ARC build** and record its behaviour, bugs included.
- Goldens come from the ObjC build with `RECORD_GOLDENS=1`. **🧑 HUMAN GATE:** a person reviews them before they're committed.
- Adding **accessibility identifiers** to xibs for XCUITest is allowed and doesn't count as a behaviour change.

**Bug policy** (from here to the end of the port). For every bug found:
1. Log it in [KNOWN-BUGS.md](KNOWN-BUGS.md).
2. Write a test that asserts the **correct** behaviour, wrapped in `withKnownIssue("BUG-nnn …")` (or `XCTExpectFailure`).
3. Don't fix it.

How to handle the awkward cases:
- **A known issue that starts passing** means behaviour changed. Investigate.
- **Crashing bugs:** assert the root cause directly, then record the crash with an exit test or a child-process test.
  An app-code guard is the last resort, and its entry is marked `guarded`.

| # | Area | What's tested | How |
|---|---|---|---|
| 1 | **Parse → write round trip** | Every directive type: part, line, triangle, quad, conditional line, comment, `!COLOUR`, `STEP`, `ROTSTEP`, MPD `0 FILE`/`NOFILE`, `!TEXMAP`, LSynth blocks, `0x2RRGGBB`, header metadata | Parameterised over `Fixtures/ldr/`. **Bytes of `dataOfType:`** (CRLF, UTF-8) == golden, plus idempotence, columnized on and off. |
| 2 | **Format edge cases** | Coordinates ≥ 1e8 (the 16-byte `snprintf` buffer, `LDrawUtilities.m:472`), `-0`, Float-vs-Double values such as `0.1`, RGB truncation (`:421`), BOM / Latin-1 / MacRoman input, and the `"UntitledModel"` and author defaults | Dedicated fixtures. |
| 3 | **Parser robustness** | Blank lines, CRLF, tabs, unknown meta, unknown line code (BUG-001), truncated lines (S2), malformed `!COLOUR` (S1, S6) | Current output is recorded; the bugs are known issues. |
| 4 | **Object model** | Tree shape, `NSCopying`, keyed NSCoding round trip (the pasteboard format), observer notifications | Decode archives produced by the ObjC build and committed as fixtures. |
| 5 | **MatrixMath / geometry** | Compose ∘ decompose ≈ identity, invert, multiply, intersections, bounds, polygon tests, `ComputationalGeometry` | Table tests and seeded property tests. |
| 6 | **Snapping and transforms** | Grid and angle snapping, move, rotate, view-orientation mapping | Table tests. |
| 7 | **Colours** | `ColorLibrary`, blended and custom colours, `!COLOUR`, edge colours; `NSArchiver` colour prefs **read and write** (the bytes the writer produces) | Fixture `LDConfig.ldr`, plus a real archived blob. |
| 8 | **Paths, library, catalog** | `LDrawPaths`, case-insensitive names, `PartCatalogBuilder` on the mini library, descriptions and categories, `MLCadIni` | Temp copy of the fixture. |
| 9 | **MPD and ModelManager** | Submodel lookup, renaming updates references, active model, cross-document references | Fixtures. |
| 10 | **Document actions and undo** | **Every IBAction in `LDrawDocument.h`** that changes the model: e.g. duplicate, delete, nudge, quick rotate ±X/Y/Z, change colour, hide/show/show all, split step, split model, add model from selection, make origin, insert reference, insert raw command, insert related, rename submodel, copy and paste, revert. Each one is followed by undo and redo | Nib-loaded window controller (window not shown); select outline rows; compare `dataOfType:` bytes with goldens. Every action that isn't automated goes on TESTING.md's **manual-only list** with a reason. |
| 11 | **Exports** | Export Steps (`LDrawDocument.m:1583`, N files), piece-count / `PartReport` text export (`PieceCountPanel.m:299`), minifig generator output | Golden files. |
| 12 | **App-logic classes** | `MinifigureDialogController`, `PartBrowserDataSource` (search and filter), `RelatedParts`, `LSynthConfiguration`, `SearchPanelController` | Unit tests on their non-view logic. |
| 13 | **LSynth** | `LDrawLSynth` parse, write and synthesise round trips (the ObjC class, which runs `lsynthcp` through `NSTask`), plus a black-box `lsynthcp` test | Golden files. |
| 14 | **Preferences contract** | Every defaults key and notification-name string, and each registered default | Snapshot test. |
| 15 | **Render snapshots** | Fixed-camera offscreen renders of 5–10 fixtures, wireframe and shaded | Offscreen CGL → FBO with a tolerance. References are **per machine**, not a CI gate, and serve as a loose reference for the Metal work. |
| 16 | **Performance** | Parse, collect and draw, build catalog | Self-timed Swift tests (median of a fixed number of iterations) in a **Release** configuration with testability enabled, on a **synthetic large model generated from ldraw-mini** (generator script committed, so no full library is needed). Results go to `build/perf-results.json`. `scripts/perf-compare.sh` checks them against `docs/perf-baseline.json` (machine recorded) and enforces **≤ +20%**; a missing metric fails. *(Design changed in P1 from XCTest `measure`, to avoid device-keyed `.xcbaselines`. As built in P2: a **Perf** build configuration (Release clone with testability enabled) is used instead of a separate scheme; the statistic is best-of-15 after warm-up on a 20,000-part model, because medians of millisecond timings were too noisy (L65).)* |
| 17 | **UI smoke** | Launch, open, select in the outline, inspector shows values, edit, undo, save-as and reopen, open each panel | XCUITest, kept thin. |

**Not testable automatically:**
- *Randomize Colors* uses unseeded `rand()` (`LDrawDocument.m:2086`), so it goes on the manual-only list. P4 adds an
  injectable RNG that defaults to `rand()`.
- The app has **no printing** feature, so there is nothing to test.

**Coverage targets**

Line coverage per class, from `xccov`, in tiers. The bar is set high on purpose: this suite is the only thing that
detects regressions during the port, and the pure-logic code is cheap to cover with goldens.

| Tier | Classes | Line coverage |
|---|---|---|
| **A: model and format** | `LDraw/Commands`, `LDraw/Files`, `LDrawDirective`, `LDrawUtilities`, `ColorLibrary`, `MatrixMath.c` (stays C, but every Swift caller depends on it), `ComputationalGeometry` | **≥ 90%** |
| **B: libraries and app logic** | `LDrawPaths`, `PartLibrary` (non-GL), `ModelManager`, `PartCatalogBuilder`, `PartReport`, `MLCadIni`, `StringUtilities`, the categories, and the row 12 app-logic classes | **≥ 80%** |
| **C: document** | `LDrawDocument` | **Every** model-changing IBAction is covered by row 10, or listed as manual-only with a reason |
| **Excluded** | `LDrawGLRenderer`, `LDrawGLCamera`, `LDrawDragHandle`, the renderer classes, and the C GL helpers | Covered by snapshots (row 15) and UI tests (row 17) |

Coverage alone isn't enough, so two more checks apply:
- **Uncovered-line ledger.** In tiers A and B, every block that stays uncovered (GL error paths, dead code,
  "can't happen" branches) is listed in port-status.md with a reason. Uncovered code that isn't listed fails the gate.
- **Mutation smoke test.** `scripts/mutation-smoke.sh` applies about 30 hand-written mutations, one at a time, to the
  §4.6 hot classes. Examples: flip a comparison in `write`, drop a field in parsing, change an `outputStringForFloat:`
  format, skip an undo registration. **Every mutation must make at least one test fail.** A surviving mutation means
  a test is missing. The script is re-run at the end of P4, when the code has changed shape.

**🧑 HUMAN GATE:** a class below its tier target is either brought up to target or explicitly accepted as a risk, with
the sign-off recorded in port-status.md.

**Exit:** every row is done, and the default suite takes under 3 minutes. Then **🧑 HUMAN GATE:** check that the
manual-only list in TESTING.md is complete.

### P3: finish ARC (M)
This comes after the tests, because the remaining MRC files are the riskiest ones (`LDrawDirective`,
`LDrawMetaCommand`, `LDrawDocument`, `PartLibrary`, `LDrawGLView`).
- Convert the 41 files with the existing tooling (`arc-migrate.sh`, `update_arc_flags.rb`).
- Then set `CLANG_ENABLE_OBJC_ARC = YES` and remove the per-file flags. `RegexKitLite` stays MRC until P4.
- Run the suite after each batch. Run ASan and Leaks on the smoke flows once at the end.
- **Exit:** §3 gate; no golden changed.

### P4: ObjC prep refactors, no behaviour change (L)
Goldens and known issues **must not change**.
- **Parse errors:** `@throw`/`@catch` becomes `BOOL` + `NSError **`, keeping every current outcome. That includes the
  half-parsed `!COLOUR` (S1), the nil directive (S6), and `readFromData:`'s unchecked `*outError` (S9).
- **Factory:** `+[LDrawDirective directiveWithLines:inRange:parentGroup:]` replaces the substitute-self init.
- **Ivars → properties:**
  - Every ivar read by another class or by a category, including **all `LDrawDocument` ivars and outlets** (needed
    for P10).
  - Check draw-loop cost against the perf gate.
- **Dead code:** remove the `USE_BLOCKS` hack and the 49 dead `#if USE_BLOCKS` branches (parsing stays serial).
- **Launch code:** move `+initialize`'s transformer registration there.
- **Modernise calls:**
  - Replace RegexKitLite with `NSRegularExpression`, then delete it.
  - Replace old enum names.
  - Replace 17 `loadNibNamed:owner:` calls.
- **Randomize Colors:** add the injectable RNG.
- **GL out of the model:** route the remaining GL calls through the **existing** `LDrawRenderer` / `LDrawCollector`
  protocols:
  - `LDrawPart` (8)
  - `LDrawDirective` (2)
  - `LDrawDragHandle` (24)
  - `PartLibrary` texture creation
- **Extract Export Steps' logic** out of its save-panel completion block (`-[LDrawDocument exportSteps:]`) into a
  callable method, and point `ExportTests` at it in place of `ExportStepsMirror` (row 11 mirrors it line for line
  until then).
- **Split `LDrawDocument.m`** (6.4k lines) into categories by concern: file I/O, edit operations, selection, undo,
  menus, viewers.
- **Fallback if annotations were missed in P1:** a "test spelling only" commit is allowed. Goldens and assertions stay
  untouched, and the commit is marked `[test-spelling]` for review.

### P5: leaf utilities and categories → Swift (S)
- `StringUtilities`, `BricksmithUtilities`, `MLCadIni`, `TransformerIntMinus1`, and the categories (as extensions).
- `UserDefaultsCategory` keeps reading **and writing** the `NSArchiver` format (row 7).

### P6: LDraw model → Swift (XL), all perf-gated
Port leaves before roots. Names, selectors, NSCoding keys and output bytes stay identical. Each sub-branch must pass
the gate on its own.
- **p6a leaves:** `LDrawConditionalLine`, `LDrawTriangle`, `LDrawQuadrilateral`, `LDrawComment`, `LDrawColor`,
  `LDrawLSynthDirective`, `LDrawDragHandle`, `LDrawMPDModel`, `LDrawFile`
- **p6b middle:** `LDrawLine`, `LDrawPart`, `LDrawMetaCommand`, `LDrawTexture`, `LDrawLSynth`, `LDrawStep`, `LDrawModel`
- **p6c roots:** `LDrawContainer`, `LDrawDrawableElement`, `LDrawDirective`

**Tightly coupled pairs.** Mutual references between classes (e.g. `LDrawDirective` ↔ `LDrawContainer` via
`enclosingDirective`) are fine across the language boundary, because they're messages rather than subclassing. Port
them in two commits, keeping each one green. If two classes can't be separated, they may share a single commit,
noted in port-status.md.

### P7: libraries and managers → Swift (L)
- `ColorLibrary`, `LDrawPaths`, `LDrawUtilities`, `ModelManager`, `PartLibrary`, `PartCatalogBuilder`, `PartReport`,
  `ComputationalGeometry`.
- Proper dependency injection replaces the P1 test hooks. Swift `static let` initialisation ends the lazy-init race:
  record S3 as fixed-by-port.

### P8: renderer (still OpenGL) → Swift (L)
- `LDrawGLRenderer`, `LDrawGLCamera`, `LDrawShaderRenderer`, `LDrawDisplayList`, `LDrawShaderLoader`, `LDrawBDPAllocator`.
- Evolve `LDrawRenderer` / `LDrawCollector` into Swift `RenderBackend` / `Camera` protocols with **no GL types**
  (`Matrix4`/`simd`, closures in place of C function pointers). GL becomes the first implementation.
- **Warnings:** Swift files that call GL produce their own deprecation warnings, and `GL_SILENCE_DEPRECATION` has to
  reach Clang through `-Xcc -DGL_SILENCE_DEPRECATION` in `OTHER_SWIFT_FLAGS`. Rebaseline the warnings deliberately.
- Render snapshots (row 15) stay within tolerance.

### P9a: UI → Swift, xibs untouched (XL)
Port leaves first:
- the 10 `Inspection*` classes → `ObjectInspectionController`, then `Inspector` (a separate root that uses them, not
  their superclass)
- `MovePanel`, `DimensionsPanel`, `PieceCountPanel` → `DialogPanel`
- `PartBrowserTableView` → `ExtendedTableView`; `ViewportArranger` → `ExtendedSplitView`
- `LDrawGLView` last among the widgets (3.2k lines)

UI tests must pass **unchanged**.

### P9b: UI modernisation (L), one control per commit
- `NSMatrix` (19 in 8 xibs) → radio `NSButton` groups or `NSSegmentedControl`
- **Keep** the `NSDrawer` part-browser mode (§8.3). It is deprecated but still functional, and is not modernised in this plan.
- `LDrawColorCell` and `IconTextCell` → view-based cells
- `AMSProgressBar` → an `NSProgressIndicator` sheet; delete the framework
- Declare UTIs for ldr, mpd and dat (`public.plain-text`)

For each control: first run the UI tests **unchanged**, then update them in a **separate** commit that only adjusts
locators. Keep the xibs and bindings; there is no SwiftUI rewrite.

### P10: document and application → Swift (L)
- Port `LDrawDocument` one P4 category at a time, as Swift extensions, with the core `@implementation` last. Its ivars
  are already properties (P4).
- Port `LDrawApplication` and `BricksmithApplication`, and replace `main.m` with `@main`.
- Undo **keeps** `prepare(withInvocationTarget:)` semantics. The closure rewrite is P11.
- The pasteboard keeps its current (non-secure) unarchiving. S7 is for P12.

### P11: hardening (M)
- No `.m` files remain; the bridging header contains C headers only.
- Swift 6 mode and complete concurrency checking; `@MainActor` UI.
- Undo moves to `registerUndo(withTarget:)` closures (undo tests unchanged).
- Revisit parallel parsing, under TSan.
- Trim unnecessary `@objc`, but keep `@objc(Name)` on anything a xib or archive references.
- Rebaseline warnings and update ARCHITECTURE.md.

### P12: post-port bug fixing
- Work through [KNOWN-BUGS.md](KNOWN-BUGS.md), crash and data-loss bugs first.
- Each fix is one Swift-only commit containing the fix, the removed `withKnownIssue`, any explained golden changes, and
  the register row update.

## 6. Per-class porting recipe (for humans and agents)

1. **Check port-status.md.** Are all subclasses already Swift? Is coverage at target or signed off? Is the class
   perf-gated (§4.6)?
2. **Grep the class for blockers.** Each one should already have been removed by P4; if one turns up, stop and fix
   it in ObjC first:
   - `@throw` / `@try`
   - an init that doesn't return `self`
   - `self->` access, or ivars used by categories
   - `+initialize` / `+load`
   - `respondsToSelector:` / `performSelector`
   - `NSArchiver`
   - varargs
3. **Add tests first** if any are missing, against the ObjC class, in their own commit.
4. **Write `Foo.swift`:**
   - `@objc(Foo) class Foo`, with `final` only if nothing subclasses it, and the selectors kept.
   - `required` inits, and `@objc dynamic` where needed.
   - **Signatures match the header's generated Swift interface** (§4.4.11).
   - Keep the original algorithms.
5. **Remove `Foo.m`** and its header from the bridging header.
   - ObjC importers switch to `#import "Bricksmith-Swift.h"` in `.m` files and `@class Foo;` in headers.
6. **Build and test.**
   - Goldens and known issues are unchanged.
   - **No test file changed.**
   - The perf check passes if the class is hot.
7. **Update port-status.md** and make one commit: `port: Foo → Swift`.

## 7. Risks

| Risk | Mitigation |
|---|---|
| ARC completion breaks memory semantics | P3 comes after P2; ASan and Leaks |
| Perf regressions | Release perf scheme, synthetic fixture, a committed baseline file, ≤ +20%, a skip fails the gate |
| Output drift | Byte-exact `dataOfType:` goldens; `.gitattributes`; pinned statics; frozen `Localizable.strings` |
| Tests break across the port | Annotations in P1; signature-match rule; swap spike; "no test file changed" in the recipe |
| NSException through Swift | P4 conversion; recipe grep |
| Archive, pasteboard or preferences incompatibility | `@objc(Name)`; decode tests; `NSArchiver` read and write tests |
| Tests polluting the real environment | Test-mode launch; override hooks; temp fixtures; scripted defaults diff |
| A class that can't be ported blocks its ancestors | `stays-objc (accepted)` status, human gate, revert policy |
| A dev build auto-updates to the release | Sparkle off in Debug (P0) |
| GL snapshots differ between machines | Per-machine references, not a CI gate |

## 8. Maintainer decisions (recorded 2026-11-14)

| # | Question | Decision | Where it lands |
|---|---|---|---|
| 1 | Deployment target | **macOS 13.0** | P0 |
| 2 | 3Dconnexion | **Drop it.** The old SDK, the weak-linked framework, and the Carbon dependency all go | P0 (a deliberate feature removal, recorded in its commit) |
| 3 | Part browser | **Keep the `NSDrawer`.** Both existing modes stay: the drawer, and the floating panel (`PartBrowserPanelController`, chosen by `PART_BROWSER_STYLE_KEY`). `NSDrawer` is deprecated but still works; revisit only if a future SDK removes it | P9a ports it as-is; no P9b change |
| 4 | `master` | Fast-forwarded to `20251111-ARC-conversion` (`af3483f`), so the ARC work done so far is kept and not redone | Done 2026-11-14 |
| 5 | LDraw fixture subset | **Allowed** in this repo, which won't be released. Replacing it with synthetic parts is a follow-on (§9) | P1 |
| 6 | Versioning | **New major version, 4.0.0.** Each phase merged to `master` bumps the **patch** number (P0 → 4.0.0, P1 → 4.0.1, …). A significant follow-on such as Metal bumps the **minor** number (4.1.0). Releases and the appcast stay manual | P0 sets 4.0.0; every phase gate bumps the patch |
| 7 | `LDrawDataStream.{h,m}` | **Delete.** It was a 2012 experiment by bsupnik (Rob Barris-style windowed VBO streaming), never compiled and never referenced. Its idea is the standard Metal ring buffer, so it's worth remembering for that work | P0 |

## 9. Follow-on goals (recorded, not planned here)

| Goal | What this plan leaves in place for it |
|---|---|
| **OpenGL → Metal** | `RenderBackend` / `Camera` Swift protocols with no GL types (P8); per-machine render snapshots (row 15); GL removed from the model (P4) |
| **Synthetic test parts.** Replace the `ldraw-mini` subset taken from the LDraw library with generated parts, so the repo could be published | The fixture layout and `ATTRIBUTION.md` (P1) |
| **C → Swift.** Covers `MatrixMath.c`, `GLMatrixMath.c`, `OpenGLUtilities.c`, `MeshSmooth.c` and possibly LSynth (≈11k lines). Likely to move to `simd` types, and best done alongside or after Metal, since `GLMatrixMath` and `MeshSmooth` are renderer-side | Tier-A coverage of `MatrixMath`, seeded geometry property tests (row 5), `lsynthcp` and `LDrawLSynth` goldens (row 13), and Release perf baselines (row 16), all reusable as-is |

## Appendix A: adversarial review log

Every finding was spot-checked against the code before it was accepted.

### Round 1 (on draft v1)

| # | Finding | Decision |
|---|---|---|
| 1 | Headers depend on pch macros | **Accepted.** P1 header hygiene |
| 2 | NSExceptions cross class boundaries | **Accepted.** P4, §4.4.3, recipe |
| 3 | Substitute-self init; `required` inits | **Accepted.** P4 factory, §4.4.4–5 |
| 4 | Swift can't see ObjC ivars | **Accepted.** P4 |
| 5 | Hosted tests polluted by launch and singletons | **Accepted.** P1 test-mode launch, reset hooks, temp fixtures |
| 6 | "Headless" document tests | **Accepted.** Nib-loaded window controller |
| 7 | The renderer seam already exists | **Accepted.** P4 and P8 build on it |
| 8 | Coverage target included GL code | **Accepted.** Per-class targets, GL excluded |
| 9 | Perf measured in Debug | **Accepted.** Release perf scheme |
| 10 | ARC finished without a safety net | **Accepted.** ARC moved to P3 |
| 11 | `+initialize`, `NSArchiver`, `Point3` bytes, enums, insecure unarchiving | **Accepted.** |
| 12 | Port `LDrawDocument` by category | **Accepted.** P10 |
| 13 | UI hierarchies need leaves-first | **Accepted.** P9a |
| 14 | `docs/` untracked | **Rejected.** It was committed in `e7415c1` |
| v2.1 | Separate test bridging header breaks "tests unchanged"; crash guard is a partial fix; USE_BLOCKS removal isn't a no-op | **Accepted.** Single bridging header, swap spike, exit tests, hack removed in P4 |

### Round 2 (on v2.1): a fact-checker and a strategic reviewer, both independent

| # | Finding | Decision |
|---|---|---|
| F1 | The `-LDrawPath` launch argument uses the wrong key (it's `"LDraw Path"`) | **Accepted.** Switched to an override hook (P1) |
| F2 | The launch guard skipped the GL context and inspector that documents need, and missed `applicationDidFinishLaunching:` and `applicationWillTerminate:` | **Accepted.** Explicit keep/skip list, plus a scripted defaults diff |
| F3 / S8 | Wrong Sparkle selector | **Accepted.** `updater:mayPerformUpdateCheck:error:` |
| F4 | 10 `Inspection*` classes, not 9; `Inspector` isn't their superclass | **Accepted.** P9a |
| F5 | ARCHITECTURE tree implied `LDrawModel : LDrawFile` | **Accepted.** Tree fixed |
| F6 / S2 | `LDrawDocument`'s own ivars block a port by category | **Accepted.** P4 converts them |
| F7 | `LDrawModel`/`LDrawStep` GL "calls" are comments | **Accepted.** Removed from P4 |
| F8 | `LDrawDataStream.m` isn't compiled | **Accepted.** Excluded; decision 7 |
| F9–F14 | Corrections to S1, S2, S5, S6 and BUG-001 mechanisms, line refs and counts | **Accepted.** KNOWN-BUGS and ARCHITECTURE corrected |
| F15 | "Builds silently for 10.13" not verified | **Accepted.** Reworded |
| F16 | macOS 14 for tests is a choice, not a requirement | **Accepted.** §4.3 reworded |
| S1 | P4 annotations would break the "tests unchanged" promise | **Accepted.** Annotations moved to P1, signature-match rule, `[test-spelling]` fallback |
| S3 | No CRLF/BOM protection for byte-exact goldens | **Accepted.** `.gitattributes` in P0; byte comparison |
| S4 | Global statics (`ColumnizesOutput`, `defaultAuthor`) | **Accepted.** Reset and pin in P1 |
| S5 | Golden edge cases (float buffer, `-0`, RGB truncation, unseeded `rand()`, encodings, `Localizable.strings`) | **Accepted.** Row 2, manual-only list, injectable RNG |
| S6 | Feature gaps: actions, exports, app-logic classes, `LDrawLSynth`; "printing" doesn't exist | **Accepted.** Rows 10–13; printing removed |
| S7 | P9 mixed porting with modernisation; undo rewrite during the port | **Accepted.** P9a/P9b split; undo rewrite moved to P11 |
| S8 | Releasability, Info.plist min version, Sparkle in dev builds | **Accepted.** §3, P0, §4.3, decision 6 |
| S9 | Gates that are unmeasurable or human-only | **Accepted.** 🧑 markers, committed perf baseline and compare script, skip = fail, warning text diff, hot-class list |
| S10 | Accessibility identifiers need xib edits | **Accepted.** Allowed in P2 |
| S11 | No stall or rollback rule | **Accepted.** §3 |
| S12 | Fixture licence contradiction | **Accepted.** Human gate and decision 5 |
| S13 | `readFromData:` writes `*outError` without a NULL check | **Accepted.** Logged as S9 |
| S14 | Preference-writer format | **Accepted.** Row 7 covers read and write |
| — | "One class per commit" with mutually dependent classes | **Accepted.** Coupled-pairs note in P6 |

### v3.1 (during P1, 2026-11-14)
| Change | Reason |
|---|---|
| Nullability and generics move from "all public headers in P1" to "per header, with its first test" | Annotations without tests would be unverified claims, and a wrong one traps at runtime in Swift. Deferring them to P4 would break "tests unchanged". Tying each one to its first test makes it checked. `-Wnullability-completeness` forces whole-header annotation |
| `NS_ENUM(int, …)`, not `NSInteger` | Keeps size and `@encode` identical (L23) |
| Swap spike passed early (L19) | Confirms §4.2/§4.5 |

### Maintainer input during round 2
- Coverage target raised from a flat ≥ 70% to tiered targets: ≥ 90% (model and format) and ≥ 80% (libraries and app
  logic), plus an uncovered-line ledger and a mutation smoke test.
- C → Swift is recorded as a follow-on goal (§9).
