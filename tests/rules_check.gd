extends SceneTree

## The gate of [Rules] - what the agents are told, read from rules/ - and of the block scalars
## [MiniYaml] reads them with. No renderer.
##
##   godot --headless --path . --script res://tests/rules_check.gd
##
## - EVERY RULES FILE PARSES, is a map of parts, and every item is a line, an empty line or a map of
##   known keys (when, say, insert, include, each); every `include` names a part that exists - against a
##   file naming one that does not, which the check finds.
## - EVERY PROMPT RENDERS WHOLE: the producer, the designer, the set dresser (with tools and without), a
##   reader's intro, card and close, and every picture, over a fixture plan, leave nothing unfilled
##   ([member Rules.missing] empty, no `{{` left) - against a part asked for a name nobody gives, which is
##   said.
## - THE WORDS' OWN MARKS: a value filled in, a section kept only when its flag holds and an inverted one
##   only when it does not, a list of lines walked, a tag alone on its line taking its line with it, a
##   flag on an item and its negation - each against the other side.
## - BLOCK SCALARS: `>-` folds lines with spaces and keeps a blank line as a break, `|` keeps lines and one
##   final break, a `#` inside one is text and `...` indented is text; `|+` is refused, and `...` at the
##   start of a line is still a document's end - the controls.

var _fails := 0


func _init() -> void:
	_run.call_deferred()


func _ok(cond: bool, what: String) -> void:
	if not cond:
		_fails += 1
		print("  FAIL: " + what)


func _run() -> void:
	for check in [_blocks, _marks, _files, _prompts]:
		var done: Variant = (check as Callable).call()
		_ok(done == true, "%s stopped part way (a script error - see above)" % (check as Callable).get_method())
	print("rules_check: %s (%d failure%s)" % ["ALL OK" if _fails == 0 else "FAILED", _fails, "" if _fails == 1 else "s"])
	quit(1 if _fails > 0 else 0)


func _blocks() -> bool:
	var got := MiniYaml.parse("a: >-\n  one two\n  three #not a comment\n\n  four\nb: |\n  x\n    y\nc:\n  - >-\n    ...and on\n  # a comment\n  - plain\n")
	_ok(bool(got["ok"]), "block scalars refused: %s" % String(got["error"]))
	if bool(got["ok"]):
		var d: Dictionary = got["data"]
		_ok(String(d["a"]) == "one two three #not a comment\nfour", "folded: %s" % str(d["a"]))
		_ok(String(d["b"]) == "x\n  y\n", "literal: %s" % str(d["b"]))
		_ok(d["c"] is Array and (d["c"] as Array).size() == 2 and String(d["c"][0]) == "...and on", "a list of blocks: %s" % str(d["c"]))
	_ok(not bool(MiniYaml.parse("a: |+\n  x\n")["ok"]), "a keep-chomping block was read")
	_ok(not bool(MiniYaml.parse("a: 1\n...\n")["ok"]), "a document's end at the start of a line was read as text")
	return true


func _marks() -> bool:
	Rules.clear()
	var v := {"name": "Moth", "on": true, "off": false, "list": [{"x": "1"}, {"x": "2"}], "blank": ""}
	_ok(Rules.fill("hi {{name}}", v) == "hi Moth", "a value is not filled in")
	_ok(Rules.fill("a{{#on}}b{{/on}}c{{#off}}d{{/off}}", v) == "abc", "a section ignores its flag")
	_ok(Rules.fill("a{{^on}}b{{/on}}c{{^off}}d{{/off}}", v) == "acd", "an inverted section ignores its flag")
	_ok(Rules.fill("a{{#blank}}b{{/blank}}{{^blank}}e{{/blank}}", v) == "ae", "an empty text is not false")
	_ok(Rules.fill("{\n{{#on}}\n  x,\n{{/on}}\n  y", v) == "{\n  x,\n  y", "a tag alone on its line keeps its line")
	_ok(Rules.fill("{\n{{#off}}\n  x,\n{{/off}}\n  y", v) == "{\n  y", "a section off leaves its lines")
	_ok(Rules.missing.is_empty(), "filled with nothing missing, yet said: %s" % str(Rules.missing))
	_ok(Rules.fill("{{nobody}}", v, "t") == "{{nobody}}" and Rules.missing.size() == 1, "a name nobody gives is not said")
	Rules.clear()
	var items := [{"when": "on", "say": "yes"}, {"when": "!on", "say": "no"}, {"when": ["on", "!off"], "say": "both"},
		{"each": "list", "say": "- {{x}}"}, "", {"insert": "name"}]
	_ok(Rules._render(items, v, "t.p") == "yes\nboth\n- 1\n- 2\n\nMoth", "the items read %s" % Rules._render(items, v, "t.p").c_escape())
	return true


func _files() -> bool:
	Rules.clear()
	var files := _rules_files("res://rules")
	_ok(files.size() >= 6, "%d rules files" % files.size())
	for f in files:
		var name: String = f.trim_prefix("res://rules/").trim_suffix(".yaml")
		var got := MiniYaml.parse(FileAccess.get_file_as_string(f))
		_ok(bool(got["ok"]) and got["data"] is Dictionary, "%s does not parse: %s" % [name, String(got["error"])])
		if not bool(got["ok"]):
			continue
		var data: Dictionary = got["data"]
		for part in data:
			for problem in _part_problems(data, data[part]):
				_ok(false, "%s.%s: %s" % [name, part, problem])
	# the control: an include of a part that is not there
	var bad := {"p": [{"include": "nowhere"}]}
	_ok(not _part_problems(bad, bad["p"]).is_empty(), "an include of a missing part was not found")
	return true


func _part_problems(data: Dictionary, part: Variant) -> PackedStringArray:
	var out := PackedStringArray()
	if part is String or part == null:
		return out
	if not (part is Array):
		out.append("a part is neither text nor a list")
		return out
	for item in part:
		if item == null or item is String:
			continue
		if not (item is Dictionary):
			out.append("an item that is not a line or a map: %s" % str(item))
			continue
		for k in item:
			if not (String(k) in ["when", "say", "insert", "include", "each"]):
				out.append("an item's key \"%s\" means nothing" % String(k))
		var inc := String((item as Dictionary).get("include", ""))
		if not inc.is_empty() and not inc.contains("/") and not data.has(inc):
			out.append("includes \"%s\", which is not a part" % inc)
	return out


func _rules_files(dir: String) -> PackedStringArray:
	var out := PackedStringArray()
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".yaml"):
			out.append(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		out.append_array(_rules_files(dir.path_join(d)))
	return out


## Every prompt over a fixture plan: nothing left unfilled.
func _prompts() -> bool:
	Rules.clear()
	var look := {"deck_name": "The Test Deck", "deck_style": "ink and wash", "palette": ["#112233", "#ddeeff"], "card_back": "a star",
		"surface": "linen", "setting": "a kitchen", "light": {"kind": "a lamp"}, "candles": 2, "page": "ledger"}
	var plan := {"episode_title": "An Episode", "audience": "you", "topic": "a topic", "premise": "an angle", "reader_mood": "calm",
		"running_bit": "a bit", "look": look, "spread": {"name": "Three", "positions": [{"name": "past", "asks": "what was"},
			{"name": "now", "asks": "what is", "comes": "swept"}, {"name": "next", "asks": "what comes", "comes": "swept"}]}}
	var card := {"name": "The Fool", "group": "", "meaning": "a leap", "art": "a cliff", "reversed": true, "jumper": false,
		"booklet": {"keywords": ["a", "b"], "upright": "up", "reversed": "down"}}
	var texts: Array = []
	for chooses in [false, true]:
		texts.append(CardPrompts.producer("Show", "a brief", 7, 3, true, CardTable.FACES, CardTable.FRAMES, [], CardDeck.standard(), chooses)["prompt"])
	for text in ["booklet", "back"]:
		texts.append(CardPrompts.designer("Show", "## Format\na show", look, card, true, [], text)["prompt"])
	for looks in [0, 40]:
		texts.append(CardPrompts.set_dresser("Show", "a brief", plan, 7, CardTable.headroom(7), ["a bell"], true, looks, ["fog"], "by me",
			["a table"], ["a light"], true, false)["prompt"])
	for step in ["intro", "1", "2", "close"]:
		var upto := 0 if step == "intro" else (3 if step == "close" else int(step))
		texts.append(CardPrompts.reader("Show", "a brief", plan, step, ["hello"], [card, card, card].slice(0, upto), 3, true, [], [], ["Moth"])["prompt"])
	texts.append(CardPrompts.card_image(look, card, "a cliff", "/x.png", true, 2))
	texts.append(CardPrompts.back_image(look, "/x.png", true, true))
	texts.append(CardPrompts.surface_image(look, "/x.png"))
	texts.append(CardPrompts.height_image(look, "/x.png"))
	texts.append(CardPrompts.backdrop_image(look, "/x.png"))
	_ok(Rules.missing.is_empty(), "rendering every prompt left these unfilled: %s" % str(Rules.missing.slice(0, 6)))
	for t in texts:
		_ok(not String(t).contains("{{") and String(t).length() > 200, "a prompt with a mark left in it, or empty: %s" % String(t).left(120))
	# the control: a part asked for with a name nobody gives
	Rules.clear()
	Rules.say("cards/set_dresser.box", {"box_x": 15, "box_z": 22})
	_ok(Rules.missing.size() == 1 and Rules.missing[0].ends_with("box_y"), "a name nobody gave was not said: %s" % str(Rules.missing))
	Rules.clear()
	return true
