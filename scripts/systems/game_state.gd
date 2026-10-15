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

var _flags: Dictionary = {}


## Returns to the state of a fresh playthrough (a new game, or between tests).
func reset() -> void:
	is_lemon_carried = false
	for flag: StringName in _flags.keys():
		set_flag(flag, false)
	_flags.clear()


func has_flag(flag: StringName) -> bool:
	return _flags.get(flag, false)


func set_flag(flag: StringName, value: bool = true) -> void:
	if has_flag(flag) == value:
		return
	_flags[flag] = value
	flag_changed.emit(flag, value)


func has_seen_offshore_light() -> bool:
	return has_flag(FLAG_SEEN_OFFSHORE_LIGHT)
