extends Node

enum FlowState { TITLE, RUN_MAP, IN_NODE, POST_BATTLE_QUEUE, POST_BATTLE_REWARD, END }

var _state: FlowState = FlowState.TITLE

var _run: RunContext
var _post_battle_queue: Array[Dictionary] = []

@onready var _map: Node = get_parent().get_node("MapController")
@onready var _battle: Node = get_parent().get_node("BattleController")
@onready var _ui: Node = get_parent().get_node("UIController")
@onready var _reward: Node = get_parent().get_node("RewardController")
@onready var _events: Node = get_parent().get_node("EventController")
@onready var _shop: Node = get_parent().get_node("ShopController")

func _ready() -> void:
	_ui.new_game_pressed.connect(_on_new_game_pressed)
	_ui.select_prev_pressed.connect(func() -> void: _map.select_prev())
	_ui.select_next_pressed.connect(func() -> void: _map.select_next())
	_ui.select_index_pressed.connect(func(index: int) -> void: _map.select_index(index))
	_ui.enter_node_pressed.connect(func() -> void: _map.enter_selected())
	_ui.battle_action_pressed.connect(_on_battle_action_pressed)
	_ui.placeholder_continue_pressed.connect(_on_placeholder_continue_pressed)
	_ui.event_option_selected.connect(_on_event_option_selected)
	_ui.event_continue_pressed.connect(_on_event_continue_pressed)
	_ui.back_to_title_pressed.connect(_on_back_to_title_pressed)
	_ui.quick_mode_level_changed.connect(_on_quick_mode_level_changed)
	_ui.debug_action.connect(_on_debug_action)

	_map.selection_changed.connect(_on_map_selection_changed)
	_map.route_finished.connect(_on_route_finished)

	_battle.battle_started.connect(_on_battle_started)
	_battle.battle_state_changed.connect(_on_battle_state_changed)
	_battle.battle_finished_victory.connect(_on_battle_finished_victory)
	_battle.battle_finished_defeat.connect(_on_battle_finished_defeat)

	_reward.rewards_finished.connect(_on_rewards_finished)
	_ui.reflection_remove_selected.connect(_on_reflection_remove_selected)
	_ui.reflection_remove_skipped.connect(_on_reflection_remove_skipped)

	_ui.show_title()
	_state = FlowState.TITLE

func _on_new_game_pressed() -> void:
	_run = RunContext.new()
	_run.reset()

	_map.setup_fixed_route()
	_ui.show_run_ui()
	_ui.set_active_run(_run)
	_refresh_header()
	_ui.set_debug_run_state({"gold": _run.gold, "hp": _run.hp, "quick_mode_level": _run.quick_mode_level})
	_render_map_ui(_map.current_index, _map.current_index)
	_start_current_node()

func _on_quick_mode_level_changed(level: int) -> void:
	if _run:
		_run.quick_mode_level = clampi(level, 0, 2)
	_battle.set_quick_mode_level(level)

func _on_map_selection_changed(_node: Dictionary, selected_index: int, current_index: int) -> void:
	if _state == FlowState.TITLE or _state == FlowState.END:
		return
	_render_map_ui(selected_index, current_index)
	_refresh_header()

func _on_battle_action_pressed(action_id: String) -> void:
	if _state != FlowState.IN_NODE:
		return
	_battle.request_player_action(action_id)

func _on_placeholder_continue_pressed() -> void:
	if _state != FlowState.IN_NODE:
		return
	if _map.complete_current_and_advance():
		_refresh_header()
		_render_map_ui(_map.current_index, _map.current_index)
		_start_current_node()

func _on_event_option_selected(_option_id: String) -> void:
	if _state != FlowState.IN_NODE:
		return
	var node: Dictionary = _map.get_current_node()
	var node_type := String(node.get("type", ""))
	if node_type != "event" and node_type != "rest":
		return
	if node_type == "rest":
		if not _run:
			return
		if _option_id == "rest":
			_run.heal_to_at_least_half()
			_ui.set_debug_run_state({"gold": _run.gold, "hp": _run.hp, "quick_mode_level": _run.quick_mode_level})
		return
	if not _run:
		return
	var event_data: Dictionary = {}
	if node.has("event") and typeof(node["event"]) == TYPE_DICTIONARY:
		event_data = node["event"]
	var options: Array = event_data.get("options", [])
	for x in options:
		if typeof(x) != TYPE_DICTIONARY:
			continue
		var o: Dictionary = x
		if String(o.get("id", "")) != _option_id:
			continue
		var effects: Array = o.get("effects", [])
		for e in effects:
			if typeof(e) != TYPE_DICTIONARY:
				continue
			var d: Dictionary = e
			var t := String(d.get("type", ""))
			if t == "gold":
				_run.add_gold(int(d.get("amount", 0)))
			elif t == "hp":
				_run.set_hp(_run.hp + int(d.get("amount", 0)))
			elif t == "hat_lost":
				_run.hat_lost = bool(d.get("value", true))
			elif t == "next_battle_start_block":
				_run.next_battle_start_block += int(d.get("amount", 0))
		return

func _on_event_continue_pressed() -> void:
	if _state != FlowState.IN_NODE:
		return
	var node: Dictionary = _map.get_current_node()
	var t := String(node.get("type", ""))
	if t != "event" and t != "rest" and t != "shop":
		return
	if _map.complete_current_and_advance():
		_refresh_header()
		_render_map_ui(_map.current_index, _map.current_index)
		_start_current_node()

func _on_route_finished() -> void:
	_state = FlowState.END
	_ui.show_end()

func _on_back_to_title_pressed() -> void:
	_state = FlowState.TITLE
	_ui.show_title()

func _on_battle_started(node: Dictionary, actions: Array[Dictionary]) -> void:
	if _state == FlowState.TITLE or _state == FlowState.END:
		return
	_ui.show_battle(node, actions)

func _on_battle_state_changed(state: Dictionary) -> void:
	if _state != FlowState.IN_NODE:
		return
	if _run:
		_refresh_header()
		_ui.set_debug_run_state({"gold": _run.gold, "hp": _run.hp, "quick_mode_level": _run.quick_mode_level})
	_ui.update_battle_state(state)

func _on_debug_action(action: Dictionary) -> void:
	var t := String(action.get("type", ""))
	if t == "set_gold":
		var v := int(action.get("value", 0))
		if _run:
			_run.set_gold(v)
			_refresh_header()
			_ui.set_debug_run_state({"gold": _run.gold, "hp": _run.hp, "quick_mode_level": _run.quick_mode_level})
		return
	if t == "set_player_hp":
		var v := int(action.get("value", 0))
		if _run:
			_run.set_hp(v)
		_battle.debug_set_player_hp(v)
		if _run:
			_refresh_header()
			_ui.set_debug_run_state({"gold": _run.gold, "hp": _run.hp, "quick_mode_level": _run.quick_mode_level})
		return
	if t == "set_enemy_hp":
		_battle.debug_set_enemy_hp(int(action.get("value", 0)))
		return
	if t == "add_status":
		var target := String(action.get("target", ""))
		var status_id := String(action.get("status_id", ""))
		var stacks := int(action.get("stacks", 1))
		_battle.debug_add_status(target, status_id, stacks)
		return
	if t == "clear_statuses":
		var target := String(action.get("target", ""))
		_battle.debug_clear_statuses(target)
		return
	if t == "set_slot_wheels":
		var wheels: Array = action.get("wheels", [])
		_battle.set_player_slot_wheels(wheels)
		return

func _on_battle_finished_victory(_result: Dictionary) -> void:
	if _state != FlowState.IN_NODE:
		return
	_post_battle_queue = _result.get("post_victory_queue", [])
	_state = FlowState.POST_BATTLE_QUEUE
	_process_post_battle_queue_next()

func _on_battle_finished_defeat(_result: Dictionary) -> void:
	if _state == FlowState.END:
		return
	_state = FlowState.END
	_ui.show_end("失败", "你倒下了，本局结束。")

func _on_rewards_finished() -> void:
	if _state == FlowState.POST_BATTLE_QUEUE:
		_process_post_battle_queue_next()
		return
	if _state == FlowState.POST_BATTLE_REWARD:
		if _map.complete_current_and_advance():
			_refresh_header()
			_render_map_ui(_map.current_index, _map.current_index)
			_start_current_node()
		return

func _process_post_battle_queue_next() -> void:
	while not _post_battle_queue.is_empty():
		var item: Dictionary = _post_battle_queue.pop_front()
		var t := String(item.get("type", ""))
		if t == "next_battle_start_block":
			if _run:
				_run.next_battle_start_block += int(item.get("amount", 0))
			continue
		if t == "extra_reward_group":
			_reward.begin_extra_card_rewards(_run, int(item.get("count", 3)))
			return
		if t == "reflection_remove_bullet":
			_ui.show_reflection_remove(_run, int(item.get("wheel_index", -1)))
			return
	if _state == FlowState.POST_BATTLE_QUEUE:
		_state = FlowState.POST_BATTLE_REWARD
		_reward.begin_battle_rewards(_run)

func _on_reflection_remove_selected(wheel_index: int, entry_index: int) -> void:
	if _state != FlowState.POST_BATTLE_QUEUE:
		return
	if _run:
		_run.remove_card_from_wheel(wheel_index, entry_index)
	_process_post_battle_queue_next()

func _on_reflection_remove_skipped(_wheel_index: int) -> void:
	if _state != FlowState.POST_BATTLE_QUEUE:
		return
	_process_post_battle_queue_next()

func _start_current_node() -> void:
	var node: Dictionary = _map.get_current_node()
	if node.is_empty():
		_on_route_finished()
		return
	_refresh_header()
	var t := String(node.get("type", ""))
	_state = FlowState.IN_NODE
	if t == "battle" or t == "boss" or t == "elite":
		if _run:
			_battle.set_run_context(_run)
			_battle.set_player_slot_wheels(_run.get_wheels_snapshot())
		_battle.start_battle(node)
	if t == "battle" or t == "boss" or t == "elite":
		return
	if t == "event":
		if _events:
			var eid := String(node.get("event_id", ""))
			if not eid.is_empty():
				_events.begin_event(_run, eid)
			else:
				_events.begin_random_event(_run, String(node.get("event_pool", "通用")))
		return
	if t == "rest":
		_ui.show_rest_node(node, _run)
		return
	if t == "shop":
		if _shop:
			_shop.begin_shop(_run, node)
		return
	_ui.show_node_content(node)

func _get_progress_text() -> String:
	if not _map:
		return ""
	var floor_total := int(_map.get_floor_count())
	var floor_n := int(_map.get_current_floor_number())
	var node_total := int(_map.get_nodes_per_floor())
	var node_n := int(_map.get_current_node_number_in_floor())
	return "第%d/%d层 %d/%d节点" % [floor_n, floor_total, node_n, node_total]

func _refresh_header() -> void:
	if not _ui or not _run:
		return
	_ui.set_header(_get_progress_text(), _run.gold)

func _render_map_ui(selected_index: int, current_index: int) -> void:
	if not _ui or not _map:
		return
	var nodes_per_floor: int = int(_map.get_nodes_per_floor())
	var floor_index: int = int(_map.get_floor_index_for_global(selected_index))
	var base_global_index: int = floor_index * nodes_per_floor
	var floor_nodes: Array[Dictionary] = _map.get_floor_nodes(floor_index)
	var selected_local: int = selected_index - base_global_index
	var current_local: int = -1
	if current_index >= base_global_index and current_index < (base_global_index + nodes_per_floor):
		current_local = current_index - base_global_index
	_ui.render_map(floor_nodes, selected_local, current_local, base_global_index, current_index)
