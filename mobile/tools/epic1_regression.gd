extends SceneTree

var failures: Array[String] = []

func check(name: String, condition: bool) -> void:
	if not condition:
		failures.append(name)

func make_dome() -> DomeSim:
	var dome := DomeSim.new()
	dome.setup()
	return dome

func seed_storage(dome: DomeSim) -> void:
	var elevator := dome.make_building("elevator", Vector2i(10, 10), 0)
	var store: Dictionary = elevator["store"]
	store["stone"] = 100.0
	store["alloy"] = 100.0
	dome.buildings.append(elevator)
	dome._dirty = true
	dome.sync_indices()

func find_cell(dome: DomeSim, w: int, h: int) -> Vector2i:
	for x in range(0, 210):
		for y in range(0, 210):
			var cell := Vector2i(x, y)
			if dome.footprint_free(cell, w, h):
				return cell
	return Vector2i(-1, -1)

func make_teleport(dome: DomeSim, cell: Vector2i) -> Dictionary:
	var teleport := dome.make_building("teleport", cell, 0)
	dome.buildings.append(teleport)
	dome._dirty = true
	dome.sync_indices()
	return teleport

func _init() -> void:
	var rng := Rng.new(77)
	var dome := make_dome()
	seed_storage(dome)
	var cell := find_cell(dome, 5, 5)
	var oxygen := dome.place("oxygen", cell, 0, 0)
	check("nullable placement succeeds", not oxygen.is_empty())
	var overlap := dome.place("solar", cell, 0, 0)
	check("overlap placement rejected", overlap.is_empty())
	var outside := dome.place("solar", Vector2i(-100, -100), 0, 0)
	check("outside placement rejected", outside.is_empty())

	var unit := UnitSim.make_dict("helot", Vector2.ZERO, 1, 0)
	dome.units.append(unit)
	dome._dirty = true
	dome.step_20hz(rng)
	check("unit fullness drains at 20Hz", float(unit["full"]) < 1.0)

	var planet := PlanetSim.new()
	planet.setup("intermediate", 5)
	var source_dome := make_dome()
	var target_dome := make_dome()
	planet.add_dome(source_dome)
	planet.add_dome(target_dome)
	var source := make_teleport(source_dome, Vector2i(20, 20))
	source["exp"] = "stone"
	(source["store"] as Dictionary)["stone"] = 10.0
	var target := make_teleport(target_dome, Vector2i(20, 20))
	target["imp"] = "stone"
	(target["store"] as Dictionary)["stone"] = 47.0
	planet.teleport_step()
	check("teleport respects capacity", is_equal_approx(float((target["store"] as Dictionary)["stone"]), 48.0))

	var hash_before := planet.state_hash()
	(source["store"] as Dictionary)["stone"] = 1.0
	var hash_after := planet.state_hash()
	check("snapshot hash includes state", hash_before != hash_after)

	var expert_source := PlanetSim.new()
	expert_source.setup("expert", 17)
	var expert_source_dome := make_dome()
	expert_source.add_dome(expert_source_dome)
	expert_source.seed_elevator(expert_source_dome)
	expert_source.step_20hz()
	var saved_state := expert_source.save_state()
	var json_state: Variant = JSON.parse_string(JSON.stringify(saved_state))
	var expert_restored := PlanetSim.new()
	expert_restored.setup("beginner", 999)
	check("planet state restores", json_state is Dictionary and expert_restored.load_state(json_state))
	check("planet round-trip hash", expert_source.state_hash() == expert_restored.state_hash())
	check("saved moon tuning restores", is_equal_approx(float(expert_restored.mults["enemy_damage"]), 1.5))
	var restored_dome: DomeSim = expert_restored.domes[0]
	var restored_elevator: Dictionary = restored_dome.buildings[0]
	check("save restores building footprint", not restored_dome.is_walkable(restored_elevator["cell"]))
	check("seed elevator keeps entrance walkable", restored_dome.is_walkable(restored_elevator["door"]))

	var authority_dome := make_dome()
	var authority := authority_dome.make_building("authority", Vector2i(40, 40), 0)
	var wrong_target := authority_dome.make_building("elevator", Vector2i(42, 40), 0)
	var assigned_target := authority_dome.make_building("elevator", Vector2i(44, 40), 0)
	wrong_target["foe"] = 11
	wrong_target["foe_hp"] = 1.0
	assigned_target["foe"] = 22
	assigned_target["foe_hp"] = 1.0
	var officer := UnitSim.make_dict("mighty", authority["hub"], 500, 0)
	officer["job_kind"] = "incident"
	officer["job_done"] = true
	officer["job_house"] = int(assigned_target["guid"])
	authority["workers"] = [500]
	authority_dome.units.append(officer)
	authority_dome.buildings.append(authority)
	authority_dome.buildings.append(wrong_target)
	authority_dome.buildings.append(assigned_target)
	authority_dome._dirty = true
	authority_dome.sync_indices()
	authority_dome.step_incident(authority)
	check("authority follows assigned incident", is_equal_approx(float(wrong_target["foe_hp"]), 1.0) and float(assigned_target["foe_hp"]) < 1.0)
	check("oxygen saturation clamps", is_equal_approx(BuildingData.oxygen_saturation(4, 1, 0), 1.0))

	var normal := PlanetSim.new()
	normal.setup("intermediate", 9)
	var normal_dome := make_dome()
	var normal_building := normal_dome.make_building("elevator", Vector2i(40, 40), 0)
	normal_building["foe"] = -1
	normal_building["foe_hp"] = 1.0
	normal_building["foe_left_ms"] = 60000
	normal_dome.buildings.append(normal_building)
	normal_dome._dirty = true
	normal.add_dome(normal_dome)
	normal.step_20hz()
	var normal_damage := float(normal_building["damage"])

	var expert := PlanetSim.new()
	expert.setup("expert", 9)
	var expert_dome := make_dome()
	var expert_building := expert_dome.make_building("elevator", Vector2i(40, 40), 0)
	expert_building["foe"] = -1
	expert_building["foe_hp"] = 1.0
	expert_building["foe_left_ms"] = 60000
	expert_dome.buildings.append(expert_building)
	expert_dome._dirty = true
	expert.add_dome(expert_dome)
	expert.step_20hz()
	check("expert enemy damage multiplier applies", float(expert_building["damage"]) > normal_damage)

	for _i in range(1200):
		normal.step_20hz()
	check("enemy incident expires", int(normal_building.get("foe", 0)) == 0)

	if failures.is_empty():
		print("EPIC1_REGRESSION PASS")
		quit(0)
	else:
		for failure in failures:
			print("FAIL ", failure)
		print("EPIC1_REGRESSION FAIL count=", failures.size())
		quit(1)
