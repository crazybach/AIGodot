# Isometric Tile Assembly Sample

This sample uses `res://assets/tiles/dungeon_isometric_tiles.png`, copied from
the raw candidate download so Godot can import it. Open
`IsometricTileOptimizationSample.tscn` and run the current scene.

## Recommendation

Use a logical diamond grid with `64 x 32` floor cells:

```gdscript
func cell_to_screen(cell: Vector2i) -> Vector2:
	return Vector2(
		(cell.x - cell.y) * 32.0,
		(cell.x + cell.y) * 16.0
	)
```

For this asset style, split rendering into two categories:

| Content | Geometry | Reason |
| --- | --- | --- |
| Flat floor, lava, grass, floor decals | Diamond quad: 4 vertices, 2 triangles | Matches the opaque footprint and avoids shading transparent rectangle corners |
| Doors, walls, pillars, chests, characters | Rectangular sprite quad, y-sorted | Artwork extends vertically outside the floor diamond |

Do not model every cell as independent triangle tiles. A diamond quad already
renders as two triangles. Four triangular sub-tiles add authoring and neighbor
handling complexity without reducing the two-triangle cost of a normal floor
diamond.

## TileMapLayer Workflow

For an editor-painted map in Godot 4:

1. Repack ground tiles into a regular atlas of `64 x 32` regions.
2. Create a `TileSet` with `tile_shape = TileSet.TILE_SHAPE_ISOMETRIC` and
   `tile_size = Vector2i(64, 32)`.
3. Put ground, tall structures, decals, and collisions on separate
   `TileMapLayer` nodes.
4. Order tall objects and actors by their cell diagonal or screen `y`
   position. The basic diagonal key is `cell.x + cell.y`.
5. Keep the `TileMapLayer` approach unless profiling shows fill-rate pressure.
   Godot batches TileMap updates and gives you terrains, collisions, navigation,
   and editor painting.

The source image mixes floor diamonds and tall sprites in one loose sheet, so a
production `TileSetAtlasSource` should be built from a repacked atlas rather
than exposing the whole PNG as one uniform grid.

## Optimized Static Floor

The right side of the sample builds one `ArrayMesh` surface:

- Each floor cell contributes four diamond vertices and six indices.
- UV points use the diamond's top, right, bottom, and left points in the
  original texture region.
- Multiple terrain variants can still use one texture and one mesh surface.
- Tall props should remain regular `Sprite2D` quads above the floor mesh after
  being extracted into clean non-overlapping atlas regions.

This does not reduce vertices compared with a rectangular quad. It reduces
transparent-pixel overdraw and can reduce draw submission overhead for a
static floor. Chunk a large map into rebuildable pieces, such as `16 x 16` or
`32 x 32` cells, instead of rebuilding one whole-world mesh after edits.

## Regions Used

The sample reads these top-surface regions directly from the supplied PNG.
Some original tiles contain a visible raised side below this surface; the
sample intentionally uses only the diamond top when constructing continuous
walkable terrain:

| Content | Regions |
| --- | --- |
| Floor top variants: gray stone, brown, grass, lava | `(128, 32, 64, 32)`, `(320, 32, 64, 32)`, `(384, 32, 64, 32)`, `(448, 32, 64, 32)` |

For production, crop and pad chosen source regions into a regular texture atlas
to avoid filter bleeding and to make terrain setup comfortable in the editor.
The doors and raised blocks in the source sheet overlap adjacent image regions,
so this floor-only comparison intentionally does not crop them as standalone
props.
