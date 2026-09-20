class_name BuildingData
extends RefCounted

static func is_functional(damage: float, has_energy: bool, incident: bool, output: float, max_output: float, input_ok: bool) -> bool:
	if damage >= 1.0:
		return false
	if not has_energy:
		return false
	if incident:
		return false
	if max_output > 0.0 and output >= max_output:
		return false
	if not input_ok:
		return false
	return true

static func productivity(mood: float, oxygen: float, damage: float) -> float:
	var m = clampf(mood, 0.0, 1.0)
	var d = clampf(damage, 0.0, 1.0)
	var o = maxf(oxygen, 0.0)
	return (0.5 + 0.5 * m) * (1.0 - d) * (0.5 + 0.5 * o)

static func oxygen_saturation(oxygen_bldgs: int, total_bldgs: int, units: int) -> float:
	var needed = float(total_bldgs) * 0.05 + float(units) * 0.15
	if needed <= 0.0:
		needed = 1.0
	return clampf(float(oxygen_bldgs) / needed, 0.0, 1.0)
