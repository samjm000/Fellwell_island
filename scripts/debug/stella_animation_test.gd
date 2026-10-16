extends Node2D
## A plain stage for judging Stella's animations: no room art, a floor marked
## with a ruler so sliding feet show against it, and readouts of what's playing.
##
## Run res://scenes/debug/stella_animation_test.tscn (F6 in the editor). Stella
## moves exactly as in a room: click the floor to walk, or use WASD / arrows
## (debug builds). The keys below are listed on screen too.

## Floor area she can walk on (feet positions).
const FLOOR := Rect2(80, 470, 1120, 242)
## Spacing of the ruler marks on the floor.
const TICK := 32.0
const HELP := "Click floor / WASD / arrows: walk\nC: carry Lemon on / off\nK: pick up / put down\n" \
		+ "T: tour (idle, left, right, up, down, carry)\n1 / 2 / 3: speed 100% / 50% / 25%\nZ: room scale / 1:1"

## The in-game perspective (Stella's room), restored when leaving 1:1.
var _room_scales := Vector2.ZERO
## Bumped to cancel a running tour.
var _tour_id: int = 0
var _tour_step: String = ""

@onready var stella: Stella = %Stella
@onready var _art: CharacterArt = stella.get_node("%Visual")
@onready var _perspective: RoomPerspective = $Perspective
@onready var _readout: Label = %Readout
@onready var _help: Label = %Help


func _ready() -> void:
	_room_scales = Vector2(_perspective.far_scale, _perspective.near_scale)
	_help.text = HELP


func _exit_tree() -> void:
	Engine.time_scale = 1.0
	GameState.is_lemon_carried = false


func _process(_delta: float) -> void:
	_readout.text = _describe()


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.physical_keycode:
		KEY_C:
			GameState.is_lemon_carried = not GameState.is_lemon_carried
		KEY_K:
			_pick_up_or_put_down()
		KEY_T:
			_toggle_tour()
		KEY_1:
			Engine.time_scale = 1.0
		KEY_2:
			Engine.time_scale = 0.5
		KEY_3:
			Engine.time_scale = 0.25
		KEY_Z:
			var one_to_one := _perspective.far_scale == 1.0 and _perspective.near_scale == 1.0
			var scales := _room_scales if one_to_one else Vector2.ONE
			_perspective.far_scale = scales.x
			_perspective.near_scale = scales.y
		_:
			return
	get_viewport().set_input_as_handled()


func _draw() -> void:
	draw_rect(get_viewport_rect(), Color(0.93, 0.92, 0.88))
	draw_rect(FLOOR, Color(0.86, 0.84, 0.79))
	var x := FLOOR.position.x
	while x <= FLOOR.end.x:
		var major := is_zero_approx(fmod(x - FLOOR.position.x, TICK * 4.0))
		draw_line(Vector2(x, FLOOR.position.y), Vector2(x, FLOOR.end.y), Color(0.55, 0.53, 0.5, 0.55 if major else 0.25), 1.0)
		x += TICK
	var y := FLOOR.position.y
	while y <= FLOOR.end.y:
		draw_line(Vector2(FLOOR.position.x, y), Vector2(FLOOR.end.x, y), Color(0.55, 0.53, 0.5, 0.25), 1.0)
		y += TICK


func _describe() -> String:
	var sprite := _art.get_node_or_null("Art") as AnimatedSprite2D
	var lines: PackedStringArray = []
	lines.append("state      %s" % _art.current_state())
	if sprite != null and sprite.visible:
		var frames := sprite.sprite_frames
		var animation := sprite.animation
		lines.append("animation  %s%s" % [animation, "  (mirrored)" if _art.scale.x < 0.0 else ""])
		lines.append("frame      %d / %d   (hold x%s)" % [sprite.frame + 1, frames.get_frame_count(animation),
				frames.get_frame_duration(animation, sprite.frame)])
		lines.append("fps        %s%s" % [frames.get_animation_speed(animation),
				"" if Engine.time_scale == 1.0 else "   (game at %d%%)" % roundi(Engine.time_scale * 100.0)])
	else:
		lines.append("animation  (placeholder blockout: no art)")
	lines.append("velocity   %s px/s   speed %d" % [stella.velocity.round(), roundi(stella.velocity.length())])
	lines.append("facing     %s" % ("right" if stella.facing > 0.0 else "left"))
	lines.append("scale      %.2f%s" % [_art.depth_scale, "  (1:1)" if _perspective.far_scale == 1.0 else ""])
	lines.append("carrying   %s" % ("yes" if GameState.is_lemon_carried else "no"))
	if not _tour_step.is_empty():
		lines.append("tour       %s" % _tour_step)
	return "\n".join(lines)


func _pick_up_or_put_down() -> void:
	if stella.is_performing():
		return
	if GameState.is_lemon_carried:
		await stella.perform(&"pickup_lemon_right", true)
		GameState.is_lemon_carried = false
	elif await stella.perform(&"pickup_lemon_right"):
		GameState.is_lemon_carried = true


func _toggle_tour() -> void:
	_tour_id += 1
	if not _tour_step.is_empty():
		_tour_step = ""
		stella.stop_walking()
		return
	_run_tour(_tour_id)


func _run_tour(id: int) -> void:
	var middle := Vector2(FLOOR.get_center().x, FLOOR.position.y + FLOOR.size.y * 0.6)
	var steps := [
		["carry off", null], ["idle", 2.0], ["walk right", Vector2(FLOOR.end.x - 80, middle.y)],
		["walk left", Vector2(FLOOR.position.x + 80, middle.y)], ["walk to middle", middle], ["idle", 1.0],
		["walk up", middle + Vector2(0, -110)], ["walk down", middle + Vector2(0, 80)], ["idle", 1.0],
		["carry on", null], ["carry idle", 2.0], ["carry walk right", Vector2(FLOOR.end.x - 80, middle.y)],
		["carry walk left", Vector2(FLOOR.position.x + 80, middle.y)], ["carry walk to middle", middle], ["carry idle", 1.0],
	]
	stella.walk_to(Vector2(FLOOR.position.x + 160, middle.y))
	_tour_step = "walk to start"
	await _walk_end()
	while id == _tour_id:
		for step: Array in steps:
			if id != _tour_id:
				return
			_tour_step = step[0]
			if step[0] == "carry on" or step[0] == "carry off":
				GameState.is_lemon_carried = step[0] == "carry on"
			elif step[1] is float:
				await get_tree().create_timer(step[1]).timeout
			elif stella.walk_to(step[1]):
				await _walk_end()


# Polled: Stella's walk_finished isn't emitted when she reaches the end of a path.
func _walk_end() -> void:
	while stella.is_walking():
		await get_tree().physics_frame
