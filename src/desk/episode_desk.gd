extends DeskMedium
class_name EpisodeDesk

## EpisodeDesk - a table show's episode at the desk (next/desk.md): what its acts write and point at, on the desk's pad.
##
## The episode is made by Table's agents ([TableEpisode]) and drawn from the reading's document as the card table draws it:
## its `table` (the episode's folder, seed and plan) and its `source` (the episode's script, the reader's marks in it,
## [CardReading]). Each act's writes (`tex`, `draw`, words, `strike`) and points ([constant Motions.LAWS] `write`, `point`)
## are the desk's actions ([DeskScript]'s kinds), whatever sheet and pen they name: the desk has one pad and one pen. What
## else an act does has no thing here to do it to, and is not shown.
##
## When each is done is the desk's ([method DeskMedium._build_plan]): a write begins at its act's word (`<!-- act: name -->`)
## and keeps with the words said from there to the next act's word (a line's 40 at most), ended at the last said by the voice
## its act's word is in; an act with no word follows the one before, or begins its beat. How its pen keeps with them is
## [PenPace]'s, one way for every write: its labels - a drawing's, a line's words, a formula's digits, letters and signs -
## matched to its words all at once ([method PenPace.align]); the pen one to four words ahead of the voice on that map, at
## the evenest pace that allows and never past three times its hand's ([method PenPace.path]); and where it would still fall
## behind, a short rest for it at the sentence end before, never inside a sentence ([method voiced], [method PenPace.rests];
## [EpisodeWalk] asks for it through the Medium row). A drawing is done with its words, never drawn on through the talk
## after them. The camera stays wide until the pen is picked up.
##
## The desk is the Letter's ([DeskLook]), dressed as the note's Medium card says ([DeskFormat]; the document's `medium`: its
## number `seed`, `things`, `mood`, `card_text`), each left out drawn from the episode's own number; chosen while it plays, the
## desk is dressed again and nothing written changes. Its camera is the old desk's, a little closer ([constant EPISODE_LOCAL],
## [constant EPISODE_WIDE]): on the line being written, the whole pad as a page turns. The desk is seen whole for [constant
## DESK_SEEN] after the title has gone before the pen is picked up ([method _first_floor]), whenever its first words come.

## How long the desk is seen whole after the title has gone ([method DeskMedium._opening]) before the camera comes in for the
## pen (seconds).
const DESK_SEEN := 10.0
## The camera's close and wide framings (meters away, degrees above the desk).
const EPISODE_LOCAL := {"dist": 0.66, "pitch": 79.0}
const EPISODE_WIDE := {"dist": 1.1, "pitch": 75.0}
## The most words a write keeps with, and a point is held over, when the next act's word is further off. A drawing keeps
## with every word to the next act's: they say what it shows, to its end.
const DICTATION_MOST := 40
const POINT_MOST := 24
## A beat's place in the episode, for the acts' order: the intro first, then the beats by number, the close last.
const CLOSE := 1000000
## The least silence the voice is given for the pen ([method voiced]), seconds.
const REST_LEAST := 0.5
## A sentence's last word: its stop, then any closing quote, bracket or emphasis - where the voice may rest for the pen.
const SENTENCE := "[.?!…][\"'’”)\\]*_]*$"
## The voice the rests are sized for before it is heard ([method voiced]): seconds a word - a quick one, so a slower voice
## only waits a little more at a sentence's end - and its pause after a sentence.
const VOICE_WORD := 0.38
const VOICE_PAUSE := 0.3

## What the episode wrote nothing for: lines TeX has not laid out, strikes and points at nothing - said once a load.
var notes := PackedStringArray()
## The episode's number: how its hand wavers. The desk's own is [member DeskMedium._seed], the rows' number where they give one.
var _hand := 1
## Who says each spoken word ([method _word_ends]), empty where the script's words could not be counted as the reading's.
var _voices := PackedStringArray()
## Each write's way ([method _pen_way]), as worked out for the plan and the start it was made for.
var _ways := {}
## What was chosen for the desk ([method DeskLook.picks_of]) as it was last dressed.
var _picks := {}


func _ensure_doc() -> void:
	if _subs == null or not is_instance_valid(_subs):
		return
	var d: Dictionary = _subs.document
	_title.channel = String(d.get("title", ""))
	_title.byline = String(d.get("byline", ""))
	var pay: Dictionary = d.get("table", {}) if d.get("table") is Dictionary else {}
	var src := String(d.get("source", ""))
	var rows: Dictionary = d.get("medium", {}) if d.get("medium") is Dictionary else {}
	var start: PackedStringArray = d.get("start_words", PackedStringArray()) \
		if d.get("start_words") is PackedStringArray else PackedStringArray()
	var dir := String(pay.get("dir", ""))
	# ...and the files the acts and their ink are read from, as they stand: blocked or laid out again, the desk is too
	var key := "%s|%d|%d|%d|%d|%s" % [dir, int(pay.get("seed", 0)), src.hash(), _modified(dir.path_join("acts.json")),
		_modified(dir.path_join("ink.json")), " ".join(start)]
	if key == _doc_key:
		# the desk's rows, chosen while it plays: the desk dressed again, the episode as it is
		if DeskLook.picks_of(rows) != _picks or _desk_of(rows) != _seed:
			_set_look(DeskLook.picks_of(rows), _desk_of(rows))
		return
	_doc_key = key
	load_episode(pay, src, rows, start, int(d.get("start_index", -1)))


## Load an episode: [param pay] (`{dir, seed, plan}`, [method TableEpisode.document]), its script [param src], the desk's
## rows [param rows] (`things`, `mood`); for a reading started mid-way its first words [param start] (normalized), [param
## near] the index they are about. Public for a gate, which hands it one by hand.
func load_episode(pay: Dictionary, src: String, rows := {}, start := PackedStringArray(), near := -1) -> void:
	_hand = int(pay.get("seed", 1))
	_set_look(DeskLook.picks_of(rows), _desk_of(rows))
	var dir := String(pay.get("dir", ""))
	var plan: Dictionary = pay.get("plan", {}) if pay.get("plan") is Dictionary else {}
	var parsed := CardReading.parse(src)
	_voices = _with_words(parsed, _word_ends(src))
	var lesson := lesson_of(_json(dir.path_join("acts.json")), _json(dir.path_join("ink.json")), parsed,
		CardTable.beats(plan) if CardTable.cardless(plan) else 0, _hand)
	_records = lesson["records"]
	_strokes = lesson["strokes"]
	notes = lesson["notes"]
	for n in notes:
		push_warning("ghost: desk - %s" % n)
	_actions = DeskScript.lay_out(lesson["actions"], _records)
	var spoken: PackedStringArray = parsed.get("spoken", PackedStringArray())
	_begin(spoken, start, near, func() -> PackedFloat32Array: return _steady(spoken.size()))


## The desk's lesson from an episode, pure: the acts [param raw] (`acts.json` as parsed), TeX's layout [param ink]
## (`ink.json`), the script's walk [param parsed] ([method CardReading.parse]; its `voices`, who says each word, where it has
## them: [method _with_words]), how many beats the episode has ([param beats]) and the hand's [param seed]. A write's `own`
## are its words (their indices among the spoken: its voice's), and its `map` how much of its ink goes with how many of them
## ([method PenPace.align]: a drawing's labels, a line's words, a formula's glyphs, matched to them). `{actions (the desk's,
## not laid out yet: [method DeskScript.lay_out]), records (each written line's size, by id), strokes (each one's schedule,
## by id), notes}`.
static func lesson_of(raw: Variant, ink: Variant, parsed: Dictionary, beats: int, seed: int) -> Dictionary:
	var notes := PackedStringArray()
	var doc: Dictionary = ink if ink is Dictionary else {}
	var fonts: Dictionary = doc.get("fonts", {}) if doc.get("fonts") is Dictionary else {}
	var records := {}
	var strokes := {}
	var spoken: PackedStringArray = parsed.get("spoken", PackedStringArray())
	var voices: PackedStringArray = parsed.get("voices", PackedStringArray())
	# where each beat's words begin, and each act's word
	var beat_at := {}
	for a in parsed.get("actions", []):
		var kind := String((a as Dictionary)["kind"])
		if not TableActions.source_of(kind).is_empty():
			beat_at["intro"] = int(a["after"])
		elif kind == "work":
			beat_at[str(int(a.get("card", 0)))] = int(a["after"])
		elif kind == "spread":
			beat_at["close"] = int(a["after"])
	var cue := {}
	var cue_si: Array = []
	for c in parsed.get("cues", []):
		cue[String((c as Dictionary)["name"]).to_lower()] = int(c["si"])
		cue_si.append(int(c["si"]))
	cue_si.sort()
	var acts: Array = Motions.sanitize_acts(raw if raw != null else {}, beats)["acts"]
	var order: Array = []
	for i in acts.size():
		order.append([_beat_rank(String((acts[i] as Dictionary).get("beat", ""))), i])
	order.sort()
	var out: Array = []
	var line_of := {}           # an act's name -> the first line it wrote (what a strike and a point name it by)
	var follows := 0            # the word an act with none of its own follows from
	for o in order:
		var act: Dictionary = acts[int(o[1])]
		var name := String(act.get("name", "")).to_lower()
		var beat := String(act.get("beat", ""))
		var after := int(cue.get(name, -1))
		if after < 0:
			after = maxi(follows, int(beat_at.get(beat, 0)))
		var next := _next_cue(cue_si, after, spoken.size())
		var span := mini(next - after, DICTATION_MOST)
		for t in act.get("tracks", []):
			var tr: Dictionary = t
			match String(tr.get("law", "")):
				"write":
					if tr.has("strike"):
						var of := int(line_of.get(String(tr["strike"]).to_lower(), -1))
						if of < 0:
							notes.append("%s strikes \"%s\", which wrote no line" % [name, String(tr["strike"])])
							continue
						out.append({"kind": "strike", "of": of, "id": "", "after": after, "span": 0, "write": DeskScript.STRIKE})
						continue
					var a := _write_of(tr, records, strokes, doc, fonts, seed)
					if a.is_empty():
						notes.append("%s writes a line TeX has not laid out yet" % name)
						continue
					a["after"] = after
					a["span"] = _own_span(voices, after, next - after if String(a["kind"]) == "draw" else span)
					var sched: Dictionary = strokes.get(String(a["id"]), {})
					var own := PackedInt32Array()
					var said := PackedStringArray()
					for j in int(a["span"]):
						var k := after + j
						if k < spoken.size() and (voices.size() != spoken.size() or voices[k] == voices[after]):
							own.append(k)
							said.append(spoken[k])
					var parts: Array
					if String(a["kind"]) == "draw":
						parts = [_labels(String(a["tex"])), _part_starts(sched, true)]
					elif bool(a.get("hand", false)):
						parts = [PackedStringArray(String(a["tex"]).replace("\n", " ").split(" ", false)), _part_starts(sched, false)]
					else:
						parts = _text_parts(String(a["tex"])) if String(a["kind"]) == "pad-text" else _glyph_parts(sched)
					a["own"] = own
					a["map"] = PenPace.align(parts[0], parts[1], said, float(a["write"]))
					if not line_of.has(name):
						line_of[name] = out.size()
						a["name"] = name
					out.append(a)
				"point":
					out.append({"kind": "point", "target": String(tr.get("at", "")).to_lower(), "id": "", "after": after,
						"span": maxi(1, mini(next - after, POINT_MOST)), "write": 0.0})
		follows = after + maxi(span, 0)
	return {"actions": out, "records": records, "strokes": strokes, "notes": notes}


## Write [param tr] as a desk action - its kind, id, what it writes and how long the hand takes - its size kept in [param
## records] and its strokes in [param strokes]: TeX's record of it in [param doc] (`{}` while it has none), or words in its
## hand on the pad's rules.
static func _write_of(tr: Dictionary, records: Dictionary, strokes: Dictionary, doc: Dictionary, fonts: Dictionary,
		seed: int) -> Dictionary:
	var it := TableInk.item_of_track(tr)
	if not it.is_empty():
		var rec := TableInk.record_in(doc, it)
		if rec.is_empty():
			return {}
		var id := String(it["id"])
		if not strokes.has(id):
			records[id] = rec
			strokes[id] = Ink.schedule(Ink.strokes_of(rec, seed, fonts)["strokes"], seed)
		var kind := "draw" if String(it["mode"]) == "figure" else ("pad-text" if String(it["mode"]) == "text" else "pad")
		return {"kind": kind, "id": id, "tex": String(it["tex"]), "write": float((strokes[id] as Dictionary)["length"])}
	var text := String(tr.get("text", "")).strip_edges()
	if text.is_empty():
		return {}
	var hand := String(tr.get("hand", "neat"))
	var id := "w" + (hand + "|" + text).sha256_text().substr(0, 12)
	if not strokes.has(id):
		var room := (DeskScript.PW - DeskScript.RIGHT - DeskScript.TEXT_X) / DeskScript.PX_PER_PT
		var got := SheetWriting.words(text, hand if not SheetWriting.stroke_hand(hand).is_empty() else "neat", seed, 1.0, room, false,
			DeskScript.RULE / DeskScript.PX_PER_PT)
		# (from the block's top to its first baseline: the desk lays a line by its baseline)
		var asc := float(got["ascent"])
		var lines: Array = []
		for st in got["strokes"]:
			var row: Dictionary = (st as Dictionary).duplicate()
			var pts := PackedVector2Array()
			for q in row["points"] as PackedVector2Array:
				pts.append(q - Vector2(0.0, asc))
			row["points"] = pts
			lines.append(row)
		var size: Vector2 = got["size"]
		records[id] = {"id": id, "ok": true, "w": size.x, "h": asc, "d": size.y - asc, "anchors": {}}
		strokes[id] = {"strokes": lines, "length": float(got["length"])}
	return {"kind": "pad-text", "id": id, "tex": text, "write": float((strokes[id] as Dictionary)["length"]), "hand": true}


## [param text], an episode's script, as the voice reads it at the desk, with silences (`<!-- quiet: S -->`, [constant
## CardReading.QUIET_MARK]) where the pen needs the voice to wait, each less a silence already written there: before the
## words of a write a page is turned for, as long as the turn and the pen's way off the pad take ([constant DeskScript.TURN],
## [constant DeskMedium.PARK_CLEAR]) past the words since the pen was last busy; and for the pens' ways, planned on a voice of
## [constant VOICE_WORD] a word and [constant VOICE_PAUSE] after a sentence ([method PenPace.rests]: a short rest at a sentence
## end where a pen would fall behind, never inside a sentence). [param pay] is the episode's `{dir, seed, plan}` ([method
## TableEpisode.document]). The script is returned as it is where nothing is owed, and where its words cannot be counted as
## the reading counts them.
static func voiced(text: String, pay: Dictionary) -> String:
	var dir := String(pay.get("dir", ""))
	var plan: Dictionary = pay.get("plan", {}) if pay.get("plan") is Dictionary else {}
	var parsed := CardReading.parse(text)
	var ends := _word_ends(text)
	if ends.is_empty() or ends.size() != (parsed.get("spoken", PackedStringArray()) as PackedStringArray).size():
		return text
	_with_words(parsed, ends)
	var quiet := {}
	for q in parsed.get("quiets", []):
		quiet[int((q as Dictionary)["si"])] = float(quiet.get(int(q["si"]), 0.0)) + float(q["s"])
	var lesson := lesson_of(_json(dir.path_join("acts.json")), _json(dir.path_join("ink.json")), parsed,
		CardTable.beats(plan) if CardTable.cardless(plan) else 0, int(pay.get("seed", 1)))
	var rests := {}
	var free := 0                       # the first word after the pen's last action's words
	var writes: Array = []
	for a in DeskScript.lay_out(lesson["actions"], lesson["records"]):
		var after := int((a as Dictionary).get("after", 0))
		var span := int(a.get("span", 0))
		if bool(a.get("turn", false)) and after > 0:
			var gap := float(after - free) * VOICE_WORD
			for j in range(free + 1, after + 1):
				gap += float(quiet.get(j, 0.0))
			_rest(rests, mini(after, ends.size()) - 1, DeskScript.TURN + PARK_CLEAR - gap)
		if String(a["kind"]) in DeskScript.WRITES and not (a.get("own", PackedInt32Array()) as PackedInt32Array).is_empty():
			writes.append({"map": a["map"], "own": a["own"], "ink": float(a["write"]), "after": after,
				"most": PenPace.PACE_MOST if String(a["kind"]) == "draw" else PenPace.PACE_MOST_WORDS})
		free = maxi(free, after + span)
	# ...the pens' ways, planned with the turns' rests in front of the words they come before
	var before := quiet.duplicate()
	for k in rests:
		before[int(k) + 1] = float(before.get(int(k) + 1, 0.0)) + float(rests[k])
	var full: Array = []
	for e in ends:
		full.append(bool((e as Dictionary)["stop"]))
	var given := PenPace.rests(writes, ends.size(), full, before, VOICE_WORD, VOICE_PAUSE)
	for k in given:
		_rest(rests, int(k), float(given[k]))
	var keys := rests.keys()
	keys.sort()
	keys.reverse()
	var out := text
	for k in keys:
		out = out.insert(int((ends[int(k)] as Dictionary)["end"]), " <!-- quiet: %s -->" % String.num(float(rests[k]), 1))
	return out


## A silence of [param s] seconds after word [param k] in [param rests], where it is worth one ([constant REST_LEAST]) and
## longer than one already there.
static func _rest(rests: Dictionary, k: int, s: float) -> void:
	if k >= 0 and s >= REST_LEAST:
		rests[k] = maxf(float(rests.get(k, 0.0)), s)


## Where each word the reading says ends in [param text] (`{end, stop, voice}`: the character after it, whether it ends a
## sentence, [constant SENTENCE], and who says it, lowercase), counted as [method CardReading.parse] counts them: the comments
## taken out first, so a word a comment is glued into is one word; a speaker's mark gives the words after it to that voice,
## and every passage (a table's mark) opens in the reader's.
static func _word_ends(text: String) -> Array:
	var from := text.length() - Manuscript.strip_frontmatter(text).length()
	var bare := ""
	var at := PackedInt32Array()          # each character of `bare`, where it is in `text`
	var turns: Array = []                 # [where in `bare` a voice begins, who]
	var speaker := RegEx.create_from_string(Manuscript.SPEAKER)
	var passage := RegEx.create_from_string("^<!--\\s*table\\s*:")
	var pos := from
	for m in Manuscript._rx(Manuscript.COMMENT).search_all(text, from):
		bare += text.substr(pos, m.get_start() - pos)
		for c in range(pos, m.get_start()):
			at.append(c)
		pos = m.get_end()
		var cue := speaker.search(m.get_string())
		if cue != null:
			turns.append([bare.length(), (cue.get_string(1) if not cue.get_string(1).is_empty() else cue.get_string(2)).to_lower()])
		elif passage.search(m.get_string()) != null:
			turns.append([bare.length(), Manuscript.NARRATOR.to_lower()])
	bare += text.substr(pos)
	for c in range(pos, text.length()):
		at.append(c)
	var stop := RegEx.create_from_string(SENTENCE)
	var out: Array = []
	var who := Manuscript.NARRATOR.to_lower()
	var turn := 0
	for m in RegEx.create_from_string("\\S+").search_all(bare):
		while turn < turns.size() and int(turns[turn][0]) <= m.get_start():
			who = String(turns[turn][1])
			turn += 1
		if TabletScript.norm(m.get_string()).is_empty():
			continue
		out.append({"end": at[m.get_end() - 1] + 1, "stop": stop.search(m.get_string()) != null, "voice": who})
	return out


## [param parsed] told who says each of its spoken words (`voices`) and whether it ends a sentence (`stops`), from the script's
## [param ends] ([method _word_ends]) - neither where they do not count the same words. Returns the voices.
static func _with_words(parsed: Dictionary, ends: Array) -> PackedStringArray:
	var voices := PackedStringArray()
	var stops: Array = []
	if ends.size() == (parsed.get("spoken", PackedStringArray()) as PackedStringArray).size():
		for e in ends:
			voices.append(String((e as Dictionary)["voice"]))
			stops.append(bool(e["stop"]))
	parsed["voices"] = voices
	parsed["stops"] = stops
	return voices


## A drawing's labels, in order: each `<text>`'s words, the marks inside it out; none left empty, as the ink step lays them
## out (hosts/math/figure.py).
static func _labels(svg: String) -> PackedStringArray:
	var out := PackedStringArray()
	var tag := RegEx.create_from_string("<[^>]*>")
	for m in RegEx.create_from_string("<text\\b[^>]*>([\\s\\S]*?)</text>").search_all(svg):
		var t := tag.sub(m.get_string(1), "", true).replace("&lt;", "<").replace("&gt;", ">").replace("&amp;", "&").strip_edges()
		if not t.is_empty():
			out.append(t)
	return out


## A formula's glyphs as its labels ([method PenPace.align]), in the order they are written: each glyph's label - what it
## is said as where it is a digit, a letter or a sign ([constant PenPace.SIGNS]), "" (not looked for) else - and where its
## ink begins (0 to 1).
static func _glyph_parts(sched: Dictionary) -> Array:
	var labels := PackedStringArray()
	var starts := PackedFloat32Array()
	var length := float(sched.get("length", 0.0))
	var seen := {}
	for st in sched.get("strokes", []) if length > 0.0 else []:
		var k := int((st as Dictionary).get("k", 0))
		if seen.has(k):
			continue
		seen[k] = true
		var name := String(st.get("name", ""))
		var digit := Ink.DIGITS.find(name)
		labels.append(str(digit) if digit >= 0 else (name if name.length() == 1 else String(PenPace.SIGNS.get(name, ""))))
		starts.append(float(st["t0"]) / length)
	return [labels, starts]


## Where each part's ink begins in [param sched] ([method Ink.schedule]), 0 to 1, in the order it is written: a drawing's
## labels ([param labels]: a label's glyphs share their thousand of `k`, a path's `k` is a whole thousand), else a hand's
## words (each its own `k`, [method SheetWriting.words]).
static func _part_starts(sched: Dictionary, labels: bool) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var length := float(sched.get("length", 0.0))
	if length <= 0.0:
		return out
	var seen := {}
	for st in sched.get("strokes", []):
		var k := int((st as Dictionary).get("k", 0))
		if labels and k % 1000 == 0:
			continue
		var part := k / 1000 if labels else k
		if seen.has(part):
			continue
		seen[part] = true
		out.append(float(st["t0"]) / length)
	return out


## A line TeX sets with words in it ([constant TableInk] `text` mode): its words, and where each one's ink is taken to begin (0
## to 1) by the letters before it shown on the page - TeX's glyphs are not grouped by word.
static func _text_parts(tex: String) -> Array:
	var words := PackedStringArray(tex.replace("\n", " ").split(" ", false))
	var marks := RegEx.create_from_string("\\\\[A-Za-z]+|[$&{}^_\\\\]")
	var shown := PackedInt32Array()
	var total := 0
	for w in words:
		shown.append(marks.sub(w, "", true).length())
		total += shown[shown.size() - 1]
	var starts := PackedFloat32Array()
	var at := 0
	for n in shown:
		starts.append(float(at) / float(maxi(total, 1)))
		at += n
	return [words, starts]


## A write's [param span] words from word [param after], ended at the last of them said by the voice that says word [param
## after] ([param voices], who says each; all of them where it has none).
static func _own_span(voices: PackedStringArray, after: int, span: int) -> int:
	if after < 0 or after >= voices.size() or span <= 1:
		return span
	var k := mini(after + span, voices.size()) - 1
	while k > after and voices[k] != voices[after]:
		k -= 1
	return k - after + 1


## The desk is seen whole first: the pen's first action begins no sooner than [constant DESK_SEEN] after the title has gone,
## and the camera's lead and the pick-up after that ([constant DeskMedium.CAM_LEAD], [constant DeskMedium.PICK_UP]).
func _first_floor() -> float:
	var opened := _opening()
	return opened + DESK_SEEN + CAM_LEAD + PICK_UP if opened < INF else -INF


## A write may begin as early as [constant PenPace.AHEAD_MOST] words before its own, the pen free: its way ([method
## _pen_way]) says when its ink does.
func _early(i: int) -> float:
	var a: Dictionary = _actions[i]
	var after := int(a.get("after", 0))
	var first := _word_t0(after)
	var soonest := _word_t0(maxi(after - int(PenPace.AHEAD_MOST), 0))
	if first == INF or soonest == INF:
		return 0.0
	return maxf(_due(i, first) - _lead_of(i) - soonest, 0.0)


## A write is done when its way is ([method _pen_way]), its words all heard; until they are, as the desk guesses - and never
## before its way has done what the words heard so far allow.
func _paced_end(i: int, start: float, end: float) -> float:
	var way := _pen_way(i, start)
	return maxf(float(way["done"]), start + 0.3) if bool(way.get("whole", false)) else maxf(end, float(way["done"]))


## How much of write [param i] is drawn now: its way's ([method _share]) - all of it once the plan has it done and the way
## has too, so no ink is put down at once.
func _written(i: int) -> float:
	if not (_actions[i] as Dictionary).has("map"):
		return super(i)
	return clampf(_share(i, _now), 0.0, 1.0)


## ...and again once a page turned for it has moved its start.
func _replanned_end(i: int, start: float, end: float) -> float:
	return _paced_end(i, start, end)


## How far through write [param i]'s ink its pen is now: on its way, which a plan made again starts where the pen was
## ([method _pen_way]) - nothing to catch up.
func _ink_time_now(i: int) -> float:
	if not (_actions[i] as Dictionary).has("map"):
		return super(i)
	return _length(i) * _share(i, _now)


## How far through write [param i] its pen is at [param t]: on its way ([method _pen_way]).
func _share(i: int, t: float) -> float:
	if not (_actions[i] as Dictionary).has("map"):
		return super(i, t)
	return PenPace.at(_pen_way(i, float(_plan[i]["start"])), t)


## Write [param i]'s way from [param start] ([method PenPace.path]): its map, its own words' times as heard (INF not yet),
## the words before its first, its ink and its quickest (a line of words' or a drawing's) - and, under way when the plan was
## made again ([member DeskMedium._held]), from where the pen was then. Kept for the plan it was made for.
func _pen_way(i: int, start: float) -> Dictionary:
	var held: Dictionary = _held.get(i, {})
	var drawn := 0.0
	if held.has("u") and held.has("at"):
		start = float(held["at"])
		drawn = float(held["u"])
	var kept: Dictionary = _ways.get(i, {})
	if int(kept.get("rev", -1)) == _plan_rev and float(kept.get("start", NAN)) == start:
		return kept["way"]
	var a: Dictionary = _actions[i]
	var own: PackedInt32Array = a.get("own", PackedInt32Array())
	var said: Array = []
	for k in own:
		var t0 := _word_t0(k)
		var t1 := _word_t1(k)
		said.append(Vector2(t0, t1) if t0 < INF and t1 < INF else Vector2(INF, INF))
	var before := PackedFloat32Array()
	var first := own[0] if not own.is_empty() else int(a.get("after", 0))
	for b in int(PenPace.AHEAD_MOST):
		before.append(_word_t0(first - 1 - b) if first - 1 - b >= 0 else INF)
	var way := PenPace.path(a.get("map", PackedVector2Array([Vector2.ZERO, Vector2(1.0, 1.0)])), said, before, _length(i), start,
		drawn, PenPace.PACE_MOST if String(a["kind"]) == "draw" else PenPace.PACE_MOST_WORDS)
	_ways[i] = {"rev": _plan_rev, "start": start, "way": way}
	return way


## A drawing is done with its words, as a line is ([method DeskMedium._build_plan]): an episode's words say what is drawn as
## it is drawn, and the talk after them is about what comes next, so the pen never draws on through it.
func _drawn_by(_i: int) -> float:
	return -INF


## The desk's number: the rows' [param rows] `seed` where they give one, else the episode's own.
func _desk_of(rows: Dictionary) -> int:
	return int(rows.get("seed", 0)) if int(rows.get("seed", 0)) > 0 else _hand


## The plan guesses a line done [constant LetterScript.AHEAD_WORDS] words before its last is said, as a letter's; where its
## pen is meanwhile is its way's ([method _pen_way]).
func _ahead() -> int:
	return LetterScript.AHEAD_WORDS


## The desk's look from its number [param desk] and what was chosen for it ([param picks]), dressed again when they changed.
func _set_look(picks: Dictionary, desk: int) -> void:
	if picks != _picks:
		_dressed = -1
	_picks = picks
	_seed = desk
	look = DeskLook.of(_seed, picks)
	_dress()


## Where beat [param beat] stands among an episode's: the intro, the beats by number, the close.
static func _beat_rank(beat: String) -> int:
	if beat == "intro":
		return 0
	if beat == "close":
		return CLOSE
	return int(beat) if beat.is_valid_int() else CLOSE - 1


## The first act's word after word [param after] in [param cue_si] (sorted), else [param n] (the last word's).
static func _next_cue(cue_si: Array, after: int, n: int) -> int:
	for si in cue_si:
		if int(si) > after:
			return int(si)
	return n


## Each of [param n] words' start in a steady voice, from the top: what the desk guesses a reading started mid-way by.
static func _steady(n: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for i in n:
		out.append(Openings.SETTLE + float(i) * DeskScript.SAID_WORD)
	return out


static func _json(path: String) -> Variant:
	if path.is_empty() or not FileAccess.file_exists(path):
		return null
	return JSON.parse_string(FileAccess.get_file_as_string(path))


static func _modified(path: String) -> int:
	return FileAccess.get_modified_time(path) if FileAccess.file_exists(path) else -1


# --- the camera ---------------------------------------------------------------------------------

func _local_frame() -> Dictionary:
	return EPISODE_LOCAL


func _wide_frame() -> Dictionary:
	return EPISODE_WIDE
