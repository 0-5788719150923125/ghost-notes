extends SceneTree

## Does the Letter format hold together without an agent or TeX: its row, what the drawer is told, what is kept, and what its rows
## hand the reading ([LetterFormat], [LetterSketches], [LetterWalk]; next/letter.md)?
##
## - the row: a Letter is one of the Medium card's formats: offered on a reading and not to a song alone (control), its own rows
##   named by path; its pictures' look is a block of the note's (`illustrations:`) that comes with the Medium.
## - what the drawer is told ([constant LetterSketches.RULES]): the prompt renders whole, names each id a point needs, and on a
##   second try says what the last drawing lacked or why it could not be read (control: a first try says neither).
## - what lands: the SVG is taken out of an answer however wrapped (none from an answer with none, control); missing ids are found.
## - what is kept (under a scratch root): a sketch not drawn is missing, one drawn from its words ready, the same sketch pointed at
##   a new part stale; the ink is ready with nothing to lay out, missing before it is laid out, ready for its drawings, stale for others.
## - what the rows hand the reading (on the first frame: they name the Director): built for a note shown as a letter (none for a
##   tablet or a letter on a song alone: controls); their block round trips without a hand (the hand is the Medium card's
##   Handwriting; Random is drawn from the note's number; an unknown one is Kalam: control); the Medium's one block holds the format,
##   the hand and the rows' keys; the walk reads the letter as [method LetterScript.speakable] does, with no title announced.
## - the desk and its light are chosen on the card: with nothing chosen the desk is what its number drew, ticked on a bank of every
##   thing; another number keeps them and the light (control: that number's own desk is another) and is the desk's alone, the letter
##   said the same at either (control: the hand seeded by the number otherwise); ticks and light are kept in the block, carried by
##   the document and round trip through the frontmatter (an empty desk too; unknown things or lights are dropped). The index cards'
##   text box shows with the cards ticked and hides without them (control), is kept in the block and carried to the desk.
## - the steps the note's other cards add (the YouTube card's tags): the rows hand the reading how it goes out, so the Pipeline card
##   lists them under the Ink in the YouTube section only while the box is ticked (control: clear, no row). Generate makes it once
##   the sketches are drawn, here refused read-only and said on its row; a job landed gives ✓ and replaces the note's tags; Stop stops one.
## - a note opened again keeps its medium: the format is the Director's medium, set from the block, and the old Medium card leaving
##   after the new one applied the note leaves it a letter (control: a reset without the block is full frame).
##
##   godot --headless --path . --script tests/letter/letter_format_check.gd

const LETTER := """Dear Friend,

<!-- sketch: a cross and a dot on one line -->

A cross, and a dot.

<!-- point: sketch, the dot --> *That one is me.*

Yours,
"""

var _fails: Array = []
var _scratch := ""


func _init() -> void:
	_scratch = OS.get_user_data_dir().path_join("letter_format_check")
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
	_check(not Components.REGISTRY.has("letter") and Medium.pickable().has("letter") and Medium.mode_of("letter").is_empty()
		and (Components.WORKSPACES["reading"]["hosts"] as Array).has("medium"),
		"a Letter is a format of the Medium, which the reading shows - no component of its own, no mode")
	_check(Medium.offered(["audio", "reading"]).has("letter") and not Medium.offered(["audio"]).has("letter"),
		"offered on a reading, not to a song alone (the control)")
	# (not loaded here: the rows name the Director, and this runs before the autoloads are up)
	_check(ResourceLoader.exists(String(Medium.REGISTRY["letter"]["card"])) and String(Medium.REGISTRY["letter"]["card"]).ends_with("letter_format.gd"),
		"its own rows are named by path")
	_check(Components.blocks_of("medium").has("illustrations")
		and Components.with_parts(Components.attached_of({"voice": {}, "medium": {"format": "letter"}})).has("illustrations"),
		"its pictures' look is kept in the note (`illustrations:`), with the Medium")


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
	print("-- what the rows hand the reading")
	# (by path: the panels' card list names the UI, which compiles only once the autoloads are up)
	_check((load("res://src/ui/note_cards.gd").get("KEYS") as Array).has("medium")
		and not (load("res://src/ui/note_cards.gd").get("KEYS") as Array).has("letter"), "every panel builds the Medium card, and no Letter card")
	var director: Node = root.get_node("Director")
	director.reset_show()
	var medium_card: GDScript = load("res://src/show/medium_card.gd")
	var as_letter: Control = medium_card.new({"reading": true, "blocks": {"medium": {"format": "letter"}}})
	var as_tablet: Control = medium_card.new({"reading": true, "blocks": {"medium": {"format": "tablet"}}})
	var on_song: Control = medium_card.new({"reading": false, "blocks": {"medium": {"format": "letter", "seed": 9}}})
	var rows: Control = as_letter.call("own")
	_check(rows != null and String(rows.get_script().resource_path).ends_with("letter_format.gd")
		and as_tablet.call("own") == null and on_song.call("own") == null,
		"the Medium card builds the Letter's rows for a letter - none for a tablet, nor for a letter on a song alone (the controls)")
	on_song.call("apply", {"format": "letter", "seed": 9})
	_check(on_song.call("capture") == {"format": "letter", "seed": 9} and director.medium == "full",
		"a letter on a song alone is kept as it was, and not shown")
	var script: GDScript = load("res://src/letter/letter_format.gd")
	var card: Control = script.call("for_note", {})
	card.apply({"seed": 42, "hand": "patrick", "writer": "claude", "writer_model": "m", "writer_effort": ""})
	var block: Dictionary = card.capture()
	director.set_hand("caveat")
	_check(int(block["seed"]) == 42 and String(block["writer_model"]) == "m" and not block.has("hand")
		and String((card.call("document") as Dictionary)["hand"]) == "caveat",
		"its block round trips without a hand: the document carries the Medium card's Handwriting")
	director.set_hand("random")
	var drawn := String((card.call("document") as Dictionary)["hand"])
	_check(LetterHand.HANDS.has(drawn) and String((card.call("document") as Dictionary)["hand"]) == drawn,
		"Random is drawn from the note's own number, the same each time (%s)" % drawn)
	director.set("hand", "comic")
	_check(String((card.call("document") as Dictionary)["hand"]) == LetterHand.DEFAULT, "a hand it does not know is Kalam (the control)")
	director.set_hand("caveat")
	director.set_medium("letter")
	as_letter.call("apply", {"format": "letter", "hand": "caveat", "seed": 7, "mood": "dusk"})
	var whole: Dictionary = as_letter.call("capture")
	_check(String(whole["format"]) == "letter" and String(whole["hand"]) == "caveat" and int(whole["seed"]) == 7
		and String(whole["mood"]) == "dusk" and not whole.has("camera") and not whole.has("scene_hold"),
		"the Medium's one block holds the format, the hand and the rows' keys - and nothing the letter does not use")
	# the hand back to the default the walk is compared against (the Medium card's own, which the walk follows)
	director.set_hand(LetterHand.DEFAULT)
	card.apply({})
	_check(int(card.call("desk_seed")) == 1, "without a note, its desk is the first")
	var walk: TextWalk = load("res://src/letter/letter_walk.gd").new(card)
	var read: Dictionary = walk.spoken(LETTER, "A Title")
	_check(String(read["title"]).is_empty() and String(read["body"]) == LetterScript.speakable(LETTER, 1),
		"the walk reads the letter as the letter's own format does, with no title announced")
	for c in [card, as_letter, as_tablet, on_song]:
		(c as Node).free()
	director.reset_show()
	_desk()
	_steps()
	_reopened()
	_finish()


## What is on the desk and its light, chosen on the rows: what the number drew until anything on the desk changes, then kept.
func _desk() -> void:
	print("-- what is on the desk, chosen")
	var script: GDScript = load("res://src/letter/letter_format.gd")
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
	# the number is the desk's alone: the words written and said as they were
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
	# the block as the note keeps it: written and read back
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
	# what is written on the index cards
	var cards_box: TextField = card.get("_card_box")
	(bank["cards"] as CheckBox).button_pressed = false
	var hidden := not cards_box.visible
	(bank["cards"] as CheckBox).button_pressed = true
	var shown := cards_box.visible
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
		and String(reread.capture()["card_text"]) == address and (reread.get("_card_box") as TextField).text == address,
		"the cards' box is shown with the cards ticked - the control, without them, hidden - and what is typed in it is kept in the block, carried by the document to the desk with the letter's hand, and round trips through the frontmatter, its lines and all")
	for c in [card, again, none, odd, reread]:
		(c as Node).free()


func _steps() -> void:
	print("-- the steps the note's other cards add")
	var note_upload = load("res://src/reading/note_upload.gd")
	var keep: String = note_upload.root
	note_upload.root = _scratch.path_join("readings")
	# the note, read by a panel built by hand (its _ready would start the voice host)
	var ed = load("res://src/reading/reading_panel.gd").new()
	ed.workspace = "reading"
	ed._build_panel()
	ed._doc._sync = false
	ed._doc._fields = {"title": "A Letter", "tags": "letters"}
	ed.note_path = _scratch.path_join("notes/A Letter.md")
	ed._text.text = LETTER
	var card = load("res://src/letter/letter_format.gd").for_note({"workspace": ed})
	ed._add_block(card)
	ed._attach("youtube")
	var up = ed._note_upload
	var pipe = ed.pipeline()
	var step = ed._youtube.episode_steps()[0]
	_check(up != null and ed.episode_feed() == up.feed(), "the note is its own episode")
	_tick_steps(card, up, pipe)
	_check(pipe.row(step.key).is_empty() and step.shown == null, "control: with the box clear, no row")
	_check(not pipe.row("ink").is_empty() and not pipe.names().is_empty(), "the letter's own rows are on the Pipeline card: a sketch's, and the ink")
	ed._youtube._write_tags.button_pressed = true
	_tick_steps(card, up, pipe)
	var feed = up.feed()
	_check(step.shown == feed and not pipe.row(step.key, "YouTube").is_empty() and pipe.row(step.key, "Letter").is_empty(),
		"ticked: its row is the YouTube section's, the note its episode, never the Letter's")
	var names: Array = pipe.names()
	_check(names.find("Ink") < names.find("Tags"), "the words' own steps stand above what is made from them (%s)" % str(names))
	ed._youtube._refresh_tags()
	var line: String = ed._youtube._tags_note.text
	_check(line.contains("Tags row in the Pipeline") and line.ends_with("and so does Generate, or an export that goes up."),
		"the YouTube card says where the row is and what makes it (%s)" % line)
	# Generate: the sketches first, then the note's tags
	card._sketches._jobs["held"] = {"id": "text-letter-format-check-sketch", "sketch": {}, "tries": 1}
	pipe.generate()
	_tick_steps(card, up, pipe)
	_check(step.state(feed) == "missing" and pipe._generate.disabled and not pipe._stop.disabled,
		"while a sketch is drawn, the tags wait for it (%s)" % step.state(feed))
	card._sketches._jobs.erase("held")
	_tick_steps(card, up, pipe)
	var r: Dictionary = pipe.row(step.key)
	_check(step.state(feed) == "failed" and (r["text"] as Label).text.contains("read-only"),
		"then Generate starts the tags - here refused, read-only, and said on its row (%s)" % (r["text"] as Label).text)
	# a job landed: its ✓, and the note's tags replaced
	step._errors.clear()
	AgentJobs._ended["text-letter-card-check"] = {"ok": true, "text": "{\"tags\": [\"handwriting\", \"a cross\", \"a dot\"]}"}
	step._jobs[feed.folder()] = {"id": "text-letter-card-check", "feed": feed, "stamp": feed.stamp()}
	_check(pipe.busy(), "while its job runs, Generate waits")
	_tick_steps(card, up, pipe)
	r = pipe.row(step.key)
	_check((r["glyph"] as Label).text == "✓" and (r["text"] as Label).text == "3 tags: handwriting, a cross, a dot" and ed._doc.field("tags") == "handwriting, a cross, a dot",
		"landed: its ✓, and the note's tags replaced (%s)" % (r["text"] as Label).text)
	# Stop stops a job writing them
	step._jobs[feed.folder()] = {"id": "text-letter-card-check-2", "feed": feed, "stamp": feed.stamp()}
	pipe._stop.pressed.emit()
	_check(not step.busy(feed) and not pipe.busy(), "Stop stops the tags being written")
	card.free()
	ed.free()
	note_upload.root = keep


## A note opened again keeps its medium: the old panel's Medium card leaves the tree after the new one has applied the note.
func _reopened() -> void:
	print("-- a note opened again keeps its medium")
	var director: Node = root.get_node("Director")
	var medium_card: GDScript = load("res://src/show/medium_card.gd")
	var made: Array = []
	for _k in 2:
		var ed = load("res://src/reading/reading_panel.gd").new()
		ed.workspace = "reading"
		ed._build_panel()
		ed._doc._sync = false
		made.append([ed, medium_card.new({"reading": true, "workspace": ed, "blocks": {"medium": {"format": "letter"}}})])
	var old: Node = made[0][1]
	var new: Node = made[1][1]
	director.reset_show()
	root.add_child(old)
	old.call("apply", {"format": "letter"})
	var shown: bool = director.resolved_medium() == "letter"
	# opened again: the new card comes up and applies the note, and the old one, only queued to be freed, leaves after it
	director.reset_show()
	var bare: String = director.resolved_medium()
	root.add_child(new)
	new.call("apply", {"format": "letter"})
	root.remove_child(old)
	var kept: String = director.resolved_medium()
	root.remove_child(new)
	_check(shown and kept == "letter" and director.resolved_medium() == "letter" and String(director.medium_override).is_empty()
		and bare == "full",
		"the old card leaving after the new one has applied the note leaves it a letter (%s), and nothing is pinned - the control, a reset without the block, is %s"
		% [kept, bare])
	for m in made:
		(m[1] as Node).free()
		(m[0] as Node).free()
	director.reset_show()


## A refresh of the note and the rows, as their _process makes one.
func _tick_steps(card: Object, up: Object, pipe: Object) -> void:
	card._seen = card._body()
	card._listed = LetterScript.sketches(card._seen)
	up.refresh()
	pipe.refresh()


func _finish() -> void:
	_rmrf(_scratch)
	LetterSketches.root = "user://letters"
	if _fails.is_empty():
		print("letter_format_check: ALL OK")
		quit(0)
	else:
		print("letter_format_check: %d FAILURE(S)" % _fails.size())
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
