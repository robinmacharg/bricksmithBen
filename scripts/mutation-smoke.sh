#!/bin/zsh
# Mutation smoke test: proves the test suite actually *checks* the hot code, not just runs it.
#
# Each file in scripts/mutations/*.patch is a small, deliberate bug (flip a comparison in -write, drop a
# parsed field, change a float format, skip an undo registration, …). For each one this script:
#   1. applies the patch to the working tree,
#   2. runs the test suite,
#   3. reverts the patch,
# and requires that the suite FAILED. A mutation that survives (tests still pass) means a test is missing.
#
# Usage:
#   scripts/mutation-smoke.sh                 # all mutations
#   scripts/mutation-smoke.sh NAME [NAME…]    # only scripts/mutations/NAME.patch
#
# Writing a mutation: make the one-line bug in the source, then
#   git diff > scripts/mutations/<class>-<what>.patch && git checkout -- <file>
# Keep each patch to one logical change in one hot class (plan §4.6). Requires a clean working tree.

set -euo pipefail

REPO_ROOT=${0:A:h:h}
MUTATIONS_DIR="$REPO_ROOT/scripts/mutations"
cd "$REPO_ROOT"

if [[ -n "$(git status --porcelain --untracked-files=no)" ]]; then
	print -u2 "mutation-smoke: working tree has uncommitted changes; commit or stash first."
	exit 2
fi

patches=()
if (( $# )); then
	for name in "$@"; do patches+=("$MUTATIONS_DIR/$name.patch"); done
else
	patches=("$MUTATIONS_DIR"/*.patch(N))
fi

if (( ${#patches} == 0 )); then
	print "mutation-smoke: no mutations defined yet (scripts/mutations/*.patch). Nothing to do."
	exit 0
fi

survivors=()
for patch in "${patches[@]}"; do
	name=${patch:t:r}
	print -n "mutation $name … "
	git apply "$patch"
	if "$REPO_ROOT/scripts/test.sh" >"$REPO_ROOT/build/mutation-$name.log" 2>&1; then
		print "SURVIVED (no test caught it)"
		survivors+=("$name")
	else
		print "killed"
	fi
	git apply -R "$patch"
done

if (( ${#survivors} )); then
	print -u2 "\n${#survivors} mutation(s) survived: ${survivors[*]}"
	print -u2 "Add or strengthen tests until each one is killed."
	exit 1
fi
print "\nAll ${#patches} mutations killed."
