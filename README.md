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

## Controls

The mouse is the primary control.

| Action | Mouse | Keys |
| --- | --- | --- |
| Walk | Left-click the floor | |
| Look at / use something | Hover it to see its label, left-click to walk over and use it | |
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
art/          backgrounds/, characters/, props/, telescope/, ui/   (drop-in art; see docs/art-direction.md)
audio/        music/, ambience/, sfx/   (drop-in audio; current files are synthetic placeholders)
tests/        regression suite (run_tests.sh), screenshot capture, framework/
tools/        setup_dev_environment.sh, godot.sh, import_art_pack.gd, process_stella_animations.gd, generate_placeholder_audio.py
docs/         design, milestone and art/audio direction notes
```

Every visual slot has a `Placeholder` child built from simple nodes. When the
matching art file exists it is shown instead, so art can arrive piece by piece.

**Installed art:** Stella's room by day and night (the attic-bedroom paintings
from `Concept Art/Stella_room_day` and `Stella_room_dark`), and the telescope
views by day and night (art pack v1). Stella is fully animated (idle, walk,
picking Lemon up, and idle and walking while carrying her), processed from the
designer's animation sheets by `tools/process_stella_animations.gd`. Lemon's floor
sprite comes from the same sheets. Known issues in the source art are listed in
`docs/art-direction.md`, *Animation QA*.
The theme music, "Found at Low Tide", is installed as
`audio/music/fellwell_theme.mp3`. Still to come: Stella's walk frames, cut-out
foreground occluders, and recorded ambience and SFX. Packs are imported with
`tools/import_art_pack.gd` (see `docs/art-direction.md`).

## Music

The Fellwell Island theme ("Found at Low Tide") is
`audio/music/fellwell_theme.mp3`, looped. It starts on the title card and carries
on into Stella's room, by day and night and through the telescope, without
restarting. To replace it, save the new track under the same name (`.ogg`, `.mp3`
or `.wav`; keep only one), then run `tests/run_tests.sh --import` or open the
editor. If it's ever missing, the game is silent there and logs that the theme is
awaited. See
`docs/art-direction.md` for every audio id.
