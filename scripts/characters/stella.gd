class_name Stella
extends CharacterBody2D
## The player character.
##
## Point-and-click first: `walk_to()` walks her along a navigation path to a floor
## point, and `walk_to_interactable()` walks her to an Interactable's approach point
## and uses it on arrival. Paths come from the navigation map of her world (built
## by the room's WalkableFloor), so she knows nothing about the room's layout.
## Keyboard movement (WASD + E) remains as a debug fallback; see
## PlayerControl.keyboard_debug_enabled().
##
## Movement is tuned for a side-on adventure room: vertical movement is slower so
## walking up/down reads as stepping into or out of the room, and the room's
## RoomPerspective makes her slightly smaller at the back. The node's origin is at
## her feet so Y-sorting against furniture works and scaling keeps her planted.

## Re-emitted from the detector so UI can follow focus without reaching into Stella.
signal focused_interactable_changed(interactable: Interactable)
## Emitted when a click-walk ends, whether she arrived or was stopped.
signal walk_finished
## Each frame of a one-shot action (see perform()), for timing gameplay to the art.
signal action_frame(animation: StringName, frame: int)

## Held while a one-shot action (e.g. picking Lemon up) plays.
const ACTION_LOCK := &"stella_action"

@export var walk_speed: float = 240.0
## Multiplier applied to vertical movement to sell the side-on perspective.
@export_range(0.1, 1.0) var depth_speed_scale: float = 0.6
## Keyboard (debug) movement eases in and out at this rate.
@export var acceleration: float = 2400.0
@export var footstep_sfx: StringName = &"footstep"
## Distance walked between footstep sounds.
@export var footstep_spacing: float = 42.0
## Facing only changes when the sideways part of her movement is at least this
## fraction of her speed, so walking mostly up or down the room keeps the last
## facing instead of flickering.
@export_range(0.0, 1.0) var facing_turn_ratio: float = 0.35
## A click-walk that gets no closer to its next waypoint for this long (blocked)
## gives up.
@export var stuck_timeout: float = 0.3

## 1.0 when facing right, -1.0 when facing left.
var facing: float = 1.0:
	set(value):
		facing = value
		if _art != null:
			_art.facing = value

var _distance_since_footstep: float = 0.0
var _path: PackedVector2Array = []
var _path_index: int = 0
## Used on arrival at the end of the current path, if any.
var _pending_interactable: Interactable = null
## Its approach point, fixed when the walk starts (some objects choose a side
## based on where she's coming from).
var _pending_approach: Vector2
var _stuck_time: float = 0.0
var _closest_to_waypoint: float = INF

@onready var _art: CharacterArt = %Visual
@onready var _interaction_detector: InteractionDetector = %InteractionDetector
@onready var _shadow: Node2D = $Shadow
@onready var _shadow_scale: Vector2 = _shadow.scale


func _ready() -> void:
	_interaction_detector.focused_changed.connect(focused_interactable_changed.emit)
	_art.action_frame.connect(action_frame.emit)
	GameState.lemon_carried_changed.connect(_on_lemon_carried_changed)
	PlayerControl.control_changed.connect(_on_control_changed)
	_on_lemon_carried_changed(GameState.is_lemon_carried)
	_update_depth_scale()


## Walks to the floor point nearest `world_point`. Returns false if there is no
## walkable floor to go to (e.g. the navigation map isn't ready yet).
func walk_to(world_point: Vector2) -> bool:
	_pending_interactable = null
	return _start_path(world_point)


## Walks to `target`'s approach point and uses it on arrival. If she's already
## close enough, she uses it straight away.
func walk_to_interactable(target: Interactable) -> void:
	_pending_interactable = target
	_pending_approach = target.get_approach_position()
	if _is_within_reach(target):
		_arrive()
	elif not _start_path(_pending_approach):
		_pending_interactable = null


func stop_walking() -> void:
	var was_walking := is_walking()
	_path = []
	_path_index = 0
	_pending_interactable = null
	velocity = Vector2.ZERO
	if was_walking:
		walk_finished.emit()


## Plays a one-shot animation of hers (e.g. &"pickup_lemon_right", or backwards
## for a put-down), standing still with control locked until it finishes.
## Returns false straight away if her art has no such animation.
func perform(animation: StringName, backwards: bool = false) -> bool:
	if not _art.has_animation(animation):
		return false
	stop_walking()
	PlayerControl.acquire(ACTION_LOCK)
	if _art.play_action(animation, backwards):
		await _art.action_finished
	PlayerControl.release(ACTION_LOCK)
	return true


func has_action(animation: StringName) -> bool:
	return _art.has_animation(animation)


func is_performing() -> bool:
	return _art.is_playing_action()


func is_walking() -> bool:
	return _path_index < _path.size()


## Where the current click-walk ends, or her position when standing still.
func get_walk_destination() -> Vector2:
	return _path[_path.size() - 1] if is_walking() else global_position


func _physics_process(delta: float) -> void:
	var keyboard_direction := Vector2.ZERO
	if PlayerControl.has_control() and PlayerControl.keyboard_debug_enabled():
		keyboard_direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if keyboard_direction != Vector2.ZERO and is_walking():
		stop_walking() # The debug keys take over from a click.

	if is_walking():
		velocity = _path_velocity(delta)
	else:
		var target_velocity := Vector2(keyboard_direction.x, keyboard_direction.y * depth_speed_scale) * walk_speed
		velocity = velocity.move_toward(target_velocity, acceleration * delta)
	move_and_slide()
	_update_depth_scale()

	var speed := get_real_velocity().length()
	if is_walking():
		_check_progress(delta)
	if absf(velocity.x) > maxf(1.0, velocity.length() * facing_turn_ratio):
		facing = signf(velocity.x)
	_art.is_moving = speed > 20.0
	_update_footsteps(speed * delta)


func _unhandled_input(event: InputEvent) -> void:
	if not PlayerControl.has_control() or not PlayerControl.keyboard_debug_enabled():
		return
	if event.is_action_pressed("interact") and _interaction_detector.interact_with_focused():
		get_viewport().set_input_as_handled()


func _start_path(world_point: Vector2) -> bool:
	var map := get_world_2d().navigation_map
	if NavigationServer2D.map_get_iteration_id(map) == 0:
		return false # The floor hasn't been registered yet (first frame of a room).
	var destination := NavigationServer2D.map_get_closest_point(map, world_point)
	var path := NavigationServer2D.map_get_path(map, global_position, destination, true)
	if path.is_empty():
		return false
	_path = path
	_path[_path.size() - 1] = destination
	_path_index = 0
	_stuck_time = 0.0
	_closest_to_waypoint = INF
	return true


func _path_velocity(delta: float) -> Vector2:
	while _path_index < _path.size() and global_position.distance_to(_path[_path_index]) < 0.5:
		_path_index += 1
		_closest_to_waypoint = INF
	if _path_index >= _path.size():
		_finish_path()
		return Vector2.ZERO
	if _pending_interactable != null and _is_within_reach(_pending_interactable):
		_arrive()
		return Vector2.ZERO

	var to_waypoint := _path[_path_index] - global_position
	var direction := to_waypoint.normalized()
	# Full speed sideways, depth_speed_scale of it straight up/down, and an ellipse
	# between, so diagonal paths stay straight.
	var speed := walk_speed / Vector2(direction.x, direction.y / depth_speed_scale).length()
	if to_waypoint.length() <= speed * delta:
		return to_waypoint / delta # Land exactly on the waypoint.
	return direction * speed


# Measured as distance to the waypoint rather than speed: sliding along a wall
# can keep her moving without getting anywhere.
func _check_progress(delta: float) -> void:
	var distance := global_position.distance_to(_path[_path_index])
	if distance < _closest_to_waypoint - 1.0:
		_closest_to_waypoint = distance
		_stuck_time = 0.0
		return
	_stuck_time += delta
	if _stuck_time >= stuck_timeout:
		stop_walking()


func _finish_path() -> void:
	if _pending_interactable != null:
		_arrive()
	else:
		stop_walking()


func _is_within_reach(target: Interactable) -> bool:
	return global_position.distance_to(_pending_approach) <= target.interaction_radius


func _arrive() -> void:
	var target := _pending_interactable
	_pending_interactable = null
	stop_walking()
	if target == null or not is_instance_valid(target):
		return
	facing = target.get_facing_for(global_position)
	if PlayerControl.has_control():
		target.trigger(self)


func _update_depth_scale() -> void:
	var depth := RoomPerspective.scale_for(self)
	_art.depth_scale = depth
	_shadow.scale = _shadow_scale * depth


func _update_footsteps(distance: float) -> void:
	if distance <= 0.01:
		_distance_since_footstep = footstep_spacing * 0.6 # First step lands soon after starting.
		return
	_distance_since_footstep += distance
	if _distance_since_footstep >= footstep_spacing:
		_distance_since_footstep = 0.0
		AudioManager.play_sfx(footstep_sfx, -4.0, 0.08)


func _on_lemon_carried_changed(is_carried: bool) -> void:
	_art.is_carrying = is_carried


func _on_control_changed(has_control: bool) -> void:
	# Dialogue, the telescope and sleeping all stop her where she is.
	if not has_control:
		stop_walking()
