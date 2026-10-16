extends SceneTree

## Every layer says what it can be told, and is told it:
##   godot --headless --path . --script tests/scene_kit/layer_fields_check.gd
##
## WHAT IT HOLDS (next/structure.md, step 16). A layer's settings are rows - `Base.COMMON` and its
## own `FIELDS` - read through [method Layer.fields_of]: what a timeline's inspector builds its rows
## from, and what an agent choosing a layer is shown. `docs.py --check` holds the rows to the code
## (every setting read has a row, every row is read, the literal defaults agree); this holds them at
## run time:
##
## - [method Layer.fields_of] answers every registered layer, the shared depth band first, then
##   its own - the table an inspector would get, read off the class the registry names;
## - a layer TOLD every default its table states builds and runs without an error, and is the same
##   layer as one told nothing: its depth band is the stated "front", and after a few frames of the
##   same music from the same seed it holds the same state.
##
## THE CONTROL: a key no layer has gets the shared rows alone, and a layer told a setting other than
## its default is not the same layer - so "the same" above is a comparison that can fail.

var _fails: Array = []


func _initialize() -> void:
	for key in Layer.REGISTRY:
		var rows: Dictionary = Layer.fields_of(key)
		var own: Dictionary = (Layer.REGISTRY[key] as GDScript).get("FIELDS")
		if rows.keys().front() != "z" or rows.size() != own.size() + Layer.Base.COMMON.size():
			_fails.append("%s: fields_of gave %s - not the shared rows and then its own" % [key, rows.keys()])
			continue
		var told := {}
		for k in rows:
			var row: Dictionary = rows[k]
			if not (row.has("label") and row.has("type") and row.has("blurb")):
				_fails.append("%s.%s: a row with no label, type or blurb" % [key, k])
			if row["default"] != null:
				told[k] = row["default"]
		var plain := Layer.make(key, _rng(7))
		var stated := Layer.make(key, _rng(7), told)
		if stated.z() != "front":
			_fails.append("%s: told its stated defaults, its depth band is %s" % [key, stated.z()])
		if _frame(plain) != _frame(stated):
			_fails.append("%s: a layer told its stated defaults is not the layer told nothing - a row's default is not the code's" % key)
	# the controls
	if Layer.fields_of("no-such-layer").keys() != Layer.Base.COMMON.keys():
		_fails.append("control: a key no layer has did not get the shared rows alone")
	if _frame(Layer.make("snow", _rng(7))) == _frame(Layer.make("snow", _rng(7), {"count": 7})):
		_fails.append("control: a snow told 7 flakes drew the same frame as one told nothing - the comparison cannot fail")
	for f in _fails:
		printerr("FAIL: ", f)
	print("layer_fields_check: %s" % ("ALL OK" if _fails.is_empty() else "%d FAILED" % _fails.size()))
	quit(0 if _fails.is_empty() else 1)


func _rng(seed: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed
	return r


## [param layer] after a few frames of music, as its own state: every variable of its script but the
## config it was told (the same layer, told nothing or told its defaults, holds a different `cfg`),
## its random stream by where it is, and anything else an object holds by its class alone.
func _frame(layer: Layer.Base) -> String:
	var f := AudioFeatures.new()
	f.energy = 0.6
	f.bass = 0.5
	f.beat = 1.0
	f.bands.resize(AudioFeatures.BAND_COUNT)
	f.bands.fill(0.4)
	for i in 3:
		layer.update(f, 1.0 / 30.0, Vector2(0.9, 0.55))
	var out := PackedStringArray()
	for prop in layer.get_property_list():
		if not (int(prop["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE) or prop["name"] == "cfg":
			continue
		out.append("%s=%s" % [prop["name"], _text(layer.get(prop["name"]))])
	return "\n".join(out)


func _text(v: Variant) -> String:
	if v is RandomNumberGenerator:
		return "rng@%d" % (v as RandomNumberGenerator).state
	if v is Object:
		return (v as Object).get_class()
	if v is Array:
		var parts := PackedStringArray()
		for x in v:
			parts.append(_text(x))
		return "[%s]" % ", ".join(parts)
	if v is Dictionary:
		var parts := PackedStringArray()
		for k in v:
			parts.append("%s: %s" % [str(k), _text(v[k])])
		return "{%s}" % ", ".join(parts)
	return var_to_str(v)
