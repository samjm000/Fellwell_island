extends Control
## The game's first scene: black, the Fellwell Island title fading in as the theme
## begins, then a fade into the first room. The theme keeps playing into the room
## (RoomAudio asks for the same track, so AudioManager doesn't restart it).
##
## INTRO INSERTION POINT: set `intro_scene` to a scene (a video player, an
## AnimationPlayer sequence, an image slideshow...) and it plays in `IntroSlot`
## between the title and the room. Its root must emit `finished` when done (and may
## handle its own skipping). Nothing else needs to change, in this script or in
## any room.
##
## A click or the interact / cancel keys skip the title hold.

const THEME_MUSIC := &"fellwell_theme"

@export_file("*.tscn") var first_room: String = "res://scenes/rooms/stellas_room.tscn"
## Optional intro shown after the title; see the insertion point note above.
@export var intro_scene: PackedScene
## Optional title art; the text title is shown when it's missing.
@export_file("*.png", "*.webp") var title_art_path: String = "res://art/ui/title.png"

@export_group("Timing")
@export var black_before_title: float = 0.6
@export var title_fade_in: float = 1.8
@export var title_hold: float = 2.6
@export var title_fade_out: float = 1.0
@export var music_fade_in: float = 2.5
@export var room_fade_in: float = 1.2

var _skip_requested: bool = false

@onready var _title_card: Control = %TitleCard
@onready var _title_text: Control = %TitleText
@onready var _title_art: TextureRect = %TitleArt
@onready var _intro_slot: Control = %IntroSlot


func _ready() -> void:
	_title_card.modulate.a = 0.0
	var art := ArtSlot.load_optional_texture(title_art_path)
	_title_art.texture = art
	_title_art.visible = art != null
	_title_text.visible = art == null
	_run.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if (button != null and button.pressed) or event.is_action_pressed("interact") or event.is_action_pressed("ui_cancel"):
		_skip_requested = true
		get_viewport().set_input_as_handled()


func _run() -> void:
	await _wait(black_before_title, false)
	_start_theme()
	await _fade_title(1.0, title_fade_in)
	await _wait(title_hold, true)
	await _fade_title(0.0, title_fade_out)
	if intro_scene != null:
		await _play_intro()
	_enter_first_room()


func _start_theme() -> void:
	if not AudioManager.has_sound("music", THEME_MUSIC):
		print("Fellwell: theme music not installed yet; add audio/music/%s.ogg and it will play from here." % THEME_MUSIC)
	AudioManager.set_music(THEME_MUSIC, music_fade_in)


func _play_intro() -> void:
	var intro := intro_scene.instantiate()
	_intro_slot.add_child(intro)
	if intro.has_signal(&"finished"):
		await intro.finished
	else:
		push_warning("Boot: intro scene %s has no 'finished' signal; skipping it." % intro_scene.resource_path)
	intro.queue_free()


func _enter_first_room() -> void:
	# Cut to black, swap scenes, and let the fader (an autoload, so it outlives this
	# scene) bring the room up.
	await ScreenFader.fade_out(0.0)
	get_tree().change_scene_to_file(first_room)
	ScreenFader.fade_in(room_fade_in)


func _fade_title(alpha: float, duration: float) -> void:
	var tween := create_tween().set_trans(Tween.TRANS_SINE)
	tween.tween_property(_title_card, "modulate:a", alpha, duration)
	await tween.finished


func _wait(seconds: float, skippable: bool) -> void:
	var remaining := seconds
	while remaining > 0.0 and not (skippable and _skip_requested):
		await get_tree().process_frame
		remaining -= get_process_delta_time()
