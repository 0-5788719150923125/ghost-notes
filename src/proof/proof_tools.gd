extends RefCounted
class_name ProofTools

## ProofTools - what the solver at the desk can do while it works (next/proof.md, "How an episode is
## made"): add to its lab NOTEBOOK, check a Lean file with LEAN, RUN code, and SUBMIT what it finished.
## Served as tools ([AgentTools]), as the set dresser's are, so any writer that takes tools works with
## them - and every call is kept in the job's `tools.jsonl`.
##
## THE SOLVER'S TOOLS ARE THE DESK: what it writes, checks and runs here is the trace the lesson is
## made from, so the work shown is the work done.
##
## A CHECK IS LEAN'S OWN ANSWER: `hosts/math/lean_check.py` runs the Lean REPL in ghost's Mathlib
## workbench ([method Provision.workbench_path]) and answers with Lean's errors, the goals before every
## tactic, the facts each used, the axioms and a verdict. VERIFIED means no error, no `sorry`, only
## Lean's three standard axioms, no forbidden fact (Mathlib's own copy of the theorem, caught through
## the facts used) and the theorem `main` stated. A check costs 12-40 s with a warm disk (2026-10-15;
## nearly all of it `import Mathlib`), more the first time after the cache is cold.
##
## NOT EVERY CLAIM IS A THEOREM (the user, 2026-10-19: "I don't want to specialize that mode too much
## on just math: it should be a general theorem-prover and learning tool"): a claim about a model, a
## simulation or data is settled by code that RAN. `run` hands Python to `hosts/compute/run.py`, which
## runs it in a sandbox (bubblewrap: the system read-only, one folder to write in, no network, nothing
## of the author's; its memory, time and files capped) in the compute environment (numpy, SciPy,
## SymPy). Each run is kept in the episode's `runs.json` - its code and what it printed - and the series
## it kept with `keep()` in `data.json`, which the pad's drawings plot by name (figure.py). Where there
## is no sandbox the tool is not offered ([method can_run]), and a problem framed as a computation is
## not solved here.
##
## WHAT IS SUBMITTED depends on the problem's `check` ([method kind_of]): a "proof" is a Lean file,
## accepted only VERIFIED; a "computation" is the result in words with the runs that show it, each one
## that ran to its end.

## The file a submission is written to, in the job's folder: what the producer lands.
const SUBMITTED := "submitted.json"
## The most checks one solver may make: a runaway loop ends here, not in the author's quota.
const MAX_CHECKS := 40
## The most runs one solver may make, and the longest one may take (seconds; the host also stops one
## whose folder grows past its limit).
const MAX_RUNS := 60
const RUN_SECONDS := 300.0
const RUN_SECONDS_DEFAULT := 60.0

## The compute environment runs are made in. Moved aside only by a probe, to run in a scratch one.
static var venv := "user://compute_venv"

var episode: ProofEpisode
var problem: Dictionary
var job_dir := ""
var checks := 0
var runs := 0
var submitted := false
var _running := false


func _init(ep: ProofEpisode, fixed: Dictionary, dir: String) -> void:
	episode = ep
	problem = fixed
	job_dir = dir


## "proof" (a Lean statement to prove) or "computation" (a claim settled by code that runs) - the
## framer's `check`; a problem framed before there were computations is a proof.
static func kind_of(p: Dictionary) -> String:
	return "computation" if String(p.get("check", "")) == "computation" else "proof"


## Whether code can be run on this machine: Linux, with bubblewrap for the sandbox.
static func can_run() -> bool:
	return Deps.platform().begins_with("linux") and not Deps.resolve("bwrap").is_empty()


func instructions() -> String:
	if kind_of(problem) == "computation":
		return ("You are working one problem at a desk. Keep your lab notebook with `notebook`, run Python "
			+ "with `run`, and hand in the result with `submit`.")
	return ("You are working one problem at a desk. Keep your lab notebook with `notebook`, check Lean "
		+ "files with `lean` (it is also a calculator: #eval)%s, and hand in the finished proof with `submit`. "
		+ "The theorem is `main`, stated exactly as given.") % (", run Python with `run`" if can_run() else "")


func list_tools() -> Array:
	var out: Array = [
		{"name": "notebook", "description": "Add a section to your lab notebook, written for a student reading over your shoulder: what you try, what it gives, plain-words explanations, math in LaTeX between $...$. Sections are kept in order.",
			"inputSchema": {"type": "object", "properties": {"text": {"type": "string"}}, "required": ["text"]}},
	]
	var computing := kind_of(problem) == "computation"
	if not computing:
		out.append({"name": "lean", "description": "Check a whole Lean 4 file (start it with `import Mathlib`) against Mathlib. Answers with Lean's errors and warnings by line, the goals before each tactic, the library facts each step used, the axioms of each theorem, and VERIFIED or NOT VERIFIED. A file of #eval lines works as a calculator. Takes about half a minute.",
			"inputSchema": {"type": "object", "properties": {"code": {"type": "string"}}, "required": ["code"]}})
	if can_run():
		out.append({"name": "run", "description": ("Run a Python 3 program (numpy, scipy and sympy are installed, and the standard library) in a sandbox: no network, no files but its own folder, which is kept between your runs. Answers with its exit status, what it printed and its errors. keep(name, y) or keep(name, x, y) - a builtin - keeps a named series of numbers (y against x, or against 0, 1, 2, ...; about=\"what it is\" optional) that the lesson's drawings can plot. Fix the random seed of anything random. Default time limit %d s (seconds: up to %d); memory 4 GB.") % [int(RUN_SECONDS_DEFAULT), int(RUN_SECONDS)],
			"inputSchema": {"type": "object", "properties": {"code": {"type": "string"}, "seconds": {"type": "number"}}, "required": ["code"]}})
	if computing:
		out.append({"name": "submit", "description": "Hand in the result: what the computation found, in plain words with its numbers, and the numbers of the runs that show it - each one must have run to its end.",
			"inputSchema": {"type": "object", "properties": {"result": {"type": "string"}, "runs": {"type": "array", "items": {"type": "integer"}}}, "required": ["result", "runs"]}})
	else:
		out.append({"name": "submit", "description": "Hand in the finished Lean file. It is checked again, and accepted only when VERIFIED.",
			"inputSchema": {"type": "object", "properties": {"code": {"type": "string"}}, "required": ["code"]}})
	return out


func call_tool(name: String, args: Dictionary) -> Dictionary:
	var computing := kind_of(problem) == "computation"
	match name:
		"notebook":
			return _notebook(str(args.get("text", "")))
		"lean":
			if not computing:
				return await _lean(str(args.get("code", "")), false)
		"run":
			if can_run():
				return await _run(str(args.get("code", "")), args.get("seconds", RUN_SECONDS_DEFAULT))
		"submit":
			if computing:
				return _submit_result(str(args.get("result", "")), args.get("runs", []))
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


## RUN [param code] in the sandbox (see the class note), one run at a time - the folder is shared. The
## run is kept in the episode's `runs.json` and what it kept in `data.json`, whatever it did.
func _run(code: String, seconds: Variant) -> Dictionary:
	if code.strip_edges().is_empty():
		return {"text": "", "error": "the program is empty"}
	if runs >= MAX_RUNS:
		return {"text": "", "error": "no runs left (%d made): write up what you have in the notebook" % runs}
	var tree := Engine.get_main_loop() as SceneTree
	while _running:
		await tree.create_timer(0.25).timeout
	_running = true
	var limit := clampf(float(seconds) if (seconds is float or seconds is int) else RUN_SECONDS_DEFAULT, 1.0, RUN_SECONDS)
	var got: Dictionary = await run_code(code, job_dir.path_join("compute"), job_dir.path_join("run_io"), limit)
	_running = false
	if not bool(got.get("ok", false)):
		return {"text": "", "error": str(got.get("error", "the run could not start"))}
	runs += 1
	var all := _runs()
	var n := all.size() + 1
	var kept: Dictionary = got["kept"] if got.get("kept") is Dictionary else {}
	var entry := {"n": n, "code": code, "exit": int(got.get("exit", -1)), "timed_out": bool(got.get("timed_out", false)),
		"seconds": float(got.get("seconds", 0.0)), "stdout": str(got.get("stdout", "")),
		"stderr": str(got.get("stderr", "")), "error": str(got.get("error", "")), "kept": kept.keys()}
	all.append(entry)
	var err := episode.write_json("runs", all)
	if err.is_empty() and not kept.is_empty():
		var data: Dictionary = episode.read_json("data") if episode.read_json("data") is Dictionary else {}
		for k in kept:
			data[k] = {"points": (kept[k] as Dictionary).get("points", []), "about": str((kept[k] as Dictionary).get("about", "")), "run": n}
		err = episode.write_json("data", data)
	if not err.is_empty():
		return {"text": "", "error": err}
	return {"text": run_report(entry, kept)}


## The runs made so far, oldest first.
func _runs() -> Array:
	var r: Variant = episode.read_json("runs")
	return r if r is Array else []


## A run as the solver is shown it: how it ended, what it printed, its errors, what it kept.
static func run_report(entry: Dictionary, kept: Dictionary) -> String:
	var lines := PackedStringArray()
	var how := "exit %d in %.1f s" % [int(entry.get("exit", -1)), float(entry.get("seconds", 0.0))]
	if not str(entry.get("error", "")).is_empty():
		how = "%s - %s" % [how, str(entry["error"])]
	lines.append("Run %d: %s." % [int(entry.get("n", 0)), how])
	lines.append("Printed:")
	lines.append(str(entry.get("stdout", "")).strip_edges() if not str(entry.get("stdout", "")).strip_edges().is_empty() else "(nothing)")
	if not str(entry.get("stderr", "")).strip_edges().is_empty():
		lines.append("Errors and warnings:")
		lines.append(str(entry["stderr"]).strip_edges())
	if not kept.is_empty():
		var said := PackedStringArray()
		for k in kept:
			said.append("%s (%s)" % [k, series_summary((kept[k] as Dictionary).get("points", []))])
		lines.append("Kept for drawings: " + ", ".join(said))
	return "\n".join(lines)


## A kept series in a few words: how many points, and the range of each coordinate.
static func series_summary(points: Variant) -> String:
	var pts: Array = points if points is Array else []
	if pts.is_empty():
		return "no points"
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for p in pts:
		if p is Array and (p as Array).size() == 2:
			var v := Vector2(float(p[0]), float(p[1]))
			lo = Vector2(minf(lo.x, v.x), minf(lo.y, v.y))
			hi = Vector2(maxf(hi.x, v.x), maxf(hi.y, v.y))
	return "%d point%s, x from %s to %s, y from %s to %s" % [pts.size(), "" if pts.size() == 1 else "s",
		_short(lo.x), _short(hi.x), _short(lo.y), _short(hi.y)]


static func _short(v: float) -> String:
	if absf(v) < 1e9 and is_equal_approx(v, roundf(v)):
		return str(int(roundf(v)))
	return String.num(v, 4) if absf(v) >= 0.001 else "%.3e" % v


## THE RESULT of a computation, handed in: the words and the runs that show it, each one that ran to
## its end ([constant SUBMITTED]).
func _submit_result(result: String, cited: Variant) -> Dictionary:
	if result.strip_edges().is_empty():
		return {"text": "", "error": "say what the computation found"}
	var all := _runs()
	var picked: Array = []
	for v in (cited if cited is Array else []):
		var n := int(v)
		if n < 1 or n > all.size():
			return {"text": "", "error": "there is no run %d (%d made)" % [n, all.size()]}
		var r: Dictionary = all[n - 1]
		if int(r.get("exit", -1)) != 0 or bool(r.get("timed_out", false)):
			return {"text": "", "error": "run %d did not run to its end: name runs that did" % n}
		if not picked.has(n):
			picked.append(n)
	if picked.is_empty():
		return {"text": "", "error": "name the runs that show the result"}
	var err := TextGen.put(job_dir.path_join(SUBMITTED), JSON.stringify({"computed": true,
		"result": result.strip_edges(), "runs": picked, "count": all.size()}, "\t"))
	if not err.is_empty():
		return {"text": "", "error": err}
	submitted = true
	return {"text": "Accepted. The result is handed in."}


## RUN [param code] in the sandbox ([code]hosts/compute/run.py[/code]), [param work] its folder,
## [param io_root] where each run's own files go (removed after): the host's answer - `{ok, exit,
## timed_out, seconds, stdout, stderr, kept, work_mb, error}` - or `{ok: false, error}` when it could
## not run (no sandbox, the compute environment missing). Awaits the host.
static func run_code(code: String, work: String, io_root: String, seconds: float) -> Dictionary:
	var bwrap := Deps.resolve("bwrap")
	if bwrap.is_empty():
		return {"ok": false, "error": "there is no sandbox to run code in: bubblewrap is not installed"}
	var py := Deps.venv_bin(venv, "python")
	var host := BundledHosts.path("res://hosts/compute/run.py")
	if not FileAccess.file_exists(py) or host.is_empty():
		return {"ok": false, "error": "the compute environment is not installed yet"}
	DirAccess.make_dir_recursive_absolute(io_root)
	var stamp := "%d_%d" % [Time.get_ticks_usec(), randi()]
	var io := io_root.path_join(stamp)
	var spec := io_root.path_join("run_%s.json" % stamp)
	var out := io_root.path_join("run_%s.out.json" % stamp)
	var log := io_root.path_join("run_%s.log" % stamp)
	var err := TextGen.put(spec, JSON.stringify({"code": code, "out": out, "work": work, "io": io,
		"seconds": seconds, "bwrap": bwrap}))
	if not err.is_empty():
		return {"ok": false, "error": err}
	var pid := Subprocess.start_logged(py, PackedStringArray(["-I", host, spec]), log, "proof run")
	if pid <= 0:
		return {"ok": false, "error": "the run could not start"}
	var tree := Engine.get_main_loop() as SceneTree
	while Subprocess.alive(pid):
		await tree.create_timer(0.25).timeout
	var answer: Variant = JSON.parse_string(FileAccess.get_file_as_string(out)) if FileAccess.file_exists(out) else null
	for f in [spec, out, io.path_join("code.py"), io.path_join("stdout.txt"), io.path_join("stderr.txt")]:
		DirAccess.remove_absolute(f)
	DirAccess.remove_absolute(io)
	if not (answer is Dictionary):
		var said := FileAccess.get_file_as_string(log)
		return {"ok": false, "error": "the run failed: " + said.strip_edges().right(600)}
	DirAccess.remove_absolute(log)
	return answer


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
