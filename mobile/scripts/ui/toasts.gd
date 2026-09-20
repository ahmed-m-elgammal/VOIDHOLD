extends CanvasLayer
const MAX_TOASTS: int = 3
var _pool: Array[Label] = []
var _queue: Array[Dictionary] = []
var _box: VBoxContainer
func _ready() -> void:
	_box = VBoxContainer.new()
	_box.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_box.alignment = BoxContainer.ALIGNMENT_END
	add_child(_box)
	for i in MAX_TOASTS:
		var label: Label = Label.new()
		label.visible = false
		_box.add_child(label)
		_pool.append(label)
func show_toast(text: String, kind: String = "info") -> void:
	_queue.append({"text": text, "kind": kind})
	if _queue.size() > MAX_TOASTS:
		_queue.pop_front()
	_refresh()
func _refresh() -> void:
	for i in _pool.size():
		if i < _queue.size():
			_pool[i].text = str(_queue[i]["text"])
			_pool[i].modulate = _color_for(str(_queue[i]["kind"]))
			_pool[i].visible = true
		else:
			_pool[i].visible = false
func _color_for(kind: String) -> Color:
	if kind == "error":
		return Color(1.0, 0.35, 0.35)
	if kind == "warning":
		return Color(1.0, 0.85, 0.4)
	return Color(1, 1, 1)
func clear() -> void:
	_queue.clear()
	_refresh()
