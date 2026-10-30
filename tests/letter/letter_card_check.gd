extends SceneTree

## Does the Letter component hold together without an agent or TeX: its row, what the drawer is told,
## what is kept, and what the card hands the reading ([LetterCard], [LetterSketches], [LetterWalk];
## next/letter.md)?
##
## - THE ROW: a Letter brings a Voice and is run by the reading, which shows its card; it holds the
##   note's presentation, so a Picture on a letter is refused with a sentence; its medium is its own, never
##   offered by a picker; its pictures' look is a block of the note's (`illustrations:`) that brings no Picture.
## - WHAT THE DRAWER IS TOLD ([constant LetterSketches.RULES]): the prompt renders whole, names each id a
##   point needs and what is said while it is drawn - and on a second try what the last drawing lacked or
##   why it could not be read (the control: a first try says neither).
## - WHAT LANDS: the SVG is taken out of an answer however it is wrapped (none from an answer with none, the
##   control), and the ids a drawing lacks are found and the ones it has are not.
## - WHAT IS KEPT (under a scratch root): a sketch not drawn is missing, one drawn from its words is ready,
##   and the same sketch pointed at a new part is stale; the ink is ready with nothing to lay out, missing
##   before it is laid out, ready for the drawings it was made from and stale for others.
## - WHAT THE CARD HANDS THE READING (on the first frame: the card names the Director): its block round
##   trips, its hand among it - one it does not know is Kalam (the control) - and the document carries it;
##   without a note its desk is the first; the walk reads the letter as [method
##   LetterScript.speakable] does, with no title announced.
## - WHAT IS ON THE DESK AND ITS LIGHT ARE CHOSEN ON THE CARD (2026-10-29, the user: "provide a multi-select bank of
##   the standard objects ... Then, when we change the seed - the only thing being changed would be the placement of
##   objects, and textures"): with nothing chosen the desk is what its number drew, ticked so on a bank of every thing;
##   another number keeps them and the light - the control, that number's own desk, is another - and is the desk's
##   alone, the letter said the same at either (the control, the hand seeded by the number, otherwise); a tick and a light are
##   kept in the block and carried by the document; the block round trips through the frontmatter, an empty desk too,
##   and a thing or a light it does not know is dropped. WHAT IS WRITTEN ON THE INDEX CARDS (the user: "an input box -
##   which only appears if we've selected the index cards"): the box shown with the cards ticked and hidden without
##   them (the control); typed into, kept in the block, carried by the document to the desk with the letter's hand, and
##   round trips through the frontmatter, its lines and all.
## - THE STEPS THE NOTE'S OTHER CARDS ADD (the YouTube card's tags; 2026-10-28, they had waited at the bottom
##   of the YouTube card): the card hands the reading how it goes out, so it lists them - with the box ticked
##   the row is on the Letter card, under the Ink and above Generate, and the YouTube card draws none (THE
##   CONTROL: the box clear, no row anywhere); the YouTube card's line names the Letter card. Generate makes it
##   once the sketches are drawn - not while one is (held by hand) - here refused, read-only, and said on its
##   row; a job landed gives its ✓ and replaces the note's tags; Stop stops one.
## - A NOTE OPENED AGAIN KEEPS ITS MEDIUM ([method Director.pin_medium]; 2026-10-28, the user: attaching a Look to a
##   letter being watched "suddenly add[ed] the underwater scene to my video"): the old card leaving the tree after
##   the new one has pinned the letter leaves it pinned - the control, the new card's own leaving, lets it go.
##
##   godot --headless --path . --script tests/letter/letter_card_check.gd

const LETTER := """Dear Friend,

<!-- sketch: a cross and a dot on one line -->

A cross, and a dot.

<!-- point: sketch, the dot --> *That one is me.*

Yours,
"""

var _fails: Array = []
var _scratch := ""


func _init() -> void:
	_scratch = OS.get_user_data_dir().path_join("letter_card_check")
	_rmrf(_scratch)
	LetterSketches.root = _scratch
	_row()
	_prompt()
	_landing()
	_kept()
	process_frame.connect(_card, CONNECT_ONE_SHOT)


func _check(ok: bool, msg: String) -> void:
	print(("   ok   " if ok else "   FAIL ") + msg)
	if not ok:
		_fails.append(msg)


func _row() -> void:
	print("-- the row")
	_check(Components.with_required(["letter"]).has("voice") and Components.workspace_of(["text", "letter"]) == "reading"
		and (Components.WORKSPACES["reading"]["hosts"] as Array).has("letter"),
		"a Letter brings a Voice, is run by the reading and its card is shown there")
	_check(not Components.slot_note("picture", ["text", "letter"]).is_empty()
		and Components.slot_note("picture", ["text", "voice"]).is_empty(),
		"it holds the presentation: a Picture on a letter is refused (on a voice alone, not)")
	_check(Medium.mode_of("letter") == "letter" and not Medium.pickable().has("letter") and Medium.REGISTRY.has("letter"),
		"its medium is its own, never offered by a picker")
	_check(Components.blocks_of("letter").has("illustrations")
		and not Components.with_required(Components.attached_of({"voice": {}, "letter": {}, "illustrations": {}})).has("picture"),
		"its pictures' look is kept in the note (`illustrations:`), and keeping it brings no Picture")


func _prompt() -> void:
	print("-- what the drawer is told")
	var sketch: Dictionary = LetterScript.sketches(LETTER)[0]
	Rules.missing.clear()
	var p := LetterSketches.prompt(sketch)
	var all := String(p["system"]) + String(p["prompt"])
	_check(Rules.missing.is_empty() and not all.contains("{{") and all.contains("id=\"the-dot\"")
		and all.contains("A cross, and a dot.") and all.contains("a cross and a dot on one line"),
		"the prompt renders whole, with the id the point needs and what is said as it is drawn")
	_check(not all.contains("had no element") and not all.contains("could not be read"), "a first try is told of no fault")
	var again := LetterSketches.prompt(sketch, PackedStringArray(["the-dot"]), "a path could not be read")
	_check(Rules.missing.is_empty() and String(again["prompt"]).contains("had no element with these ids, and each one must be there: the-dot")
		and String(again["prompt"]).contains("could not be read: a path could not be read"),
		"a second try is told what the last drawing lacked and why it could not be read")


func _landing() -> void:
	print("-- what lands")
	var svg := "<svg viewBox=\"0 0 360 40\"><circle id=\"the-dot\" cx=\"300\" cy=\"20\" r=\"4\"/></svg>"
	_check(LetterSketches.svg_of("Here it is:\n```svg\n%s\n```\nDone." % svg) == svg
		and LetterSketches.svg_of("I could not draw that.").is_empty(),
		"the SVG is taken out of an answer however it is wrapped, none from an answer with none")
	_check(LetterSketches.lacking(svg, ["the-dot", "the-cross"]) == PackedStringArray(["the-cross"]),
		"the ids a drawing lacks are found, and the ones it has are not")


func _kept() -> void:
	print("-- what is kept")
	var store := LetterSketches.new("user://notes/letter check.md")
	_check(store.dir.begins_with(ProjectSettings.globalize_path(_scratch)) and store.dir.get_file().begins_with("letter-check-"),
		"a note's sketches are kept in a folder of its own, named after it")
	var sketch: Dictionary = LetterScript.sketches(LETTER)[0]
	_check(store.state(sketch) == "missing", "a sketch not drawn is missing")
	var svg := "<svg viewBox=\"0 0 360 40\"><circle id=\"the-dot\" cx=\"300\" cy=\"20\" r=\"4\"/></svg>"
	_check(store._write(store._file(String(sketch["key"])), {"svg": svg, "prompt": sketch["prompt"],
		"parts": sketch["parts"], "from": LetterSketches.fingerprint(sketch)}).is_empty(), "a drawing is written")
	_check(store.state(sketch) == "ready" and store.svgs([sketch]).get(String(sketch["key"])) == svg,
		"one drawn from its words is ready, and handed on")
	var moved := sketch.duplicate(true)
	moved["parts"] = ["the-dot", "the-cross"]
	_check(store.state(moved) == "stale", "the same sketch pointed at a new part is stale")
	_check(store.ink_state([]) == "ready", "the ink is ready with nothing to lay out")
	var items := LetterScript.items(LETTER, store.svgs([sketch]))
	_check(items.size() == 1 and store.ink_state(items) == "missing", "and missing before it is laid out")
	store._write(store.dir.path_join("ink.json"), {"items": [], "from": LetterSketches.ink_from(items)})
	var other := [{"id": "pzzz", "tex": "<svg/>", "mode": "figure"}]
	_check(store.ink_state(items) == "ready" and store.ink_state(other) == "stale",
		"ready for the drawings it was made from, stale for others")


func _card() -> void:
	print("-- what the card hands the reading")
	# (by path: the panels' card list names the UI, which compiles only once the autoloads are up)
	_check((load("res://src/ui/note_cards.gd").get("KEYS") as Array).has("letter"), "every panel builds its card")
	var script: GDScript = load("res://src/letter/letter_card.gd")
	var card: Control = script.call("for_note", {})
	card.apply({"seed": 42, "hand": "caveat", "writer": "claude", "writer_model": "m", "writer_effort": ""})
	var block: Dictionary = card.capture()
	_check(int(block["seed"]) == 42 and String(block["writer_model"]) == "m" and String(block["hand"]) == "caveat"
		and String((card.call("document") as Dictionary)["hand"]) == "caveat", "its block round trips, and the document carries its hand")
	card.apply({"hand": "comic"})
	_check(String(card.capture()["hand"]) == LetterHand.DEFAULT, "a hand it does not know is Kalam (the control)")
	card.apply({})
	_check(int(card.call("desk_seed")) == 1, "without a note, its desk is the first")
	var walk: TextWalk = load("res://src/letter/letter_walk.gd").new(card)
	var read: Dictionary = walk.spoken(LETTER, "A Title")
	_check(String(read["title"]).is_empty() and String(read["body"]) == LetterScript.speakable(LETTER, 1),
		"the walk reads the letter as the letter's own format does, with no title announced")
	card.free()
	_desk()
	_steps()
	_reopened()
	_finish()


## WHAT IS ON THE DESK AND ITS LIGHT, CHOSEN ON THE CARD: what the number drew until anything on the desk changes, then
## kept - the number moving them, never choosing them.
func _desk() -> void:
	print("-- what is on the desk, chosen")
	var script: GDScript = load("res://src/letter/letter_card.gd")
	var card: Control = script.call("for_note", {})
	# in the tree, as it is on a panel: a Range out of it never says its value changed
	root.add_child(card)
	card.apply({"seed": 42})
	var drawn := DeskLook.kinds(DeskLook.of(42))
	var mood := String(DeskLook.of(42)["mood"])
	var bank: Dictionary = card.get("_bank")
	var ticked := true
	for k in bank:
		ticked = ticked and (bank[k] as CheckBox).button_pressed == (k in drawn)
	_check(card.call("desk_things") == drawn and card.call("desk_mood") == mood and not card.capture().has("things")
		and bank.size() == DeskLook.THINGS.size() and ticked,
		"with nothing chosen the desk is what its number drew, ticked so on the bank of every thing (%s, %s)" % [", ".join(drawn), mood])
	# another number, whose own desk is not this one's
	var other := 43
	while DeskLook.kinds(DeskLook.of(other)) == drawn and String(DeskLook.of(other)["mood"]) == mood:
		other += 1
	(card.get("_seed_box") as SpinBox).value = other
	var block: Dictionary = card.capture()
	var its_own := DeskLook.kinds(DeskLook.of(other)) != drawn or String(DeskLook.of(other)["mood"]) != mood
	_check(int(block["seed"]) == other and block.get("things") == drawn and String(block["mood"]) == mood and its_own,
		"another number keeps what was on the desk and its light - the control, that number's own desk, is another (%s, %s)"
		% [", ".join(DeskLook.kinds(DeskLook.of(other))), String(DeskLook.of(other)["mood"])])
	# THE NUMBER IS THE DESK'S ALONE: the words written and said as they were
	var long := LETTER + "\n" + "I keep the tag by the lamp, where I can see it while I write to you about the days we had. ".repeat(6) + "\n"
	var walk: TextWalk = load("res://src/letter/letter_walk.gd").new(card)
	var at_other: String = walk.spoken(long, "")["body"]
	(card.get("_seed_box") as SpinBox).value = 777
	var doc_now: Dictionary = card.call("document")
	_check(int(doc_now["desk"]) == 777 and int(doc_now["seed"]) == int(card.call("hand_seed"))
		and String(walk.spoken(long, "")["body"]) == at_other and LetterScript.speakable(long, 777) != LetterScript.speakable(long, other),
		"the number is the desk's alone: the document's hand is the note's own, and the letter is said the same at either desk - the control, the hand seeded by the number, is said otherwise")
	(bank["dog_tag"] as CheckBox).button_pressed = true
	var light: OptionButton = card.get("_light_pick")
	var dusk := DeskLook.MOODS.keys().find("dusk")
	light.select(dusk)
	light.item_selected.emit(dusk)
	block = card.capture()
	var doc: Dictionary = card.call("document")
	_check((block["things"] as Array).has("dog_tag") and String(block["mood"]) == "dusk"
		and doc["things"] == block["things"] and String(doc["mood"]) == "dusk",
		"a thing ticked and a light picked are kept in the block, and the document a render reads carries them")
	# THE BLOCK AS THE NOTE KEEPS IT: written and read back
	var again: Control = script.call("for_note", {})
	again.apply(MiniYaml.parse(MiniYaml.emit({"letter": block}))["data"]["letter"])
	var none: Control = script.call("for_note", {})
	none.apply(MiniYaml.parse(MiniYaml.emit({"letter": {"seed": other, "things": [], "mood": "dusk"}}))["data"]["letter"])
	var odd: Control = script.call("for_note", {})
	odd.apply({"seed": other, "things": ["mug", "a spaceship"], "mood": "noon"})
	_check(again.call("desk_things") == block["things"] and again.call("desk_mood") == "dusk"
		and (none.call("desk_things") as Array).is_empty() and odd.call("desk_things") == ["mug"]
		and odd.call("desk_mood") == String(DeskLook.of(other)["mood"]),
		"the block round trips through the note's frontmatter, an empty desk too; a thing or a light it does not know is dropped")
	# WHAT IS WRITTEN ON THE INDEX CARDS
	var cards_row: Control = card.get("_card_row")
	var cards_box: TextEdit = card.get("_card_box")
	(bank["cards"] as CheckBox).button_pressed = false
	var hidden := not cards_row.visible
	(bank["cards"] as CheckBox).button_pressed = true
	var shown := cards_row.visible
	var address := "Send letters to:\nRyan Brooks\n1500 Southwest Chandler Avenue\nBend, OR 97702"
	cards_box.text = address
	cards_box.text_changed.emit()
	block = card.capture()
	doc = card.call("document")
	var picks := DeskLook.picks_of(doc)
	var back: Dictionary = MiniYaml.parse(MiniYaml.emit({"letter": block}))["data"]["letter"]
	var reread: Control = script.call("for_note", {})
	reread.apply(back)
	_check(hidden and shown and String(block["card_text"]) == address and String(doc["card_text"]) == address
		and String(picks.get("card_text", "")) == address and String(picks.get("hand", "")) == String(doc["hand"])
		and String(reread.capture()["card_text"]) == address and (reread.get("_card_box") as TextEdit).text == address,
		"the cards' box is shown with the cards ticked - the control, without them, hidden - and what is typed in it is kept in the block, carried by the document to the desk with the letter's hand, and round trips through the frontmatter, its lines and all")
	for c in [card, again, none, odd, reread]:
		(c as Node).free()


func _steps() -> void:
	print("-- the steps the note's other cards add")
	var note_upload = load("res://src/reading/note_upload.gd")
	var keep: String = note_upload.root
	note_upload.root = _scratch.path_join("readings")
	# THE NOTE, read by a panel built by hand (its _ready would start the voice host)
	var ed = load("res://src/reading/reading_panel.gd").new()
	ed.workspace = "reading"
	ed._build_panel()
	ed._doc._sync = false
	ed._doc._fields = {"title": "A Letter", "tags": "letters"}
	ed.note_path = _scratch.path_join("notes/A Letter.md")
	ed._text.text = LETTER
	var card = load("res://src/letter/letter_card.gd").for_note({"workspace": ed})
	ed._attach("youtube")
	var up = ed._note_upload
	var step = ed._youtube.episode_steps()[0]
	_check(ed.steps_by == "the Letter card" and up != null and not up.hosting(),
		"the card hands the reading how it goes out, so it lists the steps - the note its own episode")
	_tick_steps(card, up)
	_check(not card._added_rows.has_row(step.key) and not up._added_rows.has_row(step.key) and step.host.is_empty(),
		"control: with the box clear, no row anywhere")
	ed._youtube._write_tags.button_pressed = true
	_tick_steps(card, up)
	var feed = up.feed()
	_check(step.host == "the Letter card" and step.shown == feed and card._added_rows.has_row(step.key)
		and not up._added_rows.has_row(step.key), "ticked: its row is on the Letter card, and the YouTube card draws none")
	var at: int = card._added_rows.get_index()
	_check(at > (card._ink_state as Control).get_parent().get_index() and at < (card._gen_btn as Control).get_parent().get_index(),
		"the row stands under the Ink, above Generate")
	ed._youtube._refresh_tags()
	var line: String = ed._youtube._tags_note.text
	_check(line.contains("Tags row on the Letter card") and line.ends_with("and so does Generate, or an export that goes up."),
		"the YouTube card says where the row is and what makes it (%s)" % line)
	# GENERATE: the sketches first, then the note's tags
	card._sketches._jobs["held"] = {"id": "text-letter-card-check-sketch", "sketch": {}, "tries": 1}
	card._generate()
	_tick_steps(card, up)
	_check(step.state(feed) == "missing" and card._gen_btn.disabled and not card._stop_btn.disabled,
		"while a sketch is drawn, the tags wait for it (%s)" % step.state(feed))
	card._sketches._jobs.erase("held")
	_tick_steps(card, up)
	var r: Dictionary = card._added_rows.row(step.key)
	_check(step.state(feed) == "failed" and (r["state"] as Label).text.contains("read-only"),
		"then Generate starts the tags - here refused, read-only, and said on the Letter card's row (%s)" % (r["state"] as Label).text)
	# A JOB LANDED: its ✓, and the note's tags replaced
	step._errors.clear()
	AgentJobs._ended["text-letter-card-check"] = {"ok": true, "text": "{\"tags\": [\"a letter\", \"a cross\", \"a dot\"]}"}
	step._jobs[feed.folder()] = {"id": "text-letter-card-check", "feed": feed, "stamp": feed.stamp()}
	card._refresh()
	_check(card._added.busy(feed) and card._gen_btn.disabled and (r["redo"] as Button).disabled,
		"while its job runs, Generate and its ⟳ wait")
	_tick_steps(card, up)
	_check((r["state"] as Label).text == "✓ 3 tags: a letter, a cross, a dot" and ed._doc.field("tags") == "a letter, a cross, a dot"
		and not card._gen_btn.disabled, "landed: its ✓ on the Letter card, and the note's tags replaced (%s)" % (r["state"] as Label).text)
	# STOP stops a job writing them
	step._jobs[feed.folder()] = {"id": "text-letter-card-check-2", "feed": feed, "stamp": feed.stamp()}
	card._stop_btn.pressed.emit()
	_check(not step.busy(feed) and not card._added.busy(feed), "Stop stops the tags being written")
	card.free()
	ed.free()
	note_upload.root = keep


## A NOTE OPENED AGAIN KEEPS ITS MEDIUM: the old panel's card leaves the tree after the new one has come up.
func _reopened() -> void:
	print("-- a note opened again keeps its medium")
	var made: Array = []
	for _k in 2:
		var ed = load("res://src/reading/reading_panel.gd").new()
		ed.workspace = "reading"
		ed._build_panel()
		ed._doc._sync = false
		made.append([ed, load("res://src/letter/letter_card.gd").for_note({"workspace": ed})])
	var old: Node = made[0][1]
	var new: Node = made[1][1]
	# (by the tree: the autoloads are not up when this script compiles)
	var director: Node = root.get_node("Director")
	director.reset_show()
	root.add_child(old)
	var pinned: bool = director.resolved_medium() == "letter"
	# opened again: the new card comes up, and the old one, only queued to be freed, leaves after it
	director.reset_show()
	root.add_child(new)
	root.remove_child(old)
	var kept: String = director.resolved_medium()
	root.remove_child(new)
	var left: String = director.medium_override
	_check(pinned and kept == "letter" and left.is_empty(),
		"the old card leaving after the new one has come up leaves the letter the medium (%s) - the new card's own leaving lets it go (the control: %s)"
		% [kept, "\"%s\"" % left])
	for m in made:
		(m[1] as Node).free()
		(m[0] as Node).free()


## A refresh of the note and the card, as their _process makes one.
func _tick_steps(card: Object, up: Object) -> void:
	up.refresh()
	card._tick_steps()
	card._refresh()


func _finish() -> void:
	_rmrf(_scratch)
	LetterSketches.root = "user://letters"
	if _fails.is_empty():
		print("letter_card_check: ALL OK")
		quit(0)
	else:
		print("letter_card_check: %d FAILURE(S)" % _fails.size())
		for f in _fails:
			print("   ", f)
		quit(1)


func _rmrf(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for f in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(f))
	for d in DirAccess.get_directories_at(path):
		_rmrf(path.path_join(d))
	DirAccess.remove_absolute(path)
