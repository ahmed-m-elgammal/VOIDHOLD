extends Control
signal build_selected(type_id)
var locked: Dictionary = {}
var selected_id: String = ""
func is_locked(type_id: String) -> bool:
	return bool(locked.get(type_id, false))
func set_locked(type_id: String, value: bool) -> void:
	locked[type_id] = value
func set_locked_all(items: Dictionary) -> void:
	locked = items.duplicate()
func select(type_id: String) -> bool:
	if is_locked(type_id):
		return false
	selected_id = type_id
	build_selected.emit(type_id)
	return true
func clear_selection() -> void:
	selected_id = ""
