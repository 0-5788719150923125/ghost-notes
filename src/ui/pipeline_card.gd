extends VBoxContainer
class_name PipelineCard

## PipelineCard - EVERYTHING AGENTS AND TOOLS MAKE FOR A NOTE, ONE LIST IN ONE PLACE (next/pipeline.md; the user,
## 2026-11-02: "I would always be able to find that one, stable card, to regenerate various things").
##
## LAST IN THE DECK, ALWAYS ONE CLICK AWAY (2026-11-02, the user of it pinned under the scroll: "It's weird that there are now
## two panels on the left ... They should all be scrollable"): it is a card like any other, its list scrolling with the
## panel, and its title bar lies on the panel's bottom pile until it is scrolled to ([PanelDeck]). Generate, Stop and how far
## along it is are on that bar, so they stay when it is folded and wherever it lies. There is no component and no "+": it
## stands while anything on the note has something to make.
##
## ONE WAY IN: a card hands a [PipelineSection] ([method add]). The list is made of what those say ([PipelineRow]), and
## nothing here knows what a card, a sketch or a tag is.
##
## ONE ⟳: a row's starts its one thing at once - unless that throws other finished work away, when it says so on hover and
## asks once, a yes or a no, naming it ([member PipelineRow.asks]). Never a list. What a click will do is known before it
## is made. EVERY ⟳ IS ONE COLOR (2026-11-07, the user: "it's not clear why some of the regenerate buttons are orange, while
## others are white. I would be inclined to just make them all white"): the amber a ⟳ that asks once wore said nothing a
## person could read, and the hover and the question say it in words.
##
## ONE GENERATE: every section's missing work, top to bottom, each waiting for the one before ([method generate]): the
## words first, then what is made from them. The ▶ on a section's heading makes that section alone. While Generate walks,
## every ⟳ waits.

## The widest a row's name stands: a longer one is clipped, whole in its tooltip.
const NAME_MOST := 124.0
## How far a group's rows stand in.
const INDENT := 12.0
## Rows ask the disk what exists, so four times a second, as the cards' rows always did.
const EVERY := 0.25

## The [Card] it is on, once [method put_on] a panel.
var card: Card = null
## What a person's question looks like while it is up: for a gate to answer.
var asking: ConfirmationDialog = null

var _sections: Array = []        # [PipelineSection], top to bottom
var _queue: Array = []           # the sections Generate has still to walk
var _begun := false              # ...and whether the first of them was started
var _t := 0.0

var _bar: HBoxContainer          # the tally, Generate and Stop: on the card's title bar
var _tally: Label
var _generate: Button
var _stop: Button
var _line: Label
var _list: VBoxContainer
var _built := ""                 # what the list was built for
var _rows := {}                  # "<section>/<key>" -> {section, row, glyph, name, text, redo, make, line}
var _heads := {}                 # a section -> {go}
var _groups := {}                # "<section>/<group>" -> {section, group, head, rows: [row controls]}
var _folds := {}                 # "<section>/<group>" -> folded
var _fold_prefix := ""


## [param prefix] names the panel in its groups' stored folds, as a [Card]'s are named.
func _init(prefix := "") -> void:
	_fold_prefix = prefix
	add_theme_constant_override("separation", 4)
	_bar = HBoxContainer.new()
	_bar.add_theme_constant_override("separation", 4)
	_tally = Label.new()
	_tally.add_theme_font_size_override("font_size", 11)
	_tally.modulate = Color(1, 1, 1, 0.75)
	_tally.mouse_filter = Control.MOUSE_FILTER_STOP
	_bar.add_child(_tally)
	_generate = _bar_button("Generate", "Make everything below that is missing, top to bottom: each part waits for the one before it. It spends the agents' quota. To make one part, use the ▶ on its heading; to make one thing again, its ⟳.")
	_generate.pressed.connect(generate)
	_stop = _bar_button("Stop", "Stop whatever is being made here. What is finished is kept.")
	_stop.pressed.connect(stop)
	_line = Label.new()
	_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_line.add_theme_font_size_override("font_size", 11)
	_line.modulate = Color(1, 1, 1, 0.7)
	_line.visible = false
	add_child(_line)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 1)
	add_child(_list)


func _bar_button(text: String, tip: String) -> Button:
	var b := Button.new()
	b.text = text
	b.tooltip_text = tip
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 11)
	_bar.add_child(b)
	return b


## ON [param panel], after the cards there, its Generate and Stop on the card's title bar so they stay when it is folded. Hidden
## until something on the note has something to make.
##
## THE CARD AND ITS BAR COME FIRST, AND IT JOINS LAST: the app's panel is in the tree as it is built, so joining runs [method _ready]
## there and then, and with no card yet that takes the bar into the list (as it did from the first build: every panel the gates
## built was out of the tree, and the engine said so only in the log).
func put_on(panel: SidePanel) -> void:
	var box := panel.add_card("pipeline", "Pipeline", &"producer")
	var node: Node = box.get_parent()
	while node != null and not (node is Card):
		node = node.get_parent()
	card = node as Card
	if card != null:
		card.add_title_bar_control(_bar)
		card.visible = false
		# ...and its chip, at once: the chips only look once a frame
		if panel.card_row != null:
			panel.card_row.follow()
	box.add_child(self)


func _ready() -> void:
	if card == null and _bar.get_parent() == null:
		add_child(_bar)
		move_child(_bar, 0)
	refresh()


## A bar never put on a title bar or the card has no one to free it (a card built by hand, and never shown).
func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and is_instance_valid(_bar) and _bar.get_parent() == null:
		_bar.free()


func _exit_tree() -> void:
	_queue = []
	_begun = false
	for s in _sections:
		if (s as PipelineSection).alive():
			(s as PipelineSection).leave()


func _process(delta: float) -> void:
	_t -= delta
	if _t > 0.0:
		return
	_t = EVERY
	refresh()


## A SECTION, UNDER THE ONES HANDED BEFORE IT - the order of the note's cards, so what writes the words stands above what
## is made from them.
func add(section: PipelineSection) -> void:
	if section != null and not _sections.has(section):
		_sections.append(section)


## The sections still here.
func sections() -> Array:
	return _sections.filter(func(s: PipelineSection) -> bool: return s.alive())


## The sections listed now.
func listed() -> Array:
	return sections().filter(func(s: PipelineSection) -> bool: return s.shown())


## Whether anything is being made, or Generate has further to go.
func busy() -> bool:
	if not _queue.is_empty():
		return true
	for s in sections():
		if (s as PipelineSection).busy():
			return true
	return false


## Whether Generate is walking: every ⟳ waits.
func walking() -> bool:
	return not _queue.is_empty()


## Whether Generate would make anything.
func missing() -> bool:
	for s in listed():
		if (s as PipelineSection).missing():
			return true
	return false


## GENERATE: every section's missing work, top to bottom, each started once the one before it is done ([method _walk]) -
## asked at its turn, so a step made from the words answers once they are written.
func generate() -> void:
	for s in sections():
		(s as PipelineSection).told = ""
	_queue = sections()
	_begun = false
	refresh()


## Walks as far as it can: a section is started once, and the walk waits while it is busy. One that fails is passed - what
## comes after it may be made regardless, and if it needs what failed, it says so.
func _walk() -> void:
	while not _queue.is_empty():
		var s: PipelineSection = _queue[0]
		if not s.alive():
			_queue.pop_front()
			_begun = false
			continue
		if not _begun:
			_begun = true
			if s.shown() and s.missing():
				s.make()
		if s.busy():
			return
		_queue.pop_front()
		_begun = false


## STOP: all of it. What is finished is kept.
func stop() -> void:
	_queue = []
	_begun = false
	for s in sections():
		(s as PipelineSection).stop()
	refresh()


## THE EPISODE IN [param feed] IS BEING LEFT OR THROWN AWAY: what is being made of it stops, and - when it is the one shown
## ([param shown]) - so does Generate's walk, which would go on into the next one's.
func episode_left(feed: EpisodeFeed, shown: EpisodeFeed = null) -> void:
	if feed == null or shown == null or feed.folder() == shown.folder():
		_queue = []
		_begun = false
	for s in sections():
		(s as PipelineSection).episode_left(feed)


## The row of the thing called [param key] in [param section] (a title; "" for any): `{section, row, glyph, name, text,
## redo, make}`, {} while there is none. For a gate.
func row(key: String, section := "") -> Dictionary:
	for k in _rows:
		var r: Dictionary = _rows[k]
		if (r["row"] as PipelineRow).key == key and (section.is_empty() or (r["section"] as PipelineSection).title == section):
			return r
	return {}


## Whether the row's ⟳ asks before it runs, naming what it throws away (its tooltip says what). For a gate.
func asks_first(key: String, section := "") -> bool:
	var r := row(key, section)
	return not r.is_empty() and not (r["row"] as PipelineRow).asks.is_empty()


## The names of the rows listed, top to bottom. For a gate.
func names() -> Array:
	var out: Array = []
	for k in _rows:
		out.append(((_rows[k] as Dictionary)["row"] as PipelineRow).label)
	return out


## The groups listed, by name, top to bottom. For a gate.
func group_names() -> Array:
	var out: Array = []
	for at in _groups:
		out.append(String((_groups[at] as Dictionary)["group"]))
	return out


## EACH REFRESH: what ended is landed, Generate walks on, and the list says where everything stands - built again only
## when what it lists has changed, for a list built again under a press loses the press.
func refresh() -> void:
	var all := sections()
	for s in all:
		(s as PipelineSection).tick()
	_walk()
	var shown := all.filter(func(s: PipelineSection) -> bool: return s.shown())
	if card != null:
		var on := not shown.is_empty()
		if card.visible != on:
			card.visible = on
			var panel := _panel()
			# ...and its chip, at once: the chips only look once a frame
			if panel != null and panel.card_row != null:
				panel.card_row.follow()
	var of := {}
	var plan := PackedStringArray()
	for s in shown:
		var rows: Array = (s as PipelineSection).rows()
		of[s] = rows
		plan.append((s as PipelineSection).title)
		for r in rows:
			var it := r as PipelineRow
			plan.append("%s|%s|%s|%s|%s" % [it.key, it.group, it.label, not it.again.is_empty(), not it.go.is_empty()])
	var key := "\n".join(plan)
	if key != _built:
		_built = key
		_build(shown, of)
	_show(shown, of)


func _panel() -> SidePanel:
	var node: Node = get_parent()
	while node != null and not (node is SidePanel):
		node = node.get_parent()
	return node as SidePanel


func _build(shown: Array, of: Dictionary) -> void:
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	_rows = {}
	_heads = {}
	_groups = {}
	for s in shown:
		var section: PipelineSection = s
		_add_head(section)
		var named: Array = []
		for r in of[section]:
			named.append(_add_row(section, r as PipelineRow))
		# their names one column wide in a section, whatever a producer called a beat, up to the most a name takes
		var wide := 0.0
		for n in named:
			wide = maxf(wide, (n as Label).get_minimum_size().x + (INDENT if (n as Label).has_meta("grouped") else 0.0))
		wide = minf(wide, NAME_MOST)
		for n in named:
			var l := n as Label
			l.custom_minimum_size.x = wide - (INDENT if l.has_meta("grouped") else 0.0)
			l.clip_text = true
			l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_apply_folds()


func _add_head(section: PipelineSection) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	_list.add_child(row)
	var l := Label.new()
	l.text = section.title
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.add_theme_font_size_override("font_size", 13)
	# A HEADING, NOT A ROW: in the card's own hue, a little apart from the section above it
	l.add_theme_color_override("font_color", Card.family_color(&"producer").lightened(0.35))
	if row.get_index() > 0:
		var gap := Control.new()
		gap.custom_minimum_size.y = 6.0
		_list.add_child(gap)
		_list.move_child(gap, row.get_index())
	row.add_child(l)
	var go := _small_button("▶", section.make_tip())
	go.visible = not section.make_tip().is_empty()
	go.pressed.connect(func() -> void:
		if not section.alive():
			return
		section.told = ""
		section.make()
		refresh())
	row.add_child(go)
	_heads[section] = {"go": go}


func _small_button(text: String, tip: String) -> Button:
	var b := Button.new()
	b.text = text
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.tooltip_text = tip
	# no taller than its text: the more rows stand in the card's share of the window, the less is scrolled
	b.add_theme_font_size_override("font_size", 12)
	for side in ["normal", "hover", "pressed", "disabled", "focus"]:
		b.add_theme_stylebox_override(side, _tight())
	return b


func _tight() -> StyleBoxEmpty:
	var box := StyleBoxEmpty.new()
	box.content_margin_left = 7.0
	box.content_margin_right = 7.0
	box.content_margin_top = 3.0
	box.content_margin_bottom = 3.0
	return box


func _group_of(section: PipelineSection, group: String) -> Dictionary:
	var at := "%s/%s" % [section.title, group]
	if _groups.has(at):
		return _groups[at]
	var head := Button.new()
	head.flat = true
	head.focus_mode = Control.FOCUS_NONE
	head.alignment = HORIZONTAL_ALIGNMENT_LEFT
	head.clip_text = true
	head.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_theme_font_size_override("font_size", 12)
	head.pressed.connect(func() -> void: _toggle(at))
	_list.add_child(head)
	var g := {"section": section, "group": group, "head": head, "rows": []}
	_groups[at] = g
	if not _folds.has(at):
		_folds[at] = bool(Settings.read(Card.SECTION, _fold_key(group), false))
	return g


## ONE LINE: its glyph, its name, what it says, and its ▶ and ⟳. Returns the name, for its column.
func _add_row(section: PipelineSection, it: PipelineRow) -> Label:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	var grouped := not it.group.is_empty()
	if grouped:
		(_group_of(section, it.group)["rows"] as Array).append(row)
	_list.add_child(row)
	if grouped:
		var pad := Control.new()
		pad.custom_minimum_size.x = INDENT
		row.add_child(pad)
	var glyph := Label.new()
	glyph.custom_minimum_size.x = 14.0
	glyph.add_theme_font_size_override("font_size", 12)
	row.add_child(glyph)
	var name_l := Label.new()
	name_l.text = it.label
	name_l.add_theme_font_size_override("font_size", 12)
	name_l.mouse_filter = Control.MOUSE_FILTER_STOP
	if grouped:
		name_l.set_meta("grouped", true)
	row.add_child(name_l)
	var text := Label.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_font_size_override("font_size", 11)
	text.modulate = Color(1, 1, 1, 0.7)
	text.mouse_filter = Control.MOUSE_FILTER_STOP
	row.add_child(text)
	var at := "%s/%s" % [section.title, it.key]
	var make: Button = null
	if not it.go.is_empty():
		make = _small_button("▶", it.go)
		make.pressed.connect(_press_make.bind(at))
		row.add_child(make)
	var redo := _small_button("⟳", it.again)
	redo.pressed.connect(_press_redo.bind(at))
	# A ROW WITH NO ⟳ KEEPS ITS PLACE: the column stays straight down the list
	if it.again.is_empty():
		redo.modulate.a = 0.0
		redo.disabled = true
		redo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(redo)
	_rows[at] = {"section": section, "row": it, "glyph": glyph, "name": name_l, "text": text, "redo": redo, "make": make, "line": row}
	return name_l


## WHERE EVERYTHING STANDS: read off what the sections said this refresh, on the list as it is built.
func _show(shown: Array, of: Dictionary) -> void:
	var walking_now := walking()
	var made := 0
	var all := 0
	var working := false
	var failed := false
	var lines := PackedStringArray()
	var any_missing := false
	var any_busy := walking_now
	for s in shown:
		var section: PipelineSection = s
		var busy_here := section.busy()
		any_busy = any_busy or busy_here
		var missing_here := section.missing()
		any_missing = any_missing or missing_here
		var said := section.told if not section.told.is_empty() else section.line()
		if not said.is_empty():
			lines.append(said)
		var head: Dictionary = _heads.get(section, {})
		if not head.is_empty():
			(head["go"] as Button).disabled = busy_here or walking_now or not missing_here
		for r in of[section]:
			var it := r as PipelineRow
			if PipelineRow.counted(it.state):
				all += 1
				if it.state == "made":
					made += 1
			working = working or it.state == "running" or it.state == "queued"
			failed = failed or it.state == "failed"
			_show_row(section, it, walking_now)
	for at in _groups:
		_show_group(at)
	_tally.text = "%s %d/%d" % ["✗" if failed else ("◌" if working else ("✓" if all > 0 and made == all else "·")), made, all]
	_tally.tooltip_text = "%d of %d made here." % [made, all]
	_generate.disabled = any_busy or not any_missing
	_stop.disabled = not any_busy
	var line := "\n".join(lines)
	if _line.text != line:
		_line.text = line
	_line.visible = not line.is_empty()


func _show_row(section: PipelineSection, it: PipelineRow, walking_now: bool) -> void:
	var r: Dictionary = _rows.get("%s/%s" % [section.title, it.key], {})
	if r.is_empty():
		return
	r["row"] = it
	(r["glyph"] as Label).text = PipelineRow.glyph(it.state)
	(r["glyph"] as Label).tooltip_text = String(Registry.field(PipelineRow.STATES, it.state, "label", ""))
	var text: Label = r["text"]
	if text.text != it.said:
		text.text = it.said
	# WHAT IS BEING DONE COMES WHOLE (2026-10-26: an 18-minute run's status sat past the end of a clipped row, and read as
	# stuck): a running row wraps to say all of it
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if it.wraps else TextServer.AUTOWRAP_OFF
	text.clip_text = not it.wraps
	text.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING if it.wraps else TextServer.OVERRUN_TRIM_ELLIPSIS
	var tip := it.tip if not it.tip.is_empty() else it.said
	text.tooltip_text = tip
	(r["name"] as Label).tooltip_text = it.tip if not it.tip.is_empty() else it.label
	var redo: Button = r["redo"]
	if not it.again.is_empty():
		redo.disabled = walking_now or not it.open
		redo.tooltip_text = it.again + ("\n\n" + it.asks if not it.asks.is_empty() else "")
	var make: Variant = r["make"]
	if make is Button:
		(make as Button).disabled = walking_now or not it.go_open
		(make as Button).tooltip_text = it.go


func _show_group(at: String) -> void:
	var g: Dictionary = _groups[at]
	var section: PipelineSection = g["section"]
	var states := {}
	for k in _rows:
		var r: Dictionary = _rows[k]
		if r["section"] == section and (r["row"] as PipelineRow).group == String(g["group"]):
			states[(r["row"] as PipelineRow).state] = true
	var lead := "·"
	if states.has("failed"):
		lead = "✗"
	elif states.has("running") or states.has("queued"):
		lead = "◌"
	elif states.has("stale"):
		lead = "⚠"
	elif states.has("made") and not states.has("missing"):
		lead = "✓"
	var said := section.group_said(String(g["group"]))
	var head: Button = g["head"]
	var text := "%s %s  %s%s" % ["▸" if bool(_folds.get(at, false)) else "▾", lead, String(g["group"]),
		(" - " + said) if not said.is_empty() else ""]
	if head.text != text:
		head.text = text
		head.tooltip_text = text


func _toggle(at: String) -> void:
	var folded := not bool(_folds.get(at, false))
	_folds[at] = folded
	var g: Dictionary = _groups.get(at, {})
	if not g.is_empty():
		Settings.write(Card.SECTION, _fold_key(String(g["group"])), folded)
	_apply_folds()


## The fold's key beside the [Card]'s: kept with every fold, the viewer's, never the note's.
func _fold_key(group: String) -> String:
	return ("%s.pipeline.%s" % [_fold_prefix, group]) if not _fold_prefix.is_empty() else "pipeline.%s" % group


func _apply_folds() -> void:
	for at in _groups:
		var folded := bool(_folds.get(at, false))
		for row in (_groups[at] as Dictionary)["rows"]:
			(row as Control).visible = not folded
		_show_group(at)


## ⟳ PRESSED: what it says, at once - or, where it throws other finished work away, once that is answered. The row read
## now, for it changes four times a second.
func _press_redo(at: String) -> void:
	var r: Dictionary = _rows.get(at, {})
	if r.is_empty():
		return
	var it: PipelineRow = r["row"]
	if not it.open or walking() or not it.redo.is_valid():
		return
	(r["section"] as PipelineSection).told = ""
	if it.asks.is_empty():
		it.redo.call()
		refresh()
		return
	_ask(it)


func _press_make(at: String) -> void:
	var r: Dictionary = _rows.get(at, {})
	if r.is_empty():
		return
	var it: PipelineRow = r["row"]
	if not it.go_open or walking() or not it.make.is_valid():
		return
	(r["section"] as PipelineSection).told = ""
	it.make.call()
	refresh()


## A YES OR A NO, NAMING WHAT IS THROWN AWAY - never a list of what else could be done.
func _ask(it: PipelineRow) -> void:
	if asking != null and is_instance_valid(asking):
		asking.queue_free()
	var ask := ConfirmationDialog.new()
	ask.title = it.again
	ask.dialog_text = "%s?\n\n%s" % [it.again, it.asks]
	ask.dialog_autowrap = true
	ask.ok_button_text = "Make again"
	var go := it.redo
	ask.confirmed.connect(func() -> void:
		ask.queue_free()
		asking = null
		go.call()
		refresh())
	ask.canceled.connect(func() -> void:
		ask.queue_free()
		asking = null)
	add_child(ask)
	asking = ask
	if is_inside_tree():
		ask.popup_centered(Vector2i(480, 0))
