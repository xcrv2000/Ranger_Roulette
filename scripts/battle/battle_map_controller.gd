extends Node

signal configured(lane_length: int, enemy_outside_index: int)
signal player_spawned(cell: int)
signal player_moved(from_cell: int, to_cell: int, delta: int, reason: String)
signal player_move_blocked(from_cell: int, delta: int, reason: String)
signal player_out_of_bounds_attempt(direction: String, from_cell: int, attempted_to_cell: int, clamped_to_cell: int, delta: int)
signal enemy_spawned(enemy_id: int, cell: int)
signal enemy_moved(enemy_id: int, from_cell: int, to_cell: int, reason: String)

var lane_length: int = 7
var enemy_outside_index: int = 8

var player_cell: int = 1
var enemies: Dictionary = {}

func setup(p_lane_length: int = 7) -> void:
	lane_length = max(1, p_lane_length)
	enemy_outside_index = lane_length + 1
	player_cell = 1
	enemies.clear()
	configured.emit(lane_length, enemy_outside_index)

func spawn_player(cell: int = 1) -> int:
	player_cell = clampi(cell, 1, lane_length)
	player_spawned.emit(player_cell)
	return player_cell

func spawn_enemy(enemy_id: int, cell: int) -> int:
	var final_cell := _clamp_enemy_cell(cell)
	enemies[enemy_id] = final_cell
	enemy_spawned.emit(enemy_id, final_cell)
	return final_cell

func request_move_player(delta: int) -> Dictionary:
	var from := player_cell
	var attempted_to := from + delta
	var clamped_to := clampi(attempted_to, 1, lane_length)
	var out_of_bounds := attempted_to < 1 or attempted_to > lane_length
	var direction := ""
	var reason := "ok"
	var applied_delta := clamped_to - from

	if out_of_bounds:
		direction = "left" if attempted_to < 1 else "right"
		reason = "clamped_%s" % direction
		player_out_of_bounds_attempt.emit(direction, from, attempted_to, clamped_to, delta)
		if clamped_to == from:
			player_move_blocked.emit(from, delta, "%s_edge" % direction)

	player_cell = clamped_to
	if clamped_to != from:
		player_moved.emit(from, clamped_to, delta, reason)
	return {"applied": clamped_to != from, "from": from, "to": clamped_to, "attempted_to": attempted_to, "delta": delta, "delta_applied": applied_delta, "reason": reason, "out_of_bounds_attempt": out_of_bounds, "direction": direction}

func request_move_enemy(enemy_id: int, delta: int) -> Dictionary:
	if not enemies.has(enemy_id):
		return {"applied": false, "reason": "enemy_not_found"}

	var from: int = int(enemies[enemy_id])
	var to := _clamp_enemy_cell(from + delta)
	if to == from:
		return {"applied": false, "from": from, "to": to, "reason": "blocked"}
	enemies[enemy_id] = to
	enemy_moved.emit(enemy_id, from, to, "ok")
	return {"applied": true, "from": from, "to": to, "reason": "ok"}

func _clamp_enemy_cell(cell: int) -> int:
	if cell <= enemy_outside_index:
		return max(1, cell)
	return enemy_outside_index
