extends RefCounted
class_name Tonemaps

## Tonemaps - how a 3D set's light is brought down to what a screen can show: Filmic, AgX or ACES, each with a
## preset of its own and three adjustments kept for each (the Look card's Tonemapper rows).
##
## A look, not a quality: it is the Director's, as the filters are (the Look card, a note's `look:` block, ghost.cfg so
## an export render inherits it), and pushed down here ([method choose]). Every 3D set below the Director (the card
## table, the desk, the dispatch desk, the book, the tablet) hands its environment in as it is made ([method dress]),
## with the exposure it was tuned at under Filmic, and is dressed again whenever the choice changes. Filmic is the
## default: its preset is the picture as every set was tuned, so nothing changes until a note picks another.
##
## A preset is the tonemapper's own numbers (its white point, AgX's contrast) and a starting exposure, in stops, over
## the set's own. The adjustments are a person's, laid over it and kept for each tonemapper apart, so trying AgX never
## moves Filmic's: exposure in stops, then contrast and saturation after the tonemapper (the environment's
## adjustments, which every set has on for its fades; only its brightness is the set's).
##
## The tonemappers, each a row: `mode` (Godot's), the preset's `exposure` in stops, and its own numbers: `white`
## (Filmic's and ACES' white point) or `agx_white` and `agx_contrast`.
const REGISTRY := {
	"filmic": {"label": "Filmic",
		"blurb": "Godot's filmic curve: soft shoulders, colors held - the look every set here was tuned in.",
		"mode": Environment.TONE_MAPPER_FILMIC, "exposure": 0.0, "white": 1.0},
	"agx": {"label": "AgX",
		"blurb": "Bright, saturated light rolls toward white as film's does - a flame goes white-hot rather than a flat orange - and the darks sit deeper. Colors come out a little quieter.",
		"mode": Environment.TONE_MAPPER_AGX, "exposure": 0.0, "agx_white": 16.29, "agx_contrast": 1.25},
	"aces": {"label": "ACES",
		"blurb": "The film industry's reference curve, as Godot fits it: more contrast and saturation, punchier darks, and bright colors that shift hue as they climb.",
		"mode": Environment.TONE_MAPPER_ACES, "exposure": 0.0, "white": 1.0},
}
const DEFAULT := "filmic"

## The adjustments, each a row: its range and what is neutral (`default`). Exposure is in stops over the preset's.
const ADJUSTMENTS := {
	"exposure": {"label": "Exposure", "blurb": "Brighter or darker, in stops: each one doubles or halves the light.",
		"min": -2.0, "max": 2.0, "step": 0.05, "default": 0.0},
	"contrast": {"label": "Contrast", "blurb": "The darks and lights pushed apart or drawn together, after the tonemapper.",
		"min": 0.75, "max": 1.25, "step": 0.01, "default": 1.0},
	"saturation": {"label": "Saturation", "blurb": "Colors stronger or quieter, after the tonemapper.",
		"min": 0.5, "max": 1.5, "step": 0.01, "default": 1.0},
}

## Where a set's own exposure is kept on its environment, so dressing it again starts from the set's and not from the
## last dressing.
const BASE_META := &"tonemap_base_exposure"

static var _key := DEFAULT
static var _adjust := {}
static var _envs: Array = []         # WeakRefs of the environments the sets handed in


## [param key] if it is a tonemapper, else the default.
static func known(key: String) -> String:
	return key if REGISTRY.has(key) else DEFAULT


## [param name]'s neutral value.
static func neutral(name: String) -> float:
	return float(Registry.field(ADJUSTMENTS, name, "default", 0.0))


## [param adjust] made whole and held to the ranges: every adjustment named, each in its range.
static func sanitize(adjust: Variant) -> Dictionary:
	var a: Dictionary = adjust if adjust is Dictionary else {}
	var out := {}
	for name in ADJUSTMENTS:
		var row: Dictionary = ADJUSTMENTS[name]
		out[name] = clampf(float(a.get(name, row["default"])), float(row["min"]), float(row["max"]))
	return out


## The choice, from the Director: tonemapper [param key] with its adjustments [param adjust], and every environment
## handed in dressed again.
static func choose(key: String, adjust: Dictionary) -> void:
	_key = known(key)
	_adjust = sanitize(adjust)
	var kept: Array = []
	for w in _envs:
		var env := (w as WeakRef).get_ref() as Environment
		if env != null:
			_dress(env)
			kept.append(w)
	_envs = kept


## The tonemapper chosen now.
static func chosen() -> String:
	return _key


## A set's environment, handed as it is made with [param base_exposure], the exposure it was tuned at under Filmic:
## dressed as the choice has it, and again whenever the choice changes.
static func dress(env: Environment, base_exposure: float) -> void:
	env.set_meta(BASE_META, base_exposure)
	_dress(env)
	for w in _envs:
		if (w as WeakRef).get_ref() == env:
			return
	_envs.append(weakref(env))


static func _dress(env: Environment) -> void:
	var row: Dictionary = REGISTRY[_key]
	var a := _adjust if not _adjust.is_empty() else sanitize({})
	env.tonemap_mode = int(row["mode"]) as Environment.ToneMapper
	env.tonemap_exposure = float(env.get_meta(BASE_META, 1.0)) * pow(2.0, float(row.get("exposure", 0.0)) + float(a["exposure"]))
	env.tonemap_white = float(row.get("white", 1.0))
	env.tonemap_agx_white = float(row.get("agx_white", 16.29))
	env.tonemap_agx_contrast = float(row.get("agx_contrast", 1.25))
	env.adjustment_enabled = true
	env.adjustment_contrast = float(a["contrast"])
	env.adjustment_saturation = float(a["saturation"])
