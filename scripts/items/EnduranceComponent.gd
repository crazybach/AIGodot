class_name EnduranceComponent
extends ItemComponent
## Mutable endurance is stored by ItemStack; this Resource only defines rules.

@export var maximum := 100.0
@export var drain_per_second := 1.0
@export var depleted_item_id: StringName
@export var refill_item_tag: StringName
@export var refill_amount := 50.0


func can_refill_from(definition: ItemDefinition) -> bool:

	return definition != null and refill_item_tag != &"" and definition.has_tag(refill_item_tag)
