# Learnings log

Mistakes we've made, gotchas we've hit, and facts we've confirmed during the Swift port. **Read this before
starting work, and add to it the moment something bites**: one entry per lesson, newest at the bottom of its
section. Each entry says what happened and what to do instead.

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
  real user impact (backwards Export Steps files) was confirmed.
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
- **L71. Parse snippets with a header.** A file whose first line is `0 something` takes that line as the model's
  title, so a comment or meta-command under test disappears from the steps. `Prim.parse` prepends
  `0 Primitive` / `0 Name:` / `0 Author:` lines.
- **L72. Annotate a header in the commit that first tests it, even when the test reaches it indirectly
  through a helper.** Commits `029061e` and `b264d6f` tested LDrawLine, LDrawTriangle, LDrawQuadrilateral,
  LDrawConditionalLine, LDrawTexture, LDrawDragHandle and LDrawRenderer directly, without annotating them. They
  were caught up later. The annotator also mis-handled typedef'd pointers taken by address (`LDrawDLHandle *`
  is `void **`) and function-pointer typedefs. It now handles both. A function-pointer typedef's own
  parameters still need annotating by hand.
