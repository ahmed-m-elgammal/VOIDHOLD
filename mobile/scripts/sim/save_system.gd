class_name SaveSystem
extends Node

const SLOT_FMT := "user://slot%d.json"
const VERSION := 1
const CORRUPT_FMT := "user://corrupt/slot%d_%d.json"
const CORRUPT_DIR := "user://corrupt"

func save_slot(i: int, state: Dictionary) -> Error:
	var path: String = SLOT_FMT % i
	var tmp: String = path + ".tmp"
	var payload: Dictionary = state.duplicate(true)
	payload["save_version"] = VERSION
	var text: String = JSON.stringify(payload)
	var f: FileAccess = FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(text)
	f.close()
	var save_dir: DirAccess = DirAccess.open("user://")
	if save_dir == null:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(tmp))
		return ERR_FILE_CANT_OPEN
	var err: Error = save_dir.rename(tmp.get_file(), path.get_file())
	if err != OK:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(tmp))
	return err

func load_slot(i: int) -> Dictionary:
	var path: String = SLOT_FMT % i
	if not FileAccess.file_exists(path):
		return {}
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var text: String = f.get_as_text()
	f.close()
	var parser: JSON = JSON.new()
	var perr: Error = parser.parse(text)
	if perr != OK:
		_quarantine(path, i)
		return {}
	var data: Variant = parser.data
	if not (data is Dictionary):
		_quarantine(path, i)
		return {}
	var d: Dictionary = data
	if not d.has("save_version"):
		return migrate_v0_v1(d)
	var v: int = int(d["save_version"])
	if v < VERSION:
		return migrate_v0_v1(d)
	if v > VERSION:
		_quarantine(path, i)
		return {}
	return d

func migrate_v0_v1(d: Dictionary) -> Dictionary:
	var out: Dictionary = SaveSchema.default_save()
	for k in d.keys():
		out[k] = d[k]
	if d.has("playtime") and not d.has("playtime_s"):
		out["playtime_s"] = d["playtime"]
	var rng: Dictionary = {"s0": 0, "s1": 0, "pos": 0}
	if out.get("rng_state") is Dictionary:
		rng = out["rng_state"]
	if not rng.has("s0"):
		rng["s0"] = 0
	if not rng.has("s1"):
		rng["s1"] = 0
	if not rng.has("pos"):
		rng["pos"] = 0
	out["rng_state"] = rng
	if not (out.get("domes") is Array):
		out["domes"] = []
	if not (out.get("entitlements") is Dictionary):
		out["entitlements"] = {}
	if not (out.get("settings") is Dictionary):
		out["settings"] = {"locale": "en", "music": true, "sfx": true}
	if not (out.get("stats") is Dictionary):
		out["stats"] = {}
	if not (out.get("tutorial_flags") is Dictionary):
		out["tutorial_flags"] = {}
	out["save_version"] = VERSION
	return out

func _quarantine(path: String, i: int) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CORRUPT_DIR))
	var stamp: int = int(Time.get_unix_time_from_system())
	var dest: String = CORRUPT_FMT % [i, stamp]
	var suffix: int = 0
	while FileAccess.file_exists(dest):
		suffix += 1
		dest = CORRUPT_FMT % [i, stamp + suffix]
	DirAccess.rename_absolute(ProjectSettings.globalize_path(path), ProjectSettings.globalize_path(dest))
