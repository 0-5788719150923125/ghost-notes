extends DeskMedium
class_name LetterMedium

## LetterMedium - somebody writing a letter at a desk, reading it aloud as the pen puts it down
## (next/letter.md). The desk's medium ([DeskMedium]) - its pad, its pen, its camera, the voice followed
## word by word - with the letter's own hand and the letter's own moments ([LetterScript]).
##
## WHAT IT DRAWS FROM: the reading's document (`_subs.document`) - its `source`, the letter with its marks,
## and its `letter`, what the Letter component hands the reading ([method LetterCard.document]): the hand's
## `seed`, each sketch's SVG (`svgs`), the ink step's layout of them (`ink`) and each picture's file
## (`pictures`). The words are the hand's own, so nothing else is needed to write them: a letter whose
## sketches and pictures are not made yet plays all the same, its sketches' paragraphs said and its
## pictures' passages read over the desk.
##
## THE PEN WRITES TWO WORDS AHEAD ([LetterScript]'s class note; 2026-10-27, the user: "maybe 2 words ahead of the
## speaking?"): the desk's elastic dictation, each word written while the voice says the one [constant
## LetterScript.AHEAD_WORDS] before it ([method _due], [method _paced_end], [method _share]) - on the voice's own
## times, so at any voice's speed - and never quicker than [constant LetterScript.QUICKEST] the hand's pace; a
## paragraph the voice waits for, begun as the voice gets to it; for a page to turn, no sooner than the voice has
## read it. Where the pen cannot be that far ahead the voice waits
## for it (the rests the script wrote into it). Under a picture the dictation is the desk's own, the pen kept
## with the voice, unseen. A line's way back to the margin is a quick return ([constant LINE_RETURN]), as a
## hand's is.
##
## A THOUGHT IS NOT WRITTEN: while the writer thinks a passage in italics the pen is lifted.
##
## THE CAMERA'S ARC OVER A PAGE (2026-10-27, the user: "The forward and backward zooming of the camera is
## nauseating. Like the journal and tablet mediums, we really need to dial that behavior back, and make it
## much more gradual/gentle"): as the book's and the tablet's ([method _arc]) - a page opens on the whole pad,
## closes in on the writing as it gets under way and lets go before its turn - between two framings under
## twice as far apart ([constant LETTER_WIDE], [constant LETTER_LOCAL]; it had been the desk's 1.45 m and
## 0.38, near four times, all the way out and back at every turn), on the tablet's slow springs
## ([constant LETTER_TAU]). Nothing else moves it in or out - a thought, a point and a tap move where it
## looks and never how close (each had stepped it back and in again) - but a point at the camera, a little
## back ([constant CAMERA_K]), and a still, held close on its drawing. Across, it holds the column's middle:
## close, the whole pad's width is in the frame, and it had swung between a short line and a long one.
##
## THE PEN TAPS (`<!-- tap -->`): it is lifted, turned over in the hand and its top tapped on the pad, or
## the desk beside it, a few times, then turned back - [method _tap_pose], laid over the pen's own place
## while it lasts.
##
## THE PEN POINTS AT WHOEVER WATCHES (`<!-- point: camera -->`): lifted off the page and its nib turned to
## the lens for the sentence, then put back ([method _camera_pose]).
##
## A PICTURE TAKES THE SCREEN (`<!-- image (full): -->` ... `<!-- /image -->`): it fades up over the desk
## as the passage under it begins, moves slowly in its own way ([constant MOVES]: a pan its length guessed
## from the script, never from the voice's times, so it never jumps as a live reading's words arrive) and
## fades back to the desk as the passage ends. The pen writes on under it: the page the camera comes back
## to has the passage on it. PICTURES DISSOLVE INTO ONE ANOTHER (2026-10-27, the user: "blend from one picture
## into a second one, or a third one, directly without ever seeing the page again ... each with different
## panning/zooming behavior"): one whose passage begins where the last one's ends (its span's `blend`) comes
## up over it, the one under held whole until it has, so the page is never seen between them
## ([method pictures_at]); and no picture moves as the one before it did.
##
## A STILL IS DEAD STILL (`<!-- still -->`: "the camera holds still on the cross and the dot, with the pen
## well clear of them, or the test cannot work"): from the mark to the next written line the camera frames
## the last drawing on the page, its slow wander stopped where it was, and the pen is sent off the pad.
##
## THE SUBTITLES CAPTION ONLY WHAT CANNOT BE READ ON THE PAGE (2026-10-27, the user: "hide the subtitles for any
## text that is already being written on the page ... anything we can't see or didn't write directly on the page
## will need subtitles"): a line is drawn when any of its words is not written - a thought, a sketch's narration -
## or while a picture covers the screen ([method _captioned], [member Subtitles.captions]); a line of the
## letter, written two words ahead of the voice, is read on the page instead.
##
## THE LETTER ENDS WHEN THE PEN DOES: an unspoken line after the last word ("Dear Ink," on a new page) is
## written before the camera stands back and the picture goes to black.

## THE CAMERA ([method _arc]): close on the writing, nearer than the desk's, which frames a formula (a line
## of a letter is small; at this the camera sees about three fifths of the page's height and all its
## width); wide, the whole pad with a little desk round it, for the opening, each turn and the close. Its
## springs' time (seconds), the tablet's. A page closes in over ARC_IN from ARRIVE after it has come up -
## the first from the intro's end, over the blank page ([constant LetterScript.BLANK_PAGE]) - and lets go
## over ARC_OUT, done OUT_BEFORE its turn: the springs run about twice their time behind, so the turn is
## seen from nearly the whole pad (simulated: a fifth of the way in as the sheet lifts).
const LETTER_LOCAL := {"dist": 0.47, "pitch": 80.0}
const LETTER_WIDE := {"dist": 0.85, "pitch": 77.0}
const LETTER_TAU := 4.2
const ARRIVE := 1.0
const ARC_IN := 9.0
const ARC_OUT := 9.0
const OUT_BEFORE := 7.0
## A line's return to the margin: as fast as a hand's (px of the page a second), and never quicker than
## [constant LetterScript.RETURN], which the voice's rests are sized by.
const LINE_RETURN := 2600.0
## A PICTURE: its fade (seconds) - up, out from just after its passage's last word, the voice resting until it
## is gone, and over the picture before it ([constant LetterScript.IMAGE_FADE]).
const IMAGE_FADE := LetterScript.IMAGE_FADE
## HOW A PICTURE MOVES while it is up, each a row: how big it is at its start and at its end (a share over
## just covering the screen) and how far it drifts across what is left over of it (a share of that slack, at
## the least and the most). Each picture takes one by the seed, never the one the picture before it took, and
## drifts at least a quarter turn away from that one's way ([method moves_of]).
const MOVES := {
	"in": {"label": "Closer", "blurb": "Comes slowly closer, drifting a little across.",
		"grow": [1.04, 1.16], "drift": [0.4, 0.7]},
	"out": {"label": "Back", "blurb": "Starts close and slowly draws back, drifting a little across.",
		"grow": [1.16, 1.04], "drift": [0.4, 0.7]},
	"across": {"label": "Across", "blurb": "Held a little close and carried slowly across.",
		"grow": [1.15, 1.15], "drift": [0.8, 1.0]},
}
## THE TAP: where the top comes down - by the line last written, where the camera is (px of the page:
## on the paper a rule and a half under it, toward the right; or on the desk beside the pad, level with
## it), how long it takes to turn the pen over and back, how many taps, how high it lifts between them
## (m), and the pen's lean as it is held upside down (from the surface to the nib: up, right, toward the
## writer).
const TAP_SPOTS := {"pad": Vector2(PW * 0.8, DeskScript.RULE * 1.5), "desk": Vector2(PW + 110.0, DeskScript.RULE * 0.5)}
const TAP_FLIP := 0.55
const TAP_N := 3
const TAP_RISE := 0.016
const TAP_LEAN := Vector3(0.32, 0.86, 0.4)
## The pen's length from nib to top (m), as [DeskMedium] builds it.
const PEN_TOP := PEN_LEN + 0.02
## POINTING AT THE CAMERA: the nib held this high (m) over where the camera looks, the pen turned this
## far off the lens's own line, how long it takes to get there and back, and how long it is held after the
## sentence. A camera looking all but straight down has the pen's body running down from the nib: at 11 cm
## up its top went 2 cm into the pad (measured on paper, 2026-10-26); turned 37 degrees off the lens's line
## to clear it, it read as the pen writing (the first render). Held 20 cm up and 22 degrees off, it is a pen
## aimed at the lens, its top 6 cm over the pad. The camera stands back a little for it ([constant
## CAMERA_K]: of the way from [constant LETTER_WIDE] to [constant LETTER_LOCAL], so a fifth further off).
const CAMERA_RISE := 0.2
const CAMERA_OFF := 0.3
const CAMERA_EASE := 0.7
const CAMERA_HOLD := 1.0
const CAMERA_K := 0.7
## THE CAMERA LOOKS AT WHAT THE PEN DOES AWAY FROM THE LINE - a point, a tap - from this long before it (its
## springs are slow, and close it sees three fifths of the page), as close as it was.
const AWAY_LEAD := 3.5
## THE WRITER HESITATES TOO (2026-10-27, the user: "after "Dear Pen," - why was there no hesitation at all?" - the
## voice rested 2.4 s there, and the pen, two words ahead, wrote straight on): through a hesitation the pen stops
## after the word before it and takes up again this long (seconds) before the voice goes on ([method
## _resume_floor]).
const RESUME_LEAD := 0.9
## A STILL IS STILL FROM ITS FIRST MOMENT: the camera heads for the drawing [constant AWAY_LEAD] early, on
## springs this much quicker than its own, so it has settled when the still begins (on its own it was
## still drifting 15 px three seconds in - a test the viewer does on the screen cannot be done on a
## moving one).
const STILL_SPRING := 0.3

## The plate the pictures are shown on, over the desk ([method _show_picture]): each up, bottom first.
class Plate extends Node2D:
	var layers: Array = []          # {tex, alpha, grow, drift}

	func _draw() -> void:
		var view := get_viewport_rect().size
		var cover := LetterMedium.cover_of(layers)
		if cover <= 0.0:
			return
		draw_rect(Rect2(Vector2.ZERO, view), Color(0.0, 0.0, 0.0, cover))
		for l in layers:
			var tex: Texture2D = l["tex"]
			var ts := tex.get_size()
			if ts.x <= 0.0 or ts.y <= 0.0:
				continue
			var size := ts * maxf(view.x / ts.x, view.y / ts.y) * float(l["grow"])
			var slack := size - view
			var at := -slack * 0.5 + slack * 0.5 * (l["drift"] as Vector2)
			draw_texture_rect(tex, Rect2(at, size), false, Color(1.0, 1.0, 1.0, float(l["alpha"])))


var _spans: Array = []
var _pictures := {}            # an image's key -> its texture
var _written_words := PackedByteArray()  # a spoken word -> 1 when a line of the letter writes it
var _pauses := {}              # a spoken word a hesitation follows -> true ([member LetterScript] `pauses`)
var _plate: Plate
var _still_from := -1.0        # when the still up now began (its wander's time), -1 for none


func mount(st: SubViewport) -> void:
	super.mount(st)
	_plate = Plate.new()
	_plate.material = ShaderMaterial.new()
	(_plate.material as ShaderMaterial).shader = _plate_shader()
	add_child(_plate)
	# over the desk, under the opening's blur and the title
	move_child(_plate, _blur.get_index())


## A FLASHBACK'S LOOK: the edges dimmed, the color a little warmer and quieter than the desk's.
static func _plate_shader() -> Shader:
	var sh := Shader.new()
	sh.code = """shader_type canvas_item;
void fragment() {
	vec4 c = texture(TEXTURE, UV) * COLOR;
	vec2 q = SCREEN_UV - 0.5;
	float v = 1.0 - smoothstep(0.32, 0.78, length(q * vec2(1.0, 0.8)));
	float g = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	c.rgb = mix(vec3(g), c.rgb, 0.82) * vec3(1.03, 1.0, 0.95);
	c.rgb *= mix(0.62, 1.0, v);
	COLOR = c;
}
"""
	return sh


# --- the document ------------------------------------------------------------------------------

func _ensure_doc() -> void:
	if _subs == null or not is_instance_valid(_subs):
		return
	var d: Dictionary = _subs.document
	_title.channel = String(d.get("title", ""))
	_title.byline = String(d.get("byline", d.get("author", "")))
	var src := String(d.get("source", ""))
	var letter: Dictionary = d.get("letter", {}) if d.get("letter") is Dictionary else {}
	var start: PackedStringArray = d.get("start_words", PackedStringArray()) \
		if d.get("start_words") is PackedStringArray else PackedStringArray()
	# hashed as they are, never printed first: every sketch's SVG made into one string, every frame
	var key := "%d|%d|%s|%d|%d|%s" % [src.hash(), int(letter.get("seed", 0)), String(letter.get("hand", "")),
		hash(letter.get("svgs", {})), hash(letter.get("pictures", {})), " ".join(start)]
	if key == _doc_key:
		return
	_doc_key = key
	load_letter(src, letter, start, int(d.get("start_index", -1)))


## LOAD A LETTER: [param source] (its text, its marks in it) and [param letter] (`{seed, hand, svgs, ink,
## pictures}`, any of them missing); for a reading started mid-way its first words [param start]
## (normalized), [param near] the index they are about. Public for a gate, which hands it one by hand.
func load_letter(source: String, letter: Dictionary, start := PackedStringArray(), near := -1) -> void:
	_seed = int(letter.get("seed", _seed))
	look = DeskLook.of(_seed)
	_dress()
	var svgs: Dictionary = letter.get("svgs", {}) if letter.get("svgs") is Dictionary else {}
	var ink: Dictionary = letter.get("ink", {}) if letter.get("ink") is Dictionary else {}
	var fonts: Dictionary = ink.get("fonts", {}) if ink.get("fonts") is Dictionary else {}
	_records = LetterScript.records_of(ink)
	_strokes = {}
	var lengths := {}
	for id in _records:
		var got := Ink.strokes_of(_records[id], _seed, fonts)
		var sched := Ink.schedule(got["strokes"], _seed)
		_strokes[id] = sched
		lengths[id] = float(sched["length"])
	var parsed := LetterScript.parse(source, _seed, svgs, lengths, _records,
		LetterHand.of(String(letter.get("hand", ""))))
	_actions = parsed["actions"]
	_spans = parsed["spans"]
	var moves := moves_of(_spans, _seed)
	for i in moves.size():
		if not (moves[i] as Dictionary).is_empty():
			(_spans[i] as Dictionary)["move"] = moves[i]
	var last_y := DeskScript.FIRST_RULE
	var last_page := 0
	for a in _actions:
		var act: Dictionary = a
		match String(act["kind"]):
			"pad-text", "draw":
				if act.has("at"):
					last_y = (act["at"] as Vector2).y + float(act.get("d", 0.0))
					last_page = int(act["page"])
				if String(act["kind"]) == "pad-text":
					_strokes[String(act["id"])] = act["strokes"]
			"tap":
				# by the line last written, on its page
				var spot: Vector2 = TAP_SPOTS.get(String(act.get("target", "pad")), TAP_SPOTS["pad"])
				act["spot"] = Vector2(spot.x, clampf(last_y + spot.y, DeskScript.FIRST_RULE, PH - 60.0))
				act["page"] = last_page
	for p in parsed["ignored"]:
		push_warning("ghost: letter - %s is in a paragraph the pen writes or draws through, and is not made" % p)
	var spoken: PackedStringArray = parsed["spoken"]
	_spoken_n = spoken.size()
	_written_words = PackedByteArray()
	_written_words.resize(_spoken_n)
	_pauses = {}
	for h in parsed.get("pauses", []):
		_pauses[int(h)] = true
	for a in _actions:
		var act: Dictionary = a
		if String(act["kind"]) == "pad-text":
			for k in range(int(act.get("after", 0)), mini(int(act.get("after", 0)) + int(act.get("span", 0)), _spoken_n)):
				_written_words[k] = 1
	var from := TabletScript.find_run(spoken, start, near) if not start.is_empty() else -1
	var est := PackedFloat32Array()
	if from > 0:
		for w in DeskScript.rehearsal(parsed):
			est.append(float((w as Dictionary)["t0"]))
	_follower.reset(spoken, from, est)
	_built_n = -1
	_held = {}
	_plan = []
	_plan_rev += 1
	_done_ink = {}
	for i in _actions.size():
		_plan.append({"start": INF, "end": INF, "turn_at": INF})
	_load_pictures(letter.get("pictures", {}) if letter.get("pictures") is Dictionary else {})
	_snap = true
	for c in [_canvas, _wet, _canvas_turn]:
		if c != null:
			(c as PadCanvas).forget()


## EVERY PICTURE THE LETTER SHOWS, read now - at the session's start, so a render's frames find them
## made: [param paths] (key -> file) first, the painter's library for one not handed.
func _load_pictures(paths: Dictionary) -> void:
	_pictures = {}
	for s in _spans:
		var sp: Dictionary = s
		if String(sp["kind"]) != "image" or _pictures.has(String(sp["key"])):
			continue
		var path := String(paths.get(String(sp["key"]), ""))
		if path.is_empty() or not FileAccess.file_exists(path):
			path = Illustrations.path_for(String(sp["key"]))
		if path.is_empty() or not FileAccess.file_exists(path):
			continue
		var img := Image.load_from_file(ProjectSettings.globalize_path(path))
		if img != null and not img.is_empty():
			_pictures[String(sp["key"])] = ImageTexture.create_from_image(img)


# --- the clock ----------------------------------------------------------------------------------

func advance(features, delta: float, bookend: float) -> void:
	super.advance(features, delta, bookend)
	_show_picture()


## The span of [param kind] up at [member _now], {} for none: `{span, t0, t1}`, its window ([method _window]).
func _span_now(kind: String) -> Dictionary:
	for s in _spans:
		var sp: Dictionary = s
		if String(sp["kind"]) != kind:
			continue
		var w := _window(sp)
		if w.x < INF and _now >= w.x and _now <= w.y:
			return {"span": sp, "t0": w.x, "t1": w.y}
	return {}


## WHEN A SPAN IS UP: a thought from its first word to the end of its last; a still from the end of the word
## before its mark to the first word of the line written next (it holds over no words of its own - the
## hesitation it is for). Words not heard yet are guessed ([method DeskMedium._guess]); INF before any is.
func _window(sp: Dictionary) -> Vector2:
	var from := int(sp["from"])
	var to := int(sp["to"])
	if String(sp["kind"]) == "still":
		var a := _guess(from - 1, true) if from > 0 else 0.0
		var b := _guess(to, false) if to < _spoken_n else INF
		return Vector2(a, b)
	return Vector2(_guess(from, false), _guess(to - 1, true))


## THE PICTURES UP NOW, on the plate over the desk ([method pictures_at]).
func _show_picture() -> void:
	var layers: Array = []
	for p in pictures_at():
		var tex: Texture2D = _pictures.get(String(p["key"]))
		if tex != null and float(p["alpha"]) > 0.0:
			layers.append({"tex": tex, "alpha": float(p["alpha"]), "grow": float(p["grow"]), "drift": p["drift"]})
	if layers != _plate.layers:
		_plate.layers = layers
		_plate.queue_redraw()


## WHAT THE SCREEN SHOWS OF THE PICTURES at [member _now], bottom first: each `{key, alpha, grow, drift}` -
## faded in from the end of the word before its passage, over the desk or over the picture before it (which is
## held whole under it until it is in), and out after the passage's last word, unless the next comes up over it
## there; grown and drifted along its move ([constant MOVES]) by how far through the passage the script says it
## is. Only a picture there is a file for is shown. Pure: a function of the voice's times.
func pictures_at() -> Array:
	var shown: Array = []
	for s in _spans:
		var sp: Dictionary = s
		if String(sp["kind"]) == "image" and _pictures.has(String(sp["key"])) and int(sp["to"]) > int(sp["from"]):
			shown.append(sp)
	var out: Array = []
	for i in shown.size():
		var sp: Dictionary = shown[i]
		var from := int(sp["from"])
		var to := int(sp["to"])
		var nxt: Dictionary = shown[i + 1] if i + 1 < shown.size() else {}
		var under := not nxt.is_empty() and bool(nxt.get("blend", false)) and int(nxt["from"]) == to
		# its fade begins as the next's would over it: the same moment, so a dissolve has no gap
		var t0 := _guess(from - 1, true) + LetterScript.IMAGE_AFTER if from > 0 else _guess(from, false) - IMAGE_FADE
		var t1 := _guess(to - 1, true) + LetterScript.IMAGE_AFTER
		if t0 == INF or _now < t0 or _now > t1 + IMAGE_FADE:
			continue
		var a := clampf((_now - t0) / IMAGE_FADE, 0.0, 1.0)
		if not under:
			a = minf(a, 1.0 - clampf((_now - t1) / IMAGE_FADE, 0.0, 1.0))
		var u := clampf((_now - t0) / maxf(float(to - from) * DeskScript.SAID_WORD + IMAGE_FADE * 2.0, 1.0), 0.0, 1.0)
		var mv: Dictionary = sp.get("move", {"grow": Vector2(1.04, 1.16), "way": Vector2.RIGHT, "drift": 0.5})
		var grow: Vector2 = mv["grow"]
		out.append({"key": String(sp["key"]), "alpha": a * a * (3.0 - 2.0 * a), "grow": lerpf(grow.x, grow.y, u),
			"drift": (mv["way"] as Vector2) * lerpf(-float(mv["drift"]), float(mv["drift"]), u)})
	return out


## The picture on top at [member _now] ([method pictures_at]): `{key, alpha, grow, drift}`, key "" for none.
func picture_at() -> Dictionary:
	var up := pictures_at()
	return up.back() if not up.is_empty() else {"key": "", "alpha": 0.0, "grow": 1.0, "drift": Vector2.ZERO}


## How much of the screen [param layers] (each with an `alpha`) cover, one over another: 0 the desk, 1 none of it.
static func cover_of(layers: Array) -> float:
	var through := 1.0
	for l in layers:
		through *= 1.0 - clampf(float((l as Dictionary)["alpha"]), 0.0, 1.0)
	return 1.0 - through


## EACH PICTURE'S MOVE by [param spans]' index (`{}` for a span that is no picture): `{kind, grow, way, drift}` - a
## row of [constant MOVES] drawn from [param seed] and the picture's place in the letter, never the row the picture
## before it took, `grow` its start and end, `way` its drift's direction (at least a quarter turn from the one
## before), `drift` how far along it.
static func moves_of(spans: Array, seed: int) -> Array:
	var out: Array = []
	var last := ""
	var angle := INF
	var n := 0
	for s in spans:
		var sp: Dictionary = s
		if String(sp["kind"]) != "image":
			out.append({})
			continue
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(["letter-picture", seed, n])
		n += 1
		var kinds: Array = MOVES.keys().filter(func(k: String) -> bool: return k != last)
		var kind := String(kinds[rng.randi() % kinds.size()])
		var row: Dictionary = MOVES[kind]
		angle = rng.randf() * TAU if angle == INF else angle + rng.randf_range(PI * 0.5, PI * 1.5)
		var drift: Array = row["drift"]
		out.append({"kind": kind, "grow": Vector2(float(row["grow"][0]), float(row["grow"][1])),
			"way": Vector2.from_angle(angle), "drift": rng.randf_range(float(drift[0]), float(drift[1]))})
		last = kind
	return out


## WHEN A LINE MAY BEGIN: as the voice begins the word [constant LetterScript.AHEAD_WORDS] before its first; for a
## paragraph the voice waits for, as the voice gets to it (its first word less the rest the voice took there,
## `gate_rest`); for a page to turn, once the voice has read the page and the page is turned. Under a picture,
## and anything but a line, the desk's dictation.
func _due(i: int, t0: float) -> float:
	var a: Dictionary = _actions[i]
	if String(a["kind"]) != "pad-text" or _pictured(a):
		return super._due(i, t0)
	if t0 == INF:
		return INF
	var k0 := int(a["after"])
	var due := t0
	match String(a.get("gate", "")):
		"voice":
			due = t0 - float(a.get("gate_rest", 0.0))
		"turn":
			var read := _word_t1(k0 - 1)
			due = read + LetterScript.TURN_REST if read < INF else INF
		_:
			due = _word_t0(k0 - LetterScript.AHEAD_WORDS) if k0 >= LetterScript.AHEAD_WORDS else t0
	return maxf(due, _resume_floor(k0))


## THE WRITER HESITATES TOO: the soonest the pen may write spoken word [param k] - [constant RESUME_LEAD] before
## the voice goes on from a hesitation that comes between the word the voice is on as the pen writes it
## ([constant LetterScript.AHEAD_WORDS] back) and the word itself; -INF for none.
func _resume_floor(k: int) -> float:
	var soonest := -INF
	for h in range(maxi(k - LetterScript.AHEAD_WORDS, 0), k):
		if _pauses.has(h):
			var on := _word_t0(h + 1)
			if on == INF:
				on = _guess(h + 1, false)
			soonest = maxf(soonest, on - RESUME_LEAD)
	return soonest


## The times the pen writes line [param a]'s spoken words by, begun at [param start]: `[t0s, t1s]` - each word
## the voice's word [constant LetterScript.AHEAD_WORDS] before it, never before the line may begin (the first
## words of a paragraph the voice waits for, written as it gets there), nor past a hesitation before the pen
## is taken up again ([method _resume_floor]).
func _ahead_times(a: Dictionary, start: float) -> Array:
	var t0s := PackedFloat32Array()
	var t1s := PackedFloat32Array()
	var k0 := int(a["after"])
	var last := start
	for j in int(a["span"]):
		var k := k0 + j - LetterScript.AHEAD_WORDS
		var w0 := _word_t0(k) if k >= 0 and (String(a.get("gate", "")) == "" or k >= k0) else -INF
		var w1 := _word_t1(k) if w0 > -INF else -INF
		if w0 == INF or w1 == INF:
			w0 = last + 0.05
			w1 = w0 + DeskScript.EST_WORD * 0.9
		# the writer hesitating: nothing past the hesitation before the pen is taken up again
		var resume := _resume_floor(k0 + j)
		if resume > w0:
			w1 = maxf(w1, resume + (w1 - w0))
			w0 = resume
		t0s.append(maxf(w0, start))
		t1s.append(maxf(w1, start + 0.01))
		last = t1s[t1s.size() - 1]
	return [t0s, t1s]


## Is line [param a] read under a picture ([method LetterScript._pictured]) - where nobody reads along, and
## the desk's dictation keeps the pen with the voice?
func _pictured(a: Dictionary) -> bool:
	return LetterScript._pictured(int(a.get("after", 0)), _spans)


## WHEN A LINE WRITTEN AHEAD ENDS: as the voice ends the word [constant LetterScript.AHEAD_WORDS] before its last,
## never quicker than [constant LetterScript.QUICKEST] its ink's own time nor slower than the desk's slowest pen; a
## sketch, as its words end, no quicker than [method LetterScript.draw_pace]; one under a picture, and anything else,
## as the desk's.
func _paced_end(i: int, start: float, end: float) -> float:
	var a: Dictionary = _actions[i]
	if String(a["kind"]) == "draw" and int(a.get("span", 0)) > 0:
		# A SKETCH DASHED OFF where its ink outruns its words ([method LetterScript.draw_pace], the pace the voice's rest
		# after them was sized by); the desk then draws it as slowly as the next line leaves it time for
		var said := _word_t1(int(a["after"]) + int(a["span"]) - 1)
		if said == INF:
			return end
		var ink := float(a.get("write", 0.0))
		return clampf(said, start + ink / LetterScript.draw_pace(ink, said - start), start + ink / DeskScript.MIN_PACE)
	if String(a["kind"]) != "pad-text" or _pictured(a) or int(a.get("span", 0)) <= 0:
		return end
	var write := float(a.get("write", 0.0))
	var times := _ahead_times(a, start)
	var wanted: float = (times[1] as PackedFloat32Array)[int(a["span"]) - 1]
	return clampf(wanted, start + write / LetterScript.QUICKEST, start + write / DeskScript.MIN_PACE)


## How far through its writing action [param i] is at [param t]: a line written ahead by the desk's elastic
## dictation over its words' times [constant LetterScript.AHEAD_WORDS] words back ([method _ahead_times]);
## anything else (a line under a picture too) as the desk's.
func _share(i: int, t: float) -> float:
	var a: Dictionary = _actions[i]
	if String(a["kind"]) != "pad-text" or _pictured(a) or int(a.get("span", 0)) <= 0:
		return super._share(i, t)
	var start := float(_plan[i]["start"])
	var times := _ahead_times(a, start)
	return elastic(t, start, float(_plan[i]["end"]), times[0], times[1])


## THE INTRO ENDS BEFORE THE PAGE'S BLANK MOMENT ([constant LetterScript.BLANK_PAGE]): the title and the
## lens's blur go that long before the pen first touches the page - planned, else its first word less the
## voice's head start for it - not at the first word, so the empty pad is seen.
func _opening() -> float:
	var t := super._opening()
	if t == INF:
		return INF
	var touch := float(_plan[0]["start"]) if not _plan.is_empty() else INF
	var first: Dictionary = _actions[0] if not _actions.is_empty() else {}
	return (touch if touch < INF else t - float(first.get("gate_rest", 0.0))) - LetterScript.BLANK_PAGE


## The subtitles are the letter's to caption ([method _captioned]); the desk's own binding otherwise.
func bind_captions(subs) -> bool:
	var own := super.bind_captions(subs)
	# asked by name: a gate that builds the medium has no overlay's autoloads to compile it against
	if subs != null and "captions" in subs:
		subs.captions = _captioned
	return own


## IS THE LINE FROM SUBTITLE WORD [param w0] TO [param w1] CAPTIONED at [param _t]? While a picture covers the
## screen, yes - the page is not seen; else only when some word of it is not written on the page (a thought, a
## sketch's narration, a word the voice says that no line has).
func _captioned(w0: int, w1: int, _t: float) -> bool:
	if cover_of(pictures_at()) >= 0.5:
		return true
	var map: Array = _follower.map
	for w in range(w0, w1 + 1):
		var si := int(map[w]) if w >= 0 and w < map.size() else -1
		if si < 0:
			continue
		if si >= _written_words.size() or _written_words[si] == 0:
			return true
	return false


## THE CLOSE waits for the pen: down to black over the outro once the last word is said AND the last
## thing written is done.
func _end_fade() -> float:
	var last := _follower.known_last()
	if _spoken_n == 0 or last < _spoken_n - 1:
		return 1.0
	var end := _follower.st1[last]
	if _now < end:
		return 1.0          # nothing fades before the last word is said: the plan is not walked every frame
	for p in _plan:
		var e := float((p as Dictionary)["end"])
		if e == INF:
			return 1.0
		end = maxf(end, e)
	var o := maxf(feed.tail(), 0.0)
	var beat := minf(0.8, o * 0.15)
	var x := clampf((_now - (end + beat)) / maxf(o - beat, 0.05), 0.0, 1.0)
	return 1.0 - x * x * (3.0 - 2.0 * x)


## The letter is over once its last word is said and the pen has done its last.
func _ended() -> bool:
	if not super._ended():
		return false
	for p in _plan:
		if float((p as Dictionary)["end"]) > _now:
			return false
	return true


# --- the pen ------------------------------------------------------------------------------------

func _travel(px: float) -> float:
	return maxf(px / LINE_RETURN, LetterScript.RETURN)


## The pen gets out of the way for a still too, wherever it begins between the two actions.
func _parks(last: int, next: int) -> bool:
	if super._parks(last, next):
		return true
	var a: Dictionary = _actions[last]
	var from := int(a.get("after", 0)) + int(a.get("span", 0))
	var to := _spoken_n if next < 0 else int((_actions[next] as Dictionary).get("after", 0))
	for s in _spans:
		var sp: Dictionary = s
		if String(sp["kind"]) == "still" and int(sp["from"]) >= from and int(sp["from"]) <= to:
			return true
	return false


func _action_point(a: Dictionary, first: bool) -> Vector2:
	if String(a["kind"]) == "tap":
		return a.get("spot", TAP_SPOTS["pad"])
	return super._action_point(a, first)


func _pen_during(a: Dictionary, i: int, start: float) -> Dictionary:
	if String(a["kind"]) == "tap":
		return {"p": _action_point(a, true), "lift": REST_LIFT}
	return super._pen_during(a, i, start)


## THE PEN, as the desk places it - and then turned over to tap, or lifted to point at the lens.
func _place_pen() -> void:
	super._place_pen()
	var base := _pen.global_transform
	var pose := _tap_pose(base)
	if pose.is_empty():
		pose = _camera_pose(base)
	if not pose.is_empty():
		_pen.global_transform = _blend(base, pose["xf"], float(pose["f"]))


## WHILE A TAP LASTS: the pen upside down over its spot, its top coming down on it [constant TAP_N]
## times - `{xf, f}` (the pose, and how far into it the pen is: 0 as the tap begins and ends, 1 between).
## {} when no tap is under way.
func _tap_pose(_base: Transform3D) -> Dictionary:
	for i in _of_kind("tap"):
		var a: Dictionary = _actions[i]
		var s := float(_plan[i]["start"])
		var e := float(_plan[i]["end"])
		if s == INF or _now < s or _now > e:
			continue
		var f := minf(clampf((_now - s) / TAP_FLIP, 0.0, 1.0), clampf((e - _now) / TAP_FLIP, 0.0, 1.0))
		var v := clampf((_now - s - TAP_FLIP) / maxf(e - s - 2.0 * TAP_FLIP, 0.1), 0.0, 1.0) * float(TAP_N)
		var h := TAP_RISE * pow(sin(PI * fposmod(v, 1.0)), 0.6) if v > 0.0 and v < float(TAP_N) else TAP_RISE
		var spot := _world(_action_point(a, true), 0.0)
		if String(a.get("target", "pad")) == "desk":
			spot.y += LegalPad.DESK_Y
		var lean := TAP_LEAN.normalized()
		var top := spot + Vector3.UP * h
		return {"xf": _pen_frame(top + lean * PEN_TOP, -lean), "f": f * f * (3.0 - 2.0 * f)}
	return {}


## WHILE A POINT AT THE CAMERA LASTS: the nib held up over the page and turned to the lens - `{xf, f}`
## as [method _tap_pose] gives it, {} when none is.
func _camera_pose(_base: Transform3D) -> Dictionary:
	for s in _spans:
		var sp: Dictionary = s
		if String(sp["kind"]) != "camera":
			continue
		var t0 := _guess(int(sp["after"]), false)
		var t1 := _guess(int(sp["after"]) + int(sp["span"]) - 1, true) + CAMERA_HOLD
		if t0 == INF or t1 == INF or _now < t0 - CAMERA_EASE or _now > t1 + CAMERA_EASE:
			continue
		var f := minf(clampf((_now - (t0 - CAMERA_EASE)) / CAMERA_EASE, 0.0, 1.0),
			clampf((t1 + CAMERA_EASE - _now) / CAMERA_EASE, 0.0, 1.0))
		var nib := _c_aim + Vector3.UP * CAMERA_RISE
		var eye := _cam.global_position if _cam != null and _cam.is_inside_tree() else _c_aim + Vector3(0.0, 1.4, 0.25)
		var to_lens := (eye - nib).normalized()
		# the body behind the nib, away from the lens, turned a little off its line so it reads as a pen
		var up := (-to_lens + Vector3(CAMERA_OFF, CAMERA_OFF * 0.4, -CAMERA_OFF * 0.6)).normalized()
		return {"xf": _pen_frame(nib, up), "f": f * f * (3.0 - 2.0 * f)}
	return {}


## The pen's transform with its nib at [param nib] and its body along [param up] (nib to top), as
## [method DeskMedium._place_pen] builds one.
static func _pen_frame(nib: Vector3, up: Vector3) -> Transform3D:
	var y := up.normalized()
	var x := y.cross(Vector3.FORWARD)
	if x.length() < 0.01:
		x = y.cross(Vector3.RIGHT)
	x = x.normalized()
	var z := x.cross(y).normalized()
	return Transform3D(Basis(x, y, z), nib)


## From [param a] to [param b] by [param f], turned about the pen's middle where the fingers hold it, and
## lifted clear of the page on the way.
static func _blend(a: Transform3D, b: Transform3D, f: float) -> Transform3D:
	if f <= 0.0:
		return a
	if f >= 1.0:
		return b
	var qa := a.basis.get_rotation_quaternion()
	var qb := b.basis.get_rotation_quaternion()
	var basis := Basis(qa.slerp(qb, f))
	var mid := (a.origin + a.basis.y * PEN_TOP * 0.5).lerp(b.origin + b.basis.y * PEN_TOP * 0.5, f)
	mid += Vector3.UP * sin(PI * f) * 0.05
	return Transform3D(basis, mid - basis.y * PEN_TOP * 0.5)


# --- the camera ---------------------------------------------------------------------------------

func _local_frame() -> Dictionary:
	return LETTER_LOCAL


func _wide_frame() -> Dictionary:
	return LETTER_WIDE


## HOW CLOSE THE CAMERA IS MEANT TO BE at [member _now], 0 wide to 1 close: the page's arc - in over
## [constant ARC_IN] once it has come up, out over [constant ARC_OUT] before its turn - wide before the
## letter opens and once it is over. A turn not planned yet (a live reading's words arrive a sentence at a
## time) is guessed from its first word's ([method DeskMedium._guess]), so the camera lets go in time.
func _arc() -> float:
	if _ended():
		return 0.0
	var page := _pages().x
	var opening := _opening()
	var opened := opening if opening < INF else maxf(feed.intro_hold, 0.0)
	var turns := INF
	for i in _turn_actions():
		var a: Dictionary = _actions[i]
		var ta := float(_plan[i]["turn_at"])
		if ta == INF:
			ta = _guess(int(a.get("after", 0)), false) - DeskScript.TURN
		if int(a["page"]) == page:
			opened = ta + DeskScript.TURN
		elif int(a["page"]) > page:
			turns = ta
			break
	var k := smoothstep(opened + ARRIVE, opened + ARRIVE + ARC_IN, _now)
	if turns < INF:
		k = minf(k, 1.0 - smoothstep(turns - OUT_BEFORE - ARC_OUT, turns - OUT_BEFORE, _now))
	return k


## THE FRAMING: the desk's place on the page, the column's middle across, as close as the page's arc
## ([method _arc]) - and for a still, close on the last drawing on the page.
func _framing() -> Dictionary:
	var f := super._framing()
	f["k"] = _arc()
	f["line"] = Vector2(DeskScript.TEXT_X + LetterScript.LINE_W * 0.5, (f["line"] as Vector2).y)
	var still := _span_now("still")
	if still.is_empty() and _still_soon():
		var box := _last_drawn()
		if box.size.x > 0.0:
			f["line"] = box.get_center() - Vector2(0.0, 60.0)
			f["k"] = 1.0
			return f
	if not still.is_empty():
		var box := _last_drawn()
		if box.size.x > 0.0:
			f["line"] = box.get_center() - Vector2(0.0, 60.0)
			f["k"] = 1.0
		if _still_from < 0.0:
			_still_from = _now
		return f
	_still_from = -1.0
	# a point at the camera, under way or soon: stood back, so the pen held up reads as a pen
	for s in _spans:
		var sp: Dictionary = s
		if String(sp["kind"]) == "camera":
			var t0 := _guess(int(sp["after"]), false)
			var t1 := _guess(int(sp["after"]) + int(sp["span"]) - 1, true) + CAMERA_HOLD
			if t0 < INF and _now > t0 - AWAY_LEAD and _now < t1 + CAMERA_EASE:
				f["k"] = minf(float(f["k"]), CAMERA_K)
	# a point or a tap, under way or soon: framed on what it is about, as close as it was
	var page := _pages().x
	for i in _page_actions(page):
		var a: Dictionary = _actions[i]
		var start := float(_plan[i]["start"])
		if start == INF or start > _now + AWAY_LEAD:
			break
		if float(_plan[i]["end"]) < _now:
			continue
		if String(a["kind"]) == "point":
			var b := target_box(a)
			if b.size.x >= 0.0:
				f["line"] = b.get_center() - Vector2(0.0, 60.0)
		elif String(a["kind"]) == "tap":
			f["line"] = (a["spot"] as Vector2) - Vector2(0.0, 60.0)
	return f


## Is a still about to begin - within [constant AWAY_LEAD]?
func _still_soon() -> bool:
	for s in _spans:
		var sp: Dictionary = s
		if String(sp["kind"]) == "still":
			var w := _window(sp)
			if w.x < INF and _now < w.x and _now > w.x - AWAY_LEAD:
				return true
	return false


## The camera's springs: the tablet's slow ones ([constant LETTER_TAU]), quick through a still and the
## run-up to it.
func _spring_tau() -> float:
	if _still_soon() or not _span_now("still").is_empty():
		return SPRING_TAU * STILL_SPRING
	return LETTER_TAU


## The page lies blank before the first thing is written ([constant LetterScript.BLANK_PAGE]).
func _blank() -> float:
	return LetterScript.BLANK_PAGE


## The time the camera's wander is read at: frozen through a still, where it began.
func _wander_time() -> float:
	return _still_from if _still_from >= 0.0 else _now


## The box of the last drawing begun on the page up now (px), a box of negative size for none.
func _last_drawn() -> Rect2:
	var page := _pages().x
	var out := Rect2(Vector2.ZERO, Vector2(-1.0, -1.0))
	for i in _page_actions(page):
		var a: Dictionary = _actions[i]
		if float(_plan[i]["start"]) > _now:
			break
		if String(a["kind"]) == "draw" and a.has("at"):
			var at: Vector2 = a["at"]
			out = Rect2(at.x, at.y - float(a["h"]), float(a["w"]), float(a["h"]) + float(a["d"]))
	return out
