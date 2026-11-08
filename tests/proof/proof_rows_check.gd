extends SceneTree

## proof_rows_check - a Proof episode, as rows of the note's Pipeline card ([ProofCard.Section]; next/pipeline.md).
##
##   godot --headless --path . --script tests/proof/proof_rows_check.gd
##
## Each step is a row, with a Whole episode row over them where Make episode's second meaning had been (a button that made
## the first time and threw everything away the second; 2026-11-02). THE WHOLE EPISODE ASKS, and nothing runs until it is
## answered. A STEP THROWS AWAY ONLY WHAT AGENTS MADE: the solve asks, naming the lesson; the ink does not (THE CONTROL), for the
## script after it is the tools'. ⟳ GOES ON FROM WHERE IT STOPPED: on the first step never made, in an episode begun, it is
## offered, and on a later one it is not (THE CONTROL). A step passed by while the lesson stands has nothing to make, and is
## left out of the count. Generate refuses a note with no problem, saying so over the rows.

const ROOT := "user://proof_rows_check"

var _fails := 0
var _ed: Object
var _proof: Object
var _pipe: Object
var _ep: Object


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var settings := root.get_node_or_null("Settings")
	if settings != null:
		settings.set("_read_only", true)
	var episodes: GDScript = load("res://src/proof/proof_episode.gd")
	var was: String = episodes.root
	episodes.root = ROOT
	_ed = load("res://src/reading/reading_panel.gd").new()
	_ed.workspace = "proof"
	_ed._build_panel()
	_ed._doc._sync = false
	_ed._doc._fields = {"title": "Rows"}
	_proof = _ed._block_cards["proof"]
	_pipe = _ed.pipeline()
	_proof._open_episode()
	_ep = _proof._episode
	_check()
	_ed.free()
	episodes.root = was
	_rmrf(ProjectSettings.globalize_path(ROOT))
	print("proof_rows_check: %s" % ("ALL OK" if _fails == 0 else "%d FAILED" % _fails))
	quit(0 if _fails == 0 else 1)


func _ok(cond: bool, what: String) -> void:
	print(("  ok    " if cond else "  FAIL  ") + what)
	if not cond:
		_fails += 1


func _write(steps: Array) -> void:
	for s in steps:
		var path: String = _ep.file_of(String(s))
		DirAccess.make_dir_recursive_absolute(path.get_base_dir())
		var f := FileAccess.open(path, FileAccess.WRITE)
		f.store_string("{}" if path.ends_with(".json") else "Some words.")
		f.close()


func _redo(key: String) -> Button:
	return _pipe.row(key)["redo"]


func _check() -> void:
	_pipe.refresh()
	_ok(_pipe.names().has("Whole episode") and _pipe.names().has("Problem") and _pipe.names().has("Script"), "each step is a row: %s" % str(_pipe.names()))
	_ok(_redo("whole").disabled and not _pipe._generate.disabled, "nothing made: nothing to remake, and Generate offered")
	_pipe.generate()
	_ok(_ed.pipeline().sections()[0].told.contains("Write a problem") or _proof._section.told.contains("Write a problem"),
		"Generate with no problem refuses, saying so over the rows (%s)" % _proof._section.told)
	# GOES ON FROM WHERE IT STOPPED
	_write(["problem", "solve"])
	_pipe.refresh()
	_ok(not _redo("draft").disabled and _redo("review").disabled and _redo("draft").tooltip_text.contains("the ones after it"),
		"on the first never made it goes on from there; on a later one it is not offered (the control)")
	# WHAT IT THROWS AWAY
	_write(["draft", "review", "lesson", "ink", "script"])
	_pipe.refresh()
	var whole := _redo("whole")
	_ok(not whole.disabled and _pipe.asks_first("whole") and whole.tooltip_text.contains("thrown away"), "the whole episode asks first, and says what goes")
	var solve := _redo("solve")
	_ok(_pipe.asks_first("solve") and solve.tooltip_text.contains("Lesson") and not solve.tooltip_text.contains("Ink"),
		"the solve throws the agents' work away and says which: %s" % solve.tooltip_text.replace("\n", " "))
	_ok(not _pipe.asks_first("ink"), "control: the ink takes only the script, the tools': it does not ask")
	# PRESSED
	whole.pressed.emit()
	_ok(_ep.has("lesson") and _pipe.asking != null, "pressed: it asks, nothing thrown away yet")
	_pipe.asking.canceled.emit()
	_ok(_ep.has("lesson") and _ep.has("problem"), "no: all still there")
	# WHILE IT IS MADE
	_proof._producer.running = true
	_pipe.refresh()
	_ok(whole.disabled and solve.disabled, "while the episode is being made, every ⟳ waits")
	_proof._producer.running = false
	# PASSED BY
	DirAccess.remove_absolute(_ep.file_of("draft"))
	_pipe.refresh()
	_ok(String((_pipe.row("draft")["glyph"] as Label).text) == "–", "a step passed by while the lesson stands has nothing to make")
	_ok(not _pipe._tally.text.ends_with("/%d" % _pipe.names().size()), "...and is left out of the count (%s)" % _pipe._tally.text)


func _rmrf(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for f in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(f))
	for d in DirAccess.get_directories_at(path):
		_rmrf(path.path_join(d))
	DirAccess.remove_absolute(path)
