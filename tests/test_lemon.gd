extends "res://tests/framework/test_case.gd"
## Picking Lemon up, carrying her, and putting her down.

const PICK_UP_LINE := "Come on, Lemon."
const PUT_DOWN_LINE := "Honestly, I don't know how you sleep this much."


func test_pick_up() -> void:
	var lemon := interactable("Lemon")
	check(not GameState.is_lemon_carried, "Lemon starts on the floor")
	check_eq(lemon.get_prompt_text(), "Pick up Lemon", "prompt before picking up")

	await interact_with(lemon)
	check(GameState.is_lemon_carried, "Lemon is carried after picking her up")
	check(saw_line(PICK_UP_LINE), "pick-up line is shown")
	await advance_dialogue()
	check(PlayerControl.has_control(), "control returns after the pick-up line")
	check_eq(lemon.get_prompt_text(), "Put down Lemon", "prompt while carried")


func test_carried_visual_state() -> void:
	var lemon := interactable("Lemon")
	var art: CharacterArt = stella.get_node("%Visual")
	var floor_visual: CanvasItem = lemon.get_node("%Visual")
	var overlay: CanvasItem = art.carried_overlay
	check(floor_visual.visible, "Lemon is drawn on the floor before pick-up")
	check(not String(art.shown_animation()).begins_with("carry"), "Stella shows non-carry art before pick-up")

	await interact_with(lemon)
	await advance_dialogue()
	check(not floor_visual.visible, "floor Lemon is hidden while carried")
	var art_shows_lemon := String(art.shown_animation()).begins_with("carry")
	check(art_shows_lemon or overlay.visible, "a carried Lemon is drawn on Stella")
	check(not (art_shows_lemon and overlay.visible), "carry art and overlay are not both drawn")

	# Lemon follows Stella around while carried.
	stella.global_position += Vector2(-60, 10)
	await wait_physics_frames(2)
	check_near(lemon.global_position, stella.global_position, 1.0, "carried Lemon follows Stella")


func test_put_down() -> void:
	var lemon := interactable("Lemon")
	await interact_with(lemon)
	await advance_dialogue()

	var drop_from := Vector2(700, 690)
	stella.global_position = drop_from
	await wait_physics_frames(2)
	await interact_with(lemon)
	check(not GameState.is_lemon_carried, "Lemon is not carried after putting her down")
	check(saw_line(PUT_DOWN_LINE), "put-down line is shown")
	await advance_dialogue()

	var art: CharacterArt = stella.get_node("%Visual")
	check(lemon.get_node("%Visual").visible, "floor Lemon is drawn again")
	check(not String(art.shown_animation()).begins_with("carry"), "Stella's art leaves the carry state")
	check(not art.carried_overlay.visible, "carried overlay is hidden")
	var depth := RoomPerspective.scale_for(stella)
	var expected: Vector2 = stella.global_position + Vector2(lemon.pickup_offset.x * stella.facing, lemon.pickup_offset.y) * depth
	check_near(lemon.global_position, expected, 2.0, "Lemon is set down beside Stella, where the art lowered her")
	check(lemon.global_position.distance_to(stella.global_position) < 160.0, "and close to Stella")
	check_eq(lemon.get_prompt_text(), "Pick up Lemon", "prompt after putting down")

	# Lemon stays where she was put.
	var rest := lemon.global_position
	stella.global_position += Vector2(120, 0)
	await wait_physics_frames(2)
	check_near(lemon.global_position, rest, 0.5, "Lemon stays put once set down")
