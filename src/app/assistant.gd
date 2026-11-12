extends CanvasLayer
class_name Assistant

## The muted caption under the picker.
const COL_USES := Color(0.42, 0.48, 0.58)

## Assistant - the feedback browser and, opt-in, the hand-off of each feedback submission to a CLI agent.
##
## This node exists unconditionally (main.gd / mask_editor.gd): it is also the only UI for reviewing
## and deleting feedback console submissions (feedback.gd).
##
## Dispatch is gated on the Assistant's own picker and on that CLI being installed ([method
## AssistantBackends.runnable] reads as Off without it; a follow-up or resume needs its own pinned
## CLI). With a backend chosen, each submission is handed to a fresh permission-bypassed run
## (`claude -p --dangerously-skip-permissions`, or Codex or Grok Build); the agent, model and level
## come from the writers' own row ([method AgentPick.assistant]). What differs between CLIs (command
## line, resume, event stream, cost) lives in [AssistantBackends]; each entry remembers which CLI
## started it so a follow-up never lands on another CLI's session. With it Off, submissions are
## listed (status "orphaned") and never sent on their own.
##
## Every submission starts at once, however many are running. Each run edits the same working tree,
## so the dispatch prompt tells the agent to scope its edit narrowly.
##
## Conversations persist to feedback/NNNN.assistant.json (beside the console's NNNN.json/.png) and are
## resumable: a typed follow-up continues the same session via --resume.
##
## UI: bottom-right in the export button's row, right of it, closed by default (a chat-bubble toggle
## with an activity badge). Expanded, it is a scrollable list of entries, each expandable to the full
## exchange, with a delete button. Both export buttons leave room for it (their offset_right), so
## move none without the others.

const DIR := "res://feedback"
## Where the notes are, for a gate: a folder of its own, never the author's. "" is the app's.
static var root := ""


static func _feedback_dir() -> String:
	if not root.is_empty():
		return root
	return DIR if OS.has_feature("editor") else "user://feedback"
const PANEL_W := 380
## A gate's hold: while set, nothing queued is started. Never set by the app.
var hold := false

## The pure half: per-backend command lines and stream parsing. Preloaded rather than named by class so
## a headless run does not depend on the class cache.
const Backends := preload("res://src/agents/assistant_backends.gd")

var _repo_root := ""

var _entries: Array = [] # Array[Dictionary], newest first - see enqueue()
var _running_count := 0 # how many entries are actively running right now
var _timer_tick := 0.0 # throttles the running-entry elapsed-timer repaint to ~1/sec
## Set the instant the app starts closing (see _notification). Once true, _process stops polling
## dispatched child PIDs: Godot reaps its children on shutdown, and a same-frame OS.is_process_running()
## races that reap on the same pid (ECHILD during teardown). Dispatched runs are meant to outlive the
## editor, so not observing them past close is correct.
var _closing := false

var _panel: Control
var _list_col: VBoxContainer
var _header: Label
var _head_row: HBoxContainer        # the header and its Delete all
var _delete_all_btn: Button
var _toggle_btn: Button
var _expanded := false # closed by default - see _build_ui


## A restart requested (the editor's F5, or after a run edits code) but held until every agent has
## returned, so it cannot corrupt another agent's edits. Fired by _maybe_reload when idle.
var _pending_reload: Callable = Callable()


func _ready() -> void:
	add_to_group("assistant") # the mask editor asks us to defer its reload until idle
	layer = 126 # below the feedback console itself (128), above ordinary scene UI
	_resolve_repo_root()
	_ensure_dir()
	_build_ui()
	_load_existing()
	_refresh_list()


## The real binary for a backend. A GUI launch's path differs from a shell's, so it is resolved through
## [Deps], the same answer the Environment panel reports.
func _bin_for(backend: String) -> String:
	var bin := Backends.dep(backend)
	var path := Deps.resolve(bin)
	return path if not path.is_empty() else bin


## Which CLI an entry belongs to. Recorded at first dispatch and never changed, because a session id
## only means something to the CLI that issued it; an entry saved before backends were recorded was Claude's.
func _backend_of(entry: Dictionary) -> String:
	var b := String(entry.get("backend", ""))
	if Backends.has(b):
		return b
	var chosen := AssistantBackends.choice()
	return chosen if Backends.has(chosen) else Backends.LEGACY


## "" when the CLI this entry runs on is installed, else "<that CLI> is not installed". A follow-up or
## resume is pinned to the CLI that started it, whatever the dropdown says now.
func _missing_cli(entry: Dictionary) -> String:
	var b := _backend_of(entry)
	return "" if AssistantBackends.installed().has(b) else "%s is not installed" % Backends.label(b)


## ghost's project root is the repository, so the subprocess runs from res:// and sees the same
## Claude.md and git context as an interactive session.
func _resolve_repo_root() -> void:
	_repo_root = Boot.project_dir().simplify_path()


func _ensure_dir() -> void:
	var dir := ProjectSettings.globalize_path(_feedback_dir())
	if not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)
	#Kept out of Godot's scan: under res:// an editor scan imports every screenshot as a texture. Nothing
	#loads a note's files as resources; an agent reads them from disk. (Never from a test.)
	var ignore := dir.path_join(".gdignore")
	if _feedback_dir().begins_with("res://") and not FileAccess.file_exists(ignore) \
			and not Settings.is_read_only() and not Settings.is_probe_launch(OS.get_cmdline_args()):
		var f := FileAccess.open(ignore, FileAccess.WRITE)
		if f != null:
			f.close()


# --- public API ----------------------------------------------------------------

## Called by whoever owns the FeedbackConsole right after it writes feedback/NNNN.json (feedback.gd's
## `submitted` signal). Fires at once only if the console's Ask box was on ([param ask]) and a backend
## is selected; otherwise the entry is listed in the "orphaned" state, with its Send button.
func enqueue(index: int, query: String, stem: String, ask: bool = true) -> void:
	var entry := {
		"index": index, "query": query, "stem": stem,
		"status": "queued", "session_id": "", "response": "", "cost_usd": 0.0,
		"pid": - 1, "out_path": "", "err_path": "", "error_text": "", "expanded": true,
		"pending_prompt": "", "backend": "", "usage": "",
	}
	_entries.push_front(entry)
	if not sends(ask, AssistantBackends.runnable()):
		entry.status = "orphaned"
		_refresh_list()
		return
	_save_entry(entry)
	_refresh_list()
	_pump_queue()


## Whether a submission is dispatched the moment it lands: the Ask box was on and a backend is chosen.
static func sends(ask: bool, backend: String) -> bool:
	return ask and backend != ""


# --- dispatch --------------------------------------------------------------------

## Anything still running or waiting to run: the window in which a restart would clobber an agent's edits.
func is_busy() -> bool:
	if _running_count > 0:
		return true
	for e in _entries:
		if e.status == "queued":
			return true
	return false


## Defer a restart until every agent has returned. Fires at once if already idle.
func reload_when_idle(cb: Callable) -> void:
	_pending_reload = cb
	if is_busy():
		var me := get_tree().get_first_node_in_group("mask_editor")
		if me != null and me.has_method("_set_status"):
			me.call("_set_status", "⟳  Reload pending - restarting once assistant runs finish (%d active)" % _running_count)
	_maybe_reload()


func _maybe_reload() -> void:
	if not _pending_reload.is_valid() or is_busy():
		return
	#Hold the reload until the feedback console closes, as main.gd's _end_session does.
	var fc := get_tree().get_first_node_in_group("feedback_console")
	if fc != null and is_instance_valid(fc) and fc.is_open():
		if not fc.closed.is_connected(_maybe_reload):
			fc.closed.connect(_maybe_reload, CONNECT_ONE_SHOT)
		return
	var cb := _pending_reload
	_pending_reload = Callable()
	cb.call()


## Newest modification time across ghost's own source (src/ + shaders/, subfolders included). A dispatch
## records it at start (see _dispatch); if it is higher at _finish, that run edited code and the app
## should reload.
func _max_ghost_source_mtime(dirs: Array = ["res://src", "res://shaders"]) -> float:
	var best := 0.0
	for d in dirs:
		var da := DirAccess.open(d)
		if da == null:
			continue
		for fn in da.get_files():
			if fn.ends_with(".gd") or fn.ends_with(".gdshader") or fn.ends_with(".gdshaderinc"):
				var m := float(FileAccess.get_modified_time(ProjectSettings.globalize_path("%s/%s" % [d, fn])))
				if m > best:
					best = m
		var subs: Array = []
		for sub in da.get_directories():
			subs.append("%s/%s" % [d, sub])
		if not subs.is_empty():
			best = maxf(best, _max_ghost_source_mtime(subs))
	return best


func _pump_queue() -> void:
	if hold:
		return
	for e in _entries.duplicate():
		if e.status == "queued":
			var pending: String = e.get("pending_prompt", "")
			e.pending_prompt = ""
			_dispatch(e, pending if pending != "" else _build_prompt(e))


## `prompt` is the initial dispatch prompt or a typed follow-up; either lands on the same session once
## `entry.session_id` is set, via --resume.
func _dispatch(entry: Dictionary, prompt: String) -> void:
	#Never launch a CLI that is not there: the buttons are grayed without it, so this is the backstop. The
	#entry is parked as a resumable error, picked up by its own button once the CLI is installed.
	var missing := _missing_cli(entry)
	if not missing.is_empty():
		entry.status = "interrupted" if String(entry.session_id) != "" else "orphaned"
		entry.error_text = missing + " - install it, then rescan on the home screen"
		_save_entry(entry)
		_refresh_list()
		return
	entry.code_mtime = _max_ghost_source_mtime() # baseline: detect if THIS run edits code
	_running_count += 1
	entry.status = "running"
	entry.started_at = Time.get_ticks_msec()
	entry.read_offset = 0
	entry.progress = "starting…"
	var base := ProjectSettings.globalize_path(_feedback_dir())
	entry.out_path = "%s/%04d.out.json" % [base, int(entry.index)]
	entry.err_path = "%s/%04d.err.log" % [base, int(entry.index)]
	var prompt_path := "%s/%04d.prompt.txt" % [base, int(entry.index)]
	#A run reads only its own stream: a run the app died under leaves files behind and feedback numbering
	#restarts, so a new run can share their name and this frame's _poll_progress could read the old one.
	_delete_file(entry.out_path)
	_delete_file(entry.err_path)
	#Pinned on first dispatch: a follow-up or resume must reach the same CLI whatever the dropdown says now.
	var backend := _backend_of(entry)
	entry.backend = backend
	var run := _run_for(entry, prompt_path)
	#The run's stdout is a stream of JSON events, one per line: _poll_progress tails it each frame for a
	#live "what's it doing" line; _finish reads the whole thing once the process exits. The prompt reaches
	#the CLI on stdin from a file, never argv or shell source (see AssistantBackends). Detached: the run
	#edits the working tree and may finish after the editor closes.
	var pf := FileAccess.open(prompt_path, FileAccess.WRITE)
	if pf != null:
		pf.store_string(prompt)
		pf.close()
	var cli := Backends.argv(backend, _bin_for(backend), String(entry.session_id), _repo_root, run)
	entry.pid = Subprocess.start_redirected(cli[0], cli.slice(1), {"cwd": _repo_root,
		"stdin": prompt_path, "out": entry.out_path, "err": entry.err_path}, "", true) \
		if pf != null else -1
	if int(entry.pid) < 0:
		#create_process failed outright. _process only calls _finish() on an actual pid, so without this the
		#entry would sit at "running" and block the queue.
		entry.status = "error"
		entry.error_text = "failed to start the %s subprocess (launch returned %d)" \
			% [Backends.label(backend), int(entry.pid)]
		_running_count -= 1
		_save_entry(entry)
		_refresh_list()
		_pump_queue()
		return
	_save_entry(entry)
	_refresh_list()


## What a run of [param entry] takes ([method AssistantBackends.argv]'s `run`), on the CLI pinned to it:
## the picker's model and level while the picker names that CLI, else what the entry last ran on. Grok
## is handed the id a fresh run takes: its opening event has none.
func _run_for(entry: Dictionary, prompt_path: String) -> Dictionary:
	var backend := String(entry.backend)
	var c: Dictionary = _pick.choice() if _pick != null else {}
	if String(c.get("agent", "")) == backend:
		entry.model = String(c["model"])
		entry.effort = String(c["effort"])
	var run := {"model": String(entry.get("model", "")), "effort": String(entry.get("effort", "")),
		"prompt_path": prompt_path}
	if backend == "grok_cli" and String(entry.session_id).is_empty():
		entry.fresh = Backends.new_session_id()
		run["fresh"] = entry.fresh
	return run


## Points the fresh session at the feedback record and screenshot and lets it read them itself; the
## record carries the full resolved layer stack, markers and playhead. Claude.md is named explicitly so
## the run reads the repo's orientation before it starts on files.
func _build_prompt(entry: Dictionary) -> String:
	var rel: String = String(entry.stem).trim_prefix("res://") # "feedback/0051"
	return ("Read CLAUDE.md first - it's the map of where things live in " +
		"this project plus hard-won gotchas (shader validation, etc.) that'll save you " +
		"from re-deriving them via grep.\n\n" +
		"New feedback was left in ghost's feedback console: %s.json " +
		"(screenshot at %s.png). Read both to understand the exact scene/state " +
		"being reacted to, then fix the issue. Their note: \"%s\"\n\n" +
		"This runs unattended - scope the fix to what's actually reported rather than " +
		"opportunistically refactoring nearby code.") % [rel, rel, String(entry.query)]


## WM_CLOSE_REQUEST reaches every node when the main window is asked to close; EXIT_TREE/PREDELETE cover
## programmatic quits. Latching here, before the frame's _process, prevents the ECHILD race (see _closing).
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_EXIT_TREE \
			or what == NOTIFICATION_PREDELETE:
		_closing = true
		#a note's files being deleted are finished, never abandoned half-way
		_reap_deleting(true)


func _process(_dt: float) -> void:
	if _closing:
		return
	if not _deleting.is_empty():
		_reap_deleting()
	var any_running := false
	for e in _entries:
		if e.status == "running" and int(e.pid) >= 0:
			any_running = true
			_poll_progress(e)
			if not OS.is_process_running(int(e.pid)):
				_finish(e)
	#The elapsed timer and progress line repaint about once a second: rebuilding the list is real UI work.
	if any_running:
		_timer_tick += _dt
		if _timer_tick >= 1.0:
			_timer_tick = 0.0
			_refresh_list()


## Tails entry.out_path for newly written, complete stream-json lines (a partial trailing line is left
## for the next poll) and keeps entry.progress at the most recent meaningful event, so the UI can show
## what a run in flight is doing.
func _poll_progress(entry: Dictionary) -> void:
	if not FileAccess.file_exists(entry.out_path):
		return
	var since := Backends.lines_since(entry.out_path, int(entry.get("read_offset", 0)))
	entry.read_offset = since.offset
	for line in since.lines:
		line = line.strip_edges()
		if line == "":
			continue
		var evt = Backends.json_object(line)
		if evt is Dictionary:
			#Persist the session id the instant it first appears (Claude's init event, Codex's thread.started),
			#so a run interrupted by a crash can still be resumed (see _load_existing).
			if String(entry.session_id) == "":
				var sid := Backends.session_of(_backend_of(entry), evt)
				#a run handed its id (Grok) has it once it has said something
				if sid == "" and String(evt.get("type", "")) == "assistant":
					sid = String(entry.get("fresh", ""))
				if sid != "":
					entry.session_id = sid
					_save_entry(entry)
			var desc := Backends.describe(_backend_of(entry), evt)
			if desc != "" and desc != String(entry.get("progress", "")):
				#Marks the moment the agent did something new; _build_row flickers the collapsed title from it.
				entry._flicker_pulse_at = Time.get_ticks_msec()
			if desc != "":
				entry.progress = desc


## Dig a session id out of a captured output/error blob when the field was never saved (an interrupted run).
func _recover_session_id(text: String, backend: String = Backends.LEGACY) -> String:
	return Backends.recover_session(backend, text)


func _finish(entry: Dictionary) -> void:
	var backend := _backend_of(entry)
	var out_text := _read_file(entry.out_path)
	var res: Dictionary = Backends.result(backend, Backends.events_in(out_text))
	if bool(res.ok):
		entry.status = "done"
		entry.response = String(res.response)
		if String(res.session) != "":
			entry.session_id = String(res.session)
		entry.cost_usd = float(res.cost_usd)
		entry.usage = String(res.usage)
		entry.error_text = ""
	else:
		var err_text := _read_file(entry.err_path)
		if String(entry.session_id) == "":
			entry.session_id = String(res.session)
		#No clean result, but it may have emitted its first event and so have a session id: then it is
		#resumable, not a dead end.
		if String(entry.session_id) == "":
			entry.session_id = _recover_session_id(out_text + "\n" + err_text, backend)
		if String(entry.session_id) != "":
			entry.status = "interrupted"
			entry.error_text = "did not finish - Resume to continue this session"
			if String(res.error) != "":
				entry.error_text = "%s: %s - Resume to continue this session" \
					% [Backends.label(backend), String(res.error)]
		else:
			entry.status = "error"
			entry.error_text = err_text if err_text != "" else \
				(out_text if out_text != "" else "(no output - the process may have failed to start)")
	_delete_file(entry.out_path)
	_delete_file(entry.err_path)
	_delete_file(String(entry.out_path).replace(".out.json", ".prompt.txt"))
	entry.pid = -1
	entry.progress = ""
	_save_entry(entry)
	_refresh_list()
	_running_count -= 1
	_pump_queue()
	#If this run edited ghost's own code, arrange a restart, held by reload_when_idle until other running
	#agents return. Routed through _reload_requested so it also defers to an in-flight export.
	if entry.status == "done" and _max_ghost_source_mtime() > float(entry.get("code_mtime", 0.0)):
		var me := get_tree().get_first_node_in_group("mask_editor")
		if me != null and me.has_method("_reload_requested"):
			reload_when_idle(Callable(me, "_reload_requested"))
	_maybe_reload()


func _read_file(path: String) -> String:
	if path == "" or not FileAccess.file_exists(path):
		return ""
	var fa := FileAccess.open(path, FileAccess.READ)
	if fa == null:
		return ""
	var s := fa.get_as_text()
	fa.close()
	return s


func _delete_file(path: String) -> void:
	if path != "" and FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


# --- persistence -------------------------------------------------------------

func _save_entry(entry: Dictionary) -> void:
	var path := "%s.assistant.json" % ProjectSettings.globalize_path(String(entry.stem))
	var data := {
		"index": entry.index, "query": entry.query, "status": entry.status,
		"session_id": entry.session_id, "response": entry.response,
		"cost_usd": entry.cost_usd, "error_text": entry.get("error_text", ""),
		"backend": entry.get("backend", ""), "usage": entry.get("usage", ""),
		"model": entry.get("model", ""), "effort": entry.get("effort", ""),
	}
	var fa := FileAccess.open(path, FileAccess.WRITE)
	if fa != null:
		fa.store_string(JSON.stringify(data, "\t"))
		fa.close()


## Conversations from a prior run of the app, rebuilt from the persisted summaries (see _save_entry). A
## run still queued or running when the app closed died with the editor, so it is surfaced as an error
## (or as resumable, see below).
func _load_existing() -> void:
	var dir := DirAccess.open(_feedback_dir())
	if dir == null:
		return
	var loaded := []
	var has_record := {} # feedback index -> true, for every entry ALREADY reconciled below
	for fn in dir.get_files():
		if not fn.ends_with(".assistant.json"):
			continue
		var fa := FileAccess.open("%s/%s" % [_feedback_dir(), fn], FileAccess.READ)
		if fa == null:
			continue
		var data = JSON.parse_string(fa.get_as_text())
		fa.close()
		if not (data is Dictionary):
			continue
		var idx := int(data.get("index", 0))
		var status := str(data.get("status", "error"))
		var error_text := str(data.get("error_text", ""))
		var sid := str(data.get("session_id", ""))
		#No key = saved before backends were recorded, which means Claude.
		var backend := str(data.get("backend", ""))
		if not Backends.has(backend):
			backend = Backends.LEGACY
		if sid == "":
			sid = _recover_session_id(error_text, backend) # older logs stashed the init event in error_text
		#A run that was mid-flight when the editor closed (or errored without a clean result) is resumable if
		#its session id is known: continue it via --resume. Only an unidentifiable run is a dead "error".
		if status == "running" or status == "queued" or (status == "error" and sid != ""):
			if sid != "":
				status = "interrupted"
				error_text = "did not finish before the editor closed - Resume to continue this session"
			else:
				status = "error"
				error_text = "interrupted - the editor closed before this run could be identified"
		loaded.append({
			"index": idx, "query": str(data.get("query", "")), "stem": "%s/%04d" % [_feedback_dir(), idx],
			"status": status, "session_id": sid,
			"response": str(data.get("response", "")), "cost_usd": float(data.get("cost_usd", 0.0)),
			"pid": - 1, "out_path": "", "err_path": "", "error_text": error_text, "expanded": false,
			"pending_prompt": "", "backend": backend, "usage": str(data.get("usage", "")),
			"model": str(data.get("model", "")), "effort": str(data.get("effort", "")),
		})
		has_record[idx] = true
	#Orphaned feedback: a NNNN.json with no matching NNNN.assistant.json (submitted while the picker was
	#Off). Listed, never auto-dispatched, so turning the assistant on cannot fire a permission-bypassed
	#run against ancient feedback; each needs its own click (the "orphaned" status in _build_body).
	for fn in dir.get_files():
		if not fn.ends_with(".json") or fn.ends_with(".assistant.json"):
			continue
		var stem_name := fn.get_basename()
		if not stem_name.is_valid_int():
			continue
		var idx := int(stem_name)
		if has_record.has(idx):
			continue
		var fa := FileAccess.open("%s/%s" % [_feedback_dir(), fn], FileAccess.READ)
		if fa == null:
			continue
		var data = JSON.parse_string(fa.get_as_text())
		fa.close()
		var query := String(data.get("query", "")) if data is Dictionary else ""
		if query == "":
			continue
		loaded.append({
			"index": idx, "query": query, "stem": "%s/%04d" % [_feedback_dir(), idx],
			"status": "orphaned", "session_id": "", "response": "", "cost_usd": 0.0,
			"pid": - 1, "out_path": "", "err_path": "", "error_text": "", "expanded": false,
			"pending_prompt": "", "backend": "", "usage": "",
		})
	loaded.sort_custom(func(a, b): return int(a.index) > int(b.index))
	_entries = loaded
	_refresh_list()


# --- deleting -------------------------------------------------------------------
# Rows are built only while the panel is open, a removed note leaves the list at once, and its files
# are deleted on a worker (the list rebuild and symbol-font search were the cost, not the disk).

## The deleting under way: WorkerThreadPool task ids, each waited for once done (_process) or as the app closes.
var _deleting: Array = []


## The files of [param entry], absolute: its record and screenshot (and the screenshot's import file),
## its conversation, and a run's stream, error log and prompt - by its number, since an entry loaded
## from an earlier session knows no paths of its own.
func _files_of(entry: Dictionary) -> PackedStringArray:
	var g := ProjectSettings.globalize_path(String(entry.stem))
	var out := PackedStringArray()
	for ext in [".assistant.json", ".json", ".png", ".png.import", ".out.json", ".err.log", ".prompt.txt"]:
		out.append(g + ext)
	return out


## Delete [param paths] on a worker: what is listed has already left the list.
func _remove_away(paths: PackedStringArray) -> void:
	if not paths.is_empty():
		_deleting.append(WorkerThreadPool.add_task(_remove.bind(paths), false, "feedback delete"))


static func _remove(paths: PackedStringArray) -> void:
	for p in paths:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)


## Every task id whose deleting is done, let go of. With [param all], wait for the rest (the app closing).
func _reap_deleting(all := false) -> void:
	for id in _deleting.duplicate():
		if all or WorkerThreadPool.is_task_completed(int(id)):
			WorkerThreadPool.wait_for_task_completion(int(id))
			_deleting.erase(id)


func _delete_entry(entry: Dictionary) -> void:
	if entry.status == "running" and int(entry.pid) >= 0:
		Subprocess.terminate(int(entry.pid))
	_entries.erase(entry)
	_remove_away(_files_of(entry))
	if entry.status == "running":
		_running_count -= 1
		_pump_queue()
	#Its row alone goes: rebuilding the other rows is what a delete would otherwise cost.
	var row: Variant = entry.get("_row")
	if _expanded and is_instance_valid(row):
		(row as Control).queue_free()
		_refresh_head()
		call_deferred("_resize_panel")
	else:
		_refresh_list()


## A note an agent is working on or waiting to: never taken by a bulk delete.
static func _at_work(entry: Dictionary) -> bool:
	return String(entry.status) == "running" or String(entry.status) == "queued"


## Every note not at work, in one press: a run under way or waiting stays, since a bulk delete never
## stops an agent mid-edit. The numbered files no remaining note owns go with them (listed now, so a
## note submitted meanwhile is untouched) and are deleted on a worker.
func _delete_all() -> void:
	var kept := _entries.filter(_at_work)
	var keep := {}
	for e in kept:
		keep[int(e.index)] = true
	var dir := ProjectSettings.globalize_path(_feedback_dir())
	var paths := PackedStringArray()
	for fn in DirAccess.get_files_at(dir):
		var num := fn.get_slice(".", 0)
		if num.length() == 4 and num.is_valid_int() and fn.length() > 5 and not keep.has(int(num)):
			paths.append(dir.path_join(fn))
	_entries = kept
	_remove_away(paths)
	_refresh_list()


# --- UI ------------------------------------------------------------------------

const _TOGGLE_SIZE := 40.0
const _TOGGLE_GAP := 4.0 # between the toggle button and the panel above it
const _PANEL_TOP_MARGIN := 28.0 # never crowd closer to the viewport top than this, even when full of entries
## The toggle's own bottom edge: the same -28 margin the export buttons sit on, so they align into one
## row. Their offset_right is pulled in by _TOGGLE_SIZE + _TOGGLE_GAP to leave the toggle the corner.
const _TOGGLE_ROW_BOTTOM := -28.0
## See Chrome.bottom_inset.
var _bottom_inset := 0.0

func _build_ui() -> void:
	#Closed by default: the toggle in the bottom-right corner is the whole UI until clicked; the panel
	#exists on screen only while expanded.
	_toggle_btn = Button.new()
	_toggle_btn.text = "💬"
	_toggle_btn.tooltip_text = "Assistant"
	_toggle_btn.focus_mode = Control.FOCUS_NONE
	_toggle_btn.custom_minimum_size = Vector2(_TOGGLE_SIZE, _TOGGLE_SIZE)
	_toggle_btn.pressed.connect(func():
		_set_expanded(not _expanded))
	#The row's, when this is the Chrome's own Assistant (Chrome.row_button); a --mask-edit Masking session
	#has no Chrome and keeps its own, at the old slot.
	var ch := Chrome.of(self)
	if ch != null and get_parent() == ch:
		#Above the home screen (200), like the row, so the panel and its picker can be seen and clicked. The
		#feedback console closes it when it opens (Chrome.panel_opened).
		layer = Shell.ROW_LAYER - 1
		ch.row_button(&"assistant", _toggle_btn)
		ch.register_panel(&"assistant", func() -> void:
			_expanded = false
			_refresh_list())
	else:
		_toggle_btn.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		_toggle_btn.offset_right = -28
		_toggle_btn.offset_left = -28 - _TOGGLE_SIZE
		_toggle_btn.offset_bottom = _TOGGLE_ROW_BOTTOM
		_toggle_btn.offset_top = _TOGGLE_ROW_BOTTOM - _TOGGLE_SIZE
		add_child(_toggle_btn)

	_panel = PanelContainer.new()
	#BOTTOM_RIGHT (not RIGHT_WIDE) so the panel is a small window above the toggle that grows upward:
	#offset_top and offset_bottom are both measured from the viewport's bottom edge (see _resize_panel).
	_panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_panel.offset_right = -28
	_panel.offset_left = -28 - PANEL_W
	_panel.offset_bottom = _TOGGLE_ROW_BOTTOM - _TOGGLE_SIZE - _TOGGLE_GAP # above the toggle, not overlapping it
	_panel.offset_top = _panel.offset_bottom # sized properly on the first _resize_panel() call
	_panel.visible = false
	add_child(_panel)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 6)
	_panel.add_child(outer)

	_header = Label.new()
	_header.text = "Assistant"
	#Wrap, or a long header reports its full width as a minimum and drags the right-anchored panel off-screen.
	_header.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_header.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0, 0.9))
	_header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	#beside it, Delete all: pressed twice, as every delete that cannot be undone is ([ArmedDelete])
	_head_row = HBoxContainer.new()
	outer.add_child(_head_row)
	_head_row.add_child(_header)
	_delete_all_btn = ArmedDelete.button("Delete all", _delete_all,
		"Delete every note in this list, with its screenshot and conversation - all but a run under way or "
		+ "waiting its turn. Press twice: it cannot be undone.")
	_delete_all_btn.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_head_row.add_child(_delete_all_btn)
	#Godot does not lay out invisible controls, so the deferred _resize_panel() can land while an autowrapped
	#Label is mid-reflow and report an inflated minimum height. Recomputing whenever the minimum size
	#actually changes converges on the true content height.
	_header.minimum_size_changed.connect(_resize_panel)
	_build_backend_pick(outer)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(scroll)

	_list_col = VBoxContainer.new()
	_list_col.add_theme_constant_override("separation", 4)
	_list_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list_col)
	_list_col.minimum_size_changed.connect(_resize_panel)


func _refresh_list() -> void:
	_refresh_head()
	for c in _list_col.get_children():
		c.queue_free()
	#Rows only while the panel is open: building every row at startup and each second a run was under way
	#was most of what the panel cost.
	if not _expanded:
		return
	for e in _entries:
		var row := _build_row(e)
		e._row = row
		_list_col.add_child(row)
	#Deferred: new rows have no layout pass yet, so autowrapped labels report no accurate minimum height.
	call_deferred("_resize_panel")


## What the panel says above its list - the header, the badge, whether Delete all has anything to delete -
## with no row built.
func _refresh_head() -> void:
	var running := 0
	var queued := 0
	for e in _entries:
		if e.status == "running":
			running += 1
		elif e.status == "queued":
			queued += 1
	if AssistantBackends.runnable() == "":
		_header.text = "Feedback (assistant %s - browse/delete only)" \
			% ("off" if AssistantBackends.choice() == "" else "not installed")
	elif running == 0 and queued == 0:
		_header.text = "Assistant"
	else:
		_header.text = "Assistant - %d running, %d queued" % [running, queued]
	#The toggle carries an activity badge even while collapsed.
	_toggle_btn.text = "💬" if running + queued == 0 else "💬 %d" % (running + queued)
	_panel.visible = _expanded
	_delete_all_btn.disabled = not _entries.any(func(e: Dictionary) -> bool: return not _at_work(e))


## Keeps the panel sized to its content (small by default, above the toggle): it grows upward, capped at
## _PANEL_TOP_MARGIN from the top of the screen, beyond which the panel's own ScrollContainer takes over.
func _resize_panel() -> void:
	if not is_instance_valid(_panel):
		return
	var offset_bottom := _TOGGLE_ROW_BOTTOM - _TOGGLE_SIZE - _TOGGLE_GAP - _bottom_inset
	_panel.offset_bottom = offset_bottom
	var viewport_h := get_viewport().get_visible_rect().size.y
	var max_h: float = max(viewport_h + offset_bottom - _PANEL_TOP_MARGIN, 0.0)
	var chrome_h := 0.0
	var style := _panel.get_theme_stylebox("panel")
	if style:
		chrome_h = style.get_minimum_size().y
	var content_h: float = _head_row.get_combined_minimum_size().y + 6.0 \
		+ _backend_row.get_combined_minimum_size().y + 6.0 + _list_col.get_combined_minimum_size().y + chrome_h
	_panel.offset_top = offset_bottom - clamp(content_h, 0.0, max_h)


func _status_glyph(status: String) -> String:
	match status:
		"orphaned": return "○"
		"queued": return "⏳"
		"running": return "⚙"
		"done": return "✓"
		"interrupted": return "↻"
		_: return "✕"


## Neon accent per status, distinct from the near-white body text and from each other, so a title reads
## at a glance even collapsed.
func _title_color(status: String) -> Color:
	match status:
		"running": return Color(0.3, 1.0, 0.85, 0.95) # cyan - alive right now
		"done": return Color(0.55, 1.0, 0.45, 0.95) # green - finished clean
		"interrupted": return Color(1.0, 0.75, 0.25, 0.95) # amber - paused, resumable
		"queued": return Color(0.7, 0.55, 1.0, 0.9) # violet - waiting
		"orphaned": return Color(0.55, 0.6, 0.7, 0.85) # dim - nothing happening yet
		_: return Color(1.0, 0.35, 0.55, 0.95) # pink - error


## How long after a genuine progress change (_poll_progress's _flicker_pulse_at) a title still flickers:
## long enough to land on the next ~1/sec repaint, short enough not to read as a steady state.
const _FLICKER_WINDOW_MS := 1800.0
const _FLICKER_GLYPHS := ["▚", "▞", "░", "▓", "◇", "∴", "≈"]

## Glitches one character of a title: half the time it goes dark, half it flickers to a brighter glyph.
## Never touches the status glyph/index prefix or whitespace/ellipsis.
func _flicker_text(text: String) -> String:
	var candidates: Array = []
	for i in range(text.length()):
		var ch := text[i]
		if ch != " " and ch != "…":
			candidates.append(i)
	if candidates.is_empty():
		return text
	var idx: int = candidates[randi() % candidates.size()]
	var replacement: String = " " if randi() % 2 == 0 else _FLICKER_GLYPHS[randi() % _FLICKER_GLYPHS.size()]
	return text.substr(0, idx) + replacement + text.substr(idx + 1)


func _build_row(entry: Dictionary) -> Control:
	var row := PanelContainer.new()
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	row.add_child(col)

	var head := HBoxContainer.new()
	col.add_child(head)

	var toggle := Button.new()
	toggle.flat = true
	toggle.focus_mode = Control.FOCUS_NONE
	var preview: String = String(entry.query)
	if preview.length() > 40:
		preview = preview.substr(0, 40) + "…"
	#Flicker only while something is happening (a new progress event landed recently).
	var pulsing: bool = String(entry.status) == "running" and \
		(Time.get_ticks_msec() - float(entry.get("_flicker_pulse_at", -_FLICKER_WINDOW_MS * 10.0))) < _FLICKER_WINDOW_MS
	if pulsing:
		preview = _flicker_text(preview)
	toggle.text = "%s #%04d  %s" % [_status_glyph(entry.status), int(entry.index), preview]
	toggle.add_theme_color_override("font_color", _title_color(entry.status))
	toggle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toggle.alignment = HORIZONTAL_ALIGNMENT_LEFT
	#clip_text, or the button's minimum width fits its full text, exceeds the panel's width and pushes the
	#delete button out of the row. SIZE_EXPAND_FILL takes whatever is left after `del` claims its width.
	toggle.clip_text = true
	toggle.pressed.connect(func():
		entry.expanded = not entry.expanded
		_refresh_list())
	head.add_child(toggle)

	var del := Button.new()
	del.text = "✕"
	del.focus_mode = Control.FOCUS_NONE
	del.custom_minimum_size = Vector2(28, 0) # guaranteed footprint regardless of the toggle's width
	del.tooltip_text = "Delete this feedback + conversation"
	del.pressed.connect(func(): _delete_entry(entry))
	head.add_child(del)

	if entry.expanded:
		col.add_child(_build_body(entry))
	return row


func _build_body(entry: Dictionary) -> Control:
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 4)

	var query_lbl := Label.new()
	query_lbl.text = String(entry.query)
	query_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	query_lbl.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0, 0.9))
	body.add_child(query_lbl)

	match String(entry.status):
		"orphaned":
			if AssistantBackends.runnable() != "":
				body.add_child(_dim_label("not sent automatically"))
				body.add_child(_build_send_row(entry))
			else:
				body.add_child(_dim_label("not sent - %s" % AssistantBackends.gap()))
		"queued":
			body.add_child(_dim_label("queued - waiting for the current run to finish"))
		"interrupted":
			body.add_child(_dim_label(String(entry.error_text)))
			body.add_child(_build_resume_row(entry))
		"running":
			var elapsed_s: int = (Time.get_ticks_msec() - int(entry.get("started_at", Time.get_ticks_msec()))) / 1000
			var time_str := "%ds" % elapsed_s if elapsed_s < 60 else Clock.text(float(elapsed_s))
			body.add_child(_dim_label("running (%s)" % time_str))
			var prog := String(entry.get("progress", ""))
			if prog != "":
				var prog_lbl := Label.new()
				prog_lbl.text = "▸ " + prog
				prog_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				prog_lbl.add_theme_color_override("font_color", Color(0.6, 0.85, 0.7, 0.9))
				body.add_child(prog_lbl)
			body.add_child(_build_interrupt_row(entry))
		"done":
			var resp := Label.new()
			resp.text = String(entry.response)
			resp.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			body.add_child(resp)
			#Claude reports dollars; Codex reports tokens and no price. An entry saved before `usage` existed
			#still has its dollar figure.
			var usage := String(entry.get("usage", ""))
			if usage.is_empty():
				usage = "$%.3f" % float(entry.cost_usd)
			var ran := PackedStringArray([Backends.label(_backend_of(entry))])
			for k in ["model", "effort"]:
				if not String(entry.get(k, "")).is_empty():
					ran.append(String(entry[k]))
			body.add_child(_dim_label("%s · %s" % [", ".join(ran), usage]))
			body.add_child(_build_followup_row(entry))
		_:
			var err := Label.new()
			err.text = String(entry.error_text)
			err.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			err.add_theme_color_override("font_color", Color(1.0, 0.6, 0.55, 0.9))
			body.add_child(err)
	return body


func _dim_label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	#These carry long status strings; without wrapping each reports its full one-line width as a minimum and
	#pushes the panel off the screen edge. WORD_SMART also breaks over-long tokens (paths).
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_color_override("font_color", Color(0.6, 0.68, 0.8, 0.8))
	return l


## An orphaned entry moves only once this button is pressed (see _load_existing).
func _build_send_row(entry: Dictionary) -> Control:
	var send := Button.new()
	#Not yet dispatched, so it goes wherever the dropdown points now.
	send.text = "Send to %s" % Backends.label(_backend_of(entry))
	send.focus_mode = Control.FOCUS_NONE
	send.pressed.connect(func():
		entry.status = "queued"
		_save_entry(entry)
		_refresh_list()
		_pump_queue())
	return send


## A completed conversation stays resumable: the follow-up is sent via --resume against entry.session_id
## (see _dispatch).
func _build_followup_row(entry: Dictionary) -> Control:
	var row := HBoxContainer.new()
	var edit := LineEdit.new()
	edit.placeholder_text = "follow up..."
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	#_refresh_list() rebuilds every row when any entry's status changes; the draft is stashed on the entry
	#so that rebuild does not wipe what someone is typing.
	edit.text = String(entry.get("draft_followup", ""))
	edit.text_changed.connect(func(t): entry.draft_followup = t)
	row.add_child(edit)
	var send := Button.new()
	send.text = "Send"
	send.focus_mode = Control.FOCUS_NONE
	var missing := _missing_cli(entry)
	send.disabled = not missing.is_empty()
	if not missing.is_empty():
		send.tooltip_text = missing + " - a follow-up continues that CLI's own session"
	#The same queue as a fresh submission (enqueue/_pump_queue), which starts it at once.
	send.pressed.connect(func():
		var text := edit.text.strip_edges()
		if text.is_empty():
			return
		entry.status = "queued"
		entry.response = ""
		entry.pending_prompt = text
		entry.draft_followup = ""
		_entries.erase(entry)
		_entries.push_front(entry)
		_save_entry(entry)
		_refresh_list()
		_pump_queue())
	#emitting `pressed` by hand bypasses `disabled`, so Enter asks it too
	edit.text_submitted.connect(func(_t):
		if not send.disabled:
			send.pressed.emit())
	row.add_child(send)
	return row


## Halts a live run without discarding it (unlike _delete_entry, which also wipes the feedback record).
## Kills the subprocess; _finish then turns a run with a known session_id into "interrupted", the state
## _build_resume_row continues via --resume. The id is captured by _poll_progress at the first event.
func _interrupt_entry(entry: Dictionary) -> void:
	if entry.status != "running" or int(entry.pid) < 0:
		return
	Subprocess.terminate(int(entry.pid))


func _build_interrupt_row(entry: Dictionary) -> Control:
	var row := HBoxContainer.new()
	var stop := Button.new()
	stop.text = "⏸  Interrupt"
	stop.focus_mode = Control.FOCUS_NONE
	stop.tooltip_text = "Halt this run now so you can add context and resume it"
	stop.pressed.connect(func(): _interrupt_entry(entry))
	row.add_child(stop)
	return row


## Resume an interrupted run: re-queue it against its saved session_id so --resume picks up the same
## session (see _dispatch). An optional typed note is folded into the resume prompt; blank falls back to
## the plain "pick up where you left off" prompt.
func _build_resume_row(entry: Dictionary) -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)

	var row := HBoxContainer.new()
	var edit := LineEdit.new()
	edit.placeholder_text = "extra context for the resume (optional)..."
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	#Draft stash, as in _build_followup_row.
	edit.text = String(entry.get("draft_resume", ""))
	edit.text_changed.connect(func(t): entry.draft_resume = t)
	row.add_child(edit)

	var resume := Button.new()
	resume.text = "↻  Resume"
	resume.focus_mode = Control.FOCUS_NONE
	resume.tooltip_text = "Continue the same %s session (%s) where it left off" \
		% [Backends.label(_backend_of(entry)), String(entry.session_id)]
	var missing := _missing_cli(entry)
	resume.disabled = not missing.is_empty()
	if not missing.is_empty():
		resume.tooltip_text = missing + " - a resume continues that CLI's own session"
	var do_resume := func():
		var extra := edit.text.strip_edges()
		var prompt := "The previous run was interrupted before finishing."
		if extra != "":
			prompt += " The user has additional context: \"%s\"" % extra
		prompt += " Please pick up exactly where you left off and complete the work."
		entry.status = "queued"
		entry.response = ""
		entry.error_text = ""
		entry.pending_prompt = prompt
		entry.draft_resume = ""
		_entries.erase(entry)
		_entries.push_front(entry)
		_save_entry(entry)
		_refresh_list()
		_pump_queue()
	resume.pressed.connect(do_resume)
	edit.text_submitted.connect(func(_t):
		if not resume.disabled:
			do_resume.call())
	row.add_child(resume)

	col.add_child(row)
	return col


## Lift the toggle - and the panel above it - clear of whatever the mode has put along the bottom of the
## frame. See Chrome.bottom_inset.
func set_bottom_inset(v: float) -> void:
	_bottom_inset = v
	if _toggle_btn != null and _toggle_btn.get_parent() == self:      # in the row, the row moves it
		_toggle_btn.offset_bottom = _TOGGLE_ROW_BOTTOM - v
		_toggle_btn.offset_top = _TOGGLE_ROW_BOTTOM - _TOGGLE_SIZE - v
	_resize_panel()


## Open or close the panel - one panel above the row at a time (Chrome.panel_opened).
func _set_expanded(on: bool) -> void:
	_expanded = on
	var ch := Chrome.of(self)
	if ch != null and get_parent() == ch:
		if on:
			ch.panel_opened(&"assistant")
		else:
			ch.panel_closed(&"assistant")
	_refresh_list()


# --- which assistant runs (it was the home screen's dropdown) ---------------------------------

const ASSIST_TIP := "Feedback left with ` gets handed to this, one-shot, the moment you submit it."
const INSTALL_HINT := ("Install one or several of them, then press rescan in the Environment panel "
	+ "(⚙). Click an agent's row there for the command that installs it.")

## The writers' own row ([method AgentPick.assistant]): Off or an agent, its model and its level - the
## agent stored as its name in `[assistant] backend`, never a row number.
var _pick: AgentPick
var _backend_row: Control           # the row, measured by _resize_panel
## The agent picker of the row: what a gate drives, and what says why nothing can run.
var _backend_pick: OptionButton


## The picker lives in this panel, its only user (next/notes.md): a --mask-edit Masking session has no
## home screen to reach it from.
func _build_backend_pick(parent: Control) -> void:
	_pick = AgentPick.assistant(ASSIST_TIP)
	_backend_row = _pick
	_backend_pick = _pick.agents
	parent.add_child(_pick)
	var backend := String(Settings.read("assistant", "backend", ""))
	#A Claude chosen before there was a model to choose ran Sonnet, and still does until another is picked
	_pick.set_choice(backend, String(Settings.read("assistant", "model", "sonnet" if backend == "claude_cli" else "")),
		String(Settings.read("assistant", "effort", "")))
	_pick.changed.connect(func() -> void:
		var c := _pick.choice()
		for k in ["model", "effort"]:
			Settings.write("assistant", k, String(c[k]))
		Settings.write("assistant", "backend", String(c["agent"]))
		_refresh_list())
	_refresh_backend_pick()
	# A rescan after installing a CLI lights its row up without a restart.
	var ch := Chrome.of(self)
	if ch != null and ch.environment != null:
		ch.environment.probed.connect(_refresh_backend_pick)


## Gray out the assistants that cannot run: a CLI that is not installed is listed but not choosable, and
## with none installed the whole picker is ([method AssistantBackends.runnable] reads as Off everywhere).
## The stored choice is never rewritten, so it comes back when its CLI is found.
func _refresh_backend_pick() -> void:
	_pick.mark_available()
	var have := AssistantBackends.installed()
	_backend_pick.disabled = have.is_empty()
	var gap := AssistantBackends.gap()
	if have.is_empty():
		var names: Array = Backends.REGISTRY.keys().map(
			func(k: String) -> String: return Backends.label(k).replace(" ", "\u00a0"))
		_backend_pick.tooltip_text = "\n\n".join(PackedStringArray([
			"No AI assistant is installed, so a note left with ` is only logged.",
			"Supported assistants: %s." % Capabilities.join_words(names, "and"), INSTALL_HINT]))
	elif not gap.is_empty() and not AssistantBackends.choice().is_empty():
		_backend_pick.tooltip_text = "%s\n\n%s, so a note is only logged. Pick another, or install it." \
			% [ASSIST_TIP, gap.left(1).to_upper() + gap.substr(1)]
	else:
		_backend_pick.tooltip_text = ASSIST_TIP
	(_pick.get_child(0) as Label).add_theme_color_override("font_color",
		COL_USES if have.is_empty() else Color(0.55, 0.62, 0.75))
