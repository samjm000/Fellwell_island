class_name CharacterArt
extends Node2D
## Chooses how a character looks for its current state: idle or walking (left or
## right), with or without Lemon in her arms. Gameplay scripts only set
## `is_moving`, `is_carrying` and `facing`; they never touch sprites.
##
## States: idle, walk_left, walk_right, carry_idle, carry_walk_left,
## carry_walk_right. Art sources, in order of preference:
##   1. `sprite_frames` authored in the editor (animation names = state names).
##   2. Images in `art_directory`, either one folder per state with numbered frames
##      (`idle/frame_0001.png`, `walk_right/frame_0001.png` ...; the art pack's
##      layout) or flat files (`idle.png`, or `walk_right_0.png`, `walk_right_1.png` ...).
##   3. The node-built `Placeholder` child.
##
## Missing states fall back gracefully. A walk in one direction can be mirrored
## from the other, or from an undirected `walk` / `carry_walk` cycle (authored
## facing right); with no walk frames at all the matching still (idle or
## carry_idle) is shown with a small walking bob, never stretched or deformed. The
## bob switches off by itself once real walk frames are installed.
##
## When the chosen animation isn't a carry_* one, `carried_overlay` (e.g. a Lemon
## sprite at the arms) is shown on top while carrying.
##
## Animations may also be named `<state>_right` (idle_right, walk_right,
## carry_idle_right, carry_walk_right: Stella's SpriteFrames), authored facing
## right and mirrored for left. One-shot actions (e.g. pickup_lemon_right) are
## played with `play_action()`: they hold the sprite until they finish, report
## each frame through `action_frame` (for timing gameplay to the art), then hand
## back to the state animations.
##
## A `walk_rig` (a procedural walk such as StellaCutoutRig) replaces the walk
## frames while moving, carrying or not; standing and actions still use frames.

signal action_frame(animation: StringName, frame: int)
signal action_finished(animation: StringName)

const STATES: Array[StringName] = [
	&"idle", &"walk_left", &"walk_right", &"walk",
	&"carry_idle", &"carry_walk_left", &"carry_walk_right", &"carry_walk",
]
## Animations authored facing left; everything else faces right.
const FACES_LEFT: Array[StringName] = [&"walk_left", &"carry_walk_left"]
## What shown_animation() reports while the walk rig is shown.
const WALK_RIG := &"walk_rig"
const CARRY_WALK_RIG := &"carry_walk_rig"
## Candidates for each state, best first.
const FALLBACKS := {
	&"idle": [&"idle", &"idle_right"],
	&"walk_left": [&"walk_left", &"walk_right", &"walk", &"idle", &"idle_right"],
	&"walk_right": [&"walk_right", &"walk_left", &"walk", &"idle", &"idle_right"],
	&"carry_idle": [&"carry_idle", &"carry_idle_right", &"idle", &"idle_right"],
	&"carry_walk_left": [&"carry_walk_left", &"carry_walk_right", &"carry_walk", &"carry_idle", &"carry_idle_right",
			&"walk_left", &"walk_right", &"walk", &"idle", &"idle_right"],
	&"carry_walk_right": [&"carry_walk_right", &"carry_walk_left", &"carry_walk", &"carry_idle", &"carry_idle_right",
			&"walk_right", &"walk_left", &"walk", &"idle", &"idle_right"],
}
const IMAGE_EXTENSIONS: Array[String] = ["png", "webp"]
const MAX_FRAMES_PER_STATE := 32

@export var sprite_frames: SpriteFrames
@export_dir var art_directory: String = ""
## Walk cycles built from `art_directory` play at this rate.
@export var frames_per_second: float = 8.0
## Idle loops (breathing, blinking) built from `art_directory` play at this rate.
@export var idle_frames_per_second: float = 4.0
## Painted art can be authored at a higher resolution and scaled down here.
@export var art_scale: Vector2 = Vector2.ONE
## Nudge in texture pixels so the feet sit on the origin (canvases often have a
## margin below the boots or an off-centre figure).
@export var art_offset: Vector2 = Vector2.ZERO
## Shown instead of walk frames while moving. Needs `advance(distance, delta)`
## (distance in its own units, 0 to stand) and `carrying`; authored facing right
## with its origin at the feet.
@export var walk_rig: Node2D
## Shown while carrying, unless the art itself includes what's being carried.
@export var carried_overlay: CanvasItem
## Bob height (pixels) while walking without walk frames: the placeholder, or a
## still standing in for missing walk art.
@export var walk_bob_height: float = 3.0
## Perspective scale for where the character stands in the room (1.0 = as
## authored). Scales about the feet, together with the carried overlay.
@export var depth_scale: float = 1.0:
	set(value):
		depth_scale = value
		_apply_scale()

var is_moving: bool = false:
	set(value):
		if value != is_moving:
			is_moving = value
			_refresh()
var is_carrying: bool = false:
	set(value):
		if value != is_carrying:
			is_carrying = value
			_refresh()
## 1.0 faces right, -1.0 faces left.
var facing: float = 1.0:
	set(value):
		if value != facing:
			facing = value
			_apply_scale()
			_refresh()

var _sprite: AnimatedSprite2D = null
var _bob_time: float = 0.0
## The one-shot action playing, or "".
var _action: StringName = &""
## Where the character was last physics tick, for the distance fed to walk_rig.
var _last_position := Vector2.INF

@onready var _placeholder: Node2D = get_node_or_null("Placeholder")


func _ready() -> void:
	var frames := sprite_frames
	if frames == null and not art_directory.is_empty():
		frames = _build_frames_from_directory(art_directory)
	if frames != null:
		_sprite = AnimatedSprite2D.new()
		_sprite.name = "Art"
		_sprite.sprite_frames = frames
		_sprite.centered = false
		add_child(_sprite)
		move_child(_sprite, 0)
		_sprite.frame_changed.connect(_on_sprite_frame_changed)
		_sprite.animation_finished.connect(_on_sprite_animation_finished)
	_apply_scale()
	_refresh()


func has_animation(animation: StringName) -> bool:
	return _sprite != null and _sprite.sprite_frames.has_animation(animation) \
			and _sprite.sprite_frames.get_frame_count(animation) > 0


## Plays a one-shot animation (forwards, or backwards, e.g. a pickup reversed as a
## put-down). Returns false if the art has no such animation. Await
## `action_finished` for the end.
func play_action(animation: StringName, backwards: bool = false) -> bool:
	if not has_animation(animation):
		return false
	_action = animation
	if backwards:
		_sprite.play_backwards(animation)
	else:
		_sprite.play(animation)
	_place_sprite(animation)
	_sprite.visible = true
	_sprite.position.y = 0.0
	if walk_rig != null:
		walk_rig.visible = false
	if _placeholder != null:
		_placeholder.visible = false
	if carried_overlay != null:
		carried_overlay.visible = false # Actions involving Lemon draw her themselves.
	return true


func is_playing_action() -> bool:
	return _action != &""


func current_state() -> StringName:
	var direction := "left" if facing < 0.0 else "right"
	if is_carrying:
		return StringName("carry_walk_" + direction) if is_moving else &"carry_idle"
	return StringName("walk_" + direction) if is_moving else &"idle"


## The animation actually playing ("" while the placeholder is shown).
func shown_animation() -> StringName:
	if walk_rig != null and walk_rig.visible:
		return CARRY_WALK_RIG if is_carrying else WALK_RIG
	return _sprite.animation if _sprite != null and _sprite.visible else &""


## True while walking is shown by bobbing a still rather than by walk frames.
func is_bobbing_still() -> bool:
	if not is_moving or is_playing_action():
		return false
	if _placeholder != null and _placeholder.visible:
		return true
	return _sprite != null and _sprite.visible and not _is_walk_cycle(_sprite.animation)


func _process(delta: float) -> void:
	var bob_target: Node2D = _placeholder if _placeholder != null and _placeholder.visible else _sprite
	if bob_target == null:
		return
	if is_bobbing_still():
		_bob_time += delta
		bob_target.position.y = -absf(sin(_bob_time * 11.0)) * walk_bob_height
	else:
		_bob_time = 0.0
		bob_target.position.y = 0.0


# After the character has moved (parents run their physics first): the rig walks
# exactly as far as she did, so its planted foot stays put on the floor.
func _physics_process(delta: float) -> void:
	if walk_rig == null:
		return
	var moved := 0.0 if _last_position == Vector2.INF else global_position.distance_to(_last_position)
	_last_position = global_position
	var rig_scale := absf(walk_rig.global_scale.x)
	walk_rig.advance(moved / rig_scale if walk_rig.visible and rig_scale > 0.0 else 0.0, delta)


func _refresh() -> void:
	if not is_node_ready() or is_playing_action():
		return
	var use_rig := walk_rig != null and is_moving
	if walk_rig != null:
		walk_rig.visible = use_rig
		walk_rig.carrying = is_carrying
	var animation := &"" if use_rig else _resolve_animation(current_state())
	var showing_art := animation != &""
	if showing_art:
		if _sprite.animation != animation or not _sprite.is_playing():
			_sprite.play(animation)
		_place_sprite(animation)
	if _sprite != null:
		_sprite.visible = showing_art
		_sprite.position.y = 0.0
	if _placeholder != null:
		_placeholder.visible = not showing_art and not use_rig
		_placeholder.position.y = 0.0
	if carried_overlay != null:
		var art_includes_carry := use_rig or (showing_art and String(animation).begins_with("carry"))
		carried_overlay.visible = is_carrying and not art_includes_carry


func _place_sprite(animation: StringName) -> void:
	var first_frame := _sprite.sprite_frames.get_frame_texture(animation, 0)
	_sprite.offset = ArtSlot.anchor_offset(first_frame, ArtSlot.Anchor.BOTTOM_CENTER) + art_offset
	_apply_scale()


func _on_sprite_frame_changed() -> void:
	if is_playing_action() and _sprite.animation == _action:
		action_frame.emit(_action, _sprite.frame)


func _on_sprite_animation_finished() -> void:
	if not is_playing_action():
		return
	var finished := _action
	_action = &""
	_refresh()
	action_finished.emit(finished)


# The whole node mirrors with `facing` (so the placeholder and carried overlay
# follow); art authored facing left is mirrored back inside it.
func _apply_scale() -> void:
	scale = Vector2(facing * depth_scale, depth_scale)
	if _sprite != null:
		var authored_left := FACES_LEFT.has(_sprite.animation)
		_sprite.scale = Vector2(art_scale.x * (-1.0 if authored_left else 1.0), art_scale.y)
	if walk_rig != null:
		walk_rig.scale = art_scale


func _resolve_animation(state: StringName) -> StringName:
	if _sprite == null:
		return &""
	for candidate: StringName in FALLBACKS[state]:
		if _sprite.sprite_frames.has_animation(candidate) and _sprite.sprite_frames.get_frame_count(candidate) > 0:
			return candidate
	return &""


static func _is_walk_cycle(animation: StringName) -> bool:
	return String(animation).contains("walk")


func _build_frames_from_directory(directory: String) -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	for state in STATES:
		var textures := _find_state_textures(directory.path_join(String(state)))
		if textures.is_empty():
			continue
		frames.add_animation(state)
		frames.set_animation_speed(state, frames_per_second if _is_walk_cycle(state) else idle_frames_per_second)
		frames.set_animation_loop(state, true)
		for texture in textures:
			frames.add_frame(state, texture)
	return frames if not frames.get_animation_names().is_empty() else null


# ResourceLoader.exists() is used instead of listing the directory because it also
# works in exported builds, where source images are remapped.
func _find_state_textures(base_path: String) -> Array[Texture2D]:
	var textures: Array[Texture2D] = []
	# Folder per state: <state>/frame_0001.png, frame_0002.png ...
	for extension in IMAGE_EXTENSIONS:
		for index in range(1, MAX_FRAMES_PER_STATE + 1):
			var frame := ArtSlot.load_optional_texture(base_path.path_join("frame_%04d.%s" % [index, extension]))
			if frame == null:
				break
			textures.append(frame)
		if not textures.is_empty():
			return textures
	# Flat files: <state>.png, or <state>_0.png, <state>_1.png ...
	for extension in IMAGE_EXTENSIONS:
		var still := ArtSlot.load_optional_texture("%s.%s" % [base_path, extension])
		if still != null:
			textures.append(still)
			return textures
		for index in MAX_FRAMES_PER_STATE:
			var frame := ArtSlot.load_optional_texture("%s_%d.%s" % [base_path, index, extension])
			if frame == null:
				break
			textures.append(frame)
		if not textures.is_empty():
			return textures
	return textures
