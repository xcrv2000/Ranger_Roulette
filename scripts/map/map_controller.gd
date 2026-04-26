extends Node

signal selection_changed(node: Dictionary, selected_index: int, current_index: int)
signal entered_node(node: Dictionary, index: int)
signal route_finished

const NODE_BATTLE := "battle"
const NODE_EVENT := "event"
const NODE_SHOP := "shop"
const NODE_REST := "rest"
const NODE_BOSS := "boss"
const NODE_CHEST := "chest"
const NODE_ELITE := "elite"

const NODES_PER_FLOOR := 17
const FLOOR_COUNT := 3

var nodes: Array[Dictionary] = []
var current_index: int = 0
var selected_index: int = 0

func setup_fixed_route() -> void:
	nodes = []
	for f in range(FLOOR_COUNT):
		nodes.append_array(_build_floor_nodes(f))
	current_index = 0
	selected_index = 0
	_emit_selection()

func get_nodes_per_floor() -> int:
	return NODES_PER_FLOOR

func get_floor_count() -> int:
	return FLOOR_COUNT

func get_floor_index_for_global(index: int) -> int:
	return int(index / NODES_PER_FLOOR)

func get_current_floor_index() -> int:
	return get_floor_index_for_global(current_index)

func get_current_floor_number() -> int:
	return get_current_floor_index() + 1

func get_current_node_index_in_floor() -> int:
	return current_index % NODES_PER_FLOOR

func get_current_node_number_in_floor() -> int:
	return get_current_node_index_in_floor() + 1

func get_selected_floor_index() -> int:
	return get_floor_index_for_global(selected_index)

func get_selected_node_index_in_floor() -> int:
	return selected_index % NODES_PER_FLOOR

func get_floor_nodes(floor_index: int) -> Array[Dictionary]:
	var start: int = floor_index * NODES_PER_FLOOR
	var end: int = min(nodes.size(), start + NODES_PER_FLOOR)
	if start >= end:
		return []
	return nodes.slice(start, end)

func _build_floor_nodes(floor_index: int) -> Array[Dictionary]:
	var rest_data := {
		"text1": "火堆发出微弱的噼啪声。\n你可以稍作休整，或整理一下弹匣。",
		"text2": "你收拾好行装，准备继续上路。",
	}
	var pool_b := "B类事件"
	var out: Array[Dictionary] = []
	out.append(_decorate_node({"type": NODE_EVENT, "name": "事件A", "event_pool": pool_b}, floor_index, 0))
	out.append(_decorate_node({"type": NODE_BATTLE, "name": "小怪（弱）", "enemy_pool": "小怪（弱）"}, floor_index, 1))
	out.append(_decorate_node({"type": NODE_EVENT, "name": "事件B", "event_pool": pool_b}, floor_index, 2))
	out.append(_decorate_node({"type": NODE_BATTLE, "name": "小怪（弱）", "enemy_pool": "小怪（弱）"}, floor_index, 3))
	out.append(_decorate_node({"type": NODE_REST, "name": "火堆", "rest": rest_data}, floor_index, 4))
	out.append(_decorate_node({"type": NODE_BATTLE, "name": "小怪（弱）", "enemy_pool": "小怪（弱）"}, floor_index, 5))
	out.append(_decorate_node({"type": NODE_CHEST, "name": "宝箱"}, floor_index, 6))
	out.append(_decorate_node({"type": NODE_BATTLE, "name": "小怪（强）", "enemy_pool": "小怪（强）"}, floor_index, 7))
	out.append(_decorate_node({"type": NODE_EVENT, "name": "事件C", "event_pool": pool_b}, floor_index, 8))
	out.append(_decorate_node({"type": NODE_REST, "name": "火堆", "rest": rest_data}, floor_index, 9))
	out.append(_decorate_node({"type": NODE_BATTLE, "name": "小怪（强）", "enemy_pool": "小怪（强）"}, floor_index, 10))
	out.append(_decorate_node({"type": NODE_EVENT, "name": "事件B", "event_pool": pool_b}, floor_index, 11))
	out.append(_decorate_node({"type": NODE_BATTLE, "name": "小怪（强）", "enemy_pool": "小怪（强）"}, floor_index, 12))
	out.append(_decorate_node({"type": NODE_SHOP, "name": "商店"}, floor_index, 13))
	out.append(_decorate_node({"type": NODE_ELITE, "name": "精英", "enemy_pool": "小怪（强）"}, floor_index, 14))
	out.append(_decorate_node({"type": NODE_REST, "name": "火堆", "rest": rest_data}, floor_index, 15))
	out.append(_decorate_node({"type": NODE_BOSS, "name": "Boss"}, floor_index, 16))
	return out

func _decorate_node(src: Dictionary, floor_index: int, index_in_floor: int) -> Dictionary:
	var d: Dictionary = src.duplicate(true)
	d["floor"] = floor_index
	d["index_in_floor"] = index_in_floor
	d["global_index"] = floor_index * NODES_PER_FLOOR + index_in_floor
	return d

func get_last_index() -> int:
	return max(0, nodes.size() - 1)

func get_selected_node() -> Dictionary:
	if nodes.is_empty():
		return {}
	return nodes[selected_index]

func get_current_node() -> Dictionary:
	if nodes.is_empty():
		return {}
	return nodes[current_index]

func get_selectable_max_index() -> int:
	return min(get_last_index(), current_index + 1)

func can_select(index: int) -> bool:
	return index >= 0 and index <= get_selectable_max_index()

func select_index(index: int) -> void:
	if not can_select(index):
		return
	selected_index = index
	_emit_selection()

func select_prev() -> void:
	select_index(selected_index - 1)

func select_next() -> void:
	select_index(selected_index + 1)

func enter_selected() -> void:
	if nodes.is_empty():
		return
	if selected_index != current_index:
		return
	entered_node.emit(nodes[current_index], current_index)

func complete_current_and_advance() -> bool:
	if nodes.is_empty():
		return false
	if current_index >= get_last_index():
		route_finished.emit()
		return false
	current_index += 1
	selected_index = current_index
	_emit_selection()
	return true

func _emit_selection() -> void:
	if nodes.is_empty():
		return
	selection_changed.emit(nodes[selected_index], selected_index, current_index)
