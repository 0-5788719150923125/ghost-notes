extends RefCounted
class_name MaskAudioFx

## MaskAudioFx - Masking's timeline applied to the clip's sound: the one effect that draws nothing.
##
## Everything runs on one dedicated bus routed to Master, built once and left in place, using Godot's own effects
## (sample-exact, off the main thread). The export relaunch mixes through the same bus, so a rendered file carries
## the sound the editor previewed. A marker's envelope drives each parameter, so an audio marker fades in and out
## like a visual one.
##
## Chain order: EQ (shape the tone), COMPRESSOR (even it out), DELAY (echoes of the result), REVERB (the room, last).
##
## A part of the editor, cut along its banners (next/structure.md): it holds the bus and its effects, and reads the
## editor's audio player through `editor`.

## The [MaskEditor] this is a part of: everything read through it is something this part is handed.
var editor: MaskEditor

var _bus_idx := -1
var _fx_eq: AudioEffectEQ6
var _fx_comp: AudioEffectCompressor
var _fx_delay: AudioEffectDelay
var _fx_reverb: AudioEffectReverb
## The room's settings, shared with the mode that has no bus: [RoomFX] decides the dial's range, taper and what
## Resonance does to the tail; this renders them onto Godot's reverb.
var _room := RoomFX.new()

# --- the audio effect: the timeline, applied to the sound -------------------------------------

func ensure_bus() -> void:
	if _bus_idx >= 0 and AudioServer.get_bus_index(MaskEditor.MASK_BUS) == _bus_idx:
		return
	_bus_idx = AudioServer.get_bus_index(MaskEditor.MASK_BUS)
	if _bus_idx < 0:
		AudioServer.add_bus()
		_bus_idx = AudioServer.get_bus_count() - 1
		AudioServer.set_bus_name(_bus_idx, MaskEditor.MASK_BUS)
		AudioServer.set_bus_send(_bus_idx, "Master")
	# Rebuilt from scratch: a bus with a partial chain is worse than none.
	while AudioServer.get_bus_effect_count(_bus_idx) > 0:
		AudioServer.remove_bus_effect(_bus_idx, 0)
	_fx_eq = AudioEffectEQ6.new()
	_fx_comp = AudioEffectCompressor.new()
	_fx_delay = AudioEffectDelay.new()
	_fx_reverb = AudioEffectReverb.new()
	for fx in [_fx_eq, _fx_comp, _fx_delay, _fx_reverb]:
		AudioServer.add_bus_effect(_bus_idx, fx)
	apply({})   # neutral until a marker says otherwise
	if editor._audio != null:
		editor._audio.bus = MaskEditor.MASK_BUS


## Resolve one audio layer onto the bus. `l` is the layer dict (empty = neutral); every parameter runs through
## the layer's own envelope `env`.
func apply(l: Dictionary) -> void:
	if _fx_eq == null:
		return
	var amt := clampf(float(l.get("env", 0.0)) * float(l.get("intensity_a", 1.0)), 0.0, 1.0)
	# BASS: two bands lifted together (a single band reads as a resonance, not weight). EQ6's bands are
	# 32/100/320/1000/3200/10000 Hz; the bottom two are a voice's chest and a kick's body.
	var bass := clampf(float(l.get("fx_stick", 0.0)), 0.0, 1.0) * amt
	_fx_eq.set_band_gain_db(0, bass * 12.0)
	_fx_eq.set_band_gain_db(1, bass * 8.0)
	# PUNCH is the compressor on the same knob: bass that keeps its transient, where bass alone is muddy.
	_fx_comp.threshold = lerpf(0.0, -18.0, bass)
	_fx_comp.ratio = lerpf(1.0, 5.0, bass)
	_fx_comp.gain = bass * 5.0
	_fx_comp.attack_us = lerpf(20.0, 8.0, bass)     # fast enough to catch a transient
	_fx_comp.release_ms = lerpf(250.0, 120.0, bass)   # ms, unlike attack_us - the two differ
	# ECHO: Lag is the time between repeats, Bleed how much comes back.
	var echo := clampf(float(l.get("fx_smooth", 0.0)), 0.0, 1.0) * amt
	_fx_delay.dry = 1.0
	_fx_delay.tap1_active = echo > 0.001
	_fx_delay.tap1_delay_ms = lerpf(60.0, 620.0, clampf(float(l.get("fx_lag", 0.35)), 0.0, 1.0))
	_fx_delay.tap1_level_db = linear_to_db(maxf(echo * 0.7, 0.0001))
	# The second tap sits at a non-multiple of the first so repeats interleave into a decay.
	_fx_delay.tap2_active = echo > 0.001
	_fx_delay.tap2_delay_ms = _fx_delay.tap1_delay_ms * 1.63
	_fx_delay.tap2_level_db = linear_to_db(maxf(echo * 0.45, 0.0001))
	_fx_delay.feedback_active = echo > 0.001
	_fx_delay.feedback_level_db = linear_to_db(maxf(echo * 0.35, 0.0001))
	# RESONANCE: low-passing the feedback path makes a tail sound like a space rather than a copy.
	var reso := clampf(float(l.get("fx_contrast", 0.5)), 0.0, 1.0)
	_fx_delay.feedback_lowpass = lerpf(16000.0, 900.0, reso * amt)
	# AMBIENCE: size and wet are separate (a big dry room and a small wet one differ). The mapping lives in [RoomFX],
	# shared with Generative, which bakes its effects into a take; only the renderer differs. The envelope scales the
	# wet but not the size: a marker fades a room in, it does not grow the walls.
	_room.size = float(l.get("fx_scale", 1.0))
	_room.wet = clampf(float(l.get("fx_density", 0.45)), 0.0, 1.0) * amt
	_room.resonance = reso
	_room.to_reverb(_fx_reverb)
