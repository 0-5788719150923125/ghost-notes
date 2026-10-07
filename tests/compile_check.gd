extends SceneTree

## compile_check - that every GDScript in the project COMPILES, the analyzer's checks included.
##
##   godot --headless --path . --script tests/compile_check.gd
##
## `godot --editor --quit` (scripts/check.sh's `parse`) registers the class names and resolves
## every UID, but it only PARSES a script: a type error, an unknown identifier or an inference
## that cannot be made surfaces the first time something LOADS the script - in whichever mode or
## gate happens to load it first, as a failure that says nothing about where it came from. This
## loads every script under src/ and tests/ and names any that does not come back.

const ROOTS := ["res://src", "res://tests"]


func _init() -> void:
	_run.call_deferred()


## DEFERRED, not in _init: the autoloads' names (Director, Spectrum, Settings) resolve only once
## the tree is up, so a script naming one fails to compile from _init and compiles fine in the
## app - which is a harness artifact, not a finding.
func _run() -> void:
	await process_frame
	var bad: Array = []
	var n := 0
	for root in ROOTS:
		for path in _scripts(root):
			n += 1
			# THROUGH THE CACHE: a script already loaded (an autoload, a dependency) compiled to
			# get there, and reloading one that is live - CACHE_MODE_IGNORE - trips an internal
			# error in the engine and hangs it (measured on 4.7.2).
			var s: Script = ResourceLoader.load(path, "Script")
			if s == null or not s.can_instantiate():
				bad.append(path)
	# THE CONTROL: a script that cannot compile must be caught, or the sweep proves nothing.
	var probe := GDScript.new()
	probe.source_code = "extends Node\nfunc f() -> void:\n\tvar x := undefined_thing\n"
	var control_caught := probe.reload() != OK
	if not control_caught:
		print("compile_check: FAIL - the control compiled: a script with an unknown identifier "
			+ "was accepted, so this check cannot see a broken one")
	if bad.is_empty() and control_caught and n > 0:
		print("compile_check: ALL OK - %d scripts compile" % n)
		quit(0)
		return
	for p in bad:
		print("compile_check: FAIL - %s does not compile" % p)
	quit(1)


func _scripts(dir: String) -> Array:
	var out: Array = []
	var da := DirAccess.open(dir)
	if da == null:
		return out
	for f in da.get_files():
		# tests/run_boot_probe.sh's private copies come and go under a concurrent run
		if f.ends_with(".gd") and not f.begins_with("_probe_"):
			out.append(dir.path_join(f))
	for d in da.get_directories():
		out.append_array(_scripts(dir.path_join(d)))
	return out
