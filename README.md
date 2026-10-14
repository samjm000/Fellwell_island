# Fellwell Island

A warm, funny, mysterious 2D narrative adventure. Stella, a young girl born on
Fellwell Island, explores with her golden Labrador, Lemon. The game uses direct
character movement with modern quality-of-life design, inspired by classic
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
3. Press **Play** (F5). The main scene is `scenes/rooms/stellas_room.tscn`.

## Controls

| Action | Keys |
| --- | --- |
| Move | WASD or arrow keys |
| Interact / advance dialogue / confirm choice | E, Space or Enter |
| Choose a dialogue option | W/S or Up/Down |
| Leave the telescope | E or Esc |

All controls are Input Map actions (`move_left`, `move_right`, `move_up`,
`move_down`, `interact`, plus the built-in `ui_cancel`). Rebind them under
*Project Settings → Input Map*.

## Current milestone

**Milestone 01.5: Art & Atmosphere Pass**, built on Vertical Slice 01 (Stella's
Room). The room now has layered presentation, distinct day and night looks,
ambient animation, an audio system, and hooks that let finished art and audio be
dropped in without code changes.

- [`docs/vertical-slice.md`](docs/vertical-slice.md): scope, systems, scene
  structure, known limitations and next tasks.
- [`docs/art-direction.md`](docs/art-direction.md): visual tone, layering rules,
  and exactly where new art and audio files go.

## Implemented systems

- **Stella movement**: a `CharacterBody2D` with side-on depth movement and
  Y-sorting against furniture.
- **Interaction system**: an `Interactable` base class and scene, plus an
  `InteractionDetector` on Stella that focuses the best nearby object. A floating
  prompt shows what pressing E will do.
- **Dialogue**: the `DialogueManager` autoload, with awaitable `play()`, `say()`
  and `ask()`. Lines are authored as `DialogueSequence` resources in
  `data/dialogue/`.
- **Player control locks**: the `PlayerControl` autoload. Dialogue, the telescope
  and sleeping each suspend Stella's movement and interaction.
- **Game state**: the `GameState` autoload tracks whether Lemon is carried and
  holds named story flags.
- **Time of day**: the `TimeManager` autoload switches between DAY and NIGHT and
  emits a signal. `TimeOfDayTint` and `TimeOfDayVisibility` components react to it.
- **Lemon**: pick up and put down. A carried Lemon is drawn on Stella.
- **Bed**: Stella protests, then agrees to sleep. The screen fades and the time
  changes to NIGHT.
- **Telescope**: a full-screen eyepiece view that differs by time of day, with a
  slow drift and animated sea. At night it shows the lighthouse beam and the
  unexplained offshore light, and seeing the light sets a story flag.
- **Art slots**: `ArtSlot` shows a texture if the file exists (optionally a night
  variant) and otherwise a node-built placeholder. `CharacterArt` picks Stella's
  idle / walk / carry art from dropped-in images, falling back gracefully.
- **Room presentation**: background, Y-sorted lit layer, foreground occluders,
  and multiply/add lighting overlays. `AmbientMotion` and `AmbientFlicker` drive
  curtains, water glints, dust, lamp flicker and the lighthouse.
- **Audio**: the `AudioManager` autoload handles music crossfades, layered looping
  ambience, pooled SFX and UI sounds, and override stacks (the telescope brings
  the sea closer). Sounds are found by file name, and missing files are skipped.
  `RoomAudio` sets each room's day/night mix. Buses: Music, Ambience, SFX, UI.
- **UI theme**: `art/ui/fellwell_theme.tres` styles the prompt (which fades in
  with a key-cap icon) and the dialogue panel (with a speaker tag).

## Project layout

```
scenes/       characters/, rooms/, interactables/, ui/   (.tscn)
scripts/      art/, characters/, rooms/, interactables/, ui/, systems/, dialogue/   (.gd)
data/         dialogue/   (authored DialogueSequence .tres files)
art/          backgrounds/, characters/, props/, telescope/, ui/   (drop-in art; see docs/art-direction.md)
audio/        music/, ambience/, sfx/   (drop-in audio; current files are synthetic placeholders)
tools/        generate_placeholder_audio.py
docs/         design, milestone and art/audio direction notes
```

Every visual slot has a `Placeholder` child built from simple nodes. When the
matching art file exists it is shown instead, so art can arrive piece by piece.

## Adding music

Save the Fellwell Island theme as `audio/music/fellwell_theme.ogg`. It will play
by day and by night until state-specific tracks (`stellas_room_day`,
`stellas_room_night`) are added. See `docs/art-direction.md` for every audio id.
