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
  WindowView          the outside, day/night variants + ambient motion
  RoomArt             room painting (ArtSlot) – window area must be TRANSPARENT
Lit                   tinted as one unit for time of day
  WallObjects         window frame + curtains, photograph
  Objects (Y-sorted)  bed, telescope, cupboard, Lemon, Stella
  Foreground          occluders that are always in front (ArtSlot)
Lighting              overlays: MULTIPLY = shadow, ADD = light
  Vignette (day / night)
  Day: sunbeam, window warmth, dust motes
  Night: lamp glow (flicker), window moonlight, moonbeam, night motes
UI (CanvasLayer)      interaction prompt
```

Rules:

1. **The outside sits behind the room painting.** Leave the window glass
   transparent in room backgrounds so the animated `WindowView` shows through. An
   opaque painted window still works; it simply covers the animated view.
2. **Anything that emits light goes in `Lighting`**, so the night tint never
   dulls it: lamp glows, sunbeams, moonbeams, glowing windows.
3. **Props sit in `Objects`** with their origin at the floor contact point, so
   Y-sorting puts Stella in front of or behind them correctly.
4. **Foreground occluders go in `Foreground`.** Keep them at the screen edges,
   where they won't hide anything interactive.
5. **Ambient motion stays subtle.** Use `AmbientMotion` for sway and drift and
   `AmbientFlicker` for pulses and flicker. Both only run while visible. The
   room should feel alive, not busy.
6. **If the room painting already includes a prop** (for example a painted
   cupboard), untick `placeholder_enabled` on that prop's `Visual` ArtSlot, so
   its placeholder doesn't draw over the painting.

When painted day and night backgrounds arrive:
- `RoomArt/Placeholder`'s tint only affects the placeholder; painted art is
  shown as authored.
- Tune `Lit`'s `night_color` so Stella and props sit naturally in the painted
  night.
- Tune the overlay alphas in `Lighting` to taste, and hide any overlays the
  painting already covers (for example a painted sunbeam).

## Where assets go

Images can be PNG or WebP (SVG is also accepted by `ArtSlot`). Paint at the game
resolution (1280×720 for full screens), or at 2× and set `art_scale` to 0.5 on the
slot. Anchors: **BC** means bottom-centre at the node origin (the floor contact
point); **TL** means top-left.

| Asset | Path | Anchor / size | Notes |
| --- | --- | --- | --- |
| Room, day | `art/backgrounds/stellas_room/stellas_room_day.png` | TL, 1280×720 | Window glass transparent |
| Room, night | `art/backgrounds/stellas_room/stellas_room_night.png` | TL, 1280×720 | Same composition as day |
| Room foreground | `art/backgrounds/stellas_room/stellas_room_foreground.png` | TL, 1280×720 | Mostly transparent; edge occluders only |
| Bed | `art/props/bed.png` | BC | Footprint is 270 px wide |
| Telescope | `art/props/telescope.png` | BC | Footprint is 56 px wide |
| Cupboard | `art/props/cupboard.png` | BC | Footprint is 150 px wide |
| Window frame + curtains | `art/props/window_frame.png` | Centre | Transparent glass |
| Grandad's photograph | `art/props/grandad_photograph.png` | Centre | |
| Lemon in the room | `art/characters/lemon/lemon.png` | BC | Lying down, facing right |
| Lemon in Stella's arms | `art/characters/lemon/lemon_carried.png` | Centre | Only used when Stella has no `carry_*` art |
| Stella | `art/characters/stella/<state>.png` or `<state>_<n>.png` | BC | See below |
| Telescope, day | `art/telescope/telescope_day.png` | TL, 1400×840 | Covers the drift margin |
| Telescope, night | `art/telescope/telescope_night.png` | TL, 1400×840 | **Do not paint** the offshore light, lighthouse beam or water glints |
| UI font | `art/ui/fonts/…` | | Set as `default_font` in `art/ui/fellwell_theme.tres` |

Any slot whose file is missing keeps its node-built placeholder, so art can
arrive one piece at a time.

### Character art (Stella)

- Paint her **facing right**; the game mirrors her for left. Her feet go at the
  bottom-centre of the canvas, and every frame of a state uses the same canvas
  size.
- **States:** `idle`, `walk`, `carry_idle`, `carry_walk` (carrying Lemon).
  - A still: `idle.png`.
  - Animation frames: `walk_0.png`, `walk_1.png`, … played at 8 fps by default
    (`frames_per_second` on `Stella/Visual`).
- **Fallbacks:** `carry_walk` → `carry_idle` → `walk` → `idle`. One `idle.png`
  replaces the placeholder entirely.
- **Carrying Lemon:** if there's no `carry_*` art, the separate
  `lemon_carried.png` is shown in her arms instead.
- **More control:** an artist can author a `SpriteFrames` resource in the editor,
  with the same animation names, and assign it to `sprite_frames` on
  `Stella/Visual`.
- **Scale:** her placeholder is about 130 px tall at 1×; keep painted Stella
  close to that on screen.

### Lemon

Lemon is a toy whom Stella treats as a real dog. Paint her soft and plush (a hint
of stitching is fine), but nothing in the game should state outright that she is
a toy.

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
`audio/music/fellwell_theme.ogg`. It will play in both day and night until
`stellas_room_day` and `stellas_room_night` exist.

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
is no gull yet beyond a synthetic chirp, and no music at all.

## Performance budget

- **Target:** Godot 4.3 Compatibility renderer on modest hardware.
- **No Light2D, no viewports, no post-processing chains.** Lighting is
  multiply/add overlays on ordinary sprites and polygons.
- **Shaders:** one cheap shader, for the telescope eyepiece.
- **Particles:** `CPUParticles2D` only, with fewer than 30 per effect.
- **Ambient scripts** are a few sines per node and stop when hidden.
- **Gradients:** keep `GradientTexture2D` small (64 px) and let it stretch.
