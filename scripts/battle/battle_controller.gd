extends Node

signal battle_started(node: Dictionary, actions: Array[Dictionary])
signal battle_state_changed(state: Dictionary)
signal battle_log(text: String)
signal battle_finished_victory(result: Dictionary)
signal battle_finished_defeat(result: Dictionary)
signal roll_timeline_started(roll: Array)
signal wheel_highlight_changed(wheel_index: int)
signal skill_step_started(wheel_index: int, skill_id: String)
signal skill_step_finished(wheel_index: int, skill_id: String, result: Dictionary)

var active_node: Dictionary = {}

const _BATTLE_MAP_SCRIPT := preload("res://scripts/battle/battle_map_controller.gd")
const _TURN_FLOW_SCRIPT := preload("res://scripts/battle/turn_flow_controller.gd")
const _SLOT_MACHINE_SCRIPT := preload("res://scripts/battle/slot_machine_controller.gd")
const _ENEMY_DB_SCRIPT := preload("res://scripts/systems/enemy_database.gd")

const PRIMARY_ENEMY_ID := 0

var _battle_map: Node
var _turn_flow: Node
var _slot_machine: Node
var _card_db: CardDatabase
var _card_resolver: CardScriptResolver
var _enemy: Node
var _enemy_db: RefCounted
var _enemy_def: Dictionary = {}
var _enemy_id: String = "dummy"
var _enemy_instance_id: String = ""
var _run: RunContext
var _quick_mode_level: int = 0
var quick_wait_fast_seconds: float = 0.5
var quick_wait_extreme_seconds: float = 0.2
var _status_db: StatusDatabase
var _player_statuses: StatusContainer
var _enemy_statuses: StatusContainer

var _player_hp: int = 50
var _player_block: int = 0

var _enemy_hp: int = 50
var _enemy_intent: Dictionary = {}
var _is_resolving_enemy: bool = false
var post_player_delay_seconds: float = 0.8
var enemy_action_duration_seconds: float = 1.2

var _slot_pools: Array = []
var _slot_last_roll: Array = []
var _slot_active_wheel: int = -1
var _is_resolving_roll: bool = false
var _input_stage: String = "none"
var _last_player_oob_attempt: Dictionary = {}

var _attacks_played_this_turn: int = 0
var _forward_distance_this_turn: int = 0
var _scheduled_events: Array[Dictionary] = []
var _post_victory_queue: Array[Dictionary] = []
var _player_hat_lost: bool = false
var _start_battle_block_bonus: int = 0
var _rng := RandomNumberGenerator.new()

func start_battle(node: Dictionary) -> void:
	active_node = node
	var t := String(node.get("type", ""))
	var forced_enemy_id := String(node.get("enemy_id", ""))
	if not forced_enemy_id.is_empty():
		_enemy_id = forced_enemy_id
	elif t == "boss":
		_enemy_id = "dummy_boss"
	else:
		var pool := String(node.get("enemy_pool", ""))
		if not pool.is_empty():
			if not _enemy_db:
				_enemy_db = _ENEMY_DB_SCRIPT.new()
				_enemy_db.load_from_path("res://data/enemies.json")
			var rolled := String(_enemy_db.roll_enemy_id(pool, _rng))
			_enemy_id = rolled if not rolled.is_empty() else "dummy"
		else:
			_enemy_id = "dummy"
	_ensure_subcontrollers()
	_reset_battle_state()
	_battle_map.setup(7)
	_battle_map.spawn_enemy(PRIMARY_ENEMY_ID, _battle_map.enemy_outside_index)
	_turn_flow.start()
	battle_started.emit(node, get_available_actions())
	_emit_state()

func set_run_context(run: RunContext) -> void:
	_run = run
	if _run:
		_player_hp = _run.hp
		_quick_mode_level = _run.quick_mode_level
	_emit_state()

func set_quick_mode_level(level: int) -> void:
	_quick_mode_level = clampi(level, 0, 2)
	if _run:
		_run.quick_mode_level = _quick_mode_level
	_emit_state()

func _get_quick_wait_seconds() -> float:
	if _quick_mode_level == 1:
		return quick_wait_fast_seconds
	if _quick_mode_level == 2:
		return quick_wait_extreme_seconds
	return 0.0

func set_player_slot_wheels(pools: Array) -> void:
	_ensure_subcontrollers()
	_slot_pools = []
	for w in pools:
		if typeof(w) == TYPE_PACKED_STRING_ARRAY:
			_slot_pools.append(w.duplicate())
		elif typeof(w) == TYPE_ARRAY:
			_slot_pools.append(PackedStringArray(w))
	if _slot_machine:
		_slot_machine.set_wheels(_slot_pools)
		_slot_pools = _slot_machine.get_pool_snapshot()
	_emit_state()

func debug_set_player_hp(value: int) -> void:
	_player_hp = max(0, value)
	if _run:
		_run.set_hp(_player_hp)
	_emit_state()

func debug_set_enemy_hp(value: int) -> void:
	_enemy_hp = value
	_emit_state()

func debug_add_status(target: String, status_id: String, stacks: int) -> void:
	if status_id.is_empty() or stacks == 0:
		return
	if not _status_db:
		_status_db = StatusDatabase.load_default()
	if not _player_statuses:
		_player_statuses = StatusContainer.new(_status_db)
	if not _enemy_statuses:
		_enemy_statuses = StatusContainer.new(_status_db)
	_wire_status_signals()
	if target == "enemy":
		_enemy_statuses.add(status_id, stacks)
	else:
		_player_statuses.add(status_id, stacks)
	_emit_state()

func debug_clear_statuses(target: String) -> void:
	if not _status_db:
		_status_db = StatusDatabase.load_default()
	if target == "enemy":
		_enemy_statuses = StatusContainer.new(_status_db)
	else:
		_player_statuses = StatusContainer.new(_status_db)
	_wire_status_signals()
	_emit_state()

func request_player_action(action_id: String) -> bool:
	if not _turn_flow:
		return false
	if _is_resolving_roll or _is_resolving_enemy:
		return false
	if _turn_flow.phase != "player":
		return false
	if action_id == "roll" and _input_stage != "roll":
		return false
	return _turn_flow.submit_player_action(action_id)

func get_available_actions() -> Array[Dictionary]:
	return [
		{"id": "roll", "name": "摇老虎机", "desc": "从三个随机池各抽取一个技能，并按顺序自动发动"},
	]

func _ensure_subcontrollers() -> void:
	if not _battle_map:
		_battle_map = get_node_or_null("BattleMap")
	if not _battle_map:
		_battle_map = _BATTLE_MAP_SCRIPT.new()
		_battle_map.name = "BattleMap"
		add_child(_battle_map)
		_battle_map.player_moved.connect(func(_from_cell: int, _to_cell: int, _delta: int, _reason: String) -> void:
			_emit_state()
		)
		_battle_map.player_move_blocked.connect(func(_from_cell: int, _delta: int, _reason: String) -> void:
			_emit_state()
		)
		_battle_map.player_out_of_bounds_attempt.connect(func(direction: String, from_cell: int, attempted_to_cell: int, clamped_to_cell: int, delta: int) -> void:
			_on_player_out_of_bounds_attempt(direction, from_cell, attempted_to_cell, clamped_to_cell, delta)
		)

	if not _turn_flow:
		_turn_flow = get_node_or_null("TurnFlow")
	if not _turn_flow:
		_turn_flow = _TURN_FLOW_SCRIPT.new()
		_turn_flow.name = "TurnFlow"
		add_child(_turn_flow)
	var on_battle_started := Callable(self, "_on_turn_flow_battle_started")
	if not _turn_flow.battle_started.is_connected(on_battle_started):
		_turn_flow.battle_started.connect(on_battle_started)
	var on_action_committed := Callable(self, "_on_action_committed")
	if not _turn_flow.action_committed.is_connected(on_action_committed):
		_turn_flow.action_committed.connect(on_action_committed)
	var on_phase_changed := Callable(self, "_on_turn_flow_phase_changed")
	if not _turn_flow.phase_changed.is_connected(on_phase_changed):
		_turn_flow.phase_changed.connect(on_phase_changed)

	if not _slot_machine:
		_slot_machine = get_node_or_null("SlotMachine")
	if not _slot_machine:
		_slot_machine = _SLOT_MACHINE_SCRIPT.new()
		_slot_machine.name = "SlotMachine"
		add_child(_slot_machine)
	if not _card_db:
		_card_db = CardDatabase.load_default()
		_card_resolver = CardScriptResolver.new(_card_db)
	if not _status_db:
		_status_db = StatusDatabase.load_default()
	if not _enemy_db:
		_enemy_db = _ENEMY_DB_SCRIPT.new()
		_enemy_db.load_from_path("res://data/enemies.json")
	_enemy_def = _enemy_db.get_enemy(_enemy_id)
	_ensure_enemy_instance()

func _ensure_enemy_instance() -> void:
	if _enemy and is_instance_valid(_enemy) and _enemy_instance_id == _enemy_id:
		return
	if _enemy and is_instance_valid(_enemy):
		_enemy.queue_free()
	_enemy = null
	_enemy_instance_id = ""
	var script_path := String(_enemy_def.get("script", ""))
	if script_path.is_empty():
		return
	var s: Script = load(script_path) as Script
	if not s:
		return
	var n: Variant = s.new()
	if n is Node:
		_enemy = n
		_enemy.name = "Enemy"
		add_child(_enemy)
		_enemy_instance_id = _enemy_id

func _reset_battle_state() -> void:
	if _run:
		_player_hp = _run.hp
	else:
		_player_hp = 50
	_player_block = 0
	_enemy_hp = _get_enemy_max_hp()
	_slot_last_roll = []
	_slot_active_wheel = -1
	_is_resolving_roll = false
	_is_resolving_enemy = false
	_input_stage = "none"
	_enemy_intent = {}
	_last_player_oob_attempt = {}
	_attacks_played_this_turn = 0
	_forward_distance_this_turn = 0
	_scheduled_events = []
	_post_victory_queue = []
	_player_hat_lost = _run.hat_lost if _run else false
	_start_battle_block_bonus = 0
	if _run and _run.next_battle_start_block > 0:
		_start_battle_block_bonus = _run.next_battle_start_block
		_run.next_battle_start_block = 0
	_player_statuses = StatusContainer.new(_status_db)
	_enemy_statuses = StatusContainer.new(_status_db)
	_wire_status_signals()
	if _slot_machine:
		if _slot_pools.is_empty():
			_slot_machine.setup_default_3_wheels()
		else:
			_slot_machine.set_wheels(_slot_pools)
		_slot_pools = _slot_machine.get_pool_snapshot()

func _wire_status_signals() -> void:
	if _player_statuses:
		var cb := Callable(self, "_on_statuses_changed")
		if not _player_statuses.changed.is_connected(cb):
			_player_statuses.changed.connect(cb)
	if _enemy_statuses:
		var cb := Callable(self, "_on_statuses_changed")
		if not _enemy_statuses.changed.is_connected(cb):
			_enemy_statuses.changed.connect(cb)

func _on_statuses_changed() -> void:
	_update_enemy_intent_preview()
	_emit_state()

func _on_player_out_of_bounds_attempt(direction: String, from_cell: int, attempted_to_cell: int, clamped_to_cell: int, delta: int) -> void:
	# 仅打通事件通路：当前最小循环不惩罚，后续由敌人状态机/脚本消费该信号实现反应。
	_last_player_oob_attempt = {
		"direction": direction,
		"from": from_cell,
		"attempted_to": attempted_to_cell,
		"to": clamped_to_cell,
		"delta": delta,
		"turn": _turn_flow.turn if _turn_flow else 0,
	}
	_emit_state()

func _on_turn_flow_battle_started(initial_player_cell: int) -> void:
	if not _battle_map:
		return
	_battle_map.spawn_player(initial_player_cell)
	_emit_state()

func _on_turn_flow_phase_changed(_phase: String, _turn: int) -> void:
	if _phase == "player":
		_player_block = 0
		_input_stage = "roll"
		if _turn == 1 and _start_battle_block_bonus > 0:
			_player_block += _start_battle_block_bonus
			_start_battle_block_bonus = 0
		_attacks_played_this_turn = 0
		_forward_distance_this_turn = 0
		if _player_statuses:
			_player_statuses.set_stacks("temp_strength", 0)
			_player_statuses.set_stacks("next_attack_double", 0)
			_player_statuses.set_stacks("heroic_charge", 0)
			_player_statuses.set_stacks("next_time_take_damage_reflect", 0)
		if _enemy_statuses:
			_enemy_statuses.set_stacks("enemy_attack_halved_this_turn", 0)
		_process_scheduled_events()
		_enemy_intent = _roll_enemy_intent()
		_update_enemy_intent_preview()
		var ctx: Dictionary = {"turn": _turn, "phase": _phase}
		_player_statuses.dispatch("on_turn_start", ctx, {})
		_enemy_statuses.dispatch("on_turn_start", ctx, {})
		if _player_statuses:
			var next_block := _player_statuses.get_stacks("next_turn_gain_block")
			if next_block > 0:
				_player_block += next_block
				_player_statuses.set_stacks("next_turn_gain_block", 0)
	_emit_state()

func _process_scheduled_events() -> void:
	if _scheduled_events.is_empty():
		return
	var remaining: Array[Dictionary] = []
	for e in _scheduled_events:
		var d: Dictionary = e
		var turns := int(d.get("turns", 0))
		turns -= 1
		d["turns"] = turns
		if turns <= 0:
			_execute_scheduled_event(d)
		else:
			remaining.append(d)
	_scheduled_events = remaining

func _execute_scheduled_event(e: Dictionary) -> void:
	var actions: Array = e.get("actions", [])
	if actions.is_empty():
		return
	var sid := String(e.get("skill_id", ""))
	_execute_actions(actions, {"skill_id": sid, "wheel_index": -1, "entry_index": -1, "is_first_attack": false, "is_double_copy": true})

func _roll_enemy_intent() -> Dictionary:
	if not _enemy:
		return {}
	var ctx := {"player_cell": _battle_map.player_cell, "lane_length": _battle_map.lane_length}
	var v: Variant = _enemy.call("roll_intent", ctx)
	if typeof(v) == TYPE_DICTIONARY:
		return v
	return {}

func _update_enemy_intent_preview() -> void:
	if _enemy_intent.is_empty():
		return
	var base_damage: int = int(_enemy_intent.get("damage", 0))
	var intent_id: String = String(_enemy_intent.get("id", ""))
	if base_damage <= 0 or intent_id.is_empty():
		_enemy_intent.erase("damage_preview")
		return
	var preview_damage: int = _compute_enemy_damage_for_intent(base_damage, intent_id)
	_enemy_intent["damage_preview"] = preview_damage

func _compute_enemy_damage_for_intent(base_damage: int, intent_id: String) -> int:
	var dmg_payload: Dictionary = {"damage": base_damage, "intent_id": intent_id}
	var dmg_ctx: Dictionary = {"intent_id": intent_id, "source": "enemy", "target": "player"}
	if _enemy_statuses:
		_enemy_statuses.dispatch("before_deal_damage", dmg_ctx, dmg_payload)
	if _player_statuses:
		_player_statuses.dispatch("before_take_damage", dmg_ctx, dmg_payload)
	return max(0, int(dmg_payload.get("damage", 0)))

func _get_enemy_max_hp() -> int:
	if _enemy_def.is_empty():
		return 50
	return int(_enemy_def.get("max_hp", 50))

func _on_action_committed(_turn: int, action_id: String) -> void:
	if action_id == "roll":
		_start_roll_timeline()
		return
	var result := _resolve_action(action_id)
	var victory := bool(result.get("victory", false))
	_turn_flow.notify_action_resolved(action_id, result, not victory)
	_emit_state()
	if victory:
		_finish_victory()

func _resolve_action(action_id: String) -> Dictionary:
	_emit_log("未知行动：%s" % action_id)
	return {"ok": false, "error": "unknown_action", "action_id": action_id}

func _start_roll_timeline() -> void:
	if _is_resolving_roll:
		return
	_is_resolving_roll = true
	_slot_active_wheel = -1
	_input_stage = "none"
	_resolve_roll_timeline()

func _resolve_roll_timeline() -> void:
	if not _slot_machine:
		var fail := {"ok": false, "error": "slot_machine_missing"}
		_turn_flow.notify_action_resolved("roll", fail, true)
		_is_resolving_roll = false
		if _turn_flow and _turn_flow.phase == "player":
			_input_stage = "roll"
		else:
			_input_stage = "none"
		_emit_state()
		return
	if _slot_pools.is_empty():
		_slot_machine.setup_default_3_wheels()
		_slot_pools = _slot_machine.get_pool_snapshot()

	_slot_last_roll = _slot_machine.roll()
	roll_timeline_started.emit(_slot_last_roll)
	var roll_ids: Array[String] = []
	for item in _slot_last_roll:
		if typeof(item) == TYPE_DICTIONARY:
			roll_ids.append(String((item as Dictionary).get("id", "")))
	_emit_log("摇老虎机：%s" % " / ".join(roll_ids))
	_emit_state()

	var initial_wait := _get_roll_initial_delay_seconds()
	if initial_wait > 0.0:
		await get_tree().create_timer(initial_wait).timeout

	var step_results: Array[Dictionary] = []
	for i in range(_slot_last_roll.size()):
		var roll_item: Dictionary = _slot_last_roll[i] if typeof(_slot_last_roll[i]) == TYPE_DICTIONARY else {}
		var skill_id := String(roll_item.get("id", ""))
		_slot_active_wheel = i
		wheel_highlight_changed.emit(i)
		_emit_state()

		if not skill_id.is_empty():
			skill_step_started.emit(i, skill_id)
			var step := _resolve_skill(skill_id, roll_item)
			step["wheel_index"] = i
			step_results.append(step)
			skill_step_finished.emit(i, skill_id, step)
			_emit_state()

		if i < _slot_last_roll.size() - 1:
			var wait_seconds := _get_wheel_wait_seconds(skill_id)
			if wait_seconds > 0.0:
				await get_tree().create_timer(wait_seconds).timeout

	_slot_active_wheel = -1
	wheel_highlight_changed.emit(-1)
	_emit_state()

	var enemy_result: Dictionary = {"ok": true, "skipped": true, "reason": "enemy_dead"}
	var post_wait := _get_post_player_delay_seconds()
	if post_wait > 0.0:
		await get_tree().create_timer(post_wait).timeout

	if _enemy_hp > 0:
		enemy_result = await _resolve_enemy_action()
	_emit_state()

	var defeated := _player_hp <= 0
	var result := {
		"ok": true,
		"action_id": "roll",
		"roll": _slot_last_roll,
		"steps": step_results,
		"enemy_action": enemy_result,
		"enemy_hp": _enemy_hp,
		"player_hp": _player_hp,
		"player_block": _player_block,
		"victory": _enemy_hp <= 0,
		"defeat": defeated,
	}
	var victory := bool(result.get("victory", false))
	_turn_flow.notify_action_resolved("roll", result, (not victory) and (not defeated))
	_is_resolving_roll = false
	if _turn_flow and _turn_flow.phase == "player":
		_input_stage = "roll"
	else:
		_input_stage = "none"
	_emit_state()
	if victory:
		_finish_victory()
	if defeated:
		_finish_defeat()

func _resolve_skill(skill_id: String, roll_item: Dictionary = {}) -> Dictionary:
	var first := _resolve_skill_once(skill_id, roll_item, false)
	if not bool(first.get("ok", false)):
		return first
	if bool(first.get("is_attack", false)) and _player_statuses and _player_statuses.get_stacks("next_attack_double") > 0:
		_player_statuses.add("next_attack_double", -1)
		var second := _resolve_skill_once(skill_id, roll_item, true)
		first["double_second"] = second
	return first

func _resolve_skill_once(skill_id: String, roll_item: Dictionary, is_double_copy: bool) -> Dictionary:
	var effect: Dictionary = {}
	var name := skill_id
	var desc := ""
	if _card_resolver:
		name = _card_resolver.get_card_name(skill_id)
		desc = _card_resolver.get_card_text(skill_id)
		effect = _card_resolver.get_effect(skill_id)
	if effect.is_empty():
		_emit_log("未知技能：%s" % skill_id)
		return {"ok": false, "error": "unknown_skill", "skill_id": skill_id}

	var barrage_active := _enemy_hp <= 0

	var eff: Dictionary = effect.duplicate()
	var skill_ctx: Dictionary = {"skill_id": skill_id}
	if _player_statuses:
		_player_statuses.dispatch("before_skill", skill_ctx, {"effect": eff})

	var tags: Array = eff.get("tags", [])
	var actions: Array = eff.get("actions", [])
	var damage: int = int(eff.get("damage", 0))
	var block: int = int(eff.get("block", 0))
	var move: int = int(eff.get("move", 0))

	var is_attack := bool(eff.get("is_attack", false))
	if not is_attack and damage > 0:
		is_attack = true
	if not is_attack and not actions.is_empty():
		for a in actions:
			if typeof(a) == TYPE_DICTIONARY and String((a as Dictionary).get("type", "")) == "deal_damage":
				is_attack = true
				break
	var is_first_attack := is_attack and _attacks_played_this_turn == 0

	var wheel_index := int(roll_item.get("wheel_index", -1))
	var entry_index := int(roll_item.get("entry_index", -1))
	var exec_ctx := {"skill_id": skill_id, "wheel_index": wheel_index, "entry_index": entry_index, "is_first_attack": is_first_attack, "is_double_copy": is_double_copy}

	var move_result: Dictionary = {}
	var total_damage := 0
	var total_block := 0
	var total_move := 0

	if not actions.is_empty():
		var r := _execute_actions(actions, exec_ctx)
		move_result = r.get("move_result", {})
		total_damage = int(r.get("damage", 0))
		total_block = int(r.get("block", 0))
		total_move = int(r.get("move", 0))
	else:
		if block > 0:
			_player_block += block
			total_block += block
		if damage > 0:
			total_damage += int(_deal_damage_to_enemy(damage, {"skill_id": skill_id, "source": "player", "target": "enemy"}).get("damage", 0))
		if move != 0:
			move_result = _apply_move(move, skill_id)
			total_move += int(move_result.get("delta_applied", 0))

	if is_attack and not is_double_copy:
		_attacks_played_this_turn += 1

	if barrage_active and not is_double_copy:
		_execute_barrage(eff.get("barrage", {}), exec_ctx, actions)

	if not is_double_copy and _has_tag(tags, "消耗") and wheel_index >= 0 and entry_index >= 0 and _slot_machine:
		_slot_machine.set_entry_consumed(wheel_index, entry_index, true)
		_slot_pools = _slot_machine.get_pool_snapshot()

	var quick_playback_mode := "tail"
	if _card_resolver:
		quick_playback_mode = _card_resolver.get_quick_playback_mode(skill_id)

	_emit_log("%s：%s" % [name, desc])

	var step := {
		"ok": true,
		"skill_id": skill_id,
		"damage": total_damage,
		"block": total_block,
		"move": total_move,
		"move_result": move_result,
		"enemy_hp": _enemy_hp,
		"player_hp": _player_hp,
		"player_block": _player_block,
		"quick_playback_mode": quick_playback_mode,
		"is_attack": is_attack,
	}
	if _player_statuses:
		_player_statuses.dispatch("after_skill", skill_ctx, {"result": step})
	return step

func _deal_damage_to_enemy(amount: int, ctx: Dictionary) -> Dictionary:
	var skill_id := String(ctx.get("skill_id", ""))
	var dmg_payload: Dictionary = {"damage": amount, "skill_id": skill_id}
	var dmg_ctx: Dictionary = {"skill_id": skill_id, "source": String(ctx.get("source", "player")), "target": "enemy"}
	if _player_statuses:
		_player_statuses.dispatch("before_deal_damage", dmg_ctx, dmg_payload)
	if _enemy_statuses:
		_enemy_statuses.dispatch("before_take_damage", dmg_ctx, dmg_payload)
	var final_damage: int = max(0, int(dmg_payload.get("damage", 0)))
	_enemy_hp -= final_damage
	var after_payload: Dictionary = {"damage": final_damage, "skill_id": skill_id}
	if _player_statuses:
		_player_statuses.dispatch("after_damage", dmg_ctx, after_payload)
	if _enemy_statuses:
		_enemy_statuses.dispatch("after_damage", dmg_ctx, after_payload)
	return {"damage": final_damage}

func _has_tag(tags: Array, tag: String) -> bool:
	for t in tags:
		if String(t) == tag:
			return true
	return false

func _execute_actions(actions: Array, ctx: Dictionary) -> Dictionary:
	var out := {"damage": 0, "block": 0, "move": 0, "move_result": {}}
	for a in actions:
		if typeof(a) != TYPE_DICTIONARY:
			continue
		var r := _execute_action(a as Dictionary, ctx)
		out["damage"] = int(out.get("damage", 0)) + int(r.get("damage", 0))
		out["block"] = int(out.get("block", 0)) + int(r.get("block", 0))
		out["move"] = int(out.get("move", 0)) + int(r.get("move", 0))
		if r.has("move_result") and typeof(r.get("move_result")) == TYPE_DICTIONARY:
			out["move_result"] = r.get("move_result")
	return out

func _execute_action(a: Dictionary, ctx: Dictionary) -> Dictionary:
	var t := String(a.get("type", ""))
	var skill_id := String(ctx.get("skill_id", ""))
	if t == "move":
		var delta := int(a.get("delta", 0))
		if delta == 0:
			return {}
		var mr := _apply_move(delta, skill_id)
		return {"move": int(mr.get("delta_applied", 0)), "move_result": mr}
	if t == "move_to_cell":
		var cell := int(a.get("cell", 0))
		var delta := cell - int(_battle_map.player_cell)
		if delta == 0:
			return {}
		var mr := _apply_move(delta, skill_id)
		return {"move": int(mr.get("delta_applied", 0)), "move_result": mr}
	if t == "conditional_move_by_cell":
		var min_cell := int(a.get("min", 0))
		var max_cell := int(a.get("max", 0))
		var c := int(_battle_map.player_cell)
		var delta := int(a.get("else_delta", 0))
		if c >= min_cell and c <= max_cell:
			delta = int(a.get("then_delta", 0))
		if delta == 0:
			return {}
		var mr := _apply_move(delta, skill_id)
		return {"move": int(mr.get("delta_applied", 0)), "move_result": mr}
	if t == "wander":
		var steps: int = int(max(0, int(a.get("steps", 0))))
		var last_move: Dictionary = {}
		var total: int = 0
		for _i in range(steps):
			var dir: int = -1 if _rng.randi_range(0, 1) == 0 else 1
			last_move = _apply_move(dir, skill_id)
			total += int(last_move.get("delta_applied", 0))
		return {"move": total, "move_result": last_move}
	if t == "gain_block":
		var amount := int(a.get("amount", 0))
		if amount <= 0:
			return {}
		_player_block += amount
		return {"block": amount}
	if t == "self_damage":
		var amount := int(a.get("amount", 0))
		if amount <= 0:
			return {}
		_player_hp = max(0, _player_hp - amount)
		return {"self_damage": amount}
	if t == "deal_damage":
		var hits: int = int(max(1, int(a.get("hits", 1))))
		var on_hit_gain_block := int(a.get("on_hit_gain_block", 0))
		var total_damage: int = 0
		var total_block: int = 0
		for _i in range(hits):
			var amount: int = int(_compute_damage_amount(a, ctx))
			if amount <= 0:
				continue
			var dealt := int(_deal_damage_to_enemy(amount, {"skill_id": skill_id, "source": "player", "target": "enemy"}).get("damage", 0))
			total_damage += dealt
			if on_hit_gain_block > 0 and dealt > 0:
				_player_block += on_hit_gain_block
				total_block += on_hit_gain_block
		return {"damage": total_damage, "block": total_block}
	if t == "deal_damage_front_cells":
		var cells: int = int(max(0, int(a.get("cells", 0))))
		if cells <= 0:
			return {}
		var enemy_cell: int = int(_battle_map.enemies.get(PRIMARY_ENEMY_ID, _battle_map.enemy_outside_index))
		var from_cell: int = int(_battle_map.player_cell) + 1
		var to_cell: int = int(_battle_map.player_cell) + cells
		if enemy_cell < from_cell or enemy_cell > to_cell:
			return {}
		var amount := int(a.get("amount", 0))
		if amount <= 0:
			return {}
		var dealt := int(_deal_damage_to_enemy(amount, {"skill_id": skill_id, "source": "player", "target": "enemy"}).get("damage", 0))
		return {"damage": dealt}
	if t == "apply_status":
		var target := String(a.get("target", "player"))
		var status_id := String(a.get("status_id", ""))
		var stacks := int(a.get("stacks", 0))
		if status_id.is_empty() or stacks == 0:
			return {}
		if target == "enemy":
			if _enemy_statuses:
				_enemy_statuses.add(status_id, stacks)
		else:
			if _player_statuses:
				_player_statuses.add(status_id, stacks)
		return {"status_id": status_id, "stacks": stacks}
	if t == "schedule":
		var turns: int = int(max(1, int(a.get("turns", 1))))
		var scheduled_actions: Array = a.get("actions", [])
		if scheduled_actions.is_empty():
			return {}
		_scheduled_events.append({"turns": turns, "actions": scheduled_actions, "skill_id": skill_id})
		return {}
	if t == "fire_random_bullet":
		_fire_random_bullets(a, ctx)
		return {}
	if t == "gain_gold":
		var amount := int(a.get("amount", 0))
		if amount <= 0:
			return {}
		if _run:
			_run.add_gold(amount)
		return {"gold": amount}
	if t == "set_hat_lost":
		_player_hat_lost = true
		if _run:
			_run.hat_lost = true
		return {}
	return {}

func _compute_damage_amount(a: Dictionary, ctx: Dictionary) -> int:
	if a.has("amount_by_cell"):
		var cell := int(_battle_map.player_cell)
		var table: Array = a.get("amount_by_cell", [])
		for row in table:
			if typeof(row) != TYPE_DICTIONARY:
				continue
			var r: Dictionary = row
			var mn := int(r.get("min", 0))
			var mx := int(r.get("max", 0))
			if cell >= mn and cell <= mx:
				return int(r.get("amount", 0))
		return 0
	var amount := int(a.get("amount", 0))
	if a.has("amount_expr"):
		var expr := String(a.get("amount_expr", ""))
		if expr == "player_block":
			amount = _player_block
		elif expr == "forward_distance_this_turn":
			amount = _forward_distance_this_turn
		elif expr == "current_wheel_available_count":
			amount = _get_current_wheel_available_count(ctx)
	var mult := int(a.get("mult", 1))
	if mult < 1:
		mult = 1
	amount *= mult
	if bool(ctx.get("is_first_attack", false)):
		if a.has("amount_if_first_attack"):
			amount = int(a.get("amount_if_first_attack", amount))
		if a.has("mult_if_first_attack"):
			amount *= int(a.get("mult_if_first_attack", 1))
	return max(0, amount)

func _get_current_wheel_available_count(ctx: Dictionary) -> int:
	var wi := int(ctx.get("wheel_index", -1))
	if wi < 0 or wi >= _slot_pools.size():
		return 0
	var w: Array = _slot_pools[wi]
	var count := 0
	for item in w:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var e: Dictionary = item
		if bool(e.get("consumed", false)):
			continue
		if String(e.get("id", "")).is_empty():
			continue
		count += 1
	return count

func _apply_move(delta: int, skill_id: String) -> Dictionary:
	var move_result: Dictionary = _battle_map.request_move_player(delta)
	if bool(move_result.get("applied", false)):
		var applied_delta := int(move_result.get("delta_applied", 0))
		var move_ctx: Dictionary = {"skill_id": skill_id}
		var move_payload: Dictionary = {
			"from": int(move_result.get("from", 0)),
			"to": int(move_result.get("to", 0)),
			"delta": applied_delta,
			"attempted_delta": int(move_result.get("delta", delta)),
			"out_of_bounds_attempt": bool(move_result.get("out_of_bounds_attempt", false)),
			"direction": String(move_result.get("direction", "")),
		}
		if _player_statuses:
			_player_statuses.dispatch("on_move", move_ctx, move_payload)

		if applied_delta > 0:
			_forward_distance_this_turn += applied_delta
			if _player_statuses:
				var per := _player_statuses.get_stacks("move_forward_deal_damage")
				if per > 0:
					for _i in range(applied_delta):
						_deal_damage_to_enemy(per, {"skill_id": "move_forward_deal_damage", "source": "player", "target": "enemy"})
				var heroic := _player_statuses.get_stacks("heroic_charge")
				if heroic > 0:
					_player_statuses.add("temp_strength", heroic * applied_delta)
		elif applied_delta < 0:
			if _player_statuses:
				var perb := _player_statuses.get_stacks("move_backward_gain_block")
				if perb > 0:
					_player_block += perb * abs(applied_delta)
	return move_result

func _execute_barrage(barrage: Variant, ctx: Dictionary, base_actions: Array) -> void:
	if typeof(barrage) != TYPE_DICTIONARY:
		return
	var b: Dictionary = barrage
	if String(b.get("when", "")) != "any_enemy_dead":
		return
	var post_victory: Array = b.get("post_victory", [])
	for item in post_victory:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var it: Dictionary = item
		var t := String(it.get("type", ""))
		if t == "reflection_remove_bullet":
			_post_victory_queue.append({"type": "reflection_remove_bullet", "wheel_index": int(ctx.get("wheel_index", -1))})
		elif t == "extra_reward_group":
			_post_victory_queue.append({"type": "extra_reward_group", "count": int(it.get("count", 1))})
		elif t == "next_battle_start_block":
			_post_victory_queue.append({"type": "next_battle_start_block", "amount": int(it.get("amount", 0))})

	var actions: Array = b.get("actions", [])
	for item in actions:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var act: Dictionary = item
		if String(act.get("type", "")) == "repeat_self":
			var times: int = int(max(0, int(act.get("times", 0))))
			for _i in range(times):
				_execute_actions(base_actions, {"skill_id": String(ctx.get("skill_id", "")), "wheel_index": int(ctx.get("wheel_index", -1)), "entry_index": int(ctx.get("entry_index", -1)), "is_first_attack": false, "is_double_copy": true})
		else:
			_execute_action(act, ctx)

func _fire_random_bullets(a: Dictionary, ctx: Dictionary) -> void:
	if _slot_pools.is_empty():
		return
	var scope := String(a.get("scope", "current"))
	var filter := String(a.get("filter", "available"))
	var times: int = int(max(1, int(a.get("times", 1))))
	var unique := bool(a.get("unique", false))
	var exclude_current := bool(a.get("exclude_current", false))
	var current_wi := int(ctx.get("wheel_index", -1))
	var current_ei := int(ctx.get("entry_index", -1))
	var picked: Array[String] = []

	var pick_from_wheel: Callable = func(wi: int) -> Dictionary:
		if wi < 0 or wi >= _slot_pools.size():
			return {}
		var w: Array = _slot_pools[wi]
		var candidates: Array[int] = []
		for ei in range(w.size()):
			var v: Variant = w[ei]
			if typeof(v) != TYPE_DICTIONARY:
				continue
			var e: Dictionary = v as Dictionary
			if exclude_current and wi == current_wi and ei == current_ei:
				continue
			var id := String(e.get("id", ""))
			if id.is_empty():
				continue
			var consumed := bool(e.get("consumed", false))
			if filter == "consumed" and not consumed:
				continue
			if filter != "consumed" and consumed:
				continue
			var key := "%d:%d" % [wi, ei]
			if unique and picked.has(key):
				continue
			candidates.append(ei)
		if candidates.is_empty():
			return {}
		var ei: int = int(candidates[_rng.randi_range(0, candidates.size() - 1)])
		var key := "%d:%d" % [wi, ei]
		picked.append(key)
		var e: Dictionary = w[ei]
		return {"wheel_index": wi, "entry_index": ei, "id": String(e.get("id", ""))}

	if scope == "each_other":
		for wi in range(_slot_pools.size()):
			if wi == current_wi:
				continue
			for _i in range(times):
				var pick: Dictionary = pick_from_wheel.call(wi) as Dictionary
				if pick.is_empty():
					continue
				_resolve_skill(String(pick.get("id", "")), pick)
		return

	for _i in range(times):
		var wi := current_wi
		if scope == "any":
			var wheel_candidates: Array[int] = []
			for wj in range(_slot_pools.size()):
				var probe: Dictionary = pick_from_wheel.call(wj) as Dictionary
				if probe.is_empty():
					continue
				wheel_candidates.append(wj)
				if unique:
					picked.remove_at(picked.size() - 1)
			if wheel_candidates.is_empty():
				return
			wi = int(wheel_candidates[_rng.randi_range(0, wheel_candidates.size() - 1)])
		elif scope != "current":
			continue
		var pick: Dictionary = pick_from_wheel.call(wi) as Dictionary
		if pick.is_empty():
			continue
		_resolve_skill(String(pick.get("id", "")), pick)

func _get_roll_initial_delay_seconds() -> float:
	var q := _get_quick_wait_seconds()
	if q > 0.0:
		return q
	if _slot_machine:
		return float(_slot_machine.roll_initial_delay_seconds)
	return 0.0

func _get_post_player_delay_seconds() -> float:
	var q := _get_quick_wait_seconds()
	if q > 0.0:
		return q
	return post_player_delay_seconds

func _resolve_enemy_action():
	if _enemy_intent.is_empty():
		return {"ok": true, "intent_id": "none", "text": "无意图"}
	_is_resolving_enemy = true
	_emit_state()
	var duration_seconds := float(_enemy_intent.get("duration_seconds", 1.2))
	var q := _get_quick_wait_seconds()
	if q > 0.0:
		duration_seconds = q

	var intent_id := String(_enemy_intent.get("id", ""))
	var text := String(_enemy_intent.get("text", ""))
	var base_damage: int = int(_enemy_intent.get("damage", 0))
	var damage: int = _compute_enemy_damage_for_intent(base_damage, intent_id)
	var cells: Variant = _enemy_intent.get("cells", PackedInt32Array())

	var enemy_action_ctx: Dictionary = {"intent_id": intent_id}
	if _enemy_statuses:
		_enemy_statuses.dispatch("before_enemy_action", enemy_action_ctx, {"intent": _enemy_intent})
	if _player_statuses:
		_player_statuses.dispatch("before_enemy_action", enemy_action_ctx, {"intent": _enemy_intent})

	var hit := false
	if typeof(cells) == TYPE_PACKED_INT32_ARRAY:
		hit = (cells as PackedInt32Array).has(_battle_map.player_cell)

	var applied_damage := 0
	var applied_block := 0
	var prevented_by_fake_target := false
	if hit and damage > 0:
		if _player_statuses and _player_statuses.get_stacks("next_enemy_hit_zero") > 0:
			prevented_by_fake_target = true
			_player_statuses.set_stacks("next_enemy_hit_zero", 0)
			damage = 0
			_player_hat_lost = true
			if _run:
				_run.hat_lost = true
		if damage > 0:
			applied_block = min(_player_block, damage)
			_player_block = max(0, _player_block - damage)
			applied_damage = max(0, damage - applied_block)
			_player_hp = max(0, _player_hp - applied_damage)
			var after_payload: Dictionary = {"damage": damage, "intent_id": intent_id, "applied_damage": applied_damage, "applied_block": applied_block}
			var after_ctx: Dictionary = {"intent_id": intent_id, "source": "enemy", "target": "player"}
			if _enemy_statuses:
				_enemy_statuses.dispatch("after_damage", after_ctx, after_payload)
			if _player_statuses:
				_player_statuses.dispatch("after_damage", after_ctx, after_payload)
				if applied_damage > 0 and _player_statuses.get_stacks("next_time_take_damage_reflect") > 0:
					_player_statuses.set_stacks("next_time_take_damage_reflect", 0)
					_deal_damage_to_enemy(6, {"skill_id": "reflect", "source": "player", "target": "enemy"})

	var enemy_name := "敌人"
	if _enemy:
		var v: Variant = _enemy.call("get_name_text")
		if typeof(v) == TYPE_STRING:
			enemy_name = String(v)
	_emit_log("%s：%s" % [enemy_name, text])

	if _enemy_statuses:
		_enemy_statuses.dispatch("after_enemy_action", enemy_action_ctx, {"hit": hit, "damage_base": base_damage, "damage": damage, "applied_damage": applied_damage, "applied_block": applied_block, "prevented_by_fake_target": prevented_by_fake_target})
	if _player_statuses:
		_player_statuses.dispatch("after_enemy_action", enemy_action_ctx, {"hit": hit, "damage_base": base_damage, "damage": damage, "applied_damage": applied_damage, "applied_block": applied_block, "prevented_by_fake_target": prevented_by_fake_target})
	if _enemy_statuses:
		_enemy_statuses.set_stacks("enemy_attack_halved_this_turn", 0)

	if duration_seconds > 0.0:
		await get_tree().create_timer(duration_seconds).timeout
	_is_resolving_enemy = false
	return {
		"ok": true,
		"intent_id": intent_id,
		"text": text,
		"hit": hit,
		"damage_base": base_damage,
		"damage": damage,
		"applied_damage": applied_damage,
		"applied_block": applied_block,
		"prevented_by_fake_target": prevented_by_fake_target,
		"player_hp": _player_hp,
		"player_block": _player_block,
	}

func _get_wheel_wait_seconds(skill_id: String) -> float:
	var q := _get_quick_wait_seconds()
	if q > 0.0:
		# 预留：快战时动画裁切策略由 step.quick_playback_mode 指示，
		# 当前仅统一时长为（快/极速）固定秒数，具体“播放结尾片段”由后续动画系统实现。
		return q
	if _card_resolver:
		var t: float = _card_resolver.get_timeline_seconds(skill_id)
		if t > 0.0:
			return t
	if _slot_machine:
		return float(_slot_machine.default_wheel_interval_seconds)
	return 0.0

func _finish_victory() -> void:
	if _run:
		_run.set_hp(_player_hp)
	var result := {
		"node": active_node,
		"enemy_id": PRIMARY_ENEMY_ID,
		"enemy_hp": _enemy_hp,
		"turn": _turn_flow.turn,
		"post_victory_queue": _post_victory_queue,
	}
	battle_finished_victory.emit(result)

func _finish_defeat() -> void:
	if _run:
		_run.set_hp(_player_hp)
	var result := {
		"node": active_node,
		"enemy_id": PRIMARY_ENEMY_ID,
		"enemy_hp": _enemy_hp,
		"turn": _turn_flow.turn,
		"player_hp": _player_hp,
	}
	battle_finished_defeat.emit(result)

func _emit_state() -> void:
	if not _battle_map or not _turn_flow:
		return
	var enemy_cell := int(_battle_map.enemies.get(PRIMARY_ENEMY_ID, _battle_map.enemy_outside_index))
	var enemy_name := "dummy"
	if _enemy:
		var v: Variant = _enemy.call("get_name_text")
		if typeof(v) == TYPE_STRING:
			enemy_name = String(v)
	var player_statuses: Array = []
	if _player_statuses:
		player_statuses = _player_statuses.to_state_array()
	var enemy_statuses: Array = []
	if _enemy_statuses:
		enemy_statuses = _enemy_statuses.to_state_array()
	battle_state_changed.emit({
		"turn": _turn_flow.turn,
		"phase": _turn_flow.phase,
		"lane_length": _battle_map.lane_length,
		"enemy_outside_index": _battle_map.enemy_outside_index,
		"player": {"hp": _player_hp, "block": _player_block, "cell": _battle_map.player_cell, "statuses": player_statuses, "visual": {"hat_lost": _player_hat_lost}},
		"enemies": [{"id": PRIMARY_ENEMY_ID, "name": enemy_name, "hp": _enemy_hp, "cell": enemy_cell, "intent": _enemy_intent, "statuses": enemy_statuses}],
		"slot": {"pools": _slot_pools, "last_roll": _slot_last_roll, "active_wheel": _slot_active_wheel, "is_resolving": _is_resolving_roll or _is_resolving_enemy},
		"movement": {"last_oob_attempt": _last_player_oob_attempt},
		"input": {"locked": _is_resolving_roll or _is_resolving_enemy or _turn_flow.phase != "player", "stage": _input_stage},
	})

func _emit_log(text: String) -> void:
	battle_log.emit(text)
