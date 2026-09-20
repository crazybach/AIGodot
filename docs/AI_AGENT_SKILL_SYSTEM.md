# Field training / skill trees

First iteration: 12 passive talents, 28 purchasable ranks, two branches. Open with **K** or the **Training** HUD button (also touch accessible). Six starting points; defeats give 25 XP, completed quests 150 XP. Level threshold = `100 + 40 * (level - 1)`; each level grants one point. Refund All is free. The world continues while the window is open; rooftops are the safe place to train.

## Design references

- [WoW Dragonflight talents](https://worldofwarcraft.blizzard.com/en-us/news/23865972/): ranked nodes, dependency links, point gates and room to experiment. Our gates count only earlier rows in the same branch.
- [Diablo III progression](https://eu.diablo3.blizzard.com/en-us/class/wizard/progression): clear separation of active skills, passives and runes. This iteration adds passives; existing fire/throw actions remain the active layer.
- [Final Fantasy XIV job traits](https://na.finalfantasyxiv.com/jobguide/samurai/): readable trait upgrades to established actions. Our modern survival theme uses field-training language and existing original `assets/ui/field_icons/*.svg` art; no third-party game art copied.

## Ownership and entry points

| File | Responsibility |
| --- | --- |
| `data/skills.json` | Node text, icon, rank cap, branch, position, prerequisite ranks, earlier-row gate, per-rank modifiers; XP settings. Exported by existing JSON export filter. |
| `scripts/progression/CharacterAttributes.gd` | Per-character, source-keyed modifier aggregation. Call `set_source(id, modifiers)` to replace a source, `remove_source(id)` to clear it. Emits `changed`. |
| `scripts/progression/SkillTreeComponent.gd` | Rank/point/XP authority. `purchase`, `lock_reason`, `award_event`, `reset_tree`, `reload_table`, explicit `save_profile` / `load_profile`. Rebuilds the `skills` modifier source after allocation changes. |
| `scripts/Player.gd` | Owns both nodes; binds humanoid/combat consumers. Quest completion awards XP. |
| `scripts/GameManager.gd` | Existing encounter defeat event awards kill XP; Escape/Android Back closes training before exiting. |
| `scripts/components/CombatComponent.gd` | Resolves effective range, damage, crit, reload, spread, bow draw duration and theoretical DPS. Shared WeaponConfig remains unchanged. |
| `scripts/components/HumanoidProfileComponent.gd` | Resolves stamina cap/recovery/action costs; supports optional attribute binding for NPCs. |
| `scripts/ui/SkillTreePanel.gd` | Presentation, linked cards, selection/details, Train/Refund/Save/Load, live stats. Calls the component API; never edits ranks directly. |
| `scripts/HUD.gd` | K/button access, modal input, effective weapon readouts. Inventory tooltips label template stats as base stats. |
| `scripts/debug/DebugPanel.gd` | F3 > Skills: grant XP/point, refund, hot reload source table. |

NPC use: create CharacterAttributes + SkillTreeComponent on the NPC, call `tree.setup(attributes)`, bind its humanoid profile and assign `combat.attributes` if it has ranged combat. NPCs do not inherit player talents or UI. Existing peaceful NPCs have no allocations.

## Modifiers / invariants

`effective = (base + sum(flat)) * max(0, 1 + sum(percent))`. JSON `percent: 0.08` means +8%; negative percentages reduce time/cost/spread. Each modifier is multiplied by invested rank. Crit uses a flat probability: `0.015` = +1.5 percentage points, added after existing per-weapon proficiency. Source keys prevent reload/respec stacking. Consumers enforce bounds (crit 0–1, reload >=0.05s, draw >=0s with zero meaning instant full power, action cost >=10% of base).

- Never mutate ItemDefinition or WeaponConfig for character bonuses. Use effective combat methods in execution **and** previews/HUD. Range bonus also scales damage-falloff distance. DPS remains an idealized estimate excluding crit, armor and misses.
- Stamina cap = resolved base cap + temporary consumable cap bonus. Training never fills stamina for free. Removing bonuses clamps current stamina to the new cap.
- Natural recovery = resolved recovery * environment multiplier. Mist suppression remains authoritative. Food/medicine restoration retains its existing independent behavior.
- Action cost modifier applies only to firing, throwing and melee costs. It does not reduce environmental drain; sprint currently has no stamina cost.
- Weapon bonuses affect direct firearm/bow projectiles, not grenade/area-effect damage or hand-throw range. Bow draw talent affects charged launchers only.
- XP follows existing encounter kill credit (not a new damage-source attribution system). Quests award through `quest_completed`; ordinary dialogue gives no XP.

## Authoring and reload

Nodes require `id/title/description/branch/icon/ranks/row/column/requires/gate/modifiers`. `requires` maps parent IDs to minimum ranks. Parent must be in an earlier row of the same branch. `gate` counts ranks in earlier rows only. Every rank costs one point. First-iteration UI supports `weapons`/`survival`, rows 0–2 and columns 0–1; extending that layout requires updating the validator and panel together. IDs are save keys; keep them stable.

`CharacterAttributes.STAT_NAMES` is the allowed stat registry. To add an attribute: add its display name, consume `resolve(key, base)` in the relevant gameplay component, expose effective values in previews/UI, then author modifiers. Unknown stats, cycles, bad ranks/settings, missing icons and overlapping positions reject the table before replacement. Successful reload rebuilds legal allocations in row order and refunds ranks that no longer fit prerequisites/caps/budget. Invalid reload leaves the old working tree active.

## Persistence

**Save Build / Load Build are explicit**, not automatic. `user://training_profile.json` stores version 1, level, XP, debug bonus points and stable node IDs/ranks. Every new game starts with a fresh tree; Load Build restores the saved training snapshot. This is not a world save: inventory, health, quests, proficiency and map state are not restored. Saves reconcile against current definitions on load. Tests use separate filenames and never touch the user's training profile. A future full save manager should own the load timing and serialize all character state together.

## Verification

- `tests/skill_tree_smoke.gd`: prerequisites/budget, real projectile damage/range, aim range, reload completion, proficiency stacking, modifier isolation, consumable coexistence, mist suppression, actual recovery/cost, respec, save/load, valid/invalid hot reload, XP hooks, bow charge, UI actions, touch isolation and Back.
- `tests/skill_tree_visual.gd`: real viewport mouse events open Training without firing, switch branches, select and train; 1920×1080 captures under `.godot_local/skills-*.png` check branches and multi-effect detail text.
- Regression: weapon_system_smoke, field_collection_smoke, environment_smoke, touch_controls_smoke.

Run scripts with Godot `--headless --path . --script res://tests/skill_tree_smoke.gd`; visual test requires the renderer (omit `--headless`). Import new global classes once with `--headless --editor --quit`.
