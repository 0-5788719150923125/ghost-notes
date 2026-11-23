extends Window
class_name EpisodeScript

## EpisodeScript - an episode's script, read and edited (the Episode card's Script…): every word as it was made, its table marks
## each saying what it is (a picture its name and what it shows, a throw what came of it, [method TableProducer.readable_script]),
## highlighted as a note's words are ([ScriptHighlighter]), found and replaced in ([FindBar]), and talked over with a writer
## (Refine…, [TextRefine], [WriterChat]) who changes it here as the author watches.
##
## Save writes it back ([method TableProducer.write_script]): the words to their passages, each kept as the author's; a picture's
## new words painted again, and that page alone (its own picture, [method TableEpisode.page_key]); a picture added or moved. Every
## other mark stands as it stood - what was thrown was thrown - and one changed is refused, said above the text. The mark under the
## caret is said in full below it. The conversation is kept in the episode's folder.

var episode: TableEpisode
var producer: TableProducer
## Called after a save is written, for the card to show what it changed.
var saved := Callable()

var _text: CodeEdit
var _said: Label
var _under: Label
var _find: FindBar
var _chat: WriterChat = null
var _refine: TextRefine = null


func _init() -> void:
	title = "Script"
	visible = false
	transient = true
	min_size = Vector2i(760, 440)
	close_requested.connect(hide)
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
	_said.add_theme_color_override("font_color", Color(1.0, 0.75, 0.5))
	_said.visible = false
	col.add_child(_said)
	_text = CodeEdit.new()
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text.custom_minimum_size = Vector2(420, 240)
	_text.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.highlight_current_line = true
	# Prose, not code: nothing may type a character the author did not.
	_text.auto_brace_completion_enabled = false
	_text.indent_automatic = false
	_text.code_completion_enabled = false
	_text.add_theme_font_size_override("font_size", 16)
	_text.add_theme_constant_override("line_spacing", 6)
	_text.syntax_highlighter = ScriptHighlighter.new("table")
	_text.caret_changed.connect(_say_under)
	_find = FindBar.new(_text)
	col.add_child(_find.stack())
	_under = Label.new()
	_under.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_under.add_theme_font_size_override("font_size", 12)
	_under.modulate = Color(1, 1, 1, 0.75)
	col.add_child(_under)
	var foot := HBoxContainer.new()
	col.add_child(foot)
	var hint := Label.new()
	hint.text = ("What follows a picture's bar is what it shows: change it and that page is painted again; add one with \"picture new\". "
		+ "Every other mark is what happened, and stands.")
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.add_theme_font_size_override("font_size", 11)
	hint.modulate = Color(1, 1, 1, 0.55)
	foot.add_child(hint)
	foot.add_child(_find.button())
	var refine := Button.new()
	refine.text = "Refine…"
	refine.tooltip_text = ("Talk the script over with a writer: say what to change, and it changes it here as you watch - the words, "
		+ "and what each picture shows, and where pictures fall - never what was thrown. Each change is a step Ctrl+Z takes back; Save "
		+ "keeps them.")
	refine.pressed.connect(_open_refine)
	foot.add_child(refine)
	var save := Button.new()
	save.text = "Save"
	save.tooltip_text = "Write it back: the words to their passages, kept as yours, and each picture changed painted again by Generate."
	save.pressed.connect(_save)
	foot.add_child(save)
	var done := Button.new()
	done.text = "Done"
	done.pressed.connect(hide)
	foot.add_child(done)


## Opened on [param ep]'s script as it stands, over [param over].
func open_on(ep: TableEpisode, p: TableProducer, over: Node) -> void:
	episode = ep
	producer = p
	title = "Script - %s" % String((ep.read_json("plan") as Dictionary).get("episode_title", "")) if ep.read_json("plan") is Dictionary else "Script"
	_text.text = p.readable_script()
	_text.clear_undo_history()
	_said.visible = false
	_say_under()
	TextField.pop_up(self, over, Vector2(0.82, 0.82))
	_text.grab_focus()


func _save() -> void:
	if producer == null:
		return
	var err := producer.write_script(_text.text)
	_said.visible = not err.is_empty()
	_said.text = err
	if err.is_empty():
		var at := _text.get_caret_line()
		_text.text = producer.readable_script()
		_text.set_caret_line(mini(at, _text.get_line_count() - 1))
		if saved.is_valid():
			saved.call()


## The table mark on the caret's line, said in full: what it is, and whether it may be changed.
func _say_under() -> void:
	var line := _text.get_line(_text.get_caret_line()) if _text.get_line_count() > 0 else ""
	var m := RegEx.create_from_string(TableProducer.MARK_RX).search(line)
	if m == null:
		_under.text = ""
		return
	var kind := m.get_string(1)
	var said := m.get_string(3).strip_edges()
	_under.text = ("%s %s: %s" % [kind.capitalize(), m.get_string(2), said if not said.is_empty() else "(nothing more)"]) \
		+ ("  - its words may be changed" if kind == "picture" else "  - stands as it happened")


# --- Refine… -------------------------------------------------------------------------------------------------------------

func _chat_of() -> WriterChat:
	if _chat == null:
		_chat = WriterChat.at(TextRefine.folder_for(episode.dir, "script"))
	_chat.read_text = func() -> String: return _text.text
	_chat.apply = func(at: int, gone: int, put: String) -> void: TextRefine.splice(_text, at, gone, put)
	_chat.about = func() -> Dictionary:
		var plan: Variant = episode.read_json("plan")
		return {"what": "one episode's script", "title": String((plan as Dictionary).get("episode_title", "")) if plan is Dictionary else "",
			"episode": true, "marks": TextRefine.marks_of("table")}
	return _chat


func _open_refine() -> void:
	if episode == null:
		return
	if _refine == null or not is_instance_valid(_refine):
		_refine = TextRefine.new(_chat_of(), "Script")
		add_child(_refine)
	_refine.open_beside(self)


func _exit_tree() -> void:
	if _chat != null:
		_chat.let_go()
