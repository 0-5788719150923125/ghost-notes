extends RefCounted
class_name Motions

## Motions - WORK AT THE TABLE as data (next/table_work.md): what a thing's parts can do, the LAWS that move
## them, and the ACTS an episode's puppeteer writes out of them. The user, 2026-10-25: a set dresser's clock
## "showed 3:00 precisely... but the hands never moved", and "I don't want to implement a baking mode, or
## an alchemy mode: I want to build a system that is flexible enough to allow agents to do this for
## themselves." So nothing here knows a clock, a pestle or a cauldron: a part can be JOINTED (a hinge, a
## slide, or free to be picked up), can carry named POINTS, and can CHANGE (how full it is, how big, its
## color, its glow, whether it is there); a LAW says how one of those goes over time; an ACT is a few laws
## on a few parts, cued by the reading.
##
## THREE LAYERS, all written by agents, all read here ([method sanitize_work], [method sanitize_acts]):
##   - the set dresser's: on a part, `name`, `joint`, `points`, `start` (a state it begins in), `runs` (a
##     law it follows all the time, from the opening: a clock's hands, a pendulum, a candle burning down)
##     and `emits` (smoke or steam rising from one of its points);
##   - the laws ([constant LAWS]): each a row, its words what an agent reads ([method describe_laws]);
##   - the puppeteer's acts (`acts.json` in the episode): each a beat's work - its tracks (a law on a
##     thing's part), its cues (a burst at a moment of it), how long it takes - played by [TableWork].
##
## EVERY LAW IS A CLOSED FORM OF TIME: the same moment gives the same pose, so a render, a scrub and a
## tool's picture agree. Any number a law takes may be a FORMULA instead ([Formula]): arithmetic of `t`
## (seconds into the act, or the show for a law that runs), `u` (how far through the act, 0 to 1), `d` (the
## act's length), `T` (show time) and `n` (whole periods done) - never code, which nothing here runs.
##
## UNITS ARE THE TABLE'S, as a set dresser writes them: centimeters and degrees, seconds; a place on the
## table is [x, y, z] centimeters from the middle of the reading (x to the reader's right, y up from the top,
## z toward the reader) or a thing's point by name, "mortar.floor".

## THE LAWS: what each does to what (`on`: the channels it can drive - `angle` a hinge's turn, `offset` a
## slide's travel, `pose` a free part's or a whole thing's place and turn, and the states), and its fields as
## an agent reads them.
const LAWS := {
	"turn": {"label": "Turn", "on": ["angle", "offset"],
		"blurb": "it goes on turning (or sliding) at a steady rate - a clock's hands, a turning mobile, a spinning top, a music box's drum, a wheel",
		"fields": [["rate", "degrees a second, counterclockwise as seen from where the hinge's `axis` points - negative turns it clockwise (a slide: centimeters a second); a clock's hands keep its time with `clock` instead"],
			["from", "where it starts, degrees from as it was built (left out: where it is)"],
			["tick", "steps a whole turn is made in, each a small jump that settles (60 for a ticking second hand; 0 turns smoothly)"]]},
	"clock": {"label": "Clock", "on": ["angle"],
		"blurb": "a clock's hand keeping the video's own time, turning clockwise as seen from where its hinge's `axis` points (point the axis out of the dial's face) - a hand's `runs`, so the clock is never stopped: a wall clock, a pocket watch, a chronometer, a kitchen timer's dial",
		"fields": [["hand", "\"hour\", \"minute\" or \"second\" (a second hand ticks)"],
			["shows", "the time \"H:MM\" the hand points at as it was built (left out: the time it starts at)"],
			["time", "the time \"H:MM\" the clock says as the video starts (left out: what it shows as built)"]]},
	"swing": {"label": "Swing", "on": ["angle", "offset", "fill", "grow", "glow", "emit", "boil"],
		"blurb": "it goes to and fro about where it is - a pendulum, a metronome, a rocking cradle, a balance's beam settling, a glow that breathes",
		"fields": [["amount", "how far each way (degrees, centimeters, or a share for a state)"],
			["period", "seconds a whole swing takes"], ["phase", "0-1, where in its swing it starts"],
			["settle", "seconds it takes to die away (0 or left out: it never does)"]]},
	"to": {"label": "To", "on": ["angle", "offset", "fill", "grow", "glow", "emit", "boil", "shown", "tint"],
		"blurb": "it goes to a new value and stays there - a lid opened, a drink changing color, a heap ground down, a pile rising, a light coming up, a thing appearing",
		"fields": [["value", "where it ends: degrees, centimeters, a share (fill, grow, glow, emit, shown), or a color \"#rrggbb\" for tint"],
			["from", "where it starts (left out: where it is)"], ["between", "[u0, u1]: the stretch of the act it moves in (left out: all of it)"],
			["ease", "\"both\" (slow in and out, the usual), \"in\", \"out\" or \"none\""]]},
	"path": {"label": "Path", "on": ["angle", "offset", "fill", "grow", "glow", "emit", "boil", "pose"],
		"blurb": "it goes through KEYS, on through each one as a hand goes (it stops only at a key it holds or turns back at, and at its last) - a knife's chop, a vial lifted and tipped and set down, a lid lifted and laid aside",
		"fields": [["keys", "[{at (0-1 through the act), value} ...] - or, for a part that moves freely, [{at, by: [x, y, z] centimeters from where it started, turn: [x, y, z] degrees from how it started}, ...]; the first key is where it is at the start"]]},
	"circle": {"label": "Circle", "on": ["pose"],
		"blurb": "it travels round and round a circle, keeping its turn - a spoon stirring, a whisk, a pendulum's bob seen from above",
		"fields": [["around", "the middle: a thing's point (\"bowl.middle\") or [x, y, z]"], ["lift", "centimeters above the middle"],
			["radius", "centimeters, or [across, deep] for an ellipse"], ["period", "seconds a round takes"],
			["dir", "1 clockwise seen from above, -1 against"], ["start", "degrees round where it begins (0 its right, 90 toward the reader)"],
			["press", "a thing's name: kept on that thing's surface below it, never through it"]]},
	"aim": {"label": "Aim", "on": ["pose"],
		"blurb": "a held tool posed by TWO of its points, each on its own way - a pestle grinding (its `tip` circling small in the bowl, its `grip` wider above), a whisk, a spoon stirring, a knife rocking on its point",
		"fields": [["tip", "the part's point that leads (by name) and its way: {point, circle or at or path fields} - `{\"point\": \"tip\", \"around\": \"bowl.floor\", \"radius\": 1.5, \"period\": 1.4, \"press\": \"bowl\"}`"],
			["grip", "its other point and its way, the same"], ["roll", "degrees it is turned about the line between them"]]},
	"carry": {"label": "Carry", "on": ["pose"],
		"blurb": "picked up, carried in an arc and set down somewhere else, turned on the way as a hand would - a jar fetched from the back of the table, a cup taken to the reader's side, a book set on a stack, a thing put back",
		"fields": [["to", "where its middle goes: a thing's point or [x, y, z]; left out, back where it was built"],
			["by", "[x, y, z] centimeters past that"], ["lift", "centimeters it rises on the way (6 is a hand's)"],
			["turn", "[x, y, z] degrees it ends turned, from as it was built"], ["between", "[u0, u1]: the stretch of the act it travels in"],
			["down", "true: SET DOWN on what is under it - its lowest point comes to rest on the table or on the thing below, however it is turned (a lid laid aside, a spoon put down on its side, a jar stood on a shelf); `to`'s height is then only roughly where"]]},
	"sprinkle": {"label": "Sprinkle", "on": [],
		"blurb": "a little of something falls from a point, as grains - a pinch of salt from fingers nobody sees, herbs crumbled off a bundle, seeds shaken from a pod, ash tapped off; they fall, land and heap or sink where they land, as any grains do. (A vessel needs no law to pour: tipped until what is in it reaches its rim, it pours by itself)",
		"fields": [["at", "where it falls from: a point (\"bundle.flowers\") or [x, y, z] - hold it over what it falls into"],
			["material", "a material of the table's (its look, how heavy it is, whether it dissolves)"],
			["grain", "a grain's size in centimeters (0.1 a powder, drawn as small clumps, to 1)"], ["amount", "how many grains fall (up to 120)"],
			["spread", "how wide it falls, centimeters (left out: 1)"], ["between", "[u0, u1]: when they fall"]]},
}
## THE CHANNELS a state can be: what a part's `start` and a law's `state` may name, as an agent reads it.
const STATES := {
	"fill": "how full a liquid or a heap is, 0-1 of how it was built (it is lowered from the top)",
	"grow": "how big it is, 0-2 of as built, about the middle of its base (0 is gone: a pinch dropped in, herbs ground away)",
	"tint": "its color, \"#rrggbb\" (a brew turning, a metal heating)",
	"glow": "light of its own, 0-1 (a potion lit from within, coals)",
	"shown": "whether it is there at all, 0 or 1",
	"emit": "how hard its `emits` smokes or steams, 0-2 of as written",
	"boil": "how hard a liquid bubbles, 0 (still, only stirring) to 2 (a rolling boil)",
}
## THE PLACES ON THE TABLE A LAW MAY NAME BY A WORD, beside a thing's points ([method _place]; [TableWork] finds
## them): where the work is done ([method TablePlan.work_spot]).
const SPOTS := {
	"work": "the work's spot: the middle of the picture, a little toward the reader, clear of what stands - where a thing is brought to be worked, seen large and whole. It is on the table's top: a thing carried there is set `down`",
}
## THE LAWS A PART MAY FOLLOW ALL THE TIME (its `runs`), as the set dresser is told them.
const RUNNING := ["clock", "turn", "swing", "to"]
## A clock's hands, each its degrees a second (the hour hand a turn in twelve hours) and the steps a turn ticks in.
const HANDS := {"hour": {"rate": 1.0 / 120.0, "tick": 0}, "minute": {"rate": 0.1, "tick": 0}, "second": {"rate": 6.0, "tick": 60}}
## The longest an act may run, and an act's length when "under" has nothing to measure yet (seconds).
const MAX_LENGTH := 120.0
const UNDER_GUESS := 12.0
## The most acts an episode has, tracks and cues one act has, keys a path has, points a part names, and
## parts a table works with.
const MAX_ACTS := 40
const MAX_TRACKS := 12
const MAX_CUES := 8
const MAX_KEYS := 16
const MAX_POINTS := 8
const MAX_WORKS := 192
## How far a thing's work may reach (centimeters): a place past it is no place on this table.
const REACH := 200.0
## THE KINDS OF SMOKE a part may emit, and how each looks: color, puffs a second, how fast they rise
## (m/s), how long they live (s), how big they are born (mm) and how much they grow.
const EMITS := {
	"steam": {"about": "white steam rising off something hot - a brew, a cup, a kettle's spout", "color": "#eef0f2", "rate": 7.0, "rise": 0.09, "life": 2.6, "size": 22.0, "grow": 2.6},
	"smoke": {"about": "a thread of gray smoke - incense, a snuffed wick, smoldering herbs", "color": "#b9b4ad", "rate": 4.0, "rise": 0.05, "life": 4.2, "size": 9.0, "grow": 3.2},
	"fumes": {"about": "a colored vapor curling off a brew or a flask", "color": "#9fe0b0", "rate": 5.0, "rise": 0.06, "life": 3.4, "size": 18.0, "grow": 2.4},
}
## The most puffs one emitter keeps in the air at once: a thread of smoke's trail ([method TableWork._plume]) for
## as long as its longest puff lives.
const MAX_PUFFS := 64
## The faintest a puff of a plume asked for less than a trail is drawn ([method TableWork._plume]).
const TRAIL_THIN := 0.3


## An EASE in and out over 0..1: slow to start, slow to end - a hand's move, as MINIMUM JERK has it ([method
## Hands.smooth]). The cubic in and out it had been stepped its acceleration from +12 to -12 at the middle of every
## move: a jolt half way, which the user saw as "somewhat jerky" (2026-10-28).
static func eased(x: float) -> float:
	return Hands.smooth(x)


## THROUGH ITS PLACES, NEVER STOPPING AT ONE (the-quiet-crucible 181083: the snowmelt's vial, carried the low way out
## of its rack, "started, and stopped, and started, and stopped ... about 4 times"): each place's slope, for values
## [param v] at times [param at] - Steffen's monotone cubic: where a value goes on the same way it goes on through,
## where it holds or turns back it stops there, and it never passes beyond a place (a move kept low never dips through
## what it is kept above). [param m0] and [param m1]: the slopes at the first and the last (at rest, zero).
static func slopes(at: PackedFloat32Array, v: PackedVector3Array, m0 := Vector3.ZERO, m1 := Vector3.ZERO) -> PackedVector3Array:
	var out := PackedVector3Array()
	out.resize(v.size())
	for i in v.size():
		if i == 0 or i == v.size() - 1:
			out[i] = m0 if i == 0 else m1
			continue
		var h0 := maxf(at[i] - at[i - 1], 1e-6)
		var h1 := maxf(at[i + 1] - at[i], 1e-6)
		var m := Vector3.ZERO
		for c in 3:
			var d0 := (v[i][c] - v[i - 1][c]) / h0
			var d1 := (v[i + 1][c] - v[i][c]) / h1
			if d0 * d1 > 0.0:
				var p := (d0 * h1 + d1 * h0) / (h0 + h1)
				m[c] = 2.0 * signf(d0) * minf(minf(absf(d0), absf(d1)), 0.5 * absf(p))
		out[i] = m
	return out


## From [param a] to [param b] over 0..1 ([param s]), leaving with slope [param ma] and arriving with [param mb] (each
## per the whole stretch): a cubic through both - and, both at rest, [method eased], as a single move is.
static func hermite(a: Vector3, b: Vector3, ma: Vector3, mb: Vector3, s: float) -> Vector3:
	var u := clampf(s, 0.0, 1.0)
	if ma == Vector3.ZERO and mb == Vector3.ZERO:
		return a.lerp(b, eased(u))
	var u2 := u * u
	var u3 := u2 * u
	return a * (2.0 * u3 - 3.0 * u2 + 1.0) + ma * (u3 - 2.0 * u2 + u) + b * (3.0 * u2 - 2.0 * u3) + mb * (u3 - u2)


## The value at [param x] through values [param v] at times [param at] with slopes [param m] ([method slopes]): held
## at the first before it, at the last after.
static func through(at: PackedFloat32Array, v: PackedVector3Array, m: PackedVector3Array, x: float) -> Vector3:
	if v.is_empty():
		return Vector3.ZERO
	if x <= at[0]:
		return v[0]
	for i in v.size() - 1:
		if x <= at[i + 1]:
			var h := maxf(at[i + 1] - at[i], 1e-6)
			return hermite(v[i], v[i + 1], m[i] * h, m[i + 1] * h, (x - at[i]) / h)
	return v[v.size() - 1]


## [param x] through [param kind]'s ease: "both", "in", "out" or "none".
static func ease_by(x: float, kind: String) -> float:
	var u := clampf(x, 0.0, 1.0)
	match kind:
		"in":
			return u * u * u
		"out":
			return 1.0 - pow(1.0 - u, 3.0)
		"none":
			return u
	return eased(u)


## THE NAMES a formula in a law may use ([Formula]).
const VARS := ["t", "u", "d", "T", "n"]


# --- describing ---------------------------------------------------------------------------------

## WHAT A PART CAN DO, as a set dresser reads it ([TablePrompts.set_dresser], beside [method Props.describe]).
static func describe_parts() -> String:
	var lines := PackedStringArray()
	lines.append("WORKING PARTS. A part (or a group) can do more than stand: give it a `name` (unique in its thing) and what it can do -")
	lines.append("- `joint`: how it can move - {\"kind\": \"hinge\" (it turns about `axis` through `at`: a clock's hand, a lid, a balance's beam), \"slide\" (it moves along `axis`: a cork, a drawer), or \"free\" (it can be picked up and moved anywhere: a pestle, a spoon, a vial, a knife), \"at\": [x, y, z] (in the thing's own centimeters, as a part's `at` is: the pivot - a hand's at the middle of the dial; left out, the part's middle), \"axis\": [x, y, z] (left out: up), \"range\": [least, most] (degrees, or centimeters for a slide)}. A whole thing can always be picked up and moved: it needs no joint.")
	lines.append("- `points`: {\"name\": [x, y, z], ...} in the thing's own centimeters - the places the work holds and reaches with: a tool's `tip` and `grip`, a jug's `lip`, a bowl's `floor`, a pot's `mouth` (the middle of its liquid's top). At most %d." % MAX_POINTS)
	lines.append("- `start`: the state it begins in, when not as built - {\"fill\": 0.2} a vessel nearly empty, {\"grow\": 0} powder not yet ground, {\"shown\": 0} not there yet, {\"tint\": \"#rrggbb\"}, {\"glow\": 0.3}. States:")
	for k in STATES:
		lines.append("  - %s: %s" % [k, STATES[k]])
	lines.append("- `runs`: a law it follows ALL THE TIME, from the start of the video - a clock's hands keeping the video's own time (`clock`, each hand jointed as a hinge), a pendulum swinging, a mobile turning, a brew's glow breathing (`swing` on `glow`), the sand of an hourglass running down `to` a lower `fill` over the episode's minutes (`between` is then in seconds of the video). Anything that moves in the world moves here: a clock that runs, never one stopped. Never on a lit candle's wax: its flame stays where it was lit.")
	# THE LAWS A PART MAY RUN, in full: told only that `runs` takes "a law", the first real set dresser wrote
	# {"clock": "hour"} on each hand and {"glow": {"every": 7, "swing": [0.5, 0.8]}} on its coals, and nothing ran
	lines.append("  A `runs` law is {\"law\": one of these, its fields} (on a state, name the state in `state`; a list runs several):")
	for k in RUNNING:
		var row: Dictionary = LAWS[k]
		var fields := PackedStringArray()
		for f in row["fields"]:
			fields.append("`%s` %s" % [String(f[0]), String(f[1])])
		lines.append("  - %s: %s. %s." % [k, String(row["blurb"]), "; ".join(fields)])
	lines.append("  (a running `to` takes its `between` in seconds of the video.)")
	lines.append("- `emits`: {\"kind\": %s, \"at\": a point's name, \"rate\" (how thick it rises, in puffs a second: fewer than its kind's own is a fainter trail, never a broken one), \"color\"} - smoke or steam rising from it all the time, carried by the table's wind." % " or ".join(PackedStringArray(EMITS.keys())))
	for k in EMITS:
		lines.append("  - %s: %s" % [k, String((EMITS[k] as Dictionary)["about"])])
	lines.append("- material \"liquid\": what is IN a vessel - a brew, ink, oil, wine, water - as its own part filling the vessel's inside from its floor to the liquid's surface (a hollow part: its profile comes back down inside it); give it a `name` so the work can tint and light it. It is REAL: its surface stays level however its vessel is turned, it slops when its vessel is carried and turns when it is stirred, it pours over the rim once it is tipped far enough, and things that fall into it ring it, splash it, sink in it or float on it. A vessel's inside is as deep as the vessel is: draw it full only as far as it is full. A stopper across its mouth (a part of the same thing there) keeps it in, until the work takes the stopper away (`shown` 0).")
	lines.append("- WHAT IS IN A THING IS WHAT IT IS (next/table_physics.md): a liquid is a liquid part, loose stuff poured in quantity is a `grains` part in its vessel, a loose thing lying in or on something is `loose`; each falls, pours, tumbles and lands for real when what holds it tips.")
	return "\n".join(lines)


## THE LAWS, as a puppeteer reads them: each with what it drives and its fields.
static func describe_laws() -> String:
	var lines := PackedStringArray()
	lines.append("LAWS (a track's `law`), and what each can drive - `angle` (a hinge), `offset` (a slide), `pose` (a free part or a whole thing), or a state:")
	for k in LAWS:
		var row: Dictionary = LAWS[k]
		var on := ", ".join(PackedStringArray(row["on"])) if not (row["on"] as Array).is_empty() else "the vessels it names"
		lines.append("- %s (%s): %s." % [k, on, String(row["blurb"])])
		for f in row["fields"]:
			lines.append("    `%s`: %s" % [String(f[0]), String(f[1])])
	lines.append("Any number may be a formula instead, a string of arithmetic in t (seconds into the act), u (0-1 through it), d (its length), T (the video's time) and n (whole periods done): \"30 * sin(tau * t / 2)\". Functions: %s." % ", ".join(PackedStringArray(Formula.FUNCS.keys())))
	lines.append("Any track may add `jitter` (centimeters or degrees of a hand's unsteadiness) and `rate` (how quickly it wanders, per second) - a held thing already moves as a hand holds it: never quite still, bowed a little as it is carried, leaning with the pull of its moves.")
	lines.append("")
	lines.append("WHAT IS IN THINGS IS REAL (there is no law for it): a LIQUID stays level in its vessel, sloshes as it is carried and swirls as it is stirred; tipped until it reaches the rim it POURS BY ITSELF from the lowest point of the rim, faster the further it is tipped, in a stream that falls under gravity into whatever is under it - and nothing pours from a vessel stoppered or not tipped far enough. GRAINS in a vessel slide and spill out of its mouth when it is tipped. A LOOSE thing slides, rolls and tumbles out of what holds it when that is tipped, falls, and sinks or floats in a liquid; carried by a law, it is held, and falls from where it is let go. A tool `press`ed into loose things and moved over them (a pestle going round in a bowl) CRUSHES them - stones and crystals break into pieces and the pieces into powder; metal, glass and wood never break. To pour or tip something out: bring the vessel over what is to catch it, tip it across the view and hold it there for as long as it should flow, then tip it back.")
	return "\n".join(lines)


## THE TABLE'S WORKING PARTS IN WORDS, from [param things] as the table makes them safe
## ([method CardTable.sanitize_table]): each thing, where it was written to stand, whether it holds a flame,
## and each named part with its joint, points and states - for a puppeteer told the table before it is stood
## ([TablePrompts.puppeteer]; its `parts` tool says where each point is once it is).
static func table_text(things: Array) -> String:
	var lines := PackedStringArray()
	for t in things:
		var th: Dictionary = t
		var at: Variant = th.get("at")
		var where := ""
		if at is Vector2:
			where = " - written at [%.0f, %.0f] cm" % [(at as Vector2).x, (at as Vector2).y]
		elif at is Array and (at as Array).size() == 2:
			where = " - written at [%s, %s] cm" % [str(at[0]), str(at[1])]
		lines.append("- \"%s\"%s%s" % [String(th.get("name", "")), where, " - it holds a flame and is never moved whole" if Props._burns(th.get("parts", [])) else ""])
		_parts_text(th.get("parts", []), lines, "    ")
	return "\n".join(lines)


static func _parts_text(parts: Array, lines: PackedStringArray, pad: String) -> void:
	for p in parts:
		var d: Dictionary = p
		var w: Dictionary = d.get("work", {}) if d.get("work") is Dictionary else {}
		if not w.is_empty():
			var bits := PackedStringArray()
			if w.get("joint") is Dictionary:
				bits.append("%s joint" % String((w["joint"] as Dictionary)["kind"]))
			if w.get("points") is Dictionary:
				bits.append("points " + ", ".join(PackedStringArray((w["points"] as Dictionary).keys())))
			if w.has("start"):
				bits.append("starts " + JSON.stringify(w["start"]))
			if w.has("runs"):
				bits.append("runs")
			if w.has("emits"):
				bits.append("emits " + String((w["emits"] as Dictionary)["kind"]))
			if bool(w.get("loose", false)):
				bits.insert(0, "loose")
			if String(d.get("shape", "")) == "grains":
				bits.insert(0, "grains")
			# a part with copies is worked as one by its name, a copy alone by its number ([method TableWork._part_of])
			var n := int((d["copies"] as Dictionary).get("count", 1)) if d.get("copies") is Dictionary else 1
			if n > 1:
				var nm := String(w.get("name", ""))
				bits.insert(0, "%d copies - \"%s\" works them all as one, \"%s 1\" to \"%s %d\" one alone" % [n, nm, nm, nm, n])
			lines.append("%s- part \"%s\" (%s): %s" % [pad, String(w.get("name", "")), String(d.get("shape", "a group")),
				"; ".join(bits) if not bits.is_empty() else "it changes (fill, grow, tint, glow, shown)"])
		if d.get("parts") is Array:
			_parts_text(d["parts"], lines, pad + "  ")


# --- sanitizing: a part's work -----------------------------------------------------------------

## A PART'S WORK made safe, from what an agent wrote on it ([param p]): `{name, joint, points, start, runs,
## emits}` - only what it has, `{}` when it does none of it. Notes for the agent go in [param notes].
static func sanitize_work(p: Dictionary, notes: PackedStringArray = PackedStringArray()) -> Dictionary:
	var out := {}
	var nm := Props._text(p.get("name", ""), 60) if p.get("name") is String else ""
	if not nm.is_empty():
		out["name"] = nm
	if p.get("joint") is Dictionary:
		var j: Dictionary = p["joint"]
		var kind := String(j.get("kind", "")).strip_edges().to_lower()
		if kind in ["hinge", "slide", "free"]:
			var jo := {"kind": kind}
			if j.has("at"):
				jo["at"] = Props._vec3(j.get("at"), Vector3.ZERO, Props.MAX_SIZE)
			var ax := Props._vec3(j.get("axis"), Vector3.UP, 1e6)
			jo["axis"] = ax.normalized() if ax.length() > 1e-6 else Vector3.UP
			if j.get("range") is Array and (j["range"] as Array).size() == 2:
				var a := float(Props._num((j["range"] as Array)[0], 0.0, -3600.0, 3600.0))
				var b := float(Props._num((j["range"] as Array)[1], 0.0, -3600.0, 3600.0))
				jo["range"] = Vector2(minf(a, b), maxf(a, b))
			out["joint"] = jo
		else:
			notes.append("%s's joint: \"%s\" is not hinge, slide or free - it stands still" % [nm if not nm.is_empty() else "a part", kind])
	if p.get("points") is Dictionary:
		var pts := {}
		for k in p["points"]:
			if pts.size() >= MAX_POINTS:
				break
			var key := Props._text(k, 40)
			if not key.is_empty() and (p["points"] as Dictionary)[k] is Array:
				pts[key] = Props._vec3((p["points"] as Dictionary)[k], Vector3.ZERO, Props.MAX_SIZE)
		if not pts.is_empty():
			out["points"] = pts
	var start := _states(p.get("start"))
	if not start.is_empty():
		out["start"] = start
	if p.has("runs"):
		var runs: Array = []
		for r in (p["runs"] if p["runs"] is Array else [p["runs"]]):
			var law := sanitize_law(r, notes, true)
			if not law.is_empty():
				runs.append(law)
		if not runs.is_empty():
			out["runs"] = runs.slice(0, 3)
	if p.get("emits") is Dictionary:
		var e: Dictionary = p["emits"]
		var kind := String(e.get("kind", "steam")).strip_edges().to_lower()
		if EMITS.has(kind):
			var base: Dictionary = EMITS[kind]
			out["emits"] = {"kind": kind, "at": Props._text(e.get("at", ""), 40),
				"rate": Props._num(e.get("rate"), float(base["rate"]), 0.2, 20.0),
				"color": Props._color(e.get("color", ""), String(base["color"]))}
	# LOOSE ([Particles]): not fixed to its thing - it lies where it is, falls, slides and tumbles when nothing holds it,
	# and is picked up as a free part is (a strand's own `loose` is a number, how unkempt it lies: [method Props._sanitize_part])
	var lv: Variant = p.get("loose")
	if (lv is bool and lv) or ((lv is float or lv is int) and float(lv) >= 1.0):
		out["loose"] = true
		if not out.has("joint"):
			out["joint"] = {"kind": "free", "axis": Vector3.UP}
	return out


## A part's states as written ([constant STATES]): numbers in range, a tint a color.
static func _states(v: Variant) -> Dictionary:
	var out := {}
	if not (v is Dictionary):
		return out
	for k in v:
		var key := String(k).strip_edges().to_lower()
		match key:
			"tint":
				if Props._is_color((v as Dictionary)[k]):
					out["tint"] = Props._color((v as Dictionary)[k], "#808080")
			"fill", "shown":
				out[key] = Props._num((v as Dictionary)[k], 1.0, 0.0, 1.0)
			"grow", "emit", "boil":
				out[key] = Props._num((v as Dictionary)[k], 1.0, 0.0, 2.0)
			"glow":
				out[key] = Props._num((v as Dictionary)[k], 0.0, 0.0, 1.0)
	return out


# --- sanitizing: laws and acts --------------------------------------------------------------------

## A NUMBER A LAW TAKES, made safe: the number in [lo, hi], or a formula ([Formula]) kept compiled
## (`{f: steps, lo, hi}`) and held to the range when it is worked; [param fallback] when neither will do.
static func _num(v: Variant, fallback: float, lo: float, hi: float, notes: PackedStringArray, what: String) -> Variant:
	if v is String:
		var c := Formula.compile(String(v), PackedStringArray(VARS))
		if bool(c["ok"]):
			return {"f": c["code"], "lo": lo, "hi": hi, "text": String(v).substr(0, 200)}
		notes.append("%s: %s - %s used instead" % [what, String(c["error"]), str(fallback)])
		return fallback
	return Props._num(v, fallback, lo, hi)


## A number a law took ([method _num]) worked out with [param vars].
static func num(v: Variant, vars: Dictionary) -> float:
	if v is Dictionary:
		return clampf(Formula.run((v as Dictionary)["f"], vars), float((v as Dictionary)["lo"]), float((v as Dictionary)["hi"]))
	return float(v)


## A stretch of an act, `[u0, u1]`, made safe: within 0..1, the first before the second.
static func _between(v: Variant) -> Vector2:
	if v is Array and (v as Array).size() == 2:
		var a := clampf(float(Props._num((v as Array)[0], 0.0, 0.0, 1.0)), 0.0, 1.0)
		var b := clampf(float(Props._num((v as Array)[1], 1.0, 0.0, 1.0)), 0.0, 1.0)
		if b > a + 0.01:
			return Vector2(a, b)
	return Vector2(0.0, 1.0)


## A PLACE A LAW NAMES: a thing's point by name ("mortar.floor"), kept as text for [TableWork] to find, or
## [x, y, z] centimeters on the table; null for neither.
static func _place(v: Variant) -> Variant:
	if v is String and SPOTS.has(String(v).strip_edges().to_lower()):
		return String(v).strip_edges().to_lower()
	if v is String and String(v).strip_edges().contains("."):
		return Props._text(v, 100)
	if v is Array and (v as Array).size() >= 2:
		return Props._vec3(v, Vector3.ZERO, REACH)
	return null


## A LAW made safe ([constant LAWS]): `{law, ...its fields}`, `{}` for one with no law ghost knows. [param
## running]: a part's `runs`, timed by the video, where `between` and `over` are seconds of it.
static func sanitize_law(raw: Variant, notes: PackedStringArray, running := false) -> Dictionary:
	if not (raw is Dictionary):
		return {}
	var d: Dictionary = raw
	var law := String(d.get("law", "")).strip_edges().to_lower()
	# a hand written as the clock it is ({"clock": "minute"}, as the first real set dresser wrote all three)
	if law.is_empty() and d.get("clock") is String:
		d = d.duplicate()
		d["hand"] = d["clock"]
		law = "clock"
	if not LAWS.has(law):
		if law.is_empty():
			notes.append("%s names no `law` - write {\"law\": one of %s, and its fields}" % [JSON.stringify(d).left(80), ", ".join(PackedStringArray(LAWS.keys()))])
		else:
			notes.append("\"%s\" is not a law (the laws: %s)" % [law, ", ".join(PackedStringArray(LAWS.keys()))])
		return {}
	var out := {"law": law}
	var st := String(d.get("state", "")).strip_edges().to_lower()
	if STATES.has(st):
		out["state"] = st
	match law:
		"turn":
			out["rate"] = _num(d.get("rate"), 6.0, -3600.0, 3600.0, notes, "turn's rate")
			if d.has("from"):
				out["from"] = _num(d.get("from"), 0.0, -36000.0, 36000.0, notes, "turn's from")
			out["tick"] = int(Props._num(d.get("tick"), 0.0, 0.0, 3600.0))
		"clock":
			var hand := String(d.get("hand", "")).strip_edges().to_lower()
			if not HANDS.has(hand):
				notes.append("a clock's `hand` is hour, minute or second (\"%s\") - it stands still" % hand)
				return {}
			if not running:
				notes.append("a clock is a hand's `runs`, kept all through the video - not an act's")
				return {}
			out["hand"] = hand
			# THE HAND MOVED ON from what it shows as built to the time the video starts at (clockwise, the short
			# way or the long - a hand reads the same either way)
			var shows := _hours(d.get("shows"))
			var at := _hours(d.get("time"))
			out["ahead"] = hand_degrees(hand, at) - hand_degrees(hand, shows) if not (is_nan(shows) or is_nan(at)) else 0.0
		"swing":
			out["amount"] = _num(d.get("amount"), 10.0, -360.0, 360.0, notes, "swing's amount")
			out["period"] = _num(d.get("period"), 2.0, 0.05, 600.0, notes, "swing's period")
			out["phase"] = Props._num(d.get("phase"), 0.0, 0.0, 1.0)
			out["settle"] = Props._num(d.get("settle"), 0.0, 0.0, 3600.0)
		"to":
			if st == "tint" or Props._is_color(d.get("value")):
				out["state"] = "tint"
				out["value"] = Props._color(d.get("value", ""), "#808080")
				if Props._is_color(d.get("from")):
					out["from"] = Props._color(d["from"], "#808080")
			else:
				out["value"] = _num(d.get("value"), 1.0, -36000.0, 36000.0, notes, "to's value")
				if d.has("from"):
					out["from"] = _num(d.get("from"), 0.0, -36000.0, 36000.0, notes, "to's from")
			out["ease"] = String(d.get("ease", "both")).strip_edges().to_lower() if String(d.get("ease", "both")).strip_edges().to_lower() in ["both", "in", "out", "none"] else "both"
			if running:
				# A RUNNING `to` IS TIMED BY THE VIDEO: from the opening over its `between` seconds (a candle
				# burning down over twenty minutes)
				var w: Variant = d.get("between", d.get("over"))
				var span := Vector2(0.0, 600.0)
				if w is Array and (w as Array).size() == 2:
					span = Vector2(float(Props._num((w as Array)[0], 0.0, 0.0, 36000.0)), float(Props._num((w as Array)[1], 600.0, 0.0, 36000.0)))
				elif w is float or w is int:
					span = Vector2(0.0, float(Props._num(w, 600.0, 1.0, 36000.0)))
				out["span"] = Vector2(minf(span.x, span.y), maxf(span.y, span.x + 1.0))
			else:
				out["between"] = _between(d.get("between"))
		"path":
			var keys: Array = []
			for k in (d.get("keys", []) if d.get("keys") is Array else []):
				if keys.size() >= MAX_KEYS or not (k is Dictionary):
					continue
				var kd: Dictionary = k
				var key := {"at": clampf(float(Props._num(kd.get("at"), float(keys.size()) / maxf(float((d["keys"] as Array).size() - 1), 1.0), 0.0, 1.0)), 0.0, 1.0)}
				if kd.has("value"):
					key["value"] = _num(kd.get("value"), 0.0, -36000.0, 36000.0, notes, "a path key's value")
				if kd.has("by"):
					key["by"] = Props._vec3(kd.get("by"), Vector3.ZERO, REACH)
				if kd.has("turn"):
					key["turn"] = Props._vec3(kd.get("turn"), Vector3.ZERO, 3600.0)
				keys.append(key)
			keys.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["at"]) < float(b["at"]))
			if keys.size() < 2:
				notes.append("a path needs two keys at least - it stands still")
				return {}
			out["keys"] = keys
		"circle":
			_point_law(d, out, notes)
		"aim":
			for end in ["tip", "grip"]:
				if not (d.get(end) is Dictionary):
					notes.append("aim needs a `%s`: {point, and its way}" % end)
					return {}
				var e: Dictionary = d[end]
				var o := {"point": Props._text(e.get("point", end), 40)}
				_point_law(e, o, notes)
				out[end] = o
			out["roll"] = _num(d.get("roll"), 0.0, -3600.0, 3600.0, notes, "aim's roll")
		"carry":
			var to: Variant = _place(d.get("to"))
			if to != null:
				out["to"] = to
			out["by"] = Props._vec3(d.get("by"), Vector3.ZERO, REACH)
			out["lift"] = Props._num(d.get("lift"), 6.0, 0.0, 60.0)
			if d.has("turn"):
				out["turn"] = Props._vec3(d.get("turn"), Vector3.ZERO, 3600.0)
			out["between"] = _between(d.get("between"))
			if d.get("down") == true:
				out["down"] = true
		"sprinkle":
			var at: Variant = _place(d.get("at"))
			if at != null:
				out["at"] = at
			out["material"] = Props._text(d.get("material", ""), 60)
			out["grain"] = Props._num(d.get("grain"), 0.3, 0.05, 1.5)
			out["amount"] = int(Props._num(d.get("amount"), 24.0, 1.0, 120.0))
			out["spread"] = Props._num(d.get("spread"), 1.0, 0.0, 10.0)
			out["between"] = _between(d.get("between"))
	if d.has("jitter"):
		out["jitter"] = Props._num(d.get("jitter"), 0.0, 0.0, 5.0)
		out["rate"] = Props._num(d.get("rate"), 0.7, 0.05, 8.0)
	return out


## A TIME OF DAY as a clock's face is read, "H:MM" or "H:MM:SS", in hours - NAN for none.
static func _hours(v: Variant) -> float:
	if not (v is String):
		return NAN
	var bits := String(v).strip_edges().split(":")
	if bits.size() < 2 or bits.size() > 3 or not bits[0].strip_edges().is_valid_int() or not bits[1].strip_edges().is_valid_int():
		return NAN
	var s := float(bits[2].strip_edges()) if bits.size() == 3 and bits[2].strip_edges().is_valid_float() else 0.0
	return float(int(bits[0]) % 12) + float(int(bits[1])) / 60.0 + s / 3600.0


## Where clock hand [param hand] points at [param hours] past twelve, in degrees clockwise from twelve.
static func hand_degrees(hand: String, hours: float) -> float:
	match hand:
		"hour":
			return fposmod(hours, 12.0) * 30.0
		"minute":
			return fposmod(hours * 60.0, 60.0) * 6.0
	return fposmod(hours * 3600.0, 60.0) * 6.0


## THE WAY A POINT GOES ([param d], a circle's or an aim's end): `at` a fixed place, round `around`, or
## through a path's keys - its fields into [param out].
static func _point_law(d: Dictionary, out: Dictionary, notes: PackedStringArray) -> void:
	if d.has("around"):
		var c: Variant = _place(d.get("around"))
		if c == null:
			notes.append("`around` names no place - its middle is where it starts")
		else:
			out["around"] = c
		out["lift"] = _num(d.get("lift"), 0.0, -REACH, REACH, notes, "lift")
		var r: Variant = d.get("radius")
		if r is Array and (r as Array).size() == 2:
			out["radius"] = Vector2(float(Props._num((r as Array)[0], 2.0, 0.0, REACH)), float(Props._num((r as Array)[1], 2.0, 0.0, REACH)))
		else:
			var rr := float(Props._num(r, 2.0, 0.0, REACH))
			out["radius"] = Vector2(rr, rr)
		out["period"] = _num(d.get("period"), 1.5, 0.05, 600.0, notes, "period")
		out["dir"] = -1.0 if float(Props._num(d.get("dir"), 1.0, -1.0, 1.0)) < 0.0 else 1.0
		out["start"] = Props._num(d.get("start"), 0.0, -3600.0, 3600.0)
	elif d.has("at"):
		var a: Variant = _place(d.get("at"))
		if a != null:
			out["at"] = a
	elif d.get("keys") is Array:
		var keys: Array = []
		for k in d["keys"]:
			if k is Dictionary and keys.size() < MAX_KEYS:
				var p: Variant = _place((k as Dictionary).get("at_place", (k as Dictionary).get("place")))
				var key := {"at": clampf(float(Props._num((k as Dictionary).get("at"), 0.0, 0.0, 1.0)), 0.0, 1.0),
					"by": Props._vec3((k as Dictionary).get("by"), Vector3.ZERO, REACH)}
				if p != null:
					key["place"] = p
				keys.append(key)
		keys.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["at"]) < float(b["at"]))
		if keys.size() >= 2:
			out["keys"] = keys
	if d.has("press"):
		out["press"] = Props._text(d.get("press", ""), 100)
		out["gap"] = Props._num(d.get("gap"), 0.15, 0.0, 5.0)


## THE ACTS an episode's puppeteer wrote (`acts.json`), made safe: `{acts: [{name, about, beat, length,
## under, tracks, cues}], notes}` - each act's `beat` "intro", "close" or a beat's place (1..[param beats]:
## a card's, or in a show that draws none its own - [method CardTable.beats]); a track `{thing, part, state,
## ...its law}`; a cue `{at, every, where, burst}`. What cannot be kept is said in `notes`.
static func sanitize_acts(raw: Variant, beats: int) -> Dictionary:
	var notes := PackedStringArray()
	var acts: Array = []
	var names := {}
	var list: Variant = (raw as Dictionary).get("acts", []) if raw is Dictionary else raw
	for a in (list if list is Array else []):
		if acts.size() >= MAX_ACTS or not (a is Dictionary):
			continue
		var d: Dictionary = a
		var nm := Manuscript.slug(String(d.get("name", ""))) if d.get("name") is String else ""
		if nm.is_empty() or names.has(nm):
			notes.append("an act needs a name of its own (\"%s\")" % str(d.get("name", "")))
			continue
		var beat: Variant = d.get("beat", "")
		var b := ""
		if beat is String and String(beat).strip_edges().to_lower() in ["intro", "close"]:
			b = String(beat).strip_edges().to_lower()
		elif (beat is float or beat is int) and int(beat) >= 1 and int(beat) <= beats:
			b = str(int(beat))
		elif beat is String and String(beat).is_valid_int() and int(beat) >= 1 and int(beat) <= beats:
			b = str(int(beat))
		if b.is_empty():
			notes.append("%s: its `beat` is \"intro\", \"close\" or a beat's place 1-%d - left out" % [nm, beats])
			continue
		var act := {"name": nm, "about": Props._text(d.get("about", ""), 300), "beat": b}
		var ln: Variant = d.get("length", 6.0)
		if ln is String and String(ln).strip_edges().to_lower() == "under":
			act["under"] = true
			act["length"] = UNDER_GUESS
		else:
			act["under"] = false
			act["length"] = Props._num(ln, 6.0, 0.3, MAX_LENGTH)
		var tracks: Array = []
		for t in (d.get("tracks", []) if d.get("tracks") is Array else []):
			if tracks.size() >= MAX_TRACKS or not (t is Dictionary):
				continue
			var law := sanitize_law(t, notes)
			if law.is_empty():
				continue
			var thing := Props._text((t as Dictionary).get("thing", ""), 100)
			if thing.is_empty() and String(law["law"]) != "sprinkle":
				notes.append("%s: a track names no thing - left out" % nm)
				continue
			law["thing"] = thing
			law["part"] = Props._text((t as Dictionary).get("part", ""), 60)
			tracks.append(law)
		if tracks.is_empty():
			notes.append("%s: nothing in it moves - left out" % nm)
			continue
		act["tracks"] = tracks
		var cues: Array = []
		for c in (d.get("cues", []) if d.get("cues") is Array else []):
			if cues.size() >= MAX_CUES or not (c is Dictionary):
				continue
			var cd: Dictionary = c
			var where: Variant = _place(cd.get("where"))
			if where == null or not (cd.get("burst") is Dictionary):
				notes.append("%s: a cue is {at or every, where (a point), burst: {look, ...}} - left out" % nm)
				continue
			var cue := {"where": where, "burst": (cd["burst"] as Dictionary).duplicate(true)}
			if cd.has("every"):
				cue["every"] = Props._num(cd.get("every"), 1.0, 0.2, 60.0)
			else:
				cue["at"] = clampf(float(Props._num(cd.get("at"), 0.0, 0.0, 1.0)), 0.0, 1.0)
			cues.append(cue)
		act["cues"] = cues
		names[nm] = true
		acts.append(act)
	return {"acts": acts, "notes": notes}


## The acts of [param beat] ("intro", "close", or a card's place), in the order written.
static func of_beat(acts: Array, beat: String) -> Array:
	return acts.filter(func(a: Dictionary) -> bool: return String(a["beat"]) == beat)


# --- the laws, worked ---------------------------------------------------------------------------------

## A SCALAR CHANNEL under [param law] at [param t] seconds into an act of [param d] seconds, from [param
## from] (where it was as the act began) - an angle, an offset or a state's number. [param T]: show time.
static func scalar(law: Dictionary, from: float, t: float, d: float, T: float) -> float:
	var u := clampf(t / maxf(d, 1e-6), 0.0, 1.0)
	var vars := {"t": t, "u": u, "d": d, "T": T, "n": 0.0}
	var out := from
	match String(law["law"]):
		"turn":
			var base := num(law["from"], vars) if law.has("from") else from
			var deg := num(law["rate"], vars) * t
			var tick := int(law.get("tick", 0))
			if tick > 0:
				# A TICK: a jump to the next step, a quick settle past it and back (a clock's second hand) - either way round
				var step := 360.0 / float(tick)
				var at := absf(deg) / step
				var whole := floorf(at)
				var into := (at - whole) * step / maxf(absf(num(law["rate"], vars)), 1e-6)
				var settle := exp(-into * 18.0) * sin(into * 40.0) * 0.12 * step
				deg = signf(deg) * (whole * step + settle)
			out = base + deg
		"clock":
			# CLOCKWISE seen from where the hinge's axis points: a turn the other way about it
			var hand: Dictionary = HANDS[String(law["hand"])]
			var deg := float(hand["rate"]) * t
			var tick := int(hand["tick"])
			if tick > 0:
				var step := 360.0 / float(tick)
				var whole := floorf(deg / step)
				var into := (deg - whole * step) / float(hand["rate"])
				deg = whole * step + exp(-into * 18.0) * sin(into * 40.0) * 0.12 * step
			out = from - float(law.get("ahead", 0.0)) - deg
		"swing":
			var period := num(law["period"], vars)
			vars["n"] = floorf(t / maxf(period, 1e-6))
			var amp := num(law["amount"], vars)
			var settle := float(law.get("settle", 0.0))
			var fade := exp(-t / settle) if settle > 0.0 else 1.0
			out = from + amp * fade * sin(TAU * (t / maxf(period, 1e-6) + float(law.get("phase", 0.0))))
		"to":
			var a := num(law["from"], vars) if law.has("from") and not (law["from"] is String) else from
			var b := num(law["value"], vars) if not (law["value"] is String) else from
			var w: Vector2 = law.get("between", Vector2(0.0, 1.0))
			var s := 0.0
			if law.has("span"):
				var span: Vector2 = law["span"]
				s = ease_by((T - span.x) / maxf(span.y - span.x, 1e-6), String(law.get("ease", "both")))
			else:
				s = ease_by((u - w.x) / maxf(w.y - w.x, 1e-6), String(law.get("ease", "both")))
			out = lerpf(a, b, s)
		"path":
			var keys: Array = law["keys"]
			out = _key_value(keys, 0, vars, from)
			for i in range(keys.size() - 1):
				var k0: Dictionary = keys[i]
				var k1: Dictionary = keys[i + 1]
				if u >= float(k0["at"]) and u <= float(k1["at"]):
					var s := eased((u - float(k0["at"])) / maxf(float(k1["at"]) - float(k0["at"]), 1e-6))
					out = lerpf(_key_value(keys, i, vars, from), _key_value(keys, i + 1, vars, from), s)
					break
				if u > float(k1["at"]):
					out = _key_value(keys, i + 1, vars, from)
	if law.has("jitter") and float(law["jitter"]) > 0.0:
		out += float(law["jitter"]) * Formula.noise1(t * float(law.get("rate", 0.7)) + 17.3)
	return out


## Key [param i]'s value, or [param from] for a key that names none (the first, most often).
static func _key_value(keys: Array, i: int, vars: Dictionary, from: float) -> float:
	var k: Dictionary = keys[i]
	return num(k["value"], vars) if k.has("value") else from


## A COLOR under a `to` law at [param t] of [param d]: from [param from] toward its value.
static func tint(law: Dictionary, from: Color, t: float, d: float, T: float) -> Color:
	var u := clampf(t / maxf(d, 1e-6), 0.0, 1.0)
	var a := Color.html(String(law["from"])) if law.has("from") and law["from"] is String else from
	var b := Color.html(String(law["value"])) if law["value"] is String else from
	var s := 0.0
	if law.has("span"):
		var span: Vector2 = law["span"]
		s = ease_by((T - span.x) / maxf(span.y - span.x, 1e-6), String(law.get("ease", "both")))
	else:
		var w: Vector2 = law.get("between", Vector2(0.0, 1.0))
		s = ease_by((u - w.x) / maxf(w.y - w.x, 1e-6), String(law.get("ease", "both")))
	return a.lerp(b, s)


## WHERE A POINT IS under a point law ([method _point_law]'s fields in [param law]) at [param t] of [param
## d]: round its middle [param center] (meters, the table's space, already found), at its fixed place
## [param fixed], or along its keys from [param rest] - every place in meters.
static func point_at(law: Dictionary, center: Vector3, fixed: Variant, rest: Vector3, t: float, d: float, T: float) -> Vector3:
	var u := clampf(t / maxf(d, 1e-6), 0.0, 1.0)
	var vars := {"t": t, "u": u, "d": d, "T": T, "n": 0.0}
	if law.has("radius"):
		var period := num(law["period"], vars)
		vars["n"] = floorf(t / maxf(period, 1e-6))
		var r: Vector2 = law["radius"]
		var a := deg_to_rad(float(law.get("start", 0.0))) + float(law.get("dir", 1.0)) * TAU * t / maxf(period, 1e-6)
		var lift := num(law.get("lift", 0.0), vars)
		# A ROUND IS NEVER THE SAME TWICE ([method Hands.round_of]): the hand's own pace, reach and middle, the same for
		# both ends of a tool so it goes round whole
		if law.has("_hand"):
			var h := Hands.round_of(t, period, int(law["_hand"]))
			a += float(h["phase"]) * float(law.get("dir", 1.0))
			r *= float(h["radius"])
			center += h["middle"]
		return center + Vector3(cos(a) * r.x, lift, sin(a) * r.y) * 0.01
	if fixed is Vector3:
		return fixed
	if law.has("keys"):
		# through its keys, stopping only where it holds or turns back ([method slopes])
		var keys: Array = law["keys"]
		var at := PackedFloat32Array()
		var v := PackedVector3Array()
		for k in keys:
			at.append(float((k as Dictionary)["at"]))
			v.append(rest + ((k as Dictionary)["by"] as Vector3) * 0.01)
		return through(at, v, slopes(at, v), u)
	return rest


## A HAND'S UNSTEADINESS on a pose, for a law's `jitter`: a small wander of place (meters) at [param t].
static func jitter_of(law: Dictionary, t: float) -> Vector3:
	var j := float(law.get("jitter", 0.0)) * 0.01
	if j <= 0.0:
		return Vector3.ZERO
	var r := float(law.get("rate", 0.7))
	return Vector3(Formula.noise1(t * r + 3.1), Formula.noise1(t * r + 11.7) * 0.5, Formula.noise1(t * r + 23.9)) * j
