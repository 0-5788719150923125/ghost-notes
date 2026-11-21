extends RefCounted
class_name RiggerTools

## RiggerTools - the rigger's tools (next/cartoon.md, rules/cartoon/rigger.yaml): a drawing cut off its paper, its skeleton, jaw, eyes and
## parts built into a puppet, each answered with the picture the puppet host draws of it, and the puppet handed in. Served over ghost's
## MCP server ([AgentTools]) to a writer that takes tools.
##
## The host is `hosts/puppet/rig.py` on its own environment ([constant VENV]): `cut` and `build`, a spec in JSON each, the rig written
## straight into the puppet's folder on the library's `puppets` shelf ([method PuppetRig.folder_of]), so what is handed in is what a show
## plays. A tool waits for its run, frame by frame; nothing heavy is on the app's thread.

const VENV := "user://puppet_venv"
const HOST := "res://hosts/puppet/rig.py"
## The longest one host run may take (s).
const RUN_MOST := 180.0
## The Python the host runs on where one is named (a command-line run with the environment elsewhere); its environment's otherwise.
static var python := ""

## Where the puppet is made, and the drawing it is made from.
var folder := ""
var source := ""
## The folder of the drawing this one is set onto ([method PuppetSheet.REGISTRY] `from`), "" for none: a cut is aligned to it again.
var base := ""
var submitted := false
## How many pictures it may look at.
var looks := 16

var _looked := 0
var _cut := false
var _built := false
var _busy := false
var _released := false


func _init(puppet_folder: String, drawing: String, most_looks := 16) -> void:
	folder = puppet_folder
	source = drawing
	looks = most_looks
	DirAccess.make_dir_recursive_absolute(folder)


## Its tools let go (the job ended): a call still waiting answers that they are closed.
func release() -> void:
	_released = true


func instructions() -> String:
	return "Tools for making a drawing a puppet: cut it off its paper, build its skeleton, see both, and hand the puppet in."


func list_tools() -> Array:
	return [
		{"name": "cut", "description": "Cut the drawing off its paper. `holes`: ids of the enclosed white regions to cut away as gaps (every one to cut); `keep`: ids to keep that would otherwise be cut; `erase`: outlines [[x, y], ...] to take out, or {outline, color, tolerance} to take only that color inside one. Answers with the regions and a picture of the cut on a grid.",
			"inputSchema": {"type": "object", "properties": {
				"holes": {"type": "array", "items": {"type": "integer"}},
				"keep": {"type": "array", "items": {"type": "integer"}},
				"erase": {"type": "array", "items": {}}}}},
		{"name": "rig", "description": "Build the puppet: `bones` [{name, parent, head, tail, role, side}], and any of `jaw` {outline, hinge, open, drop, cavity}, `eyes` [{name, center, radius}], `behind` [{name, color, tolerance, bone}], `parts` [{name, outline, bone}], `faces`, `ground`, `poses`, `about`. Answers with what it built (or what is wrong with what you wrote) and three pictures in one: the skeleton on the grid, what each bone moves, and the puppet bent.",
			"inputSchema": {"type": "object", "properties": {
				"bones": {"type": "array", "items": {"type": "object"}},
				"jaw": {"type": "object"}, "eyes": {"type": "array", "items": {"type": "object"}},
				"behind": {"type": "array", "items": {"type": "object"}}, "parts": {"type": "array", "items": {"type": "object"}},
				"faces": {"type": "string"}, "ground": {"type": "number"}, "poses": {"type": "object"}, "about": {"type": "string"}},
				"required": ["bones"]}},
		{"name": "submit", "description": "Hand the puppet in as it was last built. Answers with what keeps it from being handed in, if anything; otherwise the puppet is done, and so is your work.",
			"inputSchema": {"type": "object", "properties": {}}},
	]


func call_tool(name: String, args: Dictionary) -> Dictionary:
	var tree := Engine.get_main_loop() as SceneTree
	while _busy and not _released:
		await tree.process_frame
	if _released:
		return {"text": "The puppet has been handed in and its tools are closed.", "error": true}
	_busy = true
	var out: Dictionary = {}
	match name:
		"cut":
			var spec := {"src": source, "dir": folder}
			for k in ["holes", "keep", "erase"]:
				if args.has(k):
					spec[k] = args[k]
			out = await _run("cut", spec, "cut_look.png")
			_cut = _cut or not bool(out.get("error", false))
			if _cut and not base.is_empty():
				DirAccess.remove_absolute(folder.path_join("cut_raw.png"))
				await RiggerTools.host("align", {"dir": folder, "base": base}, folder.path_join("job"))
		"rig":
			if not _cut and not FileAccess.file_exists(folder.path_join("cut.png")):
				out = {"text": "Cut the drawing off its paper first (`cut`).", "error": true}
			else:
				var spec := args.duplicate(true)
				spec["dir"] = folder
				out = await _run("build", spec, "look.png")
				_built = not bool(out.get("error", false))
		"submit":
			if not _built or not FileAccess.file_exists(folder.path_join(PuppetRig.FILE)):
				out = {"text": "There is no puppet built yet: `rig` it, look, and hand it in when it moves as it should.", "error": true}
			else:
				submitted = true
				out = {"text": "Handed in. The puppet is done."}
		_:
			out = {"text": "There is no tool called %s." % name, "error": true}
	_busy = false
	return out


## The host's [param step] run on [param spec], waited for: its answer as words, and the picture [param look] it drew where looks are
## left.
func _run(step: String, spec: Dictionary, look: String) -> Dictionary:
	var got := await RiggerTools.host(step, spec, folder.path_join("job"))
	if not bool(got.get("ok", false)):
		return {"text": "That did not build: %s" % String(got.get("error", "the host stopped")), "error": true}
	var said := got.duplicate()
	said.erase("ok")
	said.erase("trace")
	var text := JSON.stringify(said)
	var images: Array = []
	if _looked < looks:
		var img := Image.load_from_file(folder.path_join(look))
		if img != null:
			_looked += 1
			images.append(img)
			text += "\n(%d of %d looks used)" % [_looked, looks]
	else:
		text += "\n(no looks left: hand the puppet in)"
	return {"text": text, "images": images}


## The puppet host's [param step] (cut, build) run on [param spec] (JSON, written in [param dir]), waited for frame by frame: what it
## answered (`done.json`: `{ok, ...}` or `{ok: false, error}`).
static func host(step: String, spec: Dictionary, dir: String) -> Dictionary:
	DirAccess.make_dir_recursive_absolute(dir)
	if python.is_empty() and not Provision.ensure("puppet_venv"):
		return {"ok": false, "error": "the puppet environment is being installed (%s); try again in a minute" % String(Deps.entry("puppet_venv").get("size", ""))}
	var py := python if not python.is_empty() else Deps.venv_bin(VENV, "python")
	var script := BundledHosts.path(HOST)
	if not FileAccess.file_exists(py) or script.is_empty():
		return {"ok": false, "error": "the puppet environment is not installed"}
	var spec_path := dir.path_join("%s_spec.json" % step)
	var f := FileAccess.open(spec_path, FileAccess.WRITE)
	if f == null:
		return {"ok": false, "error": "could not write the spec in %s" % dir}
	f.store_string(JSON.stringify(spec))
	f.close()
	var done := String(spec.get("dir", dir)).path_join("done.json")
	if FileAccess.file_exists(done):
		DirAccess.remove_absolute(done)
	var pid := Subprocess.start_logged(py, PackedStringArray(["-I", script, step, spec_path]), dir.path_join("%s.log" % step), "puppet " + step)
	if pid <= 0:
		return {"ok": false, "error": "could not start the puppet host"}
	var tree := Engine.get_main_loop() as SceneTree
	var t0 := Time.get_ticks_msec()
	while Subprocess.alive(pid):
		if Time.get_ticks_msec() - t0 > int(RUN_MOST * 1000.0):
			Subprocess.stop(pid)
			return {"ok": false, "error": "the puppet host took longer than %d seconds" % int(RUN_MOST)}
		await tree.process_frame
	var got: Variant = JSON.parse_string(FileAccess.get_file_as_string(done)) if FileAccess.file_exists(done) else null
	return got if got is Dictionary else {"ok": false, "error": "the puppet host left no answer (%s)" % dir.path_join("%s.log" % step)}
