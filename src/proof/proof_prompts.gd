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

## The lesson's speech runs at about this many words a minute.
const WORDS_PER_MINUTE := 140


## What every agent shares: the channel's name and the note.
static func context(title: String, brief: String) -> String:
	return Rules.say("proof/show.context", {"title": title, "brief": brief})


## "Invent a problem": a branch picked by [param seed], avoiding [param before] (titles done).
static func inventor(seed: int, before: Array) -> Dictionary:
	var area := String(AREAS[absi(hash(["proof-area", seed])) % AREAS.size()])
	return {"system": Rules.say("proof/inventor.system", {}),
		"prompt": Rules.say("proof/inventor.prompt", {"area": area,
			"before": ", ".join(PackedStringArray(before))})}


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
## carries what a second try must mend: `broken` (formulas TeX refused), `notation` (speech that
## carried notation) and `undictated` (pad lines not read aloud as written), each a list of lines.
static func teacher(title: String, brief: String, problem: Dictionary, notebook: String,
		proof: String, verified: bool, minutes: float, fix: Dictionary = {}) -> Dictionary:
	return {"system": Rules.say("proof/teacher.system", {}) + "\n\n" + context(title, brief),
		"prompt": Rules.say("proof/teacher.prompt", {
			"statement": str(problem.get("statement", "")), "latex": str(problem.get("latex", "")),
			"history": str(problem.get("history", "")),
			"audience": str(problem.get("audience", "curious viewers with high-school math")),
			"notebook": notebook.strip_edges() if not notebook.strip_edges().is_empty()
				else "(the mathematician left no notes)",
			"proof": proof.strip_edges() if not proof.strip_edges().is_empty() else "(no Lean file)",
			"verified": verified, "minutes": String.num(minutes, 0),
			"words": str(int(round(minutes * WORDS_PER_MINUTE))),
			"broken": "\n".join(PackedStringArray(fix.get("broken", []))),
			"notation": "\n".join(PackedStringArray(fix.get("notation", []))),
			"undictated": "\n".join(PackedStringArray(fix.get("undictated", [])))})}
