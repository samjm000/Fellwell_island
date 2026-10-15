extends Node
## Runs the `test_*` methods of one or more test scripts and quits with exit code
## 0 when everything passes, 1 otherwise. Normally launched by tests/run_tests.sh:
##
##     godot --headless --fixed-fps 60 --path . res://tests/framework/runner.tscn \
##         -- res://tests/test_lemon.gd [more test scripts...]
##
## With no scripts given, every tests/test_*.gd is run in this one process.

const TESTS_DIRECTORY := "res://tests"
## Seconds of game time a single test may take before it is failed.
const TEST_TIMEOUT := 60.0

var _passed: int = 0
var _failed: PackedStringArray = []


func _ready() -> void:
	var scripts := OS.get_cmdline_user_args()
	if scripts.is_empty():
		scripts = _discover_tests()
	# Run after the autoloads and this scene have finished entering the tree.
	_run.call_deferred(scripts)


func _run(script_paths: PackedStringArray) -> void:
	for path in script_paths:
		await _run_file(path)
	print("")
	print("TESTS: %d passed, %d failed" % [_passed, _failed.size()])
	for failure in _failed:
		print("  FAILED " + failure)
	# Let timers started by the last test (e.g. delayed comments) expire, so they
	# aren't reported as leaks at exit.
	await get_tree().create_timer(3.0).timeout
	AudioManager.stop_all_and_quit(0 if _failed.is_empty() else 1)


func _run_file(path: String) -> void:
	var script := load(path) as GDScript
	if script == null:
		_failed.append("%s (could not load)" % path)
		return
	for method in script.get_script_method_list():
		var method_name: String = method.name
		if not method_name.begins_with("test_"):
			continue
		var test: Node = script.new()
		test.name = method_name
		add_child(test)
		var label := "%s::%s" % [path.get_file().get_basename(), method_name]
		var finished := await _run_with_timeout(test, &"before_each")
		if finished:
			finished = await _run_with_timeout(test, StringName(method_name))
		await _run_with_timeout(test, &"after_each")
		if not finished:
			test.failures.append("did not finish within %ss (script error or hang)" % TEST_TIMEOUT)
		if test.failures.is_empty():
			_passed += 1
			print("PASS  " + label)
		else:
			print("FAIL  " + label)
			for failure in test.failures:
				print("        - " + failure)
			_failed.append(label)
		test.queue_free()
		await get_tree().process_frame


## Calls a (possibly awaiting) method, returning false if it never completes, which
## is how a coroutine that hit a script error shows up.
func _run_with_timeout(test: Node, method: StringName) -> bool:
	var state := {"done": false}
	var call_it := func() -> void:
		await test.call(method)
		state.done = true
	call_it.call()
	var waited := 0.0
	while not state.done and waited < TEST_TIMEOUT:
		await get_tree().process_frame
		waited += get_process_delta_time()
	return state.done


func _discover_tests() -> PackedStringArray:
	var found: PackedStringArray = []
	for file in DirAccess.get_files_at(TESTS_DIRECTORY):
		if file.begins_with("test_") and file.ends_with(".gd"):
			found.append(TESTS_DIRECTORY.path_join(file))
	found.sort()
	return found
