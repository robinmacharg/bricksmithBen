# Running parallel agents

How to split port work across several agents, each in its own git worktree, and integrate the results.
First used for P4 (four streams). The reasons behind each rule are in LEARNINGS (L17, L74, L75, L84).

## When to split

- Split only along file boundaries. Streams that edit the same file must touch different hunks, or the
  cherry-picks conflict. Survey first (`grep -rl` for each work item) and assign every file to one stream.
- Do anything that touches many files (mechanical sweeps, renames, removing a macro) **yourself, first**, and commit
  it. Then start the agents from that commit.
- Keep work that needs `project.pbxproj` edits (adding, deleting or splitting source files) out of the streams. Do it
  serially, after integration.

## Setting up

```zsh
S=<scratchpad>                      # outside the repo; worktrees under /tmp are fine since e66adfa (L84)
BASE=$(git rev-parse --short HEAD)  # the commit every stream starts from
git worktree add -b p4-<stream> $S/p4-<stream> $BASE
```

Each worktree gets its own `build/`, so builds run in parallel. Tests do not (see the lock below).

## The brief

The brief is all the agent knows. Every brief states:

1. **Worktree path, branch and base SHA.** The agent's first command is `git rev-parse --short HEAD`, which must
   print the base (L75). It works and commits only there, never in the main checkout, and never pushes.
2. **What to read first:** CLAUDE.md, LEARNINGS, the plan section for the phase, TESTING.md "Writing a test", and
   anything specific (KNOWN-BUGS, AGENT-NOTES, ARCHITECTURE).
3. **Scope:** the files and items it owns, and what the other streams are doing, so it keeps out of their hunks.
4. **Files only the integrator edits:** `project.pbxproj`, `docs/port-status.md`, `docs/LEARNINGS.md`,
   `docs/warnings-baseline*.txt`. No new source files (they need pbxproj edits); stop and ask instead.
5. **Hard pass criteria for every commit:**
   - `git diff <base> -- '**/golden/**'` is empty;
   - the known-issue count is unchanged (the test count may grow);
   - no new warnings (disappearing ones are fine);
   - no bug fixes: record new bugs in KNOWN-BUGS with a `withKnownIssue` test, or report them if borderline.
6. **The gate,** with the test run under the shared lock, and the commit as a separate command (L74):
   ```zsh
   setopt pipefail; scripts/build.sh 2>&1 | tail -3 && lockf -k $S/test.lock scripts/test.sh 2>&1 | tail -8
   ```
   The lock is mandatory: every test run snapshots and restores the same Debug preferences domain (L75).
7. **Never `scripts/test.sh --ui`** (it takes over the user's screen), and never launch Bricksmith.app. The
   integrator runs the UI suite once, after integrating.
8. **Commit messages:** the phase's prefix (`refactor(P4 <stream>): …`), one concern per commit. No attribution
   trailer.
9. **The final report:** commits (SHA and subject), new Swift-visible API, tests added, new bugs, learnings, doc
   changes due, and uncertainties. Ask for facts; the integrator verifies them.

## Integrating

1. **Verify before believing** (L17): read the stream's diff, check that the golden diff is empty, and check any
   claim that matters (lifetimes, ordering, semantics) against the code.
2. Cherry-pick the stream's commits onto the phase branch, in its order. Then build, run the tests under the lock
   (other agents may still be running), and only then integrate the next stream.
3. Apply the doc changes the stream reported (port-status rows, LEARNINGS entries, TESTING/ARCHITECTURE/plan
   fixes) in one docs commit per integration.
4. After the last stream: re-baseline warnings if any disappeared (deliberately, say why in the commit), run the
   UI suite and the perf gate, then remove the worktrees (`git worktree remove`) and their branches.

## Troubleshooting

- **`build.sh` reports every warning as new in a worktree:** the `/tmp` vs `/private/tmp` path spelling (L84,
  fixed in `e66adfa`). A worktree cut from an older base still has the old script; cut from a newer base.
- **`.git/index.lock` exists:** a git process in the *main* checkout died (worktrees have their own index). Check
  that no git process is running there, then remove the lock.
- **A cherry-pick conflicts:** the scope split was wrong. Resolve by hand, re-run the full gate, and note it in
  the integration commit.
