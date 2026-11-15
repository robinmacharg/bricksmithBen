#!/bin/zsh
# Run Bricksmith's automated tests (hosted in the app) and check that the run left no trace in
# the user's real preferences.
#
# Usage:
#   scripts/test.sh                           # unit + characterisation tests (BricksmithTests)
#   scripts/test.sh --only <Target/Suite>     # pass through to -only-testing (repeatable)
#   scripts/test.sh --ui                      # also run the XCUITest smoke tests (real windows on screen)
#   scripts/test.sh --ui-only [--only BricksmithUITests/SmokeUITests]   # UI tests alone, for iterating
#   RECORD_GOLDENS=1 scripts/test.sh          # (re)write golden files instead of comparing; review the diff!
#
# Output:
#   build/TestResults.xcresult                # result bundle (open in Xcode)
#   build/test.log                            # full xcodebuild log
#   build/coverage.txt                        # per-file line coverage for the app target
#
# Fails if:
#   - any test fails (expected failures from withKnownIssue don't count as failures)
#   - the installed app's real preferences (com.AllenSmith.Bricksmith) changed during the run
#
# The Debug/test-host domain (com.AllenSmith.Bricksmith.debug) is restored to its pre-run snapshot after
# every run: AppKit autosave (table columns, split views) and Sparkle (SUHasLaunchedBefore) write there
# whenever nibs load, so this keeps runs independent of each other. Changes are reported, not failed.

set -euo pipefail

REPO_ROOT=${0:A:h:h}
PROJECT="$REPO_ROOT/trunk/Bricksmith/Bricksmith.xcodeproj"
BUILD_DIR="$REPO_ROOT/build"
RESULT="$BUILD_DIR/TestResults.xcresult"
LOG="$BUILD_DIR/test.log"
REAL_DOMAIN=com.AllenSmith.Bricksmith
DEBUG_DOMAIN=com.AllenSmith.Bricksmith.debug
DOMAINS=($REAL_DOMAIN $DEBUG_DOMAIN)

ONLY=()
UI=0
while (( $# )); do
	case $1 in
		--ui)   UI=1; shift ;;
		--ui-only) UI=2; shift ;;   # skip the hosted unit run (iterating on UI tests); --only applies to UI
		--only) ONLY+=("-only-testing:$2"); shift 2 ;;
		*) print -u2 "unknown argument: $1"; exit 2 ;;
	esac
done

mkdir -p "$BUILD_DIR"
rm -rf "$RESULT"

# Environment for the tests: xcodebuild forwards TEST_RUNNER_<NAME> to the test process as <NAME>.
export TEST_RUNNER_BRICKSMITH_REPO_ROOT="$REPO_ROOT"
[[ -n "${RECORD_GOLDENS:-}" ]] && export TEST_RUNNER_RECORD_GOLDENS="$RECORD_GOLDENS"

snapshot_defaults() {
	# $1 = before|after. Missing domain is fine (fresh machine); compare as canonical XML.
	local domain
	for domain in "${DOMAINS[@]}"; do
		local file="$BUILD_DIR/defaults-$1-$domain.plist"
		if defaults export "$domain" "$file" 2>/dev/null; then
			plutil -convert xml1 "$file"
		else
			print -n >"$file"
		fi
	done
}

snapshot_defaults before

print "Testing…"
set +e
STATUS=0
: >"$LOG"
if (( UI != 2 )); then
	xcodebuild test -project "$PROJECT" -scheme Bricksmith -configuration Debug \
		-derivedDataPath "$BUILD_DIR/DerivedData" -resultBundlePath "$RESULT" \
		"${ONLY[@]}" >"$LOG" 2>&1
	STATUS=$?
fi
if (( UI && STATUS == 0 )); then
	# UI tests drive the real app in a separate process (first run triggers macOS automation /
	# accessibility permission prompts). Separate scheme so the default run stays prompt-free.
	print "UI testing…"
	rm -rf "$BUILD_DIR/UITestResults.xcresult"
	UI_ONLY=(); (( UI == 2 )) && UI_ONLY=("${ONLY[@]}")
	xcodebuild test -project "$PROJECT" -scheme Bricksmith-UITests -configuration Debug \
		-derivedDataPath "$BUILD_DIR/DerivedData" -resultBundlePath "$BUILD_DIR/UITestResults.xcresult" \
		"${UI_ONLY[@]}" >>"$LOG" 2>&1
	STATUS=$?
fi
set -e

# xcodebuild can return while the test host is still terminating, and AppKit writes autosave state on the
# way out. Wait for it to exit so the snapshot/restore below sees the final state (L31).
for _ in {1..60}; do
	pgrep -f "$BUILD_DIR/DerivedData/Build/Products/Debug/Bricksmith.app/Contents/MacOS/Bricksmith" >/dev/null || break
	sleep 0.5
done

snapshot_defaults after

# Summary lines from Swift Testing / XCTest.
grep -E '^(􁁛|􀢄|✔|✘)|Test run with|Executed [0-9]+ test|\*\* TEST' "$LOG" | grep -vE 'started\.?$' | tail -40 || true

if [[ -d "$RESULT" ]]; then
	xcrun xccov view --report --only-targets "$RESULT" >"$BUILD_DIR/coverage.txt" 2>/dev/null || true
	xcrun xccov view --report --files-for-target Bricksmith.app "$RESULT" >>"$BUILD_DIR/coverage.txt" 2>/dev/null || true
	print "Coverage report: ${BUILD_DIR#$REPO_ROOT/}/coverage.txt"
fi

# Debug/test-host domain: restore, so the next run starts from the same state.
before_debug="$BUILD_DIR/defaults-before-$DEBUG_DOMAIN.plist"
if ! diff -q "$before_debug" "$BUILD_DIR/defaults-after-$DEBUG_DOMAIN.plist" >/dev/null; then
	# diff exits 1 and grep may match nothing: neither may abort the script (set -e + pipefail; see L1).
	changed=$( { diff "$before_debug" "$BUILD_DIR/defaults-after-$DEBUG_DOMAIN.plist" || true; } \
		| { grep -oE '<key>[^<]+</key>' || true; } | sed -E 's/<\/?key>//g' | sort -u | tr '\n' ',' | sed 's/,$//')
	if [[ -s "$before_debug" ]]; then
		defaults import "$DEBUG_DOMAIN" "$before_debug"
	else
		defaults delete "$DEBUG_DOMAIN" 2>/dev/null || true
	fi
	print "Restored $DEBUG_DOMAIN (run wrote: $changed)"
fi

# Real preferences: must be untouched.
if ! diff -q "$BUILD_DIR/defaults-before-$REAL_DOMAIN.plist" "$BUILD_DIR/defaults-after-$REAL_DOMAIN.plist" >/dev/null; then
	print -u2 "FAIL: the test run changed the installed app's preferences ($REAL_DOMAIN):"
	diff "$BUILD_DIR/defaults-before-$REAL_DOMAIN.plist" "$BUILD_DIR/defaults-after-$REAL_DOMAIN.plist" >&2 || true
	exit 1
fi
print "Real preferences unchanged."

if (( STATUS != 0 )); then
	print -u2 "TESTS FAILED (exit $STATUS; full log: ${LOG#$REPO_ROOT/})"
	exit $STATUS
fi
print "TESTS PASSED"
