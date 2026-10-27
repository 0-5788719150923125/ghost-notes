extends Node

## A SHOW THAT DRAWS NO CARDS ON A MOUNTED TABLE (the user, 2026-10-26: "we should start with a mask every time
## - and just paint it while talking"; [method CardTable.cardless]): an episode staged from nowhere, built and
## played by the table as the show builds it - its things stood by [TableThings], its work scheduled from a
## reading that begins and opens each beat with `work K`.
##
##   tests/run_boot_probe.sh tests/table/table_cardless_check.gd 300
##
## - NOTHING OF A CARD'S STANDS: no deck, no card, no box, and no room kept clear for a spread - the middle of
##   the table is the work's, so a thing written there stands there, unmoved.
## - THE WORK RUNS IN ITS BEATS: every act kept (counted by beats, not cards), beat 1's after `work 1` begins,
##   beat 2's cued act at its word, the close's after the spread.
## - IT PLAYS THROUGH: posed from the first moment to past the last word, nothing of a card's is shown.
## - THE CONTROL: the same table and words with two cards drawn from a deck stands a deck, keeps the cards'
##   room clear and moves the thing written in the middle off it.
##
## A BOOT probe (the medium reaches the Director); no GPU - what is checked is where things are, never pixels.

const DIR := "user://table_cardless_check"
const LIVE := preload("res://tests/table/table_work_live_check.gd")

var medium: TableMedium
var subs: Subtitles
var _fails := 0


func _ready() -> void:
	_run.call_deferred()


func _ok(cond: bool, what: String) -> void:
	print(("  ok    " if cond else "  FAIL  ") + what)
	if not cond:
		_fails += 1


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	var stage := SubViewport.new()
	stage.size = Vector2i(640, 360)
	stage.own_world_3d = true
	add_child(stage)
	Director.detach()
	medium = Medium.make("table") as TableMedium
	medium.mount(stage)
	Director.attach(stage, medium)
	Director.hold(true)
	subs = preload("res://src/show/subtitles.gd").new()
	add_child(subs)
	medium.bind_captions(subs)
	_bare()
	_control()
	print("table_cardless_check: %s (%d failure%s)" % ["ALL OK" if _fails == 0 else "FAILED", _fails, "" if _fails == 1 else "s"])
	get_tree().quit(0 if _fails == 0 else 1)


## The bench of the work probe with a thing written in the very middle - a mask's stand, where a spread would lie.
static func _table() -> Dictionary:
	var t: Dictionary = LIVE._table().duplicate(true)
	(t["materials"] as Dictionary)["bisque"] = {"kind": "ceramic", "color": "#e8e2d6"}
	(t["things"] as Array).append({"name": "the mask", "at": [0, -6], "parts": [
		{"shape": "lathe", "profile": [[0, 0], [5, 0], [5, 1], [1.2, 2], [1.2, 18], [0, 18]], "material": "bisque"}]})
	return t


## The episode built over the bench with the work probe's acts: staged from nowhere when [param bare] (its two
## beats with work), else two cards drawn from a deck.
func _build(bare: bool) -> void:
	var f := FileAccess.open(DIR.path_join("table.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(_table()))
	f.close()
	var a := FileAccess.open(DIR.path_join("acts.json"), FileAccess.WRITE)
	a.store_string(JSON.stringify(LIVE._acts()))
	a.close()
	var positions := [{"name": "the base", "asks": "x", "work": "the ink is poured in"}, {"name": "the heart", "asks": "y", "work": "the herbs are ground"}]
	var plan := {"look": {"candles": 0}, "spread": {"positions": positions}, "work_close": "the brew glows",
		"staging": {"source": "none" if bare else "deck"}}
	var cards: Array = []
	if not bare:
		for i in 2:
			cards.append({"key": "c%d" % i, "name": "Card %d" % i, "numeral": str(i), "reversed": false, "jumper": false,
				"position": positions[i], "booklet": {}, "art": ""})
	var passages: Array = []
	for m in TableProducer.choreography(plan, cards):
		var say := String(m.get("say", ""))
		var text := "Some words said about it at an easy pace for a while, and then a few more words after that."
		if say == ("say:2" if bare else "say:work:2"):
			text = "Into the mortar they go and now we <!-- act: grind --> grind them slowly round and round, a little more, until they are fine."
		passages.append({"kind": m["kind"], "card": m.get("card", 0), "text": text if not say.is_empty() else ""})
	var script := CardReading.compose(passages)
	var doc := {"show": "table-cardless-check", "seed": 5, "dir": DIR, "plan": plan, "cards": cards, "deck_n": 0 if bare else 12}
	subs.words = load("res://tests/table/table_look_probe.gd").timeline(CardReading.parse(script), 0.36, Director.intro_hold)
	subs.document = {"source": script, "title": "Bare Check", "table": doc}
	medium._key = ""
	medium._ensure_doc()
	medium._follow.extend(subs.words)
	medium._sched = medium._follow.place(medium._plan.parse["actions"], maxf(Director.intro_hold, 0.6), TableMedium.LEAD, TableMedium.TAIL)
	medium._work.schedule(medium._sched, medium._plan.parse, medium._follow.said0, medium._follow.said1, medium._est, 0.0)


func _posed(t: float) -> void:
	medium._now = t
	medium._pose(t)
	medium._work.tick(t)
	medium._tick_air(t)


func _run_of(name: String) -> Dictionary:
	for r in medium._work.runs:
		if String((medium._work.acts[int((r as Dictionary)["i"])] as Dictionary)["name"]) == name:
			return r
	return {}


func _action_t0(kind: String, card := 0) -> float:
	for e in medium._sched:
		var a: Dictionary = (e as Dictionary)["a"]
		if String(a["kind"]) == kind and (card == 0 or int(a.get("card", 0)) == card):
			return float((e as Dictionary)["t0"])
	return INF


## Where the thing called [param name] stands on the table (meters, x z), or none.
func _stood(name: String) -> Variant:
	for th in medium._things_part.on_table:
		if String((th as Dictionary)["name"]) == name:
			var n: Node3D = (th as Dictionary)["node"]
			return Vector2(n.position.x, n.position.z)
	return null


func _bare() -> void:
	_build(true)
	_ok(medium._plan.cards_from == "none" and medium._plan.deck_n == 0, "it comes from nowhere and holds no deck (%s, %d)" % [medium._plan.cards_from, medium._plan.deck_n])
	_ok((medium._deck as Array).is_empty() and (medium._cards as Array).is_empty() and medium._box_part.stood.is_empty(),
		"no deck, card or box stands: %d, %d, %s" % [(medium._deck as Array).size(), (medium._cards as Array).size(), str(medium._box_part.stood.keys())])
	_ok(medium._things_part.off_limits().is_empty() and not medium._things_part.shuffle_rect().has_area(), "no room is kept clear for cards")
	_ok(not medium._things_part.blueprint().has("deck"), "its blueprint draws no deck")
	var mask: Variant = _stood("the mask")
	var written := Tables.ORIGIN + Vector2(0.0, -0.06)
	_ok(mask is Vector2 and (mask as Vector2).distance_to(written) < 0.005, "the thing written in the middle stands there: %s (written %s)" % [str(mask), str(written)])
	var w = medium._work
	_ok((w.acts as Array).size() == 4 and (w.notes as PackedStringArray).is_empty(), "every act is kept by its beat: %d, said against them: %s" % [(w.acts as Array).size(), "; ".join(w.notes)])
	_ok((w.runs as Array).size() == 4, "every act is scheduled: %d" % (w.runs as Array).size())
	var fetch := _run_of("fetch-jar")
	var grind := _run_of("grind")
	var close := _run_of("light-brew")
	_ok(not fetch.is_empty() and float(fetch["t0"]) >= _action_t0("work", 1) and float(fetch["t0"]) < INF, "beat 1's work begins after its `work 1`: %s, the mark %s" % [fetch.get("t0"), _action_t0("work", 1)])
	_ok(not close.is_empty() and float(close["t0"]) >= _action_t0("spread"), "the close's work begins after the spread")
	var cue_si := -1
	for c in medium._plan.parse.get("cues", []):
		if String((c as Dictionary)["name"]) == "grind":
			cue_si = int((c as Dictionary)["si"])
	_ok(cue_si >= 0 and not grind.is_empty() and absf(float(grind["t0"]) - float((subs.words[cue_si] as Dictionary)["t0"])) < 0.05,
		"beat 2's cued act starts at its word: %s" % grind.get("t0"))
	# PLAYED THROUGH: from the first moment past the last word, nothing of a card's is ever shown
	var end := float((subs.words[subs.words.size() - 1] as Dictionary)["t1"]) + 5.0
	var shown := 0
	var t := 0.0
	while t < end:
		_posed(t)
		for m in medium._cards:
			if (m as MeshInstance3D).visible:
				shown += 1
		if medium._page != null and (medium._page as Node3D).visible:
			shown += 1
		t += 1.7
	_ok(shown == 0, "played through to %.0f s, nothing of a card's is shown (%d)" % [end, shown])


func _control() -> void:
	_build(false)
	_ok(medium._plan.cards_from == "deck" and (medium._deck as Array).size() == 12 and (medium._cards as Array).size() == 2,
		"the control: two cards from a deck stand a deck of 12 and their cards (%s, %d, %d)" % [medium._plan.cards_from, (medium._deck as Array).size(), (medium._cards as Array).size()])
	_ok(not medium._things_part.off_limits().is_empty(), "the control: a deck's table keeps its cards' room clear")
	var mask: Variant = _stood("the mask")
	var written := Tables.ORIGIN + Vector2(0.0, -0.06)
	_ok(mask == null or (mask as Vector2).distance_to(written) > 0.01, "the control: the thing written in the cards' room is moved off it or left off: %s" % str(mask))
