class_name TelescopeView
extends CanvasLayer
## Full-screen "looking through the telescope" mode.
##
## Presentation only: shows the view for the current time of day, takes control
## away from Stella while open, and closes on request. What Stella notices (dialogue,
## story flags) is decided by the telescope that opened it.
##
## Layout: `Scene` holds the day/night views (each an ArtSlot painting plus animated
## overlays: sea glints, lighthouse beam, offshore light) and is slightly larger
## than the screen so it can drift. The `Eyepiece` shader masks it to a circle. A
## slow hand-held drift moves the eyepiece one way and the scene the other, which
## reads as gentle parallax.

signal closed

const CONTROL_LOCK := &"telescope"
const AUDIO_SOURCE := &"telescope"

## Radians per second for the lighthouse beam's swing.
@export var beam_sweep_speed: float = 1.4
## Pixels of slow hand-held drift; 0 disables it.
@export var drift_amount: float = 7.0
## How much further the scene moves than the eyepiece, for parallax.
@export var parallax_factor: float = 1.6

@export_group("Audio")
@export var open_sfx: StringName = &"telescope_open"
@export var close_sfx: StringName = &"telescope_close"
@export var cancel_sfx: StringName = &"ui_cancel"
## Through the eyepiece the sea is closer and the room falls away.
@export var day_ambience: Dictionary = {&"sea": -6.0, &"wind": -14.0}
@export var night_ambience: Dictionary = {&"sea": -7.0, &"wind": -14.0}
## Optional motif while looking out at night; skipped if the file doesn't exist.
@export var night_music: StringName = &"telescope_mystery"

var _beam_phase: float = 0.0
var _time: float = 0.0
var _scene_rest_position: Vector2

@onready var _day_view: Control = %DayView
@onready var _night_view: Control = %NightView
@onready var _lighthouse_beam: Node2D = %LighthouseBeam
@onready var _offshore_light: CanvasItem = %OffshoreLight
@onready var _lighthouse_lamp_glow: CanvasItem = %LighthouseLampGlow
@onready var _scene: Control = %Scene
@onready var _eyepiece: ColorRect = %Eyepiece


func _ready() -> void:
	PlayerControl.acquire(CONTROL_LOCK)
	var is_night := TimeManager.is_night()
	_day_view.visible = not is_night
	_night_view.visible = is_night
	_scene_rest_position = _scene.position
	if is_night:
		_start_offshore_light_pulse()
	AudioManager.play_sfx(open_sfx)
	AudioManager.push_ambience_override(AUDIO_SOURCE, night_ambience if is_night else day_ambience)
	if is_night:
		AudioManager.push_music_override(AUDIO_SOURCE, night_music)


func _exit_tree() -> void:
	PlayerControl.release(CONTROL_LOCK)
	AudioManager.pop_ambience_override(AUDIO_SOURCE)
	AudioManager.pop_music_override(AUDIO_SOURCE)


func is_offshore_light_visible() -> bool:
	return _night_view.visible and _offshore_light.visible


func close() -> void:
	if is_queued_for_deletion():
		return
	PlayerControl.release(CONTROL_LOCK)
	AudioManager.play_sfx(close_sfx)
	closed.emit()
	queue_free()


func _process(delta: float) -> void:
	_time += delta
	var drift := Vector2(sin(_time * 0.37), sin(_time * 0.29 + 1.3)) * drift_amount
	_scene.position = _scene_rest_position - drift * parallax_factor
	var viewport_size := get_viewport().get_visible_rect().size
	_eyepiece.material.set_shader_parameter(&"center", Vector2(0.5, 0.5) + drift / viewport_size)

	if _night_view.visible:
		# Seen side-on from far away, a rotating beam reads as swinging toward and
		# away; the lamp flares as it swings past the viewer.
		_beam_phase = wrapf(_beam_phase + beam_sweep_speed * delta, 0.0, TAU)
		var swing := cos(_beam_phase)
		_lighthouse_beam.scale.x = swing
		_lighthouse_lamp_glow.self_modulate.a = 0.35 + 0.65 * pow(1.0 - absf(swing), 3.0)


func _unhandled_input(event: InputEvent) -> void:
	# Lines shown over the view take the key presses until they finish.
	if DialogueManager.is_active():
		return
	if event.is_action_pressed("interact") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if event.is_action_pressed("ui_cancel"):
			AudioManager.play_ui(cancel_sfx)
		close()


func _start_offshore_light_pulse() -> void:
	var tween := create_tween().set_loops()
	tween.tween_property(_offshore_light, "modulate:a", 0.35, 1.1).set_trans(Tween.TRANS_SINE)
	tween.tween_property(_offshore_light, "modulate:a", 1.0, 1.1).set_trans(Tween.TRANS_SINE)
