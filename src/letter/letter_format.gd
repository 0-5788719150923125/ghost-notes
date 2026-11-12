extends VBoxContainer
class_name LetterFormat

## LetterFormat - the Letter's own rows on the Medium card: the note read as a letter, written by hand at a desk while the voice
## reads it (next/letter.md, [LetterMedium]). The Letter is one of the Medium card's formats ([MediumCard]).
##
## The note is the letter, word for word: nothing writes it but its author. What these rows make is what the words only describe:
## each sketch, drawn as SVG by an agent and laid out by ghost's own TeX ([LetterSketches]), so the pen draws it. Each picture a
## passage is read over is the note's Pictures card's ([PicturesCard]: the letter's pictures, never its sketches, [method
## LetterMedium.pictures_in]). A letter plays without either: a sketch not drawn yet is not drawn, a picture not painted leaves
## its passage over the desk.
##
## Rows on the reading's Medium card: built by [MediumCard] from the `letter` row's `card` while the Letter is the format, they
## hand the reading what is read ([LetterWalk]: the letter as the voice says it, the pen's rests in it, no title announced) and how
## it goes out ([LetterFormat.Publish]: the document a render draws the letter from). What they keep is part of the Medium's one block.
##
## The desk and the hand are the note's: the desk's seed is the note's own file's unless the rows are given one ([method
## DeskRows.desk_seed]); how each word wavers (and so where the lines break and the rests the voice takes) is always the note's own
## ([method hand_seed]), so the same letter is written the same way at any desk; the hand is one of the journal's ([Handwriting],
## the Notebook's): the Medium card's Handwriting ([method hand]).
##
## Which desk, its light, what is on it and the index cards' words are the desk's rows ([DeskRows], the Desk format's too), 0 the
## note's own desk. Changed while the letter plays, the desk is dressed again at once ([method _redress_live]); the hand waits for
## the next Play, since it changes how every word is written.
##
## Generation is explicit, on the note's Pipeline card ([Section]; next/pipeline.md): Generate draws the sketches not drawn, then
## lays them out; a sketch's ⟳ draws it again. Nothing runs on open.

## Its format's key in [constant Medium.REGISTRY].
const KEY := "letter"
## Its keys in the Medium's block: who draws the sketches; the desk's are its rows' ([constant DeskRows.KNOBS]). The hand is the
## Medium card's own row (`hand`).
const KNOBS := {"writer": "claude", "writer_model": "", "writer_effort": ""}

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
## What it hands the note's pipeline card ([method pipeline]).
var _section: Section = null

var _desk: DeskRows              # which desk, its light, what is on it, the index cards' words
var _writer: AgentPick


static func for_note(ctx: Dictionary) -> LetterFormat:
	var card := LetterFormat.new()
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


func _exit_tree() -> void:
	if _sketches != null:
		_sketches.stop()


func _process(delta: float) -> void:
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
	var out := _knobs.duplicate(true)
	out.merge(_desk.capture(), true)
	return out


func apply(cfg: Dictionary) -> void:
	_knobs = KNOBS.duplicate(true)
	for k in KNOBS:
		if cfg.has(k):
			_knobs[k] = String(cfg[k])
	if not TextGen.has(String(_knobs["writer"])):
		_knobs["writer"] = "claude"
	_desk.apply(cfg)
	_show_knobs()


# --- what it hands the reading -------------------------------------------------------------------

## How it goes out: the document a render draws the letter from carries what these rows made.
class Publish extends ReadingPublish:
	var card: LetterFormat

	func _init(c: LetterFormat) -> void:
		card = c

	func book(d: Dictionary, _body: String) -> Dictionary:
		d["letter"] = card.document()
		return d


## The hand's seed, how each word wavers and where the lines break: the note's own file's (a draft with no file, the first),
## whatever the desk's number.
func hand_seed() -> int:
	var doc := _panel.doc_source() if _panel != null else null
	var path := doc.doc_path() if doc != null else ""
	return 1 if path.is_empty() else 1 + absi(hash(path)) % 99999


## The hand it is written in: the Medium card's Handwriting ([member Director.hand], the Notebook's hands); Random is drawn from the
## note's own number ([method hand_seed]).
func hand() -> String:
	var h := String(Director.hand)
	if h == "random":
		var keys: Array = Handwriting.HANDS.keys()
		keys.sort()
		return String(keys[hand_seed() % keys.size()])
	return Handwriting.of(h)


## The document's `letter`: the hand's seed (`seed`) and the desk's (`desk`), the hand, each sketch's laid-out drawing, the ink,
## each picture's file, and what is on the desk, its light and the index cards' words; what [LetterMedium] and [LetterWalk] read, so
## the voice's rests and the pen are sized alike.
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
	var out := {"seed": hand_seed(), "hand": hand(), "svgs": svgs, "ink": ink, "pictures": pictures}
	out.merge(_desk.picks(), true)
	return out


## The desk dressed again while the letter plays: its number, what is on it, its light and the cards' words, handed to the reading's
## live document ([LetterMedium] dresses the desk again when they change).
func _redress_live() -> void:
	var subs: Node = _panel.subtitles if _panel != null and is_instance_valid(_panel) else null
	if subs == null or not is_instance_valid(subs):
		return
	var doc: Dictionary = subs.get("document")
	if doc.get("letter") is Dictionary:
		(doc["letter"] as Dictionary).merge(_desk.picks(), true)


func _body() -> String:
	var doc := _panel.doc_source() if _panel != null else null
	if _panel != null and _panel.source_box() != null:
		return _panel.source_box().text
	return doc.pull() if doc != null else ""


# --- the sketches --------------------------------------------------------------------------------

func _generate() -> void:
	var sketches := LetterScript.sketches(_body())
	_sketches.writer = _writer.choice()
	# A drawing the ink step refused is drawn again, told why
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

## What these rows make, on the note's one list ([PipelineCard]): a row a sketch, and their ink.
class Section extends PipelineSection:
	var card: LetterFormat

	func _init(c: LetterFormat) -> void:
		card = c
		owner = c
		title = Registry.label(Medium.REGISTRY, LetterFormat.KEY)

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


## Once the drawings are in, the ink: laid out by TeX when they are not the ones it was laid out from, after Generate or a ⟳, never
## on open, and not again on drawings it just failed on.
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


# --- the rows -----------------------------------------------------------------------------------

func _build() -> void:
	add_theme_constant_override("separation", 8)
	_desk = DeskRows.new(hand_seed, "the note's own desk, the same every time")
	_desk.changed.connect(_touch)
	_desk.redress.connect(_redress_live)
	add_child(_desk)

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
	_syncing = false


func _touch() -> void:
	if _panel != null:
		_panel.touch()


## A row a sketch, its words its name, and the ink they are laid out in, which is the tools' and has no ⟳: it follows the drawings
## ([method _lay_out_when_drawn]).
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
