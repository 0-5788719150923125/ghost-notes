extends RefCounted
class_name Visemes

## Visemes - the mouth shapes a voice's sounds are seen as (next/likeness.md, "The lanes"): a row a
## class, the sounds in it and how strongly each holds the mouth to its shape. The mouth of a
## Likeness follows the voice's phones through these: each phone is a class, each class is THEIR mouth
## for it ([method targets], from `visemes.json`), and the mouth at a moment is every nearby phone's
## shape, weighed by how much it dominates there ([method blend_at]).
##
## COARTICULATION BY DOMINANCE FUNCTIONS (Cohen and Massaro, "Modeling coarticulation in synthetic
## visual speech", 1993): each phone pulls the mouth toward its class's shape with a strength that
## falls off on either side of its center, `strength * exp(-rate * |t - center|)`, and the mouth is
## the pulls' weighted mean. A strong, quick class (the lips closing for P B M) wins its moment even
## in fast speech; a weak one (T D N L, said with the tongue) takes the shape of the vowels round it.
##
##   label     its name
##   arpabet   its sounds as ghost's own phonemes spell them (the captions' words, [Phonemes])
##   ipa       ...and as the voice's phones come back (Piper speaks eSpeak's symbols)
##   strength  how hard it holds the mouth at its center
##   rate      how fast that hold falls off, per second
##   range     the shape where their captions give too few of its sounds: a place in their own range,
##             as a percentile of each mouth blendshape (the rest at their median)
##   blurb     what the mouth does
const REGISTRY := {
	"rest": {"label": "Rest", "arpabet": [], "ipa": [], "strength": 0.6, "rate": 6.0,
		"range": {"jawOpen": 10, "mouthClose": 60},
		"blurb": "Silence: the mouth at rest between phrases."},
	"pbm": {"label": "P B M", "arpabet": ["P", "B", "M"], "ipa": ["p", "b", "m"], "strength": 4.0, "rate": 40.0,
		"range": {"jawOpen": 5, "mouthClose": 95, "mouthPressLeft": 85, "mouthPressRight": 85, "mouthRollLower": 70},
		"blurb": "The lips pressed shut."},
	"fv": {"label": "F V", "arpabet": ["F", "V"], "ipa": ["f", "v"], "strength": 1.4, "rate": 28.0,
		"range": {"jawOpen": 15, "mouthRollLower": 90, "mouthUpperUpLeft": 60, "mouthUpperUpRight": 60},
		"blurb": "The lower lip against the upper teeth."},
	"th": {"label": "TH DH", "arpabet": ["TH", "DH"], "ipa": ["θ", "ð"], "strength": 0.5, "rate": 16.0,
		"range": {"jawOpen": 30, "mouthClose": 30},
		"blurb": "The tongue between the teeth, the jaw a little open."},
	"tdnl": {"label": "T D N L", "arpabet": ["T", "D", "N", "L"], "ipa": ["t", "d", "n", "l", "ɾ", "ɫ", "ʔ"],
		"strength": 0.35, "rate": 14.0, "range": {"jawOpen": 35},
		"blurb": "The tongue's tip up behind the teeth: the lips take the vowels' shape."},
	"sz": {"label": "S Z", "arpabet": ["S", "Z"], "ipa": ["s", "z"], "strength": 0.7, "rate": 16.0,
		"range": {"jawOpen": 12, "mouthStretchLeft": 70, "mouthStretchRight": 70, "mouthSmileLeft": 60, "mouthSmileRight": 60},
		"blurb": "The teeth nearly together, the lips drawn back."},
	"sh": {"label": "SH ZH CH JH", "arpabet": ["SH", "ZH", "CH", "JH"], "ipa": ["ʃ", "ʒ", "tʃ", "dʒ", "ʧ", "ʤ"],
		"strength": 0.8, "rate": 14.0, "range": {"jawOpen": 25, "mouthFunnel": 85, "mouthPucker": 60},
		"blurb": "The lips pushed out round a narrow opening."},
	"kg": {"label": "K G NG", "arpabet": ["K", "G", "NG"], "ipa": ["k", "ɡ", "g", "ŋ", "x"], "strength": 0.3, "rate": 12.0,
		"range": {"jawOpen": 40},
		"blurb": "The back of the tongue up: the lips take the vowels' shape."},
	"r": {"label": "R", "arpabet": ["R"], "ipa": ["ɹ", "r", "ɻ"], "strength": 0.55, "rate": 12.0,
		"range": {"jawOpen": 25, "mouthPucker": 70, "mouthFunnel": 60},
		"blurb": "The lips a little rounded."},
	"w": {"label": "W", "arpabet": ["W"], "ipa": ["w", "ʍ"], "strength": 1.0, "rate": 12.0,
		"range": {"jawOpen": 12, "mouthPucker": 95, "mouthFunnel": 80},
		"blurb": "The lips rounded and pushed forward."},
	"h": {"label": "HH", "arpabet": ["HH"], "ipa": ["h"], "strength": 0.12, "rate": 12.0, "range": {},
		"blurb": "Breath: the mouth already in the next vowel's shape."},
	"open": {"label": "Open", "arpabet": ["AA", "AE", "AH", "AY", "AW"], "ipa": ["a", "ɑ", "æ", "ʌ", "ɐ", "ɒ"],
		"strength": 0.6, "rate": 10.0, "range": {"jawOpen": 92},
		"blurb": "The jaw dropped open."},
	"mid": {"label": "Mid", "arpabet": ["EH", "EY", "ER"], "ipa": ["ɛ", "e", "ə", "ɚ", "ɝ", "ɜ", "ᵻ"],
		"strength": 0.5, "rate": 10.0, "range": {"jawOpen": 65, "mouthStretchLeft": 60, "mouthStretchRight": 60},
		"blurb": "Half open, the lips relaxed."},
	"spread": {"label": "Spread", "arpabet": ["IH", "IY", "Y"], "ipa": ["ɪ", "i", "j"], "strength": 0.6, "rate": 10.0,
		"range": {"jawOpen": 30, "mouthStretchLeft": 85, "mouthStretchRight": 85, "mouthSmileLeft": 75, "mouthSmileRight": 75},
		"blurb": "The lips spread wide, the jaw nearly closed."},
	"round": {"label": "Round", "arpabet": ["AO", "OW", "OY", "UW", "UH"], "ipa": ["ɔ", "o", "ʊ", "u", "ɵ"],
		"strength": 0.7, "rate": 10.0, "range": {"jawOpen": 50, "mouthFunnel": 85, "mouthPucker": 85},
		"blurb": "The lips rounded, the jaw half open."},
}

## A phone's pull reaches no further than this from its center (seconds): past it, it is nothing.
const REACH := 0.45
## A gap between two phones this long or longer is a rest of its own.
const REST_GAP := 0.12
## Always a little rest, so a mouth far from every phone is at rest rather than undefined.
const REST_FLOOR := 0.02

static var _by_symbol := {}


## The class of [param phone] - an ARPAbet phoneme (with or without its stress digit) or one of the
## voice's IPA symbols - or "" for none (a mark, a pause).
static func class_of(phone: String) -> String:
	if _by_symbol.is_empty():
		for k in REGISTRY:
			for p in (REGISTRY[k] as Dictionary)["arpabet"]:
				_by_symbol[String(p)] = k
			for p in (REGISTRY[k] as Dictionary)["ipa"]:
				_by_symbol[String(p)] = k
	var p := phone.strip_edges()
	if _by_symbol.has(p):
		return String(_by_symbol[p])
	var bare := p.rstrip("012")
	if _by_symbol.has(bare):
		return String(_by_symbol[bare])
	# a symbol with a diacritic: its base letter
	if p.length() > 1 and _by_symbol.has(p.substr(0, 1)):
		return String(_by_symbol[p.substr(0, 1)])
	return ""


## The `range` of every class, as `actor.py visemes` takes them.
static func ranges() -> Dictionary:
	var out := {}
	for k in REGISTRY:
		out[k] = {"range": (REGISTRY[k] as Dictionary)["range"]}
	return out


## THEIR SHAPE FOR EACH CLASS, from `visemes.json` ([param data]): `{class: PackedFloat32Array}` of the
## mouth blendshapes, in its `names`' order.
static func targets(data: Variant) -> Dictionary:
	var out := {}
	if not (data is Dictionary):
		return out
	var cl: Dictionary = (data as Dictionary).get("classes", {}) if (data as Dictionary).get("classes") is Dictionary else {}
	for k in cl:
		out[k] = PackedFloat32Array((cl[k] as Dictionary).get("blend", []))
	return out


## THE VOICE'S PHONES AS CLASSES, with a rest wherever the voice is silent: `[{c, t0, t1, mid}]`,
## ascending - each phone's class and center, and the rests' [param phones] leave between them.
##
## A PHONE HOLDS ITS MOUTH UNTIL THE NEXT ONE STARTS: the voice times each sound by its own frames
## alone, and the plan's blanks between them are no one's - a P or an M came back 12 to 24 ms long,
## under a frame, and the lips scarcely closed (2026-10-21, the first take read). Within a run of
## speech each phone runs on to the next; a gap of [constant REST_GAP] or more is a rest.
static func timeline(phones: Array) -> Array:
	var said: Array = []
	for ph in phones:
		var d: Dictionary = ph
		var c := class_of(String(d.get("p", "")))
		if c.is_empty():
			continue
		var t0 := float(d.get("t0", 0.0))
		said.append({"c": c, "t0": t0, "t1": maxf(t0, float(d.get("t1", t0)))})
	var out: Array = []
	var last := -INF
	for i in said.size():
		var d: Dictionary = said[i]
		var t0 := float(d["t0"])
		var t1 := float(d["t1"])
		if i + 1 < said.size():
			var nxt := float((said[i + 1] as Dictionary)["t0"])
			if nxt - t1 < REST_GAP and nxt > t1:
				t1 = nxt
		if t0 - last >= REST_GAP and last > -INF:
			out.append({"c": "rest", "t0": last, "t1": t0, "mid": (last + t0) * 0.5})
		out.append({"c": String(d["c"]), "t0": t0, "t1": t1, "mid": (t0 + t1) * 0.5})
		last = maxf(last, t1)
	return out


## EVERY PULL ON THE MOUTH AT [param t]: each phone of [param line] ([method timeline]) within
## [constant REACH], weighed by its dominance there - its class's `strength`, falling off at its `rate`
## from the middle half of the phone - and the rest, always a little: `[[k, class, weight]]`, `k` the
## phone's place in the line (-1 for the rest's floor). [param rows] are the classes' holds - the
## registry's, unless a gate hands its own.
static func pulls(t: float, line: Array, from := 0, rows: Dictionary = REGISTRY) -> Array:
	var out: Array = [[-1, "rest", REST_FLOOR]]
	var i0 := clampi(from, 0, line.size())
	# back to the first phone still in reach
	while i0 > 0 and float((line[i0 - 1] as Dictionary)["t1"]) > t - REACH:
		i0 -= 1
	for k in range(i0, line.size()):
		var ph: Dictionary = line[k]
		var mid := float(ph["mid"])
		if mid > t + REACH:
			break
		if float(ph["t1"]) < t - REACH:
			continue
		var row: Dictionary = rows.get(String(ph["c"]), {})
		var half := (float(ph["t1"]) - float(ph["t0"])) * 0.5
		# the hold is whole across the phone's own middle half, and falls off from its edges
		var dist := maxf(0.0, absf(t - mid) - half * 0.5)
		var w := float(row.get("strength", 0.5)) * exp(-float(row.get("rate", 10.0)) * dist)
		if w >= 1e-4:
			out.append([k, String(ph["c"]), w])
	return out


## THE MOUTH AT [param t]: every pull ([method pulls]) toward its class's shape in [param targets]
## ([method targets]), the shapes mixed by the pulls' weights; [param n] the shapes' length. Before the
## first phone and after the last, the rest.
static func blend_at(t: float, line: Array, targets: Dictionary, n: int, from := 0,
		rows: Dictionary = REGISTRY) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(n)
	var total := 0.0
	for p in pulls(t, line, from, rows):
		var shape: PackedFloat32Array = targets.get(String(p[1]), PackedFloat32Array())
		if shape.size() != n:
			continue
		var w := float(p[2])
		total += w
		for i in n:
			out[i] += shape[i] * w
	if total > 0.0:
		for i in n:
			out[i] /= total
	return out


## THE TWO STRONGEST PULLS AT [param t], each less the third's and over the strongest's, what is left
## the still's own mouth (the rest, -1): `[[k, class, weight]]`, the weights summing to 1. Taking the
## third's weight off both is what keeps the mouth continuous - a pull falls to nothing at the very moment
## another overtakes it - and measuring them against the strongest, not against each other, keeps it so
## where three pull alike (their shares of each other swung wildly there). So two real mouths are mixed at
## most, and none ever pops in or out.
static func strongest(t: float, line: Array, from := 0, rows: Dictionary = REGISTRY) -> Array:
	var all := pulls(t, line, from, rows)
	all.sort_custom(func(a: Array, b: Array) -> bool: return float(a[2]) > float(b[2]))
	var first := float(all[0][2])
	var third := float(all[2][2]) if all.size() > 2 else 0.0
	var out: Array = []
	var total := 0.0
	for p in all.slice(0, 2):
		var w := (float(p[2]) - third) / first
		if w > 1e-6:
			out.append([int(p[0]), String(p[1]), w])
			total += w
	if total > 1.0:
		for p in out:
			p[2] = float(p[2]) / total
		total = 1.0
	if total < 1.0:
		var rest := out.filter(func(p: Array) -> bool: return int(p[0]) == -1)
		if rest.is_empty():
			out.append([-1, "rest", 1.0 - total])
		else:
			rest[0][2] = float(rest[0][2]) + 1.0 - total
	return out
