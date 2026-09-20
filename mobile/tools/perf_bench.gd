class_name PerfBench
extends RefCounted

const Sim = preload("res://scripts/sim/building_data.gd")
const STEP_DT := 0.05
const DEFAULT_BUILDINGS := 96
const DEFAULT_UNITS := 48

static func make_full_dome(building_total: int = DEFAULT_BUILDINGS, unit_total: int = DEFAULT_UNITS) -> Dictionary:
	var buildings: Array = []
	buildings.resize(maxi(building_total, 0))
	for i in buildings.size():
		buildings[i] = {
			"mood": 0.5 + 0.5 * (float(i % 5) / 4.0),
			"oxygen": 0.6 + 0.4 * (float(i % 3) / 2.0),
			"damage": float(i % 4) / 12.0,
			"has_energy": (i % 7) != 0,
			"incident": (i % 11) == 0,
			"output": float(i % 9),
			"max_output": 10.0,
			"input_ok": (i % 5) != 0
		}
	var units: Array = []
	units.resize(maxi(unit_total, 0))
	for i in units.size():
		units[i] = {
			"fullness": 0.4 + 0.6 * (float(i % 7) / 6.0),
			"oxygen_need": 0.15,
			"assigned": (i % 4) != 0
		}
	return {"buildings": buildings, "units": units, "sim_time": 0.0, "functional": 0, "output_sum": 0.0}

static func dome_step(state: Dictionary) -> void:
	var buildings: Array = state["buildings"]
	var units: Array = state["units"]
	var functional := 0
	var output_sum := 0.0
	var oxygen_bldgs := 0
	for b in buildings:
		var row: Dictionary = b
		if Sim.is_functional(float(row["damage"]), bool(row["has_energy"]), bool(row["incident"]), float(row["output"]), float(row["max_output"]), bool(row["input_ok"])):
			functional += 1
		output_sum += Sim.productivity(float(row["mood"]), float(row["oxygen"]), float(row["damage"]))
		if (int(row["output"]) % 3) == 0:
			oxygen_bldgs += 1
	var need_sum := 0.0
	for u in units:
		var row: Dictionary = u
		need_sum += float(row["fullness"]) * float(row["oxygen_need"])
	var saturation := Sim.oxygen_saturation(oxygen_bldgs, buildings.size(), units.size())
	state["functional"] = functional
	state["output_sum"] = output_sum * saturation + need_sum * 0.001
	state["sim_time"] = float(state["sim_time"]) + STEP_DT

static func bench_dome_steps(steps: int = 600) -> Dictionary:
	if steps <= 0:
		return {"steps": 0, "avg_ms": 0.0, "p95_ms": 0.0, "min_ms": 0.0, "max_ms": 0.0, "buildings": 0, "units": 0}
	var state: Dictionary = make_full_dome()
	var samples: Array = []
	samples.resize(steps)
	for i in steps:
		var t0: int = Time.get_ticks_usec()
		dome_step(state)
		var t1: int = Time.get_ticks_usec()
		samples[i] = float(t1 - t0) / 1000.0
	var ordered: Array = samples.duplicate()
	ordered.sort()
	var total := 0.0
	for v in samples:
		total += float(v)
	var p95_index: int = mini(steps - 1, int(ceil(0.95 * float(steps))) - 1)
	return {
		"steps": steps,
		"avg_ms": total / float(steps),
		"p95_ms": float(ordered[p95_index]),
		"min_ms": float(ordered[0]),
		"max_ms": float(ordered[steps - 1]),
		"buildings": (state["buildings"] as Array).size(),
		"units": (state["units"] as Array).size()
	}

static func make_planet(building_total: int = DEFAULT_BUILDINGS, unit_total: int = DEFAULT_UNITS) -> PlanetSim:
	var planet := PlanetSim.new()
	planet.setup("beginner", 41)
	var dome := DomeSim.new()
	dome.setup()
	planet.add_dome(dome)
	planet.seed_elevator(dome)
	for i in range(maxi(0, building_total - 1)):
		var cell := Vector2i(30 + (i % 10) * 8, 30 + (i / 10) * 8)
		var building := dome.make_building("solar", cell, 0)
		dome.buildings.append(building)
	for i in range(maxi(0, unit_total)):
		dome.units.append(UnitSim.make_dict("helot", Vector2(128.0, 128.0), i + 1, 0))
	dome._dirty = true
	dome.sync_indices()
	return planet

static func bench_planet_steps(steps: int = 600) -> Dictionary:
	if steps <= 0:
		return {"steps": 0, "avg_ms": 0.0, "p95_ms": 0.0, "min_ms": 0.0, "max_ms": 0.0}
	var planet := make_planet()
	var samples: Array = []
	samples.resize(steps)
	for i in steps:
		var start_usec: int = Time.get_ticks_usec()
		planet.step_20hz()
		samples[i] = float(Time.get_ticks_usec() - start_usec) / 1000.0
	var ordered: Array = samples.duplicate()
	ordered.sort()
	var total_ms: float = 0.0
	for sample in samples:
		total_ms += float(sample)
	var p95_index: int = mini(steps - 1, int(ceil(0.95 * float(steps))) - 1)
	return {
		"steps": steps,
		"avg_ms": total_ms / float(steps),
		"p95_ms": float(ordered[p95_index]),
		"min_ms": float(ordered[0]),
		"max_ms": float(ordered[steps - 1])
	}
