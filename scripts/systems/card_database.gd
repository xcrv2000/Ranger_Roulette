class_name CardDatabase
extends RefCounted

var _cards_by_id: Dictionary = {}
var _order: Array[String] = []

static func load_default() -> CardDatabase:
	var db := CardDatabase.new()
	db.load_from_path("res://data/cards.json")
	return db

func load_from_path(path: String) -> void:
	_cards_by_id.clear()
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
	var cards: Array = root.get("cards", [])
	for item in cards:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var c: Dictionary = item
		var id := String(c.get("id", ""))
		if id.is_empty():
			continue
		_cards_by_id[id] = c
		_order.append(id)

func get_card(id: String) -> Dictionary:
	return _cards_by_id.get(id, {})

func get_all_ids() -> Array[String]:
	var out: Array[String] = []
	out.assign(_order)
	return out

func get_all_cards() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for id in _order:
		out.append(get_card(id))
	return out
