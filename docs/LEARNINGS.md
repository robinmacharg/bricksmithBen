# Learnings log

Mistakes we've made, gotchas we've hit, and facts we've confirmed during the Swift port. **Read this before
starting work, and add to it the moment something bites**: one entry per lesson, newest at the bottom of its
section. Each entry says what happened and what to do instead.

## Index by topic

Entries are numbered in the order they were learned; the numbers are cited elsewhere and never change. Read the
topics that match your task rather than the whole log.

| Topic | Entries |
|---|---|
| Shell, git, scripts | L1-L4, L22, L51, L74, L81, L83, L84, L89, L96 |
| Build and warnings | L5-L10, L20, L21, L66, L84, L86, L90 |
| Xcode project editing | L11, L12 |
| App facts, preferences, LDraw library | L13-L16, L27, L28, L33, L35, L53 |
| Swift/ObjC interop | L19, L23, L24, L26, L36, L38, L40, L45, L49, L55, L63, L72, L76, L86, L87, L91, L92, L95 |
| ARC | L54, L67, L77, L79, L88 |
| Writing tests | L25, L29, L31, L32, L37, L42, L43, L46, L47, L57-L62, L71, L85 |
| Rendering, GL and snapshots | L64, L70, L73, L78 |
| Performance | L65 (and the noise band in TESTING.md "Rules", performance tests) |
| UI tests and manual smoke | L34, L68, L80, L82 |
| Diagnosing a surprise | L30, L39, L41, L44, L48, L50, L56, L69, L82, L94 |
| Agents and review | L17, L18, L75, L85, L93; [PARALLEL-AGENTS.md](PARALLEL-AGENTS.md) |

## Shell and git
- **L1. A pipe hides failures.** `scripts/build.sh | tail -2 && git commit …` committed after the build had
  failed: zsh returns the exit status of `tail`. → Run `setopt pipefail` first, or don't pipe a command whose
  exit status matters.
- **L2. `git add -A <dir>` picks up stray files.** It committed the untracked `Source/LDraw.zip` backup (since
  amended out and gitignored). → Stage explicit paths, or use `git add -u` for tracked files, and check
  `git status --short` before committing.
- **L3. BSD `sed` flag order.** `sed -e … -e -E …` fails ("invalid command code -"). → Put `-E` first:
  `sed -E -e … -e …`. For in-place editing use `sed -i ''`.
- **L4. `bundle exec` rewrites `Gemfile.lock`** by adding the host platform (`arm64-darwin-24`). That's harmless,
  so commit it rather than reverting it every time.

## Build
- **L5. Incremental builds hide compiler warnings**, so the warning baseline fell from 75 to 3. →
  `scripts/build.sh` always runs `clean build`.
- **L6. Release reports diagnostics that Debug doesn't** (`-Wuninitialized`, `-Wreturn-type`), and two of them
  were real bugs (S10, S11). → Each configuration has its own warnings baseline. Read new Release-only
  warnings as possible bugs.
- **L7. Raising the deployment target exposes hidden deprecations** (75 → 137 warnings). → Re-record the
  baseline deliberately, and say why in the commit message.
- **L8. Carbon in the pch was quietly supplying the C standard headers** (`math.h`, `assert.h`, `stdio.h`, `size_t`)
  to the `.c` files. → The pch now imports `ApplicationServices`. Making headers self-contained (P1) is the real fix.
- **L9. Code signing rejects data files in `Contents/MacOS`** (`lsynth.mpd` was there). → Put data in
  `Resources` and pass paths explicitly.
- **L10. Adding the first Swift file turns on generated asset-catalog symbols**, and asset names like `ArrowE+`
  and `ArrowE` collide. → `ASSETCATALOG_COMPILER_GENERATE_ASSET_SYMBOLS = NO` on the app target.

## Xcode project editing (Ruby `xcodeproj` gem, `bundle exec` in `trunk/Bricksmith`)
- **L11. `find_subpath('A/B', true)` creates groups that have no `path`**, so file refs resolve to the wrong
  place ("Build input file cannot be found"). → Set `path` **only on groups you've just created**. Never set
  `path` on an existing group, because that relocates every child. Afterwards, check that every new ref's
  `real_path` exists.
- **L12. Keep project-editing scripts small and idempotent**: find the thing, or create it if missing. Run
  `plutil -lint` on the pbxproj and do a full build after each edit.

## App facts (confirmed)
- **L13. The LDraw folder preference key is `"LDraw Path"`, with a space** (`MacLDraw.h:35`). A `-LDrawPath`
  launch argument does nothing. Tests inject the path through an override hook instead.
- **L14. Launch work that documents depend on:** the shared GL context and the Inspector are created in
  `applicationWillFinishLaunching:`, and `readFromData:` locks that context. So the test-mode guard must keep
  them.
- **L15. The bundled `lsynthcp` looks for `lsynth.mpd` next to its own executable** unless it's given `-c`.
- **L16. This machine's real LDraw library is at `/Applications/Bricksmith/ldraw`.** Read it; never modify it.

## Process
- **L17. Check subagent and reviewer claims before acting on them.** A fact-check found wrong selectors, keys,
  counts and class hierarchies in documents that had already been reviewed once.
- **L18. If a file was changed with shell tools, `Read` it before using the `Edit` tool on it.** Otherwise the
  edit is refused.
- **L19. Swap spike PASSED (2026-11-14, branch `spike/20261114-swap-transformer`).**
  - What was ported: `TransformerIntMinus1` → Swift `@objc(TransformerIntMinus1)`, with its `.h`/`.m` deleted and the
    ObjC caller (an MRC file) switched to `#import "Bricksmith-Swift.h"`.
  - Result: the unchanged test file compiled and passed.
  - Takeaways: the single bridging header plus `@testable import` works. ValueTransformers registered by name
    keep working from xibs.
- **L20. Gate on `scripts/build.sh`'s exit status. Don't hand-roll a check.** I once printed a `comm` count and
  committed anyway, even though there was one new warning. → Use `scripts/build.sh && git commit …` (with
  `pipefail`).
- **L21. Adding a header to the bridging header can surface its deprecations again** (Swift's Clang importer
  compiles it in a new context). An example is `NSDrawer` in `LDrawDocument.h`. → Expected. Re-record the baseline
  deliberately and say so in the commit.
- **L22. BSD `sed` has no `\s`.** It matches a literal `s`, which silently ate every letter "s" from the output.
  → Use `[[:space:]]` (or Python for anything non-trivial).
- **L23. A plain C `typedef enum` is 4 bytes with `@encode` `"i"`, even when every value is non-negative.**
  `NS_ENUM(int, …)` keeps exactly that (verified), whereas `NS_ENUM(NSInteger, …)` changes it to 8 bytes `"q"`,
  which breaks struct layout, `encodeBytes:`, NSValue archives and KVC. → Always use `NS_ENUM(int, …)` or
  `NS_OPTIONS(int, …)` when converting.
- **L24. Converting `#define` string constants: verify mechanically, and watch for composed macros.**
  - Method: compile a dump program that prints every name and value against the old headers, then compile it
    against the new `extern` constants plus their `.m`, and `diff` the outputs. 175 constants came out identical.
  - Composed macros such as `LDCONFIG @"." LDCONFIG_EXTENSION` aren't simple literals, so a regex converter skips
    them, and the build then fails wherever they're used. → Convert them by hand and verify them against the old
    header recovered with `git show HEAD:<path>`.
- **L25. Exit tests work hosted.** `await #expect(processExitsWith: .failure) { … }` runs the body in a child
  process that relaunches the test host in test mode. App ObjC code is reachable there, and a crash fails only
  that expectation. Each exit test costs about 1–1.5 s, so use them sparingly. The body can't capture local
  state: pass data via files or the environment.
- **L26. "Insert before the last `@end`" can land inside a protocol.** Some headers declare a `@protocol` after the
  class (`PartLibrary.h` → `PartLibraryDelegate`), so a new method silently became a required protocol method. The
  warning gate caught it as `-Wprotocol`. → When inserting declarations, find the `@end` that closes
  `@interface ClassName`, not the last `@end` in the file.
- **L27. `-[LDrawPaths setPreferredLDrawPath:]` already lets tests redirect the LDraw folder.** It only sets an
  ivar; the real preference is read only in `init`. So no new override API was needed.
- **L28. Debug builds share preferences with the installed Bricksmith** (both use `com.AllenSmith.Bricksmith`).
  The installed 3.1.0 is newer upstream code than this source and stores colours in a format this code can't read
  (BUG-002). → Debug builds should have their own preferences domain. Never let a dev build write the user's
  real preferences.
- **L29. AppKit silently swallows exceptions raised in action methods**, so the only symptom is that nothing
  happens, and `NSLog` output from a GUI launch doesn't reach the unified log. → Launch the binary from a
  terminal with stderr captured. Attach `lldb` (Debug builds aren't hardened) and inspect `[NSApp windows]`, then
  confirm suspicions with a tiny standalone program.
- **L30. `lldb --batch` stops at the first command that errors**, including an `expr` interrupted by a breakpoint,
  even with `stop-command-source-on-error false`. → Use separate lldb runs, or reproduce outside lldb.
- **L31. `xcodebuild test` can return while the test-host app is still terminating**, and AppKit writes autosave
  state on the way out. A preferences snapshot or restore taken straight away races with it. → `scripts/test.sh`
  waits for the host process to exit first.
- **L32. Exit-test children don't get `XCTestConfigurationFilePath`.** Swift Testing relaunches the host with
  `SWT_EXIT_TEST_ID` instead, so the app did a **normal** launch in them: LDraw discovery, catalog load, and a
  modal "LDraw folder not complete" alert once the dev domain had no path, which hung the run. It only looked
  fine before because the shared real preferences held a valid path. → `+isRunningTests` also checks
  `SWT_EXIT_TEST_ID`, and `HarnessExitTests.childIsInTestMode` guards it.
- **L33. Separating domains can expose leaks that a shared domain was hiding.** AppKit table and split-view
  autosave, plus Sparkle's `SUHasLaunchedBefore`, were always written by test runs, but with the same values
  already present the guard saw no change. → The dev/test domain is restored after every run; the real domain is
  strictly guarded.
- **L34. Don't use the fixture files as working documents in manual testing.** Saving rewrites them (BOM dropped,
  `0 FILE` name changed, spacing normalised). → Open a temp copy, and restore with `git checkout` if one is saved.
- **L35. Sparkle's "Check for updates automatically?" prompt is modal and appears on a second launch** when
  `SUEnableAutomaticChecks` is undecided. Test runs relaunch the app all the time (hosts, exit-test children),
  so it could hang a run. → In Debug, `updaterShouldPromptForPermissionToCheckForUpdates:` returns NO; Release is
  unchanged. Any perf scheme built from Release needs the same treatment.
- **L36. Typedef'd pointers are invisible to a `*`-based scan.** A `dispatch_group_t` parameter (here a macro for
  `void *`) went unannotated, so `NS_ASSUME_NONNULL` silently made it `nonnull`, and a caller passing `nil` drew a
  new `-Wnonnull` warning. That's exactly the hazard the explicit `null_unspecified` rule exists for. The warning
  gate caught it. → `scripts/dev/annotate-unspecified.py` also treats `dispatch_*_t` and `…Ref` as pointers. Treat
  any new `-Wnonnull` warning as a wrong annotation.
- **L37. `.serialized` only orders tests within one suite; separate suites run concurrently.** Suites sharing
  Bricksmith's singletons reset each other mid-test: the fixture path came out nil and the colour marker was
  missing. → The `.fixtureLibrary` trait takes a process-wide async FIFO lock (`GlobalStateLock`), so every test
  that touches global state runs alone.
- **L38. Swift doesn't strip a leading "class" from ObjC selectors.** `+classForDirectiveBeginningWithLine:`
  imports as `classForDirectiveBeginning(withLine:)`. If unsure of an imported name, let the compiler tell you
  rather than guessing.
- **L39. Golden review finds real bugs.** Diffing each fixture against its recorded golden surfaced two data-loss
  bugs (BUG-003, BUG-004) on the first pass. → Always review golden diffs line by line before the review gate;
  never just accept a recording.
- **L40. Swift imports an ObjC class factory named after its class (`+[LDrawFile file]`) as `init()`.** That
  collides with the inherited `-init`, and `LDrawFile()` silently called plain `-init`, giving a file with **no
  model**. → Pin factories with `NS_SWIFT_NAME(file())` when their header is annotated. Expect the same with
  `+[LDrawMPDModel model]`, `+[LDrawStep emptyStep]` and similar.
- **L41. Form a bug hypothesis from code reading, then let the test decide.** Reading the code predicted that
  "1e14 is written as "1"", but `Float(1e14)` is `100000000376832`, which fits the buffer. The real failures were
  -1e14 and 1e20. Likewise, the suspected RGB truncation was disproved by checking all 768 values. Swift Testing
  reports "Known issue was not recorded" when an expected failure passes, so keep each known-issue test to the
  cases that actually fail.
- **L42. Exit-test capture lists aren't available in this Swift Testing** ("Cannot specify a capture clause").
  → To find which input crashes, run all cases in one child, write each case name to a progress file first, and
  have the parent read the file after a crash. Then **confirm each crasher in isolation**: heap corruption can
  surface in a later case than the one that caused it.
- **L43. Swift Testing `--only` identifiers need the parentheses** (`Suite/test()`). Without them, zero tests run
  and the run still "passes". → Prefer suite-level `--only`, and check the "N tests" count.
- **L44. Ask the spec, not memory.** The local LDraw spec copies (`docs/reference/ldraw-spec`) turned two
  suspicions into confirmed bugs (BUG-009 TEXMAP, BUG-010 encoding). They also showed `0x4` codes are not in the
  spec. → Check `AGENT-NOTES.md` before calling LDraw behaviour right or wrong.
- **L45. Block typedefs hide pointers too** (`LDrawPartVisitor`). → `annotate-unspecified.py` now collects every
  block and pointer typedef in the app's headers and treats those names as pointers.
- **L46. Characterise both modes of mode-dependent behaviour.** Parsed trees don't post notifications; a document
  turns them on (`setPostsNotifications:YES`). Testing only the default mode would have recorded "nothing
  happens", which isn't what the app sees.
- **L47. Put a readable diff in every equality assertion** (`Golden.firstDifference`, or `before -> after`). The
  first BUG-011/BUG-012 failures said only "Expectation failed"; the diagnostics found both bugs in one rerun.
- **L48. Read a C helper's units before testing it.** `V3AntiEuler` takes and returns degrees because it calls
  `Matrix4Rotate`, but I tested it with radians. And `FloatsApproximatelyEqual` allows about 5 ULPs, not a
  decimal tolerance. Two of three "failures" in row 5 were mistakes in my tests; the third (BUG-014) was
  confirmed with a standalone C program before being logged.
- **L49. NS_ENUM prefix stripping is literal.** `ViewOrientationT` with cases `ViewOrientationFront…` imports as
  `.orientationFront`: the trailing `T` stops `ViewOrientation` from matching, so only `View` is stripped. If a
  nicer spelling is wanted, add `NS_SWIFT_NAME` **before** tests use the enum (it's a Swift-spelling change).
- **L50. Check the doc comment before calling a surprise a bug.** Position snapping put Y on 8/24 LDU, not the
  10/20 grid. That's documented design (brick and plate heights along the part's Y axis), so the test now encodes
  the documented rule.
- **L51. A heredoc ends an `&&` chain.** In `cmd && python3 - <<'EOF' … EOF` followed by `git commit` on the next
  line, the commit runs regardless of `cmd`'s status, and a failed build gate got committed. → Put the gate on
  the same line as the commit (`scripts/build.sh && git commit …`) or use `|| exit 1`. Also, C prototypes after
  a class's `@end` need nullability too; the annotator now handles `extern` prototypes.
- **L53. Some code reads the "LDraw Path" preference directly** (`PartCatalogBuilder` creates its own
  `LDrawPaths`), so overriding the shared instance isn't enough. → The `.fixtureLibrary` trait also sets the path
  in the volatile `NSArgumentDomain`, which outranks persistent domains and is never written. Exit-test children
  don't inherit it, so they must set it themselves.
- **L54. When a crash appears in a file the in-progress ARC edit touched, diff that edit first**
  (`git show af3483f -- <file>`). BUG-015 was a removed `retain`/`autorelease` pair around a local
  `NSAutoreleasePool`, in a file that still compiles with manual retain/release. The decisive experiment was
  "call it exactly as the app does": it still crashed, so it was real.
- **L55. For ObjC `NSString **` out-parameters, pass `&optionalVar` from Swift.** Hand-building an
  `AutoreleasingUnsafeMutablePointer` from `withUnsafeMutablePointer` skips Swift's write-back and over-releases
  the returned object, which crashed the test host. Zombies (`TEST_RUNNER_NSZombieEnabled=YES`) and running each
  test in isolation pinpointed it as a test bug, not an app bug.
- **L56. Call APIs with the arguments the app actually passes.** `-[ModelManager requestModel:…]` "failed" for
  `"A.ldr"`, but the app always passes the lower-cased `referenceName`. Before calling something a bug, find the
  app's real call site.
- **L57. An NSException on a Swift Testing thread doesn't fail the test. It hangs the whole run** (AppKit's
  handler swallows it and the task never finishes). → `BricksmithTestSupport +catchException:` (test-support ObjC
  in the app) plus `ObjC.run { … }` turn it into a reported failure. Also, `makeWindowControllers()` doesn't load
  the nib: touch `.window`, or the outline view has no rows and selection throws.
- **L58. A never-shown window gives views degenerate geometry.** The focus-ring `OverlayHelperWindow` then
  computed an out-of-range frame, and AppKit asserted from a run-loop observer, which no test code can catch.
  → The harness orders the window in with `alphaValue = 0` and a fixed frame, and `LDrawGLView` skips the
  focus-ring overlay in test mode (purely visual; manual checklist).
- **L59. Check undo by comparing bytes, not just "looks right".** Exact before/after comparison showed that
  undoing a rotation applies the inverse transform (float drift, `-0`): BUG-016. A numeric-tolerance check is
  kept alongside, so a genuinely broken undo is still caught.
- **L60. When logic is trapped in UI code (a save-panel completion block), mirror it in the test line for line and
  cite the source.** Record a P4 task to extract it, so the mirror can't drift for long. The mirror is how BUG-011's
  real user impact (backwards Export Steps files) was confirmed. *(P4: extracted into `-exportStepsToURL:`; the
  mirror is gone.)*
- **L61. Never put Foundation `-description` output in a golden.** Its formatting of nested collections can change
  between OS versions. → Serialise to compact sorted JSON (`JSONSerialization` with `.sortedKeys`).
- **L62. Private ObjC actions can be driven from tests by selector** (`perform(NSSelectorFromString("generateMinifigure:"))`)
  inside `ObjC.run`, mirroring the order the app calls them (`restoreFromPreferences` first, as `-runModal` does).
- **L63. `NSNotificationName` constants import as `NSNotification.Name` members with the `Notification` suffix
  removed** (`LDrawColorDidChangeNotification` becomes `.LDrawColorDidChange`), so generated Swift must use that
  spelling. Also, the registration domain mixes in system keys (`Apple*`, `NS*`, `METAL_*`, `XCT*`) and keys that
  views register lazily. Filter those out of goldens, or the golden depends on the machine and on test order.
- **L64. Capturing a GL view in tests:** `display()` alone produced a black capture. What works is to call the
  view's `-draw` with its context current, then `glReadPixels` from the back buffer (the window can stay fully
  transparent). `glReadPixels` is bottom-up, so flip the image for humans. `zoomToFit:` misbehaves before layout
  settles; a fixed zoom plus `scrollCenterToModelPoint:` (the model's bounding-box centre) gives stable framing.
- **L65. Benchmarking on a working desktop:** medians of millisecond timings varied from 44% to 121% between
  identical runs, which made a +20% gate useless. → Make the workload large enough for timings in the 10–250 ms
  range, warm up first, and take the **minimum** of N runs (interference only adds time). After that, re-runs were
  within ±16%. Remember `glFinish()` when timing GL, or you only measure command submission.
- **L66. A new build configuration must exist in every sub-project** (AMSProgressBar, LSynth). Otherwise they
  build under their default configuration into a different products folder, and the app can't find their
  headers. The `xcodeproj` gem's `add_build_configuration` fails when targets differ in deployment target; create
  `XCBuildConfiguration` objects by hand.
- **L67. A test-mode guard can leave an MRC object without an owner.** Skipping `addOverlayView:` in test mode
  (L58) left `focusRingView`, which is only autoreleased, with no owner. The first focus change in a UI test then
  messaged a freed object. To XCUITest this looked like a 35 s hang followed by "application is not running": the
  Swift runtime's backtracer was writing a crash report. → When a guard skips the call that retains something,
  nil the reference too. When a UI test "hangs", `sample` the app process before guessing.
- **L68. XCUITest on this AppKit app.** Probe the tree (`app.debugDescription`) rather than guessing names (L38):
  - NSPanels (Parts Browser, Preferences) are **Dialogs**, not Windows.
  - Outline rows report "not hittable"; click them by coordinate.
  - Menu items have only `_NS:` identifiers, and titles change with state ("Undo Duplicate"). macOS 13+ also
    retitles "Preferences…" to "Settings…". Match by title prefix.
  - Opening Preferences runs a modal "Choose LDraw Folder" panel when the `"LDraw Path"` default is unset. So pass
    `-"LDraw Path" <copy>` as a launch argument (volatile argument domain), as well as the environment variable.
  - Save-panel paths go through Cmd-Shift-G plus `typeText(path + "\r")`.
- **L69. Check that code is live before you write tests for it.** I wrote ray-picking goldens for `-hitTest:...`.
  Its only caller, `getDirectivesUnderPoint:`, is never called, and the fixed-function `draw:`/VBO chain is compiled
  out by `NEW_RENDERER 1`. → Before covering a method, trace a caller back to an action, a xib or the run loop.
  Check `@selector(`, `NSSelectorFromString`, the xib action names and Swift, not just a source grep (note that
  `grep` here is ugrep, and `--include` works differently: use `command grep`). Dead code goes in
  `docs/coverage-ledger.tsv` with the evidence. It is not deleted in P2.
- **L70. Some model calls need a current GL context, even in "pure model" tests.** Creating an `LDrawDragHandle`
  (which `setSelected:YES` does for primitives) builds a sphere mesh with `glGenBuffers`. Drawing an
  `LDrawTexture` asks PartLibrary for a GL texture name. With no current context, both crash (SIGSEGV in
  libGL). → Use `OffscreenGL.makeCurrent()` (`Tests/Unit/DrawingTests.swift`) in suites that select or draw.
  *(Since P4 the drag handle builds its sphere only on the dead legacy `draw:` path, so selecting no longer needs
  GL; drawing a texture still does.)*
- **L71. Parse snippets with a header.** A file whose first line is `0 something` takes that line as the model's
  title, so a comment or meta-command under test disappears from the steps. `Prim.parse` prepends
  `0 Primitive` / `0 Name:` / `0 Author:` lines.
- **L72. Annotate a header in the commit that first tests it, even when the test reaches it indirectly
  through a helper.** Commits `029061e` and `b264d6f` tested LDrawLine, LDrawTriangle, LDrawQuadrilateral,
  LDrawConditionalLine, LDrawTexture, LDrawDragHandle and LDrawRenderer directly, without annotating them. They
  were caught up later. The annotator also mis-handled typedef'd pointers taken by address (`LDrawDLHandle *`
  is `void **`) and function-pointer typedefs. It now handles both. A function-pointer typedef's own
  parameters still need annotating by hand.
- **L73. Render snapshots must fix their own geometry.** When the main display changed to the built-in Retina
  screen, captures came out at 2x. Even at 1x, the GL viewport followed the split-view layout, which comes from
  divider positions autosaved in the debug defaults domain (636x702 against 625x691). → `DocHarness.open` turns off
  `wantsBestResolutionOpenGLSurface` before the window is first shown. `RenderHarness` sizes the
  `LDrawViewerContainer` and the view to 625x691 after `display()`, then calls `reshape` and re-centres. References
  were re-recorded with this harness on 2026-11-15; the renders are the same, offset by a few pixels.
- **L74. Never chain a commit after a test run with `;`.** Commit `06ba93d` went in while 8 render tests were
  failing (the L51 mistake again). Use `&&` from the test command to the commit, with `setopt pipefail` and a
  grep that fails on failure, or check the result first and commit in a separate call.
- **L75. Parallel agents in worktrees (learned from the P2 coverage work):**
  - Worktrees started on an old commit (`b19a8ab`), not the current HEAD. Each agent had to `git reset --hard` to
    the base. → Tell agents the base commit explicitly, and check it.
  - Register placeholder test files in the target first, so agents never edit `project.pbxproj`. Their commits then
    cherry-pick cleanly.
  - Concurrent `scripts/test.sh` runs share the debug defaults domain (snapshot/restore races). Autosaved
    window/split-view state then drifts between runs, which made render geometry unstable (L73).
- **L76. Swift gotchas from the same work:**
  - `.first as? T` on an imported `NSArray`/`NSMutableArray` resolves to `first(where:)`, so the cast silently
    fails, with only a warning. Use `firstObject`, or cast to `[Any]` first.
  - `NSTableView.style = .plain` gives deterministic row geometry; the default style adds OS-dependent padding.
  - Undeclared or deprecated ObjC methods can be called through `method(for:)` plus `unsafeBitCast` to a
    `@convention(c)` type.
  - Test preferences through the volatile argument domain, never a persistent domain.
  - Read private outlets by KVC name only where necessary. The port must keep those names (listed in
    `AppLogicCoverageTests`).
- **L77. ARC conversion with ARCMT (P3).** Xcode 26's clang still contains Apple's ARC migrator, behind
  `-Xclang -arcmt-action=modify`; the `-ccc-arcmt-*` driver flags are silently ignored. `scripts/dev/arcmt-migrate.py`
  runs it with each file's real compile command. Review every diff, because ARCMT gets some things wrong or doesn't
  decide them:
  - It rewrites MRC `__block Foo *x = [[Foo alloc] init]` as `__weak`, which is **nil at once** under ARC. Make it
    a plain strong local (`__block` only if the variable itself is reassigned inside the block).
  - Plain object ivars become `__strong`. Back-pointers (parent, delegate, owner) that were deliberately unretained
    under MRC need `__weak` or `__unsafe_unretained`, or they form retain cycles.
  - `unsafe_unretained` properties that were assigned `[[X alloc] init]` and then released by hand: make them
    `strong` and drop the release.
  - The legacy `+[NSBundle loadNibNamed:owner:]` retains top-level objects. MRC code balanced that with
    `autorelease`/`release`; under ARC that's no longer possible, so those objects leak (S36) until P4 moves to
    `loadNibNamed:owner:topLevelObjects:`.
  - `[self autorelease]` (singletons that drop themselves when their window closes): use an `__autoreleasing`
    local to keep the same lifetime.
- **L78. A black render snapshot doesn't by itself mean the change broke rendering.** During P3, all-black captures
  came and went across identical configurations: the same tree failed, then passed minutes later. A bisect chased
  that noise. The likely cause is the transparent harness window not being visible (another Space, or behind a
  full-screen app). → The render test now records the window's occlusion state and skips, with a message, when the
  capture is uniform *and* the window wasn't visible. Before bisecting a render failure, rerun it on the last good
  commit.
- **L79. Under ARC, *when* a release happens can be behaviour.**
  - `LDrawShaderRenderer` does its real drawing in `dealloc`. ARCMT removed `[ren release]`, so the renderer now
    lived to the end of the method, after GL-state asserts, and they aborted. → Set the variable to `nil` where the
    release used to be.
  - `IBOutlet` ivars are not retained by nib loading under MRC, but they are **strong** under ARC. LDrawDocument's
    strong outlets kept a closed window's views alive until the document went away. The views were then torn down
    during another window's display cycle ("Collection was mutated while being enumerated" in
    `NSViewUpdateVibrancyForSubtree`). → Bare outlets become `IBOutlet __unsafe_unretained`, matching MRC; NSDrawer
    and some other AppKit classes can't be weakly referenced. The exceptions are outlets the original code retained
    itself and released in `dealloc` (DocumentToolbarController's tool views): they stay strong.
- **L80. A Debug build can draw differently from a release build of the same code, on the same Mac.** The P3 manual
  smoke found black and yellow panels (BUG-033). They came from views that fill their dirty rect instead of their
  bounds. The pre-port snapshot drew them correctly under the release bundle id and wrongly when built with
  `com.AllenSmith.Bricksmith.debug`; preferences, window position and displays were ruled out. → When a UI symptom
  appears, A/B the *same bundle id* before blaming a commit, and fix the drawing code rather than relying on it.
  Related traps found on the way:
  - Commits before `50b795b` (including tag `snapshot-20261114-pre-swift-plan`) build with the **real** bundle id
    and write the user's real preferences when launched. Build them with
    `PRODUCT_BUNDLE_IDENTIFIER=com.AllenSmith.Bricksmith.debug`, or back up and restore the real domain.
  - `defaults import` **merges** into a domain; it does not replace it. To restore, `defaults delete` the domain
    first (or delete the keys the run added), then diff against the backup.
  - UI-scripting a click (System Events) on a button inside an `NSApp runModalForWindow:` session did not trigger
    its action here; drive modal dialogs from tests by calling the action directly.
- **L81. `comm` and `sort` are locale-sensitive.** `build.sh` reported "NEW WARNINGS" that were identical lines: the
  baseline was sorted in one collation and compared under another. → Pin `LC_ALL=C` on both `sort` and `comm`
  (`1f4b6b1`). Apply this to any script that compares sorted text.
- **L82. Read the code and diff it against master before building an A/B harness for a smoke "anomaly".** Two P3
  reports turned out to be designed behaviour, provable from the source in minutes:
  - Randomize Colors only shuffles colours already in the selection, so one colour gives no change.
  - In Steps view, earlier parts shift slightly when a step adds parts further away. `-[LDrawModel boundingBox3]`
    counts only the steps shown, and `-[LDrawGLCamera tickle]` puts the camera at 6.5 × (bounds radius + 40), so
    the perspective changes.
  If `git diff master` shows no logic change in the code involved, the behaviour isn't a port regression. Record it in
  TESTING.md so the next smoke run doesn't flag it again.
- **L83. Merging a phase to master.** The phase branch is cut from the previous phase's *branch tip*, so it doesn't
  contain master's merge commit or its version bump (the branch's `Info.plist` still shows an older version).
  → `git merge --no-ff --no-commit <branch>` on master; set both `CFBundleShortVersionString` and `CFBundleVersion`
  in the merge; run `scripts/build.sh`, `scripts/build.sh --release` and `scripts/test.sh --ui` on the merged tree;
  only then commit, with the gates in the message. Cut the next branch from master, not from the old branch.
- **L84. In a worktree under `/tmp`, Xcode logs `/tmp/...` paths but `${0:A}` resolves to `/private/tmp/...`.**
  `build.sh` then reported every warning as new (fixed in `e368875` by stripping both spellings). → When a script
  compares tool output against paths it computed, normalise symlinked prefixes on both sides.
- **L85. Agent lessons from P4 stream C:**
  - Check a value-transformer registration through `NSValueTransformer.valueTransformerNames()` in a fresh child
    process, before any lookup: a lookup by name instantiates and registers a class of that name itself.
  - Opening a document renames extensionless models to `*.ldr` (`-doMissingModelnameExtensionCheck:`), so document
    output and parsed-file goldens differ in model names.
  - An injected random source for Randomize Colors must not return a constant: its retry loop never ends.
- **L86. Adding one nullability annotation to a header outside `NS_ASSUME_NONNULL` triggers
  `-Wnullability-completeness` for the whole header.** Leave new methods unannotated like their neighbours, or
  annotate the whole header in its own commit.
- **L87. A catch-all `@try` also swallows Foundation raises, so a clean `@throw` grep doesn't mean no NSException can
  reach Swift.** P4 stream A found calls inside parse-path `@try`s that raise on bad input: `scanQuotableToken:`
  with no token (`appendString:nil`), `objectAtIndex:` used as control flow in `parseHeaderFromLines:`,
  `insertObject:nil` when a child init returns nil, `objectAtIndex:0` in `readModelAtPath:`, and
  `pathForPartName:nil`. → Before removing a `@try`, list every call inside it that can raise, and guard each one
  explicitly. The §6 recipe grep is necessary, not sufficient.
- **L88. `-[NSBundle loadNibNamed:owner:topLevelObjects:]` does not keep the top-level objects alive; the legacy
  `+loadNibNamed:owner:` retained (leaked) them.** With bare outlets `__unsafe_unretained` (L79), switching without
  keeping the array frees windows still in use (the Inspector crashed with signal 11 in the negative control).
  → Keep the returned array in a strong ivar on the owner. Objects that leaked before are now freed with their
  owner, which is a lifetime change: pin it with a test that drains an autorelease pool and then touches the objects
  (`NibLifetimeTests`).
- **L89. Shell and Swift gotchas from P4 stream B:**
  - A `pgrep -f "<pattern>"` wait loop matches its own command line and never ends. Wait on a log line instead.
  - A local named `type` in a Swift test hides `type(of:)`.
  - In a `@MainActor` suite, `arguments:` data needs `nonisolated static let`.
  - `(?:SHOW|HIDE)` matches `HIDES` but not `HIDDEN`: write regex tests against the old implementation first.
- **L90. xcodebuild's log can interleave parallel compiler output mid-line.** A warning once appeared as
  `s/trunk/Bricksmith/...` (its path prefix cut off by another line), so `build.sh` reported it as new. → If a "new"
  warning has a mangled path, check `build/build.log` for the same warning with a full path and rerun the build.
- **L91. An ObjC property whose type is only `@class`-forward-declared is silently dropped from Swift**, and the app
  build stays green. P4 found `toolbarController` and `fileContentsOutline` missing that way. → Import the type's
  header in the bridging header, and probe new API with real Swift code.
- **L92. To find every outside reader of a class's ivars in one pass,** move the ivar blocks into the `.m`, then
  re-run each file's compile command from `build/build.log` with `-fsyntax-only -ferror-limit=0` (xcodebuild stops
  at the first failing file). Revert the experiment afterwards.
- **L93. macOS clears `/private/tmp` on restart.** A reboot during the P4 split wiped the agent's worktree (under the
  session scratchpad) with ~30 minutes of uncommitted work, plus the scratch tools and the test lock. The main
  checkout was untouched; `git worktree prune` cleaned up. → Put worktrees and the test lock under the repo's ignored
  `build/` (`build/worktrees/`, `build/test.lock`), and have agents commit each gated step at once.
- **L94. When converting "throws" to "returns nil", nil usually already meant something else.** The BUG-007
  conversion treated any nil model from an existing part file as a parse failure. A zero-byte file, an unreadable
  file or a directory also give nil, so those documents stopped opening (fixed in `4e4fce2`; found by adversarial
  review, not by tests). The pin tests had covered only the failing input and a good control. → Before giving nil a
  new meaning, list every existing way to get nil there, and pin each one. Carry an explicit flag
  (`parseFailed:`) rather than inferring failure from nil.
- **L95. Splitting an ObjC class into categories (P4 `LDrawDocument`):**
  - A method declared in the primary `@interface` but implemented only in a category warns
    `-Wincomplete-implementation`; move its declaration into a matching category `@interface`.
  - Methods declared in a class extension can't be implemented in a category; private cross-file declarations need
    their own named category (`(ViewersInternal)`), since reusing the public category name duplicates it.
  - Category files can't see ivars synthesized in the core `.m`: declare them explicitly in a private header's class
    extension and keep `@synthesize name = name;` in the core. An explicit ivar of a deprecated type (`NSDrawer`)
    warns where the synthesized one didn't.
  - Prove the move: compare the multiset of non-blank lines before and after, and diff `nm` method symbols (strip
    category names and block numbering, which the compiler renumbers).
  - L90 has a second form: a log line cut at its end rather than its path.
- **L96. Rewriting history breaks every commit hash the docs and messages cite.** Removing attribution trailers
  from the P4 branch renumbered all 67 commits. → Rewrite in one `filter-branch --msg-filter` pass that also maps
  quoted hashes through `map` (`build/msgfilter.sh` pattern), then update the tip's docs from an old→new table
  built by pairing `rev-list --reverse` of the backup and the rewritten branch (check the subjects match). Keep a
  backup branch until the merge.
