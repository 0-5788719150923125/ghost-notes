extends GhostScene

## Glyphs - an invented script, written live, one stroke at a time.
##
## A page of writing in a language that does not exist. [GlyphSet] rolls the alphabet; this scene is the pen
## and the page: a nib crosses the paper, ink arrives behind it stroke by stroke, words group, lines fill,
## the page scrolls, and when the music goes quiet the pen stops mid-stroke.
##
## The music decides the text. The next character is the argmax of the twelve chroma channels of
## [method Spectrum.harmonic_signature], crossed with the low/mid/high tilt, through a seeded permutation, so
## a recurring chord in the same register writes the same character. Characters commit subdivided by a
## sampled [1,4] beats each, and the reveal is paced across [member AudioFeatures.beat_period]. Word breaks
## land where [member AudioFeatures.movement] crosses a sampled threshold. [member AudioFeatures.flux]
## presses the nib (up to a sampled 35% extra weight, the only thing that tracks amplitude); tonality
## (`chroma_hue().y`) raises ink saturation and warms the paper. Below [member Director.silence_floor]
## (0.03) the reveal does not advance: the pen stops with the nib down.
##
## The seed decides, beyond the hand: the layout (page, column, a centered banner that recenters as each
## line grows, or a spiral written outward and drawn back toward its center), margins, line height, beats per
## character, word-break strength, ruled paper, how much is already written, and the ground.
##
## Cost: one draw call. Each character's geometry is baked once in em space, so a frame is one native
## `Transform2D * PackedVector2Array` per character plus three `append_array`s; stroke quads carry their
## antialiasing in a 1-D alpha ramp texture. [constant MAX_GLYPHS] = 300 is the page budget (about 4.5k
## quads); a finer hand on a wider frame is scaled up until it fits.
##
## The alphabet, hand, layout and opening reproduce exactly; the written text does not (live and offline
## feature streams differ). No rng is drawn on an audio-conditioned event.

## Characters the page may hold at once - the flush budget (see the header).
const MAX_GLYPHS := 300

## Layouts, weighted: a page is the default, the others are the same writing in a different measure.
const LAYOUTS := ["page", "page", "page", "column", "banner", "spiral"]

var _gs: GlyphSet
var _sch: Scheme
var _sim := SimClock.new(60.0)
var _prng := RandomNumberGenerator.new()
var _f: AudioFeatures = AudioFeatures.new()
var _sig := PackedFloat32Array()
var _ch := Vector2.ZERO

# The page: finished characters, plus the one under the nib.
var _placed: Array = []
var _cur: Dictionary = {}
var _reveal := 0.0
var _hold := 0.0                  # the pen's rest before the next character (seconds)
var _written := 0                 # characters the cursor has stepped past, ever
var _words := 0
var _pending_word := false
var _cur_mark := false
var _joined_now := false
var _mv_prev := 0.0
# The music's current 36-wide harmonic key (see GlyphSet.key) and the characters written under it; a
# held key walks the alphabet on rather than repeating one shape.
var _key := -1
var _run := 0

# The layout cursor.
var _cx := 0.0
var _cy := 0.0
var _line := 0
var _shifts: Dictionary = {}      # finished line -> its frozen centering shift
var _shift_cur := 0.0
var _scroll := 0.0
var _scroll_to := 0.0
## How hard the camera is drawn toward the pen, and how fast its own speed may change: a damped spring,
## omega = sqrt(PULL * EASE) and zeta = sqrt(EASE / (4 * PULL)); 1.5 and 6.0 are critically damped at
## omega 3, settling a carriage return in about a second with no overshoot.
const CAM_PULL := 8.0
const CAM_ACCEL := 16.0

# The camera sits in the text: glyphs are large enough to overflow the frame and the camera follows the
# pen, with a slow independent downward creep so the frame is never quite still.
var _cam := Vector2.ZERO          # eased camera center, in the same unit space as _cx/_cy
var _cam_vel := Vector2.ZERO      # its SPEED, which is what is eased now - see _track_pen
var _cam_drift := 0.0             # seconds, for the bounded breath (see _track_pen)
var _zoom_in := 2.6               # how far the framing is pushed past whole-page
var _drift_rate := 0.006

# The spiral's own cursor: arc length along the coil, and the scale the coil is drawn at so what has been
# written stays in frame. Glyphs never move along the arc once written (shifting `s` would rotate the picture).
var _s := 0.0
# `_coil_fit`, not `_fit`: `_fit` is the hand's scale, chosen once at layout; this one changes every
# frame and applies to the coil only.
var _coil_fit := 1.0
var _coil_fit_to := 1.0
## Turns of coil to keep: a bound, not a look. The writing never stops, so without one the glyph list
## and the zoom-out grow without limit. Well past what a scene's lifetime reaches (about twelve turns in
## sixty seconds), so in an ordinary shot nothing is retired.
const MAX_TURNS := 16.0
var _coil := 0.02                 # r = coil * theta
var _s_min := 0.0
var _s_max := 1.0

# Page metrics, in unit fractions.
var _half := Vector2(0.888, 0.5)
var _left := 0.0
var _right := 0.0
var _top := 0.0
var _bottom := 0.0
var _adv := 0.05
var _em := 0.08
var _line_step := 0.12
var _fit := 1.0
var _open := false                # has the page been laid out and pre-written yet

# Sampled look / behavior.
var _layout := "page"
var _centered := false
var _margin := 0.08
var _col_frac := 0.48
var _line_h := 1.6
var _bpg := 2
var _char_beats := 0.5    # fraction of a beat one NOMINAL character takes to write
var _mean_ink := 0.0      # the hand's mean glyph ink length, the divisor in _len_scale
var _rest_char := 0.12    # the pen's rest after a character / a word / a line, as a
var _rest_word := 0.55    # fraction of one nominal character's span
var _rest_line := 1.1
var _break_thr := 0.35
var _press_lvl := 0.0             # smoothed nib pressure, 0..1
var _ease := 0.6                  # how much the stroke reveal is eased
var _prefill := 0.4
var _paper := true
var _ruled := false
var _margin_rule := false
var _ink_hue := 0.0
var _ink_wet := 0.0
var _ink_sat := 0.5
var _ink_val := 0.2
var _ink_alpha := 0.95
var _dry := 2.0
var _paper_hue := 0.1
var _paper_sat := 0.06
var _paper_val := 0.92
var _rule_col := Color(0, 0, 0, 0.12)
var _nib_col := Color(0, 0, 0, 0.8)

# Per-frame geometry scratch kept as members: packed arrays are value types in GDScript, so a helper
# that appends to a parameter would append to a copy.
var _pts := PackedVector2Array()
var _cols := PackedColorArray()
var _uvs := PackedVector2Array()
var _idx := PackedInt32Array()

# _pose's outputs, likewise (a Dictionary per character per frame is 220 allocations).
var _pxf := Transform2D.IDENTITY
var _pfade := 1.0

var _tip := Vector2.ZERO
var _tip_rot := 0.0
var _tip_ok := false


## What this scene can be told ([method GhostScene.choice], [method GhostScene.number]): a storyboard
## entry's `set`, by name; a setting not told is drawn from the seed.
const FIELDS := {
	"layout": {"label": "Layout", "type": "choice", "options": "LAYOUTS", "default": null,
		"blurb": "How the writing is laid out: a page, a column, a banner, or a spiral that stops reading as paper."},
	"margin": {"label": "Margin", "type": "num", "range": [0.04, 0.14], "default": null,
		"blurb": "How wide the empty margin around the writing is."},
	"line_spacing": {"label": "Line spacing", "type": "num", "range": [1.30, 2.10], "default": null,
		"blurb": "How far apart the lines of writing are."},
	"pace": {"label": "Writing pace", "type": "num", "range": [0.25, 0.80], "default": null,
		"blurb": "How long the pen takes over each character, as a share of a beat."},
	"word_pause": {"label": "Word pause", "type": "num", "range": [0.35, 0.95], "default": null,
		"blurb": "How long the pen rests between words."},
	"prefill": {"label": "Already written", "type": "num", "range": [0.15, 0.70], "default": null,
		"blurb": "How much of the page is already written when the scene opens."},
}


func build_params(rng: RandomNumberGenerator) -> Dictionary:
	render_kind = "canvas"
	framing = "plane"                     # a page is square-on; PLANE_BAG keeps it there
	_prng.seed = rng.randi()
	_gs = GlyphSet.new(rng)
	# The hand's mean ink length, so a character's duration can be its own length against it (see _len_scale).
	_mean_ink = 0.0
	for g in _gs.glyphs:
		_mean_ink += (g as GlyphSet.Glyph).total
	_mean_ink /= maxf(1.0, float(_gs.count()))
	_sch = Scheme.pick(rng)
	_layout = String(choice("layout", rng))
	_centered = _layout == "banner"
	_margin = number("margin", rng)
	_col_frac = rng.randf_range(0.38, 0.60)
	_line_h = number("line_spacing", rng)
	_bpg = rng.randi_range(1, 4)
	# 0.25 to 0.8 of a beat per character: 2.5 to 8 a second at 120 bpm.
	_char_beats = number("pace", rng)
	# The hand rests unevenly: a short lift between characters, longer between words, longest at the turn
	# of a line. Fractions of one nominal character's span, so they ride the tempo.
	_rest_char = rng.randf_range(0.05, 0.22)
	_rest_word = number("word_pause", rng)
	_rest_line = rng.randf_range(0.70, 1.80)
	# How far into the text the camera sits: at 1.0 the whole page is in frame; past 2 the writing runs
	# off both edges. A spiral is framed whole: its nib orbits rather than travels, and at a page's zoom
	# the frame would land inside the coil's empty hub (`_line_step` across).
	_zoom_in = rng.randf_range(1.02, 1.30) if _layout == "spiral" else rng.randf_range(2.1, 3.4)
	# A few percent of a line height a second.
	_drift_rate = rng.randf_range(0.004, 0.011)
	# Movement is a 0..1 section-change score that spends most of a track low: a threshold near 0.5
	# breaks words only at real changes, near 0.2 gives short, choppy ones.
	_break_thr = rng.randf_range(0.18, 0.52)
	_ease = rng.randf_range(0.20, 1.0)
	_prefill = number("prefill", rng)
	_dry = rng.randf_range(1.2, 4.0)
	_paper = rng.randf() < 0.5
	_ruled = _paper and rng.randf() < 0.45
	_margin_rule = _ruled and rng.randf() < 0.5
	if _paper:
		# High-key: the ground is flat and bright (paint_ground, not a bed) and the ink is dark.
		_paper_hue = _sch.hue
		_paper_sat = rng.randf_range(0.03, 0.12)
		_paper_val = rng.randf_range(0.86, 0.96)
		_ink_hue = _sch.opposed(_sch.hue, 0.10)
		_ink_wet = fposmod(_sch.accent + rng.randf_range(-0.03, 0.03), 1.0)
		_ink_sat = clampf(_sch.sat * rng.randf_range(0.5, 0.9), 0.05, 1.0)
		_ink_val = rng.randf_range(0.10, 0.28)
		_ink_alpha = rng.randf_range(0.88, 1.0)
		_rule_col = Color.from_hsv(fposmod(_sch.accent, 1.0), 0.40, 0.55,
			rng.randf_range(0.10, 0.22))
		_nib_col = Color.from_hsv(fposmod(_ink_hue, 1.0), _ink_sat * 0.7, _ink_val * 0.8, 0.85)
	else:
		# The dark ground is composed: the shared bed behind the writing and a thin dust in front. (`z`
		# defaults to "front"; the bed must ask for "back".)
		add_layer("bed", rng, {"z": "back", "hue": _sch.hue, "sat": _sch.sat * 0.7,
			"val": rng.randf_range(0.10, 0.20), "pools": rng.randi_range(2, 4)})
		add_layer("dust", rng, {"z": "front", "count": rng.randi_range(30, 70),
			"hue": _sch.accent, "sat": _sch.sat * 0.4})
		_ink_hue = _sch.vary(rng, 0.5)
		_ink_wet = _sch.accent
		_ink_sat = clampf(_sch.sat * rng.randf_range(0.4, 0.8), 0.03, 1.0)
		_ink_val = rng.randf_range(0.80, 1.0)
		_ink_alpha = rng.randf_range(0.80, 0.95)
		_rule_col = Color.from_hsv(fposmod(_sch.accent, 1.0), 0.35, 0.9, 0.07)
		_nib_col = Color.from_hsv(fposmod(_ink_hue, 1.0), _ink_sat * 0.5, 1.0, 0.75)
	var d := _gs.spec()
	d["mood"] = _sch.name
	d["layout"] = _layout
	d["ground"] = "paper" if _paper else "ink_on_dark"
	d["margin"] = _margin
	d["line_height"] = _line_h
	d["beats_per_glyph"] = _bpg
	d["char_beats"] = _char_beats
	d["rest_word"] = _rest_word
	d["break_threshold"] = _break_thr
	d["reveal_ease"] = _ease
	d["prefill"] = _prefill
	d["dry_seconds"] = _dry
	d["ruled"] = _ruled
	return d


func _ready() -> void:
	super()
	# A pressed nib samples the stroke ramp slightly past its ends (see GlyphSet.uv_pressure); clamping
	# keeps that from wrapping into the opposite edge of the texture.
	texture_repeat = CanvasItem.TEXTURE_REPEAT_DISABLED


func update(f: AudioFeatures, delta: float) -> void:
	_f = f
	tick(f, delta)
	drift_view(f, 0.02, 0.03)           # a page barely moves; it is being read
	update_layers(f, delta)
	queue_redraw()
	if size.x < 4.0:
		return
	_metrics()
	if not _open:
		_open = true
		_write_opening()
		_shift_cur = _shift_target()     # arrive centered; the ease is for what happens after
		# The page arrives already part written (see _write_opening), so it arrives framed.
		_cam = _clamp_cam(_pen_at())
		_cam_vel = Vector2.ZERO
	# After _metrics and the opening: the tracker reads `_left` / `_right` / `_bottom` / `_line_step`
	# for its bound and the cursor for its target, none of which exist on the first frame.
	_track_pen(delta)
	_ch = chroma_hue()
	_sig = signature()
	# A character commits when the previous one has finished its reveal and the next starts in the same
	# frame, so the writing is continuous. An event, not integration: it belongs here and not in the sim step.
	if f.movement > _break_thr and _mv_prev <= _break_thr:
		_pending_word = true
	_mv_prev = f.movement
	for _i in _sim.ticks(delta):
		_step(_sim.dt)


# The pen. Everything here integrates time, so it runs on the fixed clock (the Director substeps,
# pre-warms and fast-forwards).
func _step(dt: float) -> void:
	# Nib pressure. Flux runs 0.01 to 0.05, so a gain near 20 reaches a full press; an asymmetric
	# follower keeps the hand from strobing.
	_press_lvl = Nonlinear.flare(_press_lvl, clampf(_f.flux * 20.0, 0.0, 1.0), dt, 6.0, 1.8)
	if feed != null and _f.energy < feed.silence_floor:
		return                          # silence: the nib rests where it is, mid-stroke
	# Spend this substep across rests and characters in order, carrying the overshoot rather than
	# discarding it, so a fast hand loses no progress at a handover. A loop, since one substep can span
	# a rest and more than one character.
	var left := dt
	var guard := 0
	while left > 0.0 and guard < 64:
		guard += 1
		if _hold > 0.0:
			var used := minf(_hold, left)
			_hold -= used
			left -= used
			continue
		var span := _span()
		var need := (1.0 - _reveal) * span
		if left < need:
			_reveal += left / span
			break
		left -= need
		_reveal = 1.0
		_commit()                       # _start resets the reveal, _advance sets the next rest
	_scroll = lerpf(_scroll, _scroll_to, 1.0 - exp(-9.0 * dt))
	_coil_fit = lerpf(_coil_fit, _coil_fit_to, 1.0 - exp(-3.0 * dt))
	_ease_shift(dt)


# The centered line's shift, integrated here rather than computed at draw time. A banner recenters its live
# line, so every glyph on it is drawn at `p.x + _shift_cur`. The target moves with the reveal (the committed
# cursor plus the fraction of the current character inked), so it is continuous across a commit, and it is
# eased on this fixed clock because a word gap, a narrow mark and a carriage return still move it in one
# substep. _pen_at reads the same value, and _newline freezes it as the line's final shift.
func _ease_shift(dt: float) -> void:
	if not _centered:
		_shift_cur = 0.0
		return
	_shift_cur = lerpf(_shift_cur, _shift_target(), 1.0 - exp(-14.0 * dt))


func _shift_target() -> float:
	if not _centered:
		return 0.0
	var w := _adv * (0.62 if _cur_mark else 1.0)
	return -(_cx + w * clampf(_reveal, 0.0, 1.0) + _left) * 0.5


# How long the character under the nib has to be written. A pen moves at a roughly constant nib speed,
# so a character's duration is its own ink length against the hand's mean (the alphabet runs 2 to 7
# strokes a character, GlyphSet.strokes_lo/hi), which leaves the average pace where it was.
func _span() -> float:
	return maxf(0.05, _base_span() * _len_scale(int(_cur.get("g", -1))))


# The tempo's share of one nominal character, before that character's length and the hand's rests are
# applied. Clamped so an absurd tempo estimate cannot stall or sprint the hand. A fraction of a beat, so
# the slowest hands do not write at one character a second (a real hand runs two to six).
func _base_span() -> float:
	return _char_beats * clampf(_f.beat_period, 0.25, 1.6)


# This character's ink length against the hand's mean, bounded so the shortest is still visibly drawn
# and the longest does not stall the page.
func _len_scale(gi: int) -> float:
	if gi < 0 or _mean_ink <= 0.0 or _gs == null or gi >= _gs.glyphs.size():
		return 1.0
	var g: GlyphSet.Glyph = _gs.glyphs[gi]
	return clampf(g.total / _mean_ink, 0.55, 1.75)


# ---------------------------------------------------------------------------------
# The page: metrics, the cursor, and committing a character
# ---------------------------------------------------------------------------------

func _metrics() -> void:
	var u := maxf(1.0, unit())
	_half = Vector2(size.x, size.y) / (2.0 * u)
	if not _open:
		_adv = _gs.advance
		_em = _gs.em
		_line_step = _em * _line_h
		_bounds()
		var cap := _capacity()
		if cap > MAX_GLYPHS:
			# Scale the whole hand rather than truncating the page: capacity falls with the square of the scale.
			_fit = sqrt(float(cap) / float(MAX_GLYPHS))
			_adv = _gs.advance * _fit
			_em = _gs.em * _fit
			_line_step = _em * _line_h
	_bounds()


func _bounds() -> void:
	var mx := _half.x * (1.0 - 2.0 * _margin)
	var my := _half.y * (1.0 - 2.0 * _margin)
	_top = -my
	_bottom = my
	var measure := 2.0 * mx
	if _layout == "column":
		measure *= _col_frac
	elif _layout == "banner":
		measure *= 0.86
	_left = -measure * 0.5
	_right = measure * 0.5
	# The coil: one turn per line, so rows sit as far apart as a page's lines. Arc length s of an
	# Archimedean spiral is ~coil*theta^2/2, which is where both bounds come from.
	_coil = maxf(0.000001, _line_step / TAU)
	_s_min = _line_step * _line_step / (2.0 * _coil)
	var rmax := _half.length() * 1.08
	_s_max = rmax * rmax / (2.0 * _coil)


func _capacity() -> int:
	if _layout == "spiral":
		return int(maxf(1.0, (_s_max - _s_min) / maxf(0.001, _adv)))
	var per_line := int(maxf(1.0, (_right - _left) / maxf(0.001, _adv)))
	var lines := int(maxf(1.0, (_bottom - _top) / maxf(0.001, _line_step)) + 1.0)
	return per_line * lines


# The page is already part written when we arrive (a blank sheet would take a scene to become a
# picture). Seeded from the build rng, so it reproduces exactly.
func _write_opening() -> void:
	_cx = _left
	_cy = _top + _em
	_s = _s_min
	var n := int(_prefill * float(_capacity()))
	_start(_prng.randi() % maxi(1, _gs.count()))
	for _i in n:
		_cur["born"] = -60.0            # long dry by the time the first frame is drawn
		_placed.append(_cur)
		_cur = {}
		if _prng.randf() < 0.16:
			_pending_word = true
		# The pre-write is instantaneous, so the centering is snapped with it. It must still be kept up to
		# date, because _newline() freezes the live shift as each line's final one.
		_reveal = 1.0
		_shift_cur = _shift_target()
		_advance(_prng.randi() % maxi(1, _gs.count()))
		_shift_cur = _shift_target()
	_reveal = 0.0
	_hold = 0.0


func _commit() -> void:
	if not _cur.is_empty():
		_cur["born"] = _sim.elapsed()
		_placed.append(_cur)
		_cur = {}
	_advance(-1)
	while _placed.size() > MAX_GLYPHS * 2:
		_placed.remove_at(0)


# Step the cursor past the character just finished and put the next one under the nib. [param gi] < 0
# means "ask the music"; the opening pass hands its own index (no signature before the first audio frame).
func _advance(gi: int) -> void:
	var w := _adv * (0.62 if _cur_mark else 1.0)
	var gap := 0.0
	var was_mark := _cur_mark
	var line0 := _line
	_written += 1
	var next_mark := false
	if _pending_word and not was_mark and _gs.reserve > 0:
		next_mark = true                # the mark closes the word; the gap follows it
	elif _pending_word:
		gap = _adv * _gs.word_gap
		_words += 1
		_pending_word = false
	_joined_now = _gs.joined and gap <= 0.0 and not was_mark and not next_mark
	if _layout == "spiral":
		_s += w + gap
		_refit()
	else:
		_cx += w + gap
		if _cx + _adv > _right:
			_newline()
	_cur_mark = next_mark
	var idx := gi
	if next_mark:
		idx = _gs.mark(_words)
	elif idx < 0:
		var k := _gs.key(_sig)
		if k >= 0 and _ch.y > 0.0005:
			# A new key opens a new word at that chord's own character; a held key walks the alphabet
			# on instead of repeating. The signature is a 2.5 s EMA, so its argmax sits still for tens
			# of characters - see GlyphSet.pick.
			if k != _key:
				_key = k
				_run = 0
			else:
				_run += 1
			idx = _gs.pick(_sig, _run)
		else:
			# No tonal content to read (a session booted with no audio): step the alphabet on the
			# counters. Still a function of the feature stream, so reproducible (an rng here would
			# diverge in the export). Nearly unreachable: `_sig.size()` is always 16 (HarmonicSignature.DIM).
			idx = (_written * 7 + _words * 5) % maxi(1, _gs.count())
	_start(idx)
	# The rest that follows the character just finished. Set after _start, which clears it with the reveal.
	var rest := _rest_char
	if gap > 0.0 or was_mark:
		rest = _rest_word
	if _line != line0:
		rest = _rest_line
	_hold = rest * _base_span()


func _newline() -> void:
	if _centered:
		# Freeze this line's centering at the value it was last drawn with; the live line goes on
		# recentering as it grows (see _ease_shift).
		_shifts[_line] = _shift_cur
	_line += 1
	_cx = _left
	if _centered:
		# A carriage return is a discontinuity: the finished line keeps its frozen shift and the new line
		# has no ink, so snapping its centering moves nothing, while easing would drag the first glyph
		# across the page.
		_shift_cur = _shift_target()
	_cy += _line_step
	_joined_now = false
	if _cy > _bottom:
		_scroll_to += _line_step
		_drop_lines()


func _drop_lines() -> void:
	var keep: Array = []
	var cut := _top - 1.8 * _line_step
	var lowest := _line
	for e in _placed:
		var p: Vector2 = e["p"]
		if p.y - _scroll_to > cut:
			keep.append(e)
			lowest = mini(lowest, int(e["line"]))
	_placed = keep
	# The centering table would otherwise grow one entry per line; nothing above the page is asked for again.
	for k in _shifts.keys():
		if int(k) < lowest:
			_shifts.erase(k)


## How far out the writing now reaches, and therefore how small the coil has to be drawn. Eased at the
## draw rate rather than applied here (see the `_fit` lerp), so a long word on the edge is a glide.
func _refit() -> void:
	var r_out := _coil * sqrt(2.0 * maxf(_s, _s_min) / maxf(0.000001, _coil))
	var h := _half / maxf(0.001, _zoom_in)
	_coil_fit_to = clampf(minf(h.x, h.y) * 0.98 / maxf(0.000001, r_out), 0.05, 1.0)
	# ...and the safety valve. Retiring an inner turn moves nothing: every surviving glyph keeps the `s` it was written at.
	var theta_out := sqrt(2.0 * maxf(_s, _s_min) / maxf(0.000001, _coil))
	var theta_keep := theta_out - MAX_TURNS * TAU
	if theta_keep <= TAU:
		return
	var s_keep := _coil * theta_keep * theta_keep * 0.5
	var keep: Array = []
	for e in _placed:
		if float(e["s"]) >= s_keep:
			keep.append(e)
	_placed = keep


func _start(gi: int) -> void:
	var e := {
		"g": clampi(gi, 0, maxi(0, _gs.count() - 1)),
		"join": _joined_now,
		"line": _line,
		"born": 0.0,
	}
	if _layout == "spiral":
		e["s"] = _s
	else:
		e["p"] = Vector2(_cx, _cy)
	_cur = e
	_reveal = 0.0
	_hold = 0.0


# ---------------------------------------------------------------------------------
# Drawing
# ---------------------------------------------------------------------------------

func _draw() -> void:
	begin_draw()
	if _paper:
		# Tonality warms the sheet instead of dimming it.
		paint_ground(_paper_hue, _paper_sat, _paper_val, _ch.y * 0.6, _ch.x)
	else:
		draw_layers("back")
	if size.x < 4.0 or _gs == null or _gs.count() == 0:
		return
	var u := unit()
	_frame(u)
	_rules(u)
	_ink(u)
	# No nib is drawn at the ink's edge: the ink arriving is the indication that something is writing.
	if not _paper:
		# Back to the screen's transform: the dust is atmosphere in the room, not ink on the page.
		draw_set_transform_matrix(view.matrix(size))
		draw_layers("front")


## Push the view into the text: zoom past whole-page and center on the tracked pen. Composed onto the
## scene's view matrix rather than into [member view] itself, so it replaces its own contribution every
## frame instead of accumulating.
func _frame(u: float) -> void:
	var z := _zoom_in
	draw_set_transform_matrix(view.matrix(size)
		* Transform2D(0.0, Vector2(z, z), 0.0, -_cam * u * z))


## Follow the pen, loosely and at a speed that does not jump. Eased rather than locked to the nib, so the
## character being written drifts across the frame and the camera catches up between words.
##
## What is eased is the speed, not the position (a position lerp's velocity is proportional to the error).
## The target does not step (`_pen_at` reads the reveal, as `_shift_target` does) and the gain does not
## switch: a nib far out of frame is a large error and so a large target speed, which the speed ease turns
## into an accelerate-and-settle. The downward creep never stops, so a held character or a silent passage
## still has motion in the frame.
func _track_pen(delta: float) -> void:
	# The downward travel comes from the writing (_cy steps down a line at a time and the camera follows
	# it); an accumulator would grow without bound. A bounded breath keeps the frame alive while the pen holds a character.
	_cam_drift += delta
	var breath := sin(_cam_drift * _drift_rate * TAU * 12.0) * _line_step * 0.18
	# The target is clamped before it is chased: aiming somewhere the camera may not go winds the
	# speed up against the bound and spends it in a lurch when the bound releases.
	var target := _clamp_cam(_pen_at() + Vector2(0.0, breath))
	# A position lerp's rate, read as the speed it asks for; that speed is what gets eased, so the camera
	# cannot change how fast it moves faster than CAM_ACCEL allows.
	var to := target - _cam
	var dist := to.length()
	# The speed allowed is the smaller of a settle (proportional to the error) and a braking limit,
	# sqrt(2 a d), the fastest it can go and still stop on arrival. Braking is what wins on a carriage
	# return, so there is no overshoot and nothing for the page bound to stop dead.
	var cruise := minf(dist * CAM_PULL, sqrt(2.0 * CAM_ACCEL * dist))
	var want := to.normalized() * cruise if dist > 0.000001 else Vector2.ZERO
	# ...and it may not change speed faster than the cap, so the frame's velocity is Lipschitz.
	var dv := want - _cam_vel
	var lim := CAM_ACCEL * delta
	_cam_vel += dv if dv.length() <= lim else dv.normalized() * lim
	var was := _cam
	_cam = _clamp_cam(_cam + _cam_vel * delta)
	# ...and the speed is then taken from what actually happened: the clamp can refuse part of a step,
	# and a velocity that keeps integrating into a wall comes out all at once later.
	if delta > 0.0:
		_cam_vel = (_cam - was) / delta
	# The camera is not written into `view`: `view.zoom` and `view.offset` are only re-set by the
	# assigned shot, so a shotless scene (the catalog smoke gate) would multiply its zoom by _zoom_in
	# every frame. The framing is applied as its own transform at draw time, which is idempotent.


## Where the nib actually is on screen, in the unit-fraction space [member _cam] lives in. Not `_cx` / `_cy`
## (the page cursor): the spiral never touches them, and a banner draws at `p.x + _shift_cur` (see _pose and
## _ink). `_cy` also needs its scroll taken off: it is absolute on an endless page, and when it passes
## `_bottom` the page scrolls (`_scroll_to += _line_step`), so every glyph is drawn at `p.y - _scroll`.
func _pen_at() -> Vector2:
	if _layout == "spiral":
		# A coil is framed, not tracked: its nib's angle advances as `sqrt(s)`, so a tracker lags by more than
		# the visible width and only chases. The coil is drawn to fit (see `_refit`), with `_zoom_in` sampled low.
		return Vector2.ZERO
	# The same eased shift the glyphs are drawn with (see _ease_shift), and the same reveal, for the same
	# reason `_shift_target` reads it: `_cx` is the committed cursor and steps a whole character per commit.
	var w := _adv * (0.62 if _cur_mark else 1.0)
	return Vector2(_cx + w * clampf(_reveal, 0.0, 1.0) + _shift_cur,
		_cy - _scroll - _line_step * 0.25)


## Keep the frame on the writing: the visible rectangle is held inside the region the writing occupies, so
## it can neither sit on empty ground nor show the sheet's edge. The bound is exactly tight (the pen sits
## on the frame edge at the limit) so the hand never writes off the side of its own frame.
func _clamp_cam(c: Vector2) -> Vector2:
	var h := _half / maxf(0.001, _zoom_in)          # visible half-extent, in unit fractions
	if _layout == "spiral":
		# A coil is written outward from its center, so the written disc is the bound and grows with
		# `_s`. The coil is scaled to fit, so there is nowhere for the camera to go; saying so here keeps
		# the bound true if the fit is ever floored.
		var r := _coil * sqrt(2.0 * maxf(_s, _s_min) / maxf(0.000001, _coil)) * _coil_fit
		return c.limit_length(maxf(0.0, r - minf(h.x, h.y)))
	# A page narrower or shorter than the view has no pan on that axis, so it centers.
	var x1 := _right - h.x
	var y1 := _bottom - h.y
	return Vector2(
		clampf(c.x, -x1, x1) if x1 > 0.0 else 0.0,
		clampf(c.y, -y1, y1) if y1 > 0.0 else 0.0)


# Faint ruling under the writing (a dozen antialiased lines): it turns a bright ground into paper.
func _rules(u: float) -> void:
	if not _ruled or _layout == "spiral" or _line_step < 0.005:
		return
	var base := _top + _em
	var k := int(ceil((_top + _scroll - base) / _line_step))
	for i in 40:
		var y := base + float(k + i) * _line_step - _scroll
		if y > _bottom + _line_step * 0.5:
			break
		if y < _top:
			continue
		draw_line(Vector2(_left * u, y * u), Vector2(_right * u, y * u), _rule_col, 1.0, true)
	if _margin_rule:
		var x := (_left - _adv * 0.6) * u
		draw_line(Vector2(x, _top * u), Vector2(x, _bottom * u), _rule_col, 1.2, true)


# The whole page in one triangle array: per character one native transform of its baked vertices, three append_arrays, one color.
func _ink(u: float) -> void:
	_pts.clear()
	_cols.clear()
	_uvs.clear()
	_tip_ok = false
	var now := _sim.elapsed()
	var prev_exit := Vector2.ZERO
	var prev_ok := false
	var hair_w := _gs.weight * u / GlyphSet.REF_UNIT * 0.34
	# One squeeze of the ramp coordinate presses the whole hand (see GlyphSet.uv_pressure).
	var pressed := _gs.pressure > 0.005
	var uvt := _gs.uv_pressure(_press_lvl)
	for e in _placed:
		if not _pose(e, u):
			prev_ok = false
			continue
		var g: GlyphSet.Glyph = _gs.glyphs[int(e["g"])]
		var col := _ink_color(now - float(e["born"]), _pfade)
		if prev_ok and bool(e["join"]):
			_hairline(prev_exit, _pxf * g.entry, hair_w, col)
		var wv: PackedVector2Array = _pxf * g.verts
		var wuv: PackedVector2Array = (uvt * g.uvs) if pressed else g.uvs
		_emit(wv, wuv, col)
		prev_exit = _pxf * g.exit
		prev_ok = true
	if not _cur.is_empty() and _pose(_cur, u):
		var gc: GlyphSet.Glyph = _gs.glyphs[int(_cur["g"])]
		# The reveal is eased, so ink leaves the nib into a stroke and out of it.
		var p := lerpf(_reveal, Nonlinear.apply("smoothstep", _reveal), _ease)
		var tr := _gs.trace(int(_cur["g"]), p)
		var v: PackedVector2Array = tr["verts"]
		var uvc: PackedVector2Array = tr["uvs"]
		var col_c := _ink_color(0.0, _pfade)
		if v.size() >= 4:
			if prev_ok and bool(_cur["join"]):
				_hairline(prev_exit, _pxf * gc.entry, hair_w, col_c)
			var wv2: PackedVector2Array = _pxf * v
			var wuv2: PackedVector2Array = (uvt * uvc) if pressed else uvc
			_emit(wv2, wuv2, col_c)
		var tip_local: Vector2 = tr["tip"]
		_tip = _pxf * tip_local
		_tip_rot = _pxf.get_rotation()
		_tip_ok = true
	_flush()


func _emit(verts: PackedVector2Array, uvs: PackedVector2Array, col: Color) -> void:
	if verts.is_empty():
		return
	_pts.append_array(verts)
	_uvs.append_array(uvs)
	var c := PackedColorArray()
	c.resize(verts.size())
	c.fill(col)
	_cols.append_array(c)


# The cursive connector between two characters of the same word: one quad, the same ramp texture, a third of the pen's weight.
func _hairline(a: Vector2, b: Vector2, w: float, col: Color) -> void:
	var d := b - a
	if d.length_squared() < 0.01:
		return
	var n := Vector2(-d.y, d.x).normalized() * (w / GlyphSet.CORE * 0.5)
	var u0 := GlyphSet.uv_lo()
	var u1 := GlyphSet.uv_hi()
	_pts.append(a - n)
	_pts.append(b - n)
	_pts.append(b + n)
	_pts.append(a + n)
	_uvs.append(Vector2(u0, 0.5))
	_uvs.append(Vector2(u0, 0.5))
	_uvs.append(Vector2(u1, 0.5))
	_uvs.append(Vector2(u1, 0.5))
	var faint := Color(col.r, col.g, col.b, col.a * 0.55)
	for _i in 4:
		_cols.append(faint)


func _flush() -> void:
	var quads := _pts.size() / 4
	if quads <= 0:
		return
	_ensure_idx(quads)
	RenderingServer.canvas_item_add_triangle_array(get_canvas_item(),
		_idx.slice(0, quads * 6), _pts, _cols, _uvs,
		PackedInt32Array(), PackedFloat32Array(), GlyphSet.ramp_texture().get_rid())


# Indices depend only on a quad's ordinal and the vertex buffer is built by concatenation, so one
# template grown to the high-water mark serves every frame.
func _ensure_idx(quads: int) -> void:
	var have := _idx.size() / 6
	if quads <= have:
		return
	_idx.resize(quads * 6)
	for q in range(have, quads):
		var b := q * 4
		var o := q * 6
		_idx[o] = b
		_idx[o + 1] = b + 1
		_idx[o + 2] = b + 2
		_idx[o + 3] = b
		_idx[o + 4] = b + 2
		_idx[o + 5] = b + 3


# Where one character sits this frame, into _pxf / _pfade. Returns false for a character scrolled off the page.
func _pose(e: Dictionary, u: float) -> bool:
	# Audio-free: the sound presses the nib and moves the color, it never scales the writing.
	var sc := _em * u
	if _layout == "spiral":
		var s: float = float(e["s"])
		if s < _s_min * 0.9:
			return false
		var theta := sqrt(2.0 * s / _coil)
		# The coil is drawn smaller as it grows, and the glyphs with it: one scale for the whole picture.
		var r := _coil * theta * _coil_fit
		_pfade = clampf((r - _line_step * _coil_fit)
			/ maxf(0.001, _line_step * _coil_fit * 0.8), 0.0, 1.0)
		_pxf = Transform2D(theta + PI * 0.5, Vector2(sc * _coil_fit, sc * _coil_fit), 0.0,
			Vector2(cos(theta), sin(theta)) * r * u)
		return true
	var p: Vector2 = e["p"]
	var y := p.y - _scroll
	if y < _top - 2.0 * _line_step:
		return false
	# A centered layout recenters the live line as it grows and freezes the shift once the line is finished.
	var sh := _shift_cur
	if _centered:
		var ln := int(e["line"])
		if _shifts.has(ln):
			sh = float(_shifts[ln])
	_pfade = clampf((y - _top + 1.6 * _line_step) / maxf(0.001, 1.6 * _line_step), 0.0, 1.0)
	_pxf = Transform2D(0.0, Vector2(sc, sc), 0.0, Vector2(p.x + sh, y) * u)
	return true


# Ink dries. Fresh ink is wetter, darker (or brighter on a dark ground) and pulled toward the scheme's
# accent; over `_dry` seconds it settles to the page's own color (age is a subtraction, so it is free).
func _ink_color(age: float, fade: float) -> Color:
	var wet := exp(-maxf(0.0, age) / _dry)
	var h := _ink_hue
	var dh := _ink_wet - h
	h = fposmod(h + (dh - round(dh)) * wet * 0.8, 1.0)
	var s := clampf(_ink_sat * (0.55 + 0.75 * _ch.y) + 0.10 * wet, 0.0, 1.0)
	var v := _ink_val * (1.0 - 0.35 * wet) if _paper else _ink_val * (1.0 + 0.30 * wet)
	return Color.from_hsv(h, s, clampf(v, 0.0, 1.0), clampf(_ink_alpha * fade, 0.0, 1.0))


# The nib itself, resting on the paper where the ink stops: a small wedge; the shaft angle and the ink imply the hand.
func _nib(u: float) -> void:
	if not _tip_ok:
		return
	var sc := _em * u
	var shaft := Vector2(0.42, -0.91).rotated(_tip_rot)
	var n := Vector2(-shaft.y, shaft.x)
	var l := sc * 0.60
	var w := sc * 0.085
	fill_aa(PackedVector2Array([
		_tip,
		_tip + shaft * (l * 0.5) + n * w,
		_tip + shaft * l,
		_tip + shaft * (l * 0.5) - n * w]), _nib_col, 1.0)
