class_name DialogueBox
extends CanvasLayer
## Presentation for DialogueManager: shows one line (with a typewriter reveal) or a
## question with options, and reports player input back via signals. It holds no
## dialogue flow of its own.

signal advance_requested
signal choice_selected(index: int)

enum Mode { HIDDEN, LINE, CHOICE }

@export var characters_per_second: float = 50.0
@export var advance_sfx: StringName = &"ui_confirm"
@export var select_sfx: StringName = &"ui_select"
@export var confirm_sfx: StringName = &"ui_confirm"

var _mode: Mode = Mode.HIDDEN
var _reveal_tween: Tween
var _options: PackedStringArray = []
var _option_labels: Array[Label] = []
var _selected_option: int = 0

@onready var _speaker_tag: Control = %SpeakerTag
@onready var _speaker_label: Label = %SpeakerLabel
@onready var _body_label: Label = %BodyLabel
@onready var _options_container: VBoxContainer = %Options
@onready var _continue_hint: Label = %ContinueHint


func _ready() -> void:
	# A slow breathing pulse on the "more" marker; cheap and only visible when shown.
	var pulse := create_tween().set_loops().set_trans(Tween.TRANS_SINE)
	pulse.tween_property(_continue_hint, "self_modulate:a", 0.45, 0.7)
	pulse.tween_property(_continue_hint, "self_modulate:a", 1.0, 0.7)


func show_line(speaker: String, text: String) -> void:
	_mode = Mode.LINE
	_show_speaker_and_text(speaker, text)
	_clear_options()
	_continue_hint.visible = false
	_body_label.visible_ratio = 0.0
	_reveal_tween = create_tween()
	_reveal_tween.tween_property(_body_label, "visible_ratio", 1.0, text.length() / characters_per_second)
	_reveal_tween.finished.connect(_on_reveal_finished)
	visible = true


func show_choice(speaker: String, question: String, options: PackedStringArray) -> void:
	_mode = Mode.CHOICE
	_show_speaker_and_text(speaker, question)
	_body_label.visible_ratio = 1.0
	_continue_hint.visible = false
	_clear_options()
	_options = options
	for option in options:
		var label := Label.new()
		label.theme_type_variation = &"DialogueOption"
		_options_container.add_child(label)
		_option_labels.append(label)
	_options_container.visible = true
	_select_option(0)
	visible = true


func close() -> void:
	_mode = Mode.HIDDEN
	_stop_reveal()
	_clear_options()
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	match _mode:
		Mode.LINE:
			if event.is_action_pressed("interact"):
				get_viewport().set_input_as_handled()
				if _is_revealing():
					_stop_reveal()
					_body_label.visible_ratio = 1.0
					_on_reveal_finished()
				else:
					AudioManager.play_ui(advance_sfx, -6.0)
					advance_requested.emit()
		Mode.CHOICE:
			if event.is_action_pressed("move_up"):
				get_viewport().set_input_as_handled()
				AudioManager.play_ui(select_sfx)
				_select_option(_selected_option - 1)
			elif event.is_action_pressed("move_down"):
				get_viewport().set_input_as_handled()
				AudioManager.play_ui(select_sfx)
				_select_option(_selected_option + 1)
			elif event.is_action_pressed("interact"):
				get_viewport().set_input_as_handled()
				AudioManager.play_ui(confirm_sfx)
				choice_selected.emit(_selected_option)


func _show_speaker_and_text(speaker: String, text: String) -> void:
	_speaker_label.text = speaker
	_speaker_tag.visible = not speaker.is_empty()
	_body_label.text = text


func _select_option(index: int) -> void:
	_selected_option = wrapi(index, 0, _option_labels.size())
	for i in _option_labels.size():
		_option_labels[i].text = ("> " if i == _selected_option else "   ") + _options[i]


func _clear_options() -> void:
	for label in _option_labels:
		label.queue_free()
	_option_labels.clear()
	_options = []
	_options_container.visible = false


func _is_revealing() -> bool:
	return _reveal_tween != null and _reveal_tween.is_running()


func _stop_reveal() -> void:
	if _reveal_tween != null:
		_reveal_tween.kill()
		_reveal_tween = null


func _on_reveal_finished() -> void:
	_continue_hint.visible = true
