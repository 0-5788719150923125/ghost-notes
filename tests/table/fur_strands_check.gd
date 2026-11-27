extends SceneTree

## A part's fur as strands ([FurStrands], [method Props._fur], [method PropRig.touch]; next/studio.md "Fur (props)"), with no renderer.
##
##   godot --headless --path . --script res://tests/table/fur_strands_check.gd
##
## - How many strands a part wears is its area times its density squared, never more than [constant FurStrands.MOST] (a
##   head-sized windscreen at ten a centimeter is capped), none on no area.
## - The roots are a seeded draw: the same mesh and seed give the same roots, float for float (an export plays what the live show
##   did); the control, another seed, gives others.
## - Each root lies on the mesh, its normal the skin's there (on a ball: as far out as its facets, pointing out).
## - They are strewn by area, evenly: over a fan of triangles of very different sizes every cell of a grid gets its share. The
##   control: the same count shared out a triangle each, as a draw blind to area would, leaves the measure failing.
## - What is made is kept: the same mesh and fur hand back the same texture and strip, two texels a strand, a strip of
##   [method FurStrands.per_strand] vertices a strand whose box holds the part grown by the fur's reach.
## - Built on a prop, a furred part keeps its own material as the undercoat (no pass chained after it) and wears its strands as a
##   one-instance MultiMesh, out of every MeshInstance3D scan, casting no shadow, parting at the part's top. Its rig is furred and a
##   touch reaches the strands' material; a rig's copy is pressed on its own (the control: the original keeps its touch). A thing
##   with no fur has a rig that is not furred.

var _fails := 0


func _init() -> void:
	_run.call_deferred()


func _ok(cond: bool, what: String) -> void:
	if not cond:
		_fails += 1
		print("  FAIL: " + what)


## A ball's triangles, every three points one: [vertices, normals].
func _ball(r: float) -> Array:
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	sm.radial_segments = 32
	sm.rings = 16
	var arr := sm.get_mesh_arrays()
	var iv: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var inn: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	for i in (arr[Mesh.ARRAY_INDEX] as PackedInt32Array):
		v.append(iv[i])
		n.append(inn[i])
	return [v, n]


## A unit square in the xz plane as a fan of triangles from its corner, of very different sizes: [vertices, normals].
func _fan() -> Array:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var edge := [Vector3(1, 0, 0), Vector3(1, 0, 0.05), Vector3(1, 0, 0.2), Vector3(1, 0, 1), Vector3(0.9, 0, 1), Vector3(0.6, 0, 1),
		Vector3(0, 0, 1)]
	for i in edge.size() - 1:
		v.append_array([Vector3.ZERO, edge[i], edge[i + 1]])
		n.append_array([Vector3.UP, Vector3.UP, Vector3.UP])
	return [v, n]


## How unevenly roots [param r] (eight floats each) cover the unit square in xz: the worst cell of an 8 x 8 grid, as a share off
## the mean.
func _uneven(r: PackedFloat32Array) -> float:
	var cells := PackedInt32Array()
	cells.resize(64)
	var count := r.size() / 8
	for i in count:
		var cx := clampi(int(r[i * 8] * 8.0), 0, 7)
		var cz := clampi(int(r[i * 8 + 2] * 8.0), 0, 7)
		cells[cz * 8 + cx] += 1
	var mean := float(count) / 64.0
	var worst := 0.0
	for c in cells:
		worst = maxf(worst, absf(float(c) - mean) / mean)
	return worst


func _run() -> void:
	# --- how many
	_ok(FurStrands.count_for(1e6, 40.0) == FurStrands.MOST, "a huge part is capped at the most strands")
	_ok(FurStrands.count_for(0.0, 10.0) == 0 and FurStrands.count_for(-1.0, 10.0) == 0, "no area wears no strands")
	_ok(FurStrands.count_for(0.01, 10.0) == 10000, "100 cm2 at ten a centimeter is ten thousand: %d" % FurStrands.count_for(0.01, 10.0))
	var ball := _ball(0.087)
	var bv: PackedVector3Array = ball[0]
	var bn: PackedVector3Array = ball[1]
	_ok(FurStrands.count_for(FurStrands.area_of(bv), 10.0) == FurStrands.MOST, "a head-sized windscreen at ten a centimeter is capped")

	# --- a seeded draw, on the mesh
	var r1 := FurStrands.roots(bv, bn, 6000, 11)
	var r2 := FurStrands.roots(bv, bn, 6000, 11)
	var r3 := FurStrands.roots(bv, bn, 6000, 12)
	_ok(r1.size() == 6000 * 8 and r1 == r2, "the same mesh and seed give the same roots")
	_ok(r1 != r3, "the control: another seed gives other roots")
	var inner := 0.087 * cos(PI / 16.0) * cos(PI / 32.0) - 1e-4
	var on := true
	var out := true
	for i in 6000:
		var p := Vector3(r1[i * 8], r1[i * 8 + 1], r1[i * 8 + 2])
		var q := Vector3(r1[i * 8 + 4], r1[i * 8 + 5], r1[i * 8 + 6])
		on = on and p.length() <= 0.087 + 1e-4 and p.length() >= inner
		out = out and absf(q.length() - 1.0) < 1e-3 and q.dot(p.normalized()) > 0.97
		out = out and r1[i * 8 + 3] >= 0.0 and r1[i * 8 + 3] < 1.0 and r1[i * 8 + 7] >= 0.0 and r1[i * 8 + 7] < 1.0
	_ok(on, "every root lies on the ball's facets")
	_ok(out, "each root's normal is the skin's there, pointing out, and its numbers are 0..1")

	# --- by area, evenly
	var fan := _fan()
	var fv: PackedVector3Array = fan[0]
	var fn: PackedVector3Array = fan[1]
	var even := _uneven(FurStrands.roots(fv, fn, 12800, 3))
	_ok(even < 0.2, "strewn by area, every cell gets its share (worst %.0f%% off)" % (even * 100.0))
	var blind := PackedFloat32Array()
	var tris := fv.size() / 3
	for t in tris:
		var one := FurStrands.roots(fv.slice(t * 3, t * 3 + 3), fn.slice(t * 3, t * 3 + 3), 12800 / tris, 3 + t)
		blind.append_array(one)
	var blind_off := _uneven(blind)
	_ok(blind_off > 0.5, "the control: a triangle's even share each leaves cells far off (worst %.0f%% off)" % (blind_off * 100.0))

	# --- kept
	var f := {"length": 3.0, "density": 10.0}
	var made := FurStrands.made(bv, bn, f)
	var again := FurStrands.made(bv, bn, f)
	var count := int(made.get("count", 0))
	_ok(count == FurStrands.MOST and made.get("texture") == again.get("texture") and made.get("mesh") == again.get("mesh"),
		"the same mesh and fur hand back what was made")
	var tex: Texture2D = made.get("texture")
	_ok(tex != null and tex.get_width() == FurStrands.ROW * 2 and tex.get_height() == ceili(float(count) / FurStrands.ROW),
		"two texels a strand, %d strands a row" % FurStrands.ROW)
	var strip: ArrayMesh = made.get("mesh")
	var want := AABB(bv[0], Vector3.ZERO)
	for p in bv:
		want = want.expand(p)
	want = want.grow(0.03 * FurStrands.REACH)
	_ok(strip != null and strip.surface_get_primitive_type(0) == Mesh.PRIMITIVE_TRIANGLE_STRIP
		and strip.surface_get_array_len(0) == count * FurStrands.per_strand(),
		"a strip of %d vertices a strand" % FurStrands.per_strand())
	_ok(strip != null and strip.get_aabb().grow(1e-4).encloses(want), "its box holds the part grown by the fur's reach: %s" % str(strip.get_aabb() if strip else null))
	_ok(float(made.get("width", 0.0)) > 0.0 and float(made.get("width", 1.0)) < 0.001, "a strand is finer than a millimeter at its root")
	_ok(FurStrands.made(PackedVector3Array(), PackedVector3Array(), f).is_empty(), "no mesh, no fur")

	# --- on a prop
	var spec := {"things": [{"name": "a windscreen", "parts": [
		{"shape": "lathe", "profile": [[0, 0], [1.3, 0], [1.3, 6], [0, 6]], "material": "body"},
		{"shape": "ball", "name": "screen", "size": [17, 18.6, 17], "at": [0, 15, 0], "material": "fluff",
			"fur": {"length": 3.0, "density": 10.0, "curl": 0.55, "droop": 0.55, "color": "#5a5048", "tip": "#e6ded2"}}]}],
		"materials": {"body": {"kind": "metal", "color": "#303030"}, "fluff": {"kind": "fabric", "color": "#3a322b"}}}
	var safe := Props.sanitize(spec, [])
	var b := Props.build((safe["things"] as Array)[0], safe["materials"], 5)
	var node: Node3D = b["node"]
	var furs := node.find_children("*", "MultiMeshInstance3D", true, false)
	_ok(furs.size() == 1 and (furs[0] as Node).has_meta("fur"), "a furred part wears one MultiMesh of strands")
	var hair := furs[0] as MultiMeshInstance3D if furs.size() == 1 else null
	var skin := hair.get_parent() as MeshInstance3D if hair != null else null
	_ok(skin != null and skin.material_override != null and skin.material_override.next_pass == null,
		"its part keeps its own material as the undercoat, nothing chained after it")
	var in_scan := false
	for mi in node.find_children("*", "MeshInstance3D", true, false):
		in_scan = in_scan or (mi as Node).has_meta("fur") or ((mi as MeshInstance3D).mesh != null and (mi as MeshInstance3D).mesh.surface_get_primitive_type(0) != Mesh.PRIMITIVE_TRIANGLES)
	_ok(not in_scan, "no MeshInstance3D scan meets the strip")
	var sm := hair.material_override as ShaderMaterial if hair != null else null
	_ok(hair != null and hair.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF and hair.multimesh.instance_count == 1,
		"one instance, casting no shadow")
	var crown: Variant = sm.get_shader_parameter("crown") if sm != null else null
	var sbox := skin.mesh.get_aabb() if skin != null else AABB()
	_ok(crown is Vector3 and absf((crown as Vector3).y - sbox.end.y) < 1e-4 and absf((crown as Vector3).x - sbox.get_center().x) < 1e-4,
		"it parts at the part's top, middle of its width: %s" % str(crown))
	_ok(sm != null and sm.get_shader_parameter("roots") is Texture2D and int(sm.get_shader_parameter("segments")) == FurStrands.SEGMENTS,
		"the strands' material is handed its roots and segments")
	var rig := PropRig.new(b)
	_ok(rig.furred(), "its rig is furred")
	var dup := rig.copy()
	rig.touch(0, Vector3(0.1, 0.15, 0.0), 0.01, Vector3(0, 0, 0.02))
	_ok(sm != null and _first(sm, "touches") == Vector4(0.1, 0.15, 0.0, 0.01) and _first(sm, "pushes") == Vector3(0, 0, 0.02)
		and int(sm.get_shader_parameter("touch_n")) == 1, "a touch reaches the strands")
	rig.touch_all([{"at": Vector3(0.1, 0.15, 0.0), "depth": 0.01}, {"at": Vector3(0.12, 0.15, 0.0), "depth": 0.008}, {"at": Vector3.ZERO, "depth": 0.0}])
	_ok(int(sm.get_shader_parameter("touch_n")) == 2, "fingertips press it together, one that does not press left out")
	rig.touch(0, Vector3(0.1, 0.15, 0.0), 0.01, Vector3(0, 0, 0.02))
	var dup_furs := dup.node.find_children("*", "MultiMeshInstance3D", true, false)
	var dup_sm := (dup_furs[0] as GeometryInstance3D).material_override as ShaderMaterial if dup_furs.size() == 1 else null
	dup.touch(0, Vector3(-0.1, 0.1, 0.0), 0.02)
	_ok(dup_sm != null and dup_sm != sm and _first(dup_sm, "touches") == Vector4(-0.1, 0.1, 0.0, 0.02),
		"a copy is pressed on its own")
	_ok(sm != null and _first(sm, "touches") == Vector4(0.1, 0.15, 0.0, 0.01), "the control: the original keeps its touch")
	var bare := Props.sanitize({"things": [{"name": "a ball", "parts": [{"shape": "ball", "size": [5, 5, 5], "material": "body"}]}],
		"materials": spec["materials"]}, [])
	var bb := Props.build((bare["things"] as Array)[0], bare["materials"], 5)
	_ok(not PropRig.new(bb).furred(), "a thing with no fur has a rig that is not furred")
	(bb["node"] as Node).free()
	dup.node.free()
	node.free()

	if _fails == 0:
		print("fur_strands_check: ALL OK")
	else:
		print("fur_strands_check: %d FAILED" % _fails)
	quit(1 if _fails > 0 else 0)


## The first of shader array [param key] on [param sm], null where there is none.
func _first(sm: ShaderMaterial, key: String) -> Variant:
	var v: Variant = sm.get_shader_parameter(key)
	if v is PackedVector4Array and not (v as PackedVector4Array).is_empty():
		return (v as PackedVector4Array)[0]
	if v is PackedVector3Array and not (v as PackedVector3Array).is_empty():
		return (v as PackedVector3Array)[0]
	return null
