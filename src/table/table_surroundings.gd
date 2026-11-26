extends RefCounted
class_name TableSurroundings

## TableSurroundings - a table's sound and the lasting part of its air as Environment elements ([Surroundings]), and back: what the
## set dresser wrote (`table.json`'s `sound` and `effects`) listed on the Environment card as any note's environment is, kept in the
## library ([EnvironmentLibrary]) and changed by hand. Pure.
##
## Each part of the sound is an element of its kind - the wind, the sea, rain, a fire, a stream, insects, the ride, and a creature each -
## and each fog and each kind of motes in the air one too: a fog a haze, motes the kind their look is ([constant MOTE_KINDS]). Bursts and
## what the wind carries are the set dresser's staging and stay as written. An element made here is the table's as written (its `own`,
## [constant Surroundings.OWN]): it sets the part's own values, and the rest of the part's words ride along, so written back it is the
## same part. An element brought from the Dex stands where its kind stands at a table ([constant PLACES]).
##
## The table keeps what is set aside from its environment as `environment_aside`, a list of elements beside its things' `aside`:
## nothing plays it and no agent reads it.

## Where an element of the Environment stands at a table: its kind's region ([constant Surroundings.KINDS]' `where`) as the table names
## it ([constant CardTable.AIR]). A fog stands beyond the table, where it never lies thick over the work.
const PLACES := {"far": "beyond the table", "near": "over the cloth", "room": "the whole room"}
const FOG_PLACE := "beyond the table"
## The kind each look of motes is ([constant Effects.MOTES]).
const MOTE_KINDS := {"dust": "dust", "pixie": "pixies", "firefly": "fireflies", "wisp": "wisps", "ember": "embers", "snow": "snow",
	"fly": "flies"}
## The kind each part of the sound is ([constant Soundscape.LAYERS]), in the order the card lists them.
const SOUND_KINDS := {"wind": "wind", "water": "sea", "rain": "rain", "fire": "fire", "stream": "stream", "insects": "insects",
	"ride": "ride", "creatures": "creature"}
## The table's key for what is set aside from its environment.
const ASIDE := "environment_aside"


## Every element of table [param table] (as written, `table.json`), the episode's [param seed] numbering them: its sound's parts, then
## its lasting air in the order it was written (made safe in [param palette], the plan's), then what is set aside (each `off`).
static func elements_of(table: Dictionary, seed: int, palette: Array) -> Array:
	var out: Array = []
	var sound := Soundscape.sanitize(table.get("sound"))
	for part in SOUND_KINDS:
		if part == "creatures":
			var cs: Array = sound.get("creatures", []) if sound.get("creatures") is Array else []
			for i in cs.size():
				out.append(_heard("creature", cs[i], absi(hash([seed, "sound", part, i])) % 1000000))
		elif sound.get(part) is Dictionary:
			out.append(_heard(String(SOUND_KINDS[part]), sound[part], absi(hash([seed, "sound", part])) % 1000000))
	for a in _air(table, seed, palette):
		out.append((a as Dictionary)["element"])
	for e in (table.get(ASIDE, []) if table.get(ASIDE) is Array else []):
		var el := Surroundings.element(e)
		if not el.is_empty() and String((Surroundings.KINDS[String(el["kind"])] as Dictionary)["group"]) != "light":
			el["off"] = true
			out.append(el)
	return out


## Table [param table] with its sound, its lasting air and what is set aside written from [param elements] (as [method elements_of]
## gives them, changed): each air element where its effect stood, one new at the end, bursts and what the wind carries kept as they
## were; the sound's `why` kept.
static func with_elements(table: Dictionary, elements: Array, seed: int, palette: Array) -> Dictionary:
	var t := table.duplicate(true)
	var heard: Array = []
	var air := {}
	var air_order: Array = []
	var aside: Array = []
	for e in elements:
		var el: Dictionary = e
		var group := String((Surroundings.KINDS.get(String(el.get("kind", "")), {}) as Dictionary).get("group", ""))
		if el.get("off") == true:
			var kept := el.duplicate(true)
			kept.erase("off")
			aside.append(kept)
		elif group == "sound":
			heard.append(el)
		elif group == "air":
			air[int(el["seed"])] = el
			air_order.append(int(el["seed"]))
	var sound := Surroundings.sound_of({"elements": heard})
	var was := Soundscape.sanitize(table.get("sound"))
	if not sound.is_empty() and not String(was.get("why", "")).is_empty():
		sound["why"] = was["why"]
	t["sound"] = sound
	var fx: Array = []
	var stood := _air(table, seed, palette)
	var by_index := {}
	for a in stood:
		by_index[int((a as Dictionary)["index"])] = int(((a as Dictionary)["element"] as Dictionary)["seed"])
	var all := Effects.sanitize(table.get("effects", []), palette, CardTable.AIR.keys(), CardTable.MOMENTS.keys())
	for i in all.size():
		if not by_index.has(i):
			fx.append(all[i])
			continue
		var s := int(by_index[i])
		if air.has(s):
			fx.append(effect_of(air[s]))
			air_order.erase(s)
	for s in air_order:
		fx.append(effect_of(air[s]))
	t["effects"] = fx
	if aside.is_empty():
		t.erase(ASIDE)
	else:
		t[ASIDE] = aside
	return t


## Element [param el] of the air as an effect at a table ([Effects]): a haze a fog, a fog a fog with all it is told, motes the look
## its kind is - each where its own words put it, else where its kind stands at a table ([constant PLACES]).
static func effect_of(el: Dictionary) -> Dictionary:
	var kind := String(el.get("kind", ""))
	var row: Dictionary = Surroundings.KINDS.get(kind, {})
	var base: Dictionary = row.get("effect", {})
	var own: Dictionary = el.get("own", {})
	var v := Surroundings.values_of(el)
	var fx := {"name": String(own.get("name", "%s %d" % [kind, int(el.get("seed", 0))]))}
	if String(base.get("kind", "")) == "motes":
		fx.merge({"kind": "motes", "look": String(base["look"]), "where": _where(own, base),
			"count": Surroundings.mote_count(el, v), "colors": Surroundings.own_colors(own, String(v["color"])),
			"size": v["size"], "glow": v["glow"], "speed": v["speed"]})
		for k in ["away", "light"]:
			if own.has(k):
				fx[k] = own[k]
		return fx
	fx["kind"] = "fog"
	if kind == "fog":
		for k in ["density", "rolls", "height", "grain", "settle", "patches", "patch", "chaos", "wind", "turn", "gusts", "stretch",
				"sway", "pace", "breathe", "glow"]:
			fx[k] = v[k]
		fx["shape"] = v["activation"]
		fx["sight"] = float(v["height"]) * 0.025
		fx["where"] = FOG_PLACE
		if Color.html_is_valid(String(v["color"])):
			fx["color"] = String(v["color"])
		return fx
	# a haze: a bank, as its kind is or as the table wrote it
	fx.merge({"where": String(own["where"]) if own.has("where") else FOG_PLACE, "density": v["density"], "rolls": v["rolls"],
		"drift": v["drift"], "height": base.get("height", 60.0), "grain": base.get("grain", 40.0)})
	for k in own:
		if k != "where" and k != "name":
			fx[k] = own[k]
	return fx


## Where motes of base effect [param base] stand at a table: where their own words put them, else their kind's region there.
static func _where(own: Dictionary, base: Dictionary) -> String:
	if own.has("where"):
		return String(own["where"])
	return String(PLACES.get(String(base.get("where", "near")), "over the cloth"))


## A part of the sound ([param part], made safe) as an element of [param kind] numbered [param seed]: its properties set as the part
## has them, the rest of its words its `own`.
static func _heard(kind: String, part: Dictionary, seed: int) -> Dictionary:
	var row: Dictionary = Surroundings.KINDS[kind]
	var fields := Surroundings.fields_of(kind)
	var el := {"kind": kind, "seed": seed}
	var own := {}
	for k in part:
		var field := "sort" if String(k) == "kind" else String(k)
		if fields.has(field):
			el[field] = part[k]
		elif String(k) in Surroundings.own_keys(kind):
			own[k] = part[k]
	el["own"] = own
	return Surroundings.element(el) if not row.is_empty() else {}


## The table's lasting air: each fog and motes of its effects (made safe in [param palette]) as an element, with its place among them -
## `[{index, element}]`. A fog is a haze; motes the kind their look is. Each numbered by its name and how many before it had that name.
static func _air(table: Dictionary, seed: int, palette: Array) -> Array:
	var out: Array = []
	var all := Effects.sanitize(table.get("effects", []), palette, CardTable.AIR.keys(), CardTable.MOMENTS.keys())
	var names := {}
	for i in all.size():
		var fx: Dictionary = all[i]
		var kind := ""
		if String(fx["kind"]) == "fog":
			kind = "haze"
		elif String(fx["kind"]) == "motes":
			kind = String(MOTE_KINDS.get(String(fx.get("look", "")), ""))
		if kind.is_empty():
			continue
		var nm := String(fx.get("name", ""))
		var nth := int(names.get(nm, 0))
		names[nm] = nth + 1
		var el := {"kind": kind, "seed": absi(hash([seed, "air", nm, nth])) % 1000000}
		var own := {}
		if kind == "haze":
			for k in ["density", "rolls", "drift"]:
				el[k] = fx[k]
		else:
			el["size"] = fx["size"]
			el["glow"] = fx["glow"]
			el["speed"] = fx["speed"]
			var colors: Array = fx.get("colors", [])
			if not colors.is_empty():
				el["color"] = colors[0]
		for k in Surroundings.own_keys(kind):
			if fx.has(k):
				own[k] = fx[k]
		el["own"] = own
		out.append({"index": i, "element": Surroundings.element(el)})
	return out


## The sound of element [param el] alone at table [param table], as the table hears it ([method Soundscape.of_table]: its wind and its
## ride planned on the episode's [param seed]) - `{sound, wind, ride}`, its `sound` {} where it makes none.
static func heard_alone(table: Dictionary, el: Dictionary, seed: int) -> Dictionary:
	var one := el.duplicate(true)
	one.erase("off")
	var sound := Surroundings.sound_of({"elements": [one]})
	return Soundscape.of_table({"sound": sound, "light": table.get("light", {}), "ride": table.get("ride", {})}, seed)
