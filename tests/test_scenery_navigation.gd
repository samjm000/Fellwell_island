extends "res://tests/framework/test_case.gd"
## Real clicks on painted obstacles must stop on safe floor in both phases.
## Also checks every journey against the same solid shapes used by physics.

func map_point(x: float, y: float) -> Vector2:
	return Vector2(160, 0) + Vector2(x, y) * (720.0 / 1086.0)

func check_scenery(scene: String, dangerous: Array[Vector2]) -> void:
	for phase in [GameTime.Phase.DAY, GameTime.Phase.NIGHT]:
		await load_room(phase, "res://scenes/rooms/" + scene + ".tscn")
		var obstacles: Node2D = room.get_node("RoomBounds/Obstacles")
		var map := stella.get_world_2d().navigation_map
		# Every start-to-exit route must avoid scenery along its entire length.
		for marker in room.get_node("Arrivals").get_children():
			for target in get_tree().get_nodes_in_group(Interactable.GROUP):
				if target.name == "Lemon":
					continue
				var route := NavigationServer2D.map_get_path(map, marker.global_position, target.get_approach_position(), true)
				for i in range(1, route.size()):
					var steps := maxi(1, ceili(route[i - 1].distance_to(route[i]) / 2.0))
					for step in range(steps + 1):
						var sample := route[i - 1].lerp(route[i], float(step) / steps)
						check_clear(sample, obstacles, scene + " route stays clear of props")
		# Test the floor click itself, without the painting's hotspot opening a door.
		for target in get_tree().get_nodes_in_group(Interactable.GROUP):
			target.enabled = false
		for spot in dangerous:
			await click_world(spot)
			await wait_for_walk_end(15.0)
			check_clear(stella.global_position, obstacles, scene + " click cannot put Stella on scenery")
			check(stella.global_position.distance_to(spot) > 4.0, scene + " blocked click is projected onto safe ground")
			check_near(NavigationServer2D.map_get_closest_point(map, stella.global_position), stella.global_position, 1.0, "walk ends on the floor")

func check_clear(point: Vector2, obstacles: Node2D, message: String) -> void:
	for shape in obstacles.get_children():
		if shape is CollisionPolygon2D:
			check(not Geometry2D.is_point_in_polygon(shape.global_transform.affine_inverse() * point, shape.polygon), message + ": " + shape.name)

func test_map_paths_avoid_cottage_clocktower_stall_and_ship() -> void:
	await check_scenery("island_map", [map_point(540, 330), map_point(765, 625), map_point(1040, 770)])

func test_port_does_not_walk_over_bollard_or_crates() -> void:
	await check_scenery("port", [Vector2(440, 525), Vector2(200, 558)])

func test_cave_does_not_walk_over_bed_desk_or_backpack() -> void:
	await check_scenery("maxs_cave", [Vector2(300, 420), Vector2(800, 580), Vector2(200, 550)])

func test_waterfall_keeps_to_the_path_not_fence_or_cliff() -> void:
	await check_scenery("waterfall", [Vector2(60, 405), Vector2(280, 570)])

func test_market_does_not_walk_over_clock_stalls_or_posts() -> void:
	await check_scenery("marketplace", [Vector2(625, 520), Vector2(460, 580), Vector2(570, 600)])

func test_garden_keeps_clear_of_planters_and_wall() -> void:
	await check_scenery("cottage_exterior", [Vector2(370, 535), Vector2(565, 580)])

func test_obstacles_are_solid_in_physics_too() -> void:
	await load_room(GameTime.Phase.DAY, "res://scenes/rooms/port.tscn")
	var query := PhysicsPointQueryParameters2D.new()
	query.position = Vector2(440, 525)
	query.collision_mask = 1
	var hits := stella.get_world_2d().direct_space_state.intersect_point(query)
	check(not hits.is_empty(), "the painted bollard has solid world collision")

func test_cave_terrace_avoids_fire_chests_and_cliffs() -> void:
	await check_scenery("maxs_cave_exterior", [Vector2(500, 470), Vector2(1020, 470), Vector2(400, 640)])

func test_farm_avoids_hutch_barn_rocks_and_pond() -> void:
	await check_scenery("farm", [Vector2(1140, 310), Vector2(880, 260), Vector2(300, 630), Vector2(1050, 650)])
