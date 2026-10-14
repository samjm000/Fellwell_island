extends Interactable
## Grandad's telescope. Opens a TelescopeView and decides what Stella makes of it.
##
## At night the view contains the unexplained offshore light; the first time she
## sees it a story flag is set so later puzzle threads can build on it.

@export var view_scene: PackedScene
@export var first_sighting_dialogue: DialogueSequence
@export var repeat_sighting_dialogue: DialogueSequence
## Gives the player a moment to take in the view before Stella comments.
@export var observation_delay: float = 1.2

var _view: TelescopeView = null


func can_interact(actor: Node2D) -> bool:
	return super(actor) and _view == null


func interact(actor: Node2D) -> void:
	interacted.emit(actor)
	var view: TelescopeView = view_scene.instantiate()
	_view = view
	add_child(view)
	view.closed.connect(_on_view_closed)

	await get_tree().create_timer(observation_delay).timeout
	if _view != view:
		return # Closed (or reopened) before Stella got a proper look.

	if view.is_offshore_light_visible():
		await _notice_offshore_light()
	else:
		await DialogueManager.play(get_current_dialogue())


func _notice_offshore_light() -> void:
	if GameState.has_seen_offshore_light():
		await DialogueManager.play(repeat_sighting_dialogue)
		return
	GameState.set_flag(GameState.FLAG_SEEN_OFFSHORE_LIGHT)
	await DialogueManager.play(first_sighting_dialogue)


func _on_view_closed() -> void:
	_view = null
