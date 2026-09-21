class_name QuestLocationTrigger
extends Area2D
## Editor extension point: add a CollisionShape2D and a stable location ID.
@export var location_id: StringName

func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	body_entered.connect(func(body):
		if body is Player and body.quest_log: body.quest_log.arrive(location_id))
