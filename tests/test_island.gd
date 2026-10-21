extends "res://tests/framework/test_case.gd"
## Player-driven island routes, geometry, Lemon and the unchanged water module.
const MAP := "res://scenes/rooms/island_map.tscn"
const LOCATIONS := [MAP, "res://scenes/rooms/waterfall.tscn", "res://scenes/rooms/port.tscn", "res://scenes/rooms/maxs_cave.tscn", "res://scenes/rooms/marketplace.tscn", "res://scenes/rooms/maxs_cave_exterior.tscn", "res://scenes/rooms/farm.tscn"]

func go_through(exit_name: String) -> void:
	await interact_with(interactable(exit_name))
	await wait_for_room_change()
	await wait_physics_frames(2)
	check(PlayerControl.has_control(), "control returned after the journey")

func tour(phase: GameTime.Phase) -> void:
	await load_room(phase, EXTERIOR_SCENE)
	await go_through("GardenGate")
	check_eq(room.scene_file_path, MAP, "garden opens the island")
	for pair in [["Waterfall", LOCATIONS[1]], ["MaxsCave", LOCATIONS[5]], ["Marketplace", LOCATIONS[4]], ["Port", LOCATIONS[2]], ["Farm", LOCATIONS[6]]]:
		await go_through(pair[0])
		check_eq(room.scene_file_path, pair[1], "reached " + pair[0])
		if pair[0] == "Waterfall":
			check_eq(room.waterfall.night, phase == GameTime.Phase.NIGHT, "water follows time of day")
		if pair[0] == "MaxsCave":
			await go_through("CaveEntrance")
			check_eq(room.scene_file_path, LOCATIONS[3], "entered the real cave interior")
			await go_through("IslandPath")
			check_eq(room.scene_file_path, LOCATIONS[5], "returned to the cave terrace")
		await go_through("IslandPath")
		check_eq(room.scene_file_path, MAP, "returned to island")

	await go_through("Home")
	check_eq(room.scene_file_path, EXTERIOR_SCENE, "home again")
	check_eq(TimeManager.current_phase, phase, "journey preserves the time")

func test_island_by_day() -> void:
	await tour(GameTime.Phase.DAY)

func test_island_by_night() -> void:
	await tour(GameTime.Phase.NIGHT)

func test_lemon_can_travel_and_wait_in_the_port() -> void:
	await load_room(GameTime.Phase.DAY, MAP)
	GameState.is_lemon_carried = true
	await wait_physics_frames(2)
	await go_through("Port")
	check(GameState.is_lemon_carried, "Lemon reaches the port in Stella's arms")
	await interact_with(interactable("Lemon"))
	await advance_dialogue()
	var spot := interactable("Lemon").global_position
	await go_through("IslandPath")
	check(not interactable("Lemon").visible, "Lemon stays in the port")
	await go_through("Port")
	check_near(interactable("Lemon").global_position, spot, 0.5, "Lemon waits where she was left")

func test_all_island_arrivals_and_approaches_are_reachable() -> void:
	for path in LOCATIONS:
		await load_room(GameTime.Phase.DAY, path)
		var map := stella.get_world_2d().navigation_map
		for marker in room.get_node("Arrivals").get_children():
			check_near(NavigationServer2D.map_get_closest_point(map, marker.global_position), marker.global_position, 1.0, path + " arrival on floor")
			for node in get_tree().get_nodes_in_group(Interactable.GROUP):
				if node.name == "Lemon":
					continue
				var end: Vector2 = node.get_approach_position()
				var route := NavigationServer2D.map_get_path(map, marker.global_position, end, true)
				check(not route.is_empty() and route[-1].distance_to(end) <= node.interaction_radius, "%s: %s reachable from %s" % [path, node.name, marker.name])

func test_waterfall_keeps_its_cave_gate_and_flow_states() -> void:
	await load_room(GameTime.Phase.DAY, LOCATIONS[1])
	var wf: FellwellWaterfall = room.waterfall
	check(not wf.is_cave_available(), "hidden cave closed under running water")
	check(wf.get_node("Ribbon/Curtain").mesh != null, "original ribbon mesh exists")
	wf.set_flow_state(FellwellWaterfall.FlowState.SLOWING)
	await wait_seconds(wf.slow_seconds + 0.3)
	check(absf(wf.volume - wf.slow_volume) < 0.02, "original slow flow")
	wf.set_flow_state(FellwellWaterfall.FlowState.STOPPED)
	check(not wf.is_cave_available(), "last water must fall first")
	await wait_seconds(wf.stop_fall_seconds + 0.3)
	check(wf.is_cave_available(), "hidden cave becomes available")
	wf.set_flow_state(FellwellWaterfall.FlowState.RESTARTING)
	check(not wf.is_cave_available(), "restart immediately closes hidden cave")
	await wait_seconds(wf.restart_fall_seconds + wf.restart_fill_seconds + 0.5)
	check_eq(wf.state, FellwellWaterfall.FlowState.NORMAL, "original restart completes")
	TimeManager.set_phase(GameTime.Phase.NIGHT)
	await wait_frames(2)
	check(wf.night, "night updates while staying at the waterfall")

func test_bedroom_map_matches_exploration_and_closes_with_dialogue() -> void:
	await interact_with(interactable("Photograph"))
	var view: CanvasLayer = interactable("Photograph").get_node("IslandMapView")
	check_eq(view.get_node("Map").texture.resource_path, "res://art/backgrounds/island/map.png", "bedroom and exploration share one map")
	check(not PlayerControl.has_control(), "reading the map locks walking")
	await advance_dialogue()
	await wait_frames(2)
	check(not interactable("Photograph").has_node("IslandMapView"), "reading closes with its dialogue")
	check(PlayerControl.has_control(), "map gives control back")

func test_tiny_map_feet_keep_the_collision_on_the_ground() -> void:
	await load_room(GameTime.Phase.DAY, MAP)
	var feet: CollisionShape2D = stella.get_node("FeetCollision")
	var scale := RoomPerspective.scale_for(stella)
	check_near(feet.position, Vector2(0, -7) * scale, 0.001, "feet offset scales along with the collider")
	check(absf(feet.scale.x - scale) < 0.001, "feet and character share scale")

func test_marketplace_shops_and_port_route_by_day_and_night() -> void:
	for phase in [GameTime.Phase.DAY, GameTime.Phase.NIGHT]:
		await load_room(phase, LOCATIONS[4])
		for shop in ["Clocktower", "Fishmonger", "PotionShop", "DadsShop", "Tavern"]:
			await interact_with(interactable(shop))
			await wait_for_dialogue()
			await advance_dialogue()
		var art: ArtSlot = room.get_node("Background/RoomArt")
		var atlas := art.get_node("Art").texture as AtlasTexture
		check(atlas != null, "market uses a view into the untouched original board")
		check_eq(atlas.region.position.y, 546.0 if phase == GameTime.Phase.NIGHT else 0.0, "right day/night panel")
		await go_through("PortPath")
		check_eq(room.scene_file_path, LOCATIONS[2], "market to port")
		await go_through("MarketPath")
		check_eq(room.scene_file_path, LOCATIONS[4], "port back to market")

func test_garden_stella_is_larger_and_map_size_is_preserved() -> void:
	await load_room(GameTime.Phase.DAY, EXTERIOR_SCENE)
	room.place_at_arrival(&"FromHall")
	var garden_scale := RoomPerspective.scale_for(stella)
	check(garden_scale >= 0.34 and garden_scale <= 0.40, "garden Stella reads against the cottage door")
	await go_through("GardenGate")
	check(absf(RoomPerspective.scale_for(stella) - 0.065) < 0.0001, "map Stella keeps her approved scale")

func test_farm_and_caves_use_the_supplied_paintings() -> void:
	for pair in [[LOCATIONS[3], "maxs_cave/interior.png"], [LOCATIONS[5], "maxs_cave/exterior.png"], [LOCATIONS[6], "farm/day.png"]]:
		await load_room(GameTime.Phase.DAY, pair[0])
		var art: ArtSlot = room.get_node("Background/RoomArt")
		check_eq(art.texture_path, "res://art/backgrounds/" + pair[1], "correct approved location painting")
		check_eq(art.get_node("Art").texture.get_size(), Vector2(1672, 941), "full source resolution retained")

func test_farm_and_cave_observations() -> void:
	for pair in [[LOCATIONS[6], ["Farmyard", "Hutch", "FarmPond"]], [LOCATIONS[3], ["CaveMaps", "CaveTelescope", "MaxsBed"]]]:
		await load_room(GameTime.Phase.DAY, pair[0])
		for object_name in pair[1]:
			await interact_with(interactable(object_name))
			await wait_for_dialogue()
			await advance_dialogue()

func test_new_floor_patches_are_connected() -> void:
	for path in [LOCATIONS[3], LOCATIONS[5], LOCATIONS[6]]:
		await load_room(GameTime.Phase.DAY, path)
		var navigation: NavigationPolygon = room.get_node("RoomBounds/Floor").navigation_polygon
		var vertices := navigation.get_vertices()
		for i in navigation.get_polygon_count():
			var polygon := navigation.get_polygon(i)
			var centre := Vector2.ZERO
			for index in polygon:
				centre += vertices[index]
			centre /= polygon.size()
			var route := NavigationServer2D.map_get_path(stella.get_world_2d().navigation_map, stella.global_position, centre, true)
			check(not route.is_empty() and route[-1].distance_to(centre) < 1.0, path + " has no unreachable floor islands")

func test_animated_farm_uses_clean_original_and_keeps_characters_separate() -> void:
	await load_room(GameTime.Phase.DAY, LOCATIONS[6])
	var art := room.get_node("Background/RoomArt") as FarmAmbientArt
	check(art != null, "mapped farm installs the animated painting")
	check_eq(FileAccess.get_sha256("res://art/backgrounds/farm/day.png"), "764c4b7d46604498da6e8df4906716fc6d86f547da92377f752780c1eb787b7e", "exact approved animal-free original")
	check(not room.has_node("RoomBounds/Obstacles/PaintedStellaAndLemon"), "no collision for removed painted characters")
	check(stella.get_parent() == room.get_node("Lit/Objects"), "playable Stella remains separate from background")
	var start_environment: float = art.environment_clock
	var start_detail: float = art.detail_clock
	await wait_seconds(1.0)
	check(art.environment_clock > start_environment + 0.9, "environment animates during gameplay")
	check(art.detail_clock > start_detail + 0.9, "detail animates independently during gameplay")
	art.set_elapsed(40.0)
	check(is_zero_approx(art.environment_clock), "40-second environment wraps")
	check_eq(art.detail_clock, 2.0, "55-second detail has its own phase")
	TimeManager.set_phase(GameTime.Phase.NIGHT)
	await wait_frames(2)
	check_eq(room.get_node("Background").modulate, Color(0.52, 0.59, 0.8, 1), "animated farm follows existing night tint")
	await click_world(Vector2(650, 470))
	await wait_for_walk_end(15.0)
	check_near(stella.global_position, Vector2(650, 470), 8.0, "walk across the cleared farmyard")
