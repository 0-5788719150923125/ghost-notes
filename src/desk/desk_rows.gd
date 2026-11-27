extends VBoxContainer
class_name DeskRows

## DeskRows - a desk's rows on the Medium card, the Letter's ([LetterFormat]) and the Desk's ([DeskFormat]): which desk by
## number and what is written on its index cards ([DeskLook]); what is on it is ticked on the Props card ([method props],
## [DeskProps]), and how it is lit is the Environment card's ([EnvironmentCard]).
##
## What is on the desk is chosen: a tick per [constant DeskLook.THINGS] row (the block's `things`, [method set_thing]); the number
## only places them and draws how they look (paper, ink, top), never how a word is written. Until they are chosen they are what the
## number drew, and the first change of anything on the desk, the number included, keeps them ([method _hold]). A number of 0 is the
## owner's own desk ([member own_seed]).
##
## Its owner keeps what it holds in the Medium's block ([method capture], [method apply]), hands it to what draws the desk
## ([method picks]), touches the note on [signal changed] and dresses a playing desk again on [signal redress].

## Its keys in the Medium's block: the desk's number (0: the owner's own), what is written on the index cards, and, once chosen, `things` ([constant DeskLook.THINGS] keys; none written: the number's) and `makes` (a thing
## played by a prop kept in the library, `{kind: {kept: name}}` - a desk thing refined, [method set_make]).
const KNOBS := {"seed": 0, "card_text": ""}
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
var _props: DeskProps = null     # what is on it, as the Props card shows it ([method props])
var _card_box: TextField         # what is written on the index cards, shown while they are on the desk
var _card_due := 0.0             # seconds till a playing desk takes the cards' words, 0 for nothing waiting


## Rows whose number 0 is [param own] (a Callable returning the desk's number), said on the Seed row as [param own_said].
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
	if cfg.get("things") is Array:
		var kinds: Array = []
		for k in DeskLook.THINGS:
			if k in (cfg["things"] as Array):
				kinds.append(k)
		_knobs["things"] = kinds
	var makes := DeskLook.makes_of(cfg)
	if not makes.is_empty():
		_knobs["makes"] = makes
	show_desk()


## The desk's number: the rows', or the owner's own ([member own_seed]).
func desk_seed() -> int:
	return int(_knobs["seed"]) if int(_knobs["seed"]) > 0 else maxi(1, int(own_seed.call()))


## What is on the desk ([constant DeskLook.THINGS] keys, in its order): what was ticked, or what the number drew.
func desk_things() -> Array:
	if _knobs.get("things") is Array:
		return (_knobs["things"] as Array).duplicate()
	return DeskLook.kinds(DeskLook.of(desk_seed()))


## What is written on the index cards, "" for nothing.
func card_text() -> String:
	return String(_knobs["card_text"])


## The props kept in the library that play the desk's things, `{kind: {kept: name, v}}` ([method set_make], [method PropMakes.chosen]).
func desk_makes() -> Dictionary:
	return (_knobs.get("makes", {}) as Dictionary).duplicate(true)


## What a document hands the desk: its number (`desk`), what is on it and what plays it, and the cards' words ([method
## DeskLook.picks_of]).
func picks() -> Dictionary:
	return {"desk": desk_seed(), "things": desk_things(), "card_text": card_text(), "makes": desk_makes()}


## What is on the desk kept as it is now, before anything on the desk changes: the number moves it, never chooses it.
func _hold() -> void:
	if not (_knobs.get("things") is Array):
		_knobs["things"] = desk_things()


# --- the rows -----------------------------------------------------------------------------------

func _build(own_said: String) -> void:
	add_theme_constant_override("separation", 8)
	var srow := HBoxContainer.new()
	srow.add_theme_constant_override("separation", 6)
	add_child(srow)
	srow.add_child(_label("Seed"))
	_seed_box = SpinBox.new()
	_seed_box.min_value = 0
	_seed_box.max_value = 99999
	_seed_box.step = 1
	_seed_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_seed_box.tooltip_text = ("Which desk, by number: its paper, ink and pen, its top, where each thing on it lies and how it "
		+ "looks, and the lamp - never what is on it (the Props card's) or how it is lit (the Environment card's), nor how the words are written. "
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
	again.text = "Roll"
	again.tooltip_text = "Another desk, drawn at random: the same things, placed and colored anew."
	again.pressed.connect(func() -> void: _seed_box.value = randi_range(1, 99999))
	srow.add_child(again)

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


## The rows as they stand: the number and what is on the desk - chosen, or the number's (shown again when the owner's
## own number changes, as a table show's does with the episode up).
func show_desk() -> void:
	if _card_box == null:
		return
	var was := _syncing
	_syncing = true
	_seed_box.value = int(_knobs["seed"])
	var on := desk_things()
	if _card_box.text != card_text():
		_card_box.text = card_text()
	_card_box.visible = "cards" in on
	_syncing = was


## What is on the desk as the Props card shows it: the section its owner hands the panel ([member ReadingPanel.prop_sections]).
func props() -> DeskProps:
	if _props == null:
		_props = DeskProps.new(self)
	return _props


## Thing [param kind] ([constant DeskLook.THINGS]) put on the desk or taken off it.
func set_thing(kind: String, on: bool) -> void:
	if not DeskLook.THINGS.has(kind):
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


## Thing [param kind] ([constant DeskLook.THINGS]) played by [param choice]: `{kept: name}`, a prop kept in the library (a version of
## the desk's own, refined), or {} the desk's own drawn by its number.
func set_make(kind: String, choice: Dictionary) -> void:
	if not DeskLook.THINGS.has(kind):
		return
	var makes := desk_makes()
	if choice.get("kept") is String and not String(choice["kept"]).strip_edges().is_empty():
		makes[kind] = PropMakes.chosen({"kept": String(choice["kept"])})
	else:
		makes.erase(kind)
	if makes.is_empty():
		_knobs.erase("makes")
	else:
		_knobs["makes"] = makes
	changed.emit()
	show_desk()
	redress.emit()


## A thing's name on the Props card: its label without its article, capitalized ("a cup of pencils": "Cup of pencils").
static func thing_name(label: String) -> String:
	for a in ["a ", "an "]:
		if label.begins_with(a):
			label = label.substr(a.length())
	return label.substr(0, 1).to_upper() + label.substr(1)
