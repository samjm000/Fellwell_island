class_name Room
extends Node2D
## A playable room. Rooms only wire their own pieces together; behaviour lives in
## the reusable characters, interactables and UI they contain.
##
## Every room has a `%Stella`, a `%PointAndClick` and an `%InteractionPrompt`.
## Entered through a RoomExit, it places Stella at the RoomArrival under
## `Arrivals` that the exit named; loaded directly, she stays where she was authored.

@onready var _point_and_click: PointAndClickInput = %PointAndClick
@onready var _interaction_prompt: Control = %InteractionPrompt
@onready var _stella: Stella = %Stella


func _ready() -> void:
	_point_and_click.hovered_changed.connect(_interaction_prompt.set_target)
	var arrival := RoomTransition.take_arrival()
	if arrival != &"":
		place_at_arrival(arrival)


func place_at_arrival(arrival: StringName) -> bool:
	var marker := get_arrival(arrival)
	if marker == null:
		push_warning("%s has no arrival named %s" % [name, arrival])
		return false
	_stella.place_at(marker.global_position, marker.facing)
	return true


func get_arrival(arrival: StringName) -> RoomArrival:
	return get_node_or_null(NodePath("Arrivals/" + String(arrival))) as RoomArrival
