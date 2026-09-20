extends Camera3D

# Orthographic 2.5D camera rig: wheel/pinch zoom, drag pan (mouse LMB or
# single touch), middle-mouse pan, planet bounds clamp, and focus() for the
# T2.4 elevator camera jump. Tap handling for placement lives in
# PlacementSystem; the rig ignores quick taps so both stay active at once.

@export var min_size: float = 24.0
@export var max_size: float = 90.0
@export var bounds_margin: float = 10.0

var _dragging: bool = false
var _drag_last: Vector2 = Vector2.ZERO
var _drag_moved: float = 0.0
var _pinch_dist: float = 0.0
var _pointers: Dictionary = {}
var _focus_tween: Tween = null
var _target := Vector3(105.0, 0.0, 105.0)

func _ready() -> void:
	projection = PROJECTION_ORTHOGONAL
	size = 48.0
	_target = _ground_point()

func _ground_point() -> Vector3:
	# World point the camera looks at (drop y).
	return Vector3(position.x, 0.0, position.z + size * 0.4)

func _clamp_target() -> void:
	var lim: float = float(WorldTheme.PLANET_SIZE) + bounds_margin
	_target.x = clampf(_target.x, -lim, lim)
	_target.z = clampf(_target.z, -lim, lim)
	position.x = _target.x
	position.z = _target.z + size * 0.4

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			size = clampf(size - 4.0, min_size, max_size)
			_clamp_target()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			size = clampf(size + 4.0, min_size, max_size)
			_clamp_target()
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_dragging = true
				_drag_last = mb.position
				_drag_moved = 0.0
			else:
				_dragging = false
		elif mb.button_index == MOUSE_BUTTON_MIDDLE:
			if mb.pressed:
				_dragging = true
				_drag_last = mb.position
				_drag_moved = 0.0
			else:
				_dragging = false
		return
	if event is InputEventMouseMotion and _dragging:
		var mm := event as InputEventMouseMotion
		var d: Vector2 = mm.position - _drag_last
		_drag_moved += d.length()
		_drag_last = mm.position
		var scale_factor: float = size / 720.0
		_target -= Vector3(d.x, 0.0, d.y) * scale_factor
		_clamp_target()
		return
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			_pointers[st.index] = st.position
		else:
			_pointers.erase(st.index)
			if st.index == 0:
				_dragging = false
		return
	if event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		if _pointers.size() == 1:
			var scale_factor2: float = size / 720.0
			_target -= Vector3(sd.relative.x, 0.0, sd.relative.y) * scale_factor2
			_clamp_target()
			_dragging = true
		elif _pointers.size() == 2:
			var idxs: Array = _pointers.keys()
			_pointers[sd.index] = sd.position
			if idxs.size() == 2:
				var a: Vector2 = _pointers.get(idxs[0], Vector2.ZERO)
				var b: Vector2 = _pointers.get(idxs[1], Vector2.ZERO)
				var dist: float = a.distance_to(b)
				if _pinch_dist > 0.0:
					var delta: float = _pinch_dist - dist
					size = clampf(size + delta * 0.14, min_size, max_size)
					_clamp_target()
				_pinch_dist = dist
		return

func snap_rotate_90() -> void:
	rotation.y += PI / 2.0

# T2.4 — camera jump + zoom-out to a world point. jump=true snaps instantly
# then eases the zoom; jump=false eases both.
func focus(world_point: Vector3, target_size: float, jump: bool) -> void:
	if _focus_tween != null and _focus_tween.is_valid():
		_focus_tween.kill()
	var goal := Vector3(world_point.x, 0.0, world_point.z)
	if jump:
		_target = goal
		position.x = _target.x
		position.z = _target.z + size * 0.4
		_focus_tween = create_tween()
		_focus_tween.tween_property(self, "size", clampf(target_size, min_size, max_size), 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	else:
		_focus_tween = create_tween().set_parallel(true)
		_focus_tween.tween_property(self, "size", clampf(target_size, min_size, max_size), 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_focus_tween.tween_method(func(v: Vector3) -> void:
			_target = v
			position.x = v.x
			position.z = v.z + size * 0.4, _target, goal, 0.5)
