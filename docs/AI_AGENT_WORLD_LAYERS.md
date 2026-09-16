# World and level system: AI agent map

## Current district

Ashdown is a 6000 × 4200 world with six roads and ten irregular buildings: apartments,
offices, clinic, relay exchange, shopping mall, warehouse, hotel, corner market,
freight depot, and transit station. Each has a ground interior and same-shape roof.
The mall is the largest chunk: entrance hall, central atrium, fountain, grocery,
clothing/travel shop, pharmacy, outdoor supply, food court, service locker, shelves,
closets and counters. Searchable storage contains persistent ItemStacks.

Ground has hazardous mist, 16 dormant eggs, and 14 slow wanderers. Eggs hatch only
inside their short trigger radius. Hatchlings have short sight and wait if they lose
the player; wanderers continue slow patrol. All monsters require close range and
line of sight before chasing. Roofs have clear air, the continuing day/night cycle,
and no hostile encounters. A-B has a crossing; B-C consumes a portable ladder.

Start: lobby A, facing its lift, with one portable ladder. WASD moves; E searches,
trades, uses lifts, or builds a crossing. I/C opens inventory/equipment. F3 → Layers
teleports to any lift and tunes exposure. F3 → World changes time of day.

## Editor-first authoring

Open `scenes/world/AshdownDistrict.tscn` in Godot. The `DistrictLayout` root owns map
bounds and road rectangles. Its children are editor-visible authoring markers:

- `BuildingMarker`: position plus a `BuildingDefinition` resource. The resource owns
  an orthogonal footprint polygon, exterior doors, elevator position, colors, and
  optional ground/roof interior PackedScenes. Reuse one definition as a template or
  make it local to a marker for a unique building.
- `RoofLinkMarker`: endpoints, building IDs, and initial built state. It supports
  horizontal or vertical links.
- `EncounterMarker`: egg/wanderer kind, sight radius, and egg hatch delay.
- `InteriorProp`: place in an interior scene; configure visual kind, size, collision,
  storage capacity, and starting item dictionary. A prop can be furniture only.

Reusable building resources live in `data/world/buildings/`; reusable interior chunks
live in `scenes/world/interiors/`. `DistrictBuilder` converts the authored layout to
runtime WorldLayers, generates exterior collision/occlusion and roads, instances
interiors, indexes props for navigation/interactions, and constructs roof crossings.
`data/district.cfg` contains live environment tuning only. Structural map data belongs
in Godot scenes/resources, so designers can move and edit it visually.

Current footprint restriction: orthogonal polygon edges and translation-only building
markers. Keep local interior coordinates inside the footprint. Door/link points must
lie exactly on polygon edges. The builder asserts invalid authoring early.

## Runtime ownership

| Source | Responsibility |
|---|---|
| `WorldLayerDefinition.gd` | Layer ID, entry addresses, fog/hazard/night policy |
| `WorldLayer.gd` | Floor-local geometry, actors, interactions and AStar grid |
| `LayerManager.gd` | Cache floors, preserve player identity, apply environment |
| `LayerPortal.gd` | Reusable destination ID + entry ID for lifts/stairs/doors |
| `DistrictBuilder.gd` | Compile editor scene into ground and roof runtime layers |
| `InteriorProp.gd` | Physical furniture plus optional ItemContainerComponent |
| `MistEgg.gd` | Dormant, damageable proximity hatch encounter |
| `MistStalker.gd` | Fog visibility, short-sight LOS AI and pathfinding |
| `RooftopBridge.gd` | Construction capability → consume item → open crossing |
| `DistrictHUD.gd` | Scaled irregular-footprint map and contextual prompts |
| `EnvironmentExposureComponent.gd` | Passive stamina depletion then mist damage |
| `GameManager.gd` | Services, assembly, encounters, NPC spawning, E interaction routing |

`GameManager → LayerManager → active WorldLayer → actors/items/props`. Lighting, fog,
weapon database and HUD remain session services. Spawn bullets, AoEs and dropped items
beneath the owning actor's floor. Only the active floor is in the SceneTree; detached
floors keep inventory, construction and encounter state while physics and processing
pause. The same Player is reparented, preserving stacks, magazine, endurance, health,
stamina, skills and wallet. LightSource2D registers on enter_tree and unregisters on
exit_tree. The manager frees detached floors during scene teardown.

Storage reuses `ItemContainerComponent`; no loot-specific item state exists. The
inventory UI uses the same ItemSlotWidgets as trade, but moves stacks directly without
currency. Click/drag supports backpack ↔ storage. Containers and their stack instances
remain on the cached floor through roof travel.

## Rooftop social actors

`GameManager._spawn_rooftop_npcs()` loads ten records from
`data/npc_rooftop_content.json`, initializes their composed components once, and
caches them under the detached roof layer. `SurvivorNPC` instances join the same
`WorldLayer.interactables` list as elevators and containers, so E-routing remains
distance based. Dialogue, quests, relationship changes, and optional two-pack
trade are documented in `docs/GDD_NPC_DIALOGUE_QUESTS.md`.

Add a new floor or room as a WorldLayer, assign a unique definition ID and entries,
register it, then point LayerPortals at `(destination_id, entry_id)`. The player,
inventory, fog and weapon systems do not need duplication. Defer travel if called from
a physics callback. Floor roots currently use identity transform.

## Environment and limits

Ground defaults: 1.2 stamina/s while idle; 3 HP/s after stamina reaches zero. Natural
recovery is disabled in mist and restored on roofs; consumables still work. Mist damage
uses typed `mist` damage and bypasses kinetic armor. Hiding the fog visualization in
debug does not disable exposure. Roof night ambient is brighter and global time does
not reset.

State is in memory until restart. Inactive floor simulation pauses. Equal-height roofs
use physical parapets; there is no fall/height model, lift animation, arbitrary ladder
placement, save serialization, or streaming between district chunks yet.

## Verification

`tests/district_layers_smoke.gd` covers ten buildings/lifts, irregular footprints,
loot UI transfer, 16 eggs, 14 wanderers, hatching, floor isolation, stamina/death,
lighting, persistent player/item state, crossing collision and construction. The visual
test captures lobby, street, night, mall, loot, roof, crossing and debug views at 1080p.
Also run `field_collection_smoke.gd` and `light_item_system_smoke.gd` after changing
floor ownership, containers, or ItemCatalog.
