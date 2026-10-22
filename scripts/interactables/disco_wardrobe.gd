class_name DiscoWardrobe
extends Interactable
## Optional discovery; the mouse's story interaction is deliberately reserved.
func interact(actor: Node2D) -> void:
	interacted.emit(actor)
	GameState.set_flag(GameState.FLAG_MOUSE_DISCOVERED)
	var view := WardrobeView.new()
	get_tree().current_scene.add_child(view)
