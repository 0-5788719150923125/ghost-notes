extends Node
class_name AutoDocs

## AutoDocs - `docs.py` run at every development launch, so `docs/`, the README's lists and the roadmap's
## order follow the code without anyone running it by hand. It runs in the background and writes only the
## files whose text changed (the same output `python docs.py --check` holds); what it says lands in the app's
## log as `[docs.py] ...`, its warnings (drift a person must resolve) as errors.
##
## Only in development: where Godot's `editor` feature is (an exported build has no docs.py), in a window (a
## headless run is automation), and never in a read-only process (a render, an export, a probe), so a gate
## never rewrites the tree. The interpreter is Ghost Notes' own ([method Provision.python_exe]); until uv has
## installed it, a `python3` on the machine stands in. docs.py is stdlib only.

const SCRIPT := "res://docs.py"


func _ready() -> void:
	var why := skip_reason()
	if why.is_empty():
		var py := python()
		if py.is_empty():
			print("ghost docs: not regenerated - no Python yet")
		elif Subprocess.start(py, PackedStringArray(["-I", ProjectSettings.globalize_path(SCRIPT)]), "docs.py") <= 0:
			print("ghost docs: could not start docs.py")
	queue_free()


## Why this process leaves the docs alone ("" when it regenerates them).
func skip_reason() -> String:
	if not OS.has_feature("editor"):
		return "not a development build"
	if DisplayServer.get_name() == "headless":
		return "headless"
	# by its node, not its name: a `--script` run compiles this before the autoloads exist
	var st: Node = get_tree().root.get_node_or_null("Settings") if is_inside_tree() else null
	if st == null or bool(st.is_read_only()):
		return "a read-only process"
	if not FileAccess.file_exists(SCRIPT):
		return "no docs.py in this checkout"
	return ""


## The interpreter docs.py runs on: Ghost Notes' own, else the machine's `python3`; "" when neither is here.
static func python() -> String:
	var own := Provision.python_exe()
	return own if not own.is_empty() else Deps.resolve("python3")
