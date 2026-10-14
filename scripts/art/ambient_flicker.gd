class_name AmbientFlicker
extends CanvasItem
## Gently varies a CanvasItem's opacity: a slow pulse (lighthouse lamp, distant
## light) or an irregular flicker (oil lamp, house windows across the bay).
## Uses self_modulate so it doesn't fight scripts that animate `modulate`.

enum Mode { PULSE, FLICKER }

@export var mode: Mode = Mode.FLICKER
@export_range(0.0, 1.0) var min_alpha: float = 0.8
@export_range(0.0, 1.0) var max_alpha: float = 1.0
## Seconds per pulse, or roughly how quickly a flicker wanders.
@export var period: float = 2.0

var _time: float = 0.0
var _seed: float = 0.0


func _ready() -> void:
	_seed = randf() * 100.0
	_time = randf() * period


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_time += delta
	var t := _time * TAU / maxf(period, 0.01)
	var amount: float
	if mode == Mode.PULSE:
		amount = 0.5 + 0.5 * sin(t)
	else:
		# A few incommensurate sines read as organic flicker without a noise texture.
		amount = 0.5 + 0.22 * sin(t + _seed) + 0.17 * sin(t * 2.37 + _seed * 1.7) + 0.11 * sin(t * 5.13 + _seed * 0.3)
	self_modulate.a = lerpf(min_alpha, max_alpha, clampf(amount, 0.0, 1.0))
