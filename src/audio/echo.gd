extends RefCounted
class_name Echo

## Echo - content re-localization: "have I heard this before, and where?"
##
## The Director keeps the show's cursor aligned to the music itself, not the playhead (which lies once the
## audio is doubled into one track, trimmed or looped). Echo builds a map of what the song sounds like at each
## position of the show's schedule (the [HarmonicSignature] descriptor) and continuously matches the live
## signature against it. When the incoming audio accumulates enough evidence that it belongs somewhere the
## cursor is not (the song looped back, a cloned section arrived, the board sat frozen past its end), it
## reports the schedule position the audio says we are at, and the Director corrects course.
##
## The matcher is an accumulator over alignments (lags), not a best-frame streak. Every tick each map cell
## resembling the live audio votes for its lag (cell time minus the monotonic listening clock, constant while
## playback stays aligned). A true alignment gathers weak-but-consistent votes through the whole pass; a
## lookalike twin (a repeated chorus) only gathers votes during its own section, so self-similar music does not
## flicker between twins.
##   frontier  - the map is write-once, recorded the first time each schedule position plays.
##   explained - self-match is explanation, not evidence: cells near the cursor feed a separate "here" tally
##               (never the lag bins), and while the cursor is inside the map a correction must decisively
##               out-vote it. A cursor beyond the map explains nothing and defends nothing.
##   decay     - evidence has a half-life, so coincidental resemblance fades.
##   cooldown  - after a correction the accumulator restarts from silence.
##
## Echo holds no rng and no Godot scene state: a pure listener, testable headlessly (tests/audio/echo_check.gd).

const CELL := 0.5          # map resolution: one signature snapshot per this many schedule seconds
const TICK := 0.25         # how often the live signature is matched against the map (s)
const SOFT := 0.90         # cells scoring above this cosine vote for their lag
const FIRE := 2.2          # accumulated votes to fire, in SECONDS of full-strength match
const BEAT := 1.5          # a correction must carry this multiple of the RECENT self-match
const HALF_LIFE := 6.0     # confidence half-life (s) - long enough that a weak-but-real
                           # alignment can integrate to FIRE, short enough that fades
# The explained-check runs on short-memory tallies: confidence wants a long integral, but the defense must be
# responsive, since after a loop the cursor's old self-match goes stale within seconds. A twin still ties the
# equally fresh "here" tally.
const HALF_FAST := 1.5
const LAG_BIN := 1.0       # lag quantization (s); the reported time uses the exact vote mean
const COOLDOWN := 4.0      # silence after a correction (s)
# The self radius: map cells within this of the cursor's claim are the show explaining itself (they feed the
# defense, never the bins), and a bin whose implied target lands within it is not a correction. It must exceed
# the music's local self-similarity, or a standing trailing-lag bin fires as the cursor passes the map's end.
const NEAR := 6.0

var _times := PackedFloat32Array()   # schedule time of each map cell (monotonic)
var _cells: Array = []               # unit-normalized signature per cell
var _frontier := -1e9                # schedule time of the newest cell (write-once gate)
var _acc := 0.0                      # time since the last match tick
var _votes := {}                     # lag bin (int) -> accumulated vote weight (confidence)
var _votes_fast := {}                # lag bin (int) -> short-memory vote weight (recency)
var _lag_sum := {}                   # lag bin (int) -> weight-weighted exact-lag sum
var _here_fast := 0.0                # short-memory self-match around the cursor (the defense)
var _cool := 0.0


## Record what schedule position [param t] sounds like. Write-once: positions at or
## behind the frontier (a replayed pass after a correction) are ignored, so the map
## always describes the first hearing. Call every frame; the cell gate is internal.
func record(t: float, sig: PackedFloat32Array) -> void:
	if t < _frontier + CELL:
		return
	var v := _unit(sig)
	if v.is_empty():
		return
	_times.append(t)
	_cells.append(v)
	_frontier = t


## Listen for a re-localization. [param heard_t] is a monotonic listening clock (it
## never rewinds - lags are measured against it); [param cursor_t] is where the
## show's cursor claims to be in the schedule (pass a huge value when it is beyond
## the map, e.g. cycling a tail). Returns the schedule time the audio says we are
## at, or -1.0 while the cursor already explains what we hear. Call every frame.
func listen(heard_t: float, cursor_t: float, sig: PackedFloat32Array, dt: float) -> float:
	_cool = maxf(0.0, _cool - dt)
	_acc += dt
	if _acc < TICK:
		return -1.0
	_acc = 0.0
	if _cells.size() < 8:
		return -1.0                    # too little map to recognize anything against
	var decay := pow(0.5, TICK / HALF_LIFE)
	var decay_fast := pow(0.5, TICK / HALF_FAST)
	for b in _votes.keys():
		_votes[b] *= decay
		_lag_sum[b] *= decay
		_votes_fast[b] = float(_votes_fast.get(b, 0.0)) * decay_fast
	_here_fast *= decay_fast
	var v := _unit(sig)
	if v.is_empty():
		return -1.0                    # silence: cast no votes, let the old ones fade
	# Each sufficiently-similar cell votes for its lag; one vote per bin per tick
	# (the strongest), so a run of near-identical neighboring cells - the EMA makes
	# neighbors alike - doesn't multiply its say. Cells near the cursor are the show
	# explaining itself: they feed the "here" defense, never the lag bins.
	var tick_w := {}
	var tick_lag := {}
	var here_tick := 0.0
	for i in _cells.size():
		var s := _dot(v, _cells[i])
		if s < SOFT:
			continue
		var w := (s - SOFT) / (1.0 - SOFT)
		if absf(_times[i] - cursor_t) < NEAR:
			here_tick = maxf(here_tick, w)
			continue
		var lag := _times[i] - heard_t
		var b := int(floor(lag / LAG_BIN + 0.5))
		if w > float(tick_w.get(b, 0.0)):
			tick_w[b] = w
			tick_lag[b] = lag
	_here_fast += here_tick * TICK
	for b in tick_w.keys():
		_votes[b] = float(_votes.get(b, 0.0)) + tick_w[b] * TICK
		_votes_fast[b] = float(_votes_fast.get(b, 0.0)) + tick_w[b] * TICK
		_lag_sum[b] = float(_lag_sum.get(b, 0.0)) + tick_lag[b] * tick_w[b] * TICK
	if _cool > 0.0:
		return -1.0
	# The winning alignment among eligible bins: enough long-memory confidence, and an
	# implied target genuinely elsewhere (a bin near the cursor is self-similarity, not
	# a correction - and being ineligible, it can never mask a real alignment either).
	var best_w := 0.0
	var best_to := -1.0
	for b in _votes.keys():
		var w2 := float(_votes[b])
		if w2 < FIRE or w2 <= best_w:
			continue
		var t2 := clampf(heard_t + float(_lag_sum[b]) / w2, 0.0, _frontier)
		if absf(t2 - cursor_t) < NEAR:
			continue
		# The recent votes must decisively out-vote the cursor's recent self-match.
		# _here_fast is self-regulating - fed only by cells near the cursor's claim,
		# so it stays high exactly as long as that claim explains the audio (even a
		# cursor just past the map's end still holds the outro) and dies within a
		# couple of seconds once the content moves on. No positional gate needed.
		if float(_votes_fast.get(b, 0.0)) < _here_fast * BEAT:
			continue
		best_w = w2
		best_to = t2
	if best_to < 0.0:
		return -1.0
	_votes.clear()
	_votes_fast.clear()
	_lag_sum.clear()
	_here_fast = 0.0
	_cool = COOLDOWN
	return best_to


## How much of the schedule has been mapped (s) - observability, and the Director's
## "is the cursor beyond the map" check.
func frontier() -> float:
	return maxf(0.0, _frontier)


func _unit(sig: PackedFloat32Array) -> PackedFloat32Array:
	if sig.is_empty():
		return PackedFloat32Array()
	var n := 0.0
	for x in sig:
		n += x * x
	if n < 1e-8:
		return PackedFloat32Array()    # silence / unstarted analyzer: nothing to hear
	n = sqrt(n)
	var v := PackedFloat32Array()
	v.resize(sig.size())
	for i in sig.size():
		v[i] = sig[i] / n
	return v


func _dot(a: PackedFloat32Array, b: PackedFloat32Array) -> float:
	var s := 0.0
	for i in mini(a.size(), b.size()):
		s += a[i] * b[i]
	return s
