extends RefCounted
class_name StudioScene

## StudioScene - the studio as an agent placing one of its things sees it ([StudioProps], a refine that may place a thing): a report in
## numbers ([method report]) - every thing's box where it stands, the one asked about measured against the others (how far apart,
## how deep in, whether it stands in the viewer's frame) and its relations (the camera's foot on the tripod's head) - and pictures of
## the set as it stands ([method views]): from the viewer's eye, from the side of and above the thing asked about, and through the
## camera's lens. The report says where the show is recorded from - the viewer's eye (the creator's head, and how far the show moves it)
## and the camera's lens (the flip screen's picture) - and where every thing falls through each ([method framed]). Built from the
## note's makes and places ([method StudioSet.build]), never the playing studio's own nodes.

## How big a view is (px), and how far round a thing its side and top views stand back (its size's times).
const VIEW := Vector2i(768, 512)
const BACK := 3.2
## A gap this small (cm) is a touch: what rests on another is told as touching, not apart.
const TOUCH := 0.6


## What [param role] is called in a report, and the things the set stands (a rig key -> its role).
static func _role_of_rig(k: String) -> String:
	return "block" if k.begins_with("block") else k


## The set built from [param makes] and [param places] described for an agent placing [param role]: a text. Builds off the tree; a
## worker's.
static func report(makes: Dictionary, places: Dictionary, role: String) -> String:
	var built := StudioSet.build(1, makes, places)
	var out := describe(built, makes, places, role)
	var root: Node = built.get("root")
	if root != null:
		root.free()
	return out


## [param built] (a set, [method StudioSet.build]) described for an agent placing [param role]. Pure of the tree.
static func describe(built: Dictionary, makes: Dictionary, places: Dictionary, role: String) -> String:
	var rigs: Dictionary = built.get("rigs", {})
	var boxes := {}
	for k in rigs:
		boxes[String(k)] = box_of((rigs[k] as PropRig).node)
	var lines := PackedStringArray()
	var geo: Dictionary = built["geo"]
	lines.append("THE STUDIO, in centimeters: x toward the viewer's right, y up from the floor, z toward the viewer (the camera is at -z). The microphone's capsule (where the sound is heard) is at %s; the side table the worked things rest on is %s up. A box is a thing's outer bounds: one standing in another's opening (a camera inside a ring) shows as passing into it." % [
		_cm3((geo["listener"] as Transform3D).origin), _cm(StudioSet.SHELF)])
	lines.append("")
	lines.append("THE CAMERAS - what the show is recorded through, and what to place things for:")
	lines.append("- THE VIEWER'S EYE records the show: at %s, looking at %s, its lens %d degrees tall and %d wide (16:9). It is the creator's head: it rests there, and the show moves it - leaning up to %s to either side of the microphone, as near as %s to its capsule and up to %s above it, turning to look along the windscreen. What must be seen belongs in its frame from where it rests; what is near the microphone is seen closest." % [
		_cm3(StudioSet.EYE), _cm3(StudioSet.LOOK), roundi(StudioSet.VFOV), roundi(rad_to_deg(2.0 * atan(tan(deg_to_rad(StudioSet.VFOV) * 0.5) * 16.0 / 9.0))),
		_cm(HeadPlan.SIDEWAYS), _cm(HeadPlan.NEAREST), _cm(HeadPlan.HIGHEST)])
	var screen := flip_eye(built)
	if not screen.is_empty():
		lines.append("- THE CAMERA'S LENS is a second camera, its picture on the flip screen the viewer sees: at %s, looking toward %s, %d degrees tall (3:2). Behind the viewer it sees the green screen, and nobody." % [
			_cm3((screen["eye"] as Transform3D).origin), _cm3((screen["eye"] as Transform3D).origin - (screen["eye"] as Transform3D).basis.z), roundi(StudioScreen.FOV)])
	lines.append("")
	lines.append("EVERY THING, its box where it stands (its middle, its size, its foot) and what of it each camera sees (across from -1, the frame's left edge, to 1, its right; up from -1, its bottom, to 1, its top; how much of the frame's height it fills):")
	var eye := Transform3D(Basis.looking_at(StudioSet.LOOK - StudioSet.EYE, Vector3.UP), StudioSet.EYE)
	for k in boxes:
		var b: AABB = boxes[k]
		var r := _role_of_rig(String(k))
		var name := String((makes.get(r, {}) as Dictionary).get("kept", PropMakes.ROLES.get(r, {}).get("label", r)))
		var placed: Dictionary = places.get(r, {})
		var through := "; the viewer's eye: " + framed_text(framed(b, eye, StudioSet.VFOV, 16.0 / 9.0))
		if not screen.is_empty():
			through += "; the lens: " + framed_text(framed(b, screen["eye"], StudioScreen.FOV, 1.5))
		lines.append("- %s (%s%s): middle %s, size %s, foot %s%s%s" % [k.replace("_", " "), name, "" if k == r else ", one of two",
			_cm3(b.get_center()), _cm3(b.size), _cm3(Vector3(b.get_center().x, b.position.y, b.get_center().z)),
			("; moved from where the studio stands it by %s" % JSON.stringify(placed)) if not placed.is_empty() else "", through])
	var mine: Array = boxes.keys().filter(func(k: String) -> bool: return _role_of_rig(k) == role)
	if mine.is_empty():
		lines.append("")
		lines.append("The %s is not in the studio yet." % role.replace("_", " "))
		return "\n".join(lines)
	lines.append("")
	lines.append("THE %s MEASURED AGAINST THE REST (a gap of 0 is touching; \"into\" is how far their boxes pass into each other):" % role.replace("_", " ").to_upper())
	for m in mine:
		var bm: AABB = boxes[m]
		for k in boxes:
			if k == m:
				continue
			var g := gap(bm, boxes[k])
			if g < 40.0:
				lines.append("- %s and %s: %s" % [String(m).replace("_", " "), String(k).replace("_", " "),
					("into each other by %s" % _cm(-g * 0.01)) if g < -TOUCH else ("touching" if g <= TOUCH else "%s apart" % _cm(g * 0.01))])
	for rel in relations(built, role):
		lines.append("- " + String(rel))
	return "\n".join(lines)


## What [param role] stands in relation to, measured in [param built]: the camera's foot against the tripod's head, the windscreen in
## the viewer's frame - a line each.
static func relations(built: Dictionary, role: String) -> Array:
	var rigs: Dictionary = built.get("rigs", {})
	var out: Array = []
	if role in ["camera", "tripod"] and rigs.has("camera") and rigs.has("tripod"):
		var top: Variant = (rigs["tripod"] as PropRig).point_in_thing("top")
		if top is Vector3:
			var head: Vector3 = (rigs["tripod"] as PropRig).node.transform * (top as Vector3)
			var foot := box_of((rigs["camera"] as PropRig).node)
			var under := Vector3(foot.get_center().x, foot.position.y, foot.get_center().z)
			out.append("the camera's foot is %s the tripod's head (%s across)" % [("%s above" % _cm(under.y - head.y)) if under.y > head.y + 0.006
				else (("%s below" % _cm(head.y - under.y)) if under.y < head.y - 0.006 else "on"), _cm(Vector2(under.x - head.x, under.z - head.z).length())])
	if role == "microphone" and rigs.has("microphone"):
		out.append("the windscreen %s in the viewer's frame" % ("is" if in_frame(box_of((rigs["microphone"] as PropRig).node)) else "is not"))
	return out


## The flip screen's camera in [param built]: `{eye}` - at the camera's lens, looking out of the glass along the camera's front (as
## [StudioScreen] places it); {} with no camera.
static func flip_eye(built: Dictionary) -> Dictionary:
	var rigs: Dictionary = built.get("rigs", {})
	if not rigs.has("camera"):
		return {}
	var cam: Node3D = (rigs["camera"] as PropRig).node
	var fwd := cam.transform.basis.z.normalized()
	var at: Vector3 = (built["geo"] as Dictionary)["lens"]
	return {"eye": Transform3D(Basis.looking_at(fwd, cam.transform.basis.y.normalized()), at + fwd * StudioScreen.AHEAD)}


## Where box [param b] falls in a view from [param eye] (looking down its -z), its lens [param vfov] degrees tall and [param aspect]
## times as wide: `{seen, x, y, lo, hi, cut, tall, dist, off}` - `x` and `y` its middle from -1 (the left, the bottom edge) to 1, `lo` and
## `hi` the corners of what of it is in view, `cut` the frame's edges it runs past, `tall` the share of the view's height it fills, `dist`
## meters to its middle, `off` where it lies out of view ("" where it is seen). Pure.
static func framed(b: AABB, eye: Transform3D, vfov: float, aspect: float) -> Dictionary:
	var tv := tan(deg_to_rad(vfov) * 0.5)
	var th := tv * aspect
	var inv := eye.affine_inverse()
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	var ahead := 0
	for i in 8:
		var c := inv * (b.position + Vector3(b.size.x * float(i & 1), b.size.y * float((i >> 1) & 1), b.size.z * float((i >> 2) & 1)))
		if c.z > -0.01:
			continue
		ahead += 1
		var q := Vector2((c.x / -c.z) / th, (c.y / -c.z) / tv)
		lo = Vector2(minf(lo.x, q.x), minf(lo.y, q.y))
		hi = Vector2(maxf(hi.x, q.x), maxf(hi.y, q.y))
	var dist := eye.origin.distance_to(b.get_center())
	if ahead == 0:
		return {"seen": false, "off": "behind it", "dist": dist}
	var seen := hi.x > -1.0 and lo.x < 1.0 and hi.y > -1.0 and lo.y < 1.0
	var off := ""
	if not seen:
		off = "left of the frame" if hi.x <= -1.0 else ("right of the frame" if lo.x >= 1.0 else ("below the frame" if hi.y <= -1.0 else "above the frame"))
	return {"seen": seen, "x": clampf((lo.x + hi.x) * 0.5, -9.0, 9.0), "y": clampf((lo.y + hi.y) * 0.5, -9.0, 9.0),
		"lo": Vector2(clampf(lo.x, -1.0, 1.0), clampf(lo.y, -1.0, 1.0)), "hi": Vector2(clampf(hi.x, -1.0, 1.0), clampf(hi.y, -1.0, 1.0)),
		"cut": _cut_edges(lo, hi),
		"tall": (clampf(hi.y, -1.0, 1.0) - clampf(lo.y, -1.0, 1.0)) * 0.5, "dist": dist, "off": off}


## The frame's edges a thing seen from [param lo] to [param hi] (view units) runs past.
static func _cut_edges(lo: Vector2, hi: Vector2) -> PackedStringArray:
	var out := PackedStringArray()
	if lo.x < -1.0:
		out.append("left")
	if hi.x > 1.0:
		out.append("right")
	if lo.y < -1.0:
		out.append("bottom")
	if hi.y > 1.0:
		out.append("top")
	return out


## A framing ([method framed]) as an agent reads it.
static func framed_text(f: Dictionary) -> String:
	if not bool(f.get("seen", false)):
		return "out of view, %s (%s away)" % [String(f.get("off", "")), _cm(float(f.get("dist", 0.0)))]
	var lo: Vector2 = f["lo"]
	var hi: Vector2 = f["hi"]
	var cut: PackedStringArray = f["cut"]
	return "seen across %.2f to %.2f and up %.2f to %.2f%s, filling %d%% of its height, %s away" % [lo.x, hi.x, lo.y, hi.y,
		(" (cut off at the frame's %s)" % " and ".join(cut)) if not cut.is_empty() else "", roundi(float(f["tall"]) * 100.0), _cm(float(f["dist"]))]


## Node [param n]'s meshes' box in its set (the set's root's space, meters), out of any tree.
static func box_of(n: Node3D) -> AABB:
	var out := AABB()
	var first := true
	for mi in n.find_children("*", "VisualInstance3D", true, false):
		if not (mi is MeshInstance3D or mi is MultiMeshInstance3D):
			continue
		var xf := Transform3D.IDENTITY
		var at: Node = mi
		while at != null and at is Node3D:
			xf = (at as Node3D).transform * xf
			if at == n:
				break
			at = at.get_parent()
		var b := xf * (mi as VisualInstance3D).get_aabb()
		if first:
			out = b
			first = false
		else:
			out = out.merge(b)
	return out


## How far apart boxes [param a] and [param b] are (cm): above 0 the gap between them, below 0 how far they pass into each other.
static func gap(a: AABB, b: AABB) -> float:
	var apart := Vector3(maxf(maxf(a.position.x - b.end.x, b.position.x - a.end.x), 0.0), maxf(maxf(a.position.y - b.end.y, b.position.y - a.end.y), 0.0),
		maxf(maxf(a.position.z - b.end.z, b.position.z - a.end.z), 0.0))
	if apart.length() > 0.0:
		return apart.length() * 100.0
	var into := minf(minf(minf(a.end.x - b.position.x, b.end.x - a.position.x), minf(a.end.y - b.position.y, b.end.y - a.position.y)),
		minf(a.end.z - b.position.z, b.end.z - a.position.z))
	return -into * 100.0


## Whether any of box [param b] stands in the viewer's frame (a 16:9 view from the chair).
static func in_frame(b: AABB) -> bool:
	var view := Basis.looking_at(StudioSet.LOOK - StudioSet.EYE, Vector3.UP)
	var half_v := deg_to_rad(StudioSet.VFOV) * 0.5
	var half_h := atan(tan(half_v) * 16.0 / 9.0)
	for i in 8:
		var c := b.position + Vector3(b.size.x * float(i & 1), b.size.y * float((i >> 1) & 1), b.size.z * float((i >> 2) & 1))
		var local := view.inverse() * (c - StudioSet.EYE)
		if local.z < 0.0 and absf(atan2(local.x, -local.z)) < half_h and absf(atan2(local.y, -local.z)) < half_v:
			return true
	return false


## Pictures of the set built from [param makes] and [param places], [param role] in them, saved in [param dir]: from the viewer's eye,
## from the right of the thing and from above it. Their paths ([] where nothing can be drawn here). Built on a worker, drawn here.
static func views(makes: Dictionary, places: Dictionary, role: String, dir: String) -> Array:
	if not PropStudio.can_see():
		return []
	var box := {}
	var task := WorkerThreadPool.add_task(func() -> void: box["set"] = StudioSet.build(1, makes, places))
	while not WorkerThreadPool.is_task_completed(task):
		await PropStudio.tree().process_frame
	WorkerThreadPool.wait_for_task_completion(task)
	var built: Dictionary = box.get("set", {})
	if built.is_empty():
		return []
	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.size = VIEW
	vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	PropStudio.tree().root.add_child(vp)
	var world := Node3D.new()
	vp.add_child(world)
	world.add_child(built["root"])
	var cam := Camera3D.new()
	cam.environment = StudioLook.environment()
	cam.near = 0.01
	cam.far = 20.0
	world.add_child(cam)
	var label := Label.new()
	label.position = Vector2(10, 6)
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color(1.0, 0.98, 0.92))
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.9))
	label.add_theme_constant_override("outline_size", 6)
	vp.add_child(label)
	var rigs: Dictionary = built["rigs"]
	var focus := AABB(StudioSet.CAPSULE - Vector3(0.2, 0.2, 0.2), Vector3(0.4, 0.4, 0.4))
	for k in rigs:
		if _role_of_rig(String(k)) == role:
			focus = box_of((rigs[k] as PropRig).node)
			break
	var c := focus.get_center()
	var r := maxf(focus.size.length() * 0.5, 0.15)
	var screen := flip_eye(built)
	var shots := [
		["eye", Transform3D(Basis.looking_at(StudioSet.LOOK - StudioSet.EYE, Vector3.UP), StudioSet.EYE), StudioSet.VFOV, "From the viewer's eye"],
		["side", Transform3D(Basis.looking_at(Vector3.LEFT, Vector3.UP), c + Vector3(r * BACK, 0.05, 0.0)), 40.0, "From the right of the %s" % role.replace("_", " ")],
		["above", Transform3D(Basis.looking_at(Vector3.DOWN, Vector3.FORWARD), c + Vector3(0.0, r * BACK, 0.0)), 40.0, "From above the %s" % role.replace("_", " ")],
	]
	if not screen.is_empty():
		shots.append(["lens", screen["eye"], StudioScreen.FOV, "Through the camera's lens: its flip screen's picture"])
	DirAccess.make_dir_recursive_absolute(dir)
	var out: Array = []
	for s in shots:
		cam.transform = s[1]
		cam.fov = float(s[2])
		label.text = String(s[3])
		var img: Image = await PropStudio.render(vp, PropStudio.FRAMES)
		if img != null:
			var path := dir.path_join("scene_%s.png" % String(s[0]))
			img.save_png(path)
			out.append(path)
	vp.queue_free()
	return out


## The studio as it stands for an agent placing [param role]: `{report, views}` - [method report] on a worker and [method views] saved
## in [param dir].
static func look(makes: Dictionary, places: Dictionary, role: String, dir: String) -> Dictionary:
	var box := {}
	var task := WorkerThreadPool.add_task(func() -> void: box["report"] = report(makes, places, role))
	while not WorkerThreadPool.is_task_completed(task):
		await PropStudio.tree().process_frame
	WorkerThreadPool.wait_for_task_completion(task)
	var pics: Array = await views(makes, places, role, dir)
	return {"report": String(box.get("report", "")), "views": pics}


static func _cm(m: float) -> String:
	return "%s cm" % PropStudio.cm(absf(m))


static func _cm3(v: Vector3) -> String:
	return "[%s, %s, %s]" % [str(snappedf(v.x * 100.0, 0.5)), str(snappedf(v.y * 100.0, 0.5)), str(snappedf(v.z * 100.0, 0.5))]
