class_name BuildingView
extends Node3D

# World-space visual for one sim building. Prefers the greybox .glb kit
# (assets/domes/greybox), falls back to a footprint-correct procedural box
# with an amber roof stripe + warm window strip (night glow) so all 18
# canonical kinds are representable in greybox.

const GLB_KINDS: Array = ["oxygen", "living", "farmarea", "solar", "storage", "teleport", "elevator", "dome_entrance"]
# Greybox heights (meters) for kinds without a model yet.
const BOX_HEIGHTS: Dictionary = {
	"authority": 6.0, "bar": 4.0, "cantine": 4.0, "factory": 6.0, "farm": 3.5,
	"kitchen": 4.5, "maintenance": 3.5, "mine": 5.0, "mineshaft": 4.0,
	"oremine": 5.0, "quarter": 5.5
}

var guid: int = 0
var kind: String = ""
var data: Dictionary = {}
var selected: bool = false

var _ring: MeshInstance3D = null
var _glow_mat: StandardMaterial3D = null

static func _glb_scene(k: String) -> Node3D:
	var full := "res://assets/domes/greybox/" + k + ".glb"
	if ResourceLoader.exists(full) == false:
		return null
	var res: Variant = load(full)
	if res is PackedScene == false:
		return null
	var ps: PackedScene = res
	var inst: Variant = ps.instantiate()
	if inst is Node3D == false:
		return null
	return inst

func build(b: Dictionary) -> void:
	data = b
	guid = int(b.get("guid", 0))
	kind = String(b.get("kind", ""))
	var cell: Vector2i = b.get("cell", Vector2i.ZERO)
	var w: int = int(b.get("w", 3))
	var h: int = int(b.get("h", 3))
	var rot: int = int(b.get("rot", 0))
	var hub := Vector3(float(cell.x) + float(w) * 0.5, 0.0, float(cell.y) + float(h) * 0.5)
	position = hub
	rotation.y = -float(rot) * PI * 0.5

	var model: Node3D = BuildingView._glb_scene(kind)
	if model != null:
		add_child(model)
	else:
		_build_box(w, h)

	# Selection ring on the ground.
	var ring_size: float = float(maxi(w, h)) + 2.0
	var quad := QuadMesh.new()
	quad.size = Vector2(ring_size, ring_size)
	_ring = MeshInstance3D.new()
	_ring.mesh = quad
	_ring.rotation.x = -PI * 0.5
	_ring.position.y = 0.06
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var ring_mat := WorldTheme.make_unshaded_mat(Color(1, 1, 1, 1), 0.9)
	var ring_tex_path := "res://assets/ui/placement/selection_ring.png"
	if ResourceLoader.exists(ring_tex_path):
		ring_mat.albedo_texture = load(ring_tex_path)
	else:
		ring_mat.albedo_color = Color(WorldTheme.COL_CYAN.r, WorldTheme.COL_CYAN.g, WorldTheme.COL_CYAN.b, 0.8)
	_ring.material_override = ring_mat
	_ring.visible = false
	add_child(_ring)

func _build_box(w: int, h: int) -> void:
	var height: float = float(BOX_HEIGHTS.get(kind, 3.0))
	var mesh := BoxMesh.new()
	mesh.size = Vector3(float(w) * 0.9, height, float(h) * 0.9)
	var body := MeshInstance3D.new()
	body.mesh = mesh
	body.position.y = height * 0.5
	var m := StandardMaterial3D.new()
	m.albedo_color = WorldTheme.COL_ALLOY
	m.roughness = 0.65
	m.metallic = 0.2
	body.material_override = m
	add_child(body)
	# Amber roof stripe (safety accent).
	var stripe := MeshInstance3D.new()
	var smesh := BoxMesh.new()
	smesh.size = Vector3(float(w) * 0.92, 0.25, float(h) * 0.3)
	stripe.mesh = smesh
	stripe.position.y = height + 0.12
	var sm := StandardMaterial3D.new()
	sm.albedo_color = WorldTheme.COL_AMBER
	sm.emission_enabled = true
	sm.emission = WorldTheme.COL_AMBER
	sm.emission_energy_multiplier = 0.4
	stripe.material_override = sm
	add_child(stripe)
	# Warm window strip facing +Z (hab light at night).
	var win := MeshInstance3D.new()
	var wmesh := BoxMesh.new()
	wmesh.size = Vector3(float(w) * 0.6, height * 0.25, 0.1)
	win.mesh = wmesh
	win.position = Vector3(0.0, height * 0.55, float(h) * 0.452)
	_glow_mat = StandardMaterial3D.new()
	_glow_mat.albedo_color = WorldTheme.COL_WARM
	_glow_mat.emission_enabled = true
	_glow_mat.emission = WorldTheme.COL_WARM
	_glow_mat.emission_energy_multiplier = 0.0
	win.material_override = _glow_mat
	add_child(win)

func set_selected(v: bool) -> void:
	selected = v
	if _ring != null:
		_ring.visible = v

func set_daylight(v: float) -> void:
	if _glow_mat != null:
		_glow_mat.emission_energy_multiplier = (1.0 - v) * 1.6
