#!/usr/bin/env python3 -I
"""Switch the named .m files from -fno-objc-arc to -fobjc-arc in the app's project.pbxproj (P3)."""
import os, sys
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
P = os.path.join(ROOT, "trunk", "Bricksmith", "Bricksmith.xcodeproj", "project.pbxproj")
s = open(P).read()
for name in sys.argv[1:]:
    old = f'/* {name} in Sources */ = {{isa = PBXBuildFile;'
    lines = [l for l in s.split("\n") if old in l and "-fno-objc-arc" in l]
    if len(lines) != 1:
        sys.exit(f"{name}: expected 1 MRC build-file line, found {len(lines)}")
    s = s.replace(lines[0], lines[0].replace('"-fno-objc-arc"', '"-fobjc-arc"'))
open(P, "w").write(s)
print(f"{len(sys.argv) - 1} files now -fobjc-arc")
