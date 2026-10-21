class_name FellwellWaterfall
extends Node2D
## Fellwell Island waterfall controller.
## One scene, four flow states. Nothing is swapped: the cave is painted into the
## plate and the water simply leaves or returns.
##
## Call set_flow_state(FlowState.SLOWING / STOPPED / RESTARTING / NORMAL) from
## the beaver puzzle. Listen to cave_available_changed to enable the cave.

signal state_changed(state: FlowState)
signal cave_available_changed(available: bool)

enum FlowState { NORMAL, SLOWING, STOPPED, RESTARTING }

@export var start_state: FlowState = FlowState.NORMAL
@export var night: bool = false
## Step the water animation at 12 fps for a hand-animated cadence.
@export var on_twos: bool = false
## Must match the level's CanvasModulate colour so the night glow balances.
@export var night_tint: Color = Color(0.26, 0.33, 0.58)

@export_group("Timing")
@export_range(0.05, 1.0) var slow_volume: float = 0.3
@export var slow_seconds: float = 6.0
@export var stop_fall_seconds: float = 1.5
@export var restart_fall_seconds: float = 1.7
@export var restart_fill_seconds: float = 5.0
@export var dry_seconds: float = 40.0

@export_group("Drips after stopping")
@export var drip_points: PackedVector2Array = PackedVector2Array([
	Vector2(1076, 222), Vector2(1160, 229), Vector2(1238, 218), Vector2(1320, 227),
	Vector2(1405, 224), Vector2(1142, 654), Vector2(1365, 745)])

var state: FlowState = FlowState.NORMAL
var volume := 1.0
var head := 1.0
var tail := 0.0
var impact := 1.0
var mist := 1.0
var wet := 1.0
var night_mix := 0.0

var _clock := 0.0
var _tweens := {}
var _cave_available := false

@onready var _curtain: MeshInstance2D = $Ribbon/Curtain
@onready var _wet: MeshInstance2D = $Ribbon/WetRock
@onready var _foam: ColorRect = $ImpactFoam
@onready var _mist: ColorRect = $Mist
@onready var _spray: CPUParticles2D = $Spray
@onready var _drips: CPUParticles2D = $Drips
@onready var _cave_shape: CollisionShape2D = $CaveEntrance/CollisionShape2D

func _ready() -> void:
	_drips.emission_shape = CPUParticles2D.EMISSION_SHAPE_POINTS
	_drips.emission_points = drip_points
	_drips.position = Vector2.ZERO
	night_mix = 1.0 if night else 0.0
	_cave_shape.disabled = true
	jump_to(start_state)

## Instantly place the waterfall in a state, no transition (use when loading a save).
func jump_to(s: FlowState) -> void:
	state = s
	match s:
		FlowState.STOPPED:
			volume = 0.0; head = 1.0; tail = 1.0; impact = 0.0; mist = 0.0; wet = 0.0
		FlowState.SLOWING:
			volume = slow_volume; head = 1.0; tail = 0.0; impact = slow_volume; mist = slow_volume; wet = 1.0
		_:
			volume = 1.0; head = 1.0; tail = 0.0; impact = 1.0; mist = 1.0; wet = 1.0
	_update_cave()

func set_flow_state(s: FlowState) -> void:
	if s == state:
		return
	state = s
	match s:
		FlowState.NORMAL:
			tail = 0.0; head = 1.0
			_tween("volume", 1.0, 3.0, Tween.TRANS_SINE)
		FlowState.SLOWING:
			tail = 0.0; head = 1.0
			_tween("volume", slow_volume, slow_seconds, Tween.TRANS_SINE)
		FlowState.STOPPED:
			head = 1.0
			# Linear in time-of-flight space = the last water falls under gravity.
			_tween("tail", 1.0, stop_fall_seconds, Tween.TRANS_LINEAR)
		FlowState.RESTARTING:
			tail = 0.0; head = 0.0; volume = 0.55
			var t := _tween("head", 1.0, restart_fall_seconds, Tween.TRANS_LINEAR)
			t.finished.connect(func():
				if state == FlowState.RESTARTING:
					var t2 := _tween("volume", 1.0, restart_fill_seconds, Tween.TRANS_SINE)
					t2.finished.connect(func():
						if state == FlowState.RESTARTING:
							state = FlowState.NORMAL
							state_changed.emit(state)))
	_update_cave()
	state_changed.emit(state)

func is_cave_available() -> bool:
	return _cave_available

func _tween(prop: String, to: float, seconds: float, trans: Tween.TransitionType) -> Tween:
	if _tweens.has(prop) and _tweens[prop].is_valid():
		_tweens[prop].kill()
	var t := create_tween().set_trans(trans).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(self, prop, to, seconds)
	_tweens[prop] = t
	return t

func _process(delta: float) -> void:
	_clock += delta
	var at_pool := volume if (head >= 0.995 and tail < 0.995) else 0.0
	var rate := 3.0 if at_pool > impact else 2.6
	impact += (at_pool - impact) * minf(1.0, delta * rate)
	mist += (impact - mist) * minf(1.0, delta * 0.25)
	if state == FlowState.STOPPED:
		wet = maxf(0.0, wet - delta / dry_seconds)
	else:
		wet = minf(1.0, wet + delta * (0.8 if head > 0.5 else 0.2))
	night_mix = move_toward(night_mix, 1.0 if night else 0.0, delta * 2.0)
	_push()
	_update_cave()

func _push() -> void:
	var t := floorf(_clock * 12.0) / 12.0 if on_twos else _clock
	var cm := _curtain.material as ShaderMaterial
	cm.set_shader_parameter("anim_time", t)
	cm.set_shader_parameter("volume", volume)
	cm.set_shader_parameter("head", head)
	cm.set_shader_parameter("tail", tail)
	cm.set_shader_parameter("impact", impact)
	cm.set_shader_parameter("night", night_mix)
	cm.set_shader_parameter("night_tint", Vector3(night_tint.r, night_tint.g, night_tint.b))
	(_wet.material as ShaderMaterial).set_shader_parameter("wet", wet)
	for r in [_foam, _mist]:
		var m := r.material as ShaderMaterial
		m.set_shader_parameter("anim_time", t)
		m.set_shader_parameter("night", night_mix)
		m.set_shader_parameter("night_tint", Vector3(night_tint.r, night_tint.g, night_tint.b))
		m.set_shader_parameter("rect_size", r.size)
	(_foam.material as ShaderMaterial).set_shader_parameter("impact", impact)
	(_mist.material as ShaderMaterial).set_shader_parameter("mist", mist)
	_spray.emitting = impact > 0.03
	_spray.modulate.a = clampf(impact * impact * 1.4, 0.0, 1.0)
	_drips.emitting = state == FlowState.STOPPED and tail > 0.99 and wet > 0.08

func _update_cave() -> void:
	var available := state == FlowState.STOPPED and tail >= 0.999
	if available != _cave_available:
		_cave_available = available
		_cave_shape.set_deferred("disabled", not available)
		cave_available_changed.emit(available)
