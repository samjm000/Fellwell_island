class_name Interactable
extends Area2D
## Base class for anything Stella can interact with.
##
## The Area2D's collision shape is the "reach" zone: an InteractionDetector that
## overlaps it can focus and trigger this object. Subclasses override `interact()`
## (and optionally `can_interact()` / `get_prompt_text()`) for custom behaviour.

## Emitted when the prompt text or availability changes, so an open prompt can refresh.
signal prompt_changed
signal interacted(actor: Node2D)

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


func can_interact(_actor: Node2D) -> bool:
	return enabled


func get_prompt_text() -> String:
	return "%s %s" % [interaction_prompt, interaction_name]


func get_prompt_position() -> Vector2:
	return global_position + prompt_offset


func interact(actor: Node2D) -> void:
	interacted.emit(actor)
	print("Interacted with %s" % interaction_name)
