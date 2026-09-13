class_name WorldItemActor
extends Area2D
## Runtime representation of an item stack in the world. The actor owns the
## original stack, so mutable endurance survives inventory/equipment/world moves.

signal landed_at(actor: WorldItemActor)
signal item_depleted(actor: WorldItemActor, result: ItemDefinition)

var item_stack: ItemStack
var start_position := Vector2.ZERO
var landing_position := Vector2.ZERO
var flight_time := 0.55
var arc_height := 90.0
var elapsed := 0.0
var landed := false
var spin := 0.0
var light_source: LightSource2D
var _depleted := false
var source: Node2D
var _landing_age := 0.0
var _payload_fired := false


func launch(stack: ItemStack, start: Vector2, finish: Vector2, duration: float, height: float) -> void:

	item_stack = stack
	start_position = start
	landing_position = finish
	flight_time = maxf(duration, 0.1)
	arc_height = maxf(height, 12.0)
	global_position = start_position


func deploy(stack: ItemStack, position: Vector2, facing := 0.0) -> void:

	item_stack = stack
	start_position = position
	landing_position = position
	global_position = position
	rotation = facing
	landed = true


func _ready() -> void:

	z_index = 35
	collision_layer = 0
	collision_mask = 0
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(22, 13)
	collision.shape = shape
	add_child(collision)
	_build_item_behavior()
	queue_redraw()


func _physics_process(delta: float) -> void:

	if not landed:
		elapsed += delta
		var t := minf(elapsed / flight_time, 1.0)
		global_position = start_position.lerp(landing_position, t)
		spin = t * TAU * 1.35
		if t >= 1.0:
			landed = true
			spin = roundf(spin / (PI * 0.5)) * (PI * 0.5)
			rotation = (landing_position - start_position).angle()
			if light_source == null:
				_build_item_behavior()
			landed_at.emit(self)
		queue_redraw()
	_tick_endurance(delta)
	_tick_payload(delta)


func _tick_payload(delta: float) -> void:
	if not landed or _payload_fired or item_stack == null:
		return
	var payload := item_stack.definition.get_component(AreaEffectComponent) as AreaEffectComponent
	if payload == null:
		return
	_landing_age += delta
	queue_redraw()
	if _landing_age < payload.fuse_seconds:
		return
	_payload_fired = true
	var effect := AreaEffectActor.new()
	effect.payload = payload.duplicate() as AreaEffectComponent
	effect.source = source if is_instance_valid(source) else null
	effect.global_position = global_position
	get_parent().add_child(effect)
	item_stack = null # Payload is consumed exactly once.
	queue_free()


func extract_stack() -> ItemStack:

	if item_stack and item_stack.definition.get_component(AreaEffectComponent):
		return null # Armed payloads cannot return to inventory.
	var result := item_stack
	item_stack = null
	if light_source:
		light_source.queue_free()
	queue_free()
	return result


func _build_item_behavior() -> void:

	if item_stack == null or item_stack.definition == null:
		return
	var world_component := item_stack.definition.get_component(WorldActorComponent) as WorldActorComponent
	var emitter := item_stack.definition.get_component(LightEmitterComponent) as LightEmitterComponent
	if world_component == null or emitter == null:
		return
	if not landed and not world_component.activate_while_airborne:
		return
	light_source = LightSource2D.new()
	light_source.name = "DeployedItemLight"
	light_source.setup(emitter.light_config())
	add_child(light_source)
	_update_light_enabled()


func _tick_endurance(delta: float) -> void:

	if item_stack == null or item_stack.definition == null:
		return
	var endurance := item_stack.definition.get_component(EnduranceComponent) as EnduranceComponent
	if endurance == null or light_source == null or _depleted:
		return
	var current := item_stack.endurance(endurance)
	if current > 0.0:
		item_stack.set_endurance(endurance, current - endurance.drain_per_second * delta)
	_update_light_enabled()
	if item_stack.endurance(endurance) <= 0.0:
		_deplete(endurance)


func _update_light_enabled() -> void:

	if light_source == null or item_stack == null:
		return
	var endurance := item_stack.definition.get_component(EnduranceComponent) as EnduranceComponent
	light_source.set_owner_enabled(endurance == null or item_stack.endurance(endurance) > 0.0)


func _deplete(endurance: EnduranceComponent) -> void:

	_depleted = true
	if light_source:
		light_source.set_owner_enabled(false)
	var result := ItemCatalog.get_item(endurance.depleted_item_id) if endurance.depleted_item_id != &"" else null
	if result:
		item_stack.definition = result
		item_stack.runtime_values.clear()
		if light_source:
			light_source.queue_free()
			light_source = null
		queue_redraw()
	else:
		var world_component := item_stack.definition.get_component(WorldActorComponent) as WorldActorComponent
		if world_component and not world_component.remains_after_depletion:
			queue_free()
	item_depleted.emit(self, result)


func _draw() -> void:

	var t := minf(elapsed / flight_time, 1.0) if not landed else 1.0
	var lift := sin(PI * t) * arc_height if not landed else 0.0
	_draw_ellipse(Vector2.ZERO, Vector2(15.0, 6.0), Color(0.0, 0.0, 0.0, 0.34 if landed else 0.2))
	var center := Vector2(0.0, -lift)
	var base_color := Color("#8f4935")
	if item_stack:
		var payload := item_stack.definition.get_component(AreaEffectComponent) as AreaEffectComponent
		if payload:
			base_color = payload.color.darkened(0.4)
			if landed:
				draw_arc(Vector2.ZERO, payload.radius, 0, TAU, 96, Color(payload.color, 0.25), 1.0, true)
				draw_string(ThemeDB.fallback_font, Vector2(-22, -20), "%.1fs" % maxf(0.0, payload.fuse_seconds - _landing_age), HORIZONTAL_ALIGNMENT_CENTER, 44, 12, payload.color)
	if item_stack and item_stack.definition:
		if item_stack.definition.id == &"ash":
			base_color = Color("#39383e")
		else:
			var emitter := item_stack.definition.get_component(LightEmitterComponent) as LightEmitterComponent
			if emitter:
				base_color = emitter.color.darkened(0.42)
	var corners := PackedVector2Array([
		center + Vector2(-11, -7).rotated(spin), center + Vector2(11, -7).rotated(spin),
		center + Vector2(11, 7).rotated(spin), center + Vector2(-11, 7).rotated(spin),
	])
	draw_colored_polygon(corners, base_color)
	for index in corners.size():
		draw_line(corners[index], corners[(index + 1) % corners.size()], Color("#321d24"), 2.0, true)
	draw_line(center + Vector2(-6, -2).rotated(spin), center + Vector2(6, -2).rotated(spin), base_color.lightened(0.3), 2.0, true)


func _draw_ellipse(center: Vector2, radii: Vector2, color: Color) -> void:

	var points := PackedVector2Array()
	for index in 20:
		var angle := TAU * float(index) / 20.0
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	draw_colored_polygon(points, color)
