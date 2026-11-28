extends VBoxContainer
class_name PopupFormat

## PopupFormat - the pop-up book's own rows on the Medium card ([PopupMedium]; next/popup.md): the Letter's desk rows
## ([DeskRows]: which desk by number and the index cards' words; what is on it ticked on the Props card, [DeskProps]), kept
## in the note's `medium:` block and carried to the book in the reading's document (`medium`), beside the note's pop-up
## design ([PopupDesign], `popup`). It hands the reading the walk that rests the voice for the book ([PopupWalk]), and the
## note's Pipeline card the paper engineer's rows ([PopupEngineer]): the spreads made in layers from the script's briefs, ⟳
## making them again, and a row for each layer's picture, painted on Generate where it is missing.
##
## A number of 0 is the note's own desk ([method PopupMedium.desk_seed]). Changed while the book plays, the desk is dressed
## again at once.

var _desk: DeskRows
var _panel: ReadingPanel = null
var _section: Section = null


static func for_note(ctx: Dictionary) -> PopupFormat:
	var card := PopupFormat.new()
	card._panel = ctx.get("workspace") as ReadingPanel
	card._desk = DeskRows.new(card._own_seed, "the note's own desk, the same every time")
	card._desk.changed.connect(card._touch)
	card._desk.redress.connect(card._redress_live)
	card.add_child(card._desk)
	if card._panel != null:
		card._panel.walk = PopupWalk.new()
		card._panel.prop_sections.append(card._desk.props())
		card._panel.document_parts["popup"] = func() -> Dictionary:
			return {"medium": card._desk.capture(), "popup": PopupDesign.load_of(card._panel.note_path)}
	card._section = Section.new(card)
	return card


## What it hands the note's Pipeline card.
func pipeline() -> PipelineSection:
	return _section


func _note() -> String:
	return _panel.note_path if _panel != null and is_instance_valid(_panel) else ""


func _words() -> String:
	var box := _panel.source_box() if _panel != null and is_instance_valid(_panel) else null
	return box.text if box != null else ""


## The paper engineer's tools, over the note as it stands.
func _tools() -> PopupTools:
	var t := PopupTools.new()
	t.note = _note()
	t.body = _words
	t.design = PopupDesign.load_of(_note())
	t.document = func() -> Dictionary:
		var subs: Node = _panel.subtitles if _panel != null and is_instance_valid(_panel) else null
		var live: Variant = subs.get("document") if subs != null and is_instance_valid(subs) else null
		return live if live is Dictionary else {"medium": _desk.capture()}
	return t


## The design's layers' pictures, each painted or not ([method PopupDesign.pictures_of]).
func _layer_pictures() -> Array:
	return PopupDesign.pictures_of(PopupDesign.load_of(_note()))


## Whether every scene is made: in layers where it has a brief to make them from, as its own marks say where it has none.
func _stood() -> bool:
	var design := PopupDesign.load_of(_note())
	var scenes := PopupLayout.scenes_of(Manuscript.blocks(Manuscript.read_part(_words())).filter(func(b: Dictionary) -> bool:
		return String(b.get("placement", "")) != "cover"))
	if scenes.is_empty():
		return false
	for n in scenes.size():
		if not ((scenes[n] as Dictionary).get("brief", []) as Array).is_empty() and not PopupDesign.layered(PopupDesign.scene_of(design, n)):
			return false
	return true


## The layers' pictures not painted yet (nor painting).
func _unpainted() -> Array:
	return _layer_pictures().filter(func(im: Dictionary) -> bool:
		return Illustrations.status(String(im["key"])) in ["missing", "error"])


func _engineer() -> void:
	var why := PopupEngineer.start(_note(), _tools())
	if not why.is_empty() and _section != null:
		_section.tell("The paper engineer did not start: %s." % why)


func _step_rows() -> Array:
	var row := PipelineRow.new("popup:design", "The spreads made in layers")
	var note := _note()
	row.state = "running" if PopupEngineer.busy(note) else ("error" if PopupEngineer.failed(note) else ("ready" if _stood() else "missing"))
	row.said = PopupEngineer.line(note) if not PopupEngineer.line(note).is_empty() else ("every spread made" if row.state == "ready" else "")
	row.wraps = true
	row.again = "Have the paper engineer make every spread again from the script's briefs, in layers it paints, looks at and refines."
	row.asks = "The layers it made are kept in the library, but the spreads are made again."
	row.open = not PopupEngineer.busy(note)
	row.redo = _engineer
	var rows: Array = [row]
	for im in _layer_pictures():
		var d: Dictionary = im
		var r := PipelineRow.new("popup:" + String(d["key"]), "Scene %d, %s" % [int(d["scene"]) + 1, String(d["layer"])], "Layers")
		var st := Illustrations.status(String(d["key"]))
		r.state = st if st in ["missing", "queued", "running", "ready", "error"] else "missing"
		r.said = Illustrations.activity(String(d["key"])) if st in ["queued", "running"] else String(d["prompt"]).left(90)
		r.tip = String(d["prompt"])
		r.again = "Paint this layer again from its words."
		r.redo = func() -> void: Illustrations.generate({"key": d["key"], "prompt": d["prompt"], "placement": d["placement"]})
		rows.append(r)
	return rows


## The paper engineer's row on the note's one list ([PipelineCard]).
class Section extends PipelineSection:
	var card: PopupFormat

	func _init(c: PopupFormat) -> void:
		card = c
		owner = c
		title = "Pop-ups"

	func shown() -> bool:
		return not card._words().is_empty()

	func rows() -> Array:
		return card._step_rows()

	func make() -> void:
		if PopupEngineer.busy(card._note()):
			return
		if not card._stood():
			card._engineer()
			return
		for im in card._unpainted():
			Illustrations.generate({"key": im["key"], "prompt": im["prompt"], "placement": im["placement"]})

	func make_tip() -> String:
		return "Have the paper engineer make every spread in layers from the script's briefs (painting, looking and refining), and paint any layer still missing. Spends the agent's and the painter's quota."

	func stop() -> void:
		PopupEngineer.stop(card._note())

	func busy() -> bool:
		return PopupEngineer.busy(card._note())

	func missing() -> bool:
		return not card._stood() or not card._unpainted().is_empty()


func capture() -> Dictionary:
	return _desk.capture()


func apply(cfg: Dictionary) -> void:
	_desk.apply(cfg)


## The note's own desk's number: the one the book draws from its title.
func _own_seed() -> int:
	var doc := _panel.doc_source() if _panel != null and is_instance_valid(_panel) else null
	return PopupMedium.desk_seed({}, FrontMatter.field_of(doc.shown(), "title") if doc != null else "")


func _touch() -> void:
	if _panel != null:
		_panel.touch()


## The desk dressed again while the book plays: the rows as they stand, in the reading's live document's `medium`.
func _redress_live() -> void:
	var subs: Node = _panel.subtitles if _panel != null and is_instance_valid(_panel) else null
	if subs == null or not is_instance_valid(subs):
		return
	var doc: Dictionary = subs.get("document")
	var block: Dictionary = doc.get("medium", {}) if doc.get("medium") is Dictionary else {}
	block.merge(_desk.capture(), true)
	doc["medium"] = block
