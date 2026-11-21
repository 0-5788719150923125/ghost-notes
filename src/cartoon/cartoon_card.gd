extends VBoxContainer
class_name CartoonCard

## CartoonCard - the Cartoon's card (next/cartoon.md): the characters a cartoon is made of, each from its maker's drawing; the places it
## is set in, each a line saying what is there; and how long it runs. What is made of them is the Pipeline card's ([PipelineSection]):
## each character rigged by the rigger, each set painted in the cast's own drawing style, and the storyboard the director writes from
## the note's words, its direction and all of those ([CartoonProducer]). The note's show plays that storyboard in its Medium, silent.
##
## It keeps the note's `cartoon:` block: `cast` [{name, picture, about, height}], `sets` [{name, place}], `seconds`, `silent`. A
## character's puppet and a set's picture are named on the library's shelves (`puppets`, `sets`), so any note can use them.

## Its storyboard was written anew: the panel opens the note again around it, its silent track as long as it now is.
signal made(what: String)

const KEY := "cartoon"
## The drawings a character may come from.
const PICTURES := ["*.png", "*.jpg", "*.jpeg", "*.webp"]

var _workspace: Object = null
var _note_path := ""
var _folder := ""
var _block := {}
var _has_bookends := false
var _producer: CartoonProducer = null
var _walking := false
var _cast_box: VBoxContainer
var _sets_box: VBoxContainer
var _place: LineEdit
var _seconds: SpinBox
var _status: Label
var _dialog: FileDialog = null
var _section := Section.new()


## The card for a note's panel. From [param ctx]: `workspace` (told of a change), `path` (the note's file) and `folder` (its own).
static func for_note(ctx: Dictionary) -> CartoonCard:
	var c := CartoonCard.new()
	c._workspace = ctx.get("workspace")
	c._note_path = String(ctx.get("path", ""))
	c._folder = String(ctx.get("folder", ""))
	c._has_bookends = ctx.get("blocks") is Dictionary and (ctx["blocks"] as Dictionary).has("bookends")
	return c


func _init() -> void:
	add_theme_constant_override("separation", 6)
	_section.card = self
	_section.owner = self
	_section.title = "Cartoon"
	add_child(_heading("Characters", "Each is a puppet made from its maker's drawing: cut off the paper, a skeleton placed on it, its jaw, eyes and what it holds marked, by the rigger."))
	_cast_box = VBoxContainer.new()
	add_child(_cast_box)
	var add_char := Button.new()
	add_char.text = "+ Character…"
	add_char.tooltip_text = "A character from a drawing on plain paper: picked here, rigged by Generate."
	add_char.pressed.connect(_pick_drawing)
	add_child(add_char)
	add_child(_heading("Sets", "Each is a painted backdrop, made in the characters' own drawing style: say what the place has in it."))
	_sets_box = VBoxContainer.new()
	add_child(_sets_box)
	var row := HBoxContainer.new()
	_place = LineEdit.new()
	_place.placeholder_text = "A place: what is in it"
	_place.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_place.text_submitted.connect(func(_t: String) -> void: _add_set())
	row.add_child(_place)
	var add_set := Button.new()
	add_set.text = "+ Set"
	add_set.tooltip_text = "A set the cartoon can play in, painted by Generate."
	add_set.pressed.connect(_add_set)
	row.add_child(add_set)
	add_child(row)
	var len_row := HBoxContainer.new()
	var len_label := Label.new()
	len_label.text = "Seconds"
	len_label.tooltip_text = "About how long the director makes it."
	len_row.add_child(len_label)
	_seconds = SpinBox.new()
	_seconds.min_value = 10
	_seconds.max_value = 300
	_seconds.step = 5
	_seconds.value = CartoonProducer.SECONDS
	_seconds.value_changed.connect(func(v: float) -> void:
		_block["seconds"] = int(v)
		_touch())
	len_row.add_child(_seconds)
	add_child(len_row)
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_font_size_override("font_size", 12)
	_status.modulate = Color(1, 1, 1, 0.7)
	add_child(_status)


func _heading(text: String, tip: String) -> Label:
	var l := Label.new()
	l.text = text
	l.tooltip_text = tip
	l.mouse_filter = Control.MOUSE_FILTER_PASS
	return l


func capture() -> Dictionary:
	return _block.duplicate(true)


func apply(block: Dictionary) -> void:
	_block = block.duplicate(true)
	if not _block.has("silent"):
		_block["silent"] = true
	_seconds.set_value_no_signal(float(_block.get("seconds", CartoonProducer.SECONDS)))
	producer().block = _block
	# a cartoon starts on its first frame and ends on its last (it may loop, or play on a screen): no holds unless a Bookends card asks
	if not _has_bookends:
		Director.set_intro_hold(0.0)
		Director.set_outro_hold(0.0)
	_list()


func pipeline() -> PipelineSection:
	return _section


## Whether the cartoon can play: its storyboard is written.
func ready_to_play() -> bool:
	return producer().boarded()


## What the show is timed by: a silent track as long as the storyboard, kept in the note's folder (made where it is missing or
## another length).
func playable() -> String:
	return producer().silence()


## The producer of this note's cartoon, kept while the card is.
func producer() -> CartoonProducer:
	if _producer == null:
		_producer = CartoonProducer.new(_note_path, _folder, _block)
	return _producer


func _process(_delta: float) -> void:
	if _producer == null:
		return
	var was := _producer.busy()
	var had := _producer.boarded_stamp()
	_producer.pump()
	if _producer.boarded_stamp() != had:
		made.emit(_producer.silence())
	if _walking and not _producer.busy():
		var why := _producer.make_missing()
		if not _producer.busy():
			_walking = false
			if not why.is_empty():
				_section.tell(why)
	if was != _producer.busy() or Engine.get_process_frames() % 30 == 0:
		_status.text = _section.line()
		_list()


## Generate: everything not made yet, in order - rigs and sets at once, then the storyboard once they stand.
func generate() -> void:
	_walking = true
	var why := producer().make_missing()
	if not producer().busy():
		_walking = false
		_section.tell(why if not why.is_empty() else "Everything is made; ⟳ on a row makes that one again.")


# --- the lists -------------------------------------------------------------------------------------------------------------

func _list() -> void:
	for c in _cast_box.get_children():
		c.queue_free()
	for c in _sets_box.get_children():
		c.queue_free()
	var p := producer()
	for c in p.cast():
		var name := String(c["name"])
		var line := "Rigged" if CartoonProducer.rigged(name) else "Not rigged yet"
		if p.busy("rig:" + name):
			line = "The rigger is at work: " + p.activity("rig:" + name)
		elif not p.error_of("rig:" + name).is_empty():
			line = p.error_of("rig:" + name)
		var e := EntryCard.new(name, line, String(c.get("picture", "")))
		e.set_remove(_remove.bind("cast", name), "Take %s out of this cartoon (its puppet stays on the library's shelf)." % name)
		_cast_box.add_child(e)
	for s in p.sets():
		var name := String(s["name"])
		var line := String(s.get("place", ""))
		if p.busy("set:" + name):
			line = "Being painted: " + line
		elif not p.error_of("set:" + name).is_empty():
			line = p.error_of("set:" + name)
		elif not CartoonProducer.painted(name):
			line = "Not painted yet: " + line
		var e := EntryCard.new(name, line, String(s.get("place", "")))
		e.set_remove(_remove.bind("sets", name), "Take this set out of the cartoon (its picture stays on the library's shelf).")
		_sets_box.add_child(e)


func _remove(list: String, name: String) -> void:
	_block[list] = (_block.get(list, []) as Array).filter(func(x: Variant) -> bool: return not (x is Dictionary and String((x as Dictionary).get("name", "")) == name))
	producer().block = _block
	_touch()
	_list()


func _pick_drawing() -> void:
	if _dialog == null:
		_dialog = FileDialog.new()
		_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
		_dialog.access = FileDialog.ACCESS_FILESYSTEM
		_dialog.filters = PackedStringArray([", ".join(PICTURES) + " ; Drawings"])
		_dialog.title = "A character's drawing"
		_dialog.file_selected.connect(_add_character)
		add_child(_dialog)
	_dialog.popup_centered_ratio(0.6)


func _add_character(path: String) -> void:
	var name := slug(path.get_file().get_basename())
	var cast: Array = _block.get("cast", [])
	for c in cast:
		if c is Dictionary and String((c as Dictionary).get("name", "")) == name:
			return
	cast.append({"name": name, "picture": path})
	_block["cast"] = cast
	producer().block = _block
	_touch()
	_list()


func _add_set() -> void:
	var place := _place.text.strip_edges()
	if place.is_empty():
		return
	var sets: Array = _block.get("sets", [])
	var name := slug(" ".join(place.split(" ", false).slice(0, 4)))
	while sets.any(func(s: Variant) -> bool: return s is Dictionary and String((s as Dictionary).get("name", "")) == name):
		name += "_2"
	sets.append({"name": name, "place": place})
	_block["sets"] = sets
	_place.text = ""
	producer().block = _block
	_touch()
	_list()


## A name a shelf keeps: lower case, words joined by underscores.
static func slug(text: String) -> String:
	var out := ""
	for ch in text.to_lower():
		out += ch if (ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9") else "_"
	while out.contains("__"):
		out = out.replace("__", "_")
	return out.strip_edges().trim_prefix("_").trim_suffix("_")


func _touch() -> void:
	if _workspace != null and is_instance_valid(_workspace) and _workspace.has_method("touch"):
		_workspace.call("touch")


# --- what it hands the Pipeline card ---------------------------------------------------------------------------------------

## The cartoon's rows: each character's rig, each set's painting, and the storyboard.
class Section extends PipelineSection:
	var card: CartoonCard = null

	func shown() -> bool:
		return card != null and is_instance_valid(card)

	func rows() -> Array:
		var out: Array = []
		var p := card.producer()
		for c in p.cast():
			var name := String(c["name"])
			out.append(_row("rig:" + name, "%s rigged" % name, CartoonProducer.rigged(name),
				"Rig %s again from its drawing: cut, skeleton and all." % name,
				"Throws %s's puppet away and makes it again." % name if CartoonProducer.rigged(name) else "",
				func() -> void: p.make(c)))
		for s in p.sets():
			var name := String(s["name"])
			out.append(_row("set:" + name, "%s painted" % name, CartoonProducer.painted(name), "Paint this set again.",
				"Throws the set's picture away and paints it again." if CartoonProducer.painted(name) else "",
				func() -> void: p.paint(s)))
		out.append(_row("board", "Storyboard written", p.boarded(), "Write the storyboard again from the note, its cast and its sets.",
			"Writes over the storyboard (Restore… on its timeline brings it back)." if p.boarded() else "",
			func() -> void: p.direct()))
		return out

	func _row(key: String, label: String, made: bool, again: String, asks: String, redo: Callable) -> PipelineRow:
		var p := card.producer()
		var r := PipelineRow.new(key, label)
		r.group = "Cartoon"
		r.state = "running" if p.busy(key) else ("failed" if not p.error_of(key).is_empty() else ("made" if made else "missing"))
		r.said = p.activity(key) if p.busy(key) else p.error_of(key)
		r.again = again
		r.asks = asks
		r.open = not p.busy(key)
		r.redo = redo
		return r

	func line() -> String:
		if not told.is_empty():
			return told
		var p := card.producer()
		return "Agents at work on the cartoon." if p.busy() else ""

	func make() -> void:
		told = ""
		card.generate()

	func make_tip() -> String:
		return "Rig each character, paint each set, then write the storyboard: whatever is not made yet."

	func busy() -> bool:
		return card.producer().busy()
