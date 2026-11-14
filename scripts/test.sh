#!/bin/zsh
# Run Bricksmith's automated tests (hosted in the app) and check that the run left no trace in
# the user's real preferences.
#
# Usage:
#   scripts/test.sh                           # unit + characterisation tests (BricksmithTests)
#   scripts/test.sh --only <Target/Suite>     # pass through to -only-testing (repeatable)
#   RECORD_GOLDENS=1 scripts/test.sh          # (re)write golden files instead of comparing; review the diff!
#
# Output:
#   build/TestResults.xcresult                # result bundle (open in Xcode)
#   build/test.log                            # full xcodebuild log
#   build/coverage.txt                        # per-file line coverage for the app target
#
# Fails if:
#   - any test fails (expected failures from withKnownIssue don't count as failures)
#   - the app's defaults domain (com.AllenSmith.Bricksmith) differs before and after the run

set -euo pipefail

REPO_ROOT=${0:A:h:h}
PROJECT="$REPO_ROOT/trunk/Bricksmith/Bricksmith.xcodeproj"
BUILD_DIR="$REPO_ROOT/build"
RESULT="$BUILD_DIR/TestResults.xcresult"
LOG="$BUILD_DIR/test.log"
DOMAIN=com.AllenSmith.Bricksmith

ONLY=()
while (( $# )); do
	case $1 in
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
	# Missing domain is fine (fresh machine); compare as canonical XML.
	if defaults export "$DOMAIN" "$1" 2>/dev/null; then
		plutil -convert xml1 "$1"
	else
		print -n >"$1"
	fi
}

snapshot_defaults "$BUILD_DIR/defaults-before.plist"

print "Testing…"
set +e
xcodebuild test -project "$PROJECT" -scheme Bricksmith -configuration Debug \
	-derivedDataPath "$BUILD_DIR/DerivedData" -resultBundlePath "$RESULT" \
	"${ONLY[@]}" >"$LOG" 2>&1
STATUS=$?
set -e

snapshot_defaults "$BUILD_DIR/defaults-after.plist"

# Summary lines from Swift Testing / XCTest.
grep -E '^(􁁛|􀢄|✔|✘)|Test run with|Executed [0-9]+ test|\*\* TEST' "$LOG" | grep -vE 'started\.?$' | tail -40 || true

if [[ -d "$RESULT" ]]; then
	xcrun xccov view --report --only-targets "$RESULT" >"$BUILD_DIR/coverage.txt" 2>/dev/null || true
	xcrun xccov view --report --files-for-target Bricksmith.app "$RESULT" >>"$BUILD_DIR/coverage.txt" 2>/dev/null || true
	print "Coverage report: ${BUILD_DIR#$REPO_ROOT/}/coverage.txt"
fi

if ! diff -q "$BUILD_DIR/defaults-before.plist" "$BUILD_DIR/defaults-after.plist" >/dev/null; then
	print -u2 "FAIL: the test run changed the user's defaults ($DOMAIN):"
	diff "$BUILD_DIR/defaults-before.plist" "$BUILD_DIR/defaults-after.plist" >&2 || true
	exit 1
fi
print "Defaults unchanged."

if (( STATUS != 0 )); then
	print -u2 "TESTS FAILED (exit $STATUS; full log: ${LOG#$REPO_ROOT/})"
	exit $STATUS
fi
print "TESTS PASSED"
