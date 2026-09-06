class_name ItemDefinition
extends Resource
## Immutable item template. Runtime quantities live in ItemStack.

@export var id: StringName
@export var display_name := "Unnamed item"
@export_multiline var description := ""
@export var weight := 0.0
@export var max_stack := 1
@export var tags: Array[StringName] = []
@export var components: Array[ItemComponent] = []


func has_tag(tag: StringName) -> bool:

	return tags.has(tag)


func get_component(component_class) -> ItemComponent:

	for component in components:
		if is_instance_of(component, component_class):
			return component
	return null
