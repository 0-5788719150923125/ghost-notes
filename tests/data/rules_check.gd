extends SceneTree

## The gate of [Rules] - what the agents are told, read from rules/ - and of the block scalars
## [MiniYaml] reads them with. No renderer.
##
##   godot --headless --path . --script res://tests/data/rules_check.gd
##
## - EVERY RULES FILE PARSES, is a map of parts, and every item is a line, an empty line or a map of
##   known keys (when, say, insert, include, each); every `include` names a part that exists - against a
##   file naming one that does not, which the check finds.
## - EVERY PROMPT RENDERS WHOLE: the producer, the designer, the set dresser (with tools and without), a
##   reader's intro, card and close, every picture, what Grok is told beside them (a writer's
##   pictures, the painter's system prompt and references) and an episode's YouTube tags and painted thumbnail (the
##   writer's and the painter's), over a fixture plan, leave nothing unfilled
##   ([member Rules.missing] empty, no `{{` left) - against a part asked for a name nobody gives, which is
##   said.
## - THE RULES ARE EVERY SHOW'S (the user, 2026-10-08: "there shouldn't be ANY tarot-gated rules or logic in
##   the 'rules/' files"): no word of any rules file, a flag's name included, names a kind of card - tarot,
##   its arcana, its suits - and no prompt rendered over a fixture that names none says one; what a show's
##   cards are is its brief's. The control: a part that says "tarot" is found. NOR A KIND OF WORK
##   (next/table_work.md; the user, 2026-10-25: "I don't want to implement a baking mode, or an alchemy mode"):
##   no rules file says alchemy, a potion, baking or a jigsaw - the brief says what the work is. The control: a
##   part that says "potion" is found. And the work's prompts - the producer told of work, the set dresser
##   given the plan's work, the puppeteer with tools and without, a reader's work passage and an intro and a
##   close with acts - render whole.
## - THE WORDS' OWN MARKS: a value filled in, a section kept only when its flag holds and an inverted one
##   only when it does not, a list of lines walked, a tag alone on its line taking its line with it, a
##   flag on an item and its negation - each against the other side.
## - BLOCK SCALARS: `>-` folds lines with spaces and keeps a blank line as a break, `|` keeps lines and one
##   final break, a `#` inside one is text and `...` indented is text; `|+` is refused, and `...` at the
##   start of a line is still a document's end - the controls.

const FixtureDeck := preload("res://tests/fixture_deck.gd")
## What only a kind of card's own show may say: the rules name none of them.
const KINDS := ["tarot", "arcana", "rider-waite", "pentacle"]
## ...and what only a kind of work's own show may say (next/table_work.md).
const WORKS := ["alchemy", "alchemist", "potion", "cauldron", "baking", "bakery", "jigsaw", "dragon"]

var _fails := 0


func _init() -> void:
	_run.call_deferred()


func _ok(cond: bool, what: String) -> void:
	if not cond:
		_fails += 1
		print("  FAIL: " + what)


func _run() -> void:
	for check in [_blocks, _marks, _files, _every_show, _prompts]:
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


## THE RULES ARE EVERY SHOW'S: every word of every file, flags and comments' neighbors alike (a comment is
## the reason, not a rule, and MiniYaml drops it).
func _every_show() -> bool:
	for f in _rules_files("res://rules"):
		var got := MiniYaml.parse(FileAccess.get_file_as_string(f))
		if bool(got["ok"]):
			for hit in _kinds_named(got["data"]):
				_ok(false, "%s names a kind of card: %s" % [f.trim_prefix("res://rules/"), hit])
	# the control: a part that says it, in a flag and in its words
	_ok(_kinds_named({"p": ["a line", {"when": "!tarot", "say": "a Rider-Waite deck"}]}).size() == 2, "a part naming tarot was not found")
	# NOR A KIND OF WORK: every word of every file
	for f in _rules_files("res://rules"):
		var got := MiniYaml.parse(FileAccess.get_file_as_string(f))
		if bool(got["ok"]):
			for hit in _named(got["data"], WORKS):
				_ok(false, "%s names a kind of work: %s" % [f.trim_prefix("res://rules/"), hit])
	_ok(_named({"p": [{"say": "stir the potion"}]}, WORKS).size() == 1, "the control: a part naming a potion was not found")
	return true


## Every word of [param v] naming one of [param words].
func _named(v: Variant, words: Array) -> PackedStringArray:
	var out := PackedStringArray()
	if v is String:
		for k in words:
			var at := (v as String).to_lower().find(k)
			if at >= 0:
				out.append("%s, in \"...%s...\"" % [k, (v as String).substr(maxi(0, at - 30), 70).replace("\n", " ")])
				break
	elif v is Array:
		for x in v:
			out.append_array(_named(x, words))
	elif v is Dictionary:
		for k in v:
			out.append_array(_named(v[k], words))
	return out


func _kinds_named(v: Variant) -> PackedStringArray:
	var out := PackedStringArray()
	if v is String:
		for k in KINDS:
			var at := (v as String).to_lower().find(k)
			if at >= 0:
				out.append("%s, in \"...%s...\"" % [k, (v as String).substr(maxi(0, at - 30), 70).replace("\n", " ")])
				break
	elif v is Array:
		for x in v:
			out.append_array(_kinds_named(x))
	elif v is Dictionary:
		for k in v:
			out.append_array(_kinds_named(v[k]))
	return out


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
	var card := {"name": "The Moth", "group": "Night", "meaning": "a leap", "art": "a cliff", "reversed": true, "jumper": false,
		"booklet": {"keywords": ["a", "b"], "upright": "up", "reversed": "down"}}
	var texts: Array = []
	for chooses in [false, true]:
		texts.append(TablePrompts.producer("Show", "a brief", 7, CardTable.FACES, CardTable.FRAMES, [], FixtureDeck.cards().slice(0, 12), chooses)["prompt"])
	_ok(String(texts[0]).contains("`text` \"front\""), "the producer can choose details on the front")
	for text in ["booklet", "back", "front"]:
		texts.append(TablePrompts.designer("Show", "## Format\na show", look, card, true, [], text)["prompt"])
	var front_prompt := String(texts[texts.size() - 1])
	_ok(front_prompt.contains("PRINTED WITH THE ART ON ITS FRONT") and front_prompt.contains("shared artwork"),
		"the designer is told how to write a card with front details and a shared back")
	for looks in [0, 40]:
		texts.append(TablePrompts.set_dresser("Show", "a brief", plan, 7, CardTable.headroom(7), ["a bell"], true, looks, ["fog"], "by me",
			["a table"], ["a light"], true, false)["prompt"])
	for step in ["intro", "1", "2", "close"]:
		var upto := 0 if step == "intro" else (3 if step == "close" else int(step))
		texts.append(TablePrompts.reader("Show", "a brief", plan, step, ["hello"], [card, card, card].slice(0, upto), 3, true, [], [], ["Moth"])["prompt"])
	var front_plan := plan.duplicate(true)
	front_plan["staging"] = {"source": "box", "text": "front"}
	front_plan["inventory"] = {"count": 12, "printings": {"": 12}}
	var front_reader := String(TablePrompts.reader("Show", "a brief", front_plan, "1", ["hello"], [card], 3,
		true, [], [], ["Moth"])["prompt"])
	_ok(front_reader.contains("share the front") and not front_reader.contains("<back>"),
		"the reader sees the details on the front")
	_ok(front_reader.contains("12 cards in all") and front_reader.contains("Usually do not mention the total"),
		"the reader can check the story against the box without announcing a count")
	texts.append(TablePrompts.card_image(look, card, "a cliff", "/x.png", true, 2))
	# ...a painting sent back, a designer shown the cards before it, the art director, a reader of a card
	# read with the ones down whose painting falls short
	texts.append(TablePrompts.card_image(look, card, "a cliff", "/x.png", true, 2, false, PackedStringArray(["the wing is missing"])))
	texts.append(TablePrompts.designer("Show", "a brief", look, card, true, [], "booklet", [{"k": 1, "name": "The Owl", "art": "an owl"}])["prompt"])
	for earlier in [0, 1, 2]:
		texts.append(TablePrompts.art_director("Show", "a brief", look, card, earlier, "back")["prompt"])
	texts.append(TablePrompts.reader("Show", "a brief", plan, "2", ["hello"], [card, card], 3, true, [], [], ["Moth"], true, true,
		["the wing is missing"])["prompt"])
	# THE WORK AT THE TABLE (next/table_work.md): a plan with work, its set dresser, its puppeteer with tools and
	# without, a work passage and an intro and a close done over acts
	var worked := plan.duplicate(true)
	worked["work_intro"] = "the kettle is filled"
	worked["work_close"] = "the cups are set out"
	((worked["spread"] as Dictionary)["positions"][1] as Dictionary)["work"] = "a leaf is dropped into the cup"
	var acts := [{"name": "drop-leaf", "about": "a leaf is dropped into the cup", "length": 4.0, "under": false},
		{"name": "stir", "about": "the tea is stirred", "length": 12.0, "under": true}]
	texts.append(TablePrompts.set_dresser("Show", "a brief", worked, 7, CardTable.headroom(7), ["a bell"], true, 40, ["fog"], "by me",
		["a table"], ["a light"], true, false)["prompt"])
	_ok(String(texts[texts.size() - 1]).contains("THE WORK.") and not String(texts[5]).contains("THE WORK."),
		"the set dresser is told the plan's work (and, the control, not when there is none)")
	for looks in [0, 30]:
		texts.append(TablePrompts.puppeteer("Show", "a brief", worked, 7, [card, card, card], "- \"a cup\": stands at [0, 0] cm", looks)["prompt"])
	texts.append(TablePrompts.reader("Show", "a brief", worked, "work:2", ["hello"], [card, card], 3, false, [], [], ["Moth"],
		true, false, [], acts)["prompt"])
	var work_words := String(texts[texts.size() - 1])
	_ok(work_words.contains("the work begins at the table") and work_words.contains("drop-leaf") and not work_words.contains("HOW EARLIER EPISODES MET"),
		"a work passage is not told its acts as the work it talks through")
	for step in ["intro", "close"]:
		texts.append(TablePrompts.reader("Show", "a brief", worked, step, ["hello"], [card, card, card].slice(0, 0 if step == "intro" else 3), 3,
			false, [], [], ["Moth"], true, false, [], acts)["prompt"])
	texts.append(TablePrompts.back_image(look, "/x.png", true, true))
	# a symmetric back is never made by blending the picture with its half turn (feedback 0012: every
	# mark printed twice); the control is a back that is not asked to be symmetric
	var symmetric := TablePrompts.back_image(look, "/x.png", true)
	_ok(symmetric.contains("EXACTLY SYMMETRIC") and symmetric.contains("NEVER make it symmetric by blending"),
		"a back asked to be symmetric is told never to blend the picture with a rotated copy")
	_ok(not TablePrompts.back_image(look, "/x.png", false).contains("blending"),
		"control: a back not asked to be symmetric is not told about blending")
	# a back cut to a shaped window is told to keep its marks off the edge (feedback 0015: an arch sliced the
	# wings the painter ran to the border); the control is a plain rectangle
	var arched := look.duplicate(true)
	arched["frame"] = {"window": "arch"}
	var shaped_back := TablePrompts.back_image(arched, "/x.png", true)
	_ok(shaped_back.contains("an arched window") and shaped_back.contains("outer sixth"),
		"a back cut to an arch is told the window and to keep its marks inside it")
	_ok(not TablePrompts.back_image(look, "/x.png", true).contains("outer sixth"),
		"control: a back with a plain rectangle window is not told to keep clear of its edge")
	texts.append(TablePrompts.surface_image(look, "/x.png"))
	texts.append(TablePrompts.height_image(look, "/x.png"))
	texts.append(TablePrompts.backdrop_image(look, "/x.png"))
	texts.append(TablePrompts.show_context("Show", "a brief"))
	# what Grok is told beside them: a writer's pictures, the painter's system prompt and its references
	var shown := "res://project.godot"
	texts.append(TextGen.Grok.compose({"dir": "/x", "prompt": texts[6], "images": [{"path": shown, "label": "The card:"}]})["message"])
	texts.append(Rules.say("agents/grok.painter"))
	texts.append(ImageGen.Grok.compose({"dir": "/x", "prompt": TablePrompts.card_image(look, card, "a cliff", "/x.png", true, 2),
		"refs": [shown, shown]})["message"])
	# what the YouTube card's step tells the show's writer of an episode, for its tags
	var tags_prompt: Dictionary = load("res://src/export/youtube_tags.gd").prompt("Show", "An Episode", "a description",
		PackedStringArray(["a", "b"]), "the words of a reading")
	texts.append(String(tags_prompt["system"]) + "\n" + String(tags_prompt["prompt"]))
	# ...and of its painted thumbnail: the writer shown the episode's pictures, and the painter
	var Thumb: GDScript = load("res://src/export/youtube_thumbnail.gd")
	var thumb_prompt: Dictionary = Thumb.prompt("Show", "An Episode", "a description", "the words of a reading",
		PackedStringArray([shown]))
	texts.append(String(thumb_prompt["system"]) + "\n" + String(thumb_prompt["prompt"]))
	texts.append(Thumb.painting({"picture": "a lantern on a table", "words": "THE END", "after": [shown]}, false))
	# A LIKENESS'S AGENT (rules/likeness/): the audit of a set, whole, over a made set
	var a_set := {"id": "set-x", "minutes": 12.5, "shots": [{"vid": "v", "n": 0}, {"vid": "v", "n": 1}]}
	for more in [false, true]:
		var au := ActorPrompts.audit("An Actor", a_set, more)
		texts.append(String(au["system"]) + "\n" + String(au["prompt"]))
	var re := ActorPrompts.rest("An Actor", 12)
	texts.append(String(re["system"]) + "\n" + String(re["prompt"]))
	_ok((ActorPrompts.land_rest({"rest": [3, 3, 0, 13, 1.0]}, 12)["rest"] as Array) == [2, 0]
		and ActorPrompts.land_rest({"stills": [1]}, 12).has("error"), "the answer of At rest was not made sound")
	_ok(Rules.missing.is_empty(), "rendering every prompt left these unfilled: %s" % str(Rules.missing.slice(0, 6)))
	for t in texts:
		_ok(_kinds_named(t).is_empty(), "a prompt over a fixture naming no kind of card names one: %s" % ", ".join(_kinds_named(t)))
	for t in texts:
		_ok(not String(t).contains("{{") and String(t).length() > 200, "a prompt with a mark left in it, or empty: %s" % String(t).left(120))
	# the control: a part asked for with a name nobody gives
	Rules.clear()
	Rules.say("table/set_dresser.box", {"box_x": 15, "box_z": 22})
	_ok(Rules.missing.size() == 1 and Rules.missing[0].ends_with("box_y"), "a name nobody gave was not said: %s" % str(Rules.missing))
	Rules.clear()
	return true
