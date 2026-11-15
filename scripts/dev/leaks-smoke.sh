#!/bin/zsh
# P3 exit: run the Debug app (test mode, fixture library copy) on temp copies of fixtures, then report `leaks`.
# Usage: scripts/dev/leaks-smoke.sh [fixture ...]   (default: the multipart, texmap and LSynth fixtures)
# Never touches the real domain; snapshots and restores the debug domain (the app writes window frames).
set -euo pipefail
ROOT=${0:A:h:h:h}
APP="$ROOT/build/DerivedData/Build/Products/Debug/Bricksmith.app/Contents/MacOS/Bricksmith"
[[ -x $APP ]] || { print -u2 "build the Debug app first (scripts/test.sh)"; exit 2; }
WORK=$(mktemp -d)
cp -R "$ROOT/trunk/Fixtures/ldraw-mini" "$WORK/ldraw"
fixtures=("$@"); (( ${#fixtures} )) || fixtures=(05-multipart.mpd 07-texmap.ldr 15-lsynth-band.ldr)
files=(); for f in $fixtures; do cp "$ROOT/trunk/Fixtures/ldr/$f" "$WORK/$f"; files+="$WORK/$f"; done
defaults export com.AllenSmith.Bricksmith.debug "$WORK/debug-before.plist" 2>/dev/null || print -n >"$WORK/debug-before.plist"
# leaks can't attach to a running app here ("unable to instantiate a memory scanner"), so let it launch the
# app and report at exit; quit the app normally after it has opened and drawn the files.
BRICKSMITH_TEST_MODE=1 BRICKSMITH_TEST_LDRAW_PATH="$WORK/ldraw" MallocStackLogging=1 \
	leaks --atExit -- "$APP" -ApplePersistenceIgnoreState YES -"LDraw Path" "$WORK/ldraw" "${files[@]}" \
	>"$ROOT/build/leaks.txt" 2>&1 &
pid=$!
sleep 15
osascript -e 'tell application id "com.AllenSmith.Bricksmith.debug" to quit' >/dev/null 2>&1 || true
for _ in {1..60}; do kill -0 $pid 2>/dev/null || break; sleep 1; done
[[ -s "$WORK/debug-before.plist" ]] && defaults import com.AllenSmith.Bricksmith.debug "$WORK/debug-before.plist"
grep -E "Process [0-9]+: [0-9]+ leaks? for" "$ROOT/build/leaks.txt" || head -5 "$ROOT/build/leaks.txt"
rm -rf "$WORK"
