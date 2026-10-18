extends "res://tests/framework/test_case.gd"
## Captures reference screenshots of the vertical slice for checking by eye.
## Needs a real display (not --headless); run with tests/capture_screenshots.sh.
## Files are written to $FELLWELL_SCREENSHOT_DIR (default user://screenshots).

const BOOT_SCENE := "res://scenes/boot/boot.tscn"
const AuthoringOverlay := preload("res://tests/screenshots/authoring_overlay.gd")

var _output_dir: String


func before_each() -> void:
	_output_dir = OS.get_environment("FELLWELL_SCREENSHOT_DIR")
	if _output_dir.is_empty():
		_output_dir = ProjectSettings.globalize_path("user://screenshots")
	DirAccess.make_dir_recursive_absolute(_output_dir)
	await super()


func capture(file_name: String) -> void:
	await wait_frames(2)
	await RenderingServer.frame_post_draw
	var path := _output_dir.path_join(file_name + ".png")
	var error := get_viewport().get_texture().get_image().save_png(path)
	check_eq(error, OK, "saved %s" % path)
	print("SCREENSHOT " + path)


func add_authoring_overlay() -> void:
	var overlay := AuthoringOverlay.new()
	overlay.room = room
	room.add_child(overlay)


func test_01_day_room_hover() -> void:
	await click_world(Vector2(560, 690))
	await wait_for_walk_end()
	await hover_world(hotspot_point(interactable("Telescope")))
	await wait_seconds(0.4)
	await capture("01_day_room_hover_telescope")


func test_02_day_authoring() -> void:
	add_authoring_overlay()
	await capture("02_day_authoring_overlay")


func test_03_carrying_lemon() -> void:
	await interact_with(interactable("Lemon"))
	await advance_dialogue()
	await click_world(Vector2(760, 600))
	await wait_for_walk_end()
	await hover_world(hotspot_point(interactable("Lemon")))
	await wait_seconds(0.4)
	await capture("03_carrying_lemon_hover")


func test_04_depth_front_and_back() -> void:
	await click_world(Vector2(420, 700))
	await wait_for_walk_end()
	await capture("04a_front_of_room")
	await click_world(Vector2(700, 556))
	await wait_for_walk_end()
	await capture("04b_back_of_room")


func test_05_night_room() -> void:
	await load_room(GameTime.Phase.NIGHT)
	await click_world(Vector2(700, 680))
	await wait_for_walk_end()
	await capture("05_night_room")


func test_06_night_authoring() -> void:
	await load_room(GameTime.Phase.NIGHT)
	add_authoring_overlay()
	await capture("06_night_authoring_overlay")


func test_07_dialogue_choice() -> void:
	var bed := interactable("Bed")
	await interact_with(bed)
	await advance_dialogue()
	await interact_with(bed)
	await advance_dialogue()
	var not_yet: Control = DialogueManager.get_node("DialogueBox").get_node("%Options").get_child(1)
	await hover_screen(not_yet.get_global_rect().get_center())
	await capture("07_dialogue_choice")
	await click_screen(not_yet.get_global_rect().get_center())


func test_08_telescope_day() -> void:
	await interact_with(interactable("Telescope"))
	await wait_seconds(0.6)
	await capture("08_telescope_day")
	await wait_for_dialogue()
	await advance_dialogue()
	await press(&"ui_cancel")


func test_09_telescope_night() -> void:
	await load_room(GameTime.Phase.NIGHT)
	await interact_with(interactable("Telescope"))
	await wait_for_dialogue()
	await capture("09_telescope_night")
	await advance_dialogue()
	await press(&"ui_cancel")


func test_10_boot_title() -> void:
	await unload_room()
	if not ResourceLoader.exists(BOOT_SCENE):
		return
	get_tree().change_scene_to_file(BOOT_SCENE)
	await wait_seconds(2.6)
	await capture("10_boot_title")
	# Let the boot flow finish into the room so nothing is left running.
	await wait_until(func() -> bool: return get_tree().current_scene != null \
			and get_tree().current_scene.scene_file_path == ROOM_SCENE, 20.0, "boot to reach the room")
	await wait_seconds(1.0)
	await capture("11_boot_into_room")
	room = get_tree().current_scene


# --- Stella animation QA ---------------------------------------------------------

func test_11_walking_right_and_left() -> void:
	await click_world(Vector2(420, 650))
	await wait_for_walk_end()
	await click_world(Vector2(860, 650))
	await wait_seconds(0.6)
	await capture("12_walking_right")
	await wait_for_walk_end()
	await click_world(Vector2(400, 660))
	await wait_seconds(0.6)
	await capture("13_walking_left")
	await wait_for_walk_end()


func test_12_pickup_frames() -> void:
	var lemon := interactable("Lemon")
	var sprite: AnimatedSprite2D = stella.get_node("%Visual").get_node("Art")
	await click_world(Vector2(760, 640))
	await wait_for_walk_end()
	await hover_world(hotspot_point(lemon))
	await capture("14_before_pickup")
	await click_world(hotspot_point(lemon))
	await wait_until(func() -> bool: return stella.is_performing(), 10.0, "the pickup")
	await capture("15_pickup_start")
	await wait_until(func() -> bool: return sprite.frame >= 3, 3.0, "pickup midpoint")
	await capture("16_pickup_midpoint")
	await wait_until(func() -> bool: return not stella.is_performing(), 3.0, "pickup end")
	await wait_seconds(0.3)
	await capture("17_carrying_lemon")
	await advance_dialogue()
	await click_world(Vector2(420, 690))
	await wait_seconds(0.6)
	await capture("18_carry_walking")
	await wait_for_walk_end()


# --- Stella's house ----------------------------------------------------------------

const HOUSE_ROOMS := {
	"hall": HALL_SCENE,
	"kitchen": KITCHEN_SCENE,
	"garden": EXTERIOR_SCENE,
}


## Each downstairs room and the garden, by day and night, with the authoring
## overlay; then (by day) Stella standing at every exit's approach point, to check
## her feet and size against the painting.
func test_20_house_rooms() -> void:
	for room_name: String in HOUSE_ROOMS:
		for phase in [GameTime.Phase.DAY, GameTime.Phase.NIGHT]:
			await load_room(phase, HOUSE_ROOMS[room_name])
			add_authoring_overlay()
			var phase_name := "night" if phase == GameTime.Phase.NIGHT else "day"
			await capture("20_%s_%s_authoring" % [room_name, phase_name])
		await load_room(GameTime.Phase.DAY, HOUSE_ROOMS[room_name])
		for exit in room.find_children("*", "RoomExit", true, false):
			stella.place_at(exit.get_approach_position(), exit.get_facing_for(exit.get_approach_position()))
			await capture("21_%s_at_%s" % [room_name, exit.name.to_snake_case()])


func test_22_bedroom_door() -> void:
	var door: RoomExit = interactable("BedroomDoor")
	stella.place_at(door.get_approach_position(), -1.0)
	await hover_world(hotspot_point(door))
	await capture("22_bedroom_at_door")


## The whole route carrying Lemon, captured on arrival in each room (and once
## mid-fade): bedroom → hall → kitchen → hall → garden → hall → bedroom.
func test_23_route_carrying_lemon() -> void:
	await interact_with(interactable("Lemon"))
	await advance_dialogue()
	var step := 0
	for exit_name in ["BedroomDoor", "KitchenDoor", "HallDoor", "FrontDoor", "FrontDoor", "Stairs"]:
		await interact_with(interactable(exit_name))
		if step == 0:
			await wait_seconds(0.2)
			await capture("23_route_fading_out")
		var previous := room
		await wait_until(func() -> bool: return get_tree().current_scene != previous and get_tree().current_scene != null \
				and not RoomTransition.is_busy(), 5.0, "the next room")
		room = get_tree().current_scene
		stella = room.get_node("%Stella")
		point_and_click = room.get_node("%PointAndClick")
		step += 1
		await capture("23_route_%d_%s" % [step, room.name.to_snake_case()])
