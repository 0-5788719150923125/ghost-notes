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
##   the solve deletes its notebook, its Lean file, its runs and data and everything made after it, and
##   nothing else.
## - NOT EVERY CLAIM IS A THEOREM (the user, 2026-10-19: "it should be a general theorem-prover and
##   learning tool"): a COMPUTATION is framed with what it computes and no Lean statement (one that does
##   not say what it computes is refused - the control), and a problem framed before there were
##   computations is a proof; the framer is offered a computation only where code can run (the
##   control, without); a computation's solver is told what is computed and given no Lean, a proof's
##   with no sandbox is given no run (the control); a computed lesson's teacher is shown the runs that
##   show the result, first, and the series they kept, says the numbers come from code that ran and is
##   never told of Lean (the control, a computation that did not settle it, says so); a result naming a
##   run that did not finish is refused (the control, one that did, accepted) and lands `computed`;
##   the upload says the numbers were computed; and no teacher or student is told a viewer's level
##   the framer's audience did not give.
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
##   spoken, whichever side of it the lesson spaced (2026-10-19: "onlythe" in the subtitles, from
##   `only <!-- point: x -->the`; the control is the old cut, which took the space before it alone);
##   it finds the latest thing written under its name - a mark's #name, a drawing's id, a
##   formula's \pin - and a name nothing carries is caught (the control: the names that are there are
##   not). At the desk the nib comes down beside the thing as the word is said - a wide one swept under
##   first - the camera goes to it and no ink is drawn; a point at a page already turned leaves the pen where it was (the control).
##   A sweep the next point cuts short ends where the pen waits from (2026-10-20: cut at a third of its
##   sweep, the nib jumped 366 px in a frame in a live replay - the control, the sweep at its own pace).
## - THE PEN IS NEVER STILL FOR LONG: a long stretch of speech with the pen idle is caught, and the same
##   stretch broken by a point is not (the control).
## - AN IDLE PEN GETS OUT OF THE WAY (the user, 2026-10-19: "the pen was just frozen, right in the middle
##   of the page, covering a bunch of the text's visibility"): over a long aside the nib sets off from
##   where its action left it (the old wait jumped 136 px in a frame), goes right, then up, waits off the
##   pad's top right and is back as the next formula begins at a hand's pace (the old reach, 0.45 s
##   however far, is the control); over a short wait it stays by its line (the control). A page turns
##   only once the pen is off the pad, and the pen comes back behind the sheet: the pen, a rod along
##   its lean, never meets the turning sheet - the old wait at the page's right did.
## - A PAGE IS TURNED AS A HAND TURNS ONE ([LegalPad]; the user, 2026-10-19: "it sort of just disappears
##   ... gently lifts the head of the pad and folds the paper around the back ... a turned page will
##   COVER that top part of the paper. And multiple pages might fan-apart a bit"): the sheet starts
##   flat where the page lay and ends round the pad's head, its end under the pad; the head is lifted
##   for it and down before the pen comes back; eight pages over, their loops never cross nor go into
##   the pad, each reaching further round the head, and a ninth turned over them never crosses one
##   (the control, the same sheet given the innermost loop, does); the outermost loop's bulge stays
##   above the first rule, and the pen writing the top line never meets it (the control, a loop twice
##   as round, it does).
## - EVERY DESK IS ITS OWN ([DeskLook]; the user: "a little bit of variety, of color, of the table, of
##   objects on the table"): the same seed is the same desk; across seeds the paper, the ink, the top
##   and the things vary; the ink always reads on its paper (the control, the paper's own color, does
##   not); a thing is never put on the pad, behind it where the turned pages lie, or - a tall one -
##   beside its right edge where the pen leans out (the control: the same draws with no rule land there).
##   NO DESK WAITS FOR A PAINTING (the user: "There is nowhere to set the 'Painter' on the Proof card;
##   so how would the generative table and props even work there?"): the card table's one painted
##   surface - a top or a layer that IS the episode's painting - is never chosen, so a built desk lays
##   the painting on nothing (controls: the same desk with its top the painting, and with its layers
##   left out, which is the old reading cloth).
## - A READING STARTED MID-WAY (the user, 2026-10-16: "scrubbing the timeline seems to have broken the
##   pen completely. For the remainder of the video, the pen doesn't move at all"): handed the new
##   reading's first words, the desk finds its place - what came before is written, the next formula
##   is scheduled and the pen writes it; the control, the same words with no start, finds none of
##   its words - the rest unscheduled, which is what the user saw, or (since a word the voice went past
##   is placed, 2026-10-20) scheduled on stray matches, never at the words.
## - WHAT IS ON THE PAGE STAYS (2026-10-19: "two graphs are drawn side-by-side. Then suddenly, the 2nd
##   one disappears and is re-drawn"): a formula dictated over three sentences, its words' times
##   arriving a sentence at a time a little before each is heard, from a voice slower than the guess -
##   handed them as a live reading hands them ([method DeskMedium.take_words]), its ink never goes back,
##   never outruns the pen, and is all written by its last word; the control, the plan made again
##   without holding the past, takes back strokes already written. And no reach is squeezed: a point
##   said while its formula is still being written waits the nib's way from it, crossed at a pen's pace
##   - the control, the point begun the moment the formula ends, crosses the page in a frame.
## - A WORD THE VOICE SAYS ITS OWN WAY NEVER HOLDS THE DESK (2026-10-20: "the pen just stood in one place
##   swaying for the rest of the video" - "[c]'s" said as "c" and "'s" sent the matcher seven words on,
##   and the plan waited on a word never heard): a one-letter word starts the page's next word and the
##   words after keep their own times; a dictation whose first word is said another way ("seven") is
##   written as that word is said - the control, the page's word itself never matched; and a last word
##   said its own way is said when the voice's last word is.
## - A DRAWING TAKES ITS TIME (the same day: "chart and picture-drawing felt REALLY fast, relative to the
##   voice describing the charts"): its ink outlasting its short line, it runs on into the talk about it
##   and is done a settle and the nib's way before the point at it, which is on its word as before - the
##   control, a formula as long held to its words; and one with the room is drawn at the hand's own pace.
## - THE HAND IS ALIVE (the same day: "A hand holding a pen would never keep it at a perfectly static
##   angle"): the pen's lean sways over seconds - the old fixed lean is the control - always toward the
##   top right and within a few degrees of it; it is the same at the same moment, another hand's sways
##   otherwise; its top trails the nib's travel; and the nib drifts at rest and never while it writes.
## - A LESSON'S LENGTH IS ITS OWN (the user, 2026-10-16: "make videos as long as they need to be"): with
##   no length in the note, no agent is handed minutes or words, and a lesson of thousands of words
##   lands on its first try - against the same lesson with a pad line left unread, which still goes back.
## - BUT THE ONE ITS NOTE ASKS FOR (2026-10-20: "a 5-10 minute request in the script turned into a
##   36-minute export"): the framer's `minutes` is kept only when sound; the teacher is handed it in
##   spoken words in place of "no set length", the second draft and the student how long the first runs;
##   a lesson's runtime is its spoken words at DeskScript.SAID_WORD and its rests; and the same long
##   lesson goes back under a note asking "5 to 10 minutes", told by how much - a lesson inside it lands.
## - EVERY TAKE IS CHECKED (2026-10-19: "Was the problem fixed or not?"): a first take over a still pen
##   goes back, a mended second is taken, and what the first was sent back for is still in the prompt a
##   take after TeX's send-back gets - a fresh lesson's is not; a take out of tries is kept with its
##   faults named for the log, a mended one has none.
## - THE THUMBNAIL (the user: "did not use the proper thumbnail ... the same thumbnail that cards-based
##   modes use"): a Proof upload names the title screen's moment, the name fully up over the blur - on
##   the first frame, since [ProofCard] names the Director, which a script's `_init` has not got. Its
##   tags are the note's alone, the one list the YouTube card shows (2026-10-19).
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
	_live()
	_heard()
	_drawn()
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
	var cards: Script = load("res://src/table_show/episode_card.gd")
	_check(absf(at - ShowOpening.thumbnail_moment(9.0)) < 0.001 and absf(at - float(cards.thumbnail_moment(9.0))) < 0.001,
		"a Proof upload names the thumbnail's moment, the card shows' own (%.2f s)" % at)
	_check(ShowOpening.title_alpha(at, 9.0, true) == 1.0 and ShowOpening.pull(at, 9.0, true) == 0.0,
		"and at that moment the name is fully up over the desk out of focus")
	_check(String(up.get("description", "")).contains("checked by the Lean theorem prover (Lean 4.35.0")
		and up.get("tags", []) == ["math"], "with the description, the check, and the note's tags alone - the framer's \"induction\" is not added unseen")
	var comp := ProofEpisode.open("thumb-note", 2)
	comp.write_json("problem", COMPUTED.merged({"description": "The pendulum, integrated."}))
	comp.write_json("solve", {"verified": false, "computed": true, "runs": 4})
	var cdesc := String(card.upload_of(comp, {"title": "Pen & Ink"}, PackedStringArray(), 9.0).get("description", ""))
	_check(cdesc.contains("come from code that was run for it") and not cdesc.contains("Lean"),
		"a computed episode's upload says its numbers were computed, and never names Lean")
	var take := _scratch.path_join("take_1.wav")
	# closed here: a temporary FileAccess can live (unflushed) to the end of the function
	var side := FileAccess.open(take.get_basename() + ".json", FileAccess.WRITE)
	side.store_string(JSON.stringify({"bookend": {"in": 9.0, "out": 9.0}}))
	side.close()
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


const COMPUTED := {"episode_title": "How Fast Does a Pendulum Swing?", "statement": "A pendulum swung wider takes longer to swing.",
	"latex": "\\ddot\\theta = -\\tfrac{g}{L}\\sin\\theta", "check": "computation",
	"computation": "the period of a 1 m pendulum, integrated for amplitudes from 10 to 90 degrees", "lean": "",
	"forbidden": [], "history": "", "audience": "students who know what a derivative is"}


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
	var yes := ProofPrompts.teacher("Ghost Notes", "a note", PROBLEM, "## notes", "theorem main", {"verified": true})
	var no := ProofPrompts.teacher("Ghost Notes", "a note", PROBLEM, "## notes", "theorem main", {"verified": false})
	var fix := ProofPrompts.teacher("Ghost Notes", "a note", PROBLEM, "", "", {"verified": true},
		{"broken": ["\\frac{1}{: Missing } inserted."], "notation": ["so $x^2$ grows"], "undictated": ["n^2 + 1"],
		"letters": ["Take a equal to two."]})
	var again := ProofPrompts.teacher("Ghost Notes", "a note", PROBLEM, "## notes", "theorem main", {"verified": true}, {},
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
	# BUT THE ONE ITS NOTE ASKS FOR (2026-10-20): read off the note by the framer, handed the teacher in
	# spoken words, and the second draft and the student told how long the first runs
	var asked := PROBLEM.duplicate()
	asked["minutes"] = [5.0, 10.0]
	var span := "%d to %d spoken words" % [ProofPrompts.words_in(5.0), ProofPrompts.words_in(10.0)]
	var held := ProofPrompts.teacher("Ghost Notes", "a note", asked, "## notes", "theorem main", {"verified": true})
	var held2 := ProofPrompts.teacher("Ghost Notes", "a note", asked, "## notes", "theorem main", {"verified": true}, {},
		LESSON, [{"quote": "x", "need": "y"}])
	var stu2 := ProofPrompts.student("Ghost Notes", "a note", asked, LESSON)
	texts.append_array([held["prompt"], held2["prompt"], stu2["prompt"]])
	_check(String(fr["prompt"]).contains("\"minutes\"") and String(fr["prompt"]).contains("never one you choose"),
		"the framer reads the length the note asks for, and is told never to choose one")
	_check(String(held["prompt"]).contains("about 5 to 10 minutes - about " + span) and not String(held["prompt"]).contains("no set length")
		and not String(held["prompt"]).contains("YOUR FIRST DRAFT RUNS"),
		"a note's length is handed the first draft in spoken words (%s), in place of none" % span)
	var draft_runs := ProofPrompts.said_num(snappedf(DeskScript.runtime(LESSON) / 60.0, 0.5))
	_check(String(held2["prompt"]).contains("YOUR FIRST DRAFT RUNS ABOUT %s MINUTES (%d spoken words)" % [draft_runs,
		(DeskScript.parse(LESSON)["spoken"] as PackedStringArray).size()])
		and String(held2["prompt"]).contains("Write it to the length the author asked for")
		and not String(again["prompt"]).contains("YOUR FIRST DRAFT RUNS"),
		"the second draft is told how long the first runs (the control: with no length asked, it is not)")
	_check(String(stu2["prompt"]).contains("about 5 to 10 minutes, and this draft runs about %s minutes" % draft_runs)
		and not String(stu2["prompt"]).contains("leave out to come down") and not String(stu["prompt"]).contains("this draft runs"),
		"the student is told the length and the draft's, and a draft inside it is not cut (the control: none asked, none said)")
	# NOT EVERY CLAIM IS A THEOREM: a computation, framed, solved and taught
	var fr_run := String(ProofPrompts.framer("Ghost Notes", "a note", "", [], true)["prompt"])
	_check(fr_run.contains("\"check\"") and fr_run.contains("\"computation\"") and fr_run.contains("proof or computation")
		and not bare.contains("\"computation\"") and not bare.contains("or computation"),
		"the framer is offered a computation where code can run (the control, with none, only a proof)")
	var so_c := ProofPrompts.solver("Ghost Notes", "a note", COMPUTED, true)
	var so_n := ProofPrompts.solver("Ghost Notes", "a note", PROBLEM, false)
	texts.append_array([so_c["prompt"], so_n["prompt"], fr_run])
	_check(String(so_c["prompt"]).contains("What is computed, fixed before you start") and String(so_c["prompt"]).contains("- run:")
		and not String(so_c["prompt"]).contains("Lean 4 statement") and not String(so_c["prompt"]).contains("- lean:")
		and not String(so_n["prompt"]).contains("- run:") and String(so_n["prompt"]).contains("- lean:"),
		"a computation's solver is told what is computed and given no Lean; a proof's with no sandbox no run (the control)")
	var runs := [{"n": 1, "code": "print(1)", "exit": 1, "timed_out": false, "stdout": "", "stderr": "boom", "error": ""},
		{"n": 2, "code": "keep('period', [10, 20], [2.007, 2.016])\nprint('T at 10 degrees: 2.007')", "exit": 0,
		"timed_out": false, "stdout": "T at 10 degrees: 2.007\n", "stderr": "", "error": ""}]
	var data := {"period": {"points": [[10.0, 2.007], [20.0, 2.016]], "about": "seconds, by amplitude", "run": 2}}
	var done := ProofPrompts.teacher("Ghost Notes", "a note", COMPUTED, "## notes", "", {"computed": true,
		"result": "The period grows with the amplitude.", "evidence": [2]}, {}, "", [], runs, data)
	var undone := ProofPrompts.teacher("Ghost Notes", "a note", COMPUTED, "## notes", "", {"computed": false}, {}, "", [], runs, {})
	texts.append_array([done["prompt"], undone["prompt"]])
	var dp := String(done["prompt"])
	_check(dp.contains("The period grows with the amplitude.") and dp.contains("code that was run for this lesson")
		and dp.find("Run 2 (the result names it)") < dp.find("run 1: did not finish") and dp.contains("print('T at 10 degrees")
		and dp.contains("- period: 2 points") and dp.contains("<plot data=\"NAME\"/>"),
		"a computed lesson's teacher is shown the result, the runs that show it first, and the series they kept")
	_check(not dp.contains("what Lean is") and not dp.contains("Lean proof") and not dp.contains("did NOT settle"),
		"and is never told of Lean")
	_check(String(undone["prompt"]).contains("did NOT settle") and not String(undone["prompt"]).contains("code that was run for this lesson")
		and not String(undone["prompt"]).contains("<plot data="),
		"the control: a computation that did not settle it is told to say so, and offered no series to draw")
	var levels := PackedStringArray()
	for t2 in [yes, done, stu]:
		if String((t2 as Dictionary)["prompt"]).contains("fractions and a little algebra"):
			levels.append(String((t2 as Dictionary)["prompt"]).substr(0, 30))
	_check(levels.is_empty() and String(done["prompt"]).contains(String(COMPUTED["audience"])),
		"no teacher or student is told a viewer's level the framer's audience did not give")
	var inv_run := String(ProofPrompts.inventor(7, [], true)["prompt"])
	_check(inv_run.contains("a short program can compute") and not String(inv["prompt"]).contains("a short program can compute"),
		"the inventor may propose a computation where code can run (the control, without, may not)")
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
	for step in ["problem", "solve", "draft", "review", "lesson", "ink", "script", "notebook", "proof", "runs", "data"]:
		ep.write_text(step, "{}" if step in ["problem", "solve", "review", "ink", "data"] else ("[]" if step == "runs" else "x"))
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
	ep.write_text("runs", "[]")
	ep.write_text("data", "{}")
	ep.invalidate("solve")
	var gone := PackedStringArray()
	var kept := PackedStringArray()
	for step in ["problem", "solve", "draft", "review", "lesson", "ink", "script", "notebook", "proof", "runs", "data"]:
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
	# BUT THE ONE ITS NOTE ASKS FOR: a runtime is its spoken words at SAID_WORD and its rests
	var p := DeskScript.parse(long)
	var rests := 0.0
	for r in _rests(String(p["speakable"])):
		rests += r
	var runs := DeskScript.runtime(long)
	_check(absf(runs - (words * DeskScript.SAID_WORD + rests)) < 0.01 and rests > 0.0 and DeskScript.runtime("no marks here") == 0.0,
		"a lesson runs its spoken words at %.2f s and its rests (%.0f s, %.0f s of them rests)" % [DeskScript.SAID_WORD, runs, rests])
	var asked := ProofEpisode.open("length-check", 3)
	asked.write_json("problem", ProofProducer.land_problem({"episode_title": "x", "statement": "y",
		"lean": "theorem main : True", "minutes": [10, 5]}))
	var producer := ProofProducer.new(asked, {})
	producer._tries["lesson"] = 1
	var sent := producer._land_lesson(long)
	_check(sent.contains("it runs about %s minutes (%d spoken words), past the 5 to 10 minutes" % [ProofPrompts.said_num(snappedf(runs / 60.0, 0.5)), words])
		and not asked.has("lesson"), "under a note asking 5 to 10 minutes, the same lesson goes back, told by how much (%s)" % sent)
	var told := String(ProofPrompts.teacher("T", "", producer._problem(), "", "", {}, producer._fix, "draft")["prompt"])
	_check(told.contains("LAST TIME THE LESSON RAN about") and told.contains("Write it to about %d to %d spoken words" % [
		ProofPrompts.words_in(5.0), ProofPrompts.words_in(10.0)]), "and the next take is told so, in words")
	var cut := ""
	for i in 12:
		cut += "<!-- pad: %d + 1 = %d -->\n%d plus one equals %d.\n\n" % [i, i + 1, i, i + 1]
		for j in 4:
			cut += "The sum grows by one at every step, and the next step is the same. "
		cut += "\n\n"
	producer._tries["lesson"] = 2
	var fits := producer._land_lesson(cut)
	_check(fits.is_empty() and asked.has("lesson") and DeskScript.runtime(cut) < 10.0 * 60.0,
		"the control: a lesson inside it lands (%.1f minutes; %s)" % [DeskScript.runtime(cut) / 60.0, fits])
	var over := String(ProofPrompts.student("T", "", producer._problem(), long)["prompt"])
	_check(over.contains("leave out to come down to that length"), "a student reading a draft past it marks what could go")



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
	# A MARK WRITTEN AGAINST ITS WORD (2026-10-19: the subtitles read "onlythe" and "drawing,the"):
	# the same words, each point at the same word, and no space left before punctuation
	var tight := DeskScript.parse(POINTED.replace("--> ", "-->") + "\nSee it here <!-- point: P -->.\n")
	var tight_pts: Array = (tight["actions"] as Array).filter(func(a): return String(a["kind"]) == "point")
	var tight_said := String(tight["speakable"])
	_check(tight_said.contains("The point sits") and tight_said.contains("Look at the left side. Then the whole line.")
		and tight_said.contains("See it here.") and (tight["spoken"] as PackedStringArray).slice(0, spoken.size()) == spoken
		and tight_pts.size() == 4 and int(tight_pts[1]["after"]) == int(pts[1]["after"]),
		"a mark written against its word leaves the words apart and the point at its word")
	var old_cut := RegEx.create_from_string(" ?" + DeskScript.POINT).sub("Look at the <!-- point: lhs -->left side.", "", true)
	_check(old_cut == "Look at theleft side.", "the control: the old cut, the space before the mark taken alone, fuses them (%s)" % old_cut)
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
	# EVERY TAKE IS CHECKED, AND WHAT ONE WAS SENT BACK FOR IS KEPT
	var takes := ProofProducer.new(ProofEpisode.open("takes-check", 1), {})
	takes._tries["lesson"] = 1
	var sent := takes._land_lesson(idle)
	_check(sent.contains("stands still") and not takes.episode.has("lesson"), "a first take over a still pen goes back (%s)" % sent)
	takes._tries["lesson"] = 2
	var mended := takes._land_lesson(busy)
	_check(mended.is_empty() and takes.episode.has("lesson"), "the second take, mended, is taken (%s)" % mended)
	var told := String(ProofPrompts.teacher("T", "", {"statement": "s"}, "", "", {}, takes._fix, "draft")["prompt"])
	var untold := String(ProofPrompts.teacher("T", "", {"statement": "s"}, "", "", {}, {}, "draft")["prompt"])
	_check(told.contains("STOOD STILL") and told.contains(DeskScript.still(idle)[0]) and not untold.contains("STOOD STILL"),
		"a take TeX sends back after it is still told what the first was sent back for (the control: a fresh lesson is not)")
	takes._tries["lesson"] = 3
	var kept := takes._land_lesson(idle)
	_check(kept.is_empty() and ProofProducer.lesson_faults({"still": DeskScript.still(idle)}).contains("stands still")
		and ProofProducer.lesson_faults({"still": DeskScript.still(busy)}).is_empty(),
		"a take out of tries is kept, its faults named for the log (the control: a mended one has none)")
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
	# A POINT THE NEXT ONE CUTS SHORT sweeps all the same, and ends where the pen waits from
	var wi := int(at[2])
	var uncut: Dictionary = (desk._plan[wi] as Dictionary).duplicate()
	desk._plan[wi]["end"] = w0 + 0.3
	desk._now = w0 + 0.3 - 1.0 / 60.0
	var cut: Vector2 = desk.pen_at()["p"]
	desk._now = w0 + 0.3 + 1.0 / 60.0
	var after_cut: Vector2 = desk.pen_at()["p"]
	var sweep := desk.point_path(desk._actions[wi])
	var was_cut: Vector2 = (sweep[0] as Vector2).lerp(sweep[1], DeskMedium._ease(0.3 / DeskMedium.POINT_SWEEP / 0.7))
	_check(cut.distance_to(after_cut) < 40.0 and was_cut.distance_to(sweep[2]) > 100.0,
		"a sweep cut to 0.3 s by the next point ends where the pen waits from (%.0f px in a frame; the control, the sweep at its own pace, %.0f px)" % [cut.distance_to(after_cut), was_cut.distance_to(sweep[2])])
	desk._plan[wi] = uncut
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
	_check(absf(float(lost._plan[2]["start"]) - at) > 1.0,
		"the control: the same reading matched from the top does not find its words, and the next formula is not written at them (%.1f s)" % float(lost._plan[2]["start"]))
	found.free()
	lost.free()


const LIVE := """<!-- pad: x^2+y^2=r^2 -->
The first of three sentences is short. The second one says a little more than the first one did. The third and last sentence ends the line at last.
"""


func _live() -> void:
	print("-- what is on the page stays")
	var id := String(DeskScript.item("pad", "x^2+y^2=r^2")["id"])
	var parsed := DeskScript.parse(LIVE, {id: 14.0})
	# a voice slower than the rehearsal's, each word in the sentence it is said in
	var heard: Array = DeskScript.rehearsal(parsed)
	var said := LIVE.split("\n")[1].split(" ")
	var sentence := 0
	var first := {}
	for k in heard.size():
		var w: Dictionary = heard[k]
		w["t0"] = float(w["t0"]) * 1.4
		w["t1"] = float(w["t1"]) * 1.4
		w["sentence"] = sentence
		first[k] = sentence
		if String(said[k]).ends_with("."):
			sentence += 1
	var starts := {}
	for k in heard.size():
		if not starts.has(first[k]):
			starts[first[k]] = float((heard[k] as Dictionary)["t0"])
	var last_word := float((heard.back() as Dictionary)["t1"])
	var runs := {}
	for live in [true, false]:
		var desk := DeskMedium.new()
		desk.load_lesson(LIVE, {"seed": 3})
		desk._actions = parsed["actions"]
		var back := 0.0
		var fastest := 0.0
		var was := 0.0
		var built := -1
		var t := 0.0
		while t < last_word + 1.0:
			var n := 0
			while n < heard.size() and float(starts[first[n]]) - 2.0 <= t:
				n += 1
			desk._now = t
			if live:
				desk.take_words(heard.slice(0, n))
			else:
				desk._follower.extend(heard.slice(0, n))
				if n != built:
					built = n
					desk._build_plan()
			var u := desk._written(0) if float(desk._plan[0]["start"]) <= t else 0.0
			back = maxf(back, was - u)
			fastest = maxf(fastest, (u - was) * 14.0 * 30.0)
			was = u
			t += 1.0 / 30.0
		runs[live] = {"back": back, "fastest": fastest, "end": was}
		desk.free()
	var held: Dictionary = runs[true]
	_check(float(held["back"]) <= 0.0 and float(held["end"]) >= 1.0,
		"its ink never goes back as the voice's words arrive a sentence at a time, and is all written by the last word (%.2f)" % float(held["end"]))
	_check(float(held["fastest"]) < DeskScript.MAX_PACE * 2.0,
		"and never jumps ahead: at most %.1fx the pen's pace" % float(held["fastest"]))
	_check(float((runs[false] as Dictionary)["back"]) > 0.05,
		"the control: the plan made again without holding the past takes back %.0f%% of the formula" % (float((runs[false] as Dictionary)["back"]) * 100.0))
	# NO REACH IS SQUEEZED: a point said while the formula it names is still being written - its one
	# stroke ends at its right end, and the voice goes on 2.5 s sooner than the rest the pen was given
	var src := "<!-- pad #long: x -->\nEx.\n\nLook at <!-- point: long --> it now.\n"
	var long_id := String(DeskScript.item("pad", "x")["id"])
	var zig := PackedVector2Array()
	for j in 6:
		zig.append(Vector2(0.0 if j % 2 == 0 else 200.0, -5.0))
	var sched := Ink.schedule([{"points": zig, "width": 0.5}], 3)
	var recs := {long_id: {"id": long_id, "ok": true, "w": 200.0, "h": 10.0, "d": 3.0, "glyphs": [], "rules": [], "anchors": {}}}
	var wp := DeskScript.parse(src, {long_id: float(sched["length"])}, recs)
	var way := DeskMedium.new()
	way.load_lesson(src, {"seed": 3, "ink": {"items": recs.values()}})
	way._actions = wp["actions"]
	way._strokes[long_id] = sched
	var soon: Array = DeskScript.rehearsal(wp)
	for k in range(1, soon.size()):
		soon[k]["t0"] = float(soon[k]["t0"]) - 2.5
		soon[k]["t1"] = float(soon[k]["t1"]) - 2.5
	way.take_words(soon)
	var gap := float(way._plan[1]["start"]) - float(way._plan[0]["end"])
	var jump := func(desk: DeskMedium) -> float:
		var most := 0.0
		var t := float(desk._plan[0]["end"]) - 0.5
		desk._now = t
		var was: Vector2 = desk.pen_at()["p"]
		while t < float(desk._plan[1]["start"]) + 1.0:
			t += 1.0 / 30.0
			desk._now = t
			var nib: Vector2 = desk.pen_at()["p"]
			most = maxf(most, nib.distance_to(was))
			was = nib
		return most
	var paced: float = jump.call(way)
	_check(gap >= way._way(0, 1) - 0.001 and float(soon[3]["t0"]) < float(way._plan[0]["end"]),
		"a point said while its formula is still being written waits the nib's way from it (%.2f s)" % gap)
	way._plan[1]["start"] = way._plan[0]["end"]
	var squeezed: float = jump.call(way)
	_check(paced < 60.0 and squeezed > 200.0,
		"and the nib goes there at most %.0f px a frame; the control, the point begun as the formula ends, %.0f px" % [paced, squeezed])
	way.free()


const HEARD := """<!-- pad: c + d -->
[c] plus [d].

Each of the [c]'s and the [d] is a number.

<!-- pad: 7 + d -->
7 plus [d].

That is all.
"""


func _heard() -> void:
	print("-- a word the voice says its own way")
	var parsed := DeskScript.parse(HEARD, {})
	var spoken: PackedStringArray = parsed["spoken"]
	var cs := spoken.find("cs")
	var seven := spoken.find("7")
	# the voice: "[c]'s" said as two words, "7" as "seven", and its last word one the page does not have
	var heard: Array = []
	var seven_at := 0.0
	for w in DeskScript.rehearsal(parsed):
		var said: Dictionary = (w as Dictionary).duplicate()
		if String(said["text"]) == "cs":
			var mid := (float(said["t0"]) + float(said["t1"])) * 0.5
			heard.append({"text": "c", "t0": float(said["t0"]), "t1": mid, "sentence": 0})
			said = {"text": "'s", "t0": mid, "t1": float(said["t1"]), "sentence": 0}
		elif String(said["text"]) == "7":
			said["text"] = "seven"
			seven_at = float(said["t0"])
		heard.append(said)
	(heard.back() as Dictionary)["text"] = "everything"
	var desk := DeskMedium.new()
	desk.load_lesson(HEARD, {"seed": 3})
	desk._actions = parsed["actions"]
	desk.take_words(heard)
	var f := desk._follower
	var after_cs := heard.size() - 1
	for k in heard.size():
		if String((heard[k] as Dictionary)["text"]) == "'s":
			after_cs = k + 1
	_check(cs >= 0 and is_equal_approx(f.st0[cs], float((heard[cs] as Dictionary)["t0"]))
		and is_equal_approx(f.st0[cs + 1], float((heard[after_cs] as Dictionary)["t0"])),
		"\"[c]'s\" said as \"c\" and \"'s\" is the page's one word, and the words after it keep their own times")
	var second: Dictionary = desk._plan[1]
	_check(f.st0[seven] == ReadingFollower.NO_TIME and absf(float(second["start"]) + DeskMedium.PEN_LEAD - seven_at) < 0.001,
		"a dictation whose first word the voice says its own way (\"seven\") is written all the same, as that word is said (%.2f s; the control: the page's word was never matched)" % float(second["start"]))
	var last := spoken.size() - 1
	_check(f.known_last() < last and is_equal_approx(f.said1[last], float((heard.back() as Dictionary)["t1"])),
		"and a last word said its own way is said when the voice's last word is")
	desk.free()


## A DRAWING TAKES ITS TIME: its line is short and its ink long, and the talk about it comes next, with a
## point at it in the middle.
const SLOW := """<!-- draw #graph:
<svg viewBox="0 0 360 120"><line x1="20" y1="100" x2="340" y2="100"/></svg>
-->
Axes, the graph, and its corner.

The graph stays flat for a while and then it rises, and <!-- point: graph --> this whole line is what one neuron gives us for every input we try.

<!-- pad: y = x -->
[y] equals [x].
"""


func _drawn() -> void:
	print("-- a drawing takes its time")
	var draw_id := ""
	for a in DeskScript.parse(SLOW)["actions"]:
		if String((a as Dictionary)["kind"]) == "draw":
			draw_id = String(a["id"])
	var plans := {}
	for write in [30.0, 3.0]:
		var parsed := DeskScript.parse(SLOW, {draw_id: write}, {draw_id: {"w": 270.0, "h": 90.0, "d": 0.0}})
		for kind in ["draw", "pad"]:
			var desk := DeskMedium.new()
			desk.load_lesson(SLOW, {"seed": 3})
			desk._actions = parsed["actions"].duplicate(true)
			desk._actions[0]["kind"] = kind
			desk.take_words(DeskScript.rehearsal(parsed))
			var f := desk._follower
			var a: Dictionary = desk._actions[0]
			plans["%s %d" % [kind, write]] = {"plan": desk._plan.duplicate(true), "said": f.st1[int(a["after"]) + int(a["span"]) - 1],
				"talk": f.st1[int(a["after"]) + int(a["span"]) + int(a["about"]) - 1], "point": f.st0[int(desk._actions[1]["after"])],
				"way": desk._way(0, 1), "about": int(a["about"])}
			desk.free()
	var slow: Dictionary = plans["draw 30"]
	var held: Dictionary = plans["pad 30"]
	var d: Dictionary = slow["plan"][0]
	var h: Dictionary = held["plan"][0]
	_check(int(slow["about"]) == 26, "the talk about a drawing is the paragraph after its line (%d words)" % int(slow["about"]))
	_check(float(d["end"]) > float(slow["said"]) + 1.0 and float(d["end"]) > float(h["end"]) + 1.0,
		"a drawing whose ink outlasts its line runs on past it, into the talk about it (done at %.1f s, its line at %.1f s)" % [float(d["end"]), float(slow["said"])])
	_check(absf(float(d["end"]) - (float(slow["point"]) - float(slow["way"]) - DeskMedium.DRAW_SETTLE)) < 0.01
		and absf(float(slow["plan"][1]["start"]) - float(slow["point"])) < 0.001
		and absf(float(slow["plan"][1]["start"]) - float(held["plan"][1]["start"])) < 0.001,
		"and is done a settle and the nib's way before the point at it, which is on its word as before")
	_check(absf(float(h["end"]) - maxf(float(held["said"]), float(h["start"]) + 30.0 / DeskScript.MAX_PACE)) < 0.01,
		"the control: a formula as long, its line as short, is held to its words (%.1f s)" % float(h["end"]))
	var quick: Dictionary = plans["draw 3"]["plan"][0]
	_check(absf(float(quick["end"]) - float(quick["start"]) - 3.0 / DeskMedium.DRAW_PACE) < 0.01,
		"and a drawing that has the room is drawn no slower than the hand's own pace (%.1f s for 3 s of ink)" % (float(quick["end"]) - float(quick["start"])))


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
	var comp := ProofProducer.land_problem({"episode_title": "Pendulums", "statement": "wider is slower", "check": "Computation",
		"computation": "the period by amplitude", "lean": "theorem main : True", "forbidden": ["Real.pi"]})
	_check(not comp.has("error") and String(comp["check"]) == "computation" and String(comp["lean"]).is_empty()
		and (comp["forbidden"] as Array).is_empty() and ProofTools.kind_of(comp) == "computation",
		"a computation is framed with what it computes and no Lean statement")
	_check(ProofProducer.land_problem({"episode_title": "Pendulums", "statement": "y", "check": "computation"}).has("error"),
		"the control: a computation that does not say what it computes is refused")
	_check(ProofTools.kind_of(PROBLEM) == "proof" and ProofTools.kind_of({"lean": "theorem main : True"}) == "proof",
		"a problem framed before there were computations is a proof")
	# THE LENGTH THE NOTE ASKS FOR, kept only when sound
	_check(ProofProducer.minutes_of([10, 5]) == [5.0, 10.0] and ProofProducer.minutes_of([8]) == [8.0, 8.0]
		and ProofProducer.minutes_of(12) == [12.0, 12.0] and ProofProducer.minutes_of(["5", "10"]) == [5.0, 10.0],
		"a length is kept as [least, most] minutes, one number both")
	_check(ProofProducer.minutes_of([]).is_empty() and ProofProducer.minutes_of("").is_empty()
		and ProofProducer.minutes_of([0, 10]).is_empty() and ProofProducer.minutes_of([5, 10, 15]).is_empty()
		and ProofProducer.minutes_of(["short"]).is_empty() and ProofProducer.minutes_of([5, 900]).is_empty()
		and (got["minutes"] as Array).is_empty(), "the control: none, nonsense or no length at all is no length")
	# THE RESULT, handed in: only runs that ran to their end show it
	var ep := ProofEpisode.open("computed-note", 1)
	ep.write_json("problem", COMPUTED)
	ep.write_json("runs", [{"n": 1, "code": "x", "exit": 0, "timed_out": false}, {"n": 2, "code": "y", "exit": 0, "timed_out": true}])
	DirAccess.make_dir_recursive_absolute(ep.job_dir("solve"))
	var tools := ProofTools.new(ep, COMPUTED, ep.job_dir("solve"))
	var names := PackedStringArray()
	for d in tools.list_tools():
		names.append(String((d as Dictionary)["name"]))
	_check(not names.has("lean") and names.has("submit") and names.has("run") == ProofTools.can_run(),
		"a computation's solver has no Lean, and runs code only where it can (%s)" % ", ".join(names))
	var refused := tools._submit_result("wider is slower", [1, 2])
	var taken := tools._submit_result("wider is slower", [1.0])
	var sub: Variant = JSON.parse_string(FileAccess.get_file_as_string(ep.job_dir("solve").path_join(ProofTools.SUBMITTED)))
	_check(String(refused.get("error", "")).contains("did not run to its end") and String(taken.get("text", "")).begins_with("Accepted")
		and sub is Dictionary and bool(sub["computed"]) and (sub["runs"] as Array).size() == 1 and int(sub["runs"][0]) == 1,
		"a result naming a run that did not finish is refused (the control, one that did, is taken)")
	var maker := ProofProducer.new(ep, {})
	var landed := maker._land_solve(FileAccess.get_file_as_string(ep.job_dir("solve").path_join(ProofTools.SUBMITTED)), {"ok": true}, 0)
	var solve: Variant = ep.read_json("solve")
	_check(landed.is_empty() and solve is Dictionary and bool(solve["computed"]) and not bool(solve["verified"])
		and int(solve["runs"]) == 2 and String(solve["result"]) == "wider is slower",
		"and lands computed, never verified, with its runs counted")
	_check(ProofTools.run_report({"n": 3, "exit": 0, "seconds": 1.25, "stdout": "ok\n", "stderr": "", "error": ""},
		{"period": {"points": [[10.0, 2.0], [90.0, 2.4]]}}).contains("period (2 points, x from 10 to 90, y from 2 to 2.4)"),
		"a run's report names what it kept, with its ranges")


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


## AN IDLE PEN GETS OUT OF THE WAY (the user, 2026-10-19: "the pen was just frozen, right in the middle
## of the page, covering a bunch of the text's visibility ... drift to the right and top"): over a long
## aside the nib sets off from where its action left it, goes right off the written lines, then up the
## pad's edge, waits off its top right and is back as the next formula begins, never whipping across
## the page; over a short wait it stays beside its line (the control). The old wait jumped to its rest
## the frame an action ended, and every reach took 0.45 s however far it went.
func _idle() -> void:
	print("-- an idle pen gets out of the way")
	var talk := ""
	for i in 5:
		talk += "This sentence says nothing that the pen could show at all. "
	var desk := _desk_over({}, LESSON + "\n" + talk + "\n\n<!-- pad: 4!+1 = 25 -->\nFour factorial, plus one, is twenty five.\n")
	var s := desk._actions.size() - 2
	var k := s + 1
	var end := float(desk._plan[s]["end"])
	var start := float(desk._plan[k]["start"])
	var words := int((desk._actions[k] as Dictionary)["after"]) - int((desk._actions[s] as Dictionary)["after"])
	_check(String((desk._actions[s] as Dictionary)["kind"]) == "strike" and desk._parks(s, k) and not desk._parks(0, 1)
		and not desk._parks(k, -1), "%d words with nothing for the pen send it off the pad, and the short waits do not" % words)
	var left := desk._action_point(desk._actions[s], false)
	desk._now = end + 0.01
	var set_off: Vector2 = desk.pen_at()["p"]
	_check(set_off.distance_to(left) < 3.0, "the nib sets off from where its action left it (%.1f px; the old wait, at its rest, %.0f px away the next frame)"
		% [set_off.distance_to(left), DeskMedium._rest_near(left).distance_to(left)])
	desk._now = end + DeskMedium.PARK_AFTER + DeskMedium.PARK_CLEAR
	var cleared: Vector2 = desk.pen_at()["p"]
	_check(cleared.x > DeskScript.PW and cleared.y > DeskMedium.PARK.y + 100.0,
		"it goes right first, off the written lines, then up the pad's edge (%s)" % cleared)
	desk._now = (end + start) * 0.5
	var parked: Vector2 = desk.pen_at()["p"]
	_check(parked.distance_to(DeskMedium.PARK) < 1.0, "over the aside it waits off the pad's top right (%s)" % parked)
	var first := desk._action_point(desk._actions[k], true)
	var fastest := 0.0
	var prev := Vector2.INF
	var t := end
	while t < start:
		desk._now = t
		var p: Vector2 = desk.pen_at()["p"]
		if prev != Vector2.INF:
			fastest = maxf(fastest, p.distance_to(prev))
		prev = p
		t += 1.0 / 60.0
	desk._now = start - 0.001
	var back: Vector2 = desk.pen_at()["p"]
	var old := 1.5 * DeskMedium.PARK.distance_to(first) / DeskMedium.REACH_EASE / 60.0
	_check(back.distance_to(first) < 2.0 and fastest < 40.0 and old > 40.0,
		"and is back as the formula begins, at most %.0f px a frame on its way (the control: the old reach, %.0f)" % [fastest, old])
	var rest_at := float(desk._plan[0]["end"]) + DeskMedium.REST_EASE
	desk._now = rest_at
	var near: Vector2 = desk.pen_at()["p"]
	_check(rest_at < float(desk._plan[1]["start"]) - desk._reach(0, 1) and near.x < DeskScript.PW
		and near.distance_to(DeskMedium._rest_near(desk._action_point(desk._actions[0], false))) < 1.0,
		"the control: between two actions closer than that it waits beside its line (%s)" % near)
	desk.free()


## Does the pen at [param at] (`pen_at`'s) meet the sheet a turn begun at [param ta] is turning over
## [param over] pages already turned? In the pad's meters: the sheet as [LegalPad] draws it - its left
## and right edges' profiles, swept across, the pad's head lifted as it is then - the pen a rod from its
## nib along its lean.
func _meets_sheet(at: Dictionary, now: float, ta: float, over := 0) -> bool:
	var u := clampf((now - ta) / DeskScript.TURN, 0.0, 1.0)
	var beta := LegalPad.tilt(u)
	var lead := LegalPad.LEAD * sin(PI * clampf(u / LegalPad.FLIP, 0.0, 1.0))
	var r := LegalPad.rank(over, over, LegalPad.turn_progress(u))
	var loop := LegalPad.loop_of(over, r, 3)
	return _rod_meets(at, now, _lifted(LegalPad.curve(clampf(u - lead, 0.0, 1.0), loop, LegalPad.root_of(r), LegalPad.under_of(r), beta), beta),
		_lifted(LegalPad.curve(clampf(u + lead, 0.0, 1.0), loop, LegalPad.root_of(r), LegalPad.under_of(r), beta), beta))


## A profile in the pad's body, where it is with the head lifted [param beta].
func _lifted(c: PackedVector2Array, beta: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for q in c:
		out.append(LegalPad.lifted(q, beta))
	return out


## Does the pen at [param at] meet a sheet whose left edge's profile is [param left] and right edge's
## [param right] ((z, y) in the pad's meters)?
func _rod_meets(at: Dictionary, now: float, left: PackedVector2Array, right: PackedVector2Array) -> bool:
	var p: Vector2 = at["p"]
	var nib := Vector3((p.x / DeskScript.PW - 0.5) * DeskMedium.PAD_W, 0.0003 + float(at["lift"]),
		(p.y / DeskScript.PH - 0.5) * DeskMedium.PAD_H)
	var up := DeskMedium.lean(DeskMedium.PEN_UP, now, 3, p.x / DeskScript.PW, Vector3.ZERO)
	for j in 41:
		var q := nib + up * (0.02 + DeskMedium.PEN_LEN) * float(j) / 40.0
		if absf(q.x) > DeskMedium.PAD_W * 0.5 + DeskMedium.PEN_R:
			continue
		var f := clampf(q.x / DeskMedium.PAD_W + 0.5, 0.0, 1.0)
		var at2 := Vector2(q.z, q.y)
		for i in left.size() - 1:
			var a := left[i].lerp(right[i], f)
			var b := left[i + 1].lerp(right[i + 1], f)
			if at2.distance_to(Geometry2D.get_closest_point_to_segment(at2, a, b)) < DeskMedium.PEN_R:
				return true
	return false


## How many times two profiles cross.
func _crossings(p: PackedVector2Array, q: PackedVector2Array) -> int:
	var n := 0
	for i in p.size() - 1:
		for j in q.size() - 1:
			if Geometry2D.segment_intersects_segment(p[i], p[i + 1], q[j], q[j + 1]) != null:
				n += 1
	return n


## How many points of a profile (the pad's body) are inside the pad - its stack, or the binding over
## its head.
func _in_pad(c: PackedVector2Array) -> int:
	var top := -LegalPad.H * 0.5
	var head := top - LegalPad.BIND_W - 0.0025
	var n := 0
	for i in range(2, c.size()):
		var q := c[i]
		if q.x > head and q.x < LegalPad.H * 0.5 and q.y > -LegalPad.THICK + 0.00001 and q.y < -0.00001:
			n += 1
		elif q.x > head and q.x < top and q.y < LegalPad.TAPE_TOP + 0.0001 and q.y > -LegalPad.THICK:
			n += 1
	return n


## A PAGE IS TURNED AS A HAND TURNS ONE ([LegalPad]): the sheet's profile through a turn and the
## pages it folds round, in the pad's meters.
func _turned() -> void:
	print("-- a page turned")
	var seed := 3
	var over := LegalPad.KEPT
	# where it starts and where it ends: flat where the page lay, then as it then lies round the head
	var r0 := LegalPad.rank(over, over, 0.0)
	var flat := LegalPad.curve(0.0, LegalPad.loop_of(over, r0, seed), LegalPad.root_of(r0), LegalPad.under_of(r0))
	var lies := true
	for i in flat.size():
		var s := LegalPad.H * float(i) / float(flat.size() - 1)
		lies = lies and absf(flat[i].x - (-LegalPad.H * 0.5 + s)) < 1e-4 and absf(flat[i].y - LegalPad.root_of(r0)) < 1e-6
	var r1 := LegalPad.rank(over, over, LegalPad.turn_progress(1.0))
	var done := LegalPad.curve(1.0, LegalPad.loop_of(over, r1, seed), LegalPad.root_of(r1), LegalPad.under_of(r1), LegalPad.tilt(1.0))
	var r2 := LegalPad.rank(over, over + 1, 0.0)
	var lain := LegalPad.curve(1.0, LegalPad.loop_of(over, r2, seed), LegalPad.root_of(r2), LegalPad.under_of(r2))
	var end := done[done.size() - 1]
	_check(lies and done == lain and end.y < -LegalPad.THICK and end.x > -LegalPad.H * 0.5,
		"the sheet starts flat where the page lay, and ends as it then lies: round the head, its end under the pad (%s)" % end)
	# THE HEAD IS LIFTED FOR IT, and down again before the pen comes back
	var most := 0.0
	var u := 0.0
	while u <= 1.0:
		most = maxf(most, LegalPad.tilt(u))
		u += 0.01
	_check(LegalPad.tilt(0.0) == 0.0 and most > deg_to_rad(10.0) and LegalPad.tilt(DeskMedium.PARK_BACK) == 0.0
		and LegalPad.tilt(DeskMedium.PARK_BACK - 0.1) > 0.0,
		"the pad's head is lifted for it (%.0f degrees at most) and down before the pen comes back" % rad_to_deg(most))
	# EIGHT PAGES OVER: nested, none in the pad or its binding, fanned apart round the head
	var olds: Array = []
	for j in over:
		var r := LegalPad.rank(j, over, 0.0)
		olds.append(LegalPad.curve(1.0, LegalPad.loop_of(j, r, seed), LegalPad.root_of(r), LegalPad.under_of(r)))
	var cross := 0
	var inside := 0
	var backs := PackedFloat32Array()
	for j in over:
		inside += _in_pad(olds[j])
		var b := 1.0
		for q in olds[j]:
			b = minf(b, (q as Vector2).x)
		backs.append(b)
		for k in range(j + 1, over):
			cross += _crossings(olds[j], olds[k])
	var fanned := true
	for j in range(1, over):
		fanned = fanned and backs[j] < backs[j - 1] - 0.0002
	_check(cross == 0 and inside == 0 and fanned,
		"eight pages over: their loops never cross nor go into the pad, and each reaches further round the head than the one inside it (%.1f mm in all)"
		% ((backs[0] - backs[over - 1]) * 1000.0))
	# A NINTH TURNED OVER THEM: never crosses one nor goes into the pad; the control, the same sheet
	# given the innermost loop
	var hits := 0
	var ctl := 0
	u = 0.0
	while u <= 1.0001:
		var e := LegalPad.turn_progress(u)
		var beta := LegalPad.tilt(u)
		var lead := LegalPad.LEAD * sin(PI * clampf(u / LegalPad.FLIP, 0.0, 1.0))
		var rt := LegalPad.rank(over, over, e)
		var now: Array = []
		for j in over:
			var r := LegalPad.rank(j, over, e)
			if r >= 0.0:
				now.append(LegalPad.curve(1.0, LegalPad.loop_of(j, r, seed), LegalPad.root_of(r), LegalPad.under_of(r), beta))
		for side in [-1.0, 1.0]:
			var a := clampf(u + float(side) * lead, 0.0, 1.0)
			var sheet := LegalPad.curve(a, LegalPad.loop_of(over, rt, seed), LegalPad.root_of(rt), LegalPad.under_of(rt), beta)
			var inner := LegalPad.curve(a, LegalPad.loop_of(over, 0.0, seed), LegalPad.root_of(float(LegalPad.KEPT)), LegalPad.under_of(0.0), beta)
			hits += _in_pad(sheet)
			for o in now:
				hits += _crossings(sheet, o)
				ctl += _crossings(inner, o)
		u += 1.0 / 30.0
	_check(hits == 0 and ctl > 0, "a ninth page turned over them never crosses one nor goes into the pad (the control, given the innermost loop, crosses %d times)" % ctl)
	# THE TOP OF THE PAGE IS COVERED, ABOVE ITS FIRST RULE: the roundest loop's bulge, and the pen writing
	# the top line under it
	var rk := float(LegalPad.KEPT - 1)
	var roundest := LegalPad.curve(1.0, LegalPad.LOOP + rk * LegalPad.GAP + LegalPad.GAP * LegalPad.GAP_SPREAD * 0.5,
		LegalPad.root_of(rk), LegalPad.under_of(rk))
	var bulge := 0.0
	for q in roundest:
		if q.y > 0.002:
			bulge = maxf(bulge, (q.x + LegalPad.H * 0.5) / LegalPad.H * DeskScript.PH)
	var twice := LegalPad.curve(1.0, (LegalPad.LOOP + rk * LegalPad.GAP) * 2.0, LegalPad.root_of(rk), LegalPad.under_of(rk))
	var meets := 0
	var ctl_meets := 0
	var tries := 0
	var x := DeskScript.MATH_X
	while x <= DeskScript.PW - DeskScript.RIGHT:
		for k in 8:
			var at := {"p": Vector2(x, DeskScript.FIRST_RULE - DeskScript.RULE * 0.8), "lift": 0.0}
			meets += int(_rod_meets(at, k * 1.7, roundest, roundest))
			ctl_meets += int(_rod_meets(at, k * 1.7, twice, twice))
			tries += 1
		x += 60.0
	_check(bulge > 0.0 and bulge < DeskScript.FIRST_RULE - DeskScript.RULE and meets == 0 and ctl_meets > 0,
		"the loops cover the page's top above its first rule (%.0f px), and the pen writing the top line never meets the roundest (the control, twice as round: %d of %d)"
		% [bulge, ctl_meets, tries])


## EVERY DESK IS ITS OWN ([DeskLook]): the same seed, the same desk; across seeds, a variety; the ink
## readable; the things off the pad, out from behind it, and out of the pen's way; nothing painted.
func _look() -> void:
	print("-- the desk's look")
	_check(str(DeskLook.of(41)) == str(DeskLook.of(41)) and str(DeskLook.of(41)) != str(DeskLook.of(42)),
		"the same seed is the same desk, another seed another")
	var papers := {}
	var tops := {}
	var kinds := {}
	var counts := {}
	var worst := INF
	var ctl_worst := INF
	for seed in 300:
		var l := DeskLook.of(seed)
		papers[(l["paper"] as Color).to_html(false).substr(0, 3)] = true
		tops[String((l["materials"]["the desk"] as Dictionary)["kind"])] = true
		counts[(l["things"] as Array).size()] = true
		for t in l["things"]:
			kinds[String((t as Dictionary)["kind"])] = true
		worst = minf(worst, _contrast(l["ink"], l["paper"]))
		ctl_worst = minf(ctl_worst, _contrast((l["paper"] as Color).darkened(0.1), l["paper"]))
	_check(papers.size() > 10 and tops.size() >= 4 and kinds.size() == DeskLook.THINGS.size() and counts.size() >= 5,
		"across 300 desks: %d papers, %d kinds of top, %d kinds of thing, %d counts of things" % [papers.size(), tops.size(), kinds.size(), counts.size()])
	_check(worst > 7.0 and ctl_worst < 3.0, "the ink always reads on its paper (contrast at least %.1f; the control, the paper a shade darker, %.1f)" % [worst, ctl_worst])
	# WHERE THINGS GO: never on the pad nor behind it, a tall one never beside its right edge or in front
	var bad := 0
	var ctl := 0
	var placed := 0
	for seed in 400:
		var r := DeskLook._rng(seed, "probe")
		var rad := r.randf_range(0.01, 0.12)
		var tall := r.randf() < 0.5
		var at := DeskLook._placed(r, rad, tall, [])
		if at.x == INF:
			continue
		placed += 1
		bad += int(_badly_placed(at, rad, tall))
		var free := Vector2(r.randf_range(DeskLook.REACH.position.x, DeskLook.REACH.end.x), r.randf_range(DeskLook.REACH.position.y, DeskLook.REACH.end.y))
		ctl += int(_badly_placed(free, rad, tall))
	_check(placed > 300 and bad == 0 and ctl > 50, "a thing never stands on the pad, behind it, or tall in the pen's way (%d placed; the control, anywhere in reach, %d badly)" % [placed, ctl])
	# NO PAINTER: nothing on a desk is the episode's painting, so Proof, which has no painter, makes it whole
	var wants := 0
	for seed in 300:
		var l := DeskLook.of(seed)
		wants += int(_wants_painting(Tables.sanitize(l["top"], l["layers"], l["materials"], [])))
	var l41 := DeskLook.of(41)
	var built := Tables.build(Tables.sanitize(l41["top"], l41["layers"], l41["materials"], []), 41)
	var ctl_top := (l41["top"] as Dictionary).duplicate()
	ctl_top["material"] = "painting"
	var ctl_built := Tables.build(Tables.sanitize(ctl_top, l41["layers"], l41["materials"], []), 41)
	var ctl_cloth := _wants_painting(Tables.sanitize(l41["top"], null, l41["materials"], []))
	_check(wants == 0 and (built["painted"] as Array).is_empty() and not (ctl_built["painted"] as Array).is_empty() and ctl_cloth,
		"no desk of 300 waits for a painting, and a built one lays it on nothing (controls: the top the painting lays it on %d, no layers is the painted cloth: %s)"
		% [(ctl_built["painted"] as Array).size(), ctl_cloth])
	(built["node"] as Node).free()
	(ctl_built["node"] as Node).free()


## Whether a table made safe ([method Tables.sanitize]) lays the painting anywhere: its top, or a layer, IS it.
func _wants_painting(spec: Dictionary) -> bool:
	var top: Dictionary = spec["top"]
	if String(top.get("material", "")) == "painting" or String((top.get("pattern", {}) as Dictionary).get("kind", "")) == "painting":
		return true
	for l in spec["layers"]:
		if String(((l as Dictionary).get("pattern", {}) as Dictionary).get("kind", "")) == "painting":
			return true
	return false


func _badly_placed(at: Vector2, rad: float, tall: bool) -> bool:
	var on_or_behind := absf(at.x) < LegalPad.W * 0.5 + rad and at.y < LegalPad.H * 0.5 + rad
	var pen_lane := at.x > 0.0 and at.x < DeskLook.TALL_RIGHT + rad and at.y < 0.0
	var tall_near := tall and (at.x > -DeskLook.TALL_LEFT - rad and at.x < DeskLook.TALL_RIGHT + rad)
	return on_or_behind or pen_lane or tall_near


## The contrast ratio of two colors (WCAG's, 1 to 21).
func _contrast(a: Color, b: Color) -> float:
	var x := a.srgb_to_linear()
	var y := b.srgb_to_linear()
	var la := 0.2126 * x.r + 0.7152 * x.g + 0.0722 * x.b
	var lb := 0.2126 * y.r + 0.7152 * y.g + 0.0722 * y.b
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


## A desk over the lesson with no stage: the actions as the ink would lay them out (no strokes - an
## item's writing is its measured length), and a steady voice reading it.
func _desk_over(sizes: Dictionary, lesson := LESSON) -> DeskMedium:
	var desk := DeskMedium.new()
	desk.load_lesson(lesson, {"seed": 3})
	var parsed := DeskScript.parse(lesson, _lengths(), sizes)
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
	_idle()
	_turned()
	_look()
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
	_check(ta >= float(td._plan[1]["end"]) + DeskMedium.PARK_CLEAR and float(tp["start"]) >= ta + DeskScript.TURN,
		"the page turns once the pen is off the pad after the writing before it, and the pen writes once it is over")
	# THE PEN IS NEVER IN THE TURNING SHEET'S WAY: it goes off the pad before the sheet lifts, and comes
	# back over the new page behind it; the control, the old wait at the page's right, is in its way
	var hits := 0
	var old_hits := 0
	var frames := 0
	var t := ta
	while t <= float(tp["start"]):
		td._now = t
		hits += int(_meets_sheet(td.pen_at(), t, ta))
		old_hits += int(_meets_sheet({"p": Vector2(DeskScript.PW * 0.84, DeskScript.FIRST_RULE + DeskScript.RULE * 2.0),
			"lift": DeskMedium.REST_LIFT}, t, ta))
		frames += 1
		t += 1.0 / 60.0
	td._now = ta
	_check(td._parks(1, 2) and (td.pen_at()["p"] as Vector2).x > DeskScript.PW and hits == 0 and old_hits > 2,
		"the pen is off the pad as the sheet lifts and never in its way, nor as it comes back (%d of %d frames; the control, the old wait at the page's right, %d)"
		% [hits, frames, old_hits])
	td._now = ta - 0.1
	var before := td._pages()
	td._now = ta + 0.5
	var during := td._pages()
	td._now = ta + DeskScript.TURN + 0.01
	var after := td._pages()
	_check(before == Vector2i(0, -1) and during == Vector2i(1, 0) and after == Vector2i(1, -1),
		"page one is written, turned over page two, and lies over the pad's head (%s %s %s)" % [before, during, after])
	td._now = ta + 0.5
	_check(float(td._framing()["k"]) < 1.0, "the camera stands back as a page turns")
	td.free()
