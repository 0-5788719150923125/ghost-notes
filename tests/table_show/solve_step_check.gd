extends SceneTree

## The gate of WORK A COMPUTER CHECKS at the table ([SolverTools], the `solve` step; next/proof.md, "Proof became a table show"):
## the problem a plan fixes, the step it makes, what the solver can do and hand in, and what the roles after it are told. No
## renderer, no writer, no Lean: what Lean or a run would answer is written as their answer would be.
##
##   godot --headless --path . --script res://tests/table_show/solve_step_check.gd
##
## - A PLAN'S PROBLEM LANDS ONLY SOUND: a proof states `theorem main` (its `:=` and proof cut off, a forbidden name with a space
##   dropped), a computation says what it computes, and a computation where no code can run is refused; no problem is none (the
##   controls: a proof with another theorem's name and a computation that says nothing are refused).
## - IT MAKES ITS STEP: a plan with a problem has `solve` before the table, made from the plan, and the acts and the intro wait
##   for it. The control: a plan with none has no `solve`, and nothing waits on one.
## - THE SOLVER'S TOOLS: a proof's are the notebook, Lean and submit (and runs where code can run), a computation's the
##   notebook, runs and submit; the notebook keeps its sections in order; a result is accepted only with runs that ran to their
##   end (the controls: none named, a run that failed, a run that is not there).
## - ITS SESSION LANDS HONESTLY: a proof handed in is `verified`, a result `computed`; a run that handed in nothing is tried
##   again, then goes on unchecked if it left a notebook - and fails if it left none.
## - WHAT THE ROLES AFTER IT ARE TOLD: a verified proof is said accepted, an unfinished one never (two-sided); the upload says
##   what checked it, and says nothing with no solve.
## - NO NOTATION IN WHAT IS SAID: a passage with TeX in its words is caught, a mark's underscore is not, and plain words are
##   not (the control); a letter in brackets stays to be said, a direction in brackets goes.

var _fails := 0
const ROOT := "user://solve_step_check"


func _init() -> void:
	_run.call_deferred()


func _ok(cond: bool, what: String) -> void:
	if not cond:
		_fails += 1
		print("  FAIL: " + what)


func _run() -> void:
	await process_frame
	for check in [_problem, _steps, _tools, _lands, _told, _spoken]:
		var done: Variant = await (check as Callable).call()
		_ok(done == true, "%s stopped part way (a script error - see above)" % (check as Callable).get_method())
	_clean()
	print("solve_step_check: %s (%d failure%s)" % ["ALL OK" if _fails == 0 else "FAILED", _fails, "" if _fails == 1 else "s"])
	quit(1 if _fails > 0 else 0)


func _clean() -> void:
	var base := ProjectSettings.globalize_path(ROOT)
	if DirAccess.dir_exists_absolute(base):
		_wipe(base)


func _wipe(path: String) -> void:
	for d in DirAccess.get_directories_at(path):
		_wipe(path.path_join(d))
	for f in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(f))
	DirAccess.remove_absolute(path)


## An episode on disk under the gate's root: a plan of two beats, with [param problem] fixed in it when given.
func _episode(seed: int, problem: Dictionary = {}) -> TableEpisode:
	TableEpisode.root = ROOT
	var ep := TableEpisode.open("solve-show", seed)
	if DirAccess.dir_exists_absolute(ep.dir):
		_wipe(ep.dir)
	var plan := {"episode_title": "Why Primes Go On", "premise": "a proof at a desk", "topic": "primes", "audience": "everyone",
		"reader_mood": "calm", "description": "We prove there is no largest prime.", "tags": ["primes"],
		"spread": {"name": "", "positions": [{"name": "The question", "asks": "", "work": "the question is written"},
			{"name": "The proof", "asks": "", "work": "the proof is written"}]},
		"staging": CardTable.staging_of({"staging": {"source": "none"}}), "look": CardTable.sanitize_look({})}
	if not problem.is_empty():
		plan["problem"] = problem
	ep.write_json("plan", plan)
	return ep


const PROOF := {"statement": "There is no largest prime.", "latex": "\\forall n, \\exists p \\ge n, p \\text{ prime}",
	"check": "proof", "lean": "theorem main (n : ℕ) : ∃ p, n ≤ p ∧ Nat.Prime p := by sorry",
	"forbidden": ["Nat.exists_infinite_primes", "not a name"], "history": "Euclid proved it."}


func _problem() -> bool:
	var got := SolverTools.land_problem(PROOF, true)
	_ok(not got.has("error") and String(got["lean"]) == "theorem main (n : ℕ) : ∃ p, n ≤ p ∧ Nat.Prime p",
		"a proof keeps its statement and loses its proof (%s)" % str(got.get("lean", got.get("error", ""))))
	_ok(got.get("forbidden") == ["Nat.exists_infinite_primes"], "a forbidden name with a space in it is dropped (%s)" % str(got.get("forbidden")))
	var other := PROOF.duplicate()
	other["lean"] = "theorem euclid (n : ℕ) : ∃ p, n ≤ p ∧ Nat.Prime p"
	_ok(SolverTools.land_problem(other, true).has("error"), "CONTROL: a proof that does not state theorem main is refused")
	var comp := {"statement": "How far a ball rolls.", "latex": "d", "check": "computation", "computation": "simulate it, dt halved to check"}
	_ok(not SolverTools.land_problem(comp, true).has("error") and String(SolverTools.land_problem(comp, true)["lean"]).is_empty(),
		"a computation that says what it computes lands, with no Lean statement")
	var silent := comp.duplicate()
	silent.erase("computation")
	_ok(SolverTools.land_problem(silent, true).has("error"), "CONTROL: a computation that does not say what it computes is refused")
	_ok(SolverTools.land_problem(comp, false).has("error"), "a computation where no code can run is refused")
	_ok(SolverTools.land_problem({}, true).is_empty() and SolverTools.land_problem(null, true).is_empty(), "no problem is none")
	_ok(SolverTools.land_problem({"latex": "x"}, true).has("error"), "a problem with no statement is refused")
	return true


func _steps() -> bool:
	var ep := _episode(1, SolverTools.land_problem(PROOF, true))
	var steps := ep.steps()
	_ok(ep.wants_solve() and steps.has("solve") and steps.find("solve") < steps.find("table"),
		"a plan with a problem works it before the table is set (%s)" % str(steps))
	_ok(ep.needs("solve") == ["plan"], "the solve is made from the plan (%s)" % str(ep.needs("solve")))
	_ok(ep.needs("acts").has("solve"), "the acts wait for the work (%s)" % str(ep.needs("acts")))
	_ok(ep.needs("say:intro").has("solve"), "the intro waits for the work (%s)" % str(ep.needs("say:intro")))
	var bare := _episode(2)
	_ok(not bare.wants_solve() and not bare.steps().has("solve") and not bare.needs("acts").has("solve") and not bare.needs("say:intro").has("solve"),
		"CONTROL: a plan with no problem has no solve, and nothing waits on one")
	return true


func _names(tools: Array) -> Array:
	return tools.map(func(t: Dictionary) -> String: return String(t["name"]))


func _tools() -> bool:
	var ep := _episode(3, SolverTools.land_problem(PROOF, true))
	var dir := ep.job_dir("solve")
	DirAccess.make_dir_recursive_absolute(dir)
	var proof := SolverTools.new(ep, ep.problem(), dir)
	var want := ["notebook", "lean"] + (["run"] if SolverTools.can_run() else []) + ["submit"]
	_ok(_names(proof.list_tools()) == want, "a proof's tools are the notebook, Lean, submit%s (%s)" % [
		" and runs" if SolverTools.can_run() else "", str(_names(proof.list_tools()))])
	await proof.call_tool("notebook", {"text": "## Small cases\n2, 3, 5, 7."})
	await proof.call_tool("notebook", {"text": "## The idea\nn! + 1."})
	var nb := ep.read_text("notebook")
	_ok(nb.find("Small cases") >= 0 and nb.find("Small cases") < nb.find("The idea"), "the notebook keeps its sections in order")
	_ok(String((await proof.call_tool("notebook", {"text": "  "})).get("error", "")) != "", "an empty section is refused")
	var comp := SolverTools.new(ep, {"statement": "s", "check": "computation", "computation": "c"}, dir)
	var cwant := ["notebook"] + (["run"] if SolverTools.can_run() else []) + ["submit"]
	_ok(_names(comp.list_tools()) == cwant, "a computation's tools are the notebook%s and submit (%s)" % [
		", runs" if SolverTools.can_run() else "", str(_names(comp.list_tools()))])
	ep.write_json("runs", [{"n": 1, "code": "print(2)", "exit": 0, "timed_out": false, "stdout": "2"},
		{"n": 2, "code": "1/0", "exit": 1, "timed_out": false, "stdout": ""}])
	_ok(String(comp._submit_result("it is two", []).get("error", "")) != "", "CONTROL: a result naming no runs is refused")
	_ok(String(comp._submit_result("it is two", [2]).get("error", "")) != "", "CONTROL: a result naming a run that failed is refused")
	_ok(String(comp._submit_result("it is two", [9]).get("error", "")) != "", "CONTROL: a result naming a run that is not there is refused")
	var took := comp._submit_result("it is two", [1])
	var handed: Variant = JSON.parse_string(FileAccess.get_file_as_string(dir.path_join(SolverTools.SUBMITTED)))
	_ok(not took.has("error") and comp.submitted and handed is Dictionary and bool((handed as Dictionary).get("computed", false)),
		"a result with a run that ran to its end is handed in (%s)" % str(took))
	comp.release()
	_ok(bool((await comp.call_tool("notebook", {"text": "late"})).get("error", false)), "nothing is taken once the work is handed in")
	return true


func _lands() -> bool:
	var ep := _episode(4, SolverTools.land_problem(PROOF, true))
	var prod := TableProducer.new(ep, {"title": "Primes", "brief": "a channel of proofs"})
	prod._tries["solve"] = 1
	var err := prod._land_solve(JSON.stringify({"code": "theorem main ... := by exact foo", "checks": 3, "axioms": {"main": ["propext"]}}), {"ok": true}, 3)
	_ok(err.is_empty() and bool(ep.solved().get("verified", false)) and ep.read_text("proof").contains("exact foo"),
		"a proof handed in lands verified, its file kept (%s)" % err)
	var ep2 := _episode(5, SolverTools.land_problem({"statement": "s", "check": "computation", "computation": "c"}, true))
	var prod2 := TableProducer.new(ep2, {})
	prod2._tries["solve"] = 1
	err = prod2._land_solve(JSON.stringify({"computed": true, "result": "it is two", "runs": [1]}), {"ok": true}, 0)
	_ok(err.is_empty() and bool(ep2.solved().get("computed", false)) and not bool(ep2.solved().get("verified", true)),
		"a result handed in lands computed (%s)" % err)
	var ep3 := _episode(6, SolverTools.land_problem(PROOF, true))
	var prod3 := TableProducer.new(ep3, {})
	prod3._tries["solve"] = 1
	_ok(not prod3._land_solve("", {"ok": true}, 2).is_empty() and not ep3.has("solve"), "a run that handed in nothing is tried again")
	prod3._tries["solve"] = TableProducer.SOLVE_RETRIES + 1
	_ok(not prod3._land_solve("", {"ok": true}, 2).is_empty() and not ep3.has("solve"), "CONTROL: out of tries with no notebook, it fails")
	ep3.write_text("notebook", "## What was tried\nInduction, which did not close.\n")
	err = prod3._land_solve("", {"ok": true}, 2)
	_ok(err.is_empty() and ep3.has("solve") and not bool(ep3.solved().get("verified", true)) and not bool(ep3.solved().get("computed", true)),
		"out of tries with a notebook, it goes on honestly unchecked (%s)" % err)
	return true


func _told() -> bool:
	var problem := SolverTools.land_problem(PROOF, true)
	var told := func(solve: Dictionary) -> String:
		return Rules.say("table/solver.worked", TablePrompts.worked_vars({"problem": problem, "solve": solve,
			"notebook": "## The idea\nn! + 1.", "proof": "theorem main ...", "runs": [], "data": {}}))
	var yes: String = told.call({"verified": true})
	var no: String = told.call({"verified": false, "computed": false})
	_ok(yes.contains("accepted") and not yes.contains("did NOT"), "a verified proof is told as accepted")
	_ok(no.contains("did NOT finish") and not no.contains("accepted"), "CONTROL: an unfinished check is never told as accepted")
	_ok(yes.contains("n! + 1"), "the roles after the solver are handed its notebook")
	_ok(TablePrompts.worked_vars({}).get("worked") == false and TablePrompts.worked_vars({"problem": problem}).get("worked") == false,
		"with no solve made, nothing is told of the work")
	var prompt := TablePrompts.solver("Primes", "a channel", {"episode_title": "Why Primes Go On", "premise": "p"}, problem, false)
	_ok(String(prompt.get("prompt", "")).contains("theorem main") and String(prompt.get("prompt", "")).contains("Forbidden facts") \
		and not String(prompt.get("prompt", "")).contains("- run:"), "the solver is told the statement, the forbidden facts, and no runs where none can run")
	var ep := _episode(7, problem)
	ep.write_json("solve", {"verified": true, "lean": "4.35.0", "mathlib": "v4.35.0"})
	var up := String(ep.upload_notes()["description"])
	_ok(up.contains("We prove there is no largest prime.") and up.contains("checked by the Lean theorem prover (Lean 4.35.0, Mathlib v4.35.0)"),
		"the upload says what checked it (%s)" % up)
	var bare := _episode(8)
	_ok(not String(bare.upload_notes()["description"]).contains("Lean"), "CONTROL: an episode with no solve says nothing of a check")
	return true


func _spoken() -> bool:
	_ok(not TableProducer.notation_in("Add up the first n odd numbers, and you get $n^2$.").is_empty(), "a passage with TeX in its words is caught")
	_ok(TableProducer.notation_in("<!-- act: write_sum --> The sum is [n] squared.").is_empty(), "a mark's underscore is no notation")
	_ok(TableProducer.notation_in("The sum is n squared.").is_empty(), "CONTROL: plain words are not caught")
	var said := TableProducer.clean_spoken("[laughs] The side [a] is three.")
	_ok(said.contains("[a]") and not said.contains("laughs"), "a letter in brackets stays to be said, a direction goes (%s)" % said)
	return true
