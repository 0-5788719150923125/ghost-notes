extends RefCounted
class_name SoundTimeline

## SoundTimeline - a composed Sound's score as the one [Timeline] (next/music.md, "The card"; next/editing.md): a group
## a section (its kind's name, on the song's clock), a lane a part - the drums a span a bar named by their pattern, a
## pitched part a span a chord, the voice a span each word sung - and the chord changes as flags in the group's own
## lane. Every item's `source` is a path into the note's `sound:` block, so what reads the timeline knows where a part
## is written. Pure: the score in, the Timeline out, every item on the `time` engine (shown at any moment at once).


## [param score] ([method Composer.score]) as a Timeline.
static func of(score: Dictionary) -> Dictionary:
	var groups: Array = []
	var beat := float(score.get("beat", 0.5))
	var start := float(score.get("start", 0.0))
	var meter := int(score.get("meter", Composer.METER))
	var sections: Array = score.get("sections", [])
	for i in sections.size():
		var s: Dictionary = sections[i]
		var g0 := float(s["start"])
		var g := Timeline.group("s%d" % i, String(s["label"]), g0, float(s["length"]), "time")
		var b0 := int(s["bar"])
		var b1 := b0 + int(s["bars"])
		for c in score.get("chords", []):
			var at_beat := int(c["bar"]) * meter + int(c["beat"])
			if int(c["bar"]) >= b0 and int(c["bar"]) < b1:
				Timeline.add(g, "", "", Timeline.item("chord%d_%d" % [int(c["bar"]), int(c["beat"])],
					MusicTheory.chord_name(int(c["root"]), String(c["quality"])), start + at_beat * beat - g0, 0.0, ["chords"]))
		for p in score.get("parts", []):
			var key := String(p["key"])
			if not (s["parts"] as Array).has(key) and not (key == "lead" and (s["parts"] as Array).has("vocal")):
				continue
			var label := Registry.label(SongParts.PARTS, key) + (" (muted)" if bool(p.get("mute", false)) else "")
			_part_spans(g, key, label, p, score, b0, b1, g0)
		var v: Dictionary = score.get("vocal", {})
		for ph in v.get("phrases", []):
			if int(ph["bar"]) < b0 or int(ph["bar"]) >= b1:
				continue
			var k := 0
			for w in ph["words"]:
				var notes: Array = w["notes"]
				var t0 := float(ph["at"]) + float(notes[0]["t"])
				var last: Dictionary = notes[notes.size() - 1]
				var t1 := float(ph["at"]) + float(last["t"]) + float(last["len"])
				var names := PackedStringArray()
				for n in notes:
					names.append(_note_name(float(n["midi"])))
				Timeline.add(g, "vocal", Registry.label(SongParts.PARTS, "vocal"), Timeline.item(
					"w%d_%d" % [int(ph["bar"]), k], "%s  %s" % [String(w["text"]), " ".join(names)], t0 - g0, maxf(t1 - t0, 0.05),
					["parts", "vocal"]))
				k += 1
		groups.append(g)
	return Timeline.make("song", groups)


## A part's spans in bars [param b0]..[param b1]: the drums' bars, a pitched part's chords.
static func _part_spans(g: Dictionary, key: String, label: String, p: Dictionary, score: Dictionary, b0: int, b1: int, g0: float) -> void:
	var beat := float(score["beat"])
	var start := float(score["start"])
	var meter := int(score.get("meter", Composer.METER))
	if key == "drums":
		for b in range(b0, b1):
			Timeline.add(g, key, label, Timeline.item("%s%d" % [key, b], Registry.label(SongParts.PATTERNS, String(p.get("pattern", ""))),
				start + b * meter * beat - g0, meter * beat * 0.98, ["parts", key]))
		return
	var chords: Array = score.get("chords", [])
	var bounds: Array = []
	for c in chords:
		var at := int(c["bar"]) * meter + int(c["beat"])
		if at >= b0 * meter and at < b1 * meter:
			bounds.append({"at": at, "name": MusicTheory.chord_name(int(c["root"]), String(c["quality"]))})
	if bounds.is_empty() or int(bounds[0]["at"]) > b0 * meter:
		var before := ""
		for c in chords:
			if int(c["bar"]) * meter + int(c["beat"]) <= b0 * meter:
				before = MusicTheory.chord_name(int(c["root"]), String(c["quality"]))
		bounds.push_front({"at": b0 * meter, "name": before})
	for i in bounds.size():
		var a := int(bounds[i]["at"])
		var e := int(bounds[i + 1]["at"]) if i + 1 < bounds.size() else b1 * meter
		Timeline.add(g, key, label, Timeline.item("%s%d" % [key, a], "%s  %s" % [Registry.label(SongParts.PATTERNS, String(p.get("pattern", ""))),
			String(bounds[i]["name"])], start + a * beat - g0, maxf((e - a) * beat * 0.98, 0.05), ["parts", key]))


static func _note_name(midi: float) -> String:
	var m := int(round(midi))
	return "%s%d" % [MusicTheory.NAMES[posmod(m, 12)], floori(m / 12.0) - 1]


## What the dock's inspector shows of a picked item ([member TimelineDock.inspector]): what it is, where it is, and
## where in the note it is written.
static func inspect(what: Dictionary, box: VBoxContainer) -> void:
	var it: Dictionary = what.get("item", {})
	var g: Dictionary = what.get("group", {})
	if it.is_empty():
		return
	var lines := PackedStringArray([String(it.get("label", "")),
		"%s, %s in" % [String(g.get("label", "")), Clock.text(float(it.get("at", 0.0)))]])
	if float(it.get("length", 0.0)) > 0.0:
		lines.append("for %.2f s" % float(it["length"]))
	var src: Array = it.get("source", [])
	if not src.is_empty():
		lines.append("written in sound: %s" % ".".join(PackedStringArray(src.map(func(x: Variant) -> String: return str(x)))))
	for t in lines:
		var l := Label.new()
		l.text = t
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.add_theme_font_size_override("font_size", 12)
		box.add_child(l)
