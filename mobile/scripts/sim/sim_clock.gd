class_name SimClock
extends RefCounted

const STEP_HZ := 20
const STEP_MS := 50
const MAX_CATCHUP_STEPS := 240

var acc_ms: float = 0.0
var speed: int = 1
var paused: bool = false
var dropped_steps: int = 0
var stepped_total: int = 0

func set_speed(value: int) -> void:
	if value < 1:
		return
	if value > 3:
		return
	speed = value

func set_paused(value: bool) -> void:
	paused = value

func reset() -> void:
	acc_ms = 0.0
	dropped_steps = 0
	stepped_total = 0

func advance(frame_ms: float, step_fn: Callable) -> float:
	if paused:
		return clampf(acc_ms / float(STEP_MS), 0.0, 1.0)
	var budget: float = frame_ms
	if budget < 0.0:
		budget = 0.0
	if not step_fn.is_valid():
		return clampf(acc_ms / float(STEP_MS), 0.0, 1.0)
	acc_ms += budget * float(speed)
	var cap_ms: float = float(MAX_CATCHUP_STEPS * STEP_MS)
	if acc_ms > cap_ms:
		var excess: float = acc_ms - cap_ms
		dropped_steps += int(excess / float(STEP_MS))
		acc_ms = cap_ms
	var guard: int = 0
	while acc_ms >= float(STEP_MS) and guard < MAX_CATCHUP_STEPS:
		step_fn.call(STEP_MS)
		acc_ms -= float(STEP_MS)
		guard += 1
		stepped_total += 1
	return clampf(acc_ms / float(STEP_MS), 0.0, 1.0)
