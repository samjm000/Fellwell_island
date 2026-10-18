extends Node
## Moves Stella from one room to another.
##
## A RoomExit asks for a room and a named arrival once Stella has walked to it.
## The transition holds a PlayerControl lock (which stops her and ignores clicks),
## fades out, changes scene, and leaves the arrival name for the new room, whose
## Room script places her at that RoomArrival. Then it fades in and hands control
## back. Lemon and the time of day live in autoloads, so they carry over as they
## are. A request made while a transition is running is ignored.
##
## Exits that lead somewhere not built yet emit `world_exit_requested` instead
## (see RoomExit); nothing listens to it until the wider island exists.

signal room_changed(room: Node)
## Integration hook: an exit with no destination room was used (e.g. the garden
## gate). `exit_id` names it.
signal world_exit_requested(exit_id: StringName)

const LOCK := &"room_transition"

@export var fade_duration: float = 0.35

var _pending_arrival: StringName = &""
var _busy: bool = false


func is_busy() -> bool:
	return _busy


## Changes to `scene_path` and places Stella at its `arrival`. Returns false if a
## transition is already running or the scene doesn't exist.
func go_to(scene_path: String, arrival: StringName) -> bool:
	if _busy or not ResourceLoader.exists(scene_path):
		return false
	_busy = true
	PlayerControl.acquire(LOCK)
	await ScreenFader.fade_out(fade_duration)
	var tree := get_tree()
	var previous := tree.current_scene
	_pending_arrival = arrival
	tree.change_scene_to_file(scene_path)
	while tree.current_scene == null or tree.current_scene == previous:
		await tree.process_frame
	_pending_arrival = &"" # Taken by the new room in its _ready, or unused.
	# Let the new floor's navigation map sync before she can be sent anywhere.
	await tree.physics_frame
	await tree.physics_frame
	room_changed.emit(tree.current_scene)
	await ScreenFader.fade_in(fade_duration)
	PlayerControl.release(LOCK)
	_busy = false
	return true


## The arrival the room being entered should place Stella at (empty when a room
## is loaded directly). Clears it, so it's only used once.
func take_arrival() -> StringName:
	var arrival := _pending_arrival
	_pending_arrival = &""
	return arrival
