extends RefCounted
class_name TableTune

## TableTune - THE NUMBERS A PERSON HAS JUDGED, AS ROWS (next/editing.md step 11; each names the laws whose motion it paces, so a show
## is offered only the numbers its acts use): a constant a report made someone change, named
## and bounded, with its default the value that proved right - told per show in its `table:` block (`tune: {slow_most: 3}`) and
## read by the table as it is built ([TableWork], [TablePaint]), so a show tunes how a hand paces itself without a code change
## and its gates. Never a free knob: a value outside a row's bounds is brought inside them and said ([method sanitize]); a key
## with no row is said and left out.

const ROWS := {
	"slow_most": {"label": "Slowest stroke", "blurb": "How far an act's strokes may be slowed (a share of a hand's pace) before what is left is rests between them.",
		"default": 2.5, "least": 1.0, "most": 5.0, "unit": "x", "laws": ["paint"]},
	"rest_most": {"label": "Longest rest", "blurb": "The longest one rest between a painting act's elements may be, once its strokes are as slow as they go.",
		"default": 6.0, "least": 0.5, "most": 20.0, "unit": "s", "laws": ["paint"]},
	"move_pace": {"label": "Hand's pace", "blurb": "How fast a hand carries a tool from one element to the next, on average.",
		"default": 0.25, "least": 0.05, "most": 1.0, "unit": "m/s", "laws": ["paint"]},
	"laid_rest": {"label": "Laid rest", "blurb": "How long a thing set down lies before a hand takes it up again for its next move.",
		"default": 1.2, "least": 0.0, "most": 6.0, "unit": "s", "laws": ["to", "path", "carry"]},
}


## [param raw] (a show's `tune:` block) made safe: `{values: {key: number}, notes}` - each row's number within its bounds, a
## key with no row left out; every change said.
static func sanitize(raw: Variant) -> Dictionary:
	var values := {}
	var notes := PackedStringArray()
	if raw is Dictionary:
		for k in raw:
			var key := String(k)
			if not ROWS.has(key):
				notes.append("tune: \"%s\" is none of %s - left out" % [key, ", ".join(ROWS.keys())])
				continue
			var v: Variant = (raw as Dictionary)[k]
			if not (typeof(v) in [TYPE_INT, TYPE_FLOAT]):
				notes.append("tune: %s is a number - left at its default" % key)
				continue
			var row: Dictionary = ROWS[key]
			var safe := clampf(float(v), float(row["least"]), float(row["most"]))
			if safe != float(v):
				notes.append("tune: %s %.2f is outside %.2f to %.2f %s - made %.2f" % [key, float(v), float(row["least"]), float(row["most"]), String(row["unit"]), safe])
			values[key] = safe
	return {"values": values, "notes": notes}


## THE ROWS AS A FORM'S FIELDS ([SchemaForm]): each a number within its bounds - a slider beside its box - labeled and explained as
## its row is, with its unit. Given [param laws], only the rows that pace one of them (each row's `laws`): what an episode's acts
## use decides which numbers it may be tuned by - a show that paints nothing is offered no brush's ([TuneSection]).
static func fields(laws: Variant = null) -> Dictionary:
	var out := {}
	for k in ROWS:
		if laws is Array and not ((ROWS[k] as Dictionary)["laws"] as Array).any(func(l: Variant) -> bool: return (laws as Array).has(l)):
			continue
		var r: Dictionary = ROWS[k]
		out[k] = {"type": "float", "label": "%s (%s)" % [String(r["label"]), String(r["unit"])], "blurb": String(r["blurb"]),
			"default": float(r["default"]), "min": float(r["least"]), "max": float(r["most"])}
	return out


## [param key]'s number in [param tune] (made safe), its row's default where the show tells none.
static func value(tune: Dictionary, key: String) -> float:
	return float(tune.get(key, Registry.field(ROWS, key, "default", 0.0)))
