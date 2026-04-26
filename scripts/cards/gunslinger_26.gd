extends RefCounted

static func get_effect() -> Dictionary:
	return {"tags":["补射","延迟触发"],"notes":["复杂效果按文本描述占位，当前战斗仅结算 damage/block/move。"],"damage":0,"move":-1,"block":12}

static func get_timeline_seconds() -> float:
	return 0.0

