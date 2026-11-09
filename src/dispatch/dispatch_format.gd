extends VBoxContainer
class_name DispatchFormat

## DispatchFormat - the Dispatch desk's own rows on the Medium card: the note played at a desk late at night, seen from
## the chair - a terminal that types, a dozen labeled phones that ring and are held to the ear, a radar, a receiver, a
## printer, small screens, roots growing across the desk ([DispatchMedium], next/dispatch.md). The Dispatch desk was a
## component of its own, with a card that pinned its medium, until it became one of the Medium card's formats
## (2026-11-09, [MediumCard]).
##
## THE NOTE IS THE SCRIPT, word for word. Its `desk:` block (the author's, beside ghost's own) names the phones' labels in
## order; everything else on the desk is built by code. The pictures the script's image marks describe - on the desk's
## screens or over the whole frame - are the note's Pictures card's ([PicturesCard]: which marks they are is this
## medium's to say, [method DispatchMedium.pictures_in]); a picture not painted leaves its screen as it was.
##
## ROWS ON THE READING'S MEDIUM CARD, as the Letter's are: built by [MediumCard] from the `dispatch` row's `card` while
## the Dispatch desk is the format, they HAND the reading what is read ([DispatchWalk]: the script with the desk's rests
## in it, every voice through a phone marked) and how it goes out ([DispatchFormat.Publish]: the document a render draws
## the desk from). What they keep (`seed`) is part of the Medium's one block.
##
## THE DESK'S NUMBER is the note's own file's unless the rows are given one ([method desk_seed]): it places the things
## that can wander, grows the roots, and draws the radar's aircraft - never what the script does.

## Its format's key in [constant Medium.REGISTRY].
const KEY := "dispatch"
## Its keys in the Medium's block: the desk's seed (0: the note's own).
const KNOBS := {"seed": 0}

signal noted(text: String)

var _knobs := KNOBS.duplicate(true)
var _panel: ReadingPanel = null
var _syncing := false
var _row_t := 0.0
var _seen := ""
var _typing := ""                # the words as last looked at, and how long they have rested
var _rested := 0.0
var _seed_box: SpinBox
var _about: Label


static func for_note(ctx: Dictionary) -> DispatchFormat:
	var card := DispatchFormat.new()
	card._panel = ctx.get("workspace") as ReadingPanel
	if card._panel != null:
		card._panel.walk = DispatchWalk.new()
		card._panel.publish = Publish.new(card)
	card._build()
	return card


## The script read again once its words have rested this long (seconds): a parse of a long note is a few tens of
## milliseconds, never to be paid a keystroke.
const SETTLE := 1.0


func _process(delta: float) -> void:
	_row_t -= delta
	if _row_t > 0.0:
		return
	_row_t = 0.25
	var body := _body()
	if body != _typing:
		_typing = body
		_rested = 0.0
		return
	_rested += 0.25
	if body != _seen and _rested >= SETTLE:
		_seen = body
		_say_about(body)


# --- the block ---------------------------------------------------------------------------------------------------------

func capture() -> Dictionary:
	return _knobs.duplicate(true)


func apply(cfg: Dictionary) -> void:
	_knobs = KNOBS.duplicate(true)
	if cfg.has("seed"):
		_knobs["seed"] = int(cfg["seed"])
	_show_knobs()


# --- what it hands the reading -----------------------------------------------------------------------------------------

## HOW IT GOES OUT: the document a render draws the desk from carries what these rows made.
class Publish extends ReadingPublish:
	var card: DispatchFormat

	func _init(c: DispatchFormat) -> void:
		card = c

	func book(d: Dictionary, _body: String) -> Dictionary:
		d["dispatch"] = card.document()
		return d


## THE DESK'S SEED: the rows', or the note's own file's (a draft with no file, the first).
func desk_seed() -> int:
	if int(_knobs["seed"]) > 0:
		return int(_knobs["seed"])
	var doc := _panel.doc_source() if _panel != null else null
	var path := doc.doc_path() if doc != null else ""
	return 1 if path.is_empty() else 1 + absi(hash(path)) % 99999


## THE DOCUMENT'S `dispatch`: the desk's seed and each picture's file - what [DispatchMedium] reads.
func document() -> Dictionary:
	var pictures := {}
	for im in DispatchMedium.pictures_in(_body()):
		var path := Illustrations.path_for(String((im as Dictionary)["key"]))
		if not path.is_empty():
			pictures[String(im["key"])] = ProjectSettings.globalize_path(path)
	return {"seed": desk_seed(), "pictures": pictures}


func _body() -> String:
	var doc := _panel.doc_source() if _panel != null else null
	if _panel != null and _panel.source_box() != null:
		return _panel.source_box().text
	return doc.pull() if doc != null else ""


# --- the rows ----------------------------------------------------------------------------------------------------------

func _build() -> void:
	add_theme_constant_override("separation", 8)
	var hint := Label.new()
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 11)
	hint.modulate = Color(1, 1, 1, 0.7)
	hint.text = ("The note's words are the script, played at the desk: the first voice cued is the room's, every other is "
		+ "heard through a phone. Edit lists the desk's marks - calls, rings, texts, pings, the terminal's typed and shown "
		+ "blocks, the printer, the static, a picture on a screen. The note's desk: block names the phones.")
	add_child(hint)
	var srow := HBoxContainer.new()
	srow.add_theme_constant_override("separation", 6)
	add_child(srow)
	var sl := Label.new()
	sl.text = "Desk"
	sl.custom_minimum_size.x = 64.0
	sl.add_theme_font_size_override("font_size", 12)
	srow.add_child(sl)
	_seed_box = SpinBox.new()
	_seed_box.min_value = 0
	_seed_box.max_value = 99999
	_seed_box.step = 1
	_seed_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_seed_box.tooltip_text = ("Which desk, by number: how the roots grow, how the phones lie in their rows, the aircraft "
		+ "on the radar - never what the script does. 0 is the note's own desk, the same every time. Takes effect at the next Play.")
	_seed_box.value_changed.connect(func(v: float) -> void:
		if not _syncing:
			_knobs["seed"] = int(v)
			_touch())
	srow.add_child(_seed_box)
	var again := Button.new()
	again.text = "New desk"
	again.tooltip_text = "Another desk, drawn at random: the roots grown anew, the phones laid again."
	again.pressed.connect(func() -> void: _seed_box.value = randi_range(1, 99999))
	srow.add_child(again)
	_about = Label.new()
	_about.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_about.add_theme_font_size_override("font_size", 11)
	add_child(_about)
	_show_knobs()


## WHAT THE SCRIPT ASKS OF THE DESK, in a line: its phones, its voices through them, and anything it gets wrong.
func _say_about(body: String) -> void:
	if _about == null:
		return
	var p := DispatchScript.parse(body)
	var phones: PackedStringArray = p["phones"]
	var n := (p["actions"] as Array).size()
	var line := "%d phones (%s); %d things the desk does." % [phones.size(), ", ".join(phones), n]
	var warn: PackedStringArray = p["warnings"]
	if not warn.is_empty():
		line += "\n⚠  " + "\n⚠  ".join(warn.slice(0, 4))
	_about.text = line
	noted.emit(line)


func _show_knobs() -> void:
	if _seed_box == null:
		return
	_syncing = true
	_seed_box.value = int(_knobs["seed"])
	_syncing = false


func _touch() -> void:
	if _panel != null:
		_panel.touch()
