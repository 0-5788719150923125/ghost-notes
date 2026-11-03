extends RefCounted
class_name SheetBend

## SheetBend - A SHEET AS THE BAKE HAS IT BENT ([method Particles.make_soft]; 841899, feedback 0012): the node is posed as a whole by where the sheet is on the whole, and this lays
## the difference over its mesh - each vertex following the few of the sheet's points nearest it as it was built, each normal from its own faces, its creases kept where the mesh
## has them. The mesh is the instance's own from here on, and laid again only as the bend changes. Nothing here decides anything: it draws what a frame says.

## How many of the sheet's points a vertex follows, and how far a bent sheet may stand from its box as the mesh was measured (meters).
const FOLLOWS := 4
const CULL_MARGIN := 0.12

var _mi: MeshInstance3D
var _arrays: Array = []
var _flags := 0
var _material: Material = null
var _mesh := ArrayMesh.new()
var _rest := PackedVector3Array()      # each place a vertex stands, once (the mesh's space)
var _place := PackedInt32Array()       # vertex -> its place
var _facing := PackedInt32Array()      # vertex -> which of the normals it shares
var _facings := 0
var _signs := PackedFloat32Array()     # a triangle -> which way round its normal is, as built
var _near := PackedInt32Array()        # a place -> the points it follows ([constant FOLLOWS] each)
var _weight := PackedFloat32Array()
var _to_mesh := Basis.IDENTITY
var _last := PackedVector3Array()
var _normals0 := PackedVector3Array()  # each vertex's normal as built: what it is, straight


## [param mi]'s mesh made ready to bend by [param points], where [param built] carries the mesh's space to the table's as the sheet was built. Null: not a mesh this can bend.
static func of(mi: MeshInstance3D, built: Transform3D, points: PackedVector3Array) -> SheetBend:
	var mesh := mi.mesh as ArrayMesh
	if mesh == null or mesh.get_surface_count() != 1 or mesh.surface_get_primitive_type(0) != Mesh.PRIMITIVE_TRIANGLES:
		return null
	var arrays := mesh.surface_get_arrays(0)
	if arrays[Mesh.ARRAY_INDEX] != null or arrays[Mesh.ARRAY_NORMAL] == null or points.is_empty():
		return null
	var b := SheetBend.new()
	b._mi = mi
	b._arrays = arrays
	b._normals0 = arrays[Mesh.ARRAY_NORMAL]
	b._material = mesh.surface_get_material(0)
	if arrays[Mesh.ARRAY_CUSTOM0] != null:
		b._flags = Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT
	b._to_mesh = built.basis.inverse()
	b._measure(arrays[Mesh.ARRAY_VERTEX], arrays[Mesh.ARRAY_NORMAL], built, points)
	mi.mesh = b._mesh
	mi.extra_cull_margin = CULL_MARGIN
	b._lay()
	return b


func _measure(verts: PackedVector3Array, normals: PackedVector3Array, built: Transform3D, points: PackedVector3Array) -> void:
	var places := {}
	var facings := {}
	_place.resize(verts.size())
	_facing.resize(verts.size())
	for v in verts.size():
		var key := Vector3i((verts[v] * 20000.0).round())
		if not places.has(key):
			places[key] = _rest.size()
			_rest.append(verts[v])
		_place[v] = int(places[key])
		var fk := [key, Vector3i((normals[v] * 50.0).round())]
		if not facings.has(fk):
			facings[fk] = facings.size()
		_facing[v] = int(facings[fk])
	_facings = facings.size()
	_signs.resize(verts.size() / 3)
	for t in _signs.size():
		var a := verts[t * 3]
		var made := (verts[t * 3 + 1] - a).cross(verts[t * 3 + 2] - a)
		_signs[t] = 1.0 if made.dot(normals[t * 3]) >= 0.0 else -1.0
	# ...each place by the points nearest it as built, the nearer the more
	for u in _rest.size():
		var at := built * _rest[u]
		var ds: Array = []
		for k in points.size():
			ds.append([at.distance_squared_to(points[k]), k])
		ds.sort_custom(func(a: Array, c: Array) -> bool: return float(a[0]) < float(c[0]))
		var total := 0.0
		var count := mini(FOLLOWS, ds.size())
		for k in FOLLOWS:
			var d: Array = ds[mini(k, count - 1)]
			var wt := 1.0 / (float(d[0]) + 1e-7) if k < count else 0.0
			_near.append(int(d[1]))
			_weight.append(wt)
			total += wt
		for k in FOLLOWS:
			_weight[u * FOLLOWS + k] /= total


## Bent by [param off] (each point off its own shape, the table's space as built): null or the same as last, nothing is done.
func apply(off: Variant) -> void:
	var o: PackedVector3Array = off if off is PackedVector3Array else PackedVector3Array()
	if o == _last:
		return
	if o.is_empty():
		_arrays[Mesh.ARRAY_VERTEX] = _vertices_of(_rest)
		_arrays[Mesh.ARRAY_NORMAL] = _normals0
		_lay()
		_last = o
		return
	var now := PackedVector3Array()
	now.resize(_rest.size())
	for u in _rest.size():
		var i := u * FOLLOWS
		now[u] = _rest[u] + _to_mesh * (o[_near[i]] * _weight[i] + o[_near[i + 1]] * _weight[i + 1] + o[_near[i + 2]] * _weight[i + 2] + o[_near[i + 3]] * _weight[i + 3])
	var verts := _vertices_of(now)
	var summed := PackedVector3Array()
	summed.resize(_facings)
	for t in _signs.size():
		var a := verts[t * 3]
		var n := (verts[t * 3 + 1] - a).cross(verts[t * 3 + 2] - a) * _signs[t]
		summed[_facing[t * 3]] += n
		summed[_facing[t * 3 + 1]] += n
		summed[_facing[t * 3 + 2]] += n
	var normals: PackedVector3Array = _arrays[Mesh.ARRAY_NORMAL]
	for v in normals.size():
		var n := summed[_facing[v]]
		if n.length_squared() > 1e-16:
			normals[v] = n.normalized()
	_arrays[Mesh.ARRAY_VERTEX] = verts
	_arrays[Mesh.ARRAY_NORMAL] = normals
	_lay()
	_last = o


func _vertices_of(places: PackedVector3Array) -> PackedVector3Array:
	var out := PackedVector3Array()
	out.resize(_place.size())
	for v in out.size():
		out[v] = places[_place[v]]
	return out


func _lay() -> void:
	_mesh.clear_surfaces()
	_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, _arrays, [], {}, _flags)
	if _material != null:
		_mesh.surface_set_material(0, _material)
