class_name WalkableFloor
extends NavigationRegion2D
## The floor Stella can walk on with point-and-click movement.
##
## The navigation polygon is built at load time from `outline`, the same polygon
## that bounds keyboard movement, inset so Stella's feet never scrape its edges.
## Edit the outer outline and optional solid obstacle polygons in the room scene;
## navigation subtracts expanded obstacles and physics uses the same solid shapes.
##
## Characters query paths through NavigationServer2D on their world's map, so they
## don't need a reference to this node.

## The room's walkable outline (a CollisionPolygon2D in segments mode).
@export var outline: CollisionPolygon2D
## Solid scene-authored CollisionPolygon2D children; navigation avoids the same
## shapes that stop debug keyboard movement. Clear of the whole feet rectangle.
@export var obstacles: Node2D
## The walker's feet collision, relative to their origin (match Stella's
## FeetCollision). The outline is inset by it so a path never leads into a wall.
@export var footprint: Rect2 = Rect2(-28, -14, 56, 14)
## Extra clearance beyond the footprint.
@export var edge_margin: float = 3.0


func _ready() -> void:
	if outline == null:
		return
	var to_local := global_transform.affine_inverse() * outline.global_transform
	var points := to_local * outline.polygon
	var blocked: Array[PackedVector2Array] = []
	if obstacles != null:
		for shape in obstacles.get_children():
			if shape is CollisionPolygon2D and not shape.disabled:
				var transform: Transform2D = global_transform.affine_inverse() * shape.global_transform
				blocked.append(expand_obstacle(transform * shape.polygon, footprint, edge_margin))
	navigation_polygon = build_navigation_polygon(inset_outline(points, footprint, edge_margin), blocked)


static func build_navigation_polygon(walkable: PackedVector2Array, blocked: Array[PackedVector2Array] = []) -> NavigationPolygon:
	var navigation := NavigationPolygon.new()
	navigation.agent_radius = 0.0 # Already inset.
	# Map-sized paths have sub-pixel corners; bake and merge at the same precision.
	navigation.cell_size = ProjectSettings.get_setting("navigation/2d/default_cell_size", 1.0)
	var source := NavigationMeshSourceGeometryData2D.new()
	source.add_traversable_outline(walkable)
	for obstruction in blocked:
		source.add_obstruction_outline(obstruction)
	NavigationServer2D.bake_from_source_geometry_data(navigation, source)
	return navigation


## The origins at which `box` (relative to the origin) stays, approximately, inside
## `points`. Offsetting is isotropic, so the polygon is squashed to make the box
## square, offset by its half size, stretched back, then shifted for the box's
## offset from the origin.
static func inset_outline(points: PackedVector2Array, box: Rect2, margin: float) -> PackedVector2Array:
	var half_extents := box.size * 0.5
	var squash := Vector2(1.0, half_extents.x / maxf(half_extents.y, 0.001))
	var squashed := PackedVector2Array()
	for point in points:
		squashed.append(point * squash)
	var largest := PackedVector2Array()
	for candidate: PackedVector2Array in Geometry2D.offset_polygon(squashed, -(half_extents.x + margin), Geometry2D.JOIN_MITER):
		if candidate.size() > largest.size():
			largest = candidate
	var result := PackedVector2Array()
	for point in largest:
		result.append(point / squash - box.get_center())
	return result


## Expand scenery by the same footprint used to inset the floor: paths keep
## Stella's feet clear of it, rather than merely steering her centre around it.
static func expand_obstacle(points: PackedVector2Array, box: Rect2, margin: float) -> PackedVector2Array:
	var half_extents := box.size * 0.5
	var squash := Vector2(1.0, half_extents.x / maxf(half_extents.y, 0.001))
	var squashed := PackedVector2Array()
	for point in points:
		squashed.append(point * squash)
	var expanded := Geometry2D.offset_polygon(squashed, half_extents.x + margin, Geometry2D.JOIN_MITER)
	var result := PackedVector2Array()
	if not expanded.is_empty():
		for point in expanded[0]:
			result.append(point / squash - box.get_center())
	return result
