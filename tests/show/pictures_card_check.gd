extends SceneTree

## pictures_card_check - THE NOTE'S PICTURES, ONE CARD ([PicturesCard]; 2026-11-06, the user: "if we are generating images,
## we are doing it from a unified place: not from a bunch of disparate cards. And the reason is maintainability").
##
##   godot --headless --path . --script tests/show/pictures_card_check.gd
##
## WHICH MARKS ARE PICTURES IS THE PRESENTATION'S ([method Medium.pictures_of]): a novel prints every image mark, a sketch
## among them; a letter never its sketch, which its pen draws (THE CONTROL: the novel's has it); a dispatch desk finds a
## picture pinned to a screen (THE CONTROL: the plain image marks miss it); a tablet adds its real pages, captured, with
## their `url`; the full frame shows none.
##
## IT COMES WITH WHAT SHOWS PICTURES ([method Components.with_parts]): beside a Picture, a Letter, a Dispatch desk - never
## beside a voice alone or a show at a table (THE CONTROL) - and it has no × of its own, where the Letter's card has one.
##
## ONE CARD: built beside a Letter's, a Dispatch desk's and a Picture's cards, none of which carries a list of pictures of
## its own (THE CONTROL: the Pictures card holds one).
##
## IT STANDS ONLY WHILE THE MEDIUM SHOWS PICTURES: pinned to a letter, the card stands, its list the letter's pictures and
## not its sketch, and its Pipeline section is listed; under the full frame the card and its section are put away (THE
## CONTROL); under a novel both are back, the sketch with them.
##
## GENERATE ALL IS ON THE CARD, saying how many have none - a page captured is never counted - and grayed with none to
## paint; read-only, it is grayed and, pressed, says why. It is the Pipeline card's Generate: one function behind both.

const WORDS := ("Words. <!-- image: A harbor at dawn. --> More.\n\n<!-- sketch: a tree of dots -->\n\n"
	+ "Then. <!-- image: A storm over the bay. -->\n")
const DESK := ("<!-- speaker: Control -->\nThe feed. <!-- image (feed): The car park from above. -->\n\n"
	+ "<!-- image (full): Dawn over the field. -->\n")
const TABLET := ("<!-- url: news.test/a -->\n\n# An article\n\nRead this. <!-- image: A harbor at dawn. -->\n\n"
	+ "Then [the listing](https://www.shop.test/item/42).\n\n<!-- url: https://www.shop.test/item/42 -->\n")

var _fails := 0


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var settings := root.get_node_or_null("Settings")
	if settings != null:
		settings.set("_read_only", true)
	Illustrations.use_for_test({}, true)
	_which()
	_comes_with()
	await _one_card()
	Illustrations.use_for_test()
	print("pictures_card_check: %s" % ("ALL OK" if _fails == 0 else "%d FAILED" % _fails))
	quit(0 if _fails == 0 else 1)


## WHICH MARKS ARE PICTURES IS THE PRESENTATION'S
func _which() -> void:
	var book := _prompts(Medium.pictures_of("book", WORDS))
	_ok(book == ["A harbor at dawn.", "a tree of dots", "A storm over the bay."], "a novel prints every image mark, the sketch among them: %s" % str(book))
	var letter := _prompts(Medium.pictures_of("letter", WORDS))
	_ok(letter == ["A harbor at dawn.", "A storm over the bay."], "a letter's pictures, never its sketch (the control above has it): %s" % str(letter))
	var desk := _prompts(Medium.pictures_of("dispatch", DESK))
	_ok(desk == ["The car park from above.", "Dawn over the field."], "a dispatch desk finds the picture pinned to a screen: %s" % str(desk))
	_ok(_prompts(Manuscript.images(DESK)) == ["Dawn over the field."], "the control: the plain image marks miss it")
	var tab := Medium.pictures_of("tablet", TABLET)
	_ok(tab.size() == 2 and String(tab[0]["prompt"]) == "A harbor at dawn." and String(tab[1].get("url", "")) == "https://www.shop.test/item/42",
		"a tablet adds its real page, captured, with its url: %s" % str(_prompts(tab)))
	_ok(Medium.pictures_of("full", WORDS).is_empty() and Medium.pictures_of("comic", WORDS).is_empty(), "the full frame and the comic show none")


## IT COMES WITH WHAT SHOWS PICTURES
func _comes_with() -> void:
	for host in ["picture", "letter", "dispatch"]:
		_ok(Components.with_parts(["text", "voice", host]).has("illustrations"), "it comes with a %s" % host)
	_ok(not Components.with_parts(["text", "voice"]).has("illustrations") and not Components.with_parts(["text", "table", "voice"]).has("illustrations"),
		"the control: never beside a voice alone, or a show at a table")
	_ok(Components.attach_blocks("illustrations").is_empty() and not Components.detach_blocker("illustrations", ["text", "voice", "letter"]).is_empty(),
		"never attached or taken off by itself")


## ONE CARD, STANDING ONLY WHILE THE MEDIUM SHOWS PICTURES. (Nothing here is typed by a card's class: a `--script` gate
## compiles before the autoloads, and a card that names one would be loaded broken.)
func _one_card() -> void:
	var director: Node = root.get_node("Director")
	var cards: GDScript = load("res://src/ui/note_cards.gd")
	var panel = load("res://src/ui/side_panel.gd").new()
	panel.detach = func(_key: String) -> void: pass
	root.add_child(panel)
	var have := Components.with_parts(["text", "voice", "letter"])
	var built: Dictionary = cards.build(panel, have, {"only": ["letter", "illustrations"]})
	var pictures = built.get("illustrations")
	_ok(pictures != null and built.has("letter"), "a Letter's panel builds the Pictures card beside the Letter's: %s" % str(built.keys()))
	if pictures == null:
		panel.queue_free()
		return
	var crosses: Array = panel._detach_buttons.map(func(d: Array) -> String: return String(d[1]))
	_ok(crosses.has("letter") and not crosses.has("illustrations"), "the Letter's card has its ×, the Pictures card none: %s" % str(crosses))
	_ok(_lists(built["letter"]) == 0 and _lists(pictures) == 1, "the Letter's card carries no list of its own, the Pictures card one")
	for key in ["dispatch", "picture"]:
		var other = cards.make(key, {"reading": true})
		_ok(_lists(other) == 0, "...nor does a %s's card" % key)
		other.free()
	var pin := RefCounted.new()
	director.pin_medium("letter", pin)
	pictures.set_script_text(WORDS)
	var card = pictures._own_card()
	var section = pictures.pipeline()
	var listed := _prompts(pictures.list()._images)
	_ok(card != null and card.visible and listed == ["A harbor at dawn.", "A storm over the bay."] and section.shown(),
		"pinned to a letter: the card stands, listing its pictures and not its sketch, and its section is listed: %s" % str(listed))
	await process_frame
	var all = pictures.list()._all
	_ok(all.visible and all.text == "Generate all (2)" and all.disabled, "Generate all says how many have none - read-only, grayed: %s" % all.text)
	all.pressed.emit()
	_ok(pictures.list()._status.text.contains("read-only"), "pressed read-only, it says why: %s" % pictures.list()._status.text)
	director.pin_medium("full", pin)
	pictures._follow(false)
	_ok(not card.visible and not section.shown() and pictures.list()._images.is_empty(),
		"the control: under the full frame the card and its section are put away")
	director.pin_medium("book", pin)
	pictures._follow(false)
	_ok(card.visible and section.shown() and pictures.list()._images.size() == 3, "under a novel both are back, the sketch with them")
	var made := "user://pictures_card_check.png"
	Image.create(4, 4, false, Image.FORMAT_RGB8).save_png(made)
	Illustrations.use_for_test({"index": {Manuscript.image_key("A harbor at dawn."): {"versions": [{"file": made, "sig": ""}], "current": 0}}}, true)
	director.pin_medium("tablet", pin)
	pictures.set_script_text(TABLET)
	pictures.list()._refresh()
	_ok(all.text == "Generate all" and all.disabled, "a page captured is never counted, and with every picture made there is none to paint: %s" % all.text)
	director.unpin_medium(pin)
	panel.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(made))


## How many picture lists [param node] holds.
static func _lists(node: Node) -> int:
	var script: Script = node.get_script()
	var n := 1 if script != null and script.resource_path == "res://src/media/illustration_panel.gd" else 0
	for c in node.get_children():
		n += _lists(c)
	return n


static func _prompts(rows: Array) -> Array:
	return rows.map(func(r: Dictionary) -> String: return String(r["prompt"]))


func _ok(cond: bool, what: String) -> void:
	print(("  ok    " if cond else "  FAIL  ") + what)
	if not cond:
		_fails += 1
