extends Node
## Tracks whether the player currently has control of Stella.
##
## Systems that take over input (dialogue, telescope view, sleep transition) acquire
## a lock under their own key and release it when done. Control returns only when
## every lock is released, so overlapping systems can't hand control back early.

signal control_changed(has_control: bool)

var _locks: Dictionary = {}


func acquire(source: StringName) -> void:
	var had_control := has_control()
	_locks[source] = true
	if had_control:
		control_changed.emit(false)


func release(source: StringName) -> void:
	if not _locks.erase(source):
		return
	if has_control():
		control_changed.emit(true)


func has_control() -> bool:
	return _locks.is_empty()
