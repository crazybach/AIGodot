class_name ThrowConfig
extends RefCounted
## Hand-thrown trajectories use item IDs, separate from launcher ammunition ranges.
const PATH := "res://data/throwables.cfg"

static func apply(items: Dictionary, path := PATH) -> Error:
	var config := ConfigFile.new()
	var error := config.load(path)
	if error != OK: return error
	var ranges: Dictionary = {}
	for section in config.get_sections():
		var value: Variant = config.get_value(section, "max_range", 260.0)
		if not (value is float or value is int) or not is_finite(float(value)) or float(value) <= 0:
			return ERR_INVALID_DATA
		ranges[section] = float(value)
	for id in items:
		var item: ItemDefinition = items[id]
		for part in item.components:
			if part is AimComponent and part.strategy == AimComponent.LOB:
				part.max_distance = ranges.get(String(id), ranges.get("default", 260.0))
				part.min_distance = minf(part.min_distance, part.max_distance)
	return OK
