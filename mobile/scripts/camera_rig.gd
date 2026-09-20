extends Camera3D

@export var min_size: float = 24.0
@export var max_size: float = 90.0

func _ready() -> void:
	projection = PROJECTION_ORTHOGONAL
	size = 48.0

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			size = clampf(size - 4.0, min_size, max_size)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			size = clampf(size + 4.0, min_size, max_size)

func snap_rotate_90() -> void:
	rotation.y += PI / 2.0
