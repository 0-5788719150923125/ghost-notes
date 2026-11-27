extends RefCounted
class_name StudioSet

## StudioSet - the studio as the viewer sits in it (next/studio.md, "The set"): the creator's chair, a camera on its tripod in the
## middle of the frame looking back at the viewer from inside a ring light, a giant fluffy microphone in front of it, low in the
## frame, and the things the hands work laid on a side table beside the chair, out of every view, until an act brings them up. Black
## round all of it.
##
## Every thing is a prop playing a role ([PropMakes]: `camera`, `tripod`, `ring_light`, `microphone`, `block`, `brush`, `backdrop`),
## its make the note's choice ([StudioProps]: a prop an agent designed, [RoleDesign]), placed where the note moves it from where the
## studio stands it ([constant PLACE_FIELDS]; a place is the scene's, never a version of the prop), worked through its rig ([PropRig]);
## a role with no make yet stands empty. [method build] makes it all off the tree (a worker builds it) and hands back the root, the rigs
## and the set's [method geometry]: where the capsule is and how the listener is turned, the windscreen's size, the camera's body
## and lens, where the things rest. The camera's own things are on [constant CAMERA_LAYER], which its own screen never sees.

## Where the viewer's eye is and where it looks (m), and its lens (vertical degrees).
const EYE := Vector3(0.0, 1.30, 0.0)
const LOOK := Vector3(0.0, 1.27, -0.95)
const VFOV := 28.0
## Where the camera's lens is, and the ring light's middle behind it (m).
const LENS := Vector3(0.0, 1.30, -0.95)
const RING := Vector3(0.0, 1.30, -1.17)
## Where the microphone's capsule is (m): low in the frame, the top of its windscreen just under the camera.
const CAPSULE := Vector3(0.0, 1.132, -0.62)
## The top of the side table beside the chair, where the worked things lie (m): low, below every view.
const SHELF := 0.62
## Where the green screen stands, behind the viewer's chair facing the camera: out of the viewer's sight, the flip screen's
## background (m).
const BACKDROP := Vector3(0.0, 0.0, 0.95)
## Where each thing rests (m, and degrees turned): on the side table beside the chair, below the frame wherever the head goes and
## below the flip screen's view - the blocks stacked, the brush on its side - until an act brings it up ([StudioActs]).
const RESTS := {
	"block_b": [Vector3(-0.28, SHELF, 0.05), Vector3(0.0, 20.0, 0.0)],
	"block_a": [Vector3(-0.275, SHELF + 0.02, 0.045), Vector3(0.0, 31.0, 0.0)],
	"brush": [Vector3(0.28, SHELF + 0.008, 0.05), Vector3(-85.0, 30.0, 0.0)],
}
## The render layer the camera's own things are on (its screen never sees them).
const CAMERA_LAYER := 2
## Each role's number, salted from the set's: the same set draws the same makes.
const SALTS := {"camera": "studio camera", "tripod": "studio tripod", "ring_light": "studio ring", "microphone": "studio mic",
	"block": "studio block", "brush": "studio brush", "backdrop": "studio backdrop"}
## Where a thing is moved from where the studio stands it, as a note places it (a thing's entry on the Props card, a refine that
## places it): centimeters, degrees and a size, each its range and default - and what the agent placing it is told of each.
const PLACE_FIELDS := {
	"x": {"label": "Across", "blurb": "Centimeters toward the viewer's right (left, less than 0).", "type": "float", "min": -150.0, "max": 150.0, "step": 0.5, "default": 0.0},
	"y": {"label": "Up", "blurb": "Centimeters up (down, less than 0).", "type": "float", "min": -150.0, "max": 150.0, "step": 0.5, "default": 0.0},
	"z": {"label": "Toward you", "blurb": "Centimeters toward the viewer (away, toward the camera, less than 0).", "type": "float", "min": -150.0, "max": 150.0, "step": 0.5, "default": 0.0},
	"turn": {"label": "Turn", "blurb": "Degrees turned about its upright, to its own left (to its right, less than 0).", "type": "float", "min": -180.0, "max": 180.0, "step": 1.0, "default": 0.0},
	"tilt": {"label": "Tip", "blurb": "Degrees tipped back (forward, less than 0).", "type": "float", "min": -90.0, "max": 90.0, "step": 1.0, "default": 0.0},
	"roll": {"label": "Lean", "blurb": "Degrees leaned toward its own left (its right, less than 0).", "type": "float", "min": -90.0, "max": 90.0, "step": 1.0, "default": 0.0},
	"scale": {"label": "Size", "blurb": "How much bigger it is made here (1 its own size).", "type": "float", "min": 0.25, "max": 4.0, "step": 0.01, "default": 1.0},
}
## The roles the studio sets out (the block twice).
const ROLES := ["camera", "tripod", "ring_light", "microphone", "block", "brush", "backdrop"]
## The light: a soft warm key from over the viewer's left shoulder (its color, energy and where it is), a dim fill, and how little
## the room gives back.
const KEY_COLOR := Color(1.0, 0.86, 0.72)
const KEY_ENERGY := 2.4
const KEY_AT := Vector3(-0.75, 1.95, 0.35)
## Where the key is aimed: between the microphone and the camera, so both catch it.
const KEY_AIM := Vector3(0.0, 1.18, -0.72)
const FILL := 0.08
const AMBIENT := Color(0.05, 0.05, 0.06)


## The studio built off the tree from [param seed] and the makes chosen ([param makes]: `{role: choice}`, [PropMakes]): `{root,
## rigs: {camera, tripod, ring_light, microphone, block_a, block_b, brush}, geo}` - see the header. Touches no tree.
static func build(seed: int, makes := {}, places := {}) -> Dictionary:
	var root := Node3D.new()
	root.name = "Studio"
	var rigs := {}
	for role in ["camera", "tripod", "ring_light", "microphone", "brush", "backdrop"]:
		var b := PropMakes.made(role, makes.get(role, {}) if makes.get(role) is Dictionary else {}, hash([seed, SALTS[role]]))
		if b.is_empty():
			continue
		var rig := PropRig.new(b)
		rigs[role] = rig
		root.add_child(rig.node)
	var bb := PropMakes.made("block", makes.get("block", {}) if makes.get("block") is Dictionary else {}, hash([seed, SALTS["block"]]))
	if not bb.is_empty():
		var one := PropRig.new(bb)
		rigs["block_b"] = one
		rigs["block_a"] = one.copy()
		root.add_child(one.node)
		root.add_child((rigs["block_a"] as PropRig).node)
	var geo := _place(rigs, places)
	_light(root)
	return {"root": root, "rigs": rigs, "geo": geo}


## Each thing put where it stands - by its relations (the camera by its lens, the tripod's head under the camera's foot, the ring
## light by its middle, the microphone by its capsule), then moved as the note places it ([param places], [method moved]): each place
## moves its own thing alone, so a camera floating off its tripod is brought down onto it. The set's geometry is worked out from where
## they really are: the lens where the camera is, the sound heard at the capsule where it is.
static func _place(rigs: Dictionary, places := {}) -> Dictionary:
	var geo := {"fur_r": 0.088, "fur_len": 0.024, "brush_tip": 0.186, "block_size": Vector3(0.15, 0.02, 0.05)}
	var view := Basis.looking_at(LOOK - EYE, Vector3.UP)
	geo["listener"] = Transform3D(view, CAPSULE)
	geo["eye"] = Transform3D(view, EYE)
	if rigs.has("microphone"):
		var mic: PropRig = rigs["microphone"]
		var cap: Variant = mic.point_in_thing("capsule")
		var c: Vector3 = cap if cap is Vector3 else Vector3(0.0, 0.272, 0.0)
		mic.node.position = CAPSULE - mic.node.basis * c
		moved(mic, places.get("microphone", {}))
		geo["listener"] = Transform3D(view, mic.node.transform * c)
		var screen := mic.part("windscreen")
		if screen != null:
			for mi in screen.find_children("*", "MeshInstance3D", true, false):
				var box := (mi as MeshInstance3D).get_aabb()
				geo["fur_r"] = maxf(box.size.x, box.size.z) * 0.5 * mic.node.basis.get_scale().x
				break
		var body: Variant = mic.point_in_thing("body")
		geo["mic_body"] = mic.node.transform * (body as Vector3 if body is Vector3 else Vector3(0.0, 0.13, 0.034))
	else:
		geo["mic_body"] = CAPSULE + Vector3(0.0, -0.14, 0.034)
	var cam_origin := LENS
	var mount := LENS
	geo["lens"] = LENS
	if rigs.has("camera"):
		var cam: PropRig = rigs["camera"]
		var lens: Variant = cam.point_in_thing("lens")
		var l: Vector3 = lens if lens is Vector3 else Vector3(0.006, 0.039, 0.114)
		cam.node.position = LENS - cam.node.basis * l
		# where the tripod's head goes: under the camera's own foot (its meshes' lowest, at its origin's place) as the studio stands
		# it - a make whose origin is not its foot still sits on the head, and the camera moved here moves alone
		var foot_box := StudioScene.box_of(cam.node)
		mount = Vector3(cam.node.position.x, foot_box.position.y if foot_box.size.length() > 0.0 else cam.node.position.y, cam.node.position.z)
		moved(cam, places.get("camera", {}))
		cam_origin = cam.node.position
		geo["lens"] = cam.node.transform * l
		var top: Variant = cam.point_in_thing("body")
		geo["camera_body"] = cam.node.transform * (top as Vector3 if top is Vector3 else Vector3(0.03, 0.078, 0.0))
		_layer(cam.node)
	else:
		geo["camera_body"] = LENS + Vector3(0.03, 0.04, -0.1)
	geo["lens_n"] = Vector3(0.0, 0.0, 1.0)
	geo["camera_at"] = cam_origin
	if rigs.has("tripod"):
		# its head under the camera's foot as the studio stands the camera ([param places] move each alone)
		var tri: PropRig = rigs["tripod"]
		var top2: Variant = tri.point_in_thing("top")
		tri.node.position = mount - tri.node.basis * (top2 as Vector3 if top2 is Vector3 else Vector3(0.0, 1.348, 0.0))
		moved(tri, places.get("tripod", {}))
		_layer(tri.node)
	if rigs.has("ring_light"):
		var ring: PropRig = rigs["ring_light"]
		var mid: Variant = ring.point_in_thing("middle")
		ring.node.position = RING - ring.node.basis * (mid as Vector3 if mid is Vector3 else Vector3(0.0, 0.4, 0.0))
		moved(ring, places.get("ring_light", {}))
		_layer(ring.node)
		_round_the_lens(ring.node)
	if rigs.has("backdrop"):
		# turned to face the camera: its front (+z) toward -z, its foot on the floor
		var back: PropRig = rigs["backdrop"]
		back.node.transform = Transform3D(Basis(Vector3.UP, PI) * back.node.basis, BACKDROP)
		moved(back, places.get("backdrop", {}))
	# what the hands work, as big as its make is
	if rigs.has("brush"):
		var tip: Variant = (rigs["brush"] as PropRig).point_in_thing("tip")
		if tip is Vector3:
			geo["brush_tip"] = ((rigs["brush"] as PropRig).node.basis * (tip as Vector3)).length() * float(place_of(places.get("brush", {})).get("scale", 1.0))
	if rigs.has("block_b"):
		# (a make fitted to the role says its size as fitted, [method PropMakes.fitted])
		var bsize: Variant = (rigs["block_b"] as PropRig).built.get("size")
		if bsize is AABB and (bsize as AABB).size.length() > 0.0:
			geo["block_size"] = (bsize as AABB).size * float(place_of(places.get("block", {})).get("scale", 1.0))
	var rests := {}
	for k in RESTS:
		var r: Array = RESTS[k]
		var deg: Vector3 = r[1]
		var rest := Transform3D(Basis.from_euler(Vector3(deg_to_rad(deg.x), deg_to_rad(deg.y), deg_to_rad(deg.z))), r[0])
		var rig_key := String(k)
		if rigs.has(rig_key):
			(rigs[rig_key] as PropRig).node.transform = rest
			# (both blocks are the block's, as placed)
			moved(rigs[rig_key], places.get("block" if rig_key.begins_with("block") else rig_key, {}))
			rest = (rigs[rig_key] as PropRig).node.transform
		rests[k] = rest
	geo["rests"] = rests
	return geo


## [param rig] moved as [param place] says ([constant PLACE_FIELDS]: centimeters across, up and toward the viewer, degrees turned,
## tipped and leaned, how much bigger): turned and scaled about its own foot, then moved. Nothing for an empty place.
static func moved(rig: PropRig, place: Variant) -> void:
	var p := place_of(place)
	if p.is_empty():
		return
	var xf := rig.node.transform
	var k := float(p.get("scale", 1.0))
	var turn := Basis.from_euler(Vector3(deg_to_rad(float(p.get("tilt", 0.0))), deg_to_rad(float(p.get("turn", 0.0))), deg_to_rad(float(p.get("roll", 0.0)))))
	xf.basis = turn * xf.basis.scaled(Vector3(k, k, k))
	xf.origin += Vector3(float(p.get("x", 0.0)), float(p.get("y", 0.0)), float(p.get("z", 0.0))) * 0.01
	rig.node.transform = xf


## A place as written made safe ([constant PLACE_FIELDS]): each field in its range, those at their default left out.
static func place_of(d: Variant) -> Dictionary:
	var out := {}
	if not (d is Dictionary):
		return out
	for k in PLACE_FIELDS:
		var v: Variant = (d as Dictionary).get(k)
		if not (v is float or v is int):
			continue
		var row: Dictionary = PLACE_FIELDS[k]
		var x := clampf(float(v), float(row["min"]), float(row["max"]))
		if not is_equal_approx(x, float(row["default"])):
			out[k] = x
	return out


## The places a Medium block [param block] gives the studio's things: `{role: place}`, each made safe, empty ones left out.
static func places_of(block: Dictionary) -> Dictionary:
	var out := {}
	var src: Dictionary = block.get("places", {}) if block.get("places") is Dictionary else {}
	for role in src:
		if ROLES.has(String(role)):
			var p := place_of(src[role])
			if not p.is_empty():
				out[String(role)] = p
	return out


## Every mesh under [param n] on the camera's own layer.
static func _layer(n: Node) -> void:
	for mi in n.find_children("*", "VisualInstance3D", true, false):
		(mi as VisualInstance3D).layers = 1 << (CAMERA_LAYER - 1)


## The ring light's own light passing round what stands at its middle (everything on [constant CAMERA_LAYER]: the camera, its tripod,
## the ring itself), as a ring of lamps round a lens shines: none of it lit from inside the camera, none of it shading the light.
static func _round_the_lens(n: Node) -> void:
	var own := 1 << (CAMERA_LAYER - 1)
	for l in n.find_children("*", "Light3D", true, false):
		(l as Light3D).light_cull_mask &= ~own
		(l as Light3D).shadow_caster_mask &= ~own


## The key and the fill (the ring light is a prop, and lights itself).
static func _light(root: Node3D) -> void:
	var key := SpotLight3D.new()
	key.name = "Key"
	key.light_color = KEY_COLOR
	key.light_energy = KEY_ENERGY
	key.spot_range = 4.0
	key.spot_angle = 38.0
	key.spot_angle_attenuation = 1.6
	key.shadow_enabled = true
	key.shadow_blur = ShadowFilter.blur(3.0)
	root.add_child(key)
	key.transform = Transform3D(Basis.looking_at(KEY_AIM - KEY_AT, Vector3.UP), KEY_AT)
	var fill := DirectionalLight3D.new()
	fill.name = "Fill"
	fill.light_energy = FILL
	fill.light_color = Color(0.75, 0.82, 1.0)
	root.add_child(fill)
	fill.rotation_degrees = Vector3(-35.0, 160.0, 0.0)


## The viewer's camera for [param geo]: in the chair, looking at the camera.
static func eye_of(geo: Dictionary) -> Transform3D:
	return geo["eye"]
