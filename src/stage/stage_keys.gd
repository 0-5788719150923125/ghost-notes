extends RefCounted
class_name StageKeys

## StageKeys - a stage's flags: a value that changes at a moment, eased before or after it, and holds
## (next/editing.md). Masking's marker is the model, its ramp and damp the same two eases: a ramp arrives
## at its moment, eased in over the seconds before it (anticipation); a damp begins at it, eased out over
## the seconds after. Between keys a field holds what the last one left.
##
##   track:
##     nominal: 8
##     keys:
##       - {field: camera.fov, at: 2.0, to: 30, over: 1.5, ease: ramp}
##       - {field: camera.eye, at: 5.0, to: [0, 0.6, 3.2], over: 2.0, ease: damp}
##       - {field: actor.scale, actor: blue, at: 3.0, to: 0.6, over: 1.0, ease: ramp}
##       - {field: look, filter: pointillism, at: 4.0, to: 0.8, over: 2.0, ease: ramp}
##
## Times are the track's nominal seconds, as its spans' are, scaling with the entry's hold. A pure function
## of the entry's time (the Timeline's `time` engine): shown at any moment at once, the same every time,
## unlike a verb, which latches as it plays. Which fields a key may name is [constant FIELDS].

const FIELDS := {
	"camera.fov": {"label": "Camera's field of view", "blurb": "How wide the lens sees, in degrees: smaller is closer.", "kind": "num"},
	"camera.eye": {"label": "Camera's place", "blurb": "Where the lens stands, [x, y, z].", "kind": "vec3"},
	"camera.look": {"label": "What the camera looks at", "blurb": "The point the lens is aimed at, [x, y, z].", "kind": "vec3"},
	"actor.scale": {"label": "Size", "blurb": "An actor's size in the world (its `actor` names which). From its first key on, a verb's own change to it is overruled.", "kind": "num"},
	"actor.hue": {"label": "Hue", "blurb": "An actor's color around the wheel, 0-1 (its `actor` names which).", "kind": "num"},
	"actor.fade": {"label": "Shown", "blurb": "How far an actor is shown, 0 hidden to 1 (its `actor` names which).", "kind": "num"},
	"look": {"label": "The Look", "blurb": "A filter's dial over the whole picture, 0 off to 1 (its `filter` names which of the Look's filters). From its first key on, the Look card's own setting is overruled.", "kind": "num"},
}
const EASES := {
	"ramp": {"label": "Ramp", "blurb": "Arrives at its moment, eased in over the seconds before it."},
	"damp": {"label": "Damp", "blurb": "Begins at its moment, eased out over the seconds after it."},
}


## [param raw] (a track's `keys`) made safe: `{keys, notes}` - each key a known field, a moment, a value of the field's kind, its
## seconds and ease; sorted by when each begins to move. Anything else is said and left out.
static func sanitize(raw: Variant) -> Dictionary:
	var keys: Array = []
	var notes := PackedStringArray()
	for i in (raw as Array).size() if raw is Array else 0:
		var k: Variant = (raw as Array)[i]
		if not (k is Dictionary):
			notes.append("keys[%d] is not a map - left out" % i)
			continue
		var d: Dictionary = k
		var field := String(d.get("field", ""))
		if not FIELDS.has(field):
			notes.append("keys[%d]: \"%s\" is none of %s - left out" % [i, field, ", ".join(FIELDS.keys())])
			continue
		var to: Variant = _value(d.get("to"), String(FIELDS[field]["kind"]))
		if to == null:
			notes.append("keys[%d]: %s's `to` is not a %s - left out" % [i, field, "number" if String(FIELDS[field]["kind"]) == "num" else "[x, y, z]"])
			continue
	# (who a key moves: an actor's, or the Look's filter; kept as the key's `actor`, what tells its values apart)
		var by := "filter" if field == "look" else "actor"
		var who := String(d.get(by, "")) if d.get(by) is String else ""
		if (field.begins_with("actor.") or field == "look") and who.is_empty():
			notes.append("keys[%d]: %s names no `%s` - left out" % [i, field, by])
			continue
		var ease := String(d.get("ease", "ramp"))
		keys.append({"field": field, "actor": who, "at": maxf(0.0, float(d.get("at", 0.0))), "to": to, "over": maxf(0.0, float(d.get("over", 0.0))),
			"ease": ease if EASES.has(ease) else "ramp", "index": i})
	keys.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return start_of(a) < start_of(b))
	return {"keys": keys, "notes": notes}


## When [param k] (made safe) begins to move: a ramp its seconds before its moment, a damp at it.
static func start_of(k: Dictionary) -> float:
	return float(k["at"]) - (float(k["over"]) if String(k["ease"]) == "ramp" else 0.0)


## How a key is named on a timeline: its field, or an actor's `<actor>.<param>`.
static func key_name(k: Dictionary) -> String:
	var f := String(k.get("field", ""))
	if f == "look":
		return "look.%s" % String(k.get("actor", k.get("filter", "")))
	return "%s.%s" % [String(k.get("actor", "")), f.trim_prefix("actor.")] if f.begins_with("actor.") else f


## When [param field] (of [param actor]) first begins to move, INF for never: before it, a verb rules it.
static func first_start(keys: Array, field: String, actor := "") -> float:
	for k in keys:
		if String((k as Dictionary)["field"]) == field and String((k as Dictionary).get("actor", "")) == actor:
			return start_of(k)
	return INF


## [param field] (of [param actor], for an actor's) at [param t] nominal seconds, from [param base] (what the entry sets it to)
## and [param keys] (made safe).
static func value_at(base: Variant, keys: Array, field: String, t: float, actor := "") -> Variant:
	var v: Variant = base
	for k in keys:
		var kd: Dictionary = k
		if String(kd["field"]) != field or String(kd.get("actor", "")) != actor:
			continue
		var t0 := start_of(kd)
		if t < t0:
			break
		var over := float(kd["over"])
		var u := 1.0 if over <= 0.0 else clampf((t - t0) / over, 0.0, 1.0)
		var e := u * u * (3.0 - 2.0 * u)
		v = lerp(v, kd["to"], e) if typeof(v) == typeof(kd["to"]) else kd["to"]
	return v


static func _value(v: Variant, kind: String) -> Variant:
	if kind == "num":
		return float(v) if typeof(v) in [TYPE_INT, TYPE_FLOAT] else null
	if v is Array and (v as Array).size() == 3 and (v as Array).all(func(x: Variant) -> bool: return typeof(x) in [TYPE_INT, TYPE_FLOAT]):
		return Vector3(float(v[0]), float(v[1]), float(v[2]))
	return null
