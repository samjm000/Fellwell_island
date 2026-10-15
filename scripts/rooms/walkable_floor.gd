class_name WalkableFloor
extends NavigationRegion2D
## The floor Stella can walk on with point-and-click movement.
##
## The navigation polygon is built at load time from `outline`, the same polygon
## that bounds keyboard movement, inset so Stella's feet never scrape its edges.
## There is one authored floor shape, so click-walking and collision always agree;
## reshape the floor by editing the outline in the room scene.
##
## Characters query paths through NavigationServer2D on their world's map, so they
## don't need a reference to this node.

## The room's walkable outline (a CollisionPolygon2D in segments mode).
@export var outline: CollisionPolygon2D
## Half the size of the walker's feet collision. The outline is inset by this
## (horizontally and vertically) so a path never leads into a wall.
@export var footprint_half_extents: Vector2 = Vector2(28, 7)
## Extra clearance beyond the footprint.
@export var edge_margin: float = 3.0


func _ready() -> void:
	if outline == null:
		return
	var to_local := global_transform.affine_inverse() * outline.global_transform
	var points := to_local * outline.polygon
	navigation_polygon = build_navigation_polygon(inset_outline(points, footprint_half_extents, edge_margin))


static func build_navigation_polygon(walkable: PackedVector2Array) -> NavigationPolygon:
	var navigation := NavigationPolygon.new()
	navigation.agent_radius = 0.0 # Already inset.
	var source := NavigationMeshSourceGeometryData2D.new()
	source.add_traversable_outline(walkable)
	NavigationServer2D.bake_from_source_geometry_data(navigation, source)
	return navigation


## Shrinks `points` so a box of `half_extents` centred anywhere inside the result
## stays (approximately) inside the original. Offsetting is isotropic, so the
## polygon is squashed to make the box square, offset, and stretched back.
static func inset_outline(points: PackedVector2Array, half_extents: Vector2, margin: float) -> PackedVector2Array:
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
		result.append(point / squash)
	return result
