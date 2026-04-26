class_name EventDatabase
extends RefCounted

var _events_by_id: Dictionary = {}
var _order: Array[String] = []

static func load_default() -> EventDatabase:
	var db := EventDatabase.new()
	db.load_from_path("res://data/events.json")
	return db

func load_from_path(path: String) -> void:
	_events_by_id.clear()
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
	var arr: Array = root.get("events", [])
	for item in arr:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var e: Dictionary = item
		var id := String(e.get("id", ""))
		if id.is_empty():
			continue
		_events_by_id[id] = e
		_order.append(id)

func get_event(id: String) -> Dictionary:
	return _events_by_id.get(id, {})

func get_all_ids() -> Array[String]:
	return _order.duplicate()
