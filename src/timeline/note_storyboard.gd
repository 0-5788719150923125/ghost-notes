extends Node
class_name NoteStoryboard

## NoteStoryboard - a note's storyboard: the show written down, kept in the note's own folder as JSON ([constant FILE])
## and edited in the [StoryboardEditor] that opens from beside Play ([method Transport.offer_timeline]). A panel whose
## note has a Medium holds one; it offers the timeline while the format shown plays scenes ([method plays_scenes]).
## Nothing is attached for it.
##
## Nothing written, the seed chooses: the editor shows what the seed is about to play, grayed ([method
## Director.forecast]), and the first change to it makes it the note's own. An edit reaches the show a moment after the
## hand stops ([constant SETTLE]) and is written then, each state kept in the note's history ([constant HISTORY], listed
## by Restore…). Emptied (the editor's "To the seed"), the file goes and the seed chooses again.
##
## Handed by its panel: the note's folder ([member folder]). Never written from a process that may not write the
## author's things.

## The file in the note's folder, and the folder its states are kept in.
const FILE := "storyboard.json"
const HISTORY := "history/storyboard"
## How many scenes of the seeded show the editor shows while nothing is written.
const AHEAD := 12
## Seconds an edit waits before the show takes it and it is written: a number being dragged is many edits.
const SETTLE := 0.25
## Its place among a note's timelines ([method Transport.offer_timeline]): over the words' marks, under an episode.
const RANK := 2

## A line for the panel's status.
signal noted(msg: String)

## () -> String: the note's folder, absolute ("" for a note with no file).
var folder: Callable = Callable()

var _data := {"sequence": []}      # the raw tree, as written
var _editor: StoryboardEditor = null
var _settle := -1.0
var _poll := 0.0
var _fault := ""
var _saves_for_test := false       # see allow_saves_for_test


## The file of the storyboard kept in the note folder [param dir], "" for none.
static func path_in(dir: String) -> String:
	return "" if dir.is_empty() else dir.path_join(FILE)


## The storyboard kept in [param dir]: `{ok, error, data}`, the raw tree; nothing written is `{sequence: []}`.
static func read(dir: String) -> Dictionary:
	var p := path_in(dir)
	if p.is_empty() or not FileAccess.file_exists(p):
		return {"ok": true, "error": "", "data": {"sequence": []}}
	var r := Storyboard.read_raw(p)
	return {"ok": bool(r["ok"]), "error": String(r["error"]), "data": Storyboard.own_block(r["data"] if bool(r["ok"]) else {})}


## [param data] kept in [param dir] as the note's storyboard, its state kept in the history; nothing written removes
## the file. "" done, else why not.
static func write(dir: String, data: Dictionary) -> String:
	var p := path_in(dir)
	if p.is_empty():
		return "the note has no folder of its own"
	var tree := Storyboard.own_block(data)
	DirAccess.make_dir_recursive_absolute(dir)
	if (tree["sequence"] as Array).is_empty():
		if FileAccess.file_exists(p) and DirAccess.remove_absolute(p) != OK:
			return "could not remove " + p
	else:
		var f := FileAccess.open(p + ".part", FileAccess.WRITE)
		if f == null:
			return "could not write " + p
		f.store_string(Storyboard.to_json(tree))
		f.close()
		if DirAccess.rename_absolute(p + ".part", p) != OK:
			return "could not move the storyboard into place"
	return NoteHistory.record_data(dir.path_join(HISTORY), tree)


## Does the format [param fmt] play scenes, which a storyboard orders? Auto draws what Full frame does.
static func plays_scenes(fmt: String) -> bool:
	return fmt == "auto" or Medium.uses(fmt, "scenes")


func _ready() -> void:
	var r := read(_folder())
	_data = r["data"]
	if not bool(r["ok"]):
		_say_fault(String(r["error"]))
	Director.medium_changed.connect(_offer)
	_offer()


func _exit_tree() -> void:
	close_editor()
	Transport.withdraw_timeline(self)
	if Director.medium_changed.is_connected(_offer):
		Director.medium_changed.disconnect(_offer)


func _folder() -> String:
	return String(folder.call()) if folder.is_valid() else ""


## Offered beside Play while the format shown plays scenes; taken back (and the editor closed) while it does not.
func _offer() -> void:
	if not is_inside_tree():
		return
	if not plays_scenes(Director.resolved_medium()):
		Transport.withdraw_timeline(self)
		close_editor()
		return
	Transport.offer_timeline(self, RANK, func() -> void:
		if editor() != null:
			close_editor()
		else:
			open_editor(), func() -> bool: return editor() != null,
		"The storyboard's timeline: its entries, a stage's actors and what they do, flags on the camera and the Look.")


## What the show walks: `board`, the storyboard in its loaded form ({} where nothing is written, or what is written
## does not load - the seed chooses), and `source` ("": a render is handed it as written).
func plan() -> Dictionary:
	if (_data.get("sequence", []) as Array).is_empty():
		_say_fault("")
		return {"board": {}, "source": ""}
	var own := Storyboard.from_data(_data, Storyboard.IN_NOTE, "storyboard")
	_say_fault("" if bool(own.ok) else String(own.error))
	return {"board": own if bool(own.ok) else {}, "source": ""}


## The raw tree, as written.
func raw() -> Dictionary:
	return _data


## [param data] is the note's storyboard again (a state put back from its history): written, shown and walked.
func restore(data: Dictionary) -> String:
	_data = Storyboard.own_block(Storyboard.whole(data))
	var err := _save()
	_sync_editor(true)
	_take_to_show()
	return err


func _say_fault(msg: String) -> void:
	if msg == _fault:
		return
	_fault = msg
	var said := ("⚠  %s - until it is put right, the seed chooses the scenes." % msg) if not msg.is_empty() else ""
	if editor() != null:
		_editor.set_banner(said)
	if not said.is_empty():
		noted.emit(said)


## A gate's process is read-only: this one writes all the same, into a folder the gate made its own
## (`NoteUpload.root`). Nothing but a gate may call this.
func allow_saves_for_test() -> void:
	_saves_for_test = true


# --- the editor ------------------------------------------------------------------------------------

func open_editor() -> void:
	if editor() != null:
		return
	_editor = StoryboardEditor.new()
	_sync_editor(true)
	_editor.edited.connect(_on_edited)
	_editor.picked.connect(show_entry)
	_editor.scrubbed.connect(show_entry)
	_editor.closed.connect(close_editor)
	add_child(_editor)


func close_editor() -> void:
	if _editor != null and is_instance_valid(_editor):
		_editor.queue_free()
	_editor = null


## The editor, while it is open.
func editor() -> StoryboardEditor:
	return _editor if _editor != null and is_instance_valid(_editor) else null


## Hand the editor what is written. [param fresh]: another storyboard, so its history starts again; otherwise the one
## it has, changed from here.
func _sync_editor(fresh: bool) -> void:
	if editor() == null:
		return
	var written := not (_data.get("sequence", []) as Array).is_empty()
	if not written and Director.is_attached() and not Director.is_manual():
		# Nothing written: what the seed is going to play, as the storyboard it amounts to
		_editor.open({"transition": "dip", "sequence": Director.forecast(AHEAD)}, false,
			("Nothing is written yet, so the seed chooses: these are the first %d scenes it plays. Change any of them and "
			% AHEAD + "they are this note's own; + Scene starts one from nothing."), true)
	elif fresh or _editor.ghost:
		_editor.open(_data)
	else:
		_editor.replace(_data)
	if not _fault.is_empty():
		_editor.set_banner("⚠  %s - until it is put right, the seed chooses the scenes." % _fault)


func _on_edited(tree: Dictionary) -> void:
	_data = Storyboard.own_block(tree)
	_settle = SETTLE


# --- the show --------------------------------------------------------------------------------------

func _process(delta: float) -> void:
	if _settle >= 0.0:
		_settle -= delta
		if _settle < 0.0:
			_take_to_show()
			_save()
	_poll -= delta
	if _poll > 0.0:
		return
	_poll = 0.1
	if editor() != null:
		var cur := Director.cursor()
		_editor.set_cursor(int(cur["entry"]), float(cur["elapsed"]))


## What is written, in the note's folder. "" written (or a process that writes nothing of the author's), else why not.
func _save() -> String:
	if Settings.is_read_only() and not _saves_for_test:
		return ""
	var dir := _folder()
	if dir.is_empty():
		return ""
	var err := write(dir, _data)
	if not err.is_empty():
		noted.emit("⚠  The storyboard was not kept: " + err)
	return err


## Hand what is written to the show that is up: the Director walks it from the next cut, and the entry being worked on
## is put back on screen. With nothing written the show is the seed's again.
func _take_to_show() -> void:
	if not Director.is_attached():
		return
	var board: Dictionary = plan()["board"]
	if board.is_empty():
		if Director.is_manual():
			Director.clear_storyboard()
			Director.next()
		_sync_editor(true)
		return
	var was_manual := Director.is_manual()
	if not Director.load_board(board, ""):
		return
	var at := editor().selected() if editor() != null else -1
	if at >= 0:
		Director.goto_entry(at)
	elif not was_manual:
		Director.goto_entry(0)


## Put entry [param i] on screen (the tail's counted on from the sequence's end), [param into] seconds of it: the entry
## played again from its start and run on to there (a stage is a simulation - a verb latches as it plays - so a moment
## inside it is reached, never jumped to; [method Director.goto_entry]). Where the storyboard follows the song, the song
## goes to that entry's place in the schedule too.
func show_entry(i: int, into := 0.0) -> void:
	if not Director.is_attached():
		noted.emit("Entry %d - it is shown once the note's show is up." % (i + 1))
		return
	if _settle >= 0.0:
		_settle = -1.0
		_take_to_show()
		_save()
	if not Director.is_manual():
		return
	Director.goto_entry(i, into)
	var board: Dictionary = plan()["board"]
	if board.is_empty() or bool(board.get("loop", true)) or not Spectrum.conductor().is_empty() or not Spectrum.seekable():
		return
	var seq: Array = board["sequence"]
	if i >= seq.size():
		return
	var s := Storyboard.schedule(seq, Director.storyboard_sensitivity(), Director.unauthored_hold())
	var paused := Spectrum.paused
	Spectrum.seek(float(s["starts"][i]) + into)
	Spectrum.set_paused(paused)
