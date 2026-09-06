class_name ProjectileComponent
extends ItemComponent
## Data for ammunition and thrown objects. Damage may intentionally be zero.

@export var damage := 0.0
@export var speed := 500.0
@export var range := 650.0
@export var effect: StringName = &"impact"
