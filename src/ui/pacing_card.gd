extends VBoxContainer
class_name PacingCard

## PacingCard - THE PANEL'S PACING CARD: the numbers the note's show may be paced by, as rows ([TuneSection], handed by whatever reads
## them), each a slider within its bounds and unset at its default. The card is shown only while some section offers a row, and hidden
## otherwise: a show with nothing to pace has no Pacing card. Looked at again every second (what a section offers follows what is
## being shown - an episode picked, acts made again), and drawn again only when that changed.

## What the card is for, on its title bar and its chip ([member Card.blurb]).
const BLURB := "The numbers this show can be paced by, each at its default until you move it. Shown while something on the note offers one."
const POLL := 60              # frames between looks

var _sections: Callable       # () -> Array of TuneSection
var _form: SchemaForm
var _seen := 0
var _owner_of := {}           # key -> the section that offers it


func _init(sections: Callable) -> void:
	_sections = sections
	add_theme_constant_override("separation", 4)
	var said := Label.new()
	said.text = "What the show is paced by, for this show alone. Unset is the default; a change is heard the next time it is set (Play)."
	said.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	said.add_theme_font_size_override("font_size", 11)
	said.modulate = Color(1, 1, 1, 0.6)
	add_child(said)
	_form = SchemaForm.new()
	_form.edited.connect(func(key: String, value: Variant) -> void:
		var s: TuneSection = _owner_of.get(key)
		if s != null:
			s.set_value(key, value)
		refresh(true))
	add_child(_form)


func _ready() -> void:
	refresh()


func _process(_delta: float) -> void:
	if Engine.get_process_frames() % POLL == 0:
		refresh()


## WHAT IS OFFERED, LOOKED AT AGAIN: the card shown with rows and hidden without, the rows drawn again where they or their values
## changed ([param force]: drawn again regardless).
func refresh(force := false) -> void:
	var rows := {}
	var values := {}
	_owner_of = {}
	for s in (_sections.call() if _sections.is_valid() else []):
		var sec := s as TuneSection
		if sec == null:
			continue
		var r := sec.rows()
		for k in r:
			rows[k] = r[k]
			_owner_of[k] = sec
		values.merge(sec.values(), true)
	var card := _card()
	if card != null:
		card.visible = not rows.is_empty()
	var h := hash([JSON.stringify(rows), JSON.stringify(values)])
	if h == _seen and not force:
		return
	_seen = h
	_form.show_fields(rows, values)


## How many rows are offered now.
func row_count() -> int:
	return _owner_of.size()


func _card() -> Card:
	var n: Node = get_parent()
	while n != null and not (n is Card):
		n = n.get_parent()
	return n as Card
