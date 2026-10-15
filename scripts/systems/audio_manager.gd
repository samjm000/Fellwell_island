extends Node
## Small audio front end: one music track, a set of looping ambience layers, and
## one-shot SFX, each routed to its own bus (see default_bus_layout.tres).
##
## Sounds are referred to by id and found by file name, so supplied audio only has
## to be dropped into the right folder with the right name:
##     audio/music/<id>.ogg|.mp3|.wav
##     audio/ambience/<id>.*          looping layers and occasional one-shots
##     audio/sfx/<id>.*               or <id>_1.*, <id>_2.* ... for random variations
## Missing files are skipped quietly (logged with --verbose), so hooks can exist
## before the audio does. If a music id has no file, `fellwell_theme` is used.
##
## Music and ambience each have a base (set by the room) plus keyed overrides
## (e.g. the telescope), like PlayerControl's locks: the newest override wins and
## removing it returns to whatever is underneath.
##
## Music is never restarted needlessly: asking for the track that's already
## playing does nothing (so the theme started at boot carries on through rooms,
## time changes and the telescope), and a track interrupted by an override
## resumes where it left off when the override ends.

## Emitted when the music actually changes track (not when a request keeps the
## current one), with the new stream or null for silence.
signal music_changed(stream: AudioStream)

const BUS_MASTER := &"Master"
const BUS_MUSIC := &"Music"
const BUS_AMBIENCE := &"Ambience"
const BUS_SFX := &"SFX"
const BUS_UI := &"UI"

const MUSIC_FALLBACK_ID := &"fellwell_theme"
const EXTENSIONS: Array[String] = ["ogg", "mp3", "wav"]
const MAX_VARIATIONS := 16
const SFX_VOICES := 8

var _music_players: Array[AudioStreamPlayer] = []
var _active_music_player: int = 0
var _current_music_stream: AudioStream = null
var _base_music: StringName = &""
var _music_overrides: Dictionary = {} # source -> music id
var _music_resume_positions: Dictionary = {} # AudioStream -> seconds

var _base_ambience: Dictionary = {} # layer id -> volume_db
var _ambience_overrides: Dictionary = {} # source -> { layer id -> volume_db }
var _ambience_players: Dictionary = {} # layer id -> AudioStreamPlayer

var _sfx_players: Array[AudioStreamPlayer] = []
var _next_sfx_player: int = 0
var _stream_cache: Dictionary = {} # "folder/id" -> Array of AudioStream


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().auto_accept_quit = false # See stop_all_and_quit().
	for i in 2:
		_music_players.append(_make_player(BUS_MUSIC, "Music%d" % i))
	for i in SFX_VOICES:
		_sfx_players.append(_make_player(BUS_SFX, "Sfx%d" % i))


## Stops everything, gives the audio thread a moment to release its playbacks,
## then quits. Godot 4.3 reports leaked AudioStreamPlaybacks if the game quits
## while streams are still playing, so window closes are routed through here; a
## future Quit menu option should call it too.
func stop_all_and_quit(exit_code: int = 0) -> void:
	for child in get_children():
		if child is AudioStreamPlayer:
			child.stop()
	# Real time, not game time: under --fixed-fps (the tests) game time races ahead
	# of the audio thread.
	var release_at := Time.get_ticks_msec() + 150
	while Time.get_ticks_msec() < release_at:
		await get_tree().process_frame
	get_tree().quit(exit_code)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		stop_all_and_quit()


# --- Music -----------------------------------------------------------------------

func set_music(music_id: StringName, fade: float = 2.0) -> void:
	_base_music = music_id
	_apply_music(fade)


func push_music_override(source: StringName, music_id: StringName, fade: float = 2.0) -> void:
	_music_overrides.erase(source) # Re-adding moves it to the top.
	_music_overrides[source] = music_id
	_apply_music(fade)


func pop_music_override(source: StringName, fade: float = 2.0) -> void:
	if _music_overrides.erase(source):
		_apply_music(fade)


## The track playing now (or fading in), or null for silence.
func get_current_music() -> AudioStream:
	return _current_music_stream


## Makes generated or downloaded audio available under an id, as if it were a
## file in audio/<folder>/ (e.g. "music", &"fellwell_theme").
func register_sound(folder: String, sound_id: StringName, streams: Array) -> void:
	_stream_cache["%s/%s" % [folder, sound_id]] = streams


# --- Ambience --------------------------------------------------------------------

## `layers` maps ambience id -> volume in dB, e.g. { &"sea": -10.0, &"wind": -16.0 }.
func set_ambience(layers: Dictionary, fade: float = 2.5) -> void:
	_base_ambience = _normalise_layers(layers)
	_apply_ambience(fade)


func push_ambience_override(source: StringName, layers: Dictionary, fade: float = 1.5) -> void:
	_ambience_overrides.erase(source)
	_ambience_overrides[source] = _normalise_layers(layers)
	_apply_ambience(fade)


func pop_ambience_override(source: StringName, fade: float = 1.5) -> void:
	if _ambience_overrides.erase(source):
		_apply_ambience(fade)


## The ambience layers currently wanted (layer id -> volume in dB): the newest
## override's, or the room's base mix.
func get_ambience_mix() -> Dictionary:
	return (_ambience_overrides.values().back() if not _ambience_overrides.is_empty() else _base_ambience).duplicate()


## For occasional ambient sounds (gulls, creaks) that aren't loops.
func play_ambience_one_shot(sound_id: StringName, volume_db: float = 0.0, pitch_variation: float = 0.05) -> void:
	_play_one_shot("ambience", sound_id, BUS_AMBIENCE, volume_db, pitch_variation)


# --- One-shots -------------------------------------------------------------------

func play_sfx(sound_id: StringName, volume_db: float = 0.0, pitch_variation: float = 0.0) -> void:
	_play_one_shot("sfx", sound_id, BUS_SFX, volume_db, pitch_variation)


func play_ui(sound_id: StringName, volume_db: float = 0.0) -> void:
	_play_one_shot("sfx", sound_id, BUS_UI, volume_db, 0.0)


# --- Volume hooks for a future settings menu -----------------------------------

func set_bus_volume(bus: StringName, linear: float) -> void:
	var index := AudioServer.get_bus_index(bus)
	if index >= 0:
		AudioServer.set_bus_volume_db(index, linear_to_db(clampf(linear, 0.0, 1.0)))


func get_bus_volume(bus: StringName) -> float:
	var index := AudioServer.get_bus_index(bus)
	return db_to_linear(AudioServer.get_bus_volume_db(index)) if index >= 0 else 0.0


func set_bus_muted(bus: StringName, muted: bool) -> void:
	var index := AudioServer.get_bus_index(bus)
	if index >= 0:
		AudioServer.set_bus_mute(index, muted)


func has_sound(folder: String, sound_id: StringName) -> bool:
	return not _resolve(folder, sound_id).is_empty()


# --- Internals -------------------------------------------------------------------

func _apply_music(fade: float) -> void:
	var stream := _effective_music_stream()
	if stream == _current_music_stream:
		return
	_current_music_stream = stream
	var outgoing := _music_players[_active_music_player]
	if outgoing.playing and outgoing.stream != null:
		_music_resume_positions[outgoing.stream] = outgoing.get_playback_position()
	_fade_player(outgoing, 0.0, fade, true)
	music_changed.emit(stream)
	if stream == null:
		return
	_active_music_player = 1 - _active_music_player
	var incoming := _music_players[_active_music_player]
	if incoming.playing and incoming.stream == stream:
		# Still fading out from a moment ago: bring it back rather than restart.
		_fade_player(incoming, 1.0, fade, false)
		return
	incoming.stream = stream
	incoming.volume_db = linear_to_db(0.0)
	incoming.play(_music_resume_positions.get(stream, 0.0))
	_fade_player(incoming, 1.0, fade, false)


func _effective_music_stream() -> AudioStream:
	var overrides := _music_overrides.values()
	for i in range(overrides.size() - 1, -1, -1):
		var stream := _first_stream("music", overrides[i])
		if stream != null:
			return stream
	if _base_music == &"":
		return null
	var base := _first_stream("music", _base_music)
	return base if base != null else _first_stream("music", MUSIC_FALLBACK_ID)


func _apply_ambience(fade: float) -> void:
	var target: Dictionary = _base_ambience
	if not _ambience_overrides.is_empty():
		target = _ambience_overrides.values().back()

	for layer_id: StringName in _ambience_players.keys():
		if not target.has(layer_id):
			_fade_player(_ambience_players[layer_id], 0.0, fade, true, true)
			_ambience_players.erase(layer_id)

	for layer_id: StringName in target:
		var volume_linear := db_to_linear(float(target[layer_id]))
		if _ambience_players.has(layer_id):
			_fade_player(_ambience_players[layer_id], volume_linear, fade, false)
			continue
		var stream := _first_stream("ambience", layer_id)
		if stream == null:
			continue
		var player := _make_player(BUS_AMBIENCE, "Ambience_%s" % layer_id)
		player.stream = stream
		player.volume_db = linear_to_db(0.0)
		player.play()
		_ambience_players[layer_id] = player
		_fade_player(player, volume_linear, fade, false)


# Inspector-authored dictionaries may use String keys; layer ids are StringNames.
func _normalise_layers(layers: Dictionary) -> Dictionary:
	var normalised := {}
	for layer_id in layers:
		normalised[StringName(layer_id)] = float(layers[layer_id])
	return normalised


func _play_one_shot(folder: String, sound_id: StringName, bus: StringName, volume_db: float, pitch_variation: float) -> void:
	if sound_id == &"":
		return
	var variations := _resolve(folder, sound_id)
	if variations.is_empty():
		return
	var player := _sfx_players[_next_sfx_player]
	_next_sfx_player = (_next_sfx_player + 1) % _sfx_players.size()
	player.stream = variations.pick_random()
	player.bus = bus
	player.volume_db = volume_db
	player.pitch_scale = 1.0 + randf_range(-pitch_variation, pitch_variation)
	player.play()


func _first_stream(folder: String, sound_id: StringName) -> AudioStream:
	var variations := _resolve(folder, sound_id)
	if variations.is_empty():
		return null
	_make_looping(variations[0])
	return variations[0]


func _resolve(folder: String, sound_id: StringName) -> Array:
	var key := "%s/%s" % [folder, sound_id]
	if _stream_cache.has(key):
		return _stream_cache[key]
	var found: Array = []
	var base := "res://audio/%s/%s" % [folder, sound_id]
	for extension in EXTENSIONS:
		var single := "%s.%s" % [base, extension]
		if ResourceLoader.exists(single):
			found.append(load(single))
			break
		for index in range(1, MAX_VARIATIONS + 1):
			var variation := "%s_%d.%s" % [base, index, extension]
			if not ResourceLoader.exists(variation):
				break
			found.append(load(variation))
		if not found.is_empty():
			break
	if found.is_empty():
		print_verbose("AudioManager: no audio for '%s' (looked for %s.*)" % [sound_id, base])
	_stream_cache[key] = found
	return found


func _make_looping(stream: AudioStream) -> void:
	if stream is AudioStreamWAV:
		var wav := stream as AudioStreamWAV
		if wav.loop_mode == AudioStreamWAV.LOOP_DISABLED:
			wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
			wav.loop_begin = 0
			wav.loop_end = int(wav.get_length() * wav.mix_rate)
	elif "loop" in stream:
		stream.set("loop", true)


func _make_player(bus: StringName, player_name: String) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = player_name
	player.bus = bus
	add_child(player)
	return player


## Fades in linear amplitude (sounds more natural than a dB ramp).
func _fade_player(player: AudioStreamPlayer, to_linear: float, duration: float, stop_after: bool, free_after: bool = false) -> void:
	if player.has_meta(&"fade_tween"):
		var previous: Tween = player.get_meta(&"fade_tween")
		if previous.is_valid():
			previous.kill()
	var from_linear := db_to_linear(player.volume_db)
	var tween := create_tween()
	player.set_meta(&"fade_tween", tween)
	tween.tween_method(func(value: float) -> void: player.volume_db = linear_to_db(value),
			from_linear, to_linear, maxf(duration, 0.01))
	if free_after:
		tween.tween_callback(player.queue_free)
	elif stop_after:
		tween.tween_callback(player.stop)
