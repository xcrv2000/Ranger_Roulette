class_name RunContext
extends RefCounted

var gold: int = 0
var max_hp: int = 50
var hp: int = 50
var quick_mode_level: int = 0
var slot_wheels: Array = []
var locked_wheels: Array[bool] = []
var hat_lost: bool = false
var next_battle_start_block: int = 0
var seen_event_ids: Array[String] = []

func reset() -> void:
	gold = 0
	max_hp = 50
	hp = max_hp
	quick_mode_level = 0
	hat_lost = false
	next_battle_start_block = 0
	seen_event_ids = []
	slot_wheels = [
		PackedStringArray(["attack", "attack", "attack", "defend"]),
		PackedStringArray(["attack", "attack", "defend", "defend"]),
		PackedStringArray(["attack", "defend", "defend", "defend"]),
		PackedStringArray(["attack", "attack", "attack", "attack"]),
	]
	locked_wheels = [false, false, false, true]

func get_locked_wheels_snapshot() -> Array:
	return locked_wheels.duplicate()

func is_wheel_locked(wheel_index: int) -> bool:
	if wheel_index < 0 or wheel_index >= locked_wheels.size():
		return false
	return bool(locked_wheels[wheel_index])

func get_last_unlocked_wheel_index() -> int:
	for i in range(slot_wheels.size() - 1, -1, -1):
		if not is_wheel_locked(i):
			return i
	return -1

func set_wheel_locked(wheel_index: int, locked: bool) -> void:
	if wheel_index < 0:
		return
	while locked_wheels.size() <= wheel_index:
		locked_wheels.append(false)
	locked_wheels[wheel_index] = locked

func set_locked_wheels(values: Array) -> void:
	locked_wheels = []
	for v in values:
		locked_wheels.append(bool(v))

func add_gold(amount: int) -> void:
	gold = max(0, gold + amount)

func set_gold(value: int) -> void:
	gold = max(0, value)

func set_hp(value: int) -> void:
	hp = clampi(value, 0, max_hp)

func heal_to_at_least_half() -> void:
	var threshold: float = float(max_hp) * 0.5
	var heal_amount: int = int(ceili(float(max_hp) * 0.5))
	if float(hp) > threshold:
		set_hp(max_hp)
	else:
		set_hp(hp + heal_amount)

func add_card_to_wheel(card_id: String, wheel_index: int) -> bool:
	if card_id.is_empty():
		return false
	if wheel_index < 0 or wheel_index >= slot_wheels.size():
		return false
	if is_wheel_locked(wheel_index):
		return false
	var last_wheel_index := get_last_unlocked_wheel_index()
	if last_wheel_index < 0:
		return false
	var db := CardDatabase.load_default()
	var def := db.get_card(card_id)
	var constraints: Dictionary = def.get("constraints", {})
	if String(constraints.get("wheel", "")) == "last" and wheel_index != last_wheel_index:
		return false
	var w = slot_wheels[wheel_index]
	w.append(card_id)
	slot_wheels[wheel_index] = w
	return true

func insert_card_to_wheel(card_id: String, wheel_index: int, entry_index: int, ignore_constraints: bool = false) -> bool:
	if card_id.is_empty():
		return false
	if wheel_index < 0 or wheel_index >= slot_wheels.size():
		return false
	if is_wheel_locked(wheel_index):
		return false
	if not ignore_constraints:
		var last_wheel_index := get_last_unlocked_wheel_index()
		if last_wheel_index < 0:
			return false
		var db := CardDatabase.load_default()
		var def := db.get_card(card_id)
		var constraints: Dictionary = def.get("constraints", {})
		if String(constraints.get("wheel", "")) == "last" and wheel_index != last_wheel_index:
			return false
	var w = slot_wheels[wheel_index]
	var arr: Array[String] = []
	if typeof(w) == TYPE_ARRAY:
		for x in (w as Array):
			arr.append(String(x))
	elif typeof(w) == TYPE_PACKED_STRING_ARRAY:
		for x in (w as PackedStringArray):
			arr.append(String(x))
	var idx := clampi(entry_index, 0, arr.size())
	arr.insert(idx, card_id)
	slot_wheels[wheel_index] = PackedStringArray(arr)
	return true

func remove_card_from_wheel(wheel_index: int, entry_index: int) -> bool:
	if wheel_index < 0 or wheel_index >= slot_wheels.size():
		return false
	if is_wheel_locked(wheel_index):
		return false
	var w = slot_wheels[wheel_index]
	if entry_index < 0 or entry_index >= w.size():
		return false
	w.remove_at(entry_index)
	slot_wheels[wheel_index] = w
	return true

func get_wheels_snapshot() -> Array:
	var out: Array = []
	for w in slot_wheels:
		out.append(w.duplicate())
	return out

func has_seen_event(event_id: String) -> bool:
	if event_id.is_empty():
		return false
	return seen_event_ids.has(event_id)

func mark_event_seen(event_id: String) -> void:
	if event_id.is_empty():
		return
	if not seen_event_ids.has(event_id):
		seen_event_ids.append(event_id)
