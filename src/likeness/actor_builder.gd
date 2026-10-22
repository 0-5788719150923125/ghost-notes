extends RefCounted
class_name ActorBuilder

## ActorBuilder - makes whatever an actor is missing, in the order [ActorSteps] gives, the way
## [ProofProducer] makes a Proof episode's (next/likeness.md, "The runner").
##
## THE ORDER IS NOT A SCRIPT: every [method tick] lands what ended and starts each step whose inputs
## exist and whose own output is missing - or stale, when that was asked for - over every video, the
## actor or the chosen set ([method ActorFolder.scopes_of]). Nothing runs on its own: [method start] is a
## person pressing Generate or a step's ▶, since the steps cost hours of CPU and the agents quota.
##
## WHAT RUNS AT ONCE, by lane: one step that takes the processor (MediaPipe takes every core it is
## given), one download (the network, beside it), one quick step, and one agent job.
##
## A STEP IS FILES: a program's step writes its output under a temporary name and renames it into
## place, so a step whose output is newer than its start succeeded - whatever its exit said - and a
## stopped one left nothing half made. A stopped survey loses at most the video in hand. A step whose
## environment is installing is not failed: it waits, and [member waiting] says for what.
##
## WHAT IS THE ACTOR'S IS MADE FROM EVERY VIDEO (the second build, 2026-10-21): their range of mouth
## shapes and their head's motion read every steady set's usable shots ([method shots_of]); a set's
## still, rig and library are the set's own, its library's mouths and eyes from any video.

signal changed

## The lane each kind of step runs in.
const LANES := {"download": "net", "probe": "quick", "local": "quick", "python": "cpu", "agent": "agent"}
## An agent step's reply that is not what was asked is asked again this many times.
const RETRIES := 1
## A set is audited when it has at least this many usable minutes; a smaller one is kept as it is.
const AUDIT_LEAST := 2.0
## A DOWNLOAD THAT SAYS NOTHING FOR THIS LONG IS STUCK (2026-10-21: an old yt-dlp sat at "Downloading
## webpage" for good, and the download lane with it): stopped, and tried once more.
const STALL_S := 300
## The most contact sheets one audit job is shown.
const AUDIT_SHEETS := 14
## THE FILE A PROGRAM'S STEP IS JUDGED BY: written last, so newer than the run's start only when the
## step finished.
const MAIN := {"survey": "survey.bin", "shots": "shots.json", "sets": "sets.json", "transcribe": "transcript.json",
	"visemes": "visemes.json", "learn": "mouth_model.json",
	"motion": "motion.json", "stills": "stills.json", "rig": "rig.json", "library": "library.json"}
## Candidate stills a set keeps (enough that some show them at rest: on his footage two of six did, the
## fourth pass); prototype mouths per sound and eyes per state its library keeps.
const STILLS := 12
const VARIANTS := 3
const EYE_VARIANTS := 2
## The most minutes of their head's motion kept.
const MOTION_MINUTES := 60.0

var actor: ActorFolder
## Is a run asked for and not done?
var running := false
## What the run waits to be installed, "" when nothing.
var waiting := ""
## The steps this run makes; every step when empty.
var only: Array = []
## Remake what is stale as well as what is missing.
var refresh := true
## WHO LABELS: `{agent, model, effort}`, the card's [AgentPick].
var writer := {"agent": "claude", "model": "", "effort": ""}
## A GATE'S SEAM: when set, a step is made by calling it - `(step, scope) -> String`, "" once its
## outputs are written - instead of running its program or its agent, and stamped as made. The order,
## the waiting and the staleness are the real ones (tests/likeness/actors_check.gd).
var make_with: Callable

## A COMMAND-LINE TOOL'S SEAM ([method allow_for_tool]): outside the app no Provisioner runs, so an
## environment whose Python is there is taken as it is.
static var _tool := false

var _runs := {}         # "step|scope" -> the run
var _errors := {}       # "step|scope" -> why it failed
var _listings := {}     # source index -> {pid, out, err, t0}


func _init(a: ActorFolder) -> void:
	actor = a


## For a tool booted with `--script`, where no Provisioner installs anything: take ghost's environments
## as they are, when their Python is there (as [method AgentJobs.allow_for_tool] lets it start agents).
static func allow_for_tool() -> void:
	_tool = true


# --- what is asked ---------------------------------------------------------------------------------

## GENERATE ([param steps] empty) or ▶ (a step and what it needs): make what is missing and stale.
func start(steps: Array = []) -> void:
	only = steps.duplicate()
	refresh = true
	running = true
	_errors.clear()
	tick()
	changed.emit()


## ⟳: [param step]'s outputs thrown away over every scope, and made again; what is made from it is
## stale once it is.
func redo(step: String) -> void:
	for sc in actor.scopes_of(step):
		if not _runs.has(_key(step, String(sc))):
			actor.drop(step, String(sc))
	if step == "audit":
		Actors._remove_tree(actor.dir.path_join("audit.parts"))
	start([step])


## STOP: every run ends now; what each finished is kept.
func stop() -> void:
	running = false
	waiting = ""
	for k in _runs.keys():
		_end_run(_runs[k])
	_runs.clear()
	for si in _listings.keys():
		Subprocess.stop(int((_listings[si] as Dictionary)["pid"]))
	_listings.clear()
	changed.emit()


func busy() -> bool:
	return not _runs.is_empty() or not _listings.is_empty()


static func _key(step: String, scope: String) -> String:
	return step + "|" + scope


# --- what the card reads --------------------------------------------------------------------------

## "running", "queued", "failed", or the actor's own: "made", "stale", "missing".
func state_of(step: String, scope: String) -> String:
	if _runs.has(_key(step, scope)):
		return "running"
	if _errors.has(_key(step, scope)):
		return "failed"
	return actor.state_of(step, scope)


func error_of(step: String, scope: String) -> String:
	return String(_errors.get(_key(step, scope), ""))


## Why each failed run failed, by "step|scope" (read only).
func errors() -> Dictionary:
	return _errors


## [param step] over all its scopes, for its row: `{state, made, total, progress, said, error}` - the
## row's state the worst of its scopes' (running first), `said` what the running one is doing; "moot"
## when it has nothing to do for any (a folder's videos are not fetched), and its moot scopes counted out.
func row_of(step: String) -> Dictionary:
	var scopes := actor.scopes_of(step)
	var out := {"state": "missing", "made": 0, "total": scopes.size(), "progress": -1.0, "said": "", "error": ""}
	if scopes.is_empty():
		out["state"] = "waiting"
		return out
	var states := {}
	var moot := 0
	for sc in scopes:
		if actor.moot(step, String(sc)) and not _runs.has(_key(step, String(sc))):
			moot += 1
			continue
		var st := state_of(step, String(sc))
		states[st] = true
		if st == "made" or st == "stale":
			out["made"] = int(out["made"]) + 1
		if st == "running":
			var run: Dictionary = _runs[_key(step, String(sc))]
			out["progress"] = _progress_of(run)
			out["said"] = String(run.get("said", ""))
		if st == "failed" and String(out["error"]).is_empty():
			out["error"] = error_of(step, String(sc))
	# NOTHING TO DO FOR ANY OF THEM: a folder's videos are not fetched, and need no captions link
	if moot == scopes.size():
		out["state"] = "moot"
		return out
	out["total"] = scopes.size() - moot
	for st in ["running", "failed", "missing", "stale", "made"]:
		if states.has(st):
			out["state"] = st
			break
	if out["state"] == "made" or out["state"] == "stale":
		var one := String(scopes[0])
		out["said"] = actor.summary_of(step, one) if scopes.size() == 1 else ""
	return out


func _progress_of(run: Dictionary) -> float:
	var p := String(run.get("progress", ""))
	if not p.is_empty() and FileAccess.file_exists(p):
		var t := FileAccess.get_file_as_string(p).strip_edges()
		if t.is_valid_float():
			return clampf(t.to_float(), 0.0, 1.0)
	return float(run.get("share", -1.0))


# --- the loop --------------------------------------------------------------------------------------

## Land what ended; start what can start.
func tick() -> void:
	var moved := false
	actor.forget()
	for k in _runs.keys():
		var run: Dictionary = _runs[k]
		if _poll(run):
			_runs.erase(k)
			actor.forget()
			moved = true
	for si in _listings.keys():
		if _poll_listing(int(si)):
			moved = true
	var was := waiting
	waiting = ""
	if running:
		var lanes := {}
		for k in _runs:
			lanes[String((_runs[k] as Dictionary)["lane"])] = true
		for step in ActorSteps.ORDER:
			if not (only.is_empty() or only.has(step)):
				continue
			var lane := String(LANES.get(String(Registry.field(ActorSteps.REGISTRY, step, "runs", "local")), "quick"))
			for sc in actor.scopes_of(step):
				var scope := String(sc)
				if lanes.has(lane):
					break
				if _runs.has(_key(step, scope)) or _errors.has(_key(step, scope)) or actor.moot(step, scope):
					continue
				var st := actor.state_of(step, scope)
				if st == "made" or (st == "stale" and not refresh):
					continue
				if not _needs_ready(step, scope):
					continue
				var lacks := "" if make_with.is_valid() else _lacks(step)
				if not lacks.is_empty():
					waiting = lacks
					continue
				var run := _start(step, scope, lane)
				if run.is_empty():
					continue
				_runs[_key(step, scope)] = run
				lanes[lane] = true
				moved = true
		if _runs.is_empty() and waiting.is_empty() and _listings.is_empty():
			running = false
			moved = true
	if moved or waiting != was:
		changed.emit()


## Is everything [param step] over [param scope] reads there - made, or stale and not about to be
## made again in this run?
func _needs_ready(step: String, scope: String) -> bool:
	for need in ActorSteps.needs(step):
		for sc in actor._need_scopes(String(need), scope):
			var key := _key(String(need), String(sc))
			if _runs.has(key):
				return false
			# CAPTIONS THAT COULD NOT BE FETCHED are no captions: the words go on without them (and are
			# stale once a later fetch brings some)
			if String(need) == "captions" and _errors.has(key):
				continue
			if actor.moot(String(need), String(sc)):
				if String(need) == "fetch" and actor.video_path(String(sc).substr(2)).is_empty():
					return false
				continue
			var st := actor.state_of(String(need), String(sc))
			if st == "missing":
				return false
			if st == "stale" and refresh and (only.is_empty() or only.has(need)) and not _errors.has(key):
				return false
	return true


## What [param step] runs on that is not installed yet - asked to be installed, and named - or "".
func _lacks(step: String) -> String:
	var names := PackedStringArray()
	for k in Registry.field(ActorSteps.REGISTRY, step, "env", []) as Array:
		var row := Deps.entry(String(k))
		if _tool and row.has("path") and FileAccess.file_exists(Deps.venv_bin(String(row["path"]), "python")):
			continue
		if not Provision.ensure(String(k)):
			names.append(String(row.get("name", k)))
	if String(Registry.field(ActorSteps.REGISTRY, step, "runs", "")) == "agent":
		if not TextGen.has(String(writer["agent"])):
			names.append("a writer")
	return "" if names.is_empty() else "installing %s" % " and ".join(names)


# --- running a step --------------------------------------------------------------------------------

func _ffmpeg() -> String:
	return Provision.tool_path("ffmpeg", "ffmpeg")


func _logs() -> String:
	var d := actor.dir.path_join("logs")
	DirAccess.make_dir_recursive_absolute(d)
	return d


## Start [param step] over [param scope]: its run, or {} when it ended at once (landed or failed).
func _start(step: String, scope: String, lane: String) -> Dictionary:
	var run := {"step": step, "scope": scope, "lane": lane, "phase": 0, "pid": -1, "job": "",
		"t0": int(Time.get_unix_time_from_system()), "tries": 0, "said": "", "state": {}}
	var err := ""
	if make_with.is_valid():
		err = String(make_with.call(step, scope))
		if err.is_empty():
			actor.put_stamp(step, scope, "made by a gate")
			return {}
	else:
		err = _phase(run)
	if err == "done":
		return {}
	if not err.is_empty():
		_errors[_key(step, scope)] = err
		push_warning("ghost: actor %s %s - %s" % [step, scope, err])
		return {}
	return run


## Start what [param run] does next: "" when it is under way, "done" when the step is made, else why
## it failed.
func _phase(run: Dictionary) -> String:
	var step := String(run["step"])
	var scope := String(run["scope"])
	var vid := scope.substr(2) if scope.begins_with("v:") else ""
	var sid := scope.substr(2) if scope.begins_with("s:") else ""
	var out := actor.scope_dir(scope)
	DirAccess.make_dir_recursive_absolute(out)
	var ff := _ffmpeg()
	match step:
		"fetch":
			return _fetch(run, vid, false)
		"captions":
			return _fetch(run, vid, true)
		"probe":
			var probe := Provision.tool_path("ffmpeg", "ffprobe")
			if probe.is_empty():
				return "FFmpeg's ffprobe is not installed"
			run["json"] = _logs().path_join("probe_%s.json" % vid)
			return _spawn_redirected(run, probe, PackedStringArray(["-v", "error", "-select_streams", "v:0",
				"-show_entries", "stream=width,height,avg_frame_rate,r_frame_rate:format=duration", "-of", "json",
				actor.video_path(vid)]), String(run["json"]))
		"survey":
			var s := actor.settings()
			return _spawn_py(run, ["survey", "--ffmpeg", ff, "--face-model", Provision.file_path("face_model"),
				"--pose-model", Provision.file_path("pose_model"), "--video", actor.video_path(vid),
				"--out", out.path_join("survey.bin"), "--interval", str(s["survey_interval"])], "surveying")
		"shots":
			return _spawn_py(run, ["shots", "--ffmpeg", ff, "--video", actor.video_path(vid), "--survey",
				out.path_join("survey.bin"), "--out", out.path_join("shots.json"), "--min-shot",
				str(actor.settings()["shortest_shot"])], "finding cuts")
		"transcribe":
			var spans: Array = []
			var heard := 0.0
			var most := float(actor.settings()["listen_minutes"]) * 60.0
			for sh in shots_of(actor):
				var d: Dictionary = sh
				if String(d["vid"]) != vid or heard >= most:
					continue
				var t1 := minf(float(d["end"]), float(d["start"]) + most - heard)
				spans.append([float(d["start"]), t1])
				heard += t1 - float(d["start"])
			if spans.is_empty():
				var e := ActorFolder.write_file(out.path_join("transcript.json"), JSON.stringify({"words": [], "seconds": 0}))
				if not e.is_empty():
					return e
				actor.put_stamp(step, scope, "nothing usable to hear")
				return "done"
			var spec := out.path_join("transcribe.spec.json")
			var e := ActorFolder.write_file(spec, JSON.stringify({"video": actor.video_path(vid), "spans": spans,
				"out": out.path_join("transcript.json")}))
			if not e.is_empty():
				return e
			return _spawn(run, "user://speech_venv", "res://hosts/speech/transcribe.py", ["--ffmpeg", ff, "--model",
				Provision.file_path("whisper_model").get_base_dir(), "--spec", spec], "listening")
		"words":
			return _make_words(vid)
		"sets":
			var vids: Array = []
			for v in actor.ticked():
				var p := actor.video_path(String(v))
				if p.is_empty():
					continue
				vids.append({"vid": v, "path": p, "label": String(actor.video(String(v)).get("title", v)).substr(0, 40),
					"survey": actor.video_dir(String(v)).path_join("survey.bin"),
					"shots": actor.video_dir(String(v)).path_join("shots.json")})
			var spec := actor.dir.path_join("sets.spec.json")
			var e := ActorFolder.write_file(spec, JSON.stringify({"videos": vids}))
			if not e.is_empty():
				return e
			return _spawn_py(run, ["sets", "--ffmpeg", ff, "--spec", spec, "--out", actor.dir.path_join("sets.json"),
				"--sheets", actor.sheets_dir(), "--threshold", str(actor.settings()["set_threshold"])], "grouping shots")
		"audit":
			return _audit_next(run)
		"visemes":
			var shots := shots_of(actor)
			var spec := actor.dir.path_join("visemes.spec.json")
			var e := ActorFolder.write_file(spec, JSON.stringify({"videos": videos_spec(), "shots": shots,
				"phones": phones_of(actor, shots), "classes": Visemes.ranges(), "least": 30}))
			if not e.is_empty():
				return e
			return _spawn_py(run, ["visemes", "--spec", spec, "--out", out.path_join("visemes.json")], "learning their mouth")
		"learn":
			var shots := shots_of(actor)
			var spec := actor.dir.path_join("learn.spec.json")
			var e := ActorFolder.write_file(spec, JSON.stringify({"videos": videos_spec(), "shots": shots,
				"phones": phones_of(actor, shots), "classes": Visemes.REGISTRY.keys()}))
			if not e.is_empty():
				return e
			return _spawn_py(run, ["learn", "--spec", spec, "--out", out.path_join("mouth_model.json")], "learning their mouth")
		"motion":
			var spec := actor.dir.path_join("motion.spec.json")
			var e := ActorFolder.write_file(spec, JSON.stringify({"videos": videos_spec(), "shots": shots_of(actor),
				"rate": 1.0 / float(actor.settings()["survey_interval"]), "most_minutes": MOTION_MINUTES}))
			if not e.is_empty():
				return e
			return _spawn_py(run, ["motion", "--spec", spec, "--out", out.path_join("motion.json")], "learning their motion")
		"stills":
			var spec := out.path_join("stills.spec.json")
			var e := ActorFolder.write_file(spec, JSON.stringify({"videos": videos_spec(), "shots": shots_of(actor, sid),
				"count": STILLS, "out": out.path_join("stills"), "index": out.path_join("stills.json")}))
			if not e.is_empty():
				return e
			return _spawn_py(run, ["stills", "--ffmpeg", ff, "--face-model", Provision.file_path("face_model"),
				"--pose-model", Provision.file_path("pose_model"), "--spec", spec], "finding their stills")
		"rest":
			return _rest(run, sid, out)
		"rig":
			return _spawn_py(run, ["rig", "--stills", out.path_join("stills.json"), "--out", out.path_join("rig.json")],
				"building the rig")
		"library":
			var spec := out.path_join("library.spec.json")
			var e := ActorFolder.write_file(spec, JSON.stringify({"rig": out.path_join("rig.json"),
				"stills": out.path_join("stills.json"), "visemes": actor.dir.path_join("visemes.json"),
				"videos": videos_spec(), "shots": shots_of(actor), "set": sid,
				"articulation": actor.settings()["articulation"], "variants": VARIANTS, "eye_variants": EYE_VARIANTS,
				"out": out.path_join("library"), "index": out.path_join("library.json")}))
			if not e.is_empty():
				return e
			return _spawn_py(run, ["library", "--ffmpeg", ff, "--face-model", Provision.file_path("face_model"),
				"--pose-model", Provision.file_path("pose_model"), "--spec", spec], "keeping their mouths and eyes")
	return "no such step"


## Start a program of the face environment: actor.py [param args].
func _spawn_py(run: Dictionary, args: Array, said: String) -> String:
	return _spawn(run, "user://face_venv", "res://hosts/face/actor.py", args, said)


## Start [param host] (a script of ghost's) on the Python of the environment at [param venv].
func _spawn(run: Dictionary, venv: String, host_path: String, args: Array, said: String) -> String:
	var py := Deps.venv_bin(venv, "python")
	var host := BundledHosts.path(host_path)
	if host.is_empty() or not FileAccess.file_exists(py):
		return "the %s environment is missing" % venv.get_file().trim_suffix("_venv")
	var tag := "%s_%s" % [run["step"], String(run["scope"]).replace(":", "_")]
	run["log"] = _logs().path_join(tag + ".log")
	run["progress"] = _logs().path_join(tag + ".progress")
	DirAccess.remove_absolute(String(run["progress"]))
	var argv := PackedStringArray(["-I", host])
	for a in args:
		argv.append(str(a))
	argv.append_array(PackedStringArray(["--progress", String(run["progress"])]))
	Provision.hold(venv.get_file(), "actor")
	run["held"] = venv.get_file()
	run["pid"] = Subprocess.start_logged(py, argv, String(run["log"]), "actor " + String(run["step"]))
	run["kind"] = "process"
	run["said"] = said
	return "" if int(run["pid"]) > 0 else "actor.py could not start"


func _spawn_redirected(run: Dictionary, prog: String, args: PackedStringArray, out: String) -> String:
	var err := out + ".err"
	DirAccess.remove_absolute(out)
	run["pid"] = Subprocess.start_redirected(prog, args, {"out": out, "err": err}, "actor " + String(run["step"]))
	run["kind"] = "process"
	return "" if int(run["pid"]) > 0 else "%s could not start" % prog.get_file()


## Has [param run] ended? Lands it when it has.
func _poll(run: Dictionary) -> bool:
	match String(run.get("kind", "")):
		"wait_env":
			if not Provision.ensure(String(run["env"])) and not _tool:
				run["said"] = "updating " + String(Deps.entry(String(run["env"])).get("name", run["env"]))
				return false
			return _after(run, "")
		"process":
			if Subprocess.alive(int(run["pid"])):
				if String(run["lane"]) == "net" and _stalled(run):
					Subprocess.stop(int(run["pid"]))
					return _after(run, _land_process(run))
				return false
			if Subprocess.closing():
				return true
			return _after(run, _land_process(run))
		"agent":
			var id := String(run["job"])
			var st := AgentJobs.state(id)
			if st != "done" and st != "failed":
				run["said"] = AgentJobs.activity(id)
				return false
			var res := AgentJobs.result(id)
			AgentJobs.forget(id)
			run["job"] = ""
			return _after(run, _land_agent(run, res))
	return true


## What landing [param run] said: "" moves it to its next phase, "done" makes it, else it failed.
## True when the run is over.
func _after(run: Dictionary, said: String) -> bool:
	_release(run)
	if said == "wait":
		return false
	if said.is_empty():
		var nxt := _phase(run)
		if nxt.is_empty():
			return false
		said = nxt
	if said == "done":
		return true
	_errors[_key(String(run["step"]), String(run["scope"]))] = said
	push_warning("ghost: actor %s %s - %s" % [run["step"], run["scope"], said])
	return true


func _release(run: Dictionary) -> void:
	if run.has("held"):
		Provision.release(String(run["held"]), "actor")
		run.erase("held")


func _end_run(run: Dictionary) -> void:
	if String(run.get("kind", "")) == "process":
		Subprocess.stop(int(run["pid"]))
	elif String(run.get("kind", "")) == "agent" and not String(run.get("job", "")).is_empty():
		AgentJobs.cancel(String(run["job"]))
		AgentJobs.forget(String(run["job"]))
	_release(run)


## Has [param run]'s log stood still for [constant STALL_S]?
func _stalled(run: Dictionary) -> bool:
	var log := String(run.get("log", ""))
	var f := FileAccess.open(log, FileAccess.READ) if not log.is_empty() else null
	var size := f.get_length() if f != null else 0
	var now := Time.get_ticks_msec()
	if size != int(run.get("log_size", -1)):
		run["log_size"] = size
		run["log_at"] = now
		return false
	return now - int(run.get("log_at", now)) > STALL_S * 1000


## Is [param path] newer than [param run]'s start: made by it?
static func _made_by(path: String, run: Dictionary) -> bool:
	return (FileAccess.file_exists(path) or DirAccess.dir_exists_absolute(path)) \
		and FileAccess.get_modified_time(path) >= int(run["t0"])


## The last thing actor.py said of its step ("survey: 15201 samples ..."), for the row.
static func _said_by(log: String, step: String) -> String:
	var text := FileAccess.get_file_as_string(log)
	var said := ""
	for line in text.split("\n"):
		var at := line.find("actor: %s: " % step)
		if at >= 0:
			said = line.substr(at + 9 + step.length()).strip_edges()
	return said


static func _tail(log: String) -> String:
	var lines := FileAccess.get_file_as_string(log).strip_edges().split("\n")
	for i in range(lines.size() - 1, -1, -1):
		var l := String(lines[i]).strip_edges()
		if not l.is_empty() and not l.begins_with("W0000") and not l.begins_with("I0000"):
			return l.substr(0, 200)
	return "it ended without a word (see %s)" % log.get_file()


# --- the stills at rest ------------------------------------------------------------------------------

## WHICH OF SET [param sid]'S STILLS SHOW THEM AT REST: the writer shown their sheet - or, once its answer
## is kept, made.
func _rest(run: Dictionary, sid: String, out: String) -> String:
	var count := actor.stills_of(sid).size()
	if bool(run["state"].get("landed", false)):
		var d: Variant = ActorFolder.read_json(out.path_join("rest.json"))
		var n := ((d as Dictionary).get("rest", []) as Array).size() if d is Dictionary else 0
		actor.put_stamp("rest", run["scope"], "%d of %d at rest" % [n, count] if n > 0 else "none of %d at rest" % count)
		return "done"
	var sheet := out.path_join("stills").path_join("sheet.jpg")
	if count == 0 or not FileAccess.file_exists(sheet):
		return "the stills have no sheet: Generate makes them again"
	var p := ActorPrompts.rest(actor.name(), count)
	p["images"] = [{"path": sheet, "label": "The stills, numbered:"}]
	run["said"] = "looking for them at rest"
	return _submit(run, p, "at rest " + sid)


## The writer's answer, kept as `rest.json`: `{rest: [still index, ...]}`, most at ease first.
func _land_rest(run: Dictionary, text: String) -> String:
	var d: Variant = TextGen.extract_json(text)
	if not (d is Dictionary):
		return "the answer was not JSON"
	var sid := String(run["scope"]).substr(2)
	var got := ActorPrompts.land_rest(d as Dictionary, actor.stills_of(sid).size())
	if got.has("error"):
		return String(got["error"])
	var e := ActorFolder.write_file(actor.set_dir(sid).path_join("rest.json"), JSON.stringify(got))
	if not e.is_empty():
		return e
	run["state"]["landed"] = true
	return ""


# --- landing a program's step ----------------------------------------------------------------------

func _land_process(run: Dictionary) -> String:
	var step := String(run["step"])
	var scope := String(run["scope"])
	var vid := scope.substr(2) if scope.begins_with("v:") else ""
	var out := actor.scope_dir(scope)
	match step:
		"fetch", "captions":
			return _land_fetch(run, vid, step == "captions")
		"probe":
			var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(String(run["json"])))
			if not (d is Dictionary):
				return "ffprobe could not read the video"
			var info := probe_of(d as Dictionary)
			if float(info["duration"]) <= 0.0:
				return "ffprobe found no video in it"
			# CAPTIONS BESIDE A FOLDER VIDEO (`<name>.en*.json3`) are its own
			var path := actor.video_path(vid)
			var v := actor.video(vid)
			if String(v.get("captions", "")).is_empty():
				var beside := _captions_beside(path)
				if not beside.is_empty():
					v["captions"] = beside
					actor.save()
			info["captions"] = FileAccess.file_exists(String(v.get("captions", "")))
			var e := ActorFolder.write_file(out.path_join("probe.json"), JSON.stringify(info))
			if not e.is_empty():
				return e
			v["duration"] = info["duration"]
			actor.save()
			actor.put_stamp(step, scope, "%s, %d fps" % [Clock.text(float(info["duration"])), roundi(float(info["fps"]))])
			return "done"
		"survey", "shots", "sets", "transcribe", "visemes", "learn", "motion", "stills", "rig", "library":
			if not _made_by(out.path_join(String(MAIN[step])), run):
				return _tail(String(run["log"]))
			var said := _said_by(String(run["log"]), step)
			actor.put_stamp(step, scope, said)
			return "done"
	return "done"


## ffprobe's JSON as `{duration, fps, width, height}`.
static func probe_of(d: Dictionary) -> Dictionary:
	var st: Dictionary = (d.get("streams", [{}]) as Array)[0] if not (d.get("streams", []) as Array).is_empty() else {}
	var fps := _rate(String(st.get("avg_frame_rate", "")))
	if fps <= 0.0:
		fps = _rate(String(st.get("r_frame_rate", "")))
	return {"duration": float((d.get("format", {}) as Dictionary).get("duration", 0.0)), "fps": fps if fps > 0.0 else 30.0,
		"width": int(st.get("width", 0)), "height": int(st.get("height", 0))}


static func _rate(s: String) -> float:
	var p := s.split("/")
	if p.size() == 2 and float(p[1]) != 0.0:
		return float(p[0]) / float(p[1])
	return float(s) if s.is_valid_float() else 0.0


static func _captions_beside(path: String) -> String:
	if path.is_empty():
		return ""
	var stem := path.get_basename().get_file()
	var d := DirAccess.open(path.get_base_dir())
	if d == null:
		return ""
	for f in d.get_files():
		if f.begins_with(stem + ".en") and f.ends_with(".json3"):
			return path.get_base_dir().path_join(f)
	return ""


# --- fetching ---------------------------------------------------------------------------------------

func _yt_python() -> String:
	return Deps.venv_bin("user://ytdlp_venv", "python")


func _deno() -> String:
	return Deps.venv_bin("user://ytdlp_venv", "deno")


## A linked video fetched (or a folder video's captions): yt-dlp, its output in the log.
func _fetch(run: Dictionary, vid: String, captions_only: bool) -> String:
	var v := actor.video(vid)
	var url := String(v.get("captions_url" if captions_only else "url", ""))
	if url.is_empty():
		return "done"
	DirAccess.make_dir_recursive_absolute(actor.footage_dir())
	run["log"] = _logs().path_join("%s_%s.log" % [run["step"], vid])
	run["kind"] = "process"
	Provision.hold("ytdlp_venv", "actor")
	run["held"] = "ytdlp_venv"
	run["pid"] = Subprocess.start_logged(_yt_python(), ActorSources.fetch_args(url, actor.footage_dir(), captions_only, _deno()),
		String(run["log"]), "actor fetch")
	run["said"] = "fetching captions" if captions_only else "downloading"
	return "" if int(run["pid"]) > 0 else "yt-dlp could not start"


func _land_fetch(run: Dictionary, vid: String, captions_only: bool) -> String:
	var v := actor.video(vid)
	var entry := String(v.get("captions_id" if captions_only else "entry", ""))
	var got := ActorSources.fetched(actor.footage_dir(), entry)
	# A VIDEO WITH NO CAPTIONS ON THE SITE IS NOT A FAILED FETCH: its details came, and its words are
	# none - a step waiting on them would stop the set for good
	var ok := not String(got["info"]).is_empty() if captions_only else not String(got["video"]).is_empty()
	if not ok:
		# YouTube breaking an old yt-dlp is the usual failure: update it once, and go again
		if int(run["tries"]) == 0:
			run["tries"] = 1
			Provision.update("ytdlp_venv")
			run["kind"] = "wait_env"
			run["env"] = "ytdlp_venv"
			return "wait"
		return "the download failed: %s" % _tail(String(run["log"]))
	if not captions_only:
		v["path"] = String(got["video"])
	if not String(got["captions"]).is_empty():
		v["captions"] = String(got["captions"])
	var info: Variant = ActorFolder.read_json(String(got["info"]))
	if info is Dictionary and not captions_only:
		v["title"] = String((info as Dictionary).get("title", v.get("title", "")))
	actor.save()
	actor.put_stamp(String(run["step"]), String(run["scope"]),
		"with captions" if not String(got["captions"]).is_empty() else "no captions on the site")
	return "done"


## LIST A LINK: its entries come back as JSON (a video, a playlist, a channel), and land as rows.
func list_link(source: int) -> String:
	if _listings.has(source):
		return ""
	if not Provision.ensure("ytdlp_venv") and not (_tool and FileAccess.file_exists(_yt_python())):
		return "waiting for the download environment to install"
	var s: Dictionary = actor.data["sources"][source]
	var out := _logs().path_join("list_%d.json" % source)
	var err := out + ".err"
	DirAccess.remove_absolute(out)
	var pid := Subprocess.start_redirected(_yt_python(), ActorSources.list_args(String(s["url"]), _deno()),
		{"out": out, "err": err}, "actor list")
	if pid <= 0:
		return "yt-dlp could not start"
	_listings[source] = {"pid": pid, "out": out, "err": err}
	changed.emit()
	return ""


## Is a listing under way for [param source]?
func listing(source: int) -> bool:
	return _listings.has(source)


func _poll_listing(source: int) -> bool:
	var l: Dictionary = _listings[source]
	if Subprocess.alive(int(l["pid"])):
		return false
	_listings.erase(source)
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(String(l["out"])))
	var s: Dictionary = actor.data["sources"][source]
	if not (d is Dictionary):
		s["error"] = _tail(String(l["err"]))
		actor.save()
		return true
	var got := ActorSources.land_listing(actor, source, ActorSources.entries_of(d))
	s.erase("error")
	s["title"] = String((d as Dictionary).get("title", ""))
	s["landed"] = got
	actor.save()
	return true


# --- words, from captions ----------------------------------------------------------------------------

## A VIDEO'S WORDS: its captions', or, where it has none, what Transcribe heard.
func _make_words(vid: String) -> String:
	var cap := String(actor.video(vid).get("captions", ""))
	var words: Array = []
	var from := "captions"
	if FileAccess.file_exists(cap):
		words = ActorSources.words_of_json3(FileAccess.get_file_as_string(cap))
	else:
		from = "heard"
		var t: Variant = ActorFolder.read_json(actor.video_dir(vid).path_join("transcript.json"))
		for w in ((t as Dictionary).get("words", []) if t is Dictionary else []):
			words.append({"text": String(w["text"]), "t0": float(w["t0"]), "t1": float(w["t1"])})
	var e := ActorFolder.write_file(actor.video_dir(vid).path_join("words.json"), JSON.stringify({"vid": vid, "words": words}))
	if not e.is_empty():
		return e
	actor.put_stamp("words", "v:" + vid, ("%d words, %s" % [words.size(), from]) if not words.is_empty() else "no words")
	return "done"


# --- the audit ---------------------------------------------------------------------------------------

func _audit_parts() -> String:
	return actor.dir.path_join("audit.parts")


## The next set to audit, or the audit made from every set's answer.
func _audit_next(run: Dictionary) -> String:
	var st: Variant = ActorFolder.read_json(actor.dir.path_join("sets.json"))
	var all: Array = (st as Dictionary).get("sets", []) if st is Dictionary else []
	DirAccess.make_dir_recursive_absolute(_audit_parts())
	var todo: Array = []
	for s in all:
		var d: Dictionary = s
		if float(d.get("usable", 0.0)) >= AUDIT_LEAST and not FileAccess.file_exists(_audit_parts().path_join(String(d["id"]) + ".json")):
			todo.append(d)
	var count := 0
	for s in all:
		if float((s as Dictionary).get("usable", 0.0)) >= AUDIT_LEAST:
			count += 1
	if todo.is_empty():
		return _land_audit(all)
	var set_d: Dictionary = todo[0]
	run["state"]["set"] = set_d
	run["share"] = float(count - todo.size()) / float(maxi(1, count))
	var images: Array = [{"path": String(set_d.get("sheet", "")), "label": "THE SET - 16 frames across all of it:"}]
	for p in (set_d.get("shot_sheets", []) as Array).slice(0, AUDIT_SHEETS - 1):
		images.append({"path": String(p), "label": "Its shots, one frame from the middle of each, numbered:"})
	var p := ActorPrompts.audit(actor.name(), set_d, (set_d.get("shot_sheets", []) as Array).size() > AUDIT_SHEETS - 1)
	p["images"] = images
	run["said"] = "auditing set %d of %d" % [count - todo.size() + 1, count]
	return _submit(run, p, "audit " + String(set_d["id"]))


func _submit(run: Dictionary, p: Dictionary, label: String) -> String:
	var dir := actor.dir.path_join("jobs").path_join(String(run["step"])).path_join(
		str(Time.get_unix_time_from_system()).replace(".", "_"))
	var id := AgentJobs.submit({"kind": "text", "backend": String(writer["agent"]), "tier": "best", "dir": dir,
		"system": String(p.get("system", "")), "prompt": String(p.get("prompt", "")), "images": p.get("images", []),
		"label": "likeness " + label, "model": String(writer["model"]), "effort": String(writer["effort"])})
	if id.is_empty():
		return "this session cannot start agents (read-only)"
	run["job"] = id
	run["kind"] = "agent"
	return ""


func _land_agent(run: Dictionary, res: Dictionary) -> String:
	var step := String(run["step"])
	if not bool(res.get("ok", false)):
		return "the writer stopped: %s" % String(res.get("error", "its run failed"))
	var text := String(res.get("text", ""))
	var err := ""
	match step:
		"audit":
			err = _land_audit_part(run["state"]["set"], text)
		"rest":
			err = _land_rest(run, text)
	if err.is_empty():
		run["tries"] = 0
		return ""
	if int(run["tries"]) < RETRIES:
		run["tries"] = int(run["tries"]) + 1
		push_warning("ghost: actor %s - %s; asking again" % [step, err])
		return ""
	return err


## One set's answer, kept: `{look, unusable: [{shot, why}], other: {shots, look}}`.
func _land_audit_part(set_d: Dictionary, text: String) -> String:
	var d: Variant = TextGen.extract_json(text)
	if not (d is Dictionary):
		return "the audit's answer was not JSON"
	var got := ActorPrompts.land_audit(d as Dictionary, (set_d.get("shots", []) as Array).size())
	if got.has("error"):
		return String(got["error"])
	return ActorFolder.write_file(_audit_parts().path_join(String(set_d["id"]) + ".json"), JSON.stringify(got))


## THE AUDIT, whole: every set with its look, a set split where shots of another look were found,
## the unusable shots out of its usable minutes.
func _land_audit(all: Array) -> String:
	var sets: Array = []
	for s in all:
		var d: Dictionary = (s as Dictionary).duplicate(true)
		var part: Variant = ActorFolder.read_json(_audit_parts().path_join(String(d["id"]) + ".json"))
		if not (part is Dictionary):
			d["look"] = ""
			d["audited"] = false
			sets.append(d)
			continue
		sets.append_array(ActorPrompts.apply_audit(d, part as Dictionary))
	sets.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["usable"]) > float(b["usable"]))
	var e := ActorFolder.write_file(actor.dir.path_join("audit.json"), JSON.stringify({"sets": sets}, "\t"))
	if not e.is_empty():
		return e
	var looked := sets.filter(func(x: Dictionary) -> bool: return bool(x.get("audited", false))).size()
	actor.put_stamp("audit", "", "%d set%s, %d looked at" % [sets.size(), "" if sets.size() == 1 else "s", looked])
	return "done"


# --- what is made from what ------------------------------------------------------------------------

## EVERY TICKED VIDEO'S FILE, SURVEY AND SIZE, as actor.py reads them: `{vid: {path, survey, size}}`.
func videos_spec() -> Dictionary:
	var out := {}
	for v in actor.ticked():
		var vid := String(v)
		var path := actor.video_path(vid)
		if path.is_empty():
			continue
		var pr: Variant = ActorFolder.read_json(actor.video_dir(vid).path_join("probe.json"))
		var w := int((pr as Dictionary).get("width", 1920)) if pr is Dictionary else 1920
		var h := int((pr as Dictionary).get("height", 1080)) if pr is Dictionary else 1080
		out[vid] = {"path": path, "survey": actor.video_dir(vid).path_join("survey.bin"), "size": [w, h]}
	return out


## THE USABLE SHOTS of set [param sid], or with none of every steady set (a handheld one moves with
## the camera, not with them): `[{vid, start, end, set}]`, of ticked videos only.
static func shots_of(a: ActorFolder, sid := "") -> Array:
	var ticked := a.ticked()
	var out: Array = []
	for s in a.sets():
		var d: Dictionary = s
		if (not sid.is_empty() and String(d.get("id", "")) != sid) or (sid.is_empty() and bool(d.get("handheld", false))):
			continue
		for sh in d.get("shots", []):
			var x: Dictionary = sh
			if bool(x.get("unusable", false)) or not ticked.has(String(x.get("vid", ""))):
				continue
			out.append({"vid": String(x["vid"]), "start": float(x["start"]), "end": float(x["end"]), "set": String(d["id"])})
	return out


## THE PHONES THEY SAID in [param shots], from their videos' caption words: each word's sounds
## ([Phonemes]), its time shared among them by how long each kind of sound usually lasts.
## `[{vid, p, t0, t1, class}]`.
static func phones_of(a: ActorFolder, shots: Array) -> Array:
	var spans := {}
	for s in shots:
		var d: Dictionary = s
		(spans.get_or_add(String(d["vid"]), []) as Array).append([float(d["start"]), float(d["end"])])
	var out: Array = []
	for vid in spans:
		var w: Variant = ActorFolder.read_json(a.video_dir(String(vid)).path_join("words.json"))
		if not (w is Dictionary):
			continue
		for word in (w as Dictionary).get("words", []):
			var t0 := float(word["t0"])
			var t1 := float(word["t1"])
			var inside := false
			for sp in spans[vid]:
				if t0 >= float(sp[0]) and t1 <= float(sp[1]):
					inside = true
					break
			if not inside:
				continue
			var bare := String(word["text"]).to_lower().strip_edges().lstrip("\"'([").rstrip(".,!?;:\"')]")
			if bare.is_empty():
				continue
			var ph := Phonemes.word_to_phones(bare)
			if ph.is_empty():
				continue
			var weights := PackedFloat32Array()
			var sum := 0.0
			for p in ph:
				var c := Visemes.class_of(String(p))
				var wt := 1.5 if ["open", "mid", "spread", "round"].has(c) else (0.7 if ["tdnl", "kg", "pbm"].has(c) else 1.0)
				weights.append(wt)
				sum += wt
			var at := t0
			for i in ph.size():
				var dur := (t1 - t0) * weights[i] / maxf(sum, 1e-6)
				out.append({"vid": vid, "p": String(ph[i]), "t0": snappedf(at, 0.001), "t1": snappedf(at + dur, 0.001),
					"class": Visemes.class_of(String(ph[i]))})
				at += dur
	return out
