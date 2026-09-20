class_name PlacementSystem
extends Node3D

# T2.3 — placement ghost system. Validation matrix (order matters for the
# error toast contract): outside-dome / elevator-outside / no-space /
# bad-tile (footprint or planetProperty) / missing-link (worker buildings,
# via closest super building) / prerequisite (tech) / no-resource.
# Taps place/move the ghost; pinch/pan stay with the camera rig during
# placement (Epic 6 UX requirement).

signal placement_changed(active: bool, kind: String)
signal ghost_validated(ok: bool, reason: String)
signal place_requested(kind: String, cell: Vector2i, rot: int, master_guid: int)

var manager: DomeManager = null
var camera: Camera3D = null
var current_world: DomeWorld = null

var active: bool = false
var kind: String = ""
var rot: int = 0
var ghost_cell := Vector2i(-9999, -9999)
var has_ghost: bool = false
var last_validation: Dictionary = {}
var validate_ms: float = 0.0

var _press_pos: Vector2 = Vector2.ZERO
var _press_time: float = 0.0
var _press_active: bool = false
var _pointers: int = 0
var _tap_cell := Vector2i(-9999, -9999)

var _root: Node3D = null
var _overlay: MeshInstance3D = null
var _foot_quad: MeshInstance3D = null
var _preview: Node3D = null
var _arrow: MeshInstance3D = null
var _radius_ring: MeshInstance3D = null
var _link_marker: MeshInstance3D = null
var _tex_valid: Texture2D = null
var _tex_blocked: Texture2D = null
var _tex_warning: Texture2D = null
var _tex_arrow: Texture2D = null
var _tex_radius: Texture2D = null
var _tex_link: Texture2D = null

func _ready() -> void:
	_root = Node3D.new()
	_root.name = "GhostRoot"
	add_child(_root)
	_tex_valid = _load_tex("res://assets/ui/placement/ghost_valid.png")
	_tex_blocked = _load_tex("res://assets/ui/placement/ghost_blocked.png")
	_tex_warning = _load_tex("res://assets/ui/placement/ghost_warning.png")
	_tex_arrow = _load_tex("res://assets/ui/placement/entrance_arrow.png")
	_tex_radius = _load_tex("res://assets/ui/placement/worker_radius_ring.png")
	_tex_link = _load_tex("res://assets/ui/placement/link_marker.png")
	_build_visuals()
	visible = false

static func _load_tex(p: String) -> Texture2D:
	if ResourceLoader.exists(p) == false:
		return null
	return load(p)

func _build_visuals() -> void:
	_overlay = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(1, 1, 1)
	_overlay.mesh = box
	var om := StandardMaterial3D.new()
	om.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	om.albedo_color = Color(WorldTheme.COL_VALID.r, WorldTheme.COL_VALID.g, WorldTheme.COL_VALID.b, 0.35)
	om.emission_enabled = true
	om.emission = WorldTheme.COL_VALID
	om.emission_energy_multiplier = 0.25
	om.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_overlay.material_override = om
	_root.add_child(_overlay)

	_foot_quad = MeshInstance3D.new()
	var fq := QuadMesh.new()
	fq.size = Vector2(1, 1)
	_foot_quad.mesh = fq
	_foot_quad.rotation.x = -PI * 0.5
	_foot_quad.position.y = 0.04
	_foot_quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var fm := WorldTheme.make_unshaded_mat(Color(1, 1, 1, 0.85), 0.85)
	if _tex_valid != null:
		fm.albedo_texture = _tex_valid
	_foot_quad.material_override = fm
	_root.add_child(_foot_quad)

	_arrow = MeshInstance3D.new()
	var aq := QuadMesh.new()
	aq.size = Vector2(1.6, 1.6)
	_arrow.mesh = aq
	_arrow.rotation.x = -PI * 0.5
	_arrow.position.y = 0.08
	_arrow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var am := WorldTheme.make_unshaded_mat(Color(1, 1, 1, 0.95), 0.95)
	if _tex_arrow != null:
		am.albedo_texture = _tex_arrow
	_arrow.material_override = am
	_root.add_child(_arrow)

	_radius_ring = MeshInstance3D.new()
	var rq := QuadMesh.new()
	rq.size = Vector2(2, 2)
	_radius_ring.mesh = rq
	_radius_ring.rotation.x = -PI * 0.5
	_radius_ring.position.y = 0.05
	_radius_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var rm := WorldTheme.make_unshaded_mat(Color(1, 1, 1, 0.5), 0.5)
	if _tex_radius != null:
		rm.albedo_texture = _tex_radius
	_radius_ring.material_override = rm
	_root.add_child(_radius_ring)

	_link_marker = MeshInstance3D.new()
	var lq := QuadMesh.new()
	lq.size = Vector2(1.2, 1.2)
	_link_marker.mesh = lq
	_link_marker.rotation.x = -PI * 0.5
	_link_marker.position.y = 0.07
	_link_marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var lm := WorldTheme.make_unshaded_mat(Color(1, 1, 1, 0.9), 0.9)
	if _tex_link != null:
		lm.albedo_texture = _tex_link
	_link_marker.material_override = lm
	_root.add_child(_link_marker)

func start_placement(p_kind: String) -> void:
	kind = p_kind
	rot = 0
	active = true
	has_ghost = false
	visible = true
	_refresh_preview()
	placement_changed.emit(true, kind)

func cancel() -> void:
	active = false
	kind = ""
	has_ghost = false
	visible = false
	last_validation = {}
	placement_changed.emit(false, "")

func rotate_ghost() -> void:
	if active == false:
		return
	rot = (rot + 1) % 4
	if has_ghost:
		_refresh_preview()
		_update_ghost(ghost_cell)

func footprint_of(p_kind: String, p_rot: int) -> Vector2i:
	var def: Dictionary = _def(p_kind)
	var dw: int = int(def.get("width", 3))
	var dh: int = int(def.get("height", 3))
	if p_rot % 2 == 1:
		return Vector2i(dh, dw)
	return Vector2i(dw, dh)

func _def(p_kind: String) -> Dictionary:
	var dw := _current_dome_world()
	if dw == null:
		return {}
	return (dw.dome as DomeSim).bdef(p_kind)

# ---------------------------------------------------------------- validation

# Full T2.3 matrix. Returns {"ok": bool, "reason": String, "master_guid": int}.
func validate(dw: DomeWorld, p_kind: String, cell: Vector2i, p_rot: int) -> Dictionary:
	var t0: int = Time.get_ticks_usec()
	# by_type/by_guid must reflect any place()/unplace() since last sync.
	dw.dome.sync_indices()
	var out: Dictionary = _validate_inner(dw, p_kind, cell, p_rot)
	validate_ms = float(Time.get_ticks_usec() - t0) / 1000.0
	return out

func _validate_inner(dw: DomeWorld, p_kind: String, cell: Vector2i, p_rot: int) -> Dictionary:
	var out := {"ok": false, "reason": "bad-tile", "master_guid": 0}
	var dome: DomeSim = dw.dome
	var def: Dictionary = dome.bdef(p_kind)
	if def.is_empty():
		out["reason"] = "bad-tile"
		return out
	var size := footprint_of(p_kind, p_rot)
	var w: int = size.x
	var h: int = size.y
	var end := cell + size
	if cell.x < 0 or cell.y < 0 or end.x > WorldTheme.PLANET_SIZE or end.y > WorldTheme.PLANET_SIZE:
		out["reason"] = "outside-dome"
		return out
	if p_kind == "elevator":
		# Elevator special: must sit outside every dome rect (no overlap
		# exploit) and there must be room to land an 80x80 dome.
		var probe := Rect2i(cell, size)
		if dw.rect.intersects(probe) or manager.rect_overlaps_any(probe.grow(1)):
			out["reason"] = "elevator-outside"
			return out
		var rect: Rect2i = manager.find_new_dome_rect(dome, cell)
		if rect.size == Vector2i.ZERO:
			out["reason"] = "no-space"
			return out
		out["ok"] = true
		return out
	# Standard buildings: fully inside the dome rect.
	if cell.x < dw.rect.position.x or cell.y < dw.rect.position.y:
		out["reason"] = "outside-dome"
		return out
	if end.x > dw.rect.end.x or end.y > dw.rect.end.y:
		out["reason"] = "outside-dome"
		return out
	# Footprint free (mirrors DomeSim.footprint_free semantics incl. w+1 strip).
	if dome.footprint_free(cell, w, h) == false:
		out["reason"] = "bad-tile"
		return out
	# planetProperty tile check (JSON null must not become the string "null").
	var pval: Variant = def.get("planetProperty")
	var pname: String = ""
	if pval != null:
		pname = String(pval)
	if pname != "":
		var key: String = pname
		if key == "isMineable":
			key = "mineable"
		if key == "isFarmable":
			key = "farmable"
		if key == "isOreMineable":
			key = "oreMineable"
		if dome.footprint_has_prop(cell, w, h, key) == false:
			out["reason"] = "bad-tile"
			return out
	# Worker buildings: link check via closest super building.
	var master_guid: int = 0
	if bool(def.get("isWorkerBuilding", false)):
		var link := _closest_super_building(dome, p_kind, def, cell, w, h)
		if link.is_empty():
			out["reason"] = "missing-link"
			return out
		master_guid = int(link["master"]["guid"])
		out["master_guid"] = master_guid
		# Slot capacity: master may not already be fully linked.
		var master: Dictionary = link["master"]
		var slots: int = 0
		for g in master.get("linked", []):
			if dome.by_guid.has(int(g)):
				slots += 1
		if slots >= maxi(1, dome.max_workers(master)):
			out["reason"] = "missing-link"
			return out
	# Tech preconditions.
	if dome.precondition_met(p_kind) == false:
		out["reason"] = "prerequisite"
		return out
	# Resource check.
	var cost_s: float = float(def.get("stone", 0))
	var cost_a: float = float(def.get("alloy_cost", 0))
	if dome.test_for("stone", cost_s) < cost_s or dome.test_for("alloy", cost_a) < cost_a:
		out["reason"] = "no-resource"
		return out
	out["ok"] = true
	return out

# getClosestSuperBuilding equivalent: nearest functional building of the
# perWorker link type within maxRadius (+ footprint slack, mirroring place()).
func _closest_super_building(dome: DomeSim, kind: String, def: Dictionary, cell: Vector2i, w: int, h: int) -> Dictionary:
	# DomeSim.place() resolves the link kind from the worker def first, then
	# falls back to the master's def (e.g. farmarea itself has no perWorker;
	# the farm declares perWorker.building = "farmarea"). Mirror that here.
	var link_kind: String = ""
	var radius: float = 20.0
	var pw: Variant = def.get("perWorker")
	if pw is Dictionary:
		var pwd: Dictionary = pw
		link_kind = String(pwd.get("building", ""))
		radius = float(pwd.get("maxRadius", 20.0))
	if link_kind == "":
		for t in dome.defs.keys():
			var td: Dictionary = dome.defs[t]
			var tpw: Variant = td.get("perWorker")
			if tpw is Dictionary and String((tpw as Dictionary).get("building", "")) == kind:
				link_kind = t
				radius = float((tpw as Dictionary).get("maxRadius", 20.0))
	if link_kind == "":
		return {}
	var want_pos: Vector2 = DomeSim.cell_to_pos(cell)
	var cands: Array = dome.functional_of(link_kind)
	if cands.is_empty():
		return {}
	var in_range: Array = []
	for c in cands:
		if c is Dictionary == false:
			continue
		var cd: Dictionary = c
		var mp: Vector2 = cd.get("hub", Vector2.ZERO)
		var slack: float = float(maxi(w, h)) * DomeSim.TILE
		if mp.distance_to(want_pos) <= radius * DomeSim.TILE + slack:
			in_range.append(cd)
	if in_range.is_empty():
		return {}
	dome.sort_by_dist2(in_range, want_pos)
	return {"master": in_range[0], "radius": radius}

# ---------------------------------------------------------------- ghost visuals

func _refresh_preview() -> void:
	if _preview != null:
		_root.remove_child(_preview)
		_preview.queue_free()
		_preview = null
	var size := footprint_of(kind, rot)
	(_overlay.mesh as BoxMesh).size = Vector3(float(size.x) * 0.96, 2.2, float(size.y) * 0.96)
	var model: Node3D = BuildingView._glb_scene(kind)
	if model != null:
		_preview = model
		_root.add_child(_preview)
		_apply_ghost_tint(model, 0.45)
	else:
		_preview = null

func _apply_ghost_tint(node: Node, alpha: float) -> void:
	# Greybox models carry stable VH_* materials; lighten them while ghosting.
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		var src: Material = null
		if mi.mesh != null:
			src = mi.get_active_material(0)
		if src is BaseMaterial3D:
			var ghost_mat: BaseMaterial3D = (src as BaseMaterial3D).duplicate()
			ghost_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			ghost_mat.albedo_color.a = alpha
			mi.material_override = ghost_mat
	for child in node.get_children():
		_apply_ghost_tint(child, alpha)

func _update_ghost(cell: Vector2i) -> void:
	var size := footprint_of(kind, rot)
	var hub := Vector3(float(cell.x) + float(size.x) * 0.5, 0.0, float(cell.y) + float(size.y) * 0.5)
	_root.position = hub
	_root.rotation.y = -float(rot) * PI * 0.5
	var fq := _foot_quad.mesh as QuadMesh
	fq.size = Vector2(float(size.x), float(size.y))
	var v: Dictionary = last_validation
	var tex: Texture2D = _tex_valid
	var tint := Color(WorldTheme.COL_VALID.r, WorldTheme.COL_VALID.g, WorldTheme.COL_VALID.b, 0.4)
	var ok: bool = bool(v.get("ok", false))
	var reason: String = String(v.get("reason", ""))
	if ok == false:
		tex = _tex_blocked
		tint = Color(WorldTheme.COL_DANGER.r, WorldTheme.COL_DANGER.g, WorldTheme.COL_DANGER.b, 0.4)
		if reason == "missing-link" or reason == "no-resource":
			tex = _tex_warning
			tint = Color(WorldTheme.COL_AMBER.r, WorldTheme.COL_AMBER.g, WorldTheme.COL_AMBER.b, 0.4)
	var fm: StandardMaterial3D = _foot_quad.material_override as StandardMaterial3D
	fm.albedo_texture = tex
	fm.albedo_color = Color(1, 1, 1, 0.9)
	var om: StandardMaterial3D = _overlay.material_override as StandardMaterial3D
	om.albedo_color = tint
	om.emission = Color(tint.r, tint.g, tint.b)
	# Entrance arrow at the door cell, pointing outward. The arrow is a child
	# of _root (already rotated by rot), so all offsets are footprint-local.
	var arrow_visible: bool = ok and kind != "elevator"
	_arrow.visible = arrow_visible
	if arrow_visible:
		var def: Dictionary = _def(kind)
		var dw2: int = int(def.get("width", 3))
		var dh2: int = int(def.get("height", 3))
		var door_local: Vector2i
		var outward: Vector2
		if rot == 1:
			door_local = Vector2i(0, 1)
			outward = Vector2(-1.0, 0.0)
		elif rot == 2:
			door_local = Vector2i(dw2 - 1, 0)
			outward = Vector2(0.0, -1.0)
		elif rot == 3:
			door_local = Vector2i(dh2 - 1, dw2 - 1)
			outward = Vector2(1.0, 0.0)
		else:
			door_local = Vector2i(1, dh2 - 1)
			outward = Vector2(0.0, 1.0)
		var local_x: float = float(door_local.x) + 0.5 - float(size.x) * 0.5 + outward.x * 0.9
		var local_z: float = float(door_local.y) + 0.5 - float(size.y) * 0.5 + outward.y * 0.9
		_arrow.position = Vector3(local_x, 0.08, local_z)
	# Radius viz for worker buildings (perWorkerBuildingMaxRadius).
	var ring_visible: bool = false
	var link_visible: bool = false
	var dw_world := _current_dome_world()
	if dw_world != null and bool(_def(kind).get("isWorkerBuilding", false)):
		var dome2: DomeSim = dw_world.dome as DomeSim
		var link := _closest_super_building(dome2, kind, _def(kind), cell, size.x, size.y)
		if link.is_empty() == false:
			ring_visible = true
			link_visible = true
			var master: Dictionary = link["master"]
			var radius: float = float(link["radius"])
			var mpos: Vector2 = master.get("hub", Vector2.ZERO) / DomeSim.TILE
			_radius_ring.position = Vector3(mpos.x - _root.position.x, 0.05, mpos.y - _root.position.z)
			(_radius_ring.mesh as QuadMesh).size = Vector2(radius * 2.0, radius * 2.0)
			var lpos: Vector2 = (mpos + Vector2(_root.position.x, _root.position.z)) * 0.5
			_link_marker.position = Vector3(lpos.x - _root.position.x, 0.07, lpos.y - _root.position.z)
	_radius_ring.visible = ring_visible
	_link_marker.visible = link_visible

func set_ghost_cell(cell: Vector2i) -> void:
	if active == false:
		return
	ghost_cell = cell
	has_ghost = true
	var dw := _current_dome_world()
	if dw == null:
		return
	last_validation = validate(dw, kind, cell, rot)
	_update_ghost(cell)
	ghost_validated.emit(bool(last_validation.get("ok", false)), String(last_validation.get("reason", "")))

func _current_dome_world() -> DomeWorld:
	if current_world != null:
		return current_world
	if manager == null or manager.count() == 0:
		return null
	return manager.world_at(0)

# ---------------------------------------------------------------- input

func _unhandled_input(event: InputEvent) -> void:
	if active == false or camera == null:
		return
	if event is InputEventKey:
		var k := event as InputEventKey
		if k.pressed and k.echo == false:
			if k.keycode == KEY_R:
				rotate_ghost()
			elif k.keycode == KEY_ESCAPE:
				cancel()
			elif k.keycode == KEY_ENTER:
				_try_confirm()
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_press_active = true
				_press_pos = mb.position
				_press_time = Time.get_ticks_msec()
			elif _press_active:
				_press_active = false
				_handle_tap(mb.position)
		return
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			_pointers += 1
		else:
			_pointers = maxi(0, _pointers - 1)
		if st.index == 0:
			if st.pressed:
				_press_active = true
				_press_pos = st.position
				_press_time = Time.get_ticks_msec()
			elif _press_active:
				_press_active = false
				if _pointers == 0:
					_handle_tap(st.position)
		return
	if event is InputEventMouseMotion and _press_active == false:
		var mm := event as InputEventMouseMotion
		_move_ghost_to(mm.position)

func _handle_tap(screen_pos: Vector2) -> void:
	var elapsed: float = float(Time.get_ticks_msec() - _press_time)
	if elapsed > 400.0:
		return
	var moved: bool = _move_ghost_to(screen_pos)
	# Second tap on the already-placed ghost confirms (plus the HUD button).
	if moved == false and _tap_cell == ghost_cell and last_validation.get("ok", false):
		_try_confirm()

func _move_ghost_to(screen_pos: Vector2) -> bool:
	var plane := Plane(Vector3.UP, 0.0)
	var origin: Vector3 = camera.project_ray_origin(screen_pos)
	var dir: Vector3 = camera.project_ray_normal(screen_pos)
	var hit: Variant = plane.intersects_ray(origin, dir)
	if hit == null:
		return false
	var p: Vector3 = hit
	var cell := WorldTheme.world_to_cell(p)
	_tap_cell = cell
	if cell != ghost_cell:
		set_ghost_cell(cell)
		return true
	return false

func _try_confirm() -> void:
	if active == false or has_ghost == false:
		return
	if last_validation.get("ok", false) == false:
		ghost_validated.emit(false, String(last_validation.get("reason", "bad-tile")))
		return
	place_requested.emit(kind, ghost_cell, rot, int(last_validation.get("master_guid", 0)))
