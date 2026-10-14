extends PanelContainer
## Small "[E] Look at Telescope" bubble that floats above the focused interactable.
##
## Fed by whoever owns the detector (the room wires Stella's focus signal here), so
## the prompt has no knowledge of the player or the scene tree layout.

@export var key_hint: String = "E"

var _target: Interactable = null

@onready var _label: Label = %Label


func _ready() -> void:
	_refresh()


func set_target(interactable: Interactable) -> void:
	if _target != null and is_instance_valid(_target):
		_target.prompt_changed.disconnect(_refresh)
	_target = interactable
	if _target != null:
		_target.prompt_changed.connect(_refresh)
	_refresh()


func _process(_delta: float) -> void:
	if not visible:
		return
	if _target == null or not is_instance_valid(_target):
		set_target(null)
		return
	# Interactables live in world space; convert to this canvas layer's screen space.
	var screen_position := get_viewport().get_canvas_transform() * _target.get_prompt_position()
	position = (screen_position - Vector2(size.x * 0.5, size.y)).round()


func _refresh() -> void:
	visible = _should_show()
	if visible:
		_label.text = "[%s] %s" % [key_hint, _target.get_prompt_text()]
		reset_size()


func _should_show() -> bool:
	return _target != null and is_instance_valid(_target)
