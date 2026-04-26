class_name EnemyDatabase
extends RefCounted

var _enemies_by_id: Dictionary = {}
var _order: Array[String] = []

static func load_default() -> EnemyDatabase:
	var db := EnemyDatabase.new()
	db.load_from_path("res://data/enemies.json")
	return db

func load_from_path(path: String) -> void:
	_enemies_by_id.clear()
	_order = []
	if not FileAccess.file_exists(path):
		return
	var f := FileAccess.open(path, FileAccess.READ)
	if not f:
		return
	var text := f.get_as_text()
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var root: Dictionary = parsed
	var enemies: Array = root.get("enemies", [])
	for item in enemies:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var e: Dictionary = item
		var id := String(e.get("id", ""))
		if id.is_empty():
			continue
		_enemies_by_id[id] = e
		_order.append(id)

func get_enemy(id: String) -> Dictionary:
	return _enemies_by_id.get(id, {})

func get_all_ids() -> Array[String]:
	var out: Array[String] = []
	out.assign(_order)
	return out

func get_ids_by_pool(pool: String) -> Array[String]:
	var out: Array[String] = []
	for id in _order:
		var e: Dictionary = _enemies_by_id.get(id, {})
		if String(e.get("random_pool", "")) != pool:
			continue
		out.append(id)
	return out

func roll_enemy_id(pool: String, rng: RandomNumberGenerator) -> String:
	var total_weight := 0
	var ids: Array[String] = []
	var weights: Array[int] = []
	for id in _order:
		var e: Dictionary = _enemies_by_id.get(id, {})
		if String(e.get("random_pool", "")) != pool:
			continue
		var w := int(e.get("weight", 1))
		if w <= 0:
			continue
		ids.append(id)
		weights.append(w)
		total_weight += w
	if ids.is_empty() or total_weight <= 0:
		return ""
	var r := rng.randi_range(1, total_weight)
	var acc := 0
	for i in range(ids.size()):
		acc += weights[i]
		if r <= acc:
			return ids[i]
	return ids[ids.size() - 1]
