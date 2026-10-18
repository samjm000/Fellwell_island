#!/usr/bin/env bash
# Cuts Stella out of her animation video: every frame, background removed
# (tools/video_matte/video_matte.c), as numbered RGBA PNGs at the video's size.
# tools/process_stella_animations.gd then turns them into the game's frames.
#
#     tools/extract_stella_video.sh [VIDEO] [OUT_DIR]
#
# Defaults: assets_source/character_video/stella/stella_walk_and_pickup.mp4 and
# .godot/stella_video_frames/ (frame_0001.png is the video's first frame).
# Needs ffmpeg ($FFMPEG, else on PATH) and a C compiler ($CC, else cc).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VIDEO="${1:-$ROOT/assets_source/character_video/stella/stella_walk_and_pickup.mp4}"
OUT="${2:-$ROOT/.godot/stella_video_frames}"
FFMPEG="${FFMPEG:-$(command -v ffmpeg || true)}"
FFPROBE="${FFPROBE:-$(dirname "${FFMPEG:-x}")/ffprobe}"
[[ -x "$FFPROBE" ]] || FFPROBE="$(command -v ffprobe || true)"
if [[ -z "$FFMPEG" || -z "$FFPROBE" ]]; then
	echo "ffmpeg/ffprobe not found: install ffmpeg or set FFMPEG=/path/to/ffmpeg." >&2
	exit 127
fi

MATTE="$ROOT/.godot/tools/video_matte"
SOURCE="$ROOT/tools/video_matte/video_matte.c"
if [[ ! -x "$MATTE" || "$SOURCE" -nt "$MATTE" ]]; then
	mkdir -p "$(dirname "$MATTE")"
	"${CC:-cc}" -O2 -o "$MATTE" "$SOURCE"
fi

IFS=x read -r W H < <("$FFPROBE" -v error -select_streams v:0 -show_entries stream=width,height -of csv=p=0:s=x "$VIDEO")
mkdir -p "$OUT"
rm -f "$OUT"/frame_*.png
"$FFMPEG" -v error -i "$VIDEO" -f rawvideo -pix_fmt rgb24 - \
	| "$MATTE" "$W" "$H" \
	| "$FFMPEG" -v error -f rawvideo -pix_fmt rgba -s "${W}x${H}" -i - -start_number 1 "$OUT/frame_%04d.png"
echo "$(ls "$OUT" | wc -l) frames (${W}x${H}) in $OUT"
