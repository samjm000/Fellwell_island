extends "res://tests/framework/test_case.gd"
## The boot flow: black, title, (optional intro), then Stella's room, with and
## without the theme installed.

const BOOT_SCENE := "res://scenes/boot/boot.tscn"

const INTRO_SOURCE := """extends Node
signal finished
var started_at := -1.0
func _ready() -> void:
	started_at = Time.get_ticks_msec()
	await get_tree().create_timer(0.8).timeout
	finished.emit()
"""

var boot: Control = null


func before_each() -> void:
	await unload_room()
	GameState.reset()
	TimeManager.set_phase(GameTime.Phase.DAY)


## Starts the boot scene as the current scene, the way the game launches.
func start_boot(intro: PackedScene = null) -> void:
	boot = load(BOOT_SCENE).instantiate()
	if intro != null:
		boot.intro_scene = intro
	get_tree().root.add_child(boot)
	get_tree().current_scene = boot


func title_alpha() -> float:
	return boot.get_node("%TitleCard").modulate.a if is_instance_valid(boot) else 0.0


func in_room() -> bool:
	var current := get_tree().current_scene
	return current != null and current.scene_file_path == ROOM_SCENE


func adopt_room() -> void:
	room = get_tree().current_scene
	stella = room.get_node("%Stella")
	point_and_click = room.get_node("%PointAndClick")


func test_boot_is_main_scene() -> void:
	check_eq(ProjectSettings.get_setting("application/run/main_scene"), BOOT_SCENE, "the game starts at the boot scene")


func test_title_then_room() -> void:
	start_boot()
	await wait_frames(2)
	check(title_alpha() < 0.05, "starts on black")
	check(await wait_until(func() -> bool: return title_alpha() > 0.95, 5.0, "the title to fade in"), "the title appears")
	check(not in_room(), "the title holds before the room")
	check(await wait_until(in_room, 15.0, "the room"), "boot continues into Stella's room")
	adopt_room()
	check(await wait_until(func() -> bool: return ScreenFader.get_node("%Overlay").color.a < 0.01, 3.0, "the fade-in"),
			"the room fades up from black")
	check(PlayerControl.has_control(), "the player can play")
	if AudioManager.has_sound("music", &"fellwell_theme"):
		check(AudioManager.get_current_music() != null, "the installed theme is playing in the room")
	else:
		check(AudioManager.get_current_music() == null, "no theme installed: silence, without errors")


func test_missing_theme_is_silent() -> void:
	AudioManager.register_sound("music", &"fellwell_theme", []) # As if the file were absent.
	start_boot()
	check(await wait_until(in_room, 15.0, "the room"), "boot reaches the room without the theme")
	adopt_room()
	check(AudioManager.get_current_music() == null, "silence, without errors")
	await wait_seconds(1.5)


func test_click_skips_title_hold() -> void:
	start_boot()
	await wait_until(func() -> bool: return title_alpha() > 0.95, 5.0, "the title")
	var hold: float = boot.title_hold
	var fallback_time: float = hold + boot.title_fade_out
	await click_screen(Vector2(640, 360))
	var elapsed := 0.0
	while not in_room() and elapsed < fallback_time + 2.0:
		await get_tree().process_frame
		elapsed += get_process_delta_time()
	check(in_room(), "the room loads after skipping")
	check(elapsed < hold, "skipping cuts the title hold short (%.2fs)" % elapsed)
	adopt_room()
	await wait_seconds(1.5)


func test_intro_insertion_point() -> void:
	var script := GDScript.new()
	script.source_code = INTRO_SOURCE
	check_eq(script.reload(), OK, "test intro compiles")
	var intro_root := Node.new()
	intro_root.name = "TestIntro"
	intro_root.set_script(script)
	var intro := PackedScene.new()
	intro.pack(intro_root)
	intro_root.free()

	start_boot(intro)
	var slot: Control = boot.get_node("%IntroSlot")
	check(await wait_until(func() -> bool: return slot.get_child_count() > 0, 10.0, "the intro to start"),
			"the intro plays in the IntroSlot")
	check(title_alpha() < 0.05, "the title has faded before the intro")
	check(not in_room(), "the room waits for the intro")
	check(await wait_until(in_room, 10.0, "the room after the intro"), "the room follows the intro's finished signal")
	adopt_room()
	await wait_seconds(1.5)
