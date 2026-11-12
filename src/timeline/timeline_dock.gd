extends CanvasLayer
class_name TimelineDock

## TimelineDock - any show's [Timeline], docked under it, on Masking's controls (next/editing.md, "The
## Timeline" and step 6): the show's groups as flags on one [FlagStrip] across the whole of it (an
## episode's beats; picked by a flag's handle, or by scrubbing to a moment inside one), and the group
## picked on [TimelineLanes] below - its spans blocks, its flags flags, each labeled with what it is and
## who it happens to. What is wrong with the timeline ([method Timeline.check]) is said over it.
##
## Written back by its owner ([member edit]): a block stretched or a flag moved is handed back as the
## item it is, with its `source`, and whoever read the Timeline writes it where it lives and hands the
## Timeline back ([method reload]). With no [member edit] it is read-only.
##
## One thing picked, one inspector: a block or a flag picked on the lanes - or anything its owner hands
## [method inspect], a thing picked on the stage - is shown at the right, and the owner fills it
## ([member inspector]): it knows what the item's `source` is, and the dock knows only that it was
## picked. Undo takes the last edit back ([member undo]). The storyboard's editor writes its own tree
## with the same lanes, strip and form; the episode's dock reads its show's files.

## The dock's name among the shell's claims on the bottom and the stage.
const CLAIM := &"timeline_dock"
## Every timeline editor open, this dock and the storyboard's ([StoryboardEditor]): what the transport
## steps its rail aside for, and what the panel's Timeline card lists ([TimelineList]). A member answers
## `timeline_items()` and `pick_item(i)`.
const GROUP := Transport.EDITORS
const HEIGHT := 300.0
const MARGIN := 12.0
const INSPECTOR_W := 360.0

## The dock was closed.
signal closed
## A moment of the show was asked for (the strip scrubbed): [param t] show seconds.
signal sought(t: float)

## The Timeline shown.
var timeline: Dictionary = {}
## Its heading.
var title := "Timeline"
## The group picked, -1 for none.
var picked := -1
## Where the show is, in its seconds; -1 for nowhere.
var playhead := -1.0
## (item: Dictionary, from: float, to: float) -> String: item of the group picked moved to [from, to] (group seconds), "" if
## written; invalid, the dock is read-only.
var edit: Callable = Callable()
## (what: Dictionary, box: VBoxContainer) -> void: the owner fills the inspector for what is picked - `{item, group}` for a block or
## flag picked on the lanes, or what [method inspect] was handed. Invalid, the inspector says only what an item is.
var inspector: Callable = Callable()
## () -> String: the last edit made from here taken back, "" when it was, else why not. Invalid, there is no Undo.
var undo: Callable = Callable()
## What the inspector shows, {} for nothing.
var inspected := {}
## () -> float: where the show is, in the timeline's seconds (-1 for nowhere) - the transport's own position unless its owner says
## otherwise (an episode's timeline begins at its first word, the show's after the intro).
var clock: Callable = func() -> float: return Spectrum.scrub_position() if Spectrum.timed() else -1.0
## (t: float) -> void: the show moved to [param t] seconds of the timeline - the strip scrubbed, a row of the Timeline card pressed.
var seek: Callable = func(t: float) -> void: Spectrum.seek(t)

var _root: PanelContainer
var _summary: Label
var _problems: Label
var _view := TimelineView.new()
var _groups: FlagStrip
var _flags: Array = []
var _group_label: Label
var _lanes: TimelineLanes
var _items: Array = []        # the group picked's items, in the order its lanes' spans are
var _inspector: VBoxContainer
var _undo_b: Button
var _said: Label


func _ready() -> void:
	layer = 110
	add_to_group(GROUP)
	_build()
	_place()
	get_viewport().size_changed.connect(_place)


func _process(_delta: float) -> void:
	# The panel beside it hides and shows (F2): followed, as the storyboard's editor follows it
	if Engine.get_process_frames() % 10 == 0:
		_place()
	# The playhead, the show's own: on the strip across the show, and on the lanes inside the group picked - which follows the show while it plays
	var t := float(clock.call()) if clock.is_valid() else -1.0
	if absf(t - playhead) < 0.001:
		return
	playhead = t
	if t >= 0.0 and Spectrum.transport_playing():
		var g := group_at(t)
		if g >= 0 and g != picked:
			pick(g)
	if _lanes != null:
		var groups: Array = timeline.get("groups", [])
		var local := -1.0
		if picked >= 0 and picked < groups.size() and t >= 0.0:
			var gd: Dictionary = groups[picked]
			local = t - float(gd["start"])
			if local < 0.0 or local > float(gd["length"]):
				local = -1.0
		_lanes.playhead = local
		_lanes.queue_redraw()
	if _groups != null:
		_groups.queue_redraw()


## Every item in the order it comes ([TimelineList]): each group, then its items - `{label, at (seconds of the timeline), kind
## ("group", "span" or "flag"), group, item}`.
func timeline_items() -> Array:
	var out: Array = []
	var groups: Array = timeline.get("groups", [])
	for gi in groups.size():
		var g: Dictionary = groups[gi]
		out.append({"label": String(g["label"]), "at": float(g["start"]), "kind": "group", "group": gi})
		var its: Array = []
		for l in g["lanes"]:
			for it in (l as Dictionary)["items"]:
				its.append(it)
		its.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["at"]) < float(b["at"]))
		for it in its:
			out.append({"label": String((it as Dictionary).get("label", "")), "at": float(g["start"]) + float((it as Dictionary)["at"]),
				"kind": String((it as Dictionary)["kind"]), "group": gi, "item": it})
	return out


## Row [param i] of [method timeline_items] pressed: its group picked, it shown in the inspector, and the show moved to it.
func pick_item(i: int) -> void:
	var all := timeline_items()
	if i < 0 or i >= all.size():
		return
	var e: Dictionary = all[i]
	if int(e["group"]) != picked:
		pick(int(e["group"]))
	if e.has("item"):
		inspect({"item": e["item"], "group": int(e["group"])})
	if seek.is_valid():
		seek.call(float(e["at"]))


func _exit_tree() -> void:
	var ch := Shell.of(self)
	if ch != null:
		ch.release_bottom(CLAIM)
		ch.release_stage(CLAIM)


## Show [param tl], called [param heading]: its first group picked.
func open(tl: Dictionary, heading := "Timeline") -> void:
	timeline = tl
	title = heading
	picked = 0 if not (tl.get("groups", []) as Array).is_empty() else -1
	inspected = {}
	if _root != null:
		_refresh()
		_show_inspector()


func _build() -> void:
	_root = PanelContainer.new()
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.07, 0.08, 0.1, 0.96)
	bg.set_corner_radius_all(6)
	bg.set_content_margin_all(8)
	_root.add_theme_stylebox_override("panel", bg)
	add_child(_root)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	_root.add_child(box)
	var bar := HBoxContainer.new()
	box.add_child(bar)
	var head := Label.new()
	head.name = "Title"
	head.add_theme_font_size_override("font_size", 14)
	bar.add_child(head)
	_summary = Label.new()
	_summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_summary.add_theme_font_size_override("font_size", 12)
	_summary.modulate = Color(1, 1, 1, 0.6)
	_summary.clip_text = true
	bar.add_child(_summary)
	_undo_b = Button.new()
	_undo_b.text = "Undo"
	_undo_b.flat = true
	_undo_b.focus_mode = Control.FOCUS_NONE
	_undo_b.tooltip_text = "Take the last change made here back: what it replaced is put back, and the change kept a version back (Ctrl+Z)."
	_undo_b.pressed.connect(func() -> void: take_back())
	bar.add_child(_undo_b)
	var close := Button.new()
	close.text = "×"
	close.flat = true
	close.tooltip_text = "Close the timeline. It is read from the show's own files, and nothing here changes them."
	close.pressed.connect(func() -> void: closed.emit())
	bar.add_child(close)
	_said = Label.new()
	_said.add_theme_font_size_override("font_size", 11)
	_said.modulate = Color(1.0, 0.75, 0.45)
	_said.visible = false
	box.add_child(_said)
	# The timeline at the left, what is picked at the right
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 10)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(body)
	var side := ScrollContainer.new()
	side.custom_minimum_size = Vector2(INSPECTOR_W, 0)
	side.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_inspector = VBoxContainer.new()
	_inspector.add_theme_constant_override("separation", 4)
	_inspector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side.add_child(_inspector)
	box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(box)
	body.add_child(side)
	_problems = Label.new()
	_problems.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_problems.add_theme_font_size_override("font_size", 11)
	_problems.modulate = Color(1.0, 0.75, 0.45)
	box.add_child(_problems)
	_groups = FlagStrip.new()
	_groups.tview = _view
	_groups.custom_minimum_size = Vector2(0, 56)
	_groups.get_markers = func() -> Array: return _flags
	_groups.get_extent = func() -> float: return float(timeline.get("length", 0.0))
	_groups.get_playhead = func() -> float: return playhead
	_groups.get_span = func(m: Dictionary) -> Vector2: return m["span"]
	_groups.set_time = func(_m: Dictionary, _t: float) -> void: pass
	_groups.marker_picked.connect(func(m: Dictionary) -> void: pick(int(m["group"])))
	_groups.scrubbed.connect(func(t: float) -> void:
		var g := group_at(t)
		if g >= 0 and g != picked:
			pick(g)
		sought.emit(t)
		if seek.is_valid():
			seek.call(t))
	box.add_child(_groups)
	_group_label = Label.new()
	_group_label.add_theme_font_size_override("font_size", 12)
	_group_label.modulate = Color(1, 1, 1, 0.75)
	box.add_child(_group_label)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(scroll)
	_lanes = TimelineLanes.new()
	_lanes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lanes.read_only = true
	_lanes.retimed.connect(func(span: int, from: float, to: float) -> void:
		if edit.is_valid() and span >= 0 and span < _items.size():
			edit.call(_items[span], from, to))
	_lanes.picked.connect(func(span: int) -> void:
		if span >= 0 and span < _items.size():
			inspect({"item": _items[span], "group": picked}))
	# ...and the lanes' own strip scrubbed: the show moved to that moment of the group picked
	_lanes.scrubbed.connect(func(t: float) -> void:
		var groups: Array = timeline.get("groups", [])
		if picked >= 0 and picked < groups.size() and seek.is_valid():
			seek.call(float((groups[picked] as Dictionary)["start"]) + t))
	scroll.add_child(_lanes)
	_refresh()
	_show_inspector()


## [param what] shown in the inspector - `{item, group}` for an item of the timeline, or whatever the owner picks elsewhere (a
## thing on the stage) - {} for nothing.
func inspect(what: Dictionary) -> void:
	inspected = what
	_show_inspector()


func _show_inspector() -> void:
	if _inspector == null:
		return
	for c in _inspector.get_children():
		_inspector.remove_child(c)
		c.queue_free()
	if inspected.is_empty():
		var hint := Label.new()
		hint.text = "Pick a block or a flag to see it here." + (" Click something on the stage to pick it." if inspector.is_valid() else "")
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hint.add_theme_font_size_override("font_size", 12)
		hint.modulate = Color(1, 1, 1, 0.55)
		_inspector.add_child(hint)
		return
	if inspector.is_valid():
		inspector.call(inspected, _inspector)
		return
	var it: Dictionary = inspected.get("item", {}) if inspected.get("item") is Dictionary else {}
	var l := Label.new()
	l.text = "%s\n%s at %s%s" % [String(it.get("label", "?")), String(it.get("kind", "")), Clock.text(float(it.get("at", 0.0))),
		(", %s long" % Clock.text(float(it.get("length", 0.0)))) if String(it.get("kind", "")) == "span" else ""]
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_inspector.add_child(l)


## Undo: the owner takes the last edit back ([member undo]); what it said, when it could not, over the timeline.
func take_back() -> String:
	if not undo.is_valid():
		return "nothing here can be taken back"
	var err := String(undo.call())
	say(("Not taken back: " + err) if not err.is_empty() else "")
	return err


## A line over the timeline ("" clears it): what an edit or a pick said.
func say(text: String) -> void:
	if _said == null:
		return
	_said.text = text
	_said.visible = not text.is_empty()


func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo or k.keycode != KEY_Z or not k.ctrl_pressed or not undo.is_valid() or _root == null:
		return
	# only with the pointer over the dock: Ctrl+Z means other things everywhere else
	if _root.get_global_rect().has_point(_root.get_global_mouse_position()):
		take_back()
		get_viewport().set_input_as_handled()


## [param tl] again, as its owner wrote it: the group picked stays picked.
func reload(tl: Dictionary) -> void:
	timeline = tl
	picked = clampi(picked, -1, (tl.get("groups", []) as Array).size() - 1)
	_refresh()
	_show_inspector()


## Group [param i] picked: its items on the lanes.
func pick(i: int) -> void:
	picked = i
	_refresh()


## The group under [param t] show seconds, -1 for none.
func group_at(t: float) -> int:
	var groups: Array = timeline.get("groups", [])
	for i in groups.size():
		var g: Dictionary = groups[i]
		if t >= float(g["start"]) and t < float(g["start"]) + float(g["length"]):
			return i
	return -1


## The group picked as a stage entry's track, so [TimelineLanes] shows it as it shows one: a span `from`/`to`, a flag `at`,
## each its item's label and aimed at its lane. -> {actors, spans, nominal}.
static func as_track(g: Dictionary) -> Dictionary:
	var actors: Array = []
	var spans: Array = []
	for l in g.get("lanes", []):
		var lane := String((l as Dictionary)["id"])
		var who := lane if not lane.is_empty() else "all"
		if not actors.has(who):
			actors.append(who)
		for it in (l as Dictionary)["items"]:
			var d: Dictionary = it
			var s := {"action": String(d.get("label", "")), "target": who}
			if String(d["kind"]) == "flag":
				s["at"] = float(d["at"])
			else:
				s["from"] = float(d["at"])
				s["to"] = float(d["at"]) + float(d["length"])
			spans.append(s)
	return {"actors": actors, "spans": spans, "nominal": maxf(0.05, float(g.get("length", 0.0)))}


func _refresh() -> void:
	if _root == null:
		return
	(_root.find_child("Title", true, false) as Label).text = title
	_undo_b.visible = undo.is_valid()
	var groups: Array = timeline.get("groups", [])
	var items := 0
	_flags = []
	for i in groups.size():
		var g: Dictionary = groups[i]
		for l in g["lanes"]:
			items += ((l as Dictionary)["items"] as Array).size()
		_flags.append({"time": float(g["start"]), "kind": 1, "label": String(g["label"]), "group": i,
			"span": Vector2(float(g["start"]), float(g["start"]) + float(g["length"]))})
	_view.refresh(float(timeline.get("length", 1.0)))
	_summary.text = "%d %s · %s · %d items · %s" % [groups.size(), "group" if groups.size() == 1 else "groups",
		Clock.text(float(timeline.get("length", 0.0))), items, Timeline.label_of(Timeline.CLOCKS, String(timeline.get("clock", "seconds")))]
	var wrong := Timeline.check(timeline)
	# ...and what its reader found wrong in what it says (an episode's cue naming nothing)
	wrong.append_array(PackedStringArray(timeline.get("problems", [])))
	_problems.text = "⚠ " + "; ".join(wrong) if not wrong.is_empty() else ""
	_problems.visible = not wrong.is_empty()
	_groups.selected = _flags[picked] if picked >= 0 and picked < _flags.size() else null
	if picked >= 0 and picked < groups.size():
		var g: Dictionary = groups[picked]
		var tr := as_track(g)
		_items = []
		for l in g["lanes"]:
			_items.append_array((l as Dictionary)["items"])
		_lanes.read_only = not edit.is_valid()
		_lanes.set_track(tr["actors"], tr["spans"], float(tr["nominal"]))
		_group_label.text = "%s - %s from %s, %d lanes" % [String(g["label"]), Clock.text(float(g["length"])),
			Clock.text(float(g["start"])), (g["lanes"] as Array).size()]
	else:
		_lanes.set_track([], [], 1.0)
		_group_label.text = "Nothing on this timeline yet."


## Along the bottom, beside an open panel on the left and over the transport's rail, its room claimed - as the storyboard's
## editor stands ([method StoryboardEditor._place]).
func _place() -> void:
	if _root == null or not is_inside_tree():
		return
	var vp := get_viewport().get_visible_rect().size
	var left := MARGIN
	for n in get_tree().get_nodes_in_group(SidePanel.GROUP):
		var c := n as Control
		if c != null and c.is_visible_in_tree() and c.get_global_rect().position.x < vp.x * 0.5:
			left = maxf(left, c.get_global_rect().end.x + 12.0)
	var h := minf(HEIGHT, vp.y * 0.55)
	var bottom := Transport.room() + 6.0
	_root.position = Vector2(left, vp.y - bottom - h)
	_root.size = Vector2(maxf(480.0, vp.x - left - MARGIN), h)
	var ch := Shell.of(self)
	if ch != null:
		ch.claim_bottom(CLAIM, bottom + h + 6.0 - Shell.ROW_MARGIN)
		ch.claim_stage(CLAIM, bottom + h + 6.0)
