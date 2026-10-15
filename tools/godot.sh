#!/usr/bin/env bash
# Runs the project's Godot 4.3 binary with the given arguments.
#
#     tools/godot.sh --path .               # run the game
#     tools/godot.sh --print-path           # print the resolved binary
#
# Resolution order: $GODOT, then the copy installed by
# tools/setup_dev_environment.sh, then `godot` on PATH.
set -euo pipefail

INSTALL_DIR="${FELLWELL_GODOT_DIR:-$HOME/.local/share/fellwell/godot-4.3}"
candidates=("${GODOT:-}" "$INSTALL_DIR/Godot_v4.3-stable_linux.x86_64" "$(command -v godot 2>/dev/null || true)")

for candidate in "${candidates[@]}"; do
	if [[ -n "$candidate" && -x "$candidate" ]]; then
		if [[ "${1:-}" == "--print-path" ]]; then
			echo "$candidate"
			exit 0
		fi
		exec "$candidate" "$@"
	fi
done

echo "Godot 4.3 not found. Run tools/setup_dev_environment.sh or set GODOT=/path/to/godot." >&2
exit 127
