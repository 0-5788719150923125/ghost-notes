extends RefCounted
class_name Splice

## Splice - the cuts a reading makes in a voice's take once the model has rendered it: the
## hesitations spliced in (a rest the model will not make on its own), the hums held, and every
## word's timing moved by the cuts before it; and the take read from and written to a WAV.
##
## PURE: functions of the samples, the spans the aligner returned and the sample rate - nothing of
## who asked. Cut out of [ReadingPanel] (next/structure.md, step 13), where the live window and the
## export take both called them, so the two cannot disagree about a splice; a voice that is a card,
## or a reading whose text arrives as it is written, splices with the same functions.

## SPLICE THE HESITATIONS into one chunk's audio, after its resample. Returns
## `{pcm, cuts}`, where `cuts` is `[{t, add}]` in the MODEL's time (the clock the aligner's
## spans are on) - [method shifted] moves a word timing by every cut before it.
##
## WHERE: the host's `rest` for the word the rest follows - the quietest place between that
## word's last sound and the next word's first, inside any pause already spliced there (piper
## `_gap_window`). Word spans touch, so their midpoint is only the fallback for a host that
## sends no `rest`. A rest before the chunk's first word opens the chunk; one after its last
## closes it. Both sit inside the chunk rather than in the seam, so the live window and the
## export - which join chunks differently - cannot disagree about them.
##
## HOW MUCH: the rest less what the voice already rests there for it (the word's `rested`): the
## host is told of the rest (a token's `rest_after`, [method ReadingPlan.cut]) and the model ends
## the word and pauses on its own (piper `REST_AFTER_FLOOR`) - so a hesitation is as long as it
## says, never that and the model's pause.
##
## THE EDGES: a raised-cosine ramp either side, as long as the level there needs - the voice
## often runs straight from one word into the next, and a ramp of a few milliseconds on a
## sounding vowel is a click. Mirrors piper `_edge_ramp`: HOLD_FADE in silence, up to a
## HOLD_RELEASE out of the word and a HOLD_ATTACK into the next, log-spaced between HOLD_QUIET
## and HOLD_LOUD of the chunk's peak.
const HOLD_FADE := 0.002
const HOLD_RELEASE := 0.030
const HOLD_ATTACK := 0.012
const HOLD_QUIET := 0.02
const HOLD_LOUD := 0.16

static func chunk(pcm: PackedFloat32Array, holds: Array, spans: Array, ratio: float, sr: int) -> Dictionary:
	var cuts: Array = []
	if holds.is_empty():
		return {"pcm": pcm, "cuts": cuts}
	var by_index := {}
	for sp in spans:
		by_index[int((sp as Dictionary).get("index", -1))] = sp
	var end := INF
	var spent := {}                  # of each word's `rested`, what a rest has already taken
	for h in holds:
		var k := int((h as Dictionary)["tok"])
		var cur: Variant = by_index.get(k)
		if (h as Dictionary).has("hum"):
			if cur != null:
				var hc := hum_cut(pcm, float(cur["t0"]), float(cur["t1"]), float(h["hum"]), ratio, sr)
				if not hc.is_empty():
					cuts.append(hc)
			continue
		var t := end
		var own: Variant = cur        # the word the rest follows
		if bool((h as Dictionary)["before"]):
			var prev: Variant = by_index.get(k - 1)
			own = prev if k > 0 else null
			if k == 0:
				t = 0.0
			elif prev != null and cur != null:
				t = float(prev.get("rest", (float(prev["t1"]) + float(cur["t0"])) * 0.5))
			elif cur != null:
				t = float(cur["t0"])
			elif prev != null:
				t = float(prev["t1"])
		else:
			var nxt: Variant = by_index.get(k + 1)
			if nxt == null:
				t = end              # the chunk's last word: rest after all of it
			elif cur != null:
				t = float(cur.get("rest", (float(cur["t1"]) + float(nxt["t0"])) * 0.5))
			else:
				t = float(nxt["t0"])
		var add := float((h as Dictionary)["sec"])
		if own != null:
			var w := int(own.get("index", -1))
			var have := clampf(float(own.get("rested", 0.0)) - float(spent.get(w, 0.0)), 0.0, add)
			spent[w] = float(spent.get(w, 0.0)) + have
			add -= have
		if add > 0.0:
			cuts.append({"t": t, "add": add})
	cuts.sort_custom(func(a, b): return float(a["t"]) < float(b["t"]))
	var out := PackedFloat32Array()
	var from := 0
	var peak := 0.0
	for v in pcm:
		peak = maxf(peak, absf(v))
	var n_in := 0                    # the ramp into the piece after the last cut
	var after_fill := false          # the piece being cut follows a hum: no fade-in on it
	for c in cuts:
		var ct := float(c["t"])
		var at := pcm.size() if is_inf(ct) else clampi(int(c.get("at",
			int(round(ct / ratio * float(sr))))), from, pcm.size())
		var piece := pcm.slice(from, at)
		var fill: Variant = c.get("fill")
		# Ramp either side of a SILENCE; a hum's continuation is phase-aligned to the cut, so
		# fading it would put a dip in the middle of the hum it is lengthening.
		var n_out := 0
		if fill == null:
			n_out = _edge_ramp(_edge_level(pcm, at, true, sr), peak, HOLD_RELEASE, sr)
		piece = _ramped(piece, 0 if after_fill else n_in, n_out)
		out.append_array(piece)
		if fill != null:
			out.append_array(fill as PackedFloat32Array)
		else:
			var gap := PackedFloat32Array()
			gap.resize(int(float(c["add"]) * float(sr)))
			out.append_array(gap)
		# A fill that RESUMES elsewhere ended in its own fade, so what follows fades in as
		# after any rest; one that rejoins at `at` is phase-aligned and must not.
		after_fill = fill != null and not c.has("resume")
		from = clampi(int(c.get("resume", at)), at, pcm.size())
		n_in = _edge_ramp(_edge_level(pcm, from, false, sr), peak, HOLD_ATTACK, sr)
	out.append_array(_ramped(pcm.slice(from), 0 if after_fill else n_in, 0))
	return {"pcm": out, "cuts": cuts}


## RMS of the 5 ms on one side of sample [param at].
static func _edge_level(pcm: PackedFloat32Array, at: int, before: bool, sr: int) -> float:
	var n := maxi(1, int(0.005 * float(sr)))
	var a := maxi(0, at - n) if before else clampi(at, 0, pcm.size())
	var b := clampi(at, 0, pcm.size()) if before else mini(pcm.size(), at + n)
	if b <= a:
		return 0.0
	var e := 0.0
	for i in range(a, b):
		e += pcm[i] * pcm[i]
	return sqrt(e / float(b - a))


## Samples of ramp at a splice edge whose [param level] is that loud, up to [param longest]
## seconds - see [constant HOLD_RELEASE].
static func _edge_ramp(level: float, peak: float, longest: float, sr: int) -> int:
	var sec := HOLD_FADE
	var quiet := HOLD_QUIET * peak
	if peak > 0.0 and level > quiet:
		var k := minf(1.0, log(level / quiet) / log(HOLD_LOUD / HOLD_QUIET))
		sec = HOLD_FADE + k * (longest - HOLD_FADE)
	return maxi(1, int(round(sec * float(sr))))


## [param buf] with raised-cosine ramps over its first [param n_in] and last [param n_out]
## samples.
static func _ramped(buf: PackedFloat32Array, n_in: int, n_out: int) -> PackedFloat32Array:
	var k := mini(n_in, buf.size())
	for i in k:
		buf[i] *= 0.5 - 0.5 * cos(PI * (float(i) + 0.5) / float(k))
	k = mini(n_out, buf.size())
	for i in k:
		buf[buf.size() - 1 - i] *= 0.5 - 0.5 * cos(PI * (float(i) + 0.5) / float(k))
	return buf


## HUMS ARE HELD. "Hmm." read as a thinking hum is most of a second; the voice renders it in
## about 0.15 s, and asking for more `M`s does not help - measured, eight of them come back
## as 0.30 s, the model compresses the repeats. So the hum is LENGTHENED after the fact, by
## pitch-synchronous overlap-add of its own steadiest periods: same voice and color.
## Target length in seconds, per spelling.
const HUM_SECONDS := {"hm": 0.45, "mm": 0.5, "hmm": 0.75, "mmm": 0.85, "hmmm": 0.95}
## Pitch marks either side of the anchor the held hum wanders over. Wandering, rather than
## repeating one period, keeps the hum alive; more than a few reaches the pitch glide and the
## fry either side of the steady stretch.
const HUM_MARKS := 2
## THE HUM FALLS. A thinking "hmm" is not a held note: it settles, then drops in pitch and dies
## away. Semitones of fall by the end, and where along the held hum (0..1) the pitch starts to
## drop and the loudness starts to fade.
const HUM_FALL := 4.0
const HUM_FALL_FROM := 0.3
const HUM_FADE_FROM := 0.55

## The cut that lengthens one hum to [param target] seconds: `{t, at, add, fill}`, or empty
## when it is already long enough or has no steady voiced stretch to hold.
##
## WHY OVERLAP-ADD. The first version butted raw periods end to end. A rendered hum is not
## strictly periodic - its pitch glides ~15% across the word, periodicity is ~0.75, and it
## drops into fry at half the pitch - so every join between copied periods was a step in the
## waveform, and a join every few periods is a buzz: measured, splice steps up to 2.9x the
## largest in the natural hum and a 5 ms loudness flutter of 20-50%. Here every period is a
## two-period Hann grain laid down one period apart, so each join is a crossfade and a hard
## step cannot occur; grains are matched in loudness to the anchor so the wander cannot
## flutter; and the fill starts and ends on the anchor mark itself, so it leaves and rejoins
## the natural hum at the same sample.
##
## IT REPLACES THE HUM'S TAIL rather than being inserted into it: the fill falls in pitch and
## fades out, so going back to the natural hum afterwards would jump the pitch back up. The
## take resumes (`resume`) where the natural hum has gone quiet, and `add` is what the reading
## gained overall.
static func hum_cut(pcm: PackedFloat32Array, t0: float, t1: float, target: float, ratio: float, sample_rate: int) -> Dictionary:
	var sr := float(sample_rate)
	var a := int(t0 / ratio * sr)
	var b := mini(int(t1 / ratio * sr), pcm.size())
	if target - float(b - a) / sr < 0.03 or b - a < 64:
		return {}
	# THE ANCHOR: the loudest periodic frame at the hum's own pitch. Most renders drop into
	# FRY somewhere - a period-doubled subharmonic an octave down, often the loudest stretch
	# and just as periodic (measured 0.96 against the modal 0.9), which held is a creak and
	# not a hum. Two tells, and neither is a candidate unless the hum has nothing else: a
	# frame pitched well under the highest the hum reaches cleanly, and one that matches
	# itself better two periods on than one (the fry setting in or letting go).
	var win := int(0.02 * sr)
	var hi := int(sr / 60.0)
	var frames: Array = []          # [at, period, periodicity, rms, doubled]
	var modal := INF
	var f := a
	while f + win + hi <= b:
		var pc := period_of(pcm, f, win, sr)
		if pc.x > 0.0 and pc.y > 0.5:
			var e := 0.0
			for k in win:
				e += pcm[f + k] * pcm[f + k]
			frames.append([f, pc.x, pc.y, sqrt(e / float(win)), pc.z > pc.y + 0.05])
			if pc.y > 0.7:
				modal = minf(modal, pc.x)
		f += int(0.01 * sr)
	var anchor := -1
	var period := 0.0
	for pass_ in 2:
		var score := 0.0
		for fr in frames:
			if pass_ == 0 and (float(fr[1]) > modal / 0.7 or bool(fr[4])):
				continue
			var sc: float = float(fr[3]) * float(fr[2]) * float(fr[2])
			if sc > score:
				score = sc
				anchor = int(fr[0])
				period = float(fr[1])
		if anchor >= 0:
			break
	if anchor < 0:
		return {}
	var half := int(round(period))
	# THE MARKS: the strongest peak in the middle period of the anchor frame, then one
	# period at a time either side, each nudged to where it best matches the anchor's own
	# period. They stay inside the frame that was measured: a frame is chosen for being
	# steady, and the fry is often the very next thing.
	var mid := anchor + win / 2 - half / 2
	var c := mid
	for k in half:
		if pcm[mid + k] > pcm[c]:
			c = mid + k
	var marks: Array = []
	var gains: Array = []
	var ref := _grain_energy(pcm, c, half)
	if ref <= 0.0:
		return {}
	for j in range(-HUM_MARKS, HUM_MARKS + 1):
		var m := c
		if j != 0:
			m = _align_mark(pcm, c, int(round(float(c) + float(j) * period)), half)
		if m - half < maxi(a, anchor - half / 2) or m + half >= mini(b, anchor + win + half / 2):
			continue
		marks.append(m)
		gains.append(sqrt(ref / maxf(_grain_energy(pcm, m, half), 1e-9)))
	var home := marks.find(c)
	if home < 0:
		return {}
	# WHERE THE NATURAL HUM ENDS: the first 5 ms after the anchor quieter than a tenth of it,
	# not the aligner's word end, which can fall short of the voicing it closes.
	var ref_rms := sqrt(ref / float(maxi(1, half / 2 * 2)))
	var hop5 := int(0.005 * sr)
	var e := mini(b + int(0.2 * sr), pcm.size())
	var s := c + int(0.02 * sr)
	while s + hop5 <= mini(b + int(0.2 * sr), pcm.size()):
		var en := 0.0
		for k in hop5:
			en += pcm[s + k] * pcm[s + k]
		if sqrt(en / float(hop5)) < 0.1 * ref_rms:
			e = s
			break
		s += hop5
	var length := int(target * sr) - (c - a)
	var add := float(length - (e - c)) / sr
	if add < 0.03:
		return {}
	# THE FILL: grains laid down one output period apart - a period that lengthens as the
	# pitch falls - from a seeded walk over the marks, the first on the anchor itself so the
	# fill leaves the natural hum at the same sample. Divided by the summed window only where
	# grains overlap by more than it: a longer hop leaves the windows short of 1 between
	# grains, which is what a lower pitch is, and dividing that out would inflate the tails.
	var fall := pow(2.0, -HUM_FALL / 12.0)
	var acc := PackedFloat32Array()
	acc.resize(length)
	var wsum := PackedFloat32Array()
	wsum.resize(length)
	var at := home
	var o := 0.0
	var g := 0
	while o < float(length + half):
		var u := o / float(length)
		var drop := smoothstep(HUM_FALL_FROM, 1.0, u)
		var env := 0.5 + 0.5 * cos(PI * smoothstep(HUM_FADE_FROM, 1.0, u))
		if g > 0:
			var step := posmod(hash(g * 7919 + c), 3) - 1
			at = clampi(at + step, 0, marks.size() - 1)
		var m: int = marks[at]
		var gain: float = env * (1.0 if at == home else float(gains[at]))
		var oi := int(round(o))
		for d in range(-half + 1, half):
			var q := oi + d
			if q < 0 or q >= length:
				continue
			var w := 0.5 + 0.5 * cos(PI * float(d) / float(half))
			acc[q] += w * gain * pcm[m + d]
			wsum[q] += w
		o += period / lerpf(1.0, fall, drop)
		g += 1
	for q in length:
		acc[q] = acc[q] / maxf(wsum[q], 1.0)
	return {"t": float(c) / sr * ratio, "at": c, "add": add, "fill": acc, "resume": e}


## The pitch period of [param n] samples from [param s0] (fractional, in samples), how
## periodic they are (normalized correlation at that lag, 0..1), and the same correlation two
## periods on, over a voice's 60-350 Hz. The SHORTEST lag within 90% of the best wins, so a
## stretch that also matches itself two periods on does not read as an octave down.
static func period_of(pcm: PackedFloat32Array, s0: int, n: int, sr: int) -> Vector3:
	var lo := int(float(sr) / 350.0)
	var hi := int(float(sr) / 60.0)
	if s0 < 0 or s0 + n + hi + 1 > pcm.size():
		return Vector3.ZERO
	var e0 := 0.0
	for i in range(0, n, 2):
		e0 += pcm[s0 + i] * pcm[s0 + i]
	if e0 <= 1e-9:
		return Vector3.ZERO
	var rs := PackedFloat32Array()
	rs.resize(hi + 2)
	var best := 0.0
	for lag in range(lo, hi + 2):
		rs[lag] = _corr_at(pcm, s0, n, lag, e0)
		best = maxf(best, rs[lag])
	for lag in range(lo + 1, hi + 1):
		if rs[lag] >= 0.9 * best and rs[lag] >= rs[lag - 1] and rs[lag] >= rs[lag + 1]:
			# parabolic refinement: the true period is rarely a whole number of samples,
			# and a whole-sample hop drifts a sample every few periods
			var den := rs[lag - 1] - 2.0 * rs[lag] + rs[lag + 1]
			var off := 0.0 if absf(den) < 1e-9 else clampf(0.5 * (rs[lag - 1] - rs[lag + 1]) / den, -0.5, 0.5)
			# two periods on, searched a couple of samples either way for the pitch drift
			var twice := 0.0
			for l2 in range(2 * lag - 2, 2 * lag + 3):
				if s0 + n + l2 <= pcm.size():
					twice = maxf(twice, _corr_at(pcm, s0, n, l2, e0))
			return Vector3(float(lag) + off, rs[lag], twice)
	return Vector3.ZERO


## Normalized correlation of pcm[s0, s0 + n) with itself [param lag] on, every other sample.
static func _corr_at(pcm: PackedFloat32Array, s0: int, n: int, lag: int, e0: float) -> float:
	var r := 0.0
	var e1 := 0.0
	for i in range(0, n, 2):
		var y := pcm[s0 + i + lag]
		r += pcm[s0 + i] * y
		e1 += y * y
	return r / sqrt(e0 * maxf(e1, 1e-9))


## The mark near [param guess] whose period best matches the one about [param c], searched a
## sixth of a period either way - a hum's pitch drifts, so a mark a whole period away is
## rarely exactly where arithmetic puts it.
static func _align_mark(pcm: PackedFloat32Array, c: int, guess: int, half: int) -> int:
	var reach := maxi(1, half / 6)
	var best := guess
	var best_r := -INF
	for m in range(guess - reach, guess + reach + 1):
		if m - half < 0 or m + half >= pcm.size():
			continue
		var r := 0.0
		for d in range(-half / 2, half / 2):
			r += pcm[c + d] * pcm[m + d]
		if r > best_r:
			best_r = r
			best = m
	return best


## Energy of one period centered on [param m].
static func _grain_energy(pcm: PackedFloat32Array, m: int, half: int) -> float:
	var e := 0.0
	for d in range(-half / 2, half / 2):
		if m + d >= 0 and m + d < pcm.size():
			e += pcm[m + d] * pcm[m + d]
	return e


## A word timing from the model's clock onto the spliced take's: divided by the resample
## ratio, then moved by every rest spliced in before it. A START at exactly a cut is moved
## (the rest precedes that word); an END at exactly a cut is not (the rest follows it).
static func shifted(t: float, cuts: Array, ratio: float, is_start: bool) -> float:
	var add := 0.0
	for c in cuts:
		var ct := float(c["t"])
		if ct < t or (is_start and is_equal_approx(ct, t)):
			add += float(c["add"])
	return t / ratio + add


## PCM16 mono, as written by the voice host. The 44-byte canonical header is
## ours, so this does not need to be a general WAV parser.
static func read_wav(path: String) -> PackedFloat32Array:
	return decode_wav(path)


## The same, static, for a worker thread (the audition decodes off the main thread).
static func decode_wav(path: String) -> PackedFloat32Array:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return PackedFloat32Array()
	var bytes := f.get_buffer(f.get_length())
	f.close()
	if bytes.size() <= 44:
		return PackedFloat32Array()
	var n := (bytes.size() - 44) / 2
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		out[i] = float(bytes.decode_s16(44 + i * 2)) / 32768.0
	return out


## PCM16 WAV, written atomically - the exporter's render process may open
## this file while we are still writing it otherwise, which is how a truncated
## take once made a render record silence forever. One channel writes each frame's
## left (with no lean the two are the same), two write both.
static func write_wav(path: String, frames: PackedVector2Array, channels: int, sr: int) -> String:
	var tmp := path + ".part"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return ""
	var bytes := PackedByteArray()
	bytes.resize(frames.size() * 2 * channels)
	for i in frames.size():
		var v := frames[i]
		bytes.encode_s16(i * 2 * channels, int(clampf(v.x, -1.0, 1.0) * 32767.0))
		if channels == 2:
			bytes.encode_s16(i * 4 + 2, int(clampf(v.y, -1.0, 1.0) * 32767.0))
	f.store_buffer("RIFF".to_ascii_buffer()); f.store_32(36 + bytes.size())
	f.store_buffer("WAVE".to_ascii_buffer()); f.store_buffer("fmt ".to_ascii_buffer())
	f.store_32(16); f.store_16(1); f.store_16(channels); f.store_32(sr)
	f.store_32(sr * 2 * channels); f.store_16(2 * channels); f.store_16(16)
	f.store_buffer("data".to_ascii_buffer()); f.store_32(bytes.size())
	f.store_buffer(bytes)
	f.close()
	var abs_tmp := ProjectSettings.globalize_path(tmp)
	var abs_out := ProjectSettings.globalize_path(path)
	if DirAccess.rename_absolute(abs_tmp, abs_out) != OK:
		return abs_tmp
	return abs_out
