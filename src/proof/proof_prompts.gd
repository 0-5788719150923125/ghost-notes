extends RefCounted
class_name ProofPrompts

## ProofPrompts - what each agent behind a Proof episode is told, built from rules/proof/ ([Rules]).
## Every builder is a pure function of what it is handed and returns `{system, prompt}`, so a gate
## renders each whole (tests/proof/proof_check.gd) - the words live in the YAML, the code decides
## what fills them.
##
## The context every agent shares is [method context]: the channel, and the note's words.

## The branches the inventor is pointed at, one per press, so two presses propose different things.
const AREAS := ["number theory", "combinatorics and counting", "inequalities", "sums and series",
	"divisibility and primes", "irrational and rational numbers", "the pigeonhole principle",
	"induction", "graphs", "games and invariants", "geometry with numbers", "algebra of polynomials"]

## A LESSON HAS NO SET LENGTH (the user, 2026-10-16: "I would prefer to just make videos as long as they
## need to be"): no agent is handed minutes or a count of words, and none is sent back for running long.
##
## The most notes the student hands back on a draft.
const STUDENT_NOTES := 12


## What every agent shares: the channel's name and the note.
static func context(title: String, brief: String) -> String:
	return Rules.say("proof/show.context", {"title": title, "brief": brief})


## "Invent a problem": a branch picked by [param seed], avoiding [param before] (titles done).
static func inventor(seed: int, before: Array) -> Dictionary:
	var area := String(AREAS[absi(hash(["proof-area", seed])) % AREAS.size()])
	return {"system": Rules.say("proof/inventor.system", {}),
		"prompt": Rules.say("proof/inventor.prompt", {"area": area,
			"before": ", ".join(PackedStringArray(before))})}


## "Refine": the note as the author left it ([param brief], a line or a draft) written back whole, the
## problem defined.
static func refiner(title: String, brief: String) -> Dictionary:
	return {"system": Rules.say("proof/refiner.system", {}) + "\n\n" + context(title, brief),
		"prompt": Rules.say("proof/refiner.prompt", {})}


## The framer: the note in, the fixed problem and the episode's name out (JSON). [param uploads_as]
## is the line the episode's title goes up in ([method YouTube.title_shape], "" for none), and
## [param before] the titles this note's other episodes took.
static func framer(title: String, brief: String, uploads_as := "", before: Array = []) -> Dictionary:
	return {"system": context(title, brief), "prompt": Rules.say("proof/framer.prompt", {
		"uploads_as": uploads_as.strip_edges(), "before": "; ".join(PackedStringArray(before))})}


## The solver, given the fixed [param problem] (the framer's answer, landed).
static func solver(title: String, brief: String, problem: Dictionary) -> Dictionary:
	return {"system": Rules.say("proof/solver.system", {}) + "\n\n" + context(title, brief),
		"prompt": Rules.say("proof/solver.prompt", {
			"statement": str(problem.get("statement", "")), "latex": str(problem.get("latex", "")),
			"lean": str(problem.get("lean", "")),
			"forbidden": ", ".join(PackedStringArray(problem.get("forbidden", [])))})}


## The teacher, given the problem, the notebook and the Lean file as they were left. [param fix]
## carries what a second try must mend: `broken` (formulas and drawings that could not be set),
## `notation` (speech that carried notation), `undictated` (pad lines not read aloud as written) and
## `letters` (speech that said a letter as the word "a"), `points` (names pointed at that nothing
## carries) and `still` (long stretches of speech over a still pen), each a list of lines. With
## [param draft]
## (the first draft) and [param review] (the student's notes on it, `[{quote, need}]`) it writes the
## lesson again from them.
static func teacher(title: String, brief: String, problem: Dictionary, notebook: String,
		proof: String, verified: bool, fix: Dictionary = {}, draft := "",
		review: Array = []) -> Dictionary:
	return {"system": Rules.say("proof/teacher.system", {}) + "\n\n" + context(title, brief),
		"prompt": Rules.say("proof/teacher.prompt", {
			"statement": str(problem.get("statement", "")), "latex": str(problem.get("latex", "")),
			"history": str(problem.get("history", "")),
			"audience": str(problem.get("audience", "curious viewers with high-school math")),
			"notebook": notebook.strip_edges() if not notebook.strip_edges().is_empty()
				else "(the mathematician left no notes)",
			"proof": proof.strip_edges() if not proof.strip_edges().is_empty() else "(no Lean file)",
			"verified": verified,
			"draft": draft.strip_edges(), "review": notes_text(review),
			"broken": "\n".join(PackedStringArray(fix.get("broken", []))),
			"notation": "\n".join(PackedStringArray(fix.get("notation", []))),
			"undictated": "\n".join(PackedStringArray(fix.get("undictated", []))),
			"letters": "\n".join(PackedStringArray(fix.get("letters", []))),
			"points": ", ".join(PackedStringArray(fix.get("points", []))),
			"still": "\n".join(PackedStringArray(fix.get("still", []))),
			"still_words": str(DeskScript.STILL_WORDS)})}


## THE STUDENT, given the teacher's first [param draft]: notes on where it loses a newcomer (JSON).
static func student(title: String, brief: String, problem: Dictionary, draft: String) -> Dictionary:
	return {"system": Rules.say("proof/student.system", {}) + "\n\n" + context(title, brief),
		"prompt": Rules.say("proof/student.prompt", {
			"audience": str(problem.get("audience", "curious viewers with high-school math")),
			"draft": draft.strip_edges(), "most": str(STUDENT_NOTES)})}


## The student's notes as the teacher reads them: a line each, the lesson's words and what was needed.
## "(the student had no notes)" for none.
static func notes_text(review: Array) -> String:
	var lines := PackedStringArray()
	for n in review:
		if n is Dictionary and not str((n as Dictionary).get("need", "")).strip_edges().is_empty():
			lines.append("- \"%s\": %s" % [str((n as Dictionary).get("quote", "")).strip_edges(),
				str((n as Dictionary)["need"]).strip_edges()])
	return "\n".join(lines) if not lines.is_empty() else "(the student had no notes)"
