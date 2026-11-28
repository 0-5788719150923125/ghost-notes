extends RefCounted
class_name HeadPlan

## HeadPlan - a speaker's head performed over show time (next/head.md): where the mouth is round a microphone, how the head is turned,
## tipped and leaned, where the eyes are and which way they look. One plan moves a camera that is the head (the Studio's) and places
## the voice ([method lane_at]: its pan, its nearness and how muffled it is, turned away), so what is seen and what is heard agree.
##
## IT IS A PERFORMANCE OF PHRASES ([HeadBank]: a show's own, designed by an agent): each phrase a short choreography written in ranges
## ([method sanitize_phrase], [constant PHRASE_FIELDS]) and drawn afresh every time it is performed - its places, its turn, tip and lean,
## how long each move takes, how many times it runs through. A phrase the script calls (`<!-- head: NAME -->`, [HeadMarks]) begins at
## its word; between calls the performer picks one from the bank by its weight, a short settle between, so the head is never parked.
## A move's arrival lands on a stressed word or a sentence's end where the phrase says (head motion follows speech), and the head keeps
## near home through the opening and the close ([method calm]). Home is the chair: where the microphone is moved, the head still rests
## there, so the voice is heard from where it really is ([method feel_of] `home`). The close is calmed only once the last word is
## known, so a plan made as the words arrive performs what the plan of all of them does.
##
## How a head moves, kept: a move is minimum-jerk along a bowed path, never faster than the Pace allows ([constant MOVE_SPEED],
## [constant TURN_SPEED]); the turn leads it and the lean lags it, each on its own clock, with a swing of its own on the way; a held
## head drifts and breathes ([method Gesture.idle]), its eyes wavering with it even while they are held on the lens or the screen. Space is the microphone's listener frame, in
## meters: the capsule at the origin, x toward the viewer's right, y up, +z toward the chair; the mouth stays where a seated head can be
## ([method bounded]). A pure function of its calls, words, bank and number: no tree, no clock. Gate: tests/motion/head_plan_check.gd.
##
## HOW GENTLY IT IS PERFORMED is the head camera's on the Camera card ([method feel_of], [constant FEEL]): how far each move goes round
## the microphone, how far the head turns, tips and leans, and how often it moves (each phrase played longer) - shaping the eye and
## the voice alike, as one performance.

## What a phrase is written as, field by field - each range a [lo, hi] drawn afresh each time (a number is both), as its designer is
## told ([method fields_told]).
const PHRASE_FIELDS := {
	"name": "a few plain words for what the head does",
	"line": "a sentence saying what it does, and what it does to the voice",
	"moves": "the places it goes in order, each {side, distance, rise, turn, tilt, roll, look, take, hold, land}",
	"side": "degrees round the microphone of a move's place: 0 the chair's side, -90 its left (the left ear), 90 its right; never past -135 or 135 (the camera's side)",
	"distance": "meters from the capsule to the mouth: 0.13 the closest (on the fur), 0.25 leaning in, 0.58 sat back, 0.8 far back",
	"rise": "meters the mouth is over the capsule (up to 0.3)",
	"turn": "degrees the head is turned from facing the microphone, positive to its own right: turned away, the voice muffles",
	"tilt": "degrees the head is tipped, positive up",
	"roll": "degrees the head leans ear toward shoulder, positive to its right",
	"look": "what the eyes look at instead: \"screen\" (the flip screen) or \"lens\"; left out, where the head faces",
	"take": "how long the move takes, against the phrase's other moves (the phrase is stretched to its length)",
	"hold": "the share of the move spent still at its end",
	"land": "where its arrival falls: \"stress\" (a stressed word), \"end\" (a sentence's end) or \"free\"",
	"repeat": "how many times its moves run through",
	"length": "seconds it lasts when performed on its own",
	"weight": "how often it is picked when the script calls nothing (1 the usual)",
	"calm": "true for a phrase that keeps near home, the one the opening and the close favor",
}
## How gently it is performed, each 1 as the show's own ([method feel_of]): `reach` (how far a move goes from home), `turns` (how far
## the head turns, tips and leans), `pace` (how often it moves: each phrase lasts 1 / pace as long) and `sway` (how much a held head
## drifts, breathes and wavers between moves: 0 still).
const FEEL := {"reach": 1.0, "turns": 1.0, "pace": 1.0, "sway": 1.0}

## The nearest the mouth comes to the capsule (m); the highest over it a seated head reaches; the furthest out past it toward the
## camera; and how far to either side (m).
const NEAREST := 0.13
const HIGHEST := 0.3
const PAST := 0.04
const SIDEWAYS := 0.42
## Where the head rests: the mouth sat back on the chair's side, facing the microphone.
const HOME := Vector3(0.0, 0.088, 0.57)
## The eyes from the mouth (m, the head's own frame: y up, -z the way it faces).
const EYES := Vector3(0.0, 0.075, 0.02)
## How fast the head goes at Pace 1, at most: the mouth round the microphone (m/s) and the head turned or tipped (degrees/s) - a
## slower Pace slower still.
const MOVE_SPEED := 0.3
const TURN_SPEED := 90.0
## Which way the head moves, as the take's voice is placed by it (in the take's signature: a change places the voice again).
const MOTION := "speed-limited"
## How long the opening and the close keep the head near home (s, from the first word and to the last), and how near.
const OPENING := 30.0
const CLOSING := 35.0
const CALM_PULL := 0.9
## A settle between two phrases the script did not call (s, least and most).
const SETTLE := Vector2(0.4, 1.6)
## How far a move's arrival may slide to land on a word (a share of the move).
const LAND_REACH := 0.6
## How muffled the voice is with the mouth turned away: none within this many degrees of facing the microphone, all of it here.
const MUFFLE_FROM := 20.0
const MUFFLE_FULL := 160.0
## The most keyposes a plan holds (a show hours long is still bounded).
const MOST_KEYS := 6000


## A phrase as written, made safe: its moves bounded, its ranges [lo, hi], its name and line kept; {} where it has no move.
static func sanitize_phrase(d: Variant) -> Dictionary:
	if not (d is Dictionary):
		return {}
	var src: Dictionary = d
	var moves: Array = []
	for m in (src.get("moves", []) if src.get("moves") is Array else []):
		if not (m is Dictionary):
			continue
		var mm: Dictionary = m
		moves.append({"side": _range(mm.get("side"), 0.0, -135.0, 135.0), "distance": _range(mm.get("distance"), 0.3, NEAREST, 0.85),
			"rise": _range(mm.get("rise"), 0.04, -0.1, HIGHEST), "turn": _range(mm.get("turn"), 0.0, -110.0, 110.0),
			"tilt": _range(mm.get("tilt"), 0.0, -40.0, 40.0), "roll": _range(mm.get("roll"), 0.0, -30.0, 30.0),
			"look": String(mm.get("look", "")) if String(mm.get("look", "")) in ["screen", "lens"] else "",
			"take": _range(mm.get("take"), 1.0, 0.1, 10.0), "hold": _range(mm.get("hold"), 0.2, 0.0, 0.9),
			"land": String(mm.get("land", "free")) if String(mm.get("land", "free")) in ["stress", "end", "free"] else "free"})
		if moves.size() >= 12:
			break
	if moves.is_empty():
		return {}
	return {"name": String(src.get("name", "")).strip_edges().to_lower().left(40), "line": String(src.get("line", "")).strip_edges().left(300),
		"moves": moves, "repeat": _range(src.get("repeat"), 1.0, 1.0, 6.0), "length": _range(src.get("length"), 4.0, 0.8, 30.0),
		"weight": clampf(float(src.get("weight", 1.0)) if (src.get("weight") is float or src.get("weight") is int) else 1.0, 0.0, 10.0),
		"calm": src.get("calm") == true}


## [param v] as a range [lo, hi] within [param lo]..[param hi] ([param fallback] where it says none).
static func _range(v: Variant, fallback: float, lo: float, hi: float) -> Array:
	var a := fallback
	var b := fallback
	if v is float or v is int:
		a = float(v)
		b = float(v)
	elif v is Array and (v as Array).size() == 2 and ((v as Array)[0] is float or (v as Array)[0] is int) and ((v as Array)[1] is float or (v as Array)[1] is int):
		a = float((v as Array)[0])
		b = float((v as Array)[1])
	return [clampf(minf(a, b), lo, hi), clampf(maxf(a, b), lo, hi)]


## A range [param r] drawn with [param rng].
static func _draw(r: Array, rng: RandomNumberGenerator) -> float:
	return rng.randf_range(float(r[0]), float(r[1]))


## What a phrase's designer is told of its fields, a line each.
static func fields_told() -> String:
	var out := PackedStringArray()
	for k in PHRASE_FIELDS:
		out.append("- %s: %s" % [k, PHRASE_FIELDS[k]])
	return "\n".join(out)


## The head performed: the phrases [param calls] (each `{at, name}`: the time of the word it was called at) from [param bank] (sanitized
## phrases), the rest of the time phrases the performer picks, on [param words] (a take's: `{t0, t1, emph, sentence}`) with
## [param seed]; [param targets] where `look` looks (`screen`, `lens`: listener-frame points); [param until] where it stops (s; past
## the close where it is less than 0). A plan: `{keys, targets, first, last, seed}`, each key `{t, mouth, turn, tilt, roll, look,
## swing}` - the pose it reaches at `t`.
static func make(calls: Array, words: Array, bank: Array, seed: int, targets := {}, until := -1.0, feel := {}, whole := true) -> Dictionary:
	var how := FEEL.merged(feel, true)
	var home: Vector3 = how["home"] if how.get("home") is Vector3 else HOME
	var by_name := {}
	for p in bank:
		if p is Dictionary and not String((p as Dictionary).get("name", "")).is_empty():
			by_name[String(p["name"])] = p
	var first := float((words[0] as Dictionary)["t0"]) if not words.is_empty() else 0.0
	var last := float((words[words.size() - 1] as Dictionary)["t1"]) if not words.is_empty() else 0.0
	var stresses := PackedFloat32Array()
	var ends := PackedFloat32Array()
	for i in words.size():
		var w: Dictionary = words[i]
		if int(w.get("emph", 0)) > 0:
			stresses.append(float(w["t0"]))
		var next_sentence := i + 1 >= words.size() or int((words[i + 1] as Dictionary).get("sentence", 0)) != int(w.get("sentence", 0))
		if next_sentence or String(w.get("text", "")).strip_edges().right(1) in [".", "?", "!"]:
			ends.append(float(w["t1"]))
	var sorted := calls.filter(func(c: Variant) -> bool: return c is Dictionary and by_name.has(String((c as Dictionary).get("name", ""))))
	sorted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["at"]) < float(b["at"]))
	# (the close is calmed only once the last word is known: words still arriving would calm wherever the reading has reached)
	var plan := {"keys": [], "targets": targets, "first": first, "last": last if whole else INF, "seed": seed, "feel": how, "home": home}
	var keys: Array = plan["keys"]
	keys.append(_key(0.0, home, 0.0, 0.0, 0.0, "", 0.0))
	var end_t := until if until >= 0.0 else maxf(last, float((sorted[sorted.size() - 1] as Dictionary)["at"]) if not sorted.is_empty() else 0.0) + CLOSING
	var t := 0.0
	var ci := 0
	var slot := 0
	var seen := {}
	while t < end_t and keys.size() < MOST_KEYS:
		var rng := RandomNumberGenerator.new()
		rng.seed = hash([seed, "slot", slot])
		var phrase := {}
		var start := t
		var called := false
		if ci < sorted.size() and float((sorted[ci] as Dictionary)["at"]) <= t + SETTLE.x:
			phrase = by_name[String((sorted[ci] as Dictionary)["name"])]
			start = maxf(t, float((sorted[ci] as Dictionary)["at"]))
			called = true
			ci += 1
		elif not bank.is_empty():
			start = t + rng.randf_range(SETTLE.x, SETTLE.y)
			phrase = _pick(bank, calm(plan, start), rng)
		if phrase.is_empty():
			# nothing to perform: rest at home until the next call, or the end
			var rest_to := float((sorted[ci] as Dictionary)["at"]) if ci < sorted.size() else end_t
			keys.append(_key(rest_to, _home_of(plan, rng), 0.0, 0.0, 0.0, "", 0.0))
			t = rest_to
			slot += 1
			continue
		var length := _draw(phrase["length"], rng) / clampf(float(how["pace"]), 0.05, 4.0)
		# a called phrase runs to the next call at most; one the performer picked gives way to a call that comes
		var stop := float((sorted[ci] as Dictionary)["at"]) if ci < sorted.size() else INF
		var dur := minf(length, stop - start) if stop > start + 0.5 else length
		# a phrase the script called is stretched to the end of its sentence, where that is near
		if called:
			var e := _after(ends, start + length)
			if e < start + length * 1.5 and e < stop:
				dur = e - start
		if dur < 0.5:
			t = maxf(start, t + 0.1)
			slot += 1
			continue
		var key := String(phrase["name"])
		seen[key] = int(seen.get(key, 0)) + 1
		var own := RandomNumberGenerator.new()
		own.seed = hash([seed, key, int(seen[key]), called])
		_perform(plan, phrase, start, dur, own, stresses, ends, length)
		# (a move slowed past the phrase's end is waited out)
		t = maxf(start + dur, float((keys[keys.size() - 1] as Dictionary)["t"]))
		slot += 1
	return plan


## How gently the head is performed, from a show's camera list [param cameras] (its studio head camera's Reach, Turns and Pace,
## [Cameras] `creator`): [constant FEEL]'s fields - and, where the microphone is moved from where the studio stands it ([param mic]:
## its place, `x`, `y`, `z` cm), `home`: the chair where the head rests, as seen from the capsule where it is now.
static func feel_of(cameras: Array, mic := {}) -> Dictionary:
	var e := Cameras.entry_of(Cameras.sanitize(cameras, true, "studio"), "creator")
	var out := {"reach": Cameras.value(e, "reach"), "turns": Cameras.value(e, "turns"), "pace": Cameras.value(e, "pace"),
		"sway": Cameras.value(e, "sway")}
	var by := Vector3(float(mic.get("x", 0.0)), float(mic.get("y", 0.0)), float(mic.get("z", 0.0))) * 0.01
	if not by.is_zero_approx():
		out["home"] = HOME - by
	return out


## A key: the pose reached at [param t].
static func _key(t: float, mouth: Vector3, turn: float, tilt: float, roll: float, look: String, swing: float) -> Dictionary:
	return {"t": t, "mouth": mouth, "turn": turn, "tilt": tilt, "roll": roll, "look": look, "swing": swing}


## Home, a little off where it was last time.
static func _home_of(plan: Dictionary, rng: RandomNumberGenerator) -> Vector3:
	var sway := clampf(float((plan.get("feel", FEEL) as Dictionary).get("sway", 1.0)), 0.0, 3.0)
	return bounded((plan.get("home", HOME) as Vector3) + Vector3(rng.randf_range(-0.03, 0.03), rng.randf_range(-0.015, 0.015), rng.randf_range(-0.04, 0.04)) * sway)


## A phrase picked from [param bank] by its weight, the calm ones favored as [param calm_k] (0..1) is high.
static func _pick(bank: Array, calm_k: float, rng: RandomNumberGenerator) -> Dictionary:
	var total := 0.0
	var ws := PackedFloat32Array()
	for p in bank:
		var w := float((p as Dictionary)["weight"]) * (lerpf(0.6, 4.0, calm_k) if bool((p as Dictionary)["calm"]) else lerpf(1.0, 0.25, calm_k))
		ws.append(w)
		total += w
	if total <= 0.0:
		return {}
	var x := rng.randf() * total
	for i in ws.size():
		x -= ws[i]
		if x <= 0.0:
			return bank[i]
	return bank[bank.size() - 1]


## [param phrase] performed from [param start] for [param dur] seconds with [param rng]: its keys appended to [param plan]. Its moves keep
## the timing of its own [param length] (stretched where [param dur] is longer); cut short, it does only the moves that fit.
static func _perform(plan: Dictionary, phrase: Dictionary, start: float, dur: float, rng: RandomNumberGenerator, stresses: PackedFloat32Array,
		ends: PackedFloat32Array, length := -1.0) -> void:
	var keys: Array = plan["keys"]
	var moves: Array = []
	for _r in roundi(_draw(phrase["repeat"], rng)):
		moves.append_array(phrase["moves"])
	var takes := PackedFloat32Array()
	var total := 0.0
	for m in moves:
		var tk := _draw((m as Dictionary)["take"], rng)
		takes.append(tk)
		total += tk
	# its moves at its own length (stretched to a sentence's end where it was called to one); cut short, it does the moves that fit
	var span := maxf(dur, length) if length > 0.0 else dur
	var at := start
	for i in moves.size():
		if at >= start + dur - 0.3:
			break
		var m: Dictionary = moves[i]
		var mdur := minf(span * takes[i] / maxf(total, 1e-4), start + dur - at)
		var hold := _draw(m["hold"], rng)
		var arrive := at + mdur
		var reach := at + mdur * (1.0 - hold)
		# where it comes to rest, on a word where the phrase says (never past the phrase's end, never too soon after it set off)
		var land := String(m["land"])
		if land != "free":
			reach = clampf(_nearest(stresses if land == "stress" else ends, reach, mdur * LAND_REACH), at + mdur * 0.4, start + dur)
			arrive = maxf(arrive, reach)
		var calm_k := calm(plan, reach)
		# how much of each move is kept: less near the opening and the close, and as the camera's Reach and Turns say
		var feel: Dictionary = plan.get("feel", FEEL)
		var keep := (1.0 - CALM_PULL * calm_k) * clampf(float(feel["reach"]), 0.0, 2.0)
		var spin := (1.0 - CALM_PULL * calm_k) * clampf(float(feel["turns"]), 0.0, 2.0)
		# the place the move is written to round the microphone, then only as much of the way there from home as is kept
		var side := deg_to_rad(_draw(m["side"], rng))
		var dist := _draw(m["distance"], rng)
		var rise := clampf(_draw(m["rise"], rng), -0.1, minf(dist, HIGHEST))
		var flat := sqrt(maxf(dist * dist - rise * rise, 0.0))
		var home: Vector3 = plan.get("home", HOME)
		var mouth := bounded(home + (Vector3(sin(side) * flat, rise, cos(side) * flat) - home) * keep)
		var swing := rng.randf_range(-12.0, 12.0) * spin
		var turn := _draw(m["turn"], rng) * spin
		var tilt := _draw(m["tilt"], rng) * spin
		var roll := _draw(m["roll"], rng) * spin
		# never there sooner than a head goes that far at this pace: the way round the microphone and the turn each take their time
		var prev: Dictionary = keys[keys.size() - 1]
		var pace := clampf(float(feel["pace"]), 0.05, 4.0)
		var least := maxf((prev["mouth"] as Vector3).distance_to(mouth) / (MOVE_SPEED * pace),
			maxf(absf(turn - float(prev["turn"])), absf(tilt - float(prev["tilt"]))) / (TURN_SPEED * pace))
		reach = maxf(reach, float(prev["t"]) + least)
		arrive = maxf(arrive, reach)
		keys.append(_key(reach, mouth, turn, tilt, roll, String(m["look"]), swing))
		if arrive - reach > 0.05:
			var held: Dictionary = (keys[keys.size() - 1] as Dictionary).duplicate()
			held["t"] = arrive
			held["swing"] = 0.0
			keys.append(held)
		at = arrive


## The first time in [param times] at or after [param t], INF for none.
static func _after(times: PackedFloat32Array, t: float) -> float:
	for x in times:
		if x >= t:
			return x
	return INF


## The time in [param times] nearest [param t] within [param reach] of it, else [param t].
static func _nearest(times: PackedFloat32Array, t: float, reach: float) -> float:
	var best := t
	var gap := reach
	for x in times:
		if absf(x - t) < gap:
			gap = absf(x - t)
			best = x
	return best


## How much the head keeps near home at time [param t] of [param plan]: 1 through the opening and the close, 0 between ([constant
## OPENING], [constant CLOSING]).
static func calm(plan: Dictionary, t: float) -> float:
	var first := float(plan.get("first", 0.0))
	var last := float(plan.get("last", 0.0))
	if last <= first:
		return 0.0
	var opening := 1.0 - smoothstep(first, first + OPENING, t)
	var closing := 0.0 if is_inf(last) else smoothstep(maxf(last - CLOSING, first), last, t)
	return clampf(maxf(opening, closing), 0.0, 1.0)


## [param p] kept where a seated head can be: never nearer the capsule than [constant NEAREST], higher over it than [constant HIGHEST],
## further out past it than [constant PAST] or further to a side than [constant SIDEWAYS].
static func bounded(p: Vector3) -> Vector3:
	var q := Vector3(clampf(p.x, -SIDEWAYS, SIDEWAYS), minf(p.y, HIGHEST), maxf(p.z, -PAST))
	var d := q.length()
	return q if d >= NEAREST else (q.normalized() if d > 1e-5 else Vector3.BACK) * NEAREST


## The head at time [param t] of [param plan]: `{mouth, eyes, look, up, turn, tilt, roll}` - the mouth's and the eyes' places
## (listener frame, m), the way the eyes look and the head's up (unit vectors), its turn, tip and lean (degrees).
static func pose_at(plan: Dictionary, t: float) -> Dictionary:
	var keys: Array = plan.get("keys", [])
	var seed := int(plan.get("seed", 1))
	if keys.is_empty():
		return _posed(plan.get("home", HOME), 0.0, 0.0, 0.0, "", "", 0.0, seed, t, plan)
	var j := keys.bsearch_custom(t, func(k: Variant, x: Variant) -> bool: return float((k as Dictionary)["t"]) < float(x))
	if j <= 0:
		var k0: Dictionary = keys[0]
		return _posed(k0["mouth"], float(k0["turn"]), float(k0["tilt"]), float(k0["roll"]), String(k0["look"]), String(k0["look"]), 0.0, seed, t, plan)
	if j >= keys.size():
		var kl: Dictionary = keys[keys.size() - 1]
		return _posed(kl["mouth"], float(kl["turn"]), float(kl["tilt"]), float(kl["roll"]), String(kl["look"]), String(kl["look"]), 0.0, seed, t, plan)
	var a: Dictionary = keys[j - 1]
	var b: Dictionary = keys[j]
	var span := maxf(float(b["t"]) - float(a["t"]), 1e-4)
	var u := clampf((t - float(a["t"])) / span, 0.0, 1.0)
	var s := Gesture.min_jerk(u)
	var pa: Vector3 = a["mouth"]
	var pb: Vector3 = b["mouth"]
	# a bowed path: out from the microphone and up a little on the way, never a line
	var bow := (((pa + pb) * 0.5).normalized() * 0.05 + Vector3(0.0, 0.02, 0.0)) * minf(pa.distance_to(pb) * 3.0, 1.0)
	var mouth := pa.lerp(pb, s) + bow * Gesture.bump(u)
	# the turn leads, the lean lags, each with its own swing on the way
	var s_turn := Gesture.min_jerk(clampf(u * 1.3, 0.0, 1.0))
	var s_roll := Gesture.min_jerk(clampf((u - 0.15) / 0.85, 0.0, 1.0))
	var turn := lerpf(float(a["turn"]), float(b["turn"]), s_turn) + float(b["swing"]) * Gesture.bump(u)
	var tilt := lerpf(float(a["tilt"]), float(b["tilt"]), s) + float(b["swing"]) * 0.35 * Gesture.bump(clampf(u * 1.2, 0.0, 1.0))
	var roll := lerpf(float(a["roll"]), float(b["roll"]), s_roll)
	# (the eyes go from what they looked at to what they look at next with the turn, never in one frame)
	return _posed(mouth, turn, tilt, roll, String(a["look"]), String(b["look"]), s_turn, seed, t, plan)


## The pose from where the mouth is and how the head is turned, drifting and breathing: the eyes, the way they look and the head's up.
## The eyes look [param k] of the way from [param look_from] to [param look_to] (each a target's name, "" where the head faces).
static func _posed(mouth_in: Vector3, turn_in: float, tilt_in: float, roll_in: float, look_from: String, look_to: String, k: float,
		seed: int, t: float, plan: Dictionary) -> Dictionary:
	var feel: Dictionary = plan.get("feel", FEEL)
	var sway := clampf(float(feel.get("sway", 1.0)), 0.0, 3.0)
	var spin := clampf(float(feel.get("turns", 1.0)), 0.0, 2.0) * sway
	var mouth := bounded(mouth_in + (Gesture.idle(seed, t, 0.004) + Vector3(0.0, 0.0025 * sin(TAU * t / 4.1), 0.0)) * sway)
	var waver_turn := 2.0 * spin * Gesture.wave(seed + 5, t, 7.0, 2.5)
	var waver_tilt := 1.5 * spin * Gesture.wave(seed + 9, t, 6.0, 2.0)
	var turn := turn_in + waver_turn
	var tilt := tilt_in + waver_tilt
	var roll := roll_in + 1.2 * spin * Gesture.wave(seed + 13, t, 8.0, 3.0)
	var facing := -mouth.normalized() if mouth.length() > 0.001 else Vector3.FORWARD
	var face := Basis.looking_at(facing, Vector3.UP)
	var head := face * Basis(Vector3.UP, -deg_to_rad(turn)) * Basis(Vector3.RIGHT, deg_to_rad(tilt)) * Basis(Vector3.BACK, -deg_to_rad(roll))
	var look := head * Vector3.FORWARD
	var up := head * Vector3.UP
	var eyes := mouth + face * EYES
	var targets: Dictionary = plan.get("targets", {})
	var ahead := look.normalized()
	# (eyes held on a target still waver as the held head does: never locked still)
	var waver := Basis(Vector3.UP, -deg_to_rad(waver_turn)) * Basis(Vector3.RIGHT, deg_to_rad(waver_tilt))
	var from := _wavered(((targets[look_from] as Vector3) - eyes).normalized(), waver) if targets.get(look_from) is Vector3 else ahead
	var to := _wavered(((targets[look_to] as Vector3) - eyes).normalized(), waver) if targets.get(look_to) is Vector3 else ahead
	look = from.slerp(to, clampf(k, 0.0, 1.0)) if from.dot(to) > -0.999 else to
	return {"mouth": mouth, "eyes": eyes, "look": look.normalized(), "up": up.normalized(), "facing": (head * Vector3.FORWARD).normalized(),
		"turn": turn, "tilt": tilt, "roll": roll}


## The way [param dir] (a unit vector) turned by [param waver] in its own frame.
static func _wavered(dir: Vector3, waver: Basis) -> Vector3:
	if absf(dir.dot(Vector3.UP)) > 0.999:
		return dir
	return (Basis.looking_at(dir, Vector3.UP) * waver * Vector3.FORWARD).normalized()


## What the voice does at time [param t] of [param plan], heard at the microphone: `x` its pan (-1 the left ear to 1 the right, from
## the mouth's angle round it), `y` its nearness (-1 backed off to 1 fully in, home 0) and `z` how muffled it is (0 the mouth facing
## the microphone, 1 turned away).
static func lane_at(plan: Dictionary, t: float) -> Vector3:
	var pose := pose_at(plan, t)
	var m: Vector3 = pose["mouth"]
	var pan := clampf(m.x / maxf(m.length(), 1e-4), -1.0, 1.0)
	var d := maxf(m.length(), NEAREST)
	var home := HOME.length()
	var near := log(home / d) / log(home / 0.15) if d < home else -log(d / home) / log(0.8 / home)
	var off := rad_to_deg((pose["facing"] as Vector3).angle_to(-m.normalized()))
	var muffle := pow(clampf((off - MUFFLE_FROM) / (MUFFLE_FULL - MUFFLE_FROM), 0.0, 1.0), 1.2)
	return Vector3(pan, clampf(near, -1.0, 1.0), muffle)


## [param phrase] performed alone, measured as its designer is told it ([HeadBank], next/head.md): over [param tries] performances, how
## many times the voice crosses from ear to ear, its pan's range, how near and how far it comes, how muffled it gets, how long it
## lasts, and how much two performances differ. `{crossings, pan_lo, pan_hi, nearest, farthest, muffled, seconds, differ}`.
static func measure(phrase: Dictionary, tries := 3) -> Dictionary:
	var out := {"crossings": 0.0, "pan_lo": 1.0, "pan_hi": -1.0, "nearest": 9.0, "farthest": 0.0, "muffled": 0.0, "seconds": 0.0, "differ": 0.0}
	var first: Array = []
	for k in tries:
		# the phrase called at the start and nothing after it
		var plan := make([{"at": 0.0, "name": phrase["name"]}], [], [phrase], 977 + k * 31, {}, 0.01)
		var keys: Array = plan["keys"]
		var end := float((keys[keys.size() - 1] as Dictionary)["t"]) if keys.size() > 1 else 4.0
		var last_side := 0
		var n := 0
		var samples: Array = []
		var t := 0.0
		while t <= end:
			var l := lane_at(plan, t)
			var m: Vector3 = pose_at(plan, t)["mouth"]
			samples.append(m)
			out["pan_lo"] = minf(float(out["pan_lo"]), l.x)
			out["pan_hi"] = maxf(float(out["pan_hi"]), l.x)
			out["nearest"] = minf(float(out["nearest"]), m.length())
			out["farthest"] = maxf(float(out["farthest"]), m.length())
			out["muffled"] = maxf(float(out["muffled"]), l.z)
			var side := 1 if l.x > 0.25 else (-1 if l.x < -0.25 else 0)
			if side != 0 and last_side != 0 and side != last_side:
				n += 1
			if side != 0:
				last_side = side
			t += 0.05
		out["crossings"] = float(out["crossings"]) + float(n) / float(tries)
		out["seconds"] = float(out["seconds"]) + end / float(tries)
		if k == 0:
			first = samples
		else:
			var diff := 0.0
			for i in mini(first.size(), samples.size()):
				diff += (first[i] as Vector3).distance_to(samples[i])
			out["differ"] = maxf(float(out["differ"]), diff / maxf(float(mini(first.size(), samples.size())), 1.0))
	return out
