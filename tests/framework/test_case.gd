extends Node
## Base class for Fellwell regression tests.
##
## A test file extends this script and declares `test_*` methods, which may await.
## The runner calls `before_each()` (a fresh Stella's room by day, with a clean
## GameState) before every test. Tests drive the game the way a player does,
## through input events, and record problems with `check()` / `check_eq()`
## rather than stopping at the first one.

const ROOM_SCENE := "res://scenes/rooms/stellas_room.tscn"
const HALL_SCENE := "res://scenes/rooms/entrance_hall.tscn"
const KITCHEN_SCENE := "res://scenes/rooms/kitchen_living.tscn"
const EXTERIOR_SCENE := "res://scenes/rooms/cottage_exterior.tscn"

var room: Node2D = null
var stella: Stella = null
var point_and_click: PointAndClickInput = null
## Every dialogue line and question shown since the current test began.
var lines_seen: PackedStringArray = []
var failures: PackedStringArray = []


func before_each() -> void:
	await load_room()


func after_each() -> void:
	if DialogueManager.is_active():
		check(false, "test left dialogue open")
		await advance_dialogue()
	await unload_room()


# --- World setup -----------------------------------------------------------------

## Starts a fresh playthrough in `scene` (Stella's room unless given).
func load_room(phase: GameTime.Phase = GameTime.Phase.DAY, scene: String = ROOM_SCENE) -> void:
	await unload_room()
	GameState.reset()
	TimeManager.set_phase(phase)
	lines_seen.clear()
	if not DialogueManager.line_shown.is_connected(_on_line_shown):
		DialogueManager.line_shown.connect(_on_line_shown)
	room = load(scene).instantiate()
	get_tree().root.add_child(room)
	get_tree().current_scene = room
	_find_room_parts()
	# Let areas register overlaps and the navigation map sync.
	await wait_physics_frames(3)


## After an exit is used: waits for the transition to finish and points `room`,
## `stella` and `point_and_click` at the new room. Returns false on timeout.
func wait_for_room_change(timeout: float = 5.0) -> bool:
	var previous := room
	var changed := await wait_until(func() -> bool:
		return get_tree().current_scene != previous and get_tree().current_scene != null and not RoomTransition.is_busy(),
		timeout, "the room to change")
	room = get_tree().current_scene
	_find_room_parts()
	return changed


func _find_room_parts() -> void:
	stella = room.get_node("%Stella")
	point_and_click = room.get_node("%PointAndClick")


func unload_room() -> void:
	if RoomTransition.is_busy():
		await wait_until(func() -> bool: return not RoomTransition.is_busy(), 5.0, "a room transition to finish")
		room = get_tree().current_scene
	if room != null and is_instance_valid(room):
		room.queue_free()
		await wait_frames(2)
	room = null
	stella = null
	point_and_click = null


## Finds an Interactable in the room by node name, e.g. "Bed" or "Window".
func interactable(node_name: String) -> Interactable:
	for node in room.find_children(node_name, "", true, false):
		if node is Interactable:
			return node
	check(false, "room has an interactable named %s" % node_name)
	return null


# --- Assertions ------------------------------------------------------------------

func check(condition: bool, message: String) -> bool:
	if not condition:
		failures.append(message)
		push_error("CHECK FAILED: " + message)
	return condition


func check_eq(actual: Variant, expected: Variant, message: String) -> bool:
	return check(actual == expected, "%s (expected %s, got %s)" % [message, expected, actual])


func check_near(actual: Vector2, expected: Vector2, tolerance: float, message: String) -> bool:
	return check(actual.distance_to(expected) <= tolerance,
			"%s (expected %s ± %s, got %s)" % [message, expected, tolerance, actual])


func saw_line(text: String) -> bool:
	return lines_seen.has(text)


# --- Time ------------------------------------------------------------------------

func wait_frames(count: int = 1) -> void:
	for i in count:
		await get_tree().process_frame


func wait_physics_frames(count: int = 1) -> void:
	for i in count:
		await get_tree().physics_frame


func wait_seconds(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


## Waits until `condition` returns true. Records a failure and returns false on timeout.
func wait_until(condition: Callable, timeout: float, description: String) -> bool:
	var elapsed := 0.0
	while not condition.call():
		if elapsed >= timeout:
			return check(false, "timed out after %.1fs waiting for: %s" % [timeout, description])
		await get_tree().process_frame
		elapsed += get_process_delta_time()
	return true


# --- Input -----------------------------------------------------------------------

func press(action: StringName) -> void:
	_push_action(action, true)
	await wait_frames(1)
	_push_action(action, false)
	await wait_frames(1)


## Holds an action down for a number of physics frames (Stella reads movement there).
func hold(action: StringName, physics_frames: int) -> void:
	Input.action_press(action)
	await wait_physics_frames(physics_frames)
	Input.action_release(action)
	await wait_physics_frames(1)


func world_to_screen(world_point: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform() * world_point


## Moves the mouse to a screen position (viewport coordinates).
func hover_screen(screen_point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = screen_point
	motion.global_position = screen_point
	get_viewport().push_input(motion, true)
	await wait_physics_frames(1)


func hover_world(world_point: Vector2) -> void:
	await hover_screen(world_to_screen(world_point))


## Moves the mouse to a screen position and clicks there.
func click_screen(screen_point: Vector2, button_index: MouseButton = MOUSE_BUTTON_LEFT) -> void:
	await hover_screen(screen_point)
	for pressed in [true, false]:
		var button := InputEventMouseButton.new()
		button.button_index = button_index
		button.pressed = pressed
		button.position = screen_point
		button.global_position = screen_point
		get_viewport().push_input(button, true)
		await wait_frames(1)


func click_world(world_point: Vector2, button_index: MouseButton = MOUSE_BUTTON_LEFT) -> void:
	await click_screen(world_to_screen(world_point), button_index)


func wait_for_walk_end(timeout: float = 10.0) -> bool:
	return await wait_until(func() -> bool: return not stella.is_walking(), timeout, "Stella to stop walking")


## A point inside `target`'s hotspot: its centre if that's inside, else the first
## inside point on a grid over its bounds.
func hotspot_point(target: Interactable) -> Vector2:
	var center := target.get_hotspot_center()
	if target.hotspot_contains(center):
		return center
	var bounds := target._hotspot_bounds()
	for step_y in range(1, 10):
		for step_x in range(1, 10):
			var point := bounds.position + bounds.size * Vector2(step_x, step_y) / 10.0
			if target.hotspot_contains(point):
				return point
	check(false, "%s has a clickable hotspot" % target.name)
	return center


func _push_action(action: StringName, pressed: bool) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = pressed
	get_viewport().push_input(event)


# --- Dialogue --------------------------------------------------------------------

func wait_for_dialogue(timeout: float = 5.0) -> bool:
	return await wait_until(DialogueManager.is_active, timeout, "dialogue to open")


## Clicks through lines until the dialogue closes or a question is shown.
func advance_dialogue(max_presses: int = 60) -> void:
	for i in max_presses:
		if not DialogueManager.is_active() or DialogueManager.is_choosing():
			return
		await press(&"interact")
	check(false, "dialogue still open after %d presses" % max_presses)


func choose_option(index: int) -> void:
	if not check(DialogueManager.is_choosing(), "a question is showing before choosing option %d" % index):
		return
	for i in index:
		await press(&"move_down")
	await press(&"interact")


# --- Interacting -----------------------------------------------------------------

## Interacts with `target` the way a player does: hover its hotspot, click it, and
## wait for Stella to walk over and use it (including any animation it plays,
## such as picking Lemon up).
func interact_with(target: Interactable) -> void:
	var point := hotspot_point(target)
	await hover_world(point)
	check_eq(point_and_click.hovered, target, "hovered object over %s's hotspot" % target.name)
	var approach := target.get_approach_position()
	await click_world(point)
	await wait_for_walk_end()
	check(stella.global_position.distance_to(approach) <= target.interaction_radius + 1.0,
			"Stella reached %s's approach point (at %s, approach %s)" % [target.name, stella.global_position, approach])
	await wait_for_action_end()


func wait_for_action_end(timeout: float = 5.0) -> bool:
	await wait_frames(1)
	return await wait_until(func() -> bool: return not stella.is_performing(), timeout, "Stella's animation to finish")


## The debug keyboard route: stand in the object's reach zone and press E.
func interact_with_keyboard(target: Interactable) -> void:
	stella.global_position = target.global_position
	await wait_physics_frames(3)
	var detector: InteractionDetector = stella.get_node("%InteractionDetector")
	check_eq(detector.focused, target, "Stella's focus when standing at %s" % target.name)
	await press(&"interact")
	await wait_for_action_end()


func _on_line_shown(_speaker: String, text: String) -> void:
	lines_seen.append(text)
