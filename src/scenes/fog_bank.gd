extends GhostScene

## Fog bank - rolling colored fog, light glowing from within.
##
## The explicit "rolling fog with colors underneath / inside" idea: a rich color bed
## with slow pools breathing on the spectrum, then several fog layers of different tint
## and speed rolling over and through it, so the color bleeds up through the cloud. The
## bank lurches on the beat and coasts down (velocity + decay, not a uniform drift).
## `bed` + stacked `fog` layers - atmosphere from pure composition.

# How heavy the bank is. A thin one barely veils the color and a deep one buries it in
# sheets, which is the difference between a glow with mist over it and weather - so the
# sheet count, their opacity and the bed's brightness all move together.
const BANKS := {
	"thin":    {"sheets": [1, 1], "alpha": [0.020, 0.035], "count": [4, 6],  "val": [0.46, 0.60]},
	"rolling": {"sheets": [2, 3], "alpha": [0.030, 0.050], "count": [5, 8],  "val": [0.38, 0.54]},
	"deep":    {"sheets": [3, 4], "alpha": [0.040, 0.070], "count": [6, 10], "val": [0.28, 0.44]},
}


## WHAT THIS SCENE CAN BE TOLD ([method GhostScene.choice], [method GhostScene.number]): a storyboard
## entry's `set`, by name; a setting not told is drawn from the seed, as it always was.
const FIELDS := {
	"bank": {"label": "Bank", "type": "choice", "options": "BANKS", "default": null,
		"blurb": "How heavy the fog bank is: a thin veil, a rolling bank, or a deep one that buries the color in sheets."},
	"pools": {"label": "Color pools", "type": "num", "range": [3, 7], "default": null,
		"blurb": "How many soft pools of color breathe under the fog."},
}


func build_params(rng: RandomNumberGenerator) -> Dictionary:
	render_kind = "canvas"
	framing = "field"
	# Any mood is fair here: the bank is the constant, the color under it is the variable.
	var sch := Scheme.pick(rng)
	var bank := String(choice("bank", rng))
	var b: Dictionary = BANKS[bank]
	var val_r: Array = b["val"]
	var alpha_r: Array = b["alpha"]
	var cnt_r: Array = b["count"]
	var sheet_r: Array = b["sheets"]
	# A bright, saturated bed so the color reads strongly *through* the fog above it.
	add_layer("bed", rng, {
		"hue": sch.hue,
		"sat": clampf(sch.sat * rng.randf_range(0.85, 1.2), 0.05, 1.0),
		"val": rng.randf_range(float(val_r[0]), float(val_r[1])),
		"pools": number("pools", rng),
	})
	var sheets := rng.randi_range(int(sheet_r[0]), int(sheet_r[1]))
	for i in sheets:
		# The stack walks from the base hue toward the accent, so a pile of sheets is one
		# family of tints rather than an arbitrary offset invented per sheet.
		var tint: float = sch.hue_at(i + 1, sheets + 1)
		add_layer("fog", rng, {
			"hue": tint,
			"sat": clampf(sch.sat * rng.randf_range(0.2, 0.5), 0.03, 0.6),
			"alpha": rng.randf_range(float(alpha_r[0]), float(alpha_r[1])),
			"count": rng.randi_range(int(cnt_r[0]), int(cnt_r[1])),
		})
	return {"hue": sch.hue, "mood": sch.name, "bank": bank, "sheets": sheets}


func update(f: AudioFeatures, delta: float) -> void:
	tick(f, delta)
	drift_view(f, 0.02, 0.03)
	update_layers(f, delta)
	queue_redraw()


func _draw() -> void:
	begin_draw()
	draw_layers()
