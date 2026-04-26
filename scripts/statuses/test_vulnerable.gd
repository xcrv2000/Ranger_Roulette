extends RefCounted

static func before_take_damage(_ctx: Dictionary, payload: Dictionary, stacks: int) -> void:
	var damage: int = int(payload.get("damage", 0))
	var mult: float = 1.0 + (0.5 * float(max(0, stacks)))
	payload["damage"] = int(floor(float(damage) * mult))
