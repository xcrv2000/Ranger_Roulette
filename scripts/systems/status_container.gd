class_name StatusContainer
extends RefCounted

signal changed

var _db: StatusDatabase
var _by_id: Dictionary = {}
var _script_cache: Dictionary = {}

func _init(db: StatusDatabase) -> void:
	_db = db

func add(status_id: String, delta_stacks: int = 1) -> void:
	if status_id.is_empty():
		return
	if delta_stacks == 0:
		return
	if _by_id.has(status_id):
		var inst: StatusInstance = _by_id[status_id]
		inst.stacks += delta_stacks
		if inst.stacks <= 0:
			_by_id.erase(status_id)
		changed.emit()
		return
	var stacks: int = delta_stacks
	if stacks <= 0:
		return
	var def: Dictionary = _db.get_status(status_id) if _db else {}
	var script: Script = _get_script_for(status_id, def)
	var inst: StatusInstance = StatusInstance.new(status_id, stacks, def, script)
	_by_id[status_id] = inst
	changed.emit()

func set_stacks(status_id: String, stacks: int) -> void:
	if status_id.is_empty():
		return
	if stacks <= 0:
		if _by_id.erase(status_id):
			changed.emit()
		return
	if _by_id.has(status_id):
		var inst: StatusInstance = _by_id[status_id]
		inst.stacks = stacks
		changed.emit()
		return
	var def: Dictionary = _db.get_status(status_id) if _db else {}
	var script: Script = _get_script_for(status_id, def)
	var inst: StatusInstance = StatusInstance.new(status_id, stacks, def, script)
	_by_id[status_id] = inst
	changed.emit()

func remove(status_id: String) -> void:
	if status_id.is_empty():
		return
	if _by_id.erase(status_id):
		changed.emit()

func get_stacks(status_id: String) -> int:
	if not _by_id.has(status_id):
		return 0
	var inst: StatusInstance = _by_id[status_id]
	return inst.stacks

func get_all() -> Array[StatusInstance]:
	var ids := _get_sorted_ids()
	var out: Array[StatusInstance] = []
	for id in ids:
		var inst: StatusInstance = _by_id[id]
		out.append(inst)
	return out

func dispatch(hook: String, ctx: Dictionary, payload: Dictionary) -> void:
	if hook.is_empty():
		return
	var ids := _get_sorted_ids()
	for id in ids:
		var inst: StatusInstance = _by_id[id]
		var s: Script = inst.hook_script
		if not s:
			continue
		if not s.has_method(hook):
			continue
		s.call(hook, ctx, payload, inst.stacks)

func to_state_array() -> Array[Dictionary]:
	var ids := _get_sorted_ids()
	var out: Array[Dictionary] = []
	for id in ids:
		var inst: StatusInstance = _by_id[id]
		out.append({"id": inst.id, "name": inst.get_name(), "stacks": inst.stacks})
	return out

func _get_sorted_ids() -> Array[String]:
	var keys: Array = _by_id.keys()
	var ids: Array[String] = []
	for k in keys:
		ids.append(String(k))
	ids.sort()
	return ids

func _get_script_for(status_id: String, def: Dictionary) -> Script:
	if _script_cache.has(status_id):
		return _script_cache[status_id]
	var path := String(def.get("script", ""))
	if path.is_empty():
		_script_cache[status_id] = null
		return null
	var s: Script = load(path) as Script
	_script_cache[status_id] = s
	return s
