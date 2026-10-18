extends "res://tests/framework/test_case.gd"
## Stella's runtime animations match their recorded source (the video), so frames
## can always be regenerated from what's committed.

const MANIFEST := "res://art/characters/stella/animations/manifest.json"


func before_each() -> void:
	pass # No room needed.


func after_each() -> void:
	pass


func load_manifest() -> Dictionary:
	var text := FileAccess.get_file_as_string(MANIFEST)
	var parsed: Variant = JSON.parse_string(text)
	check(parsed is Dictionary, "manifest.json parses")
	return parsed if parsed is Dictionary else {}


func test_animations_trace_to_committed_source() -> void:
	var manifest := load_manifest()
	var frames: SpriteFrames = load(manifest.get("sprite_frames", ""))
	check(frames != null, "the SpriteFrames resource loads")
	for entry: Dictionary in manifest.get("animations", []):
		var source := ProjectSettings.globalize_path("res://" + String(entry.source))
		check(FileAccess.file_exists(source), "%s: source %s is committed" % [entry.animation, entry.source])
		check_eq(FileAccess.get_sha256(source), entry.source_sha256, "%s: source unchanged since the frames were made" % entry.animation)
		for file: String in entry.frames:
			check(ResourceLoader.exists(String(entry.folder).path_join(file)), "%s: %s exists" % [entry.animation, file])
		if frames != null:
			check_eq(frames.get_frame_count(StringName(entry.animation)), entry.frames.size(), "%s: SpriteFrames has every frame" % entry.animation)


func test_lemon_sprite_recorded() -> void:
	var lemon: Dictionary = load_manifest().get("lemon_floor_sprite", {})
	check(ResourceLoader.exists(lemon.get("runtime", "")), "Lemon's floor sprite exists")
	var scene: PackedScene = load("res://scenes/interactables/lemon.tscn")
	var node := scene.instantiate()
	var offset: Array = lemon.get("pickup_offset", [0, 0])
	check(node.pickup_offset.distance_to(Vector2(offset[0], offset[1])) < 0.6, "Lemon's pickup_offset matches the processed art")
	node.free()


func test_runtime_never_loads_source_or_deprecated_art() -> void:
	for folder in ["res://scenes", "res://scripts", "res://data"]:
		for path in _files_under(folder):
			var text := FileAccess.get_file_as_string(path)
			check(not text.contains("assets_source/"), "%s doesn't load from assets_source/" % path)


func _files_under(folder: String) -> PackedStringArray:
	var found: PackedStringArray = []
	var dir := DirAccess.open(folder)
	if dir == null:
		return found
	for file in dir.get_files():
		found.append(folder.path_join(file))
	for sub in dir.get_directories():
		found.append_array(_files_under(folder.path_join(sub)))
	return found
