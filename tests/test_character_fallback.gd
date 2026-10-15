extends "res://tests/framework/test_case.gd"
## With no character art installed (as when the interim art is removed before
## canonical sprites arrive), the canonical-colour blockouts show and everything
## still plays.


func before_each() -> void:
	await unload_room()
	GameState.reset()
	TimeManager.set_phase(GameTime.Phase.DAY)
	lines_seen.clear()
	if not DialogueManager.line_shown.is_connected(_on_line_shown):
		DialogueManager.line_shown.connect(_on_line_shown)
	room = load(ROOM_SCENE).instantiate()
	room.find_child("Stella", true, false).get_node("Visual").art_directory = ""
	room.find_child("Lemon", true, false).get_node("Visual").texture_path = ""
	get_tree().root.add_child(room)
	get_tree().current_scene = room
	stella = room.get_node("%Stella")
	point_and_click = room.get_node("%PointAndClick")
	await wait_physics_frames(3)


func test_blockouts_replace_missing_art() -> void:
	var art: CharacterArt = stella.get_node("%Visual")
	var lemon := interactable("Lemon")
	check(art.get_node("Placeholder").visible, "Stella's blockout shows without art")
	check(lemon.get_node("%Visual/Placeholder").visible, "Lemon's blockout shows without art")
	check_eq(art.shown_animation(), &"", "no sprite is shown")

	await interact_with(lemon)
	check(GameState.is_lemon_carried, "Lemon can still be picked up")
	await advance_dialogue()
	check(art.carried_overlay.visible, "the carried-Lemon blockout shows in Stella's arms")
	await click_world(Vector2(700, 690))
	await wait_for_walk_end()
	await interact_with(lemon)
	check(not GameState.is_lemon_carried, "and put down")
	await advance_dialogue()
	check(not art.carried_overlay.visible, "the carried blockout hides again")


func test_blockouts_match_art_size() -> void:
	var placeholder: Node2D = stella.get_node("%Visual/Placeholder")
	var top := 0.0
	for part in placeholder.get_children():
		if part is Polygon2D:
			for point: Vector2 in part.polygon:
				top = minf(top, point.y)
	check(top < -360.0 and top > -420.0, "Stella's blockout is about as tall as her art (%.0f px)" % -top)
