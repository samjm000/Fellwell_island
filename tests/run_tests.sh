#!/usr/bin/env bash
# Runs the Fellwell regression tests headlessly against Godot 4.3.
#
#     tests/run_tests.sh                     # every tests/test_*.gd
#     tests/run_tests.sh tests/test_lemon.gd # just these files
#     tests/run_tests.sh --import            # force a re-import first
#
# The project is re-imported automatically when scripts or assets have changed
# since the last import (new class_names and art need registering).
#
# Each test file runs in its own Godot process, at a fixed 60 fps so timing is
# deterministic and faster than real time. A file fails if any check fails, a
# test times out, or Godot reports a script error. Exits non-zero on any failure.
# Full logs are kept in .godot/test_logs/ (git-ignored).
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
GODOT_BIN="$(tools/godot.sh --print-path)" || exit 127
LOG_DIR="$ROOT/.godot/test_logs"

files=()
force_import=false
for arg in "$@"; do
	case "$arg" in
		--import) force_import=true ;;
		*) files+=("$arg") ;;
	esac
done
if [[ ${#files[@]} -eq 0 ]]; then
	files=(tests/test_*.gd)
fi

# New class_name scripts or assets are only registered by an import.
CLASS_CACHE=.godot/global_script_class_cache.cfg
if [[ -f "$CLASS_CACHE" ]] && [[ -n "$(find scripts tests art audio scenes -newer "$CLASS_CACHE" \( -name '*.gd' -o -name '*.png' -o -name '*.webp' -o -name '*.ogg' -o -name '*.mp3' -o -name '*.wav' \) -print -quit)" ]]; then
	force_import=true
fi
if $force_import || [[ ! -d .godot/imported ]] || [[ ! -f "$CLASS_CACHE" ]]; then
	echo "Importing project..."
	"$GODOT_BIN" --headless --path . --editor --quit >/dev/null 2>&1
	touch "$CLASS_CACHE"
fi
mkdir -p "$LOG_DIR"

# Engine output that means something went wrong even if every check passed.
ERROR_PATTERN='SCRIPT ERROR|Parse Error|Compile Error|Failed to load|Cannot call|Invalid (get|set|call)|Nonexistent function|leaked|ObjectDB instances'

failed_files=()
for file in "${files[@]}"; do
	name="$(basename "$file" .gd)"
	log="$LOG_DIR/$name.log"
	"$GODOT_BIN" --headless --fixed-fps 60 --path . res://tests/framework/runner.tscn -- "res://${file#./}" >"$log" 2>&1
	status=$?
	grep -E '^(PASS|FAIL|        - )' "$log"
	errors="$(grep -E "$ERROR_PATTERN" "$log" | grep -v 'CHECK FAILED' || true)"
	if [[ -n "$errors" ]]; then
		echo "ERRORS in $name:"
		echo "$errors" | head -n 20 | sed 's/^/        /'
		status=1
	fi
	if [[ $status -ne 0 ]]; then
		failed_files+=("$name (log: $log)")
	fi
done

echo
if [[ ${#failed_files[@]} -eq 0 ]]; then
	echo "All test files passed (${#files[@]})."
	exit 0
fi
echo "Failed test files:"
printf '  %s\n' "${failed_files[@]}"
exit 1
