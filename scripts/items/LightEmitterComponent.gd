class_name LightEmitterComponent
extends ItemComponent
## Declarative light data shared by equipped and deployed item systems.

@export var light_type: LightSource2D.LightType = LightSource2D.LightType.POINT
@export var color := Color(1.0, 0.88, 0.62)
@export var range := 240.0
@export var energy := 1.4
@export var spot_angle := 25.0
@export var flicker := false
@export var flicker_amount := 0.08
@export var flicker_speed := 9.0
@export var shimmer := false
@export var cast_shadows := true
@export var fog_range_multiplier := 0.9
@export var fog_clear_strength := 0.76


func light_config() -> Dictionary:

	return {
		"type": light_type,
		"color": color,
		"range": range,
		"energy": energy,
		"spot_angle": spot_angle,
		"flicker": flicker,
		"flicker_amount": flicker_amount,
		"flicker_speed": flicker_speed,
		"shimmer": shimmer,
		"cast_shadows": cast_shadows,
		"auto_day_night": false,
		"fog_range_multiplier": fog_range_multiplier,
		"fog_clear_strength": fog_clear_strength,
	}
