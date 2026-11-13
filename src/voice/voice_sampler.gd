extends PanelContainer
class_name VoiceSampler

## VoiceSampler - "echo a living voice": record the player reading the passage every voice is tested with (handed
## to [method open]), measure the voice
## (the recording is never kept), and mint a new seed whose traits and prosody genome mimic the source.
##
## What leaves this panel is ~20 scalars: a trait vector (the closed-form inversions of
## [Voice.Spec.from_traits]) and a partial walk genome (the measured keys; [Voice.ProsodyWalk] backfills
## the rest from its prior, as for a frozen adrenochrome genome). The voice stays synthetic - the seed
## sits where the living voice sits: pitch, tempo, breathiness, pausing, melodic spread.
##
## Recording is the stock Godot microphone pattern: an [AudioStreamMicrophone] played onto a muted bus
## carrying an [AudioEffectRecord], heard through the system's default microphone (no device is asked for:
## the sound goes on playing where ghost plays it, and the input is the one the system already uses). The Master bus is pulled down while the mic is open, so the take
## cannot bleed into the measurement. Analysis runs on a [WorkerThreadPool] thread; `seed_ready` fires
## back on the main thread.

signal seed_ready(traits: Dictionary, genome: Dictionary, report: String)

const BUS_NAME := "VoiceIn"
const MIN_SECONDS := 8.0            # too little speech = statistics of nothing
const MAX_SECONDS := 120.0          # auto-stop; the Test passage reads in about a minute

var _words: Label                   # the passage read aloud, handed to [method open]
var _record_btn: Button
var _cancel_btn: Button
var _status: Label
var _player: AudioStreamPlayer
var _effect: AudioEffectRecord
var _recording := false
var _analyzing := false
var _rec_t := 0.0
var _master_vol := 0.0              # restored when the booth closes
var _show_quiet := false            # the Master mute is engaged


func _ready() -> void:
	visible = false
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	add_child(col)
	var title := Label.new()
	title.text = "echo a living voice"
	title.add_theme_font_size_override("font_size", 13)
	title.add_theme_color_override("font_color", Color(0.75, 0.95, 0.85))
	col.add_child(title)
	var hint := Label.new()
	hint.text = ("Read the passage below, naturally - the instrument measures the "
		+ "READING (pitch, tempo, pauses, breath), never keeps the audio, and "
		+ "mints a new seed that sits where your voice sits.")
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 10)
	hint.modulate = Color(1, 1, 1, 0.6)
	col.add_child(hint)
	_words = Label.new()
	_words.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_words.add_theme_font_size_override("font_size", 12)
	_words.add_theme_color_override("font_color", Color(0.9, 0.9, 0.8))
	col.add_child(_words)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	col.add_child(row)
	_record_btn = Button.new()
	_record_btn.text = "Record"
	_record_btn.custom_minimum_size = Vector2(90, 26)
	_record_btn.pressed.connect(_toggle_record)
	row.add_child(_record_btn)
	_cancel_btn = Button.new()
	_cancel_btn.text = "Cancel"
	_cancel_btn.custom_minimum_size = Vector2(70, 26)
	_cancel_btn.pressed.connect(close)
	row.add_child(_cancel_btn)
	_status = Label.new()
	_status.add_theme_font_size_override("font_size", 11)
	_status.modulate = Color(1, 1, 1, 0.75)
	col.add_child(_status)
	# the bus is created once, at boot: reshaping the bus layout while the mixer is live can corrupt
	# state under the audio thread
	_ensure_bus()


## Open the booth on [param passage]: the words every voice is tested with, so an echo is heard on the same ones.
func open(passage: String) -> void:
	if _analyzing:
		return
	_words.text = passage
	# the show goes quiet when the booth opens, or a looping voice would read into the microphone
	_set_show_quiet(true)
	_status.text = "press Record and read the passage aloud - your system's microphone listens"
	visible = true


func close() -> void:
	if _recording:
		_abort_recording()
	if _player != null:
		_player.stop()
	_set_show_quiet(false)
	visible = false


func _ensure_bus() -> void:
	var idx := AudioServer.get_bus_index(BUS_NAME)
	if idx < 0:
		idx = AudioServer.bus_count
		AudioServer.add_bus(idx)
		AudioServer.set_bus_name(idx, BUS_NAME)
		# muted so the mic never reaches the speakers, but a muted bus still feeds its effects
		AudioServer.set_bus_mute(idx, true)
		_effect = AudioEffectRecord.new()
		_effect.format = AudioStreamWAV.FORMAT_16_BITS
		AudioServer.add_bus_effect(idx, _effect)
	if _player == null:
		_player = AudioStreamPlayer.new()
		_player.stream = AudioStreamMicrophone.new()
		_player.bus = BUS_NAME
		add_child(_player)


func _toggle_record() -> void:
	if _analyzing:
		return
	if _recording:
		_finish_recording()
	else:
		_start_recording()


## Quiet (or restore) the whole show while the recording booth is open. The mute is on the Master bus
## volume so everything the mic could overhear goes down together; calls must be balanced.
func _set_show_quiet(quiet: bool) -> void:
	if quiet == _show_quiet:
		return
	_show_quiet = quiet
	if quiet:
		_master_vol = AudioServer.get_bus_volume_db(0)
		AudioServer.set_bus_volume_db(0, -60.0)
	else:
		AudioServer.set_bus_volume_db(0, _master_vol)


func _start_recording() -> void:
	_player.play()
	_effect.set_recording_active(true)
	_recording = true
	_rec_t = 0.0
	_record_btn.text = "Stop"
	_status.text = "listening - read the passage"


func _abort_recording() -> void:
	_effect.set_recording_active(false)
	_player.stop()
	_recording = false
	_record_btn.text = "Record"


func _finish_recording() -> void:
	var wav := _effect.get_recording()
	_abort_recording()
	if _rec_t < MIN_SECONDS or wav == null:
		_status.text = "too short to measure - read at least %.0f s of the passage" % MIN_SECONDS
		return
	var mono := _wav_to_mono(wav)
	if mono.pcm.size() < int(mono.sr * MIN_SECONDS * 0.5):
		_status.text = "the microphone gave almost no audio - is it the one your system's sound settings use?"
		return
	_analyzing = true
	_record_btn.disabled = true
	_status.text = "developing the echo..."
	var pcm: PackedFloat32Array = mono.pcm
	var sr: float = mono.sr
	WorkerThreadPool.add_task(func() -> void:
		var out := VoiceSampler.analyze(pcm, sr)
		call_deferred("_analysis_done", out))


func _analysis_done(out: Dictionary) -> void:
	_analyzing = false
	_record_btn.disabled = false
	if out.is_empty():
		_status.text = "the echo would not develop - too quiet or too short; try again"
		return
	_status.text = "echoed: " + String(out.report)
	seed_ready.emit(out.traits, out.genome, out.report)
	close()                          # restores the show's volume


func _exit_tree() -> void:
	# shutdown: never leave the record effect or the mic stream live while the audio driver tears down, nor the show
	# turned down for a booth nobody can see
	if _recording and _effect != null:
		_effect.set_recording_active(false)
	if _player != null:
		_player.stop()
	_set_show_quiet(false)


func _process(delta: float) -> void:
	if not _recording:
		return
	_rec_t += delta
	_status.text = "listening - %.0f s (Stop when you have read it)" % _rec_t
	if _rec_t >= MAX_SECONDS:
		_finish_recording()


static func _wav_to_mono(wav: AudioStreamWAV) -> Dictionary:
	var bytes := wav.data
	var stride := 2 * (2 if wav.stereo else 1)
	var n := bytes.size() / stride
	var pcm := PackedFloat32Array()
	pcm.resize(n)
	for i in n:
		var v := float(bytes.decode_s16(i * stride)) / 32767.0
		if wav.stereo:
			v = (v + float(bytes.decode_s16(i * stride + 2)) / 32767.0) * 0.5
		pcm[i] = v
	return {"pcm": pcm, "sr": float(wav.mix_rate)}


# ---- the measurement --------------------------------------------------------
# Static and UI-free so tests/voice/sampler_check.gd can round-trip it headless against synthesized
# voices with known traits.


## Analyze a mono recording into {traits, genome, report}, or {} if there is
## not enough usable speech. Deterministic per input.
static func analyze(pcm: PackedFloat32Array, sr: float) -> Dictionary:
	# two decimation ladders: ~5.5 kHz for f0/periodicity (cheap autocorrelation lags), ~8 kHz for
	# energy and band balance
	var x0 := _decimate(pcm, maxi(int(round(sr / 5500.0)), 1))
	var fs0 := sr / float(maxi(int(round(sr / 5500.0)), 1))
	var x8 := _decimate(pcm, maxi(int(round(sr / 8000.0)), 1))
	var fs8 := sr / float(maxi(int(round(sr / 8000.0)), 1))
	# cap analysis to the middle ~24 s (enough statistics, bounded compute)
	x0 = _middle(x0, int(fs0 * 24.0))
	x8 = _middle(x8, int(fs8 * 24.0))
	var hop0 := int(fs0 * 0.02)
	var corr_n := int(fs0 * 0.025)
	var lag_lo := maxi(int(fs0 / 400.0), 2)
	var lag_hi := int(fs0 / 70.0)
	var nframes := (x0.size() - (lag_hi + corr_n + 1)) / hop0
	if nframes < 150:                # < ~3 s of frames: nothing to measure
		return {}
	var f0s := PackedFloat32Array()
	var voiced := PackedByteArray()
	var periodicity := PackedFloat32Array()
	f0s.resize(nframes)
	voiced.resize(nframes)
	periodicity.resize(nframes)
	var energies := PackedFloat32Array()
	energies.resize(nframes)
	var hf := PackedFloat32Array()   # fraction of frame energy above ~1.1 kHz
	hf.resize(nframes)
	var hop8 := int(fs8 * 0.02)
	var win8 := int(fs8 * 0.025)
	var lp_k := 1.0 - exp(-TAU * 1100.0 / fs8)
	for f in nframes:
		var a0 := f * hop0
		# energy + band split on the 8 kHz ladder
		var a8 := mini(f * hop8, maxi(x8.size() - win8 - 1, 0))
		var e_all := 0.0
		var e_hi := 0.0
		var lp := 0.0
		for i in win8:
			var v := x8[a8 + i]
			lp += lp_k * (v - lp)
			e_all += v * v
			e_hi += (v - lp) * (v - lp)
		energies[f] = sqrt(e_all / float(win8))
		hf[f] = e_hi / maxf(e_all, 0.0000001)
		# autocorrelation f0 (coarse lag sweep, then refine)
		var e0 := 0.0
		for i in corr_n:
			e0 += x0[a0 + i] * x0[a0 + i]
		if e0 < 0.00000004:
			continue                 # silence; stays unvoiced
		var best_lag := 0
		var best_r := 0.0
		var lags_arr := PackedInt32Array()
		var rs_arr := PackedFloat32Array()
		var lag := lag_lo
		while lag <= lag_hi:
			var s := 0.0
			var e1 := 0.0
			for i in corr_n:
				s += x0[a0 + i] * x0[a0 + i + lag]
				e1 += x0[a0 + i + lag] * x0[a0 + i + lag]
			var r := s / sqrt(maxf(e0 * e1, 0.000000000001))
			lags_arr.append(lag)
			rs_arr.append(r)
			if r > best_r:
				best_r = r
				best_lag = lag
			lag += 2
		# octave robustness: a subharmonic lock often scores a hair above the true period and flips
		# the track down an octave, so take the shortest lag within 90% of the best correlation
		for k in lags_arr.size():
			if rs_arr[k] >= best_r * 0.9:
				best_lag = lags_arr[k]
				best_r = rs_arr[k]
				break
		for cand in [best_lag - 1, best_lag + 1]:
			if cand < lag_lo or cand > lag_hi:
				continue
			var s2 := 0.0
			var e2 := 0.0
			for i in corr_n:
				s2 += x0[a0 + i] * x0[a0 + i + cand]
				e2 += x0[a0 + i + cand] * x0[a0 + i + cand]
			var r2 := s2 / sqrt(maxf(e0 * e2, 0.000000000001))
			if r2 > best_r:
				best_r = r2
				best_lag = cand
		periodicity[f] = best_r
		if best_r > 0.55 and best_lag > 0:
			voiced[f] = 1
			f0s[f] = fs0 / float(best_lag)
	# ---- aggregate ----------------------------------------------------------
	var vf0: Array = []
	var vper: Array = []
	var vhf: Array = []
	for f in nframes:
		if voiced[f] == 1:
			vf0.append(f0s[f])
			vper.append(periodicity[f])
			vhf.append(hf[f])
	if vf0.size() < 80:              # < ~1.6 s of voiced speech
		return {}
	var f0_med := _median(vf0)
	# melodic spread in semitones (p85 - p15 around the median)
	var semis: Array = []
	for v in vf0:
		semis.append(12.0 * log(v / f0_med) / log(2.0))
	semis.sort()
	var spread: float = semis[int(semis.size() * 0.85)] - semis[int(semis.size() * 0.15)]
	# melodic modes: the histogram of where the melody sits (0.5 st bins, smoothed). Its peaks are the
	# recording's own pitch anchors (they replace the seeded shelf, see Voice.ProsodyWalk), and the
	# share of melody on them is the gravity: how strongly this speaker quantizes toward their notes.
	var nbins := 57
	var hist := PackedFloat32Array()
	hist.resize(nbins)
	for s in semis:
		hist[mini(int(round((clampf(float(s), -14.0, 14.0) + 14.0) * 2.0)), nbins - 1)] += 1.0
	var hsm := PackedFloat32Array()
	hsm.resize(nbins)
	var hmax := 0.0
	for b in nbins:
		hsm[b] = (hist[maxi(b - 1, 0)] + hist[b] + hist[mini(b + 1, nbins - 1)]) / 3.0
		hmax = maxf(hmax, hsm[b])
	var modes: Array = []
	for b in range(1, nbins - 1):
		if hsm[b] >= hsm[b - 1] and hsm[b] > hsm[b + 1] and hsm[b] > hmax * 0.2:
			modes.append([float(b) * 0.5 - 14.0, hsm[b]])
	modes.sort_custom(func(m1, m2): return float(m1[1]) > float(m2[1]))
	var anchors: Array = []
	for k in mini(modes.size(), 5):
		anchors.append(float(modes[k][0]))
	var near := 0
	for s in semis:
		for a in anchors:
			if absf(float(s) - float(a)) <= 0.5:
				near += 1
				break
	var gravity := clampf((float(near) / maxf(float(semis.size()), 1.0) - 0.3) * 1.6, 0.0, 0.8)
	# jitter proxy: second difference of the voiced f0 track (drops the slow intonation trend)
	var jits: Array = []
	for i in range(1, vf0.size() - 1):
		jits.append(absf(float(vf0[i]) - (float(vf0[i - 1]) + float(vf0[i + 1])) * 0.5) / f0_med)
	var jitter := _median(jits)
	# envelope, pauses, syllable peaks (20 ms frames)
	var env := PackedFloat32Array()
	env.resize(nframes)
	var sm := 0.0
	for f in nframes:
		sm = lerpf(sm, energies[f], 0.45)
		env[f] = sm
	var e_sorted: Array = []
	for f in nframes:
		e_sorted.append(env[f])
	e_sorted.sort()
	var e95: float = e_sorted[int(e_sorted.size() * 0.95)]
	if e95 < 0.004:
		return {}                    # effectively silence
	var pauses: Array = []           # seconds each
	var run_len := 0
	for f in nframes:
		if env[f] < e95 * 0.07:
			run_len += 1
		else:
			if run_len * 0.02 >= 0.15:
				pauses.append(run_len * 0.02)
			run_len = 0
	# syllable nuclei: peaks of a re-smoothed envelope. The raw EMA envelope wobbles with amplitude
	# modulation and splits long vowels into extra peaks, so the rate would scale with duration; a
	# centered boxcar plus a wider refractory keeps one peak per nucleus.
	var env2 := PackedFloat32Array()
	env2.resize(nframes)
	for f in nframes:
		env2[f] = (env[maxi(f - 1, 0)] + env[f] + env[mini(f + 1, nframes - 1)]) / 3.0
	var peaks: Array = []            # frame indices of syllable nuclei
	var last_pk := -100
	for f in range(1, nframes - 1):
		if env2[f] > env2[f - 1] and env2[f] >= env2[f + 1] \
				and env2[f] > e95 * 0.25 and f - last_pk >= 8:
			peaks.append(f)
			last_pk = f
	if peaks.size() < 10:
		return {}
	var speech_time := 0.0
	for f in nframes:
		if env[f] >= e95 * 0.07:
			speech_time += 0.02
	var syll_rate: float = float(peaks.size()) / maxf(speech_time, 1.0)
	# cadence range from 2 s windows: the walk realizes tempo as a journey between pace_hot and
	# pace_calm, so measure the recording's own percentiles and hand it that range
	var wrates: Array = []
	var wstart := 0
	while wstart + 100 <= nframes:
		var pc := 0
		for p in peaks:
			if p >= wstart and p < wstart + 100:
				pc += 1
		var sp := 0.0
		for f in range(wstart, wstart + 100):
			if env[f] >= e95 * 0.07:
				sp += 0.02
		if sp >= 1.0:
			wrates.append(float(pc) / sp)
		wstart += 50
	wrates.sort()
	var rate_lo := syll_rate
	var rate_hi := syll_rate
	if wrates.size() > 3:
		rate_lo = float(wrates[int(wrates.size() * 0.2)])
		rate_hi = float(wrates[int(wrates.size() * 0.8)])
	# early vs late tempo (the walk's heat: arrive hot, settle)
	var mid: float = float(nframes) / 2.0
	var early := 0
	var late := 0
	for p in peaks:
		if float(p) < mid:
			early += 1
		else:
			late += 1
	var heat_ratio: float = (float(early) + 1.0) / (float(late) + 1.0)
	# emphasis events: peaks that stand well over the envelope
	var emph: Array = []
	for p in peaks:
		if env[p] > e95 * 0.6:
			emph.append(p)
	var emph_spacing := 2.4
	if emph.size() >= 2:
		var gaps: Array = []
		for i in range(1, emph.size()):
			gaps.append((float(emph[i]) - float(emph[i - 1])) * 0.02)
		emph_spacing = _median(gaps)
	var pause_med: float = _median(pauses) if pauses.size() > 0 else 0.2
	var sylls_per_pause: float = float(peaks.size()) / maxf(float(pauses.size()), 1.0)
	var aper := 1.0 - _median(vper)  # voiced aperiodicity = breathiness proxy
	var hf_med := _median(vhf)
	# ---- the vocal tract, for real: LPC formants over the vowel cores -------
	var fm := _formants(x8, fs8, hop8, voiced, energies, e95)
	# ---- traits: the closed-form inversions of Spec.from_traits -------------
	var pitch := clampf(log(f0_med / 130.0) / log(2.0) / 0.85, -1.0, 1.0)
	var tract := clampf(0.6 * pitch + 1.2 * (hf_med - 0.25), -1.0, 1.0)
	if float(fm[0]) > 0.0 and float(fm[1]) > 0.0:
		# formant_scale = 2^(0.22 * tract); the measured F1/F2 medians against the reference vowel
		# space give the scale directly (log-mean of the two ratios)
		tract = clampf((log(float(fm[0]) / F1_REF) + log(float(fm[1]) / F2_REF))
			/ log(2.0) * 0.5 / 0.22, -1.0, 1.0)
	var traits := {
		"pitch": pitch,
		"lilt": clampf((spread - 5.0) / 5.0, -1.0, 1.0),
		"pace": clampf(log(syll_rate / 4.2) / log(2.0) / 0.35, -1.0, 1.0),
		"drawl": clampf(log(maxf(pause_med, 0.05) / 0.42) / log(1.6), -1.0, 1.0),
		"breath": clampf((aper - 0.22) / 0.28, -1.0, 1.0),
		"grit": clampf(log(maxf(jitter, 0.002) / 0.012) / log(2.2), -1.0, 1.0),
		"air": clampf((hf_med - 0.2) / 0.3, -1.0, 1.0),
		"tract": tract,
	}
	# ---- genome: the measured keys, plus the ornament clamp; the PRIOR fills
	# the rest. The reserved "anchors" key carries the melody's own notes.
	var genome := {
		"heat": clampf(1.35 * pow(heat_ratio, 1.5), 0.6, 2.4),
		"breath_span": clampf(sylls_per_pause, 3.0, 20.0),
		"spend_window": clampf(emph_spacing, 0.8, 5.0),
		"lean": clampf(float(emph.size()) / maxf(float(peaks.size()), 1.0) * 4.0, 0.3, 2.2),
		"act_thr": clampf(3.2 - 2.2 * float(emph.size()) / maxf(speech_time, 1.0), 0.6, 3.2),
		"pace_hot": clampf(syll_rate / maxf(rate_hi, 0.1), 0.6, 1.1),
		"pace_calm": clampf(syll_rate / maxf(rate_lo, 0.1), 0.9, 1.7),
		"gravity": gravity,
		# the rolled ornament layer is clamped down so nothing performs what the recording never did:
		# heavy damp starves spawned oscillators, low verve keeps descendants refining, moderate
		# act_gain keeps the sparse activations (echo, swell, stretch) from firing theatrically
		"damp": 0.8,
		"verve": 0.15,
		"act_gain": 0.7,
		"anchors": anchors,
	}
	var report := "f0 %d Hz, %.1f-%.1f syll/s, %.0f ms pauses, %.0f%% breath, %d notes, F1/F2 %s Hz" % [
		int(f0_med), rate_lo, rate_hi, pause_med * 1000.0,
		clampf(aper, 0.0, 1.0) * 100.0, anchors.size(),
		("%d/%d" % [int(fm[0]), int(fm[1])]) if float(fm[0]) > 0.0 else "untracked"]
	return {"traits": traits, "genome": genome, "report": report}


# Reference vowel-space medians: what _formants measures at formant_scale 1.0, the anchor the tract
# inversion measures against (the geometric midpoint of tract +-0.7 renderings measured by this
# estimator; tests/voice/sampler_check.gd round-trips it).
const F1_REF := 458.0
const F2_REF := 1720.0


## LPC formant estimate: median F1/F2 across strong voiced frames. Levinson-Durbin on pre-emphasized
## 30 ms frames; the envelope's peaks are picked on a coarse frequency grid. Returns [F1_med, F2_med,
## frames_used]; F1_med <= 0 when tracking failed (too few clean frames).
static func _formants(x8: PackedFloat32Array, fs8: float, hop8: int,
		voiced: PackedByteArray, energies: PackedFloat32Array, e95: float) -> Array:
	var order := 10
	var win := int(fs8 * 0.03)
	var f1s: Array = []
	var f2s: Array = []
	var stride := 2                  # every other voiced frame is plenty
	var fidx := 0
	for f in voiced.size():
		if voiced[f] != 1 or energies[f] < e95 * 0.3:
			continue
		fidx += 1
		if fidx % stride != 0:
			continue
		var a8 := f * hop8
		if a8 + win + 1 >= x8.size():
			break
		# pre-emphasis flattens the source tilt: what remains is the TRACT
		var y := PackedFloat32Array()
		y.resize(win)
		for i in win:
			y[i] = x8[a8 + i + 1] - 0.97 * x8[a8 + i]
		var r := PackedFloat32Array()
		r.resize(order + 1)
		for lag in order + 1:
			var s := 0.0
			for i in win - lag:
				s += y[i] * y[i + lag]
			r[lag] = s
		if r[0] <= 0.0000001:
			continue
		# Levinson-Durbin recursion for the all-pole coefficients
		var a := PackedFloat32Array()
		a.resize(order + 1)
		a[0] = 1.0
		var err := r[0]
		var ok := true
		for m in range(1, order + 1):
			var acc := r[m]
			for j in range(1, m):
				acc += a[j] * r[m - j]
			var k := -acc / err
			if absf(k) >= 1.0:
				ok = false
				break
			var na := a.duplicate()
			for j in range(1, m):
				na[j] = a[j] + k * a[m - j]
			na[m] = k
			a = na
			err *= 1.0 - k * k
			if err <= 0.0:
				ok = false
				break
		if not ok:
			continue
		# envelope power 1/|A|^2 on a 25 Hz grid; local maxima are formants
		var pk_f: Array = []
		var prev := 0.0
		var prev2 := 0.0
		var prev_fq := 0.0
		var fq := 150.0
		while fq <= 3200.0:
			var w := TAU * fq / fs8
			var re := 0.0
			var im := 0.0
			for j in order + 1:
				re += a[j] * cos(w * float(j))
				im -= a[j] * sin(w * float(j))
			var p := 1.0 / maxf(re * re + im * im, 0.0000001)
			if prev > prev2 and prev >= p and prev_fq > 0.0:
				pk_f.append(prev_fq)
			prev2 = prev
			prev = p
			prev_fq = fq - 25.0
			fq += 25.0
		var f1 := 0.0
		var f2 := 0.0
		for pf in pk_f:
			if f1 <= 0.0 and float(pf) >= 220.0 and float(pf) <= 1000.0:
				f1 = float(pf)
			elif f1 > 0.0 and float(pf) >= maxf(f1 * 1.3, 800.0) and float(pf) <= 2900.0:
				f2 = float(pf)
				break
		if f1 > 0.0 and f2 > 0.0:
			f1s.append(f1)
			f2s.append(f2)
	if f1s.size() < 30:
		return [-1.0, -1.0, f1s.size()]
	return [_median(f1s), _median(f2s), f1s.size()]


static func _decimate(pcm: PackedFloat32Array, dec: int) -> PackedFloat32Array:
	if dec <= 1:
		return pcm
	var n := pcm.size() / dec
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var acc := 0.0
		var base := i * dec
		for k in dec:
			acc += pcm[base + k]
		out[i] = acc / float(dec)
	return out


static func _middle(x: PackedFloat32Array, cap: int) -> PackedFloat32Array:
	if x.size() <= cap:
		return x
	var start := (x.size() - cap) / 2
	return x.slice(start, start + cap)


static func _median(vals: Array) -> float:
	if vals.is_empty():
		return 0.0
	var s := vals.duplicate()
	s.sort()
	return float(s[s.size() / 2])
