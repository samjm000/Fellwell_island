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
| Entrance hall, day / night | `art/backgrounds/entrance_hall/day.png`, `night.png` | TL, 1672×941 at 0.7656 | Installed (Stella's house v1) |
| Kitchen / living room, day / night | `art/backgrounds/kitchen_living/day.png`, `night.png` | TL, 1672×941 at 0.7656 | Installed (Stella's house v1) |
| Cottage exterior, day / night | `art/backgrounds/cottage_exterior/day.png`, `night.png` | TL, 1672×941 at 0.7656 | Installed (the approved exterior concept) |
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

Each pack has a list in its `PACKS` table (`art_pack_v1`, `stellas_house_v1`);
the tool picks the pack whose files are all in the folder, or takes its name as
a second argument. Images at scale 1.0 are copied byte for byte. Add a list
when a new pack arrives. The v1 entries
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

**Installed: Stella's animation set.** Five source sheets (in the designer's
`animations/` folder, outside the repo) are processed into runtime frames by
`tools/process_stella_animations.gd`:

| Source sheet | Animation (SpriteFrames name) | Frames | fps |
| --- | --- | --- | --- |
| `stella_animation_2` | `idle_right` | 4 (frame 1 held, frame 3 blinks) | 5 |
| `stella_animation` | `walk_right` | 6 | 8 |
| `stella_pick_up_lemon` | `pickup_lemon_right` (one-shot) | 6 | 8 |
| `stella_holding_lemon` | `carry_idle_right` | 4 (frame 1 held, frame 2 blinks) | 5 |
| `stella_walking_lemon` | `carry_walk_right` | 6 | 8 |

Lemon's floor sprite (`art/characters/lemon/idle.png`) is cut from the first
pickup pose, where she sits beside Stella. That way the floor sprite and the
pickup frames show the same Lemon in the same place.

To regenerate after the designer replaces a sheet:

```
tools/godot.sh --headless --path . --script tools/process_stella_animations.gd -- "<animations folder>" [qa_dir]
tests/run_tests.sh --import
```

What the tool does, per sheet:
- **Finds the poses** from the alpha channel (separate shapes), not a grid.
  Lemon sitting beside Stella joins her pose.
- **Cleans the matting.** It drops isolated low-alpha specks left by background
  removal. Soft edge pixels with red/yellow halos take the colour of the opaque
  pixels next to them; their alpha is unchanged.
- **Normalises scale.** The sheets were drawn at different sizes. Each is scaled
  relative to the walk sheet, from shoe size and standing height:
  idle 1.22, carry idle 1.165, carry walk 0.966, pickup 0.855. Stella stands
  ≈384 px tall at `art_scale` 1.
- **Aligns the feet.** Every frame shares one 388×415 canvas, with the floor
  contact at the bottom centre. The anchor x is the middle of her thighs, except
  pickup frames 1–4, which are anchored on Lemon so she stays still on the
  floor.
- **Writes QA files** to `qa_dir`: a contact sheet per animation (anchor and
  floor lines) and `report.txt`, with each frame's source box and anchor.

**Animation QA: issues for the designer** (flagged, not hidden). These were the
issues with the old sheets; since 2026-10-18 the animations come from a video
instead (see `docs/development.md`, *Stella's animations*, and the open issues
in `docs/asset-manifest.md`):
- **Walk and carry-walk cycles have no passing pose.** In every frame one foot is
  ≈40–100 px behind the hips and the other ≈20–110 px ahead; the feet never pass
  or move back along the floor. That is six variations of one mid-stride pose, so
  the feet appear to slide at any playback speed. Regenerate as a proper cycle:
  contact, down, passing, up, for each foot.
- **Sheets at different scales**, as above. After normalising, leg length
  matches, but heads differ by about 7%: carry idle and carry walk have larger
  heads than idle and walk.
- **Lemon:**
  - Her tail is missing in carry-walk frames 2–3.
  - She has no name tag in the carry walk, although the tag shows in carry
    idle.
  - In all the sheets she is cream, not the soft golden of the latest direction.
- **Pickup frame 6 → carry idle frame 1:** a cheek-to-cheek hug with eyes closed
  becomes the standard hold, with Lemon lower. Expect a small pop at the end of
  the pickup.
- **Pickup frame 2** had a small separate "!" excitement mark. It was removed as
  a stray shape.
- **Matting:** all sheets had red/yellow halo fringes and scattered specks. They
  are cleaned by the tool, but cleaner source exports would be better.
- **No drop animation:** putting Lemon down plays the pickup backwards.

### Character art (Stella)

- **Layout:** `art/characters/stella/animations/<animation>/frame_NNNN.png`, plus
  `stella_frames.tres` (a SpriteFrames resource, assigned to
  `Stella/Visual.sprite_frames`). Speeds, loops and per-frame durations can be
  tuned there in the editor, but are overwritten when the tool is re-run; tune
  them in `ANIMATIONS` in the tool instead.
- **Facing:** everything is authored facing right. Left is the same frames
  mirrored at runtime: `CharacterArt` flips the whole visual node, which works
  like `flip_h` but also mirrors the carried Lemon. No left-facing copies are
  stored.
- **States:** idle → `idle_right`; moving → `walk_right`; carrying →
  `carry_idle_right` / `carry_walk_right`. Facing only changes when the
  sideways part of her movement is at least `facing_turn_ratio` (35%) of her
  speed, so mostly vertical walks keep the last facing.
- **One-shot actions:** `Stella.perform(&"pickup_lemon_right")` plays an action
  (backwards for a put-down) with the `stella_action` control lock held. Gameplay
  times itself to `action_frame` signals, not timers.
- **Fallbacks remain:**
  - Without `_right` names, `CharacterArt` still reads `idle/`, `walk_left/`,
    `walk/` and the other plain names, mirroring a missing direction.
  - With no walk frames at all, the matching still is shown with a small walking
    bob. It is never used while real walk frames exist.
  - With no art at all, the canonical-colour blockouts (`Placeholder` nodes)
    show.
- **Size and depth:** the room's `Perspective` node scales the whole visual node
  (frames and the Lemon in them) about her feet: 0.66 at the back of Stella's
  room to 0.86 at the front. Frames are never scaled individually.

### Lemon

Lemon's floor sprite is static (she is a toy, and is never animated on her own).
Picking her up is timed to the pickup art:
- Stella walks to the spot beside her where the art draws Lemon. That is
  `pickup_offset` on the Lemon scene, measured by the tool. Stella stands on the
  side Lemon is looking towards, so there is no flip when the art takes over.
- The floor sprite hands over to the pickup frames in frame 1.
- The carried state changes on `lift_frame` (frame 5, when Lemon leaves the
  floor).
- Putting her down plays the pickup backwards. The state changes on
  `set_down_frame` (frame 4), and the floor sprite returns at the end, where the
  art left her, still looking at Stella. Stella turns round first if her side
  has no floor.

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
| `audio/music/` | Music, looped | `stellas_room_day`, `stellas_room_night`, `stellas_house_day`, `stellas_house_night` (hall and kitchen), `garden_day`, `garden_night`, `telescope_mystery` (optional night motif), `fellwell_theme` (fallback for any missing track) |
| `audio/ambience/` | Looping layers | `sea`, `wind`, `night_insects` |
| `audio/ambience/` | Occasional one-shots | `gull`, `room_creak` (variations as `_1`, `_2`, …) |
| `audio/sfx/` | One-shots | `footstep` (`_1`–`_4`), `interact`, `lemon_pick_up`, `lemon_put_down`, `telescope_open`, `telescope_close`, `cupboard_open`, `bed_rustle`, `sleep_transition`, `door_open` (every room exit; not supplied yet), `ui_confirm`, `ui_select`, `ui_cancel` |

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
