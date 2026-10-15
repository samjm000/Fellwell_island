extends "res://tests/framework/test_case.gd"
## The telescope view by day and by night, the offshore light and its story flag.

const DAY_LINE := "Grandad said you could see everything from here."
const FIRST_SIGHTING := "...That's not the lighthouse."
const REPEAT_SIGHTING := "It's still there."


func open_view() -> TelescopeView:
	await interact_with(interactable("Telescope"))
	await wait_frames(2)
	var view := find_view()
	check(view != null, "the telescope view opens")
	return view


## Closes the view before Stella comments, then waits out the comment delay.
func close_early(view: TelescopeView) -> void:
	view.close()
	await wait_seconds(1.5)
	check(not DialogueManager.is_active(), "no comment after closing early")


func find_view() -> TelescopeView:
	for child in interactable("Telescope").get_children():
		if child is TelescopeView and not child.is_queued_for_deletion():
			return child
	return null


func test_daytime_telescope() -> void:
	var view := await open_view()
	if view == null:
		return
	check(not PlayerControl.has_control(), "the view takes control from Stella")
	check(view.get_node("%DayView").visible, "day view shows by day")
	check(not view.get_node("%NightView").visible, "night view is hidden by day")
	check(not view.is_offshore_light_visible(), "no offshore light by day")

	check(await wait_for_dialogue(), "Stella comments on the day view")
	check(saw_line(DAY_LINE), "day observation line")
	await advance_dialogue()
	check(not GameState.has_seen_offshore_light(), "daytime viewing does not set the story flag")
	await press(&"ui_cancel")
	await wait_frames(2)


func test_nighttime_telescope_and_story_flag() -> void:
	await load_room(GameTime.Phase.NIGHT)
	check(not GameState.has_seen_offshore_light(), "flag starts unset")
	var view := await open_view()
	if view == null:
		return
	check(view.get_node("%NightView").visible, "night view shows at night")
	check(not view.get_node("%DayView").visible, "day view is hidden at night")
	check(view.is_offshore_light_visible(), "the offshore light is visible at night")

	check(await wait_for_dialogue(), "Stella reacts to the light")
	check(saw_line(FIRST_SIGHTING), "first sighting line")
	check(GameState.has_flag(&"seen_offshore_light"), "seen_offshore_light is set")
	await advance_dialogue()
	await press(&"ui_cancel")
	await wait_frames(2)

	lines_seen.clear()
	view = await open_view()
	if view == null:
		return
	check(await wait_for_dialogue(), "Stella reacts again")
	check(saw_line(REPEAT_SIGHTING), "repeat sighting line")
	check(not saw_line(FIRST_SIGHTING), "first sighting line is not repeated")
	check(GameState.has_seen_offshore_light(), "flag stays set")
	await advance_dialogue()
	await press(&"ui_cancel")
	await wait_frames(2)


func test_offshore_light_only_at_night() -> void:
	var view := await open_view()
	if view == null:
		return
	check(not view.is_offshore_light_visible(), "no offshore light by day")
	await close_early(view)

	TimeManager.set_phase(GameTime.Phase.NIGHT)
	view = await open_view()
	if view == null:
		return
	check(view.is_offshore_light_visible(), "offshore light at night")
	await close_early(view)
	check(not GameState.has_seen_offshore_light(), "closing before Stella looks properly doesn't set the flag")


func test_telescope_exit() -> void:
	var view := await open_view()
	if view == null:
		return
	# Leaving before Stella comments: no dialogue should follow.
	await press(&"ui_cancel")
	await wait_frames(2)
	check(find_view() == null, "cancel closes the view")
	check(PlayerControl.has_control(), "control returns after closing")
	await wait_seconds(1.5)
	check(not DialogueManager.is_active(), "no comment after leaving early")

	# Leaving after the comment, with the interact action.
	view = await open_view()
	await wait_for_dialogue()
	await advance_dialogue()
	check(find_view() != null, "view stays open after the comment")
	await press(&"interact")
	await wait_frames(2)
	check(find_view() == null, "interact closes the view")
	check(PlayerControl.has_control(), "control returns after closing")
	check(interactable("Telescope").can_interact(stella), "the telescope can be used again")
