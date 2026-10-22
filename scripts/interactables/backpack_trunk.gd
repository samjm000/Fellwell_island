class_name BackpackTrunk
extends Interactable
## Opening the trunk reveals the backpack; a separate interaction takes it.
func _ready() -> void:
	GameState.flag_changed.connect(_refresh)
	_refresh()

func _refresh(_flag: StringName = &"", _value: bool = false) -> void:
	interaction_name = "Trunk" if not GameState.has_flag(GameState.FLAG_TRUNK_OPEN) else "yellow backpack"
	interaction_prompt = "Open" if not GameState.has_flag(GameState.FLAG_TRUNK_OPEN) else "Take"
	if GameState.has_backpack():
		interaction_name = "Trunk"
		interaction_prompt = "Look inside"
	queue_redraw()

func interact(actor: Node2D) -> void:
	interacted.emit(actor)
	if not GameState.has_flag(GameState.FLAG_TRUNK_OPEN):
		GameState.set_flag(GameState.FLAG_TRUNK_OPEN)
		await DialogueManager.say(["There it is! My yellow backpack.", "Room for everything an adventure might require. Except a wardrobe."])
	elif not GameState.has_backpack():
		GameState.set_flag(GameState.FLAG_BACKPACK)
		await DialogueManager.say(["Backpack on. Now we're getting somewhere."])
	else:
		await DialogueManager.say(["Nothing else I need in here."])

func _draw() -> void:
	if not GameState.has_flag(GameState.FLAG_TRUNK_OPEN):
		return
	# Small prototype overlay over the painted lid. Replace with painted open art.
	draw_colored_polygon(PackedVector2Array([Vector2(-160,-118),Vector2(32,-122),Vector2(20,-178),Vector2(-155,-173)]), Color("684126"))
	draw_rect(Rect2(-151,-163,168,31),Color("b27b45"))
	draw_colored_polygon(PackedVector2Array([Vector2(-155,-118),Vector2(30,-122),Vector2(25,-95),Vector2(-151,-89)]),Color("2c211d"))
	if not GameState.has_backpack():
		draw_style_box(_bag_style(),Rect2(-100,-157,62,66))
		for i in 5:
			draw_circle(Vector2(-70,-126)+Vector2.from_angle(i*TAU/5)*9,6,Color("5498bd"))
		draw_circle(Vector2(-70,-126),4,Color("f9d871"))

func _bag_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("e8b648")
	style.set_corner_radius_all(14)
	style.border_color = Color("956226")
	style.set_border_width_all(2)
	return style
