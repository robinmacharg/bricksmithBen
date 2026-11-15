#!/usr/bin/env python3 -I
"""P3: convert MRC files to ARC with clang's own ARC migrator (ARCMT), which still ships in Xcode 26's clang
behind `-Xclang -arcmt-action=modify` (the `-ccc-arcmt-*` driver flags are silently ignored).

For each named .m file this takes the file's real compile command from build/build.log (run scripts/build.sh
first), switches it to -fobjc-arc, replaces the precompiled prefix header (built for MRC) with its source, drops
output/dependency/index flags, and runs it with -fsyntax-only -Xclang -arcmt-action=modify. ARCMT rewrites the
file (and may touch headers) in place: retain/release/autorelease removed, NSAutoreleasePool -> @autoreleasepool,
dealloc trimmed, property attributes adjusted. It refuses (exit 1, nothing written) when it finds something it
can't migrate safely; fix that by hand and re-run.

It does NOT decide ownership of plain ivars: every object ivar becomes __strong under ARC. Back-pointers
(parent, delegate, owner) that were deliberately unretained under MRC must be reviewed by hand (L77).

Usage: scripts/dev/arcmt-migrate.py LDrawDocument.m [Inspector.m ...]
"""
import os, re, shlex, subprocess, sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
LOG = os.path.join(ROOT, "build", "build.log")
PREFIX = os.path.join(ROOT, "trunk", "Bricksmith", "Source", "Other", "Mac LDraw_Prefix.pch")
DROP_WITH_ARG = {"-MT", "-MF", "--serialize-diagnostics", "-index-store-path", "-index-unit-output-path", "-o",
                 "-ivfsstatcache"}
DROP = {"-MMD", "-fno-objc-arc", "-fobjc-arc", "-c"}


def command_for(name):
    pattern = re.compile(r"clang .* -c \S*/" + re.escape(name) + r" ")
    with open(LOG, encoding="utf-8", errors="replace") as fh:
        for line in fh:
            if pattern.search(line):
                return shlex.split(line.strip())
    sys.exit(f"{name}: no compile command in build/build.log (run scripts/build.sh first)")


def migrate(name):
    args = command_for(name)
    out, skip, source = [], False, None
    i = 0
    while i < len(args):
        a = args[i]
        if a in DROP_WITH_ARG:
            i += 2; continue
        if a in DROP:
            if a == "-c":
                source = args[i + 1]; i += 2; continue
            i += 1; continue
        if a == "-include" and args[i + 1].endswith(".pch"):
            out += ["-include", PREFIX]; i += 2; continue
        out.append(a); i += 1
    out += ["-fobjc-arc", "-fsyntax-only", "-Xclang", "-arcmt-action=modify", source]
    result = subprocess.run(out, capture_output=True, text=True, cwd=os.path.dirname(source))
    errors = [l for l in result.stderr.splitlines() if ": error:" in l]
    status = "migrated" if result.returncode == 0 else "REFUSED"
    print(f"{name}: {status}")
    for l in errors[:25]:
        print("   ", l.replace(ROOT + "/", ""))
    return result.returncode == 0


if __name__ == "__main__":
    ok = all([migrate(n) for n in sys.argv[1:]])
    sys.exit(0 if ok else 1)
