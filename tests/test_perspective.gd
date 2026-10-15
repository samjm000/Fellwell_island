extends "res://tests/framework/test_case.gd"
## Perspective scaling: smaller at the back of the room, larger at the front,
## feet planted, and Lemon scaling with Stella.


func perspective() -> RoomPerspective:
	return room.get_node("Perspective")


func art() -> CharacterArt:
	return stella.get_node("%Visual")


func walk_to_and_wait(point: Vector2) -> void:
	await click_world(point)
	await wait_for_walk_end()


func test_scale_follows_depth() -> void:
	var p := perspective()
	check(p.far_scale < p.near_scale, "the back of the room is smaller than the front")
	check(p.near_scale - p.far_scale <= 0.25, "the change across the floor stays moderate")
	check_eq(p.scale_at(p.far_y - 100.0), p.far_scale, "clamped behind the floor")
	check_eq(p.scale_at(p.near_y + 100.0), p.near_scale, "clamped in front of the floor")

	await walk_to_and_wait(Vector2(640, 700))
	var front := art().depth_scale
	await walk_to_and_wait(Vector2(700, 556))
	var back := art().depth_scale
	check(back < front, "Stella is smaller at the back (%.3f) than the front (%.3f)" % [back, front])
	check(absf(back - p.scale_at(stella.global_position.y)) < 0.001, "her scale matches the room's perspective")
	check(is_equal_approx(art().scale.y, back), "the art node carries the depth scale")
	check(is_equal_approx(absf(art().scale.x), back), "uniformly (no squash)")


func test_feet_stay_planted() -> void:
	await walk_to_and_wait(Vector2(700, 556))
	check_eq(art().position, Vector2.ZERO, "art origin stays at Stella's feet")
	var sprite := art().get_node_or_null("Art") as AnimatedSprite2D
	if sprite != null:
		var texture := sprite.sprite_frames.get_frame_texture(sprite.animation, 0)
		# The painting's feet: its bottom centre, less the authored alignment nudge.
		var feet_local := sprite.offset - art().art_offset + Vector2(texture.get_width() * 0.5, texture.get_height())
		var feet_world := sprite.get_global_transform() * feet_local
		check_near(feet_world, stella.global_position, 0.5, "the painted feet stay on Stella's origin when scaled")
	else:
		# The blockout stands in for missing art: its soles sit on the origin.
		var placeholder: Node2D = art().get_node("Placeholder")
		var lowest := -INF
		for part in placeholder.get_children():
			if part is Polygon2D:
				for point: Vector2 in part.polygon:
					lowest = maxf(lowest, point.y)
		check(placeholder.visible, "the blockout shows while there is no art")
		check_eq(lowest, 0.0, "the blockout's soles are on Stella's origin")
		check_eq(placeholder.position, Vector2.ZERO, "standing still, the blockout isn't lifted")


func test_lemon_scales_with_stella() -> void:
	var lemon := interactable("Lemon")
	var floor_visual: Node2D = lemon.get_node("%Visual")
	check(absf(floor_visual.scale.x - perspective().scale_at(lemon.global_position.y)) < 0.001,
			"floor Lemon is sized for where she sits")

	await interact_with(lemon)
	await advance_dialogue()
	var overlay: Node2D = art().carried_overlay
	check(overlay.get_parent() == art(), "the carried-Lemon overlay is inside Stella's scaled art")
	await walk_to_and_wait(Vector2(700, 556))
	var hotspot: Node2D = lemon.get_node("%Hotspot")
	check(absf(hotspot.scale.x - art().depth_scale) < 0.001, "carried Lemon's hotspot scales with Stella")

	await interact_with(lemon) # Put her down at the back of the room.
	await advance_dialogue()
	check(absf(floor_visual.scale.x - perspective().scale_at(lemon.global_position.y)) < 0.001,
			"put-down Lemon is sized for her new spot")
