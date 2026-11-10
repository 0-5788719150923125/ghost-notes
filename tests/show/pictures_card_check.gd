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
## IT COMES WITH WHAT SHOWS PICTURES ([method Components.with_parts]): beside the Medium, and beside a show at a table, whose
## agents paint pictures of their own (2026-11-09) - never beside a voice alone (THE CONTROL) - and it has no × of its own, where
## the Medium card has one. EVERY PANEL SHOWS WHAT COMES WITH THE CARDS IT SHOWS (its workspace's `hosts`; THE CONTROL: the table's
## without the Pictures card, as it was when a table show's never stood).
##
## ONE CARD: built beside the Medium card - as a letter, a dispatch desk and a tablet - which never carries a list of
## pictures of its own (THE CONTROL: the Pictures card holds one).
##
## IT STANDS ONLY WHILE THE MEDIUM SHOWS PICTURES: pinned to a letter, the card stands, its list the letter's pictures and
## not its sketch, and its Pipeline section is listed; under the full frame the card and its section are put away (THE
## CONTROL); under a novel both are back, the sketch with them.
##
## WHAT A SHOW'S AGENTS PAINTED IS SHOWN ([MadePictures], [method EpisodeFeed.made_pictures]): under the full frame, which
## shows no pictures of the note's, the card stands while the episode has a picture its agents made, a thumbnail of it listed;
## with none made it is put away again (THE CONTROL).
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


## IT COMES WITH WHAT SHOWS PICTURES: the Medium (whose formats include the Letter and the Dispatch desk, 2026-11-09)
func _comes_with() -> void:
	_ok(Components.with_parts(["text", "voice", "medium"]).has("illustrations"), "it comes with the Medium")
	_ok(Components.with_parts(["text", "table", "voice"]).has("illustrations"), "...and with a show at a table, whose agents paint")
	_ok(not Components.with_parts(["text", "voice"]).has("illustrations"), "the control: never beside a voice alone")
	_ok(Components.attach_blocks("illustrations").is_empty() and not Components.detach_blocker("illustrations", ["text", "voice", "medium"]).is_empty(),
		"never attached or taken off by itself")
	# ...AND ON THE PANEL OF WHAT IT COMES WITH (2026-11-09: the table's panel showed no card it does not list in its `hosts`, and the
	# Pictures card was missing from a table show's)
	var unhosted := _unhosted(Components.WORKSPACES)
	_ok(unhosted.is_empty(), "every panel shows what comes with the cards it shows: missing %s" % str(unhosted))
	var cut: Dictionary = Components.WORKSPACES.duplicate(true)
	((cut["table"] as Dictionary)["hosts"] as Array).erase("illustrations")
	_ok(_unhosted(cut) == [["table", "illustrations"]], "the control: a table panel without it is found: %s" % str(_unhosted(cut)))


## `[workspace, part]` for each part that comes with a card a panel shows ([method Components.with_parts]) but is not among its `hosts`:
## made for the note, and put on no panel.
static func _unhosted(workspaces: Dictionary) -> Array:
	var out: Array = []
	for ws in workspaces:
		var hosts: Variant = (workspaces[ws] as Dictionary).get("hosts")
		if not (hosts is Array):
			continue
		for k in Components.REGISTRY:
			var with: Array = (Components.REGISTRY[k] as Dictionary).get("comes_with", [])
			if not (hosts as Array).has(k) and with.any(func(h: String) -> bool: return (hosts as Array).has(h)):
				out.append([ws, k])
	return out


## ONE CARD, STANDING ONLY WHILE THE MEDIUM SHOWS PICTURES. (Nothing here is typed by a card's class: a `--script` gate
## compiles before the autoloads, and a card that names one would be loaded broken.)
func _one_card() -> void:
	var director: Node = root.get_node("Director")
	var cards: GDScript = load("res://src/ui/note_cards.gd")
	var panel = load("res://src/ui/side_panel.gd").new()
	panel.detach = func(_key: String) -> void: pass
	root.add_child(panel)
	var have := Components.with_parts(["text", "voice", "medium"])
	var built: Dictionary = cards.build(panel, have, {"only": ["medium", "illustrations"], "reading": true,
		"blocks": {"medium": {"format": "letter"}}})
	var pictures = built.get("illustrations")
	_ok(pictures != null and built.has("medium") and built["medium"].own() != null,
		"a letter's panel builds the Pictures card beside the Medium card, the Letter's rows on it: %s" % str(built.keys()))
	if pictures == null:
		panel.queue_free()
		return
	var crosses: Array = panel._detach_buttons.map(func(d: Array) -> String: return String(d[1]))
	_ok(crosses.has("medium") and not crosses.has("illustrations"), "the Medium card has its ×, the Pictures card none: %s" % str(crosses))
	_ok(_lists(built["medium"]) == 0 and _lists(pictures) == 1, "the Medium card with the Letter's rows carries no list of its own, the Pictures card one")
	for fmt in ["dispatch", "tablet"]:
		var other = cards.make("medium", {"reading": true, "blocks": {"medium": {"format": fmt}}})
		_ok(_lists(other) == 0, "...nor does it as a %s" % fmt)
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
	# WHAT THE EPISODE'S AGENTS PAINTED: shown whatever the medium, and the card stood for it
	var painted := "user://pictures_card_made_check.png"
	Image.create(8, 12, false, Image.FORMAT_RGB8).save_png(painted)
	var feed := MadeFeed.new()
	feed.list = [{"path": ProjectSettings.globalize_path(painted), "label": "Picture to copy", "row": "image:face", "group": ""}]
	section.episode = func() -> EpisodeFeed: return feed
	pictures._stand()
	_ok(card.visible and pictures.made().visible and pictures.made().shown().size() == 1 and pictures.made()._flow.get_child_count() == 1,
		"under the full frame the card stands for a picture the episode's agents made, its thumbnail listed")
	feed.list = []
	pictures._stand()
	_ok(not card.visible and not pictures.made().visible, "the control: with none made, it is put away again")
	section.episode = Callable()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(painted))
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


## An episode whose agents painted what the gate says.
class MadeFeed extends EpisodeFeed:
	var list: Array = []

	func made_pictures() -> Array:
		return list


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
