extends Window
class_name TextRefine

## TextRefine - Refine… for a note's text, opened from the window the text is written in (the Body's editor, the Direction's
## box): a conversation with a writer ([WriterChat]) as a chat - what the author said, what the writer said and every change it
## made to the text (the lines it took out and put in), what each turn cost and how much of it came from the cache - scrolled
## back through, kept with the note. Below it the writer picked ([AgentPick]: the agent, its model and how hard it thinks), a
## bar and the line the writer reports while it works, and the box the author writes in.
##
## It stands beside the window it was opened from ([method open_beside]), which moves aside to make room, so each change is
## seen landing in the text as the writer makes it. Closed, the conversation goes on: its owner polls it ([method
## WriterChat.poll]) and this shows what it missed when opened again.

## The writer picked last anywhere, so a new conversation starts where the last one left off.
static var last_pick := {}
## Where the conversations of a text kept in no note are: a gate's own folder, never the author's.
static var root := "user://refine"

const GAP := 16
const COL_YOU := Color(0.62, 0.72, 0.88)
const COL_WRITER := Color(0.78, 0.72, 0.94)
const COL_GONE := Color(0.92, 0.52, 0.5)
const COL_PUT := Color(0.56, 0.86, 0.6)
const COL_DIM := Color(1, 1, 1, 0.5)
const COL_ERROR := Color(1.0, 0.68, 0.42)
## The most lines of a change shown, each side.
const DIFF_LINES := 8

var chat: WriterChat

var _scroll: ScrollContainer
var _list: VBoxContainer
var _empty: Label
var _labels: Array = []          # a RichTextLabel a turn
var _pick: AgentPick
var _bar: ProgressBar
var _line: Label
var _box: TextEdit
var _go: Button
var _stop: Button
var _forget: Button
var _forget_armed := -INF
var _shown_busy := false


## A window on [param conversation], called "Refine - [param what]".
func _init(conversation: WriterChat, what: String) -> void:
	chat = conversation
	visible = false
	transient = true
	title = "Refine - %s" % what
	min_size = Vector2i(420, 420)
	close_requested.connect(hide)
	window_input.connect(func(e: InputEvent) -> void:
		if e is InputEventKey and (e as InputEventKey).pressed and (e as InputEventKey).keycode == KEY_ESCAPE:
			hide())
	var bg := PanelContainer.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var pad := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, 10)
	bg.add_child(pad)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	pad.add_child(col)

	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(_scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 14)
	_scroll.add_child(_list)
	_empty = Label.new()
	_empty.text = "No conversation yet."
	_empty.modulate = COL_DIM
	_empty.add_theme_font_size_override("font_size", 12)
	_list.add_child(_empty)

	_bar = ProgressBar.new()
	_bar.indeterminate = true
	_bar.show_percentage = false
	_bar.custom_minimum_size = Vector2(0, 6)
	_bar.visible = false
	col.add_child(_bar)
	_line = Label.new()
	_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_line.add_theme_font_size_override("font_size", 11)
	_line.modulate = Color(1, 1, 1, 0.8)
	_line.visible = false
	col.add_child(_line)

	_pick = AgentPick.writer("Who you talk it over with. A conversation is the agent's own: another agent picked mid-way is told what was said and goes on from there.")
	var start: Dictionary = chat.pick if not chat.pick.is_empty() else last_pick
	if not start.is_empty():
		_pick.set_choice(String(start.get("agent", "")), String(start.get("model", "")), String(start.get("effort", "")))
	_pick.changed.connect(func() -> void: last_pick = _pick.choice())
	col.add_child(_pick)

	_box = TextEdit.new()
	_box.custom_minimum_size = Vector2(0, 84)
	_box.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_box.placeholder_text = "What should change? Which part is wrong, and how should it read instead - or ask about it."
	_box.tooltip_text = "Enter sends; Shift+Enter starts a new line. The writer sees the text as it stands, your edits included."
	_box.gui_input.connect(_box_key)
	col.add_child(_box)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	col.add_child(row)
	_forget = Button.new()
	_forget.text = "New conversation"
	_forget.focus_mode = Control.FOCUS_NONE
	_forget.tooltip_text = "Start again: this conversation is forgotten, and the writer's next turn knows only the text as it stands. Press twice."
	_forget.pressed.connect(_forget_pressed)
	row.add_child(_forget)
	var room := Control.new()
	room.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(room)
	_stop = Button.new()
	_stop.text = "Stop"
	_stop.tooltip_text = "Stop the writer. What it changed so far stays, and each change can be taken back in the text (Ctrl+Z)."
	_stop.visible = false
	_stop.pressed.connect(func() -> void: chat.stop())
	row.add_child(_stop)
	_go = Button.new()
	_go.text = "Send"
	_go.tooltip_text = "Send what you wrote to the writer. It changes the text as you ask, where you see it, and says what it did."
	_go.pressed.connect(send)
	row.add_child(_go)

	chat.changed.connect(_redraw)
	_redraw()


## Shown beside [param host] (the window the text is written in): to its right where there is room, else with [param host]
## moved left, narrowed as far as its own least width, to make it.
func open_beside(host: Window) -> void:
	_pick.mark_available()
	var screen := Vector2i(get_tree().root.get_visible_rect().size) if is_inside_tree() else Vector2i(1600, 900)
	var w := clampi(int(screen.x * 0.3), min_size.x, 640)
	var h := screen.y - 2 * GAP
	var y := GAP
	var x := screen.x - w - GAP
	if host != null and host.visible:
		h = maxi(min_size.y, host.size.y)
		y = host.position.y
		if host.position.x + host.size.x + GAP + w > screen.x - GAP:
			var host_w := maxi(host.min_size.x, mini(host.size.x, screen.x - w - 3 * GAP))
			host.position = Vector2i(GAP, host.position.y)
			host.size = Vector2i(host_w, host.size.y)
		x = mini(host.position.x + host.size.x + GAP, screen.x - w - GAP)
	if not visible:
		popup(Rect2i(x, y, w, h))
	position = Vector2i(x, y)
	size = Vector2i(w, h)
	_scroll_down()
	_box.grab_focus()


## What is written in the box sent, and the box emptied.
func send() -> void:
	var why := chat.send(_box.text, _pick.choice())
	if not why.is_empty():
		_say(why.substr(0, 1).to_upper() + why.substr(1) + ".")
		return
	last_pick = _pick.choice()
	_box.text = ""
	_scroll_down()


func _box_key(e: InputEvent) -> void:
	var k := e as InputEventKey
	if k == null or not k.pressed or k.echo or (k.keycode != KEY_ENTER and k.keycode != KEY_KP_ENTER):
		return
	if k.shift_pressed:
		return
	_box.accept_event()
	if not chat.busy():
		send()


func _forget_pressed() -> void:
	var t := Time.get_ticks_msec() / 1000.0
	if t - _forget_armed > ArmedDelete.ARMED:
		_forget_armed = t
		_forget.text = "Forget it?"
		_forget.add_theme_color_override("font_color", Color(1.0, 0.55, 0.5))
		get_tree().create_timer(ArmedDelete.ARMED).timeout.connect(func() -> void:
			if is_instance_valid(_forget):
				_forget.text = "New conversation"
				_forget.remove_theme_color_override("font_color"))
		return
	_forget_armed = -INF
	_forget.text = "New conversation"
	_forget.remove_theme_color_override("font_color")
	chat.clear()


func _process(_delta: float) -> void:
	if not visible:
		return
	var busy := chat.busy()
	if busy != _shown_busy:
		_shown_busy = busy
		_bar.visible = busy
		_stop.visible = busy
		_go.disabled = busy
		_say("")
	if busy:
		_say(chat.activity())


func _say(what: String) -> void:
	_line.text = what
	_line.visible = not what.is_empty()


## The turns shown: the last one drawn again (it is the one that grows), any new ones added, and all of them when the
## conversation started again.
func _redraw() -> void:
	if chat.turns.size() < _labels.size():
		for l in _labels:
			(l as Node).queue_free()
		_labels.clear()
	var at_end := _at_end()
	for i in range(maxi(0, mini(_labels.size(), chat.turns.size()) - 1), chat.turns.size()):
		if i >= _labels.size():
			_labels.append(_turn_label())
			_list.add_child(_labels[i])
		(_labels[i] as RichTextLabel).text = turn_bbcode(chat.turns[i])
	_empty.visible = chat.turns.is_empty()
	if at_end:
		_scroll_down()


func _turn_label() -> RichTextLabel:
	var l := RichTextLabel.new()
	l.bbcode_enabled = true
	l.fit_content = true
	l.scroll_active = false
	l.selection_enabled = true
	l.context_menu_enabled = true
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.add_theme_font_size_override("normal_font_size", 13)
	l.add_theme_font_size_override("bold_font_size", 13)
	l.add_theme_font_size_override("mono_font_size", 12)
	return l


func _at_end() -> bool:
	var bar := _scroll.get_v_scroll_bar()
	return bar == null or _scroll.scroll_vertical >= int(bar.max_value - bar.page) - 24


func _scroll_down() -> void:
	if not is_inside_tree():
		return
	await get_tree().process_frame
	await get_tree().process_frame
	if is_instance_valid(_scroll):
		_scroll.scroll_vertical = int(_scroll.get_v_scroll_bar().max_value)


# --- what the writer is told it works on, and its changes landing --------------------------------------------------

## Where the conversation about the text [param key] ("body", "direction") is kept: in the note's folder [param note_folder]
## (it moves with the note), else under [member root].
static func folder_for(note_folder: String, key: String) -> String:
	return (note_folder.path_join("refine") if not note_folder.is_empty() else root).path_join(key)


## The marks a text in the panel [param mode] may carry, as the writer is told them ([method WriterChat.system_of]): each
## mark's name, its sample as the palette inserts it, and what it does there ([ScriptMarks]).
static func marks_of(mode: String) -> Array:
	var out: Array = []
	for k in ScriptMarks.for_mode(mode):
		out.append({"label": String(ScriptMarks.REGISTRY[k]["label"]), "example": ScriptMarks.example(k), "blurb": ScriptMarks.blurb(k, mode)})
	return out


## What a note with [param attached] is made of, as the writer is told it: each component's name and its own blurb
## ([Components]).
static func parts_of(attached: Array) -> Array:
	var out: Array = []
	for k in attached:
		if Components.REGISTRY.has(k):
			out.append({"label": Registry.label(Components.REGISTRY, k), "blurb": Registry.blurb(Components.REGISTRY, k)})
	return out


## [param gone] characters from [param at] in [param te] replaced by [param put], as one step its undo takes back, the
## caret and selection left where they were.
static func splice(te: TextEdit, at: int, gone: int, put: String) -> void:
	var text := te.text
	at = clampi(at, 0, text.length())
	gone = clampi(gone, 0, text.length() - at)
	var before := text.substr(0, at)
	var upto := text.substr(0, at + gone)
	var line := before.count("\n")
	var column := at - (before.rfind("\n") + 1)
	te.begin_complex_operation()
	if gone > 0:
		te.remove_text(line, column, upto.count("\n"), at + gone - (upto.rfind("\n") + 1))
	if not put.is_empty():
		te.insert_text(put, line, column, false, false)
	te.end_complex_operation()


# --- a turn as it reads ----------------------------------------------------------------------------------------------

## One turn as the chat shows it: what the author said, then the writer's words and changes in the order they came, its
## reply, what it cost, and why it stopped if it did.
static func turn_bbcode(turn: Dictionary) -> String:
	var out := PackedStringArray()
	out.append("[color=#%s][b]You[/b][/color]" % COL_YOU.to_html(false))
	out.append(escaped(String(turn.get("you", ""))))
	out.append("")
	var who := String(turn.get("agent", "writer")).capitalize()
	var how := PackedStringArray()
	if not String(turn.get("model", "")).is_empty():
		how.append(model_label(String(turn.get("agent", "")), String(turn["model"])))
	if not String(turn.get("effort", "")).is_empty():
		how.append(TextGen.effort_label(String(turn["effort"])))
	var tail := " · ".join(how)
	out.append("[color=#%s][b]%s[/b]%s[/color]" % [COL_WRITER.to_html(false), who, (" [color=#%s]%s[/color]" % [COL_DIM.to_html(true), tail]) if not tail.is_empty() else ""])
	for e in turn.get("events", []):
		var d: Dictionary = e
		if d.has("said"):
			out.append(markdown(String(d["said"])))
		elif String(d.get("tool", "")) == "edit":
			out.append(edit_bbcode(String(d.get("old", "")), String(d.get("new", "")), int(d.get("count", 1))))
		elif String(d.get("tool", "")) == "write":
			out.append("[color=#%s]Wrote the text whole (%d words).[/color]" % [COL_DIM.to_html(true), int(d.get("words", 0))])
	if not String(turn.get("reply", "")).is_empty():
		out.append(markdown(String(turn["reply"])))
	if bool(turn.get("running", false)) and (turn.get("events", []) as Array).is_empty():
		out.append("[color=#%s]…[/color]" % COL_DIM.to_html(true))
	var cost := usage_line(turn.get("usage", {}) if turn.get("usage") is Dictionary else {})
	if not cost.is_empty():
		out.append("[font_size=11][color=#%s]%s[/color][/font_size]" % [COL_DIM.to_html(true), cost])
	var err := String(turn.get("error", ""))
	if not err.is_empty():
		out.append("[color=#%s]%s[/color]" % [COL_ERROR.to_html(false), "Stopped." if err == "stopped" else "Stopped: " + escaped(err)])
	return "\n".join(out)


## A change as the chat shows it: the lines taken out, struck, and the lines put in - the lines both sides share at their
## ends left out, so a line added shows alone - each side cut to [constant DIFF_LINES].
static func edit_bbcode(old: String, new: String, count := 1) -> String:
	var out := PackedStringArray()
	if count > 1:
		out.append("[color=#%s]Changed %d places:[/color]" % [COL_DIM.to_html(true), count])
	var a := old.split("\n")
	var b := new.split("\n")
	var head := 0
	while head < a.size() and head < b.size() and a[head] == b[head]:
		head += 1
	var tail := 0
	while tail < a.size() - head and tail < b.size() - head and a[a.size() - 1 - tail] == b[b.size() - 1 - tail]:
		tail += 1
	for side in [[a.slice(head, a.size() - tail), COL_GONE, "-", true], [b.slice(head, b.size() - tail), COL_PUT, "+", false]]:
		var lines: PackedStringArray = side[0]
		if lines.is_empty():
			continue
		for i in mini(lines.size(), DIFF_LINES):
			var l := escaped(String(lines[i]))
			out.append("[code][color=#%s]%s %s[/color][/code]" % [(side[1] as Color).to_html(false), side[2],
				("[s]%s[/s]" % l) if bool(side[3]) and not l.strip_edges().is_empty() else l])
		if lines.size() > DIFF_LINES:
			out.append("[color=#%s]  … %d more lines[/color]" % [COL_DIM.to_html(true), lines.size() - DIFF_LINES])
	return "\n".join(out)


## The model [param key] as [param agent]'s picker names it ("opus" is "Opus"), the key itself where it lists none.
static func model_label(agent: String, key: String) -> String:
	var cls: Variant = Registry.field(TextGen.REGISTRY, agent, "backend", null)
	if cls is GDScript:
		for m in (cls as GDScript).call("models"):
			if String((m as Dictionary).get("key", "")) == key:
				return String((m as Dictionary)["label"])
	return key


## What a turn cost: tokens read new, read from the cache, written to it, written out, and dollars where the CLI says.
static func usage_line(u: Dictionary) -> String:
	var parts := PackedStringArray()
	for pair in [["fresh", "new"], ["cached", "from the cache"], ["made", "into the cache"], ["out", "out"]]:
		var n := int(u.get(String(pair[0]), 0))
		if n > 0:
			parts.append("%s %s" % [TextGen.count(n), String(pair[1])])
	if float(u.get("usd", 0.0)) > 0.0:
		parts.append("$%.3f" % float(u["usd"]))
	return " · ".join(parts)


## [param text] shown as written: a bracket never read as a tag.
static func escaped(text: String) -> String:
	return text.replace("[", "[lb]")


static var _rx_head: RegEx
static var _rx_bold: RegEx
static var _rx_code: RegEx

## A writer's Markdown, lightly: bold, code and headings drawn, the rest as written.
static func markdown(text: String) -> String:
	if _rx_head == null:
		_rx_head = RegEx.create_from_string("^#{1,6}\\s+(.*)$")
		_rx_bold = RegEx.create_from_string("\\*\\*(.+?)\\*\\*")
		_rx_code = RegEx.create_from_string("`([^`]+)`")
	var lines := PackedStringArray()
	for line in escaped(text).split("\n"):
		var l := String(line)
		var h := _rx_head.search(l)
		if h != null:
			l = "[b]%s[/b]" % h.get_string(1)
		l = _rx_bold.sub(l, "[b]$1[/b]", true)
		l = _rx_code.sub(l, "[code]$1[/code]", true)
		lines.append(l)
	return "\n".join(lines)
