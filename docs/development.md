# Development

How to set up, where things go, and how to add art, process animations and run
the tests. The repository is the source of truth for code and runtime assets;
nothing the game needs lives in temporary or download folders.

## Setup

- **Engine:** Godot **4.3-stable** (standard build, GDScript, Compatibility
  renderer).
- **On Linux/WSL:**

  ```bash
  git clone <remote> Fellwell && cd Fellwell
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

## Animation sheets

Stella's sheets live in `assets_source/character_sheets/stella/`:

| Sheet | Animation |
| --- | --- |
| `stella_animation_2.png` | idle |
| `stella_animation.png` | walk |
| `stella_pick_up_lemon.png` | pickup_lemon |
| `stella_holding_lemon.png` | carry_idle |
| `stella_walking_lemon.png` | carry_walk |

To regenerate the frames after replacing a sheet (keep the same file name, or
edit `SHEETS` in the tool):

```bash
tools/godot.sh --headless --path . --script tools/process_stella_animations.gd
tests/run_tests.sh --import
```

The tool finds each pose from transparency, cleans matting specks and halos,
normalises each sheet's scale to the walk sheet (`relative` in `SHEETS`), and
aligns every frame on one canvas with the feet at the bottom centre. It writes:
- the frames;
- `stella_frames.tres`;
- Lemon's floor sprite;
- `manifest.json`;
- QA contact sheets and a measurement report, in
  `user://stella_animation_qa/` (or a folder you pass as the second argument).

Check the contact sheets: the cyan line is the feet anchor and the magenta line
is the floor. Tune fps and frame holds in `SHEETS`, then re-run; don't edit the
generated `.tres` by hand.

### Regenerating the walk cycles (needed)

The current walk and carry-walk sheets don't step: one foot is always behind
and the other always ahead. A usable cycle needs, facing right, on a transparent
background, at the same scale as the idle sheet:

- **6–8 frames for a full cycle (two steps):**
  1. contact (right heel down, legs apart)
  2. down (weight on the right)
  3. passing (left foot passing the right, feet together)
  4. up (pushing off)
  5. contact (left heel down)
  6. down, passing, up, mirrored for the other leg
- **The planted foot** moves backwards by an even amount each frame while it's on
  the floor. That distance, times fps, sets how fast she should walk.
- **Head and hair** stay the same size and style in every frame.
- **Carry walk:** the same leg cycle with Lemon held as in carry idle, keeping her
  tail and LEMON tag in every frame.

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

The repository has **no remote yet**. To publish it on GitHub:

1. Create an empty repository on GitHub, e.g. `fellwell-island`, private, with
   no README, licence or .gitignore, so the histories don't conflict.
2. Authenticate on this machine, either way:
   - **HTTPS:** install the GitHub CLI and run `gh auth login`, or use a personal
     access token when Git asks for a password.
   - **SSH:** add `~/.ssh/id_ed25519.pub` to GitHub (*Settings → SSH keys*). If
     you need a key first, run `ssh-keygen -t ed25519`.
3. Connect and push:

   ```bash
   git remote add origin git@github.com:<you>/fellwell-island.git   # or https://github.com/<you>/fellwell-island.git
   git push -u origin main
   ```
