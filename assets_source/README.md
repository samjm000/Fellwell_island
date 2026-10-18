# Source assets

Original artwork the runtime assets are made from. Godot ignores this folder
(`.gdignore`): nothing here is imported, loaded or exported with the game.

| Folder | Contents |
| --- | --- |
| `character_sheets/` | Animation sheets per character, as supplied. Stella's were her animations before the video; kept for reference. |
| `character_video/` | Animation videos per character. Stella's is the source of all her animations: `tools/extract_stella_video.sh`, then `tools/process_stella_animations.gd`. |
| `concept_art/` | Concept and design sheets: canonical character designs, future locations. |
| `references/` | Reference material, including **deprecated** designs kept for comparison. Never use these at runtime. |

Runtime-ready files live in `art/` and `audio/`. A source file whose runtime
copy is byte-identical (e.g. the room paintings, the theme) is **not** duplicated
here; `docs/asset-manifest.md` records where each runtime asset came from.
