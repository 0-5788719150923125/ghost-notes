extends SceneTree

## Does the Letter component hold together without an agent or TeX: its row, what the drawer is told,
## what is kept, and what the card hands the reading ([LetterCard], [LetterSketches], [LetterWalk];
## next/letter.md)?
##
## - THE ROW: a Letter brings a Voice and is run by the reading, which shows its card; it holds the
##   note's presentation, so a Picture on a letter is refused with a sentence; its medium is its own, never
##   offered by a picker.
## - WHAT THE DRAWER IS TOLD ([constant LetterSketches.RULES]): the prompt renders whole, names each id a
##   point needs and what is said while it is drawn - and on a second try what the last drawing lacked or
##   why it could not be read (the control: a first try says neither).
## - WHAT LANDS: the SVG is taken out of an answer however it is wrapped (none from an answer with none, the
##   control), and the ids a drawing lacks are found and the ones it has are not.
## - WHAT IS KEPT (under a scratch root): a sketch not drawn is missing, one drawn from its words is ready,
##   and the same sketch pointed at a new part is stale; the ink is ready with nothing to lay out, missing
##   before it is laid out, ready for the drawings it was made from and stale for others.
## - WHAT THE CARD HANDS THE READING (on the first frame: the card names the Director): its block round
##   trips; without a note its desk is the first; the walk reads the letter as [method
##   LetterScript.speakable] does, with no title announced.
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
	card.apply({"seed": 42, "writer": "claude", "writer_model": "m", "writer_effort": ""})
	var block: Dictionary = card.capture()
	_check(int(block["seed"]) == 42 and String(block["writer_model"]) == "m", "its block round trips")
	card.apply({})
	_check(int(card.call("desk_seed")) == 1, "without a note, its desk is the first")
	var walk: TextWalk = load("res://src/letter/letter_walk.gd").new(card)
	var read: Dictionary = walk.spoken(LETTER, "A Title")
	_check(String(read["title"]).is_empty() and String(read["body"]) == LetterScript.speakable(LETTER, 1),
		"the walk reads the letter as the letter's own format does, with no title announced")
	card.free()
	_finish()


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
