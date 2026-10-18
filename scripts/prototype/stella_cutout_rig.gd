class_name StellaCutoutRig
extends Node2D
## PROTOTYPE. Stella as a layered 2D cutout (art/prototypes/stella_cutout, made by
## tools/build_stella_cutout.gd), walked procedurally.
##
## The walk is driven by distance, not time: `advance()` moves the gait phase by
## distance / stride, and while a foot is on the floor it moves backwards (relative
## to the hips) by exactly the distance walked, so in the world it stays planted at
## any speed. Each step: heel contact (toe up, the foot rolling about the heel),
## foot flat, heel rising and toe-off (rolling about the ball), then a swing with
## the knee bent and the foot lifted. Knees come from two-bone IK; the hips sit as
## high as the legs reach, which gives the bob (lowest when both feet are down,
## highest at the passing pose) without authoring it. The arms swing opposite the
## legs, following the other side's foot.
##
## The shorts and the near sleeve are meshes that bend like cloth. Each leg
## opening of the shorts turns about its own thigh's hip with nearly all of its swing, its
## cuff as one piece, the denim above bending up to the waistband, which stays.
## The near sleeve turns with its arm, the bend fading out at its seams (the top
## of the shoulder, and where it's sewn to the torso).
## The far sleeve is part of the far arm (it swings behind the torso).
##
## Secondary motion (the flow): springs pushed by the hips' bob and the walking
## speed. The hair trails behind and bounces, its ends moving more (and later)
## than its roots; the lower shirt bounces and sways with each step; the head
## nods against the bob; the torso rocks a little with each push-off. Standing
## still, everything settles back to the drawn pose.
##
## Stopping never slides a foot: whatever is on the floor stays exactly where it
## is, and a foot in the air comes down beside the other one. Starting again lifts
## only the foot that's free. A mover that walks on to `distance_to_feet_together()`
## before stopping gets her standing with her feet side by side.
##
## Coordinates are Stella's canvas pixels with the origin at her feet (like the
## production CharacterArt); scale the node for depth and mirror it for facing.

const RIG_DIR := "res://art/prototypes/stella_cutout"
## Cloth mesh grid size, texture px.
const CLOTH_CELL := 6
## The head on the canvas (walk frame): the middle of the face and the half-sizes
## of an ellipse round it (hair outside it is loose, more so further out), and
## the neck it nods about.
const HEAD_CENTRE := Vector2(225, 100)
const HEAD_RADII := Vector2(40, 52)
const NECK := Vector2(212, 158)
const HAIR_BOTTOM_Y := 182.0
## The lower shirt moves from this height down to its hem.
const SHIRT_FLOW_Y := Vector2(196, 250)
## Springs: stiffness, damping. Hair roots are stiffer than its ends.
const HAIR_SPRING := Vector2(200, 12)
const HAIR_END_SPRING := Vector2(70, 5)
const SHIRT_SPRING := Vector2(160, 11)
const HEAD_SPRING := Vector2(150, 10)
## How far the springs may stretch, canvas px (the head: radians).
const FLOW_LIMIT := 12.0
## The shorts on the canvas (walk frame): bending starts below the waistband and
## is whole by the top of the cuffs; the leg openings divide along the crotch seam
## (top to bottom; above it, the back pocket goes with the back opening).
const SHORTS_TOP_Y := 256.0
const CUFF_TOP_Y := 274.0
const CROTCH_SEAM := [Vector2(180, 250), Vector2(181, 303)]
## Below this the two cuffs are separate pieces (the far one's inner end lies over
## the near one): each turns whole with its thigh, overlapping or parting a little.
const CUFF_SPLIT_Y := 280.0
## The openings' turns blend over this far either side of the seam (wider than a
## mesh cell, or the denim there folds).
const CROTCH_BLEND := 9.0
## Mesh vertex modes: blended across the crotch seam, or one opening's own.
enum Wear { BLENDED, NEAR, FAR }
## The near sleeve bends from this far above the shoulder joint (it hangs from
## the seam) to wholly following the arm this far below it, canvas px.
const SLEEVE_BEND := Vector2(16.0, 4.0)
## ...and from its seam with the torso to wholly following this far from it.
const SEAM_HOLD := 10.0

## Distance the body travels in one full cycle (two steps), canvas px.
@export var stride: float = 196.0
## Fraction of the cycle each foot is on the floor (> 0.5 gives double support).
@export_range(0.5, 0.8) var duty: float = 0.62
## Foot angle at heel contact (toe up), degrees.
@export var heel_strike_angle: float = 16.0
## Foot angle at toe-off (heel up), degrees.
@export var toe_off_angle: float = 38.0
## Fraction of stance spent rolling onto the foot after heel contact / on the toe.
@export var heel_roll: float = 0.16
@export var toe_roll: float = 0.30
## Swing foot lift at mid-swing, canvas px.
@export var swing_lift: float = 13.0
## Legs never fully straighten: the most of their length they reach.
@export_range(0.9, 1.0) var max_reach: float = 0.993
## Forward lean of the body while walking, degrees.
@export var lean: float = 2.0
## Arm swing either side of hanging straight down, degrees.
@export var arm_swing: float = 24.0
## Relaxed arms hang this far forward of straight down, degrees.
@export var arm_hang: float = 5.0
## Which cut leg each rig leg uses ("back" or "front" from the source frame).
@export var near_leg_source: String = "back"
@export var far_leg_source: String = "front"
## Lean while carrying Lemon (she's held in front, so a touch less forward), degrees.
@export var carry_lean: float = 0.5
## Carrying Lemon: the carry-idle upper body (arms holding her) on the same legs.
@export var carrying: bool = false:
	set(value):
		carrying = value
		_apply_carrying()
## How much of its thigh's swing each leg opening of the shorts follows.
@export_range(0.0, 1.0) var shorts_follow: float = 0.9
## The leg openings never turn further than this, degrees.
@export var shorts_max_turn: float = 40.0
## How much the hair, shirt and head move (0 = not at all, 1 = as designed).
@export_range(0.0, 2.0) var hair_flow: float = 1.0
@export_range(0.0, 2.0) var shirt_flow: float = 1.0
@export_range(0.0, 2.0) var head_flow: float = 1.0
## While walking, the hair streams back this far (canvas px) at 200 px/s.
@export var hair_drag: float = 4.0
## Each step sways the hair and the shirt hem this far forward and back, canvas px.
@export var hair_sway: float = 1.5
@export var shirt_sway: float = 1.5
## The torso rocks forward this much with each push-off, degrees.
@export var torso_rock: float = 1.2
## Standing, the free foot comes down this far (canvas px) behind the other.
@export var stand_gap: float = 12.0
## The far leg is drawn darker to sit behind.
@export var far_leg_tint: Color = Color(0.84, 0.82, 0.86)
@export var show_guides: bool = false:
	set(value):
		show_guides = value
		if _guides != null:
			_guides.queue_redraw()

## 0..1 through the cycle; the near leg's heel contact is at 0, the far leg's at 0.5.
var phase: float = 0.0
## 1 while walking, easing to 0 (standing) when stopped.
var walk_weight: float = 0.0
## Whether the last advance() moved.
var is_moving: bool = false

var _rig: Dictionary = {}
var _origin: Vector2
var _pelvis_rest: Vector2
var _legs: Dictionary = {} # "near"/"far" -> leg state
## Cloth meshes: {node: Polygon2D, rest: canvas positions, pivot, ...}.
var _body: Dictionary
var _near_sleeve: Dictionary
var _carry_body: Dictionary
var _arms: Dictionary = {} # "near"/"far" -> arm state
var _pelvis: Vector2
## Secondary motion springs ({pos, vel}; the head's pos.x is its nod, radians),
## and the hips' last position and velocity, for their acceleration.
var _hair_spring := {"pos": Vector2.ZERO, "vel": Vector2.ZERO}
var _hair_end_spring := {"pos": Vector2.ZERO, "vel": Vector2.ZERO}
var _shirt_spring := {"pos": Vector2.ZERO, "vel": Vector2.ZERO}
var _head_spring := {"pos": Vector2.ZERO, "vel": Vector2.ZERO}
var _last_pelvis := Vector2.INF
var _last_pelvis_velocity := Vector2.ZERO
## Drawn over the sprites (a node's own _draw is behind its children).
var _guides: Node2D


func _ready() -> void:
	_rig = JSON.parse_string(FileAccess.get_file_as_string(RIG_DIR.path_join("rig.json")))
	_origin = _vec(_rig.origin)
	_pelvis_rest = _vec(_rig.parts.body.pivot) - _origin
	# Drawing order: far arm, far leg, near leg, body, near arm, near sleeve.
	_arms["far"] = _make_arm("far")
	for side in ["far", "near"]:
		_legs[side] = _make_leg(side, far_leg_source if side == "far" else near_leg_source)
	_match_leg_reach()
	_body = _make_cloth("body", true, [], false)
	_carry_body = _make_cloth("carry_body", true, [], true)
	_arms["near"] = _make_arm("near")
	_near_sleeve = _make_cloth("near_sleeve", false, ["near"], false)
	_apply_carrying()
	phase = duty * 0.5 # Standing on the near foot with the far one beside it.
	for side: String in _legs:
		_legs[side].weight = 0.0
	_capture_stand()
	_guides = Node2D.new()
	_guides.name = "Guides"
	add_child(_guides)
	_guides.draw.connect(_draw_guides)
	_update_pose()


## Walks `distance` canvas px (0 to stand).
func advance(distance: float, delta: float) -> void:
	var moving := absf(distance) > 0.0001
	if moving and not is_moving:
		# Starting: a foot on the floor carries straight on from where it stands
		# (its standing pose is the walk's pose at this phase); a lifted one blends.
		for side: String in _legs:
			if _legs[side].stand_planted:
				_legs[side].weight = 1.0
	elif not moving and is_moving:
		_capture_stand()
	is_moving = moving
	phase = fposmod(phase + distance / stride, 1.0)
	for side: String in _legs:
		_legs[side].weight = move_toward(_legs[side].weight, 1.0 if moving else 0.0, delta * 7.0)
	walk_weight = move_toward(walk_weight, 1.0 if moving else 0.0, delta * 6.0)
	_update_pose()
	_step_flow(distance, delta)


## How far to walk on (canvas px) to the next passing pose, where the feet are
## side by side: stop there and she stands neatly.
func distance_to_feet_together() -> float:
	var near_passing := duty * 0.5
	var ahead := minf(fposmod(near_passing - phase, 1.0), fposmod(near_passing + 0.5 - phase, 1.0))
	return ahead * stride


## What each leg is doing, for readouts: {"near": "contact", "far": "swing", ...}.
func describe_legs() -> Dictionary:
	var info := {}
	for side: String in _legs:
		info[side] = _legs[side].stage
	return info


## Where a leg's sole touches the floor (rig coordinates), or null mid-swing.
func planted_point(side: String) -> Variant:
	return _legs[side].contact


func _make_leg(side: String, source: String) -> Dictionary:
	var leg: Dictionary = _rig.legs[source]
	var hip := _vec(leg.hip)
	var knee := _vec(leg.knee)
	var ankle := _vec(leg.ankle)
	var heel := _vec(leg.heel)
	var toe := _vec(leg.toe)
	var foot_rest := (toe - heel).angle()
	var state := {
		# Each thigh hangs from its own hip, where it was drawn, so it comes out of
		# its own leg of the shorts (the far one is further forward).
		"hip_offset": hip - _vec(_rig.parts.body.pivot),
		"source_hip": hip,
		"thigh": float(leg.thigh_length), "shin": float(leg.shin_length),
		"thigh_rest": (knee - hip).angle(), "shin_rest": (ankle - knee).angle(), "foot_rest": foot_rest,
		# Heel and ball relative to the ankle, in the foot's frame (sole along +x).
		"heel_f": (heel - ankle).rotated(-foot_rest), "ball_f": (_vec(leg.ball) - ankle).rotated(-foot_rest),
		"phase_offset": 0.0 if side == "near" else 0.5,
		"stage": "", "contact": null, "weight": 0.0, "stand": {}, "stand_planted": true, "reach_scale": 1.0,
		"hip": Vector2.ZERO, "knee": Vector2.ZERO, "ankle": Vector2.ZERO,
	}
	# Shin first so the thigh's knee cap and the shoe's collar cover the joints.
	for part in ["shin", "thigh", "foot"]:
		var sprite := _make_sprite(source + "_" + part)
		if side == "far":
			sprite.modulate = far_leg_tint
		state[part + "_sprite"] = sprite
	return state


## The two cut legs reach the floor by slightly different amounts (their ankles
## were found at different heights in the shoes); the far leg is scaled to match
## the near one, or the shorter leg would hold the hips down and bend the other.
func _match_leg_reach() -> void:
	var near_leg: Dictionary = _legs.near
	var far_leg: Dictionary = _legs.far
	var factor := _floor_reach(near_leg) / _floor_reach(far_leg)
	far_leg.thigh *= factor
	far_leg.shin *= factor
	far_leg.heel_f *= factor
	far_leg.ball_f *= factor
	for part in ["thigh_sprite", "shin_sprite", "foot_sprite"]:
		far_leg[part].scale = Vector2.ONE * factor
	far_leg.reach_scale = factor


## Hip to floor with the leg straight and the foot flat.
static func _floor_reach(leg: Dictionary) -> float:
	return leg.thigh + leg.shin + leg.heel_f.y


func _apply_carrying() -> void:
	if _body.is_empty():
		return
	_body.node.visible = not carrying
	_near_sleeve.node.visible = not carrying
	for side: String in _arms:
		_arms[side].sprite.visible = not carrying
	_carry_body.node.visible = carrying


func _make_arm(side: String) -> Dictionary:
	var arm: Dictionary = _rig.arms[side]
	var shoulder := _vec(arm.shoulder)
	return {
		"sprite": _make_sprite(side + "_arm"),
		"shoulder_offset": shoulder - _vec(_rig.parts.body.pivot),
		"rest": (_vec(arm.hand) - shoulder).angle(),
		"shoulder": shoulder, "hand": _vec(arm.hand),
		"seam": [_vec(arm.seam[0]), _vec(arm.seam[1])] if arm.has("seam") else [],
		"turn": 0.0, # Rotation from its pose in the frame.
	}


## Freezes the current pose as the standing pose: a foot on the floor stays put;
## a foot in the air will come down flat, stand_gap behind the other.
func _capture_stand() -> void:
	var poses := {}
	for side: String in _legs:
		poses[side] = _gait_foot(_legs[side], fposmod(phase + _legs[side].phase_offset, 1.0))
	for side: String in _legs:
		var leg: Dictionary = _legs[side]
		leg.stand_planted = poses[side].contact != null
		if leg.stand_planted:
			leg.stand = poses[side]
			continue
		var other: String = "far" if side == "near" else "near"
		var other_leg: Dictionary = _legs[other]
		var other_mid: float = poses[other].contact.x + (other_leg.ball_f.x - other_leg.heel_f.x) * 0.5
		if poses[other].stage == "toe-off": # Its contact is the ball, not the heel.
			other_mid -= other_leg.ball_f.x - other_leg.heel_f.x
		var heel_f: Vector2 = leg.heel_f
		var ball_f: Vector2 = leg.ball_f
		var pivot := Vector2(other_mid - stand_gap - (ball_f.x - heel_f.x) * 0.5, 0.0)
		leg.stand = {"ankle": pivot - heel_f, "angle": 0.0, "contact": pivot, "stage": "standing"}


## A part as a grid mesh (CLOTH_CELL px squares over its opaque pixels) that
## _bend_cloth() can deform. `shorts`: its shorts bend with the thighs, whose pose
## in this part's source frame is `legs_straight` (carry idle) or the walk frame's.
## `sleeves`: which sleeves bend with their arms.
func _make_cloth(part: String, shorts: bool, sleeves: Array, legs_straight: bool) -> Dictionary:
	var info: Dictionary = _rig.parts[part]
	var texture: Texture2D = load(RIG_DIR.path_join(info.file))
	var image := texture.get_image()
	var size := image.get_size()
	var columns := ceili(float(size.x) / CLOTH_CELL) + 1
	var rows := ceili(float(size.y) / CLOTH_CELL) + 1
	var uv := PackedVector2Array()
	for j in rows:
		for i in columns:
			uv.append(Vector2(mini(i * CLOTH_CELL, size.x), mini(j * CLOTH_CELL, size.y)))
	var polygons := []
	for j in rows - 1:
		for i in columns - 1:
			if _cell_has_pixels(image, Rect2i(uv[j * columns + i], Vector2i(CLOTH_CELL, CLOTH_CELL))):
				var a := j * columns + i
				polygons.append(PackedInt32Array([a, a + 1, a + columns + 1, a + columns]))
	var origin := _vec(info.position)
	var pivot := _vec(info.pivot)
	var wear := PackedByteArray()
	wear.resize(uv.size())
	if shorts:
		# The far cuff's cells get their own copies of their corners, so the cuffs
		# come apart below CUFF_SPLIT_Y (the carry body's shorts are placed like the
		# walking body's relative to the pivot).
		var to_walk_frame: Vector2 = (_body.pivot - pivot) if not _body.is_empty() else Vector2.ZERO
		var n := uv.size()
		var seat := {}
		var cuff_cells := []
		for polygon: PackedInt32Array in polygons:
			var centre: Vector2 = origin + uv[polygon[0]] + Vector2.ONE * CLOTH_CELL * 0.5 + to_walk_frame
			if centre.y > CUFF_SPLIT_Y:
				cuff_cells.append([polygon, centre.x >= _polyline_x(CROTCH_SEAM, centre.y)])
			else:
				for v in polygon:
					seat[v] = true
		uv.append_array(uv.duplicate())
		wear.resize(uv.size())
		for cell: Array in cuff_cells:
			var polygon: PackedInt32Array = cell[0]
			for k in polygon.size():
				var v := polygon[k]
				if cell[1]:
					polygon[k] = v + n
					wear[v + n] = Wear.BLENDED if seat.has(v) else Wear.FAR
				elif not seat.has(v):
					wear[v] = Wear.NEAR
	var flow := _flow_weights(image, uv, origin + ((_body.pivot - pivot) if not _body.is_empty() else Vector2.ZERO)) \
			if shorts else {}
	var node := Polygon2D.new()
	node.name = part
	node.texture = texture
	node.uv = uv
	node.polygons = polygons
	var rest := PackedVector2Array()
	for point in uv:
		rest.append(origin + point)
	var placed := PackedVector2Array()
	for point in rest:
		placed.append(point - pivot)
	node.polygon = placed
	add_child(node)
	return {"node": node, "rest": rest, "pivot": pivot, "shorts": shorts, "sleeves": sleeves,
			"legs_straight": legs_straight, "wear": wear, "flow": flow}


## How much each vertex of a body mesh moves with the hair, the shirt and the
## head, from what's painted around it (`to_canvas`: texture px to walk-frame
## canvas). Hair: the share of hair-coloured pixels nearby, times how far out
## from the face it is; shirt: the share of shirt pixels, more towards the hem;
## head: everything above the neck.
func _flow_weights(image: Image, uv: PackedVector2Array, to_canvas: Vector2) -> Dictionary:
	var hair := PackedFloat32Array()
	var shirt := PackedFloat32Array()
	var head := PackedFloat32Array()
	var bounds := Rect2i(Vector2i.ZERO, image.get_size())
	for point in uv:
		var canvas := point + to_canvas
		var area := Rect2i(Vector2i(point) - Vector2i.ONE * CLOTH_CELL, Vector2i.ONE * CLOTH_CELL * 2).intersection(bounds)
		var opaque := 0
		var hair_px := 0
		var shirt_px := 0
		for y in range(area.position.y, area.end.y, 2):
			for x in range(area.position.x, area.end.x, 2):
				var c := image.get_pixel(x, y)
				if c.a < 0.5:
					continue
				opaque += 1
				if _is_hair_colour(c):
					hair_px += 1
				elif _is_shirt_colour(c):
					shirt_px += 1
		var share := 1.0 / maxf(opaque, 1.0)
		var out := ((canvas - HEAD_CENTRE) / HEAD_RADII).length()
		# The shirt's shoulders are below the hair and in front of it, and the hair
		# ends above HAIR_BOTTOM_Y (dark outlines on the shirt look like hair).
		var on_shirt := (canvas.y > NECK.y and canvas.x > NECK.x - 40.0) or canvas.y > HAIR_BOTTOM_Y
		hair.append(0.0 if on_shirt else hair_px * share * smoothstep(0.9, 2.3, out))
		shirt.append(shirt_px * share * smoothstep(SHIRT_FLOW_Y.x, SHIRT_FLOW_Y.y, canvas.y))
		head.append(1.0 - smoothstep(NECK.y - 8.0, NECK.y + 8.0, canvas.y))
	return {"hair": hair, "shirt": shirt, "head": head}


static func _is_hair_colour(c: Color) -> bool:
	return c.h > 0.03 and c.h < 0.12 and c.s > 0.28 and c.s < 0.8 and c.v > 0.2 and c.v < 0.8


static func _is_shirt_colour(c: Color) -> bool:
	var yellow := c.h > 0.095 and c.h < 0.18 and c.s > 0.45 and c.v > 0.6
	var orange_shade := c.h > 0.06 and c.h <= 0.095 and c.s > 0.62 and c.v > 0.6
	var white := c.s < 0.16 and c.v > 0.82
	return yellow or orange_shade or white


static func _cell_has_pixels(image: Image, cell: Rect2i) -> bool:
	var area := cell.intersection(Rect2i(Vector2i.ZERO, image.get_size()))
	for y in range(area.position.y, area.end.y):
		for x in range(area.position.x, area.end.x):
			if image.get_pixel(x, y).a > 0.0:
				return true
	return false


## Moves the cloth's vertices: shorts about the hips, sleeves about the shoulders.
func _bend_cloth(cloth: Dictionary) -> void:
	var limit := deg_to_rad(shorts_max_turn)
	# The carry body's shorts sit where the walking body's do, relative to its pivot.
	var to_walk_frame: Vector2 = _body.pivot - cloth.pivot
	var turns := {}
	for side: String in _legs:
		var leg: Dictionary = _legs[side]
		var drawn_at: float = PI * 0.5 if cloth.legs_straight else leg.thigh_rest
		turns[side] = clampf(angle_difference(drawn_at, (leg.knee - leg.hip).angle()) * shorts_follow, -limit, limit)
	var placed := PackedVector2Array()
	placed.resize(cloth.rest.size())
	var flow: Dictionary = cloth.flow
	var neck := NECK - to_walk_frame
	var nod: float = _head_spring.pos.x * head_flow
	for k in cloth.rest.size():
		var p: Vector2 = cloth.rest[k]
		if not flow.is_empty():
			p = neck + (p - neck).rotated(nod * flow.head[k])
			var w: float = flow.hair[k]
			if w > 0.0:
				p += _hair_spring.pos.lerp(_hair_end_spring.pos, w) * w * hair_flow
			p += _shirt_spring.pos * flow.shirt[k] * shirt_flow
		if cloth.shorts:
			var q: Vector2 = cloth.rest[k] + to_walk_frame
			var weight := smoothstep(SHORTS_TOP_Y, CUFF_TOP_Y, q.y)
			if weight > 0.0:
				# The near leg (cut from the frame's back leg) wears the back opening;
				# each opening turns about its own thigh's hip.
				var back := 1.0 - smoothstep(-CROTCH_BLEND, CROTCH_BLEND, q.x - _polyline_x(CROTCH_SEAM, q.y))
				if cloth.wear[k] != Wear.BLENDED:
					back = 1.0 if cloth.wear[k] == Wear.NEAR else 0.0
				var near_hip: Vector2 = _legs.near.source_hip - to_walk_frame
				var far_hip: Vector2 = _legs.far.source_hip - to_walk_frame
				var with_far := far_hip + (p - far_hip).rotated(weight * turns.far)
				var with_near := near_hip + (p - near_hip).rotated(weight * turns.near)
				p = with_far.lerp(with_near, back)
		for side: String in cloth.sleeves:
			var arm: Dictionary = _arms[side]
			var weight := smoothstep(arm.shoulder.y - SLEEVE_BEND.x, arm.shoulder.y + SLEEVE_BEND.y, p.y)
			if not arm.seam.is_empty():
				# Sewn to the torso along its seam: the cloth there stays put, down to
				# the armpit (below it, the hem goes with the arm).
				var along: Vector2 = (arm.seam[1] - arm.seam[0]).normalized()
				var arm_side := signf(along.cross(arm.hand - arm.seam[0]))
				var held := smoothstep(0.0, SEAM_HOLD, along.cross(p - arm.seam[0]) * arm_side)
				weight *= lerpf(held, 1.0, smoothstep(arm.seam[1].y - 16.0, arm.seam[1].y - 4.0, p.y))
			if weight > 0.0:
				p = arm.shoulder + (p - arm.shoulder).rotated(arm.turn * weight)
		placed[k] = p - cloth.pivot
	cloth.node.polygon = placed


## Moves the springs on by `delta`: pushed by the hips' acceleration (loose things
## lag behind the body's bob), pulled towards trailing back while walking, and
## swayed with each step.
func _step_flow(distance: float, delta: float) -> void:
	if delta <= 0.0:
		return
	var velocity := Vector2.ZERO if _last_pelvis == Vector2.INF else (_pelvis - _last_pelvis) / delta
	var accel := ((velocity - _last_pelvis_velocity) / delta).limit_length(4000.0)
	if _last_pelvis == Vector2.INF:
		accel = Vector2.ZERO
	_last_pelvis = _pelvis
	_last_pelvis_velocity = velocity
	var drag := clampf(absf(distance) / delta / 200.0, 0.0, 1.5) * walk_weight
	var step := TAU * 2.0 * phase
	var hair_target := Vector2(-hair_drag * drag + hair_sway * sin(step - 1.2) * walk_weight, 0.0)
	_spring(_hair_spring, hair_target, accel, HAIR_SPRING, delta)
	_spring(_hair_end_spring, hair_target * 1.6, accel, HAIR_END_SPRING, delta)
	_spring(_shirt_spring, Vector2(shirt_sway * sin(step - 0.6) * walk_weight - drag, 0.0), accel * 0.6,
			SHIRT_SPRING, delta)
	# The head nods down as the hips come up (and lags their fall), a little.
	_spring(_head_spring, Vector2.ZERO, Vector2(accel.y * 0.005, 0.0), HEAD_SPRING, delta)
	_head_spring.pos.x = clampf(_head_spring.pos.x, -0.05, 0.05)


static func _spring(spring: Dictionary, target: Vector2, accel: Vector2, constants: Vector2, delta: float) -> void:
	var steps := maxi(ceili(delta * 240.0), 1)
	var h := delta / steps
	for i in steps:
		var a: Vector2 = (target - spring.pos) * constants.x - spring.vel * constants.y - accel
		spring.vel += a * h
		spring.pos += spring.vel * h
	spring.pos = spring.pos.limit_length(FLOW_LIMIT)


## x along a polyline of points going down, at height y (clamped to its ends).
static func _polyline_x(points: Array, y: float) -> float:
	if y <= points[0].y:
		return points[0].x
	for k in range(1, points.size()):
		if y <= points[k].y:
			return lerpf(points[k - 1].x, points[k].x, (y - points[k - 1].y) / (points[k].y - points[k - 1].y))
	return points[-1].x


func _make_sprite(part: String) -> Sprite2D:
	var info: Dictionary = _rig.parts[part]
	var sprite := Sprite2D.new()
	sprite.name = part
	sprite.texture = load(RIG_DIR.path_join(info.file))
	sprite.centered = false
	sprite.offset = _vec(info.position) - _vec(info.pivot) # Pivot at the sprite's origin.
	add_child(sprite)
	return sprite


func _update_pose() -> void:
	if _rig.is_empty():
		return
	# 1. Ankle targets and foot angles from the gait (blended towards standing).
	for side: String in _legs:
		var leg: Dictionary = _legs[side]
		var walking := _gait_foot(leg, fposmod(phase + leg.phase_offset, 1.0))
		var standing: Dictionary = leg.stand
		var w: float = smoothstep(0.0, 1.0, leg.weight)
		leg.ankle = standing.ankle.lerp(walking.ankle, w)
		leg.angle = lerpf(standing.angle, walking.angle, w)
		if not leg.stand_planted and w > 0.0 and w < 1.0:
			leg.ankle.y -= swing_lift * 0.6 * sin(PI * w) # Step down / up, not a slide.
		leg.stage = walking.stage if w > 0.5 or is_moving else "standing"
		leg.contact = walking.contact if w > 0.5 or is_moving else standing.contact
	# 2. Hips as high as both legs reach.
	var pelvis_y := -INF
	for side: String in _legs:
		var leg: Dictionary = _legs[side]
		var reach: float = (leg.thigh + leg.shin) * max_reach
		var dx: float = leg.ankle.x - (_pelvis_rest.x + leg.hip_offset.x)
		pelvis_y = maxf(pelvis_y, leg.ankle.y - sqrt(maxf(reach * reach - dx * dx, 0.0)) - leg.hip_offset.y)
	_pelvis = Vector2(_pelvis_rest.x, pelvis_y)
	# Leaning in, and rocking forward a little as each foot pushes off.
	var rock := deg_to_rad(torso_rock) * sin(TAU * 2.0 * phase - PI * 0.5)
	var body_rotation := (deg_to_rad(carry_lean if carrying else lean) + rock) * walk_weight
	for cloth: Dictionary in [_body, _carry_body, _near_sleeve]:
		cloth.node.position = _pelvis
		cloth.node.rotation = body_rotation
	# Arms: each follows the other side's foot (forward when that foot is ahead).
	var half_step := duty * stride * 0.5
	for side: String in _arms:
		var arm: Dictionary = _arms[side]
		var other: Dictionary = _legs["far" if side == "near" else "near"]
		var forward := clampf((other.ankle.x - other.hip_offset.x) / half_step, -1.0, 1.0) * walk_weight
		arm.sprite.position = _pelvis + arm.shoulder_offset.rotated(body_rotation)
		# Hanging is straight down (PI/2); forwards turns the hand towards +x.
		arm.turn = PI * 0.5 - deg_to_rad(arm_hang + arm_swing * forward) - arm.rest
		arm.sprite.rotation = arm.turn + body_rotation
	# 3. Knees by two-bone IK, bending forwards (+x).
	for side: String in _legs:
		var leg: Dictionary = _legs[side]
		leg.hip = _pelvis + leg.hip_offset
		leg.knee = _solve_knee(leg.hip, leg.ankle, leg.thigh, leg.shin)
		leg.thigh_sprite.position = leg.hip
		leg.thigh_sprite.rotation = (leg.knee - leg.hip).angle() - leg.thigh_rest
		leg.shin_sprite.position = leg.knee
		leg.shin_sprite.rotation = (leg.ankle - leg.knee).angle() - leg.shin_rest
		leg.foot_sprite.position = leg.ankle
		leg.foot_sprite.rotation = leg.angle - leg.foot_rest
	# 4. Cloth follows the limbs.
	if carrying:
		_bend_cloth(_carry_body)
	else:
		_bend_cloth(_body)
		_bend_cloth(_near_sleeve)
	if show_guides:
		_guides.queue_redraw()


## The foot at cycle position `t` (0 = this foot's heel contact), its path
## centred under its own hip.
## Returns {ankle, angle (sole direction, radians; + = heel up), stage, contact}.
func _gait_foot(leg: Dictionary, t: float) -> Dictionary:
	var foot := _gait_foot_under_pelvis(leg, t)
	var shift := Vector2(leg.hip_offset.x, 0.0)
	foot.ankle += shift
	if foot.contact != null:
		foot.contact += shift
	return foot


func _gait_foot_under_pelvis(leg: Dictionary, t: float) -> Dictionary:
	var heel_f: Vector2 = leg.heel_f
	var ball_f: Vector2 = leg.ball_f
	if t < duty:
		return _stance_foot(heel_f, ball_f, t / duty)
	# Swing: from the toe-off pose to the next heel contact, lifted in between.
	var w := (t - duty) / (1.0 - duty)
	var from := _stance_foot(heel_f, ball_f, 1.0)
	var to := _stance_foot(heel_f, ball_f, 0.0)
	var s := smoothstep(0.0, 1.0, w)
	var ankle: Vector2 = from.ankle.lerp(to.ankle, s)
	ankle.y -= swing_lift * sin(PI * w)
	return {"ankle": ankle, "angle": lerp_angle(from.angle, to.angle, smoothstep(0.0, 1.0, minf(w * 1.3, 1.0))),
			"stage": "swing", "contact": null}


## On the floor, `u` 0..1 from heel contact to toe-off. The sole's midpoint moves
## from duty*stride/2 ahead of the hips to as far behind, at exactly the walking
## speed, so whichever point it rolls about stays still in the world.
func _stance_foot(heel_f: Vector2, ball_f: Vector2, u: float) -> Dictionary:
	var span := duty * stride
	var heel_x := span * 0.5 - u * span - (ball_f.x - heel_f.x) * 0.5
	var angle := 0.0
	var pivot := Vector2(heel_x, 0.0)
	var pivot_f := heel_f
	var stage := "flat"
	if u < heel_roll:
		angle = -deg_to_rad(heel_strike_angle) * (1.0 - smoothstep(0.0, 1.0, u / heel_roll))
		stage = "contact"
	elif u > 1.0 - toe_roll:
		angle = deg_to_rad(toe_off_angle) * smoothstep(0.0, 1.0, (u - (1.0 - toe_roll)) / toe_roll)
		pivot = Vector2(heel_x + ball_f.x - heel_f.x, 0.0)
		pivot_f = ball_f
		stage = "toe-off"
	elif u < 0.42:
		stage = "down"
	elif u < 0.62:
		stage = "passing"
	else:
		stage = "up"
	return {"ankle": pivot - pivot_f.rotated(angle), "angle": angle, "stage": stage, "contact": pivot}


static func _solve_knee(hip: Vector2, target: Vector2, upper: float, lower: float) -> Vector2:
	var to_target := target - hip
	var d := clampf(to_target.length(), absf(upper - lower) + 0.01, upper + lower - 0.01)
	var cos_a := clampf((upper * upper + d * d - lower * lower) / (2.0 * upper * d), -1.0, 1.0)
	var bend := acos(cos_a)
	# Pointing down, rotating by -bend swings the knee towards +x (forwards).
	var a := to_target.angle()
	var knee := hip + Vector2.from_angle(a - bend) * upper
	if knee.x < hip.lerp(target, 0.5).x:
		knee = hip + Vector2.from_angle(a + bend) * upper
	return knee


func _draw_guides() -> void:
	if not show_guides or _legs.is_empty():
		return
	for side: String in _legs:
		var leg: Dictionary = _legs[side]
		var colour := Color(0.1, 0.5, 1.0) if side == "near" else Color(1.0, 0.45, 0.1)
		_guides.draw_polyline(PackedVector2Array([leg.hip, leg.knee, leg.ankle]), colour, 3.0)
		for p: Vector2 in [leg.hip, leg.knee, leg.ankle]:
			_guides.draw_circle(p, 5.0, colour)
		if leg.contact != null:
			_guides.draw_circle(leg.contact, 7.0, Color(0.1, 0.75, 0.3))
	_guides.draw_line(Vector2(-200, 0), Vector2(200, 0), Color(1, 0, 0.6, 0.6), 1.0)


static func _vec(value: Array) -> Vector2:
	return Vector2(value[0], value[1])
