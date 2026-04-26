extends Node

signal phase_changed(phase: String, turn: int)
signal battle_started(initial_player_cell: int)
signal player_action_requested(turn: int)
signal action_committed(turn: int, action_id: String)
signal action_resolved(turn: int, action_id: String, result: Dictionary)
signal turn_ended(turn: int)

var turn: int = 0
var phase: String = "idle"
var initial_player_cell: int = 2

func start() -> void:
	battle_started.emit(initial_player_cell)
	turn = 1
	_set_phase("player")
	player_action_requested.emit(turn)

func stop() -> void:
	turn = 0
	_set_phase("idle")

func submit_player_action(action_id: String) -> bool:
	if phase != "player":
		return false
	if action_id.is_empty():
		return false
	_set_phase("resolve")
	action_committed.emit(turn, action_id)
	return true

func notify_action_resolved(action_id: String, result: Dictionary, continue_turns: bool = true) -> void:
	if phase != "resolve":
		return
	action_resolved.emit(turn, action_id, result)
	_set_phase("end")
	turn_ended.emit(turn)
	if not continue_turns:
		_set_phase("idle")
		return
	turn += 1
	_set_phase("player")
	player_action_requested.emit(turn)

func _set_phase(p: String) -> void:
	phase = p
	phase_changed.emit(phase, turn)
