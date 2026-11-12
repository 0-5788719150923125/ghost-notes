extends Window
class_name SourceWindow

## SourceWindow - the edit button on a row: one thing an agent made, as text, in a window of its own
## (next/editing.md step 4). Its words, or its data as JSON; Apply hands the text to whoever opened it
## ([member take]), who writes it where it lives - as a hand's version, kept - or says why not, and then
## the window stays open on what was typed with the reason above it. Every note a taker's checks find
## ([member notes]) is shown.

## (text: String) -> String: the text taken, "" when it was written, else why not.
var take: Callable = Callable()
## () -> PackedStringArray: what the taker's checks say of what stands now (shown under the text; empty for nothing).
var notes: Callable = Callable()
## () -> PackedStringArray: the versions kept of it, oldest first, each in a few words ("made by the reader, 11-10 04:15");
## invalid or empty, none is offered. What a refresh or an edit replaced is one of them (TableEpisode.versions).
var versions: Callable = Callable()
## (i: int) -> String: version [param i] put back, what stands a version back - "" done; then [method reread] shows it.
var restore: Callable = Callable()
## () -> String: the text as it stands now, read again after a version is put back.
var reread: Callable = Callable()
## (note: String) -> String: ask its maker for it again with a note (next/editing.md step 9) - "" asked; invalid, not offered.
var ask: Callable = Callable()
## Who is asked ("the reader"), for the button's words.
var ask_who := ""

var text_edit: CodeEdit
var _said: Label
var _notes: Label
var _apply: Button
var _versions: OptionButton
var _put_back: Button
var _ask_row: HBoxContainer
var _ask_note: LineEdit
var _ask_b: Button


func _init() -> void:
	visible = false
	transient = true
	min_size = Vector2i(720, 420)
	close_requested.connect(hide)
	window_input.connect(func(e: InputEvent) -> void:
		if e is InputEventKey and e.pressed and e.keycode == KEY_ESCAPE:
			hide())
	var bg := PanelContainer.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	bg.add_child(margin)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	margin.add_child(col)
	_said = Label.new()
	_said.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_said.add_theme_font_size_override("font_size", 12)
	_said.modulate = Color(1.0, 0.75, 0.45)
	_said.visible = false
	col.add_child(_said)
	text_edit = CodeEdit.new()
	text_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	text_edit.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_edit.auto_brace_completion_enabled = false
	text_edit.indent_automatic = false
	text_edit.code_completion_enabled = false
	text_edit.add_theme_font_size_override("font_size", 15)
	col.add_child(text_edit)
	_notes = Label.new()
	_notes.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_notes.add_theme_font_size_override("font_size", 11)
	_notes.modulate = Color(1, 1, 1, 0.6)
	_notes.visible = false
	col.add_child(_notes)
	_ask_row = HBoxContainer.new()
	col.add_child(_ask_row)
	_ask_note = LineEdit.new()
	_ask_note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ask_note.placeholder_text = "Or say what to change, and ask for it again"
	_ask_row.add_child(_ask_note)
	_ask_b = Button.new()
	_ask_b.tooltip_text = "Make it again with your note: what stands goes a version back, and plays until the new one lands."
	_ask_b.pressed.connect(func() -> void: ask_again(_ask_note.text))
	_ask_row.add_child(_ask_b)
	var foot := HBoxContainer.new()
	foot.alignment = BoxContainer.ALIGNMENT_END
	col.add_child(foot)
	_versions = OptionButton.new()
	_versions.tooltip_text = "The versions kept of it, oldest first: what a ⟳ or an edit replaced."
	foot.add_child(_versions)
	_put_back = Button.new()
	_put_back.text = "Put back"
	_put_back.tooltip_text = "Put the version picked back: what stands goes a version back, and the one put back is kept as yours."
	_put_back.pressed.connect(func() -> void: put_back(_versions.selected))
	foot.add_child(_put_back)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(gap)
	var cancel := Button.new()
	cancel.text = "Cancel"
	cancel.tooltip_text = "Close it, keeping what stands."
	cancel.pressed.connect(hide)
	foot.add_child(cancel)
	_apply = Button.new()
	_apply.text = "Apply"
	_apply.tooltip_text = "Write it where it lives, as your version: what stood goes a version back, and Generate leaves yours as it is."
	_apply.pressed.connect(apply)
	foot.add_child(_apply)


## Open on [param text], titled [param heading], over [param over]; [param highlighter] colors its marks (none for data).
func open_on(heading: String, text: String, over: Node, highlighter: SyntaxHighlighter = null) -> void:
	title = heading
	text_edit.text = text
	text_edit.syntax_highlighter = highlighter
	_said.visible = false
	_show_notes()
	_fill_versions()
	_ask_row.visible = ask.is_valid()
	_ask_b.text = "Ask %s again" % (ask_who if not ask_who.is_empty() else "its maker")
	_ask_note.text = ""
	if not is_inside_tree():
		over.add_child(self)
	TextField.pop_up(self, over, Vector2(0.72, 0.78))
	text_edit.grab_focus()


## The first [param needle] in the text, picked and brought into view - what a click on the stage named, found in its data. False
## when it is not there.
func find_text(needle: String) -> bool:
	var all := text_edit.text
	var at := all.find(needle) if not needle.is_empty() else -1
	if at < 0:
		return false
	var line := all.substr(0, at).count("\n")
	var col := at - (all.rfind("\n", at - 1) + 1) if at > 0 else 0
	text_edit.select(line, col, line, col + needle.length())
	text_edit.set_caret_line(line)
	text_edit.set_caret_column(col + needle.length())
	text_edit.center_viewport_to_caret()
	return true


## Apply: the text handed over; written, the window closes - refused, it stays, saying why. Returns what the taker said.
func apply() -> String:
	var err: String = take.call(text_edit.text) if take.is_valid() else "nothing here can take it"
	if err.is_empty():
		_said.visible = false
		hide()
	else:
		_said.text = "Not written: " + err
		_said.visible = true
	_fill_versions()
	_show_notes()
	return err


## Asked again with [param note]: handed to whoever made it; asked, the window closes. Returns what the asker said.
func ask_again(note: String) -> String:
	if note.strip_edges().is_empty():
		_said.text = "Say what to change first."
		_said.visible = true
		return _said.text
	var err: String = ask.call(note) if ask.is_valid() else "nothing here can be asked again"
	if err.is_empty():
		hide()
	else:
		_said.text = "Not asked: " + err
		_said.visible = true
	return err


## Version [param i] put back, and shown: what stands goes a version back first. Returns what the restorer said.
func put_back(i: int) -> String:
	var err: String = restore.call(i) if restore.is_valid() else "there is nothing to put back"
	if err.is_empty():
		if reread.is_valid():
			text_edit.text = String(reread.call())
		_said.visible = false
	else:
		_said.text = "Not put back: " + err
		_said.visible = true
	_fill_versions()
	_show_notes()
	return err


func _fill_versions() -> void:
	var list: PackedStringArray = versions.call() if versions.is_valid() else PackedStringArray()
	_versions.clear()
	for v in list:
		_versions.add_item(v)
	if not list.is_empty():
		_versions.select(list.size() - 1)
	_versions.visible = not list.is_empty()
	_put_back.visible = not list.is_empty()


func _show_notes() -> void:
	var said: PackedStringArray = notes.call() if notes.is_valid() else PackedStringArray()
	_notes.text = ("What its checks say of it now:\n- " + "\n- ".join(said)) if not said.is_empty() else ""
	_notes.visible = not said.is_empty()
