extends GhostScene

## Strata - stacked waveform planes receding into depth.
##
## Horizontal planes are stacked back-to-front; each is a waveform whose height comes from a
## slice of the spectrum plus a traveling sine, filled down to the foot of the frame as a
## translucent sheet. Nearer planes sit over farther ones and the view's tilt skews the stack, so
## it reads as planes of light in space. Far planes scroll slower than near ones (parallax).
##
## By seed the stack is a few big slabs or a deep receding pile ([constant STACKS]), each
## plane's edge follows one of three laws ([constant PROFILES]) - swells, ridgelines or stepped
## terraces - and one [Scheme] colors it, depth carrying the palette from base hue to accent.

const OVER := 1.4
const COLS := 72       # samples across each plane

## The law each plane's edge follows: it decides whether the stack reads as swells, ridges or
## terraces.
const PROFILES := ["smooth", "ridge", "terrace"]

## How many planes, and how thick they sit: few read as big slabs of light, many as a dense stack.
const STACKS := {
	"slabs": {"planes": [3, 5], "amp": [0.10, 0.22], "alpha": [0.30, 0.62]},
	"stack": {"planes": [5, 9], "amp": [0.06, 0.13], "alpha": [0.35, 0.55]},
	"deep": {"planes": [10, 17], "amp": [0.04, 0.09], "alpha": [0.22, 0.42]},
}

var _f: AudioFeatures = AudioFeatures.new()
var _t := 0.0
## One batch for the band fills (see the note in _draw: they are strips).
var _tb := TriBatch.new()


## What this scene can be told ([method GhostScene.choice], [method GhostScene.number]): a
## storyboard entry's `set`, by name; a setting not told is drawn from the seed.
const FIELDS := {
	"stack": {"label": "Stack", "type": "choice", "options": "STACKS", "default": null,
		"blurb": "How many planes and how thick they sit: a few big slabs, a stack, or a deep stack receding."},
	"profile": {"label": "Profile", "type": "choice", "options": "PROFILES", "default": null,
		"blurb": "The line each plane's edge follows: smooth swells, ridges or terraces."},
	"terraces": {"label": "Terraces", "type": "num", "range": [4, 11], "default": null,
		"blurb": "How many treads a terraced edge steps through, when the profile is terraces."},
	"waves": {"label": "Waves", "type": "num", "range": [1.0, 5.5], "default": null,
		"blurb": "How many swells run across each plane's edge."},
	"scroll": {"label": "Scroll speed", "type": "num", "range": [0.15, 0.45], "default": null,
		"blurb": "How fast the planes' edges slide sideways."},
}


func build_params(rng: RandomNumberGenerator) -> Dictionary:
	framing = "field"
	# Planes of light are abstract: take the whole mood set.
	var sch := Scheme.pick(rng)
	var kname := String(choice("stack", rng))
	var st: Dictionary = STACKS[kname]
	var pl: Array = st["planes"]
	var am: Array = st["amp"]
	var al: Array = st["alpha"]
	# Depth carries the palette from the scheme's base to its accent.
	var to_accent := fposmod(sch.accent - sch.hue + 0.5, 1.0) - 0.5
	return {
		"planes": rng.randi_range(int(pl[0]), int(pl[1])),
		"stack": kname,
		"mood": sch.name,
		"profile": String(choice("profile", rng)),
		"steps": number("terraces", rng),        # terrace profile: how many treads
		"hue": sch.hue,
		"hue_span": to_accent * rng.randf_range(0.5, 1.3),
		"sat": sch.sat,
		"val": 0.75 + 0.30 * sch.val,           # the mood's brightness character
		"wave_k": number("waves", rng),    # spatial frequency across x
		"amp": rng.randf_range(float(am[0]), float(am[1])),   # crest height, fraction of unit
		"scroll": number("scroll", rng),
		"alpha": rng.randf_range(float(al[0]), float(al[1])),
	}


func update(f: AudioFeatures, delta: float) -> void:
	_f = f
	tick(f, delta)
	# Tilt-forward bias so the stack reads as receding planes. An absolute skew target (the view
	# eases toward it): set it, never accumulate with `+=`, which shears the whole stack.
	drift_view(f, 0.03, 0.04, 0.04, 0.08)
	view.skew = 0.18 + 0.05 * mod.value("tilt2")
	_t += delta * float(params.scroll)
	queue_redraw()


func _draw() -> void:
	begin_draw()
	var planes := maxi(2, int(params.planes))
	var foot := size.y * OVER * 0.5
	var hue: float = params.hue
	var hue_span: float = params.hue_span
	var alpha: float = params.alpha
	var sat: float = params.sat
	var val_mul: float = params.val

	# Far (top) to near (bottom): later draws cover earlier -> depth ordering.
	for i in planes:
		var depth := float(i) / float(planes - 1)        # 0 far .. 1 near
		var loud := _f.sample(1.0 - depth)               # bass near, treble far

		var tops := band_points(i)

		var h := fposmod(hue + hue_span * depth, 1.0)
		var fill := Color.from_hsv(h, clampf(sat * 0.85, 0.0, 1.0),
			clampf((0.25 + 0.6 * (0.3 + loud) * (0.4 + depth)) * val_mul, 0.0, 1.0), alpha)
		# Filled as an explicit strip, one quad per column, not as one closed polygon: the engine
		# ear-clips a polygon and cannot triangulate zero-area ears, and the `ridge` profile
		# produces exactly-collinear runs (straight flanks plus the crest clamp's plateaus), so
		# a band could fail to triangulate and vanish for that frame. A band is x-monotone, so
		# column c and c+1 with their two feet make a quad and the band goes down in one batched
		# draw call ([TriBatch]).
		for c in COLS - 1:
			_tb.quad(tops[c], tops[c + 1],
				Vector2(tops[c + 1].x, foot), Vector2(tops[c].x, foot), fill)
		# Flushed per band: the crest line below must land over its own fill and under the next
		# plane's (painter's order).
		_tb.flush(self)

		# A brighter crest line for definition.
		var lcol := Color.from_hsv(h, clampf(sat * 0.55, 0.0, 1.0),
			clampf((0.7 + 0.3 * loud) * val_mul, 0.0, 1.0), 0.7)
		draw_polyline(tops, lcol, 1.5 + 2.0 * depth, true)


## The crest of plane [param i]: the band's top edge, sampled across the frame in this scene's own
## draw space, from the plane's spectrum slice and the scrolling profile. Split out of
## [method _draw] so tests/scenes/strata_band_check.gd gets the geometry the scene actually draws.
func band_points(i: int) -> PackedVector2Array:
	var field := size * OVER
	var planes := maxi(2, int(params.planes))
	var step := field.y / float(planes)
	var top := -field.y * 0.5
	var left := -field.x * 0.5
	var foot := field.y * 0.5
	var depth := float(i) / float(planes - 1)            # 0 far .. 1 near
	var base_y := top + (float(i) + 0.5) * step
	var loud := _f.sample(1.0 - depth)
	var phase := _t * (0.4 + 0.6 * depth)                # parallax: near scrolls faster
	var crest := unit() * float(params.amp) * (0.4 + 1.4 * loud + 0.3 * _f.beat)
	var profile: String = params.profile
	var steps: int = params.steps
	var wave_k: float = params.wave_k
	var out := PackedVector2Array()
	out.resize(COLS)
	for c in COLS:
		var fx := float(c) / float(COLS - 1)
		var x := left + fx * field.x
		var wave := _shape(profile, wave_k * fx + phase / TAU, steps) * 0.6 \
			+ 0.4 * (_f.sample(fx) - 0.5) * 2.0
		# Keep every crest above the closing edge, so no column's quad folds over.
		out[c] = Vector2(x, minf(base_y - wave * crest, foot - 1.0))
	return out


## The same band as one closed polygon (the shape the engine's triangulator can refuse), kept so
## the gate can demonstrate it. Nothing draws this.
func band_polygon(i: int) -> PackedVector2Array:
	var tops := band_points(i)
	var foot := size.y * OVER * 0.5
	var out := tops.duplicate()
	out.append(Vector2(tops[tops.size() - 1].x, foot))
	out.append(Vector2(tops[0].x, foot))
	return out


## The crest law, in [-1, 1], as a function of position along the plane (`s` is in whole cycles).
## Only the shape of the edge differs.
func _shape(profile: String, s: float, steps: int) -> float:
	match profile:
		"ridge":
			# A triangle wave: hard peaks and straight flanks, ridgelines not swells.
			return 4.0 * absf(s - floor(s) - 0.5) - 1.0
		"terrace":
			# Quantized into treads, so each plane is a stepped bench of light.
			return round(sin(s * TAU) * float(steps)) / float(steps)
		_:
			return sin(s * TAU)
