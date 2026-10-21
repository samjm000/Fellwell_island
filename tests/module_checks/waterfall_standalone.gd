extends SceneTree
## Headless check: godot --headless --path . --script res://tests/test_waterfall.gd
var failures := 0

func check(cond: bool, msg: String) -> void:
	print(("PASS " if cond else "FAIL ") + msg)
	if not cond: failures += 1

func _init() -> void:
	var scene := load("res://environments/waterfall/waterfall.tscn") as PackedScene
	check(scene != null, "waterfall.tscn loads")
	var wf = scene.instantiate()
	root.add_child(wf)
	await process_frame
	var mesh: Mesh = wf.get_node("Ribbon/Curtain").mesh
	check(mesh != null and mesh.get_surface_count() == 1, "ribbon mesh built")
	check(not wf.is_cave_available(), "cave closed at start")
	var events := []
	wf.cave_available_changed.connect(func(a): events.append(a))
	wf.set_flow_state(wf.FlowState.SLOWING)
	await create_timer(wf.slow_seconds + 0.3).timeout
	check(absf(wf.volume - wf.slow_volume) < 0.02, "slowing reaches slow_volume")
	wf.set_flow_state(wf.FlowState.STOPPED)
	await create_timer(wf.stop_fall_seconds + 0.3).timeout
	check(wf.is_cave_available(), "cave opens after the last water falls")
	check(not wf.get_node("CaveEntrance/CollisionShape2D").disabled, "cave collision enabled")
	wf.set_flow_state(wf.FlowState.RESTARTING)
	await process_frame
	check(not wf.is_cave_available(), "cave closes as soon as water restarts")
	await create_timer(wf.restart_fall_seconds + wf.restart_fill_seconds + 0.5).timeout
	check(wf.state == wf.FlowState.NORMAL and wf.volume > 0.98, "restart returns to normal")
	wf.jump_to(wf.FlowState.STOPPED)
	await process_frame
	check(wf.is_cave_available(), "jump_to(STOPPED) for save games")
	check(events == [true, false, true], "cave signal sequence %s" % [events])
	print("FAILURES: %d" % failures)
	quit(failures)
