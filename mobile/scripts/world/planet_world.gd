class_name PlanetWorld
extends Node3D

# Epic 2 runtime conductor: binds the Epic 1 sim (SimRuntime/PlanetSim) to
# the 3D world — ground, day/night, domes + pathing, building views,
# placement, elevator-to-new-dome flow (T2.4), selection/demolition, and
# camera focus. HUD lives in the UI layer and talks to this node.

const DayNightScript := preload("res://scripts/world/day_night.gd")
const DomeManagerScript := preload("res://scripts/world/dome_manager.gd")
const PlacementScript := preload("res://scripts/world/placement_system.gd")
const BuildingViewScript := preload("res://scripts/world/building_view.gd")

var sim_runtime: Node = null
var day_night: DayNight = null
var manager: DomeManager = null
var placement: PlacementSystem = null
var camera_rig: Camera3D = null
var ground: MeshInstance3D = null

var current_dome_index: int = 0
var views: Dictionary = {}          # guid -> BuildingView
var _building_signature: Dictionary = {}  # dome index -> buildings count+hash

func _ready() -> void:
        sim_runtime = get_node_or_null("../SimRuntime")
        day_night = DayNightScript.new()
        day_night.name = "DayNight"
        # Assign targets BEFORE add_child: add_child fires _ready(), which
        # needs env/sun already set (sky material detection).
        day_night.env = get_node_or_null("../WorldEnvironment")
        day_night.sun = get_node_or_null("../DirectionalLight3D")
        day_night.moon_sprite = get_node_or_null("../DistantMoon")
        add_child(day_night)
        manager = DomeManagerScript.new()
        manager.name = "DomeManager"
        add_child(manager)
        placement = PlacementScript.new()
        placement.name = "PlacementSystem"
        add_child(placement)
        placement.manager = manager
        camera_rig = get_node_or_null("../Camera3D")
        placement.camera = camera_rig
        ground = get_node_or_null("../Ground")
        placement.place_requested.connect(_on_place_requested)
        placement.ghost_validated.connect(_on_ghost_validated)
        _bootstrap_domes()

func _bootstrap_domes() -> void:
        # One DomeWorld per sim dome, in index parity with PlanetSim.domes.
        # Fresh games get their dome rect derived from the seeded elevator;
        # loaded saves restore topleft/entrance_side from the save state.
        var planet: PlanetSim = sim_runtime.planet
        if planet.domes.is_empty():
                return
        for i in planet.domes.size():
                var ds: DomeSim = planet.domes[i]
                var rect := Rect2i(ds.topleft, Vector2i(ds.dome_size, ds.dome_size))
                var side: int = ds.entrance_side
                if ds.topleft == Vector2i.ZERO:
                        var found := _derive_rect_from_elevator(ds)
                        if found.size == Vector2i.ZERO:
                                found = Rect2i(Vector2i(0, 0), Vector2i(ds.dome_size, ds.dome_size))
                                side = WorldTheme.SIDE_NORTH
                        rect = found
                        ds.topleft = rect.position
                        ds.entrance_side = side
                var w: DomeWorld = manager.add_world(ds, rect, side)
                if i == 0 and camera_rig != null:
                        camera_rig.focus(w.center_world(), 48.0, true)

func _derive_rect_from_elevator(ds: DomeSim) -> Rect2i:
        ds.sync_indices()
        var lifts: Array = ds.functional_of("elevator")
        if lifts.is_empty():
                return Rect2i()
        var lift: Dictionary = lifts[0]
        var cell: Vector2i = lift.get("cell", Vector2i.ZERO)
        var door: Vector2i = lift.get("door", cell)
        # Prefer a candidate whose interior is AStar-connected to the lift
        # door; fall back to the first geometry-viable candidate (the
        # near-origin seeded lift often has no in-bounds alternative).
        for cand in manager.find_new_dome_candidates(ds, cell, ds.dome_size):
                if _probe_connected(ds, cand["rect"], int(cand["side"]), door):
                        return cand["rect"]
        var found: Dictionary = manager.find_new_dome_rect(ds, cell, ds.dome_size)
        return found["rect"]

func _process(_delta: float) -> void:
        var planet: PlanetSim = sim_runtime.planet
        # Day/night -> solar multiplier into every dome's tune.
        var mult: float = day_night.solar_multiplier
        for d in planet.domes:
                var ds: DomeSim = d
                if absf(float(ds.tune.get("solar_mult", 1.0)) - mult) > 0.001:
                        ds.tune["solar_mult"] = mult
        # Views sync (create/remove) — cheap diff, buildings change rarely.
        _sync_views(planet)
        # Day/night visuals + fence brightness + window glow.
        for w in manager.worlds:
                (w as DomeWorld).set_daylight(day_night.daylight)
        for v in views:
                (views[v] as BuildingView).set_daylight(day_night.daylight)

func _sync_views(planet: PlanetSim) -> void:
        for i in planet.domes.size():
                var ds: DomeSim = planet.domes[i]
                ds.sync_indices()
                var sig: int = ds.buildings.size() * 2654435761 + ds.next_guid
                if _building_signature.get(i, -1) == sig:
                        continue
                _building_signature[i] = sig
                for b in ds.buildings:
                        if b is Dictionary == false:
                                continue
                        var bd: Dictionary = b
                        var g: int = int(bd.get("guid", 0))
                        if views.has(g):
                                continue
                        var view: BuildingView = BuildingViewScript.new()
                        manager.add_child(view)
                        view.build(bd)
                        views[g] = view
                var gone: Array = []
                for g in views:
                        if ds.by_guid.has(int(g)) == false:
                                var dome_match: bool = false
                                for j in planet.domes.size():
                                        if j != i and (planet.domes[j] as DomeSim).by_guid.has(int(g)):
                                                dome_match = true
                                                break
                                if dome_match == false:
                                        gone.append(g)
                for g in gone:
                        var v: BuildingView = views[g]
                        v.queue_free()
                        views.erase(g)
                if manager.world_at(i) != null:
                        manager.world_at(i).resync_pathing()

# ---------------------------------------------------------------- placement flow

func _on_place_requested(kind: String, cell: Vector2i, rot: int, master_guid: int) -> void:
        var planet: PlanetSim = sim_runtime.planet
        var dw: DomeWorld = placement.current_world if placement.current_world != null else manager.world_at(current_dome_index)
        if dw == null:
                return
        var ds: DomeSim = dw.dome
        if kind == "elevator":
                _flow_new_dome(ds, cell, rot)
                return
        var b: Dictionary = ds.place(kind, cell, rot, master_guid)
        if b.is_empty():
                _toast("toast_bad_tile", "error")
                return
        _toast(String(TranslationServer.translate("building_" + kind)) + " " + tr("toast_placed"), "info")
        if placement.active:
                placement.cancel()

var _last_reason: String = ""

func _on_ghost_validated(ok: bool, reason: String) -> void:
        if ok:
                _last_reason = ""
                return
        # Avoid toast spam while dragging the ghost across bad tiles.
        if reason == _last_reason:
                return
        _last_reason = reason
        _toast("toast_" + reason, "warning")

func _flow_new_dome(source: DomeSim, cell: Vector2i, rot: int) -> void:
        # T2.4 — elevator placed outside: create the 80x80 dome, pay from the
        # source dome, seed the elevator as the new dome's spawn/store, push to
        # manager, camera jump + zoom-out, save. The rect is chosen so the lift
        # footprint sits fully inside the new dome at its entrance edge AND the
        # lift door is AStar-connected to the dome interior; otherwise refund
        # and report no space.
        var planet: PlanetSim = sim_runtime.planet
        var def: Dictionary = source.bdef("elevator")
        var cost_s: float = float(def.get("stone", 0))
        var cost_a: float = float(def.get("alloy_cost", 0))
        if source.test_for("stone", cost_s) < cost_s or source.test_for("alloy", cost_a) < cost_a:
                _toast("toast_no_resource", "error")
                return
        var dome2 := DomeSim.new()
        dome2.setup()
        # Disjoint guid range per dome: dome N owns [N*1000000+1, ...]. Epic 1
        # dome 1 stays in 1..999999; cross-dome views/maps key on guid.
        dome2.next_guid = (planet.domes.size()) * 1000000 + 1
        var b: Dictionary = dome2.make_building("elevator", cell, rot)
        var st: Dictionary = b["store"]
        for k in planet.start_resources.keys():
                st[k] = float(planet.start_resources.get(k, 0.0))
        dome2.set_walk_rect(b, false)
        dome2.buildings.append(b)
        dome2._dirty = true
        dome2.sync_indices()
        var door: Vector2i = b["door"]
        # Pick the first candidate whose interior is actually reachable from
        # the lift door (probe on a throwaway pathing, no scene nodes).
        var chosen: Dictionary = {}
        for cand in manager.find_new_dome_candidates(dome2, cell):
                if _probe_connected(dome2, cand["rect"], int(cand["side"]), door):
                        chosen = cand
                        break
        if chosen.is_empty():
                _toast("toast_no_space", "error")
                return
        var rect: Rect2i = chosen["rect"]
        var side: int = int(chosen["side"])
        source.get_resource("stone", cost_s)
        source.get_resource("alloy", cost_a)
        dome2.topleft = rect.position
        dome2.entrance_side = side
        planet.add_dome(dome2)
        current_dome_index = planet.domes.size() - 1
        placement.current_world = manager.add_world(dome2, rect, side)
        _sync_views(planet)
        _toast("toast_new_dome", "info")
        if camera_rig != null:
                camera_rig.focus(WorldTheme.rect_center_world(rect), 90.0, true)
        sim_runtime.save_game()

func _probe_connected(dome: DomeSim, rect: Rect2i, side: int, door: Vector2i) -> bool:
        # Navigation reachability probe: lift door must path into the dome
        # interior on the cardinal-only AStarGrid2D. Uses a throwaway
        # DomePathing (RefCounted) so no live scene nodes are touched.
        if rect.has_point(door) == false:
                return false
        var p := DomePathing.new()
        p.setup(dome, rect)
        p.entrance_cells = DomeWorld.entrance_cells_for(rect, side)
        p.resync()
        var target := _nearest_walkable_cell(p, rect)
        if target == Vector2i(-1, -1):
                return false
        return p.path_exists(door, target)

func _nearest_walkable_cell(p: DomePathing, rect: Rect2i) -> Vector2i:
        var c := rect.position + rect.size / 2
        var best := Vector2i(-1, -1)
        var best_d: int = 2147483647
        for x in range(rect.position.x, rect.end.x):
                for y in range(rect.position.y, rect.end.y):
                        var cell := Vector2i(x, y)
                        if p.is_walkable(cell) == false:
                                continue
                        var d: int = absi(cell.x - c.x) + absi(cell.y - c.y)
                        if d < best_d:
                                best_d = d
                                best = cell
        return best

func select_current_dome(index: int) -> void:
        var planet: PlanetSim = sim_runtime.planet
        if index < 0 or index >= planet.domes.size():
                return
        current_dome_index = index
        placement.current_world = manager.world_at(index)
        _toast("hud_dome " + str(index + 1), "info")

func current_totals() -> Dictionary:
        var ds := _current_dome()
        if ds == null:
                return {}
        var out: Dictionary = {}
        for res in ["stone", "alloy", "biomass", "ore", "stim"]:
                out[res] = ds.total_of(res)
        return out

func _current_dome() -> DomeSim:
        var planet: PlanetSim = sim_runtime.planet
        if planet.domes.is_empty():
                return null
        return planet.domes[current_dome_index]

func _toast(key: String, kind: String) -> void:
        var t: Node = get_node_or_null("../Toasts")
        if t != null:
                t.call("show_toast", tr(key), kind)

# ---------------------------------------------------------------- selection

func select_building(guid: int) -> void:
        for g in views:
                (views[g] as BuildingView).set_selected(int(g) == guid)

func demolish_selected(guid: int) -> void:
        var ds := _current_dome()
        if ds == null or ds.by_guid.has(guid) == false:
                return
        var bd: Dictionary = ds.by_guid[guid]
        if String(bd.get("kind", "")) == "elevator":
                _toast("toast_cannot_demolish", "error")
                return
        ds.unplace(guid)
        select_building(0)
        _toast("toast_demolished", "info")

# ---------------------------------------------------------------- debug overlay data

func debug_lines() -> Array:
        var planet: PlanetSim = sim_runtime.planet
        var out: Array = []
        out.append("day: " + day_night.phase_label() + "  daylight=%.2f" % day_night.daylight)
        out.append("solar_mult=%.2f" % day_night.solar_multiplier)
        out.append("domes: " + str(planet.domes.size()))
        for i in planet.domes.size():
                var ds: DomeSim = planet.domes[i]
                out.append("dome%d solar=%.2f oxy=%.2f" % [i + 1, ds.energy_saturation(), ds.oxygen_saturation()])
        out.append("validate_ms=%.3f" % placement.validate_ms)
        return out

# ---------------------------------------------------------------- idle tap (selection / dome focus)

var _tap_down_pos: Vector2 = Vector2.ZERO
var _tap_down_time: int = 0
var _tap_down: bool = false
var selected_guid: int = 0

func _unhandled_input(event: InputEvent) -> void:
        if placement.active or camera_rig == null:
                return
        if event is InputEventMouseButton:
                var mb := event as InputEventMouseButton
                if mb.button_index == MOUSE_BUTTON_LEFT:
                        if mb.pressed:
                                _tap_down = true
                                _tap_down_pos = mb.position
                                _tap_down_time = Time.get_ticks_msec()
                        elif _tap_down:
                                _tap_down = false
                                if float(Time.get_ticks_msec() - _tap_down_time) <= 400.0:
                                        _idle_tap(mb.position)
                return
        if event is InputEventScreenTouch:
                var st := event as InputEventScreenTouch
                if st.index == 0:
                        if st.pressed:
                                _tap_down = true
                                _tap_down_pos = st.position
                                _tap_down_time = Time.get_ticks_msec()
                        elif _tap_down:
                                _tap_down = false
                                if float(Time.get_ticks_msec() - _tap_down_time) <= 400.0:
                                        _idle_tap(st.position)

func _idle_tap(screen_pos: Vector2) -> void:
        var plane := Plane(Vector3.UP, 0.0)
        var origin: Vector3 = camera_rig.project_ray_origin(screen_pos)
        var dir: Vector3 = camera_rig.project_ray_normal(screen_pos)
        var hit: Variant = plane.intersects_ray(origin, dir)
        if hit == null:
                return
        var p: Vector3 = hit
        var cell := WorldTheme.world_to_cell(p)
        # Building selection across all domes.
        var planet: PlanetSim = sim_runtime.planet
        for i in planet.domes.size():
                var ds: DomeSim = planet.domes[i]
                for b in ds.buildings:
                        if b is Dictionary == false:
                                continue
                        var bd: Dictionary = b
                        var c: Vector2i = bd.get("cell", Vector2i(-1, -1))
                        var w: int = int(bd.get("w", 0))
                        var h: int = int(bd.get("h", 0))
                        if cell.x >= c.x and cell.x < c.x + w and cell.y >= c.y and cell.y < c.y + h:
                                selected_guid = int(bd.get("guid", 0))
                                select_building(selected_guid)
                                return
        # Ground tap: switch current dome if inside a dome rect.
        for i in manager.worlds.size():
                var w2: DomeWorld = manager.worlds[i]
                if w2.rect.has_point(cell):
                        if i != current_dome_index:
                                select_current_dome(i)
                        return
        select_building(0)
        selected_guid = 0
