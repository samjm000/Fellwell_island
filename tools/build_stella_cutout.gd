extends SceneTree
## PROTOTYPE. Cuts one of Stella's processed walk frames into a layered 2D cutout
## rig: the body (head, torso, arms, shorts) and, for each leg, a thigh, a shin and
## a shoe, with the joint positions the rig pivots them around.
##
##     tools/godot.sh --headless --path . --script tools/build_stella_cutout.gd [-- QA_DIR]
##
## Source: walk frame 3 (both legs fully visible and apart below the shorts, both
## nearly straight; the back foot is in toe-off, the front in heel contact). The
## frame is already on Stella's shared canvas (feet at the bottom centre), so the
## rig is the same size and stands at the same origin as the production art.
##
## Every pixel comes from the frame except one, documented, addition: each thigh
## is continued up past the hip joint along its own direction (repeating its top
## cross-section, so shading and outline carry on), ending in a round cap at the
## hip, and its top THIGH_TOP_EDGE px (the shorts' shadow) are replaced the same way. The thigh in the frame slants, so its top was cut flat along the hem; once
## extended like this it stays tucked under the shorts at any swing angle.
##
## Outputs art/prototypes/stella_cutout/<part>.png, rig.json (part placement,
## joints and lengths in canvas pixels) and, in QA_DIR (default
## user://stella_cutout_qa), a guide image of the masks and joints.

const SOURCE := "res://art/characters/stella/animations/walk/frame_0003.png"
const OUT_DIR := "res://art/prototypes/stella_cutout"

## Height (canvas px) of the hip joints, inside the shorts.
const HIP_Y := 276.0
## The thigh's top few px carry the shorts' shadow line; the extension replaces them.
const THIGH_TOP_EDGE := 5
## Knee position along hip -> ankle.
const KNEE_T := 0.5
## Below this, in columns without denim, pixels may belong to a leg (the back
## hand reaches y = 282 beside the shorts).
const LEG_MIN_Y := 286
## Ball of the foot: this fraction of the sole back from the toe tip.
const BALL_FROM_TOE := 0.24
## Each shoe's sole (heel, toe tip) on the canvas, measured by eye on the cutout
## guide at 6x: the soles are rockered and the toe caps rounded, so no outline
## rule found them reliably. Re-measure if SOURCE changes.
const SOLES := {
	"back": [Vector2(95, 382), Vector2(156, 409)],
	"front": [Vector2(250, 408), Vector2(312, 377)],
}

var _image: Image
var _size: Vector2i


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var qa_dir: String = args[0] if args.size() > 0 else "user://stella_cutout_qa"
	_image = Image.load_from_file(ProjectSettings.globalize_path(SOURCE))
	_image.convert(Image.FORMAT_RGBA8)
	_size = _image.get_size()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(qa_dir))

	var labels := _label_legs()
	var rig := {
		"source": SOURCE,
		"source_sha256": FileAccess.get_sha256(SOURCE),
		"canvas_size": [_size.x, _size.y],
		"origin": [_size.x / 2.0, float(_size.y)],
		"parts": {},
		"legs": {},
	}
	var body_mask := PackedByteArray()
	body_mask.resize(_size.x * _size.y)
	for i in body_mask.size():
		body_mask[i] = 1 if _alpha(i) > 0.0 and labels[i] == 0 else 0

	var guide := _image.duplicate() as Image
	for leg in [1, 2]:
		var leg_name := "back" if leg == 1 else "front"
		var leg_rig := _cut_leg(labels, leg, leg_name, rig, guide)
		rig.legs[leg_name] = leg_rig

	rig.parts["body"] = _save_part("body", body_mask, {}, Vector2(_size.x / 2.0, HIP_Y))
	_draw_guide_points(guide, rig)
	guide.save_png(ProjectSettings.globalize_path(qa_dir).path_join("cutout_guide.png"))

	var file := FileAccess.open(OUT_DIR.path_join("rig.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(rig, "\t", true))
	file.close()
	print("Cutout written to %s; guide in %s" % [OUT_DIR, qa_dir])
	quit()


# --- Legs ------------------------------------------------------------------------

## 0 = body, 1 = back leg, 2 = front leg. Leg pixels are those below the shorts,
## reached from each foot; where the thighs meet, each pixel goes to the nearer
## foot (by path), which splits them along the crotch.
func _label_legs() -> PackedInt32Array:
	var shorts_bottom := PackedInt32Array()
	shorts_bottom.resize(_size.x)
	for x in _size.x:
		shorts_bottom[x] = -1
		for y in range(230, 320):
			if _is_bluish(_image.get_pixel(x, y)):
				shorts_bottom[x] = y
	var candidate := PackedByteArray()
	candidate.resize(_size.x * _size.y)
	for y in _size.y:
		for x in _size.x:
			var below := y > shorts_bottom[x] if shorts_bottom[x] >= 0 else y >= LEG_MIN_Y
			var pixel := _image.get_pixel(x, y)
			candidate[y * _size.x + x] = 1 if below and y >= 270 and pixel.a > 0.0 and not _is_bluish(pixel) else 0

	var labels := PackedInt32Array()
	labels.resize(_size.x * _size.y)
	var queue: Array[int] = []
	for leg in [1, 2]:
		var seed := _lowest_candidate(candidate, leg == 1)
		labels[seed] = leg
		queue.append(seed)
	var head := 0
	while head < queue.size():
		var index: int = queue[head]
		head += 1
		var x := index % _size.x
		var y := index / _size.x
		for offset: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
				Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1)]:
			var nx := x + offset.x
			var ny := y + offset.y
			if nx < 0 or ny < 0 or nx >= _size.x or ny >= _size.y:
				continue
			var n := ny * _size.x + nx
			if candidate[n] == 1 and labels[n] == 0:
				labels[n] = labels[index]
				queue.append(n)
	return labels


func _lowest_candidate(candidate: PackedByteArray, left: bool) -> int:
	for y in range(_size.y - 1, 0, -1):
		var xs := range(0, _size.x / 2) if left else range(_size.x / 2, _size.x)
		for x: int in xs:
			if candidate[y * _size.x + x] == 1 and _image.get_pixel(x, y).a > 0.5:
				return y * _size.x + x
	return 0


func _cut_leg(labels: PackedInt32Array, leg: int, leg_name: String, rig: Dictionary, guide: Image) -> Dictionary:
	# The shoe: in each column, everything from the first pink pixel down.
	var foot := PackedByteArray()
	foot.resize(labels.size())
	var pink_top := _size.y
	for x in _size.x:
		var in_shoe := false
		for y in range(LEG_MIN_Y, _size.y):
			var i := y * _size.x + x
			if labels[i] != leg:
				continue
			if _is_pink(_image.get_pixel(x, y)):
				in_shoe = true
				pink_top = mini(pink_top, y)
			if in_shoe:
				foot[i] = 1
	# Leg axis from the row centres between the shorts and the shoe.
	var top := _size.y
	for i in labels.size():
		if labels[i] == leg:
			top = mini(top, i / _size.x)
	var ys: Array[float] = []
	var xs: Array[float] = []
	for y in range(top + 12, pink_top - 4):
		var sum := 0.0
		var count := 0
		for x in _size.x:
			var i := y * _size.x + x
			if labels[i] == leg and foot[i] == 0 and _alpha(i) > 0.5:
				sum += x
				count += 1
		if count > 0:
			ys.append(y)
			xs.append(sum / count)
	var fit := _fit_line(ys, xs) # x = a*y + b
	var axis_x := func(y: float) -> float: return fit.x * y + fit.y
	var ankle_y := float(pink_top) + 10.0
	var hip := Vector2(axis_x.call(HIP_Y), HIP_Y)
	var ankle := Vector2(axis_x.call(ankle_y), ankle_y)
	var knee := hip.lerp(ankle, KNEE_T)
	var axis := (ankle - hip).normalized()
	var knee_t := (knee - hip).dot(axis)
	# Toe caps and soles past the last pink column: everything beyond the ankle,
	# across the shin.
	var ankle_t := (ankle - hip).dot(axis)
	for i in labels.size():
		if labels[i] == leg and (Vector2(i % _size.x, i / _size.x) - hip).dot(axis) > ankle_t + 4.0:
			foot[i] = 1
	# Row widths of a slanted leg overstate its width; measure across the leg.
	var knee_radius := _width_at(labels, leg, foot, knee) * axis.y * 0.5

	var thigh := PackedByteArray()
	var shin := PackedByteArray()
	thigh.resize(labels.size())
	shin.resize(labels.size())
	for i in labels.size():
		if labels[i] != leg or foot[i] == 1:
			continue
		var p := Vector2(i % _size.x, i / _size.x)
		var t := (p - hip).dot(axis)
		if t < knee_t or p.distance_to(knee) <= knee_radius:
			thigh[i] = 1
		# Both parts end in the same disc around the knee, which looks the same
		# at any angle, so neither shows a cut corner when the knee bends.
		if t >= knee_t or p.distance_to(knee) <= knee_radius:
			shin[i] = 1
	var extension := _extend_thigh(thigh, hip, axis)

	var heel: Vector2 = SOLES[leg_name][0]
	var toe: Vector2 = SOLES[leg_name][1]
	var ball := toe.lerp(heel, BALL_FROM_TOE)

	_tint(guide, labels, leg, foot, thigh, shin)
	rig.parts[leg_name + "_thigh"] = _save_part(leg_name + "_thigh", thigh, extension, hip)
	rig.parts[leg_name + "_shin"] = _save_part(leg_name + "_shin", shin, {}, knee)
	rig.parts[leg_name + "_foot"] = _save_part(leg_name + "_foot", foot, {}, ankle)
	return {
		"hip": [hip.x, hip.y], "knee": [knee.x, knee.y], "ankle": [ankle.x, ankle.y],
		"heel": [heel.x, heel.y], "ball": [ball.x, ball.y], "toe": [toe.x, toe.y],
		"thigh_length": hip.distance_to(knee), "shin_length": knee.distance_to(ankle),
		"thigh_extension_px": extension.size(),
	}


## Continues the thigh along `axis` from its top edge up past the hip (see the
## header). Each line along the axis repeats the colour just inside the thigh's
## top; past the hip it ends in a half disc of the thigh's width. Returns {index: Color} of added pixels.
func _extend_thigh(thigh: PackedByteArray, hip: Vector2, axis: Vector2) -> Dictionary:
	var across := Vector2(-axis.y, axis.x)
	# For each line along the axis (offset s across it): where the thigh starts,
	# and the colour just inside.
	var starts := {}
	for s in range(-40, 41):
		for t in range(0, 80):
			var p := (hip + axis * t + across * s).round()
			var i := int(p.y) * _size.x + int(p.x)
			if thigh[i] == 1 and _alpha(i) > 0.9:
				var inside := (hip + axis * (t + THIGH_TOP_EDGE + 2) + across * s).round()
				starts[s] = {"t": float(t + THIGH_TOP_EDGE), "colour": _image.get_pixelv(Vector2i(inside))}
				break
	# Only lines through the thigh's full width (not ones grazing its edge).
	var lines := starts.keys()
	lines.sort()
	var half: float = (lines[-1] - lines[0]) * 0.5
	var top_end := 0.0
	for line: int in starts:
		top_end = maxf(top_end, starts[line].t)
	var added := {}
	var reach := int(half + 80)
	for y in range(int(hip.y) - reach, int(hip.y) + reach):
		for x in range(int(hip.x) - reach, int(hip.x) + reach):
			if x < 0 or y < 0 or x >= _size.x or y >= _size.y:
				continue
			var i := y * _size.x + x
			var d := Vector2(x, y) - hip
			var t := d.dot(axis)
			var s := roundi(d.dot(across))
			if not starts.has(s):
				if thigh[i] == 1 and t < top_end:
					added[i] = Color(0, 0, 0, 0) # Scraps of the old top edge beside the tube.
				continue
			if t >= starts[s].t:
				continue
			if t < 0.0 and d.length() > half:
				continue # Round end about the hip.
			added[i] = starts[s].colour
	return added


func _width_at(labels: PackedInt32Array, leg: int, foot: PackedByteArray, at: Vector2) -> float:
	var y := int(at.y)
	var count := 0
	for x in _size.x:
		var i := y * _size.x + x
		if labels[i] == leg and foot[i] == 0 and _alpha(i) > 0.5:
			count += 1
	return float(count)


# --- Output ----------------------------------------------------------------------

## Saves the masked pixels (plus `added`) cropped to their bounds. Placement:
## the part's top-left on the canvas, and the pivot it rotates about.
func _save_part(part: String, mask: PackedByteArray, added: Dictionary, pivot: Vector2) -> Dictionary:
	var rect := Rect2i()
	var first := true
	for i in mask.size():
		if mask[i] == 1 or added.has(i):
			var p := Vector2i(i % _size.x, i / _size.x)
			rect = Rect2i(p, Vector2i.ONE) if first else rect.expand(p).expand(p + Vector2i.ONE)
			first = false
	var out := Image.create(rect.size.x, rect.size.y, false, Image.FORMAT_RGBA8)
	for y in rect.size.y:
		for x in rect.size.x:
			var i := (rect.position.y + y) * _size.x + rect.position.x + x
			if added.has(i):
				out.set_pixel(x, y, added[i])
			elif mask[i] == 1:
				out.set_pixel(x, y, _image.get_pixel(rect.position.x + x, rect.position.y + y))
	out.save_png(ProjectSettings.globalize_path(OUT_DIR.path_join(part + ".png")))
	return {"file": part + ".png", "position": [rect.position.x, rect.position.y], "pivot": [pivot.x, pivot.y]}


func _tint(guide: Image, labels: PackedInt32Array, leg: int, foot: PackedByteArray, thigh: PackedByteArray, shin: PackedByteArray) -> void:
	for i in labels.size():
		if labels[i] != leg:
			continue
		var p := Vector2i(i % _size.x, i / _size.x)
		var tint := Color(0.2, 0.5, 1.0) if foot[i] == 1 else (Color(1.0, 0.6, 0.1) if thigh[i] == 1 and shin[i] == 0 \
				else (Color(0.8, 0.2, 0.9) if thigh[i] == 1 else Color(0.2, 0.8, 0.3)))
		var c := guide.get_pixel(p.x, p.y)
		guide.set_pixel(p.x, p.y, c.lerp(Color(tint, c.a), 0.45))


func _draw_guide_points(guide: Image, rig: Dictionary) -> void:
	for leg_name: String in rig.legs:
		var leg: Dictionary = rig.legs[leg_name]
		for joint in ["hip", "knee", "ankle", "heel", "ball", "toe"]:
			var p := Vector2i(int(leg[joint][0]), int(leg[joint][1]))
			for dy in range(-3, 4):
				for dx in range(-3, 4):
					var q := p + Vector2i(dx, dy)
					if Rect2i(Vector2i.ZERO, _size).has_point(q):
						guide.set_pixel(q.x, q.y, Color.RED if joint in ["hip", "knee", "ankle"] else Color.BLACK)


# --- Helpers ---------------------------------------------------------------------

func _alpha(i: int) -> float:
	return _image.get_pixel(i % _size.x, i / _size.x).a


## Any blue at all: the shorts, including the pale cuff and its stitching.
static func _is_bluish(c: Color) -> bool:
	return c.a > 0.3 and c.h > 0.5 and c.h < 0.75 and c.s > 0.06


static func _is_pink(c: Color) -> bool:
	return c.a > 0.5 and (c.h > 0.93 or c.h < 0.03) and c.s > 0.4 and c.v > 0.4


static func _fit_line(ys: Array[float], xs: Array[float]) -> Vector2:
	var n := float(ys.size())
	var my := 0.0
	var mx := 0.0
	for k in ys.size():
		my += ys[k]
		mx += xs[k]
	my /= n
	mx /= n
	var num := 0.0
	var den := 0.0
	for k in ys.size():
		num += (ys[k] - my) * (xs[k] - mx)
		den += (ys[k] - my) * (ys[k] - my)
	var a := num / den
	return Vector2(a, mx - a * my)

