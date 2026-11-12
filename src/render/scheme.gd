extends RefCounted
class_name Scheme

## Scheme - a scene's color identity, drawn from a named mood.
##
## The companion to [Palette]: a Palette is a ramp sampled by a scalar (elevation to color), while a Scheme is a
## small set of related hues a scene builds its whole look from, so one scene can be seeded to different colors.
##
## A mood carries a base hue, a related accent, how far individual elements may drift from the base, and the
## saturation/value character that makes the mood read as itself ("ash" is desaturated, dark and narrow). Scenes
## ask for a mood and then ask it for colors, so adding a mood varies every scene that uses one.
##
## Relationships are named rather than random, because random hue pairs clash: `accent` is chosen per mood as a
## complement, a near-neighbor or a triad partner, so base + accent is harmonious by construction.

# hue, accent, spread, sat, val
const MOODS := {
	"dawn":      {"hue": 0.06, "accent": 0.11, "spread": 0.05, "sat": 0.72, "val": 0.92},
	"ember":     {"hue": 0.02, "accent": 0.09, "spread": 0.04, "sat": 0.85, "val": 0.85},
	"sodium":    {"hue": 0.09, "accent": 0.05, "spread": 0.03, "sat": 0.80, "val": 0.95},
	"brass":     {"hue": 0.11, "accent": 0.55, "spread": 0.05, "sat": 0.62, "val": 0.88},
	"verdant":   {"hue": 0.33, "accent": 0.16, "spread": 0.07, "sat": 0.58, "val": 0.78},
	"teal":      {"hue": 0.47, "accent": 0.08, "spread": 0.05, "sat": 0.60, "val": 0.82},
	"glacier":   {"hue": 0.55, "accent": 0.60, "spread": 0.05, "sat": 0.42, "val": 0.95},
	"abyss":     {"hue": 0.62, "accent": 0.50, "spread": 0.05, "sat": 0.70, "val": 0.55},
	"violet":    {"hue": 0.74, "accent": 0.90, "spread": 0.06, "sat": 0.58, "val": 0.80},
	"magenta":   {"hue": 0.90, "accent": 0.45, "spread": 0.05, "sat": 0.70, "val": 0.88},
	"ash":       {"hue": 0.60, "accent": 0.08, "spread": 0.03, "sat": 0.12, "val": 0.62},
	"bone":      {"hue": 0.10, "accent": 0.58, "spread": 0.03, "sat": 0.16, "val": 0.92},
	"toxic":     {"hue": 0.22, "accent": 0.78, "spread": 0.06, "sat": 0.85, "val": 0.92},
	"rose":      {"hue": 0.95, "accent": 0.12, "spread": 0.04, "sat": 0.45, "val": 0.90},
}

var name := "dawn"
var hue := 0.06        # the base
var accent := 0.11     # a harmonious second hue, per mood
var spread := 0.05     # how far individual elements may drift from the base
var sat := 0.7
var val := 0.9


## Each voice lights in colors of its own: the reading's first voice in the whole rainbow, and every voice after
## it, in the order they first speak, in a band of hues [from, to] (crossed the way listed, e.g. red through purple
## to blue), swept there and back by the same flowing phase. Past the last band they come round again.
const VOICE_BANDS := [[1.0, 0.62], [0.36, 0.14], [0.44, 0.58]]


## The hue a glyph lights in, for [param phase] (any real; the flow along the text and over time):
## the phase itself on the whole wheel for the reading's first voice ([param order] 0), otherwise
## swept across that voice's band and back, eased at both ends so the band never jumps.
static func voice_hue(phase: float, order: int) -> float:
	if order <= 0:
		return fposmod(phase, 1.0)
	var band: Array = VOICE_BANDS[(order - 1) % VOICE_BANDS.size()]
	return fposmod(lerpf(float(band[0]), float(band[1]), 0.5 - 0.5 * cos(TAU * phase)), 1.0)


## Pick a mood at random; deterministic for a given rng.
static func pick(rng: RandomNumberGenerator) -> Scheme:
	var keys := MOODS.keys()
	return of(String(keys[rng.randi() % keys.size()]), rng)


## Pick from a named subset, for scenes where only some moods make sense. Falls back to the full set if none match.
static func among(names: Array, rng: RandomNumberGenerator) -> Scheme:
	var valid: Array = []
	for n in names:
		if MOODS.has(String(n)):
			valid.append(String(n))
	if valid.is_empty():
		return pick(rng)
	return of(String(valid[rng.randi() % valid.size()]), rng)


static func of(mood: String, rng: RandomNumberGenerator) -> Scheme:
	var s := Scheme.new()
	var m: Dictionary = MOODS.get(mood, MOODS["dawn"])
	s.name = mood
	# a small jitter so two scenes on the same mood are not identical twins
	s.hue = fposmod(float(m["hue"]) + rng.randf_range(-0.02, 0.02), 1.0)
	s.accent = fposmod(float(m["accent"]) + rng.randf_range(-0.02, 0.02), 1.0)
	s.spread = float(m["spread"])
	s.sat = float(m["sat"])
	s.val = float(m["val"])
	return s


## The base hue, drifted by up to `spread`: per-element variation within one scene.
func vary(rng: RandomNumberGenerator, amount := 1.0) -> float:
	return fposmod(hue + rng.randf_range(-spread, spread) * amount, 1.0)


## A hue by index: 0 base, 1 accent, beyond that evenly spaced between the two.
func hue_at(i: int, n := 2) -> float:
	if i <= 0:
		return hue
	if n <= 2:
		return accent          # only two hues asked for: base and accent
	if i >= n - 1:
		return accent          # the last of a series IS the accent
	var d := fposmod(accent - hue + 0.5, 1.0) - 0.5      # shortest way round
	return fposmod(hue + d * float(i) / float(n - 1), 1.0)


## A color on this scheme. `s_mul`/`v_mul` scale the mood's own saturation and value character.
func color(h: float, s_mul := 1.0, v_mul := 1.0, a := 1.0) -> Color:
	return Color.from_hsv(fposmod(h, 1.0), clampf(sat * s_mul, 0.0, 1.0),
		clampf(val * v_mul, 0.0, 1.0), a)


## The base color, and the accent color. The two calls a scene makes most.
func base(s_mul := 1.0, v_mul := 1.0, a := 1.0) -> Color:
	return color(hue, s_mul, v_mul, a)


func accent_color(s_mul := 1.0, v_mul := 1.0, a := 1.0) -> Color:
	return color(accent, s_mul, v_mul, a)


## A second hue guaranteed to read as different from `lead`.
##
## The accent alone can be too close to the base (sodium's sits 0.04 away) and `lead` is usually a drifted base. The
## mood's own accent is preferred and pushed out to `min_sep` only when too close, along the direction the mood
## already leans (verdant opens toward amber, glacier toward violet). Callers that stack further per-element
## variation on top should ask for more separation than they need.
func opposed(lead: float, min_sep := 0.24) -> float:
	var d := fposmod(accent - lead + 0.5, 1.0) - 0.5      # signed, shortest way round
	if absf(d) >= min_sep:
		return accent
	return fposmod(lead + (min_sep if d >= 0.0 else -min_sep), 1.0)
