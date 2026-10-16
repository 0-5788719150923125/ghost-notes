extends RefCounted
class_name Delivery

## Delivery - how one voice's settings become what the voice host is asked for and what its room
## is dialed to: the tone presets, the pause curve and the rests at a seam and a handover, the
## stress a run of italics gets, the leans a delivery mark asks for, eased sentence by sentence,
## and the request for one chunk in one voice. A SLOT is one voice's settings
## ([constant ReadingPanel.SLOT_DEFAULTS]); everything here is a function of a slot and a chunk.
##
## ONE COPY OF EVERY RULE (next/structure.md, step 13). The live window, the audition and the
## export take each read a voice, and the render must be the performance that was auditioned - a
## second copy of a rule is where the two part. These were the reading panel's own; they are
## pure, so a voice that is a card, or a reading whose text arrives as it is written, asks the
## same functions.

# The silence between sentences. The host inserts this BETWEEN sentences inside
# one chunk; with one sentence per chunk it has no pair to sit between, so the
# boundary is made here instead. Without it the reading runs sentences together
# - the "rushed" problem, reintroduced by the chunk size. This is the figure at
# Pause 1.0; the slider scales it, and the host is sent the same pair so the two
# sides of a seam agree (see _seam_gap).
# Ceiling for the Pause slider. 2 was the first guess and it was far too timid: measured
# end to end through the real host, scale 2 stretched a 4.3 s sentence by only 0.81 s -
# spread over three marks, which reads as no change at all. Scale 10 stretches the same
# sentence by 3.46 s, which is unmistakable. The base table stays conservative (it is
# calibrated to what the model already does) and this opens the range instead, so the
# choice is the reader's rather than baked in.
#
# The number is no longer a stretch factor for our own silence: the dial scales the WHOLE
# rest along a saturating curve, so 10 means "3.2 times the natural rest" rather than "ten
# times the silence we splice". See [method rest_for].
const MAX_PAUSE_SCALE := 10.0
const SENTENCE_GAP := 0.32
# What the MODEL rests at a sentence end on its own: the trailing silence of one rendered
# sentence plus the leading silence of the next, which with one sentence per chunk is what
# sits either side of a seam. Measured, 0.138-0.145 + 0.044. Mirrors piper.DWELL - see
# [method rest_for] for why a rest has to know this in order to scale properly.
const SENTENCE_DWELL := 0.18
# The pause curve's exponent, which IS its reach: log(5)/log(10), so the multiplier is
# exactly 1.0 at Pause 1.0 and 5.0 at the top of the slider. Mirrors piper.PAUSE_GAIN -
# see [method pause_multiplier] for why a power law and not a saturating one.
const PAUSE_GAIN := 0.69897


# THE HANDOVER. A change of speaker is a bigger boundary than a sentence end and
# wants a bigger rest: one reader stops, the other starts, and run together they
# read as one person changing their mind mid-paragraph rather than as two people.
# This is the figure at Turn 1, ON TOP of the ordinary sentence seam, and the
# slider scales it.
#
# GLOBAL, not per tab, and that is the point of it being above them: the pause
# belongs to the BOUNDARY between two voices, not to either one of them, so
# asking which tab owns it has no answer.
const TURN_GAP := 0.55
const MAX_TURN_SCALE := 6.0
# ...and a ceiling on the whole rest, the seam included. Past a few seconds a
# handover stops reading as a beat and starts reading as the file having ended.
const TURN_CEILING := 4.0


# TONE PRESETS.
#
# VITS has no affect control - the only handles are pace, how much variation the
# model samples, and pitch. So a "tone" here is those three moved together, plus
# A TONE OWNS THE VOICE AND NOTHING ELSE. It reached into two of the panel's own
# dials once - the ambience bed and Presence - and both were mistakes, in opposite
# directions.
#
# The bed was never the voice's business: it is a drone under the reading, a choice
# about the room, and it neither competes with the voice nor belongs to any manner of
# speaking. It was also pointless at the sizes used - "if we EVER set ambience to 0.1,
# then there is essentially no ambience at all."
#
# Presence WAS the voice's business, because Gruff really is muffled, but a preset has
# no business writing a control the reader has set - and as a hidden offset it was
# worse than that: Presence rests at the TOP of its travel, so subtracting from it
# could not be undone by pushing the slider up. "There is no way to correct that; I
# can ramp presence up to 1.0 and it's still too quiet." What Gruff wanted was not
# distance anyway. It wanted to sound like a voice coming through something, which is
# a property of the SOURCE, and `muffle` is now exactly that - a filter the preset
# owns, in the backend beside the whisper, leaving every dial on the panel alone.
#
# ...and `whisper` and `muffle`, which are neither. Those two are not parameters of
# the model at all but transforms applied to what it returns (piper.py `_whisper`,
# `_muffle`): the two manners a modal-speech checkpoint categorically cannot be asked
# for are the one where the vocal folds are not vibrating and the one where the voice
# is coming through something.
#
# The pitch shift is done by RESAMPLING, and the model compensates: to raise the
# voice by r we ask it to speak r times SLOWER, then play back r times faster.
# The two cancel in duration and leave only the pitch change, which avoids a
# phase vocoder entirely. The host does the playback (`play_ratio` in
# [method request_args]), band-limited - this editor's own was linear, which dulled
# the top end and folded images back into it. It does shift the
# formants with the pitch, so the speaker reads as a different SIZE - which is
# exactly what "spooky" (larger, lower) and "excited" (smaller, higher) want.
## THE DELIVERY A SCRIPT MARKS (`<!-- delivery: quicker, brighter -->`, [constant
## Manuscript.DELIVERY]): each word a step on four axes - PACE, BRIGHTNESS (a touch higher, a
## little livelier, a little more effort), PAUSES (+ is longer: a reader who lets a moment sit, or
## one running on) and VOLUME (effort alone, no pitch: leaning in, or projecting) - and the
## intents a reader has as small combinations of them. `steady` is the voice's own. Steps add,
## at most two each way.
const DELIVERY_WORDS := {
	"quicker": Vector4(1, 0, 0, 0), "faster": Vector4(1, 0, 0, 0), "slower": Vector4(-1, 0, 0, 0),
	"brighter": Vector4(0, 1, 0, 0), "graver": Vector4(0, -1, 0, 0),
	"tighter": Vector4(0, 0, -1, 0), "looser": Vector4(0, 0, 1, 0),
	"louder": Vector4(0, 0, 0, 1), "softer": Vector4(0, 0, 0, -1),
	"excited": Vector4(1, 1, -1, 0), "urgent": Vector4(1, 0, -1, 1), "playful": Vector4(1, 1, 0, 0),
	"serious": Vector4(-1, -1, 1, 0), "hushed": Vector4(-1, -1, 1, -1), "tender": Vector4(-1, 0, 1, -1),
	"dry": Vector4(0, -1, 0, 0), "steady": Vector4.ZERO,
}
## What ONE step is, on each axis - small on purpose: pace 4%, pitch a third of a semitone (on the
## formant-locked path, so the speaker keeps their size), effort and melody a little, pauses a
## fifth. Two steps is as far as a mark goes.
const LEAN_PACE := 0.04
const LEAN_SEMIS := 0.33
const LEAN_EFFORT := 0.08
const LEAN_LIVELY := 0.07
## A pause step is the widest: a reader lets a moment sit, or barely stops on a roll (x1.3 a step).
const LEAN_PAUSE := 1.3
## Volume is effort alone - the spectral tilt and the level, no pitch.
const LEAN_LOUD := 0.12
## A hushed approach is this many "softer" steps of effort - the tilt of a dropped voice; the
## level itself is VoiceFX's ([constant VoiceFX.NEAR_HUSH_DB]).
const NEAR_SOFTER := 2.0
## How much of the way to a new delivery each sentence goes: a change eases in over two or three
## sentences, and back out the same way after its paragraph.
const LEAN_EASE := 0.5

const TONE_PRESETS := {
	"Neutral":  {"pace": 1.00, "semis":  0.0, "noise": 0.667, "noise_w": 0.333, "muffle": 0.0, "whisper": 0.0},
	"Warm":     {"pace": 0.96, "semis": -0.5, "noise": 0.60,  "noise_w": 0.35, "muffle": 0.0, "whisper": 0.0},
	"Serious":  {"pace": 0.92, "semis": -1.5, "noise": 0.50,  "noise_w": 0.25, "muffle": 0.0, "whisper": 0.0},
	"Excited":  {"pace": 1.15, "semis":  2.0, "noise": 0.85,  "noise_w": 0.50, "muffle": 0.0, "whisper": 0.0},
	"Spooky":   {"pace": 0.85, "semis": -3.0, "noise": 0.45,  "noise_w": 0.20, "muffle": 0.0, "whisper": 0.0},
	# The three below fill quadrants the first five leave empty. `pace` and
	# `noise_w` are close to independent - one is how fast the reading runs, the
	# other how EVENLY it is divided - and everything above sits on the diagonal:
	# slow readings are also metronomic (Serious, Spooky), quick ones also loose
	# (Excited). The off-diagonal corners are where the manners that are not just
	# "more" or "less" of the same delivery live.
	#
	# SARCASTIC is the drawl: slow, but unevenly slow. It is not guesswork - the
	# acoustics of sarcasm have been measured (Cheang & Pell, "The sound of
	# sarcasm", Speech Communication 50, 2008), and against neutral productions of
	# the same sentences sarcasm came out lower in mean F0 (their most robust cue,
	# ~5-7% below neutral, so about a semitone), reduced in F0 standard deviation
	# (a flatter contour), reduced in HNR (a rougher voice), and slower - 9% on
	# whole sentences, 28% on short keyphrases. So: a semitone down, a sixth slower,
	# `noise` well under Neutral to flatten the melody, and `noise_w` the highest in
	# the bank, which is what stretches some syllables and clips others. The flat
	# melody over uneven timing is the whole effect; the lowered pitch alone reads
	# as Serious.
	#
	# URGENT is the corner nothing occupied: FAST AND TIGHT. Excited is fast and
	# loose - a voice that has lost its grip on the rhythm - and the opposite of
	# that is a voice keeping a grip on it deliberately. Low `noise_w` is what
	# makes it clipped rather than merely quick, and the pitch barely moves,
	# because the tension is in the timing, not the register.
	#
	# DREAMY is slow and loose, like Sarcastic, and reads nothing like it: it is
	# a semitone and a half UP (the formants go with the pitch, so the reader is
	# smaller and lighter, not larger and darker like Spooky), the model is left
	# free to wander at the top of the `noise` range, and the ambience bed comes up
	# further than any other preset - the pad is doing as much of the work as the
	# voice is.
	"Sarcastic": {"pace": 0.86, "semis": -1.0, "noise": 0.42, "noise_w": 0.60, "muffle": 0.0, "whisper": 0.0},
	"Urgent":    {"pace": 1.22, "semis":  0.5, "noise": 0.40, "noise_w": 0.16, "muffle": 0.0, "whisper": 0.0},
	"Dreamy":    {"pace": 0.88, "semis":  1.5, "noise": 0.78, "noise_w": 0.52, "muffle": 0.0, "whisper": 0.0},
	# ...and these three are the classic vocal-emotion table, as far as it
	# translates. Murray & Arnott ("Toward the simulation of emotion in synthetic
	# speech", Speech Communication 16, 1993) reviewed the human literature FOR
	# synthesis and tabulated five emotions against neutral speech, in rate, pitch
	# average, pitch range, intensity, voice quality and inflection. Three of those
	# five survive the trip into this parameter space; see below for the two that
	# do not.
	#
	# MOURNFUL is their sadness: slightly slower, slightly lower, slightly
	# narrower pitch range, downward inflections. Narrow range is the one that
	# matters here and it is why `noise` is the lowest in the bank - this is the
	# flattest, most affectless reading available, and the flatness is doing the
	# work, not the pitch. It is a semitone down, no more: Serious already owns
	# -1.5, and past that the formants have moved far enough that it reads as a
	# different, larger reader rather than the same one grieving.
	#
	# FIERCE is their anger: quicker, higher, wider, louder, with ABRUPT pitch
	# changes on stressed syllables and a rough chest tone. Only half of that is
	# available. The pitch half is not - raising F0 here resamples, which shrinks
	# the speaker, and an angry voice that has gone SMALL reads as a complaint
	# rather than a threat - so it sits a little BELOW neutral to keep the chest in
	# it, and the two halves that do translate carry the whole thing: `noise` at
	# the top of the bank for the roughness, `noise_w` near the bottom for the
	# abruptness. Fast, rough and clipped, where Excited is fast, bright and loose.
	#
	# ANXIOUS is their fear: much quicker, much higher, and IRREGULAR VOICING -
	# which is the one emotion in the table whose signature cue is jitter, so it is
	# the one this parameter space renders most directly. Highest `noise_w` in the
	# bank. It sits close to Excited by design, because they sit close in real
	# speakers too: high-arousal emotions are the ones listeners confuse with each
	# other, and the difference is that Excited is EVENLY quick and this is not.
	#
	# The two that did not translate: HAPPINESS is Excited already, and DISGUST
	# (very much slower, very much lower, grumbled) is Spooky with worse manners.
	"Mournful":  {"pace": 0.84, "semis": -1.0, "noise": 0.30, "noise_w": 0.45, "muffle": 0.0, "whisper": 0.0},
	"Fierce":    {"pace": 1.10, "semis": -0.5, "noise": 0.90, "noise_w": 0.28, "muffle": 0.0, "whisper": 0.0},
	"Anxious":   {"pace": 1.18, "semis":  1.5, "noise": 0.80, "noise_w": 0.65, "muffle": 0.0, "whisper": 0.0},
	# GRUFF is the growl behind the mask, and it is the first preset that needed
	# `pres`. Low and rough are in reach without it - the deepest `semis` in the
	# bank puts a bigger chest behind the voice, and `noise` near the top makes the
	# source gravelly rather than clean - but MUFFLED and QUIETER are not, and they
	# are half of what this voice is - and they are a property of the SOURCE, not of
	# how far away it is standing. `muffle` is the preset's own filter (piper._muffle),
	# so Gruff sounds like it is speaking through something without spending the
	# reader's Presence dial, which stays theirs for the room.
	#
	# The timing is deliberate rather than drawled - this voice is forcing the
	# words out, not savoring them - so `noise_w` sits low, near Fierce.
	"Gruff":     {"pace": 0.90, "semis": -4.0, "noise": 0.88, "noise_w": 0.30, "muffle": 0.55, "whisper": 0.0},
	# WHISPERED is the one manner in this bank that no inference parameter can
	# reach, and the only one that is not a setting at all. A VITS checkpoint
	# trained on modal speech has no whispered speech in it to sample, so there is
	# nothing to ask for: turning the model's own variation up gives a rough voice,
	# never a breathed one. What makes a whisper is the vocal folds not vibrating -
	# no fundamental, no harmonics, the words carried entirely by the resonances -
	# and that is a filter operation on the rendered audio, not a request to the
	# model. piper.py `_whisper` does it: each frame rebuilt as noise shaped by its
	# own spectral envelope, so the vocal tract survives and the voice in it does
	# not.
	#
	# HUSHED is the same transform at half strength, which is a real manner rather
	# than a fader position - a stage whisper is a voice that has not entirely
	# left, and half is where it sits. It used to stand back a little as well, on
	# the theory that someone lowering their voice does; that came out as "too
	# quiet, and there is no way to correct that", and the distance was never the
	# reason - a half blend of two UNCORRELATED signals loses 3 dB all by itself
	# (piper._whisper, which now normalizes for it). The dial is back at 1.0 and
	# the reader can push it away if they want the distance.
	"Whispered": {"pace": 0.92, "semis":  0.0, "noise": 0.55, "noise_w": 0.35, "muffle": 0.0, "whisper": 1.0},
	"Hushed":    {"pace": 0.94, "semis": -0.5, "noise": 0.55, "noise_w": 0.33, "muffle": 0.0, "whisper": 0.45},
}


## THE LONGEST RUN OF EMPHASIZED WORDS THAT IS STRESS. Italics also mark things that are not
## said harder: a paragraph in italics is a change of time or place ([ScriptMarks] "italic"), a
## thought, a title. A word or a few is a reader leaning on them; a longer run is typography,
## and stressing every word of it would drawl the whole paragraph.
const STRESS_RUN_MAX := 3


## {flat word index: emphasis level} for the words of [param parsed] ([method Phonemes.parse])
## that are spoken with stress - each run of emphasized words no longer than
## [constant STRESS_RUN_MAX], counted across sentence ends, so an italic paragraph of short
## sentences is still one long run.
static func stressed_words(parsed: Array) -> Dictionary:
	var levels: Array = []
	for sentence in parsed:
		for w in sentence:
			levels.append(int((w as Dictionary).get("emph", 0)))
	var out := {}
	var i := 0
	while i < levels.size():
		if int(levels[i]) <= 0:
			i += 1
			continue
		var j := i
		while j < levels.size() and int(levels[j]) > 0:
			j += 1
		if j - i <= STRESS_RUN_MAX:
			for k in range(i, j):
				out[k] = int(levels[k])
		i = j
	return out


## A slot's preset, and the resample ratio it implies.
static func preset_of(s: Dictionary) -> Dictionary:
	var keys := TONE_PRESETS.keys()
	return TONE_PRESETS[keys[clampi(int(s["tone"]), 0, keys.size() - 1)]]


static func pitch_ratio_of(s: Dictionary) -> float:
	return pow(2.0, float(preset_of(s)["semis"]) / 12.0)


## One voice's delivery settings, as the host expects them.
##
## These used to be null-guarded against a missing slider, because export_take and
## _pump are both reachable from outside this editor's own lifecycle. They read a
## SLOT now, and a slot is [constant SLOT_DEFAULTS] merged with whatever was
## stored - so the missing-value case is answered by the schema, once, for every
## setting rather than one guard per dial.
static func delivery_of(s: Dictionary) -> Dictionary:
	return {
		"dynamics": open_up(float(s["dynamics"])),
		"prosody_arc": arc_semis(float(s["arc"])),
		"effort": open_up(float(s["effort"])),
	}


## THE PARAGRAPH PITCH ARC, in semitones peak-to-peak.
##
## Its own curve rather than [method open_up] x a ceiling, because this dial had a
## hard limit the other two do not, and it was not a limit of taste. The arc's pitch
## move is bought by RESAMPLING (piper.py `_discourse_plan` -> `_resample`, the same
## trick the Tone shift uses), and a resample moves the formants with the pitch - so
## it did not change how high the reader was speaking, it changed HOW BIG THEY WERE.
##
## Reported exactly that way: "the voice becomes lower and lower and lower; it
## completely transforms the voice into another voice by the end of the arc - the
## voice doesn't actually maintain its identity", with everything past 0.2 unusable.
## Measured on a sixteen-sentence script, the dial spanned 7.5 semitones at the top
## of its travel, a 54% change in apparent vocal-tract scale between a paragraph's
## opening sentence and its last. The dial was not too strong. It was asking a
## formant-SHIFTING resampler for a thing only a formant-PRESERVING shifter can do.
##
## So the shifter was fixed instead of the dial being capped to hide it: piper.py
## `_restore_formants` puts the speaker's own resonances back after the resample,
## leaving the pitch move and nothing else. What bounds the ceiling now is the
## linguistics rather than the DSP - 't Hart, Collier & Cohen put declination at
## one to two semitones over an utterance, with the deepest boundaries resetting
## further - so 4 semitones peak to peak is a top of travel that is more than any
## speaker would do and still the same speaker doing it.
##
## The exponent is FITTED, not chosen: it holds the old curve's value at 0.15,
## because 0.10 and 0.15 were reported as the settings that already work and a fix
## for the top of a dial has no business moving the bottom of it. It tracks the old
## curve within 5% up to about 0.4 and only then bends away, which is precisely the
## half that was broken.
const ARC_CEILING_SEMIS := 4.0
const ARC_KNEE := 1.13

static func arc_semis(k: float) -> float:
	return ARC_CEILING_SEMIS * pow(clampf(k, 0.0, 1.0), ARC_KNEE)


## The top of a delivery dial, opened up - identity at the bottom, 2.5x at the top.
##
## The first ceilings were set where I thought the results stopped being good, which
## is not my call to make: at full travel Dynamics only slowed the last sentence of a
## paragraph by 18%, so the upper half of the dial was doing almost nothing and the
## reported symptom was exactly that. (Arc was opened up the same way and has since
## been given its own curve - see [method arc_semis] - because its ceiling is set by
## the resampler rather than by taste.)
##
## AND THIS FUNCTION IS ONLY HALF OF A DIAL. It multiplies what the backend is handed;
## the backend then multiplies its own coefficients by that. Those coefficients were
## written as their own ceilings - piper's `_discourse_plan` has documented "18% at
## full depth" since it was written - so opening the dial to 2.5x quietly took the
## paragraph's final lengthening to 45%, the section's to 17%, and a sentence sitting
## at the end of both to two and a half times its own length. Reported as "the
## cadence/pace/speed of the voice becomes slower and slower and slower", attributed
## to Arc, and measured on the reporter's own settings as 15% from Dynamics and 0.0%
## from Arc. piper.DEPTH_TOP now divides it back out, so the figures documented there
## are what the top of THIS dial delivers. A ceiling opened here has to be paid for
## there; the two files are one control.
static func open_up(k: float) -> float:
	return k * (1.0 + 1.5 * k * k)


## The ambience dial: SEVERITY, not level (see [constant VoiceFX.PAD_FADE_IN]). Just the slider now - see [constant TONE_PRESETS] for why
## the preset writes this dial instead of secretly adding to it.
##
## Kept as a named function rather than inlined because the stream open, the export, the
## slider callback and the config load all have to agree about it, and they did not once:
## two of the four added the preset's contribution and two did not, so moving the slider
## during a reading silently dropped it and the export put it back.
static func pad_level_of(s: Dictionary) -> float:
	return clampf(float(s["ambience"]), 0.0, 1.0)


## How close the reader stands. The pad's twin, and the same story.
##
## Floored well above zero: the dial may push the voice back, never mute it, and
## [member VoiceFX.presence] is a gain as well as a filter.
static func presence_of(s: Dictionary) -> float:
	return clampf(float(s["presence"]), 0.25, 1.0)


static func pause_scale_of(s: Dictionary) -> float:
	return clampf(float(s["pause"]), 0.0, MAX_PAUSE_SCALE)


## The silence at a chunk seam. The host inserts the same figure between
## sentences INSIDE a chunk, so a seam and an interior boundary stay the same
## length however the reading happens to have been cut up.
static func seam_gap_of(s: Dictionary) -> float:
	return rest_for(SENTENCE_GAP, SENTENCE_DWELL, pause_scale_of(s))


## The silence to place at a mark whose natural rest is `dwell` and whose top-up at
## Pause 1.0 is `top_up`. MIRRORS piper._rest_for, and has to: the host owns the marks
## inside a sentence and this owns the seam between two of them, so a reading cut one
## way has to rest exactly as long as the same reading cut the other way.
##
## WHY THE DIAL MULTIPLIES THE WHOLE REST rather than our own share of it. What a reader
## hears at a full stop is the model's own trailing silence plus the seam we add, and
## scaling only the second half stretches the DIFFERENCES between the marks instead of
## the marks. Reported as "the pause after a comma and the pause after a sentence are
## very different... at 6.0 the comma-pauses feel about right, while the period-pauses
## feel far too slow" - no one setting could suit both, because their ratio was moving
## with the dial. It no longer moves: a full stop rests twice as long as a comma at 1.0
## and at 10.0 and everywhere between. See piper.DWELL for the measurements.
static func rest_for(top_up: float, dwell: float, scale: float) -> float:
	var mult := pause_multiplier(scale)
	# At 1.0 the answer IS the top-up, said exactly - see piper._rest_for for the float.
	if is_equal_approx(mult, 1.0):
		return maxf(0.0, top_up)
	return maxf(0.0, (dwell + top_up) * mult - dwell)


## How much longer than natural every rest in this reading is. Mirrors piper's, and the
## power law is deliberate: the saturating curve this replaces reached 3.2 at the top of
## the dial and 3.29 at a hundred, so "the pause effect barely seems to work at 10x" could
## not have been answered by allowing a bigger number - the curve had topped out, not the
## dial. This one is exactly 1.0 at Pause 1.0 by construction, within 3% of the old curve
## up to 3.0, and 5.0 at the top, where a full stop rests two and a half seconds.
static func pause_multiplier(scale: float) -> float:
	return pow(clampf(scale, 0.0, MAX_PAUSE_SCALE), PAUSE_GAIN)


## The silence BEFORE chunk `idx` - the ordinary sentence seam, plus the turn
## rest when the chunk before it was somebody else's.
##
## Both the live window and the export join chunks, so this is written once for
## the same reason [method request_args] is: the render has to be the reading
## that was auditioned, and a second copy of a rule is where the two part.
static func gap_before(chunks: Array, idx: int, s: Dictionary, turn := 1.0) -> float:
	var g := seam_gap_of(s)
	if idx <= 0 or idx >= chunks.size():
		return g
	if String((chunks[idx - 1] as Dictionary).get("speaker", "")) \
			== String((chunks[idx] as Dictionary).get("speaker", "")):
		return g
	return minf(g + TURN_GAP * clampf(turn,
		0.0, MAX_TURN_SCALE), TURN_CEILING)


## Everything the host needs to read ONE chunk in ONE voice. Written once and
## used by both the live window and the export, because the render must be the
## performance that was auditioned - a second copy of this list is how the two
## drift apart a parameter at a time.
static func request_args(s: Dictionary, ch: Dictionary, speaker := 0) -> Dictionary:
	var t := preset_of(s)
	var lean: Vector4 = ch.get("lean", Vector4.ZERO)
	var near: Dictionary = ch.get("near", {})
	# length_scale = r / pace: the model speaks r times slower so that
	# playing back r times faster restores the intended pace
	var r := pitch_ratio_of(s)
	var d := delivery_of(s)
	return {
		"length_scale": r / maxf(float(s["pace"]) * float(t["pace"]), 0.1) * (1.0 - LEAN_PACE * lean.x),
		"noise_scale": float(t["noise"]) * (1.0 + LEAN_LIVELY * lean.y), "noise_w": float(t["noise_w"]),
		"lean_semis": LEAN_SEMIS * lean.y,
		# COMING IN HUSHED is a softer voice as well as a quieter one (VoiceFX drops the level)
		"lean_effort": LEAN_EFFORT * lean.y + LEAN_LOUD * (lean.w - NEAR_SOFTER * float(near.get("hush", 0.0))),
		"whisper": float(t["whisper"]), "muffle": float(t["muffle"]),
		"speaker": speaker,
		"sentence_gap": SENTENCE_GAP, "pause_scale": pause_scale_of(s) * pow(LEAN_PAUSE, lean.z),
		"dynamics": d["dynamics"],
		"prosody_arc": d["prosody_arc"],
		"effort": d["effort"],
		"plan_u": float(ch.get("plan_u", 0.0)),
		"plan_v": float(ch.get("plan_v", 0.0)),
		# ...and the host plays it back r times faster, band-limited, so every time it returns
		# is already in the heard audio's seconds (piper.py `_resample`)
		"play_ratio": r,
		"tokens": ch["tokens"],
	}


## A delivery mark's words ([constant DELIVERY_WORDS]) as one lean: their steps added, at most two
## each way. A word not on the list is nothing - a mark the voice cannot act on is ignored.
static func lean_of(words: String) -> Vector4:
	var v := Vector4.ZERO
	for w in words.to_lower().replace(",", " ").split(" ", false):
		v += DELIVERY_WORDS.get(String(w).strip_edges(), Vector4.ZERO)
	return v.clamp(Vector4(-2, -2, -2, -2), Vector4(2, 2, 2, 2))


## Delivery marks [param marks] (`[at, lean]` in [param text]) with the return each implies: a
## delivery lasts to the end of its paragraph (a blank line), where the voice's own comes back.
static func leans_of(text: String, marks: Array) -> Array:
	var out: Array = []
	for i in marks.size():
		var at := int((marks[i] as Array)[0])
		out.append(marks[i])
		var para := text.find("\n\n", at)
		var next := int((marks[i + 1] as Array)[0]) if i + 1 < marks.size() else text.length() + 1
		if para >= 0 and para < next:
			out.append([para, Vector4.ZERO])
	return out


## EASED, NEVER SWITCHED: each sentence goes [constant LEAN_EASE] of the way from the delivery the
## sentence before it had to the one marked for it, per voice - so a mark leans in over two or
## three sentences and its paragraph's end lets go the same way. A hard change of delivery from
## one sentence to the next is what made a marked stretch sound like somebody else.
static func ease_leans(chunks: Array) -> void:
	var cur := {}
	for c in chunks:
		var d: Dictionary = c
		var who := String(d.get("speaker", ""))
		var was: Vector4 = cur.get(who, Vector4.ZERO)
		var now := was + ((d.get("lean_aim", Vector4.ZERO) as Vector4) - was) * LEAN_EASE
		if now.length() < 0.02:
			now = Vector4.ZERO
		cur[who] = now
		d["lean"] = now


## Push ONE VOICE'S settings onto a [VoiceFX] chain. ONE definition, because there
## were four lists of assignments - the slider callback, the config load, the
## stream opening and the export - and a dial had to appear in all four to work
## everywhere. Adding Room to three of them would have left one path silently
## dry, which is the same class of bug [method pad_level_of] was written to end:
## live and render disagreeing about the room around the voice.
##
## It takes a SLOT rather than reading the panel, because the tab on screen is
## not necessarily the voice being heard: while tab 1 narrates, tab 2's dials are
## a room nobody is in yet.
static func apply_fx(fx: VoiceFX, s: Dictionary) -> void:
	if fx == null:
		return
	fx.echo_wet = float(s["echo"])
	fx.resonance = float(s["resonance"])
	fx.presence = presence_of(s)
	fx.pad = pad_level_of(s)
	fx.lean = clampf(float(s["lean"]), 0.0, 1.0)
	# One dial, so [RoomFX] does the collapsing: size and wet open together, and
	# Resonance colors the tail the same way it does on Masking's bus.
	fx.room.from_dial(float(s["room"]), float(s["resonance"]))


## A distance mark at frame [param at], unless it is where the reader already is ([param last],
## the last one written to [param marks], kept up to date here; empty is home).
static func near_mark(marks: Array, near: Dictionary, at: int, last: Dictionary) -> void:
	var want := {"c": float(near.get("c", 0.0)), "hush": float(near.get("hush", 0.0))}
	if want == last or (last.is_empty() and want["c"] == 0.0):
		return
	last.clear()
	last.merge(want)
	marks.append({"at": at, "near": want})


static func near_to(fx: VoiceFX, near: Dictionary) -> void:
	fx.near_to(float(near.get("c", 0.0)), float(near.get("hush", 0.0)))
