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
