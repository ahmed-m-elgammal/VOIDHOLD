class_name Rng
extends RefCounted

var _s0: int = 1
var _s1: int = 2
var _pos: int = 0

func _init(seed_value: int = 1) -> void:
	seed(seed_value)

func seed(seed_value: int) -> void:
	var z: int = seed_value
	if z == 0:
		z = 1
	_s0 = _splitmix(z)
	_s1 = _splitmix(_s0 ^ z)
	if _s0 == 0 and _s1 == 0:
		_s0 = 1
		_s1 = 2
	_pos = 0

static func _lshr(v: int, n: int) -> int:
	if n <= 0:
		return v
	if n >= 64:
		return 0
	if v >= 0:
		return v >> n
	var shifted: int = v >> n
	var keep: int = 64 - n
	var mask: int = 0
	if keep >= 63:
		mask = 9223372036854775807
	else:
		mask = (1 << keep) - 1
	return shifted & mask

static func _splitmix(x: int) -> int:
	var z: int = x + -7046029254386353131
	z = (z ^ _lshr(z, 30)) * -4658895280553007687
	z = (z ^ _lshr(z, 27)) * -7723592293110705685
	return z ^ _lshr(z, 31)

func _raw() -> int:
	var s1: int = _s0
	var s0: int = _s1
	var result: int = s0 + s1
	_s0 = s0
	s1 = s1 ^ (s1 << 23)
	_s1 = s1 ^ s0 ^ _lshr(s1, 18) ^ _lshr(s0, 5)
	_pos += 1
	return result

func next_int() -> int:
	return _raw() & 2147483647

func next_float() -> float:
	return float(next_int()) / 2147483648.0

func pick(arr: Array) -> Variant:
	if arr.is_empty():
		return null
	var idx: int = next_int() % arr.size()
	return arr[idx]

static func less_than(dist_a: float, guid_a: int, dist_b: float, guid_b: int) -> bool:
	if dist_a < dist_b:
		return true
	if dist_a > dist_b:
		return false
	return guid_a < guid_b

func save_state() -> Dictionary:
	return {"s0": _s0, "s1": _s1, "pos": _pos}

func load_state(d: Dictionary) -> void:
	_s0 = int(d.get("s0", 1))
	_s1 = int(d.get("s1", 2))
	_pos = int(d.get("pos", 0))
	if _s0 == 0 and _s1 == 0:
		_s0 = 1
		_s1 = 2
