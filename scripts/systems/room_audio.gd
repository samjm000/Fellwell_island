class_name RoomAudio
extends Node
## Declares a room's music and ambience for each time of day and keeps
## AudioManager in step through TimeManager.phase_changed. Also plays occasional
## ambient one-shots (gulls, creaks) at random intervals.

@export var day_music: StringName = &""
@export var night_music: StringName = &""
## Looping ambience layer id -> volume in dB.
@export var day_ambience: Dictionary = {}
@export var night_ambience: Dictionary = {}
## Occasional one-shot ids (files in audio/ambience/).
@export var day_occasional: PackedStringArray = []
@export var night_occasional: PackedStringArray = []
## Random gap between occasional sounds, in seconds (min, max).
@export var occasional_interval: Vector2 = Vector2(10.0, 25.0)
@export var occasional_volume_db: float = -8.0
@export var crossfade: float = 2.5

var _occasional_timer: Timer


func _ready() -> void:
	_occasional_timer = Timer.new()
	_occasional_timer.one_shot = true
	_occasional_timer.timeout.connect(_on_occasional_timeout)
	add_child(_occasional_timer)
	TimeManager.phase_changed.connect(_on_phase_changed)
	_apply(TimeManager.current_phase, 1.5)
	_schedule_occasional()


func _apply(phase: GameTime.Phase, fade: float) -> void:
	var is_night := phase == GameTime.Phase.NIGHT
	AudioManager.set_music(night_music if is_night else day_music, fade)
	AudioManager.set_ambience(night_ambience if is_night else day_ambience, fade)


func _schedule_occasional() -> void:
	_occasional_timer.start(randf_range(occasional_interval.x, occasional_interval.y))


func _on_occasional_timeout() -> void:
	var options := night_occasional if TimeManager.is_night() else day_occasional
	if not options.is_empty():
		AudioManager.play_ambience_one_shot(StringName(options[randi() % options.size()]), occasional_volume_db)
	_schedule_occasional()


func _on_phase_changed(new_phase: GameTime.Phase, _previous_phase: GameTime.Phase) -> void:
	_apply(new_phase, crossfade)
