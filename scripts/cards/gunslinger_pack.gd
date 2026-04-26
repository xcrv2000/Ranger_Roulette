extends RefCounted

static func get_effect_for(card_id: String) -> Dictionary:
	match card_id:
		"gunslinger_01":
			return {
				"tags": [],
				"is_attack": true,
				"actions": [
					{"type": "move", "delta": 1},
					{"type": "deal_damage", "amount_by_cell": [{"min": 1, "max": 3, "amount": 9}, {"min": 4, "max": 6, "amount": 13}, {"min": 7, "max": 7, "amount": 17}]},
				],
			}
		"gunslinger_02":
			return {"tags": [], "is_attack": true, "actions": [{"type": "move", "delta": 2}, {"type": "deal_damage", "amount": 9}]}
		"gunslinger_03":
			return {"tags": [], "is_attack": true, "actions": [{"type": "move", "delta": 1}, {"type": "deal_damage", "amount": 6, "hits": 2}]}
		"gunslinger_04":
			return {
				"tags": [],
				"is_attack": true,
				"actions": [{"type": "deal_damage", "amount": 12, "amount_if_first_attack": 36}],
				"constraints": {"wheel": "last"},
			}
		"gunslinger_05":
			return {
				"tags": [],
				"is_attack": true,
				"actions": [{"type": "deal_damage", "amount_expr": "player_block", "mult_if_first_attack": 2}],
			}
		"gunslinger_06":
			return {"tags": [], "is_attack": true, "actions": [{"type": "wander", "steps": 2}, {"type": "deal_damage", "amount": 9}, {"type": "wander", "steps": 1}]}
		"gunslinger_07":
			return {
				"tags": [],
				"is_attack": true,
				"actions": [{"type": "wander", "steps": 1}, {"type": "self_damage", "amount": 3}, {"type": "deal_damage", "amount": 13}, {"type": "deal_damage_front_cells", "amount": 5, "cells": 3}],
			}
		"gunslinger_08":
			return {
				"tags": [],
				"is_attack": true,
				"actions": [{"type": "wander", "steps": 1}, {"type": "self_damage", "amount": 3}, {"type": "deal_damage", "amount": 9}, {"type": "schedule", "turns": 1, "actions": [{"type": "deal_damage", "amount": 9}]}],
			}
		"gunslinger_09":
			return {
				"tags": [],
				"is_attack": true,
				"actions": [{"type": "wander", "steps": 1}, {"type": "self_damage", "amount": 3}, {"type": "deal_damage", "amount": 4, "hits": 3, "target": "random"}],
			}
		"gunslinger_10":
			return {
				"tags": [],
				"is_attack": true,
				"actions": [{"type": "wander", "steps": 1}, {"type": "self_damage", "amount": 3}, {"type": "deal_damage", "amount_expr": "current_wheel_available_count", "mult": 2}],
			}
		"gunslinger_11":
			return {"tags": [], "is_attack": false, "actions": [{"type": "wander", "steps": 1}, {"type": "self_damage", "amount": 3}, {"type": "fire_random_bullet", "scope": "current", "filter": "available", "times": 2, "unique": true, "exclude_current": true}]}
		"gunslinger_12":
			return {"tags": [], "is_attack": true, "actions": [{"type": "wander", "steps": 1}, {"type": "self_damage", "amount": 3}, {"type": "deal_damage", "amount": 9}, {"type": "fire_random_bullet", "scope": "current", "filter": "available", "times": 1, "unique": false, "exclude_current": true}]}
		"gunslinger_13":
			return {"tags": [], "is_attack": false, "actions": [{"type": "wander", "steps": 1}, {"type": "self_damage", "amount": 3}, {"type": "fire_random_bullet", "scope": "each_other", "filter": "available", "times": 1, "unique": false, "exclude_current": false}]}
		"gunslinger_14":
			return {"tags": ["消耗"], "is_attack": false, "actions": [{"type": "wander", "steps": 1}, {"type": "self_damage", "amount": 3}, {"type": "fire_random_bullet", "scope": "any", "filter": "consumed", "times": 1, "unique": false, "exclude_current": false}]}
		"gunslinger_15":
			return {"tags": [], "is_attack": true, "actions": [{"type": "move", "delta": 1}, {"type": "deal_damage", "amount": 17, "target": "all"}]}
		"gunslinger_16":
			return {"tags": ["消耗"], "is_attack": true, "actions": [{"type": "move", "delta": 1}, {"type": "deal_damage", "amount": 17}]}
		"gunslinger_17":
			return {
				"tags": [],
				"is_attack": true,
				"actions": [{"type": "move", "delta": 1}, {"type": "deal_damage", "amount": 7}],
				"barrage": {"when": "any_enemy_dead", "actions": [{"type": "repeat_self", "times": 1}]},
			}
		"gunslinger_18":
			return {"tags": [], "is_attack": true, "actions": [{"type": "deal_damage", "amount": 10}, {"type": "gain_block", "amount": 5}]}
		"gunslinger_19":
			return {"tags": ["消耗"], "is_attack": false, "actions": [{"type": "apply_status", "target": "player", "status_id": "move_forward_deal_damage", "stacks": 4}]}
		"gunslinger_20":
			return {"tags": [], "is_attack": true, "actions": [{"type": "move", "delta": 3}, {"type": "deal_damage", "amount_expr": "forward_distance_this_turn", "mult": 3}]}
		"gunslinger_21":
			return {"tags": [], "is_attack": false, "actions": [{"type": "apply_status", "target": "player", "status_id": "heroic_charge", "stacks": 3}]}
		"gunslinger_22":
			return {"tags": [], "is_attack": true, "actions": [{"type": "move", "delta": 1}, {"type": "deal_damage", "amount": 3, "hits": 3, "on_hit_gain_block": 6}]}
		"gunslinger_23":
			return {"tags": [], "is_attack": false, "actions": [{"type": "move", "delta": 1}, {"type": "gain_block", "amount": 8}], "barrage": {"when": "any_enemy_dead", "actions": [{"type": "gain_gold", "amount": 6}]}}
		"gunslinger_24":
			return {
				"tags": [],
				"is_attack": false,
				"actions": [{"type": "move", "delta": -1}, {"type": "gain_block", "amount": 8}],
				"barrage": {"when": "any_enemy_dead", "post_victory": [{"type": "extra_reward_group", "count": 3}]},
			}
		"gunslinger_25":
			return {
				"tags": [],
				"is_attack": false,
				"actions": [{"type": "move", "delta": -1}, {"type": "gain_block", "amount": 8}],
				"barrage": {"when": "any_enemy_dead", "post_victory": [{"type": "reflection_remove_bullet"}]},
			}
		"gunslinger_26":
			return {
				"tags": [],
				"is_attack": false,
				"actions": [{"type": "move", "delta": -1}, {"type": "gain_block", "amount": 12}],
				"barrage": {"when": "any_enemy_dead", "post_victory": [{"type": "next_battle_start_block", "amount": 16}]},
			}
		"gunslinger_27":
			return {"tags": [], "is_attack": false, "actions": [{"type": "move", "delta": -1}, {"type": "gain_block", "amount": 8}]}
		"gunslinger_28":
			return {"tags": [], "is_attack": false, "actions": [{"type": "gain_block", "amount": 8}, {"type": "conditional_move_by_cell", "min": 1, "max": 3, "then_delta": 3, "else_delta": -3}]}
		"gunslinger_29":
			return {"tags": [], "is_attack": false, "actions": [{"type": "move_to_cell", "cell": 1}, {"type": "self_damage", "amount": 3}, {"type": "gain_block", "amount": 20}]}
		"gunslinger_30":
			return {"tags": [], "is_attack": false, "actions": [{"type": "move", "delta": -1}, {"type": "gain_block", "amount": 11}, {"type": "apply_status", "target": "player", "status_id": "next_time_take_damage_reflect", "stacks": 1}]}
		"gunslinger_31":
			return {"tags": [], "is_attack": false, "actions": [{"type": "wander", "steps": 1}, {"type": "gain_block", "amount": 8}]}
		"gunslinger_32":
			return {"tags": ["消耗"], "is_attack": false, "actions": [{"type": "gain_block", "amount": 13}]}
		"gunslinger_33":
			return {"tags": [], "is_attack": false, "actions": [{"type": "gain_block", "amount": 7}, {"type": "apply_status", "target": "player", "status_id": "next_attack_double", "stacks": 1}]}
		"gunslinger_34":
			return {"tags": [], "is_attack": false, "actions": [{"type": "apply_status", "target": "enemy", "status_id": "enemy_attack_halved_this_turn", "stacks": 1}]}
		"gunslinger_35":
			return {"tags": [], "is_attack": false, "actions": [{"type": "move", "delta": -1}, {"type": "gain_block", "amount": 8}, {"type": "apply_status", "target": "player", "status_id": "next_turn_gain_block", "stacks": 6}]}
		"gunslinger_36":
			return {"tags": ["消耗"], "is_attack": false, "actions": [{"type": "apply_status", "target": "player", "status_id": "next_enemy_hit_zero", "stacks": 1}, {"type": "set_hat_lost"}]}
		"gunslinger_37":
			return {"tags": ["消耗"], "is_attack": false, "actions": [{"type": "apply_status", "target": "player", "status_id": "move_backward_gain_block", "stacks": 3}]}
		_:
			return {}

static func get_timeline_seconds_for(_card_id: String) -> float:
	return 0.0
