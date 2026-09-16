class_name WorldLayerDefinition
extends Resource
## Stable address and environment policy; geometry/actors belong to WorldLayer.
@export var id: StringName
@export var display_name := "Unknown floor"
@export var mist_exposure := false
@export var night_ambient := Color(0.13, 0.15, 0.24)
@export var stamina_drain := 1.2
@export var exhausted_damage := 3.0
@export var entries: Dictionary = {}
## Future indoor-only room layers opt out of precipitation entirely.
@export var outdoor_weather := true
@export var buildings_shelter_weather := false
