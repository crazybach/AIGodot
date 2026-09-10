# Configurable Weapon System — First Iteration

## Player experience

Weapons are physical component-based items. A weapon must be equipped in its declared hand slot and consumes matching ammunition from a backpack when its magazine is loaded. Number keys 1–4 select the pistol, rifle, shotgun, and bow. `LMB` fires firearms. Holding and releasing `LMB` draws and fires the bow. `R` reloads. The HUD shows the active weapon, magazine, fire mode, base damage, proficiency, critical chance, and bow charge.

The inventory art reuses the project's licensed `fivem-icons-pixel` set so the four weapons and their ammunition retain one visual language; aliases are used where that pack has no separately imported rifle or arrow file. Attribution and the retained upstream license are documented in [`assets/ui/SOURCES.md`](../assets/ui/SOURCES.md).

| Weapon | Hands | Ammunition | Magazine | Trigger | Interval |
|---|---:|---|---:|---|---:|
| M9 service pistol | 1 | 9 mm rounds | 10 | Semi-automatic | 0.35 s |
| M14 breach rifle | 2 | 7.62 mm rounds | 30 | 3-round burst | 0.20 s per round |
| Coach shotgun | 2 | 12-gauge shells | 2 | Semi-automatic, 6 pellets | 0.70 s |
| Survivor recurve bow | 2 | Hunting arrows | 1 | Hold to charge | Configurable curve |

Shotgun pellet count and spread are configuration values. Bow draw time interpolates both projectile power and maximum range. A magazine remains associated with its weapon while another weapon is equipped.

## Item and combat composition

`ItemDefinition` remains the inventory identity and owns reusable components. `EquippableComponent` declares one-hand or two-hand placement. `LauncherComponent` contains only a `weapon_config_id`, which resolves a typed `WeaponConfig`. Ammunition remains an ordinary stackable item with a `ProjectileComponent` and a matching tag. This keeps inventory and equipment independent of fire-mode code.

`CombatComponent` is the runtime state machine for semi, burst, pellet, and charged triggers. It emits weapon, ammo, charge, and shot signals so UI and animation do not implement weapon rules. `WeaponProficiencyComponent` stores skill per character and weapon ID. Equipped use time and successful shots increase skill from 0 to 100. Critical chance interpolates from 5% to 10% by default; growth, endpoints, and critical multiplier are configurable per weapon.

## Configuration decision

The editable source is [`data/weapons.cfg`](../data/weapons.cfg). Godot `ConfigFile` uses an INI-style section/key structure and supports Variant values, which makes optional and newly added fields easier to review than a positional CSV table. CSV is suitable for flat bulk data but becomes fragile as weapon modes gain different parameters. SQLite adds schema migrations, a native dependency, and query machinery without helping a four-row table.

At load, the database sanitizes the text values into typed `WeaponConfig` resources. Press `F3`, open **Weapons**, and tune every numeric property live. **Reload CFG** restores the source file. **Compile .RES** writes a compressed `user://weapons.res`, providing a direct binary packaging path without changing consumers. The database also polls the text file modification time for development hot reload.

This choice follows Godot's documented [`ConfigFile`](https://docs.godotengine.org/en/stable/classes/class_configfile.html), [`ResourceSaver`](https://docs.godotengine.org/en/stable/classes/class_resourcesaver.html), and [runtime file loading](https://docs.godotengine.org/en/stable/tutorials/io/runtime_file_loading_and_saving.html) APIs. Godot's [showcase](https://godotengine.org/showcase/) confirms the engine ships commercial games, but those games generally do not publish their internal configuration architecture; the format choice here is based on the engine's supported resource pipeline rather than an unverifiable claim about a particular title.

## Extension points

New weapon types add a configuration row and, only when necessary, a new trigger strategy in `CombatComponent`. Projectile presentation and impacts can later move into projectile configuration. Proficiency belongs to the humanoid, so NPCs can use the same weapons with independent skill. The current dictionary state is save-ready: persistence can serialize weapon-ID/skill pairs alongside the character record.

Run the headless integration check with:

```powershell
D:\workspace\GodotRuntime\Godot_v4.6.2-stable_win64_console.exe --headless --path . --script tests/weapon_system_smoke.gd
```
