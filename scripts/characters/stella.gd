class_name Stella
extends CharacterBody2D
## The player character.
##
## Movement is tuned for a side-on adventure room: free horizontal walking, with a
## slower vertical component so moving up/down reads as stepping into or out of the
## room (depth) rather than climbing. The node's origin is at her feet so Y-sorting
## against furniture works.
##
## Stella never inspects what she is interacting with: her InteractionDetector picks
## the focused Interactable and she simply calls into it.

## Re-emitted from the detector so UI can follow focus without reaching into Stella.
signal focused_interactable_changed(interactable: Interactable)

@export var walk_speed: float = 240.0
## Multiplier applied to vertical movement to sell the side-on perspective.
@export_range(0.1, 1.0) var depth_speed_scale: float = 0.6
@export var acceleration: float = 2400.0

## 1.0 when facing right, -1.0 when facing left.
var facing: float = 1.0

@onready var _visual: Node2D = %Visual
@onready var _interaction_detector: InteractionDetector = %InteractionDetector
@onready var _carried_lemon: Node2D = %CarriedLemon


func _ready() -> void:
	_interaction_detector.focused_changed.connect(focused_interactable_changed.emit)
	GameState.lemon_carried_changed.connect(_on_lemon_carried_changed)
	_on_lemon_carried_changed(GameState.is_lemon_carried)


func _physics_process(delta: float) -> void:
	var input_direction := Vector2.ZERO
	if PlayerControl.has_control():
		input_direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")

	var target_velocity := Vector2(input_direction.x, input_direction.y * depth_speed_scale) * walk_speed
	velocity = velocity.move_toward(target_velocity, acceleration * delta)
	move_and_slide()

	if not is_zero_approx(input_direction.x):
		facing = signf(input_direction.x)
		_visual.scale.x = facing


func _unhandled_input(event: InputEvent) -> void:
	if not PlayerControl.has_control():
		return
	if event.is_action_pressed("interact") and _interaction_detector.interact_with_focused():
		get_viewport().set_input_as_handled()


func _on_lemon_carried_changed(is_carried: bool) -> void:
	_carried_lemon.visible = is_carried
