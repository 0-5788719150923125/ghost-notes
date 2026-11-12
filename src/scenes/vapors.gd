extends GhostScene

## Vapors - colored ink-in-water: heavy masses twisting through the frame with fibrous
## strands drawn out of them, lit from inside.
##
## Unlike `clouds`, `fog_bank`, `fog_volume` and `aurora` (stacked gaussian puffs, which can only
## be soft), this is diffuse but hard: a mass with a visible front, bright threads streaming
## inside it, color changing across the frame. So the scene is a field: one quad, one density
## evaluated per pixel. Read shaders/vapor_field.gdshader's header for how (a ridged multifractal
## for the filaments, a double domain warp for the twist, the plume envelope re-tapped toward
## the lamp for the volume) and [Layer.Vapor] for the plumes that place, color and drive it.
##
## Its gate is tests/scenes/vapor_check.gd: presence, a front, drawn-out filaments, more than
## one hue, and motion, each against a control that breaks that one property.
##
## The music touches light and speed, never shape. The vapor travels steadily forward and turns
## over on its own clock; a swell brightens it, nudges its rate of flow and thickens each mass
## slightly over a second or two; a beat lights the plume it landed on. Nothing is resized
## (amplitude is a mass's size, so driving it makes the frame inflate and collapse); every audio
## path ends in a brightness or a rate, and the gate holds it to that. The tonal center pulls
## every hue toward the music's key, eased as a vector so a key change sweeps instead of jumping.
##
## The kind of vapor comes from one roll, since the choices are not independent: ink is dense,
## wet and dark, a nebula wide, diffuse and starlit, gossamer pale and almost all fiber.

# The vapor's character. Each decides the moods it may be colored from, the field's shape (how
# hard the front, how fibrous, how big the features, how violently it turns), where the masses
# sit, and what else is in the frame.
const CHARACTERS := {
	# INK - a drop of ink in still water: dense, wet, sharp-fronted, dark around it.
	"ink": {
		"moods": ["abyss", "violet", "magenta", "teal", "ember"],
		"layouts": ["scatter", "sweep"],
		"count": [5, 7], "hard": [0.72, 0.95], "thresh": [0.46, 0.60],
		"stretch": [2.2, 3.6], "crease": [1.9, 2.8], "scale": [0.85, 1.25],
		"swirl": [0.55, 0.85], "churn": [0.8, 1.3], "flow": [0.012, 0.026], "haze": [0.07, 0.14],
		"shadow": [1.9, 2.8], "sat": [0.80, 0.95], "size": [0.9, 1.15],
		"counter": 0.3, "bed": [0.008, 0.022], "stars": 0.15, "dust": 0.25,
	},
	# NEBULA - broad, diffuse, colors far apart, starlight behind it.
	"nebula": {
		"moods": ["violet", "magenta", "abyss", "glacier", "rose", "teal"],
		"layouts": ["edges", "scatter"],
		"count": [5, 7], "hard": [0.32, 0.58], "thresh": [0.40, 0.52],
		"stretch": [1.7, 2.7], "crease": [1.2, 1.9], "scale": [0.60, 0.90],
		"swirl": [0.40, 0.65], "churn": [0.55, 0.95], "flow": [0.016, 0.034], "haze": [0.16, 0.26],
		"shadow": [1.2, 1.9], "sat": [0.70, 0.90], "size": [1.05, 1.35],
		"counter": 0.5, "bed": [0.008, 0.022], "stars": 0.90, "dust": 0.20,
	},
	# GOSSAMER - pale, low mass, almost entirely strand, stretched between whatever it is caught on.
	"gossamer": {
		"moods": ["glacier", "bone", "teal", "violet", "ash"],
		"layouts": ["sweep", "edges"],
		"count": [4, 6], "hard": [0.60, 0.88], "thresh": [0.44, 0.56],
		"stretch": [3.2, 4.8], "crease": [2.4, 3.2], "scale": [0.90, 1.30],
		"swirl": [0.35, 0.60], "churn": [0.5, 0.9], "flow": [0.022, 0.042], "haze": [0.06, 0.12],
		"shadow": [1.6, 2.4], "sat": [0.30, 0.55], "size": [0.95, 1.25],
		"counter": 0.2, "bed": [0.008, 0.022], "stars": 0.35, "dust": 0.60,
	},
	# PLASMA - vapor with power in it: hot, saturated, turning over fast.
	"plasma": {
		"moods": ["toxic", "magenta", "sodium", "teal", "ember", "verdant"],
		"layouts": ["scatter", "edges", "sweep"],
		"count": [6, 8], "hard": [0.68, 0.92], "thresh": [0.44, 0.58],
		"stretch": [2.0, 3.2], "crease": [1.8, 2.8], "scale": [0.80, 1.20],
		"swirl": [0.70, 1.00], "churn": [1.25, 1.90], "flow": [0.026, 0.050], "haze": [0.10, 0.18],
		"shadow": [1.5, 2.3], "sat": [0.85, 1.00], "size": [0.85, 1.10],
		"counter": 0.45, "bed": [0.008, 0.022], "stars": 0.10, "dust": 0.15,
	},
}

var _vapor: Layer.Vapor = null
# The tonal center, held as a vector and eased there (see the note in update()).
var _ch_vec := Vector2.ZERO


## What this scene can be told ([method GhostScene.choice], [method GhostScene.number]): a
## storyboard entry's `set`, by name; a setting not told is drawn from the seed.
const FIELDS := {
	"character": {"label": "Character", "type": "choice", "options": "CHARACTERS", "default": null,
		"blurb": "What the vapor is like: a drop of ink in still water, a nebula seen across light years, a pale gossamer cobweb, or hot plasma turning over fast."},
	"stars": {"label": "Stars", "type": "num", "range": [60, 220], "default": null,
		"blurb": "How many stars show behind the vapor, when there are any."},
	"glow": {"label": "Glow", "type": "num", "range": [1.15, 1.50], "default": null,
		"blurb": "How brightly the vapor glows overall."},
	"motes": {"label": "Motes", "type": "num", "range": [40, 120], "default": null,
		"blurb": "How many motes float in the vapor, when there are any."},
}


func build_params(rng: RandomNumberGenerator) -> Dictionary:
	render_kind = "canvas"
	framing = "field"
	var kind := String(choice("character", rng))
	var ch: Dictionary = CHARACTERS[kind]
	var sch := Scheme.among(ch["moods"], rng)
	var layouts: Array = ch["layouts"]
	var layout := String(layouts[rng.randi() % layouts.size()])
	# The ground is nearly black on purpose: the field is additive light, so any brightness under
	# it is brightness the vapor cannot be darker than, and the look needs true dark between masses.
	add_layer("bed", rng, {
		"hue": sch.hue,
		"sat": clampf(sch.sat * rng.randf_range(0.5, 0.9), 0.05, 1.0),
		"val": _pick(rng, ch["bed"]),
		"pools": rng.randi_range(2, 5),
	})
	if rng.randf() < float(ch["stars"]):
		add_layer("stars", rng, {
			"z": "back", "count": number("stars", rng), "hue": sch.accent})
	_vapor = add_layer("vapor", rng, {
		"hue": sch.hue,
		"accent": sch.accent,              # the fringe / shadow chroma
		"spread": sch.spread * rng.randf_range(1.2, 2.6),
		"sat": _pick(rng, ch["sat"]),
		"val": rng.randf_range(0.95, 1.0),
		"count": rng.randi_range(int(ch["count"][0]), int(ch["count"][1])),
		"layout": layout,
		"counter": float(ch["counter"]),   # share of masses on the OPPOSING hue
		"size": _pick(rng, ch["size"]),
		"hard": _pick(rng, ch["hard"]),
		"thresh": _pick(rng, ch["thresh"]),
		"stretch": _pick(rng, ch["stretch"]),
		"crease": _pick(rng, ch["crease"]),
		"scale": _pick(rng, ch["scale"]),
		"swirl": _pick(rng, ch["swirl"]),
		"churn": _pick(rng, ch["churn"]),      # how fast the medium turns over...
		"flow": _pick(rng, ch["flow"]),        # ...and how fast it travels while doing it
		"haze": _pick(rng, ch["haze"]),
		"shadow": _pick(rng, ch["shadow"]),
		"gain": number("glow", rng),
	}) as Layer.Vapor
	# Motes draw onto the scene's own canvas, so the field (a child quad, see [Layer.FieldQuad])
	# composites over them whatever order they are added in. Additive light does not occlude, so
	# the motes read through the vapor, brightened where it is thick.
	if rng.randf() < float(ch["dust"]):
		add_layer("dust", rng, {
			"hue": sch.accent, "count": number("motes", rng),
			"shaft": false, "speed": rng.randf_range(0.01, 0.03)})
	return {"hue": sch.hue, "mood": sch.name, "character": kind, "layout": layout}


static func _pick(rng: RandomNumberGenerator, r: Array) -> float:
	return rng.randf_range(float(r[0]), float(r[1]))


func update(f: AudioFeatures, delta: float) -> void:
	tick(f, delta)
	# A whisper of camera: the field's own motion is the show, and a pan on top reads as the
	# camera slipping.
	drift_view(f, 0.010, 0.018)
	# The tonal center, eased as a vector (as tidepool does). An angle is the wrong quantity to
	# ease: when two tonal centers a tritone apart trade dominance the resultant passes near the
	# origin and its angle flips half a turn, which would change every mass's color at once. Easing
	# the vector routes that through the middle: an ambiguous tonality reads as low strength and
	# the pull fades out instead of picking a side.
	var raw := chroma_hue()
	var want := Vector2(cos(raw.x * TAU), sin(raw.x * TAU)) * raw.y
	_ch_vec = _ch_vec.lerp(want, 1.0 - exp(-0.85 * delta))
	if _vapor != null:
		_vapor.tonal = Vector2(fposmod(_ch_vec.angle() / TAU, 1.0),
			clampf(_ch_vec.length(), 0.0, 1.0))
	update_layers(f, delta)
	queue_redraw()


func _draw() -> void:
	begin_draw()
	draw_layers()
