extends RefCounted
class_name LetterSketches

## LetterSketches - a letter's sketches, made: each `<!-- sketch: ... -->` drawn as SVG by an agent from
## its words ([constant RULES]), then laid out by ghost's own TeX and figure reader
## (hosts/math/typeset.py, the Proof pad's ink step) into what the pen draws ([LetterMedium]).
##
## KEPT IN THE NOTE'S OWN FOLDER (`user://letters/<note>-<hash>/`, as [NoteUpload] keeps a note's): a
## sketch is `sketches/<key>.json` - its SVG, the words it was drawn from and the fingerprint of what
## it was asked (its description and the parts the letter points at) - and the ink is `ink.json`, TeX's
## answer, with the fingerprint of the drawings it laid out. A sketch whose words changed is STALE, and
## used as it is until it is drawn again; the ink is laid out again whenever the drawings are not the
## ones it was made from.
##
## A DRAWING IS CHECKED AS IT LANDS: an answer with no `<svg>` in it, or one missing an id a point needs,
## is sent back once with what it lacks; one the ink step cannot read is sent back once with why, and then
## stands as it is - the pen leaves a drawing TeX refused out, and the letter plays without it.
##
## NOTHING RUNS ON ITS OWN: [method generate] and [method redo] are the card's buttons.

const RULES := "letter/sketcher"
## The drawing's width (figure.py's column, which spans the pad's) and its tallest height, in its units.
const WIDTH := 360
const MOST := 260
## A drawing sent back is tried this many more times.
const RETRIES := 1
## The ink step's column, in TeX points (figure.py's COLUMN_PT).
const PAD_WIDTH := 270.0

## Where the notes' folders are: moved aside by a gate.
static var root := "user://letters"

var dir := ""
## Who draws: `{agent, model, effort}` ([AgentPick]'s choice).
var writer := {"agent": "claude", "model": "", "effort": ""}

var _jobs := {}              # a sketch's key -> {id, sketch, tries, missing, refused}
var _errors := {}            # a sketch's key -> why it is not drawn, once out of tries
var _ink := {}               # {pid, out, log, from} while the ink step runs
var _ink_error := ""
var _kept := {}              # file -> {mt, data}


## THE NOTE'S FOLDER, absolute, for the note at [param note]: named after its file and told apart from
## another of that name by its path ([method NoteUpload.folder_of]'s rule). "" for a note with no file.
static func folder_of(note: String) -> String:
	if note.is_empty():
		return ""
	var abs := ProjectSettings.globalize_path(note)
	var base := abs.get_file().get_basename().strip_edges().to_lower().replace(" ", "-").validate_filename()
	return ProjectSettings.globalize_path(root.path_join("%s-%s" % [base, abs.md5_text().substr(0, 8)]))


func _init(note := "") -> void:
	dir = folder_of(note)


## What a sketch is asked from: its description and the parts the letter points at.
static func fingerprint(sketch: Dictionary) -> String:
	return JSON.stringify([String(sketch.get("prompt", "")).strip_edges(), sketch.get("parts", [])]).sha256_text().substr(0, 16)


func _file(key: String) -> String:
	return dir.path_join("sketches").path_join(key + ".json") if not dir.is_empty() else ""


## What is kept for the sketch [param key], {} for nothing.
func made(key: String) -> Dictionary:
	return _read(_file(key))


func _read(path: String) -> Dictionary:
	if path.is_empty() or not FileAccess.file_exists(path):
		return {}
	var mt := FileAccess.get_modified_time(path)
	var c: Dictionary = _kept.get(path, {})
	if c.is_empty() or int(c["mt"]) != mt:
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		c = {"mt": mt, "data": d if d is Dictionary else {}}
		_kept[path] = c
	return c["data"]


## "ready", "stale" (drawn from words since changed - still used), "running", "queued", "failed" or
## "missing", for [param sketch] (a [method LetterScript.sketches] row).
func state(sketch: Dictionary) -> String:
	var key := String(sketch["key"])
	if _jobs.has(key):
		return "running" if AgentJobs.state(String((_jobs[key] as Dictionary)["id"])) == "running" else "queued"
	if _errors.has(key):
		return "failed"
	var m := made(key)
	if m.is_empty():
		return "missing"
	return "ready" if String(m.get("from", "")) == fingerprint(sketch) else "stale"


## Why [param key] is not drawn, or what its agent is doing.
func said(sketch: Dictionary) -> String:
	var key := String(sketch["key"])
	if _jobs.has(key):
		return "drawer " + AgentJobs.activity(String((_jobs[key] as Dictionary)["id"]))
	return String(_errors.get(key, ""))


## Every drawing made for [param sketches]: key -> SVG.
func svgs(sketches: Array) -> Dictionary:
	var out := {}
	for s in sketches:
		var m := made(String((s as Dictionary)["key"]))
		if not String(m.get("svg", "")).is_empty():
			out[String(s["key"])] = String(m["svg"])
	return out


func busy() -> bool:
	return not _jobs.is_empty() or not _ink.is_empty()


## GENERATE: each of [param sketches] not drawn, failed or stale is drawn (the card lays them out once
## they are).
func generate(sketches: Array) -> void:
	for s in sketches:
		var st := state(s)
		if st in ["missing", "stale", "failed"]:
			_errors.erase(String(s["key"]))
			_start(s, 1, PackedStringArray(), "")


## ⟳: [param sketch] drawn again now - told [param refused], why the ink step could not read the last one,
## when it could not; what was drawn stays until the new one lands.
func redo(sketch: Dictionary, refused := "") -> void:
	_stop_job(String(sketch["key"]))
	_errors.erase(String(sketch["key"]))
	_start(sketch, 1, PackedStringArray(), refused)


## STOP: every drawing under way and the ink step; what was made stays.
func stop() -> void:
	for key in _jobs.keys():
		_stop_job(String(key))
	if not _ink.is_empty():
		Subprocess.stop(int(_ink["pid"]))
		_ink = {}


func _stop_job(key: String) -> void:
	if not _jobs.has(key):
		return
	var id := String((_jobs[key] as Dictionary)["id"])
	AgentJobs.cancel(id)
	AgentJobs.forget(id)
	_jobs.erase(key)


func _start(sketch: Dictionary, tries: int, missing: PackedStringArray, refused: String) -> void:
	var key := String(sketch["key"])
	if dir.is_empty():
		_errors[key] = "the letter has no file to keep its sketches beside"
		return
	var p := prompt(sketch, missing, refused)
	var id := AgentJobs.submit({"kind": "text", "backend": String(writer.get("agent", "claude")), "tier": "best",
		"dir": dir.path_join("jobs").path_join("sketch-" + key), "system": String(p["system"]),
		"prompt": String(p["prompt"]), "label": "letter sketch %s" % key.substr(0, 6),
		"model": String(writer.get("model", "")), "effort": String(writer.get("effort", ""))})
	if id.is_empty():
		_errors[key] = "this session cannot start agents (read-only)"
		return
	_jobs[key] = {"id": id, "sketch": sketch.duplicate(true), "tries": tries}


## WHAT THE DRAWER IS TOLD for [param sketch]: `{system, prompt}`, with what its last drawing lacked
## ([param missing] ids) or why it could not be read ([param refused]).
static func prompt(sketch: Dictionary, missing := PackedStringArray(), refused := "") -> Dictionary:
	var parts := PackedStringArray()
	for p in sketch.get("parts", []):
		parts.append("id=\"%s\"" % String(p))
	var vars := {"description": String(sketch.get("prompt", "")), "said": String(sketch.get("said", "")),
		"parts": "\n".join(parts), "width": str(WIDTH), "most": str(MOST),
		"missing": ", ".join(missing), "refused": refused}
	return {"system": Rules.say(RULES + ".system", vars), "prompt": Rules.say(RULES + ".prompt", vars)}


## THE SVG IN AN ANSWER: from its `<svg` to its `</svg>`, fences and words round it left out - "" for
## none.
static func svg_of(text: String) -> String:
	var a := text.find("<svg")
	var b := text.rfind("</svg>")
	if a < 0 or b < a:
		return ""
	return text.substr(a, b + 6 - a).strip_edges()


## The ids [param svg] lacks of [param parts].
static func lacking(svg: String, parts: Array) -> PackedStringArray:
	var out := PackedStringArray()
	for p in parts:
		if not RegEx.create_from_string("\\bid\\s*=\\s*[\"']%s[\"']" % String(p)).search(svg):
			out.append(String(p))
	return out


## Land what ended, each refresh: a drawing kept, sent back once, or stopped on with why; the ink
## step's answer kept.
func tick() -> void:
	for key in _jobs.keys():
		var job: Dictionary = _jobs[key]
		var id := String(job["id"])
		var st := AgentJobs.state(id)
		if st == "queued" or st == "running":
			continue
		var res := AgentJobs.result(id)
		AgentJobs.forget(id)
		_jobs.erase(key)
		var sketch: Dictionary = job["sketch"]
		if st != "done":
			_fail(String(key), String(res.get("error", "the job was lost" if st.is_empty() else "the job failed")),
				sketch, int(job["tries"]))
			continue
		var svg := svg_of(String(res.get("text", "")))
		if svg.is_empty():
			_fail(String(key), "the drawer handed back no SVG", sketch, int(job["tries"]), PackedStringArray(),
				"there was no <svg> element in the answer")
			continue
		var lacks := lacking(svg, sketch.get("parts", []))
		if not lacks.is_empty() and int(job["tries"]) <= RETRIES:
			_start(sketch, int(job["tries"]) + 1, lacks, "")
			continue
		var err := _write(_file(String(key)), {"svg": svg, "prompt": String(sketch["prompt"]),
			"parts": sketch.get("parts", []), "from": fingerprint(sketch)})
		if not err.is_empty():
			_errors[key] = err
	_tick_ink()


func _fail(key: String, err: String, sketch: Dictionary, tries: int, missing := PackedStringArray(),
		refused := "") -> void:
	push_warning("ghost: letter sketch %s - %s" % [key, err])
	if tries <= RETRIES:
		_start(sketch, tries + 1, missing, refused)
	else:
		_errors[key] = err


# --- the ink ----------------------------------------------------------------------------------

## The ink step's answer, as kept ({} for none).
func ink() -> Dictionary:
	return _read(dir.path_join("ink.json")) if not dir.is_empty() else {}


## The drawings [param items] ([method LetterScript.items]) as the ink's fingerprint.
static func ink_from(items: Array) -> String:
	var ids := PackedStringArray()
	for it in items:
		ids.append(String((it as Dictionary)["id"]))
	return ",".join(ids).sha256_text().substr(0, 16)


## "ready", "running", "failed", "stale" (laid out for other drawings) or "missing" - "ready" too for
## a letter with no drawings to lay out.
func ink_state(items: Array) -> String:
	if not _ink.is_empty():
		return "running"
	if not _ink_error.is_empty():
		return "failed"
	if items.is_empty():
		return "ready"
	var k := ink()
	if k.is_empty():
		return "missing"
	return "ready" if String(k.get("from", "")) == ink_from(items) else "stale"


func ink_error() -> String:
	return _ink_error


## WHAT THE INK STEP RUNS ON THAT IS NOT INSTALLED YET - asked to be installed (as the Proof producer asks,
## [method Provision.ensure]) and named - or "".
static func lacks() -> String:
	var names := PackedStringArray()
	for k in ["tex", "math_venv"]:
		if not Provision.ensure(String(k)):
			names.append(String(Deps.entry(String(k)).get("name", k)))
	return "" if names.is_empty() else "installing %s" % " and ".join(names)


## THE INK STEP for [param items]: every drawing laid out by ghost's own TeX (hosts/math/typeset.py).
## "" started, else why not.
func start_ink(items: Array) -> String:
	_ink_error = ""
	if items.is_empty() or not _ink.is_empty():
		return ""
	var py := Deps.venv_bin("user://math_venv", "python")
	var host := BundledHosts.path("res://hosts/math/typeset.py")
	var latex := Provision.tool_path("tex", "latex")
	if host.is_empty() or latex.is_empty() or not FileAccess.file_exists(py):
		_ink_error = "TeX or the math environment is missing"
		return _ink_error
	DirAccess.make_dir_recursive_absolute(dir)
	var answer := dir.path_join("ink.answer.json")
	var spec_path := dir.path_join("ink.spec.json")
	var log := dir.path_join("ink.log")
	DirAccess.remove_absolute(answer)
	var err := TextGen.put(spec_path, JSON.stringify({"items": items, "out": answer,
		"work": dir.path_join("ink_work"), "width": PAD_WIDTH, "outlines": true,
		"bin": latex.get_base_dir(), "data": {}}))
	if not err.is_empty():
		_ink_error = err
		return err
	var pid := Subprocess.start_logged(py, PackedStringArray(["-I", host, spec_path]), log, "letter ink")
	if pid <= 0:
		_ink_error = "TeX's layout could not start"
		return _ink_error
	_ink = {"pid": pid, "out": answer, "log": log, "from": ink_from(items)}
	return ""


func _tick_ink() -> void:
	if _ink.is_empty() or Subprocess.alive(int(_ink["pid"])):
		return
	var job := _ink
	_ink = {}
	var answer: Variant = JSON.parse_string(FileAccess.get_file_as_string(String(job["out"]))) \
		if FileAccess.file_exists(String(job["out"])) else null
	DirAccess.remove_absolute(String(job["out"]))
	if not (answer is Dictionary):
		_ink_error = "TeX's layout failed: " + FileAccess.get_file_as_string(String(job["log"])).strip_edges().right(300)
		return
	for r in (answer as Dictionary).get("items", []):
		if r is Dictionary and not bool((r as Dictionary).get("ok", false)):
			push_warning("ghost: letter ink - a drawing could not be laid out: %s" % String(r.get("error", "")))
	var d: Dictionary = answer
	d["from"] = String(job["from"])
	_ink_error = _write(dir.path_join("ink.json"), d)


## THE DRAWINGS THE INK STEP REFUSED: each one's id -> why, from the kept answer.
func refused() -> Dictionary:
	var out := {}
	for r in ink().get("items", []):
		if r is Dictionary and not bool((r as Dictionary).get("ok", false)):
			out[String((r as Dictionary)["id"])] = String(r.get("error", ""))
	return out


## Written ATOMICALLY: a file that is there is a step that is done.
func _write(path: String, d: Dictionary) -> String:
	if path.is_empty():
		return "the letter has no folder"
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var tmp := path + ".part"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return "could not write " + path
	f.store_string(JSON.stringify(d, "\t"))
	f.close()
	if DirAccess.rename_absolute(tmp, path) != OK:
		return "could not move %s into place" % path
	_kept.erase(path)
	return ""
