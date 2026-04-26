extends Node

var _ui: Node
var _db: EventDatabase
var _card_db: CardDatabase
var _rng := RandomNumberGenerator.new()

var _run: RunContext
var _active_event_id: String = ""
var _active_event: Dictionary = {}
var _state: String = ""
var _gift_card_id: String = ""
var _exam_reward_cards: Array[Dictionary] = []
var _pending_card_id: String = ""

func _ready() -> void:
	_ui = get_parent().get_node("UIController")
	_db = EventDatabase.load_default()
	_card_db = CardDatabase.load_default()
	_ui.event_option_selected.connect(_on_event_option_selected)
	_ui.event_continue_pressed.connect(_on_event_continue_pressed)
	_ui.event_remove_bullet_selected.connect(_on_remove_bullet_selected)
	_ui.event_remove_bullet_cancelled.connect(_on_remove_bullet_cancelled)
	_ui.event_add_to_wheel_selected.connect(_on_event_add_to_wheel_selected)
	_ui.event_add_to_wheel_cancelled.connect(_on_event_add_to_wheel_cancelled)

func begin_random_event(run: RunContext, pool: String) -> void:
	if not _db:
		_db = EventDatabase.load_default()
	if not _db:
		return
	var ids: Array[String] = []
	for id in _db.get_all_ids():
		var e: Dictionary = _db.get_event(id)
		if String(e.get("random_pool", "通用")) != pool:
			continue
		if run and run.has_seen_event(String(id)):
			continue
		ids.append(id)
	if ids.is_empty():
		_begin_empty_event(run, pool)
		return
	begin_event(run, String(ids[_rng.randi_range(0, ids.size() - 1)]))

func begin_event(run: RunContext, event_id: String) -> void:
	_run = run
	_active_event_id = event_id
	_active_event = _db.get_event(event_id) if _db else {}
	_state = "root"
	_gift_card_id = ""
	_exam_reward_cards = []
	_pending_card_id = ""
	if _run and not _active_event_id.is_empty() and not _active_event_id.begins_with("__"):
		_run.mark_event_seen(_active_event_id)
	if _active_event_id == "gift":
		_gift_card_id = _roll_gift_card_id()
	var name := String(_active_event.get("name", "事件"))
	var text1 := String(_active_event.get("text1", ""))
	if _active_event_id == "gift" and not _gift_card_id.is_empty() and _card_db:
		var c: Dictionary = _card_db.get_card(_gift_card_id)
		var cn := String(c.get("name", _gift_card_id))
		text1 = "%s\n\n赠品：%s" % [text1, cn]
	var options: Array = _active_event.get("options", [])
	var node := {
		"type": "event",
		"name": name,
		"event": {"text": text1, "options": _sanitize_options(options)},
	}
	_ui.show_event_node(node, _run)

func _begin_empty_event(run: RunContext, pool: String) -> void:
	_run = run
	_active_event_id = "__empty__"
	_active_event = {"text2": ""}
	_state = "root"
	_gift_card_id = ""
	_exam_reward_cards = []
	_pending_card_id = ""
	var node := {
		"type": "event",
		"name": "事件",
		"event": {
			"text": "这一片区域已经没有更多事件了。\n（随机池：%s）" % pool,
			"options": [{"id": "ok", "text": "继续"}],
		},
	}
	_ui.show_event_node(node, _run)

func _sanitize_options(options: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for x in options:
		if typeof(x) != TYPE_DICTIONARY:
			continue
		var o: Dictionary = x
		out.append({"id": String(o.get("id", "")), "text": String(o.get("text", ""))})
	return out

func _on_event_continue_pressed() -> void:
	if _active_event_id.is_empty():
		return
	_active_event_id = ""
	_active_event = {}
	_state = ""
	_run = null
	_gift_card_id = ""
	_exam_reward_cards = []
	_pending_card_id = ""

func _on_event_option_selected(option_id: String) -> void:
	if _active_event_id.is_empty():
		return
	if not _run:
		return
	if _active_event_id == "__empty__":
		_ui.event_show_result("")
		return
	if _active_event_id == "ammo_recycler":
		_handle_ammo_recycler(option_id)
		return
	if _active_event_id == "exam_dummy":
		_handle_exam_dummy(option_id)
		return
	if _active_event_id == "gift":
		_handle_gift(option_id)
		return
	_ui.event_show_result(String(_active_event.get("text2", "")))

func _handle_ammo_recycler(option_id: String) -> void:
	if option_id != "delete_bullet":
		_ui.event_show_result(String(_active_event.get("text2", "")))
		return
	_state = "ammo_wait_remove"
	_ui.show_event_remove_bullet(_run)

func _on_remove_bullet_selected(wheel_index: int, entry_index: int) -> void:
	if _active_event_id != "ammo_recycler":
		return
	if _state != "ammo_wait_remove":
		return
	if not _run:
		return
	_run.remove_card_from_wheel(wheel_index, entry_index)
	_state = "done"
	_ui.event_show_result(String(_active_event.get("text2", "")))

func _on_remove_bullet_cancelled() -> void:
	if _active_event_id != "ammo_recycler":
		return
	if _state != "ammo_wait_remove":
		return
	_state = "root"
	var options: Array = _active_event.get("options", [])
	_ui.event_show_options(_sanitize_options(options))

func _handle_exam_dummy(option_id: String) -> void:
	if _state == "exam_pick_reward":
		_handle_exam_reward_pick(option_id)
		return
	if option_id == "take_gold":
		_run.add_gold(5)
		_ui.set_header("data", _run.gold)
		_ui.event_show_result("你拿走了5金币。")
		return
	if option_id != "roll_test":
		_ui.event_show_result(String(_active_event.get("text2", "")))
		return
	var dmg := _simulate_roll_damage(_run)
	if dmg > 20:
		_exam_reward_cards = _roll_weighted_cards(3, ["white", "blue", "gold"])
		var opts: Array[Dictionary] = []
		for c in _exam_reward_cards:
			var cid := String(c.get("id", ""))
			var name := String(c.get("name", cid))
			var rarity := String(c.get("rarity", "white"))
			opts.append({"id": "pick:%s" % cid, "text": name, "rarity": rarity})
		opts.append({"id": "skip_reward", "text": "跳过"})
		_state = "exam_pick_reward"
		_ui.event_play_text_then_options("考核伤害 %d（>20）\n选择一张奖励：" % dmg, opts)
	else:
		_ui.event_show_result("考核伤害 %d（≤20）\n无事发生。" % dmg)

func _handle_exam_reward_pick(option_id: String) -> void:
	if option_id == "skip_reward":
		_state = "done"
		_ui.event_show_result(String(_active_event.get("text2", "")))
		return
	if option_id.begins_with("pick:"):
		_pending_card_id = option_id.trim_prefix("pick:")
		_state = "exam_pick_wheel"
		_ui.show_event_add_card_to_wheel(_pending_card_id, true)
		return
	_ui.event_show_options([])

func _handle_gift(option_id: String) -> void:
	if option_id == "skip":
		_ui.event_show_result(String(_active_event.get("text2", "")))
		return
	if option_id != "take":
		_ui.event_show_result(String(_active_event.get("text2", "")))
		return
	if _gift_card_id.is_empty():
		_ui.event_show_result(String(_active_event.get("text2", "")))
		return
	_pending_card_id = _gift_card_id
	_state = "gift_pick_wheel"
	_ui.show_event_add_card_to_wheel(_pending_card_id, true)

func _on_event_add_to_wheel_selected(card_id: String, wheel_index: int) -> void:
	if _active_event_id.is_empty():
		return
	if not _run:
		return
	if card_id.is_empty():
		return
	if not _run.add_card_to_wheel(card_id, wheel_index):
		_ui.show_event_add_card_to_wheel(card_id, true)
		return
	_pending_card_id = ""
	_state = "done"
	_ui.event_show_result(String(_active_event.get("text2", "")))

func _on_event_add_to_wheel_cancelled() -> void:
	if _active_event_id.is_empty():
		return
	if _active_event_id == "gift":
		_pending_card_id = ""
		_state = "root"
		var options: Array = _active_event.get("options", [])
		_ui.event_show_options(_sanitize_options(options))
		return
	if _active_event_id == "exam_dummy" and _state == "exam_pick_wheel":
		_pending_card_id = ""
		_state = "exam_pick_reward"
		var opts: Array[Dictionary] = []
		for c in _exam_reward_cards:
			var cid := String(c.get("id", ""))
			var name := String(c.get("name", cid))
			var rarity := String(c.get("rarity", "white"))
			opts.append({"id": "pick:%s" % cid, "text": name, "rarity": rarity})
		opts.append({"id": "skip_reward", "text": "跳过"})
		_ui.event_show_options(opts)
		return

func _roll_gift_card_id() -> String:
	if not _card_db:
		return ""
	var blue: Array[String] = []
	var gold: Array[String] = []
	for id in _card_db.get_all_ids():
		var c: Dictionary = _card_db.get_card(id)
		if String(c.get("random_pool", "")) != "漫游枪手":
			continue
		var r := String(c.get("rarity", "white"))
		if r == "blue":
			blue.append(id)
		elif r == "gold":
			gold.append(id)
	if blue.is_empty() and gold.is_empty():
		return ""
	var pick_blue: bool = _rng.randi_range(0, 12) != 12
	if pick_blue and not blue.is_empty():
		return blue[_rng.randi_range(0, blue.size() - 1)]
	if not pick_blue and not gold.is_empty():
		return gold[_rng.randi_range(0, gold.size() - 1)]
	if not blue.is_empty():
		return blue[_rng.randi_range(0, blue.size() - 1)]
	return gold[_rng.randi_range(0, gold.size() - 1)]

func _roll_weighted_cards(count: int, allowed_rarities: Array[String]) -> Array[Dictionary]:
	if not _card_db:
		return []
	var white_ids: Array[String] = []
	var blue_ids: Array[String] = []
	var gold_ids: Array[String] = []
	for id in _card_db.get_all_ids():
		var c: Dictionary = _card_db.get_card(id)
		if String(c.get("random_pool", "")) != "漫游枪手":
			continue
		var r := String(c.get("rarity", "white"))
		if allowed_rarities.has(r):
			if r == "gold":
				gold_ids.append(id)
			elif r == "blue":
				blue_ids.append(id)
			else:
				white_ids.append(id)
	var out: Array[Dictionary] = []
	var target_count: int = int(min(count, white_ids.size() + blue_ids.size() + gold_ids.size()))
	while out.size() < target_count:
		var picked := _pick_weighted_by_rarity(white_ids, blue_ids, gold_ids)
		if picked.is_empty():
			break
		out.append(_card_db.get_card(picked))
	return out

func _pick_weighted_by_rarity(white_ids: Array[String], blue_ids: Array[String], gold_ids: Array[String]) -> String:
	var total: int = 0
	if not white_ids.is_empty():
		total += 20
	if not blue_ids.is_empty():
		total += 12
	if not gold_ids.is_empty():
		total += 1
	if total <= 0:
		return ""
	var r: int = _rng.randi_range(0, total - 1)
	if not white_ids.is_empty():
		if r < 20:
			return _pop_random_id(white_ids)
		r -= 20
	if not blue_ids.is_empty():
		if r < 12:
			return _pop_random_id(blue_ids)
		r -= 12
	if not gold_ids.is_empty():
		return _pop_random_id(gold_ids)
	return ""

func _pop_random_id(ids: Array[String]) -> String:
	if ids.is_empty():
		return ""
	var idx: int = _rng.randi_range(0, ids.size() - 1)
	var id := String(ids[idx])
	ids.remove_at(idx)
	return id

func _simulate_roll_damage(run: RunContext) -> int:
	if not run or not _card_db:
		return 0
	var total := 0
	for w in run.get_wheels_snapshot():
		var size := 0
		if typeof(w) == TYPE_ARRAY:
			size = (w as Array).size()
		elif typeof(w) == TYPE_PACKED_STRING_ARRAY:
			size = (w as PackedStringArray).size()
		if size <= 0:
			continue
		var idx := _rng.randi_range(0, size - 1)
		var card_id := String(w[idx])
		total += _get_simple_damage(card_id)
	return total

func _get_simple_damage(card_id: String) -> int:
	if card_id.is_empty() or not _card_db:
		return 0
	var c: Dictionary = _card_db.get_card(card_id)
	var path := String(c.get("script", ""))
	if path.is_empty():
		return 0
	var s: Script = load(path) as Script
	if not s or not s.has_method("get_effect"):
		return 0
	var eff: Variant = s.call("get_effect")
	if typeof(eff) != TYPE_DICTIONARY:
		return 0
	return int((eff as Dictionary).get("damage", 0))
