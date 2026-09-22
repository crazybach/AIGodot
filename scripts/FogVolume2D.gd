class_name FogVolume2D
extends Node2D
## A local mist reservoir. Opening its associated door grows a soft 2D density
## field instead of simulating individual fluid cells.

@export var radius := 260.0
@export var density := 0.32
@export var spread_radius := 640.0
@export var release_speed := 0.18
@export var fog_tint := Color(0, 0, 0, 0) # alpha zero preserves atmospheric color

var is_releasing := false
var release_amount := 0.0


func _ready() -> void:

	add_to_group(&"fog_volumes")


func _process(delta: float) -> void:

	var target := 1.0 if is_releasing else 0.0
	release_amount = move_toward(release_amount, target, release_speed * delta)


func open() -> void:

	is_releasing = true


func close() -> void:

	is_releasing = false


func shader_data() -> Vector4:

	var expansion := lerpf(radius, spread_radius, release_amount)
	return Vector4(global_position.x, global_position.y, expansion, density * release_amount)
