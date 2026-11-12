extends SceneTree

## Does a table episode play at the desk ([EpisodeDesk]; next/desk.md) - its acts' writes and points the desk's actions, each
## at its act's word, laid on the pad - without a voice, an agent or a renderer? The episode is made here, in a folder of the
## gate's own: its acts, TeX's layout of them (the ink gate's fixture records, given the writes' ids) and a script with the
## reader's act marks. Each item names its control, which must fail the assertion.
##
## - The lesson ([method EpisodeDesk.lesson_of]): a formula, words in a hand, a point and a strike, in their beats' order; each
##   at its act's word and kept with the words to the next act's word; the strike crossing out the line its act names; the words
##   written in the hand's strokes. Controls: a write TeX has not laid out is said and left out; a strike at an act that wrote
##   nothing is said and left out.
## - The row: `desk` is a Medium row of Table's (`mode`), needing an episode, made as an [EpisodeDesk].
## - Played ([method EpisodeDesk.load_episode], words handed as a voice would): the formula begun as its word is said, the pen
##   on its ink while it is written; the point at the line its act names; the strike after the line it strikes. The pen lies at
##   its place beside the pad until it is picked up, and the pick-up is over before its first stroke begins. Control: as that
##   stroke begins, the pen is in hand, off its place.
## - The pen keeps ahead of the voice ([method EpisodeDesk._ahead]): a line is begun ahead of its word by the time its own first
##   words take to say, and done that much before its last is said. Control: a desk whose pen keeps no lead begins on its word.
## - The camera waits for the pen: wide through talk before the first stroke, though the episode has opened; close once the pen
##   writes (the control).
## - Dressed by the Desk's rows ([DeskFormat]; the document's `medium`): a number of their own is the desk's and its light the
##   one chosen, the hand still the episode's; chosen while it plays, the desk is dressed again and the episode not loaded
##   again. Control: rows with no number are the episode's own desk.
## - The episode keeps what it is shown in ([method TableEpisode.medium]): a plan naming the desk is at the desk, with no cloth,
##   room or depth to paint and its table made from the plan alone; the producer keeps the Medium card's format in the plan.
##   Controls: a plan naming no medium, or one no table plays, is at its table and paints its cloth and room. (The Medium
##   card's side of it, which needs the app: tests/media/medium_pick_check.gd.)
##
##   godot --headless --path . --script res://tests/desk/episode_desk_check.gd

const DIR := "user://episode_desk_check"


## What the desk reads a reading's document from (the Subtitles' `document`, which needs the app).
class Words extends Node:
	var document := {}

var _fails := 0
var _doc := {}


func _init() -> void:
	_doc = JSON.parse_string(FileAccess.get_file_as_string("res://tests/table/ink_layout.json"))
	_lesson()
	_row()
	_played()
	_framed()
	_kept()
	print("episode_desk_check: %s (%d failures)" % ["ALL OK" if _fails == 0 else "FAILED", _fails])
	quit(1 if _fails > 0 else 0)


func _ok(cond: bool, what: String) -> void:
	if not cond:
		_fails += 1
		print("  FAIL: " + what)


const TEX := "a^2 + b^2 = c^2"
const WORDS := "The question"
const SCRIPT := """<!-- table: begin -->

<!-- act: square --> First we write a squared plus b squared equals c squared, the rule for every right triangle.

<!-- act: label --> Then a heading for it, in plain words, so we know what we asked.

Look at this <!-- act: look --> line again, the one with the squares on it.

<!-- act: wrong --> That one was a dead end, so we cross it out and start fresh.
"""


func _acts(extra := []) -> Dictionary:
	var acts: Array = [
		{"name": "square", "beat": "intro", "tracks": [{"law": "write", "thing": "pad", "part": "page", "tex": TEX}]},
		{"name": "label", "beat": "intro", "tracks": [{"law": "write", "thing": "pad", "part": "page", "text": WORDS, "hand": "neat"}]},
		{"name": "look", "beat": "intro", "tracks": [{"law": "point", "thing": "pen", "on": "pad", "at": "square"}]},
		{"name": "wrong", "beat": "intro", "tracks": [{"law": "write", "thing": "pad", "part": "page", "strike": "square"}]},
	]
	acts.append_array(extra)
	return {"acts": acts}


## The ink step's answer for the formula: the fixture's own record, given the write's id.
func _ink() -> Dictionary:
	var it := TableInk.item("tex", TEX)
	var rec: Dictionary = {}
	for r in _doc["items"]:
		if String((r as Dictionary)["id"]) == "pyth":
			rec = (r as Dictionary).duplicate(true)
	rec["id"] = String(it["id"])
	return {"items": [rec], "fonts": _doc.get("fonts", {})}


func _kinds(actions: Array) -> PackedStringArray:
	var out := PackedStringArray()
	for a in actions:
		out.append(String((a as Dictionary)["kind"]))
	return out


func _lesson() -> void:
	var parsed := CardReading.parse(SCRIPT)
	var cue := {}
	for c in parsed["cues"]:
		cue[String((c as Dictionary)["name"])] = int(c["si"])
	var got := EpisodeDesk.lesson_of(_acts(), _ink(), parsed, 0, 3)
	var acts: Array = got["actions"]
	_ok(_kinds(acts) == PackedStringArray(["pad", "pad-text", "point", "strike"]),
		"a formula, words, a point and a strike, in order (%s)" % ", ".join(_kinds(acts)))
	if acts.size() < 4:
		return
	var at_cues := int(acts[0]["after"]) == int(cue["square"]) and int(acts[1]["after"]) == int(cue["label"]) \
		and int(acts[2]["after"]) == int(cue["look"]) and int(acts[3]["after"]) == int(cue["wrong"])
	_ok(at_cues, "each begins at its act's word")
	_ok(int(acts[0]["span"]) == int(cue["label"]) - int(cue["square"]), "a write keeps with the words to the next act's word (%d)" % int(acts[0]["span"]))
	_ok(int(acts[3]["of"]) == 0 and String(acts[2]["target"]) == "square", "the strike crosses out its act's line, and the point names it")
	var words: Dictionary = (got["strokes"] as Dictionary).get(String(acts[1]["id"]), {})
	var rec: Dictionary = (got["records"] as Dictionary).get(String(acts[1]["id"]), {})
	_ok(not (words.get("strokes", []) as Array).is_empty() and float(rec.get("w", 0.0)) > 10.0 and float(rec.get("h", 0.0)) > 3.0,
		"words in a hand are its strokes, with a size the pad lays them by (%d strokes, %.0f x %.0f pt)" % [(words.get("strokes", []) as Array).size(),
		float(rec.get("w", 0.0)), float(rec.get("h", 0.0)) + float(rec.get("d", 0.0))])
	var laid := DeskScript.lay_out(acts, got["records"])
	_ok(laid.size() == 4 and (laid[0] as Dictionary).has("at") and (laid[1] as Dictionary).has("at")
		and ((laid[1]["at"] as Vector2).y > (laid[0]["at"] as Vector2).y), "the pad lays the words under the formula")
	# Controls: what was never laid out, and a strike at nothing
	var unlaid := EpisodeDesk.lesson_of(_acts([{"name": "late", "beat": "intro", "tracks": [{"law": "write", "thing": "pad", "tex": "x^3"}]}]),
		_ink(), parsed, 0, 3)
	_ok((unlaid["actions"] as Array).size() == 4 and (unlaid["notes"] as PackedStringArray).size() == 1,
		"CONTROL: a write TeX has not laid out is said and left out (%s)" % ", ".join(unlaid["notes"]))
	var astray := EpisodeDesk.lesson_of(_acts([{"name": "stray", "beat": "intro", "tracks": [{"law": "write", "thing": "pad", "strike": "nobody"}]}]),
		_ink(), parsed, 0, 3)
	_ok((astray["actions"] as Array).size() == 4 and (astray["notes"] as PackedStringArray).size() == 1,
		"CONTROL: a strike at an act that wrote nothing is said and left out")


func _row() -> void:
	_ok(Medium.mode_of("desk") == "table" and (Registry.field(Medium.REGISTRY, "desk", "needs", []) as Array).has("episode")
		and not Medium.pickable().has("desk"), "the desk is Table's medium, needing an episode, never remembered as the setting")
	var m := Medium.make("desk")
	_ok(m is EpisodeDesk, "the desk row makes an EpisodeDesk")
	m.free()


func _played() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	var put := func(name: String, v: Variant) -> void:
		var f := FileAccess.open(DIR.path_join(name), FileAccess.WRITE)
		f.store_string(JSON.stringify(v))
		f.close()
	put.call("acts.json", _acts())
	put.call("ink.json", _ink())
	var feed := ShowFeed.new()
	feed.intro_hold = 1.0
	var m := EpisodeDesk.new()
	m.feed = feed
	m._pad = LegalPad.new()
	m.load_episode({"dir": DIR, "seed": 3, "plan": {}}, SCRIPT)
	var parsed := CardReading.parse(SCRIPT)
	var words: Array = []
	var spoken: PackedStringArray = parsed["spoken"]
	for i in spoken.size():
		var t0 := 2.0 + float(i) * 0.4
		words.append({"text": spoken[i], "t0": t0, "t1": t0 + 0.32})
	m._now = 0.0
	m.take_words(words)
	var cue := {}
	for c in parsed["cues"]:
		cue[String((c as Dictionary)["name"])] = int(c["si"])
	var start := float(m._plan[0]["start"])
	var said := float((words[int(cue["square"])] as Dictionary)["t0"])
	var lead := m._lead_of(0)
	_ok(lead > 0.5 and absf(start - (said - DeskMedium.PEN_LEAD - lead)) < 0.01,
		"the formula is begun ahead of its word by what its first words take to say (%.2f s, its word at %.2f, %.2f ahead)" % [start, said, lead])
	var level := Level.new()
	level.feed = feed
	level._pad = LegalPad.new()
	level.load_episode({"dir": DIR, "seed": 3, "plan": {}}, SCRIPT)
	level._now = 0.0
	level.take_words(words)
	var level_start := float(level._plan[0]["start"])
	_ok(absf(level_start - (said - DeskMedium.PEN_LEAD)) < 0.01, "CONTROL: a desk whose pen keeps no lead begins on its word (%.2f s)" % level_start)
	_ok(float(m._plan[0]["end"]) < float(level._plan[0]["end"]) - 0.5, "and the line is done before the voice has said it (%.2f s, the voice's %.2f)" % [
		float(m._plan[0]["end"]), float(level._plan[0]["end"])])
	level._pad.free()
	level.free()
	m._now = (start + float(m._plan[0]["end"])) * 0.5
	var nib := m.pen_at()
	var a: Dictionary = m._actions[0]
	var box := Rect2((a["at"] as Vector2).x - 4.0, (a["at"] as Vector2).y - float(a["h"]) - 4.0, float(a["w"]) + 8.0, float(a["h"]) + float(a["d"]) + 8.0)
	_ok(box.has_point(nib["p"]) and float(nib["lift"]) <= Pen.LIFT + 0.0001, "the pen is on the formula's ink while it is written (%s in %s)" % [str(nib["p"]), str(box)])
	# the pen lies at its place until it is picked up for its first stroke ([method DeskMedium._pick_up_pose])
	var pick := m._pick_up()
	m._now = pick.x
	var lying := m._lying(0)
	_ok(pick.x < INF and m._pen_xf().is_equal_approx(lying), "the pen lies at its place until it is picked up (from %.2f s)" % pick.x)
	_ok(pick.y <= start + 0.001, "the pick-up is over before the first stroke begins (%.2f s, the stroke at %.2f)" % [pick.y, start])
	m._now = start
	_ok(m._pen_xf().origin.distance_to(lying.origin) > 0.03, "CONTROL: as its first stroke begins, the pen is in hand, off its place")
	_ok(m.target_box(m._actions[2]).size.x > 0.0, "the point finds the line its act names")
	_ok(float(m._plan[3]["start"]) >= float(m._plan[0]["end"]), "the strike comes after the line it strikes")
	# the Desk's rows: its number and light, chosen
	var own_desk := m._seed
	var hand_was: Dictionary = (m._strokes as Dictionary).duplicate(true)
	m.load_episode({"dir": DIR, "seed": 3, "plan": {}}, SCRIPT, {"seed": 77, "mood": "dusk"})
	_ok(own_desk == 3 and m._seed == 77 and String(m.look["mood"]) == "dusk" and m._strokes == hand_was,
		"the rows' number is the desk's and their light the one chosen; the hand is still the episode's (desk %d, then %d)" % [own_desk, m._seed])
	# ...chosen while it plays: the desk dressed again, the episode as it was
	var subs := Words.new()
	subs.document = {"source": SCRIPT, "table": {"dir": DIR, "seed": 3, "plan": {}}, "medium": {"seed": 77, "mood": "dusk"}}
	m._subs = subs
	m._title = TitleCard.new()
	m._ensure_doc()
	var laid: Array = m._actions
	(subs.document["medium"] as Dictionary)["mood"] = "candlelight"
	(subs.document["medium"] as Dictionary)["seed"] = 0
	m._ensure_doc()
	_ok(String(m.look["mood"]) == "candlelight" and is_same(m._actions, laid),
		"a light chosen while it plays dresses the desk again, the episode not loaded again")
	_ok(m._seed == 3, "CONTROL: rows with no number are the episode's own desk (%d)" % m._seed)
	m._title.free()
	subs.free()
	m._pad.free()
	m.free()
	for f in ["acts.json", "ink.json"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(DIR.path_join(f)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(DIR))


## A desk whose pen writes each word as it is said, for the control.
class Level extends EpisodeDesk:
	func _ahead() -> int:
		return 0


## THE CAMERA WAITS FOR THE PEN: an opening said slowly before the first stroke is framed wide, though the episode has opened.
func _framed() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	for pair in [["acts.json", _acts()], ["ink.json", _ink()]]:
		var f := FileAccess.open(DIR.path_join(String(pair[0])), FileAccess.WRITE)
		f.store_string(JSON.stringify(pair[1]))
		f.close()
	var opening := "Hello and welcome, this is a long and easy opening before anything at all is written down.\n\n"
	var script := SCRIPT.replace("<!-- table: begin -->\n\n", "<!-- table: begin -->\n\n" + opening)
	var feed := ShowFeed.new()
	feed.intro_hold = 1.0
	var m := EpisodeDesk.new()
	m.feed = feed
	m._pad = LegalPad.new()
	m.load_episode({"dir": DIR, "seed": 3, "plan": {}}, script)
	var parsed := CardReading.parse(script)
	var spoken: PackedStringArray = parsed["spoken"]
	var first := 0
	for c in parsed["cues"]:
		if String((c as Dictionary)["name"]) == "square":
			first = int(c["si"])
	var words: Array = []
	var t := 2.0
	for i in spoken.size():
		words.append({"text": spoken[i], "t0": t, "t1": t + 0.3})
		t += 2.0 if i < first else 0.4
	m._now = 0.0
	m.take_words(words)
	var start := float(m._plan[0]["start"])
	m._now = 12.0
	var wide := float(m._framing()["k"])
	m._now = start + 0.5
	var close := float(m._framing()["k"])
	_ok(m._opening() < 12.0 and start > 20.0 and wide == 0.0, "the camera is wide through the talk before the first stroke (%.0f at 12 s, the stroke at %.1f s)" % [wide, start])
	_ok(close == 1.0, "CONTROL: once the pen writes, the camera is close (%.0f)" % close)
	m._pad.free()
	m.free()
	for f in ["acts.json", "ink.json"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(DIR.path_join(f)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(DIR))


func _kept() -> void:
	var was := TableEpisode.root
	TableEpisode.root = DIR
	var ep := TableEpisode.open("show", 5)
	var plan := {"staging": {"source": "none"}, "spread": {"positions": [{"name": "a"}]}, "medium": "desk"}
	ep.write_json("plan", plan)
	var desk_steps := ep.steps()
	_ok(ep.medium() == "desk" and ep.at_desk() and desk_steps.has("table") and not desk_steps.has("image:surface")
		and not desk_steps.has("image:backdrop") and ep.needs("table") == ["plan"],
		"a plan naming the desk is at the desk: its table made from the plan alone, nothing painted (%s)" % ", ".join(PackedStringArray(desk_steps)))
	plan.erase("medium")
	ep.write_json("plan", plan)
	var table_steps := ep.steps()
	_ok(ep.medium() == "table" and not ep.at_desk() and table_steps.has("image:surface") and ep.needs("table").has("image:backdrop"),
		"CONTROL: a plan naming no medium is at its table, its cloth and room painted")
	plan["medium"] = "letter"
	ep.write_json("plan", plan)
	_ok(ep.medium() == "table", "CONTROL: a medium no table plays is the table")
	var built: Array = CardTable.sanitize_table(DeskTable.spec(), {})["things"]
	_ok(built.size() == 2, "the desk's table stands: its pad and its pen (%d things)" % built.size())
	var producer := TableProducer.new(ep, {"medium": "desk"})
	var landed := {}
	producer._land_medium(landed)
	var stray := {}
	TableProducer.new(ep, {"medium": "comic"})._land_medium(stray)
	_ok(String(landed.get("medium", "")) == "desk" and String(stray.get("medium", "")) == "table",
		"the producer keeps the Medium card's format in the plan, and a format no table plays as the table (the control)")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ep.file_of("plan")))
	DirAccess.remove_absolute(ep.dir)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(DIR.path_join("show")))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(DIR))
	TableEpisode.root = was

