class_name TimeOfDayTint
extends CanvasModulate
## Tints a room's world canvas for the current time of day. UI on separate
## CanvasLayers is unaffected.

@export var day_color: Color = Color(1.0, 0.96, 0.88)
@export var night_color: Color = Color(0.45, 0.52, 0.8)
## 0 snaps instantly (use when the change happens behind a fade).
@export var transition_duration: float = 0.0


func _ready() -> void:
	color = _color_for(TimeManager.current_phase)
	TimeManager.phase_changed.connect(_on_phase_changed)


func _color_for(phase: GameTime.Phase) -> Color:
	match phase:
		GameTime.Phase.NIGHT:
			return night_color
		_:
			return day_color


func _on_phase_changed(new_phase: GameTime.Phase, _previous_phase: GameTime.Phase) -> void:
	var target := _color_for(new_phase)
	if transition_duration <= 0.0:
		color = target
	else:
		create_tween().tween_property(self, "color", target, transition_duration)
