extends RefCounted
class_name ShotReach

## ShotReach - what a thing out of the shot still gives the picture: a flame's light, a shadow a light throws of it onto the table in
## the frame, or steam or smoke it puffs up into view. A thing out of the shot that gives none of these and that the work never takes
## up is there for nobody: the set dresser is asked about it ([SetDresserTools]), and the table played hides it ([method
## TableMedium.hide_idle]). Pure geometry over the camera, the lights and the thing's bounds; it touches no tree.

## Less of a thing in the shot than this share of it, and it is out of it.
const OUT := 0.05
## The frame's shape, width over height, as the table judges what is in the shot: the dressed frame ([constant CardTable.DRESSED]),
## whatever frame it is shown in.
const ASPECT := CardTable.DRESSED
## How far a corner of the frame above the horizon reaches across the table (meters), and how high a thing's steam is followed.
const FAR := 4.0
const STEAM_UP := 0.3


## What thing [param t] (as written) still gives the picture from out of the shot: "light" ([param lit], a flame of its own), "a
## shadow" (a light that casts one throws its shadow onto the table in the frame) and "rising steam" or "rising smoke" (a part that
## `emits` puffs up into the frame). Its bounds are [param box] placed by [param at] (the table's space; identity for bounds measured
## there already), standing on the table at their foot; [param root] holds the table's lights; the camera is at [param cam] with a
## vertical [param fov] in degrees.
static func gives(t: Dictionary, at: Transform3D, box: AABB, lit: bool, root: Node, cam: Transform3D, fov: float) -> Array:
	var out: Array = []
	if lit:
		out.append("light")
	var corners: Array = []
	var inside := AABB(at * box.position, Vector3.ZERO)
	for i in 8:
		var c := at * box.get_endpoint(i)
		corners.append(c)
		inside = inside.expand(c)
	var top := inside.position.y
	var frame := frame_on_table(cam, fov, top)
	if root != null:
		for n in root.find_children("*", "Light3D", true, false):
			var light := n as Light3D
			# (a table built again still holds the last one's lights until the frame ends)
			if light == null or light.is_queued_for_deletion() or not light.shadow_enabled or not light.visible or light.light_energy <= 0.0:
				continue
			var lt := _in(light, root)
			# a light within the thing is its own, which lights it rather than casting it
			if not (light is DirectionalLight3D) and inside.grow(0.02).has_point(lt.origin):
				continue
			if shadow_in_frame(corners, top, light, lt, frame):
				out.append("a shadow")
				break
	var emits := emits_of(t.get("parts", []))
	if not emits.is_empty():
		var c := inside.get_center()
		for k in range(1, 7):
			if seen_at(cam, fov, Vector3(c.x, inside.end.y + STEAM_UP * float(k) / 6.0, c.z)):
				out.append("rising " + emits)
				break
	return out


## What the frame of the camera at [param cam] (vertical [param fov] degrees, the stage's shape) takes in of the table's level at
## height [param top]: its four corners there, in the table's x and z, a corner above the horizon reaching [constant FAR] out.
static func frame_on_table(cam: Transform3D, fov: float, top: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	var tn := tan(deg_to_rad(fov) * 0.5)
	for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		var dir := cam.basis * Vector3(corner.x * tn * ASPECT, corner.y * tn, -1.0)
		var p: Vector3
		if dir.y < -1e-4:
			p = cam.origin + dir * minf((top - cam.origin.y) / dir.y, FAR / dir.length())
		else:
			p = cam.origin + Vector3(dir.x, 0.0, dir.z).normalized() * FAR
		out.append(Vector2(p.x, p.z))
	return out


## Whether the shadow light [param light] (standing at [param lt]) throws of the box with [param corners] onto the table's level at
## [param top] falls in [param frame] ([method frame_on_table]). A point or spot light beyond its reach, or a spot turned away,
## throws none here.
static func shadow_in_frame(corners: Array, top: float, light: Light3D, lt: Transform3D, frame: PackedVector2Array) -> bool:
	var pts := PackedVector2Array()
	if light is DirectionalLight3D:
		var d := -lt.basis.z
		if d.y > -0.02:
			return false
		for c in corners:
			var v: Vector3 = c
			var q := v + d * ((v.y - top) / -d.y)
			pts.append(Vector2(q.x, q.z))
	else:
		var l := lt.origin
		if l.y <= top:
			return false
		var mid := Vector3.ZERO
		for c in corners:
			mid += c as Vector3
		mid /= float(corners.size())
		var reach := (light as OmniLight3D).omni_range if light is OmniLight3D else ((light as SpotLight3D).spot_range if light is SpotLight3D else 0.0)
		if l.distance_to(mid) > reach:
			return false
		if light is SpotLight3D and rad_to_deg((-lt.basis.z).angle_to(mid - l)) > (light as SpotLight3D).spot_angle:
			return false
		for c in corners:
			var v: Vector3 = c
			if v.y >= l.y - 0.001:
				pts.append(Vector2(v.x, v.z) + Vector2(v.x - l.x, v.z - l.z).normalized() * FAR)
			else:
				var q := l + (v - l) * ((l.y - top) / (l.y - v.y))
				pts.append(Vector2(q.x, q.z))
	var hull := Geometry2D.convex_hull(pts)
	return hull.size() >= 3 and not Geometry2D.intersect_polygons(hull, frame).is_empty()


## Whether the point [param p] (the table's space) is in the frame of the camera at [param cam] (vertical [param fov] degrees).
static func seen_at(cam: Transform3D, fov: float, p: Vector3) -> bool:
	var q := cam.affine_inverse() * p
	if q.z >= -0.001:
		return false
	var tn := tan(deg_to_rad(fov) * 0.5)
	return absf(q.x / (-q.z * tn * ASPECT)) <= 1.0 and absf(q.y / (-q.z * tn)) <= 1.0


## How much of a thing whose frame rect is [param rect] (the frame is 0-1 each way) is in the shot.
static func shown(rect: Rect2) -> float:
	return rect.intersection(Rect2(0.0, 0.0, 1.0, 1.0)).get_area() / maxf(rect.get_area(), 1e-9)


## What the parts [param parts] give off ("steam", "smoke"...: the first `emits` kind among them, groups looked into), "" for none.
static func emits_of(parts: Variant) -> String:
	if not (parts is Array):
		return ""
	for p in parts:
		if not (p is Dictionary):
			continue
		if (p as Dictionary).get("emits") is Dictionary:
			return String(((p as Dictionary)["emits"] as Dictionary).get("kind", "steam"))
		var inner := emits_of((p as Dictionary).get("parts"))
		if not inner.is_empty():
			return inner
	return ""


## Whether thing [param name] is taken up by the acts [param acts] (`acts.json` as written): named anywhere in them, whole or as
## "name/part".
static func named_in(acts: Variant, name: String) -> bool:
	var want := name.strip_edges().to_lower()
	if want.is_empty():
		return false
	var stack: Array = [acts]
	while not stack.is_empty():
		var v: Variant = stack.pop_back()
		if v is String:
			var s := (v as String).strip_edges().to_lower()
			if s == want or s.begins_with(want + "/") or s.begins_with(want + "."):
				return true
		elif v is Array:
			stack.append_array(v as Array)
		elif v is Dictionary:
			stack.append_array((v as Dictionary).values())
	return false


## Node [param n]'s place in [param root]'s space, walked up its parents (it may be out of the tree).
static func _in(n: Node3D, root: Node) -> Transform3D:
	var out := n.transform
	var p := n.get_parent()
	while p != null and p != root:
		if p is Node3D:
			out = (p as Node3D).transform * out
		p = p.get_parent()
	return out
