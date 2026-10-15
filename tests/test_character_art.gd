extends "res://tests/framework/test_case.gd"
## CharacterArt state selection, with synthetic frames standing in for art that
## hasn't been delivered yet (walk cycles, left-facing art).


func before_each() -> void:
	pass # No room needed.


func after_each() -> void:
	for child in get_children():
		child.queue_free()
	await wait_frames(1)


func make_art(animations: Array[StringName]) -> CharacterArt:
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	var image := Image.create(20, 40, false, Image.FORMAT_RGBA8)
	var texture := ImageTexture.create_from_image(image)
	for animation in animations:
		frames.add_animation(animation)
		frames.add_frame(animation, texture)
		frames.add_frame(animation, texture)
	var art := CharacterArt.new()
	art.sprite_frames = frames
	add_child(art)
	return art


func sprite_of(art: CharacterArt) -> AnimatedSprite2D:
	return art.get_node("Art")


## The direction the art actually appears to face on screen.
func shown_facing(art: CharacterArt) -> float:
	return signf(art.scale.x * sprite_of(art).scale.x * (-1.0 if CharacterArt.FACES_LEFT.has(art.shown_animation()) else 1.0))


func test_states_follow_movement_carrying_and_facing() -> void:
	var art := make_art([&"idle", &"walk_left", &"walk_right", &"carry_idle", &"carry_walk_left", &"carry_walk_right"])
	check_eq(art.shown_animation(), &"idle", "standing")
	art.is_moving = true
	check_eq(art.shown_animation(), &"walk_right", "walking right")
	art.facing = -1.0
	check_eq(art.shown_animation(), &"walk_left", "walking left")
	check_eq(shown_facing(art), -1.0, "left-authored art isn't mirrored back to the right")
	art.is_carrying = true
	check_eq(art.shown_animation(), &"carry_walk_left", "carrying, walking left")
	art.facing = 1.0
	check_eq(art.shown_animation(), &"carry_walk_right", "carrying, walking right")
	art.is_moving = false
	check_eq(art.shown_animation(), &"carry_idle", "carrying, standing")


func test_missing_direction_is_mirrored() -> void:
	var art := make_art([&"idle", &"walk_right"])
	art.is_moving = true
	art.facing = -1.0
	check_eq(art.shown_animation(), &"walk_right", "walk_left falls back to walk_right")
	check_eq(shown_facing(art), -1.0, "and is mirrored to face left")

	var left_only := make_art([&"idle", &"walk_left"])
	left_only.is_moving = true
	check_eq(left_only.shown_animation(), &"walk_left", "walk_right falls back to walk_left")
	check_eq(shown_facing(left_only), 1.0, "and is mirrored to face right")


func test_undirected_walk_cycle_still_supported() -> void:
	var art := make_art([&"idle", &"walk", &"carry_idle", &"carry_walk"])
	art.is_moving = true
	art.facing = -1.0
	check_eq(art.shown_animation(), &"walk", "the art pack's walk/ folder is used for both directions")
	check_eq(shown_facing(art), -1.0, "mirrored when walking left")
	art.is_carrying = true
	check_eq(art.shown_animation(), &"carry_walk", "carry_walk/ likewise")


func test_stills_bob_until_walk_frames_exist() -> void:
	var stills := make_art([&"idle", &"carry_idle"])
	stills.is_moving = true
	check_eq(stills.shown_animation(), &"idle", "a still stands in for the missing walk")
	check(stills.is_bobbing_still(), "the still bobs while walking")
	stills.is_carrying = true
	check_eq(stills.shown_animation(), &"carry_idle", "carry still, not a walk without Lemon")
	check(stills.is_bobbing_still(), "the carry still bobs too")
	await wait_frames(6)
	check(sprite_of(stills).position.y < 0.0, "the bob lifts the still")
	stills.is_moving = false
	await wait_frames(2)
	check_eq(sprite_of(stills).position.y, 0.0, "standing still settles the bob")

	var cycles := make_art([&"idle", &"walk_right", &"carry_idle", &"carry_walk_right"])
	cycles.is_moving = true
	check(not cycles.is_bobbing_still(), "no fake bob once walk frames exist")
	await wait_frames(6)
	check_eq(sprite_of(cycles).position.y, 0.0, "walk frames aren't bobbed")


func test_depth_scale_keeps_feet_and_facing() -> void:
	var art := make_art([&"idle"])
	art.facing = -1.0
	art.depth_scale = 0.9
	check_eq(art.scale, Vector2(-0.9, 0.9), "depth scale applies uniformly, keeping the facing flip")
	check_eq(art.position, Vector2.ZERO, "scaling is about the feet (origin)")
