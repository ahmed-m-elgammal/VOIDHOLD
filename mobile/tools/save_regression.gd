extends SceneTree

const FIRST_TEST_SLOT := 900000

var failures: Array[String] = []

func check(name: String, condition: bool) -> void:
	if not condition:
		failures.append(name)

func _init() -> void:
	var slot: int = FIRST_TEST_SLOT
	while FileAccess.file_exists("user://slot%d.json" % slot):
		slot += 1
	var saver := SaveSystem.new()
	var payload: Dictionary = {"planet_state": {"tick": 7, "rng": {"s0": 3, "s1": 5}}}
	var probe := FileAccess.open("user://save_probe.tmp", FileAccess.WRITE)
	if probe != null:
		probe.store_string("probe")
		probe.close()
	var first_error: Error = saver.save_slot(slot, payload)
	check("first atomic save", first_error == OK)
	var loaded: Dictionary = saver.load_slot(slot)
	check("save round-trip", loaded.get("planet_state", {}).get("tick", -1) == 7)
	var second_error: Error = saver.save_slot(slot, {"planet_state": {"tick": 8}})
	check("second atomic save replaces", second_error == OK)
	check("replacement is readable", saver.load_slot(slot).get("planet_state", {}).get("tick", -1) == 8)
	var path: String = ProjectSettings.globalize_path("user://slot%d.json" % slot)
	var corrupt := FileAccess.open(path, FileAccess.WRITE)
	if corrupt != null:
		corrupt.store_string("{not-json")
		corrupt.close()
	var recovered: Dictionary = saver.load_slot(slot)
	check("corrupt save quarantines", recovered.is_empty() and not FileAccess.file_exists(path))
	_cleanup(slot)
	var probe_path: String = ProjectSettings.globalize_path("user://save_probe.tmp")
	if FileAccess.file_exists(probe_path):
		DirAccess.remove_absolute(probe_path)
	saver.free()
	if failures.is_empty():
		print("SAVE_REGRESSION PASS")
		quit(0)
	else:
		for failure in failures:
			print("FAIL ", failure)
		print("SAVE_REGRESSION FAIL count=", failures.size())
		quit(1)

func _cleanup(slot: int) -> void:
	var path: String = ProjectSettings.globalize_path("user://slot%d.json" % slot)
	var tmp: String = path + ".tmp"
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	if FileAccess.file_exists(tmp):
		DirAccess.remove_absolute(tmp)
	var corrupt_dir: String = ProjectSettings.globalize_path("user://corrupt")
	var dir := DirAccess.open(corrupt_dir)
	if dir == null:
		return
	for filename in dir.get_files():
		if filename.begins_with("slot%d_" % slot):
			DirAccess.remove_absolute(corrupt_dir.path_join(filename))
