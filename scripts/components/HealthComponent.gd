class_name HealthComponent
extends Component
## Manages health, damage-taking, damage-flash effect, and death trigger.

signal health_changed(current: float, maximum: float)
signal damaged(amount: float)
signal depleted  # health reached 0

var health: float
var max_health: float
var flash_color := Color.RED
var flash_duration := 0.1
var _flash_timer  # SceneTreeTimer (RefCounted, no type annotation — avoid Timer mismatch)


## Set initial health. Emits health_changed so HUD/bar sync at startup.
func configure(hp: float, flash_clr := Color.RED, flash_dur := 0.1) -> void:
	health = hp
	max_health = hp
	flash_color = flash_clr
	flash_duration = flash_dur
	health_changed.emit(health, max_health)


## Called externally (Bullet, Enemy attack) via Creature.take_damage → here.
func take_damage(amount: float) -> void:
	if not creature.is_alive:
		return
	health = max(0.0, health - amount)
	health_changed.emit(health, max_health)
	damaged.emit(amount)
	flash(flash_color, flash_duration)
	if health <= 0.0:
		depleted.emit()
		creature.die()


func heal(amount: float) -> void:
	if not creature.is_alive:
		return
	health = min(max_health, health + amount)
	health_changed.emit(health, max_health)


## Public one-shot visual flash. Safe to call overlapping (cancels prior).
func flash(color: Color, duration: float) -> void:
	_cancel_pending_flash()
	creature.apply_flash(color)
	_flash_timer = get_tree().create_timer(duration)
	_flash_timer.timeout.connect(_on_flash_timeout)


func _cancel_pending_flash() -> void:
	if _flash_timer == null:
		return
	# SceneTreeTimer is one-shot; it auto-frees after firing.
	# Disconnect to avoid stale callbacks, then drop the reference.
	if _flash_timer.timeout.is_connected(_on_flash_timeout):
		_flash_timer.timeout.disconnect(_on_flash_timeout)
	_flash_timer = null


func _on_flash_timeout() -> void:
	creature.reset_flash()
