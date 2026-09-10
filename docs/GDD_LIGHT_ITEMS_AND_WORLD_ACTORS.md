# Light Items and World Actors

## Player-facing behavior

Three equipable left-hand light items now work with the time-of-day and fog systems:

| Item | Light | Endurance | Depletion | World behavior |
|---|---|---:|---|---|
| Survivor Flashlight | Focused spot, 430 px | 100, drains 0.8/s | Light switches off | Can be refilled with a D-cell battery |
| Fire Torch | Warm round light, 275 px | 100, drains 0.42/s | Becomes Cold Ash | Can be aimed and thrown while burning |
| Emergency Flare | Bright orange-red round light, 360 px | 100, drains 8/s | Becomes Cold Ash | Can be aimed and thrown; keeps lighting during flight and after landing |

Equip these through the backpack UI. Hold `RMB` to display the lob trajectory and press `LMB` to throw the selected hand item. Clicking a D-cell battery while a partially depleted flashlight is equipped consumes one battery and restores 55 endurance. The HUD and item slots expose remaining endurance.

## Runtime architecture

`ItemDefinition` and its ItemComponents remain shared, immutable design data. `EnduranceComponent` describes capacity, drain, refill compatibility, and the depletion result. `LightEmitterComponent` describes the fog-aware point or spot light. `WorldActorComponent` declares that behavior remains active outside a container.

Mutable endurance belongs to `ItemStack.runtime_values`. Transfers between backpack and equipment move the same stack object, so they preserve state. When thrown or deployed, a `WorldItemActor` takes ownership of that same stack. Because it is a `Node2D`, it supplies world transform, scene-tree lifecycle, drawing, collision, and processing. `extract_stack()` provides the reverse path for a later pickup system.

`ItemLightSystem` materializes one `LightSource2D` per equipped light item, rotates spot lights with the character, drains each stack independently, and resolves depletion. `WorldItemActor` performs the equivalent work for deployed stacks. Both use the same data components and register their lights with the existing `LightingManager`, so the fog shader receives the same attenuation data whether the light is carried or lying in the street.

This follows Godot's documented split: [Resources are data containers used by Nodes](https://docs.godotengine.org/en/stable/tutorials/scripting/resources.html), while [PointLight2D is a positional Node2D light whose texture defines its shape](https://docs.godotengine.org/en/stable/classes/class_pointlight2d.html). Godot specifically lists torches, fire, and projectiles as point-light use cases in its [2D lights and shadows guide](https://docs.godotengine.org/en/stable/tutorials/2d/2d_lights_and_shadows.html). If deployed objects later need authored animations or complex collision trees, `WorldItemActor` can instantiate an assigned [`PackedScene`](https://docs.godotengine.org/en/stable/classes/class_packedscene.html) without moving persistent item state into scene nodes.

## Extension path

The refill rule uses item tags, so future crafting can call the same operation for flashlight + battery without special-casing a particular battery definition. Further item actors can add smoke, sound, traps, timed explosives, or portal effects as new data components and runtime systems. Saving a game only needs to serialize the item definition ID, quantity, and `runtime_values`; scene actors can rebuild their presentation after loading.
