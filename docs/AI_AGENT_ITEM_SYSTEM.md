# Item System: AI Agent Architecture Guide
Read this before changing items, inventory, equipment, weapons, lights, throwing,
trade, or their UI. This is an implementation map; the GDDs describe design intent.

World ownership: read [AI_AGENT_WORLD_LAYERS.md](AI_AGENT_WORLD_LAYERS.md) before
spawning world items/projectiles. Actors now belong to the active WorldLayer;
elevators reparent the same player. `ConstructionComponent` lets a portable ladder
be consumed by a matching rooftop crossing. Inactive floors retain state off-tree.

## Field collection extension (2026-09)

Start with [GDD_FIELD_COLLECTION.md](GDD_FIELD_COLLECTION.md) for the 50-item roster,
18-weapon tuning table, controls, effects, tests, and research/art provenance.
`ItemCatalog._build_catalog()` now calls `FieldCollection.register_into(_items)`;
edit featured content there. `data/weapons.cfg` remains authoritative for weapons.

- `AreaEffectComponent` is payload data; `WorldItemActor` owns its landing fuse;
  `AreaEffectActor` executes a single blast plus finite damage over time with LOS.
- `ConsumableEffectSystem` snapshots timed consumable data per owner. Same item
  refreshes duration; distinct items coexist. Stamina cap bonuses are transient.
- `Creature.receive_damage(amount, type)` applies resistance and routes armor.
- Weapon configs add auto fire, recoil and damage falloff; `ItemPresentation`
  supplies derived stats to UI. `F3 → Items` grants content and creates a target.
- `add_item()` returns the **unaccepted remainder**, not the added count.
- Featured SVG icons: `assets/ui/field_icons/`; generated VFX: `assets/vfx/`.

## 30-second model

```text
ItemDefinition (shared immutable template)
  + ItemComponent Resources (capability/config data)
            |
            v
ItemStack (one mutable runtime instance: definition + quantity + runtime_values)
            |
            v
ItemContainerComponent (ownership: inventory, equipment, merchant stock, future NPCs)
            |
            v
Runtime Components/Nodes (Combat, Aiming, ItemLight, Trade) execute capabilities
            |
            v
UI observes containers and calls owner/system APIs; it does not own item state
```

Keep these layers separate:

- `ItemDefinition` and its item components are shared `Resource` data. Never mutate
  them to represent one physical item's state.
- `ItemStack.runtime_values` stores per-instance state such as endurance.
- `ItemContainerComponent` owns stacks while they are carried or equipped.
- `WorldItemActor` owns the same stack while it exists in the world.
- Runtime `Component` nodes contain behavior and receive `_physics_tick()` from
  `Creature`. Item components only describe capabilities.

## Source map

| Concern | Source of truth |
|---|---|
| Shared item schema | `scripts/items/ItemDefinition.gd`, `ItemComponent.gd` |
| Runtime item instance | `scripts/items/ItemStack.gd` |
| Item definitions/loadouts | `scripts/items/ItemCatalog.gd` |
| Generic storage/transfer | `scripts/components/ItemContainerComponent.gd` |
| Backpack + hotbar bindings | `scripts/components/InventoryComponent.gd` |
| Anatomical slots/equip conflicts | `scripts/components/EquipmentComponent.gd` |
| Weapon execution | `scripts/components/CombatComponent.gd` |
| Aim selection/throw input | `scripts/components/AimingSystem.gd` |
| Equipped light execution | `scripts/components/ItemLightSystem.gd` |
| World/deployed/thrown item | `scripts/WorldItemActor.gd` |
| Weapon config schema/load/hot reload | `scripts/weapons/`, `data/weapons.cfg` |
| Actor composition | `scripts/Creature.gd`, `scripts/Player.gd`, `scripts/Merchant.gd` |
| Inventory/equipment/trade UI | `scripts/InventoryPanel.gd`, `ItemSlotWidget.gd`, `Quickbar.gd` |
| Runtime config UI | `scripts/WeaponDebugTab.gd` |

## Data types and ownership

### `ItemDefinition`

Shared catalog template: `id`, display text, weight, stack limit, tags, icon, and
`Array[ItemComponent]`. Query behavior with `get_component(Type)` or `has_tag()`.
Definitions are built once by `ItemCatalog._build_catalog()` and reused by every
stack with that ID.

### `ItemStack`

Mutable physical instance:

```gdscript
var definition: ItemDefinition
var quantity: int
var runtime_values: Dictionary
```

`endurance()` lazily creates the `&"endurance"` value from
`EnduranceComponent.max_endurance`. Add future mutable state here, using stable
`StringName` keys and deep-copying nested values.

### Item components

| Component | Declares | Executed/read by |
|---|---|---|
| `EquippableComponent` | valid anatomical slots, modifiers | `EquipmentComponent` |
| `ConsumableComponent` | immediate use effects | `Player` use path |
| `ProjectileComponent` | thrown/projectile damage and speed | `AimingSystem`, combat/world actor |
| `LauncherComponent` | weapon config ID | `CombatComponent` |
| `AimComponent` | direct or lob aim parameters | `AimingSystem` |
| `CraftingPartComponent` | part type/quality | future crafting |
| `TradeValueComponent` | buy/sell value | `MerchantTradeComponent` |
| `EnduranceComponent` | capacity, drain, refill tag, depleted item | `ItemLightSystem`, `WorldItemActor` |
| `LightEmitterComponent` | point/spot light color, range, energy | light systems/world actor |
| `WorldActorComponent` | deploy/throw persistence behavior | `AimingSystem`, `WorldItemActor` |

A single definition may combine any compatible components. Examples: an apple is
consumable and throwable; a flare is equippable, throwable, deployable, luminous,
stateful, and becomes ash when depleted.

### Runtime components

`Creature._add_component()` assigns `component.creature`, adds the node, and keeps
it in the actor's component list. `Creature._physics_process()` calls each
component's `_physics_tick(delta)`. `Player` composes inventory, equipment, combat,
proficiency, light, aiming, health, movement, wallet, and humanoid profile systems.
NPCs can compose the same pieces without inheriting player UI or input.

## Container contract

`ItemContainerComponent` is the base for every carried collection. It supplies
slot and weight limits plus add, place, take, consume, split, swap, and transfer.

Critical invariants:

1. Exactly one owner holds a runtime `ItemStack`: a container or world actor.
2. Transfer stateful/unique items as stacks with `take_slot()`, `put_stack()`,
   `place_stack()`, or `move_slot_to()`. Do not recreate them with `add_item()`.
3. `put_stack()` preserves the original object when `max_stack == 1` or
   `runtime_values` is nonempty. Stateless stacks may merge.
4. `consume_at()` returns the original object when removing a whole stack; partial
   consumption returns a copied stack with copied runtime state.
5. Validate the destination before removing the source. Failed moves must leave
   ownership unchanged.

`InventoryComponent` adds tag queries/consumption and eight hotbar item-ID
bindings. A hotbar binding is a stable definition ID, not an inventory index.

`EquipmentComponent` is a specialized container with named slots:

```text
head face torso legs feet left_hand right_hand two_hand backpack accessory_1 accessory_2
```

It validates `EquippableComponent`, handles hand/two-hand conflicts, and returns
displaced gear to the source inventory only when the whole operation fits.

## Main flows

### Equip and hotbar

```text
UI/quick key -> Player activation method
             -> EquipmentComponent.equip_from_inventory()
             -> equipment_changed
             -> Player refreshes combat launcher, modifiers, aiming, lights, UI
```

### Fire a launcher

```text
equipped LauncherComponent.weapon_config_id
  -> WeaponConfigDatabase entry from data/weapons.cfg
  -> CombatComponent checks cooldown/magazine/ammo tag
  -> InventoryComponent.consume_tag() during reload
  -> spawn projectile(s), update proficiency, emit combat signals
```

Magazines are currently keyed by weapon config ID, so two weapons using the same
config share magazine state. Change that to stack runtime state before supporting
independent duplicate weapons.

### Throw or deploy an item

```text
RMB aim -> AimingSystem selects equipped lob-capable stack
LMB commit -> remove/decrement equipment stack
           -> WorldItemActor.launch()/deploy() receives that stack
           -> actor owns transform, flight, light, endurance, and landing
future pickup -> WorldItemActor.extract_stack() -> container.put_stack()
```

`ThrownItem.gd` is a compatibility subclass. Put new world behavior on
`WorldItemActor` or a focused runtime system, not in UI code.

### Light, endurance, refill, depletion

```text
equipment_changed -> ItemLightSystem rebuilds lights for equipped stacks
physics tick       -> drain each stack's endurance
battery use        -> refill_stack_from_inventory(target_stack, source_index)
endurance == 0     -> disable effect; optionally replace with depleted_item_id
```

If a depleted replacement cannot fit in inventory, it is deployed into the world.
The same `EnduranceComponent` and `LightEmitterComponent` work on carried and world
items.

### Trade

`MerchantTradeComponent` moves stacks between player and merchant containers and
updates `CurrencyWalletComponent`. The trade UI displays two inventories but does
not duplicate their contents. Give future humanoid NPCs their own inventory,
equipment, wallet, and stable character ID.

## Add or extend content

### Add a normal item

1. Add one `_item(...)` registration in `ItemCatalog._build_catalog()`.
2. Compose existing helper components; use tags for category queries.
3. Add `assets/ui/item_icons/<item_id>.webp` or an explicit icon alias.
4. Add it to a loadout/merchant stock only when intended.
5. Exercise catalog creation and its main interaction path.

### Add a weapon

1. Add a section to `data/weapons.cfg`; match `WeaponConfig` fields.
2. Add a catalog item with `EquippableComponent`,
   `LauncherComponent(config_id)`, and the required `AimComponent`.
3. Add an ammo item whose tags match the config's `ammo_tag`.
4. If adding a fire mode or aim mode, extend the typed config, database parser,
   combat/aim executor, debug UI, and smoke test together.

Do not copy weapon timing, damage, magazine, spread, or proficiency tuning into
the catalog or UI. `data/weapons.cfg` is authoritative and supports live reload.

### Add a new capability

1. Create a small `ItemComponent` Resource containing config only.
2. Add it to relevant catalog definitions.
3. Implement behavior in an owner/runtime system.
4. Connect refresh signals when equip/container changes affect the behavior.
5. Add UI only for information or actions the player needs.
6. Test composition with at least one existing component on the same item.

### Add a container or NPC owner

Subclass `ItemContainerComponent` only when policy differs from generic storage.
Compose inventory/equipment onto the NPC through `Creature._add_component()`.
Keep interaction authorization/range on the actor or interaction system; keep item
movement in container/trade APIs.

### Add an equipment slot

Update `EquipmentComponent.SLOT_ORDER`, equipment UI layout/context mapping, and
any hand-conflict rules. Item definitions opt in through `valid_slots`.

## UI and input boundaries

- `I`: backpack; `C`: character equipment; `E`: nearby interaction/trade.
- Number keys `1..8`: activate stable hotbar item IDs.
- Hold RMB to aim a lob; LMB commits a valid throw. Launcher input routes through
  combat according to its aim/fire mode.
- `ItemSlotWidget` carries drag context and source identity. `InventoryPanel`
  resolves the move through container/player APIs.
- UI refreshes from signals/current state. Never store authoritative quantity,
  endurance, magazine, currency, or ownership in controls.

## Verification

From the repository root, use the Godot 4.6.2 console binary:

```powershell
rtk proxy cmd.exe /d /c "set APPDATA=D:\workspace\AIGodot\.godot_local\appdata&& set LOCALAPPDATA=D:\workspace\AIGodot\.godot_local\localappdata&& D:\workspace\GodotRuntime\Godot_v4.6.2-stable_win64_console.exe --headless --path . --editor --quit"
rtk proxy cmd.exe /d /c "set APPDATA=D:\workspace\AIGodot\.godot_local\appdata&& set LOCALAPPDATA=D:\workspace\AIGodot\.godot_local\localappdata&& D:\workspace\GodotRuntime\Godot_v4.6.2-stable_win64_console.exe --headless --path . --script tests/weapon_system_smoke.gd"
rtk proxy cmd.exe /d /c "set APPDATA=D:\workspace\AIGodot\.godot_local\appdata&& set LOCALAPPDATA=D:\workspace\AIGodot\.godot_local\localappdata&& D:\workspace\GodotRuntime\Godot_v4.6.2-stable_win64_console.exe --headless --path . --script tests/light_item_system_smoke.gd"
```

Use project-local `APPDATA`/`LOCALAPPDATA` in restricted environments. Also check
the interaction-specific scripts under `.godot_local/` when changing inventory,
merchant, or throwing flows.

## Current limits

- Catalog definitions are constructed in code; item `.tres` authoring/import is
  not implemented.
- Item stack save/load and persistent world-item save data are not implemented.
- `WorldItemActor.extract_stack()` exists, but generic world pickup interaction is
  not wired.
- Crafting parts exist as data; combination/recipe execution is future work.
- Magazine state is per weapon config ID, not per weapon stack.
- Equipped stack quantity can exceed one through the inventory equip path; code
  handling equipped throwables must support decrementing a stack.

## Change checklist

- Shared config stays immutable; per-item mutations stay on `ItemStack`.
- Every transfer preserves quantity, runtime state, and exactly one owner.
- Tags/config IDs match across catalog and weapon/endurance consumers.
- Equip changes refresh combat, aim, lights, modifiers, hotbar, and visible UI.
- New behavior works for player and reusable NPC/container owners where relevant.
- Parse check and focused smoke tests pass without new Godot errors.
