class_name HumanoidProfileComponent
extends Node
## Shared human state for the player and social NPCs. Combat health remains in
## HealthComponent; this profile mirrors it so social systems have one stable
## character record even for peaceful NPCs without combat components.

signal stamina_changed(current: float, maximum: float)
signal health_index_changed(current: float, maximum: float)
signal relationship_changed(character_id: StringName, attitude: int)

const NEUTRAL_ATTITUDE := 50
const MIN_ATTITUDE := 0
const MAX_ATTITUDE := 100

@export var character_id: StringName = &"unnamed_humanoid"
@export var display_name := "Unknown Survivor"
@export var max_stamina := 100.0:
	get: return maxf(1.0, attributes.resolve("max_stamina", max_stamina) if attributes else max_stamina) + _stamina_bonus
var attributes: CharacterAttributes
var _stamina_bonus := 0.0
@export var stamina_recovery_per_second := 16.0
@export var melee_charge_stamina_cost := 10.0
@export var melee_hit_stamina_cost := 14.0
@export var ranged_hit_stamina_cost := 1.5
@export var throw_stamina_cost := 8.0
@export_range(0.0, 1.0) var empathy := 0.5
@export_range(0.0, 1.0) var caution := 0.5
@export_range(0.0, 1.0) var aggression := 0.3

var stamina := 100.0
var health_current := 100.0
var health_maximum := 100.0
var relationships: Dictionary = {}
var _tracked_health: HealthComponent
var _spent_stamina_this_frame := false
var environment_recovery_multiplier := 1.0


func _ready() -> void:

	stamina = clampf(stamina, 0.0, max_stamina)


func _physics_process(delta: float) -> void:

	if not _spent_stamina_this_frame and stamina < max_stamina:
		stamina = minf(max_stamina, stamina + recovery_rate() * environment_recovery_multiplier * delta)
		stamina_changed.emit(stamina, max_stamina)
	_spent_stamina_this_frame = false


func bind_health(health: HealthComponent) -> void:

	_tracked_health = health
	if health == null:
		return
	if not health.health_changed.is_connected(_on_health_changed):
		health.health_changed.connect(_on_health_changed)
	_on_health_changed(health.health, health.max_health)


func bind_attributes(value: CharacterAttributes) -> void:
	if attributes and attributes.changed.is_connected(_on_attributes_changed):
		attributes.changed.disconnect(_on_attributes_changed)
	attributes = value
	if attributes: attributes.changed.connect(_on_attributes_changed)
	_on_attributes_changed()


func _on_attributes_changed() -> void:
	stamina = minf(stamina, max_stamina)
	stamina_changed.emit(stamina, max_stamina)


func recovery_rate() -> float:
	return maxf(0.0, attributes.resolve("stamina_recovery", stamina_recovery_per_second) if attributes else stamina_recovery_per_second)


func action_cost(base: float) -> float:
	return maxf(base * 0.1, attributes.resolve("action_cost", base) if attributes else base)


func _on_health_changed(current: float, maximum: float) -> void:

	health_current = current
	health_maximum = maximum
	health_index_changed.emit(current, maximum)


func can_spend_stamina(amount: float) -> bool:

	return amount <= 0.0 or stamina + 0.001 >= amount


func set_stamina_bonus(value: float) -> void:
	if is_equal_approx(_stamina_bonus, value):
		return
	_stamina_bonus = maxf(0.0, value)
	stamina = minf(stamina, max_stamina)
	stamina_changed.emit(stamina, max_stamina)


func restore_stamina(amount: float) -> void:
	if amount <= 0.0:
		return
	stamina = minf(max_stamina, stamina + amount)
	stamina_changed.emit(stamina, max_stamina)


func spend_stamina(amount: float) -> bool:

	if amount <= 0.0:
		return true
	if not can_spend_stamina(amount):
		return false
	stamina = maxf(0.0, stamina - amount)
	_spent_stamina_this_frame = true
	stamina_changed.emit(stamina, max_stamina)
	return true


func start_melee_charge() -> bool:

	return spend_stamina(action_cost(melee_charge_stamina_cost))


func resolve_melee_hit() -> bool:

	return spend_stamina(action_cost(melee_hit_stamina_cost))


func resolve_ranged_hit() -> bool:

	return spend_stamina(action_cost(ranged_hit_stamina_cost))


func resolve_throw() -> bool:

	return spend_stamina(action_cost(throw_stamina_cost))


func meet(character: StringName) -> int:

	if character == &"" or character == character_id:
		return NEUTRAL_ATTITUDE
	if not relationships.has(character):
		relationships[character] = NEUTRAL_ATTITUDE
		relationship_changed.emit(character, NEUTRAL_ATTITUDE)
	return int(relationships[character])


func attitude_toward(character: StringName) -> int:

	return meet(character)


func set_attitude(character: StringName, value: int) -> int:

	if character == &"" or character == character_id:
		return NEUTRAL_ATTITUDE
	var clamped := clampi(value, MIN_ATTITUDE, MAX_ATTITUDE)
	relationships[character] = clamped
	relationship_changed.emit(character, clamped)
	return clamped


func adjust_attitude(character: StringName, delta: int) -> int:

	return set_attitude(character, attitude_toward(character) + delta)
