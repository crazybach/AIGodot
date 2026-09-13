# Field Collection — 50 playable items

## Scope and quick test

Exactly **50 featured definitions** are returned by `FieldCollection.ids()`. Existing
salvage/prototype definitions remain available through `ItemCatalog`; they are not
removed or counted in this collection.

- **F3 → Items**: search, inspect full statistics, grant the selected item, place a
  training target and refill vitals. Grants respect backpack capacity.
- **I**: click weapons/throwables to equip; click food/medicine to consume.
- **LMB**: semi-auto shot, hold for automatic fire; bows draw while held and fire
  on release. **R** reloads. The HUD bar shows reload or draw progress.
- **Hold RMB + LMB**: throw the held item. Preview shows legal range and area
  radius; out-of-range targets show a cross. **Q** cycles held throw candidates.
- **E near Imani**: trade; all 50 items are stocked in a scrolling inventory.
- Explosions/fire/acid can hurt the thrower. Solid walls block area damage.
- Medicine can be tested after taking damage; effect names/timers appear under
  the vitals. Reusing the same item refreshes duration; different items coexist.

## Balance table

These are game units and selected magazine variants, not a real ballistics model.
One displayed metre is 10 world pixels. 7.62 ammunition is deliberately a shared
gameplay category. M9's 10-round magazine and the modified M14's 30-round burst
configuration preserve the original prototype. No chamber or per-shell reload model.

DPS includes full reload downtime, assumes all pellets hit, full bow draw, no
critical hits, armor, spread misses, or stamina limits. DPS is computed by
`WeaponConfig.sustained_dps()`, not stored independently.

| Weapon | Ammo | Mode | Mag | Damage/shot | Interval | Reload | Range | Sustained DPS |
|---|---|---|---:|---:|---:|---:|---:|---:|
| Beretta M9 | 9mm | semi | 10 | 24.0 | 0.35s | 1.25s | 72m | 54.5 |
| Glock 17 | 9mm | semi | 17 | 20.0 | 0.28s | 1.70s | 64m | 55.0 |
| Glock 19 | 9mm | semi | 15 | 21.0 | 0.30s | 1.45s | 58m | 55.8 |
| SIG P226 | 9mm | semi | 15 | 27.0 | 0.40s | 1.80s | 76m | 54.7 |
| CZ 75 | 9mm | semi | 16 | 23.0 | 0.32s | 1.90s | 68m | 54.9 |
| M14 Breach Rifle | 762 | burst | 30 | 31.0 | 0.20s | 1.80s | 88m | 122.4 |
| AKM | 762 | auto | 30 | 28.0 | 0.17s | 2.65s | 74m | 110.8 |
| M4 Carbine | 556 | auto | 30 | 22.0 | 0.14s | 2.25s | 82m | 104.6 |
| FN SCAR-H | 762 | semi | 20 | 45.0 | 0.34s | 2.60s | 100m | 99.3 |
| FN FAL | 762 | auto | 20 | 36.0 | 0.24s | 3.00s | 92m | 95.2 |
| Stoeger Coach Gun | shell | semi | 2 | 72.0 | 0.70s | 1.50s | 43m | 65.5 |
| Remington 870 | shell | semi | 6 | 80.0 | 0.90s | 3.20s | 48m | 62.3 |
| Mossberg 590 | shell | semi | 8 | 81.0 | 0.95s | 4.00s | 44m | 60.8 |
| Benelli M4 | shell | semi | 7 | 56.0 | 0.50s | 3.50s | 46m | 60.3 |
| KelTec KSG | shell | semi | 14 | 72.0 | 0.85s | 5.00s | 40m | 62.8 |
| Survivor Recurve Bow | arrow | charged | 1 | 55.1 | 0.30s | 0.45s | 82m | 29.8 |
| Hunting Longbow | arrow | charged | 1 | 79.2 | 0.35s | 0.60s | 100m | 31.7 |
| Compound Bow | arrow | charged | 1 | 51.0 | 0.25s | 0.40s | 76m | 37.8 |

Bows: recurve draws in 1.4s, longbow 1.9s, compound 0.95s. Draw scales power and
range. Every weapon also configures pellet spread, recoil growth/recovery/cap,
distance falloff, critical multipliers, and proficiency growth in `data/weapons.cfg`.
**F3 → Weapons** edits these live, saves/reloads CFG, and compiles a binary Resource.

## Throwables (5)

| Item | Type | Radius | Center impact | Lingering damage | Landing fuse |
|---|---|---:|---:|---|---:|
| Fragmentation Grenade | Explosion | 11m | 110 | — | 1.1s |
| Fire Bottle | Fire | 9m | 12 | 14/s × 7s | Impact |
| Containment Acid Bomb | Acid | 10.5m | 8 | 10/s × 10s | Impact |
| Thermite Canister | Fire | 6.5m | 20 | 24/s × 6s | 0.5s |
| Impact Grenade | Explosion | 7m | 85 | — | Impact |

Impact damage falls linearly to 25% at the edge. Lingering damage has a uniform
radius and ticks at 0.25s with a final partial tick. Payloads consume once; armed
items cannot be picked back up. Fuse timing begins at landing, deliberately keeping
the first iteration simple. Fire emits a registered light; fire and acid have
generated transparent textures, drifting embers/bubbles, and lifetime rings.

## Food (5) and medicine (5)

| Item | Instant | Timed effect |
|---|---|---|
| Canned Beans | +2 HP, +5 stamina | +4 stamina/s for 12s |
| Bottled Water | +25 stamina | — |
| Bruised Apple | +1 HP, +15 stamina | Also equip/throw via right-click or drag |
| Emergency Ration | +10 stamina | +3 stamina/s for 25s |
| Energy Bar | +35 stamina | +2 stamina/s for 5s |
| Field Medkit | +45 HP | — |
| Antiseptic Dressing | +10 HP | +2 HP/s for 12s |
| Endurance Tablets | — | +20 maximum stamina for 45s |
| Adrenaline Injector | — | +40 maximum stamina for 20s |
| Regenerative Injector | +5 HP | +4 HP/s for 15s |

Recovery is clamped to the current cap. Increasing maximum stamina does not fill it;
natural recovery/food fills the extra capacity. Expiry clamps stamina back to its
remaining cap. Effect data is snapshotted at consumption. Dead characters cannot
consume or recover.

## Remaining featured items (17)

Ammunition: 9mm rounds, 7.62mm rounds, 5.56mm rounds, 12-gauge shells, arrows.
Gear/utilities: hard hat, gas mask, ballistic vest, cargo pants, work boots, canvas
backpack, flashlight, battery, fire torch, flare, stone, ash.

## Architecture delta

| File | Responsibility |
|---|---|
| `scripts/items/FieldCollection.gd` | 50-item roster; composes existing capabilities; overlays prototype catalog definitions |
| `data/weapons.cfg` | Authoritative weapon tuning; typed load, reload, debug edits, binary export |
| `AreaEffectComponent.gd` | Shared payload Resource: type, radius, impact, DPS, fuse, duration, owner damage |
| `WorldItemActor.gd` | Carries stack/source through flight; consumes and deploys payload once after landing/fuse |
| `AreaEffectActor.gd` | Runtime blast/DoT/LOS, finite lifespan, textures, light, telegraph |
| `ConsumableComponent.gd` | Instant recovery and timed effect configuration |
| `ConsumableEffectSystem.gd` | Per-owner effects keyed by item ID; refresh, exact duration, cap cleanup |
| `HumanoidProfileComponent.gd` | Base stamina cap plus separate transient bonus |
| `Creature.receive_damage()` | Typed resistance; kinetic/explosion use existing armor, fire/acid bypass flat armor |
| `CombatComponent.gd` | Auto trigger, recoil recovery/spread, configured projectile falloff |
| `Bullet.gd` | Swept collision, one hit, distance falloff, smooth tracer/arrow rendering |
| `ItemPresentation.gd` | Shared user-facing stats for tooltips, inventory details, debug catalog |
| `ItemDebugTab.gd`, `TrainingTarget.gd` | Search/grant/inspect and a bounded replaceable damage target |

Existing limitations remain: magazines are per config ID rather than per physical
weapon; world items/effects are not saved; arrows are not recovered; no armor
penetration, sound attraction, or weapon wear/jamming model. Do not infer these
mechanics from real weapon names or legacy item text.

## Validation

- `tests/weapon_system_smoke.gd`: original four paths, burst/charge/proficiency,
  reload/CFG round trip and binary output; asserts expanded 18-entry table.
- `tests/light_item_system_smoke.gd`: equipped/deployed light and endurance regression.
- `tests/field_collection_smoke.gd`: 50 unique definitions/icons/merchant rows, all
  18 firing paths, auto release, recovery totals, buff refresh/expiry, area lifetime,
  walls, single detonation, stack throw, debug supply, swept target collision.
- `tests/field_collection_visual.gd`: actual game UI/effects captures at 1920×1080
  under `.godot_local/field-*.png`; run with a renderer, not headless.

See [agent guide](AI_AGENT_ITEM_SYSTEM.md) for local Godot commands.

## References and art provenance

- [The Division 2 weapon design](https://www.ubisoft.com/en-us/game/the-division/the-division-2/news-updates/8gCjs51CA7gSEq9YsqHIy/intelligence-annex-weapons-in-the-division-2):
  reference for balancing handling, magazine size and reload downtime.
- [Glock buyer guide](https://us.glock.com/-/media/global/us/old/us-site/83-downloadable-materials/glock_buyersguide2020_lowres.pdf?la=en):
  G17/G19 identities and capacity reference.
- [SIG product reference](https://www.sigsauer.com/media/sigsauer/resources/SOF_PistolRifle_Section.pdf):
  P226 identity/capacity.
- [FN SCAR](https://fnamerica.com/products/rifles/fn-scar-17s/):
  heavy-rifle identity, 7.62 family and 20-round reference.
- [KelTec KSG](https://www.keltecweapons.com/blog/ksg-spotlight-most-innovative-gun-of-this-century/):
  twin-tube identity/capacity.
- [Mossberg overview](https://resources.mossberg.com/journal/series-overview-500-cruiser):
  shotgun variants/capacity reference.
- [Benelli M4](https://www.benelliusa.com/resources/benelli-unleashes-the-m4-ext-more-firepower-more-versatility-more-m4):
  semi-auto shotgun identity.
- [Kenney Particle Pack](https://kenney.nl/assets/particle-pack): 512px CC0
  particle art reference. Reference only; no files from this pack are bundled.
- [Godot 2D particles](https://docs.godotengine.org/en/stable/tutorials/2d/particle_systems_2d.html):
  runtime effects reference.

New vector icons in `assets/ui/field_icons/` are project-authored schematic
silhouettes; manufacturer photos/logos are not included. Existing legacy icon
licenses remain in their asset folder. New raster VFX use the built-in imagegen
tool; exact prompts and output provenance are in
[`assets/vfx/PROVENANCE.md`](../assets/vfx/PROVENANCE.md).
