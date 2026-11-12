extends GhostScene

## Snowfall - a quiet field of falling snow over a soft color bed.
##
## The atmospheric weather scene (distinct from `snowflakes`, the hero crystal field): flakes
## drift down and gust sideways with the treble over a gradient that breathes with the music.
## The seed picks the kind of snow first - fine powder, fat lazy flurry, driven blizzard, still
## hard frost - which decides flake count, size, fall speed and how many crisp into six-fold
## dendrites. Layers: `bed` + `snow` (+ `volumetric` fog, + `veil`) from the [Layer] registry.

# Snow is a weather before it is a color: flake size, count and fall speed are one choice.
#   count/size/fall/crystal go straight to the snow layer; fog/veil are chances; val is the bed
#
# `habits` is the crystal morphology this weather produces, as relative weights over
# [constant Crystal.HABITS]. Habit follows temperature and complexity follows supersaturation
# (the Nakaya diagram), so the conditions that make powder or a flurry also decide whether
# its crystals are columns or ferns.
#
# `density` is the floor and gain of the audio-driven flake count (the drizzle-to-downpour
# axis): a blizzard is loud at its quietest (high floor, small gain), a hoar frost barely moves.
const SNOWS := {
	"powder": {
		# Dry fine snow. Snow takes the color of whatever lights it, so the warm moods are in too.
		# Cold and dry: columns and needles, almost no branching.
		"moods": ["glacier", "bone", "ash", "abyss", "teal", "violet", "dawn", "rose"],
		"count": [260, 380], "size": [0.0035, 0.005], "fall": [0.06, 0.10],
		"crystal": [0.10, 0.25], "fog": 0.70, "veil": 0.0, "val": [0.20, 0.30],
		"habits": {"column": 0.45, "needle": 0.30, "plate": 0.25},
		"complexity": [0.0, 0.2], "rime": [0.0, 0.1], "density": [0.30, 0.75],
	},
	"flurry": {
		# Fat wet flakes, few and slow.
		# Warm and wet, near freezing: big stellar dendrites and sectored plates.
		"moods": ["glacier", "sodium", "dawn", "rose", "violet", "bone", "teal", "abyss"],
		"count": [55, 110], "size": [0.012, 0.020], "fall": [0.045, 0.08],
		"crystal": [0.55, 0.85], "fog": 0.45, "veil": 0.0, "val": [0.22, 0.34],
		"habits": {"stellar": 0.45, "sectored": 0.30, "fern": 0.15, "capped": 0.10},
		"complexity": [0.5, 0.8], "rime": [0.1, 0.35], "density": [0.35, 0.70],
	},
	"blizzard": {
		# Driven and dense enough to hide the ground; brass/sodium are headlights in it.
		# Battered snow: heavily rimed, broken, barely branched.
		"moods": ["ash", "glacier", "abyss", "bone", "teal", "violet", "sodium", "brass"],
		"count": [340, 480], "size": [0.005, 0.008], "fall": [0.20, 0.34],
		"crystal": [0.15, 0.35], "fog": 0.90, "veil": 0.95, "val": [0.12, 0.22],
		"habits": {"plate": 0.35, "column": 0.30, "bullet": 0.20, "stellar": 0.15},
		"complexity": [0.0, 0.25], "rime": [0.5, 1.0], "density": [0.62, 0.95],
	},
	"hoar": {
		# A still, hard frost: fewer flakes, most near ones drawn as dendrites, so its shapes
		# differ, not just its density.
		# Still air and high supersaturation: the showcase, and the only unrimed one.
		"moods": ["glacier", "teal", "bone", "violet", "abyss", "magenta", "ash", "dawn"],
		"count": [150, 240], "size": [0.009, 0.014], "fall": [0.03, 0.06],
		"crystal": [0.80, 1.0], "fog": 0.35, "veil": 0.0, "val": [0.24, 0.36],
		"habits": {"fern": 0.40, "stellar": 0.35, "sectored": 0.25},
		"complexity": [0.75, 1.0], "rime": [0.0, 0.05], "density": [0.55, 0.45],
	},
}


## What this scene can be told ([method GhostScene.choice], [method GhostScene.number]): a
## storyboard entry's `set`, by name; a setting not told is drawn from the seed.
const FIELDS := {
	"snow": {"label": "Snow", "type": "choice", "options": "SNOWS", "default": null,
		"blurb": "What kind of snow falls: fine powder, a flurry of fat slow flakes, a blizzard, or a sparse hoar frost of real crystals."},
	"whiteout": {"label": "Whiteout", "type": "num", "range": [0.35, 0.55], "default": null,
		"blurb": "How close a blizzard's veil comes to a whiteout at its thickest, when there is one."},
}


func build_params(rng: RandomNumberGenerator) -> Dictionary:
	render_kind = "canvas"
	framing = "field"
	var kind := String(choice("snow", rng))
	var s: Dictionary = SNOWS[kind]
	var sch := Scheme.among(s["moods"], rng)
	var val: Array = s["val"]
	add_layer("bed", rng, {
		"hue": sch.hue,
		"sat": clampf(sch.sat * rng.randf_range(0.5, 0.9), 0.05, 1.0),
		"val": rng.randf_range(float(val[0]), float(val[1])),
		"pools": rng.randi_range(2, 4),
	})
	# Volumetric fog rolling low under the snow, behind the flakes (added before the snow layer).
	if rng.randf() < float(s["fog"]):
		add_layer("volumetric", rng, {"mode": "fog", "hue": sch.vary(rng)})
	var count := rng.randi_range(int(s["count"][0]), int(s["count"][1]))
	var crystal := rng.randf_range(float(s["crystal"][0]), float(s["crystal"][1]))
	var dens: Array = s["density"]
	add_layer("snow", rng, {
		"hue": sch.hue_at(1, 3),
		# Snow is near-white whatever lights it, so the mood only tints it faintly.
		"sat": clampf(sch.sat * 0.18, 0.02, 0.35),
		"count": count,
		"size": rng.randf_range(float(s["size"][0]), float(s["size"][1])),
		"fall": rng.randf_range(float(s["fall"][0]), float(s["fall"][1])),
		"crystal_frac": crystal,
		# The crystal bank: enough distinct geometries that counting flakes runs out of patience
		# before shapes, without generating one per flake. Scaled to the field.
		"bank": clampi(int(count / 12) + 8, 10, 32),
		"habits": s["habits"],
		"complexity": rng.randf_range(float(s["complexity"][0]), float(s["complexity"][1])),
		"rime": rng.randf_range(float(s["rime"][0]), float(s["rime"][1])),
		"density_floor": float(dens[0]),
		"density_gain": float(dens[1]),
	})
	# A blizzard needs more obscuring than the snow layer's own squalls: a second veil in front,
	# swelling on loud passages, closes the view to a whiteout.
	if rng.randf() < float(s["veil"]):
		add_layer("veil", rng, {
			"hue": sch.hue, "sat": clampf(sch.sat * 0.12, 0.01, 0.2), "val": 1.0,
			"floor": 0.08, "gain": 0.9, "max": number("whiteout", rng),
		})
	return {"hue": sch.hue, "mood": sch.name, "snow": kind, "count": count, "crystal": crystal}


func update(f: AudioFeatures, delta: float) -> void:
	tick(f, delta)
	drift_view(f, 0.02, 0.03)
	update_layers(f, delta)
	queue_redraw()


func _draw() -> void:
	begin_draw()
	draw_layers()
