extends Node
## Story and world state for the current playthrough.
##
## Kept deliberately small: time of day, dialogue and player control live in their
## own autoloads. One-off story progress is stored as named flags so new puzzle
## threads don't each need a new field and signal here. This is the natural place
## to serialise from once saving exists.

signal lemon_carried_changed(is_carried: bool)
signal flag_changed(flag: StringName, value: bool)

## Story flags. Declared here so every flag in the game is discoverable in one place.
const FLAG_SEEN_OFFSHORE_LIGHT := &"seen_offshore_light"

var is_lemon_carried: bool = false:
	set(value):
		if value == is_lemon_carried:
			return
		is_lemon_carried = value
		lemon_carried_changed.emit(value)

## Where Lemon is when she isn't carried: the scene path of the room she was
## set down in, her floor position there and which way she looks. Empty until
## she's first put down; until then she's wherever a room's Lemon starts
## (`starts_in_room`, Stella's bedroom).
var lemon_room: String = ""
var lemon_position: Vector2 = Vector2.ZERO
var lemon_facing: float = -1.0

var _flags: Dictionary = {}


## Returns to the state of a fresh playthrough (a new game, or between tests).
func reset() -> void:
	is_lemon_carried = false
	lemon_room = ""
	lemon_position = Vector2.ZERO
	lemon_facing = -1.0
	for flag: StringName in _flags.keys():
		set_flag(flag, false)
	_flags.clear()


## Records Lemon set down in `room` (a scene path) at `position`, looking
## `facing` (-1 left, 1 right). She stays there while Stella is elsewhere.
func place_lemon(room: String, position: Vector2, facing: float) -> void:
	lemon_room = room
	lemon_position = position
	lemon_facing = facing


func has_flag(flag: StringName) -> bool:
	return _flags.get(flag, false)


func set_flag(flag: StringName, value: bool = true) -> void:
	if has_flag(flag) == value:
		return
	_flags[flag] = value
	flag_changed.emit(flag, value)


func has_seen_offshore_light() -> bool:
	return has_flag(FLAG_SEEN_OFFSHORE_LIGHT)
