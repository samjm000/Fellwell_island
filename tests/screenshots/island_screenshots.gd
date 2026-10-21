extends "res://tests/framework/test_case.gd"
## Run through the existing screenshot runner with a display.
const AuthoringOverlay := preload("res://tests/screenshots/authoring_overlay.gd")

func capture(file_name: String) -> void:
	# Render a real HD viewport even if the desktop fits the preview window to
	# a smaller work area. This is a fresh render, never a resized screenshot.
	var original_parent := room.get_parent()
	var hd := SubViewport.new()
	hd.size = Vector2i(1920, 1080)
	hd.world_2d = room.get_world_2d()
	hd.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	get_tree().root.add_child(hd)
	room.reparent(hd)
	hd.canvas_transform = Transform2D(0.0, Vector2(1.5, 1.5), 0.0, Vector2.ZERO)
	await wait_frames(2)
	await RenderingServer.frame_post_draw
	var image := hd.get_texture().get_image()
	var output := OS.get_environment("FELLWELL_SCREENSHOT_DIR")
	DirAccess.make_dir_recursive_absolute(output)
	check_eq(image.get_size(), Vector2i(1920, 1080), "native HD capture size")
	check_eq(image.save_png(output.path_join(file_name + ".png")), OK, "screenshot saved")
	room.reparent(original_parent)
	hd.queue_free()
	await wait_frames(2)

func add_authoring_overlay() -> void:
	var overlay := AuthoringOverlay.new()
	overlay.room = room
	room.add_child(overlay)

func test_island_locations() -> void:
	for path in ["farm", "maxs_cave_exterior", "maxs_cave", "island_map", "waterfall", "port", "marketplace", "cottage_exterior"]:
		print("CAPTURE DAY ", path)
		await load_room(GameTime.Phase.DAY, "res://scenes/rooms/" + path + ".tscn")
		if path == "cottage_exterior":
			room.place_at_arrival(&"FromHall")
		await wait_seconds(1.0)
		await capture("island_" + path)
		add_authoring_overlay()
		await capture("island_" + path + "_authoring")
		print("CAPTURE NIGHT ", path)
		await load_room(GameTime.Phase.NIGHT, "res://scenes/rooms/" + path + ".tscn")
		if path == "cottage_exterior":
			room.place_at_arrival(&"FromHall")
		await wait_seconds(1.0)
		await capture("island_" + path + "_night")
