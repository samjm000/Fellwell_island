extends Room
## Integrates the approved waterfall without altering its renderer or timings.

@onready var waterfall: FellwellWaterfall = $Background/Waterfall

func _ready() -> void:
	super()
	TimeManager.phase_changed.connect(_on_phase_changed)
	_on_phase_changed(TimeManager.current_phase, TimeManager.current_phase)

func _on_phase_changed(_phase: GameTime.Phase, _previous: GameTime.Phase) -> void:
	waterfall.night = TimeManager.is_night()
