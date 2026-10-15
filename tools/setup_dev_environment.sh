#!/usr/bin/env bash
# Installs the Godot 4.3 editor used by this project, outside the repository,
# and imports the project once so the tests can run.
#
#     tools/setup_dev_environment.sh            # install (if needed) and import
#     tools/setup_dev_environment.sh --check    # only report what is installed
#
# The binary goes to $FELLWELL_GODOT_DIR (default ~/.local/share/fellwell/godot-4.3)
# so it survives editor crashes and reboots and never ends up in git. Set
# GODOT=/path/to/godot to use an existing 4.3 binary instead; every tool in this
# repo resolves Godot through tools/godot.sh, which honours the same variables.
set -euo pipefail

VERSION="4.3-stable"
ARCHIVE="Godot_v${VERSION}_linux.x86_64.zip"
BINARY="Godot_v${VERSION}_linux.x86_64"
RELEASE_URL="https://github.com/godotengine/godot/releases/download/${VERSION}"
INSTALL_DIR="${FELLWELL_GODOT_DIR:-$HOME/.local/share/fellwell/godot-4.3}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ "${1:-}" == "--check" ]]; then
	if godot="$("$ROOT/tools/godot.sh" --print-path 2>/dev/null)"; then
		echo "Godot: $godot ($("$godot" --version 2>/dev/null | head -n1))"
	else
		echo "Godot: not installed (run tools/setup_dev_environment.sh)"
		exit 1
	fi
	exit 0
fi

if [[ -n "${GODOT:-}" ]]; then
	echo "Using GODOT=$GODOT"
elif [[ -x "$INSTALL_DIR/$BINARY" ]]; then
	echo "Godot $VERSION already installed at $INSTALL_DIR"
else
	for tool in curl sha512sum; do
		command -v "$tool" >/dev/null || { echo "Missing required tool: $tool" >&2; exit 1; }
	done
	download="$(mktemp -d)"
	trap 'rm -rf "$download"' EXIT
	echo "Downloading Godot $VERSION..."
	curl -fsSL --retry 3 -o "$download/$ARCHIVE" "$RELEASE_URL/$ARCHIVE"
	curl -fsSL --retry 3 -o "$download/SHA512-SUMS.txt" "$RELEASE_URL/SHA512-SUMS.txt"
	(cd "$download" && grep " $ARCHIVE\$" SHA512-SUMS.txt | sha512sum -c -)
	mkdir -p "$INSTALL_DIR"
	if command -v unzip >/dev/null; then
		unzip -oq "$download/$ARCHIVE" -d "$INSTALL_DIR"
	else
		python3 -c 'import sys, zipfile; zipfile.ZipFile(sys.argv[1]).extractall(sys.argv[2])' "$download/$ARCHIVE" "$INSTALL_DIR"
	fi
	chmod +x "$INSTALL_DIR/$BINARY"
	echo "Installed to $INSTALL_DIR/$BINARY"
fi

godot="$("$ROOT/tools/godot.sh" --print-path)"
"$godot" --version

# The first import generates .godot/ (git-ignored); tests need imported assets.
echo "Importing project assets..."
"$godot" --headless --path "$ROOT" --editor --quit >/dev/null 2>&1 || true
echo "Ready. Run the tests with: tests/run_tests.sh"
