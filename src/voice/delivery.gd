extends RefCounted
class_name Delivery

## Delivery - how one voice's settings become what the voice host is asked for and what its room is
## dialed to: the tone presets, the pause curve and the rests at a seam and a handover, the stress a run
## of italics gets, and the request for one chunk in one voice. How a script's delivery marks move the words
## is [DeliveryBank]'s, carried on each token (`x`, `acts`). A slot is one voice's settings ([constant ReadingPanel.SLOT_DEFAULTS]);
## everything here is a function of a slot and a chunk.
##
## One copy of every rule (next/structure.md): the live window, the audition and the export all read a
## voice through these pure functions, so the render is the performance that was auditioned.

# Ceiling for the Pause slider (the dial scales the whole rest along a power curve, see [method
# rest_for]), and then SENTENCE_GAP, the silence between sentences at Pause 1.0: the host inserts it
# between sentences inside a chunk, and with one sentence per chunk the boundary is made here. The host
# is sent the same pair so the two sides of a seam agree (see _seam_gap).
const MAX_PAUSE_SCALE := 10.0
const SENTENCE_GAP := 0.32
# What the model rests at a sentence end on its own: the trailing silence of one rendered sentence plus
# the leading silence of the next (measured 0.138-0.145 + 0.044). Mirrors piper.DWELL - see [method
# rest_for].
const SENTENCE_DWELL := 0.18
# The pause curve's exponent, which is its reach: log(5)/log(10), so the multiplier is 1.0 at Pause 1.0
# and 5.0 at the top of the slider. Mirrors piper.PAUSE_GAIN - see [method pause_multiplier].
const PAUSE_GAIN := 0.69897


# The handover. A change of speaker wants a bigger rest than a sentence end, or the two readers run
# together as one person changing their mind. This is the figure at Turn 1, on top of the ordinary
# sentence seam, and the slider scales it. Global, not per tab: the pause belongs to the boundary
# between two voices, not to either one.
const TURN_GAP := 0.55
const MAX_TURN_SCALE := 6.0
# ...and a ceiling on the whole rest, the seam included: past a few seconds a handover reads as the
# file having ended.
const TURN_CEILING := 4.0


## A hushed approach ([method VoiceFX.near_plan]) is a softer voice as well as a quieter one: this much less effort at full
## hush - the tilt of a dropped voice; the level itself is VoiceFX's ([constant VoiceFX.NEAR_HUSH_DB]).
const NEAR_EFFORT := 0.24

## Tone presets. VITS has no affect control: the handles are pace, sampled variation (`noise`, `noise_w`)
## and pitch (`semis`, by resampling: the model is asked to speak r times slower and the host plays it back
## r times faster, which moves the formants too, so the speaker reads as a different size). `whisper` and
## `muffle` are not model parameters but transforms of what it returns (piper.py `_whisper`, `_muffle`). A
## tone owns the voice and nothing else: it never writes the ambience or Presence dials.
const TONE_PRESETS := {
	"Neutral":  {"pace": 1.00, "semis":  0.0, "noise": 0.667, "noise_w": 0.333, "muffle": 0.0, "whisper": 0.0},
	"Warm":     {"pace": 0.96, "semis": -0.5, "noise": 0.60,  "noise_w": 0.35, "muffle": 0.0, "whisper": 0.0},
	"Serious":  {"pace": 0.92, "semis": -1.5, "noise": 0.50,  "noise_w": 0.25, "muffle": 0.0, "whisper": 0.0},
	"Excited":  {"pace": 1.15, "semis":  2.0, "noise": 0.85,  "noise_w": 0.50, "muffle": 0.0, "whisper": 0.0},
	"Spooky":   {"pace": 0.85, "semis": -3.0, "noise": 0.45,  "noise_w": 0.20, "muffle": 0.0, "whisper": 0.0},
	# Sarcastic, Urgent and Dreamy fill the quadrants the first five leave empty: `pace` and `noise_w`
	# are close to independent (how fast the reading runs vs how evenly it is divided), and the first
	# five sit on the diagonal.
	#
	# Sarcastic: slow but uneven. Cheang & Pell, "The sound of sarcasm" (Speech Communication 50, 2008):
	# against neutral, sarcasm has lower mean F0 (~5-7%, about a semitone), smaller F0 deviation, lower
	# HNR and slower rate (9% on whole sentences). So a semitone down, a sixth slower, `noise` well under
	# Neutral to flatten the melody, and the highest `noise_w` in the bank (some syllables stretched,
	# others clipped).
	#
	# Urgent: fast and tight. Low `noise_w` makes it clipped rather than merely quick; the pitch barely
	# moves because the tension is in the timing.
	#
	# Dreamy: slow and loose, a semitone and a half up (the formants go with the pitch, so the reader is
	# smaller and lighter), `noise` at the top of its range, and the ambience bed higher than any other
	# preset.
	"Sarcastic": {"pace": 0.86, "semis": -1.0, "noise": 0.42, "noise_w": 0.60, "muffle": 0.0, "whisper": 0.0},
	"Urgent":    {"pace": 1.22, "semis":  0.5, "noise": 0.40, "noise_w": 0.16, "muffle": 0.0, "whisper": 0.0},
	"Dreamy":    {"pace": 0.88, "semis":  1.5, "noise": 0.78, "noise_w": 0.52, "muffle": 0.0, "whisper": 0.0},
	# Mournful, Fierce and Anxious come from Murray & Arnott, "Toward the simulation of emotion in
	# synthetic speech" (Speech Communication 16, 1993), as far as it translates to this parameter space.
	#
	# Mournful (sadness): slightly slower and lower, narrow pitch range, so `noise` is the lowest in the
	# bank. A semitone down at most: Serious owns -1.5, and past that the formants move far enough to
	# read as a larger reader.
	#
	# Fierce (anger): raising F0 here resamples, which shrinks the speaker (a small angry voice reads as
	# a complaint), so it sits a little below neutral; `noise` at the top for the roughness, `noise_w`
	# near the bottom for abruptness.
	#
	# Anxious (fear): much quicker, much higher, irregular voicing - the highest `noise_w` in the bank.
	# Close to Excited by design, but Excited is evenly quick and this is not.
	#
	# Happiness is Excited already, and disgust is Spooky.
	"Mournful":  {"pace": 0.84, "semis": -1.0, "noise": 0.30, "noise_w": 0.45, "muffle": 0.0, "whisper": 0.0},
	"Fierce":    {"pace": 1.10, "semis": -0.5, "noise": 0.90, "noise_w": 0.28, "muffle": 0.0, "whisper": 0.0},
	"Anxious":   {"pace": 1.18, "semis":  1.5, "noise": 0.80, "noise_w": 0.65, "muffle": 0.0, "whisper": 0.0},
	# Gruff: the deepest `semis` in the bank, `noise` near the top for a gravelly source, and `muffle`,
	# the preset's own filter (piper._muffle), so it sounds like speaking through something without
	# using the reader's Presence dial. `noise_w` low, near Fierce: the words are forced out.
	"Gruff":     {"pace": 0.90, "semis": -4.0, "noise": 0.88, "noise_w": 0.30, "muffle": 0.55, "whisper": 0.0},
	# Whispered is not a setting: a VITS checkpoint trained on modal speech has no whispered speech to
	# sample, and the model's own variation gives a rough voice, never a breathed one. A whisper is the
	# vocal folds not vibrating, so piper.py `_whisper` rebuilds each frame as noise shaped by its own
	# spectral envelope.
	#
	# Hushed is the same transform at half strength (a stage whisper is a voice that has not entirely
	# left). A half blend of two uncorrelated signals loses 3 dB by itself, which piper._whisper
	# normalizes for.
	"Whispered": {"pace": 0.92, "semis":  0.0, "noise": 0.55, "noise_w": 0.35, "muffle": 0.0, "whisper": 1.0},
	"Hushed":    {"pace": 0.94, "semis": -0.5, "noise": 0.55, "noise_w": 0.33, "muffle": 0.0, "whisper": 0.45},
}


## Kokoro's readers by speaker number, as its host numbers them (hosts/voice/backends/kokoro.py, PACKS: it only
## grows): what a voice's reader is called before the host has listed them.
const KOKORO_READERS := ["af_heart", "af_bella", "af_nicole", "af_aoede", "af_kore", "af_sarah", "af_alloy", "af_nova",
	"af_sky", "af_jessica", "af_river", "am_fenrir", "am_michael", "am_puck", "am_echo", "am_eric", "am_liam", "am_onyx",
	"am_santa", "am_adam", "bf_emma", "bf_isabella", "bf_alice", "bf_lily", "bm_fable", "bm_george", "bm_lewis", "bm_daniel"]


## The pitch shift of tone [param tone] (a [constant TONE_PRESETS] index), in semitones.
static func tone_semis(tone: int) -> float:
	var keys := TONE_PRESETS.keys()
	return float((TONE_PRESETS[keys[clampi(tone, 0, keys.size() - 1)]] as Dictionary)["semis"])


## How voice [param cfg] (a cast row or a kept voice) is asked to sing (the voice host's `sing`): its reader, its blend or
## a formant voice's own (`formant`), and its Tone's pitch shift as a change of SIZE (`semis`: the formants move, the notes
## stay where they are written).
static func sung_params(cfg: Dictionary) -> Dictionary:
	var out := {"speaker": int(cfg.get("speaker", 0))}
	if not String(cfg.get("blend", "")).is_empty():
		out["blend"] = String(cfg["blend"])
	if String(cfg.get("voice", "")) == FormantVoice.ID and cfg.get("formant") is Dictionary:
		out["formant"] = (cfg["formant"] as Dictionary).duplicate(true)
	var semis := tone_semis(int(cfg.get("tone", 0)))
	if absf(semis) > 0.001:
		out["semis"] = semis
	return out


## How voice [param cfg] sings a held note: its vibrato (semitones deep, sways a second) and its drift.
static func sung_style(cfg: Dictionary) -> Dictionary:
	return {"vibrato": float(cfg.get("vibrato", 0.15)), "vibrato_rate": float(cfg.get("vibrato_rate", 5.4)),
		"drift": float(cfg.get("drift", 0.03))}


## Whether voice [param cfg] is a man's: most of its blend's readers, or its one reader, named so (am_, bm_), by
## [param names] (the host's list of readers by number; [constant KOKORO_READERS] where it is empty).
static func sings_low(cfg: Dictionary, names: Array = []) -> bool:
	var readers: Array = Array(VoiceBlend.readers(String(cfg.get("blend", ""))))
	if readers.is_empty():
		var list: Array = names if not names.is_empty() else KOKORO_READERS
		var i := int(cfg.get("speaker", 0))
		readers = [String(list[i]) if i >= 0 and i < list.size() else ""]
	var men := 0
	for r in readers:
		men += 1 if String(r).length() >= 2 and String(r)[1] == "m" else 0
	return men * 2 > readers.size()


## The longest run of emphasized words that is stress. Italics also mark things that are not said
## harder (a paragraph in italics is a change of time or place, [ScriptMarks] "italic"; a thought; a
## title): a word or a few is a reader leaning on them, a longer run is typography.
const STRESS_RUN_MAX := 3


## {flat word index: emphasis level} for the words of [param parsed] ([method Phonemes.parse]) that are
## spoken with stress: each run of emphasized words no longer than [constant STRESS_RUN_MAX], counted
## across sentence ends.
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


## One voice's delivery settings, as the host expects them. A slot is [constant SLOT_DEFAULTS] merged
## with whatever was stored, so a missing value is answered by the schema once.
static func delivery_of(s: Dictionary) -> Dictionary:
	return {
		"dynamics": open_up(float(s["dynamics"])),
		"prosody_arc": arc_semis(float(s["arc"])),
		"effort": open_up(float(s["effort"])),
	}


## The paragraph pitch arc, in semitones peak-to-peak.
##
## Its own curve rather than [method open_up] x a ceiling: the arc's pitch move is bought by resampling
## (piper.py `_discourse_plan` -> `_resample`, as the Tone shift), which moves the formants with the
## pitch, and piper.py `_restore_formants` puts the speaker's own resonances back after it. What bounds
## the ceiling is the linguistics: 't Hart, Collier & Cohen put declination at one to two semitones over
## an utterance, so 4 semitones peak to peak is more than any speaker would do and still the same
## speaker.
##
## The exponent is fitted to hold the earlier curve's value at 0.15 and track it within 5% up to about
## 0.4, so the bottom of the dial stays where it was.
const ARC_CEILING_SEMIS := 4.0
const ARC_KNEE := 1.13

static func arc_semis(k: float) -> float:
	return ARC_CEILING_SEMIS * pow(clampf(k, 0.0, 1.0), ARC_KNEE)


## The top of a delivery dial, opened up: identity at the bottom, 2.5x at the top. (The arc has its own
## curve, [method arc_semis].)
##
## This function is half of a dial: it multiplies what the backend is handed, and the backend multiplies
## its own coefficients by that. Those coefficients were written as ceilings (piper's `_discourse_plan`
## documents "18% at full depth"), so piper.DEPTH_TOP divides the 2.5x back out and the figures
## documented there are what the top of this dial delivers. A ceiling opened here has to be paid for
## there; the two files are one control.
static func open_up(k: float) -> float:
	return k * (1.0 + 1.5 * k * k)


## The ambience dial: severity, not level (see [constant VoiceFX.PAD_FADE_IN]). Just the slider: a tone
## preset does not add to it.
##
## A named function because the stream open, the export, the slider callback and the config load must
## all agree about it.
static func pad_level_of(s: Dictionary) -> float:
	return clampf(float(s["ambience"]), 0.0, 1.0)


## How close the reader stands. The pad's twin. Floored well above zero: the dial may push the voice
## back, never mute it, and [member VoiceFX.presence] is a gain as well as a filter.
static func presence_of(s: Dictionary) -> float:
	return clampf(float(s["presence"]), 0.25, 1.0)


## THE THREE PAUSES of a voice row: at a comma, a semicolon or a colon (`pause`), at a sentence's end (`pause_sentence`) and at a
## paragraph's end (`pause_paragraph`), each scaling its whole rest along the same curve ([method rest_for]).
static func pause_scale_of(s: Dictionary) -> float:
	return clampf(float(s["pause"]), 0.0, MAX_PAUSE_SCALE)


static func sentence_scale_of(s: Dictionary) -> float:
	return clampf(float(s.get("pause_sentence", s["pause"])), 0.0, MAX_PAUSE_SCALE)


static func paragraph_scale_of(s: Dictionary) -> float:
	return clampf(float(s.get("pause_paragraph", s["pause"])), 0.0, MAX_PAUSE_SCALE)


## The silence at a chunk seam, at the Pause at sentence ends. The host inserts the same figure between sentences inside a
## chunk, so a seam and an interior boundary stay the same length however the reading is cut up.
static func seam_gap_of(s: Dictionary) -> float:
	return rest_for(SENTENCE_GAP, SENTENCE_DWELL, sentence_scale_of(s))


## The silence at a seam where a paragraph ends: the sentence end's rest at the Pause at paragraph ends.
static func paragraph_gap_of(s: Dictionary) -> float:
	return rest_for(SENTENCE_GAP, SENTENCE_DWELL, paragraph_scale_of(s))


## The silence to place at a mark whose natural rest is `dwell` and whose top-up at Pause 1.0 is
## `top_up`. Mirrors piper._rest_for: the host owns the marks inside a sentence and this owns the seam
## between two of them, so a reading cut one way rests as long as the same reading cut another.
##
## The dial multiplies the whole rest, not just our share: what a reader hears at a full stop is the
## model's trailing silence plus the seam we add, and scaling only the second half would change the
## ratio between marks with the dial. A full stop rests twice as long as a comma at every setting. See
## piper.DWELL for the measurements.
static func rest_for(top_up: float, dwell: float, scale: float) -> float:
	var mult := pause_multiplier(scale)
	# at 1.0 the answer is the top-up, said exactly - see piper._rest_for for the float
	if is_equal_approx(mult, 1.0):
		return maxf(0.0, top_up)
	return maxf(0.0, (dwell + top_up) * mult - dwell)


## How much longer than natural every rest in this reading is. Mirrors piper's. A power law, not a
## saturating curve (which tops out near 3.2 however far the dial goes): exactly 1.0 at Pause 1.0, and
## 5.0 at the top, where a full stop rests two and a half seconds.
static func pause_multiplier(scale: float) -> float:
	return pow(clampf(scale, 0.0, MAX_PAUSE_SCALE), PAUSE_GAIN)


## The silence before chunk `idx`: the sentence seam - or the paragraph's, where the chunk begins a paragraph (`para_start`,
## [method ReadingPlan.place]) - plus the turn rest when the chunk before it was somebody else's. Written once for the live window
## and the export, as [method request_args].
static func gap_before(chunks: Array, idx: int, s: Dictionary, turn := 1.0) -> float:
	var starts := idx > 0 and idx < chunks.size() and bool((chunks[idx] as Dictionary).get("para_start", false))
	var g := paragraph_gap_of(s) if starts else seam_gap_of(s)
	if idx <= 0 or idx >= chunks.size():
		return g
	# ...as long as the delivery of the word before it says ([method DeliveryBank.rest_of]: its `pauses` and its sentence or
	# paragraph rests, or their seconds): the whole rest heard, the model's own share in it, as the dials scale it
	var last := {}
	for t in (chunks[idx - 1] as Dictionary).get("tokens", []):
		if t is Dictionary and not String((t as Dictionary).get("text", "")).strip_edges().is_empty():
			last = t
	if not last.is_empty():
		var heard := DeliveryBank.rest_of(last, "paragraphs" if starts else "ends", g + SENTENCE_DWELL)
		if not is_equal_approx(heard, g + SENTENCE_DWELL):
			g = maxf(0.0, heard - SENTENCE_DWELL)
	if String((chunks[idx - 1] as Dictionary).get("speaker", "")) \
			== String((chunks[idx] as Dictionary).get("speaker", "")):
		return g
	return minf(g + TURN_GAP * clampf(turn,
		0.0, MAX_TURN_SCALE), TURN_CEILING)


## What the delivery keeps from the voice host ([constant APP_RESTS]): the rests made here, after a sentence or a paragraph and at a
## hesitation, which the host never reads - so a change to one asks no take again.
const APP_RESTS := ["ends", "paragraphs", "hesitations", "ends_s", "paragraphs_s", "hesitations_s"]


## [param tokens] as the host is sent them: a token whose delivery says a rest made here sent with a copy of its `x` without it,
## every other one as it is.
static func host_tokens(tokens: Array) -> Array:
	var out: Array = tokens
	for i in tokens.size():
		var t: Variant = tokens[i]
		if not (t is Dictionary) or not ((t as Dictionary).get("x") is Dictionary):
			continue
		var x: Dictionary = t["x"]
		if not APP_RESTS.any(func(k: String) -> bool: return x.has(k)):
			continue
		if out == tokens:
			out = tokens.duplicate()
		var kept := x.duplicate()
		for k in APP_RESTS:
			kept.erase(k)
		var copy: Dictionary = (t as Dictionary).duplicate()
		if kept.is_empty():
			copy.erase("x")
		else:
			copy["x"] = kept
		out[i] = copy
	return out


## Everything the host needs to read one chunk in one voice. Written once for the live window and the
## export, so the render is the performance that was auditioned.
## A [param blend] of the voice's readers ([VoiceBlend]) is asked only when there is one, so a take kept
## under a voice that has none keeps its key; where the chunk stands in its paragraph (`plan_span`) only when the blend
## moves within one, and which paragraph it is (`plan_p`) only when its noise wanders.
static func request_args(s: Dictionary, ch: Dictionary, speaker := 0, blend := "") -> Dictionary:
	var t := preset_of(s)
	var near: Dictionary = ch.get("near", {})
	# length_scale = r / pace: the model speaks r times slower so that playing back r times faster
	# restores the intended pace
	var r := pitch_ratio_of(s)
	var d := delivery_of(s)
	# the paragraph's arc swings as far as the sentence's words are told to ([DeliveryBank] `range`): a deadpan sentence
	# keeps to its register
	var swing := 0.0
	var said := 0
	for tok in ch.get("tokens", []):
		if tok is Dictionary and not String((tok as Dictionary).get("text", "")).strip_edges().is_empty():
			swing += float(((tok as Dictionary).get("x", {}) as Dictionary).get("range", 1.0))
			said += 1
	if said > 0:
		d["prosody_arc"] = float(d["prosody_arc"]) * (swing / float(said))
	var args := {
		"length_scale": r / maxf(float(s["pace"]) * float(t["pace"]), 0.1),
		"noise_scale": float(t["noise"]), "noise_w": float(t["noise_w"]),
		# coming in hushed is a softer voice as well as a quieter one (VoiceFX drops the level)
		"lean_effort": -NEAR_EFFORT * float(near.get("hush", 0.0)),
		"whisper": float(t["whisper"]), "muffle": float(t["muffle"]),
		"speaker": speaker,
		"sentence_gap": SENTENCE_GAP, "pause_scale": pause_scale_of(s),
		"dynamics": d["dynamics"],
		"prosody_arc": d["prosody_arc"],
		"effort": d["effort"],
		"plan_u": float(ch.get("plan_u", 0.0)),
		"plan_v": float(ch.get("plan_v", 0.0)),
		# ...and the host plays it back r times faster, band-limited, so every time it returns is
		# already in the heard audio's seconds (piper.py `_resample`)
		"play_ratio": r,
		"tokens": host_tokens(ch["tokens"]),
	}
	# the Pause at sentence ends, for the sentence ends inside the chunk: asked only where it is not the Pause at commas, so a
	# take said before the two were apart keeps its key
	if not is_equal_approx(sentence_scale_of(s), pause_scale_of(s)):
		args["sentence_scale"] = sentence_scale_of(s)
	if not blend.is_empty():
		args["blend"] = blend
		if VoiceBlend.moves(blend):
			var u := float(ch.get("plan_u", 0.5))
			args["plan_span"] = ch.get("plan_span", [u, u])
		if VoiceBlend.wanders(blend):
			args["plan_p"] = int(ch.get("plan_p", 0))
	return args


## Push one voice's settings onto a [VoiceFX] chain. One definition, so a dial need appear in only one
## place to work in the slider callback, the config load, the stream opening and the export. It takes a
## slot rather than reading the panel: the tab on screen is not necessarily the voice being heard.
static func apply_fx(fx: VoiceFX, s: Dictionary) -> void:
	if fx == null:
		return
	fx.echo_wet = float(s["echo"])
	fx.resonance = float(s["resonance"])
	fx.presence = presence_of(s)
	fx.pad = pad_level_of(s)
	fx.lean = clampf(float(s["lean"]), 0.0, 1.0)
	fx.seat = pan_of_seat(float(s.get("seat", 0.0)))
	# one dial, so [RoomFX] collapses it: size and wet open together, and Resonance colors the tail as
	# on Masking's bus
	fx.room.from_dial(float(s["room"]), float(s["resonance"]))


## Which ear a voice is heard in, from where it sits (degrees round a table: 0 the far side, 90 its right, -90 its left, 180 at the viewer's elbow): -1 left to 1 right.
static func pan_of_seat(degrees: float) -> float:
	return sin(deg_to_rad(degrees))


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
