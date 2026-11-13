extends SceneTree

## timeline_check - one document for what a show does when ([Timeline]; next/editing.md, "The Timeline").
##
##   godot --headless --path . --script res://tests/scene_kit/timeline_check.gd
##
## What it holds:
##   - The check: a timeline made by the contract's own hands has no problems; the control is one with a clock, a kind
##     and an engine that have no row and an item outside its group, each named.
##   - A storyboard read as one (data/showcase.json, the demo note's): a group per entry, at the times the
##     Director's schedule gives; the first entry's blue prism a lane, its `arrive` a span scaled into the entry's
##     seconds; every span's `source` the span it was read from, and a flag's the key; every span a `verb` (a
##     simulation, reached by playing from the start - the control for seeking, as a flag is seekable); and it
##     survives JSON whole.
##   - An episode read as one (a cardless fixture under its own root, never the author's): the intro, each beat and
##     the close a group; an act a span on the `time` engine (seekable) in its thing's lane, found under way at a
##     moment inside it; a cue a flag at the word it stands before; a beat with acts and no words as long as its acts;
##     its problems, as `--episode-check` prints them, none for it as made - the control a cue naming nothing and data
##     that does not parse, each said.

const ROOT := "user://timeline_check"

var _fails := 0


func _init() -> void:
	_contract()
	_storyboard()
	_episode()
	TableEpisode.root = TableEpisode.ROOT
	if _fails == 0:
		print("timeline_check: ALL OK")
		quit(0)
		return
	print("timeline_check: %d FAILED" % _fails)
	quit(1)


func _contract() -> void:
	var g := Timeline.group("a", "A", 0.0, 4.0, "time")
	Timeline.add(g, "x", "X", Timeline.item("one", "One", 1.0, 2.0, ["acts", 0]))
	Timeline.add(g, "x", "X", Timeline.item("cue", "Cue", 3.0, 0.0, ["say", "cue", 0], "verb"))
	var tl := Timeline.make("voice", [g])
	_ok(Timeline.check(tl).is_empty() and float(tl["length"]) == 4.0, "a timeline made by the contract has no problems: %s" % ", ".join(Timeline.check(tl)))
	_ok(((g["lanes"] as Array)[0]["items"] as Array).size() == 2 and (g["lanes"] as Array).size() == 1, "two items in one lane, named once")
	var bad := {"clock": "tides", "groups": [{"id": "b", "start": 0.0, "length": 1.0, "engine": "dream",
		"lanes": [{"id": "", "items": [{"id": "z", "kind": "blob", "at": 5.0, "length": 0.0}]}]}]}
	var said := " ".join(Timeline.check(bad))
	_ok(said.contains("tides") and said.contains("dream") and said.contains("blob") and said.contains("outside its group"),
		"the control: a clock, an engine and a kind with no row and an item outside its group are each named: %s" % said)


func _storyboard() -> void:
	var raw: Dictionary = Storyboard.read_raw("res://data/showcase.json")["data"]
	var tl := Storyboard.timeline(raw)
	var seq: Array = raw["sequence"]
	var sched := Storyboard.schedule(Storyboard.expanded(seq, raw.get("defs", {})), float(raw.get("sensitivity", 1.0)), 8.0)
	var groups: Array = tl["groups"]
	_ok(String(tl["clock"]) == "song" and groups.size() == seq.size(), "a group per entry, on the song's clock (%d of %d)" % [groups.size(), seq.size()])
	var starts_ok := true
	for i in groups.size():
		starts_ok = starts_ok and is_equal_approx(float(groups[i]["start"]), float(sched["starts"][i]))
	_ok(starts_ok, "each group starts where the Director's schedule starts its entry")
	var first: Dictionary = groups[0]
	var blue: Dictionary = {}
	for l in first["lanes"]:
		if String(l["id"]) == "blue":
			blue = l
	var arrive: Dictionary = {}
	for it in blue.get("items", []):
		if String((it as Dictionary).get("label", "")) == "arrive":
			arrive = it
	var written: Dictionary = {}
	for sp in seq[0]["track"]["spans"]:
		if String((sp as Dictionary).get("action", "")) == "arrive":
			written = sp
	var scale := float(first["length"]) / float(seq[0]["track"]["nominal"])
	var t0 := float(written.get("from", written.get("at", -1.0)))
	var t1 := float(written.get("to", t0))
	_ok(not written.is_empty() and String(arrive.get("kind", "")) == "span" and t1 > t0
		and is_equal_approx(float(arrive.get("at", -1.0)), t0 * scale) and is_equal_approx(float(arrive.get("length", -1.0)), (t1 - t0) * scale),
		"the first entry's blue prism is a lane, its arrive a span in the entry's seconds: %s (written %s)" % [str(arrive), str(written)])
	var sources_ok := true
	var all_verbs := true
	var flags_seek := true
	var spans := 0
	for g in groups:
		for l in g["lanes"]:
			for it in l["items"]:
				var written_at: Variant = DataPath.at(raw, it["source"])
				# a flag ([StageKeys]) is a key of the track's, on the `time` engine: seekable
				if (it["source"] as Array).has("keys"):
					flags_seek = flags_seek and written_at is Dictionary and Timeline.seekable(g, it)
					continue
				spans += 1
				sources_ok = sources_ok and written_at is Dictionary and String((written_at as Dictionary).get("action", "")) == String(it["label"])
				all_verbs = all_verbs and not Timeline.seekable(g, it)
	_ok(spans > 0 and sources_ok, "every span's source is the span it was read from (%d spans)" % spans)
	_ok(flags_seek, "...and every flag's the key it was read from, seekable")
	_ok(all_verbs, "the control for seeking: a stage's spans are simulations, reached by playing from the start")
	_ok(Timeline.check(tl).is_empty(), "the storyboard's timeline has no problems: %s" % ", ".join(Timeline.check(tl)))
	_ok(DataPath.same(JSON.parse_string(JSON.stringify(tl)), tl), "it survives JSON whole")


func _episode() -> void:
	TableEpisode.root = ROOT
	var ep := TableEpisode.open("timeline-show", 7)
	_rmrf(ep.dir)
	var positions := [{"name": "The Hook", "work": "the base is laid on"}, {"name": "The Turn"}]
	ep.write_json("plan", {"episode_title": "T", "spread": {"name": "", "positions": positions}, "staging": {"source": "none"},
		"look": CardTable.sanitize_look({})})
	ep.write_text("say:intro", "We begin.")
	ep.write_text("say:1", "One two three <!-- act: base --> four five.")
	ep.write_json("acts", {"acts": [{"name": "base", "beat": "1", "length": 8.0, "tracks": [{"law": "to", "thing": "sponge"}]},
		{"name": "wipe", "beat": "2", "length": 5.0, "tracks": [{"law": "to", "thing": "towel"}]}]})
	var tl := ep.timeline()
	var groups: Array = tl["groups"]
	_ok(String(tl["clock"]) == "voice" and groups.map(func(g: Dictionary) -> String: return String(g["id"])) == ["intro", "1", "2", "close"],
		"the intro, each beat and the close a group, on the voice's clock: %s" % str(groups.map(func(g: Dictionary) -> String: return String(g["id"]))))
	var beat1: Dictionary = groups[1]
	var sponge: Dictionary = {}
	var words: Dictionary = {}
	for l in beat1["lanes"]:
		if String(l["id"]) == "sponge":
			sponge = (l["items"] as Array)[0]
		if String(l["id"]) == "words":
			words = (l["items"] as Array)[0]
	_ok(String(sponge.get("label", "")) == "base" and Timeline.seekable(beat1, sponge) and DataPath.same(sponge["source"], ["acts", 0]),
		"an act is a seekable span in its thing's lane, its source its place in acts.json: %s" % str(sponge))
	var under := Timeline.at_time(tl, float(beat1["start"]) + 4.0)
	_ok(under.any(func(h: Dictionary) -> bool: return String((h["item"] as Dictionary)["label"]) == "base"), "an act is found under way at a moment inside it")
	_ok(String(words.get("kind", "")) == "flag" and is_equal_approx(float(words.get("at", -1.0)), 3.0 * TablePrompts.SAID_WORD),
		"a cue is a flag at the word it stands before: %s" % str(words))
	_ok(is_equal_approx(float(groups[2]["length"]), 5.0), "a beat with acts and no words is as long as its acts")
	_ok(Timeline.check(tl).is_empty() and (tl["problems"] as PackedStringArray).is_empty(), "the episode's timeline has no problems: %s" % ", ".join(Timeline.check(tl)))
	_ok(ep.problems().is_empty(), "the episode's problems, as --episode-check prints them: none (%s)" % ", ".join(ep.problems()))
	ep.write_text("say:2", "And then <!-- act: gone --> more.")
	var said := " ".join(ep.timeline()["problems"])
	_ok(said.contains("gone") and said.contains("starts nothing") and " ".join(ep.problems()).contains("gone"),
		"the control: a cue naming no act and no layer is a problem said, on the timeline and in the episode's list: %s" % said)
	var f := FileAccess.open(ep.file_of("table"), FileAccess.WRITE)
	f.store_string("{ broken")
	f.close()
	_ok(" ".join(ep.problems()).contains("table.json does not parse"), "a step's data that does not parse is a problem said")
	# The take kept (next/editing.md step 3): kept with the script it was said from, it matches until the script changes
	# (the control), and the table's words take its times, aligned as a render's follower aligns them, a word it does not place keeping its guess
	ep.write_text("script", "<!-- table: work 1 -->\n\nOne two three.\n")
	var scratch := ProjectSettings.globalize_path(ROOT).path_join("rendered.wav")
	var wf := FileAccess.open(scratch, FileAccess.WRITE)
	wf.store_string("RIFF")
	wf.close()
	var sf := FileAccess.open(scratch.get_basename() + ".json", FileAccess.WRITE)
	sf.store_string(JSON.stringify({"words": [{"text": "One", "t0": 4.0, "t1": 4.3}, {"text": "two", "t0": 4.4, "t1": 4.7}], "bookend": {"in": 3.0, "out": 1.0},
		"sig": "as-said"}))
	sf.close()
	_ok(ep.keep_take(scratch).is_empty() and ep.take_matches() and is_equal_approx(ep.take_length(), 5.7), "a take kept matches the script it was said from (%.1f s)" % ep.take_length())
	_ok(ep.take_matches("as-said") and not ep.take_matches("other-voices"),
		"it matches the voices it was said in (ReadingPanel.take_sig) - the control: said in others, it does not")
	ep.write_text("script", "<!-- table: work 1 -->\n\nOne two three, again.\n")
	_ok(not ep.take_matches(), "the control: the script changed since, the take no longer matches")
	var times := TablePlan.take_times(PackedStringArray(["one", "two", "three"]), PackedFloat32Array([1.0, 2.0, 3.0]),
		[{"text": "One", "t0": 4.0, "t1": 4.3}, {"text": "two", "t0": 4.4, "t1": 4.7}])
	_ok(is_equal_approx(times[0], 4.0) and is_equal_approx(times[1], 4.4) and times[2] > 4.4,
		"the table's words take the take's times; a word it does not place is spaced after them: %s" % str(times))
	_ok(TablePlan.take_times(PackedStringArray(["one"]), PackedFloat32Array([1.0]), []) == PackedFloat32Array([1.0]), "no take, the guess")
	_rmrf(ProjectSettings.globalize_path(ROOT))


func _rmrf(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for d in DirAccess.get_directories_at(path):
		_rmrf(path.path_join(d))
	for f in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(f))
	DirAccess.remove_absolute(path)


func _ok(cond: bool, msg: String) -> void:
	print(("  ok    " if cond else "  FAIL  ") + msg)
	if not cond:
		_fails += 1
