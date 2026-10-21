extends "res://tests/screenshots/island_screenshots.gd"
## Capture the integrated room, player and authored floor at native HD.
func test_island_locations() -> void:
	for phase in [GameTime.Phase.DAY, GameTime.Phase.NIGHT]:
		await load_room(phase, "res://scenes/rooms/farm.tscn")
		await wait_seconds(1.0)
		var label := "farm_ambient_day" if phase == GameTime.Phase.DAY else "farm_ambient_night"
		await capture(label)
		add_authoring_overlay()
		await capture(label + "_authoring")
