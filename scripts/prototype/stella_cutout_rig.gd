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
## Stopping never slides a foot: whatever is on the floor stays exactly where it
## is, and a foot in the air comes down beside the other one. Starting again lifts
## only the foot that's free. A mover that walks on to `distance_to_feet_together()`
## before stopping gets her standing with her feet side by side.
##
## Coordinates are Stella's canvas pixels with the origin at her feet (like the
## production CharacterArt); scale the node for depth and mirror it for facing.

const RIG_DIR := "res://art/prototypes/stella_cutout"

## Distance the body travels in one full cycle (two steps), canvas px.
@export var stride: float = 200.0
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
@export var swing_lift: float = 22.0
## Legs never fully straighten: the most of their length they reach.
@export_range(0.9, 1.0) var max_reach: float = 0.995
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
var _body: Sprite2D
var _near_sleeve: Sprite2D
var _carry_body: Sprite2D
var _arms: Dictionary = {} # "near"/"far" -> arm state
var _pelvis: Vector2
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
	_body = _make_sprite("body")
	_carry_body = _make_sprite("carry_body")
	_arms["near"] = _make_arm("near")
	_near_sleeve = _make_sprite("near_sleeve")
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
		# Side on, both hips are at the pelvis (the frame's two hips differ only
		# because its legs splay).
		"hip_offset": Vector2(0.0, hip.y - _vec(_rig.parts.body.pivot).y),
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
	if _body == null:
		return
	_body.visible = not carrying
	_near_sleeve.visible = not carrying
	for side: String in _arms:
		_arms[side].sprite.visible = not carrying
	_carry_body.visible = carrying


func _make_arm(side: String) -> Dictionary:
	var arm: Dictionary = _rig.arms[side]
	var shoulder := _vec(arm.shoulder)
	return {
		"sprite": _make_sprite(side + "_arm"),
		"shoulder_offset": shoulder - _vec(_rig.parts.body.pivot),
		"rest": (_vec(arm.hand) - shoulder).angle(),
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
	_body.position = _pelvis
	_body.rotation = deg_to_rad(carry_lean if carrying else lean) * walk_weight
	_carry_body.position = _pelvis
	_carry_body.rotation = _body.rotation
	_near_sleeve.position = _pelvis
	_near_sleeve.rotation = _body.rotation
	# Arms: each follows the other side's foot (forward when that foot is ahead).
	var half_step := duty * stride * 0.5
	for side: String in _arms:
		var arm: Dictionary = _arms[side]
		var other: Dictionary = _legs["far" if side == "near" else "near"]
		var forward := clampf((other.ankle.x - other.hip_offset.x) / half_step, -1.0, 1.0) * walk_weight
		arm.sprite.position = _pelvis + arm.shoulder_offset.rotated(_body.rotation)
		# Hanging is straight down (PI/2); forwards turns the hand towards +x.
		arm.sprite.rotation = PI * 0.5 - deg_to_rad(arm_hang + arm_swing * forward) - arm.rest + _body.rotation
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
	if show_guides:
		_guides.queue_redraw()


## The foot at cycle position `t` (0 = this foot's heel contact).
## Returns {ankle, angle (sole direction, radians; + = heel up), stage, contact}.
func _gait_foot(leg: Dictionary, t: float) -> Dictionary:
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
