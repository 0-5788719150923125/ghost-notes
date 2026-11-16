extends RefCounted
class_name VoiceKeep

## VoiceKeep - the Voice card's kept voices, a part of [ReadingCast]: Keep… on the voice on screen, which asks a name and
## keeps it in the library ([VoiceLibrary], [method ReadingCast.keep_shown]), and "Make it this note's own" on a tab that
## reads one by name. A tab reading a kept voice is that voice: a dial of who speaks and how moved on it is written to the
## library once the hand rests ([method edited], [method flush]) - its room never is - and a change to the library from
## anywhere in this process reaches every tab that reads it ([method tick], [method ReadingCast.follow_library]).
##
## Its samples: the opening of the Test passage ([method sample_text]) said once in a kept voice, dry - no room - and kept
## beside it ([method VoiceLibrary.sample_path]). Made when a voice is kept, and the first time one is asked for after the
## voice changed ([member VoiceLibrary.maker]): one at a time, from the host as a reading is (a sentence said before comes
## from the [TakeCache]), never while a reading or a Test plays - those come first, and a sample in their way is asked again
## after - and decoded, joined and written on a worker. Never in a session that may not write the library.

## Paragraphs of the Test passage a sample says.
const SAMPLE_PARAGRAPHS := 2
## How long the hand rests on a kept voice's dial before the library is told, milliseconds.
const REST_MS := 700
## Silence after a sample's last word, seconds.
const SAMPLE_TAIL := 0.4
## The room a Keep… dialog stands clear of the panel by.
const BESIDE := 12.0

## The cast this is a part of.
var cast: ReadingCast

var _keep_btn: Button
var _own_btn: Button
var _seen := 0               # the library's version this has followed
var _edited_ms := 0          # when a kept voice's dial last moved; 0 for nothing waiting
var _queue: Array = []       # names waiting for a sample
## The sample being made: `{name, cfg, path, chunks, req: {id: {i, key}}, got: {i: {wav, out, own}}}`, and once every
## sentence is in, the worker's `task` and its `box`.
var _making := {}


func _init(owner: ReadingCast) -> void:
	cast = owner
	_seen = VoiceLibrary.version
	VoiceLibrary.maker = sample_later


## The row right under the Voice row, in [param box] from its left edge: Keep…, and on a tab reading a kept voice, "Make it
## this note's own". On the Voice row itself it would leave the picker too narrow to read a voice's name.
func build(box: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	box.add_child(row)
	_keep_btn = Button.new()
	_keep_btn.text = "Keep…"
	_keep_btn.focus_mode = Control.FOCUS_NONE
	_keep_btn.tooltip_text = ("Keep this voice for every note, by a name: it is listed under Kept in every Voice picker. "
		+ "Who speaks and how is kept - the model, the reader or blend, Tone, Pace, Pause, the delivery dials and the ink - "
		+ "and the room (Echo, Room, Resonance, Presence, Ambience, Lean, Near, Seat) stays this note's. From then this voice "
		+ "reads it by name: a change to it here is heard in every note that reads it.")
	_keep_btn.pressed.connect(ask)
	row.add_child(_keep_btn)
	_own_btn = Button.new()
	_own_btn.text = "Make it this note's own"
	_own_btn.focus_mode = Control.FOCUS_NONE
	_own_btn.pressed.connect(func() -> void: cast.make_own())
	row.add_child(_own_btn)
	show_state()


## The row says what the tab on screen reads: "Make it this note's own" only where it reads a kept voice.
func show_state() -> void:
	if _own_btn == null:
		return
	var kept := cast.kept_shown()
	_own_btn.visible = not kept.is_empty()
	if kept.is_empty():
		return
	var tip := ("Reads the kept voice %s by name, so a change to it here or in another note is heard here too. Make it "
		+ "this note's own: it keeps what it sounds like now, and from then on only this note changes it.") % kept
	if VoiceLibrary.read(kept).is_empty():
		tip += " %s is not in this machine's library, so this note reads the copy it carries." % kept
	_own_btn.tooltip_text = tip


## Keep…: the voice on screen kept by the name asked, centered beside the panel.
func ask() -> void:
	var dlg := ConfirmationDialog.new()
	dlg.title = "Keep this voice"
	dlg.ok_button_text = "Keep"
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	var name_edit := _field(col, "Name", cast.keep_name(), VoiceLibrary.NAME_MOST,
		"What it is called in the library, and under Kept in every Voice picker.")
	var line_edit := _field(col, "About", "", VoiceLibrary.LINE_MOST,
		"What the voice is, in a few words: said beside its name wherever kept voices are listed.")
	dlg.add_child(col)
	dlg.register_text_enter(name_edit)
	dlg.register_text_enter(line_edit)
	var named := func(t: String) -> void:
		var n := t.strip_edges()
		dlg.get_ok_button().disabled = n.is_empty()
		dlg.ok_button_text = "Replace" if not n.is_empty() and not VoiceLibrary.read(n).is_empty() else "Keep"
		dlg.get_ok_button().tooltip_text = ("A voice called %s is kept already: this one takes its place, in every note "
			+ "that reads it.") % n if dlg.ok_button_text == "Replace" else ""
	name_edit.text_changed.connect(named)
	named.call(name_edit.text)
	dlg.confirmed.connect(func() -> void:
		var err := cast.keep_shown(name_edit.text, line_edit.text)
		if err.is_empty():
			sample_later(cast.kept_shown())
			cast.panel.status("Kept %s: every note can read it, under Kept in the Voice picker." % cast.kept_shown())
		else:
			cast.panel.status("Not kept: " + err)
		dlg.queue_free())
	dlg.canceled.connect(dlg.queue_free)
	cast.panel.add_child(dlg)
	dlg.popup_centered(Vector2i(420, 0))
	_beside(dlg)
	name_edit.grab_focus()
	name_edit.select_all()


func _field(col: VBoxContainer, label: String, text: String, most: int, tip: String) -> LineEdit:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	col.add_child(row)
	var l := Label.new()
	l.text = label
	l.custom_minimum_size = Vector2(56, 0)
	l.mouse_filter = Control.MOUSE_FILTER_STOP
	l.tooltip_text = tip
	row.add_child(l)
	var e := LineEdit.new()
	e.text = text
	e.max_length = most
	e.tooltip_text = tip
	e.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(e)
	return e


## [param dlg] in the middle of the room beside the panel: clear of it where it fits, slid left as far as the window's
## edge where it does not.
func _beside(dlg: Window) -> void:
	if not dlg.is_inside_tree():
		return
	var room := dlg.get_parent().get_viewport().get_visible_rect()
	var left := room.position.x
	var side: Control = cast.panel._panel
	if side != null and side.is_visible_in_tree():
		left = maxf(left, side.get_global_rect().end.x + BESIDE)
	var size := Vector2(dlg.size)
	var x := clampf(left + (room.end.x - left - size.x) * 0.5, room.position.x, maxf(room.position.x, room.end.x - size.x))
	var y := maxf(room.position.y, room.position.y + (room.size.y - size.y) * 0.5)
	dlg.position = Vector2i(roundi(x), roundi(y))


## A dial of who speaks and how moved on a tab reading a kept voice: the library is told once the hand rests.
func edited() -> void:
	_edited_ms = maxi(1, Time.get_ticks_msec())


## Every frame: a change to the library followed, a kept voice's rested dial written to it, and the sample being made
## carried on.
func tick() -> void:
	if VoiceLibrary.version != _seen:
		_seen = VoiceLibrary.version
		cast.follow_library()
		show_state()
	if _edited_ms > 0 and Time.get_ticks_msec() - _edited_ms >= REST_MS:
		flush()
	_pump()


## The kept voice the tab on screen reads told what its dials say now ([param capture]: read off the controls first, else
## as last taken), where they say otherwise and its model is one this machine lists. "" done (or nothing to tell), else
## why not.
func flush(capture := true) -> String:
	_edited_ms = 0
	var name := cast.kept_shown()
	if name.is_empty():
		return ""
	var e := VoiceLibrary.read(name)
	if capture:
		cast.capture_slot()
	var s := cast.slot_cfg(cast.slot)
	if e.is_empty() or not cast.listed(String(s["voice"])):
		return ""
	if VoiceLibrary.hash_of(s) == VoiceLibrary.hash_of(e["voice"]):
		return ""
	return VoiceLibrary.keep(s, String(e["name"]), String(e["line"]))


## A dial still waiting for the hand to rest told to the library now: before the tab on screen changes, or the cast is
## read again. [param capture] as [method flush]'s.
func settle(capture := true) -> void:
	if _edited_ms > 0:
		flush(capture)


## The panel is going: a dial still waiting told to the library, the library no longer asks it for samples, and the sample
## being made is let go (its worker, if one is writing, finished first).
func release() -> void:
	settle()
	if VoiceLibrary.maker == Callable(self, &"sample_later"):
		VoiceLibrary.maker = Callable()
	if _making.has("task"):
		_finish()
	elif not _making.is_empty():
		_abandon(false)
	_queue.clear()


# --- samples ---------------------------------------------------------------------------------------


## The words a sample says: the Test passage's first paragraphs, the same for every voice.
static func sample_text() -> String:
	return "\n\n".join(ReadingAudition.PASSAGE.split("\n\n").slice(0, SAMPLE_PARAGRAPHS))


## The sample of the voice kept as [param name] made when it can be, after those asked before it.
func sample_later(name: String) -> void:
	if not name.is_empty() and not _queue.has(name) and String(_making.get("name", "")) != name:
		_queue.append(name)


## Whether request [param id] is a sample's.
func owns(id: int) -> bool:
	return (_making.get("req", {}) as Dictionary).has(id)


## The host answered request [param id] of the sample being made with [param result].
func take(id: int, result: Dictionary) -> void:
	var r: Dictionary = (_making["req"] as Dictionary)[id]
	(_making["req"] as Dictionary).erase(id)
	var wav := String(result.get("wav", ""))
	if wav.is_empty():
		_abandon(false)
		return
	if not Settings.is_read_only():
		TakeCache.put(String(r["key"]), wav, result)
	(_making["got"] as Dictionary)[int(r["i"])] = {"wav": wav, "out": result, "own": true}
	_join_when_in()


## The host failed a request: a sample waiting on one is let go, made again when it is next asked for.
func failed() -> void:
	if not _making.is_empty() and not _making.has("task"):
		_abandon(false)


## The voice whose sample is being made, "" for none.
func making() -> String:
	return String(_making.get("name", ""))


func _pump() -> void:
	if not _making.is_empty():
		if _making.has("task"):
			if WorkerThreadPool.is_task_completed(int(_making["task"])):
				_finish()
		elif _in_the_way():
			_abandon(true)
		return
	if _queue.is_empty() or _in_the_way() or not _can_make():
		return
	_start(String(_queue.pop_front()))


## A reading or a Test is going: what is heard comes first.
func _in_the_way() -> bool:
	return cast.panel._stream.live() or cast.panel._test_busy()


func _can_make() -> bool:
	var panel := cast.panel
	return Library.writable() and panel.is_inside_tree() and panel._host != null and panel._host.is_up() \
		and not cast.voice_meta.is_empty()


## The sample of the voice kept as [param name] begun: each sentence from the [TakeCache] where it was said before, the
## rest asked of the host. A voice whose model this machine does not list has none made: another would stand in for it.
func _start(name: String) -> void:
	var e := VoiceLibrary.read(name)
	if e.is_empty():
		return
	var path := VoiceLibrary.sample_path(e["voice"])
	if FileAccess.file_exists(path):
		return
	var cfg: Dictionary = ReadingPanel.SLOT_DEFAULTS.duplicate(true)
	var v: Dictionary = e["voice"]
	for k in v:
		cfg[k] = (v[k] as Dictionary).duplicate(true) if v[k] is Dictionary else v[k]
	if not cast.listed(String(cfg["voice"])):
		return
	var text := sample_text()
	var chunks: Array = ReadingPlan.cut(text, 0)["chunks"]
	ReadingPlan.place(chunks, text)
	for c in chunks:
		(c as Dictionary)["speaker"] = String(e["name"])
	_making = {"name": String(e["name"]), "cfg": cfg, "path": path, "chunks": chunks, "req": {}, "got": {}}
	var panel := cast.panel
	var stamp := Time.get_ticks_msec()
	for i in chunks.size():
		var args := panel._request_args(cfg, chunks[i])
		var key := panel.take_key(cfg, args)
		var hit := TakeCache.find(key)
		if not hit.is_empty():
			(_making["got"] as Dictionary)[i] = {"wav": String(hit["wav"]), "out": hit["out"], "own": false}
			continue
		var id := panel._host.request("", cast.voice_id_of(cfg), ReadingPanel.TAKE_DIR + "/sample_%d_%d.wav" % [stamp, i],
			args, null)
		(_making["req"] as Dictionary)[id] = {"i": i, "key": key}
	_join_when_in()


## Every sentence in: decoded, joined as a reading joins them and written, on a worker.
func _join_when_in() -> void:
	if _making.is_empty() or _making.has("task") or not (_making["req"] as Dictionary).is_empty():
		return
	var chunks: Array = _making["chunks"]
	var got: Dictionary = _making["got"]
	var parts: Array = []
	var sr := cast.panel._sr
	for i in chunks.size():
		var p: Dictionary = got.get(i, {})
		parts.append(p)
		if not p.is_empty() and int((p["out"] as Dictionary).get("sample_rate", 0)) > 0:
			sr = int((p["out"] as Dictionary)["sample_rate"])
	var cfg: Dictionary = _making["cfg"]
	var path := String(_making["path"])
	var turn := cast.turn_scale()
	var box := [false]
	_making["box"] = box
	_making["task"] = WorkerThreadPool.add_task(func() -> void:
		box[0] = _render(chunks, parts, cfg, sr, turn, path), false, "voice sample")


## The sentences [param parts] (each `{wav, out}`) of [param chunks] joined as a reading joins them, dry, and written at
## [param path]: whether it was. A pure function of what it is handed, for a worker.
static func _render(chunks: Array, parts: Array, cfg: Dictionary, sr: int, turn: float, path: String) -> bool:
	var join := ReadingJoin.new(sr)
	var pcm := PackedFloat32Array()
	for i in chunks.size():
		var p: Dictionary = parts[i]
		if p.is_empty():
			continue
		var said := Splice.decode_wav(String(p["wav"]))
		if said.is_empty():
			continue
		var out: Dictionary = p["out"]
		pcm.append_array(join.add(chunks, i, said, out.get("tokens", []), cfg, turn, out.get("phones", [])))
	if pcm.is_empty():
		return false
	pcm.append_array(join.pad(int(SAMPLE_TAIL * float(sr))))
	var frames := PackedVector2Array()
	frames.resize(pcm.size())
	for i in pcm.size():
		frames[i] = Vector2(pcm[i], pcm[i])
	return not Splice.write_wav(path, frames, 1, sr).is_empty()


## The worker done: the host's files let go, and the shelf told a sample was written.
func _finish() -> void:
	WorkerThreadPool.wait_for_task_completion(int(_making["task"]))
	var ok := bool((_making["box"] as Array)[0])
	_forget_own()
	_making = {}
	if ok:
		VoiceLibrary.sampled()


## The sample being made let go: what is still asked cancelled, the host's files removed, and asked again later where
## [param again].
func _abandon(again: bool) -> void:
	var ids: Array = (_making.get("req", {}) as Dictionary).keys()
	if not ids.is_empty() and cast.panel._host != null:
		cast.panel._host.cancel(ids)
	_forget_own()
	if again and not _queue.has(String(_making["name"])):
		_queue.push_front(String(_making["name"]))
	_making = {}


func _forget_own() -> void:
	for p in (_making.get("got", {}) as Dictionary).values():
		if bool((p as Dictionary).get("own", false)):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(String((p as Dictionary)["wav"])))
