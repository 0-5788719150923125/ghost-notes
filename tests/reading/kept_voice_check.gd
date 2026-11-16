extends Node

## kept_voice_check - a voice kept for every note, read by name on the Voice card ([VoiceLibrary], [VoiceKeep],
## [ReadingCast]), on a library of the gate's own:
##
##   tests/run_boot_probe.sh tests/reading/kept_voice_check.gd 120
##
## - A cast row is a voice's fields and its room's, nothing else: [constant VoiceLibrary.OWN] and [constant
##   VoiceLibrary.ROOM] are every key of [constant ReadingPanel.SLOT_DEFAULTS], none in both, and the store's defaults are
##   the row's.
## - A note reading a kept voice by name is said as the voice written out whole on its row is: the same take signature and
##   the same request for every sentence, its own room kept. The control, the written-out voice with one dial moved, is
##   said otherwise. What it writes back carries the kept voice as its copy.
## - With the library moved aside it reads the copy it carries (the control: the library back, the kept voice); with the
##   voice removed, the copy it last wrote, said as the voice was.
## - The kept voice changed - in the library, or a dial of who speaks moved on the card and the hand rested (or the tab
##   changed first) - changes the take signature of every note reading it, one opened later with an older copy included,
##   and reaches every tab reading it here. The controls: a room dial moved leaves the kept voice as it was, and a tab of
##   its own is untouched.
## - The picker lists the kept voices under the models and shows a tab's kept voice; a model picked makes the tab its own,
##   its room kept, and the kept voice picked reads it by name again. "Make it this note's own" keeps the sound (the same
##   signature) and lets go of the library. A voice renamed is followed. A new speaker starts as a copy, never by name.
##   Keep on a tab of its own keeps what it has and reads it by name from then.
## - A sample: each sentence asked of the host in the kept voice, joined and written beside it on a worker, the host's files
##   let go; the control, a voice whose model this machine does not list, asks nothing.
##
## The panel is built by hand and never added to the tree (its `_ready` starts the python voice host).

class Host extends VoiceHost:
	var asked: Array = []

	func request(_text: String, voice: String, out_path: String,
			params: Dictionary = {}, _phonemes: Variant = null) -> int:
		asked.append({"voice": voice, "out": out_path, "params": params})
		return 3000 + asked.size()

	func ensure(_voice: String) -> int:
		return 0

	func cancel(_ids: Array) -> void:
		pass

	func is_up() -> bool:
		return true


const ROOT := "user://kept_voice_check"
const NARRATOR := Manuscript.NARRATOR
const BODY := "The rain had not stopped. Since morning it had kept on.\n\n<!-- speaker: Ann -->\nShe said nothing at all.\n\n<!-- speaker: Cy -->\nNor did he, for a while."
## Where the voices are heard, on every row: never kept.
const ROOM_A := {"echo": 0.3, "room": 0.2, "resonance": 0.1, "presence": 0.9, "ambience": 0.0, "lean": 0.0, "near": 0.1, "seat": 0.0}

var _fails: Array = []
var _ed: ReadingPanel
var _host: Host
var _c: ReadingCast


func _ready() -> void:
	Library.root = ROOT.path_join("library")
	Library.discard = func(path: String) -> int: return DirAccess.remove_absolute(path)
	_rmrf(ProjectSettings.globalize_path(ROOT))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ROOT))
	_ed = ReadingPanel.new()
	_ed._build_panel()
	_ed.walk = TextWalk.new()
	if _ed._doc != null:
		_ed._doc._sync = false
	_ed.remove_child(_ed._panel)
	add_child(_ed._panel)
	_host = Host.new()
	_ed._host = _host
	_ed._text.text = BODY
	_c = _ed._cast
	_c.fill_voices(_list())
	_run.call_deferred()


func _run() -> void:
	_structure()
	var said := _by_name()
	_copy(said["copy"], String(said["sig"]))
	_changes()
	_picker()
	_own_and_rename()
	_sample()
	print("")
	if _fails.is_empty():
		print("kept_voice_check: ALL OK")
	else:
		for f in _fails:
			print("kept_voice_check: FAIL - ", f)
		print("kept_voice_check: %d FAILED" % _fails.size())
	VoiceLibrary.maker = Callable()
	_ed._panel.queue_free()
	for _i in 4:
		await get_tree().process_frame
	_ed.free()
	_rmrf(ProjectSettings.globalize_path(ROOT))
	Library.root = Library.ROOT
	Library.discard = Callable()
	get_tree().quit(0 if _fails.is_empty() else 1)


func _list() -> Array:
	return [{"id": "kokoro", "name": "kokoro", "speakers": 2, "installed": true},
		{"id": "en_US-lessac-medium", "name": "lessac medium", "speakers": 1, "installed": true},
		{"id": ReadingPanel.DEFAULT_VOICE, "name": "libritts high", "speakers": 904, "installed": true}]


## Who speaks and how: the voice kept.
func _voice(pace := 1.2) -> Dictionary:
	return {"voice": "kokoro", "speaker": 1, "blend": "", "formant": {}, "tone": 3, "pace": pace, "pause": 2.0,
		"dynamics": 0.3, "arc": 0.2, "effort": 0.6, "ink": "blue"}


## What a note read before the voice changed: another reader, tone and pace.
func _stale() -> Dictionary:
	var v := _voice(0.8)
	v["speaker"] = 0
	v["tone"] = 0
	return v


func _lessac() -> Dictionary:
	return {"voice": "en_US-lessac-medium", "speaker": 0, "blend": "", "formant": {}, "tone": 1, "pace": 1.0, "pause": 1.0,
		"dynamics": 0.5, "arc": 0.4, "effort": 0.35, "ink": ""}


func _row(fields: Dictionary, kept := "") -> Dictionary:
	var r := fields.duplicate(true)
	r.merge(ROOM_A, true)
	if not kept.is_empty():
		r["kept"] = kept
	return r


func _apply(rows: Dictionary) -> void:
	_c.apply({"turn": 1.0, "voices": rows, "hesitate": 1.5, "hesitate_on": true})


func _sig() -> String:
	return _ed.take_sig(BODY)


## What the host is asked for every sentence of the body, in order.
func _said() -> Array:
	var out: Array = []
	for ch in _ed._build_chunks(BODY):
		var s := _c.cfg_of(String((ch as Dictionary).get("speaker", "")))
		out.append(JSON.stringify(_ed._request_args(s, ch), "", true))
	return out


func _own(who: String) -> String:
	return VoiceLibrary.hash_of(_c.cfg_of(who))


func _room_of(who: String) -> Dictionary:
	var cfg := _c.cfg_of(who)
	var out := {}
	for k in VoiceLibrary.ROOM:
		out[k] = cfg[k]
	return out


func _structure() -> void:
	var keys: Array = VoiceLibrary.OWN + VoiceLibrary.ROOM
	keys.sort()
	var slot: Array = ReadingPanel.SLOT_DEFAULTS.keys()
	slot.sort()
	_ok(keys == slot, "the kept fields and the room are not every field of a cast row (%s against %s)" % [str(keys), str(slot)])
	_ok(VoiceLibrary.OWN.all(func(k: String) -> bool: return not VoiceLibrary.ROOM.has(k)), "a field is both the voice's and the room's")
	for k in VoiceLibrary.OWN:
		if k != "voice":
			_ok(DocSource.same_value(VoiceLibrary.DEFAULTS[k], ReadingPanel.SLOT_DEFAULTS[k]),
				"the store's default %s is not the row's" % k)


## A note reading a kept voice says what the voice written out whole says: `{copy, sig}`, the row it writes (the copy it
## carries) and its take signature.
func _by_name() -> Dictionary:
	_ok(VoiceLibrary.keep(_voice(), "Ada", "the narrator").is_empty(), "the voice could not be kept")
	_apply({NARRATOR: _row(_stale(), "Ada"), "Ann": _row(_lessac()), "Cy": _row(_lessac())})
	_ok(Array(_c._names) == [NARRATOR, "Ann", "Cy"], "the tabs are %s" % str(_c._names))
	_ok(_own(NARRATOR) == VoiceLibrary.hash_of(_voice()), "a note reading a kept voice reads %s" % str(VoiceLibrary.own_of(_c.cfg_of(NARRATOR))))
	_ok(DocSource.same_value(_room_of(NARRATOR), ROOM_A), "a note reading a kept voice lost its own room (%s)" % str(_room_of(NARRATOR)))
	_ok(String(_c.cfg_of(NARRATOR).get("kept", "")) == "Ada" and _c.kept_shown() == "Ada", "the row no longer reads the voice by name")
	var sig := _sig()
	var said := _said()
	var written: Dictionary = ((_c.capture()["voices"] as Dictionary)[NARRATOR] as Dictionary).duplicate(true)
	_ok(String(written.get("kept", "")) == "Ada" and VoiceLibrary.hash_of(written) == VoiceLibrary.hash_of(_voice()),
		"what the note writes back does not carry the kept voice as its copy (%s)" % str(written))
	_apply({NARRATOR: _row(_voice()), "Ann": _row(_lessac()), "Cy": _row(_lessac())})
	_ok(_sig() == sig, "the voice written out whole has another take signature than the voice read by name")
	_ok(_said() == said, "the voice written out whole is asked otherwise than the voice read by name")
	_apply({NARRATOR: _row(_voice(1.25)), "Ann": _row(_lessac()), "Cy": _row(_lessac())})
	_ok(_sig() != sig and _said() != said, "control: the written-out voice with one dial moved is said as the kept voice")
	return {"copy": written, "sig": sig}


## With the library moved aside a note reads its copy; with the voice removed, the copy it last wrote.
func _copy(copy: Dictionary, sig: String) -> void:
	Library.root = ROOT.path_join("elsewhere")
	_apply({NARRATOR: _row(_stale(), "Ada"), "Ann": _row(_lessac()), "Cy": _row(_lessac())})
	_ok(_own(NARRATOR) == VoiceLibrary.hash_of(_stale()) and String(_c.cfg_of(NARRATOR).get("kept", "")) == "Ada",
		"with the library moved aside, a note does not read the copy it carries")
	_apply({NARRATOR: copy, "Ann": _row(_lessac()), "Cy": _row(_lessac())})
	_ok(_sig() == sig, "with the library moved aside, the copy written is not said as the kept voice was")
	Library.root = ROOT.path_join("library")
	_apply({NARRATOR: _row(_stale(), "Ada"), "Ann": _row(_lessac()), "Cy": _row(_lessac())})
	_ok(_own(NARRATOR) == VoiceLibrary.hash_of(_voice()), "control: the library back, the kept voice is not read")
	_ok(VoiceLibrary.remove("Ada").is_empty(), "the kept voice could not be removed")
	_apply({NARRATOR: copy, "Ann": _row(_lessac()), "Cy": _row(_lessac())})
	_ok(_sig() == sig, "with the voice removed, the copy written is not said as the kept voice was")


## A change to the kept voice reaches every row reading it and its take signature; the room alone never reaches it.
func _changes() -> void:
	VoiceLibrary.keep(_voice(), "Ada", "the narrator")
	_apply({NARRATOR: _row(_stale(), "Ada"), "Ann": _row(_stale(), "Ada"), "Cy": _row(_lessac())})
	var older: Dictionary = _c.capture()
	var sig := _sig()
	var cy := _own("Cy")
	VoiceLibrary.keep(_voice(1.3), "Ada", "the narrator")
	_c.keep.tick()
	_ok(is_equal_approx(float(_c.cfg_of(NARRATOR)["pace"]), 1.3) and is_equal_approx(float(_c.cfg_of("Ann")["pace"]), 1.3),
		"a change to the kept voice did not reach every tab reading it")
	var now := _sig()
	_ok(now != sig, "a change to the kept voice left the take signature as it was")
	_ok(_own("Cy") == cy, "control: a change to a kept voice reached a tab of its own")
	_apply(older["voices"] as Dictionary)
	_ok(_sig() == now, "a note opened with an older copy of a changed kept voice is not said in the change")
	var h := String(VoiceLibrary.read("Ada")["hash"])
	_c._fx_echo.value = 0.6
	_ok(_c.keep._edited_ms == 0, "control: a room dial moved is waiting to tell the library")
	_ok(_c.keep.flush().is_empty() and String(VoiceLibrary.read("Ada")["hash"]) == h, "control: a room dial moved changed the kept voice")
	_ok(is_equal_approx(float(_c.cfg_of(NARRATOR)["echo"]), 0.6), "the room dial did not reach the tab")
	_c._dynamics.value = 0.7
	_ok(_c.keep._edited_ms > 0, "a dial of who speaks moved is not waiting to tell the library")
	_ok(_c.keep.flush().is_empty() and String(VoiceLibrary.read("Ada")["hash"]) != h
		and is_equal_approx(float(VoiceLibrary.read("Ada")["voice"]["dynamics"]), 0.7), "a dial of who speaks moved did not reach the kept voice")
	_c.keep.tick()
	_ok(is_equal_approx(float(_c.cfg_of("Ann")["dynamics"]), 0.7), "a kept voice changed on one tab did not reach another tab reading it")
	_ok(_own("Cy") == cy, "control: a kept voice changed on one tab reached a tab of its own")
	_c._effort.value = 0.8
	_c._select_tab(_c._names.find("Ann"))
	_ok(is_equal_approx(float(VoiceLibrary.read("Ada")["voice"]["effort"]), 0.8), "a dial moved and the tab changed before the hand rested was lost")
	_c._select_tab(_c._names.find(NARRATOR))


func _picker() -> void:
	_c.fill_voices(_list())
	var n := _c.voice_meta.size()
	var kept := VoiceLibrary.names()
	_ok(_c.voice_pick.item_count == n + 1 + kept.size() and _c.voice_pick.is_item_separator(n)
		and _c.voice_pick.get_item_text(n + 1 + kept.find("Ada")) == "Ada", "the picker does not list the kept voices under the models")
	_ok(_c.voice_pick.selected == n + 1 + kept.find("Ada"), "the picker does not show the tab's kept voice (%d)" % _c.voice_pick.selected)
	var room := _room_of(NARRATOR)
	_pick(1)
	_ok(_c.kept_shown() == "" and not _c.cfg_of(NARRATOR).has("kept") and String(_c.cfg_of(NARRATOR)["voice"]) == "en_US-lessac-medium",
		"a model picked on a tab reading a kept voice did not make it the tab's own")
	_ok(DocSource.same_value(_room_of(NARRATOR), room), "a model picked lost the tab's room")
	_pick(n + 1 + kept.find("Ada"))
	_ok(_c.kept_shown() == "Ada" and _own(NARRATOR) == String(VoiceLibrary.read("Ada")["hash"]) and DocSource.same_value(_room_of(NARRATOR), room),
		"the kept voice picked is not read by name, its room kept")


func _own_and_rename() -> void:
	var sig := _sig()
	_c.make_own()
	_ok(not _c.cfg_of(NARRATOR).has("kept") and _sig() == sig, "made this note's own, the voice sounds otherwise or still reads by name")
	VoiceLibrary.keep(_voice(1.5), "Ada", "the narrator")
	_c.keep.tick()
	_ok(not is_equal_approx(float(_c.cfg_of(NARRATOR)["pace"]), 1.5), "a voice made this note's own still follows the library")
	_ok(is_equal_approx(float(_c.cfg_of("Ann")["pace"]), 1.5), "control: a tab reading the kept voice did not follow it")
	VoiceLibrary.rename("Ada", "Ada Prime", "the narrator")
	_c.keep.tick()
	VoiceLibrary.keep(_voice(1.1), "Ada Prime", "the narrator")
	_c.keep.tick()
	_ok(String(_c.cfg_of("Ann").get("kept", "")) == "Ada Prime" and is_equal_approx(float(_c.cfg_of("Ann")["pace"]), 1.1),
		"a kept voice renamed is not followed (%s)" % str(_c.cfg_of("Ann")))
	_c.fill_voices(_list())
	_pick(_c.voice_meta.size() + 1 + VoiceLibrary.names().find("Ada Prime"))
	_ed._text.text = BODY + "\n\n<!-- speaker: Dee -->\nAnd Dee."
	_c.refresh(_ed._cast_text())
	_ok(_c._names.has("Dee") and not _c.cfg_of("Dee").has("kept") and _own("Dee") == _own(NARRATOR),
		"a new speaker does not start as a copy of the first voice (%s)" % str(_c.cfg_of("Dee")))
	_c._select_tab(_c._names.find("Cy"))
	var cy := _own("Cy")
	_ok(_c.keep_name() == "Cy", "a tab of its own is offered to be kept as %s" % _c.keep_name())
	_ok(_c.keep_shown("Bea", "a second voice").is_empty(), "a tab of its own could not be kept")
	_ok(String(VoiceLibrary.read("Bea").get("hash", "")) == cy and _c.kept_shown() == "Bea" and String(_c.cfg_of("Cy").get("kept", "")) == "Bea",
		"a voice kept from a tab is not what the tab had, read by name")
	_ok(_c.keep_name() == "Bea 2", "a tab reading a kept voice is offered %s" % _c.keep_name())


func _sample() -> void:
	VoiceLibrary.keep(_voice(), "Sam", "")
	var k := _c.keep
	var before := _host.asked.size()
	k._start("Sam")
	var n: int = (ReadingPlan.cut(VoiceKeep.sample_text(), 0)["chunks"] as Array).size()
	var asked := _host.asked.slice(before)
	_ok(n >= 3 and asked.size() == n and asked.all(func(a: Dictionary) -> bool: return String(a["voice"]) == "kokoro"),
		"a sample asked the host %d times, not once a sentence (%d) in the kept voice" % [asked.size(), n])
	var made: Array = []
	for id in (k._making.get("req", {}) as Dictionary).keys():
		var path := ProjectSettings.globalize_path(ROOT).path_join("said_%d.wav" % int(id))
		var frames := PackedVector2Array()
		for i in 6615:
			var x := 0.2 * sin(TAU * 220.0 * float(i) / 22050.0)
			frames.append(Vector2(x, x))
		Splice.write_wav(path, frames, 1, 22050)
		made.append(path)
		k.take(int(id), {"wav": path, "sample_rate": 22050, "tokens": []})
	_ok(k._making.has("task"), "every sentence in, the sample was not joined on a worker")
	if k._making.has("task"):
		k._finish()
	var at := VoiceLibrary.sample("Sam")
	_ok(not at.is_empty() and at.get_base_dir() == VoiceLibrary.dir() and Splice.decode_wav(at).size() >= n * 6615,
		"the sample was not written beside the kept voice (%s)" % at)
	_ok(made.all(func(p: String) -> bool: return not FileAccess.file_exists(p)), "the host's files for a sample were kept")
	var far := _voice()
	far["voice"] = "en_US-elsewhere"
	VoiceLibrary.keep(far, "Far", "")
	before = _host.asked.size()
	k._start("Far")
	_ok(_host.asked.size() == before and k._making.is_empty(), "control: a voice whose model is not listed had a sample asked in another")


## The person picks item [param i] in the Voice picker.
func _pick(i: int) -> void:
	_c.voice_pick.select(i)
	_c.voice_pick.item_selected.emit(i)


func _ok(cond: bool, msg: String) -> void:
	if not cond:
		_fails.append(msg)


func _rmrf(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for d in DirAccess.get_directories_at(path):
		_rmrf(path.path_join(d))
	for f in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(f))
	DirAccess.remove_absolute(path)
