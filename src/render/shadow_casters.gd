extends RefCounted
class_name ShadowCasters

## ShadowCasters - what casts a candle's shadow, cut fine enough to be drawn in a paraboloid.
##
## A candle's shadow is drawn as two paraboloids ([method TableLight.candle_shadow]); Godot's other way, a cube copied
## into them, reads the cube's depth through a linear sampler (copy_effects.cpp `copy_cubemap_to_dp`), averaging a
## thin thing's depth with what is far behind it at every edge. A paraboloid is drawn straight but bends straight
## lines: a triangle's corners are projected and what is between them is not, so a big triangle's depth is drawn wrong
## (a 40 cm plate casts nothing; table_shadow_check). Cut so that no edge is longer than [constant MOST], what is
## between the corners is near enough to where they are.
##
## [method cut] makes a mesh's triangles into a grid of smaller ones, its points alone (all a shadow pass reads);
## neighbours may cut a shared edge into different numbers of pieces, each too short for the difference to reach a
## texel. [method cut_under] gives every caster under a node that needs it a twin that casts its shadow in its place.

## The longest edge a caster keeps (meters): a centimeter and a half subtends a twentieth of a radian from a flame 30 cm off, and drawn
## straight in a paraboloid strays a third of a texel.
const MOST := 0.015
## The most pieces an edge is cut into (a table's top a meter and a half across stays some tens of thousands of triangles).
const MOST_CUTS := 96


## Every mesh that casts a shadow under [param root] and has an edge longer than [param most] is cast by a twin cut
## fine ([method cut]): a MeshInstance3D casting nothing itself any more, beside it one that only casts, with the same
## place, layers and material (a vertex shader that moves it moves its shadow); each mesh is cut once, whoever shares
## it. Only what a shadow pass reads (its points) is cut, so the picture is drawn as it was.
static func cut_under(root: Node, most := MOST) -> void:
	if root == null:
		return
	var done := {}
	for n in root.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		# (one whose mesh is given a new shape as the show plays - a sheet turning or bending - says so with `shadow_own`, and casts itself)
		if mi.mesh == null or mi.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF or mi.has_meta("shadow_twin") or mi.has_meta("shadow_of") \
				or mi.has_meta("shadow_own"):
			continue
		var key := mi.mesh.get_instance_id()
		if not done.has(key):
			done[key] = cut(mi.mesh, most)
		var cut_mesh: Mesh = done[key]
		if cut_mesh == mi.mesh:
			continue
		# (one that only casts - a foot's shadow slab - is cut itself: given no shadow of its own it would be drawn)
		if mi.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY:
			mi.mesh = cut_mesh
			continue
		var twin := MeshInstance3D.new()
		twin.name = "ShadowTwin"
		twin.mesh = cut_mesh
		twin.material_override = mi.material_override if mi.material_override != null else mi.mesh.surface_get_material(0)
		twin.layers = mi.layers
		twin.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		twin.set_meta("shadow_of", true)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.set_meta("shadow_twin", true)
		mi.add_child(twin)


## [param mesh]'s shape with no triangle edge longer than [param most] (meters), as a shadow pass reads it: its points
## alone, indexed, each triangle a grid of as many pieces a side as its longest edge asks ([constant MOST_CUTS] at
## most); [param mesh] itself where it has no such edge.
static func cut(mesh: Mesh, most := MOST) -> Mesh:
	if mesh == null:
		return mesh
	var f := mesh.get_faces()
	var m2 := most * most
	var longer := false
	for i in range(0, f.size() - 2, 3):
		if f[i].distance_squared_to(f[i + 1]) > m2 or f[i + 1].distance_squared_to(f[i + 2]) > m2 or f[i + 2].distance_squared_to(f[i]) > m2:
			longer = true
			break
	if not longer:
		return mesh
	var pts := PackedVector3Array()
	var idx := PackedInt32Array()
	for t in range(0, f.size() - 2, 3):
		var p0 := f[t]
		var p1 := f[t + 1]
		var p2 := f[t + 2]
		var n := clampi(ceili(sqrt(maxf(maxf(p0.distance_squared_to(p1), p1.distance_squared_to(p2)), p2.distance_squared_to(p0))) / most), 1, MOST_CUTS)
		if n == 1:
			var b := pts.size()
			pts.append(p0)
			pts.append(p1)
			pts.append(p2)
			idx.append_array(PackedInt32Array([b, b + 1, b + 2]))
			continue
		# the grid's points, row r (toward p1) by column c (toward p2), and its triangles the same way round as the triangle
		var base := pts.size()
		var d1 := (p1 - p0) / float(n)
		var d2 := (p2 - p0) / float(n)
		var row_at := PackedInt32Array()
		row_at.resize(n + 2)
		var k := 0
		for r in n + 1:
			row_at[r] = k
			for c in n + 1 - r:
				pts.append(p0 + d1 * float(r) + d2 * float(c))
				k += 1
		for r in n:
			for c in n - r:
				var a := base + row_at[r] + c
				var below := base + row_at[r + 1] + c
				idx.append(a)
				idx.append(below)
				idx.append(a + 1)
				if c < n - r - 1:
					idx.append(below)
					idx.append(below + 1)
					idx.append(a + 1)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = pts
	arrays[Mesh.ARRAY_INDEX] = idx
	var out := ArrayMesh.new()
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return out
