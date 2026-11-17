extends RefCounted
class_name Surroundings

## Surroundings - what is round a scene, as a person chooses it on the Environment card (next/environment.md; [EnvironmentCard]):
## the light it is in (a preset, [constant LIGHTS], and how bright), shafts of light through its haze ([method rays]), what drifts in
## its air ([constant AIR], any together), what is heard round it ([constant SOUNDS], any together), how strongly each thing in it
## that throws light throws it and how loud each that makes a sound of its own is. The note's `environment:` block, made safe here ([method sanitize]) and turned into what a scene's
## builders take: [Effects]' air ([method effects_of]), [Soundscape]'s sound ([method sound_of]), the rays. A scene that hosts it reads
## the block from its document (`environment`); with none it keeps its own light and adds nothing.
##
## Every preset is a row of numbers each host reads as it can: a desk its lamp, candles and the room's light through a window
## ([DeskLook]); the Dispatch desk its hollow's ambient, the shaft that falls through its ceiling and its lamp ([DispatchMedium]). A
## row with no `weight` is only ever chosen: a desk drawing its own light from its number never draws it, so adding one moves no
## desk already drawn.

## The light presets: `weight` how often a desk's number draws it (0: only chosen); `lamp` the share of a working lamp that is on;
## `candles` how many burn on a desk ([least, most]) and whether one lights the page (`leads`); `ambient` the room's own light (its
## color, and `ambient_energy`, a share of the scene's own); `key` what the light comes from where it comes through something - "sun",
## "moon", or "" (a shaft through a crack, a lamp's) - its color (`key_color`) and strength (`key_strength`, a share of the scene's
## own); `fog` the haze's color in it.
const LIGHTS := {
	"lamplight": {"label": "Lamplight", "blurb": "Night: a lamp lights the work, the room dark round it - a screen's glow, a street lamp, a fire, the moon in a window.",
		"weight": 4.0, "lamp": 1.0, "candles": [0, 1], "leads": false, "ambient": "#2e3340", "ambient_energy": 1.0, "key": "",
		"key_color": "#9eb0d0", "key_strength": 1.0, "fog": "#1c1f26"},
	"candlelight": {"label": "Candlelight", "blurb": "Night with the lamp off: candles light the work, their shadows moving with their flames.",
		"weight": 2.5, "lamp": 0.0, "candles": [1, 2], "leads": true, "ambient": "#3a2a1e", "ambient_energy": 0.75, "key": "",
		"key_color": "#ffb066", "key_strength": 0.45, "fog": "#241a12"},
	"daylight": {"label": "Daylight", "blurb": "Day: the sun falls through a window across the work, the bars' shadows over it, the sky filling the room.",
		"weight": 2.0, "lamp": 0.0, "candles": [0, 0], "leads": false, "ambient": "#8c96a6", "ambient_energy": 2.4, "key": "sun",
		"key_color": "#fff1dc", "key_strength": 1.8, "fog": "#9aa3ad"},
	"dusk": {"label": "Dusk", "blurb": "Evening: a low gold sun through the window, long shadows, and the lamp on.",
		"weight": 1.5, "lamp": 0.6, "candles": [0, 1], "leads": false, "ambient": "#5a4a5e", "ambient_energy": 1.5, "key": "sun",
		"key_color": "#ffb070", "key_strength": 1.4, "fog": "#4a3a40"},
	"moonlight": {"label": "Moonlight", "blurb": "Night with every lamp off: the moon through a window, white and cold, bright enough to see by.",
		"weight": 0.0, "lamp": 0.0, "candles": [0, 0], "leads": false, "ambient": "#28324a", "ambient_energy": 0.9, "key": "moon",
		"key_color": "#e4ebff", "key_strength": 1.3, "fog": "#232a38"},
	"darkness": {"label": "No light", "blurb": "Nearly dark: no lamp, no candle, only the faint light of the room - the work's own glow, if it has any.",
		"weight": 0.0, "lamp": 0.0, "candles": [0, 0], "leads": false, "ambient": "#15171c", "ambient_energy": 0.4, "key": "",
		"key_color": "#7d8aa6", "key_strength": 0.3, "fog": "#101216"},
}
## What may drift in the air, ticked together ([method effects_of]): each an [Effects] effect over a region every host names -
## `far` (past the work, out of focus), `near` (round the work) or `room` (everywhere, faint) - `count` at the amount dial's 1.
const AIR := {
	"haze": {"label": "Haze", "blurb": "A bank of haze far off, out of focus behind the work: the room's depth, and what light shafts fall through.",
		"effect": {"kind": "fog", "where": "far", "density": 0.45, "rolls": 0.4, "drift": 0.15, "height": 60.0, "grain": 40.0}},
	"dust": {"label": "Dust", "blurb": "Motes of dust drifting through the light, barely there.",
		"effect": {"kind": "motes", "look": "dust", "where": "near", "count": 18, "glow": 0.35, "speed": 0.3}},
	"pixies": {"label": "Pixies", "blurb": "Tiny bright points of colored light that dart and drift, alone or in twos and threes: magic in the air.",
		"effect": {"kind": "motes", "look": "pixie", "where": "near", "count": 7, "glow": 0.7, "speed": 0.6}},
	"fireflies": {"label": "Fireflies", "blurb": "Slow, low sparks that blink on for a moment and off for longer.",
		"effect": {"kind": "motes", "look": "firefly", "where": "far", "count": 10, "glow": 0.7, "speed": 0.4}},
	"wisps": {"label": "Wisps", "blurb": "Large, faint, slow glows that hang and drift in the distance.",
		"effect": {"kind": "motes", "look": "wisp", "where": "far", "count": 4, "glow": 0.5, "speed": 0.3}},
	"embers": {"label": "Embers", "blurb": "Sparks rising from somewhere below, flickering, winking out.",
		"effect": {"kind": "motes", "look": "ember", "where": "far", "count": 10, "glow": 0.7, "speed": 0.5}},
	"snow": {"label": "Snow", "blurb": "Flakes falling slowly, drifting as they fall - snow, ash, pollen.",
		"effect": {"kind": "motes", "look": "snow", "where": "room", "count": 22, "glow": 0.4, "speed": 0.35}},
}
## What may be heard round the scene, ticked together ([method sound_of]): each a part of a [Soundscape]'s `sound`.
const SOUNDS := {
	"rain": {"label": "Rain", "blurb": "Rain on a window, the rest of it muffled outside.", "part": "rain", "spec": {"on": "window", "strength": 0.45}},
	"wind": {"label": "Wind", "blurb": "A wind outside, moaning round the eaves in a gust.", "part": "wind", "spec": {"through": "eaves", "level": 0.6}},
	"fire": {"label": "Fire", "blurb": "A fire burning nearby, crackling - a hearth, a stove.", "part": "fire", "spec": {"size": 0.45, "distance": 0.5}},
	"insects": {"label": "Crickets", "blurb": "Crickets outside, chirp after chirp, each at its own pace.", "part": "insects", "spec": {"kind": "crickets", "strength": 0.4}},
	"stream": {"label": "Stream", "blurb": "Running water - a brook, a fountain, a gutter after rain.", "part": "stream", "spec": {"size": 0.35, "distance": 0.6}},
	"sea": {"label": "Sea", "blurb": "Waves breaking on a shore some way off.", "part": "water", "spec": {"kind": "shore", "size": 0.35, "distance": 0.6}},
}
## The block's keys and what each is when it says nothing: the light preset ("" the scene's own), how bright (a share of it), how
## many shafts of light fall through the haze (-1 the scene's own) and how strong, what drifts and how much of it, what is heard and
## how loud, how strongly each thing in the scene that throws light throws it, and how loud each that makes a sound of its own is
## (each by the name its scene gives it, a share).
const KNOBS := {"light": "", "brightness": 1.0, "rays": -1, "ray_strength": 0.6, "air": [], "air_amount": 1.0, "sound": [],
	"sound_level": 0.5, "lights": {}, "heard": {}}
## The dials' ranges.
const BRIGHTNESS := Vector2(0.25, 2.5)
const RAYS_MOST := 8
const AIR_AMOUNT := Vector2(0.25, 2.5)
const LIGHT_SHARE := Vector2(0.0, 3.0)
const HEARD_SHARE := Vector2(0.0, 2.0)
## A shaft ([method rays]): its cone (degrees from its axis), its width where it comes through (a share of its length), how bright it
## is through its middle at strength 1 (seen against the dark), and the light it throws where it lands at strength 1 - a narrow spot
## that does not fade along its length, as light through a hole does not.
const RAY_CONE := 3.5
const RAY_THROUGH := 0.02
const RAY_GLOW := 0.5
const RAY_LIGHT := 2.2
const SHAFT_SHADER := preload("res://shaders/light_shaft.gdshader")


## The block [param raw] made safe: every key of [constant KNOBS], a preset it does not know the scene's own, ticks it does not know
## dropped, numbers held to their ranges.
static func sanitize(raw: Variant) -> Dictionary:
	var d: Dictionary = raw if raw is Dictionary else {}
	var out := KNOBS.duplicate(true)
	var light := String(d.get("light", "")).strip_edges().to_lower() if d.get("light") is String else ""
	out["light"] = light if LIGHTS.has(light) else ""
	out["brightness"] = Props._num(d.get("brightness"), 1.0, BRIGHTNESS.x, BRIGHTNESS.y)
	out["rays"] = int(Props._num(d.get("rays"), -1.0, -1.0, float(RAYS_MOST)))
	out["ray_strength"] = Props._num(d.get("ray_strength"), 0.6, 0.0, 1.0)
	out["air"] = _ticks(d.get("air"), AIR)
	out["air_amount"] = Props._num(d.get("air_amount"), 1.0, AIR_AMOUNT.x, AIR_AMOUNT.y)
	out["sound"] = _ticks(d.get("sound"), SOUNDS)
	out["sound_level"] = Props._num(d.get("sound_level"), 0.5, 0.0, 1.0)
	out["lights"] = _shares(d.get("lights"), LIGHT_SHARE)
	out["heard"] = _shares(d.get("heard"), HEARD_SHARE)
	return out


## A thing's name -> its share, made safe from [param v]: names kept short, shares held to [param range], at most 32.
static func _shares(v: Variant, range: Vector2) -> Dictionary:
	var out := {}
	if v is Dictionary:
		for k in (v as Dictionary):
			var key := Props._text(k, 60)
			if not key.is_empty() and out.size() < 32:
				out[key] = Props._num((v as Dictionary)[k], 1.0, range.x, range.y)
	return out


## The keys of [param table] that [param v] ticks, in the table's order.
static func _ticks(v: Variant, table: Dictionary) -> Array:
	var out: Array = []
	var asked: Array = v if v is Array else []
	for k in table:
		if k in asked:
			out.append(k)
	return out


## Light preset [param key]'s row, or the row a scene's own light is nearest to ([param own]) where the block names none.
static func light_of(spec: Dictionary, own := "lamplight") -> Dictionary:
	var k := String(spec.get("light", ""))
	return LIGHTS[k] if LIGHTS.has(k) else LIGHTS.get(own, LIGHTS["lamplight"])


## How strongly the thing a scene calls [param name] throws its light ([member KNOBS] `lights`): 1 where the block says nothing.
static func share_of(spec: Dictionary, name: String) -> float:
	return float((spec.get("lights", {}) as Dictionary).get(name, 1.0))


## How loud the thing a scene calls [param name] is in what it makes of its own ([member KNOBS] `heard`): 1 where the block says
## nothing.
static func heard_of(spec: Dictionary, name: String) -> float:
	return float((spec.get("heard", {}) as Dictionary).get(name, 1.0))


## What drifts in the air ([constant AIR] ticked in [param spec]) as [Effects] effects over a host's regions `far`, `near` and `room`,
## each as many as the amount dial says, its fog the color of [param fog]: made safe by [method Effects.sanitize]. A mote never
## goes away on a visit: its exit is out of the picture the air was built for, and a host's camera moves on to another, where
## the motes leaving and waiting there would stand in a line.
static func effects_of(spec: Dictionary, fog: Color) -> Array:
	var raw: Array = []
	var amount := float(spec.get("air_amount", 1.0))
	for k in spec.get("air", []):
		var fx: Dictionary = (AIR[k] as Dictionary)["effect"].duplicate(true)
		fx["name"] = String(k)
		if fx.has("count"):
			fx["count"] = maxi(1, roundi(float(fx["count"]) * amount))
		if String(fx["kind"]) == "motes":
			fx["away"] = 0.0
		if String(fx["kind"]) == "fog":
			fx["density"] = clampf(float(fx["density"]) * amount, 0.0, 1.0)
			fx["color"] = "#" + fog.to_html(false)
		raw.append(fx)
	return Effects.sanitize(raw, ["#" + fog.to_html(false)], ["far", "near", "room"], [])


## What is heard ([constant SOUNDS] ticked in [param spec]) as a [Soundscape]'s `sound`, made safe; {} for silence.
static func sound_of(spec: Dictionary) -> Dictionary:
	var raw := {}
	for k in spec.get("sound", []):
		var row: Dictionary = SOUNDS[k]
		raw[String(row["part"])] = (row["spec"] as Dictionary).duplicate(true)
	return Soundscape.sanitize(raw) if not raw.is_empty() else {}


## [param count] shafts of light through the haze, each falling [param reach] (m) from [param toward] (the way to their light, from
## where they land) onto its own place in [param over] (a box in the host's space, its top where they land), colored [param color]
## and as strong as [param strength] says: under one node, out of any tree, each a drawn shaft ([constant SHAFT_SHADER]) and a narrow
## spot lighting where it lands. Its places are drawn from [param seed], spread so no two land together; the dust in them drifts by
## show time ([method tick_rays]).
static func rays(count: int, strength: float, color: Color, toward: Vector3, over: AABB, seed: int, reach := 3.0) -> Node3D:
	var root := Node3D.new()
	root.name = "Rays"
	var mat := ShaderMaterial.new()
	mat.shader = SHAFT_SHADER
	mat.set_shader_parameter("color", color)
	mat.set_shader_parameter("strength", RAY_GLOW * strength)
	mat.set_shader_parameter("span", reach)
	mat.set_shader_parameter("soft", 0.08 * reach)
	root.set_meta("shaft", mat)
	var r := RandomNumberGenerator.new()
	r.seed = hash([seed, "rays"])
	var dir := toward.normalized() if toward.length() > 1e-4 else Vector3.UP
	var up := Vector3.UP if absf(dir.dot(Vector3.UP)) < 0.98 else Vector3.BACK
	for i in count:
		# a place in its own stretch of the box, so the shafts stand apart
		var u := (float(i) + r.randf_range(0.2, 0.8)) / float(maxi(count, 1))
		var land := Vector3(lerpf(over.position.x, over.end.x, u), over.end.y, lerpf(over.position.z, over.end.z, r.randf()))
		var at := land + dir * reach
		var cone := RAY_CONE * r.randf_range(0.7, 1.3)
		var ray := Node3D.new()
		ray.name = "Ray %d" % i
		root.add_child(ray)
		var light := SpotLight3D.new()
		light.name = "Light"
		light.light_color = color
		light.light_energy = RAY_LIGHT * strength * r.randf_range(0.7, 1.15)
		light.spot_range = reach * 1.6
		light.spot_angle = cone
		light.spot_angle_attenuation = 0.6
		light.spot_attenuation = 0.0
		light.light_volumetric_fog_energy = 0.0
		light.shadow_enabled = false
		light.transform = Transform3D(Basis.looking_at(land - at, up), at)
		ray.add_child(light)
		# the shaft drawn: a cone along its axis, +y toward where it comes through
		var mesh := CylinderMesh.new()
		mesh.height = reach
		mesh.top_radius = reach * RAY_THROUGH
		mesh.bottom_radius = reach * tan(deg_to_rad(cone)) + reach * RAY_THROUGH
		mesh.radial_segments = 24
		mesh.rings = 1
		mesh.cap_top = false
		mesh.cap_bottom = false
		var shaft := MeshInstance3D.new()
		shaft.name = "Shaft"
		shaft.mesh = mesh
		shaft.material_override = mat
		shaft.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var side := up.cross(dir).normalized()
		shaft.transform = Transform3D(Basis(side, dir, side.cross(dir)), (land + at) * 0.5)
		ray.add_child(shaft)
	return root


## The dust in shafts [param rays] ([method rays]) where it is at show time [param t].
static func tick_rays(rays_root: Node3D, t: float) -> void:
	if rays_root != null and rays_root.has_meta("shaft"):
		(rays_root.get_meta("shaft") as ShaderMaterial).set_shader_parameter("t", t)


## The volumetric fog a scene's environment [param env] wants for what [param spec] chooses: on where a bank of haze lies (a fog volume
## needs it), at the scene's own density [param own] (0 a scene with none, whose fog is then off), colored as the light's fog.
static func fog_for(env: Environment, spec: Dictionary, own: float) -> void:
	var row := light_of(spec)
	env.volumetric_fog_enabled = own > 0.0 or "haze" in (spec.get("air", []) as Array)
	env.volumetric_fog_density = own
	env.volumetric_fog_albedo = Color.html(String(row["fog"])).lerp(Color(0.75, 0.76, 0.8), 0.5)


## The way to light [param from] (degrees round the scene, [constant Lights.FROM]'s: 0 from behind the viewer, 90 their right) at
## [param height] degrees up: a direction in a scene's own space (x right, y up, z toward the viewer).
static func toward(from: float, height: float) -> Vector3:
	var a := deg_to_rad(from)
	var h := deg_to_rad(height)
	return Vector3(sin(a) * cos(h), sin(h), cos(a) * cos(h))
