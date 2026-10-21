# Island exploration — updated 21 October 2026

The garden gate opens the newly supplied **Enchanted Island Adventure Map**.
Stella can walk the island paths and enter the waterfall, Max's cave, marketplace
and port, plus the farm, then return home. Max's cave has a separate cliffside entrance and interior, connected in both directions. Marketplace and port also connect directly.
The bedroom map close-up uses the same new map artwork.

## Existing artwork and image quality

- `Downloads/Enchanted Island Adventure Map.png` is copied byte-for-byte to
  `art/backgrounds/island/map.png`. It is the currently supplied labelled map.
  All island routes, arrivals and hotspots were reauthored against it.
- `Downloads/Fantasy Island Market_ Day and Night.png` is copied byte-for-byte
  to `art/backgrounds/marketplace/board.png`. Day and night are native
  AtlasTexture views in `day.tres` and `night.tres`; the original board is never
  resampled or regenerated. The left-hand overview and panel dividers are not
  displayed as part of the street. Aspect ratio is preserved with side margins.
- Both supplied PNGs are **1448×1086**. Each marketplace street panel is only
  about **606×522**. Filtering can improve jagged edges, but cannot recover
  detail absent from those originals. No AI upscaling or replacement art was used.
- Backgrounds and character frames remain lossless, with full original dimensions
  and mipmaps. The default desktop window now renders at **1920×1080** using
  `canvas_items`, retaining 1280×720 logical scene coordinates. Background ArtSlots
  use Catmull-Rom reconstruction when enlarged, and mipmaps when reduced. This
  samples the same original pixels; no source image was altered or regenerated.
  Atlas sampling is bounded to the selected panel to avoid seams or neighbouring
  board artwork bleeding in. See [art-resolution-audit.md](art-resolution-audit.md).
- `tools/import_island_art.gd` is the reproducible import tool. Pass the two
  approved original file paths after `--`; run an editor import afterward.
  For brand-new files, rerun the tool after that initial import so their generated
  `.import` metadata receives the same mipmap settings, then import once more.

The harbour retains its approved painting. The earlier use of Blaze in the
Moonlit Cave for Max's home was incorrect. That file is retained but no longer
referenced by any playable room. Three newly supplied originals are copied
byte-for-byte, each 1672 by 941 pixels:

| Original in Downloads | Runtime painting |
| --- | --- |
| image-gen-3(2) (1).png | art/backgrounds/farm/day.png |
| image-gen-2(5).png | art/backgrounds/maxs_cave/interior.png |
| image-gen-1(5).png | art/backgrounds/maxs_cave/exterior.png |

The reproducible tool tools/import_farm_cave_art.gd takes these originals in
that order and preserves their bytes with lossless import and mipmaps. No new
images were made. Farm and cave terrace night use a tint; the interior retains
its warm painted lanterns with a gentle night tint.

The farm painting includes fixed Stella and Lemon figures, which remain visible
while playable Stella moves. Its clear foreground is playable; animals, pond,
rocks and painted figures are blocked. The obstructed back path is not exposed
as disconnected floor. Animals, guinea pigs and pond have simple observations.
The barn is scenery, not an additional interior.

The cave interior keeps Stella on the visible rug corridor beside the bed and
desk. Clicking the distant exit walks her to the end of that corridor and fades
to the terrace: the painting hides the continuation behind its large desk.
She does not walk over the table to reach it. Maps, telescope and bed have
simple observations through the existing DialogueManager.

## Character scale and architecture

Stella is about one-third larger in the garden: perspective changes from
0.25–0.31 to **0.33–0.40**, with matching feet clearance and walking speed.
Her **map scale stays exactly 0.065**. The previous fix scaling her collision
offset along with her feet remains in place for narrow paths.

All locations use the existing Room, RoomExit, RoomArrival, WalkableFloor,
PointAndClickInput, RoomPerspective, DialogueManager and Lemon systems.
Market shop observations are provisional labels; no interiors, purchases or
shopkeeper dialogue trees were added. Floors now have scene-authored solid
scenery polygons. WalkableFloor subtracts these polygons, expanded by Stella's
footprint, from navigation; the same polygons stop keyboard movement in physics.
The garden stays clear of planters/walls; the market avoids its clock pedestal,
stalls and dock posts; the port avoids its bollard and crates; the waterfall
keeps to the ledge; the cave terrace avoids fire, stool, treasure and cliffs, while its interior avoids the bed, backpack, shelves and desk. Map routes now go around buildings,
the covered market stall and the ship, and the port approach ends on the pier.

Navigation baking and the world map use matching quarter-pixel cells. This
prevents narrow overview-path corners collapsing during navigation merging.
The optional authoring overlay shows walkable floor in green and solid scenery
in red. All exits and arrivals remain reachable in both phases.

The approved 18 October waterfall module remains byte-for-byte unchanged.
The waterfall wrapper only links TimeManager to its night property and instances
the 2560×1440 module at 0.5 scale. Its normal/slowing/stopped/restarting states
and hidden-cave availability remain intact. The beaver puzzle and an enterable
hidden cave behind the falls are still future work; Max's cave is separate.
No save system, inventory, character swap or replacement framework was added.

## Verification and working state

Baseline before this farm/cave update: all **17** regression test files passed.
`tests/test_island.gd` covers both phase tours through every location, direct
market/port travel, farm and cave round trips, observations, correct painting selection, connected floor patches, all arrivals/approaches, Lemon waiting in the
port, the shared bedroom map, garden/map scale and waterfall state behaviour.
The new `test_scenery_navigation.gd` drives clicks at painted obstacles in both
phases, samples whole routes for scenery intersections, and confirms physics
collision. The test runner now fails on all engine and shader errors as well as
script errors. Room-transition test waits use stable instance IDs so they do
not retain freed room references. The full suite passed **all 17 test files**, with engine/shader errors treated
as failures. Independent HD viewports verify 1920×1080 output even when the
desktop window manager fits the interactive window to a smaller screen. These
are fresh HD renders, not enlarged screenshots.

Visual checks:
`FELLWELL_SCREENSHOT_DIR=/absolute/output/path tools/godot.sh --fixed-fps 60 --path . res://tests/framework/runner.tscn -- res://tests/screenshots/island_screenshots.gd`

Original module check:
`tools/godot.sh --headless --fixed-fps 60 --path . --script res://tests/module_checks/waterfall_standalone.gd`

WSL currently lacks PulseAudio/ALSA libraries, so its graphical preview uses
Godot's silent audio fallback. Audio assets and game audio code are unchanged.

All earlier uncommitted development is retained. README.md and AGENTS.md remain
unchanged. Nothing has been committed, pushed or merged. `_incoming/`, uploaded
originals and synced project sources were not edited.


## Animated animal-free farm (21 October 2026)

The island map's existing Farm exit now opens the approved animated farm in
scenes/rooms/farm.tscn. art/backgrounds/farm/day.png is a byte-identical copy
of Downloads/farm (SHA-256 764c4b7d46604498da6e8df4906716fc6d86f547da92377f752780c1eb787b7e),
1672x941. The older baked-character painting is retained only as deprecated
reference assets_source/references/farm_before_ambient.png.
FarmAmbientArt extends ArtSlot, with independent 40s environment and 55s detail
loops and the approved pond refraction / plant sway shader. RGB/RG masks keep
hutch, shoreline, paths and architecture fixed. Shader vertex tint preserves the
existing room DAY/NIGHT tint; no alternate night artwork was generated.
The playable Stella and Lemon systems remain separate from the clean background.
Walkable floor and solid barn/hutch/pond/rocks/gate shapes were fitted to this
painting; obsolete painted-animal blockers were removed. Farmyard, empty hutch
and pond observations replace claims that absent animals are visible.
No farm animals or animal AI have been added. Map exits and return route retain
their existing destinations and arrival IDs. Masks can be rebuilt using
tools/farm_ambient/build_masks.ps1 then refine_masks.py (Pillow required).
There is one canvas draw with six texture reads, no runtime viewports or particles.

Validation of farm ambient replacement: all 17 regression test files passed before
and after integration. New farm checks cover the exact original hash, separate
playable character, clocks advancing in-game and independent wrap, night tint,
and walking across the cleared yard. Existing tests cover map round trips,
observations, arrivals/approaches, connected floors, and blocked scenery in both
phases. HD day/night and authoring-overlay renders passed and were inspected.
No commit or push was made.
