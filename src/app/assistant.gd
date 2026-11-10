extends CanvasLayer
class_name Assistant

## The muted caption under the picker - the home screen's caption color, which it borrowed.
const COL_USES := Color(0.42, 0.48, 0.58)

## Assistant - the feedback browser, and (opt-in) tight Claude Code integration.
##
## This node exists unconditionally (see main.gd / mask_editor.gd) - it is
## ALSO the only UI for reviewing and deleting old feedback console
## submissions (see feedback.gd), which has nothing to do with AI dispatch and
## shouldn't require opting into it.
##
## Dispatch itself is gated on the Assistant's own picker (in its panel) AND on that CLI being
## installed ([method AssistantBackends.runnable] reads as Off without it; a follow-up or resume
## needs its own pinned CLI):
## set to anything but Off, every feedback submission is
## immediately handed to a fresh `claude -p --dangerously-skip-permissions`
## subprocess - the same one-shot workflow already used interactively all
## session, just wired to fire the moment feedback lands instead of waiting
## for a human to notice and paste it in. THE AGENT, ITS MODEL AND ITS LEVEL are chosen on the
## writers' own row ([method AgentPick.assistant], 2026-11-07), and each run takes what the row says.
## Codex CLI (OpenAI) and the Grok Build CLI are the others; what differs
## between them (command line, resume, event stream, cost) lives in
## [AssistantBackends], and each entry remembers which one started it so a
## follow-up never lands on a different CLI's session. With it set to Off, submissions still
## show up (status "orphaned") so they stay reviewable/deletable - they just
## never get sent anywhere on their own.
##
## EVERY SUBMISSION STARTS AT ONCE, however many are running (the user, 2026-11-09: "I don't understand why assistant sessions
## are limited ... that gate was forcing me to wait for one session to finish for the next to even start" - three at a time had
## held the rest queued). Each is a fresh, permission-bypassed agent editing the SAME working tree, so two runs CAN land
## conflicting edits on the same file - each dispatch prompt tells the agent to scope its edit narrowly rather than roam,
## precisely so concurrent runs mostly land on different files.
##
## Conversations persist to feedback/NNNN.assistant.json (paired with the
## feedback console's own NNNN.json/.png) so they survive an app restart, and
## each is resumable: once a run completes, a typed follow-up continues the
## SAME claude session via --resume, not a fresh one - a real back-and-forth,
## not a one-shot fire-and-forget log.
##
## UI lives bottom-right, in the SAME row as the export button (see
## mask_editor.gd / exporter.gd's shared "Export video" button), right of it,
## right in the corner - CLOSED by default: a chat-bubble toggle button is the
## only thing on screen until clicked, carrying an activity badge ("💬 2")
## when something's running/queued so there's a hint without opening it.
## Expanded, it's a scrollable list of entries, each expandable to show the
## full exchange, with a delete button per entry. Both export buttons leave
## room for it (see their own offset_right) - the two live side by side by
## construction, not by coincidence, so don't move one without the other.

const DIR := "res://feedback"
## WHERE THE NOTES ARE, for a gate: a folder of its own, never the author's (EVERY TEST IS READ-ONLY). "" is the app's.
static var root := ""


static func _feedback_dir() -> String:
	if not root.is_empty():
		return root
	return DIR if OS.has_feature("editor") else "user://feedback"
const PANEL_W := 380
## A GATE'S HOLD: while set, nothing queued is started (a check that looks at a queue without running agents). Never set by the app.
var hold := false

## The pure half: per-backend command lines and stream parsing. Preloaded rather than
## named by class so a headless run never depends on the class cache being fresh.
const Backends := preload("res://src/agents/assistant_backends.gd")

var _repo_root := ""

var _entries: Array = [] # Array[Dictionary], newest first - see enqueue()
var _running_count := 0 # how many entries are actively running right now
var _timer_tick := 0.0 # throttles the running-entry elapsed-timer repaint to ~1/sec
## Set the instant the app starts closing (see _notification). Once true, _process
## stops polling dispatched child PIDs: on shutdown Godot reaps/kills the children it
## created, and a same-frame OS.is_process_running() call then races that reap on the
## SAME pid - both waitpid(), the loser gets ECHILD (errno 10), which faults during
## teardown ("crash on normal close"). Dispatched claude runs are meant to outlive the
## editor anyway (they write straight to the working tree), so simply not observing
## them past close is correct, not a leak.
var _closing := false

var _panel: Control
var _list_col: VBoxContainer
var _header: Label
var _head_row: HBoxContainer        # the header and its Delete all
var _delete_all_btn: Button
var _toggle_btn: Button
var _expanded := false # closed by default - see _build_ui


## A restart requested (by the editor's F5, or auto after a run edits code) but held
## until every agent has returned - restarting mid-run would corrupt another agent's
## in-progress edits. Fired by _maybe_reload the moment we go idle.
var _pending_reload: Callable = Callable()


func _ready() -> void:
	add_to_group("assistant") # the mask editor asks us to defer its reload until idle
	layer = 126 # below the feedback console itself (128), above ordinary scene UI
	_resolve_repo_root()
	_ensure_dir()
	_build_ui()
	_load_existing()
	_refresh_list()


## The real binary for a backend - PATH when Godot is launched from a GUI entry (vs. a
## shell) doesn't always match an interactive shell's PATH, so resolve it rather than
## assume the bare name works. [Deps] is the app-wide answer to that, and the home
## screen's Environment panel reports the same one.
func _bin_for(backend: String) -> String:
	var bin := Backends.dep(backend)
	var path := Deps.resolve(bin)
	return path if not path.is_empty() else bin


## Which CLI an entry belongs to. Recorded when it is first dispatched and never changed
## after, because a session id only means something to the CLI that issued it; an entry
## saved before backends were recorded was Claude's.
func _backend_of(entry: Dictionary) -> String:
	var b := String(entry.get("backend", ""))
	if Backends.has(b):
		return b
	var chosen := AssistantBackends.choice()
	return chosen if Backends.has(chosen) else Backends.LEGACY


## "" when the CLI this entry runs on is installed, else "<that CLI> is not installed". A
## follow-up or resume is pinned to the CLI that started it, so it is THAT one's presence that
## counts, whatever the dropdown says now.
func _missing_cli(entry: Dictionary) -> String:
	var b := _backend_of(entry)
	return "" if AssistantBackends.installed().has(b) else "%s is not installed" % Backends.label(b)


## ghost's project root IS the repository (ghost-notes), so the subprocess runs from
## res:// and sees the same CLAUDE.md / git context an interactive session would.
func _resolve_repo_root() -> void:
	_repo_root = Boot.project_dir().simplify_path()


func _ensure_dir() -> void:
	var dir := ProjectSettings.globalize_path(_feedback_dir())
	if not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)
	# KEPT OUT OF GODOT'S SCAN: under res:// an editor scan (and the parse gate's `--editor --quit`) imported every
	# screenshot as a texture, and a deleted note left its `.png.import` behind (63 of them, 2026-11-07). Nothing loads
	# a note's files as resources: an agent reads them from disk.
	# (never from a test: a gate writes nothing of the author's)
	var ignore := dir.path_join(".gdignore")
	if _feedback_dir().begins_with("res://") and not FileAccess.file_exists(ignore) \
			and not Settings.is_read_only() and not Settings.is_probe_launch(OS.get_cmdline_args()):
		var f := FileAccess.open(ignore, FileAccess.WRITE)
		if f != null:
			f.close()


# --- public API ----------------------------------------------------------------

## Called by whoever owns the FeedbackConsole (main.gd / mask_editor.gd) right
## after it writes feedback/NNNN.json - see feedback.gd's `submitted` signal.
## Fires this instant ONLY if the console's Ask box was on ([param ask]) AND the
## Assistant's picker actually has a backend selected; otherwise the
## entry is still listed (this node exists unconditionally now - see
## main.gd/mask_editor.gd - specifically so old feedback stays browsable/deletable
## without opting into AI dispatch), it just never gets sent anywhere on its own.
## That is the "orphaned" state, with its Send button.
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


## Whether a submission is dispatched the moment it lands: the console's Ask box was on and a
## backend is chosen. Anything else is only listed.
static func sends(ask: bool, backend: String) -> bool:
	return ask and backend != ""


# --- dispatch --------------------------------------------------------------------

## Anything still running OR waiting to run - the window during which a restart would
## clobber an agent's edits.
func is_busy() -> bool:
	if _running_count > 0:
		return true
	for e in _entries:
		if e.status == "queued":
			return true
	return false


## Defer a restart until every agent has returned. Fires immediately if already idle,
## otherwise held and fired by _maybe_reload once the last run finishes.
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
	# Don't yank the reload out from under someone mid-critique - hold it until the
	# feedback console closes (submit or cancel), same deference main.gd's
	# _end_session gives it for session teardown.
	var fc := get_tree().get_first_node_in_group("feedback_console")
	if fc != null and is_instance_valid(fc) and fc.is_open():
		if not fc.closed.is_connected(_maybe_reload):
			fc.closed.connect(_maybe_reload, CONNECT_ONE_SHOT)
		return
	var cb := _pending_reload
	_pending_reload = Callable()
	cb.call()


## Newest modification time across ghost's own source (src/ + shaders/, subfolders
## included - a fix to a scene or a medium is a code edit too). A dispatch records this at
## start (see _dispatch); if it's higher at _finish, that run edited code and the app
## should reload to pick it up.
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


## `prompt` is either the initial dispatch prompt (built from the feedback
## record) or a typed follow-up - either way it lands on the SAME claude
## session once `entry.session_id` is set, via --resume.
func _dispatch(entry: Dictionary, prompt: String) -> void:
	# NEVER LAUNCH A CLI THAT IS NOT THERE. The buttons that queue a run are grayed out without
	# it, so this is the backstop: a failed launch leaves a resumable conversation as a dead
	# "error". It is parked where its own button picks it up again once the CLI is installed.
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
	# A RUN READS ONLY ITS OWN STREAM. A run the app died under leaves its files behind (_finish
	# never ran), and feedback numbering restarts, so a new run can share their name. The shell
	# truncates them once it gets going - but this frame's _poll_progress can open the old one
	# first and read it as this run's, or read it short as the shell cuts it ("Condition
	# r != len" from get_as_text, the first poll after a submission).
	_delete_file(entry.out_path)
	_delete_file(entry.err_path)
	# Pinned on first dispatch: a follow-up or resume must reach the SAME CLI whatever the
	# dropdown says now.
	var backend := _backend_of(entry)
	entry.backend = backend
	var run := _run_for(entry, prompt_path)
	# The run's stdout is a stream of JSON events, one per line, as they happen - never a
	# single blob at the end, which gave NOTHING to show for however long the fix took.
	# _poll_progress tails it each frame for a live "what's it doing" line; _finish reads
	# the whole thing once the process exits.
	#
	# The prompt reaches the CLI on stdin, from a file - never argv, never shell source (see
	# AssistantBackends). Detached: the run edits the working tree and is meant to finish
	# after the editor closes.
	var pf := FileAccess.open(prompt_path, FileAccess.WRITE)
	if pf != null:
		pf.store_string(prompt)
		pf.close()
	var cli := Backends.argv(backend, _bin_for(backend), String(entry.session_id), _repo_root, run)
	entry.pid = Subprocess.start_redirected(cli[0], cli.slice(1), {"cwd": _repo_root,
		"stdin": prompt_path, "out": entry.out_path, "err": entry.err_path}, "", true) \
		if pf != null else -1
	if int(entry.pid) < 0:
		# create_process failed outright (bad binary, spawn error) - without
		# this, the entry would sit at "running" forever: _process()'s poll
		# only ever calls _finish() when is_process_running() sees an ACTUAL
		# pid, and a negative one never satisfies that, so nothing would ever
		# notice or unblock the queue.
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


## WHAT A RUN OF [param entry] TAKES ([method AssistantBackends.argv]'s `run`), on the CLI pinned to it: the picker's model
## and level while the picker names that CLI, else what the entry last ran on - kept on it, so a follow-up after the
## picker moved to another agent still runs as it did. Grok is handed the id a fresh run takes: its opening event has none.
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


## Mirrors exactly how this whole session actually worked: point the fresh
## session at the feedback record + screenshot and let it read them itself,
## rather than trying to pre-digest the state into the prompt (the record
## already carries the full resolved layer stack, markers, and playhead - it
## IS the context).
##
## CLAUDE.md is named explicitly (not left to auto-discovery)
## because a real dispatched run (feedback 0055) burned a huge chunk of a
## 10-minute session re-deriving ghost's file layout, the effect-registry
## pattern, and the "shader edits need a real GPU compile, not just
## --editor --quit" rule from scratch via grep, all of which that file now
## states up front - forcing an explicit read is one line and removes any
## doubt about whether a -p session picks up a subdirectory CLAUDE.md on
## its own before it starts reading files.
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


## WM_CLOSE_REQUEST propagates to every node when the main window is asked to close;
## EXIT_TREE/PREDELETE cover the programmatic-quit paths. Latching here (before the
## same frame's _process runs) is what stops the shutdown ECHILD race - see _closing.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_EXIT_TREE \
			or what == NOTIFICATION_PREDELETE:
		_closing = true
		# a note's files being deleted are finished, never abandoned half-way
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
	# The elapsed timer + progress line only need to repaint about once a
	# second, not every frame - rebuilding the whole list is real UI work,
	# and nobody's watching closely enough for sub-second granularity anyway.
	if any_running:
		_timer_tick += _dt
		if _timer_tick >= 1.0:
			_timer_tick = 0.0
			_refresh_list()


## Tails entry.out_path for newly-written, COMPLETE stream-json lines (a
## partial trailing line - still being written - is left for the next poll)
## and keeps entry.progress pointed at the most recent meaningful event, so
## the UI has something honest to show while a run is still in flight instead
## of a bare "running..." with no sign of life (see _dispatch's stream-json
## switch - this is the whole reason for it).
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
			# Persist the session id the INSTANT it first appears (Claude's init event,
			# Codex's thread.started), not only at _finish - so a run interrupted by a
			# crash still has a saved id and can be resumed later (see _load_existing).
			if String(entry.session_id) == "":
				var sid := Backends.session_of(_backend_of(entry), evt)
				# a run handed its id (Grok) has it once it has said something
				if sid == "" and String(evt.get("type", "")) == "assistant":
					sid = String(entry.get("fresh", ""))
				if sid != "":
					entry.session_id = sid
					_save_entry(entry)
			var desc := Backends.describe(_backend_of(entry), evt)
			if desc != "" and desc != String(entry.get("progress", "")):
				# Marks the moment the underlying agent actually did something new -
				# _build_row uses this to flicker the collapsed title briefly, a
				# small "sign of life" visible even in a long collapsed list.
				entry._flicker_pulse_at = Time.get_ticks_msec()
			if desc != "":
				entry.progress = desc


## Dig a session id out of a captured output/error blob when the field itself was
## never saved (an interrupted run).
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
		# The run produced no clean result, but it may still have a session id (it got
		# far enough to emit its first event). If so it's RESUMABLE, not a dead end.
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
	# If this run actually edited ghost's own code, arrange a restart to pick it up -
	# held by reload_when_idle until any OTHER still-running agents also return, so no
	# restart ever lands mid-edit. Routed through _reload_requested (not _do_restart
	# directly) so it also defers to an in-flight export (see that method's doc,
	# feedback/0027) - reload_when_idle only knows about other assistant runs.
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


## Conversations from a prior run of the app - rebuilt from the persisted
## summaries (see _save_entry). A run that was still queued/running when the
## app last closed never got to finish; the subprocess died with the editor,
## so that's surfaced honestly as an error rather than silently vanishing or
## claiming to still be "running" forever.
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
		# No key = saved before backends were recorded, which means Claude.
		var backend := str(data.get("backend", ""))
		if not Backends.has(backend):
			backend = Backends.LEGACY
		if sid == "":
			sid = _recover_session_id(error_text, backend) # older logs stashed the init event in error_text
		# A run that was mid-flight when the editor closed (or errored without a clean
		# result) is resumable IF we know its session id - continue it via --resume
		# rather than starting over. Only a run we can't identify is a dead "error".
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
	# Orphaned feedback: a NNNN.json with no matching NNNN.assistant.json - left
	# behind by a submission made before the Assistant dropdown was ever set to
	# anything but Off. LISTED, never auto-dispatched: a feedback console left
	# running for a while can easily have DOZENS of these built up (this is not
	# hypothetical - it happened, and enqueuing all of them at once meant a
	# real subprocess firing off against ancient feedback the instant the
	# assistant was ever turned on, with nothing to review or stop it - the
	# same mistake --dangerously-skip-permissions makes if it fires without
	# anyone asking it to). Each one needs its own deliberate click (see the
	# "orphaned" status in _build_body) before anything runs.
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
# (2026-11-07, the user: "We can delete them individually now, but that can be very slow ... It blocks the main thread to
# do that.") MEASURED, the disk was never it: a note's files go in under a millisecond, and the second was the list built
# again - every row, and every symbol on a row (○ ✓ ✕) a system font search of 5-8 ms (Boot.lend_symbol_fonts ends that).
# Now the rows are built only while the panel is open, a note leaves the list at once, and its files go on a worker.

## The deleting under way: WorkerThreadPool task ids, each waited for once it is done (_process) or as the app closes.
var _deleting: Array = []


## THE FILES OF [param entry], absolute: its record and screenshot (and the screenshot's import file, from before the folder
## carried a .gdignore), its conversation, and a run's stream, error log and prompt - by its number, for an entry loaded
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
	# ITS ROW ALONE GOES: the other rows built again were the rest of what a delete cost
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


## EVERY NOTE NOT AT WORK, IN ONE PRESS (the user: "can we add a button to delete all entries in the assistant feedback
## list?"): a run under way or waiting its turn stays, for a bulk delete never stops an agent mid-edit. The numbered files
## no remaining note owns go with them - an old screenshot's import file too - listed now, so a note submitted while they
## are deleted is never touched, and deleted on a worker.
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
## The toggle's own bottom edge - the same -28 margin mask_editor.gd's/exporter.gd's
## "Export video" button sits on, so the two align into one visual row. The export
## buttons' own offset_right is pulled in by _TOGGLE_SIZE + _TOGGLE_GAP to leave the
## toggle room at the true corner, right of them - see this file's class doc.
const _TOGGLE_ROW_BOTTOM := -28.0
## See Chrome.bottom_inset.
var _bottom_inset := 0.0

func _build_ui() -> void:
	# Closed by default - a chat-bubble toggle sitting in the viewport's very
	# bottom-right corner, right of the export button in the same row (see
	# _TOGGLE_ROW_BOTTOM's doc), is the whole UI until clicked; the panel
	# itself only exists on screen while expanded.
	_toggle_btn = Button.new()
	_toggle_btn.text = "💬"
	_toggle_btn.tooltip_text = "Assistant"
	_toggle_btn.focus_mode = Control.FOCUS_NONE
	_toggle_btn.custom_minimum_size = Vector2(_TOGGLE_SIZE, _TOGGLE_SIZE)
	_toggle_btn.pressed.connect(func():
		_set_expanded(not _expanded))
	# THE ROW'S, when this is the Chrome's own Assistant (Chrome.row_button); a Masking session
	# launched with --mask-edit has no Chrome and keeps its own, at the old slot.
	var ch := Chrome.of(self)
	if ch != null and get_parent() == ch:
		# ABOVE THE HOME SCREEN (200), like the row: on 126 this panel - and the picker it holds
		# now - opened under the home screen, where no one could see or click it. The feedback
		# console it used to sit under closes it when it opens (Chrome.panel_opened).
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
	# BOTTOM_RIGHT (not RIGHT_WIDE) so the panel sits as a small window above
	# the toggle by default and only grows upward as its content needs more
	# room - see _resize_panel(), called after every _refresh_list(). Both
	# offset_top and offset_bottom end up measured from the viewport's
	# bottom edge this way, which is what lets offset_top move up (more
	# negative) as content grows instead of being pinned near the top.
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
	# Wrap, or a long header ("Feedback (assistant off - browse/delete only)")
	# reports its full text width as a minimum and drags the right-anchored panel
	# off-screen to the right (the panel grows to its content's minimum size).
	_header.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_header.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0, 0.9))
	_header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# beside it, DELETE ALL: pressed twice, as every delete that cannot be undone is ([ArmedDelete])
	_head_row = HBoxContainer.new()
	outer.add_child(_head_row)
	_head_row.add_child(_header)
	_delete_all_btn = ArmedDelete.button("Delete all", _delete_all,
		"Delete every note in this list, with its screenshot and conversation - all but a run under way or "
		+ "waiting its turn. Press twice: it cannot be undone.")
	_delete_all_btn.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_head_row.add_child(_delete_all_btn)
	# The panel starts (and often sits) invisible/collapsed, and Godot doesn't run
	# layout on invisible controls - so the deferred _resize_panel() call below can
	# land while an autowrapped Label is still mid-reflow (a transient near-zero
	# wrap width briefly reports a wildly inflated minimum height), pinning the
	# panel's height to that bogus value with nothing left to ever correct it.
	# Recomputing whenever the real minimum size actually changes (e.g. once the
	# panel becomes visible and reflows for real) keeps it converging on the true
	# content height instead of getting stuck on a stale bad reading.
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
	# ROWS ONLY WHILE THE PANEL IS OPEN: closed, the list is the entries alone - building every row at startup, and again
	# each second a run was under way, was most of what this panel cost
	if not _expanded:
		return
	for e in _entries:
		var row := _build_row(e)
		e._row = row
		_list_col.add_child(row)
	# Deferred: freshly added rows haven't had a layout pass yet, so their
	# autowrapped labels don't report an accurate minimum height until next
	# idle frame.
	call_deferred("_resize_panel")


## What the panel says above its list - the header, the 💬's badge, whether Delete all has anything to delete - with no
## row built.
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
	# The toggle carries an activity badge even while collapsed, so something
	# running/queued is still visible without opening the panel.
	_toggle_btn.text = "💬" if running + queued == 0 else "💬 %d" % (running + queued)
	_panel.visible = _expanded
	_delete_all_btn.disabled = not _entries.any(func(e: Dictionary) -> bool: return not _at_work(e))


## Keeps the panel sized to its actual content (small by default, above the
## toggle) instead of permanently stretched to the viewport height - it only
## grows upward, capped so it never crowds past _PANEL_TOP_MARGIN from the
## top of the screen, beyond which the panel's own ScrollContainer takes
## over instead of the panel itself continuing to grow.
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


## Neon accent per status - distinct from both the desaturated near-white body
## text (see _build_body/_dim_label) and each other, so a title reads at a
## glance even collapsed. Saturated on purpose ("neon sign"), not just tinted.
func _title_color(status: String) -> Color:
	match status:
		"running": return Color(0.3, 1.0, 0.85, 0.95) # cyan - alive right now
		"done": return Color(0.55, 1.0, 0.45, 0.95) # green - finished clean
		"interrupted": return Color(1.0, 0.75, 0.25, 0.95) # amber - paused, resumable
		"queued": return Color(0.7, 0.55, 1.0, 0.9) # violet - waiting
		"orphaned": return Color(0.55, 0.6, 0.7, 0.85) # dim - nothing happening yet
		_: return Color(1.0, 0.35, 0.55, 0.95) # pink - error


## How long after a genuine progress change (see _poll_progress's
## _flicker_pulse_at) a title still shows the flicker - long enough to land on
## the very next ~1/sec repaint (_process), short enough to read as a flicker,
## not a steady state.
const _FLICKER_WINDOW_MS := 1800.0
const _FLICKER_GLYPHS := ["▚", "▞", "░", "▓", "◇", "∴", "≈"]

## Glitches ONE character of a title - half the time it just goes dark (a
## neon sign losing a letter), half the time it flickers to a brighter glyph.
## Never touches the status glyph/index prefix (see _build_row) or whitespace/
## ellipsis, so the title stays legible, just alive.
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
	# Only flicker while something is actually happening (a real, new progress
	# event landed recently) - see _poll_progress's _flicker_pulse_at. This is
	# what makes it read as "life", not a distracting constant twitch.
	var pulsing: bool = String(entry.status) == "running" and \
		(Time.get_ticks_msec() - float(entry.get("_flicker_pulse_at", -_FLICKER_WINDOW_MS * 10.0))) < _FLICKER_WINDOW_MS
	if pulsing:
		preview = _flicker_text(preview)
	toggle.text = "%s #%04d  %s" % [_status_glyph(entry.status), int(entry.index), preview]
	toggle.add_theme_color_override("font_color", _title_color(entry.status))
	toggle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toggle.alignment = HORIZONTAL_ALIGNMENT_LEFT
	# Without this, a Button's minimum width is sized to fit its FULL text -
	# a 40-character preview easily exceeds the whole panel's width, and the
	# HBoxContainer has no way to shrink it back down. That doesn't just crowd
	# the delete button, it pushes it out of the row's allocated width
	# entirely - invisible even though nothing is actually "off-screen" in the
	# window sense. clip_text lets the button truncate instead of demanding
	# the space, which is the whole reason SIZE_EXPAND_FILL is on it - it's
	# supposed to take whatever's left AFTER `del` claims its own width, not
	# force everything else out of the way to fit uncropped.
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
			# Claude reports dollars; Codex reports tokens and no price. An entry saved before
			# `usage` existed still has its dollar figure.
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
	# These carry the long status strings ("running (12s) - output is captured
	# here, never printed to a terminal", "no assistant selected - pick one on the
	# home screen to send this"). Without wrapping, each reports its full one-line
	# width as a minimum and pushes the right-anchored panel off the screen edge -
	# WORD_SMART also breaks over-long tokens (paths) so nothing overflows.
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_color_override("font_color", Color(0.6, 0.68, 0.8, 0.8))
	return l


## An orphaned entry only ever moves once THIS button is pressed - see
## _load_existing's class doc for why nothing here fires on its own.
func _build_send_row(entry: Dictionary) -> Control:
	var send := Button.new()
	# Not yet dispatched, so it goes wherever the dropdown points now.
	send.text = "Send to %s" % Backends.label(_backend_of(entry))
	send.focus_mode = Control.FOCUS_NONE
	send.pressed.connect(func():
		entry.status = "queued"
		_save_entry(entry)
		_refresh_list()
		_pump_queue())
	return send


## A completed conversation stays resumable - the follow-up is sent via
## --resume against entry.session_id (see _dispatch), a genuine continuation
## of the same claude session, not a fresh one that's forgotten everything.
func _build_followup_row(entry: Dictionary) -> Control:
	var row := HBoxContainer.new()
	var edit := LineEdit.new()
	edit.placeholder_text = "follow up..."
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# _refresh_list() rebuilds EVERY row whenever any entry's status changes
	# (a different entry finishing running, say) - without stashing the draft
	# on the entry itself, that rebuild would wipe out whatever someone was
	# mid-typing here for a completely unrelated conversation.
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
	# Goes through the SAME queue as a fresh submission (see
	# enqueue/_pump_queue), which starts it at once.
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
	# emitting `pressed` by hand bypasses `disabled`, so Enter asks it too
	edit.text_submitted.connect(func(_t):
		if not send.disabled:
			send.pressed.emit())
	row.add_child(send)
	return row


## Halts a live run without discarding it (unlike _delete_entry, which also wipes
## the feedback record). Kills the subprocess and lets the normal _process()/
## _finish() polling notice it exited next frame - _finish already turns a run
## with a known session_id into "interrupted" (the same state a crash or app-close
## leaves behind), which is exactly the state _build_resume_row below knows how to
## continue via --resume. session_id is usually already captured by then (
## _poll_progress persists it the instant the run's first stream-json event
## arrives), so an interrupt reliably lands on "interrupted", not a dead "error".
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


## Resume an interrupted run: re-queue it against its saved session_id so --resume
## picks up the SAME claude session where it left off (see _dispatch). An optional
## typed note - e.g. context that changed while the run was halted - is folded into
## the resume prompt; left blank, it falls back to the plain "pick up where you left
## off" prompt. Same queue as any other dispatch.
func _build_resume_row(entry: Dictionary) -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)

	var row := HBoxContainer.new()
	var edit := LineEdit.new()
	edit.placeholder_text = "extra context for the resume (optional)..."
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Same reasoning as _build_followup_row's draft stash - _refresh_list() rebuilds
	# every row whenever any entry's status changes, so an in-progress note here
	# would otherwise vanish the moment an unrelated entry finishes.
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


## Lift the toggle - and the panel that opens above it - clear of whatever the
## mode has put along the bottom of the frame. See Chrome.bottom_inset.
func set_bottom_inset(v: float) -> void:
	_bottom_inset = v
	if _toggle_btn != null and _toggle_btn.get_parent() == self:      # in the row, the row moves it
		_toggle_btn.offset_bottom = _TOGGLE_ROW_BOTTOM - v
		_toggle_btn.offset_top = _TOGGLE_ROW_BOTTOM - _TOGGLE_SIZE - v
	_resize_panel()


## Open or close the panel - ONE PANEL ABOVE THE ROW AT A TIME (Chrome.panel_opened).
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

## THE WRITERS' OWN ROW ([method AgentPick.assistant]): Off or an agent, its model and its level - the agent stored as its
## NAME in `[assistant] backend`, never a row number, the model and the level beside it. It was a list of CLIs alone.
var _pick: AgentPick
var _backend_row: Control           # the row, measured by _resize_panel
## The agent picker of the row - what a gate drives, and what says why nothing can run.
var _backend_pick: OptionButton


## THE PICKER LIVES IN THIS PANEL, its only user (next/notes.md step 4). It was the home screen's,
## where a Masking session launched with --mask-edit could never reach it, and its "chosen on the
## home screen" told a person to go somewhere no mode could take them back to.
func _build_backend_pick(parent: Control) -> void:
	_pick = AgentPick.assistant(ASSIST_TIP)
	_backend_row = _pick
	_backend_pick = _pick.agents
	parent.add_child(_pick)
	var backend := String(Settings.read("assistant", "backend", ""))
	# A CLAUDE CHOSEN BEFORE THERE WAS A MODEL TO CHOOSE ran Sonnet, and still does until another is picked
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


## GRAY OUT the assistants that cannot run: a CLI that is not installed is listed but not
## choosable, and with none installed the whole picker is - there is nothing to send a note to,
## and [method AssistantBackends.runnable] reads as Off everywhere. The stored choice is never
## rewritten, so it comes back the moment its CLI is found.
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
