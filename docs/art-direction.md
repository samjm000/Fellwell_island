# Fellwell Island: Art & Audio Direction

How Fellwell should look and sound, and exactly where new art and audio go so
they show up in the game without code changes.

## Visual tone

- **Warm, cosy, funny and slightly mysterious.** It should feel like a
  storybook, painted rather than pixel art.
- **A coastal British island:** whitewashed cottages, washing lines, a
  lighthouse, a grey-green sea, wind, gulls, a mountainside above the harbour.
- **Visually rich but readable.** Interactive props should stand out from the
  background through value and edge contrast, not outlines or glow.
- **Inspired by classic narrative adventures**, without copying any particular
  game's characters or art.
- **Night is a showcase, not a dimmer switch.** Pair a moonlit blue exterior with
  warm interior lamplight, deepen the shadows, and let lights glow: the
  lighthouse, houses across the bay, and the offshore light.

## Day / night look

| | Day (afternoon) | Night |
| --- | --- | --- |
| Exterior | Golden, slightly hazy sky; bright sea with glints | Deep blue sky, stars, moon path on the water, house lights across the bay, lighthouse |
| Interior | Warm cream walls; a sunbeam with dust motes through the window | Cool blue fill with a warm pool of lamplight by the bed; moonlight from the window; darker corners |
| Mood | Lazy, cosy, a little comic | Quiet, beautiful, curious |

Implementation (all event-driven from `TimeManager.phase_changed`):

- **Room painting:** day and night versions swap automatically through `ArtSlot`.
- **`Lit` layer tint:** Stella, props and wall objects are painted in neutral
  light and tinted warm by day and blue by night (`Lit` → `TimeOfDayTint`).
- **Lighting overlays:** multiply vignettes, plus additive sunbeam, lamp glow,
  moonlight and particles.
- **Telescope:** separate day and night paintings with animated overlays.

## Room layering rules

Draw order in `scenes/rooms/stellas_room.tscn`, back to front:

```
Background            not tinted
  WindowView          animated outside view (hidden: the painted window is opaque)
  RoomArt             room painting (ArtSlot, day/night): furniture is painted in
Lit                   tinted as one unit for time of day (Stella, Lemon)
  WallObjects         window and photograph interaction zones
  Objects (Y-sorted)  bed / telescope / cupboard zones, Lemon, Stella
  Foreground          cut-out occluders that are always in front (none supplied yet)
Lighting              overlays: MULTIPLY = shadow, ADD = light
  Vignette (day / night), softened for the paintings
  Day: dust motes in the painted window light
  Night: flicker on the painted wall lantern, motes near the window
UI (CanvasLayer)      interaction prompt
```

Rules:

1. **The room paintings are shown exactly as authored.** They are never tinted;
   overlays only add a little life (motes, lantern flicker) and soft vignettes.
2. **Furniture painted into the room** keeps its gameplay node (interaction zone
   and prompt), but its `Visual` placeholder and collision footprint are switched
   off on the room instance. Walking limits come from the `RoomBounds/WalkableOutline`
   polygon traced around the painted floor.
3. **Characters live in `Lit`** and are tinted for night (`Lit` → `night_color`),
   so warmly-lit character art sits in the blue night painting.
4. **Painted foreground pieces can't hide Stella.** The walkable outline keeps her
   clear of the trunk, chair and desk. To let her pass behind something, supply it
   as a transparent cut-out PNG for the `Foreground` slot
   (`art/backgrounds/stellas_room/foreground.png`, TL, 1280×720).
5. **Anything that emits light goes in `Lighting`**, aligned to a painted light
   source, so the night tint never dulls it.
6. **Ambient motion stays subtle.** Use `AmbientMotion` for sway and drift and
   `AmbientFlicker` for pulses and flicker. Both only run while visible.
7. **A transparent painted window** would show the animated `WindowView` behind
   it; unhide that node if a future painting leaves the glass clear.

If a new room painting changes the layout, re-trace `WalkableOutline` and move
the interaction zones and prompts to match (a 40 px grid over the painting
scaled to 1280×720 makes this quick).

## Where assets go

Images can be PNG or WebP. Large source paintings are fine: set `art_scale` on
the slot. Character art is downscaled when imported (see *Importing an art pack*
below). Anchors: **BC** means bottom-centre at the node origin (the floor contact
point); **TL** means top-left; **C** means centred.

| Asset | Path | Anchor / scale | Notes |
| --- | --- | --- | --- |
| Room, day | `art/backgrounds/stellas_room/day.png` | TL, 1672×941 at 0.7656 | Installed: the attic bedroom, from `Concept Art/Stella_room_day` |
| Room, night | `art/backgrounds/stellas_room/night.png` | TL, 1672×941 at 0.7656 | Installed: from `Concept Art/Stella_room_dark`; same composition as day (required: hotspots and the floor are shared) |
| Room foreground | `art/backgrounds/stellas_room/foreground.png` | TL, 1280×720 | Optional cut-out occluders; not supplied |
| Stella | `art/characters/stella/<state>/frame_0001.png`, `frame_0002.png`, … | BC, 0.5634 (≈380 px tall) | Idle and carry_idle installed; see below |
| Lemon in the room | `art/characters/lemon/idle.png` | BC, 0.445 (≈130 px tall) | Installed (art pack v1) |
| Lemon in Stella's arms | `art/characters/lemon/lemon_carried.png` | C | Unused: Stella's carry art includes Lemon |
| Telescope, day | `art/telescope/day.png` | C, 1448×1086 at 0.663 | Installed; includes its own eyepiece ring |
| Telescope, night | `art/telescope/night.png` | C, 1448×1086 at 0.663 | Installed; painted lighthouse beam and offshore light are enhanced by overlays aligned to them |
| Separate props | `art/props/*.png` | BC / C | Not needed while furniture is painted into the room |
| Title card | `art/ui/title.png` | Centred, fitted to the screen | Optional; the boot scene shows the text title "Fellwell Island" until it exists |
| UI font | `art/ui/fonts/…` | | Set as `default_font` in `art/ui/fellwell_theme.tres` |

Any slot whose file is missing keeps its node-built placeholder, so art can
arrive one piece at a time.

**Telescope paintings and the offshore light.** The `OffshoreLight` and
`LighthouseLampGlow` overlays in `scenes/ui/telescope_view.tscn` are positioned on
the painted lights. The story trigger relies on the `OffshoreLight` node, so if
the night painting changes, move that node onto the new light rather than
removing it.

### Importing an art pack

`tools/import_art_pack.gd` copies runtime images from a pack folder into the
project, downscaling the character art (Stella 50%, Lemon 25%). It colour-bleeds
transparent edges first so resizing doesn't darken them. Reference sheets and
source files stay in the pack, not the repo.

```
godot --headless --path . --script tools/import_art_pack.gd -- "<pack folder>"
```

Add new entries to its `ENTRIES` list when a pack adds files. The v1 entries
for Stella and Lemon are the interim, non-canonical art described below; drop
them once canonical sprites replace it, so a re-import can't bring it back.

### Canonical character designs

The source of truth for Stella and Lemon is the **Fellwell Island Character
Asset Sheet** (`Concept Art/stella_lemon_concept.png`, kept with the art packs,
outside the repo). It covers proportions, colours, outfit, hair, face and the
overall style.

- **Stella:** brown, wavy, shoulder-length hair with short bangs; large brown
  eyes; a yellow-and-white striped T-shirt with multicoloured trim on the
  sleeves; blue denim shorts; white socks; pink high-top trainers; a small beaded
  necklace.
- **Lemon:** a soft, golden toy dog with fluffy fur and dark eyes, a blue collar
  and a round yellow tag reading LEMON. This follows the latest direction: soft
  golden rather than the sheet's paler cream.

The sheet is concept art (opaque background, overlapping labels and figures), not
sprites, so nothing is cut out of it. Character art is supplied, never generated
in the project.

**No character sprites are installed.** The earlier interim images (Stella with a
bun and pinafore, and a golden retriever Lemon) were removed because they didn't
match the canonical direction; they remain in git history. Until canonical
sprites arrive, the game shows **canonical-colour blockouts**: the `Placeholder`
nodes in `scenes/characters/stella.tscn` (Stella, and Lemon in her arms) and
`scenes/interactables/lemon.tscn`. These are flat shapes in the canonical
palette, at the art's size and foot position. Dropping sprites into the paths
below replaces them with no other change.

**Sprites still to be produced** (transparent PNG, matching the sheet):

| Asset | Path | Canvas / on-screen size |
| --- | --- | --- |
| Stella standing | `art/characters/stella/idle/frame_0001.png` (+ more frames for a loop) | 561×701 at `art_scale` 0.5634, ≈380 px tall |
| Stella holding Lemon | `art/characters/stella/carry_idle/frame_0001.png` | as above, Lemon held at chest height |
| Stella walking | `walk_right/` (and optionally `walk_left/`), ≈8 frames | as above |
| Stella walking with Lemon | `carry_walk_right/` (and optionally `carry_walk_left/`) | as above |
| Lemon sitting on the floor | `art/characters/lemon/idle.png` | 281×351 at `art_scale` 0.445, ≈125×156 px |

Keep the canvas sizes and the feet at the bottom-centre, or adjust `art_offset`
on `Stella/Visual` and `Lemon/Visual`. Then hotspots, prompts, collisions and
scale all keep working unchanged.

### Character art (Stella)

- Paint her **facing right** unless a state is explicitly a left one. Every frame
  of a state uses the same canvas size, with her boots near the bottom-centre.
  `art_offset` on `Stella/Visual` corrects any margin.
- **States**, each in its own folder as `frame_0001.png`, `frame_0002.png`, …:

  | Folder | Use |
  | --- | --- |
  | `idle/` | Standing |
  | `walk_left/`, `walk_right/` | Walk cycle in each direction |
  | `carry_idle/` | Standing, holding Lemon |
  | `carry_walk_left/`, `carry_walk_right/` | Walking while holding Lemon |
  | `walk/`, `carry_walk/` | Optional undirected cycles, facing right (the art pack's layout) |

  Walk cycles play at `frames_per_second` (8) and idle loops at
  `idle_frames_per_second` (4), both on `Stella/Visual`. Flat names such as
  `idle.png` or `walk_right_0.png` also work.
- **Fallbacks:**
  - A missing direction is mirrored from the other one, then from `walk/`.
  - With no walk frames at all, the matching still (`idle` or `carry_idle`) is
    shown with a small walking bob. The image is never stretched or deformed.
  - The bob switches off automatically once walk frames are installed.
- **Size and depth:** her art is ≈380 px tall at `art_scale`. Each room's
  `Perspective` node sizes her for its painting, about her feet. Stella's room is
  deep, so she runs from 0.66 at the back of the floor (≈250 px, beside the
  desk) to 0.86 at the front (≈325 px). Tune those values there, not in the
  art.
- **Carrying Lemon:** if there's no `carry_*` art, the separate
  `lemon_carried.png` is shown in her arms instead.
- **More control:** an artist can author a `SpriteFrames` resource in the editor,
  with the same animation names, and assign it to `sprite_frames` on
  `Stella/Visual`.
- **Design status:** see *Canonical character designs* above. Replacement frames
  drop into the same folders.

### Lemon

Lemon is a toy whom Stella treats as a real dog. Paint her as on the character
direction above: a small, soft, golden, fluffy dog. Nothing in the game
should state outright that she is a toy.

## Audio

### Buses (`default_bus_layout.tres`)

`Master` ← `Music`, `Ambience`, `SFX`, `UI`. `AudioManager.set_bus_volume()` and
`set_bus_muted()` are the hooks for a future settings menu.

### Folders and names

Sounds are referenced by id. A file named after the id is picked up
automatically; `.ogg`, `.mp3` and `.wav` are all accepted.

| Folder | Use | Ids used now |
| --- | --- | --- |
| `audio/music/` | Music, looped | `stellas_room_day`, `stellas_room_night`, `telescope_mystery` (optional night motif), `fellwell_theme` (fallback for any missing track) |
| `audio/ambience/` | Looping layers | `sea`, `wind`, `night_insects` |
| `audio/ambience/` | Occasional one-shots | `gull`, `room_creak` (variations as `_1`, `_2`, …) |
| `audio/sfx/` | One-shots | `footstep` (`_1`–`_4`), `interact`, `lemon_pick_up`, `lemon_put_down`, `telescope_open`, `telescope_close`, `cupboard_open`, `bed_rustle`, `sleep_transition`, `ui_confirm`, `ui_select`, `ui_cancel` |

**Dropping in the Fellwell Island theme:** save it as
`audio/music/fellwell_theme.ogg` (re-import with `tests/run_tests.sh --import` or
by opening the editor). The boot scene starts it as the title fades in. Stella's
room asks for `stellas_room_day` / `stellas_room_night`, which fall back to the
theme, so the same track simply carries on: into the room, across sleep and
through the telescope. If a `telescope_mystery` track is added, it takes over
while looking out at night, and the theme then fades back in where it left off.
Installed: "Found at Low Tide" as `audio/music/fellwell_theme.mp3`, with
looping on in its import settings. If the file is ever missing, boot logs that
the theme is awaited and the game plays without music.

**Intro animation or video:** see `Boot.intro_scene` in
`docs/vertical-slice.md`. The intro is a scene whose root emits `finished`; it
plays between the title and the room.

**Where each sound's volume is set:**
- Room music and ambience mix: the `RoomAudio` node in each room.
- Telescope mix and motif: the `Audio` export group in `telescope_view.gd`.
- Individual SFX ids: exports on the objects that play them.

**Formats:**
- Music and ambience should be OGG Vorbis, seamlessly loopable.
  `AudioManager` turns looping on for these streams itself.
- Short SFX can be WAV.

**Placeholders:** the files currently in `audio/ambience/` and `audio/sfx/` are
quiet synthetic placeholders made by `tools/generate_placeholder_audio.py`. They
have no licensing issues. Delete or overwrite them as real audio arrives. There
is no gull yet beyond a synthetic chirp. The theme is real music.

## Performance budget

- **Target:** Godot 4.3 Compatibility renderer on modest hardware.
- **No Light2D, no viewports, no post-processing chains.** Lighting is
  multiply/add overlays on ordinary sprites and polygons.
- **Shaders:** one cheap shader, for the telescope eyepiece.
- **Particles:** `CPUParticles2D` only, with fewer than 30 per effect.
- **Ambient scripts** are a few sines per node and stop when hidden.
- **Gradients:** keep `GradientTexture2D` small (64 px) and let it stretch.
