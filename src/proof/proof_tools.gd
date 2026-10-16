extends RefCounted
class_name ProofTools

## ProofTools - what the mathematician at the desk can do while it works (next/proof.md, "How an
## episode is made"): add to its lab NOTEBOOK, check a Lean file with LEAN, and SUBMIT the finished
## proof. Served as tools ([AgentTools]), as the set dresser's are, so any writer that takes tools
## works with them - and every call is kept in the job's `tools.jsonl`.
##
## THE SOLVER'S TOOLS ARE THE DESK: what it writes and checks here is the trace the lesson is made
## from, so the work shown is the work done.
##
## A CHECK IS LEAN'S OWN ANSWER: `hosts/math/lean_check.py` runs the Lean REPL in ghost's Mathlib
## workbench ([method Provision.workbench_path]) and answers with Lean's errors, the goals before every
## tactic, the facts each used, the axioms and a verdict. VERIFIED means no error, no `sorry`, only
## Lean's three standard axioms, no forbidden fact (Mathlib's own copy of the theorem, caught through
## the facts used) and the theorem `main` stated. A check costs 12-40 s with a warm disk (2026-10-15;
## nearly all of it `import Mathlib`), more the first time after the cache is cold.

## The file a submitted proof is written to, in the job's folder: what the producer lands.
const SUBMITTED := "submitted.json"
## The most checks one solver may make: a runaway loop ends here, not in the author's quota.
const MAX_CHECKS := 40

var episode: ProofEpisode
var problem: Dictionary
var job_dir := ""
var checks := 0
var submitted := false


func _init(ep: ProofEpisode, fixed: Dictionary, dir: String) -> void:
	episode = ep
	problem = fixed
	job_dir = dir


func instructions() -> String:
	return ("You are working one math problem at a desk. Keep your lab notebook with `notebook`, check "
		+ "Lean files with `lean` (it is also a calculator: #eval), and hand in the finished proof with "
		+ "`submit`. The theorem is `main`, stated exactly as given.")


func list_tools() -> Array:
	return [
		{"name": "notebook", "description": "Add a section to your lab notebook, written for a student reading over your shoulder: what you try, what it gives, plain-words explanations, math in LaTeX between $...$. Sections are kept in order.",
			"inputSchema": {"type": "object", "properties": {"text": {"type": "string"}}, "required": ["text"]}},
		{"name": "lean", "description": "Check a whole Lean 4 file (start it with `import Mathlib`) against Mathlib. Answers with Lean's errors and warnings by line, the goals before each tactic, the library facts each step used, the axioms of each theorem, and VERIFIED or NOT VERIFIED. A file of #eval lines works as a calculator. Takes about half a minute.",
			"inputSchema": {"type": "object", "properties": {"code": {"type": "string"}}, "required": ["code"]}},
		{"name": "submit", "description": "Hand in the finished Lean file. It is checked again, and accepted only when VERIFIED.",
			"inputSchema": {"type": "object", "properties": {"code": {"type": "string"}}, "required": ["code"]}},
	]


func call_tool(name: String, args: Dictionary) -> Dictionary:
	match name:
		"notebook":
			return _notebook(str(args.get("text", "")))
		"lean":
			return await _lean(str(args.get("code", "")), false)
		"submit":
			return await _lean(str(args.get("code", "")), true)
	return {"text": "", "error": "no tool '%s'" % name}


func _notebook(text: String) -> Dictionary:
	if text.strip_edges().is_empty():
		return {"text": "", "error": "nothing to add"}
	var old := episode.read_text("notebook")
	var err := episode.write_text("notebook", (old.strip_edges() + "\n\n" if not old.strip_edges().is_empty() else "")
		+ text.strip_edges() + "\n")
	return {"text": "Added to the notebook."} if err.is_empty() else {"text": "", "error": err}


func _lean(code: String, submitting: bool) -> Dictionary:
	if code.strip_edges().is_empty():
		return {"text": "", "error": "the file is empty"}
	if checks >= MAX_CHECKS:
		return {"text": "", "error": "no checks left (%d made): write up what you have in the notebook" % checks}
	checks += 1
	# the Lean file as it stands is kept, whatever Lean says of it
	episode.write_text("proof", code)
	var got: Dictionary = await check(code, Array(problem.get("forbidden", [])), "main")
	if not bool(got.get("ok", false)):
		return {"text": "", "error": str(got.get("report", "the check could not run"))}
	var report := str(got.get("report", ""))
	if not submitting:
		return {"text": report}
	if not bool(got.get("verified", false)):
		return {"text": report + "\n\nNot accepted: only a VERIFIED file can be submitted."}
	submitted = true
	var err := TextGen.put(job_dir.path_join(SUBMITTED), JSON.stringify({"code": code,
		"axioms": got.get("axioms", {}), "checks": checks, "seconds": got.get("seconds", 0.0)}, "\t"))
	if not err.is_empty():
		return {"text": "", "error": err}
	return {"text": report + "\n\nAccepted. The proof is handed in."}


## CHECK [param code] with Lean (see the class note): the host's answer - `{ok, verified, report,
## messages, tactics, axioms, forbidden_used, seconds}` - or `{ok: false, report}` when it could not
## run (Lean or Mathlib not installed yet, the math environment missing). Awaits the host.
static func check(code: String, forbidden: Array, theorem := "main") -> Dictionary:
	var bench := Provision.workbench_path()
	var lake := Provision.tool_path("lean", "lake")
	if bench.is_empty() or lake.is_empty() or Provision.repl_path().is_empty():
		return {"ok": false, "report": "Lean and Mathlib are not installed yet (Ghost Notes fetches them: about 11 GB)."}
	var py := Deps.venv_bin("user://math_venv", "python")
	var host := BundledHosts.path("res://hosts/math/lean_check.py")
	if not FileAccess.file_exists(py) or host.is_empty():
		return {"ok": false, "report": "the math environment is not installed yet"}
	var work := ProjectSettings.globalize_path("user://lean/checks")
	DirAccess.make_dir_recursive_absolute(work)
	var stamp := "%d_%d" % [Time.get_ticks_usec(), randi()]
	var spec := work.path_join("check_%s.json" % stamp)
	var out := work.path_join("check_%s.out.json" % stamp)
	var log := work.path_join("check_%s.log" % stamp)
	var err := TextGen.put(spec, JSON.stringify({"code": code, "out": out, "bench": bench, "lake": lake,
		"forbidden": forbidden, "theorem": theorem}))
	if not err.is_empty():
		return {"ok": false, "report": err}
	var pid := Subprocess.start_logged(py, PackedStringArray(["-I", host, spec]), log, "lean check")
	if pid <= 0:
		return {"ok": false, "report": "the Lean check could not start"}
	var tree := Engine.get_main_loop() as SceneTree
	while Subprocess.alive(pid):
		await tree.create_timer(0.25).timeout
	var answer: Variant = JSON.parse_string(FileAccess.get_file_as_string(out)) if FileAccess.file_exists(out) else null
	for f in [spec, out]:
		DirAccess.remove_absolute(f)
	if not (answer is Dictionary):
		var said := FileAccess.get_file_as_string(log)
		return {"ok": false, "report": "the Lean check failed: " + said.strip_edges().right(600)}
	DirAccess.remove_absolute(log)
	return answer
