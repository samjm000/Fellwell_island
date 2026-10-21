extends SceneTree
## Rebuild the editor-authored map outline from the painted path centrelines.
## Run explicitly after changing these routes; runtime uses the saved polygon.
const SCENE := "res://scenes/rooms/island_map.tscn"

func _init() -> void:
	var routes := [
		PackedVector2Array([Vector2(551,362), Vector2(529,371), Vector2(497,380), Vector2(488,396), Vector2(516,411), Vector2(541,425), Vector2(567,439), Vector2(574,464), Vector2(590,480), Vector2(572,499), Vector2(565,519), Vector2(577,541), Vector2(611,548), Vector2(633,548), Vector2(653,556), Vector2(665,570), Vector2(650,603), Vector2(637,629), Vector2(632,655), Vector2(651,679), Vector2(676,706), Vector2(696,724), Vector2(720,741), Vector2(770,746), Vector2(803,729), Vector2(800,708)]),
		PackedVector2Array([Vector2(803,729), Vector2(837,738), Vector2(873,735), Vector2(907,742), Vector2(921,746), Vector2(941,752)]),
		PackedVector2Array([Vector2(551,362), Vector2(582,365), Vector2(607,355), Vector2(621,338), Vector2(622,320), Vector2(604,301), Vector2(590,298), Vector2(565,287), Vector2(549,274), Vector2(560,258), Vector2(569,244), Vector2(551,233)]),
		PackedVector2Array([Vector2(565,519), Vector2(538,535), Vector2(504,541), Vector2(479,537), Vector2(463,535), Vector2(445,535)])]
	var outline := PackedVector2Array()
	for route: PackedVector2Array in routes:
		for i in route.size():
			route[i] = Vector2(160,0) + route[i] * (720.0 / 1086.0)
		var strip: PackedVector2Array = Geometry2D.offset_polyline(route, 5.5, Geometry2D.JOIN_MITER, Geometry2D.END_SQUARE)[0]
		if outline.is_empty():
			outline = strip
		else:
			var merged := Geometry2D.merge_polygons(outline, strip)
			assert(merged.size() == 1, "island routes must remain connected without holes")
			outline = merged[0]
	var coords := PackedStringArray()
	for p in outline:
		coords.append(str(p.x))
		coords.append(str(p.y))
	var text := FileAccess.get_file_as_string(SCENE)
	var pattern := RegEx.new()
	pattern.compile('(?s)(\\[node name="WalkableOutline".*?polygon = )PackedVector2Array\\([^)]*\\)')
	text = pattern.sub(text, '$1PackedVector2Array(' + ', '.join(coords) + ')')
	var file := FileAccess.open(SCENE, FileAccess.WRITE)
	file.store_string(text)
	quit()
