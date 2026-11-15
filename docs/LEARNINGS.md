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
