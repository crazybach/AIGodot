# Acid atmosphere, weather, and protection

## Ownership and flow

`WeatherSystem` loads validated `data/environment.cfg`: four kinds (`sunny`, `cloudy`, `rain`, `snow`), transition intensities, temperature, and acid coefficients. `ambient_acid_factor()` varies continuously: sunny/cloudy = 1, full rain = `rain_multiplier` (default .55), full snow = 0. Floor `WorldLayerDefinition.mist_exposure` gates acid to ground. Rooftops are safe in any weather.

`EnvironmentExposureComponent` on `Player` owns the ground hazard. Each physics tick it combines ambient factor with same-floor `RootColonyComponent.acid_damage_at(player_position)`. Root acid is local and unaffected by snow or rain. Root death returns zero and removes its fog/obstacles. The component resolves clothing wear, skin damage, breathing stamina cost, oxygen consumption, and exhaustion damage. `exposed`, `ambient_load`, `root_damage_per_second`, `skin_exposure`, `breath_multiplier`, `oxygen_current/maximum`, `outfit_integrity()` are public HUD/debug readouts. Its `protection_changed` signal refreshes equipment slots.

`FogController` applies the ambient factor to global/untinted local visual mist. Tinted broodroot fog remains when it snows. `WeatherOverlay` draws outdoor snowflakes/rain beneath UI; `EnvironmentHUD`, `AcidStatusHUD`, and `DistrictHUD` describe weather and actual risk. Time of day and existing light attenuation still work.

## Item components

`AcidBarrierComponent` + `EnduranceComponent` on torso, legs, feet: coverage weights .5, .3, .2. Treated jacket/ballistic vest, cargo pants, and work boots can together block all skin exposure while intact. Ambient acid wears them at .25 endurance/s. A root adds `.28 × local acid DPS`, roughly ten times faster near its center. Below 10% item endurance, its coverage falls smoothly; at zero it protects nothing. Missing clothes leave their covered fraction exposed. Direct HP damage is `skin_exposure × (ambient bare HP/s + root acid DPS)`. Exposed skin also speeds stamina loss. These figures are live tunable in World debug and loaded from the config. A `decon_patch` repairs 50 integrity on the most damaged equipped outfit item.

`BreathingProtectionComponent` on face gear controls breathing stamina drain: scarf .72×, filter gas mask .45×, oxygen mask 0× while supplied. `EnduranceComponent` stores oxygen per stack. The mask consumes .28 oxygen/s of acid load from `OxygenReserveComponent` backpack first, then its own reserve. Without oxygen it loses full breathing protection. Oxygen is conserved in clear air and on the roof. Tap an `oxygen_canister` in the backpack to refill equipped tank, then mask. Current/max combined reserve and a connected-state flag drive the HUD. Equipment swaps preserve each `ItemStack`'s runtime endurance.

`ItemCatalog` provides starter protective clothes and scarf, and carries advanced oxygen gear plus refills in the starter backpack. All new gear has SVG icons from `assets/ui/field_icons/`; slot widgets already render an endurance bar. `ItemPresentation` describes component effects. `merchant_stock()` sells the six new protective gear and supply items so they can be replenished.

## Extension points and checks

Weather changes: add a kind to `WeatherSystem.KINDS`, blending, tint/precipitation rendering, and config validation. New emitters should expose local acid through a common component/group and use the same-floor check; do not directly subtract player HP. New gear needs `EquippableComponent` plus relevant protection/endurance components; avoid hardcoded item IDs in exposure logic.

Run `tests/acid_weather_gear_smoke.gd`, `environment_smoke.gd`, `district_layers_smoke.gd`, `enemy_system_smoke.gd`; render `acid_weather_visual.gd` for sunny, rain, snow, broodroot snow, oxygen and equipment screens. Source config reload is `F3 → World → Reload environment config`; World also forces snow and tunes acid rates.
