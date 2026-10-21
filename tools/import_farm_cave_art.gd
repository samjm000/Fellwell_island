extends SceneTree
## Usage: godot --headless --path . --script tools/import_island_art.gd -- FARM.png CAVE_INTERIOR.png CAVE_EXTERIOR.png
## Preserve full source pixels; copy approved farm and cave originals without pixel changes.
func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 3:
		push_error("Pass the approved farm, cave interior and cave exterior paths")
		quit(1)
		return
	var targets := ["res://art/backgrounds/farm/day.png", "res://art/backgrounds/maxs_cave/interior.png", "res://art/backgrounds/maxs_cave/exterior.png"]
	for i in targets.size():
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(targets[i].get_base_dir()))
		var source := FileAccess.get_file_as_bytes(args[i])
		if source.is_empty():
			push_error("Cannot read approved source: " + args[i])
			quit(1)
			return
		var destination := FileAccess.open(targets[i], FileAccess.WRITE)
		destination.store_buffer(source)
		destination.close()
	_enable_mipmaps("res://art/backgrounds")
	_enable_mipmaps("res://art/characters")
	quit()

func _enable_mipmaps(directory: String) -> void:
	for child in DirAccess.get_directories_at(directory):
		_enable_mipmaps(directory.path_join(child))
	for file in DirAccess.get_files_at(directory):
		if not file.ends_with(".png.import"):
			continue
		var path := directory.path_join(file)
		var config := ConfigFile.new()
		if config.load(path) != OK:
			continue
		config.set_value("params", "mipmaps/generate", true)
		config.set_value("params", "process/size_limit", 0)
		config.set_value("params", "compress/mode", 0)
		config.save(path)
