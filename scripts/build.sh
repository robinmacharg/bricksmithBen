#!/bin/zsh
# Build Bricksmith and check compiler warnings against the committed baseline.
#
# Usage:
#   scripts/build.sh                      # Debug build; fail if any warning is not in the baseline
#   scripts/build.sh --release            # Release configuration
#   scripts/build.sh --update-baseline    # build, then overwrite the baseline
#                                         # (docs/warnings-baseline.txt; Release: docs/warnings-baseline-release.txt)
#
# Warnings are compared as de-duplicated text with repo-relative paths and with line/column numbers removed,
# so that edits which only move code don't count as new warnings.
# Sorting and comm use LC_ALL=C: the baseline is C-sorted, and comm under another locale reports matching lines as new.
# Always a clean build, so every warning is reported. Derived data goes in build/DerivedData (gitignored).
# The log is written to build/build.log.

set -euo pipefail

REPO_ROOT=${0:A:h:h}
PROJECT="$REPO_ROOT/trunk/Bricksmith/Bricksmith.xcodeproj"
SCHEME=Bricksmith
CONFIGURATION=Debug
UPDATE_BASELINE=0
BUILD_DIR="$REPO_ROOT/build"

for arg in "$@"; do
	case $arg in
		--release)         CONFIGURATION=Release ;;
		--update-baseline) UPDATE_BASELINE=1 ;;
		*) print -u2 "unknown argument: $arg"; exit 2 ;;
	esac
done

# Each configuration has its own baseline: optimised builds report extra diagnostics (e.g. -Wuninitialized).
if [[ $CONFIGURATION == Debug ]]; then
	BASELINE="$REPO_ROOT/docs/warnings-baseline.txt"
else
	BASELINE="$REPO_ROOT/docs/warnings-baseline-${(L)CONFIGURATION}.txt"
fi

mkdir -p "$BUILD_DIR"
LOG="$BUILD_DIR/build.log"
CURRENT="$BUILD_DIR/warnings.txt"

print "Building $SCHEME ($CONFIGURATION)…"
if ! xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration "$CONFIGURATION" \
		-derivedDataPath "$BUILD_DIR/DerivedData" clean build >"$LOG" 2>&1; then
	grep -E 'error:|\*\* BUILD FAILED' "$LOG" | sort -u | head -40
	print -u2 "BUILD FAILED (full log: $LOG)"
	exit 1
fi

# Say where the app is as the last line, whatever the warning check decides (the app is built either way).
APP="$BUILD_DIR/DerivedData/Build/Products/$CONFIGURATION/$SCHEME.app"
trap 'print "Built app: $APP"' EXIT

# Normalise: keep only warning lines, make paths repo-relative, drop line:col, de-duplicate.
# Under /tmp, Xcode logs /tmp/... while ${0:A} resolves to /private/tmp/...: strip both spellings.
# xcodebuild's log sometimes splits a clang warning across two lines (L90), at any word boundary, even right after
# "warning:". A complete clang warning ends with its "[-W...]" flag, so a clang (non-Swift) warning line without one
# is joined with the next line when that line looks like a continuation: non-blank, and not a path, source excerpt,
# include note or another tool's output. (A few warnings, e.g. NSDrawer, have no flag; a blank line follows them.)
awk '
	{ line[NR] = $0 }
	END {
		for (i = 1; i <= NR; i++) {
			cur = line[i]
			if (cur ~ /: warning: / && cur !~ /\.swift:[0-9]+:[0-9]+: warning: / && cur !~ /\]$/ && i < NR) {
				nxt = line[i + 1]
				if (nxt ~ /^[^\/ \t]/ && nxt !~ /^(In file included|ld: |note: |warning: |error: |\*\*|Command |cd |export )/) {
					cur = cur nxt; i++
				}
			}
			print cur
		}
	}' "$LOG" \
	| grep -E ': warning: ' \
	| sed -E -e "s|$REPO_ROOT/||g" -e "s|${REPO_ROOT#/private}/||g" -e 's/:[0-9]+:[0-9]+: warning: /: warning: /' \
	| LC_ALL=C sort -u >"$CURRENT" || true

COUNT=$(wc -l <"$CURRENT" | tr -d ' ')
print "BUILD SUCCEEDED: $COUNT distinct warnings"

if (( UPDATE_BASELINE )); then
	cp "$CURRENT" "$BASELINE"
	print "Baseline updated: ${BASELINE#$REPO_ROOT/}"
	exit 0
fi

if [[ ! -f "$BASELINE" ]]; then
	print -u2 "No baseline at ${BASELINE#$REPO_ROOT/}; run with --update-baseline"
	exit 1
fi

NEW=$(LC_ALL=C comm -13 "$BASELINE" "$CURRENT")
GONE=$(LC_ALL=C comm -23 "$BASELINE" "$CURRENT" | wc -l | tr -d ' ')
if [[ -n "$NEW" ]]; then
	print -u2 "NEW WARNINGS (not in baseline):"
	print -u2 -- "$NEW"
	exit 1
fi
(( GONE > 0 )) && print "$GONE baseline warnings no longer occur. Consider running --update-baseline."
print "No new warnings."
