class_name BackpackUI
extends CanvasLayer
## Room-local presentation of Stella's persistent inventory. I or the button opens it.
var is_open := false
var button: Button
var panel: PanelContainer
var contents: VBoxContainer
var detail: Label

func _ready() -> void:
	layer = 15
	button = Button.new()
	button.text = "Backpack  [I]"
	button.position = Vector2(1080, 24)
	button.size = Vector2(176, 48)
	button.modulate = Color("ffe09a")
	button.pressed.connect(toggle)
	add_child(button)
	panel = PanelContainer.new()
	panel.position = Vector2(325, 155)
	panel.size = Vector2(630, 410)
	add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 26)
	panel.add_child(margin)
	contents = VBoxContainer.new()
	contents.add_theme_constant_override("separation", 15)
	margin.add_child(contents)
	GameState.flag_changed.connect(_refresh)
	GameState.inventory_changed.connect(_inventory_changed)
	PlayerControl.control_changed.connect(_control_changed)
	_refresh()
	panel.hide()

func _refresh(_flag: StringName = &"", _value: bool = false) -> void:
	button.visible = GameState.has_backpack()
	if not button.visible and is_open:
		close()

func _inventory_changed(_character: StringName) -> void:
	if is_open:
		_rebuild()

func _control_changed(has_control: bool) -> void:
	button.disabled = not has_control and not is_open

func _input(event: InputEvent) -> void:
	if event.is_action_pressed(&"inventory") and not event.is_echo():
		toggle()
		get_viewport().set_input_as_handled()
	elif is_open and event.is_action_pressed(&"ui_cancel"):
		close()
		get_viewport().set_input_as_handled()

func toggle() -> void:
	if is_open:
		close()
	elif GameState.has_backpack() and PlayerControl.has_control():
		is_open = true
		PlayerControl.acquire(&"inventory")
		_rebuild()
		panel.show()

func close() -> void:
	is_open = false
	panel.hide()
	PlayerControl.release(&"inventory")

func _exit_tree() -> void:
	PlayerControl.release(&"inventory")

func _rebuild() -> void:
	for child in contents.get_children():
		contents.remove_child(child)
		child.queue_free()
	var title := Label.new()
	title.text = "STELLA'S BACKPACK"
	title.add_theme_font_size_override("font_size", 27)
	contents.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "A little room for a big adventure."
	contents.add_child(subtitle)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 150
	contents.add_child(scroll)
	var items := VBoxContainer.new()
	items.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(items)
	var owned := GameState.inventory_items(&"stella")
	if owned.is_empty():
		var empty := Label.new()
		empty.text = "Empty for now. Let's see what the island has in store."
		items.add_child(empty)
	for item: InventoryItem in owned:
		var entry := Button.new()
		entry.text = item.display_name
		entry.icon = item.icon
		entry.pressed.connect(func() -> void: detail.text = item.description)
		items.add_child(entry)
	detail = Label.new()
	detail.custom_minimum_size = Vector2(550, 65)
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	contents.add_child(detail)
	var done := Button.new()
	done.text = "Close backpack"
	done.pressed.connect(close)
	contents.add_child(done)
