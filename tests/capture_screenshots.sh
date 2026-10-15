#!/usr/bin/env bash
# Captures reference screenshots of the vertical slice (room by day and night,
# hover labels, carrying Lemon, depth scaling, dialogue, telescope, boot title)
# plus overlays of the floor, hotspots and approach points for checking authoring.
#
#     tests/capture_screenshots.sh [OUTPUT_DIR]     # default .godot/screenshots
#
# Needs a display (opens a window briefly), so it is separate from run_tests.sh.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
OUT="$(realpath -m "${1:-$ROOT/.godot/screenshots}")"
mkdir -p "$OUT"
FELLWELL_SCREENSHOT_DIR="$OUT" tools/godot.sh --fixed-fps 60 --path . res://tests/framework/runner.tscn \
	-- res://tests/screenshots/screenshots.gd 2>&1 | grep -E '^(PASS|FAIL|        - |SCREENSHOT)|SCRIPT ERROR'
echo "Screenshots in $OUT"
