extends SceneTree
## PROTOTYPE. Cuts one of Stella's processed walk frames into a layered 2D cutout
## rig: the body (head, torso, shorts), each arm, and for each leg a thigh, a shin
## and a shoe, with the joint positions the rig pivots them around.
##
##     tools/godot.sh --headless --path . --script tools/build_stella_cutout.gd [-- QA_DIR]
##
## Source: walk frame 3 (both legs fully visible and apart below the shorts, both
## nearly straight; the back foot is in toe-off, the front in heel contact; both
## arms clear of the torso). The frame is already on Stella's shared canvas (feet
## at the bottom centre), so the rig is the same size and stands at the same
## origin as the production art.
##
## Every pixel comes from the frame except one, documented, addition: each thigh
## and arm is continued up past its hip or shoulder along its own direction
## (repeating its top cross-section, so shading and outline carry on), ending in a
## round cap at the joint. Limbs in the frame slant, so their tops were cut flat
## along the hem or sleeve; extended like this they stay tucked under the shorts
## or sleeve at any swing angle. The thighs' top THIGH_TOP_EDGE px (the shorts'
## shadow) are replaced the same way.
##
## The near sleeve is also saved on its own (pixels unchanged) so it can be drawn
## over the near arm.
##
## For carrying Lemon, the upper body of carry-idle frame 1 (everything above the
## shorts' hem) is saved as `carry_body`, pivoting at the same hip height relative
## to the hem as the walking body.
##
## Outputs art/prototypes/stella_cutout/<part>.png, rig.json (part placement,
## joints and lengths in canvas pixels) and, in QA_DIR (default
## user://stella_cutout_qa), a guide image of the masks and joints.

const SOURCE := "res://art/characters/stella/animations/walk/frame_0003.png"
## Carrying Lemon: the upper body (with Lemon and both arms holding her) comes from
## the first carry-idle frame, on the same legs, lined up at the shorts' hem.
const CARRY_SOURCE := "res://art/characters/stella/animations/carry_idle/frame_0001.png"
const OUT_DIR := "res://art/prototypes/stella_cutout"

## Height (canvas px) of the hip joints, inside the shorts.
const HIP_Y := 276.0
## The made-up limb tops are inside a sleeve or the shorts, so in their shadow:
## when they show (between the cuffs), they're darker than the limb.
const TUCKED_SHADE := 0.22
## The arms' top few px are the pale sleeve lining; the extension replaces them.
const ARM_TOP_EDGE := 6
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

## Arms: shoulder joint and the middle of the hand, measured on the frame at 3x.
## The far shoulder is set inside the torso, high and near the chest: that arm is
## raised ~60 deg in the frame, and swinging it (and its sleeve) down turns the
## sleeve's top forward by about its distance from the joint, so the joint sits
## close under it to keep it behind the chest. The arm swinging back overlaps the shirt, so it's the near
## arm; the one swinging forward is behind the torso. Re-measure if SOURCE changes.
## `hem`: two points along the bottom of the sleeve; the arm is what's below it.
## `torso`: two points along the painted line where arm and shirt meet; the arm
## is on the hand's side of it, and that one line belongs to both.
const ARMS := {
	"near": {"shoulder": Vector2(174, 196), "hand": Vector2(125, 265),
		"hem": [Vector2(151, 201), Vector2(186, 219)], "torso": [Vector2(179, 207), Vector2(157, 242)]},
	"far": {"shoulder": Vector2(224, 193), "hand": Vector2(292, 232),
		"hem": [Vector2(231, 219), Vector2(255, 202)], "torso": [Vector2(236, 203), Vector2(238, 242)]},
}
## Below this, skin in the body is the legs' (between the cuffs).
const CUFF_SKIN_Y := 284
## Between these columns (the crotch), anything there but denim is, too.
const CROTCH_X_RANGE := Vector2i(190, 206)
## Body islands smaller than this (px) are dropped.
const SPECK_PX := 40
## Half the width of the painted line along `torso`.
const SHARED_LINE := 1.5
## Arm pixels lie within ARM_RADIUS of the shoulder -> hand line (extended
## HAND_REACH past the hand).
const ARM_RADIUS := 32.0
const HAND_REACH := 14.0
## The torso's left and right edges (canvas x). Skin highlights look like the
## shirt's white stripes, so white only counts as shirt between these.
const TORSO_X := Vector2(158, 237)
## The near sleeve: shirt pixels this close to the near shoulder.
const SLEEVE_RADIUS := 32.0
## The far sleeve is cut off the chest down this column (above the arm/torso line)
## and found from this pixel inside it. Measured on the frame at 6x.
const FAR_SLEEVE_CUT_X := 232.5
const FAR_SLEEVE_SEED := Vector2(245, 205)
## Above this the hair hangs against the sleeve's top, and the sleeve's top
## corner would turn out past the chest as the arm comes down.
const FAR_SLEEVE_TOP_Y := 186.0
## Where the near sleeve joins the torso (its diagonal stripes meet the torso's
## level ones), top to bottom, and the top of the part that's cut out.
const NEAR_SLEEVE_SEAM := [Vector2(180, 172), Vector2(197, 210)]
const NEAR_SLEEVE_TOP_Y := 176.0
## Plain stripes on the chest, copied to fill the shoulder: from this column, this wide.
const CHEST_X := 206
const CHEST_SPAN := 14
## The shirt's back edge behind the near shoulder (hidden by the sleeve and arm in
## the frame): from the top of the shoulder, round its back, to where it shows
## again below the arm.
const NEAR_BACK_EDGE := [Vector2(178, 174), Vector2(163, 184), Vector2(159, 200), Vector2(158, 246)]

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

	rig["arms"] = {}
	var arm_masks := {}
	var arm_extensions := {}
	for side: String in ARMS:
		var arm := _arm_mask(side)
		_remove_arm_from_body(body_mask, arm, side)
		var shoulder: Vector2 = ARMS[side].shoulder
		var hand: Vector2 = ARMS[side].hand
		arm_masks[side] = arm
		arm_extensions[side] = _extend_limb(arm, shoulder, (hand - shoulder).normalized(), ARM_TOP_EDGE)
		rig.arms[side] = {"shoulder": [shoulder.x, shoulder.y], "hand": [hand.x, hand.y]}
		_tint_mask(guide, arm, Color(1.0, 0.9, 0.1))
	var seam: Array = NEAR_SLEEVE_SEAM
	rig.arms.near["seam"] = [[seam[0].x, seam[0].y], [seam[1].x, seam[1].y]]
	# Skin showing between the cuffs at the crotch belongs to the legs.
	for i in body_mask.size():
		var p := Vector2i(i % _size.x, i / _size.x)
		if body_mask[i] == 1 and p.y > CUFF_SKIN_Y and (_is_skin(_image.get_pixelv(p)) \
				or (p.x >= CROTCH_X_RANGE.x and p.x <= CROTCH_X_RANGE.y and not _is_bluish(_image.get_pixelv(p)))):
			body_mask[i] = 0
	_drop_specks(body_mask)
	var body_fill := {}
	# The far sleeve swings with its arm behind the torso, as one piece.
	var far_sleeve := _far_sleeve_mask(body_mask)
	_cut_from_body(body_mask, far_sleeve, body_fill)
	_outline_far_shoulder(body_mask, far_sleeve, body_fill)
	for i in far_sleeve.size():
		if far_sleeve[i] == 1:
			arm_masks.far[i] = 1
			arm_extensions.far.erase(i) # The sleeve covers the arm's made-up top.
	_outline_far_sleeve(far_sleeve, arm_extensions.far)
	_tint_mask(guide, far_sleeve, Color(0.2, 0.9, 0.9))
	for side: String in ARMS:
		rig.parts[side + "_arm"] = _save_part(side + "_arm", arm_masks[side], arm_extensions[side], ARMS[side].shoulder)
	# The near sleeve is its own mesh over the near arm; the shoulder it covered is
	# filled in with shirt, for when it swings away.
	var sleeve := _sleeve_mask(body_mask, ARMS.near.shoulder)
	_cut_from_body(body_mask, sleeve, body_fill)
	_fill_near_shoulder(body_mask, sleeve, body_fill)
	_tint_mask(guide, sleeve, Color(0.9, 0.2, 0.9))
	rig.parts["near_sleeve"] = _save_part("near_sleeve", sleeve, {}, Vector2(_size.x / 2.0, HIP_Y))
	rig.parts["body"] = _save_part("body", body_mask, body_fill, Vector2(_size.x / 2.0, HIP_Y))
	var walk_hem := _hem_y(_image)
	_cut_carry_body(rig, walk_hem)
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
	var extension := _extend_limb(thigh, hip, axis, THIGH_TOP_EDGE)

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


## Continues a limb along `axis` from its top edge up past `joint` (see the
## header), dropping its top `edge` px. Each line along the axis repeats the colour
## just inside the limb's top, as far as the middle of the top edge; past the joint
## it ends in a half disc of the limb's width. Returns {index: Color} of added (or, transparent, removed) pixels.
func _extend_limb(limb: PackedByteArray, joint: Vector2, axis: Vector2, edge: int) -> Dictionary:
	var across := Vector2(-axis.y, axis.x)
	# For each line along the axis (offset s across it): where the limb starts,
	# and the colour just inside.
	var starts := {}
	for s in range(-40, 41):
		for t in range(0, 80):
			var p := (joint + axis * t + across * s).round()
			if not Rect2(Vector2.ZERO, _size).has_point(p):
				continue
			var i := int(p.y) * _size.x + int(p.x)
			if limb[i] == 1 and _alpha(i) > 0.9:
				# The colour just inside, taken only from the limb's own pixels.
				for k in range(edge + 2, edge + 14):
					var inside := Vector2i((joint + axis * (t + k) + across * s).round())
					if Rect2i(Vector2i.ZERO, _size).has_point(inside) and limb[inside.y * _size.x + inside.x] == 1 \
							and _image.get_pixelv(inside).a > 0.9:
						starts[s] = {"t": float(t + edge), "colour": _image.get_pixelv(inside)}
						break
				break
	var lines := starts.keys()
	lines.sort()
	var half: float = (lines[-1] - lines[0]) * 0.5
	# Lines grazing a slanted edge (or passing over the limb to the hand) only meet
	# it far down; the tube goes no further than the middle half of the lines need,
	# and lines that meet the limb further down still aren't part of its top.
	var middle: float = (lines[0] + lines[-1]) * 0.5
	var tube_end := 0.0
	for line: int in starts:
		if absf(line - middle) <= half * 0.5:
			tube_end = maxf(tube_end, starts[line].t)
	tube_end += 3.0
	var passing := {}
	for line: int in starts.keys():
		if starts[line].t > tube_end + 6.0:
			starts.erase(line)
			passing[line] = true
	var top_end := 0.0
	for line: int in starts:
		top_end = maxf(top_end, starts[line].t)
	var added := {}
	var reach := int(half + 80)
	for y in range(int(joint.y) - reach, int(joint.y) + reach):
		for x in range(int(joint.x) - reach, int(joint.x) + reach):
			if x < 0 or y < 0 or x >= _size.x or y >= _size.y:
				continue
			var i := y * _size.x + x
			var d := Vector2(x, y) - joint
			var t := d.dot(axis)
			var s := roundi(d.dot(across))
			if not starts.has(s):
				if limb[i] == 1 and t < top_end and not passing.has(s):
					added[i] = Color(0, 0, 0, 0) # Scraps of the old top edge beside the tube.
				continue
			if t >= minf(starts[s].t, tube_end):
				continue
			if t < 0.0 and d.length() > half:
				continue # Round end about the joint.
			# Shaded only where it's new (not the top edge px it repaints).
			var tucked: bool = t < starts[s].t - edge
			added[i] = starts[s].colour.darkened(TUCKED_SHADE) if tucked else starts[s].colour
	return added


# --- Carrying ---------------------------------------------------------------------

## Typical height of the bottom of the shorts (median over the columns they span).
static func _hem_y(image: Image) -> float:
	var bottoms: Array[int] = []
	for x in image.get_width():
		var bottom := -1
		for y in range(200, 330):
			if _is_bluish(image.get_pixel(x, y)):
				bottom = y
		if bottom >= 0:
			bottoms.append(bottom)
	bottoms.sort()
	return float(bottoms[bottoms.size() / 2])


func _cut_carry_body(rig: Dictionary, walk_hem: float) -> void:
	var image := Image.load_from_file(ProjectSettings.globalize_path(CARRY_SOURCE))
	image.convert(Image.FORMAT_RGBA8)
	var hem := _hem_y(image)
	var mask := PackedByteArray()
	mask.resize(_size.x * _size.y)
	for x in _size.x:
		var shorts_bottom := -1
		for y in range(200, 330):
			if _is_bluish(image.get_pixel(x, y)):
				shorts_bottom = y
		var limit := shorts_bottom if shorts_bottom >= 0 else int(hem) - 4
		for y in range(0, limit + 1):
			if image.get_pixel(x, y).a > 0.0:
				mask[y * _size.x + x] = 1
	# Same pixels source as the walk parts, so save from the carry image.
	var walk_image := _image
	_image = image
	rig.parts["carry_body"] = _save_part("carry_body", mask, {}, Vector2(_size.x / 2.0, HIP_Y + hem - walk_hem))
	_image = walk_image
	rig["carry_source"] = CARRY_SOURCE
	rig["carry_source_sha256"] = FileAccess.get_sha256(CARRY_SOURCE)


# --- Arms ------------------------------------------------------------------------

## The arm below the sleeve: skin and outline pixels near the shoulder -> hand
## line, reached from the hand without crossing the shirt or shorts.
func _arm_mask(side: String) -> PackedByteArray:
	var shoulder: Vector2 = ARMS[side].shoulder
	var hand: Vector2 = ARMS[side].hand
	var mask := PackedByteArray()
	mask.resize(_size.x * _size.y)
	var start := int(hand.y) * _size.x + int(hand.x)
	mask[start] = 1
	var queue: Array[int] = [start]
	var head := 0
	while head < queue.size():
		var index: int = queue[head]
		head += 1
		for offset: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var q := Vector2i(index % _size.x, index / _size.x) + offset
			if not Rect2i(Vector2i.ZERO, _size).has_point(q):
				continue
			var n := q.y * _size.x + q.x
			if mask[n] == 1:
				continue
			var c := _image.get_pixelv(q)
			if c.a <= 0.0 or _is_shirt_at(q) or _is_bluish(c):
				continue
			if not _below_hem(Vector2(q), side) or _distance_to_arm_line(Vector2(q), side) > ARM_RADIUS \
					or _from_torso_line(Vector2(q), side) < -SHARED_LINE:
				continue
			mask[n] = 1
			queue.append(n)
	return mask


## Takes the arm out of the body, plus loose bits of its outline next to it, but
## leaves the line it shares with the shirt.
func _remove_arm_from_body(body_mask: PackedByteArray, arm: PackedByteArray, side: String) -> void:
	for i in arm.size():
		var p := Vector2i(i % _size.x, i / _size.x)
		var from_torso := _from_torso_line(Vector2(p), side)
		if body_mask[i] == 0 or from_torso <= SHARED_LINE:
			continue
		var near_arm := arm[i] == 1
		if not near_arm and _below_hem(Vector2(p), side) and not _is_shirt_at(p):
			for offset: Vector2i in [Vector2i(2, 0), Vector2i(-2, 0), Vector2i(0, 2), Vector2i(0, -2), Vector2i(1, 1), Vector2i(-1, -1)]:
				var q := p + offset
				if Rect2i(Vector2i.ZERO, _size).has_point(q) and arm[q.y * _size.x + q.x] == 1:
					near_arm = true
					break
		if near_arm:
			body_mask[i] = 0


## Removes islands of body pixels smaller than SPECK_PX (outline scraps the arm
## cut leaves behind).
func _drop_specks(mask: PackedByteArray) -> void:
	var seen := PackedByteArray()
	seen.resize(mask.size())
	for start in mask.size():
		if mask[start] == 0 or seen[start] == 1:
			continue
		var island: Array[int] = [start]
		seen[start] = 1
		var head := 0
		while head < island.size():
			var index: int = island[head]
			head += 1
			for offset: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
					Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1)]:
				var q := Vector2i(index % _size.x, index / _size.x) + offset
				if not Rect2i(Vector2i.ZERO, _size).has_point(q):
					continue
				var n := q.y * _size.x + q.x
				if mask[n] == 1 and seen[n] == 0:
					seen[n] = 1
					island.append(n)
		if island.size() < SPECK_PX:
			for index in island:
				mask[index] = 0


## Signed distance from the arm/torso line: positive on the hand's side.
func _from_torso_line(p: Vector2, side: String) -> float:
	var line: Array = ARMS[side].torso
	var along: Vector2 = (line[1] - line[0]).normalized()
	var hand_side := signf(along.cross(ARMS[side].hand - line[0]))
	return along.cross(p - line[0]) * hand_side


## The near sleeve, unchanged pixels: body pixels on the arm's side of its seam
## (NEAR_SLEEVE_SEAM) above the hem, and the lining showing inside it (what's left
## between the hem and the arm).
func _sleeve_mask(body_mask: PackedByteArray, shoulder: Vector2) -> PackedByteArray:
	var mask := PackedByteArray()
	mask.resize(body_mask.size())
	var seam: Vector2 = NEAR_SLEEVE_SEAM[1] - NEAR_SLEEVE_SEAM[0]
	var arm_side := signf(seam.cross(ARMS.near.hand - NEAR_SLEEVE_SEAM[0]))
	for i in body_mask.size():
		var p := Vector2(i % _size.x, i / _size.x)
		if body_mask[i] == 0 or p.distance_to(shoulder) > SLEEVE_RADIUS or p.y < NEAR_SLEEVE_TOP_Y \
				or signf(seam.cross(p - NEAR_SLEEVE_SEAM[0])) != arm_side:
			continue
		var lining := _from_torso_line(p, "near") > SHARED_LINE and not _is_shirt_at(Vector2i(p))
		# Hair hanging over the shoulder stays with the hair (it moves on its own).
		if (not _below_hem(p, "near") or lining) and not _is_hair(_image.get_pixelv(Vector2i(p))):
			mask[i] = 1
	return mask


## The far sleeve: body pixels in front of the chest (FAR_SLEEVE_CUT_X at the
## shoulder, then the arm/torso line), reached from inside the sleeve.
func _far_sleeve_mask(body_mask: PackedByteArray) -> PackedByteArray:
	var shoulder: Vector2 = ARMS.far.shoulder
	var mask := PackedByteArray()
	mask.resize(body_mask.size())
	var start := int(FAR_SLEEVE_SEED.y) * _size.x + int(FAR_SLEEVE_SEED.x)
	mask[start] = 1
	var queue: Array[int] = [start]
	var head := 0
	while head < queue.size():
		var index: int = queue[head]
		head += 1
		for offset: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var q := Vector2i(index % _size.x, index / _size.x) + offset
			if not Rect2i(Vector2i.ZERO, _size).has_point(q):
				continue
			var n := q.y * _size.x + q.x
			var p := Vector2(q)
			var in_front := p.x > FAR_SLEEVE_CUT_X if not _below_hem(p, "far") else _from_torso_line(p, "far") > SHARED_LINE
			if mask[n] == 1 or body_mask[n] == 0 or not in_front or p.distance_to(shoulder) > 55.0 \
					or p.y < FAR_SLEEVE_TOP_Y:
				continue
			mask[n] = 1
			queue.append(n)
	# Skin left over below the hem, cut off from the rest by the shared line.
	for i in mask.size():
		var p := Vector2(i % _size.x, i / _size.x)
		if body_mask[i] == 1 and _below_hem(p, "far") and p.x > FAR_SLEEVE_CUT_X \
				and p.distance_to(shoulder) <= 55.0 and _is_skin(_image.get_pixelv(Vector2i(p))):
			mask[i] = 1
	return mask


func _cut_from_body(body_mask: PackedByteArray, cut: PackedByteArray, fill: Dictionary) -> void:
	for i in cut.size():
		if cut[i] == 1:
			body_mask[i] = 0
			fill.erase(i)


## With the far sleeve gone, the chest needs an edge where it was: the outline
## colour of the chest below, along the cut.
func _outline_far_shoulder(body_mask: PackedByteArray, sleeve: PackedByteArray, fill: Dictionary) -> void:
	var torso: Array = ARMS.far.torso
	var outline := _darkest_in_row(int(torso[0].y + torso[1].y) / 2, int(torso[0].x) - 4, int(torso[1].x) + 2)
	for i in sleeve.size():
		if sleeve[i] == 0:
			continue
		var p := Vector2i(i % _size.x, i / _size.x)
		if _below_hem(Vector2(p), "far"):
			continue
		for dx in [1, 2]:
			var q := p - Vector2i(dx, 0)
			var n := q.y * _size.x + q.x
			if body_mask[n] == 1 and _is_shirt_at(q):
				fill[n] = outline if dx == 1 else _image.get_pixelv(q).lerp(outline, 0.5)


## The sleeve's cut edge shows in front of the chest when the arm hangs down, so
## it gets an outline too.
func _outline_far_sleeve(sleeve: PackedByteArray, added: Dictionary) -> void:
	var torso: Array = ARMS.far.torso
	var outline := _darkest_in_row(int(torso[0].y + torso[1].y) / 2, int(torso[0].x) - 4, int(torso[1].x) + 2)
	for i in sleeve.size():
		var p := Vector2i(i % _size.x, i / _size.x)
		if sleeve[i] == 0 or _below_hem(Vector2(p), "far") or sleeve[i - 1] == 1:
			continue
		added[i] = outline
		if sleeve[i + 1] == 1:
			added[i + 1] = _image.get_pixelv(p + Vector2i(1, 0)).lerp(outline, 0.5)


## Fills the shoulder under the near sleeve with shirt: each row, between the
## shirt's back edge and the shirt still there, repeats that row of the chest
## (where the stripes run level), with the back outline along the edge.
func _fill_near_shoulder(body_mask: PackedByteArray, sleeve: PackedByteArray, fill: Dictionary) -> void:
	var last: Vector2 = NEAR_BACK_EDGE[-1]
	var outline := _darkest_in_row(int(last.y), int(last.x) - 2, int(last.x) + 6)
	var top := int(NEAR_BACK_EDGE[0].y)
	for y in range(top, int(last.y)):
		var back := roundi(_polyline_x(NEAR_BACK_EDGE, y))
		# The first stripe to the right of the gap (past all of the sleeve).
		var x_shirt := back
		for x in range(back, _size.x):
			if sleeve[y * _size.x + x] == 1:
				x_shirt = x + 1
		while x_shirt < _size.x and not (body_mask[y * _size.x + x_shirt] == 1 and not fill.has(y * _size.x + x_shirt) \
				and _is_stripe_at(Vector2i(x_shirt, y))):
			x_shirt += 1
		if x_shirt >= int(NEAR_SLEEVE_SEAM[1].x) + 20:
			continue
		for x in range(back, x_shirt):
			var i := y * _size.x + x
			if body_mask[i] == 1 and _is_stripe_at(Vector2i(x, y)) and x - back > 1:
				continue
			var source := Vector2i(CHEST_X + (x - back) % CHEST_SPAN, y)
			if not _is_stripe_at(source):
				source = Vector2i(x_shirt, y)
			var colour := _image.get_pixelv(source)
			if x - back < 2:
				colour = outline if x == back else colour.lerp(outline, 0.5)
			fill[i] = colour
		# Leftovers outside the edge (the arm's outline) go.
		for x in range(back - 4, back):
			var i := y * _size.x + x
			if body_mask[i] == 1 and not _is_stripe_at(Vector2i(x, y)):
				body_mask[i] = 0


## x along a polyline of points going down, at height y (clamped to its ends).
static func _polyline_x(points: Array, y: float) -> float:
	if y <= points[0].y:
		return points[0].x
	for k in range(1, points.size()):
		if y <= points[k].y:
			return lerpf(points[k - 1].x, points[k].x, (y - points[k - 1].y) / (points[k].y - points[k - 1].y))
	return points[-1].x


func _darkest_in_row(y: int, from_x: int, to_x: int) -> Color:
	var darkest := Color.WHITE
	for x in range(from_x, to_x + 1):
		var c := _image.get_pixel(x, y)
		if c.a > 0.9 and c.v < darkest.v:
			darkest = c
	return darkest


## True on the arm's side of the sleeve hem (away from the shoulder).
func _below_hem(p: Vector2, side: String) -> bool:
	var hem: Array = ARMS[side].hem
	var along: Vector2 = hem[1] - hem[0]
	var shoulder_side := signf(along.cross(ARMS[side].shoulder - hem[0]))
	return signf(along.cross(p - hem[0])) != shoulder_side


## Distance from the shoulder -> hand line, which runs on past the hand's middle
## by HAND_REACH to take in the fingertips.
func _distance_to_arm_line(p: Vector2, side: String) -> float:
	var shoulder: Vector2 = ARMS[side].shoulder
	var hand: Vector2 = ARMS[side].hand
	var tip := hand + (hand - shoulder).normalized() * HAND_REACH
	return Geometry2D.get_closest_point_to_segment(p, shoulder, tip).distance_to(p)


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


func _tint_mask(guide: Image, mask: PackedByteArray, tint: Color) -> void:
	for i in mask.size():
		if mask[i] == 1:
			var p := Vector2i(i % _size.x, i / _size.x)
			var c := guide.get_pixelv(p)
			guide.set_pixelv(p, c.lerp(Color(tint, c.a), 0.45))


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


## The T-shirt: yellow (and its deep orange shading), its white stripes, and the
## teal and red sleeve trim.
func _is_shirt_at(p: Vector2i) -> bool:
	var c := _image.get_pixelv(p)
	if c.a < 0.5:
		return false
	var yellow := c.h > 0.095 and c.h < 0.18 and c.s > 0.45
	var orange_shade := c.h > 0.06 and c.h <= 0.095 and c.s > 0.62 and c.v > 0.6 # Skin never gets this saturated.
	var white := c.s < 0.16 and c.v > 0.82 and p.x >= TORSO_X.x and p.x <= TORSO_X.y
	var teal := c.h > 0.42 and c.h < 0.56 and c.s > 0.3
	var red := (c.h > 0.94 or c.h < 0.025) and c.s > 0.55 and c.v > 0.5
	return yellow or orange_shade or white or teal or red


## The shirt's body: its yellow, orange shading and white stripes (no trim).
func _is_stripe_at(p: Vector2i) -> bool:
	var c := _image.get_pixelv(p)
	var teal := c.h > 0.42 and c.h < 0.56 and c.s > 0.3
	var red := (c.h > 0.94 or c.h < 0.025) and c.s > 0.55 and c.v > 0.5
	return _is_shirt_at(p) and not teal and not red


## Same test as the rig's hair flow (StellaCutoutRig._is_hair_colour).
static func _is_hair(c: Color) -> bool:
	return c.a > 0.5 and c.h > 0.03 and c.h < 0.12 and c.s > 0.28 and c.s < 0.8 and c.v > 0.2 and c.v < 0.8


static func _is_skin(c: Color) -> bool:
	return c.a > 0.5 and (c.h < 0.1 or c.h > 0.97) and c.s > 0.2 and c.s < 0.72 and c.v > 0.75


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

