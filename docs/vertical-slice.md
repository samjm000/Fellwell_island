# Vertical Slice 01: Stella's Room

## Scope

One playable room that proves the core reusable systems before the wider island
is built. In scope:

- Stella's movement and collision in a side-on room
- Reusable interaction (detection, focus, prompt, interact)
- Short dialogue and observation lines, with simple choices
- Lemon pick-up and put-down
- DAY/NIGHT time state, changed by sleeping in the bed
- Day/night room presentation, driven by events
- Telescope view mode, with a night-only offshore light that is recorded as seen

Out of scope: other rooms, inventory, saving, continuous time, NPCs, art and audio.

## Implemented systems

### Autoloads (`project.godot`)

| Autoload | Script | Responsibility |
| --- | --- | --- |
| `GameState` | `scripts/systems/game_state.gd` | Playthrough state: `is_lemon_carried` and named story flags (`FLAG_SEEN_OFFSHORE_LIGHT`). Emits `lemon_carried_changed` and `flag_changed`. |
| `TimeManager` | `scripts/systems/time_manager.gd` | Current `GameTime.Phase` (DAY/NIGHT). `set_phase()` emits `phase_changed`. |
| `PlayerControl` | `scripts/systems/player_control.gd` | Keyed input locks. Stella moves and interacts only when no lock is held. |
| `DialogueManager` | `scripts/systems/dialogue_manager.gd` | Awaitable `play(sequence)`, `say(lines, speaker)` and `ask(question, options)`. Owns the DialogueBox UI and queues overlapping requests. |
| `ScreenFader` | `scenes/ui/screen_fader.tscn` | `await fade_out()` and `await fade_in()`. |

Each autoload has one job. Time is kept out of `GameState` on purpose, so a future
save system will serialise `GameState` and `TimeManager` side by side.

### Interaction

- `Interactable` (`scripts/interactables/interactable.gd`, base scene
  `scenes/interactables/interactable.tscn`) is an `Area2D` on physics layer 3.
  Its collision shape is the reach zone. Exports: `interaction_name`,
  `interaction_prompt` (the verb), `interaction_priority`, `enabled`,
  `prompt_offset`, `dialogue` and `night_dialogue`.
  - By default `interact(actor)` plays `get_current_dialogue()`, so simple
    observations need no script: the window, photograph and cupboard are just
    configured instances.
  - Subclasses override `interact()`, `can_interact()` or `get_current_dialogue()`.
    Bed, Telescope and Lemon do this.
- `InteractionDetector` (`scripts/interactables/interaction_detector.gd`) is an
  `Area2D` on Stella. It collects overlapping interactables and each physics frame
  focuses the valid one with the highest priority, nearest first on ties. It emits
  `focused_changed`. Stella never checks what she is interacting with.
- `InteractionPrompt` (`scenes/ui/interaction_prompt.tscn`) floats above the
  focused object and hides while the player has no control. The room connects
  Stella's `focused_interactable_changed` signal to it.

### Dialogue

- `DialogueSequence` (`scripts/dialogue/dialogue_sequence.gd`) is a resource with
  `speaker` and `lines`. The room's lines live in `data/dialogue/stellas_room/*.tres`
  and can be edited in the Inspector.
- `DialogueBox` (`scenes/ui/dialogue_box.tscn`) handles presentation only:
  typewriter reveal (E skips to the end, then advances), optional speaker name,
  and an option list for `ask()`.
- While dialogue is open, `DialogueManager` holds the `dialogue` control lock.

### Time of day

- `GameTime.Phase` (`scripts/systems/game_time.gd`) is the shared enum. It sits
  outside the autoload so it can be used as an exported type.
- `TimeOfDayTint` is a `CanvasModulate` that tints the world. UI layers are not
  affected.
- `TimeOfDayVisibility` can be attached to any CanvasItem to show it only in the
  selected phases (an export flags bitmask). The window's day and night skies use it.
- Nothing polls the time: everything listens to `TimeManager.phase_changed`.

### Room objects

| Object | Behaviour |
| --- | --- |
| Bed (`bed.gd`) | DAY, first press: "I'm not tired." Later presses: "I am slightly tired." and a *Go to sleep?* choice. Choosing Yes plays "Fine. But only because Lemon's exhausted.", fades out, sets NIGHT, fades in. NIGHT: "I'm wide awake now." |
| Telescope (`telescope.gd`) | Opens a `TelescopeView`. DAY: sea view and Mrs. Boggins lines. NIGHT: dark sea, a sweeping lighthouse beam and a pulsing offshore light. The first sighting sets `seen_offshore_light` and plays a first-sighting line; later visits play a short repeat line. |
| Lemon (`lemon.gd`) | Pick up ("Come on, Lemon.") or put down ("Honestly, I don't know how you sleep this much."). Carrying is stored in `GameState`; Stella shows a carried-Lemon visual in response. |
| Window | Plain Interactable with day and night lines and a day/night sky. |
| Grandad's photograph | Plain Interactable. |
| Cupboard | Plain Interactable with a collision footprint. |

## Scene structure

```
StellasRoom (Node2D, stellas_room.gd: wires Stella's focus to the prompt)
├── TimeOfDayTint (CanvasModulate)
├── Background (wall, floor, skirting placeholders)
├── WallObjects
│   ├── Window (Interactable): Reach, Visual/{Frame, DaySky, NightSky, Mullion}
│   └── Photograph (Interactable): Reach, Visual
├── RoomBounds (StaticBody2D: back wall, front edge, left/right walls)
├── Objects (y_sort_enabled)
│   ├── Bed (bed.tscn)
│   ├── Telescope (telescope.tscn): adds a TelescopeView child while in use
│   ├── Cupboard (cupboard.tscn)
│   ├── Lemon (lemon.tscn)
│   └── Stella (stella.tscn)
│       ├── FeetCollision
│       ├── Visual/…/CarriedLemon
│       └── InteractionDetector/Reach
└── UI (CanvasLayer)
    └── InteractionPrompt
```

All furniture scenes inherit `interactable.tscn` and follow the same pattern:
`Reach` (interaction shape), `Body/Footprint` (StaticBody2D for walking
collision, layer 1) and `Visual` (art). Each origin is at the floor contact point
so Y-sorting works.

Canvas layers: world 0, UI prompt 1, TelescopeView 10, DialogueBox 20,
ScreenFader 50.

Physics layers: 1 `world`, 2 `player`, 3 `interactables`.

## Known limitations

- **No saving.** Restarting the game resets to DAY with Lemon on the floor. There
  is no way back to DAY in-game.
- **Bed protest state is per room instance.** It resets if the room is reloaded.
  This is deliberate: it is flavour, not story progress.
- **Placeholder art only.** The rooms and views are built from coloured
  rectangles and polygons. The beam "sweep" just scales a triangle.
- **Keyboard only.** There are no gamepad or mouse bindings yet, although the
  Input Map actions make them easy to add. The prompt's key hint is a fixed "E".
- **Lemon drop position isn't validated.** Lemon is placed beside Stella's feet
  and can visually overlap furniture if Stella stands right against it.
- **Input routing relies on lock checks.** The telescope view ignores input while
  dialogue is open by checking `DialogueManager.is_active()`. With more overlay
  modes, a small modal/input stack would be cleaner.
- **Single room.** `Lemon` has a path for starting in the carried state, but room
  transitions don't exist yet.

## Obvious next tasks

1. Add a room transition and spawn-point system (with `ScreenFader`) to a second
   location, such as the hallway or the outside of the house.
2. Add save/load that serialises `GameState` and `TimeManager`.
3. Expand `GameTime.Phase` (morning, afternoon, evening) and add a day count once
   the design calls for scheduled events.
4. Let interactables choose dialogue from story flags as well as time, for example
   with an ordered list of conditional `DialogueSequence` entries.
5. Add gamepad bindings and derive the prompt's key hint from the Input Map.
6. Replace placeholder visuals with production art once the visual direction is
   supplied.
