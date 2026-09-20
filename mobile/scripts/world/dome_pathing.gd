class_name DomePathing
extends RefCounted

# T2.2 — 80x80 AStarGrid2D per dome. Cardinal movement only
# (DIAGONAL_MODE_NEVER, per the Epic 2 default; any diagonal mode is an
# explicit mobile-design change with new placement/path tests).
# place_walkable / remove semantics mirror dome.js placeWalkable/removeWalkable;
# entrance cells are always kept walkable.

var dome: DomeSim = null
var rect: Rect2i = Rect2i()
var entrance_cells: Array = []
var _astar := AStarGrid2D.new()

func setup(p_dome: DomeSim, p_rect: Rect2i) -> void:
	dome = p_dome
	rect = p_rect
	_astar.region = rect
	_astar.cell_size = Vector2(1.0, 1.0)
	_astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	_astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	_astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	_astar.update()
	resync()

func resync() -> void:
	if dome == null:
		return
	for x in range(rect.position.x, rect.end.x):
		for y in range(rect.position.y, rect.end.y):
			var c := Vector2i(x, y)
			var walkable: bool = dome.is_inside(c) and dome.is_walkable(c)
			_astar.set_point_solid(c, not walkable)
	for c in entrance_cells:
		var e := Vector2i(int(c.x), int(c.y))
		if rect.has_point(e):
			_astar.set_point_solid(e, false)

# Mirrors dome.js placeWalkable/removeWalkable for one cell.
# The dome entrance can never be blocked (T2.2: entrance kept walkable).
func place_walkable(cell: Vector2i, walkable: bool) -> void:
	if rect.has_point(cell) == false:
		return
	if walkable == false and entrance_cells.has(cell):
		return
	_astar.set_point_solid(cell, not walkable)

func remove_walkable(cell: Vector2i) -> void:
	place_walkable(cell, false)

func is_walkable(cell: Vector2i) -> bool:
	if rect.has_point(cell) == false:
		return false
	return _astar.is_in_boundsv(cell) == false or _astar.is_point_solid(cell) == false

func find_path(from: Vector2i, to: Vector2i) -> Array:
	if rect.has_point(from) == false or rect.has_point(to) == false:
		return []
	if _astar.is_in_boundsv(from) == false or _astar.is_in_boundsv(to) == false:
		return []
	if _astar.is_point_solid(to):
		return []
	var raw: PackedVector2Array = _astar.get_point_path(from, to)
	var out: Array = []
	for v in raw:
		out.append(Vector2i(int(v.x), int(v.y)))
	return out

func path_exists(from: Vector2i, to: Vector2i) -> bool:
	return find_path(from, to).is_empty() == false
