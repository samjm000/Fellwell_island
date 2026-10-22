# Development

How to set up, where things go, and how to add art, process animations and run
the tests. The repository is the source of truth for code and runtime assets;
nothing the game needs lives in temporary or download folders.

## Setup

- **Engine:** Godot **4.3-stable** (standard build, GDScript, Compatibility
  renderer).
- **On Linux/WSL:**

  ```bash
  git clone git@github.com:samjm000/Fellwell_island.git Fellwell && cd Fellwell
  tools/setup_dev_environment.sh          # installs Godot 4.3 to ~/.local/share/fellwell/godot-4.3, imports the project
  tools/godot.sh --path .                 # run the game
  tests/run_tests.sh                      # run the regression suite
  ```

  The Godot binary is never committed. Set `GODOT=/path/to/godot` to use your
  own 4.3 build; every script resolves it through `tools/godot.sh`.
- **On Windows/macOS:** open `project.godot` in Godot 4.3. The shell tools need a
  bash shell (WSL or Git Bash).

## Layout

```
art/              runtime images (backgrounds, characters, telescope, ui)
audio/            runtime audio (music, ambience, sfx)
assets_source/    originals the runtime assets come from (ignored by Godot via .gdignore)
  character_sheets/   animation sheets per character
  concept_art/        canonical designs, future locations
  references/         reference material; deprecated/ holds superseded designs
scenes/ scripts/ data/   game scenes, code, dialogue
tests/            regression suite and screenshot capture
tools/            setup, Godot wrapper, art/animation processing, placeholder audio
docs/             design, art direction, asset manifest, this file
_incoming/        quarantined files from other tools (git-ignored; never touch)
```

`docs/asset-manifest.md` lists every major asset, its status and its source.

## Adding art

1. **Put the original in `assets_source/`** (unless the runtime file is the
   untouched original; then don't duplicate it, just record it in the manifest).
2. **Produce the runtime file in `art/`** at the path the game expects (see
   `docs/art-direction.md`, *Where assets go*). Missing files fall back to
   placeholders, so art can arrive one piece at a time.
3. **Use a committed tool for any processing.** Never use one-off scripts:
   - `tools/import_art_pack.gd`: copies and downscales an art pack's runtime
     images.
   - `tools/process_stella_animations.gd`: turns animation sheets into frames
     (below).
4. **Re-import and test:** `tests/run_tests.sh --import`. This also catches any
   scene still pointing at a moved file.
5. **Record it** in `docs/asset-manifest.md`.

Room paintings need the day and night versions to share one composition:
hotspots, approach points and the walkable floor are authored once for both.
When a room's painting changes, re-author those in the room scene and check them
with `tests/capture_screenshots.sh` (`02_day_authoring_overlay.png`).

## Stella's animations

All of Stella's animations come from one video,
`assets_source/character_video/stella/stella_walk_and_pickup.mp4` (20 s, 24 fps,
made with Gemini): she stands, walks on the spot, then Lemon appears and Stella
kneels, picks her up and walks carrying her. The camera never moves.

To regenerate the frames (after changing the video or the frame ranges):

```bash
tools/extract_stella_video.sh      # every frame, background removed -> .godot/stella_video_frames/
tools/godot.sh --headless --path . --script tools/process_stella_animations.gd
tests/run_tests.sh --import
```

The extract script needs ffmpeg (`$FFMPEG`, else on PATH) and a C compiler: it
builds `tools/video_matte/video_matte.c`, which removes the off-white
background, floor grid and shadow by filling in from the frame edges, so the
fill stops at her outlines and never reaches her white socks, soles or eyes.
Background enclosed by her (between the legs, under an arm, between her and
Lemon, behind a stray strand of hair) is found separately. To check what it
removes, run with `VIDEO_MATTE_DEBUG=1` and an output folder: removed pockets
come out magenta.

The Godot tool cuts every frame from the same part of the video (`SOURCE_RECT`),
scales it so she stands 384 px tall, and keeps the video's own framing, so
frames never jump against each other. `ANIMATIONS` lists the video frames each
animation uses (every other frame, so 12 fps, on twos), with fps and looping. It writes:
- the frames;
- `stella_frames.tres`;
- Lemon's floor sprite, cut from the first pickup frame;
- `manifest.json`;
- QA contact sheets and a report, in `user://stella_animation_qa/` (or a folder
  you pass as the second argument).

The report also gives values to copy into scenes when they change: Stella's
`Visual.art_offset.y` (her feet are a few px above the canvas bottom, room for
the near foot in the three-quarter view), `walk_ground_speed`, and Lemon's
`pickup_offset` and lift frame (`lemon.gd`).

Walk cycles play as fast as she actually moves (`CharacterArt.walk_ground_speed`:
the speed the planted foot slides back in the video), so her feet don't slide at
any walking speed or depth.

To watch the animations in motion, run `scenes/debug/stella_animation_test.tscn`
(F6 in the editor, or `tools/godot.sh --path . res://scenes/debug/stella_animation_test.tscn`).
It's a plain floor with a 32 px ruler, so sliding feet show against it, and a
readout of the state, animation, frame, fps, speed and facing. Click or use
WASD/arrows to walk; C toggles carrying Lemon, K plays the pickup or put-down,
T runs a tour of every state, 1/2/3 set the game speed to 100/50/25% and Z
switches between the room's scale and 1:1.

## Tests

```bash
tests/run_tests.sh                     # all; exits non-zero on failure
tests/run_tests.sh tests/test_lemon.gd # one file
tests/run_tests.sh --import            # force a re-import first
tests/capture_screenshots.sh [dir]     # reference screenshots (needs a display)
```

Coverage and how to write a test: `tests/README.md`. Logs go to
`.godot/test_logs/`. Run the suite before every commit that touches gameplay or
assets.

## Music

The Fellwell Island theme is `audio/music/fellwell_theme.mp3` ("Found at Low
Tide"). To replace it, save the new track under the same name (`.ogg`, `.mp3`
or `.wav`; keep only one) and re-import. It starts on the title card and carries
on through Stella's room without restarting. Every music and ambience id is in
`docs/art-direction.md`, *Audio*.

## Git, assets and LFS

- **What's tracked:** all runtime art and audio, source sheets and concept art,
  scenes, resources and `.import` files, tests, tools and docs.
- **What's ignored:** `.godot/` (import cache, logs, screenshots), exports, editor
  temp files, OS junk, local Godot binaries and `_incoming/` (`.gitignore`).
- **No Git LFS, for now.** Runtime assets are about 18 MB, the largest file is
  4 MB, and the whole repository is about 60 MB. Plain Git handles that well, and
  LFS would add an install step and a GitHub bandwidth quota. Switch when any of
  these happens:
  - video files (`.mp4`, e.g. the intro) are added;
  - a single file exceeds about 25 MB;
  - the repository passes about 500 MB.

  Then install `git-lfs`, run `git lfs install`, and run
  `git lfs track "*.mp4" "*.png" "*.wav" "*.ogg" "*.mp3"` (commit
  `.gitattributes`). Moving existing history into LFS (`git lfs migrate`)
  rewrites history and needs everyone's agreement.
- **Commits:** small and focused, with conventional prefixes (`feat:`, `fix:`,
  `test:`, `docs:`, `chore:`). Never force-push `main`.

## Remote

**GitHub is the source of truth for Fellwell Island.** The canonical repository
is `git@github.com:samjm000/Fellwell_island.git`, and `main` is the canonical
development branch.

```bash
git clone git@github.com:samjm000/Fellwell_island.git Fellwell
```

SSH needs your public key (`~/.ssh/id_ed25519.pub`) added on GitHub under
*Settings → SSH and GPG keys*; check it with `ssh -T git@github.com`.

- **What belongs in the repository:** approved game code, scenes, documentation,
  tests, source artwork and game-ready assets.
- **`_incoming/` stays ignored and quarantined.** Files there are promoted into
  the project only after they've been reviewed, by deliberately adding them in
  their proper place (see *Adding art*).
- **Large video and source-media files** (e.g. `.mp4` intro videos, long audio
  masters) are not simply added to normal Git history. Flag them for review
  first; if they belong in the repository, set up Git LFS for them before the
  first commit (see *Git, assets and LFS*).
- **Never committed:** local Godot binaries, the `.godot/` cache, export output,
  credentials, and generated temporary files.
- **No commit or push without the project owner's approval.** Run
  `tests/run_tests.sh` before every push, and push normally; never force-push.

## Inventory and bedroom preparation

`InventoryItem` resources hold `id`, `display_name`, `description`, and optional
`icon`. Author definitions under `data/items/`; pickups call
`GameState.add_item(&"stella", item)` after the backpack is acquired. Duplicate
IDs are rejected per owner. `has_item`, `remove_item` and `inventory_items` accept
an explicit character (`stella` or `max`). Returned arrays are copies. Item use
and combination are not implemented pending their design decision.

`BackpackUI` is attached by `Room`, so inventory remains available across rooms
but not on the title. It owns an `inventory` input lock while open, and releases
it on close or room destruction. WardrobeView follows the same lifecycle and
uses an AudioManager override to restore the prior music when closed.

Story state and inventory survive room transitions, not application restarts:
there is still no disk save system. `GameState.reset()` clears both.
Regenerate the prototype disco with `python3 tools/generate_mouse_disco.py`.
