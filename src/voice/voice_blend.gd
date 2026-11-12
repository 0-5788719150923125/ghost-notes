extends RefCounted
class_name VoiceBlend

## VoiceBlend - a new voice made of a multi-speaker voice's own readers, written as one line.
##
## A Kokoro voice is a style pack: 510 rows of 256 numbers (one row per sentence length), the first 128 the
## timbre the decoder is given and the last 128 the prosody its duration, pitch and energy predictors get.
## Two packs mixed are a voice of their own. The host makes the pack (hosts/voice/blend.py holds the math
## of each method); this file is the line and its words.
##
## The line is the same in the note (`blend:` on a voice) and in the request (`blend`):
##
##     mix: af_heart 2, bf_emma 1
##     split british: af_heart sound, bf_emma delivery
##
## A method and an accent, then each reader by its pack's name, its weight (1 if unsaid, and unsaid for a
## method that weighs nothing) and, for a method that gives voices parts, its part. Fewer than two readers
## is no blend - the Speaker number reads alone. Only a voice whose backend says `blend` takes one
## (`ReadingCast.blend_of`); elsewhere it is ignored.

## How the readers are made one: what the host does for each (blend.py), said in the reader browser.
const METHODS := {
	"mix": {"label": "Mix",
		"blurb": "Each number of the voices averaged by its weight - Kokoro's own way of blending (equal weights are the plain average). Two voices far apart can come out flatter than either."},
	"spherical": {"label": "Mix, kept full",
		"blurb": "The same mix, its timbre and its delivery each kept as strong as the voices' own - an average of two different voices is a weaker style than either, and this puts the strength back."},
	"split": {"label": "Sound and delivery", "parts": true,
		"blurb": "The SOUND of the voices marked Sound (the timbre Kokoro's decoder is given) with the DELIVERY of those marked Delivery (the pace, pitch and stress its predictors plan from) - each side mixed by weight. A voice marked Both is on both sides."},
	"max": {"label": "Max", "unweighted": true,
		"blurb": "An experiment: each of the style's 256 numbers the largest any of the voices has (weights do nothing). No voice was taught a style like it, though every word was still heard in each one tried."},
	"min": {"label": "Min", "unweighted": true,
		"blurb": "An experiment: each of the style's 256 numbers the smallest any of the voices has (weights do nothing). No voice was taught a style like it, though every word was still heard in each one tried."},
}

## A reader's part in a method that gives parts ([constant METHODS] `parts`).
const PARTS := {
	"both": {"label": "Both", "blurb": "On both sides: its sound and its delivery."},
	"sound": {"label": "Sound", "blurb": "Its timbre: what the voice sounds like."},
	"delivery": {"label": "Delivery", "blurb": "Its prosody: how the voice paces, lifts and leans on the words."},
}

## What eSpeak reads a blend in. Unsaid, the accent of its heaviest reader (in Sound and delivery, its
## heaviest delivery).
const ACCENTS := {
	"": {"label": "Accent: its heaviest voice's", "blurb": "Read in the accent of the reader with the most weight - the delivery's, in Sound and delivery."},
	"american": {"label": "American", "blurb": "Read as American English, whoever is in it."},
	"british": {"label": "British", "blurb": "Read as British English, whoever is in it."},
}

## A reader's weight, at least and at most: a ratio, so 2 and 1 are two parts to one.
const WEIGHT_MIN := 0.1
const WEIGHT_MAX := 10.0


## [param spec] read: `{method, accent, voices: [{reader, weight, part}]}`, every value one this file
## knows (an unknown method is a mix, an unknown accent or part unsaid, a weight clamped) - {} for "".
static func parse(spec: String) -> Dictionary:
	var at := spec.find(":")
	if spec.strip_edges().is_empty() or at < 0:
		return {}
	var head := spec.substr(0, at).strip_edges().to_lower().split(" ", false)
	var method := String(head[0]) if head.size() > 0 else "mix"
	var accent := String(head[1]) if head.size() > 1 else ""
	var out := {"method": method if METHODS.has(method) else "mix",
		"accent": accent if ACCENTS.has(accent) else "", "voices": []}
	for entry in spec.substr(at + 1).split(",", false):
		var words := String(entry).strip_edges().split(" ", false)
		if words.is_empty():
			continue
		var v := {"reader": String(words[0]), "weight": 1.0, "part": "both"}
		for w in words.slice(1):
			var word := String(w).to_lower()
			if word.is_valid_float():
				v["weight"] = clampf(float(word), WEIGHT_MIN, WEIGHT_MAX)
			elif PARTS.has(word):
				v["part"] = word
		(out["voices"] as Array).append(v)
	return out


## The line for [param method], [param accent] and [param voices] (`[{reader, weight, part}]`): "" for
## fewer than two readers, a part written only where the method gives parts, a weight of 1 unsaid.
static func compose(method: String, accent: String, voices: Array) -> String:
	if voices.size() < 2:
		return ""
	var parts := bool(Registry.field(METHODS, method, "parts", false))
	var weighted := not bool(Registry.field(METHODS, method, "unweighted", false))
	var rows := PackedStringArray()
	for v in voices:
		var d: Dictionary = v
		var row := String(d.get("reader", ""))
		var w := clampf(float(d.get("weight", 1.0)), WEIGHT_MIN, WEIGHT_MAX)
		if weighted and not is_equal_approx(w, 1.0):
			row += " " + _weight(w)
		var part := String(d.get("part", "both"))
		if parts and part != "both" and PARTS.has(part):
			row += " " + part
		rows.append(row)
	var head := method if METHODS.has(method) else "mix"
	if ACCENTS.has(accent) and not accent.is_empty():
		head += " " + accent
	return "%s: %s" % [head, ", ".join(rows)]


## A weight as a person writes it: 2, 0.5, 1.25 - never 2.0.
static func _weight(w: float) -> String:
	var r := snappedf(w, 0.01)
	return str(int(r)) if is_equal_approx(r, roundf(r)) else String.num(r, 2)


## The readers [param spec] names, in its order: their pack names.
static func readers(spec: String) -> PackedStringArray:
	var out := PackedStringArray()
	for v in parse(spec).get("voices", []):
		out.append(String((v as Dictionary)["reader"]))
	return out


## A blend said in words for a person: the method, then each reader by the name its pack is known by
## (`af_heart` is heart) and its share - "Mix: heart 67%, emma 33%"; in a method that gives parts, each
## reader's part and its weight where it is not 1 ("Sound and delivery: heart sound, emma delivery").
## [param brief], its readers alone ("heart + emma"). "" for no blend.
static func line(spec: String, brief := false) -> String:
	var b := parse(spec)
	var voices: Array = b.get("voices", [])
	if voices.size() < 2:
		return ""
	var names := PackedStringArray()
	var total := 0.0
	for v in voices:
		var reader := String((v as Dictionary)["reader"])
		names.append(reader.get_slice("_", 1) if reader.contains("_") else reader)
		total += float((v as Dictionary)["weight"])
	if brief:
		return " + ".join(names)
	var method := String(b["method"])
	var parts := bool(Registry.field(METHODS, method, "parts", false))
	var rows := PackedStringArray()
	for k in voices.size():
		var d: Dictionary = voices[k]
		var w := float(d["weight"])
		if bool(Registry.field(METHODS, method, "unweighted", false)):
			rows.append(names[k])
		elif parts:
			rows.append("%s %s%s" % [names[k], Registry.label(PARTS, String(d["part"])).to_lower(),
				"" if is_equal_approx(w, 1.0) else " " + _weight(w)])
		else:
			rows.append("%s %d%%" % [names[k], roundi(100.0 * w / maxf(total, 0.001))])
	var said := Registry.label(METHODS, method) + ": " + ", ".join(rows)
	if not String(b["accent"]).is_empty():
		said += " (" + Registry.label(ACCENTS, String(b["accent"])) + ")"
	return said
