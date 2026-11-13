extends RefCounted
class_name FormantVoice

## FormantVoice - Ghost Notes' own voice as one the Voice card lists: the Klatt formant synthesizer ([Voice]), no
## model, no weights and no recordings, bred in the Lab's fishing game ([VoiceFishing]). [VoiceHost] makes each of
## its sentences here, in-process on a worker, and answers as the host answers for a neural voice, so a reading, Test
## and an export read in it unchanged.
##
## A tab reading in it keeps the voice the game made on its row (`formant:`, [method voice_of]): the lineage that
## names it, its traits, the genome it froze with, the reception it was caught at and the bank it sings with. An empty
## one is the synthesizer's default speaker.
##
## A request is the host's: the reading's tokens in, a WAV at the host's rate and every token's span out ([method
## say]), at every voice's level ([method gain_of]: one gain a voice, never a take, as the host levels a neural one). Of the tab's rows it takes the Tone's pace and pitch, the Pace and the Pause ([method tuned]); the room is
## the reading's, after it. The game plays the voice through the same [method tuned], so what the Lab plays is what
## the reading reads.

## The id the voice list and a tab's row name it by.
const ID := "formant"
## The rate a reading takes every voice at (the host's): the synthesizer runs at [constant Voice.SR], twice it.
const RATE := 22050
## The voice list's row, shaped as the host lists a voice ([method ReadingCast.fill_voices]).
const ROW := {"id": ID, "name": "formant (Ghost Notes' own)", "backend": "formant", "installed": true, "speakers": 1,
	"license": "Ghost Notes' own synthesizer: no model, no weights, no recordings"}
## The traits [method line] names: a voice is said by the ones that lean this far from the default speaker.
const SAID_FROM := 0.25

## The speaking level every voice is played at: the host's (hosts/voice/level.py TARGET, the default neural voice's
## own), measured the host's way ([method speaking_level]).
const TARGET := 0.0547
## What a voice's level is measured on: the first sentence of the host's passage (level.py LEVEL_TEXT).
const LEVEL_TEXT := "The morning was quiet, and the road ran on past the river."
## A frame is speech within this many dB of the loud frames (the 95th percentile), and frames are this long.
const LEVEL_GATE := 30.0
const LEVEL_FRAME := 0.02
## How far a voice is ever moved: a measure past these is a broken render, not a voice.
const GAIN_MIN := 0.1
const GAIN_MAX := 10.0
## Voices whose gain is kept at once; past it the kept ones are let go.
const GAINS_KEPT := 256

static var _gains := {}
static var _gains_lock := Mutex.new()


## A row's `formant:` as the synthesizer reads it: the lineage as ints, every number a float (YAML gives a whole
## number back as an int), the bank as triples.
static func voice_of(raw: Variant) -> Dictionary:
	var v: Dictionary = raw if raw is Dictionary else {}
	var lineage: Array = []
	if v.get("lineage") is Array:
		for s in v["lineage"] as Array:
			lineage.append(int(s))
	if lineage.is_empty():
		return {}
	var bank: Array = []
	var flat: Array = v.get("bank", []) if v.get("bank") is Array else []
	for i in range(0, flat.size() - 2, 3):
		bank.append([float(flat[i]), float(flat[i + 1]), float(flat[i + 2])])
	return {"lineage": lineage, "traits": floats(v.get("traits", {})), "genome": floats(v.get("genome", {})),
		"reception": floats(v.get("reception", {})), "bank": bank}


## A voice to keep on a row: [method voice_of]'s shape, its bank one flat list so the note reads it on a line.
static func kept(lineage: Array, traits: Dictionary, genome: Dictionary, reception: Dictionary, bank: Array) -> Dictionary:
	var flat: Array = []
	for c in bank:
		flat.append_array([float((c as Array)[0]), float((c as Array)[1]), float((c as Array)[2])])
	return {"lineage": lineage.duplicate(), "traits": traits.duplicate(), "genome": genome.duplicate(),
		"reception": reception.duplicate(), "bank": flat}


## A stored map with every value a float.
static func floats(raw: Variant) -> Dictionary:
	var out := {}
	if raw is Dictionary:
		for k in raw as Dictionary:
			out[str(k)] = float((raw as Dictionary)[k])
	return out


## The synthesizer's voice for [param voice] ([method voice_of]'s shape): the default speaker when it holds none.
static func spec_of(voice: Dictionary) -> Voice.Spec:
	if voice.is_empty():
		return Voice.Spec.from_traits({}, 1, [1])
	var lineage: Array = voice["lineage"]
	var spec := Voice.Spec.from_traits(voice["traits"] as Dictionary, int(lineage[0]), lineage)
	spec.adrenochrome = (voice["genome"] as Dictionary).duplicate()
	spec.sustain_bank = (voice["bank"] as Array).duplicate(true)
	return spec


## [param spec] as a tab's rows ask, from the request [param args] ([method Delivery.request_args]): the pace (the
## Tone's and the Pace row's, with a delivery mark's lean), the Tone's pitch - formants moved with it, so a shift reads
## as a different size, as a neural voice's does - and the Pause row's rests. Changes [param spec] and returns it.
static func tuned(spec: Voice.Spec, args: Dictionary) -> Voice.Spec:
	var ratio := maxf(float(args.get("play_ratio", 1.0)), 0.25)
	var length := maxf(float(args.get("length_scale", ratio)), 0.05)
	spec.rate *= ratio / length
	spec.f0_base *= ratio
	spec.formant_scale *= ratio
	var pause := float(args.get("pause_scale", 1.0))
	spec.pause_comma *= pause
	spec.pause_stop *= pause
	return spec


## The sentence a request's tokens read: each token's own spelling and mark ([method ReadingPlan.make]), an authored
## [K AE T] override as its phones.
static func text_of(tokens: Array) -> String:
	var words := PackedStringArray()
	for t in tokens:
		var d: Dictionary = t
		var said := String(d.get("cased", d.get("text", "")))
		if d.get("arpa") is Array:
			var phones := PackedStringArray()
			for p in d["arpa"] as Array:
				phones.append(String(p).rstrip("0123456789"))
			said = "[%s]" % " ".join(phones)
		words.append(said + String(d.get("punct", "")))
	return " ".join(words)


## Make one request: [param tokens] read in [param voice], tuned by [param args], written to [param out] (absolute)
## at [constant RATE], baked with the reception the voice was caught at. Answers as the host does: `{wav,
## sample_rate, duration, tokens, phones}`, each token's span `{index, t0, t1, rest}` in the WAV's seconds. Pure but
## for the file; a worker's.
static func say(tokens: Array, voice: Dictionary, args: Dictionary, out: String) -> Dictionary:
	var text := text_of(tokens)
	if text.strip_edges().is_empty():
		return {"ok": false, "error": "nothing to say"}
	var v := voice_of(voice)
	var made := Voice.render(text, tuned(spec_of(v), args))
	var gain := gain_of(spec_of(v))
	var pcm: PackedFloat32Array = made.pcm
	for i in pcm.size():
		pcm[i] *= gain
	var rc: Dictionary = v.get("reception", {})
	pcm = VoiceStream.bake_location(pcm, float(rc.get("prox", 0.0)), float(rc.get("freq", 400.0)))
	var half := halved(pcm)
	var frames := PackedVector2Array()
	frames.resize(half.size())
	for i in half.size():
		frames[i] = Vector2(half[i], half[i])
	var wav := Splice.write_wav(out, frames, 1, RATE)
	if wav.is_empty():
		return {"ok": false, "error": "could not write " + out}
	var at := word_index(tokens, text)
	var spans := spans_of(at, made.phones)
	var phones: Array = []
	for p in made.phones:
		var k := "%d:%d" % [int(p.sentence), int(p.word)]
		if at.has(k):
			phones.append({"p": String(p.p), "w": int(at[k]), "t0": float(p.t0), "t1": float(p.t1)})
	return {"ok": true, "wav": wav, "sample_rate": RATE, "duration": float(half.size()) / RATE,
		"tokens": spans, "phones": phones, "aligned": not spans.is_empty()}


## The gain that plays [param spec] at every voice's level: [constant TARGET] over its speaking level on
## [constant LEVEL_TEXT], read as it is - no Tone, Pace or room. Measured once a voice (a render of a few seconds)
## and kept; a worker's, under a lock.
static func gain_of(spec: Voice.Spec) -> float:
	var key := str(spec.reading) + str(spec.traits) + str(spec.adrenochrome) + str(spec.sustain_bank)
	_gains_lock.lock()
	var kept: Variant = _gains.get(key)
	_gains_lock.unlock()
	if kept != null:
		return float(kept)
	var level := speaking_level(Voice.render(LEVEL_TEXT, spec).pcm, Voice.SR)
	var gain := clampf(TARGET / level, GAIN_MIN, GAIN_MAX) if level > 0.0 else 1.0
	_gains_lock.lock()
	if _gains.size() >= GAINS_KEPT:
		_gains.clear()
	_gains[key] = gain
	_gains_lock.unlock()
	return gain


## The RMS of [param pcm]'s speech, as the host measures a voice (level.py `speaking_level`): its
## [constant LEVEL_FRAME] frames within [constant LEVEL_GATE] dB of the loud ones. 0 for silence.
static func speaking_level(pcm: PackedFloat32Array, sr: int) -> float:
	var n := maxi(1, int(LEVEL_FRAME * sr))
	var frames := pcm.size() / n
	if frames == 0:
		return 0.0
	var ms := PackedFloat32Array()
	ms.resize(frames)
	for f in frames:
		var acc := 0.0
		for k in range(f * n, f * n + n):
			acc += pcm[k] * pcm[k]
		ms[f] = acc / n
	var sorted := ms.duplicate()
	sorted.sort()
	var loud := sorted[int(0.95 * float(frames - 1))]
	if loud <= 0.0:
		return 0.0
	var gate := loud * pow(10.0, -LEVEL_GATE / 10.0)
	var sum := 0.0
	var kept := 0
	for x in ms:
		if x >= gate:
			sum += x
			kept += 1
	return sqrt(sum / float(kept))


## [param pcm] at [constant Voice.SR] to [constant RATE]: a half-band low-pass, then every other sample.
static func halved(pcm: PackedFloat32Array) -> PackedFloat32Array:
	# a 7-tap half-band filter: every even tap but the center is zero, and the taps sum to one
	const MID := 0.5
	const NEAR := 0.2941
	const FAR := -0.0441
	var n := pcm.size()
	var out := PackedFloat32Array()
	out.resize((n + 1) / 2)
	for j in out.size():
		var i := j * 2
		var near := (pcm[i - 1] if i >= 1 else 0.0) + (pcm[i + 1] if i + 1 < n else 0.0)
		var far := (pcm[i - 3] if i >= 3 else 0.0) + (pcm[i + 3] if i + 3 < n else 0.0)
		out[j] = MID * pcm[i] + NEAR * near + FAR * far
	return out


## Which token each word the synthesizer said is: `"sentence:word"` -> the token's index. The synthesizer parses the
## sentence [param text] again ([method Phonemes.parse]); its words are matched to [param tokens] in order by what
## they say, a word it splits or joins resynced a few words on, so a word left unmatched only goes without a span
## (the reading times it between its neighbors).
static func word_index(tokens: Array, text: String) -> Dictionary:
	var said: Array = []                  # [sentence, word, spoken]
	var sentences := Phonemes.parse(text)
	for si in sentences.size():
		var words: Array = sentences[si]
		for wi in words.size():
			said.append([si, wi, _plain(String((words[wi] as Dictionary).get("text", "")))])
	var want: Array = []
	for t in tokens:
		want.append(_plain(String((t as Dictionary).get("text", ""))))
	var out := {}
	var i := 0
	var j := 0
	while i < said.size() and j < want.size():
		if said[i][2] == want[j]:
			out["%d:%d" % [said[i][0], said[i][1]]] = j
			i += 1
			j += 1
			continue
		var found := false
		for ahead in range(1, 4):
			if j + ahead < want.size() and said[i][2] == want[j + ahead]:
				j += ahead
				found = true
				break
			if i + ahead < said.size() and said[i + ahead][2] == want[j]:
				i += ahead
				found = true
				break
		if not found:
			i += 1
			j += 1
	return out


## Each token's span in the take, from the phones the synthesizer timed and the token each word is ([param at], [method
## word_index]): its first sound to its last, and the rest after it - the middle of the silence before the next word, where a hesitation is cut in ([method Splice.chunk]).
static func spans_of(at: Dictionary, phones: Array) -> Array:
	var span := {}
	for p in phones:
		var k := "%d:%d" % [int(p.sentence), int(p.word)]
		if not at.has(k):
			continue
		var ti: int = at[k]
		if span.has(ti):
			span[ti] = [minf(float(span[ti][0]), float(p.t0)), maxf(float(span[ti][1]), float(p.t1))]
		else:
			span[ti] = [float(p.t0), float(p.t1)]
	var keys := span.keys()
	keys.sort()
	var out: Array = []
	for n in keys.size():
		var ti: int = keys[n]
		var t1 := float(span[ti][1])
		var next_t0 := float(span[keys[n + 1]][0]) if n + 1 < keys.size() else t1 + 0.1
		out.append({"index": ti, "t0": snappedf(float(span[ti][0]), 0.0001), "t1": snappedf(t1, 0.0001),
			"rest": snappedf(0.5 * (t1 + maxf(next_t0, t1)), 0.0001)})
	return out


## A word as it is compared: lower case, letters, digits and apostrophes.
static func _plain(w: String) -> String:
	var out := ""
	for c in w.to_lower():
		if (c >= "a" and c <= "z") or (c >= "0" and c <= "9") or c == "'":
			out += c
	return out


## A lineage's name, as the Collection shows a seed: its generation and its fingerprint.
static func name_of(lineage: Array) -> String:
	return "g%d·%06x" % [lineage.size() - 1, hash(str(lineage)) & 0xFFFFFF]


## [param voice] ([method voice_of]'s shape) in a line: its name and the traits it leans on, "" for none.
static func line(voice: Dictionary) -> String:
	if voice.is_empty():
		return ""
	var leans := PackedStringArray()
	var traits: Dictionary = voice.get("traits", {})
	for key in Voice.TRAIT_KEYS:
		var x := float(traits.get(key, 0.0))
		if absf(x) >= SAID_FROM:
			leans.append("%s %+.1f" % [key, x])
	return "%s  ·  %s" % [name_of(voice["lineage"] as Array), ", ".join(leans) if not leans.is_empty() else "near the default speaker"]
