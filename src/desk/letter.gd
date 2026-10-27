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
## A LINE IS WRITTEN AS IT IS SAID: each line of the letter is a dictation of its own words, the pen as
## elastic over them as the desk's is over a formula's ([method DeskMedium.elastic]); a line's way back
## to the margin is a quick return ([constant LINE_RETURN]), as a hand's is, never the slow reach across
## a pad between two formulas.
##
## A THOUGHT IS NOT WRITTEN: while the writer thinks a passage in italics the pen is lifted, and the camera
## eases back off the line ([constant THINK_K]) - the writer sitting back.
##
## THE PEN TAPS (`<!-- tap -->`): it is lifted, turned over in the hand and its top tapped on the pad, or
## the desk beside it, a few times, then turned back - [method _tap_pose], laid over the pen's own place
## while it lasts.
##
## THE PEN POINTS AT WHOEVER WATCHES (`<!-- point: camera -->`): lifted off the page and its nib turned to
## the lens for the sentence, then put back ([method _camera_pose]).
##
## A PICTURE TAKES THE SCREEN (`<!-- image (full): -->` ... `<!-- /image -->`): it fades up over the desk
## as the passage under it begins, drifts slowly closer and across (a pan its length guessed from the
## script, never from the voice's times, so it never jumps as a live reading's words arrive) and fades back
## to the desk as the passage ends. The pen writes on under it: the page the camera comes back to has
## the passage on it.
##
## A STILL IS DEAD STILL (`<!-- still -->`: "the camera holds still on the cross and the dot, with the pen
## well clear of them, or the test cannot work"): from the mark to the next written line the camera frames
## the last drawing on the page, its slow wander stopped where it was, and the pen is sent off the pad.
##
## THE LETTER ENDS WHEN THE PEN DOES: an unspoken line after the last word ("Dear Ink," on a new page) is
## written before the camera stands back and the picture goes to black.

## The camera close on the writing - nearer than the desk's, which frames a formula: a line of cursive is
## small - and how far back it eases for a thought.
const LETTER_LOCAL := {"dist": 0.38, "pitch": 80.0}
const THINK_K := 0.75
## A line's return to the margin: as fast as a hand's (px of the page a second), and never quicker than
## [constant LetterScript.RETURN], which the voice's rests are sized by.
const LINE_RETURN := 2600.0
## A PICTURE: its fade (seconds), how much it grows from first to last, and how far it drifts across
## what is left over of it (a share of that slack), its length guessed at this many seconds a word.
const IMAGE_FADE := 1.4
const IMAGE_GROW := Vector2(1.04, 1.16)
const IMAGE_DRIFT := 0.7
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
## CAMERA_K]).
const CAMERA_RISE := 0.2
const CAMERA_OFF := 0.3
const CAMERA_EASE := 0.7
const CAMERA_HOLD := 1.0
const CAMERA_K := 0.55
## THE CAMERA GOES TO WHAT THE PEN DOES AWAY FROM THE LINE - a point, a tap - this long before it (its
## springs are slow, and close on a line it sees under half the page), framed this much wider.
const AWAY_LEAD := 3.5
const AWAY_K := 0.7
## A STILL IS STILL FROM ITS FIRST MOMENT: the camera heads for the drawing [constant AWAY_LEAD] early, on
## springs this much quicker than its own, so it has settled when the still begins (on its own it was
## still drifting 15 px three seconds in - a test the viewer does on the screen cannot be done on a
## moving one).
const STILL_SPRING := 0.3

## The plate a picture is shown on, over the desk ([method _show_picture]).
class Plate extends Node2D:
	var tex: Texture2D = null
	var alpha := 0.0
	var grow := 1.0
	var drift := Vector2.ZERO

	func _draw() -> void:
		if tex == null or alpha <= 0.0:
			return
		var view := get_viewport_rect().size
		var ts := tex.get_size()
		if ts.x <= 0.0 or ts.y <= 0.0:
			return
		var s := maxf(view.x / ts.x, view.y / ts.y) * grow
		var size := ts * s
		var slack := size - view
		var at := -slack * 0.5 + slack * 0.5 * drift
		draw_rect(Rect2(Vector2.ZERO, view), Color(0.0, 0.0, 0.0, alpha))
		draw_texture_rect(tex, Rect2(at, size), false, Color(1.0, 1.0, 1.0, alpha))


var _spans: Array = []
var _pictures := {}            # an image's key -> its texture
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
	var key := "%d|%d|%s|%s|%s" % [src.hash(), int(letter.get("seed", 0)), str(letter.get("svgs", {})).hash(),
		str(letter.get("pictures", {})).hash(), " ".join(start)]
	if key == _doc_key:
		return
	_doc_key = key
	load_letter(src, letter, start, int(d.get("start_index", -1)))


## LOAD A LETTER: [param source] (its text, its marks in it) and [param letter] (`{seed, svgs, ink,
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
	var parsed := LetterScript.parse(source, _seed, svgs, lengths, _records)
	_actions = parsed["actions"]
	_spans = parsed["spans"]
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
	var from := TabletScript.find_run(spoken, start, near) if not start.is_empty() else -1
	var est := PackedFloat32Array()
	if from > 0:
		for w in DeskScript.rehearsal(parsed):
			est.append(float((w as Dictionary)["t0"]))
	_follower.reset(spoken, from, est)
	_built_n = -1
	_held = {}
	_plan = []
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


## THE PICTURE UP NOW, on the plate over the desk ([method picture_at]).
func _show_picture() -> void:
	var p := picture_at()
	var tex: Texture2D = _pictures.get(String(p["key"])) if not String(p["key"]).is_empty() else null
	var a := float(p["alpha"]) if tex != null else 0.0
	var changed := a != _plate.alpha or tex != _plate.tex or float(p["grow"]) != _plate.grow
	_plate.alpha = a
	_plate.tex = tex
	_plate.grow = float(p["grow"])
	_plate.drift = p["drift"]
	if changed:
		_plate.queue_redraw()


## WHAT THE SCREEN SHOWS OF A PICTURE at [member _now]: `{key, alpha, grow, drift}` - the picture up (""
## for none), faded in from the end of the word before its passage and out after the passage's last
## word, grown and drifted along by how far through the passage the script says it is. Only a picture
## there is a file for is shown. Pure: a function of the voice's times.
func picture_at() -> Dictionary:
	for s in _spans:
		var sp: Dictionary = s
		if String(sp["kind"]) != "image" or not _pictures.has(String(sp["key"])):
			continue
		var from := int(sp["from"])
		var to := int(sp["to"])
		if to <= from:
			continue
		var t0 := _guess(from - 1, true) + 0.1 if from > 0 else _guess(from, false) - IMAGE_FADE
		var t1 := _guess(to - 1, true) + 0.4
		if t0 == INF or _now < t0 or _now > t1 + IMAGE_FADE:
			continue
		var a := minf(clampf((_now - t0) / IMAGE_FADE, 0.0, 1.0), 1.0 - clampf((_now - t1) / IMAGE_FADE, 0.0, 1.0))
		var u := clampf((_now - t0) / maxf(float(to - from) * DeskScript.SAID_WORD + IMAGE_FADE * 2.0, 1.0), 0.0, 1.0)
		var dir := Vector2.from_angle(TAU * _hash01(hash(sp["key"]), 91))
		return {"key": String(sp["key"]), "alpha": a * a * (3.0 - 2.0 * a),
			"grow": lerpf(IMAGE_GROW.x, IMAGE_GROW.y, u), "drift": dir * lerpf(-IMAGE_DRIFT, IMAGE_DRIFT, u)}
	return {"key": "", "alpha": 0.0, "grow": 1.0, "drift": Vector2.ZERO}


## THE CLOSE waits for the pen: down to black over the outro once the last word is said AND the last
## thing written is done.
func _end_fade() -> float:
	var last := _follower.known_last()
	if _spoken_n == 0 or last < _spoken_n - 1:
		return 1.0
	var end := _follower.st1[last]
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
	for i in _actions.size():
		var a: Dictionary = _actions[i]
		if String(a["kind"]) != "tap":
			continue
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


## THE FRAMING, as the desk's - eased back for a thought, and for a still, held on the last drawing on
## the page.
func _framing() -> Dictionary:
	var f := super._framing()
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
	if not _span_now("thought").is_empty():
		f["k"] = minf(float(f["k"]), THINK_K)
	# a point at the camera, under way or soon: stood back, so the pen held up reads as a pen
	for s in _spans:
		var sp: Dictionary = s
		if String(sp["kind"]) == "camera":
			var t0 := _guess(int(sp["after"]), false)
			var t1 := _guess(int(sp["after"]) + int(sp["span"]) - 1, true) + CAMERA_HOLD
			if t0 < INF and _now > t0 - AWAY_LEAD and _now < t1 + CAMERA_EASE:
				f["k"] = minf(float(f["k"]), CAMERA_K)
	# a point or a tap, under way or soon: framed on what it is about, a little wider
	var page := _pages().x
	for i in _actions.size():
		var a: Dictionary = _actions[i]
		var start := float(_plan[i]["start"])
		if start == INF or start > _now + AWAY_LEAD:
			break
		if float(_plan[i]["end"]) < _now or int(a["page"]) != page:
			continue
		if String(a["kind"]) == "point":
			var b := target_box(a)
			if b.size.x >= 0.0:
				f["line"] = b.get_center() - Vector2(0.0, 60.0)
				f["k"] = minf(float(f["k"]), AWAY_K)
		elif String(a["kind"]) == "tap":
			f["line"] = (a["spot"] as Vector2) - Vector2(0.0, 60.0)
			f["k"] = minf(float(f["k"]), AWAY_K)
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


## The camera's springs: quick through a still and the run-up to it.
func _spring_tau() -> float:
	if _still_soon() or not _span_now("still").is_empty():
		return SPRING_TAU * STILL_SPRING
	return SPRING_TAU


## The time the camera's wander is read at: frozen through a still, where it began.
func _wander_time() -> float:
	return _still_from if _still_from >= 0.0 else _now


## The box of the last drawing begun on the page up now (px), a box of negative size for none.
func _last_drawn() -> Rect2:
	var page := _pages().x
	var out := Rect2(Vector2.ZERO, Vector2(-1.0, -1.0))
	for i in _actions.size():
		var a: Dictionary = _actions[i]
		if float(_plan[i]["start"]) > _now:
			break
		if String(a["kind"]) == "draw" and int(a["page"]) == page and a.has("at"):
			var at: Vector2 = a["at"]
			out = Rect2(at.x, at.y - float(a["h"]), float(a["w"]), float(a["h"]) + float(a["d"]))
	return out
