extends RefCounted
class_name MeshCut

## MeshCut - A PIECE OF A THING CUT: its mesh kept on the near side of each of the piece's cuts, and each cut closed by a
## face of its own - the inside of the thing where the blade went through ([TablePhysics]'s pieces, cut by a blade in
## [Particles]).
##
## The user, 2026-10-29: "put a carrot or mandrake root or whatever on the board, cut it into pieces (Fruit Ninja style,
## which is to say - with real cutting dynamics)". A piece is drawn as the thing it was cut from, so a slice of a carrot
## is a slice of that carrot: its skin where the skin was, its cut faces lighter, as the inside of a root or a candle is.
##
## Each plane is cut in turn (Sutherland-Hodgman, every vertex's normal, uvs and copy data carried along an edge it cuts),
## and what a plane cuts through is closed: the edges it leaves are walked into loops and each loop filled (its outline
## laid flat in the plane and triangulated), so a piece cut again closes its first face as well as its second.

## How near two ends of cut edges must be to be one point (meters), and the most loops a cut closes.
const JOIN := 0.0002
const MOST_LOOPS := 8
## How much lighter than its skin a cut face is.
const INSIDE := 0.3


## [param mesh] - its surfaces placed by [param xf] into the space [param planes] are in - kept where every plane has it
## behind it ([method Plane.distance_to] at most 0), each cut closed: an [ArrayMesh] of its surfaces as they were (each
## the material [param mats] gives at its index), then one of the cut faces, which takes [param inside] - or null when
## nothing of it is left.
static func cut(mesh: Mesh, xf: Transform3D, planes: Array, mats: Array, inside: Material) -> ArrayMesh:
	var nb := xf.basis.inverse().transposed()
	var surfaces: Array = []
	for s in mesh.get_surface_count():
		var a := mesh.surface_get_arrays(s)
		var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var n: PackedVector3Array = a[Mesh.ARRAY_NORMAL] if a[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
		var uv: PackedVector2Array = a[Mesh.ARRAY_TEX_UV] if a[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
		var uv2: PackedVector2Array = a[Mesh.ARRAY_TEX_UV2] if a[Mesh.ARRAY_TEX_UV2] != null else PackedVector2Array()
		var cp: PackedFloat32Array = a[Mesh.ARRAY_CUSTOM0] if a[Mesh.ARRAY_CUSTOM0] is PackedFloat32Array else PackedFloat32Array()
		var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX] if a[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		var tris: Array = []
		var count := idx.size() if not idx.is_empty() else v.size()
		for k in range(0, count - 2, 3):
			var poly: Array = []
			for j in 3:
				var i := idx[k + j] if not idx.is_empty() else k + j
				poly.append(_vert(xf * v[i], (nb * n[i]).normalized() if i < n.size() else Vector3.UP,
					uv[i] if i < uv.size() else Vector2.ZERO, uv2[i] if i < uv2.size() else Vector2.ZERO,
					Color(cp[i * 4], cp[i * 4 + 1], cp[i * 4 + 2], cp[i * 4 + 3]) if cp.size() >= (i + 1) * 4 else Color(0, 0, 0, 0)))
			tris.append(poly)
		surfaces.append({"polys": tris, "custom": not cp.is_empty(), "mat": mats[s] if s < mats.size() else null})
	var faces: Array = []          # the cut faces so far, as polygons
	for pl in planes:
		var plane: Plane = pl
		var edges: Array = []
		for sd in surfaces:
			(sd as Dictionary)["polys"] = _clip_all((sd as Dictionary)["polys"], plane, edges)
		faces = _clip_all(faces, plane, edges)
		faces.append_array(_close(edges, plane))
	var out := ArrayMesh.new()
	for sd in surfaces:
		_add(out, (sd as Dictionary)["polys"], bool((sd as Dictionary)["custom"]), (sd as Dictionary)["mat"])
	_add(out, faces, false, inside)
	return out if out.get_surface_count() > 0 else null


## A cut face's material: [param skin]'s, made [constant INSIDE] lighter and a little less bright in color.
static func inside_of(skin: Material) -> Material:
	if not (skin is ShaderMaterial):
		return skin
	var m := (skin as ShaderMaterial).duplicate() as ShaderMaterial
	var c: Variant = m.get_shader_parameter("color")
	if c is Color:
		var k: Color = c
		m.set_shader_parameter("color", k.lerp(Color(0.96, 0.92, 0.82), INSIDE).lerp(Color(k.get_luminance(), k.get_luminance(), k.get_luminance()), 0.15))
	return m


static func _vert(p: Vector3, n: Vector3, uv: Vector2, uv2: Vector2, c: Color) -> Array:
	return [p, n, uv, uv2, c]


static func _lerp(a: Array, b: Array, t: float) -> Array:
	return [(a[0] as Vector3).lerp(b[0], t), ((a[1] as Vector3).lerp(b[1], t)).normalized(), (a[2] as Vector2).lerp(b[2], t),
		(a[3] as Vector2).lerp(b[3], t), (a[4] as Color).lerp(b[4], t)]


## Every polygon of [param polys] kept behind [param plane], the edges it cuts along added to [param edges].
static func _clip_all(polys: Array, plane: Plane, edges: Array) -> Array:
	var out: Array = []
	for p in polys:
		var poly: Array = p
		var kept: Array = []
		var cuts: Array = []
		for i in poly.size():
			var a: Array = poly[i]
			var b: Array = poly[(i + 1) % poly.size()]
			var da := plane.distance_to(a[0])
			var db := plane.distance_to(b[0])
			if da <= 0.0:
				kept.append(a)
			if (da <= 0.0) != (db <= 0.0):
				var x := _lerp(a, b, da / (da - db))
				kept.append(x)
				cuts.append(x[0])
		if kept.size() >= 3:
			out.append(kept)
		if cuts.size() == 2 and (cuts[0] as Vector3).distance_to(cuts[1]) > 1e-7:
			edges.append([cuts[0], cuts[1]])
	return out


## THE FACE OVER A CUT: [param edges] walked into loops, each laid flat in [param plane] and filled - facing out of the
## piece, along the plane's normal.
static func _close(edges: Array, plane: Plane) -> Array:
	var faces: Array = []
	var n := plane.normal
	var u := n.cross(Vector3.UP if absf(n.y) < 0.9 else Vector3.RIGHT).normalized()
	var w := n.cross(u)
	var left := edges.duplicate()
	var loops := 0
	while not left.is_empty() and loops < MOST_LOOPS:
		var first: Array = left.pop_back()
		var loop: Array = [first[0], first[1]]
		var grew := true
		while grew:
			grew = false
			var end: Vector3 = loop[loop.size() - 1]
			for k in left.size():
				var e: Array = left[k]
				var other: Variant = null
				if (e[0] as Vector3).distance_to(end) < JOIN:
					other = e[1]
				elif (e[1] as Vector3).distance_to(end) < JOIN:
					other = e[0]
				if other != null:
					left.remove_at(k)
					if (other as Vector3).distance_to(loop[0]) >= JOIN:
						loop.append(other)
						grew = true
					break
		loops += 1
		if loop.size() < 3:
			continue
		var flat := PackedVector2Array()
		for p in loop:
			flat.append(Vector2((p as Vector3).dot(u), (p as Vector3).dot(w)))
		var tri := Geometry2D.triangulate_polygon(flat)
		if tri.is_empty():
			# a loop that crosses itself (a cut through a crease): filled from its middle
			var mid := Vector3.ZERO
			for p in loop:
				mid += p
			mid /= float(loop.size())
			for k in loop.size():
				faces.append(_face([mid, loop[k], loop[(k + 1) % loop.size()]], n, u, w))
			continue
		for k in range(0, tri.size(), 3):
			faces.append(_face([loop[tri[k]], loop[tri[k + 1]], loop[tri[k + 2]]], n, u, w))
	return faces


## A triangle of a cut face, wound to face [param n] as Props winds its own ([method Props.Tris.tri]).
static func _face(p: Array, n: Vector3, u: Vector3, w: Vector3) -> Array:
	if ((p[1] as Vector3) - (p[0] as Vector3)).cross((p[2] as Vector3) - (p[0] as Vector3)).dot(n) > 0.0:
		p = [p[0], p[2], p[1]]
	var out: Array = []
	for q in p:
		var v: Vector3 = q
		out.append(_vert(v, n, Vector2(v.dot(u), v.dot(w)) * 20.0, Vector2.ZERO, Color(0, 0, 0, 0)))
	return out


## [param polys] (fanned into triangles) added to [param m] as a surface of material [param mat].
static func _add(m: ArrayMesh, polys: Array, custom: bool, mat: Material) -> void:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	var cp := PackedFloat32Array()
	for p in polys:
		var poly: Array = p
		for k in range(1, poly.size() - 1):
			for q in [poly[0], poly[k], poly[k + 1]]:
				v.append(q[0])
				n.append(q[1])
				uv.append(q[2])
				uv2.append(q[3])
				var c: Color = q[4]
				cp.append_array([c.r, c.g, c.b, c.a])
	if v.is_empty():
		return
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = v
	arrays[Mesh.ARRAY_NORMAL] = n
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_TEX_UV2] = uv2
	var flags := 0
	if custom:
		arrays[Mesh.ARRAY_CUSTOM0] = cp
		flags = Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, flags)
	if mat != null:
		m.surface_set_material(m.get_surface_count() - 1, mat)
