class_name Interactable
extends Area2D
## Base class for anything Stella can interact with.
##
## Point and click, all authored in the editor per instance:
##   - a `Hotspot` child (an Area2D holding CollisionPolygon2D / CollisionShape2D
##     children) is the clickable, hoverable area over the painted object;
##   - an `ApproachPoint` child (a Marker2D) is where Stella walks to before using
##     it; without one she walks to this node's origin;
##   - `interaction_radius` is how close her feet must get to that point, and
##     `approach_facing` which way she turns on arrival.
## Objects without a Hotspot can't be clicked.
##
## The Area2D's own collision shape is the "reach" zone used by the debug keyboard
## controls: an InteractionDetector that overlaps it can focus and trigger this
## object. By default interacting plays the object's DialogueSequence, which covers
## simple observations without any script. Subclasses override `interact()` (and
## optionally `can_interact()` / `get_prompt_text()`) for custom behaviour.

## Emitted when the prompt text or availability changes, so an open prompt can refresh.
signal prompt_changed
signal interacted(actor: Node2D)

enum Facing { TOWARD_HOTSPOT, LEFT, RIGHT }

const GROUP := &"interactables"

## Display name, e.g. "Telescope".
@export var interaction_name: String = "Thing":
	set(value):
		interaction_name = value
		prompt_changed.emit()
## Verb shown before the name in the prompt, e.g. "Look at", "Pick up".
@export var interaction_prompt: String = "Look at":
	set(value):
		interaction_prompt = value
		prompt_changed.emit()
## When several interactables are in reach, the highest priority wins; ties go to the nearest.
@export var interaction_priority: int = 0
@export var enabled: bool = true:
	set(value):
		enabled = value
		prompt_changed.emit()
## Where the prompt appears, relative to this node's origin.
@export var prompt_offset: Vector2 = Vector2(0, -140)
## Played by the InteractionDetector when this is used. Empty for objects that
## play their own sounds.
@export var interaction_sfx: StringName = &"interact"

@export_group("Point and click")
## Stella uses this once her feet are within this distance of the approach point.
@export var interaction_radius: float = 24.0
## Which way Stella faces on arrival.
@export var approach_facing: Facing = Facing.TOWARD_HOTSPOT
## Where hotspots overlap, the higher value is hovered and clicked.
@export var hotspot_priority: int = 0

@export_group("Dialogue")
## Played when interacted with (unless a subclass overrides `interact()`).
@export var dialogue: DialogueSequence
## Optional night-time alternative; falls back to `dialogue` when unset.
@export var night_dialogue: DialogueSequence


@onready var _hotspot: Node2D = get_node_or_null("Hotspot")
@onready var _approach_point: Node2D = get_node_or_null("ApproachPoint")


func _enter_tree() -> void:
	add_to_group(GROUP)


func can_interact(_actor: Node2D) -> bool:
	return enabled


func get_prompt_text() -> String:
	return "%s %s" % [interaction_prompt, interaction_name]


func get_prompt_position() -> Vector2:
	return global_position + prompt_offset


## Uses this object if it's available, with its interaction sound. Returns false
## if it couldn't be used.
func trigger(actor: Node2D) -> bool:
	if not can_interact(actor):
		return false
	AudioManager.play_sfx(interaction_sfx)
	interact(actor)
	return true


func interact(actor: Node2D) -> void:
	interacted.emit(actor)
	await DialogueManager.play(get_current_dialogue())


func get_approach_position() -> Vector2:
	return _approach_point.global_position if _approach_point != null else global_position


## -1.0 (left) or 1.0 (right) for an actor standing at `from`.
func get_facing_for(from: Vector2) -> float:
	match approach_facing:
		Facing.LEFT:
			return -1.0
		Facing.RIGHT:
			return 1.0
		_:
			return -1.0 if get_hotspot_center().x < from.x else 1.0


func has_hotspot() -> bool:
	return _hotspot != null and _hotspot.visible


func hotspot_contains(world_point: Vector2) -> bool:
	if not has_hotspot():
		return false
	for shape_node in _hotspot.get_children():
		if _shape_contains(shape_node, world_point):
			return true
	return false


## The middle of the hotspot's bounds (or this node's origin without a hotspot).
func get_hotspot_center() -> Vector2:
	var bounds := _hotspot_bounds()
	return bounds.get_center() if bounds.has_area() else global_position


func _hotspot_bounds() -> Rect2:
	var corners := PackedVector2Array()
	if _hotspot != null:
		for shape_node in _hotspot.get_children():
			var local_points := PackedVector2Array()
			if shape_node is CollisionPolygon2D:
				local_points = shape_node.polygon
			elif shape_node is CollisionShape2D and shape_node.shape != null:
				var rect: Rect2 = shape_node.shape.get_rect()
				local_points = [rect.position, rect.end]
			for point in local_points:
				corners.append(shape_node.global_transform * point)
	if corners.is_empty():
		return Rect2()
	var bounds := Rect2(corners[0], Vector2.ZERO)
	for corner in corners:
		bounds = bounds.expand(corner)
	return bounds


static func _shape_contains(shape_node: Node, world_point: Vector2) -> bool:
	if shape_node is CollisionPolygon2D:
		var polygon := shape_node as CollisionPolygon2D
		return not polygon.disabled and Geometry2D.is_point_in_polygon(
				polygon.global_transform.affine_inverse() * world_point, polygon.polygon)
	if shape_node is CollisionShape2D:
		var collision := shape_node as CollisionShape2D
		if collision.disabled or collision.shape == null:
			return false
		var local := collision.global_transform.affine_inverse() * world_point
		if collision.shape is CircleShape2D:
			return local.length() <= (collision.shape as CircleShape2D).radius
		return collision.shape.get_rect().has_point(local)
	return false


## Picks lines for the current world state. Subclasses can override for richer
## conditions (story flags, items carried...).
func get_current_dialogue() -> DialogueSequence:
	if TimeManager.is_night() and night_dialogue != null:
		return night_dialogue
	return dialogue
