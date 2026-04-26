extends RefCounted

static func before_deal_damage(_ctx: Dictionary, payload: Dictionary, _stacks: int) -> void:
	var damage: int = int(payload.get("damage", 0))
	payload["damage"] = int(floor(float(damage) * 0.5))

