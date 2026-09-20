class_name PlanetSim
extends RefCounted

const DomeScript := preload("res://scripts/sim/dome_sim.gd")
const HashScript := preload("res://scripts/sim/hash.gd")

const TELEPORT_MS := 60000
const TELEPORT_AMOUNT := 5.0
const ENEMY_BASE_MS := 20000
const ENEMY_CHANCE := 0.5
const ENEMY_CAP := 3
const ENEMY_PREFER := ["solar", "oxygen", "cantine", "storage"]
const EVENTS_MAX := 256

var domes: Array = []
var rng: Rng
var moon_id: String = "beginner"
var mults: Dictionary = {"energy_need": 1.0, "enemy_damage": 1.0, "enemy_spawn": 1.0, "oxygen_need": 1.0}
var start_resources: Dictionary = {"stone": 60.0, "alloy": 20.0, "biomass": 30.0, "ore": 0.0, "stim": 10.0}
var teleport_acc_ms: int = 0
var enemy_acc_ms: int = 0
var pending: Array = []
var events: Array = []
var tick: int = 0
var enemy_attack_ms: int = 60000
var next_foe_guid: int = 1000000

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

func setup(moon: String, seed_value: int) -> void:
	rng = Rng.new(seed_value)
	configure_moon(moon)

func configure_moon(moon: String) -> void:
	moon_id = moon
	mults = {"energy_need": 1.0, "enemy_damage": 1.0, "enemy_spawn": 1.0, "oxygen_need": 1.0}
	start_resources = {"stone": 60.0, "alloy": 20.0, "biomass": 30.0, "ore": 0.0, "stim": 10.0}
	var moons: Dictionary = load_json("res://data/moons.json")
	if moons.has("moons") and moons["moons"] is Array:
		for m in moons["moons"]:
			if m is Dictionary and String(m.get("id", "")) == moon:
				if m.get("multipliers") is Dictionary:
					for k in (m["multipliers"] as Dictionary).keys():
						mults[k] = float((m["multipliers"] as Dictionary)[k])
				if m.get("start_resources") is Dictionary:
					for k in (m["start_resources"] as Dictionary).keys():
						start_resources[k] = float((m["start_resources"] as Dictionary)[k])
	var balance: Dictionary = load_json("res://data/balance.json")
	if balance.get("enemy") is Dictionary:
		enemy_attack_ms = int((balance["enemy"] as Dictionary).get("attack_duration_ms", 60000))

func add_dome(dome: RefCounted) -> void:
	domes.append(dome)
	apply_moon_tuning()
	emit("dome_added", {"count": domes.size()})

func emit(kind: String, data: Dictionary) -> void:
	var e: Dictionary = {"tick": tick, "kind": kind, "data": data}
	events.append(e)
	while events.size() > EVENTS_MAX:
		events.pop_front()

func seed_elevator(dome: RefCounted) -> void:
	var ds: DomeSim = dome
	var seed_cell := Vector2i(-1, -1)
	var def: Dictionary = ds.bdef("elevator")
	var width: int = int(def.get("width", 4))
	var height: int = int(def.get("height", 4))
	for x in range(0, int(ds.grid.get("width", 0))):
		for y in range(0, int(ds.grid.get("height", 0))):
			var candidate := Vector2i(x, y)
			if ds.footprint_free(candidate, width, height):
				seed_cell = candidate
				break
		if seed_cell.x >= 0:
			break
	if seed_cell.x < 0:
		return
	var b: Dictionary = ds.make_building("elevator", seed_cell, 0)
	for k in start_resources.keys():
		(b["store"] as Dictionary)[k] = float(start_resources.get(k, 0.0))
	ds.set_walk_rect(b, false)
	ds.buildings.append(b)
	ds._dirty = true
	ds.sync_indices()
	emit("seeded", {"store": (b["store"] as Dictionary).duplicate()})

func teleport_step() -> void:
	var providers: Dictionary = {}
	var consumers: Array = []
	for dome_index in domes.size():
		var d: RefCounted = domes[dome_index]
		var ds: DomeSim = d
		ds.sync_indices()
		for b in ds.buildings:
			if b is Dictionary == false:
				continue
			var bd: Dictionary = b
			if String(bd.get("kind", "")) != "teleport":
				continue
			if float(bd.get("damage", 0.0)) >= 1.0:
				continue
			if (bd.get("store", {}) as Dictionary).is_empty() == false:
				var st: Dictionary = bd["store"]
				for res in ["stone", "alloy", "biomass", "ore", "stim"]:
					if float(st.get(res, 0.0)) > 0.0 and String(bd.get("exp", "")) == res:
						if providers.has(res) == false:
							providers[res] = []
						(providers[res] as Array).append({"dome": ds, "index": dome_index, "b": bd})
			if String(bd.get("imp", "")) != "":
				consumers.append({"dome": ds, "index": dome_index, "b": bd})
	if providers.is_empty() or consumers.is_empty():
		return
	for res in ["stone", "alloy", "biomass", "ore", "stim"]:
		if providers.has(res) == false:
			continue
		var want: Array = []
		for c in consumers:
			var cb: Dictionary = (c as Dictionary)["b"]
			if String(cb.get("imp", "")) == res:
				want.append(c)
		if want.is_empty():
			continue
		want.sort_custom(func(a: Variant, b: Variant) -> bool:
			var sa: float = float(((a as Dictionary)["b"] as Dictionary)["store"].get(res, 0.0))
			var sb: float = float(((b as Dictionary)["b"] as Dictionary)["store"].get(res, 0.0))
			if sa != sb:
				return sa < sb
			var ia: int = int((a as Dictionary).get("index", 0))
			var ib: int = int((b as Dictionary).get("index", 0))
			if ia != ib:
				return ia < ib
			return int(((a as Dictionary)["b"] as Dictionary).get("guid", 0)) < int(((b as Dictionary)["b"] as Dictionary).get("guid", 0)))
		(providers[res] as Array).sort_custom(func(a: Variant, b: Variant) -> bool:
			var ia: int = int((a as Dictionary).get("index", 0))
			var ib: int = int((b as Dictionary).get("index", 0))
			if ia != ib:
				return ia < ib
			return int(((a as Dictionary)["b"] as Dictionary).get("guid", 0)) < int(((b as Dictionary)["b"] as Dictionary).get("guid", 0)))
		for p in providers[res]:
			var pb: Dictionary = (p as Dictionary)["b"]
			var provider_dome: DomeSim = (p as Dictionary)["dome"]
			var pst: Dictionary = pb["store"]
			var have: float = float(pst.get(res, 0.0))
			if have <= 0.0:
				continue
			var chosen: Dictionary = {}
			var room: float = 0.0
			for candidate in want:
				var candidate_data: Dictionary = candidate
				if candidate_data["dome"] == provider_dome:
					continue
				var candidate_dome: DomeSim = candidate_data["dome"]
				var candidate_building: Dictionary = candidate_data["b"]
				var capacity: float = float(candidate_dome.bdef("teleport").get("maxStorage", 48.0))
				room = capacity - candidate_dome.store_sum(candidate_building["store"])
				if room > 0.0:
					chosen = candidate_data
					break
			if chosen.is_empty():
				continue
			var cb: Dictionary = chosen["b"]
			var cst: Dictionary = cb["store"]
			var move: float = minf(TELEPORT_AMOUNT, minf(have, room))
			if move <= 0.0:
				continue
			pst[res] = have - move
			cst[res] = float(cst.get(res, 0.0)) + move
			emit("teleport", {"res": res, "amount": move})
			want.sort_custom(func(a: Variant, b: Variant) -> bool:
				var sa: float = float(((a as Dictionary)["b"] as Dictionary)["store"].get(res, 0.0))
				var sb: float = float(((b as Dictionary)["b"] as Dictionary)["store"].get(res, 0.0))
				if sa != sb:
					return sa < sb
				var ia: int = int((a as Dictionary).get("index", 0))
				var ib: int = int((b as Dictionary).get("index", 0))
				if ia != ib:
					return ia < ib
				return int(((a as Dictionary)["b"] as Dictionary).get("guid", 0)) < int(((b as Dictionary)["b"] as Dictionary).get("guid", 0)))

func enemy_targets(ds: DomeSim) -> Array:
	var out: Array = []
	for b in ds.buildings:
		if b is Dictionary == false:
			continue
		var bd: Dictionary = b
		if int(bd.get("foe", 0)) != 0 or int(bd.get("foe_in", 0)) != 0:
			continue
		if float(bd.get("damage", 0.0)) >= 1.0:
			continue
		if ENEMY_PREFER.has(String(bd.get("kind", ""))):
			out.append(bd)
	return out

func enemy_step() -> void:
	var interval: float = float(ENEMY_BASE_MS) / maxf(0.25, float(mults.get("enemy_spawn", 1.0)))
	enemy_acc_ms += 50
	if float(enemy_acc_ms) < interval:
		return
	enemy_acc_ms = 0
	if rng.next_float() >= ENEMY_CHANCE:
		return
	var total_foes: int = 0
	for d in domes:
		for b in (d as DomeSim).buildings:
			if b is Dictionary and (int((b as Dictionary).get("foe", 0)) != 0 or int((b as Dictionary).get("foe_in", 0)) != 0):
				total_foes += 1
	if total_foes >= ENEMY_CAP:
		return
	var cands: Array = []
	for d in domes:
		for b in enemy_targets(d):
			cands.append({"dome": d, "b": b})
	if cands.is_empty():
		return
	cands.sort_custom(func(a: Variant, b: Variant) -> bool:
		var ia: int = domes.find((a as Dictionary)["dome"])
		var ib: int = domes.find((b as Dictionary)["dome"])
		if ia != ib:
			return ia < ib
		return int(((a as Dictionary)["b"] as Dictionary).get("guid", 0)) < int(((b as Dictionary)["b"] as Dictionary).get("guid", 0)))
	var pick: Dictionary = cands[rng.next_int() % cands.size()]
	var tb: Dictionary = pick["b"]
	tb["foe_in"] = next_foe_guid
	next_foe_guid += 1
	tb["foe_hp"] = 1.0
	pending.append({"dome": pick["dome"], "guid": int(tb.get("guid", 0)), "foe_guid": int(tb["foe_in"]), "ms": 2000})
	emit("incident_incoming", {"guid": int(tb.get("guid", 0)), "kind": String(tb.get("kind", ""))})

func pending_step() -> void:
	var kept: Array = []
	for p in pending:
		var ms: int = int((p as Dictionary).get("ms", 0)) - 50
		(p as Dictionary)["ms"] = ms
		if ms <= 0:
			var ds: DomeSim = (p as Dictionary)["dome"]
			ds.sync_indices()
			if ds.by_guid.has(int((p as Dictionary).get("guid", 0))):
				var bd: Dictionary = ds.by_guid[int((p as Dictionary).get("guid", 0))]
				var incoming_guid: int = int((p as Dictionary).get("foe_guid", 0))
				if int(bd.get("foe", 0)) == 0 and int(bd.get("foe_in", 0)) == incoming_guid:
					bd["foe_in"] = 0
					bd["foe"] = incoming_guid
					bd["foe_left_ms"] = enemy_attack_ms
					if bd.get("foe_hp", 0.0) == null or float(bd.get("foe_hp", 0.0)) <= 0.0:
						bd["foe_hp"] = 1.0
					emit("incident_enter", {"guid": int(bd.get("guid", 0))})
		else:
			kept.append(p)
	pending = kept

func apply_moon_tuning() -> void:
	var edmg: float = float(mults.get("enemy_damage", 1.0))
	var energy_need: float = float(mults.get("energy_need", 1.0))
	var oxygen_need: float = float(mults.get("oxygen_need", 1.0))
	for d in domes:
		var ds: DomeSim = d
		ds.tune["enemy_damage_mult"] = edmg
		ds.tune["energy_need_mult"] = energy_need
		ds.tune["oxygen_need_mult"] = oxygen_need

func enemy_attack_step() -> void:
	for d in domes:
		var ds: DomeSim = d
		for b in ds.buildings:
			if b is Dictionary == false or int((b as Dictionary).get("foe", 0)) == 0:
				continue
			var bd: Dictionary = b
			var left_ms: int = int(bd.get("foe_left_ms", enemy_attack_ms))
			if left_ms <= 0:
				left_ms = enemy_attack_ms
			bd["foe_left_ms"] = left_ms - 50
			if int(bd["foe_left_ms"]) <= 0:
				ds.incident_exit(int(bd.get("guid", 0)))

func step_20hz() -> void:
	tick += 1
	apply_moon_tuning()
	for d in domes:
		(d as DomeSim).step_20hz(rng)
	teleport_acc_ms += 50
	if teleport_acc_ms >= TELEPORT_MS:
		teleport_acc_ms = 0
		teleport_step()
	enemy_step()
	pending_step()
	enemy_attack_step()

func snapshot() -> Dictionary:
	var ds: Array = []
	for d in domes:
		var dd: DomeSim = d
		ds.append({
			"buildings": dd.buildings.duplicate(true),
			"units": dd.units.duplicate(true),
			"hauls": dd.hauls.duplicate(true),
			"tune": dd.tune.duplicate(true),
			"spawn_acc_ms": dd.spawn_acc_ms,
			"check_acc_ms": dd.check_acc_ms,
			"next_guid": dd.next_guid
		})
	var pending_state: Array = []
	for item in pending:
		var pending_item: Dictionary = item
		pending_state.append({
			"dome_index": domes.find(pending_item.get("dome")),
			"guid": int(pending_item.get("guid", 0)),
			"foe_guid": int(pending_item.get("foe_guid", 0)),
			"ms": int(pending_item.get("ms", 0))
		})
	return {
		"moon": moon_id,
		"mults": mults.duplicate(true),
		"tick": tick,
		"rng": rng.save_state(),
		"domes": ds,
		"pending": pending_state,
		"events": events.duplicate(true),
		"teleport_acc_ms": teleport_acc_ms,
		"enemy_acc_ms": enemy_acc_ms,
		"enemy_attack_ms": enemy_attack_ms,
		"next_foe_guid": next_foe_guid
	}

static func _encode_state(value: Variant) -> Variant:
	if value is int:
		return {"$type": "int", "value": value}
	if value is float:
		return {"$type": "float", "value": value}
	if value is Vector2:
		var v2: Vector2 = value
		return {"$type": "vector2", "x": v2.x, "y": v2.y}
	if value is Vector2i:
		var v2i: Vector2i = value
		return {"$type": "vector2i", "x": v2i.x, "y": v2i.y}
	if value is Dictionary:
		var items: Array = []
		for key in (value as Dictionary).keys():
			items.append({"key": _encode_state(key), "value": _encode_state((value as Dictionary)[key])})
		return {"$type": "dictionary", "items": items}
	if value is Array:
		var out: Array = []
		for item in value:
			out.append(_encode_state(item))
		return out
	return value

static func _decode_state(value: Variant) -> Variant:
	if value is Array:
		var out: Array = []
		for item in value:
			out.append(_decode_state(item))
		return out
	if value is Dictionary == false:
		return value
	var d: Dictionary = value
	var kind: String = String(d.get("$type", ""))
	if kind == "int":
		return int(d.get("value", 0))
	if kind == "float":
		return float(d.get("value", 0.0))
	if kind == "vector2":
		return Vector2(float(d.get("x", 0.0)), float(d.get("y", 0.0)))
	if kind == "vector2i":
		return Vector2i(int(d.get("x", 0)), int(d.get("y", 0)))
	if kind == "dictionary":
		var result: Dictionary = {}
		for item in d.get("items", []):
			if item is Dictionary:
				var pair: Dictionary = item
				result[_decode_state(pair.get("key"))] = _decode_state(pair.get("value"))
		return result
	var plain: Dictionary = {}
	for key in d.keys():
		plain[key] = _decode_state(d[key])
	return plain

func save_state() -> Dictionary:
	return _encode_state(snapshot()) as Dictionary

func load_state(state: Dictionary) -> bool:
	var decoded: Variant = _decode_state(state)
	if decoded is Dictionary == false:
		return false
	var source: Dictionary = decoded
	if source.get("domes") is Array == false:
		return false
	configure_moon(String(source.get("moon", moon_id)))
	if rng == null:
		rng = Rng.new(1)
	if source.get("mults") is Dictionary:
		mults = source["mults"].duplicate(true)
	if source.has("rng") and source["rng"] is Dictionary:
		rng.load_state(source["rng"])
	tick = int(source.get("tick", 0))
	teleport_acc_ms = int(source.get("teleport_acc_ms", 0))
	enemy_acc_ms = int(source.get("enemy_acc_ms", 0))
	enemy_attack_ms = int(source.get("enemy_attack_ms", enemy_attack_ms))
	next_foe_guid = int(source.get("next_foe_guid", 1000000))
	domes.clear()
	for raw_dome in source.get("domes", []):
		if raw_dome is Dictionary == false:
			continue
		var dome_state: Dictionary = raw_dome
		var ds: DomeSim = DomeSim.new()
		ds.setup()
		if dome_state.get("buildings") is Array:
			ds.buildings = dome_state["buildings"]
		if dome_state.get("units") is Array:
			ds.units = dome_state["units"]
		if dome_state.get("hauls") is Dictionary:
			ds.hauls = dome_state["hauls"]
		if dome_state.get("tune") is Dictionary:
			ds.tune = dome_state["tune"].duplicate(true)
		ds.spawn_acc_ms = int(dome_state.get("spawn_acc_ms", 0))
		ds.check_acc_ms = int(dome_state.get("check_acc_ms", 0))
		ds.next_guid = int(dome_state.get("next_guid", 1))
		ds.rebuild_walkability()
		ds._dirty = true
		ds.sync_indices()
		ds.heal_refs()
		domes.append(ds)
	events = source.get("events", []).duplicate(true) if source.get("events", []) is Array else []
	pending.clear()
	for raw_pending in source.get("pending", []):
		if raw_pending is Dictionary == false:
			continue
		var pending_state: Dictionary = raw_pending
		var dome_index: int = int(pending_state.get("dome_index", -1))
		if dome_index < 0 or dome_index >= domes.size():
			continue
		pending.append({
			"dome": domes[dome_index],
			"guid": int(pending_state.get("guid", 0)),
			"foe_guid": int(pending_state.get("foe_guid", 0)),
			"ms": int(pending_state.get("ms", 0))
		})
	apply_moon_tuning()
	return true

func state_hash() -> String:
	return HashScript.fnv1a(snapshot())
