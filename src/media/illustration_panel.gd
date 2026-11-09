extends VBoxContainer
class_name IllustrationPanel

## IllustrationPanel - THE NOTE'S PICTURES, listed and made: what the Pictures card ([PicturesCard]) holds, whatever the
## note is shown in ([Illustrations], the library that paints and keeps them).
##
## Top to bottom: which painter, its model and its effort ([AgentPick]); the STYLE every picture shares; the REFERENCE images
## that show that style rather than describe it; Generate all (every picture with none yet); and the note's own pictures,
## one row each, with what exists and buttons to make or remake it, or to use a file of the author's instead (Import…),
## where it can be judged. THE SAME PICTURES ARE ROWS OF THE NOTE'S PIPELINE CARD ([Section]; next/pipeline.md), with what
## is being painted, Generate, and the one that paints them all again.
##
## THE LIST FOLLOWS THE TEXT, not the library. [method set_pictures] is handed the pictures the note's words call for
## whenever they are read - which marks those are is the presentation's to say ([method Medium.pictures_of]: a letter's
## sketches are its pen's, a tablet's pages are captured) - so the rows are exactly those, in reading order: a picture
## whose description was edited is a new row, and the old one simply stops being listed (its files stay in the cache in
## case the edit is undone).
##
## Nothing here generates on its own. See [Illustrations] for why.

## The block this panel keeps under a document's `ghost:` key (next/notes.md step 5): the pictures'
## look - painter, styles, references - which travels with the note. Kept by the Pictures card.
const KEY := "illustrations"

## A line for the panel's status: a reference image the document names is not on this machine.
signal noted(msg: String)

## Big enough to judge a picture from without opening it - the whole point of the list is
## deciding which ones to repaint. Click one for the full-size preview.
const THUMB := 112
const REF_THUMB := 44

var _images: Array = []            # the pictures the note's words call for ([Manuscript.images] rows, pages captured)
var _list: VBoxContainer
var _kind_row: HBoxContainer       # the style kind picker's row: shown once the note has a sketch to paint
var _all: Button                   # Generate all: every picture with none yet
var _refs: HFlowContainer
var _refs_none: Label              # what stands in for the references while there are none
var _style: TextField
var _style_kind := "image"        # which of Illustrations.STYLE_KINDS the box is editing
var _kind_pick: OptionButton
var _self_ref: CheckBox
var _pick: AgentPick
## WHAT IT HANDS THE NOTE'S PIPELINE CARD ([method pipeline]).
var _section := Section.new(self)
var _preview: PictureWindow = null
var _status: Label
var _dialog: FileDialog = null
var _thumbs := {}                  # path|mtime|px -> ImageTexture, so a rebuild does not re-decode
var _seen := ""                    # what the list last drew, so it rebuilds only on change
var _live := {}                    # key -> [its status label, the line under the status] while it paints


func _ready() -> void:
	add_theme_constant_override("separation", 6)
	var hint := Label.new()
	hint.text = ("Painted from the image marks in the note's words, or a file of yours imported for one. Each is made "
		+ "once and kept; nothing is painted until you ask, because every picture spends your image quota.")
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 11)
	hint.modulate = Color(1, 1, 1, 0.6)
	add_child(hint)

	# THE PAINTER IS EVERY CARD'S ROW ([AgentPick]: the agent, its model, how hard it reasons), kept in
	# the look; this panel's own list of agents had no model and no effort (2026-10-27)
	_pick = AgentPick.painter("Who paints the pictures. Takes effect at the next picture painted.")
	_pick.set_choice(Illustrations.backend(), Illustrations.painter_model(), Illustrations.painter_effort())
	_pick.changed.connect(func() -> void:
		var c := _pick.choice()
		Illustrations.set_painter(String(c["agent"]), String(c["model"]), String(c["effort"])))
	add_child(_pick)

	# ONE BOX, A PICKER FOR WHICH STYLE IT EDITS: pictures and sketches are briefed separately,
	# and two boxes would double a panel that already scrolls.
	var srow := HBoxContainer.new()
	srow.add_theme_constant_override("separation", 8)
	add_child(srow)
	_kind_row = srow
	var sl := Label.new()
	sl.text = "Style"
	sl.add_theme_font_size_override("font_size", 12)
	sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	srow.add_child(sl)
	_kind_pick = OptionButton.new()
	_kind_pick.focus_mode = Control.FOCUS_NONE
	for k in Illustrations.STYLE_KINDS:
		_kind_pick.add_item(String(Illustrations.STYLE_LABELS.get(k, k)))
	_kind_pick.tooltip_text = ("Which look the style box and the references below edit. "
		+ "Pictures (`<!-- image: -->`) and sketches (`<!-- sketch: -->`) each have their own.")
	_kind_pick.item_selected.connect(func(i: int) -> void:
		_style_kind = String(Illustrations.STYLE_KINDS[i])
		_style.text = Illustrations.style(_style_kind)
		_self_ref.set_pressed_no_signal(Illustrations.self_reference(_style_kind))
		_refresh_refs())
	srow.add_child(_kind_pick)
	_self_ref = CheckBox.new()
	_self_ref.text = "Match earlier"
	_self_ref.focus_mode = Control.FOCUS_NONE
	_self_ref.tooltip_text = ("Send each picture of this kind the ones already made before it in "
		+ "the note (the first and the most recent few), so they read as one hand. Works "
		+ "alongside the references below and never adds to them. Saved in the document.")
	_self_ref.button_pressed = Illustrations.self_reference(_style_kind)
	_self_ref.toggled.connect(func(on: bool) -> void:
		Illustrations.set_self_reference(on, _style_kind)
		_refresh_refs())
	srow.add_child(_self_ref)
	_style = TextField.new("Style", "e.g. muted watercolor and ink, like a mid-century storybook plate",
		"How every picture of the chosen kind should look - medium, palette, "
		+ "linework, mood. Added to each one's own description. Changing it does not "
		+ "throw away pictures already made: they are marked stale and kept until you regenerate them.")
	_style.text = Illustrations.style(_style_kind)
	_style.text_changed.connect(func() -> void:
		Illustrations.set_style(_style.text, _style_kind)
		_seen = "")
	add_child(_style)

	var rrow := HBoxContainer.new()
	rrow.add_theme_constant_override("separation", 8)
	add_child(rrow)
	var rl := Label.new()
	rl.text = "References"
	rl.add_theme_font_size_override("font_size", 12)
	rl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rrow.add_child(rl)
	var imp := Button.new()
	imp.text = "Import…"
	imp.focus_mode = Control.FOCUS_NONE
	imp.tooltip_text = ("Pick images whose STYLE this kind (the dropdown above) should share. "
		+ "They are attached to every request of that kind as style references only - their "
		+ "subjects are never copied. With none, each picture is matched to the ones already "
		+ "made before it in the note instead. Copied into Ghost Notes' own folder, so moving the "
		+ "originals changes nothing.")
	imp.pressed.connect(_open_dialog)
	rrow.add_child(imp)
	_refs = HFlowContainer.new()
	_refs.add_theme_constant_override("h_separation", 4)
	_refs.add_theme_constant_override("v_separation", 4)
	add_child(_refs)
	# "NONE" IS A ROW OF ITS OWN, and wraps. In the flow it could not: a flow gives each child its
	# own width, so the one long line set the panel's - 357 px, past a card's room on a 380 px panel
	# (the Letter's card, which showed this panel whatever the medium; panel_fit_check 2026-10-27).
	_refs_none = Label.new()
	_refs_none.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_refs_none.add_theme_font_size_override("font_size", 11)
	_refs_none.modulate = Color(1, 1, 1, 0.6)
	add_child(_refs_none)

	_status = Label.new()
	_status.add_theme_font_size_override("font_size", 11)
	_status.add_theme_color_override("font_color", Color(0.55, 0.95, 0.75, 0.85))
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# ITS OWN ROW: a wrapping label given a sliver wraps every character, one letter a line.
	add_child(_status)

	# GENERATE ALL, on the card as on the Pipeline card's heading ([Section]): one function behind both, so neither can
	# be left without it
	_all = Button.new()
	_all.focus_mode = Control.FOCUS_NONE
	_all.pressed.connect(_generate_missing)
	add_child(_all)

	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 4)
	add_child(_list)
	_refresh_refs()
	_refresh()


## The block for a document: the library's look ([method Illustrations.look]).
func capture() -> Dictionary:
	return Illustrations.look()


## ...and back: a document's look becomes the library's, and the controls show it.
func apply(block: Dictionary) -> void:
	var errs := Illustrations.set_look(block)
	sync_from_library()
	if not errs.is_empty():
		noted.emit("reference image(s) not found: " + "; ".join(errs))


## The library changed underneath the controls - a document brought its own look. Show it.
func sync_from_library() -> void:
	if _pick != null:
		_pick.set_choice(Illustrations.backend(), Illustrations.painter_model(), Illustrations.painter_effort())
	if _style != null and _style.text != Illustrations.style(_style_kind):
		_style.text = Illustrations.style(_style_kind)
	if _self_ref != null:
		_self_ref.set_pressed_no_signal(Illustrations.self_reference(_style_kind))
	if _refs != null:
		_refresh_refs()
	_seen = ""


## THE PICTURES THE NOTE'S WORDS CALL FOR, whenever they are read: [Manuscript.images] rows (a captured page's has a
## `url`), in reading order - as the presentation shows them ([method Medium.pictures_of]). Cheap enough on every edit.
func set_pictures(rows: Array) -> void:
	_images = rows.duplicate(true)
	# the painter's self-reference chain is the painted ones alone: a page is captured, never painted
	Illustrations.set_chapter(_images.filter(func(im: Dictionary) -> bool: return not im.has("url")))
	_seen = ""
	if is_inside_tree():
		_refresh()


## Every image mark in [param body], as a book prints them.
func set_script_text(body: String) -> void:
	set_pictures(Manuscript.images(body))


func _process(_delta: float) -> void:
	Illustrations.pump()
	_refresh()


## Rebuild the rows only when something a row shows has changed - a status, a version, the
## look. A list rebuilt every frame would eat clicks on its own buttons.
func _refresh() -> void:
	if _list == null:
		return
	var sig := "%d|%s|%s|%d" % [Illustrations.revision, Illustrations.current_signature("image"),
		Illustrations.current_signature("sketch"), _images.size()]
	for im in _images:
		sig += "|" + Illustrations.status(String(im["key"]))
	# a picture being painted says what its painter is doing, updated in place: the list is rebuilt
	# only when something else changes
	for key in _live:
		var live: Array = _live[key]
		if is_instance_valid(live[0]):
			var doing := Illustrations.activity(String(key))
			(live[0] as Label).text = String(live[1]) + (("  -  painter " + doing) if not doing.is_empty() else "")
	if sig == _seen:
		return
	_seen = sig
	_live.clear()
	for c in _list.get_children():
		c.queue_free()
	for im in _images:
		_list.add_child(_row(im))
	if _images.is_empty():
		var none := Label.new()
		none.text = "  (no image marks in the note's words - Edit lists them)"
		none.add_theme_font_size_override("font_size", 11)
		none.modulate = Color(1, 1, 1, 0.6)
		_list.add_child(none)
	var n := Illustrations.busy()
	_status.text = ("⏳  Painting %d…" % n) if n > 0 else ""
	if not PageCapture.doing().is_empty():
		_status.text = "⏳  " + PageCapture.doing() + "…"
	_show_all()
	_show_kinds()


## GENERATE ALL says how many it would paint, and is grayed with nothing to paint.
func _show_all() -> void:
	var owed := _owed().size()
	var painted := _images.filter(func(im: Dictionary) -> bool: return not im.has("url")).size()
	_all.visible = painted > 0
	_all.text = ("Generate all (%d)" % owed) if owed > 0 else "Generate all"
	_all.disabled = owed == 0 or Illustrations.read_only()
	_all.tooltip_text = ("Paint every picture that has none yet - %d of %d, one request each against your image quota. "
		% [owed, painted] + "Those already made are kept as they are: to paint one again, its Regenerate; all of them, "
		+ "the Pipeline card's All pictures.") if owed > 0 else ("Every picture has one. To paint one again, its "
		+ "Regenerate; all of them again, the Pipeline card's All pictures.")


## THE KIND PICKER ONLY WHERE THERE IS A CHOICE: sketches have a style of their own (a notebook's `<!-- sketch: -->`),
## and a note with none, its look unset, has nothing for the picker to choose - a control that does nothing teaches
## nothing.
func _show_kinds() -> void:
	if _kind_row == null:
		return
	var any := _images.any(func(im: Dictionary) -> bool:
		return Illustrations.kind_of(String(im.get("placement", ""))) == "sketch")
	var set := not Illustrations.style("sketch").is_empty() or not Illustrations.references("sketch").is_empty()
	_kind_pick.visible = any or set or _style_kind == "sketch"


func _row(im: Dictionary) -> Control:
	var key := String(im["key"])
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	# The thumbnail IS the preview button: a flat button showing the picture, so the thing
	# to click is the thing you want a closer look at.
	var thumb := Button.new()
	thumb.flat = true
	thumb.focus_mode = Control.FOCUS_NONE
	thumb.custom_minimum_size = Vector2(THUMB, THUMB)
	thumb.expand_icon = true
	thumb.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var path := Illustrations.path_for(key)
	if not path.is_empty():
		thumb.icon = _thumb(path, THUMB * 2)
		thumb.tooltip_text = "Click to preview full size."
		thumb.pressed.connect(func() -> void: _open_preview(im))
	else:
		thumb.text = "none"
		thumb.disabled = true
	row.add_child(thumb)

	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 0)
	row.add_child(col)
	var desc := Label.new()
	desc.text = String(im["prompt"])
	desc.tooltip_text = String(im["prompt"])
	desc.add_theme_font_size_override("font_size", 11)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.max_lines_visible = 2
	desc.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	col.add_child(desc)
	var st := Illustrations.status(key)
	var meta := Label.new()
	var parts := PackedStringArray([_placement_label(im), String(im.get("side", "")), st])
	parts = PackedStringArray(Array(parts).filter(func(p: String) -> bool: return not p.is_empty()))
	var vs := Illustrations.versions(key)
	if vs.size() > 1:
		parts.append("v%d/%d" % [Illustrations.current_index(key) + 1, vs.size()])
	if Illustrations.is_stale(key):
		parts.append("stale")
	if Illustrations.is_imported(key):
		parts.append("imported")
	meta.text = "  ·  ".join(parts)
	if st in ["queued", "running"]:
		_live[key] = [meta, meta.text]
	meta.add_theme_font_size_override("font_size", 10)
	# WRAPS, ALWAYS: a status line that does not wrap sets the WHOLE panel's width - every tag
	# added to it ("imported") widened the side panel by its length
	meta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	meta.modulate = Color(1, 1, 1, 0.6)
	if st == "error":
		meta.text += "  -  " + Illustrations.error_of(key)
		meta.tooltip_text = Illustrations.error_of(key)
		meta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		meta.add_theme_color_override("font_color", Color(1.0, 0.6, 0.55))
	elif Illustrations.is_stale(key):
		meta.tooltip_text = "Made under a different style or reference set. Still used; regenerate to repaint it."
	col.add_child(meta)
	# THE BUTTONS ARE A LINE OF THEIR OWN under the text, not beside it: side by side they were
	# the panel's minimum width (thumbnail + label + five buttons), and the side panel grew. And the
	# line FLOWS: a picture with versions adds ‹ › to it, and as one row that was 356 px - the
	# Generative panel 10 px past its 380 (2026-10-06, the log named the Picture card). A flow is as
	# narrow as its widest button and wraps the rest.
	var acts := HFlowContainer.new()
	acts.add_theme_constant_override("h_separation", 4)
	acts.add_theme_constant_override("v_separation", 4)
	col.add_child(acts)

	if vs.size() > 1:
		var at := Illustrations.current_index(key)
		for step in [-1, 1]:
			var b := Button.new()
			b.text = "‹" if step < 0 else "›"
			b.focus_mode = Control.FOCUS_NONE
			b.tooltip_text = "Show the %s version." % ("previous" if step < 0 else "next")
			b.disabled = at + step < 0 or at + step >= vs.size()
			b.pressed.connect(func() -> void: Illustrations.select_version(key, at + step))
			acts.add_child(b)
	if not path.is_empty():
		var del := _delete_button("✕", key, Illustrations.current_index(key))
		acts.add_child(del)
	var go := Button.new()
	go.focus_mode = Control.FOCUS_NONE
	go.text = "Regenerate" if not path.is_empty() else "Generate"
	go.tooltip_text = ("Paint it again. The current picture is kept as an earlier version."
		if not path.is_empty() else "Paint this picture.")
	if im.has("url"):
		go.text = "Recapture" if not path.is_empty() else "Capture"
		go.tooltip_text = "Capture this page from the web as it is now (headless Chromium, via Playwright). Any current capture is kept as an earlier version."
	go.disabled = st in ["queued", "running"] or Illustrations.read_only()
	go.pressed.connect(func() -> void: _ask(im))
	acts.add_child(go)
	acts.add_child(_import_button(im))
	return row


## IMPORT A PICTURE FROM DISK for [param im] instead of painting one: it lands as a new version,
## so an imported picture and painted ones can be stepped between, and deleting it brings the
## last one back.
func _import_button(im: Dictionary) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.text = "Import…"
	b.tooltip_text = "Use a picture from disk for this one. Any current picture is kept as an earlier version."
	b.disabled = Illustrations.read_only()
	b.pressed.connect(func() -> void: _open_dialog(im))
	return b


func _ask(im: Dictionary) -> void:
	var err := Illustrations.capture(im) if im.has("url") else Illustrations.generate(im)
	if not err.is_empty():
		_status.text = "⚠  " + err
	_seen = ""


func _generate_all() -> void:
	for im in _images:
		if im.has("url"):
			continue              # a real page is captured, never painted
		if Illustrations.status(String(im["key"])) in ["queued", "running"]:
			continue
		var err := Illustrations.generate(im)
		if not err.is_empty():
			_status.text = "⚠  " + err
			return
	_seen = ""


## THE PREVIEW: the picture at full size in a window of its own ([PictureWindow]), with its description and its
## versions, so a repaint can be judged against the one before without leaving it.
func _open_preview(im: Dictionary) -> void:
	var key := String(im["key"])
	if _preview == null or not is_instance_valid(_preview):
		_preview = PictureWindow.new()
		add_child(_preview)
	var at := Illustrations.current_index(key)
	var extras: Array = []
	if at >= 0:
		extras.append(_delete_button("Delete this version", key, at, func() -> void:
			if Illustrations.versions(key).is_empty():
				_preview.hide()
			else:
				_open_preview(im)))
	var again := Button.new()
	again.text = "Regenerate"
	again.focus_mode = Control.FOCUS_NONE
	again.disabled = Illustrations.status(key) in ["queued", "running"] or Illustrations.read_only()
	again.pressed.connect(func() -> void:
		_ask(im)
		_preview.hide())
	extras.append(again)
	var imp := _import_button(im)
	imp.pressed.connect(func() -> void: _preview.hide())
	extras.append(imp)
	_preview.fill("Picture  ·  %s" % _placement_label(im), Illustrations.path_for(key), String(im["prompt"]), at,
		Illustrations.versions(key).size(), "(stale)" if Illustrations.is_stale(key) else "",
		func(dir: int) -> void:
			Illustrations.select_version(key, at + dir)
			_open_preview(im),
		extras)
	if not _preview.visible:
		_preview.open_over(self)


## DELETE TAKES TWO CLICKS ([ArmedDelete]): version [param version] of [param key]'s picture, its file too; then
## [param after], where something stands on what was deleted (the preview).
func _delete_button(label: String, key: String, version: int, after := Callable()) -> Button:
	var b := ArmedDelete.button(label, func() -> void:
		Illustrations.delete_version(key, version)
		_thumbs.clear()
		_seen = ""
		if after.is_valid():
			after.call(),
		"Delete this version of the picture - the file too. The one before it is shown instead, or none. Later "
		+ "pictures stop being matched to it.")
	b.disabled = Illustrations.read_only()
	return b


## GENERATE ALL: every picture that can be painted and has none, in reading order - the card's button and the Pipeline
## card's Generate alike.
func _generate_missing() -> void:
	for im in _owed():
		var err := Illustrations.generate(im)
		if not err.is_empty():
			_status.text = "⚠  " + err
			return
	_seen = ""


## The pictures that can be painted and have none (or failed). A page is captured, never painted: its own Capture.
func _owed() -> Array:
	return _images.filter(func(im: Dictionary) -> bool:
		return not im.has("url") and Illustrations.status(String(im["key"])) in ["missing", "error"])


# --- on the Pipeline card ------------------------------------------------------------------------

## WHAT THIS PANEL MAKES, on the note's one list ([PipelineCard]): a row a picture, and all of them again. Listed while the
## panel is shown (the Pictures card shows it while the note's presentation shows pictures) and its words call for any.
class Section extends PipelineSection:
	var panel: IllustrationPanel

	func _init(p: IllustrationPanel) -> void:
		panel = p
		owner = p
		title = "Pictures"

	func shown() -> bool:
		return panel.visible and not panel._images.is_empty()

	func rows() -> Array:
		return panel._step_rows()

	func make() -> void:
		panel._generate_missing()

	func make_tip() -> String:
		return "Paint every picture in this note that does not have one yet."

	func stop() -> void:
		Illustrations.stop(panel._images.map(func(im: Dictionary) -> String: return String(im["key"])))

	func busy() -> bool:
		return panel._painting()

	func missing() -> bool:
		return panel._missing()


## What it hands the note's Pipeline card.
func pipeline() -> PipelineSection:
	return _section


func _painting() -> bool:
	for im in _images:
		if Illustrations.status(String(im["key"])) in ["queued", "running"]:
			return true
	return false


## Whether a picture of the note that can be painted has none. (A page is captured, never painted: its own ⟳.)
func _missing() -> bool:
	return not _owed().is_empty()


## A ROW A PICTURE, ITS WORDS ITS NAME - and, with more than one, all of them again, which costs a note's worth of quota and asks.
func _step_rows() -> Array:
	var out: Array = []
	if _images.is_empty():
		return out
	var ro := Illustrations.read_only()
	var painting := _painting()
	if _images.size() > 1:
		var all := PipelineRow.new("all", "All pictures")
		all.state = "none"
		all.again = "Paint every picture in this note again"
		all.open = not ro and not painting
		all.asks = ("That is all %d pictures, one request each against your image quota. Pictures already made are kept as "
			+ "earlier versions.") % _images.size()
		all.redo = _generate_all
		out.append(all)
	for im in _images:
		var key := String(im["key"])
		var r := PipelineRow.new(key, String(im["prompt"]))
		r.tip = String(im["prompt"])
		var st := Illustrations.status(key)
		var captured: bool = (im as Dictionary).has("url")
		match st:
			"ready":
				r.state = "stale" if Illustrations.is_stale(key) else "made"
				var vs := Illustrations.versions(key).size()
				r.said = ("v%d/%d" % [Illustrations.current_index(key) + 1, vs]) if vs > 1 else ""
				if Illustrations.is_stale(key):
					r.said = (r.said + " - " if not r.said.is_empty() else "") + "made under another style"
			"queued", "running":
				r.state = st
				r.said = Illustrations.activity(key)
				r.wraps = true
			"error":
				r.state = "failed"
				r.said = Illustrations.error_of(key)
			_:
				r.state = "missing"
		var has_one := not Illustrations.path_for(key).is_empty()
		if captured:
			r.again = "Capture this page from the web as it is now (headless Chromium, via Playwright). Any current capture is kept as an earlier version."
		else:
			r.again = "Paint it again. The current picture is kept as an earlier version." if has_one else "Paint this picture."
		r.open = not ro and not st in ["queued", "running"]
		r.redo = _ask.bind(im)
		out.append(r)
	return out


## Keyed by the file's path AND its modification time (and the size asked for): a path can come
## to hold a different picture - a version number freed by a delete and taken by the next
## regenerate - and a path-only cache showed the old one until something else rebuilt it.
func _thumb(path: String, px: int) -> Texture2D:
	var key := "%s|%d|%d" % [path, FileAccess.get_modified_time(path), px]
	if _thumbs.has(key):
		return _thumbs[key]
	var img := Image.new()
	if img.load(path) != OK:
		return null
	var s := float(px) / float(maxi(img.get_width(), img.get_height()))
	img.resize(maxi(1, int(img.get_width() * s)), maxi(1, int(img.get_height() * s)),
		Image.INTERPOLATE_BILINEAR)
	var tex := ImageTexture.create_from_image(img)
	_thumbs[key] = tex
	return tex


# --- references --------------------------------------------------------------

func _refresh_refs() -> void:
	for c in _refs.get_children():
		c.queue_free()
	var list := Illustrations.references(_style_kind)
	_refs.visible = not list.is_empty()
	_refs_none.visible = list.is_empty()
	if list.is_empty():
		_refs_none.text = ("  (none - each is matched to the ones made before it in the note)"
			if Illustrations.self_reference(_style_kind) else "  (none - the style text alone decides the look)")
		return
	for i in list.size():
		var p := ProjectSettings.globalize_path(String(list[i]))
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 0)
		var t := TextureRect.new()
		t.custom_minimum_size = Vector2(REF_THUMB, REF_THUMB)
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		t.texture = _thumb(p, REF_THUMB * 2)
		t.tooltip_text = p
		box.add_child(t)
		var x := Button.new()
		x.text = "×"
		x.flat = true
		x.focus_mode = Control.FOCUS_NONE
		x.tooltip_text = "Stop using this reference. Pictures already made are kept, marked stale."
		var at := i
		x.pressed.connect(func() -> void:
			Illustrations.remove_reference(at, _style_kind)
			_refresh_refs()
			_seen = "")
		box.add_child(x)
		_refs.add_child(box)


## The file dialog: style references when [param for_image] is empty, otherwise ONE picture to
## use for that image.
func _open_dialog(for_image := {}) -> void:
	if _dialog != null and is_instance_valid(_dialog):
		return
	_dialog = FileDialog.new()
	_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILES if for_image.is_empty() else FileDialog.FILE_MODE_OPEN_FILE
	_dialog.access = FileDialog.ACCESS_FILESYSTEM
	# In-window, never native: the portal dialog shows nothing without xdg-desktop-portal.
	_dialog.use_native_dialog = false
	_dialog.title = "Import style references" if for_image.is_empty() else "Use a picture from disk"
	_dialog.filters = PackedStringArray(["*.png, *.jpg, *.jpeg, *.webp ; Images"])
	var pics := OS.get_system_dir(OS.SYSTEM_DIR_PICTURES)
	if not pics.is_empty():
		_dialog.current_dir = pics
	_dialog.size = Vector2i(820, 560)
	_dialog.file_selected.connect(func(path: String) -> void:
		var err := Illustrations.import_file(for_image, path)
		_status.text = "" if err.is_empty() else "⚠  " + err
		_seen = ""
		_close_dialog())
	_dialog.files_selected.connect(func(paths: PackedStringArray) -> void:
		var errs := Illustrations.add_references(Array(paths), _style_kind)
		_status.text = "" if errs.is_empty() else "⚠  " + "; ".join(errs)
		_refresh_refs()
		_seen = ""
		_close_dialog())
	_dialog.canceled.connect(_close_dialog)
	add_child(_dialog)
	_dialog.popup_centered()


func _close_dialog() -> void:
	if _dialog != null and is_instance_valid(_dialog):
		_dialog.queue_free()
	_dialog = null


## How a picture's placement reads in the list: "full page", "inline" or "sketch".
static func _placement_label(im: Dictionary) -> String:
	match String(im.get("placement", "")):
		"full":
			return "full page"
		"screen":
			return "the whole screen"
		"sketch":
			return "sketch"
		"page":
			return "web page"
	return "inline"
