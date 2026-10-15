extends Interactable
## Lemon, Stella's small, cream, fluffy dog.
##
## Lemon is a companion state, not an AI: she is either in the room or in Stella's
## arms. GameState owns that fact; this node and Stella's carried visual both react
## to it. While carried, this node follows the carrier so "Put down" stays in reach
## (with low keyboard-focus priority so it never steals focus from objects in the
## room), and her hotspot moves up to the carrier's arms so she can be clicked there.

@export var pick_up_dialogue: DialogueSequence
@export var put_down_dialogue: DialogueSequence
## Where Lemon is set down, relative to the carrier's feet (x is mirrored by facing).
@export var put_down_offset: Vector2 = Vector2(44, 6)
@export var carried_prompt_offset: Vector2 = Vector2(0, -170)
## Where her hotspot sits while carried, relative to the carrier's feet.
@export var carried_hotspot_offset: Vector2 = Vector2(0, -200)
@export var pick_up_sfx: StringName = &"lemon_pick_up"
@export var put_down_sfx: StringName = &"lemon_put_down"

var _carrier: Node2D = null
var _resting_prompt_offset: Vector2

@onready var _visual: Node2D = %Visual
@onready var _hotspot_node: Node2D = %Hotspot


func _ready() -> void:
	_resting_prompt_offset = prompt_offset
	GameState.lemon_carried_changed.connect(_on_lemon_carried_changed)
	if GameState.is_lemon_carried:
		# Entering a room already carrying Lemon (future room transitions).
		_carrier = get_tree().get_first_node_in_group("player") as Node2D
	_on_lemon_carried_changed(GameState.is_lemon_carried)
	if not GameState.is_lemon_carried:
		_apply_floor_depth()


func _physics_process(_delta: float) -> void:
	if _carrier != null:
		global_position = _carrier.global_position
		# In Stella's arms she scales with Stella; keep the hotspot on her there.
		var depth := RoomPerspective.scale_for(self)
		_hotspot_node.position = carried_hotspot_offset * depth
		_hotspot_node.scale = Vector2.ONE * depth


func interact(actor: Node2D) -> void:
	interacted.emit(actor)
	if GameState.is_lemon_carried:
		_put_down(actor)
		AudioManager.play_sfx(put_down_sfx)
		await DialogueManager.play(put_down_dialogue)
	else:
		_pick_up(actor)
		AudioManager.play_sfx(pick_up_sfx)
		await DialogueManager.play(pick_up_dialogue)


func _pick_up(actor: Node2D) -> void:
	_carrier = actor
	GameState.is_lemon_carried = true


func _put_down(actor: Node2D) -> void:
	var facing: float = actor.get("facing") if "facing" in actor else 1.0
	_carrier = null
	global_position = actor.global_position + Vector2(put_down_offset.x * facing, put_down_offset.y)
	GameState.is_lemon_carried = false
	_apply_floor_depth()


## On the floor she is sized for where she sits, like Stella.
func _apply_floor_depth() -> void:
	var depth := RoomPerspective.scale_for(self)
	_visual.scale = Vector2.ONE * depth
	_hotspot_node.position = Vector2.ZERO
	_hotspot_node.scale = Vector2.ONE * depth


func _on_lemon_carried_changed(is_carried: bool) -> void:
	_visual.visible = not is_carried
	interaction_prompt = "Put down" if is_carried else "Pick up"
	interaction_priority = -10 if is_carried else 0
	prompt_offset = carried_prompt_offset if is_carried else _resting_prompt_offset
	# Above anything Stella stands in front of, so clicking her arms means Lemon.
	hotspot_priority = 10 if is_carried else 0
	set_physics_process(is_carried)
