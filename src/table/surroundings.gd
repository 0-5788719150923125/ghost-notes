extends RefCounted
class_name Surroundings

## Surroundings - what is round a scene (next/environment.md; [EnvironmentCard]): a list of elements, each a kind of thing
## ([constant KINDS]) - the light the scene is in, shafts of light through its haze, something drifting in its air, something heard
## round it - with a number of its own and the properties a person set on it. A property never set is drawn from the element's number
## inside its field's bounds ([Roll]), so a new number is another variant of the same thing. The Dex offers every kind, each light
## preset and a few looks of shafts ([method offers]), and what a person keeps ([EnvironmentLibrary]).
##
## The note's `environment:` block: `elements` (each `{kind, seed, name, off, <its fields>}` - `name` where it was kept under one,
## `off` while it is set aside), `lights` (how strongly each thing in the scene that throws light throws it, by the name its scene
## gives it: a share) and `heard` (how loud each thing that makes a sound of its own is). [method sanitize] makes it safe; a host reads
## it through [method light_of], [method brightness], [method rays], [method effects_of], [method sound_of] and [method fog_for]. A
## scene with no element of a kind keeps its own (its own light, its own shaft, no air, silence).
##
## Every light preset is a row of numbers each host reads as it can: a desk its lamp, candles and the room's light through a window
## ([DeskLook]); the Dispatch desk its hollow's ambient, the shaft that falls through its ceiling and its lamp ([DispatchMedium]). A
## row with no `weight` is only ever chosen: a desk drawing its own light from its number never draws it.

## The kinds of element: `group` the Dex's shelf it stands on ([constant GROUPS]); `one` whether a scene has at most one (another
## added takes its place); for what drifts, the [Effects] effect it is (`effect`, over a region every host names - `far` past the
## work, `near` round it, `room` everywhere, faint - `count` at Amount 1); for what is heard, the [Soundscape] part it is (`part`) and
## its words there (`spec`).
const KINDS := {
	"light": {"label": "Light", "blurb": "The light the scene is in - lamplight, candlelight, daylight, dusk, moonlight or none - and how bright.",
		"group": "light", "one": true},
	"shafts": {"label": "Light shafts", "blurb": "Shafts of light through the haze - through a window, a crack, the leaves: each a column as wide as the gap it came through, landing in a bright patch its own size.",
		"group": "light", "one": false},
	"haze": {"label": "Haze", "blurb": "A bank of haze far off, out of focus behind the work: the room's depth, and what light shafts fall through.",
		"group": "air", "one": false, "effect": {"kind": "fog", "where": "far", "density": 0.45, "rolls": 0.4, "drift": 0.15, "height": 60.0, "grain": 40.0}},
	"dust": {"label": "Dust", "blurb": "Motes of dust drifting through the light, barely there.",
		"group": "air", "one": false, "effect": {"kind": "motes", "look": "dust", "where": "near", "count": 160, "glow": 0.8, "speed": 0.3, "size": 2.2}},
	"pixies": {"label": "Pixies", "blurb": "Tiny bright points of colored light that dart and drift, alone or in twos and threes: magic in the air.",
		"group": "air", "one": false, "effect": {"kind": "motes", "look": "pixie", "where": "near", "count": 7, "glow": 0.7, "speed": 0.6}},
	"fireflies": {"label": "Fireflies", "blurb": "Slow, low sparks that blink on for a moment and off for longer.",
		"group": "air", "one": false, "effect": {"kind": "motes", "look": "firefly", "where": "far", "count": 10, "glow": 0.7, "speed": 0.4}},
	"wisps": {"label": "Wisps", "blurb": "Large, faint, slow glows that hang and drift in the distance.",
		"group": "air", "one": false, "effect": {"kind": "motes", "look": "wisp", "where": "far", "count": 4, "glow": 0.5, "speed": 0.3}},
	"embers": {"label": "Embers", "blurb": "Sparks rising from somewhere below, flickering, winking out.",
		"group": "air", "one": false, "effect": {"kind": "motes", "look": "ember", "where": "far", "count": 10, "glow": 0.7, "speed": 0.5}},
	"snow": {"label": "Snow", "blurb": "Flakes falling slowly, drifting as they fall - snow, ash, pollen.",
		"group": "air", "one": false, "effect": {"kind": "motes", "look": "snow", "where": "room", "count": 22, "glow": 0.4, "speed": 0.35}},
	"rain": {"label": "Rain", "blurb": "Rain falling outside, or on what is over the scene.", "group": "sound", "one": true,
		"part": "rain", "spec": {"on": "window", "strength": 0.45}},
	"wind": {"label": "Wind", "blurb": "A wind outside, moaning round the eaves in a gust.", "group": "sound", "one": true,
		"part": "wind", "spec": {"through": "eaves", "level": 0.6}},
	"fire": {"label": "Fire", "blurb": "A fire burning nearby, crackling - a hearth, a stove.", "group": "sound", "one": true,
		"part": "fire", "spec": {"size": 0.45, "distance": 0.5}},
	"insects": {"label": "Insects", "blurb": "Crickets in the grass, chirp after chirp, or cicadas swelling in the trees.", "group": "sound", "one": true,
		"part": "insects", "spec": {"kind": "crickets", "strength": 0.4}},
	"stream": {"label": "Stream", "blurb": "Running water - a brook, a fountain, a gutter after rain.", "group": "sound", "one": true,
		"part": "stream", "spec": {"size": 0.35, "distance": 0.6}},
	"sea": {"label": "Sea", "blurb": "Waves on a shore some way off, against a hull, round a dock.", "group": "sound", "one": true,
		"part": "water", "spec": {"kind": "shore", "size": 0.35, "distance": 0.6}},
}
## The Dex's shelves for what is offered built in, by an element's `group`.
const GROUPS := {
	"light": {"label": "Light", "blurb": "The light a scene is in, and shafts of light through its haze."},
	"air": {"label": "In the air", "blurb": "What drifts in the air round the scene."},
	"sound": {"label": "Heard", "blurb": "What is heard round the scene, under the voice."},
}
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
## Looks of light shafts the Dex offers beside the kind as it rolls: each with some of its properties set ([constant SHAFT_FIELDS]).
const SHAFT_LOOKS := {
	"leaves": {"label": "Through leaves", "blurb": "Many thin shafts through a canopy, of every width, shimmering as the leaves move.",
		"set": {"count": 18, "width": 0.22, "inner": 0, "variety": -0.8, "flicker": 0.45, "spread": 6.0}},
	"window": {"label": "Through a window", "blurb": "Two broad, still beams, a few narrower shafts bright inside each.",
		"set": {"count": 2, "width": 0.65, "inner": 3, "variety": 0.25, "flicker": 0.0, "spread": 0.0}},
	"crack": {"label": "Through a crack", "blurb": "One narrow shaft from high up, a thinner, brighter one down its middle.",
		"set": {"count": 1, "width": 0.18, "inner": 1, "variety": 0.0, "flicker": 0.0, "spread": 0.0}},
}

## What a light can be told ([Roll]'s rows): its preset ("own" the scene's own) and how bright the whole scene is.
const LIGHT_FIELDS := {
	"preset": {"label": "Light", "blurb": "The light the scene is in; its own, as the scene lights itself.", "type": "enum",
		"options": ["own", "lamplight", "candlelight", "daylight", "dusk", "moonlight", "darkness"], "default": "own",
		"roll": ["lamplight", "candlelight", "daylight", "dusk", "moonlight"]},
	"brightness": {"label": "Brightness", "blurb": "How bright the whole scene is, over its light's own: 1 as the light is.", "type": "float",
		"min": 0.25, "max": 2.5, "step": 0.05, "default": 1.0, "roll": [0.85, 1.25]},
}
## What light shafts can be told: how many beams, how wide (a share of what the scene allows: a pencil's width to a window's, [constant
## LightShafts.WIDTH]), how many narrower shafts inside each, which way they come from and how steeply (turned from the scene's own
## light), how far each beam's way strays from the rest, how strong, how much they differ, how much they shimmer, their color.
const SHAFT_FIELDS := {
	"count": {"label": "Beams", "blurb": "How many beams fall.", "type": "int", "min": 1, "max": 30, "step": 1, "default": 4, "roll": [3, 14]},
	"width": {"label": "Width", "blurb": "How wide each beam is, from a pencil's width to a window's.", "type": "float", "min": 0.0, "max": 1.0,
		"step": 0.01, "default": 0.3, "roll": [0.1, 0.55]},
	"inner": {"label": "Inner shafts", "blurb": "How many narrower shafts fall inside each beam, twice as bright where they cross it.", "type": "int",
		"min": 0, "max": 3, "step": 1, "default": 1, "roll": [0, 2]},
	"turn": {"label": "Direction", "blurb": "Which way they come from, turned round from the scene's own light (degrees).", "type": "float",
		"min": -180.0, "max": 180.0, "step": 1.0, "default": 0.0, "roll": [-60.0, 60.0]},
	"steep": {"label": "Steepness", "blurb": "How steeply they fall, over the scene's own light: below 0 lower, as a sun near setting (degrees).",
		"type": "float", "min": -40.0, "max": 30.0, "step": 1.0, "default": 0.0, "roll": [-20.0, 12.0]},
	"spread": {"label": "Spread", "blurb": "How far each beam's way strays from the others' (degrees): 0 all parallel, as through one window; more, as through leaves.",
		"type": "float", "min": 0.0, "max": 25.0, "step": 0.5, "default": 0.0, "roll": [0.0, 9.0]},
	"strength": {"label": "Strength", "blurb": "How strongly they light the haze, and the patches where they land.", "type": "float",
		"min": 0.0, "max": 1.0, "step": 0.05, "default": 0.5, "roll": [0.3, 0.7]},
	"variety": {"label": "Variety", "blurb": "How the beams' widths stray from the Width: 0 all alike; above 0 some much fatter, below 0 some much skinnier; and how much they differ in brightness.",
		"type": "float", "min": -1.0, "max": 1.0, "step": 0.05, "default": 0.0, "roll": [-0.6, 0.6]},
	"flicker": {"label": "Flicker", "blurb": "How much they shimmer, as light through moving leaves does.", "type": "float",
		"min": 0.0, "max": 1.0, "step": 0.05, "default": 0.0, "roll": [0.0, 0.3]},
	"color": {"label": "Color", "blurb": "Their color; unset, the light's own.", "type": "color", "default": ""},
}
## What drifting motes can be told; a kind's own size (its effect's, else its look's), glow, speed and color are its defaults, drawn
## near them ([method fields_of]).
const MOTE_FIELDS := {
	"amount": {"label": "Amount", "blurb": "How many: 1 as the kind is.", "type": "float", "min": 0.25, "max": 2.5, "step": 0.05, "default": 1.0,
		"roll": [0.7, 1.5]},
	"size": {"label": "Size", "blurb": "How big each is (mm).", "type": "float", "step": 0.1},
	"glow": {"label": "Glow", "blurb": "How brightly each glows.", "type": "float", "min": 0.0, "max": 1.0, "step": 0.05},
	"speed": {"label": "Speed", "blurb": "How fast they wander.", "type": "float", "min": 0.0, "max": 1.0, "step": 0.05},
	"color": {"label": "Color", "blurb": "Their color.", "type": "color"},
}
## What haze can be told: how thick, how much it rolls, which way and how fast it drifts.
const FOG_FIELDS := {
	"density": {"label": "Density", "blurb": "How thick the haze is.", "type": "float", "min": 0.0, "max": 1.0, "step": 0.05, "default": 0.45,
		"roll": [0.3, 0.6]},
	"rolls": {"label": "Rolls", "blurb": "How much it rolls and billows.", "type": "float", "min": 0.0, "max": 1.0, "step": 0.05, "default": 0.4,
		"roll": [0.2, 0.6]},
	"drift": {"label": "Drift", "blurb": "Which way it drifts, and how fast.", "type": "float", "min": -1.0, "max": 1.0, "step": 0.05, "default": 0.15,
		"roll": [-0.3, 0.3]},
}
## What each sound can be told, by its [Soundscape] part: how loud it is, and what it is like (a choice's options are the part's own,
## [method fields_of]).
const SOUND_FIELDS := {
	"rain": {"strength": {"label": "Strength", "blurb": "How hard it rains.", "type": "float", "min": 0.0, "max": 1.0, "step": 0.05, "roll": [0.3, 0.6]},
		"on": {"label": "On", "blurb": "What it falls on.", "type": "enum", "roll": ["window", "roof", "leaves"]}},
	"wind": {"level": {"label": "Level", "blurb": "How loud the wind is.", "type": "float", "min": 0.0, "max": 1.0, "step": 0.05, "roll": [0.4, 0.75]},
		"through": {"label": "Through", "blurb": "What it blows through.", "type": "enum", "roll": ["eaves", "trees", "open"]}},
	"fire": {"size": {"label": "Size", "blurb": "How big the fire is.", "type": "float", "min": 0.0, "max": 1.0, "step": 0.05, "roll": [0.3, 0.6]},
		"distance": {"label": "Distance", "blurb": "How far off it burns.", "type": "float", "min": 0.0, "max": 1.0, "step": 0.05, "roll": [0.3, 0.7]}},
	"insects": {"strength": {"label": "Strength", "blurb": "How loud they are.", "type": "float", "min": 0.0, "max": 1.0, "step": 0.05, "roll": [0.25, 0.55]},
		"kind": {"label": "Kind", "blurb": "Which insects sing.", "type": "enum", "roll": ["crickets", "cicadas"]}},
	"stream": {"size": {"label": "Size", "blurb": "How much water runs.", "type": "float", "min": 0.0, "max": 1.0, "step": 0.05, "roll": [0.25, 0.5]},
		"distance": {"label": "Distance", "blurb": "How far off it runs.", "type": "float", "min": 0.0, "max": 1.0, "step": 0.05, "roll": [0.4, 0.8]}},
	"water": {"size": {"label": "Size", "blurb": "How big the waves are.", "type": "float", "min": 0.0, "max": 1.0, "step": 0.05, "roll": [0.25, 0.5]},
		"distance": {"label": "Distance", "blurb": "How far off the water is.", "type": "float", "min": 0.0, "max": 1.0, "step": 0.05, "roll": [0.4, 0.8]},
		"kind": {"label": "Kind", "blurb": "What the water is.", "type": "enum", "roll": ["shore", "dock"]}},
}
## The block's keys and what each is when it says nothing.
const KNOBS := {"elements": [], "lights": {}, "heard": {}}
## The most elements a scene has, and the keys of an element that are no property of it.
const MOST := 12
const OWN_KEYS := ["kind", "seed", "name", "off"]
## How strongly a thing throws its light, and how loud it is, over how it is made.
const LIGHT_SHARE := Vector2(0.0, 3.0)
const HEARD_SHARE := Vector2(0.0, 2.0)
## How loud what is heard is under the voice ([Soundscape]'s bed level).
const BED_LEVEL := 0.5
## An element's picture, on its row and the Dex (pixels).
const PICTURE := Vector2i(176, 132)


## The block [param raw] made safe: its elements each a kind it knows with a number and the properties its fields allow, a kind there
## may be one of kept once (the first), at most [constant MOST]; a lit or heard thing's share kept by its name, held to its range.
static func sanitize(raw: Variant) -> Dictionary:
	var d: Dictionary = raw if raw is Dictionary else {}
	var out := {"elements": [], "lights": _shares(d.get("lights"), LIGHT_SHARE), "heard": _shares(d.get("heard"), HEARD_SHARE)}
	var seen := {}
	for e in ((d["elements"] as Array) if d.get("elements") is Array else []):
		var el := element(e)
		if el.is_empty() or (out["elements"] as Array).size() >= MOST:
			continue
		var kind := String(el["kind"])
		if bool((KINDS[kind] as Dictionary)["one"]) and seen.has(kind):
			continue
		seen[kind] = true
		(out["elements"] as Array).append(el)
	return out


## One element made safe from [param raw]: `{kind, seed}`, its `name` and `off` where it has them, and what it sets of its kind's
## fields ([method Roll.clean]); {} for a kind it does not know. An element with no number is given its kind's own.
static func element(raw: Variant) -> Dictionary:
	if not (raw is Dictionary):
		return {}
	var d: Dictionary = raw
	var kind := String(d.get("kind", "")).strip_edges().to_lower() if d.get("kind") is String else ""
	if not KINDS.has(kind):
		return {}
	var seed := int(d["seed"]) if typeof(d.get("seed")) in [TYPE_INT, TYPE_FLOAT] else absi(hash(kind)) % 1000000
	var out := {"kind": kind, "seed": seed}
	var name := Props._text(d.get("name", ""), 60)
	if not name.is_empty():
		out["name"] = name
	if d.get("off") == true:
		out["off"] = true
	out.merge(Roll.clean(fields_of(kind), d))
	return out


## What element [param el] sets of its fields: the element without its kind, number, name and whether it is set aside.
static func set_of(el: Dictionary) -> Dictionary:
	var out := el.duplicate(true)
	for k in OWN_KEYS:
		out.erase(k)
	return out


## The fields a kind [param kind] can be told ([Roll]'s rows): a light's, shafts', haze's, motes' (their own size, glow, speed and color
## its defaults), or a sound's (its part's own choices). A shaft's color unset is [param color] ("" where it follows the scene's).
static func fields_of(kind: String, color := "") -> Dictionary:
	var row: Dictionary = KINDS.get(kind, {})
	if kind == "light":
		var out := LIGHT_FIELDS.duplicate(true)
		var labels := {"own": "The scene's own"}
		for k in LIGHTS:
			labels[k] = Registry.label(LIGHTS, k)
		(out["preset"] as Dictionary)["labels"] = labels
		return out
	if kind == "shafts":
		var out := SHAFT_FIELDS.duplicate(true)
		(out["color"] as Dictionary)["default"] = color
		return out
	if row.has("effect"):
		var fx: Dictionary = row["effect"]
		if String(fx["kind"]) == "fog":
			return FOG_FIELDS.duplicate(true)
		var base: Dictionary = Effects.MOTES[String(fx["look"])]
		var out := MOTE_FIELDS.duplicate(true)
		var sizes: Vector2 = base["sizes"]
		var size := float(fx.get("size", base["size"]))
		out["size"].merge({"min": sizes.x, "max": sizes.y, "default": size,
			"roll": [maxf(sizes.x, size * 0.75), minf(sizes.y, size * 1.35)]})
		for k in ["glow", "speed"]:
			var v := float(fx[k])
			out[k].merge({"default": v, "roll": [maxf(0.0, v - 0.15), minf(1.0, v + 0.15)]})
		out["color"]["default"] = String(base["color"])
		return out
	if row.has("part"):
		var part := String(row["part"])
		var out: Dictionary = (SOUND_FIELDS.get(part, {}) as Dictionary).duplicate(true)
		var spec: Dictionary = row["spec"]
		var tables := {"on": Soundscape.RAINS, "through": Soundscape.THROUGH, "kind": Soundscape.INSECTS if part == "insects" else Soundscape.WATERS}
		for k in out:
			var f: Dictionary = out[k]
			if String(f["type"]) == "enum":
				f["options"] = (tables[k] as Dictionary).keys()
			f["default"] = spec.get(k, f.get("min", 0.0) if String(f["type"]) == "float" else (f["options"] as Array)[0])
		return out
	return {}


## Every property of element [param el]: what it sets, the rest drawn by its number ([method Roll.values]). A shaft's color unset is
## "" (the scene's).
static func values_of(el: Dictionary) -> Dictionary:
	return Roll.values(fields_of(String(el.get("kind", ""))), set_of(el), int(el.get("seed", 0)))


## The elements of [param spec] in use (none set aside), of group [param group] ("" every group).
static func in_use(spec: Dictionary, group := "") -> Array:
	var out: Array = []
	for e in (spec.get("elements", []) as Array):
		var el: Dictionary = e
		if el.get("off") == true:
			continue
		if group.is_empty() or String((KINDS[String(el["kind"])] as Dictionary)["group"]) == group:
			out.append(el)
	return out


## The light element in use, or {} where the scene keeps its own.
static func light_element(spec: Dictionary) -> Dictionary:
	for el in in_use(spec, "light"):
		if String((el as Dictionary)["kind"]) == "light":
			return el
	return {}


## The light preset the block [param spec] chooses (made safe here, so a document's own will do), "" where it chooses none (the
## scene's own).
static func preset_of(spec: Variant) -> String:
	var el := light_element(sanitize(spec))
	if el.is_empty():
		return ""
	var p := String(values_of(el)["preset"])
	return p if LIGHTS.has(p) else ""


## The preset row of the light [param spec] chooses, or the row a scene's own light is nearest to ([param own]) where it chooses none.
static func light_of(spec: Dictionary, own := "lamplight") -> Dictionary:
	var k := preset_of(spec)
	return LIGHTS[k] if LIGHTS.has(k) else LIGHTS.get(own, LIGHTS["lamplight"])


## How bright the whole scene is over its light's own: the light element's, 1 with none.
static func brightness(spec: Dictionary) -> float:
	var el := light_element(spec)
	return float(values_of(el)["brightness"]) if not el.is_empty() else 1.0


## How strongly the thing a scene calls [param name] throws its light ([constant KNOBS] `lights`): 1 where the block says nothing.
static func share_of(spec: Dictionary, name: String) -> float:
	return float((spec.get("lights", {}) as Dictionary).get(name, 1.0))


## How loud the thing a scene calls [param name] is in what it makes of its own ([constant KNOBS] `heard`): 1 where the block says
## nothing.
static func heard_of(spec: Dictionary, name: String) -> float:
	return float((spec.get("heard", {}) as Dictionary).get(name, 1.0))


## Whether [param spec] has shafts of light in use: a scene's own shaft then gives way to them.
static func has_shafts(spec: Dictionary) -> bool:
	return in_use(spec, "light").any(func(el: Dictionary) -> bool: return String(el["kind"]) == "shafts")


## Every shafts element in use in [param spec], built ([method LightShafts.build]): falling [param reach] (m) from [param toward] (the
## way to their light) onto [param over] (boxes in the host's space, each's top where they land), [param color] where an element's is
## unset. Null where there are none.
static func rays(spec: Dictionary, color: Color, toward: Vector3, over: Array, reach: float) -> Node3D:
	var els: Array = []
	for el in in_use(spec, "light"):
		if String((el as Dictionary)["kind"]) == "shafts":
			var v := values_of(el)
			v["seed"] = int((el as Dictionary)["seed"])
			els.append(v)
	return LightShafts.build(els, color, toward, over, reach) if not els.is_empty() else null


## The shafts [param rays_root] ([method rays]) as they are at show time [param t].
static func tick_rays(rays_root: Node3D, t: float) -> void:
	LightShafts.tick(rays_root, t)


## What drifts in the air ([param spec]'s air elements) as [Effects] effects over a host's regions `far`, `near` and `room`, each as
## many as its Amount says (those round the work [param near] times as many, for a host whose region round it is larger), its fog the
## color of [param fog]: made safe by [method Effects.sanitize]. A mote never goes away on a visit: its exit is out of the picture the
## air was built for, and a host's camera moves on to another, where the motes leaving and waiting there would stand in a line. Each
## element's number places its own motes.
static func effects_of(spec: Dictionary, fog: Color, near := 1.0) -> Array:
	var raw: Array = []
	for e in in_use(spec, "air"):
		var el: Dictionary = e
		var v := values_of(el)
		var fx: Dictionary = (KINDS[String(el["kind"])] as Dictionary)["effect"].duplicate(true)
		fx["name"] = "%s %d" % [String(el["kind"]), int(el["seed"])]
		if String(fx["kind"]) == "motes":
			fx["count"] = maxi(1, roundi(float(fx["count"]) * float(v["amount"]) * (near if String(fx.get("where", "")) == "near" else 1.0)))
			fx["size"] = v["size"]
			fx["glow"] = v["glow"]
			fx["speed"] = v["speed"]
			fx["color"] = v["color"]
			fx["away"] = 0.0
		else:
			fx["density"] = v["density"]
			fx["rolls"] = v["rolls"]
			fx["drift"] = v["drift"]
			fx["color"] = "#" + fog.to_html(false)
		raw.append(fx)
	return Effects.sanitize(raw, ["#" + fog.to_html(false)], ["far", "near", "room"], [])


## What is heard ([param spec]'s sound elements) as a [Soundscape]'s `sound`, made safe; {} for silence.
static func sound_of(spec: Dictionary) -> Dictionary:
	var raw := {}
	for e in in_use(spec, "sound"):
		var row: Dictionary = KINDS[String((e as Dictionary)["kind"])]
		var part: Dictionary = (row["spec"] as Dictionary).duplicate(true)
		part.merge(values_of(e), true)
		raw[String(row["part"])] = part
	return Soundscape.sanitize(raw) if not raw.is_empty() else {}


## Whether a bank of haze is in use in [param spec].
static func hazy(spec: Dictionary) -> bool:
	return in_use(spec, "air").any(func(el: Dictionary) -> bool: return String(el["kind"]) == "haze")


## The volumetric fog a scene's environment [param env] wants for what [param spec] chooses: on where a bank of haze lies (a fog volume
## needs it), at the scene's own density [param own] (0 a scene with none, whose fog is then off), colored as the light's fog.
static func fog_for(env: Environment, spec: Dictionary, own: float) -> void:
	var row := light_of(spec)
	env.volumetric_fog_enabled = own > 0.0 or hazy(spec)
	env.volumetric_fog_density = own
	env.volumetric_fog_albedo = Color.html(String(row["fog"])).lerp(Color(0.75, 0.76, 0.8), 0.5)


## The way to light [param from] (degrees round the scene, [constant Lights.FROM]'s: 0 from behind the viewer, 90 their right) at
## [param height] degrees up: a direction in a scene's own space (x right, y up, z toward the viewer).
static func toward(from: float, height: float) -> Vector3:
	var a := deg_to_rad(from)
	var h := deg_to_rad(height)
	return Vector3(sin(a) * cos(h), sin(h), cos(a) * cos(h))


# --- what the Dex offers -------------------------------------------------------------------------------------------------

## Every element offered built in, by its key on the Dex: each light preset (`preset:<key>`), light shafts as they roll
## (`kind:shafts`) and in each of their looks (`look:<key>`), and every other kind (`kind:<key>`) - each `{label, blurb, group, element}`,
## its element with a fixed number (a new one is drawn when it is added).
static func offers() -> Dictionary:
	var out := {}
	for k in LIGHTS:
		out["preset:" + k] = {"label": Registry.label(LIGHTS, k), "blurb": Registry.blurb(LIGHTS, k), "group": "light",
			"element": {"kind": "light", "seed": absi(hash(k)) % 1000000, "preset": k}}
	for k in KINDS:
		if k == "light":
			continue
		out["kind:" + k] = {"label": Registry.label(KINDS, k), "blurb": Registry.blurb(KINDS, k), "group": String((KINDS[k] as Dictionary)["group"]),
			"element": {"kind": k, "seed": absi(hash(k)) % 1000000}}
		if k == "shafts":
			for look in SHAFT_LOOKS:
				var el := {"kind": "shafts", "seed": absi(hash(look)) % 1000000}
				el.merge((SHAFT_LOOKS[look] as Dictionary)["set"])
				out["look:" + look] = {"label": Registry.label(SHAFT_LOOKS, look), "blurb": Registry.blurb(SHAFT_LOOKS, look), "group": "light",
					"element": el}
	return out


## What element [param el] is, in a line: its kind's properties that say most ("7 beams, wide, flickering"; "110% as bright as it
## is").
static func line_of(el: Dictionary) -> String:
	var v := values_of(el)
	match String(el.get("kind", "")):
		"light":
			return "%s%% as bright as it is" % str(roundi(float(v["brightness"]) * 100.0))
		"shafts":
			var parts := PackedStringArray(["%d beam%s" % [int(v["count"]), "" if int(v["count"]) == 1 else "s"]])
			parts.append(["thin", "narrow", "wide", "broad"][clampi(int(float(v["width"]) * 4.0), 0, 3)])
			if int(v["inner"]) > 0:
				parts.append("%d inside each" % int(v["inner"]))
			if float(v["flicker"]) >= 0.1:
				parts.append("flickering")
			return ", ".join(parts)
	var kind_row: Dictionary = KINDS.get(String(el.get("kind", "")), {})
	if kind_row.has("effect"):
		if String((kind_row["effect"] as Dictionary)["kind"]) == "fog":
			return "%s%% thick" % str(roundi(float(v["density"]) * 100.0))
		return "%d%% as many, %s mm" % [roundi(float(v["amount"]) * 100.0), str(snappedf(float(v["size"]), 0.1))]
	var loud := float(v.get("strength", v.get("level", v.get("size", 0.5))))
	return "%s%% loud" % str(roundi(loud * 100.0))


# --- an element's picture ------------------------------------------------------------------------------------------------

## Element [param el] drawn small, as it would be under the light [param spec] chooses: a light its sky over its room, shafts their
## beams over the dark (narrower ones bright inside each, their patches where they land), what drifts as its motes or its haze, what
## is heard as its sound's shape. Drawn in boxes alone, so it is quick on any thread.
static func picture(el: Dictionary, spec: Dictionary, size := PICTURE) -> Image:
	var img := Image.create(size.x, size.y, false, Image.FORMAT_RGB8)
	var kind := String(el.get("kind", ""))
	var v := values_of(el)
	var row := light_of(spec)
	var dark := Color.html(String(row["ambient"])).darkened(0.6)
	img.fill(dark)
	var r := RandomNumberGenerator.new()
	r.seed = hash([int(el.get("seed", 0)), kind, "picture"])
	match String((KINDS.get(kind, {}) as Dictionary).get("group", "")):
		"light":
			if kind == "light":
				_sky(img, v)
			else:
				_beams(img, v, Color.html(String(v["color"])) if Color.html_is_valid(String(v["color"])) else Color.html(String(row["key_color"])), r)
		"air":
			var fx: Dictionary = (KINDS[kind] as Dictionary)["effect"]
			if String(fx["kind"]) == "fog":
				var fog := Color.html(String(row["fog"])).lerp(Color(0.75, 0.76, 0.8), 0.5)
				for y in size.y:
					var a := float(v["density"]) * (0.25 + 0.75 * float(y) / float(size.y)) * (0.85 + 0.15 * sin(float(y) * 0.21 + r.randf()))
					img.fill_rect(Rect2i(0, y, size.x, 1), dark.lerp(fog, clampf(a, 0.0, 1.0)))
			else:
				var c := Color.html(String(v["color"]))
				var n := maxi(1, roundi(float(fx["count"]) * float(v["amount"])))
				var px := clampi(roundi(float(v["size"]) * 1.2), 1, 7)
				for i in n:
					var at := Vector2i(r.randi_range(2, size.x - px - 2), r.randi_range(2, size.y - px - 2))
					img.fill_rect(Rect2i(at, Vector2i(px, px)), dark.lerp(c, clampf(0.35 + float(v["glow"]) * r.randf_range(0.5, 1.0), 0.0, 1.0)))
		"sound":
			_sound_shape(img, kind, v, r)
	return img


## A light's picture: its sky's color over its room's, brighter as it is.
static func _sky(img: Image, v: Dictionary) -> void:
	var p := String(v["preset"])
	var row: Dictionary = LIGHTS.get(p, {"ambient": "#30343c", "key_color": "#8a8f99"})
	var sky := Color.html(String(row["key_color"]))
	var room := Color.html(String(row["ambient"]))
	var b := clampf(float(v["brightness"]), 0.25, 2.5)
	var h := img.get_height()
	for y in h:
		var k := float(y) / float(h - 1)
		var c := sky.lerp(room, smoothstep(0.0, 0.8, k))
		img.fill_rect(Rect2i(0, y, img.get_width(), 1), Color(c.r * b, c.g * b, c.b * b).clamp())


## Shafts' picture: each beam a band down the picture, a narrower band inside it adding to it, a patch where it lands.
static func _beams(img: Image, v: Dictionary, color: Color, r: RandomNumberGenerator) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var floor := h - 14
	var light := PackedFloat32Array()
	light.resize(w)
	var n := int(v["count"])
	var variety := float(v["variety"])
	for i in n:
		var rad := clampf(lerpf(1.0, 18.0, float(v["width"])) * pow(LightShafts.VARIETY_MOST, variety * r.randf()), 0.7, 40.0)
		var mid := (float(i) + r.randf_range(0.25, 0.75)) / float(n) * float(w)
		var bright := 0.75 * (1.0 + r.randf_range(-0.45, 0.25) * absf(variety))
		_band(light, mid, rad, bright)
		for j in int(v["inner"]):
			var ir := rad * r.randf_range(LightShafts.INNER.x, LightShafts.INNER.y)
			_band(light, mid + r.randf_range(-1.0, 1.0) * (rad - ir) * 0.9, ir, 0.75)
	var base := img.get_pixel(0, 0)
	var s := float(v["strength"])
	for x in w:
		var l := light[x]
		img.fill_rect(Rect2i(x, 0, 1, floor), base.lerp(color, clampf(l * s * 0.55, 0.0, 1.0)))
		img.fill_rect(Rect2i(x, floor, 1, h - floor), base.lightened(0.08).lerp(color, clampf(l * s * 1.4, 0.0, 1.0)))


static func _band(light: PackedFloat32Array, mid: float, rad: float, bright: float) -> void:
	for x in range(maxi(0, floori(mid - rad)), mini(light.size(), ceili(mid + rad) + 1)):
		var d := (float(x) - mid) / maxf(rad, 0.5)
		if absf(d) < 1.0:
			light[x] += bright * sqrt(1.0 - d * d)


## A sound's picture: bars in its shape - rain many and quick, wind a slow swell, fire crackling, insects in pulses, water in waves.
static func _sound_shape(img: Image, kind: String, v: Dictionary, r: RandomNumberGenerator) -> void:
	var colors := {"rain": "#8fa8c8", "wind": "#c8d0d8", "fire": "#ff9a4a", "insects": "#a8d878", "stream": "#78c8c0", "sea": "#6898d8"}
	var c := Color.html(String(colors.get(kind, "#cccccc")))
	var w := img.get_width()
	var h := img.get_height()
	var loud := clampf(float(v.get("strength", v.get("level", v.get("size", 0.5)))), 0.05, 1.0)
	var bars := 44
	var bw := maxi(1, w / bars - 1)
	for i in bars:
		var x := float(i) / float(bars)
		var a := 0.5
		match kind:
			"rain":
				a = r.randf_range(0.2, 1.0)
			"wind":
				a = 0.35 + 0.65 * (0.5 + 0.5 * sin(x * TAU * 1.3))
			"fire":
				a = 0.3 + (0.7 if r.randf() < 0.18 else 0.2 * r.randf())
			"insects":
				a = 0.9 if (i % 6) < 2 else 0.1
			_:
				a = 0.4 + 0.6 * (0.5 + 0.5 * sin(x * TAU * 2.2)) * r.randf_range(0.7, 1.0)
		var bh := maxi(2, roundi(a * loud * float(h) * 0.8))
		img.fill_rect(Rect2i(i * (bw + 1) + 1, (h - bh) / 2, bw, bh), c)


## A thing's name -> its share, made safe from [param v]: names kept short, shares held to [param range], at most 32.
static func _shares(v: Variant, range: Vector2) -> Dictionary:
	var out := {}
	if v is Dictionary:
		for k in (v as Dictionary):
			var key := Props._text(k, 60)
			if not key.is_empty() and out.size() < 32:
				out[key] = Props._num((v as Dictionary)[k], 1.0, range.x, range.y)
	return out
