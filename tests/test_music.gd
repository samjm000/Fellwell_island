extends "res://tests/framework/test_case.gd"
## Theme music continuity, with a generated stand-in registered as
## `fellwell_theme` (the real track isn't in the repo yet).

const BOOT_SCENE := "res://scenes/boot/boot.tscn"

var theme: AudioStreamWAV
var mystery: AudioStreamWAV
var track_changes: Array[AudioStream] = []


func before_each() -> void:
	theme = make_silence(4.0)
	mystery = make_silence(3.0)
	AudioManager.register_sound("music", &"fellwell_theme", [theme])
	AudioManager.register_sound("music", &"telescope_mystery", [])
	if not AudioManager.music_changed.is_connected(_on_music_changed):
		AudioManager.music_changed.connect(_on_music_changed)
	track_changes.clear()
	await unload_room()


func make_silence(seconds: float) -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = 22050
	var data := PackedByteArray()
	data.resize(int(seconds * wav.mix_rate) * 2)
	wav.data = data
	return wav


func boot_into_room() -> void:
	GameState.reset()
	TimeManager.set_phase(GameTime.Phase.DAY)
	var boot: Node = load(BOOT_SCENE).instantiate()
	get_tree().root.add_child(boot)
	get_tree().current_scene = boot
	await wait_until(func() -> bool: return get_tree().current_scene != null \
			and get_tree().current_scene.scene_file_path == ROOM_SCENE, 15.0, "the room")
	room = get_tree().current_scene
	stella = room.get_node("%Stella")
	point_and_click = room.get_node("%PointAndClick")
	await wait_physics_frames(3)


func music_player_for(stream: AudioStream) -> AudioStreamPlayer:
	for child in AudioManager.get_children():
		if child is AudioStreamPlayer and child.bus == AudioManager.BUS_MUSIC and child.playing and child.stream == stream:
			return child
	return null


func test_theme_starts_at_boot_and_continues() -> void:
	await boot_into_room()
	check_eq(AudioManager.get_current_music(), theme, "the theme plays from boot")
	check_eq(track_changes.size(), 1, "one track change: silence -> theme")
	var player := music_player_for(theme)
	check(player != null, "a music player is playing the theme")

	# Telescope by day, then sleep to night, then telescope at night.
	await interact_with(interactable("Telescope"))
	await wait_for_dialogue()
	await advance_dialogue()
	await press(&"ui_cancel")
	TimeManager.set_phase(GameTime.Phase.NIGHT)
	await wait_seconds(0.5)
	await interact_with(interactable("Telescope"))
	await wait_for_dialogue()
	await advance_dialogue()
	await press(&"ui_cancel")
	await wait_seconds(0.5)

	check_eq(track_changes.size(), 1, "the theme was never restarted or swapped")
	check_eq(music_player_for(theme), player, "the same player is still playing it")


func test_ambience_mix_preserved() -> void:
	await boot_into_room()
	var day_mix := AudioManager.get_ambience_mix()
	check(day_mix.has(&"sea") and day_mix.has(&"wind"), "the room's day ambience plays alongside the theme (%s)" % day_mix)
	await interact_with(interactable("Telescope"))
	check(AudioManager.get_ambience_mix()[&"sea"] > day_mix[&"sea"], "the telescope brings the sea closer")
	await wait_for_dialogue()
	await advance_dialogue()
	await press(&"ui_cancel")
	check_eq(AudioManager.get_ambience_mix(), day_mix, "closing the telescope restores the room mix")
	TimeManager.set_phase(GameTime.Phase.NIGHT)
	check(AudioManager.get_ambience_mix().has(&"night_insects"), "night ambience at night")
	check_eq(AudioManager.get_current_music(), theme, "theme unchanged at night")


func test_override_returns_to_theme_without_restart() -> void:
	await boot_into_room()
	AudioManager.register_sound("music", &"telescope_mystery", [mystery])
	TimeManager.set_phase(GameTime.Phase.NIGHT)
	var theme_player := music_player_for(theme)
	await interact_with(interactable("Telescope"))
	check_eq(AudioManager.get_current_music(), mystery, "a night telescope motif can take over")
	await wait_for_dialogue()
	await advance_dialogue()
	await press(&"ui_cancel")
	await wait_frames(2)
	check_eq(AudioManager.get_current_music(), theme, "the theme returns after the telescope")
	check_eq(music_player_for(theme), theme_player, "the theme is brought back, not restarted on a new player")
	AudioManager.register_sound("music", &"telescope_mystery", [])
	await wait_seconds(2.5)


func _on_music_changed(stream: AudioStream) -> void:
	track_changes.append(stream)
