class_name DomeWorld
extends Node3D

# T2.2 — per-dome world node: laser-fence ring (shader), posts + gate,
# dome shell placeholder, entrance prop, and the AStarGrid2D wrapper.
# One DomeWorld per DomeSim; index parity with PlanetSim.domes is kept by
# DomeManager.

const FenceShader := preload("res://shaders/fence_ring.gdshader")
const FENCE_STRAND_PATH := "res://assets/domes/fence/fence_strand_gradient.png"
const FENCE_PULSE_PATH := "res://assets/domes/fence/fence_pulse_sheet.png"
const TILE: float = 1.0
const FENCE_HEIGHT: float = 3.0
const ENTRANCE_GAP: float = 8.0

var dome: DomeSim = null
var pathing: DomePathing = DomePathing.new()
var rect: Rect2i = Rect2i()
var entrance_side: int = WorldTheme.SIDE_WEST

var _fence_material: ShaderMaterial = null
var _segments: Array = []
var _props_root: Node3D = null
var _shell: Node3D = null

static func load_glb(rel_path: String) -> Node3D:
        var full := "res://assets/domes/greybox/" + rel_path
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

func setup(p_dome: DomeSim, p_rect: Rect2i, p_entrance_side: int) -> void:
        dome = p_dome
        rect = p_rect
        entrance_side = p_entrance_side
        pathing.setup(dome, rect)
        pathing.entrance_cells = _entrance_cells()
        pathing.resync()
        _fence_material = ShaderMaterial.new()
        _fence_material.shader = FenceShader
        _fence_material.set_shader_parameter("glow_color", WorldTheme.COL_CYAN)
        _fence_material.set_shader_parameter("strand_count", 3.0)
        _fence_material.set_shader_parameter("pulse_speed", 0.22)
        _fence_material.set_shader_parameter("brightness", 1.35)
        _bind_fence_textures()
        _build_fence()
        _build_props()

func _bind_fence_textures() -> void:
        # E2-03: the strand/pulse FX assets must be bound at runtime or the
        # shader falls back to flat default samplers (plain additive quad).
        if ResourceLoader.exists(FENCE_STRAND_PATH):
                _fence_material.set_shader_parameter("strand_tex", load(FENCE_STRAND_PATH))
        if ResourceLoader.exists(FENCE_PULSE_PATH):
                _fence_material.set_shader_parameter("pulse_tex", load(FENCE_PULSE_PATH))

static func entrance_cells_for(p_rect: Rect2i, p_side: int) -> Array:
        # Entrance gap cells: centered on the edge, ENTRANCE_GAP wide.
        # Static so the T2.4 connectivity probe can mirror DomeWorld's gap.
        var out: Array = []
        var mid: Vector2
        if p_side == WorldTheme.SIDE_NORTH:
                mid = Vector2(float(p_rect.position.x) + float(p_rect.size.x) * 0.5, float(p_rect.position.y))
        elif p_side == WorldTheme.SIDE_EAST:
                mid = Vector2(float(p_rect.end.x) - 1.0, float(p_rect.position.y) + float(p_rect.size.y) * 0.5)
        elif p_side == WorldTheme.SIDE_SOUTH:
                mid = Vector2(float(p_rect.position.x) + float(p_rect.size.x) * 0.5, float(p_rect.end.y) - 1.0)
        else:
                mid = Vector2(float(p_rect.position.x), float(p_rect.position.y) + float(p_rect.size.y) * 0.5)
        var along := Vector2(1.0, 0.0)
        if p_side == WorldTheme.SIDE_WEST or p_side == WorldTheme.SIDE_EAST:
                along = Vector2(0.0, 1.0)
        var half: float = ENTRANCE_GAP * 0.5
        for i in range(int(ceil(-half)), int(floor(half)) + 1):
                var p := mid + along * float(i)
                var c := Vector2i(int(floor(p.x)), int(floor(p.y)))
                if p_rect.has_point(c):
                        out.append(c)
        return out

func _entrance_cells() -> Array:
        return entrance_cells_for(rect, entrance_side)

func _side_midpoint_uv(side: int) -> Vector2:
        if side == WorldTheme.SIDE_NORTH:
                return Vector2(float(rect.position.x) + float(rect.size.x) * 0.5, float(rect.position.y))
        if side == WorldTheme.SIDE_EAST:
                return Vector2(float(rect.end.x) - 1.0, float(rect.position.y) + float(rect.size.y) * 0.5)
        if side == WorldTheme.SIDE_SOUTH:
                return Vector2(float(rect.position.x) + float(rect.size.x) * 0.5, float(rect.end.y) - 1.0)
        return Vector2(float(rect.position.x), float(rect.position.y) + float(rect.size.y) * 0.5)

func _side_along(side: int) -> Vector2:
        if side == WorldTheme.SIDE_NORTH or side == WorldTheme.SIDE_SOUTH:
                return Vector2(1.0, 0.0)
        return Vector2(0.0, 1.0)

# Builds the fence ring as straight quad segments, leaving an entrance gap.
func _build_fence() -> void:
        var edges: Array = [
                {"side": WorldTheme.SIDE_NORTH, "a": Vector2(float(rect.position.x), float(rect.position.y)), "b": Vector2(float(rect.end.x), float(rect.position.y))},
                {"side": WorldTheme.SIDE_EAST, "a": Vector2(float(rect.end.x), float(rect.position.y)), "b": Vector2(float(rect.end.x), float(rect.end.y))},
                {"side": WorldTheme.SIDE_SOUTH, "a": Vector2(float(rect.end.x), float(rect.end.y)), "b": Vector2(float(rect.position.x), float(rect.end.y))},
                {"side": WorldTheme.SIDE_WEST, "a": Vector2(float(rect.position.x), float(rect.end.y)), "b": Vector2(float(rect.position.x), float(rect.position.y))},
        ]
        for e in edges:
                var side: int = int((e as Dictionary)["side"])
                var a: Vector2 = (e as Dictionary)["a"]
                var b: Vector2 = (e as Dictionary)["b"]
                if side == entrance_side:
                        var mid: Vector2 = _side_midpoint_uv(side) + _side_along(side) * 0.5
                        var dir: Vector2 = (b - a).normalized()
                        var half: float = ENTRANCE_GAP * 0.5
                        _fence_segment(a, mid - dir * half, side)
                        _fence_segment(mid + dir * half, b, side)
                else:
                        _fence_segment(a, b, side)

func _fence_segment(from: Vector2, to: Vector2, side: int) -> void:
        var seg_len: float = (to - from).length()
        if seg_len < 0.5:
                return
        var quad := QuadMesh.new()
        quad.size = Vector2(seg_len, FENCE_HEIGHT)
        var mi := MeshInstance3D.new()
        mi.mesh = quad
        mi.material_override = _fence_material
        var center2: Vector2 = (from + to) * 0.5
        mi.position = Vector3(center2.x, FENCE_HEIGHT * 0.5, center2.y)
        var dir: Vector2 = (to - from).normalized()
        # QuadMesh faces +Z; yaw so its local +X aligns with the segment direction.
        mi.rotation.y = atan2(-dir.y, dir.x)
        mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        add_child(mi)
        _segments.append(mi)
        # Fade the fence toward the void-facing side for depth cue.
        _fence_segment_posts(from, to, side)

func _fence_segment_posts(from: Vector2, to: Vector2, side: int) -> void:
        var dist: float = (to - from).length()
        var dir: Vector2 = (to - from).normalized()
        var step: float = 10.0
        var d: float = 0.0
        while d <= dist + 0.01:
                var p: Vector2 = from + dir * d
                _add_post(Vector3(p.x, 0.0, p.y), side)
                d += step

func _add_post(p: Vector3, side: int) -> void:
        if _props_root == null:
                _props_root = Node3D.new()
                _props_root.name = "FenceProps"
                add_child(_props_root)
        var yaw: float = WorldTheme.side_yaw(side)
        var post: Node3D = DomeWorld.load_glb("fence_post.glb")
        if post != null:
                post.position = p
                post.rotation.y = yaw
                _props_root.add_child(post)
        else:
                var box := MeshInstance3D.new()
                var mesh := BoxMesh.new()
                mesh.size = Vector3(0.5, FENCE_HEIGHT + 0.6, 0.5)
                box.mesh = mesh
                box.position = p + Vector3(0.0, (FENCE_HEIGHT + 0.6) * 0.5, 0.0)
                var m := StandardMaterial3D.new()
                m.albedo_color = WorldTheme.COL_ALLOY
                box.material_override = m
                _props_root.add_child(box)

func _build_props() -> void:
        if _props_root == null:
                _props_root = Node3D.new()
                _props_root.name = "FenceProps"
                add_child(_props_root)
        # Gate at the entrance gap.
        var mid_uv := _side_midpoint_uv(entrance_side)
        var gate_pos := Vector3(mid_uv.x + _side_along(entrance_side).x * 0.0, 0.0, mid_uv.y)
        var yaw: float = WorldTheme.side_yaw(entrance_side)
        var gate: Node3D = DomeWorld.load_glb("fence_gate.glb")
        if gate != null:
                gate.position = gate_pos
                gate.rotation.y = yaw
                _props_root.add_child(gate)
        # Airlock/entrance prop just inside the gap.
        var inward := WorldTheme.side_inward(entrance_side)
        var entrance: Node3D = DomeWorld.load_glb("dome_entrance.glb")
        if entrance != null:
                entrance.position = gate_pos + inward * 3.0
                entrance.rotation.y = yaw
                _props_root.add_child(entrance)
        # Dome shell placeholder (alpha-blended hemisphere, r=40 for 80x80).
        var shell_glb: Node3D = DomeWorld.load_glb("dome_shell.glb")
        if shell_glb != null:
                var c := WorldTheme.rect_center_world(rect)
                shell_glb.position = Vector3(c.x, 0.0, c.z)
                add_child(shell_glb)
                _shell = shell_glb

func set_daylight(v: float) -> void:
        if _fence_material != null:
                _fence_material.set_shader_parameter("daylight", v)

func resync_pathing() -> void:
        pathing.resync()

func center_world() -> Vector3:
        return WorldTheme.rect_center_world(rect)
