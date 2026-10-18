extends "res://tests/framework/test_case.gd"
## PROTOTYPE cutout walk (StellaCutoutRig): the planted foot stays put on the
## floor, the legs alternate through contact, passing and toe-off, and the knees
## bend in the swing; stopping never slides a foot; carrying Lemon walks on the
## same legs; the shorts, sleeve, hair and shirt move with her and settle when
## she stops. The production Stella is covered by the other files.

const STAGE := "res://scenes/prototype/stella_cutout_walk_test.tscn"
const RIG_JSON := "res://art/prototypes/stella_cutout/rig.json"

var stage: Node2D
var rig: StellaCutoutRig


func before_each() -> void:
	stage = load(STAGE).instantiate()
	get_tree().root.add_child(stage)
	get_tree().current_scene = stage
	rig = stage.get_node("%Stella")
	await wait_physics_frames(3)


func after_each() -> void:
	stage.queue_free()
	await wait_frames(2)


## Walks for `frames` physics frames, recording the stages seen.
func walk_and_watch(frames: int) -> Dictionary:
	var seen := {"near": {}, "far": {}, "both_swinging": false, "passing_over_swing": false,
			"max_swing_bend": 0.0, "max_contact_bend": 0.0}
	for i in frames:
		await wait_physics_frames(1)
		var legs := rig.describe_legs()
		for side in ["near", "far"]:
			seen[side][legs[side]] = true
			var leg: Dictionary = rig._legs[side]
			var bend := rad_to_deg(absf(angle_difference((leg.knee - leg.hip).angle(), (leg.ankle - leg.knee).angle())))
			if legs[side] == "swing":
				seen.max_swing_bend = maxf(seen.max_swing_bend, bend)
			elif legs[side] == "contact":
				seen.max_contact_bend = maxf(seen.max_contact_bend, bend)
		if legs.near == "swing" and legs.far == "swing":
			seen.both_swinging = true
		if (legs.near == "passing" and legs.far == "swing") or (legs.far == "passing" and legs.near == "swing"):
			seen.passing_over_swing = true
	return seen


func test_parts_from_committed_frame() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(RIG_JSON))
	check_eq(FileAccess.get_sha256(data.source), data.source_sha256, "the cutout matches the walk frame it was cut from")
	for part in ["body", "carry_body", "near_sleeve", "near_arm", "far_arm",
			"back_thigh", "back_shin", "back_foot", "front_thigh", "front_shin", "front_foot"]:
		check(ResourceLoader.exists("res://art/prototypes/stella_cutout/%s.png" % part), "%s part exists" % part)
	check_eq(FileAccess.get_sha256(data.carry_source), data.carry_source_sha256, "the carry body matches its carry-idle frame")
	check_eq(rig.get_children().filter(func(n: Node) -> bool: return n is Sprite2D).size(), 8, "2 arms, 3 parts per leg")
	check_eq(rig.get_children().filter(func(n: Node) -> bool: return n is Polygon2D).size(), 3,
			"body, carry body and near sleeve are cloth meshes")


func test_planted_foot_stays_put_across() -> void:
	stage.mode = stage.Mode.ACROSS
	stage._place_rig()
	await wait_physics_frames(240) # Includes a turn at the edge.
	check(stage.max_drift < 0.5, "planted foot drift %.3f px < 0.5 walking across" % stage.max_drift)


func test_planted_foot_stays_put_in_place() -> void:
	await wait_physics_frames(180)
	check(stage.max_drift < 0.5, "planted foot drift %.3f px < 0.5 against the sliding floor" % stage.max_drift)


func test_alternating_cycle() -> void:
	var seen := await walk_and_watch(120)
	for side in ["near", "far"]:
		for stage_name in ["contact", "down", "passing", "up", "toe-off", "swing"]:
			check(seen[side].has(stage_name), "%s leg goes through %s" % [side, stage_name])
	check(not seen.both_swinging, "one foot is always on the floor")
	check(seen.passing_over_swing, "passing pose: one leg swings past the supporting one")
	check(seen.max_swing_bend > 30.0, "knee bends in the swing (%.0f deg)" % seen.max_swing_bend)
	check(seen.max_contact_bend < 15.0, "leg nearly straight at heel contact (%.0f deg)" % seen.max_contact_bend)


## Largest distance any vertex of a cloth mesh has moved from where it was painted.
func cloth_moved(cloth: Dictionary, region: Rect2) -> float:
	var most := 0.0
	var polygon: PackedVector2Array = cloth.node.polygon
	for k in polygon.size():
		var rest: Vector2 = cloth.rest[k]
		if region.has_point(rest):
			most = maxf(most, (polygon[k] + cloth.pivot).distance_to(rest))
	return most


func test_shorts_and_sleeves_move() -> void:
	var hem_moves := []
	var sleeve_moves := []
	for i in 4:
		await wait_physics_frames(10)
		hem_moves.append(snappedf(cloth_moved(rig._body, Rect2(150, 285, 100, 20)), 0.5))
		sleeve_moves.append(snappedf(cloth_moved(rig._near_sleeve, Rect2(145, 200, 45, 20)), 0.5))
	check(hem_moves.max() > 6.0, "the shorts' hem swings with the thighs (%s px)" % [hem_moves])
	check(hem_moves.max() - hem_moves.min() > 2.0, "...and keeps moving through the step")
	check(sleeve_moves.max() > 6.0, "the near sleeve's hem goes with its arm (%s px)" % [sleeve_moves])
	check(cloth_moved(rig._near_sleeve, Rect2(140, 170, 60, 6)) < 0.5, "...but its top stays at the shoulder seam")


func test_hair_and_shirt_flow() -> void:
	var hair_ends := Rect2(105, 90, 50, 80)
	var face := Rect2(215, 80, 40, 50)
	var shirt_hem := Rect2(175, 236, 50, 14)
	var most := {"hair": 0.0, "face": 0.0, "shirt": 0.0}
	for i in 90:
		await wait_physics_frames(1)
		most.hair = maxf(most.hair, cloth_moved(rig._body, hair_ends))
		most.face = maxf(most.face, cloth_moved(rig._body, face))
		most.shirt = maxf(most.shirt, cloth_moved(rig._body, shirt_hem))
	check(most.hair > 4.0, "walking, the hair's ends swing (%.1f px)" % most.hair)
	check(most.face < 4.0 and most.face < most.hair * 0.6, "...far more than the face nods (%.1f px)" % most.face)
	check(most.shirt > 1.0, "...and the shirt's hem moves (%.1f px)" % most.shirt)
	stage.walking = false
	await wait_until(func() -> bool: return not rig.is_moving, 3.0, "she stops")
	await wait_physics_frames(150)
	var settled := cloth_moved(rig._body, Rect2(100, 30, 190, 210))
	check(settled < 0.5, "standing, the hair, head and shirt settle back (%.2f px)" % settled)


func test_carrying_uses_the_same_legs() -> void:
	rig.carrying = true
	await wait_physics_frames(2)
	check(rig._carry_body.node.visible and not rig._body.node.visible, "carrying: the carry body replaces the walking one")
	check(not rig._arms.near.sprite.visible and not rig._arms.far.sprite.visible, "...and its own arms hold Lemon")
	stage.max_drift = 0.0
	var seen := await walk_and_watch(120)
	check(stage.max_drift < 0.5, "carrying, planted foot drift %.3f px < 0.5" % stage.max_drift)
	check(seen.passing_over_swing and not seen.both_swinging, "carrying, the legs still alternate")


func test_stops_standing() -> void:
	await wait_physics_frames(47) # Mid-step.
	stage.walking = false
	await wait_until(func() -> bool: return not rig.is_moving, 3.0, "she finishes her step")
	await wait_physics_frames(30)
	check_eq(rig.describe_legs(), {"near": "standing", "far": "standing"}, "stopped: both feet down")
	check(stage.max_drift < 0.5, "stopping, planted foot drift %.3f px < 0.5" % stage.max_drift)
	var near_x: float = rig.planted_point("near").x
	var far_x: float = rig.planted_point("far").x
	check(absf(near_x - far_x) < 40.0, "feet side by side (%.0f px apart)" % absf(near_x - far_x))
	stage.walking = true
	await wait_physics_frames(60)
	check(stage.max_drift < 0.5, "starting again, drift %.3f px < 0.5" % stage.max_drift)
