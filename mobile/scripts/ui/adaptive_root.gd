extends CanvasLayer
signal layout_changed(layout)
enum Layout { LANDSCAPE, PORTRAIT }
var _layout: int = Layout.LANDSCAPE
func _ready() -> void:
	_layout = current_layout(get_viewport().get_visible_rect().size)
	get_viewport().size_changed.connect(_on_size_changed)
func current_layout(viewport_size: Vector2) -> int:
	if viewport_size.x >= viewport_size.y:
		return Layout.LANDSCAPE
	return Layout.PORTRAIT
func get_layout() -> int:
	return _layout
func _on_size_changed() -> void:
	var next: int = current_layout(get_viewport().get_visible_rect().size)
	if next != _layout:
		_layout = next
		layout_changed.emit(_layout)
