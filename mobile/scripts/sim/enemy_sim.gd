class_name EnemySim
extends RefCounted

const BALANCE_PATH := "res://data/balance.json"
const STEP_MS := 50
const SPAWN_MS := 20000
const RANDOM_MS := 15000
const ATTACK_MS := 60000
const CAP_FIXED_3 := 3
const CHANCE := 0.5
const HIT := 0.2
const HIT_MS := 2000
const RANGE := 80.0
const DPS := 0.01
const SPEED := 23.0

var foes: Array = []
var by_guid: Dictionary = {}
var acc_ms: int = 0
var auth_ms: int = 0
var next_guid: int = 900001
var tune: Dictionary = {}

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

func setup() -> void:
	tune = load_json(BALANCE_PATH)
	rebuild()

func rebuild() -> void:
	by_guid.clear()
	for e in foes:
		if e is Dictionary and (e as Dictionary).has("guid"):
			by_guid[int((e as Dictionary)["guid"])] = e

func make_guid() -> int:
	var g: int = next_guid
	next_guid += 1
	return g

func cap() -> int:
	if tune.has("enemy") and (tune["enemy"] as Dictionary).has("cap"):
		return int((tune["enemy"] as Dictionary)["cap"])
	return CAP_FIXED_3

func spawn_ms() -> int:
	if tune.has("enemy") and (tune["enemy"] as Dictionary).has("interval_ms"):
		return int((tune["enemy"] as Dictionary)["interval_ms"])
	return SPAWN_MS

func chance() -> float:
	if tune.has("enemy") and (tune["enemy"] as Dictionary).has("chance"):
		return float((tune["enemy"] as Dictionary)["chance"])
	return CHANCE

func random_ms() -> int:
	if tune.has("enemy") and (tune["enemy"] as Dictionary).has("random_duration_ms"):
		return int((tune["enemy"] as Dictionary)["random_duration_ms"])
	return RANDOM_MS

func attack_ms() -> int:
	if tune.has("enemy") and (tune["enemy"] as Dictionary).has("attack_duration_ms"):
		return int((tune["enemy"] as Dictionary)["attack_duration_ms"])
	return ATTACK_MS

func range_px() -> float:
	if tune.has("authority") and (tune["authority"] as Dictionary).has("range_px"):
		return float((tune["authority"] as Dictionary)["range_px"])
	return RANGE

func hit_amount() -> float:
	if tune.has("authority") and (tune["authority"] as Dictionary).has("damage_per_update"):
		return float((tune["authority"] as Dictionary)["damage_per_update"])
	return HIT

func make_foe(pos: Vector2) -> Dictionary:
	var e: Dictionary = {
		"guid": make_guid(),
		"pos": pos,
		"health": 1.0,
		"day_kind": "random",
		"day_ms": random_ms(),
		"house": 0,
		"route": [],
		"idx": 0,
		"done": false
	}
	return e

func want_spawn(rng: Rng) -> bool:
	if foes.size() >= CAP_FIXED_3:
		return false
	if foes.size() >= cap():
		return false
	if rng == null:
		return foes.is_empty()
	return rng.next_float() < chance()

func house_pos(h: Dictionary, fallback: Vector2) -> Vector2:
	if h.has("hub"):
		return h["hub"]
	if h.has("pos"):
		return h["pos"]
	return fallback

func sort_by_dist2(arr: Array, pos: Vector2) -> void:
	for i in range(arr.size()):
		var best: int = i
		var a: Dictionary = arr[i]
		var bd2: float = pos.distance_squared_to(house_pos(a, pos))
		for j in range(i + 1, arr.size()):
			var c: Dictionary = arr[j]
			var jd2: float = pos.distance_squared_to(house_pos(c, pos))
			if jd2 < bd2:
				bd2 = jd2
				best = j
		if best != i:
			var tmp: Variant = arr[i]
			arr[i] = arr[best]
			arr[best] = tmp

func free_houses(dome: Dictionary) -> Array:
	var out: Array = []
	for h in dome.get("buildings", []):
		if h is Dictionary == false:
			continue
		var hd: Dictionary = h
		if int(hd.get("foe", 0)) == 0 and int(hd.get("foe_in", 0)) == 0:
			out.append(hd)
	return out

func incident_reserve(h: Dictionary, foe_guid: int) -> bool:
	if int(h.get("foe", 0)) != 0 or int(h.get("foe_in", 0)) != 0:
		return false
	h["foe_in"] = foe_guid
	return true

func incident_enter(h: Dictionary, foe_guid: int) -> void:
	h["foe_in"] = 0
	h["foe"] = foe_guid
	h["foe_hp"] = 1.0

func incident_exit(h: Dictionary) -> void:
	h["foe"] = 0
	h["foe_hp"] = 0.0

func incident_cancel(h: Dictionary) -> void:
	h["foe"] = 0
	h["foe_in"] = 0
	h["foe_hp"] = 0.0

func house_by_guid(dome: Dictionary, g: int) -> Dictionary:
	for h in dome.get("buildings", []):
		if h is Dictionary and int((h as Dictionary).get("guid", 0)) == g:
			return h
	return {}

func set_random(e: Dictionary) -> void:
	e["day_kind"] = "random"
	e["day_ms"] = random_ms()
	e["house"] = 0
	e["route"] = []
	e["idx"] = 0
	e["done"] = false

func set_attack(e: Dictionary, h: Dictionary) -> void:
	e["day_kind"] = "attack"
	e["day_ms"] = attack_ms()
	e["house"] = int(h.get("guid", 0))
	e["route"] = [house_pos(h, e["pos"])]
	e["idx"] = 0
	e["done"] = false

func set_gohome(e: Dictionary, out_pos: Vector2) -> void:
	e["day_kind"] = "gohome"
	e["day_ms"] = 0
	e["house"] = 0
	e["route"] = [out_pos]
	e["idx"] = 0
	e["done"] = false

func move_foe(e: Dictionary, dt: float) -> bool:
	var route: Array = e.get("route", [])
	var idx: int = int(e.get("idx", 0))
	if route.is_empty() or idx >= route.size():
		return true
	var p: Vector2 = e["pos"]
	var target: Vector2 = route[idx]
	var d: Vector2 = target - p
	var dist: float = d.length()
	var step: float = SPEED * dt
	if dist <= maxf(step, 10.0):
		e["pos"] = target
		e["idx"] = idx + 1
		return int(e.get("idx", 0)) >= route.size()
	e["pos"] = p + d / dist * step
	return false

func step_foe(e: Dictionary, dome: Dictionary, rng: Rng, out_pos: Vector2) -> void:
	var dt: float = float(STEP_MS) / 1000.0
	if (e.get("route", []) as Array).is_empty():
		if String(e.get("day_kind", "")) == "attack":
			var hb: Dictionary = house_by_guid(dome, int(e.get("house", 0)))
			if hb.is_empty():
				set_random(e)
				return
			if incident_reserve(hb, int(e.get("guid", 0))):
				e["route"] = [house_pos(hb, e["pos"])]
				e["idx"] = 0
			else:
				set_random(e)
		else:
			var any: Array = free_houses(dome)
			if any.is_empty():
				e["route"] = [out_pos + Vector2(96.0, 0.0)]
				e["idx"] = 0
			else:
				sort_by_dist2(any, e["pos"])
				var pick: Dictionary = any[0]
				if rng != null and rng.next_float() < 0.35:
					pick = any[rng.next_int() % any.size()]
				e["route"] = [house_pos(pick, e["pos"])]
				e["idx"] = 0
				if String(e.get("day_kind", "")) == "gohome":
					e["done"] = false
	e["day_ms"] = int(e.get("day_ms", 0)) - STEP_MS
	if move_foe(e, dt):
		e["done"] = true
	if bool(e.get("done", false)):
		if String(e.get("day_kind", "")) == "attack":
			var hb2: Dictionary = house_by_guid(dome, int(e.get("house", 0)))
			if hb2.is_empty() == false and int(hb2.get("foe", 0)) == 0:
				incident_enter(hb2, int(e.get("guid", 0)))
		if int(e.get("day_ms", 0)) >= 0:
			if String(e.get("day_kind", "")) == "random":
				e["route"] = []
				e["idx"] = 0
				e["done"] = false
		else:
			if String(e.get("day_kind", "")) == "random":
				if rng != null and rng.next_float() < 0.1:
					var cands: Array = free_houses(dome)
					if cands.is_empty():
						set_gohome(e, out_pos)
					else:
						sort_by_dist2(cands, e["pos"])
						set_attack(e, cands[0])
				else:
					set_gohome(e, out_pos)
			elif String(e.get("day_kind", "")) == "attack":
				var hb3: Dictionary = house_by_guid(dome, int(e.get("house", 0)))
				if hb3.is_empty() == false:
					incident_exit(hb3)
				set_gohome(e, out_pos)
			elif String(e.get("day_kind", "")) == "gohome":
				e["health"] = 0.0

func authority_tick(dome: Dictionary) -> void:
	if foes.is_empty():
		return
	var r: float = range_px()
	var r2: float = r * r
	var hit: float = hit_amount()
	var posts: Array = []
	for h in dome.get("buildings", []):
		if h is Dictionary == false:
			continue
		var hd: Dictionary = h
		if String(hd.get("kind", "")) != "authority":
			continue
		if float(hd.get("damage", 0.0)) >= 1.0:
			continue
		if bool(hd.get("energy", true)) == false:
			continue
		if ((hd.get("workers", []) as Array).is_empty()):
			continue
		posts.append(hd)
	if posts.is_empty():
		return
	for e in foes:
		if e is Dictionary == false:
			continue
		var ed: Dictionary = e
		var p: Vector2 = ed["pos"]
		for post in posts:
			var bp: Vector2 = house_pos(post, p)
			if p.distance_squared_to(bp) <= r2:
				ed["health"] = float(ed.get("health", 1.0)) - hit
				break

func prune(dome: Dictionary) -> void:
	var kept: Array = []
	for e in foes:
		if e is Dictionary == false:
			continue
		var ed: Dictionary = e
		if float(ed.get("health", 1.0)) <= 0.0:
			var hg: int = int(ed.get("house", 0))
			if hg != 0:
				var hb: Dictionary = house_by_guid(dome, hg)
				if hb.is_empty() == false:
					if int(hb.get("foe", 0)) == int(ed.get("guid", 0)):
						incident_exit(hb)
					if int(hb.get("foe_in", 0)) == int(ed.get("guid", 0)):
						incident_cancel(hb)
		else:
			kept.append(ed)
	foes = kept
	rebuild()

func step_20hz(dome: Dictionary, rng: Rng) -> void:
	var out_pos: Vector2 = dome.get("out_pos", Vector2(640.0, 360.0))
	acc_ms += STEP_MS
	if acc_ms >= spawn_ms():
		acc_ms = 0
		if want_spawn(rng):
			var skap: int = cap()
			if foes.size() < skap and foes.size() < CAP_FIXED_3:
				var ne: Dictionary = make_foe(out_pos)
				foes.append(ne)
				by_guid[int(ne["guid"])] = ne
	auth_ms += STEP_MS
	if auth_ms >= HIT_MS:
		auth_ms = 0
		authority_tick(dome)
	for e in foes.duplicate():
		if e is Dictionary:
			step_foe(e, dome, rng, out_pos)
	prune(dome)
