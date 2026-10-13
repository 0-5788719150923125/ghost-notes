extends ReadingPanel
class_name GenerativeEditor

## GenerativeEditor - the reading workspace: a note with a Voice, its text read aloud in the neural
## voice. Everything that reads is [ReadingPanel]'s, and what the reading is SEEN in is the note's:
## the cards of whatever else it has attached - the Picture ([PictureCard]: the medium, the films,
## the book's pictures, the Director's dials), a Storyboard, the Look, the bookends - built as every
## panel builds them ([NoteCards]) and kept in the note's frontmatter beside the voice. A voice with
## no Picture is heard, with its words over an empty frame.
##
## Started without a note (the command line, a gate) it is the whole classic panel: the Picture,
## the Look and the bookends, every time.

var _picture: PictureCard


func _init() -> void:
	_section = "generative"


func _panel_title() -> String:
	return "Generative"


func _panel_hint() -> String:
	return "Write or open a chapter. It is spoken in chunks, so the show starts while the rest is still being made. Edit lists every mark the reading understands - speakers, hesitations, pictures, pronunciations."


## Without a note, a chapter's blocks: the voice, the picture, its pictures, the Look and the
## bookends.
func _classic_blocks() -> PackedStringArray:
	return PackedStringArray(["voice", "picture", "illustrations", "look", "bookends", "youtube"])


func _classic_components() -> Array:
	return ["text", "voice", "picture", "illustrations", "look", "bookends"]


func _classic_cards() -> void:
	_picture = PictureCard.new()
	_add_block_card("Picture", &"picture", _picture)
	_add_block(_picture.illustrations())
	_add_block_card("Look", &"look", LookCard.new())
	_add_block_card("Intro & outro", &"paper", BookendsCard.new())


## The note's cards, and with a Picture the book's own pictures: they are set inside its card and
## keep a block of their own.
func _note_cards(ctx := {}) -> void:
	super._note_cards(ctx)
	_picture = _block_cards.get("picture") as PictureCard
	if _picture != null:
		_add_block(_picture.illustrations())


## The book's pictures follow the chapter's text.
func _script_text_changed(body: String) -> void:
	if _picture != null:
		_picture.set_script_text(body)
