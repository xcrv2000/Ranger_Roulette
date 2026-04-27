extends Node

signal new_game_pressed
signal select_prev_pressed
signal select_next_pressed
signal select_index_pressed(index: int)
signal enter_node_pressed
signal battle_action_pressed(action_id: String)
signal placeholder_continue_pressed
signal event_option_selected(option_id: String)
signal event_continue_pressed
signal event_remove_bullet_selected(wheel_index: int, entry_index: int)
signal event_remove_bullet_cancelled
signal event_add_to_wheel_selected(card_id: String, wheel_index: int)
signal event_add_to_wheel_cancelled
signal back_to_title_pressed
signal reward_skip_pressed
signal reward_add_to_wheel_pressed(card_id: String, wheel_index: int)
signal shop_buy_pressed(card_id: String, price: int)
signal reflection_remove_selected(wheel_index: int, entry_index: int)
signal reflection_remove_skipped(wheel_index: int)
signal quick_mode_level_changed(level: int)
signal debug_action(action: Dictionary)

const TITLE_SCREEN_SCENE := preload("res://scenes/ui/title_screen.tscn")
const RUN_UI_SCENE := preload("res://scenes/ui/ui_root.tscn")
const END_SCREEN_SCENE := preload("res://scenes/ui/end_screen.tscn")
const NODE_SHARED_ICON := preload("res://icon.svg")

var _screen_root: Node

var _title_screen: Control
var _run_ui: Control
var _end_screen: Control

var _data_label: Label
var _money_label: Label
var _debug_entry: Button
var _debug_panel: Control
var _debug_close: Button
var _debug_quick_check: Button
var _debug_info: Label
var _debug_player_hp: SpinBox
var _debug_enemy_hp: SpinBox
var _debug_apply_player_hp: Button
var _debug_apply_enemy_hp: Button
var _debug_gold: SpinBox
var _debug_apply_gold: Button
var _debug_status_select: OptionButton
var _debug_status_stacks: SpinBox
var _debug_add_player: Button
var _debug_add_enemy: Button
var _debug_clear_player: Button
var _debug_clear_enemy: Button
var _debug_run_state: Dictionary = {}
var _active_run: RunContext

var _debug_tabs: TabContainer
var _debug_wheel_tab: Control
var _debug_wheel_select: OptionButton
var _debug_wheel_card_select: OptionButton
var _debug_wheel_insert_pos: SpinBox
var _debug_wheel_insert_btn: Button
var _debug_wheel_append_btn: Button
var _debug_wheel_delete_btn: Button
var _debug_wheel_up_btn: Button
var _debug_wheel_down_btn: Button
var _debug_wheel_list: VBoxContainer
var _debug_wheel_selected_index: int = -1

var _prev_button: Button
var _next_button: Button
var _enter_button: Button
var _node_buttons: Array[Button] = []
var _nodes_viewport: Control
var _nodes_row: HBoxContainer
var _map_row_tween: Tween

var _slot_labels: Array[Label] = []
var _slot_panels: Array[Control] = []
var _slot_bar: Control
var _slot_rich_labels: Array[RichTextLabel] = []
var _last_wheel_count: int = 3
var _last_slot_pools: Array = []
var _slot_detail_layer: Control
var _slot_detail_title: Label
var _slot_detail_text: RichTextLabel
var _quick_toggle: Button
var _quick_mode_level: int = 0

var _stage_label: Label

var _battle_panel: Control
var _battle_status: Label
var _battle_action_buttons: Array[Button] = []
var _lane_slots: Array[Control] = []
var _battle_overlay: Control
var _player_token: TextureRect
var _player_token_default_texture: Texture2D
var _player_token_hat_lost_texture: Texture2D
var _enemy_token: Control
var _last_player_cell: int = 0
var _token_layout_scheduled: bool = false
var _token_layout_retry: int = 0

var _content_panel: Control
var _content_title: Label
var _content_body: Label
var _content_primary: Button

var _event_layer: Control
var _event_text: RichTextLabel
var _event_options_box: VBoxContainer
var _event_continue_button: Button
var _event_layout_scheduled: bool = false
var _event_layout_retry: int = 0
var _event_sequence_id: int = 0
var _event_current_seq_id: int = 0
var _event_choice_msec: int = 0

var _event_remove_layer: Control
var _event_remove_run: RunContext
var _event_remove_columns: HBoxContainer
var _event_remove_back: Button

var _reward_panel: Control
var _reward_gold_label: Label
var _reward_card_buttons: Array[Button] = []
var _reward_skip_button: Button
var _reward_detail_layer: Control
var _reward_backdrop: Button
var _reward_selected_icon: TextureRect
var _reward_name_label: Label
var _reward_text_label: Label
var _reward_slot_buttons: Array[Button] = []
var _reward_slot_row: Control
var _reward_selected_card_id: String = ""
var _event_reward_pick_card_id: String = ""
var _event_reward_pick_show_cancel: bool = false

var _leave_button: Button
var _leave_allowed: bool = true

var _shop_panel: Control
var _shop_hint_label: Label
var _shop_card_buttons: Array[Button] = []
var _shop_price_labels: Array[Label] = []
var _shop_suspended_for_pick: bool = false

var _reflection_layer: Control
var _reflection_title: Label
var _reflection_list: VBoxContainer
var _reflection_skip_button: Button
var _reflection_wheel_index: int = -1

var _card_db: CardDatabase

func show_title() -> void:
	if not _screen_root:
		_screen_root = get_parent().get_node("ScreenRoot")
	_clear_screen_root()
	_title_screen = TITLE_SCREEN_SCENE.instantiate()
	_screen_root.add_child(_title_screen)
	var new_button: Button = _title_screen.get_node("CenterButtons/NewButton")
	new_button.pressed.connect(func() -> void: new_game_pressed.emit())

func show_run_ui() -> void:
	if not _screen_root:
		_screen_root = get_parent().get_node("ScreenRoot")
	_clear_screen_root()
	_run_ui = RUN_UI_SCENE.instantiate()
	_screen_root.add_child(_run_ui)
	_cache_run_ui_nodes()
	_wire_run_ui_signals()
	_set_quick_mode_level(0)
	_set_debug_panel_visible(false)
	if _enter_button:
		_enter_button.visible = false
	if _prev_button:
		_prev_button.visible = false
	if _next_button:
		_next_button.visible = false

func show_end(title: String = "胜利（占位）", body: String = "本局流程已跑通：封面 → 节点推进 → 战斗占位 → 结束。") -> void:
	if not _screen_root:
		_screen_root = get_parent().get_node("ScreenRoot")
	_clear_screen_root()
	_end_screen = END_SCREEN_SCENE.instantiate()
	_screen_root.add_child(_end_screen)
	var title_label: Label = _end_screen.get_node("Center/TitleLabel")
	var body_label: Label = _end_screen.get_node("Center/BodyLabel")
	title_label.text = title
	body_label.text = body
	var back_button: Button = _end_screen.get_node("Center/CenterButtons/BackButton")
	back_button.pressed.connect(func() -> void: back_to_title_pressed.emit())

func set_header(data_text: String, gold: int) -> void:
	if _data_label:
		if not data_text.is_empty() and data_text != "data":
			_data_label.text = data_text
	if _money_label:
		_money_label.text = "$ %d" % gold
	_debug_run_state["gold"] = gold
	_refresh_debug_panel(_debug_run_state, {})

func set_debug_run_state(state: Dictionary) -> void:
	_debug_run_state = state
	_refresh_debug_panel(_debug_run_state, {})
	_refresh_wheel_editor()

func set_active_run(run: RunContext) -> void:
	_active_run = run
	_refresh_wheel_editor()

func render_map(nodes: Array[Dictionary], selected_index: int, current_index: int, base_global_index: int, current_global_index: int) -> void:
	if not _nodes_row:
		return
	_ensure_map_node_buttons(nodes.size())
	for i in range(_node_buttons.size()):
		var btn: Button = _node_buttons[i]
		var global_index: int = base_global_index + i
		btn.set_meta("map_index", global_index)
		var node: Dictionary = nodes[i]
		var name_text: String = String(node.get("name", "节点"))
		var icon_rect: TextureRect = btn.get_node_or_null("Box/Icon") as TextureRect
		if icon_rect:
			icon_rect.texture = NODE_SHARED_ICON
		var name_label: Label = btn.get_node_or_null("Box/Name") as Label
		if name_label:
			name_label.text = name_text
		else:
			btn.text = name_text

		btn.disabled = global_index > (current_global_index + 1)
		if current_index >= 0 and i == current_index:
			btn.modulate = Color(0.55, 0.85, 0.55)
		elif i == selected_index:
			btn.modulate = Color(0.95, 0.9, 0.6)
		elif global_index < current_global_index:
			btn.modulate = Color(0.75, 0.75, 0.75)
		else:
			btn.modulate = Color(1, 1, 1)

	var focus_index: int = current_index if current_index >= 0 else selected_index
	call_deferred("_center_map_row_on_index", focus_index)
	_render_stage_text("map")

func _ensure_map_node_buttons(count: int) -> void:
	if not _nodes_row:
		return
	while _node_buttons.size() < count:
		var btn: Button = _create_map_node_button()
		_nodes_row.add_child(btn)
		_node_buttons.append(btn)
		var b := btn
		b.pressed.connect(func() -> void:
			var idx := int(b.get_meta("map_index", -1))
			if idx < 0:
				return
			select_index_pressed.emit(idx)
		)
	while _node_buttons.size() > count:
		var btn: Button = _node_buttons.pop_back()
		if btn and is_instance_valid(btn):
			btn.queue_free()

func _create_map_node_button() -> Button:
	var btn: Button = Button.new()
	btn.custom_minimum_size = Vector2(220, 64)
	btn.text = ""
	btn.focus_mode = Control.FOCUS_NONE
	btn.disabled = true
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	var box: HBoxContainer = HBoxContainer.new()
	box.name = "Box"
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(box)
	var icon_rect: TextureRect = TextureRect.new()
	icon_rect.name = "Icon"
	icon_rect.custom_minimum_size = Vector2(64, 64)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(icon_rect)
	var name_label: Label = Label.new()
	name_label.name = "Name"
	name_label.vertical_alignment = VerticalAlignment.VERTICAL_ALIGNMENT_CENTER
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(name_label)
	return btn

func _center_map_row_on_index(index: int) -> void:
	if not _nodes_viewport or not _nodes_row:
		return
	if index < 0 or index >= _node_buttons.size():
		return
	var viewport_w := _nodes_viewport.size.x
	var content_w := _nodes_row.size.x
	if viewport_w <= 0.0 or content_w <= viewport_w:
		_nodes_row.position.x = 0.0
		return
	var btn: Button = _node_buttons[index]
	var btn_center := btn.position.x + (btn.size.x * 0.5)
	var target_x := (viewport_w * 0.5) - btn_center
	target_x = clampf(target_x, viewport_w - content_w, 0.0)
	if _map_row_tween and _map_row_tween.is_running():
		_map_row_tween.kill()
	_map_row_tween = create_tween()
	_map_row_tween.tween_property(_nodes_row, "position:x", target_x, 0.18)

func show_node_content(node: Dictionary) -> void:
	if not _content_panel:
		return

	var t := String(node.get("type", ""))
	var name := String(node.get("name", "节点"))

	if t == "battle" or t == "boss":
		show_battle(node, [])
	else:
		hide_shop()
		_hide_event_layer()
		_hide_battle_panel()
		hide_battle_rewards()
		_content_panel.visible = true
		if t == "chest":
			_content_body.text = "%s：宝箱占位内容。\n这里只有一个选项，用于验证流程闭环。" % name
		else:
			_content_body.text = "%s：占位文本。\n这里只有一个选项，用于验证流程闭环。" % name
		_content_title.text = name
		_content_primary.text = "继续"
		_render_stage_text("chest" if t == "chest" else "event")
		_refresh_leave_button()

func show_event_node(node: Dictionary, run: RunContext) -> void:
	hide_shop()
	_hide_battle_panel()
	hide_battle_rewards()
	if _content_panel:
		_content_panel.visible = false
	_render_stage_text("event")
	if _battle_panel:
		_battle_panel.visible = true
	if _battle_overlay:
		_battle_overlay.visible = true
	if _enemy_token:
		_enemy_token.visible = false
	for btn in _battle_action_buttons:
		btn.visible = false
	if _battle_status:
		_battle_status.text = String(node.get("name", "事件"))
	_last_player_cell = 1
	_schedule_token_layout()
	_set_slot_pools_from_run(run)
	_show_event_layer(node)
	_refresh_leave_button()

func show_rest_node(node: Dictionary, run: RunContext) -> void:
	hide_shop()
	_hide_battle_panel()
	hide_battle_rewards()
	if _content_panel:
		_content_panel.visible = false
	_render_stage_text("event")
	if _battle_panel:
		_battle_panel.visible = true
	if _battle_overlay:
		_battle_overlay.visible = true
	if _enemy_token:
		_enemy_token.visible = false
	for btn in _battle_action_buttons:
		btn.visible = false
	if _battle_status:
		_battle_status.text = String(node.get("name", "休息处"))
	_last_player_cell = 1
	_schedule_token_layout()
	_set_slot_pools_from_run(run)
	_show_rest_layer(node, run)
	_refresh_leave_button()

func show_battle(node: Dictionary, actions: Array[Dictionary]) -> void:
	hide_shop()
	var name := String(node.get("name", "战斗"))
	_hide_event_layer()
	_content_panel.visible = false
	hide_battle_rewards()
	_render_stage_text("battle")
	if not _battle_panel:
		return
	_battle_panel.visible = true
	if _enemy_token:
		_enemy_token.visible = true
	if _battle_overlay:
		_battle_overlay.visible = true
	_set_battle_actions(actions)
	_battle_status.text = "%s\n准备开始" % name
	_schedule_token_layout()
	_refresh_leave_button()

func show_battle_rewards(gold_gained: int, cards: Array[Dictionary], banner_text: String = "") -> void:
	hide_shop()
	_hide_event_layer()
	_hide_battle_panel()
	_content_panel.visible = false
	if not _reward_panel:
		return
	_reward_panel.visible = true
	if _reward_gold_label:
		_reward_gold_label.visible = true
	if _reward_skip_button:
		_reward_skip_button.visible = true
	if _run_ui and _run_ui.has_node("BattleRewardPanel/Box/CardRow"):
		(_run_ui.get_node("BattleRewardPanel/Box/CardRow") as Control).visible = true
	_reward_detail_layer.visible = false
	_reward_selected_card_id = ""
	if banner_text.is_empty():
		_reward_gold_label.text = "+%d 金币" % gold_gained
	else:
		_reward_gold_label.text = banner_text
	_set_reward_cards(cards)
	_refresh_leave_button()

func hide_battle_rewards() -> void:
	if _reward_panel:
		_reward_panel.visible = false
	if _reward_detail_layer:
		_reward_detail_layer.visible = false
	_reward_selected_card_id = ""
	_refresh_leave_button()

func show_shop(cards: Array[Dictionary], run: RunContext) -> void:
	_leave_allowed = true
	_shop_suspended_for_pick = false
	_hide_event_layer()
	hide_battle_rewards()
	if _content_panel:
		_content_panel.visible = false
	_render_stage_text("event")
	if _battle_panel:
		_battle_panel.visible = true
	if _battle_overlay:
		_battle_overlay.visible = true
	if _enemy_token:
		_enemy_token.visible = false
	for btn in _battle_action_buttons:
		btn.visible = false
	if _battle_status:
		_battle_status.text = "商店"
	_last_player_cell = 1
	_schedule_token_layout()
	_set_slot_pools_from_run(run)
	if _shop_panel:
		_shop_panel.visible = true
	shop_show_hint("")
	refresh_shop(cards, run)
	_refresh_leave_button()

func refresh_shop(cards: Array[Dictionary], run: RunContext) -> void:
	if _shop_card_buttons.is_empty() or _shop_price_labels.is_empty():
		return
	for i in range(_shop_card_buttons.size()):
		var btn: Button = _shop_card_buttons[i]
		var price_label: Label = _shop_price_labels[i] if i < _shop_price_labels.size() else null
		if i >= cards.size():
			btn.visible = false
			if price_label:
				price_label.visible = false
			continue
		var c: Dictionary = cards[i]
		var id := String(c.get("id", ""))
		var card_name := String(c.get("name", id))
		var icon_path := String(c.get("icon", ""))
		var rarity := String(c.get("rarity", "white"))
		var price := int(c.get("shop_price", 0))
		var sold := bool(c.get("shop_sold", false))
		btn.visible = true
		btn.text = card_name
		btn.set_meta("card_id", id)
		btn.set_meta("shop_price", price)
		btn.set_meta("card_rarity", rarity)
		_apply_rarity_border(btn, rarity)
		btn.icon = null
		if not icon_path.is_empty():
			var tex = load(icon_path)
			if tex is Texture2D:
				btn.icon = tex
		btn.disabled = sold
		var affordable := (run != null and run.gold >= price)
		if sold:
			btn.modulate = Color(1, 1, 1, 0.5)
		elif affordable:
			btn.modulate = Color(1, 1, 1, 1)
		else:
			btn.modulate = Color(0.7, 0.7, 0.7, 1)
		if price_label:
			price_label.visible = true
			if sold:
				price_label.text = "已售"
			else:
				price_label.text = "$ %d" % price
	_refresh_leave_button()

func hide_shop() -> void:
	if _shop_panel:
		_shop_panel.visible = false
	_shop_suspended_for_pick = false
	shop_show_hint("")
	_refresh_leave_button()

func shop_show_hint(text: String) -> void:
	if _shop_hint_label:
		_shop_hint_label.text = text

func shop_set_leave_allowed(allowed: bool) -> void:
	_leave_allowed = allowed
	_refresh_leave_button()

func _on_leave_pressed() -> void:
	if not _leave_button or not _leave_button.visible:
		return
	if _shop_panel and _shop_panel.visible:
		hide_shop()
		event_continue_pressed.emit()
		return
	if _reward_panel and _reward_panel.visible:
		reward_skip_pressed.emit()
		return
	if _event_layer and _event_layer.visible and _event_continue_button and _event_continue_button.visible:
		_on_event_continue_pressed()
		return
	if _content_panel and _content_panel.visible:
		placeholder_continue_pressed.emit()

func _refresh_leave_button() -> void:
	if not _leave_button:
		return
	var show := false
	if not _leave_allowed:
		show = false
	elif _shop_panel and _shop_panel.visible:
		show = true
	elif _reward_panel and _reward_panel.visible and _reward_skip_button and _reward_skip_button.visible and (not _reward_detail_layer or not _reward_detail_layer.visible):
		show = true
	elif _event_layer and _event_layer.visible and _event_continue_button and _event_continue_button.visible:
		show = true
	elif _content_panel and _content_panel.visible:
		show = true
	_leave_button.visible = show

func show_reflection_remove(run: RunContext, wheel_index: int) -> void:
	_hide_event_layer()
	_hide_battle_panel()
	hide_battle_rewards()
	_content_panel.visible = false
	_ensure_reflection_layer()
	_reflection_wheel_index = wheel_index
	_reflection_title.text = "反思：选择一枚子弹移除"
	for c in _reflection_list.get_children():
		c.queue_free()
	if not _card_db:
		_card_db = CardDatabase.load_default()
	if not run or wheel_index < 0 or wheel_index >= run.slot_wheels.size():
		_reflection_title.text = "反思：没有可移除的子弹"
	else:
		var w = run.slot_wheels[wheel_index]
		for i in range(w.size()):
			var id := String(w[i])
			var name := id
			if _card_db:
				var def: Dictionary = _card_db.get_card(id)
				name = String(def.get("name", id))
			var btn := Button.new()
			btn.text = name
			var wi := wheel_index
			var idx := i
			btn.pressed.connect(func() -> void:
				hide_reflection_remove()
				reflection_remove_selected.emit(wi, idx)
			)
			_reflection_list.add_child(btn)
	_reflection_layer.visible = true

func hide_reflection_remove() -> void:
	if _reflection_layer:
		_reflection_layer.visible = false
	_reflection_wheel_index = -1

func _ensure_reflection_layer() -> void:
	if _reflection_layer:
		return
	if not _run_ui:
		return
	_reflection_layer = Control.new()
	_reflection_layer.name = "ReflectionLayer"
	_reflection_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_reflection_layer.visible = false
	_run_ui.add_child(_reflection_layer)

	var backdrop := ColorRect.new()
	backdrop.color = Color(0, 0, 0, 0.6)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_reflection_layer.add_child(backdrop)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.size = Vector2(520, 520)
	panel.position = Vector2(0, 0)
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -260
	panel.offset_top = -260
	panel.offset_right = 260
	panel.offset_bottom = 260
	_reflection_layer.add_child(panel)

	var vb := VBoxContainer.new()
	panel.add_child(vb)

	_reflection_title = Label.new()
	_reflection_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(_reflection_title)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(scroll)

	_reflection_list = VBoxContainer.new()
	_reflection_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_reflection_list)

	_reflection_skip_button = Button.new()
	_reflection_skip_button.text = "跳过"
	_reflection_skip_button.pressed.connect(func() -> void:
		var wi := _reflection_wheel_index
		hide_reflection_remove()
		reflection_remove_skipped.emit(wi)
	)
	vb.add_child(_reflection_skip_button)

func update_battle_state(state: Dictionary) -> void:
	if not _battle_panel or not _battle_panel.visible:
		return
	var turn := int(state.get("turn", 0))
	var phase := String(state.get("phase", ""))
	var player: Dictionary = state.get("player", {})
	var enemies: Array = state.get("enemies", [])
	_last_player_cell = int(player.get("cell", 0))
	_schedule_token_layout()
	var visual: Dictionary = player.get("visual", {})
	var hat_lost := bool(visual.get("hat_lost", false))
	if _player_token:
		if hat_lost:
			if not _player_token_hat_lost_texture:
					var tex: Texture2D = load("res://设计方案/pics/drafts/角色草稿（假目标）.png") as Texture2D
					if tex:
						_player_token_hat_lost_texture = tex
			if _player_token_hat_lost_texture:
				_player_token.texture = _player_token_hat_lost_texture
		elif _player_token_default_texture:
			_player_token.texture = _player_token_default_texture
	var input_state: Dictionary = state.get("input", {})
	var input_locked := bool(input_state.get("locked", false))
	var can_roll := (not input_locked) and phase == "player" and String(input_state.get("stage", "")) == "roll"
	for btn in _battle_action_buttons:
		btn.disabled = not can_roll
	var enemy_hp := 0
	var enemy_cell := 0
	var enemy_intent_text := ""
	var enemy_status_text := ""
	if not enemies.is_empty():
		var e: Dictionary = enemies[0]
		enemy_hp = int(e.get("hp", 0))
		enemy_cell = int(e.get("cell", 0))
		var intent: Dictionary = e.get("intent", {})
		enemy_intent_text = String(intent.get("text", ""))
		var base_damage := int(intent.get("damage", 0))
		var preview_damage := int(intent.get("damage_preview", base_damage))
		if base_damage != 0 or preview_damage != 0:
			enemy_intent_text += "（伤害 %d）" % preview_damage
		enemy_status_text = _summarize_status_array(e.get("statuses", []))
	var player_status_text := _summarize_status_array(player.get("statuses", []))
	var slot_state: Dictionary = state.get("slot", {})
	var active_wheel := int(slot_state.get("active_wheel", -1))
	var is_resolving := bool(slot_state.get("is_resolving", false))
	var roll: Array = slot_state.get("last_roll", [])
	var roll_text := ""
	if not roll.is_empty():
		var roll_ids: Array[String] = []
		for x in roll:
			if typeof(x) == TYPE_DICTIONARY:
				roll_ids.append(String((x as Dictionary).get("id", "")))
			else:
				roll_ids.append(String(x))
		roll_text = "\n老虎机：%s" % " / ".join(roll_ids)
	var wheel_text := "\n高亮轮：-"
	if active_wheel >= 0:
		wheel_text = "\n高亮轮：%d" % (active_wheel + 1)
	if is_resolving:
		wheel_text += "（结算中）"
	var intent_text := ""
	if not enemy_intent_text.is_empty():
		intent_text = "\n敌人意图：%s" % enemy_intent_text
	var status_text := ""
	if not player_status_text.is_empty():
		status_text += "\n玩家状态：%s" % player_status_text
	if not enemy_status_text.is_empty():
		status_text += "\n敌人状态：%s" % enemy_status_text
	_battle_status.text = "回合 %d（%s）\n玩家：HP %d / 格挡 %d / 位置 %d\n敌人：HP %d / 位置 %d" % [
		turn,
		phase,
		int(player.get("hp", 0)),
		int(player.get("block", 0)),
		int(player.get("cell", 0)),
		enemy_hp,
		enemy_cell,
	] + status_text + intent_text + roll_text + wheel_text
	var pools: Array = slot_state.get("pools", [])
	_last_slot_pools = pools
	_last_wheel_count = max(1, pools.size())
	_render_slot_debug(slot_state)
	if _debug_enemy_hp:
		_debug_enemy_hp.value = float(enemy_hp)
	if _debug_player_hp:
		_debug_player_hp.value = float(int(player.get("hp", 0)))
	_refresh_debug_panel(_debug_run_state, state)

func _cache_run_ui_nodes() -> void:
	_data_label = _run_ui.get_node("HUD/TopBar/DataBox/DataLabel")
	_money_label = _run_ui.get_node("HUD/TopBar/MoneyLabel")
	_debug_entry = _run_ui.get_node_or_null("HUD/DebugEntry") as Button
	if not _debug_entry:
		_debug_entry = _run_ui.find_child("DebugEntry", true, false) as Button
	_debug_panel = _run_ui.get_node("HUD/DebugPanel")
	_debug_close = _run_ui.get_node("HUD/DebugPanel/Box/Header/Close")
	_debug_quick_check = _run_ui.get_node("HUD/DebugPanel/Box/QuickRow/QuickCheck")
	_debug_info = _run_ui.get_node("HUD/DebugPanel/Box/InfoLabel")
	_debug_player_hp = _run_ui.get_node("HUD/DebugPanel/Box/HPRow/PlayerHP")
	_debug_enemy_hp = _run_ui.get_node("HUD/DebugPanel/Box/HPRow/EnemyHP")
	_debug_apply_player_hp = _run_ui.get_node("HUD/DebugPanel/Box/HPRow/ApplyPlayerHP")
	_debug_apply_enemy_hp = _run_ui.get_node("HUD/DebugPanel/Box/HPRow/ApplyEnemyHP")
	_debug_status_select = _run_ui.get_node("HUD/DebugPanel/Box/StatusRow/StatusSelect")
	_debug_status_stacks = _run_ui.get_node("HUD/DebugPanel/Box/StatusRow/Stacks")
	_debug_add_player = _run_ui.get_node("HUD/DebugPanel/Box/StatusRow/AddPlayer")
	_debug_add_enemy = _run_ui.get_node("HUD/DebugPanel/Box/StatusRow/AddEnemy")
	_debug_clear_player = _run_ui.get_node("HUD/DebugPanel/Box/ClearRow/ClearPlayer")
	_debug_clear_enemy = _run_ui.get_node("HUD/DebugPanel/Box/ClearRow/ClearEnemy")
	_ensure_debug_tabs()
	_quick_toggle = _run_ui.get_node_or_null("HUD/QuickToggle") as Button
	if not _quick_toggle:
		_quick_toggle = _run_ui.find_child("QuickToggle", true, false) as Button
	_slot_bar = _run_ui.get_node("HUD/BottomBar/SlotBar")
	_leave_button = _run_ui.get_node_or_null("LeaveButton") as Button
	_slot_panels = []
	_slot_rich_labels = []
	for c in _slot_bar.get_children():
		if c is Control:
			_slot_panels.append(c)
			var rt := RichTextLabel.new()
			rt.bbcode_enabled = true
			rt.fit_content = true
			rt.scroll_active = false
			rt.mouse_filter = Control.MOUSE_FILTER_IGNORE
			rt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			rt.size_flags_vertical = Control.SIZE_EXPAND_FILL
			(c as Control).add_child(rt)
			_slot_rich_labels.append(rt)
	for i in range(_slot_panels.size()):
		_wire_slot_panel(_slot_panels[i], i)

	_prev_button = _run_ui.get_node("NodePanel/MapArea/MapBar/PrevButton")
	_next_button = _run_ui.get_node("NodePanel/MapArea/MapBar/NextButton")
	_enter_button = _run_ui.get_node("NodePanel/MapArea/EnterNodeButton")

	_node_buttons = []
	_nodes_viewport = _run_ui.get_node_or_null("NodePanel/MapArea/MapBar/NodesViewport")
	_nodes_row = _run_ui.get_node_or_null("NodePanel/MapArea/MapBar/NodesViewport/NodesRow") as HBoxContainer
	if not _nodes_row:
		_nodes_viewport = null
		_nodes_row = _run_ui.get_node_or_null("NodePanel/MapArea/MapBar/Nodes") as HBoxContainer
	if _nodes_row:
		for c in _nodes_row.get_children():
			if c is Button:
				_node_buttons.append(c)
		for btn in _node_buttons:
			var b := btn
			b.pressed.connect(func() -> void:
				var idx := int(b.get_meta("map_index", -1))
				if idx < 0:
					return
				select_index_pressed.emit(idx)
			)

	_stage_label = _run_ui.get_node("NodePanel/StageArea/Box/StageLabel")

	_battle_panel = _run_ui.get_node("NodePanel/StageArea/Box/BattlePanel")
	_battle_status = _run_ui.get_node("NodePanel/StageArea/Box/BattlePanel/StatusLabel")
	_battle_action_buttons = []
	var actions_container: Control = _run_ui.get_node("NodePanel/StageArea/Box/BattlePanel/Actions")
	for c in actions_container.get_children():
		if c is Button:
			_battle_action_buttons.append(c)
	_lane_slots = []
	var lane: Control = _run_ui.get_node("NodePanel/StageArea/Box/BattlePanel/Lane")
	for cell in lane.get_children():
		if cell is Control and (cell as Control).has_node("Box/Slot"):
			_lane_slots.append((cell as Control).get_node("Box/Slot"))
	if _run_ui.has_node("NodePanel/StageArea/Box/BattlePanel/Lane/Cell8/Box/Slot/EnemyToken"):
		_enemy_token = _run_ui.get_node("NodePanel/StageArea/Box/BattlePanel/Lane/Cell8/Box/Slot/EnemyToken")
	_battle_overlay = _run_ui.get_node("NodePanel/StageArea/BattleOverlay")
	_player_token = _run_ui.get_node("NodePanel/StageArea/BattleOverlay/PlayerToken")
	_player_token_default_texture = _player_token.texture if _player_token else null

	_content_panel = _run_ui.get_node("RewardPanel")
	_content_title = _run_ui.get_node("RewardPanel/Box/TitleLabel")
	_content_body = _run_ui.get_node("RewardPanel/Box/BodyLabel")
	_content_primary = _run_ui.get_node("RewardPanel/Box/PrimaryButton")

	_reward_panel = _run_ui.get_node("BattleRewardPanel")
	_reward_gold_label = _run_ui.get_node("BattleRewardPanel/Box/GoldLabel")
	_reward_skip_button = _run_ui.get_node("BattleRewardPanel/SkipButton")
	_reward_card_buttons = [
		_run_ui.get_node("BattleRewardPanel/Box/CardRow/Card0"),
		_run_ui.get_node("BattleRewardPanel/Box/CardRow/Card1"),
		_run_ui.get_node("BattleRewardPanel/Box/CardRow/Card2"),
	]
	_reward_detail_layer = _run_ui.get_node("BattleRewardPanel/DetailLayer")
	_reward_backdrop = _run_ui.get_node("BattleRewardPanel/DetailLayer/Backdrop")
	_reward_selected_icon = _run_ui.get_node("BattleRewardPanel/DetailLayer/DetailPanel/Box/SelectedIcon")
	_reward_name_label = _run_ui.get_node("BattleRewardPanel/DetailLayer/DetailPanel/Box/NameLabel")
	_reward_text_label = _run_ui.get_node("BattleRewardPanel/DetailLayer/DetailPanel/Box/TextLabel")
	_reward_slot_row = _run_ui.get_node("BattleRewardPanel/DetailLayer/DetailPanel/Box/SlotRow")
	_reward_slot_buttons = []

	_shop_panel = _run_ui.get_node_or_null("ShopPanel") as Control
	_shop_hint_label = _run_ui.get_node_or_null("ShopPanel/Box/HintLabel") as Label
	_shop_card_buttons = []
	_shop_price_labels = []
	for i in range(5):
		var btn := _run_ui.get_node_or_null("ShopPanel/Box/CardRow/Item%d/Card%d" % [i, i]) as Button
		if btn:
			_shop_card_buttons.append(btn)
		var price_label := _run_ui.get_node_or_null("ShopPanel/Box/CardRow/Item%d/Price%d" % [i, i]) as Label
		if price_label:
			_shop_price_labels.append(price_label)

func _wire_run_ui_signals() -> void:
	_content_primary.pressed.connect(func() -> void:
		placeholder_continue_pressed.emit()
	)

	for btn in _battle_action_buttons:
		var b := btn
		b.pressed.connect(func() -> void:
			var action_id := String(b.get_meta("action_id", ""))
			if action_id.is_empty():
				return
			battle_action_pressed.emit(action_id)
		)

	if _reward_skip_button:
		_reward_skip_button.pressed.connect(func() -> void:
			reward_skip_pressed.emit()
		)
	for i in range(_reward_card_buttons.size()):
		var b: Button = _reward_card_buttons[i]
		var bb := b
		bb.pressed.connect(func() -> void:
			var id := String(bb.get_meta("card_id", ""))
			if id.is_empty():
				return
			_enter_reward_detail(id)
		)
	if _reward_backdrop:
		_reward_backdrop.pressed.connect(func() -> void:
			_exit_reward_detail()
		)

	if _leave_button:
		_leave_button.pressed.connect(func() -> void:
			_on_leave_pressed()
		)

	for i in range(_shop_card_buttons.size()):
		var b: Button = _shop_card_buttons[i]
		var bb := b
		bb.pressed.connect(func() -> void:
			var id := String(bb.get_meta("card_id", ""))
			var price := int(bb.get_meta("shop_price", 0))
			if id.is_empty() or price <= 0:
				return
			shop_buy_pressed.emit(id, price)
		)
	if _quick_toggle:
		_quick_toggle.pressed.connect(func() -> void:
			_set_quick_mode_level((_quick_mode_level + 1) % 3)
			quick_mode_level_changed.emit(_quick_mode_level)
		)
	if _debug_entry:
		_debug_entry.pressed.connect(func() -> void:
			_set_debug_panel_visible(not _debug_panel.visible)
		)
	if _debug_close:
		_debug_close.pressed.connect(func() -> void:
			_set_debug_panel_visible(false)
		)
	if _debug_quick_check:
		_debug_quick_check.pressed.connect(func() -> void:
			_set_quick_mode_level((_quick_mode_level + 1) % 3)
			quick_mode_level_changed.emit(_quick_mode_level)
		)
	if _debug_apply_player_hp:
		_debug_apply_player_hp.pressed.connect(func() -> void:
			debug_action.emit({"type": "set_player_hp", "value": int(_debug_player_hp.value)})
		)
	if _debug_apply_enemy_hp:
		_debug_apply_enemy_hp.pressed.connect(func() -> void:
			debug_action.emit({"type": "set_enemy_hp", "value": int(_debug_enemy_hp.value)})
		)
	if _debug_add_player:
		_debug_add_player.pressed.connect(func() -> void:
			var sid := _get_selected_status_id()
			if sid.is_empty():
				return
			debug_action.emit({"type": "add_status", "target": "player", "status_id": sid, "stacks": int(_debug_status_stacks.value)})
		)
	if _debug_add_enemy:
		_debug_add_enemy.pressed.connect(func() -> void:
			var sid := _get_selected_status_id()
			if sid.is_empty():
				return
			debug_action.emit({"type": "add_status", "target": "enemy", "status_id": sid, "stacks": int(_debug_status_stacks.value)})
		)
	if _debug_clear_player:
		_debug_clear_player.pressed.connect(func() -> void:
			debug_action.emit({"type": "clear_statuses", "target": "player"})
		)
	if _debug_clear_enemy:
		_debug_clear_enemy.pressed.connect(func() -> void:
			debug_action.emit({"type": "clear_statuses", "target": "enemy"})
		)
	if _prev_button:
		_prev_button.pressed.connect(func() -> void:
			select_prev_pressed.emit()
		)
	if _next_button:
		_next_button.pressed.connect(func() -> void:
			select_next_pressed.emit()
		)
	if _enter_button:
		_enter_button.pressed.connect(func() -> void:
			enter_node_pressed.emit()
		)

func _set_quick_mode_level(level: int) -> void:
	_quick_mode_level = clampi(level, 0, 2)
	var label := _quick_mode_level_to_label(_quick_mode_level)
	if _quick_toggle:
		_quick_toggle.text = "快战:%s" % label
	if _debug_quick_check:
		_debug_quick_check.text = "快战:%s" % label

func _quick_mode_level_to_label(level: int) -> String:
	if level == 1:
		return "开"
	if level == 2:
		return "极"
	return "关"

func _set_debug_panel_visible(visible: bool) -> void:
	if _debug_panel:
		_debug_panel.visible = visible
		if visible:
			_refresh_debug_panel({}, {})
			_refresh_wheel_editor()

func _ensure_debug_tabs() -> void:
	if not _debug_panel:
		return
	var box := _debug_panel.get_node("Box")
	if not (box is VBoxContainer):
		return
	var vb: VBoxContainer = box
	if bool(vb.get_meta("debug_tabs_ready", false)):
		return
	if not vb.has_node("Header"):
		return
	var header: Control = vb.get_node("Header")
	_debug_tabs = TabContainer.new()
	_debug_tabs.name = "Tabs"
	_debug_tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_debug_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(_debug_tabs)
	vb.move_child(_debug_tabs, 1)

	var global := VBoxContainer.new()
	global.name = "全局"
	global.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	global.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_debug_tabs.add_child(global)
	var gold_row := HBoxContainer.new()
	global.add_child(gold_row)
	var gold_label := Label.new()
	gold_label.text = "金币"
	gold_row.add_child(gold_label)
	_debug_gold = SpinBox.new()
	_debug_gold.min_value = 0
	_debug_gold.max_value = 999999
	_debug_gold.step = 1
	gold_row.add_child(_debug_gold)
	_debug_apply_gold = Button.new()
	_debug_apply_gold.text = "应用"
	_debug_apply_gold.pressed.connect(func() -> void:
		if not _debug_gold:
			return
		debug_action.emit({"type": "set_gold", "value": int(_debug_gold.value)})
	)
	gold_row.add_child(_debug_apply_gold)

	var basic := VBoxContainer.new()
	basic.name = "调试"
	basic.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	basic.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_debug_tabs.add_child(basic)

	_debug_wheel_tab = VBoxContainer.new()
	_debug_wheel_tab.name = "弹匣编辑"
	(_debug_wheel_tab as VBoxContainer).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	(_debug_wheel_tab as VBoxContainer).size_flags_vertical = Control.SIZE_EXPAND_FILL
	_debug_tabs.add_child(_debug_wheel_tab)

	var to_move: Array[Node] = []
	for c in vb.get_children():
		if c == header or c == _debug_tabs:
			continue
		to_move.append(c)
	for n in to_move:
		vb.remove_child(n)
		if n.name == "QuickRow" or n.name == "InfoLabel" or n.name == "HPRow":
			global.add_child(n)
		else:
			basic.add_child(n)

	_build_wheel_editor_ui(_debug_wheel_tab as VBoxContainer)
	vb.set_meta("debug_tabs_ready", true)

func _build_wheel_editor_ui(root: VBoxContainer) -> void:
	for c in root.get_children():
		c.queue_free()

	var row1 := HBoxContainer.new()
	root.add_child(row1)
	var wheel_label := Label.new()
	wheel_label.text = "弹匣"
	row1.add_child(wheel_label)
	_debug_wheel_select = OptionButton.new()
	row1.add_child(_debug_wheel_select)
	_debug_wheel_select.item_selected.connect(func(_idx: int) -> void:
		_debug_wheel_selected_index = -1
		_refresh_wheel_editor()
	)

	var row2 := HBoxContainer.new()
	root.add_child(row2)
	var pos_label := Label.new()
	pos_label.text = "位置"
	row2.add_child(pos_label)
	_debug_wheel_insert_pos = SpinBox.new()
	_debug_wheel_insert_pos.min_value = 0
	_debug_wheel_insert_pos.max_value = 99
	_debug_wheel_insert_pos.step = 1
	row2.add_child(_debug_wheel_insert_pos)
	var card_label := Label.new()
	card_label.text = "子弹"
	row2.add_child(card_label)
	_debug_wheel_card_select = OptionButton.new()
	row2.add_child(_debug_wheel_card_select)
	_debug_wheel_insert_btn = Button.new()
	_debug_wheel_insert_btn.text = "插入"
	_debug_wheel_insert_btn.pressed.connect(func() -> void:
		_on_debug_wheel_insert(false)
	)
	row2.add_child(_debug_wheel_insert_btn)
	_debug_wheel_append_btn = Button.new()
	_debug_wheel_append_btn.text = "追加"
	_debug_wheel_append_btn.pressed.connect(func() -> void:
		_on_debug_wheel_insert(true)
	)
	row2.add_child(_debug_wheel_append_btn)

	var row3 := HBoxContainer.new()
	root.add_child(row3)
	_debug_wheel_delete_btn = Button.new()
	_debug_wheel_delete_btn.text = "删除"
	_debug_wheel_delete_btn.pressed.connect(func() -> void:
		_on_debug_wheel_delete()
	)
	row3.add_child(_debug_wheel_delete_btn)
	_debug_wheel_up_btn = Button.new()
	_debug_wheel_up_btn.text = "上移"
	_debug_wheel_up_btn.pressed.connect(func() -> void:
		_on_debug_wheel_move(-1)
	)
	row3.add_child(_debug_wheel_up_btn)
	_debug_wheel_down_btn = Button.new()
	_debug_wheel_down_btn.text = "下移"
	_debug_wheel_down_btn.pressed.connect(func() -> void:
		_on_debug_wheel_move(1)
	)
	row3.add_child(_debug_wheel_down_btn)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)
	_debug_wheel_list = VBoxContainer.new()
	_debug_wheel_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_debug_wheel_list)

func _refresh_wheel_editor() -> void:
	if not _debug_wheel_tab or not _debug_wheel_select or not _debug_wheel_card_select or not _debug_wheel_insert_pos or not _debug_wheel_list:
		return
	if not _active_run:
		_debug_wheel_select.clear()
		_debug_wheel_card_select.clear()
		for c in _debug_wheel_list.get_children():
			c.queue_free()
		return
	if not _card_db:
		_card_db = CardDatabase.load_default()
	if _debug_wheel_card_select.item_count == 0 and _card_db:
		_debug_wheel_card_select.clear()
		var ids := _card_db.get_all_ids()
		for i in range(ids.size()):
			var id := ids[i]
			var def: Dictionary = _card_db.get_card(id)
			var card_name := String(def.get("name", id))
			_debug_wheel_card_select.add_item("%s" % card_name)
			_debug_wheel_card_select.set_item_metadata(i, id)
		if _debug_wheel_card_select.item_count > 0:
			_debug_wheel_card_select.select(0)
	var wheels: Array = _active_run.get_wheels_snapshot()
	var last_wheel_count := wheels.size()
	_debug_wheel_select.clear()
	for i in range(last_wheel_count):
		_debug_wheel_select.add_item("弹匣 %d" % (i + 1), i)
	if _debug_wheel_select.item_count > 0 and _debug_wheel_select.selected < 0:
		_debug_wheel_select.select(0)
	if _debug_wheel_select.item_count > 0:
		var wi := _debug_wheel_select.get_item_id(_debug_wheel_select.selected)
		var w = wheels[wi]
		var size := 0
		if typeof(w) == TYPE_ARRAY:
			size = (w as Array).size()
		elif typeof(w) == TYPE_PACKED_STRING_ARRAY:
			size = (w as PackedStringArray).size()
		_debug_wheel_insert_pos.max_value = max(0, size)
		if int(_debug_wheel_insert_pos.value) > size:
			_debug_wheel_insert_pos.value = float(size)
		_render_debug_wheel_list(wi, w)

func _render_debug_wheel_list(_wheel_index: int, wheel_data) -> void:
	for c in _debug_wheel_list.get_children():
		c.queue_free()
	var size := 0
	if typeof(wheel_data) == TYPE_ARRAY:
		size = (wheel_data as Array).size()
	elif typeof(wheel_data) == TYPE_PACKED_STRING_ARRAY:
		size = (wheel_data as PackedStringArray).size()
	for i in range(size):
		var id := String(wheel_data[i])
		var card_name := id
		if _card_db:
			card_name = String(_card_db.get_card(id).get("name", id))
		var btn := Button.new()
		btn.text = "%d. %s" % [i + 1, card_name]
		if i == _debug_wheel_selected_index:
			btn.modulate = Color(1.0, 0.65, 0.15)
		var idx := i
		btn.pressed.connect(func() -> void:
			_debug_wheel_selected_index = idx
			_refresh_wheel_editor()
		)
		_debug_wheel_list.add_child(btn)

func _get_selected_debug_card_id() -> String:
	if not _debug_wheel_card_select:
		return ""
	var idx := _debug_wheel_card_select.selected
	if idx < 0:
		return ""
	var v: Variant = _debug_wheel_card_select.get_item_metadata(idx)
	return String(v)

func _on_debug_wheel_insert(append: bool) -> void:
	if not _active_run or not _debug_wheel_select or not _debug_wheel_insert_pos:
		return
	var card_id := _get_selected_debug_card_id()
	if card_id.is_empty():
		return
	var wi := _debug_wheel_select.get_item_id(_debug_wheel_select.selected)
	var wheels: Array = _active_run.get_wheels_snapshot()
	if wi < 0 or wi >= wheels.size():
		return
	var w = wheels[wi]
	var size := 0
	if typeof(w) == TYPE_ARRAY:
		size = (w as Array).size()
	elif typeof(w) == TYPE_PACKED_STRING_ARRAY:
		size = (w as PackedStringArray).size()
	var pos := size if append else int(_debug_wheel_insert_pos.value)
	if _active_run.insert_card_to_wheel(card_id, wi, pos, true):
		_debug_wheel_selected_index = clampi(pos, 0, size)
		_set_slot_pools_from_run(_active_run)
		debug_action.emit({"type": "set_slot_wheels", "wheels": _active_run.get_wheels_snapshot()})
		_refresh_wheel_editor()

func _on_debug_wheel_delete() -> void:
	if not _active_run or not _debug_wheel_select:
		return
	if _debug_wheel_selected_index < 0:
		return
	var wi := _debug_wheel_select.get_item_id(_debug_wheel_select.selected)
	if _active_run.remove_card_from_wheel(wi, _debug_wheel_selected_index):
		_debug_wheel_selected_index = -1
		_set_slot_pools_from_run(_active_run)
		debug_action.emit({"type": "set_slot_wheels", "wheels": _active_run.get_wheels_snapshot()})
		_refresh_wheel_editor()

func _on_debug_wheel_move(delta: int) -> void:
	if not _active_run or not _debug_wheel_select:
		return
	if _debug_wheel_selected_index < 0:
		return
	var wi := _debug_wheel_select.get_item_id(_debug_wheel_select.selected)
	var wheels: Array = _active_run.get_wheels_snapshot()
	if wi < 0 or wi >= wheels.size():
		return
	var w = wheels[wi]
	var size := 0
	if typeof(w) == TYPE_ARRAY:
		size = (w as Array).size()
	elif typeof(w) == TYPE_PACKED_STRING_ARRAY:
		size = (w as PackedStringArray).size()
	var from := _debug_wheel_selected_index
	var to := clampi(from + delta, 0, size - 1)
	if to == from:
		return
	var id := String(w[from])
	if not _active_run.remove_card_from_wheel(wi, from):
		return
	if not _active_run.insert_card_to_wheel(id, wi, to, true):
		_active_run.insert_card_to_wheel(id, wi, from, true)
		return
	_debug_wheel_selected_index = to
	_set_slot_pools_from_run(_active_run)
	debug_action.emit({"type": "set_slot_wheels", "wheels": _active_run.get_wheels_snapshot()})
	_refresh_wheel_editor()

func _get_selected_status_id() -> String:
	if not _debug_status_select:
		return ""
	var idx := _debug_status_select.selected
	if idx < 0:
		return ""
	return String(_debug_status_select.get_item_text(idx))

func _refresh_debug_panel(run_state: Dictionary, battle_state: Dictionary) -> void:
	if not _debug_panel or not _debug_panel.visible:
		return
	if _debug_status_select and _debug_status_select.item_count == 0:
		var db := StatusDatabase.load_default()
		var ids := db.get_all_ids()
		for id in ids:
			_debug_status_select.add_item(id)
		if _debug_status_select.item_count > 0:
			_debug_status_select.select(0)
	var hp := int(run_state.get("hp", 0))
	if _debug_player_hp:
		_debug_player_hp.value = float(hp)
	if _debug_info:
		var gold := int(run_state.get("gold", 0))
		if _debug_gold:
			_debug_gold.value = float(gold)
		var qml := int(run_state.get("quick_mode_level", 0))
		var turn := int(battle_state.get("turn", 0))
		var phase := String(battle_state.get("phase", ""))
		var player: Dictionary = battle_state.get("player", {})
		var enemies: Array = battle_state.get("enemies", [])
		var enemy_hp := 0
		var enemy_intent := ""
		if not enemies.is_empty() and typeof(enemies[0]) == TYPE_DICTIONARY:
			var e: Dictionary = enemies[0]
			enemy_hp = int(e.get("hp", 0))
			var intent: Dictionary = e.get("intent", {})
			enemy_intent = String(intent.get("text", ""))
		_debug_info.text = "gold=%d hp=%d quick=%s\nturn=%d phase=%s cell=%d\nenemy_hp=%d\nintent=%s" % [
			gold,
			hp,
			_quick_mode_level_to_label(qml),
			turn,
			phase,
			int(player.get("cell", 0)),
			enemy_hp,
			enemy_intent,
		]

func _render_stage_text(mode: String) -> void:
	if not _stage_label:
		return
	if mode == "battle":
		_stage_label.text = "战斗舞台（占位）"
	elif mode == "event":
		_stage_label.text = "节点内容（占位）"
	else:
		_stage_label.text = "地图 / 场景（占位）"

func _set_battle_actions(actions: Array[Dictionary]) -> void:
	var i := 0
	for btn in _battle_action_buttons:
		if i < actions.size():
			var a: Dictionary = actions[i]
			btn.visible = true
			btn.disabled = false
			btn.text = String(a.get("name", "行动"))
			btn.set_meta("action_id", String(a.get("id", "")))
		else:
			btn.visible = false
		i += 1

func _hide_battle_panel() -> void:
	if _battle_panel:
		_battle_panel.visible = false
	if _battle_overlay:
		_battle_overlay.visible = false

func _set_reward_cards(cards: Array[Dictionary]) -> void:
	for i in range(_reward_card_buttons.size()):
		var btn: Button = _reward_card_buttons[i]
		if i < cards.size():
			var c: Dictionary = cards[i]
			var id := String(c.get("id", ""))
			var card_name := String(c.get("name", "卡"))
			var text := String(c.get("text", ""))
			var icon_path := String(c.get("icon", ""))
			var rarity := String(c.get("rarity", "white"))
			btn.visible = true
			btn.disabled = false
			btn.text = card_name
			btn.set_meta("card_id", id)
			btn.set_meta("card_name", card_name)
			btn.set_meta("card_text", text)
			btn.set_meta("card_icon_path", icon_path)
			btn.set_meta("card_rarity", rarity)
			_apply_rarity_border(btn, rarity)
			if not icon_path.is_empty():
				var tex = load(icon_path)
				if tex is Texture2D:
					btn.icon = tex
		else:
			btn.visible = false

func _apply_rarity_border(btn: Button, rarity: String) -> void:
	if not btn:
		return
	var border: Color = Color(0.85, 0.85, 0.85)
	if rarity == "blue":
		border = Color(0.25, 0.55, 1.0)
	elif rarity == "gold":
		border = Color(1.0, 0.8, 0.15)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.15)
	sb.border_color = border
	sb.set_border_width_all(4)
	sb.set_corner_radius_all(10)
	btn.add_theme_stylebox_override("normal", sb)
	var sbh: StyleBoxFlat = sb.duplicate(true) as StyleBoxFlat
	if sbh:
		sbh.bg_color = Color(0, 0, 0, 0.22)
		btn.add_theme_stylebox_override("hover", sbh)
	var sbp: StyleBoxFlat = sb.duplicate(true) as StyleBoxFlat
	if sbp:
		sbp.bg_color = Color(0, 0, 0, 0.28)
		btn.add_theme_stylebox_override("pressed", sbp)

func _enter_reward_detail(card_id: String) -> void:
	if not _reward_detail_layer or not _reward_panel:
		return
	_reward_selected_card_id = card_id
	var card_name := card_id
	var text := ""
	var tex: Texture2D = null
	for btn in _reward_card_buttons:
		if String(btn.get_meta("card_id", "")) != card_id:
			continue
		card_name = String(btn.get_meta("card_name", btn.text))
		text = String(btn.get_meta("card_text", ""))
		if btn.icon:
			tex = btn.icon
		break
	if tex:
		_reward_selected_icon.texture = tex
	_reward_name_label.text = card_name
	_reward_text_label.text = text
	_render_reward_slot_buttons(card_id)
	_reward_detail_layer.visible = true
	_refresh_leave_button()

func _exit_reward_detail() -> void:
	if not _event_reward_pick_card_id.is_empty():
		var allow := _event_reward_pick_show_cancel
		var card_id := _event_reward_pick_card_id
		_event_reward_pick_card_id = ""
		_event_reward_pick_show_cancel = false
		_reward_selected_card_id = ""
		if _reward_detail_layer:
			_reward_detail_layer.visible = false
		if _reward_panel:
			_reward_panel.visible = false
		if _shop_panel and _shop_suspended_for_pick:
			_shop_panel.visible = true
			_shop_suspended_for_pick = false
		_refresh_leave_button()
		if allow:
			event_add_to_wheel_cancelled.emit()
		return
	_reward_selected_card_id = ""
	if _reward_detail_layer:
		_reward_detail_layer.visible = false
	_refresh_leave_button()

func show_event_add_card_to_wheel(card_id: String, allow_cancel: bool = true) -> void:
	if not _reward_panel or not _reward_detail_layer:
		return
	_hide_event_layer()
	if _shop_panel and _shop_panel.visible:
		_shop_panel.visible = false
		_shop_suspended_for_pick = true
	if not _card_db:
		_card_db = CardDatabase.load_default()
	if not _card_db:
		return
	var c: Dictionary = _card_db.get_card(card_id)
	var card_name := String(c.get("name", card_id))
	var text := String(c.get("text", ""))
	var icon_path := String(c.get("icon", ""))

	_reward_panel.visible = true
	if _reward_gold_label:
		_reward_gold_label.visible = false
	if _reward_skip_button:
		_reward_skip_button.visible = false
	if _run_ui and _run_ui.has_node("BattleRewardPanel/Box/CardRow"):
		(_run_ui.get_node("BattleRewardPanel/Box/CardRow") as Control).visible = false
	if _run_ui and _run_ui.has_node("BattleRewardPanel/Box/TitleLabel"):
		(_run_ui.get_node("BattleRewardPanel/Box/TitleLabel") as Label).text = "选择加入弹匣"

	_event_reward_pick_card_id = card_id
	_event_reward_pick_show_cancel = allow_cancel
	_reward_selected_card_id = card_id
	if _reward_selected_icon:
		if not icon_path.is_empty():
			var tex = load(icon_path)
			if tex is Texture2D:
				_reward_selected_icon.texture = tex
	if _reward_name_label:
		_reward_name_label.text = card_name
	if _reward_text_label:
		_reward_text_label.text = text
	_render_event_reward_slot_buttons(card_id)
	_reward_detail_layer.visible = true
	_refresh_leave_button()

func _render_event_reward_slot_buttons(card_id: String) -> void:
	if not _reward_slot_row:
		return
	for c in _reward_slot_row.get_children():
		c.queue_free()
	if not _card_db:
		_card_db = CardDatabase.load_default()
	var constraints: Dictionary = {}
	if _card_db:
		constraints = _card_db.get_card(card_id).get("constraints", {})
	var wheel_rule := String(constraints.get("wheel", ""))
	var wheel_count: int = int(max(1, _last_wheel_count))
	var last_idx: int = wheel_count - 1
	for i in range(wheel_count):
		var b := Button.new()
		b.text = "加入轮%d" % (i + 1)
		if wheel_rule == "last" and i != last_idx:
			b.disabled = true
		var idx := i
		b.pressed.connect(func() -> void:
			if _event_reward_pick_card_id.is_empty():
				return
			var cid := _event_reward_pick_card_id
			_event_reward_pick_card_id = ""
			_event_reward_pick_show_cancel = false
			_reward_selected_card_id = ""
			if _reward_detail_layer:
				_reward_detail_layer.visible = false
			if _reward_panel:
				_reward_panel.visible = false
			if _shop_panel and _shop_suspended_for_pick:
				_shop_panel.visible = true
				_shop_suspended_for_pick = false
			_refresh_leave_button()
			event_add_to_wheel_selected.emit(cid, idx)
		)
		_reward_slot_row.add_child(b)

func _render_reward_slot_buttons(card_id: String) -> void:
	if not _reward_slot_row:
		return
	for c in _reward_slot_row.get_children():
		c.queue_free()
	if not _card_db:
		_card_db = CardDatabase.load_default()
	var constraints: Dictionary = {}
	if _card_db:
		constraints = _card_db.get_card(card_id).get("constraints", {})
	var wheel_rule := String(constraints.get("wheel", ""))
	var wheel_count: int = int(max(1, _last_wheel_count))
	var last_idx: int = wheel_count - 1
	for i in range(wheel_count):
		var b := Button.new()
		b.text = "加入轮%d" % (i + 1)
		if wheel_rule == "last" and i != last_idx:
			b.disabled = true
		var idx := i
		b.pressed.connect(func() -> void:
			if _reward_selected_card_id.is_empty():
				return
			reward_add_to_wheel_pressed.emit(_reward_selected_card_id, idx)
		)
		_reward_slot_row.add_child(b)

func _render_slot_debug(slot_state: Dictionary) -> void:
	if not _slot_bar:
		return
	var pools: Array = slot_state.get("pools", [])
	var roll: Array = slot_state.get("last_roll", [])
	var active_wheel := int(slot_state.get("active_wheel", -1))
	var is_resolving := bool(slot_state.get("is_resolving", false))
	if not _card_db:
		_card_db = CardDatabase.load_default()
	_ensure_slot_panels(int(max(4, pools.size())))
	var roll_by_wheel: Dictionary = {}
	for x in roll:
		if typeof(x) == TYPE_DICTIONARY:
			var d: Dictionary = x
			roll_by_wheel[int(d.get("wheel_index", -1))] = String(d.get("id", ""))
	for i in range(_slot_panels.size()):
		var p: Control = _slot_panels[i]
		var rt: RichTextLabel = _slot_rich_labels[i] if i < _slot_rich_labels.size() else null
		var unlocked := i < pools.size()
		var magazine_art := p.get_node_or_null("MagazineArt")
		if magazine_art and magazine_art is CanvasItem:
			(magazine_art as CanvasItem).visible = unlocked
		var locked_magazine := p.get_node_or_null("LockedMagazine")
		if locked_magazine and locked_magazine is CanvasItem:
			(locked_magazine as CanvasItem).visible = not unlocked
		if i >= pools.size():
			p.visible = true
			if p.has_node("Label"):
				var l: Label = p.get_node("Label")
				l.visible = true
				l.text = "slot %d\n（占位）" % (i + 1)
			if rt:
				rt.text = "轮 %d\n(未解锁)" % (i + 1)
			p.modulate = Color(0.75, 0.75, 0.75, 1.0)
			continue
		p.visible = true
		if p.has_node("Label"):
			p.get_node("Label").visible = false
		var head := "轮 %d" % (i + 1)
		if i == active_wheel:
			head = "▶ %s" % head
		var rid := String(roll_by_wheel.get(i, ""))
		var roll_name := ""
		if not rid.is_empty() and _card_db:
			roll_name = String(_card_db.get_card(rid).get("name", rid))
		var roll_line := ("-> %s" % (roll_name if not roll_name.is_empty() else rid)) if not rid.is_empty() else "->"
		if rt:
			rt.text = "%s\n%s" % [head, roll_line]
		if i == active_wheel:
			p.modulate = Color(1.0, 0.65, 0.15)
		elif is_resolving:
			p.modulate = Color(0.85, 0.85, 0.85)
		else:
			p.modulate = Color(1, 1, 1)

func _ensure_slot_panels(wheel_count: int) -> void:
	if not _slot_bar:
		return
	while _slot_panels.size() < wheel_count:
		var p := PanelContainer.new()
		p.custom_minimum_size = Vector2(140, 64)
		_slot_bar.add_child(p)
		_slot_panels.append(p)
		var rt := RichTextLabel.new()
		rt.bbcode_enabled = true
		rt.fit_content = true
		rt.scroll_active = false
		rt.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rt.size_flags_vertical = Control.SIZE_EXPAND_FILL
		p.add_child(rt)
		_slot_rich_labels.append(rt)
		_wire_slot_panel(p, _slot_panels.size() - 1)

func _wire_slot_panel(panel: Control, wheel_index: int) -> void:
	if not panel:
		return
	if bool(panel.get_meta("slot_wired", false)):
		return
	panel.set_meta("slot_wired", true)
	panel.set_meta("wheel_index", wheel_index)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton:
			var mb := event as InputEventMouseButton
			if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
				_show_slot_detail(int(panel.get_meta("wheel_index", -1)))
	)

func _show_slot_detail(wheel_index: int) -> void:
	_ensure_slot_detail_layer()
	if not _slot_detail_layer:
		return
	_slot_detail_layer.visible = true
	_slot_detail_title.text = "弹匣 %d" % (wheel_index + 1)
	var entries: Array = []
	if wheel_index >= 0 and wheel_index < _last_slot_pools.size():
		entries = _last_slot_pools[wheel_index]
	_slot_detail_text.text = _format_wheel_entries(entries)

func _hide_slot_detail() -> void:
	if _slot_detail_layer:
		_slot_detail_layer.visible = false

func _ensure_slot_detail_layer() -> void:
	if _slot_detail_layer:
		return
	if not _run_ui:
		return
	_slot_detail_layer = Control.new()
	_slot_detail_layer.name = "SlotDetailLayer"
	_slot_detail_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_slot_detail_layer.visible = false
	_run_ui.add_child(_slot_detail_layer)

	var backdrop := Button.new()
	backdrop.flat = true
	backdrop.focus_mode = Control.FOCUS_NONE
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.modulate = Color(0, 0, 0, 0.6)
	backdrop.pressed.connect(func() -> void:
		_hide_slot_detail()
	)
	_slot_detail_layer.add_child(backdrop)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -260
	panel.offset_top = -260
	panel.offset_right = 260
	panel.offset_bottom = 260
	_slot_detail_layer.add_child(panel)

	var vb := VBoxContainer.new()
	panel.add_child(vb)

	_slot_detail_title = Label.new()
	_slot_detail_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(_slot_detail_title)

	_slot_detail_text = RichTextLabel.new()
	_slot_detail_text.bbcode_enabled = true
	_slot_detail_text.scroll_active = true
	_slot_detail_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(_slot_detail_text)

	var close_btn := Button.new()
	close_btn.text = "关闭"
	close_btn.pressed.connect(func() -> void:
		_hide_slot_detail()
	)
	vb.add_child(close_btn)

func _format_wheel_entries(entries: Array) -> String:
	var lines: Array[String] = []
	for x in entries:
		if typeof(x) != TYPE_DICTIONARY:
			continue
		var e: Dictionary = x
		var id := String(e.get("id", ""))
		if id.is_empty():
			continue
		var name := id
		if _card_db:
			name = String(_card_db.get_card(id).get("name", id))
		if bool(e.get("consumed", false)):
			lines.append("[s]%s[/s]" % name)
		else:
			lines.append(name)
	if lines.is_empty():
		return "-"
	return "\n".join(lines)

func _summarize_status_array(statuses) -> String:
	if typeof(statuses) != TYPE_ARRAY:
		return ""
	var parts: Array[String] = []
	for x in statuses:
		if typeof(x) != TYPE_DICTIONARY:
			continue
		var s: Dictionary = x
		var name := String(s.get("name", s.get("id", "")))
		var stacks := int(s.get("stacks", 0))
		if name.is_empty() or stacks == 0:
			continue
		parts.append("%s×%d" % [name, stacks])
	return ", ".join(parts)

func _schedule_token_layout() -> void:
	if _token_layout_scheduled:
		return
	_token_layout_scheduled = true
	call_deferred("_apply_token_layout")

func _apply_token_layout() -> void:
	_token_layout_scheduled = false
	if _lane_slots.is_empty():
		return
	if _player_token:
		var idx := clampi(_last_player_cell, 1, _lane_slots.size()) - 1
		var slot: Control = _lane_slots[idx]
		if slot.get_global_rect().size.x <= 1.0 and _token_layout_retry < 2:
			_token_layout_retry += 1
			_schedule_token_layout()
			return
		_token_layout_retry = 0
		_position_token_to_cell_center(_player_token, _last_player_cell)

func _position_token_to_cell_center(token: Control, cell: int) -> void:
	var idx := clampi(cell, 1, _lane_slots.size()) - 1
	var slot: Control = _lane_slots[idx]
	var center := slot.get_global_rect().get_center()
	var token_size := token.size * token.scale
	token.global_position = center - (token_size * 0.5)

func _set_slot_pools_from_run(run: RunContext) -> void:
	var pools: Array = []
	if run:
		for w in run.get_wheels_snapshot():
			var entries: Array = []
			if typeof(w) == TYPE_ARRAY or typeof(w) == TYPE_PACKED_STRING_ARRAY:
				for id in w:
					entries.append({"id": String(id), "consumed": false})
			pools.append(entries)
	_last_slot_pools = pools
	_last_wheel_count = max(1, pools.size())
	_render_slot_debug({"pools": pools, "last_roll": [], "active_wheel": -1, "is_resolving": false})

func _show_event_layer(node: Dictionary) -> void:
	_ensure_event_layer()
	if not _event_layer:
		return
	_event_layer.visible = true
	if _event_text:
		_event_text.text = ""
	if _event_options_box:
		for c in _event_options_box.get_children():
			c.queue_free()
		_event_options_box.visible = false
	if _event_continue_button:
		_event_continue_button.visible = false
		_event_continue_button.disabled = true
	_event_sequence_id += 1
	var seq_id := _event_sequence_id
	_event_current_seq_id = seq_id
	_event_choice_msec = 0
	_schedule_event_layout()
	call_deferred("_run_event_open_sequence", node, seq_id)

func _hide_event_layer() -> void:
	if _event_layer:
		_event_layer.visible = false
	if _event_options_box:
		_event_options_box.visible = false
	if _event_continue_button:
		_event_continue_button.visible = false
		_event_continue_button.disabled = true
	_event_sequence_id += 1
	_event_current_seq_id = 0
	_event_choice_msec = 0
	hide_event_remove_bullet()
	_hide_rest_adjust()
	_refresh_leave_button()

func _ensure_event_layer() -> void:
	if not _run_ui:
		return
	var stage_parent: Control = _run_ui.get_node_or_null("NodePanel/StageArea") as Control
	if _run_ui.has_node("EventOptionLayer"):
		var l := _run_ui.get_node("EventOptionLayer")
		if l is Control:
			(l as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not _event_layer:
		_event_layer = _run_ui.get_node_or_null("EventLayer") as Control
	if not _event_layer:
		_event_layer = Control.new()
		_event_layer.name = "EventLayer"
		_event_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
		_event_layer.visible = false
		_event_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_event_layer.z_as_relative = false
		_event_layer.z_index = 150
		(stage_parent if stage_parent else _run_ui).add_child(_event_layer)
	if stage_parent and _event_layer.get_parent() != stage_parent:
		var old_parent := _event_layer.get_parent()
		if old_parent:
			old_parent.remove_child(_event_layer)
		stage_parent.add_child(_event_layer)
	_event_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg: ColorRect = _event_layer.get_node_or_null("EventBackground") as ColorRect
	if not bg:
		bg = ColorRect.new()
		bg.name = "EventBackground"
		bg.set_anchors_preset(Control.PRESET_TOP_LEFT)
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_event_layer.add_child(bg)
		_event_layer.move_child(bg, 0)
	bg.color = Color8(152, 115, 185, 255)
	bg.visible = false
	if not _event_text:
		_event_text = _event_layer.get_node_or_null("EventText") as RichTextLabel
	if not _event_text:
		_event_text = RichTextLabel.new()
		_event_text.name = "EventText"
		_event_text.bbcode_enabled = false
		_event_text.fit_content = true
		_event_text.scroll_active = false
		_event_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_event_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_event_layer.add_child(_event_text)
	if not _event_options_box:
		if _run_ui:
			_event_options_box = _run_ui.get_node_or_null("EventOptionLayer/EventOptions") as VBoxContainer
		if not _event_options_box:
			_event_options_box = _event_layer.get_node_or_null("EventOptions") as VBoxContainer
	if not _event_options_box:
		_event_options_box = VBoxContainer.new()
		_event_options_box.name = "EventOptions"
		_event_options_box.mouse_filter = Control.MOUSE_FILTER_STOP
		_event_options_box.visible = false
		_event_layer.add_child(_event_options_box)
	_event_options_box.mouse_filter = Control.MOUSE_FILTER_STOP
	if not _event_continue_button:
		if _run_ui:
			_event_continue_button = _run_ui.get_node_or_null("EventOptionLayer/EventContinue") as Button
		if not _event_continue_button:
			_event_continue_button = _event_layer.get_node_or_null("EventContinue") as Button
	if not _event_continue_button:
		_event_continue_button = Button.new()
		_event_continue_button.name = "EventContinue"
		_event_continue_button.text = "继续"
		_event_continue_button.visible = false
		_event_continue_button.disabled = true
		_event_layer.add_child(_event_continue_button)
	_event_continue_button.disabled = true
	_event_continue_button.mouse_filter = Control.MOUSE_FILTER_STOP
	var cb := Callable(self, "_on_event_continue_pressed")
	if not _event_continue_button.pressed.is_connected(cb):
		_event_continue_button.pressed.connect(cb)

func _show_rest_layer(node: Dictionary, run: RunContext) -> void:
	_ensure_event_layer()
	if not _event_layer:
		return
	_event_layer.visible = true
	_hide_rest_adjust()
	if _event_text:
		_event_text.text = ""
	if _event_options_box:
		for c in _event_options_box.get_children():
			c.queue_free()
		_event_options_box.visible = false
	if _event_continue_button:
		_event_continue_button.visible = false
		_event_continue_button.disabled = true
	_event_sequence_id += 1
	var seq_id: int = _event_sequence_id
	_schedule_event_layout()
	call_deferred("_run_rest_open_sequence", node, run, seq_id)

func _run_rest_open_sequence(node: Dictionary, run: RunContext, seq_id: int) -> void:
	if seq_id != _event_sequence_id:
		return
	await get_tree().process_frame
	if seq_id != _event_sequence_id:
		return
	await _play_event_enter_animation(seq_id)
	if seq_id != _event_sequence_id:
		return
	var rest_data: Dictionary = {}
	if node.has("rest") and typeof(node["rest"]) == TYPE_DICTIONARY:
		rest_data = node["rest"]
	var text1 := String(rest_data.get("text1", ""))
	var text2 := String(rest_data.get("text2", ""))
	await _typewrite_event_text(text1, seq_id)
	if seq_id != _event_sequence_id:
		return
	_render_rest_root_options(seq_id, run, text2)
	if _event_options_box:
		_event_options_box.visible = true
	_schedule_event_layout()

func _render_rest_root_options(seq_id: int, run: RunContext, text2: String) -> void:
	if not _event_options_box:
		return
	for c in _event_options_box.get_children():
		c.queue_free()
	var rest_btn := Button.new()
	rest_btn.text = "休息"
	rest_btn.pressed.connect(func() -> void:
		_on_rest_rest_pressed(seq_id, text2)
	)
	_event_options_box.add_child(rest_btn)
	var adjust_btn := Button.new()
	adjust_btn.text = "调整弹匣"
	adjust_btn.pressed.connect(func() -> void:
		_on_rest_adjust_pressed(seq_id, run, text2)
	)
	_event_options_box.add_child(adjust_btn)

func _on_rest_rest_pressed(seq_id: int, text2: String) -> void:
	if seq_id != _event_sequence_id:
		return
	if _event_options_box:
		_event_options_box.visible = false
	event_option_selected.emit("rest")
	_schedule_event_layout()
	var choice_msec: int = Time.get_ticks_msec()
	_start_event_result_sequence(seq_id, text2, choice_msec)

func _on_rest_adjust_pressed(seq_id: int, run: RunContext, text2: String) -> void:
	if seq_id != _event_sequence_id:
		return
	if _event_options_box:
		_event_options_box.visible = false
	_schedule_event_layout()
	_show_rest_adjust(run, seq_id, text2)

var _rest_adjust_layer: Control
var _rest_adjust_title: Label
var _rest_adjust_columns: HBoxContainer
var _rest_adjust_target_row: HBoxContainer
var _rest_adjust_back: Button
var _rest_adjust_drop: Button
var _rest_adjust_run: RunContext
var _rest_adjust_seq_id: int = 0
var _rest_adjust_text2: String = ""
var _rest_held_wheel: int = -1
var _rest_held_index: int = -1
var _rest_held_card_id: String = ""

func _ensure_rest_adjust_layer() -> void:
	if _rest_adjust_layer:
		return
	if not _run_ui:
		return
	_rest_adjust_layer = Control.new()
	_rest_adjust_layer.name = "RestAdjustLayer"
	_rest_adjust_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rest_adjust_layer.visible = false
	_rest_adjust_layer.z_as_relative = false
	_rest_adjust_layer.z_index = 160
	_run_ui.add_child(_rest_adjust_layer)

	var backdrop := Button.new()
	backdrop.flat = true
	backdrop.focus_mode = Control.FOCUS_NONE
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.modulate = Color(0, 0, 0, 0.6)
	backdrop.pressed.connect(func() -> void:
		_hide_rest_adjust()
		_show_rest_root_options_again()
	)
	_rest_adjust_layer.add_child(backdrop)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -360
	panel.offset_top = -260
	panel.offset_right = 360
	panel.offset_bottom = 260
	_rest_adjust_layer.add_child(panel)

	var vb := VBoxContainer.new()
	panel.add_child(vb)

	_rest_adjust_title = Label.new()
	_rest_adjust_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_rest_adjust_title.text = "调整弹匣"
	vb.add_child(_rest_adjust_title)

	_rest_adjust_columns = HBoxContainer.new()
	_rest_adjust_columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(_rest_adjust_columns)

	_rest_adjust_target_row = HBoxContainer.new()
	_rest_adjust_target_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_child(_rest_adjust_target_row)

	var action_row := HBoxContainer.new()
	action_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_child(action_row)

	_rest_adjust_drop = Button.new()
	_rest_adjust_drop.text = "放下"
	_rest_adjust_drop.pressed.connect(func() -> void:
		_clear_rest_held()
		_render_rest_adjust_targets()
		_render_rest_adjust_columns()
	)
	action_row.add_child(_rest_adjust_drop)

	_rest_adjust_back = Button.new()
	_rest_adjust_back.text = "返回"
	_rest_adjust_back.pressed.connect(func() -> void:
		_hide_rest_adjust()
		_show_rest_root_options_again()
	)
	action_row.add_child(_rest_adjust_back)

func _show_rest_adjust(run: RunContext, seq_id: int, text2: String) -> void:
	_ensure_rest_adjust_layer()
	if not _rest_adjust_layer:
		return
	_rest_adjust_run = run
	_rest_adjust_seq_id = seq_id
	_rest_adjust_text2 = text2
	_clear_rest_held()
	_rest_adjust_layer.visible = true
	_render_rest_adjust_columns()
	_render_rest_adjust_targets()

func _hide_rest_adjust() -> void:
	if _rest_adjust_layer:
		_rest_adjust_layer.visible = false
	_rest_adjust_run = null
	_rest_adjust_seq_id = 0
	_rest_adjust_text2 = ""
	_clear_rest_held()

func _clear_rest_held() -> void:
	_rest_held_wheel = -1
	_rest_held_index = -1
	_rest_held_card_id = ""

func _render_rest_adjust_columns() -> void:
	if not _rest_adjust_columns:
		return
	for c in _rest_adjust_columns.get_children():
		c.queue_free()
	if not _rest_adjust_run:
		return
	var wheels: Array = _rest_adjust_run.get_wheels_snapshot()
	for wi in range(wheels.size()):
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_rest_adjust_columns.add_child(col)
		var head := Label.new()
		head.text = "弹匣 %d" % (wi + 1)
		head.horizontal_alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(head)
		var w = wheels[wi]
		var count := 0
		if typeof(w) == TYPE_ARRAY:
			count = (w as Array).size()
		elif typeof(w) == TYPE_PACKED_STRING_ARRAY:
			count = (w as PackedStringArray).size()
		else:
			continue
		for idx in range(count):
			var id := String(w[idx])
			var name := id
			if not _card_db:
				_card_db = CardDatabase.load_default()
			if _card_db:
				name = String(_card_db.get_card(id).get("name", id))
			var b := Button.new()
			b.text = name
			if wi == _rest_held_wheel and idx == _rest_held_index:
				b.modulate = Color(1.0, 0.65, 0.15)
			var wii := wi
			var ii := idx
			var cid := id
			b.pressed.connect(func() -> void:
				_on_rest_adjust_bullet_pressed(wii, ii, cid)
			)
			col.add_child(b)

func _render_rest_adjust_targets() -> void:
	if not _rest_adjust_target_row:
		return
	for c in _rest_adjust_target_row.get_children():
		c.queue_free()
	if not _rest_adjust_run:
		return
	var wheels: Array = _rest_adjust_run.get_wheels_snapshot()
	if _rest_held_wheel < 0:
		return
	var wheel_count: int = wheels.size()
	for wi in range(wheel_count):
		var b := Button.new()
		b.text = "放入轮%d" % (wi + 1)
		if wi == _rest_held_wheel:
			b.disabled = true
		elif not _can_place_card_to_wheel(_rest_held_card_id, wi, wheel_count):
			b.disabled = true
		var target := wi
		b.pressed.connect(func() -> void:
			_on_rest_adjust_target_pressed(target)
		)
		_rest_adjust_target_row.add_child(b)

func _can_place_card_to_wheel(card_id: String, wheel_index: int, wheel_count: int) -> bool:
	if card_id.is_empty() or wheel_index < 0 or wheel_index >= wheel_count:
		return false
	if not _card_db:
		_card_db = CardDatabase.load_default()
	if not _card_db:
		return true
	var def: Dictionary = _card_db.get_card(card_id)
	var constraints: Dictionary = def.get("constraints", {})
	var wheel_rule := String(constraints.get("wheel", ""))
	if wheel_rule == "last" and wheel_index != wheel_count - 1:
		return false
	return true

func _on_rest_adjust_bullet_pressed(wheel_index: int, entry_index: int, card_id: String) -> void:
	if _event_sequence_id != _rest_adjust_seq_id:
		return
	_rest_held_wheel = wheel_index
	_rest_held_index = entry_index
	_rest_held_card_id = card_id
	_render_rest_adjust_targets()
	_render_rest_adjust_columns()

func _on_rest_adjust_target_pressed(target_wheel: int) -> void:
	if _event_sequence_id != _rest_adjust_seq_id:
		return
	if not _rest_adjust_run:
		return
	if _rest_held_wheel < 0 or _rest_held_index < 0 or _rest_held_card_id.is_empty():
		return
	var src := _rest_held_wheel
	var idx := _rest_held_index
	var id := _rest_held_card_id
	if target_wheel == src:
		return
	var wheel_count: int = _rest_adjust_run.get_wheels_snapshot().size()
	if not _can_place_card_to_wheel(id, target_wheel, wheel_count):
		return
	if not _rest_adjust_run.remove_card_from_wheel(src, idx):
		return
	if not _rest_adjust_run.add_card_to_wheel(id, target_wheel):
		_rest_adjust_run.add_card_to_wheel(id, src)
		return
	_set_slot_pools_from_run(_rest_adjust_run)
	_hide_rest_adjust()
	event_option_selected.emit("adjust")
	var choice_msec: int = Time.get_ticks_msec()
	_start_event_result_sequence(_event_sequence_id, _rest_adjust_text2, choice_msec)

func _start_event_result_sequence(seq_id: int, result_text: String, choice_msec: int) -> void:
	call_deferred("_run_event_result_sequence", seq_id, result_text, choice_msec)

func _show_rest_root_options_again() -> void:
	if not _event_layer or not _event_layer.visible:
		return
	if _event_continue_button:
		_event_continue_button.visible = false
		_event_continue_button.disabled = true
	if _event_options_box:
		_event_options_box.visible = true
	_schedule_event_layout()

func show_event_remove_bullet(run: RunContext) -> void:
	_ensure_event_remove_layer()
	if not _event_remove_layer:
		return
	_event_remove_run = run
	_render_event_remove_columns()
	_event_remove_layer.visible = true

func hide_event_remove_bullet() -> void:
	if _event_remove_layer:
		_event_remove_layer.visible = false
	_event_remove_run = null
	if _event_remove_columns:
		for c in _event_remove_columns.get_children():
			c.queue_free()

func _ensure_event_remove_layer() -> void:
	if _event_remove_layer:
		return
	if not _run_ui:
		return
	_event_remove_layer = Control.new()
	_event_remove_layer.name = "EventRemoveBulletLayer"
	_event_remove_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_event_remove_layer.visible = false
	_event_remove_layer.z_as_relative = false
	_event_remove_layer.z_index = 160
	_run_ui.add_child(_event_remove_layer)

	var backdrop := Button.new()
	backdrop.flat = true
	backdrop.focus_mode = Control.FOCUS_NONE
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.modulate = Color(0, 0, 0, 0.6)
	backdrop.pressed.connect(func() -> void:
		hide_event_remove_bullet()
		event_remove_bullet_cancelled.emit()
	)
	_event_remove_layer.add_child(backdrop)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -380
	panel.offset_top = -260
	panel.offset_right = 380
	panel.offset_bottom = 260
	_event_remove_layer.add_child(panel)

	var vb := VBoxContainer.new()
	panel.add_child(vb)

	var title := Label.new()
	title.text = "删除一个子弹"
	title.horizontal_alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(title)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(scroll)

	_event_remove_columns = HBoxContainer.new()
	_event_remove_columns.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_event_remove_columns)

	_event_remove_back = Button.new()
	_event_remove_back.text = "返回"
	_event_remove_back.pressed.connect(func() -> void:
		hide_event_remove_bullet()
		event_remove_bullet_cancelled.emit()
	)
	vb.add_child(_event_remove_back)

func _render_event_remove_columns() -> void:
	if not _event_remove_columns:
		return
	for c in _event_remove_columns.get_children():
		c.queue_free()
	if not _event_remove_run:
		return
	if not _card_db:
		_card_db = CardDatabase.load_default()
	var wheels: Array = _event_remove_run.get_wheels_snapshot()
	for wi in range(wheels.size()):
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_event_remove_columns.add_child(col)
		var head := Label.new()
		head.text = "弹匣 %d" % (wi + 1)
		head.horizontal_alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(head)
		var w = wheels[wi]
		var count := 0
		if typeof(w) == TYPE_ARRAY:
			count = (w as Array).size()
		elif typeof(w) == TYPE_PACKED_STRING_ARRAY:
			count = (w as PackedStringArray).size()
		else:
			continue
		for idx in range(count):
			var id := String(w[idx])
			var card_name := id
			if _card_db:
				card_name = String(_card_db.get_card(id).get("name", id))
			var b := Button.new()
			b.text = card_name
			var wii := wi
			var ii := idx
			b.pressed.connect(func() -> void:
				hide_event_remove_bullet()
				event_remove_bullet_selected.emit(wii, ii)
			)
			col.add_child(b)

func _schedule_event_layout() -> void:
	if _event_layout_scheduled:
		return
	_event_layout_scheduled = true
	call_deferred("_apply_event_layout")

func _apply_event_layout() -> void:
	_event_layout_scheduled = false
	if not _event_layer or not _event_layer.visible:
		return
	var bg: ColorRect = _event_layer.get_node_or_null("EventBackground") as ColorRect
	if _run_ui and _event_text and _run_ui.has_node("EventTextAnchor"):
		var anchor := _run_ui.get_node("EventTextAnchor")
		if anchor is Control:
			var rect := (anchor as Control).get_global_rect()
			_event_text.custom_minimum_size = Vector2(maxf(200.0, rect.size.x), 0)
			_event_text.global_position = rect.position
	elif _lane_slots.size() >= 8 and _event_text:
		var rect4 := (_lane_slots[3] as Control).get_global_rect()
		var rect8 := (_lane_slots[7] as Control).get_global_rect()
		var left_x := rect4.position.x
		var right_x := rect8.position.x + rect8.size.x
		var width: float = maxf(200.0, right_x - left_x)
		_event_text.custom_minimum_size = Vector2(width, 0)
		if _event_text.size.y <= 1.0 and _event_layout_retry < 2:
			_event_layout_retry += 1
			_schedule_event_layout()
			return
		_event_layout_retry = 0
		var y := rect4.position.y - _event_text.size.y - 12.0
		_event_text.global_position = Vector2(left_x, y)
	if bg and _event_text and _event_text.visible:
		var pad: float = 12.0
		bg.visible = true
		bg.global_position = _event_text.global_position - Vector2(pad, pad)
		bg.size = _event_text.size + Vector2(pad * 2.0, pad * 2.0)
	if _event_options_box:
		var target_rect := Rect2(Vector2(540, 820), Vector2(156, 56))
		if _run_ui and _run_ui.has_node("EventOptionAnchor"):
			var anchor := _run_ui.get_node("EventOptionAnchor")
			if anchor is Control:
				target_rect = (anchor as Control).get_global_rect()
		elif _reward_skip_button:
			target_rect = _reward_skip_button.get_global_rect()
		else:
			var vis := get_viewport().get_visible_rect()
			var sx := vis.size.x / 720.0
			var sy := vis.size.y / 1280.0
			target_rect = Rect2(
				vis.position + Vector2(540.0 * sx, 820.0 * sy),
				Vector2(156.0 * sx, 56.0 * sy)
			)

		_event_options_box.global_position = target_rect.position
		for c in _event_options_box.get_children():
			if c is Button:
				(c as Button).custom_minimum_size = target_rect.size
		if _event_continue_button:
			_event_continue_button.global_position = target_rect.position
			_event_continue_button.custom_minimum_size = target_rect.size

func _run_event_open_sequence(node: Dictionary, seq_id: int) -> void:
	if seq_id != _event_sequence_id:
		return
	await get_tree().process_frame
	if seq_id != _event_sequence_id:
		return
	await _play_event_enter_animation(seq_id)
	if seq_id != _event_sequence_id:
		return
	var data: Dictionary = {}
	if node.has("event") and typeof(node["event"]) == TYPE_DICTIONARY:
		data = node["event"]
	var text := String(data.get("text", ""))
	await _typewrite_event_text(text, seq_id)
	if seq_id != _event_sequence_id:
		return
	var options: Array = data.get("options", [])
	_render_event_options(options, seq_id)
	if _event_options_box:
		_event_options_box.visible = true
	_schedule_event_layout()

func _render_event_options(options: Array, seq_id: int) -> void:
	if not _event_options_box:
		return
	for c in _event_options_box.get_children():
		c.queue_free()
	var i := 0
	for x in options:
		if typeof(x) != TYPE_DICTIONARY:
			continue
		var o: Dictionary = x
		var id := String(o.get("id", "opt_%d" % i))
		var text := String(o.get("text", id))
		var rarity := String(o.get("rarity", ""))
		var btn := Button.new()
		btn.text = text
		if not rarity.is_empty():
			_apply_rarity_border(btn, rarity)
		var oid := id
		btn.pressed.connect(func() -> void:
			_on_event_option_pressed(seq_id, oid)
		)
		_event_options_box.add_child(btn)
		i += 1

func _on_event_option_pressed(seq_id: int, option_id: String) -> void:
	if seq_id != _event_sequence_id:
		return
	if _event_continue_button and _event_continue_button.visible:
		return
	if _event_options_box:
		_event_options_box.visible = false
	_event_choice_msec = Time.get_ticks_msec()
	event_option_selected.emit(option_id)
	_schedule_event_layout()

func event_show_result(result_text: String) -> void:
	if not _event_layer:
		return
	_event_layer.visible = true
	if _event_text:
		_event_text.visible = true
	_ensure_event_sequence_active()
	if _event_current_seq_id <= 0:
		return
	var choice_msec := _event_choice_msec
	if choice_msec <= 0:
		choice_msec = Time.get_ticks_msec()
	_start_event_result_sequence(_event_current_seq_id, result_text, choice_msec)

func event_show_options(options: Array[Dictionary]) -> void:
	if not _event_layer:
		return
	_event_layer.visible = true
	if _event_text:
		_event_text.visible = true
	_ensure_event_sequence_active()
	if _event_continue_button:
		_event_continue_button.visible = false
		_event_continue_button.disabled = true
	if _event_options_box:
		_render_event_options(options, _event_current_seq_id)
		_event_options_box.visible = true
	_schedule_event_layout()

func event_play_text_then_options(text: String, options: Array[Dictionary]) -> void:
	if not _event_layer:
		return
	_event_layer.visible = true
	if _event_text:
		_event_text.visible = true
	_ensure_event_sequence_active()
	if _event_continue_button:
		_event_continue_button.visible = false
		_event_continue_button.disabled = true
	if _event_options_box:
		_event_options_box.visible = false
	if _event_text:
		_event_text.text = ""
	_schedule_event_layout()
	var seq_id := _event_current_seq_id
	call_deferred("_run_event_text_then_options", seq_id, text, options)

func _ensure_event_sequence_active() -> void:
	if _event_current_seq_id > 0:
		return
	_event_sequence_id += 1
	_event_current_seq_id = _event_sequence_id
	_event_choice_msec = 0
	_schedule_event_layout()

func _run_event_text_then_options(seq_id: int, text: String, options: Array[Dictionary]) -> void:
	if seq_id != _event_sequence_id:
		return
	await _typewrite_event_text(text, seq_id)
	if seq_id != _event_sequence_id:
		return
	if _event_options_box:
		_render_event_options(options, seq_id)
		_event_options_box.visible = true
	_schedule_event_layout()

func _run_event_result_sequence(seq_id: int, result_text: String, choice_msec: int) -> void:
	if seq_id != _event_sequence_id:
		return
	await _typewrite_event_text(result_text, seq_id)
	if seq_id != _event_sequence_id:
		return
	if _event_continue_button:
		_event_continue_button.visible = true
		_event_continue_button.disabled = true
		_refresh_leave_button()
	_schedule_event_layout()
	var cooldown: float = _event_continue_cooldown_duration()
	var elapsed: float = float(Time.get_ticks_msec() - choice_msec) / 1000.0
	var remaining: float = cooldown - elapsed
	if remaining > 0.0:
		await get_tree().create_timer(remaining).timeout
	if seq_id != _event_sequence_id:
		return
	if _event_continue_button:
		_event_continue_button.disabled = false

func _on_event_continue_pressed() -> void:
	if not _event_layer or not _event_layer.visible:
		return
	if _event_continue_button and _event_continue_button.disabled:
		return
	_hide_event_layer()
	event_continue_pressed.emit()

func _play_event_enter_animation(seq_id: int) -> void:
	var dur: float = _event_enter_animation_duration()
	if dur <= 0.0:
		return
	if not _player_token or _lane_slots.size() < 2:
		await get_tree().create_timer(dur).timeout
		return
	var from_pos: Vector2 = _get_token_pos_for_cell(_player_token, 1)
	var to_pos: Vector2 = _get_token_pos_for_cell(_player_token, 2)
	_player_token.global_position = from_pos
	var tween: Tween = create_tween()
	tween.tween_property(_player_token, "global_position", to_pos, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await tween.finished
	if seq_id != _event_sequence_id:
		return
	_last_player_cell = 2
	_schedule_token_layout()

func _get_token_pos_for_cell(token: Control, cell: int) -> Vector2:
	var idx := clampi(cell, 1, _lane_slots.size()) - 1
	var slot: Control = _lane_slots[idx]
	var center := slot.get_global_rect().get_center()
	var token_size := token.size * token.scale
	return center - (token_size * 0.5)

func _typewrite_event_text(text: String, seq_id: int) -> void:
	if not _event_text:
		return
	var step: float = _event_char_step_seconds()
	if step <= 0.0:
		_event_text.text = text
		_schedule_event_layout()
		return
	_event_text.text = ""
	_schedule_event_layout()
	var i := 0
	while i < text.length():
		if seq_id != _event_sequence_id:
			return
		_event_text.text += text.substr(i, 1)
		i += 1
		_schedule_event_layout()
		await get_tree().create_timer(step).timeout

func _event_char_step_seconds() -> float:
	if _quick_mode_level == 1:
		return 0.03
	if _quick_mode_level == 2:
		return 0.0
	return 0.05

func _event_enter_animation_duration() -> float:
	if _quick_mode_level == 1:
		return 0.5
	if _quick_mode_level == 2:
		return 0.2
	return 1.2

func _event_continue_cooldown_duration() -> float:
	if _quick_mode_level == 1:
		return 0.5
	if _quick_mode_level == 2:
		return 0.2
	return 0.8

func _clear_screen_root() -> void:
	if not _screen_root:
		return
	for c in _screen_root.get_children():
		c.queue_free()
	_title_screen = null
	_run_ui = null
	_end_screen = null
