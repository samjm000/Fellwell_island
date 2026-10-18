extends SceneTree
## Turns Stella's animation video into runtime frames.
##
##     tools/extract_stella_video.sh      # the video's frames, background removed
##     tools/godot.sh --headless --path . --script tools/process_stella_animations.gd [-- frames_dir [qa_dir]]
##
## frames_dir defaults to .godot/stella_video_frames/ (what the extract script
## writes; frame_0001.png is the video's first frame); qa_dir defaults to
## user://stella_animation_qa.
##
## The video (VIDEO) is one continuous take: Stella standing, walking on the
## spot, then Lemon appears, Stella kneels, picks her up and walks carrying her.
## The camera never moves, so every frame keeps its place in the video: one crop
## (SOURCE_RECT) is scaled by SCALE onto the shared canvas, with Stella's feet
## (STELLA_FEET) at the bottom centre, apart from FLOOR_MARGIN_PX below them for
## the near foot, which reaches a little lower in the three-quarter view. Each
## animation in ANIMATIONS is a run of video frames, taken every other frame
## (12 fps, on twos) unless listed.
##
## Outputs art/characters/stella/animations/<name>/frame_NNNN.png, the SpriteFrames
## resource art/characters/stella/animations/stella_frames.tres, Lemon's floor
## sprite (cut from the first pickup frame, where she sits beside Stella),
## art/characters/stella/animations/manifest.json (which video, by SHA-256, and
## which of its frames made each animation) and QA contact sheets plus a
## measurement report in qa_dir.

const OUT_DIR := "res://art/characters/stella/animations"
const FRAMES_RESOURCE := "res://art/characters/stella/animations/stella_frames.tres"
const LEMON_SPRITE := "res://art/characters/lemon/idle.png"
const MANIFEST := "res://art/characters/stella/animations/manifest.json"
const VIDEO := "assets_source/character_video/stella/stella_walk_and_pickup.mp4"
const DEFAULT_FRAMES_DIR := "res://.godot/stella_video_frames"

## Stella's standing height on the canvas, in Visual units (art_scale 1.0), and
## in the video (top of her hair to the floor, standing).
const TARGET_HEIGHT := 384.0
const VIDEO_STANDING_HEIGHT := 675.0
const SCALE := TARGET_HEIGHT / VIDEO_STANDING_HEIGHT
## The part of the video every frame is cut from (everything Stella and Lemon
## reach), centred on Stella's feet.
const SOURCE_RECT := Rect2i(262, 20, 756, 692)
const STELLA_FEET := Vector2(640, 706)
## How far the planted shoe slides back each video frame while she walks on the
## spot (walk and carry walk alike), video px: the walking speed the frames show.
const GROUND_SPEED_PER_VIDEO_FRAME := 13.0
const VIDEO_FPS := 24.0
## In the first pickup frame Lemon sits on the floor beside Stella, around this
## x (video px); her left edge is the empty column between them.
const LEMON_X := 880
## Lemon is off the floor once her lowest pixel is this far above it (video px).
const LIFTED := 8

## Per animation: video frames (0-based) from..to (exclusive) every `step`, or an
## explicit `frames` list; fps; loop.
const ANIMATIONS := [
	# Standing, facing front, still (from frame 20 her legs start to move).
	{"name": "idle", "from": 0, "to": 20, "step": 2, "fps": 12.0, "loop": true},
	# Two steps on the spot, three-quarter view facing right.
	{"name": "walk", "from": 162, "to": 194, "step": 2, "fps": 12.0, "loop": true},
	# Standing beside Lemon, kneeling, lifting her, standing up with her in her
	# arms (she steps as she rises; her feet are still from frame 364).
	{"name": "pickup_lemon", "from": 264, "to": 366, "step": 2, "fps": 16.0, "loop": false},
	# Holding Lemon, still: the frames before she sets off, there and back.
	{"name": "carry_idle", "frames": [364, 366, 368, 370, 368, 366], "fps": 12.0, "loop": true},
	{"name": "carry_walk", "from": 415, "to": 443, "step": 2, "fps": 12.0, "loop": true},
]
const ANIMATION_SUFFIX := "_right"
const BODY_ALPHA := 128

var _report: PackedStringArray = []


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var frames_dir: String = args[0] if args.size() > 0 else ProjectSettings.globalize_path(DEFAULT_FRAMES_DIR)
	var qa_dir: String = args[1] if args.size() > 1 else ProjectSettings.globalize_path("user://stella_animation_qa")
	DirAccess.make_dir_recursive_absolute(qa_dir)
	var video := ProjectSettings.globalize_path("res://" + VIDEO)
	if not FileAccess.file_exists(video):
		push_error("Missing video: " + video)
		quit(1)
		return

	var canvas := Vector2i(roundi(SOURCE_RECT.size.x * SCALE), roundi(SOURCE_RECT.size.y * SCALE))
	var floor_margin := (SOURCE_RECT.end.y - STELLA_FEET.y) * SCALE
	_report.append("canvas %dx%d, scale %.4f, feet at bottom centre less %.2f px (Visual art_offset.y)" % [
		canvas.x, canvas.y, SCALE, floor_margin])
	var resource_animations := []
	for animation: Dictionary in ANIMATIONS:
		var video_frames := _video_frames(animation)
		var folder := OUT_DIR.path_join(animation.name)
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
		_clear_frames(folder)
		var placed: Array[Image] = []
		var frames := []
		for index in video_frames.size():
			var image := _load_video_frame(frames_dir, video_frames[index])
			if image == null:
				quit(1)
				return
			var frame_image := _cut(image, canvas)
			placed.append(frame_image)
			var file := folder.path_join("frame_%04d.png" % (index + 1))
			frame_image.save_png(ProjectSettings.globalize_path(file))
			frames.append({"path": file, "duration": 1.0})
		resource_animations.append({"name": animation.name + ANIMATION_SUFFIX, "fps": animation.fps, "loop": animation.loop,
				"frames": frames, "folder": folder, "video_frames": video_frames})
		_report.append("%s: %d frames from video frames %d-%d, %.1f fps" % [
			animation.name, video_frames.size(), video_frames.min(), video_frames.max(), animation.fps])
		_save_contact_sheet(placed, qa_dir.path_join("%s_contact.png" % animation.name))
	_write_sprite_frames(resource_animations)

	var lemon := _extract_lemon(frames_dir, _video_frames(ANIMATIONS[2]))
	if lemon.is_empty():
		quit(1)
		return
	var ground_speed := GROUND_SPEED_PER_VIDEO_FRAME * VIDEO_FPS * SCALE
	_report.append("walk ground speed %.1f px/s (CharacterArt.walk_ground_speed)" % ground_speed)
	_write_manifest(resource_animations, video, canvas, floor_margin, ground_speed, lemon)
	var report := FileAccess.open(qa_dir.path_join("report.txt"), FileAccess.WRITE)
	report.store_string("\n".join(_report) + "\n")
	print("\n".join(_report))
	print("QA files in " + qa_dir)
	quit()


func _video_frames(animation: Dictionary) -> Array:
	if animation.has("frames"):
		return animation.frames
	return range(animation.from, animation.to, animation.get("step", 2))


func _load_video_frame(frames_dir: String, video_frame: int) -> Image:
	var path := frames_dir.path_join("frame_%04d.png" % (video_frame + 1))
	var image := Image.load_from_file(path)
	if image == null:
		push_error("Missing video frame %s: run tools/extract_stella_video.sh first" % path)
		return null
	image.convert(Image.FORMAT_RGBA8)
	return image


## The shared crop, scaled. Transparent pixels take their neighbours' colour first,
## so scaling doesn't darken the soft edges.
func _cut(image: Image, canvas: Vector2i) -> Image:
	var cut := image.get_region(SOURCE_RECT)
	cut.fix_alpha_edges()
	cut.resize(canvas.x, canvas.y, Image.INTERPOLATE_LANCZOS)
	return cut


## Lemon's floor sprite: what's right of the gap between her and Stella in the
## first pickup frame, cropped, with its origin at the bottom centre (floor contact). Also where she
## sits relative to Stella's feet, and the pickup frame where she leaves the floor.
func _extract_lemon(frames_dir: String, pickup_frames: Array) -> Dictionary:
	var first := _load_video_frame(frames_dir, pickup_frames[0])
	if first == null:
		return {}
	var left := _empty_column_left_of(first, LEMON_X)
	if left < 0:
		push_error("No gap between Stella and Lemon left of x %d in the first pickup frame" % LEMON_X)
		return {}
	var region := Rect2i(left, SOURCE_RECT.position.y, SOURCE_RECT.end.x - left, SOURCE_RECT.size.y)
	var bounds := _opaque_bounds(first.get_region(region), 8)
	if bounds.size == Vector2i.ZERO:
		push_error("No Lemon right of x %d in the first pickup frame" % left)
		return {}
	var floor_y := region.position.y + bounds.end.y # Just below her lowest pixel.
	var lemon := first.get_region(Rect2i(region.position + bounds.position, bounds.size))
	lemon.fix_alpha_edges()
	lemon.resize(maxi(1, roundi(bounds.size.x * SCALE)), maxi(1, roundi(bounds.size.y * SCALE)), Image.INTERPOLATE_LANCZOS)
	lemon.save_png(ProjectSettings.globalize_path(LEMON_SPRITE))
	var origin := Vector2(region.position.x + bounds.position.x + bounds.size.x * 0.5, floor_y)
	var offset := (origin - STELLA_FEET) * SCALE

	# The first frame from which she stays off the floor (she hops up once before).
	var lift_frame := -1
	for index in pickup_frames.size():
		var image := _load_video_frame(frames_dir, pickup_frames[index])
		var lowest := _opaque_bounds(image.get_region(region))
		var lifted := lowest.size == Vector2i.ZERO or region.position.y + lowest.end.y < floor_y - LIFTED
		if not lifted:
			lift_frame = -1
		elif lift_frame < 0:
			lift_frame = index
	_report.append("lemon sprite %dx%d; pickup offset from Stella's feet (%.1f, %.1f); leaves the floor in pickup frame %d (0-based)" % [
		lemon.get_width(), lemon.get_height(), offset.x, offset.y, lift_frame])
	return {"runtime": LEMON_SPRITE, "source": VIDEO,
			"cut_from": "pickup frame 1 (Lemon sitting beside Stella), video frame %d" % (pickup_frames[0] + 1),
			"pickup_offset": [snappedf(offset.x, 0.1), snappedf(offset.y, 0.1)], "lift_frame": lift_frame}


## The nearest column left of x (within SOURCE_RECT) with nothing in it.
func _empty_column_left_of(image: Image, x: int) -> int:
	var data := image.get_data()
	var w := image.get_width()
	for column in range(x, SOURCE_RECT.position.x, -1):
		var empty := true
		for y in range(SOURCE_RECT.position.y, SOURCE_RECT.end.y):
			if data[(y * w + column) * 4 + 3] > 0:
				empty = false
				break
		if empty:
			return column
	return -1


func _opaque_bounds(image: Image, alpha_min: int = BODY_ALPHA) -> Rect2i:
	var data := image.get_data()
	var w := image.get_width()
	var h := image.get_height()
	var x0 := w
	var y0 := h
	var x1 := -1
	var y1 := -1
	for y in h:
		for x in w:
			if data[(y * w + x) * 4 + 3] >= alpha_min:
				x0 = mini(x0, x)
				x1 = maxi(x1, x)
				y0 = mini(y0, y)
				y1 = maxi(y1, y)
	if x1 < 0:
		return Rect2i()
	return Rect2i(x0, y0, x1 - x0 + 1, y1 - y0 + 1)


func _clear_frames(folder: String) -> void:
	var dir := DirAccess.open(folder)
	if dir == null:
		return
	# Only stale frame images; their .import files are kept (Godot reuses them).
	for file in dir.get_files():
		if file.begins_with("frame_") and file.get_extension() == "png":
			dir.remove(file)


func _write_manifest(animations: Array, video: String, canvas: Vector2i, floor_margin: float, ground_speed: float,
		lemon: Dictionary) -> void:
	var entries := []
	for animation: Dictionary in animations:
		var frames := []
		for frame: Dictionary in animation.frames:
			frames.append(frame.path.get_file())
		entries.append({
			"animation": animation.name,
			"folder": animation.folder,
			"source": VIDEO,
			"source_sha256": FileAccess.get_sha256(video),
			"source_frames": animation.video_frames.map(func(n: int) -> int: return n + 1),
			"frames": frames,
			"fps": animation.fps,
			"loop": animation.loop,
		})
	var manifest := {
		"generated_by": "tools/extract_stella_video.sh, then tools/process_stella_animations.gd",
		"design": "Stella as in the animation video (" + VIDEO + ")",
		"canvas": [canvas.x, canvas.y],
		"feet_anchor": "bottom centre, %.2f px up (Visual art_offset.y)" % floor_margin,
		"scale_from_video": snappedf(SCALE, 0.0001),
		"source_rect": [SOURCE_RECT.position.x, SOURCE_RECT.position.y, SOURCE_RECT.size.x, SOURCE_RECT.size.y],
		"walk_ground_speed": snappedf(ground_speed, 0.1),
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
	var floor_y := size.y - 1 - roundi((SOURCE_RECT.end.y - STELLA_FEET.y) * SCALE)
	for i in frames.size():
		sheet.blend_rect(frames[i], Rect2i(Vector2i.ZERO, size), Vector2i(i * size.x, 0))
		for y in size.y:
			sheet.set_pixel(i * size.x + size.x / 2, y, Color(0, 1, 1, 0.6)) # anchor x
		for x in size.x:
			sheet.set_pixel(i * size.x + x, floor_y, Color(1, 0, 1)) # floor line
			sheet.set_pixel(i * size.x + x, floor_y - int(TARGET_HEIGHT), Color(1, 1, 0, 0.6)) # target height
	sheet.save_png(path)
