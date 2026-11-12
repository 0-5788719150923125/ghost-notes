extends VBoxContainer
class_name DeskRows

## DeskRows - a desk's rows on the Medium card, the Letter's ([LetterFormat]) and the Desk's ([DeskFormat]): which desk by
## number, its light, what is on it and what is written on its index cards ([DeskLook]).
##
## What is on the desk and how it is lit are chosen here: a tick per [constant DeskLook.THINGS] row (the block's `things`) and the
## Light (`mood`, [constant DeskLook.MOODS]); the number only places them and draws how they look (paper, ink, top), never how a
## word is written. Until either is chosen they are what the number drew, and the first change of anything on the desk, the number
## included, keeps them ([method _hold]). A number of 0 is the owner's own desk ([member own_seed]).
##
## Its owner keeps what it holds in the Medium's block ([method capture], [method apply]), hands it to what draws the desk
## ([method picks]), touches the note on [signal changed] and dresses a playing desk again on [signal redress].

## Its keys in the Medium's block: the desk's number (0: the owner's own), its light ("": the number's), what is written on the
## index cards, and, once chosen, `things` ([constant DeskLook.THINGS] keys; none written: the number's).
const KNOBS := {"seed": 0, "mood": "", "card_text": ""}
## How long the index cards' words rest unchanged before a playing desk is dressed again with them (seconds).
const CARD_SETTLE := 0.6

## A row was changed by hand: the note is touched.
signal changed
## How the desk looks has changed: a playing desk is dressed again.
signal redress

## The desk's number when the rows give none (0): the note's own for a letter, the episode's up now at a table show.
var own_seed: Callable
var _knobs := KNOBS.duplicate(true)
var _syncing := false
var _seed_box: SpinBox
var _light_pick: OptionButton    # the desk's light ([constant DeskLook.MOODS])
var _bank := {}                  # a [constant DeskLook.THINGS] key -> its CheckBox
var _card_box: TextField         # what is written on the index cards, shown while they are on the desk
var _card_due := 0.0             # seconds till a playing desk takes the cards' words, 0 for nothing waiting


## Rows whose number 0 is [param own] (a Callable returning the desk's number), said on the Desk row as [param own_said].
func _init(own: Callable = Callable(), own_said := "the note's own desk, the same every time") -> void:
	own_seed = own if own.is_valid() else func() -> int: return 1
	_build(own_said)


func _process(delta: float) -> void:
	if _card_due > 0.0:
		_card_due -= delta
		if _card_due <= 0.0:
			redress.emit()


# --- the block ---------------------------------------------------------------------------------

func capture() -> Dictionary:
	return _knobs.duplicate(true)


## ...and back: each key it knows, a light or thing it does not know dropped.
func apply(cfg: Dictionary) -> void:
	_knobs = KNOBS.duplicate(true)
	for k in KNOBS:
		if cfg.has(k):
			_knobs[k] = int(cfg[k]) if k == "seed" else String(cfg[k])
	if not DeskLook.MOODS.has(String(_knobs["mood"])):
		_knobs["mood"] = ""
	if cfg.get("things") is Array:
		var kinds: Array = []
		for k in DeskLook.THINGS:
			if k in (cfg["things"] as Array):
				kinds.append(k)
		_knobs["things"] = kinds
	show_desk()


## The desk's number: the rows', or the owner's own ([member own_seed]).
func desk_seed() -> int:
	return int(_knobs["seed"]) if int(_knobs["seed"]) > 0 else maxi(1, int(own_seed.call()))


## What is on the desk ([constant DeskLook.THINGS] keys, in its order): what was ticked, or what the number drew.
func desk_things() -> Array:
	if _knobs.get("things") is Array:
		return (_knobs["things"] as Array).duplicate()
	return DeskLook.kinds(DeskLook.of(desk_seed()))


## The desk's light ([constant DeskLook.MOODS]): the one chosen, or the number's.
func desk_mood() -> String:
	var mood := String(_knobs["mood"])
	return mood if DeskLook.MOODS.has(mood) else String(DeskLook.of(desk_seed())["mood"])


## What is written on the index cards, "" for nothing.
func card_text() -> String:
	return String(_knobs["card_text"])


## What a document hands the desk: its number (`desk`), what is on it, its light and the cards' words ([method DeskLook.picks_of]).
func picks() -> Dictionary:
	return {"desk": desk_seed(), "things": desk_things(), "mood": desk_mood(), "card_text": card_text()}


## What is on the desk and its light kept as they are now, before anything on the desk changes: the number moves them, never
## chooses them.
func _hold() -> void:
	if not (_knobs.get("things") is Array):
		_knobs["things"] = desk_things()
	if String(_knobs["mood"]).is_empty():
		_knobs["mood"] = desk_mood()


# --- the rows -----------------------------------------------------------------------------------

func _build(own_said: String) -> void:
	add_theme_constant_override("separation", 8)
	var srow := HBoxContainer.new()
	srow.add_theme_constant_override("separation", 6)
	add_child(srow)
	srow.add_child(_label("Desk"))
	_seed_box = SpinBox.new()
	_seed_box.min_value = 0
	_seed_box.max_value = 99999
	_seed_box.step = 1
	_seed_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_seed_box.tooltip_text = ("Which desk, by number: its paper, ink and pen, its top, where each thing on it lies and how it "
		+ "looks, and the lamp - never what is on it or how it is lit, which are chosen below, nor how the words are written. "
		+ "0 is %s; any other number is a desk of its own. Seen at once while the show plays, paused or not." % own_said)
	_seed_box.value_changed.connect(func(v: float) -> void:
		if _syncing:
			return
		_hold()
		_knobs["seed"] = int(v)
		changed.emit()
		show_desk()
		redress.emit())
	srow.add_child(_seed_box)
	var again := Button.new()
	again.text = "New desk"
	again.tooltip_text = "Another desk, drawn at random: the same things, the same light, placed and colored anew."
	again.pressed.connect(func() -> void: _seed_box.value = randi_range(1, 99999))
	srow.add_child(again)

	# The light, chosen
	var lrow := HBoxContainer.new()
	lrow.add_theme_constant_override("separation", 6)
	add_child(lrow)
	lrow.add_child(_label("Light"))
	_light_pick = OptionButton.new()
	_light_pick.focus_mode = Control.FOCUS_NONE
	_light_pick.fit_to_longest_item = false
	_light_pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for k in DeskLook.MOODS:
		_light_pick.add_item(String(DeskLook.MOODS[k]["label"]))
		_light_pick.set_item_tooltip(_light_pick.item_count - 1, String(DeskLook.MOODS[k]["blurb"]))
	_light_pick.item_selected.connect(func(i: int) -> void:
		if _syncing:
			return
		_hold()
		_knobs["mood"] = String(DeskLook.MOODS.keys()[i])
		changed.emit()
		show_desk()
		redress.emit())
	lrow.add_child(_light_pick)

	# What is on the desk, a tick each
	var dl := Label.new()
	dl.text = "On the desk"
	dl.add_theme_font_size_override("font_size", 12)
	add_child(dl)
	var bank := HFlowContainer.new()
	bank.add_theme_constant_override("h_separation", 4)
	add_child(bank)
	for k in DeskLook.THINGS:
		var row: Dictionary = DeskLook.THINGS[k]
		var box := CheckBox.new()
		box.text = _thing_name(String(row["label"]))
		box.tooltip_text = String(row["blurb"]) + (" It burns." if bool(row.get("lit", false)) else "")
		box.focus_mode = Control.FOCUS_NONE
		box.add_theme_font_size_override("font_size", 11)
		var kind := String(k)
		box.toggled.connect(func(on: bool) -> void: _tick_thing(kind, on))
		bank.add_child(box)
		_bank[kind] = box

	# What is written on the index cards (shown while they are on the desk), the right way up from the writer's seat ([method DeskLook._write])
	_card_box = TextField.new("On the index cards", "Nothing - the cards are blank",
		"Written on the top index card or sticky note in the writer's hand and the desk's ink, line "
		+ "for line as typed here - smaller where it needs the room, wrapped to the card's width. Nothing on the desk moves "
		+ "for it: the cards lie where the desk's number put them, and the writing turns to read the nearest way up from "
		+ "the writer's seat - down a card lying along the pad. Seen at once while the show plays, paused or not.")
	_card_box.text_changed.connect(func() -> void:
		if _syncing:
			return
		_hold()
		_knobs["card_text"] = _card_box.text
		changed.emit()
		_card_due = CARD_SETTLE)
	add_child(_card_box)
	show_desk()


func _label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.custom_minimum_size.x = 64.0
	l.add_theme_font_size_override("font_size", 12)
	return l


## The rows as they stand: the number, the light and what is on the desk - chosen, or the number's (shown again when the owner's
## own number changes, as a table show's does with the episode up).
func show_desk() -> void:
	if _card_box == null:
		return
	var was := _syncing
	_syncing = true
	_seed_box.value = int(_knobs["seed"])
	_light_pick.select(maxi(0, DeskLook.MOODS.keys().find(desk_mood())))
	var on := desk_things()
	for k in _bank:
		(_bank[k] as CheckBox).set_pressed_no_signal(k in on)
	if _card_box.text != card_text():
		_card_box.text = card_text()
	_card_box.visible = "cards" in on
	_syncing = was


## A thing ticked on or off the desk.
func _tick_thing(kind: String, on: bool) -> void:
	if _syncing:
		return
	_hold()
	var had: Array = _knobs["things"]
	var kinds: Array = []
	for k in DeskLook.THINGS:
		if (k == kind and on) or (k != kind and k in had):
			kinds.append(k)
	_knobs["things"] = kinds
	changed.emit()
	show_desk()
	redress.emit()


## A thing's name on its tick: its label without its article, capitalized ("a cup of pencils": "Cup of pencils").
static func _thing_name(label: String) -> String:
	for a in ["a ", "an "]:
		if label.begins_with(a):
			label = label.substr(a.length())
	return label.substr(0, 1).to_upper() + label.substr(1)
