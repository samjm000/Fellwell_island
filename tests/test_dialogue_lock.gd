extends "res://tests/framework/test_case.gd"
## Dialogue takes control away from Stella and gives it back afterwards.


func test_dialogue_blocks_player_control() -> void:
	var window := interactable("Window")
	await interact_with(window)
	check(DialogueManager.is_active(), "looking at the window opens dialogue")
	check(not PlayerControl.has_control(), "control is locked during dialogue")

	var start := stella.global_position
	await hold(&"move_left", 30)
	check_near(stella.global_position, start, 0.5, "keyboard movement is ignored during dialogue")

	await advance_dialogue()
	check(not DialogueManager.is_active(), "dialogue closes")
	check(PlayerControl.has_control(), "control returns after dialogue")


func test_overlapping_locks() -> void:
	# Control only returns once every system has released its lock.
	PlayerControl.acquire(&"test_a")
	PlayerControl.acquire(&"test_b")
	PlayerControl.release(&"test_a")
	check(not PlayerControl.has_control(), "one lock still held")
	PlayerControl.release(&"test_b")
	check(PlayerControl.has_control(), "control returns when all locks are released")
