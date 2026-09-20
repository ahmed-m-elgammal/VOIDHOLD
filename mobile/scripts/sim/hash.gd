class_name StateHash
extends RefCounted

static func fnv1a(d: Dictionary) -> String:
	var h: int = _feed_value(d, 2166136261)
	return "%08x" % (h & 4294967295)

static func _feed_str(s: String, h: int) -> int:
	var bytes: PackedByteArray = s.to_utf8_buffer()
	for b in bytes:
		h = h ^ int(b)
		h = (h * 16777619) & 4294967295
	return h

static func _feed_value(v: Variant, h: int) -> int:
	var kind: int = typeof(v)
	if kind == TYPE_INT or kind == TYPE_FLOAT:
		var number: float = float(v)
		if is_equal_approx(number, round(number)):
			return _feed_str("number:" + str(int(round(number))) + ";", h)
		return _feed_str("number:" + str(number) + ";", h)
	h = _feed_str("type:" + str(kind) + ";", h)
	if kind == TYPE_NIL:
		return h
	if kind == TYPE_BOOL:
		return _feed_str("true;" if v else "false;", h)
	if kind == TYPE_STRING or kind == TYPE_STRING_NAME:
		var text: String = str(v)
		return _feed_str(str(text.length()) + ":" + text, h)
	if kind == TYPE_ARRAY:
		var arr: Array = v
		h = _feed_str("array:" + str(arr.size()) + "[", h)
		for e in arr:
			h = _feed_value(e, h)
		return _feed_str("]", h)
	if kind == TYPE_DICTIONARY:
		var dd: Dictionary = v
		var kk: Array = dd.keys()
		kk.sort()
		h = _feed_str("dict:" + str(kk.size()) + "{", h)
		for k in kk:
			h = _feed_value(k, h)
			h = _feed_value(dd[k], h)
		return _feed_str("}", h)
	if kind == TYPE_PACKED_BYTE_ARRAY:
		var pb: PackedByteArray = v
		h = _feed_str("bytes:" + str(pb.size()) + "[", h)
		for b in pb:
			h = h ^ int(b)
			h = (h * 16777619) & 4294967295
		return _feed_str("]", h)
	if kind == TYPE_PACKED_INT32_ARRAY or kind == TYPE_PACKED_INT64_ARRAY:
		h = _feed_str("packed_int:" + str(v.size()) + "[", h)
		for e in v:
			h = _feed_value(e, h)
		return _feed_str("]", h)
	if kind == TYPE_PACKED_FLOAT32_ARRAY or kind == TYPE_PACKED_FLOAT64_ARRAY:
		h = _feed_str("packed_float:" + str(v.size()) + "[", h)
		for e in v:
			h = _feed_value(e, h)
		return _feed_str("]", h)
	if kind == TYPE_VECTOR2 or kind == TYPE_VECTOR2I:
		return _feed_str(str(v), h)
	if kind == TYPE_VECTOR3 or kind == TYPE_VECTOR3I:
		return _feed_str(str(v), h)
	if kind == TYPE_VECTOR4 or kind == TYPE_VECTOR4I:
		return _feed_str(str(v), h)
	if kind == TYPE_COLOR:
		return _feed_str(str(v), h)
	return _feed_str(str(v), h)
