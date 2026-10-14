extends Interactable
## Stella's bed. During the day she protests at first; once she admits she's
## slightly tired she can be talked into sleeping, which moves time to NIGHT.

const CONTROL_LOCK := &"sleep"

@export var not_tired_dialogue: DialogueSequence
@export var slightly_tired_dialogue: DialogueSequence
@export var fall_asleep_dialogue: DialogueSequence
@export var sleep_question: String = "Go to sleep?"
## Option 0 means "yes".
@export var sleep_options: PackedStringArray = ["Yes", "Not yet"]
@export var phase_after_sleeping: GameTime.Phase = GameTime.Phase.NIGHT
@export var bedding_sfx: StringName = &"bed_rustle"
@export var sleep_sfx: StringName = &"sleep_transition"

## Protests are per-visit flavour, not story progress, so they stay local.
var _has_protested: bool = false


func interact(actor: Node2D) -> void:
	interacted.emit(actor)
	if TimeManager.is_phase(phase_after_sleeping):
		await DialogueManager.play(get_current_dialogue())
		return

	if not _has_protested:
		_has_protested = true
		await DialogueManager.play(not_tired_dialogue)
		return

	await DialogueManager.play(slightly_tired_dialogue)
	var choice: int = await DialogueManager.ask(sleep_question, sleep_options)
	if choice != 0:
		return
	AudioManager.play_sfx(bedding_sfx)
	await DialogueManager.play(fall_asleep_dialogue)
	await _sleep()


func _sleep() -> void:
	PlayerControl.acquire(CONTROL_LOCK)
	AudioManager.play_sfx(sleep_sfx)
	await ScreenFader.fade_out()
	TimeManager.set_phase(phase_after_sleeping)
	await get_tree().create_timer(0.5).timeout
	await ScreenFader.fade_in()
	PlayerControl.release(CONTROL_LOCK)
