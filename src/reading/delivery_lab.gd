extends Window
class_name DeliveryLab

## DeliveryLab - one delivery a note says, worked on in one place (next/delivery.md, "Tuning a delivery"; Lab… on its entry on the
## Voice card, [DeliverySection]): HEARD in one of the note's voices on words the script says it on (or words of the Lab's own), as
## said and plain, one against the other ([method ReadingPanel.audition_chunks]) and as numbers ([DeliveryHearing]); SHAPED by hand -
## every axis a curve across the stretch it covers ([CurveEdit], start to end), its shape, the acts on its last word each with its
## degree and the pitch it draws across its word, its stress; REFINED by a designer who hears it ([DeliveryDesign], [TextRefine]);
## and KEPT for every note ([DeliveryLibrary]).
##
## A hand's change is the note's version at once ([method DeliveryVersions.set_hand]: a run of moves is one version, a designer's
## turn another), heard from the next Test; the versions are picked at the bottom, and "As it comes" says it as the library or the bank
## does again. A name of the note's own is named and said what it is here (the agents writing the script are told).

const AXIS_H := 54.0
const CONTOUR_H := 84.0
const WIDE := 640
const TALL := 760

## The list this delivery is on.
var section: DeliverySection
## The delivery, as a script says it.
var delivery := ""

var _about: Label
var _name_row: HBoxContainer
var _name_edit: LineEdit
var _what_edit: LineEdit
var _voice: OptionButton
var _pick_words: OptionButton
var _words: TextEdit
var _said_b: Button
var _plain_b: Button
var _hear_b: Button
var _heard: Label
var _shape: OptionButton
var _axes := {}                   # axis -> its CurveEdit
var _acts_box: VBoxContainer
var _add_act: OptionButton
var _emph: OptionButton
var _version: OptionButton
var _status: Label
var _spec := {}                   # the delivery as the controls show it
var _syncing := false
var _hearing: DeliveryHearing
var _last_wav := ""               # the last take heard as said: what Keep puts beside it
var _playing := ""                # "said" or "plain" while a test of this Lab's plays
var _refine: TextRefine
var _refine_btn: Button = null    # its Refine button, a toggle


func _init(owner: DeliverySection, name_: String) -> void:
	section = owner
	delivery = name_
	visible = false
	transient = true
	title = "Delivery - %s" % delivery
	min_size = Vector2i(520, 480)
	close_requested.connect(_close)
	window_input.connect(func(e: InputEvent) -> void:
		if e is InputEventKey and (e as InputEventKey).pressed and (e as InputEventKey).keycode == KEY_ESCAPE:
			_close())
	var bg := PanelContainer.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var pad := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, 10)
	bg.add_child(pad)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 8)
	pad.add_child(outer)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 6)
	scroll.add_child(col)

	_about = _label("", 12)
	_about.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_about)
	# a name of the note's own: named, and said what it is
	_name_row = HBoxContainer.new()
	_name_row.add_theme_constant_override("separation", 6)
	_name_row.add_child(_label("Name", 12))
	_name_edit = LineEdit.new()
	_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_edit.tooltip_text = "What the script says to have words said this way: lowercase words, as in [words]{name}."
	_name_edit.text_submitted.connect(func(_t: String) -> void: _renamed())
	_name_edit.focus_exited.connect(_renamed)
	_name_row.add_child(_name_edit)
	_name_row.add_child(_label("What it is", 12))
	_what_edit = LineEdit.new()
	_what_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_what_edit.tooltip_text = "A few words on how it sounds: the agents writing the script are told them, beside its name."
	_what_edit.text_changed.connect(func(t: String) -> void:
		section._entry(delivery)["about"] = t.strip_edges()
		section.cast.deliveries_changed())
	_name_row.add_child(_what_edit)
	col.add_child(_name_row)

	col.add_child(_heading("Hear it"))
	var trow := HBoxContainer.new()
	trow.add_theme_constant_override("separation", 6)
	_voice = OptionButton.new()
	_voice.fit_to_longest_item = false
	_voice.clip_text = true
	_voice.custom_minimum_size = Vector2(140, 0)
	_voice.tooltip_text = "Which of the note's voices says it: a delivery can suit one voice and not another."
	trow.add_child(_voice)
	_said_b = _button("As said", "The words said with the delivery as it stands here, in the voice picked. Press again to stop.", func() -> void: _play("said"))
	trow.add_child(_said_b)
	_plain_b = _button("Plain", "The same words with no delivery: what it is heard against. Press again to stop.", func() -> void: _play("plain"))
	trow.add_child(_plain_b)
	_hear_b = _button("Measure", "Say both and measure them: how much longer or shorter, higher or lower, wider or flatter, louder or softer it is than plain, and pitch and level across it. Its designer hears these numbers.", _measure)
	trow.add_child(_hear_b)
	col.add_child(trow)
	var wrow := HBoxContainer.new()
	wrow.add_theme_constant_override("separation", 6)
	wrow.add_child(_label("Words", 12))
	_pick_words = OptionButton.new()
	_pick_words.fit_to_longest_item = false
	_pick_words.clip_text = true
	_pick_words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pick_words.tooltip_text = "Lines to hear it on: first those of the script that say it, then lines made to show it - one suited to it, then others. Picked, a line fills the words below, which can be changed as they stand."
	_pick_words.item_selected.connect(func(i: int) -> void: _words.text = String(_pick_words.get_item_metadata(i)))
	wrow.add_child(_pick_words)
	col.add_child(wrow)
	_words = TextEdit.new()
	_words.custom_minimum_size = Vector2(0, 52)
	_words.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_words.placeholder_text = "Words to hear it on - plain words are said with it round all of them; [words]{%s} says it on those alone." % delivery
	_words.tooltip_text = "The words it is heard on, picked above or written here. Plain words are said with the delivery round all of them, words with marks as written."
	col.add_child(_words)
	_heard = _label("", 11)
	_heard.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_heard.modulate = Color(1, 1, 1, 0.8)
	_heard.visible = false
	col.add_child(_heard)

	col.add_child(_heading("Over the stretch"))
	var srow := HBoxContainer.new()
	srow.add_child(_label("Shape", 12))
	_shape = OptionButton.new()
	_shape.add_item("Eased in and out")
	_shape.set_item_metadata(0, "")
	for k in DeliveryBank.SHAPES:
		_shape.add_item(String(DeliveryBank.SHAPES[k]["label"]))
		_shape.set_item_metadata(_shape.item_count - 1, String(k))
	_shape.tooltip_text = "How much of it holds along the stretch: eased in over its first syllables and let go after (a stretch to its paragraph's end; a closed one is exact), building, fading, swelling, or all at once."
	_shape.item_selected.connect(func(_i: int) -> void: _edited())
	srow.add_child(_shape)
	col.add_child(srow)
	var hint := _label("Each axis across the stretch, its first word to its last: double-click to add a point or take one off, drag to move it. One point holds all the way; two or more move through them.", 11)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.modulate = Color(1, 1, 1, 0.6)
	col.add_child(hint)
	for k in DeliveryBank.AXES:
		var a: Dictionary = DeliveryBank.AXES[k]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		var l := _label(String(a["label"]), 12)
		l.custom_minimum_size = Vector2(72, 0)
		l.tooltip_text = String(a["blurb"])
		l.mouse_filter = Control.MOUSE_FILTER_STOP
		row.add_child(l)
		var ce := CurveEdit.new()
		ce.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ce.custom_minimum_size = Vector2(240, AXIS_H)
		ce.log_scale = String(a["kind"]) == "mult"
		ce.lo = float(a["lo"])
		ce.hi = float(a["hi"])
		ce.neutral = 1.0 if ce.log_scale else 0.0
		ce.unit = String(a["unit"])
		ce.tooltip_text = String(a["blurb"])
		ce.marks = [[0.0, "start"], [0.92, "end"]]
		ce.edited.connect(_edited)
		row.add_child(ce)
		var clear := _button("×", "Back to the voice's own: no points.", func() -> void:
			ce.points = []
			ce.queue_redraw()
			_edited())
		row.add_child(clear)
		col.add_child(row)
		_axes[k] = ce

	col.add_child(_heading("On the last word"))
	_acts_box = VBoxContainer.new()
	_acts_box.add_theme_constant_override("separation", 6)
	col.add_child(_acts_box)
	var arow := HBoxContainer.new()
	arow.add_theme_constant_override("separation", 6)
	_add_act = OptionButton.new()
	_add_act.fit_to_longest_item = false
	_add_act.custom_minimum_size = Vector2(180, 0)
	_add_act.tooltip_text = "What the stretch's last word does (every word, for spaced, none, hit and hit hard)."
	_add_act.item_selected.connect(_act_added)
	arow.add_child(_add_act)
	arow.add_child(_label("Stress", 12))
	_emph = OptionButton.new()
	for t in ["None", "Hit (as italic)", "Hit hard (as bold)"]:
		_emph.add_item(t)
	_emph.tooltip_text = "Every word stressed as an italic word is, or as a bold one."
	_emph.item_selected.connect(func(_i: int) -> void: _edited())
	arow.add_child(_emph)
	col.add_child(arow)

	# the bottom bar: versions, refine, keep
	var bar := HFlowContainer.new()
	bar.add_theme_constant_override("h_separation", 6)
	bar.add_theme_constant_override("v_separation", 6)
	_version = OptionButton.new()
	_version.fit_to_longest_item = false
	_version.clip_text = true
	_version.custom_minimum_size = Vector2(200, 0)
	_version.tooltip_text = "Which of its versions the note says: each made here by hand or by its designer."
	_version.item_selected.connect(_version_picked)
	bar.add_child(_version)
	_refine_btn = _button("Refine…", "Ask a designer for a change in your words: it changes the numbers, hears the words said with them against plain, and leaves a new version.", func() -> void: _open_refine())
	_refine_btn.toggle_mode = true
	bar.add_child(_refine_btn)
	bar.add_child(_button("Keep", "Keep it in your library as it stands here: under a bank name it is said this way in every note that says it; under a name of its own it is a word every script may say.", _keep))
	bar.add_child(_button("As it comes", "Said as your library or the bank says it again: this note's tuning set by (its versions stay, to pick again).", _as_it_comes))
	outer.add_child(bar)
	_status = _label("", 11)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_color_override("font_color", Color(0.55, 0.95, 0.75, 0.9))
	outer.add_child(_status)


func _label(t: String, size_: int) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", size_)
	return l


func _heading(t: String) -> Label:
	var l := _label(t, 13)
	l.modulate = Color(1, 1, 1, 0.85)
	return l


func _button(t: String, tip: String, act: Callable) -> Button:
	var b := Button.new()
	b.text = t
	b.tooltip_text = tip
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 12)
	b.pressed.connect(act)
	return b


## Shown in the middle of the room beside the panel, filled for the delivery as the note says it now.
func open() -> void:
	_fill_voices()
	_fill_words()
	load_spec()
	var root := get_tree().root.get_visible_rect() if is_inside_tree() else Rect2(0, 0, 1600, 900)
	var w := mini(WIDE, int(root.size.x * 0.9))
	var h := mini(TALL, int(root.size.y * 0.9))
	var left := root.position.x
	var panel: Control = section.cast.panel._panel if section.cast != null and section.cast.panel != null else null
	if panel != null and panel.is_visible_in_tree():
		left = maxf(left, panel.get_global_rect().end.x + 12.0)
	var x := clampf(left + (root.end.x - left - w) * 0.5, root.position.x, maxf(root.position.x, root.end.x - w))
	var r := Rect2i(roundi(x), roundi(root.position.y + (root.size.y - h) * 0.5), w, h)
	if not visible:
		popup(r)
	else:
		grab_focus()


func _close() -> void:
	if _playing != "" and section.cast.panel.testing():
		section.cast.panel.stop_testing()
	_playing = ""
	hide()


func _process(_delta: float) -> void:
	if not visible:
		return
	if _playing != "" and not section.cast.panel.testing():
		_playing = ""
	_said_b.text = "As said ■" if _playing == "said" else "As said"
	_plain_b.text = "Plain ■" if _playing == "plain" else "Plain"


func _fill_voices() -> void:
	var was := _voice.get_item_text(_voice.selected) if _voice.selected >= 0 else ""
	_voice.clear()
	var names: Array = section.cast.cast_dict().keys()
	for n in names:
		_voice.add_item(String(n))
	var i := names.find(was)
	if i < 0:
		i = names.find(section.cast.tab_name())
	if _voice.item_count > 0:
		_voice.select(maxi(i, 0))


## The lines offered to hear it on ([method DeliverySection.lines_for], [method DeliveryHearing.words_for]), and the words filled in
## with the first where none are written yet.
func _fill_words() -> void:
	_pick_words.clear()
	for l in section.lines_for(delivery):
		_pick_words.add_item("From the script: " + DeliveryHearing.plain_of(String(l)).strip_edges().left(80))
		_pick_words.set_item_metadata(_pick_words.item_count - 1, String(l))
	for l in DeliveryHearing.words_for(delivery):
		_pick_words.add_item(String(l).left(90))
		_pick_words.set_item_metadata(_pick_words.item_count - 1, String(l))
	if _words.text.strip_edges().is_empty() and _pick_words.item_count > 0:
		_pick_words.select(0)
		_words.text = String(_pick_words.get_item_metadata(0))
	else:
		_pick_words.select(-1)


func _voice_name() -> String:
	return _voice.get_item_text(_voice.selected) if _voice.selected >= 0 else section.cast.reader()


## The words heard, with the delivery round them as [method DeliveryHearing.passage_of] says.
func passage() -> String:
	return DeliveryHearing.passage_of(delivery, _words.text)


# --- the controls from the delivery, and back -------------------------------------------------------------------------


## The controls filled from the delivery as the note says it now ([method DeliverySection.said_as]).
func load_spec() -> void:
	var now := section.said_as(delivery)
	_spec = (now["spec"] as Dictionary).duplicate(true)
	var from := String(now["from"])
	_syncing = true
	title = "Delivery - %s" % delivery
	var own := not DeliveryBank.is_named(delivery)
	_name_row.visible = own
	if own:
		_name_edit.text = delivery
		_what_edit.text = String((section.cast.deliveries.get(delivery, {}) as Dictionary).get("about", ""))
	var blurb := DeliveryBank.blurb_of(delivery)
	_about.text = "%s%s" % [blurb if not blurb.is_empty() else "A delivery of this note's own.",
		{"tuned": "  Tuned here.", "kept": "  As kept in your library.", "bank": "", "own": "  Nothing shaped yet."}[from]]
	var axes: Dictionary = _spec.get("axes", {}) if _spec.get("axes") is Dictionary else {}
	for k in _axes:
		var ce: CurveEdit = _axes[k]
		ce.points = (axes.get(k, []) as Array).duplicate(true) if axes.get(k) is Array else []
		ce.queue_redraw()
	var sh := String(_spec.get("shape", ""))
	for i in _shape.item_count:
		if String(_shape.get_item_metadata(i)) == sh:
			_shape.select(i)
	_emph.select(clampi(int(_spec.get("emph", 0)), 0, 2))
	_fill_acts()
	_fill_versions(from)
	_syncing = false


func _fill_acts() -> void:
	for c in _acts_box.get_children():
		_acts_box.remove_child(c)
		c.queue_free()
	var acts: Dictionary = _spec.get("acts", {}) if _spec.get("acts") is Dictionary else {}
	var contours: Dictionary = _spec.get("contours", {}) if _spec.get("contours") is Dictionary else {}
	for a in acts:
		_acts_box.add_child(_act_row(String(a), float(acts[a]), contours.get(a, []) as Array if contours.get(a) is Array else []))
	_add_act.clear()
	_add_act.add_item("+ An act on the last word")
	_add_act.set_item_metadata(0, "")
	for k in DeliveryBank.ACTS:
		if k == "hit" or k == "hit hard" or acts.has(k):
			continue
		_add_act.add_item(String(DeliveryBank.ACTS[k]["label"]))
		_add_act.set_item_metadata(_add_act.item_count - 1, String(k))
		_add_act.set_item_tooltip(_add_act.item_count - 1, String(DeliveryBank.ACTS[k]["blurb"]))
	_add_act.select(0)


## One act's row: its name, its degree, a × that takes it off, and (for one that draws a pitch) the pitch across its word.
func _act_row(act: String, degree: float, own: Array) -> Control:
	var box := VBoxContainer.new()
	box.set_meta("act", act)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var l := _label(Registry.label(DeliveryBank.ACTS, act), 12)
	l.custom_minimum_size = Vector2(72, 0)
	l.tooltip_text = Registry.blurb(DeliveryBank.ACTS, act)
	l.mouse_filter = Control.MOUSE_FILTER_STOP
	row.add_child(l)
	var deg := HSlider.new()
	deg.min_value = 0.0
	deg.max_value = 2.0
	deg.step = 0.05
	deg.value = degree
	deg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	deg.tooltip_text = "Its degree: 1 as a good reader gives it, 2 an actor's size."
	deg.set_meta("degree", true)
	var shown := _label("%.2f" % degree, 11)
	deg.value_changed.connect(func(v: float) -> void: shown.text = "%.2f" % v)
	deg.drag_ended.connect(func(_c: bool) -> void: _edited())
	row.add_child(deg)
	row.add_child(shown)
	row.add_child(_button("×", "Take this act off.", func() -> void:
		_acts_box.remove_child(box)
		box.queue_free()
		_edited()
		_fill_add_act()))
	box.add_child(row)
	var base := DeliveryBank.contour_of(act)
	if not base.is_empty():
		var ce := CurveEdit.new()
		ce.custom_minimum_size = Vector2(240, CONTOUR_H)
		ce.lo = -8.0
		ce.hi = 8.0
		ce.neutral = 0.0
		ce.unit = "st"
		ce.between = "ease"
		ce.pins = {"stress<": 0.3, "stress": 0.45, "stress>": 0.6}
		ce.marks = [[0.0, "word"], [0.3, "stressed vowel"]]
		ce.points = own.duplicate(true) if not own.is_empty() else base
		ce.tooltip_text = "The pitch it draws across its word at degree 1, in semitones from where the voice would be: the gold points sit on the stressed vowel (its start, middle and end) and move up and down; double-click to add a point or take one off."
		ce.set_meta("contour", true)
		ce.edited.connect(_edited)
		box.add_child(ce)
	return box


func _fill_add_act() -> void:
	var on := {}
	for c in _acts_box.get_children():
		if not c.is_queued_for_deletion():
			on[String(c.get_meta("act"))] = true
	_add_act.clear()
	_add_act.add_item("+ An act on the last word")
	_add_act.set_item_metadata(0, "")
	for k in DeliveryBank.ACTS:
		if k == "hit" or k == "hit hard" or on.has(k):
			continue
		_add_act.add_item(String(DeliveryBank.ACTS[k]["label"]))
		_add_act.set_item_metadata(_add_act.item_count - 1, String(k))
	_add_act.select(0)


func _act_added(i: int) -> void:
	var act := String(_add_act.get_item_metadata(i))
	if act.is_empty():
		return
	_acts_box.add_child(_act_row(act, 1.0, []))
	_edited()
	_fill_add_act()


func _fill_versions(from: String) -> void:
	_version.clear()
	var dir := section.cast.delivery_folder(delivery)
	var vs := DeliveryVersions.versions(dir)
	if from != "tuned":
		_version.add_item({"bank": "As it comes", "kept": "As kept", "own": "Nothing shaped"}.get(from, "As it comes"))
		_version.set_item_metadata(0, -1)
	for i in vs.size():
		_version.add_item(DeliveryVersions.label_of(dir, i))
		_version.set_item_metadata(_version.item_count - 1, i)
		if from == "tuned" and i == DeliveryVersions.used(dir):
			_version.select(_version.item_count - 1)
	if from != "tuned":
		_version.select(0)
	_version.disabled = vs.is_empty()


## The delivery as the controls show it.
func spec_now() -> Dictionary:
	var axes := {}
	var brake := {}
	var was_brake: Dictionary = _spec.get("brake", {}) if _spec.get("brake") is Dictionary else {}
	for k in _axes:
		var pts: Array = (_axes[k] as CurveEdit).points
		if pts.is_empty():
			continue
		axes[k] = pts.duplicate(true)
		if pts.size() == 2 and was_brake.has(k):
			brake[k] = was_brake[k]
	var acts := {}
	var contours := {}
	for c in _acts_box.get_children():
		if c.is_queued_for_deletion():
			continue
		var act := String(c.get_meta("act"))
		for n in c.find_children("*", "", true, false):
			if n is HSlider and n.has_meta("degree"):
				acts[act] = snappedf((n as HSlider).value, 0.01)
			elif n is CurveEdit and n.has_meta("contour"):
				var pts: Array = (n as CurveEdit).points
				if DeliveryVersions.what({"c": pts}) != DeliveryVersions.what({"c": DeliveryBank.contour_of(act)}):
					contours[act] = pts.duplicate(true)
	var out := {"axes": axes, "brake": brake, "shape": String(_shape.get_item_metadata(_shape.selected)), "acts": acts,
		"contours": contours, "emph": _emph.selected}
	# a rest given in seconds is kept as it was given (its designer's, or the terms'): no control here moves it
	if _spec.get("secs") is Dictionary and not (_spec["secs"] as Dictionary).is_empty():
		out["secs"] = (_spec["secs"] as Dictionary).duplicate()
	return out


## A hand's change: the controls as they stand made the note's version ([method DeliveryVersions.set_hand]) and said from now on.
func _edited() -> void:
	if _syncing:
		return
	var spec := spec_now()
	var dir := section.cast.delivery_folder(delivery)
	if DeliveryVersions.set_hand(dir, spec) < 0:
		_say("This session cannot keep the note's versions: the change is shown, not kept.")
		return
	_spec = spec
	section._entry(delivery)["tuned"] = true
	section._settle(delivery)
	_syncing = true
	_fill_versions("tuned")
	_syncing = false
	_say("")


## A designer's or a picked version made the one the note says: the controls follow.
func put(spec: Dictionary, note: String, by: String) -> String:
	var dir := section.cast.delivery_folder(delivery)
	if DeliveryVersions.add(dir, spec, note, by) < 0:
		return "this session cannot keep the note's versions"
	section._entry(delivery)["tuned"] = true
	section._settle(delivery)
	if visible:
		load_spec()
	return ""


func _version_picked(i: int) -> void:
	if _syncing:
		return
	var v := int(_version.get_item_metadata(i))
	if v < 0:
		return
	_say(section.act(delivery, "version:%d" % v))
	load_spec()


func _as_it_comes() -> void:
	_say(section.act(delivery, "stock"))
	load_spec()


func _keep() -> void:
	var about_ := String((section.cast.deliveries.get(delivery, {}) as Dictionary).get("about", ""))
	var err := DeliveryLibrary.keep(delivery, spec_now(), about_ if not about_.is_empty() else DeliveryBank.blurb_of(delivery), _last_wav)
	if not err.is_empty():
		_say("Not kept: " + err)
		return
	# kept as it stands: the note follows the library now, its versions kept beside it
	section._entry(delivery).erase("tuned")
	section._settle(delivery)
	load_spec()
	_say("Kept in your library as \"%s\": every note that says it says it this way, unless it tunes its own." % delivery)


func _renamed() -> void:
	var n := _name_edit.text.strip_edges()
	if n == delivery or n.is_empty():
		_name_edit.text = delivery
		return
	var err := section.rename_own(delivery, n)
	if not err.is_empty():
		_say(err)
		_name_edit.text = delivery
		return
	delivery = DeliveryLibrary.clean_name(n)
	load_spec()
	_say("Renamed: the script says it as [words]{%s}." % delivery)


# --- hearing it ----------------------------------------------------------------------------------------------------


func _play(which: String) -> void:
	var panel := section.cast.panel
	if _playing == which and panel.testing():
		panel.stop_testing()
		_playing = ""
		return
	var text := passage() if which == "said" else DeliveryHearing.plain_of(passage())
	var plan := ReadingPlan.make(text, "", panel._plan_ask(text))
	if (plan["chunks"] as Array).is_empty():
		_say("There are no words to say.")
		return
	panel.audition_chunks(plan["chunks"], _voice_name())
	_playing = which if panel.testing() else ""
	if _playing.is_empty():
		_say("The voice is not ready yet.")


func _measure() -> void:
	if _hearing != null:
		return
	_hearing = DeliveryHearing.new()
	_hear_b.disabled = true
	_say("Saying it both ways…")
	var got: Dictionary = await _hearing.hear(section.cast.panel, _voice_name(), passage())
	_hearing = null
	if not is_instance_valid(self):
		return
	_hear_b.disabled = false
	if got.has("error"):
		_say("Not measured: " + String(got["error"]))
		return
	_last_wav = String((got["wavs"] as Array)[0]) if not (got["wavs"] as Array).is_empty() else ""
	_heard.text = String(got["text"])
	_heard.visible = true
	_say("")


func _open_refine() -> void:
	var d := DeliveryDesign.at(section.cast.delivery_folder(delivery), delivery)
	var me: WeakRef = weakref(self)
	d.name = delivery
	d.title = section.cast.panel.note_path.get_file().get_basename()
	d.spec_of = func() -> Dictionary:
		var lab: DeliveryLab = me.get_ref()
		return lab.spec_now() if lab != null else {}
	d.put = func(spec: Dictionary, note: String, by: String) -> String:
		var lab: DeliveryLab = me.get_ref()
		return lab.put(spec, note, by) if lab != null else "the Lab was closed"
	d.words_of = func() -> String:
		var lab: DeliveryLab = me.get_ref()
		return lab._words.text if lab != null else ""
	d.hearer = func(words: String, draft: Dictionary) -> Dictionary:
		var lab: DeliveryLab = me.get_ref()
		if lab == null:
			return {"error": "the Lab was closed"}
		return await DeliveryHearing.new().hear(lab.section.cast.panel, lab._voice_name(), DeliveryHearing.passage_of(lab.delivery, words), draft)
	if _refine == null or not is_instance_valid(_refine):
		_refine = TextRefine.new(d.chat, "the delivery \"%s\"" % delivery)
		add_child(_refine)
	_refine.toggle(self, _refine_btn)


func _say(t: String) -> void:
	_status.text = t
	_status.visible = not t.is_empty()
