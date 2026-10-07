extends Node

## notes_list_check - Ghost Notes opens on its notes (next/notes.md step 8), through the real main
## scene, with a notes folder of the gate's own (`NoteStore.root`) so the author's notes are never
## listed, made or touched.
##
##   tests/run_boot_probe.sh tests/notes_list_check.gd 300
##
## THE DRAFTS ARRIVE AS NOTES: an unsynced draft in a mode's Settings section becomes a note with its
## words and its voice, a synced document joins the list, and it happens once.
##
## THE APP STARTS ON THE LIST: the list is up, no home screen, the ⌂ hidden, the ⤓ export not there
## at all and no claim on the bottom of the frame (the row sits where it sits in every note), nothing
## in the row over the Environment panel (open, and with a detail open), and the keyed handover - a
## note's claims survive the list leaving after it.
##
## NEW IS GATED ON AGENTS, as the home screen's rows were (splash_agents_check's contract, moved
## here): with every agent's program hidden in `Deps._resolved` - the cache a launch reads, never a
## seam - Tarot is grayed, and its tooltip says what is missing, lists every supported agent from the
## registries, names the one that does both, suggests installing one or several, and is written as
## paragraphs that survive Boot's re-flow; restored, it is lit exactly when the machine has both.
##
## THE ROUND TRIP: New makes a note from a template and opens it; it plays through the transport; the
## ⌂ leaves it; the list opens another; a plain note's "+" attaches a Voice and the note reopens as a
## reading; and back on the list nothing is left behind (the claims, the row, the conductor, the
## background programs, no mode node).

var _fails: Array = []
var _main: Node
const ROOT := "user://notes_list_check"
const AGENT_PROGRAMS := ["claude", "codex", "aws"]


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	_clean()
	NoteStore.root = ROOT
	_check_drafts()
	_main = preload("res://scenes/main.tscn").instantiate()
	add_child(_main)
	await _frames(20)
	await _settle_probe()
	var list: NotesList = _main._list
	_ok(list != null and is_instance_valid(list), "the app opens on the notes list")
	if list == null:
		return _report()
	_ok(_find(_main, "Splash") == null, "there is no home screen")
	await _check_furniture(list)
	list = _main._list
	await _check_gating(list)
	await _check_round_trip()
	_clean()
	_report()


# --- the drafts --------------------------------------------------------------------------------

func _check_drafts() -> void:
	print("-- the drafts arrive as notes")
	var keep := {}
	var absent: Array = []
	for k in [["generative", "text"], ["generative", "sync"], ["generative", "doc_path"], ["generative", "cast"],
			["synth", "text"], ["synth", "sync"], ["tarot", "text"], ["tarot", "sync"], ["tarot", "doc_path"],
			["notes", "drafts_moved"], ["notes", "sources"]]:
		if Settings._cfg.has_section_key(k[0], k[1]):
			keep[k] = Settings._cfg.get_value(k[0], k[1])
		else:
			absent.append(k)
	# a Generative draft with a voice, a Tarot section synced to a document, nothing for Synthesis
	var doc := ProjectSettings.globalize_path(ROOT).path_join("elsewhere/show.md")
	DirAccess.make_dir_recursive_absolute(doc.get_base_dir())
	var f := FileAccess.open(doc, FileAccess.WRITE)
	f.store_string("---\ntitle: A Show Elsewhere\n---\n\nThe brief.\n")
	f.close()
	Settings._cfg.set_value("generative", "text", "A draft nobody saved.\n")
	Settings._cfg.set_value("generative", "sync", false)
	Settings._cfg.set_value("generative", "cast", {"Narrator": {"voice": "en_US-libritts-high", "speaker": 3}})
	Settings._cfg.set_value("synth", "text", "")
	Settings._cfg.set_value("tarot", "text", "")
	Settings._cfg.set_value("tarot", "doc_path", doc)
	Settings._cfg.set_value("tarot", "sync", true)
	if Settings._cfg.has_section_key("notes", "drafts_moved"):
		Settings._cfg.erase_section_key("notes", "drafts_moved")
	Settings._cfg.set_value("notes", "sources", [])
	var made := NoteStore.move_drafts()
	_ok(made.size() == 1, "one unsynced draft made one note (%s)" % str(made))
	if made.size() == 1:
		var raw := FileAccess.get_file_as_string(String(made[0]))
		_ok(raw.contains("A draft nobody saved."), "the note holds the draft's words")
		var blocks: Dictionary = NoteStore.blocks_of(String(made[0]))
		_ok(blocks.get("voice") is Dictionary and (blocks["voice"] as Dictionary).get("voices") is Dictionary,
			"...and the voice its panel kept for it (%s)" % str(blocks.keys()))
		_ok(Components.template_for(blocks) == "generative", "...so it opens as a Generative note")
	_ok(NoteStore.list().any(func(n: Dictionary) -> bool: return String(n["path"]) == doc),
		"the document Tarot was synced to is in the list")
	_ok(NoteStore.move_drafts().is_empty(), "and it happens once")
	# put the in-memory settings back (a probe never writes the file)
	for k in absent:
		if Settings._cfg.has_section_key(k[0], k[1]):
			Settings._cfg.erase_section_key(k[0], k[1])
	for k in keep:
		Settings._cfg.set_value(k[0], k[1], keep[k])
	Settings._cfg.set_value("notes", "drafts_moved", true)   # the run below must not move the author's
	Settings._cfg.set_value("notes", "sources", [doc])


# --- the furniture -------------------------------------------------------------------------------

func _check_furniture(list: NotesList) -> void:
	print("-- the list and the row")
	var ch: Chrome = _main._chrome
	_ok(not ch._home_button.visible, "the ⌂ is hidden on the list")
	_ok(is_equal_approx(ch.bottom_inset, 0.0), "the list claims nothing: the row sits where it sits in every note")
	_ok(not ch.exporter._btn.visible and ch.exporter.suppressed, "the ⤓ export is not on the list at all")
	ch.set_environment_open(true, false)
	await _frames(4)
	var floor_y := get_tree().root.get_visible_rect().size.y
	for step in ["open", "detail open"]:
		if step == "detail open" and not ch.environment._rows.is_empty():
			ch.environment._toggle_detail(String(ch.environment._rows[0].get("key", "")))
		await _frames(6)
		var box := ch.environment.get_global_rect()
		_ok(box.end.y <= floor_y - Chrome.ROW_TOP, "the Environment panel (%s) stands above the row" % step)
		for b in ch.row.get_children():
			if (b as Control).visible:
				_ok(not (b as Control).get_global_rect().intersects(box),
					"%s is not over the Environment panel (%s)" % [(b as Button).text, step])
	for b in ch.row.get_children():
		if (b as Control).visible:
			_ok(absf((b as Control).get_global_rect().end.y - (floor_y - Chrome.ROW_MARGIN)) < 0.5,
				"%s sits on the row every note uses" % (b as Button).text)
		_ok(not (b as Control).get_global_rect().intersects(list._panel.get_global_rect()),
			"%s is not over the list" % (b as Button).text)
	ch.set_environment_open(false, false)
	# THE HANDOVER: a note opens FIRST and the list leaves SECOND - the note's claims must stand.
	# Stood up as a note does, then the real list freed, as its own handler frees it.
	ch.claim_bottom(&"note", 240.0)
	ch.suppress_export(&"note")
	list.queue_free()
	await _frames(4)
	_ok(is_equal_approx(ch.bottom_inset, 240.0) and ch.exporter.suppressed,
		"a list leaving after a note arrived does not clobber the note's claims")
	ch.release_bottom(&"note")
	ch.release_export(&"note")
	await _frames(3)
	_ok(is_equal_approx(ch.bottom_inset, 0.0) and not ch.exporter.suppressed,
		"and once the note goes too, the furniture is back")
	# and the list again, as a return to it brings it
	_main._show_list()
	await _frames(6)


# --- the gating ----------------------------------------------------------------------------------

func _check_gating(list: NotesList) -> void:
	print("-- New is gated on agents")
	list._gate_templates()
	var tarot := _item(list, "tarot")
	_ok(tarot >= 0, "New offers Tarot")
	if tarot < 0:
		return
	var pop := list._new.get_popup()
	var keep := Deps._resolved.duplicate()
	for prog in AGENT_PROGRAMS:
		Deps._resolved[prog] = ""
	list._gate_templates()
	var tip := pop.get_item_tooltip(tarot)
	_ok(pop.is_item_disabled(tarot), "with no agent installed, Tarot is grayed")
	_ok(tip.contains("No AI writer or painter is installed."), "its tooltip says what is missing")
	for role in ["writer", "painter"]:
		for label in (Capabilities.registry(role).LABELS as Dictionary).values():
			_ok(tip.contains(String(label).replace(" ", " ")), "it lists the supported %s %s" % [role, label])
	_ok(tip.contains("Install one or several of them"), "it suggests installing one or several")
	var paras := tip.split("\n\n")
	_ok(Array(paras).all(func(p: String) -> bool: return not p.contains("\n")), "it is written as paragraphs")
	_ok(Boot.wrap_tip(tip).split("\n\n").size() == paras.size(), "the paragraphs survive Boot's re-flow")
	# a press on a grayed item makes nothing
	var before := NoteStore.list().size()
	list._on_new(pop.get_item_id(tarot))
	_ok(NoteStore.list().size() == before and _main._list == list, "a grayed template makes no note")
	Deps._resolved = keep
	list._gate_templates()
	var lit := Capabilities.missing_roles(["writer", "painter"]).is_empty()
	_ok(pop.is_item_disabled(tarot) == not lit, "with the agents back, Tarot is lit exactly when both roles are filled")


# --- the round trip ------------------------------------------------------------------------------

func _check_round_trip() -> void:
	print("-- new, play, leave, open another")
	var ch: Chrome = _main._chrome
	var home := _measure()
	# New -> Auto, with a song: the field routes a song into an Auto note
	var song: String = preload("res://tests/fixture_audio.gd").silence(8.0)
	var list: NotesList = _main._list
	list._take(song)
	await _frames(20)
	_ok(_main._note.begins_with(ProjectSettings.globalize_path(ROOT)), "the song made a note in the notes folder (%s)" % _main._note)
	_ok(Spectrum.has_audio(), "the note's song is loaded")
	Spectrum.transport_play()
	await _frames(10)
	_ok(Spectrum.transport_playing(), "and it plays through the transport")
	_ok(ch._home_button.visible, "the ⌂ shows in a note")
	ch._home_button.pressed.emit()
	await _frames(12)
	_ok(_main._list != null and is_instance_valid(_main._list), "the ⌂ goes back to the list")
	_check_home("after the song", home)
	# a plain note: New -> Note, then "+" -> Voice
	list = _main._list
	list._on_new(list._new.get_popup().get_item_id(_item(list, "note")))
	await _frames(12)
	var panel: Node = _main._note_panel
	_ok(panel != null and is_instance_valid(panel), "New -> Note opens a plain note")
	if panel != null:
		var note: String = panel.path
		var menu: PopupMenu = panel._plus.get_popup()
		Components.attach_menu(menu, ["text"], NotePanel.DECIDES)
		var voice := -1
		for i in menu.item_count:
			if String(menu.get_item_metadata(i)) == "voice":
				voice = i
		_ok(voice >= 0, "its \"+\" offers a Voice")
		if voice >= 0:
			panel._attach(menu.get_item_id(voice))
			await _frames(20)
			_ok(NoteStore.blocks_of(note).get("voice") is Dictionary, "attaching wrote the voice block into the note")
			_ok(_main._generative != null and is_instance_valid(_main._generative) and _main._note == note,
				"...and the note reopened as a reading of itself")
			ch._home_button.pressed.emit()
			await _frames(12)
			await _quiet(int(home["procs"]))
			_check_home("after the reading", home)


func _check_home(tag: String, home: Dictionary) -> void:
	var m := _measure()
	_ok(m["list"], "%s: the list is up" % tag)
	_ok(str(m["bottom"]) == str(home["bottom"]) and str(m["export"]) == str(home["export"]),
		"%s: Chrome's claims are the list's own" % tag)
	_ok(m["row"] == home["row"] and not m["home_button"], "%s: the row is as it was and the ⌂ hidden" % tag)
	_ok(not m["conductor"], "%s: nothing conducts" % tag)
	_ok(m["modes"] == 0, "%s: no note's node is left (%d)" % [tag, m["modes"]])
	_ok(m["procs"] == home["procs"], "%s: no background program left (%d, list %d)" % [tag, m["procs"], home["procs"]])


func _measure() -> Dictionary:
	var ch: Chrome = _main._chrome
	var modes := 0
	for n in _main.get_children():
		if n is ReadingPanel or n is SynthEditor or n is MaskEditor or n is Workspace or n is NotePanel:
			modes += 1
	return {"list": _main._list != null and is_instance_valid(_main._list),
		"bottom": ch._bottom_claims.keys(), "export": ch._export_claims.keys(),
		"row": ch.row.get_child_count(), "home_button": ch._home_button.visible,
		"conductor": not Spectrum.conductor().is_empty(), "modes": modes, "procs": Subprocess.tracked()}


func _item(list: NotesList, key: String) -> int:
	var pop := list._new.get_popup()
	for i in pop.item_count:
		if String(pop.get_item_metadata(i)) == key:
			return i
	return -1


func _quiet(home_procs: int) -> void:
	for _i in 60:
		if Subprocess.tracked() <= home_procs:
			return
		await _frames(5)


func _settle_probe() -> void:
	var env: DepsPanel = _main._chrome.environment
	for _i in 600:
		if not env._rows.is_empty():
			break
		await get_tree().process_frame
	await _frames(10)


func _find(n: Node, cls: String) -> Node:
	for c in n.get_children():
		if c.get_script() != null and String(c.get_script().get_global_name()) == cls:
			return c
	return null


func _clean() -> void:
	var abs := ProjectSettings.globalize_path(ROOT)
	if DirAccess.dir_exists_absolute(abs):
		for d in [abs.path_join("elsewhere"), abs]:
			if DirAccess.dir_exists_absolute(d):
				for f in DirAccess.get_files_at(d):
					DirAccess.remove_absolute(d.path_join(f))
		DirAccess.remove_absolute(abs.path_join("elsewhere"))
		DirAccess.remove_absolute(abs)


func _frames(n: int) -> void:
	for _i in n:
		await get_tree().process_frame


func _ok(cond: bool, msg: String) -> void:
	print(("  ok    " if cond else "  FAIL  ") + msg)
	if not cond:
		_fails.append(msg)


func _report() -> void:
	if _fails.is_empty():
		print("notes_list_check: ALL OK")
		get_tree().quit(0)
		return
	print("notes_list_check: %d FAILURE(S)" % _fails.size())
	for f in _fails:
		print("   ", f)
	get_tree().quit(1)
