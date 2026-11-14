extends SceneTree

## pipeline_check - everything made for a note, one list in one place ([PipelineCard]; next/pipeline.md).
##
##   godot --headless --path . --script tests/ui/pipeline_check.gd
##
## - One place: it stands last among a panel's cards, in the one scroll (control: the footer, which holds Masking's markers
##   alone, stays empty), its list scrolling with the panel however long it grows, with no scroll of its own (control: the
##   list really is longer than the window); with nothing to list it is gone and takes no room. New steps in the list leave a
##   view at the end at the end, the last of them in sight (control: a view anywhere else stays where it is).
## - One refresh button: a plain Button, never a menu (control: a MenuButton is what the walk would find). Pressed, it does
##   its one thing at once, and opens nothing. What throws other work away says so before it is pressed, in words and in the
##   color of every other refresh button: the tooltip saying what, and it asks a yes or a no - nothing runs until yes, and no
##   runs nothing. A row with no refresh button keeps its place and takes no press; one not open now takes none.
## - One Generate: top to bottom, a section started only once the one before it is done (control: while the first is busy
##   the second is not started), asked at its turn whether it has anything to make (words written by the section before it
##   count), a section with nothing missing passed by; while it walks every refresh button waits; Stop stops all of it.
##   Generate is grayed with nothing missing, Stop with nothing being made. The play button on a heading makes that section
##   alone (control: the other is not started). While a row made again runs alone, Generate is offered and widens it to the
##   rest (control: a section busy making all of it leaves Generate grayed). Carried into a panel built anew over the same
##   note, the walk leaves the section still making what it was asked as it is and makes the next at its turn (control:
##   Generate pressed over the same sections asks the busy one again).
## - Groups: a group's rows fold under its name, which says how they stand. What is listed is built once: a refresh with the
##   same rows keeps the same controls - a list built again under a press loses it (control: a new row builds it again). A
##   section's card freed under it takes the section along.

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
	_resume_action()
	_one_generate()
	_carried_on()
	_widened()
	_locks()
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


func _resume_action() -> void:
	var card = _Card.new()
	var section = Stub.new("Resume gate")
	card.add(section)
	var calls: Array = []
	var work := _row("work", "missing", "Start work again")
	work.go_text = "Resume"
	work.go = "Continue saved progress"
	work.make = func() -> void: calls.append("resumed")
	section.listed = [work]
	card.refresh()
	var button: Button = card.row("work")["make"]
	_ok(button != null and button.text == "Resume" and not button.disabled,
		"a resumable row offers a labelled Resume action alongside regenerate")
	button.pressed.emit()
	_ok(calls == ["resumed"] and section.made == 0, "Resume invokes its own continuation, without generating the section")
	work.go_open = false
	card.refresh()
	card._press_make("Resume gate/work")
	_ok(calls.size() == 1 and button.disabled, "a busy or unavailable Resume cannot be pressed")
	work.go = ""
	card.refresh()
	_ok(card.row("work")["make"] == null, "a row with no resumable progress has no Resume button")
	card.free()


## One place
func _one_place() -> void:
	var panel = load("res://src/ui/side_panel.gd").new()
	root.add_child(panel)
	var usual: VBoxContainer = panel.add_card("usual", "Usual", &"paper")
	var card = _Card.new()
	card.put_on(panel)
	await process_frame
	card.refresh()
	_ok(card.card != null and not card.card.visible, "with no section it is hidden")
	# Put on a panel already in the tree, as the app does: joining it runs the card's _ready there and then, which must not take
	# the bar for a card never put on a panel
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
	var bar: ScrollBar = panel._scroll.get_v_scroll_bar()
	bar.value = 100.0
	await process_frame
	for i in range(200, 220):
		rows.append(_row("r%d" % i))
	s.listed = rows.duplicate()
	card.refresh()
	await process_frame
	await process_frame
	_ok(is_equal_approx(bar.value, 100.0), "the control: new steps in the list leave a view short of the end where it is")
	bar.value = bar.max_value
	await process_frame
	var was: float = bar.value
	for i in range(220, 240):
		rows.append(_row("r%d" % i))
	s.listed = rows.duplicate()
	card.refresh()
	await process_frame
	await process_frame
	var foot: Control = card.row("r239")["line"]
	_ok(bar.value > was and bar.value >= bar.max_value - bar.page - 1.0 and foot.get_global_rect().end.y <= panel._scroll.global_position.y + panel._scroll.size.y + 1.0,
		"at the end, new steps in the list: it stays at the end, the last of them in sight (%d to %d)" % [int(was), int(bar.value)])
	s.listed = []
	card.refresh()
	_ok(not card.card.visible, "nothing left to list: gone again")
	panel.queue_free()
	await process_frame


## One ⟳
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
	_ok(r["redo"] is Button and (r["redo"] as Button).tooltip_text == "Make it again" and not card.asks_first("plain"),
		"its tooltip says what it does, and it does not ask (the control)")
	(r["redo"] as Button).pressed.emit()
	_ok(ran == ["plain"] and card.asking == null, "pressed, it does its one thing at once, and opens nothing")
	ran.clear()
	var c: Dictionary = card.row("costly")
	var redo: Button = c["redo"]
	_ok(card.asks_first("costly") and redo.tooltip_text.contains("the little thing"),
		"what throws other work away asks first, and says what before it is pressed (%s)" % redo.tooltip_text.replace("\n", " "))
	_ok(redo.modulate == (r["redo"] as Button).modulate,
		"and wears the color every ⟳ does (the user, of the amber: \"it's not clear why\")")
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


## One generate
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


## Generate's walk carried into the panel built anew over the same note ([method PipelineCard.carry_on]): the section still
## making what it was asked carries on as it is, and the next is made at its turn. Control: Generate pressed over the same
## sections asks the busy one again.
func _carried_on() -> void:
	var card = _Card.new()
	var first = Stub.new("First")
	var second = Stub.new("Second")
	first.listed = [_row("a", "running")]
	second.listed = [_row("b", "missing")]
	first.is_busy = true
	for s in [first, second]:
		card.add(s)
	card.carry_on()
	_ok(first.made == 0 and card.walking(), "carried on, it walks - from the next refresh")
	card.refresh()
	card.refresh()
	_ok(first.made == 0 and second.made == 0 and card.walking() and card._generate.disabled,
		"the section still making what it was asked carries on as it is, and the next waits")
	first.is_busy = false
	first.has_missing = false
	card.refresh()
	_ok(second.made == 1 and first.made == 0, "the first done, the next is made at its turn")
	second.is_busy = false
	second.made = 0
	first.is_busy = true
	first.has_missing = true
	card.carry_on()
	first.is_busy = false               # ...its work stopped with the panel before
	card.refresh()
	_ok(first.made == 1, "a section no longer making anything is made at its turn")
	card.stop()
	card.free()
	var control = _Card.new()
	var busy = Stub.new("Busy")
	busy.listed = [_row("a", "running")]
	busy.is_busy = true
	control.add(busy)
	control.generate()
	_ok(busy.made == 1, "control: Generate pressed over the same sections asks the busy one again")
	control.stop()
	control.free()


## Generate widens a row made again: while a section makes only some of what it is missing, Generate is offered, and
## pressed it starts the section again for all of it. Control: a section busy making all it is missing leaves Generate grayed.
func _widened() -> void:
	var card = _Card.new()
	var s = Stub.new("Episode")
	s.listed = [_row("a", "running"), _row("b", "missing")]
	card.add(s)
	s.is_busy = true
	s.is_part = true
	card.refresh()
	_ok(not card._generate.disabled and not card._stop.disabled, "a row made again alone, the rest waiting: Generate is offered")
	card.generate()
	_ok(s.made == 1 and card.walking() and card._generate.disabled, "pressed, it starts the section for the rest, once")
	card.stop()
	s.is_busy = true
	s.is_part = false
	card.refresh()
	_ok(card._generate.disabled, "the control: busy making all it is missing, Generate is grayed")
	s.is_busy = false
	card.free()


## A lock beside a refresh button (next/editing.md step 1): a made row carries one, open until pressed; pressed, the row is
## kept and its tooltip says Generate passes it by. Control: a row that is not lockable carries none.
func _locks() -> void:
	var card = _Card.new()
	var s = Stub.new("Episode")
	var calls: Array = []
	var held := _row("painted", "made", "Paint it again")
	held.lockable = true
	held.lock = func(on: bool) -> void:
		calls.append(on)
		held.locked = on
	var last := _row("tags", "made", "Write them again")
	s.listed = [held, last]
	card.add(s)
	card.refresh()
	var lock_b: Variant = card.row("painted").get("lock")
	_ok(lock_b is Button and (lock_b as Button).tooltip_text.begins_with("Press to keep"), "a made row carries a lock, open")
	(lock_b as Button).pressed.emit()
	_ok(calls == [true] and (card.row("painted")["lock"] as Button).tooltip_text.begins_with("Kept"),
		"pressed, it is kept and says so: %s" % str(calls))
	_ok(card.row("tags").get("lock") == null, "the control: a row that is not lockable carries none")
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
