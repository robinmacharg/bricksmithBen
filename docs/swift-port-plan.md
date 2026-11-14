# Bricksmith: Objective-C → Swift port plan

| | |
|---|---|
| Status | **v2.1**: adversarial review incorporated (see [Appendix A](#appendix-a-adversarial-review-log)) |
| Date | 2026-11-14 |
| Toolchain | Xcode 26.3 (17C529), built-in Swift 6.2.4. No external toolchains |
| Out of scope | OpenGL → Metal (a later project; this plan prepares the seam) |
| Related | [ARCHITECTURE.md](ARCHITECTURE.md) · [TESTING.md](TESTING.md) · [port-status.md](port-status.md) · [KNOWN-BUGS.md](KNOWN-BUGS.md) |

## 1. Goals and non-goals

**Goals**
1. Every Objective-C class in the app is ported to Swift, with today's behaviour preserved.
2. A characterisation test suite is written **before** any risky change (including finishing ARC), so
   regressions show up the moment they appear.
3. The UI is modernised where that is cheap and safe: deprecated controls are replaced and the look stays recognisable.
4. The renderer sits behind a Swift protocol so a Metal backend can drop in later.

**Non-goals**
- Metal rendering. OpenGL stays, deprecation warnings and all.
- Rewriting the C libraries (§4.1).
- New features, and **bug fixes during the port**. Bugs go in [KNOWN-BUGS.md](KNOWN-BUGS.md) with
  expected-failing tests and are fixed after the port, in P12.

## 2. Starting point

- Git history goes back 370 commits. The work branch is `20251111-ARC-conversion`, with an MRC → ARC migration
  about 55% done (≈52 files ARC, 41 files `-fno-objc-arc`).
- **State preserved.** Commit `af3483f` snapshots the uncommitted ARC work and adds `Test Data/`. It is tagged
  `snapshot-20261114-pre-swift-plan` and builds cleanly in Debug with Xcode 26.3. `Source/LDraw.zip`
  (a local backup) is deliberately left untracked.
- There are no tests and no test target.
- Size is about 70k lines: model ≈16k, UI and widgets ≈18k, renderer ≈6k, `LDrawDocument` plus app ≈7.7k, and
  C 5.5k (plus LSynth 5.7k). The per-file breakdown is in [port-status.md](port-status.md).

### Things in the code that shape the plan (verified)

| Fact | Evidence | Consequence |
|---|---|---|
| Headers depend on the prefix header's macros (`OPEN_GL_HEADER`, `dispatch_group_t` → `void *`) | `Mac LDraw_Prefix.pch:31-40`, `LDrawPart.h:12`, `LDrawDirective.h:195` | A Swift bridging header can't import them as they are, so the headers must be fixed **before** tests are written (P1) |
| Parse errors use `@throw` and are caught in *another* class (45 `@throw`/`@try` sites) | `LDrawColor.m:205-217` → caught in `LDrawMetaCommand.m:~146` | NSExceptions must not unwind through Swift frames, so parsing has to be converted to error returns while still in ObjC (P4) |
| `-[LDrawMetaCommand initWithLines:…]` returns a *different* object (LDrawComment/LDrawColor) | `LDrawMetaCommand.m:107-153` | A Swift `init` can't do that, so a factory is introduced first (P4) |
| Subclasses read superclass ivars directly (`self->hidden`, `self->color`, `@protected postsNotifications`) | `LDrawLine.m:213,240,248`, `LDrawContainer.h:25` | Swift subclasses can't see ObjC ivars, so these become properties first (P4) |
| App launch writes real user defaults, loads the user's part library, may show a modal, and starts Sparkle from the nib | `LDrawApplication.m:53-84,421-475,712-735`, `MainMenu.xib:716` | Hosted tests need a launch guard and injected paths from P1, not P7 |
| Singletons initialise lazily, can't be reset, and aren't thread-safe | `ColorLibrary.m:44-103`, `PartLibrary.m:84-90`, `LDrawPaths.m:23-33` | Tests need `+resetForTesting` hooks (P1) |
| `PartCatalogBuilder` writes `parts.plist` into the LDraw folder | `PartCatalogBuilder.m:209` | Fixture libraries are copied to a temp dir for each run |
| Document edit operations read their selection from the outline view | `LDrawDocument.m:6050-6065`, `:858-875` | Document tests must load the nib (no window shown), so "headless" in the strict sense isn't possible |
| `+initialize` registers value transformers | `LDrawApplication.m:53` | Swift can't override `+initialize`, so this moves to launch code |
| Preferences hold colours archived with non-keyed `NSArchiver` | `UserDefaultsCategory.m:22,41` | Existing user data must still be readable, so a test uses a real archived blob |

## 3. Branching and workflow

**Branches are stacked and dated.** Names follow the existing `YYYYMMDD-topic` convention, where the date is the
day the branch was cut. Each phase branch is based on the tip of the previous one:

```
master
 └─ 20251111-ARC-conversion          (existing; tip = snapshot tag)
     └─ 20261114-swift-port-plan     (this plan, docs/, CLAUDE.md)
         └─ YYYYMMDD-p0-build-hygiene
             └─ YYYYMMDD-p1-test-harness
                 └─ YYYYMMDD-p2-characterisation-tests
                     └─ YYYYMMDD-p3-arc-complete
                         └─ … one branch per phase or sub-phase
```

**Rules**
- One phase per branch. Big phases get sub-branches (`…-p6a-model-leaves`, `…-p6b-…`).
- When a lower branch changes, restack from the top with
  `git rebase --update-refs -x scripts/test.sh <base>`. The `-x` re-checks every commit along the way.
- Merge to `master` bottom-up, and only once a branch passes its exit gate. Nothing is pushed to `origin` unless
  the maintainer asks.
- **Every commit builds and every test passes.** Expected failures from known issues count as passing. This keeps
  `git bisect` usable.
- During porting phases, one class (or one category or extension) per commit. The commit message names the class
  and includes any behaviour notes.

**Exit gate for every phase:**
1. `scripts/build.sh` succeeds with no **new** warnings, measured against `docs/warnings-baseline.txt`.
2. `scripts/test.sh` is green, and no known-issue test passes unexpectedly.
3. The manual smoke checklist ([TESTING.md](TESTING.md#manual-smoke-checklist)) is run on the built app.
4. [port-status.md](port-status.md) and [KNOWN-BUGS.md](KNOWN-BUGS.md) are up to date.

## 4. Key technical decisions

### 4.1 C stays C
These stay in C for this plan:
- `MatrixMath.c`, `GLMatrixMath.c`, `OpenGLUtilities.c` and `MeshSmooth.c`
- LSynth (a separate CLI)

They are hot-path geometry and mesh code, and they already import cleanly into Swift as C structs and functions.
The goal is ObjC → Swift. Rewriting the C would add risk without moving us toward it.

The Metal project should revisit them: `simd` would replace `Matrix4`/`Point3`, and `MeshSmooth` could become a
compute job.

### 4.2 Swift mode and settings
- Use **Swift 5 language mode** with `SWIFT_STRICT_CONCURRENCY = minimal` for the whole port. Switch to Swift 6
  mode with complete checking in P11, once everything is Swift. Doing both at once would mean two hard migrations
  in one change.
- There is **one** bridging header, the app's. Tests reach everything through `@testable import Bricksmith`.
  Every header the bridging header imports must be **self-contained** (P1).

### 4.3 Deployment target and signing
- **App: macOS 13.0.** The current 10.11 is below the SDK's 10.13 floor. 13 gives `UTType`, modern sheets and
  alerts, and Swift concurrency without back-deployment shims.
  - *Maintainer decision:* 11.0 (Apple's "recommended" floor) is fine if reach matters more. The plan works the
    same either way.
- **Test bundles: macOS 14.0.** The shipped Swift Testing module's interface targets `macos14.0`. Tests run only on
  developer machines.
- **Signing:** "Sign to Run Locally", with hardened runtime off for Debug and test hosting. Distribution signing is
  out of scope.

### 4.4 Interop rules
1. **Keep the ObjC runtime names.** Declare every ported class as `@objc(OriginalName)` and keep its selectors with
   `@objc(sel:)`. The names matter because of xib `customClass`, `NSDocumentClass`, NSCoding archives and the pasteboard.
2. **ObjC can't subclass a Swift class.** Port leaves first and roots last in every hierarchy, UI included (§5 P6 and P9 list the orders).
   - Swift extensions on ObjC classes are fine.
   - ObjC categories on `@objc` Swift classes are fine.
   - Swift **cannot** see ObjC ivars (P4 removes cross-class ivar access).
3. **No NSException may cross into Swift.** Parse errors become `BOOL` + `NSError **` (P4). Any `@try` that remains
   has to sit entirely inside ObjC.
4. **No init that returns a substitute object.** Use factories (P4).
5. **Swift needs `required` inits** for `[[self class] alloc] init]` in `copyWithZone:` (`LDrawDirective.m:172`) and
   for `init?(coder:)` along the decode chain.
6. **Use `@objc dynamic`** on anything accessed through KVC, KVO or bindings (221 xib bindings, ≈33 KVC sites).
7. **Macros and plain enums don't import well.** Convert `MacLDraw.h`, `LDrawKeywords.h` and `LDrawPathNames.h` to
   `extern NSString * const` / `NS_TYPED_EXTENSIBLE_ENUM`, and plain `typedef enum` (`PartTypeT`, `MessageT`, …) to
   `NS_ENUM`. **The string values of preference keys must stay the same.** A test enforces this.
8. **Headers:** ObjC `.h` files never import `Bricksmith-Swift.h`. Use `@class` and `@protocol` forward declarations
   instead, and import the generated header in `.m` files only.
9. **C fixed arrays** (`GLfloat glTransformation[16]`) become tuples in Swift. Hide them behind `Matrix4` accessors.
10. **Struct layout:** `encodeBytes:` of `Point3` (`LDrawQuadrilateral.m:189-193`) depends on the C layout. Keep
    the C struct type; don't redefine it in Swift.

### 4.5 Testing frameworks
- **Swift Testing** for unit and characterisation tests: parameterised fixtures, plus `withKnownIssue` for known bugs.
- **XCTest** for `measure {}` performance baselines (with `XCTExpectFailure` where needed) and for XCUITest.
- Tests are written **in Swift against the ObjC API**. When a class switches to Swift, the same tests run unchanged.

## 5. Phases

Sizes are relative (S < M < L < XL), not calendar estimates.

### P0: build hygiene (S)
Branch `…-p0-build-hygiene`
- Set deployment target 13.0 and signing (§4.3). Fix build fallout, but **leave deprecation warnings alone** for now.
- Move the `LSynth` scheme from the committed `xcuserdata` into `xcshareddata`, i.e. move it rather than copy it.
- Add `scripts/build.sh`: an `xcodebuild` wrapper with a scratch derived-data dir that prints a warning count.
  Record `docs/warnings-baseline.txt`.
- **Exit:** clean build; the app opens `trunk/Test Data/Good/spider gearbox v2 opens.ldr`; manual smoke checklist passes.

### P1: header hygiene and test harness (M)
Branch `…-p1-test-harness`

**Header hygiene** (so Swift can import the model):
- Every header the tests need imports what it uses (`<Cocoa/Cocoa.h>`, `<OpenGL/gl.h>`, …) and doesn't rely on the pch.
- Move the `USE_BLOCKS 0` / `dispatch_queue_t`/`dispatch_group_t` → `void *` hack out of the pch into a small
  self-contained header (`LDrawDispatchCompat.h`), and import it from every header that uses those types. That way
  Swift sees exactly the types the ObjC was compiled with.
  - **Don't delete the hack in P1.** It guards 49 `#if USE_BLOCKS` sites, so removing it isn't a no-op. P4 removes it.

**One import route for tests**
- P1 creates the **app's** bridging header and one placeholder Swift file.
- Tests use `@testable import Bricksmith` and see ObjC types *only* through the app's bridging header. There is no
  separate test bridging header.
- When a class is ported, its header comes out of that single place, and the tests don't change.

**Test bundle**
- Add `BricksmithTests`: Swift, hosted by the app (`TEST_HOST`), macOS 14, code coverage on, with `@testable import Bricksmith`.
- Hosted, because the model needs AppKit, `NSBundle mainBundle` (LSynth and resources) and app singletons.

**Launch isolation.** When the test-mode guard detects that `XCTestConfigurationFilePath` is set in the environment:
- `-awakeFromNib` and `-applicationWillFinishLaunching:` return early, so there is no 3Dconnexion, no `findLDrawPath`,
  no catalog load and no modal.
- Sparkle is disabled through the updater delegate (`updater:mayPerformUpdateCheck:` → NO) and `SUEnableAutomaticChecks=NO`.
- The test scheme passes the fixture LDraw path as a launch argument (`-LDrawPath …` → `NSArgumentDomain`), so it
  takes effect before any singleton is built. The real `com.AllenSmith.Bricksmith` defaults are never written.

**Other harness pieces**
- **Resettable singletons:** add small ObjC `+resetForTesting` hooks to `ColorLibrary`, `PartLibrary`, `LDrawPaths`,
  `ModelManager` and `MLCadIni`. Suites that use them are `.serialized`.
- **Fixture library:** `trunk/Fixtures/ldraw-mini/` is hand-built and checked in. It holds `LDConfig.ldr`, about 20
  small parts and some primitives, and `parts.lst`. It's **copied to a temp dir for each run**, because the catalog
  builder writes into the folder.
- **Full library (optional):** `scripts/fetch-ldraw.sh` downloads ldraw.org `complete.zip` into `~/Library/Caches`.
  It's gitignored and never vendored, because of the library's licence terms. Tests that need it are tagged
  `.requiresFullLibrary` and skip when it's missing.
- `scripts/test.sh` writes an xcresult bundle and a coverage summary. A `Bricksmith-Perf` scheme runs the perf tests
  in **Release** with testability enabled.
- Add a `BricksmithUITests` target with one launch-and-open test.
- **Crash-safe expected failures:** run a spike to see whether Swift Testing **exit tests**
  (`#expect(processExitsWith: .failure)`) work from the app-hosted bundle.
  - If they do, crashing bugs such as BUG-001 are recorded as "crashes today" without touching app code.
  - If they don't, add a tiny helper that runs the case in a child process. Examples: an `XCTest` that launches the
    built app with a `--parse-file` test hook, or `lsynthcp`-style CLI parsing.
- **Exit:**
  - A trivial parse test passes.
  - Repeated runs leave the user's defaults and the fixture folder unchanged.
  - **Swap spike** (on a throwaway branch):
    1. Write a test against `TransformerIntMinus1`.
    2. Port the class to Swift.
    3. Confirm the *same* test file compiles and passes with no edits.

    This proves the "tests run unchanged across the port" claim before anything relies on it.

### P2: characterisation tests (L), the core of the plan
Branch `…-p2-characterisation-tests`. Sub-branches are allowed.

These tests are written against **today's mixed MRC/ARC build** and record its behaviour, bugs included.
Goldens come from the ObjC build and are reviewed by a person before they're committed.

**Bug policy (applies from here to the end of the port).** For every bug found:
1. Log it in [KNOWN-BUGS.md](KNOWN-BUGS.md).
2. Write a test that asserts the **correct** behaviour, wrapped in `withKnownIssue("BUG-nnn …")` (or `XCTExpectFailure`).
3. Don't fix it.

If a known issue starts passing unexpectedly, the port changed behaviour: stop and investigate.

**Crashing bugs** can't be wrapped in `withKnownIssue`. Record them in two ways:
- Characterise the root cause directly. For BUG-001, assert that `+classForDirectiveBeginningWithLine:` returns
  `Nil` for a `11 …` line; that call doesn't crash.
- Record the whole-file crash with an exit test or a child-process test (P1).

A minimal guard in app code is a **last resort**, used only if neither approach works. A guarded entry is marked
`guarded` in the register.

| # | Area | What's tested | How |
|---|---|---|---|
| 1 | **Parse → write round trip** | Every directive type: part, line, triangle, quad, conditional line, comment, `!COLOUR`, `STEP`, `ROTSTEP`, MPD `0 FILE`/`NOFILE`, `!TEXMAP`, LSynth blocks, `0x2RRGGBB` colours, header metadata | Parameterised over `Fixtures/ldr/`. `write(parse(x)) == golden`, plus idempotence. Run both columnized and not. Goldens are byte-exact, which pins the float formatting. |
| 2 | **Parser robustness** | Blank lines, CRLF, tabs, trailing whitespace, unknown meta, unknown line code (BUG-001), truncated lines (suspected S2), malformed `!COLOUR` (S1), non-UTF-8 | Record current output; wrap the bugs in `withKnownIssue`. BUG-001: the root cause is asserted directly, and the crash is recorded with an exit or child-process test. |
| 3 | **Object model** | Tree shape, `NSCopying` deep copy, keyed NSCoding round trip (the pasteboard format), observer notifications | Structural assertions. Also decode archives produced by the ObjC build and committed as fixtures. |
| 4 | **MatrixMath and geometry** | Compose ∘ decompose ≈ identity; invert; multiply; ray–triangle and ray–box intersection; bounds; polygon containment; `ComputationalGeometry` hull and tangents | Table tests and seeded property tests. |
| 5 | **Snapping and transforms** | Grid and angle snapping, move and rotate, view-orientation mapping | Table tests. |
| 6 | **Colours** | `ColorLibrary` lookup, blended and custom colours, `!COLOUR`, edge colours; **`NSArchiver` colour blobs from preferences** | Fixture `LDConfig.ldr`, plus a real archived blob. |
| 7 | **Paths, library, catalog** | `LDrawPaths`, case-insensitive names, `PartCatalogBuilder` on the mini library, descriptions and categories, `MLCadIni` | Temp copy of the fixture library. |
| 8 | **MPD and ModelManager** | Submodel lookup, renaming updates references, active model, cross-document references | Fixtures. |
| 9 | **Document operations and undo** | Add, delete, move, nudge, rotate, change colour, add or move step, rename submodel, copy and paste; each followed by undo and redo | Open the doc, call `makeWindowControllers` (nib loaded, window not ordered front), select rows in the outline view, call the action, then compare the written text after op, undo and redo with goldens. |
| 10 | **Preferences contract** | Every defaults key string and its registered default | Snapshot test. |
| 11 | **LSynth** | `lsynthcp` on sample hose and band input | Run the bundled binary as a black box. |
| 12 | **Render snapshots** | Fixed-camera offscreen renders of 5–10 fixtures, wireframe and shaded | Offscreen CGL → FBO, compared with a tolerance. **They are tied to the machine** (GL-on-Metal output differs between GPUs and OS versions): references are recorded per machine and are not a CI gate. They are kept as a loose reference for the Metal port. |
| 13 | **Performance** | Parse a large model, collect and draw, build the catalog | XCTest `measure` in the **Release** perf scheme, on a recorded machine, with fixed iterations. The Swift port must stay within +20%. Large inputs are tagged `.requiresFullLibrary`. |
| 14 | **UI smoke** | Launch, open, select in outline, inspector shows values, edit, undo, save-as and reopen, open each panel | XCUITest, kept deliberately thin. |

**Coverage targets** (line coverage, **per class**, measured on the model/logic classes):
- ≥ 70% for each class in `LDraw/Commands`, `LDraw/Files` and the non-GL `LDraw/Support` classes
  (`LDrawUtilities`, `ColorLibrary`, `LDrawPaths`, `PartLibrary` logic, `ModelManager`, `PartCatalogBuilder`).
- Excluded from that target: `LDrawGLRenderer`, `LDrawGLCamera`, `LDrawDragHandle` and the `.c` GL helpers. Render
  snapshots and UI smoke tests cover them.
- `LDrawDocument`: target set **after** row 9 proves out. The initial aim is that every menu action reachable through
  the outline view is exercised.
- A class below target can't be ported until the gap is closed, or until it's recorded as an accepted risk in port-status.md.

**Exit:** every row has tests, the targets are met or their exceptions recorded, and the default suite runs in under
3 minutes. Write the manual smoke checklist in TESTING.md for what automation can't reach: 3D-view interaction,
drag and drop, printing and export, 3Dconnexion.

### P3: finish ARC (M)
Branch `…-p3-arc-complete`. **This comes after the tests:** the remaining MRC files are the riskiest ones
(`LDrawDirective`, `LDrawMetaCommand`'s object swap, `LDrawDocument`, `PartLibrary`, `LDrawGLView`).
- Convert the 41 `-fno-objc-arc` files with the existing tooling (`arc-migrate.sh`, `update_arc_flags.rb`). Then set
  `CLANG_ENABLE_OBJC_ARC = YES` project-wide and remove the per-file flags.
- `RegexKitLite` stays `-fno-objc-arc` until P4 deletes it.
- Run the full suite and the manual checklist after each batch of files. Run the Address Sanitizer and the Leaks
  instrument on the smoke flows once at the end.
- **Exit:** gate (§3) passes; no goldens changed.

### P4: ObjC prep refactors, no behaviour change (L)
Branch `…-p4-prep`. Goldens and known issues **must not change** in this phase.

**Parser interop (P6 depends on these)**
- Replace parse-path `@throw`/`@catch` with `BOOL` + `NSError **` returns, **keeping every current outcome**,
  including the half-parsed `!COLOUR` (S1). A test pins each outcome.
- Add the factory `+[LDrawDirective directiveWithLines:inRange:parentGroup:]`. It replaces
  `LDrawMetaCommand`'s substitute-`self` init, and all callers move to it.
- Replace cross-class ivar access with properties. Check the draw-loop cost against perf baselines.

**Types and declarations**
- Convert macros and `typedef enum`s to typed constants and `NS_ENUM` (§4.4.7).
- Remove the `USE_BLOCKS` / `LDrawDispatchCompat.h` hack. Delete the 49 dead `#if USE_BLOCKS` branches (parsing
  stays serial) and use the real `dispatch_*_t` types.
- Remove the pch's Carbon import and import Carbon only in the 3Dconnexion code.
- Add nullability (`NS_ASSUME_NONNULL`) and lightweight generics to public headers.
- Turn informal protocols (`NSObject (LDrawGLViewDelegate)`) into formal `@protocol`s.
- Move `+[LDrawApplication initialize]`'s transformer registration into launch code.

**Code removal and modernisation**
- Replace RegexKitLite with `NSRegularExpression` and delete it (2.6k lines).
- Replace old enum names (≈38 sites) and `loadNibNamed:owner:` (17 sites).

**Rendering seam.** Remove the remaining GL calls from model classes and route them through the **existing**
`LDrawRenderer` / `LDrawCollector` protocols (`LDrawRenderer.h`). Affected files:
- `LDrawPart.m` (8 calls)
- `LDrawDirective.m` (2)
- `LDrawModel.m` and `LDrawStep.m` (1 each)
- `LDrawDragHandle.m` (24)
- `PartLibrary`, for texture creation

**Document split.** Split `LDrawDocument.m` (6.4k lines) into categories by concern: file I/O, edit operations,
selection, undo, menus, viewers. Where it's practical, extract a view-independent edit-operation layer and widen the
row 9 tests to cover it.

### P5: leaf utilities and categories → Swift (S)
Covers `StringUtilities`, `BricksmithUtilities`, `MLCadIni` and `TransformerIntMinus1`, and the categories as Swift
extensions.
- **Exception:** `UserDefaultsCategory` keeps reading old `NSArchiver` blobs (row 6 test). Bridge to `NSUnarchiver`
  if necessary.
- This phase proves the bridging header, the interop rules and the recipe (§6).

### P6: LDraw model → Swift (XL)
Port leaves before roots. Names, selectors, NSCoding keys and `write` output stay identical.
- **p6a leaves:** `LDrawConditionalLine`, `LDrawTriangle`, `LDrawQuadrilateral`, `LDrawComment`, `LDrawColor`,
  `LDrawLSynthDirective`, `LDrawDragHandle`, `LDrawMPDModel`
- **p6b middle:** `LDrawLine`, `LDrawPart`, `LDrawMetaCommand`, `LDrawTexture`, `LDrawLSynth`, `LDrawStep`, `LDrawModel`
- **p6c roots:** `LDrawFile`, `LDrawContainer`, `LDrawDrawableElement`, `LDrawDirective`
  - Check the order against the real `@interface` lines before starting. A class can only move once all its
    subclasses are Swift.

Check the Release perf baselines after each class. ARC traffic in parse and draw loops is the most likely regression.

### P7: libraries and managers → Swift (L)
`ColorLibrary`, `LDrawPaths`, `LDrawUtilities`, `ModelManager`, `PartLibrary`, `PartCatalogBuilder`, `PartReport`,
`ComputationalGeometry`.
- Proper dependency injection: the `shared` accessors stay, and paths and defaults come from an injectable
  environment. The P1 `+resetForTesting` hooks are replaced and then deleted.
- `dispatch_once`-style (`static let`) initialisation fixes the lazy-init race as a side effect. S3 is only latent
  while parsing is serial, so record it as fixed-by-port in the register.

### P8: renderer (still OpenGL) → Swift (L)
`LDrawGLRenderer`, `LDrawGLCamera`, `LDrawShaderRenderer`, `LDrawDisplayList`, `LDrawDataStream`, `LDrawShaderLoader`,
`LDrawBDPAllocator`.
- Evolve the existing `LDrawRenderer` / `LDrawCollector` protocols into Swift `RenderBackend` / `Camera` protocols
  **without GL types** (`Matrix4`/`simd` and Swift closures in place of `GLfloat *` and C function pointers). GL is the
  first implementation, and Metal plugs in later.
- Render snapshots (row 12) stay within tolerance. Use `GL_SILENCE_DEPRECATION` centrally.

### P9: widgets, panels, inspectors, UI modernisation (XL)
Port leaves first within each UI hierarchy:
- 9 `Inspection*` classes → `ObjectInspectionController` → `Inspector`
- `MovePanel`, `DimensionsPanel`, `PieceCountPanel` → `DialogPanel`
- `PartBrowserTableView` → `ExtendedTableView`; `ViewportArranger` → `ExtendedSplitView`
- `LDrawGLView` last among the widgets, because it is GL-heavy and the biggest (3.2k lines)

Replace deprecated UI, keeping layout and behaviour:
- `NSMatrix` (19 instances) → radio `NSButton` groups or `NSSegmentedControl`
- `NSDrawer` (part browser) → a split-view sidebar or a panel
- `LDrawColorCell` and `IconTextCell` → view-based table cells
- The `AMSProgressBar` framework (legacy nib) → an `NSProgressIndicator` sheet; delete the framework

Also:
- Declare UTIs (`UTExportedTypeDeclarations` for ldr/mpd/dat conforming to `public.plain-text`).
- Keep the xibs; **no SwiftUI rewrite**. `NSHostingView` is allowed for small new views.
- Keep Cocoa bindings as `@objc dynamic`.
- When a control changes, update its UI test in the same commit.

### P10: document and application → Swift (L)
- Port `LDrawDocument` **one category at a time**, as a Swift extension per P4 category, with the core
  `@implementation` last. Nothing subclasses it, and ObjC categories on an `@objc` Swift class still work in the meantime.
- Port `LDrawApplication` and `BricksmithApplication`, and replace `main.m` with `@main`.
- Undo moves to `registerUndo(withTarget:)` closures.
- 3Dconnexion: keep the Carbon-era SDK behind a tiny C/ObjC shim.
  - *Maintainer decision:* keep it, drop it, or replace it with the current 3Dconnexion SDK.
- Pasteboard `unarchiveObjectWithData:` (non-secure, `LDrawDocument.m:3763,6334`) keeps working through the
  equivalent Swift API. Moving to secure coding is logged in KNOWN-BUGS for P12, not done during the port.

### P11: hardening (M)
- Remove the last `.m` files, leaving C headers only in the bridging header.
- Switch to Swift 6 language mode with complete concurrency checking and `@MainActor` UI.
- Revisit parallel parsing, with TSan.
- Remove `@objc` where it's no longer needed. Keep `@objc(Name)` on anything referenced by xibs or archives.
- Rebaseline warnings, and update ARCHITECTURE.md to the Swift structure.

### P12: post-port bug fixing (size depends on the register)
Work through [KNOWN-BUGS.md](KNOWN-BUGS.md): crash and data-loss bugs first, then confirm and triage the suspected
entries. Fixes are Swift-only. Each fix is one commit containing:
- the fix
- the `withKnownIssue` removed
- any golden updates, explained in the commit message
- the register row set to `fixed`

## 6. Per-class porting recipe (for humans and agents)

1. **Check port-status.md:** are all the class's subclasses already Swift, and is its coverage at target?
2. **Grep the class** for the following. Each one has a P4 fix that must already be done.
   - `@throw` / `@try`
   - an `init` that returns something other than `self`
   - `self->` ivar access from subclasses
   - `+initialize` / `+load`
   - `respondsToSelector:` / `performSelector`
   - `NSArchiver`
   - varargs
3. **Add tests first** if any are missing, against the ObjC class, and commit them separately.
4. **Write `Foo.swift`:**
   - `@objc(Foo) class Foo` (add `final` only if nothing subclasses it), with selectors kept.
   - `required` inits as needed (§4.4.5), and `@objc dynamic` for KVC, KVO or bindings.
   - Keep the original algorithms. Idiomatic rewrites come after the port.
5. **Remove `Foo.m` from the target** and delete it.
   - ObjC importers switch to `#import "Bricksmith-Swift.h"` in `.m` files and `@class Foo;` in headers.
   - Keep `Foo.h` only while an ObjC header still needs it.
6. **Build and test.** Goldens and known issues are unchanged, and the Release perf check passes in hot classes.
7. **Update port-status.md** and make one commit.

## 7. Risks

| Risk | Mitigation |
|---|---|
| ARC completion breaks memory semantics | P3 comes after P2 tests; ASan and Leaks runs at the end |
| Perf regressions (ARC traffic, `NSArray` bridging) | Release-mode baselines with a +20% budget; keep C structs; `ContiguousArray`; profile before optimising |
| Behaviour drift in `write` output | Byte-exact goldens; port commits never change goldens |
| NSException unwinding through Swift | P4 converts parsing to error returns; recipe grep step |
| Archive, pasteboard or preferences incompatibility | `@objc(Name)`; decode tests on committed archives from the ObjC build; `NSArchiver` colour test |
| Hosted tests polluted by app launch or singletons | P1 launch guard, `NSArgumentDomain` paths, reset hooks, temp-dir fixtures |
| Document tests can't reach some operations | Nib-loaded window controller in row 9; P4 operation-layer extraction; gaps recorded |
| Hidden dynamic dispatch (`respondsToSelector:` ×74, `performSelector` ×12) | Formal protocols in P4; recipe grep step |
| GL snapshots differ between machines | Per-machine references, not a CI gate |
| LSynth `NSTask` under a future sandbox | Out of scope; noted for distribution work |

## 8. Decisions for the maintainer
1. Deployment target: **13.0** (recommended) or 11.0.
2. 3Dconnexion: keep the old SDK behind a shim (default), drop it, or replace it.
3. Part browser: replace `NSDrawer` with a **split-view sidebar** (default) or a floating panel.
4. Whether `master` should be fast-forwarded to `20251111-ARC-conversion` before the stack begins.

## Appendix A: adversarial review log

A fresh agent reviewed draft v1 against the code on 2026-11-14. Claims were spot-checked with grep before
being accepted.

| # | Finding | Severity | Decision |
|---|---|---|---|
| 1 | Headers depend on pch macros, so the bridging header fails in P1 | High | **Accepted.** Header hygiene moved into P1 |
| 2 | NSExceptions thrown across class boundaries would unwind through Swift | High | **Accepted.** P4 conversion, §4.4.3, recipe step |
| 3 | `LDrawMetaCommand` init returns a substitute; `required` inits | High | **Accepted.** P4 factory, §4.4.4–5 |
| 4 | Swift subclasses can't read ObjC ivars | High | **Accepted.** P4 ivars → properties |
| 5 | Hosted tests polluted by launch, Sparkle and singletons; DI too late | High | **Accepted.** P1 guard placement, `NSArgumentDomain`, reset hooks, temp fixtures |
| 6 | "Headless" document tests would cover almost nothing | High | **Accepted.** Row 9 uses the nib-loaded window controller; the `LDrawDocument` target is deferred |
| 7 | The renderer protocol seam already exists; serial parsing is already the default | Med | **Accepted.** P4 and P8 reworded to build on the existing protocols |
| 8 | Coverage target swept in GL code | Med | **Accepted.** Per-class targets with GL exclusions |
| 9 | +20% perf budget meaningless in Debug | Med | **Accepted.** Release perf scheme |
| 10 | ARC completion had no safety net | Med | **Accepted.** ARC moved to P3, after the tests; build hygiene stays in P0 |
| 11 | `+initialize`, `NSArchiver` prefs, `Point3` byte encoding, plain enums, insecure unarchiving | Med | **Accepted.** §4.4, P4, P5, P10 |
| 12 | Port `LDrawDocument` category by category | Med | **Accepted.** P10 |
| 13 | Leaves-first ordering for UI hierarchies | Med | **Accepted.** P9 ordering |
| 14a | Signing for the test host; LSynth scheme lives in `xcuserdata` | Low | **Accepted.** §4.3, P0 |
| 14b | `docs/` untracked on the plan branch | Low | **Rejected.** Factually wrong: committed in `e7415c1` |
| 14c | Verify that Swift Testing needs macOS 14 | Low | **Checked and kept.** The shipped `Testing.swiftmodule` interface targets `arm64-apple-macos14.0` |
| 14d | `rebase -x` to check every restacked commit | Low | **Accepted.** §3 |
| 15 | GL snapshots are machine-specific | Low | **Accepted.** Row 12 |
| — | Six suspected app bugs (S1–S6) | — | **Added** to KNOWN-BUGS.md "Suspected", to be confirmed by P2 tests |
| v2.1 | Final review: a separate test bridging header plus deleted `.h` files would break "tests unchanged"; a crash guard is a partial fix; deleting `USE_BLOCKS` in P1 isn't a no-op (it also redefines `dispatch_queue_t`, with 49 `#if` sites) | — | **Accepted.** One bridging header and a swap spike (P1); exit or child-process tests for crashes; hack made self-contained in P1 and removed in P4 |
