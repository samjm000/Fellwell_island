extends Interactable
## Lemon, Stella's soft, golden, fluffy dog (a toy, though nothing in the game
## says so outright).
##
## Lemon is a companion state, not an AI: she is either in the room or in Stella's
## arms. GameState owns that fact; this node and Stella's carried visual both react
## to it. While carried, this node follows the carrier so "Put down" stays in reach
## (with low keyboard-focus priority so it never steals focus from objects in the
## room), and her hotspot moves up to the carrier's arms so she can be clicked there.
##
## Picking up is timed to the carrier's `pickup_animation` when it has one:
##   1. Stella walks to the spot beside Lemon where the pickup art draws her (see
##      `pickup_offset`), on the side Lemon is looking towards, so the art's Lemon
##      faces the same way as this sprite. (Only if that spot isn't floor does she
##      use the other side, and Lemon is then drawn mirrored.)
##   2. The pickup starts. Its frames draw Lemon, in the same place, so this
##      floor sprite hands over to them without a visible change.
##   3. On `lift_frame` (Lemon leaves the floor) GameState marks her carried.
##   4. When the animation ends Stella is in carry_idle, and says her line.
## Putting down plays the same animation backwards: GameState changes on
## `set_down_frame`, and the floor sprite reappears when it ends, where the art
## left her. Without pickup art it falls back to an instant pick-up / put-down.
##
## Every room has a Lemon node, but only one is her. Carried, she's in whichever
## room Stella is in; set down, GameState remembers the room and spot, and she
## waits there. In any other room this node hides and can't be used.

## True for the room she starts a new game in (Stella's bedroom), where she is
## until she's first picked up.
@export var starts_in_room: bool = true
@export var pick_up_dialogue: DialogueSequence
@export var put_down_dialogue: DialogueSequence
## The carrier's one-shot animation for picking Lemon up (played backwards to
## put her down).
@export var pickup_animation: StringName = &"pickup_lemon_right"
## Where the pickup art draws Lemon on the floor, relative to the carrier's feet,
## facing right, at depth scale 1 (measured by tools/process_stella_animations.gd).
@export var pickup_offset: Vector2 = Vector2(130.4, -4.3)
## Pickup frame (0-based) in which Lemon leaves the floor.
@export var lift_frame: int = 4
## Frame (0-based) at which, played backwards, her paws are back on the floor.
@export var set_down_frame: int = 3
## Which way the floor sprite looks as authored (-1 left, 1 right). The sprite
## is cut from the first pickup frame, looking at a Stella on her left.
@export var sprite_facing: float = -1.0
## Without pickup art: where Lemon is set down, relative to the carrier's feet
## (x is mirrored by facing).
@export var put_down_offset: Vector2 = Vector2(44, 6)
@export var carried_prompt_offset: Vector2 = Vector2(0, -170)
## Where her hotspot sits while carried, relative to the carrier's feet facing
## right (mirrored when the carrier faces left).
@export var carried_hotspot_offset: Vector2 = Vector2(0, -200)
@export var pick_up_sfx: StringName = &"lemon_pick_up"
@export var put_down_sfx: StringName = &"lemon_put_down"

var _carrier: Node2D = null
var _resting_prompt_offset: Vector2
## True while a pickup or put-down animation is playing.
var _in_transition: bool = false
var _set_down_at: Vector2
## Which way she looks on the floor; put-downs leave her as the art drew her.
var _floor_facing: float = -1.0

@onready var _visual: Node2D = %Visual
@onready var _hotspot_node: Node2D = %Hotspot


func _ready() -> void:
	_resting_prompt_offset = prompt_offset
	_floor_facing = sprite_facing
	GameState.lemon_carried_changed.connect(_on_lemon_carried_changed)
	if GameState.is_lemon_carried:
		# Entering a room already carrying Lemon.
		_carrier = get_tree().get_first_node_in_group("player") as Node2D
	elif GameState.lemon_room == _room_id() and not GameState.lemon_room.is_empty():
		# Back where Stella left her.
		global_position = GameState.lemon_position
		_floor_facing = GameState.lemon_facing
	_on_lemon_carried_changed(GameState.is_lemon_carried)
	if not GameState.is_lemon_carried:
		_apply_floor_depth()
	# Presence only changes through this node (picking her up here, or putting
	# her down here), so it's settled once, on entering the room.
	visible = is_here()
	enabled = is_here()


func _physics_process(_delta: float) -> void:
	if _carrier != null:
		global_position = _carrier.global_position
		# In Stella's arms she scales with Stella; keep the hotspot on her there.
		var depth := RoomPerspective.scale_for(self)
		var facing: float = _carrier.get("facing") if "facing" in _carrier else 1.0
		_hotspot_node.position = Vector2(carried_hotspot_offset.x * facing, carried_hotspot_offset.y) * depth
		_hotspot_node.scale = Vector2(facing, 1.0) * depth
		prompt_offset = carried_prompt_offset * depth


func can_interact(actor: Node2D) -> bool:
	return super(actor) and not _in_transition


## True when Lemon is in this room: carried by Stella, or set down here.
func is_here() -> bool:
	if GameState.is_lemon_carried:
		return true
	if GameState.lemon_room.is_empty():
		return starts_in_room
	return GameState.lemon_room == _room_id()


## On the floor, Stella goes to the spot where the pickup art draws Lemon beside
## her feet, on the side Lemon is looking towards (the other side if that spot
## isn't floor). Carried, Lemon is already in her arms.
func get_approach_position() -> Vector2:
	if GameState.is_lemon_carried:
		return global_position
	var preferred := -_floor_facing # Stella faces Lemon, who faces her.
	for facing in [preferred, -preferred]:
		var spot := _pickup_spot(facing)
		if _is_floor(spot):
			return spot
	return _pickup_spot(preferred)


func interact(actor: Node2D) -> void:
	interacted.emit(actor)
	var animated: bool = actor.has_method("has_action") and actor.has_action(pickup_animation)
	if GameState.is_lemon_carried:
		if animated:
			await _put_down_animated(actor)
		else:
			_put_down(actor)
			AudioManager.play_sfx(put_down_sfx)
		await DialogueManager.play(put_down_dialogue)
	else:
		if animated:
			await _pick_up_animated(actor)
		else:
			_pick_up(actor)
			AudioManager.play_sfx(pick_up_sfx)
		await DialogueManager.play(pick_up_dialogue)


# --- Animated -----------------------------------------------------------------------

func _pick_up_animated(actor: Node2D) -> void:
	_in_transition = true
	# The pickup frames draw Lemon from the first frame, where this sprite was.
	_visual.visible = false
	var on_frame := func(animation: StringName, frame: int) -> void:
		if animation == pickup_animation and frame >= lift_frame and not GameState.is_lemon_carried:
			_pick_up(actor)
			AudioManager.play_sfx(pick_up_sfx)
	actor.action_frame.connect(on_frame)
	await actor.perform(pickup_animation)
	actor.action_frame.disconnect(on_frame)
	if not GameState.is_lemon_carried:
		_pick_up(actor) # The lift frame was skipped (e.g. a very short animation).
	_in_transition = false


func _put_down_animated(actor: Node2D) -> void:
	# Turn to whichever side has floor for her, then lower her there.
	var facing: float = actor.get("facing")
	if not _is_floor(_set_down_spot(actor, facing)) and _is_floor(_set_down_spot(actor, -facing)):
		facing = -facing
		actor.set("facing", facing)
	_set_down_at = _set_down_spot(actor, facing)
	if not _is_floor(_set_down_at):
		# Neither side is floor: she'll appear at the nearest floor point, which
		# may not match where the art drew her.
		_set_down_at = _closest_floor(_set_down_at)
	_in_transition = true
	var on_frame := func(animation: StringName, frame: int) -> void:
		if animation == pickup_animation and frame <= set_down_frame and GameState.is_lemon_carried:
			_carrier = null
			global_position = _set_down_at
			GameState.is_lemon_carried = false # The floor sprite stays hidden until the end.
			AudioManager.play_sfx(put_down_sfx)
	actor.action_frame.connect(on_frame)
	await actor.perform(pickup_animation, true)
	actor.action_frame.disconnect(on_frame)
	if GameState.is_lemon_carried:
		_carrier = null
		global_position = _set_down_at
		GameState.is_lemon_carried = false
	_in_transition = false
	_floor_facing = -facing # Facing Stella, as the art left her.
	_apply_floor_depth()
	_visual.visible = true
	_remember_floor_spot()


func _pickup_spot(facing: float) -> Vector2:
	var depth := RoomPerspective.scale_for(self)
	return global_position - Vector2(pickup_offset.x * facing, pickup_offset.y) * depth


func _set_down_spot(actor: Node2D, facing: float) -> Vector2:
	var depth := RoomPerspective.scale_for(actor)
	return actor.global_position + Vector2(pickup_offset.x * facing, pickup_offset.y) * depth


func _closest_floor(point: Vector2) -> Vector2:
	var map := get_world_2d().navigation_map
	if NavigationServer2D.map_get_iteration_id(map) == 0:
		return point
	return NavigationServer2D.map_get_closest_point(map, point)


func _is_floor(point: Vector2) -> bool:
	return _closest_floor(point).distance_to(point) < 2.0


# --- Instant (no pickup art) --------------------------------------------------------

func _pick_up(actor: Node2D) -> void:
	_carrier = actor
	GameState.is_lemon_carried = true


func _put_down(actor: Node2D) -> void:
	var facing: float = actor.get("facing") if "facing" in actor else 1.0
	_carrier = null
	global_position = actor.global_position + Vector2(put_down_offset.x * facing, put_down_offset.y)
	GameState.is_lemon_carried = false
	_apply_floor_depth()
	_remember_floor_spot()


func _remember_floor_spot() -> void:
	GameState.place_lemon(_room_id(), global_position, _floor_facing)


## The scene path of the room this node belongs to.
func _room_id() -> String:
	return owner.scene_file_path if owner != null else ""


## On the floor she is sized for where she sits, like Stella.
func _apply_floor_depth() -> void:
	var depth := RoomPerspective.scale_for(self)
	_visual.scale = Vector2(_floor_facing * sprite_facing, 1.0) * depth
	_hotspot_node.position = Vector2.ZERO
	_hotspot_node.scale = Vector2.ONE * depth
	prompt_offset = _resting_prompt_offset * depth


func _on_lemon_carried_changed(is_carried: bool) -> void:
	_visual.visible = not is_carried and not _in_transition
	interaction_prompt = "Put down" if is_carried else "Pick up"
	interaction_priority = -10 if is_carried else 0
	prompt_offset = carried_prompt_offset if is_carried else _resting_prompt_offset
	# Above anything Stella stands in front of, so clicking her arms means Lemon.
	hotspot_priority = 10 if is_carried else 0
	set_physics_process(is_carried)
