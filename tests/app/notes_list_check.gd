extends Node

## notes_list_check - Ghost Notes opens on its notes (next/notes.md step 8), through the real main
## scene, with a notes folder of the gate's own (`NoteStore.root`) so the author's notes are never
## listed, made or touched.
##
##   tests/run_boot_probe.sh tests/app/notes_list_check.gd 300
##
## THE LIST MAKES NOTES AND NOTHING ELSE (2026-10-06, the user: "the launch screen should be clean"):
## no path or URL field, no Open…, and the name and tagline once - in the panel, not again in large
## type over the main area. "Existing note…" stands beside New, and asks for markdown alone.
##
## NEW HAS NO OPTIONS (2026-10-12, the user: "'New' has no options at all. Every note would open in
## exactly the same way"): it is a button, not a menu; it makes a note with nothing attached - no
## `ghost:` key in its file - and that note opens in the note's own panel, whatever is installed.
##
## THE APP STARTS ON THE LIST: the list is up, no home screen, the ⌂ hidden, the ⤓ export not there
## at all and no claim on the bottom of the frame (the row sits where it sits in every note), nothing
## in the row over the Environment panel (open, and with a detail open), and the keyed handover - a
## note's claims survive the list leaving after it.
##
## WHAT NEEDS AN AGENT IS GATED IN "+", where a note becomes something (the home screen's rule,
## moved from New): with every agent's program hidden in `Deps._resolved` - the cache a launch
## reads, never a seam - New still makes a note, and in its "+" Cards is grayed, with a tooltip that
## says what is missing, lists every supported agent from the registries, suggests installing one or
## several, and is written as paragraphs that survive Boot's re-flow; a press on it attaches nothing;
## restored, it is lit exactly when the machine has both roles.
##
## A NOTE GOES WHEN ASKED (2026-10-06): the list's × asks first ([DeleteDialog]) - canceled, the note
## stays; confirmed, it goes to the trash (here the gate's seam, `NoteStore.discard`: a plain delete,
## never the author's trash) and out of the list. A note's own "⋯" does the same from inside it, and
## the list comes back.
##
## THE ROUND TRIP - A NOTE BECOMES A SHOW BY WHAT IS ATTACHED: New, then "+" Song (the note opens
## again with a Song card asking for one, nothing timed, no stage, and a Picture grayed no longer),
## "+" Picture (in the Auto medium: the seeded show); choosing a song writes it into the note and
## opens the note again around it, loaded and WAITING at its start ("start from the baseline of off,
## not played yet"); it plays through the transport; "+" Storyboard puts its card on the same note
## and the seed still chooses until something is written. A SECOND CLOCK IS REFUSED, WITH THE REASON
## (a Voice on a note with a song: "detach that first"), and a component COMES OFF AGAIN: the Song
## card's ×, once asked, takes the `song:` block out and leaves the note's other blocks and its
## words as they were. The ⌂ leaves it; New then "+" Voice reopens a plain note as a reading; and
## back on the list nothing is left behind (the claims, the row, the conductor, the stage, the
## background programs, no mode node).
##
## A SHOW OF CARDS STARTS WITH A BRIEF: attaching Cards to a note with no words fills it with the
## bundled starter, and the Cards workspace opens showing it.
##
## SAVE… TAKES THE NOTE WITH IT (2026-10-12, the user: "That selection keeps getting reverted back to
## the untitled cards label, and I am unsure if my edits are even being used"): the Script card has
## Save… and a [SaveMark], the editor window has no button of the kind, and Save… asks for a file
## every time. Saved into a file elsewhere, the note IS that file - for main, for "⋯", for the list -
## the one Ghost Notes was keeping goes (the gate's `discard`), and left and opened again it is still
## that file, with the words typed before and after. A file of the author's own that a note is saved
## out of stays on disk and leaves the list. THE CONTROL is the old behavior: a script sent to a file
## the note does not follow is the old file again the next time the note opens.
##
## OPEN… LOADS A FILE FROM DISK (the user, the same day: "The 'Save' button would just overwrite the
## file on disk"): in a note it asks for a file to open, and the file chosen becomes the note - its
## own text on screen, byte for byte unwritten - while the note left behind keeps the words typed a
## moment before and stays in the list. A file with no blocks opens as a plain note.

var _fails: Array = []
var _main: Node
const ROOT := "user://notes_list_check"
const AGENT_PROGRAMS := ["claude", "codex", "grok", "aws"]
const PROBE_WAIT_MS := 120000     # a backstop for the Environment panel's first probe
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
	await _check_gating()
	await _check_delete()
	await _check_round_trip()
	await _check_new_card_starter()
	await _check_save_moves_the_note()
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
	_ok(list._new is Button and not (list._new is MenuButton) and list._new.text == "New",
		"New has no options: it is a button, not a menu")
	_ok(list.find_children("*", "MenuButton", true, false).is_empty(), "nothing on the list is a menu of kinds of note")
	_ok(list._existing != null and list._existing.text.begins_with("Existing note"), "Existing note… stands beside New")
	list._existing.pressed.emit()
	var dlg: FileDialog = list._dialog
	_ok(dlg != null and Array(dlg.filters).size() == 1 and String(dlg.filters[0]).contains("*.md"),
		"...and asks for a markdown note and nothing else")
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
		_ok(box.end.y <= floor_y - Shell.ROW_TOP, "the Environment panel (%s) stands above the row" % step)
		for b in ch.row.get_children():
			if (b as Control).visible:
				_ok(not (b as Control).get_global_rect().intersects(box),
					"%s is not over the Environment panel (%s)" % [(b as Button).text, step])
	for b in ch.row.get_children():
		if (b as Control).visible:
			_ok(absf((b as Control).get_global_rect().end.y - (floor_y - Shell.ROW_MARGIN)) < 0.5,
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

func _check_gating() -> void:
	print("-- New is for everyone; what needs an agent is gated in \"+\"")
	var keep := Deps._resolved.duplicate()
	for prog in AGENT_PROGRAMS:
		Deps._resolved[prog] = ""
	var list: NotesList = _main._list
	var before := NoteStore.list().size()
	list.new_note()
	await _frames(12)
	var panel: NotePanel = _main._note_panel
	_ok(NoteStore.list().size() == before + 1 and panel != null and is_instance_valid(panel),
		"with no agent installed, New still makes a note and opens it")
	if panel == null:
		Deps._resolved = keep
		return
	_ok(not FileAccess.get_file_as_string(panel.path).contains("ghost:"), "a new note has nothing attached: no ghost: key at all")
	_ok(panel._panel.cards().size() == 1, "...and its panel is its words alone (%d cards)" % panel._panel.cards().size())
	var plus: MenuButton = panel._panel.plus
	plus.about_to_popup.emit()
	var pop := plus.get_popup()
	var cards := _menu_item(pop, "cards")
	_ok(cards >= 0, "\"+\" offers Cards")
	if cards >= 0:
		var tip := pop.get_item_tooltip(cards)
		_ok(pop.is_item_disabled(cards), "with no agent installed, Cards is grayed")
		_ok(tip.contains("No AI writer or painter is installed."), "its tooltip says what is missing")
		for role in ["writer", "painter"]:
			var reg: Dictionary = Capabilities.registry(role).REGISTRY
			for label in reg.keys().map(func(k: String) -> String: return Registry.label(reg, k)):
				_ok(tip.contains(String(label).replace(" ", " ")), "it lists the supported %s %s" % [role, label])
		_ok(tip.contains("Install one or several of them"), "it suggests installing one or several")
		var paras := tip.split("\n\n")
		_ok(Array(paras).all(func(p: String) -> bool: return not p.contains("\n")), "it is written as paragraphs")
		_ok(Boot.wrap_tip(tip).split("\n\n").size() == paras.size(), "the paragraphs survive Boot's re-flow")
		# a press on a grayed item attaches nothing
		pop.id_pressed.emit(pop.get_item_id(cards))
		await _frames(6)
		_ok(_main._note_panel == panel and not NoteStore.blocks_of(panel.path).has("cards"),
			"a grayed component is not attached")
		Deps._resolved = keep
		plus.about_to_popup.emit()
		cards = _menu_item(pop, "cards")
		var lit := Capabilities.missing_roles(["writer", "painter"]).is_empty()
		_ok(cards >= 0 and pop.is_item_disabled(cards) == not lit,
			"with the agents back, Cards is lit exactly when both roles are filled")
	Deps._resolved = keep
	_main._chrome._home_button.pressed.emit()
	await _frames(12)


# --- deleting ------------------------------------------------------------------------------------

func _check_delete() -> void:
	print("-- a note goes when asked")
	var list: NotesList = _main._list
	var path := NoteStore.create("Delete me", "Words.\n")
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
	var inside := NoteStore.create("Delete me from inside", "Words.\n")
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
	print("-- New, + Song, + Picture, a song, play, a storyboard, detach, leave")
	var ch: Chrome = _main._chrome
	var home := _measure()
	var list: NotesList = _main._list
	list.new_note()
	await _frames(12)
	var panel: NotePanel = _main._note_panel
	_ok(panel != null and is_instance_valid(panel), "New opens the note's own panel")
	if panel == null:
		return
	var note: String = panel.path
	_ok(_offer(panel, "picture") == "grayed" and _offer(panel, "song") == "lit" and _offer(panel, "voice") == "lit",
		"a plain note's \"+\": a Song and a Voice are lit, a Picture waits for a sound (picture %s, song %s, voice %s)"
		% [_offer(panel, "picture"), _offer(panel, "song"), _offer(panel, "voice")])
	panel = await _attach(panel, "song")
	_ok(panel != null and _main._note == note and panel._song != null and not panel._song.ready_to_play(),
		"+ Song: the same note, opened again with a Song card asking for a song")
	if panel == null:
		return
	_ok(not Spectrum.timed() and not _stage_up(), "...nothing timed and no stage until there is a song")
	_ok(_offer(panel, "voice") == "grayed" and _tip(panel, "voice").contains("clock") and _tip(panel, "voice").contains("Song"),
		"a second clock is refused, and \"+\" says which to detach (%s)" % _tip(panel, "voice").get_slice("\n\n", 1))
	_ok(_offer(panel, "song") == "", "what is attached is not offered again")
	panel = await _attach(panel, "picture")
	_ok(panel != null and panel._picture != null and Director.medium == "auto",
		"+ Picture: a Picture card, in the Auto medium (%s)" % Director.medium)
	if panel == null:
		return
	# twenty seconds, as teardown_check's: the eight-second silence opens on spires, whose worker-thread
	# builds trip Godot's own teardown fault after the verdict (tests/run_scene_smoke.sh) - this gate is
	# about the list, not about that scene
	var song := FixtureAudio.silence(20.0)
	panel._song.chosen.emit(song)
	await _frames(20)
	panel = _main._note_panel
	var song_block: Variant = NoteStore.blocks_of(note).get("song", {})
	_ok(song_block is Dictionary and String((song_block as Dictionary).get("path", "")) == song,
		"choosing a song writes it into the note")
	_ok(_main._note == note and Spectrum.has_audio(), "...and the note opens again around it, loaded")
	_ok(not Spectrum.transport_playing(), "...WAITING at its start: a note opens stopped")
	_ok(Director.is_attached() and _main._medium != null and _main._medium.key == "auto" and _stage_up(),
		"its picture is up, in the Auto medium")
	_ok(not Director.is_manual(), "...and the seed chooses its scenes")
	Spectrum.transport_play()
	await _frames(10)
	_ok(Spectrum.transport_playing(), "and it plays through the transport")
	_ok(ch._home_button.visible, "the ⌂ shows in a note")
	# a storyboard, attached to the same note: nothing written yet, so the seed still chooses
	panel = await _attach(panel, "storyboard")
	_ok(panel != null and panel._story != null and Storyboard.of_block(NoteStore.blocks_of(note).get("scenes"))["kind"] == "own",
		"+ Storyboard: its card, and the note's own storyboard in its scenes: block")
	_ok(Director.is_attached() and not Director.is_manual(), "...with nothing written in it, the seed still chooses")
	# ...and a component comes off again
	if panel != null:
		var words := String(FrontMatter.split(FileAccess.get_file_as_string(note)).body)
		var x := _detach_button(panel, "Song")
		_ok(x != null and not x.disabled, "the Song card has an ×")
		_ok(_detach_button(panel, "Script") == null, "...and the Script has none: the words are the note")
		if x != null:
			x.pressed.emit()
			await _frames(3)
			var ask: ConfirmationDialog = null
			for d in panel.find_children("*", "ConfirmationDialog", true, false):
				if (d as ConfirmationDialog).title.begins_with("Detach"):
					ask = d
			_ok(ask != null and NoteStore.blocks_of(note).has("song"), "the × asks first, and nothing is detached until it is answered")
			if ask != null:
				ask.confirmed.emit()
		await _frames(20)
		panel = _main._note_panel
		var left := NoteStore.blocks_of(note)
		_ok(not left.has("song") and left.has("picture") and left.has("scenes"),
			"detaching the Song takes its block out and leaves the others (%s)" % str(left.keys()))
		_ok(String(FrontMatter.split(FileAccess.get_file_as_string(note)).body) == words, "...and the note's words as they were")
		_ok(panel != null and panel._song == null and not Spectrum.timed() and not _stage_up(),
			"...the note opens again without it: no clock, no stage")
		_ok(panel != null and panel._picture != null and _waiting(panel).contains("song or a voice"),
			"...and the Picture left on it says what it is waiting for (%s)" % _waiting(panel))
	ch._home_button.pressed.emit()
	await _frames(12)
	_ok(_main._list != null and is_instance_valid(_main._list), "the ⌂ goes back to the list")
	_check_home("after the song", home)
	# a plain note: New, then "+" -> Voice
	list = _main._list
	list.new_note()
	await _frames(12)
	panel = _main._note_panel
	_ok(panel != null and is_instance_valid(panel), "New opens a plain note")
	if panel != null:
		var plain: String = panel.path
		var menu: PopupMenu = panel._panel.plus.get_popup()
		panel._panel.plus.about_to_popup.emit()
		var voice := _menu_item(menu, "voice")
		_ok(voice >= 0, "its \"+\" offers a Voice")
		if voice >= 0:
			menu.id_pressed.emit(menu.get_item_id(voice))
			await _frames(20)
			_ok(NoteStore.blocks_of(plain).get("voice") is Dictionary, "attaching wrote the voice block into the note")
			var reading: Node = _main._generative
			_ok(reading != null and is_instance_valid(reading) and _main._note == plain,
				"...and the note reopened as a reading of itself")
			if reading != null:
				var titles: Array = (reading._panel as SidePanel).cards().map(func(c: Node) -> String: return (c as Card).title)
				_ok(titles == ["Script", "Voice"], "a voice alone: its words and its voice, and no picture until one is attached (%s)" % str(titles))
				_ok(not bool(reading.show_plan()["picture"]), "...so its reading puts no stage up")
			ch._home_button.pressed.emit()
			await _frames(12)
			await _quiet(int(home["procs"]))
			_check_home("after the reading", home)


## Attach [param key] through the panel's "+", as a click on its item does; returns the note's panel
## as it is afterward (the note is opened again), or null where "+" did not offer it lit.
func _attach(panel: NotePanel, key: String) -> NotePanel:
	var menu: PopupMenu = panel._panel.plus.get_popup()
	panel._panel.plus.about_to_popup.emit()
	var i := _menu_item(menu, key)
	if i < 0 or menu.is_item_disabled(i):
		_ok(false, "\"+\" offers %s, lit" % key)
		return null
	menu.id_pressed.emit(menu.get_item_id(i))
	await _frames(20)
	return _main._note_panel


## How "+" offers [param key] on [param panel]: "lit", "grayed", or "" when it is not offered.
func _offer(panel: NotePanel, key: String) -> String:
	var menu: PopupMenu = panel._panel.plus.get_popup()
	panel._panel.plus.about_to_popup.emit()
	var i := _menu_item(menu, key)
	if i < 0:
		return ""
	return "grayed" if menu.is_item_disabled(i) else "lit"


func _tip(panel: NotePanel, key: String) -> String:
	var menu: PopupMenu = panel._panel.plus.get_popup()
	panel._panel.plus.about_to_popup.emit()
	var i := _menu_item(menu, key)
	return menu.get_item_tooltip(i) if i >= 0 else ""


func _menu_item(menu: PopupMenu, key: String) -> int:
	for i in menu.item_count:
		if str(menu.get_item_metadata(i)) == key:
			return i
	return -1


## The × on the card titled [param title], or null.
func _detach_button(panel: NotePanel, title: String) -> Button:
	for c in panel._panel.cards():
		if (c as Card).title != title:
			continue
		for b in (c as Card).find_children("*", "Button", true, false):
			if (b as Button).text == "×":
				return b as Button
	return null


## What the note's cards say they are waiting for (the ⚠ lines NoteCards puts at their heads).
func _waiting(panel: NotePanel) -> String:
	var out := PackedStringArray()
	for l in panel._panel.find_children("*", "Label", true, false):
		if (l as Label).text.begins_with("⚠"):
			out.append((l as Label).text)
	return " | ".join(out)


func _check_new_card_starter() -> void:
	print("-- + Cards starts a note with no words on the bundled brief")
	var list: NotesList = _main._list
	list.new_note()
	await _frames(12)
	var panel: NotePanel = _main._note_panel
	if panel == null:
		_ok(false, "New opens a note")
		return
	var path: String = panel.path
	# The gate in "+" is about installed agents; this is about what attaching writes.
	panel._attach("cards")
	await _frames(20)
	var starter := FileAccess.get_file_as_string("res://rules/cards/starter.md")
	_ok(_main._note == path and NoteStore.blocks_of(path).get("cards") is Dictionary, "+ Cards writes the cards block into the note")
	_ok(FileAccess.get_file_as_string(path).contains(starter), "...and the full starter brief, since the note had no words")
	var editor := _main._generative as ReadingPanel
	_ok(editor != null and editor._text.text == starter,
		"the Cards workspace opens, and Edit shows the starter brief")
	if editor != null:
		var titles: Array = (editor._panel as SidePanel).cards().map(func(c: Node) -> String: return (c as Card).title)
		_ok(titles.has("Episode") and titles.has("Voice") and not titles.has("Picture"),
			"its cards are the show's: the Episode and the Voice it brings, and no Picture (%s)" % str(titles))
		_ok(bool(editor.show_plan()["picture"]), "...and the table is what it is seen in")


## SAVE… ON THE SCRIPT CARD, from the Cards note the last check left open.
func _check_save_moves_the_note() -> void:
	print("-- Save… takes the note with it")
	var ch: Chrome = _main._chrome
	var editor := _main._generative as ReadingPanel
	var old: String = _main._note
	if editor == null or old.is_empty():
		_ok(false, "a Cards note is open")
		return
	var dir := ProjectSettings.globalize_path(ROOT).path_join("elsewhere")
	DirAccess.make_dir_recursive_absolute(dir)
	var writer: ScriptWriter = editor._writer
	_ok(writer._save_btn.visible and writer._save_btn.text == "Save…" and writer._open_btn.visible
		and writer._open_btn.get_index() < writer._save_btn.get_index() and not writer._clear_btn.visible,
		"the Script card has Open… and Save… (and, in a note, no Clear)")
	_ok(writer.save_mark != null and writer.save_mark.state() == "saved" and writer._name.text == old.get_file(),
		"...and a mark beside the file's name (%s)" % writer._name.text)
	var stray := writer._window.find_children("*", "Button", true, false).filter(func(b: Node) -> bool:
		return (b as Button).text.begins_with("Sync") or (b as Button).text.begins_with("Save"))
	_ok(stray.is_empty(), "the editor window has no Sync or Save button")
	for _i in 2:
		writer._save_btn.pressed.emit()
		await _frames(2)
		var dlg := editor._doc._dialog as FileDialog
		_ok(dlg != null and dlg.file_mode == FileDialog.FILE_MODE_SAVE_FILE, "Save… asks for a file, every time")
		editor._doc._close_dialog()
		await _frames(2)
	# THE CONTROL - what "Sync to…" did in a note: the script goes, the note does not follow
	editor._doc.moved.disconnect(editor._on_note_moved)
	var astray := dir.path_join("astray.md")
	_ok(editor._doc.save_to(astray) and _main._note == old, "the control: the script was sent where the note did not follow")
	ch._home_button.pressed.emit()
	await _frames(12)
	_main._list._open(old)
	await _frames(14)
	editor = _main._generative as ReadingPanel
	_ok(editor != null and editor._doc.doc_path() == old and editor._doc.doc_path() != astray,
		"the control: opened again, such a note is the old file once more")
	if editor == null:
		return
	# THE REAL THING
	var te: TextEdit = editor._text
	te.set_caret_line(te.get_line_count() - 1)
	te.set_caret_column(te.get_line(te.get_line_count() - 1).length())
	te.insert_text_at_caret("\n## The box\n\nAn open-top box.\n")
	var now := dir.path_join("penalty-box.md")
	var mark: SaveMark = editor._writer.save_mark
	var writes := mark.writes
	_ok(editor._doc.save_to(now), "Save… into a file elsewhere")
	_ok(_main._note == now and ch._note_path == now and editor.note_path == now,
		"the note is that file: for main, for \"⋯\" and for its panel (%s)" % _main._note.get_file())
	_ok(not FileAccess.file_exists(old), "the one Ghost Notes was keeping for it is gone")
	_ok(editor._writer._name.text == "penalty-box.md" and mark.writes > writes and mark.flashing(),
		"the card names the new file and its mark ticked (%s)" % editor._writer._name.text)
	_ok(editor._writer._note.visible and editor._writer._note.text.contains("penalty-box.md")
		and editor._writer._note.text.contains(old.get_file()), "...and says where the old one went: %s" % editor._writer._note.text)
	var raw := FileAccess.get_file_as_string(now)
	_ok(raw.contains("An open-top box.") and NoteStore.blocks_of(now).get("cards") is Dictionary,
		"the file holds the brief as it was on screen, and the show's block")
	ch._home_button.pressed.emit()
	await _frames(12)
	var list: NotesList = _main._list
	list.refresh()
	_ok(_row_of(list, now) and not _row_of(list, old), "the list shows the note once, as the new file")
	list._open(now)
	await _frames(14)
	editor = _main._generative as ReadingPanel
	_ok(editor != null and _main._note == now and editor._doc.doc_path() == now
		and editor._text.text.contains("An open-top box."), "opened again, it is still that file - nothing reverts")
	if editor == null:
		return
	# an edit made after that is saved into it (the autosave, allowed for this file of the gate's own)
	editor._doc.allow_autosave_for_test()
	mark = editor._writer.save_mark
	writes = mark.writes
	te = editor._text
	te.set_caret_line(te.get_line_count() - 1)
	te.insert_text_at_caret("Typed after the move.\n")
	for _i in 200:
		if mark.writes > writes:
			break
		await _frames(2)
	_ok(FileAccess.get_file_as_string(now).contains("Typed after the move.") and mark.writes > writes,
		"an edit made in the note afterwards is in the file, and the mark ticked for it")
	# A FILE OF THE AUTHOR'S OWN is left where it is, and leaves the list
	var third := dir.path_join("third.md")
	_ok(editor._doc.save_to(third) and _main._note == third, "saved on again, the note follows again")
	_ok(FileAccess.file_exists(now) and not NoteStore.is_added(now) and NoteStore.is_added(third),
		"a file of the author's own is left on disk and leaves the list")
	editor._doc._autosave_for_test = false
	await _check_open_from_disk(dir, third)
	ch._home_button.pressed.emit()
	await _frames(12)
	for p in [third, dir.path_join("on-disk.md"), dir.path_join("plain.md")]:
		NoteStore.remove(p)


## OPEN… ON THE SCRIPT CARD, from the Cards note [param from] the check above ends in.
func _check_open_from_disk(dir: String, from: String) -> void:
	print("-- Open… loads a file from disk")
	var editor := _main._generative as ReadingPanel
	var on_disk := dir.path_join("on-disk.md")
	FrontMatter.create(on_disk, {"cards": {"show": "from-disk"}}, "A brief that was on disk.\n", "",
		FrontMatter.KEY, {"title": "From disk"})
	var plain := dir.path_join("plain.md")
	FrontMatter.create(plain, null, "Only words.\n")
	var before := FileAccess.get_file_as_string(on_disk)
	editor._writer._open_btn.pressed.emit()
	await _frames(2)
	var dlg := editor._doc._dialog as FileDialog
	_ok(dlg != null and dlg.file_mode == FileDialog.FILE_MODE_OPEN_FILE, "Open… asks for a file to open")
	editor._doc._close_dialog()
	await _frames(2)
	var te: TextEdit = editor._text
	te.set_caret_line(te.get_line_count() - 1)
	te.insert_text_at_caret("Typed a moment before opening.\n")
	editor._writer.open_as_note(on_disk)
	await _frames(14)
	editor = _main._generative as ReadingPanel
	_ok(_main._note == on_disk and editor != null and editor._doc.doc_path() == on_disk
		and editor._text.text.contains("A brief that was on disk.") and String(editor._block_cards["cards"]._knobs["show"]) == "from-disk",
		"the file chosen is the note: its own text and its own settings (%s)" % _main._note.get_file())
	_ok(FileAccess.get_file_as_string(on_disk) == before, "...and opening it wrote nothing into it")
	_ok(FileAccess.get_file_as_string(from).contains("Typed a moment before opening.") and NoteStore.is_added(from),
		"the note left behind kept the words typed a moment before, and stays in the list")
	if editor == null:
		return
	editor._writer.open_as_note(dir.path_join("not-there.md"))
	await _frames(4)
	_ok(_main._note == on_disk and editor._writer._note.text.contains("no file"),
		"a file that is not there opens nothing, and the card says so: %s" % editor._writer._note.text)
	editor._writer.open_as_note(plain)
	await _frames(14)
	_ok(_main._note == plain and _main._note_panel != null and is_instance_valid(_main._note_panel),
		"a file with no blocks opens as a plain note")


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


func _quiet(home_procs: int) -> void:
	for _i in 60:
		if Subprocess.tracked() <= home_procs:
			return
		await _frames(5)


## The Environment panel's first probe lands from a thread, its rows built as it does: waited on by
## the clock (teardown_check's header says why). The panel's layout is checked with its rows in it.
func _settle_probe() -> void:
	var env: DepsPanel = _main._chrome.environment
	var t0 := Time.get_ticks_msec()
	while not _probed(env) and Time.get_ticks_msec() - t0 < PROBE_WAIT_MS:
		await get_tree().process_frame
	_ok(_probed(env), "the Environment panel's probe has landed before anything is measured (%d rows, %.1f s)"
		% [env._rows.size(), (Time.get_ticks_msec() - t0) / 1000.0])
	await _frames(10)


static func _probed(env: DepsPanel) -> bool:
	return not env._rows.is_empty() and env._thread == null


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
