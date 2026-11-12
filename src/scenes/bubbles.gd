extends GhostScene

## Bubbles - an underwater drift of rising bubbles in colored depths.
##
## Bubbles wobble upward with rim highlights, fine particles hang in the water, and a bed with slow color
## pools suggests light filtering down. The water's color comes from a [Scheme] and its character from a
## column below. `bed` (+ `surface`) + `kelp` + `dust` + `bubbles`.

# Water columns: a column is a whole regime - how hard the vents work, how fast the gas climbs, how much
# matter is suspended, what grows there, and whether any surface light reaches this deep.
const COLUMNS := [
	{"name": "spring", "bubbles": [90, 140], "rise": [0.11, 0.17], "dust": [110, 170],
	 "form": "grass", "fronds": [14, 24], "glows": [1, 3], "bed_v": 0.34, "lit": true},
	{"name": "seep", "bubbles": [40, 70], "rise": [0.06, 0.10], "dust": [60, 110],
	 "form": "kelp", "fronds": [10, 18], "glows": [2, 4], "bed_v": 0.28, "lit": true},
	{"name": "trench", "bubbles": [14, 30], "rise": [0.035, 0.065], "dust": [30, 70],
	 "form": "whip", "fronds": [5, 11], "glows": [4, 7], "bed_v": 0.15, "lit": false},
	{"name": "garden", "bubbles": [50, 90], "rise": [0.07, 0.12], "dust": [70, 130],
	 "form": "fan", "fronds": [18, 30], "glows": [1, 3], "bed_v": 0.30, "lit": true},
	{"name": "silt", "bubbles": [30, 60], "rise": [0.05, 0.09], "dust": [160, 240],
	 "form": "bulb", "fronds": [8, 16], "glows": [1, 2], "bed_v": 0.21, "lit": false},
]


## What this scene can be told ([method GhostScene.number]): a storyboard entry's `set`, by name;
## a setting not told is drawn from the seed.
const FIELDS := {
	"caustics": {"label": "Caustics", "type": "num", "range": [5, 11], "default": null,
		"blurb": "How many wavy bands of light from the surface shimmer across the water."},
	"sun": {"label": "Sun position", "type": "num", "range": [-0.4, 0.4], "default": null,
		"blurb": "Where the distant sun glows across the top of the water, from left to right."},
	"beam": {"label": "Beam position", "type": "num", "range": [-0.3, 0.3], "default": null,
		"blurb": "Where the beam of light through the suspended particles falls across the frame."},
	"drift": {"label": "Particle drift", "type": "num", "range": [0.002, 0.008], "default": null,
		"blurb": "How fast the suspended particles drift sideways through the water."},
}


func build_params(rng: RandomNumberGenerator) -> Dictionary:
	render_kind = "canvas"
	framing = "field"
	# Water is not always teal (mineral springs run green, deep water indigo, a still pool nearly
	# colorless), but never a warm hue, which would read as air.
	var sch := Scheme.among(["teal", "glacier", "abyss", "verdant", "toxic", "violet", "ash"], rng)
	var col: Dictionary = COLUMNS[rng.randi() % COLUMNS.size()]
	add_layer("bed", rng, {"hue": sch.hue, "sat": sch.sat * 0.9,
		"val": sch.val * float(col["bed_v"]), "pools": rng.randi_range(2, 4)})
	# Light pouring down from the surface (with caustics), only where any reaches.
	if bool(col["lit"]):
		add_layer("surface", rng, {"hue": sch.accent, "caustics": number("caustics", rng),
			"sun_x": number("sun", rng)})
	add_layer("kelp", rng, {"hue": sch.vary(rng), "form": String(col["form"]),
		"fronds": rng.randi_range(int(col["fronds"][0]), int(col["fronds"][1])),
		"glows": rng.randi_range(int(col["glows"][0]), int(col["glows"][1]))})
	add_layer("dust", rng, {"hue": sch.vary(rng), "shaft": bool(col["lit"]),
		"count": rng.randi_range(int(col["dust"][0]), int(col["dust"][1])),
		"shaft_x": number("beam", rng), "drift": number("drift", rng)})
	add_layer("bubbles", rng, {
		"hue": sch.vary(rng, 0.5),
		"count": rng.randi_range(int(col["bubbles"][0]), int(col["bubbles"][1])),
		"rise": rng.randf_range(float(col["rise"][0]), float(col["rise"][1])),
	})
	return {"hue": sch.hue, "mood": sch.name, "column": String(col["name"])}


func update(f: AudioFeatures, delta: float) -> void:
	tick(f, delta)
	drift_view(f, 0.02, 0.03)
	update_layers(f, delta)
	queue_redraw()


func _draw() -> void:
	begin_draw()
	draw_layers()
