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
- Tests act like a player: they send input events (clicks, actions) and read the
  results from game state, nodes and the `DialogueManager.line_shown` signal.
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
