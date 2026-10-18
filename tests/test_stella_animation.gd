extends "res://tests/framework/test_case.gd"
## Stella's real animation frames: state selection while walking and standing,
## facing, and picking Lemon up / putting her down in time with the art.

const PICKUP := &"pickup_lemon_right"


func art() -> CharacterArt:
	return stella.get_node("%Visual")


func lemon() -> Interactable:
	return interactable("Lemon")


func test_frames_installed() -> void:
	for animation in [&"idle_right", &"walk_right", PICKUP, &"carry_idle_right", &"carry_walk_right"]:
		check(art().has_animation(animation), "Stella has %s" % animation)
	check(not art().get_node("Placeholder").visible, "the blockout is hidden behind real art")
	var frames: SpriteFrames = art().sprite_frames
	check(not frames.get_animation_loop(PICKUP), "the pickup plays once")
	var size := frames.get_frame_texture(&"idle_right", 0).get_size()
	for animation in frames.get_animation_names():
		for i in frames.get_frame_count(animation):
			check_eq(frames.get_frame_texture(animation, i).get_size(), size, "%s frame %d shares the canvas (no size jumps)" % [animation, i + 1])


func test_walk_and_idle() -> void:
	check_eq(art().shown_animation(), &"idle_right", "standing: idle")
	await click_world(Vector2(840, 650))
	await wait_physics_frames(6)
	check_eq(art().shown_animation(), &"walk_right", "moving: walk")
	check(not art().is_bobbing_still(), "no fake bob with real walk frames")
	await wait_for_walk_end()
	await wait_physics_frames(2)
	check_eq(art().shown_animation(), &"idle_right", "stopped: idle")


func test_left_right_flipping() -> void:
	await click_world(Vector2(840, 640))
	await wait_physics_frames(6)
	check(art().scale.x > 0.0, "walking right: not mirrored")
	await wait_for_walk_end()
	await click_world(Vector2(420, 640))
	await wait_physics_frames(6)
	check_eq(art().shown_animation(), &"walk_right", "walking left uses the right-facing walk...")
	check(art().scale.x < 0.0, "...mirrored")
	await wait_for_walk_end()
	await wait_physics_frames(2)
	check_eq(art().shown_animation(), &"idle_right", "stopped: idle")
	check(art().scale.x < 0.0, "still facing left after stopping")


func test_mostly_vertical_walk_keeps_facing() -> void:
	await click_world(Vector2(560, 640))
	await wait_for_walk_end()
	var facing_before := stella.facing
	# Straight back with a slight drift the other way.
	var target := stella.global_position + Vector2(-facing_before * 12.0, -95.0)
	await click_world(target)
	await wait_for_walk_end()
	check_eq(stella.facing, facing_before, "walking mostly up the room doesn't flip her")


func test_pickup_sequence() -> void:
	var lemon_node := lemon()
	var lemon_visual: CanvasItem = lemon_node.get_node("%Visual")
	var lemon_at := lemon_node.global_position
	await click_world(hotspot_point(lemon_node))
	await wait_physics_frames(2)
	check(stella.is_walking(), "Stella walks to Lemon first")
	check(lemon_visual.visible, "Lemon stays on the floor while Stella approaches")
	await wait_for_walk_end()
	await wait_frames(1)

	check_eq(art().shown_animation(), PICKUP, "on arrival the pickup plays")
	check(not PlayerControl.has_control(), "control is locked during the pickup")
	check(not lemon_node.can_interact(stella), "Lemon can't be used again mid-pickup")
	check_eq(stella.facing, signf(lemon_at.x - stella.global_position.x), "Stella faces Lemon")
	check_eq(signf(lemon_visual.scale.x) * lemon_node.sprite_facing, -stella.facing,
			"the art's Lemon looks the same way as the floor sprite did (no flip at the handover)")
	# The art draws Lemon where she was sitting.
	var depth := RoomPerspective.scale_for(stella)
	var drawn_at: Vector2 = stella.global_position + Vector2(lemon_node.pickup_offset.x * stella.facing, lemon_node.pickup_offset.y) * depth
	check_near(drawn_at, lemon_at, 4.0, "the pickup frames draw Lemon where the floor sprite was")

	var lift_frame: int = lemon_node.lift_frame
	var carried_by_frame := {}
	var sprite: AnimatedSprite2D = art().get_node("Art")
	var stand := stella.global_position
	var clicked := false
	while art().is_playing_action():
		carried_by_frame[sprite.frame] = GameState.is_lemon_carried
		if not clicked and sprite.frame >= 2:
			clicked = true
			await click_world(Vector2(840, 690)) # Should be ignored.
		await wait_frames(1)
	for frame: int in carried_by_frame:
		check_eq(carried_by_frame[frame], frame >= lift_frame, "carried state at pickup frame %d" % (frame + 1))
	check_near(stella.global_position, stand, 0.5, "clicks during the pickup don't move Stella")
	check(GameState.is_lemon_carried, "Lemon is carried after the pickup")
	check_eq(art().shown_animation(), &"carry_idle_right", "carry idle follows the pickup")
	check(not lemon_visual.visible, "the floor sprite stays hidden; the carry frames draw Lemon")
	check(not art().carried_overlay.visible, "no separate carried overlay over the carry art")
	check(await wait_for_dialogue(), "Stella's line comes after the animation")
	await advance_dialogue()


func test_carry_walk() -> void:
	await interact_with(lemon())
	await advance_dialogue()
	await click_world(Vector2(840, 650))
	await wait_physics_frames(6)
	check_eq(art().shown_animation(), &"carry_walk_right", "moving while carrying: carry walk")
	await wait_for_walk_end()
	await wait_physics_frames(2)
	check_eq(art().shown_animation(), &"carry_idle_right", "stopped while carrying: carry idle")


func test_put_down_restores_world_sprite() -> void:
	var lemon_node := lemon()
	var lemon_visual: CanvasItem = lemon_node.get_node("%Visual")
	await interact_with(lemon_node)
	await advance_dialogue()
	await click_world(Vector2(700, 690))
	await wait_for_walk_end()

	await click_world(hotspot_point(lemon_node))
	await wait_frames(2)
	check_eq(art().shown_animation(), PICKUP, "putting down plays the pickup backwards")
	check(not PlayerControl.has_control(), "control is locked while putting down")
	var sprite: AnimatedSprite2D = art().get_node("Art")
	var saw_hidden_after_set_down := false
	while art().is_playing_action():
		if not GameState.is_lemon_carried:
			saw_hidden_after_set_down = saw_hidden_after_set_down or not lemon_visual.visible
		await wait_frames(1)
	check(saw_hidden_after_set_down, "the floor sprite waits for the animation to finish")
	check(not GameState.is_lemon_carried, "Lemon is put down")
	check(lemon_visual.visible, "the floor sprite is back")
	check_eq(signf(lemon_visual.scale.x) * lemon_node.sprite_facing, -stella.facing,
			"she looks back at Stella, as the art set her down (no flip)")
	check_eq(art().shown_animation(), &"idle_right", "Stella returns to idle")
	var map := stella.get_world_2d().navigation_map
	check(NavigationServer2D.map_get_closest_point(map, lemon_node.global_position).distance_to(lemon_node.global_position) < 2.0,
			"Lemon is set down on the floor")
	await advance_dialogue()


func test_animation_scales_with_depth() -> void:
	await click_world(Vector2(700, 540))
	await wait_for_walk_end()
	var back := art().scale.y
	await click_world(Vector2(700, 700))
	await wait_physics_frames(6)
	check(art().scale.y > back, "she grows while walking forward (%.3f > %.3f)" % [art().scale.y, back])
	await wait_for_walk_end()
	check(is_equal_approx(art().scale.y, RoomPerspective.scale_for(stella)), "the whole visual node carries the depth scale")
	var sprite: AnimatedSprite2D = art().get_node("Art")
	check_eq(sprite.scale, Vector2.ONE, "frames themselves are never scaled individually")
