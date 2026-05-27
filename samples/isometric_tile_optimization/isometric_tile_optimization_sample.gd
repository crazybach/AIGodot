extends Node2D

const ATLAS: Texture2D = preload("res://assets/tiles/dungeon_isometric_tiles.png")
const CELL_SIZE := Vector2(64.0, 32.0)
const HALF_CELL := CELL_SIZE * 0.5
const FLOOR_REGIONS: Array[Rect2] = [
	Rect2(128.0, 32.0, 64.0, 32.0),
	Rect2(320.0, 32.0, 64.0, 32.0),
	Rect2(384.0, 32.0, 64.0, 32.0),
	Rect2(448.0, 32.0, 64.0, 32.0),
]
const MAP_WIDTH := 8
const MAP_HEIGHT := 7
const LEFT_ORIGIN := Vector2(270.0, 220.0)
const RIGHT_ORIGIN := Vector2(920.0, 220.0)

var floor_cells: Array[Vector2i] = []
var floor_textures: Array[AtlasTexture] = []


func _ready() -> void:
	_prepare_regions()
	_create_room_cells()
	_build_text()
	_build_sprite_quad_floor(LEFT_ORIGIN)
	_build_diamond_mesh_floor(RIGHT_ORIGIN)
	_build_debug_overlay()
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(1280.0, 720.0)), Color("#10151d"))
	draw_rect(Rect2(28.0, 88.0, 578.0, 490.0), Color("#18222e"))
	draw_rect(Rect2(674.0, 88.0, 578.0, 490.0), Color("#18222e"))
	draw_rect(Rect2(28.0, 88.0, 578.0, 490.0), Color("#334657"), false, 2.0)
	draw_rect(Rect2(674.0, 88.0, 578.0, 490.0), Color("#334657"), false, 2.0)


func _prepare_regions() -> void:
	for region in FLOOR_REGIONS:
		floor_textures.append(_make_atlas_texture(region))


func _make_atlas_texture(region: Rect2) -> AtlasTexture:
	var texture := AtlasTexture.new()
	texture.atlas = ATLAS
	texture.region = region
	texture.filter_clip = true
	return texture


func _create_room_cells() -> void:
	for y in range(MAP_HEIGHT):
		for x in range(MAP_WIDTH):
			var cell := Vector2i(x, y)
			if _is_room_cell(cell):
				floor_cells.append(cell)

	floor_cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.x + a.y < b.x + b.y
	)


func _is_room_cell(cell: Vector2i) -> bool:
	if cell.x == 0 and cell.y >= 5:
		return false
	if cell.x == MAP_WIDTH - 1 and cell.y <= 1:
		return false
	return not (cell.x == 4 and cell.y == 3)


func _cell_position(cell: Vector2i) -> Vector2:
	return Vector2(
		(cell.x - cell.y) * HALF_CELL.x,
		(cell.x + cell.y) * HALF_CELL.y
	)


func _floor_variant(cell: Vector2i) -> int:
	return abs(cell.x * 5 + cell.y * 3) % FLOOR_REGIONS.size()


func _build_sprite_quad_floor(origin: Vector2) -> void:
	var layer := Node2D.new()
	layer.name = "RectangularQuadFloor"
	layer.z_index = 1
	add_child(layer)

	for cell in floor_cells:
		var tile := Sprite2D.new()
		tile.texture = floor_textures[_floor_variant(cell)]
		tile.position = origin + _cell_position(cell)
		tile.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		layer.add_child(tile)


func _build_diamond_mesh_floor(origin: Vector2) -> void:
	var vertices := PackedVector2Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var atlas_size := Vector2(ATLAS.get_width(), ATLAS.get_height())

	for cell in floor_cells:
		var center := origin + _cell_position(cell)
		var region := FLOOR_REGIONS[_floor_variant(cell)]
		var first_vertex := vertices.size()

		vertices.append(center + Vector2(0.0, -HALF_CELL.y))
		vertices.append(center + Vector2(HALF_CELL.x, 0.0))
		vertices.append(center + Vector2(0.0, HALF_CELL.y))
		vertices.append(center + Vector2(-HALF_CELL.x, 0.0))

		uvs.append((region.position + Vector2(HALF_CELL.x, 0.0)) / atlas_size)
		uvs.append((region.position + Vector2(CELL_SIZE.x, HALF_CELL.y)) / atlas_size)
		uvs.append((region.position + Vector2(HALF_CELL.x, CELL_SIZE.y)) / atlas_size)
		uvs.append((region.position + Vector2(0.0, HALF_CELL.y)) / atlas_size)

		indices.append_array(PackedInt32Array([
			first_vertex,
			first_vertex + 1,
			first_vertex + 2,
			first_vertex,
			first_vertex + 2,
			first_vertex + 3,
		]))

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	var layer := MeshInstance2D.new()
	layer.name = "DiamondFloorBatch"
	layer.mesh = mesh
	layer.texture = ATLAS
	layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	layer.z_index = 1
	add_child(layer)


func _build_debug_overlay() -> void:
	var left_overlay := FootprintOverlay.new()
	left_overlay.name = "TransparentQuadBounds"
	left_overlay.origin = LEFT_ORIGIN
	left_overlay.cells = floor_cells
	left_overlay.show_rectangles = true
	left_overlay.z_index = 4
	add_child(left_overlay)

	var right_overlay := FootprintOverlay.new()
	right_overlay.name = "DiamondMeshBounds"
	right_overlay.origin = RIGHT_ORIGIN
	right_overlay.cells = floor_cells
	right_overlay.show_rectangles = false
	right_overlay.z_index = 4
	add_child(right_overlay)


func _build_text() -> void:
	_add_label(
		"ISOMETRIC FLOOR GEOMETRY - same atlas regions, same room cells",
		Vector2(28.0, 24.0),
		24,
		Color("#f3f6fb")
	)
	_add_label(
		"Standard floor quads",
		Vector2(48.0, 106.0),
		22,
		Color("#f1bc70")
	)
	_add_label(
		"64 x 32 rectangle per tile\n4 vertices, 2 triangles\norange corners still consume fill rate",
		Vector2(48.0, 482.0),
		16,
		Color("#d4dce6")
	)
	_add_label(
		"Batched diamond floor mesh",
		Vector2(694.0, 106.0),
		22,
		Color("#6bd1c9")
	)
	_add_label(
		"diamond per tile in one ArrayMesh surface\n4 vertices, 2 triangles\nno transparent floor corners shaded",
		Vector2(694.0, 482.0),
		16,
		Color("#d4dce6")
	)
	_add_label(
		"Tall doors/walls should remain ordered rectangular quads. A diamond is already two triangles;\nsplitting every tile into separate triangle assets does not lower the triangle count.",
		Vector2(42.0, 606.0),
		16,
		Color("#bdcbd8")
	)


func _add_label(text: String, position_value: Vector2, size_value: int, color: Color) -> void:
	var label := Label.new()
	label.text = text
	label.position = position_value
	label.add_theme_font_size_override("font_size", size_value)
	label.add_theme_color_override("font_color", color)
	label.z_index = 8
	add_child(label)


class FootprintOverlay:
	extends Node2D

	var origin := Vector2.ZERO
	var cells: Array[Vector2i] = []
	var show_rectangles := false

	func _ready() -> void:
		queue_redraw()

	func _draw() -> void:
		for cell in cells:
			var center := origin + Vector2(
				(cell.x - cell.y) * 32.0,
				(cell.x + cell.y) * 16.0
			)
			var corners := PackedVector2Array([
				center + Vector2(0.0, -16.0),
				center + Vector2(32.0, 0.0),
				center + Vector2(0.0, 16.0),
				center + Vector2(-32.0, 0.0),
				center + Vector2(0.0, -16.0),
			])
			if show_rectangles:
				draw_rect(
					Rect2(center - Vector2(32.0, 16.0), Vector2(64.0, 32.0)),
					Color(1.0, 0.45, 0.2, 0.24),
					false,
					1.0
				)
			draw_polyline(
				corners,
				Color(0.35, 0.92, 0.86, 0.55) if not show_rectangles else Color(1.0, 0.62, 0.31, 0.42),
				1.0
			)
