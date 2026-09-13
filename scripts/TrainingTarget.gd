class_name TrainingTarget
extends Creature

var readout: Label
var total_damage := 0.0

func _setup_creature() -> void:
	add_to_group(&"training_targets")
	health_comp = _add_component(HealthComponent.new()) as HealthComponent
	health_comp.configure(10000, Color.WHITE, 0.04)
	health_comp.damaged.connect(_on_damage)
	build_collision(18)
	collision_layer = 1
	collision_mask = 0
	readout = Label.new()
	readout.position = Vector2(-85, -58)
	readout.size = Vector2(170, 32)
	readout.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	readout.add_theme_font_size_override("font_size", 13)
	readout.text = "TRAINING TARGET"
	add_child(readout)
	z_index = 32

func _on_damage(amount: float) -> void:
	total_damage += amount
	readout.text = "-%.1f HP | total %.1f" % [amount, total_damage]

func _draw() -> void:
	draw_circle(Vector2.ZERO, 19, Color("#3a4550"))
	for radius in [6.0, 12.0, 18.0]:
		draw_arc(Vector2.ZERO, radius, 0, TAU, 64, Color("#d8c197"), 1.5, true)
