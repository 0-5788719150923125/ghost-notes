extends RefCounted
class_name WorkSounds

## WorkSounds - THE WORK, HEARD, quietly under the voice: a thing set down on the table, a pestle going round in its
## mortar, a pot at the boil, a pour landing.
##
## The user, 2026-10-29: "the cauldron might have a gentle bubbling sound (only if it is brought to a boil though, not
## when it's just steaming), but more importantly: when we are grinding the mortar and pestle, you would expect to hear
## sound specifically when the pestle touches the mortar (not in the gaps where it isn't touching). Also, you might
## expect to hear a sound when we move that big object and drop it on the table somewhere, or even when we move smaller
## objects that still have weight" - and "make sure the sounds are not distracting; they need to be subdued and quieter
## than the voice".
##
## FROM THE WORK ITSELF, at the moment it happens ([TableWork]): what is set down when its carry ends `down`, how heavy
## it is and what it is made of ([method TableWork.set_down]); what is pressed onto something and whether it touches it
## now, and how fast it goes ([method TableWork.pressed]); how hard a liquid boils, its `boil` ([method
## TableWork.boiling]); and, the physics' ([TablePhysics]), where a pour's stream lands and each piece a pestle breaks off
## ([method TablePhysics.breaks_in]) - crunched as it breaks, however the grinding was written. The table plays them itself, as
## its picture is drawn (live, a frame at a time; in a render, the frames Movie Maker records - which records the sound
## too), so they keep the reading's own time as the work does, a live reading's acts moved as its words arrive.
##
## SYNTHESIZED, as the place is ([Soundscape]; Farnell, "Designing Sound", 2010): a thing set down is a thump of the
## table's wood under it and the ring of what it is made of - glass clinks high and long, metal rings lower and longer,
## stone and pottery tock, wood knocks, and paper and cloth are all but silent - lower for a bigger thing, louder for a
## heavier one; a boil is bubbles (Minnaert's: a sine that rises as it dies) and a little hiss under them; a pour is a run
## of small high bubbles where it lands.
##
## GRINDING IS A SCRAPE, only while the point touches and as fast as it goes (the user, 2026-10-29, of the grit it had
## been - noise through a band at 2.2 kHz, steady: "Stone on stone should be a scraping sound, low and rough, abrasive.
## What it does now sounds a lot closer to T.V. static. I also think it's a touch too loud"): as van den Doel, Kry and
## Pai's FoleyAutomatic (SIGGRAPH 2001) makes one - the surface under the point read at the speed it slides, so its
## grain sounds higher as it goes faster ([constant SCRAPE_FINE]), its bumps roughening it at random, never in a beat
## ([constant SCRAPE_BUMP]); the point catching and slipping on grit ([constant CATCHES]); and all of it ringing what is
## ground in, damped by the hand on it - the vessel's own low body and its material's modes for its size, the bigger the
## lower ([method _modes_for]).
##
## SUBDUED: the voice speaks at about [constant VoiceFX.PAD_VOICE_REF] RMS; nothing here peaks past [constant PEAK_MOST],
## a heavy pot set down about that, a jar a third of it, a slip of paper nothing - and what goes on (grinding, a boil)
## stays far under the voice ([constant GRIND], [constant SIMMER]).

## The sample rate made at, how far ahead of the show the sound is kept (seconds), how far the show may jump from where
## the sound is before it begins again there, and how long the player's buffer is.
const RATE := 22050
const LEAD := 0.15
const RESET := 0.35
const BUFFER := 0.5
## Samples a control step: what touches, what boils and what pours is looked at this often.
const STEP := 256
## THE LEVELS (full scale): the most anything here peaks at; a thing of THUD_HEAVY kilograms set down (louder by the
## square root of its weight, up to that), and quieter than THUD_LEAST nothing is heard.
const PEAK_MOST := 0.06
const THUD := 0.045
const THUD_HEAVY := 2.0
const THUD_LEAST := 0.002
## GRINDING: how loud its scrape is at a brisk round (GRIND_SPEED meters a second), and how near its surface a pressed
## point is touching it (meters, past the gap it is held at); the most crunches a second of what it breaks.
const GRIND := 0.0025
const GRIND_SPEED := 0.12
const TOUCH := 0.0025
const CRUNCHES := 7.0
const CRUNCH := 0.009
## ...ITS SCRAPE: the surface's grain (meters - read at the speed the point slides, its finest ripple sounds at speed / this:
## 600 Hz at a brisk round), the lowest of it heard (Hz), its bumps (meters, a random roughening of the scrape at speed /
## this), how hard they roughen it, how often the point catches on a grit and slips (a meter slid), how hard a catch
## strikes against the scrape, and how much of the scrape is heard as itself beside what it rings. Measured on its own,
## a scrape of stone at a brisk round has the middle of its spectrum at about 560 Hz, and its loudness in 20 ms pieces
## varies by 0.45 of itself; the grit it had been, 4.7 kHz and 0.03.
const SCRAPE_FINE := 0.0002
const SCRAPE_LOWEST := 130.0
const SCRAPE_BUMP := 0.006
const ROUGH := 1.6
const CATCHES := 900.0
const CATCH := 4.0
const DIRECT := 1.0
## ...WHAT IT RINGS: the vessel's body (Hz for one 10 cm across - a bigger one lower) and how much of the scrape it takes,
## how much its material's modes take, how long a mode rings under the hand (seconds; its material's own, this much of
## it, at most SCRAPE_RING), and the most modes.
const BODY := 160.0
const BODY_SHARE := 0.25
const MODE_SHARE := 0.8
const DAMPED := 0.12
const SCRAPE_RING := 0.05
const MODES := 4
## A piece broken off this big (meters, a sphere's radius) crunches at its loudest and lowest; a speck, faint and high.
const BREAK_BIG := 0.004
## A BOIL: bubbles a second at a boil of 1, a bubble's peak, and the hiss under them at a boil of 1.
const BUBBLES := 7.0
const BUBBLE := 0.009
const SIMMER := 0.0015
## A POUR: bubbles a second where it lands at full flow, their peak, and its hiss.
const POUR_BUBBLES := 30.0
const POUR_BUBBLE := 0.005
const POUR_HISS := 0.002
## How far to one side a thing sounds at most, and how far from the middle of the reading that is (meters).
const PAN := 0.7
const PAN_REACH := 0.5
## What a thing set down rings with, by its material ([constant Props.MATERIALS]): its lowest partial for a thing
## RING_SIZE across (Hz; a bigger one rings lower), the others' ratios to it, how long it rings (seconds) and how loud
## against its thump. Paper, cloth, leather, wax, plants and powder only thump.
const RING_SIZE := 0.08
const RINGS := {
	"glass": {"f": 2600.0, "ratios": [1.0, 2.32, 4.25], "decay": 0.22, "amp": 0.35},
	"crystal": {"f": 2900.0, "ratios": [1.0, 2.45, 4.6], "decay": 0.25, "amp": 0.35},
	"metal": {"f": 900.0, "ratios": [1.0, 2.76, 5.4], "decay": 0.5, "amp": 0.22},
	"ceramic": {"f": 1500.0, "ratios": [1.0, 2.13], "decay": 0.07, "amp": 0.3},
	"stone": {"f": 1100.0, "ratios": [1.0, 2.4], "decay": 0.05, "amp": 0.3},
	"bone": {"f": 1300.0, "ratios": [1.0, 2.6], "decay": 0.05, "amp": 0.25},
	"wood": {"f": 650.0, "ratios": [1.0, 2.6], "decay": 0.04, "amp": 0.35},
}
## Ticks with the show's time unmoved before the sound is held where it is.
const STILL_TICKS := 2
## The most sines and noise bursts sounding at once.
const VOICES := 40
const BURSTS := 12

var work: TableWork
var _player: AudioStreamPlayer
var _pb: AudioStreamGeneratorPlayback
var _at := NAN                    # show time of the next sample made
var _last_t := NAN                # the show's time at the last tick, and how many ticks since it moved
var _still := 0
var _rng := 0x2545f491
# the sines: phase step and its glide a sample, amplitude and its decay a sample, phase, the two ears
var _vw := PackedFloat32Array()
var _vg := PackedFloat32Array()
var _va := PackedFloat32Array()
var _vk := PackedFloat32Array()
var _vph := PackedFloat32Array()
var _vl := PackedFloat32Array()
var _vr := PackedFloat32Array()
var _nv := 0
# the noise bursts: amplitude and its decay, the filter's coefficient and damping, its two states, the ears
var _ba := PackedFloat32Array()
var _bk := PackedFloat32Array()
var _bf := PackedFloat32Array()
var _bq := PackedFloat32Array()
var _blo := PackedFloat32Array()
var _bbd := PackedFloat32Array()
var _bl := PackedFloat32Array()
var _br := PackedFloat32Array()
var _nb := 0
# what goes on: a scrape, a boil's hiss, a pour's hiss - levels now and wanted, ears
var _scrape_level := 0.0
var _scrape_want := 0.0
var _scrape_pan := Vector2(0.7, 0.7)
var _scrape_v := 0.0              # how fast the point slides (meters a second), as wanted and as it eases
var _scrape_v_want := 0.0
var _scrape_of := ""              # what it rings: its material and size, as last made into modes
var _sf := [0.0, 0.0, 0.0, 0.0]   # the grain's two filters, the bumps' and the grain's lowest'
# the modes it rings: each one's two coefficients, its gain, its two states
var _mc1 := PackedFloat32Array()
var _mc2 := PackedFloat32Array()
var _mg := PackedFloat32Array()
var _my1 := PackedFloat32Array()
var _my2 := PackedFloat32Array()
var _hiss := [0.0, 0.0]
var _hiss_level := 0.0
var _hiss_want := 0.0
var _hiss_pan := Vector2(0.7, 0.7)
var _pressed_was := {}            # work -> where its pressed point was a step ago
var _due := {}                    # what is spawned at a rate -> how much of the next one is due
var _broke := {}                  # the biggest piece broken off since the last crunch, and when that crunch was
var _crunched := -INF


func _init(w: TableWork) -> void:
	work = w
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


## THE SHOW AT [param t]: the sound kept [constant LEAD] ahead of it in a player under [param host] (made the first time) -
## begun again where the show jumped, and HELD WHERE IT IS while the show stands still (the user, 2026-10-29: "I clicked
## "pause" in the real-time viewer, and the environmental cauldron boiling sounds continue to play ... Audio should pause
## when the video does"): what is queued waits in the player, and goes on as the show does.
func tick(t: float, host: Node) -> void:
	if _player == null:
		var gen := AudioStreamGenerator.new()
		gen.mix_rate = RATE
		gen.buffer_length = BUFFER
		_player = AudioStreamPlayer.new()
		_player.name = "WorkSounds"
		_player.stream = gen
		host.add_child(_player)
	# A SHOW STANDING STILL: two ticks at one time (a single one can be a frame the clock did not tick over)
	_still = _still + 1 if t == _last_t else 0
	_last_t = t
	if _still >= STILL_TICKS and not _pb_paused():
		_player.stream_paused = true
		return
	if _still >= STILL_TICKS:
		return
	if _pb_paused():
		_player.stream_paused = false
	if not _player.playing or is_nan(_at) or t < _at - LEAD - RESET or t > _at + RESET:
		_player.stop()
		_player.play()
		_pb = _player.get_stream_playback()
		_restart(t)
	var n := mini(int((t + LEAD - _at) * float(RATE)), _pb.get_frames_available())
	if n > 0:
		_pb.push_buffer(render(n))


func _pb_paused() -> bool:
	return _player != null and _player.stream_paused


## Let go: the player stopped and taken off its host.
func stop() -> void:
	if _player != null and is_instance_valid(_player):
		_player.stop()
		_player.queue_free()
	_player = null


## Begin again at show time [param t]: nothing sounding.
func _restart(t: float) -> void:
	_at = t
	_nv = 0
	_nb = 0
	_scrape_level = 0.0
	_scrape_v = 0.0
	_sf = [0.0, 0.0, 0.0, 0.0]
	_my1.fill(0.0)
	_my2.fill(0.0)
	_hiss_level = 0.0
	_pressed_was = {}
	_due = {}
	_broke = {}
	_crunched = -INF


## THE NEXT [param n] SAMPLES from where the sound is ([member _at]), the show's time going on with them: stereo.
func render(n: int) -> PackedVector2Array:
	if is_nan(_at):
		_restart(0.0)
	var out := PackedVector2Array()
	out.resize(n)
	var i := 0
	while i < n:
		var m := mini(STEP, n - i)
		var t0 := _at + float(i) / float(RATE)
		var spawn: Array = _look(t0, t0 + float(m) / float(RATE))
		_run(out, i, m, spawn)
		i += m
	_at += float(n) / float(RATE)
	return out


## What the work does from [param t0] to [param t1]: what is begun in it (`[[sample in the step, Callable]]`) and what goes
## on through it set.
func _look(t0: float, t1: float) -> Array:
	var spawn: Array = []
	var dt := t1 - t0
	# A THING SET DOWN
	for d in work.set_down(t0, t1):
		spawn.append([int((float((d as Dictionary)["t"]) - t0) * float(RATE)), _thud.bind(d)])
	# A POINT PRESSED ONTO SOMETHING, touching it and moving over it: its scrape
	var pace := 0.0
	var seen := {}
	for p in work.pressed(t0):
		var pd: Dictionary = p
		var wi := int(pd["wi"])
		seen[wi] = true
		var at: Vector3 = pd["at"]
		var was: Variant = _pressed_was.get(wi)
		_pressed_was[wi] = at
		if was == null or float(pd["touch"]) > TOUCH:
			continue
		var speed := (at - (was as Vector3)).length() / maxf(dt, 1e-4)
		if speed / GRIND_SPEED > pace:
			pace = minf(speed / GRIND_SPEED, 1.3)
			_scrape_pan = _ears(at)
			_scrape_v_want = minf(speed, GRIND_SPEED * 1.3)
			_modes_for(String(pd.get("kind", "stone")), float(pd.get("size", 0.12)))
	for wi in _pressed_was.keys():
		if not seen.has(wi):
			_pressed_was.erase(wi)
	# ...louder the faster, as the grain it reads is struck harder and oftener
	_scrape_want = GRIND * sqrt(pace)
	# A PIECE BROKEN OFF, as the physics broke it: a crunch, the bigger the piece the lower and louder - no more than
	# CRUNCHES a second however many break at once (a lump crushed splits into dozens in a moment, which heard each had
	# stacked far past the voice), each as big as the biggest since the last
	if work.physics != null:
		for b in work.physics.breaks_in(t0, t1):
			var bd: Dictionary = b
			if float(bd["size"]) > float(_broke.get("size", 0.0)):
				_broke = bd
		if not _broke.is_empty() and t0 - _crunched >= 1.0 / CRUNCHES:
			var big := clampf(float(_broke["size"]) / BREAK_BIG, 0.25, 1.0)
			spawn.append([clampi(int((maxf(float(_broke["t"]), t0) - t0) * float(RATE)), 0, STEP - 1),
				_crunch.bind(big, _ears(_broke["at"]), lerpf(1800.0, 700.0, big))])
			_crunched = t0
			_broke = {}
	# A BOIL, and A POUR LANDING
	var hiss := 0.0
	for b in work.boiling(t0):
		var bd: Dictionary = b
		var key := "boil %d" % int(bd["wi"])
		_due[key] = float(_due.get(key, _rand())) + BUBBLES * float(bd["boil"]) * dt
		while float(_due[key]) >= 1.0:
			_due[key] = float(_due[key]) - 1.0
			var spot := (bd["at"] as Vector3) + Vector3(_rand() - 0.5, 0.0, _rand() - 0.5) * float(bd["size"]) * 0.6
			spawn.append([int(_rand() * float(STEP)), _bubble.bind(lerpf(320.0, 900.0, _rand()), BUBBLE * lerpf(0.35, 1.0, _rand()), _ears(spot))])
		if SIMMER * float(bd["boil"]) > hiss:
			hiss = SIMMER * float(bd["boil"])
			_hiss_pan = _ears(bd["at"])
	var pour := _pouring(t0)
	if not pour.is_empty():
		var flow := float(pour["flow"])
		_due["pour"] = float(_due.get("pour", _rand())) + POUR_BUBBLES * flow * dt
		while float(_due["pour"]) >= 1.0:
			_due["pour"] = float(_due["pour"]) - 1.0
			spawn.append([int(_rand() * float(STEP)), _bubble.bind(lerpf(900.0, 2400.0, _rand()), POUR_BUBBLE * lerpf(0.4, 1.0, _rand()), _ears(pour["at"]))])
		if POUR_HISS * flow > hiss:
			hiss = POUR_HISS * flow
			_hiss_pan = _ears(pour["at"])
	_hiss_want = hiss
	spawn.sort_custom(func(a: Array, b: Array) -> bool: return int(a[0]) < int(b[0]))
	return spawn


## Where a pour lands at [param t] and how hard it flows there, 0-1 (`{}` for none): the physics' frame then.
func _pouring(t: float) -> Dictionary:
	if work.physics == null:
		return {}
	var f: Variant = work.physics.frame_at(t)
	if f == null:
		return {}
	var liq: PackedFloat32Array = (f as Dictionary)["liq"]
	var best := 0.0
	var at := Vector3.ZERO
	for k in range(0, liq.size() - 15, 16):
		if liq[k + 15] > best:
			best = liq[k + 15]
			at = Vector3(liq[k + 12], liq[k + 13], liq[k + 14])
	# a stream's landing is told as at most 0.0012 ([TablePhysics]'s `hit`)
	return {} if best <= 1e-5 else {"flow": clampf(best / 0.0012, 0.0, 1.0), "at": at}


## [param m] samples into [param out] from [param i]: what is begun at its sample, then everything sounding.
func _run(out: PackedVector2Array, i: int, m: int, spawn: Array) -> void:
	var si := 0
	var gk := 1.0 - exp(-1.0 / (0.02 * float(RATE)))
	var f_hs := 2.0 * sin(PI * 3200.0 / float(RATE))
	var h := _hiss
	# THE SCRAPE'S FILTERS for how fast the point slides this step: its grain and bumps each at the speed over their
	# length, made as loud as white noise again (a one-pole's noise gain is a / (2 - a); two in a row, a^4 (1 + b) /
	# (1 - b)^3 with b = (1 - a)^2), and how likely a catch is a sample
	_scrape_v += (_scrape_v_want - _scrape_v) * minf(1.0, float(m) / (0.05 * float(RATE)))
	var sv := maxf(_scrape_v, 0.005)
	var af := 1.0 - exp(-TAU * clampf(sv / SCRAPE_FINE, 40.0, 5000.0) / float(RATE))
	var bf := (1.0 - af) * (1.0 - af)
	var nf := 1.0 / sqrt(maxf(af * af * af * af * (1.0 + bf) / pow(1.0 - bf, 3.0), 1e-12))
	var ac := 1.0 - exp(-TAU * clampf(sv / SCRAPE_BUMP, 2.0, 400.0) / float(RATE))
	var nc := 1.0 / sqrt(maxf(ac / (2.0 - ac), 1e-12))
	var catch_p := CATCHES * sv / float(RATE)
	var ah := 1.0 - exp(-TAU * SCRAPE_LOWEST / float(RATE))
	var sf := _sf
	var nm := _mc1.size()
	for k in m:
		while si < spawn.size() and int(spawn[si][0]) <= k:
			(spawn[si][1] as Callable).call()
			si += 1
		var l := 0.0
		var r := 0.0
		# the sines
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
		# the bursts: noise through a resonance (a state variable filter's band)
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
		# what goes on: the scrape, and the hiss of a boil or a pour
		_scrape_level += (_scrape_want - _scrape_level) * gk
		if _scrape_level > 1e-6:
			# the grain under the point, read as it slides; its bumps, roughening it; a catch on a grit now and then
			sf[0] = float(sf[0]) + af * (_noise() * 1.732 - float(sf[0]))
			sf[1] = float(sf[1]) + af * (float(sf[0]) - float(sf[1]))
			sf[2] = float(sf[2]) + ac * (_noise() * 1.732 - float(sf[2]))
			sf[3] = float(sf[3]) + ah * (float(sf[1]) - float(sf[3]))
			var grain := (float(sf[1]) - float(sf[3])) * nf * clampf(1.0 + ROUGH * float(sf[2]) * nc, 0.0, 3.0)
			var e := grain
			if _rand() < catch_p:
				e += CATCH * -log(maxf(_rand(), 1e-6)) * (1.0 if _rand() < 0.5 else -1.0)
			# ...ringing what is ground in
			var rung := 0.0
			for q in nm:
				var y := _mc1[q] * _my1[q] - _mc2[q] * _my2[q] + _mg[q] * e
				_my2[q] = _my1[q]
				_my1[q] = y
				rung += y
			var s := (rung + grain * DIRECT) * _scrape_level
			l += s * _scrape_pan.x
			r += s * _scrape_pan.y
		_hiss_level += (_hiss_want - _hiss_level) * gk
		if _hiss_level > 1e-6:
			var x := _noise() * _hiss_level
			h[0] += f_hs * h[1]
			h[1] += f_hs * (x - h[0] - 1.3 * h[1])
			l += float(h[1]) * _hiss_pan.x
			r += float(h[1]) * _hiss_pan.y
		out[i + k] = Vector2(clampf(l, -PEAK_MOST * 2.0, PEAK_MOST * 2.0), clampf(r, -PEAK_MOST * 2.0, PEAK_MOST * 2.0))
	while si < spawn.size():
		(spawn[si][1] as Callable).call()
		si += 1


# --- what is begun ---------------------------------------------------------------------------------------------------

## A THING SET DOWN ([method TableWork.set_down]): the table's thump under it, a click, and its material's ring.
func _thud(d: Dictionary) -> void:
	var amp := THUD * minf(sqrt(float(d["mass"]) / THUD_HEAVY), 1.0)
	if amp < THUD_LEAST:
		return
	var size := maxf(float(d["size"]), 0.02)
	var ears := _ears(d["at"])
	_sine(clampf(130.0 * sqrt(0.1 / size), 70.0, 220.0), 0.06, amp * 0.9, ears)
	_burst(1500.0, 1.2, 0.012, amp * 0.5, ears)
	var row: Variant = RINGS.get(String(d["kind"]))
	if row is Dictionary:
		var f0 := float(row["f"]) * pow(RING_SIZE / size, 0.6)
		var ratios: Array = row["ratios"]
		for k in ratios.size():
			var f := f0 * float(ratios[k])
			if f < float(RATE) * 0.45:
				_sine(f, float(row["decay"]) / (1.0 + 0.5 * k), amp * float(row["amp"]) / (1.0 + k), ears)


## A CRUNCH of something breaking under a grinding point, [param big] (0-1) of the loudest, around [param f] Hz.
func _crunch(big: float, ears: Vector2, f: float) -> void:
	_burst(f * lerpf(0.85, 1.15, _rand()), 0.9, 0.008, CRUNCH * big * lerpf(0.5, 1.0, _rand()), ears)


## THE MODES A SCRAPE RINGS in what is ground in, of material [param kind] and [param size] meters across ([constant
## WorkSounds.RINGS]): its body low, the bigger the lower, and its material's partials for its size - each a resonator
## (two poles at the mode's frequency, damped as the hand on it damps it), as loud for the grain as the next. Made again
## only when what is ground in changes.
func _modes_for(kind: String, size: float) -> void:
	var key := "%s %.3f" % [kind, size]
	if key == _scrape_of:
		return
	_scrape_of = key
	var fs := PackedFloat32Array([clampf(BODY * sqrt(0.1 / maxf(size, 0.02)), 70.0, 260.0)])
	var ds := PackedFloat32Array([0.03])
	var amps := PackedFloat32Array([BODY_SHARE])
	var row: Variant = RINGS.get(kind)
	if row is Dictionary:
		var f0 := float(row["f"]) * pow(RING_SIZE / maxf(size, 0.02), 0.6)
		var ratios: Array = row["ratios"]
		for k in mini(ratios.size(), MODES - 1):
			var f := f0 * float(ratios[k])
			if f < float(RATE) * 0.4:
				fs.append(f)
				ds.append(minf(float(row["decay"]) * DAMPED, SCRAPE_RING))
				amps.append(MODE_SHARE / (1.0 + float(k)))
	_mc1.resize(fs.size())
	_mc2.resize(fs.size())
	_mg.resize(fs.size())
	_my1.resize(fs.size())
	_my2.resize(fs.size())
	for k in fs.size():
		var rr := exp(-1.0 / (maxf(ds[k], 0.004) * float(RATE)))
		var w := TAU * fs[k] / float(RATE)
		_mc1[k] = 2.0 * rr * cos(w)
		_mc2[k] = rr * rr
		# a resonator's noise gain is about 1 / (2 (1 - r^2) sin^2 w): each made as loud as white noise, then weighed
		_mg[k] = sin(w) * sqrt(2.0 * (1.0 - rr * rr)) * amps[k]
		_my1[k] = 0.0
		_my2[k] = 0.0


## A BUBBLE closing (Minnaert): a sine at [param f] rising a fifth as it dies, [param amp] at its peak.
func _bubble(f: float, amp: float, ears: Vector2) -> void:
	var life := lerpf(0.015, 0.035, _rand())
	_sine(f, life, amp, ears, pow(1.5, 1.0 / (life * 2.0 * float(RATE))))


## A sine at [param f] Hz dying away over [param decay] seconds from [param amp], gliding by [param glide] a sample.
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


## A burst of noise through a resonance at [param fc] Hz (damping [param q]) dying away over [param decay] seconds.
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


## The two ears' gains for something at [param at] (the table's space): to the side it is on, at equal power.
static func _ears(at: Vector3) -> Vector2:
	var p := clampf((at.x - Tables.ORIGIN.x) / PAN_REACH, -1.0, 1.0) * PAN
	var a := (p + 1.0) * PI * 0.25
	return Vector2(cos(a), sin(a))


func _rand() -> float:
	_rng = (_rng * 1103515245 + 12345) & 0x7FFFFFFF
	return float(_rng) / float(0x7FFFFFFF)


func _noise() -> float:
	return _rand() * 2.0 - 1.0
