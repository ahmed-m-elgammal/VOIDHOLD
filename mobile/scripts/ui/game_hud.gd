extends CanvasLayer

# Epic 2 HUD: resource bar, build bar (18 canonical kinds), placement
# controls (rotate/confirm/cancel + demolish), debug overlay (day/night +
# solar acceptance hook), and toast wiring. Built in code like toasts.gd.

var world: PlanetWorld = null
var placement: PlacementSystem = null

var _res_labels: Dictionary = {}
var _dome_label: Label = null
var _day_label: Label = null
var _debug_label: Label = null
var _build_buttons: Dictionary = {}
var _place_box: HBoxContainer = null
var _demolish_btn: Button = null
var _debug_on: bool = true

const RES_ORDER: Array = ["stone", "alloy", "biomass", "ore", "stim"]

func _ready() -> void:
        world = get_node_or_null("../WorldRoot")
        if world != null:
                placement = world.placement
        _build_ui()
        if placement != null:
                placement.placement_changed.connect(_on_placement_changed)
                placement.ghost_validated.connect(_on_ghost_validated)
                placement.place_requested.connect(_on_place_requested)

func _icon(kind: String) -> Texture2D:
        var p := "res://assets/ui/icons/buildings/" + kind + "_48.png"
        if ResourceLoader.exists(p) == false:
                return null
        return load(p)

func _res_icon(res: String) -> Texture2D:
        var p := "res://assets/ui/icons/resources/" + res + "_48.png"
        if ResourceLoader.exists(p) == false:
                return null
        return load(p)

func _mklabel(text: String, size: int) -> Label:
        var l := Label.new()
        l.text = text
        l.add_theme_font_size_override("font_size", size)
        return l

func _build_ui() -> void:
        var root := Control.new()
        root.name = "HUDRoot"
        root.set_anchors_preset(Control.PRESET_FULL_RECT)
        root.mouse_filter = Control.MOUSE_FILTER_IGNORE
        add_child(root)

        # Top-left: resources + day + dome.
        var top := HBoxContainer.new()
        top.name = "TopBar"
        top.set_anchors_preset(Control.PRESET_TOP_WIDE)
        top.offset_left = 12.0
        top.offset_top = 8.0
        top.offset_right = -12.0
        top.add_theme_constant_override("separation", 14)
        top.mouse_filter = Control.MOUSE_FILTER_IGNORE
        root.add_child(top)
        for res in RES_ORDER:
                var chip := HBoxContainer.new()
                chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
                var icon := TextureRect.new()
                var tex: Texture2D = _res_icon(res)
                if tex != null:
                        icon.texture = tex
                icon.custom_minimum_size = Vector2(26, 26)
                icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
                icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
                chip.add_child(icon)
                var lbl := _mklabel("0", 18)
                chip.add_child(lbl)
                _res_labels[res] = lbl
                top.add_child(chip)
        var spacer := Control.new()
        spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
        top.add_child(spacer)
        _day_label = _mklabel("day", 18)
        top.add_child(_day_label)
        _dome_label = _mklabel("Dome 1", 18)
        top.add_child(_dome_label)

        # Top-right: debug overlay (T2.1 acceptance: light + solar value).
        _debug_label = _mklabel("", 14)
        _debug_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
        _debug_label.position = Vector2(-360.0, 40.0)
        _debug_label.size = Vector2(350, 200)
        _debug_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
        root.add_child(_debug_label)

        # Bottom: build bar. Portrait phones cannot fit 18 buttons in one
        # row, so the bar is a fixed-height horizontally scrollable strip
        # (drag/swipe on touch); in landscape it usually fits without
        # scrolling. Vertical scroll is disabled to keep the bar compact.
        var bar := PanelContainer.new()
        bar.name = "BuildBar"
        bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
        bar.offset_left = 4.0
        bar.offset_right = -4.0
        bar.offset_top = -92.0
        bar.offset_bottom = -8.0
        root.add_child(bar)
        var scroll := ScrollContainer.new()
        scroll.name = "BuildBarScroll"
        scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
        scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
        scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
        scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        bar.add_child(scroll)
        var row := HBoxContainer.new()
        row.name = "BuildBarRow"
        row.size_flags_vertical = Control.SIZE_FILL
        row.add_theme_constant_override("separation", 8)
        scroll.add_child(row)
        var defs: Dictionary = DomeSim.new().defs
        if defs.is_empty():
                defs = DomeSim.load_json("res://data/buildings.json")
        for kind in defs.keys():
                var def: Dictionary = defs[kind]
                var btn := Button.new()
                btn.custom_minimum_size = Vector2(64, 64)
                btn.tooltip_text = String(def.get("display", kind))
                btn.name = "bb_" + String(kind)
                var icon_tex: Texture2D = _icon(String(kind))
                if icon_tex != null:
                        btn.icon = icon_tex
                        btn.expand_icon = true
                else:
                        btn.text = String(def.get("display", kind))
                btn.pressed.connect(_on_build_pressed.bind(String(kind)))
                row.add_child(btn)
                _build_buttons[String(kind)] = btn

        # Placement controls (center-bottom, above build bar).
        _place_box = HBoxContainer.new()
        _place_box.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
        _place_box.offset_top = -160.0
        _place_box.offset_bottom = -100.0
        _place_box.offset_left = -150.0
        _place_box.offset_right = 150.0
        _place_box.add_theme_constant_override("separation", 10)
        _place_box.visible = false
        root.add_child(_place_box)
        var rotate_btn := Button.new()
        rotate_btn.text = tr("action_rotate")
        rotate_btn.custom_minimum_size = Vector2(90, 48)
        rotate_btn.pressed.connect(func() -> void: placement.rotate_ghost())
        _place_box.add_child(rotate_btn)
        var confirm_btn := Button.new()
        confirm_btn.text = tr("action_place")
        confirm_btn.custom_minimum_size = Vector2(90, 48)
        confirm_btn.pressed.connect(func() -> void: placement._try_confirm())
        _place_box.add_child(confirm_btn)
        var cancel_btn := Button.new()
        cancel_btn.text = tr("action_cancel")
        cancel_btn.custom_minimum_size = Vector2(90, 48)
        cancel_btn.pressed.connect(func() -> void: placement.cancel())
        _place_box.add_child(cancel_btn)
        _demolish_btn = Button.new()
        _demolish_btn.text = tr("action_demolish")
        _demolish_btn.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
        _demolish_btn.offset_top = -170.0
        _demolish_btn.offset_bottom = -126.0
        _demolish_btn.offset_left = -60.0
        _demolish_btn.offset_right = 60.0
        _demolish_btn.visible = false
        _demolish_btn.pressed.connect(_on_demolish)
        root.add_child(_demolish_btn)

func _on_build_pressed(kind: String) -> void:
        if placement == null:
                return
        placement.start_placement(kind)
        _highlight_build_bar(kind)

func _highlight_build_bar(kind: String) -> void:
        for k in _build_buttons:
                var b: Button = _build_buttons[k]
                b.modulate = Color(1.35, 1.35, 1.1) if k == kind else Color(1, 1, 1)

func _on_placement_changed(active: bool, _kind: String) -> void:
        _place_box.visible = active
        if active == false:
                _highlight_build_bar("")
                _demolish_btn.visible = world != null and world.selected_guid != 0

func _on_ghost_validated(_ok: bool, _reason: String) -> void:
        pass  # toasts are emitted by PlanetWorld to avoid double feeds

func _on_place_requested(_kind: String, _cell: Vector2i, _rot: int, _master: int) -> void:
        _highlight_build_bar("")

func _on_demolish() -> void:
        if world == null:
                return
        if world.selected_guid == 0:
                return
        world.demolish_selected(world.selected_guid)
        _demolish_btn.visible = false

func _process(_delta: float) -> void:
        if world == null:
                return
        var totals: Dictionary = world.current_totals()
        for res in _res_labels:
                var v: float = float(totals.get(res, 0.0))
                (_res_labels[res] as Label).text = str(int(v))
        _day_label.text = tr("hud_day") if world.day_night.daylight >= 0.5 else tr("hud_night")
        _dome_label.text = "Dome " + str(world.current_dome_index + 1)
        _demolish_btn.visible = world.selected_guid != 0 and placement.active == false
        if _debug_on:
                var lines: Array = world.debug_lines()
                lines.append("fps=%d" % Engine.get_frames_per_second())
                _debug_label.text = "\n".join(PackedStringArray(lines))
        else:
                _debug_label.text = ""
