class_name CharacterAttributes
extends Node
## Per-character modifiers. Never write bonuses into shared item/config resources.
signal changed

const STAT_NAMES := {
	"weapon_range": "Weapon range", "weapon_crit": "Critical chance",
	"reload_time": "Reload time", "weapon_damage": "Weapon damage",
	"weapon_spread": "Weapon spread", "charge_time": "Bow draw time",
	"max_stamina": "Maximum stamina", "stamina_recovery": "Stamina recovery",
	"action_cost": "Action stamina cost"
}
var _sources: Dictionary = {}

func set_source(id: StringName, modifiers: Array) -> void:
	_sources[id] = modifiers.duplicate(true)
	changed.emit()

func remove_source(id: StringName) -> void:
	if _sources.erase(id): changed.emit()

func resolve(stat: String, base: float) -> float:
	var flat := 0.0
	var percent := 0.0
	for modifiers in _sources.values():
		for modifier in modifiers:
			if modifier.stat != stat: continue
			flat += float(modifier.get("flat", 0.0))
			percent += float(modifier.get("percent", 0.0))
	return (base + flat) * maxf(0.0, 1.0 + percent)

static func describe(modifier: Dictionary, ranks := 1) -> String:
	var amount := float(modifier.get("flat", 0.0)) * ranks
	var suffix := ""
	if modifier.has("percent"):
		amount = float(modifier.percent) * 100.0 * ranks
		suffix = "%"
	elif modifier.stat == "weapon_crit":
		amount *= 100.0
		suffix = " percentage points"
	return "%s: %+.1f%s" % [STAT_NAMES.get(modifier.stat, modifier.stat), amount, suffix]
