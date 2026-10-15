extends Node2D
## Stella's bedroom. Rooms only wire their own pieces together; behaviour lives in
## the reusable characters, interactables and UI they contain.

@onready var _point_and_click: PointAndClickInput = %PointAndClick
@onready var _interaction_prompt: Control = %InteractionPrompt


func _ready() -> void:
	_point_and_click.hovered_changed.connect(_interaction_prompt.set_target)
