extends Node
class_name VoiceStream

## VoiceStream - the formant voice ([Voice]) spoken live on its own thread, on a player of its own: the
## Lab's fishing game ([VoiceFishing]) hears its line through it.
##
## Synthesis and audio delivery run on a worker thread decoupled from the render loop: the thread keeps
## a sliding lead (~[constant TARGET_LEAD]s) of PCM synthesized ahead of the playhead and pushed into
## its player's [AudioStreamGeneratorPlayback] ([method play]). The main thread only drains word-timing
## snapshots and relays completion.
##
## The stream is a live instrument, not a render job:
## - [method retune] swaps the voice spec mid-stream (an atomic reference swap the worker reads per
##   chunk), so timbre traits bend the voice while it speaks, landing ~[constant TARGET_LEAD]s later.
## - [method restart] replaces the content in place (new text or a re-planned voice): worker joined,
##   the player cycled, [method heard] from zero again.
## - presence and reception ([method set_presence], [method set_location]) are applied as samples are
##   pushed, so the game moves them per frame.
## A finished take loops on the thread; nothing is written (the reading makes the take a voice is kept in).

signal completed(dur: float)

const PREBUFFER := 0.3              # synthesized + pushed before the thread takes over
# Deep lead: the ring holds seconds of finished audio, so a machine saturated by a heavy scene (which
# can preempt this worker and the audio callback) keeps a cushion.
const TARGET_LEAD := 2.5
const SEG_CHUNK := 4                # segments per synth() call on the worker
# Presence: how close the voice is to the caster (far = quiet and dark, landed = open). Applied at push
# time - the WAV take stays the canonical full-presence render. Gain glides per sample (~0.2 s) and a
# one-pole lowpass darkens distance (~500 Hz far away, effectively open when landed).
const P_GLIDE := 0.00011            # per-sample presence glide (~0.2 s at 44.1k)

# Location reception: as the line nears the beacon, a resonant band tuned to its frequency swells into
# the voice. A state-variable bandpass (stable while the center stays well under Nyquist) blended by
# proximity, with a faint carrier of the source at close range. Applied at push time like presence, so
# the WAV take is untouched.
const LOC_GLIDE := 0.0002           # per-sample smoothing of proximity/frequency
const LOC_WET := 0.55               # max bandpass blend, at full proximity
const LOC_BP_GAIN := 1.8            # make up the bandpass's attenuation
const LOC_Q := 0.4                  # SVF damping (lower = more resonant)
const LOC_CARRIER := 0.02           # faint carrier-tone amplitude at close range
const LOC_CEIL := 0.95              # soft ceiling on the reception path: tanh rounds the resonant boost's overshoot (a hard clamp clicks)

var words: Array = []               # main-thread copy of the words said so far
var events: Array = []              # planned strike times [{t, kind, a}] - the bites

var _spec: Voice.Spec               # swapped whole by retune() - worker reads per chunk
var _segs: Array = []
var _state := {}
var _next_seg := 0
var _pcm := PackedFloat32Array()
var _pushed := 0                    # frames handed to the generator (worker-owned)
var _playback: AudioStreamGeneratorPlayback
var _player: AudioStreamPlayer      # its own ([method play])
var _thread: Thread
var _mutex := Mutex.new()
var _cancel := false
var _words_snapshot: Array = []     # worker-written duplicates, mutex-guarded
var _words_dirty := false
var _done := false
var _finish_info: Array = []        # [dur] once, mutex-guarded
var _emitted_done := false
var _underruns := 0                 # telemetry: times the ring went dry (see worker)
var _gain := 1.0                    # the voice's level gain, set from the main thread (atomic; [method set_gain])
var _gn := -1.0                     # worker-side glided gain (-1: not yet started, takes the first at once)
var _presence := 1.0                # target, set from the main thread (atomic)
var _pg := 0.0                      # worker-side glided gain (streams fade IN)
var _lp := 0.0                      # distance lowpass state
var _loc_prox := 0.0                # target proximity to the source (main-set, atomic)
var _loc_freq := 400.0              # target source frequency Hz (main-set, atomic)
var _loc_prox_s := 0.0              # worker-side smoothed proximity
var _loc_freq_s := 400.0            # worker-side smoothed frequency
var _svf_low := 0.0                 # state-variable filter states (worker-owned)
var _svf_band := 0.0
var _svf_f := 0.1                   # SVF frequency coefficient, refreshed periodically
var _loc_env := 0.0                 # smoothed |signal| for the carrier ride
var _loc_ph := 0.0                  # carrier phase
var _restarting := false            # restart() is async (fade-cut); latest wins
var _restart_queue: Array = []


func setup(text: String, spec: Voice.Spec) -> void:
	_spec = spec
	events.clear()
	_segs = Voice.plan(text, spec, events)
	_state = Voice.synth_state(spec)


## Start speaking on a player of its own, on bus [param bus]: the prebuffer synthesized and pushed in this
## frame (pushed sample N plays at N / SR), then production handed to the worker thread. Once, after
## [method setup], in the tree.
func play(bus := &"Master") -> void:
	_player = AudioStreamPlayer.new()
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = Voice.SR
	gen.buffer_length = Spectrum.STREAM_BUFFER
	_player.stream = gen
	_player.bus = bus
	add_child(_player)
	_player.play()
	_playback = _player.get_stream_playback()
	_synth_chunks(int(PREBUFFER * Voice.SR))
	_push_available()
	_snapshot_words()
	_start_worker()


## Seconds of the current content heard so far (a finished take looping counts on); 0 before [method play].
func heard() -> float:
	return _player.get_playback_position() if _player != null and _player.playing else 0.0


## Swap the voice mid-stream (timbre traits: pitch, tract, breath, grit). An atomic reference swap read
## by the worker at its next chunk, so the bend lands about TARGET_LEAD seconds later. Plan-baked traits
## (pace, drawl, lilt) and text changes need restart() instead.
func retune(spec: Voice.Spec) -> void:
	_spec = spec


## The gain that levels this voice with every other ([method FormantVoice.gain_of]), glided as presence is: set
## before [method play] it is the first sample's, set after it eases in. Safe from any thread.
func set_gain(g: float) -> void:
	_gain = maxf(g, 0.0)


## Where the voice stands relative to the caster, 0 (far / silent) .. 1
## (landed). Applied by the push path with its own glide; safe from any thread.
func set_presence(p: float) -> void:
	_presence = clampf(p, 0.0, 1.0)


## The fishing spot's acoustics: proximity to the source (0 far .. 1 on it) and the source's frequency
## (Hz). Set from the main thread, read per sample by the push path.
func set_location(prox: float, freq: float) -> void:
	_loc_prox = clampf(prox, 0.0, 1.0)
	# under SR/6 (~3675 Hz) so the state-variable filter stays unconditionally stable
	_loc_freq = clampf(freq, 80.0, 3000.0)


## Bake the location reception effect into a rendered take, offline, at a fixed anchor (prox, freq): the
## same band and carrier the push loop applies per sample, at a held position (no glide). The export
## calls this so the file matches the live stream. Mutates and returns pcm (copy-on-write: reassign the
## result). A no-op far from any source.
static func bake_location(pcm: PackedFloat32Array, prox: float, freq: float) -> PackedFloat32Array:
	if Voice.RAW_MODE:
		return pcm                   # raw diagnostic: no reception color baked
	prox = clampf(prox, 0.0, 1.0)
	if prox <= 0.004:
		return pcm
	freq = clampf(freq, 80.0, 3000.0)
	var svf_low := 0.0
	var svf_band := 0.0
	var svf_f := 2.0 * sin(PI * freq / Voice.SR)
	var env := 0.0
	var ph := 0.0
	for i in pcm.size():
		var v := pcm[i]
		svf_low += svf_f * svf_band
		var hi: float = v - svf_low - LOC_Q * svf_band
		svf_band += svf_f * hi
		v = lerpf(v, svf_band * LOC_BP_GAIN, prox * LOC_WET)
		env += (absf(v) - env) * 0.001
		ph += TAU * freq / Voice.SR
		if ph >= TAU:
			ph -= TAU
		v += LOC_CARRIER * prox * prox * sin(ph) * (0.4 + 2.0 * env)
		pcm[i] = LOC_CEIL * tanh(v / LOC_CEIL)
	return pcm


## Replace the content in place: new plan, cleared generator buffer, timing rebased. A coroutine: the
## old audio fades out over a breath before the stop/play cycle (a raw cut pops). Callers fire and
## forget; overlapping calls queue, latest wins.
func restart(text: String, spec: Voice.Spec) -> void:
	if _restarting:
		_restart_queue = [text, spec]
		return
	_restarting = true
	_stop_worker()
	if _player != null and _player.playing:
		var tw := create_tween()
		tw.tween_property(_player, "volume_db", -60.0, 0.04)
		await tw.finished
	_spec = spec
	events.clear()
	_segs = Voice.plan(text, spec, events)
	_state = Voice.synth_state(spec)
	_next_seg = 0
	_pcm = PackedFloat32Array()
	_pushed = 0
	_done = false
	_emitted_done = false
	_finish_info = []
	_words_snapshot = []
	words.clear()
	if _player != null:
		# a generator's ring can't be cleared while active: cycle the player, which rebases playback
		# time to 0 and yields a fresh playback
		_player.stop()
		_player.volume_db = 0.0
		_player.play()
		_playback = _player.get_stream_playback()
	_pg = 0.0                        # fade the new content in from silence
	_lp = 0.0
	_synth_chunks(int(PREBUFFER * Voice.SR))
	_push_available()
	_snapshot_words()
	_start_worker()
	_restarting = false
	if not _restart_queue.is_empty():
		var queued: Array = _restart_queue
		_restart_queue = []
		restart(queued[0], queued[1])


## Main thread, per frame: drain the worker's word snapshots into the shared
## array and relay the completion signal. Deliberately tiny.
func _process(_delta: float) -> void:
	if _words_dirty:
		_mutex.lock()
		words.clear()
		words.append_array(_words_snapshot)
		_words_dirty = false
		_mutex.unlock()
	if not _emitted_done:
		_mutex.lock()
		var info := _finish_info
		_mutex.unlock()
		if info.size() == 1:
			_emitted_done = true
			completed.emit(info[0])


func _exit_tree() -> void:
	_stop_worker()


# ---- worker ----------------------------------------------------------------


func _start_worker() -> void:
	_cancel = false
	_thread = Thread.new()
	# high priority: when a heavy scene saturates every core the voice must win the scheduler (the
	# render may lag; the audio may not)
	_thread.start(_worker_loop, Thread.PRIORITY_HIGH)


func _stop_worker() -> void:
	if _thread != null:
		_cancel = true
		_thread.wait_to_finish()
		_thread = null
	_cancel = false


func _worker_loop() -> void:
	var started := false
	while not _cancel:
		var worked := false
		var queued := _generator_capacity() - int(_playback.get_frames_available())
		if _next_seg < _segs.size():
			var consumed := maxi(0, _pushed - queued)
			if float(_pcm.size() - consumed) / Voice.SR < TARGET_LEAD:
				_synth_one_chunk()
				_snapshot_words()
				worked = true
				if _next_seg >= _segs.size():
					_finish_take()
		# underrun telemetry: the generator ring going dry mid-take must never happen silently
		if started and queued <= 0 and _pushed > 0:
			_underruns += 1
			if _underruns == 1 or _underruns % 50 == 0:
				print("ghost: VOICE UNDERRUN x%d (ring dry - report this)" % _underruns)
		if queued > 0:
			started = true
		_push_available()
		if not worked:
			OS.delay_msec(4)


func _synth_chunks(target_frames: int) -> void:
	while _next_seg < _segs.size() and _pcm.size() < target_frames:
		_synth_one_chunk()


func _synth_one_chunk() -> void:
	var j := mini(_next_seg + SEG_CHUNK, _segs.size())
	var result := Voice.synth(_segs, _spec, _next_seg, j, _state)
	_next_seg = j
	_pcm = result.pcm


func _snapshot_words() -> void:
	var live: Array = _state.words
	_mutex.lock()
	_words_snapshot = []
	for w in live:
		_words_snapshot.append((w as Dictionary).duplicate())
	_words_dirty = true
	_mutex.unlock()


## Push whatever the generator has room for: fresh frames while synthesizing,
## then loop passes over the finished take forever.
func _push_available() -> void:
	if _playback == null or _pcm.is_empty():
		return
	var room := int(_playback.get_frames_available())
	while room > 0:
		var src := _pushed if not _done else _pushed % _pcm.size()
		if not _done and src >= _pcm.size():
			break                    # synthesis hasn't caught up; next pass
		var n := mini(room, _pcm.size() - src)
		if n <= 0:
			break
		var buf := PackedVector2Array()
		buf.resize(n)
		var target := _presence
		var kk := 0.0
		if _gn < 0.0:
			_gn = _gain
		if Voice.RAW_MODE:
			# raw diagnostic: the take reaches the bus untouched
			for i in n:
				_gn += (_gain - _gn) * P_GLIDE
				var vr := _pcm[src + i] * _gn
				buf[i] = Vector2(vr, vr)
			_playback.push_buffer(buf)
			_pushed += n
			room -= n
			continue
		for i in n:
			_pg += (target - _pg) * P_GLIDE
			_gn += (_gain - _gn) * P_GLIDE
			var v := _pcm[src + i] * _gn
			if _pg < 0.995:
				# distance: darker and a little quieter the further out; the filter carries the cue and
				# the gain is linear (a squared gain buries a fresh cast at ~8% amplitude). The
				# coefficient refreshes every 64 samples as the glide moves.
				if (i & 63) == 0:
					# the floor is high and the filter opens early: distance darkens without strangling
					var cut := 900.0 * pow(2.0, 4.0 * _pg)
					kk = 1.0 - exp(-TAU * cut / Voice.SR)
				_lp += kk * (v - _lp)
				v = _lp * _pg
			# location reception: a resonant band tuned to the source plus a faint carrier at close
			# range (see the LOC_ consts); skipped when far from any source
			_loc_prox_s += (_loc_prox - _loc_prox_s) * LOC_GLIDE
			if _loc_prox_s > 0.004:
				_loc_freq_s += (_loc_freq - _loc_freq_s) * LOC_GLIDE
				if (i & 31) == 0:
					_svf_f = 2.0 * sin(PI * _loc_freq_s / Voice.SR)
				_svf_low += _svf_f * _svf_band
				var hi: float = v - _svf_low - LOC_Q * _svf_band
				_svf_band += _svf_f * hi
				v = lerpf(v, _svf_band * LOC_BP_GAIN, _loc_prox_s * LOC_WET)
				_loc_env += (absf(v) - _loc_env) * 0.001
				_loc_ph += TAU * _loc_freq_s / Voice.SR
				if _loc_ph >= TAU:
					_loc_ph -= TAU
				v += LOC_CARRIER * _loc_prox_s * _loc_prox_s * sin(_loc_ph) * (0.4 + 2.0 * _loc_env)
				v = LOC_CEIL * tanh(v / LOC_CEIL)   # overshoot ROUNDS, never clips
			buf[i] = Vector2(v, v)
		_playback.push_buffer(buf)
		_pushed += n
		room -= n


func _generator_capacity() -> int:
	# frames in the generator's ring (buffer_length * mix rate); frames_available counts free space
	return int(Spectrum.STREAM_BUFFER * Voice.SR)


## Worker-side: the take is fully synthesized and loops from here; the main thread emits `completed`.
func _finish_take() -> void:
	_done = true
	var dur := float(_pcm.size()) / Voice.SR
	_mutex.lock()
	_finish_info = [dur]
	_mutex.unlock()
