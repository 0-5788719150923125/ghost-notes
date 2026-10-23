extends GhostScene

## Aurora - slow curtains of light over a starlit night.
##
## Wavy ribbons drift and undulate, each tied to a band of the spectrum so the curtains
## brighten and ripple with the music, hung over a faint starfield and a dark bed. The
## northern-lights corner. `bed` + `stars` + `aurora`, in whichever of the sky's own
## colors the seed draws - and as broad drapes, fine ribbons, or a doubled curtain.

# The curtain's FORM: how many ribbons hang, how saturated they are, and whether a second
# set hangs behind on the accent hue. One display is a couple of slow drapes and another is
# a fine-grained shimmer, so the count is the silhouette here, not a cosmetic constant.
const FORMS := {
	"drapes":  {"count": [2, 3], "sat": [0.55, 0.80], "second": false},
	"ribbons": {"count": [5, 8], "sat": [0.40, 0.62], "second": false},
	"double":  {"count": [3, 5], "sat": [0.48, 0.70], "second": true},
}


## WHAT THIS SCENE CAN BE TOLD ([method GhostScene.choice], [method GhostScene.number]): a storyboard
## entry's `set`, by name; a setting not told is drawn from the seed, as it always was.
const FIELDS := {
	"form": {"label": "Form", "type": "choice", "options": "FORMS", "default": null,
		"blurb": "How the curtain hangs: a couple of slow broad drapes, many fine ribbons, or a doubled curtain with a second set behind on the accent hue."},
	"night": {"label": "Night brightness", "type": "num", "range": [0.05, 0.12], "default": null,
		"blurb": "How bright the dark night sky behind the curtains is."},
	"stars": {"label": "Stars", "type": "num", "range": [60, 220], "default": null,
		"blurb": "How many stars fill the night sky behind the curtains."},
	"back_ribbons": {"label": "Back ribbons", "type": "num", "range": [2, 3], "default": null,
		"blurb": "How many ribbons hang in the second curtain behind, when the curtain is doubled."},
}


func build_params(rng: RandomNumberGenerator) -> Dictionary:
	render_kind = "canvas"
	framing = "field"
	# The moods a real aurora can take: oxygen green through the rarer cyans, violets and
	# the high red fringe. Anything warm-orange would read as fire in the sky, not light.
	var sch := Scheme.among(
		["verdant", "toxic", "teal", "glacier", "violet", "magenta", "abyss", "rose"], rng)
	var form := String(choice("form", rng))
	var f: Dictionary = FORMS[form]
	var cnt: Array = f["count"]
	var sat_r: Array = f["sat"]
	# The night behind either answers the curtain (its accent) or opposes it (the
	# complement) - the same display reads warm-grounded or cold depending which.
	var answered := rng.randf() < 0.5
	var bed_hue: float = sch.accent if answered else fposmod(sch.hue + 0.5, 1.0)
	add_layer("bed", rng, {
		"hue": bed_hue,
		"sat": sch.sat * rng.randf_range(0.5, 0.9),
		"val": number("night", rng),
		"pools": rng.randi_range(2, 4),
	})
	add_layer("stars", rng, {"hue": sch.accent, "count": number("stars", rng)})
	add_layer("aurora", rng, {
		"hue": sch.hue,
		"sat": rng.randf_range(float(sat_r[0]), float(sat_r[1])),
		"count": rng.randi_range(int(cnt[0]), int(cnt[1])),
	})
	if bool(f["second"]):
		# A second, thinner curtain on the accent: the banded two-color display.
		add_layer("aurora", rng, {
			"hue": sch.accent,
			"sat": rng.randf_range(float(sat_r[0]), float(sat_r[1])) * 0.8,
			"count": number("back_ribbons", rng),
		})
	return {"hue": sch.hue, "mood": sch.name, "form": form, "bed": "accent" if answered else "opposed"}


func update(f: AudioFeatures, delta: float) -> void:
	tick(f, delta)
	drift_view(f, 0.015, 0.02)
	update_layers(f, delta)
	queue_redraw()


func _draw() -> void:
	begin_draw()
	draw_layers()
