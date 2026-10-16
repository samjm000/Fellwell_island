extends "res://tests/framework/test_case.gd"
## The Stella animation test stage: it loads, and the debug keys drive her through
## every walk direction, carrying and not, with the right animation and facing.

const STAGE := "res://scenes/debug/stella_animation_test.tscn"


func before_each() -> void:
	GameState.reset()
	room = load(STAGE).instantiate()
	get_tree().root.add_child(room)
	get_tree().current_scene = room
	stella = room.get_node("%Stella")
	point_and_click = room.get_node("%PointAndClick")
	await wait_physics_frames(3)


func art() -> CharacterArt:
	return stella.get_node("%Visual")


## Holds a movement key and reports the animation and mirroring shown while moving.
func walk(action: StringName) -> Array:
	Input.action_press(action)
	await wait_physics_frames(20)
	var seen := [art().shown_animation(), art().scale.x < 0.0]
	Input.action_release(action)
	await wait_physics_frames(30)
	return seen


func test_stage_shows_canonical_art() -> void:
	check(not art().get_node("Placeholder").visible, "real art, not the blockout")
	check_eq(art().shown_animation(), &"idle_right", "standing: idle")
	check(not (room.get_node("%Readout") as Label).text.is_empty(), "the readout is filled in")


func test_every_direction() -> void:
	check_eq(await walk(&"move_right"), [&"walk_right", false], "walk right: walk_right, not mirrored")
	check_eq(art().shown_animation(), &"idle_right", "stopped: idle")
	check_eq(await walk(&"move_left"), [&"walk_right", true], "walk left: walk_right, mirrored")
	check_eq(await walk(&"move_up"), [&"walk_right", true], "walk up: the side walk, keeping the last facing")
	check_eq(await walk(&"move_down"), [&"walk_right", true], "walk down: the side walk, keeping the last facing")


func test_carrying() -> void:
	var key := InputEventKey.new()
	key.physical_keycode = KEY_C
	key.pressed = true
	get_viewport().push_input(key)
	await wait_physics_frames(2)
	check(GameState.is_lemon_carried, "C picks Lemon up")
	check_eq(art().shown_animation(), &"carry_idle_right", "carrying, standing: carry idle")
	check_eq(await walk(&"move_right"), [&"carry_walk_right", false], "carry walk right")
	check_eq(await walk(&"move_left"), [&"carry_walk_right", true], "carry walk left: mirrored")


func test_tour() -> void:
	var key := InputEventKey.new()
	key.physical_keycode = KEY_T
	key.pressed = true
	get_viewport().push_input(key)
	check(await wait_until(func() -> bool: return room._tour_step == "carry walk left", 40.0, "the tour reaches carry walk"),
			"T tours every state through to carry walk")
	await wait_physics_frames(20)
	check_eq(art().shown_animation(), &"carry_walk_right", "the tour's carry walk plays")
	get_viewport().push_input(key)
	await wait_physics_frames(2)
	check_eq(room._tour_step, "", "T again stops the tour")
	check(not stella.is_walking(), "...and Stella")
