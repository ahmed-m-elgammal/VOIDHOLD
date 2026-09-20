class_name WorldTheme
extends RefCounted

# Shared world-space constants and mapping helpers for the Epic 2 runtime.
# The 3D world uses 1 tile = 1 meter: grid cell (x, y) covers world
# [x, x+1) x [y, y+1) on the XZ plane (grid y maps to world z).

const PLANET_SIZE: int = 210
const DOME_SIZE: int = 80
const GROUND_SUBDIV: int = 64

# Palette anchors (art bible T0.9 / ASSET_REQUIREMENTS section 3).
const COL_SNOW := Color("e8eef4")
const COL_ICE := Color("bcd8e8")
const COL_ROCK := Color("6b7280")
const COL_ALLOY := Color("3a4750")
const COL_AMBER := Color("ffb020")
const COL_WARM := Color("ffc37a")
const COL_VALID := Color("35d07f")
const COL_DANGER := Color("ff4d4d")
const COL_CYAN := Color("47d8ff")

const SIDE_NORTH: int = 0
const SIDE_EAST: int = 1
const SIDE_SOUTH: int = 2
const SIDE_WEST: int = 3

static func cell_to_world(cell: Vector2i) -> Vector3:
	return Vector3(float(cell.x) + 0.5, 0.0, float(cell.y) + 0.5)

static func world_to_cell(p: Vector3) -> Vector2i:
	return Vector2i(int(floor(p.x)), int(floor(p.z)))

static func cell_rect_world(cell: Vector2i, w: int, h: int) -> Rect2:
	return Rect2(float(cell.x), float(cell.y), float(w), float(h))

static func rect_center_world(r: Rect2i) -> Vector3:
	return Vector3(float(r.position.x) + float(r.size.x) * 0.5, 0.0, float(r.position.y) + float(r.size.y) * 0.5)

# Edge midpoint of a rect for a given side (0=north,1=east,2=south,3=west).
static func side_midpoint(r: Rect2i, side: int) -> Vector3:
	var c := rect_center_world(r)
	if side == SIDE_NORTH:
		return Vector3(c.x, 0.0, float(r.position.y))
	if side == SIDE_EAST:
		return Vector3(float(r.end.x), 0.0, c.z)
	if side == SIDE_SOUTH:
		return Vector3(c.x, 0.0, float(r.end.y))
	return Vector3(float(r.position.x), 0.0, c.z)

# Inward unit direction for a rect side.
static func side_inward(side: int) -> Vector3:
	if side == SIDE_NORTH:
		return Vector3(0.0, 0.0, 1.0)
	if side == SIDE_EAST:
		return Vector3(-1.0, 0.0, 0.0)
	if side == SIDE_SOUTH:
		return Vector3(0.0, 0.0, -1.0)
	return Vector3(1.0, 0.0, 0.0)

# Outward normal yaw (radians) for a rect side, for props that face outward.
static func side_yaw(side: int) -> float:
	if side == SIDE_NORTH:
		return 0.0
	if side == SIDE_EAST:
		return PI * 0.5
	if side == SIDE_SOUTH:
		return PI
	return PI * 1.5

static func make_unshaded_mat(color: Color, alpha: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(color.r, color.g, color.b, alpha)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.no_depth_test = false
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m
