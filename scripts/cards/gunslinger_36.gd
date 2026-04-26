extends RefCounted

static func get_effect() -> Dictionary:
	return {"tags":["消耗"],"design_flags":{"fake_target":true,"hat_lost_texture":"res://设计方案/pics/drafts/角色草稿（假目标）.png"},"notes":["复杂效果按文本描述占位，当前战斗仅结算 damage/block/move。"],"move":0,"damage":0,"block":0}

static func get_timeline_seconds() -> float:
	return 0.0

