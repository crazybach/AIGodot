class_name ConstructionComponent
extends ItemComponent
## Material capability consumed by a matching authored construction site.
@export var construction_kind: StringName = &"roof_crossing"

func _init() -> void:
	component_id = &"construction"

