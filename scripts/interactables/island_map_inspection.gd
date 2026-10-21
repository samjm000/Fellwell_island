extends Interactable
## Show the exploration map while Stella reads Grandad's existing map lines.
## DialogueManager owns the input lock and closes this observation as usual.

func interact(actor: Node2D) -> void:
	interacted.emit(actor)
	var view := CanvasLayer.new()
	view.name = "IslandMapView"
	view.layer = 10
	add_child(view)
	var backdrop := ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.025, 0.055, 0.075, 0.98)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.add_child(backdrop)
	var map := TextureRect.new()
	map.name = "Map"
	map.texture = load("res://art/backgrounds/island/map.png")
	map.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	map.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	map.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.add_child(map)
	map.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await DialogueManager.play(get_current_dialogue())
	view.queue_free()
