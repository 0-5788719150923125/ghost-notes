extends RefCounted
class_name VoiceFX

## VoiceFX - the formant voice's ambience ([Voice]), over any PCM.
##
## An echo is a delay line and the resonance is a bank of narrow resonators excited by the voice, so
## both work on a buffer regardless of what made it. This is that ambience as a filter over arbitrary
## audio. It runs in the generative path's push loop, sample by sample, with all state held here so a
## chunk boundary is not a discontinuity.
##
## The resonance: in the formant voice the sympathetic strings are tuned to the reading's anchor notes (from the
## seed's genome). Any other voice has no genome, so the chord is derived from the audio, which keeps the
## effect answering the voice rather than playing over it. The pitch tracker is a cheap autocorrelation
## on a decimated signal, and the tones sit at consonant intervals above the tracked pitch.

# --- heard through something: a phone, a radio ----------------------------------
# A voice through a phone (next/dispatch.md). The telephone's band is 300-3400 Hz (ITU-T G.712's voice
# channel): a second-order Butterworth high-pass and low-pass at a row's `low` and `high` (an RBJ biquad
# each), then a soft clip, the small speaker's grit (`drive`: tanh, small-signal gain one), then its
# level (`gain`). Applied to the voice as it leaves the model and before anything of the room's, so the
# room hears the phone - and after the pitch tracker, which needs the fundamental the band takes away.
# A row further off is quieter and narrower: a phone on the desk is a smaller sound than one at the ear,
# and a voice in a room at the far end of a line is heard through that line and its room both. A radio
# is narrower and driven harder, under static of its own (below); any script may mark a turn
# `<!-- heard: radio -->`.
const HEARD := {
	"phone": {"label": "Through a phone", "blurb": "Held to the ear: the telephone's band, close, with a little grit and the line's faint hiss.",
		"low": 300.0, "high": 3400.0, "drive": 2.0, "gain": 0.95, "hiss": 0.004, "crackle": 0.0, "squelch": false},
	"desk": {"label": "From a phone on the desk", "blurb": "A phone lying open on the desk, on hold: the same band and line, smaller and further off.",
		"low": 420.0, "high": 3000.0, "drive": 1.5, "gain": 0.42, "hiss": 0.004, "crackle": 0.0, "squelch": false},
	"far": {"label": "Through somebody else's phone", "blurb": "A voice in the caller's room, heard through the caller's phone: narrower still, and faint.",
		"low": 500.0, "high": 2600.0, "drive": 1.2, "gain": 0.3, "hiss": 0.004, "crackle": 0.0, "squelch": false},
	"radio": {"label": "Over a radio", "blurb": "A two-way radio or a scanner: a narrow, hard-driven band under static that crackles, the squelch bursting as the voice keys up and hissing off after it.",
		"low": 350.0, "high": 2700.0, "drive": 3.0, "gain": 0.85, "hiss": 0.03, "crackle": 4.0, "squelch": true},
}

# --- ...and its static: a line's hiss, a radio's crackle -------------------------
# A row's `hiss` is white noise at that RMS and its `crackle` that many pops a second (each a few
# milliseconds of noise, random in size), added to the voice before the band, so the static is shaped by
# the band and clipped by the speaker as a real receiver's is. It rides the voice: the channel opens when
# the voice is heard (its envelope over STATIC_OPEN) and stays open STATIC_HOLD past its last sound, so
# it hisses through the gaps between words and never through the rests between turns. A row with
# `squelch` is a two-way radio: a short burst as the channel opens, and the tail as it closes.
# Pseudo-random from a seed of its own, so the same take is the same static, live and exported.
const STATIC_OPEN := 0.01        # the voice's envelope (its peak, full scale) that opens the channel
const STATIC_FOLLOW := 0.01      # seconds the envelope falls over
const STATIC_HOLD := 0.35        # seconds the channel stays open past the voice's last sound
const STATIC_FADE := 0.012       # seconds it fades in and out over
const STATIC_BURST := 0.05       # a radio's key-up burst, in seconds...
const STATIC_TAIL := 0.22        # ...and its squelch tail
const STATIC_KICK := 2.5         # how much louder than the hiss the burst and the tail begin
const CRACKLE_RING := 0.0015     # how long a pop rings, in seconds
const CRACKLE_KICK := 6.0        # how much louder than the hiss a pop is, at most

# --- echo: a room at the bottom of the dial, a slapback at the top ------------
# The setting chooses the character, not just the level. Past roughly 50 ms the precedence effect stops
# fusing a repeat with the direct sound and the ear hears a separate event, so a discrete repeat stays
# audible far below where a diffuse room would (speech detection thresholds at this delay sit around
# -20 to -25 dB), and 170 ms is about one syllable at a reading pace, so each repeat lands on the next
# word. So the tap shortens as the dial comes down, until it is inside the fusion window and reads as
# the room the voice is in; the feedback and the damping come down with it, and a second incommensurate
# tap keeps even the long setting from being a single hard image.
const ECHO_DELAY := 0.17       # the longest tap, and the delay line's size
const ECHO_NEAR := 0.028       # the shortest: inside the ~50 ms fusion window
const ECHO_TAP2 := 0.61        # second tap as a fraction of the first, not a simple ratio (a 1/2 or 1/3 tap re-lands on the first's repeats)
const ECHO_TAP2_MIX := 0.30
const ECHO_LP := 1400.0        # every repeat comes back darker...
const ECHO_LP_NEAR := 650.0    # ...and a small dark room is darker still
const ECHO_FB_NEAR := 0.12     # one repeat and gone, rather than a five-tap tail
## The dial's taper. Above 1 so the bottom of the travel is quiet (the useful narration settings live
## down there), but not much above: at a square taper 0.05 lands at -52 dB, inaudible. 1.5 puts 0.05 at
## -39 dB and 0.20 at -21 dB, both a room rather than a repeat (see ECHO_NEAR).
const ECHO_TAPER := 1.5

# --- resonance ---------------------------------------------------------------
const TONES := 4
# Just intervals above the tracked pitch: octave, fifth, octave+third, two octaves. They ring against
# the voice's own harmonics rather than beating with them.
const RATIOS := [2.0, 3.0, 5.0, 8.0]
const RES_Q := 0.9985          # decay per sample: seconds-long ring
# Excitation per sample into each resonator. The ring integrates over its whole decay, so this is a
# rate, not a level (0.004 lifts the peak 5%, inaudible); 0.05 with the output normalized by tone count
# lands clearly under the voice but present.
const RES_DRIVE := 0.05
const TRACK_HZ := 12.0         # pitch re-estimates per second
const PITCH_MIN := 70.0
const PITCH_MAX := 320.0
const PITCH_GLIDE := 0.08      # the chord follows the register, never jumps

# --- the pad: sustained ambient tones, DECOUPLED from the voice ---------------
#
# Distinct from the resonance above: resonance is excited by the voice (it rings when the voice rings
# and dies when it stops, like the room the voice is in). A pad is its own instrument: long tones that
# keep sounding through pauses, choosing notes on a scale, breathing on their own timescale.
#
# The key comes from the narration: a slow average of the tracked pitch gives the reader's register; the
# tonic is dropped two octaves so the pad sits underneath, and it glides, so a change of register moves
# the music instead of breaking it.
const PAD_VOICES := 5
# Minor pentatonic, in semitones. No two degrees are a semitone apart, so any combination is consonant
# and the scheduler cannot stack a clash however it overlaps them.
const PAD_SCALE := [0, 3, 5, 7, 10]
const PAD_OCTAVES := [0, 12, 12, 24]     # weighted toward one octave up
## No tone in the reader's register. The key sits two octaves under the voice, so the top octave of the
## stack (degree + 24) would land on the reader's own pitch (a 220 Hz voice over a bed spanning 55-392
## Hz), heard as a second voice humming along. A note above this many semitones over the key is dropped
## an octave: at most a fifth under the voice (147 Hz on that reader).
const PAD_CEILING := 17
## How long the speech envelope that ducks the bed takes to follow, in seconds. Per sample it would be
## ~0.11 s at the voice's 22.05 kHz and the bed would swell after every word.
const SPEECH_TAU := 1.0
const PAD_ATTACK := 3.5                  # seconds: tones swell, never start
const PAD_HOLD_MIN := 5.0
const PAD_HOLD_MAX := 14.0
const PAD_RELEASE := 7.0                 # long tails, so the bed never gates
const PAD_DETUNE := 0.004                # a second oscillator, slightly off
const PAD_GAP := 2.2                     # seconds between new tones entering
## The key follows the reader, slowly: the reader's register is the median of the pitch of the last this
## many voiced windows (20 s of voice). A mean of the pitch in Hz is pulled up by the tracker's octave
## errors.
const PAD_REGISTER := 240
# Narration is speech almost continuously, so a deep duck (0.55) keeps the bed down nearly all the
# time; 0.40 steps aside for the voice without vanishing behind it.
const PAD_DUCK := 0.40
## The dial is severity, not level. The bed plays at its full staged level (`pad_level`) whenever
## Ambience is on at all - it fades in over this much of the travel so 0 is a clean off, not a step. The
## rest of the dial buys more happening on top of it.
const PAD_FADE_IN := 0.05
## The bed sits under the voice it is given, at the balance it was staged at, however loud that voice
## comes out. Kokoro is hot (Puck 0.141 RMS speaking, Heart 0.086) against libritts-high's 0.065, so a
## fixed-level bed would sit 17 dB under Puck where it sits 9 under Piper. So the bed's level and its
## duck are scaled by the voice's own speaking level - the RMS of the windows the pitch tracker finds
## voiced, followed over PAD_LEVEL_TAU seconds of voice and primed with the key ([method prime_key]) -
## against PAD_VOICE_REF, that level on the voice the bed was staged under (libritts-high). The host
## plays every voice at one level (hosts/voice/level.py), and the bed still follows what it is given: a
## hushed reader, a model not levelled, Masking's own clip. Held to [PAD_SCALE_MIN, PAD_SCALE_MAX] of
## it, so a whisper does not take the bed away nor a shout make it a wall.
const PAD_VOICE_REF := 0.06
const PAD_LEVEL_TAU := 8.0
const PAD_SCALE_MIN := 0.33
const PAD_SCALE_MAX := 4.0
## How much of a take [method prime_key] reads for the voice's level, from its first sound (seconds): a
## reading opens louder than it goes on (Puck's first 4 s 1.35 times its level), so the bed over the
## intro starts that much over where it settles. 12 s is about 0.2 s of work.
const PAD_PRIME := 12.0
## The bed is staged by the ear. The ear hears a low tone far more quietly than its power says: under
## Puck (115 Hz) every tone of the bed is under 80 Hz, 30 dB under the voice A-weighted where
## libritts-high's bed is 22, and a speaker that small plays none of it. So a tone under PAD_AUDIBLE
## takes octave partials (PAD_H2, PAD_H4 at an octave under it, less above; octaves only, so no note is
## added the scale did not choose), its power held, and the tones are lifted by how much less audible
## the bed's register is than the one it was staged in (PAD_EAR_KEY, libritts-high's key as primed,
## plain tones; [method _audibility]) - at most PAD_EAR_MOST, at least its inverse. The bass is not: it
## is meant to be felt more than heard.
const PAD_AUDIBLE := 120.0
const PAD_H2 := 0.6
const PAD_H4 := 0.35
const PAD_EAR_KEY := 58.3
const PAD_EAR_MOST := 2.0

# --- no melody, on purpose ------------------------------------------------------
# Three melodic layers (a plucked string twice, a sliding lead) were tried and removed: choosing which
# note comes next needs a real model of music, and a handful of rules sounds like random notes. The bed
# works because it never has to choose (sustained, always-consonant tones), and the bass for the same
# reason (one note, the key's root, when the voice moves). Do not add a melody without that model.

# --- the bass: a low swell on the key's root, when the voice MOVES -----------------
# Cued by a shift in the reader's pitch away from its recent average (emphasis, a question, a change of
# register) and landing on the next bar line of a steady tempo drawn per reading, so swells a minute
# apart keep one pulse.
const BPM_MIN := 80.0                    # the bar grid's tempo, drawn once per reading
const BPM_MAX := 92.0
const BASS_ONSET := 0.3
const BASS_CHANCE := 0.7                 # a pitch move is answered this often at 1.0
const BASS_SHIFT := 2.0                  # semitones from the recent average that count as a move
const BASS_PITCH_TAU := 4.0              # seconds: what "recent average" means
const BASS_COOLDOWN := 4.0               # one move, one swell, not a swell per syllable
## A swell, never a pluck: it rises over this long (seconds).
const BASS_ATTACK := 1.2
const BASS_DECAY := 2.4                  # exponential time constant, seconds
const BASS_LEVEL := 1.0
const BASS_ROOT_LO := 41.0               # the bass root sits in [LO, 2 LO), unless the voice is low
## The bass stays under the voice, as the bed's tones do (PAD_CEILING): its second partial - the lowest
## a small speaker plays - at least this many semitones under the voice's middle, the root dropped an
## octave until it is. A root that would fall under BASS_FLOOR (A0, felt more than heard) is not played.
const BASS_UNDER := 7.0
const BASS_FLOOR := 27.5
# The key moves only when the slow register (`_tonic`, PAD_REGISTER) has left it by this much, so it
# does not hop between keys phrase to phrase.
const KEY_HYSTERESIS := 3.0
## The key is the voice's own: its root exactly two octaves under the middle of the voice's pitch - the
## register, once KEY_HEARD voiced windows are in it (3 s; [method prime_key] takes those of PAD_PRIME) -
## never snapped to A440's grid, which no voice speaks on. (A reading opens high, so the first window's
## pitch alone is a poor key.) No tone and no swell sounds before it is set.
const KEY_HEARD := 36

# --- lean: the reader moving around a microphone in the middle -------------------
#
# What an ASMR reader does on purpose: lean toward one side of the microphone, hold there, drift back.
# Only the direct voice moves. The echo, the room's tail, the resonance and the bed stay centered,
# because the room does not move when the person in it does.
#
# The dial is how often, not how far. Every lean goes most of the way toward the limit, so a rare lean
# at a low setting is still audible. What the dial buys is fewer and shorter rests at center, shorter
# holds at a side, and more crossings straight to the other side instead of back through the middle -
# until at 1 it never rests and never returns, a slow continuous sway.
#
# Level only, no delay: a varying sub-millisecond delay between two channels becomes a moving comb
# filter when they are summed, and a phone speaker, a mono earbud and the bake's own analysis all sum
# them.
## The near ear's share of the voice at the deepest lean: 70/30 and never further, so the far ear
## always hears the reader (about 7.4 dB apart at the limit).
const LEAN_SHARE := 0.7
const LEAN_DEPTH_MIN := 0.55            # a lean goes at least this far toward the limit
## How much of a voice over this one reaches the room as this one's does; the rest goes straight to the ears.
const SIDE_ROOM := 0.35
const LEAN_TRAVEL_MIN := 1.4            # seconds per move, eased at both ends
const LEAN_TRAVEL_MAX := 3.2
const LEAN_HOLD_MIN := 0.8              # how long a lean is held, at the bottom of the dial
const LEAN_HOLD_MAX := 6.0
const LEAN_HOLD_FLOOR := 0.15           # the turn at the top of the dial: a sway, not a wobble
const LEAN_REST_MAX := 45.0             # the longest rest at center, at the bottom of the dial
## Left and nearer at once. The two dials are one reader, so they compose two ways:
##   - an approach ([method near_to]) takes the reader toward one side this often, when Lean is up at
##     all - the side they are already on, or either from center - at the approach's own pace, held for
##     as long as they stay in, and brought back to center when they leave;
##   - closeness is what lets a lean reach the limit. With a microphone in the middle, the same offset
##     to one side is a wider angle up close, so a lean from where the reader sits reaches
##     LEAN_REACH_HOME of the way to 70/30 (about 67/33), all of it fully in, and less backed off.
##     70/30 is the most there ever is.
const LEAN_WITH_NEAR := 0.6
const LEAN_JOINT_TRAVEL := 2.0          # seconds: the approach's own pace (NEAR_TAU, two stages)
const LEAN_REACH_HOME := 0.85
const LEAN_REACH_BACK := 0.7

# --- near: the reader coming in to the microphone, and backing off -------------------
#
# Distance at a microphone is three things, and level is only one. Closer, the direct voice rises
# against the room and the proximity effect lifts the low end (the warmth that says "right at your ear"
# more than loudness does). Further, the reverse.
#
# A reader who comes in often drops their voice: the direct sound stays about as loud while the room
# falls away and the bass comes up. So the vocal level is its own quantity here (it feeds the whole
# chain, room included) and the distance is applied to the direct voice alone. A hushed approach is a
# voice dropped by about what the distance gives back.
#
# Per sentence, not per second. A hushed voice is softer as well as quieter (its spectral tilt is the
# voice host's, the request's effort), so the choice to come in is made when a sentence is planned
# ([method near_plan]); this chain only eases the distance, starting in the pause before it. Two
# one-pole stages in series, so a move starts and ends without a corner.
#
# No whisper: a hushed approach that asked the host for a partial whisper (piper `_whisper` blended
# with the voice) sounded garbled. It stays out until the whisper is good on its own.
const NEAR_TAU := 0.45                  # seconds per stage: about two seconds to arrive
const NEAR_IN_DB := 4.5                 # the direct voice, fully in
const NEAR_BACK_DB := 5.0               # ...and fully backed off
const NEAR_BASS_DB := 5.0               # the proximity effect, fully in (backed off: half, as a cut)
const NEAR_BASS_HZ := 220.0
const NEAR_HUSH_DB := 6.0               # how far a hushed reader drops their voice, fully in
const NEAR_STEP := 32                   # samples between gain updates: the move takes seconds
## The plan's draws. At home, a sentence starts a move NEAR_MOVE_POW-curved by the dial; a move lasts
## 1..NEAR_RUN_MAX sentences (1 at the top); from a move, the reader goes home - or, the dial squared of
## the time, straight to the opposite move, which at 1 is a constant in-and-out.
const NEAR_MOVE_POW := 1.2
const NEAR_RUN_MAX := 3
const NEAR_BACK_CHANCE := 0.2           # of the moves from home, how many back off rather than come in
## Of the approaches, how many are hushed (the voice dropped); the rest are plain (louder).
const NEAR_HUSHED := 0.6

var sample_rate := 22050
var echo_wet := 0.0            # 0..1
var echo_feedback := 0.42
var resonance := 0.0           # 0..1
## The room, which is not the echo above and is the reason both exist. The echo is discrete: taps at a
## measurable delay, heard as repeats of the voice however small the room is made. This is the diffuse
## half - a comb/allpass network with no countable events - the space the voice is in rather than a
## copy of it arriving late.
##
## Shared with Masking: [RoomFX] holds the dial and its meanings, and only the engine differs.
var room := RoomFX.new()
var presence := 1.0            # 1 = in the room, lower = further away
## What this voice is heard through, a key of [constant HEARD] ("" the room): dialed with its room at each
## turn ([constant Manuscript.HEARD], [member ReadingJoin.marks]).
var heard := ""
var pad := 0.0                 # 0..1 the ambient bed
var pad_seed := 0              # same text, same music
# Staged by sweeping against real narration (voice RMS 0.0474): 0.012 sits 11.8 dB below the voice (too
# quiet), 0.022 sits 6.5 dB below (present without competing, chosen), 0.035 sits 2.5 dB below
# (competes). That is the slider's maximum, so half-way gives roughly -12 dB. Under a louder or quieter
# voice it is scaled with it (PAD_VOICE_REF).
var pad_level := 0.022
var pad_duck := PAD_DUCK       # how far the bed steps back under speech
var lean := 0.0                # 0..1 how often the reader leans to one side (see LEAN_SHARE)
## Where this voice sits: -1 the left ear to 1 the right ([method Delivery.pan_of_seat]). A lean moves from here. Heard only in the direct voice, as a lean is.
var seat := 0.0
## The voices over this one, for the buffer about to be run ([method ReadingJoin.side_between]): left and right, already where they sit. Taken once.
var side := PackedVector2Array()

var _echo := PackedFloat32Array()
var _echo_i := 0
var _echo_lp := 0.0
# Resolved from echo_wet whenever it moves (the slider is live), not per sample.
var _echo_k := -1.0            # the setting these were resolved for
var _echo_n1 := 0              # near tap, in samples behind the write head
var _echo_n2 := 0              # far tap
var _echo_gain := 0.0
var _echo_fb := 0.0
var _echo_a := 0.0             # damping coefficient
var _res_re := PackedFloat32Array()
var _res_im := PackedFloat32Array()
var _res_env := PackedFloat32Array()
var _pitch := 0.0
var _track := PackedFloat32Array()
var _track_n := 0
var _lp := 0.0                 # presence: distance darkens as well as quietens
var _p_re := PackedFloat32Array()
var _p_im := PackedFloat32Array()
var _p_re2 := PackedFloat32Array()
var _p_im2 := PackedFloat32Array()
var _p_cos := PackedFloat32Array()
var _p_sin := PackedFloat32Array()
var _p_cos2 := PackedFloat32Array()
var _p_sin2 := PackedFloat32Array()
var _p_env := PackedFloat32Array()
var _p_hold := PackedFloat32Array()
var _p_state := PackedInt32Array()      # 0 idle, 1 attack, 2 hold, 3 release
var _p_h2 := PackedFloat32Array()       # a tone's octave partials (PAD_H2, PAD_H4 as it is low), and the scale
var _p_h4 := PackedFloat32Array()       # that keeps its power a plain tone's
var _p_n := PackedFloat32Array()
var _ear_k := 1.0                       # the tones' lift for the ear in this key (PAD_EAR_KEY)
var _tonic := 0.0                       # Hz, the pad's root
var _next_note := 0.0
var _speech := 0.0                      # smoothed |voice|, for the duck
var _track_e := 0.0                     # the tracking window's sum of squares so far
var _voice_ms := 0.0                    # the voice's speaking level (mean square), 0 before it is heard
var _pad_k := 1.0                       # what it scales the bed by (see PAD_VOICE_REF)
var _rng := RandomNumberGenerator.new()
# The events draw from their own generator, so moving the dial changes what is added on top without
# re-rolling the bed's notes.
var _ev_rng := RandomNumberGenerator.new()
var _key_semi := -1000.0                # the key's root, semitones from A440; -1000 = none yet
var _register := PackedFloat32Array()   # the last PAD_REGISTER voiced windows' pitch (semitones)
var _register_at := 0                   # the oldest of them, once it is full
var _clock := 0                         # samples since setup
var _eighth := 1                        # samples per eighth note; a bar is eight
var _bass_at := -1                      # a swell waiting for its bar line
var _bass_hz := 0.0
var _pitch_slow := 0.0                  # the reader's recent pitch, for the bass cue
var _bass_cool := 0.0
var _bass_ph := 0.0
var _bass_w := 0.0
var _bass_env := 0.0
var _bass_rise := false
# The lean: a position in [-1, 1] (right is positive), eased from one place to the next.
var _lean_rng := RandomNumberGenerator.new()
var _lean_from := 0.0
var _lean_to := 0.0
var _lean_pos := 0.0
var _lean_t := 0.0                      # seconds into the current move
var _lean_dur := 0.0                    # its length; 0 = resting where it is
var _lean_hold := 0.0                   # seconds of rest left before the next move
var _lean_k := -1.0                     # the dial the hold was drawn for
var _lean_joint := false                # held at a side for an approach (see LEAN_WITH_NEAR)
var _lp_v := 0.0                        # presence on the direct voice alone, for the lean
# The distance: targets from [method near_to], each eased through two one-pole stages.
var _near_to := 0.0                     # -1 backed off .. 1 fully in
var _hush_to := 0.0                     # 0..1 how far the reader has dropped their voice
var _near_a := Vector2.ZERO             # stage 1 (x distance, y hush)
var _near_b := Vector2.ZERO             # stage 2: what is heard
var _near_n := 0                        # samples to the next gain update
var _near_vg := 1.0                     # the vocal level, into the whole chain
var _near_dg := 1.0                     # the distance, on the direct voice
var _near_bg := 1.0                     # ...and its low band, on top of that
var _near_lp := 0.0                     # the direct voice's low band
# Heard through a phone: the two biquads' coefficients (b0 b1 b2 a1 a2 each, resolved when [member heard] changes) and
# their states (x1 x2 y1 y2 each), the soft clip and the level.
var _hd_for := "?"
var _hd := PackedFloat32Array([0, 0, 0, 0, 0, 0, 0, 0, 0, 0])
var _hs := PackedFloat32Array([0, 0, 0, 0, 0, 0, 0, 0])
var _hd_drive := 1.0
var _hd_gain := 1.0
# ...and its static: the row's levels, the channel's state (open for `_st_hold` samples more, faded by `_st_gate`), a
# radio's burst and tail left to play, the pop ringing now, and the static's own generator (xorshift32, never reset).
var _st_hiss := 0.0
var _st_crackle := 0.0
var _st_squelch := false
var _st_env := 0.0
var _st_hold := 0
var _st_gate := 0.0
var _st_burst := 0
var _st_tail := 0
var _st_pop := 0.0
var _st_k := PackedFloat32Array([0, 0, 0, 0])   # the envelope's fall, the fade's step, the pop's ring, a pop's chance
var _st_rng := 0x2545F491

func setup(sr: int) -> void:
	sample_rate = sr
	_echo.resize(maxi(1, int(ECHO_DELAY * sr)))
	_echo.fill(0.0)
	_echo_i = 0
	_res_re.resize(TONES)
	_res_im.resize(TONES)
	_res_env.resize(TONES)
	for i in TONES:
		_res_re[i] = 0.0
		_res_im[i] = 0.0
		_res_env[i] = 0.0
	_track.resize(maxi(1, int(sr / TRACK_HZ)))
	_track_n = 0
	_pitch = 0.0
	for arr in [_p_re, _p_im, _p_re2, _p_im2, _p_cos, _p_sin, _p_cos2, _p_sin2,
			_p_env, _p_hold, _p_h2, _p_h4, _p_n]:
		arr.resize(PAD_VOICES)
		arr.fill(0.0)
	_p_state.resize(PAD_VOICES)
	_p_state.fill(0)
	_tonic = 0.0
	_next_note = 0.5
	_speech = 0.0
	_track_e = 0.0
	_voice_ms = 0.0
	_pad_k = 1.0
	_ear_k = 1.0
	_rng.seed = pad_seed
	_ev_rng.seed = pad_seed + 7919
	_key_semi = -1000.0
	_register = PackedFloat32Array()
	_register_at = 0
	_clock = 0
	_eighth = maxi(1, int(round(sr * 30.0 / _ev_rng.randf_range(BPM_MIN, BPM_MAX))))
	_bass_at = -1
	_pitch_slow = 0.0
	_bass_cool = 0.0
	_bass_env = 0.0
	_bass_rise = false
	# its own generator, like the events: moving the Lean dial re-rolls nothing else
	_lean_rng.seed = pad_seed + 104729
	_lean_from = 0.0
	_lean_to = 0.0
	_lean_pos = 0.0
	_lean_t = 0.0
	_lean_dur = 0.0
	_lean_k = -1.0
	_lean_hold = 0.0
	_lean_joint = false
	_lp_v = 0.0
	_near_to = 0.0
	_hush_to = 0.0
	_near_a = Vector2.ZERO
	_near_b = Vector2.ZERO
	_near_n = 0
	_near_vg = 1.0
	_near_dg = 1.0
	_near_bg = 1.0
	_near_lp = 0.0
	room.setup(sr)


## Teach the pad its key before processing, from a buffer that has not been heard yet.
##
## The pad is key-slaved: `_tonic` is derived from the tracked pitch of the voice, two octaves down, and
## `_start_tone` schedules nothing while it is zero. A leading silence has no pitch (the estimator
## returns 0 under its energy floor), so without this a bed over an intro would sit mute until the
## narration began.
##
## So: scan forward over the voiced windows of the first PAD_PRIME seconds of sound and set the key from
## the middle of their pitch (KEY_HEARD's rule, from more of them). One pass; it does not touch the
## resonators or the echo line, so the chain is still cold when [method process] starts. The glide in
## `process` then carries the key onward as the reader moves.
##
## The resonance gets no equivalent: it is excited only by the dry signal, and priming it would invent
## an excitation that was never played.
##
## The voice's level is primed with it (see PAD_VOICE_REF): the voiced windows of the first PAD_PRIME
## seconds of sound, so the bed over the intro is already at the level it will keep under the voice.
func prime_key(buf: PackedFloat32Array) -> void:
	if _track.is_empty():
		setup(sample_rate)
	var win := _track.size()
	if win <= 0 or buf.size() < win:
		return
	# skip the silence cheaply first: the buffer opens with the whole intro of digital zeros, so a scan
	# from sample 0 that gives up after a fixed couple of seconds examines only padding. A scalar
	# amplitude test costs one compare per sample and finds the voice exactly.
	var first := -1
	for i in buf.size():
		if absf(buf[i]) > 0.004:
			first = i
			break
	if first < 0:
		return                                  # the whole take is silent
	# from there, PAD_PRIME seconds: the key and the level get as many voiced windows as they can, and
	# bounding it keeps a 20-minute chapter off the critical path
	var limit := mini(buf.size() - win, first + int(PAD_PRIME * float(sample_rate)))
	var pos := first
	var ms := 0.0
	var heard := PackedFloat32Array()
	while pos <= limit:
		var chunk := buf.slice(pos, pos + win)
		var f := _estimate_pitch(chunk)
		if f > 0.0:
			heard.append(_semis(f))
			var e := 0.0
			for x in chunk:
				e += x * x
			ms += e / float(win)
		pos += win
	if not heard.is_empty():
		_register = heard.slice(maxi(0, heard.size() - PAD_REGISTER))
		_register_at = 0
		_tonic = 0.0
		_hear_register(true)
		_pitch = _tonic * 4.0
		_voice_ms = ms / float(heard.size())
		_level_pad()


## A voiced window's pitch [param s] (semitones from A440), into the reader's register (PAD_REGISTER).
func _hear(s: float) -> void:
	if _register.size() < PAD_REGISTER:
		_register.append(s)
	else:
		_register[_register_at] = s
		_register_at = (_register_at + 1) % PAD_REGISTER
	_hear_register(false)


## The register's middle as the slow tonic, two octaves down; the key set from it once KEY_HEARD
## windows are in it ([param now]: whatever there are), and moved with it ([method _follow_key]).
func _hear_register(now: bool) -> void:
	if _register.is_empty() or (_key_semi <= -1000.0 and not now and _register.size() < KEY_HEARD):
		return
	var sorted := _register.duplicate()
	sorted.sort()
	var mid := sorted[sorted.size() / 2] - 24.0
	_tonic = 440.0 * pow(2.0, mid / 12.0)
	if _key_semi <= -1000.0:
		_key_semi = mid
		_ear()
	_follow_key()


## [param hz] in semitones from A440.
static func _semis(hz: float) -> float:
	return 12.0 * log(hz / 440.0) / log(2.0)


## The bed's scale from the voice's level ([member _voice_ms]): see PAD_VOICE_REF.
func _level_pad() -> void:
	_pad_k = 1.0 if _voice_ms <= 0.0 else clampf(sqrt(_voice_ms) / PAD_VOICE_REF, PAD_SCALE_MIN, PAD_SCALE_MAX)


## Turn the echo dial into an actual room: tap times, feedback, damping and gain. Everything moves
## together (a dial that moved only the gain is unusable on speech; see the constants above). The dial's
## own `echo_feedback` still sets the top of the feedback travel.
##
## Cheap and idempotent: the slider is live, so this runs once per buffer and returns at once unless the
## setting moved.
func _resolve_echo() -> void:
	var k := clampf(echo_wet, 0.0, 1.0)
	if is_equal_approx(k, _echo_k):
		return
	_echo_k = k
	var sz := maxi(1, _echo.size())
	# the tap shortens toward the fusion window as the dial comes down; `k` is raw (not tapered) because
	# this is about character: the room should be small by the time the level is subtle
	var d1 := lerpf(ECHO_NEAR, ECHO_DELAY, k)
	_echo_n1 = clampi(int(round(d1 * sample_rate)), 1, sz - 1)
	_echo_n2 = clampi(int(round(d1 * ECHO_TAP2 * sample_rate)), 1, sz - 1)
	_echo_fb = lerpf(ECHO_FB_NEAR, echo_feedback, k)
	_echo_a = 1.0 - exp(-TAU * lerpf(ECHO_LP_NEAR, ECHO_LP, k) / sample_rate)
	# the level is tapered, so the bottom of the dial is quiet on top of being small
	_echo_gain = pow(k, ECHO_TAPER)


## Process in place. `buf` is mono float samples; returns the same array so the copy-on-write semantics
## of PackedFloat32Array cannot drop the work. This is the centered mix - what [method process_stereo]
## gives both ears with no lean.
func process(buf: PackedFloat32Array) -> PackedFloat32Array:
	return _run(buf, false)[0]


## The same chain, as left/right frames, with the direct voice placed by the lean. With
## [member lean] at 0 and the reader at center, both channels are [method process]'s output.
func process_stereo(buf: PackedFloat32Array) -> PackedVector2Array:
	return _run(buf, true)[1]


func _run(buf: PackedFloat32Array, stereo: bool) -> Array:
	if _echo.is_empty():
		setup(sample_rate)
	var over := side
	side = PackedVector2Array()
	var has_over := not over.is_empty()
	_resolve_echo()
	# as _resolve_echo: the dial is live, so the room's settings are resolved once here, not per sample
	room.prepare()
	var room_on := room.is_active()
	var n := buf.size()
	var out := PackedVector2Array()
	var direct_g := room.dry_gain() if room_on else 1.0
	var pres_a := 1.0 - exp(-TAU * 900.0 * pow(2.0, 4.0 * presence) / sample_rate)
	if stereo:
		out.resize(n)
		_resolve_lean()
	var near_k := 1.0 - exp(-1.0 / (NEAR_TAU * sample_rate))
	var near_lp_a := 1.0 - exp(-TAU * NEAR_BASS_HZ / sample_rate)
	var res_step := PackedFloat32Array()
	res_step.resize(TONES)
	var heard_on := _resolve_heard()
	for i in n:
		# --- near: the reader's distance, eased; the vocal level feeds everything ---
		# Off entirely once home and settled, so a reading with Near at 0 is the chain it was.
		var near_on := _near_to != 0.0 or _hush_to != 0.0 or _near_b != Vector2.ZERO
		if near_on:
			var want := Vector2(_near_to, _hush_to)
			_near_a += (want - _near_a) * near_k
			_near_b += (_near_a - _near_b) * near_k
			if want == Vector2.ZERO and _near_b.length() < 1e-4:
				_near_a = Vector2.ZERO
				_near_b = Vector2.ZERO
			_near_n -= 1
			if _near_n <= 0:
				_near_n = NEAR_STEP
				_near_gains()
		var dry := buf[i] * _near_vg if near_on else buf[i]
		var sv := over[i] if has_over and i < over.size() else Vector2.ZERO

		# --- pitch tracking, at TRACK_HZ rather than per sample ---
		_track[_track_n] = dry
		_track_e += dry * dry
		_track_n += 1
		if _track_n >= _track.size():
			_track_n = 0
			var f := _estimate_pitch(_track)
			if f > 0.0:
				_pitch = f if _pitch <= 0.0 else lerpf(_pitch, f, PITCH_GLIDE)
				# the reader's register, and the key once enough of it is heard to know its middle
				_hear(_semis(f))
				# ...and the voice's level, from the windows it speaks in (see PAD_VOICE_REF)
				var ms := _track_e / float(_track.size())
				_voice_ms = ms if _voice_ms <= 0.0 \
					else lerpf(_voice_ms, ms, 1.0 - exp(-1.0 / (PAD_LEVEL_TAU * TRACK_HZ)))
				_level_pad()
			_track_e = 0.0

		# --- heard through a phone: the band, its grit, its level - as the voice leaves it, before the room hears it ---
		if heard_on:
			dry = _heard_tick(dry)

		# ...The room hears the voices over this one too: it is one room
		var wet := dry + (sv.x + sv.y) * 0.5 * SIDE_ROOM

		# --- resonance: a chord excited by the voice's own energy ---
		if resonance > 0.0 and _pitch > 0.0:
			var sum := 0.0
			for k in TONES:
				var hz: float = _pitch * float(RATIOS[k])
				if hz >= sample_rate * 0.45:
					continue
				var w := TAU * hz / sample_rate
				# one-pole complex resonator: cheap, stable, and its magnitude is the ring envelope
				var re := _res_re[k] * cos(w) - _res_im[k] * sin(w)
				var im := _res_re[k] * sin(w) + _res_im[k] * cos(w)
				re = re * RES_Q + dry * RES_DRIVE
				im *= RES_Q
				_res_re[k] = re
				_res_im[k] = im
				sum += re
			wet += (sum / float(TONES)) * resonance

		# --- the pad: its own instrument, on its own clock ---
		if pad > 0.0:
			_speech += (absf(dry) - _speech) / (SPEECH_TAU * sample_rate)
			var mix := 0.0
			for k in PAD_VOICES:
				if _p_state[k] == 0:
					continue
				# complex rotation: 4 mults, no sin() in the sample loop
				var pre := _p_re[k] * _p_cos[k] - _p_im[k] * _p_sin[k]
				var pim := _p_re[k] * _p_sin[k] + _p_im[k] * _p_cos[k]
				_p_re[k] = pre
				_p_im[k] = pim
				var pre2 := _p_re2[k] * _p_cos2[k] - _p_im2[k] * _p_sin2[k]
				var pim2 := _p_re2[k] * _p_sin2[k] + _p_im2[k] * _p_cos2[k]
				_p_re2[k] = pre2
				_p_im2[k] = pim2
				match _p_state[k]:
					1:
						_p_env[k] = minf(1.0, _p_env[k] + 1.0 / (PAD_ATTACK * sample_rate))
						if _p_env[k] >= 1.0:
							_p_state[k] = 2
					2:
						_p_hold[k] -= 1.0 / sample_rate
						if _p_hold[k] <= 0.0:
							_p_state[k] = 3
					3:
						_p_env[k] -= 1.0 / (PAD_RELEASE * sample_rate)
						if _p_env[k] <= 0.0:
							_p_env[k] = 0.0
							_p_state[k] = 0
				var e: float = _p_env[k]
				var tone := pre
				if _p_h2[k] > 0.0:
					# its octave partials, from the rotation itself: cos 2x and cos 4x
					var c2 := pre * pre - pim * pim
					var s2 := 2.0 * pre * pim
					tone += _p_h2[k] * c2 + _p_h4[k] * (c2 * c2 - s2 * s2)
				mix += (tone + pre2 * 0.6) * _p_n[k] * e * e      # squared: a gentler swell
			# the duck hears the voice as the staged one would sound: scaled alike, or a louder voice
			# would hold the bed pressed down through every gap
			var duck := 1.0 - pad_duck * clampf(_speech * 12.0 / _pad_k, 0.0, 1.0)
			# staged by measurement: the bed sits well below the voice (at 0.22 it measured RMS 0.14
			# against the narration's 0.047), audible when listened for, never competing
			mix = mix * _ear_k + _tick_events(dry)
			wet += mix * smoothstep(0.0, PAD_FADE_IN, pad) * pad_level * _pad_k * duck
			_next_note -= 1.0 / sample_rate
			if _next_note <= 0.0 and _key_semi > -1000.0:
				_next_note = PAD_GAP * _rng.randf_range(0.7, 1.8)
				_start_tone()

		# --- echo: a room down low, a slapback up high, darker on every repeat ---
		if echo_wet > 0.0:
			var sz := _echo.size()
			var back := _echo[(_echo_i + sz - _echo_n1) % sz] * (1.0 - ECHO_TAP2_MIX) \
				+ _echo[(_echo_i + sz - _echo_n2) % sz] * ECHO_TAP2_MIX
			_echo_lp += (back - _echo_lp) * _echo_a
			wet += _echo_lp * _echo_gain
			_echo[_echo_i] = dry + _echo_lp * _echo_fb
			_echo_i = (_echo_i + 1) % sz

		# --- the room: last, around all of it, as a room is ---
		# The same place Masking's bus chain puts it: the room has to hear the echo, the resonance and
		# the bed.
		if room_on:
			wet = room.tick(wet)

		# --- presence: distance is a filter first, a gain second ---
		if presence < 0.995:
			_lp += pres_a * (wet - _lp)
			wet = _lp * maxf(presence, 0.05)

		# the direct voice's share of `wet`. Everything above is linear, so it is the dry sample through
		# the room's dry gain and the same presence filter; moving or shaping only that share leaves the
		# room, the echo and the bed where they were. Its filter state is kept whenever presence filters
		# at all, so a lean or an approach that starts mid-reading starts from the right place.
		var direct := dry * direct_g
		if presence < 0.995:
			_lp_v += pres_a * (direct - _lp_v)
			direct = _lp_v * maxf(presence, 0.05)

		# --- near: distance on the direct voice, the proximity effect on its low band ---
		if near_on:
			_near_lp += near_lp_a * (direct - _near_lp)
			var shaped := direct * _near_dg + _near_lp * _near_dg * (_near_bg - 1.0)
			wet += shaped - direct
			direct = shaped

		buf[i] = clampf(wet + (sv.x + sv.y) * 0.5 * (1.0 - SIDE_ROOM), -1.0, 1.0)

		# --- lean: the direct voice, moved between the ears ---
		if stereo:
			var p := _tick_lean()
			if p == 0.0 and seat == 0.0:
				out[i] = Vector2(clampf(wet + sv.x * (1.0 - SIDE_ROOM), -1.0, 1.0), clampf(wet + sv.y * (1.0 - SIDE_ROOM), -1.0, 1.0))
			else:
				var c := _near_b.x
				var reach := lerpf(LEAN_REACH_HOME, 1.0, c) if c >= 0.0 \
					else lerpf(LEAN_REACH_HOME, LEAN_REACH_BACK, -c)
				var g := lean_gains(clampf(seat + p * reach, -1.0, 1.0))
				out[i] = Vector2(clampf(wet + direct * (g.x - 1.0) + sv.x * (1.0 - SIDE_ROOM), -1.0, 1.0),
					clampf(wet + direct * (g.y - 1.0) + sv.y * (1.0 - SIDE_ROOM), -1.0, 1.0))
	return [buf, out]


## [member heard]'s filters for this buffer: resolved when it changed (its states cleared, so a voice
## heard through a phone does not begin with the last one's ringing), and whether there is a phone to
## hear it through at all.
func _resolve_heard() -> bool:
	var key := heard if HEARD.has(heard) else ""
	if key == _hd_for:
		return not key.is_empty()
	_hd_for = key
	_hs.fill(0.0)
	if key.is_empty():
		return false
	var row: Dictionary = HEARD[key]
	var hp := biquad("high", float(row["low"]), float(sample_rate))
	var lp := biquad("low", float(row["high"]), float(sample_rate))
	for k in 5:
		_hd[k] = hp[k]
		_hd[5 + k] = lp[k]
	_hd_drive = maxf(float(row["drive"]), 0.01)
	_hd_gain = float(row["gain"])
	_st_hiss = float(row.get("hiss", 0.0))
	_st_crackle = float(row.get("crackle", 0.0))
	_st_squelch = bool(row.get("squelch", false))
	var sr := float(sample_rate)
	_st_k[0] = exp(-1.0 / (STATIC_FOLLOW * sr))
	_st_k[1] = 1.0 / (STATIC_FADE * sr)
	_st_k[2] = exp(-1.0 / (CRACKLE_RING * sr))
	_st_k[3] = _st_crackle / sr
	_st_env = 0.0
	_st_hold = 0
	_st_gate = 0.0
	_st_burst = 0
	_st_tail = 0
	_st_pop = 0.0
	return true


## One sample through the phone: its static added, high-pass, low-pass, the clip, the level.
func _heard_tick(v: float) -> float:
	var x := v + _static_tick(v)
	var y := _hd[0] * x + _hd[1] * _hs[0] + _hd[2] * _hs[1] - _hd[3] * _hs[2] - _hd[4] * _hs[3]
	_hs[1] = _hs[0]
	_hs[0] = x
	_hs[3] = _hs[2]
	_hs[2] = y
	var z := _hd[5] * y + _hd[6] * _hs[4] + _hd[7] * _hs[5] - _hd[8] * _hs[6] - _hd[9] * _hs[7]
	_hs[5] = _hs[4]
	_hs[4] = y
	_hs[7] = _hs[6]
	_hs[6] = z
	return tanh(z * _hd_drive) / _hd_drive * _hd_gain


## The line's static for one sample of the voice [param v] (see [constant STATIC_OPEN]): the hiss while the channel is open,
## a radio's burst and tail, a crackle's pop - 0 where the row has none and the channel is shut.
func _static_tick(v: float) -> float:
	if _st_hiss <= 0.0 and _st_crackle <= 0.0:
		return 0.0
	var sr := float(sample_rate)
	var a := absf(v)
	_st_env = a if a > _st_env else _st_env * _st_k[0]
	if _st_env > STATIC_OPEN:
		if _st_hold <= 0 and _st_squelch:
			_st_burst = int(STATIC_BURST * sr)
			_st_tail = 0
		_st_hold = int(STATIC_HOLD * sr)
	elif _st_hold > 0:
		_st_hold -= 1
		if _st_hold == 0 and _st_squelch:
			_st_tail = int(STATIC_TAIL * sr)
	_st_gate = move_toward(_st_gate, 1.0 if _st_hold > 0 else 0.0, _st_k[1])
	var level := _st_hiss * _st_gate
	if _st_burst > 0:
		level += _st_hiss * STATIC_KICK * float(_st_burst) / (STATIC_BURST * sr)
		_st_burst -= 1
	if _st_tail > 0:
		level += _st_hiss * STATIC_KICK * float(_st_tail) / (STATIC_TAIL * sr)
		_st_tail -= 1
	if level <= 0.0 and absf(_st_pop) < 1e-6:
		return 0.0
	# uniform noise has an RMS of 1/sqrt(3): scaled, the hiss is the row's RMS
	var n := _st_white() * level * 1.7320508
	if _st_crackle > 0.0 and level > 0.0 and _st_rand() < _st_k[3]:
		_st_pop = _st_hiss * CRACKLE_KICK * (0.3 + 0.7 * _st_rand())
	if _st_pop != 0.0:
		n += _st_pop * _st_white()
		_st_pop *= _st_k[2]
		if absf(_st_pop) < 1e-6:
			_st_pop = 0.0
	return n


## The static's generator: the next number in [0, 1) (xorshift32).
func _st_rand() -> float:
	_st_rng ^= (_st_rng << 13) & 0xFFFFFFFF
	_st_rng ^= _st_rng >> 17
	_st_rng ^= (_st_rng << 5) & 0xFFFFFFFF
	return float(_st_rng & 0xFFFFFF) / 16777216.0


## ...and in [-1, 1).
func _st_white() -> float:
	return _st_rand() * 2.0 - 1.0


## A second-order Butterworth ("high" or "low") at [param hz] for [param sr]: `[b0, b1, b2, a1, a2]`, a0
## divided out (Bristow-Johnson's cookbook, Q 1/sqrt 2).
static func biquad(kind: String, hz: float, sr: float) -> PackedFloat32Array:
	var w := TAU * clampf(hz, 10.0, sr * 0.45) / sr
	var cw := cos(w)
	var alpha := sin(w) / (2.0 * 0.70710678)
	var a0 := 1.0 + alpha
	var b0 := (1.0 - cw) * 0.5 if kind == "low" else (1.0 + cw) * 0.5
	var b1 := (1.0 - cw) if kind == "low" else -(1.0 + cw)
	return PackedFloat32Array([b0 / a0, b1 / a0, b0 / a0, -2.0 * cw / a0, (1.0 - alpha) / a0])


## The reader's next distance: [param c] from -1 (backed off) through 0 (where they sit) to 1 (right at
## the microphone), and [param hush] 0..1, how far they drop their voice for it - only coming in, since
## nobody leans back to speak more quietly. Eased from wherever the reader is now ([constant NEAR_TAU]).
func near_to(c: float, hush: float) -> void:
	var was := _near_to
	_near_to = clampf(c, -1.0, 1.0)
	_hush_to = clampf(hush, 0.0, 1.0) * maxf(_near_to, 0.0)
	_join_lean(was)


## An approach that takes the reader to one side as well (see [constant LEAN_WITH_NEAR]), and the way
## back from it. Draws from the lean's own generator, so the same marks make the same moves in the
## reading, the audition and the export.
func _join_lean(was: float) -> void:
	var k := clampf(lean, 0.0, 1.0)
	if _near_to > 0.0 and was <= 0.0:
		if k > 0.0 and _lean_rng.randf() < LEAN_WITH_NEAR:
			var side := signf(_lean_pos) if absf(_lean_pos) > 0.01 \
				else (-1.0 if _lean_rng.randf() < 0.5 else 1.0)
			_lean_move(side * _lean_rng.randf_range(lerpf(LEAN_DEPTH_MIN, 0.85, k), 1.0))
			_lean_hold = INF
			_lean_joint = true
	elif _near_to <= 0.0 and _lean_joint:
		_lean_joint = false
		_lean_move(0.0)
		_lean_hold = _lean_rng.randf_range(0.4, 1.0) * LEAN_REST_MAX * pow(1.0 - k, 1.5)


func _lean_move(to: float) -> void:
	_lean_from = _lean_pos
	_lean_to = to
	_lean_t = 0.0
	_lean_dur = LEAN_JOINT_TRAVEL


## The gains for where the reader is now: dB, so a move is even to the ear.
func _near_gains() -> void:
	var c := _near_b.x
	var in_ := maxf(c, 0.0)
	var back := maxf(-c, 0.0)
	_near_vg = db_to_linear(-NEAR_HUSH_DB * _near_b.y)
	_near_dg = db_to_linear(NEAR_IN_DB * in_ - NEAR_BACK_DB * back)
	_near_bg = db_to_linear(NEAR_BASS_DB * in_ - 0.5 * NEAR_BASS_DB * back)


## Where the reader is for each sentence: `{c, hush}` per entry of [param ks], the Near dial of the voice
## reading that sentence, keyed by [param who] (the speaker, so each voice moves on its own). Seeded, and
## every sentence takes the same five draws whatever the dial, so moving the dial changes how often and
## how far the same moments move. The softer delivery scales with the move too. At 0 the reader never
## moves.
static func near_plan(ks: PackedFloat32Array, who: PackedStringArray, seed: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var state := {}                     # speaker -> [current {c, hush}, sentences left]
	var home := {"c": 0.0, "hush": 0.0}
	var out: Array = []
	for i in ks.size():
		var k := clampf(ks[i], 0.0, 1.0)
		# whether to move, which way, for how long, how far, and in what manner
		var u := [rng.randf(), rng.randf(), rng.randf(), rng.randf(), rng.randf()]
		var st: Array = state.get(who[i], [home, 0])
		var cur: Dictionary = st[0]
		var left := int(st[1])
		if k <= 0.0:
			cur = home
			left = 0
		elif left > 0:
			left -= 1
		else:
			var away := float(cur["c"]) != 0.0
			var go := 0                     # 0 home, 1 in, -1 back
			if away:
				# the opposite move, k^2 of the time; otherwise home
				if float(u[0]) < k * k:
					go = -1 if float(cur["c"]) > 0.0 else 1
			elif float(u[0]) < pow(k, NEAR_MOVE_POW):
				go = -1 if float(u[1]) < NEAR_BACK_CHANCE else 1
			if go == 0:
				cur = home
			else:
				left = int(float(u[2]) * lerpf(float(NEAR_RUN_MAX), 1.0, k))
				var depth := k * lerpf(0.6, 1.0, float(u[3]))
				if go < 0:
					cur = {"c": -depth, "hush": 0.0}
				else:
					cur = {"c": depth, "hush": depth if float(u[4]) < NEAR_HUSHED else 0.0}
		state[who[i]] = [cur, left]
		out.append(cur)
	return out


## The voice's gain in each ear at lean position [param p] (-1 left .. 1 right): the near ear's share
## runs from a half to [constant LEAN_SHARE], and the pair keeps constant power, so a lean moves the
## voice without making it louder or quieter overall.
static func lean_gains(p: float) -> Vector2:
	var r := 0.5 + (LEAN_SHARE - 0.5) * clampf(p, -1.0, 1.0)
	var l := 1.0 - r
	var norm := sqrt((l * l + r * r) * 0.5)
	return Vector2(l / norm, r / norm)


## The dial moved since the rest was drawn: a rest drawn for a sparser setting is cut to the longest the
## new one would draw, so turning Lean up is heard in seconds, and turning it to 0 sends the reader home
## now.
func _resolve_lean() -> void:
	var k := clampf(lean, 0.0, 1.0)
	if is_equal_approx(k, _lean_k):
		return
	# the reading opens at rest, at center: the first rest is drawn here rather than the reader
	# leaning on the first word
	if _lean_k < 0.0 and not _lean_joint:
		_lean_hold = _lean_rng.randf_range(0.4, 1.0) * LEAN_REST_MAX * pow(1.0 - k, 1.5)
	_lean_k = k
	if _lean_joint:
		# an approach's lean is the approach's to end - unless the dial is gone
		if k <= 0.0:
			_lean_joint = false
			_lean_hold = 0.0
		return
	if _lean_dur <= 0.0:
		var longest := LEAN_REST_MAX * pow(1.0 - k, 1.5) if absf(_lean_pos) < 0.01 \
			else LEAN_HOLD_MAX * (1.0 - k) + LEAN_HOLD_FLOOR
		_lean_hold = minf(_lean_hold, 0.0 if k <= 0.0 else longest)


## One sample of the reader's movement: the position, eased (raised cosine, so every move starts and
## ends at rest - a person leaning, not a pan sweep).
func _tick_lean() -> float:
	var dt := 1.0 / sample_rate
	if _lean_dur > 0.0:
		_lean_t += dt
		if _lean_t >= _lean_dur:
			_lean_pos = _lean_to
			_lean_dur = 0.0
		else:
			var u := _lean_t / _lean_dur
			_lean_pos = lerpf(_lean_from, _lean_to, 0.5 - 0.5 * cos(PI * u))
		return _lean_pos
	_lean_hold -= dt
	if _lean_hold <= 0.0:
		_next_lean()
	return _lean_pos


## Where the reader goes next, and how long they stay there.
##   at center: lean to a side, then hold it a while (shorter as the dial rises);
##   at a side: cross straight to the other side (lean^2 of the time) or come home,
##              and rest at center (less, and less often, as the dial rises).
## At 0 the only move left is home.
func _next_lean() -> void:
	var k := clampf(lean, 0.0, 1.0)
	var home := absf(_lean_pos) < 0.01
	var to := 0.0
	var hold := 0.0
	if k <= 0.0:
		if home:
			_lean_pos = 0.0
			_lean_hold = 0.25                   # nothing to do: look again shortly
			return
	elif home or _lean_rng.randf() < k * k:
		# a side: the other one after a crossing, either one from center
		var side := -signf(_lean_pos) if not home else (-1.0 if _lean_rng.randf() < 0.5 else 1.0)
		to = side * _lean_rng.randf_range(lerpf(LEAN_DEPTH_MIN, 0.85, k), 1.0)
		hold = _lean_rng.randf_range(LEAN_HOLD_MIN, LEAN_HOLD_MAX) * (1.0 - k) + LEAN_HOLD_FLOOR
	else:
		hold = _lean_rng.randf_range(0.4, 1.0) * LEAN_REST_MAX * pow(1.0 - k, 1.5)
	var dist := absf(to - _lean_pos)
	_lean_from = _lean_pos
	_lean_to = to
	_lean_t = 0.0
	# a crossing covers twice the ground of a lean, and takes a little longer to
	_lean_dur = _lean_rng.randf_range(LEAN_TRAVEL_MIN, LEAN_TRAVEL_MAX) * (0.75 + 0.25 * dist)
	_lean_hold = hold


## The key's root in Hz, or 0 before there is one.
func _key_hz() -> float:
	return 0.0 if _key_semi <= -1000.0 else 440.0 * pow(2.0, _key_semi / 12.0)


## Move the key, once it is set (KEY_HEARD), only when the reader's register has moved more than
## KEY_HYSTERESIS off it - so it follows a change of speaker, not every inflection - and then to where
## the register is, exactly.
func _follow_key() -> void:
	if _tonic <= 0.0 or _key_semi <= -1000.0:
		return
	var s := _semis(_tonic)
	if absf(s - _key_semi) > KEY_HYSTERESIS:
		_key_semi = s
		_ear()


## The bass for one sample, in the bed's units (so it shares its level, its duck and its
## fade-in). Its cue is detected here too.
func _tick_events(dry: float) -> float:
	var dt := 1.0 / sample_rate
	var out := 0.0
	_clock += 1
	# --- cue: the voice's pitch moving ---
	_bass_cool -= dt
	if _pitch > 0.0:
		_pitch_slow = _pitch if _pitch_slow <= 0.0 else lerpf(_pitch_slow, _pitch, dt / BASS_PITCH_TAU)
		if _bass_cool <= 0.0 and absf(12.0 * log(_pitch / _pitch_slow) / log(2.0)) > BASS_SHIFT:
			_bass_cool = BASS_COOLDOWN
			if _key_semi > -1000.0 and _bass_at < 0 and _ev_rng.randf() < _chance(BASS_ONSET, BASS_CHANCE):
				_plan_bass()
	if _bass_at >= 0 and _clock >= _bass_at:
		_bass_at = -1
		_bass_w = TAU * _bass_hz / sample_rate
		_bass_rise = true
	# --- the bass ---
	if _bass_env > 0.0 or _bass_rise:
		if _bass_rise:
			_bass_env += dt / BASS_ATTACK
			if _bass_env >= 1.0:
				_bass_env = 1.0
				_bass_rise = false
		else:
			_bass_env *= exp(-dt / BASS_DECAY)
			if _bass_env < 1e-4:
				_bass_env = 0.0
		_bass_ph = fmod(_bass_ph + _bass_w, TAU)
		# the fundamental plus two harmonics: a small speaker cannot play the root itself
		var v := sin(_bass_ph) + 0.45 * sin(2.0 * _bass_ph) + 0.18 * sin(3.0 * _bass_ph)
		out += v * _bass_env * _bass_env * BASS_LEVEL
	return out


## How often a cue is taken at the current dial: never below `onset`, rising (x^1.5, so the lower part
## of the range stays sparse) to `top` at 1.0.
func _chance(onset: float, top: float) -> float:
	var x := clampf((pad - onset) / (1.0 - onset), 0.0, 1.0)
	return top * pow(x, 1.5)


## A bass swell on the key's root (sometimes the fifth), waiting for the next bar line - under the
## voice (BASS_UNDER), or none.
func _plan_bass() -> void:
	var hz := _key_hz()
	if _ev_rng.randf() < 0.25:
		hz *= 1.5
	while hz >= BASS_ROOT_LO * 2.0:
		hz *= 0.5
	while hz < BASS_ROOT_LO:
		hz *= 2.0
	# the key's root is two octaves under the voice's middle
	var top := _key_hz() * 4.0 * pow(2.0, -BASS_UNDER / 12.0)
	while hz * 2.0 > top:
		hz *= 0.5
	if hz < BASS_FLOOR:
		return
	_bass_hz = hz
	var bar := _eighth * 8
	_bass_at = (_clock / bar + 1) * bar


## Bring one idle voice in on a scale degree. Notes are chosen, not swept: the pad is a sequence of
## sustained tones, and overlapping envelopes turn a sequence into a chord.
func _start_tone() -> void:
	var slot := -1
	for k in PAD_VOICES:
		if _p_state[k] == 0:
			slot = k
			break
	if slot < 0:
		return
	var degree: int = int(PAD_SCALE[_rng.randi() % PAD_SCALE.size()])
	var octave: int = int(PAD_OCTAVES[_rng.randi() % PAD_OCTAVES.size()])
	var semis := degree + octave
	while semis > PAD_CEILING:
		semis -= 12
	var hz: float = _key_hz() * pow(2.0, float(semis) / 12.0)
	if hz <= 0.0 or hz >= sample_rate * 0.45:
		return
	var w := TAU * hz / sample_rate
	_p_cos[slot] = cos(w)
	_p_sin[slot] = sin(w)
	var w2 := TAU * hz * (1.0 + PAD_DETUNE) / sample_rate
	_p_cos2[slot] = cos(w2)
	_p_sin2[slot] = sin(w2)
	# random start phases: tones that all begin in step sum into a click
	var ph := _rng.randf() * TAU
	_p_re[slot] = cos(ph)
	_p_im[slot] = sin(ph)
	_p_re2[slot] = cos(ph * 1.7)
	_p_im2[slot] = sin(ph * 1.7)
	_p_env[slot] = 0.0
	_p_hold[slot] = _rng.randf_range(PAD_HOLD_MIN, PAD_HOLD_MAX)
	var parts := _partials(hz)
	_p_h2[slot] = parts.x
	_p_h4[slot] = parts.y
	_p_n[slot] = parts.z
	_p_state[slot] = 1


## A tone at [param hz]'s octave partials and the scale that keeps its power a plain tone's (its detuned twin
## at 0.6 among it): `(h2, h4, scale)`. None at PAD_AUDIBLE and over; all of PAD_H2 and PAD_H4 an octave under.
static func _partials(hz: float) -> Vector3:
	var w := clampf(log(PAD_AUDIBLE / maxf(hz, 1.0)) / log(2.0), 0.0, 1.0)
	var h2 := PAD_H2 * w
	var h4 := PAD_H4 * w
	return Vector3(h2, h4, sqrt(1.36 / (1.36 + h2 * h2 + h4 * h4)))


## The tones' lift for the ear in the key now ([constant PAD_EAR_KEY]).
func _ear() -> void:
	var now := _audibility(_key_hz(), true)
	_ear_k = 1.0 if now <= 0.0 else clampf(sqrt(_audibility(PAD_EAR_KEY, false) / now), 1.0 / PAD_EAR_MOST, PAD_EAR_MOST)


## How loud the bed's tones are to the ear in the key [param key] (Hz), for their power: over every tone
## [method _start_tone] can choose (PAD_SCALE by PAD_OCTAVES, under PAD_CEILING), its partials'
## A-weighted power ([method a_power]) over their plain power - with the octave partials of a low tone
## ([param partials], [method _partials]) or plain, as the bed was staged.
static func _audibility(key: float, partials: bool) -> float:
	if key <= 0.0:
		return 0.0
	var heard := 0.0
	var n := 0
	for degree in PAD_SCALE:
		for octave in PAD_OCTAVES:
			var semis: int = int(degree) + int(octave)
			while semis > PAD_CEILING:
				semis -= 12
			var hz := key * pow(2.0, float(semis) / 12.0)
			var p := _partials(hz) if partials else Vector3(0.0, 0.0, 1.0)
			heard += p.z * p.z * (1.36 * a_power(hz) + p.x * p.x * a_power(2.0 * hz) + p.y * p.y * a_power(4.0 * hz)) / 1.36
			n += 1
	return heard / float(n)


## The A-weighting's power gain at [param hz] (IEC 61672): how much of a tone's power the ear is reckoned to
## hear, 1 at 1 kHz.
static func a_power(hz: float) -> float:
	var f2 := hz * hz
	var ra := (12194.0 * 12194.0 * f2 * f2) / ((f2 + 20.6 * 20.6) * sqrt((f2 + 107.7 * 107.7) * (f2 + 737.9 * 737.9))
		* (f2 + 12194.0 * 12194.0))
	return ra * ra * pow(10.0, 0.2)



## Autocorrelation over one tracking window, decimated by 4 (a voice is well under 400 Hz).
func _estimate_pitch(win: PackedFloat32Array) -> float:
	var dec := 4
	var m := win.size() / dec
	if m < 64:
		return 0.0
	var x := PackedFloat32Array()
	x.resize(m)
	var energy := 0.0
	for i in m:
		x[i] = win[i * dec]
		energy += x[i] * x[i]
	if energy < 1e-5:
		return 0.0                     # silence: hold the last chord
	var sr := float(sample_rate) / dec
	var lo := int(sr / PITCH_MAX)
	var hi := mini(int(sr / PITCH_MIN), m - 1)
	var best := 0.0
	var best_lag := 0
	for lag in range(lo, hi):
		var acc := 0.0
		for i in range(m - lag):
			acc += x[i] * x[i + lag]
		if acc > best:
			best = acc
			best_lag = lag
	if best_lag <= 0 or best < energy * 0.3:
		return 0.0                     # unvoiced or noisy: do not retune on noise
	return sr / float(best_lag)
