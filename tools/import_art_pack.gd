extends SceneTree
## Copies runtime-ready images from a Fellwell art pack into the project,
## downscaling oversized character art so it isn't stored and loaded at many times
## its on-screen size. Source/reference art stays in the pack, not the repo.
##
## Usage (from the repo root):
##     godot --headless --path . --script tools/import_art_pack.gd -- "<path to art pack>" [pack]
##
## `pack` names one of PACKS; without it, the first pack whose files are all in
## the folder is used. Each entry is: pack-relative source, project-relative
## destination, scale. Files at scale 1.0 are copied byte for byte (so they stay
## identical to the pack and its checksums); scaled ones are colour-bled before
## resizing so transparent borders don't darken.

const PACKS := {
	"art_pack_v1": [
		["art/backgrounds/stellas_room/day.png", "art/backgrounds/stellas_room/day.png", 1.0],
		["art/backgrounds/stellas_room/night.png", "art/backgrounds/stellas_room/night.png", 1.0],
		["art/telescope/day.png", "art/telescope/day.png", 1.0],
		["art/telescope/night.png", "art/telescope/night.png", 1.0],
	],
	# fellwell-stellas-house-v1. Its bedroom paintings are the ones already installed.
	"stellas_house_v1": [
		["art/entrance_hall_day.png", "art/backgrounds/entrance_hall/day.png", 1.0],
		["art/entrance_hall_night.png", "art/backgrounds/entrance_hall/night.png", 1.0],
		["art/kitchen_living_day.png", "art/backgrounds/kitchen_living/day.png", 1.0],
		["art/kitchen_living_night.png", "art/backgrounds/kitchen_living/night.png", 1.0],
		["art/exterior_day.png", "art/backgrounds/cottage_exterior/day.png", 1.0],
		["art/exterior_night.png", "art/backgrounds/cottage_exterior/night.png", 1.0],
	],
}


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		printerr("Usage: godot --headless --path . --script tools/import_art_pack.gd -- <art pack dir> [pack]")
		quit(1)
		return
	var pack: String = args[0]
	var entries := _pick_entries(pack, args[1] if args.size() > 1 else "")
	if entries.is_empty():
		printerr("No known pack matches ", pack, " (packs: ", ", ".join(PACKS.keys()), ")")
		quit(1)
		return
	var failures := 0
	for entry in entries:
		var source := pack.path_join(entry[0])
		var destination := ProjectSettings.globalize_path("res://" + entry[1])
		var scale: float = entry[2]
		if is_equal_approx(scale, 1.0):
			DirAccess.make_dir_recursive_absolute(destination.get_base_dir())
			var copy_error := DirAccess.copy_absolute(source, destination)
			if copy_error != OK:
				printerr("Could not copy ", source, ": ", error_string(copy_error))
				failures += 1
				continue
			print("%s  (copied)" % entry[1])
			continue
		var image := Image.load_from_file(source)
		if image == null or image.is_empty():
			printerr("Missing or unreadable: ", source)
			failures += 1
			continue
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


func _pick_entries(pack: String, pack_name: String) -> Array:
	if not pack_name.is_empty():
		return PACKS.get(pack_name, [])
	for candidate: String in PACKS:
		var complete := true
		for entry in PACKS[candidate]:
			complete = complete and FileAccess.file_exists(pack.path_join(entry[0]))
		if complete:
			return PACKS[candidate]
	return []
