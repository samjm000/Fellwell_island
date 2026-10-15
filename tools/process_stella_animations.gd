extends SceneTree
## Turns Stella's animation source sheets into runtime frames.
##
##     tools/godot.sh --headless --path . --script tools/process_stella_animations.gd [-- "<sheet folder>" [qa_dir]]
##
## The sheet folder defaults to assets_source/character_sheets/stella/ (the
## committed source sheets); qa_dir defaults to user://stella_animation_qa.
##
## For each sheet in SHEETS:
##   1. Poses are found from the alpha channel (connected shapes), not a grid.
##      Small separate shapes (Lemon sitting beside Stella) join the pose on their
##      left; isolated low-alpha specks left by background removal are dropped.
##   2. Edge pixels whose colour was fringed by the matting (red/yellow halos) take
##      the colour of the opaque pixels next to them; their alpha is unchanged.
##   3. The sheet is scaled by `scale` so Stella is the same size in every
##      animation (sheets were drawn at different sizes; see docs/art-direction.md).
##   4. Every frame is placed on one shared canvas with Stella's feet anchor at the
##      bottom centre: the lowest opaque row (floor contact) and an anchor x (see
##      ANCHOR_*), so frames never jump against each other.
## Outputs art/characters/stella/animations/<name>/frame_NNNN.png, the SpriteFrames
## resource art/characters/stella/animations/stella_frames.tres, Lemon's world
## sprite (cut from the first pickup pose, where she sits on the floor),
## art/characters/stella/animations/manifest.json (which source sheet, by SHA-256,
## produced which animation, with the settings used) and QA contact sheets plus a
## measurement report in qa_dir.

const OUT_DIR := "res://art/characters/stella/animations"
const FRAMES_RESOURCE := "res://art/characters/stella/animations/stella_frames.tres"
const LEMON_SPRITE := "res://art/characters/lemon/idle.png"
const MANIFEST := "res://art/characters/stella/animations/manifest.json"
const DEFAULT_SOURCE_DIR := "res://assets_source/character_sheets/stella"

## Anchor x: the centre of the thighs band (stable while the legs swing).
const ANCHOR_THIGHS := "thighs"
## Anchor x: the frame's right edge, i.e. Lemon on the floor in the pickup
## (she must stay still while Stella moves around her), shifted for the whole
## sequence so that in its first frame Stella's thighs are on the anchor, matching
## idle. Lemon then stays put and idle -> pickup doesn't jump.
const ANCHOR_RIGHT_EDGE := "right_edge"

## Stella's standing height on the canvas, in Visual units (art_scale 1.0).
const TARGET_HEIGHT := 384.0
## Height of the walk sheet's Stella in source pixels; the reference size.
const WALK_SOURCE_HEIGHT := 620.0

## Per sheet: source file, animation name, scale relative to the walk sheet
## (measured from shoe size and standing height), fps, loop, anchor mode, and
## optional per-frame duration multipliers.
const SHEETS := [
	{"file": "stella_animation_2", "name": "idle", "relative": 1.22, "fps": 5.0, "loop": true, "anchor": ANCHOR_THIGHS,
		"durations": [10.0, 1.0, 0.6, 1.0]},
	{"file": "stella_animation", "name": "walk", "relative": 1.0, "fps": 8.0, "loop": true, "anchor": ANCHOR_THIGHS},
	# Frames 1-4: Lemon is on (or just off) the floor, so she stays fixed. Frames
	# 5-6: Stella is standing with Lemon in her arms, so her hips match carry_idle.
	{"file": "stella_pick_up_lemon", "name": "pickup_lemon", "relative": 0.855, "fps": 8.0, "loop": false, "anchor": ANCHOR_RIGHT_EDGE,
		"frame_anchors": [ANCHOR_RIGHT_EDGE, ANCHOR_RIGHT_EDGE, ANCHOR_RIGHT_EDGE, ANCHOR_RIGHT_EDGE, ANCHOR_THIGHS, ANCHOR_THIGHS]},
	{"file": "stella_holding_lemon", "name": "carry_idle", "relative": 1.165, "fps": 5.0, "loop": true, "anchor": ANCHOR_THIGHS,
		"durations": [10.0, 0.6, 1.0, 1.0]},
	{"file": "stella_walking_lemon", "name": "carry_walk", "relative": 0.966, "fps": 8.0, "loop": true, "anchor": ANCHOR_THIGHS},
]
## Animation names in the SpriteFrames resource (all authored facing right).
const ANIMATION_SUFFIX := "_right"

const BODY_ALPHA := 128
const KEEP_ALPHA := 8
const MIN_BODY_AREA := 20000
const MIN_STELLA_AREA := 50000

var _report: PackedStringArray = []


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var source_dir: String = args[0] if args.size() > 0 else ProjectSettings.globalize_path(DEFAULT_SOURCE_DIR)
	var qa_dir: String = args[1] if args.size() > 1 else ProjectSettings.globalize_path("user://stella_animation_qa")
	DirAccess.make_dir_recursive_absolute(qa_dir)

	var processed := {} # name -> Array of {image, anchor}
	var lemon_still := {}
	var sources := {} # name -> {file, sha256}
	for sheet: Dictionary in SHEETS:
		var path := source_dir.path_join(sheet.file)
		if not FileAccess.file_exists(path):
			path += ".png"
		# The supplied sheets have no extension, so decode the bytes as PNG.
		var image := Image.new()
		if not FileAccess.file_exists(path) or image.load_png_from_buffer(FileAccess.get_file_as_bytes(path)) != OK:
			push_error("Missing or unreadable sheet: " + path)
			quit(1)
			return
		image.convert(Image.FORMAT_RGBA8)
		sources[sheet.name] = {"file": path.get_file(), "sha256": FileAccess.get_sha256(path),
				"size": [image.get_width(), image.get_height()]}
		var scale: float = TARGET_HEIGHT / WALK_SOURCE_HEIGHT / float(sheet.relative)
		var frames := _extract_frames(image, sheet, scale)
		processed[sheet.name] = frames
		if sheet.name == "pickup_lemon":
			lemon_still = _extract_lemon(image, scale)

	var canvas := _canvas_size(processed)
	_report.append("canvas %dx%d, feet anchor at bottom centre" % [canvas.x, canvas.y])
	var resource_animations := []
	for sheet: Dictionary in SHEETS:
		var folder := OUT_DIR.path_join(sheet.name)
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
		_clear_frames(folder)
		var animation_frames := []
		var placed: Array[Image] = []
		var frames: Array = processed[sheet.name]
		for index in frames.size():
			var frame_image := _place(frames[index], canvas)
			placed.append(frame_image)
			var file := folder.path_join("frame_%04d.png" % (index + 1))
			frame_image.save_png(ProjectSettings.globalize_path(file))
			var durations: Array = sheet.get("durations", [])
			var duration: float = durations[index] if index < durations.size() else 1.0
			animation_frames.append({"path": file, "duration": duration})
		resource_animations.append({"name": sheet.name + ANIMATION_SUFFIX, "fps": sheet.fps, "loop": sheet.loop, "frames": animation_frames,
				"folder": folder, "sheet": sheet})
		_save_contact_sheet(placed, qa_dir.path_join("%s_contact.png" % sheet.name))
	_write_sprite_frames(resource_animations)

	var lemon_entry := {}
	if not lemon_still.is_empty():
		var lemon_image: Image = lemon_still.image
		lemon_image.save_png(ProjectSettings.globalize_path(LEMON_SPRITE))
		# Where Lemon sits relative to Stella's feet in pickup frame 1 (Visual units, facing right).
		var first: Dictionary = processed["pickup_lemon"][0]
		var offset: Vector2 = lemon_still.origin_in_sheet - first.anchor_in_sheet
		_report.append("lemon sprite %dx%d; pickup offset from Stella's feet: (%.1f, %.1f)" % [
			lemon_image.get_width(), lemon_image.get_height(), offset.x, offset.y])
		lemon_entry = {"runtime": LEMON_SPRITE, "source": sources["pickup_lemon"].file,
				"cut_from": "pickup frame 1 (Lemon sitting beside Stella)",
				"pickup_offset": [snappedf(offset.x, 0.1), snappedf(offset.y, 0.1)]}
	_write_manifest(resource_animations, sources, canvas, lemon_entry, source_dir)
	var report := FileAccess.open(qa_dir.path_join("report.txt"), FileAccess.WRITE)
	report.store_string("\n".join(_report) + "\n")
	print("\n".join(_report))
	print("QA files in " + qa_dir)
	quit()


# --- Extraction --------------------------------------------------------------------

## Returns, per pose: {image (scaled, cropped), anchor (in the scaled crop),
## anchor_in_sheet (scaled sheet coordinates)}.
func _extract_frames(image: Image, sheet: Dictionary, scale: float) -> Array:
	var w := image.get_width()
	var h := image.get_height()
	var data := image.get_data()
	var components := _components(data, w, h, BODY_ALPHA, MIN_BODY_AREA)
	var bodies: Array = components.bodies
	var stellas: Array = bodies.filter(func(c: Dictionary) -> bool: return c.area >= MIN_STELLA_AREA)
	stellas.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.x0 < b.x0)
	# Each body joins the Stella pose it belongs to (its own, or the one on its left).
	var owner := {}
	for body: Dictionary in bodies:
		var best := 0
		for i in stellas.size():
			if stellas[i].x0 <= body.x0:
				best = i
		owner[body.id] = best
	var pixel_frame := _grow_from_bodies(data, w, h, components, owner)
	var crops := []
	for i in stellas.size():
		crops.append(_crop_frame(data, w, h, pixel_frame, i))
	var sequence_shift := 0.0
	if sheet.anchor == ANCHOR_RIGHT_EDGE:
		# Stella's own thighs only: Lemon sits at thigh height beside her.
		var first: Dictionary = crops[0]
		var thighs_in_sheet := _thigh_centre(data, w, components.labels, stellas[0])
		sequence_shift = (thighs_in_sheet - first.origin.x) - _measure(first.image, ANCHOR_RIGHT_EDGE).anchor.x
	var frames := []
	for i in stellas.size():
		var frame: Dictionary = crops[i]
		var frame_anchors: Array = sheet.get("frame_anchors", [])
		var mode: String = frame_anchors[i] if i < frame_anchors.size() else sheet.anchor
		var measured := _measure(frame.image, mode)
		if mode == ANCHOR_RIGHT_EDGE:
			measured.anchor.x += sequence_shift
		var scaled: Image = frame.image.duplicate()
		_defringe(scaled)
		scaled.resize(maxi(1, roundi(scaled.get_width() * scale)), maxi(1, roundi(scaled.get_height() * scale)), Image.INTERPOLATE_LANCZOS)
		var anchor: Vector2 = measured.anchor * scale
		frames.append({"image": scaled, "anchor": anchor, "anchor_in_sheet": (frame.origin + measured.anchor) * scale})
		_report.append("%s frame %d: source bbox (%d,%d) %dx%d, sole y %d, anchor x %.1f -> scaled %dx%d" % [
			sheet.name, i + 1, frame.origin.x, frame.origin.y, frame.image.get_width(), frame.image.get_height(),
			int(frame.origin.y + measured.anchor.y), frame.origin.x + measured.anchor.x, scaled.get_width(), scaled.get_height()])
	return frames


## Lemon's still for the world sprite: the separate shape beside Stella in the
## first pickup pose, cut on its own. Origin = bottom centre (floor contact).
func _extract_lemon(image: Image, scale: float) -> Dictionary:
	var w := image.get_width()
	var h := image.get_height()
	var data := image.get_data()
	var components := _components(data, w, h, BODY_ALPHA, MIN_BODY_AREA)
	var lemons: Array = components.bodies.filter(func(c: Dictionary) -> bool: return c.area < MIN_STELLA_AREA)
	if lemons.is_empty():
		return {}
	lemons.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.x0 < b.x0)
	var lemon: Dictionary = lemons[0]
	var owner := {lemon.id: 0} # Every other body grows too (tag -1), so it keeps its own halo.
	var pixel_frame := _grow_from_bodies(data, w, h, components, owner)
	var frame := _crop_frame(data, w, h, pixel_frame, 0)
	var bottom := _lowest_row(frame.image)
	var origin := Vector2(frame.image.get_width() * 0.5, bottom + 1)
	var still: Image = frame.image.duplicate()
	_defringe(still)
	still.resize(maxi(1, roundi(still.get_width() * scale)), maxi(1, roundi(still.get_height() * scale)), Image.INTERPOLATE_LANCZOS)
	# Trim below the floor contact so the sprite's bottom centre is the origin.
	var cut := still.get_region(Rect2i(0, 0, still.get_width(), mini(still.get_height(), roundi(origin.y * scale))))
	return {"image": cut, "origin_in_sheet": (frame.origin + origin) * scale}


## Connected shapes of pixels with alpha >= alpha_min (8-way). Returns
## {bodies: shapes of at least min_area, labels: shape id per pixel}.
func _components(data: PackedByteArray, w: int, h: int, alpha_min: int, min_area: int) -> Dictionary:
	var label := PackedInt32Array()
	label.resize(w * h)
	var found := []
	var stack := PackedInt32Array()
	var next := 1
	for start in w * h:
		if data[start * 4 + 3] < alpha_min or label[start] != 0:
			continue
		var c := {"id": next, "area": 0, "x0": w, "y0": h, "x1": 0, "y1": 0, "seed": start}
		stack.clear()
		stack.append(start)
		label[start] = next
		while not stack.is_empty():
			var p := stack[stack.size() - 1]
			stack.resize(stack.size() - 1)
			var x := p % w
			var y := p / w
			c.area += 1
			c.x0 = mini(c.x0, x); c.x1 = maxi(c.x1, x); c.y0 = mini(c.y0, y); c.y1 = maxi(c.y1, y)
			for dy in range(-1, 2):
				var ny := y + dy
				if ny < 0 or ny >= h:
					continue
				for dx in range(-1, 2):
					var nx := x + dx
					if nx < 0 or nx >= w:
						continue
					var q := ny * w + nx
					if label[q] == 0 and data[q * 4 + 3] >= alpha_min:
						label[q] = next
						stack.append(q)
		if c.area >= min_area:
			found.append(c)
		next += 1
	return {"bodies": found, "labels": label}


## Assigns pixels to poses. Every body's opaque pixels are seeded at once
## (tag = owner + 1, or -1 for bodies nobody exports), then the tags grow
## breadth-first through faint pixels (KEEP_ALPHA <= alpha < BODY_ALPHA), so soft
## edges go to the nearest body. Opaque pixels of small shapes and isolated
## faint specks are never reached: they are dropped. Returns tag per pixel.
func _grow_from_bodies(data: PackedByteArray, w: int, h: int, components: Dictionary, owner: Dictionary) -> PackedInt32Array:
	var labels: PackedInt32Array = components.labels
	var tag_of_label := {}
	for body: Dictionary in components.bodies:
		tag_of_label[body.id] = owner[body.id] + 1 if owner.has(body.id) else -1
	var frame_of := PackedInt32Array()
	frame_of.resize(w * h)
	var queue := PackedInt32Array()
	for p in w * h:
		var label := labels[p]
		if label != 0 and tag_of_label.has(label):
			frame_of[p] = tag_of_label[label]
			queue.append(p)
	var head := 0
	while head < queue.size():
		var p := queue[head]
		head += 1
		var tag := frame_of[p]
		var x := p % w
		var y := p / w
		for dy in range(-1, 2):
			var ny := y + dy
			if ny < 0 or ny >= h:
				continue
			for dx in range(-1, 2):
				var nx := x + dx
				if nx < 0 or nx >= w:
					continue
				var q := ny * w + nx
				var a := data[q * 4 + 3]
				if frame_of[q] == 0 and a >= KEEP_ALPHA and a < BODY_ALPHA:
					frame_of[q] = tag
					queue.append(q)
	return frame_of


func _crop_frame(data: PackedByteArray, w: int, h: int, pixel_frame: PackedInt32Array, index: int) -> Dictionary:
	var tag := index + 1
	var x0 := w; var y0 := h; var x1 := -1; var y1 := -1
	for p in w * h:
		if pixel_frame[p] == tag:
			var x := p % w
			var y := p / w
			x0 = mini(x0, x); x1 = maxi(x1, x); y0 = mini(y0, y); y1 = maxi(y1, y)
	var cw := x1 - x0 + 1
	var ch := y1 - y0 + 1
	var out := PackedByteArray()
	out.resize(cw * ch * 4)
	for y in ch:
		for x in cw:
			var p := (y + y0) * w + (x + x0)
			if pixel_frame[p] == tag:
				var o := (y * cw + x) * 4
				for k in 4:
					out[o + k] = data[p * 4 + k]
	return {"image": Image.create_from_data(cw, ch, false, Image.FORMAT_RGBA8, out), "origin": Vector2(x0, y0)}


# --- Measuring -----------------------------------------------------------------------

func _lowest_row(image: Image) -> int:
	var data := image.get_data()
	var w := image.get_width()
	for y in range(image.get_height() - 1, -1, -1):
		for x in w:
			if data[(y * w + x) * 4 + 3] >= BODY_ALPHA:
				return y
	return image.get_height() - 1


## Feet anchor within the crop: y = floor contact (just below the lowest opaque
## row); x per the sheet's anchor mode.
func _measure(image: Image, mode: String) -> Dictionary:
	var data := image.get_data()
	var w := image.get_width()
	var h := image.get_height()
	var sole := _lowest_row(image)
	var top := 0
	var anchor_x := w * 0.5
	if mode == ANCHOR_RIGHT_EDGE:
		for x in range(w - 1, -1, -1):
			var hit := false
			for y in h:
				if data[(y * w + x) * 4 + 3] >= BODY_ALPHA:
					hit = true
					break
			if hit:
				anchor_x = x + 1
				break
	else:
		var y0 := top + int((sole - top) * 0.63)
		var y1 := top + int((sole - top) * 0.74)
		var sum := 0.0
		var count := 0
		for y in range(y0, y1 + 1):
			for x in w:
				if data[(y * w + x) * 4 + 3] >= BODY_ALPHA:
					sum += x
					count += 1
		if count > 0:
			anchor_x = sum / count
	return {"anchor": Vector2(anchor_x, sole + 1)}


## Mean x of one shape's pixels in its thighs band (63-74% down its height).
func _thigh_centre(data: PackedByteArray, w: int, labels: PackedInt32Array, body: Dictionary) -> float:
	var y0: int = body.y0 + int((body.y1 - body.y0) * 0.63)
	var y1: int = body.y0 + int((body.y1 - body.y0) * 0.74)
	var sum := 0.0
	var count := 0
	for y in range(y0, y1 + 1):
		for x in range(body.x0, body.x1 + 1):
			if labels[y * w + x] == body.id:
				sum += x
				count += 1
	return sum / maxi(count, 1)


# --- Cleaning ------------------------------------------------------------------------

## Matting left red/yellow halos on soft edges. Give every partly transparent
## pixel the average colour of the fully opaque pixels within 2 px (alpha kept),
## then bleed colour into transparent pixels so resizing doesn't darken edges.
func _defringe(image: Image) -> void:
	var w := image.get_width()
	var h := image.get_height()
	var src := image.get_data()
	var out := src.duplicate()
	for y in h:
		for x in w:
			var i := (y * w + x) * 4
			var a := src[i + 3]
			if a == 0 or a >= 250:
				continue
			var r := 0; var g := 0; var b := 0; var n := 0
			for dy in range(-2, 3):
				var ny := y + dy
				if ny < 0 or ny >= h:
					continue
				for dx in range(-2, 3):
					var nx := x + dx
					if nx < 0 or nx >= w:
						continue
					var j := (ny * w + nx) * 4
					if src[j + 3] >= 250:
						r += src[j]; g += src[j + 1]; b += src[j + 2]; n += 1
			if n > 0:
				out[i] = r / n; out[i + 1] = g / n; out[i + 2] = b / n
	for pass_index in 3:
		var bled := out.duplicate()
		for y in h:
			for x in w:
				var i := (y * w + x) * 4
				if out[i + 3] != 0:
					continue
				for d in [[1, 0], [-1, 0], [0, 1], [0, -1]]:
					var nx: int = x + d[0]
					var ny: int = y + d[1]
					if nx < 0 or ny < 0 or nx >= w or ny >= h:
						continue
					var j := (ny * w + nx) * 4
					if out[j + 3] != 0 or (out[j] + out[j + 1] + out[j + 2]) > 0:
						bled[i] = out[j]; bled[i + 1] = out[j + 1]; bled[i + 2] = out[j + 2]
						break
		out = bled
	image.set_data(w, h, false, Image.FORMAT_RGBA8, out)


# --- Assembly ------------------------------------------------------------------------

func _canvas_size(processed: Dictionary) -> Vector2i:
	var half_width := 0.0
	var height := 0.0
	for frames: Array in processed.values():
		for frame: Dictionary in frames:
			var image: Image = frame.image
			var anchor: Vector2 = frame.anchor
			half_width = maxf(half_width, maxf(anchor.x, image.get_width() - anchor.x))
			height = maxf(height, anchor.y)
	return Vector2i(int(ceil(half_width)) * 2 + 4, int(ceil(height)) + 4)


func _place(frame: Dictionary, canvas: Vector2i) -> Image:
	var out := Image.create(canvas.x, canvas.y, false, Image.FORMAT_RGBA8)
	var image: Image = frame.image
	var anchor: Vector2 = frame.anchor
	var dest := Vector2i(roundi(canvas.x * 0.5 - anchor.x), roundi(canvas.y - anchor.y))
	out.blend_rect(image, Rect2i(Vector2i.ZERO, image.get_size()), dest)
	return out


func _clear_frames(folder: String) -> void:
	var dir := DirAccess.open(folder)
	if dir == null:
		return
	# Only stale frame images; their .import files are kept (Godot reuses them).
	for file in dir.get_files():
		if file.begins_with("frame_") and file.get_extension() == "png":
			dir.remove(file)


func _write_manifest(animations: Array, sources: Dictionary, canvas: Vector2i, lemon: Dictionary, source_dir: String) -> void:
	var entries := []
	for animation: Dictionary in animations:
		var sheet: Dictionary = animation.sheet
		var frames := []
		for frame: Dictionary in animation.frames:
			frames.append(frame.path.get_file())
		entries.append({
			"animation": animation.name,
			"folder": animation.folder,
			"source_sheet": "assets_source/character_sheets/stella/" + sources[sheet.name].file,
			"source_sha256": sources[sheet.name].sha256,
			"source_size": sources[sheet.name].size,
			"frames": frames,
			"fps": sheet.fps,
			"loop": sheet.loop,
			"frame_durations": sheet.get("durations", []),
			"scale_relative_to_walk": sheet.relative,
			"anchor": sheet.get("frame_anchors", sheet.anchor),
		})
	var manifest := {
		"generated_by": "tools/process_stella_animations.gd",
		"design": "canonical Stella (assets_source/concept_art/stella_lemon_character_sheet.png)",
		"canvas": [canvas.x, canvas.y],
		"feet_anchor": "bottom centre",
		"sprite_frames": FRAMES_RESOURCE,
		"animations": entries,
		"lemon_floor_sprite": lemon,
	}
	var file := FileAccess.open(ProjectSettings.globalize_path(MANIFEST), FileAccess.WRITE)
	file.store_string(JSON.stringify(manifest, "\t") + "\n")


## Written as text because the PNGs aren't imported yet when this runs; Godot
## resolves the Texture2D references when the resource is loaded.
func _write_sprite_frames(animations: Array) -> void:
	var ext := PackedStringArray()
	var entries := PackedStringArray()
	var id := 1
	for animation: Dictionary in animations:
		var frames := PackedStringArray()
		for frame: Dictionary in animation.frames:
			ext.append('[ext_resource type="Texture2D" path="%s" id="%d"]' % [frame.path, id])
			frames.append('{\n"duration": %s,\n"texture": ExtResource("%d")\n}' % [str(frame.duration), id])
			id += 1
		entries.append('{\n"frames": [%s],\n"loop": %s,\n"name": &"%s",\n"speed": %s\n}' % [
			", ".join(frames), "true" if animation.loop else "false", animation.name, str(animation.fps)])
	var text := '[gd_resource type="SpriteFrames" load_steps=%d format=3]\n\n' % (id)
	text += "\n".join(ext) + "\n\n[resource]\nanimations = [" + ", ".join(entries) + "]\n"
	var file := FileAccess.open(ProjectSettings.globalize_path(FRAMES_RESOURCE), FileAccess.WRITE)
	file.store_string(text)


func _save_contact_sheet(frames: Array[Image], path: String) -> void:
	if frames.is_empty():
		return
	var size := frames[0].get_size()
	var sheet := Image.create(size.x * frames.size(), size.y, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.32, 0.3, 0.34))
	for i in frames.size():
		sheet.blend_rect(frames[i], Rect2i(Vector2i.ZERO, size), Vector2i(i * size.x, 0))
		for y in size.y:
			sheet.set_pixel(i * size.x + size.x / 2, y, Color(0, 1, 1, 0.6)) # anchor x
		for x in size.x:
			sheet.set_pixel(i * size.x + x, size.y - 3, Color(1, 0, 1)) # floor line
			sheet.set_pixel(i * size.x + x, size.y - 3 - int(TARGET_HEIGHT), Color(1, 1, 0, 0.6)) # target height
	sheet.save_png(path)
