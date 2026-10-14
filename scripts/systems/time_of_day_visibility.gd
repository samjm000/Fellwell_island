class_name TimeOfDayVisibility
extends CanvasItem
## Attach to any CanvasItem (Node2D, ColorRect, ...) to show it only during the
## selected phases, e.g. a night sky in a window or a lamp glow.

## Bit order must match GameTime.Phase.
@export_flags("Day", "Night") var visible_during: int = 1


func _ready() -> void:
	_apply(TimeManager.current_phase)
	TimeManager.phase_changed.connect(_on_phase_changed)


func _apply(phase: GameTime.Phase) -> void:
	visible = (visible_during & GameTime.phase_bit(phase)) != 0


func _on_phase_changed(new_phase: GameTime.Phase, _previous_phase: GameTime.Phase) -> void:
	_apply(new_phase)
