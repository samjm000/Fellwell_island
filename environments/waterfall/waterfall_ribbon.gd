@tool
class_name WaterfallRibbon
extends Node2D
## Builds the curtain mesh from the FlowPath child (a Path2D you can drag in the
## editor). UV.x runs across the water (0..1 is the water itself, the margin is
## room for ragged edges and wet rock); UV.y runs down the drop (0 brink, 1 pool).
## Every MeshInstance2D child receives the same mesh (curtain + wet rock).

@export var top_width: float = 455.0:
	set(v): top_width = v; _queue_rebuild()
@export var bottom_width: float = 582.0:
	set(v): bottom_width = v; _queue_rebuild()
## Gentle static wobble of the outline, as a fraction of width.
@export_range(0.0, 0.1) var wobble: float = 0.03:
	set(v): wobble = v; _queue_rebuild()
## Mesh extends this far past each edge of the water (in u).
@export_range(0.0, 0.5) var u_margin: float = 0.25:
	set(v): u_margin = v; _queue_rebuild()
@export_range(8, 128) var segments: int = 56:
	set(v): segments = v; _queue_rebuild()
@export_range(2, 24) var columns: int = 10:
	set(v): columns = v; _queue_rebuild()

const S_MIN := -0.03   # a little above the brink, for the rounded crest
const S_MAX := 1.04    # a little into the pool

var _pending := false

func _ready() -> void:
	var path := _path()
	if path and not path.curve.changed.is_connected(_queue_rebuild):
		path.curve.changed.connect(_queue_rebuild)
	rebuild()

func _queue_rebuild() -> void:
	if _pending or not is_inside_tree():
		return
	_pending = true
	(func(): _pending = false; rebuild()).call_deferred()

func _path() -> Path2D:
	return get_node_or_null("FlowPath") as Path2D

## Point along the flow at s (extrapolates straight beyond the ends).
func point_at(s: float) -> Vector2:
	var path := _path()
	var curve := path.curve
	var length := curve.get_baked_length()
	if s < 0.0:
		var t := (curve.sample_baked(4.0) - curve.sample_baked(0.0)).normalized()
		return path.position + curve.sample_baked(0.0) + t * s * length
	if s > 1.0:
		var t2 := (curve.sample_baked(length) - curve.sample_baked(length - 4.0)).normalized()
		return path.position + curve.sample_baked(length) + t2 * (s - 1.0) * length
	return path.position + curve.sample_baked(s * length)

func width_at(s: float) -> float:
	var sc := clampf(s, 0.0, 1.0)
	var w := lerpf(top_width, bottom_width, sc)
	return w * (1.0 + wobble * sin(sc * 11.0 + 1.3))

func rebuild() -> void:
	var path := _path()
	if path == null or path.curve == null or path.curve.point_count < 2:
		return
	var verts := PackedVector2Array()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	for i in range(segments + 1):
		var s := lerpf(S_MIN, S_MAX, float(i) / segments)
		var p := point_at(s)
		var ahead := point_at(s + 0.01)
		var tangent := (ahead - p).normalized()
		var right := Vector2(-tangent.y, tangent.x) * -1.0   # +u to screen right
		var w := width_at(s)
		for j in range(columns + 1):
			var u := lerpf(-u_margin, 1.0 + u_margin, float(j) / columns)
			verts.append(p + right * (u - 0.5) * w)
			uvs.append(Vector2(u, s))
	var row := columns + 1
	for i in range(segments):
		for j in range(columns):
			var a := i * row + j
			idx.append_array([a, a + 1, a + row, a + 1, a + row + 1, a + row])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	for child in get_children():
		if child is MeshInstance2D:
			child.mesh = mesh
