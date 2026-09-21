class_name DomeManager
extends Node3D

# T2.2/T2.4 — multi-dome manager: owns DomeWorld nodes (index parity with
# PlanetSim.domes), closest-dome query, overlap-safe new-dome rect search.

var worlds: Array = []

func count() -> int:
        return worlds.size()

func world_at(i: int) -> DomeWorld:
        if i < 0 or i >= worlds.size():
                return null
        return worlds[i]

func world_for_dome(dome: DomeSim) -> DomeWorld:
        for w in worlds:
                if w is DomeWorld and (w as DomeWorld).dome == dome:
                        return w
        return null

func add_world(dome: DomeSim, rect: Rect2i, entrance_side: int) -> DomeWorld:
        var w := DomeWorld.new()
        w.name = "Dome%d" % worlds.size()
        add_child(w)
        w.setup(dome, rect, entrance_side)
        worlds.append(w)
        return w

func closest_world(pos: Vector2) -> DomeWorld:
        var best: DomeWorld = null
        var best_d: float = INF
        for w in worlds:
                if w is DomeWorld == false:
                        continue
                var dw: DomeWorld = w
                var c := dw.center_world()
                var d: float = Vector2(c.x, c.z).distance_to(pos)
                if d < best_d:
                        best_d = d
                        best = dw
        return best

func rect_overlaps_any(r: Rect2i, skip: DomeWorld = null) -> bool:
        for w in worlds:
                if w is DomeWorld == false or w == skip:
                        continue
                var dw: DomeWorld = w
                if dw.rect.intersects(r):
                        return true
        return false

func walkable_fraction(dome: DomeSim, r: Rect2i) -> float:
        var total: int = 0
        var walk: int = 0
        for x in range(r.position.x, r.end.x):
                for y in range(r.position.y, r.end.y):
                        var c := Vector2i(x, y)
                        total += 1
                        if dome.is_inside(c) and dome.is_walkable(c):
                                walk += 1
        if total <= 0:
                return 0.0
        return float(walk) / float(total)

# T2.4 — candidate dome rects for an elevator placed outside all domes.
# The elevator footprint must end up fully INSIDE the new dome, one tile
# inside the entrance edge, so its door is AStar-connected to the dome
# interior (navigation reachability; covered by the epic2 regression).
# The rect extends away from the elevator; preference order N, S, W, E.
# Returns an ordered Array of {"rect": Rect2i, "side": int} candidates that
# pass bounds/overlap/walkability checks; empty when nothing fits.
func find_new_dome_candidates(dome: DomeSim, elevator_cell: Vector2i, size: int = WorldTheme.DOME_SIZE) -> Array:
        var ex: int = elevator_cell.x
        var ey: int = elevator_cell.y
        var def: Dictionary = dome.bdef("elevator")
        var w: int = maxi(1, int(def.get("width", 4)))
        var h: int = maxi(1, int(def.get("height", 4)))
        var half: int = size / 2
        var w2: int = w / 2
        var h2: int = h / 2
        var candidates: Array = [
                # North entrance: entrance row just above the footprint.
                {"rect": Rect2i(Vector2i(ex + w2 - half, ey - 1), Vector2i(size, size)), "side": WorldTheme.SIDE_NORTH},
                # South entrance: entrance row just below the footprint.
                {"rect": Rect2i(Vector2i(ex + w2 - half, ey + h + 1 - size), Vector2i(size, size)), "side": WorldTheme.SIDE_SOUTH},
                {"rect": Rect2i(Vector2i(ex - 1, ey + h2 - half), Vector2i(size, size)), "side": WorldTheme.SIDE_WEST},
                {"rect": Rect2i(Vector2i(ex + w + 1 - size, ey + h2 - half), Vector2i(size, size)), "side": WorldTheme.SIDE_EAST},
        ]
        var out: Array = []
        for cand in candidates:
                var r: Rect2i = (cand as Dictionary)["rect"]
                var side: int = int((cand as Dictionary)["side"])
                if r.position.x < 0 or r.position.y < 0:
                        continue
                if r.end.x > WorldTheme.PLANET_SIZE or r.end.y > WorldTheme.PLANET_SIZE:
                        continue
                if rect_overlaps_any(r.grow(1)):
                        continue
                if walkable_fraction(dome, r) < 0.35:
                        continue
                if _entrance_strip_ok(dome, r, side):
                        out.append({"rect": r, "side": side})
        return out

# Best-guess rect for validation/ghost previews (geometry checks only, no
# connectivity probe). Returns {"rect": Rect2i(), "side": 0} when nothing fits.
func find_new_dome_rect(dome: DomeSim, elevator_cell: Vector2i, size: int = WorldTheme.DOME_SIZE) -> Dictionary:
        var all: Array = find_new_dome_candidates(dome, elevator_cell, size)
        if all.is_empty():
                return {"rect": Rect2i(), "side": WorldTheme.SIDE_NORTH}
        return all[0]

func _entrance_strip_ok(dome: DomeSim, r: Rect2i, side: int) -> bool:
        # Require a walkable strip just inside the entrance edge so the new
        # dome is actually enterable (no all-rock landing).
        var depth: int = 3
        var walk: int = 0
        var total: int = 0
        var north_south: bool = side == WorldTheme.SIDE_NORTH or side == WorldTheme.SIDE_SOUTH
        var from_i: int = r.position.x + 4 if north_south else r.position.y + 4
        var to_i: int = r.end.x - 4 if north_south else r.end.y - 4
        for i in range(from_i, maxi(from_i + 1, to_i)):
                for j in range(depth):
                        var c: Vector2i
                        if side == WorldTheme.SIDE_NORTH:
                                c = Vector2i(i, r.position.y + j)
                        elif side == WorldTheme.SIDE_SOUTH:
                                c = Vector2i(i, r.end.y - 1 - j)
                        elif side == WorldTheme.SIDE_WEST:
                                c = Vector2i(r.position.x + j, i)
                        else:
                                c = Vector2i(r.end.x - 1 - j, i)
                        total += 1
                        if dome.is_inside(c) and dome.is_walkable(c):
                                walk += 1
        if total <= 0:
                return false
        return float(walk) / float(total) >= 0.6
