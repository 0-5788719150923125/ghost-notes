extends CanvasLayer
class_name StoryboardEditor

## StoryboardEditor - the nonlinear editor of a note's storyboard: a dock along the bottom of the
## frame, under the show it edits. Opened from the [StoryboardCard] ("Timeline…").
##
## THREE VIEWS OF ONE TREE. The STRIP ([StoryboardStrip]) is the story: its entries along a
## ruler, in the order and for the lengths the Director will walk them, the tail after the
## sequence. The LANES ([StoryboardLanes]) open under it for a stage entry: a lane per actor, and
## on it what happens to that actor, when. The INSPECTOR, at the right, is whatever is picked -
## an entry, one of its actors, one of its spans - as rows built from the fields' own tables
## ([SchemaForm] over [constant Storyboard.ENTRY], [constant Cast.PARAMS], [constant Actions.ARGS]
## ...), so nothing here lists what a scene, an actor or a verb can be told.
##
## EVERY EDIT IS A NEW TREE ([DataPath]): the editor never changes the storyboard it was handed,
## it raises [signal edited] with the next one. So UNDO IS THE LIST OF TREES IT HAS SHOWN - nothing
## records what an edit did or how to reverse it, and a kind of edit added later is undone the day
## it is written. The card that owns the storyboard keeps it in the note and hands it to the show.
##
## WHAT IS WRITTEN IS WHAT IS SHOWN. The tree is the RAW one, `defs` and `use` in it: a map that
## uses a def shows the def's values dimmed, as it shows any default, and a value changed there is
## written into the map itself, over the def - the rule `use` has always had. SOURCE shows the
## whole tree as YAML, and takes it back if it still loads ([method Storyboard.from_yaml]): every
## key the spec has is reachable from the first day, whatever the rows above have learned to draw.
##
## A STORYBOARD NOBODY CAN CHANGE HERE IS STILL SHOWN ([member read_only]): one read from a file,
## and the seeded show itself, written down as far ahead as asked ([method Director.forecast]) -
## the same strip, grayed, so what "automatic" is going to play is a storyboard on the screen.

## The storyboard was edited: the new raw tree.
signal edited(data: Dictionary)
## An entry was picked: its index, the tail's counted on from the sequence's end.
signal picked(entry: int)
## The dock was closed.
signal closed

const HEIGHT := 348.0
const INSPECTOR_W := 372.0
const MARGIN := 16.0
const CLAIM := &"storyboard"
## How many trees back an undo can go.
const HISTORY := 100
## A new moment's verb: one every kind of actor answers to.
const NEW_VERB := "flash"

## The raw tree shown.
var data := {}
var read_only := false
## Shown under the toolbar when the tree cannot be changed here: why, and what to do about it.
var banner := ""
## The entries are a forecast, not a storyboard: drawn grayed.
var ghost := false

var _sel := -1                     # the entry picked (the tail's counted on), -1 for none
var _sub := "entry"                # what of it the inspector shows: "entry" | "actor" | "span"
var _sub_i := -1
var _undo: Array = []
var _redo: Array = []
var _play_entry := -1
var _play_elapsed := 0.0

var _root: PanelContainer
var _body: HBoxContainer
var _strip: StoryboardStrip
var _lanes: StoryboardLanes
var _lanes_scroll: ScrollContainer
var _lanes_hint: Label
var _inspector: VBoxContainer
var _banner: Label
var _summary: Label
var _source: CodeEdit
var _source_box: VBoxContainer
var _source_note: Label
var _source_on := false
var _buttons := {}                 # name -> Button, for graying
var _add_scene: MenuButton
var _refreshing := false           # the views are being rebuilt now
var _refresh_again := false        # ...and an edit landed meanwhile: once more when it is done


func _ready() -> void:
	# over the stage and the subtitles, under the transport (120) and everything modal
	layer = 110
	_build()
	_place()
	get_viewport().size_changed.connect(_place)
	_refresh()


func _exit_tree() -> void:
	var ch := Shell.of(self)
	if ch != null:
		ch.release_bottom(CLAIM)
		ch.release_stage(CLAIM)


## Show [param p_data]. [param p_read_only] with [param p_banner] for one that cannot be changed
## here; [param p_ghost] for the seeded show written down. The history starts again.
func open(p_data: Dictionary, p_read_only := false, p_banner := "", p_ghost := false) -> void:
	data = p_data
	read_only = p_read_only
	banner = p_banner
	ghost = p_ghost
	_undo.clear()
	_redo.clear()
	_sel = clampi(_sel, -1, _count() - 1)
	_sub = "entry"
	_sub_i = -1
	if is_inside_tree():
		_refresh()


## The storyboard was changed somewhere else (the card, a file edited outside): show it, with the
## one before it a step back.
func replace(p_data: Dictionary) -> void:
	if DataPath.same(p_data, data):
		return
	_undo.append(data)
	_redo.clear()
	data = p_data
	_sel = clampi(_sel, -1, _count() - 1)
	_refresh()


## Where the show is: the entry on screen and the seconds it has been up (-1 for none).
func set_cursor(entry: int, elapsed: float) -> void:
	_play_entry = entry
	_play_elapsed = elapsed
	if _strip == null:
		return
	_strip.play_entry = entry
	_strip.play_elapsed = elapsed
	_strip.queue_redraw()
	if _lanes.visible:
		var rows := _strip.rows
		var on := entry == _sel and entry >= 0 and entry < rows.size()
		_lanes.playhead = elapsed / maxf(0.05, float(rows[entry]["length"])) * _lanes.nominal if on else -1.0
		_lanes.queue_redraw()


## The entry picked, -1 for none.
func selected() -> int:
	return _sel


## Every scene an entry can name: the stage first, then the catalog, each once.
static func scene_names() -> Array:
	var out: Array = []
	for e in SceneRoster.SCENES:
		var n := String((e as Dictionary).script.resource_path).get_file().get_basename()
		if not out.has(n):
			out.append(n)
	out.sort()
	out.erase("stage")
	out.push_front("stage")
	return out


# --- the tree ------------------------------------------------------------------------------------

func _seq() -> Array:
	var s: Variant = data.get("sequence")
	return s as Array if s is Array else []


func _tail() -> Array:
	var t: Variant = data.get("tail")
	return t as Array if t is Array else []


func _count() -> int:
	return _seq().size() + _tail().size()


## Where entry [param i] is written: in the sequence, or the tail counted on from its end.
func _path(i: int) -> Array:
	var n := _seq().size()
	return ["sequence", i] if i < n else ["tail", i - n]


func _entry(i: int) -> Dictionary:
	var e: Variant = DataPath.at(data, _path(i))
	return e as Dictionary if e is Dictionary else {}


## The map at [param path] as it is once loaded - its `use` expanded.
func _resolved(path: Array) -> Dictionary:
	var raw: Variant = DataPath.at(data, path)
	var out: Variant = Storyboard.expanded(raw if raw is Dictionary else {}, data.get("defs", {}))
	return out as Dictionary if out is Dictionary else {}


## The strip's rows: each entry's name, where it starts and how long it is scheduled for
## ([method Storyboard.schedule], over the entries as they load).
func _rows() -> Array:
	var sens := float(data.get("sensitivity", Director.sensitivity))
	var hold := Director.unauthored_hold()
	var defs: Variant = data.get("defs", {})
	var rows: Array = []
	var acc := 0.0
	for list in [[_seq(), false], [_tail(), true]]:
		for raw in (list[0] as Array):
			var e: Variant = Storyboard.expanded(raw, defs)
			var entry: Dictionary = e if e is Dictionary else {}
			var length := Storyboard.entry_length(entry, sens, hold)
			rows.append({"name": String(entry.get("scene", "?")), "start": acc, "length": length,
				"timing": Storyboard.timing_of(entry), "tail": bool(list[1]),
				"stage": String(entry.get("scene", "")) == "stage", "ghost": ghost,
				"sens": clampf(float(entry.get("sensitivity", sens)), 0.05, 20.0)})
			acc += length
	return rows


## Make an edit: [param next] is the tree from here on, and the one before it a step back.
func _edit(next: Variant) -> void:
	if read_only or not (next is Dictionary) or DataPath.same(next, data):
		return
	_undo.append(data)
	if _undo.size() > HISTORY:
		_undo.pop_front()
	_redo.clear()
	data = next
	_sel = clampi(_sel, -1, _count() - 1)
	_refresh()
	edited.emit(data)


## Write [param value] at [param path]; null unsets it.
func _write(path: Array, value: Variant) -> void:
	_edit(DataPath.cut(data, path) if value == null else DataPath.put(data, path, value))


func undo() -> void:
	if _undo.is_empty() or read_only:
		return
	_redo.append(data)
	data = _undo.pop_back()
	_after_history()


func redo() -> void:
	if _redo.is_empty() or read_only:
		return
	_undo.append(data)
	data = _redo.pop_back()
	_after_history()


func _after_history() -> void:
	_sel = clampi(_sel, -1, _count() - 1)
	_sub = "entry"
	_sub_i = -1
	_refresh()
	edited.emit(data)


## Pick entry [param i]; -1 picks none, and the inspector shows the storyboard's own fields.
func _pick(i: int) -> void:
	var same := i == _sel
	_sel = clampi(i, -1, _count() - 1)
	if not same:
		_sub = "entry"
		_sub_i = -1
	_refresh()
	if _sel >= 0:
		picked.emit(_sel)


# --- the entries ---------------------------------------------------------------------------------

## A new entry of [param scene], after the one picked (at the end of the sequence when none is).
func add_entry(scene: String) -> void:
	if ghost:
		# the seeded show was only being shown: the first entry added starts the note's own
		data = {"sequence": []}
		ghost = false
		read_only = false
		banner = ""
		_sel = -1
	if read_only:
		return
	var n := _seq().size()
	var in_tail := _sel >= n
	var at := (_sel - n + 1) if in_tail else (_sel + 1 if _sel >= 0 else n)
	var next: Variant = DataPath.insert(data, ["tail"] if in_tail else ["sequence"], at, Storyboard.new_entry(scene))
	_sel = (n + at) if in_tail else at
	_sub = "entry"
	_sub_i = -1
	_edit(next)
	if _sel >= 0:
		picked.emit(_sel)


func remove_entry() -> void:
	if _sel < 0:
		return
	var next: Variant = DataPath.cut(data, _path(_sel))
	_sub = "entry"
	_sub_i = -1
	_edit(next)


func duplicate_entry() -> void:
	if _sel < 0:
		return
	var p := _path(_sel)
	var next: Variant = DataPath.insert(data, [p[0]], int(p[1]) + 1, _entry(_sel))
	_sel += 1
	_edit(next)


## Move the entry picked [param by] places along its own list.
func shift_entry(by: int) -> void:
	if _sel < 0:
		return
	_move(_sel, _sel + by)


func _move(from: int, to: int) -> void:
	var n := _seq().size()
	var a := _path(from)
	var size := _tail().size() if from >= n else n
	var base := n if from >= n else 0
	var dest := clampi(to - base, 0, size - 1)
	if dest == int(a[1]):
		return
	_sel = base + dest
	_edit(DataPath.move(data, [a[0]], int(a[1]), dest))


## An entry's block was dragged to [param length] scheduled seconds: its fixed hold, rewritten.
func _resize(i: int, length: float) -> void:
	var rows := _strip.rows
	if i < 0 or i >= rows.size():
		return
	# the block is drawn at its scheduled length, which is the hold over the entry's tempo
	_write(_path(i) + ["hold"], snappedf(length * float(rows[i]["sens"]), 0.1))


# --- a stage entry's cast and timeline --------------------------------------------------------------

func _cast_ids(i: int) -> Array:
	var out: Array = []
	var cast: Variant = _resolved(_path(i)).get("cast")
	for a in (cast as Array if cast is Array else []):
		if a is Dictionary:
			out.append(String((a as Dictionary).get("id", "")))
	return out


func _spans(i: int) -> Array:
	var track: Variant = _resolved(_path(i)).get("track")
	var spans: Variant = (track as Dictionary).get("spans") if track is Dictionary else null
	return spans as Array if spans is Array else []


func _nominal(i: int) -> float:
	var track: Variant = _resolved(_path(i)).get("track")
	return float((track as Dictionary).get("nominal", 8.0)) if track is Dictionary else 8.0


func add_actor(kind: String) -> void:
	if _sel < 0:
		return
	var ids := _cast_ids(_sel)
	var id := kind
	var k := 2
	while ids.has(id):
		id = "%s%d" % [kind, k]
		k += 1
	var p := _path(_sel) + ["cast"]
	_sub = "actor"
	_sub_i = ids.size()
	_edit(DataPath.insert(data, p, ids.size(), {"id": id, "kind": kind, "at": [0, 0, 0]}))


## A new span at [param at] nominal seconds for [param actor] ("" is everyone).
func add_span(verb: String, actor: String, at: float) -> void:
	if _sel < 0:
		return
	var span := {"at": snappedf(clampf(at, 0.0, _nominal(_sel)), 0.05), "action": verb}
	if not actor.is_empty():
		span["target"] = actor
	var p := _path(_sel) + ["track", "spans"]
	var n := _spans(_sel).size()
	var next: Variant = data
	if not DataPath.has(data, _path(_sel) + ["track", "nominal"]):
		next = DataPath.put(next, _path(_sel) + ["track", "nominal"], _nominal(_sel))
	_sub = "span"
	_sub_i = n
	_edit(DataPath.insert(next, p, n, span))


func _retime(span: int, from: float, to: float) -> void:
	var p := _path(_sel) + ["track", "spans", span]
	var raw: Variant = DataPath.at(data, p)
	if not (raw is Dictionary):
		return
	var s: Dictionary = (raw as Dictionary).duplicate(true)
	if s.has("from"):
		s["from"] = from
		s["to"] = to
	else:
		s["at"] = from
	_edit(DataPath.put(data, p, s))


## A span as a moment or as a window: the other's keys dropped, its own filled from what it had.
func _span_as(span: int, window: bool) -> void:
	var p := _path(_sel) + ["track", "spans", span]
	var raw: Variant = DataPath.at(data, p)
	if not (raw is Dictionary):
		return
	var s: Dictionary = (raw as Dictionary).duplicate(true)
	var w := StoryboardLanes.window_of(s)
	s.erase("at")
	s.erase("from")
	s.erase("to")
	if window:
		s["from"] = float(w[0])
		s["to"] = minf(_nominal(_sel), maxf(float(w[1]), float(w[0]) + 1.0))
	else:
		s["at"] = float(w[0])
	_edit(DataPath.put(data, p, s))


## The actor at [param index] of the stage entry at [param entry] renamed [param to]: the spans
## that named it follow, so its timeline is not left aimed at nobody. Told which entry and which
## actor, never asked of the selection - a name still being typed is committed after the pick has
## moved on.
func _rename_actor(entry: Array, index: int, to: String) -> void:
	var cast: Variant = DataPath.at(data, entry + ["cast"])
	var taken: Array = []
	for a in (cast as Array if cast is Array else []):
		if a is Dictionary:
			taken.append(String((a as Dictionary).get("id", "")))
	if not (cast is Array) or index < 0 or index >= (cast as Array).size() or to.is_empty() or taken.has(to):
		_refresh()
		return
	var was := String(taken[index])
	var next: Variant = DataPath.put(data, entry + ["cast", index, "id"], to)
	var spans: Variant = DataPath.at(next, entry + ["track", "spans"])
	var count: int = (spans as Array).size() if spans is Array else 0
	for j in count:
		var sp: Variant = (spans as Array)[j]
		if not (sp is Dictionary) or not (sp as Dictionary).has("target"):
			continue
		var t: Variant = (sp as Dictionary)["target"]
		var tp := entry + ["track", "spans", j, "target"]
		if t is Array:
			var ids: Array = (t as Array).duplicate()
			for n in ids.size():
				if String(ids[n]) == was:
					ids[n] = to
			next = DataPath.put(next, tp, ids)
		elif String(t) == was:
			next = DataPath.put(next, tp, to)
	_edit(next)


# --- building -------------------------------------------------------------------------------------

func _build() -> void:
	_root = PanelContainer.new()
	add_child(_root)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	_root.add_child(col)
	col.add_child(_toolbar())
	_banner = Label.new()
	_banner.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_banner.add_theme_font_size_override("font_size", 12)
	_banner.add_theme_color_override("font_color", Color(1.0, 0.78, 0.4))
	col.add_child(_banner)

	_body = HBoxContainer.new()
	_body.add_theme_constant_override("separation", 10)
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(_body)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 6)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_child(left)
	_strip = StoryboardStrip.new()
	_strip.picked.connect(_pick)
	_strip.moved.connect(_move)
	_strip.stretched.connect(_resize)
	left.add_child(_strip)
	_lanes_hint = Label.new()
	_lanes_hint.add_theme_font_size_override("font_size", 12)
	_lanes_hint.modulate = Color(1, 1, 1, 0.55)
	_lanes_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left.add_child(_lanes_hint)
	_lanes_scroll = ScrollContainer.new()
	_lanes_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_lanes_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(_lanes_scroll)
	_lanes = StoryboardLanes.new()
	_lanes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lanes.picked.connect(func(span: int) -> void:
		_sub = "span"
		_sub_i = span
		_refresh())
	_lanes.retimed.connect(_retime)
	_lanes.wanted.connect(func(actor: String, at: float) -> void: add_span(NEW_VERB, actor, at))
	_lanes_scroll.add_child(_lanes)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(INSPECTOR_W, 0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	_body.add_child(scroll)
	_inspector = VBoxContainer.new()
	_inspector.add_theme_constant_override("separation", 6)
	_inspector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_inspector)

	# THE SOURCE: the whole tree as YAML, in place of the rows above
	_source_box = VBoxContainer.new()
	_source_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_source_box.visible = false
	col.add_child(_source_box)
	_source = CodeEdit.new()
	_source.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_source.gutters_draw_line_numbers = true
	_source.add_theme_font_size_override("font_size", 12)
	# YAML is read by its indentation: whatever fixed-width face the system has
	var mono := SystemFont.new()
	mono.font_names = PackedStringArray(["monospace"])
	_source.add_theme_font_override("font", mono)
	_source_box.add_child(_source)
	var srow := HBoxContainer.new()
	srow.add_theme_constant_override("separation", 8)
	_source_box.add_child(srow)
	var apply := Button.new()
	apply.text = "Apply"
	apply.focus_mode = Control.FOCUS_NONE
	apply.tooltip_text = "Take this text as the storyboard, if it still makes one that loads."
	apply.pressed.connect(apply_source)
	srow.add_child(apply)
	_buttons["apply"] = apply
	_source_note = Label.new()
	_source_note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_source_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_source_note.add_theme_font_size_override("font_size", 12)
	srow.add_child(_source_note)


func _toolbar() -> HBoxContainer:
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 6)
	var title := Label.new()
	title.text = "Storyboard"
	title.add_theme_font_size_override("font_size", 14)
	bar.add_child(title)
	_add_scene = MenuButton.new()
	_add_scene.text = "+ Scene ▾"
	_add_scene.flat = false
	_add_scene.tooltip_text = ("Add an entry after the one picked. Stage is the scene made of data: who is "
		+ "on it and what they do is written in the entry. Every other scene rolls its own look from its seed.")
	var pop := _add_scene.get_popup()
	for n in scene_names():
		pop.add_item(String(n).replace("_", " "))
		pop.set_item_metadata(pop.item_count - 1, n)
		if n == "stage":
			pop.add_separator()
	pop.index_pressed.connect(func(i: int) -> void: add_entry(String(pop.get_item_metadata(i))))
	bar.add_child(_add_scene)
	_tool(bar, "dup", "Duplicate", "A copy of the entry picked, after it.", duplicate_entry)
	_tool(bar, "del", "Delete", "Remove the entry picked (Delete).", remove_entry)
	_tool(bar, "left", "◀", "Move the entry picked one place earlier.", shift_entry.bind(-1))
	_tool(bar, "right", "▶", "Move the entry picked one place later.", shift_entry.bind(1))
	_tool(bar, "undo", "↶", "Undo (Ctrl+Z)", undo)
	_tool(bar, "redo", "↷", "Redo (Ctrl+Shift+Z)", redo)
	var src := _tool(bar, "source", "Source", ("The whole storyboard as YAML: every key it has, the "
		+ "defs and the sampled ranges among them. Apply takes the text back if it still loads."), toggle_source)
	src.toggle_mode = true
	_summary = Label.new()
	_summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_summary.add_theme_font_size_override("font_size", 12)
	_summary.modulate = Color(1, 1, 1, 0.6)
	_summary.clip_text = true
	bar.add_child(_summary)
	var close := _tool(bar, "close", "×", "Close the storyboard's editor. Nothing is lost: every edit is in the note already.",
		func() -> void: closed.emit())
	close.flat = true
	return bar


func _tool(bar: Container, key: String, text: String, tip: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.tooltip_text = tip
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(action)
	bar.add_child(b)
	_buttons[key] = b
	return b


## The dock's place: along the bottom, beside an open panel on the left and over the transport's
## rail - and the room it takes is claimed, so the bottom-right row stands above it and the show
## is fitted into what is left.
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


func _process(_delta: float) -> void:
	# the panel beside it hides and shows (F2), and its width is the content's: followed, not wired
	if Engine.get_process_frames() % 10 == 0:
		_place()


func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo or read_only or _source_on:
		return
	# only with the pointer over the dock: Delete and Ctrl+Z mean other things everywhere else
	if not _root.get_global_rect().has_point(_root.get_global_mouse_position()):
		return
	if k.keycode == KEY_Z and k.ctrl_pressed:
		if k.shift_pressed:
			redo()
		else:
			undo()
		get_viewport().set_input_as_handled()
	elif k.keycode == KEY_Y and k.ctrl_pressed:
		redo()
		get_viewport().set_input_as_handled()
	elif k.keycode == KEY_DELETE and _sel >= 0:
		if _sub == "span" and _sub_i >= 0:
			_remove_sub()
		else:
			remove_entry()
		get_viewport().set_input_as_handled()


# --- the source view --------------------------------------------------------------------------------

func toggle_source() -> void:
	_source_on = not _source_on
	(_buttons["source"] as Button).set_pressed_no_signal(_source_on)
	_refresh()


## Take the source view's text as the storyboard, if it loads; say why not where it does not.
func apply_source() -> void:
	var res := Storyboard.from_yaml(_source.text)
	if not bool(res["ok"]):
		_source_note.text = "⚠  " + String(res["error"])
		_source_note.add_theme_color_override("font_color", Color(1.0, 0.6, 0.5))
		return
	_source_note.text = "✓  Applied."
	_source_note.add_theme_color_override("font_color", Color(0.55, 0.95, 0.75))
	_edit(res["data"])


# --- showing --------------------------------------------------------------------------------------

## Show the tree in all three views.
##
## A REFRESH ASKED FOR WHILE ONE IS UNDER WAY WAITS FOR IT. Rebuilding the inspector frees its
## rows, and a line of text being typed in one of them commits as it loses the tree - an edit,
## made in the middle of the rebuild that removed it. Run at once, that edit's own refresh would
## rebuild the inspector inside the loop still clearing it, and every row would be there twice.
## The edit is kept (the tree is already the new one); the views are drawn once more after.
func _refresh() -> void:
	if _strip == null:
		return
	if _refreshing:
		_refresh_again = true
		return
	_refreshing = true
	_show_all()
	_refreshing = false
	if _refresh_again:
		_refresh_again = false
		_refresh()


func _show_all() -> void:
	var rows := _rows()
	_strip.read_only = read_only
	_strip.selected = _sel
	_strip.set_rows(rows)
	_banner.text = banner
	_banner.visible = not banner.is_empty()
	var total := 0.0
	for r in rows:
		if not bool(r["tail"]):
			total += float(r["length"])
	_summary.text = "%d %s · %s%s" % [_seq().size(), "entry" if _seq().size() == 1 else "entries",
		Clock.text(total), ("  + %d in the tail" % _tail().size()) if not _tail().is_empty() else ""]
	for key in ["dup", "del", "left", "right"]:
		(_buttons[key] as Button).disabled = read_only or _sel < 0
	(_buttons["undo"] as Button).disabled = read_only or _undo.is_empty()
	(_buttons["redo"] as Button).disabled = read_only or _redo.is_empty()
	(_buttons["apply"] as Button).disabled = read_only
	_add_scene.disabled = read_only and not ghost
	_body.visible = not _source_on
	_source_box.visible = _source_on
	if _source_on:
		_source.editable = not read_only
		var text := Storyboard.to_yaml(data)
		if _source.text != text:
			_source.text = text
		return
	var stage := _sel >= 0 and String(_resolved(_path(_sel)).get("scene", "")) == "stage"
	_lanes_scroll.visible = stage
	_lanes.visible = stage
	_lanes_hint.visible = not stage
	if _sel < 0:
		_lanes_hint.text = ("Nothing is written here yet: + Scene adds the first entry." if rows.is_empty()
			else "Pick an entry to set it. Drag one along the row to move it; drag the right edge of a fixed hold to make it longer.")
	else:
		_lanes_hint.text = ("%s rolls its own look from its seed - pin the seed to keep one. A stage entry has a "
			+ "timeline here: who is on it, and what they do.") % String(rows[_sel]["name"]).replace("_", " ").capitalize()
	if stage:
		_lanes.read_only = read_only
		_lanes.selected = _sub_i if _sub == "span" else -1
		_lanes.set_track(_cast_ids(_sel), _spans(_sel), _nominal(_sel))
	_show_inspector()
	set_cursor(_play_entry, _play_elapsed)


func _heading(text: String, size := 13) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color(0.86, 0.9, 1.0))
	_inspector.add_child(l)
	return l


## Rows for the map at [param path], from [param schema]: what the map writes shown plainly, what
## a def it uses gives shown dimmed, as a default is. [param extra] adds a row for each key the
## map writes and the table lacks. An edit is written into the map itself, or handed to
## [param on_edit] (`(key, value) -> void`) where the caller has more to do than write it.
func _form(path: Array, schema: Dictionary, extra := false, context := {}, on_edit := Callable()) -> SchemaForm:
	var raw: Variant = DataPath.at(data, path)
	var own: Dictionary = (raw as Dictionary).duplicate(true) if raw is Dictionary else {}
	var resolved := _resolved(path)
	var table := {}
	for key in schema:
		var row: Dictionary = (schema[key] as Dictionary).duplicate()
		if not own.has(key) and resolved.has(key):
			row["default"] = resolved[key]          # a def's value: shown as what stands unless written over
		table[key] = row
	var defs: Variant = data.get("defs", {})
	if defs is Dictionary and not (defs as Dictionary).is_empty() and (own.has("use") or bool(context.get("usable", false))):
		var names: Array = [""]
		names.append_array((defs as Dictionary).keys())
		table["use"] = {"label": "Uses", "type": "enum", "options": names, "default": "",
			"blurb": "A named piece from this storyboard's defs that this starts from. Anything set here is written over it."}
	elif own.has("use"):
		table["use"] = {"label": "Uses", "type": "text", "default": "", "blurb": "A def this starts from."}
	var ctx := context.duplicate()
	ctx["extra"] = extra
	var form := SchemaForm.new()
	form.read_only = read_only
	form.show_fields(table, own, ctx)
	if on_edit.is_valid():
		form.edited.connect(on_edit)
	else:
		form.edited.connect(func(key: String, value: Variant) -> void: _write(path + [key], value))
	_inspector.add_child(form)
	return form


func _show_inspector() -> void:
	for c in _inspector.get_children():
		if c.get_parent() == _inspector:
			_inspector.remove_child(c)
		c.queue_free()
	if _sel < 0:
		_heading("The storyboard")
		_form([], Storyboard.BOARD)
		return
	var p := _path(_sel)
	var entry := _resolved(p)
	var in_tail := _sel >= _seq().size()
	_heading("%s %d · %s" % ["Tail entry" if in_tail else "Entry", (_sel - _seq().size() + 1) if in_tail else (_sel + 1),
		String(entry.get("scene", "?")).replace("_", " ")], 14)
	var ctx := {"scenes": scene_names(), "actors": _cast_ids(_sel)}
	_form(p, Storyboard.ENTRY, false, ctx, func(key: String, value: Variant) -> void:
		# a scene changed to the stage gets what a stage is made of, in the same edit
		var was: Variant = DataPath.at(data, p)
		var written: Dictionary = was if was is Dictionary else {}
		if key == "scene" and value != null and String(value) == "stage" and not written.has("cast"):
			var fresh := Storyboard.new_entry("stage")
			fresh.merge(written, true)
			fresh["scene"] = "stage"
			_edit(DataPath.put(data, p, fresh))
		else:
			_write(p + [key], value))
	_timing_rows(p, entry)
	# WHAT THE SCENE CAN BE TOLD ([method SceneRoster.fields_of]): its own settings, written into the
	# entry's `set` - a setting left unset is the seed's
	var own := SceneRoster.fields_of(String(entry.get("scene", "")))
	if not own.is_empty():
		_heading("Its settings")
		_form(p + ["set"], own)
	if String(entry.get("scene", "")) != "stage":
		return
	_form(p, Storyboard.STAGE)
	_heading("Camera")
	_form(p + ["camera"], Storyboard.CAMERA, false, {"usable": true})
	_cast_rows(p, ctx)
	_span_rows(p, ctx)


## How long the entry stays: one of three ways ([constant Storyboard.TIMINGS]), and that way's own
## numbers.
func _timing_rows(p: Array, entry: Dictionary) -> void:
	_heading("Stays")
	var timing := Storyboard.timing_of(entry)
	var pick := OptionButton.new()
	pick.fit_to_longest_item = false
	pick.focus_mode = Control.FOCUS_NONE
	pick.disabled = read_only
	for t in Storyboard.TIMINGS:
		pick.add_item(String(Storyboard.TIMINGS[t]["label"]))
		pick.set_item_metadata(pick.item_count - 1, t)
		pick.set_item_tooltip(pick.item_count - 1, String(Storyboard.TIMINGS[t]["blurb"]))
		if t == timing:
			pick.select(pick.item_count - 1)
	pick.tooltip_text = String(Storyboard.TIMINGS[timing]["blurb"])
	pick.item_selected.connect(func(i: int) -> void:
		var was: Variant = DataPath.at(data, p)
		_edit(DataPath.put(data, p, Storyboard.with_timing(was if was is Dictionary else {},
			String(pick.get_item_metadata(i))))))
	_inspector.add_child(pick)
	var table := {}
	for k in (Storyboard.TIMINGS[timing]["keys"] as Array):
		table[k] = Storyboard.TIMING_FIELDS[k]
	_form(p, table)


func _cast_rows(p: Array, ctx: Dictionary) -> void:
	_heading("Cast")
	var ids := _cast_ids(_sel)
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 4)
	_inspector.add_child(row)
	for j in ids.size():
		var b := Button.new()
		b.text = String(ids[j])
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		b.button_pressed = _sub == "actor" and _sub_i == j
		b.pressed.connect(func() -> void:
			_sub = "actor"
			_sub_i = j
			_refresh())
		row.add_child(b)
	var add := MenuButton.new()
	add.text = "+ Actor ▾"
	add.flat = false
	add.disabled = read_only
	add.tooltip_text = "Put another actor on this stage."
	for kind in Cast.REGISTRY:
		add.get_popup().add_item(String(kind))
	add.get_popup().index_pressed.connect(func(i: int) -> void: add_actor(add.get_popup().get_item_text(i)))
	row.add_child(add)
	if _sub != "actor" or _sub_i < 0 or _sub_i >= ids.size():
		return
	var at := _sub_i
	var ap := p + ["cast", at]
	var actor := _resolved(ap)
	var kind := String(actor.get("kind", ""))
	# what every actor has, then what its kind can be told, then anything else written for it
	var table := Storyboard.ACTOR.duplicate()
	table.merge(Cast.PARAMS.get(kind, {}) as Dictionary)
	_form(ap, table, true, ctx, func(key: String, value: Variant) -> void:
		# a name is how the timeline finds its actor: the spans aimed at the old one follow it
		if key == "id":
			_rename_actor(p, at, String(value) if value != null else "")
		else:
			_write(ap + [key], value))
	var rm := Button.new()
	rm.text = "Remove %s" % String(ids[_sub_i])
	rm.focus_mode = Control.FOCUS_NONE
	rm.disabled = read_only
	rm.pressed.connect(_remove_sub)
	_inspector.add_child(rm)


func _span_rows(p: Array, ctx: Dictionary) -> void:
	_heading("Timeline")
	var track := {"nominal": {"label": "Written at", "type": "float", "min": 0.5, "max": 600.0, "step": 0.5, "default": 8.0,
		"blurb": "The length this timeline is written at, in seconds. Its times are seconds of this, and stretch as one piece to however long the entry stays."}}
	_form(p + ["track"], track, false, {"usable": true})
	var add := MenuButton.new()
	add.text = "+ Span ▾"
	add.flat = false
	add.disabled = read_only
	add.tooltip_text = "Add something that happens: a moment at the playhead, for everyone. Double-click a lane to add one there."
	for verb in Actions.REGISTRY:
		add.get_popup().add_item(String(verb).replace("_", " "))
		add.get_popup().set_item_metadata(add.get_popup().item_count - 1, verb)
	add.get_popup().index_pressed.connect(func(i: int) -> void:
		add_span(String(add.get_popup().get_item_metadata(i)), "", maxf(0.0, _lanes.playhead)))
	_inspector.add_child(add)
	var spans := _spans(_sel)
	if _sub != "span" or _sub_i < 0 or _sub_i >= spans.size():
		return
	var sp := p + ["track", "spans", _sub_i]
	var span := _resolved(sp)
	_heading("Span %d · %s" % [_sub_i + 1, String(span.get("action", "?")).replace("_", " ")])
	_form(sp, Storyboard.SPAN, false, ctx)
	var window := span.has("from")
	var when := OptionButton.new()
	when.fit_to_longest_item = false
	when.focus_mode = Control.FOCUS_NONE
	when.disabled = read_only
	when.add_item("A moment")
	when.add_item("A window")
	when.select(1 if window else 0)
	when.tooltip_text = "Whether it happens at one time, or across a stretch of it."
	when.item_selected.connect(func(i: int) -> void: _span_as(_sub_i, i == 1))
	_inspector.add_child(when)
	var times := {}
	var secs := "Seconds into the timeline, as it is written."
	if window:
		times["from"] = {"label": "From", "type": "float", "min": 0.0, "max": 600.0, "step": 0.05, "default": 0.0, "blurb": secs}
		times["to"] = {"label": "To", "type": "float", "min": 0.0, "max": 600.0, "step": 0.05, "default": 1.0, "blurb": secs}
	else:
		times["at"] = {"label": "At", "type": "float", "min": 0.0, "max": 600.0, "step": 0.05, "default": 0.0, "blurb": secs}
	_form(sp, times)
	var verb := String(span.get("action", ""))
	var args := Actions.ARGS.get(verb, {}) as Dictionary
	var has_args := DataPath.at(data, sp + ["args"]) is Dictionary
	if not args.is_empty() or has_args:
		_heading("%s takes" % verb.replace("_", " ").capitalize(), 12)
		_form(sp + ["args"], args, true, {"usable": true, "actors": ctx["actors"]})
	var rm := Button.new()
	rm.text = "Remove this span"
	rm.focus_mode = Control.FOCUS_NONE
	rm.disabled = read_only
	rm.pressed.connect(_remove_sub)
	_inspector.add_child(rm)


## Remove the actor or the span the inspector shows.
func _remove_sub() -> void:
	if _sel < 0 or _sub_i < 0:
		return
	var p := _path(_sel) + (["cast", _sub_i] if _sub == "actor" else ["track", "spans", _sub_i])
	_sub = "entry"
	_sub_i = -1
	_edit(DataPath.cut(data, p))
