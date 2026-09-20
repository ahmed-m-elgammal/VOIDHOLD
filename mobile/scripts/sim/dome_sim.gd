class_name DomeSim
extends RefCounted

const BUILDINGS_PATH := "res://data/buildings.json"
const BALANCE_PATH := "res://data/balance.json"
const GRID_PATH := "res://data/grid.json"
const TECH_PATH := "res://data/tech_tree.json"
const STEP_MS := 50
const SPAWN_MS := 40000
const CHECK_MS := 200
const COOLDOWN_MS := 10000
const CARRY := 15
const TILE := 16.0
const NEED_HAPPY := 0.8
const NEED_FULL := 0.8
const STORE_KEYS := ["stone", "alloy", "biomass", "ore", "stim"]
const STORE_TYPES := ["storage", "elevator"]
const LEGACY := {"money": "alloy", "nutrition": "biomass", "drugs": "stim"}

var grid: Dictionary = {}
var base_walk: Dictionary = {}
var buildings: Array = []
var units: Array = []
var by_guid: Dictionary = {}
var by_type: Dictionary = {}
var unit_by_guid: Dictionary = {}
var hauls: Dictionary = {}
var defs: Dictionary = {}
var tune: Dictionary = {}
var tech: Dictionary = {}
var prop_sets: Dictionary = {}
var spawn_acc_ms: int = 0
var check_acc_ms: int = 0
var next_guid: int = 1
var _dirty: bool = true
var _wu: UnitSim = null
var _unit_context: Dictionary = {"buildings": []}

static func load_json(path: String) -> Dictionary:
	var out: Dictionary = {}
	if FileAccess.file_exists(path) == false:
		return out
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return out
	var text: String = f.get_as_text()
	f.close()
	var p: JSON = JSON.new()
	if p.parse(text) != OK:
		return out
	if p.data is Dictionary:
		return p.data
	return out

static func norm_res(r: String) -> String:
	if LEGACY.has(r):
		return String(LEGACY[r])
	return r

static func cell_to_pos(cell: Vector2i) -> Vector2:
	return Vector2(float(cell.x) * TILE, float(cell.y) * TILE)

static func clamp01(v: float) -> float:
	return clampf(v, 0.0, 1.0)

static func sstr(v: Variant, fallback: String) -> String:
	if v == null:
		return fallback
	return String(v)

static func sint(v: Variant, fallback: int) -> int:
	if v == null:
		return fallback
	return int(v)

static func sfloat(v: Variant, fallback: float) -> float:
	if v == null:
		return fallback
	return float(v)

func setup() -> void:
	defs = load_json(BUILDINGS_PATH)
	tune = load_json(BALANCE_PATH)
	grid = load_json(GRID_PATH)
	tech = load_json(TECH_PATH)
	build_walk()
	rebuild_indices()
	_wu = UnitSim.new()
	_wu.castes = UnitSim.load_castes()
	_unit_context["buildings"] = buildings

func make_guid() -> int:
	var g: int = next_guid
	next_guid += 1
	return g

func pick_idx(n: int, rng: Rng) -> int:
	if n <= 1:
		return 0
	if rng == null:
		return 0
	return rng.next_int() % n

func bdef(kind: String) -> Dictionary:
	if defs.has(kind) and defs[kind] is Dictionary:
		return defs[kind]
	return {}

func tune_float(keys: Array, fallback: float) -> float:
	var cur: Variant = tune
	for k in keys:
		if cur is Dictionary and (cur as Dictionary).has(k):
			cur = (cur as Dictionary)[k]
		else:
			return fallback
	if cur is float or cur is int:
		return float(cur)
	return fallback

func energy_need(kind: String) -> float:
	var multiplier: float = maxf(0.0, tune_float(["energy_need_mult"], 1.0))
	return maxf(0.0, float(bdef(kind).get("energyNeed", 0.0)) * multiplier)

func build_walk() -> void:
	base_walk.clear()
	prop_sets.clear()
	var w: int = int(grid.get("width", 0))
	var h: int = int(grid.get("height", 0))
	if grid.has("walkable") and grid["walkable"] is Array:
		for pair in grid["walkable"]:
			if pair is Array and (pair as Array).size() >= 2:
				var pa: Array = pair
				var cell := Vector2i(int(pa[0]), int(pa[1]))
				base_walk[cell] = true
	for pname in ["mineable", "farmable", "oreMineable"]:
		var pset: Dictionary = {}
		if grid.has(pname) and grid[pname] is Array:
			for pair in grid[pname]:
				if pair is Array and (pair as Array).size() >= 2:
					var pa2: Array = pair
					pset[Vector2i(int(pa2[0]), int(pa2[1]))] = true
		prop_sets[pname] = pset
	if grid.has("walk") == false or not (grid["walk"] is Dictionary):
		grid["walk"] = {}
	var walk: Dictionary = grid["walk"]
	walk.clear()
	for k in base_walk.keys():
		walk[k] = true
	grid["width"] = w
	grid["height"] = h

func rebuild_walkability() -> void:
	build_walk()
	for value in buildings:
		if value is Dictionary:
			set_walk_rect(value, false)

func is_inside(cell: Vector2i) -> bool:
	if grid.has("walk") == false or not (grid["walk"] is Dictionary):
		return false
	var walk: Dictionary = grid["walk"]
	return walk.has(cell)

func is_walkable(cell: Vector2i) -> bool:
	if grid.has("walk") == false or not (grid["walk"] is Dictionary):
		return false
	var walk: Dictionary = grid["walk"]
	return bool(walk.get(cell, false))

func rebuild_indices() -> void:
	by_guid.clear()
	by_type.clear()
	unit_by_guid.clear()
	for b in buildings:
		if b is Dictionary and (b as Dictionary).has("guid"):
			var bd: Dictionary = b
			var g: int = int(bd["guid"])
			by_guid[g] = bd
			var t: String = String(bd.get("kind", ""))
			if by_type.has(t) == false:
				by_type[t] = []
			var arr: Array = by_type[t]
			arr.append(bd)
	for u in units:
		if u is Dictionary and (u as Dictionary).has("guid"):
			var ud: Dictionary = u
			unit_by_guid[int(ud["guid"])] = ud

func door_for(cell: Vector2i, w: int, h: int, rot: int, dw: int, dh: int) -> Vector2i:
	if rot == 1:
		return cell + Vector2i(0, 1)
	if rot == 2:
		return cell + Vector2i(dw - 1, 0)
	if rot == 3:
		return cell + Vector2i(dh - 1, dw - 1)
	return cell + Vector2i(1, dh - 1)

func make_building(kind: String, cell: Vector2i, rot: int) -> Dictionary:
	var d: Dictionary = bdef(kind)
	var dw: int = int(d.get("width", 3))
	var dh: int = int(d.get("height", 3))
	var w: int = dw
	var h: int = dh
	if rot % 2 == 1:
		w = dh
		h = dw
	var door: Vector2i = door_for(cell, w, h, rot, dw, dh)
	var pos: Vector2 = cell_to_pos(cell)
	var hub: Vector2 = cell_to_pos(cell + Vector2i(w, h) / 2)
	var upd: String = sstr(d.get("update", ""), "")
	var period: int = sint(d.get("updateDelta_ms", 0), 0)
	var out_res: String = ""
	var out_max: float = 0.0
	var out_pw: float = 0.0
	if d.get("output") is Dictionary:
		var o: Dictionary = d["output"]
		out_res = norm_res(String(o.get("resource", "")))
		out_max = float(o.get("max", 0))
		out_pw = float(o.get("perWorker", 0))
	var in_res: String = ""
	var in_pw: float = 0.0
	if d.get("input") is Dictionary:
		var io: Dictionary = d["input"]
		in_res = norm_res(String(io.get("resource", "")))
		in_pw = float(io.get("perWorker", 0))
	var b: Dictionary = {
		"guid": make_guid(),
		"kind": kind,
		"cell": cell,
		"w": w,
		"h": h,
		"rot": rot,
		"door": door,
		"pos": pos,
		"hub": hub,
		"damage": 0.0,
		"cool_ms": 0,
		"energy": true,
		"update_kind": upd,
		"period_ms": period,
		"left_ms": period,
		"out_store": 0.0,
		"out_res": out_res,
		"out_max": out_max,
		"out_pw": out_pw,
		"in_res": in_res,
		"in_pw": in_pw,
		"max_n": sint(d.get("maxWorkers", 0), 0),
		"user_n": sint(d.get("maxWorkers", 0), 0),
		"workers": [],
		"incoming": [],
		"go_workers": [],
		"go_incoming": [],
		"residents": [],
		"store": {"stone": 0.0, "alloy": 0.0, "biomass": 0.0, "ore": 0.0, "stim": 0.0},
		"imp": "",
		"exp": "",
		"foe": 0,
		"foe_in": 0,
		"foe_hp": 0.0,
		"foe_left_ms": 0,
		"linked": []
	}
	if kind == "elevator":
		var st: Dictionary = b["store"]
		st["alloy"] = 20.0
		st["stone"] = 60.0
		st["biomass"] = 30.0
		st["stim"] = 10.0
		st["ore"] = 0.0
	return b

func set_walk_rect(b: Dictionary, remove: bool) -> void:
	if grid.has("walk") == false or not (grid["walk"] is Dictionary):
		return
	var walk: Dictionary = grid["walk"]
	var cell: Vector2i = b["cell"]
	var w: int = int(b["w"])
	var h: int = int(b["h"])
	var door: Vector2i = b["door"]
	for x in range(cell.x, cell.x + w + 1):
		for y in range(cell.y, cell.y + h):
			var c := Vector2i(x, y)
			if c == door:
				continue
			if walk.has(c) == false and base_walk.has(c) == false:
				continue
			if remove:
				if base_walk.has(c):
					walk[c] = true
				else:
					walk.erase(c)
			else:
				walk[c] = false

func precondition_met(kind: String) -> bool:
	var req: String = ""
	if tech.has("preconditions") and (tech["preconditions"] as Dictionary).has(kind):
		req = sstr((tech["preconditions"] as Dictionary)[kind], "")
	if req == "":
		return true
	if by_type.has(req) == false:
		return false
	return ((by_type[req] as Array).is_empty() == false)

func footprint_free(cell: Vector2i, w: int, h: int) -> bool:
	if grid.has("walk") == false or not (grid["walk"] is Dictionary):
		return false
	var walk: Dictionary = grid["walk"]
	for x in range(cell.x, cell.x + w + 1):
		for y in range(cell.y, cell.y + h):
			var c := Vector2i(x, y)
			if bool(walk.get(c, false)) == false:
				return false
	return true

func footprint_has_prop(cell: Vector2i, w: int, h: int, pname: String) -> bool:
	if prop_sets.has(pname) == false:
		return false
	var pset: Dictionary = prop_sets[pname]
	for x in range(cell.x, cell.x + w):
		for y in range(cell.y, cell.y + h):
			if pset.has(Vector2i(x, y)):
				return true
	return false

func place(kind: String, cell: Vector2i, rot: int, master_guid: int) -> Dictionary:
	sync_indices()
	var d: Dictionary = bdef(kind)
	if d.is_empty():
		return {}
	if precondition_met(kind) == false:
		return {}
	var cost_s: float = float(d.get("stone", 0))
	var cost_a: float = float(d.get("alloy_cost", 0))
	if test_for("stone", cost_s) < cost_s:
		return {}
	if test_for("alloy", cost_a) < cost_a:
		return {}
	var dw: int = int(d.get("width", 3))
	var dh: int = int(d.get("height", 3))
	var w: int = dw
	var h: int = dh
	if rot % 2 == 1:
		w = dh
		h = dw
	if footprint_free(cell, w, h) == false:
		return {}
	if sstr(d.get("planetProperty", ""), "") != "":
		var pname: String = sstr(d.get("planetProperty", ""), "")
		var key: String = pname
		if key == "isMineable":
			key = "mineable"
		if key == "isFarmable":
			key = "farmable"
		if key == "isOreMineable":
			key = "oreMineable"
		if footprint_has_prop(cell, w, h, key) == false:
			return {}
	var master: Dictionary = {}
	if bool(d.get("isWorkerBuilding", false)):
		if master_guid == 0 or by_guid.has(master_guid) == false:
			return {}
		master = by_guid[master_guid]
		var pw: Dictionary = {}
		if d.get("perWorker") is Dictionary:
			pw = d["perWorker"]
		var want_link: String = String(pw.get("building", ""))
		if want_link == "":
			var md: Dictionary = bdef(String(master.get("kind", "")))
			if md.get("perWorker") is Dictionary:
				want_link = String((md["perWorker"] as Dictionary).get("building", ""))
		if want_link != kind:
			var md2: Dictionary = bdef(String(master.get("kind", "")))
			var ok: bool = false
			if md2.get("perWorker") is Dictionary and String((md2["perWorker"] as Dictionary).get("building", "")) == kind:
				ok = true
			if ok == false:
				return {}
		var radius: float = 20.0
		if d.get("perWorker") is Dictionary:
			radius = float((d["perWorker"] as Dictionary).get("maxRadius", 20.0))
		else:
			var md3: Dictionary = bdef(String(master.get("kind", "")))
			if md3.get("perWorker") is Dictionary:
				radius = float((md3["perWorker"] as Dictionary).get("maxRadius", 20.0))
		var mp: Vector2 = master["hub"]
		var np: Vector2 = cell_to_pos(cell)
		if mp.distance_to(np) > radius * TILE + float(maxi(w, h)) * TILE:
			return {}
		var slots: int = 0
		for g in master.get("linked", []):
			if by_guid.has(int(g)):
				slots += 1
		if slots >= maxi(1, max_workers(master)):
			return {}
	get_resource("stone", cost_s)
	get_resource("alloy", cost_a)
	var b: Dictionary = make_building(kind, cell, rot)
	set_walk_rect(b, false)
	if master.is_empty() == false:
		var lk: Array = master["linked"]
		lk.append(int(b["guid"]))
	buildings.append(b)
	_dirty = true
	return b

func sync_indices() -> void:
	if _dirty:
		_dirty = false
		rebuild_indices()

func step_units(rng: Rng) -> void:
	if _wu == null or units.is_empty():
		return
	_unit_context["buildings"] = buildings
	for value in units:
		if value is Dictionary:
			_wu.u = value
			_wu.step_20hz(_unit_context, rng)

func heal_refs() -> void:
	for b in buildings:
		if b is Dictionary == false:
			continue
		var bd: Dictionary = b
		for key in ["workers", "incoming", "go_workers", "go_incoming", "residents"]:
			var arr: Array = bd.get(key, [])
			var kept: Array = []
			for g in arr:
				if unit_by_guid.has(int(g)):
					kept.append(int(g))
			bd[key] = kept
		var lk: Array = bd.get("linked", [])
		var kept_l: Array = []
		for g in lk:
			if by_guid.has(int(g)):
				kept_l.append(int(g))
		bd["linked"] = kept_l
		if sfloat(bd.get("foe_hp", 1.0), 0.0) <= 0.0:
			bd["foe"] = 0
			bd["foe_in"] = 0
			bd["foe_hp"] = 0.0
			bd["foe_left_ms"] = 0
		for hg in hauls.keys():
			var haul: Dictionary = hauls[hg]
			if int(haul.get("origin", 0)) != 0 and by_guid.has(int(haul.get("origin", 0))) == false:
				hauls.erase(hg)

func unplace(guid: int) -> void:
	if by_guid.has(guid) == false:
		return
	var b: Dictionary = by_guid[guid]
	set_walk_rect(b, true)
	var wb: Array = (b.get("workers", []) as Array).duplicate()
	var ib: Array = (b.get("incoming", []) as Array).duplicate()
	for g in wb:
		worker_cancel(guid, int(g))
	for g in ib:
		worker_cancel(guid, int(g))
	var gb: Array = (b.get("go_workers", []) as Array).duplicate()
	var gib: Array = (b.get("go_incoming", []) as Array).duplicate()
	for g in gb:
		mission_cancel(guid, int(g))
	for g in gib:
		mission_cancel(guid, int(g))
	if int(b.get("foe", 0)) != 0 or int(b.get("foe_in", 0)) != 0:
		b["foe"] = 0
		b["foe_in"] = 0
		b["foe_hp"] = 0.0
		b["foe_left_ms"] = 0
	for o in buildings:
		if o is Dictionary:
			var od: Dictionary = o
			var lk: Array = od.get("linked", [])
			var kept: Array = []
			for g in lk:
				if int(g) != guid:
					kept.append(int(g))
			od["linked"] = kept
	var kept_b: Array = []
	for o in buildings:
		if o is Dictionary and int((o as Dictionary).get("guid", 0)) != guid:
			kept_b.append(o)
	buildings = kept_b
	for u in units:
		if u is Dictionary:
			var ud: Dictionary = u
			if int(ud.get("home", 0)) == guid:
				ud["send_home"] = true
	_dirty = true
	sync_indices()
	heal_refs()

func store_houses() -> Array:
	var out: Array = []
	for b in buildings:
		if b is Dictionary:
			var t: String = String((b as Dictionary).get("kind", ""))
			if t == "storage" or t == "elevator":
				out.append(b)
	return out

func sort_by_store_desc(arr: Array, res: String) -> void:
	arr.sort_custom(func(a: Variant, b: Variant) -> bool:
		var va: float = 0.0
		var vb: float = 0.0
		var ga: int = 0
		var gb: int = 0
		if a is Dictionary:
			va = float((a as Dictionary).get("store", {}).get(res, 0.0))
			ga = int((a as Dictionary).get("guid", 0))
		if b is Dictionary:
			vb = float((b as Dictionary).get("store", {}).get(res, 0.0))
			gb = int((b as Dictionary).get("guid", 0))
		if va != vb:
			return va > vb
		return ga < gb)

func store_amount(b: Variant, res: String) -> float:
	if b is Dictionary == false:
		return 0.0
	var bd: Dictionary = b
	if bd.get("store") is Dictionary == false:
		return 0.0
	var st: Dictionary = bd["store"]
	return float(st.get(res, 0.0))

func test_for(res: String, amount: float) -> float:
	res = norm_res(res)
	var houses: Array = store_houses()
	if houses.is_empty():
		return 0.0
	sort_by_store_desc(houses, res)
	var total: float = 0.0
	for b in houses:
		total += store_amount(b, res)
	if total <= 0.0:
		return 0.0
	return minf(amount, total)

func total_of(res: String) -> float:
	res = norm_res(res)
	var total: float = 0.0
	for b in store_houses():
		total += store_amount(b, res)
	return total

func get_resource(res: String, amount: float) -> float:
	res = norm_res(res)
	if amount <= 0.0:
		return 0.0
	var houses: Array = store_houses()
	if houses.is_empty():
		return 0.0
	sort_by_store_desc(houses, res)
	var missing: float = amount
	for b in houses:
		if missing <= 0.0:
			break
		var bd: Dictionary = b
		var st: Dictionary = bd["store"]
		var have: float = float(st.get(res, 0.0))
		var take: float = minf(have, missing)
		st[res] = have - take
		missing -= take
	return amount - missing

func energy_saturation() -> float:
	var per: float = tune_float(["energy", "per_solar"], 1.5)
	var solar: float = 0.0
	var need: float = 0.0
	for b in buildings:
		if b is Dictionary == false:
			continue
		var bd: Dictionary = b
		var kind: String = String(bd.get("kind", ""))
		if kind == "solar":
			solar += (1.0 - float(bd.get("damage", 0.0))) * per
		need += energy_need(kind)
	if need <= 0.0:
		return 1.0
	return solar / need

func step_energy(rng: Rng) -> void:
	var per: float = tune_float(["energy", "per_solar"], 1.5)
	var solar: float = 0.0
	var need: float = 0.0
	for b in buildings:
		if b is Dictionary == false:
			continue
		var bd: Dictionary = b
		if String(bd.get("kind", "")) == "solar":
			solar += (1.0 - float(bd.get("damage", 0.0))) * per
		need += energy_need(String(bd.get("kind", "")))
	if need <= solar:
		for b in buildings:
			if b is Dictionary:
				(b as Dictionary)["energy"] = true
		return
	var live_need: float = 0.0
	for b in buildings:
		if b is Dictionary and bool((b as Dictionary).get("energy", true)):
			live_need += energy_need(String((b as Dictionary).get("kind", "")))
	var guard: int = 0
	while live_need > solar and guard < buildings.size():
		guard += 1
		var cand: Array = []
		for b in buildings:
			if b is Dictionary == false:
				continue
			var bd: Dictionary = b
			if bool(bd.get("energy", true)) and energy_need(String(bd.get("kind", ""))) > 0.0:
				cand.append(bd)
		if cand.is_empty():
			break
		cand.sort_custom(func(a: Variant, b: Variant) -> bool:
			return int((a as Dictionary).get("guid", 0)) < int((b as Dictionary).get("guid", 0)))
		var pick: Dictionary = cand[pick_idx(cand.size(), rng)]
		pick["energy"] = false
		live_need = 0.0
		for b in buildings:
			if b is Dictionary and bool((b as Dictionary).get("energy", true)):
				live_need += energy_need(String((b as Dictionary).get("kind", "")))

func oxygen_raw() -> float:
	var need_multiplier: float = maxf(0.0, tune_float(["oxygen_need_mult"], 1.0))
	var per_b: float = tune_float(["oxygen", "per_building"], 0.05) * need_multiplier
	var per_u: float = tune_float(["oxygen", "per_unit"], 0.15) * need_multiplier
	var min_need: float = tune_float(["oxygen", "min_need"], 1.0)
	var oxy: int = 0
	for b in buildings:
		if b is Dictionary == false:
			continue
		var bd: Dictionary = b
		if String(bd.get("kind", "")) == "oxygen" and float(bd.get("damage", 0.0)) < 1.0 and bool(bd.get("energy", true)) and int(bd.get("foe", 0)) == 0:
			oxy += 1
	var need: float = float(buildings.size()) * per_b + float(units.size()) * per_u
	if need <= 0.0:
		need = min_need
	if need <= 0.0:
		need = 1.0
	return float(oxy) / need

func oxygen_saturation() -> float:
	return clampf(oxygen_raw(), 0.0, 1.0)

func apply_damage(b: Dictionary, amount: float) -> void:
	if amount == 0.0:
		return
	if amount > 0.0:
		if float(b.get("damage", 0.0)) >= 1.0:
			return
		if int(b.get("cool_ms", 0)) > 0:
			return
		b["damage"] = clamp01(float(b.get("damage", 0.0)) + amount)
	else:
		b["damage"] = clamp01(float(b.get("damage", 0.0)) + amount)

func is_functional(b: Dictionary) -> bool:
	if float(b.get("damage", 0.0)) >= 1.0:
		return false
	if bool(b.get("energy", true)) == false:
		return false
	if int(b.get("foe", 0)) != 0:
		return false
	var kind: String = String(b.get("kind", ""))
	var d: Dictionary = bdef(kind)
	if String(b.get("out_res", "")) != "" and float(b.get("out_max", 0.0)) > 0.0:
		if float(b.get("out_store", 0.0)) >= float(b.get("out_max", 0.0)):
			return false
	if String(b.get("in_res", "")) != "":
		var per: float = float(b.get("in_pw", 0.0))
		var n: int = (b.get("workers", []) as Array).size() + (b.get("incoming", []) as Array).size() + 1
		var want: float = per * float(n)
		if test_for(String(b.get("in_res", "")), want) <= 0.0:
			return false
	if kind == "maintenance":
		if test_for("stone", 1.0) <= 0.0:
			return false
	return true

func avg_workers(b: Dictionary) -> Array:
	var fh: float = 0.0
	var ff: float = 0.0
	var n: int = 0
	for g in b.get("workers", []):
		if unit_by_guid.has(int(g)):
			var ud: Dictionary = unit_by_guid[int(g)]
			fh += float(ud.get("happy", 0.0))
			ff += float(ud.get("full", 0.0))
			n += 1
	if n == 0:
		return [0.0, 0.0]
	return [fh / float(n), ff / float(n)]

func productivity(b: Dictionary) -> float:
	var av: Array = avg_workers(b)
	var fh: float = float(av[0])
	var ff: float = float(av[1])
	var base: float = tune_float(["productivity", "base"], 0.5)
	var wh: float = tune_float(["productivity", "happiness_weight"], 0.25)
	var wf: float = tune_float(["productivity", "fullness_weight"], 0.25)
	var wo: float = tune_float(["productivity", "oxygen_weight"], 0.5)
	var oxy: float = oxygen_saturation()
	return (base + wf * ff + wh * fh) * (1.0 - float(b.get("damage", 0.0))) * ((oxy * wo) + (1.0 - wo))

func max_workers(b: Dictionary) -> int:
	var kind: String = String(b.get("kind", ""))
	var d: Dictionary = bdef(kind)
	var cap: int = sint(d.get("maxWorkers", 0), 0)
	var user_n: int = int(b.get("user_n", cap))
	var need_b: String = ""
	if d.get("perWorker") is Dictionary:
		need_b = String((d["perWorker"] as Dictionary).get("building", ""))
	var have: int = 999999
	if need_b != "":
		have = 0
		for g in b.get("linked", []):
			if by_guid.has(int(g)) and String((by_guid[int(g)] as Dictionary).get("kind", "")) == need_b:
				have += 1
	return mini(user_n, mini(have, cap))

func can_worker_reserve(b: Dictionary) -> bool:
	var cur: int = (b.get("workers", []) as Array).size() + (b.get("incoming", []) as Array).size()
	if cur >= max_workers(b):
		return false
	var kind: String = String(b.get("kind", ""))
	if String(b.get("in_res", "")) != "":
		var want: float = float(b.get("in_pw", 0.0)) * float(cur + 1)
		if test_for(String(b.get("in_res", "")), want) <= 0.0:
			return false
	if kind == "teleport":
		if String(b.get("exp", "")) == "":
			return false
		if test_for(String(b.get("exp", "")), 5.0) <= 0.0:
			return false
	if kind == "storage":
		return find_fetch_source() != 0
	return true

func worker_reserve(b_guid: int, u_guid: int) -> bool:
	if by_guid.has(b_guid) == false or unit_by_guid.has(u_guid) == false:
		return false
	var b: Dictionary = by_guid[b_guid]
	if can_worker_reserve(b) == false:
		return false
	var arr: Array = b["incoming"]
	if arr.has(u_guid) == false:
		arr.append(u_guid)
	return true

func worker_enter(b_guid: int, u_guid: int) -> void:
	if by_guid.has(b_guid) == false:
		return
	var b: Dictionary = by_guid[b_guid]
	var inc: Array = b["incoming"]
	var kept: Array = []
	for g in inc:
		if int(g) != u_guid:
			kept.append(int(g))
	b["incoming"] = kept
	var w: Array = b["workers"]
	if w.has(u_guid) == false:
		w.append(u_guid)
	if String(b.get("kind", "")) == "elevator" and unit_by_guid.has(u_guid):
		(unit_by_guid[u_guid] as Dictionary)["gone"] = true

func worker_exit(b_guid: int, u_guid: int) -> void:
	if by_guid.has(b_guid) == false:
		return
	var b: Dictionary = by_guid[b_guid]
	var w: Array = b["workers"]
	var kept: Array = []
	for g in w:
		if int(g) != u_guid:
			kept.append(int(g))
	b["workers"] = kept

func worker_cancel(b_guid: int, u_guid: int) -> void:
	if by_guid.has(b_guid) == false:
		return
	var b: Dictionary = by_guid[b_guid]
	for key in ["workers", "incoming"]:
		var arr: Array = b[key]
		var kept: Array = []
		for g in arr:
			if int(g) != u_guid:
				kept.append(int(g))
		b[key] = kept

func can_mission_reserve(b: Dictionary) -> bool:
	var cap: int = 1
	if String(b.get("kind", "")) == "storage":
		cap = maxi(1, int(b.get("max_n", 1)))
	var cur: int = (b.get("go_workers", []) as Array).size() + (b.get("go_incoming", []) as Array).size()
	return cur < cap

func mission_reserve(b_guid: int, u_guid: int) -> bool:
	if by_guid.has(b_guid) == false:
		return false
	var b: Dictionary = by_guid[b_guid]
	if can_mission_reserve(b) == false:
		return false
	var arr: Array = b["go_incoming"]
	if arr.has(u_guid) == false:
		arr.append(u_guid)
	return true

func mission_enter(b_guid: int, u_guid: int) -> void:
	if by_guid.has(b_guid) == false:
		return
	var b: Dictionary = by_guid[b_guid]
	var arr: Array = b["go_incoming"]
	var kept: Array = []
	for g in arr:
		if int(g) != u_guid:
			kept.append(int(g))
	b["go_incoming"] = kept
	var w: Array = b["go_workers"]
	if w.has(u_guid) == false:
		w.append(u_guid)

func mission_exit(b_guid: int, u_guid: int) -> void:
	if by_guid.has(b_guid) == false:
		return
	var b: Dictionary = by_guid[b_guid]
	var w: Array = b["go_workers"]
	var kept: Array = []
	for g in w:
		if int(g) != u_guid:
			kept.append(int(g))
	b["go_workers"] = kept
	if hauls.has(u_guid) == false:
		return
	var haul: Dictionary = hauls[u_guid]
	var mode: String = String(haul.get("mode", ""))
	if mode == "fetch":
		var res: String = ""
		var amount: float = 0.0
		if String(b.get("kind", "")) == "teleport" and String(b.get("imp", "")) != "":
			res = String(b.get("imp", ""))
			var st: Dictionary = b["store"]
			amount = minf(float(CARRY), float(st.get(res, 0.0)))
			st[res] = float(st.get(res, 0.0)) - amount
		elif String(haul.get("res", "")) != "":
			res = String(haul.get("res", ""))
			var st2: Dictionary = b["store"]
			amount = minf(float(CARRY), float(st2.get(res, 0.0)))
			st2[res] = float(st2.get(res, 0.0)) - amount
		else:
			res = String(b.get("out_res", ""))
			amount = minf(float(CARRY), float(b.get("out_store", 0.0)))
			b["out_store"] = float(b.get("out_store", 0.0)) - amount
		haul["mode"] = "store"
		haul["res"] = res
		haul["amount"] = amount
	elif mode == "store":
		var res2: String = String(haul.get("res", ""))
		var amount2: float = float(haul.get("amount", 0.0))
		if res2 != "" and amount2 > 0.0:
			var st3: Dictionary = b["store"]
			st3[res2] = float(st3.get(res2, 0.0)) + amount2
		hauls.erase(u_guid)
	else:
		hauls.erase(u_guid)

func mission_cancel(b_guid: int, u_guid: int) -> void:
	if by_guid.has(b_guid) == false:
		if hauls.has(u_guid):
			hauls.erase(u_guid)
		return
	var b: Dictionary = by_guid[b_guid]
	for key in ["go_workers", "go_incoming"]:
		var arr: Array = b[key]
		var kept: Array = []
		for g in arr:
			if int(g) != u_guid:
				kept.append(int(g))
		b[key] = kept
	if hauls.has(u_guid):
		hauls.erase(u_guid)

func incident_reserve(b_guid: int, foe_guid: int) -> bool:
	if by_guid.has(b_guid) == false:
		return false
	var b: Dictionary = by_guid[b_guid]
	if int(b.get("foe", 0)) != 0 or int(b.get("foe_in", 0)) != 0:
		return false
	b["foe_in"] = foe_guid
	b["foe_hp"] = 1.0
	return true

func incident_enter(b_guid: int, foe_guid: int) -> void:
	if by_guid.has(b_guid) == false:
		return
	var b: Dictionary = by_guid[b_guid]
	b["foe_in"] = 0
	b["foe"] = foe_guid
	b["foe_hp"] = 1.0

func incident_exit(b_guid: int) -> void:
	if by_guid.has(b_guid) == false:
		return
	var b: Dictionary = by_guid[b_guid]
	b["foe_left_ms"] = 0
	b["foe"] = 0
	b["foe_in"] = 0
	b["foe_hp"] = 0.0

func incident_cancel(b_guid: int) -> void:
	if by_guid.has(b_guid) == false:
		return
	var b: Dictionary = by_guid[b_guid]
	b["foe"] = 0
	b["foe_in"] = 0
	b["foe_hp"] = 0.0
	b["foe_left_ms"] = 0

func has_repair_need() -> bool:
	var need: int = 0
	for b in buildings:
		if b is Dictionary and float((b as Dictionary).get("damage", 0.0)) > 0.1:
			need += 1
	var busy: int = 0
	for b in buildings:
		if b is Dictionary and String((b as Dictionary).get("kind", "")) == "maintenance":
			busy += ((b as Dictionary).get("workers", []) as Array).size() + ((b as Dictionary).get("incoming", []) as Array).size()
	return busy < need

func has_incident_need() -> bool:
	var need: int = 0
	for b in buildings:
		if b is Dictionary and (int((b as Dictionary).get("foe", 0)) != 0 or int((b as Dictionary).get("foe_in", 0)) != 0):
			need += 1
	var busy: int = 0
	for b in buildings:
		if b is Dictionary and String((b as Dictionary).get("kind", "")) == "authority":
			busy += ((b as Dictionary).get("workers", []) as Array).size() + ((b as Dictionary).get("incoming", []) as Array).size()
	return busy < need

func has_storage_todo() -> bool:
	var busy: int = 0
	for b in buildings:
		if b is Dictionary and String((b as Dictionary).get("kind", "")) == "storage":
			busy += ((b as Dictionary).get("workers", []) as Array).size() + ((b as Dictionary).get("incoming", []) as Array).size()
	var piles: int = 0
	for b in buildings:
		if b is Dictionary == false:
			continue
		var bd: Dictionary = b
		if float(bd.get("out_store", 0.0)) > 0.0:
			piles += 1
		elif String(bd.get("imp", "")) != "" and float((bd.get("store", {}) as Dictionary).get(String(bd.get("imp", "")), 0.0)) > 0.0:
			piles += 1
	return busy < piles

func avg_happiness() -> float:
	if units.is_empty():
		return 0.0
	var s: float = 0.0
	for u in units:
		if u is Dictionary:
			s += float((u as Dictionary).get("happy", 0.0))
	return s / float(units.size())

func avg_fullness() -> float:
	if units.is_empty():
		return 0.0
	var s: float = 0.0
	for u in units:
		if u is Dictionary:
			s += float((u as Dictionary).get("full", 0.0))
	return s / float(units.size())

func can_spawn() -> bool:
	if units.is_empty():
		return true
	return avg_happiness() > NEED_HAPPY and avg_fullness() > NEED_FULL

func functional_of(kind: String) -> Array:
	var out: Array = []
	if by_type.has(kind):
		for b in by_type[kind]:
			if b is Dictionary and is_functional(b):
				out.append(b)
	return out

func sort_by_dist2(arr: Array, pos: Vector2) -> void:
	arr.sort_custom(func(a: Variant, b: Variant) -> bool:
		var pa: Vector2 = pos
		var pb: Vector2 = pos
		var ga: int = 0
		var gb: int = 0
		if a is Dictionary:
			pa = (a as Dictionary)["hub"]
			ga = int((a as Dictionary).get("guid", 0))
		if b is Dictionary:
			pb = (b as Dictionary)["hub"]
			gb = int((b as Dictionary).get("guid", 0))
		var da: float = pos.distance_squared_to(pa)
		var db: float = pos.distance_squared_to(pb)
		if da != db:
			return da < db
		return ga < gb)

func spawn_tick(rng: Rng) -> void:
	var lifts: Array = functional_of("elevator")
	if lifts.is_empty():
		return
	if can_spawn() == false:
		return
	var order: Array = ["helot", "mighty"]
	for caste in order:
		var home_kind: String = "living"
		if caste == "mighty":
			home_kind = "quarter"
		var homes: Array = functional_of(home_kind)
		if homes.is_empty():
			continue
		var cap: int = 0
		for h in homes:
			cap += maxi(0, max_workers(h))
		var have: int = 0
		for u in units:
			if u is Dictionary and String((u as Dictionary).get("caste", "")) == caste:
				have += 1
		if cap <= have:
			continue
		var free: Array = []
		for h in homes:
			var hd: Dictionary = h
			if ((hd.get("residents", []) as Array).size() < maxi(1, max_workers(hd))):
				free.append(hd)
		if free.is_empty():
			continue
		var lift: Dictionary = lifts[pick_idx(lifts.size(), rng)]
		var g: int = make_guid()
		var settler: Dictionary = {
			"guid": g,
			"caste": caste,
			"pos": lift["hub"],
			"happy": 1.0,
			"full": 1.0,
			"home": int((free[0] as Dictionary)["guid"]),
			"gone": false,
			"send_home": false
		}
		units.append(settler)
		unit_by_guid[g] = settler
		var rh: Array = (free[0] as Dictionary)["residents"]
		rh.append(g)
		return

func find_fetch_source() -> int:
	var best_g: int = 0
	var best_v: float = 0.0
	for b in buildings:
		if b is Dictionary == false:
			continue
		var bd: Dictionary = b
		if int(bd.get("foe", 0)) != 0:
			continue
		var v: float = float(bd.get("out_store", 0.0))
		var g: int = int(bd.get("guid", 0))
		if v > best_v or (v == best_v and v > 0.0 and (best_g == 0 or g < best_g)):
			best_v = v
			best_g = g
	return best_g

func step_gather(b: Dictionary) -> void:
	var n: int = mini(max_workers(b), (b.get("workers", []) as Array).size())
	if n <= 0:
		return
	var prod: float = productivity(b)
	var out: float = ceil(float(b.get("out_pw", 0.0)) * float(n) * prod)
	for g in b.get("workers", []):
		if unit_by_guid.has(int(g)):
			var ud: Dictionary = unit_by_guid[int(g)]
			ud["full"] = clamp01(float(ud.get("full", 0.0)) + sfloat(bdef(String(b.get("kind", ""))).get("workerFullness", 0.0), 0.0))
			ud["happy"] = clamp01(float(ud.get("happy", 0.0)) + sfloat(bdef(String(b.get("kind", ""))).get("workerHappiness", 0.0), 0.0))
	var d: Dictionary = bdef(String(b.get("kind", "")))
	if out > 0.0 and d.get("damages") is Dictionary and sfloat((d["damages"] as Dictionary).get("update", 0.0), 0.0) > 0.0:
		apply_damage(b, sfloat((d["damages"] as Dictionary).get("update", 0.0), 0.0) * (float((b.get("workers", []) as Array).size()) / float(maxi(1, int(b.get("max_n", 1))))))
	var room: float = float(b.get("out_max", 0.0)) - float(b.get("out_store", 0.0))
	b["out_store"] = float(b.get("out_store", 0.0)) + minf(out, maxf(0.0, room))

func step_produce(b: Dictionary) -> void:
	var n: int = (b.get("workers", []) as Array).size()
	if n <= 0:
		return
	var prod: float = productivity(b)
	var max_in: float = prod * float(n) * float(b.get("in_pw", 0.0))
	if max_in <= 0.0:
		return
	var got: float = get_resource(String(b.get("in_res", "")), max_in)
	var f: float = 0.0
	if max_in > 0.0:
		f = got / max_in
	for g in b.get("workers", []):
		if unit_by_guid.has(int(g)):
			var ud: Dictionary = unit_by_guid[int(g)]
			ud["full"] = clamp01(float(ud.get("full", 0.0)) + sfloat(bdef(String(b.get("kind", ""))).get("workerFullness", 0.0), 0.0))
			ud["happy"] = clamp01(float(ud.get("happy", 0.0)) + sfloat(bdef(String(b.get("kind", ""))).get("workerHappiness", 0.0), 0.0))
	var out: float = ceil(f * prod * float(n) * float(b.get("out_pw", 0.0)))
	var room: float = float(b.get("out_max", 0.0)) - float(b.get("out_store", 0.0))
	b["out_store"] = float(b.get("out_store", 0.0)) + minf(out, maxf(0.0, room))
	var d: Dictionary = bdef(String(b.get("kind", "")))
	if out > 0.0 and d.get("damages") is Dictionary and sfloat((d["damages"] as Dictionary).get("update", 0.0), 0.0) > 0.0:
		apply_damage(b, sfloat((d["damages"] as Dictionary).get("update", 0.0), 0.0) * (float(n) / float(maxi(1, int(b.get("max_n", 1))))))

func step_eat(b: Dictionary) -> void:
	var hungry: int = 0
	for g in b.get("workers", []):
		if unit_by_guid.has(int(g)) and float((unit_by_guid[int(g)] as Dictionary).get("full", 0.0)) < 1.0:
			hungry += 1
	if hungry <= 0:
		return
	var max_in: float = float(hungry) * float(b.get("in_pw", 1.0))
	var got: float = get_resource(String(b.get("in_res", "")), max_in)
	var miss: int = 0
	if float(b.get("in_pw", 1.0)) > 0.0:
		miss = int(round((max_in - got) / float(b.get("in_pw", 1.0))))
	var idx: int = 0
	for g in b.get("workers", []):
		if unit_by_guid.has(int(g)) == false:
			idx += 1
			continue
		var ud: Dictionary = unit_by_guid[int(g)]
		if idx >= miss:
			ud["full"] = clamp01(float(ud.get("full", 0.0)) + sfloat(bdef(String(b.get("kind", ""))).get("addFullness", 0.1), 0.1))
		else:
			ud["happy"] = clamp01(float(ud.get("happy", 0.0)) - 0.1)
		idx += 1
	var d: Dictionary = bdef(String(b.get("kind", "")))
	if got > 0.0 and d.get("damages") is Dictionary and sfloat((d["damages"] as Dictionary).get("update", 0.0), 0.0) > 0.0:
		apply_damage(b, sfloat((d["damages"] as Dictionary).get("update", 0.0), 0.0) * (float((b.get("workers", []) as Array).size()) / float(maxi(1, int(b.get("max_n", 1))))))

func step_relax(b: Dictionary) -> void:
	var prod: float = 1.0 - float(b.get("damage", 0.0))
	var out: float = sfloat(bdef(String(b.get("kind", ""))).get("improveHappiness", 0.0), 0.0) * prod
	if out <= 0.0:
		return
	var pool: float = 999999.0
	if String(b.get("in_res", "")) != "":
		var want: float = float((b.get("workers", []) as Array).size()) * float(b.get("in_pw", 0.0))
		pool = get_resource(String(b.get("in_res", "")), want)
	var d: Dictionary = bdef(String(b.get("kind", "")))
	if d.get("damages") is Dictionary and sfloat((d["damages"] as Dictionary).get("update", 0.0), 0.0) > 0.0:
		apply_damage(b, sfloat((d["damages"] as Dictionary).get("update", 0.0), 0.0) * (float((b.get("workers", []) as Array).size()) / float(maxi(1, int(b.get("max_n", 1))))))
	for g in b.get("workers", []):
		if unit_by_guid.has(int(g)) == false:
			continue
		if pool <= 0.0 and String(b.get("in_res", "")) != "":
			continue
		if String(b.get("in_res", "")) != "":
			pool -= float(b.get("in_pw", 0.0))
		var ud: Dictionary = unit_by_guid[int(g)]
		ud["happy"] = clamp01(float(ud.get("happy", 0.0)) + out)

func step_repair(b: Dictionary) -> void:
	if (b.get("workers", []) as Array).is_empty():
		return
	if has_repair_need() == false:
		return
	var hurt: Array = []
	for o in buildings:
		if o is Dictionary and float((o as Dictionary).get("damage", 0.0)) > 0.01:
			hurt.append(o)
	if hurt.is_empty():
		return
	sort_by_dist2(hurt, b["hub"])
	var target: Dictionary = hurt[0]
	var cap: float = minf(0.5, float(target.get("damage", 0.0))) * 2.0
	var paid: float = get_resource("stone", cap)
	if paid <= 0.0:
		return
	target["damage"] = clamp01(float(target.get("damage", 0.0)) - paid)
	target["cool_ms"] = COOLDOWN_MS
	if float(target.get("damage", 0.0)) <= 0.1:
		target["damage"] = 0.0
	for g in b.get("workers", []):
		if unit_by_guid.has(int(g)):
			var ud: Dictionary = unit_by_guid[int(g)]
			ud["full"] = clamp01(float(ud.get("full", 0.0)) + sfloat(bdef("maintenance").get("workerFullness", 0.0), 0.0))
			ud["happy"] = clamp01(float(ud.get("happy", 0.0)) + sfloat(bdef("maintenance").get("workerHappiness", 0.0), 0.0))

func step_incident(b: Dictionary) -> void:
	if (b.get("workers", []) as Array).is_empty():
		return
	var hit: float = tune_float(["authority", "damage_per_update"], 0.2)
	var rpx: float = tune_float(["authority", "range_px"], 80.0)
	var r2: float = rpx * rpx
	var done: bool = false
	for worker_guid in b.get("workers", []):
		if unit_by_guid.has(int(worker_guid)) == false:
			continue
		var worker: Dictionary = unit_by_guid[int(worker_guid)]
		if String(worker.get("job_kind", "")) != "incident" or bool(worker.get("job_done", false)) == false:
			continue
		var target_guid: int = int(worker.get("job_house", 0))
		if by_guid.has(target_guid) == false:
			continue
		var target: Dictionary = by_guid[target_guid]
		if int(target.get("foe", 0)) == 0:
			continue
		var worker_pos: Vector2 = worker.get("pos", b["hub"])
		if worker_pos.distance_squared_to(target["hub"]) > r2 and b["hub"].distance_squared_to(target["hub"]) > r2:
			continue
		target["foe_hp"] = sfloat(target.get("foe_hp", 1.0), 0.0) - hit
		if sfloat(target.get("foe_hp", 0.0), 0.0) <= 0.0:
			incident_exit(target_guid)
		done = true
	if done:
		for g in b.get("workers", []):
			if unit_by_guid.has(int(g)):
				var ud: Dictionary = unit_by_guid[int(g)]
				ud["full"] = clamp01(float(ud.get("full", 0.0)) + sfloat(bdef("authority").get("workerFullness", 0.0), 0.0))
				ud["happy"] = clamp01(float(ud.get("happy", 0.0)) + sfloat(bdef("authority").get("workerHappiness", 0.0), 0.0))

func step_storage(b: Dictionary) -> void:
	if (b.get("workers", []) as Array).is_empty():
		return
	var src_g: int = find_fetch_source()
	if src_g == 0 or by_guid.has(src_g) == false:
		return
	var src: Dictionary = by_guid[src_g]
	var res: String = String(src.get("out_res", ""))
	if res == "" or float(src.get("out_store", 0.0)) <= 0.0:
		return
	var st: Dictionary = b["store"]
	var room: float = float(bdef("storage").get("maxStorage", 160.0)) - store_sum(st)
	if room <= 0.0:
		return
	var move: float = minf(float(CARRY), minf(float(src.get("out_store", 0.0)), room))
	src["out_store"] = float(src.get("out_store", 0.0)) - move
	st[res] = float(st.get(res, 0.0)) + move

func store_sum(st: Dictionary) -> float:
	var s: float = 0.0
	for k in STORE_KEYS:
		s += float(st.get(k, 0.0))
	return s

func step_teleport(b: Dictionary) -> void:
	if (b.get("workers", []) as Array).is_empty():
		return
	var ex: String = String(b.get("exp", ""))
	if ex == "":
		return
	var st: Dictionary = b["store"]
	var room: float = float(bdef("teleport").get("maxStorage", 48.0)) - store_sum(st)
	if room <= 0.0:
		return
	var move: float = minf(5.0, minf(test_for(ex, 5.0), room))
	if move <= 0.0:
		return
	var got: float = get_resource(ex, move)
	st[ex] = float(st.get(ex, 0.0)) + got

func step_building(b: Dictionary) -> void:
	var kind: String = String(b.get("update_kind", ""))
	if kind == "gather":
		step_gather(b)
	elif kind == "produce":
		step_produce(b)
	elif kind == "eat":
		step_eat(b)
	elif kind == "relax":
		step_relax(b)
	elif kind == "repair":
		step_repair(b)
	elif kind == "incident":
		step_incident(b)
	elif kind == "storage":
		step_storage(b)
	elif kind == "teleport":
		step_teleport(b)

func step_20hz(rng: Rng) -> void:
	sync_indices()
	step_units(rng)
	var dt: float = float(STEP_MS) / 1000.0
	var foe_dps: float = tune_float(["enemy", "damage_per_sec"], 0.01) * maxf(0.0, tune_float(["enemy_damage_mult"], 1.0))
	for b in buildings:
		if b is Dictionary == false:
			continue
		var bd: Dictionary = b
		if int(bd.get("cool_ms", 0)) > 0:
			bd["cool_ms"] = maxi(0, int(bd.get("cool_ms", 0)) - STEP_MS)
		var d: Dictionary = bdef(String(bd.get("kind", "")))
		if d.get("damages") is Dictionary:
			var c: float = sfloat((d["damages"] as Dictionary).get("constant", 0.0), 0.0)
			if c > 0.0:
				apply_damage(bd, c * dt)
		if int(bd.get("foe", 0)) != 0:
			apply_damage(bd, foe_dps * dt)
		if String(bd.get("update_kind", "")) == "":
			continue
		if ((bd.get("workers", []) as Array).is_empty()):
			bd["left_ms"] = int(bd.get("period_ms", 0))
			continue
		if float(bd.get("damage", 0.0)) >= 1.0:
			continue
		bd["left_ms"] = int(bd.get("left_ms", 0)) - STEP_MS
		if int(bd.get("left_ms", 0)) <= 0:
			bd["left_ms"] = int(bd.get("period_ms", 0))
			if is_functional(bd):
				step_building(bd)
	spawn_acc_ms += STEP_MS
	if spawn_acc_ms >= SPAWN_MS:
		spawn_acc_ms = 0
		spawn_tick(rng)
	check_acc_ms += STEP_MS
	if check_acc_ms >= CHECK_MS:
		check_acc_ms = 0
		var dead_b: Array = []
		for b in buildings:
			if b is Dictionary and float((b as Dictionary).get("damage", 0.0)) >= 1.0:
				dead_b.append(int((b as Dictionary).get("guid", 0)))
		for g in dead_b:
			unplace(g)
		step_energy(rng)
		var kept: Array = []
		for u in units:
			if u is Dictionary == false:
				continue
			var ud: Dictionary = u
			if float(ud.get("full", 0.0)) <= 0.0 or bool(ud.get("gone", false)):
				for b in buildings:
					if b is Dictionary:
						worker_cancel(int((b as Dictionary).get("guid", 0)), int(ud.get("guid", 0)))
						mission_cancel(int((b as Dictionary).get("guid", 0)), int(ud.get("guid", 0)))
				for b in buildings:
					if b is Dictionary:
						var rs: Array = (b as Dictionary).get("residents", [])
						var nk: Array = []
						for r in rs:
							if int(r) != int(ud.get("guid", 0)):
								nk.append(int(r))
						(b as Dictionary)["residents"] = nk
				if hauls.has(int(ud.get("guid", 0))):
					hauls.erase(int(ud.get("guid", 0)))
			else:
				kept.append(ud)
		units = kept
		_dirty = true
		sync_indices()
		heal_refs()
