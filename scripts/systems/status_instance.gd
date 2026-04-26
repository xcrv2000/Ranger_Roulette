class_name StatusInstance
extends RefCounted

var id: String = ""
var stacks: int = 0
var def: Dictionary = {}
var hook_script: Script

func _init(p_id: String, p_stacks: int, p_def: Dictionary, p_script: Script) -> void:
	id = p_id
	stacks = p_stacks
	def = p_def
	hook_script = p_script

func get_name() -> String:
	return String(def.get("name", id))

func get_text() -> String:
	return String(def.get("text", ""))
