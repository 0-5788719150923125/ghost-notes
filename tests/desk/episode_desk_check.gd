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
## - A strike crosses out every row of what TeX wrapped ([method Desk._struck_path]): one stroke through a line, a stroke
##   left to right through each row of a block (the pen lifted between), a subscript never a row of its own. Control: a one-row record has one stroke.
## - The row: `desk` is a Medium row of Table's (`mode`), needing an episode, made as an [EpisodeDesk].
## - Played ([method EpisodeDesk.load_episode], words handed as a voice would): the formula begun as its word is said, the pen
##   on its ink while it is written; the point at the line its act names; the strike after the line it strikes. The pen lies at
##   its place beside the pad until it is picked up, and the pick-up is over before its first stroke begins. Control: as that
##   stroke begins, the pen is in hand, off its place.
## - The pen keeps with the voice ([method EpisodeDesk._pen_way], [PenPace]): a write may be begun as early as [constant
##   PenPace.AHEAD_MOST] words before its word, and as its words are said its pen is never behind one, never more than that
##   ahead and never past its quickest ([method PenPace.audit]). Control: a pen drawn evenly over its words, not matched to
##   them, falls behind.
## - The camera waits for the pen: wide through talk before the first stroke, though the episode has opened; close once the pen
##   writes (the control).
## - A drawing keeps with its words: done with them (control: a desk that draws on at the hand's pace ends past them); they end
##   at its own voice's last before the next act's word (control: told no one's voices, they run on to it); another voice's
##   line among them is none of its own (control: told no one's voices, every word is). The voice waits for the pen ([method
##   EpisodeDesk.voiced]): for a drawing denser than its words, at sentence ends only and never past [constant
##   PenPace.REST_MOST]; and before the words of a write a page is turned for. Controls: where the pen keeps up, a script voiced
##   already (its silences counted) and a drawing that fits under what is on the page each leave the script as it was.
## - The desk is seen whole first ([method EpisodeDesk._first_floor]): a write at the first word begins only after the desk has
##   been seen for [constant EpisodeDesk.DESK_SEEN], the camera wide till then (control: a desk with no floor begins on its
##   word). The hand settles through a long wait ([method DeskMedium._settled]): on the page beside where it stopped (control:
##   before a page turns it leaves the pad), the nib low and its drift nearly gone, readjusting its hold now and then and still
##   between ([method Pen.readjust]; control: a held pen's sway never stops), lifted again before it sets off (control: a
##   short wait is waited out held up).
## - Live, nothing runs on words not said yet ([method EpisodeDesk._pen_way]: a word not heard has no time): handed a sentence
##   at a time, through a pause before the next arrives the pen is no further on than with every word's time known (control: a
##   desk guessing unheard words a steady [constant DeskScript.EST_WORD] apart from the last heard runs on).
## - THE PEN IS NEVER BEHIND THE VOICE: a drawing's labels are matched to the words naming them ([method PenPace.align]); one
##   too dense for its words is given a rest at the sentence end before it would fall behind, and played with it the pen is
##   never more than [constant PenPace.LAG_OK] behind (control: played without it, it is). How a pen is matched, paced and
##   rested with no desk: tests/desk/pen_pace_check.gd.
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
	_struck()
	_row()
	_played()
	_framed()
	_paced()
	_pinned()
	_seen_first()
	_settles()
	_live()
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


func _struck() -> void:
	var rows := [[0.0, 0.0, 200.0], [0.0, 210.0, 230.0], [3.0, 40.0, 46.0], [14.5, 0.0, 120.0], [29.0, 0.0, 60.0]]
	var glyphs: Array = []
	for r in rows:
		glyphs.append({"y": r[0], "x": r[1], "w": float(r[2]) - float(r[1])})
	var m := EpisodeDesk.new()
	m._pad = LegalPad.new()
	var write := {"kind": "pad-text", "id": "r", "at": Vector2(100.0, 200.0), "k": 1.0, "w": 230.0, "h": 8.0, "d": 40.0}
	m._records = {"r": {"glyphs": glyphs}, "one": {"glyphs": glyphs.slice(0, 2)}}
	m._actions = [write, {"kind": "strike", "of": 0, "write": 1.0}, (write.duplicate() as Dictionary).merged({"id": "one"}, true),
		{"kind": "strike", "of": 2, "write": 1.0}]
	var path := m._struck_path(m._actions[1])
	_ok(path.size() == 6, "a block of three rows is crossed out row by row, its subscript no row (%d points)" % path.size())
	_ok(path.size() == 6 and path[1].y < path[2].y and path[3].y < path[4].y and path[0].x < path[1].x and path[2].x < path[3].x
		and path[4].x < path[5].x, "each row is its own stroke, left to right, the rows taken top down")
	_ok(m._struck_path(m._actions[3]).size() == 2, "CONTROL: a record of one row is one stroke")
	var half := EpisodeDesk._along(path, 0.5)
	_ok(half.size() < path.size() and half[half.size() - 1].y < path[path.size() - 1].y, "part of the way, only the first rows are drawn")
	m._pad.free()
	m.free()


func _row() -> void:
	_ok(Medium.mode_of("desk") == "table" and (Registry.field(Medium.REGISTRY, "desk", "needs", []) as Array).has("episode")
		and not Medium.pickable().has("desk"), "the desk is Table's medium, needing an episode, never remembered as the setting")
	var m := Medium.make("desk")
	_ok(m is EpisodeDesk, "the desk row makes an EpisodeDesk")
	m.free()


func _played() -> void:
	# (an opening of its own: the desk is seen first, so a write at the first word waits for it - _seen_first)
	var script := SCRIPT.replace("<!-- table: begin -->\n\n", "<!-- table: begin -->\n\n" + OPENING + "\n\n")
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
	m.load_episode({"dir": DIR, "seed": 3, "plan": {}}, script)
	var parsed := CardReading.parse(script)
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
	var soonest := float((words[int(cue["square"]) - int(PenPace.AHEAD_MOST)] as Dictionary)["t0"])
	_ok(absf(start - soonest) < 0.01, "a write may be begun as early as %d words before its word, the pen free (%.2f s, its word at %.2f)" % [
		int(PenPace.AHEAD_MOST), start, said])
	var kept := _audit_of(m, 0, words)
	_ok(float(kept["behind"]) <= 0.1 and float(kept["ahead"]) <= PenPace.AHEAD_MOST + 0.1 and float(kept["fastest"]) <= PenPace.PACE_MOST_WORDS + 0.05,
		"as its words are said its pen is never behind one, never more than %d ahead, never past its quickest (behind %.2f s, ahead %.1f words, fastest %.1f)" % [
		int(PenPace.AHEAD_MOST), kept["behind"], kept["ahead"], kept["fastest"]])
	# ...a pen drawn evenly over its words, the same ink and words
	var plain := EpisodeDesk.new()
	plain.feed = feed
	plain._pad = LegalPad.new()
	plain.load_episode({"dir": DIR, "seed": 3, "plan": {}}, script)
	var map: PackedVector2Array = (m._actions[0] as Dictionary)["map"]
	(plain._actions[0] as Dictionary)["map"] = PackedVector2Array([Vector2.ZERO, Vector2(float(((m._actions[0] as Dictionary)["own"] as PackedInt32Array).size()), 1.0)])
	plain._now = 0.0
	plain.take_words(words)
	var even := _audit_of(plain, 0, words, map)
	_ok(float(even["behind"]) > 1.0, "CONTROL: a pen drawn evenly over its words, not matched to them, falls behind (%.2f s)" % even["behind"])
	plain._pad.free()
	plain.free()
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
	m.load_episode({"dir": DIR, "seed": 3, "plan": {}}, script, {"seed": 77, "mood": "dusk"})
	_ok(own_desk == 3 and m._seed == 77 and String(m.look["mood"]) == "dusk" and m._strokes == hand_was,
		"the rows' number is the desk's and their light the one chosen; the hand is still the episode's (desk %d, then %d)" % [own_desk, m._seed])
	# ...chosen while it plays: the desk dressed again, the episode as it was
	var subs := Words.new()
	subs.document = {"source": script, "table": {"dir": DIR, "seed": 3, "plan": {}}, "medium": {"seed": 77, "mood": "dusk"}}
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


const GRID_SVG := "<svg viewBox=\"0 0 200 100\"><path d=\"M0 0 L200 0\"/></svg>"
const TALL_SVG := "<svg viewBox=\"0 0 200 360\"><path d=\"M0 0 L200 0\"/></svg>"
const GRID_WORDS := "We draw a grid of lines, one under another, down the page, each as long as the last. That keeps the count."
const OPENING := "Good morning, and welcome to the desk. Today we look at one small idea, slowly, with a pen and a pad, and nothing else on the table but a cup of tea and the light from the window over the garden, which is green and quiet at this hour, and we take our time with it, as we always do here, one line after another."
const PACED := """<!-- table: begin -->

%s

<!-- act: grid --> We draw a grid of lines, one under another, down the page, each as long as the last. That keeps the count.

<!-- speaker: Ink -->
Why lines?
<!-- speaker: Narrator -->
<!-- act: label --> Then a heading for it, in plain words, so we know what we asked.
""" % OPENING
const ASIDE := """<!-- table: begin -->

%s

<!-- act: grid --> We draw a grid of lines, one under another, down the page, each as long as the last. That keeps the count.

<!-- speaker: Ink -->
Why lines?
<!-- speaker: Narrator -->
Because a line is the easiest thing to draw by hand.

<!-- act: label --> Then a heading for it, in plain words, so we know what we asked.
""" % OPENING
const TURNED := """<!-- table: begin -->

%s

<!-- act: square --> First we write a squared plus b squared equals c squared.

<!-- act: tall --> Then a tall drawing, down the whole of the next page.
""" % OPENING
const PINNED_SVG := "<svg viewBox=\"0 0 200 100\"><text x=\"0\" y=\"10\">tape</text><path d=\"M0 20 L200 20\"/><text x=\"0\" y=\"60\">head</text><path d=\"M0 80 L200 80\"/></svg>"
const PINNED := """<!-- table: begin -->

%s

<!-- act: tape --> First the tape, a long row of squares. Then the head, a small arrow under it. That is all.
""" % OPENING


## A drawing's record as the ink step lays one out: [param lines] ruled lines across a box [param h] TeX points tall.
func _figure(svg: String, lines: int, h := 100.0) -> Dictionary:
	var paths: Array = []
	for j in lines:
		var y := -h + h * float(j) / float(maxi(lines - 1, 1))
		paths.append({"k": 1000.0 * float(j + 1), "kind": "line", "pts": [[0.0, y], [200.0, y]]})
	return {"id": String(TableInk.item("draw", svg)["id"]), "ok": true, "figure": true, "w": 200.0, "h": h, "d": 0.0,
		"glyphs": [], "paths": paths, "rules": [], "anchors": {}}


## A labeled drawing's record: the label "tape" and [param tape] lines under it, then "head" and [param head] lines.
func _pinned_figure(tape: int, head: int) -> Dictionary:
	var glyphs: Array = []
	var paths: Array = []
	var k := 0
	for part in [["tape", tape], ["head", head]]:
		var word := String(part[0])
		for c in word.length():
			glyphs.append({"c": word.unicode_at(c), "dp": 0.0, "f": "cmr12", "ht": 5.3, "k": k * 1000 + c + 1,
				"n": word[c], "s": 12.0, "w": 5.4, "x": 6.0 * float(c), "y": -60.0 if word == "tape" else -20.0})
		k += 1
		for j in int(part[1]):
			paths.append({"k": k * 1000, "kind": "line", "pts": [[0.0, -50.0 + float(j)], [200.0, -50.0 + float(j)]]})
			k += 1
	return {"id": String(TableInk.item("draw", PINNED_SVG)["id"]), "ok": true, "figure": true, "w": 200.0, "h": 100.0,
		"d": 0.0, "glyphs": glyphs, "paths": paths, "rules": [], "anchors": {}}


## THE PEN IS NEVER BEHIND THE VOICE: a drawing's labels are matched to the words naming them, and one too dense for its words
## is given a rest at the sentence end before it would fall behind.
func _pinned() -> void:
	var tape := {"name": "tape", "beat": "intro", "tracks": [{"law": "write", "thing": "pad", "part": "page", "draw": PINNED_SVG}]}
	_put({"acts": [tape]}, {"items": [_pinned_figure(6, 2)], "fonts": {}})
	var spoken: PackedStringArray = CardReading.parse(PINNED)["spoken"]
	var m := EpisodeDesk.new()
	_playing(m, PINNED, EpisodeDesk.VOICE_WORD, EpisodeDesk.VOICE_PAUSE)
	var a: Dictionary = m._actions[0]
	var own: PackedInt32Array = a["own"]
	var starts := EpisodeDesk._part_starts(m._strokes[String(a["id"])], true)
	var map: PackedVector2Array = a["map"]
	var head := PenPace.on_map(map, float(spoken.find("head") - own[0]))
	_ok(starts.size() == 2 and PenPace.on_map(map, float(spoken.find("tape") - own[0])) <= starts[0] + 0.01 and absf(head - starts[1]) < 0.01,
		"a drawing's labels are matched to the words naming them (the head's ink from %.2f, %.2f at its word)" % [starts[1] if starts.size() == 2 else -1.0, head])
	m._pad.free()
	m.free()
	var voiced := EpisodeDesk.voiced(PINNED, {"dir": DIR, "seed": 3, "plan": {}})
	var quiets: Array = CardReading.parse(voiced)["quiets"]
	_ok(quiets.size() == 1 and int(quiets[0]["si"]) == spoken.find("then") and float(quiets[0]["s"]) <= PenPace.REST_MOST,
		"one too dense for its words is given a rest at the sentence end before it would fall behind (%s)" % str(quiets))
	var rested := EpisodeDesk.new()
	var with_rest := _audit_of(rested, 0, _playing(rested, voiced, EpisodeDesk.VOICE_WORD, EpisodeDesk.VOICE_PAUSE))
	var bare := EpisodeDesk.new()
	var without := _audit_of(bare, 0, _playing(bare, PINNED, EpisodeDesk.VOICE_WORD, EpisodeDesk.VOICE_PAUSE))
	_ok(float(with_rest["behind"]) <= PenPace.LAG_OK + 0.1, "played with it, the pen is never more than %.1f s behind (%.2f s)" % [PenPace.LAG_OK, with_rest["behind"]])
	_ok(float(without["behind"]) > PenPace.LAG_OK + 0.2, "CONTROL: played without it, the pen falls behind (%.2f s)" % without["behind"])
	for d in [rested, bare]:
		(d as EpisodeDesk)._pad.free()
		(d as EpisodeDesk).free()
	for f in ["acts.json", "ink.json"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(DIR.path_join(f)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(DIR))


## How desk [param m]'s pen kept with its voice through write [param i] ([method PenPace.audit]), its words' times in
## [param words] as handed, on the write's own map or [param map].
func _audit_of(m: EpisodeDesk, i: int, words: Array, map := PackedVector2Array()) -> Dictionary:
	var a: Dictionary = m._actions[i]
	var said: Array = []
	for k in (a["own"] as PackedInt32Array):
		said.append(Vector2(float((words[k] as Dictionary)["t0"]), float((words[k] as Dictionary)["t1"])))
	var times := PackedFloat32Array()
	var drawn := PackedFloat32Array()
	var was := m._now
	var t := float(m._plan[i]["start"]) - 1.0
	while t < float(m._plan[i]["end"]) + 1.0:
		m._now = t
		times.append(t)
		drawn.append(m._written(i))
		t += 0.05
	m._now = was
	return PenPace.audit(map if not map.is_empty() else a["map"], said, times, drawn, m._length(i))


const LONG_TALK := "First we write a squared plus b squared equals c squared, and then we stop and say what each part of it means, slowly and in plain words, so that nothing on the page is a surprise when we come back to it later on, and every letter in it has a name we can say out loud before we go on to the next thing on the page."
const SHORT_TALK := "First we write a squared plus b squared equals c squared, and then we stop and say what each part of it means, slowly and in plain words, so that nothing on the page is a surprise when we come back to it later on, and every letter in it has a name."


## Two writes, a formula and a line in a hand, at the acts' words in [param talk] and the line after it.
func _two(talk: String, opening := true) -> String:
	return "<!-- table: begin -->\n\n%s<!-- act: square --> %s\n\n<!-- act: label --> Then a heading for it, in plain words.\n" % [
		(OPENING + "\n\n") if opening else "", talk]


func _two_acts() -> Dictionary:
	return {"acts": [{"name": "square", "beat": "intro", "tracks": [{"law": "write", "thing": "pad", "part": "page", "tex": TEX}]},
		{"name": "label", "beat": "intro", "tracks": [{"law": "write", "thing": "pad", "part": "page", "text": WORDS, "hand": "neat"}]}]}


## A desk with no floor under its first action, for the control.
class Unseen extends EpisodeDesk:
	func _first_floor() -> float:
		return -INF


## THE DESK IS SEEN WHOLE FIRST: a write at the first word waits until the desk has been seen, the camera wide till then.
func _seen_first() -> void:
	_put(_two_acts(), _ink())
	var script := _two(SHORT_TALK, false)
	var m := EpisodeDesk.new()
	var words := _playing(m, script, 0.4)
	var floor := m._opening() + EpisodeDesk.DESK_SEEN + DeskMedium.CAM_LEAD + DeskMedium.PICK_UP
	var start := float(m._plan[0]["start"])
	_ok(float((words[0] as Dictionary)["t0"]) < m._opening() + 5.0 and start >= floor - 0.01,
		"a write at the first word begins once the desk has been seen whole (%.1f s, the title gone at %.1f)" % [start, m._opening()])
	m._now = m._opening() + EpisodeDesk.DESK_SEEN - 0.5
	_ok(float(m._framing()["k"]) == 0.0, "the camera is wide while the desk is seen (%.0f)" % float(m._framing()["k"]))
	var unseen := Unseen.new()
	_playing(unseen, script, 0.4)
	_ok(float(unseen._plan[0]["start"]) < floor - 5.0, "CONTROL: a desk with no floor begins on its word (%.1f s)" % float(unseen._plan[0]["start"]))
	for d in [m, unseen]:
		(d as EpisodeDesk)._pad.free()
		(d as EpisodeDesk).free()


## THE HAND SETTLES through a long wait: the nib low and nearly still; a short wait is waited out held up.
func _settles() -> void:
	_put(_two_acts(), _ink())
	var m := EpisodeDesk.new()
	_playing(m, _two(LONG_TALK), 0.4)
	var end := float(m._plan[0]["end"])
	var go := float(m._plan[1]["start"])
	m._now = (end + go) * 0.5
	var at := m.pen_at()
	_ok(go - end > DeskMedium.SETTLE_WAIT + 2.0 and float(at.get("still", 0.0)) > 0.99 and absf(float(at["lift"]) - Pen.SETTLED_LIFT) < 0.0005,
		"through a long wait the hand settles, the nib low (%.1f s of wait; %.3f m up, settled %.2f)" % [go - end, float(at["lift"]), float(at.get("still", 0.0))])
	var held := 0.0
	var settled := 0.0
	for k in 60:
		held = maxf(held, Pen.drift(float(k) * 0.37, 3, Pen.REST_LIFT).length())
		settled = maxf(settled, Pen.drift(float(k) * 0.37, 3, Pen.SETTLED_LIFT, 1.0).length())
	_ok(settled < held * 0.05, "and its drift nearly gone (%.2f mm, held %.2f mm)" % [settled * 1000.0, held * 1000.0])
	var stopped: Vector2 = m._action_point(m._actions[0], false)
	_ok((at["p"] as Vector2).x < DeskMedium.PW and (at["p"] as Vector2).distance_to(stopped) < 150.0,
		"it rests on the page beside where it stopped (%s, it stopped at %s)" % [str(at["p"]), str(stopped)])
	(m._actions[1] as Dictionary)["turn"] = true
	m._now = end + DeskMedium.PARK_AFTER + DeskMedium.PARK_EASE + 0.5
	_ok((m.pen_at()["p"] as Vector2).distance_to(DeskMedium.PARK) < 5.0, "CONTROL: before a page turns, it leaves the pad (%s)" % str(m.pen_at()["p"]))
	(m._actions[1] as Dictionary)["turn"] = false
	# ...readjusting its hold now and then, the top more than the nib, and still between; a held pen sways all the time
	var moving := 0
	var held_moving := 0
	var run := 0.0
	var longest := 0.0
	var top := 0.0
	var nib := 0.0
	var was := Pen.readjust(0.0, 3)
	var was_up := Pen.lean(Pen.UP, 0.0, 3, 0.5, Vector3.ZERO)
	for f in range(1, 3600):
		var t := float(f) / 30.0
		var h := Pen.readjust(t, 3)
		var moved := absf(float(h["yaw"]) - float(was["yaw"])) + absf(float(h["tilt"]) - float(was["tilt"])) > 0.001
		moving += 1 if moved else 0
		run = 0.0 if moved else run + 1.0 / 30.0
		longest = maxf(longest, run)
		top = maxf(top, absf(float(h["yaw"])))
		nib = maxf(nib, (h["nib"] as Vector3).length())
		var up := Pen.lean(Pen.UP, t, 3, 0.5, Vector3.ZERO)
		held_moving += 1 if rad_to_deg(up.angle_to(was_up)) > 0.001 else 0
		was = h
		was_up = up
	_ok(moving > 36 and moving < 900 and longest > 3.0 and top > 2.0 and nib <= Pen.ADJUST_NIB * 1.5,
		"a settled hand readjusts now and then and is still between (moving %d of 3600 frames, still %.1f s at most; the top within %.1f degrees, the nib %.2f mm)" % [moving, longest, top, nib * 1000.0])
	_ok(held_moving > 3400, "CONTROL: a held pen's sway never stops (%d of 3600 frames)" % held_moving)
	m._now = go - DeskMedium.SETTLE_RISE * 0.2 - m._reach(0, 1)
	_ok(float(m.pen_at().get("still", 0.0)) < 0.3, "it lifts again before it sets off for the next (%.2f)" % float(m.pen_at().get("still", 0.0)))
	m._pad.free()
	m.free()
	var short := EpisodeDesk.new()
	_playing(short, _two("First we write a squared plus b squared equals c squared, the rule for every right triangle."), 0.4)
	var e := float(short._plan[0]["end"])
	var g := float(short._plan[1]["start"])
	short._now = (e + g) * 0.5
	var sat := short.pen_at()
	_ok(g > e and g - e < DeskMedium.SETTLE_WAIT and float(sat.get("still", 0.0)) == 0.0,
		"CONTROL: a short wait (%.1f s) is waited out held up (%.3f m)" % [g - e, float(sat["lift"])])
	short._pad.free()
	short.free()
	for f in ["acts.json", "ink.json"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(DIR.path_join(f)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(DIR))


## A desk guessing unheard words a steady [constant DeskScript.EST_WORD] apart from the last heard, for the control.
class Guessing extends EpisodeDesk:
	func _word_t0(si: int) -> float:
		var t := super(si)
		return t if t < INF else _guessed(si)

	func _word_t1(si: int) -> float:
		var t := super(si)
		return t if t < INF else _guessed(si) + DeskScript.EST_WORD * 0.9

	func _guessed(si: int) -> float:
		var k := mini(si, _follower.said1.size()) - 1
		while k >= 0 and _follower.said1[k] == ReadingFollower.NO_TIME:
			k -= 1
		return INF if k < 0 else _follower.said1[k] + 0.05 + float(si - k - 1) * DeskScript.EST_WORD


## LIVE, NOTHING RUNS ON WORDS NOT SAID YET: a voice's words handed a sentence at a time, a pause before the next.
func _live() -> void:
	var grid := {"name": "grid", "beat": "intro", "tracks": [{"law": "write", "thing": "pad", "part": "page", "draw": GRID_SVG}]}
	var label := {"name": "label", "beat": "intro", "tracks": [{"law": "write", "thing": "pad", "part": "page", "text": WORDS, "hand": "neat"}]}
	_put({"acts": [grid, label]}, {"items": [_figure(GRID_SVG, 8)], "fonts": {}})
	var script := "<!-- table: begin -->\n\n%s\n\n<!-- act: grid --> We draw the top line of the grid first. Then the middle line goes under it, and the bottom line under that, and the grid is done.\n\n<!-- act: label --> Then a heading for it.\n" % OPENING
	var spoken: PackedStringArray = CardReading.parse(script)["spoken"]
	var first := spoken.find("first")
	var words: Array = []
	var t := 2.0
	for i in spoken.size():
		words.append({"text": spoken[i], "t0": t, "t1": t + 0.32})
		t += 0.4 + (5.0 if i == first else 0.0)
	var pause := float((words[first] as Dictionary)["t1"]) + 3.5
	var shares := []
	for d in [EpisodeDesk.new(), EpisodeDesk.new(), Guessing.new()]:
		var m: EpisodeDesk = d
		m.feed = ShowFeed.new()
		m.feed.intro_hold = 1.0
		m._pad = LegalPad.new()
		m.load_episode({"dir": DIR, "seed": 3, "plan": {}}, script)
		# the first desk knows every word's time; the others are handed the words up to the first sentence's end, as live -
		# and, as a playing reading does, asked every half second as the time goes on
		var handed: Array = words if shares.is_empty() else words.slice(0, first + 1)
		m._now = 0.0
		while m._now < pause:
			m.take_words(handed)
			m._now = minf(m._now + 0.5, pause)
		m.take_words(handed)
		shares.append(m._written(0))
		m._pad.free()
		m.free()
	_ok(float(shares[1]) <= float(shares[0]) + 0.05,
		"live, through a pause before the next words arrive, the pen is no further on than knowing them (%.2f, known %.2f)" % [shares[1], shares[0]])
	_ok(float(shares[2]) > float(shares[0]) + 0.1, "CONTROL: a desk guessing unheard words as said runs on (%.2f)" % shares[2])
	for f in ["acts.json", "ink.json"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(DIR.path_join(f)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(DIR))


## The episode's acts and ink, written to the gate's folder.
func _put(acts: Dictionary, ink: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	for pair in [["acts.json", acts], ["ink.json", ink]]:
		var f := FileAccess.open(DIR.path_join(String(pair[0])), FileAccess.WRITE)
		f.store_string(JSON.stringify(pair[1]))
		f.close()


func _cues(parsed: Dictionary) -> Dictionary:
	var cue := {}
	for c in parsed["cues"]:
		cue[String((c as Dictionary)["name"])] = int(c["si"])
	return cue


## A desk playing [param script] from the gate's folder, its words handed at [param word] seconds each, [param pause] more
## after a sentence and the script's silences where they are.
func _playing(m: EpisodeDesk, script: String, word: float, pause := 0.0) -> Array:
	var feed := ShowFeed.new()
	feed.intro_hold = 1.0
	m.feed = feed
	m._pad = LegalPad.new()
	m.load_episode({"dir": DIR, "seed": 3, "plan": {}}, script)
	var words: Array = []
	var parsed := CardReading.parse(script)
	var spoken: PackedStringArray = parsed["spoken"]
	var ends := EpisodeDesk._word_ends(script)
	var t := 2.0
	for i in spoken.size():
		t += _quiet_at(parsed, i)
		words.append({"text": spoken[i], "t0": t, "t1": t + word * 0.8})
		t += word + (pause if i < ends.size() and bool((ends[i] as Dictionary)["stop"]) else 0.0)
	m._now = 0.0
	m.take_words(words)
	return words


## The silence the voice is given before spoken word [param si] of [param parsed], 0 for none.
func _quiet_at(parsed: Dictionary, si: int) -> float:
	for q in parsed["quiets"]:
		if int((q as Dictionary)["si"]) == si:
			return float(q["s"])
	return 0.0


## A desk that draws on past a drawing's words at the hand's own pace, for the control.
class RunsOn extends EpisodeDesk:
	func _drawn_by(_i: int) -> float:
		return INF


## A DRAWING KEEPS WITH ITS WORDS: done with them, never drawn on past them; they are its own voice's; and the voice waits for
## what the pen still owes ([method EpisodeDesk.voiced]).
func _paced() -> void:
	var grid := {"name": "grid", "beat": "intro", "tracks": [{"law": "write", "thing": "pad", "part": "page", "draw": GRID_SVG}]}
	var label := {"name": "label", "beat": "intro", "tracks": [{"law": "write", "thing": "pad", "part": "page", "text": WORDS, "hand": "neat"}]}
	var acts := {"acts": [grid, label]}
	var light := {"items": [_figure(GRID_SVG, 8)], "fonts": {}}
	var parsed := CardReading.parse(PACED)
	var cue := _cues(parsed)
	var reader := CardReading.parse(GRID_WORDS)["spoken"].size() as int
	var voiced := parsed.duplicate()
	EpisodeDesk._with_words(voiced, EpisodeDesk._word_ends(PACED))
	var own: Array = EpisodeDesk.lesson_of(acts, light, voiced, 0, 3)["actions"]
	var all: Array = EpisodeDesk.lesson_of(acts, light, parsed, 0, 3)["actions"]
	_ok(own.size() == 2 and int(own[0]["span"]) == reader,
		"a drawing's words end at its own voice's last before the next act's word (%d, the reader's %d)" % [int(own[0]["span"]) if own.size() > 0 else -1, reader])
	_ok(all.size() == 2 and int(all[0]["span"]) == int(cue["label"]) - int(cue["grid"]),
		"CONTROL: told no one's voices, they run on to the next act's word (%d)" % [int(all[0]["span"]) if all.size() > 0 else -1])
	# done with its words, its ink more than they take to say at the hand's pace and less than at the pen's quickest
	_put(acts, light)
	var m := EpisodeDesk.new()
	var words := _playing(m, PACED, 0.4)
	var said := float((words[int(cue["grid"]) + reader - 1] as Dictionary)["t1"])
	var write := float((m._actions[0] as Dictionary)["write"])
	var end := float(m._plan[0]["end"])
	# (within a step of the way's grid)
	_ok(write > said - float(m._plan[0]["start"]) and end <= said + PenPace.STEP + 0.01 and end > said - 2.0,
		"the drawing is done with its words (%.2f s, its last word ends %.2f; %.1f s of ink)" % [end, said, write])
	var on := RunsOn.new()
	_playing(on, PACED, 0.4)
	_ok(float(on._plan[0]["end"]) > said + 1.0, "CONTROL: a desk that draws on at the hand's pace ends past them (%.2f s)" % float(on._plan[0]["end"]))
	on._pad.free()
	on.free()
	m._pad.free()
	m.free()
	# another voice's line among its words is none of its own
	var aside := CardReading.parse(ASIDE)
	var aside_voiced := aside.duplicate()
	EpisodeDesk._with_words(aside_voiced, EpisodeDesk._word_ends(ASIDE))
	var mine: Dictionary = (EpisodeDesk.lesson_of(acts, light, aside_voiced, 0, 3)["actions"] as Array)[0]
	var every: Dictionary = (EpisodeDesk.lesson_of(acts, light, aside, 0, 3)["actions"] as Array)[0]
	_ok((mine["own"] as PackedInt32Array).size() == int(mine["span"]) - 2,
		"another voice's line among a drawing's words is none of its own (%d of %d)" % [(mine["own"] as PackedInt32Array).size(), int(mine["span"])])
	_ok((every["own"] as PackedInt32Array).size() == int(every["span"]), "CONTROL: told no one's voices, every word is its own")
	# the voice waits for a drawing denser than its words, at sentence ends only
	var pay := {"dir": DIR, "seed": 3, "plan": {}}
	_put(acts, {"items": [_figure(GRID_SVG, 16)], "fonts": {}})
	var once := EpisodeDesk.voiced(PACED, pay)
	var heard := CardReading.parse(once)
	var ends := EpisodeDesk._word_ends(PACED)
	var at_ends := not (heard["quiets"] as Array).is_empty()
	var longest := 0.0
	for q in heard["quiets"]:
		var si := int((q as Dictionary)["si"])
		at_ends = at_ends and si > 0 and bool((ends[si - 1] as Dictionary)["stop"])
		longest = maxf(longest, float(q["s"]))
	_ok(at_ends and longest <= PenPace.REST_MOST and heard["spoken"] == parsed["spoken"],
		"the voice waits for a drawing denser than its words at sentence ends only, never past %.1f s, its words the same (%s)" % [
		PenPace.REST_MOST, str(heard["quiets"])])
	_ok(EpisodeDesk.voiced(once, pay) == once, "CONTROL: a script voiced already is as it was, its silences counted")
	_put(acts, light)
	_ok(EpisodeDesk.voiced(PACED, pay) == PACED, "CONTROL: where the pen keeps up, the script is as it was")
	# ...and before the words of a write a page is turned for
	var square := {"name": "square", "beat": "intro", "tracks": [{"law": "write", "thing": "pad", "part": "page", "tex": TEX}]}
	var tall := {"name": "tall", "beat": "intro", "tracks": [{"law": "write", "thing": "pad", "part": "page", "draw": TALL_SVG}]}
	var pyth: Dictionary = (_ink()["items"] as Array)[0]
	_put({"acts": [square, tall]}, {"items": [pyth, _figure(TALL_SVG, 2, 360.0)], "fonts": _doc.get("fonts", {})})
	var turned := CardReading.parse(EpisodeDesk.voiced(TURNED, pay))
	var turn_rest := _quiet_at(turned, int(_cues(turned)["tall"]))
	_ok(absf(turn_rest - (DeskScript.TURN + DeskMedium.PARK_CLEAR)) < 0.11,
		"the voice waits for a page turned before a write's words (%.1f s)" % turn_rest)
	_put({"acts": [square, tall]}, {"items": [pyth, _figure(TALL_SVG, 2, 100.0)], "fonts": _doc.get("fonts", {})})
	_ok(EpisodeDesk.voiced(TURNED, pay) == TURNED, "CONTROL: a drawing that fits under what is on the page leaves the script as it was")
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

