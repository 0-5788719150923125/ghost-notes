extends RefCounted
class_name StudioActs

## StudioActs - what the hands nobody sees do at the studio (next/studio.md, "Acts"): the words an act's mark may use, as rows,
## and each act made into its motion. An act is a pure function of its own time ([method make]): where each thing it moves is
## ([member Gesture.RATE] a second), where the windscreen is pressed (`touches`), how the camera and the microphone shake from a
## tap, and the CONTACT LANES its sound is made from (`sound`, hosts/music/contact.py's spec) - for each contact where it is round
## the microphone, how fast it slides and how hard it presses, and each hit with its speed. The same motion is seen and heard.
##
## Where the microphone is, how big its windscreen is and where the things rest are the set's ([method StudioSet.geometry]);
## the listener is a head at the capsule, turned as the viewer is (x to the viewer's right, y up, z toward the viewer).
##
## Gate: tests/studio/studio_script_check.gd.

## What an act does. `things` what it can be done to (the first its own), `tool` what does it (contact.py's materials),
## `secs` how long it takes when its mark gives none.
const VERBS := {
	"rub": {"label": "Rub", "blurb": "Fingertips rubbed over it: on the windscreen a deep, soft sweep that rises and roughens as they go faster; on a hard thing its grain under a soft fingertip.",
		"things": ["fur", "camera", "mic", "blocks"], "tool": "skin", "secs": 14.0},
	"brush": {"label": "Brush", "blurb": "The powder brush swept over it: on the windscreen a soft, airy swish and crackle; on the camera's lens, quiet and far from the microphone.",
		"things": ["fur", "lens", "camera", "mic"], "tool": "bristle", "secs": 14.0},
	"scratch": {"label": "Scratch", "blurb": "Fingernails scratched over it, quick and short: on the windscreen a crisp, dense crackle over a deep rumble; on a hard thing a bright scratch that rings it.",
		"things": ["fur", "camera", "mic", "blocks"], "tool": "nail", "secs": 10.0},
	"tap": {"label": "Tap", "blurb": "Tapped in rolls of two to five with rests between: a nail's click and what the thing rings with - the camera's hollow plastic, the microphone's metal body, a wooden block; on the windscreen a soft thump.",
		"things": ["camera", "mic", "lens", "blocks", "fur"], "tool": "nail", "secs": 8.0},
	"scrape": {"label": "Scrape", "blurb": "One wooden block slid along the other: a rasp that rises with the speed, and a creak where it goes slow and presses hard.",
		"things": ["blocks"], "tool": "wood", "secs": 12.0},
	"knock": {"label": "Knock", "blurb": "The two wooden blocks struck together in rolls: a dry, quick knock, deep this close to the microphone.",
		"things": ["blocks"], "tool": "wood", "secs": 8.0},
	"cup": {"label": "Cup", "blurb": "Both hands closed round the windscreen, squeezing and turning: a deep pressure rumble in both ears at once.",
		"things": ["fur"], "tool": "skin", "secs": 12.0},
}
## What an act is done to: its material (contact.py's) and, where it rings, its body (`shape`, `size` meters, `material`).
## `also` the other words a mark may call it by.
const THINGS := {
	"fur": {"label": "The windscreen", "blurb": "The microphone's fur windscreen, right over the capsule: heard closest of all.",
		"material": "fur", "also": ["windscreen", "fluffy"]},
	"camera": {"label": "The camera", "blurb": "The camera's hollow plastic body, across the room from the microphone.",
		"material": "plastic", "body": {"shape": "shell", "size": [0.13, 0.078, 0.052], "material": "plastic"}, "also": []},
	"mic": {"label": "The microphone's body", "blurb": "The microphone's metal body under the windscreen: it rings, and it is right at the capsule.",
		"material": "metal", "body": {"shape": "tube", "size": [0.155, 0.068, 0.068], "material": "metal"}, "also": ["microphone"]},
	"lens": {"label": "The camera's lens", "blurb": "The glass of the camera's lens, its barrel round it.",
		"material": "glass", "body": {"shape": "tube", "size": [0.089, 0.078, 0.078], "material": "plastic"}, "also": ["glass"]},
	"blocks": {"label": "The wooden blocks", "blurb": "Two blocks of hardwood, brought up in front of the microphone.",
		"material": "wood", "body": {"shape": "bar", "size": [0.15, 0.05, 0.02], "material": "wood"}, "also": ["block", "wood"]},
}
## Where round the microphone, as the listener hears it: `at` a direction (x right, y up, z toward the viewer), or `sweep`
## for one that moves over the act.
const SIDES := {
	"left": {"label": "Left", "blurb": "The microphone's left, as you see it: the left ear.", "at": Vector3(-1.0, 0.0, 0.0)},
	"right": {"label": "Right", "blurb": "Its right: the right ear.", "at": Vector3(1.0, 0.0, 0.0)},
	"front": {"label": "Front", "blurb": "The side toward the camera.", "at": Vector3(0.0, 0.0, -1.0)},
	"back": {"label": "Back", "blurb": "The side toward you.", "at": Vector3(0.0, 0.0, 1.0)},
	"top": {"label": "Top", "blurb": "Over the top.", "at": Vector3(0.0, 1.0, 0.0)},
	"front-left": {"label": "Front left", "blurb": "Between the camera's side and the left.", "at": Vector3(-0.7071, 0.0, -0.7071)},
	"front-right": {"label": "Front right", "blurb": "Between the camera's side and the right.", "at": Vector3(0.7071, 0.0, -0.7071)},
	"back-left": {"label": "Back left", "blurb": "Between your side and the left.", "at": Vector3(-0.7071, 0.0, 0.7071)},
	"back-right": {"label": "Back right", "blurb": "Between your side and the right.", "at": Vector3(0.7071, 0.0, 0.7071)},
	"around": {"label": "Around", "blurb": "Circling the microphone once over the act: from the left, round the front, to the right and back round your side.", "sweep": "around"},
	"left to right": {"label": "Left to right", "blurb": "From the left ear over the top to the right.", "sweep": "over"},
	"right to left": {"label": "Right to left", "blurb": "From the right ear over the top to the left.", "sweep": "over back"},
}
## How fast: `pace` the strokes' rate as it begins (times the act's own), `to` as it ends (times where it began).
const PACES := {
	"slow": {"label": "Slow", "blurb": "Unhurried, long strokes: dark and deep.", "pace": 0.55},
	"quick": {"label": "Quick", "blurb": "Brisk: brighter, rougher, louder.", "pace": 1.7},
	"faster": {"label": "Faster", "blurb": "Speeding up over the act: the sound rises and roughens.", "to": 2.1},
	"slower": {"label": "Slower", "blurb": "Slowing over the act: the sound sinks and softens.", "to": 0.42},
}
## How hard, times the act's own press.
const PRESSES := {
	"soft": {"label": "Soft", "blurb": "Barely pressing: light and airy.", "press": 0.45},
	"firm": {"label": "Firm", "blurb": "Pressing in: heavier, deeper, and a scrape catches and creaks when slow.", "press": 2.0},
}
## How the strokes go.
const PATTERNS := {
	"circles": {"label": "Circles", "blurb": "Round and round instead of back and forth."},
	"long": {"label": "Long strokes", "blurb": "Strokes nearly twice as long.", "reach": 1.8},
	"short": {"label": "Short strokes", "blurb": "Short, quick strokes.", "reach": 0.5},
}
## What the sound host knows a thing to be made of (hosts/music/contact.py MATERIALS, held to it by test_contact.py): every contact's
## and hit's `on` and `by` is one of these.
const SOUND_MATERIALS := ["wood", "plastic", "metal", "glass", "fur", "skin", "nail", "bristle"]
## The words of a mark that are not a thing, side, pace, press or pattern: `under` (the words after it said over it) and a tool.
const TOOLS := {"nails": "nail", "fingertips": "skin", "fingers": "skin"}

## Each verb's own strokes: their pace (cycles a second), half a stroke (m), how hard (N).
const STROKES := {"rub": [1.5, 0.024, 1.1], "brush": [1.1, 0.03, 1.0], "scratch": [2.9, 0.011, 0.9], "cup": [0.45, 0.012, 2.6],
	"scrape": [1.0, 0.035, 1.4]}
## A tap's own: taps a second in a roll, the most in a roll, the rest between rolls (s), its speed landing (m/s).
const TAPS := {"rate": 6.5, "group": 4, "gap": 0.55, "speed": 0.38}
## How long a thing the hands bring takes to come and to go back (s), and the least an act's own work lasts (s).
const COME := 1.1
const GO := 1.2
const WORK_LEAST := 1.2
## How far out from the capsule the blocks are held (m), and how far above it: in front of the windscreen's top, where the chair
## sees them.
const HOLD_OUT := 0.17
const HOLD_UP := 0.045
## What the sound is told: its tail after the act (s).
const TAIL := 1.2
## A tap's shake: the camera's on its tripod and the microphone's on its stand - how fast it sways (Hz), how soon it settles
## (s), how far a tap at 1 m/s turns it (radians).
const SHAKE := {"camera": [5.5, 0.32, 0.006], "mic": [8.5, 0.18, 0.01]}


## Every word an act's mark may use, as a reader is told them (rules/table/studio.yaml): each verb with what it sounds like, then
## the things, sides, paces, pressures, patterns and tools - from these rows, so what a reader is told is what the studio reads.
static func vocabulary() -> String:
	var out := PackedStringArray()
	out.append("Verbs (what the hands do), each with what it can be done to - the first its own when no thing is named:")
	for v in VERBS:
		out.append("- %s (%s): %s" % [v, ", ".join(PackedStringArray(VERBS[v]["things"])), String(VERBS[v]["blurb"])])
	out.append("Things:")
	for k in THINGS:
		out.append("- %s: %s" % [k, String(THINGS[k]["blurb"])])
	for group in [["Sides round the microphone", SIDES], ["Paces", PACES], ["Pressures", PRESSES], ["Patterns", PATTERNS]]:
		out.append("%s:" % String(group[0]))
		var rows: Dictionary = group[1]
		for k in rows:
			out.append("- %s: %s" % [k, String(rows[k]["blurb"])])
	out.append("Tools: %s (the verb's own when none is named)." % ", ".join(PackedStringArray(TOOLS.keys())))
	out.append("Seconds: a number, how long the act lasts (%d to %d)." % [1, 180])
	out.append("under: the words after the mark are said over the act instead of after it.")
	return "\n".join(out)


## Whether [param word] names something in [param rows] (a key or one of its `also`), and which.
static func key_in(rows: Dictionary, word: String) -> String:
	var w := word.strip_edges().to_lower()
	if rows.has(w):
		return w
	for k in rows:
		if ((rows[k] as Dictionary).get("also", []) as Array).has(w):
			return k
	return ""


## Act [param act] ([StudioScript]'s: verb, thing, side, secs, pace, press, pattern, tool, seed) made into its motion and its
## sound's lanes, with the set's [param geo] ([method StudioSet.geometry]). See the header for what it holds.
static func make(act: Dictionary, geo: Dictionary) -> Dictionary:
	var verb := String(act.get("verb", "rub"))
	var thing := String(act.get("thing", ""))
	if thing.is_empty():
		thing = String((VERBS[verb]["things"] as Array)[0])
	var secs := maxf(float(act.get("secs", VERBS[verb]["secs"])), 0.5)
	var out := {"secs": secs, "tracks": {}, "touches": [], "shake": {}, "sound": {"secs": secs, "tail": TAIL,
		"lane_rate": Gesture.RATE, "contacts": [], "hits": []}}
	match verb:
		"tap":
			_tap(act, thing, secs, geo, out)
		"knock":
			_knock(act, secs, geo, out)
		"scrape":
			_scrape(act, secs, geo, out)
		"cup":
			_cup(act, secs, geo, out)
		_:
			if verb == "brush" and thing != "blocks":
				_brush_on(act, thing, secs, geo, out)
			elif thing == "fur":
				_on_fur(act, verb, secs, geo, out)
			elif thing == "blocks":
				_on_block(act, verb, secs, geo, out)
			else:
				_on_body(act, verb, thing, secs, geo, out)
	return out


# --- the strokes' settings -----------------------------------------------------------------------------------------------

## What does [param act]: the tool its mark names, else [param own].
static func _tool(act: Dictionary, own: String) -> String:
	var t := String(act.get("tool", ""))
	return t if not t.is_empty() else own


## The strokes [param act] asks for, over its verb's own ([constant STROKES]).
static func stroke_opts(act: Dictionary, verb: String) -> Dictionary:
	var own: Array = STROKES.get(verb, STROKES["rub"])
	var pace := float(own[0])
	var reach := float(own[1])
	var press := float(own[2])
	var pace_k := 1.0
	var to_k := 1.0
	for p in act.get("paces", []):
		var row: Dictionary = PACES.get(String(p), {})
		pace_k *= float(row.get("pace", 1.0))
		to_k *= float(row.get("to", 1.0))
	var pr := String(act.get("press", ""))
	press *= float((PRESSES.get(pr, {}) as Dictionary).get("press", 1.0))
	var pat := String(act.get("pattern", ""))
	reach *= float((PATTERNS.get(pat, {}) as Dictionary).get("reach", 1.0))
	return {"pace": pace * pace_k, "pace_to": pace * pace_k * to_k, "reach": reach, "arc": reach * 0.2, "press": press,
		"press_to": press, "circles": pat == "circles", "breaks": 0.04}


## Where round the microphone side [param side] is, [param s] of the way through the act (a unit direction, the listener's).
static func side_at(side: String, s: float) -> Vector3:
	var row: Dictionary = SIDES.get(side, SIDES["back"])
	if row.has("at"):
		return (row["at"] as Vector3).normalized()
	var k := Gesture.min_jerk(s) * 0.5 + s * 0.5
	match String(row["sweep"]):
		"around":
			# from the left, round the front (toward the camera), to the right and back round the viewer's side
			var a := PI + TAU * k
			return Vector3(cos(a), 0.12 * sin(TAU * k), sin(a)).normalized()
		"over":
			var b := PI * (1.0 - k)
			return Vector3(cos(b), sin(b) * 0.9, 0.35).normalized()
		_:
			var c := PI * k
			return Vector3(cos(c), sin(c) * 0.9, 0.35).normalized()


## The two directions along the surface at [param d]: around it (level) first, then up it.
static func tangents(d: Vector3) -> Array:
	var up := Vector3.UP
	var e1 := up.cross(d)
	if e1.length() < 0.2:
		e1 = Vector3.RIGHT
	e1 = e1.normalized()
	var e2 := d.cross(e1).normalized()
	return [e1, e2]


# --- the windscreen, with hands nobody sees ------------------------------------------------------------------------------

static func _on_fur(act: Dictionary, verb: String, secs: float, geo: Dictionary, out: Dictionary) -> void:
	var seed := int(act.get("seed", 1))
	var g := Gesture.strokes(seed, secs, stroke_opts(act, verb))
	var tool := _tool(act, String(VERBS[verb]["tool"]))
	var lis: Transform3D = geo["listener"]
	var r := float(geo["fur_r"])
	var fl := float(geo["fur_len"])
	var u: PackedFloat32Array = g["u"]
	var w: PackedFloat32Array = g["w"]
	var press: PackedFloat32Array = g["press"]
	var on: PackedFloat32Array = g["on"]
	var n := u.size()
	var here := PackedVector3Array()
	var tat := PackedVector3Array()
	var depth := PackedFloat32Array()
	here.resize(n)
	tat.resize(n)
	depth.resize(n)
	for i in n:
		var d := side_at(String(act.get("side", "back")), float(i) / float(maxi(n - 1, 1)))
		var e: Array = tangents(d)
		var dir := (d * r + (e[0] as Vector3) * u[i] + (e[1] as Vector3) * w[i]).normalized()
		var dep := clampf(press[i] / 2.0, 0.0, 1.0) * fl * 0.85 * on[i]
		here[i] = dir * (r + fl * 0.5 - dep)
		tat[i] = lis * (dir * (r + fl * 0.5))
		depth[i] = dep
	var sp := Gesture.speeds3(here)
	out["touches"].append({"at": tat, "depth": depth, "push": _sweeps(tat, on, fl * 0.9)})
	(out["sound"]["contacts"] as Array).append({"kind": "scratch" if verb == "scratch" else "rub", "on": "fur", "by": tool,
		"lanes": _lanes(here, sp, press)})


static func _cup(act: Dictionary, secs: float, geo: Dictionary, out: Dictionary) -> void:
	var seed := int(act.get("seed", 1))
	var lis: Transform3D = geo["listener"]
	var r := float(geo["fur_r"])
	var fl := float(geo["fur_len"])
	for hand in 2:
		var o := stroke_opts(act, "cup")
		o["circles"] = true
		var g := Gesture.strokes(seed + 31 * hand, secs, o)
		var side := Vector3(-1.0 if hand == 0 else 1.0, 0.05, 0.15).normalized()
		var u: PackedFloat32Array = g["u"]
		var w: PackedFloat32Array = g["w"]
		var press: PackedFloat32Array = g["press"]
		var on: PackedFloat32Array = g["on"]
		var n := u.size()
		var here := PackedVector3Array()
		var tat := PackedVector3Array()
		var depth := PackedFloat32Array()
		here.resize(n)
		tat.resize(n)
		depth.resize(n)
		var e: Array = tangents(side)
		for i in n:
			# a squeeze that comes and goes on the hand's own rhythm
			var dir := (side * r + (e[1] as Vector3) * u[i] + (e[0] as Vector3) * w[i]).normalized()
			var dep := clampf(press[i] / 3.0, 0.0, 1.0) * fl * 0.95 * on[i]
			here[i] = dir * (r + fl * 0.5 - dep)
			tat[i] = lis * (dir * (r + fl * 0.5))
			depth[i] = dep
		out["touches"].append({"at": tat, "depth": depth, "push": _sweeps(tat, on, fl * 0.6)})
		(out["sound"]["contacts"] as Array).append({"kind": "cup", "on": "fur", "by": "skin",
			"lanes": _lanes(here, Gesture.speeds3(here), press)})


# --- the powder brush --------------------------------------------------------------------------------------------------

## The brush brought from where it rests, swept over [param thing] (the windscreen, the lens, the camera's body or the
## microphone's), and taken back.
static func _brush_on(act: Dictionary, thing: String, secs: float, geo: Dictionary, out: Dictionary) -> void:
	var seed := int(act.get("seed", 1))
	var lis: Transform3D = geo["listener"]
	var work := maxf(secs - COME - GO, WORK_LEAST)
	var g := Gesture.strokes(seed, work, stroke_opts(act, "brush"))
	var u: PackedFloat32Array = g["u"]
	var w: PackedFloat32Array = g["w"]
	var press: PackedFloat32Array = g["press"]
	var on: PackedFloat32Array = g["on"]
	var n := u.size()
	var tips := PackedVector3Array()         # where the bristles touch (world)
	var outs := PackedVector3Array()         # which way the handle leaves the surface (world)
	var here := PackedVector3Array()         # the contact, the listener's
	var tat := PackedVector3Array()
	var depth := PackedFloat32Array()
	tips.resize(n)
	outs.resize(n)
	here.resize(n)
	tat.resize(n)
	depth.resize(n)
	var r := float(geo["fur_r"])
	var fl := float(geo["fur_len"])
	var surface := "fur"
	for i in n:
		var p: Vector3
		var away: Vector3
		if thing == "fur":
			var d := side_at(String(act.get("side", "back")), float(i) / float(maxi(n - 1, 1)))
			var e: Array = tangents(d)
			var dir := (d * r + (e[0] as Vector3) * u[i] + (e[1] as Vector3) * w[i]).normalized()
			var dep := clampf(press[i] / 1.2, 0.0, 1.0) * fl * 0.75 * on[i]
			p = lis * (dir * (r + fl * 0.5 - dep))
			# the hand holds the handle steady, out from the side worked, whatever the tip does
			away = lis.basis * (d + Vector3(0.0, 0.45, 0.0)).normalized()
			tat[i] = lis * (dir * (r + fl * 0.5))
			depth[i] = dep
		else:
			var spot: Dictionary = _surface_of(thing, geo)
			var nrm: Vector3 = spot["normal"]
			var a1: Vector3 = spot["along"]
			var a2 := nrm.cross(a1).normalized()
			var lift := (1.0 - on[i]) * 0.02
			p = (spot["at"] as Vector3) + a1 * u[i] + a2 * w[i] + nrm * (lift - 0.002 * on[i])
			away = (nrm + Vector3(0.0, 0.5, 0.0)).normalized()
			surface = String(THINGS[thing]["material"])
		tips[i] = p
		outs[i] = away
		here[i] = lis.affine_inverse() * p
	var sp := Gesture.speeds3(here)
	# the handle trails the stroke a little: leaning back from where the tip is going, eased (a hand's lag)
	var vel := _eased(_sweeps(tips, on, 1.0), 0.12)
	var lead := int(COME * Gesture.RATE)
	var rest: Transform3D = (geo["rests"] as Dictionary)["brush"]
	var tip_len := float(geo["brush_tip"])
	var poses: Array = []
	for i in n:
		var axis := ((outs[i] as Vector3) - (vel[i] as Vector3) * 0.18).normalized()
		var y := -axis
		poses.append(_basis_y(y, lis.basis.y).orthonormalized())
	var first := Transform3D(poses[0], tips[0] - (poses[0] as Basis).y * tip_len + (outs[0] as Vector3) * 0.03)
	var last := Transform3D(poses[n - 1], tips[n - 1] - (poses[n - 1] as Basis).y * tip_len + (outs[n - 1] as Vector3) * 0.03)
	var track := _carry(seed, rest, first, COME, Vector3(0.0, 0.05, 0.0))
	for i in n:
		var b: Basis = poses[i]
		track.append(Transform3D(b, tips[i] - b.y * tip_len))
	track.append_array(_carry(seed + 1, last, rest, secs - COME - work, Vector3(0.0, 0.04, 0.0)))
	out["tracks"]["brush"] = _track(track)
	if thing == "fur":
		out["touches"].append({"at": _shift(tat, lead), "depth": _shift_f(depth, lead), "push": _sweeps(_shift(tat, lead), _shift_f(on, lead), fl * 0.8)})
	var lanes := _lanes(_shift(here, lead), _shift_f(sp, lead), _shift_f(press, lead))
	var c := {"kind": "brush", "on": surface, "by": "bristle", "lanes": lanes}
	if THINGS[thing].has("body"):
		c["body"] = THINGS[thing]["body"]
	(out["sound"]["contacts"] as Array).append(c)


# --- taps --------------------------------------------------------------------------------------------------------------

static func _tap(act: Dictionary, thing: String, secs: float, geo: Dictionary, out: Dictionary) -> void:
	var seed := int(act.get("seed", 1))
	var lis: Transform3D = geo["listener"]
	var tool := _tool(act, "skin" if thing == "fur" else String(VERBS["tap"]["tool"]))
	var o := TAPS.duplicate()
	for p in act.get("paces", []):
		o["rate"] = float(o["rate"]) * float((PACES.get(String(p), {}) as Dictionary).get("pace", 1.0))
	o["speed"] = float(o["speed"]) * float((PRESSES.get(String(act.get("press", "")), {}) as Dictionary).get("press", 1.0))
	var start := COME if thing == "blocks" else 0.0
	var work := maxf(secs - (COME + GO if thing == "blocks" else 0.0), WORK_LEAST)
	var tp := Gesture.taps(seed, work, o)
	var hits: Array = tp["hits"]
	var lift: PackedFloat32Array = tp["lift"]
	var spot := {}
	if thing == "fur":
		var d := side_at(String(act.get("side", "back")), 0.0)
		var r := float(geo["fur_r"])
		var fl := float(geo["fur_len"])
		var n := lift.size()
		var tat := PackedVector3Array()
		var depth := PackedFloat32Array()
		var push := PackedVector3Array()
		tat.resize(n)
		depth.resize(n)
		push.resize(n)
		var e: Array = tangents(d)
		for i in n:
			var dir := (d * r + (e[0] as Vector3) * (tp["u"] as PackedFloat32Array)[i] + (e[1] as Vector3) * (tp["w"] as PackedFloat32Array)[i]).normalized()
			tat[i] = lis * (dir * (r + fl * 0.5))
			depth[i] = fl * 0.7 * (1.0 - clampf(lift[i] / 0.006, 0.0, 1.0))
		out["touches"].append({"at": tat, "depth": depth, "push": push})
		spot = {"at": lis * (d * r), "body": null}
	elif thing == "blocks":
		var held := _held(act, geo)
		var b: Transform3D = held["b"]
		spot = {"at": b * Vector3(0.03, float(geo["block_size"].y) * 0.5, 0.0), "body": THINGS["blocks"]["body"]}
		# the block brought up, held while it is tapped (each tap nudging it), and taken back
		var rest: Transform3D = (geo["rests"] as Dictionary)["block_b"]
		var track := _carry(seed, rest, b, COME, Vector3(0.0, 0.04, 0.0))
		for i in lift.size():
			var tt := float(i) / Gesture.RATE
			var nudge := 0.0
			for h in hits:
				var since := tt - float(h["t"])
				if since > 0.0 and since < 0.4:
					nudge += float(h["speed"]) * 0.004 * exp(-since / 0.06) * sin(TAU * 11.0 * since)
			track.append(Transform3D(b.basis, b.origin + b.basis.y * -nudge + Gesture.idle(seed, tt, 0.0015)))
		track.append_array(_carry(seed + 1, b, rest, GO, Vector3(0.0, 0.04, 0.0)))
		out["tracks"]["block_b"] = _track(track)
	else:
		var s := _surface_of(thing, geo)
		spot = {"at": s["at"], "body": THINGS[thing].get("body")}
		var who := "mic" if thing == "mic" else "camera"
		out["shake"][who] = _shake(hits, lift.size(), SHAKE[who])
	var material := String(THINGS[thing]["material"])
	for h in hits:
		var at_l: Vector3 = lis.affine_inverse() * (spot["at"] as Vector3)
		var hit := {"t": float(h["t"]) + start, "speed": float(h["speed"]), "on": material, "by": tool, "at": [at_l.x, at_l.y, at_l.z]}
		# a strike on the microphone itself is carried through it to the capsule
		if thing == "mic" or thing == "fur":
			hit["handling"] = true
		if spot.get("body") != null:
			hit["body"] = spot["body"]
		(out["sound"]["hits"] as Array).append(hit)


static func _knock(act: Dictionary, secs: float, geo: Dictionary, out: Dictionary) -> void:
	var seed := int(act.get("seed", 1))
	var lis: Transform3D = geo["listener"]
	var work := maxf(secs - COME - GO, WORK_LEAST)
	var o := TAPS.duplicate()
	o["rate"] = 4.5
	o["group"] = 3
	o["speed"] = 0.45 * float((PRESSES.get(String(act.get("press", "")), {}) as Dictionary).get("press", 1.0))
	o["hover"] = 0.03
	var tp := Gesture.taps(seed, work, o)
	var held := _held(act, geo)
	var b: Transform3D = held["b"]
	var a: Transform3D = held["a"]
	var lift: PackedFloat32Array = tp["lift"]
	var ta := _carry(seed, (geo["rests"] as Dictionary)["block_a"], _lifted(a, b, lift[0]), COME, Vector3(0.0, 0.05, 0.0))
	var tb := _carry(seed + 2, (geo["rests"] as Dictionary)["block_b"], b, COME, Vector3(0.0, 0.03, 0.0))
	for i in lift.size():
		var tt := float(i) / Gesture.RATE
		ta.append(_lifted(a, b, lift[i]).translated(Gesture.idle(seed + 5, tt, 0.001)))
		tb.append(b.translated(Gesture.idle(seed + 6, tt, 0.001)))
	ta.append_array(_carry(seed + 1, _lifted(a, b, lift[lift.size() - 1]), (geo["rests"] as Dictionary)["block_a"], GO, Vector3(0.0, 0.05, 0.0)))
	tb.append_array(_carry(seed + 3, b, (geo["rests"] as Dictionary)["block_b"], GO, Vector3(0.0, 0.03, 0.0)))
	out["tracks"]["block_a"] = _track(ta)
	out["tracks"]["block_b"] = _track(tb)
	var at_l: Vector3 = lis.affine_inverse() * (b * Vector3(0.0, float(geo["block_size"].y) * 0.5, 0.0))
	for h in tp["hits"]:
		(out["sound"]["hits"] as Array).append({"t": float(h["t"]) + COME, "speed": float(h["speed"]), "on": "wood", "by": "wood",
			"at": [at_l.x, at_l.y, at_l.z], "body": THINGS["blocks"]["body"], "body2": THINGS["blocks"]["body"]})


static func _scrape(act: Dictionary, secs: float, geo: Dictionary, out: Dictionary) -> void:
	var seed := int(act.get("seed", 1))
	var lis: Transform3D = geo["listener"]
	var work := maxf(secs - COME - GO, WORK_LEAST)
	var g := Gesture.strokes(seed, work, stroke_opts(act, "scrape"))
	var held := _held(act, geo)
	var b: Transform3D = held["b"]
	var a: Transform3D = held["a"]
	var u: PackedFloat32Array = g["u"]
	var w: PackedFloat32Array = g["w"]
	var on: PackedFloat32Array = g["on"]
	var n := u.size()
	var here := PackedVector3Array()
	here.resize(n)
	var ta := _carry(seed, (geo["rests"] as Dictionary)["block_a"], _lifted(a, b, 0.012), COME, Vector3(0.0, 0.05, 0.0))
	var tb := _carry(seed + 2, (geo["rests"] as Dictionary)["block_b"], b, COME, Vector3(0.0, 0.03, 0.0))
	var hb := float(geo["block_size"].y)
	for i in n:
		var tt := float(i) / Gesture.RATE
		var yaw := 0.05 * Gesture.wave(seed + 9, tt, 3.0, 0.8)
		var slid := Transform3D(a.basis.rotated(b.basis.y.normalized(), yaw), a.origin + b.basis.x * u[i] + b.basis.z * w[i])
		var held_b := b.translated(Gesture.idle(seed + 6, tt, 0.0008))
		var lifted := _lifted(slid, held_b, (1.0 - on[i]) * 0.012)
		ta.append(lifted)
		tb.append(held_b)
		here[i] = lis.affine_inverse() * (held_b * Vector3(0.0, hb * 0.5, 0.0) + b.basis.x * u[i] + b.basis.z * w[i])
	ta.append_array(_carry(seed + 1, _lifted(a, b, 0.012), (geo["rests"] as Dictionary)["block_a"], GO, Vector3(0.0, 0.05, 0.0)))
	tb.append_array(_carry(seed + 3, b, (geo["rests"] as Dictionary)["block_b"], GO, Vector3(0.0, 0.03, 0.0)))
	out["tracks"]["block_a"] = _track(ta)
	out["tracks"]["block_b"] = _track(tb)
	var lead := int(COME * Gesture.RATE)
	(out["sound"]["contacts"] as Array).append({"kind": "scrape", "on": "wood", "by": "wood", "body": THINGS["blocks"]["body"],
		"body2": THINGS["blocks"]["body"], "lanes": _lanes(_shift(here, lead), _shift_f(Gesture.speeds(u, w), lead), _shift_f(g["press"], lead))})


## A block's face rubbed or scratched by a hand nobody sees: the block brought up, held (nudged by the strokes), taken back.
static func _on_block(act: Dictionary, verb: String, secs: float, geo: Dictionary, out: Dictionary) -> void:
	var seed := int(act.get("seed", 1))
	var lis: Transform3D = geo["listener"]
	var work := maxf(secs - COME - GO, WORK_LEAST)
	var g := Gesture.strokes(seed, work, stroke_opts(act, verb))
	var b: Transform3D = _held(act, geo)["b"]
	var u: PackedFloat32Array = g["u"]
	var w: PackedFloat32Array = g["w"]
	var n := u.size()
	var here := PackedVector3Array()
	here.resize(n)
	var tb := _carry(seed + 2, (geo["rests"] as Dictionary)["block_b"], b, COME, Vector3(0.0, 0.03, 0.0))
	var hb := float(geo["block_size"].y)
	for i in n:
		var tt := float(i) / Gesture.RATE
		var held_b := b.translated(b.basis.x * u[i] * 0.04 + Gesture.idle(seed + 6, tt, 0.0008))
		tb.append(held_b)
		here[i] = lis.affine_inverse() * (held_b * Vector3(0.0, hb * 0.5, 0.0) + b.basis.x * u[i] + b.basis.z * w[i])
	tb.append_array(_carry(seed + 3, b, (geo["rests"] as Dictionary)["block_b"], GO, Vector3(0.0, 0.03, 0.0)))
	out["tracks"]["block_b"] = _track(tb)
	var lead := int(COME * Gesture.RATE)
	(out["sound"]["contacts"] as Array).append({"kind": verb if verb != "brush" else "brush", "on": "wood",
		"by": _tool(act, String(VERBS[verb]["tool"])), "body": THINGS["blocks"]["body"],
		"lanes": _lanes(_shift(here, lead), _shift_f(Gesture.speeds(u, w), lead), _shift_f(g["press"], lead))})


## The camera's or the microphone's body rubbed or scratched by a hand nobody sees: it sways a little with the strokes.
static func _on_body(act: Dictionary, verb: String, thing: String, secs: float, geo: Dictionary, out: Dictionary) -> void:
	var seed := int(act.get("seed", 1))
	var lis: Transform3D = geo["listener"]
	var o := stroke_opts(act, verb)
	o["press"] = float(o["press"]) * 0.6
	o["press_to"] = o["press"]
	var g := Gesture.strokes(seed, secs, o)
	var s := _surface_of(thing, geo)
	var a1: Vector3 = s["along"]
	var a2 := (s["normal"] as Vector3).cross(a1).normalized()
	var u: PackedFloat32Array = g["u"]
	var w: PackedFloat32Array = g["w"]
	var n := u.size()
	var here := PackedVector3Array()
	here.resize(n)
	var sway := PackedFloat32Array()
	sway.resize(n)
	for i in n:
		here[i] = lis.affine_inverse() * ((s["at"] as Vector3) + a1 * u[i] + a2 * w[i])
		sway[i] = u[i] / maxf(float(o["reach"]), 0.005) * 0.0012 * (g["on"] as PackedFloat32Array)[i]
	out["shake"]["mic" if thing == "mic" else "camera"] = sway
	var c := {"kind": verb, "on": String(THINGS[thing]["material"]), "by": _tool(act, String(VERBS[verb]["tool"])),
		"lanes": _lanes(here, Gesture.speeds(u, w), g["press"])}
	if THINGS[thing].has("body"):
		c["body"] = THINGS[thing]["body"]
	(out["sound"]["contacts"] as Array).append(c)


# --- where things are --------------------------------------------------------------------------------------------------

## A hard thing's surface where it is worked: its point, which way is out of it, and which way the strokes run along it.
static func _surface_of(thing: String, geo: Dictionary) -> Dictionary:
	var lis: Transform3D = geo["listener"]
	match thing:
		"lens":
			return {"at": geo["lens"], "normal": geo["lens_n"], "along": lis.basis.x}
		"mic":
			return {"at": geo["mic_body"], "normal": lis.basis.z, "along": lis.basis.y}
		_:
			return {"at": geo["camera_body"], "normal": lis.basis.y, "along": lis.basis.x}


## Where the blocks are held for [param act]: `b` the one held still, `a` the other above it - in front of the microphone on the
## act's side.
static func _held(act: Dictionary, geo: Dictionary) -> Dictionary:
	var lis: Transform3D = geo["listener"]
	var d := side_at(String(act.get("side", "back")), 0.0)
	var at := lis * (d * HOLD_OUT + Vector3(0.0, HOLD_UP, 0.0))
	var yaw := atan2(d.x, d.z) * 0.25
	# turned a little and tipped toward the eye, so the chair sees a top and a side, never a flat face
	var basis := lis.basis * Basis(Vector3.UP, yaw + 0.3) * Basis(Vector3.RIGHT, 0.42)
	var b := Transform3D(basis, at)
	var a := Transform3D(basis * Basis(Vector3.UP, 0.08), at + basis.y * float(geo["block_size"].y))
	return {"a": a, "b": b}


## Block [param a] resting on [param b], raised [param lift] meters off it.
static func _lifted(a: Transform3D, b: Transform3D, lift: float) -> Transform3D:
	return Transform3D(a.basis, a.origin + b.basis.y.normalized() * lift)


## A thing carried from [param from] to [param to] over [param secs] as a hand carries it: minimum-jerk along a path bowed by
## [param bow], turned on the way. A list of transforms, [constant Gesture.RATE] a second.
static func _carry(seed: int, from: Transform3D, to: Transform3D, secs: float, bow: Vector3) -> Array:
	var path := Gesture.reach(seed, from.origin, to.origin, maxf(secs, 0.1), bow, false)
	var q0 := from.basis.get_rotation_quaternion()
	var q1 := to.basis.get_rotation_quaternion()
	var out: Array = []
	var n := path.size()
	for i in n - 1:
		var k := Gesture.min_jerk(float(i) / float(maxi(n - 1, 1)))
		out.append(Transform3D(Basis(q0.slerp(q1, k)).scaled(from.basis.get_scale()), path[i]))
	return out


## A list of transforms as the tracks a medium reads: `pos` and `rot` (a quaternion's x, y, z, w four floats a sample).
static func _track(xfs: Array) -> Dictionary:
	var pos := PackedVector3Array()
	var rot := PackedFloat32Array()
	for x in xfs:
		pos.append((x as Transform3D).origin)
		var q := (x as Transform3D).basis.get_rotation_quaternion()
		rot.append_array(PackedFloat32Array([q.x, q.y, q.z, q.w]))
	return {"pos": pos, "rot": rot}


## A track at [param t] seconds: its transform (a quaternion slerped between samples).
static func pose_at(track: Dictionary, t: float) -> Transform3D:
	var pos: PackedVector3Array = track["pos"]
	var rot: PackedFloat32Array = track["rot"]
	if pos.is_empty():
		return Transform3D()
	var x := clampf(t * Gesture.RATE, 0.0, float(pos.size() - 1))
	var i := int(x)
	var j := mini(i + 1, pos.size() - 1)
	var f := x - float(i)
	var q0 := Quaternion(rot[i * 4], rot[i * 4 + 1], rot[i * 4 + 2], rot[i * 4 + 3])
	var q1 := Quaternion(rot[j * 4], rot[j * 4 + 1], rot[j * 4 + 2], rot[j * 4 + 3])
	return Transform3D(Basis(q0.slerp(q1, f)), pos[i].lerp(pos[j], f))


## A basis whose y is [param y], turned as little as it can be from [param up_hint] round it.
static func _basis_y(y: Vector3, up_hint: Vector3) -> Basis:
	var yy := y.normalized()
	var x := up_hint.cross(yy)
	if x.length() < 0.1:
		x = Vector3.RIGHT.cross(yy)
	x = x.normalized()
	var z := x.cross(yy).normalized()
	return Basis(x, yy, z)


## A path's way of going, a sample each: its direction times [param size] while it touches ([param on]): which way the fur is
## laid over, and which way a handle trails.
static func _sweeps(p: PackedVector3Array, on: PackedFloat32Array, size: float) -> PackedVector3Array:
	var out := PackedVector3Array()
	out.resize(p.size())
	for i in p.size():
		var a := maxi(i - 3, 0)
		var b := mini(i + 3, p.size() - 1)
		var v := p[b] - p[a]
		var k := on[i] if i < on.size() else 1.0
		out[i] = v.normalized() * size * k if v.length() > 1e-6 else Vector3.ZERO
	return out


## [param p] eased over about [param secs] seconds (an exponential follow, a sample each): what lags a hand's motion.
static func _eased(p: PackedVector3Array, secs: float) -> PackedVector3Array:
	var out := PackedVector3Array()
	out.resize(p.size())
	var k := 1.0 - exp(-1.0 / (Gesture.RATE * maxf(secs, 0.001)))
	var v := p[0] if not p.is_empty() else Vector3.ZERO
	for i in p.size():
		v = v.lerp(p[i], k)
		out[i] = v
	return out


## A tap's shake: each hit sets the thing swaying ([param row]: Hz, settling s, radians at 1 m/s), summed - [param n] samples.
static func _shake(hits: Array, n: int, row: Array) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / Gesture.RATE
		var a := 0.0
		for h in hits:
			var since := t - float(h["t"])
			if since > 0.0 and since < float(row[1]) * 6.0:
				a += float(h["speed"]) * float(row[2]) * exp(-since / float(row[1])) * sin(TAU * float(row[0]) * since)
		out[i] = a
	return out


## A table of points as contact.py's lanes, in the listener's frame already: x, y, z, speed and force, a sample each.
static func _lanes(here: PackedVector3Array, speed: PackedFloat32Array, force: PackedFloat32Array) -> Dictionary:
	var x := PackedFloat32Array()
	var y := PackedFloat32Array()
	var z := PackedFloat32Array()
	for p in here:
		x.append(p.x)
		y.append(p.y)
		z.append(p.z)
	return {"x": x, "y": y, "z": z, "speed": speed, "force": force}


## [param p] begun [param k] samples late (its first held before it): a lane laid where its work begins in the act.
static func _shift(p: PackedVector3Array, k: int) -> PackedVector3Array:
	var out := PackedVector3Array()
	if p.is_empty():
		return out
	out.resize(k)
	out.fill(p[0])
	out.append_array(p)
	return out


static func _shift_f(p: PackedFloat32Array, k: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(k)
	out.append_array(p)
	return out
