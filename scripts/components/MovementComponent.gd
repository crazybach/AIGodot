class_name MovementComponent
extends Component
## Handles velocity and move_and_slide for both Player and Enemy.
##
## Strategy pattern: same component, two controllers.
##   Player mode: input_control = true  → reads WASD + sprint from Input
##   Enemy mode:  input_control = false → AI writes move_direction directly

const DEFAULT_MOVE_SPEED      := 200.0
const DEFAULT_SPRINT_MULTIPLIER := 1.5

var base_speed        := DEFAULT_MOVE_SPEED
var sprint_multiplier := DEFAULT_SPRINT_MULTIPLIER

## If true, reads Input actions (Player). If false, uses move_direction (Enemy AI).
var input_control := false

## AI-driven movement target; set by AIController each frame.
var move_direction := Vector2.ZERO


func configure(speed: float, sprint_mul := 1.5) -> void:
	base_speed = speed
	sprint_multiplier = sprint_mul


func _physics_tick(_delta: float) -> void:
	var dir: Vector2
	var speed := base_speed

	if input_control:
		if creature is Player and creature.ui_input_blocked:
			creature.velocity = Vector2.ZERO
			return
		dir = Vector2(
			Input.get_axis("move_left", "move_right"),
			Input.get_axis("move_up", "move_down")
		).normalized()
		if creature is Player and creature.touch_move_direction != Vector2.ZERO:
			dir = creature.touch_move_direction
		if Input.is_action_pressed("sprint") or (creature is Player and creature.mobile_input and creature.mobile_input.enabled and creature.mobile_input.running):
			speed *= sprint_multiplier
	else:
		dir = move_direction

	creature.velocity = dir * speed
	creature.move_and_slide()
