extends Node

## teardown_check - EVERY MODE CAN BE LEFT AND ENTERED AGAIN (next/notes.md step 6), through the real
## main scene: each template opened the way the notes list opens a note, left by Chrome's ⌂, several times
## over, and the app measured after every return home.
##
##   tests/run_boot_probe.sh tests/teardown_check.gd 420
##
## WHAT IS MEASURED after each return: nodes in the tree and orphan nodes (Godot's own monitors);
## the stage (wiped - no medium mounted, nothing shown: a tablet chapter's desk used to stay under the
## next note, 2026-10-06);
## Chrome's claims on the bottom of the frame and on the export button (the notes list's own only);
## the row (Masking's ⤓ gone, the ⌂ hidden); the transport (no conductor, nothing timed); the
## Director (no storyboard, no game pacing, no medium pinned by a mode); the audio buses and their
## effects; the background programs [Subprocess] tracks (the voice host stops with its panel). A
## number that grows with every cycle is a leak. The FIRST cycle of a mode may build what every later
## one reuses (the stage, a bus), so it is cycles 2..N that must agree with each other.
##
## LEAVING IS REFUSED, AND SAYS WHY, while an export is making the mode's take: the take is a
## coroutine on the mode's panel and the export would wait on a freed panel forever. Two-sided: the
## ⌂ grays and the mode stays, then the hold lifts and it leaves.
##
## THE CONTROL: a node a mode "forgets" to free is seen by the same measure, or the comparisons above
## prove nothing.
##
## A NOTE STARTS FROM NOTHING (2026-10-06, the user: "every time we enter a note, we should wipe the
## scene and start fresh"): a chapter that sets its medium and look hands neither to the note opened
## after it, and a song note opens stopped at its start. Two-sided: the chapter does set them.
##
## MASKING OPENS ON NO CLIP (its panel asks for one): the author's sessions hold hand-placed markers that
## cannot be remade, and no gate opens one. A song for Auto and Manual is a fixture of silence. Every
## note lives in a folder of the gate's own (`NoteStore.root`), so the author's notes are never made,
## listed or opened - and a reading's panel is pointed at a note of the gate's, never their chapter.

const CYCLES := 3
## The templates, as the notes list opens them (step 8): a note made from each, opened from the list.
const MODES := ["note", "auto", "manual", "synthesis", "generative", "cards", "masking"]
const ROOT := "user://teardown_check_notes"

var _fails: Array = []
var _main: Node
var _notes := {}       # template -> the gate's note made from it


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var song: String = preload("res://tests/fixture_audio.gd").silence(20.0)
	NoteStore.root = ROOT
	_notes = {}
	_main = preload("res://scenes/main.tscn").instantiate()
	add_child(_main)
	# the notes list and the Environment panel's first probe (a thread) settle first
	await _frames(30)
	await _settle_probe()
	var home := _measure()
	var ch: Chrome = _main._chrome
	_ok(not ch._home_button.visible, "the notes list has no ⌂ (there is nothing to leave)")
	for mode in MODES:
		var seen: Array = []
		for cycle in CYCLES:
			await _enter(mode, song)
			_ok(ch._home_button.visible and not ch._home_button.disabled,
				"%s #%d: the ⌂ shows while the mode is up" % [mode, cycle + 1])
			if mode == "generative" and cycle == 0:
				await _check_refused_while_preparing()
			ch._home_button.pressed.emit()
			await _frames(12)
			await _quiet(int(home["procs"]))
			var m := _measure()
			seen.append(m)
			_check_home(mode, cycle, m, home)
		# CYCLES 2..N AGREE: nothing grows with each visit
		for k in ["nodes", "orphans", "buses", "procs", "row"]:
			var vals := seen.slice(1).map(func(x: Dictionary) -> Variant: return x[k])
			var same := vals.all(func(v: Variant) -> bool: return str(v) == str(vals[0]))
			_ok(same, "%s: %s holds steady from the second visit on (%s)" % [mode, k, str(seen.map(func(x): return x[k]))])
	await _check_fresh(song)
	await _control(song)
	_clean()
	_report()


## Enter [param mode] the way the notes list does: a note made from the template (once), opened by the
## list's own handler, which calls main and then frees the list.
func _enter(mode: String, song: String) -> void:
	var list: Node = _main._list
	if list == null or not is_instance_valid(list):
		_ok(false, "%s: there is no notes list to open it from" % mode)
		return
	if not _notes.has(mode):
		var blocks := {"song": {"path": song}} if mode in ["auto", "manual"] else {}
		_notes[mode] = NoteStore.create(mode, "teardown %s" % mode, "Words.\n", blocks)
	list._open(String(_notes[mode]))
	await _frames(20)


## Back on the list after leaving [param mode]: everything the list began with, nothing a mode left.
func _check_home(mode: String, cycle: int, m: Dictionary, home: Dictionary) -> void:
	var tag := "%s #%d" % [mode, cycle + 1]
	_ok(m["list"], "%s: leaving returns to the notes list" % tag)
	_ok(str(m["bottom"]) == str(home["bottom"]) and str(m["export"]) == str(home["export"]),
		"%s: Chrome's claims are the list's own (bottom %s, export %s - list: %s, %s)"
		% [tag, m["bottom"], m["export"], home["bottom"], home["export"]])
	_ok(not m["home_button"], "%s: the ⌂ hides again" % tag)
	_ok(m["row"] == home["row"], "%s: the row is back to %d buttons (%d)" % [tag, home["row"], m["row"]])
	_ok(not m["conductor"] and not m["timed"], "%s: nothing conducts and nothing is timed" % tag)
	_ok(not m["manual"] and not m["paced"] and String(m["override"]).is_empty(),
		"%s: the Director is a session's again (storyboard %s, game-paced %s, pinned '%s')"
		% [tag, m["manual"], m["paced"], m["override"]])
	_ok(m["procs"] == home["procs"], "%s: no background program left running (%d, home %d)" % [tag, m["procs"], home["procs"]])
	_ok(m["modes"] == 0, "%s: no mode's node is left in the tree (%d)" % [tag, m["modes"]])
	_ok(not m["stage"] and not m["medium"], "%s: the stage is wiped (shown %s, a medium mounted %s)" % [tag, m["stage"], m["medium"]])


## TWO-SIDED: while an export makes the take, the ⌂ grays with the reason and leaving is refused -
## then the hold lifts and the same press leaves.
func _check_refused_while_preparing() -> void:
	var ch: Chrome = _main._chrome
	ch.exporter._prepping = true
	ch._paint_home()
	var why: String = _main.leave_mode()
	_ok(not why.is_empty() and ch._home_button.disabled and ch._home_button.tooltip_text == why,
		"leaving is refused while an export makes the take, and the ⌂ says why ('%s')" % why)
	_ok(_main._generative != null and is_instance_valid(_main._generative) and _main._list == null,
		"...and the mode is still up")
	ch.exporter._prepping = false
	ch._paint_home()
	_ok(not ch._home_button.disabled, "the ⌂ comes back once the take is made")


## A NOTE STARTS FROM NOTHING: what a chapter set is not the next note's, and a song opens stopped.
func _check_fresh(song: String) -> void:
	var ch: Chrome = _main._chrome
	var chapter := NoteStore.create("generative", "teardown fresh", "Words.\n",
		{"picture": {"medium": "tablet"}, "look": {"filters": {"monochrome": 1.0}}})
	_main._list._open(chapter)
	await _frames(20)
	_ok(Director.medium == "tablet" and Director.filter_amount("monochrome") > 0.0,
		"a chapter sets its medium and look (%s, %s)" % [Director.medium, str(Director.filters)])
	ch._home_button.pressed.emit()
	await _frames(12)
	var plain := NoteStore.create("note", "teardown plain", "Words.\n")
	_main._list._open(plain)
	await _frames(12)
	_ok(Director.medium == "full" and Director.resolved_filters().is_empty(),
		"the note opened after it starts from nothing (%s, %s)" % [Director.medium, str(Director.filters)])
	_ok(not _measure()["stage"], "...with no stage under its panel")
	ch._home_button.pressed.emit()
	await _frames(12)
	var auto := NoteStore.create("auto", "teardown stopped", "", {"song": {"path": song}})
	_main._list._open(auto)
	await _frames(20)
	_ok(Spectrum.has_audio() and not Spectrum.transport_playing() and Spectrum.current.time < 0.05,
		"a song note opens stopped, at its start (playing %s, %.2fs)" % [Spectrum.transport_playing(), Spectrum.current.time])
	ch._home_button.pressed.emit()
	await _frames(12)


## THE CONTROL: a node left behind by a "mode" shows up in the same count.
func _control(song: String) -> void:
	await _enter("auto", song)
	var stray := Node.new()
	stray.name = "LeftBehind"
	_main.add_child(stray)
	_main._chrome._home_button.pressed.emit()
	await _frames(12)
	var before: int = _measure()["nodes"]
	stray.queue_free()
	await _frames(3)
	var after: int = _measure()["nodes"]
	_ok(before == after + 1, "the control: a node a mode forgets is counted (%d with it, %d without)" % [before, after])


func _measure() -> Dictionary:
	var ch: Chrome = _main._chrome
	var buses: Array = []
	for i in AudioServer.bus_count:
		buses.append("%s:%d" % [AudioServer.get_bus_name(i), AudioServer.get_bus_effect_count(i)])
	var modes := 0
	for n in _main.get_children():
		if n is ReadingPanel or n is SynthEditor or n is MaskEditor or n is NotePanel:
			modes += 1
	return {
		"list": _main._list != null and is_instance_valid(_main._list),
		"nodes": get_tree().get_node_count(),
		"orphans": int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)),
		"bottom": ch._bottom_claims.keys(),
		"export": ch._export_claims.keys(),
		"row": ch.row.get_child_count(),
		"home_button": ch._home_button.visible,
		"conductor": not Spectrum.conductor().is_empty(),
		"timed": Spectrum.timed(),
		"manual": Director.is_manual(),
		"paced": Director._game_paced,
		"override": Director.medium_override,
		"buses": buses,
		"procs": Subprocess.tracked(),
		"modes": modes,
		"stage": _main._stage_view != null and is_instance_valid(_main._stage_view) and _main._stage_view.visible,
		"medium": _main._medium != null and is_instance_valid(_main._medium),
	}


## Programs a mode started are stopped as it leaves; give their reaping a moment.
func _quiet(home_procs: int) -> void:
	for _i in 60:
		if Subprocess.tracked() <= home_procs:
			return
		await _frames(5)


## The Environment panel's first probe runs on a thread and builds its rows when it returns.
func _settle_probe() -> void:
	var env: DepsPanel = _main._chrome.environment
	for _i in 600:
		if not env._rows.is_empty():
			break
		await get_tree().process_frame
	await _frames(10)


func _frames(n: int) -> void:
	for _i in n:
		await get_tree().process_frame


func _ok(cond: bool, msg: String) -> void:
	print(("  ok    " if cond else "  FAIL  ") + msg)
	if not cond:
		_fails.append(msg)


func _report() -> void:
	if _fails.is_empty():
		print("teardown_check: ALL OK")
		get_tree().quit(0)
		return
	print("teardown_check: %d FAILURE(S)" % _fails.size())
	for f in _fails:
		print("   ", f)
	get_tree().quit(1)


func _clean() -> void:
	var abs := ProjectSettings.globalize_path(ROOT)
	if DirAccess.dir_exists_absolute(abs):
		for f in DirAccess.get_files_at(abs):
			DirAccess.remove_absolute(abs.path_join(f))
		DirAccess.remove_absolute(abs)
