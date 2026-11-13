extends RefCounted
class_name VoiceBlend

## VoiceBlend - a new voice made of a multi-speaker voice's own readers, and shaped, written as one line.
##
## A Kokoro voice is a style pack: 510 rows of 256 numbers (one row per sentence length), the first 128 the
## timbre the decoder is given and the last 128 the prosody its duration, pitch and energy predictors get.
## Two packs mixed are a voice of their own. The host makes the pack (hosts/voice/blend.py holds the math
## of each method, the lanes and the noise); this file is the line and its words.
##
## The line is the same in the note (`blend:` on a voice) and in the request (`blend`):
##
##     mix: af_heart 2, bf_emma 1
##     split british: af_heart sound, bf_emma delivery
##     max: am_santa 60/50/40/35/30, af_nicole 40/50/60/65/70; breath 0/0.1/0.2/0.4/0.5; noise wander 0.3 7
##     mix: bf_emma; breath 0.7
##
## A method and an accent, then each reader by its pack's name, its weight and, for a method that gives voices
## parts, its part. A weight is one number or points across a paragraph joined by "/" - the reader's share at the
## paragraph's first word, its last, and evenly between ([method curve_at]); each word reads where it stands (a
## sentence at a time where the host cannot make the graph that moves within one). Then the lanes (`breath`, `push`: points from -1 to 1 along directions measured off Kokoro's readers)
## and the noise (`fixed` or `wander`, an amount, a seed). Fewer than two readers is no blend unless a lane or the
## noise shapes the one - the tab's one reader (`speaker:`) reads alone. Only a voice whose backend says `blend` takes one
## (`ReadingCast.blend_of`); elsewhere it is ignored.

## How the readers are made one: what the host does for each (blend.py), said in the reader browser.
const METHODS := {
	"mix": {"label": "Mix",
		"blurb": "Each number of the voices averaged by its share - Kokoro's own way of blending. Two voices far apart can come out flatter than either."},
	"spherical": {"label": "Mix, kept full",
		"blurb": "The same mix, its timbre and its delivery each kept as strong as the voices' own - an average of two different voices is a weaker style than either, and this puts the strength back."},
	"split": {"label": "Sound and delivery", "parts": true,
		"blurb": "The SOUND of the voices marked Sound (the timbre Kokoro's decoder is given) with the DELIVERY of those marked Delivery (the pace, pitch and stress its predictors plan from) - each side mixed by share. A voice marked Both is on both sides."},
	"max": {"label": "Max",
		"blurb": "Each of the style's 256 numbers pushed out to the largest any of the voices has, the shares leaning it toward one voice or another. No voice was taught a style like it, though every word was still heard in each one tried."},
	"min": {"label": "Min",
		"blurb": "Each of the style's 256 numbers pulled in to the smallest any of the voices has, the shares leaning it toward one voice or another. No voice was taught a style like it, though every word was still heard in each one tried."},
}

## A reader's part in a method that gives parts ([constant METHODS] `parts`).
const PARTS := {
	"both": {"label": "Both", "blurb": "On both sides: its sound and its delivery."},
	"sound": {"label": "Sound", "blurb": "Its timbre: what the voice sounds like."},
	"delivery": {"label": "Delivery", "blurb": "Its prosody: how the voice paces, lifts and leans on the words."},
}

## What eSpeak reads a blend in. Unsaid, the accent of its heaviest reader (in Sound and delivery, its
## heaviest delivery) across the paragraph.
const ACCENTS := {
	"": {"label": "Accent: its heaviest voice's", "blurb": "Read in the accent of the reader with the most weight across a paragraph - the delivery's, in Sound and delivery."},
	"american": {"label": "American", "blurb": "Read as American English, whoever is in it."},
	"british": {"label": "British", "blurb": "Read as British English, whoever is in it."},
}

## The directions a voice is moved along, measured off Kokoro's 28 English readers (hosts/voice_train/kokoro_axes.py):
## -1 to 1, its points across a paragraph as a weight's are.
const LANES := {
	"breath": {"label": "Breath",
		"blurb": "Breathier up, clearer down: the way Kokoro's breathiest readers differ from its clearest, so any voice can whisper or ring without another voice's sound in it. A breathier voice is a little quieter."},
	"push": {"label": "Push",
		"blurb": "Pushed up, soft down: brighter and more forceful toward the top, darker and gentler toward the bottom - the way Kokoro's brightest readers differ from its darkest. Not loudness."},
}

## Noise that stays among voices: drawn over the ways Kokoro's readers differ from one another, by how much they do.
const NOISES := {
	"fixed": {"label": "Fixed",
		"blurb": "One draw for the whole reading: a new voice near this one. Its Seed picks which."},
	"wander": {"label": "Wander",
		"blurb": "The voice drifts among nearby voices, a new place every paragraph and eased between, the same each time it is read. Its Seed picks which path."},
}

## Ways to move a voice across each paragraph, the lanes filled in to start from: `mix` moves the last reader's share
## by points out of a hundred around the shares as they stand (the others giving way in proportion), `breath` and
## `push` are the lanes' points.
const SHAPES := {
	"steady": {"label": "Steady", "blurb": "The same all the way through: the mix as it stands, no breath or push.",
		"mix": [0, 0, 0, 0, 0], "breath": [0, 0, 0, 0, 0], "push": [0, 0, 0, 0, 0]},
	"settle": {"label": "Settle",
		"blurb": "Opens nearer the first voice and settles into the last across each paragraph, easing off as it goes - the way a reader lands a paragraph.",
		"mix": [-12, -8, 0, 10, 15], "breath": [0, 0, 0.1, 0.25, 0.4], "push": [0.3, 0.2, 0, -0.2, -0.35]},
	"soften": {"label": "Soften", "blurb": "Breath creeps in across each paragraph, and the push eases off with it.",
		"mix": [0, 0, 0, 0, 0], "breath": [0, 0.1, 0.25, 0.45, 0.6], "push": [0, 0, -0.1, -0.15, -0.2]},
	"hush": {"label": "Hush", "blurb": "Breathy and a little soft all the way through - a voice kept low.",
		"mix": [0, 0, 0, 0, 0], "breath": [0.9, 0.9, 0.9, 0.9, 0.9], "push": [-0.2, -0.2, -0.2, -0.2, -0.2]},
	"lift": {"label": "Lift", "blurb": "Gathers push across each paragraph, brightening toward its end.",
		"mix": [0, 0, 0, 0, 0], "breath": [0, 0, 0, 0, 0], "push": [-0.2, -0.1, 0.1, 0.3, 0.4]},
	"swell": {"label": "Swell",
		"blurb": "Leans into the last voice in the middle of each paragraph and back, pushing a little at the peak.",
		"mix": [0, 8, 15, 8, 0], "breath": [0, 0, 0, 0, 0], "push": [0, 0.15, 0.3, 0.15, 0]},
}

## A weight's most: a share, so 60 and 40 are three parts to two.
const WEIGHT_MAX := 100.0
## The most points a curve may have.
const POINTS_MOST := 9
## The points a curve is drawn and dragged with in the reader browser.
const POINTS := 5


## [param spec] read: `{method, accent, voices: [{reader, weights, part}], breath, push, noise}` (`weights`, `breath`
## and `push` arrays of points, `noise` `{kind, amount, seed}` or {}), every value one this file knows (an unknown
## method is a mix, an unknown accent, part or clause unsaid, a number clamped) - {} for a line that is no voice.
static func parse(spec: String) -> Dictionary:
	var clauses := spec.split(";")
	var first := String(clauses[0]) if clauses.size() > 0 else ""
	var at := first.find(":")
	if spec.strip_edges().is_empty() or at < 0:
		return {}
	var head := first.substr(0, at).strip_edges().to_lower().split(" ", false)
	var method := String(head[0]) if head.size() > 0 else "mix"
	var accent := String(head[1]) if head.size() > 1 else ""
	var out := {"method": method if METHODS.has(method) else "mix",
		"accent": accent if ACCENTS.has(accent) else "", "voices": [], "breath": [0.0], "push": [0.0], "noise": {}}
	for entry in first.substr(at + 1).split(",", false):
		var words := String(entry).strip_edges().split(" ", false)
		if words.is_empty():
			continue
		var v := {"reader": String(words[0]), "weights": [1.0], "part": "both"}
		for w in words.slice(1):
			var word := String(w).to_lower()
			var got := _points(word, 0.0, WEIGHT_MAX)
			if not got.is_empty():
				v["weights"] = got
			elif PARTS.has(word):
				v["part"] = word
		(out["voices"] as Array).append(v)
	for k in range(1, clauses.size()):
		var bits := String(clauses[k]).strip_edges().to_lower().split(" ", false)
		if bits.size() >= 2 and LANES.has(String(bits[0])):
			var got := _points(String(bits[1]), -1.0, 1.0)
			if not got.is_empty():
				out[String(bits[0])] = got
		elif bits.size() >= 3 and String(bits[0]) == "noise" and NOISES.has(String(bits[1])):
			var amount := _points(String(bits[2]), 0.0, 1.0)
			var seed := int(String(bits[3])) if bits.size() > 3 and String(bits[3]).is_valid_int() \
				and int(String(bits[3])) >= 0 else 0
			if not amount.is_empty() and float(amount[0]) > 0.0:
				out["noise"] = {"kind": String(bits[1]), "amount": float(amount[0]), "seed": seed}
	var n := (out["voices"] as Array).size()
	return out if n >= 2 or (n == 1 and shaped(out)) else {}


## A number or "/"-joined numbers, each clamped to [param lo]..[param hi] - [] where any is not a number.
static func _points(word: String, lo: float, hi: float) -> Array:
	var out: Array = []
	for bit in word.split("/"):
		if not String(bit).is_valid_float():
			return []
		out.append(clampf(float(bit), lo, hi))
	return out.slice(0, POINTS_MOST)


## Whether a read line [param b] moves its voice: a lane off zero, or noise.
static func shaped(b: Dictionary) -> bool:
	if not (b.get("noise", {}) as Dictionary).is_empty():
		return true
	for lane in LANES:
		for v in b.get(lane, []):
			if not is_zero_approx(float(v)):
				return true
	return false


## [param points] (evenly across 0..1) read at [param u]: a monotone cubic (Fritsch-Carlson) that never leaves two
## neighboring points between them. blend.py's `curve_at` is this, line for line.
static func curve_at(points: Array, u: float) -> float:
	var n := points.size()
	if n == 0:
		return 0.0
	if n == 1:
		return float(points[0])
	var p: Array = []
	for v in points:
		p.append(float(v))
	u = clampf(u, 0.0, 1.0)
	var h := 1.0 / float(n - 1)
	var d: Array = []
	for k in n - 1:
		d.append((float(p[k + 1]) - float(p[k])) / h)
	var m: Array = []
	m.resize(n)
	m.fill(0.0)
	m[0] = d[0]
	m[n - 1] = d[n - 2]
	for k in range(1, n - 1):
		m[k] = 0.0 if float(d[k - 1]) * float(d[k]) <= 0.0 else (float(d[k - 1]) + float(d[k])) / 2.0
	for k in n - 1:
		if float(d[k]) == 0.0:
			m[k] = 0.0
			m[k + 1] = 0.0
			continue
		var a := float(m[k]) / float(d[k])
		var b := float(m[k + 1]) / float(d[k])
		var s := a * a + b * b
		if s > 9.0:
			var t := 3.0 / sqrt(s)
			m[k] = t * a * float(d[k])
			m[k + 1] = t * b * float(d[k])
	var k := mini(int(u / h), n - 2)
	var t := (u - k * h) / h
	var t2 := t * t
	var t3 := t2 * t
	return ((2 * t3 - 3 * t2 + 1) * float(p[k]) + (t3 - 2 * t2 + t) * h * float(m[k])
		+ (-2 * t3 + 3 * t2) * float(p[k + 1]) + (t3 - t2) * h * float(m[k + 1]))


## Each reader's share at [param u] across a paragraph, from their weights' points ([param weights], one array a
## reader): adding to 1, each counting once where every weight is nothing.
static func shares_at(weights: Array, u: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var total := 0.0
	for w in weights:
		var v := maxf(0.0, curve_at(w, u))
		out.append(v)
		total += v
	for k in out.size():
		out[k] = out[k] / total if total > 0.0 else 1.0 / float(out.size())
	return out


## The line for [param method], [param accent] and [param voices] (`[{reader, weights, part}]`; a single `weight`
## reads as one point), shaped by [param shape] (`{breath, push, noise}`): "" for no reader, or one shaped by nothing.
## A weight curve that never moves is one number; a reader's weight of 1, and every weight where all are equal,
## unsaid; a part only where the method gives parts; a lane only off zero, noise only above nothing.
static func compose(method: String, accent: String, voices: Array, shape := {}) -> String:
	var lanes := {}
	for lane in LANES:
		lanes[lane] = _flat(shape.get(lane, [0.0]))
	var noise: Dictionary = shape.get("noise", {})
	var b := {"breath": lanes["breath"], "push": lanes["push"],
		"noise": noise if float(noise.get("amount", 0.0)) > 0.0 else {}}
	if voices.is_empty() or (voices.size() < 2 and not shaped(b)):
		return ""
	var curves: Array = []
	for v in voices:
		var d: Dictionary = v
		var w: Array = d.get("weights", [d.get("weight", 1.0)])
		var c: Array = []
		for x in w:
			c.append(clampf(float(x), 0.0, WEIGHT_MAX))
		curves.append(_flat(c))
	var all_same := true
	for c in curves:
		all_same = all_same and (c as Array).size() == 1 and is_equal_approx(float(c[0]), float(curves[0][0]))
	var parts := bool(Registry.field(METHODS, method, "parts", false))
	var rows := PackedStringArray()
	for k in voices.size():
		var d: Dictionary = voices[k]
		var row := String(d.get("reader", ""))
		var c: Array = curves[k]
		if voices.size() > 1 and not all_same and not (c.size() == 1 and is_equal_approx(float(c[0]), 1.0)):
			row += " " + "/".join(PackedStringArray(c.map(func(x: float) -> String: return _weight(x))))
		var part := String(d.get("part", "both"))
		if parts and part != "both" and PARTS.has(part):
			row += " " + part
		rows.append(row)
	var head := method if METHODS.has(method) else "mix"
	if ACCENTS.has(accent) and not accent.is_empty():
		head += " " + accent
	var line := "%s: %s" % [head, ", ".join(rows)]
	for lane in LANES:
		var c: Array = lanes[lane]
		if not c.all(func(x: float) -> bool: return is_zero_approx(x)):
			line += "; %s %s" % [lane, "/".join(PackedStringArray(c.map(func(x: float) -> String: return _number(x))))]
	if not (b["noise"] as Dictionary).is_empty():
		var kind := String(noise.get("kind", "fixed"))
		line += "; noise %s %s" % [kind if NOISES.has(kind) else "fixed", _number(clampf(float(noise["amount"]), 0.0, 1.0))]
		if int(noise.get("seed", 0)) > 0:
			line += " %d" % int(noise["seed"])
	return line


## Points that never move, as one.
static func _flat(points: Array) -> Array:
	var out: Array = []
	for v in points:
		out.append(snappedf(float(v), 0.01))
	if out.is_empty():
		return [0.0]
	for v in out:
		if not is_equal_approx(float(v), float(out[0])):
			return out
	return [out[0]]


## A weight as a person writes it: 2, 0.5, 1.25 - never 2.0.
static func _weight(w: float) -> String:
	var r := snappedf(w, 0.01)
	return str(int(r)) if is_equal_approx(r, roundf(r)) else String.num(r, 2)


## A lane's point or an amount: 0.7, -0.25, 0 - never 0.70.
static func _number(v: float) -> String:
	var r := snappedf(v, 0.01)
	if is_zero_approx(r):
		return "0"
	return str(int(r)) if is_equal_approx(r, roundf(r)) else String.num(r, 2)


## The readers [param spec] names, in its order: their pack names.
static func readers(spec: String) -> PackedStringArray:
	var out := PackedStringArray()
	for v in parse(spec).get("voices", []):
		out.append(String((v as Dictionary)["reader"]))
	return out


## Whether [param spec] moves within a paragraph - a curve of more than one value, or noise that wanders: read word by
## word, so a request says where its sentence stands in its paragraph (`plan_span`).
static func moves(spec: String) -> bool:
	var b := parse(spec)
	if b.is_empty():
		return false
	if String((b["noise"] as Dictionary).get("kind", "")) == "wander":
		return true
	var curves: Array = [b["breath"], b["push"]]
	for v in b["voices"]:
		curves.append((v as Dictionary)["weights"])
	for c in curves:
		for x in c:
			if not is_equal_approx(float(x), float(c[0])):
				return true
	return false


## Whether [param spec]'s noise wanders - read at its place in the reading, so a request says which paragraph it is.
static func wanders(spec: String) -> bool:
	return String((parse(spec).get("noise", {}) as Dictionary).get("kind", "")) == "wander"


## Shape [param key] of [constant SHAPES] laid over readers weighted [param weights] (one array of points a reader):
## `{weights, breath, push}`, each [constant POINTS] points - the shares as they stand on average, the last reader's
## moved by the shape's `mix` and the others giving way in proportion, never under 5 in a hundred.
static func reshaped(key: String, weights: Array) -> Dictionary:
	var n := weights.size()
	var base := PackedFloat32Array()
	base.resize(n)
	for k in POINTS:
		var s := shares_at(weights, float(k) / float(POINTS - 1))
		for r in n:
			base[r] += s[r] / float(POINTS)
	var moved: Array = Registry.field(SHAPES, key, "mix", [0, 0, 0, 0, 0])
	var out: Array = []
	for r in n:
		out.append([])
	for k in POINTS:
		var last := base[n - 1] if n > 0 else 1.0
		var now := clampf(last + float(moved[k]) / 100.0, 0.05, 0.95) if n > 1 else 1.0
		for r in n:
			var s := now if r == n - 1 else base[r] * (1.0 - now) / maxf(1.0 - last, 0.001)
			(out[r] as Array).append(snappedf(s, 0.001))
	return {"weights": out, "breath": (Registry.field(SHAPES, key, "breath", []) as Array).duplicate(),
		"push": (Registry.field(SHAPES, key, "push", []) as Array).duplicate()}


## A blend said in words for a person: the method, then each reader by the name its pack is known by (`af_heart` is
## heart) and its share - "Mix: heart 67%, emma 33%", a share that moves across a paragraph from its first word's to
## its last's ("heart 60→30%"); in a method that gives parts, each reader's part; then the lanes and the noise
## ("breath +0.7", "push +0.2 → -0.3", "noise: wander 0.3"). [param brief], its readers alone and what shapes them in
## a word ("emma, breathy"). "" for no blend.
static func line(spec: String, brief := false) -> String:
	var b := parse(spec)
	var voices: Array = b.get("voices", [])
	if voices.is_empty():
		return ""
	var names := PackedStringArray()
	var weights: Array = []
	for v in voices:
		var reader := String((v as Dictionary)["reader"])
		names.append(reader.get_slice("_", 1) if reader.contains("_") else reader)
		weights.append((v as Dictionary)["weights"])
	if brief:
		var said := " + ".join(names)
		var words := PackedStringArray()
		for pair in [["breath", "breathy", "clear"], ["push", "pushed", "soft"]]:
			var mean := _mean(b[pair[0]])
			if mean > 0.15:
				words.append(pair[1])
			elif mean < -0.15:
				words.append(pair[2])
		if not (b["noise"] as Dictionary).is_empty():
			words.append("wandering" if String(b["noise"]["kind"]) == "wander" else "varied")
		return said + (", " + ", ".join(words) if not words.is_empty() else "")
	var method := String(b["method"])
	var parts := bool(Registry.field(METHODS, method, "parts", false))
	var first := shares_at(weights, 0.0)
	var last := shares_at(weights, 1.0)
	var rows := PackedStringArray()
	for k in voices.size():
		var d: Dictionary = voices[k]
		if voices.size() == 1:
			rows.append(names[k])
		elif parts:
			rows.append("%s %s" % [names[k], Registry.label(PARTS, String(d["part"])).to_lower()])
		elif roundi(100.0 * first[k]) == roundi(100.0 * last[k]):
			rows.append("%s %d%%" % [names[k], roundi(100.0 * first[k])])
		else:
			rows.append("%s %d→%d%%" % [names[k], roundi(100.0 * first[k]), roundi(100.0 * last[k])])
	var said := ", ".join(rows) if voices.size() == 1 else Registry.label(METHODS, method) + ": " + ", ".join(rows)
	for lane in LANES:
		var c: Array = b[lane]
		if c.all(func(x: float) -> bool: return is_zero_approx(x)):
			continue
		var ends := [float(c[0]), float(c[c.size() - 1])]
		said += " · %s %s" % [Registry.label(LANES, lane).to_lower(), _signed(ends[0]) if c.size() == 1 \
			else "%s → %s" % [_signed(ends[0]), _signed(ends[1])]]
	if not (b["noise"] as Dictionary).is_empty():
		said += " · noise: %s %s" % [Registry.label(NOISES, String(b["noise"]["kind"])).to_lower(),
			_number(float(b["noise"]["amount"]))]
	if not String(b["accent"]).is_empty():
		said += " (" + Registry.label(ACCENTS, String(b["accent"])) + ")"
	return said


static func _mean(points: Array) -> float:
	var t := 0.0
	for v in points:
		t += float(v)
	return t / float(maxi(1, points.size()))


static func _signed(v: float) -> String:
	return ("+" if v > 0.0 else "") + _number(v)
