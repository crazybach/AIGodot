class_name AreaEffectActor
extends Node2D
## One detonation plus optional persistent ground hazard. No damage after expiry.

var payload: AreaEffectComponent
var source: Node2D
var age := 0.0
var _damage_clock := 0.0
var _detonated := false
var decal: Sprite2D

func _ready() -> void:
	z_index = 28
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var path := "res://assets/vfx/acid_pool.png" if payload.damage_type == &"acid" else "res://assets/vfx/fire_ground.png"
	if payload.duration > 0.0 and ResourceLoader.exists(path):
		decal = Sprite2D.new()
		decal.texture = load(path)
		# Generated artwork includes a transparent margin.
		decal.scale = Vector2.ONE * payload.radius * 2.25 / decal.texture.get_width()
		add_child(decal)
	if payload.damage_type == &"fire":
		var light := LightSource2D.new()
		light.setup({"type": LightSource2D.LightType.POINT, "color": payload.color,
			"range": payload.radius * 2.2, "energy": 0.8, "pixel_steps": 0, "flicker": true})
		add_child(light)

func _physics_process(delta: float) -> void:
	if not _detonated:
		_detonated = true
		_apply_damage(0.0, true)
	var step := minf(delta, maxf(0.0, payload.duration - age))
	age += delta
	_damage_clock += step
	if _damage_clock >= 0.25 or (age >= payload.duration and _damage_clock > 0.0):
		_apply_damage(_damage_clock, false)
		_damage_clock = 0.0
	if decal:
		decal.modulate.a = minf(0.82, maxf(0.0, payload.duration - age) / 0.6)
	if age >= maxf(payload.duration, 0.65):
		queue_free()
	queue_redraw()

func _apply_damage(seconds: float, impact: bool) -> void:
	for node in get_tree().get_nodes_in_group(&"damage_receivers"):
		var target := node as Creature
		if target == null or not target.is_alive or (target == source and not payload.hurts_owner):
			continue
		var distance := global_position.distance_to(target.global_position)
		if distance > payload.radius or not _line_of_sight(target):
			continue
		var amount := payload.damage_at_distance(distance) if impact else payload.damage_per_second * seconds
		if amount > 0.0:
			target.receive_damage(amount, payload.damage_type)

func _line_of_sight(target: Creature) -> bool:
	var ray := PhysicsRayQueryParameters2D.create(global_position, target.global_position, 1)
	ray.exclude = target.damage_collision_rids()
	if is_instance_valid(source) and source is CollisionObject2D and source != target:
		ray.exclude.append(source.get_rid())
	return get_world_2d().direct_space_state.intersect_ray(ray).is_empty()

func _draw() -> void:
	if payload == null:
		return
	var burst := clampf(age / 0.55, 0.0, 1.0)
	if burst < 1.0:
		var color := Color(payload.color, (1.0 - burst) * 0.7)
		draw_arc(Vector2.ZERO, maxf(1.0, payload.radius * burst), 0, TAU, 96, color, 2.0, true)
		for i in 20:
			var direction := Vector2.RIGHT.rotated(float(i) * 2.39996)
			var point := direction * payload.radius * burst * (0.4 + float(i % 5) * 0.14)
			draw_line(point, point - direction * 9.0 * (1.0 - burst), color, 1.8, true)
	if payload.duration > 0.0 and age < payload.duration:
		var remaining := 1.0 - age / payload.duration
		for i in 18:
			var phase := fposmod(age * 0.75 + float(i) * 0.618, 1.0)
			var origin := Vector2.RIGHT.rotated(float(i) * 2.4) * payload.radius * (0.25 + float(i % 7) * 0.085)
			var point := origin + Vector2(sin(age + i) * 4.0, -phase * 26.0)
			var tint := Color(payload.color, sin(PI * phase) * 0.52)
			if payload.damage_type == &"acid":
				draw_arc(point, 1.5 + phase * 2.0, 0, TAU, 16, tint, 1.0, true)
			else:
				draw_line(point, point + Vector2(1.0, -4.0), tint, 1.5, true)
		draw_arc(Vector2.ZERO, payload.radius, -PI * 0.5, -PI * 0.5 + TAU * remaining, 96, Color(payload.color, 0.34), 1.2, true)
		draw_string(ThemeDB.fallback_font, Vector2(-42, -payload.radius - 8), "%s %.1fs" % [String(payload.damage_type).to_upper(), payload.duration - age], HORIZONTAL_ALIGNMENT_CENTER, 84, 11, payload.color)
