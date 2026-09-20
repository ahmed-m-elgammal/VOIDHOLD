class_name SaveSchema
extends RefCounted

const SAVE_VERSION := 1

static func default_save() -> Dictionary:
	return {
		"save_version": SAVE_VERSION,
		"game_version": "0.1.0",
		"content_version": 1,
		"playtime": 0.0,
		"playtime_s": 0.0,
		"rng_state": {"s0": 0, "s1": 0, "pos": 0},
		"last_seen_utc": 0,
		"camera": {
			"topleft": [0, 0],
			"zoom": 1.0,
			"rotation": 0.0
		},
		"planet": {
			"seed": 0,
			"moon_id": "beginner",
			"map_version": 1
		},
		"domes": [],
		"entitlements": {},
		"settings": {
			"locale": "en",
			"music": true,
			"sfx": true
		},
		"stats": {},
		"tutorial_flags": {}
	}
