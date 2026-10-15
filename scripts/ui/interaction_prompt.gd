extends PanelContainer
## Small "Look at Telescope" label that floats above the hovered interactable.
##
## Fed by the room (it wires the mouse hover signal here), so the prompt has no
## knowledge of the player or the scene tree layout. It fades and settles into place
## rather than popping, and stays inside the screen.

## Shown in a key-cap before the label; empty hides the key-cap (mouse controls).
@export var key_hint: String = ""
@export var fade_duration: float = 0.14
## How far the bubble rises as it fades in.
@export var rise_distance: float = 6.0
@export var screen_margin: float = 8.0

var _target: Interactable = null
var _shown: bool = false
var _appear: float = 0.0 # 0 hidden -> 1 settled; drives the rise.
var _tween: Tween

@onready var _label: Label = %Label
@onready var _key_label: Label = %KeyLabel


func _ready() -> void:
	_key_label.text = key_hint
	_key_label.get_parent().visible = not key_hint.is_empty()
	modulate.a = 0.0
	visible = false
	PlayerControl.control_changed.connect(_on_control_changed)
	_refresh()


func set_target(interactable: Interactable) -> void:
	if _target != null and is_instance_valid(_target):
		_target.prompt_changed.disconnect(_refresh)
	_target = interactable
	if _target != null:
		_target.prompt_changed.connect(_refresh)
	_refresh()


func _process(_delta: float) -> void:
	if not visible or _target == null or not is_instance_valid(_target):
		return
	# Interactables live in world space; convert to this canvas layer's screen space.
	var anchor := get_viewport().get_canvas_transform() * _target.get_prompt_position()
	var rise := rise_distance * (1.0 - _appear)
	var top_left := anchor - Vector2(size.x * 0.5, size.y - rise)
	var screen := get_viewport().get_visible_rect().size
	top_left.x = clampf(top_left.x, screen_margin, screen.x - size.x - screen_margin)
	top_left.y = clampf(top_left.y, screen_margin, screen.y - size.y - screen_margin)
	position = top_left.round()


func _refresh() -> void:
	var should_show := _target != null and is_instance_valid(_target) and PlayerControl.has_control()
	if should_show:
		_label.text = _target.get_prompt_text()
		reset_size()
	if should_show == _shown:
		return
	_shown = should_show
	if _tween != null:
		_tween.kill()
	_tween = create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if should_show:
		visible = true
		_tween.tween_property(self, "modulate:a", 1.0, fade_duration)
		_tween.tween_property(self, "_appear", 1.0, fade_duration)
	else:
		_tween.tween_property(self, "modulate:a", 0.0, fade_duration)
		_tween.tween_property(self, "_appear", 0.0, fade_duration)
		_tween.chain().tween_callback(hide)


func _on_control_changed(_has_control: bool) -> void:
	_refresh()
