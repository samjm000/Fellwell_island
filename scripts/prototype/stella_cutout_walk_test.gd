extends Node2D
## PROTOTYPE stage for the cutout walk (StellaCutoutRig): a plain floor with a
## ruler, Stella walking either in place (the floor slides under her) or across
## the stage, and a measurement of how far each planted foot drifts against the
## floor (should be ~0 px).
##
## Run res://scenes/prototype/stella_cutout_walk_test.tscn (F6 in the editor).

enum Mode { IN_PLACE, ACROSS }

const FLOOR_TOP := 470.0
const FLOOR_Y := 640.0
const TICK := 32.0
const EDGE := 140.0
const HELP := "M: in place / across    Space: walk / stop\nLeft / Right: walk that way (across, Space to stop first)\n" \
		+ "+ / -: walking speed    1 / 2 / 3: game speed 100 / 50 / 25%\nP: pause    . : step a frame (paused)\n" \
		+ "C: carry Lemon on / off    G: joint guides    Z: room scale / 1:1"

@export var mode: Mode = Mode.IN_PLACE
## Walking speed on screen, px/s (the game's Stella walks at 240; with this rig's
## stride that's a hurried ~2.8 steps a second, so the stage strolls slower).
@export var walk_speed: float = 180.0
## Stella's size, as at the middle of her room's floor.
@export var depth_scale: float = 0.79

var walking: bool = true
var direction: float = 1.0
## How far the floor has slid (in place) or 0 (across), screen px.
var floor_offset: float = 0.0
## Largest drift of a planted foot against the floor seen so far, screen px.
var max_drift: float = 0.0

var _paused: bool = false
var _step_once: bool = false
var _manual: float = 0.0
## Screen px still to walk while stopping (-1 when not stopping).
var _stop_left: float = -1.0
## side -> {kind, floor_x} for the foot point currently planted.
var _planted: Dictionary = {}

@onready var rig: StellaCutoutRig = %Stella
@onready var _readout: Label = %Readout
@onready var _help: Label = %Help


func _ready() -> void:
	_help.text = HELP
	_place_rig()


func _exit_tree() -> void:
	Engine.time_scale = 1.0


func _physics_process(delta: float) -> void:
	if _paused and not _step_once:
		return
	_step_once = false
	var wants_to_walk := walking or _manual != 0.0
	if _manual != 0.0:
		direction = _manual
	var distance := walk_speed * delta if wants_to_walk else 0.0
	if wants_to_walk:
		_stop_left = -1.0
	elif rig.is_moving:
		# Stopping: carry on, slowing, to the next step with the feet together.
		if _stop_left < 0.0:
			_stop_left = rig.distance_to_feet_together() * depth_scale
		var ease := clampf(_stop_left / (rig.stride * depth_scale * 0.25), 0.3, 1.0)
		distance = minf(walk_speed * ease * delta, _stop_left)
		_stop_left -= distance
	var moving := distance > 0.0
	if mode == Mode.ACROSS and moving:
		var next_x := rig.position.x + direction * distance
		if next_x > get_viewport_rect().size.x - EDGE or next_x < EDGE:
			direction = -direction # Turn at the edge of the stage.
			_planted.clear()
			next_x = rig.position.x + direction * distance
		rig.position.x = next_x
	elif mode == Mode.IN_PLACE:
		floor_offset -= distance
	rig.scale = Vector2(direction * depth_scale, depth_scale)
	rig.advance(distance / depth_scale, delta) # Canvas px: the rig's own units.
	_measure_drift()
	queue_redraw()
	_readout.text = _describe()


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or key.echo:
		return
	if key.physical_keycode in [KEY_LEFT, KEY_A, KEY_RIGHT, KEY_D]:
		var towards := -1.0 if key.physical_keycode in [KEY_LEFT, KEY_A] else 1.0
		if mode == Mode.ACROSS:
			_manual = towards if key.pressed else (0.0 if _manual == towards else _manual)
		get_viewport().set_input_as_handled()
		return
	if not key.pressed:
		return
	match key.physical_keycode:
		KEY_M:
			mode = Mode.ACROSS if mode == Mode.IN_PLACE else Mode.IN_PLACE
			_place_rig()
		KEY_SPACE:
			walking = not walking
		KEY_C:
			rig.carrying = not rig.carrying
		KEY_EQUAL, KEY_KP_ADD:
			walk_speed = minf(walk_speed + 20.0, 400.0)
		KEY_MINUS, KEY_KP_SUBTRACT:
			walk_speed = maxf(walk_speed - 20.0, 40.0)
		KEY_1:
			Engine.time_scale = 1.0
		KEY_2:
			Engine.time_scale = 0.5
		KEY_3:
			Engine.time_scale = 0.25
		KEY_P:
			_paused = not _paused
		KEY_PERIOD:
			_step_once = true
		KEY_G:
			rig.show_guides = not rig.show_guides
		KEY_Z:
			depth_scale = 1.0 if depth_scale != 1.0 else 0.79
			_planted.clear()
		_:
			return
	max_drift = 0.0
	get_viewport().set_input_as_handled()


func _place_rig() -> void:
	rig.position = Vector2(get_viewport_rect().size.x * 0.5, FLOOR_Y)
	floor_offset = 0.0
	_planted.clear()
	max_drift = 0.0


# A planted point (the heel, then the ball once the heel lifts) should keep the
# same position on the floor until it changes or the foot lifts.
func _measure_drift() -> void:
	for side in ["near", "far"]:
		var contact: Variant = rig.planted_point(side)
		var stage: String = rig.describe_legs()[side]
		if contact == null or stage == "standing":
			_planted.erase(side)
			continue
		var kind := "ball" if stage == "toe-off" else "heel"
		var floor_x := rig.to_global(contact).x - floor_offset
		if not _planted.has(side) or _planted[side].kind != kind:
			_planted[side] = {"kind": kind, "floor_x": floor_x}
		else:
			max_drift = maxf(max_drift, absf(floor_x - _planted[side].floor_x))


func _draw() -> void:
	var view := get_viewport_rect()
	draw_rect(view, Color(0.93, 0.92, 0.88))
	draw_rect(Rect2(0, FLOOR_TOP, view.size.x, view.size.y - FLOOR_TOP), Color(0.86, 0.84, 0.79))
	var first := fposmod(floor_offset, TICK * 4.0) - TICK * 4.0
	var x := first
	var index := 0
	while x <= view.size.x:
		var major := index % 4 == 0
		draw_line(Vector2(x, FLOOR_TOP), Vector2(x, view.size.y), Color(0.5, 0.48, 0.45, 0.6 if major else 0.25), 2.0 if major else 1.0)
		x += TICK
		index += 1
	draw_line(Vector2(0, FLOOR_Y), Vector2(view.size.x, FLOOR_Y), Color(0.5, 0.48, 0.45, 0.5), 1.0)


func _describe() -> String:
	var canvas_speed := walk_speed / depth_scale
	var moving := rig.is_moving
	var legs := rig.describe_legs()
	return "\n".join([
		"PROTOTYPE  cutout walk  (%s%s)%s" % ["in place" if mode == Mode.IN_PLACE else "across",
				", carrying Lemon" if rig.carrying else "", "   PAUSED" if _paused else ""],
		"speed      %d px/s   %.2f steps/s" % [walk_speed if moving else 0.0, 2.0 * canvas_speed / rig.stride if moving else 0.0],
		"stride     %d px (two steps, on screen)" % roundi(rig.stride * depth_scale),
		"phase      %.2f" % rig.phase,
		"near leg   %s" % legs.near,
		"far leg    %s" % legs.far,
		"drift      %.2f px (planted foot vs floor, max)" % max_drift,
		"scale      %.2f%s" % [depth_scale, "" if Engine.time_scale == 1.0 else "   game at %d%%" % roundi(Engine.time_scale * 100.0)],
	])
