# Regression tests

Automated checks for the Stella's room vertical slice, run headlessly against
Godot 4.3. Everything needed lives in the repo; only the Godot binary is kept
outside it.

```bash
tools/setup_dev_environment.sh   # once per machine: installs Godot 4.3, imports the project
tests/run_tests.sh               # every test file; exits non-zero on any failure
tests/run_tests.sh tests/test_lemon.gd   # one file
tests/run_tests.sh --import      # re-import assets first (after adding art/audio)
```

Godot is found through `tools/godot.sh`: `$GODOT` if set, else the copy installed
by the setup script (`~/.local/share/fellwell/godot-4.3/`), else `godot` on PATH.

## How it works

- `framework/runner.tscn` runs the `test_*` methods of the test scripts given on
  the command line. `run_tests.sh` starts one Godot process per file, with
  `--fixed-fps 60` so game time is deterministic and runs faster than real time.
- Every test starts from a fresh Stella's room by day with a clean `GameState`
  (`framework/test_case.gd`, `before_each()`).
- Tests act like a player: they send input events (mouse motion and clicks,
  actions) and read the results from game state, nodes and the
  `DialogueManager.line_shown` signal.
- New `class_name` scripts and new assets need an import before they're
  visible. `run_tests.sh` re-imports by itself when anything under `scripts/`,
  `tests/`, `scenes/`, `art/` or `audio/` is newer than the last import.
- A file fails when a `check()` fails, a test doesn't finish within 60 s of game
  time, or the log contains a script error or leak warning. Logs are written to
  `.godot/test_logs/` (git-ignored).

## Coverage

| File | Covers |
| --- | --- |
| `test_lemon.gd` | pick up, carried visual state, put down |
| `test_bed.gd` | protest → tired → question, declining, sleeping DAY → NIGHT, bed at night |
| `test_telescope.gd` | day view, night view, offshore light only at night, `seen_offshore_light`, leaving the view |
| `test_dialogue_lock.gd` | dialogue blocks player control; overlapping control locks |
| `test_time_of_day.gd` | room art, lighting, tint and dialogue follow DAY/NIGHT |
| `test_point_and_click.gd` | click-to-walk, off-floor clicks, redirects, hover labels, walk-then-interact, cancelling, clicks during dialogue, mouse choices, telescope exit by click, control locks, carried Lemon, reachable approach points, debug keys |
| `test_character_art.gd` | directional states, mirroring fallbacks, the bob only without walk frames, depth scale |
| `test_stella_animation.gd` | real frames installed on one canvas, walk/idle switching, left/right mirroring, vertical walks keep facing, the pickup (lock, timing of the carried state, Lemon handover position and facing), carry walk, put-down restoring the floor sprite, depth scaling of the whole visual |
| `test_stella_animation_scene.gd` | the animation test stage loads with real art; its keys drive walk right, left, up and down and carry walk, with the right animation and mirroring; the tour runs and stops |
| `test_perspective.gd` | smaller at the back, feet planted, Lemon scaling with Stella |
| `test_boot.gd` | boot is the main scene, title then room, skipping, the intro insertion point, no errors without the theme |
| `test_house.gd` | Stella's house: bedroom → hall → kitchen → hall → garden and back, by day and night (right room, arrival spot and facing, control returned); changing the time keeps her place; Lemon carried through every room, and left where she's put down; exits clicked from a distance and repeatedly; clicks during the fade; a new click cancelling an exit; no bounce-back; the garden gate hook; the Look lines; every approach point, start and arrival on the floor and every exit reachable from every arrival |
| `test_music.gd` | the theme (a generated stand-in) starts at boot and never restarts through the room, DAY → NIGHT or the telescope; ambience mix preserved; an override returns to the theme without restarting |

Interactions are driven like a player would: `interact_with()` hovers the
object's hotspot, clicks it, and waits for Stella to walk over and use it.

## Screenshots

`tests/capture_screenshots.sh [OUTPUT_DIR]` (default `.godot/screenshots/`) opens
a window and saves reference shots: the room by day and by night, hover labels,
carrying Lemon, the front and back of the room, a dialogue choice, both telescope
views, and the title. It also saves `02_day_authoring_overlay.png` and
`06_night_authoring_overlay.png`, which draw the floor, hotspots, approach points
and prompt anchors over the art. For Stella's house it saves the same overlay for
the hall, kitchen and garden by day and night (`20_*`), Stella standing at every
exit (`21_*`, `22_*`), and the whole route carrying Lemon (`23_*`).

## Writing a test

```gdscript
extends "res://tests/framework/test_case.gd"

func test_something() -> void:
	await interact_with(interactable("Cupboard"))
	check(saw_line("Jumpers. A lot of jumpers."), "cupboard line")
	await advance_dialogue()
```

Wait out anything the test started (delayed comments, fades) before it ends, so
coroutines aren't left pending when the room is freed.
