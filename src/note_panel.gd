extends CanvasLayer
class_name NotePanel

## NotePanel - a note with nothing attached (next/notes.md step 8): "with nothing attached, it is a
## text editor". The panel holds the note's own words - the Script card, synced to the file, its
## body edited in place and written back on a quiet period as every panel's is ([DocSource]) - and
## the component row's "+", which lists what the note could become: a Voice, a Voice lab, Tarot, a
## song, a clip, each grayed with its reason when it cannot be had here ([Components.attach_menu]).
##
## ATTACHING WRITES THE COMPONENT'S BLOCK into the note and opens the note again - now run by the
## template its blocks name ([method Components.template_for]): attach a Voice and it is read
## aloud. A component that keeps nothing in the note on its own (a Look with no picture yet) is
## attached inside the panel that has its card, so "+" here offers only what decides what the note
## is.

## The Settings section the script's source lives in (its remembered document).
const SECTION := "note"
## What "+" offers a note with nothing attached: the components that decide what it becomes.
const DECIDES := ["voice", "voice_lab", "tarot", "song", "clip"]

## Set by main: the note this panel shows, and how to open it again once a component is attached.
var path := ""
var reopen: Callable

var _panel: SidePanel
var _writer: ScriptWriter
var _plus: MenuButton


func _ready() -> void:
	layer = 10
	# NOTHING TO RENDER: a plain note has no stage, so the ⤓ is not there (released on the way out,
	# keyed - see Chrome._export_claims)
	var ch := Chrome.of(self)
	if ch != null:
		ch.suppress_export(&"note_panel")
	_panel = preload("res://src/side_panel.gd").new(380.0)
	_panel.title = "Note"
	add_child(_panel)
	var box: VBoxContainer = _panel.body
	box.add_theme_constant_override("separation", 8)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 6)
	box.add_child(head)
	head.add_child(Chrome.back_button(self))
	var title := Label.new()
	title.text = NoteStore.title_of(path) if not path.is_empty() else "Note"
	title.add_theme_font_size_override("font_size", 20)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	head.add_child(title)
	# THE COMPONENT ROW: nothing attached yet, so only "+"
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	box.add_child(row)
	_plus = MenuButton.new()
	_plus.text = "+"
	_plus.flat = false
	_plus.tooltip_text = "Attach what this note should become - each one grayed, with the reason, when it cannot be had here."
	_plus.about_to_popup.connect(func() -> void: Components.attach_menu(_plus.get_popup(), ["text"], DECIDES))
	_plus.get_popup().id_pressed.connect(_attach)
	row.add_child(_plus)
	var hint := Label.new()
	hint.text = "Just the words, for now."
	hint.add_theme_font_size_override("font_size", 12)
	hint.modulate = Color(1, 1, 1, 0.6)
	row.add_child(hint)
	_panel.card_prefix = SECTION
	_panel.add_card_row()
	var card: VBoxContainer = _panel.add_card("script", "Script", &"paper")
	# THE NOTE'S OWN FILE, from the first frame: the source is pointed at it before it is bound
	Settings.write(SECTION, "doc_path", path)
	Settings.write(SECTION, "sync", not path.is_empty())
	_writer = preload("res://src/script_writer.gd").new()
	_writer.setup(SECTION, PackedStringArray([]), SECTION)
	card.add_child(_writer)
	_writer.doc.bind_text(_writer.text_edit)


func _exit_tree() -> void:
	var ch := Chrome.of(self)
	if ch != null:
		ch.release_export(&"note_panel")


func _attach(id: int) -> void:
	var pop := _plus.get_popup()
	var i := pop.get_item_index(id)
	if i < 0 or pop.is_item_disabled(i):
		return
	var key := String(pop.get_item_metadata(i))
	var add := Components.attach_blocks(key)
	if add.is_empty() or path.is_empty():
		return
	var ghost := NoteStore.blocks_of(path)
	ghost.merge(add, false)
	var err := FrontMatter.write_block(path, ghost)
	if not err.is_empty():
		push_warning("ghost: could not attach %s to %s - %s" % [key, path.get_file(), err])
		return
	if reopen.is_valid():
		reopen.call(path)
