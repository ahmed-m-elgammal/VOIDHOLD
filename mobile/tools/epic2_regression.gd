extends SceneTree

# Epic 2 regression (T2.1-T2.4). Run headless after import:
#   godot --headless --path mobile -s tools/epic2_regression.gd
# Covers: solar day/night multiplier, dome world-state save round-trip,
# AStarGrid2D pathing around buildings, placement validation matrix,
# elevator-to-new-dome flow (no overlap exploit), mask/grid spot check,
# and placement query perf (<8 ms budget).

var failures: Array[String] = []
var checks: int = 0

func check(name: String, condition: bool) -> void:
	checks += 1
	if condition == false:
		failures.append(name)
		print("FAIL: " + name)

func _init() -> void:
	# Deterministic: drop any local save before booting the scene.
	var save_path: String = ProjectSettings.globalize_path("user://slot0.json")
	if FileAccess.file_exists("user://slot0.json"):
		DirAccess.remove_absolute(save_path)
	_test_solar_multiplier()
	_test_dome_state_roundtrip()
	_test_theme_mapping()
	await _test_scene_integration()
	_test_mask_spot_check()
	var failed: int = failures.size()
	print("RESULT: " + str(checks - failed) + "/" + str(checks) + " epic2 checks passed")
	if failed > 0:
		for f in failures:
			print("  failed: " + f)
	quit(0 if failed == 0 else 1)

# ---------------------------------------------------------------- T2.1 solar

func _solar_dome() -> DomeSim:
	var dome := DomeSim.new()
	dome.setup()
	var elev := dome.make_building("elevator", Vector2i(20, 20), 0)
	dome.buildings.append(elev)
	dome._dirty = true
	dome.sync_indices()
	return dome

func _test_solar_multiplier() -> void:
	# Tech preconditions: solar requires oxygen first.
	var dome2 := _solar_dome()
	check("solar without oxygen rejected", dome2.place("solar", Vector2i(40, 30), 0, 0).is_empty())
	check("oxygen placement ok", dome2.place("oxygen", Vector2i(30, 30), 0, 0).is_empty() == false)
	check("solar after oxygen ok", dome2.place("solar", Vector2i(40, 30), 0, 0).is_empty() == false)
	# Only factory/kitchen/teleport draw energy; add a factory via
	# make_building (its own precondition chain is covered elsewhere).
	var factory := dome2.make_building("factory", Vector2i(50, 30), 0)
	dome2.buildings.append(factory)
	dome2._dirty = true
	dome2.sync_indices()
	var day_v: float = dome2.energy_saturation()
	dome2.tune["solar_mult"] = 0.35
	var night_v: float = dome2.energy_saturation()
	check("day/night changes solar value", day_v > night_v)
	check("night solar is scaled", absf(night_v - day_v * 0.35) < 0.0001)

# ---------------------------------------------------------------- save roundtrip

func _test_dome_state_roundtrip() -> void:
	var planet := PlanetSim.new()
	planet.setup("beginner", 1)
	var d1 := DomeSim.new()
	d1.setup()
	d1.topleft = Vector2i(10, 6)
	d1.entrance_side = 3
	planet.add_dome(d1)
	planet.seed_elevator(d1)
	var d2 := DomeSim.new()
	d2.setup()
	d2.topleft = Vector2i(7, 94)
	d2.entrance_side = 0
	planet.add_dome(d2)
	var state: Dictionary = planet.save_state()
	var planet2 := PlanetSim.new()
	planet2.setup("beginner", 1)
	check("load_state ok", planet2.load_state(state))
	check("two domes restored", planet2.domes.size() == 2)
	var r1: DomeSim = planet2.domes[0]
	var r2: DomeSim = planet2.domes[1]
	check("dome1 topleft restored", r1.topleft == Vector2i(10, 6))
	check("dome1 entrance restored", r1.entrance_side == 3)
	check("dome2 topleft restored", r2.topleft == Vector2i(7, 94))
	check("dome2 entrance restored", r2.entrance_side == 0)
	check("dome size default 80", r2.dome_size == 80)

# ---------------------------------------------------------------- theme mapping

func _test_theme_mapping() -> void:
	check("cell_to_world center", WorldTheme.cell_to_world(Vector2i(0, 0)) == Vector3(0.5, 0.0, 0.5))
	check("world_to_cell inverse", WorldTheme.world_to_cell(Vector3(4.7, 0.0, 9.2)) == Vector2i(4, 9))
	check("side yaw north", is_equal_approx(WorldTheme.side_yaw(WorldTheme.SIDE_NORTH), 0.0))

# ---------------------------------------------------------------- AStarGrid2D

func _test_pathing() -> void:
	var dome := DomeSim.new()
	dome.setup()
	var elev := dome.make_building("elevator", Vector2i(20, 20), 0)
	dome.buildings.append(elev)
	dome._dirty = true
	dome.sync_indices()
	var rect := Rect2i(Vector2i(10, 6), Vector2i(80, 80))
	var pathing := DomePathing.new()
	pathing.setup(dome, rect)
	pathing.entrance_cells = [Vector2i(10, 44), Vector2i(10, 45)]
	pathing.resync()
	var from := Vector2i(30, 30)
	var to := Vector2i(60, 60)
	check("straight path exists", pathing.path_exists(from, to))
	# Drop a building between them and confirm the path routes around.
	var blocker := dome.make_building("storage", Vector2i(44, 44), 0)
	dome.buildings.append(blocker)
	dome.set_walk_rect(blocker, false)
	dome._dirty = true
	dome.sync_indices()
	pathing.resync()
	var detour: Array = pathing.find_path(from, to)
	check("detour path exists around building", detour.is_empty() == false)
	if detour.is_empty() == false:
		var straight_len: int = absi(to.x - from.x) + absi(to.y - from.y)
		check("detour at least manhattan length", detour.size() - 1 >= straight_len)
		var cardinal: bool = true
		for i in range(1, detour.size()):
			var step: Vector2i = detour[i] - detour[i - 1]
			if absi(step.x) + absi(step.y) != 1:
				cardinal = false
		check("cardinal movement only", cardinal)
		var inside: bool = true
		for p in detour:
			if rect.has_point(p) == false:
				inside = false
		check("path stays inside dome", inside)
	# placeWalkable/removeWalkable mirror.
	var c := Vector2i(50, 50)
	pathing.place_walkable(c, false)
	check("placeWalkable blocks", pathing.is_walkable(c) == false)
	pathing.place_walkable(c, true)
	check("removeWalkable restores", pathing.is_walkable(c))
	# Entrance stays walkable even under a building footprint.
	pathing.place_walkable(Vector2i(10, 44), false)
	check("entrance kept walkable", pathing.is_walkable(Vector2i(10, 44)))
	# Unplace restores walkability.
	dome.unplace(int(blocker["guid"]))
	pathing.resync()
	check("unplace restores walkability", pathing.is_walkable(Vector2i(45, 45)))

# ---------------------------------------------------------------- placement matrix

# Nearest free w x h spot around `center` whose footprint does not cover the
# keepout rect (keepout_w x keepout_h at center), scanning outward.
func _nearest_free_excluding(dome: DomeSim, w: int, h: int, center: Vector2i, keepout: int, maxd: int) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_d: int = 2147483647
	for dx in range(-maxd, maxd + 1):
		for dy in range(-maxd, maxd + 1):
			var c := center + Vector2i(dx, dy)
			var ring: int = maxi(absi(dx), absi(dy))
			if ring < 5 or ring > maxd:
				continue
			if c.x < 1 or c.y < 1 or c.x + w >= 209 or c.y + h >= 209:
				continue
			var fp := Rect2i(c, Vector2i(w, h))
			if fp.intersects(Rect2i(center, Vector2i(keepout, keepout))):
				continue
			if dome.footprint_free(c, w, h) == false:
				continue
			if ring < best_d:
				best_d = ring
				best = c
	return best

func _first_free_bounded(dome: DomeSim, w: int, h: int, anchor: Vector2i, maxd: int) -> Vector2i:
	for dx in range(0, maxd):
		for dy in range(0, maxd):
			var c := anchor + Vector2i(dx, dy)
			if dome.footprint_free(c, w, h):
				return c
	return Vector2i(-1, -1)

func _first_free(dome: DomeSim, w: int, h: int, anchor: Vector2i) -> Vector2i:
	for dx in range(0, 60):
		for dy in range(0, 60):
			var c := anchor + Vector2i(dx, dy)
			if dome.footprint_free(c, w, h):
				return c
	return Vector2i(-1, -1)

func _test_placement_matrix(manager: DomeManager, placement: PlacementSystem) -> void:
	var dw: DomeWorld = manager.world_at(0)
	var dome: DomeSim = dw.dome
	# Seed resources so the resource check only fails when we zero the store.
	for b in dome.buildings:
		if String(b.get("kind", "")) == "elevator":
			var st: Dictionary = b["store"]
			st["stone"] = 500.0
			st["alloy"] = 500.0
	# OK case: oxygen inside dome on free ground.
	var cell_ok := _first_free(dome, 5, 5, Vector2i(20, 20))
	check("found free cell for oxygen", cell_ok.x >= 0)
	var v: Dictionary = placement.validate(dw, "oxygen", cell_ok, 0)
	check("valid placement accepted", bool(v.get("ok", false)) == true)
	# Overlap -> bad-tile.
	var v2: Dictionary = placement.validate(dw, "oxygen", cell_ok, 0)
	check("overlap rejected bad-tile", String(v2.get("reason", "")) == "bad-tile")
	# Outside dome -> outside-dome.
	var v3: Dictionary = placement.validate(dw, "oxygen", Vector2i(dw.rect.position.x - 10, 30), 0)
	check("outside dome rejected", String(v3.get("reason", "")) == "outside-dome")
	# planetProperty: farmarea on non-farmable -> bad-tile.
	var fc := _first_free(dome, 4, 4, Vector2i(20, 20))
	check("found free cell for farmarea", fc.x >= 0)
	var on_farm: bool = dome.footprint_has_prop(fc, 4, 4, "farmable")
	if on_farm:
		fc = _first_free(dome, 4, 4, Vector2i(60, 60))
		on_farm = dome.footprint_has_prop(fc, 4, 4, "farmable")
	check("found non-farmable cell", on_farm == false)
	var v4: Dictionary = placement.validate(dw, "farmarea", fc, 0)
	check("farmarea on plain ground is bad-tile", String(v4.get("reason", "")) == "bad-tile")
	# farmarea on farmable ground without a farm -> missing-link.
	var fcell := Vector2i(-1, -1)
	var farms: Dictionary = dome.prop_sets.get("farmable", {})
	for c in farms.keys():
		var cc: Vector2i = c
		if dw.rect.has_point(cc) and dome.footprint_free(cc, 4, 4):
			fcell = cc
			break
	check("found farmable cell in dome", fcell.x >= 0)
	if fcell.x >= 0:
		var v5: Dictionary = placement.validate(dw, "farmarea", fcell, 0)
		check("farmarea without farm is missing-link", String(v5.get("reason", "")) == "missing-link")
		# Tech chain: farm requires living, living requires oxygen. Place
		# them near enough for the farm<->farmarea link radius (20).
		var oc := _first_free(dome, 5, 5, fcell + Vector2i(10, 10))
		var lc := Vector2i(-1, -1)
		var farm_cell := _first_free_bounded(dome, 7, 7, fcell + Vector2i(6, 0), 12)
		if oc.x >= 0 and farm_cell.x >= 0:
			check("oxygen places for chain", dome.place("oxygen", oc, 0, 0).is_empty() == false)
			lc = _first_free(dome, 5, 5, fcell + Vector2i(10, 10))
			check("living places for chain", lc.x >= 0 and dome.place("living", lc, 0, 0).is_empty() == false)
			farm_cell = _nearest_free_excluding(dome, 7, 7, fcell, 4, 14)
			var farm_res: Dictionary = dome.place("farm", farm_cell, 0, 0)
			if farm_res.is_empty():
				print("DEBUG farm failed at ", farm_cell, " free=", dome.footprint_free(farm_cell, 7, 7), " prereq=", dome.precondition_met("farm"), " stone=", dome.test_for("stone", 3.0), " fcell=", fcell)
			check("farm places", farm_res.is_empty() == false)
			var v6: Dictionary = placement.validate(dw, "farmarea", fcell, 0)
			check("farmarea with farm in range ok", bool(v6.get("ok", false)))
	# Prerequisite: solar needs oxygen; fresh dome has none.
	var dome_b := DomeSim.new()
	dome_b.setup()
	var elev_b := dome_b.make_building("elevator", Vector2i(20, 20), 0)
	dome_b.buildings.append(elev_b)
	dome_b._dirty = true
	dome_b.sync_indices()
	var wb: DomeWorld = manager.add_world(dome_b, Rect2i(Vector2i(0, 0), Vector2i(80, 80)), WorldTheme.SIDE_WEST)
	var v7: Dictionary = placement.validate(wb, "solar", Vector2i(30, 30), 0)
	check("solar without oxygen is prerequisite", String(v7.get("reason", "")) == "prerequisite")
	# No-resource: zero the store.
	for b in dome_b.buildings:
		if String(b.get("kind", "")) == "elevator":
			var st2: Dictionary = b["store"]
			for k in st2.keys():
				st2[k] = 0.0
	var v8: Dictionary = placement.validate(wb, "oxygen", Vector2i(30, 30), 0)
	check("empty store is no-resource", String(v8.get("reason", "")) == "no-resource")
	manager.worlds.erase(wb)
	# Elevator inside dome -> elevator-outside.
	var v9: Dictionary = placement.validate(dw, "elevator", Vector2i(30, 30), 0)
	check("elevator inside dome rejected", String(v9.get("reason", "")) == "elevator-outside")
	# Elevator outside with room -> ok.
	var elev_cell := Vector2i(-1, -1)
	for y in range(dw.rect.end.y + 2, 205):
		for x in range(20, 100):
			var vv: Dictionary = placement.validate(dw, "elevator", Vector2i(x, y), 0)
			if bool(vv.get("ok", false)):
				elev_cell = Vector2i(x, y)
				break
		if elev_cell.x >= 0:
			break
	check("found valid elevator cell outside domes", elev_cell.x >= 0)
	# Perf: placement query budget.
	var t0: int = Time.get_ticks_usec()
	var worst: float = 0.0
	for i in range(1000):
		var c2 := Vector2i(20 + (i % 40), 20 + ((i / 40) % 40))
		var t1: int = Time.get_ticks_usec()
		placement.validate(dw, "oxygen", c2, 0)
		var ms: float = float(Time.get_ticks_usec() - t1) / 1000.0
		worst = maxf(worst, ms)
	var avg: float = float(Time.get_ticks_usec() - t0) / 1000.0 / 1000.0
	print("placement perf avg=%.4fms worst=%.4fms" % [avg, worst])
	check("placement query under 8ms budget", worst < 8.0)

# ---------------------------------------------------------------- scene integration

func _test_scene_integration() -> void:
	var packed: Variant = load("res://scenes/world/Planet3D.tscn")
	check("scene loads", packed != null)
	if packed == null:
		return
	var scene: Node = (packed as PackedScene).instantiate()
	root.add_child(scene)
	# _ready fires on the first main-loop iteration in this context.
	await process_frame
	await process_frame
	var world: PlanetWorld = scene.get_node("WorldRoot")
	var manager: DomeManager = world.manager
	var ground: MeshInstance3D = scene.get_node("Ground")
	var mesh: PlaneMesh = ground.mesh as PlaneMesh
	check("ground is 210x210", mesh.size == Vector2(210, 210))
	check("ground has 64 subdiv", mesh.subdivide_width == 64 and mesh.subdivide_depth == 64)
	check("ground material is ground shader", ground.material_override != null and (ground.material_override as ShaderMaterial).shader != null)
	check("one dome bootstrapped", manager.count() == 1)
	var dw: DomeWorld = manager.world_at(0)
	check("dome rect derived from elevator", dw.rect.size == Vector2i(80, 80))
	check("dome1 topleft persisted to sim", dw.dome.topleft == dw.rect.position)
	check("day/night node present", world.day_night != null)
	# Day/night drives solar multiplier into the dome tune.
	world.day_night.t = 0.25
	world.day_night._process(0.016)
	check("noon daylight", world.day_night.daylight > 0.9)
	check("noon solar mult 1", absf(world.day_night.solar_multiplier - 1.0) < 0.01)
	world.day_night.t = 0.75
	world.day_night._process(0.016)
	check("midnight daylight", world.day_night.daylight < 0.5)
	check("midnight solar mult lowered", world.day_night.solar_multiplier < 0.6)
	world._process(0.016)
	var ds0: DomeSim = dw.dome
	check("dome tune carries solar_mult", ds0.tune.get("solar_mult", 1.0) < 0.6)
	# Pathing tests on the live dome.
	_test_pathing()
	# Placement matrix on the live world.
	var placement: PlacementSystem = world.placement
	_test_placement_matrix(manager, placement)
	# T2.4 elevator -> new dome flow.
	var elev_cell := Vector2i(-1, -1)
	for y in range(dw.rect.end.y + 2, 205):
		for x in range(20, 100):
			var vv: Dictionary = placement.validate(dw, "elevator", Vector2i(x, y), 0)
			if bool(vv.get("ok", false)):
				elev_cell = Vector2i(x, y)
				break
		if elev_cell.x >= 0:
			break
	check("elevator flow: valid cell found", elev_cell.x >= 0)
	if elev_cell.x >= 0:
		placement.start_placement("elevator")
		placement.set_ghost_cell(elev_cell)
		placement._try_confirm()
		check("elevator flow: two domes", manager.count() == 2)
		check("elevator flow: sim has two domes", world.sim_runtime.planet.domes.size() == 2)
		var dome2: DomeSim = world.sim_runtime.planet.domes[1]
		check("elevator flow: new dome has elevator", (dome2.by_type.get("elevator", []) as Array).size() == 1)
		check("elevator flow: dome2 rect no overlap", dw.rect.intersects((manager.world_at(1) as DomeWorld).rect) == false)
		check("elevator flow: save written", FileAccess.file_exists("user://slot0.json"))
		# Reload the save into a fresh PlanetSim: dome 2 must carry over.
		var saves: SaveSystem = SaveSystem.new()
		var loaded: Dictionary = saves.load_slot(0)
		check("save has planet_state", loaded.get("planet_state") is Dictionary)
		var planet2 := PlanetSim.new()
		planet2.setup("beginner", 1)
		check("save reload carries two domes", planet2.load_state(loaded["planet_state"]) and planet2.domes.size() == 2)
		var d2r: DomeSim = planet2.domes[1]
		check("save reload keeps dome2 topleft", d2r.topleft == (manager.world_at(1) as DomeWorld).rect.position)
	# Views synced for every building across domes.
	world._process(0.016)
	var total_buildings: int = 0
	for d in world.sim_runtime.planet.domes:
		total_buildings += (d as DomeSim).buildings.size()
	check("building views synced", world.views.size() == total_buildings)
	scene.queue_free()

# ---------------------------------------------------------------- mask spot check

func _test_mask_spot_check() -> void:
	var img := Image.load_from_file(ProjectSettings.globalize_path("res://assets/world/masks/logical_mask_a.png"))
	check("mask_a readable", img != null)
	if img == null:
		return
	check("mask_a is 210x210", img.get_size() == Vector2i(210, 210))
	var grid: Dictionary = DomeSim.load_json("res://data/grid.json")
	var ok := true
	var sample: int = 0
	for x in range(0, 210, 7):
		for y in range(0, 210, 7):
			var want_walk: bool = dome_prop(grid, "walkable", x, y)
			var want_mine: bool = dome_prop(grid, "mineable", x, y)
			var want_farm: bool = dome_prop(grid, "farmable", x, y)
			var want_ore: bool = dome_prop(grid, "oreMineable", x, y)
			var c: Color = img.get_pixel(x, y)
			var got_walk: bool = c.r > 0.5
			var got_mine: bool = c.g > 0.5
			var got_farm: bool = c.b > 0.5
			var got_ore: bool = c.a > 0.5
			sample += 1
			if want_walk != got_walk or want_mine != got_mine or want_farm != got_farm or want_ore != got_ore:
				ok = false
	check("mask matches logical grid spot check (" + str(sample) + " cells)", ok)

func dome_prop(grid: Dictionary, key: String, x: int, y: int) -> bool:
	var arr: Array = grid.get(key, [])
	for pair in arr:
		if pair is Array and (pair as Array).size() >= 2:
			var pa: Array = pair
			if int(pa[0]) == x and int(pa[1]) == y:
				return true
	return false
