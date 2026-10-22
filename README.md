# Fellwell Island

A warm, funny, mysterious 2D narrative adventure. Stella, a young girl born on
Fellwell Island, explores with her soft, golden, fluffy dog, Lemon. It is a mouse-first
point-and-click adventure with modern quality-of-life design, inspired by classic
LucasArts-style adventures.

## Godot version

**Godot 4.3** (standard build, GDScript only). The project uses the
*Compatibility* renderer, so it runs on modest and older GPUs. Later 4.x versions
should open it fine; Godot may add `.uid` files when you do, and those should be
committed.

## Running the project

1. Clone the repository.
2. Open Godot 4.3, choose **Import** and select `project.godot`. The first open
   imports assets into `.godot/`, which is git-ignored.
3. Press **Play** (F5). The main scene is `scenes/boot/boot.tscn`: the title card,
   then Stella's room. To jump straight into the room, open
   `scenes/rooms/stellas_room.tscn` and press F6.

From a terminal (Linux/WSL), `tools/godot.sh --path .` runs the game with the
Godot found by the tools below.

## Setting up, and recovering after a crash

Nothing needed for development lives outside the repo except the Godot binary:

```bash
tools/setup_dev_environment.sh     # installs Godot 4.3 to ~/.local/share/fellwell/godot-4.3
                                   # (checksum-verified, outside git) and imports the project
tools/setup_dev_environment.sh --check   # shows which Godot will be used
tests/run_tests.sh                 # the regression suite; exits non-zero on failure
tests/capture_screenshots.sh       # reference screenshots (needs a display)
```

Set `GODOT=/path/to/godot` to use a different 4.3 binary. See
[`tests/README.md`](tests/README.md) for what the tests cover and how to add one.

- [`docs/development.md`](docs/development.md): setup, repository layout,
  adding art, processing animation sheets, tests, music, Git/LFS policy, and
  publishing to GitHub.
- [`docs/asset-manifest.md`](docs/asset-manifest.md): every major asset, its
  status (runtime / source / concept / deprecated) and where it came from,
  including the canonical Stella design.

## Controls

The mouse is the primary control.

| Action | Mouse | Keys |
| --- | --- | --- |
| Walk | Left-click the floor | |
| Look at / use something | Hover it to see its label, left-click to walk over and use it | |
| Go to another room | Hover a door or the stairs ("Go downstairs", "Go to Kitchen"…) and click it | |
| Advance dialogue | Left-click | E, Space or Enter |
| Choose a dialogue option | Hover and click it | W/S or Up/Down, then E |
| Leave the telescope | Left- or right-click | E or Esc |
| Skip the title | Click | E, Space, Enter or Esc |

**Debug keyboard controls:** in debug builds (the editor and the tests), WASD or
the arrow keys still move Stella and E uses whatever is in reach. Turn them off
with the project setting `fellwell/debug/keyboard_controls`; release exports
never enable them. All keys are Input Map actions (`move_left`, `move_right`,
`move_up`, `move_down`, `interact`, plus the built-in `ui_cancel`).

## Current milestone

**Milestone 01.5: Art & Atmosphere Pass**, built on Vertical Slice 01 (Stella's
Room), followed by the art pack v1 integration and a controls and boot pass:
point-and-click play, perspective scaling, the title/boot flow and the theme music
hook. The room now has layered presentation, distinct day and night looks,
ambient animation, an audio system, and hooks that let finished art and audio be
dropped in without code changes.

- [`docs/vertical-slice.md`](docs/vertical-slice.md): scope, systems, scene
  structure, known limitations and next tasks.
- [`docs/art-direction.md`](docs/art-direction.md): visual tone, layering rules,
  and exactly where new art and audio files go.

## Implemented systems

- **Point-and-click**: `PointAndClickInput` turns clicks into Stella's actions;
  she walks navigation paths over the room's `WalkableFloor` (built from the
  walkable outline). Hovering a hotspot shows its label and a pointing cursor.
- **Stella's house**: the attic bedroom, entrance hall, kitchen/living room and
  garden, joined by `RoomExit` doors and stairs. `RoomTransition` fades between
  rooms and places Stella at the next room's named `RoomArrival`; Lemon (carried,
  or left where she was put down) and the time of day carry over. The garden
  gate is a documented hook until the wider island exists. See
  [`docs/vertical-slice.md`](docs/vertical-slice.md), *Stella's house*.
- **Interaction system**: an `Interactable` base class and scene. Each object has
  an editor-authored `Hotspot`, `ApproachPoint`, `interaction_radius` and
  `approach_facing`; clicking it walks Stella there and uses it on arrival. An
  `InteractionDetector` on Stella serves the debug keyboard controls.
- **Stella movement**: a `CharacterBody2D` with side-on depth movement,
  Y-sorting against furniture, and perspective scaling from the room's
  `RoomPerspective` (smaller at the back, larger at the front).
- **Boot flow**: `scenes/boot/boot.tscn` fades the title in as the theme starts,
  then fades into Stella's room. `Boot.intro_scene` is the insertion point for a
  future intro animation or video.
- **Dialogue**: the `DialogueManager` autoload, with awaitable `play()`, `say()`
  and `ask()`. Lines are authored as `DialogueSequence` resources in
  `data/dialogue/`.
- **Player control locks**: the `PlayerControl` autoload. Dialogue, the telescope
  and sleeping each suspend Stella's movement and interaction.
- **Game state**: the `GameState` autoload tracks whether Lemon is carried and
  holds named story flags.
- **Time of day**: the `TimeManager` autoload switches between DAY and NIGHT and
  emits a signal. `TimeOfDayTint` and `TimeOfDayVisibility` components react to it.
- **Lemon**: picking her up and putting her down are timed to Stella's pickup
  animation (Lemon is handed between the floor sprite and the art on set
  frames). A carried Lemon is drawn in Stella's carry frames.
- **Bed**: Stella protests, then agrees to sleep. The screen fades and the time
  changes to NIGHT.
- **Telescope**: a full-screen eyepiece view that differs by time of day, with a
  slow drift and animated sea. At night it shows the lighthouse beam and the
  unexplained offshore light, and seeing the light sets a story flag.
- **Art slots**: `ArtSlot` shows a texture if the file exists (optionally a night
  variant) and otherwise a node-built placeholder. `CharacterArt` picks Stella's
  idle, walk_left/right and carry art from dropped-in images, mirroring or
  falling back gracefully (a still with a small bob until walk frames exist).
- **Room presentation**: background, Y-sorted lit layer, foreground occluders,
  and multiply/add lighting overlays. `AmbientMotion` and `AmbientFlicker` drive
  curtains, water glints, dust, lamp flicker and the lighthouse.
- **Audio**: the `AudioManager` autoload handles music crossfades, layered looping
  ambience, pooled SFX and UI sounds, and override stacks (the telescope brings
  the sea closer). A track already playing is never restarted, and an
  interrupted one resumes where it left off. Sounds are found by file name, and missing files are skipped.
  `RoomAudio` sets each room's day/night mix. Buses: Music, Ambience, SFX, UI.
- **UI theme**: `art/ui/fellwell_theme.tres` styles the prompt (which fades in
  with a key-cap icon) and the dialogue panel (with a speaker tag).

## Project layout

```
scenes/       boot/, characters/, rooms/, interactables/, ui/   (.tscn)
scripts/      art/, boot/, characters/, rooms/, interactables/, ui/, systems/, dialogue/   (.gd)
data/         dialogue/   (authored DialogueSequence .tres files)
art/          runtime images: backgrounds/, characters/ (stella/animations/, lemon/), telescope/, ui/
audio/        runtime audio: music/ (the theme), ambience/ and sfx/ (synthetic placeholders)
assets_source/  originals: character_video/, character_sheets/ (old), concept_art/, references/ (deprecated designs); ignored by Godot
tests/        regression suite (run_tests.sh), screenshot capture, framework/
tools/        setup_dev_environment.sh, godot.sh, import_art_pack.gd, extract_stella_video.sh, video_matte/,
              process_stella_animations.gd, generate_placeholder_audio.py
docs/         design, milestone and art/audio direction notes
```

Every visual slot has a `Placeholder` child built from simple nodes. When the
matching art file exists it is shown instead, so art can arrive piece by piece.

**Installed art:** Stella's house (entrance hall, kitchen/living room and the
cottage garden, by day and night, from the `fellwell-stellas-house-v1` pack),
Stella's room by day and night (the attic-bedroom paintings
from `Concept Art/Stella_room_day` and `Stella_room_dark`), and the telescope
views by day and night (art pack v1). Stella is fully animated (idle, walk,
picking Lemon up, and idle and walking while carrying her), cut from one Gemini
video by `tools/extract_stella_video.sh` and `tools/process_stella_animations.gd`
(see `docs/development.md`, *Stella's animations*). Lemon's floor sprite comes
from the same video. Known issues are listed in `docs/asset-manifest.md`, *Open
art issues*.
The theme music, "Found at Low Tide", is installed as
`audio/music/fellwell_theme.mp3`. Still to come: cut-out foreground occluders, and recorded ambience and SFX. Packs are imported with
`tools/import_art_pack.gd` (see `docs/art-direction.md`).

## Planned: remake Stella's animation video

Good enough for now; not the next job. Stella's mouth is open while she walks
(and in the pickup and carry walk). The plan:

1. In Gemini, edit the existing video if it can ("same video, but keep her mouth
   closed with a gentle smile"); otherwise regenerate the whole take with the
   same prompt plus that line. Regenerate all of it, not just the walk, so her
   size and style still match across walk, pickup and carry.
2. Save it over `assets_source/character_video/stella/stella_walk_and_pickup.mp4`.
3. Re-pick the frames in `ANIMATIONS` in `tools/process_stella_animations.gd`
   (a seamless walk and carry-walk loop, still standing frames, where the pickup
   starts and ends) and re-measure `STELLA_FEET`, `SOURCE_RECT` and
   `GROUND_SPEED_PER_VIDEO_FRAME`.
4. Run `tools/extract_stella_video.sh`, then the processing tool; copy the values
   it reports (`art_offset.y`, `walk_ground_speed`, Lemon's `pickup_offset` and
   lift frame) into the scenes; check the QA sheets and a
   `VIDEO_MATTE_DEBUG=1` pass, since the matte's rules may need tuning for a
   new video; then `tests/run_tests.sh --import`.

About 30–60 minutes of tool work once the video exists.

## Music

The Fellwell Island theme ("Found at Low Tide") is
`audio/music/fellwell_theme.mp3`, looped. It starts on the title card and carries
on into Stella's room, by day and night and through the telescope, without
restarting. To replace it, save the new track under the same name (`.ogg`, `.mp3`
or `.wav`; keep only one), then run `tests/run_tests.sh --import` or open the
editor. If it's ever missing, the game is silent there and logs that the theme is
awaited. See
`docs/art-direction.md` for every audio id.

## Backpack and bedroom discovery

Before Stella's first departure, open the trunk, click again to take her yellow
backpack, and pick up Lemon. The backpack button (top-right) or **I** opens the
inventory; **I**, **Esc** or its Close button closes it. Items can be inspected;
world-item use and combination await a later design decision.

Open the low wardrobe at the front-left to discover the mouse's disco. **Esc**
or Close wardrobe returns to the room. This optional scene uses prototype art
and music; Stella's new backpack animation is awaiting replacement footage.
