class_name LauncherComponent
extends ItemComponent
## A weapon chamber or launcher. It consumes an ItemDefinition with a matching tag.

@export var ammo_tag: StringName = &"ammo_9mm"
@export var magazine_size := 15
@export var reload_time := 1.2
@export var fire_rate := 0.18
@export var projectile_speed := 600.0
@export var projectile_damage := 25.0
