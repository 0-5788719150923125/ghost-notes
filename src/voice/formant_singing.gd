extends RefCounted
class_name FormantSinging

## FormantSinging - a phrase sung by the formant voice ([FormantVoice], next/music.md "Who sings"): the voice host's `sing`
## request made with the Klatt synthesizer ([Voice]) instead of a neural model. [VoiceHost] runs it on a worker and answers
## as the host answers a sung phrase, so a composed Sound, its stream and the Lab's Sing take it unchanged.
##
## A phrase is words, each with its notes `{t, len, midi}` in seconds from the phrase's start. Each word's phones are split
## into syllables at their vowels (the consonants between two go to the second as far as English lets a syllable begin),
## its syllables matched to its notes - one each; two quickly on one note where a word has more; one held across several
## where it has fewer - and laid as hosts/voice/singing.py lays Kokoro's: THE VOWEL IS ON THE BEAT, a syllable's onset sung
## before its note, its coda at the note's end, each consonant at the length the synthesizer speaks it, the vowel taking the
## rest. The pitch is one curve over the take ([constant Voice.BEND_STEP]): each note's own, with a glide into a change that
## overshoots a little and settles, vibrato coming in on a held note, a slow drift ([method ornament], singing.py's
## `ornament`), all taken out toward `tune` 1. A singer's Tone is a change of SIZE: the formants move, the notes stay.

## Two- and three-consonant runs a syllable may begin with (maximal onset), as singing.py's ONSETS; any one consonant but NG.
const ONSETS := ["P L", "P R", "B L", "B R", "T R", "D R", "K L", "K R", "G L", "G R", "F L", "F R", "TH R", "SH R", "S P",
	"S T", "S K", "S M", "S N", "S L", "S W", "T W", "D W", "K W", "G W", "P Y", "B Y", "F Y", "V Y", "M Y", "N Y", "HH Y",
	"K Y", "TH W", "S F", "S P R", "S T R", "S K R", "S P L", "S K W", "S K L", "S T Y", "S P Y", "S K Y"]
## Silence before and after the phrase in the take (s).
const LEAD := 0.12
const TAIL := 0.12
## The least a sung vowel holds, and a consonant squeezed to make room for one (s).
const VOWEL_LEAST := 0.04
const CONSONANT_LEAST := 0.015
## The breath before a word that follows another closely (s).
const WORD_GAP := 0.012
## How damped a glide into a new note is (singing.py DAMPING) and how quick (Hz).
const DAMPING := 0.65
const GLIDE_HZ := 6.0
## When a held note's vibrato starts, and how long it takes to come in (s).
const VIBRATO_DELAY := 0.28
const VIBRATO_RAMP := 0.2


## Sing [param words] in [param params]' voice (`formant`: [method FormantVoice.voice_of]'s shape; `semis`: the Tone's change
## of size) as [param style] says (`tune`, `vibrato`, `vibrato_rate`, `drift`, `seed`), written to [param out] (absolute) at
## [constant FormantVoice.RATE]. Answers as the host's `sing`: `{ok, wav, sample_rate, start, duration, sung}`, `start` where
## the take's first sample falls in the phrase's seconds. Pure but for the file; a worker's.
static func sing(words: Array, params: Dictionary, style: Dictionary, out: String) -> Dictionary:
	var v := FormantVoice.voice_of(params.get("formant", {}))
	var spec := FormantVoice.spec_of(v)
	var gain := FormantVoice.gain_of(FormantVoice.spec_of(v))
	spec.formant_scale *= pow(2.0, float(params.get("semis", 0.0)) / 12.0)
	spec.song = 1.0
	var laid := plan(words, spec, style)
	if laid.has("error"):
		return {"ok": false, "error": String(laid["error"])}
	var made := Voice.synth(laid["segs"], spec)
	var pcm: PackedFloat32Array = made.pcm
	for i in pcm.size():
		pcm[i] *= gain
	var rc: Dictionary = v.get("reception", {})
	pcm = VoiceStream.bake_location(pcm, float(rc.get("prox", 0.0)), float(rc.get("freq", 400.0)))
	var half := FormantVoice.halved(pcm)
	var frames := PackedVector2Array()
	frames.resize(half.size())
	for i in half.size():
		frames[i] = Vector2(half[i], half[i])
	var wav := Splice.write_wav(out, frames, 1, FormantVoice.RATE)
	if wav.is_empty():
		return {"ok": false, "error": "could not write " + out}
	return {"ok": true, "wav": wav, "sample_rate": FormantVoice.RATE, "start": float(laid["start"]),
		"duration": float(half.size()) / FormantVoice.RATE, "sung": laid["sung"]}


## [param words] laid for the synthesizer in [param spec]: `{segs, start, sung, curve}` - its segments, every one carrying the
## phrase's pitch curve `bend`; where the take's first sample falls in the phrase's seconds; each syllable's vowel onset
## `{word, t}`; the curve itself (midi, a value each [constant Voice.BEND_STEP] of the take). `{error}` when it cannot be sung.
## Pure.
static func plan(words: Array, spec: Voice.Spec, style: Dictionary) -> Dictionary:
	var syl: Array = []
	for w in words.size():
		var word: Dictionary = words[w]
		var phones := phones_of(word)
		if phones.is_empty():
			return {"error": "a word of the phrase has no sound: %s" % String(word.get("text", ""))}
		var sy := syllables(phones)
		var nts := matched(sy.size(), word.get("notes", []) as Array)
		for q in sy.size():
			var s: Dictionary = sy[q]
			syl.append({"word": w, "first": q == 0, "last": q == sy.size() - 1, "on": s["on"], "nu": s["nu"],
				"co": s["co"], "notes": nts[q], "text": String(word.get("text", ""))})
	if syl.is_empty():
		return {"error": "a sung phrase needs words, each with its notes"}
	# a syllable its word had no note for is sung just after the one before
	for j in syl.size():
		if (syl[j]["notes"] as Array).is_empty():
			var prev: Dictionary = (syl[j - 1]["notes"] as Array).back() if j > 0 else {"t": 0.0, "len": 0.2, "midi": 60.0}
			syl[j]["notes"] = [{"t": float(prev["t"]) + float(prev["len"]), "len": 0.12, "midi": float(prev["midi"])}]
	for s in syl:
		var nts: Array = s["notes"]
		s["t0"] = float(nts[0]["t"])
		s["t1"] = float(nts.back()["t"]) + float(nts.back()["len"])
		s["on_len"] = _spoken(s["on"], spec)
	for j in syl.size():
		var s: Dictionary = syl[j]
		var end := float(s["t1"])
		if j + 1 < syl.size():
			var nxt: Dictionary = syl[j + 1]
			end = minf(end, float(nxt["t0"]) - float(nxt["on_len"]) - (WORD_GAP if bool(nxt["first"]) else 0.0))
		s["end"] = end
		s["co_len"] = minf(_spoken(s["co"], spec), maxf(end - float(s["t0"]) - VOWEL_LEAST,
			CONSONANT_LEAST * float((s["co"] as Array).size())))
	var segs: Array = [_sil(LEAD)]
	var origin := float(syl[0]["t0"]) - float(syl[0]["on_len"])
	var t := origin
	var voices: Array = []          # [t, midi]: the pitch from t on, in the phrase's seconds
	var sung: Array = []
	for j in syl.size():
		var s: Dictionary = syl[j]
		var on_start := float(s["t0"]) - float(s["on_len"])
		if on_start > t + 0.001:
			var last: Dictionary = segs.back()
			if not bool(s["first"]) and String(last["p"]) != "SIL":
				last["dur"] = float(last["dur"]) + on_start - t   # a rest inside a word: what was sung holds on
			else:
				segs.append(_sil(on_start - t))
			t = on_start
		voices.append([t, float((s["notes"] as Array)[0]["midi"])])
		var on: Array = s["on"]
		if not on.is_empty():
			var scale := maxf(float(s["t0"]) - t, CONSONANT_LEAST * float(on.size())) / maxf(float(s["on_len"]), 1e-6)
			for k in on.size():
				var d := _dur(String(on[k]), spec) * scale
				segs.append(_seg(String(on[k]), d, s, bool(s["first"]) and k == 0, false))
				t += d
		sung.append({"word": int(s["word"]), "t": t})
		var nu: Array = s["nu"]
		var co: Array = s["co"]
		var v_end := maxf(float(s["end"]) - float(s["co_len"]), t + VOWEL_LEAST)
		var v0 := t
		for k in nu.size():
			var d := (v_end - v0) / float(nu.size())
			segs.append(_seg(String(nu[k]), d, s, bool(s["first"]) and on.is_empty() and k == 0,
				bool(s["last"]) and co.is_empty() and k == nu.size() - 1))
			t += d
		for nt in (s["notes"] as Array).slice(1):
			voices.append([float(nt["t"]), float(nt["midi"])])
		if not co.is_empty():
			var scale := float(s["co_len"]) / maxf(_spoken(co, spec), 1e-6)
			for k in co.size():
				var d := _dur(String(co[k]), spec) * scale
				segs.append(_seg(String(co[k]), d, s, false, bool(s["last"]) and k == co.size() - 1))
				t += d
	segs.append(_sil(TAIL))
	# the pitch, one curve over the take: a step a note, ornamented, in semitones over the voice's base
	var total := 0.0
	for sg in segs:
		total += float(sg["dur"])
	var n := int(ceil(total / Voice.BEND_STEP)) + 2
	var midi := PackedFloat32Array()
	var held := PackedFloat32Array()
	midi.resize(n)
	held.resize(n)
	var k := 0
	for i in n:
		var tp := float(i) * Voice.BEND_STEP - LEAD + origin
		while k + 1 < voices.size() and float(voices[k + 1][0]) <= tp:
			k += 1
		midi[i] = float(voices[k][1])
		held[i] = maxf(tp - float(voices[k][0]), 0.0)
	var curve := ornament(midi, Voice.BEND_STEP, held, style, int(style.get("seed", 0)))
	var base := 69.0 + 12.0 * log(spec.f0_base * 1.06 / 440.0) / log(2.0)
	var bend := PackedFloat32Array()
	bend.resize(n)
	for i in n:
		bend[i] = curve[i] - base
	for sg in segs:
		sg["bend"] = bend
	return {"segs": segs, "start": origin - LEAD, "sung": sung, "curve": curve}


## Word [param word]'s phones (ARPAbet, no stress marks): an authored `arpa` as it is, else the synthesizer's reading of its
## text ([method Phonemes.parse]), every word that text says.
static func phones_of(word: Dictionary) -> Array:
	var out: Array = []
	if word.get("arpa") is Array and not (word["arpa"] as Array).is_empty():
		for p in word["arpa"] as Array:
			out.append(String(p).rstrip("0123456789").to_upper())
		return out.filter(func(p: String) -> bool: return Phonemes.TABLE.has(p))
	for sentence in Phonemes.parse(String(word.get("text", ""))):
		for w in sentence:
			for p in (w as Dictionary).get("phones", []):
				if Phonemes.TABLE.has(String(p)):
					out.append(String(p))
	return out


## Whether phone [param p] is a vowel the synthesizer sings.
static func is_vowel(p: String) -> bool:
	return String((Phonemes.TABLE.get(p, {}) as Dictionary).get("type", "")) == "vowel"


## A word's [param phones] as syllables: `[{on, nu, co}]`, each a list of phones. A word with no vowel is one syllable of
## consonants (its nucleus empty).
static func syllables(phones: Array) -> Array:
	var nuclei: Array = []
	for i in phones.size():
		if is_vowel(String(phones[i])):
			nuclei.append(i)
	if nuclei.is_empty():
		return [{"on": phones.duplicate(), "nu": [], "co": []}]
	var out: Array = []
	for i in nuclei:
		out.append({"on": [], "nu": [phones[i]], "co": []})
	out[0]["on"] = phones.slice(0, int(nuclei[0]))
	for q in nuclei.size() - 1:
		var between: Array = phones.slice(int(nuclei[q]) + 1, int(nuclei[q + 1]))
		var take := 0
		for size in [3, 2, 1]:
			if size <= between.size():
				var run := " ".join(PackedStringArray(between.slice(between.size() - size)))
				if (size == 1 and run != "NG") or run in ONSETS:
					take = size
					break
		out[q]["co"] = between.slice(0, between.size() - take)
		out[q + 1]["on"] = between.slice(between.size() - take)
	out[-1]["co"] = phones.slice(int(nuclei.back()) + 1)
	return out


## Each of [param n] syllables' notes from [param notes]: one each, a note shared where there are more syllables (its time
## split between them), several for one where there are fewer (singing.py's `match`).
static func matched(n: int, notes: Array) -> Array:
	var out: Array = []
	for _j in n:
		out.append([])
	if notes.is_empty():
		return out
	if n == notes.size():
		for j in n:
			out[j] = [notes[j]]
		return out
	if n < notes.size():
		for i in notes.size():
			(out[mini(i * n / notes.size(), n - 1)] as Array).append(notes[i])
		return out
	var owners: Array = []
	for _i in notes.size():
		owners.append([])
	for j in n:
		(owners[mini(j * notes.size() / n, notes.size() - 1)] as Array).append(j)
	for i in notes.size():
		var nt: Dictionary = notes[i]
		var js: Array = owners[i]
		var share := float(nt["len"]) / float(maxi(js.size(), 1))
		for q in js.size():
			(out[int(js[q])] as Array).append({"t": float(nt["t"]) + float(q) * share, "len": share, "midi": float(nt["midi"])})
	return out


## The pitch a singer gives [param midi] (a value each [param step] seconds; [param held] how long the note at each step has
## been held): a damped glide into each change of note, vibrato on a note held long, a slow drift - all taken out by
## `style.tune` toward 1, a hard-tuned step (singing.py's `ornament`).
static func ornament(midi: PackedFloat32Array, step: float, held: PackedFloat32Array, style: Dictionary, seed: int) -> PackedFloat32Array:
	var tune := clampf(float(style.get("tune", 0.0)), 0.0, 1.0)
	var n := midi.size()
	var out := midi.duplicate()
	if n == 0:
		return out
	if tune < 1.0:
		var w := TAU * float(style.get("glide_hz", GLIDE_HZ)) * (1.0 + 6.0 * tune)
		var damping := float(style.get("damping", DAMPING))
		var z := minf(damping + (1.0 - damping) * tune, 0.999)
		var r := exp(-z * w * step)
		var th := w * sqrt(1.0 - z * z) * step
		var a1 := 2.0 * r * cos(th)
		var a2 := -r * r
		var g := 1.0 - a1 - a2
		# the response's lag, taken back so a change lands on its note
		var lead := int(round((2.0 * z / w) / step))
		var y1 := midi[mini(lead, n - 1)]
		var y2 := y1
		for i in n:
			var y := a1 * y1 + a2 * y2 + g * midi[mini(i + lead, n - 1)]
			out[i] = y
			y2 = y1
			y1 = y
	var depth := float(style.get("vibrato", 0.3)) * (1.0 - tune)
	var rate := float(style.get("vibrato_rate", 5.5))
	var wait := float(style.get("vibrato_delay", VIBRATO_DELAY))
	var drift := float(style.get("drift", 0.08)) * (1.0 - tune)
	var rnd := RandomNumberGenerator.new()
	rnd.seed = seed
	var walk := 0.0
	var phase := rnd.randf() * TAU
	for i in n:
		if held[i] < step * 0.5:
			phase = rnd.randf() * TAU   # each note's vibrato starts where it will
		var ramp := clampf((held[i] - wait) / VIBRATO_RAMP, 0.0, 1.0)
		walk = walk * 0.97 + (rnd.randf() - 0.5) * 0.06
		out[i] += depth * ramp * sin(TAU * rate * held[i] + phase) + drift * walk
	return out


## How long phone [param p] is spoken in [param spec] (s).
static func _dur(p: String, spec: Voice.Spec) -> float:
	return float((Phonemes.TABLE.get(p, {}) as Dictionary).get("dur", 80.0)) * 0.001 / maxf(spec.rate, 0.05)


static func _spoken(phones: Array, spec: Voice.Spec) -> float:
	var s := 0.0
	for p in phones:
		s += _dur(String(p), spec)
	return s


static func _seg(p: String, dur: float, s: Dictionary, start: bool, end: bool) -> Dictionary:
	return {"p": p, "dur": maxf(dur, 0.005), "word": int(s["word"]), "sentence": 0, "text": String(s["text"]),
		"word_start": start, "word_end": end, "semitones": 0.0, "amp": 1.0, "reduce": 0.0, "echo": 0.0}


static func _sil(dur: float) -> Dictionary:
	return {"p": "SIL", "dur": maxf(dur, 0.001), "word": -1, "sentence": 0, "text": "", "word_start": false,
		"word_end": false, "semitones": 0.0, "amp": 1.0, "reduce": 0.0, "echo": 0.0}
