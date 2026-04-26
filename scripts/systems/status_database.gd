class_name StatusDatabase
extends RefCounted

var _statuses_by_id: Dictionary = {}
var _order: Array[String] = []

static func load_default() -> StatusDatabase:
	var db := StatusDatabase.new()
	db.load_from_path("res://data/statuses.json")
	return db

func load_from_path(path: String) -> void:
	_statuses_by_id.clear()
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
	var statuses: Array = root.get("statuses", [])
	for item in statuses:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var s: Dictionary = item
		var id: String = String(s.get("id", ""))
		if id.is_empty():
			continue
		_statuses_by_id[id] = s
		_order.append(id)

func get_status(id: String) -> Dictionary:
	return _statuses_by_id.get(id, {})

func get_all_ids() -> Array[String]:
	var out: Array[String] = []
	out.assign(_order)
	return out
