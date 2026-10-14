class_name TelescopeView
extends CanvasLayer
## Full-screen "looking through the telescope" mode.
##
## Presentation only: shows the view for the current time of day, takes control
## away from Stella while open, and closes on request. What Stella notices (dialogue,
## story flags) is decided by the telescope that opened it.

signal closed

const CONTROL_LOCK := &"telescope"

## Radians per second for the lighthouse beam's swing.
@export var beam_sweep_speed: float = 1.4

var _beam_phase: float = 0.0

@onready var _day_view: Control = %DayView
@onready var _night_view: Control = %NightView
@onready var _lighthouse_beam: Node2D = %LighthouseBeam
@onready var _offshore_light: CanvasItem = %OffshoreLight


func _ready() -> void:
	PlayerControl.acquire(CONTROL_LOCK)
	var is_night := TimeManager.is_night()
	_day_view.visible = not is_night
	_night_view.visible = is_night
	set_process(is_night)
	if is_night:
		_start_offshore_light_pulse()


func _exit_tree() -> void:
	PlayerControl.release(CONTROL_LOCK)


func is_offshore_light_visible() -> bool:
	return _night_view.visible and _offshore_light.visible


func close() -> void:
	if is_queued_for_deletion():
		return
	PlayerControl.release(CONTROL_LOCK)
	closed.emit()
	queue_free()


func _process(delta: float) -> void:
	# Seen side-on from far away, a rotating beam reads as swinging toward and away.
	_beam_phase = wrapf(_beam_phase + beam_sweep_speed * delta, 0.0, TAU)
	_lighthouse_beam.scale.x = cos(_beam_phase)


func _unhandled_input(event: InputEvent) -> void:
	# Lines shown over the view take the key presses until they finish.
	if DialogueManager.is_active():
		return
	if event.is_action_pressed("interact") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


func _start_offshore_light_pulse() -> void:
	var tween := create_tween().set_loops()
	tween.tween_property(_offshore_light, "modulate:a", 0.35, 1.1).set_trans(Tween.TRANS_SINE)
	tween.tween_property(_offshore_light, "modulate:a", 1.0, 1.1).set_trans(Tween.TRANS_SINE)
