extends RefCounted
class_name MaskAudioFx

## MaskAudioFx - Masking's timeline applied to the clip's sound.
##
## The one effect here that draws nothing. A mask session already owns its clip's
## audio - it plays it, fades it, and the export mixes it - so the timeline is
## already the right place to say "from here, wetter", and a marker's envelope is
## already the right shape for it: a reverb that arrives over a ramp is precisely
## what a ramp is for.
##
## Everything runs on ONE dedicated bus routed to Master, built once and left in
## place. Godot's own effects rather than hand-written DSP: they are sample-exact,
## they cost nothing on the main thread, and - the part that matters for this app -
## the export relaunch mixes through the same bus, so a rendered file carries the
## same sound the editor previewed. A hand-rolled process() on the video thread
## would not survive the export's fixed-fps clock at all.
##
## The chain's ORDER is the usual mixing order and is not arbitrary:
##   EQ          shape the tone first, so everything downstream reacts to the tone
##               you actually want (bass lifted here is bass the compressor hears)
##   COMPRESSOR  then even it out - this is what "punchy" is: not more bass, but
##               bass whose transients survive next to everything else
##   DELAY       echoes of the shaped, evened signal
##   REVERB      the room goes last, around all of it, as a room does
##
## A PART OF THE EDITOR, cut along its banners (next/structure.md, step 15): it holds the bus and its
## effects, and reads the editor's audio player through `editor`.

## The [MaskEditor] this is a part of: everything read through it is something this part
## is handed, and the list of them is what it depends on.
var editor: MaskEditor

var _bus_idx := -1
var _fx_eq: AudioEffectEQ6
var _fx_comp: AudioEffectCompressor
var _fx_delay: AudioEffectDelay
var _fx_reverb: AudioEffectReverb
## The room's SETTINGS, shared with the mode that has no bus. See [RoomFX]: the
## dial's range, its taper and what Resonance does to the tail are decided there
## and rendered here onto Godot's own reverb, so Generative's Room slider is the
## same control rather than a second one wearing the name.
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
	# Rebuild the chain from scratch: a bus that survived a reload with a partial
	# chain is worse than no bus, and these are cheap to make.
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


## Resolve one audio layer onto the bus. `l` is the layer dict (empty = neutral).
## Every parameter is driven through the layer's own envelope in `env`, so an
## audio marker fades its sound in and out exactly like a visual one fades its
## paint - no separate concept, no separate code path.
func apply(l: Dictionary) -> void:
	if _fx_eq == null:
		return
	var amt := clampf(float(l.get("env", 0.0)) * float(l.get("intensity_a", 1.0)), 0.0, 1.0)
	# BASS. Two bands lifted together rather than one, because a single band's
	# bump is audible as a resonance rather than as weight. EQ6's bands are
	# 32/100/320/1000/3200/10000 Hz; the bottom two are the ones a voice's chest
	# and a kick's body live in.
	var bass := clampf(float(l.get("fx_stick", 0.0)), 0.0, 1.0) * amt
	_fx_eq.set_band_gain_db(0, bass * 12.0)
	_fx_eq.set_band_gain_db(1, bass * 8.0)
	# PUNCH is the compressor, and it rides the same knob - because "punchy" is
	# not more bass, it is bass that keeps its transient. Raising the bass alone
	# just makes a mix muddy, which is the trap this avoids by moving both.
	_fx_comp.threshold = lerpf(0.0, -18.0, bass)
	_fx_comp.ratio = lerpf(1.0, 5.0, bass)
	_fx_comp.gain = bass * 5.0
	_fx_comp.attack_us = lerpf(20.0, 8.0, bass)     # fast enough to catch a transient
	_fx_comp.release_ms = lerpf(250.0, 120.0, bass)   # ms, unlike attack_us - the two differ
	# ECHO. Lag is the time between repeats, Bleed how much comes back.
	var echo := clampf(float(l.get("fx_smooth", 0.0)), 0.0, 1.0) * amt
	_fx_delay.dry = 1.0
	_fx_delay.tap1_active = echo > 0.001
	_fx_delay.tap1_delay_ms = lerpf(60.0, 620.0, clampf(float(l.get("fx_lag", 0.35)), 0.0, 1.0))
	_fx_delay.tap1_level_db = linear_to_db(maxf(echo * 0.7, 0.0001))
	# The second tap at a non-multiple of the first, so repeats interleave into a
	# decay instead of landing on top of each other as one loud slap.
	_fx_delay.tap2_active = echo > 0.001
	_fx_delay.tap2_delay_ms = _fx_delay.tap1_delay_ms * 1.63
	_fx_delay.tap2_level_db = linear_to_db(maxf(echo * 0.45, 0.0001))
	_fx_delay.feedback_active = echo > 0.001
	_fx_delay.feedback_level_db = linear_to_db(maxf(echo * 0.35, 0.0001))
	# RESONANCE, as the delay's own feedback color: a tuned, ringing repeat
	# rather than a flat one. Low-passing the feedback path is what makes a tail
	# sound like a space rather than like a copy.
	var reso := clampf(float(l.get("fx_contrast", 0.5)), 0.0, 1.0)
	_fx_delay.feedback_lowpass = lerpf(16000.0, 900.0, reso * amt)
	# AMBIENCE. Room size and wet are separate on purpose - a big dry room and a
	# small wet one are different sounds, and collapsing them into one "reverb"
	# slider is what makes every preset sound the same.
	#
	# The mapping itself lives in [RoomFX] rather than here, because Generative has
	# the same Room now and cannot use this bus (it bakes its effects into a take
	# WAV; see the class docs). Only the RENDERER is mode-specific: this hands the
	# settings to Godot's reverb, that one runs the same network per sample.
	# Note the size is NOT scaled by the envelope while the wet is - a marker fades
	# a room IN, it does not grow the walls.
	_room.size = float(l.get("fx_scale", 1.0))
	_room.wet = clampf(float(l.get("fx_density", 0.45)), 0.0, 1.0) * amt
	_room.resonance = reso
	_room.to_reverb(_fx_reverb)
