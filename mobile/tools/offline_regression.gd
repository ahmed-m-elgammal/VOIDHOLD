extends SceneTree

var planet: PlanetSim

func _init() -> void:
	planet = PlanetSim.new()
	planet.setup("beginner", 31)
	var dome := DomeSim.new()
	dome.setup()
	planet.add_dome(dome)
	planet.seed_elevator(dome)
	var start_usec: int = Time.get_ticks_usec()
	var result: Dictionary = Offline.fast_forward({}, 14400.0, Callable(self, "_step"))
	var elapsed_ms: float = float(Time.get_ticks_usec() - start_usec) / 1000.0
	print("OFFLINE_REGRESSION simulated_s=", result["simulated_s"], " wall_ms=", elapsed_ms)
	if not is_equal_approx(float(result["simulated_s"]), 14400.0):
		quit(1)
	else:
		quit(0)

func _step(_step_ms: int) -> void:
	planet.step_20hz()

