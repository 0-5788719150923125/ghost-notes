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
## `also` the other words a mark may call it by; `both` where it is held in both hands, whatever the mark says.
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
		"both": true, "material": "wood", "body": {"shape": "bar", "size": [0.15, 0.05, 0.02], "material": "wood"}, "also": ["block", "wood"]},
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
## Which hand does it, as a mark names it: each word and the hand it means.
const HANDS := {"left hand": "left", "right hand": "right", "both hands": "both", "two hands": "both"}
## What takes both hands whatever the mark says.
const BOTH_HANDS := ["cup", "scrape", "knock"]
## The longest an act may name in seconds (an act with no seconds goes on as long as the words do).
const LONGEST := 600.0
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
## How long the blocks take to be brought and taken back (s: two hands, one after the other, [constant HANDS_APART] apart), and how
## it eases ([method _carry]: brought, most of the way covered early and the last of it drifted in).
const BLOCK_COME := 3.0
const BLOCK_GO := 3.0
const HANDS_APART := 0.8
const CARRY_EASE := 1.8
## How far over a block coming down its first edge touches before it lies flat (m, [method _landing]).
const LAND_EDGE := 0.004
## How a held block takes a blow from the other ([method _bump_at]): how far it gives (m for each meter a second of the blow), how fast
## it springs back (Hz), how soon that dies away (s), and how far it tips about its length as it gives (radians a meter).
const BUMP_DEPTH := 0.008
const BUMP_HZ := 7.0
const BUMP_DIES := 0.09
const BUMP_TIP := 2.5
## How long a thing the hands bring takes to come and to go back (s: unhurried, as ASMR is), and the least an act's own work lasts (s).
const COME := 2.2
## An open act's pace and pressure ease over this long (s); one that circles goes round once in [constant AROUND] seconds, and one
## that crosses from ear to ear goes across in [constant OVER] and back.
const RAMP := 20.0
const AROUND := 16.0
const OVER := 9.0
const GO := 2.2
const WORK_LEAST := 1.2
## How much of a stroke's reach a brush keeps on the lens, whose glass is smaller than a stroke elsewhere: its tip stays well inside
## the glass, the bristles round it reaching the rim.
const LENS_FIT := 0.33
## How far out from the capsule the blocks are held (m), and how far above it: in front of the windscreen's top, where the chair
## sees them.
const HOLD_OUT := 0.22
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
	out.append("Hands: %s - which hand does it (else the one on the side it works, else a free one; %s take both)." % [", ".join(PackedStringArray(HANDS.keys())), ", ".join(PackedStringArray(BOTH_HANDS))])
	out.append("Seconds: a number, how long the act lasts (%d to %d) - else it goes on until its closing mark, until another act takes its hand, or to the end." % [1, int(LONGEST)])
	out.append("alone: with its seconds, heard on its own - the voice waits it out.")
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
## sound's lanes, with the set's [param geo] ([method StudioSet.geometry]). See the header for what it holds. An act with its
## seconds (`timed`, the default where it does not say) is made whole, brought, worked and put back; one that goes on until
## something ends it is made [param horizon] seconds long and OPEN - a pure function of its own time, the same wherever two
## lengths of it overlap, with nothing drawn at its end (whatever ends it lifts the hand and puts the thing back).
static func make(act_in: Dictionary, geo: Dictionary, horizon := -1.0) -> Dictionary:
	var act := act_in.duplicate()
	var verb := String(act.get("verb", "rub"))
	var thing := String(act.get("thing", ""))
	if thing.is_empty():
		thing = String((VERBS[verb]["things"] as Array)[0])
	var open := not bool(act.get("timed", true)) and horizon > 0.0
	act["_open"] = open
	var secs := horizon if open else maxf(float(act.get("secs", VERBS[verb]["secs"])), 0.5)
	var blocks := thing == "blocks" or verb in ["knock", "scrape"]
	# (`held_until`: where, made whole, its own putting back begins - an act that takes the same things next takes them from there)
	var out := {"secs": secs, "open": open, "come": BLOCK_COME if blocks else COME, "go": BLOCK_GO if blocks else GO,
		"held_until": (secs - (BLOCK_GO if blocks else GO)) if not open else INF,
		"apart": HANDS_APART if blocks else 0.0, "tracks": {}, "touches": [], "shake": {}, "sound": {"secs": secs, "tail": 0.0 if open else TAIL,
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
		"press_to": press, "circles": pat == "circles", "breaks": 0.04, "open": bool(act.get("_open", false)), "ramp": RAMP} \
		if bool(act.get("_open", false)) else {"pace": pace * pace_k, "pace_to": pace * pace_k * to_k, "reach": reach, "arc": reach * 0.2,
		"press": press, "press_to": press, "circles": pat == "circles", "breaks": 0.04}


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


## Where round the microphone [param act] works at sample [param i] of [param n] (a unit direction, the listener's): its side
## [param s] of the way through a timed act; an open one circles or crosses on its own clock ([constant AROUND], [constant OVER]),
## back and forth, for as long as it goes on.
static func dir_at(act: Dictionary, i: int, n: int) -> Vector3:
	var side := String(act.get("side", "back"))
	if not bool(act.get("_open", false)):
		return side_at(side, float(i) / float(maxi(n - 1, 1)))
	var row: Dictionary = SIDES.get(side, SIDES["back"])
	if row.has("at"):
		return (row["at"] as Vector3).normalized()
	var t := float(i) / Gesture.RATE
	if String(row["sweep"]) == "around":
		var a := PI + TAU * t / AROUND
		return Vector3(cos(a), 0.12 * sin(TAU * t / AROUND), sin(a)).normalized()
	# across and back again, eased at each end as a hand turns
	var k := pingpong(t / OVER, 1.0)
	return side_at(side, Gesture.min_jerk(k))


## Where on the windscreen a hand is (world): [param v] from its middle (the listener's frame, m) - the windscreen's own middle
## (`fur_c`), which may stand off the capsule the sound is heard at.
static func on_fur(geo: Dictionary, v: Vector3) -> Vector3:
	var lis: Transform3D = geo["listener"]
	return (geo["fur_c"] as Vector3) + lis.basis * v if geo.get("fur_c") is Vector3 else lis * v


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
		var d := dir_at(act, i, n)
		var e: Array = tangents(d)
		var dir := (d * r + (e[0] as Vector3) * u[i] + (e[1] as Vector3) * w[i]).normalized()
		var dep := clampf(press[i] / 2.0, 0.0, 1.0) * fl * 0.85 * on[i]
		here[i] = lis.affine_inverse() * on_fur(geo, dir * (r + fl * 0.5 - dep))
		tat[i] = on_fur(geo, dir * (r + fl * 0.5))
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
			here[i] = lis.affine_inverse() * on_fur(geo, dir * (r + fl * 0.5 - dep))
			tat[i] = on_fur(geo, dir * (r + fl * 0.5))
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
	var work := maxf(secs - COME - (0.0 if bool(act["_open"]) else GO), WORK_LEAST)
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
	var nrms := PackedVector3Array()         # which way is out of what the bristles touch (world)
	nrms.resize(n)
	# (on the lens the strokes keep to its glass, which is smaller than a stroke elsewhere)
	var fit := LENS_FIT if thing == "lens" else 1.0
	for i in n:
		var p: Vector3
		var away: Vector3
		if thing == "fur":
			var d := dir_at(act, i + (int(COME * Gesture.RATE) if bool(act["_open"]) else 0), n)
			var e: Array = tangents(d)
			var dir := (d * r + (e[0] as Vector3) * u[i] + (e[1] as Vector3) * w[i]).normalized()
			var dep := clampf(press[i] / 1.2, 0.0, 1.0) * fl * 0.75 * on[i]
			p = on_fur(geo, dir * (r + fl * 0.5 - dep))
			# the hand holds the handle steady, out from the side worked, whatever the tip does
			away = lis.basis * (d + Vector3(0.0, 0.45, 0.0)).normalized()
			tat[i] = on_fur(geo, dir * (r + fl * 0.5))
			depth[i] = dep
			nrms[i] = lis.basis * dir
		else:
			var spot: Dictionary = _surface_of(thing, geo)
			var nrm: Vector3 = spot["normal"]
			var a1: Vector3 = spot["along"]
			var a2 := nrm.cross(a1).normalized()
			var lift := (1.0 - on[i]) * 0.02
			p = (spot["at"] as Vector3) + (a1 * u[i] + a2 * w[i]) * fit + nrm * (lift - 0.002 * on[i])
			# (on the lens it comes at the glass nearly face-on from the side of the hand holding it, so its bristles cover the glass -
			# what the lens itself sees, and its screen - and the handle never hides them from the eye)
			var side := (-1.0 if String(act.get("hand", "right")) == "left" else 1.0) * 0.35 if thing == "lens" else 0.0
			away = (nrm + lis.basis.x * side + Vector3(0.0, 0.15 if thing == "lens" else 0.5, 0.0)).normalized()
			nrms[i] = nrm
			surface = String(THINGS[thing]["material"])
		tips[i] = p
		outs[i] = away
		here[i] = lis.affine_inverse() * p
	var sp := Gesture.speeds3(here)
	# the handle trails the stroke a little: leaning back from where the tip is going, eased (a hand's lag)
	var vel := _eased(_sweeps(tips, on, 1.0), 0.12)
	var lead := int(COME * Gesture.RATE)
	var rest: Transform3D = (geo["rests"] as Dictionary)["brush"]
	# (its tip where its make says, in its own space: the bristles land where the stroke is, whichever way the make was drawn)
	var tip_v: Vector3 = geo.get("brush_tip_v", Vector3(0.0, float(geo["brush_tip"]), 0.0))
	var poses: Array = []
	for i in n:
		var axis := ((outs[i] as Vector3) - (vel[i] as Vector3) * 0.18).normalized()
		var y := -axis
		poses.append(_basis_y(y, lis.basis.y).orthonormalized())
	var first := Transform3D(poses[0], tips[0] - (poses[0] as Basis) * tip_v + (outs[0] as Vector3) * 0.03)
	var last := Transform3D(poses[n - 1], tips[n - 1] - (poses[n - 1] as Basis) * tip_v + (outs[n - 1] as Vector3) * 0.03)
	var track := _carry(seed, rest, first, COME, Vector3(0.0, 0.05, 0.0))
	# how hard the bristles are pressed and which way is out of what they touch, a sample each beside the track (none in the air)
	var bpress := PackedFloat32Array()
	var bnorm := PackedVector3Array()
	bpress.resize(track.size())
	bnorm.resize(track.size())
	for i in n:
		var b: Basis = poses[i]
		track.append(Transform3D(b, tips[i] - b * tip_v))
		bpress.append(clampf(press[i] / 1.2, 0.0, 1.0) * on[i])
		bnorm.append(nrms[i])
	if not bool(act["_open"]):
		track.append_array(_carry(seed + 1, last, rest, secs - COME - work, Vector3(0.0, 0.04, 0.0), false))
	out["tracks"]["brush"] = _track(track)
	out["press"] = {"brush": bpress}
	out["normals"] = {"brush": bnorm}
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
	var start := BLOCK_COME if thing == "blocks" else 0.0
	var work := maxf(secs - ((BLOCK_COME + (0.0 if bool(act["_open"]) else BLOCK_GO)) if thing == "blocks" else 0.0), WORK_LEAST)
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
			tat[i] = on_fur(geo, dir * (r + fl * 0.5))
			depth[i] = fl * 0.7 * (1.0 - clampf(lift[i] / 0.006, 0.0, 1.0))
		out["touches"].append({"at": tat, "depth": depth, "push": push})
		spot = {"at": on_fur(geo, d * r), "body": null}
	elif thing == "blocks":
		var held := _held(act, geo)
		var b: Transform3D = held["b"]
		spot = {"at": b * Vector3(0.03, float(geo["block_size"].y) * 0.5, 0.0), "body": THINGS["blocks"]["body"]}
		# the block brought up, held while it is tapped (each tap nudging it), and taken back
		var rest: Transform3D = (geo["rests"] as Dictionary)["block_b"]
		var track := _carry(seed, rest, b, BLOCK_COME, Vector3(0.0, 0.04, 0.0))
		for i in lift.size():
			var tt := float(i) / Gesture.RATE
			var nudge := 0.0
			for h in hits:
				var since := tt - float(h["t"])
				if since > 0.0 and since < 0.4:
					nudge += float(h["speed"]) * 0.004 * exp(-since / 0.06) * sin(TAU * 11.0 * since)
			track.append(Transform3D(b.basis, b.origin + b.basis.y * -nudge + Gesture.idle(seed, tt, 0.0015)))
		if not bool(act["_open"]):
			track.append_array(_carry(seed + 1, b, rest, BLOCK_GO, Vector3(0.0, 0.04, 0.0), false))
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
	var work := maxf(secs - BLOCK_COME - (0.0 if bool(act["_open"]) else BLOCK_GO), WORK_LEAST)
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
	var size: Vector3 = geo["block_size"]
	# (the blows first: the blocks are brought to where the first begins and taken back from where the last ends, never jumping)
	var wa: Array = []
	var wb: Array = []
	var hits: Array = tp["hits"]
	for i in lift.size():
		var tt := float(i) / Gesture.RATE
		# the held block taking each blow: given a little the way it is struck, sprung back, tipped a touch - and the striking block,
		# while it is on it, going with it
		var held_b := _bump_at(hits, tt, b) * b.translated(Gesture.idle(seed + 6, tt, 0.001))
		# (the striking block stood on the held one as it is now, so the gap between them is the lift and nothing more)
		var a_on := held_b * (b.affine_inverse() * a)
		wa.append(_landing(a_on, held_b, lift[i], _edge_at(seed, tt), size))
		wb.append(held_b)
	# (one hand first, the held block; the other after it)
	var ta := _carry_late(seed, (geo["rests"] as Dictionary)["block_a"], wa[0], BLOCK_COME, HANDS_APART, Vector3(0.0, 0.05, 0.0))
	var tb := _carry_early(seed + 2, (geo["rests"] as Dictionary)["block_b"], wb[0], BLOCK_COME, HANDS_APART, Vector3(0.0, 0.03, 0.0))
	ta.append_array(wa)
	tb.append_array(wb)
	if not bool(act["_open"]):
		# (taken back the other way round: the striking block first, the held one after)
		ta.append_array(_carry_early(seed + 1, wa[wa.size() - 1], (geo["rests"] as Dictionary)["block_a"], BLOCK_GO, HANDS_APART, Vector3(0.0, 0.05, 0.0), false))
		tb.append_array(_carry_late(seed + 3, wb[wb.size() - 1], (geo["rests"] as Dictionary)["block_b"], BLOCK_GO, HANDS_APART, Vector3(0.0, 0.03, 0.0), false))
	out["tracks"]["block_a"] = _track(ta)
	out["tracks"]["block_b"] = _track(tb)
	var at_l: Vector3 = lis.affine_inverse() * (b * Vector3(0.0, float(geo["block_size"].y) * 0.5, 0.0))
	for h in tp["hits"]:
		(out["sound"]["hits"] as Array).append({"t": float(h["t"]) + BLOCK_COME, "speed": float(h["speed"]), "on": "wood", "by": "wood",
			"at": [at_l.x, at_l.y, at_l.z], "body": THINGS["blocks"]["body"], "body2": THINGS["blocks"]["body"]})


static func _scrape(act: Dictionary, secs: float, geo: Dictionary, out: Dictionary) -> void:
	var seed := int(act.get("seed", 1))
	var lis: Transform3D = geo["listener"]
	var work := maxf(secs - BLOCK_COME - (0.0 if bool(act["_open"]) else BLOCK_GO), WORK_LEAST)
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
	var size: Vector3 = geo["block_size"]
	# (the strokes first: the blocks are brought to where the first begins and taken back from where the last ends, never jumping)
	var wa: Array = []
	var wb: Array = []
	var hb := float(geo["block_size"].y)
	for i in n:
		var tt := float(i) / Gesture.RATE
		var yaw := 0.05 * Gesture.wave(seed + 9, tt, 3.0, 0.8)
		var slid := Transform3D(a.basis.rotated(b.basis.y.normalized(), yaw), a.origin + b.basis.x * u[i] + b.basis.z * w[i])
		var held_b := b.translated(Gesture.idle(seed + 6, tt, 0.0008))
		# (the sliding block on the held one as it is now: the gap between them is the lift alone)
		var lifted := _landing(held_b * (b.affine_inverse() * slid), held_b, (1.0 - on[i]) * 0.012, _edge_at(seed, tt), size)
		wa.append(lifted)
		wb.append(held_b)
		here[i] = lis.affine_inverse() * (held_b * Vector3(0.0, hb * 0.5, 0.0) + b.basis.x * u[i] + b.basis.z * w[i])
	# (one hand first, the held block; the other after it)
	var ta := _carry_late(seed, (geo["rests"] as Dictionary)["block_a"], wa[0], BLOCK_COME, HANDS_APART, Vector3(0.0, 0.05, 0.0))
	var tb := _carry_early(seed + 2, (geo["rests"] as Dictionary)["block_b"], wb[0], BLOCK_COME, HANDS_APART, Vector3(0.0, 0.03, 0.0))
	ta.append_array(wa)
	tb.append_array(wb)
	if not bool(act["_open"]):
		ta.append_array(_carry_early(seed + 1, wa[n - 1], (geo["rests"] as Dictionary)["block_a"], BLOCK_GO, HANDS_APART, Vector3(0.0, 0.05, 0.0), false))
		tb.append_array(_carry_late(seed + 3, wb[n - 1], (geo["rests"] as Dictionary)["block_b"], BLOCK_GO, HANDS_APART, Vector3(0.0, 0.03, 0.0), false))
	out["tracks"]["block_a"] = _track(ta)
	out["tracks"]["block_b"] = _track(tb)
	var lead := int(BLOCK_COME * Gesture.RATE)
	(out["sound"]["contacts"] as Array).append({"kind": "scrape", "on": "wood", "by": "wood", "body": THINGS["blocks"]["body"],
		"body2": THINGS["blocks"]["body"], "lanes": _lanes(_shift(here, lead), _shift_f(Gesture.speeds(u, w), lead), _shift_f(g["press"], lead))})


## A block's face rubbed or scratched by a hand nobody sees: the block brought up, held (nudged by the strokes), taken back.
static func _on_block(act: Dictionary, verb: String, secs: float, geo: Dictionary, out: Dictionary) -> void:
	var seed := int(act.get("seed", 1))
	var lis: Transform3D = geo["listener"]
	var work := maxf(secs - BLOCK_COME - (0.0 if bool(act["_open"]) else BLOCK_GO), WORK_LEAST)
	var g := Gesture.strokes(seed, work, stroke_opts(act, verb))
	var b: Transform3D = _held(act, geo)["b"]
	var u: PackedFloat32Array = g["u"]
	var w: PackedFloat32Array = g["w"]
	var n := u.size()
	var here := PackedVector3Array()
	here.resize(n)
	var tb := _carry(seed + 2, (geo["rests"] as Dictionary)["block_b"], b, BLOCK_COME, Vector3(0.0, 0.03, 0.0))
	var hb := float(geo["block_size"].y)
	for i in n:
		var tt := float(i) / Gesture.RATE
		var held_b := b.translated(b.basis.x * u[i] * 0.04 + Gesture.idle(seed + 6, tt, 0.0008))
		tb.append(held_b)
		here[i] = lis.affine_inverse() * (held_b * Vector3(0.0, hb * 0.5, 0.0) + b.basis.x * u[i] + b.basis.z * w[i])
	if not bool(act["_open"]):
		tb.append_array(_carry(seed + 3, b, (geo["rests"] as Dictionary)["block_b"], BLOCK_GO, Vector3(0.0, 0.03, 0.0), false))
	out["tracks"]["block_b"] = _track(tb)
	var lead := int(BLOCK_COME * Gesture.RATE)
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


## Block [param a] coming down onto [param b] from [param lift] meters off it as a hand brings it, never quite level: tipped, the edge
## of its underside at [param edge] (radians round its middle, [method _edge_at]) lowest - that edge touches once it is within
## [constant LAND_EDGE] of [param b], and the rest settles flat as the last of the lift goes. [param size] the block's.
static func _landing(a: Transform3D, b: Transform3D, lift: float, edge: float, size: Vector3) -> Transform3D:
	if lift <= 0.0:
		return a
	var up := b.basis.y.normalized()
	var low := maxf(lift - LAND_EDGE, 0.0)
	var a1 := Transform3D(a.basis, a.origin + up * low)
	# the low edge's point on its underside, and the line it tips about there
	var r := Vector3(cos(edge) * size.x * 0.5, 0.0, sin(edge) * size.z * 0.5)
	if r.length() < 1e-5:
		return a1
	var pivot := a1 * r
	var axis := (a1.basis * Vector3(-r.z, 0.0, r.x)).normalized()
	var across := 2.0 * r.length()
	var tip := atan((lift - low) / maxf(across, 1e-4))
	var turn := Basis(axis, tip)
	# (tipped the way that lifts the far side)
	if (turn * (a1.basis * -r)).dot(up) < (a1.basis * -r).dot(up):
		turn = Basis(axis, -tip)
	return Transform3D(turn, pivot - turn * pivot) * a1


## How a held block [param b] is moved at time [param t] by the blows [param hits] (each `{t, speed}`) it has taken: each pressing it
## the way it was struck ([constant BUMP_DEPTH] a meter a second of the blow) and springing back, dying away ([constant BUMP_HZ],
## [constant BUMP_DIES]), tipping it a little about its length - the identity where none is still felt.
static func _bump_at(hits: Array, t: float, b: Transform3D) -> Transform3D:
	var give := 0.0
	for h in hits:
		var since := t - float((h as Dictionary)["t"])
		if since >= 0.0 and since < BUMP_DIES * 6.0:
			give += float((h as Dictionary)["speed"]) * BUMP_DEPTH * exp(-since / BUMP_DIES) * sin(TAU * BUMP_HZ * since)
	if absf(give) < 1e-6:
		return Transform3D.IDENTITY
	var down := -b.basis.y.normalized()
	var length := b.basis.x.normalized()
	var tip := Basis(length, give * BUMP_TIP)
	return Transform3D(Basis.IDENTITY, b.origin + down * give) * Transform3D(tip, Vector3.ZERO) * Transform3D(Basis.IDENTITY, -b.origin)


## Which edge of a block coming down leads at time [param t] of an act with [param seed]: an angle round its underside, turning slowly
## from one landing to the next.
static func _edge_at(seed: int, t: float) -> float:
	return TAU * float(absi(hash([seed, "edge"])) % 1000) / 1000.0 + 2.2 * Gesture.wave(seed + 11, t, 5.0, 2.0)


## A thing carried from [param from] to [param to] over [param secs] as a hand carries it: minimum-jerk along a path bowed by
## [param bow], turned on the way. A list of transforms, [constant Gesture.RATE] a second.
static func _carry(seed: int, from: Transform3D, to: Transform3D, secs: float, bow: Vector3, arriving := true) -> Array:
	var path := Gesture.reach(seed, from.origin, to.origin, maxf(secs, 0.1), bow, false)
	var q0 := from.basis.get_rotation_quaternion()
	var q1 := to.basis.get_rotation_quaternion()
	var out: Array = []
	var n := path.size()
	for i in n - 1:
		# (brought, it covers most of the way early - out of shot - and drifts the last of it in; taken back, it leaves slowly and
		# hurries once it is away)
		var u := float(i) / float(maxi(n - 1, 1))
		var w := 1.0 - pow(1.0 - u, CARRY_EASE) if arriving else pow(u, CARRY_EASE)
		var x := w * float(n - 1)
		var j := mini(int(x), n - 1)
		var at: Vector3 = path[j].lerp(path[mini(j + 1, n - 1)], x - float(j))
		out.append(Transform3D(Basis(q0.slerp(q1, Gesture.min_jerk(w))).scaled(from.basis.get_scale()), at))
	return out


## [method _carry] beginning [param late] seconds in, standing at [param from] till then - the second hand coming after the first.
static func _carry_late(seed: int, from: Transform3D, to: Transform3D, secs: float, late: float, bow: Vector3, arriving := true) -> Array:
	var out: Array = []
	for i in int(late * Gesture.RATE):
		out.append(from)
	out.append_array(_carry(seed, from, to, secs - late, bow, arriving))
	return out


## [method _carry] done [param early] seconds before [param secs] are up, standing at [param to] after - the first hand going before
## the second.
static func _carry_early(seed: int, from: Transform3D, to: Transform3D, secs: float, early: float, bow: Vector3, arriving := true) -> Array:
	var out := _carry(seed, from, to, secs - early, bow, arriving)
	for i in int(early * Gesture.RATE):
		out.append(to)
	return out


## A thing [param k] of the way carried from [param from] back to [param to] (where it rests): eased along a path that lifts a little
## on the way, turned on the way - what an act that goes on does with what it brought, once it ends.
static func carried(from: Transform3D, to: Transform3D, k: float) -> Transform3D:
	var q := from.basis.get_rotation_quaternion().slerp(to.basis.get_rotation_quaternion(), k)
	var at := from.origin.lerp(to.origin, k) + Vector3(0.0, 0.04 * sin(PI * k), 0.0)
	return Transform3D(Basis(q).scaled(from.basis.get_scale()), at)


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
