extends RefCounted
class_name DeskLight

## DeskLight - the desk's light beyond its lamp (2026-10-27, the user: "some nice ambient lighting, maybe some
## open-flame light sources, which cast nice shadows, etc. ... leverage the Table primitives from the other cards
## mode"): THE ROOM'S, a [Lights] rig built from the light the desk's look writes ([method DeskLook.of]'s `light`:
## the sky's fill, the sun or the moon through a window, lamps out of the shot - as the set dresser writes a
## table's, and fitted as the table's is to the palest thing it falls on, here the page); and THE CANDLES burning
## on the desk, each flame the card table's ([TableLight]: a quad on its wick, flickering in its own time, its wax
## glowing with it) and each candle's one light throwing shadows soft by a filter, never by its size ([method
## TableLight.candle_shadow]) - the pen's among them. Where the desk's mood says the candles light the page
## ([constant DeskLook.MOODS] `leads`), the one that lights it most is the KEY; any other burns as a fill.
##
## NO PAGE BURNS OUT ([constant PAGE_HEAT]): a candle is held to what the paper can take where its light falls
## hardest, the table's rule for its cloth ([constant TableMedium.HEAT]) - a key beside the pad lights it as the lamp
## does, never whiter.
##
## A FLAME SEEN FROM ABOVE: the desk's camera looks nearly straight down, where the table's flame - a quad standing
## upright, turned to the camera across - is seen edge on. Here it faces the camera, foreshortened only so far
## ([constant FLAME_SQUAT]).
##
## A PART OF THE DESK ([DeskMedium]): it reads the scene, the camera and the environment through [member medium].
## Like everything at the desk it is a function of show time ([method tick]).

## The [DeskMedium] this is a part of.
var medium: DeskMedium

## The candles' light: a key's and a fill's energy at the most, and the most a page may be lit (the paper's
## linear lightness times the light on it - the lamp's is about 1).
const KEY_ENERGY := 1.5
const FILL_ENERGY := 0.2
const PAGE_HEAT := 1.15
## A flame's quad stands this much of its height at the least, however steeply it is looked down on.
const FLAME_SQUAT := 0.65
## THE BLOOM a flame bleeds through, the card table's ([TableMedium]), while candles burn: only what is brighter
## than this glows - past a page in any light here (the lamp's about 1, a candle's [constant PAGE_HEAT]).
const GLOW_THRESHOLD := 1.6

var _rig = null                       # the room's light (Lights.Rig), or null
var _candles: Array = []              # {light, energy, flames: [{mesh, base, flicker, glow}]}
var _root: Node3D = null
var _noise := FastNoiseLite.new()


## THE DESK'S LIGHT for [param look] ([method DeskLook.of]) and the things of it that burn ([param lit], [method
## DeskLook.dress]'s), on the desk of [param seed]: what was built before taken down.
func build(look: Dictionary, lit: Array, seed: int) -> void:
	release()
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.frequency = 1.0
	_root = Node3D.new()
	_root.name = "Candles"
	medium._root3.add_child(_root)
	var paper := paper_lum(look)
	var light: Dictionary = look.get("light", {}) if look.get("light") is Dictionary else {}
	if not light.is_empty():
		_rig = Lights.build(light, _stage(), hash([seed, "desk light"]))
		medium._root3.add_child(_rig.root)
		_rig.fit(paper)
	var leads := bool((DeskLook.MOODS[String(look.get("mood", "lamplight"))] as Dictionary).get("leads", false))
	var key := -1
	var best := 0.0
	var fields: Array = []
	for i in lit.size():
		var t: Dictionary = lit[i]
		var node: Node3D = t["node"]
		var own := TableMedium.CANDLE_LAYER << i
		var wicks: Array = t["wicks"]
		for m in t["meshes"]:
			if TableLight.near_wick(m as MeshInstance3D, wicks):
				(m as MeshInstance3D).layers = own
		var flames: Array = []
		var at := Vector3.ZERO
		for k in wicks.size():
			var wick: Vector3 = node.transform * (wicks[k] as Vector3)
			var made := TableLight.flame_nodes(wick, own)
			for n in made:
				_root.add_child(n)
			var flame: MeshInstance3D = made[1]
			var glows: Array = t["glows"]
			flames.append({"mesh": flame, "base": flame.position, "glow": glows[k] if k < glows.size() else null,
				"flicker": TableLight.flicker_seeded(seed, "desk %d %d" % [i, k])})
			at += flame.position
		at /= float(maxi(flames.size(), 1))
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.7, 0.4)
		l.omni_range = 1.4
		l.shadow_caster_mask = 0xFFFFFFFF & ~own & ~Lights.SCREEN_MASK
		l.light_cull_mask = 0xFFFFFFFF & ~own
		TableLight.candle_shadow(l)
		l.position = at + Vector3(0.0, 0.016, 0.0)
		_root.add_child(l)
		var field := page_field(l.position)
		fields.append(field)
		if field.x > best:
			best = field.x
			key = i
		_candles.append({"light": l, "energy": 0.0, "flames": flames})
	if not _candles.is_empty():
		_glow(medium._env, true)
	for i in _candles.size():
		var most := (KEY_ENERGY if leads and i == key else FILL_ENERGY)
		(_candles[i] as Dictionary)["energy"] = minf(most, PAGE_HEAT / maxf(paper * float((fields[i] as Vector2).y), 1e-4))


## THE LIGHT AT SHOW TIME [param t]: the room's, and each candle's flames - flickering each in its own time, facing
## the camera - with its light as bright as they are together.
func tick(t: float) -> void:
	if _rig != null:
		_rig.tick(t)
	if _candles.is_empty():
		return
	var cb := medium._cam.transform.basis
	var squat := clampf(cb.y.dot(Vector3.UP), FLAME_SQUAT, 1.0)
	for c in _candles:
		var bright := 0.0
		for f in (c as Dictionary)["flames"]:
			var fk: Dictionary = f["flicker"]
			var fl := TableLight.flame_burn(_noise, fk, t)
			var rate := float(fk["rate"])
			var fast := _noise.get_noise_2d(t * 9.0 * rate, float(fk["seed"]) + 91.0)
			var mesh: MeshInstance3D = f["mesh"]
			var b := cb * Basis.from_scale(Vector3(1.0 + 0.06 * fast, fl.y * squat, 1.0))
			var foot := (f["base"] as Vector3) - Vector3(0.0, TableLight.FLAME_QUAD * 0.5, 0.0)
			mesh.transform = Transform3D(b, foot + b * Vector3(0.0, TableLight.FLAME_QUAD * 0.5, 0.0))
			var fm := mesh.material_override as ShaderMaterial
			fm.set_shader_parameter("bend", fl.z * 0.0015)
			fm.set_shader_parameter("lick", TableLight.FLAME_QUAD * TableLight.FLAME_LICK.x
				* clampf(0.8 + 0.7 * _noise.get_noise_2d(t * 2.1 * rate, float(fk["seed"]) + 143.0), 0.2, 1.5))
			fm.set_shader_parameter("phase", TAU * 3.2 * rate * t + 2.5 * _noise.get_noise_2d(t * 0.9 * rate, float(fk["seed"]) + 211.0))
			if f.get("glow") is ShaderMaterial:
				(f["glow"] as ShaderMaterial).set_shader_parameter("flame", fl.x)
			bright += fl.x
		var n := maxf(float(((c as Dictionary)["flames"] as Array).size()), 1.0)
		((c as Dictionary)["light"] as OmniLight3D).light_energy = float((c as Dictionary)["energy"]) * bright / n


## Whether the room's light or a candle is up: the desk's own fill, the old flat one, stands down for them.
func lights_room() -> bool:
	return _rig != null


## How many candles burn.
func candles() -> int:
	return _candles.size()


## Each candle's energy, the key's the highest where the candles lead.
func energies() -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for c in _candles:
		out.append(float((c as Dictionary)["energy"]))
	return out


## Everything built taken down, the stage's environment given back.
func release() -> void:
	if medium != null and medium._env != null:
		_glow(medium._env, false)
	if _rig != null:
		_rig.release()
		_rig = null
	if _root != null and is_instance_valid(_root):
		_root.queue_free()
	_root = null
	_candles = []


## The flames' bloom on [param env], or none.
static func _glow(env: Environment, on: bool) -> void:
	env.glow_enabled = on
	if not on:
		return
	env.glow_normalized = false
	env.glow_intensity = 0.75
	env.glow_strength = 1.0
	env.glow_bloom = 0.0
	env.glow_hdr_threshold = GLOW_THRESHOLD
	env.glow_hdr_scale = 2.0
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.set_glow_level(0, 0.0)
	env.set_glow_level(1, 0.6)
	env.set_glow_level(2, 1.0)
	env.set_glow_level(3, 0.8)
	env.set_glow_level(4, 0.4)


## How pale the paper is (linear luminance): what the light is fitted to.
static func paper_lum(look: Dictionary) -> float:
	var c: Color = (look.get("paper", Color(0.97, 0.95, 0.8)) as Color).srgb_to_linear()
	return c.r * 0.2126 + c.g * 0.7152 + c.b * 0.0722


## HOW A LIGHT AT [param at] FALLS ON THE PAGE at energy 1, over the pad's face: (its mean, its most) - the
## light on a point being its slant over its distance squared (an omni light's 1/d, [method TableLight.light_the_table]).
static func page_field(at: Vector3) -> Vector2:
	var sum := 0.0
	var most := 0.0
	var n := 0
	for gy in 7:
		for gx in 5:
			var p := Vector3((float(gx) / 4.0 - 0.5) * LegalPad.W, 0.0, (float(gy) / 6.0 - 0.5) * LegalPad.H)
			var d := at - p
			var h := maxf(d.y, 0.005)
			var f := h / maxf(d.length_squared(), 1e-4)
			sum += f
			most = maxf(most, f)
			n += 1
	return Vector2(sum / float(n), most)


## WHERE THE LIGHT STANDS ([method Lights.build]): the desk's widest framing (the camera that sees most, so a lamp
## out of the shot is out of every shot), the page's middle on the desk's top, the desk and what stands on it, the
## desk the camera sees, the environment; no room picture.
func _stage() -> Dictionary:
	var middle := Vector3(0.0, LegalPad.DESK_Y, 0.0)
	var p := deg_to_rad(float(DeskMedium.WIDE["pitch"]))
	var eye := middle + Vector3(0.0, sin(p), cos(p)) * float(DeskMedium.WIDE["dist"])
	var cam := Transform3D(Basis.looking_at(middle - eye, Vector3.UP), eye)
	var fov := DeskMedium.VFOV
	var seen := PackedVector3Array()
	var reach := DeskLook.REACH.grow(0.2)
	for gy in 12:
		for gx in 16:
			var q := Vector3(reach.position.x + (gx + 0.5) * reach.size.x / 16.0, LegalPad.DESK_Y,
				reach.position.y + (gy + 0.5) * reach.size.y / 12.0)
			if CardTable.in_shot(cam, fov, q):
				seen.append(q)
	var in_shot := func(at: Vector3) -> bool: return CardTable.in_shot(cam, fov, at)
	return {"camera": cam, "fov": fov, "aspect": 16.0 / 9.0, "middle": middle,
		"bounds": AABB(Vector3(reach.position.x, LegalPad.DESK_Y - 0.04, reach.position.y), Vector3(reach.size.x, 0.4, reach.size.y)),
		"seen": seen, "env": medium._env, "room": null, "in_shot": in_shot, "wind": {}}
