class_name UnitSim
extends RefCounted

const BALANCE_PATH := "res://data/balance.json"
const STEP_MS := 50
const DRAIN := -0.002
const SPEED := 23.0
const OPPOLENCE := "oppolence"
const LEGACY_OPPULENCE := "oppulence"
const DAY_KINDS := ["work", "eat", "relax", "oppolence", "idle", "gounderground"]
const JOB_KINDS := ["fetch", "store", "repair", "incident"]
const JOB_MS := 2000

var u: Dictionary = {}
var castes: Dictionary = {}

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

static func normalize_kind(k: String) -> String:
	if k == LEGACY_OPPULENCE:
		return OPPOLENCE
	return k

static func denormalize_kind(k: String) -> String:
	if k == OPPOLENCE:
		return LEGACY_OPPULENCE
	return k

static func clamp01(v: float) -> float:
	return clampf(v, 0.0, 1.0)

static func load_castes() -> Dictionary:
	var tune: Dictionary = load_json(BALANCE_PATH)
	var out: Dictionary = {}
	if tune.has("castes") == false or not (tune["castes"] is Dictionary):
		return out
	var src: Dictionary = tune["castes"]
	for caste in src.keys():
		if src[caste] is Dictionary == false:
			continue
		var cmap: Dictionary = {}
		var one: Dictionary = src[caste]
		for sk in one.keys():
			if one[sk] is Dictionary == false:
				continue
			var sd: Dictionary = one[sk]
			var nk: String = normalize_kind(String(sk))
			var nb: Array = []
			if sd.get("buildings") is Array:
				for b in sd["buildings"]:
					nb.append(String(b))
			var nx: String = ""
			if sd.get("next") is String:
				nx = normalize_kind(String(sd["next"]))
			cmap[nk] = {"resolve_ms": int(sd.get("resolve_ms", 10000)), "buildings": nb, "next": nx}
		out[String(caste)] = cmap
	return out

static func make_dict(caste: String, pos: Vector2, guid: int, home_guid: int) -> Dictionary:
	return {
		"guid": guid,
		"caste": caste,
		"pos": pos,
		"happy": 1.0,
		"full": 1.0,
		"home": home_guid,
		"gone": false,
		"send_home": false,
		"day_kind": "work",
		"day_house": 0,
		"day_left_ms": 90000,
		"day_route": [],
		"day_idx": 0,
		"day_done": false,
		"had_duty": false,
		"idle_n": 0,
		"job_kind": "",
		"job_house": 0,
		"job_left_ms": 0,
		"job_route": [],
		"job_idx": 0,
		"job_done": false,
		"haul_origin": 0,
		"haul_res": "",
		"haul_amount": 0.0
	}

static func can_spawn(avg_h: float, avg_f: float, count: int) -> bool:
	if count <= 0:
		return true
	return avg_h > 0.8 and avg_f > 0.8

static func is_dead(d: Dictionary) -> bool:
	if bool(d.get("gone", false)):
		return true
	return float(d.get("full", 0.0)) <= 0.0

func setup(caste: String, pos: Vector2, guid: int, home_guid: int) -> void:
	castes = load_castes()
	u = make_dict(caste, pos, guid, home_guid)
	set_day("work")

func day_def() -> Dictionary:
	var c: String = String(u.get("caste", "helot"))
	if castes.has(c) == false:
		return {"resolve_ms": 10000, "buildings": [], "next": "work"}
	var cmap: Dictionary = castes[c]
	var k: String = normalize_kind(String(u.get("day_kind", "work")))
	if cmap.has(k):
		return cmap[k]
	return {"resolve_ms": 10000, "buildings": [], "next": "work"}

func set_day(kind: String) -> void:
	kind = normalize_kind(kind)
	u["day_kind"] = kind
	u["day_house"] = 0
	u["day_route"] = []
	u["day_idx"] = 0
	u["day_done"] = false
	u["had_duty"] = false
	var dd: Dictionary = day_def()
	u["day_left_ms"] = int(dd.get("resolve_ms", 10000))
	u["job_kind"] = ""
	u["job_house"] = 0
	u["job_route"] = []
	u["job_idx"] = 0
	u["job_done"] = false
	if kind == "relax":
		u["idle_n"] = 0

func set_job(kind: String) -> void:
	u["job_kind"] = kind
	u["job_house"] = 0
	u["job_route"] = []
	u["job_idx"] = 0
	u["job_done"] = false
	u["job_left_ms"] = JOB_MS

func is_job_resolving() -> bool:
	return String(u.get("job_kind", "")) != "" and bool(u.get("job_done", false))

func is_idle() -> bool:
	return bool(u.get("day_done", false)) and String(u.get("job_kind", "")) == ""

func drain(dt: float) -> void:
	u["full"] = clamp01(float(u.get("full", 0.0)) + DRAIN * dt)

func walk_to(target: Vector2, dt: float) -> bool:
	var p: Vector2 = u["pos"]
	var d: Vector2 = target - p
	var dist: float = d.length()
	var step: float = SPEED * dt
	if dist <= maxf(step, 10.0):
		u["pos"] = target
		return true
	u["pos"] = p + d / dist * step
	return false

func walk_route(which: String, dt: float) -> bool:
	var rk: String = "day_route"
	var ik: String = "day_idx"
	if which == "job":
		rk = "job_route"
		ik = "job_idx"
	var route: Array = u.get(rk, [])
	var idx: int = int(u.get(ik, 0))
	if route.is_empty() or idx >= route.size():
		return true
	var target: Vector2 = route[idx]
	if walk_to(target, dt):
		idx += 1
		u[ik] = idx
		if idx >= route.size():
			return true
	return false

func house_pos(h: Dictionary) -> Vector2:
	if h.has("hub"):
		return h["hub"]
	if h.has("pos"):
		return h["pos"]
	return u["pos"]

func sort_by_dist2(arr: Array, pos: Vector2) -> void:
	for i in range(arr.size()):
		var best: int = i
		var bd2: float = pos.distance_squared_to(house_pos(arr[i]))
		var bg: int = int((arr[i] as Dictionary).get("guid", 0))
		for j in range(i + 1, arr.size()):
			var jd2: float = pos.distance_squared_to(house_pos(arr[j]))
			var jg: int = int((arr[j] as Dictionary).get("guid", 0))
			if jd2 < bd2 or (is_equal_approx(jd2, bd2) and jg < bg):
				bd2 = jd2
				bg = jg
				best = j
		if best != i:
			var tmp: Variant = arr[i]
			arr[i] = arr[best]
			arr[best] = tmp

func house_ok_day(h: Dictionary, want: Array) -> bool:
	if want.has(String(h.get("kind", ""))) == false:
		return false
	if float(h.get("damage", 0.0)) >= 1.0:
		return false
	if bool(h.get("energy", true)) == false:
		return false
	if int(h.get("foe", 0)) != 0:
		return false
	return true

func find_day_spot(dome: Dictionary) -> bool:
	var dd: Dictionary = day_def()
	var want: Array = dd.get("buildings", [])
	var kind: String = normalize_kind(String(u.get("day_kind", "work")))
	var pos: Vector2 = u["pos"]
	var all: Array = dome.get("buildings", [])
	var cand: Array = []
	for h in all:
		if h is Dictionary == false:
			continue
		var hd: Dictionary = h
		if kind == "idle":
			if want.has(String(hd.get("kind", ""))):
				cand.append(hd)
		elif kind == "relax":
			if want.has(String(hd.get("kind", ""))) and int(hd.get("guid", 0)) == int(u.get("home", 0)):
				if house_ok_day(hd, want):
					cand.append(hd)
			elif String(u.get("caste", "")) == "mighty" and kind == OPPOLENCE:
				if String(hd.get("kind", "")) == "bar" and house_ok_day(hd, ["bar"]):
					cand.append(hd)
		else:
			if house_ok_day(hd, want) and can_reserve(hd):
				cand.append(hd)
	if cand.is_empty():
		return false
	if kind == "idle" and cand.size() > 0:
		var one: Dictionary = cand[0]
		u["day_house"] = int(one.get("guid", 0))
		u["day_route"] = [house_pos(one)]
		u["day_idx"] = 0
		reserve_spot(dome, one)
		return true
	sort_by_dist2(cand, pos)
	var pick: Dictionary = cand[0]
	u["day_house"] = int(pick.get("guid", 0))
	u["day_route"] = [house_pos(pick)]
	u["day_idx"] = 0
	reserve_spot(dome, pick)
	return true

func can_reserve(h: Dictionary) -> bool:
	var cap: int = int(h.get("max_n", 1))
	if cap <= 0:
		return true
	var cur: int = (h.get("workers", []) as Array).size() + (h.get("incoming", []) as Array).size()
	return cur < cap

func reserve_spot(dome: Dictionary, h: Dictionary) -> void:
	var arr: Array = h.get("incoming", [])
	var g: int = int(u.get("guid", 0))
	if arr.has(g) == false:
		arr.append(g)
	h["incoming"] = arr

func enter_spot(dome: Dictionary) -> void:
	var hg: int = int(u.get("day_house", 0))
	for h in dome.get("buildings", []):
		if h is Dictionary and int((h as Dictionary).get("guid", 0)) == hg:
			var hd: Dictionary = h
			var inc: Array = hd.get("incoming", [])
			var kept: Array = []
			for g in inc:
				if int(g) != int(u.get("guid", 0)):
					kept.append(int(g))
			hd["incoming"] = kept
			var w: Array = hd.get("workers", [])
			if w.has(int(u.get("guid", 0))) == false:
				w.append(int(u.get("guid", 0)))
			var k: String = String(hd.get("kind", ""))
			if k == "maintenance":
				set_job("repair")
			elif k == "authority":
				set_job("incident")
			elif k == "storage":
				set_job("fetch")
				u["haul_origin"] = hg
			elif k == "teleport":
				set_job("fetch")
				u["haul_origin"] = hg
				u["haul_res"] = String(hd.get("exp", ""))
			elif k == "elevator":
				u["gone"] = true

func exit_spot(dome: Dictionary) -> void:
	var hg: int = int(u.get("day_house", 0))
	for h in dome.get("buildings", []):
		if h is Dictionary and int((h as Dictionary).get("guid", 0)) == hg:
			var hd: Dictionary = h
			var w: Array = hd.get("workers", [])
			var kept: Array = []
			for g in w:
				if int(g) != int(u.get("guid", 0)):
					kept.append(int(g))
			hd["workers"] = kept

func step_day(dome: Dictionary, dt_ms: int, rng: Rng) -> void:
	var dt: float = float(dt_ms) / 1000.0
	if (u.get("day_route", []) as Array).is_empty():
		if bool(u.get("send_home", false)):
			set_day("gounderground")
		if find_day_spot(dome) == false:
			var dk: String = normalize_kind(String(u.get("day_kind", "work")))
			if dk == "work" and int(u.get("idle_n", 0)) < 3:
				set_day("idle")
				u["idle_n"] = int(u.get("idle_n", 0)) + 1
			else:
				var dd: Dictionary = day_def()
				var nx: String = normalize_kind(String(dd.get("next", "work")))
				if nx == "":
					nx = "work"
				set_day(nx)
			return
	u["day_left_ms"] = int(u.get("day_left_ms", 0)) - dt_ms
	if bool(u.get("day_done", false)) == false:
		if walk_route("day", dt):
			var dk2: String = normalize_kind(String(u.get("day_kind", "work")))
			if dk2 == "idle" and int(u.get("day_left_ms", 0)) < 0:
				u["day_done"] = true
				enter_spot(dome)
			elif (u.get("day_route", []) as Array).is_empty() == false:
				u["day_done"] = true
				enter_spot(dome)
	else:
		var hg: int = int(u.get("day_house", 0))
		var hb: Dictionary = {}
		for h in dome.get("buildings", []):
			if h is Dictionary and int((h as Dictionary).get("guid", 0)) == hg:
				hb = h
		if hb.is_empty() == false and float(hb.get("damage", 0.0)) >= 1.0:
			u["day_left_ms"] = int(u.get("day_left_ms", 0)) - dt_ms * 3
		if String(u.get("day_kind", "")) == "eat" and float(u.get("full", 0.0)) >= 0.99 and int(u.get("day_left_ms", 0)) > 5000:
			u["day_left_ms"] = 5000
		var dk3: String = normalize_kind(String(u.get("day_kind", "work")))
		var over: bool = dk3 == "idle" or int(u.get("day_left_ms", 0)) <= 0
		if hb.is_empty() == false and bool(hb.get("energy", true)) == false:
			over = true
		if over:
			var jk: String = String(u.get("job_kind", ""))
			if jk == "store" or jk == "gounderground":
				return
			cancel_mission(dome)
			exit_spot(dome)
			var dd2: Dictionary = day_def()
			var nx2: String = normalize_kind(String(dd2.get("next", "work")))
			if nx2 == "":
				nx2 = "work"
			set_day(nx2)

func cancel_mission(dome: Dictionary) -> void:
	var jg: int = int(u.get("job_house", 0))
	if jg == 0:
		return
	for h in dome.get("buildings", []):
		if h is Dictionary and int((h as Dictionary).get("guid", 0)) == jg:
			var hd: Dictionary = h
			for key in ["go_workers", "go_incoming"]:
				var arr: Array = hd.get(key, [])
				var kept: Array = []
				for g in arr:
					if int(g) != int(u.get("guid", 0)):
						kept.append(int(g))
				hd[key] = kept

func find_job_spot(dome: Dictionary) -> bool:
	var jk: String = String(u.get("job_kind", ""))
	if jk == "":
		return false
	var pos: Vector2 = u["pos"]
	var cand: Array = []
	for h in all_houses(dome):
		var hd: Dictionary = h
		if job_fits(hd, jk) and can_mission(hd):
			if int(hd.get("guid", 0)) == int(u.get("haul_origin", 0)) and (jk == "fetch" or jk == "store"):
				continue
			cand.append(hd)
	if cand.is_empty():
		return false
	sort_by_dist2(cand, pos)
	var pick: Dictionary = cand[0]
	u["job_house"] = int(pick.get("guid", 0))
	u["job_route"] = [house_pos(pick)]
	u["job_idx"] = 0
	u["had_duty"] = true
	var arr: Array = pick.get("go_incoming", [])
	if arr.has(int(u.get("guid", 0))) == false:
		arr.append(int(u.get("guid", 0)))
	pick["go_incoming"] = arr
	return true

func all_houses(dome: Dictionary) -> Array:
	var out: Array = []
	for h in dome.get("buildings", []):
		if h is Dictionary:
			out.append(h)
	return out

func job_fits(h: Dictionary, jk: String) -> bool:
	if jk == "repair":
		return float(h.get("damage", 0.0)) > 0.0
	if jk == "incident":
		return int(h.get("foe", 0)) != 0
	if jk == "fetch":
		if int(h.get("foe", 0)) != 0:
			return false
		if String(u.get("haul_res", "")) != "":
			var st: Dictionary = h.get("store", {})
			return float(st.get(String(u.get("haul_res", "")), 0.0)) > 0.0
		return float(h.get("out_store", 0.0)) > 0.0
	if jk == "store":
		return int(h.get("guid", 0)) == int(u.get("haul_origin", 0))
	return false

func can_mission(h: Dictionary) -> bool:
	var cap: int = 1
	if String(h.get("kind", "")) == "storage":
		cap = maxi(1, int(h.get("max_n", 1)))
	var cur: int = (h.get("go_workers", []) as Array).size() + (h.get("go_incoming", []) as Array).size()
	return cur < cap

func step_job(dome: Dictionary, dt_ms: int) -> void:
	var jk: String = String(u.get("job_kind", ""))
	if jk == "":
		return
	if (u.get("job_route", []) as Array).is_empty():
		if find_job_spot(dome) == false:
			u["job_kind"] = ""
			u["job_house"] = 0
			return
	var dt: float = float(dt_ms) / 1000.0
	if bool(u.get("job_done", false)) == false:
		if walk_route("job", dt):
			if jk == "incident":
				var hb: Dictionary = house_by_guid(dome, int(u.get("job_house", 0)))
				if hb.is_empty() == false:
					var bp: Vector2 = house_pos(hb)
					var p: Vector2 = u["pos"]
					if p.distance_squared_to(bp) < 6400.0:
						u["job_done"] = true
						join_mission(dome)
				else:
					u["job_done"] = true
					join_mission(dome)
			else:
				u["job_done"] = true
				join_mission(dome)
	else:
		u["job_left_ms"] = int(u.get("job_left_ms", 0)) - dt_ms
		if int(u.get("job_left_ms", 0)) <= 0:
			var hb2: Dictionary = house_by_guid(dome, int(u.get("job_house", 0)))
			var stay: bool = false
			if jk == "repair" and hb2.is_empty() == false and float(hb2.get("damage", 0.0)) > 0.01:
				stay = true
			if jk == "incident" and hb2.is_empty() == false and int(hb2.get("foe", 0)) != 0:
				stay = true
			if stay:
				u["job_left_ms"] = JOB_MS
			else:
				leave_mission(dome)

func house_by_guid(dome: Dictionary, g: int) -> Dictionary:
	for h in dome.get("buildings", []):
		if h is Dictionary and int((h as Dictionary).get("guid", 0)) == g:
			return h
	return {}

func join_mission(dome: Dictionary) -> void:
	var hg: int = int(u.get("job_house", 0))
	var hb: Dictionary = house_by_guid(dome, hg)
	if hb.is_empty():
		return
	var arr: Array = hb.get("go_incoming", [])
	var kept: Array = []
	for g in arr:
		if int(g) != int(u.get("guid", 0)):
			kept.append(int(g))
	hb["go_incoming"] = kept
	var w: Array = hb.get("go_workers", [])
	if w.has(int(u.get("guid", 0))) == false:
		w.append(int(u.get("guid", 0)))

func leave_mission(dome: Dictionary) -> void:
	var hg: int = int(u.get("job_house", 0))
	var hb: Dictionary = house_by_guid(dome, hg)
	if hb.is_empty() == false:
		var w: Array = hb.get("go_workers", [])
		var kept: Array = []
		for g in w:
			if int(g) != int(u.get("guid", 0)):
				kept.append(int(g))
		hb["go_workers"] = kept
		var jk: String = String(u.get("job_kind", ""))
		if jk == "fetch":
			var res: String = ""
			var amount: float = 0.0
			if String(hb.get("kind", "")) == "teleport" and String(u.get("haul_res", "")) != "":
				res = String(u.get("haul_res", ""))
				var st: Dictionary = hb.get("store", {})
				amount = minf(15.0, float(st.get(res, 0.0)))
				st[res] = float(st.get(res, 0.0)) - amount
			elif String(u.get("haul_res", "")) != "":
				res = String(u.get("haul_res", ""))
				var st2: Dictionary = hb.get("store", {})
				amount = minf(15.0, float(st2.get(res, 0.0)))
				st2[res] = float(st2.get(res, 0.0)) - amount
			else:
				res = String(hb.get("out_res", ""))
				amount = minf(15.0, float(hb.get("out_store", 0.0)))
				hb["out_store"] = float(hb.get("out_store", 0.0)) - amount
			u["job_kind"] = "store"
			u["haul_res"] = res
			u["haul_amount"] = amount
			u["job_house"] = int(u.get("haul_origin", 0))
			u["job_route"] = []
			u["job_idx"] = 0
			u["job_done"] = false
			u["job_left_ms"] = JOB_MS
			return
		if jk == "store":
			var ob: Dictionary = house_by_guid(dome, int(u.get("haul_origin", 0)))
			if ob.is_empty() == false:
				var st3: Dictionary = ob.get("store", {})
				var r2: String = String(u.get("haul_res", ""))
				if r2 != "":
					st3[r2] = float(st3.get(r2, 0.0)) + float(u.get("haul_amount", 0.0))
			u["haul_res"] = ""
			u["haul_amount"] = 0.0
			u["haul_origin"] = 0
	u["job_kind"] = ""
	u["job_house"] = 0
	u["job_route"] = []
	u["job_idx"] = 0
	u["job_done"] = false

func step_20hz(dome: Dictionary, rng: Rng) -> void:
	var dt: float = float(STEP_MS) / 1000.0
	drain(dt)
	step_day(dome, STEP_MS, rng)
	if String(u.get("job_kind", "")) != "":
		step_job(dome, STEP_MS)
	if float(u.get("full", 0.0)) <= 0.0:
		u["full"] = 0.0
	u["happy"] = clamp01(float(u.get("happy", 0.0)))
	u["full"] = clamp01(float(u.get("full", 0.0)))
