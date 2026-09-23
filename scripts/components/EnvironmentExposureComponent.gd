class_name EnvironmentExposureComponent
extends Node
## Ground-level acid atmosphere. Weather sets ambient load, broodroots add a
## local load, and equipped item components resolve skin/breathing protection.
signal protection_changed
var actor: Player
var weather: WeatherSystem
var exposed := false
@export var stamina_drain := 1.2
@export var exhausted_damage := 3.0
var ambient_load := 0.0
var root_damage_per_second := 0.0
var skin_exposure := 0.0
var breath_multiplier := 1.0
var oxygen_current := 0.0
var oxygen_maximum := 0.0
var oxygen_connected := false
var _report_elapsed := 0.0

func apply_environment(definition: WorldLayerDefinition) -> void:
	exposed = definition.mist_exposure
	stamina_drain = definition.stamina_drain
	exhausted_damage = definition.exhausted_damage
	if not exposed:
		ambient_load = 0.0
		root_damage_per_second = 0.0
		actor.humanoid_profile.environment_recovery_multiplier = 1.0
	protection_changed.emit()

func _physics_process(delta: float) -> void:
	if not is_instance_valid(actor) or not actor.is_alive: return
	ambient_load = weather.ambient_acid_factor() if exposed and weather else (1.0 if exposed else 0.0)
	root_damage_per_second = _root_damage() if exposed else 0.0
	var acid_active := ambient_load > 0.001 or root_damage_per_second > 0.001
	var wear_rate := 0.0
	if weather:
		wear_rate = weather.outfit_wear_per_second * ambient_load + weather.root_wear_per_damage * root_damage_per_second
	else: wear_rate = 0.25 * ambient_load + 0.28 * root_damage_per_second
	skin_exposure = _wear_outfit(wear_rate * delta) if acid_active else 0.0
	var breathing_load := ambient_load + root_damage_per_second / 3.5
	breath_multiplier = _resolve_breathing(breathing_load * delta)
	var bare_stamina: float = weather.bare_stamina_multiplier if weather else 4.0
	var bare_health: float = weather.bare_health_per_second if weather else 3.5
	var drain := stamina_drain * breathing_load * (breath_multiplier + (bare_stamina - 1.0) * skin_exposure)
	actor.humanoid_profile.environment_recovery_multiplier = 0.0 if drain > 0.001 else 1.0
	if drain > 0.0:
		var profile: HumanoidProfileComponent = actor.humanoid_profile
		var exhausted_time := maxf(0.0, delta - profile.stamina / drain)
		profile.stamina = maxf(0.0, profile.stamina - drain * delta)
		profile.stamina_changed.emit(profile.stamina, profile.max_stamina)
		if exhausted_time > 0.0:
			actor.receive_damage(exhausted_damage * exhausted_time, &"mist")
	var skin_damage := (bare_health * ambient_load + root_damage_per_second) * skin_exposure * delta
	if skin_damage > 0.0: actor.receive_damage(skin_damage, &"acid")
	_report_elapsed += delta
	if _report_elapsed >= 0.2:
		_report_elapsed = 0.0
		protection_changed.emit()

func _root_damage() -> float:
	var total := 0.0
	for emitter in get_tree().get_nodes_in_group(&"acid_emitters"):
		if emitter is RootColonyComponent and emitter.creature.get_parent() == actor.get_parent():
			total += emitter.acid_damage_at(actor.global_position)
	return total

func _wear_outfit(wear: float) -> float:
	var protected := 0.0
	if actor.equipment_comp == null: return 1.0
	for slot in [&"torso", &"legs", &"feet"]:
		var stack := actor.equipment_comp.get_equipped(slot)
		if stack == null: continue
		var barrier := stack.definition.get_component(AcidBarrierComponent) as AcidBarrierComponent
		var endurance := stack.definition.get_component(EnduranceComponent) as EnduranceComponent
		if barrier == null or endurance == null: continue
		var remaining := stack.endurance(endurance)
		if wear > 0.0 and remaining > 0.0:
			stack.set_endurance(endurance, remaining - wear * barrier.wear_multiplier)
			remaining = stack.endurance(endurance)
		protected += barrier.body_coverage * barrier.acid_block * clampf(remaining / minf(10.0, endurance.maximum), 0.0, 1.0)
	return 1.0 - clampf(protected, 0.0, 1.0)

func _resolve_breathing(oxygen_demand: float) -> float:
	oxygen_current = 0.0
	oxygen_maximum = 0.0
	oxygen_connected = false
	if actor.equipment_comp == null: return 1.0
	var face := actor.equipment_comp.get_equipped(&"face")
	var tank := actor.equipment_comp.get_equipped(&"backpack")
	var mask_reserve := _reserve(face)
	var tank_reserve := _reserve(tank) if tank and tank.definition.get_component(OxygenReserveComponent) else null
	var breath := face.definition.get_component(BreathingProtectionComponent) as BreathingProtectionComponent if face else null
	if breath == null:
		if tank_reserve:
			oxygen_current = tank.endurance(tank_reserve)
			oxygen_maximum = tank_reserve.maximum
		return 1.0
	if breath.oxygen_per_second <= 0.0:
		return breath.stamina_multiplier
	oxygen_connected = true
	var needed := breath.oxygen_per_second * oxygen_demand
	var total_needed := needed
	if tank_reserve and needed > 0.0:
		var used := minf(needed, tank.endurance(tank_reserve))
		tank.set_endurance(tank_reserve, tank.endurance(tank_reserve) - used)
		needed -= used
	if mask_reserve and needed > 0.0:
		var used := minf(needed, face.endurance(mask_reserve))
		face.set_endurance(mask_reserve, face.endurance(mask_reserve) - used)
		needed -= used
	if mask_reserve:
		oxygen_current += face.endurance(mask_reserve)
		oxygen_maximum += mask_reserve.maximum
	if tank_reserve:
		oxygen_current += tank.endurance(tank_reserve)
		oxygen_maximum += tank_reserve.maximum
	if total_needed <= 0.0: return 0.0 if oxygen_current > 0.0 else 1.0
	return lerpf(breath.stamina_multiplier, 1.0, needed / total_needed)

func _reserve(stack: ItemStack) -> EnduranceComponent:
	return stack.definition.get_component(EnduranceComponent) as EnduranceComponent if stack else null

func refill_oxygen(source_index: int) -> bool:
	if actor.inventory_comp == null or source_index < 0 or source_index >= actor.inventory_comp.slots.size(): return false
	var source := actor.inventory_comp.slots[source_index]
	if source == null or not source.definition.has_tag(&"oxygen"): return false
	for slot in [&"backpack", &"face"]:
		var target := actor.equipment_comp.get_equipped(slot)
		if target == null: continue
		var endurance := _reserve(target)
		if endurance == null or not endurance.can_refill_from(source.definition): continue
		var current := target.endurance(endurance)
		if current >= endurance.maximum: continue
		target.set_endurance(endurance, current + endurance.refill_amount)
		actor.inventory_comp.consume_at(source_index)
		protection_changed.emit()
		return true
	return false

func repair_outfit(source_index: int) -> bool:
	if actor.inventory_comp == null or source_index < 0 or source_index >= actor.inventory_comp.slots.size(): return false
	var source := actor.inventory_comp.slots[source_index]
	if source == null or not source.definition.has_tag(&"decon"): return false
	var target: ItemStack
	var lowest := INF
	for slot in [&"torso", &"legs", &"feet"]:
		var stack := actor.equipment_comp.get_equipped(slot)
		if stack == null or stack.definition.get_component(AcidBarrierComponent) == null: continue
		var endurance := _reserve(stack)
		if endurance == null or not endurance.can_refill_from(source.definition): continue
		var ratio := stack.endurance(endurance) / endurance.maximum
		if ratio < lowest:
			lowest = ratio
			target = stack
	if target == null or lowest >= 1.0: return false
	var endurance := _reserve(target)
	target.set_endurance(endurance, target.endurance(endurance) + endurance.refill_amount)
	actor.inventory_comp.consume_at(source_index)
	protection_changed.emit()
	return true

func outfit_integrity() -> float:
	if actor.equipment_comp == null: return 0.0
	var total := 0.0
	for slot in [&"torso", &"legs", &"feet"]:
		var stack := actor.equipment_comp.get_equipped(slot)
		if stack == null: continue
		var barrier := stack.definition.get_component(AcidBarrierComponent) as AcidBarrierComponent
		var endurance := _reserve(stack)
		if barrier and endurance:
			total += barrier.body_coverage * barrier.acid_block * stack.endurance(endurance) / endurance.maximum
	return clampf(total, 0.0, 1.0)

func restore_gear() -> void:
	for slot in [&"torso", &"legs", &"feet", &"face", &"backpack"]:
		var stack := actor.equipment_comp.get_equipped(slot)
		var endurance := _reserve(stack)
		if endurance and (stack.definition.get_component(AcidBarrierComponent) or stack.definition.get_component(OxygenReserveComponent) or stack.definition.get_component(BreathingProtectionComponent)):
			stack.set_endurance(endurance, endurance.maximum)
	protection_changed.emit()
