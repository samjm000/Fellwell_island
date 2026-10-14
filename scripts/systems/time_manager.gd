extends Node
## Owns the current time of day.
##
## Time does not advance on a clock in this slice; it changes only when something
## asks (e.g. sleeping). Anything that looks different by time of day connects to
## `phase_changed` rather than polling `current_phase`.

signal phase_changed(new_phase: GameTime.Phase, previous_phase: GameTime.Phase)

var current_phase: GameTime.Phase = GameTime.Phase.DAY


func set_phase(new_phase: GameTime.Phase) -> void:
	if new_phase == current_phase:
		return
	var previous_phase := current_phase
	current_phase = new_phase
	phase_changed.emit(new_phase, previous_phase)


func is_phase(phase: GameTime.Phase) -> bool:
	return current_phase == phase


func is_night() -> bool:
	return current_phase == GameTime.Phase.NIGHT
