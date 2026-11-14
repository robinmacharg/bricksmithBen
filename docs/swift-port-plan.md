# Bricksmith: Objective-C → Swift port plan

| | |
|---|---|
| Status | Draft v1 (pre-review) |
| Date | 2026-11-14 |
| Toolchain | Xcode 26.3 (17C529), built-in Swift 6.2.4. No external toolchains, no SwiftPM-only builds of the app |
| Out of scope | OpenGL → Metal (a later project; this plan prepares the seam) |
| Related | [ARCHITECTURE.md](ARCHITECTURE.md) · [TESTING.md](TESTING.md) · [port-status.md](port-status.md) |

## 1. Goals and non-goals

**Goals**
1. Every Objective-C class in the app is ported to Swift, and the app keeps its current behaviour.
2. A characterisation test suite is written **before** any code is ported, so regressions show
   up the moment they happen.
3. The UI is modernised where it's cheap and safe: deprecated controls are replaced and the
   look stays recognisable.
4. The renderer sits behind a Swift protocol so a Metal backend can drop in later.

**Non-goals**
- Metal rendering. OpenGL stays, deprecation warnings and all.
- Rewriting the C libraries (see §4.1).
- New features. File-format behaviour changes only through explicit, test-recorded bug fixes.

## 2. Starting point

- Git history goes back 370 commits. The current work branch is `20251111-ARC-conversion`, with an MRC → ARC
  migration about 55% done.
- **The state is preserved.** Commit `af3483f` snapshots the uncommitted ARC work and adds `Test Data/`.
  It is tagged `snapshot-20261114-pre-swift-plan`, and it builds cleanly in Debug with Xcode 26.3.
  `Source/LDraw.zip` (a local backup) is deliberately left untracked.
- There are no tests and no test target.
- Size: roughly 70k lines. The bulk is the model (≈16k), UI and widgets (≈18k), renderer (≈6k), and
  `LDrawDocument` plus the app delegate (≈7.7k). [port-status.md](port-status.md) has the per-file breakdown.

## 3. Branching and workflow

**Stacked, dated branches.** Branch names follow the existing `YYYYMMDD-topic` convention. The date is
the day the branch was cut. Each phase branch starts from the tip of the one before it:

```
master
 └─ 20251111-ARC-conversion          (existing; tip = snapshot tag)
     └─ 20261114-swift-port-plan     (this plan, docs/, CLAUDE.md)
         └─ YYYYMMDD-p0-arc-complete
             └─ YYYYMMDD-p1-test-harness
                 └─ YYYYMMDD-p2-characterisation-tests
                     └─ … one branch per phase (or per sub-phase for the big ones)
```

Rules:
- One phase per branch. A big phase (P6, P9) gets sub-branches such as `…-p6a-model-leaves` and `…-p6b-model-containers`.
- When a lower branch changes, restack with `git rebase --update-refs` from the top branch.
- Merging to `master` goes bottom-up and only when a branch passes its exit gate. Nothing is pushed to `origin`
  unless the maintainer asks.
- **Every commit builds, and every test passes** (apart from recorded known issues). This keeps `git bisect` usable.
- One class per commit during porting phases. The commit message names the class and lists any behaviour notes.

**Exit gate for every phase:**
1. `scripts/build.sh` succeeds with no **new** warnings. The warning count is tracked in `docs/warnings-baseline.txt`.
2. `scripts/test.sh` is green. Any `withKnownIssue` entries are listed in [TESTING.md](TESTING.md).
3. Someone runs the manual smoke checklist in [TESTING.md](TESTING.md) on the built app.
4. [port-status.md](port-status.md) is updated.

## 4. Key technical decisions

### 4.1 C stays C
`MatrixMath.c`, `GLMatrixMath.c`, `OpenGLUtilities.c`, `MeshSmooth.c` and LSynth (5.5k + 5.7k lines) remain C.
- They are hot-path geometry and mesh code, and they already import cleanly into Swift as C structs and functions.
- The task is Objective-C → Swift, and rewriting the C would add risk without moving us toward the goal.
- When the Metal work starts, we revisit them: `simd` types would replace `Matrix4`/`Point3`, and `MeshSmooth` might move to compute shaders.

### 4.2 Swift mode and settings
- **Swift 5 language mode** with `SWIFT_STRICT_CONCURRENCY = minimal` for the duration of the port.
- Swift 6 mode and complete concurrency checking come in P11, once all the code is Swift. Turning them on earlier
  would mix two difficult migrations in one change.
- `SWIFT_OBJC_INTEROP_MODE` stays at the default (objc).
- The app and test targets get a bridging header, `Bricksmith-Bridging-Header.h`.

### 4.3 Deployment target
Raise it from 10.11, which is below the SDK's 10.13 floor, to **macOS 13.0**.
- The test bundle targets **macOS 14.0**, because that is what the shipped Swift Testing module requires. It can run
  on a higher target than the app because tests only run on developer machines.
- Why 13: it is old enough to cover most users of a hobbyist app that was last released years ago, and it gives us
  `NSHostingView`, `UTType`, modern `NSAlert` and sheet APIs, and Swift concurrency with no back-deploy shims.
- *Decision for the maintainer:* 11.0 is Apple's "recommended" floor if you need wider reach.
  The plan works the same with either.

### 4.4 Interop rules
1. **Keep the ObjC runtime names.** Every ported class is declared `@objc(OriginalName)`, for these reasons:
   - Xib `customClass` entries, `NSDocumentClass` in Info.plist, and `NSCoding` archives (pasteboard data, saved
     part-browser state) all look classes up by name.
   - Selectors that ObjC call sites use stay the same through explicit `@objc(selector:)` annotations.
2. **ObjC cannot subclass a Swift class.** Inside a class hierarchy, port **leaves first and roots last**. For example,
   `LDrawConditionalLine` comes before `LDrawLine`, and every drawable comes before `LDrawDrawableElement` and `LDrawDirective`.
3. **Use `@objc dynamic`** on every property that is reached through KVC, KVO or Cocoa bindings (221 xib bindings,
   about 33 KVC sites).
4. **Macros don't import.** P4 converts `MacLDraw.h`, `LDrawKeywords.h` and `LDrawPathNames.h` to
   `extern NSString * const` and `NS_ENUM` / `NS_TYPED_EXTENSIBLE_ENUM` declarations.
   **Preference key string values must not change**, or users lose their settings. A test asserts this.
5. **Headers:** ObjC `.h` files must not import `Bricksmith-Swift.h`. Use `@class` forward declarations in headers and
   import the generated header in `.m` files.
6. **C fixed arrays become tuples in Swift** (e.g. `GLfloat glTransformation[16]`). Wrap them in accessors that take
   or return `Matrix4`, rather than spreading tuple code around.

### 4.5 Testing frameworks
- **Swift Testing** (`import Testing`) for unit and characterisation tests: parameterised tests suit the
  fixture-driven goldens, and `withKnownIssue` records known bugs.
- **XCTest** for `measure {}` performance baselines and XCUITest UI smoke tests.
- Tests are written **in Swift against the ObjC API** through the bridging header. Then the same tests run unchanged as
  each class switches to Swift, which is the point of writing them first.

## 5. Phases

Sizes are relative (S < M < L < XL), not calendar estimates.

### P0: finish ARC and get a green baseline (M)
Branch `…-p0-arc-complete`
- Finish converting the 41 `-fno-objc-arc` files with the existing tooling (`arc-migrate.sh`,
  `update_arc_flags.rb`). Then set `CLANG_ENABLE_OBJC_ARC = YES` project-wide and remove the per-file flags.
  Mixing MRC code with Swift ownership is a source of subtle over-releases, so this is a prerequisite.
- RegexKitLite (MRC, OSAtomic) stays `-fno-objc-arc` for now; P4 deletes it.
- Raise the deployment target (§4.3). Fix any build fallout, but don't fix deprecation warnings yet.
- Share the `LSynth` scheme, which currently lives only in `xcuserdata`.
- Add `scripts/build.sh`: an `xcodebuild` wrapper that uses a local derived-data dir and prints a warning count.
  Record `docs/warnings-baseline.txt`.
- **Exit:** clean build, the app launches and opens `Test Data/Good/*.ldr`, and the manual smoke checklist passes.
  (There are no automated tests yet. Watch for ARC regressions by hand, particularly in undo, copy/paste and closing documents.)

### P1: test harness (M)
Branch `…-p1-test-harness`
- Add a `BricksmithTests` unit-test bundle hosted by the app (`TEST_HOST`). It uses Swift, has its own bridging header,
  targets macOS 14, and has code coverage turned on.
  - Hosted, because the model depends on AppKit, `NSBundle mainBundle` (LSynth, resources) and app singletons.
- **Test-mode launch guard:** when `XCTestConfigurationFilePath` is set in the environment, `LDrawApplication` skips
  first-run UI such as the LDraw-folder prompt, Sparkle and 3Dconnexion. Keep this ObjC change small and covered by a test.
- **Fixture LDraw library:** `trunk/Fixtures/ldraw-mini/` holds a hand-made minimal library that is checked in:
  - `LDConfig.ldr`
  - about 20 small `.dat` parts plus a few `p/` primitives
  - a `parts.lst`
  Tests point `LDrawPaths` at it through a test-only defaults domain (`NSArgumentDomain`, or `UserDefaults(suiteName:)`
  plus a swizzle-free injection hook). They never touch the developer's real preferences.
- **Full library (optional):** `scripts/fetch-ldraw.sh` downloads ldraw.org `complete.zip` to `~/Library/Caches/…`.
  It is gitignored and never vendored, because of LDraw library licence terms. Tests that need it are tagged
  `.requiresFullLibrary` and skip when it is absent.
- Add `scripts/test.sh`, which runs `xcodebuild test` and writes an xcresult bundle plus a coverage summary.
- Add a `BricksmithUITests` target (XCUITest) containing a single "launch and open fixture" test.
- **Exit:** a trivial test passes, the coverage report is produced, and the scripts are documented in [TESTING.md](TESTING.md).

### P2: characterisation tests (L), the core of the plan
Branch `…-p2-characterisation-tests` (sub-branches allowed).

These tests record **current behaviour**, bugs included, as the baseline. Goldens are generated by running the ObjC
build, then reviewed by a person before they're committed.

| # | Area | What's tested | How |
|---|---|---|---|
| 1 | **Parse → write round-trip** | Every directive type: part, line, triangle, quad, conditional line, comment, `!COLOUR`, `STEP`, `ROTSTEP`, MPD `0 FILE`/`0 NOFILE`, `!TEXMAP`, LSynth blocks, custom `0x2RRGGBB` colours, header metadata | Parameterised over `Fixtures/ldr/*.ldr`. Assert `write(parse(x)) == golden`, plus idempotence: `write(parse(write(parse(x)))) == write(parse(x))`. Run columnized and non-columnized. |
| 2 | **Parser robustness** | Blank lines, CRLF, tabs, trailing whitespace, unknown meta commands, unknown line codes (`Test Data/Bad`), truncated lines, non-UTF-8 input | Today's crash is recorded with `withKnownIssue` until it is fixed on purpose, in a separate tagged commit. |
| 3 | **Object model** | Tree shape after parse (counts per type, step and model structure), `NSCopying` deep copy, `NSCoding` archive round trip (this is the pasteboard format), observer notifications | Structural assertions on the fixtures. |
| 4 | **MatrixMath / geometry** | Compose ∘ decompose ≈ identity for `TransformComponents`; invert; multiply; ray–triangle and ray–box intersection; bounds; `V2PolygonContains`; `ComputationalGeometry` hull and tangents | Table tests plus seeded randomised property tests (fixed seed for reproducibility). |
| 5 | **Snapping and transforms** | `componentsSnappedToGrid:minimumAngle:`, `position:snappedToGrid:`, rotate and move about centres, view-orientation angle mapping | Table tests. |
| 6 | **Colours** | `ColorLibrary` lookup, blended and custom colours, `!COLOUR` parsing, edge colours | Against the fixture `LDConfig.ldr`. |
| 7 | **Paths, library, catalog** | `LDrawPaths` resolution, case-insensitive names, `PartCatalogBuilder` output on the mini library, part descriptions and categories, `MLCadIni` parsing | Fixture library. |
| 8 | **MPD and ModelManager** | Submodel lookup, renaming a submodel updates references, active model, cross-document references | Fixtures. |
| 9 | **Document operations and undo** | Open, then: add part, delete, move, rotate, change colour, add or move step, rename submodel, paste. Each followed by undo and redo | Drive `LDrawDocument` headlessly (no window). Assert that the written text after op, undo and redo matches goldens. Where an operation needs view state, record the gap in TESTING.md; P4 extracts an op layer to close it. |
| 10 | **Preferences contract** | Every defaults key string and default value | Snapshot test, so renamed keys are caught. |
| 11 | **LSynth** | `lsynthcp` on sample hose and band input produces the expected output | Run the bundled binary directly, black box. |
| 12 | **Render snapshots** | Fixed-camera offscreen renders of 5–10 fixtures, both wireframe and shaded | Offscreen `NSOpenGLContext`/CGL into an FBO, compared with a tolerance (per-pixel delta plus a % threshold). These become **the reference images for the later Metal port**. |
| 13 | **Performance** | Parse a large model, collect/draw it, build the part catalog | XCTest `measure` baselines. The Swift port must stay within +20%. Large models come from the optional full library (`.requiresFullLibrary`). |
| 14 | **UI smoke** | Launch; open a fixture; select a part in the outline; inspector shows its values; edit a field; undo; save-as; reopen and compare; open each panel (Preferences, Part Browser, Rotation, Move…) | XCUITest. Kept deliberately thin, because UI tests are slow and flaky. |

- **Coverage target before porting begins:** ≥ 70% line coverage on `Source/LDraw/{Commands,Files,Support}` and ≥ 50%
  on `LDrawDocument`.
- A class whose coverage is below target can't be ported until the gap is closed or written down as an accepted risk in port-status.md.
- **Exit:** every row above has tests, the coverage targets are met or exceptions recorded, and the suite runs in under 3 minutes
  without the full-library tests.

### P3: manual test script and docs (S)
Can be folded into P2. Write the manual smoke checklist (TESTING.md §Manual) for the things automation can't reach well:
- 3D view interaction: rotate, zoom, marquee selection, drag-and-drop from the part browser
- printing and export
- the 3Dconnexion mouse

### P4: ObjC prep refactors, no behaviour change (M)
Branch `…-p4-prep`
- Turn the macros into typed constants (§4.4.4) and remove `USE_BLOCKS` and the `dispatch_group_t` macro hack.
  Parsing either becomes truly concurrent (only if P2 tests stay green and a TSan run is clean) or explicitly serial.
  **Default: explicitly serial.** Concurrency comes back after the port, under Swift concurrency checking.
- Remove `Carbon/Carbon.h` from the prefix header and import it only in the 3Dconnexion shim. Shrink the `.pch` so
  that no Swift-visible header depends on it.
- Add nullability annotations (`NS_ASSUME_NONNULL_BEGIN`) and lightweight generics (`NSArray<LDrawDirective *> *`) to
  every public header, so Swift sees honest types.
- Replace RegexKitLite with `NSRegularExpression` and delete the 2.6k-line file.
- Split `LDrawDocument.m` (6.4k lines) into categories by concern (file I/O, edit ops, selection, undo, menus,
  viewers). Where it's practical, extract a **view-independent edit-operation layer** that the P2 #9 tests can drive.
  Back-fill the test gaps recorded in P2.
- Replace old enum names (`NSOnState` and similar, 38 sites) and `loadNibNamed:owner:` (17 sites) with modern API.
- **Exit:** the gate in §3. Tests and goldens are unchanged.

### P5: leaf utilities and categories → Swift (S)
Categories (as Swift extensions), `StringUtilities`, `BricksmithUtilities`, `MLCadIni`, `TransformerIntMinus1`.
This first, low-risk phase proves out the interop rules, the bridging header and the per-class recipe (§6).

### P6: LDraw model → Swift (XL)
Sub-branches:
- **p6a:** leaf directives (`LDrawConditionalLine`, `LDrawTriangle`, `LDrawQuadrilateral`, `LDrawComment`, `LDrawColor`, `LDrawLSynthDirective`, `LDrawDragHandle`)
- **p6b:** mid-level (`LDrawLine`, `LDrawPart`, `LDrawMetaCommand`, `LDrawTexture`, `LDrawLSynth`, `LDrawStep`, `LDrawMPDModel`)
- **p6c:** roots (`LDrawModel`, `LDrawFile`, `LDrawContainer`, `LDrawDrawableElement`, `LDrawDirective`)

Rules for this phase:
- Port in the order the leaves-first rule dictates. Class names, selectors, NSCoding keys and `write` output stay identical.
- The GL calls inside the model (`LDrawPart` immediate-mode drawing, `glDrawArrays` in `LDrawDirective`) move behind
  the `LDrawRenderer` protocol **in ObjC first** (in P4 or at the start of P6), so that the Swift model has no GL calls.
- Watch the performance baselines (P2 #13) after each class. ARC traffic in Swift parse and draw loops is the most
  likely regression.

### P7: libraries and managers → Swift (L)
`ColorLibrary`, `LDrawPaths`, `LDrawUtilities`, `ModelManager`, `PartLibrary`, `PartCatalogBuilder`, `PartReport`, `ComputationalGeometry`.
- Introduce dependency injection here: the singletons keep their `shared` accessors but take their paths and defaults
  from an injectable environment. Test-only hacks from P1 go away.
- GL texture creation in `PartLibrary` moves behind the renderer seam.

### P8: renderer (still OpenGL) → Swift (L)
`LDrawGLRenderer`, `LDrawGLCamera`, `LDrawShaderRenderer`, `LDrawDisplayList`, `LDrawDataStream`, `LDrawShaderLoader`, `LDrawBDPAllocator`.
- Define Swift protocols `RenderBackend` and `Camera`: protocols with no GL types in their signatures (use `Matrix4`/`simd`).
  The GL classes become one implementation of them, which is where Metal plugs in later.
- Render snapshots (P2 #12) must stay within tolerance.
- Silence OpenGL deprecation warnings centrally with `GL_SILENCE_DEPRECATION`. They are not port regressions.

### P9: widgets, panels, inspectors, and UI modernisation (XL)
Sub-branches by area: widgets and views, inspectors, panels, preferences, part browser, minifig generator.

Replace deprecated UI, preserving layout and behaviour:
- `NSMatrix` → `NSButton` radio groups / `NSSegmentedControl`
- `NSDrawer` (part browser) → split-view sidebar or a panel
- `LDrawColorCell` and `IconTextCell` → view-based table cells
- `AMSProgressBar` framework with its legacy nib → in-app sheet using `NSProgressIndicator`; delete the framework

Other changes:
- Declare UTIs (`UTExportedTypeDeclarations` for ldr/mpd/dat, conforming to `public.plain-text`).
- Keep xibs; there is **no SwiftUI rewrite** in this plan. New small views may use SwiftUI through `NSHostingView` if that's simpler.
- Keep Cocoa bindings (marked `@objc dynamic`) where they work, notably the minifig generator.
- Update the XCUITest smoke tests as controls change. A changed control needs its test updated in the same commit.

### P10: document and application → Swift (L)
`LDrawDocument` (already split in P4), `LDrawApplication`, `BricksmithApplication`, `main.m` → `@main`.
- Keep the 3Dconnexion C/Carbon API in a tiny ObjC or C shim. *Decision for the maintainer:* keep the old SDK or
  drop or replace 3D-mouse support.
- Use the undo `registerUndo(withTarget:)` closures in place of `prepareWithInvocationTarget:`.

### P11: hardening (M)
- Remove all remaining `.m` files and reduce the bridging header to C headers only.
- Switch to **Swift 6 language mode** with complete concurrency checking. Mark UI code `@MainActor` and revisit
  parallel parsing (with TSan).
- Remove Swift-side `@objc` where the ObjC runtime no longer needs it. Keep `@objc(Name)` on anything referenced by
  xibs or archives.
- Rebaseline warnings and update ARCHITECTURE.md to the Swift structure.

## 6. Per-class porting recipe (for humans and agents)

1. Check port-status.md: are the class's dependencies and subclasses ported, and is its coverage at target?
2. If tests are missing, add them **against the ObjC class first**, then commit.
3. Write `Foo.swift` with `@objc(Foo) final class Foo` (not `final` if anything subclasses it), keeping selectors.
   Keep the original algorithms. Idiomatic rewrites wait until after the port.
4. Remove `Foo.m` from the target and delete it. Change ObjC importers from `#import "Foo.h"` to
   `#import "Bricksmith-Swift.h"`. Keep `Foo.h` only while other ObjC headers need an `@class`.
5. Run build, test and the relevant manual checks. Update port-status.md, and make one commit.

## 7. Risks

| Risk | Mitigation |
|---|---|
| Performance regressions in parse and draw loops (ARC retain/release, bridging `NSArray`) | Perf baselines with a +20% budget; keep C structs; use `ContiguousArray`; profile with Instruments before optimising |
| Behaviour drift in the `write` output (float formatting) | Golden round-trip tests; keep `outputStringForFloat:` semantics byte-identical |
| Archive and pasteboard incompatibility | `@objc(Name)` names; NSCoding round-trip tests using archives produced by the ObjC build |
| Hidden dynamic dispatch (`respondsToSelector:` ×74, `performSelector` ×12, informal protocols) | Convert informal protocols to formal `@objc protocol`s in P4; grep check during each port |
| Hosted tests fighting app startup | P1 test-mode guard |
| Headless document tests infeasible for some ops | P4 op-layer extraction; record remaining gaps explicitly |
| OpenGL rendering differs between machines | Tolerance-based snapshots; record the reference machine |
| LSynth `NSTask` under a future sandbox | Out of scope; noted for the hardening and distribution work |
