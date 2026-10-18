class_name RoomExit
extends Interactable
## A door, stair or gate that leads to another room.
##
## It is an ordinary Interactable: clicking it walks Stella to its ApproachPoint,
## and only on arrival does it ask RoomTransition for `destination` (placing her
## at its `arrival`). Nothing triggers by walking past, so she can't bounce
## straight back after arriving.
##
## With no `destination` (somewhere not built yet) it plays its `dialogue`
## instead and emits RoomTransition.world_exit_requested with `exit_id`, the
## hook for connecting the wider island later.

@export_file("*.tscn") var destination: String = ""
## The RoomArrival node name in the destination room.
@export var arrival: StringName = &""
## Names this exit for world_exit_requested when it has no destination.
@export var exit_id: StringName = &""


func can_interact(actor: Node2D) -> bool:
	return super(actor) and not RoomTransition.is_busy()


func leads_somewhere() -> bool:
	return not destination.is_empty() and ResourceLoader.exists(destination)


func interact(actor: Node2D) -> void:
	if not leads_somewhere():
		RoomTransition.world_exit_requested.emit(exit_id)
		await super(actor)
		return
	interacted.emit(actor)
	# Not awaited: this room (and this node) is freed partway through.
	RoomTransition.go_to(destination, arrival)
