extends ReadingPanel
class_name GenerativeEditor

## GenerativeEditor - the Generative mode: a chapter read aloud in the neural voice, shown in the
## medium the author picks. Everything that reads is [ReadingPanel]'s; this panel adds the cards a
## chapter's picture is made of (next/notes.md step 5) - the Picture ([PictureCard]: the medium,
## the films, the book's pictures, the Director's dials), the Look ([LookCard]) and the bookends
## ([BookendsCard]) - and keeps their blocks in the chapter's frontmatter beside the voice.
##
## ONE PLACE TO REACH FOR A PICTURE SETTING beats an architecturally tidier second home nobody
## finds: the Director's picture settings drive every mode but Masking, and this panel is where
## most of them are set. In the notes model a card is that second home, found because it appears
## wherever a picture is made.

var _picture: PictureCard


func _init() -> void:
	_section = "generative"


func _panel_title() -> String:
	return "Generative"


func _panel_hint() -> String:
	return "Write or open a chapter. It is spoken in chunks, so the show starts while the rest is still being made. Edit lists every mark the reading understands - speakers, hesitations, pictures, pronunciations."


## A chapter's blocks: the voice, the picture, its pictures, the Look and the bookends.
func _doc_blocks() -> PackedStringArray:
	return PackedStringArray(["voice", "picture", "illustrations", "look", "bookends"])


func _build_cards() -> void:
	_picture = PictureCard.new()
	_add_block_card("Picture", &"picture", _picture)
	_add_block(_picture.illustrations())
	_add_block_card("Look", &"look", LookCard.new())
	_add_block_card("Intro & outro", &"paper", BookendsCard.new())


## The book's pictures follow the chapter's text.
func _script_text_changed(body: String) -> void:
	if _picture != null:
		_picture.set_script_text(body)
