extends Interactable
## Lemon, Stella's golden Labrador.
##
## Lemon is a companion state, not an AI: she is either in the room or in Stella's
## arms. GameState owns that fact; this node and Stella's carried visual both react
## to it. While carried, this node follows the carrier so "Put down" stays in reach,
## with low priority so it never steals focus from objects in the room.

@export var pick_up_dialogue: DialogueSequence
@export var put_down_dialogue: DialogueSequence
## Where Lemon is set down, relative to the carrier's feet (x is mirrored by facing).
@export var put_down_offset: Vector2 = Vector2(44, 6)
@export var carried_prompt_offset: Vector2 = Vector2(0, -170)

var _carrier: Node2D = null
var _resting_prompt_offset: Vector2

@onready var _visual: Node2D = %Visual


func _ready() -> void:
	_resting_prompt_offset = prompt_offset
	GameState.lemon_carried_changed.connect(_on_lemon_carried_changed)
	if GameState.is_lemon_carried:
		# Entering a room already carrying Lemon (future room transitions).
		_carrier = get_tree().get_first_node_in_group("player") as Node2D
	_on_lemon_carried_changed(GameState.is_lemon_carried)


func _physics_process(_delta: float) -> void:
	if _carrier != null:
		global_position = _carrier.global_position


func interact(actor: Node2D) -> void:
	interacted.emit(actor)
	if GameState.is_lemon_carried:
		_put_down(actor)
		await DialogueManager.play(put_down_dialogue)
	else:
		_pick_up(actor)
		await DialogueManager.play(pick_up_dialogue)


func _pick_up(actor: Node2D) -> void:
	_carrier = actor
	GameState.is_lemon_carried = true


func _put_down(actor: Node2D) -> void:
	var facing: float = actor.get("facing") if "facing" in actor else 1.0
	_carrier = null
	global_position = actor.global_position + Vector2(put_down_offset.x * facing, put_down_offset.y)
	GameState.is_lemon_carried = false


func _on_lemon_carried_changed(is_carried: bool) -> void:
	_visual.visible = not is_carried
	interaction_prompt = "Put down" if is_carried else "Pick up"
	interaction_priority = -10 if is_carried else 0
	prompt_offset = carried_prompt_offset if is_carried else _resting_prompt_offset
	set_physics_process(is_carried)
