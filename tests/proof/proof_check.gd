extends SceneTree

## Does the Proof component hold together without an agent: what each agent is told, the lesson's
## format, the episode on disk, the framer's answer checked, and the pad laid out?
##
## - EVERY PROMPT RENDERS WHOLE ([ProofPrompts] over rules/proof/): the inventor, the framer, the
##   solver, the teacher verified and not, and the teacher's second try with what it must mend -
##   nothing left unfilled ([member Rules.missing], no `{{`). Two-sided on the one claim that matters
##   most: a teacher whose proof Lean did NOT accept is never told it was checked, and is told to say
##   so; one whose proof was accepted is told what Lean checked.
## - THE LESSON'S FORMAT ([DeskScript]): the pen's marks are actions anchored after the right word, a
##   run of them is one rest of their summed length, a formula's rest is only what its writing
##   outlasts its sentence by, and the voice is handed no notation - with a lesson whose speech says
##   "$x^2$" as the control the audit must catch.
## - THE EPISODE ON DISK ([ProofEpisode], under a scratch root): what each step needs, that a redo of
##   the solve deletes its notebook, its Lean file and everything made after it, and nothing else.
## - THE FRAMER'S ANSWER ([method ProofProducer.land_problem]): a statement handed back with its proof
##   keeps only the statement; one that does not state `theorem main` is refused (the control);
##   forbidden names that are not names are dropped.
## - THE PAD ([method DeskMedium.lay_out]): every formula's baseline on a rule, a long lesson onto a
##   second page, `new page` turning one, a strike on the last thing written.
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
		{"broken": ["\\frac{1}{: Missing } inserted."], "notation": ["so $x^2$ grows"]})
	for t in [yes, no, fix]:
		texts.append((t as Dictionary)["system"])
		texts.append((t as Dictionary)["prompt"])
	_check(String(yes["prompt"]).contains("checked this proof and accepted it")
		and not String(yes["prompt"]).contains("did NOT accept"), "a verified proof's teacher says what Lean checked")
	_check(String(no["prompt"]).contains("did NOT accept") and not String(no["prompt"]).contains("checked this proof and accepted it"),
		"the control: an unverified proof's teacher is told to say so, never that it was checked")
	_check(String(fix["prompt"]).contains("Missing } inserted") and String(fix["prompt"]).contains("so $x^2$ grows"),
		"a second try is told what to mend")
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
Do the primes ever run out? Let us try a few numbers.
<!-- pad: 2!+1 = 3 -->
<!-- pad: 3!+1 = 7 -->
Two factorial plus one is three, and three factorial plus one is seven.
<!-- strike -->
That was a dead end. <!-- note to self: not read -->
<!-- new page -->
So here is the idea.
"""


func _script() -> void:
	print("-- the lesson's format")
	var p := DeskScript.parse(LESSON)
	var actions: Array = p["actions"]
	var kinds := PackedStringArray()
	for a in actions:
		kinds.append(String((a as Dictionary)["kind"]))
	_check(kinds == PackedStringArray(["pad-text", "pad", "pad", "strike", "new page"]),
		"every mark is an action, in order (%s)" % ", ".join(kinds))
	var spoken: PackedStringArray = p["spoken"]
	_check(spoken.size() > 0 and int((actions[0] as Dictionary)["after"]) == 11,
		"the first mark comes after the first sentence's eleven words (%d)" % int((actions[0] as Dictionary)["after"]))
	_check(int((actions[1] as Dictionary)["after"]) == int((actions[2] as Dictionary)["after"]),
		"two marks together are anchored after the same word")
	var speak := String(p["speakable"])
	var holds := RegEx.create_from_string("action-hold: ([0-9.]+)").search_all(speak)
	_check(holds.size() == 4, "a run of marks is ONE rest - four rests for five marks (%d)" % holds.size())
	var two := float(holds[1].get_string(1))
	var want := float((actions[1] as Dictionary)["dur"]) + float((actions[2] as Dictionary)["dur"])
	_check(absf(two - want) < 0.02, "and that rest is their summed length (%.2f, %.2f)" % [two, want])
	_check(not speak.contains("pad:") and not speak.contains("2!+1") and not speak.contains("not read"),
		"the voice is handed no TeX and no note")
	_check(DeskScript.hold_for(3.0) == DeskScript.MIN_HOLD and is_equal_approx(DeskScript.hold_for(8.0), 4.5)
		and DeskScript.hold_for(40.0) == DeskScript.MAX_HOLD,
		"a formula's rest is only what its writing outlasts its sentence by")
	var lengths := {String(DeskScript.item("pad", "2!+1 = 3")["id"]): 20.0}
	var measured := DeskScript.parse(LESSON, lengths)
	_check(float((measured["actions"][1] as Dictionary)["write"]) == 20.0,
		"the ink's measured writing time is what is used, once there is one")
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
	actions.insert(6, {"kind": "new page", "after": 5, "dur": 1.3, "write": 1.3, "id": ""})
	var laid := DeskMedium.lay_out(actions, records)
	var off := PackedStringArray()
	var pages := {}
	for a in laid:
		var act: Dictionary = a
		pages[int(act["page"])] = true
		if act.has("at"):
			var y := (act["at"] as Vector2).y
			var k := (y - DeskMedium.FIRST_RULE) / DeskMedium.RULE
			if absf(k - roundf(k)) > 0.001 or y + float(act["d"]) > DeskMedium.PH - DeskMedium.FOOT + 0.5:
				off.append(str(y))
	_check(off.is_empty(), "every formula sits on a rule, above the foot (%s)" % ", ".join(off))
	_check(int((laid[3] as Dictionary)["of"]) == 2, "a strike crosses out the last thing written")
	_check(int((laid[7] as Dictionary)["page"]) == 1 and int((laid[5] as Dictionary)["page"]) == 0,
		"new page turns one: what follows it is on the next")
	_check(pages.size() >= 3, "a long lesson runs onto more pages (%d)" % pages.size())
	var first_on_two := -1.0
	for a in laid:
		if int((a as Dictionary)["page"]) == 1 and (a as Dictionary).has("at"):
			first_on_two = ((a as Dictionary)["at"] as Vector2).y
			break
	_check(first_on_two == DeskMedium.FIRST_RULE, "a new page starts on its first rule (%.0f)" % first_on_two)
	# THE TITLE SCREEN, as the card table's: the channel's name up over the intro, gone as the lesson
	# opens - its first word - and not before (the control: with no word heard yet, it stays up)
	var desk := DeskMedium.new()
	_check(desk._title_alpha(0.1) == 0.0 and desk._title_alpha(1.6) == 1.0, "the channel's name comes up over the intro")
	desk._follower.reset(PackedStringArray(["here", "is"]))
	_check(desk._title_alpha(8.0) == 1.0, "and stays up while no word has been said")
	desk._follower.extend([{"text": "Here", "t0": 5.0, "t1": 5.3}])
	_check(desk._title_alpha(3.0) == 1.0 and desk._title_alpha(5.5) == 0.0, "and is gone as the first word is said")
	desk.free()
