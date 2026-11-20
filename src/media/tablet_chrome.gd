extends RefCounted
class_name TabletChrome

## TabletChrome - a tablet's screen furniture, drawn one way for every tablet that shows the web: the tablet medium's
## ([TabletMedium]) and the dispatch desk's ([DispatchScreens]). The status bar (the time, the battery, the wifi) and, over
## a page, the browser: its tab strip, back and forward, the address bar (the host behind a padlock, the words being typed
## into it, or a redirect's whole address) and the load line; a blank tab's page, a box on a page while it is typed into,
## and the keyboard. In logical pixels; the page is drawn under it, from [constant TOP] down.

## The status bar, the tab strip and the address bar's row (logical pixels); the page begins under them.
const STATUS := 40.0
const TABS := 62.0
const BAR := 86.0
const TOP := STATUS + TABS + BAR

## The keyboard's letters, a row a string; and how much of the screen's height it takes, upright and on its side.
const KEYS := ["qwertyuiop", "asdfghjkl", "zxcvbnm"]
const KEYBOARD := 0.34
const KEYBOARD_WIDE := 0.44

static var _boxes := {}
static var _ring_box: StyleBoxFlat


## A rounded box of [param col], [param radius] px at its corners, made once.
static func box(col: Color, radius: int) -> StyleBoxFlat:
	var k := "%s|%d" % [col.to_html(), radius]
	if not _boxes.has(k):
		var b := StyleBoxFlat.new()
		b.bg_color = col
		b.set_corner_radius_all(radius)
		b.anti_aliasing = true
		_boxes[k] = b
	return _boxes[k]


## [param s] cut with an ellipsis to fit [param w] px at [param fs] in [param f].
static func fit(f: Font, s: String, fs: int, w: float) -> String:
	if f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x <= w:
		return s
	while s.length() > 1 and f.get_string_size(s + "…", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > w:
		s = s.substr(0, s.length() - 1)
	return s + "…"


## The back chevron.
static func back_at() -> Vector2:
	return Vector2(44.0, STATUS + TABS + BAR * 0.5)


## The address bar, on a screen [param L] logical pixels across.
static func bar_rect(L: Vector2) -> Rect2:
	return Rect2(150.0, STATUS + TABS + 10.0, L.x - 300.0, BAR - 20.0)


## The new tab's plus.
static func plus_rect(L: Vector2) -> Rect2:
	return Rect2(L.x - 74.0, STATUS + 9.0, 46.0, 46.0)


## The status bar on a screen [param L] across: the time [param minutes] into the day, the battery at [param level] percent
## (its fill draining smoothly, its number a percent at a time) and the wifi; dark ink over a light app ([param light]).
static func draw_status(ci: CanvasItem, L: Vector2, light: bool, minutes: int, level: float) -> void:
	var col := Color(0.1, 0.1, 0.12) if light else Color.WHITE
	var f := TabletPage.face(false, 2)
	ci.draw_string(f, Vector2(34.0, 30.0), "%d:%02d" % [(minutes / 60) % 24, minutes % 60],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 24, col)
	var pct := int(ceil(level))
	var bx := Rect2(L.x - 74.0, 12.0, 44.0, 20.0)
	ci.draw_rect(bx, Color(col, 0.9), false, 2.0)
	ci.draw_rect(Rect2(bx.end.x + 1.0, 18.0, 3.0, 8.0), col)
	ci.draw_rect(Rect2(bx.position + Vector2(3, 3), Vector2((bx.size.x - 6.0) * level / 100.0, bx.size.y - 6.0)), col)
	ci.draw_string(f, Vector2(L.x - 210.0, 30.0), "%d%%" % pct, HORIZONTAL_ALIGNMENT_RIGHT, 120, 22, col)
	# wifi
	var wc := Vector2(L.x - 290.0, 30.0)
	for k in 3:
		ci.draw_arc(wc, 6.0 + k * 7.0, -PI * 0.75, -PI * 0.25, 10, col, 3.0, true)


## The browser's chrome over the page on a screen [param L] across, as [param st] has it: `{tabs: [titles], tab (the active
## one), can_back, url (what the bar shows), editing (the bar being typed into), typed, hop (a redirect's address passed
## through, "" for none), load (0-1, -1 for none), now (the cursor's blink)}`.
static func draw_browser(ci: CanvasItem, L: Vector2, st: Dictionary) -> void:
	var chrome := Color(0.95, 0.95, 0.96)
	var ink := Color(0.12, 0.12, 0.14)
	ci.draw_rect(Rect2(0.0, 0.0, L.x, TOP), chrome)
	ci.draw_line(Vector2(0.0, TOP), Vector2(L.x, TOP), Color(0, 0, 0, 0.12), 2.0)
	var tabs: Array = st.get("tabs", [])
	var n := maxi(1, tabs.size())
	var tw := minf(330.0, (L.x - 140.0) / n)
	var f := TabletPage.face(false, 0)
	for i in tabs.size():
		var r := Rect2(24.0 + i * (tw + 8.0), STATUS + 8.0, tw, TABS - 10.0)
		var active := i == int(st.get("tab", 0))
		ci.draw_style_box(box(Color.WHITE if active else Color(0.88, 0.88, 0.9), 14), r)
		ci.draw_string(f, r.position + Vector2(20.0, 33.0), fit(f, String(tabs[i]), 20, r.size.x - 40.0),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(ink, 0.9 if active else 0.55))
	var pr := plus_rect(L)
	ci.draw_line(pr.get_center() - Vector2(13, 0), pr.get_center() + Vector2(13, 0), ink, 3.0, true)
	ci.draw_line(pr.get_center() - Vector2(0, 13), pr.get_center() + Vector2(0, 13), ink, 3.0, true)
	# back / forward: back is live when there is somewhere to go back to
	var by := STATUS + TABS + BAR * 0.5
	var can_back := bool(st.get("can_back", false))
	for k in 2:
		var x := 44.0 + k * 52.0
		var d := -1.0 if k == 0 else 1.0
		var live := k == 0 and can_back
		ci.draw_polyline(PackedVector2Array([Vector2(x - 8.0 * d, by - 14.0), Vector2(x + 8.0 * d, by),
			Vector2(x - 8.0 * d, by + 14.0)]), Color(ink, 0.8 if live else 0.25), 4.0, true)
	var br := bar_rect(L)
	var editing := bool(st.get("editing", false))
	var hop := String(st.get("hop", ""))
	ci.draw_style_box(box(Color(0.87, 0.87, 0.89) if not editing else Color.WHITE, 18), br)
	if editing:
		ci.draw_rect(br, Color(0.25, 0.5, 1.0, 0.7), false, 3.0)
		var typed := String(st.get("typed", ""))
		var tx := br.position + Vector2(26.0, 44.0)
		ci.draw_string(f, tx, typed, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, ink)
		if fmod(float(st.get("now", 0.0)), 1.0) < 0.6:
			var cx := tx.x + f.get_string_size(typed, HORIZONTAL_ALIGNMENT_LEFT, -1, 28).x + 3.0
			ci.draw_line(Vector2(cx, br.position.y + 16.0), Vector2(cx, br.end.y - 16.0), Color(0.25, 0.5, 1.0), 3.0)
	elif not hop.is_empty():
		# the whole address, and no padlock: these are not places anyone chose to go
		var hu := fit(f, hop, 26, br.size.x - 60.0)
		ci.draw_string(f, Vector2(br.position.x, by + 10.0), hu, HORIZONTAL_ALIGNMENT_CENTER, br.size.x, 26,
			Color(ink, 0.75))
	else:
		var url := String(st.get("url", ""))
		if not url.is_empty():
			var w := f.get_string_size(url, HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x
			var x := br.get_center().x - w * 0.5
			# a padlock
			ci.draw_rect(Rect2(x - 34.0, by - 4.0, 18.0, 15.0), Color(ink, 0.6))
			ci.draw_arc(Vector2(x - 25.0, by - 4.0), 6.0, PI, TAU, 12, Color(ink, 0.6), 2.5, true)
			ci.draw_string(f, Vector2(x, by + 10.0), url, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, ink)
	var ld := float(st.get("load", -1.0))
	if ld >= 0.0:
		ci.draw_rect(Rect2(0.0, TOP - 4.0, L.x * (1.0 - pow(1.0 - ld, 2.0)), 4.0), Color(0.2, 0.48, 1.0))


## A blank tab's page on a screen [param L] across: a row of favorites, their colors and names made up from [param seed].
static func draw_start(ci: CanvasItem, L: Vector2, seed: int) -> void:
	ci.draw_rect(Rect2(0.0, TOP, L.x, L.y - TOP), Color(0.97, 0.97, 0.98))
	var f := TabletPage.face(false, 2)
	ci.draw_string(f, Vector2(70.0, TOP + 90.0), "Favorites", HORIZONTAL_ALIGNMENT_LEFT, -1, 34,
		Color(0.12, 0.12, 0.14))
	var cols := 6 if L.x < L.y else 8
	var s := 110.0
	var gap := (L.x - 140.0 - cols * s) / float(cols - 1)
	for i in cols * 2:
		var r := Rect2(70.0 + (i % cols) * (s + gap), TOP + 140.0 + (i / cols) * (s + 80.0), s, s)
		var hue := float(hash([seed, "fav%d" % i]) & 0xFFFF) / 65535.0
		ci.draw_style_box(box(Color.from_hsv(hue, 0.35, 0.92), 22), r)
		TabletPage.squiggle(ci, Vector2(r.position.x + 14.0, r.end.y + 30.0), s - 28.0, 6.0,
			Color(0.5, 0.5, 0.55), hash([seed, "fv", i]))


## A box on a page while it is typed into - [param r] where it is on the screen, [param typed] what it holds so far, set
## [param inset] in from its left (past its magnifying glass): ringed, as a field under a finger is.
static func draw_typed(ci: CanvasItem, r: Rect2, typed: String, inset := 74.0) -> void:
	if _ring_box == null:
		_ring_box = StyleBoxFlat.new()
		_ring_box.draw_center = false
		_ring_box.border_color = Color(0.25, 0.5, 1.0)
		_ring_box.set_border_width_all(3)
		_ring_box.anti_aliasing = true
	_ring_box.set_corner_radius_all(int(r.size.y * 0.5))
	ci.draw_rect(Rect2(r.position + Vector2(inset - 10.0, 6.0), Vector2(r.size.x - inset - 20.0, r.size.y - 12.0)), Color.WHITE)
	ci.draw_style_box(_ring_box, r)
	ci.draw_string(TabletPage.face(false, 0), Vector2(r.position.x + inset, r.get_center().y + 11.0), typed,
		HORIZONTAL_ALIGNMENT_LEFT, r.size.x - inset - 26.0, 30, Color(0.12, 0.12, 0.14))


## Key [param col] of [param n] in row [param row] of a keyboard whose top is at [param top] on a screen [param L] across.
static func key_rect(L: Vector2, top: float, row: int, col: int, n: int) -> Rect2:
	var kw := L.x / 10.8
	var kh := (L.y - top - 30.0) / 4.0
	var x0 := (L.x - n * kw) * 0.5
	return Rect2(x0 + col * kw + 5.0, top + 14.0 + row * kh + 5.0, kw - 10.0, kh - 10.0)


## The keyboard risen [param up] (0-1) from the foot of a screen [param L] across: its letters, the space bar, the period
## and "go"; the key [param key] under the finger darkened, a letter's with its pop-up, while [param press] is above 0.
static func draw_keyboard(ci: CanvasItem, L: Vector2, up: float, key: String, press: float) -> void:
	if up <= 0.0:
		return
	var h := L.y * (KEYBOARD if L.x < L.y else KEYBOARD_WIDE)
	var top := L.y - h * up
	ci.draw_rect(Rect2(0.0, top, L.x, h), Color(0.8, 0.81, 0.84))
	var f := TabletPage.face(false, 0)
	var down_key := key.to_lower()
	var ink := Color(0.1, 0.1, 0.12)
	for row in 3:
		var keys: String = KEYS[row]
		for col in keys.length():
			var r := key_rect(L, top, row, col, keys.length())
			var down := down_key == keys[col] and press > 0.0
			ci.draw_style_box(box(Color(0.62, 0.64, 0.68) if down else Color.WHITE, 10), r)
			ci.draw_string(f, r.position + Vector2(0.0, r.size.y * 0.66), keys[col], HORIZONTAL_ALIGNMENT_CENTER,
				r.size.x, 30, ink)
			if down:
				# the pop-up a key shows under the finger
				var pop := Rect2(r.position - Vector2(10.0, r.size.y * 1.3), r.size + Vector2(20.0, r.size.y * 0.3))
				ci.draw_style_box(box(Color.WHITE, 14), pop)
				ci.draw_string(f, pop.position + Vector2(0.0, pop.size.y * 0.7), keys[col],
					HORIZONTAL_ALIGNMENT_CENTER, pop.size.x, 44, ink)
	var space := key_rect(L, top, 3, 2, 10)
	space.size.x = space.size.x * 5.0 + 40.0
	ci.draw_style_box(box(Color(0.62, 0.64, 0.68) if down_key == " " and press > 0.0 else Color.WHITE, 10), space)
	var go := key_rect(L, top, 3, 8, 10)
	go.size.x = go.size.x * 2.0 + 10.0
	ci.draw_style_box(box(Color(0.15, 0.4, 0.95) if down_key == "\n" and press > 0.0 else Color(0.25, 0.5, 1.0), 10), go)
	ci.draw_string(f, go.position + Vector2(0.0, go.size.y * 0.66), "go", HORIZONTAL_ALIGNMENT_CENTER,
		go.size.x, 28, Color.WHITE)
	var dot := key_rect(L, top, 3, 7, 10)
	ci.draw_style_box(box(Color(0.62, 0.64, 0.68) if down_key == "." and press > 0.0 else Color.WHITE, 10), dot)
	ci.draw_string(f, dot.position + Vector2(0.0, dot.size.y * 0.66), ".", HORIZONTAL_ALIGNMENT_CENTER,
		dot.size.x, 30, ink)
	for c in 2:
		ci.draw_style_box(box(Color(0.68, 0.7, 0.74), 10), key_rect(L, top, 3, c, 10))
