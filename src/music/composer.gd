extends RefCounted
class_name Composer

## Composer - a composed Sound's score, worked out from its `sound:` block, the note's words and the song it imported
## (next/music.md): a pure function, like [method TablePlan.make]. THE SEEDED SONG IS A SCORE NOBODY WROTE DOWN: every
## choice the block leaves open is drawn from the seed, and the author overrides choice by choice on the Sound card.
##
##   score(block, {lyrics: Lyrics.parse(...), reference: {} or a reference.json}) ->
##     {tempo, beat, meter, key: {tonic, scale}, bars, start, length,
##      sections: [{kind, label, bar, bars, start, length, parts}],
##      chords: [{bar, beat, root, quality}],
##      parts: [{key, instrument (resolved), notes: [{t, len, midi | hit, vel}], level, pan, fx, mute}],
##      vocal: {singer, style, level, pan, fx, mute, phrases: [{at, text, words: [{text, notes: [{t, len, midi}]}]}]}}
##
## Times in the score are seconds (`start` is where the first bar falls); the music host renders it as it is.
##
## - THE FORM. With a reference, its bar grid and its sung bars: each section of the words is laid on the stretch of
##   bars the reference sings most in, a line a bar (or two), in order (`_place_sections`), and the bars between are an
##   intro, breaks and an outro; a section the author pinned (`place`: its index -> its first bar) stays where it is
##   put. Without one, the words' sections in order, an intro and an outro around them.
## - THE HARMONY IS THE SPINE: one chord a beat every pitched part reads - the reference's, or each kind of section's
##   progression ([constant SongParts.PROGRESSIONS]) drawn from the seed.
## - A ROLL DRAWS EVERYTHING THE BLOCK LEAVES OPEN ([method drawn]): the tempo, key and mode, the swing, the form and
##   how its lines are paced, the chords and how often they change, who plays in each section, every part's pattern,
##   sound and notes, the tune, the singer and how they sing. With a reference, `likeness` is the chance each thing it
##   has is kept instead (its tempo, key, form, chords, drums, bass line and tune), each by a draw of its own.
## - EACH PART draws from the song's seed and its own number together (`part_seed`): rolling the song is a new song,
##   every part moved; rolling a part moves it alone, so muting or rolling a part is a fair comparison.
## - THE VOICE sings each line on the reference's melody in its bars (`reference`), or on a melody made for the words
##   (`composed`: stressed syllables on strong beats, chord tones there, a contour a line, lines answering each other),
##   or recites it (`recite`), moved by octaves to sit in the singer's range; heard, as far as its `vocoder` says,
##   through a vocoder playing those notes (the music host's).

const METER := 4
## Seconds past the last bar the score runs, for the tails to ring out.
const TAIL := 3.0
## Where a sung line wants to sit, by the singer's voice (MIDI centers): a melody is moved by octaves to be nearest.
const SINGER_CENTER := {"f": 67, "m": 57}
## The default singer: Kokoro's Puck, who holds a melody into the fourth octave (Michael breaks there).
const SINGER := {"voice": "kokoro", "speaker": 13, "name": "am_puck"}
## How the voice sings when the block says nothing: a little glide, vibrato on held notes, no hard tuning.
const STYLE := {"tune": 0.15, "vibrato": 0.15, "vibrato_rate": 5.4, "drift": 0.03}
## A sung bar in a reference: this share of it voiced.
const SUNG := 0.2
## Syllables a second a line is sung at, and what a line laid far from it costs its placing (a bar's worth an octave).
const SUNG_RATE := 2.6
const PACE_COST := 0.35
## A line on the reference's tune: how much a strong beat counts beside the reference's own onsets, and the most
## sixteenths between two syllables.
const REF_METER := 0.25
const REF_GAP := 8
## The widest leap a line read from a reference keeps between two notes (semitones); wider is taken for an octave slip.
const LEAP_MOST := 7
## A reference's bass starts a new note where its low band rises this much (0-1), even on the same pitch.
const BASS_ONSET := 0.45
## The chance a roll keeps each thing the reference has, where the block says nothing (`likeness`).
const LIKENESS := 0.5
## A tempo drawn free of a reference (beats a minute), and one drawn over a reference's form, as a share of its tempo:
## near enough that the lines laid on its bars are still sung at a pace a voice can carry.
const TEMPO_FREE := [68, 160]
const TEMPO_OVER_FORM := [0.75, 1.35]
## The modes a key is drawn in.
const MODES := ["major", "minor", "dorian", "mixolydian", "lydian"]
## The chance a roll swings, and how far: where an eighth's second half falls, 0.5 straight.
const SWING_CHANCE := 0.35
const SWING := [0.57, 0.67]
## The chance a part steps out of a section's usual line-up, or into it, where a roll draws who plays.
const ARRANGE := 0.25
## A free form's lines: the most syllables a second a line is laid at (a faster line takes another bar).
const SUNG_MOST := 4.2
## The singers a roll draws from where the author picked none: Kokoro readers heard holding a melody.
const SINGERS := [{"voice": "kokoro", "speaker": 13, "name": "am_puck"}, {"voice": "kokoro", "speaker": 0, "name": "af_heart"}]
## How a roll draws the voice's manner where the author set none: [least, most].
const STYLE_DRAWN := {"tune": [0.0, 0.8], "vibrato": [0.05, 0.35], "drift": [0.01, 0.06]}


## The score of [param block] for [param ctx] (`lyrics`, `reference`).
static func score(block: Dictionary, ctx: Dictionary) -> Dictionary:
	var seed := int(block.get("seed", 1))
	var ref: Dictionary = ctx.get("reference", {}) if ctx.get("reference", {}) is Dictionary else {}
	var lyrics: Array = ctx.get("lyrics", [])
	var parts_cfg: Dictionary = (block.get("parts", {}) as Dictionary).duplicate() if block.get("parts", {}) is Dictionary else {}
	if parts_cfg.is_empty():
		for k in default_parts(ref, not lyrics.is_empty()):
			parts_cfg[k] = {}
	var roll := drawn(block, ref, parts_cfg)
	var tempo := float(roll["tempo"])
	var beat := 60.0 / tempo
	var key: Dictionary = roll["key"]
	# A KEY OVER A REFERENCE MOVES IT: its chords and its tune by the nearest interval from its key to this one
	var shift := 0
	if not ref.is_empty():
		shift = posmod(int(key["tonic"]) - int(_ref_key(ref)["tonic"]) + 6, 12) - 6
	var form := _form(block, ref if bool(roll["form"]) else {}, lyrics, tempo, seed)
	var band: Array = parts_cfg.keys().filter(func(k: String) -> bool: return k != "vocal")
	if bool(roll["arrange"]):
		_arrange(form, band, seed)
	var bars := 0
	for s in form:
		bars = maxi(bars, int(s["bar"]) + int(s["bars"]))
	var start := float(ref.get("offset", 0.0)) if bool(roll["form"]) and bool(block.get("follow_reference", true)) else 0.0
	var swing := float(roll["swing"])
	var chords := _harmony(block, ref if bool(roll["harmony"]) else {}, form, key, seed, shift)
	var per_beat := _chord_track(chords, bars)
	var has_vocal := parts_cfg.has("vocal") and not lyrics.is_empty()
	var ctx2 := {"form": form, "per_beat": per_beat, "key": key, "beat": beat, "start": start, "bars": bars,
		"ref": ref, "has_vocal": has_vocal, "shift": shift, "seed": seed, "swing": swing}
	var parts: Array = []
	var kick: Array = []
	for k in SongParts.PARTS:
		if k == "vocal" or not parts_cfg.has(k):
			continue
		var cfg: Dictionary = parts_cfg[k] if parts_cfg[k] is Dictionary else {}
		var row: Dictionary = SongParts.PARTS[k]
		var chose := choice_of(k, cfg, seed, ref, bool((roll["follow"] as Dictionary).get(k, false)))
		var pattern := String(chose["pattern"])
		var inst := String(chose["instrument"])
		var pseed := part_seed(seed, k, cfg)
		var notes := _part_notes(k, pattern, _rng(pseed, k), ctx2, kick)
		if k == "drums":
			for n in notes:
				if String(n.get("hit", "")) == "kick":
					kick.append(float(n["t"]))
		parts.append({"key": k, "instrument": Instruments.resolve(inst, pseed), "notes": _to_seconds(notes, beat, start, swing),
			"level": float(cfg.get("level", row["level"])), "pan": float(cfg.get("pan", row["pan"])),
			"fx": (row["fx"] as Dictionary).duplicate(true), "mute": bool(cfg.get("mute", false)),
			"pattern": pattern, "instrument_key": inst, "seed": pseed})
	var vocal := {}
	if has_vocal:
		var vcfg: Dictionary = (parts_cfg["vocal"] as Dictionary).duplicate() if parts_cfg["vocal"] is Dictionary else {}
		vcfg["pattern"] = choice_of("vocal", vcfg, seed, ref, bool((roll["follow"] as Dictionary).get("vocal", false)))["pattern"]
		vocal = _vocal(vcfg, ctx2, lyrics)
	var sections: Array = []
	for s in form:
		var d: Dictionary = s.duplicate(true)
		d["start"] = start + int(s["bar"]) * METER * beat
		d["length"] = int(s["bars"]) * METER * beat
		d.erase("lines")
		sections.append(d)
	return {"tempo": tempo, "beat": beat, "meter": METER, "key": key, "bars": bars, "start": start,
		"length": start + bars * METER * beat + TAIL, "sections": sections, "chords": chords, "parts": parts,
		"vocal": vocal, "seed": seed, "kicks": _beats_to_s(kick, beat, start, swing), "roll": roll}


## WHAT A ROLL DRAWS of the song as a whole, where [param block] leaves it open: `{likeness, form, harmony, follow: {part:
## bool}, tempo, key, swing, arrange, kept}` (`kept`: what of the song as a whole is the reference's - tempo, key,
## form, chords). Each thing [param ref] has - its tempo, key, form, chords, each part's pattern
## (drums, bass line, tune), its straight feel and its line-ups - is kept with the chance `likeness` ([constant
## LIKENESS] where unset), each by a draw of its own; what is not kept is drawn. The reference's chords, drums, bass
## and tune lie on its bars, so they are kept only with its form, and a part pinned to the reference keeps the form.
static func drawn(block: Dictionary, ref: Dictionary, parts_cfg: Dictionary) -> Dictionary:
	var seed := int(block.get("seed", 1))
	var has_ref := not ref.is_empty() and int(ref.get("bars", 0)) > 0
	var like := clampf(float(block.get("likeness", LIKENESS)), 0.0, 1.0) if has_ref else 0.0
	var keeps := func(what: String) -> bool: return has_ref and _rng(seed, "keep:" + what).randf() < like
	var pinned := false
	for k in parts_cfg:
		if parts_cfg[k] is Dictionary and String((parts_cfg[k] as Dictionary).get("pattern", "")) == "reference":
			pinned = true
	var form: bool = has_ref and (pinned or keeps.call("form"))
	var harmony: bool = form and (String(block.get("harmony", "")) == "reference" or (not block.has("harmony") and keeps.call("harmony")))
	var follow := {}
	for k in ["drums", "bass", "vocal"]:
		follow[k] = form and keeps.call("pattern:" + k)
	var kept: Array = []
	var tempo := float(block.get("tempo", 0.0))
	if tempo <= 0.0:
		var rt := _rng(seed, "tempo")
		if has_ref and keeps.call("tempo"):
			tempo = float(ref["tempo"])
			kept.append("tempo")
		elif form:
			tempo = roundf(float(ref["tempo"]) * lerpf(float(TEMPO_OVER_FORM[0]), float(TEMPO_OVER_FORM[1]), rt.randf()))
		else:
			tempo = float(rt.randi_range(int(TEMPO_FREE[0]), int(TEMPO_FREE[1])))
	var key := MusicTheory.parse_key(String(block.get("key", "")))
	if key.is_empty():
		var rk := _rng(seed, "key")
		if has_ref and keeps.call("key"):
			key = _ref_key(ref)
			kept.append("key")
		else:
			var tonic := rk.randi_range(0, 11)
			# the reference's chords keep their own mode: a key drawn over them moves only where they stand
			key = {"tonic": tonic, "scale": _ref_key(ref)["scale"] if harmony else MODES[rk.randi_range(0, MODES.size() - 1)]}
	var swing := 0.5
	if not (has_ref and keeps.call("feel")):
		var rs := _rng(seed, "swing")
		if rs.randf() < SWING_CHANCE:
			swing = lerpf(float(SWING[0]), float(SWING[1]), rs.randf())
	if form:
		kept.append("form")
	if harmony:
		kept.append("chords")
	return {"likeness": like, "form": form, "harmony": harmony, "follow": follow, "tempo": tempo, "key": key,
		"swing": swing, "arrange": not (has_ref and keeps.call("arrange")), "kept": kept}


## A PART'S NUMBER, as it is drawn from: the song's [param seed] and the part's own number together, so rolling the song
## moves every part at once - a new song - and rolling a part moves that part alone. The part's own number is its
## variation, the song its world.
static func part_seed(seed: int, part: String, cfg: Dictionary) -> int:
	return absi(hash(["part", seed, part, int(cfg.get("seed", 1))])) % 1000000007


## THE BAND: a part's pattern and instrument where the block names none. The reference's own where the roll keeps it
## ([param follow]) and the reference has the part (its drum pattern, its bass line, its sung tune); otherwise drawn
## from the song's [param seed] among the rows the part can play - so rolling the song draws another band, and a part
## the author set stays set.
static func choice_of(part: String, cfg: Dictionary, seed: int, ref: Dictionary, follow := true) -> Dictionary:
	var row: Dictionary = SongParts.PARTS.get(part, {})
	var pattern := String(cfg.get("pattern", ""))
	if pattern.is_empty():
		var has := (ref.get("parts", []) as Array).has(part)
		if follow and part == "drums" and not (ref.get("drums", {}) as Dictionary).is_empty():
			pattern = "reference"
		elif follow and part == "bass" and not (ref.get("bass", {}) as Dictionary).is_empty():
			pattern = "reference"
		elif part == "vocal":
			# a tune made for the words, now and then recited
			pattern = "reference" if follow and not (ref.get("voice", {}) as Dictionary).is_empty() \
				else ("recite" if _rng(seed, "pattern:vocal").randf() < 0.15 else "composed")
		else:
			var offered := SongParts.patterns_for(part, false)
			var rng := _rng(seed, "pattern:" + part)
			pattern = String(offered[rng.randi_range(0, offered.size() - 1)]) if not offered.is_empty() else String(row.get("pattern", ""))
		if pattern == "reference" and not has and part != "vocal" and ref.get("parts") is Array:
			pattern = String(row.get("pattern", ""))
	var inst := String(cfg.get("instrument", ""))
	if inst.is_empty() and part != "vocal":
		var rows := Instruments.for_part(part)
		var rng2 := _rng(seed, "instrument:" + part)
		inst = String(rows[rng2.randi_range(0, rows.size() - 1)]) if not rows.is_empty() else String(row.get("instrument", ""))
	return {"pattern": pattern, "instrument": inst}


## The parts a song starts with, where the block names none: what the reference was heard to have (its `parts`), the
## voice too where the note has words; without a reference, a small band.
static func default_parts(ref: Dictionary, has_words: bool) -> Array:
	var out: Array = []
	if ref.get("parts") is Array:
		for k in ref["parts"]:
			if SongParts.PARTS.has(String(k)) and String(k) != "vocal":
				out.append(String(k))
	else:
		out = ["drums", "bass", "keys", "pad"]
	if has_words:
		out.append("vocal")
	return out


# --- the form -------------------------------------------------------------------------------------

## The song's sections in order: `[{kind, label, bar, bars, parts, lines: [{line, bar, bars}]}]` - laid on [param ref]'s
## bars where it is handed, else drawn from [param seed]: an intro, the words' sections in order, each kind's lines
## paced for [param tempo] (as many bars a line as keep it under SUNG_MOST syllables a second, now and then one more),
## breaks after a chorus, an outro.
static func _form(block: Dictionary, ref: Dictionary, lyrics: Array, tempo: float, seed: int) -> Array:
	var lines_of: Array = []  # each lyric section's lines
	for s in lyrics:
		lines_of.append(s["lines"])
	if not ref.is_empty() and int(ref.get("bars", 0)) > 0:
		var total := int(ref["bars"])
		var sung: Array = ref.get("sung", [])
		var fixed: Dictionary = block.get("place", {}) if block.get("place", {}) is Dictionary else {}
		var placed := _place_sections(lyrics, sung, total, float(ref.get("beat", 0.6)), fixed) if not lyrics.is_empty() else []
		var out: Array = []
		var at := 0
		for i in placed.size():
			var p: Dictionary = placed[i]
			if int(p["bar"]) > at:
				out.append(_section(("intro" if out.is_empty() else "break"), at, int(p["bar"]) - at))
			var s: Dictionary = lyrics[i]
			var sec := _section(String(s["kind"]), int(p["bar"]), int(p["bars"]), String(s["label"]))
			var lines: Array = []
			for k in (s["lines"] as Array).size():
				lines.append({"line": s["lines"][k], "bar": int(p["bar"]) + k * int(p["per"]), "bars": int(p["per"])})
			sec["lines"] = lines
			sec["lyric"] = i
			sec["pinned"] = fixed.has(str(i))
			out.append(sec)
			at = int(p["bar"]) + int(p["bars"])
		if at < total:
			out.append(_section("outro" if not out.is_empty() else "verse", at, total - at))
		return out
	# drawn: an intro, the words' sections in order (a break after a chorus that has more after it), an outro
	var rng := _rng(seed, "form")
	var intro: int = [2, 4, 4, 8][rng.randi_range(0, 3)]
	var gap: int = [0, 2, 4, 4, 8][rng.randi_range(0, 4)]
	var outro: int = [2, 4, 8][rng.randi_range(0, 2)]
	var bar_s := METER * 60.0 / maxf(tempo, 40.0)
	var out2: Array = [_section("intro", 0, intro)]
	var bar := intro
	if lyrics.is_empty():
		for kind in ["verse", "chorus", "break", "verse", "chorus"]:
			out2.append(_section(kind, bar, 8))
			bar += 8
	var pace := {}  # each kind of section's bars a line
	for i in lyrics.size():
		var s: Dictionary = lyrics[i]
		var kind := String(s["kind"])
		if not pace.has(kind):
			var most := 1
			for l in s["lines"]:
				most = maxi(most, Lyrics.syllables_of(l))
			var per := clampi(ceili(most / (SUNG_MOST * bar_s)), 1, 4)
			if per < 4 and most / ((per + 1) * bar_s) >= SUNG_RATE * 0.6 and _rng(seed, "pace:" + kind).randf() < 0.3:
				per += 1
			pace[kind] = per
		var per2: int = pace[kind]
		var sec := _section(kind, bar, (s["lines"] as Array).size() * per2, String(s["label"]))
		var lines: Array = []
		for k in (s["lines"] as Array).size():
			lines.append({"line": s["lines"][k], "bar": bar + k * per2, "bars": per2})
		sec["lines"] = lines
		out2.append(sec)
		bar += int(sec["bars"])
		if kind == "chorus" and i + 1 < lyrics.size() and gap > 0:
			out2.append(_section("break", bar, gap))
			bar += gap
	out2.append(_section("outro", bar, outro))
	return out2


## WHO PLAYS WHERE, drawn: each kind of section's usual line-up ([constant SongParts.SECTIONS]) with each of the band's
## parts stepping out of it, or into it, by the chance ARRANGE - the same for every section of a kind - and never a
## section the band has left entirely.
static func _arrange(form: Array, band: Array, seed: int) -> void:
	var lineups := {}
	for s in form:
		var kind := String(s["kind"])
		if not lineups.has(kind):
			var rng := _rng(seed, "arrange:" + kind)
			var parts: Array = (s["parts"] as Array).duplicate()
			for k in SongParts.PARTS:
				if k == "vocal" or rng.randf() >= ARRANGE:
					continue
				if parts.has(k):
					parts.erase(k)
				else:
					parts.append(k)
			if not band.is_empty() and not parts.any(func(k: String) -> bool: return band.has(k)):
				parts.append(band[rng.randi_range(0, band.size() - 1)])
			lineups[kind] = parts
		s["parts"] = (lineups[kind] as Array).duplicate()


static func _section(kind: String, bar: int, bars: int, label := "") -> Dictionary:
	var k := kind if SongParts.SECTIONS.has(kind) else "verse"
	return {"kind": k, "label": label if not label.is_empty() else Registry.label(SongParts.SECTIONS, k), "bar": bar,
		"bars": bars, "parts": (Registry.field(SongParts.SECTIONS, k, "parts", []) as Array).duplicate(), "lines": []}


## EACH SECTION OF THE WORDS ON THE BARS THE REFERENCE SINGS: `[{bar, bars, per}]` a section, in order - its first bar
## and a line every `per` (1 or 2) bars - the placing that covers the most sung bars and the fewest unsung ones
## (a dynamic program over the sections and the bars), each section's lines at a pace words are sung at: a line laid
## over twice the bars it needs is charged for how far its syllables a second fall from SUNG_RATE. A section the author
## pinned ([param fixed]: its index -> its first bar, the block's `place`) starts there and nowhere else.
static func _place_sections(lyrics: Array, sung: Array, total: int, beat: float, fixed := {}) -> Array:
	var n := lyrics.size()
	var gain: Array = []  # gain[b] = how much bar b wants to be sung
	for b in total:
		gain.append((float(sung[b]) if b < sung.size() else 0.0) - SUNG * 1.5)
	var prefix: Array = [0.0]
	for b in total:
		prefix.append(float(prefix[b]) + float(gain[b]))
	# best[i][b]: the best score with the first i sections placed and ending at or before bar b
	var NEG := -1.0e9
	var best: Array = []
	var choice: Array = []
	for i in n + 1:
		var row: Array = []
		var ch: Array = []
		for b in total + 1:
			row.append(0.0 if i == 0 else NEG)
			ch.append(null)
		best.append(row)
		choice.append(ch)
	for i in range(1, n + 1):
		var count := (lyrics[i - 1]["lines"] as Array).size()
		var syllables := 0
		for l in lyrics[i - 1]["lines"]:
			syllables += Lyrics.syllables_of(l)
		var pace := {}  # what each `per` is charged for its pace
		for per: int in [1, 2]:
			var rate := float(syllables) / maxf(count * per * METER * beat, 0.01)
			pace[per] = PACE_COST * count * absf(log(rate / SUNG_RATE) / log(2.0))
		for b in range(1, total + 1):
			best[i][b] = best[i][b - 1]
			choice[i][b] = choice[i][b - 1]
			for per: int in [1, 2]:
				var span: int = count * per
				var s: int = b - span
				if s < 0 or float(best[i - 1][s]) <= NEG / 2:
					continue
				if fixed.has(str(i - 1)) and int(fixed[str(i - 1)]) != s:
					continue
				var v := float(best[i - 1][s]) + float(prefix[b]) - float(prefix[s]) - float(pace[per])
				if v > float(best[i][b]):
					best[i][b] = v
					choice[i][b] = {"bar": s, "bars": span, "per": per, "end": b}
	var out: Array = []
	var b := total
	for i in range(n, 0, -1):
		var c: Variant = choice[i][b]
		if c == null:
			return []
		out.push_front(c)
		b = int((c as Dictionary)["bar"])
	return out


# --- the harmony ----------------------------------------------------------------------------------

## The chords, each where it begins: `[{bar, beat, root, quality}]`.
static func _harmony(block: Dictionary, ref: Dictionary, form: Array, key: Dictionary, seed: int, shift := 0) -> Array:
	var out: Array = []
	if not ref.is_empty() and String(block.get("harmony", "reference")) == "reference" and not (ref.get("chords", []) as Array).is_empty():
		for c in ref["chords"]:
			out.append({"bar": int(c["bar"]), "beat": int(c["beat"]), "root": posmod(int(c["root"]) + shift, 12),
				"quality": String(c["quality"])})
		return out
	var picks := {}  # each kind of section's progression, and its chords' length in beats
	var lengths := {}
	for s in form:
		var kind := String(s["kind"])
		if not picks.has(kind):
			var rng := _rng(seed, "harmony:" + kind)
			var keys: Array = SongParts.PROGRESSIONS.keys()
			if String(key["scale"]) in ["minor", "dorian", "phrygian", "harmonic_minor", "minor_pentatonic"]:
				keys = keys.filter(func(k: String) -> bool: return k != "pop" and k != "fifties")
			picks[kind] = keys[rng.randi_range(0, keys.size() - 1)]
			# a chord a bar mostly; now and then two bars a chord, or two chords a bar (a two-chord sway twice as long)
			var u := _rng(seed, "rhythm:" + kind).randf()
			var bars_a_chord := 1.0 if u < 0.55 else (2.0 if u < 0.8 else 0.5)
			if (SongParts.PROGRESSIONS[picks[kind]]["degrees"] as Array).size() <= 2:
				bars_a_chord *= 2.0
			lengths[kind] = int(bars_a_chord * METER)
		var degrees: Array = SongParts.PROGRESSIONS[picks[kind]]["degrees"]
		var span: int = lengths[kind]
		var c := 0
		while c * span < int(s["bars"]) * METER:
			var at := c * span
			var d := int(degrees[c % degrees.size()])
			var ch := MusicTheory.diatonic(int(key["tonic"]), String(key["scale"]), d, kind in ["verse", "bridge"])
			out.append({"bar": int(s["bar"]) + at / METER, "beat": at % METER, "root": int(ch["root"]), "quality": String(ch["quality"])})
			c += 1
	return out


## The chord sounding on every beat: [{root, quality, since (its first beat), until}].
static func _chord_track(chords: Array, bars: int) -> Array:
	var out: Array = []
	var total := bars * METER
	var cur := {"root": 0, "quality": "", "since": 0}
	var k := 0
	var sorted := chords.duplicate()
	sorted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a["bar"]) * METER + int(a["beat"]) < int(b["bar"]) * METER + int(b["beat"]))
	for i in total:
		while k < sorted.size() and int(sorted[k]["bar"]) * METER + int(sorted[k]["beat"]) <= i:
			cur = {"root": int(sorted[k]["root"]), "quality": String(sorted[k]["quality"]), "since": i}
			k += 1
		out.append(cur)
	# each chord's end, for parts that hold it
	var until := total
	for i in range(total - 1, -1, -1):
		if i + 1 < total and int(out[i + 1]["since"]) != int(out[i]["since"]):
			until = i + 1
		out[i] = (out[i] as Dictionary).merged({"until": until})
	return out


static func _chord_at(ctx: Dictionary, beat: float) -> Dictionary:
	var pb: Array = ctx["per_beat"]
	return pb[clampi(int(floor(beat)), 0, pb.size() - 1)] if not pb.is_empty() else {"root": 0, "quality": "", "since": 0, "until": 1}


## The sections a part plays in, as [bar, bars].
static func _playing(part: String, ctx: Dictionary) -> Array:
	var out: Array = []
	for s in ctx["form"]:
		var parts: Array = s["parts"]
		# without a voice, the lead sings the voice's sections
		if parts.has(part) or (part == "lead" and not bool(ctx["has_vocal"]) and parts.has("vocal")):
			out.append(s)
	return out


# --- the parts ------------------------------------------------------------------------------------

## A part's notes, in beats from the first bar: [{t, len, midi | hit, vel}].
static func _part_notes(part: String, pattern: String, rng: RandomNumberGenerator, ctx: Dictionary, kick: Array) -> Array:
	match part:
		"drums":
			return _drums(pattern, rng, ctx)
		"bass":
			return _bass(pattern, rng, ctx, kick)
		"keys":
			return _keys(pattern, rng, ctx)
		"pad":
			return _pad(rng, ctx)
		"guitar":
			return _guitar(pattern, rng, ctx)
		"lead":
			return _lead(rng, ctx)
		"bells":
			return _bells(rng, ctx)
	return []


static func _drums(pattern: String, rng: RandomNumberGenerator, ctx: Dictionary) -> Array:
	var out: Array = []
	var ref: Dictionary = ctx["ref"]
	var own := SongParts.drum_steps(pattern if pattern != "reference" else "backbeat")
	var swing := float(Registry.field(SongParts.PATTERNS, pattern, "swing", 0.5))
	var ghost := 0.25
	var playing := _playing("drums", ctx)
	for si in playing.size():
		var s: Dictionary = playing[si]
		var energy := float(Registry.field(SongParts.SECTIONS, String(s["kind"]), "energy", 0.7))
		for b in range(int(s["bar"]), int(s["bar"]) + int(s["bars"])):
			var steps := own
			if pattern == "reference":
				steps = _ref_drums(ref, b, own)
			var last := b == int(s["bar"]) + int(s["bars"]) - 1 and int(s["bars"]) >= 4
			for hit in steps:
				var row: Array = steps[hit]
				for k in row.size():
					var v := float(row[k])
					if v <= 0.0:
						continue
					if last and k >= 8 and hit in ["snare", "kick", "clap"]:
						continue  # the fill takes the bar's second half
					if energy < 0.5 and hit in ["snare", "clap", "open_hat"]:
						continue
					out.append(_hit(hit, b, k, v * (0.75 + 0.25 * energy), swing, rng))
			if energy >= 0.6 and rng.randf() < ghost:
				out.append(_hit("ghost", b, [6, 10, 14, 15][rng.randi_range(0, 3)], 0.8, swing, rng))
			if last and energy >= 0.6:
				# a fill into the next section: sixteenths down the toms, a snare to finish
				var toms := ["snare", "tom_hi", "tom_hi", "tom_mid", "tom_mid", "tom_lo", "tom_lo", "snare"]
				for k in range(8, 16):
					if k % 2 == 0 or rng.randf() < 0.5:
						out.append(_hit(toms[k - 8], b, k, 0.7 + 0.3 * (k - 8) / 8.0, swing, rng))
		# a crash where a section with energy begins
		if energy >= 0.8 or (si > 0 and energy >= 0.6):
			out.append({"t": float(s["bar"]) * METER, "hit": "crash", "vel": 0.8})
	return out


## A reference's drum pattern for bar [param b]: the pattern of the reference section it falls in, its strong steps
## played ([param fallback] where it has none).
static func _ref_drums(ref: Dictionary, b: int, fallback: Dictionary) -> Dictionary:
	var letter := ""
	for s in ref.get("sections", []):
		if b >= int(s["bar"]) and b < int(s["bar"]) + int(s["bars"]):
			letter = String(s["letter"])
	var pat: Variant = (ref.get("drums", {}) as Dictionary).get(letter)
	if not (pat is Dictionary):
		return fallback
	var out := {}
	for hit in pat:
		var row: Array = []
		for v in pat[hit]:
			row.append(clampf((float(v) - 0.3) / 0.5, 0.0, 1.0) if float(v) >= 0.4 else 0.0)
		out[hit] = row
	return out


static func _hit(hit: String, bar: int, step: int, vel: float, swing: float, rng: RandomNumberGenerator) -> Dictionary:
	var t := float(step)
	if step % 2 == 1:
		t = step - 1 + 2.0 * swing
	return {"t": bar * METER + t / 4.0 + rng.randf_range(-0.008, 0.008), "hit": hit,
		"vel": clampf(vel + rng.randf_range(-0.06, 0.06), 0.05, 1.0)}


static func _bass(pattern: String, rng: RandomNumberGenerator, ctx: Dictionary, kick: Array) -> Array:
	var out: Array = []
	var reg: Array = SongParts.PARTS["bass"]["register"]
	var center := (int(reg[0]) + int(reg[1])) / 2 - 4
	var hop := rng.randf_range(0.1, 0.45)
	for s in _playing("bass", ctx):
		var b0 := int(s["bar"]) * METER
		var b1 := b0 + int(s["bars"]) * METER
		var thin := float(Registry.field(SongParts.SECTIONS, String(s["kind"]), "energy", 0.7)) < 0.5
		var pat := "drone" if thin and pattern != "reference" else pattern
		match pat:
			"reference":
				out.append_array(_ref_bass(ctx, b0 / METER, b1 / METER, center))
			"root_fifth":
				for beat in range(b0, b1, 2):
					var ch := _chord_at(ctx, beat)
					var root := MusicTheory.nearest(int(ch["root"]), center)
					out.append({"t": float(beat), "len": 1.7, "midi": root if (beat / 2) % 2 == 0 else root + 7, "vel": 0.85})
			"follow_kick":
				for t in kick:
					if t >= b0 and t < b1:
						var ch := _chord_at(ctx, t)
						out.append({"t": t, "len": 0.45, "midi": MusicTheory.nearest(int(ch["root"]), center), "vel": 0.9})
			"walking":
				for beat in range(b0, b1):
					var ch := _chord_at(ctx, beat)
					var root := MusicTheory.nearest(int(ch["root"]), center)
					var pcs := MusicTheory.chord_pcs(int(ch["root"]), String(ch["quality"]))
					var m := root
					match beat % METER:
						1:
							m = MusicTheory.nearest(int(pcs[1 % pcs.size()]), root + 3)
						2:
							m = MusicTheory.nearest(int(pcs[2 % pcs.size()]), root + 7)
						3:
							var nxt := _chord_at(ctx, beat + 1)
							m = MusicTheory.nearest(int(nxt["root"]), root) + (1 if rng.randf() < 0.5 else -1)
					out.append({"t": float(beat), "len": 0.9, "midi": m, "vel": 0.8})
			"drone":
				var beat := b0
				while beat < b1:
					var ch := _chord_at(ctx, beat)
					var until := mini(int(ch["until"]), b1)
					out.append({"t": float(beat), "len": maxf(until - beat - 0.1, 0.5),
						"midi": MusicTheory.nearest(int(ch["root"]), center), "vel": 0.75})
					beat = maxi(until, beat + 1)
			_:  # root eighths
				for e in range((b1 - b0) * 2):
					var t := b0 + e * 0.5
					var ch := _chord_at(ctx, t)
					var root := MusicTheory.nearest(int(ch["root"]), center)
					var up := e % 8 == 7 and rng.randf() < hop * 2.0
					out.append({"t": t, "len": 0.42, "midi": root + (12 if up else 0), "vel": 0.9 if e % 2 == 0 else 0.75})
	return out


## THE REFERENCE'S BASS LINE, bars [param a]..[param b]: a note where its low band starts one (or its pitch changes), held
## to the next, each in the register nearest [param center], moved with the song's key.
static func _ref_bass(ctx: Dictionary, a: int, b: int, center: int) -> Array:
	var out: Array = []
	var line: Dictionary = (ctx["ref"] as Dictionary).get("bass", {})
	var shift := int(ctx.get("shift", 0))
	var cur: Dictionary = {}
	for bar in range(a, b):
		var v: Variant = line.get(str(bar))
		for k in 8:
			var pc := int((v as Dictionary)["pitch"][k]) if v is Dictionary else -1
			var on := float((v as Dictionary)["onset"][k]) if v is Dictionary else 0.0
			var t := bar * METER + k * 0.5
			if pc < 0:
				if not cur.is_empty():
					out.append(cur)
					cur = {}
				continue
			var m := MusicTheory.nearest(posmod(pc + shift, 12), center)
			if cur.is_empty() or int(cur["midi"]) != m or on >= BASS_ONSET:
				if not cur.is_empty():
					out.append(cur)
				cur = {"t": t, "len": 0.45, "midi": m, "vel": 0.7 + 0.3 * clampf(on, 0.0, 1.0)}
			else:
				cur["len"] = t + 0.45 - float(cur["t"])
	if not cur.is_empty():
		out.append(cur)
	return out


static func _voicing(ctx: Dictionary, beat: float, prev: Array, count: int, reg: Array) -> Array:
	var ch := _chord_at(ctx, beat)
	return MusicTheory.voice_lead(prev, MusicTheory.chord_pcs(int(ch["root"]), String(ch["quality"])), count,
		int(reg[0]) + 3, int(reg[1]) - 3)


static func _keys(pattern: String, rng: RandomNumberGenerator, ctx: Dictionary) -> Array:
	var out: Array = []
	var reg: Array = SongParts.PARTS["keys"]["register"]
	var prev: Array = []
	var euclid := MusicTheory.euclid([3, 5, 5, 7][rng.randi_range(0, 3)], 16, rng.randi_range(0, 3))
	for s in _playing("keys", ctx):
		var b0 := int(s["bar"]) * METER
		var b1 := b0 + int(s["bars"]) * METER
		var energy := float(Registry.field(SongParts.SECTIONS, String(s["kind"]), "energy", 0.7))
		var pat := "block" if energy < 0.5 else pattern
		for step in range((b1 - b0) * 4):
			var t := b0 + step / 4.0
			var on := false
			var length := 0.3
			match pat:
				"block":
					on = step == 0 or int(_chord_at(ctx, t)["since"]) == int(floor(t)) and step % 4 == 0
					length = maxf(float(_chord_at(ctx, t)["until"]) - t - 0.1, 0.5)
				"syncopated":
					on = bool(euclid[step % 16])
					length = 0.4
				"arpeggio":
					var v := _voicing(ctx, t, prev, 3, reg)
					prev = v
					var up := [0, 1, 2, 1]
					out.append({"t": t, "len": 0.3, "midi": int(v[up[step % 4]]) + (12 if (step / 4) % 2 == 1 else 0), "vel": 0.65})
					continue
				_:  # offbeat stabs
					on = step % 4 == 2
			if on:
				prev = _voicing(ctx, t, prev, 3, reg)
				for m in prev:
					out.append({"t": t, "len": length, "midi": int(m), "vel": 0.7 * (0.7 + 0.3 * energy)})
	return out


static func _pad(rng: RandomNumberGenerator, ctx: Dictionary) -> Array:
	var out: Array = []
	var reg: Array = SongParts.PARTS["pad"]["register"]
	var prev: Array = []
	for s in _playing("pad", ctx):
		var beat := int(s["bar"]) * METER
		var b1 := beat + int(s["bars"]) * METER
		while beat < b1:
			var ch := _chord_at(ctx, beat)
			var until := mini(int(ch["until"]), b1)
			prev = _voicing(ctx, beat, prev, 4, reg)
			for m in prev:
				out.append({"t": float(beat), "len": maxf(until - beat - 0.05, 0.5), "midi": int(m), "vel": 0.55 + rng.randf() * 0.1})
			beat = maxi(until, beat + 1)
	return out


static func _guitar(pattern: String, rng: RandomNumberGenerator, ctx: Dictionary) -> Array:
	var out: Array = []
	var reg: Array = SongParts.PARTS["guitar"]["register"]
	var strum := String((Registry.field(SongParts.PATTERNS, "strum", "steps", {}) as Dictionary).get("strum", "x.x.x.x.x.x.x.x."))
	for s in _playing("guitar", ctx):
		var b0 := int(s["bar"]) * METER
		var b1 := b0 + int(s["bars"]) * METER
		for step in range((b1 - b0) * 4):
			var t := b0 + step / 4.0
			var ch := _chord_at(ctx, t)
			var root := MusicTheory.nearest(int(ch["root"]), int(reg[0]) + 6)
			if pattern == "strum":
				if strum[step % 16] != "x":
					continue
				var v := MusicTheory.voice_lead([], MusicTheory.chord_pcs(int(ch["root"]), String(ch["quality"])), 5, root, int(reg[1]))
				for i in v.size():
					out.append({"t": t + i * 0.012 / 0.6, "len": 0.45, "midi": int(v[i]), "vel": 0.6 + rng.randf() * 0.2})
			elif step % 2 == 0:
				for m in [root, root + 7, root + 12]:
					out.append({"t": t, "len": 0.38, "midi": m, "vel": 0.85 if step % 8 == 0 else 0.7})
	return out


## THE LEAD'S MOTIF: two bars of rhythm and contour drawn from the seed, played on each chord's tones, repeated and
## varied - moved with the harmony, its answer ending lower.
static func _lead(rng: RandomNumberGenerator, ctx: Dictionary) -> Array:
	var out: Array = []
	var reg: Array = SongParts.PARTS["lead"]["register"]
	var center := (int(reg[0]) + int(reg[1])) / 2 - 3
	var key: Dictionary = ctx["key"]
	var scale := MusicTheory.scale_of(int(key["tonic"]), String(key["scale"]))
	var cells := [[0.0, 1.0], [0.0, 0.5, 1.0], [0.0, 1.5], [0.0, 0.5, 0.75], [0.0, 2.0]]
	var rhythm: Array = []  # beats within two bars
	var at := 0.0
	while at < 7.0:
		var c: Array = cells[rng.randi_range(0, cells.size() - 1)]
		var span := float(c[c.size() - 1])
		for x in c.slice(0, c.size() - 1):
			rhythm.append(at + float(x))
		at += maxf(span, 1.0)
	var contour: Array = []
	for i in rhythm.size():
		contour.append(rng.randi_range(-2, 3))
	for s in _playing("lead", ctx):
		var b0 := int(s["bar"]) * METER
		var b1 := b0 + int(s["bars"]) * METER
		var phrase := 0
		for p0 in range(b0, b1, 8):
			for i in rhythm.size():
				var t := p0 + float(rhythm[i])
				if t >= b1:
					break
				var ch := _chord_at(ctx, t)
				var pcs := MusicTheory.chord_pcs(int(ch["root"]), String(ch["quality"]))
				var target := center + int(contour[i]) * 2 - (3 if phrase % 2 == 1 and i == rhythm.size() - 1 else 0)
				var strong := fmod(float(rhythm[i]), 1.0) < 0.01
				var pc := int(pcs[i % pcs.size()]) if strong else int(scale[(i * 2 + phrase) % scale.size()])
				var nxt := float(rhythm[i + 1]) if i + 1 < rhythm.size() else 8.0
				out.append({"t": t, "len": maxf(nxt - float(rhythm[i]) - 0.1, 0.25), "midi": MusicTheory.nearest(pc, target), "vel": 0.75})
			phrase += 1
	return out


static func _bells(rng: RandomNumberGenerator, ctx: Dictionary) -> Array:
	var out: Array = []
	var reg: Array = SongParts.PARTS["bells"]["register"]
	for s in _playing("bells", ctx):
		for b in range(int(s["bar"]), int(s["bar"]) + int(s["bars"])):
			if rng.randf() < 0.45:
				var t := b * METER + rng.randi_range(0, 7) * 0.5
				var ch := _chord_at(ctx, t)
				var pcs := MusicTheory.chord_pcs(int(ch["root"]), String(ch["quality"]))
				out.append({"t": t, "len": 2.0, "midi": MusicTheory.nearest(int(pcs[rng.randi_range(0, pcs.size() - 1)]),
					rng.randi_range(int(reg[0]) + 4, int(reg[1]) - 8)), "vel": 0.5 + rng.randf() * 0.3})
	return out


# --- the voice ------------------------------------------------------------------------------------

static func _vocal(cfg: Dictionary, ctx: Dictionary, _lyrics: Array) -> Dictionary:
	var pattern := String(cfg.get("pattern", "reference"))
	var ref: Dictionary = ctx["ref"]
	if pattern == "reference" and (ref.get("voice", {}) as Dictionary).is_empty():
		pattern = "composed"
	# who sings is the roll's as an instrument is (the song's number), how they sing the voice's own number's with it;
	# how it ornaments a note is its own number's alone
	var seed := part_seed(int(ctx.get("seed", 1)), "vocal", cfg)
	var singer: Dictionary = cfg["singer"] if cfg.get("singer") is Dictionary and not (cfg["singer"] as Dictionary).is_empty() \
		else SINGERS[_rng(int(ctx.get("seed", 1)), "singer").randi_range(0, SINGERS.size() - 1)]
	var style: Dictionary = STYLE.duplicate()
	var rs := _rng(seed, "style")
	for k in STYLE_DRAWN:
		style[k] = snappedf(lerpf(float(STYLE_DRAWN[k][0]), float(STYLE_DRAWN[k][1]), rs.randf()), 0.01)
	for k in ["tune", "vibrato", "vibrato_rate", "drift"]:
		if cfg.has(k):
			style[k] = float(cfg[k])
	style["seed"] = int(cfg.get("seed", 1))
	var beat := float(ctx["beat"])
	var start := float(ctx["start"])
	var phrases: Array = []
	var shapes := {}  # each kind of section's line shapes, so its verses share a tune
	for s in ctx["form"]:
		for li in s.get("lines", []):
			var line: Dictionary = li["line"]
			var notes: Array = []
			if pattern == "reference":
				notes = _tidy(_moved(_ref_line(ref, int(li["bar"]), int(li["bars"]), line), int(ctx.get("shift", 0))), ctx, int(li["bar"]))
			if notes.size() < 2:
				var shape_key := "%s:%d" % [String(s["kind"]), int(line.get("stanza", 0)) % 4]
				var at_in := (int(li["bar"]) - int(s["bar"])) / maxi(int(li["bars"]), 1)
				notes = _composed_line(line, int(li["bars"]), at_in, ctx, int(li["bar"]),
					_rng(seed, "line:" + String(s["kind"]) + ":" + str(at_in % 4)), pattern == "recite", shapes, shape_key)
			if notes.is_empty():
				continue
			phrases.append({"bar": int(li["bar"]), "bars": int(li["bars"]), "text": String(line["text"]),
				"notes": notes, "line": line})
	_fit_register(phrases, singer)
	var out_phrases: Array = []
	for p in phrases:
		var words := _words_on_notes(p["line"], p["notes"])
		if words.is_empty():
			continue
		var t0 := 1.0e9
		for w in words:
			t0 = minf(t0, float(w["notes"][0]["t"]))
		var swing := float(ctx.get("swing", 0.5))
		var b0 := float(int(p["bar"]) * METER)
		var at := start + warp(b0 + t0, swing) * beat
		for w in words:
			for n in w["notes"]:
				var t := float(n["t"])
				n["len"] = (warp(b0 + t + float(n["len"]), swing) - warp(b0 + t, swing)) * beat
				n["t"] = (warp(b0 + t, swing) - warp(b0 + t0, swing)) * beat
		out_phrases.append({"at": at, "text": p["text"], "words": words, "bar": p["bar"]})
	var row: Dictionary = SongParts.PARTS["vocal"]
	return {"key": "vocal", "singer": singer, "style": style, "level": float(cfg.get("level", row["level"])),
		"pan": float(cfg.get("pan", row["pan"])), "fx": (row["fx"] as Dictionary).duplicate(true),
		"mute": bool(cfg.get("mute", false)), "pattern": pattern, "phrases": out_phrases,
		"vocoder": clampf(float(cfg.get("vocoder", 0.0)), 0.0, 1.0)}


## A LINE ON THE REFERENCE'S TUNE: its syllables placed on the sixteenths of its bars where the reference's voice begins
## a sound (its `onset`) and is singing (its `pitch`), stressed syllables drawn to strong beats too (a dynamic program),
## each sung at the pitch the reference holds most until the next. [{t (beats from the line's bar), len, midi, stress}];
## [] where the reference sings nothing there.
static func _ref_line(ref: Dictionary, bar: int, bars: int, line: Dictionary) -> Array:
	var voice: Dictionary = ref.get("voice", {})
	var pitch: Array = []
	var onset: Array = []
	for b in range(bar, bar + bars):
		var v: Variant = voice.get(str(b))
		for k in 16:
			pitch.append(int((v as Dictionary)["pitch"][k]) if v is Dictionary else 0)
			onset.append(float((v as Dictionary)["onset"][k]) if v is Dictionary else 0.0)
	var sylls: Array = []
	for w in line.get("words", []):
		for st in w["stress"]:
			sylls.append(int(st))
	var n := sylls.size()
	var slots := pitch.size()
	var voiced := 0
	for p in pitch:
		voiced += 1 if int(p) > 0 else 0
	if n == 0 or voiced < 2 or n > slots:
		return []
	var metric := [1.0, 0.1, 0.3, 0.1, 0.7, 0.1, 0.3, 0.1, 0.9, 0.1, 0.3, 0.1, 0.7, 0.1, 0.3, 0.1]
	var strength: Array = []
	for k in slots:
		var v := float(onset[k]) + REF_METER * float(metric[k % 16])
		strength.append(v if int(pitch[k]) > 0 else v - 0.8)
	var NEG := -1.0e9
	var best: Array = []
	var back: Array = []
	for i in n:
		best.append([])
		back.append([])
		for k in slots:
			best[i].append(NEG)
			back[i].append(-1)
	for k in slots:
		best[0][k] = float(strength[k]) * (1.5 if int(sylls[0]) == 1 else 1.0)
	for i in range(1, n):
		for k in range(i, slots):
			var gain := float(strength[k]) * (1.5 if int(sylls[i]) == 1 else 1.0)
			for q in range(maxi(i - 1, k - REF_GAP), k):
				if float(best[i - 1][q]) <= NEG / 2:
					continue
				var v := float(best[i - 1][q]) + gain
				if v > float(best[i][k]):
					best[i][k] = v
					back[i][k] = q
	var end_k := -1
	var top := NEG
	for k in slots:
		# the last syllable wants room to hold: the voiced steps after it count for it
		var run := 0
		var j := k + 1
		while j < slots and int(pitch[j]) > 0 and run < 8:
			run += 1
			j += 1
		var v := float(best[n - 1][k]) + 0.05 * run
		if v > top:
			top = v
			end_k = k
	if end_k < 0:
		return []
	var place: Array = []
	place.resize(n)
	var k2 := end_k
	for i in range(n - 1, -1, -1):
		place[i] = k2
		k2 = int(back[i][k2]) if i > 0 else k2
	var out: Array = []
	for i in n:
		var a := int(place[i])
		var e := int(place[i + 1]) if i + 1 < n else a + 1
		if i + 1 == n:
			while e < slots and int(pitch[e]) > 0 and e - a < 8:
				e += 1
		var counts := {}
		for j in range(a, maxi(e, a + 1)):
			if int(pitch[j]) > 0:
				counts[int(pitch[j])] = int(counts.get(int(pitch[j]), 0)) + 1
		var m := 0
		var most := 0
		for q in counts:
			if int(counts[q]) > most:
				most = int(counts[q])
				m = int(q)
		if m == 0:
			m = _nearest_voiced(pitch, a)
		out.append({"t": a / 4.0, "len": maxf((e - a) / 4.0 - 0.04, 0.2), "midi": m, "stress": sylls[i]})
	return out


## A line read from a reference made singable: a note out of the key moved to the nearest tone of the chord sounding
## (else of the key), and each note in the octave nearest the note before it - a tracker's commonest slip is an
## octave, and a sung line rarely leaps past a fifth.
static func _tidy(notes: Array, ctx: Dictionary, bar: int) -> Array:
	var key: Dictionary = ctx["key"]
	var scale := MusicTheory.scale_of(int(key["tonic"]), String(key["scale"]))
	var prev := -1
	for n in notes:
		var m := int(n["midi"])
		if not scale.has(posmod(m, 12)):
			var ch := _chord_at(ctx, bar * METER + float(n["t"]))
			var pcs := MusicTheory.chord_pcs(int(ch["root"]), String(ch["quality"]))
			var best := m
			for d in [1, -1, 2, -2]:
				if pcs.has(posmod(m + d, 12)) and scale.has(posmod(m + d, 12)):
					best = m + d
					break
			if best == m:
				for d in [1, -1]:
					if scale.has(posmod(m + d, 12)):
						best = m + d
						break
			m = best
		if prev >= 0:
			while m - prev > LEAP_MOST:
				m -= 12
			while prev - m > LEAP_MOST:
				m += 12
		n["midi"] = m
		prev = m
	return notes


## [param notes] moved [param by] semitones.
static func _moved(notes: Array, by: int) -> Array:
	for n in notes:
		n["midi"] = int(n["midi"]) + by
	return notes


static func _nearest_voiced(pitch: Array, at: int) -> int:
	for d in pitch.size():
		for j in [at - d, at + d]:
			if j >= 0 and j < pitch.size() and int(pitch[j]) > 0:
				return int(pitch[j])
	return 60


## A LINE SET TO MUSIC FROM FIRST PRINCIPLES (textsetting, Halle and Lerdahl): its syllables placed on the eighths of its
## bars so stressed ones land on strong beats (a dynamic program), each held to the next, the last held longest; each
## stressed syllable on a tone of the chord sounding then, nearest the line's contour, the rest stepping between. A
## line's place in its stanza sets its contour: the first rises, the second answers on the fifth, the last comes home.
## Recited (a psalm tone): every syllable on one reciting tone but the last two, which turn to the cadence.
static func _composed_line(line: Dictionary, bars: int, at_in: int, ctx: Dictionary, bar: int, rng: RandomNumberGenerator,
		recite: bool, shapes: Dictionary, shape_key: String) -> Array:
	var sylls: Array = []  # stress a syllable
	for w in line.get("words", []):
		for st in w["stress"]:
			sylls.append(int(st))
	var n := sylls.size()
	if n == 0:
		return []
	var slots := bars * METER * 2  # eighths
	var strength := func(k: int) -> float:
		var pos := k % 8
		return [1.0, 0.1, 0.5, 0.1, 0.75, 0.1, 0.5, 0.15][pos]
	# DP: place syllable i at slot p_i, increasing, maximize sum(stress * strength), leaving the last beat for the hold
	var last := maxi(slots - 2, n - 1)
	var span := mini(slots, last + 1)
	var NEG := -1.0e9
	var best: Array = []
	var back: Array = []
	for i in n:
		best.append([])
		back.append([])
		for p in span:
			best[i].append(NEG)
			back[i].append(-1)
	for p in span:
		if p < 3:  # a line may start on a pickup into its first strong beat, never later than the second eighth past it
			best[0][p] = _fit(sylls[0], strength.call(p)) - 0.15 * p
	for i in range(1, n):
		for p in range(i, span):
			for q in range(maxi(i - 1, p - 4), p):
				if float(best[i - 1][q]) <= NEG / 2:
					continue
				var v := float(best[i - 1][q]) + _fit(sylls[i], strength.call(p)) - (0.2 if p - q > 2 else 0.0)
				if v > float(best[i][p]):
					best[i][p] = v
					back[i][p] = q
	var end_p := -1
	var top := NEG
	for p in span:
		var v: float = float(best[n - 1][p]) + float(strength.call(p)) * 0.5
		if v > top:
			top = v
			end_p = p
	if end_p < 0:  # more syllables than eighths: sixteenths, evenly
		var out_fast: Array = []
		for i in n:
			out_fast.append({"t": i * float(slots) / n * 0.5, "len": float(slots) / n * 0.5 * 0.95, "midi": 0, "stress": sylls[i]})
		return _pitch_line(out_fast, at_in, ctx, bar, rng, recite, shapes, shape_key)
	var place: Array = []
	place.resize(n)
	var p2 := end_p
	for i in range(n - 1, -1, -1):
		place[i] = p2
		p2 = int(back[i][p2]) if i > 0 else p2
	var out: Array = []
	for i in n:
		var t := int(place[i]) * 0.5
		var nxt := int(place[i + 1]) * 0.5 if i + 1 < n else minf(t + 2.0, bars * METER - 0.5)
		out.append({"t": t, "len": maxf(nxt - t - 0.05, 0.25), "midi": 0, "stress": sylls[i]})
	return _pitch_line(out, at_in, ctx, bar, rng, recite, shapes, shape_key)


static func _fit(stress: int, strength: float) -> float:
	var s := 1.0 if stress == 1 else (0.5 if stress == 2 else 0.0)
	return s * strength - (1.0 - s) * strength * 0.6


static func _pitch_line(notes: Array, at_in: int, ctx: Dictionary, bar: int, rng: RandomNumberGenerator, recite: bool,
		shapes: Dictionary, shape_key: String) -> Array:
	var key: Dictionary = ctx["key"]
	var tonic := int(key["tonic"])
	var scale := MusicTheory.scale_of(tonic, String(key["scale"]))
	var home := 60 + tonic if 60 + tonic <= 66 else 48 + tonic
	if not shapes.has(shape_key):
		# a contour: where the line starts and peaks, in scale steps over the tonic
		shapes[shape_key] = {"start": rng.randi_range(2, 4), "peak": rng.randi_range(4, 6)}
	var shape: Dictionary = shapes[shape_key]
	var end_step: int = [4, 4, 2, 0][at_in % 4]  # rise, answer on the fifth, lean, home
	var n := notes.size()
	var prev := home + 4
	for i in n:
		var t := float(notes[i]["t"])
		var u := float(i) / maxf(n - 1, 1)
		var arch := float(shape["start"]) + (float(shape["peak"]) - float(shape["start"])) * sin(PI * u) * (1.0 - u * 0.3)
		var steps := lerpf(arch, float(end_step), u * u)
		var target := MusicTheory.degree_midi(tonic, String(key["scale"]), int(round(steps)), 4)
		if home < 60:
			target -= 12
		if recite:
			target = MusicTheory.degree_midi(tonic, String(key["scale"]), 4 if i < n - 2 else (3 if i == n - 2 else end_step), 4)
		var ch := _chord_at(ctx, bar * METER + t)
		var pcs := MusicTheory.chord_pcs(int(ch["root"]), String(ch["quality"]))
		var m := target
		if int(notes[i]["stress"]) >= 1 or i == n - 1:
			var best := 99
			for pc in pcs:
				var q := MusicTheory.nearest(int(pc), float(target))
				if absi(q - target) < absi(best - target):
					best = q
			m = best
		else:
			m = MusicTheory.nearest(int(scale[posmod(scale.find(posmod(target, 12)), scale.size())]) if scale.has(posmod(target, 12)) else posmod(target, 12), float(target))
		# no leap past a sixth
		while m - prev > 9:
			m -= 12
		while prev - m > 9:
			m += 12
		notes[i]["midi"] = m
		prev = m
	return notes


## Every phrase moved by whole octaves together so the song's melody sits nearest the singer's center.
static func _fit_register(phrases: Array, singer: Dictionary) -> void:
	var all: Array = []
	for p in phrases:
		for n in p["notes"]:
			all.append(int(n["midi"]))
	if all.is_empty():
		return
	all.sort()
	var median := int(all[all.size() / 2])
	var center := int(SINGER_CENTER.get(_voice_of(singer), 60))
	var shift := int(round((center - median) / 12.0)) * 12
	for p in phrases:
		for n in p["notes"]:
			n["midi"] = int(n["midi"]) + shift


## "f" or "m": a Kokoro reader's own name says (af_, bf_, am_, bm_).
static func _voice_of(singer: Dictionary) -> String:
	var name := String(singer.get("name", ""))
	if name.length() >= 2 and name[1] in ["f", "m"]:
		return name[1]
	return "m"


## A line's notes shared among its words: each word its syllables' notes - one each where the counts agree, a note
## split where there are more syllables, a syllable held over several where there are fewer.
static func _words_on_notes(line: Dictionary, notes: Array) -> Array:
	var words: Array = line.get("words", [])
	var total := Lyrics.syllables_of(line)
	if total == 0 or notes.is_empty():
		return []
	var syll_notes: Array = []  # each syllable's notes
	var count := notes.size()
	if count >= total:
		for j in total:
			var a := j * count / total
			var b := (j + 1) * count / total
			var mine: Array = []
			for k in range(a, maxi(b, a + 1)):
				mine.append((notes[k] as Dictionary).duplicate())
			syll_notes.append(mine)
	else:
		for j in total:
			var k := j * count / total
			var share := 0
			var first := -1
			for q in total:
				if q * count / total == k:
					share += 1
					if first < 0:
						first = q
			var nt: Dictionary = (notes[k] as Dictionary).duplicate()
			var piece := float(nt["len"]) / share
			nt["t"] = float(nt["t"]) + (j - first) * piece
			nt["len"] = piece
			syll_notes.append([nt])
	var out: Array = []
	var j := 0
	for w in words:
		var mine: Array = []
		for _s in int(w["syllables"]):
			if j < syll_notes.size():
				for nt in syll_notes[j]:
					mine.append({"t": float(nt["t"]), "len": float(nt["len"]), "midi": float(nt["midi"])})
			j += 1
		if not mine.is_empty():
			out.append({"text": String(w["text"]), "notes": mine})
	return out


# --- helpers ----------------------------------------------------------------------------------------

static func _rng(seed: int, salt: String) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = hash(["sound", seed, salt])
	return r


static func _ref_key(ref: Dictionary) -> Dictionary:
	var k: Dictionary = ref.get("key", {})
	return {"tonic": int(k.get("tonic", 0)), "scale": "minor" if String(k.get("mode", "major")) == "minor" else "major"}


## Notes in beats to seconds, swung by [param swing] ([method warp]).
static func _to_seconds(notes: Array, beat: float, start: float, swing := 0.5) -> Array:
	var out: Array = []
	for n in notes:
		var d: Dictionary = (n as Dictionary).duplicate()
		var t := float(n["t"])
		d["t"] = start + warp(t, swing) * beat
		if d.has("len"):
			d["len"] = (warp(t + float(n["len"]), swing) - warp(t, swing)) * beat
		out.append(d)
	return out


## A time in beats, swung: the second half of each beat's eighths begins at [param swing] of the beat (0.5 straight)
## and everything between moves with it, so a sixteenth keeps its place in the swung eighth. Beats stay where they are.
static func warp(t: float, swing: float) -> float:
	if absf(swing - 0.5) < 1e-6:
		return t
	var b := floorf(t)
	var f := t - b
	return b + (f * swing / 0.5 if f < 0.5 else swing + (f - 0.5) * (1.0 - swing) / 0.5)


static func _beats_to_s(beats: Array, beat: float, start: float, swing := 0.5) -> Array:
	var out: Array = []
	for b in beats:
		out.append(start + warp(float(b), swing) * beat)
	return out


## What the music host is handed for [param score]: its parts, the sung takes laid at their places ([param takes]:
## `[{wav, at}]`), the duck the kick makes in the pad and bass, and the room. ([SongBake] writes it.) The voice is left
## out while no take is sung, unless [param sung_later] (a stream's, whose takes come as they are sung).
static func render_spec(score: Dictionary, takes: Array, out_dir: String, mix_name: String, sung_later := false) -> Dictionary:
	var parts: Array = []
	for p in score["parts"]:
		parts.append({"key": p["key"], "instrument": p["instrument"], "notes": p["notes"], "level": p["level"],
			"pan": p["pan"], "fx": p["fx"], "mute": p["mute"]})
	var vocals: Array = []
	var v: Dictionary = score.get("vocal", {})
	if not v.is_empty() and (not takes.is_empty() or sung_later):
		var voc := {"key": "vocal", "level": v["level"], "pan": v["pan"], "fx": v["fx"], "mute": v["mute"], "takes": takes}
		if float(v.get("vocoder", 0.0)) > 0.0:
			# the vocoder plays the line's own notes, in the mix's seconds
			var notes: Array = []
			for p in v["phrases"]:
				for w in p["words"]:
					for nt in w["notes"]:
						notes.append({"t": float(p["at"]) + float(nt["t"]), "len": float(nt["len"]), "midi": float(nt["midi"])})
			voc["vocoder"] = float(v["vocoder"])
			voc["notes"] = notes
		vocals.append(voc)
	return {"out": out_dir, "mix": mix_name, "length": score["length"], "seed": score["seed"], "beat": score["beat"],
		"parts": parts, "vocals": vocals,
		"duck": {"hits": score.get("kicks", []), "depth": 0.3, "release": 0.14, "parts": ["pad", "bass", "keys"]},
		"master": {"reverb": {"seconds": 1.9, "damp": 0.5, "predelay": 0.018}, "ceiling": -1.0}}
