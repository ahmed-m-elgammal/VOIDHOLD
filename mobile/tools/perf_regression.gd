extends SceneTree

func _init() -> void:
	var result: Dictionary = PerfBench.bench_planet_steps(600)
	print("PERF_REGRESSION steps=", result["steps"], " avg_ms=", result["avg_ms"], " p95_ms=", result["p95_ms"], " max_ms=", result["max_ms"])
	quit(0)
