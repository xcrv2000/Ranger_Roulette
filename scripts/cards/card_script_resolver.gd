class_name CardScriptResolver
extends RefCounted

var _db: CardDatabase
var _script_cache: Dictionary = {}

func _init(db: CardDatabase) -> void:
	_db = db

func get_card(id: String) -> Dictionary:
	if not _db:
		return {}
	return _db.get_card(id)

func get_card_name(id: String) -> String:
	var c := get_card(id)
	return String(c.get("name", id))

func get_card_text(id: String) -> String:
	var c := get_card(id)
	return String(c.get("text", ""))

func get_effect(id: String) -> Dictionary:
	var script: Script = _get_script_for(id)
	if script:
		var eff: Variant = null
		if script.has_method("get_effect_for"):
			eff = script.call("get_effect_for", id)
		else:
			eff = script.call("get_effect")
		if typeof(eff) == TYPE_DICTIONARY:
			return eff
	return {}

func get_timeline_seconds(id: String) -> float:
	var script: Script = _get_script_for(id)
	if script:
		if script.has_method("get_timeline_seconds_for"):
			return float(script.call("get_timeline_seconds_for", id))
		if script.has_method("get_timeline_seconds"):
			return float(script.call("get_timeline_seconds"))
	return 0.0

func get_quick_playback_mode(id: String) -> String:
	# 预留：快战截断长动画时，默认播放“结尾片段（tail）”而非开头。
	var c := get_card(id)
	return String(c.get("quick_playback_mode", "tail"))

func _get_script_for(id: String) -> Script:
	if _script_cache.has(id):
		return _script_cache[id]
	if id.begins_with("gunslinger_"):
		var s: Script = load("res://scripts/cards/gunslinger_pack.gd") as Script
		_script_cache[id] = s
		return s
	var c := get_card(id)
	var path := String(c.get("script", ""))
	if path.is_empty():
		_script_cache[id] = null
		return null
	var s: Script = load(path) as Script
	_script_cache[id] = s
	return s
