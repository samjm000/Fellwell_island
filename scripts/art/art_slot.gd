class_name ArtSlot
extends Node2D
## A place for one piece of finished art, with a node-built placeholder until the
## art exists.
##
## If `texture_path` points at an image in the project it is shown as a Sprite2D and
## the `Placeholder` child is hidden; otherwise the placeholder stays. Paths are used
## rather than Texture2D exports so a scene never fails to load because an asset
## hasn't been delivered yet. An optional `night_texture_path` is swapped in when
## TimeManager changes phase.
##
## Art is positioned by `anchor` relative to this node's origin. Props and
## characters use BOTTOM_CENTER (origin at the floor contact point, which keeps
## Y-sorting correct); full-screen paintings use TOP_LEFT.

enum Anchor { TOP_LEFT, BOTTOM_CENTER, CENTER }

@export_file("*.png", "*.webp", "*.jpg", "*.svg") var texture_path: String = ""
@export_file("*.png", "*.webp", "*.jpg", "*.svg") var night_texture_path: String = ""
@export var anchor: Anchor = Anchor.BOTTOM_CENTER
## Extra offset in texture pixels, for nudging art onto its collision footprint.
@export var art_offset: Vector2 = Vector2.ZERO
## Painted art can be authored at a higher resolution and scaled down here.
@export var art_scale: Vector2 = Vector2.ONE
## Untick when another painting (e.g. the room background) already shows this
## object, so the placeholder doesn't draw on top of it.
@export var placeholder_enabled: bool = true

var _sprite: Sprite2D = null
var _day_texture: Texture2D = null
var _night_texture: Texture2D = null

@onready var _placeholder: CanvasItem = get_node_or_null("Placeholder")


func _ready() -> void:
	_day_texture = load_optional_texture(texture_path)
	_night_texture = load_optional_texture(night_texture_path)
	if _day_texture != null or _night_texture != null:
		_sprite = Sprite2D.new()
		_sprite.name = "Art"
		_sprite.centered = false
		_sprite.scale = art_scale
		add_child(_sprite)
		move_child(_sprite, 0)
	if _night_texture != null:
		TimeManager.phase_changed.connect(_on_phase_changed)
	_apply(TimeManager.current_phase)


## True when finished art (rather than the placeholder) is being shown.
func has_art() -> bool:
	return _sprite != null and _sprite.visible


static func load_optional_texture(path: String) -> Texture2D:
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D


static func anchor_offset(texture: Texture2D, anchor_mode: Anchor) -> Vector2:
	var size := texture.get_size()
	match anchor_mode:
		Anchor.BOTTOM_CENTER:
			return Vector2(-size.x * 0.5, -size.y)
		Anchor.CENTER:
			return -size * 0.5
		_:
			return Vector2.ZERO


func _apply(phase: GameTime.Phase) -> void:
	var texture := _day_texture
	if phase == GameTime.Phase.NIGHT and _night_texture != null:
		texture = _night_texture
	if _sprite != null:
		_sprite.texture = texture
		_sprite.visible = texture != null
		if texture != null:
			_sprite.offset = anchor_offset(texture, anchor) + art_offset
	if _placeholder != null:
		_placeholder.visible = placeholder_enabled and not has_art()


func _on_phase_changed(new_phase: GameTime.Phase, _previous_phase: GameTime.Phase) -> void:
	_apply(new_phase)
