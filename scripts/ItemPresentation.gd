class_name ItemPresentation
extends RefCounted
## Shared player-facing stat text for slot tooltips and the field catalogue.

static func short_stats(item: ItemDefinition, database: WeaponConfigDatabase) -> String:
	var launcher := item.get_component(LauncherComponent) as LauncherComponent
	if launcher and database:
		var config := database.get_config(launcher.weapon_config_id)
		if config:
			return "DMG %.0f / DPS %.0f / MAG %d / RELOAD %.1fs" % [config.shot_damage(), config.sustained_dps(), config.magazine_size, config.reload_time]
	var area := item.get_component(AreaEffectComponent) as AreaEffectComponent
	if area:
		return "%s / %.0fm RADIUS / %.0f IMPACT / %.0f DPS / %.0fs" % [String(area.damage_type).to_upper(), area.radius / 10, area.impact_damage, area.damage_per_second, area.duration]
	var use := item.get_component(ConsumableComponent) as ConsumableComponent
	if use:
		return "+%.0f HP / +%.0f STM / %.0fs EFFECT" % [use.health_restore, use.stamina_restore, use.duration]
	var barrier := item.get_component(AcidBarrierComponent) as AcidBarrierComponent
	if barrier:
		return "ACID COVER %.0f%% / INTEGRITY" % (barrier.body_coverage * barrier.acid_block * 100)
	var breath := item.get_component(BreathingProtectionComponent) as BreathingProtectionComponent
	if breath:
		return "O2 MASK" if breath.oxygen_per_second > 0 else "BREATH DRAIN %.0f%%" % (breath.stamina_multiplier * 100)
	if item.get_component(OxygenReserveComponent): return "O2 RESERVE / MASK FEED"
	return "EQUIP / DRAG TO MOVE" if item.get_component(EquippableComponent) else "DRAG TO MOVE"

static func describe(item: ItemDefinition, database: WeaponConfigDatabase) -> String:
	var lines: Array[String] = [item.display_name, item.description, "Weight %.2f kg  |  Stack %d" % [item.weight, item.max_stack]]
	var launcher := item.get_component(LauncherComponent) as LauncherComponent
	if launcher and database:
		var weapon := database.get_config(launcher.weapon_config_id)
		if weapon:
			lines.append("BASE WEAPON STATS (character talents shown in Training / HUD)")
			lines.append("%s  |  %s  |  %d rounds" % [String(weapon.fire_mode).to_upper(), String(weapon.ammo_tag).trim_prefix("ammo_"), weapon.magazine_size])
			lines.append("%.0f damage/shot (%d pellets)  |  %.1f sustained DPS*" % [weapon.shot_damage(), weapon.pellets_per_shot, weapon.sustained_dps()])
			lines.append("Shot %.2fs  |  Reload %.2fs  |  Range %.0fm" % [weapon.shot_interval, weapon.reload_time, weapon.max_range / 10.0])
			lines.append("Spread %.1f deg  |  Recoil +%.1f / shot, recovery %.1f deg/s" % [weapon.spread_degrees, weapon.recoil_per_shot, weapon.recoil_recovery])
			lines.append("Falloff after %.0fm to %.0f%% damage  |  Crit %.0f-%.0f%%" % [weapon.falloff_start / 10.0, weapon.minimum_damage_ratio * 100, weapon.critical_chance_min * 100, weapon.critical_chance_max * 100])
			if weapon.fire_mode == WeaponConfig.CHARGED:
				lines.append("Draw %.2fs  |  Power %.2f-%.2fx" % [weapon.charge_time, weapon.minimum_power, weapon.maximum_power])
			lines.append("*Includes reloads; assumes all pellets hit, full draw, no armor or crits.")
	var area := item.get_component(AreaEffectComponent) as AreaEffectComponent
	if area:
		lines.append("%s  |  Radius %.0fm  |  Landing fuse %.1fs" % [String(area.damage_type).to_upper(), area.radius / 10.0, area.fuse_seconds])
		lines.append("Impact %.0f center / %.0f edge  |  %.0f damage/s for %.1fs" % [area.impact_damage, area.impact_damage * area.edge_damage_ratio, area.damage_per_second, area.duration])
		lines.append("Can hurt the thrower. Solid walls block area damage.")
	var use := item.get_component(ConsumableComponent) as ConsumableComponent
	if use:
		lines.append("Instant: +%.0f HP / +%.0f stamina" % [use.health_restore, use.stamina_restore])
		if use.duration > 0:
			lines.append("For %.0fs: +%.1f HP/s / +%.1f stamina/s / +%.0f max stamina" % [use.duration, use.health_per_second, use.stamina_per_second, use.stamina_max_bonus])
		lines.append("Click to consume. Same item refreshes duration.")
	var barrier := item.get_component(AcidBarrierComponent) as AcidBarrierComponent
	if barrier:
		lines.append("Acid coverage %.0f%% of body. Protection lasts while integrity remains." % (barrier.body_coverage * barrier.acid_block * 100))
	var breath := item.get_component(BreathingProtectionComponent) as BreathingProtectionComponent
	if breath:
		lines.append("Sealed oxygen breathing: %.2f O2/s in acid air." % breath.oxygen_per_second if breath.oxygen_per_second > 0 else "Acid-air stamina drain: %.0f%% of normal." % (breath.stamina_multiplier * 100))
	if item.get_component(OxygenReserveComponent): lines.append("Feeds an equipped oxygen mask before its own reserve is used.")
	return "\n".join(lines)
