extends SceneTree

## Does the Proof component hold together without an agent: what each agent is told, the lesson's
## format, the episode on disk, the framer's answer checked, and the pad laid out?
##
## - EVERY PROMPT RENDERS WHOLE ([ProofPrompts] over rules/proof/): the inventor, the refiner, the
##   framer, the solver, the teacher verified and not, and the teacher's second try with what it must
##   mend - nothing left unfilled ([member Rules.missing], no `{{`). The refiner (the user, 2026-10-16:
##   "rewrite the entire thing, to define the problem better") reads the note as it stands, and its
##   format is placeholders only - a format with a title written in the control. Two-sided on the one
##   claim that matters most: a teacher whose proof Lean did NOT accept is never told it was checked, and is told to say
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
## - A DRAWING ([DeskScript], the user, 2026-10-16: "it might be useful if it could draw something"): a
##   `draw` mark over several lines is one action, a figure for the ink, dictated by the line after it,
##   centered on the page and never spoken - with the SVG's text in the speech as the control.
## - A LETTER IS SAID AS A LETTER (the user, the same day: "The voices are pronouncing 'a' wrong"): `[a]`
##   is the letter's name, shown as `a`, where a bare "a" stays the article (the control); a lesson
##   reading a formula's `a` as a bare word is caught, and one writing `[a]` is not.
## - THE STUDENT AND THE SECOND DRAFT: the student's prompt renders whole and never asks for reasoning,
##   its answer is read as notes (a non-answer refused), the teacher's second draft is handed the first
##   and the notes, and an episode whose lesson stands is not drafted again behind it.
## - THE PEN POINTS (the user, 2026-10-16: "describing what is on the page, but never POINTING to any of
##   it"): a `point` in speech is an action at the word after it, held to its sentence's end and never
##   spoken; it finds the latest thing written under its name - a mark's #name, a drawing's id, a
##   formula's \pin - and a name nothing carries is caught (the control: the names that are there are
##   not). At the desk the nib comes down beside the thing as the word is said - a wide one swept under
##   first - the camera goes to it and no ink is drawn; a point at a page already turned leaves the pen where it was (the control).
## - THE PEN IS NEVER STILL FOR LONG: a long stretch of speech with the pen idle is caught, and the same
##   stretch broken by a point is not (the control).
## - A READING STARTED MID-WAY (the user, 2026-10-16: "scrubbing the timeline seems to have broken the
##   pen completely. For the remainder of the video, the pen doesn't move at all"): handed the new
##   reading's first words, the desk finds its place - what came before is written, the next formula
##   is scheduled and the pen writes it; the control, the same words with no start, matches nothing
##   and leaves the rest unscheduled, which is what the user saw.
## - THE HAND IS ALIVE (the same day: "A hand holding a pen would never keep it at a perfectly static
##   angle"): the pen's lean sways over seconds - the old fixed lean is the control - always toward the
##   top right and within a few degrees of it; it is the same at the same moment, another hand's sways
##   otherwise; its top trails the nib's travel; and the nib drifts at rest and never while it writes.
## - A LESSON'S LENGTH IS ITS OWN (the user, 2026-10-16: "make videos as long as they need to be"): no
##   agent is handed minutes or words, and a lesson of thousands of words lands on its first try -
##   against the same lesson with a pad line left unread, which still goes back.
## - THE THUMBNAIL (the user: "did not use the proper thumbnail ... the same thumbnail that cards-based
##   modes use"): a Proof upload names the title screen's moment, the name fully up over the blur - on
##   the first frame, since [ProofCard] names the Director, which a script's `_init` has not got.
## - DELETE AND REMAKE (the user, 2026-10-16: "There is currently no way to delete an episode. There is
##   also no way to entirely remake one"): an episode with nothing made is made, one with anything made
##   is remade (Make becomes Remake) and a remake leaves nothing of it; a delete throws away the
##   episode's own folder - through the gate's seam, never the system trash - and opens the newest left,
##   or a first one when none is.
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
	_drawing()
	_letters()
	_student()
	_length()
	_points()
	_alive()
	_scrub()
	process_frame.connect(_upload, CONNECT_ONE_SHOT)


## THE UPLOAD, on the first frame (the card names the Director), and then the verdict.
func _upload() -> void:
	print("-- the upload's thumbnail")
	var card: Script = load("res://src/proof/proof_card.gd")
	var ep := ProofEpisode.open("thumb-note", 1)
	ep.write_json("problem", {"episode_title": "Odd Squares", "description": "Sums of odd numbers.", "tags": ["induction"]})
	ep.write_json("solve", {"verified": true, "lean": "4.35.0", "mathlib": "v4.35.0"})
	var up: Dictionary = card.upload_of(ep, {"title": "Pen & Ink"}, PackedStringArray(["math"]), 9.0)
	var at := float(up.get("thumbnail_at", -1.0))
	var cards: Script = load("res://src/cards/episode_card.gd")
	_check(absf(at - ShowOpening.thumbnail_moment(9.0)) < 0.001 and absf(at - float(cards.thumbnail_moment(9.0))) < 0.001,
		"a Proof upload names the thumbnail's moment, the card shows' own (%.2f s)" % at)
	_check(ShowOpening.title_alpha(at, 9.0, true) == 1.0 and ShowOpening.pull(at, 9.0, true) == 0.0,
		"and at that moment the name is fully up over the desk out of focus")
	_check(String(up.get("description", "")).contains("checked by the Lean theorem prover (Lean 4.35.0")
		and up.get("tags", []) == ["math", "induction"], "with the description, the check and the tags as before")
	var take := _scratch.path_join("take_1.wav")
	FileAccess.open(take.get_basename() + ".json", FileAccess.WRITE).store_string(JSON.stringify({"bookend": {"in": 9.0, "out": 9.0}}))
	_check(ShowOpening.take_intro(take, 2.0) == 9.0 and ShowOpening.take_intro(_scratch.path_join("none.wav"), 2.0) == 2.0,
		"the moment comes from the intro the take was rendered with; the control, a take with no sidecar, the live one")
	print("-- delete and remake")
	var fresh := ProofEpisode.open("delete-note", 1)
	_check(not card.made_any(fresh), "an episode with nothing made is made (the button says Make episode)")
	fresh.write_text("lesson", "Words.\n")
	var notes := ProofEpisode.open("delete-note", 2)
	DirAccess.make_dir_recursive_absolute(notes.dir)
	FileAccess.open(notes.file_of("notebook"), FileAccess.WRITE).store_string("## work")
	_check(card.made_any(fresh) and card.made_any(notes), "one with any step made - a notebook too - is remade (Remake episode)")
	var whole := ProofEpisode.open("delete-note", 3)
	for st in ProofEpisode.STEPS:
		whole.write_text(String(st), "x\n")
	whole.invalidate("problem")
	_check(not card.made_any(whole), "a remake leaves nothing of what was made")
	_check(card.after_delete([]) == 1 and card.after_delete([{"n": 2, "title": ""}, {"n": 5, "title": ""}]) == 5,
		"once one is deleted the newest left is opened, else a first one")
	var thrown: Array = []
	ProofEpisode.discard = func(d: String) -> void: thrown.append(d)
	var err := fresh.trash()
	ProofEpisode.discard = Callable()
	_check(err.is_empty() and thrown == [fresh.dir], "a delete throws away that episode's own folder, through the gate's seam")
	_finish()


func _finish() -> void:
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
	var ref := ProofPrompts.refiner("Ghost Notes", "Explain the 6 trig functions")
	texts.append(ref["system"])
	texts.append(ref["prompt"])
	_check(String(ref["system"]).contains("Explain the 6 trig functions")
		and String(ref["prompt"]).contains("Keep everything the author asked for"),
		"the refiner reads the note as it stands, and keeps what was asked")
	_check(not String(ref["prompt"] + ref["system"]).to_lower().contains("reasoning"),
		"the refiner is never asked for its reasoning")
	# A SAMPLE IN A PROMPT COMES BACK WORD FOR WORD: every line of the format the refiner fills is a
	# placeholder, or one of the note's own headings
	var filled := _filled_in(String(ref["prompt"]))
	_check(String(ref["prompt"]).contains("in exactly this format") and filled.is_empty(),
		"the refiner's format is placeholders only (%s)" % " | ".join(filled))
	_check(_filled_in("Write it in exactly this format:\n\n# <a title>\n\n# The Six Ratios\n\n## Who it is for").size() == 1,
		"the control: a format with a title written in is found")
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
	var yes := ProofPrompts.teacher("Ghost Notes", "a note", PROBLEM, "## notes", "theorem main", true)
	var no := ProofPrompts.teacher("Ghost Notes", "a note", PROBLEM, "## notes", "theorem main", false)
	var fix := ProofPrompts.teacher("Ghost Notes", "a note", PROBLEM, "", "", true,
		{"broken": ["\\frac{1}{: Missing } inserted."], "notation": ["so $x^2$ grows"], "undictated": ["n^2 + 1"],
		"letters": ["Take a equal to two."]})
	var again := ProofPrompts.teacher("Ghost Notes", "a note", PROBLEM, "## notes", "theorem main", true, {},
		"FIRST DRAFT TEXT", [{"quote": "a stubborn number", "need": "say what irrational means"}, {"quote": "x", "need": ""}])
	var stu := ProofPrompts.student("Ghost Notes", "a note", PROBLEM, "THE DRAFT TO READ")
	for t in [yes, no, fix, again, stu]:
		texts.append((t as Dictionary)["system"])
		texts.append((t as Dictionary)["prompt"])
	_check(String(yes["prompt"]).contains("checked this proof and accepted it")
		and not String(yes["prompt"]).contains("did NOT accept"), "a verified proof's teacher says what Lean checked")
	_check(String(no["prompt"]).contains("did NOT accept") and not String(no["prompt"]).contains("checked this proof and accepted it"),
		"the control: an unverified proof's teacher is told to say so, never that it was checked")
	_check(String(fix["prompt"]).contains("Missing } inserted") and String(fix["prompt"]).contains("so $x^2$ grows")
		and String(fix["prompt"]).contains("n^2 + 1"), "a second try is told what to mend")
	_check(String(fix["prompt"]).contains("Take a equal to two.") and String(fix["prompt"]).contains("square brackets"),
		"and the lines that said a letter as the word a")
	_check(not String(yes["prompt"]).contains("COULD NOT BE SET") and not String(yes["prompt"]).contains("FIRST DRAFT")
		and not String(yes["prompt"]).contains("SAID A LETTER"), "and a first try is not")
	_check(String(again["prompt"]).contains("FIRST DRAFT TEXT") and String(again["prompt"]).contains("\"a stubborn number\": say what irrational means")
		and String(again["prompt"]).contains("Write the lesson again"),
		"the second draft is handed the first and the student's notes (a note with no need left out)")
	_check(String(stu["prompt"]).contains("THE DRAFT TO READ") and String(stu["prompt"]).contains("curious viewers")
		and String(stu["prompt"]).contains("\"notes\""), "the student reads the draft as the episode's viewer, and answers notes")
	_check(not String(stu["prompt"] + stu["system"]).to_lower().contains("reasoning")
		and not String(stu["prompt"] + stu["system"]).to_lower().contains("explain why"),
		"the student is never asked for its reasoning")
	_check(String(yes["prompt"]).contains("<!-- draw:") and String(yes["prompt"]).contains("Draw at least two figures"),
		"the teacher is told how to draw, and to draw at least two figures")
	_check(String(yes["prompt"]).contains("no metaphors") and not String(yes["prompt"]).contains("refuses to behave")
		and not String(yes["prompt"]).contains("can you see why that has to be even"),
		"the teacher is told to talk plainly, and handed no sample phrase to repeat")
	# AS LONG AS IT NEEDS (the user, 2026-10-16: "make videos as long as they need to be"): no agent is
	# handed a length, and the teacher is told neither to stretch nor to rush
	var lengths := PackedStringArray()
	for t in [yes, again, ref]:
		var said := String((t as Dictionary)["prompt"]).to_lower()
		for w in ["minutes", "spoken words"]:
			if said.contains(w):
				lengths.append(w)
	_check(lengths.is_empty() and String(yes["prompt"]).contains("no set length")
		and String(ref["prompt"]).contains("no set length"),
		"no agent is handed a length (%s), and the teacher and the refiner are told there is none" % ", ".join(lengths))
	_check(String(yes["prompt"]).contains("Never stretch it") and String(yes["prompt"]).contains("never rush it"),
		"the teacher is told neither to stretch the lesson nor to rush it")
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
const WRITES := {"pad-text|Do the primes ever run out?": 2.0, "pad|2!+1 = 3": 3.0, "pad|3!+1 = 7": 20.0}


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



## The lines of [param prompt]'s format (after "in exactly this format") that are neither a
## placeholder (`<...>`) nor one of the note's headings (`## `): words an agent would copy.
func _filled_in(prompt: String) -> PackedStringArray:
	var out := PackedStringArray()
	var at := prompt.find("in exactly this format")
	for line in (prompt.substr(at).split("\n").slice(1) if at >= 0 else PackedStringArray()):
		if not line.strip_edges().is_empty() and not line.begins_with("## ") and not line.contains("<"):
			out.append(line)
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
	# keeps up with, the third's writing outlasting its six words (20 s at 4 x pace, less the words) -
	# all of it after its last word - and the strike
	var rests := _rests(String(p["speakable"]))
	var tail := 20.0 / DeskScript.MAX_PACE - 6.0 * DeskScript.EST_WORD
	var want := PackedFloat32Array([DeskScript.LEAD_HOLD, DeskScript.LEAD_HOLD, DeskScript.LEAD_HOLD,
		tail, DeskScript.STRIKE])
	var same := rests.size() == want.size()
	for i in mini(rests.size(), want.size()):
		same = same and absf(rests[i] - want[i]) < 0.011
	_check(same, "the voice rests for the pen to come down, for what it lags and for a strike (%s)" % str(rests))
	# A DICTATION IS NEVER BROKEN (the user, 2026-10-16: "like 5 seconds of silence between 'two' and
	# 'numbers'"; 2026-10-17: "We shouldn't be forcing arbitrary breaks in the speech, to wait for the pen")
	_check(String(p["speakable"]).contains("Three factorial, plus one, is seven.\n\n<!-- action-hold: %s -->"
		% String.num(tail, 2)) and String(p["speakable"]).contains("Two factorial, plus one, is three."),
		"a dictation the pen lags is said straight through, what the pen owes after its last word")
	var line := "Look.\n\n<!-- pad-text: A point is named by two numbers: across, then up. -->\n" \
		+ "A point is named by two numbers: across, then up.\n\nNext."
	var prose := DeskScript.item("pad-text", "A point is named by two numbers: across, then up.")
	var reported := String(DeskScript.parse(line, {String(prose["id"]): 23.0})["speakable"])
	_check(reported.contains("A point is named by two numbers: across, then up.\n\n<!-- action-hold: %s -->\n\nNext."
		% String.num(DeskScript.tail_for(23.0, 10), 2)),
		"the reported line is said whole, the rest after it (%s)" % reported.replace("\n", " / "))
	var twice := false
	var chunks := String(p["speakable"]).split("\n\n")
	for i in range(1, chunks.size()):
		twice = twice or (chunks[i].begins_with("<!-- action-hold") and chunks[i - 1].begins_with("<!-- action-hold"))
	_check(not twice,
		"one rest between two paragraphs, never two in a row")
	var speak := String(p["speakable"])
	_check(not speak.contains("pad:") and not speak.contains("2!+1") and not speak.contains("not read"),
		"the voice is handed no TeX and no note")
	_check(DeskScript.tail_for(3.0, 6) == 0.0 and DeskScript.tail_for(7.5, 6) == 0.0
		and absf(DeskScript.tail_for(20.0, 6) - (20.0 / DeskScript.MAX_PACE - 6.0 * DeskScript.EST_WORD)) < 0.001,
		"a dictation the pen keeps up with leaves no rest - a line of prose at four times the pen's pace too; one it lags leaves the difference")
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
	_check(ep.dependents("solve") == ["draft", "review", "lesson", "ink", "script"], "a solve's dependents (%s)" % str(ep.dependents("solve")))
	_check(ep.dependents("script").is_empty(), "nothing is made from the script")
	for step in ["problem", "solve", "draft", "review", "lesson", "ink", "script", "notebook", "proof"]:
		ep.write_text(step, "{}" if step in ["problem", "solve", "review", "ink"] else "x")
	ep.invalidate("lesson")
	_check(ep.has("draft") and ep.has("review") and not ep.has("lesson") and not ep.has("ink"),
		"a redo of the lesson keeps the draft and the student's notes it is written again from")
	_check(not ep.moot("draft") and not ep.moot("review"), "with no lesson, the draft and the notes are made")
	ep.write_text("lesson", "x")
	DirAccess.remove_absolute(ep.file_of("draft"))
	DirAccess.remove_absolute(ep.file_of("review"))
	_check(ep.moot("draft") and ep.moot("review") and not ep.moot("ink"),
		"an episode whose lesson stands (made before there were drafts) is not drafted again behind it")
	ep.write_text("ink", "{}")
	ep.write_text("script", "x")
	ep.write_json("problem", {"episode_title": "Primes never run out"})
	ep.invalidate("solve")
	var gone := PackedStringArray()
	var kept := PackedStringArray()
	for step in ["problem", "solve", "draft", "review", "lesson", "ink", "script", "notebook", "proof"]:
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


# --- a drawing, a letter, the student ------------------------------------------------------------

const DRAWN := """Here is the number line.

<!-- draw:
<svg viewBox="0 0 360 120">
  <line x1="10" y1="60" x2="350" y2="60" arrow="end"/>
  <text x="10" y="90">$0$</text>
</svg>
-->
A line, with zero at its left end.

And on we go.
"""


func _drawing() -> void:
	print("-- a drawing")
	var p := DeskScript.parse(DRAWN, {})
	var actions: Array = p["actions"]
	_check(actions.size() == 1 and String((actions[0] as Dictionary)["kind"]) == "draw",
		"a drawing over several lines is one action (%s)" % str(actions.map(func(a): return a["kind"])))
	if actions.size() != 1:
		return
	var a: Dictionary = actions[0]
	_check(String(a["mode"]) == "figure" and String(a["tex"]).begins_with("<svg viewBox") and String(a["tex"]).ends_with("</svg>"),
		"its SVG is the figure the ink lays out")
	_check(int(a["span"]) == 8 and int(a["after"]) == 5, "the line after it is its dictation (%d words after %d)" % [a["span"], a["after"]])
	var w := float(a["w"])
	_check(absf(float((a["at"] as Vector2).x) - (DeskScript.TEXT_X + (DeskScript.PW - DeskScript.RIGHT - DeskScript.TEXT_X - w) * 0.5)) < 0.01
		and absf(w - DeskScript.FIGURE_W * DeskScript.PX_PER_PT) < 0.01 and absf(float(a["h"]) - 90.0 * DeskScript.PX_PER_PT) < 0.01,
		"it spans the column, its viewBox's shape, centered on the page (%.0f wide at %s)" % [w, a["at"]])
	var speak := String(p["speakable"])
	_check(not speak.contains("svg") and not speak.contains("viewBox") and not speak.contains("$0$")
		and speak.contains("A line, with zero at its left end.") and speak.contains("And on we go."),
		"none of the drawing is spoken; its dictation and the words after it are")
	var leak := DeskScript.parse(DRAWN.replace("<!-- draw:", "<!-- not a mark:"), {})
	_check(String(leak["said"]).contains("viewBox") or (leak["actions"] as Array).is_empty(),
		"the control: the same SVG with no draw mark is not a drawing")
	_check(DeskScript.items(DRAWN).size() == 1 and String(DeskScript.items(DRAWN)[0]["mode"]) == "figure",
		"the ink is handed it as a figure")
	_check(DeskScript.undictated(DRAWN).is_empty() and DeskScript.undictated(DRAWN.replace("-->\nA line", "-->\n\nA line")).size() == 1,
		"a drawing with no dictation is caught like a formula with none")
	_check(DeskScript.estimate(String(a["tex"])) < 6.0 and DeskScript.estimate(String(a["tex"])) > DeskScript.EST_BASE,
		"a drawing's time before the ink is guessed by its elements, not its characters (%.1f s)" % DeskScript.estimate(String(a["tex"])))


func _letters() -> void:
	print("-- a letter, said as a letter")
	var said: Array = Phonemes.parse("Take [a] to be two.")[0]
	var plain: Array = Phonemes.parse("Take a fraction.")[0]
	_check(said.size() == 5 and String(said[1]["text"]) == "eigh" and String(said[1]["display"]) == "a",
		"[a] is said as the letter's name and shown as the letter (%s / %s)" % [said[1].get("text"), said[1].get("display")])
	_check(String(plain[1]["text"]) == "a", "the control: a bare a is the article")
	var cased: Array = Phonemes.parse("Case [A], then [b].")[0]
	_check(String(cased[1]["display"]) == "A," and String(cased[3]["text"]) == "bee" and String(cased[3]["display"]) == "b.",
		"a capital is shown as written, and a stop after it stays (%s %s)" % [cased[1].get("display"), cased[3].get("display")])
	var spoken := DeskScript.parse("<!-- pad: a + b -->\n[a] plus [b].\n\nDone.")["spoken"] as PackedStringArray
	_check(spoken.size() > 0 and spoken[0] == "a", "the desk follows [a] as the word the subtitles show (%s)" % ", ".join(spoken))
	var bad := "<!-- pad: a^{b} \\in \\mathbb{Q} -->\na to the power b is rational.\n\nSo it is."
	var good := "<!-- pad: a^{b} \\in \\mathbb{Q} -->\n[a] to the power [b] is rational.\n\nSo it is."
	var article := "<!-- pad: x \\in \\mathbb{Q} -->\nx is a fraction.\n\nSo it is."
	_check(DeskScript.bare_letters(bad).size() == 1, "a formula's a read as the bare word is caught")
	_check(DeskScript.bare_letters(good).is_empty() and DeskScript.bare_letters(article).is_empty(),
		"the controls: [a] passes, and so does an article where the formula has no a")
	_check(DeskScript.bare_letters("Take numbers a, b and c.").size() == 1, "and so is an a right before a comma, which no article is")


func _student() -> void:
	print("-- the student's notes")
	var got := ProofProducer.land_review({"notes": [{"quote": "a stubborn number", "need": "say what irrational means"},
		{"quote": "x", "need": "  "}, "not a note"]})
	_check(not got.has("error") and (got["notes"] as Array).size() == 1
		and String(got["notes"][0]["need"]) == "say what irrational means", "the notes are kept, the empty ones dropped")
	_check(ProofProducer.land_review({"notes": []}).get("notes", null) == [], "no notes is an answer too")
	_check(ProofProducer.land_review("just words").has("error") and ProofProducer.land_review({"remarks": []}).has("error"),
		"the control: an answer that is not notes is refused")
	var many: Array = []
	for i in 30:
		many.append({"quote": str(i), "need": "more"})
	_check((ProofProducer.land_review({"notes": many})["notes"] as Array).size() == ProofPrompts.STUDENT_NOTES,
		"no more than the student was asked for")



func _length() -> void:
	print("-- a lesson's length is its own")
	# the pen busy every few sentences, so only the length is in question (a still pen goes back)
	var long := ""
	for i in 75:
		long += "<!-- pad: %d + 1 = %d -->\n%d plus one equals %d.\n\n" % [i, i + 1, i, i + 1]
		for j in 4:
			long += "The sum grows by one at every step, and the next step is the same. "
		long += "\n\n"
	var words := (DeskScript.parse(long)["spoken"] as PackedStringArray).size()
	var ep := ProofEpisode.open("length-check", 1)
	var err := ProofProducer.new(ep, {})._land_lesson(long)
	_check(words > 4000 and err.is_empty() and ep.has("lesson"),
		"a lesson of %d spoken words lands on its first try (%s)" % [words, err])
	var unread := ProofProducer.new(ProofEpisode.open("length-check", 2), {})._land_lesson(
		long.replace("1 -->\n0 plus", "1 -->\n\n0 plus"))
	_check(unread.contains("not read aloud"), "the control: the same lesson with its pad line unread goes back (%s)" % unread)



# --- the pen points, and lives -------------------------------------------------------------------

const POINTED := """Here is a circle.

<!-- draw #circ:
<svg viewBox="0 0 360 120"><circle cx="60" cy="60" r="40"/><dot id="P" x="88" y="32"/></svg>
-->
A circle, and a point on it.

The <!-- point: P --> point sits on the circle. That is all for now.

<!-- pad #pyth: \\pin{lhs}{a^2 + b^2} = c^2 -->
[a] squared plus [b] squared equals [c] squared.

Look at the <!-- point: lhs --> left side. Then the <!-- point: pyth --> whole line.
"""


func _points() -> void:
	print("-- the pen points")
	var p := DeskScript.parse(POINTED)
	var pts: Array = (p["actions"] as Array).filter(func(a): return String(a["kind"]) == "point")
	var spoken: PackedStringArray = p["spoken"]
	_check(pts.size() == 3, "each point in speech is an action (%d)" % pts.size())
	if pts.size() != 3:
		return
	var first: Dictionary = pts[0]
	_check(spoken[int(first["after"])] == "point" and int(first["span"]) == 5,
		"a point is at the word after it, held to its sentence's end (%s, %d words)" % [spoken[int(first["after"])], first["span"]])
	_check(not String(p["speakable"]).contains("point:") and not spoken.has("p") and String(p["speakable"]).contains("The point sits"),
		"and is never spoken (the voice reads \"The point sits\")")
	var draw_i := -1
	var pad_i := -1
	for a in p["actions"]:
		if String(a["kind"]) == "draw":
			draw_i = int(a["i"])
		elif String(a["kind"]) == "pad":
			pad_i = int(a["i"])
	_check(int(first["of"]) == draw_i and String(first["part"]) == "P", "a drawing's part is found by its id")
	_check(int(pts[1]["of"]) == pad_i and String(pts[1]["part"]) == "lhs", "a formula's by its \\pin")
	_check(int(pts[2]["of"]) == pad_i and String(pts[2]["part"]) == "", "and a whole line by its mark's name")
	var twice := DeskScript.parse(POINTED.replace("Look at", "<!-- pad #circ: x -->\nEx.\n\nLook at") + "\nThe <!-- point: circ --> x.\n")
	var last: Dictionary = (twice["actions"] as Array).back()
	_check(String((twice["actions"][int(last["of"])] as Dictionary)["kind"]) == "pad",
		"a name written twice points at the latest")
	var bad := POINTED + "\nAnd the <!-- point: nowhere --> thing.\n"
	_check(DeskScript.unknown_points(bad) == PackedStringArray(["nowhere"]) and DeskScript.unknown_points(POINTED).is_empty(),
		"a point at a name nothing carries is caught (the control: the names that are there are not)")
	var in_dictation := DeskScript.parse("<!-- pad #x: x -->\nThe <!-- point: x --> ex.\n")
	_check((in_dictation["actions"] as Array).size() == 1, "a point inside a dictation is no action: the pen is writing")
	# THE PEN IS NEVER STILL FOR LONG
	var talk := ""
	for i in 12:
		talk += "This sentence says nothing that the pen could show at all. "
	var idle := POINTED + "\n" + talk + "\n"
	var busy := POINTED + "\n" + talk.substr(0, talk.length() / 2) + "See the <!-- point: P --> point. " + talk.substr(talk.length() / 2) + "\n"
	_check(DeskScript.still(idle).size() == 1 and DeskScript.still(busy).is_empty() and DeskScript.still(POINTED).is_empty(),
		"a long stretch over a still pen is caught (%s), and the same stretch broken by a point is not" % ", ".join(DeskScript.still(idle)))
	# AT THE DESK: the nib beside the thing as its word is said, the camera on it, no ink
	var draw_id := String(DeskScript.item("draw", String((p["actions"][draw_i] as Dictionary)["tex"]))["id"])
	var pad_id := String(DeskScript.item("pad", "\\pin{lhs}{a^2 + b^2} = c^2")["id"])
	var records := {
		draw_id: {"id": draw_id, "ok": true, "figure": true, "w": 270.0, "h": 90.0, "d": 0.0, "glyphs": [],
			"rules": [], "paths": [], "anchors": {"P": [200.0, -80.0, 204.0, -76.0]}},
		pad_id: {"id": pad_id, "ok": true, "w": 100.0, "h": 10.0, "d": 3.0, "glyphs": [], "rules": [],
			"anchors": {"lhs": [0.0, -10.0, 45.0, 2.0]}},
	}
	var desk := DeskMedium.new()
	desk.load_lesson(POINTED, {"seed": 3, "ink": {"items": records.values()}})
	var parsed := DeskScript.parse(POINTED, {}, records)
	desk._actions = parsed["actions"]
	desk._follower.extend(DeskScript.rehearsal(parsed))
	desk._build_plan()
	var at: Array = []
	for i in desk._actions.size():
		if String((desk._actions[i] as Dictionary)["kind"]) == "point":
			at.append(i)
	var pi := int(at[0])
	var pa: Dictionary = desk._actions[pi]
	var f := desk._follower
	var box := desk.target_box(pa)
	_check(absf(float(desk._plan[pi]["start"]) - f.st0[int(pa["after"])]) < 0.001,
		"at the desk the point starts as its word is said")
	_check(box.size.x > 0.0 and box.size.x < 20.0, "and points at the dot's own box, not the drawing's (%s)" % box)
	desk._now = f.st0[int(pa["after"])] + DeskMedium.POINT_SWEEP + 0.05
	var pen := desk.pen_at()
	var nib: Vector2 = pen["p"]
	_check(absf(float(pen["lift"]) - DeskMedium.POINT_LIFT) < 0.0001 and nib.x > box.end.x
		and nib.x - box.end.x < DeskMedium.POINT_GAP and nib.y > box.position.y and nib.y < box.end.y,
		"the nib comes down close, just right of the dot, within its height (%s by %s)" % [nib, box])
	var frame: Vector2 = desk._framing()["line"]
	_check(frame.distance_to(box.get_center()) < 0.5, "and the camera goes to it")
	_check(desk.page_state(0)["all"].find(pi) < 0, "and a point draws no ink")
	var wide := desk.target_box(desk._actions[int(at[2])])
	var w0 := f.st0[int((desk._actions[int(at[2])] as Dictionary)["after"])]
	desk._now = w0 + DeskMedium.POINT_SWEEP * 0.15
	var early: Vector2 = desk.pen_at()["p"]
	desk._now = w0 + DeskMedium.POINT_SWEEP * 0.6
	var later: Vector2 = desk.pen_at()["p"]
	desk._now = w0 + DeskMedium.POINT_SWEEP + 0.05
	var ends: Vector2 = desk.pen_at()["p"]
	_check(wide.size.x >= DeskMedium.POINT_WIDE and early.y > wide.end.y and later.y > wide.end.y and later.x > early.x + 50.0
		and ends.x > wide.end.x and ends.y < wide.end.y,
		"a wide thing is swept under, left to right, and the nib stays beside its end (%s, %s, %s by %s)" % [early, later, ends, wide])
	# the control: the same point on another page than its target leaves the pen where it was
	(desk._actions[pi] as Dictionary)["page"] = 1
	desk._now = f.st0[int(pa["after"])] + DeskMedium.POINT_SWEEP + 0.05
	var stays: Dictionary = desk.pen_at()
	_check(desk.target_box(desk._actions[pi]).size.x < 0.0 and absf(float(stays["lift"]) - DeskMedium.POINT_LIFT) > 0.001,
		"the control: a point at a page already turned leaves the pen where it was (lift %.4f)" % float(stays["lift"]))
	desk.free()


func _scrub() -> void:
	print("-- a reading started mid-way")
	var parsed := DeskScript.parse(LESSON, _lengths())
	var spoken: PackedStringArray = parsed["spoken"]
	var third: Dictionary = parsed["actions"][2]
	var from := int(third["after"]) - 3
	var all := DeskScript.rehearsal(parsed)
	var heard: Array = []
	for w in all.slice(from):
		heard.append({"text": String(w["text"]), "t0": float(w["t0"]) - float(all[from]["t0"]) + 1.0,
			"t1": float(w["t1"]) - float(all[from]["t0"]) + 1.0, "sentence": 0})
	var found := DeskMedium.new()
	found.load_lesson(LESSON, {"seed": 3}, spoken.slice(from, from + 6))
	found._actions = parsed["actions"]
	found._follower.extend(heard)
	found._build_plan()
	var at := float(found._plan[2]["start"])
	_check(float(found._plan[0]["end"]) < 0.0 and float(found._plan[1]["end"]) < 0.0,
		"handed the new reading's first words, what came before them is written by the first frame")
	_check(absf(at - (float(heard[3]["t0"]) - DeskMedium.PEN_LEAD)) < 0.01,
		"and the next formula is scheduled at its own words (%.2f s)" % at)
	found._now = at + 0.6
	_check(found._ink_time(2) > 0.0 and float(found.pen_at()["lift"]) < DeskMedium.REST_LIFT * 0.5,
		"and the pen is down at it, writing (%.2f s of ink)" % found._ink_time(2))
	var lost := DeskMedium.new()
	lost.load_lesson(LESSON, {"seed": 3})
	lost._actions = parsed["actions"]
	lost._follower.extend(heard)
	lost._build_plan()
	_check(float(lost._plan[2]["start"]) == INF,
		"the control: the same reading matched from the top finds none of its words, and nothing after the scrub is scheduled")
	found.free()
	lost.free()


func _alive() -> void:
	print("-- the hand is alive")
	var base := DeskMedium.PEN_UP.normalized()
	var most := 0.0
	var widest := 0.0
	var toward := true
	for i in 200:
		var up := DeskMedium.lean(DeskMedium.PEN_UP, i * 0.1, 3, 0.7, Vector3.ZERO)
		most = maxf(most, rad_to_deg(up.angle_to(base)))
		if i > 0:
			widest = maxf(widest, rad_to_deg(up.angle_to(DeskMedium.lean(DeskMedium.PEN_UP, 0.0, 3, 0.7, Vector3.ZERO))))
		toward = toward and up.x > 0.0 and up.z < 0.0 and up.y > 0.5
	_check(widest > 3.0, "the pen's lean sways over twenty seconds (%.1f degrees at most apart; the old fixed lean, 0)" % widest)
	_check(most < DeskMedium.SWAY_YAW + DeskMedium.SWAY_TILT + 1.0 and toward,
		"always toward the top right, within %.1f degrees of its lean" % most)
	_check(DeskMedium.lean(DeskMedium.PEN_UP, 4.2, 3, 0.5, Vector3.ZERO) == DeskMedium.lean(DeskMedium.PEN_UP, 4.2, 3, 0.5, Vector3.ZERO)
		and DeskMedium.lean(DeskMedium.PEN_UP, 4.2, 3, 0.5, Vector3.ZERO) != DeskMedium.lean(DeskMedium.PEN_UP, 4.2, 4, 0.5, Vector3.ZERO),
		"the same moment is the same lean, and another hand sways otherwise")
	var still := DeskMedium.lean(DeskMedium.PEN_UP, 2.0, 3, 0.5, Vector3.ZERO)
	var moving := DeskMedium.lean(DeskMedium.PEN_UP, 2.0, 3, 0.5, Vector3(0.04, 0.0, 0.0))
	_check(moving.x < still.x - 0.02, "its top trails the nib: writing to the right tips it left (%.3f -> %.3f)" % [still.x, moving.x])
	var left := DeskMedium.lean(DeskMedium.PEN_UP, 2.0, 3, 0.1, Vector3.ZERO)
	_check(left.x < still.x and left.z < still.z, "and a nib at the page's left turns it toward the page's top")
	var writing: Dictionary = DeskMedium.drift(3.3, 3, 0.0)
	var resting: Dictionary = DeskMedium.drift(3.3, 3, DeskMedium.REST_LIFT)
	_check((writing["dp"] as Vector2) == Vector2.ZERO and float(writing["dlift"]) == 0.0
		and (resting["dp"] as Vector2).length() > 1.0,
		"the nib drifts at rest (%s px) and never while it writes" % resting["dp"])


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


## THE PEN IS ELASTIC (the user, 2026-10-17: "the pen stopping at weird moments - like halfway between
## drawing a straight line, pausing for a second or two ... NEVER should we just be stopping"): over a
## dictation with a long pause in it, the pen slows and never stands still, and makes it up after;
## the control, the old clock (the share of the words said), stands still through the pause.
func _elastic() -> void:
	print("-- the elastic pen")
	# ten words, 0.3 s each and 0.08 apart, with a breath of 1.6 s after the fourth
	var t0s := PackedFloat32Array()
	var t1s := PackedFloat32Array()
	var t := 2.0
	for j in 10:
		t0s.append(t)
		t1s.append(t + 0.3)
		t += 0.38 + (1.6 if j == 3 else 0.0)
	var start := t0s[0] - DeskMedium.PEN_LEAD
	var end := t1s[9]
	var dt := 1.0 / 30.0
	var mean := 1.0 / (end - start)
	var least := INF
	var most := 0.0
	var prev := 0.0
	var back := false
	var stood := 0.0          # the longest the old clock stood still while writing
	var still := 0.0
	var old_prev := 0.0
	var off := 0.0            # how far the pen strays from the words, at each word's end
	var tt := start
	while tt < end - dt * 0.5:
		tt += dt
		var p := DeskMedium.elastic(tt, start, end, t0s, t1s)
		var v := (p - prev) / dt / mean
		least = minf(least, v)
		most = maxf(most, v)
		back = back or p < prev
		prev = p
		var old := _share_said(tt, t0s, t1s)
		still = still + dt if old - old_prev < 1e-6 and old < 1.0 and old > 0.0 else 0.0
		stood = maxf(stood, still)
		old_prev = old
	for j in 10:
		off = maxf(off, absf(DeskMedium.elastic(t1s[j], start, end, t0s, t1s) - float(j + 1) / 10.0))
	_check(DeskMedium.elastic(start, start, end, t0s, t1s) == 0.0 and DeskMedium.elastic(end, start, end, t0s, t1s) == 1.0
		and not back, "the pen's clock runs from nothing at the pen's touch to all of it at the last word, never back")
	_check(least >= 0.25, "it never stands still - its slowest is %.2f of its average pace" % least)
	_check(stood >= 1.5, "the control: the old clock, the share of the words said, stood still %.1f s in the breath" % stood)
	_check(most <= 2.0, "and never races - its fastest is %.2f of its average pace" % most)
	_check(off <= 0.15, "it keeps with the words: at each word's end it is within %.2f of their share" % off)
	var mid := (t1s[3] + t0s[4]) * 0.5
	var in_breath := (DeskMedium.elastic(mid + 0.1, start, end, t0s, t1s) - DeskMedium.elastic(mid - 0.1, start, end, t0s, t1s)) / 0.2 / mean
	var after := (DeskMedium.elastic(t1s[6], start, end, t0s, t1s) - DeskMedium.elastic(t0s[5], start, end, t0s, t1s)) / (t1s[6] - t0s[5]) / mean
	_check(in_breath < 0.75 and after > 1.0,
		"it slows in the breath (%.2f of its average pace) and makes it up over the words after (%.2f)" % [in_breath, after])
	# THE PEN THAT LAGS runs the whole way behind, evenly: no slowing as the voice ends
	var late := start + (end - start) * 2.5
	var lmean := 1.0 / (late - start)
	var tail_v := (DeskMedium.elastic(late - 0.2, start, late, t0s, t1s) - DeskMedium.elastic(late - 0.6, start, late, t0s, t1s)) / 0.4 / lmean
	_check(tail_v >= 0.7, "a pen that lags its words does not slow as they end (%.2f of its average pace in the rest)" % tail_v)


## The old clock, for the control: the share of words [param t0s]..[param t1s] said at [param t].
func _share_said(t: float, t0s: PackedFloat32Array, t1s: PackedFloat32Array) -> float:
	var done := 0.0
	for j in t0s.size():
		if t < t0s[j]:
			break
		done += clampf((t - t0s[j]) / (t1s[j] - t0s[j]), 0.0, 1.0)
	return done / float(t0s.size())


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
	_check(absf(share - 0.5) < 0.07, "halfway through the words, about halfway through the writing (%.2f)" % share)
	desk._now = float(plan["start"])
	_check(desk._ink_time(1) == 0.0, "nothing written before the pen is down")
	desk._now = float(plan["end"]) + 0.1
	_check(desk._ink_time(1) == float(act["write"]), "and all of it once the words are said")
	var slow: Dictionary = desk._actions[2]
	var sp: Dictionary = desk._plan[2]
	desk._now = float(f.st1[int(slow["after"]) + 5]) + 0.01
	var lag := desk._ink_time(2)
	desk._now += 0.1
	var on := desk._ink_time(2)
	_check(absf(float(sp["end"]) - float(sp["start"]) - float(slow["write"]) / DeskScript.MAX_PACE) < 0.001
		and lag < float(slow["write"]) and on > lag,
		"a formula that outlasts its words is written at the pen's fastest, and is still being written in the rest (%.2f of %.0f)"
		% [lag, float(slow["write"])])
	_check(float(sp["end"]) <= float(f.st0[int(slow["after"]) + 6]),
		"before the voice goes on")
	_elastic()
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
	# THE PAGE IS REDRAWN ONLY WHEN WHAT IT SHOWS CHANGES: a redraw rebuilds every stroke on it, and
	# redrawn every frame over a page that stood still all night, the engine crashed freeing one
	var dry_c := DeskMedium.PadCanvas.new()
	dry_c.part = "dry"
	var wet_c := DeskMedium.PadCanvas.new()
	wet_c.part = "wet"
	dry_c.forget()
	wet_c.forget()
	var still := float(f.st1[f.st1.size() - 1])
	for p in desk._plan:
		still = maxf(still, float((p as Dictionary)["end"]))
	var redraws := 0
	for k in 300:
		desk._now = still + 0.5 + k / 60.0
		var st := desk.page_state(0)
		redraws += int(dry_c.show_page(0, st["dry"])) + int(wet_c.show_page(0, st["wet"]))
	_check(redraws == 2, "a page that stands still is drawn once, not every frame (%d redraws of its two parts in 300 frames)" % redraws)
	desk._now = float(f.st0[first + 1])
	var w0 := desk.page_state(0)
	desk._now = float(f.st0[first + 3])
	var w1 := desk.page_state(0)
	_check(w0["wet"] != w1["wet"] and w0["dry"] == w1["dry"],
		"the control: as the pen writes, what it is writing is redrawn and the rest is not (wet %s -> %s)" % [w0["wet"], w1["wet"]])
	desk._now = float(plan["end"]) - 0.05
	var e0 := desk.page_state(0)
	desk._now = float(plan["end"]) + 0.05
	var e1 := desk.page_state(0)
	_check(not (e0["dry"] as Array).has(1) and (e1["dry"] as Array).has(1), "and a formula goes under the dry ink as it is finished")
	var s := -1
	for i in desk._actions.size():
		if String((desk._actions[i] as Dictionary)["kind"]) == "strike":
			s = i
	var sp_page := int((desk._actions[int((desk._actions[s] as Dictionary)["of"])] as Dictionary)["page"])
	desk._now = float(desk._plan[s]["start"]) + DeskScript.STRIKE * 0.5
	var mid := [desk.page_ink(sp_page, "wet").size(), desk.page_ink(sp_page, "dry").size()]
	desk._now = float(desk._plan[s]["start"]) + DeskScript.STRIKE + 0.01
	var done := [desk.page_ink(sp_page, "wet").size(), desk.page_ink(sp_page, "dry").size()]
	_check(mid == [1, 0] and done == [0, 1], "a strike is wet as it is drawn and dry once it is (%s %s)" % [mid, done])
	dry_c.free()
	wet_c.free()
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
	_check(rests.size() == 5 and absf(rests[2] - DeskScript.LEAD_HOLD - DeskScript.TURN) < 0.011,
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
