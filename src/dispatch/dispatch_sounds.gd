extends RefCounted
class_name DispatchSounds

## DispatchSounds - the desk, heard (next/dispatch.md): a phone flipped open and snapped shut, its keys and ring, a phone
## buzzing against its neighbors, the terminal's keys and bell, the printer's screech, the radar's ping, the toggle's
## click, the mug set down, the receiver's hiss and the storms it opens up on, the gain knob's clicks, the lamp's switch,
## and the one jet that passes over while the man sleeps.
##
## Played from the desk's own schedule ([method DispatchMedium.sound_plan]): a list of what sounds when (a one-shot at a
## moment, or something that goes on from one moment to another), remade when the plan is. The medium plays it as its
## picture is drawn (live a frame at a time; in a render, the frames Movie Maker records, which records the sound too). A
## pure function of show time: begun again where the show jumped, what goes on picks up where it would be.
##
## Synthesized, as the table's are ([WorkSounds], [Soundscape]; Farnell, "Designing Sound", 2010). The phone's tones are
## the networks' own (DTMF's two tones a key; the ring the far end sends back, 400 and 450 Hz in pairs). The storms are
## Jupiter's as NASA's Radio JOVE describes them at 20.1 MHz: Io-B's S-bursts, short pops in clusters over the receiver's
## hiss; Io-A's L-bursts, long swells of noise. The jet is a moving source ([method _jet]): its whine and roar are heard
## from where it is, the pitch Doppler-shifted at the speed of sound, louder as it nears, darker as it is far, so the
## fall can be measured from a video.
##
## Subdued, as the table's: nothing under the voice peaks past [constant PEAK_MOST]; the storms and the jet, which the
## voice waits for, a little more ([constant LOUD_MOST]).

## The sounds a `sound:` mark can name ([method DispatchScript.sound_of]): its key among the mark's words. `secs` is how
## long the voice waits for it.
const SOUNDS := {
	"jet": {"label": "A jet passing over", "blurb": "A jet passes low over the building: its turbine's whine and its roar rising as it comes and falling as it goes - a real Doppler fall - and fading away.",
		"secs": 11.0},
}
## The storms the receiver opens up on (`<!-- static: 5, surf -->`; bare is popcorn).
const STORMS := {
	"popcorn": {"label": "Io-B's crackle", "blurb": "Short pops in clusters, like popcorn or pebbles on a tin roof, over the receiver's hiss - Jupiter's S-bursts."},
	"surf": {"label": "Io-A's surf", "blurb": "Long swells of noise, rising and falling like surf on a beach - Jupiter's L-bursts."},
}

## The sample rate made at, how far ahead of the show the sound is kept, how far the show may jump before it begins again
## there, the player's buffer (seconds), and the samples a control step.
const RATE := 22050
const LEAD := 0.15
const RESET := 0.35
const BUFFER := 0.5
const STEP := 256
const STILL_TICKS := 2
## The levels (full scale): the most anything under the voice peaks at, and what the voice waits for.
const PEAK_MOST := 0.06
const LOUD_MOST := 0.085
## The receiver's own hiss, always there (the note's "The receiver hisses, low"), and opened up under a storm.
const HISS := 0.0016
const HISS_OPEN := 0.02
## A storm's pops: a control slot (seconds), the most pops a second inside a cluster, and a pop's loudness and length.
const POP_SLOT := 0.004
const POP_RATE := 70.0
const POP := 0.05
const POP_LEN := 0.004
## A storm's surf: how long a swell takes (seconds, least and most) and its loudness at its crest.
const SWELL := Vector2(1.4, 3.6)
const SURF := 0.05
## The phones: a key's two tones and their length and gap (seconds), how loud in the earpiece; the ring sent back (two
## tones, the pair's on and off) and how loud; a phone buzzing - its motor (Hz), its rattle against its neighbors (knocks
## a second) - and how loud.
const DTMF_ROWS := [697.0, 770.0, 852.0, 941.0]
const DTMF_COLS := [1209.0, 1336.0, 1477.0]
const DTMF_ON := 0.11
const DTMF_GAP := 0.075
const DTMF := 0.012
const RINGBACK := [400.0, 450.0]
const RINGBACK_PAIR := [0.4, 0.2, 0.4]
const RINGBACK_LEVEL := 0.009
const BUZZ_HZ := 172.0
const RATTLE := 26.0
const BUZZ := 0.03
## The printer: its pins' screech (Hz), the head's motor (Hz) and how loud each.
const PINS_HZ := 940.0
const MOTOR_HZ := 118.0
const SCREECH := 0.022
const MOTOR := 0.008
## The radar's ping: its pitch, how long it rings, its echo (seconds after, and how loud) and its loudness.
const PING_HZ := 1180.0
const PING_RING := 0.75
const PING_ECHO := 0.36
const PING := 0.03
## The terminal's bell ([method _bell]): one short beep from its little speaker - its pitch, a near-square tone (its odd
## overtones), how long, and how loud.
const BELL_HZ := 880.0
const BELL_LEN := 0.2
const BELL := 0.022
## The jet ([method _jet]): its speed (m/s), how near it comes (m), the speed of sound (m/s), its turbine's whine (Hz) and
## its loudness at its nearest; the far air's darkening.
const JET_SPEED := 95.0
const JET_NEAR := 240.0
const SOUND_SPEED := 343.0
const WHINE_HZ := 1650.0
const JET := 0.07
## How far a thing is to one side before it is heard all the way there (meters), and how far to one side it ever goes.
const PAN_REACH := 1.1
const PAN := 0.55
## The most sounds ringing at once.
const VOICES := 48
const BURSTS := 32

var medium: Object = null        # a [DispatchMedium]: what sounds when ([method DispatchMedium.sound_plan])
var _player: AudioStreamPlayer = null
var _pb: AudioStreamGeneratorPlayback = null
var _at := NAN                   # the show time of the next sample made
var _last_t := NAN
var _still := 0
var _rng := 1
var _plan: Array = []            # the medium's sound plan, as of [member _plan_rev]
var _plan_rev := -1
var _lasting: Array = []         # ...the items of it that go on from one moment to another
var _next := 0                   # the first one-shot of the plan not yet begun
var _vw := PackedFloat32Array()  # the sines: each one's step, its glide, its level, its decay, its phase, its ears
var _vg := PackedFloat32Array()
var _va := PackedFloat32Array()
var _vk := PackedFloat32Array()
var _vph := PackedFloat32Array()
var _vl := PackedFloat32Array()
var _vr := PackedFloat32Array()
var _nv := 0
var _ba := PackedFloat32Array()  # the bursts: noise through a resonance
var _bk := PackedFloat32Array()
var _bf := PackedFloat32Array()
var _bq := PackedFloat32Array()
var _blo := PackedFloat32Array()
var _bbd := PackedFloat32Array()
var _bl := PackedFloat32Array()
var _br := PackedFloat32Array()
var _nb := 0
var _hs := PackedFloat32Array([0.0, 0.0])   # the hiss's band
var _ss := PackedFloat32Array([0.0, 0.0])   # the surf's band
var _js := PackedFloat32Array([0.0, 0.0, 0.0])   # the jet's roar
var _jph := 0.0                  # the jet's whine's phase
var _pop_slot := -1              # the storm's pop slot last looked at
var _ph := PackedFloat32Array([0, 0, 0, 0, 0, 0])   # the steady tones' phases: ringback, buzz, pins, motor


func _init(m: Object = null) -> void:
	medium = m
	# one by one: a packed array put in an Array literal is a copy, and resizing it there resizes nothing
	_vw.resize(VOICES)
	_vg.resize(VOICES)
	_va.resize(VOICES)
	_vk.resize(VOICES)
	_vph.resize(VOICES)
	_vl.resize(VOICES)
	_vr.resize(VOICES)
	_ba.resize(BURSTS)
	_bk.resize(BURSTS)
	_bf.resize(BURSTS)
	_bq.resize(BURSTS)
	_blo.resize(BURSTS)
	_bbd.resize(BURSTS)
	_bl.resize(BURSTS)
	_br.resize(BURSTS)


## The show at [param t]: the sound kept [constant LEAD] ahead of it in a player under [param host] (made the first
## time), begun again where the show jumped and held where it is while the show stands still.
func tick(t: float, host: Node) -> void:
	if _player == null:
		var gen := AudioStreamGenerator.new()
		gen.mix_rate = RATE
		gen.buffer_length = BUFFER
		_player = AudioStreamPlayer.new()
		_player.name = "DispatchSounds"
		_player.stream = gen
		host.add_child(_player)
	_still = _still + 1 if t == _last_t else 0
	_last_t = t
	if _still >= STILL_TICKS:
		_player.stream_paused = true
		return
	_player.stream_paused = false
	if not _player.playing or is_nan(_at) or t < _at - LEAD - RESET or t > _at + RESET:
		_player.stop()
		_player.play()
		_pb = _player.get_stream_playback()
		_restart(t)
	var n := mini(int((t + LEAD - _at) * float(RATE)), _pb.get_frames_available())
	if n > 0:
		_pb.push_buffer(render(n))


## Let go: the player stopped and taken off its host.
func stop() -> void:
	if _player != null and is_instance_valid(_player):
		_player.stop()
		_player.queue_free()
	_player = null


## Begin again at show time [param t]: nothing ringing, the plan's one-shots from there.
func _restart(t: float) -> void:
	_at = t
	_nv = 0
	_nb = 0
	_hs.fill(0.0)
	_ss.fill(0.0)
	_js.fill(0.0)
	_jph = 0.0
	_pop_slot = -1
	_rng = 1 + absi(hash(int(t * 1000.0))) % 100000
	_take_plan(true)


## The medium's plan, taken again when it changed; [param from_now] finds the first one-shot from [member _at].
func _take_plan(from_now := false) -> void:
	if medium == null:
		return
	var rev := int(medium.call("sound_rev"))
	if rev == _plan_rev and not from_now:
		return
	_plan_rev = rev
	_plan = medium.call("sound_plan")
	# what lasts, apart: looked through every step, where the one-shots (a key a character) are walked once
	_lasting = []
	for it in _plan:
		if float((it as Dictionary).get("t1", -INF)) > float(it["t"]):
			_lasting.append(it)
	_next = 0
	while _next < _plan.size() and float((_plan[_next] as Dictionary)["t"]) < _at:
		_next += 1


## The next [param n] samples from where the sound is ([member _at]): stereo.
func render(n: int) -> PackedVector2Array:
	if is_nan(_at):
		_restart(0.0)
	_take_plan()
	var out := PackedVector2Array()
	out.resize(n)
	var i := 0
	while i < n:
		var m := mini(STEP, n - i)
		var t0 := _at + float(i) / float(RATE)
		_run(out, i, m, t0)
		i += m
	_at += float(n) / float(RATE)
	return out


## What goes on at show time [param t] of the plan's lasting sounds: `[item, u]` each, u the seconds into it.
func _going(t: float) -> Array:
	var out: Array = []
	for it in _lasting:
		var d: Dictionary = it
		var t1 := float(d.get("t1", -INF))
		if t1 > float(d["t"]) and t >= float(d["t"]) and t < t1:
			out.append([d, t - float(d["t"])])
	return out


func _run(out: PackedVector2Array, i: int, m: int, t0: float) -> void:
	var dt := 1.0 / float(RATE)
	var t1 := t0 + float(m) * dt
	var spawn: Array = []
	while _next < _plan.size() and float((_plan[_next] as Dictionary)["t"]) < t1:
		var d: Dictionary = _plan[_next]
		spawn.append([maxi(0, int((float(d["t"]) - t0) * float(RATE))), d])
		_next += 1
	var going := _going(t0)
	var hiss := HISS
	for g in going:
		var gd: Dictionary = g[0]
		if String(gd["kind"]) == "static":
			var lv := storm_level(String(gd.get("storm", "popcorn")), float(g[1]), int(gd.get("seed", 0)), float(gd["t1"]) - float(gd["t"]))
			g.append(lv)
			hiss = HISS_OPEN * lv * 0.6 + HISS
	var f_hs := 2.0 * sin(PI * 2400.0 / float(RATE))
	var f_ss := 2.0 * sin(PI * 900.0 / float(RATE))
	var si := 0
	for k in m:
		while si < spawn.size() and int(spawn[si][0]) <= k:
			_begin(spawn[si][1])
			si += 1
		var l := 0.0
		var r := 0.0
		var v := 0
		while v < _nv:
			var s := _va[v] * sin(_vph[v])
			l += s * _vl[v]
			r += s * _vr[v]
			_vph[v] += _vw[v]
			_vw[v] *= _vg[v]
			_va[v] *= _vk[v]
			if _va[v] < 1e-5:
				_nv -= 1
				_drop_voice(v, _nv)
				continue
			v += 1
		var b := 0
		while b < _nb:
			var x := _noise() * _ba[b]
			_blo[b] += _bf[b] * _bbd[b]
			_bbd[b] += _bf[b] * (x - _blo[b] - _bq[b] * _bbd[b])
			l += _bbd[b] * _bl[b]
			r += _bbd[b] * _br[b]
			_ba[b] *= _bk[b]
			if _ba[b] < 1e-5:
				_nb -= 1
				_drop_burst(b, _nb)
				continue
			b += 1
		var hx := _noise() * hiss
		_hs[0] += f_hs * _hs[1]
		_hs[1] += f_hs * (hx - _hs[0] - 1.1 * _hs[1])
		var rx := Vector2(0.62, 0.78)
		l += float(_hs[1]) * rx.x
		r += float(_hs[1]) * rx.y
		for g in going:
			var d: Dictionary = g[0]
			var u := float(g[1]) + float(k) * dt
			match String(d["kind"]):
				"static":
					var s := _storm(d, u, f_ss, float(g[2]))
					l += s * rx.x
					r += s * rx.y
				"ringback":
					var s := _ringback(u)
					l += s * 0.35
					r += s * 0.94
				"bell":
					var s := _bell(u)
					var e: Vector2 = d.get("ears", Vector2(0.7071, 0.7071))
					l += s * e.x
					r += s * e.y
				"buzz":
					var s := _buzz(d, u)
					var e: Vector2 = d.get("ears", Vector2(0.7071, 0.7071))
					l += s * e.x
					r += s * e.y
				"print":
					var s := _printing(d, u)
					var e: Vector2 = d.get("ears", Vector2(0.7071, 0.7071))
					l += s * e.x
					r += s * e.y
				"jet":
					var s := _jet(d, u)
					l += s.x
					r += s.y
		out[i + k] = Vector2(clampf(l, -LOUD_MOST * 2.0, LOUD_MOST * 2.0), clampf(r, -LOUD_MOST * 2.0, LOUD_MOST * 2.0))
	while si < spawn.size():
		_begin(spawn[si][1])
		si += 1


# --- what is begun ---------------------------------------------------------------------------------------------------

## One moment's sound, begun: `what` says which, `at` where on the desk it is.
func _begin(d: Dictionary) -> void:
	var ears := ears_of(d.get("at", Vector3.ZERO))
	match String(d.get("what", "")):
		"flip":
			_burst(3200.0, 1.0, 0.006, 0.03, ears)
			_burst(1400.0, 0.8, 0.012, 0.018, ears)
			_sine(2900.0, 0.02, 0.006, ears)
		"snap":
			_burst(2200.0, 0.9, 0.008, 0.045, ears)
			_burst(600.0, 0.9, 0.02, 0.02, ears)
			_sine(1900.0, 0.025, 0.008, ears)
		"lay":
			_sine(190.0, 0.04, 0.02, ears)
			_burst(1700.0, 1.1, 0.01, 0.014, ears)
		"key":
			var a := lerpf(0.6, 1.0, _rand())
			_burst(lerpf(2400.0, 3300.0, _rand()), 1.0, 0.005, 0.03 * a, ears)
			_sine(lerpf(260.0, 340.0, _rand()), 0.03, 0.012 * a, ears)
		"space":
			_burst(1600.0, 1.0, 0.007, 0.026, ears)
			_sine(210.0, 0.04, 0.016, ears)
		"enter":
			_burst(1900.0, 1.0, 0.008, 0.034, ears)
			_sine(230.0, 0.05, 0.02, ears)
		"dtmf":
			var digit := int(d.get("digit", 5))
			var row := clampi(digit / 3, 0, 3)
			var col := digit % 3
			for f in [float(DTMF_ROWS[row]), float(DTMF_COLS[col])]:
				_sine(f, float(d.get("secs", DTMF_ON)) * 0.9, DTMF, Vector2(0.35, 0.94))
		"chime":
			_sine(1318.5, 0.16, 0.022, ears)
			_sine(1975.5, 0.32, 0.016, ears)
		"pad":
			_burst(3600.0, 0.9, 0.003, 0.012, ears)
			_sine(1400.0, 0.05, 0.008, ears)
		"sent":
			_sine(880.0, 0.14, 0.012, ears, pow(1.6, 1.0 / (0.12 * float(RATE))))
		"ping":
			_sine(PING_HZ, PING_RING, PING, ears, pow(0.97, 1.0 / (PING_RING * float(RATE))))
			_sine(PING_HZ * 2.01, PING_RING * 0.35, PING * 0.18, ears)
		"echo":
			_sine(PING_HZ * 0.995, PING_RING * 0.8, PING * 0.3, ears, pow(0.97, 1.0 / (PING_RING * float(RATE))))
		"tick":
			_sine(PING_HZ * 1.5, 0.045, PING * 0.1, ears)
		"alarm":
			_sine(PING_HZ * 1.25, 0.09, PING * 0.32, ears)
		"alarm_hi":
			_sine(PING_HZ * 1.68, 0.09, PING * 0.32, ears)
		"toggle":
			_burst(4200.0, 0.7, 0.003, 0.05, ears)
			_burst(2600.0, 0.9, 0.006, 0.03, ears)
			_sine(1250.0, 0.06, 0.006, ears)
		"thud":
			_sine(150.0, 0.06, 0.035, ears)
			_burst(1500.0, 1.2, 0.012, 0.02, ears)
			_sine(2350.0, 0.09, 0.008, ears)
			_sine(5200.0, 0.05, 0.003, ears)
		"lift":
			_burst(800.0, 1.4, 0.03, 0.006, ears)
		"crt":
			_sine(70.0, 0.12, 0.02, ears)
			_burst(6000.0, 0.9, 0.04, 0.004, ears)
		"click":
			_burst(3000.0, 1.0, 0.004, 0.02, ears)
		"detent":
			_burst(3800.0, 0.9, 0.0025, 0.016, ears)
			_sine(1700.0, 0.012, 0.004, ears)
		"lamp":
			_burst(2600.0, 0.8, 0.005, 0.034, ears)
			_burst(900.0, 0.9, 0.012, 0.012, ears)
			_sine(1500.0, 0.02, 0.004, ears)
		"tear":
			_burst(2600.0, 1.4, 0.15, 0.01, ears)


# --- what goes on ----------------------------------------------------------------------------------------------------

## A storm at [param u] seconds into it: its pops (Io-B) or its surf (Io-A).
func _storm(d: Dictionary, u: float, f_ss: float, level: float) -> float:
	var kind := String(d.get("storm", "popcorn"))
	var seed := int(d.get("seed", 0))
	if kind == "surf":
		var x := _noise() * SURF * level
		_ss[0] += f_ss * _ss[1]
		_ss[1] += f_ss * (x - _ss[0] - 0.7 * _ss[1])
		return float(_ss[1]) * 1.6 + x * 0.25
	# Pops: in each slot a pop as likely as the cluster's rate says - begun as a burst of its own, so it rings a moment
	var slot := int(floor(u / POP_SLOT))
	if slot != _pop_slot:
		_pop_slot = slot
		var p := POP_RATE * POP_SLOT * level
		if hash01(seed, slot) < p:
			var a := POP * lerpf(0.3, 1.0, hash01(seed + 7, slot))
			_burst(lerpf(900.0, 3200.0, hash01(seed + 11, slot)), 0.6, POP_LEN, a, Vector2(0.62, 0.78))
	return 0.0


## How hard a storm is at [param u] seconds of [param span] (0-1), a pure function of them and [param seed]; its sound and
## the receiver's needle both follow. Io-B's in clusters of pops, on and off; Io-A's in long swells. Both open and close
## over their first and last half second.
static func storm_level(kind: String, u: float, seed: int, span := 1e9) -> float:
	var edge := clampf(u / 0.5, 0.0, 1.0) * clampf((span - u) / 0.5, 0.0, 1.0)
	if kind == "surf":
		var s := 0.0
		var k := 0
		var t := 0.0
		while k < 64:
			var len := lerpf(SWELL.x, SWELL.y, hash01(seed + 3, k))
			if u < t + len:
				var w := (u - t) / len
				var crest := lerpf(0.45, 1.0, hash01(seed + 5, k))
				s = crest * pow(sin(PI * w), 1.6)
				break
			t += len
			k += 1
		return clampf(0.18 + 0.82 * s, 0.0, 1.0) * edge
	var c := int(floor(u / 0.25))
	var on := hash01(seed + 13, c) < 0.62
	var inside := lerpf(0.5, 1.0, hash01(seed + 17, c))
	return (inside if on else 0.08) * edge


## The ring the far end sends back, [param u] seconds after dialing ended: a pair of short rings a cycle, quiet in the earpiece.
func _ringback(u: float) -> float:
	var cyc := fposmod(u, DispatchScript.RING_CYCLE)
	var on := cyc < RINGBACK_PAIR[0] or (cyc >= RINGBACK_PAIR[0] + RINGBACK_PAIR[1] and cyc < DispatchScript.RING_ON)
	_ph[0] += TAU * float(RINGBACK[0]) / float(RATE)
	_ph[1] += TAU * float(RINGBACK[1]) / float(RATE)
	if not on:
		return 0.0
	return (sin(_ph[0]) + sin(_ph[1])) * 0.5 * RINGBACK_LEVEL


## The terminal's bell [param u] seconds into it: a near-square tone, a few milliseconds on and off at either end so it
## never clicks; its phase from [param u] itself.
func _bell(u: float) -> float:
	var edge := clampf(u / 0.004, 0.0, 1.0) * clampf((BELL_LEN - u) / 0.01, 0.0, 1.0)
	var ph := TAU * BELL_HZ * u
	return (sin(ph) + sin(ph * 3.0) / 3.0 + sin(ph * 5.0) / 5.0) * BELL * edge


## A phone buzzing on the wood [param u] seconds into its ring (or its one text's buzz): the motor's hum while it is on, and
## its rattle against its neighbors.
func _buzz(d: Dictionary, u: float) -> float:
	var on := true
	if String(d.get("pattern", "ring")) == "ring":
		on = fposmod(u, DispatchScript.BUZZ_ON + DispatchScript.BUZZ_OFF) < DispatchScript.BUZZ_ON
	else:
		on = u < DispatchScript.TEXT_BUZZ
	_ph[2] += TAU * BUZZ_HZ / float(RATE)
	if not on:
		return 0.0
	var hum := sin(_ph[2]) + 0.45 * sin(_ph[2] * 2.0) + 0.25 * sin(_ph[2] * 3.0)
	if _rand() < RATTLE / float(RATE):
		_burst(lerpf(2000.0, 3600.0, _rand()), 0.8, 0.004, BUZZ * 0.8, d.get("ears", Vector2(0.7071, 0.7071)))
	return hum * BUZZ * 0.35


## The printer [param u] seconds into a print: before its first line, quiet; each line the head's pins screeching across
## and its motor; between lines the paper fed; done, its last feed.
func _printing(d: Dictionary, u: float) -> float:
	var lines := int(d.get("lines", 1))
	var lead := DispatchScript.PRINT_LEAD
	var line := DispatchScript.PRINT_LINE
	if u < lead:
		return 0.0
	var k := int(floor((u - lead) / line))
	var w := fposmod(u - lead, line) / line
	_ph[3] += TAU * PINS_HZ / float(RATE)
	_ph[4] += TAU * MOTOR_HZ / float(RATE)
	if k >= lines:
		return sin(_ph[4]) * MOTOR * 0.6 if u - lead - float(lines) * line < DispatchScript.PRINT_FEED else 0.0
	var printing := w < 0.82
	var s := sin(_ph[4]) * MOTOR
	if printing:
		var ch := int(floor(w * 60.0))
		var gate := 1.0 if hash01(k * 131 + 7, ch) < 0.8 else 0.0
		var sq := signf(sin(_ph[3])) * 0.6 + sin(_ph[3] * 2.0) * 0.3
		s += sq * SCREECH * gate + _noise() * SCREECH * 0.25 * gate
	elif w < 0.84:
		_burst(320.0, 1.2, 0.02, 0.02, Vector2(0.9, 0.42))
	return s


## The jet [param u] seconds into its pass: a source moving in a straight line past the building at [constant JET_SPEED],
## nearest ([constant JET_NEAR]) at its middle. Heard as it was when the sound left it: its distance then gives its
## loudness (one over the distance) and how dark the air makes it, and the speed it was coming or going at then gives the
## pitch factor c / (c - v cos), cos being how directly it came on.
func _jet(d: Dictionary, u: float) -> Vector2:
	var span := float(d["t1"]) - float(d["t"])
	var tc := span * 0.5
	var te := u
	for _k in 4:
		var x := JET_SPEED * (te - tc)
		te = u - sqrt(JET_NEAR * JET_NEAR + x * x) / SOUND_SPEED
	var xe := JET_SPEED * (te - tc)
	var r := sqrt(JET_NEAR * JET_NEAR + xe * xe)
	var coming := -xe / r
	var f := SOUND_SPEED / (SOUND_SPEED - JET_SPEED * coming)
	var near := JET_NEAR / r
	var edge := clampf(u / 1.0, 0.0, 1.0) * clampf((span - u) / 1.5, 0.0, 1.0)
	var amp := JET * near * edge
	_jph += TAU * WHINE_HZ * f / float(RATE)
	var whine := sin(_jph) + 0.4 * sin(_jph * 2.02) + 0.2 * sin(_jph * 0.5)
	var dark := clampf(near, 0.12, 1.0)
	var a := 1.0 - exp(-TAU * (400.0 + 2600.0 * dark) / float(RATE))
	_js[0] += a * (_noise() - _js[0])
	_js[1] += a * (_js[0] - _js[1])
	var roar := _js[1] * 2.2
	var s := (whine * 0.22 * dark + roar) * amp
	var pan := clampf(xe / (JET_NEAR * 2.0), -1.0, 1.0) * 0.6
	var ang := (pan + 1.0) * PI * 0.25
	return Vector2(s * cos(ang), s * sin(ang))


## The pitch factor heard [param u] seconds into a jet's pass of [param span] seconds: what [method _jet] plays it at.
static func jet_pitch(u: float, span: float) -> float:
	var tc := span * 0.5
	var te := u
	for _k in 4:
		var x := JET_SPEED * (te - tc)
		te = u - sqrt(JET_NEAR * JET_NEAR + x * x) / SOUND_SPEED
	var xe := JET_SPEED * (te - tc)
	var r := sqrt(JET_NEAR * JET_NEAR + xe * xe)
	return SOUND_SPEED / (SOUND_SPEED + JET_SPEED * xe / r)


# --- the parts ---------------------------------------------------------------------------------------------------------

func _sine(f: float, decay: float, amp: float, ears: Vector2, glide := 1.0) -> void:
	if _nv >= VOICES:
		return
	_vw[_nv] = TAU * f / float(RATE)
	_vg[_nv] = glide
	_va[_nv] = amp
	_vk[_nv] = exp(-1.0 / (maxf(decay, 1e-3) * float(RATE)))
	_vph[_nv] = 0.0
	_vl[_nv] = ears.x
	_vr[_nv] = ears.y
	_nv += 1


func _burst(fc: float, q: float, decay: float, amp: float, ears: Vector2) -> void:
	if _nb >= BURSTS:
		return
	_ba[_nb] = amp
	_bk[_nb] = exp(-1.0 / (maxf(decay, 1e-3) * float(RATE)))
	_bf[_nb] = 2.0 * sin(PI * minf(fc, float(RATE) / 6.5) / float(RATE))
	_bq[_nb] = q
	_blo[_nb] = 0.0
	_bbd[_nb] = 0.0
	_bl[_nb] = ears.x
	_br[_nb] = ears.y
	_nb += 1


func _drop_voice(v: int, last: int) -> void:
	_vw[v] = _vw[last]
	_vg[v] = _vg[last]
	_va[v] = _va[last]
	_vk[v] = _vk[last]
	_vph[v] = _vph[last]
	_vl[v] = _vl[last]
	_vr[v] = _vr[last]


func _drop_burst(b: int, last: int) -> void:
	_ba[b] = _ba[last]
	_bk[b] = _bk[last]
	_bf[b] = _bf[last]
	_bq[b] = _bq[last]
	_blo[b] = _blo[last]
	_bbd[b] = _bbd[last]
	_bl[b] = _bl[last]
	_br[b] = _br[last]


## The two ears' gains for something at [param at] on the desk (meters, x across from the chair): to the side it is on,
## at equal power.
static func ears_of(at: Vector3) -> Vector2:
	var p := clampf(at.x / PAN_REACH, -1.0, 1.0) * PAN
	var a := (p + 1.0) * PI * 0.25
	return Vector2(cos(a), sin(a))


## A number in [0, 1) from [param seed] and [param k], the same every time.
static func hash01(seed: int, k: int) -> float:
	return float(absi(hash([seed, k])) % 100003) / 100003.0


func _rand() -> float:
	_rng = (_rng * 1103515245 + 12345) & 0x7FFFFFFF
	return float(_rng) / float(0x7FFFFFFF)


func _noise() -> float:
	return _rand() * 2.0 - 1.0
