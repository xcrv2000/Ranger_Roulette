extends RefCounted

static func before_deal_damage(_ctx: Dictionary, payload: Dictionary, stacks: int) -> void:
	var damage: int = int(payload.get("damage", 0))
	payload["damage"] = damage + max(0, stacks)

