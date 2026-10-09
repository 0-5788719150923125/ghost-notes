extends Node

## notes_list_check - Ghost Notes opens on its notes (next/notes.md step 8), through the real main
## scene, with a notes folder of the gate's own (`NoteStore.root`) so the author's notes are never
## listed, made or touched.
##
##   tests/run_boot_probe.sh tests/notes_list_check.gd 300
##
## THE LIST MAKES NOTES AND NOTHING ELSE (2026-10-06, the user: "the launch screen should be clean"):
## no path or URL field, no Open…, and the name and tagline once - in the panel, not again in large
## type over the main area. New ends on "Existing note…", which asks for markdown alone.
##
## THE APP STARTS ON THE LIST: the list is up, no home screen, the ⌂ hidden, the ⤓ export not there
## at all and no claim on the bottom of the frame (the row sits where it sits in every note), nothing
## in the row over the Environment panel (open, and with a detail open), and the keyed handover - a
## note's claims survive the list leaving after it.
##
## NEW IS GATED ON AGENTS, as the home screen's rows were (splash_agents_check's contract, moved
## here): with every agent's program hidden in `Deps._resolved` - the cache a launch reads, never a
## seam - Cards is grayed, and its tooltip says what is missing, lists every supported agent from the
## registries, suggests installing one or several, and is written as paragraphs that survive Boot's
## re-flow; restored, it is lit exactly when the machine has both roles.
##
## A NOTE GOES WHEN ASKED (2026-10-06): the list's × asks first ([DeleteDialog]) - canceled, the note
## stays; confirmed, it goes to the trash (here the gate's seam, `NoteStore.discard`: a plain delete,
## never the author's trash) and out of the list. A note's own "⋯" does the same from inside it, and
## the list comes back.
##
## THE ROUND TRIP: New -> Auto makes a song note with no song yet, and nothing is stuck - its panel is
## up with a Song card asking for one, a Picture in the Auto medium, nothing timed, no stage; choosing
## a song writes it into the note and opens the note again around it, loaded and WAITING at its start
## ("start from the baseline of off, not played yet"); it plays through the transport; the ⌂ leaves
## it; New -> Note's "+" attaches a Voice and the note reopens as a reading; and back on the list
## nothing is left behind (the claims, the row, the conductor, the stage, the background programs,
## no mode node).

var _fails: Array = []
var _main: Node
const ROOT := "user://notes_list_check"
const AGENT_PROGRAMS := ["claude", "codex", "grok", "aws"]
const FixtureAudio := preload("res://tests/fixture_audio.gd")


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	_clean()
	NoteStore.root = ROOT
	NoteStore.discard = func(p: String) -> int: return DirAccess.remove_absolute(p)
	_main = preload("res://scenes/main.tscn").instantiate()
	add_child(_main)
	await _frames(20)
	await _settle_probe()
	var list: NotesList = _main._list
	_ok(list != null and is_instance_valid(list), "the app opens on the notes list")
	if list == null:
		return _report()
	_ok(_find(_main, "Splash") == null, "there is no home screen")
	_check_clean(list)
	await _check_furniture(list)
	list = _main._list
	await _check_gating(list)
	await _check_delete()
	await _check_round_trip()
	NoteStore.discard = Callable()
	_clean()
	_report()


# --- the list itself -----------------------------------------------------------------------------

func _check_clean(list: NotesList) -> void:
	print("-- the list makes notes and nothing else")
	# (a PopupMenu carries a search field of its own - Godot's, not ours)
	var fields := list._panel.find_children("*", "LineEdit", true, false).filter(func(f: Node) -> bool:
		var n := f.get_parent()
		while n != null and n != list:
			if n is PopupMenu:
				return false
			n = n.get_parent()
		return true)
	_ok(fields.is_empty(), "there is no path or URL field (%s)" % str(fields.map(func(f: Node) -> String: return str(f.get_path()))))
	var opens := list.find_children("*", "Button", true, false).filter(
		func(b: Node) -> bool: return (b as Button).text.begins_with("Open"))
	_ok(opens.is_empty(), "there is no Open… button")
	var names := list.find_children("*", "Label", true, false).filter(
		func(l: Node) -> bool: return (l as Label).text == Boot.NAME)
	_ok(names.size() == 1 and list._panel.is_ancestor_of(names[0]), "the name is shown once, in the panel")
	var pop := list._new.get_popup()
	var last := pop.item_count - 1
	_ok(pop.get_item_id(last) == NotesList.EXISTING_ID and pop.get_item_text(last).begins_with("Existing note"),
		"New ends on Existing note…")
	list._on_new(NotesList.EXISTING_ID)
	var dlg: FileDialog = list._dialog
	_ok(dlg != null and Array(dlg.filters).size() == 1 and String(dlg.filters[0]).contains("*.md"),
		"...which asks for a markdown note and nothing else")
	list._close_dialog()


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
	var cards := _item(list, "cards")
	_ok(cards >= 0, "New offers Cards")
	if cards < 0:
		return
	var pop := list._new.get_popup()
	var keep := Deps._resolved.duplicate()
	for prog in AGENT_PROGRAMS:
		Deps._resolved[prog] = ""
	list._gate_templates()
	var tip := pop.get_item_tooltip(cards)
	_ok(pop.is_item_disabled(cards), "with no agent installed, Cards is grayed")
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
	list._on_new(pop.get_item_id(cards))
	_ok(NoteStore.list().size() == before and _main._list == list, "a grayed template makes no note")
	Deps._resolved = keep
	list._gate_templates()
	var lit := Capabilities.missing_roles(["writer", "painter"]).is_empty()
	_ok(pop.is_item_disabled(cards) == not lit, "with the agents back, Cards is lit exactly when both roles are filled")


# --- deleting ------------------------------------------------------------------------------------

func _check_delete() -> void:
	print("-- a note goes when asked")
	var list: NotesList = _main._list
	var path := NoteStore.create("note", "Delete me", "Words.\n")
	list.refresh()
	_ok(_row_of(list, path), "a new note is listed")
	list._ask_delete(path)
	await _frames(2)
	var dlg := _dialog_in(list)
	_ok(dlg != null and dlg.visible, "its × asks first")
	if dlg != null:
		dlg.canceled.emit()
		await _frames(2)
	_ok(FileAccess.file_exists(path), "canceled, the note stays")
	list._ask_delete(path)
	await _frames(2)
	dlg = _dialog_in(list)
	if dlg != null:
		dlg.confirmed.emit()
		await _frames(3)
	_ok(not FileAccess.file_exists(path), "confirmed, it goes")
	list.refresh()
	_ok(not _row_of(list, path), "...and leaves the list")
	# FROM INSIDE THE NOTE: its own "⋯", asked first, and the list comes back
	var inside := NoteStore.create("note", "Delete me from inside", "Words.\n")
	list._open(inside)
	await _frames(12)
	var ch: Chrome = _main._chrome
	_ok(_main._note == inside and ch.delete_blocker().is_empty(), "an open note can be deleted")
	ch.ask_delete()
	await _frames(2)
	dlg = _dialog_in(ch)
	_ok(dlg != null, "its ⋯ asks first")
	if dlg != null:
		dlg.confirmed.emit()
		await _frames(12)
	_ok(not FileAccess.file_exists(inside), "...and once asked, the note goes")
	_ok(_main._list != null and is_instance_valid(_main._list) and _main._note.is_empty(), "...and the list comes back")


func _row_of(list: NotesList, path: String) -> bool:
	for r in list._rows.get_children():
		for b in (r as Node).find_children("*", "Button", true, false):
			if (b as Button).tooltip_text == path:
				return true
	return false


func _dialog_in(n: Node) -> DeleteDialog:
	for c in n.get_children():
		if c is DeleteDialog and not (c as Node).is_queued_for_deletion():
			return c
	return null


# --- the round trip ------------------------------------------------------------------------------

func _check_round_trip() -> void:
	print("-- New -> Auto, a song, play, leave")
	var ch: Chrome = _main._chrome
	var home := _measure()
	var list: NotesList = _main._list
	list._on_new(list._new.get_popup().get_item_id(_item(list, "auto")))
	await _frames(12)
	var panel: NotePanel = _main._note_panel
	_ok(panel != null and is_instance_valid(panel), "New -> Auto opens the note's own panel - nothing is stuck")
	if panel == null:
		return
	var note: String = panel.path
	_ok(panel._song != null and not panel._song.ready_to_play(), "...a Song card asking for a song")
	_ok(panel._picture != null and Director.medium == "auto", "...a Picture in the Auto medium (%s)" % Director.medium)
	_ok(not Spectrum.timed() and not _stage_up(), "...nothing timed and no stage until there is a song")
	# twenty seconds, as teardown_check's: the eight-second silence opens on spires, whose worker-thread
	# builds trip Godot's own teardown fault after the verdict (tests/run_scene_smoke.sh) - this gate is
	# about the list, not about that scene
	var song := FixtureAudio.silence(20.0)
	panel._song.chosen.emit(song)
	await _frames(20)
	var song_block: Variant = NoteStore.blocks_of(note).get("song", {})
	_ok(song_block is Dictionary and String((song_block as Dictionary).get("path", "")) == song,
		"choosing a song writes it into the note")
	_ok(_main._note == note and Spectrum.has_audio(), "...and the note opens again around it, loaded")
	_ok(not Spectrum.transport_playing(), "...WAITING at its start: a note opens stopped")
	_ok(Director.is_attached() and _main._medium != null and _main._medium.key == "auto" and _stage_up(),
		"its picture is up, in the Auto medium")
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
	panel = _main._note_panel
	_ok(panel != null and is_instance_valid(panel), "New -> Note opens a plain note")
	if panel != null:
		var plain: String = panel.path
		var menu: PopupMenu = panel._panel.plus.get_popup()
		panel._panel.plus.about_to_popup.emit()
		var voice := -1
		for i in menu.item_count:
			if String(menu.get_item_metadata(i)) == "voice":
				voice = i
		_ok(voice >= 0, "its \"+\" offers a Voice")
		if voice >= 0:
			menu.id_pressed.emit(menu.get_item_id(voice))
			await _frames(20)
			_ok(NoteStore.blocks_of(plain).get("voice") is Dictionary, "attaching wrote the voice block into the note")
			_ok(_main._generative != null and is_instance_valid(_main._generative) and _main._note == plain,
				"...and the note reopened as a reading of itself")
			ch._home_button.pressed.emit()
			await _frames(12)
			await _quiet(int(home["procs"]))
			_check_home("after the reading", home)


## The stage is showing a picture.
func _stage_up() -> bool:
	return _main._stage_view != null and is_instance_valid(_main._stage_view) and _main._stage_view.visible


func _check_home(tag: String, home: Dictionary) -> void:
	var m := _measure()
	_ok(m["list"], "%s: the list is up" % tag)
	_ok(str(m["bottom"]) == str(home["bottom"]) and str(m["export"]) == str(home["export"]),
		"%s: Chrome's claims are the list's own" % tag)
	_ok(m["row"] == home["row"] and not m["home_button"], "%s: the row is as it was and the ⌂ hidden" % tag)
	_ok(not m["conductor"], "%s: nothing conducts" % tag)
	_ok(m["modes"] == 0, "%s: no note's node is left (%d)" % [tag, m["modes"]])
	_ok(m["procs"] == home["procs"], "%s: no background program left (%d, list %d)" % [tag, m["procs"], home["procs"]])
	_ok(not _stage_up() and _main._medium == null, "%s: the stage is wiped" % tag)


func _measure() -> Dictionary:
	var ch: Chrome = _main._chrome
	var modes := 0
	for n in _main.get_children():
		if n is ReadingPanel or n is SynthEditor or n is MaskEditor or n is NotePanel:
			modes += 1
	return {"list": _main._list != null and is_instance_valid(_main._list),
		"bottom": ch._bottom_claims.keys(), "export": ch._export_claims.keys(),
		"row": ch.row.get_child_count(), "home_button": ch._home_button.visible,
		"conductor": not Spectrum.conductor().is_empty(), "modes": modes, "procs": Subprocess.tracked()}


func _item(list: NotesList, key: String) -> int:
	var pop := list._new.get_popup()
	for i in pop.item_count:
		if str(pop.get_item_metadata(i)) == key:
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
