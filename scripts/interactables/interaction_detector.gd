class_name InteractionDetector
extends Area2D
## Tracks which Interactable is currently in focus for its actor.
##
## Overlapping interactables are candidates; the focused one is the highest
## priority, then the nearest. Focus is re-evaluated every physics frame because an
## object's availability can change without anything entering or leaving the area
## (e.g. Lemon being picked up). This only runs on the player, so the cost is trivial.

signal focused_changed(interactable: Interactable)

## The node performing interactions. Defaults to the parent.
@export var actor: Node2D

var focused: Interactable = null

var _candidates: Array[Interactable] = []


func _ready() -> void:
	if actor == null:
		actor = get_parent() as Node2D
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)


func _physics_process(_delta: float) -> void:
	_set_focused(_find_best_candidate())


## Triggers the focused interactable. Returns false if nothing was in focus.
func interact_with_focused() -> bool:
	if focused == null or not is_instance_valid(focused):
		return false
	return focused.trigger(actor)


func _find_best_candidate() -> Interactable:
	var best: Interactable = null
	var best_distance := INF
	for candidate in _candidates:
		if not is_instance_valid(candidate) or not candidate.can_interact(actor):
			continue
		var distance := actor.global_position.distance_squared_to(candidate.global_position)
		var is_better := best == null \
				or candidate.interaction_priority > best.interaction_priority \
				or (candidate.interaction_priority == best.interaction_priority and distance < best_distance)
		if is_better:
			best = candidate
			best_distance = distance
	return best


func _set_focused(interactable: Interactable) -> void:
	if interactable == focused:
		return
	focused = interactable
	focused_changed.emit(focused)


func _on_area_entered(area: Area2D) -> void:
	if area is Interactable and not _candidates.has(area):
		_candidates.append(area)


func _on_area_exited(area: Area2D) -> void:
	if area is Interactable:
		_candidates.erase(area)
