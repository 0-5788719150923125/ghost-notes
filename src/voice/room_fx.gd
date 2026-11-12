extends RefCounted
class_name RoomFX

## RoomFX - the room, decided once and rendered by two engines.
##
## Everything above the engine lives here: the dial's range and taper, what Resonance does to the tail's
## color, what "no room" means, and how one dial collapses into size-plus-wet when a panel has room for
## only one. Masking and the reading both ask this class and get the same answer.
##
## The engines differ because each mode's audio does:
##   [method to_reverb]  Masking plays its clip through an [AudioStreamPlayer], so its room is Godot's
##                       [AudioEffectReverb] on a bus (rebuilt identically by the export relaunch).
##   [method tick]       The reading pushes samples into a generator and bakes its effects into the take
##                       WAV, because the render process boots with only that file; a bus effect cannot
##                       run offline over a buffer, so this half is the reverb, in GDScript.
##
## Both derive from Jezar at Dreampoint's Freeverb (public domain): eight damped comb filters in
## parallel into four allpasses in series, from the same published tunings, so one set of numbers drives
## both. They are close, not sample-identical.

# --- the dial ------------------------------------------------------------------

## The top of the Room dial. 2 because Masking's neutral sits at 1.0: a dial resting in the middle can be
## opened as well as closed.
const SIZE_MAX := 2.0
## A single-dial panel's taper, for [method from_dial]. Above 1 so the bottom of the travel is a small
## close room rather than a quiet big one (as [constant VoiceFX.ECHO_TAPER]).
const WET_TAPER := 1.5

# --- what the numbers mean -----------------------------------------------------

## Feedback across the dial: a small room's tail dies in a breath, a big one rings for seconds.
## Freeverb's roomsize1 = size * 0.28 + 0.7, which is also how Godot maps its `room_size`.
const FB_MIN := 0.7
const FB_SPAN := 0.28
## Damping, moved by Resonance: a resonant space is bright and rings on, a dead one swallows the top of
## every repeat. Same mapping in both engines.
const DAMP_DEAD := 0.9
const DAMP_RING := 0.2
const DAMP_SCALE := 0.4          # Freeverb's scaledamp
## Wet and dry come from one "how much of the room reaches you" number but are not complements: the
## room is added to the sound, so the dry only steps back part of the way.
const WET_GAIN := 0.8
const DRY_DUCK := 0.35

# --- Freeverb's tunings, at the rate they were published for --------------------
const COMB := [1116, 1188, 1277, 1356, 1422, 1491, 1557, 1617]
const ALLPASS := [556, 441, 341, 225]
const REF_RATE := 44100.0
## The comb bank sums eight lines each with a DC gain of 1/(1 - feedback), so at the top of the dial the
## network multiplies by ~50. Freeverb's input trim, chosen against the feedback range above.
const FIXED_GAIN := 0.015
const ALLPASS_FB := 0.5

# --- the settings --------------------------------------------------------------

## How big the space is, on the 0..[constant SIZE_MAX] dial Masking's slider uses. 1.0 is neutral.
var size := 1.0
## How much of that space reaches the listener, 0..1. Masking drives it from its Ambience slider; a
## one-dial panel gets it from [method from_dial].
var wet := 0.0
## The tail's color, 0..1, from the mode's Resonance: 0 a dead room, 1 a ringing one.
var resonance := 0.5

var sample_rate := 22050

# One flat buffer with per-line offsets rather than twelve arrays: nested indexing on packed arrays
# goes through set_indexed and is slow per sample, and this runs in VoiceFX's per-sample loop.
#
# Positions are absolute indices into that buffer and the wrap bound is stored beside them, so the
# innermost loop reads two packed values per line instead of four.
var _buf := PackedFloat32Array()
var _off := PackedInt32Array()
var _end := PackedInt32Array()
var _len := PackedInt32Array()
var _pos := PackedInt32Array()
var _store := PackedFloat32Array()   # each comb's damping lowpass state
# Resolved from the settings whenever they move, never per sample.
var _k_size := -1.0
var _k_wet := -1.0
var _k_res := -1.0
var _fb := 0.0
var _damp1 := 0.0
var _damp2 := 1.0
var _wet_g := 0.0
var _dry_g := 1.0


# --- the shared model ----------------------------------------------------------


## The dial, as the fraction Freeverb and Godot both call room_size.
func size01() -> float:
	return clampf(size / SIZE_MAX, 0.0, 1.0)


func wet_gain() -> float:
	return clampf(wet, 0.0, 1.0) * WET_GAIN


func dry_gain() -> float:
	return 1.0 - clampf(wet, 0.0, 1.0) * DRY_DUCK


func damping() -> float:
	return lerpf(DAMP_DEAD, DAMP_RING, clampf(resonance, 0.0, 1.0))


## Nothing of the room reaches the listener, so a caller may skip it entirely. Asks about wet, not size:
## a big room nobody is standing in is silence. The DSP half is GDScript in a per-sample loop (about 6%
## of realtime at 22050 Hz), so it is paid only when the dial is up.
func is_active() -> bool:
	return wet_gain() > 0.0005


## Collapse one 0..1 dial into a room, for a panel with a single Room slider (the reading), rather than
## Masking's separate size and Ambience.
##
## Size and wet move together here, which Masking does not do (a big dry room and a small wet one are
## different sounds). The reading has the other axis under another name: Presence is distance from the
## source, which is what a separate wet control answers.
func from_dial(k: float, res: float) -> void:
	var t := clampf(k, 0.0, 1.0)
	size = t * SIZE_MAX
	wet = pow(t, WET_TAPER)
	resonance = res


# --- renderer 1: Godot's own reverb, on a bus ----------------------------------


## Push the settings onto a live [AudioEffectReverb]. Every property is assigned, including the ones
## that do not move, so a bus rebuilt from stale state keeps no value nobody chose.
func to_reverb(fx: AudioEffectReverb) -> void:
	if fx == null:
		return
	fx.wet = wet_gain()
	fx.dry = dry_gain()
	fx.room_size = size01()
	fx.damping = damping()
	fx.spread = 1.0


# --- renderer 2: the same network, in GDScript ---------------------------------


func setup(sr: int) -> void:
	sample_rate = maxi(sr, 1)
	var scale := float(sample_rate) / REF_RATE
	var n := COMB.size() + ALLPASS.size()
	_off.resize(n)
	_end.resize(n)
	_len.resize(n)
	_pos.resize(n)
	_store.resize(COMB.size())
	_store.fill(0.0)
	var total := 0
	for i in n:
		var base: int = int(COMB[i]) if i < COMB.size() else int(ALLPASS[i - COMB.size()])
		var l := maxi(1, int(round(float(base) * scale)))
		_off[i] = total
		_len[i] = l
		_pos[i] = total
		total += l
		_end[i] = total
	_buf.resize(total)
	_buf.fill(0.0)
	_k_size = -1.0                 # force a resolve on the next sample


## Cheap and idempotent: the sliders are live, so this runs once per buffer and returns at once unless
## something moved.
func _resolve() -> void:
	if is_equal_approx(size, _k_size) and is_equal_approx(wet, _k_wet) \
			and is_equal_approx(resonance, _k_res):
		return
	_k_size = size
	_k_wet = wet
	_k_res = resonance
	_fb = FB_MIN + FB_SPAN * size01()
	_damp1 = damping() * DAMP_SCALE
	_damp2 = 1.0 - _damp1
	_wet_g = wet_gain()
	_dry_g = dry_gain()


## One sample through the room. Inlined by the caller's loop because the reading's chain puts the room
## between the echo and the presence filter, as the bus chain does.
##
## Call [method prepare] once per buffer first (the settings cannot move mid-buffer). The 8 and the 12
## are the tuning tables' sizes, literals because this is the innermost loop in the audio path.
func tick(x: float) -> float:
	if _buf.is_empty():
		setup(sample_rate)
		_resolve()
	var input := x * FIXED_GAIN
	var acc := 0.0
	for k in 8:
		var i: int = _pos[k]
		var y := _buf[i]
		var s: float = y * _damp2 + _store[k] * _damp1
		_store[k] = s
		_buf[i] = input + s * _fb
		i += 1
		_pos[k] = i if i < _end[k] else _off[k]
		acc += y
	for k in range(8, 12):
		var i: int = _pos[k]
		var y := _buf[i]
		_buf[i] = acc + y * ALLPASS_FB
		acc = y - acc
		i += 1
		_pos[k] = i if i < _end[k] else _off[k]
	return x * _dry_g + acc * _wet_g


## A whole buffer through the room, in place. VoiceFX uses [method tick] directly so the room keeps its
## place in the chain.
func process(buf: PackedFloat32Array) -> PackedFloat32Array:
	if _buf.is_empty():
		setup(sample_rate)
	prepare()
	if not is_active():
		return buf
	for i in buf.size():
		buf[i] = tick(buf[i])
	return buf


## Re-resolve the settings. Call once per buffer before a run of [method tick].
func prepare() -> void:
	_resolve()
