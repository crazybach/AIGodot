class_name QuickSlotRules
extends RefCounted
## Shared binding policy; inventory is the single source of binding IDs.
const COUNT := 8

static func label(index: int) -> String:
	if index < 2: return "WEAPON %d" % (index + 1)
	if index == 2: return "THROWABLE"
	return "QUICK USE %d" % (index - 2)

static func accepts(index: int, item: ItemDefinition) -> bool:
	if index < 0 or index >= COUNT: return false
	if item == null: return true
	if index < 2:
		return item.get_component(LauncherComponent) != null and item.get_component(EquippableComponent) != null
	if index == 2:
		if item.get_component(ProjectileComponent) == null or item.get_component(EquippableComponent) == null: return false
		for part in item.components:
			if part is AimComponent and part.strategy == AimComponent.LOB: return true
		return false
	return item.get_component(ConsumableComponent) != null or item.has_tag(&"battery") or item.get_component(LightEmitterComponent) != null
