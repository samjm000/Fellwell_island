extends "res://tests/framework/test_case.gd"
## Mouse-first controls: walking, hovering, click-to-interact, redirects and locks.

const NOT_TIRED := "I'm not tired."


func is_on_floor(point: Vector2) -> bool:
	var map := stella.get_world_2d().navigation_map
	return NavigationServer2D.map_get_closest_point(map, point).distance_to(point) < 1.0


func test_click_floor_walks_there() -> void:
	var target := Vector2(720, 660)
	check(is_on_floor(target), "test target is on the floor")
	await click_world(target)
	await wait_physics_frames(2)
	check(stella.is_walking(), "Stella starts walking after a floor click")
	check(await wait_for_walk_end(), "Stella arrives")
	check_near(stella.global_position, target, 1.5, "Stella stands where the floor was clicked")
	check(not DialogueManager.is_active(), "walking alone opens no dialogue")


func test_click_off_floor_walks_to_nearest_floor() -> void:
	# The extreme lower-left edge is outside the floor and wardrobe hotspot.
	var off_floor := Vector2(0, 719)
	check(not is_on_floor(off_floor), "test point is off the floor")
	await click_world(off_floor)
	await wait_for_walk_end()
	check(is_on_floor(stella.global_position), "Stella stays on the floor")
	check(stella.global_position.x < 400.0, "Stella walks toward the click (x=%s)" % stella.global_position.x)


func test_new_click_redirects() -> void:
	var first := Vector2(420, 680)
	var second := Vector2(800, 600)
	await click_world(first)
	await wait_physics_frames(10)
	var after_first := stella.global_position
	await click_world(second)
	await wait_for_walk_end()
	check_near(stella.global_position, second, 1.5, "the newer click wins")
	check(after_first.distance_to(first) > 50.0, "Stella hadn't reached the first target when redirected")


func test_hover_shows_label() -> void:
	var prompt: Control = room.get_node("%InteractionPrompt")
	var telescope := interactable("Telescope")
	await hover_world(hotspot_point(telescope))
	await wait_seconds(0.3)
	check_eq(point_and_click.hovered, telescope, "hovering the telescope")
	check(prompt.visible, "the label shows while hovering")
	check_eq(prompt.get_node("%Label").text, telescope.get_prompt_text(), "label text")
	check(prompt.get_node("%Label").text.begins_with("Look through"), "label names the action")

	await hover_world(Vector2(640, 680)) # Bare floor.
	await wait_seconds(0.3)
	check(point_and_click.hovered == null, "nothing hovered over bare floor")
	check(not prompt.visible, "the label hides off the hotspot")
	# (The cursor shape can't be read back headless; it's checked by hand.)


func test_click_interactable_walks_then_interacts() -> void:
	var bed := interactable("Bed")
	var start := stella.global_position
	await click_world(hotspot_point(bed))
	await wait_physics_frames(2)
	check(stella.is_walking(), "Stella walks to the bed first")
	check(not DialogueManager.is_active(), "no dialogue before she arrives")
	check(await wait_for_dialogue(10.0), "she uses the bed on arrival")
	check(saw_line(NOT_TIRED), "the bed's first line")
	check(stella.global_position.distance_to(bed.get_approach_position()) <= bed.interaction_radius + 1.0,
			"she stopped at the bed's approach point")
	check(stella.global_position.distance_to(start) > 50.0, "she actually walked")
	check_eq(stella.facing, -1.0, "she faces the bed (left)")
	await advance_dialogue()


func test_floor_click_cancels_pending_interaction() -> void:
	await click_world(hotspot_point(interactable("Bed")))
	await wait_physics_frames(5)
	await click_world(Vector2(800, 680))
	await wait_for_walk_end()
	await wait_seconds(0.5)
	check(not DialogueManager.is_active(), "the bed isn't used after redirecting to the floor")


func test_clicks_ignored_while_dialogue_open() -> void:
	await interact_with(interactable("Window"))
	check(DialogueManager.is_active(), "window dialogue opens")
	var position_in_dialogue := stella.global_position
	var lines_before := lines_seen.size()
	await click_world(Vector2(450, 690))
	await wait_physics_frames(20)
	check_near(stella.global_position, position_in_dialogue, 0.5, "a click during dialogue doesn't move Stella")
	check(point_and_click.hovered == null, "nothing is hovered while dialogue is open")

	# Clicks advance the dialogue instead: the first finishes the line's reveal.
	for i in 6:
		if not DialogueManager.is_active():
			break
		await click_world(Vector2(640, 360))
	check(lines_seen.size() > lines_before, "clicking advances to the next line")
	check(not DialogueManager.is_active(), "clicking through closes the dialogue")
	check_near(stella.global_position, position_in_dialogue, 0.5, "advancing dialogue by click doesn't move Stella")


func test_dialogue_choice_by_mouse() -> void:
	var bed := interactable("Bed")
	await interact_with(bed)
	await advance_dialogue()
	await interact_with(bed)
	await advance_dialogue()
	if not check(DialogueManager.is_choosing(), "the sleep question is showing"):
		return
	var options: Container = DialogueManager.get_node("DialogueBox").get_node("%Options")
	await wait_frames(2)
	var not_yet: Control = options.get_child(1)
	await click_screen(not_yet.get_global_rect().get_center())
	await wait_frames(2)
	check(not DialogueManager.is_active(), "clicking 'Not yet' answers the question")
	check(TimeManager.is_phase(GameTime.Phase.DAY), "declining by mouse keeps it DAY")


func test_telescope_by_mouse() -> void:
	var telescope := interactable("Telescope")
	await interact_with(telescope)
	await wait_frames(2)
	var standing_at := stella.global_position
	check(not PlayerControl.has_control(), "the telescope view is open")
	check(await wait_for_dialogue(), "Stella comments")
	for i in 8:
		if not DialogueManager.is_active():
			break
		await click_world(Vector2(640, 360))
	check(not DialogueManager.is_active(), "clicking advances the comment")
	await click_world(Vector2(640, 360))
	await wait_frames(2)
	check(PlayerControl.has_control(), "a click closes the view")
	check_near(stella.global_position, standing_at, 0.5, "the closing click doesn't also walk Stella")

	await interact_with(telescope)
	await wait_frames(2)
	check(await wait_for_dialogue(), "Stella comments again")
	await advance_dialogue()
	await click_world(Vector2(640, 360), MOUSE_BUTTON_RIGHT)
	await wait_frames(2)
	check(PlayerControl.has_control(), "a right click also closes the view")


func test_control_lock_stops_walking() -> void:
	await click_world(Vector2(420, 690))
	await wait_physics_frames(5)
	check(stella.is_walking(), "walking")
	PlayerControl.acquire(&"test_lock")
	await wait_physics_frames(2)
	check(not stella.is_walking(), "a control lock stops the walk")
	var stopped_at := stella.global_position
	await click_world(Vector2(800, 690))
	await wait_physics_frames(10)
	check_near(stella.global_position, stopped_at, 0.5, "clicks are ignored while locked")
	PlayerControl.release(&"test_lock")
	await wait_physics_frames(10)
	check_near(stella.global_position, stopped_at, 0.5, "she doesn't resume the old walk when control returns")


func test_carried_lemon_clicked_in_stellas_arms() -> void:
	var lemon := interactable("Lemon")
	await interact_with(lemon)
	await advance_dialogue()
	check(GameState.is_lemon_carried, "Lemon picked up by clicking her")
	await click_world(Vector2(700, 690))
	await wait_for_walk_end()
	var arms := hotspot_point(lemon)
	check(absf(arms.x - stella.global_position.x) < 80.0 and arms.y < stella.global_position.y - 100.0,
			"carried Lemon's hotspot is up in Stella's arms (%s vs feet %s)" % [arms, stella.global_position])
	await interact_with(lemon)
	check(not GameState.is_lemon_carried, "clicking Lemon in her arms puts her down")
	await advance_dialogue()


func test_authored_approach_points_are_reachable() -> void:
	for node in get_tree().get_nodes_in_group(Interactable.GROUP):
		var target := node as Interactable
		if not target.has_hotspot():
			continue
		var approach := target.get_approach_position()
		var map := stella.get_world_2d().navigation_map
		var reachable := NavigationServer2D.map_get_closest_point(map, approach)
		check(reachable.distance_to(approach) <= target.interaction_radius,
				"%s's approach point %s is within reach of the floor (nearest %s)" % [target.name, approach, reachable])


func test_keyboard_debug_controls() -> void:
	check(PlayerControl.keyboard_debug_enabled(), "keyboard debug controls are on in debug builds")
	var start := stella.global_position
	await hold(&"move_right", 20)
	check(stella.global_position.x > start.x + 20.0, "WASD still moves Stella in debug builds")

	await click_world(Vector2(420, 690))
	await wait_physics_frames(5)
	await hold(&"move_up", 5)
	check(not stella.is_walking(), "debug keys cancel a click-walk")

	await interact_with_keyboard(interactable("Window"))
	check(DialogueManager.is_active(), "E still interacts in debug builds")
	await advance_dialogue()
