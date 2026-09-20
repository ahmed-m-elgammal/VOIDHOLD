class_name TimeManager
extends Node

const OFFLINE_CAP := 14400

var speed: int = 1
var paused: bool = false
var last_seen_utc: int = 0

func set_speed(value: int) -> void:
	if value == 1 or value == 2 or value == 3:
		speed = value

func set_paused(value: bool) -> void:
	paused = value

func effective_speed() -> int:
	if paused:
		return 0
	return speed

func offline_seconds(now: int, last: int) -> int:
	var delta = now - last
	if delta < 0:
		delta = 0
	return mini(delta, OFFLINE_CAP)
