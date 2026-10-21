extends Node2D
## Debug drawing for checking a room's point-and-click authoring against its art:
## the walkable floor (green), each hotspot (yellow), approach points with their
## interaction radius (cyan), and prompt anchors (magenta). Used by the screenshot
## capture; add it to a room by hand to check authoring in a running game.

@export var room: Node


func _ready() -> void:
	z_index = 100


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if room == null:
		return
	for region in room.find_children("*", "NavigationRegion2D", true, false):
		var navigation: NavigationPolygon = region.navigation_polygon
		if navigation == null:
			continue
		for index in navigation.get_polygon_count():
			var points := PackedVector2Array()
			for vertex in navigation.get_polygon(index):
				points.append(region.global_transform * navigation.vertices[vertex])
			draw_colored_polygon(points, Color(0.2, 1.0, 0.3, 0.18))
			draw_polyline(points + PackedVector2Array([points[0]]), Color(0.2, 1.0, 0.3, 0.6), 1.0)
	var obstacles := room.get_node_or_null("RoomBounds/Obstacles")
	if obstacles != null:
		for shape in obstacles.get_children():
			if shape is CollisionPolygon2D:
				var points: PackedVector2Array = shape.global_transform * shape.polygon
				draw_colored_polygon(points, Color(1.0, 0.2, 0.15, 0.22))
				draw_polyline(points + PackedVector2Array([points[0]]), Color(1.0, 0.25, 0.2, 0.9), 2.0)
	for node in get_tree().get_nodes_in_group(Interactable.GROUP):
		var target := node as Interactable
		var hotspot := target.get_node_or_null("Hotspot")
		if hotspot != null:
			for shape in hotspot.get_children():
				if shape is CollisionPolygon2D:
					var points: PackedVector2Array = shape.global_transform * shape.polygon
					draw_polyline(points + PackedVector2Array([points[0]]), Color(1, 0.9, 0.1, 0.95), 2.0)
		var approach := target.get_approach_position()
		draw_arc(approach, target.interaction_radius, 0, TAU, 32, Color(0.2, 0.9, 1.0, 0.9), 2.0)
		draw_circle(approach, 3.0, Color(0.2, 0.9, 1.0))
		draw_circle(target.get_prompt_position(), 4.0, Color(1, 0.2, 0.9))
