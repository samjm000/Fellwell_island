extends SceneTree
## Copies runtime-ready images from a Fellwell art pack into the project,
## downscaling oversized character art so it isn't stored and loaded at many times
## its on-screen size. Source/reference art stays in the pack, not the repo.
##
## Usage (from the repo root):
##     godot --headless --path . --script tools/import_art_pack.gd -- "<path to art pack>"
##
## Each entry is: pack-relative source, project-relative destination, scale.
## Edges are colour-bled before resizing so transparent borders don't darken.

const ENTRIES := [
	["art/backgrounds/stellas_room/day.png", "art/backgrounds/stellas_room/day.png", 1.0],
	["art/backgrounds/stellas_room/night.png", "art/backgrounds/stellas_room/night.png", 1.0],
	["art/characters/stella/idle/frame_0001.png", "art/characters/stella/idle/frame_0001.png", 0.5],
	["art/characters/stella/carry_idle/frame_0001.png", "art/characters/stella/carry_idle/frame_0001.png", 0.5],
	["art/characters/lemon/idle.png", "art/characters/lemon/idle.png", 0.25],
	["art/telescope/day.png", "art/telescope/day.png", 1.0],
	["art/telescope/night.png", "art/telescope/night.png", 1.0],
]


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		printerr("Usage: godot --headless --path . --script tools/import_art_pack.gd -- <art pack dir>")
		quit(1)
		return
	var pack: String = args[0]
	var failures := 0
	for entry in ENTRIES:
		var source := pack.path_join(entry[0])
		var destination := ProjectSettings.globalize_path("res://" + entry[1])
		var image := Image.load_from_file(source)
		if image == null or image.is_empty():
			printerr("Missing or unreadable: ", source)
			failures += 1
			continue
		var scale: float = entry[2]
		if not is_equal_approx(scale, 1.0):
			if image.detect_alpha() != Image.ALPHA_NONE:
				image.fix_alpha_edges()
			image.resize(roundi(image.get_width() * scale), roundi(image.get_height() * scale), Image.INTERPOLATE_LANCZOS)
		DirAccess.make_dir_recursive_absolute(destination.get_base_dir())
		var error := image.save_png(destination)
		if error != OK:
			printerr("Could not write ", destination, ": ", error_string(error))
			failures += 1
			continue
		print("%s  %dx%d" % [entry[1], image.get_width(), image.get_height()])
	quit(1 if failures > 0 else 0)
