extends GhostScene

## Fire - a living flame attuned to the harmonics.
##
## One GPU temperature field (see [Layer.Fire] / shaders/flame.gdshader): heat sources along the bed, each
## listening to its own harmonic band (bass at the center, treble at the rim), raise columns that rising
## turbulence carves into licks. CPU sparks crackle out of whichever region is roaring, and smoke sometimes
## hazes the top. Quiet passages sit as embers; powerful ones send columns up the frame.
##
## The flame's colors are the shader's (the temperature of its fuel), so the seed varies the hearth around
## it: the ambient, how wide it is laid, and how much smoke it throws.

# The hearth: each is a place a fire is found, and decides the ambient wash behind the flame, how far the
# sources are laid across the frame and how heavily it smokes.
const HEARTHS := {
	"forge":   {"moods": ["ember", "sodium", "brass"], "spread": [0.45, 0.75],
		"val": [0.07, 0.11], "smoke": 0.35, "sheets": [1, 1]},
	"bonfire": {"moods": ["ember", "dawn", "rose", "sodium"], "spread": [0.85, 1.15],
		"val": [0.05, 0.09], "smoke": 0.60, "sheets": [1, 2]},
	"night":   {"moods": ["abyss", "violet", "ash", "teal"], "spread": [0.70, 1.05],
		"val": [0.03, 0.07], "smoke": 0.70, "sheets": [1, 2]},
}


## What this scene can be told ([method GhostScene.choice], [method GhostScene.number]): a storyboard
## entry's `set`, by name; a setting not told is drawn from the seed.
const FIELDS := {
	"hearth": {"label": "Hearth", "type": "choice", "options": "HEARTHS", "default": null,
		"blurb": "Where the fire is found: a forge, a bonfire, or a fire on a cold night, which sets the wash behind the flame, how widely the flames are laid and how heavily it smokes."},
	"sparks": {"label": "Sparks", "type": "num", "range": [50, 160], "default": null,
		"blurb": "How many sparks the fire can throw into the air at once."},
}


func build_params(rng: RandomNumberGenerator) -> Dictionary:
	render_kind = "canvas"
	framing = "field"
	var hearth := String(choice("hearth", rng))
	var h: Dictionary = HEARTHS[hearth]
	var sch := Scheme.among(h["moods"], rng)
	var val_r: Array = h["val"]
	var spread_r: Array = h["spread"]
	add_layer("bed", rng, {
		"hue": sch.hue,
		"sat": clampf(sch.sat * rng.randf_range(0.6, 1.0), 0.05, 1.0),
		"val": rng.randf_range(float(val_r[0]), float(val_r[1])),
		"pools": rng.randi_range(1, 4),
	})
	# No hue is passed to the flame: its palette is the temperature ramp in flame.gdshader.
	add_layer("fire", rng, {
		"count": number("sparks", rng),                       # the SPARK pool (born from heat)
		"spread": rng.randf_range(float(spread_r[0]), float(spread_r[1])),
	})
	# Smoke drifting off the top, sometimes, on the mood's accent.
	if rng.randf() < float(h["smoke"]):
		var sheets: Array = h["sheets"]
		for i in rng.randi_range(int(sheets[0]), int(sheets[1])):
			add_layer("fog", rng, {
				"hue": sch.hue_at(i + 1, 3),
				"sat": clampf(sch.sat * rng.randf_range(0.15, 0.4), 0.02, 0.5),
				"alpha": rng.randf_range(0.02, 0.045),
				"count": rng.randi_range(3, 8),
			})
	return {"hue": sch.hue, "mood": sch.name, "hearth": hearth}


func update(f: AudioFeatures, delta: float) -> void:
	tick(f, delta)
	drift_view(f, 0.015, 0.02)
	update_layers(f, delta)
	queue_redraw()


func _draw() -> void:
	begin_draw()
	draw_layers()
