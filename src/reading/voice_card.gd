extends VBoxContainer
class_name VoiceCard

## VoiceCard - the Voice: the note's cast and the speaker picked in it, a card [NoteCards] builds from
## the `voice` row like every other component's (next/notes.md, "the Voice as a card").
##
## ITS INSIDES ARE THE READING'S ([ReadingCast]): the cast rows (Turn, Hesitate, the list of speakers)
## are global, and every row below the list belongs to the speaker selected in it. The reading plays
## what the cast holds, so the cast stays the panel's and the card is where it is shown and kept - the
## panel hands it over in `ctx` (`cast`), as a producer is handed the panel itself.
##
## Its block is `voice:` ([method ReadingCast.capture], [method ReadingCast.apply]): every voice by the
## name the script cues it with, the reader's first.

## The block this card keeps under a document's `ghost:` key.
const KEY := "voice"

var _cast: ReadingCast
var _kept := {}     # with no cast, the block as it was handed over, so a capture never blanks it


## This card for a reading's panel, from what the panel says of itself ([method NoteCards.make]): the
## cast it shows (`cast`). A panel with no reading has no cast, and its card says so.
static func for_note(ctx: Dictionary) -> VoiceCard:
	return VoiceCard.new(ctx.get("cast") as ReadingCast)


func _init(cast: ReadingCast) -> void:
	_cast = cast
	add_theme_constant_override("separation", 8)
	if cast == null:
		var l := Label.new()
		l.text = "A voice reads a note's words on a reading's panel."
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.add_theme_font_size_override("font_size", 11)
		add_child(l)
		return
	cast.build_cast(self)
	cast.build_voice(self)


## The cast's block - or, on a panel with no cast, the block exactly as it came: a card that cannot
## edit the voices must never write an empty cast over them.
func capture() -> Dictionary:
	return _cast.capture() if _cast != null else _kept.duplicate(true)


func apply(block: Dictionary) -> void:
	if _cast != null:
		_cast.apply(block)
	else:
		_kept = block.duplicate(true)
