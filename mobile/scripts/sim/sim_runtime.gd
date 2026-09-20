extends Node

const SAVE_SLOT := 0
const AUTOSAVE_MS := 30000.0

var clock: SimClock
var planet: PlanetSim
var saves: SaveSystem
var time_manager: TimeManager
var autosave_acc_ms: float = 0.0

func _ready() -> void:
	clock = SimClock.new()
	planet = PlanetSim.new()
	planet.setup("beginner", 1)
	time_manager = TimeManager.new()
	add_child(time_manager)
	saves = SaveSystem.new()
	add_child(saves)
	var loaded: Dictionary = saves.load_slot(SAVE_SLOT)
	var restored: bool = false
	if loaded.get("planet_state") is Dictionary:
		restored = planet.load_state(loaded["planet_state"])
	if restored and time_manager != null:
		var last_seen_utc: int = int(loaded.get("last_seen_utc", 0))
		if last_seen_utc > 0:
			var offline_s: int = time_manager.offline_seconds(int(Time.get_unix_time_from_system()), last_seen_utc)
			if offline_s > 0:
				Offline.fast_forward({}, float(offline_s), Callable(self, "_step"))
	if restored == false:
		var dome := DomeSim.new()
		dome.setup()
		planet.add_dome(dome)
		planet.seed_elevator(dome)
	set_process(true)

func _process(delta: float) -> void:
	if clock == null or planet == null:
		return
	var frame_ms: float = maxf(0.0, delta * 1000.0)
	clock.advance(frame_ms, Callable(self, "_step"))
	autosave_acc_ms += frame_ms
	if autosave_acc_ms >= AUTOSAVE_MS:
		autosave_acc_ms = 0.0
		save_game()

func _step(_step_ms: int) -> void:
	planet.step_20hz()

func save_game() -> Error:
	if saves == null or planet == null:
		return ERR_UNCONFIGURED
	return saves.save_slot(SAVE_SLOT, {
		"last_seen_utc": int(Time.get_unix_time_from_system()),
		"planet_state": planet.save_state()
	})

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game()
		if what == NOTIFICATION_WM_CLOSE_REQUEST:
			get_tree().quit()
