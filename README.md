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

**Vertical Slice 01: Stella's Room.** One playable room that establishes the
core reusable systems. See [`docs/vertical-slice.md`](docs/vertical-slice.md) for
the scope, scene structure, known limitations and next tasks.

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
- **Telescope**: a full-screen view that differs by time of day. At night it shows
  the lighthouse and the unexplained offshore light, and seeing the light sets a
  story flag.

## Project layout

```
scenes/       characters/, rooms/, interactables/, ui/   (.tscn)
scripts/      characters/, rooms/, interactables/, ui/, systems/, dialogue/   (.gd)
data/         dialogue/   (authored DialogueSequence .tres files)
art/, audio/  production assets (empty for now; placeholders are built from nodes)
docs/         design and milestone notes
```

Placeholder visuals are ColorRect, Polygon2D and Label nodes whose names start
with `Placeholder`. They sit under each object's `Visual` node, and no script
references them, so production art can replace them freely.
