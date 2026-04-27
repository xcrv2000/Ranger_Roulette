extends Node

signal rewards_started(gold_gained: int, card_options: Array[Dictionary])
signal rewards_finished

const ACTIVE_RANDOM_POOL := "漫游枪手"
const WEIGHT_WHITE: int = 20
const WEIGHT_BLUE: int = 12
const WEIGHT_GOLD: int = 1

var _rng := RandomNumberGenerator.new()

var _db: CardDatabase
var _ui: Node
var _run: RunContext

var _selected_card_id: String = ""
var _card_options: Array[Dictionary] = []

func _ready() -> void:
	_ui = get_parent().get_node("UIController")
	_db = CardDatabase.load_default()
	_ui.reward_skip_pressed.connect(_on_reward_skip_pressed)
	_ui.reward_add_to_wheel_pressed.connect(_on_reward_add_to_wheel_pressed)

func begin_battle_rewards(run: RunContext) -> void:
	_run = run
	_selected_card_id = ""
	_card_options = _roll_card_options(3)
	var gold_gained := _rng.randi_range(12, 15)
	_run.add_gold(gold_gained)
	_ui.set_header("data", _run.gold)
	_ui.show_battle_rewards(gold_gained, _card_options, "+%d 金币" % gold_gained)
	rewards_started.emit(gold_gained, _card_options)

func begin_extra_card_rewards(run: RunContext, count: int = 3) -> void:
	_run = run
	_selected_card_id = ""
	_card_options = _roll_card_options(count)
	_ui.show_battle_rewards(0, _card_options, "额外奖励")
	rewards_started.emit(0, _card_options)

func _roll_card_options(count: int) -> Array[Dictionary]:
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

func _on_reward_skip_pressed() -> void:
	_ui.hide_battle_rewards()
	rewards_finished.emit()

func _on_reward_add_to_wheel_pressed(card_id: String, wheel_index: int) -> void:
	if not _run:
		return
	if card_id.is_empty():
		return
	var err := _run.get_add_card_to_wheel_error(card_id, wheel_index)
	if not err.is_empty():
		if _ui and _ui.has_method("reward_show_hint"):
			_ui.reward_show_hint(_wheel_add_error_to_text(err))
		return
	if _run.add_card_to_wheel(card_id, wheel_index):
		_ui.hide_battle_rewards()
		rewards_finished.emit()

func _wheel_add_error_to_text(err: String) -> String:
	if err == "must_be_last_unlocked_wheel":
		return "该子弹只能加入最后一个未锁定弹匣。"
	if err == "wheel_locked":
		return "该弹匣已锁定。"
	if err == "no_unlocked_wheel":
		return "没有可加入的弹匣。"
	return "无法加入该弹匣。"
