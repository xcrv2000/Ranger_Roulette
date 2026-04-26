extends Node

signal intent_declared(intent: Dictionary)

var name_text: String = "dummy"
var action_duration_seconds: float = 1.2

var _rng := RandomNumberGenerator.new()
var _current_intent: Dictionary = {}

func roll_intent() -> Dictionary:
	var r := _rng.randi_range(0, 2)
	var intent: Dictionary
	if r == 0:
		intent = {
			"id": "dmg_4567_20",
			"name": "扫射右侧",
			"text": "对第4/5/6/7格造成20伤害",
			"damage": 20,
			"cells": PackedInt32Array([4, 5, 6, 7]),
			"duration_seconds": action_duration_seconds,
		}
	elif r == 1:
		intent = {
			"id": "dmg_all_10",
			"name": "全屏扫射",
			"text": "对所有格造成10伤害",
			"damage": 10,
			"cells": PackedInt32Array([1, 2, 3, 4, 5, 6, 7]),
			"duration_seconds": action_duration_seconds,
		}
	else:
		intent = {
			"id": "noop",
			"name": "观望",
			"text": "什么都不做",
			"damage": 0,
			"cells": PackedInt32Array(),
			"duration_seconds": action_duration_seconds,
		}
	_current_intent = intent
	intent_declared.emit(intent)
	return intent

func get_current_intent() -> Dictionary:
	return _current_intent

func get_name_text() -> String:
	return name_text
