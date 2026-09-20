class_name Offline
extends RefCounted

const CAP_S := 14400
const BLOCK_S := 600
const STEP_MS := 50
const STEPS_PER_SEC := 20

const HashScript := preload("res://scripts/sim/hash.gd")

static func fast_forward(state: Dictionary, seconds: float, step_fn: Callable) -> Dictionary:
	var want: float = seconds
	if want < 0.0:
		want = 0.0
	if want > float(CAP_S):
		want = float(CAP_S)
	if not step_fn.is_valid():
		return {"simulated_s": 0.0, "hash": HashScript.fnv1a(state)}
	var total_steps: int = int(want * float(STEPS_PER_SEC))
	var block_steps: int = BLOCK_S * STEPS_PER_SEC
	var done: int = 0
	while done < total_steps:
		var left: int = total_steps - done
		var chunk: int = block_steps
		if chunk > left:
			chunk = left
		var i: int = 0
		while i < chunk:
			step_fn.call(STEP_MS)
			i += 1
		done += chunk
	var simulated: float = float(done) * (float(STEP_MS) / 1000.0)
	return {"simulated_s": simulated, "hash": HashScript.fnv1a(state)}
