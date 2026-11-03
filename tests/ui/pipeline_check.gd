extends SceneTree

## pipeline_check - everything made for a note, one list in one place ([PipelineCard]; next/pipeline.md; the user,
## 2026-11-02: "when we click the regenerate button - we will KNOW that it's going to regenerate that one thing, without a
## maybe second list appearing").
##
##   godot --headless --path . --script tests/ui/pipeline_check.gd
##
## ONE PLACE: it stands last among a panel's cards, in the one scroll (THE CONTROL: the footer, which holds Masking's markers
## alone, stays empty), its list scrolling with the panel however long it grows, with no scroll of its own (THE CONTROL: the
## list really is longer than the window); with nothing to list it is gone and takes no room.
## ONE ⟳: a plain Button, never a menu (THE CONTROL: a MenuButton is what the walk would find). Pressed, it does its one
## thing at once, and opens nothing. WHAT THROWS OTHER WORK AWAY SAYS SO BEFORE IT IS PRESSED: amber, the tooltip saying what,
## and it asks a yes or a no - nothing runs until yes, and no runs nothing. A row with no ⟳ keeps its place and takes no
## press; one not open now takes none.
## ONE GENERATE: top to bottom, a section started only once the one before it is done (THE CONTROL: while the first is busy
## the second is not started), asked at its turn whether it has anything to make (words written by the section before it
## count), a section with nothing missing passed by; while it walks every ⟳ waits; Stop stops all of it. Generate is grayed
## with nothing missing, Stop with nothing being made. The ▶ on a heading makes that section alone (THE CONTROL: the
## other is not started).
## GROUPS: a group's rows fold under its name, which says how they stand. WHAT IS LISTED IS BUILT ONCE: a refresh with the
## same rows keeps the same controls - a list built again under a press loses it (THE CONTROL: a new row builds it again). A
## SECTION'S CARD FREED under it takes the section along.

var _fails := 0
# loaded once the tree is up: the card reads Settings, an autoload a `--script` gate's own compile cannot see
var _Card: GDScript
var Stub: GDScript


func _init() -> void:
	# deferred: a card reads Settings, up once the tree is
	_run.call_deferred()


func _run() -> void:
	var settings := root.get_node_or_null("Settings")
	if settings != null:
		settings.set("_read_only", true)
	_Card = load("res://src/ui/pipeline_card.gd")
	Stub = load("res://tests/ui/pipeline_stub_section.gd")
	await _one_place()
	_one_redo()
	_one_generate()
	_groups_and_rebuilds()
	_gone_with_its_card()
	print("pipeline_check: %s" % ("ALL OK" if _fails == 0 else "%d FAILED" % _fails))
	quit(0 if _fails == 0 else 1)


func _ok(cond: bool, what: String) -> void:
	print(("  ok    " if cond else "  FAIL  ") + what)
	if not cond:
		_fails += 1


func _row(key: String, state := "made", again := "") -> PipelineRow:
	var r := PipelineRow.new(key, key)
	r.state = state
	r.again = again
	return r


## ONE PLACE
func _one_place() -> void:
	var panel = load("res://src/ui/side_panel.gd").new()
	root.add_child(panel)
	var usual: VBoxContainer = panel.add_card("usual", "Usual", &"paper")
	var card = _Card.new()
	card.put_on(panel)
	await process_frame
	card.refresh()
	_ok(card.card != null and not card.card.visible, "with no section it is hidden")
	# PUT ON A PANEL ALREADY IN THE TREE, as the app does: joining it runs the card's _ready there and then, which must not take
	# the bar for a card never put on a panel (the app's Generate stood in the list, and the engine said so only in the log)
	_ok(card.card.head.is_ancestor_of(card._generate) and not card.card.body.is_ancestor_of(card._generate),
		"Generate stands on the title bar, not in the list")
	var s = Stub.new("A")
	card.add(s)
	card.refresh()
	_ok(not card.card.visible, "a section with nothing listed: still hidden")
	var rows: Array = []
	for i in 4:
		rows.append(_row("r%d" % i))
	s.listed = rows
	card.refresh()
	await process_frame
	await process_frame
	_ok(card.card.visible, "a row to list: it stands")
	_ok(panel._scroll.is_ancestor_of(card) and panel._scroll.is_ancestor_of(usual) and not panel._foot_pad.visible,
		"it stands in what scrolls, as a card added the usual way does, and the footer stays empty")
	_ok(card.card.get_index() > usual.get_parent().get_parent().get_index(), "...after the note's cards")
	rows = []
	for i in 200:
		rows.append(_row("r%d" % i))
	s.listed = rows
	card.refresh()
	await process_frame
	await process_frame
	_ok(card.find_children("*", "ScrollContainer", true, false).is_empty(), "a long list has no scroll of its own")
	_ok(card._list.get_combined_minimum_size().y > root.get_visible_rect().size.y and panel._scroll.get_v_scroll_bar().max_value > panel._scroll.size.y,
		"the control: the list is longer than the window, and the panel's one scroll takes it (%d px)" % int(card._list.get_combined_minimum_size().y))
	s.listed = []
	card.refresh()
	_ok(not card.card.visible, "nothing left to list: gone again")
	panel.queue_free()
	await process_frame


## ONE ⟳
func _one_redo() -> void:
	var card = _Card.new()
	var s = Stub.new("A")
	card.add(s)
	var ran: Array = []
	var plain := _row("plain", "made", "Make it again")
	plain.redo = func() -> void: ran.append("plain")
	var costly := _row("costly", "made", "Make the big thing again")
	costly.asks = "It also throws away: the little thing."
	costly.redo = func() -> void: ran.append("costly")
	var bare := _row("bare")
	var shut := _row("shut", "running", "Make it again")
	shut.open = false
	shut.redo = func() -> void: ran.append("shut")
	s.listed = [plain, costly, bare, shut]
	card.refresh()
	var a_menu := _a_menu()
	_ok(_menus(card) == 0 and _menus(a_menu) == 1, "no ⟳ is a menu (the control: the walk finds one in a menu)")
	a_menu.free()
	var r: Dictionary = card.row("plain")
	_ok(r["redo"] is Button and (r["redo"] as Button).tooltip_text == "Make it again" and (r["redo"] as Button).modulate == Color.WHITE,
		"its tooltip says what it does")
	(r["redo"] as Button).pressed.emit()
	_ok(ran == ["plain"] and card.asking == null, "pressed, it does its one thing at once, and opens nothing")
	ran.clear()
	var c: Dictionary = card.row("costly")
	var redo: Button = c["redo"]
	_ok(redo.modulate == _Card.AMBER and redo.tooltip_text.contains("the little thing"),
		"what throws other work away is amber, and says what before it is pressed (%s)" % redo.tooltip_text.replace("\n", " "))
	redo.pressed.emit()
	_ok(ran.is_empty() and card.asking != null and card.asking.dialog_text.contains("the little thing"),
		"pressed, it runs nothing yet and asks, naming what goes")
	card.asking.canceled.emit()
	_ok(ran.is_empty() and card.asking == null, "no: nothing ran")
	redo.pressed.emit()
	card.asking.confirmed.emit()
	_ok(ran == ["costly"] and card.asking == null, "yes: it ran, once")
	ran.clear()
	var b: Dictionary = card.row("bare")
	(b["redo"] as Button).pressed.emit()
	_ok((b["redo"] as Button).modulate.a == 0.0 and (b["redo"] as Button).disabled and ran.is_empty(),
		"a row with no ⟳ keeps its place and takes no press")
	var o: Dictionary = card.row("shut")
	(o["redo"] as Button).pressed.emit()
	_ok((o["redo"] as Button).disabled and ran.is_empty(), "one not open now takes none")
	_ok((b["glyph"] as Label).text == "✓" and (o["glyph"] as Label).text == "◌", "each says where it stands")
	card.free()


## ONE GENERATE
func _one_generate() -> void:
	var card = _Card.new()
	var first = Stub.new("First")
	var second = Stub.new("Second")
	var third = Stub.new("Third")
	first.listed = [_row("a", "missing")]
	second.listed = [_row("b", "missing")]
	third.listed = [_row("c")]
	first.has_missing = true
	second.has_missing = false         # its words are written by the first
	third.has_missing = false
	for s in [first, second, third]:
		card.add(s)
	card.refresh()
	_ok(not card._generate.disabled and card._stop.disabled, "something missing: Generate is offered, Stop is not")
	card.generate()
	_ok(first.made == 1 and second.made == 0 and first.is_busy, "Generate starts the first")
	card.refresh()
	card.refresh()
	_ok(first.made == 1 and second.made == 0 and card.walking() and card._generate.disabled and not card._stop.disabled,
		"the control: while it is busy the next is not started, and it is started once")
	var ran: Array = []
	var redo := _row("b", "missing", "Make b")
	redo.redo = func() -> void: ran.append("b")
	second.listed = [redo]
	card.refresh()
	(card.row("b")["redo"] as Button).pressed.emit()
	_ok((card.row("b")["redo"] as Button).disabled and ran.is_empty(), "while it walks, every ⟳ waits")
	second.has_missing = true          # the first has written its words
	first.is_busy = false
	card.refresh()
	_ok(second.made == 1 and third.made == 0, "the first done, the second is started: asked at its turn, it has something to make now")
	second.is_busy = false
	card.refresh()
	_ok(third.made == 0 and not card.walking(), "a section with nothing missing is passed by, and the walk is over")
	card.refresh()
	first.has_missing = false
	second.has_missing = false
	card.refresh()
	_ok(card._generate.disabled and card._stop.disabled, "nothing missing and nothing being made: both grayed")
	first.has_missing = true
	second.has_missing = true
	card.generate()
	card.stop()
	_ok(not card.walking() and first.stopped == 1 and second.stopped == 1 and third.stopped == 1, "Stop stops all of it")
	first.is_busy = false
	first.made = 0
	second.made = 0
	card.refresh()
	_ok(first.made == 0 and second.made == 0, "...and nothing is started after it")
	(card._heads[second]["go"] as Button).pressed.emit()
	_ok(second.made == 1 and first.made == 0, "the ▶ on a heading makes that section alone (the control: the other is not started)")
	second.is_busy = false
	card.free()


func _groups_and_rebuilds() -> void:
	var card = _Card.new()
	var s = Stub.new("A")
	card.add(s)
	var one := PipelineRow.new("one", "One", "Card 3")
	one.state = "made"
	var two := PipelineRow.new("two", "Two", "Card 3")
	two.state = "failed"
	s.listed = [one, two]
	card.refresh()
	var at: String = card._groups.keys()[0]
	var head: Button = card._groups[at]["head"]
	_ok(head.text.contains("Card 3") and head.text.contains("✗") and head.text.contains("▾"), "a group is named, says how its rows stand (%s)" % head.text)
	var line: Control = card.row("one")["line"]
	head.pressed.emit()
	_ok(not line.visible and head.text.contains("▸"), "folded, its rows are hidden")
	head.pressed.emit()
	_ok(line.visible, "...and unfolded, back")
	card.refresh()
	_ok(card.row("one")["line"] == line, "a refresh with the same rows keeps the same controls")
	s.listed = [one, two, _row("three")]
	card.refresh()
	_ok(card.row("one")["line"] != line and not card.row("three").is_empty(), "the control: a new row builds the list again")
	card.free()


func _gone_with_its_card() -> void:
	var card = _Card.new()
	var held := Node.new()
	var s = Stub.new("A")
	s.owner = held
	s.listed = [_row("a")]
	card.add(s)
	card.refresh()
	var was: bool = not card.row("a").is_empty()
	held.free()
	card.refresh()
	_ok(was and card.row("a").is_empty() and card.sections().is_empty(), "a card freed takes its section along (control: listed while it was up)")
	card.free()


## How many MenuButtons stand under [param node].
func _menus(node: Node) -> int:
	var n := 1 if node is MenuButton else 0
	for c in node.get_children():
		n += _menus(c)
	return n


func _a_menu() -> Node:
	var box := Control.new()
	box.add_child(MenuButton.new())
	return box
