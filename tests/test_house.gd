extends "res://tests/framework/test_case.gd"
## Stella's house: the bedroom, entrance hall, kitchen/living room and garden,
## and moving between them through their doors.

const PICK_UP_LINE := "Come on, Lemon."

## Every room reachable on foot, and its arrivals.
const ROOMS := [ROOM_SCENE, HALL_SCENE, KITCHEN_SCENE, EXTERIOR_SCENE]


## Uses the exit named `exit_name` like a player and waits until Stella is in the
## next room with control back.
func go_through(exit_name: String) -> void:
	if exit_name == "BedroomDoor":
		if not GameState.has_backpack():
			await interact_with(interactable("Cupboard"))
			await advance_dialogue()
			await interact_with(interactable("Cupboard"))
			await advance_dialogue()
		if not GameState.is_lemon_carried:
			await interact_with(interactable("Lemon"))
			await advance_dialogue()
	await interact_with(interactable(exit_name))
	await wait_for_room_change()
	await wait_physics_frames(2)


func check_in_room(scene: String, arrival: StringName) -> void:
	check_eq(room.scene_file_path, scene, "arrived in the right room")
	var marker: RoomArrival = room.get_arrival(arrival)
	if not check(marker != null, "%s has arrival %s" % [scene.get_file(), arrival]):
		return
	check_near(stella.global_position, marker.global_position, 1.0, "Stella placed at %s" % arrival)
	check_eq(stella.facing, float(marker.facing), "Stella faces into the room at %s" % arrival)
	check(PlayerControl.has_control(), "control returns after entering %s" % scene.get_file())
	check(not stella.is_walking(), "Stella arrives standing still")


func walk_the_house() -> void:
	await go_through("BedroomDoor")
	check_in_room(HALL_SCENE, &"FromBedroom")
	await go_through("KitchenDoor")
	check_in_room(KITCHEN_SCENE, &"FromHall")
	await go_through("HallDoor")
	check_in_room(HALL_SCENE, &"FromKitchen")
	await go_through("FrontDoor")
	check_in_room(EXTERIOR_SCENE, &"FromHall")
	# And back the other way.
	await go_through("FrontDoor")
	check_in_room(HALL_SCENE, &"FromGarden")
	await go_through("KitchenDoor")
	check_in_room(KITCHEN_SCENE, &"FromHall")
	await go_through("HallDoor")
	check_in_room(HALL_SCENE, &"FromKitchen")
	await go_through("Stairs")
	check_in_room(ROOM_SCENE, &"FromHall")


func test_bedroom_door_to_the_garden() -> void:
	var door: RoomExit = interactable("BedroomDoor")
	await hover_world(hotspot_point(door))
	check_eq(door.get_prompt_text(), "Go downstairs", "the bedroom door's label")
	await go_through("BedroomDoor")
	check_in_room(HALL_SCENE, &"FromBedroom")
	await go_through("FrontDoor")
	check_in_room(EXTERIOR_SCENE, &"FromHall")


func test_route_by_day() -> void:
	await walk_the_house()
	check(TimeManager.is_phase(GameTime.Phase.DAY), "still day after the walk")


func test_route_by_night() -> void:
	await load_room(GameTime.Phase.NIGHT)
	await walk_the_house()
	check(TimeManager.is_night(), "still night after the walk")
	var art: ArtSlot = room.get_node("Background/RoomArt")
	check(art.get_node("Art").texture.resource_path.ends_with("night.png"), "rooms entered at night show their night painting")


func test_time_change_keeps_place() -> void:
	await load_room(GameTime.Phase.DAY, KITCHEN_SCENE)
	await click_world(Vector2(560, 620))
	await wait_for_walk_end()
	var spot := stella.global_position
	var art: ArtSlot = room.get_node("Background/RoomArt")
	TimeManager.set_phase(GameTime.Phase.NIGHT)
	await wait_frames(2)
	check(art.get_node("Art").texture.resource_path.ends_with("kitchen_living/night.png"), "the kitchen swaps to its night painting")
	check_near(stella.global_position, spot, 0.5, "changing the time doesn't move Stella")


func test_lemon_carried_through_every_room() -> void:
	await interact_with(interactable("Lemon"))
	check(saw_line(PICK_UP_LINE), "picked Lemon up")
	await advance_dialogue()
	for exit_name in ["BedroomDoor", "KitchenDoor", "HallDoor", "FrontDoor"]:
		await go_through(exit_name)
		var lemon := interactable("Lemon")
		check(GameState.is_lemon_carried, "Lemon still carried in %s" % room.name)
		check(lemon.visible and lemon.enabled, "the carried Lemon is with Stella in %s" % room.name)
		check_near(lemon.global_position, stella.global_position, 1.0, "carried Lemon is at Stella in %s" % room.name)
		check(String(stella.get_node("%Visual").shown_animation()).begins_with("carry"), "Stella shows carry art in %s" % room.name)


func test_lemon_stays_where_she_was_put_down() -> void:
	await interact_with(interactable("Lemon"))
	await advance_dialogue()
	await go_through("BedroomDoor")
	await click_world(Vector2(760, 640))
	await wait_for_walk_end()
	await interact_with(interactable("Lemon"))
	await advance_dialogue()
	check(not GameState.is_lemon_carried, "Lemon put down in the hall")
	var hall_spot := interactable("Lemon").global_position

	await go_through("KitchenDoor")
	var kitchen_lemon := interactable("Lemon")
	check(not kitchen_lemon.visible and not kitchen_lemon.enabled, "Lemon isn't in the kitchen")
	await hover_world(kitchen_lemon.get_hotspot_center())
	check(point_and_click.hovered != kitchen_lemon, "the absent Lemon can't be hovered")

	await go_through("HallDoor")
	var hall_lemon := interactable("Lemon")
	check(hall_lemon.visible and hall_lemon.enabled, "Lemon waits in the hall")
	check_near(hall_lemon.global_position, hall_spot, 0.5, "where Stella left her")

	await go_through("Stairs")
	var bedroom_lemon := interactable("Lemon")
	check(not bedroom_lemon.visible, "Lemon isn't back in the bedroom by herself")


func test_exit_clicked_from_a_distance() -> void:
	await load_room(GameTime.Phase.DAY, HALL_SCENE)
	await click_world(Vector2(1000, 660))
	await wait_for_walk_end()
	var door := interactable("KitchenDoor")
	await hover_world(hotspot_point(door))
	check_eq(point_and_click.hovered, door, "the kitchen doorway is hovered")
	check_eq(door.get_prompt_text(), "Go to Kitchen", "doorway label")
	await click_world(hotspot_point(door))
	await wait_physics_frames(5)
	check(stella.is_walking(), "she walks over first")
	check(not RoomTransition.is_busy(), "the room doesn't change before she gets there")
	# Clicking it again on the way doesn't change anything.
	await click_world(hotspot_point(door))
	await click_world(hotspot_point(door))
	await wait_for_walk_end()
	check(RoomTransition.is_busy(), "the transition starts on arrival")
	var changes := [0]
	var count := func(_room: Node) -> void: changes[0] += 1
	RoomTransition.room_changed.connect(count)
	await wait_for_room_change()
	await wait_seconds(1.0)
	RoomTransition.room_changed.disconnect(count)
	check_eq(changes[0], 1, "one click-through, one room change")
	check_in_room(KITCHEN_SCENE, &"FromHall")


func test_clicks_ignored_during_transition() -> void:
	await load_room(GameTime.Phase.DAY, HALL_SCENE)
	var door := interactable("FrontDoor")
	stella.place_at(door.get_approach_position() + Vector2(0, 30), 1.0)
	await interact_with(door)
	check(RoomTransition.is_busy(), "transition running")
	check(not PlayerControl.has_control(), "control is locked during the fade")
	await click_world(Vector2(300, 650))
	check(not stella.is_walking(), "a click during the fade doesn't move her")
	await wait_for_room_change()
	check_in_room(EXTERIOR_SCENE, &"FromHall")


func test_walking_away_cancels_an_exit() -> void:
	await load_room(GameTime.Phase.DAY, HALL_SCENE)
	stella.place_at(Vector2(1000, 660), -1.0)
	await click_world(hotspot_point(interactable("KitchenDoor")))
	await wait_physics_frames(10)
	await click_world(Vector2(800, 640))
	await wait_for_walk_end()
	await wait_seconds(0.5)
	check(not RoomTransition.is_busy(), "a new click replaces the exit")
	check_eq(get_tree().current_scene, room, "still in the hall")


func test_no_bounce_back() -> void:
	await go_through("BedroomDoor")
	var hall := room
	await wait_seconds(1.5)
	check_eq(get_tree().current_scene, hall, "arriving doesn't trigger the way back")
	check(not RoomTransition.is_busy(), "nothing pending after arriving")
	# The stairs are right there, but only a new click uses them.
	var stairs := interactable("Stairs")
	check(stella.global_position.distance_to(stairs.get_approach_position()) > stairs.interaction_radius,
			"the arrival isn't on the stairs' approach point")


func test_garden_gate_opens_the_island() -> void:
	await load_room(GameTime.Phase.DAY, EXTERIOR_SCENE)
	check((interactable("GardenGate") as RoomExit).leads_somewhere(), "garden gate connects to island")
	await go_through("GardenGate")
	check_in_room("res://scenes/rooms/island_map.tscn", &"FromGarden")
	await go_through("Home")
	check_in_room(EXTERIOR_SCENE, &"FromWorld")


func test_look_interactions() -> void:
	var expected := {
		HALL_SCENE: {"CoatAndBoots": "Grandad's coat and boots, waiting by the door.",
				"BoatPicture": "Grandad's painting of his old boat."},
		KITCHEN_SCENE: {"Kettle": "Grandad's kettle. It whistles like a seagull that's stubbed its toe.",
				"Crockery": "Grandad's blue-and-white crockery.",
				"Sofa": "Grandad's sofa, and Grandad's blanket."},
	}
	for scene: String in expected:
		await load_room(GameTime.Phase.DAY, scene)
		for object_name: String in expected[scene]:
			var target := interactable(object_name)
			await hover_world(hotspot_point(target))
			check(target.get_prompt_text().begins_with("Look at"), "%s is a Look interaction" % object_name)
			await interact_with(target)
			await wait_for_dialogue()
			check(saw_line(expected[scene][object_name]), "%s's line" % object_name)
			await advance_dialogue()


func test_every_room_is_authored_on_its_floor() -> void:
	for scene: String in ROOMS:
		await load_room(GameTime.Phase.DAY, scene)
		var map := stella.get_world_2d().navigation_map
		var label := scene.get_file()
		check(_on_floor(map, stella.global_position, 1.0), "%s: Stella starts on the floor" % label)
		for node in get_tree().get_nodes_in_group(Interactable.GROUP):
			var target := node as Interactable
			if target is RoomExit or target.has_hotspot() and target.name != "Lemon":
				check(_on_floor(map, target.get_approach_position(), target.interaction_radius),
						"%s: %s's approach point is reachable" % [label, target.name])
		for marker in room.get_node("Arrivals").get_children():
			check(_on_floor(map, marker.global_position, 1.0), "%s: arrival %s is on the floor" % [label, marker.name])
			for exit in room.find_children("*", "RoomExit", true, false):
				check(marker.global_position.distance_to(exit.get_approach_position()) > exit.interaction_radius,
						"%s: arrival %s is clear of %s's approach" % [label, marker.name, exit.name])
		# Every exit can be reached from every arrival.
		for marker in room.get_node("Arrivals").get_children():
			for exit in room.find_children("*", "RoomExit", true, false):
				var path := NavigationServer2D.map_get_path(map, marker.global_position, exit.get_approach_position(), true)
				check(not path.is_empty() and path[path.size() - 1].distance_to(exit.get_approach_position()) <= exit.interaction_radius,
						"%s: %s reachable from %s" % [label, exit.name, marker.name])


func _on_floor(map: RID, point: Vector2, tolerance: float) -> bool:
	return NavigationServer2D.map_get_closest_point(map, point).distance_to(point) <= tolerance
