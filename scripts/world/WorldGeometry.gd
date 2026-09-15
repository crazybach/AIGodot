class_name WorldGeometry
extends RefCounted
## Shared blockout geometry; authored interior scenes can replace these visuals.
static func polygon(parent: Node2D, points: PackedVector2Array, color: Color) -> Polygon2D:
	var shape := Polygon2D.new()
	shape.polygon = points
	shape.color = color
	parent.add_child(shape)
	return shape

static func rect(parent: Node2D, area: Rect2, color: Color) -> Polygon2D:
	return polygon(parent, PackedVector2Array([area.position, Vector2(area.end.x, area.position.y), area.end, Vector2(area.position.x, area.end.y)]), color)

static func wall(floor_node: WorldLayer, area: Rect2, color := Color("#929f9e")) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.position = area.get_center()
	floor_node.add_child(body)
	var collider := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = area.size
	collider.shape = shape
	body.add_child(collider)
	rect(body, Rect2(-area.size / 2, area.size), color)
	rect(body, Rect2(-area.size / 2, Vector2(area.size.x, 2)), color.lightened(0.2))
	var occluder := LightOccluder2D.new()
	var poly := OccluderPolygon2D.new()
	var local := Rect2(-area.size / 2, area.size)
	poly.polygon = PackedVector2Array([local.position, Vector2(local.end.x, local.position.y), local.end, Vector2(local.position.x, local.end.y)])
	occluder.occluder = poly
	body.add_child(occluder)
	floor_node.solid_rects.append(area)
	return body

static func label(parent: Node2D, point: Vector2, title: String, font_size := 14, color := Color("#bed0cd")) -> Label:
	var result := Label.new()
	result.position = point
	result.text = title
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	result.add_theme_font_size_override("font_size", font_size)
	result.modulate = color
	parent.add_child(result)
	return result
