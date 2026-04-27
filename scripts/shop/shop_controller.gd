extends Node

signal shop_started(cards: Array[Dictionary])

const ACTIVE_RANDOM_POOL := "漫游枪手"
const WEIGHT_WHITE: int = 20
const WEIGHT_BLUE: int = 12
const WEIGHT_GOLD: int = 1

var _rng := RandomNumberGenerator.new()

var _db: CardDatabase
var _ui: Node
var _run: RunContext

var _cards: Array[Dictionary] = []
var _pending_card_id: String = ""
var _pending_price: int = 0

func _ready() -> void:
	_ui = get_parent().get_node("UIController")
	_db = CardDatabase.load_default()
	if _ui:
		_ui.shop_buy_pressed.connect(_on_shop_buy_pressed)
		_ui.event_add_to_wheel_selected.connect(_on_event_add_to_wheel_selected)
		_ui.event_add_to_wheel_cancelled.connect(_on_event_add_to_wheel_cancelled)

func begin_shop(run: RunContext, _node: Dictionary = {}) -> void:
	_run = run
	_pending_card_id = ""
	_pending_price = 0
	_cards = _roll_shop_cards(5)
	for i in range(_cards.size()):
		var c: Dictionary = _cards[i]
		var rarity := String(c.get("rarity", "white"))
		var price := _roll_price_for_rarity(rarity)
		c["shop_price"] = price
		c["shop_sold"] = false
		_cards[i] = c
	if _ui:
		_ui.show_shop(_cards, _run)
	shop_started.emit(_cards)

func _roll_shop_cards(count: int) -> Array[Dictionary]:
	if not _db:
		_db = CardDatabase.load_default()
	if not _db:
		return []
	var white_ids: Array[String] = []
	var blue_ids: Array[String] = []
	var gold_ids: Array[String] = []
	for id in _db.get_all_ids():
		var card: Dictionary = _db.get_card(id)
		if String(card.get("random_pool", "")) != ACTIVE_RANDOM_POOL:
			continue
		var r := String(card.get("rarity", "white"))
		if r == "gold":
			gold_ids.append(id)
		elif r == "blue":
			blue_ids.append(id)
		else:
			white_ids.append(id)
	if white_ids.is_empty() and blue_ids.is_empty() and gold_ids.is_empty():
		return []
	var picked: Array[String] = []
	var target_count: int = int(min(count, white_ids.size() + blue_ids.size() + gold_ids.size()))
	while picked.size() < target_count:
		var id := _pick_weighted_by_rarity(white_ids, blue_ids, gold_ids)
		if id.is_empty():
			break
		picked.append(id)
	var out: Array[Dictionary] = []
	for id in picked:
		out.append(_db.get_card(id))
	return out

func _pick_weighted_by_rarity(white_ids: Array[String], blue_ids: Array[String], gold_ids: Array[String]) -> String:
	var total: int = 0
	if not white_ids.is_empty():
		total += WEIGHT_WHITE
	if not blue_ids.is_empty():
		total += WEIGHT_BLUE
	if not gold_ids.is_empty():
		total += WEIGHT_GOLD
	if total <= 0:
		return ""
	var r: int = _rng.randi_range(0, total - 1)
	if not white_ids.is_empty():
		if r < WEIGHT_WHITE:
			return _pop_random_id(white_ids)
		r -= WEIGHT_WHITE
	if not blue_ids.is_empty():
		if r < WEIGHT_BLUE:
			return _pop_random_id(blue_ids)
		r -= WEIGHT_BLUE
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

func _roll_price_for_rarity(rarity: String) -> int:
	if rarity == "gold":
		return _rng.randi_range(90, 110)
	if rarity == "blue":
		return _rng.randi_range(25, 35)
	return _rng.randi_range(15, 20)

func _on_shop_buy_pressed(card_id: String, price: int) -> void:
	if not _run or not _ui:
		return
	if card_id.is_empty() or price <= 0:
		return
	if _pending_card_id != "":
		return
	if _run.gold < price:
		_ui.shop_show_hint("金币不足。")
		return
	var entry := _find_shop_entry(card_id)
	if entry.is_empty() or bool(entry.get("shop_sold", false)):
		return
	_pending_card_id = card_id
	_pending_price = price
	_ui.shop_set_leave_allowed(false)
	_ui.show_event_add_card_to_wheel(card_id, true)

func _on_event_add_to_wheel_selected(card_id: String, wheel_index: int) -> void:
	if not _run or not _ui:
		return
	if _pending_card_id.is_empty():
		return
	if card_id != _pending_card_id:
		return
	var price := _pending_price
	if _run.gold < price:
		_pending_card_id = ""
		_pending_price = 0
		_ui.shop_set_leave_allowed(true)
		_ui.shop_show_hint("金币不足。")
		_ui.refresh_shop(_cards, _run)
		return
	var err := _run.get_add_card_to_wheel_error(card_id, wheel_index)
	if not err.is_empty():
		_ui.shop_set_leave_allowed(false)
		_ui.show_event_add_card_to_wheel(card_id, true)
		if _ui.has_method("reward_show_hint"):
			_ui.reward_show_hint(_wheel_add_error_to_text(err))
		return
	if not _run.add_card_to_wheel(card_id, wheel_index):
		_ui.shop_set_leave_allowed(false)
		_ui.show_event_add_card_to_wheel(card_id, true)
		if _ui.has_method("reward_show_hint"):
			_ui.reward_show_hint(_wheel_add_error_to_text("unknown"))
		return
	_run.add_gold(-price)
	_ui.set_header("data", _run.gold)
	for i in range(_cards.size()):
		var c: Dictionary = _cards[i]
		if String(c.get("id", "")) == card_id:
			c["shop_sold"] = true
			_cards[i] = c
			break
	_pending_card_id = ""
	_pending_price = 0
	_ui.shop_set_leave_allowed(true)
	_ui.shop_show_hint("购买成功。")
	_ui.refresh_shop(_cards, _run)

func _wheel_add_error_to_text(err: String) -> String:
	if err == "must_be_last_unlocked_wheel":
		return "该子弹只能加入最后一个未锁定弹匣。"
	if err == "wheel_locked":
		return "该弹匣已锁定。"
	if err == "no_unlocked_wheel":
		return "没有可加入的弹匣。"
	return "无法加入该弹匣。"

func _on_event_add_to_wheel_cancelled() -> void:
	if not _ui:
		return
	if _pending_card_id.is_empty():
		return
	_pending_card_id = ""
	_pending_price = 0
	_ui.shop_set_leave_allowed(true)
	_ui.shop_show_hint("")
	_ui.refresh_shop(_cards, _run)

func _find_shop_entry(card_id: String) -> Dictionary:
	for c in _cards:
		if String(c.get("id", "")) == card_id:
			return c
	return {}
