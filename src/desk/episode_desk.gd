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
## and keeps with the words said from there to the next act's word - the old desk's dictation, its pen quicker or slower to
## keep with them, never past [constant DeskScript.MAX_PACE] and [constant DeskScript.MIN_PACE] of its own pace; an act with
## no word follows the one before, or begins its beat. A point is there at its word and held while it is talked about.
## Words with no math are written in their hand's strokes on the pad's rules ([method SheetWriting.words]); what TeX lays out
## is the episode's `ink.json` ([TableInk]), and a line not laid out yet is left unwritten.
##
## The desk is the Letter's ([DeskLook]): its things and mood the note's Medium card's where it chose them (the document's
## `medium`: `things`, `mood`), else drawn from the episode's seed. Its camera is the old desk's, a little closer
## ([constant EPISODE_LOCAL], [constant EPISODE_WIDE]): on the line being written, the whole pad as a page turns.

## The camera's close and wide framings (meters away, degrees above the desk).
const EPISODE_LOCAL := {"dist": 0.66, "pitch": 79.0}
const EPISODE_WIDE := {"dist": 1.1, "pitch": 75.0}
## The most words a write keeps with, and a point is held over, when the next act's word is further off.
const DICTATION_MOST := 40
const POINT_MOST := 24
## A beat's place in the episode, for the acts' order: the intro first, then the beats by number, the close last.
const CLOSE := 1000000

## What the episode wrote nothing for: lines TeX has not laid out, strikes and points at nothing - said once a load.
var notes := PackedStringArray()


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
	var key := "%s|%d|%d|%d|%d|%d|%s" % [dir, int(pay.get("seed", 0)), src.hash(), hash(rows), _modified(dir.path_join("acts.json")),
		_modified(dir.path_join("ink.json")), " ".join(start)]
	if key == _doc_key:
		return
	_doc_key = key
	load_episode(pay, src, rows, start, int(d.get("start_index", -1)))


## Load an episode: [param pay] (`{dir, seed, plan}`, [method TableEpisode.document]), its script [param src], the desk's
## rows [param rows] (`things`, `mood`); for a reading started mid-way its first words [param start] (normalized), [param
## near] the index they are about. Public for a gate, which hands it one by hand.
func load_episode(pay: Dictionary, src: String, rows := {}, start := PackedStringArray(), near := -1) -> void:
	_seed = int(pay.get("seed", 1))
	look = DeskLook.of(_seed, DeskLook.picks_of(rows))
	_dress()
	var dir := String(pay.get("dir", ""))
	var plan: Dictionary = pay.get("plan", {}) if pay.get("plan") is Dictionary else {}
	var parsed := CardReading.parse(src)
	var lesson := lesson_of(_json(dir.path_join("acts.json")), _json(dir.path_join("ink.json")), parsed,
		CardTable.beats(plan) if CardTable.cardless(plan) else 0, _seed)
	_records = lesson["records"]
	_strokes = lesson["strokes"]
	notes = lesson["notes"]
	for n in notes:
		push_warning("ghost: desk - %s" % n)
	_actions = DeskScript.lay_out(lesson["actions"], _records)
	var spoken: PackedStringArray = parsed.get("spoken", PackedStringArray())
	_begin(spoken, start, near, func() -> PackedFloat32Array: return _steady(spoken.size()))


## The desk's lesson from an episode, pure: the acts [param raw] (`acts.json` as parsed), TeX's layout [param ink]
## (`ink.json`), the script's walk [param parsed] ([method CardReading.parse]), how many beats the episode has ([param
## beats]) and the hand's [param seed]. `{actions (the desk's, not laid out yet: [method DeskScript.lay_out]), records (each
## written line's size, by id), strokes (each one's schedule, by id), notes}`.
static func lesson_of(raw: Variant, ink: Variant, parsed: Dictionary, beats: int, seed: int) -> Dictionary:
	var notes := PackedStringArray()
	var doc: Dictionary = ink if ink is Dictionary else {}
	var fonts: Dictionary = doc.get("fonts", {}) if doc.get("fonts") is Dictionary else {}
	var records := {}
	var strokes := {}
	var spoken: PackedStringArray = parsed.get("spoken", PackedStringArray())
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
					a["span"] = span
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
	return {"kind": "pad-text", "id": id, "tex": text, "write": float((strokes[id] as Dictionary)["length"])}


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
