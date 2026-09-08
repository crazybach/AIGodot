class_name AimComponent
extends ItemComponent
## Describes how an item is targeted. Execution stays in LauncherComponent or
## ProjectileComponent, allowing new strategies (charged bow, beam, cone) to
## share inventory and equipment code.

const DIRECT: StringName = &"direct"
const LOB: StringName = &"lob"

@export var strategy: StringName = DIRECT
@export var max_distance := 650.0
@export var min_distance := 20.0
@export var flight_time := 0.55
@export var arc_height_ratio := 0.16

