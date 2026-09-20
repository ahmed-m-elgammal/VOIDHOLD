extends Node
signal entitlement_changed(id)
signal purchase_started(id)
var _owned: Dictionary = {}
var shop_locked: bool = true
func has(id: String) -> bool:
	return bool(_owned.get(id, false))
func purchase_requested(id: String) -> void:
	purchase_started.emit(id)
func grant_mock(id: String) -> void:
	if OS.is_debug_build():
		_owned[id] = true
		entitlement_changed.emit(id)
func revoke_mock(id: String) -> void:
	if OS.is_debug_build():
		_owned.erase(id)
		entitlement_changed.emit(id)
func is_shop_locked() -> bool:
	return shop_locked
