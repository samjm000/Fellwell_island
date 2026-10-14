extends Node
## Global entry point for short dialogue and observations.
##
##     await DialogueManager.play(sequence)                      # DialogueSequence resource
##     await DialogueManager.say(["Line one", "Line two"], "Stella")
##     var choice := await DialogueManager.ask("Go to sleep?", ["Yes", "Not yet"])
##
## Requests made while dialogue is already showing wait their turn. The player loses
## control of Stella for as long as dialogue is open.

signal dialogue_started
signal dialogue_finished

const DIALOGUE_BOX_SCENE: PackedScene = preload("res://scenes/ui/dialogue_box.tscn")
const CONTROL_LOCK := &"dialogue"

var _box: DialogueBox
var _is_active: bool = false


func _ready() -> void:
	_box = DIALOGUE_BOX_SCENE.instantiate()
	add_child(_box)
	_box.close()


func is_active() -> bool:
	return _is_active


func play(sequence: DialogueSequence) -> void:
	if sequence == null or sequence.lines.is_empty():
		return
	await say(sequence.lines, sequence.speaker)


func say(lines: PackedStringArray, speaker: String = "") -> void:
	if lines.is_empty():
		return
	await _begin()
	for line in lines:
		_box.show_line(speaker, line)
		await _box.advance_requested
	_end()


## Shows a question with options and returns the chosen option's index.
func ask(question: String, options: PackedStringArray, speaker: String = "") -> int:
	assert(not options.is_empty(), "DialogueManager.ask() needs at least one option")
	await _begin()
	_box.show_choice(speaker, question, options)
	var index: int = await _box.choice_selected
	_end()
	return index


func _begin() -> void:
	while _is_active:
		await dialogue_finished
	_is_active = true
	PlayerControl.acquire(CONTROL_LOCK)
	dialogue_started.emit()


func _end() -> void:
	_box.close()
	_is_active = false
	PlayerControl.release(CONTROL_LOCK)
	dialogue_finished.emit()
