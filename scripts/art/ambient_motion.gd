class_name AmbientMotion
extends Node2D
## Slow, looping idle motion for set dressing: curtains swaying, water glinting,
## clouds drifting. Everything is a sine around the node's starting transform, so
## the scene's authored layout stays the rest pose.
##
## Only runs while visible, so night-only or day-only decoration costs nothing
## when hidden.

@export var period: float = 4.0
@export var position_amplitude: Vector2 = Vector2.ZERO
@export var rotation_amplitude_degrees: float = 0.0
@export var skew_amplitude_degrees: float = 0.0
## Continuous drift in pixels per second, wrapped within `drift_wrap` (e.g. clouds).
@export var drift_velocity: Vector2 = Vector2.ZERO
@export var drift_wrap: float = 0.0
## Negative picks a random phase so neighbouring elements don't move in lockstep.
@export var phase_offset: float = -1.0

var _rest_position: Vector2
var _rest_rotation: float
var _rest_skew: float
var _time: float = 0.0


func _ready() -> void:
	_rest_position = position
	_rest_rotation = rotation
	_rest_skew = skew
	_time = randf() * period if phase_offset < 0.0 else phase_offset


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_time += delta
	var wave := sin(_time * TAU / maxf(period, 0.01))
	var drift := drift_velocity * _time
	if drift_wrap > 0.0:
		drift = Vector2(fposmod(drift.x, drift_wrap), fposmod(drift.y, drift_wrap))
	position = _rest_position + position_amplitude * wave + drift
	rotation = _rest_rotation + deg_to_rad(rotation_amplitude_degrees) * wave
	skew = _rest_skew + deg_to_rad(skew_amplitude_degrees) * wave
