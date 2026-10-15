extends "res://tests/framework/test_case.gd"
## The bed: protest, admit tiredness, choose, and sleep from DAY into NIGHT.

const NOT_TIRED := "I'm not tired."
const SLIGHTLY_TIRED := "I am slightly tired."
const SLEEP_QUESTION := "Go to sleep?"
const FALL_ASLEEP := "Fine. But only because Lemon's exhausted."
const AWAKE_AT_NIGHT := "I'm wide awake now."


func test_bed_progression() -> void:
	var bed := interactable("Bed")

	await interact_with(bed)
	check(saw_line(NOT_TIRED), "first use: Stella protests")
	await advance_dialogue()
	check(not saw_line(SLEEP_QUESTION), "first use does not offer sleep")
	check(TimeManager.is_phase(GameTime.Phase.DAY), "still DAY after protesting")

	lines_seen.clear()
	await interact_with(bed)
	check(saw_line(SLIGHTLY_TIRED), "second use: Stella admits she's slightly tired")
	await advance_dialogue()
	check(DialogueManager.is_choosing(), "the sleep question is asked")
	check(saw_line(SLEEP_QUESTION), "the question reads 'Go to sleep?'")

	await choose_option(1) # "Not yet"
	await wait_frames(2)
	check(not DialogueManager.is_active(), "declining closes the dialogue")
	check(TimeManager.is_phase(GameTime.Phase.DAY), "still DAY after declining")
	check(PlayerControl.has_control(), "control returns after declining")


func test_sleep_changes_day_to_night() -> void:
	var bed := interactable("Bed")
	await interact_with(bed)
	await advance_dialogue()
	await interact_with(bed)
	await advance_dialogue()

	await choose_option(0) # "Yes"
	check(await wait_until(func() -> bool: return saw_line(FALL_ASLEEP), 3.0, "the fall-asleep line"), "Stella agrees to sleep")
	await advance_dialogue()
	check(await wait_until(func() -> bool: return not PlayerControl.has_control(), 2.0, "the sleep lock"),
			"control is locked while falling asleep")
	check(await wait_until(TimeManager.is_night, 5.0, "NIGHT"), "sleeping changes the time to NIGHT")
	check(await wait_until(PlayerControl.has_control, 5.0, "control after waking"), "control returns after the fade")

	lines_seen.clear()
	await interact_with(bed)
	check(saw_line(AWAKE_AT_NIGHT), "at night the bed has its night line")
	await advance_dialogue()
	check(not saw_line(SLEEP_QUESTION), "no sleep question at night")
	check(TimeManager.is_night(), "still NIGHT")
