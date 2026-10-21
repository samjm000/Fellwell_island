# Notes for coding agents

Fellwell Island is a 2D point-and-click narrative adventure in **Godot 4.3**
(GDScript only, Compatibility renderer). Read these before changing anything:

- [`README.md`](README.md): controls, implemented systems, project layout, current milestone.
- [`docs/development.md`](docs/development.md): setup, repo layout, adding art, animation processing, tests, Git/LFS policy.
- [`docs/vertical-slice.md`](docs/vertical-slice.md): scene structure, known limitations, *Obvious next tasks*.
- [`docs/game-design.md`](docs/game-design.md): tone, characters, story threads.
- [`docs/art-direction.md`](docs/art-direction.md) and [`docs/asset-manifest.md`](docs/asset-manifest.md): where art and audio go, and asset status.
- [`tests/README.md`](tests/README.md): how the regression suite works and what it covers.

## Working rules

- Run `tests/run_tests.sh` before and after changes; it must pass. Add tests for
  new behaviour in the existing style (drive input like a player, see `tests/framework/`).
  `tools/setup_dev_environment.sh` installs Godot 4.3 if it's missing.
- GitHub (`samjm000/Fellwell_island`) is the source of truth. **Commit or push
  only when the owner approves.**
- Never touch `_incoming/` (quarantined files from other tools).
- Match the surrounding code: autoload singletons in `scripts/systems/`,
  `class_name` scripts with `##` doc comments, authored data as resources in `data/`,
  editor-authored hotspots and approach points on `Interactable` scenes.

## Decisions already made

- **Keep our own engine code.** No Escoria, Popochiu, Dialogic or similar
  framework; they would replace working systems and all need Godot 4.6+.
- **Inventory (next feature, not started):** per-character from the start.
  Stella's items live in her **backpack** (art not drawn yet); **Max**, a
  planned second playable character with a character swap, has a **pouch**.
- **Dialogue (next feature, not started):** grow the existing
  `DialogueManager` (`play` / `say` / `ask`, `scripts/systems/dialogue_manager.gd`)
  into a branching, multi-option system with conditions on story flags,
  items and time, and outcomes such as setting flags and giving items.
  Story flags live in `GameState` (`scripts/systems/game_state.gd`).

Still undecided, so ask the owner before building: how dialogue is authored
(a plain-text script format or Godot resources), how items are used on the world
(item as cursor or drag and drop), whether items combine, and how the backpack
opens (corner icon, key/right-click, or a hover strip).
