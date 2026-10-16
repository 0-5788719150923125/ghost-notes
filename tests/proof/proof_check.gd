extends SceneTree

## Does the Proof component hold together without an agent: what each agent is told, the lesson's
## format, the episode on disk, the framer's answer checked, and the pad laid out?
##
## - EVERY PROMPT RENDERS WHOLE ([ProofPrompts] over rules/proof/): the inventor, the framer, the
##   solver, the teacher verified and not, and the teacher's second try with what it must mend -
##   nothing left unfilled ([member Rules.missing], no `{{`). Two-sided on the one claim that matters
##   most: a teacher whose proof Lean did NOT accept is never told it was checked, and is told to say
##   so; one whose proof was accepted is told what Lean checked.
## - THE LESSON'S FORMAT ([DeskScript]): every pen's mark is an action anchored after the right word,
##   the paragraph right after a formula is its DICTATION (the words the pen writes across), the voice
##   rests only for the pen to come down, for a page's turn and for writing a dictation would leave
##   behind - one rest between two paragraphs - and is handed no notation, with a lesson whose speech
##   says "$x^2$" as the control the audit must catch.
## - THE EPISODE ON DISK ([ProofEpisode], under a scratch root): what each step needs, that a redo of
##   the solve deletes its notebook, its Lean file and everything made after it, and nothing else.
## - THE FRAMER'S ANSWER ([method ProofProducer.land_problem]): a statement handed back with its proof
##   keeps only the statement; one that does not state `theorem main` is refused (the control);
##   forbidden names that are not names are dropped.
## - THE PAD ([method DeskScript.lay_out]): every formula's baseline on a rule, a page filled to its
##   foot before it turns (no mark turns one: the user, 2026-10-16, "a page with text on it is just
##   'wiped' clean, for seemingly no reason"), a strike on the last thing written.
## - THE DESK'S CLOCK ([DeskMedium], no stage): the pen down as its dictation starts and done as it
##   ends, the ink as far through as the words are - within the pen's pace - a page turned in the rest
##   before the formula that needs it and never over writing, the camera wide over the intro and a turn
##   and close while the pen writes, and the title up until the first word ([ShowOpening]).
##
##   godot --headless --path . --script tests/proof/proof_check.gd

const YouTube_ := preload("res://src/export/youtube.gd")

var _fails: Array = []
var _scratch := ""


func _init() -> void:
	_scratch = OS.get_user_data_dir().path_join("proof_check")
	_rmrf(_scratch)
	ProofEpisode.root = _scratch
	_prompts()
	_script()
	_episode()
	_problem()
	_pad()
	_rmrf(_scratch)
	ProofEpisode.root = ProofEpisode.ROOT
	if _fails.is_empty():
		print("proof_check: ALL OK")
		quit(0)
	else:
		print("proof_check: %d FAILURE(S)" % _fails.size())
		for f in _fails:
			print("   ", f)
		quit(1)


func _check(ok: bool, msg: String) -> void:
	print(("   ok   " if ok else "   FAIL ") + msg)
	if not ok:
		_fails.append(msg)


func _rmrf(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for f in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(f))
	for d in DirAccess.get_directories_at(path):
		_rmrf(path.path_join(d))
	DirAccess.remove_absolute(path)


# --- what each agent is told ----------------------------------------------------------------

const PROBLEM := {"episode_title": "Why the Primes Never Run Out", "statement": "However far you count, there is a prime further on.",
	"latex": "\\forall n,\\ \\exists p \\ge n,\\ p \\text{ prime}", "lean": "theorem main (n : ℕ) : ∃ p, n ≤ p ∧ Nat.Prime p",
	"forbidden": ["Nat.exists_infinite_primes"], "history": "Euclid proved it around 300 BC.",
	"audience": "curious viewers"}


func _prompts() -> void:
	print("-- every prompt renders whole")
	Rules.missing = PackedStringArray()
	var texts: Array = []
	var inv := ProofPrompts.inventor(7, ["Primes never run out"])
	texts.append(inv["system"])
	texts.append(inv["prompt"])
	_check(String(inv["prompt"]).contains("Primes never run out"), "the inventor is told what was done before")
	_check(String(ProofPrompts.inventor(8, [])["prompt"]) != String(ProofPrompts.inventor(9, [])["prompt"])
		or String(ProofPrompts.inventor(8, [])["prompt"]) != String(ProofPrompts.inventor(10, [])["prompt"]),
		"two presses point the inventor at different branches")
	var fr := ProofPrompts.framer("Ghost Notes", "Show that primes never run out.",
		YouTube_.title_shape(YouTube_.TITLE_TEMPLATE, {"title": "Ghost Notes"}), ["Pick More Than Half"])
	texts.append(fr["system"])
	texts.append(fr["prompt"])
	_check(String(fr["system"]).contains("Show that primes never run out."), "the note reaches every agent")
	# A PROPER EPISODE NAME (2026-10-15): the framer names the episode under the one rule every show's
	# namer is given (rules/agents/episode.yaml), for the line it goes up in, avoiding earlier titles
	_check(String(fr["prompt"]).contains("Ghost Notes: [episode_title]") and String(fr["prompt"]).contains("\"episode_title\"")
		and String(fr["prompt"]).contains("title case"), "the framer names the episode for the line it goes up in, in title case")
	_check(String(fr["prompt"]).contains("Pick More Than Half"), "and is told the note's earlier titles")
	var bare := String(ProofPrompts.framer("Ghost Notes", "a note")["prompt"])
	_check(not bare.contains("goes up as") and bare.contains("title case"),
		"the control: with no line to go up in, none is said - the title rule still is")
	var so := ProofPrompts.solver("Ghost Notes", "a note", PROBLEM)
	texts.append(so["system"])
	texts.append(so["prompt"])
	_check(String(so["prompt"]).contains("Nat.exists_infinite_primes"), "the solver is told the forbidden facts")
	_check(not String(so["prompt"] + so["system"]).to_lower().contains("reasoning"),
		"the solver is never asked for its reasoning (a safeguard stops that - next/proof.md step 0c)")
	var yes := ProofPrompts.teacher("Ghost Notes", "a note", PROBLEM, "## notes", "theorem main", true, 6.0)
	var no := ProofPrompts.teacher("Ghost Notes", "a note", PROBLEM, "## notes", "theorem main", false, 6.0)
	var fix := ProofPrompts.teacher("Ghost Notes", "a note", PROBLEM, "", "", true, 4.0,
		{"broken": ["\\frac{1}{: Missing } inserted."], "notation": ["so $x^2$ grows"], "undictated": ["n^2 + 1"]})
	for t in [yes, no, fix]:
		texts.append((t as Dictionary)["system"])
		texts.append((t as Dictionary)["prompt"])
	_check(String(yes["prompt"]).contains("checked this proof and accepted it")
		and not String(yes["prompt"]).contains("did NOT accept"), "a verified proof's teacher says what Lean checked")
	_check(String(no["prompt"]).contains("did NOT accept") and not String(no["prompt"]).contains("checked this proof and accepted it"),
		"the control: an unverified proof's teacher is told to say so, never that it was checked")
	_check(String(fix["prompt"]).contains("Missing } inserted") and String(fix["prompt"]).contains("so $x^2$ grows")
		and String(fix["prompt"]).contains("n^2 + 1"), "a second try is told what to mend")
	_check(not String(yes["prompt"]).contains("COULD NOT SET"), "and a first try is not")
	_check(String(fix["prompt"]).contains("560"), "four minutes is about 560 words")
	var left := PackedStringArray()
	for t in texts:
		if String(t).contains("{{"):
			left.append(String(t).substr(String(t).find("{{"), 30))
	_check(Rules.missing.is_empty(), "nothing the code was asked to fill is missing (%s)" % ", ".join(Rules.missing))
	_check(left.is_empty(), "no mark is left unfilled (%s)" % ", ".join(left))


# --- the lesson's format ---------------------------------------------------------------------

const LESSON := """Here is a question that sounds too simple to be hard.

<!-- pad-text: Do the primes ever run out? -->
Do the primes ever run out?

Let us try a few numbers.

<!-- pad: 2!+1 = 3 -->
Two factorial, plus one, is three.
<!-- pad: 3!+1 = 7 -->
Three factorial, plus one, is seven.

That is prime too, but it tells us nothing. <!-- note to self: not read -->
<!-- strike -->
So here is the idea.
"""
## How long each of the lesson's formulas takes the pen, as the ink would measure it: the first two
## keep up with their dictations, the third outlasts its words.
const WRITES := {"pad-text|Do the primes ever run out?": 2.0, "pad|2!+1 = 3": 3.0, "pad|3!+1 = 7": 9.0}


func _lengths() -> Dictionary:
	var out := {}
	for k in WRITES:
		var parts := String(k).split("|")
		out[String(DeskScript.item(parts[0], parts[1])["id"])] = float(WRITES[k])
	return out


func _rests(speak: String) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for m in RegEx.create_from_string("action-hold: ([0-9.]+)").search_all(speak):
		out.append(float(m.get_string(1)))
	return out


func _script() -> void:
	print("-- the lesson's format")
	var p := DeskScript.parse(LESSON, _lengths())
	var actions: Array = p["actions"]
	var kinds := PackedStringArray()
	for a in actions:
		kinds.append(String((a as Dictionary)["kind"]))
	_check(kinds == PackedStringArray(["pad-text", "pad", "pad", "strike"]),
		"every mark is an action, in order (%s)" % ", ".join(kinds))
	_check(int((actions[0] as Dictionary)["after"]) == 11,
		"the first mark comes after the first sentence's eleven words (%d)" % int((actions[0] as Dictionary)["after"]))
	_check(int((actions[0] as Dictionary)["span"]) == 6 and int((actions[1] as Dictionary)["span"]) == 6
		and int((actions[3] as Dictionary)["span"]) == 0,
		"a formula's dictation is the paragraph right after it; a strike has none")
	var spoken: PackedStringArray = p["spoken"]
	var at := int((actions[1] as Dictionary)["after"])
	_check(" ".join(spoken.slice(at, at + 6)) == "two factorial plus one is three",
		"and the pen writes across exactly those words (%s)" % " ".join(spoken.slice(at, at + 6)))
	# the rests: the pen coming down before each dictation (0.45), none in or after a dictation the pen
	# keeps up with, the third's writing outlasting its six words (9 s at 1.8 x pace, less the words) -
	# shared out over its three phrases, the last share after it - and the strike
	var rests := _rests(String(p["speakable"]))
	var tail := 9.0 / DeskScript.MAX_PACE - 6.0 * DeskScript.EST_WORD
	var want := PackedFloat32Array([DeskScript.LEAD_HOLD, DeskScript.LEAD_HOLD, DeskScript.LEAD_HOLD,
		tail / 3.0, tail / 3.0, tail / 3.0, DeskScript.STRIKE])
	var same := rests.size() == want.size()
	for i in mini(rests.size(), want.size()):
		same = same and absf(rests[i] - want[i]) < 0.011
	_check(same, "the voice rests for the pen to come down, for what it lags and for a strike (%s)" % str(rests))
	_check(String(p["speakable"]).contains("Three factorial, <!-- action-hold: 1.01 --> plus one, <!-- action-hold: 1.01 --> is seven.")
		and String(p["speakable"]).contains("Two factorial, plus one, is three."),
		"a dictation the pen lags goes phrase by phrase, resting while the pen writes; one it keeps up with is said straight")
	var plain := DeskScript.paced("one two three four five six seven eight nine ten", 20.0, 10)
	_check(String(plain["text"]).count("action-hold") == 1 and String(plain["text"]).contains("six <!-- action-hold")
		and absf(float(plain["rest"]) - DeskScript.tail_for(20.0, 10) * 0.4) < 0.01,
		"a phrase with no stop in it rests every few words (%s)" % String(plain["text"]))
	var lone := DeskScript.paced("one two three four five six seven", 20.0, 7)
	_check(String(lone["text"]).count("action-hold") == 0, "but never leaves one word to say alone (%s)" % String(lone["text"]))
	var near := DeskScript.paced("Twelve is four times three. Forty is eight.", DeskScript.MAX_PACE * (8.0 * DeskScript.EST_WORD + 0.7), 8)
	_check(not String(near["text"]).contains("action-hold") and absf(float(near["rest"]) - 0.7) < 0.01,
		"the control: a dictation the pen lags by under a second is said straight, the rest after it")
	var twice := false
	var chunks := String(p["speakable"]).split("\n\n")
	for i in range(1, chunks.size()):
		twice = twice or (chunks[i].begins_with("<!-- action-hold") and chunks[i - 1].begins_with("<!-- action-hold"))
	_check(not twice,
		"one rest between two paragraphs, never two in a row")
	var speak := String(p["speakable"])
	_check(not speak.contains("pad:") and not speak.contains("2!+1") and not speak.contains("not read"),
		"the voice is handed no TeX and no note")
	_check(DeskScript.tail_for(3.0, 6) == 0.0 and DeskScript.tail_for(9.0, 6) > 2.9,
		"a dictation the pen keeps up with leaves no rest; one it lags leaves the difference")
	var silent := DeskScript.parse("Look.\n\n<!-- pad: x = 1 -->\n\nNow then.", {})
	_check(absf(float((silent["actions"][0] as Dictionary)["dur"]) - DeskScript.LEAD_HOLD
		- DeskScript.estimate("x = 1")) < 0.01 and int((silent["actions"][0] as Dictionary)["span"]) == 0,
		"a formula with no dictation - a blank line before the next words - is written while the voice waits")
	_check(DeskScript.undictated(LESSON).is_empty() and DeskScript.undictated(
		"Look.\n\n<!-- pad: x = 1 -->\n\nNow then.") == PackedStringArray(["x = 1"]),
		"a pad line read on the line after it is dictated; the control, one with a blank line between, is not")
	_check(DeskScript.parse("Hello.\n<!-- new page -->\nThere.")["actions"].is_empty(),
		"no mark turns a page: the pad turns when it is full")
	_check(DeskScript.items(LESSON).size() == 3 and String(DeskScript.items(LESSON)[1]["mode"]) == "math",
		"three items for the ink, in order, each its mode")
	_check(String(DeskScript.item("pad", "\\begin{aligned} a &= b \\\\ c &= d \\end{aligned}")["mode"]) == "math",
		"an aligned derivation is math: TeX allows aligned only in math mode (the first real episode's refusal)")
	_check(String(DeskScript.item("pad", "\\begin{align*} a &= b \\\\ c &= d \\end{align*}")["mode"]) == "display",
		"the control: align*, a display of its own, is set as one")
	_check(DeskScript.audit(LESSON).is_empty(), "a lesson that says its math in words passes the audit")
	var notation := DeskScript.audit("<!-- pad: x^2 -->\nSo $x^2$ grows, and so does x_1.")
	_check(notation.size() == 1, "the control: speech carrying notation is caught (%d)" % notation.size())
	_check(DeskScript.speakable("Plain words.") == "Plain words.", "a text with no pen marks is read as it is")


# --- the episode on disk ----------------------------------------------------------------------

func _episode() -> void:
	print("-- the episode on disk")
	var ep := ProofEpisode.open("my-note", 1)
	_check(ep.dir.begins_with(_scratch), "the gate's episodes are in its own folder")
	_check(ep.dependents("solve") == ["lesson", "ink", "script"], "a solve's dependents (%s)" % str(ep.dependents("solve")))
	_check(ep.dependents("script").is_empty(), "nothing is made from the script")
	for step in ["problem", "solve", "lesson", "ink", "script", "notebook", "proof"]:
		ep.write_text(step, "{}" if step in ["problem", "solve", "ink"] else "x")
	ep.write_json("problem", {"episode_title": "Primes never run out"})
	ep.invalidate("solve")
	var gone := PackedStringArray()
	var kept := PackedStringArray()
	for step in ["problem", "solve", "lesson", "ink", "script", "notebook", "proof"]:
		if FileAccess.file_exists(ep.file_of(step)):
			kept.append(step)
		else:
			gone.append(step)
	_check(kept == PackedStringArray(["problem"]), "a redo of the solve keeps only the problem (kept %s)" % ", ".join(kept))
	_check(not DirAccess.get_files_at(ep.dir).has("problem.json.part"), "nothing half-written is left")
	var two := ProofEpisode.open("my-note", 2)
	two.write_json("problem", {"episode_title": "Odd numbers"})
	var hist := ProofEpisode.history("my-note")
	_check(hist.size() == 2 and String(hist[0]["title"]) == "Primes never run out" and int(hist[1]["n"]) == 2,
		"the note's episodes, oldest first, with their titles")
	_check(ep.seed != two.seed and ep.seed == ProofEpisode.open("my-note", 1).seed,
		"each episode's hand has a seed of its own, the same every time")
	_check(ProofEpisode.show_key_of("/notes/My Proof Note.md") == "my-proof-note", "a note's key is its file's name")


# --- the framer's answer -----------------------------------------------------------------------

func _problem() -> void:
	print("-- the framer's answer, checked")
	var got := ProofProducer.land_problem({"episode_title": "Why the Primes Never Run Out", "statement": "they never run out",
		"description": "Euclid's argument, worked at the desk.", "tags": ["primes", "Euclid", 7],
		"latex": "x", "lean": "theorem main (n : ℕ) : ∃ p, n ≤ p ∧ Nat.Prime p := by\n  sorry",
		"forbidden": ["Nat.exists_infinite_primes", "not a name", ""]})
	_check(not got.has("error") and String(got["lean"]) == "theorem main (n : ℕ) : ∃ p, n ≤ p ∧ Nat.Prime p",
		"a statement handed back with a proof keeps only the statement (%s)" % str(got.get("lean", got.get("error"))))
	_check(got.get("forbidden", []) == ["Nat.exists_infinite_primes"], "a forbidden 'name' with a space is dropped")
	_check(String(got.get("episode_title", "")) == "Why the Primes Never Run Out" and got.get("tags", []) == ["primes", "Euclid", "7"]
		and String(got.get("description", "")).begins_with("Euclid"), "the episode's name, description and tags are kept")
	_check(ProofProducer.land_problem({"title": "Primes", "statement": "y", "lean": "theorem main : True"}).has("error"),
		"the control: an answer naming no episode is refused")
	var bad := ProofProducer.land_problem({"episode_title": "x", "statement": "y", "lean": "lemma helper : True"})
	_check(bad.has("error"), "the control: a statement that is not theorem main is refused")
	_check(ProofProducer.land_problem({"episode_title": "", "statement": "y", "lean": "theorem main : True"}).has("error"),
		"and so is one with no title")
	_check(ProofProducer.clean_lesson("```markdown\nHello.\n```") == "Hello.", "a fenced lesson is unwrapped")


# --- the pad --------------------------------------------------------------------------------

func _pad() -> void:
	print("-- the pad, laid out")
	var actions: Array = []
	var records := {}
	for i in 60:
		var it := DeskScript.item("pad", "x_%d = %d" % [i, i])
		records[String(it["id"])] = {"id": it["id"], "ok": true, "w": 60.0, "h": 8.0, "d": 2.0}
		actions.append({"kind": "pad", "id": it["id"], "tex": it["tex"], "after": i, "dur": 1.0, "write": 3.0})
	actions.insert(3, {"kind": "strike", "after": 3, "dur": 0.9, "write": 0.9, "id": ""})
	var laid := DeskScript.lay_out(actions, records)
	var off := PackedStringArray()
	var per_page := {}
	var turns := PackedInt32Array()
	for a in laid:
		var act: Dictionary = a
		if bool(act["turn"]):
			turns.append(int(act["i"]))
		if act.has("at"):
			per_page[int(act["page"])] = int(per_page.get(int(act["page"]), 0)) + 1
			var y := (act["at"] as Vector2).y
			var k := (y - DeskScript.FIRST_RULE) / DeskScript.RULE
			if absf(k - roundf(k)) > 0.001 or y + float(act["d"]) > DeskScript.PH - DeskScript.FOOT + 0.5:
				off.append(str(y))
	_check(off.is_empty(), "every formula sits on a rule, above the foot (%s)" % ", ".join(off))
	_check(int((laid[3] as Dictionary)["of"]) == 2, "a strike crosses out the last thing written")
	# a line of type a rule tall takes one rule, and a page has 25 above its foot: every one is used
	_check(per_page.get(0, 0) == 25 and per_page.get(1, 0) == 25 and per_page.get(2, 0) == 10,
		"each page is filled to its foot before the next (%s)" % str(per_page))
	_check(turns.size() == 2 and int((laid[turns[0]] as Dictionary)["page"]) == 1,
		"the page turns where the next formula would run off it, and only there (%s)" % str(turns))
	var first_on_two := ((laid[turns[0]] as Dictionary)["at"] as Vector2).y if turns.size() > 0 else -1.0
	_check(first_on_two == DeskScript.FIRST_RULE, "a new page starts on its first rule (%.0f)" % first_on_two)
	_desk()


## A desk over the lesson with no stage: the actions as the ink would lay them out (no strokes - an
## item's writing is its measured length), and a steady voice reading it.
func _desk_over(sizes: Dictionary) -> DeskMedium:
	var desk := DeskMedium.new()
	desk.load_lesson(LESSON, {"seed": 3})
	var parsed := DeskScript.parse(LESSON, _lengths(), sizes)
	desk._actions = parsed["actions"]
	desk._follower.extend(DeskScript.rehearsal(parsed))
	desk._build_plan()
	return desk


func _desk() -> void:
	print("-- the desk's clock")
	var desk := _desk_over({})
	var f := desk._follower
	var act: Dictionary = desk._actions[1]
	var plan: Dictionary = desk._plan[1]
	var first := int(act["after"])
	_check(absf(float(plan["start"]) - (f.st0[first] - DeskMedium.PEN_LEAD)) < 0.001,
		"the pen comes down as its dictation's first word is said")
	_check(absf(float(plan["end"]) - f.st1[first + 5]) < 0.001, "and is done as the last word is (it keeps up)")
	desk._now = float(f.st0[first + 3])
	var share := desk._ink_time(1) / float(act["write"])
	_check(absf(share - 0.5) < 0.02, "halfway through the words, halfway through the writing (%.2f)" % share)
	desk._now = float(plan["start"])
	_check(desk._ink_time(1) == 0.0, "nothing written before the pen is down")
	desk._now = float(plan["end"]) + 0.1
	_check(desk._ink_time(1) == float(act["write"]), "and all of it once the words are said")
	var slow: Dictionary = desk._actions[2]
	var sp: Dictionary = desk._plan[2]
	desk._now = float(f.st1[int(slow["after"]) + 5]) + 0.01
	var lag := desk._ink_time(2)
	_check(lag < float(slow["write"]) and absf(lag - (desk._now - float(sp["start"])) * DeskScript.MAX_PACE) < 0.01,
		"a formula that outlasts its words is written at the pen's fastest, and finishes in the rest (%.2f of %.0f)"
		% [lag, float(slow["write"])])
	_check(float(sp["end"]) <= float(f.st0[int(slow["after"]) + 6]),
		"before the voice goes on")
	# THE TITLE AND THE CAMERA: up and wide over the intro until the first word, close as the pen writes
	_check(ShowOpening.title_alpha(0.1, INF, false) == 0.0 and ShowOpening.title_alpha(1.6, INF, false) == 1.0,
		"the channel's name comes up over the intro")
	_check(desk._opening() == f.st0[0], "the lesson opens on its first word")
	desk._now = float(f.st0[0]) - 2.0
	_check(float(desk._framing()["k"]) == 0.0, "the camera is wide over the intro")
	desk._now = float(plan["start"]) + 0.5
	_check(float(desk._framing()["k"]) == 1.0, "and close while the pen writes")
	desk._now = float(f.st1[f.st1.size() - 1]) + 0.5
	_check(float(desk._framing()["k"]) == 0.0, "and wide again once the last word is said")
	var none := DeskMedium.new()
	none.load_lesson(LESSON, {"seed": 3})
	_check(none._opening() == INF and ShowOpening.title_alpha(8.0, none._opening(), false) == 1.0,
		"the control: with no word heard, the name stays up")
	none.free()
	desk.free()
	# A PAGE TURNED FOR THE THIRD FORMULA (one too tall for what is left of the first page): the voice
	# rests for the turn, the turn comes after the writing before it, and the formula after the turn
	var tall := {String(DeskScript.item("pad", "3!+1 = 7")["id"]): {"w": 60.0, "h": 360.0, "d": 2.0}}
	var turned := DeskScript.parse(LESSON, _lengths(), tall)
	_check(bool((turned["actions"][2] as Dictionary)["turn"]) and not bool((turned["actions"][1] as Dictionary)["turn"]),
		"the formula that will not fit turns the page")
	var rests := _rests(String(turned["speakable"]))
	_check(rests.size() == 7 and absf(rests[2] - DeskScript.LEAD_HOLD - DeskScript.TURN) < 0.011,
		"and the voice waits for the turn before its dictation (%s)" % str(rests))
	var td := _desk_over(tall)
	var tp: Dictionary = td._plan[2]
	var ta := float(tp["turn_at"])
	_check(ta >= float(td._plan[1]["end"]) and float(tp["start"]) >= ta + DeskScript.TURN,
		"the page turns after the writing before it, and the pen writes once it is over")
	td._now = ta - 0.1
	var before := td._pages()
	td._now = ta + 0.5
	var during := td._pages()
	td._now = ta + DeskScript.TURN + 0.01
	var after := td._pages()
	_check(before == Vector2i(0, -1) and during == Vector2i(1, 0) and after == Vector2i(1, -1),
		"page one is written, turned away over page two, and gone (%s %s %s)" % [before, during, after])
	td._now = ta + 0.5
	_check(float(td._framing()["k"]) < 1.0, "the camera stands back as a page turns")
	td.free()
