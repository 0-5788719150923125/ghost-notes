extends GhostScene

## Two prisms - the pair, from the drop through specialization (the-point, scenes 6-11).
##
## The trembling eye bursts into the glowing red [PrismBody] on the beat drop; two prisms then
## face forward, the blue (continued from `eye_prism`) and the red, on a timeline:
##   6  burst      - the red forms in a flash where the eye was; blue keeps living.
##   7  phase-lock - the two snap into sync, red locked to blue's pose, rotating as one.
##   8  scan       - locked, they scan the void in unison.
##   9  desync     - the blue breaks sync and looks around on its own; the red holds steady.
##   10 unlock     - both slip their anchors and sway, weightless, straining and drifting.
##   11 specialize - the blue swells and pulses slowly; the red shrinks and quickens (bias vs.
##                   variance made physical).
##
## Arrives by morph from `eye_prism` (`morph_in = "eye2prism"`): reuses the live blue prism and
## bursts the red at the eye's slot. Hands off to `prism_swarm` (`morph_out = "prisms"`).
##
## The pair takes a [Scheme] mood: the lead on its base hue, the counter on the opposed hue. Both
## ride on the bodies as offsets from [constant HUE_BLUE] / [constant HUE_RED] (the convention
## `eye_prism` established), so a body handed across a morph keeps its color. When one arrives,
## the red is re-derived from the arriving hue, so the pair is one mood's opposition.

## The pair's staging: separation and size together (two big prisms crowded together overlap,
## two small ones far apart lose the relationship). Each entry leaves room for the specialize
## phase, where the lead swells by half again.
const STAGING := {
	"close":  {"off": [0.10, 0.13], "size": [0.10, 0.13]},
	"paired": {"off": [0.14, 0.17], "size": [0.16, 0.20]},
	"apart":  {"off": [0.24, 0.30], "size": [0.20, 0.25]},
}

var _f: AudioFeatures = AudioFeatures.new()
var _blue: PrismBody
var _red: PrismBody
var _bpos := Vector2(0.15, 0.0)     # blue center, unit-fractions from screen center
var _rpos := Vector2(-0.15, 0.0)    # red center
var _banch := Vector2(0.15, 0.0)    # anchors the pair sway around
var _ranch := Vector2(-0.15, 0.0)
var _bscale := 0.18                 # blue draw scale (unit-fraction)
var _rscale := 0.18                 # red draw scale
var _base := 0.18
var _t := 0.0
var _burst := 0.0                   # the red's form-in flash envelope
var _lock := 0.0                    # 0 free .. 1 red phase-locked to blue
var _lockflash := 0.0
var _rspin := 1.0                   # red's own spin scale (damped to 0 when it "holds steady")
var _lead_off := 0.0                # the mood, as an offset from HUE_BLUE, carried on the body
var _sep := -0.6                    # lead -> counter hue distance; survives a morph so the pair stays a pair
var _red_cast := 0.0                # the red body's own small per-instance hue cast
const HUE_BLUE := 0.6
const HUE_RED := 0.0

# Phase thresholds as fractions of the scene's hold (beats 6-11 spread across it), so every event
# lands whatever the hold length.
const FL_LOCK := 0.19      # snap into phase-lock
const FL_DESYNC := 0.50    # blue breaks sync
const FL_UNLOCK := 0.62    # slip anchors and sway
const FL_SPECIAL := 0.80   # specialize
const NOMINAL := 16.0      # design length (used to pace in auto mode, where there is no fixed hold)


## What this scene can be told ([method GhostScene.choice], [method GhostScene.number]): a
## storyboard entry's `set`, by name; a setting not told is drawn from the seed.
const FIELDS := {
	"staging": {"label": "Staging", "type": "choice", "options": "STAGING", "default": null,
		"blurb": "How the pair is staged: small prisms close together, a matched pair, or larger ones set apart."},
	"tilt": {"label": "Tilt", "type": "num", "range": [-0.55, 0.55], "default": null,
		"blurb": "How far the line between the two prisms leans from level."},
}


func build_params(rng: RandomNumberGenerator) -> Dictionary:
	render_kind = "scene3d"        # drawn on the canvas, but a 3D-feeling body; keep the plane framing
	framing = "plane"
	morph_in = "eye2prism"
	morph_out = "prisms"
	_blue = PrismBody.new(rng.randi())
	_red = PrismBody.new(rng.randi())
	# One mood, two roles. `+=` keeps each body's own small cast, so the pair is one color family,
	# not two copies of one hue.
	var sch := Scheme.pick(rng)
	var lead := sch.vary(rng)
	var counter := sch.opposed(lead)
	_sep = wrapf(counter - lead, -0.5, 0.5)
	_lead_off = wrapf(lead - HUE_BLUE, -0.5, 0.5)
	_red_cast = _red.hue_shift
	_blue.hue_shift += _lead_off
	_red.hue_shift += wrapf(counter - HUE_RED, -0.5, 0.5)
	var stage := String(choice("staging", rng))
	var st: Dictionary = STAGING[stage]
	var size_band: Array = st["size"]
	var off_band: Array = st["off"]
	_base = rng.randf_range(float(size_band[0]), float(size_band[1]))
	_bscale = _base
	_rscale = _base
	var off := rng.randf_range(float(off_band[0]), float(off_band[1]))
	# The pair's axis, not just its gap: a leaning pair re-composes the whole frame.
	var tilt: float = number("tilt", rng)
	var axis := Vector2(cos(tilt), sin(tilt))
	_banch = axis * off
	_ranch = -axis * off
	_bpos = _banch
	_rpos = _ranch
	_t = 0.0
	return {"mood": sch.name, "staging": stage, "lead": lead, "counter": counter,
		"tilt": tilt, "offset": off, "size": _base, "forms": [_blue.form, _red.form]}


# The prism family's second hue: the mood's own accent, never closer to the lead than
# Scheme.opposed allows. Moods whose accent sits within a few hundredths of the base are pushed
# out along the direction the mood chose (verdant still turns amber, glacier violet), or the two
# prisms would stop reading as an opposition. Measured against the drifted lead, since `vary`
# moves it.


# Arrived from eye_prism: keep the live blue prism, and burst the red in at the eye's slot.
func begin_morph(from: GhostScene) -> void:
	var p := from.morph_payload()
	if p.is_empty():
		return
	if p.has("blue"):
		_blue = p["blue"]
		# The arriving body carries the mood the eye crystallized into: re-derive the red from that
		# hue at the separation this build rolled, so the morph lands one mood's opposition.
		_lead_off = _blue.hue_shift
		var lead := fposmod(HUE_BLUE + _lead_off, 1.0)
		_red.hue_shift = _red_cast + wrapf(fposmod(lead + _sep, 1.0) - HUE_RED, -0.5, 0.5)
	_banch = p.get("blue_slot", _banch)
	_ranch = p.get("eye_slot", _ranch)
	_bpos = _banch
	_rpos = _ranch
	_base = float(p.get("scale", _base))
	_bscale = _base
	_rscale = _base
	_t = 0.0
	_burst = 1.0                     # the drop: the red bursts into being


func morph_payload() -> Dictionary:
	return {"blue": _blue, "red": _red, "blue_pos": _bpos, "red_pos": _rpos,
		"blue_scale": _bscale, "red_scale": _rscale}


func update(f: AudioFeatures, delta: float) -> void:
	_f = f
	last_f = f
	tick(f, delta)
	drift_view(f, 0.006, 0.012)
	_t += delta
	var drive := clampf(f.energy * 0.85 + f.beat * 0.6, 0.0, 1.0)
	_burst = maxf(0.0, _burst - delta * 2.2)
	# Keyframe phases run on the fraction of the hold elapsed; the bodies' spin and pulse run on
	# the raw delta and never speed up with the tempo.
	var f2 := clampf(_t / phase_span(NOMINAL), 0.0, 1.0)

	# Phase-lock: ease _lock up around FL_LOCK, with a snap-flash on the crossover. While locked,
	# the red mirrors the blue's pose exactly.
	var lock_t := smoothstep(FL_LOCK - 0.04, FL_LOCK + 0.03, f2)
	if f2 < FL_DESYNC:
		if _lock < 0.5 and lock_t >= 0.5:
			_lockflash = 1.0
		_lock = lock_t
	else:
		_lock = maxf(0.0, _lock - delta * 3.0)     # blue breaks sync at FL_DESYNC
	_lockflash = maxf(0.0, _lockflash - delta * 2.6)

	# When the blue desyncs, the red holds steady: its own spin damps to zero.
	var want_rspin := 1.0 if f2 < FL_DESYNC else 0.0
	_rspin = lerpf(_rspin, want_rspin, 1.0 - exp(-4.0 * delta))
	_red._vel *= (0.02 + 0.98 * _rspin) if f2 >= FL_DESYNC else 1.0

	# Specialize: blue swells and slows, red shrinks and quickens. Time-scales change each body's
	# whole tempo, so they diverge in character, not just size.
	var sp := smoothstep(FL_SPECIAL, FL_SPECIAL + 0.15, f2)
	var b_speed := lerpf(1.0, 0.55, sp)
	var r_speed := lerpf(1.0, 1.8, sp)
	var b_size := lerpf(_base, _base * 1.55, sp) * (1.0 + 0.12 * sp * sin(_t * 1.2))   # slow pulse
	var r_size := lerpf(_base, _base * 0.6, sp) * (1.0 + 0.06 * sp * sin(_t * 6.5))    # quick flutter
	_bscale = lerpf(_bscale, b_size, 1.0 - exp(-5.0 * delta))
	_rscale = lerpf(_rscale, r_size, 1.0 - exp(-5.0 * delta))

	# Unlock + sway: past FL_UNLOCK the pair slips its anchors and drifts weightlessly against
	# them (a gentle spring back, with an audio-driven wander on top).
	var sway := smoothstep(FL_UNLOCK, FL_UNLOCK + 0.09, f2)
	var bw := Vector2(sin(_t * 0.7 + 0.0), cos(_t * 0.9 + 1.0)) * (0.05 * sway * (0.5 + drive))
	var rw := Vector2(sin(_t * 0.8 + 2.1), cos(_t * 0.6 + 3.0)) * (0.05 * sway * (0.5 + drive))
	var follow := 1.0 - exp(-3.0 * delta)
	_bpos = _bpos.lerp(_banch + bw, follow)
	_rpos = _rpos.lerp(_ranch + rw, follow)

	_blue.update(delta * b_speed, clampf(drive * (0.6 + 0.4 * (1.0 - _lock)), 0.0, 1.0))
	# The red drives on its own energy; while locked its pose is overwritten to the blue's.
	_red.update(delta * r_speed, clampf(drive, 0.0, 1.0))
	if _lock > 0.5:
		_red.lock_pose_to(_blue)
	queue_redraw()


func _draw() -> void:
	begin_draw()
	var u := unit()
	var bc := _bpos * u
	var rc := _rpos * u
	# The red bursts into being where the eye was: a bright flash in the counter's own color.
	if _burst > 0.001:
		var fc := Color.from_hsv(fposmod(HUE_RED + _red.hue_shift, 1.0), 0.5, 1.0)
		draw_circle(rc, _rscale * u * (0.6 + 1.6 * _burst), Color(fc.r, fc.g, fc.b, 0.5 * _burst))
		draw_circle(rc, _rscale * u * (0.3 + 0.7 * _burst), Color(1, 1, 1, 0.6 * _burst))
	_blue.draw(self, bc, _bscale * u, HUE_BLUE, 1.0)
	_red.draw(self, rc, _rscale * u, HUE_RED, clampf(1.0 - _burst * 0.5, 0.0, 1.0))
	# The phase-lock snap: a brief bright tie between the two centers as they sync.
	if _lockflash > 0.001:
		var mid := (bc + rc) * 0.5
		draw_line(bc, rc, Color(1, 1, 1, 0.5 * _lockflash), 2.0, true)
		draw_circle(mid, u * 0.02 * _lockflash, Color(1, 1, 1, 0.7 * _lockflash))
