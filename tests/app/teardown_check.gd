extends Node

## teardown_check - every note can be left and entered again (next/notes.md), through the real main scene: a
## note of each make-up (words alone, a song and its show, a show written by hand with the storyboard's editor
## open, each workspace) opened the way the notes list opens a note, left by Chrome's ⌂ several times, and the
## app measured after every return home.
##
##   tests/run_boot_probe.sh tests/app/teardown_check.gd 420
##
## Measured after each return: nodes in the tree and orphan nodes (Godot's monitors); the stage (wiped: no
## medium mounted); Chrome's claims on the bottom of the frame, the show's room and the export button (the
## notes list's own only); the row (Masking's ⤓ gone, the ⌂ hidden); the transport (no conductor, nothing
## timed); the Director (no storyboard, no pinned medium); the audio buses and effects; the
## background programs [Subprocess] tracks. A number that grows with every cycle is a leak. The first cycle of
## a mode may build what later ones reuse, so cycles 2..N must agree with each other.
##
## Nothing is measured until the Environment panel's probe has landed: its rows are built when a thread comes
## back, and rows landing mid-cycle read as a leak. It is waited on by the clock, and a probe that never lands
## fails here rather than as a count that grew.
##
## Leaving is refused, and says why, while an export is making the mode's take (the take is a coroutine on the
## mode's panel). Two-sided: the ⌂ grays and the mode stays, then the hold lifts and it leaves.
##
## Control: a node a mode "forgets" to free is seen by the same measure.
##
## A note starts from nothing: a chapter that sets its medium and look hands neither to the note opened after
## it, and a song note opens stopped at its start. Two-sided: the chapter does set them.
##
## A note's make-up is its blocks: each is made with the blocks "+" would have written ([constant BLOCKS]). An
## Actor's note carries its own block alone, as "+" writes it, and must show its card and the Voice it brings,
## and play them.
##
## Masking opens on no clip (its panel asks for one): no gate opens the author's sessions. A song for Auto and
## Manual is a fixture of silence. Every note lives in a folder of the gate's own (`NoteStore.root`), and a
## reading's panel is pointed at a note of the gate's.

const CYCLES := 3
## What each note is made of: the blocks a note of that make-up carries (`SONG` stands for the fixture's path).
const MODES := ["note", "auto", "manual", "story", "generative", "narrated", "table",
	"likeness", "masking"]
const BLOCKS := {
	"note": {},
	"auto": {"song": {"path": "SONG"}, "medium": {"format": "auto"}},
	"manual": {"song": {"path": "SONG"}, "medium": {"format": "full"}},
	# a storyboard of the note's own, with the editor opened over the show before each leaving
	"story": {"song": {"path": "SONG"}, "medium": {"format": "full"}},
	"generative": {"voice": {}},
	# a voice with a Medium and a storyboard: a pairing no template had
	"narrated": {"voice": {}, "medium": {"format": "full"}},
	"table": {"table": {}},
	# an actor reading the note: its card pins the likeness medium, and brings a Voice beside it
	"likeness": {"actor": {}},
	"masking": {"clip": {"path": ""}},
}
## The storyboard each make-up keeps in its note's folder ([NoteStoryboard]): the shipped one's stage entries
## (actors carried across cuts), or a written list. A path is the file's raw tree.
const BOARDS := {
	"manual": "res://data/showcase.json",
	"story": {"loop": true, "sequence": [{"scene": "aurora", "hold": 4}, {"scene": "embers", "hold": 4}]},
	"narrated": {"loop": true, "sequence": [{"scene": "aurora", "hold": 4}]},
}
const ROOT := "user://teardown_check_notes"
## The notes' folders, the gate's own.
const READINGS := "user://teardown_check_readings"
## How long the Environment panel's first probe may take: a backstop only, far over a cold probe on a
## loaded runner.
const PROBE_WAIT_MS := 120000

var _fails: Array = []
var _main: Node
var _notes := {}       # make-up -> the gate's note made of it


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var song: String = preload("res://tests/fixture_audio.gd").silence(20.0)
	NoteStore.root = ROOT
	NoteUpload.root = READINGS
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
			# "+" actor writes its own block alone, and the Voice it brings has its card all the same
			if mode == "likeness" and cycle == 0:
				_ok(_has_node_of(_main, ActorCard) and _has_node_of(_main, VoiceCard),
					"likeness: the note shows its Actor card and the Voice card it brings")
				_ok(Director.medium_override == "likeness", "likeness: the Actor card does not pin its medium")
			if mode == "story":
				_open_timeline(cycle)
				await _frames(6)
			ch._home_button.pressed.emit()
			await _frames(12)
			await _quiet(int(home["procs"]))
			var m := _measure()
			seen.append(m)
			_check_home(mode, cycle, m, home)
		# Cycles 2..N agree: nothing grows with each visit
		for k in ["nodes", "orphans", "buses", "procs", "row"]:
			var vals := seen.slice(1).map(func(x: Dictionary) -> Variant: return x[k])
			var same := vals.all(func(v: Variant) -> bool: return str(v) == str(vals[0]))
			_ok(same, "%s: %s holds steady from the second visit on (%s)" % [mode, k, str(seen.map(func(x): return x[k]))])
	await _check_fresh(song)
	await _control(song)
	NoteUpload.root = NoteUpload.ROOT
	_clean()
	_report()


## Is a node of [param script]'s class anywhere under [param n]?
func _has_node_of(n: Node, script: Script) -> bool:
	if is_instance_of(n, script):
		return true
	for c in n.get_children():
		if _has_node_of(c, script):
			return true
	return false


## Enter [param mode] the way the notes list does: a note made from the template (once), opened by the list's
## own handler, which calls main and then frees the list.
func _enter(mode: String, song: String) -> void:
	var list: Node = _main._list
	if list == null or not is_instance_valid(list):
		_ok(false, "%s: there is no notes list to open it from" % mode)
		return
	if not _notes.has(mode):
		_notes[mode] = NoteStore.create("teardown %s" % mode, "Words.\n", _blocks(mode, song))
		if BOARDS.has(mode):
			var board: Variant = BOARDS[mode]
			var tree: Dictionary = Storyboard.read_raw(String(board))["data"] if board is String else board
			_ok(NoteStoryboard.write(NoteUpload.folder_of(String(_notes[mode])), tree).is_empty() and not tree.is_empty(),
				"%s: its storyboard is kept in its note's folder" % mode)
	list._open(String(_notes[mode]))
	await _frames(20)


## The blocks of a note of [param mode]'s make-up, the fixture's song put where one is named.
func _blocks(mode: String, song: String) -> Dictionary:
	var blocks: Dictionary = (BLOCKS[mode] as Dictionary).duplicate(true)
	if blocks.has("song"):
		blocks["song"] = {"path": song}
	return blocks


## The storyboard's editor, opened over the note's show: it claims room at the bottom of the frame and from the
## stage, and the leaving that follows must give both back.
func _open_timeline(cycle: int) -> void:
	var panel: NotePanel = _main._note_panel
	var card: NoteStoryboard = panel._story if panel != null else null
	_ok(card != null, "story #%d: the note holds its storyboard" % (cycle + 1))
	if card == null:
		return
	card.open_editor()
	var ch: Chrome = _main._chrome
	_ok(card.editor() != null and ch._bottom_claims.has(StoryboardEditor.CLAIM) and ch._stage_claims.has(StoryboardEditor.CLAIM),
		"story #%d: its editor is docked, and has claimed its room (%s, %s)" % [cycle + 1, ch._bottom_claims.keys(), ch._stage_claims.keys()])


## Back on the list after leaving [param mode]: everything the list began with, nothing a mode left.
func _check_home(mode: String, cycle: int, m: Dictionary, home: Dictionary) -> void:
	var tag := "%s #%d" % [mode, cycle + 1]
	_ok(m["list"], "%s: leaving returns to the notes list" % tag)
	_ok(str(m["bottom"]) == str(home["bottom"]) and str(m["export"]) == str(home["export"]),
		"%s: Chrome's claims are the list's own (bottom %s, export %s - list: %s, %s)"
		% [tag, m["bottom"], m["export"], home["bottom"], home["export"]])
	_ok((m["stage_room"] as Array).is_empty(), "%s: nothing is left claiming the show's room (%s)" % [tag, m["stage_room"]])
	_ok(not m["home_button"], "%s: the ⌂ hides again" % tag)
	_ok(m["row"] == home["row"], "%s: the row is back to %d buttons (%d)" % [tag, home["row"], m["row"]])
	_ok(not m["conductor"] and not m["timed"], "%s: nothing conducts and nothing is timed" % tag)
	_ok(not m["manual"] and String(m["override"]).is_empty(),
		"%s: the Director is a session's again (storyboard %s, pinned '%s')"
		% [tag, m["manual"], m["override"]])
	_ok(m["procs"] == home["procs"], "%s: no background program left running (%d, home %d)" % [tag, m["procs"], home["procs"]])
	_ok(m["modes"] == 0, "%s: no mode's node is left in the tree (%d)" % [tag, m["modes"]])
	_ok(not m["stage"] and not m["medium"], "%s: the stage is wiped (shown %s, a medium mounted %s)" % [tag, m["stage"], m["medium"]])


## Two-sided: while an export makes the take, the ⌂ grays with the reason and leaving is refused -
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


## A note starts from nothing: what a chapter set is not the next note's, and a song opens stopped.
func _check_fresh(song: String) -> void:
	var ch: Chrome = _main._chrome
	var chapter := NoteStore.create("teardown fresh", "Words.\n",
		{"voice": {}, "medium": {"format": "tablet"}, "look": {"filters": {"monochrome": 1.0}}})
	_main._list._open(chapter)
	await _frames(20)
	_ok(Director.medium == "tablet" and Director.filter_amount("monochrome") > 0.0,
		"a chapter sets its medium and look (%s, %s)" % [Director.medium, str(Director.filters)])
	ch._home_button.pressed.emit()
	await _frames(12)
	var plain := NoteStore.create("teardown plain", "Words.\n")
	_main._list._open(plain)
	await _frames(12)
	_ok(Director.medium == "full" and Director.resolved_filters().is_empty(),
		"the note opened after it starts from nothing (%s, %s)" % [Director.medium, str(Director.filters)])
	_ok(not _measure()["stage"], "...with no stage under its panel")
	ch._home_button.pressed.emit()
	await _frames(12)
	var auto := NoteStore.create("teardown stopped", "", _blocks("auto", song))
	_main._list._open(auto)
	await _frames(20)
	_ok(Spectrum.has_audio() and not Spectrum.transport_playing() and Spectrum.current.time < 0.05,
		"a song note opens stopped, at its start (playing %s, %.2fs)" % [Spectrum.transport_playing(), Spectrum.current.time])
	ch._home_button.pressed.emit()
	await _frames(12)


## The control: a node left behind by a "mode" shows up in the same count.
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
		if n is ReadingPanel or n is MaskEditor or n is NotePanel:
			modes += 1
	return {
		"list": _main._list != null and is_instance_valid(_main._list),
		"nodes": get_tree().get_node_count(),
		"orphans": int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)),
		"bottom": ch._bottom_claims.keys(),
		"export": ch._export_claims.keys(),
		"stage_room": ch._stage_claims.keys(),
		"row": ch.row.get_child_count(),
		"home_button": ch._home_button.visible,
		"conductor": not Spectrum.conductor().is_empty(),
		"timed": Spectrum.timed(),
		"manual": Director.is_manual(),
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


## The Environment panel's first probe runs on a thread and builds its rows when it returns: waited on by the
## clock, since how many frames a cold probe takes is the machine's.
func _settle_probe() -> void:
	var env: DepsPanel = _main._chrome.environment
	var t0 := Time.get_ticks_msec()
	while not _probed(env) and Time.get_ticks_msec() - t0 < PROBE_WAIT_MS:
		await get_tree().process_frame
	_ok(_probed(env), "the Environment panel's probe has landed before anything is measured (%d rows, %.1f s)"
		% [env._rows.size(), (Time.get_ticks_msec() - t0) / 1000.0])
	await _frames(10)


## Its rows are built and no probe is still out on a thread.
static func _probed(env: DepsPanel) -> bool:
	return not env._rows.is_empty() and env._thread == null


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
	_rmrf(ProjectSettings.globalize_path(READINGS))


## [param dir] and everything in it, gone: the gate's own folders only.
func _rmrf(dir: String) -> void:
	if not DirAccess.dir_exists_absolute(dir):
		return
	for sub in DirAccess.get_directories_at(dir):
		_rmrf(dir.path_join(sub))
	for f in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(f))
	DirAccess.remove_absolute(dir)
