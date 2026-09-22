# Radial controls (current)

Replaces the bottom quickbar and old dual-stick overlay. No combat, inventory,
quest, or equipment implementations belong in UI code.

| Owner | Responsibility / extension point |
|---|---|
| `components/InventoryComponent.gd` | Single binding store: `hotbar_slots`, 8 stable item-definition IDs. Use `set_hotbar_slot` / `swap_hotbar_slots`; never write array entries from UI. Bindings do not transfer or clone items. |
| `components/QuickSlotRules.gd` | Slot policy: 0–1 equipped launchers; 2 equippable projectile with LOB aim; 3–7 consumables, batteries, lights. Change policy here for new item capabilities. |
| `components/QuickSlotController.gd` | Resolves equipped/bag stack, activates a binding through Player APIs, reports feedback, remembers selected throwable. Handles exact-item equip/aim; failed transfers preserve items. |
| `components/MobileInputAdapter.gd` | Movement/facing intent, run toggle, attack press/release/cancel. Uses existing CombatComponent/AimingSystem. UI must call this instead of firing projectiles itself. |
| `ui/TouchControls.gd` | Owns movement and shoot finger IDs. Contextual ACT delegates to GameManager. Rejects gameplay touches while modal/dead. Focus loss/canceled touch/modal clears held input without firing. |
| `ui/RadialWheel.gd` | Pure eight-sector geometry/rendering. `entries`, `center`, `selected`; `sector_at` / `point_for`. Antialiased procedural rings + icon textures. No actor reference. |
| `ui/RadialMenuHost.gd` | Hold (0.18s), slide, release; center/outside cancel. One pointer owns the menu. Populates entries and routes system selection/shortcut activation. Canvas layer 180. |
| `ui/QuickSlotPanel.gd` | Binding editor at layer 170: select slot, tap bag item to assign/replace, tap selected occupied slot to clear. Type-incompatible buttons disabled. Inventory/equipment signals refresh contents. |
| `HUD.gd` | Builds UI, polls existing PC hotkeys, combines modal state. `is_window_open` excludes radial/help; `is_modal_open` includes them. |
| `GameManager._handle_back` | Cancel radial → close help/quick-slot window → existing modal handling → exit. |

Paths above are relative to `scripts/`. `Player.activate_hotbar_slot` is the
compatibility entry point for numeric keys. `InventoryPanel` retains its hotbar
context for shared item presentation; the old `Quickbar.gd` view is removed.
Bindings follow the first matching definition, not a unique instance, and last
only for the current session, as before.

Touch left wheel controls movement only. Right wheel drag controls facing and
holds gun fire at configured cadence; bow/throw executes on release. The center
dead zone cancels the attack while leaving movement untouched. Wheel strength
sets throw distance; drag beyond its radius saturates at the configured cap.
Bow charge increases reach only up to the effective configured maximum.
Weapon selection exits throw mode.
Run is adapter state, never a synthetic global Shift press. PC mouse aim and
existing gameplay keys remain unchanged in normal launches. UI-generated mouse
events are ignored by Player to prevent duplicate shots. Desktop touch preview
uses `-- --touch-controls`; its real mouse goes through the same finger handlers.

Range config: launcher/bow `max_range`, `minimum_range`, `charge_time` are in
`data/weapons.cfg` (existing weapon debug/reload). Hand throws use
`data/throwables.cfg`, sections by item ID with a default, loaded by `ThrowConfig`
after catalog construction. Edit and restart, or apply the config to the catalog
with `ThrowConfig.apply`. `AimIndicator` clamps throw targeting before drawing;
`Bullet` clamps each sweep/movement step to its remaining range and lifetime.

Radial selection closes/unblocks the menu before executing gameplay. Opening a
menu cancels active fire/charge; closing it never resumes a held trigger. Other
fingers cannot operate the world or underlying GUI while a radial is open.

System sectors clockwise from top: Backpack, Equipment, Quick slots, Training,
Journal, Debug, Controls, Resume. Quick sectors: weapon 1, weapon 2, throwable,
five uses. `QuickSlotRules.label` and the radial host supply display text.

## Validation

- `tests/touch_controls_smoke.gd`: viewport touch events, simultaneous fingers,
  facing, run toggle, ACT availability, radial cancel/selection, typed bindings,
  bow cancel, stone execution, touch cancellation, one-item use, PC restoration.
- `tests/aim_range_smoke.gd`: bow/throw range caps, no off-range markers, exact
  projectile stopping with oversized physics steps, independent aim cancellation.
- `tests/radial_mouse_smoke.gd`: real GUI routing at 1920×1080, mouse radial
  gestures, bag assignment/clear, no accidental firing, PC fire, touch preview.
- `tests/touch_controls_visual.gd`: mobile/desktop HUD, both wheels, editor PNGs
  under `.godot_local/`. Run with rendering enabled.
- Weapon, light-item, quest and skill smoke tests cover shared gameplay regressions.

## Art / research

System icons: [Kenney Game Icons](https://kenney.nl/assets/game-icons), CC0.
Selected original White/2x PNGs are in `assets/ui/radial_icons/`; original license
included. Item sectors reuse the project's item art. Procedural rings scale with
the canvas. No third-party game screenshots or proprietary art are bundled.
Reviewed [Kenney mobile controls](https://kenney.nl/assets/mobile-controls) and
[large, spaced touch targets](https://gameaccessibilityguidelines.com/ensure-interactive-elements-virtual-controls-are-large-and-well-spaced-particularly-on-small-or-touch-screens/)
when choosing ring spacing and separate action targets.
