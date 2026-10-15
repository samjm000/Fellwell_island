# Vertical Slice 01: Stella's Room (+ Milestone 01.5: Art & Atmosphere)

## Scope

One playable room that proves the core reusable systems before the wider island
is built. In scope:

- Point-and-click movement and interaction in a side-on room
- Reusable interaction (hotspots, approach points, hover labels, interact)
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
- The painted room was shown by day and night, with the walkable floor and
  interaction zones remapped onto the painting. It has since been replaced by
  the attic-bedroom paintings (see *Room objects*), re-authored the same way.
- Stella's idle and carry stills are installed, with a walking bob until walk
  frames exist.
- Lemon's art is installed.
- The painted telescope views are installed, with overlays aligned to the
  painted lamp and offshore light.

**Controls and boot pass** (after art pack v1):
- Mouse-first play: click to walk, hover for labels, click objects to walk over
  and use them. Keyboard movement is a debug fallback.
- Directional animation states, ready for walk frames.
- Subtle perspective scaling.
- A boot/title scene with an intro insertion point.
- The theme music hook.
- A persistent regression suite in `tests/`.

## Implemented systems

### Autoloads (`project.godot`)

| Autoload | Script | Responsibility |
| --- | --- | --- |
| `GameState` | `scripts/systems/game_state.gd` | Playthrough state: `is_lemon_carried` and named story flags (`FLAG_SEEN_OFFSHORE_LIGHT`). Emits `lemon_carried_changed` and `flag_changed`. |
| `TimeManager` | `scripts/systems/time_manager.gd` | Current `GameTime.Phase` (DAY/NIGHT). `set_phase()` emits `phase_changed`. |
| `PlayerControl` | `scripts/systems/player_control.gd` | Keyed input locks. Stella moves and interacts only when no lock is held, and any lock stops a click-walk. `keyboard_debug_enabled()` gates the debug keys. |
| `DialogueManager` | `scripts/systems/dialogue_manager.gd` | Awaitable `play(sequence)`, `say(lines, speaker)` and `ask(question, options)`. Owns the DialogueBox UI and queues overlapping requests. |
| `ScreenFader` | `scenes/ui/screen_fader.tscn` | `await fade_out()` and `await fade_in()`. |
| `AudioManager` | `scripts/systems/audio_manager.gd` | Music crossfade (never restarting the current track; resuming interrupted ones), looping ambience layers, pooled SFX/UI one-shots, keyed music/ambience overrides, bus volume hooks. Finds sounds by id under `audio/`; missing files are skipped. Routes window close through `stop_all_and_quit()`. |

Each autoload has one job. Time is kept out of `GameState` on purpose, so a future
save system will serialise `GameState` and `TimeManager` side by side.

### Point and click

- `PointAndClickInput` (`scripts/systems/point_and_click_input.gd`, the room's
  `PointAndClick` node) reads mouse input in the room:
  - Hover: it finds the usable interactable whose hotspot is under the mouse
    (highest `hotspot_priority`, then nearest the front) and emits
    `hovered_changed`. The room feeds that to the prompt, and the cursor becomes
    a pointing hand.
  - Click on a hotspot: `Stella.walk_to_interactable()`.
  - Click elsewhere: `Stella.walk_to()` the nearest floor point. A newer click
    replaces whatever she was doing.
  - While any `PlayerControl` lock is held, world clicks are ignored and fall
    through to the dialogue box or telescope view.
- `WalkableFloor` (`scripts/rooms/walkable_floor.gd`, `RoomBounds/Floor`) is a
  `NavigationRegion2D`. At load it builds its navigation polygon from the room's
  walkable outline (the same `CollisionPolygon2D` that bounds keyboard movement),
  inset by Stella's feet rectangle. There is one floor shape to edit.
- `Stella` follows `NavigationServer2D` paths on her world's map, at full speed
  sideways and `depth_speed_scale` of it in depth. She arrives once within the
  target's `interaction_radius` of its approach point, turns to
  `approach_facing`, and calls `Interactable.trigger()`. A walk that stops
  getting closer to its next waypoint gives up after `stuck_timeout`.
- **Authoring an object** (all in the room scene, per instance):
  - add a `Hotspot` child (an `Area2D` holding `CollisionPolygon2D`s, layer and
    mask 0) traced over the painted object;
  - add an `ApproachPoint` `Marker2D` on the floor where Stella should stand;
  - set `interaction_radius`, `approach_facing` (toward the hotspot, left or
    right) and, where hotspots overlap, `hotspot_priority`.

  `tests/capture_screenshots.sh` draws all of this over the room
  (`02_day_authoring_overlay.png`) so it can be checked against the art.
  `test_authored_approach_points_are_reachable` fails if an approach point is
  off the floor.
- `RoomPerspective` (`scripts/rooms/room_perspective.gd`, the room's
  `Perspective` node) maps feet y to a scale. In Stella's room it runs from 0.66
  at the back (`far_y` 525) to 0.86 at the front (`near_y` 704). Stella's art
  and shadow scale about her feet; Lemon on the floor, and her carried hotspot,
  scale to match.

### Interaction

- `Interactable` (`scripts/interactables/interactable.gd`, base scene
  `scenes/interactables/interactable.tscn`) is an `Area2D` on physics layer 3.
  Its collision shape is the reach zone used by the debug keyboard controls.
  Exports: `interaction_name`, `interaction_prompt` (the verb),
  `interaction_priority`, `enabled`, `prompt_offset`, `dialogue`,
  `night_dialogue`, and the point-and-click group above. `trigger(actor)`
  checks `can_interact()`, plays `interaction_sfx` and calls `interact()`; clicks
  and the keyboard detector both go through it.
  - By default `interact(actor)` plays `get_current_dialogue()`, so simple
    observations need no script: the window, photograph and cupboard are just
    configured instances.
  - Subclasses override `interact()`, `can_interact()` or `get_current_dialogue()`.
    Bed, Telescope and Lemon do this.
- `InteractionDetector` (`scripts/interactables/interaction_detector.gd`) is an
  `Area2D` on Stella, used by the debug keyboard controls (E). It collects
  overlapping interactables and each physics frame focuses the valid one with the
  highest priority, nearest first on ties.
- `InteractionPrompt` (`scenes/ui/interaction_prompt.tscn`) floats above the
  hovered object at its `prompt_offset`. It stays on screen and hides while the
  player has no control. It can show a key-cap (`key_hint`), which is empty for
  mouse play.
- `interaction_sfx` on each Interactable is played on use. It is empty for
  objects that play their own sounds (Lemon, the telescope).

### Dialogue

- `DialogueSequence` (`scripts/dialogue/dialogue_sequence.gd`) is a resource with
  `speaker` and `lines`. The room's lines live in `data/dialogue/stellas_room/*.tres`
  and can be edited in the Inspector.
- `DialogueBox` (`scenes/ui/dialogue_box.tscn`) handles presentation only:
  typewriter reveal (a click or E skips to the end, then advances), an optional
  speaker tag, an option list for `ask()` (hover and click, or keys), and UI
  sounds. `DialogueManager` emits `line_shown` for every line and question.
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
  `is_carrying`, `facing` and `depth_scale`. States are `idle`, `walk_left`,
  `walk_right`, `carry_idle`, `carry_walk_left` and `carry_walk_right`. Art
  comes from an authored `SpriteFrames` or from `art/characters/stella/<state>/`.
  A missing direction is mirrored, and a missing walk falls back to the still
  with a bob. A carried-Lemon overlay is shown when there is no carry art.
- `AmbientMotion`: sine sway, bob and skew plus optional drift.
- `AmbientFlicker`: alpha pulse or flicker.
- Both ambient components stop working while hidden.

### Boot

- `scenes/boot/boot.tscn` (`scripts/boot/boot.gd`) is the main scene: black, then
  the title fades in as `AudioManager.set_music(&"fellwell_theme")` starts the
  theme, holds (a click or key skips), and fades. The game cuts to black, changes
  to `first_room`, and `ScreenFader` (an autoload, so it outlives the boot scene)
  fades the room in.
- **Intro insertion point:** `intro_scene`. Any scene whose root emits `finished`
  plays in `IntroSlot` between the title and the room. Nothing in the rooms
  changes.
- Optional title art at `art/ui/title.png` replaces the text title.

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
| Island map (node `Photograph`) | Plain Interactable on the map above the desk. It still uses `photograph.tres` ("Grandad. He's trying very hard not to smile…"), which needs new lines for a map. |
| Trunk (node `Cupboard`) | Plain Interactable on the trunk at the foot of the bed ("Open Trunk"), with the cupboard lines. |

## Scene structure

```
StellasRoom (Node2D, stellas_room.gd: wires mouse hover to the prompt)
├── Background                       not tinted
│   ├── WindowView                   outside view: Day / Night variants, clouds, glints, lighthouse
│   └── RoomArt (ArtSlot)            room painting (day/night); Placeholder is tinted by night
├── Lit (TimeOfDayTint)              everything below is tinted together
│   ├── WallObjects
│   │   ├── Window (Interactable): Reach, Visual (ArtSlot), Hotspot, ApproachPoint
│   │   └── Photograph (Interactable): Reach, Visual (ArtSlot), Hotspot, ApproachPoint
│   ├── Objects (y_sort_enabled)
│   │   ├── Bed / Telescope / Cupboard   (each: Reach, Body/Footprint, Visual ArtSlot, Hotspot, ApproachPoint)
│   │   ├── Lemon                        (Reach, Visual ArtSlot, Hotspot; approaches her directly)
│   │   └── Stella (stella.tscn)
│   │       ├── FeetCollision, Shadow
│   │       ├── Visual (CharacterArt) → Placeholder, CarriedLemon (ArtSlot)
│   │       └── InteractionDetector/Reach
│   └── Foreground (ArtSlot)         occluders always in front (placeholder plant)
├── RoomBounds (StaticBody2D)
│   ├── WalkableOutline              the one authored floor shape
│   └── Floor (WalkableFloor)        navigation polygon built from the outline
├── Lighting                         MULTIPLY vignettes; ADD sunbeam/lamp/moonlight; motes
├── RoomAudio                        day/night music + ambience mix
├── Perspective (RoomPerspective)    depth → character scale
├── PointAndClick (PointAndClickInput)
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
  - Stella's and Lemon's installed art is interim and doesn't match the
    canonical character sheet. Canonical sprites are still to be produced; until
    the old files are removed, the canonical-colour blockouts stay hidden.
  - Stella has no walk frames yet; her stills bob while walking.
  - Painted foreground furniture can't occlude her, so the walkable outline
    keeps her clear of it.
  - Ambience and SFX are synthetic placeholders. The theme
    (`audio/music/fellwell_theme.mp3`) is the real track.
- **Art only appears at runtime.** `ArtSlot` and `CharacterArt` load their files
  when the game runs, so the editor still shows placeholders. Making them
  `@tool` scripts would allow in-editor previews.
- **`--quit-after` warnings.** Quitting via `--quit-after` (or `get_tree().quit()`
  directly) while ambience is playing prints Godot 4.3 "leaked playback"
  warnings. Normal window closes go through `AudioManager.stop_all_and_quit()`
  and exit cleanly.
- **No gamepad support.** Mouse is primary and keys are a debug fallback (and
  drive dialogue and the telescope). A gamepad would need a cursor or a
  hotspot-cycling scheme.
- **Hover is by hotspot polygon only.** Overlaps are settled by
  `hotspot_priority`, then the object nearer the front. There is no pixel-perfect
  picking against the art.
- **Navigation avoids walls, not people.** Stella walks through floor-Lemon,
  which has no collision.
- **Lemon drop position isn't validated.** Lemon is placed beside Stella's feet
  and can visually overlap furniture if Stella stands right against it.
- **Input routing relies on lock checks.** World clicks are ignored while any
  control lock is held. The telescope view ignores input while dialogue is open
  by checking `DialogueManager.is_active()`. With more overlay modes, a small
  modal/input stack would be cleaner.
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
5. Add gamepad support (a virtual cursor or hotspot cycling).
6. Drop in Stella's walk frames and the theme music following
   `art-direction.md`, then retune walk speed against the walk cycle.
7. Make `ArtSlot` and `CharacterArt` `@tool` scripts so artists can see real
   art in the editor.
