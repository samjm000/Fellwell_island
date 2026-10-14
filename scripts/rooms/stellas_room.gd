extends Node2D
## Stella's bedroom. Rooms only wire their own pieces together; behaviour lives in
## the reusable characters, interactables and UI they contain.

@onready var _stella: Stella = %Stella
@onready var _interaction_prompt: Control = %InteractionPrompt


func _ready() -> void:
	_stella.focused_interactable_changed.connect(_interaction_prompt.set_target)
