extends Node

signal intent_declared(intent: Dictionary)

var name_text: String = "dummy boss"
var action_duration_seconds: float = 1.2

var _rng := RandomNumberGenerator.new()
var _current_intent: Dictionary = {}

func roll_intent(context: Dictionary = {}) -> Dictionary:
	var player_cell := int(context.get("player_cell", 1))
	var lane_length := int(context.get("lane_length", 7))

	var r := _rng.randi_range(0, 2)
	var intent: Dictionary
	if r == 0:
		intent = {
			"id": "boss_dmg_cell_50",
			"name": "锁定射击",
			"text": "对玩家回合开始所在格造成50点伤害",
			"damage": 50,
			"cells": PackedInt32Array([player_cell]),
			"duration_seconds": action_duration_seconds,
		}
	elif r == 1:
		var cells := PackedInt32Array()
		for c in [player_cell - 1, player_cell, player_cell + 1]:
			if c >= 1 and c <= lane_length:
				cells.append(c)
		intent = {
			"id": "boss_dmg_adj_30",
			"name": "扩散射击",
			"text": "对玩家回合开始所在格及相邻格造成30点伤害",
			"damage": 30,
			"cells": cells,
			"duration_seconds": action_duration_seconds,
		}
	else:
		var cells := PackedInt32Array()
		for c in range(1, lane_length + 1):
			cells.append(c)
		intent = {
			"id": "boss_dmg_all_20",
			"name": "全屏压制",
			"text": "对所有格造成20点伤害",
			"damage": 20,
			"cells": cells,
			"duration_seconds": action_duration_seconds,
		}
	_current_intent = intent
	intent_declared.emit(intent)
	return intent

func get_current_intent() -> Dictionary:
	return _current_intent

func get_name_text() -> String:
	return name_text
