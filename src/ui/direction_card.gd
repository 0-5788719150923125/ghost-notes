extends VBoxContainer
class_name DirectionCard

## DirectionCard - the Direction's card ([Direction]; next/direction.md): where to take what is made next, written beside the
## note's own words and handed to every agent above them. The card is the direction's first lines; a click opens the window it
## is written in.
##
## Refine… stands in that window ([method TextField.add_action]): a conversation with a writer about the direction ([TextRefine],
## [WriterChat]), who reads the note and changes the direction where the author sees it, turn after turn, each change one the
## window's undo takes back. Who it talks to is picked there. The conversation is kept in the note's folder and goes on with the
## window closed; the card says what the writer is doing meanwhile.
##
## The note's words are left alone: the writer changes only the direction (rules/agents/refine.yaml, `direction`), so a show's
## brief stays as its author keeps it, and the direction is changed for the next episode as often as it is wanted.

## The block this card keeps under `ghost:`.
const KEY := Direction.KEY

var _field: TextField
var _refine_btn: Button
var _status: Label
var _workspace: Object = null
var _note_path := ""
var _folder := ""
var _attached: Array = []
var _chat: WriterChat = null
var _refine: TextRefine = null


## The card for a note's panel. From [param ctx]: `workspace` (what it reads the note's words from and tells of a change), `path`
## (the note's file, where there is no workspace), `folder` (where its conversation is kept) and `blocks` (what the note is made of).
static func for_note(ctx: Dictionary) -> DirectionCard:
	var c := DirectionCard.new()
	c._workspace = ctx.get("workspace")
	c._note_path = String(ctx.get("path", ""))
	c._folder = String(ctx.get("folder", ""))
	c._attached = Components.attached_of(ctx["blocks"]) if ctx.get("blocks") is Dictionary else []
	return c


func _init() -> void:
	add_theme_constant_override("separation", 6)
	_field = TextField.new("", "Where should what is made next go? - click to write it",
		("What the next episode is about or does, beyond the note's own words, and above them: every agent that makes it is "
		+ "told this first, and follows it where the note says otherwise. An episode keeps the direction it was made from, so "
		+ "change this for the next one freely."))
	_field.window_title = "Direction"
	_field.text_changed.connect(_touch)
	add_child(_field)
	_refine_btn = Button.new()
	_refine_btn.text = "Refine…"
	_refine_btn.tooltip_text = ("Talk the direction over with a writer: it reads the note and what you wrote here - a line is "
		+ "enough - and changes the direction as you ask, where you see it, in the note's own terms. The note itself is left as it is.")
	_refine_btn.toggle_mode = true
	_refine_btn.pressed.connect(func() -> void: toggle_refine(_refine_btn))
	_field.add_action(_refine_btn)
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_font_size_override("font_size", 12)
	_status.modulate = Color(1, 1, 1, 0.7)
	_status.visible = false
	add_child(_status)


func _ready() -> void:
	chat()


func _exit_tree() -> void:
	if _chat != null:
		_chat.let_go()


func _process(_delta: float) -> void:
	if _chat == null:
		return
	_chat.poll()
	var busy := _chat.busy()
	_status.visible = busy
	if busy:
		_status.text = "The writer is at work on it: " + _chat.activity()


## The direction as written now.
func text() -> String:
	return _field.text


## The conversation about the direction, bound to this card's box: the one live in the note's folder, or read from it.
func chat() -> WriterChat:
	if _chat == null:
		_chat = WriterChat.at(TextRefine.folder_for(_folder, "direction"))
	_chat.read_text = text
	_chat.apply = _field.splice
	_chat.read_note = _note_words
	_chat.about = about
	return _chat


## What the writer is told it works on ([method WriterChat.system_of]).
func about() -> Dictionary:
	return {"what": "the note's Direction", "title": _note_title(), "direction": true, "parts": TextRefine.parts_of(_attached), "marks": []}


## Refine…: the conversation, docked into the direction's window where it is open, else beside this card in its panel
## ([RefineDock]).
func open_refine() -> void:
	_made_refine().open_beside(_refine_from())


## The Refine button's toggle: the conversation opened, or folded away ([param button] pressed while open).
func toggle_refine(button: BaseButton = null) -> void:
	_made_refine().toggle(_refine_from(), button)


func _refine_from() -> Node:
	var w := _field.window()
	return w if w != null and w.visible else self


func _made_refine() -> TextRefine:
	if _refine == null or not is_instance_valid(_refine):
		_refine = TextRefine.new(chat(), "Direction")
		add_child(_refine)
	return _refine


func capture() -> Dictionary:
	return {"text": _field.text}


func apply(block: Dictionary) -> void:
	if block.has("text") and not _field.editing() and _field.text != String(block["text"]):
		_field.text = String(block["text"])
	# who refined it, where a note kept that on the card: the conversation's first pick
	var c := chat()
	if c.pick.is_empty() and not String(block.get("writer", "")).is_empty():
		c.pick = {"agent": String(block["writer"]), "model": String(block.get("writer_model", "")), "effort": String(block.get("writer_effort", ""))}


## The panel told of a change, so the note keeps it.
func _touch() -> void:
	if _workspace != null and is_instance_valid(_workspace) and _workspace.has_method("touch"):
		_workspace.call("touch")


## The note's words as the panel holds them now (its frontmatter aside), and its title: the workspace's, else its file's.
func _note_raw() -> String:
	if _workspace != null and is_instance_valid(_workspace) and _workspace.has_method("doc_source"):
		var doc: Object = _workspace.call("doc_source")
		return String(doc.call("pull")) if doc != null and doc.has_method("pull") else ""
	return FileAccess.get_file_as_string(_note_path) if not _note_path.is_empty() and FileAccess.file_exists(_note_path) else ""


func _note_words() -> String:
	return Manuscript.strip_frontmatter(_note_raw())


func _note_title() -> String:
	return FrontMatter.field_of(_note_raw(), "title").strip_edges()
