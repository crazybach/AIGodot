# Clock, weather, temperature and debug: agent map

## Runtime and tuning

`GameManager.weather` is a session-level `WeatherSystem` containing one `WorldClock`.
It persists across floor travel. Full 24-hour cycle: **120 real seconds**, starting
08:00. Time scale multiplies both clock and front timers; pause stops environment
simulation, not actors. Midnight increments the day counter, preserving excess
time even across multiple days in one update.

`data/environment.cfg` is the human-readable default table. `EnvironmentSettings`
validates the whole file before changing live values. F3 > World reload applies
timing and temperature settings without resetting day/hour or the current front.
`start_hour`, initial weather and RNG seed apply on startup/reset only. Debug edits
are runtime-only; edit the cfg for durable defaults. Include `data/*.cfg` in future
export presets' non-resource filter.

Phase boundaries: dawn 05–07, day 07–17, dusk 17–20, night 20–05. Smoothstep blends
ambient light at dawn/dusk. Temperature is a separate cosine curve with minimum at
03:00 and maximum at 15:00, default 10–24°C. Cloudy/rain offsets are -3/-6°C at their
respective full cover; temperature continuously follows the blended cloud/rain
state. It is ambient outdoor temperature, not body temperature. This iteration
does not add temperature damage, wet clothes, seasonal simulation, or weather audio.

Weather fronts: sunny/cloudy/rain, 35-second holds, 6-second smooth transitions.
Seeded RNG chooses a different next front. A debug override is immediate and
disables automatic fronts until re-enabled. Nighttime sunny weather reads CLEAR in
the HUD and uses a moon icon. New fronts during a blend start from current values.

## Ownership

| Source | Responsibility / public seam |
| --- | --- |
| `scripts/environment/WorldClock.gd` | calendar, `advance`, `set_hour`, `daylight`, `updated`, `day_changed` |
| `scripts/environment/WeatherSystem.gd` | owns clock, `advance`, `set_weather`, `reload_config`, `snapshot`, `updated`, `weather_changed` |
| `scripts/environment/EnvironmentSettings.gd` | validate cfg atomically; retain old values on invalid reload |
| `scripts/LightingManager.gd` | one CanvasModulate, `bind_environment`, `refresh_environment`, `force_phase`, light registry |
| `scripts/environment/WeatherOverlay.gd` | world-anchored antialiased rain strokes and splashes, CanvasLayer 50 |
| `scripts/environment/EnvironmentHUD.gd` | day/time/phase, weather icon, ambient °C; HUD CanvasLayer 100 |
| `scripts/debug/DebugPanel.gd` | F3 hub, tab registration and built-in system composition |
| `scripts/debug/DebugControls.gd` | scrolling live getters/setters and callable actions |

`LightingManager` has no independent timer. Use `weather.clock.set_hour()` or
`lighting.force_phase()` rather than mutating the projected `phase`/`darkness`.
`LayerManager.travel()` changes night ambient and calls `refresh_environment()`;
it never overwrites weather tint or clock state. Auto lamps use a twilight threshold
or heavy cloud cover. Carried lights retain their own enabled/endurance state.
Fog tint follows time and weather, while mist visibility and exposure remain
independent. Roofs remain mist-free and safe.

Rain draws above mist (40) and below HUD/debug (100/220). It uses the floor's canvas
transform so rain stays world-anchored under camera movement and zoom. Both falling
head and landing position must be outdoors. `WorldLayer.is_outdoors_at(point)` is
the common shelter query. `WorldLayerDefinition.outdoor_weather=false` disables
rain for a room layer; `buildings_shelter_weather=true` shelters building footprint
polygons (ground default). Roofs are open sky. These flags are independent of mist.

## Add future debug features

Register after the hub is ready. Stable unique IDs permit selecting/removing a
module without depending on tab position. The caller retains rejected controls.
Existing Fog, World, Weapons, Items and Layers all use this registration path.
`FogDebugPanel.gd` is only a compatibility alias for older scenes.

```gdscript
var controls := DebugControls.new()
controls.readout(func(): return my_system.summary())
controls.number("Range", func(): return my_system.range, my_system.set_range, 1, 500, 1)
controls.toggle_value("Enabled", func(): return my_system.enabled, my_system.set_enabled)
controls.action("Reset", my_system.reset)
hud.debug_panel.register_tab(&"my_system", "My System", controls)
hud.debug_panel.select_tab(&"my_system")
# On feature teardown: hud.debug_panel.unregister_tab(&"my_system")
```

The UI reads live values without invoking setters during synchronization. A focused
numeric text field is left alone while editing. Actions call system APIs. Keep
game state out of debug controls; expose public methods and snapshots on systems.

## Verification and reference

`tests/environment_smoke.gd`: full-day/midnight/multi-day catchup, pause/speed,
weather interpolation/scheduling, day/night contrast, temperature, auto lamps,
shelter, travel continuity, real debug button/time controls, registration and
invalid config rejection. `tests/environment_visual.gd`: 1080p sunny, cloudy,
rainy, nighttime and F3 screenshots under `.godot_local/`.
Also run district, light-item and NPC smoke tests when changing shared ownership.

Renderer reference: [Godot 4.6 CanvasModulate](https://docs.godotengine.org/en/4.6/classes/class_canvasmodulate.html).
One ambient modulator handles the world; separate canvas layers keep UI readable.
