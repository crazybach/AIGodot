# District streaming contract

## Why this layer exists

Godot 4 provides [background resource loading](https://docs.godotengine.org/en/stable/tutorials/io/background_loading.html) through `ResourceLoader.load_threaded_request/get_status/get`, but it does not prescribe a whole-world cell lifecycle. The [thread-safe API guidance](https://docs.godotengine.org/en/stable/tutorials/performance/thread_safe_apis.html) limits scene-tree edits on worker threads. Therefore resource I/O and scene activation are separate concerns: future authored `.tscn` cells should prefetch resources in a thread, poll status across frames, then instantiate/attach on the main thread. Current outer cells are generated from already resident definitions, so they have no disk I/O to thread.

## Addresses and ownership

`DistrictBuilder.build()` reads `data/district_streaming.cfg`. The editor-authored `AshdownDistrict.tscn` is cell `(0,0)` and defines the cell size (`6000 × 4200` world units). Radius `1` yields a `3 × 3` grid: `18000 × 12600` units, nine times the former area. The original hub stays resident because its ten buildings, quests, NPCs, enemies, and player-modified crossings have established runtime state. `DistrictStreamManager.cell_at(point)` and `cell_bounds(coord)` use the same address on ground and roof floors. A cell may be replaced by an authored scene in the builder later without changing the stream manager.

`DistrictStreamManager` owns activation, hysteresis, cache, and the player-near priority queue. The viewport plus `load_margin` requests cells before their geometry enters view. `unload_margin` is larger to prevent boundary thrashing. Normal frame updates build at most `builds_per_frame` cells; explicit sync and floor travel can build more immediately. Floor travel calls `ensure_at(destination)` before moving the player, then refreshes the neighborhood. Each cell has a `WorldSector` for ground and one for roofs. Only the current floor is in the SceneTree. Detached cells retain loot and other object identity until evicted.

`WorldLayer.attach_sector/detach_sector` updates collision, interaction, weather shelter, encounters, and building indexes. `build_navigation()` rasterizes only the focus cell and attached neighbors; `map_bounds` remains the full world rectangle for the HUD. New streamed objects should belong to a sector rather than a permanent floor child. Keep the central hub's persistent NPC/quest content on the authored floor until it has an explicit save contract.

## State and content

`cold_cache_limit` bounds detached cell nodes. Eviction calls `WorldSector.stream_snapshot()` and frees both floor variants. Objects with mutable state implement `stream_snapshot/stream_restore`; `InteriorProp` currently records slot item ID, quantity, and runtime values. New stateful props, bridges, eggs, NPCs, or enemies placed in evictable cells must implement a state contract before being added there. Compact snapshots remain in memory for this iteration; disk persistence should serialize them by `(coord, floor_id, object_name)` for an unbounded world.

Outer cells reuse the hub road pattern and generate four varied orthogonal buildings, elevators, and searchable supply cabinets. Building IDs and cell contents derive deterministically from the coordinate. `DistrictBuilder.build_cell` is the content factory and `_building` is the shared construction path. A cell can be authored by replacing that factory with a scene source; avoid building geometry directly in gameplay or HUD code.

The top-center HUD shows active/total cells, player cell, cached cells, and queued cells. The minimap outlines the grid and highlights the focus/active cells. `F3 → Layers` exposes status, immediate sync, and config reload. `grid.radius` requires restart because it changes world bounds and building addresses; margins and cache settings reload live.

## Checks

Run `tests/district_streaming_smoke.gd` for seam crossing, floor travel, navigation locality, detach/reuse, eviction/restore, and the nine-times area. Run `tests/district_layers_smoke.gd` for authored hub behavior. Render `tests/district_streaming_visual.gd` to inspect the street seam, outer cell, roof, minimap, and debug line. Existing gameplay smoke tests guard weather, enemies, quests, and inventory.
