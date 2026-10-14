# Vertical Slice 01: Stella's Room (+ Milestone 01.5: Art & Atmosphere)

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

Out of scope: other rooms, inventory, saving, continuous time, NPCs.

**Milestone 01.5** added presentation without changing gameplay:
- layered room art slots with placeholders
- Stella's art states
- distinct day and night looks
- ambient animation
- the audio system
- telescope and UI polish

Art and audio placement rules are in [`art-direction.md`](art-direction.md).

**Art pack v1** is integrated through those systems:
- The painted room is shown by day and night, with the walkable floor and
  interaction zones remapped onto the painting.
- Stella's idle and carry stills are installed, with a walking bob until walk
  frames exist.
- Lemon's art is installed.
- The painted telescope views are installed, with overlays aligned to the
  painted lamp and offshore light.

## Implemented systems

### Autoloads (`project.godot`)

| Autoload | Script | Responsibility |
| --- | --- | --- |
| `GameState` | `scripts/systems/game_state.gd` | Playthrough state: `is_lemon_carried` and named story flags (`FLAG_SEEN_OFFSHORE_LIGHT`). Emits `lemon_carried_changed` and `flag_changed`. |
| `TimeManager` | `scripts/systems/time_manager.gd` | Current `GameTime.Phase` (DAY/NIGHT). `set_phase()` emits `phase_changed`. |
| `PlayerControl` | `scripts/systems/player_control.gd` | Keyed input locks. Stella moves and interacts only when no lock is held. |
| `DialogueManager` | `scripts/systems/dialogue_manager.gd` | Awaitable `play(sequence)`, `say(lines, speaker)` and `ask(question, options)`. Owns the DialogueBox UI and queues overlapping requests. |
| `ScreenFader` | `scenes/ui/screen_fader.tscn` | `await fade_out()` and `await fade_in()`. |
| `AudioManager` | `scripts/systems/audio_manager.gd` | Music crossfade, looping ambience layers, pooled SFX/UI one-shots, keyed music/ambience overrides, bus volume hooks. Finds sounds by id under `audio/`; missing files are skipped. Routes window close through `stop_all_and_quit()`. |

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
  focused object, fading in with a key-cap icon. It stays on screen and hides
  while the player has no control. The room connects Stella's
  `focused_interactable_changed` signal to it.
- `interaction_sfx` on each Interactable is played by the detector on use. It is
  empty for objects that play their own sounds (Lemon, the telescope).

### Dialogue

- `DialogueSequence` (`scripts/dialogue/dialogue_sequence.gd`) is a resource with
  `speaker` and `lines`. The room's lines live in `data/dialogue/stellas_room/*.tres`
  and can be edited in the Inspector.
- `DialogueBox` (`scenes/ui/dialogue_box.tscn`) handles presentation only:
  typewriter reveal (E skips to the end, then advances), an optional speaker
  tag, an option list for `ask()`, and UI sounds.
- All UI styling lives in `art/ui/fellwell_theme.tres`, the project theme.
  Portraits are not implemented.
- While dialogue is open, `DialogueManager` holds the `dialogue` control lock.

### Time of day

- `GameTime.Phase` (`scripts/systems/game_time.gd`) is the shared enum. It sits
  outside the autoload so it can be used as an exported type.
- `TimeOfDayTint` tints any CanvasItem (it drives `modulate` by default). It is
  used on the room's `Lit` layer and on the placeholder background.
- `TimeOfDayVisibility` can be attached to any CanvasItem to show it only in the
  selected phases (an export flags bitmask). It switches the window view, the
  lighting overlays and the vignettes.
- `ArtSlot` swaps between day and night textures itself.
- `RoomAudio` changes the music and ambience mix.
- Nothing polls the time: everything listens to `TimeManager.phase_changed`.

### Art and ambience components (`scripts/art/`)

- `ArtSlot`: shows `texture_path` (and an optional `night_texture_path`) if the
  file exists, anchored top-left, bottom-centre or centre; otherwise it shows its
  `Placeholder` child. Paths are used rather than texture references, so missing
  art never breaks a scene.
- `CharacterArt`: Stella's `Visual`. Gameplay sets only `is_moving`,
  `is_carrying` and `facing`. Art comes from an authored `SpriteFrames` or from
  `art/characters/stella/<state>[_n].png`, with fallbacks. A carried-Lemon overlay
  is shown when there is no carry art.
- `AmbientMotion`: sine sway, bob and skew plus optional drift.
- `AmbientFlicker`: alpha pulse or flicker.
- Both ambient components stop working while hidden.

### Audio

- `RoomAudio` is a node in the room. It sets the day and night music ids,
  ambience layers (id → dB) and occasional one-shots (gulls, creaks).
- The telescope view pushes its own ambience mix (the sea comes forward and the
  room falls away) and an optional night motif, then pops them on close.
- **SFX hooks:** footsteps (by distance walked), interact, Lemon pick-up/put-down,
  telescope open/close, cupboard, bedding, sleep transition, UI confirm, select
  and cancel.

### Room objects

| Object | Behaviour |
| --- | --- |
| Bed (`bed.gd`) | DAY, first press: "I'm not tired." Later presses: "I am slightly tired." and a *Go to sleep?* choice. Choosing Yes plays "Fine. But only because Lemon's exhausted.", fades out, sets NIGHT, fades in. NIGHT: "I'm wide awake now." |
| Telescope (`telescope.gd`) | Opens a `TelescopeView`: an eyepiece shader, day/night ArtSlot paintings, and animated overlays (glints, moon path, stars, lighthouse beam with lamp flare, offshore light) that drift with slow parallax. DAY: Mrs. Boggins lines. NIGHT: the first sighting sets `seen_offshore_light` and plays a first-sighting line; later visits play a short repeat line. |
| Lemon (`lemon.gd`) | Pick up ("Come on, Lemon.") or put down ("Honestly, I don't know how you sleep this much."). Carrying is stored in `GameState`; Stella shows a carried-Lemon visual in response. |
| Window | Plain Interactable with day and night lines and a day/night sky. |
| Grandad's photograph | Plain Interactable. |
| Cupboard | Plain Interactable with a collision footprint. |

## Scene structure

```
StellasRoom (Node2D, stellas_room.gd: wires Stella's focus to the prompt)
├── Background                       not tinted
│   ├── WindowView                   outside view: Day / Night variants, clouds, glints, lighthouse
│   └── RoomArt (ArtSlot)            room painting (day/night); Placeholder is tinted by night
├── Lit (TimeOfDayTint)              everything below is tinted together
│   ├── WallObjects
│   │   ├── Window (Interactable): Reach, Visual (ArtSlot) with curtains
│   │   └── Photograph (Interactable): Reach, Visual (ArtSlot)
│   ├── Objects (y_sort_enabled)
│   │   ├── Bed / Telescope / Cupboard / Lemon   (each: Reach, Body/Footprint, Visual ArtSlot)
│   │   └── Stella (stella.tscn)
│   │       ├── FeetCollision, Shadow
│   │       ├── Visual (CharacterArt) → Placeholder, CarriedLemon (ArtSlot)
│   │       └── InteractionDetector/Reach
│   └── Foreground (ArtSlot)         occluders always in front (placeholder plant)
├── RoomBounds (StaticBody2D)
├── Lighting                         MULTIPLY vignettes; ADD sunbeam/lamp/moonlight; motes
├── RoomAudio                        day/night music + ambience mix
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
- **Partial art and placeholder audio.**
  - Stella has no walk frames yet; her stills bob while walking.
  - There is no depth scaling: Stella is the same size at the front and back
    of the floor.
  - Painted foreground furniture can't occlude her, so the walkable outline
    keeps her clear of it.
  - Audio is synthetic placeholder ambience and SFX, and there is no music yet.
- **Art only appears at runtime.** `ArtSlot` and `CharacterArt` load their files
  when the game runs, so the editor still shows placeholders. Making them
  `@tool` scripts would allow in-editor previews.
- **Music restarts after an override.** When the telescope's night motif ends,
  the room track starts again from the beginning rather than resuming.
- **`--quit-after` warnings.** Quitting via `--quit-after` (or `get_tree().quit()`
  directly) while ambience is playing prints Godot 4.3 "leaked playback"
  warnings. Normal window closes go through `AudioManager.stop_all_and_quit()`
  and exit cleanly.
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
6. Drop in the supplied art and theme music following `art-direction.md`, then
   tune the `Lit` night tint and overlay alphas against the painted backgrounds.
7. Make `ArtSlot` and `CharacterArt` `@tool` scripts so artists can see real
   art in the editor.
