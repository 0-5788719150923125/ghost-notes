extends RefCounted
class_name StageBeams

## StageBeams - beams of colored light from fixtures high over a scene ([Surroundings]' `beams`), as a stage's or a club's moving
## heads throw them: each from its own lens on a truss across the scene, opening a little as it goes, down through the haze to what
## it lands on. Some hold still and some sweep (a pan and a tilt, each a slow swing of its own); each keeps a color from its palette
## for a stretch of its own, short or long, and moves on to another; some strobe in bursts. A pure function of show time ([method
## tick]): a scrub and a render land where the live show was.
##
## Drawn by the shafts' own shader ([constant LightShafts.SHADER]): a column worked out for each pixel from where the line of sight
## passes its axis, cut where something stands in it, lighting a patch where it lands - here a cone (its `penumbra` the beam's
## spread), faded in just under its lens, colored by its `tint`. No light lights it (a narrow cone is dropped by Godot's light grid,
## [LightShafts]), so a beam's patch has no glint and throws no shadow.
##
## Built out of any tree from each element's properties ([method Surroundings.values_of]) and its number, which places its fixtures,
## draws which beams move, strobe and how long each keeps its colors.

## A beam's radius at its lens at the Width dial's ends (m).
const WIDTH := Vector2(0.01, 0.07)
## How bright a beam is through its middle at strength 1, over a shaft's ([constant LightShafts.GLOW]), and how many times brighter it
## makes what it lands on.
const GLOW := 0.32
const LANDS := 24.0
## How far under its lens a beam fades in (a share of its length), and how far past where it could land it runs on (a share).
const FADE_IN := 0.025
const SINK := 0.1
## How much longer an element's beams are drawn than the longest way to where one lands, so a sweep still reaches the floor (the
## shader's reach is its material's, one for the element).
const LONGER := 1.6
## The truss: how much of the scene's width it spans, how far each fixture strays along it and up and down (m).
const TRUSS := 0.8
const STRAY := Vector2(0.15, 0.12)
## A swing's period at the Speed dial's ends (s), and how much each beam's strays from it (a share either way); a tilt swings this
## share as far as its pan.
const SWING := Vector2(12.0, 1.2)
const SWING_STRAY := 0.3
const TILT := 0.5
## A hold strays from the Hold dial up to this many times either way at Variety 1 (drawn evenly on a log scale).
const HOLD_STRAY := 4.0
## A strobing beam's flash: the share of each flash it is lit, and the share of its holds it strobes through (a burst each).
const FLASH := 0.3
const BURSTS := 0.5
## The most beams drawn, every element's together.
const MOST := 48
## The palettes a beam draws its colors from ([constant Surroundings.BEAM_FIELDS] `palette`); `one` is its Color alone.
const PALETTES := {
	"club": {"label": "Club", "blurb": "Magenta, cyan, deep blue, violet, green and red.",
		"colors": ["#ff2bd6", "#19e3ff", "#3a4dff", "#a238ff", "#2bff88", "#ff3355"]},
	"rainbow": {"label": "Rainbow", "blurb": "Every hue round the wheel.",
		"colors": ["#ff2a2a", "#ff8c1a", "#ffe11a", "#33ff4d", "#1ad1ff", "#3355ff", "#b833ff"]},
	"warm": {"label": "Warm", "blurb": "Reds, oranges, ambers and pinks.",
		"colors": ["#ff3b1f", "#ff7a1a", "#ffb31a", "#ff2b6a", "#ffd9a0"]},
	"cool": {"label": "Cool", "blurb": "Cyans, blues, violets and teal.",
		"colors": ["#1ad1ff", "#2b6bff", "#7a3bff", "#19ffd1", "#c8e6ff"]},
	"ice": {"label": "Ice", "blurb": "White and pale blues.",
		"colors": ["#e8f4ff", "#a8d8ff", "#7fb2ff", "#ffffff"]},
	"one": {"label": "One color", "blurb": "Every beam its Color (white where none is set).", "colors": []},
}


## The beams of [param elements] (each a beams element's properties with its `seed` and `key`, its place among the scene's elements),
## their fixtures on a truss [param reach] (m) up from [param over] (boxes in the host's space, each's top what they land on) along
## [param toward] (the way to the scene's light) turned as each says, under one node, out of any tree. Its meta: `beams` (each beam's
## node and what it does, [method tick]) and `levels` (each element's key -> its material and strength).
static func build(elements: Array, toward: Vector3, over: Array, reach: float, root: Node3D = null) -> Node3D:
	if root == null:
		root = Node3D.new()
		root.name = "Beams"
	var beams: Array = root.get_meta("beams", [])
	var levels: Dictionary = root.get_meta("levels", {})
	for e in elements:
		var v: Dictionary = e
		var r := RandomNumberGenerator.new()
		r.seed = hash([int(v.get("seed", 0)), "beams"])
		var count := int(v["count"])
		var way := LightShafts.way_of(toward, float(v.get("turn", 0.0)), 0.0)
		var lands := LightShafts._lands(count, over, r)
		_shuffle(lands, r)
		var truss := _truss(count, over, way, reach, r)
		var spread := deg_to_rad(float(v["spread"]))
		var penumbra := 2.0 * tan(spread * 0.5)
		# one length for the element's beams (the shader's reach is its material's): the longest way to where one lands, and more
		var length := 0.5
		for i in count:
			length = maxf(length, ((lands[i] as Vector3) - (truss[i] as Vector3)).length() * LONGER)
		var mat := ShaderMaterial.new()
		mat.shader = LightShafts.SHADER
		mat.set_shader_parameter("color", Color(1, 1, 1))
		mat.set_shader_parameter("strength", GLOW * float(v["strength"]))
		mat.set_shader_parameter("lands", LANDS / GLOW)
		mat.set_shader_parameter("penumbra", penumbra)
		mat.set_shader_parameter("reach", length)
		mat.set_shader_parameter("sink", length * SINK)
		mat.set_shader_parameter("soft", 0.35)
		mat.set_shader_parameter("fade_in", FADE_IN)
		mat.set_shader_parameter("flicker", 0.0)
		mat.set_shader_parameter("streaks", 0.2)
		mat.set_shader_parameter("clouds", 0.35)
		mat.set_shader_parameter("forward", 0.45)
		levels[int(v.get("key", -1))] = {"mats": [mat], "strength": GLOW * float(v["strength"])}
		var colors := colors_of(v)
		var hold := float(v["hold"])
		var variety := float(v["variety"])
		var sweep := deg_to_rad(float(v["sweep"]))
		var period := lerpf(SWING.x, SWING.y, float(v["speed"]))
		for i in count:
			if beams.size() >= MOST:
				break
			var from: Vector3 = truss[i]
			var land: Vector3 = lands[i]
			var aim := (land - from).normalized() if (land - from).length() > 1e-4 else Vector3.DOWN
			var rad := 0.5 * lerpf(WIDTH.x, WIDTH.y, float(v["width"])) * r.randf_range(0.8, 1.25)
			var b := {
				"from": from, "aim": aim, "length": length,
				"moving": r.randf() < float(v["moving"]),
				"pan": sweep * r.randf_range(0.5, 1.0), "tilt": sweep * TILT * r.randf_range(0.3, 1.0),
				"w_pan": TAU / (period * r.randf_range(1.0 - SWING_STRAY, 1.0 + SWING_STRAY)),
				"w_tilt": TAU / (period * r.randf_range(1.0 - SWING_STRAY, 1.0 + SWING_STRAY) * 1.37),
				"p_pan": r.randf() * TAU, "p_tilt": r.randf() * TAU,
				"hold": hold * pow(1.0 + (HOLD_STRAY - 1.0) * variety, r.randf_range(-1.0, 1.0)),
				"offset": r.randf() * 100.0,
				"blend": float(v["blend"]),
				"strobe": r.randf() < float(v["strobe"]), "rate": float(v["rate"]) * r.randf_range(0.85, 1.15),
				"colors": colors, "seed": hash([int(v.get("seed", 0)), i]),
			}
			var shaft := _beam(rad, length, mat, penumbra)
			shaft.name = "Beam %d" % beams.size()
			shaft.set_instance_shader_parameter("phase", r.randf() * TAU)
			b["node"] = shaft
			root.add_child(shaft)
			beams.append(b)
			_place(b, 0.0)
	root.set_meta("beams", beams)
	root.set_meta("levels", levels)
	return root


## The beams under [param root] ([method build]) at show time [param t]: each turned where its swing has it, in the color its hold has
## come to (eased from the last over its Blend), flashing through a burst where it strobes.
static func tick(root: Node3D, t: float) -> void:
	if root == null or not root.has_meta("beams"):
		return
	for bv in (root.get_meta("beams") as Array):
		var b: Dictionary = bv
		_place(b, t)
		var shaft: MeshInstance3D = b["node"]
		shaft.set_instance_shader_parameter("tint", color_at(b, t))
		shaft.set_instance_shader_parameter("glow", glow_at(b, t))


## Beam [param b]'s color at [param t]: its hold's color, eased in from the one before over its Blend of the hold.
static func color_at(b: Dictionary, t: float) -> Color:
	var colors: Array = b["colors"]
	if colors.size() <= 1:
		return colors[0] if not colors.is_empty() else Color(1, 1, 1)
	var hold := maxf(float(b["hold"]), 0.05)
	var u := (t + float(b["offset"])) / hold
	var seg := int(floor(u))
	var now := Color(colors[_pick(b, seg)])
	var into := (u - float(seg)) / maxf(float(b["blend"]), 1e-4)
	if into >= 1.0:
		return now
	var was := Color(colors[_pick(b, seg - 1)])
	return was.lerp(now, smoothstep(0.0, 1.0, into))


## Beam [param b]'s brightness at [param t]: whole, but through a strobing beam's burst, a flash [constant FLASH] of each beat at its rate.
static func glow_at(b: Dictionary, t: float) -> float:
	if not bool(b["strobe"]):
		return 1.0
	var hold := maxf(float(b["hold"]), 0.05)
	var seg := int(floor((t + float(b["offset"])) / hold))
	if _unit(int(b["seed"]), seg * 7 + 3) >= BURSTS:
		return 1.0
	return 1.0 if fposmod(t * float(b["rate"]), 1.0) < FLASH else 0.0


## The colors element [param v] draws from: its palette's, or its Color alone where it sets one (or chooses one color).
static func colors_of(v: Dictionary) -> Array:
	var own := String(v.get("color", ""))
	var pal := String(v.get("palette", "club"))
	if Color.html_is_valid(own) and not own.is_empty():
		return [Color.html(own)]
	var row: Dictionary = PALETTES.get(pal, PALETTES["club"])
	var out: Array = (row["colors"] as Array).map(func(c: String) -> Color: return Color.html(c))
	return out if not out.is_empty() else [Color(1, 1, 1)]


## The way beam [param b] points at [param t]: its aim, swung by its pan round the vertical and its tilt across it where it moves.
static func way_at(b: Dictionary, t: float) -> Vector3:
	var aim: Vector3 = b["aim"]
	if not bool(b["moving"]):
		return aim
	var pan := float(b["pan"]) * sin(t * float(b["w_pan"]) + float(b["p_pan"]))
	var tilt := float(b["tilt"]) * sin(t * float(b["w_tilt"]) + float(b["p_tilt"]))
	var side := Vector3.UP.cross(aim)
	side = side.normalized() if side.length() > 1e-4 else Vector3.RIGHT
	return aim.rotated(Vector3.UP, pan).rotated(side.rotated(Vector3.UP, pan), tilt).normalized()


# --- inside ------------------------------------------------------------------------------------------------------------

## Beam [param b]'s node turned to where it points at [param t]: its lens at its fixture, its length down the way.
static func _place(b: Dictionary, t: float) -> void:
	var down := way_at(b, t)
	var dir := -down
	var up := Vector3.UP if absf(dir.dot(Vector3.UP)) < 0.98 else Vector3.BACK
	var side := up.cross(dir).normalized()
	var length := float(b["length"])
	var full := length * (1.0 + SINK)
	(b["node"] as MeshInstance3D).transform = Transform3D(Basis(side, dir, side.cross(dir)), (b["from"] as Vector3) + down * full * 0.5)


## Hold [param seg]'s color of beam [param b]: an index into its colors, never the same as the hold before's.
static func _pick(b: Dictionary, seg: int) -> int:
	var n := (b["colors"] as Array).size()
	var a := int(_unit(int(b["seed"]), seg) * float(n)) % n
	var before := int(_unit(int(b["seed"]), seg - 1) * float(n)) % n
	return (a + 1) % n if a == before else a


## A number from 0 to 1 for [param seed] and [param k], the same every time.
static func _unit(seed: int, k: int) -> float:
	return float(absi(hash([seed, k])) % 100003) / 100003.0


## Where [param count] fixtures hang: on a truss [param reach] up [param way] from the middle of [param over]'s tops, across the way,
## spanning [constant TRUSS] of the boxes' width, each strayed a little along it and up and down.
static func _truss(count: int, over: Array, way: Vector3, reach: float, r: RandomNumberGenerator) -> Array:
	var mid := Vector3.ZERO
	var corners: Array = []
	for bv in over:
		var bx: AABB = bv
		mid += Vector3(bx.get_center().x, bx.end.y, bx.get_center().z)
		for k in 4:
			corners.append(Vector3(bx.position.x if k % 2 == 0 else bx.end.x, bx.end.y, bx.position.z if k < 2 else bx.end.z))
	mid = mid / float(maxi(over.size(), 1))
	var flat := Vector3(way.x, 0.0, way.z)
	var across := Vector3.UP.cross(flat.normalized()) if flat.length() > 1e-3 else Vector3.RIGHT
	across = across.normalized() if across.length() > 1e-4 else Vector3.RIGHT
	var half := 0.5
	for c in corners:
		half = maxf(half, absf(((c as Vector3) - mid).dot(across)))
	half *= TRUSS
	var center := mid + way * reach
	var out: Array = []
	for i in count:
		var u := (float(i) + 0.5) / float(maxi(count, 1)) * 2.0 - 1.0
		out.append(center + across * (u * half + r.randf_range(-STRAY.x, STRAY.x)) + Vector3.UP * r.randf_range(-STRAY.y, STRAY.y))
	return out


## [param a] shuffled in place by [param r].
static func _shuffle(a: Array, r: RandomNumberGenerator) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := r.randi_range(0, i)
		var x: Variant = a[i]
		a[i] = a[j]
		a[j] = x


## One beam's mesh: a cone of radius [param rad] at its lens (its top, +y) opening by [param penumbra] down its [param length] and a
## little past it, drawn by [param mat].
static func _beam(rad: float, length: float, mat: Material, penumbra: float) -> MeshInstance3D:
	var full := length * (1.0 + SINK)
	var mesh := CylinderMesh.new()
	mesh.height = full
	mesh.top_radius = rad * 1.2 + 0.002
	mesh.bottom_radius = rad * 1.2 + 0.5 * penumbra * full + 0.004
	mesh.radial_segments = 20
	mesh.rings = 1
	mesh.cap_top = false
	mesh.cap_bottom = false
	var beam := MeshInstance3D.new()
	beam.mesh = mesh
	beam.material_override = mat
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	beam.set_instance_shader_parameter("radius", rad)
	beam.set_instance_shader_parameter("glow", 1.0)
	beam.extra_cull_margin = full
	return beam
