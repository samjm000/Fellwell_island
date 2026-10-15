class_name RoomPerspective
extends Node
## How large characters appear at each depth of a room: slightly smaller at the
## back of the floor, slightly larger at the front. Characters scale about their
## feet, so they stay planted.
##
## Add one to a room and tune it there; characters find it through its group.
## Rooms without one show characters at their authored size.

const GROUP := &"room_perspective"

## Floor y (feet) at the back of the walkable area, and the scale there.
@export var far_y: float = 553.0
@export var far_scale: float = 0.92
## Floor y at the front of the walkable area, and the scale there.
@export var near_y: float = 704.0
@export var near_scale: float = 1.05


func _enter_tree() -> void:
	add_to_group(GROUP)


## Scale for feet at `y`, clamped to the far/near range.
func scale_at(y: float) -> float:
	return lerpf(far_scale, near_scale, clampf(inverse_lerp(far_y, near_y, y), 0.0, 1.0))


## The perspective of the room `node` is in; 1.0 everywhere if it has none.
static func scale_for(node: Node2D) -> float:
	var perspective := node.get_tree().get_first_node_in_group(GROUP) as RoomPerspective
	return perspective.scale_at(node.global_position.y) if perspective != null else 1.0
