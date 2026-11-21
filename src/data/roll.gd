extends RefCounted
class_name Roll

## Roll - a thing's properties as a person tunes them: each a field row (SchemaForm's shape - `label`, `blurb`, `type`, `default`,
## `min`/`max`/`step` or `options`), and the ones a person never set drawn from the thing's own number inside the field's `roll`, so a
## new number is another variant of the same thing, never a wild one. A field set is pinned and no roll moves it; unset, it is the
## number's again ([SchemaForm] shows it dimmed). A field with no `roll` is its `default` until set.
##
## `roll` is `[least, most]` for a number, a list of the choices drawn among for an `enum` or a `color`, or a chance for a `bool`.
## Pure: the same fields, set values and number give the same values on any machine. A draw that must stay put as a list
## of choices grows - a code kept for later, a row added - is [method pick] and [method rng], keyed by name and salt.


## A new number for a thing, to draw its unset fields from: under [param most].
static func fresh(most := 1000000) -> int:
	return randi() % most


## A number in [0, 1) for [param seed] and [param salt], the same on any machine and any engine (a SHA-256, not the
## engine's own hash).
static func unit(seed: int, salt: String) -> float:
	return float(("%d|%s" % [seed, salt]).sha256_text().substr(0, 8).hex_to_int()) / 4294967296.0


## A generator for [param seed] and [param salt], as [method unit] keys it: each thing drawn from a salt of its own, so a
## draw added never moves another.
static func rng(seed: int, salt: String) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = ("%d|%s" % [seed, salt]).sha256_text().substr(0, 15).hex_to_int()
	return r


## THE CHOICE AMONG NAMES THAT A NEW NAME NEVER RESHUFFLES: each of [param names] scored by itself ([method unit] of
## [param seed], [param salt] and the name), the highest taken - so a name added takes only the draws it wins and every
## other keeps its own, as the show picks its scenes. Null for none.
static func pick(names: Array, seed: int, salt: String) -> Variant:
	var best: Variant = null
	var top := -1.0
	for n in names:
		var u := unit(seed, salt + "|" + str(n))
		if u > top:
			top = u
			best = n
	return best


## Every field of [param fields] for a thing of number [param seed] with [param set] pinned: what is set where it is, the rest drawn
## ([method drawn]).
static func values(fields: Dictionary, set: Dictionary, seed: int) -> Dictionary:
	var out := {}
	for k in fields:
		out[k] = set[k] if set.has(k) else drawn(fields[k], String(k), seed)
	return out


## Every field of [param fields] for a thing kept as [param spec] - `{seed, <its fields set>}` - that is its own until it is rolled:
## with no `seed`, each field not set its `default`; with one, drawn by it ([method values]). What is set is set either way.
static func own_or_drawn(fields: Dictionary, spec: Dictionary) -> Dictionary:
	var set := spec.duplicate()
	set.erase("seed")
	if typeof(spec.get("seed")) in [TYPE_INT, TYPE_FLOAT]:
		return values(fields, set, int(spec["seed"]))
	var out := {}
	for k in fields:
		out[k] = set[k] if set.has(k) else (fields[k] as Dictionary).get("default")
	return out


## [param fields] as [method own_or_drawn] shows them for [param spec]: each unset field's `default` what it is now - [SchemaForm]
## shows it dimmed.
static func shown_for(fields: Dictionary, spec: Dictionary) -> Dictionary:
	var now := own_or_drawn(fields, spec)
	var out := {}
	for k in fields:
		var row: Dictionary = (fields[k] as Dictionary).duplicate()
		if not spec.has(k):
			row["default"] = now[k]
		out[k] = row
	return out


## [param raw] made safe as a thing kept by [method own_or_drawn]: its `seed` where it has one, and what it sets of [param fields]
## ([method clean]).
static func clean_spec(fields: Dictionary, raw: Variant) -> Dictionary:
	var d: Dictionary = raw if raw is Dictionary else {}
	var out := clean(fields, d)
	if typeof(d.get("seed")) in [TYPE_INT, TYPE_FLOAT]:
		out["seed"] = int(d["seed"])
	return out


## Field [param row] (named [param key]) as the number [param seed] draws it inside its `roll`, or its `default` where it has none.
static func drawn(row: Dictionary, key: String, seed: int) -> Variant:
	var roll: Variant = row.get("roll")
	if roll == null:
		return row.get("default")
	var r := RandomNumberGenerator.new()
	r.seed = hash([seed, key])
	match String(row.get("type", "")):
		"int":
			if roll is Array and (roll as Array).size() == 2:
				return r.randi_range(int(roll[0]), int(roll[1]))
		"float":
			if roll is Array and (roll as Array).size() == 2:
				var v := r.randf_range(float(roll[0]), float(roll[1]))
				return snappedf(v, float(row.get("step", 0.01)))
		"enum", "color":
			if roll is Array and not (roll as Array).is_empty():
				return (roll as Array)[r.randi() % (roll as Array).size()]
		"bool":
			return r.randf() < float(roll)
	return row.get("default")


## [param fields] with each unset field's `default` what the number [param seed] draws it as: what [SchemaForm] shows, dimmed, for a
## field [param set] does not pin.
static func shown(fields: Dictionary, set: Dictionary, seed: int) -> Dictionary:
	var out := {}
	for k in fields:
		var row: Dictionary = (fields[k] as Dictionary).duplicate()
		if not set.has(k):
			row["default"] = drawn(fields[k], String(k), seed)
		out[k] = row
	return out


## What [param raw] sets of [param fields], made safe: a number held to its field's bounds (a whole one for `int`), a choice its field
## offers, a color as `#rrggbb`, a switch a bool; anything else, and any key with no field, left out.
static func clean(fields: Dictionary, raw: Dictionary) -> Dictionary:
	var out := {}
	for k in raw:
		if not fields.has(k):
			continue
		var row: Dictionary = fields[k]
		var v: Variant = raw[k]
		match String(row.get("type", "")):
			"int", "float":
				if typeof(v) in [TYPE_INT, TYPE_FLOAT]:
					var f := clampf(float(v), float(row.get("min", -INF)), float(row.get("max", INF)))
					out[k] = int(roundf(f)) if String(row["type"]) == "int" else f
			"enum":
				if v is String and String(v) in (row.get("options", []) as Array):
					out[k] = String(v)
			"color":
				if v is String and Color.html_is_valid(String(v)):
					out[k] = "#" + Color.html(String(v)).to_html(false)
			"bool":
				if v is bool:
					out[k] = v
	return out
