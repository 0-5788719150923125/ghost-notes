extends RefCounted
class_name StickerBook

## StickerBook - the night's book as a sticker book (next/sticker_book.md): each page a still ACTION SHOT - a painted SET, seen from
## one of its ANGLES, with the cast's POSES and the story's THINGS laid on it ([StickerPoses]) - as a comic or a manga cuts from
## panel to panel. A page CUTS to the next: nobody slides, bounces or breathes, and a pose is simply the next drawing; only a page
## that asks for it (`glide`) has the camera move to it across the same backdrop. A page is pushed in slowly while it is up, and its
## effects mark its moment. A pure function of show time and when each page came up ([method pose_at]): a render, a scrub and a live
## reading see the same page.
##
## THE SET IS A STAGE SEEN FROM THE FRONT ROW: its height is one unit, its eye level [constant HORIZON] down it, and a figure stands
## with its feet on the floor at a depth - at the middle depth its feet [constant FEET] down and a person of [constant PERSON_CM]
## [constant PERSON] tall, nearer lower and bigger, farther higher and smaller, so a row too wide for the frame steps back. The cast
## stands left to right as the page lists it, round where on the set the page is (`where`, else where the last page on the set was).
## A wide page frames everyone in it; a close one frames who or what it is close on - and a character in a close pose (a face) is its
## head and shoulders over the frame's bottom, the set behind them.
##
## Drawn in a viewport of its own ([member viewport]) the size of the show's frame, whose picture [TableGame] lays over the table as
## a painted page is laid. Built on the worker that builds the table ([method build]): its pictures read there, its nodes made off the
## tree, every page laid out once.

## The set as a stage: eye level and the middle depth's floor (shares of its height from the top); how tall a person of PERSON_CM
## stands there; how much bigger near and smaller far; the room between two of a row (set heights, at the middle depth).
const HORIZON := 0.42
const FEET := 0.93
const PERSON := 0.56
const PERSON_CM := 175.0
const NEAR := 1.35
const FAR := 0.62
const GAP := 0.05
## A row is at most this much of the widest frame the set allows: wider, its people overlap, each at most [constant OVERLAP] of the
## narrower of two neighbors, and only then does it step back.
const ROW_MOST := 0.86
const OVERLAP := 0.3
## Where on the set each `where` is, as a share of its width.
const WHERE_AT := {"left": 0.25, "middle": 0.5, "right": 0.75}
## A wide page's frame: the tightest it frames (set heights), and the room it leaves above the heads, at the sides and below the feet
## (shares of what it frames).
const FRAME_LEAST := 0.46
const HEAD_ROOM := 0.14
const SIDE_ROOM := 0.12
const FOOT_ROOM := 0.05
## A close page: on a whole body, the frame's height as a share of their standing height (head to waist); on a thing, how much more
## than the thing; behind a face, how much of their standing height the set is framed on. A face fills this much of the frame's
## height, bottom-aligned, and leans this far off the middle toward where they stand.
const CLOSE_BODY := 0.55
const CLOSE_THING := 1.7
const CLOSE_BEHIND := 0.8
const FACE_TALL := 0.9
const FACE_LEAN := 0.14
## The slow push while a page is up: how far in it ends (a share of its frame) and how quickly it gets there (seconds to most of it).
const PUSH := 0.04
const PUSH_TAKES := 7.0
## A page that glides to its framing (its `glide` effect) on the backdrop the page before stood on: how long the move takes (seconds).
const GLIDE := 0.6
## A drawing wider than this share of its height is framed whole when the camera is close on it (a creature on four legs, its head to
## one side), never by the top of it.
const CLOSE_WIDE := 0.9
## The effects: how dark the set goes, each tint, the lines rushing in (how many, from how far in, as shares of the frame's diagonal,
## re-drawn how often a second), the burst's size (a share of the frame's height), the shake (a share of the frame's height), the
## explosion's puffs.
const DARK := Color(0.22, 0.22, 0.27)
const TINTS := {"red": Color(1.0, 0.5, 0.45), "blue": Color(0.55, 0.68, 1.0), "gold": Color(1.0, 0.86, 0.5)}
const LINES := 84
const LINES_FROM := 0.28
const LINES_RATE := 12.0
const BURST := 0.34
const SHAKE := 0.022
const PUFFS := 11
const INK := Color(0.07, 0.06, 0.05)
## The frame's longer side in pixels.
const LONG_SIDE := 1920

var book := {}
var dir := ""
var aspect := 16.0 / 9.0
var viewport: SubViewport

var _backdrops := {}             # "K" (a set, 0 up, from its first angle) or "K:angle" -> {tex, size: Vector2, aspect}
var _stickers := {}              # "model:K", "pose:K", "thing:K" -> {tex, used: Rect2, size: Vector2}
var _layouts: Array = []         # per page: [method _lay_out]
var _base: Node2D
var _new: _Layer
var _face: Sprite2D              # a close page's face, in the frame's pixels
var _front: _Front
var _tint: CanvasModulate
var _flash: ColorRect


func _init(game: Dictionary, folder: String, frame_aspect: float) -> void:
	book = game
	dir = folder
	aspect = maxf(frame_aspect, 0.1)


## Whether [param game] tells its story in sticker pages.
static func composed(game: Dictionary) -> bool:
	return not (game.get("sets", []) as Array).is_empty()


# --- building ------------------------------------------------------------------------------------------------------------------------

## Its pictures read and every page laid out, its viewport and nodes made - on the worker that builds the table, off the tree.
func build() -> void:
	for i in (book.get("sets", []) as Array).size():
		_backdrops[str(i)] = _backdrop("set_%d.png" % (i + 1))
	var angles: Array = book.get("angles", [])
	for i in angles.size():
		var a: Dictionary = angles[i]
		var k := _set_index(String(a.get("set", "")))
		var b := _backdrop("angle_%d.png" % (i + 1))
		if b["tex"] != null:
			_backdrops["%d:%s" % [k, String(a.get("angle", ""))]] = b
	for kind in ["model", "pose", "thing"]:
		var list: Array = book.get({"model": "cast", "pose": "poses", "thing": "things"}[kind], [])
		for i in list.size():
			var img := _image("%s_%d.png" % [kind, i + 1])
			if img == null:
				continue
			var used := Rect2(img.get_used_rect())
			if used.size.y < 2.0:
				continue
			_stickers["%s:%d" % [kind, i + 1]] = {"tex": ImageTexture.create_from_image(img), "used": used, "size": Vector2(img.get_size())}
	var before := {}
	for p in book.get("pages", []):
		var l := _lay_out(p if p is Dictionary else {}, before)
		_layouts.append(l)
		before[String(l["backdrop"])] = l
	_make_nodes()


func _image(file: String) -> Image:
	var path := dir.path_join(file)
	if dir.is_empty() or not FileAccess.file_exists(path):
		return null
	var img := Image.load_from_file(path)
	if img == null or img.is_empty():
		return null
	img.generate_mipmaps()
	return img


func _read(file: String) -> ImageTexture:
	var img := _image(file)
	return ImageTexture.create_from_image(img) if img != null else null


## A backdrop's picture and size, read from [param file] (`{tex: null}` and a 3:2 size where it is not painted yet).
func _backdrop(file: String) -> Dictionary:
	var tex := _read(file)
	var size := Vector2(tex.get_width(), tex.get_height()) if tex != null else Vector2(1536, 1024)
	return {"tex": tex, "size": size, "aspect": size.x / maxf(size.y, 1.0)}


func _make_nodes() -> void:
	viewport = SubViewport.new()
	viewport.name = "StickerBook"
	viewport.disable_3d = true
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	viewport.size = pixels()
	_tint = CanvasModulate.new()
	viewport.add_child(_tint)
	var back := ColorRect.new()
	back.color = Color(0.05, 0.045, 0.04)
	back.size = Vector2(viewport.size)
	viewport.add_child(back)
	_base = Node2D.new()
	viewport.add_child(_base)
	_new = _Layer.new()
	_base.add_child(_new)
	_face = Sprite2D.new()
	_face.centered = false
	_face.visible = false
	_base.add_child(_face)
	_front = _Front.new()
	_base.add_child(_front)
	_flash = ColorRect.new()
	_flash.color = Color(1, 1, 1, 0)
	_flash.size = Vector2(viewport.size)
	viewport.add_child(_flash)


## The frame's size in pixels, its longer side [constant LONG_SIDE].
func pixels() -> Vector2i:
	return Vector2i(LONG_SIDE, roundi(LONG_SIDE / aspect)) if aspect >= 1.0 else Vector2i(roundi(LONG_SIDE * aspect), LONG_SIDE)


## Its viewport drawn only while a page shows: [param on].
func show(on: bool) -> void:
	if viewport != null:
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if on else SubViewport.UPDATE_DISABLED


# --- laying a page out ----------------------------------------------------------------------------------------------------------------

## Page [param p] laid out on its set, [param before] the last page laid on each set (set index -> its layout): `{set, frame (Rect2,
## set units), members: [{key, sticker, rect, flip, face}] left to right, center, subject (set units), close, face, fx}`. A pure
## function of the page, the stickers' sizes and the page before it on its set.
func _lay_out(p: Dictionary, before: Dictionary) -> Dictionary:
	var k := _set_index(String(p.get("set", "")))
	var key := "%d:%s" % [k, String(p.get("angle", ""))]
	if not _backdrops.has(key):
		key = str(k)
	var wide := float((_backdrops.get(key, {"aspect": 1.5}) as Dictionary)["aspect"])
	var fx: Array = p.get("fx", []) if p.get("fx") is Array else []
	var out := {"set": k, "backdrop": key, "members": [], "fx": fx, "close": String(p.get("close", "")), "face": ""}
	# ...the widest a frame can be on this set at its full height, and so the widest row
	var most_w := minf(wide, aspect)
	var raw: Array = p.get("cast", []) if p.get("cast") is Array else []
	var members: Array = []
	for c in raw:
		var m := _member(c as Dictionary)
		if not m.is_empty():
			members.append(m)
	# ...the row at the middle depth: where it is too wide for any frame its people stand closer, overlapping, and only then does it
	# step back as a whole
	var row_w := 0.0
	var tight := 0.0
	for j in members.size():
		row_w += float(members[j]["w"])
		if j > 0:
			tight += OVERLAP * minf(float(members[j]["w"]), float(members[j - 1]["w"]))
	var gaps := float(maxi(members.size() - 1, 0))
	var room := ROW_MOST * most_w
	var gap := GAP
	if row_w + GAP * gaps > room and gaps > 0.0:
		gap = maxf(GAP - (row_w + GAP * gaps - room) / gaps, -tight / gaps)
	row_w += gap * gaps
	var back := minf(1.0, room / maxf(row_w, 0.001))
	row_w *= back
	var where := String(p.get("where", ""))
	var center := wide * 0.5
	if WHERE_AT.has(where):
		center = wide * float(WHERE_AT[where])
	elif before.has(key):
		center = float((before[key] as Dictionary)["center"])
	center = clampf(center, minf(row_w * 0.5, wide * 0.5), maxf(wide - row_w * 0.5, wide * 0.5))
	out["center"] = center
	var x := center - row_w * 0.5
	var mid_i := (float(members.size()) - 1.0) * 0.5
	for j in members.size():
		var m: Dictionary = members[j]
		var s := back * float(m["depth"])
		var feet := HORIZON + (FEET - HORIZON) * s
		var h := float(m["h"]) * back
		var w := float(m["w"]) * back
		var rect := Rect2(x, feet - h, w, h)
		x += w + gap * back
		var facing := String(m.get("facing", ""))
		if facing.is_empty():
			if members.size() == 1:
				facing = "right" if rect.get_center().x <= wide * 0.5 else "left"
			else:
				facing = "right" if float(j) <= mid_i else "left"
		(out["members"] as Array).append({"key": m["key"], "sticker": m["sticker"], "rect": rect, "stand": float(m["stand"]) * back,
			"flip": facing == "left" and bool(m["turned"]), "face": bool(m["face"]), "thing": bool(m["thing"])})
	out["frame"] = _frame_of(out, wide)
	return out


## One of a page's cast made ready to lay: `{key, sticker, w, h (its drawing, set units, at the middle depth), stand (its standing
## height), depth, turned, face, thing, facing}`, {} where it has no drawing.
func _member(c: Dictionary) -> Dictionary:
	var thing := c.has("thing")
	var name := String(c.get("thing" if thing else "who", ""))
	var list_key := "things" if thing else "cast"
	var i := _index(book.get(list_key, []), name)
	if i < 0:
		return {}
	var entry: Dictionary = (book[list_key] as Array)[i]
	var pose := String(c.get("pose", "stand"))
	var sticker := "thing:%d" % (i + 1) if thing else _pose_sticker(name, pose, i)
	if not _stickers.has(sticker):
		return {}
	var used: Rect2 = (_stickers[sticker] as Dictionary)["used"]
	var depth := NEAR if String(c.get("depth", "")) == "near" else (FAR if String(c.get("depth", "")) == "far" else 1.0)
	var stand := PERSON * float(entry.get("height", PERSON_CM)) / PERSON_CM * depth
	var h := stand * (1.0 if thing else StickerPoses.tall(pose))
	var face := not thing and StickerPoses.close(pose)
	return {"key": ("thing:" if thing else "who:") + name.to_lower(), "sticker": sticker, "h": h, "w": h * used.size.x / maxf(used.size.y, 1.0),
		"stand": stand, "depth": depth, "turned": not thing and StickerPoses.turned(pose), "face": face, "thing": thing,
		"facing": String(c.get("facing", ""))}


## The sticker of [param name]'s [param pose] (character [param i], 0 up): its own drawing, else its model where the pose is not drawn.
func _pose_sticker(name: String, pose: String, i: int) -> String:
	if pose != "stand":
		var poses: Array = book.get("poses", [])
		for q in poses.size():
			var d: Dictionary = poses[q]
			if String(d.get("who", "")).to_lower() == name.to_lower() and String(d.get("pose", "")) == pose and _stickers.has("pose:%d" % (q + 1)):
				return "pose:%d" % (q + 1)
	return "model:%d" % (i + 1)


## The frame a laid-out page [param l] is seen in (set units), on a set [param wide] wide: everyone in it, or who or what it is close on.
func _frame_of(l: Dictionary, wide: float) -> Rect2:
	var members: Array = l["members"]
	var tallest := minf(1.0, wide / aspect)
	var close := String(l["close"]).to_lower()
	var subject := Vector2(float(l["center"]), HORIZON)
	var frame := Rect2()
	var on: Dictionary = {}
	for m in members:
		if String((m as Dictionary)["key"]).get_slice(":", 1) == close and not close.is_empty():
			on = m
	if not on.is_empty():
		var r: Rect2 = on["rect"]
		var stand := float(on["stand"])
		if bool(on["face"]):
			# ...the set behind a face, framed where they stand; the face itself laid over the frame ([method _pose_face])
			var hh := minf(stand * CLOSE_BEHIND, tallest)
			frame = Rect2(r.get_center().x - hh * aspect * 0.5, r.end.y - stand - hh * 0.1, hh * aspect, hh)
			l["face"] = String(on["key"])
			subject = Vector2(r.get_center().x, r.end.y - stand * 0.85)
		elif bool(on["thing"]) or r.size.x > r.size.y * CLOSE_WIDE:
			# ...a thing, or a creature wider than it is tall, framed whole: its head may be at either end
			var hh := clampf(r.size.y * CLOSE_THING, 0.08, tallest)
			hh = maxf(hh, r.size.x * CLOSE_THING / aspect)
			frame = Rect2(r.get_center().x - hh * aspect * 0.5, r.get_center().y - hh * 0.5, hh * aspect, hh)
			subject = r.get_center()
		else:
			var hh := minf(stand * CLOSE_BODY, tallest)
			frame = Rect2(r.get_center().x - hh * aspect * 0.5, r.position.y - hh * 0.08, hh * aspect, hh)
			subject = Vector2(r.get_center().x, r.position.y + stand * 0.12)
	else:
		var box := Rect2()
		var any := false
		for m in members:
			var r: Rect2 = (m as Dictionary)["rect"]
			# ...what is seen of them: never below the set's bottom
			var seen := Rect2(r.position, Vector2(r.size.x, minf(r.end.y, 1.0) - r.position.y))
			box = seen if not any else box.merge(seen)
			any = true
		if not any:
			var hh := tallest
			frame = Rect2(float(l["center"]) - hh * aspect * 0.5, 1.0 - hh, hh * aspect, hh)
		else:
			var grown := Rect2(box.position.x - box.size.x * SIDE_ROOM, box.position.y - box.size.y * HEAD_ROOM,
				box.size.x * (1.0 + 2.0 * SIDE_ROOM), box.size.y * (1.0 + HEAD_ROOM + FOOT_ROOM))
			var hh := clampf(maxf(grown.size.y, grown.size.x / aspect), minf(FRAME_LEAST, tallest), tallest)
			var c := grown.get_center()
			frame = Rect2(c.x - hh * aspect * 0.5, c.y - hh * 0.5, hh * aspect, hh)
			var first: Rect2 = (members[0] as Dictionary)["rect"]
			subject = Vector2(first.get_center().x, first.position.y + first.size.y * 0.15)
	l["subject"] = subject
	return _inside(frame, wide)


## [param f] moved (and made no bigger than the set allows) so it lies wholly on a set [param wide] wide.
func _inside(f: Rect2, wide: float) -> Rect2:
	var h := minf(f.size.y, minf(1.0, wide / aspect))
	var c := f.get_center()
	var out := Rect2(c.x - h * aspect * 0.5, c.y - h * 0.5, h * aspect, h)
	out.position.x = clampf(out.position.x, 0.0, maxf(wide - out.size.x, 0.0))
	out.position.y = clampf(out.position.y, 0.0, maxf(1.0 - out.size.y, 0.0))
	return out


func _set_index(name: String) -> int:
	return maxi(_index(book.get("sets", []), name), 0)


static func _index(list: Variant, name: String) -> int:
	if not (list is Array):
		return -1
	for i in (list as Array).size():
		if (list[i] is Dictionary) and String((list[i] as Dictionary).get("name", "")).to_lower() == name.to_lower():
			return i
	return -1


## Page [param i]'s layout (0 up), {} for none.
func layout(i: int) -> Dictionary:
	return _layouts[i] if i >= 0 and i < _layouts.size() else {}


# --- the page at a moment -----------------------------------------------------------------------------------------------------------------

## The book at show time [param t]: page [param i] (0 up) up since [param at], come straight after page [param p] (-1 where the book
## came up from the table) which was up since [param p_at]. Every node is set from these alone.
func pose_at(t: float, i: int, at: float, p: int, p_at: float) -> void:
	var l := layout(i)
	if l.is_empty() or viewport == null:
		return
	var px := Vector2(viewport.size)
	var since := t - at
	var fx: Array = l["fx"]
	var prev := layout(p)
	var frame := pushed(l, since)
	# ...a cut, unless the page glides to its framing across the backdrop the page before stood on
	if fx.has("glide") and not prev.is_empty() and String(prev["backdrop"]) == String(l["backdrop"]) and since < GLIDE:
		frame = _lerp_rect(pushed(prev, at - p_at), frame, _ease(since / GLIDE))
	_new.lay(self, l, frame, px, since, t)
	_pose_face(l, frame, px)
	_pose_fx(l, frame, px, since, t)


## Page layout [param l]'s frame [param since] seconds after it came up: pushed in toward its subject, unless it is held still.
func pushed(l: Dictionary, since: float) -> Rect2:
	var f: Rect2 = l["frame"]
	if (l["fx"] as Array).has("still"):
		return f
	var u := PUSH * (1.0 - exp(-maxf(since, 0.0) / PUSH_TAKES * 2.0))
	var s: Vector2 = l["subject"]
	var toward := Vector2(clampf(s.x, f.position.x, f.end.x), clampf(s.y, f.position.y, f.end.y))
	return Rect2(f.position + (toward - f.position) * u, f.size * (1.0 - u))


## The face over the frame, where a page is close on a character in a close pose.
func _pose_face(l: Dictionary, frame: Rect2, px: Vector2) -> void:
	_face.visible = false
	var now := String(l.get("face", ""))
	if not now.is_empty():
		_lay_face(_face, l, now, frame, px)


func _lay_face(s: Sprite2D, l: Dictionary, key: String, frame: Rect2, px: Vector2) -> void:
	var m := {}
	for d in l["members"]:
		if String((d as Dictionary)["key"]) == key:
			m = d
	if m.is_empty() or not _stickers.has(String(m["sticker"])):
		return
	var st: Dictionary = _stickers[String(m["sticker"])]
	var used: Rect2 = st["used"]
	var k := FACE_TALL * px.y / maxf(used.size.y, 1.0)
	var r: Rect2 = m["rect"]
	var lean := clampf((r.get_center().x - frame.get_center().x) / maxf(frame.size.x, 0.001), -FACE_LEAN, FACE_LEAN)
	var cx := px.x * (0.5 + lean)
	s.texture = st["tex"]
	s.flip_h = bool(m["flip"])
	s.scale = Vector2(k, k)
	var ux := (Vector2(st["size"]).x - used.end.x) if s.flip_h else used.position.x
	s.position = Vector2(cx - used.size.x * k * 0.5 - ux * k, px.y - used.end.y * k)
	s.visible = true


## The effects of layout [param l], [param since] seconds into it: the shake, the tint, the flash, and what is drawn over the frame.
func _pose_fx(l: Dictionary, frame: Rect2, px: Vector2, since: float, t: float) -> void:
	var fx: Array = l["fx"]
	var shake := Vector2.ZERO
	var lasts := float(Registry.field(StickerPoses.EFFECTS, "shake", "lasts", 0.5))
	if (fx.has("shake") or fx.has("boom")) and since < lasts * (1.8 if fx.has("boom") else 1.0):
		var decay := 1.0 - since / (lasts * (1.8 if fx.has("boom") else 1.0))
		shake = Vector2(sin(since * 61.0) + sin(since * 37.0) * 0.5, cos(since * 53.0) + sin(since * 29.0) * 0.5) * SHAKE * px.y * decay * decay
	_base.position = shake
	var tint := Color.WHITE
	for k in TINTS:
		if fx.has(k):
			tint = tint * (TINTS[k] as Color)
	_tint.color = tint
	var flash := 0.0
	for k in ["flash", "boom"]:
		var d := float(Registry.field(StickerPoses.EFFECTS, k, "lasts", 0.3))
		if fx.has(k) and since < d:
			flash = maxf(flash, 1.0 - since / d)
	_flash.color = Color(1, 1, 1, flash * flash)
	var s: Vector2 = l["subject"]
	var at := (s - frame.position) / frame.size * px
	_front.set_moment(fx, at, px, since, t)


# --- helpers -----------------------------------------------------------------------------------------------------------------------------

## A sticker's texture and where its drawing is in it.
func sticker(key: String) -> Dictionary:
	return _stickers.get(key, {})


## Backdrop [param key]'s picture (null where it is not painted yet) and its size in pixels.
func backdrop_texture(key: String) -> ImageTexture:
	return (_backdrops.get(key, {}) as Dictionary).get("tex")


func backdrop_size(key: String) -> Vector2:
	return (_backdrops.get(key, {}) as Dictionary).get("size", Vector2(1536, 1024))


static func _ease(x: float) -> float:
	var u := clampf(x, 0.0, 1.0)
	return u * u * u * (u * (u * 6.0 - 15.0) + 10.0)


static func _lerp_rect(a: Rect2, b: Rect2, u: float) -> Rect2:
	return Rect2(a.position.lerp(b.position, u), a.size.lerp(b.size, u))


## One page's scene in the frame: its set and its cast, seen through its frame.
class _Layer extends Node2D:
	var _set: Sprite2D
	var _back: _Behind
	var _members := {}             # key -> Sprite2D, made as first wanted

	func _init() -> void:
		_set = Sprite2D.new()
		_set.centered = false
		add_child(_set)
		_back = _Behind.new()
		add_child(_back)

	## [param l] laid through [param frame] in [param px] pixels, [param since] seconds in: its backdrop, and each of its cast standing
	## still where the page puts them, in the pose it gives them.
	func lay(b: StickerBook, l: Dictionary, frame: Rect2, px: Vector2, since: float, t: float) -> void:
		var k := px.x / maxf(frame.size.x, 0.0001)
		transform = Transform2D(0.0, Vector2(k, k), 0.0, -frame.position * k)
		var bk := String(l["backdrop"])
		_set.texture = b.backdrop_texture(bk)
		var size := b.backdrop_size(bk)
		_set.scale = Vector2.ONE / maxf(size.y, 1.0)
		_set.modulate = StickerBook.DARK if (l["fx"] as Array).has("dark") else Color.WHITE
		var face := String(l.get("face", ""))
		var seen := {}
		for m in l["members"]:
			var d: Dictionary = m
			var key := String(d["key"])
			var s := _sprite(key)
			# ...behind a face, the one it is of is not on the set, and nobody else is either
			if not face.is_empty():
				continue
			seen[key] = true
			# ...the nearer over the farther, and where they stand alike the shorter in front, as people are stood for a picture
			var taller := 0
			for o in l["members"]:
				if float((o as Dictionary)["stand"]) > float(d["stand"]):
					taller += 1
			s.z_index = 1 + int((d["rect"] as Rect2).end.y * 100.0) * 8 + taller
			_place(s, b.sticker(String(d["sticker"])), d["rect"], bool(d["flip"]))
		for key in _members:
			if not seen.has(key):
				(_members[key] as Sprite2D).visible = false
		_back.set_moment(l, since, t)

	func _sprite(key: String) -> Sprite2D:
		if not _members.has(key):
			var s := Sprite2D.new()
			s.centered = false
			add_child(s)
			_members[key] = s
		return _members[key]

	## Sprite [param s] showing sticker [param st] (its texture and where its drawing is) with its drawing standing in [param rect],
	## turned to face left where [param flip].
	func _place(s: Sprite2D, st: Dictionary, rect: Rect2, flip: bool) -> void:
		if st.is_empty():
			s.visible = false
			return
		var used: Rect2 = st["used"]
		var k := rect.size.y / maxf(used.size.y, 1.0)
		s.texture = st["tex"]
		s.flip_h = flip
		s.scale = Vector2(k, k)
		var ux := (Vector2(st["size"]).x - used.end.x) if flip else used.position.x
		s.position = Vector2(rect.get_center().x - used.size.x * k * 0.5 - ux * k, rect.end.y - used.end.y * k)
		s.visible = true


## What is drawn on the set behind the cast: a page's burst.
class _Behind extends Node2D:
	var _on := false
	var _at := Vector2.ZERO
	var _r := 0.0
	var _spin := 0.0

	func set_moment(l: Dictionary, since: float, t: float) -> void:
		_on = (l["fx"] as Array).has("burst") and String(l.get("face", "")).is_empty()
		if _on:
			var f: Rect2 = l["frame"]
			_at = l["subject"]
			_r = f.size.y * StickerBook.BURST * (1.0 + 0.04 * sin(t * 9.0)) * minf(1.0, 0.6 + since * 4.0)
			_spin = t * 0.15
		z_index = 0
		queue_redraw()

	func _draw() -> void:
		if _on:
			StickerBook.burst(self, _at, _r, _spin, Color(1, 1, 1, 0.95), 0.0)


## What is drawn over the frame: the lines rushing in, an explosion's smoke - in the frame's pixels.
class _Front extends Node2D:
	var _fx: Array = []
	var _at := Vector2.ZERO
	var _px := Vector2.ONE
	var _since := 0.0
	var _t := 0.0

	func set_moment(fx: Array, at: Vector2, px: Vector2, since: float, t: float) -> void:
		_fx = fx
		_at = at
		_px = px
		_since = since
		_t = t
		queue_redraw()

	func _draw() -> void:
		if _fx.has("lines"):
			var diag := _px.length()
			var frame_n := int(floor(_t * StickerBook.LINES_RATE))
			var rng := RandomNumberGenerator.new()
			rng.seed = hash([frame_n, "lines"])
			for i in StickerBook.LINES:
				var a := TAU * (float(i) + rng.randf()) / float(StickerBook.LINES)
				var d := Vector2(cos(a), sin(a))
				var inner := diag * (StickerBook.LINES_FROM + rng.randf() * 0.16)
				var half := 0.006 + rng.randf() * 0.012
				var side := Vector2(-d.y, d.x)
				var tip := _at + d * inner
				var far := _at + d * diag
				draw_colored_polygon(PackedVector2Array([tip, far + side * diag * half, far - side * diag * half]), Color(StickerBook.INK, 0.85))
		if _fx.has("boom"):
			var lasts := float(Registry.field(StickerPoses.EFFECTS, "boom", "lasts", 0.9))
			var u := clampf(_since / lasts, 0.0, 1.0)
			if u < 1.0:
				var rng := RandomNumberGenerator.new()
				rng.seed = hash("boom")
				for i in StickerBook.PUFFS:
					var a := TAU * float(i) / float(StickerBook.PUFFS) + rng.randf() * 0.5
					var reach := _px.y * (0.08 + 0.3 * sqrt(u)) * (0.6 + rng.randf() * 0.6)
					var p := _at + Vector2(cos(a), sin(a) * 0.7) * reach
					var r := _px.y * (0.05 + 0.06 * u) * (0.7 + rng.randf() * 0.6)
					var fade := 1.0 - u * u
					draw_circle(p, r, Color(0.92, 0.9, 0.86, 0.9 * fade))
					draw_arc(p, r, 0.0, TAU, 28, Color(StickerBook.INK, 0.8 * fade), maxf(2.0, r * 0.06), true)
				if u < 0.5:
					StickerBook.burst(self, _at, _px.y * 0.22 * (0.5 + u), 0.0, Color(1.0, 0.96, 0.8, 1.0 - u * 2.0))


## A jagged burst on [param canvas] at [param at], [param r] across, turned [param spin], filled [param fill] and inked no thinner than
## [param least].
static func burst(canvas: CanvasItem, at: Vector2, r: float, spin: float, fill: Color, least := 1.0) -> void:
	var pts := PackedVector2Array()
	var n := 14
	for i in n * 2:
		var a := spin + TAU * float(i) / float(n * 2)
		var jag := 1.0 if i % 2 == 0 else 0.56 + 0.1 * float((i * 7) % 3) / 2.0
		pts.append(at + Vector2(cos(a), sin(a)) * r * jag)
	canvas.draw_colored_polygon(pts, fill)
	var loop := pts.duplicate()
	loop.append(pts[0])
	canvas.draw_polyline(loop, Color(INK, fill.a), maxf(least, r * 0.03), true)
