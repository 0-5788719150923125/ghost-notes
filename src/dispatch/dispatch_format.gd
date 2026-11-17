extends VBoxContainer
class_name DispatchFormat

## DispatchFormat - the Dispatch desk's rows on the Medium card: the note played at a desk late at night, seen from the
## chair - a typing terminal, labeled phones that ring, a radar, a receiver, a printer, small screens, roots across the
## desk ([DispatchMedium], next/dispatch.md). A format of [MediumCard], not a component.
##
## The note is the script, word for word. Its `desk:` block names the phones' labels in order; everything else is built
## by code. The pictures the script's image marks describe are the note's Pictures card's ([PicturesCard]; which marks
## they are is [method DispatchMedium.pictures_in]'s to say); an unpainted picture leaves its screen as it was.
##
## [MediumCard] builds the rows from the `dispatch` row's `card` while this is the format. They hand the reading what is
## read ([DispatchWalk]) and how it goes out ([DispatchFormat.Publish]: the document a render draws the desk from).
## `seed` is kept in the Medium's one block.
##
## The desk's number is the note's own file's unless the Seed row gives one ([method desk_seed]): it places the things that
## can wander, grows the roots and draws the radar's aircraft - never what the script does. Changed while the note plays, it
## is handed to the reading's live document and the desk is drawn again at once ([method _redress_live]).
##
## What is on the desk is on the Props card ([DispatchProps]): the parts any make can play (the mug, the cup of pencils) are
## chosen there, kept in the block's `things` (`{role: choice}`, [PropMakes]) and handed to the desk as the seed is.

## Its format's key in [constant Medium.REGISTRY].
const KEY := "dispatch"
## Its keys in the Medium's block: the desk's seed (0: the note's own), and the makes chosen for its parts (`{role: choice}`,
## none for the desk's own).
const KNOBS := {"seed": 0, "things": {}}

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
var _wants := {}                 # what the script last read asks the desk to build only for it ([method wants])


static func for_note(ctx: Dictionary) -> DispatchFormat:
	var card := DispatchFormat.new()
	card._panel = ctx.get("workspace") as ReadingPanel
	if card._panel != null:
		card._panel.walk = DispatchWalk.new()
		card._panel.publish = Publish.new(card)
		# what is on the desk, on the Props card ([DispatchProps])
		card._panel.prop_sections.append(DispatchProps.new(card))
	card._build()
	return card


## The script is read again once its words have rested this long (seconds); a long note parses in tens of milliseconds.
const SETTLE := 1.0


func _process(delta: float) -> void:
	_row_t -= delta
	if _row_t > 0.0:
		return
	_row_t = 0.25
	var body := _note()
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
	if cfg.get("things") is Dictionary:
		for role in (cfg["things"] as Dictionary):
			var c: Variant = (cfg["things"] as Dictionary)[role]
			if DispatchSet.MAKE_SALTS.has(String(role)) and PropMakes.valid_for(String(role), c) and not (c as Dictionary).is_empty():
				_knobs["things"][String(role)] = (c as Dictionary).duplicate(true)
	_show_knobs()


# --- what it hands the reading -----------------------------------------------------------------------------------------

## How it goes out: the document a render draws the desk from carries what these rows made.
class Publish extends ReadingPublish:
	var card: DispatchFormat

	func _init(c: DispatchFormat) -> void:
		card = c

	func book(d: Dictionary, _body: String) -> Dictionary:
		d["dispatch"] = card.document()
		return d


## The rows' seed, or the note's own file's (a draft with no file: the first).
func desk_seed() -> int:
	if int(_knobs["seed"]) > 0:
		return int(_knobs["seed"])
	var doc := _panel.doc_source() if _panel != null else null
	var path := doc.doc_path() if doc != null else ""
	return 1 if path.is_empty() else 1 + absi(hash(path)) % 99999


## The document's `dispatch`: the desk's seed, each picture's file, each clip's frames ([method Illustrations.clip_of]) and
## the note's frontmatter (`head`, its `desk:` and `terminal:` blocks; the words a synced note is read with have none) -
## what [DispatchMedium] reads.
func document() -> Dictionary:
	var pictures := {}
	var clips := {}
	for im in DispatchMedium.pictures_in(_body()):
		var key := String((im as Dictionary)["key"])
		if (im as Dictionary).has("clip"):
			var clip := Illustrations.clip_of(key)
			if not clip.is_empty():
				clips[key] = clip
			continue
		var path := Illustrations.path_for(key)
		if not path.is_empty():
			pictures[key] = ProjectSettings.globalize_path(path)
	return {"seed": desk_seed(), "things": things().duplicate(true), "pictures": pictures, "clips": clips, "head": _head()}


## The makes chosen for the desk's parts: `{role: choice}` ([PropMakes]), a part not in it the desk's own.
func things() -> Dictionary:
	return _knobs["things"]


## Role [param role] played by [param choice] from here ({} the desk's own): kept in the block and drawn at once while the note
## plays. "" done, else why not.
func choose(role: String, choice: Dictionary) -> String:
	if not DispatchSet.MAKE_SALTS.has(role):
		return "the desk has no such part to choose"
	if not PropMakes.valid_for(role, choice):
		return "that is not something the part can be played by"
	if choice.is_empty():
		(_knobs["things"] as Dictionary).erase(role)
	else:
		_knobs["things"][role] = choice.duplicate(true)
	_touch()
	_redress_live()
	return ""


## The note as written, its frontmatter on it ([method _note]).
func note() -> String:
	return _note()


## What the script asks the desk to build only for it, as last read: `clock`, `tablet` ([method DispatchMedium.wants_of]).
func wants() -> Dictionary:
	return _wants


func _body() -> String:
	var doc := _panel.doc_source() if _panel != null else null
	if _panel != null and _panel.source_box() != null:
		return _panel.source_box().text
	return doc.pull() if doc != null else ""


## The note's frontmatter as written ("" for none): where the desk's `desk:` and `terminal:` blocks are - a synced note's
## words, as the box and the voice have them, come without it.
func _head() -> String:
	var doc := _panel.doc_source() if _panel != null else null
	return doc.head() if doc != null else ""


## The note as written: its words, with its frontmatter on them where they come without it.
func _note() -> String:
	return DispatchMedium.whole(_body(), _head())


# --- the rows ----------------------------------------------------------------------------------------------------------

func _build() -> void:
	add_theme_constant_override("separation", 8)
	var srow := HBoxContainer.new()
	srow.add_theme_constant_override("separation", 6)
	add_child(srow)
	var sl := Label.new()
	sl.text = "Seed"
	sl.custom_minimum_size.x = 64.0
	sl.add_theme_font_size_override("font_size", 12)
	srow.add_child(sl)
	_seed_box = SpinBox.new()
	_seed_box.min_value = 0
	_seed_box.max_value = 99999
	_seed_box.step = 1
	_seed_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_seed_box.tooltip_text = ("Which desk, by number: how the roots grow, how the phones lie in their rows, the aircraft "
		+ "on the radar - never what the script does. 0 is the note's own desk, the same every time. Seen at once while the "
		+ "show plays, paused or not.")
	_seed_box.value_changed.connect(func(v: float) -> void:
		if not _syncing:
			_knobs["seed"] = int(v)
			_touch()
			_redress_live())
	srow.add_child(_seed_box)
	var again := Button.new()
	again.text = "Roll"
	again.tooltip_text = "Another desk, drawn at random: the roots grown anew, the phones laid again."
	again.pressed.connect(func() -> void: _seed_box.value = randi_range(1, 99999))
	srow.add_child(again)
	_about = Label.new()
	_about.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_about.add_theme_font_size_override("font_size", 11)
	add_child(_about)
	_show_knobs()


## What the script asks of the desk: its phones, its voices through them, and anything it gets wrong.
func _say_about(body: String) -> void:
	if _about == null:
		return
	var p := DispatchScript.parse(body)
	_wants = DispatchMedium.wants_of(p, body)
	var phones: PackedStringArray = p["phones"]
	var n := (p["actions"] as Array).size()
	var line := "%d phones (%s); %d things the desk does." % [phones.size(), ", ".join(phones), n]
	var warn: PackedStringArray = p["warnings"]
	StatusLog.say("dispatch desk", "\n".join(warn))
	if not warn.is_empty():
		line += "\n⚠  " + "\n⚠  ".join(warn.slice(0, 4))
		if warn.size() > 4:
			line += "\n⚠  ...and %d more (the log has them all)" % (warn.size() - 4)
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


## The desk drawn again while the note plays: the seed and the parts' makes as they stand, in the reading's live document
## ([DispatchMedium] draws the desk again when either changes).
func _redress_live() -> void:
	var subs: Node = _panel.subtitles if _panel != null and is_instance_valid(_panel) else null
	if subs == null or not is_instance_valid(subs):
		return
	var doc: Dictionary = subs.get("document")
	if doc.get("dispatch") is Dictionary:
		(doc["dispatch"] as Dictionary)["seed"] = desk_seed()
		(doc["dispatch"] as Dictionary)["things"] = things().duplicate(true)
