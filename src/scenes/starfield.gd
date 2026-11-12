extends GhostScene

## Starfield - a deep night sky, twinkling, with the occasional shooting star.
##
## A parallax field of stars over a near-black nebula bed and a wisp of colored fog; brighter
## stars glow, and every so often a meteor streaks across (more often on a beat). The seed picks
## where in the galaxy the sky is looked at from, which decides crowding, dust and company as one
## choice. Layers: `bed` + `fog` + `stars` (+ `cosmos` / `volumetric` / `planet` / `flare`).

# A sky is a place before it is a color: a crowded dusty core and an empty deep field differ in
# star count, lit dust and company, so one roll moves all of it and the mood set follows.
#   count - stars; val - the bed's brightness; fog - haze alpha; the rest are chances of company
const SKIES := {
	"core": {
		# Toward the galactic center: thousands of stars reddened by the dust in front of them.
		"moods": ["sodium", "dawn", "brass", "bone", "ember", "magenta", "violet", "rose"],
		"count": [420, 700], "val": [0.10, 0.17], "fog": [0.035, 0.06], "fog_n": [5, 9],
		"cosmos": 0.85, "cosmos_n": [1, 3], "volumetric": 0.65, "planet": 0.15, "flare": 0.80,
	},
	"deep": {
		# A deep field between the arms: almost nothing, very far away, very cold.
		"moods": ["abyss", "violet", "ash", "glacier", "teal", "bone", "magenta", "verdant"],
		"count": [45, 110], "val": [0.02, 0.05], "fog": [0.008, 0.02], "fog_n": [2, 4],
		"cosmos": 0.55, "cosmos_n": [1, 2], "volumetric": 0.10, "planet": 0.30, "flare": 0.20,
	},
	"nebula": {
		# Inside the cloud, where the gas is the subject: emission nebulae are lurid green-teal, so
		# "toxic" belongs here as much as violet.
		"moods": ["magenta", "violet", "teal", "abyss", "rose", "toxic", "glacier", "ember", "dawn"],
		"count": [150, 280], "val": [0.06, 0.12], "fog": [0.03, 0.055], "fog_n": [4, 8],
		"cosmos": 1.00, "cosmos_n": [2, 3], "volumetric": 0.85, "planet": 0.25, "flare": 0.45,
	},
	"orbit": {
		# Close over a world with the sun just past its limb: the planet and flare are the scene.
		"moods": ["glacier", "abyss", "ash", "bone", "sodium", "teal", "verdant", "brass", "violet"],
		"count": [110, 220], "val": [0.03, 0.07], "fog": [0.01, 0.03], "fog_n": [2, 5],
		"cosmos": 0.30, "cosmos_n": [1, 1], "volumetric": 0.15, "planet": 1.00, "flare": 0.90,
	},
}


## What this scene can be told ([method GhostScene.choice], [method GhostScene.number]): a
## storyboard entry's `set`, by name; a setting not told is drawn from the seed.
const FIELDS := {
	"sky": {"label": "Sky", "type": "choice", "options": "SKIES", "default": null,
		"blurb": "Which part of space the sky shows: the crowded dusty core, an empty deep field, the inside of a nebula, or an orbit close over a world."},
	"fisheye": {"label": "Flare fisheye", "type": "num", "range": [0.12, 0.3], "default": null,
		"blurb": "How strongly the lens flare and its chain of discs bow outward, when there is a flare."},
}


func build_params(rng: RandomNumberGenerator) -> Dictionary:
	render_kind = "canvas"
	framing = "field"
	var sky_name := String(choice("sky", rng))
	var sky: Dictionary = SKIES[sky_name]
	var sch := Scheme.among(sky["moods"], rng)
	var val: Array = sky["val"]
	# Near-black bed with only a faint gradient (no big soft pools); the bright glows are a lens
	# flare out front.
	add_layer("bed", rng, {
		"hue": sch.hue,
		"sat": clampf(sch.sat * rng.randf_range(0.6, 1.0), 0.05, 1.0),
		"val": rng.randf_range(float(val[0]), float(val[1])),
		"pools": 0,
	})
	var fog_a: Array = sky["fog"]
	var fog_n: Array = sky["fog_n"]
	add_layer("fog", rng, {
		"hue": sch.vary(rng),
		"sat": clampf(sch.sat * 0.5, 0.02, 0.6),
		"alpha": rng.randf_range(float(fog_a[0]), float(fog_a[1])),
		"count": rng.randi_range(int(fog_n[0]), int(fog_n[1])),
	})
	# Diffuse depth behind the stars: a distant nebula or galaxy, and drifting harmonic bands of
	# fog (volumetric, fog mode): dust catching light and moving with the music.
	if rng.randf() < float(sky["cosmos"]):
		var cn: Array = sky["cosmos_n"]
		add_layer("cosmos", rng, {"z": "back", "hue": sch.hue_at(1, 3),
			"count": rng.randi_range(int(cn[0]), int(cn[1]))})
	if rng.randf() < float(sky["volumetric"]):
		add_layer("volumetric", rng, {"z": "back", "mode": "fog", "hue": sch.accent})
	# Starlight on the accent, so the stars stay legible against a nebula of the base hue.
	var count := rng.randi_range(int(sky["count"][0]), int(sky["count"][1]))
	add_layer("stars", rng, {"hue": sch.accent, "count": count})
	# A 3D planet in front of the stars (added last, so it occludes them).
	if rng.randf() < float(sky["planet"]):
		add_layer("planet", rng, {"hue": sch.vary(rng, 3.0)})
	# A lens flare over everything (incl. the planet): bright glows pulsing with the harmonics,
	# gently fisheye-bowed. How likely is the sky's business.
	if rng.randf() < float(sky["flare"]):
		add_layer("flare", rng, {"hue": sch.hue_at(1, 3), "fisheye": number("fisheye", rng)})
	return {"hue": sch.hue, "mood": sch.name, "sky": sky_name, "stars": count}


func update(f: AudioFeatures, delta: float) -> void:
	tick(f, delta)
	drift_view(f, 0.015, 0.02)
	update_layers(f, delta)
	queue_redraw()


func _draw() -> void:
	begin_draw()
	draw_layers()
