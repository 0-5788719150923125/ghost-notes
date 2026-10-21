extends RefCounted
class_name ProofProducer

## ProofProducer - makes whatever a Proof episode is missing, in the order a lesson happens
## (next/proof.md, "How an episode is made"), the way [CardProducer] makes a card show's:
##
##   problem   the FRAMER fixes the problem from the note before anyone works on it: its words,
##             its TeX, how it is checked - a PROOF in Lean (its exact statement, the facts it may
##             not cite) or a COMPUTATION (what is computed) - and where it comes from
##   solve     the SOLVER works it at the desk with [ProofTools] - a lab notebook, Lean checks, runs
##             of code, a submitted proof or result - and its session ends verified, computed or
##             neither, honestly whichever
##   draft     the TEACHER writes what the voice says and the pen writes and draws ([DeskScript]),
##             from the notebook and the Lean file as they were left
##   review    the STUDENT reads the draft as the viewer it is for, and notes where it loses them
##   lesson    the TEACHER writes it again from the draft and the student's notes
##   ink       ghost lays every formula out with TeX (hosts/math/typeset.py): a formula TeX refuses
##             sends the lesson back once, with TeX's own words, to be written so it can be set
##   script    ghost: what the voice reads
##
## THE ORDER IS NOT A SCRIPT: every [method tick] starts each step whose inputs exist and whose own
## file does not, and lands what ended. Nothing runs on its own - [method start] is a person pressing
## Make episode, because the agents spend the author's quota.
##
## IT WAITS FOR WHAT IT RUNS ON: a proof's solver needs Lean and Mathlib, a solver that runs code the
## compute environment, the ink TeX and the math environment - all fetched by ghost itself
## ([Provision]). A step whose dependency is installing is not failed; it waits, and [member waiting]
## says for what. What ghost cannot fetch - the sandbox, bubblewrap - a computation fails on, saying so.

signal changed

## A step whose job fails is tried this many more times before the episode stops on it.
const RETRIES := 1
## The solver, more: a safeguard sometimes stops a sound run part way (2026-10-15: the first real
## episode's first try, after one Lean check; its retry verified), and a run is the episode's heart.
const SOLVE_RETRIES := 2
## The steps made here, with no agent and no quota.
const LOCAL := ["ink", "script"]
## A solver may work this long (seconds) before its run is abandoned.
const SOLVE_TIMEOUT := 3600
## TeX's measure for the pad: a column this many points wide (the page's text width).
const PAD_WIDTH := 270.0
## What a take of the lesson is checked for ([method _land_lesson]), as the keys of [member _fix].
const CHECKED := ["notation", "undictated", "letters", "points", "still", "long"]
## A LESSON RUNS LONG when it passes the most minutes its note asks for by more than this share: the
## estimate is good to a few percent ([method DeskScript.runtime]), and a lesson a little over is better
## kept than cut again.
const LONG_BY := 0.2
## The most minutes a note's length is taken at; past it the framer misread the note.
const MOST_MINUTES := 180.0

var episode: ProofEpisode
## {title (the channel's name), byline, uploads_as (the line an episode's title goes up in), before
## (the titles this note's other episodes took), brief, writer, writer_model, writer_effort}
var spec: Dictionary = {}
var running := false
## The steps this run was asked for; empty for the whole episode.
var only: Array = []
## What the run is waiting to be installed before it can go on, "" when nothing.
var waiting := ""

var _jobs := {}        # step -> AgentJobs id
var _tools := {}       # step -> {url, set}
var _local := {}       # step -> {pid, out, log}: a step ghost runs as a program (the ink)
var _errors := {}      # step -> why it failed, once out of tries
var _tries := {}       # step -> runs started
var _fix := {}         # what the next lesson must mend: {broken, notation, undictated, letters, points, still, long: [..]}


func _init(ep: ProofEpisode, sp: Dictionary) -> void:
	episode = ep
	spec = sp


func start(steps: Array = []) -> void:
	_errors.clear()
	_tries.clear()
	only = steps.duplicate()
	running = true
	tick()
	changed.emit()


func stop() -> void:
	running = false
	waiting = ""
	for step in _jobs:
		AgentJobs.cancel(String(_jobs[step]))
		AgentJobs.forget(String(_jobs[step]))
	_jobs.clear()
	for step in _tools.keys():
		_close_tools(String(step))
	for step in _local:
		Subprocess.stop(int((_local[step] as Dictionary)["pid"]))
	_local.clear()
	changed.emit()


func busy() -> bool:
	return not _jobs.is_empty() or not _local.is_empty()


## "ready", "running", "queued", "waiting", "failed" or "missing".
func state_of(step: String) -> String:
	if episode.has(step):
		return "ready"
	if _local.has(step):
		return "running"
	if _jobs.has(step):
		return "running" if AgentJobs.state(String(_jobs[step])) == "running" else "queued"
	if _errors.has(step):
		return "failed"
	return "missing"


func error_of(step: String) -> String:
	return String(_errors.get(step, ""))


## What [param step]'s agent is doing now, "" when nothing is making it.
func activity_of(step: String) -> String:
	if _jobs.has(step):
		var said := AgentJobs.activity(String(_jobs[step]))
		var t: Dictionary = _tools.get(step, {})
		if not t.is_empty():
			var set := t["set"] as ProofTools
			if set.checks > 0:
				said += " · %d Lean check%s" % [set.checks, "" if set.checks == 1 else "s"]
			if set.runs > 0:
				said += " · %d run%s" % [set.runs, "" if set.runs == 1 else "s"]
		return said
	if _local.has(step):
		return "laying out the formulas with TeX"
	return ""


## Land what ended; start what can start.
func tick() -> void:
	var moved := false
	for step in _jobs.keys():
		var id := String(_jobs[step])
		var st := AgentJobs.state(id)
		if st != "done" and st != "failed":
			continue
		var res := AgentJobs.result(id)
		AgentJobs.forget(id)
		_jobs.erase(step)
		_land(String(step), res)
		moved = true
	for step in _local.keys():
		if Subprocess.alive(int((_local[step] as Dictionary)["pid"])):
			continue
		var job: Dictionary = _local[step]
		_local.erase(step)
		_land_ink(job)
		moved = true
	var was_waiting := waiting
	waiting = ""
	if running:
		for s in ProofEpisode.STEPS:
			var step := String(s)
			if episode.has(step) or _jobs.has(step) or _local.has(step) or _errors.has(step):
				continue
			if episode.moot(step):
				continue
			var ready := true
			for need in episode.needs(step):
				if not episode.has(String(need)):
					ready = false
			if not ready or not (only.is_empty() or only.has(step) or LOCAL.has(step)):
				continue
			var lacks := _lacks(step)
			if not lacks.is_empty():
				waiting = lacks
				continue
			_make(step)
			moved = true
		if _jobs.is_empty() and _local.is_empty() and waiting.is_empty():
			running = false
			moved = true
	if moved or waiting != was_waiting:
		changed.emit()


## What [param step] runs on that is not installed yet - asked to be installed, and named - or "".
func _lacks(step: String) -> String:
	var keys: Array = []
	match step:
		"solve":
			keys = ["compute_venv"] if ProofTools.kind_of(_problem()) == "computation" else ["mathlib", "math_venv"]
			if ProofTools.can_run() and not keys.has("compute_venv"):
				keys.append("compute_venv")
		"ink":
			keys = ["tex", "math_venv"]
	var names := PackedStringArray()
	for k in keys:
		if not Provision.ensure(String(k)):
			names.append(String(Deps.entry(String(k)).get("name", k)))
	if names.is_empty():
		return ""
	return "installing %s" % " and ".join(names)


# --- making one step ---------------------------------------------------------------------

func _make(step: String) -> void:
	match step:
		"problem":
			_submit_text(step, ProofPrompts.framer(_title(), _brief(), String(spec.get("uploads_as", "")),
				spec.get("before", []) if spec.get("before") is Array else [], ProofTools.can_run()), "best")
		"solve":
			_make_solve()
		"draft", "lesson":
			# the first draft from the work; the lesson from the draft and the student's notes on it
			if step == "lesson" and int(_tries.get(step, 0)) == 0:
				for k in CHECKED:
					_fix.erase(k)
			var solve: Variant = episode.read_json("solve")
			var review: Variant = episode.read_json("review")
			var notes: Array = (review as Dictionary).get("notes", []) if review is Dictionary \
				and (review as Dictionary).get("notes") is Array else []
			var runs: Variant = episode.read_json("runs")
			var data: Variant = episode.read_json("data")
			_submit_text(step, ProofPrompts.teacher(_title(), _brief(), _problem(),
				episode.read_text("notebook"), episode.read_text("proof"), solve if solve is Dictionary else {},
				_fix if step == "lesson" else {},
				episode.read_text("draft") if step == "lesson" else "", notes,
				runs if runs is Array else [], data if data is Dictionary else {}), "best")
		"review":
			_submit_text(step, ProofPrompts.student(_title(), _brief(), _problem(),
				episode.read_text("draft")), "best")
		"ink":
			_start_ink()
		"script":
			_finish(step, episode.write_text("script", episode.read_text("lesson").strip_edges() + "\n"))


func _title() -> String:
	return String(spec.get("title", "Ghost Notes"))


func _brief() -> String:
	return String(spec.get("brief", ""))


func _problem() -> Dictionary:
	var p: Variant = episode.read_json("problem")
	return p if p is Dictionary else {}


func _submit_text(step: String, p: Dictionary, tier: String, extra: Dictionary = {}) -> void:
	_tries[step] = int(_tries.get(step, 0)) + 1
	if String(p.get("prompt", "")).is_empty():
		_errors[step] = "its prompt could not be built (see the log)"
		_close_tools(step)
		return
	var job := {"kind": "text", "backend": String(spec.get("writer", "claude")), "tier": tier,
		"dir": episode.job_dir(step), "system": String(p.get("system", "")),
		"prompt": String(p["prompt"]), "label": "proof %s" % step,
		"model": String(spec.get("writer_model", "")), "effort": String(spec.get("writer_effort", ""))}
	job.merge(extra, true)
	var id := AgentJobs.submit(job)
	if id.is_empty():
		_errors[step] = "this session cannot start agents (read-only)"
		_close_tools(step)
		return
	_jobs[step] = id


## THE SOLVER at the desk, with its tools: a writer that takes none cannot check a proof, and says so.
func _make_solve() -> void:
	_close_tools("solve")
	DirAccess.remove_absolute(episode.job_dir("solve").path_join(ProofTools.SUBMITTED))
	var writer := String(spec.get("writer", "claude"))
	if not TextGen.has(writer) or not TextGen.make(writer).takes_tools():
		_errors["solve"] = "the writer picked takes no tools - pick one that does (Claude, Codex or Grok)"
		return
	if ProofTools.kind_of(_problem()) == "computation" and not ProofTools.can_run():
		_errors["solve"] = ("this problem is settled by running code, and this machine has no sandbox to run "
			+ "it in: install bubblewrap (see the Environment panel), or Refine the note into a proof")
		return
	if int(_tries.get("solve", 0)) == 0:
		# a solve begun afresh begins with an empty folder; a retry keeps what the first try saved
		Provision.remove_tree(episode.job_dir("solve").path_join("compute"))
	var toolset := ProofTools.new(episode, _problem(), episode.job_dir("solve"))
	var url := AgentTools.open(episode.job_dir("solve"), toolset)
	if url.is_empty():
		_errors["solve"] = "the tools could not be served (a read-only session?)"
		return
	_tools["solve"] = {"url": url, "set": toolset}
	_submit_text("solve", ProofPrompts.solver(_title(), _brief(), _problem(), ProofTools.can_run()), "best",
		{"tools_url": url, "timeout": SOLVE_TIMEOUT})


func _close_tools(step: String) -> void:
	var t: Dictionary = _tools.get(step, {})
	if t.is_empty():
		return
	AgentTools.close(String(t["url"]))
	_tools.erase(step)


## THE INK: every formula the lesson's pen writes, laid out by ghost's own TeX.
func _start_ink() -> void:
	_tries["ink"] = int(_tries.get("ink", 0)) + 1
	var items := DeskScript.items(episode.read_text("lesson"))
	var py := Deps.venv_bin("user://math_venv", "python")
	var host := BundledHosts.path("res://hosts/math/typeset.py")
	var latex := Provision.tool_path("tex", "latex")
	if host.is_empty() or latex.is_empty() or not FileAccess.file_exists(py):
		_errors["ink"] = "TeX or the math environment is missing"
		return
	var answer := episode.dir.path_join("ink.answer.json")
	var spec_path := episode.dir.path_join("ink.spec.json")
	var log := episode.dir.path_join("ink.log")
	DirAccess.remove_absolute(answer)
	var data: Variant = episode.read_json("data")
	var err := TextGen.put(spec_path, JSON.stringify({"items": items, "out": answer,
		"work": episode.dir.path_join("ink_work"), "width": PAD_WIDTH, "outlines": true,
		"bin": latex.get_base_dir(), "data": data if data is Dictionary else {}}))
	if not err.is_empty():
		_errors["ink"] = err
		return
	var pid := Subprocess.start_logged(py, PackedStringArray(["-I", host, spec_path]), log, "proof ink")
	if pid <= 0:
		_errors["ink"] = "TeX's layout could not start"
		return
	_local["ink"] = {"pid": pid, "out": answer, "log": log}


## A local step's outcome: "" written, else why not.
func _finish(step: String, err: String) -> void:
	if err.is_empty() and not episode.has(step):
		err = "it wrote nothing (see the log)"
	if not err.is_empty():
		_errors[step] = err


# --- landing -------------------------------------------------------------------------------------

func _land(step: String, res: Dictionary) -> void:
	var err := ""
	var handed := ""
	if step == "solve":
		var path := episode.job_dir("solve").path_join(ProofTools.SUBMITTED)
		handed = FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""
		var t: Dictionary = _tools.get("solve", {})
		var checks := int((t["set"] as ProofTools).checks) if not t.is_empty() else 0
		_close_tools("solve")
		err = _land_solve(handed, res, checks)
		if err.is_empty():
			# what the runs left in their folder was scratch: what they did is in runs.json
			Provision.remove_tree(episode.job_dir("solve").path_join("compute"))
	elif not bool(res.get("ok", false)):
		err = String(res.get("error", "the job failed"))
	else:
		match step:
			"problem":
				err = _land_problem(String(res.get("text", "")))
			"draft":
				err = _land_draft(String(res.get("text", "")))
			"review":
				err = _land_review(String(res.get("text", "")))
			"lesson":
				err = _land_lesson(String(res.get("text", "")))
	if err.is_empty():
		_errors.erase(step)
		return
	push_warning("ghost: proof %s - %s" % [step, err])
	if int(_tries.get(step, 0)) > (SOLVE_RETRIES if step == "solve" else RETRIES):
		_errors[step] = err


## THE FIXED PROBLEM, in the shape every later step reads: its words, its TeX, how it is checked, and
## for a proof a Lean statement that names `main` and stops before its proof and the facts it may not
## cite, for a computation what is computed.
func _land_problem(text: String) -> String:
	var d: Variant = TextGen.extract_json(text)
	if not (d is Dictionary):
		return "the framer's answer was not JSON"
	var got := land_problem(d as Dictionary)
	if got.has("error"):
		return String(got["error"])
	return episode.write_json("problem", got)


## The framer's answer [param d] made into a problem, or `{error}`. Static and pure for the gate.
## THE EPISODE'S NAME is `episode_title` (Cards' producer's key, under the one rule both are given:
## rules/agents/episode.yaml); its description and tags go up with the video.
##
## NOT EVERY CLAIM IS A THEOREM: `check` is "proof" (Lean) or "computation" (code that runs,
## [ProofTools]); anything else, or none - a problem framed before there were computations - is a proof.
## THE LENGTH THE NOTE ASKS FOR is `minutes`, `[least, most]` (one number is both), kept only when it
## is sound - [] otherwise, and a lesson with none has no set length ([ProofPrompts]).
static func land_problem(d: Dictionary) -> Dictionary:
	var out := {}
	for k in ["episode_title", "statement", "latex", "lean", "history", "audience", "description", "computation"]:
		out[k] = str(d.get(k, "")).strip_edges()
	out["minutes"] = minutes_of(d.get("minutes", []))
	out["check"] = "computation" if str(d.get("check", "")).strip_edges().to_lower() == "computation" else "proof"
	if String(out["episode_title"]).is_empty() or String(out["statement"]).is_empty():
		return {"error": "the problem has no episode title or no statement"}
	out["tags"] = Array(DataPath.strings(d.get("tags", [])))
	if out["check"] == "computation":
		if String(out["computation"]).is_empty():
			return {"error": "the problem is a computation and does not say what is computed"}
		out["lean"] = ""
		out["forbidden"] = []
		return out
	var lean := String(out["lean"])
	# a statement handed back with its proof, or its `:=`, keeps only the statement
	var at := lean.find(":=")
	if at >= 0:
		lean = lean.substr(0, at).strip_edges()
	lean = lean.trim_prefix("```lean").trim_suffix("```").strip_edges()
	out["lean"] = lean
	if not RegEx.create_from_string("^theorem\\s+main\\b").search(lean):
		return {"error": "the Lean statement does not state theorem main"}
	var forbidden: Array = []
	for f in (d.get("forbidden", []) if d.get("forbidden") is Array else []):
		var name := str(f).strip_edges()
		if not name.is_empty() and not name.contains(" "):
			forbidden.append(name)
	out["forbidden"] = forbidden
	return out


## [param m] as `[least, most]` minutes: one or two positive numbers (a number alone, or written as
## text, is taken too); [] for anything else, or a length no lesson could be (over
## [constant MOST_MINUTES]).
static func minutes_of(m: Variant) -> Array:
	var said: Array = m if m is Array else [m]
	if said.is_empty() or said.size() > 2:
		return []
	var got: Array = []
	for v in said:
		var x := float(v) if v is float or v is int else (str(v).to_float() if str(v).strip_edges().is_valid_float() else 0.0)
		if x <= 0.0 or x > MOST_MINUTES:
			return []
		got.append(x)
	return [got.min(), got.max()]


## THE SOLVER'S SESSION, ENDED. A handed-in proof was VERIFIED when it was handed in, and a handed-in
## result names runs that ran to their end (ProofTools accepts nothing else): `verified` or `computed`.
## With neither, the run is tried again; after that the episode goes on honestly unchecked, so long as
## there is a notebook to teach from - the lesson then says so.
func _land_solve(handed: String, res: Dictionary, checks: int) -> String:
	var r: Variant = episode.read_json("runs")
	var runs := (r as Array).size() if r is Array else 0
	if not handed.is_empty():
		var sub: Variant = JSON.parse_string(handed)
		var d: Dictionary = sub if sub is Dictionary else {}
		if bool(d.get("computed", false)):
			return episode.write_json("solve", {"verified": false, "computed": true, "checks": checks,
				"runs": runs, "result": String(d.get("result", "")), "evidence": d.get("runs", [])})
		episode.write_text("proof", String(d.get("code", episode.read_text("proof"))))
		# WHAT CHECKED IT, kept with the verdict: the upload says so, in these versions
		return episode.write_json("solve", {"verified": true, "checks": int(d.get("checks", checks)),
			"runs": runs, "axioms": d.get("axioms", {}), "seconds": d.get("seconds", 0.0),
			"lean": String(Provision.installed("lean").get("version", "")),
			"mathlib": String(Provision.workbench().get("tag", ""))})
	var why := ("the solver stopped without handing in a result" if ProofTools.kind_of(_problem()) == "computation"
		else "the solver stopped without handing in a verified proof")
	if not bool(res.get("ok", false)):
		why = "the solver stopped: %s" % String(res.get("error", "its run failed"))
	if int(_tries.get("solve", 0)) <= SOLVE_RETRIES:
		return why
	if episode.read_text("notebook").strip_edges().is_empty():
		return why + ", and left no notebook"
	return episode.write_json("solve", {"verified": false, "computed": false, "checks": checks, "runs": runs, "note": why})


## THE FIRST DRAFT: a lesson in the pen's format, with something on the pad. It is read by the
## student as it is; the lesson written from it is the one held to the audits.
func _land_draft(text: String) -> String:
	var draft := clean_lesson(text)
	if DeskScript.items(draft).is_empty():
		return "the draft writes nothing on the pad"
	print("ghost: proof draft - %s" % _runs(draft))
	return episode.write_text("draft", draft + "\n")


## THE STUDENT'S NOTES on the draft: `{notes: [{quote, need}]}`, at most [constant
## ProofPrompts.STUDENT_NOTES]. None is an answer too - the lesson is written again all the same.
func _land_review(text: String) -> String:
	var got := land_review(TextGen.extract_json(text))
	if got.has("error"):
		return String(got["error"])
	return episode.write_json("review", got)


## The student's answer [param d] as notes, or `{error}`. Static and pure for the gate.
static func land_review(d: Variant) -> Dictionary:
	if not (d is Dictionary) or not ((d as Dictionary).get("notes") is Array):
		return {"error": "the student's answer was not JSON with notes"}
	var notes: Array = []
	for n in (d as Dictionary)["notes"]:
		if not (n is Dictionary):
			continue
		var need := str((n as Dictionary).get("need", "")).strip_edges()
		if need.is_empty():
			continue
		notes.append({"quote": str((n as Dictionary).get("quote", "")).strip_edges().substr(0, 300),
			"need": need.substr(0, 600)})
		if notes.size() >= ProofPrompts.STUDENT_NOTES:
			break
	return {"notes": notes}


## THE LESSON, as the voice will read it: fences and stray framing off, at least one thing on the
## pad, and no notation in its speech ([method DeskScript.audit]) - a lesson that has some goes back
## once, told which lines. One that leaves pad lines unread ([method DeskScript.undictated]), says a
## formula's letter as the word "a" ([method DeskScript.bare_letters]), points at a name nothing on
## the pad carries ([method DeskScript.unknown_points]) or talks long over a still pen
## ([method DeskScript.still]) goes back once too, and is taken the second time: the desk writes such a
## line while the voice waits, the voice says "uh", the pen stays put, the viewer loses the thread.
## EVERY TAKE IS CHECKED AND THE LOG SAYS HOW IT STANDS (2026-10-19: "Was the problem fixed or not?" -
## a take after a send-back was taken unchecked, and nothing said): one taken with faults left warns
## with them, one that mends them says so. What a take was sent back for stays in [member _fix] until
## the lesson is made anew, so the take TeX sends back - written from the draft again, like the first
## - is told it too, and does not bring back what the second mended.
## THE LENGTH THE NOTE ASKS FOR, AND NO OTHER (2026-10-20: "a 5-10 minute request in the script turned
## into a 36-minute export"): every take's length is said in the log, and one that runs past the most
## minutes the note asks for by more than [constant LONG_BY] goes back too, told by how much. With no
## length asked, nothing sends a lesson back for running long ([ProofPrompts]).
func _land_lesson(text: String) -> String:
	var lesson := clean_lesson(text)
	if DeskScript.items(lesson).is_empty():
		return "the lesson writes nothing on the pad"
	var said := DeskScript.audit(lesson)
	if not said.is_empty():
		_fix["notation"] = Array(_fix.get("notation", [])) + Array(said)
		return "the lesson's speech carries notation (%d line%s)" % [said.size(), "" if said.size() == 1 else "s"]
	var found := {"undictated": DeskScript.undictated(lesson), "letters": DeskScript.bare_letters(lesson),
		"points": DeskScript.unknown_points(lesson), "still": DeskScript.still(lesson),
		"long": too_long(lesson, ProofPrompts.asked(_problem()))}
	var faults := lesson_faults(found)
	for k in found:
		if not (found[k] as PackedStringArray).is_empty():
			_fix[k] = Array(_fix.get(k, [])) + Array(found[k])
	var take := int(_tries.get("lesson", 0))
	print("ghost: proof lesson - take %d %s" % [take, _runs(lesson)])
	if not faults.is_empty() and take <= RETRIES:
		return faults
	if not faults.is_empty():
		push_warning("ghost: proof lesson - take %d is kept as it is: %s" % [take, faults])
	elif take > 1:
		print("ghost: proof lesson - take %d passes every check" % take)
	return episode.write_text("lesson", lesson + "\n")


## What [param found] (check -> what it caught, as [method _land_lesson] runs them) says is wrong with
## a lesson, every fault named; "" when nothing is.
static func lesson_faults(found: Dictionary) -> String:
	var bare: PackedStringArray = found.get("undictated", PackedStringArray())
	var letters: PackedStringArray = found.get("letters", PackedStringArray())
	var points: PackedStringArray = found.get("points", PackedStringArray())
	var still: PackedStringArray = found.get("still", PackedStringArray())
	var long: PackedStringArray = found.get("long", PackedStringArray())
	var out := PackedStringArray()
	if not bare.is_empty():
		out.append("%d pad line%s not read aloud as written" % [bare.size(), "" if bare.size() == 1 else "s"])
	if not letters.is_empty():
		out.append("%d line%s said a letter as the word a" % [letters.size(), "" if letters.size() == 1 else "s"])
	if not points.is_empty():
		out.append("it points at %s, which nothing on the pad is called" % ", ".join(points))
	if not still.is_empty():
		out.append("the pen stands still through %d long stretch%s of speech" % [still.size(), "" if still.size() == 1 else "es"])
	if not long.is_empty():
		out.append("it runs %s" % long[0])
	return "; ".join(out)


## THE LESSON RUN LONG: how far [param lesson] runs past [param asked] (`[least, most]` minutes, as
## [method ProofPrompts.asked] has it) when that is more than [constant LONG_BY] of the most - one line,
## as the log and the teacher are told it; none when it is within it, or nothing was asked.
static func too_long(lesson: String, asked: Array) -> PackedStringArray:
	if asked.size() != 2:
		return PackedStringArray()
	var runs := DeskScript.runtime(lesson)
	if runs <= float(asked[1]) * 60.0 * (1.0 + LONG_BY):
		return PackedStringArray()
	return PackedStringArray(["about %s minutes (%d spoken words), past the %s the note asks for" % [
		ProofPrompts.said_num(snappedf(runs / 60.0, 0.5)), (DeskScript.parse(lesson)["spoken"] as PackedStringArray).size(),
		String(ProofPrompts.length_of({"minutes": asked})["span"])]])


## How long [param lesson] runs, for the log: its minutes and spoken words, and the length its note
## asks for when it asks one.
func _runs(lesson: String) -> String:
	var said := ProofPrompts.length_of(_problem())
	return "runs about %s minutes (%d spoken words)%s" % [ProofPrompts.said_num(snappedf(DeskScript.runtime(lesson) / 60.0, 0.5)),
		(DeskScript.parse(lesson)["spoken"] as PackedStringArray).size(),
		(", the note asks for %s" % said["span"]) if bool(said["minutes"]) else ""]


## A teacher's reply as a lesson: a fenced reply unwrapped, outer blank lines off.
static func clean_lesson(text: String) -> String:
	var t := text.strip_edges()
	if t.begins_with("```"):
		var nl := t.find("\n")
		t = t.substr(nl + 1) if nl >= 0 else ""
		if t.ends_with("```"):
			t = t.substr(0, t.length() - 3)
	return t.strip_edges()


## TeX's layout landed. A formula it refused sends the lesson back once, with TeX's words for each;
## after that the ink stands as it is and the pen leaves the refused formulas out.
func _land_ink(job: Dictionary) -> void:
	var answer: Variant = JSON.parse_string(FileAccess.get_file_as_string(String(job["out"]))) \
		if FileAccess.file_exists(String(job["out"])) else null
	DirAccess.remove_absolute(String(job["out"]))
	if not (answer is Dictionary):
		var log := FileAccess.get_file_as_string(String(job["log"])).strip_edges()
		_errors["ink"] = "TeX's layout failed: " + log.right(300)
		return
	var broken: Array = []
	for r in (answer as Dictionary).get("items", []):
		if r is Dictionary and not bool((r as Dictionary).get("ok", false)):
			broken.append("%s: %s" % [_tex_of(String((r as Dictionary).get("id", ""))),
				String((r as Dictionary).get("error", ""))])
	if not broken.is_empty() and int(_tries.get("lesson", 0)) <= RETRIES + 1:
		_fix["broken"] = broken
		episode.invalidate("lesson")
		push_warning("ghost: proof ink - %d formula(s) TeX refused; the lesson is written again" % broken.size())
		return
	if not broken.is_empty():
		push_warning("ghost: proof ink - %d formula(s) TeX refused again; the pen leaves them out" % broken.size())
	elif _fix.has("broken"):
		print("ghost: proof ink - TeX sets every formula of the lesson written again")
	_fix.erase("broken")
	_finish("ink", episode.write_json("ink", answer))


func _tex_of(id: String) -> String:
	for it in DeskScript.items(episode.read_text("lesson")):
		if String((it as Dictionary)["id"]) == id:
			return String((it as Dictionary)["tex"]).substr(0, 400)
	return id
