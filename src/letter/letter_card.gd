extends VBoxContainer
class_name LetterCard

## LetterCard - the Letter component's card: the note read as a letter, written by hand at a desk while
## the voice reads it (next/letter.md, [LetterMedium]).
##
## THE NOTE IS THE LETTER, word for word: nothing writes it but its author. What this card makes is what
## the words only describe - each SKETCH, drawn as SVG by an agent and laid out by ghost's own TeX
## ([LetterSketches]), so the pen draws it. Each PICTURE a passage is read over is the note's Pictures card's
## ([PicturesCard]: the letter's pictures and never its sketches, [method LetterMedium.pictures_in]). A letter plays
## without either: a sketch not drawn yet is not drawn, the words round it as they are, a picture not painted leaves
## its passage over the desk.
##
## A CARD ON THE READING, as the Actor's and Proof's are: built by [NoteCards] from the `letter` row, it
## PINS ITS MEDIUM while it is up ([member Director.medium_override]) and HANDS the reading what is read
## ([LetterWalk]: the letter as the voice says it, the pen's rests in it, no title announced) and how it
## goes out ([LetterCard.Publish]: the document a render draws the letter from).
##
## THE DESK AND THE HAND ARE THE NOTE'S: the desk's seed is the note's own file's unless the card is given
## one ([method desk_seed]); how each word wavers - and so where the lines break and the rests the voice takes - is
## always the note's own ([method hand_seed]), so the same letter is written the same way every time, whatever desk it
## is written at; the hand is one of the journal's ([LetterHand], the Notebook's), Kalam unless the card names another.
##
## WHAT IS ON THE DESK AND HOW IT IS LIT ARE CHOSEN HERE (2026-10-29, the user: "It's really hard to find a good seed,
## because generating the scenes is kind of slow (startup is like 20 seconds) ... provide a multi-select bank of the
## standard objects we already implement ... Then, when we change the seed - the only thing being changed would be the
## placement of objects, and textures"): a tick a [constant DeskLook.THINGS] row (the block's `things`) and the Light
## (`mood`, [constant DeskLook.MOODS]); the number only places them and draws how they look - the paper, the ink, the
## top - and never how a word is written ([method hand_seed]). Until either is chosen they are what the number drew,
## and the first change of anything on the desk - the number among them - keeps them ([method _hold_desk]). Changed
## while the letter plays (paused or not), the desk is dressed again at once ([method _redress_live]): the number is no
## longer a new take and a Play to see; the hand still waits for the next Play, for it changes how every word is
## written.
##
## GENERATION IS EXPLICIT, AND ON THE NOTE'S PIPELINE CARD ([Section]; next/pipeline.md): Generate draws the sketches not
## drawn, then lays them out; a sketch's ⟳ draws it again. Nothing runs on open.

const KEY := "letter"
## The block: the desk's seed (0: the note's own), its light ("": the seed's), the hand it is written in, who draws
## the sketches and what is written on the index cards (`card_text`, [method DeskLook.picks_of]) - and, once chosen,
## `things` (what is on the desk, [constant DeskLook.THINGS] keys; none written: the seed's).
const KNOBS := {"seed": 0, "mood": "", "hand": LetterHand.DEFAULT, "writer": "claude", "writer_model": "", "writer_effort": "",
	"card_text": ""}
## How long the index cards' words rest unchanged before a playing letter's desk is dressed again with them (seconds):
## a desk is not built again a keystroke.
const CARD_SETTLE := 0.6

signal noted(text: String)

var _knobs := KNOBS.duplicate(true)
var _panel: ReadingPanel = null
var _sketches: LetterSketches = null
var _syncing := false
var _row_t := 0.0
var _seen := ""                  # the letter's text the rows were built for
var _listed: Array = []          # ...and its sketches ([method LetterScript.sketches])
var _asked := false              # Generate or a ⟳ asked: the ink is laid out once the drawings are in
var _ink_tried := ""             # the drawings the ink step last failed on, not tried again unasked
var _installing := ""            # what the ink step waits to be installed, "" for nothing
## WHAT IT HANDS THE NOTE'S PIPELINE CARD ([method pipeline]).
var _section: Section = null

var _seed_box: SpinBox
var _light_pick: OptionButton    # the desk's light ([constant DeskLook.MOODS])
var _bank := {}                  # a [constant DeskLook.THINGS] key -> its CheckBox
var _card_box: TextField         # what is written on the index cards, shown while they are on the desk
var _card_due := 0.0             # seconds till a playing letter's desk takes the cards' words, 0 for nothing waiting
var _hand_pick: OptionButton
var _writer: AgentPick


static func for_note(ctx: Dictionary) -> LetterCard:
	var card := LetterCard.new()
	card._panel = ctx.get("workspace") as ReadingPanel
	if card._panel != null:
		card._panel.walk = LetterWalk.new(card)
		card._panel.publish = Publish.new(card)
		var doc := card._panel.doc_source()
		card._sketches = LetterSketches.new(doc.doc_path() if doc != null else "")
		# a note saved elsewhere has its sketches carried there ([method LetterSketches.carry]): read them there
		if doc != null:
			doc.moved.connect(func(_from: String, to: String) -> void: card._sketches.dir = LetterSketches.folder_of(to))
	else:
		card._sketches = LetterSketches.new()
	card._build()
	return card


## THE LETTER IS THE MEDIUM, pinned while the card is up.
func _enter_tree() -> void:
	if _panel != null:
		Director.pin_medium("letter", self)


func _exit_tree() -> void:
	if _sketches != null:
		_sketches.stop()
	if _panel != null:
		Director.unpin_medium(self)


func _process(delta: float) -> void:
	if _card_due > 0.0:
		_card_due -= delta
		if _card_due <= 0.0:
			_redress_live()
	_row_t -= delta
	if _row_t > 0.0:
		return
	_row_t = 0.25
	_sketches.tick()
	var body := _body()
	if body != _seen:
		_seen = body
		_listed = LetterScript.sketches(_seen)
	_lay_out_when_drawn()


# --- the block ---------------------------------------------------------------------------------

func capture() -> Dictionary:
	return _knobs.duplicate(true)


func apply(cfg: Dictionary) -> void:
	_knobs = KNOBS.duplicate(true)
	for k in KNOBS:
		if cfg.has(k):
			_knobs[k] = int(cfg[k]) if k == "seed" else String(cfg[k])
	if not TextGen.has(String(_knobs["writer"])):
		_knobs["writer"] = "claude"
	_knobs["hand"] = LetterHand.of(String(_knobs["hand"]))
	if not DeskLook.MOODS.has(String(_knobs["mood"])):
		_knobs["mood"] = ""
	if cfg.get("things") is Array:
		var kinds: Array = []
		for k in DeskLook.THINGS:
			if k in (cfg["things"] as Array):
				kinds.append(k)
		_knobs["things"] = kinds
	_show_knobs()


# --- what it hands the reading -------------------------------------------------------------------

## HOW IT GOES OUT: the document a render draws the letter from carries what this card made.
class Publish extends ReadingPublish:
	var card: LetterCard

	func _init(c: LetterCard) -> void:
		card = c

	func book(d: Dictionary, _body: String) -> Dictionary:
		d["letter"] = card.document()
		return d


## THE DESK'S SEED: the card's, or the note's own ([method hand_seed]).
func desk_seed() -> int:
	return int(_knobs["seed"]) if int(_knobs["seed"]) > 0 else hand_seed()


## THE HAND'S SEED, how each word wavers and where the lines break: the note's own file's (a draft with no file, the
## first), whatever the desk's number.
func hand_seed() -> int:
	var doc := _panel.doc_source() if _panel != null else null
	var path := doc.doc_path() if doc != null else ""
	return 1 if path.is_empty() else 1 + absi(hash(path)) % 99999


## THE DOCUMENT'S `letter`: the hand's seed (`seed`) and the desk's (`desk`), the hand, each sketch's drawing that is
## laid out, the ink, each picture's file, and what is on the desk, its light and what is written on its index cards -
## what [LetterMedium] and [LetterWalk] read, so the voice's rests and the pen are sized alike.
func document() -> Dictionary:
	var body := _body()
	var ink := _sketches.ink()
	var records := LetterScript.records_of(ink)
	var svgs := {}
	var all := _sketches.svgs(LetterScript.sketches(body))
	for key in all:
		if records.has(String(DeskScript.item("draw", String(all[key]))["id"])):
			svgs[key] = all[key]
	var pictures := {}
	for im in LetterMedium.pictures_in(body):
		var path := Illustrations.path_for(String((im as Dictionary)["key"]))
		if not path.is_empty():
			pictures[String(im["key"])] = ProjectSettings.globalize_path(path)
	return {"seed": hand_seed(), "desk": desk_seed(), "hand": LetterHand.of(String(_knobs["hand"])), "svgs": svgs,
		"ink": ink, "pictures": pictures, "things": desk_things(), "mood": desk_mood(), "card_text": String(_knobs["card_text"])}


## WHAT IS ON THE DESK ([constant DeskLook.THINGS] keys, in its order): what was ticked, or what the number drew.
func desk_things() -> Array:
	if _knobs.get("things") is Array:
		return (_knobs["things"] as Array).duplicate()
	return DeskLook.kinds(DeskLook.of(desk_seed()))


## THE DESK'S LIGHT ([constant DeskLook.MOODS]): the one chosen, or the number's.
func desk_mood() -> String:
	var mood := String(_knobs["mood"])
	return mood if DeskLook.MOODS.has(mood) else String(DeskLook.of(desk_seed())["mood"])


## WHAT IS ON THE DESK AND ITS LIGHT KEPT as they are now, before anything on the desk changes: the number moves them,
## it never chooses them.
func _hold_desk() -> void:
	if not (_knobs.get("things") is Array):
		_knobs["things"] = desk_things()
	if String(_knobs["mood"]).is_empty():
		_knobs["mood"] = desk_mood()


## THE DESK DRESSED AGAIN WHILE THE LETTER PLAYS: its number, what is on it, its light and the cards' words, handed to the reading's
## live document ([LetterMedium] dresses the desk again when they change, the letter as it is).
func _redress_live() -> void:
	var subs: Node = _panel.subtitles if _panel != null and is_instance_valid(_panel) else null
	if subs == null or not is_instance_valid(subs):
		return
	var doc: Dictionary = subs.get("document")
	if doc.get("letter") is Dictionary:
		(doc["letter"] as Dictionary)["desk"] = desk_seed()
		(doc["letter"] as Dictionary)["things"] = desk_things()
		(doc["letter"] as Dictionary)["mood"] = desk_mood()
		(doc["letter"] as Dictionary)["card_text"] = String(_knobs["card_text"])


func _body() -> String:
	var doc := _panel.doc_source() if _panel != null else null
	if _panel != null and _panel.source_box() != null:
		return _panel.source_box().text
	return doc.pull() if doc != null else ""


# --- the sketches --------------------------------------------------------------------------------

func _generate() -> void:
	var sketches := LetterScript.sketches(_body())
	_sketches.writer = _writer.choice()
	# A DRAWING THE INK STEP REFUSED is drawn again, told why
	var refused := _sketches.refused()
	var all := _sketches.svgs(sketches)
	for s in sketches:
		var svg := String(all.get(String((s as Dictionary)["key"]), ""))
		var why := String(refused.get(String(DeskScript.item("draw", svg)["id"]), "")) if not svg.is_empty() else ""
		if not why.is_empty():
			_sketches.redo(s, why)
	_sketches.generate(sketches)
	_asked = true
	_ink_tried = ""
	_say("Drawing the sketches…" if _sketches.busy() else "Every sketch is drawn.")


func _redo(sketch: Dictionary) -> void:
	_sketches.writer = _writer.choice()
	_sketches.redo(sketch)
	_asked = true
	_ink_tried = ""


func _stop() -> void:
	_sketches.stop()
	_asked = false
	_say("Stopped - what was drawn is kept.")


# --- on the Pipeline card ------------------------------------------------------------------------

## WHAT THIS CARD MAKES, on the note's one list ([PipelineCard]): a row a sketch, and their ink.
class Section extends PipelineSection:
	var card: LetterCard

	func _init(c: LetterCard) -> void:
		card = c
		owner = c
		title = String(Registry.field(Components.REGISTRY, LetterCard.KEY, "label", "Letter"))

	func shown() -> bool:
		return not card._listed.is_empty()

	func rows() -> Array:
		return card._step_rows()

	func make() -> void:
		card._generate()

	func make_tip() -> String:
		return "Draw every sketch not drawn yet (or drawn from words since changed), then lay them out with TeX. Spends the drawer's quota."

	func stop() -> void:
		card._stop()

	func busy() -> bool:
		return card._sketches.busy()

	func missing() -> bool:
		return card._to_draw()


## What it hands the note's Pipeline card.
func pipeline() -> PipelineSection:
	return _section


## Whether Generate has a sketch to draw or a drawing to lay out.
func _to_draw() -> bool:
	for s in _listed:
		if _sketches.state(s) != "ready":
			return true
	var items := LetterScript.items(_seen, _sketches.svgs(_listed))
	return _sketches.ink_state(items) != "ready"


## ONCE THE DRAWINGS ARE IN, THE INK: laid out by TeX when they are not the ones it was laid out from -
## after Generate or a ⟳, never on open, and not again on drawings it just failed on.
func _lay_out_when_drawn() -> void:
	if not _asked or _sketches.busy():
		return
	var items := LetterScript.items(_body(), _sketches.svgs(LetterScript.sketches(_body())))
	var st := _sketches.ink_state(items)
	var from := LetterSketches.ink_from(items)
	if st == "ready":
		_asked = false
		_say("The sketches are drawn and laid out: the pen draws them on the next reading.")
		return
	if from == _ink_tried:
		_asked = false
		return
	# what it runs on is fetched the first time, and the drawings laid out once it is in
	_installing = LetterSketches.lacks()
	if not _installing.is_empty():
		return
	_ink_tried = from
	var err := _sketches.start_ink(items)
	if not err.is_empty():
		_say("⚠  " + err)


func _say(text: String) -> void:
	if _section != null:
		_section.tell(text)
	if _panel != null:
		_panel.status(text)
	noted.emit(text)


# --- the card -----------------------------------------------------------------------------------

func _build() -> void:
	add_theme_constant_override("separation", 8)
	var hint := Label.new()
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 11)
	hint.modulate = Color(1, 1, 1, 0.7)
	hint.text = ("The note's words are the letter: the pen writes each paragraph as the voice reads it. A "
		+ "paragraph in italics is a thought - said, not written. Edit lists the letter's marks: strike, "
		+ "sketch, tap, point, a picture over a passage, a new page.")
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
	_seed_box.tooltip_text = ("Which desk the letter is written at, by number: its paper, ink and pen, its top, where "
		+ "each thing on it lies and how it looks, and the lamp - never what is on it or how it is lit, which are "
		+ "chosen below, nor how the words are written, which is the note's own. 0 is the note's own desk, the same "
		+ "every time; any other number is a desk of its own. Seen at once while the letter plays, paused or not.")
	_seed_box.value_changed.connect(func(v: float) -> void:
		if not _syncing:
			_hold_desk()
			_knobs["seed"] = int(v)
			_touch()
			_redress_live()
		_show_desk())
	srow.add_child(_seed_box)
	var again := Button.new()
	again.text = "New desk"
	again.tooltip_text = "Another desk, drawn at random: the same things, the same light, placed and colored anew."
	again.pressed.connect(func() -> void: _seed_box.value = randi_range(1, 99999))
	srow.add_child(again)

	# THE LIGHT, chosen (2026-10-27, the user, of the mood shown beside the number: "It's not clear to me what the
	# 'Desk' value ... is doing. Is that just a random seed?")
	var lrow := HBoxContainer.new()
	lrow.add_theme_constant_override("separation", 6)
	add_child(lrow)
	var ll := Label.new()
	ll.text = "Light"
	ll.custom_minimum_size.x = 64.0
	ll.add_theme_font_size_override("font_size", 12)
	lrow.add_child(ll)
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
		_hold_desk()
		_knobs["mood"] = String(DeskLook.MOODS.keys()[i])
		_touch()
		_show_desk()
		_redress_live())
	lrow.add_child(_light_pick)

	# WHAT IS ON THE DESK, a tick each
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

	# WHAT IS WRITTEN ON THE INDEX CARDS (2026-10-29, the user: "an input box - which only appears if we've selected the
	# index cards"), the right way up from the writer's seat ([method DeskLook._write])
	_card_box = TextField.new("On the index cards", "Nothing - the cards are blank",
		"Written on the top index card or sticky note in the letter's hand and the desk's ink, line "
		+ "for line as typed here - smaller where it needs the room, wrapped to the card's width. Nothing on the desk moves "
		+ "for it: the cards lie where the desk's number put them, and the writing turns to read the nearest way up from "
		+ "the writer's seat - down a card lying along the pad. Seen at once while the letter plays, paused or not.")
	_card_box.text_changed.connect(func() -> void:
		if _syncing:
			return
		_hold_desk()
		_knobs["card_text"] = _card_box.text
		_touch()
		_card_due = CARD_SETTLE)
	add_child(_card_box)

	# THE HAND: the journal's (the Picture card's Handwriting row has the same three)
	var hrow := HBoxContainer.new()
	hrow.add_theme_constant_override("separation", 6)
	add_child(hrow)
	var hl := Label.new()
	hl.text = "Hand"
	hl.custom_minimum_size.x = 64.0
	hl.add_theme_font_size_override("font_size", 12)
	hrow.add_child(hl)
	_hand_pick = OptionButton.new()
	_hand_pick.focus_mode = Control.FOCUS_NONE
	_hand_pick.fit_to_longest_item = false
	_hand_pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hand_pick.tooltip_text = ("The handwriting the letter is written in - the Notebook's hands, each written "
		+ "stroke by stroke by the pen. Where the lines and pages break follows it, so the voice's rests do too.")
	for k in _hand_keys():
		_hand_pick.add_item(String(LetterHand.HANDS[k]["label"]))
	_hand_pick.item_selected.connect(func(i: int) -> void:
		if _syncing:
			return
		_knobs["hand"] = String(_hand_keys()[i])
		_touch())
	hrow.add_child(_hand_pick)

	_writer = AgentPick.writer(("Who draws the letter's sketches: each one's words, turned into a drawing the "
		+ "pen makes. Takes effect at the next Generate or ⟳."),
		"The model that draws. Default is the CLI's own choice per job.",
		"How hard the drawer thinks before it draws - the CLI's own reasoning effort.")
	_writer.changed.connect(func() -> void:
		if _syncing:
			return
		var c := _writer.choice()
		_knobs["writer"] = String(c["agent"])
		_knobs["writer_model"] = String(c["model"])
		_knobs["writer_effort"] = String(c["effort"])
		_touch())
	add_child(_writer)

	_section = Section.new(self)
	var brow := HBoxContainer.new()
	brow.add_theme_constant_override("separation", 6)
	add_child(brow)
	var folder := Button.new()
	folder.text = "Folder"
	folder.tooltip_text = "Open the letter's folder: each sketch's drawing, the ink and the logs."
	folder.pressed.connect(func() -> void:
		DirAccess.make_dir_recursive_absolute(_sketches.dir)
		OS.shell_open(_sketches.dir))
	brow.add_child(folder)
	_show_knobs()


func _show_knobs() -> void:
	if _writer == null:
		return
	_syncing = true
	_writer.set_choice(String(_knobs["writer"]), String(_knobs["writer_model"]), String(_knobs["writer_effort"]))
	_seed_box.value = int(_knobs["seed"])
	_show_desk()
	_hand_pick.select(maxi(0, _hand_keys().find(LetterHand.of(String(_knobs["hand"])))))
	if _card_box.text != String(_knobs["card_text"]):
		_card_box.text = String(_knobs["card_text"])
	_syncing = false


## The desk's light and what is on it, as they stand: chosen, or the number's.
func _show_desk() -> void:
	if _light_pick == null:
		return
	var was := _syncing
	_syncing = true
	_light_pick.select(maxi(0, DeskLook.MOODS.keys().find(desk_mood())))
	var on := desk_things()
	for k in _bank:
		(_bank[k] as CheckBox).set_pressed_no_signal(k in on)
	_card_box.visible = "cards" in on
	_syncing = was


## A thing ticked on or off the desk.
func _tick_thing(kind: String, on: bool) -> void:
	if _syncing:
		return
	_hold_desk()
	var had: Array = _knobs["things"]
	var kinds: Array = []
	for k in DeskLook.THINGS:
		if (k == kind and on) or (k != kind and k in had):
			kinds.append(k)
	_knobs["things"] = kinds
	_touch()
	_show_desk()
	_redress_live()


## A thing's name on its tick: its label without its article, capitalized ("a cup of pencils": "Cup of pencils").
static func _thing_name(label: String) -> String:
	for a in ["a ", "an "]:
		if label.begins_with(a):
			label = label.substr(a.length())
	return label.substr(0, 1).to_upper() + label.substr(1)


## The hands, in the order the Picture card lists them.
static func _hand_keys() -> Array:
	var keys: Array = LetterHand.HANDS.keys()
	keys.sort()
	return keys


func _touch() -> void:
	if _panel != null:
		_panel.touch()


## A ROW A SKETCH, its words its name, and the ink they are laid out in, which is the tools' and has no ⟳: it follows the
## drawings ([method _lay_out_when_drawn]).
func _step_rows() -> Array:
	var out: Array = []
	if _listed.is_empty():
		return out
	var refused := _sketches.refused()
	var all := _sketches.svgs(_listed)
	for s in _listed:
		var sketch: Dictionary = s
		var key := String(sketch["key"])
		var r := PipelineRow.new(key, String(sketch["prompt"]), "")
		r.tip = String(sketch["prompt"])
		var st := _sketches.state(sketch)
		match st:
			"ready", "stale":
				var why := String(refused.get(String(DeskScript.item("draw", String(all.get(key, "")))["id"]), ""))
				if not why.is_empty():
					r.state = "failed"
					r.said = "TeX could not lay it out: " + why
				elif st == "ready":
					r.state = "made"
					r.said = "drawn"
				else:
					r.state = "stale"
					r.said = "drawn from words since changed - ⟳ draws it again"
			"running":
				r.state = "running"
				r.said = _sketches.said(sketch)
				r.wraps = true
			"queued":
				r.state = "queued"
				r.said = "waiting its turn"
			"failed":
				r.state = "failed"
				r.said = _sketches.said(sketch)
			_:
				r.state = "missing"
		r.again = "Draw this sketch again (then lay it out)"
		r.open = not st in ["running", "queued"]
		r.redo = _redo.bind(sketch)
		out.append(r)
	out.append(_ink_row(all))
	return out


func _ink_row(all: Dictionary) -> PipelineRow:
	var items := LetterScript.items(_seen, all)
	var ink := _sketches.ink_state(items)
	var r := PipelineRow.new("ink", "Ink")
	match ink:
		"ready":
			r.state = "made" if not items.is_empty() else "missing"
			r.said = "laid out" if not items.is_empty() else "nothing to lay out yet"
		"running":
			r.state = "running"
			r.said = "TeX is laying the drawings out"
		"failed":
			r.state = "failed"
			r.said = _sketches.ink_error()
		"stale":
			r.state = "stale"
			r.said = "laid out for other drawings - Generate lays them out again"
		_:
			r.state = "missing"
			r.said = "laid out once the sketches are drawn"
	if ink in ["missing", "stale"] and not _installing.is_empty():
		r.state = "running"
		r.said = _installing + " (the first time: a few hundred MB), then the drawings are laid out"
		r.wraps = true
	return r
