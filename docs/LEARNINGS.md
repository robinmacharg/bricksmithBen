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
