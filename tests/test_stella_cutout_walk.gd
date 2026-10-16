extends "res://tests/framework/test_case.gd"
## PROTOTYPE cutout walk (StellaCutoutRig): the planted foot stays put on the
## floor, the legs alternate through contact, passing and toe-off, and the knees
## bend in the swing; stopping never slides a foot; carrying Lemon walks on the
## same legs. The production Stella is covered by the other files.

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
	check_eq(rig.get_children().filter(func(n: Node) -> bool: return n is Sprite2D).size(), 11,
			"body, carry body, near sleeve, 2 arms, 3 parts per leg")


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


func test_carrying_uses_the_same_legs() -> void:
	rig.carrying = true
	await wait_physics_frames(2)
	check(rig._carry_body.visible and not rig._body.visible, "carrying: the carry body replaces the walking one")
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
