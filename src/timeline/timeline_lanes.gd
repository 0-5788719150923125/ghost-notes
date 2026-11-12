extends VBoxContainer
class_name TimelineLanes

## TimelineLanes - one stage entry's spans on Masking's controls (next/editing.md, "The Timeline"). A
## window span (`from` to `to`) is a [TrackLane] - drag its edges to trim it, its body to move it - and
## every moment (`at`) a flag on one [FlagStrip] beneath them, picked by its handle and then dragged;
## the strip scrubs, and shows the playhead. All read one [TimelineView], so a second sits in the same
## place on every row. The lower rows of the [StoryboardEditor], shown while a stage entry is picked.
##
## The ruler is the entry's own: a track's times are written in seconds of its `nominal`, the length it
## was designed at, and they scale as one piece with the entry's hold - so the rows are drawn in nominal
## seconds, and dragging changes the number that is written, whatever speed the entry plays at.
##
## It asks, the editor does: one signal per gesture, raised when the button comes up: [signal picked],
## [signal retimed] (a span moved or stretched), [signal wanted] (a double click on the strip's body: a
## new moment there, for everyone) and [signal scrubbed] (the strip dragged: a moment of the entry to show).

## A span was clicked: its index in the track's list.
signal picked(span: int)
## A span was dragged: its new start and end in nominal seconds (equal, for a moment).
signal retimed(span: int, from: float, to: float)
## The strip's body was double-clicked: [param actor] ("" for everyone) and the time.
signal wanted(actor: String, at: float)
## The strip was scrubbed to [param t] nominal seconds.
signal scrubbed(t: float)
## A key ([StageKeys]) was dragged: its index in the track's `keys` and its new moment, nominal seconds.
signal key_retimed(key: int, at: float)

## The actors' names, in the cast's order.
var actors: Array = []
## The track's spans, as they are written.
var spans: Array = []
var nominal := 8.0
## The span picked, -1 for none.
var selected := -1:
	set(i):
		selected = i
		_mark_selected()
## Where the entry is, in nominal seconds; -1 while it is not on screen.
var playhead := -1.0
var read_only := false

var _view := TimelineView.new()
var _rows: Array = []        # [{lane: TrackLane, span: int, m: {in, out, off}, moved}]
var _strip: FlagStrip
var _flags: Array = []       # the strip's markers: {time, kind, label, span}
var _keys: Array = []        # the track's keys as markers: {time, kind, label, key, tint (the seconds it eases over)}
var _flag_moved := false
var _busy := false           # a gesture is under way: the rows are not built again under it


func _init() -> void:
	add_theme_constant_override("separation", 2)
	_strip = FlagStrip.new()
	_strip.tview = _view
	_strip.custom_minimum_size = Vector2(0, 64)
	_strip.get_markers = func() -> Array: return _flags + _keys
	_strip.get_span = func(m: Dictionary) -> Vector2: return m.get("tint", Vector2(float(m["time"]), float(m["time"])))
	_strip.get_extent = func() -> float: return nominal
	_strip.get_playhead = func() -> float: return playhead
	_strip.marker_picked.connect(func(m: Dictionary) -> void:
		_strip.selected = m
		if m.has("key"):
			return
		picked.emit(int(m["span"])))
	_strip.marker_drag_started.connect(func(_m: Dictionary) -> void:
		_busy = true
		_flag_moved = true)
	_strip.scrubbed.connect(func(t: float) -> void: scrubbed.emit(t))
	_strip.gui_input.connect(_on_strip_input)
	add_child(_strip)


## The entry to show: its cast's [param p_actors], its track's [param p_spans] and [param p_nominal].
func set_track(p_actors: Array, p_spans: Array, p_nominal: float) -> void:
	actors = p_actors
	spans = p_spans
	nominal = maxf(0.05, p_nominal)
	if _busy:
		return
	_view.refresh(nominal)
	for r in _rows:
		(r["lane"] as TrackLane).queue_free()
	_rows = []
	_flags = []
	for i in spans.size():
		var s: Dictionary = spans[i] if spans[i] is Dictionary else {}
		var label := "%s → %s" % [String(s.get("action", "?")), _targets(s)]
		if s.has("at"):
			_flags.append({"time": clampf(float(s["at"]), 0.0, nominal), "kind": 1, "label": label, "span": i})
			continue
		var from := clampf(float(s.get("from", 0.0)), 0.0, nominal)
		var to := clampf(float(s.get("to", from)), from, nominal)
		_add_row(i, label, from, to, _color_of(s))
	move_child(_strip, get_child_count() - 1)
	_mark_selected()


func _add_row(i: int, label: String, from: float, to: float, color: Color) -> void:
	var m := {"in": from, "out": to, "off": from}
	var lane := TrackLane.new()
	lane.tview = _view
	lane.label = label
	lane.color = color
	lane.full_duration = nominal
	lane.movable = true
	lane.get_in = func() -> float: return float(m["in"])
	lane.set_in = func(v: float) -> void: m["in"] = v
	lane.get_out = func() -> float: return float(m["out"])
	lane.set_out = func(v: float) -> void: m["out"] = v
	lane.get_offset = func() -> float: return float(m["off"])
	lane.set_offset = func(v: float) -> void: m["off"] = v
	lane.mouse_filter = Control.MOUSE_FILTER_IGNORE if read_only else Control.MOUSE_FILTER_STOP
	var row := {"lane": lane, "span": i, "m": m, "moved": false, "color": color}
	lane.drag_started.connect(func() -> void:
		_busy = true
		row["moved"] = true)
	lane.drag_ended.connect(func() -> void:
		_busy = false
		if bool(row["moved"]):
			row["moved"] = false
			var a := float(m["off"])
			retimed.emit(i, a, a + float(m["out"]) - float(m["in"])))
	lane.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and (e as InputEventMouseButton).pressed and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			picked.emit(i))
	_rows.append(row)
	add_child(lane)


func _on_strip_input(e: InputEvent) -> void:
	if not (e is InputEventMouseButton) or (e as InputEventMouseButton).button_index != MOUSE_BUTTON_LEFT:
		return
	var mb := e as InputEventMouseButton
	if mb.double_click and not read_only:
		wanted.emit("", clampf(_view.t_of(mb.position.x), 0.0, nominal))
	elif not mb.pressed and _flag_moved:
		_flag_moved = false
		_busy = false
		var m: Variant = _strip.selected
		if m is Dictionary and (m as Dictionary).has("key"):
			key_retimed.emit(int((m as Dictionary)["key"]), float((m as Dictionary)["time"]))
		elif m is Dictionary:
			retimed.emit(int((m as Dictionary)["span"]), float((m as Dictionary)["time"]), float((m as Dictionary)["time"]))


## The track's keys ([StageKeys], as written): flags on the strip as Masking draws its markers - a ramp's handle pointing back,
## a damp's forward, the seconds each eases over tinted - picked, then dragged to another moment.
func set_keys(raw: Array) -> void:
	_keys = []
	for k in StageKeys.sanitize(raw)["keys"]:
		var kd: Dictionary = k
		var t := clampf(float(kd["at"]), 0.0, nominal)
		var ramp := String(kd["ease"]) == "ramp"
		_keys.append({"time": t, "kind": 0 if ramp else 1, "label": StageKeys.key_name(kd), "key": int(kd["index"]),
			"tint": Vector2(t - float(kd["over"]), t) if ramp else Vector2(t, t + float(kd["over"]))})


## A span's window as written, `[start, end]` in nominal seconds (a moment's two the same).
static func window_of(span: Variant) -> Array:
	if not (span is Dictionary):
		return [0.0, 0.0]
	var d: Dictionary = span
	if d.has("from"):
		var a := _sec(d["from"])
		return [a, maxf(a, _sec(d.get("to", d["from"])))]
	var at := _sec(d.get("at", 0.0))
	return [at, at]


static func _sec(v: Variant) -> float:
	return float(v) if typeof(v) in [TYPE_INT, TYPE_FLOAT] else 0.0


## Who [param s] is aimed at, in words.
func _targets(s: Dictionary) -> String:
	var t: Variant = s.get("target", "all")
	if t is Array:
		return ", ".join(PackedStringArray((t as Array).map(func(v: Variant) -> String: return str(v))))
	return "everyone" if String(t) == "all" else String(t)


## An actor's own color, the same every time: the first it is aimed at.
func _color_of(s: Dictionary) -> Color:
	var t: Variant = s.get("target", "all")
	var who := String((t as Array)[0]) if t is Array and not (t as Array).is_empty() else String(t)
	var at := actors.find(who)
	var hue := fposmod(0.58 + 0.23 * float(at if at >= 0 else actors.size()), 1.0)
	return Color.from_hsv(hue, 0.45, 0.85)


func _mark_selected() -> void:
	for r in _rows:
		var on := int(r["span"]) == selected
		(r["lane"] as TrackLane).color = (r["color"] as Color).lightened(0.35) if on else (r["color"] as Color)
	_strip.selected = null
	for f in _flags:
		if int(f["span"]) == selected:
			_strip.selected = f
