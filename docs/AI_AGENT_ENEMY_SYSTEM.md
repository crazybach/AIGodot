# Enemy system: agent guide

## Entry points

- `data/enemies.cfg`: archetype parameters, loaded through `EnemyDefinition.load_type(id)` into an independent Resource per actor. File edits apply to new spawns; existing actors retain their definitions. Export presets include `data/*.cfg`.
- `Enemy`: `Creature` facade, health/damage/death signals, visuals, component composition. Call `configure(id, player, registration)` after adding the actor to its `WorldLayer`.
- `EnemyEncounterSpawner`: creates actors and calls registration; `populate()` reads scene encounter records. `find_position()` checks navigation clearance and existing creature overlap.
- `EncounterMarker` in `scenes/world/AshdownDistrict.tscn`: editor-authored `kind`, `enemy_id`, `count`, `spread`. `DistrictBuilder` converts markers into floor-local records. `count=1` is a single encounter; larger counts scatter a group.
- `GameManager._register_enemy`: shared kill count, quest, XP integration; newborn enemies must use this callback too.

## Components and tick order

`Creature._physics_process` calls components in insertion order:

1. `EnemyBrainComponent`: same-floor target check, sight/LOS acquisition, wandering, radius-aware AStar pursuit. Ranged enemies stop to shoot within their preferred range.
2. `EnemyAttackComponent`: overrides movement during windup/dash. Melee rechecks contact and LOS after windup; charge locks direction and distance; ranged emits `EnemySpike` after its warning. Cooldown starts at windup and includes windup duration.
3. Shared `MovementComponent`: physical movement. `locomotion_enabled=false` skips collision recovery as well as movement, required for roots with overlapping owned colliders.
4. Shared `HealthComponent`.
5. Optional `RootColonyComponent`: fog, acid damage, brood, procedural root/tendril rendering.

`MistStalker` is a compatibility facade for old encounter/egg callers. `setup_behavior(..., wanders=false)` selects the skitter preset. Add new behavior to components, not to this wrapper.

## Presets

| ID | Role | HP | Radius | Chase speed | Attack |
|---|---|---:|---:|---:|---|
| stalker | Medium wanderer | 70 | 17 | 105 | 12 melee |
| skitter | Small swarm/hatchling | 24 | 9 | 165 | 5 melee |
| brute | Slow armored large creature | 300 | 34 | 62 | 32 melee; 25% kinetic resistance |
| charger | Medium breach hound | 110 | 20 | 90 | 24 damage; 190 px dash at 470 px/s |
| spitter | Medium ranged creature | 80 | 19 | 76 | 15 damage spikes; 390 px range |
| root | Stationary brood colony | 950 | 48 | 0 | 460 px acid field; no direct attack |

Distances are world pixels; speed is px/s; times are seconds. Melee `attack_range` is additional edge reach (enemy radius + player radius + range). Ranged/charge acquisition range is center-to-center. `charge_distance` limits travel independently. Resistances are damage-type fractions in `[0,1]`; existing shotgun pellets, grenades, fire and acid share `Creature.receive_damage`.

## Root lifecycle and ownership

- Root owns a `FogVolume2D` and four solid `RootTendril` bodies. Tendril bullet hits transfer half damage to the root, then apply its resistances. Only the root belongs to `damage_receivers`, preventing duplicate AoE damage and kills.
- `Creature.damage_collision_rids()` defines owned bodies excluded from area-damage visibility rays. Enemy adds its root limbs; unrelated walls still block blasts.
- Root registers body/limb rectangles in `WorldLayer.dynamic_obstacles` under its instance ID. Navigation grids cache each actor radius and invalidate when blockers change.
- Every 14 s, a root attempts to lay an egg on a free nearby point. Eggs hatch autonomously after 6 s while their floor is active. Weak references count both live eggs and hatchlings against the default cap of six; deaths free capacity.
- Eggs/hatchlings are floor siblings. Root death stops production but does not erase existing offspring.
- Death calls `RootColonyComponent.shutdown()` before freeing: zero local fog, disable limb collision, remove navigation blockers. Kill through `die()`/damage, not raw `queue_free()`, so cleanup and quest signals run.
- Floor transitions detach/cache actors; do not destroy their persistent navigation registrations on `_exit_tree`. Acid and brood ticks require the living player on the same floor. Rooftops remain safe.
- Killing roots removes their extra acid fog/hazard; normal district mist and stamina drain remain.

## Rendering and extension

Fog supports the 16 nearest active local volumes, each with density/radius/tint. Acid tint follows day/night and weather; existing light clearing applies. This is a soft fake density field, not fluid simulation. Root fog damage falls off toward the radius edge and currently crosses indoor walls.

Existing stalker SVG is reused with size/tint variations; spitters add spines, attacks draw windup rings/direction lines, roots use antialiased procedural limbs. Replace art in `Enemy`/`RootColonyComponent` without changing damage behavior.

To add an archetype: add a config section, expose its ID in `EncounterMarker`, author a marker. For a new attack mode, extend/replace the attack component; keep targeting, locomotion, spawning and rendering separate. `configure()` is spawn-time setup, not a live type-conversion API.

## Validation and manual checks

- `tests/enemy_system_smoke.gd`: authored swarm, size/speed balance, dodging, bounded locked-direction charge, swept ranged hits, floor isolation, stationary root physics, egg growth/cap, resistance, AoE, root cleanup.
- `tests/district_layers_smoke.gd`: navigation, existing encounters, elevators, loot and floor persistence.
- `tests/enemy_visual.gd`: day/night root, swarm and charge warning screenshots under `.godot_local/` (run with rendering).
- Regression suites: `weapon_system_smoke`, `field_collection_smoke`, `environment_smoke`, `touch_controls_smoke`, `aim_range_smoke`.

Run tests with `Godot --headless --path <repo> --script res://tests/<name>.gd`. Run normal PC gameplay with `tools/run_pc.bat`.

District placements: swarm east of A/B `(280,15)`; west root `(-1050,40)`; west brute `(-1050,620)`; charger `(1260,430)`; spitters `(960,870)`; south root `(1300,900)`; mall brute `(2450,-1300)`. Spawns may shift slightly to find clearance. Original 16 eggs and 14 low-sight wanderers remain.
