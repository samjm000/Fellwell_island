class_name PointAndClickInput
extends Node
## Turns mouse input in a room into Stella's actions.
##
## Hovering a hotspot reports it (the room shows its label) and shows a pointing
## cursor; clicking a hotspot sends Stella to use it; clicking anywhere else walks
## her to the nearest floor point. A newer click replaces whatever she was doing.
## While anything holds a PlayerControl lock (dialogue, the telescope, sleeping)
## world clicks are ignored and nothing is hovered, so the click reaches the UI.

signal hovered_changed(interactable: Interactable)

@export var player: Stella

var hovered: Interactable = null

var _mouse_position: Vector2 = Vector2.ZERO
var _has_mouse_position: bool = false


func _ready() -> void:
	PlayerControl.control_changed.connect(_on_control_changed)


func _exit_tree() -> void:
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)


# Hotspots move (Lemon in Stella's arms), so hover is re-checked every frame.
func _physics_process(_delta: float) -> void:
	_update_hover()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouse:
		_mouse_position = event.position
		_has_mouse_position = true
	if event is InputEventMouseMotion:
		_update_hover()
		return
	var button := event as InputEventMouseButton
	if button == null or not button.pressed or button.button_index != MOUSE_BUTTON_LEFT:
		return
	if player == null or not PlayerControl.has_control():
		return # Leave the click for dialogue or the telescope view.
	get_viewport().set_input_as_handled()
	var world_point := screen_to_world(button.position)
	var target := pick_interactable(world_point)
	if target != null:
		player.walk_to_interactable(target)
	else:
		player.walk_to(world_point)


func screen_to_world(screen_point: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform().affine_inverse() * screen_point


## The usable interactable whose hotspot is under `world_point`, if any.
func pick_interactable(world_point: Vector2) -> Interactable:
	var best: Interactable = null
	for node in get_tree().get_nodes_in_group(Interactable.GROUP):
		var candidate := node as Interactable
		if candidate == null or not candidate.can_interact(player) or not candidate.hotspot_contains(world_point):
			continue
		# Higher priority wins; otherwise the one nearer the front of the room.
		if best == null or candidate.hotspot_priority > best.hotspot_priority \
				or (candidate.hotspot_priority == best.hotspot_priority and candidate.global_position.y > best.global_position.y):
			best = candidate
	return best


func _update_hover() -> void:
	var target: Interactable = null
	if _has_mouse_position and PlayerControl.has_control():
		target = pick_interactable(screen_to_world(_mouse_position))
	if target == hovered:
		return
	hovered = target
	Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND if hovered != null else Input.CURSOR_ARROW)
	hovered_changed.emit(hovered)


func _on_control_changed(_has_control: bool) -> void:
	_update_hover()
