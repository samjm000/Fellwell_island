extends "res://tests/framework/test_case.gd"
## Switching between DAY and NIGHT updates the room's art, lighting and lines.

const WINDOW_DAY := "The sea's all sparkly today."
const WINDOW_NIGHT := "The lighthouse is on."


func room_texture_path() -> String:
	var art := room.get_node("Background/RoomArt").find_child("Art", false, false) as Sprite2D
	return art.texture.resource_path if art != null and art.texture != null else ""


func check_phase_presentation(is_night: bool) -> void:
	var phase_name := "night" if is_night else "day"
	check(room_texture_path().ends_with("/%s.png" % phase_name), "room background is the %s painting (%s)" % [phase_name, room_texture_path()])
	check_eq(room.get_node("Lighting/Day").visible, not is_night, "daytime lighting visibility at %s" % phase_name)
	check_eq(room.get_node("Lighting/Night").visible, is_night, "night lighting visibility at %s" % phase_name)
	var lit: TimeOfDayTint = room.get_node("Lit")
	check_eq(lit.modulate, lit.night_color if is_night else lit.day_color, "characters' tint at %s" % phase_name)


func test_time_changes_update_room() -> void:
	check_phase_presentation(false)
	TimeManager.set_phase(GameTime.Phase.NIGHT)
	await wait_frames(2)
	check_phase_presentation(true)
	TimeManager.set_phase(GameTime.Phase.DAY)
	await wait_frames(2)
	check_phase_presentation(false)


func test_room_loaded_at_night() -> void:
	await load_room(GameTime.Phase.NIGHT)
	check_phase_presentation(true)


func test_dialogue_follows_time_of_day() -> void:
	var window := interactable("Window")
	await interact_with(window)
	check(saw_line(WINDOW_DAY), "window has its day line")
	await advance_dialogue()

	TimeManager.set_phase(GameTime.Phase.NIGHT)
	lines_seen.clear()
	await interact_with(window)
	check(saw_line(WINDOW_NIGHT), "window has its night line")
	await advance_dialogue()
