#!/usr/bin/env python3 -I
"""P2 coverage gate (plan §5 P2, "Coverage targets"): per-class line coverage for tiers A and B.

Reads the hosted-test result bundle (build/TestResults.xcresult, written by scripts/test.sh) and the ledger
docs/coverage-ledger.tsv, then prints for every tier A/B class:

    raw %        line coverage as xccov reports it
    effective %  the same with ledgered functions removed from both sides
    status       ok / BELOW (fails the gate) / accepted (a "*" ledger row: risk signed off by the maintainer)

Ledger rows (tab-separated): file  selector-or-function-or-*  reason
    selector    "hitTest:transform:viewScale:boundsOnly:creditObject:hits:" matches that method in that file
    function    "V3Print" matches a C function
    *           accepts the whole class below target (needs a maintainer sign-off in port-status.md)

Usage:  scripts/dev/coverage-tiers.py [--uncovered]   (--uncovered also lists unledgered functions < 100%)
Exit 1 if any class is BELOW its tier target.
"""
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SOURCE = os.path.join(ROOT, "trunk", "Bricksmith", "Source")
RESULT = os.path.join(ROOT, "build", "TestResults.xcresult")
LEDGER = os.path.join(ROOT, "docs", "coverage-ledger.tsv")

# Tier membership, copied from the plan's table. Paths are relative to Source/.
TIER_A_DIRS = ("LDraw/Commands/", "LDraw/Files/")
TIER_A_FILES = {"LDraw/Support/LDrawDirective.m", "LDraw/Support/LDrawUtilities.m", "LDraw/Support/ColorLibrary.m",
                "LDraw/Support/MatrixMath.c", "LDraw/Support/ComputationalGeometry.m"}
TIER_B_FILES = {"LDraw/Support/LDrawPaths.m", "LDraw/Support/PartLibrary.m", "LDraw/Support/ModelManager.m",
                "LDraw/Support/PartCatalogBuilder.m", "LDraw/Support/PartReport.m", "Other/MLCadIni.m",
                "Other/StringUtilities.m",
                # row 12 app-logic classes
                "Application/General/RelatedParts.m", "Application/General/LSynthConfiguration.m",
                "Application/General/PartBrowserDataSource.m", "Application/General/MinifigureDialogController.m"}
TIER_B_DIRS = ("Categories/",)
TARGET = {"A": 90.0, "B": 80.0}


def tier(rel):
    if rel.startswith(TIER_A_DIRS) or rel in TIER_A_FILES:
        return "A"
    if rel.startswith(TIER_B_DIRS) or rel in TIER_B_FILES:
        return "B"
    return None


def xccov(*args):
    return subprocess.run(["xcrun", "xccov", "view", "--report", *args, RESULT],
                          capture_output=True, text=True, check=True).stdout


def ledger():
    rows = {}
    with open(LEDGER, encoding="utf-8") as fh:
        for n, line in enumerate(fh, 1):
            if not line.strip() or line.startswith("#"):
                continue
            parts = line.rstrip("\n").split("\t")
            if len(parts) != 3 or not parts[2].strip():
                raise SystemExit(f"{LEDGER}:{n}: need 3 tab-separated fields with a reason")
            rows.setdefault(parts[0], {})[parts[1]] = parts[2]
    return rows


def functions(path):
    out = []
    for line in xccov("--functions-for-file", path).splitlines():
        m = re.match(r"\s*\d+\s+(.+?)\s+\{\d+, \d+\}\s+[\d.]+% \((\d+)/(\d+)\)", line)
        if m:
            name = m.group(1)
            sel = re.sub(r"^[-+]\[\S+ (.+)\]$", r"\1", name)
            out.append((name, sel, int(m.group(2)), int(m.group(3))))
    return out


def main():
    if not os.path.isdir(RESULT):
        raise SystemExit("no build/TestResults.xcresult - run scripts/test.sh first")
    led = ledger()
    files = []
    for line in xccov("--files-for-target", "Bricksmith.app").splitlines():
        m = re.search(r"(/\S+/Source/(\S+\.(?:m|c)))\s", line)
        if m and tier(m.group(2)):
            files.append((m.group(1), m.group(2)))
    known = {rel for _, rel in files}
    for rel in led:
        if rel not in known:
            print(f"warning: ledger names {rel}, which is not a tier A/B file in this report", file=sys.stderr)

    failed = False
    report, uncovered = [], []
    for path, rel in sorted(files, key=lambda f: (tier(f[1]), f[1])):
        rows = led.get(rel, {})
        funcs = functions(path)
        raw_c = sum(f[2] for f in funcs); raw_t = sum(f[3] for f in funcs)
        kept = [f for f in funcs if f[1] not in rows]
        eff_c = sum(f[2] for f in kept); eff_t = sum(f[3] for f in kept)
        raw = 100 * raw_c / raw_t if raw_t else 100
        eff = 100 * eff_c / eff_t if eff_t else 100
        t = tier(rel)
        if eff >= TARGET[t]:
            status = "ok"
        elif "*" in rows:
            status = "accepted"
        else:
            status = "BELOW"; failed = True
        report.append(f"{t} {status:8} raw {raw:6.2f}%  effective {eff:6.2f}%  ({eff_c}/{eff_t})  {rel}")
        uncovered += [f"  {rel}: {f[0]} {f[2]}/{f[3]}" for f in kept if f[2] < f[3]]
        for sel in rows:
            if sel != "*" and not any(f[1] == sel for f in funcs):
                print(f"warning: ledger row {rel} {sel} matches no function", file=sys.stderr)
    print("\n".join(report))
    if "--uncovered" in sys.argv:
        print("\nUnledgered functions below 100%:")
        print("\n".join(uncovered))
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
