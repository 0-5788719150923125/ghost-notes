extends VBoxContainer
class_name LetterCard

## LetterCard - the Letter component's card: the note read as a letter, written by hand at a desk while
## the voice reads it (next/letter.md, [LetterMedium]).
##
## THE NOTE IS THE LETTER, word for word: nothing writes it but its author. What this card makes is what
## the words only describe - each SKETCH, drawn as SVG by an agent and laid out by ghost's own TeX
## ([LetterSketches]), so the pen draws it; and each PICTURE a passage is read over, painted by the
## Illustrations library's painter from its mark ([IllustrationPanel], handed the letter's pictures and
## never its sketches). A letter plays without either: a sketch not drawn yet leaves its paragraph only
## said, a picture not painted leaves its passage over the desk.
##
## A CARD ON THE READING, as the Actor's and Proof's are: built by [NoteCards] from the `letter` row, it
## PINS ITS MEDIUM while it is up ([member Director.medium_override]) and HANDS the reading what is read
## ([LetterWalk]: the letter as the voice says it, the pen's rests in it, no title announced) and how it
## goes out ([LetterCard.Publish]: the document a render draws the letter from).
##
## THE DESK AND THE HAND ARE THE NOTE'S: the desk's seed is the note's own file's unless the card is given
## one ([method desk_seed]), so the same letter is written the same way every time; the hand is one of the
## journal's ([LetterHand], the Notebook's), Kalam unless the card names another.
##
## GENERATION IS EXPLICIT: Generate draws the sketches not drawn, then lays them out; a sketch's ⟳ draws
## it again. Nothing runs on open.
##
## THE NOTE'S OTHER CARDS ADD STEPS OF THEIR OWN ([EpisodeSteps] - the YouTube card's tags), and this card,
## handing the reading how it goes out, lists them: rows under the Ink, beside Generate (the user, 2026-10-28:
## they had waited at the bottom of the YouTube card), the note their episode - it is its own ([NoteUpload]) -
## made by Generate once the sketches are drawn, and by an export that goes up.

const KEY := "letter"
## The block: the desk's seed (0: the note's own), the hand it is written in and who draws the sketches.
const KNOBS := {"seed": 0, "hand": LetterHand.DEFAULT, "writer": "claude", "writer_model": "", "writer_effort": ""}
## What makes the note's episode, as the rows of the steps the note's other cards add say it.
const MAKES := "Generate, or an export that goes up"

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
## THE STEPS THE NOTE'S OTHER CARDS ADD, listed here: this card hands the reading how it goes out.
var _added := EpisodeSteps.new(host_name(), Callable(), MAKES)
var _added_rows: EpisodeStepRows # their rows, under the Ink

var _seed_box: SpinBox
var _mood: Label                 # what the desk's number picked, in a word ([constant DeskLook.MOODS])
var _hand_pick: OptionButton
var _writer: AgentPick
var _rows_box: VBoxContainer
var _rows := {}                  # a sketch's key -> {sketch, state: Label, redo: Button}
var _ink_state: Label
var _gen_btn: Button
var _stop_btn: Button
var _line: Label
var _pictures: IllustrationPanel


static func for_note(ctx: Dictionary) -> LetterCard:
	var card := LetterCard.new()
	card._panel = ctx.get("workspace") as ReadingPanel
	if card._panel != null:
		card._panel.walk = LetterWalk.new(card)
		card._panel.hand_publish(Publish.new(card), host_name())
		card._added = EpisodeSteps.new(host_name(), card._panel.episode_steps, MAKES)
		var doc := card._panel.doc_source()
		card._sketches = LetterSketches.new(doc.doc_path() if doc != null else "")
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
	_added.stop(_note_feed())
	if _panel != null:
		Director.unpin_medium(self)


func _process(delta: float) -> void:
	_row_t -= delta
	if _row_t > 0.0:
		return
	_row_t = 0.25
	_sketches.tick()
	var body := _body()
	if body != _seen:
		_seen = body
		_pictures.set_script_text(LetterScript.pictures_only(body))
		_build_rows()
	_lay_out_when_drawn()
	_tick_steps()
	_refresh()


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
	_show_knobs()


## The pictures' look - a block of its own (`illustrations:`), kept by the reading as the Picture card's is.
func illustrations() -> IllustrationPanel:
	return _pictures


# --- what it hands the reading -------------------------------------------------------------------

## HOW IT GOES OUT: the document a render draws the letter from carries what this card made.
class Publish extends ReadingPublish:
	var card: LetterCard

	func _init(c: LetterCard) -> void:
		card = c

	func book(d: Dictionary, _body: String) -> Dictionary:
		d["letter"] = card.document()
		return d


## THE DESK'S SEED, which is the hand's: the card's, or the note's own file's (a draft with no file, the
## first).
func desk_seed() -> int:
	if int(_knobs["seed"]) > 0:
		return int(_knobs["seed"])
	var doc := _panel.doc_source() if _panel != null else null
	var path := doc.doc_path() if doc != null else ""
	return 1 if path.is_empty() else 1 + absi(hash(path)) % 99999


## THE DOCUMENT'S `letter`: the seed, the hand, each sketch's drawing that is laid out, the ink, and each
## picture's file - what [LetterMedium] and [LetterWalk] read, so the voice's rests and the pen are sized alike.
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
	for im in Manuscript.images(LetterScript.pictures_only(body)):
		var path := Illustrations.path_for(String((im as Dictionary)["key"]))
		if not path.is_empty():
			pictures[String(im["key"])] = ProjectSettings.globalize_path(path)
	return {"seed": desk_seed(), "hand": LetterHand.of(String(_knobs["hand"])), "svgs": svgs, "ink": ink,
		"pictures": pictures}


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
	_added.asked = true          # the steps under them: the other cards' too
	var also := _added.names(_note_feed())
	_say(("Drawing the sketches…" if _sketches.busy() else "Every sketch is drawn.")
		+ ((" Then the note's %s, from its words." % ", ".join(also)) if not also.is_empty() else ""))


func _redo(key: String) -> void:
	var r: Dictionary = _rows.get(key, {})
	if r.is_empty():
		return
	_sketches.writer = _writer.choice()
	_sketches.redo(r["sketch"])
	_asked = true
	_ink_tried = ""


func _stop() -> void:
	_sketches.stop()
	_asked = false
	_added.stop(_note_feed())
	_say("Stopped - what was drawn is kept.")


# --- the steps the note's other cards add -------------------------------------------------------

## THE NOTE AS THEIR EPISODE: read as it is written, it is its own ([method ReadingPanel.note_upload]) - null
## while it has no YouTube card.
func _note_feed() -> EpisodeFeed:
	var up := _panel.note_upload() if _panel != null and is_instance_valid(_panel) else null
	return up.feed() if up != null else null


## This card as the steps' rows say where they are: "the Letter card".
static func host_name() -> String:
	return "the %s card" % String(Registry.field(Components.REGISTRY, KEY, "label", "Letter"))


## EACH REFRESH ([EpisodeSteps]): the note said to the steps listed, and once the sketches are drawn, each
## Generate asked for made - from the note's words, so only once they are written.
func _tick_steps() -> void:
	_added.tick(_note_feed(), _sketches.busy())


## ⟳ on a step's row: made again now, from the note's words - which must be written first.
func _redo_step(step: EpisodeStep) -> void:
	if not step.redo(_note_feed()):
		_say("%s waits for the note's words: write them on the Script card." % step.label)


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
	if _line != null:
		_line.text = text
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
	_seed_box.tooltip_text = ("Which desk the letter is written at, by number: its paper, ink and pen, its top and "
		+ "the things on it, how it is lit - the lamp, candles, a window's daylight or a low sun - and how each word "
		+ "wavers. 0 is the note's own, the same every time; any other number is a desk of its own.")
	_seed_box.value_changed.connect(func(v: float) -> void:
		if not _syncing:
			_knobs["seed"] = int(v)
			_touch()
		_show_mood())
	srow.add_child(_seed_box)
	# WHAT THE NUMBER PICKED, in a word (2026-10-27, the user: "It's not clear to me what the 'Desk' value ... is
	# doing. Is that just a random seed?")
	_mood = Label.new()
	_mood.add_theme_font_size_override("font_size", 12)
	_mood.modulate = Color(1, 1, 1, 0.7)
	_mood.mouse_filter = Control.MOUSE_FILTER_PASS
	srow.add_child(_mood)
	var again := Button.new()
	again.text = "New desk"
	again.tooltip_text = "Another desk, drawn at random."
	again.pressed.connect(func() -> void: _seed_box.value = randi_range(1, 99999))
	srow.add_child(again)

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

	var head := Label.new()
	head.text = "Sketches"
	head.add_theme_font_size_override("font_size", 12)
	add_child(head)
	_rows_box = VBoxContainer.new()
	add_child(_rows_box)
	var irow := HBoxContainer.new()
	irow.add_theme_constant_override("separation", 6)
	add_child(irow)
	var il := Label.new()
	il.text = "Ink"
	il.custom_minimum_size.x = 64.0
	il.add_theme_font_size_override("font_size", 12)
	irow.add_child(il)
	_ink_state = Label.new()
	_ink_state.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ink_state.clip_text = true
	_ink_state.add_theme_font_size_override("font_size", 11)
	_ink_state.mouse_filter = Control.MOUSE_FILTER_STOP
	irow.add_child(_ink_state)
	# THE STEPS THE NOTE'S OTHER CARDS ADD, under the Ink
	_added_rows = EpisodeStepRows.new(_added, " - once the note has words")
	_added_rows.redo.connect(_redo_step)
	add_child(_added_rows)

	var brow := HBoxContainer.new()
	brow.add_theme_constant_override("separation", 6)
	add_child(brow)
	_gen_btn = Button.new()
	_gen_btn.text = "Generate"
	_gen_btn.tooltip_text = ("Draw every sketch not drawn yet (or drawn from words since changed), then lay them "
		+ "out with TeX. Spends the drawer's quota. Then the steps listed above it (the note's tags), from the "
		+ "note's words. The pictures are painted below, each on its own.")
	_gen_btn.pressed.connect(_generate)
	brow.add_child(_gen_btn)
	_stop_btn = Button.new()
	_stop_btn.text = "Stop"
	_stop_btn.pressed.connect(_stop)
	brow.add_child(_stop_btn)
	var folder := Button.new()
	folder.text = "Folder"
	folder.tooltip_text = "Open the letter's folder: each sketch's drawing, the ink and the logs."
	folder.pressed.connect(func() -> void:
		DirAccess.make_dir_recursive_absolute(_sketches.dir)
		OS.shell_open(_sketches.dir))
	brow.add_child(folder)
	_line = Label.new()
	_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_line.add_theme_font_size_override("font_size", 11)
	_line.modulate = Color(1, 1, 1, 0.7)
	add_child(_line)

	# THE PICTURES, the Illustrations library's: handed the letter's picture marks alone
	_pictures = preload("res://src/media/illustration_panel.gd").new()
	add_child(_pictures)
	_show_knobs()


func _show_knobs() -> void:
	if _writer == null:
		return
	_syncing = true
	_writer.set_choice(String(_knobs["writer"]), String(_knobs["writer_model"]), String(_knobs["writer_effort"]))
	_seed_box.value = int(_knobs["seed"])
	_show_mood()
	_hand_pick.select(maxi(0, _hand_keys().find(LetterHand.of(String(_knobs["hand"])))))
	_syncing = false


## The desk's mood beside its number: how the desk the letter is written at is lit.
func _show_mood() -> void:
	if _mood == null:
		return
	var mood := String(DeskLook.of(desk_seed())["mood"])
	var row: Dictionary = DeskLook.MOODS[mood]
	_mood.text = String(row["label"])
	_mood.tooltip_text = String(row["blurb"])


## The hands, in the order the Picture card lists them.
static func _hand_keys() -> Array:
	var keys: Array = LetterHand.HANDS.keys()
	keys.sort()
	return keys


func _touch() -> void:
	if _panel != null:
		_panel.touch()


## A ROW A SKETCH: its words, its state, its ⟳ - rebuilt when the letter's sketches change.
func _build_rows() -> void:
	var sketches := LetterScript.sketches(_seen)
	_listed = sketches
	var keys := PackedStringArray()
	for s in sketches:
		keys.append(String((s as Dictionary)["key"]))
	if keys == PackedStringArray(_rows.keys()):
		for s in sketches:
			_rows[String(s["key"])]["sketch"] = s
		return
	for c in _rows_box.get_children():
		c.queue_free()
	_rows = {}
	if sketches.is_empty():
		var none := Label.new()
		none.text = "  (no <!-- sketch: ... --> marks in this letter)"
		none.add_theme_font_size_override("font_size", 11)
		none.modulate = Color(1, 1, 1, 0.6)
		_rows_box.add_child(none)
	for s in sketches:
		var r := HBoxContainer.new()
		r.add_theme_constant_override("separation", 6)
		_rows_box.add_child(r)
		var name_l := Label.new()
		name_l.text = String((s as Dictionary)["prompt"]).substr(0, 28) + "…"
		name_l.tooltip_text = String(s["prompt"])
		name_l.custom_minimum_size.x = 150.0
		name_l.clip_text = true
		name_l.mouse_filter = Control.MOUSE_FILTER_STOP
		name_l.add_theme_font_size_override("font_size", 11)
		r.add_child(name_l)
		var state := Label.new()
		state.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		state.clip_text = true
		state.add_theme_font_size_override("font_size", 11)
		state.mouse_filter = Control.MOUSE_FILTER_STOP
		r.add_child(state)
		var redo := Button.new()
		redo.text = "⟳"
		redo.flat = true
		redo.tooltip_text = "Draw this sketch again (then lay it out)"
		var key := String(s["key"])
		redo.pressed.connect(func() -> void: _redo(key))
		r.add_child(redo)
		_rows[key] = {"sketch": s, "state": state, "redo": redo}


func _refresh() -> void:
	var busy := _sketches.busy()
	var feed := _note_feed()
	var steps := _added.asked or _added.busy(feed)
	_gen_btn.disabled = busy or steps
	_stop_btn.disabled = not (busy or steps)
	_added_rows.refresh(feed)
	var refused := _sketches.refused()
	var all := _sketches.svgs(_listed)
	for key in _rows:
		var r: Dictionary = _rows[key]
		var sketch: Dictionary = r["sketch"]
		var st := _sketches.state(sketch)
		var said := ""
		match st:
			"ready", "stale":
				var why := String(refused.get(String(DeskScript.item("draw", String(all.get(key, "")))["id"]), ""))
				said = ("✗ TeX could not lay it out: " + why) if not why.is_empty() else \
					("✓ drawn" if st == "ready" else "⚠ drawn from words since changed - ⟳ draws it again")
			"running":
				said = "… " + _sketches.said(sketch)
			"queued":
				said = "… waiting its turn"
			"failed":
				said = "✗ " + _sketches.said(sketch)
			_:
				said = "–"
		(r["state"] as Label).text = said
		(r["state"] as Label).tooltip_text = said
		(r["redo"] as Button).disabled = busy and st in ["running", "queued"]
	var items := LetterScript.items(_seen, all)
	var ink := _sketches.ink_state(items)
	var shown: String = {"ready": "✓ laid out" if not items.is_empty() else "– nothing to lay out yet",
		"running": "… TeX is laying the drawings out", "failed": "✗ " + _sketches.ink_error(),
		"stale": "⚠ laid out for other drawings - Generate lays them out again",
		"missing": "– laid out once the sketches are drawn"}.get(ink, "–")
	if ink in ["missing", "stale"] and not _installing.is_empty():
		shown = "… " + _installing + " (the first time: a few hundred MB), then the drawings are laid out"
	_ink_state.text = shown
	_ink_state.tooltip_text = shown
