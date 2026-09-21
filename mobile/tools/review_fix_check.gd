extends SceneTree

# Review-fix verification (post-review smoke for the greybox milestone). Run:
#   godot --headless --path mobile -s tools/review_fix_check.gd
# Proves at runtime that (1) the fence shader has strand_tex/pulse_tex bound,
# (2) the build bar is a ScrollContainer strip, (3) the sky is a crossfade
# ShaderMaterial whose blend follows daylight.

var failures: Array = []
var checks: int = 0

func check(name: String, cond: bool) -> void:
        checks += 1
        if cond == false:
                failures.append(name)
                print("FAIL: " + name)

func _init() -> void:
        var packed: Variant = load("res://scenes/world/Planet3D.tscn")
        check("scene loads", packed != null)
        if packed == null:
                quit(1)
                return
        var scene: Node = (packed as PackedScene).instantiate()
        root.add_child(scene)
        await process_frame
        await process_frame
        var world: PlanetWorld = scene.get_node("WorldRoot")
        var manager: DomeManager = world.manager
        # --- 1. fence textures bound on every DomeWorld ---
        for w in manager.worlds:
                var dw: DomeWorld = w
                var mi: MeshInstance3D = dw._segments[0]
                var mat: ShaderMaterial = mi.material_override
                check("fence material is fence shader", mat != null and mat.shader.resource_path.ends_with("fence_ring.gdshader"))
                check("fence strand_tex bound", mat.get_shader_parameter("strand_tex") != null)
                check("fence pulse_tex bound", mat.get_shader_parameter("pulse_tex") != null)
        # --- 2. HUD build bar scrolls instead of one fixed row ---
        var hud: CanvasLayer = scene.get_node("HUD")
        var bar: PanelContainer = hud.get_node("HUDRoot/BuildBar")
        check("build bar is PanelContainer", bar != null)
        var scroll: ScrollContainer = bar.get_node("BuildBarScroll")
        check("build bar scrolls horizontally", scroll != null and scroll.horizontal_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED)
        check("build bar vertical scroll disabled", scroll != null and scroll.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED)
        var row: HBoxContainer = scroll.get_node("BuildBarRow")
        check("build bar row has 18 buttons", row.get_child_count() == 18)
        # Portrait smoke: the row min width may exceed a narrow viewport but
        # must stay inside the scrollable strip, not the fixed bar.
        check("row content wider than one portrait row is scrollable", row.get_combined_minimum_size().x > 540.0 and scroll.get_h_scroll_bar() != null)
        # --- 3. sky crossfade follows daylight continuously ---
        var env_node: WorldEnvironment = scene.get_node("WorldEnvironment")
        var sky_mat: Material = env_node.environment.sky.sky_material
        check("sky is crossfade shader", sky_mat is ShaderMaterial and (sky_mat as ShaderMaterial).shader.resource_path.ends_with("sky_crossfade.gdshader"))
        var dn: DayNight = world.day_night
        dn.t = 0.75
        dn._process(0.016)
        var night_blend: float = float((sky_mat as ShaderMaterial).get_shader_parameter("blend"))
        check("midnight blend near 0", night_blend < 0.15)
        dn.t = 0.25
        dn._process(0.016)
        var noon_blend: float = float((sky_mat as ShaderMaterial).get_shader_parameter("blend"))
        check("noon blend near 1", noon_blend > 0.85)
        # Mid-fade: t where the daylight curve sits mid-range (~0.4).
        dn.t = 0.033
        dn._process(0.016)
        var mid_blend: float = float((sky_mat as ShaderMaterial).get_shader_parameter("blend"))
        check("mid-fade blend between (true fade)", mid_blend > night_blend + 0.15 and mid_blend < noon_blend - 0.15)
        check("no hard panorama swap flag", dn._sky_mat == null)
        var failed: int = failures.size()
        print("RESULT: " + str(checks - failed) + "/" + str(checks) + " review-fix checks passed")
        if failed > 0:
                for f in failures:
                        print("  failed: " + f)
        scene.queue_free()
        quit(0 if failed == 0 else 1)
