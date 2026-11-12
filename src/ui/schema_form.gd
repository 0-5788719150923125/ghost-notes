extends VBoxContainer
class_name SchemaForm

## SchemaForm - rows of controls built from a table of fields, for editing one map of data.
##
## A registry says what can be set - each field's label, type, default, bounds or choices, and a sentence
## for its tooltip ([constant Storyboard.ENTRY], [constant Actions.ARGS], [constant Cast.PARAMS]) - and
## this draws a row for each, so a field added to a table is a control in every editor that shows that
## table. Nothing here knows what a storyboard is.
##
## It edits nothing itself. A row moved raises [signal edited] with the field's key and its new value,
## and whoever owns the data makes the edit (a new tree, [DataPath]) and shows the result again with
## [method show_fields]. The form never holds a value the data does not.
##
## Unset is a value. A key the map does not have means "the default", so a row shows the default dimmed,
## and a row whose key is written carries an unset button ([signal edited] with null). Writing a default
## explicitly and leaving it unset are different things, and both are kept.
##
## Types: `bool`, `enum`, `float`, `int`, `text`, `scene` (a choice among [code]context.scenes[/code]),
## `actor` (one of [code]context.actors[/code]), `targets` (some of them; none is everyone), `num` (a
## number, or a range `lo..hi` sampled once per instance), `vec3` (three of those, `x, y, z`), `pair`
## (two plain numbers, `x, z`) and `data` (anything else, as JSON). A key the map has and the table does
## not gets a row by what its value is ([method infer]).
##
## A bounded number is a slider beside its box (next/editing.md step 5): dragged, it is one edit,
## written as the drag ends, and unset, it stands at the default, dimmed, and sets the value only once
## moved. `color` is a picker, written `#rrggbb`; `ref` a choice among the names the context lists under
## the field's `of` (an actor, a thing, a point), "" unsetting it.

## A row was moved: the field's key and its new value; null unsets the key.
signal edited(key: String, value: Variant)

const LABEL_W := 92.0
const DIM := Color(1, 1, 1, 0.45)

## Rows are shown, never changed (a storyboard read from a file).
var read_only := false

var _building := false


func _init() -> void:
	add_theme_constant_override("separation", 4)


## Show [param values] through [param schema] (key -> field row, in order). [param context]:
## `scenes` and `actors`, the choices the `scene` and `targets` types offer; `extra` true adds a
## row for each key the map has and the table does not.
func show_fields(schema: Dictionary, values: Dictionary, context := {}) -> void:
	_building = true
	for c in get_children():
		remove_child(c)
		c.queue_free()
	for key in schema:
		_add_row(String(key), schema[key] as Dictionary, values, context)
	if bool(context.get("extra", false)):
		for key in values:
			if not schema.has(key):
				_add_row(String(key), infer(String(key), values[key]), values, context)
	_building = false


## One row shape (next/editing.md step 5): what this form reads - `type`, `label`, `blurb`, `default`,
## and `min`/`max`/`step`, `options` or `of` as its type has them - from a row written in any registry's
## dialect: the storyboard's and the table's (this shape), a layer's (`num`, `flag`, `txt`, `dict`), a
## scene's (`choice` with its options listed, `num` with a `range`; [method SceneRoster.fields_of] names
## a table's options first), the Look's tonemap adjustments (`min`/`max`/`step`, no type) and the Look's
## filters (no type and no bounds: a dial, 0 to 1).
static func normalize(row: Dictionary) -> Dictionary:
	var out := row.duplicate()
	match String(row.get("type", "")):
		"flag":
			out["type"] = "bool"
		"txt":
			out["type"] = "text"
		"dict":
			out["type"] = "data"
		"choice":
			out["type"] = "enum" if row.get("options") is Array else "text"
		"num":
			if row.get("range") is Array and row.get("default") == null:
				out["default"] = row["range"]
		"":
			if row.has("min") and row.has("max"):
				out["type"] = "float"
			elif typeof(row.get("default")) in [TYPE_INT, TYPE_FLOAT]:
				out["type"] = "float"
				out["min"] = 0.0
				out["max"] = 1.0
			elif row.get("default") is bool:
				out["type"] = "bool"
			elif row.get("default") is String:
				out["type"] = "text"
			else:
				out["type"] = "data"
	return out


## A field row for a value no table describes: a switch, a number, a line of text, or JSON.
static func infer(key: String, value: Variant) -> Dictionary:
	var row := {"label": key.capitalize(), "default": null, "blurb": "`%s`, as written." % key}
	match typeof(value):
		TYPE_BOOL:
			row["type"] = "bool"
		TYPE_INT, TYPE_FLOAT:
			row["type"] = "num"
		TYPE_STRING, TYPE_STRING_NAME:
			row["type"] = "text"
		_:
			row["type"] = "vec3" if is_vec3(value) else ("num" if is_range(value) else "data")
	return row


## A two-number list: a sampled range ([method Storyboard.sample]).
static func is_range(v: Variant) -> bool:
	return v is Array and (v as Array).size() == 2 and _is_num(v[0]) and _is_num(v[1])


## Three components, each a number or a range.
static func is_vec3(v: Variant) -> bool:
	if not (v is Array) or (v as Array).size() != 3:
		return false
	for c in v as Array:
		if not (_is_num(c) or is_range(c)):
			return false
	return true


## A number or a range as a person types it: `0.3`, or `0.3..0.4`.
static func num_text(v: Variant) -> String:
	if is_range(v):
		return "%s..%s" % [_trim(float(v[0])), _trim(float(v[1]))]
	return _trim(float(v)) if _is_num(v) else ""


## ...and read back: a number, a `[lo, hi]` range, or null for text that is neither.
static func parse_num(text: String) -> Variant:
	var t := text.strip_edges().trim_prefix("[").trim_suffix("]")
	for sep in ["..", ","]:
		if t.contains(sep):
			var parts := t.split(sep, false)
			if parts.size() == 2 and parts[0].strip_edges().is_valid_float() and parts[1].strip_edges().is_valid_float():
				return [_number(parts[0]), _number(parts[1])]
			return null
	return _number(t) if t.is_valid_float() else null


## Three components as a person types them: `0, 0, 4` (a component may be a range, `0.3..0.4`).
static func vec3_text(v: Variant) -> String:
	if not is_vec3(v):
		return ""
	var parts := PackedStringArray()
	for c in v as Array:
		parts.append(num_text(c))
	return ", ".join(parts)


## Two numbers as a person types them, `x, z` - a place on a table in centimeters, say. "" for anything else.
static func pair_text(v: Variant) -> String:
	if not (v is Array) or (v as Array).size() != 2 or not _is_num((v as Array)[0]) or not _is_num((v as Array)[1]):
		return ""
	return "%s, %s" % [num_text((v as Array)[0]), num_text((v as Array)[1])]


## ...and read back: `[x, z]`, or null for text that is not two numbers.
static func parse_pair(text: String) -> Variant:
	var parts := text.strip_edges().trim_prefix("[").trim_suffix("]").split(",", false)
	if parts.size() != 2 or not parts[0].strip_edges().is_valid_float() or not parts[1].strip_edges().is_valid_float():
		return null
	return [float(parts[0]), float(parts[1])]


## ...and read back: `[x, y, z]`, or null for text that is not three components.
static func parse_vec3(text: String) -> Variant:
	var parts := text.strip_edges().trim_prefix("[").trim_suffix("]").split(",", false)
	if parts.size() != 3:
		return null
	var out: Array = []
	for p in parts:
		var c: Variant = parse_num(p)
		if c == null:
			return null
		out.append(c)
	return out


static func _is_num(v: Variant) -> bool:
	return typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT


## A whole number stays an int, as the YAML it was read from had it.
static func _number(text: String) -> Variant:
	var t := text.strip_edges()
	return int(t) if t.is_valid_int() else float(t)


static func _trim(f: float) -> String:
	return str(int(f)) if is_equal_approx(f, roundf(f)) and absf(f) < 1e9 else str(snappedf(f, 0.0001))


func _add_row(key: String, raw: Dictionary, values: Dictionary, context: Dictionary) -> void:
	var field := normalize(raw)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	add_child(row)
	var label := Label.new()
	label.text = String(field.get("label", key))
	label.custom_minimum_size = Vector2(LABEL_W, 0)
	label.add_theme_font_size_override("font_size", 12)
	label.tooltip_text = String(field.get("blurb", ""))
	label.mouse_filter = Control.MOUSE_FILTER_STOP
	label.clip_text = true
	row.add_child(label)
	var has := values.has(key)
	var value: Variant = values[key] if has else field.get("default")
	var control := _control(key, field, value, has, context)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	control.tooltip_text = String(field.get("blurb", ""))
	if not has:
		control.modulate = DIM
	row.add_child(control)
	var reset := Button.new()
	reset.text = "↺"
	reset.flat = true
	reset.focus_mode = Control.FOCUS_NONE
	reset.tooltip_text = "Unset: back to the default."
	reset.disabled = not has or read_only
	reset.modulate.a = 1.0 if has and not read_only else 0.0
	reset.pressed.connect(func() -> void: edited.emit(key, null))
	row.add_child(reset)


func _control(key: String, field: Dictionary, value: Variant, has: bool, context: Dictionary) -> Control:
	match String(field.get("type", "data")):
		"bool":
			var box := CheckBox.new()
			box.button_pressed = bool(value) if value != null else false
			box.disabled = read_only
			box.focus_mode = Control.FOCUS_NONE
			box.toggled.connect(func(on: bool) -> void: _emit(key, on))
			return box
		"enum":
			return _choice(key, field.get("options", []) as Array, String(value) if value != null else "")
		"scene":
			return _choice(key, context.get("scenes", []) as Array, String(value) if value != null else "")
		"actor":
			return _choice(key, [""] + (context.get("actors", []) as Array), String(value) if value != null else "")
		"float", "int":
			# (a slider for one number: a range sampled once, `[lo, hi]`, or a value from a def stays the line it was)
			if field.has("min") and field.has("max") and (value == null or typeof(value) in [TYPE_INT, TYPE_FLOAT]) \
					and typeof(field.get("default", field["min"])) in [TYPE_INT, TYPE_FLOAT]:
				return _slider(key, field, value, has)
			return _line(key, num_text(value) if has else "", num_text(field.get("default")),
				func(t: String) -> Variant:
					if not t.strip_edges().is_valid_float():
						return null
					return int(t.strip_edges()) if String(field["type"]) == "int" else float(t))
		"num":
			return _line(key, num_text(value) if has else "", num_text(field.get("default")), parse_num)
		"vec3":
			return _line(key, vec3_text(value) if has else "", vec3_text(field.get("default")), parse_vec3)
		"pair":
			return _line(key, pair_text(value) if has else "", pair_text(field.get("default")), parse_pair)
		"text":
			return _line(key, String(value) if has and value != null else "", "", func(t: String) -> Variant:
				return t.strip_edges() if not t.strip_edges().is_empty() else null)
		"targets":
			return _targets(key, value, context.get("actors", []) as Array)
		"color":
			var pick := ColorPickerButton.new()
			pick.custom_minimum_size = Vector2(48, 0)
			pick.color = Color.from_string(String(value if has and value != null else field.get("default", "#ffffff")), Color.WHITE)
			pick.edit_alpha = false
			pick.disabled = read_only
			pick.modulate.a = 1.0 if has else 0.6
			pick.color_changed.connect(func(c: Color) -> void: _emit(key, "#" + c.to_html(false)))
			return pick
		"ref":
			return _choice(key, [""] + (context.get(String(field.get("of", "")), []) as Array), String(value) if value != null else "")
	return _line(key, JSON.stringify(value) if has else "", "", func(t: String) -> Variant:
		return JSON.parse_string(t))


## A bounded number: a slider and its box, as one. The box writes what is typed; the slider writes once,
## as its drag ends (or at once for a click or a key). Unset, both stand at the default, dimmed.
func _slider(key: String, field: Dictionary, value: Variant, has: bool) -> Control:
	var whole := String(field["type"]) == "int"
	var row := HBoxContainer.new()
	var slide := HSlider.new()
	var spin := SpinBox.new()
	for r in [slide, spin]:
		(r as Range).min_value = float(field["min"])
		(r as Range).max_value = float(field["max"])
		(r as Range).step = float(field.get("step", 1.0 if whole else 0.01))
		(r as Range).set_value_no_signal(float(value if has and value != null else field.get("default", field["min"])))
	slide.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slide.custom_minimum_size = Vector2(90, 0)
	slide.editable = not read_only
	spin.editable = not read_only
	row.modulate.a = 1.0 if has else 0.6
	var out := func(v: float) -> Variant: return int(v) if whole else v
	var dragging := [false]
	slide.drag_started.connect(func() -> void: dragging[0] = true)
	slide.drag_ended.connect(func(changed: bool) -> void:
		dragging[0] = false
		if changed:
			_emit(key, out.call(slide.value)))
	slide.value_changed.connect(func(v: float) -> void:
		spin.set_value_no_signal(v)
		if not dragging[0]:
			_emit(key, out.call(v)))
	# The box's edit is handed over once its press is done: an arrow pressed sets the value and then
	# starts the box's own repeat timer, which fails if an owner that redraws its form on an edit freed the box in between.
	spin.value_changed.connect(func(v: float) -> void:
		slide.set_value_no_signal(v)
		_emit.call_deferred(key, out.call(v)))
	row.add_child(slide)
	row.add_child(spin)
	return row


func _emit(key: String, value: Variant) -> void:
	if not _building and not read_only:
		edited.emit(key, value)


## One of [param options]; "" among them reads "(unset)" and unsets the key.
func _choice(key: String, options: Array, current: String) -> OptionButton:
	var pick := OptionButton.new()
	# sized by the row, not by its longest item (see SidePanel._check_width)
	pick.fit_to_longest_item = false
	pick.clip_text = true
	pick.focus_mode = Control.FOCUS_NONE
	pick.disabled = read_only
	var opts := options.duplicate()
	if not current.is_empty() and not opts.has(current):
		opts.append(current)               # a value the table does not list is still shown
	for o in opts:
		pick.add_item(String(o).replace("_", " ") if not String(o).is_empty() else "(unset)")
		pick.set_item_metadata(pick.item_count - 1, String(o))
		if String(o) == current:
			pick.select(pick.item_count - 1)
	pick.item_selected.connect(func(i: int) -> void:
		var v := String(pick.get_item_metadata(i))
		_emit(key, v if not v.is_empty() else null))
	return pick


## A line of text read by [param parse] (`(String) -> Variant`, null for text it cannot read) when
## Enter is pressed or the line is left. An empty line unsets the key; unreadable text is put back.
func _line(key: String, text: String, placeholder: String, parse: Callable) -> LineEdit:
	var line := LineEdit.new()
	line.text = text
	line.placeholder_text = placeholder
	line.editable = not read_only
	line.add_theme_font_size_override("font_size", 12)
	# what the line last said, so leaving it after Enter is not a second edit of the same value
	var said := {"text": text}
	var commit := func() -> void:
		if line.text == String(said["text"]):
			return
		if line.text.strip_edges().is_empty():
			said["text"] = line.text
			_emit(key, null)
			return
		var v: Variant = parse.call(line.text)
		if v == null:
			line.text = String(said["text"])
			return
		said["text"] = line.text
		_emit(key, v)
	line.text_submitted.connect(func(_t: String) -> void: commit.call())
	line.focus_exited.connect(commit)
	return line


## Which actors: a menu of ticks. None ticked is everyone, written as no key at all.
func _targets(key: String, value: Variant, actors: Array) -> MenuButton:
	var chosen: Array = []
	if value is Array:
		chosen = (value as Array).duplicate()
	elif value != null and String(value) != "all" and not String(value).is_empty():
		chosen = [String(value)]
	var menu := MenuButton.new()
	menu.flat = false
	menu.clip_text = true
	menu.alignment = HORIZONTAL_ALIGNMENT_LEFT
	menu.disabled = read_only
	menu.text = ", ".join(PackedStringArray(chosen)) if not chosen.is_empty() else "everyone"
	var pop := menu.get_popup()
	pop.hide_on_checkable_item_selection = false
	var ids := actors.duplicate()
	for c in chosen:
		if not ids.has(c):
			ids.append(c)
	for id in ids:
		pop.add_check_item(String(id))
		pop.set_item_checked(pop.item_count - 1, chosen.has(id))
	pop.popup_hide.connect(func() -> void:
		var now: Array = []
		for i in pop.item_count:
			if pop.is_item_checked(i):
				now.append(pop.get_item_text(i))
		var was := chosen.duplicate()
		var is_now := now.duplicate()
		was.sort()
		is_now.sort()
		if was == is_now:
			return
		# one actor is written as its name, several as a list - as a storyboard is by hand
		_emit(key, null if now.is_empty() else (now[0] if now.size() == 1 else now)))
	pop.index_pressed.connect(func(i: int) -> void: pop.set_item_checked(i, not pop.is_item_checked(i)))
	return menu
