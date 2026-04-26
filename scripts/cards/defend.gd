extends RefCounted

static func get_effect() -> Dictionary:
	return {"damage": 0, "move": -1, "block": 5, "tags": ["测试"], "notes": ["测试卡。"]}

static func get_timeline_seconds() -> float:
	return 0.0
