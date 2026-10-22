class_name BedroomExit
extends RoomExit
## Bedroom departure requires the backpack and Lemon in Stella's arms.
func interact(actor: Node2D) -> void:
	# Gate the opening departure only: Lemon may legitimately wait elsewhere later.
	if GameState.has_flag(GameState.FLAG_BEDROOM_DEPARTED):
		super(actor)
		return
	if not GameState.has_backpack() and not GameState.is_lemon_carried:
		await DialogueManager.say(["I'll need my backpack and Lemon before I go.", "My backpack should be in the trunk."])
	elif not GameState.has_backpack():
		await DialogueManager.say(["Nearly ready. My backpack's still in the trunk."])
	elif not GameState.is_lemon_carried:
		await DialogueManager.say(["I'm not leaving without Lemon."])
	else:
		GameState.set_flag(GameState.FLAG_BEDROOM_DEPARTED)
		super(actor)
