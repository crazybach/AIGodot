@tool
class_name InteriorProp
extends Node2D
## Reusable editor prop: physical furniture, optional persistent item container.
@export var title := "Supply cabinet"
@export_enum("wall", "shelf", "closet", "counter", "crate", "bench", "planter", "table", "floor") var kind := "closet"
@export var size := Vector2(64, 36)
@export var tint := Color("#77827c")
@export var solid := true
@export var storage_enabled := true
@export var slot_capacity := 8
@export var weight_capacity := 40.0
@export var starting_items: Dictionary = {}
var inventory: ItemContainerComponent
var body: StaticBody2D
var prompt: String:
	get: return "Search " + title

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	if solid:
		body = StaticBody2D.new()
		var shape := RectangleShape2D.new()
		shape.size = size
		var collider := CollisionShape2D.new()
		collider.shape = shape
		body.add_child(collider)
		add_child(body)
	if storage_enabled:
		inventory = ItemContainerComponent.new()
		inventory.container_title = title
		inventory.slot_capacity = slot_capacity
		inventory.weight_capacity = weight_capacity
		add_child(inventory)
		for id in starting_items:
			inventory.add_item(ItemCatalog.get_item(StringName(id)), int(starting_items[id]))
		inventory.contents_changed.connect(queue_redraw)
	queue_redraw()

func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		queue_redraw()

func can_interact(actor: Node2D) -> bool:
	if not storage_enabled or not is_inside_tree():
		return false
	var nearest := to_global(to_local(actor.global_position).clamp(-size / 2, size / 2))
	if actor.global_position.distance_to(nearest) > 58:
		return false
	var query := PhysicsRayQueryParameters2D.create(actor.global_position, global_position, 1, [actor.get_rid()])
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	return hit.is_empty() or hit.get("collider") == body

func stream_snapshot() -> Dictionary:
	var saved: Array = []
	if inventory:
		for stack in inventory.slots:
			saved.append(null if stack == null else {"id": stack.definition.id, "quantity": stack.quantity, "values": stack.runtime_values.duplicate(true)})
	return {"slots": saved}

func stream_restore(saved: Dictionary) -> void:
	if inventory == null or not saved.has("slots"): return
	var entries: Array = saved.slots
	inventory.slots.fill(null)
	for index in mini(entries.size(), inventory.slots.size()):
		var row = entries[index]
		if row != null:
			inventory.slots[index] = ItemStack.new(ItemCatalog.get_item(StringName(row.id)), int(row.quantity), row.values)
	inventory.notify_changed()

func _draw() -> void:
	var rect := Rect2(-size / 2, size)
	draw_rect(Rect2(rect.position + Vector2(4, 5), rect.size), Color(0.035, 0.055, 0.065, 0.7))
	draw_rect(rect, tint)
	draw_rect(rect, tint.lightened(0.25), false, 1.5)
	match kind:
		"shelf", "closet", "crate":
			for x in range(int(-size.x / 2) + 12, int(size.x / 2), 24):
				draw_line(Vector2(x, -size.y / 2 + 4), Vector2(x, size.y / 2 - 4), tint.darkened(0.35), 2)
			if kind == "shelf":
				for x in range(int(-size.x / 2) + 8, int(size.x / 2) - 8, 18):
					draw_rect(Rect2(x, -size.y / 2 + 7, 11, size.y - 15), Color("#b6ac83"))
		"planter":
			draw_circle(Vector2.ZERO, minf(size.x, size.y) * 0.38, Color("#416656"), true, -1, true)
		"table":
			draw_rect(rect.grow(-5), tint.lightened(0.12), false, 2)
	if storage_enabled:
		var available := inventory == null or inventory.slots.any(func(stack): return stack != null)
		draw_circle(Vector2(size.x / 2 - 7, size.y / 2 - 7), 3, Color("#e3c785") if available else Color("#495b5d"), true, -1, true)
