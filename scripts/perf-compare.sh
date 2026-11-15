#!/bin/zsh
# Performance gate: compare the latest perf results against the committed baseline.
#
# Design (plan §5 P2 row 16): perf tests time themselves (median of a fixed number of iterations, Release
# build, synthetic model generated from ldraw-mini) and write build/perf-results.json:
#     { "machine": "<hw.model>", "results": { "<metric>": <median seconds>, … } }
# The baseline lives in docs/perf-baseline.json in the same shape. This avoids XCTest's device-keyed
# .xcbaselines and xcresult parsing.
#
# Usage:
#   scripts/perf-compare.sh                    # compare; fail if any metric is > +20% or missing
#   scripts/perf-compare.sh --update-baseline  # deliberate: copy results to the baseline (explain in commit)
#
# A metric present in the baseline but missing from the results FAILS the gate (a skipped perf test must
# not pass silently). Comparisons are only meaningful on the baseline's machine; a different machine fails
# with a message rather than comparing.

set -euo pipefail

REPO_ROOT=${0:A:h:h}
RESULTS="$REPO_ROOT/build/perf-results.json"
BASELINE="$REPO_ROOT/docs/perf-baseline.json"
BUDGET=1.20

if [[ "${1:-}" == --update-baseline ]]; then
	[[ -f "$RESULTS" ]] || { print -u2 "no results at ${RESULTS#$REPO_ROOT/}; run the perf tests first"; exit 1; }
	cp "$RESULTS" "$BASELINE"
	print "Baseline updated: ${BASELINE#$REPO_ROOT/}"
	exit 0
fi

if [[ ! -f "$BASELINE" ]]; then
	print "perf-compare: no baseline yet (${BASELINE#$REPO_ROOT/}); nothing to compare. (Perf tests arrive in P2.)"
	exit 0
fi
[[ -f "$RESULTS" ]] || { print -u2 "perf-compare: no results at ${RESULTS#$REPO_ROOT/}; perf tests did not run"; exit 1; }

python3 -I - "$BASELINE" "$RESULTS" "$BUDGET" "$(sysctl -n hw.model)" <<'EOF'
import json, sys
baseline, results, budget, machine = json.load(open(sys.argv[1])), json.load(open(sys.argv[2])), float(sys.argv[3]), sys.argv[4]
if baseline.get("machine") != machine:
    sys.exit(f"perf-compare: baseline recorded on {baseline.get('machine')}, this is {machine}; not comparable")
failed = False
for metric, base in sorted(baseline["results"].items()):
    now = results["results"].get(metric)
    if now is None:
        print(f"MISSING  {metric}: in baseline but not measured (skipped test?)"); failed = True; continue
    ratio = now / base
    status = "OK" if ratio <= budget else "SLOWER"
    failed |= ratio > budget
    print(f"{status:8} {metric}: {base:.4f}s -> {now:.4f}s ({ratio:.0%} of baseline)")
sys.exit(1 if failed else 0)
EOF
