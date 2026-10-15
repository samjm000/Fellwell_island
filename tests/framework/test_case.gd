extends Node
## Base class for Fellwell regression tests.
##
## A test file extends this script and declares `test_*` methods, which may await.
## The runner calls `before_each()` (a fresh Stella's room by day, with a clean
## GameState) before every test. Tests drive the game the way a player does,
## through input events, and record problems with `check()` / `check_eq()`
## rather than stopping at the first one.

const ROOM_SCENE := "res://scenes/rooms/stellas_room.tscn"

var room: Node2D = null
var stella: Stella = null
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

func load_room(phase: GameTime.Phase = GameTime.Phase.DAY) -> void:
	await unload_room()
	GameState.reset()
	TimeManager.set_phase(phase)
	lines_seen.clear()
	if not DialogueManager.line_shown.is_connected(_on_line_shown):
		DialogueManager.line_shown.connect(_on_line_shown)
	room = load(ROOM_SCENE).instantiate()
	get_tree().root.add_child(room)
	get_tree().current_scene = room
	stella = room.get_node("%Stella")
	# Let areas register overlaps and the navigation map sync.
	await wait_physics_frames(3)


func unload_room() -> void:
	if room != null and is_instance_valid(room):
		room.queue_free()
		await wait_frames(2)
	room = null
	stella = null


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

## Interacts with `target` using the player's primary controls.
func interact_with(target: Interactable) -> void:
	stella.global_position = target.global_position
	await wait_physics_frames(3)
	var detector: InteractionDetector = stella.get_node("%InteractionDetector")
	check_eq(detector.focused, target, "Stella's focus when standing at %s" % target.name)
	await press(&"interact")


func _on_line_shown(_speaker: String, text: String) -> void:
	lines_seen.append(text)
