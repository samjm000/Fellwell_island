class_name CharacterArt
extends Node2D
## Chooses how a character looks for its current state: idle or walking, with or
## without Lemon in her arms. Gameplay scripts only set `is_moving`, `is_carrying`
## and `facing`; they never touch sprites.
##
## Art sources, in order of preference:
##   1. `sprite_frames` authored in the editor (animation names = state names).
##   2. Images in `art_directory`, either one folder per state with numbered frames
##      (`idle/frame_0001.png`, `walk/frame_0001.png` ...; the art pack's layout) or
##      flat files (`idle.png`, or `walk_0.png`, `walk_1.png` ...).
##   3. The node-built `Placeholder` child.
## Missing states fall back (carry_walk -> carry_idle -> walk -> idle), so a single
## idle image is enough to replace the placeholder. Until walk frames exist, the
## still is given a small walking bob (never stretched or deformed).
##
## When the chosen animation isn't a carry_* one, `carried_overlay` (e.g. a Lemon
## sprite at the arms) is shown on top while carrying.

const STATES: Array[StringName] = [&"idle", &"walk", &"carry_idle", &"carry_walk"]
const FALLBACKS := {
	&"idle": [&"idle"],
	&"walk": [&"walk", &"idle"],
	&"carry_idle": [&"carry_idle", &"idle"],
	&"carry_walk": [&"carry_walk", &"carry_idle", &"walk", &"idle"],
}
const IMAGE_EXTENSIONS: Array[String] = ["png", "webp"]
const MAX_FRAMES_PER_STATE := 32

@export var sprite_frames: SpriteFrames
@export_dir var art_directory: String = ""
## Used for animations built from `art_directory`.
@export var frames_per_second: float = 8.0
## Painted art can be authored at a higher resolution and scaled down here.
@export var art_scale: Vector2 = Vector2.ONE
## Nudge in texture pixels so the feet sit on the origin (canvases often have a
## margin below the boots or an off-centre figure).
@export var art_offset: Vector2 = Vector2.ZERO
## Shown while carrying, unless the art itself includes what's being carried.
@export var carried_overlay: CanvasItem
## Bob height (pixels) while walking without walk frames: the placeholder, or a
## still standing in for missing walk art.
@export var walk_bob_height: float = 3.0

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
## 1.0 faces right, -1.0 faces left. Art is authored facing right.
var facing: float = 1.0:
	set(value):
		facing = value
		scale.x = facing

var _sprite: AnimatedSprite2D = null
var _bob_time: float = 0.0

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
		_sprite.scale = art_scale
		add_child(_sprite)
		move_child(_sprite, 0)
	_refresh()


func current_state() -> StringName:
	if is_carrying:
		return &"carry_walk" if is_moving else &"carry_idle"
	return &"walk" if is_moving else &"idle"


## The animation actually playing ("" while the placeholder is shown).
func shown_animation() -> StringName:
	return _sprite.animation if _sprite != null and _sprite.visible else &""


func _process(delta: float) -> void:
	# Real walk frames animate themselves; otherwise bob whatever is showing.
	var bob_target: Node2D = null
	if _placeholder != null and _placeholder.visible:
		bob_target = _placeholder
	elif _sprite != null and _sprite.visible and not String(_sprite.animation).ends_with("walk"):
		bob_target = _sprite
	if bob_target == null:
		return
	if is_moving:
		_bob_time += delta
		bob_target.position.y = -absf(sin(_bob_time * 11.0)) * walk_bob_height
	else:
		_bob_time = 0.0
		bob_target.position.y = 0.0


func _refresh() -> void:
	if not is_node_ready():
		return
	var animation := _resolve_animation(current_state())
	var showing_art := animation != &""
	if showing_art:
		if _sprite.animation != animation or not _sprite.is_playing():
			_sprite.play(animation)
		var first_frame := _sprite.sprite_frames.get_frame_texture(animation, 0)
		_sprite.offset = ArtSlot.anchor_offset(first_frame, ArtSlot.Anchor.BOTTOM_CENTER) + art_offset
	if _sprite != null:
		_sprite.visible = showing_art
	if _placeholder != null:
		_placeholder.visible = not showing_art
	if carried_overlay != null:
		var art_includes_carry := showing_art and String(animation).begins_with("carry")
		carried_overlay.visible = is_carrying and not art_includes_carry


func _resolve_animation(state: StringName) -> StringName:
	if _sprite == null:
		return &""
	for candidate: StringName in FALLBACKS[state]:
		if _sprite.sprite_frames.has_animation(candidate) and _sprite.sprite_frames.get_frame_count(candidate) > 0:
			return candidate
	return &""


func _build_frames_from_directory(directory: String) -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	for state in STATES:
		var textures := _find_state_textures(directory.path_join(String(state)))
		if textures.is_empty():
			continue
		frames.add_animation(state)
		frames.set_animation_speed(state, frames_per_second)
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
