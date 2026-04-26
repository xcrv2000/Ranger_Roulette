extends Node

signal configured(wheel_count: int)
signal rolled(results: Array)

var wheels: Array = []

var _rng := RandomNumberGenerator.new()

var roll_initial_delay_seconds: float = 1.2
var default_wheel_interval_seconds: float = 0.8

func setup_default_3_wheels() -> void:
	set_wheels([
		PackedStringArray(["attack", "attack", "attack", "attack", "defend"]),
		PackedStringArray(["attack", "attack", "attack", "defend", "defend"]),
		PackedStringArray(["attack", "attack", "defend", "defend", "defend"]),
	])
	configured.emit(wheels.size())

func set_wheels(p_wheels: Array) -> void:
	wheels = []
	for w in p_wheels:
		wheels.append(_normalize_wheel(w))
	configured.emit(wheels.size())

func roll() -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	for wi in range(wheels.size()):
		var w: Array = wheels[wi]
		var candidates: Array[int] = []
		for ei in range(w.size()):
			var e: Dictionary = w[ei]
			var id := String(e.get("id", ""))
			if id.is_empty():
				continue
			if bool(e.get("consumed", false)):
				continue
			candidates.append(ei)
		if candidates.is_empty():
			results.append({"wheel_index": wi, "entry_index": -1, "id": ""})
			continue
		var pick_idx: int = int(candidates[_rng.randi_range(0, candidates.size() - 1)])
		var picked: Dictionary = w[pick_idx] as Dictionary
		results.append({"wheel_index": wi, "entry_index": pick_idx, "id": String(picked.get("id", ""))})
	rolled.emit(results)
	return results

func get_pool_snapshot() -> Array:
	var out: Array = []
	for w in wheels:
		out.append(_duplicate_wheel(w))
	return out

func set_entry_consumed(wheel_index: int, entry_index: int, consumed: bool = true) -> void:
	if wheel_index < 0 or wheel_index >= wheels.size():
		return
	var w: Array = wheels[wheel_index]
	if entry_index < 0 or entry_index >= w.size():
		return
	var e: Dictionary = (w[entry_index] as Dictionary).duplicate()
	e["consumed"] = consumed
	w[entry_index] = e
	wheels[wheel_index] = w

func _normalize_wheel(w: Variant) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if typeof(w) == TYPE_PACKED_STRING_ARRAY:
		for id in w:
			out.append({"id": String(id), "consumed": false})
		return out
	if typeof(w) == TYPE_ARRAY:
		for item in w:
			if typeof(item) == TYPE_STRING:
				out.append({"id": String(item), "consumed": false})
			elif typeof(item) == TYPE_DICTIONARY:
				var d: Dictionary = item
				out.append({"id": String(d.get("id", "")), "consumed": bool(d.get("consumed", false))})
		return out
	return out

func _duplicate_wheel(w: Variant) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if typeof(w) != TYPE_ARRAY:
		return out
	for item in w:
		if typeof(item) == TYPE_DICTIONARY:
			out.append((item as Dictionary).duplicate())
	return out
