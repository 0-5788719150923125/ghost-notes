extends RefCounted
class_name ProofPrompts

## ProofPrompts - what each agent behind a Proof episode is told, built from rules/proof/ ([Rules]).
## Every builder is a pure function of what it is handed and returns `{system, prompt}`, so a gate
## renders each whole (tests/proof/proof_check.gd) - the words live in the YAML, the code decides
## what fills them.
##
## The context every agent shares is [method context]: the channel, and the note's words.

## The fields the inventor is pointed at, one per press, so two presses propose different things.
## NOT ONLY MATH (the user, 2026-10-19: "it should be a general theorem-prover and learning tool"): a
## field whose claims are about models or data is settled by a computation where code can run.
const AREAS := ["number theory", "combinatorics and counting", "inequalities", "sums and series",
	"geometry", "graphs and networks", "probability", "statistics and estimation", "machine learning",
	"optimization", "information and coding", "algorithms", "mechanics and motion",
	"waves and oscillation", "heat and thermodynamics", "electric circuits", "orbits and gravity",
	"population and epidemic models", "games and economics", "signals and Fourier analysis"]
## How many characters of the solver's runs the teacher is shown in full; the rest a line each.
const RUNS_SHOWN := 40000

## A LESSON HAS NO SET LENGTH (the user, 2026-10-16: "I would prefer to just make videos as long as they
## need to be"): no agent is handed minutes or a count of words, and none is sent back for running long.
##
## The most notes the student hands back on a draft.
const STUDENT_NOTES := 12


## What every agent shares: the channel's name and the note.
static func context(title: String, brief: String) -> String:
	return Rules.say("proof/show.context", {"title": title, "brief": brief})


## "Invent a problem": a field picked by [param seed], avoiding [param before] (titles done). [param run]:
## whether code can run here ([method ProofTools.can_run]), so a computation may be proposed.
static func inventor(seed: int, before: Array, run := false) -> Dictionary:
	var area := String(AREAS[absi(hash(["proof-area", seed])) % AREAS.size()])
	return {"system": Rules.say("proof/inventor.system", {}),
		"prompt": Rules.say("proof/inventor.prompt", {"area": area, "run": run,
			"before": ", ".join(PackedStringArray(before))})}


## "Refine": the note as the author left it ([param brief], a line or a draft) written back whole, the
## problem defined.
static func refiner(title: String, brief: String, run := false) -> Dictionary:
	return {"system": Rules.say("proof/refiner.system", {}) + "\n\n" + context(title, brief),
		"prompt": Rules.say("proof/refiner.prompt", {"run": run})}


## The framer: the note in, the fixed problem and the episode's name out (JSON). [param uploads_as]
## is the line the episode's title goes up in ([method YouTube.title_shape], "" for none),
## [param before] the titles this note's other episodes took, and [param run] whether code can run
## here - a claim may be framed as a computation only then.
static func framer(title: String, brief: String, uploads_as := "", before: Array = [], run := false) -> Dictionary:
	return {"system": context(title, brief), "prompt": Rules.say("proof/framer.prompt", {
		"uploads_as": uploads_as.strip_edges(), "before": "; ".join(PackedStringArray(before)), "run": run})}


## The solver, given the fixed [param problem] (the framer's answer, landed): a proof to check in Lean,
## or a computation to run ([method ProofTools.kind_of]). [param run]: whether it can run code.
static func solver(title: String, brief: String, problem: Dictionary, run := false) -> Dictionary:
	var proof := ProofTools.kind_of(problem) == "proof"
	return {"system": Rules.say("proof/solver.system", {}) + "\n\n" + context(title, brief),
		"prompt": Rules.say("proof/solver.prompt", {
			"statement": str(problem.get("statement", "")), "latex": str(problem.get("latex", "")),
			"lean": str(problem.get("lean", "")), "proof": proof, "run": run,
			"computation": str(problem.get("computation", "")),
			"forbidden": ", ".join(PackedStringArray(problem.get("forbidden", [])))})}


## The teacher, given the problem, the notebook, the Lean file as it was left, the solver's session as
## it ended ([param solve]: `verified` - Lean accepted the proof - or `computed` - the result was handed
## in with the runs that show it), the [param runs] it made and the [param data] they kept. [param fix]
## carries what a second try must mend: `broken` (formulas and drawings that could not be set),
## `notation` (speech that carried notation), `undictated` (pad lines not read aloud as written) and
## `letters` (speech that said a letter as the word "a"), `points` (names pointed at that nothing
## carries) and `still` (long stretches of speech over a still pen), each a list of lines. With
## [param draft]
## (the first draft) and [param review] (the student's notes on it, `[{quote, need}]`) it writes the
## lesson again from them.
static func teacher(title: String, brief: String, problem: Dictionary, notebook: String,
		proof: String, solve: Dictionary, fix: Dictionary = {}, draft := "",
		review: Array = [], runs: Array = [], data: Dictionary = {}) -> Dictionary:
	var is_proof := ProofTools.kind_of(problem) == "proof"
	return {"system": Rules.say("proof/teacher.system", {}) + "\n\n" + context(title, brief),
		"prompt": Rules.say("proof/teacher.prompt", {
			"statement": str(problem.get("statement", "")), "latex": str(problem.get("latex", "")),
			"history": str(problem.get("history", "")),
			"audience": str(problem.get("audience", "curious viewers with high-school math")),
			"notebook": notebook.strip_edges() if not notebook.strip_edges().is_empty()
				else "(the solver left no notes)",
			"lean": proof.strip_edges() if not proof.strip_edges().is_empty() else "(no Lean file)",
			"proof": is_proof, "verified": is_proof and bool(solve.get("verified", false)),
			"computed": not is_proof and bool(solve.get("computed", false)),
			"computation": str(problem.get("computation", "")),
			"result": str(solve.get("result", "")),
			"runs": runs_text(runs, solve.get("evidence", []) if solve.get("evidence") is Array else []),
			"data": data_text(data),
			"draft": draft.strip_edges(), "review": notes_text(review),
			"broken": "\n".join(PackedStringArray(fix.get("broken", []))),
			"notation": "\n".join(PackedStringArray(fix.get("notation", []))),
			"undictated": "\n".join(PackedStringArray(fix.get("undictated", []))),
			"letters": "\n".join(PackedStringArray(fix.get("letters", []))),
			"points": ", ".join(PackedStringArray(fix.get("points", []))),
			"still": "\n".join(PackedStringArray(fix.get("still", []))),
			"still_words": str(DeskScript.STILL_WORDS)})}


## THE RUNS as the teacher reads them: the ones the result names ([param evidence]) first, then the
## others that ran to their end, each with its code and what it printed, while [constant RUNS_SHOWN]
## lasts; every other run a line. "" for none.
static func runs_text(runs: Array, evidence: Array) -> String:
	var named: Array = []
	for v in evidence:
		named.append(int(v))
	var order: Array = []
	for r in runs:
		if r is Dictionary and named.has(int((r as Dictionary).get("n", 0))):
			order.append(r)
	for r in runs:
		if r is Dictionary and not order.has(r):
			order.append(r)
	var full := PackedStringArray()
	var brief := PackedStringArray()
	var used := 0
	for r in order:
		var d: Dictionary = r
		var ran := int(d.get("exit", -1)) == 0 and not bool(d.get("timed_out", false))
		var out := str(d.get("stdout", "")).strip_edges()
		var block := "Run %d%s:\n```python\n%s\n```\nIt printed:\n%s" % [int(d.get("n", 0)),
			" (the result names it)" if named.has(int(d.get("n", 0))) else "", str(d.get("code", "")).strip_edges(),
			out if not out.is_empty() else "(nothing)"]
		if ran and used + block.length() <= RUNS_SHOWN:
			full.append(block)
			used += block.length()
			continue
		var last := out.get_slice("\n", out.count("\n")) if not out.is_empty() else ""
		var why := str(d.get("error", "")) if not str(d.get("error", "")).is_empty() else \
			("exit %d" % int(d.get("exit", -1)) if not ran else "")
		brief.append("- run %d: %s%s" % [int(d.get("n", 0)), ("did not finish (%s)" % why) if not ran else "ran",
			(", last printed: " + last.substr(0, 200)) if not last.is_empty() else ""])
	var text := "\n\n".join(full)
	if not brief.is_empty():
		text += ("\n\n" if not text.is_empty() else "") + "Other runs:\n" + "\n".join(brief)
	return text


## THE DATA the runs kept, as the teacher reads it: a line per series - its name, its size and range,
## what it is, and the run that kept it. "" for none.
static func data_text(data: Dictionary) -> String:
	var lines := PackedStringArray()
	var names := data.keys()
	names.sort()
	for k in names:
		var s: Dictionary = data[k] if data[k] is Dictionary else {}
		var about := str(s.get("about", "")).strip_edges()
		lines.append("- %s: %s%s (run %d)" % [k, ProofTools.series_summary(s.get("points", [])),
			(" - " + about) if not about.is_empty() else "", int(s.get("run", 0))])
	return "\n".join(lines)


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
