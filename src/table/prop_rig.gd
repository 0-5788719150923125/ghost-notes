extends RefCounted
class_name PropRig

## PropRig - a built prop's working parts, played by what its scene feeds it (next/working_props.md). A scene works a prop only through
## this: its faces, lights and jointed or changing parts found by their `name` ([Props], [Motions]), each part's `runs` worked out at a
## moment of the show with the scene's feeds (the `follow` law), its points where they are as it stands - never by the shapes it was
## handed, so any make of a role (its own, one kept, one refined) is worked the same way.
##
## Made off the tree from what [method Props.build] handed back (a worker builds it); [method pose] touches only the prop's own nodes.
## Its lights come on as it is made (a host that makes no rig never shows them). A part a make lacks is no error: asked for, it is
## null, and fed, nothing moves.

## The built thing's node (what a scene places), and the rest of what [method Props.build] handed back.
var node: Node3D
var built: Dictionary
var _works: Array = []           # each {name, node, w, kind, mats, lights}
var _faces := {}                 # a face's name -> its record ([method Props.build]'s `faces`)
var _lights: Array = []          # each {name, node, energy}
var _now := {}                   # "<work index>:<channel>" -> its value as last posed
var _light_scale := 1.0          # how strongly its lights throw their light, over what its parts say ([method set_light_scale])


## The rig of thing [param b], as [method Props.build] (or [method PropMakes.made]) handed it back.
func _init(b: Dictionary) -> void:
	built = b
	node = b.get("node") as Node3D
	_lights = b.get("lights", []) if b.get("lights") is Array else []
	var lit_by := {}
	for wv in (b.get("works", []) if b.get("works") is Array else []):
		var wd: Dictionary = wv
		var wn: Node3D = wd["node"]
		var w: Dictionary = wd["work"]
		var mats: Array = []
		for mi in wn.find_children("*", "MeshInstance3D", true, false):
			var mat := (mi as MeshInstance3D).material_override as ShaderMaterial
			if mat != null:
				mats.append(mat)
		var mine: Array = []
		for l in _lights:
			if wn.is_ancestor_of((l as Dictionary)["node"]):
				mine.append(l)
				lit_by[l] = true
		_works.append({"name": String(w.get("name", "")), "node": wn, "w": w, "kind": String((w.get("joint", {}) as Dictionary).get("kind", "")),
			"mats": mats, "lights": mine})
	for f in (b.get("faces", []) if b.get("faces") is Array else []):
		var nm := String((f as Dictionary).get("name", ""))
		if not nm.is_empty() and not _faces.has(nm):
			_faces[nm] = f
	# as it starts: each part's own state, and every light that answers to no part lit as written
	for wi in _works.size():
		var start: Dictionary = ((_works[wi] as Dictionary)["w"] as Dictionary).get("start", {}) if ((_works[wi] as Dictionary)["w"] as Dictionary).get("start") is Dictionary else {}
		for ch in ["glow", "shown", "light"]:
			if start.has(ch) or (ch == "light" and not ((_works[wi] as Dictionary)["lights"] as Array).is_empty()):
				_apply(wi, ch, float(start.get(ch, 1.0)))
	for l in _lights:
		if not lit_by.has(l):
			((l as Dictionary)["node"] as Light3D).visible = true


## Every part at show time [param T], fed [param feeds] (what the scene hands it, by name: a signal's level, a knob's setting, how
## open a lid is): each part's `runs` worked out in turn, each from what the last made of it, as a table's are.
func pose(T: float, feeds := {}) -> void:
	for wi in _works.size():
		var runs: Array = ((_works[wi] as Dictionary)["w"] as Dictionary).get("runs", [])
		if runs.is_empty():
			continue
		var by := {}
		for law in runs:
			var ch := _channel(wi, law as Dictionary)
			if ch.is_empty():
				continue
			var was := float(by.get(ch, _rest(wi, ch)))
			by[ch] = Motions.scalar(law, was, T, 1.0, T, feeds)
		for ch in by:
			_apply(wi, String(ch), float(by[ch]))


## Every light of this make throwing [param k] of what its parts say (a scene's own tuning of it, the Environment card's): kept
## through every pose after.
func set_light_scale(k: float) -> void:
	_light_scale = maxf(k, 0.0)
	var under := {}
	for wi in _works.size():
		for l in (_works[wi] as Dictionary)["lights"]:
			under[l] = true
		if not ((_works[wi] as Dictionary)["lights"] as Array).is_empty():
			_apply(wi, "light", float(_now.get("%d:light" % wi, _rest(wi, "light"))))
	for l in _lights:
		if not under.has(l):
			var ln: Light3D = (l as Dictionary)["node"]
			ln.light_energy = float((l as Dictionary)["energy"]) * _light_scale
			ln.visible = _light_scale > 0.001


## The names of the faces this make has.
func face_names() -> PackedStringArray:
	return PackedStringArray(_faces.keys())


## Face [param name]'s mesh, its picture's to show; null where this make has none.
func face(name: String) -> MeshInstance3D:
	return (_faces[name] as Dictionary)["node"] if _faces.has(name) else null


## Face [param name] as written ([constant Props.SHAPES] `face`: its size, outline, `lit`, `glass`, words...); {} where it has none.
func face_part(name: String) -> Dictionary:
	return (_faces[name] as Dictionary)["part"] if _faces.has(name) else {}


## Face [param name]'s size as it stands (meters, the thing's own scale counted), Vector2.ZERO where it has none.
func face_size(name: String) -> Vector2:
	if not _faces.has(name):
		return Vector2.ZERO
	var xf := face_xf(name)
	var s: Vector2 = ((_faces[name] as Dictionary)["part"] as Dictionary)["size"]
	return Vector2(s.x * xf.basis.x.length(), s.y * xf.basis.y.length()) * 0.01


## Where face [param name]'s middle is and which way it faces, in the thing's node ([member node]): its x across, y up and z out of
## it, scaled as the thing is. Identity where it has none.
func face_xf(name: String) -> Transform3D:
	if not _faces.has(name):
		return Transform3D.IDENTITY
	var f: Dictionary = _faces[name]
	return _in_node(f["node"]) * (f["xform"] as Transform3D)


## Face [param name] saying [param text] where it has words of its own ([constant Props.SHAPES] `face`'s `text`) - or made to, in its
## hand and ink, where it has none.
func say(name: String, text: String) -> void:
	if not _faces.has(name):
		return
	var f: Dictionary = _faces[name]
	var part: Dictionary = f["part"]
	if not f.has("words"):
		var p := part.duplicate()
		p["text"] = text
		f["words"] = Props.face_words(p, f["xform"])
		(f["node"] as Node).add_child(f["words"])
		return
	Props.fit_words(f["words"], text, (part["size"] as Vector2) * 0.01)


## The working part [param name]'s node (what its joint turns, a whole group's); null where there is none.
func part(name: String) -> Node3D:
	var wi := _named(name)
	return (_works[wi] as Dictionary)["node"] if wi >= 0 else null


## Light [param name]'s node (the part it is at named so); null where there is none.
func light(name: String) -> Light3D:
	for l in _lights:
		if String((l as Dictionary)["name"]) == name:
			return (l as Dictionary)["node"]
	return null


## Every light this make has.
func lights() -> Array:
	return _lights.map(func(l: Dictionary) -> Light3D: return l["node"])


## Part [param name]'s channel [param ch] (`angle`, `offset`, `glow`, `shown`, `light`, `fill`, `grow`) as last posed - or as built.
func value(name: String, ch: String) -> float:
	var wi := _named(name)
	if wi < 0:
		return NAN
	return float(_now.get("%d:%s" % [wi, ch], _rest(wi, ch)))


## Point [param name] of any working part (its `points`), where it is now in the thing's node (meters); null where there is none.
func point(name: String) -> Variant:
	for wk in _works:
		var pts: Dictionary = ((wk as Dictionary)["w"] as Dictionary).get("points", {})
		if pts.has(name):
			var wn: Node3D = (wk as Dictionary)["node"]
			return _in_node(wn) * (pts[name] as Vector3)
	return null


## Whether this make has every face named in [param names].
func has_faces(names: Array) -> bool:
	for n in names:
		if not _faces.has(String(n)):
			return false
	return true


## A rig of its own for a copy of this thing: its node duplicated, every part, face and light found again in the copy by where
## it stands among its parents' children, and every material its own - one make built once for many of it (a row of phones), each
## copy then told its own words, colors and feeds. Touches no tree.
func copy() -> PropRig:
	var dup := node.duplicate() as Node3D
	for mi in dup.find_children("*", "MeshInstance3D", true, false):
		if (mi as MeshInstance3D).material_override != null:
			(mi as MeshInstance3D).material_override = (mi as MeshInstance3D).material_override.duplicate()
	var b := built.duplicate()
	b["node"] = dup
	b["works"] = (built.get("works", []) as Array).map(func(w: Dictionary) -> Dictionary:
		return {"node": _found(dup, w["node"]), "work": w["work"]})
	b["faces"] = (built.get("faces", []) as Array).map(func(f: Dictionary) -> Dictionary:
		var g := f.duplicate()
		g["node"] = _found(dup, f["node"])
		if f.has("words"):
			g["words"] = _found(dup, f["words"])
		return g)
	b["lights"] = (built.get("lights", []) as Array).map(func(l: Dictionary) -> Dictionary:
		var m := l.duplicate()
		m["node"] = _found(dup, l["node"])
		return m)
	return PropRig.new(b)


## The node in copy [param dup] that stands where [param n] stands in [member node]: the same child at every step down.
func _found(dup: Node, n: Node) -> Node:
	var steps: Array = []
	var at := n
	while at != null and at != node:
		steps.push_front(at.get_index())
		at = at.get_parent()
	var out := dup
	for i in steps:
		out = out.get_child(int(i))
	return out


# --- inside ------------------------------------------------------------------------------------------------------------

func _named(name: String) -> int:
	for wi in _works.size():
		if String((_works[wi] as Dictionary)["name"]) == name:
			return wi
	return -1


## What law [param law] drives on part [param wi]: a state it names, else its joint's angle or offset.
func _channel(wi: int, law: Dictionary) -> String:
	if law.has("state"):
		return String(law["state"])
	match String((_works[wi] as Dictionary)["kind"]):
		"hinge":
			return "angle"
		"slide":
			return "offset"
	return ""


## Channel [param ch] of part [param wi] with nothing acting on it: as its `start` says, else as built.
func _rest(wi: int, ch: String) -> float:
	var start: Dictionary = ((_works[wi] as Dictionary)["w"] as Dictionary).get("start", {}) if ((_works[wi] as Dictionary)["w"] as Dictionary).get("start") is Dictionary else {}
	if start.has(ch) and (start[ch] is float or start[ch] is int):
		return float(start[ch])
	return 0.0 if ch in ["angle", "offset", "glow"] else 1.0


## Channel [param ch] of part [param wi] at [param v], shown.
func _apply(wi: int, ch: String, v: float) -> void:
	var wk: Dictionary = _works[wi]
	_now["%d:%s" % [wi, ch]] = v
	var wn: Node3D = wk["node"]
	match ch:
		"angle", "offset", "fill", "grow":
			wn.transform = _joint(wi) * _scale(wi)
		"glow":
			for m in wk["mats"]:
				(m as ShaderMaterial).set_shader_parameter("glow", v)
		"shown":
			wn.visible = v > 0.5
		"light":
			for l in wk["lights"]:
				var ln: Light3D = (l as Dictionary)["node"]
				ln.light_energy = float((l as Dictionary)["energy"]) * maxf(v, 0.0) * _light_scale
				ln.visible = v * _light_scale > 0.001


## Part [param wi]'s joint as it is posed now ([method Motions]: a hinge turned about its pivot, a slide moved along its axis, each
## held to its range): where its node stands in the node it hangs in.
func _joint(wi: int) -> Transform3D:
	var wk: Dictionary = _works[wi]
	var jt: Dictionary = (wk["w"] as Dictionary).get("joint", {}) if (wk["w"] as Dictionary).get("joint") is Dictionary else {}
	var rg: Variant = jt.get("range")
	match String(wk["kind"]):
		"hinge":
			var a := float(_now.get("%d:angle" % wi, 0.0))
			if rg is Vector2:
				a = clampf(a, (rg as Vector2).x, (rg as Vector2).y)
			var b := Basis(jt["axis"] as Vector3, deg_to_rad(a))
			var pv: Vector3 = jt["pivot"]
			return Transform3D(b, pv - b * pv)
		"slide":
			var o := float(_now.get("%d:offset" % wi, 0.0))
			if rg is Vector2:
				o = clampf(o, (rg as Vector2).x, (rg as Vector2).y)
			return Transform3D(Basis.IDENTITY, (jt["axis"] as Vector3) * o * 0.01)
	return Transform3D.IDENTITY


## Part [param wi] as full and as big as it is posed (about the middle of its base, as a table's are).
func _scale(wi: int) -> Transform3D:
	var fill := float(_now.get("%d:fill" % wi, 1.0))
	var grow := float(_now.get("%d:grow" % wi, 1.0))
	if is_equal_approx(fill, 1.0) and is_equal_approx(grow, 1.0):
		return Transform3D.IDENTITY
	var base: Vector3 = ((_works[wi] as Dictionary)["w"] as Dictionary).get("base", Vector3.ZERO)
	var k := maxf(grow, 0.0005)
	return Transform3D(Basis.from_scale(Vector3(k, k * maxf(fill, 0.0005), k)), base) * Transform3D(Basis.IDENTITY, -base)


## Where [param n] stands in the thing's node ([member node]), through every node between.
func _in_node(n: Node3D) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var at: Node = n
	while at != null and at != node and at is Node3D:
		xf = (at as Node3D).transform * xf
		at = at.get_parent()
	return xf
