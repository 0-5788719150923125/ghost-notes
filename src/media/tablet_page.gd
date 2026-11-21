extends RefCounted
class_name TabletPage

## TabletPage - one web page of a [TabletScript], set into a column of a given width.
##
## Pages are typeset, not rendered from HTML: the blocks the chapter wrote (headings, paragraphs,
## pictures, links) in a site's own face and color, and placeholders for everything it did not write,
## drawn as squiggles (wavy strokes in the shape of text). A heading with nothing under it gets a
## squiggled body, `<!-- filler: N -->` puts N placeholder stories in, and every page is padded to
## [member min_height] (so there is something to scroll) and past its last written block by TAIL_SHARE
## at least (so the last lines are not read at the screen's foot).
##
## A page with a live chat ([constant TabletScript.CHAT]) is built to the screen, never scrolled: what is written above
## it, its picture no taller than [constant LIVE_PICTURE] of the screen, then the paid messages, the stream filling what
## is left, and the message box at the foot ([method _live], [method _draw_chat]).
##
## A page set without [member placeholders] (the dispatch desk's) has no squiggles anywhere: no padding, no stub bodies,
## no placeholder stories, its menu row only where the site names one (`<!-- nav: -->`), and a footer of the site's
## name; it ends where its writing does.
##
## A forum is set as one ([method _post_begin]): each `<!-- post: -->` a card, the author's column (an avatar drawn from the
## name, the name, what the forum says of them) beside the post's body, its quotes in tinted boxes, its pictures as
## attachments; a table's columns of numbers centered, its rows banded, a cell's detail after `<br>` set smaller.
##
## The site's look is its host: face, accent color and masthead are hashed off the address, so a site
## looks the same wherever the chapter visits it. Two kinds are recognized from what the chapter does
## with them: a page searched from that has little else on it is a search engine's home (a centered
## logo and a box), and a page reached by a search is its results.

const BODY := 30
const SIZES := {1: 52, 2: 40, 3: 34}
const LEAD := 1.48            # line height over font size
const MARGIN := 56.0
const MAX_COLUMN := 1060.0    # sites have a max width; landscape centers the column

const SANS := ["Inter", "Roboto", "Helvetica Neue", "Helvetica", "Arial", "Liberation Sans",
	"DejaVu Sans"]
## Each site is set in its own type: one serif and one sans family chosen by its host from plain text
## faces most desks have some version of (no display faces, scripts or italics). Each entry is a family
## and its look-alikes, best first, so a machine without the first sets the same kind of page. Every
## family needs a real bold (headings use it). The browser's own chrome keeps [constant SANS].
const SERIF_FAMILIES := [
	["Georgia", "Gelasio", "Noto Serif"],
	["Times New Roman", "Liberation Serif", "Nimbus Roman", "Tinos"],
	["Palatino Linotype", "Palatino", "P052", "TeX Gyre Pagella"],
	["Century Schoolbook", "C059", "TeX Gyre Schola"],
	["DejaVu Serif", "Bitstream Vera Serif"],
]
const SANS_FAMILIES := [
	["Helvetica Neue", "Helvetica", "Arial", "Liberation Sans", "Nimbus Sans", "Arimo"],
	["Roboto"],
	["Inter", "Adwaita Sans"],
	["Verdana", "DejaVu Sans"],
	["Segoe UI", "Noto Sans", "Open Sans"],
]

## A live page's picture at most this share of the screen's height (cropped to it, as a player is).
const LIVE_PICTURE := 0.36
## A live chat's message: its size, its line's height, the room between messages; how long a new one takes to push the
## stream up (s); how many paid messages stand above the stream, each this tall, this far apart.
const CHAT_FS := 25
const CHAT_LINE := 34.0
const CHAT_GAP := 7.0
const CHAT_IN := 0.18
## How far down the stream fades in from under the paid messages (px), in so many bands.
const CHAT_FADE := 46.0
const CHAT_FADE_STEPS := 12
const PAID_SLOTS := 2
const PAID_H := 76.0
const PAID_GAP := 10.0
## How long a paid message takes to come in at the top, and how long a reply sent stays brighter than lit (s).
const PAID_IN := 0.45
const PAID_GLOW := 3.0
## A live picture's sound button: its size (px), drawn muted until the page is told it is heard.
const SOUND_BUTTON := 64.0

var script_doc: Dictionary
var index := -1
var width := 1200.0
var height := 0.0
var min_height := 0.0
## Placeholder stories after the last written block, at least, as a share of [member min_height]:
## about half a screen.
const TAIL_SHARE := 0.2
## Whether what nobody wrote is drawn as placeholders (squiggles, padding stories); see the class note.
var placeholders := true
## A table cell's detail (after `<br>`), a quote's words, a post's own furniture (px).
const DETAIL_FS := 24
const QUOTE_FS := 27
## A forum post: the author's column, the strip across its top, its padding, the room after it, the avatar, an
## attachment's widest and tallest.
const POST_SIDE := 230.0
const POST_HEAD := 50.0
const POST_PAD := 22.0
const POST_GAP := 26.0
const AVATAR := 112.0
const ATTACH_W := 640.0
const ATTACH_H := 520.0
var items: Array = []         # in page coordinates, in drawing order
var word_rect := {}           # global word index -> Rect2
var search_rect := Rect2()
var reply_rect := Rect2()     # the message box of a page that takes a reply (its `reply`), under its last line
var block_rect := {}          # block index -> Rect2, for the pictures a skim stops on
var bg := Color.WHITE
var ink := Color(0.1, 0.1, 0.12)
var accent := Color(0.15, 0.35, 0.8)
var serif := false
var _serif_fam := 0                  # this site's families, see SERIF_FAMILIES / SANS_FAMILIES
var _sans_fam := 0
var title := ""               # what the tab says
var live := false             # built to the screen around a live chat ([method _live]): it never scrolls of itself
var sound_rect := Rect2()     # a live page's sound button, on its picture's corner

var _x0 := 0.0
var _col := 0.0
var _y := 0.0
var _line: Array = []         # word items waiting for their line to be finished
var _line_x := 0.0
var _line_h := 0.0
var _center := false
var _post := {}               # the forum post being set ([method _post_begin]), {} outside one

static var _faces := {}


## The face for [param serif_face] at [param level] (bit 1 italic, bit 2 bold).
static func face(serif_face: bool, level: int) -> Font:
	var k := "%s%d" % [serif_face, level]
	if _faces.has(k):
		return _faces[k]
	var f := SystemFont.new()
	f.font_names = PackedStringArray(BookLayout.SERIFS if serif_face else SANS)
	f.font_italic = (level & 1) != 0
	f.font_weight = 700 if (level & 2) != 0 else 400
	f.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	_faces[k] = f
	return f


## A face in one of the site families: [param family] indexes SERIF_FAMILIES or SANS_FAMILIES.
static func face_of(serif_face: bool, family: int, level: int) -> Font:
	var k := "%s|%d|%d" % [serif_face, family, level]
	if _faces.has(k):
		return _faces[k]
	var names: Array = (SERIF_FAMILIES if serif_face else SANS_FAMILIES)[family]
	var f := SystemFont.new()
	f.font_names = PackedStringArray(names + (BookLayout.SERIFS if serif_face else SANS))
	f.font_italic = (level & 1) != 0
	f.font_weight = 700 if (level & 2) != 0 else 400
	f.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	_faces[k] = f
	return f


## This site's face: its serif or its sans.
func _face(serif_face: bool, level: int) -> Font:
	return face_of(serif_face, _serif_fam if serif_face else _sans_fam, level)


func _h(salt: String) -> int:
	return hash([String((script_doc["pages"][index] as Dictionary)["host"]), salt])


func _f(salt: String) -> float:
	return float(_h(salt) & 0xFFFF) / 65535.0


## Typeset page [param pi] of [param doc] at [param w] pixels wide.
## Page [param pi] of [param doc] set [param w] wide, padded to [param min_h]; a live page is [param view] tall (the screen
## under the browser's bars).
func build(doc: Dictionary, pi: int, w: float, min_h: float, view := 0.0) -> void:
	script_doc = doc
	index = pi
	width = w
	min_height = min_h
	items = []
	live = false
	sound_rect = Rect2()
	word_rect = {}
	block_rect = {}
	var page: Dictionary = doc["pages"][pi]
	serif = _f("serif") < 0.35 and not bool(page["results"])
	_serif_fam = absi(_h("serif face")) % SERIF_FAMILIES.size()
	_sans_fam = absi(_h("sans face")) % SANS_FAMILIES.size()
	accent = Color.from_hsv(_f("hue"), lerpf(0.55, 0.85, _f("sat")), lerpf(0.45, 0.7, _f("val")))
	bg = Color.from_hsv(_f("hue") + 0.08, 0.04, 0.99) if _f("paper") < 0.4 else Color.WHITE
	_col = minf(w - MARGIN * 2.0, MAX_COLUMN)
	_x0 = (w - _col) * 0.5
	_y = 34.0
	var blocks: Array = page["blocks"]
	title = String(page["host"])
	if bool(page.get("real", false)):
		_real(page, w, min_h)
		return
	for b in blocks:
		if String((b as Dictionary)["kind"]) == "chat":
			_live(blocks, view if view > 0.0 else min_h / 2.4)
			return
	var engine := bool(page["search_box"]) and not bool(page["results"]) and _written(blocks) <= 3
	if engine:
		_engine_home(blocks)
		height = maxf(_y + 120.0, min_h * 0.6) if placeholders else _y + 120.0
		return
	if bool(page["results"]):
		_search_box(String(page["query"]))
		_y += 18.0
		title = String(page["query"])
	var boxed := not bool(page["search_box"]) or bool(page["results"])
	_post = {}
	for i in blocks.size():
		var b: Dictionary = blocks[i]
		if not _post.is_empty() and int(b.get("post", 0)) != int(_post["n"]):
			_post_end()
		match String(b["kind"]):
			"post":
				_post_begin(b)
			"quote":
				_quote(b)
			"heading":
				var lvl := int(b["level"])
				if i == 0 and lvl == 1 and not bool(page["results"]) and _site_name().is_empty():
					_masthead(b)
				else:
					if i == 0 and not bool(page["results"]) and not _site_name().is_empty():
						_band(_site_name())
						# A later page opening on the site's own name: that title is the band above it, so
						# it is not set again; the article's own title follows as the page's.
						if lvl == 1 and _plain(b).strip_edges().to_lower() == _site_name().strip_edges().to_lower():
							continue
					if bool(page["results"]) and _is_link(b):
						_result_url(b)
					_text(b, mini(lvl, 3), 2)
				if title == String(page["host"]) and lvl <= 2:
					title = _plain(b)
				if bool(b.get("stub", false)) and placeholders:
					_squiggles(3, BODY, ink.lerp(bg, 0.72), "stub%d" % i)
					_y += 26.0
				if not boxed and i == 0:
					_search_box("")
					boxed = true
			"para":
				_text(b, 0, 0)
				_y += BODY * 0.7
			"table":
				_table(b)
			"item":
				_item(b)
				var nb: Dictionary = blocks[i + 1] if i + 1 < blocks.size() else {}
				if String(nb.get("kind", "")) != "item" or int(nb.get("list", -1)) != int(b["list"]):
					_pager("pager%d" % i)
			"image":
				_image(b, i)
			"pager":
				_pager("pager%d" % i, int(b["n"]))
			"filler":
				for k in int(b["n"]) if placeholders else 0:
					_filler("f%d_%d" % [i, k])
			"rule":
				items.append({"kind": "rule", "rect": Rect2(_x0, _y + 10.0, _col, 2.0)})
				_y += 24.0
	if not _post.is_empty():
		_post_end()
	if not boxed:
		_search_box("")
	if bool(page.get("reply", false)):
		_reply_box()
	# A page goes on past its article (related stories, comments) so its last written lines can be
	# scrolled up to where the rest were read.
	var want := maxf(min_h, _y + min_h * TAIL_SHARE) if placeholders else 0.0
	var k := 0
	while _y < want:
		_filler("pad%d" % k)
		k += 1
	_y += 40.0
	var site := _site_name()
	if site.is_empty() and not blocks.is_empty() and String((blocks[0] as Dictionary)["kind"]) == "heading":
		site = _plain(blocks[0])
	items.append({"kind": "foot", "rect": Rect2(0.0, _y, w, 160.0), "site": site})
	_y += 160.0
	height = _y


# --- a live page ------------------------------------------------------------------------

## A page with a live chat, built to [param view] and no taller: its written blocks in order (its picture cropped to
## [constant LIVE_PICTURE] of the screen), then the paid messages, the stream, and the message box at the foot. The stream
## is set before the paid messages so they, and the box, are drawn over what runs past its edges.
func _live(blocks: Array, view: float) -> void:
	live = true
	var chat := {}
	for i in blocks.size():
		var b: Dictionary = blocks[i]
		match String(b["kind"]):
			"chat":
				if chat.is_empty():
					chat = b
			"heading":
				_text(b, clampi(int(b["level"]) + 1, 2, 3), 2)
				if title == String(script_doc["pages"][index]["host"]):
					title = _plain(b)
			"para", "item":
				_text(b, 0, 0)
				_y += BODY * 0.4
			"image":
				_image(b, i)
				var r: Rect2 = block_rect[i]
				var cap := view * LIVE_PICTURE
				if r.size.y > cap:
					r.size.y = cap
					block_rect[i] = r
					(items.back() as Dictionary)["rect"] = r
					_y = r.end.y + 34.0
				items.append({"kind": "live", "rect": Rect2(r.position + Vector2(18.0, 18.0), Vector2(104.0, 42.0))})
				if sound_rect.size == Vector2.ZERO:
					sound_rect = Rect2(Vector2(r.position.x + 18.0, r.end.y - 18.0 - SOUND_BUTTON), Vector2(SOUND_BUTTON, SOUND_BUTTON))
					items.append({"kind": "sound", "rect": sound_rect})
				_y -= 14.0
			"rule":
				items.append({"kind": "rule", "rect": Rect2(_x0, _y + 6.0, _col, 2.0)})
				_y += 16.0
	_y += 14.0
	var foot := view - 76.0 - 26.0
	var paid := Rect2(_x0, _y, _col, PAID_H * PAID_SLOTS + PAID_GAP * (PAID_SLOTS - 1))
	var stream_top := paid.end.y + 16.0
	items.append({"kind": "chat", "rect": Rect2(_x0, stream_top, _col, maxf(foot - 14.0 - stream_top, CHAT_LINE)), "chat": chat})
	items.append({"kind": "paid", "rect": paid, "chat": chat, "cover": Rect2(0.0, paid.position.y - 6.0, width, stream_top - paid.position.y + 6.0)})
	items.append({"kind": "cover", "rect": Rect2(0.0, foot - 14.0, width, view - foot + 14.0)})
	reply_rect = Rect2(_x0, foot, _col, 76.0)
	items.append({"kind": "reply", "rect": reply_rect})
	height = view


## The messages of [param chat] in the stream at [param now], newest first, until [param tall] is filled: `{at, name, said}`.
## A pure function of the time and the page: each slot of 1 / rate seconds holds none, one or two (about one on average),
## its words taken through the bank so none comes back until the bank has gone round, and its name drawn at random.
func chat_at(chat: Dictionary, now: float, tall: float) -> Array:
	var said: PackedStringArray = chat.get("said", PackedStringArray())
	var names: PackedStringArray = chat.get("names", PackedStringArray(["viewer"]))
	if said.is_empty():
		return []
	var rate := float(chat.get("rate", TabletScript.CHAT_RATE))
	var n := said.size()
	var stride := 1 + absi(_h("chat stride")) % maxi(n - 1, 1)
	while _gcd(stride, n) != 1:
		stride += 1
	var out: Array = []
	var used := 0.0
	var k := int(floor(now * rate))
	var guard := 0
	while used < tall + CHAT_LINE * 3.0 and guard < 600:
		var f := _f("chat slot %d" % k)
		var many := 0 if f < 0.2 else (1 if f < 0.8 else 2)
		for j in range(many - 1, -1, -1):
			var at := (float(k) + (float(j) + lerpf(0.1, 0.9, _f("chat at %d %d" % [k, j]))) / float(many)) / rate
			if at > now:
				continue
			var id := k * 2 + j
			var lap := int(floor(float(id) / float(n)))
			var m := {"at": at, "name": names[absi(_h("chat name %d %d" % [k, j])) % names.size()],
				"said": said[posmod(id * stride + absi(_h("chat lap %d" % lap)), n)]}
			out.append(m)
			used += float(_chat_lines(m).size()) * CHAT_LINE + CHAT_GAP
		k -= 1
		guard += 1
	return out


static func _gcd(a: int, b: int) -> int:
	while b != 0:
		var t := b
		b = a % b
		a = t
	return a


var _wrapped := {}            # a message's name and words -> its lines as set in the stream


## A message's lines in the stream: its name, then its words after it, wrapped to the column (`[[x, text], ...]` per line,
## the first line's first entry the name).
func _chat_lines(m: Dictionary) -> Array:
	var key := String(m["name"]) + "\u0001" + String(m["said"])
	if _wrapped.has(key):
		return _wrapped[key]
	var f := _face(false, 0)
	var fb := _face(false, 2)
	var sp := f.get_string_size(" ", HORIZONTAL_ALIGNMENT_LEFT, -1, CHAT_FS).x
	var x := fb.get_string_size(String(m["name"]), HORIZONTAL_ALIGNMENT_LEFT, -1, CHAT_FS).x + sp * 2.0
	var lines: Array = []
	var cur := ""
	var x0 := x
	for w in String(m["said"]).split(" ", false):
		var try := w if cur.is_empty() else cur + " " + w
		if not cur.is_empty() and x0 + f.get_string_size(try, HORIZONTAL_ALIGNMENT_LEFT, -1, CHAT_FS).x > _col:
			lines.append([x0, cur])
			cur = w
			x0 = 0.0
		else:
			cur = try
	lines.append([x0, cur])
	_wrapped[key] = lines
	return lines


## A name's color in the stream: its own hue, dark enough to read on the page.
func _name_col(name: String) -> Color:
	return Color.from_hsv(fposmod(float(hash(name) & 1023) / 1024.0, 1.0), 0.7, 0.62)


## The stream in [param r] at [param now]: the newest at the foot, pushing the rest up as it comes in.
func _draw_chat(ci: CanvasItem, r: Rect2, chat: Dictionary, now: float) -> void:
	var ms := chat_at(chat, now, r.size.y)
	if ms.is_empty():
		return
	var newest: Dictionary = ms[0]
	var h0 := float(_chat_lines(newest).size()) * CHAT_LINE + CHAT_GAP
	var y := r.end.y + h0 * (1.0 - _ease_out((now - float(newest["at"])) / CHAT_IN))
	var f := _face(false, 0)
	var fb := _face(false, 2)
	for m in ms:
		var lines := _chat_lines(m)
		var h := float(lines.size()) * CHAT_LINE + CHAT_GAP
		y -= h
		if y + h < r.position.y - CHAT_LINE:
			break
		for li in lines.size():
			var base := y + CHAT_LINE * float(li) + CHAT_FS * 1.0
			if li == 0:
				ci.draw_string(fb, Vector2(r.position.x, base), String(m["name"]), HORIZONTAL_ALIGNMENT_LEFT, -1, CHAT_FS,
					_name_col(String(m["name"])))
			ci.draw_string(f, Vector2(r.position.x + float((lines[li] as Array)[0]), base), String((lines[li] as Array)[1]),
				HORIZONTAL_ALIGNMENT_LEFT, -1, CHAT_FS, ink)


## The sound button in [param r]: a speaker on a dark disc, its waves out when [param on], else crossed out.
func _draw_sound(ci: CanvasItem, r: Rect2, on: bool) -> void:
	var c := r.get_center()
	var u := r.size.x / 64.0
	ci.draw_circle(c, r.size.x * 0.5, Color(0.0, 0.0, 0.0, 0.55), true, -1.0, true)
	var w := Color.WHITE
	var body := PackedVector2Array([c + Vector2(-17, -7) * u, c + Vector2(-9, -7) * u, c + Vector2(1, -16) * u,
		c + Vector2(1, 16) * u, c + Vector2(-9, 7) * u, c + Vector2(-17, 7) * u])
	ci.draw_colored_polygon(body, w)
	if on:
		for k in 2:
			var rad := (9.0 + 8.0 * float(k)) * u
			ci.draw_arc(c + Vector2(3, 0) * u, rad, -0.9, 0.9, 16, w, 3.2 * u, true)
	else:
		ci.draw_line(c + Vector2(8, -8) * u, c + Vector2(20, 8) * u, w, 3.6 * u, true)
		ci.draw_line(c + Vector2(8, 8) * u, c + Vector2(20, -8) * u, w, 3.6 * u, true)


## A paid amount's color, by how much it is (the digits in it): from blue for the least to red for the most.
static func paid_col(amount: String) -> Color:
	var v := String(amount).to_float() if amount.is_valid_float() else 0.0
	var digits := RegEx.create_from_string("[0-9]+(\\.[0-9]+)?").search(amount)
	if digits != null:
		v = digits.get_string().to_float()
	if v < 2.0:
		return Color(0.12, 0.53, 0.9)
	if v < 5.0:
		return Color(0.0, 0.72, 0.83)
	if v < 10.0:
		return Color(0.11, 0.85, 0.66)
	if v < 20.0:
		return Color(1.0, 0.79, 0.16)
	if v < 50.0:
		return Color(0.96, 0.49, 0.0)
	if v < 100.0:
		return Color(0.91, 0.12, 0.39)
	return Color(0.9, 0.13, 0.13)


## The paid messages in [param r]: the page's own, and above them each reply sent from it ([param sent]: `{text, at}`) once
## sent, coming in at the top and lit, pushing the others down; as many as [constant PAID_SLOTS] show.
func _draw_paid(ci: CanvasItem, r: Rect2, cover: Rect2, chat: Dictionary, now: float, sent: Array) -> void:
	ci.draw_rect(cover, bg)
	var cards: Array = []
	for p in (chat.get("paid", []) as Array):
		cards.append({"amount": String(p["amount"]), "name": String(p["name"]), "text": String(p["text"]), "at": -INF})
	var tip := String(chat.get("tip", ""))
	for s in sent:
		var at := float((s as Dictionary)["at"])
		if at <= now:
			cards.push_front({"amount": tip if not tip.is_empty() else "$5", "name": String(chat.get("me", "")) if not String(chat.get("me", "")).is_empty() else "you",
				"text": String((s as Dictionary)["text"]), "at": at, "mine": true})
	if cards.is_empty():
		var f := _face(false, 0)
		ci.draw_string(f, Vector2(r.position.x, r.get_center().y + 9.0), "No paid messages yet", HORIZONTAL_ALIGNMENT_LEFT, -1, 24,
			ink.lerp(bg, 0.6))
		return
	var step := PAID_H + PAID_GAP
	var come := 1.0
	if bool((cards[0] as Dictionary).get("mine", false)):
		come = _ease_out((now - float((cards[0] as Dictionary)["at"])) / PAID_IN)
	for k in mini(cards.size(), PAID_SLOTS + 1):
		var c: Dictionary = cards[k]
		var y := r.position.y + step * (float(k) - (1.0 - come))
		var alpha := 1.0
		if k == 0 and come < 1.0:
			alpha = come
		if k >= PAID_SLOTS:
			alpha = 1.0 - come
		if alpha <= 0.01:
			continue
		_paid_card(ci, Rect2(r.position.x, y, r.size.x, PAID_H), c, now, alpha)
	ci.draw_rect(Rect2(0.0, r.end.y + 2.0, width, cover.end.y - r.end.y - 2.0), bg)
	# the stream fades out under the paid messages rather than ending on a cut line
	for k in CHAT_FADE_STEPS:
		var u := float(k) / float(CHAT_FADE_STEPS)
		ci.draw_rect(Rect2(0.0, cover.end.y + CHAT_FADE * u, width, CHAT_FADE / float(CHAT_FADE_STEPS) + 0.5),
			Color(bg.r, bg.g, bg.b, 1.0 - u))


func _paid_card(ci: CanvasItem, r: Rect2, c: Dictionary, now: float, alpha: float) -> void:
	var col := paid_col(String(c["amount"]))
	var dark := col.get_luminance() < 0.55
	var text_col := Color(1, 1, 1, alpha) if dark else Color(0.08, 0.08, 0.1, alpha)
	if _box == null:
		_box = StyleBoxFlat.new()
		_box.anti_aliasing = true
	var mine := bool(c.get("mine", false))
	if mine:
		var glow := 1.0 - clampf((now - float(c["at"])) / PAID_GLOW, 0.0, 1.0)
		for g in 3:
			var grow := 4.0 + float(g) * 5.0 + glow * 6.0
			_box.bg_color = Color(accent.r, accent.g, accent.b, (0.22 - float(g) * 0.06) * alpha * (0.6 + glow * 0.4))
			_box.set_border_width_all(0)
			_box.set_corner_radius_all(int(16.0 + grow))
			ci.draw_style_box(_box, r.grow(grow))
	_box.bg_color = Color(col.r, col.g, col.b, alpha)
	_box.border_color = Color(1, 1, 1, alpha) if mine else Color(col.r, col.g, col.b, alpha)
	_box.set_border_width_all(4 if mine else 0)
	_box.set_corner_radius_all(16)
	ci.draw_style_box(_box, r)
	var f := _face(false, 0)
	var fb := _face(false, 2)
	var x := r.position.x + 22.0
	ci.draw_string(fb, Vector2(x, r.position.y + 31.0), String(c["name"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 24, text_col)
	var nw := fb.get_string_size(String(c["name"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x
	ci.draw_string(fb, Vector2(x + nw + 16.0, r.position.y + 31.0), String(c["amount"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 24, text_col)
	ci.draw_string(f, Vector2(x, r.position.y + 63.0), _fit(String(c["text"]), f, 24, r.size.x - 44.0), HORIZONTAL_ALIGNMENT_LEFT, -1, 24,
		text_col)


## [param text] cut with an ellipsis to fit [param w] at size [param fs].
static func _fit(text: String, f: Font, fs: int, w: float) -> String:
	if f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x <= w:
		return text
	var t := text
	while t.length() > 1 and f.get_string_size(t + "…", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > w:
		t = t.substr(0, t.length() - 1)
	return t.strip_edges() + "…"


static func _ease_out(u: float) -> float:
	var x := clampf(u, 0.0, 1.0)
	return 1.0 - (1.0 - x) * (1.0 - x)


static func _written(blocks: Array) -> int:
	var n := 0
	for b in blocks:
		if (b as Dictionary)["kind"] != "filler":
			n += 1
	return n


func _is_link(b: Dictionary) -> bool:
	var ws: PackedInt32Array = b.get("words", PackedInt32Array())
	return not ws.is_empty() and not String((script_doc["words"][ws[0]] as Dictionary)["link"]).is_empty()


func _plain(b: Dictionary) -> String:
	var out := PackedStringArray()
	for wi in (b.get("words", PackedInt32Array()) as PackedInt32Array):
		out.append(String((script_doc["words"][wi] as Dictionary)["text"]))
	return " ".join(out)


# --- text ----------------------------------------------------------------------------

## Set block [param b]'s words: [param level] picks the size (0 body), [param emph] is added
## to every word's own emphasis (2 = bold, for headings).
##
## A word after a `<br>` starts a new line; with [param detail], it and the rest are set at [constant DETAIL_FS], muted
## (a table cell's detail). [param size] sets the size outright.
func _text(b: Dictionary, level: int, emph: int, col := Color(0, 0, 0, 0), centered := false, detail := false,
		size := 0) -> void:
	var fs: int = size if size > 0 else SIZES.get(level, BODY)
	_center = centered
	_y += fs * 0.25 if level > 0 else 0.0
	_line_x = 0.0
	_line = []
	_line_h = fs * LEAD
	for wi in (b.get("words", PackedInt32Array()) as PackedInt32Array):
		var w: Dictionary = script_doc["words"][wi]
		if bool(w.get("brk", false)):
			_end_line()
			if detail:
				fs = DETAIL_FS
				emph = 0
				_line_h = fs * LEAD
				col = ink.lerp(bg, 0.42)
		var lvl := int(w["emph"]) | emph
		var f := _face(serif, lvl)
		var ww := f.get_string_size(String(w["text"]), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var sp := f.get_string_size(" ", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		if bool(w.get("glue", false)) and _line_x > 0.0:
			_line_x -= sp                  # no space before it, as written
		if _line_x > 0.0 and _line_x + ww > _col:
			_end_line()
		# A link looks like one only inline: a heading that links is set as a heading (a site's titles
		# are all clickable by convention).
		var link := not String(w["link"]).is_empty() and level == 0
		var c := col if col.a > 0.0 else (accent if link else ink)
		_line.append({"kind": "word", "wi": wi, "x": _line_x, "w": ww, "fs": fs, "lvl": lvl,
			"col": c, "link": link})
		_line_x += ww + sp
	_end_line()


func _end_line() -> void:
	if _line.is_empty():
		return
	var used: float = (_line.back() as Dictionary)["x"] + (_line.back() as Dictionary)["w"]
	var shift := (_col - used) * 0.5 if _center else 0.0
	for k in _line.size():
		var d: Dictionary = _line[k]
		# a link's underline runs on under the space to its next word, one line under the whole link
		var nx: Dictionary = _line[k + 1] if k + 1 < _line.size() else {}
		var same := bool(d["link"]) and not nx.is_empty() and bool(nx["link"]) \
			and String(script_doc["words"][int(nx["wi"])]["link"]) == String(script_doc["words"][int(d["wi"])]["link"])
		d["ul"] = float(nx["x"]) - float(d["x"]) if same else float(d["w"])
		var fs := int(d["fs"])
		var x := _x0 + shift + float(d["x"])
		d["pos"] = Vector2(x, _y + fs * 1.08)
		var r := Rect2(x - 4.0, _y + fs * 0.12, float(d["w"]) + 8.0, fs * 1.24)
		d["rect"] = r
		word_rect[int(d["wi"])] = r
		items.append(d)
	_y += _line_h
	_line = []
	_line_x = 0.0


# --- the furniture ---------------------------------------------------------------------

## A list item: a bullet (or the item's own number) in the margin, the text hung beside it.
func _item(b: Dictionary) -> void:
	var indent := BODY * 1.4
	var y0 := _y
	_x0 += indent
	_col -= indent
	_text(b, 0, 0)
	_x0 -= indent
	_col += indent
	var mark := String(b.get("mark", ""))
	if mark.is_empty():
		var d := BODY * 0.28
		items.append({"kind": "dot", "rect": Rect2(_x0 + BODY * 0.4, y0 + BODY * 0.62, d, d),
			"col": ink.lerp(bg, 0.3)})
	else:
		items.append({"kind": "label", "pos": Vector2(_x0, y0 + BODY * 1.08), "text": mark, "fs": BODY,
			"col": ink.lerp(bg, 0.35)})
	_y += BODY * 0.35


# --- a forum ---------------------------------------------------------------------------

## A forum post opens ([param b], a `post` block): a strip across its top with when it was written and its number, and
## the column its body is set in, beside the author's. [method _post_end] closes it.
func _post_begin(b: Dictionary) -> void:
	var top := _y + 6.0
	_post = {"n": int(b["n"]), "who": String(b["who"]), "meta": String(b["meta"]), "when": String(b["when"]),
		"top": top, "at": items.size(), "x0": _x0, "col": _col}
	_x0 = _x0 + POST_SIDE + POST_PAD
	_col = float(_post["col"]) - POST_SIDE - POST_PAD * 2.0
	_y = top + POST_HEAD + POST_PAD


## The post open closes: as tall as its body or its author's column, whichever is taller, with its card, strip and
## column drawn under what was set in it, and Quote and Reply at its foot.
func _post_end() -> void:
	var p := _post
	_post = {}
	_x0 = float(p["x0"])
	_col = float(p["col"])
	var top := float(p["top"])
	var under: Array = []                 # drawn first: the card, the column, the strip
	var over: Array = []                  # the author's column and the strip's words
	var f := _face(false, 0)
	var fb := _face(false, 2)
	var side_x := _x0
	var cy := top + POST_HEAD + POST_PAD
	over.append({"kind": "avatar", "rect": Rect2(side_x + (POST_SIDE - AVATAR) * 0.5, cy, AVATAR, AVATAR), "seed": hash(String(p["who"]))})
	cy += AVATAR + 14.0
	var lines: Array = [[String(p["who"]), fb, 26, accent]]
	for m in String(p["meta"]).split("·", false):
		if not String(m).strip_edges().is_empty():
			lines.append([String(m).strip_edges(), f, 21, ink.lerp(bg, 0.45)])
	for ln in lines:
		var text := _fit(String(ln[0]), ln[1], int(ln[2]), POST_SIDE - 16.0)
		var tw := (ln[1] as Font).get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, int(ln[2])).x
		over.append({"kind": "label", "pos": Vector2(side_x + (POST_SIDE - tw) * 0.5, cy + float(ln[2])), "text": text, "fs": int(ln[2]),
			"col": ln[3], "bold": ln[1] == fb})
		cy += float(ln[2]) * 1.45
	var foot := maxf(_y, cy) + 8.0
	for k in 2:
		var label: String = ["Quote", "Reply"][k]
		var lw := f.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
		over.append({"kind": "label", "pos": Vector2(_x0 + _col - POST_PAD - lw - (0.0 if k == 1 else 110.0), foot + 26.0), "text": label,
			"fs": 22, "col": ink.lerp(bg, 0.5)})
	var bottom := foot + 26.0 + POST_PAD
	under.append({"kind": "card", "rect": Rect2(_x0, top, _col, bottom - top)})
	under.append({"kind": "band", "rect": Rect2(_x0, top + POST_HEAD, POST_SIDE, bottom - top - POST_HEAD), "col": accent.lerp(bg, 0.94)})
	under.append({"kind": "band", "rect": Rect2(_x0, top, _col, POST_HEAD), "col": accent.lerp(bg, 0.84)})
	over.append({"kind": "label", "pos": Vector2(_x0 + POST_PAD, top + 34.0), "text": String(p["when"]), "fs": 22, "col": ink.lerp(bg, 0.3)})
	var num := "#%d" % int(p["n"])
	over.append({"kind": "label", "pos": Vector2(_x0 + _col - POST_PAD - fb.get_string_size(num, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x, top + 34.0),
		"text": num, "fs": 22, "col": ink.lerp(bg, 0.3), "bold": true})
	var at := int(p["at"])
	for k in under.size():
		items.insert(at + k, under[k])
	items.append_array(over)
	_y = bottom + POST_GAP


## A quote ([param b]): its words a little smaller in a tinted box with a bar down its left, as a forum quotes a post.
func _quote(b: Dictionary) -> void:
	var top := _y + 4.0
	var at := items.size()
	_x0 += 30.0
	_col -= 48.0
	_y = top + 14.0
	_text(b, 0, 0, ink.lerp(bg, 0.2), false, false, QUOTE_FS)
	_x0 -= 30.0
	_col += 48.0
	var r := Rect2(_x0, top, _col, _y - top + 14.0)
	items.insert(at, {"kind": "band", "rect": Rect2(r.position, Vector2(6.0, r.size.y)), "col": accent.lerp(bg, 0.35)})
	items.insert(at, {"kind": "band", "rect": r, "col": accent.lerp(bg, 0.92)})
	_y = r.end.y + BODY * 0.6


## An avatar nobody uploaded, as a forum draws one: a five by five pattern mirrored down its middle, in one color of the
## name's own on a pale ground. Deterministic in [param seed].
func _draw_avatar(ci: CanvasItem, r: Rect2, seed: int) -> void:
	var col := Color.from_hsv(float(absi(seed) % 360) / 360.0, 0.55, 0.62)
	ci.draw_rect(r, col.lerp(Color.WHITE, 0.88))
	var cell := r.size.x / 6.0
	var o := r.position + Vector2(cell * 0.5, cell * 0.5)
	for y in 5:
		for x in 3:
			if (seed >> (y * 3 + x)) & 1 == 0:
				continue
			ci.draw_rect(Rect2(o + Vector2(x, y) * cell, Vector2(cell, cell)), col)
			ci.draw_rect(Rect2(o + Vector2(4 - x, y) * cell, Vector2(cell, cell)), col)


## A table: the header on a tinted band, the rows ruled apart, each cell's words set in its own column,
## columns as wide as their longest cell asks, within reason.
func _table(b: Dictionary) -> void:
	var head: Array = b.get("head_cells", [])
	var rows: Array = b.get("row_cells", [])
	var n := head.size()
	for r in rows:
		n = maxi(n, (r as Array).size())
	if n == 0:
		return
	# No column narrower than its widest word (a word cannot wrap); the rest of the width is shared by
	# how much each column holds.
	var weights: Array = []
	var mins: Array = []
	for k in n:
		var longest := 0
		var widest := 0.0
		for r in [head] + rows:
			if k < (r as Array).size():
				longest = maxi(longest, _chars(r[k]))
				widest = maxf(widest, _widest(r[k], 2 if r == head else 0))
		weights.append(clampf(float(longest), 6.0, 60.0))
		mins.append(widest + TABLE_PAD * 2.0 + 4.0)
	# a column of numbers (topics, replies, views) is set in the middle of its column, as a forum's counts are
	var counts: Array = []
	for k in n:
		var all_counts := not rows.is_empty()
		for r in rows:
			if k < (r as Array).size() and not _is_count(r[k]):
				all_counts = false
		counts.append(all_counts)
	var ws := _share(_col, weights, mins)
	var xs: Array = []
	var x := _x0
	for k in n:
		xs.append(x)
		x += float(ws[k])
	_y += BODY * 0.4
	if not head.is_empty():
		_row(head, xs, ws, 2, true, counts)
	for ri in rows.size():
		_row(rows[ri], xs, ws, 0, false, counts, ri % 2 == 1)
	_y += BODY * 0.7


## Whether a cell holds nothing but a count: digits, with their commas and points.
func _is_count(cell: Variant) -> bool:
	var ws := cell as PackedInt32Array
	if ws.is_empty():
		return false
	for wi in ws:
		if TabletScript._rx("^[0-9][0-9,.]*[KkMm%]?$").search(String(script_doc["words"][wi]["text"])) == null:
			return false
	return true


## [param total] shared by [param weights], no share under its floor in [param mins]: a column
## held at its floor gives its share up, and the rest is shared again among the others.
static func _share(total: float, weights: Array, mins: Array) -> Array:
	var n := weights.size()
	var fixed := {}
	var ws: Array = []
	ws.resize(n)
	for _pass in n + 1:
		var free := total
		var wsum := 0.0
		for k in n:
			if fixed.has(k):
				free -= float(mins[k])
			else:
				wsum += float(weights[k])
		var settled := true
		for k in n:
			if fixed.has(k):
				ws[k] = float(mins[k])
				continue
			ws[k] = maxf(0.0, free) * float(weights[k]) / maxf(wsum, 0.001)
			if ws[k] < float(mins[k]):
				fixed[k] = true
				settled = false
		if settled:
			break
	return ws


## The widest single word of a cell, in the face it is set in.
func _widest(cell: Variant, emph: int) -> float:
	var w := 0.0
	for wi in (cell as PackedInt32Array):
		var word: Dictionary = script_doc["words"][wi]
		var f := _face(serif, int(word["emph"]) | emph)
		w = maxf(w, f.get_string_size(String(word["text"]), HORIZONTAL_ALIGNMENT_LEFT, -1, BODY).x)
	return w


## One row of a table: every cell from the same top, the row as tall as its tallest cell.
const TABLE_PAD := 16.0

func _row(cells: Array, xs: Array, ws: Array, emph: int, header: bool, counts := [], banded := false) -> void:
	const PAD := TABLE_PAD
	var top := _y
	var bottom := top
	var at := items.size()
	var x0 := _x0
	var col := _col
	for k in cells.size():
		_x0 = float(xs[k]) + PAD
		_col = float(ws[k]) - PAD * 2.0
		_y = top + PAD * 0.7
		_text({"words": cells[k]}, 0, emph, Color(0, 0, 0, 0), k < counts.size() and bool(counts[k]), not header)
		bottom = maxf(bottom, _y)
	_x0 = x0
	_col = col
	_y = bottom + PAD * 0.7
	var span := Rect2(_x0, top, _col, _y - top)
	if header:
		items.insert(at, {"kind": "band", "rect": span, "col": accent.lerp(bg, 0.86)})
	elif banded:
		items.insert(at, {"kind": "band", "rect": span, "col": ink.lerp(bg, 0.965)})
	items.append({"kind": "rule", "rect": Rect2(_x0, _y - 1.0, _col, 1.5)})


## How many characters a cell's words come to, with their spaces.
func _chars(cell: Variant) -> int:
	var n := 0
	for wi in (cell as PackedInt32Array):
		n += String(script_doc["words"][wi]["text"]).length() + 1
	return n


## The foot of a list, or a `pager` mark's place: Back (grayed) and Next, a sample of a longer listing ([param pages] of
## it, else a number drawn from the site).
func _pager(salt: String, pages := 0) -> void:
	_y += BODY * 0.3
	var r := Rect2(_x0, _y, _col, 60.0)
	items.append({"kind": "pager", "rect": r, "pages": pages if pages > 0 else 6 + absi(_h(salt)) % 19})
	_y = r.end.y + BODY * 0.7


## A real page: its capture, edge to edge at the tablet's width, as long as the capture is. Not captured
## yet, a plain page saying so, with the address.
func _real(page: Dictionary, w: float, min_h: float) -> void:
	bg = Color.WHITE
	var key := String(page["snap"])
	var path := Illustrations.path_for(key)
	var h := min_h
	if not path.is_empty():
		var img := Image.load_from_file(path)
		if img != null and not img.is_empty():
			h = w * float(img.get_height()) / float(img.get_width())
	items.append({"kind": "snap", "rect": Rect2(0.0, 0.0, w, h), "key": key,
		"url": String(page["url"])})
	height = h


## The name an earlier page on this host gave the site (its opening H1, set as the masthead), or "" when
## this is the first page of the host seen (whose own H1 then becomes the masthead). A page at this one's own
## address is this page come up again, set as it was: never an earlier page of its site.
func _site_name() -> String:
	var here: Dictionary = script_doc["pages"][index]
	var host := String(here["host"])
	for k in index:
		var pg: Dictionary = script_doc["pages"][k]
		if String(pg["host"]) != host or bool(pg["results"]) or (pg["blocks"] as Array).is_empty() \
				or TabletScript.url_key(String(pg["url"])) == TabletScript.url_key(String(here["url"])):
			continue
		var b0: Dictionary = (pg["blocks"] as Array)[0]
		if b0["kind"] == "heading" and int(b0["level"]) == 1:
			return _plain(b0)
	return ""


## The site's name, remembered from an earlier page, in a thinner band of its color: not words of this
## page, so nothing to read or highlight.
func _band(name: String) -> void:
	var top := _y - 34.0
	items.append({"kind": "band", "rect": Rect2(0.0, top, width, 96.0), "col": accent.darkened(0.25)})
	items.append({"kind": "label", "pos": Vector2(MARGIN, top + 62.0), "text": name, "fs": 34,
		"col": Color.WHITE, "bold": true})
	_y = top + 96.0
	_nav()


## A news site's name, in a band of its color.
func _masthead(b: Dictionary) -> void:
	var top := _y - 34.0
	var n0 := items.size()
	_y += 26.0
	var x0 := _x0
	var col := _col
	_x0 = MARGIN
	_col = width - MARGIN * 2.0
	_text(b, 1, 2, Color.WHITE)
	_x0 = x0
	_col = col
	_y += 26.0
	items.insert(n0, {"kind": "band",
		"rect": Rect2(0.0, top, width, _y - top), "col": accent.darkened(0.25)})
	_nav()


## The row of the site's menu under its name: what it names ([method _site_nav]), else squiggles, else (no placeholders)
## no row.
func _nav() -> void:
	var labels := _site_nav()
	if labels.is_empty() and not placeholders:
		_y += 30.0
		return
	items.append({"kind": "nav", "rect": Rect2(0.0, _y, width, 58.0), "labels": labels})
	_y += 58.0 + 30.0


## The site's menu: this page's `nav`, else the one an earlier page of its host named.
func _site_nav() -> PackedStringArray:
	var here: Dictionary = script_doc["pages"][index]
	if not (here.get("nav", PackedStringArray()) as PackedStringArray).is_empty():
		return here["nav"]
	for k in range(index - 1, -1, -1):
		var pg: Dictionary = script_doc["pages"][k]
		if String(pg["host"]) == String(here["host"]) and not (pg.get("nav", PackedStringArray()) as PackedStringArray).is_empty():
			return pg["nav"]
	return PackedStringArray()


## A search engine's front page: its name as a logo, centered, and the box under it.
func _engine_home(blocks: Array) -> void:
	_y = 230.0
	for i in blocks.size():
		var b: Dictionary = blocks[i]
		if b["kind"] == "heading" and i == 0:
			var n0 := items.size()
			_text(b, 1, 2, accent, true)
			for k in range(n0, items.size()):
				var d: Dictionary = items[k]
				d["fs"] = 76
				d["logo"] = true
			# re-set at logo size, centered
			_relayout_logo(n0)
			_y += 50.0
			title = _plain(b)
			_search_box("", true)
			_y += 40.0
		elif b["kind"] == "para" or b["kind"] == "heading":
			_text(b, 0, 0, ink.lerp(bg, 0.35), true)
			_y += 12.0


func _relayout_logo(n0: int) -> void:
	var total := 0.0
	var f := face(false, 2)
	for k in range(n0, items.size()):
		var d: Dictionary = items[k]
		d["w"] = f.get_string_size(String(script_doc["words"][int(d["wi"])]["text"]),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 76).x
		total += float(d["w"]) + 18.0
	total -= 18.0
	var x := (width - total) * 0.5
	var y: float = ((items[n0] as Dictionary)["rect"] as Rect2).position.y if n0 < items.size() else _y
	for k in range(n0, items.size()):
		var d: Dictionary = items[k]
		d["pos"] = Vector2(x, y + 76.0 * 1.0)
		d["rect"] = Rect2(x - 4.0, y, float(d["w"]) + 8.0, 76.0 * 1.25)
		word_rect[int(d["wi"])] = d["rect"]
		x += float(d["w"]) + 18.0
	_y = y + 76.0 * 1.3


func _search_box(query: String, wide := false) -> void:
	var w := _col * (0.86 if wide else 1.0)
	var r := Rect2((width - w) * 0.5, _y, w, 76.0)
	search_rect = r
	items.append({"kind": "search", "rect": r, "query": query})
	_y += 76.0 + 26.0


## A message box under the page's last line, a Send at its right end: where a reply is typed.
func _reply_box() -> void:
	_y += 8.0
	reply_rect = Rect2(_x0, _y, _col, 76.0)
	items.append({"kind": "reply", "rect": reply_rect})
	_y += 76.0 + 34.0


## The message box's Send, on the page.
func send_rect() -> Rect2:
	return Rect2(reply_rect.end.x - 150.0, reply_rect.position.y + 10.0, 140.0, reply_rect.size.y - 20.0)


func _result_url(b: Dictionary) -> void:
	var ws: PackedInt32Array = b["words"]
	var url := String((script_doc["words"][ws[0]] as Dictionary)["link"])
	items.append({"kind": "label", "pos": Vector2(_x0, _y + 24.0), "text": TabletScript.url_key(url),
		"fs": 22, "col": Color(0.13, 0.5, 0.25)})
	_y += 30.0


func _image(b: Dictionary, bi: int) -> void:
	var path := Illustrations.path_for(String(b["key"]))
	var aspect := 9.0 / 16.0
	if not path.is_empty():
		var img := Image.load_from_file(path)
		if img != null and not img.is_empty():
			aspect = float(img.get_height()) / float(img.get_width())
	var r := Rect2(_x0, _y + 8.0, _col, _col * clampf(aspect, 0.4, 1.3))
	if not _post.is_empty():
		# an attachment: no wider or taller than a forum shows one
		var aw := minf(_col, ATTACH_W)
		var ah := minf(aw * clampf(aspect, 0.4, 1.3), ATTACH_H)
		r = Rect2(_x0, _y + 8.0, ah / clampf(aspect, 0.4, 1.3), ah)
	items.append({"kind": "image", "rect": r, "key": String(b["key"]), "prompt": String(b["prompt"]),
		"seed": _h("img" + String(b["key"]))})
	block_rect[bi] = r
	_y = r.end.y + 34.0


## [param n] lines of squiggles, the last one short.
func _squiggles(n: int, fs: int, col: Color, salt: String, thick := 0.34) -> void:
	for i in n:
		var frac := 1.0 if i < n - 1 else lerpf(0.35, 0.8, _f(salt + str(i)))
		items.append({"kind": "squiggle", "rect": Rect2(_x0, _y + fs * 0.5, _col * frac, fs * thick),
			"seed": _h(salt + str(i)), "col": col})
		_y += fs * LEAD


## A story nobody wrote: a squiggled headline, sometimes a placeholder picture, a squiggled stub.
func _filler(salt: String) -> void:
	_y += 10.0
	_squiggles(1, 40, ink.lerp(bg, 0.45), salt + "h", 0.42)
	if _f(salt + "img") < 0.3:
		var r := Rect2(_x0, _y + 6.0, _col, _col * 0.42)
		items.append({"kind": "image", "rect": r, "key": "", "prompt": "", "seed": _h(salt + "pic")})
		_y = r.end.y + 22.0
	_squiggles(2 + (_h(salt + "n") & 3), BODY, ink.lerp(bg, 0.72), salt + "b")
	items.append({"kind": "rule", "rect": Rect2(_x0, _y + 14.0, _col, 1.5)})
	_y += 44.0


# --- drawing ----------------------------------------------------------------------------

## Draw the page onto [param ci] with its top at [param top] - [param scroll], keeping to the
## band [param clip_y0]..[param clip_y1]. [param lit] is the reading's highlight
## ([method TabletMedium._lit]).
func draw(ci: CanvasItem, top: float, scroll: float, clip_y0: float, clip_y1: float,
		lit: Dictionary, now: float, textures: Callable, state := {}) -> void:
	var sent: Array = state.get("sent", [])
	ci.draw_rect(Rect2(0.0, clip_y0, width, clip_y1 - clip_y0), bg)
	var dy := top - scroll
	for it in items:
		var d: Dictionary = it
		var kind := String(d["kind"])
		if kind == "word":
			var p: Vector2 = d["pos"]
			if p.y + dy < clip_y0 - 10.0 or p.y + dy - float(d["fs"]) > clip_y1 + 10.0:
				continue
			_draw_word(ci, d, dy, lit)
			continue
		var r: Rect2 = d.get("rect", Rect2(d.get("pos", Vector2.ZERO), Vector2(1, 1)))
		var rr := Rect2(r.position + Vector2(0.0, dy), r.size)
		if rr.end.y < clip_y0 - 40.0 or rr.position.y > clip_y1 + 40.0:
			continue
		match kind:
			"band":
				ci.draw_rect(rr, d["col"])
			"nav":
				ci.draw_rect(rr, accent.darkened(0.45))
				var labels: PackedStringArray = d.get("labels", PackedStringArray())
				if not labels.is_empty():
					var lx := MARGIN
					for l in labels:
						if lx > width - MARGIN - 40.0:
							break
						ci.draw_string(_face(false, 0), Vector2(lx, rr.get_center().y + 9.0), l, HORIZONTAL_ALIGNMENT_LEFT, -1, 25,
							Color(1, 1, 1, 0.88))
						lx += _face(false, 0).get_string_size(l, HORIZONTAL_ALIGNMENT_LEFT, -1, 25).x + 44.0
					continue
				var x := MARGIN
				var k := 0
				while x < width - MARGIN - 60.0:
					var sw := 60.0 + float((_h("nav%d" % k)) & 63)
					squiggle(ci, Vector2(x, rr.get_center().y), sw, 9.0, Color(1, 1, 1, 0.55), _h("nv%d" % k))
					x += sw + 34.0
					k += 1
			"squiggle":
				squiggle(ci, rr.position, rr.size.x, rr.size.y, d["col"], int(d["seed"]))
			"rule":
				ci.draw_rect(rr, ink.lerp(bg, 0.86))
			"label":
				ci.draw_string(_face(serif, 2) if bool(d.get("bold", false)) else _face(false, 0), d["pos"] + Vector2(0.0, dy), String(d["text"]),
					HORIZONTAL_ALIGNMENT_LEFT, -1, int(d["fs"]), d["col"])
			"image":
				_draw_image(ci, rr, d, textures)
			"search":
				_draw_search(ci, rr, String(d["query"]))
			"reply":
				_draw_reply(ci, rr)
			"chat":
				_draw_chat(ci, rr, d["chat"], now)
			"paid":
				var cv: Rect2 = d["cover"]
				_draw_paid(ci, rr, Rect2(cv.position + Vector2(0.0, dy), cv.size), d["chat"], now, sent)
			"cover":
				ci.draw_rect(rr, bg)
			"sound":
				_draw_sound(ci, rr, bool(state.get("sound", false)))
			"live":
				_pill(ci, rr, Color(0.86, 0.1, 0.1), Color(0.86, 0.1, 0.1))
				ci.draw_string(_face(false, 2), Vector2(rr.position.x, rr.get_center().y + 9.0), "LIVE", HORIZONTAL_ALIGNMENT_CENTER,
					rr.size.x, 24, Color.WHITE)
			"dot":
				ci.draw_circle(rr.get_center(), rr.size.x * 0.5, d["col"], true, -1.0, true)
			"card":
				ci.draw_rect(rr, Color.WHITE.lerp(bg, 0.5))
				ci.draw_rect(rr, ink.lerp(bg, 0.82), false, 2.0)
			"avatar":
				_draw_avatar(ci, rr, int(d["seed"]))
			"pager":
				_draw_pager(ci, rr, int(d["pages"]))
			"snap":
				var tex: Texture2D = textures.call(String(d["key"]))
				if tex != null:
					ci.draw_texture_rect(tex, rr, false)
				else:
					var f := face(false, 0)
					var c := Vector2(width * 0.5, clip_y0 + 260.0)
					ci.draw_string(face(false, 2), c - Vector2(width * 0.5, 0.0), "A real page, not captured yet",
						HORIZONTAL_ALIGNMENT_CENTER, width, 34, ink.lerp(bg, 0.4))
					ci.draw_string(f, c + Vector2(-width * 0.5, 56.0), String(d["url"]),
						HORIZONTAL_ALIGNMENT_CENTER, width, 26, accent)
					ci.draw_string(f, c + Vector2(-width * 0.5, 110.0), "Capture it, or import a screenshot, on the Pictures card.",
						HORIZONTAL_ALIGNMENT_CENTER, width, 22, ink.lerp(bg, 0.55))
			"foot":
				if not placeholders:
					# the footer runs to the screen's foot: a short page ends on it, never on blank page
					rr.size.y = maxf(rr.size.y, clip_y1 - rr.position.y)
				ci.draw_rect(rr, ink.lerp(bg, 0.93))
				if not placeholders:
					var fo := _face(false, 0)
					var site := String(d.get("site", ""))
					ci.draw_string(fo, rr.position + Vector2(MARGIN, 64.0), ("© %s" % site) if not site.is_empty() else "",
						HORIZONTAL_ALIGNMENT_LEFT, -1, 24, ink.lerp(bg, 0.45))
					ci.draw_string(fo, rr.position + Vector2(MARGIN, 108.0), "About  ·  Contact  ·  Privacy  ·  Terms",
						HORIZONTAL_ALIGNMENT_LEFT, -1, 22, ink.lerp(bg, 0.55))
					continue
				for j in 3:
					squiggle(ci, rr.position + Vector2(MARGIN, 40.0 + j * 34.0),
						width * (0.3 - j * 0.06), 8.0, ink.lerp(bg, 0.7), _h("foot%d" % j))


func _draw_word(ci: CanvasItem, d: Dictionary, dy: float, hl: Dictionary) -> void:
	var wi := int(d["wi"])
	var fs := int(d["fs"])
	var f := _face(serif, int(d["lvl"])) if not d.has("logo") else face(false, 2)
	var p: Vector2 = d["pos"] + Vector2(0.0, dy)
	var col: Color = d["col"]
	var text := String(script_doc["words"][wi]["text"])
	if d.has("logo"):
		# the engine's name in a run of colors, a letter at a time
		var x := p.x
		for c in text.length():
			var lc := Color.from_hsv(fposmod(_f("logo") + float(c) * 0.11, 1.0), 0.7, 0.85)
			ci.draw_string(f, Vector2(x, p.y), text[c], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, lc)
			x += f.get_string_size(text[c], HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		return
	# Every word is drawn glyph by glyph, lit or not, as the book does it: two drawing paths snap glyphs
	# to the pixel grid differently and the letters would jump as the color reached them. The color is
	# the book's: each letter its own hue by its place in the text, lit as the voice reaches it and
	# cooling back to ink behind it.
	var times: Dictionary = hl.get("times", {})
	var lit := times.has(wi)
	var cur := int(hl.get("cur", -1))
	var now := float(hl.get("now", 0.0))
	var frac := float(hl.get("frac", 0.0))
	var tt: Vector2 = times.get(wi, Vector2.ZERO)
	var c0 := 0
	if lit:
		var ch: PackedInt32Array = hl["char0"]
		c0 = ch[wi] if wi < ch.size() else 0
	var n := text.length()
	for gl in glyphs(f, text, fs):
		var k := int(gl["start"])
		var gc := col
		if lit:
			var at := (float(k) + 0.5) / float(maxi(n, 1))
			var g := 0.0
			if wi != cur:
				g = exp(-maxf(now - lerpf(tt.x, tt.y, at), 0.0) / BookMedium.TRAIL_TAU)
			elif at <= frac:
				g = exp(-maxf((frac - at) * maxf(tt.y - tt.x, 0.05), 0.0) / BookMedium.TRAIL_TAU)
			if g > 0.01:
				var ci_i := c0 + k
				var hue := fposmod(float(hl["hue0"]) + float(ci_i) * BookMedium.HUE_STEP, 1.0)
				var sw := 0.5 + 0.35 * sin(float(ci_i) * 0.21 - now * 0.9) \
					+ 0.15 * sin(float(ci_i) * 0.36 + now * 0.45)
				var sat := lerpf(0.45, 0.9, clampf(sw, 0.0, 1.0))
				gc = col.lerp(Color.from_hsv(hue, sat, 0.55), g)
		_ts.font_draw_glyph(gl["rid"], ci.get_canvas_item(), fs, p + (gl["pos"] as Vector2), int(gl["index"]), gc)
	if bool(d["link"]):
		ci.draw_line(p + Vector2(0.0, fs * 0.16), p + Vector2(float(d.get("ul", d["w"])), fs * 0.16), Color(col, 0.6), 2.0)


## A word's shaped glyphs, `[{index, rid, pos, start}]` - the book's [method BookMedium._glyphs],
## cached the same way.
static var _glyph_cache := {}
static var _ts: TextServer = TextServerManager.get_primary_interface()

static func glyphs(font: Font, text: String, fs: int) -> Array:
	var key := "%d|%d|%s" % [font.get_instance_id(), fs, text]
	if _glyph_cache.has(key):
		return _glyph_cache[key]
	var line := TextLine.new()
	line.add_string(text, font, fs)
	var out: Array = []
	var x := 0.0
	for g in _ts.shaped_text_get_glyphs(line.get_rid()):
		var gd: Dictionary = g
		for _r in maxi(1, int(gd.get("repeat", 1))):
			var off: Vector2 = gd.get("offset", Vector2.ZERO)
			if int(gd.get("index", 0)) != 0 or not gd.has("font_rid"):
				out.append({"index": int(gd.get("index", 0)), "rid": gd.get("font_rid", RID()),
					"pos": Vector2(x, 0.0) + off, "start": int(gd.get("start", 0))})
			x += float(gd.get("advance", 0.0))
	if _glyph_cache.size() > 20000:
		_glyph_cache = {}
	_glyph_cache[key] = out
	return out


func _draw_image(ci: CanvasItem, r: Rect2, d: Dictionary, textures: Callable) -> void:
	var tex: Texture2D = textures.call(String(d["key"])) if not String(d["key"]).is_empty() else null
	if tex == null:
		# Not yet painted: soft blobs of color, the picture's placeholder as squiggles are the writing's
		blobs(ci, r, int(d.get("seed", 0)))
		return
	var ts := Vector2(tex.get_size())
	var want := r.size.x / r.size.y
	var src := Rect2(Vector2.ZERO, ts)
	if ts.x / ts.y > want:
		src = Rect2((ts.x - ts.y * want) * 0.5, 0.0, ts.y * want, ts.y)
	else:
		src = Rect2(0.0, (ts.y - ts.x / want) * 0.5, ts.x, ts.x / want)
	ci.draw_texture_rect_region(tex, r, src)


var _box: StyleBoxFlat
var _pill_box: StyleBoxFlat


## Back (nothing before this page: grayed), the page numbers with this one marked, and Next.
func _draw_pager(ci: CanvasItem, r: Rect2, pages: int) -> void:
	const FS := 24
	const BW := 150.0
	var f := _face(false, 0)
	var fb := _face(false, 2)
	var cy := r.get_center().y
	var base := cy + FS * 0.36
	_pill(ci, Rect2(r.position.x, cy - 25.0, BW, 50.0), Color(0, 0, 0, 0), ink.lerp(bg, 0.86))
	ci.draw_string(f, Vector2(r.position.x, base), "‹  Back", HORIZONTAL_ALIGNMENT_CENTER, BW, FS,
		ink.lerp(bg, 0.7))
	_pill(ci, Rect2(r.end.x - BW, cy - 25.0, BW, 50.0), accent, accent)
	ci.draw_string(fb, Vector2(r.end.x - BW, base), "Next  ›", HORIZONTAL_ALIGNMENT_CENTER, BW, FS,
		Color.WHITE)
	var labels := ["1", "2", "3", "…", str(pages)]
	const STEP := 50.0
	var x0 := r.get_center().x - STEP * float(labels.size() - 1) * 0.5
	for k in labels.size():
		var c := Vector2(x0 + STEP * k, cy)
		if k == 0:
			ci.draw_circle(c, 20.0, accent, true, -1.0, true)
		ci.draw_string(fb if k == 0 else f, Vector2(c.x - STEP * 0.5, base), labels[k],
			HORIZONTAL_ALIGNMENT_CENTER, STEP, FS - 2, Color.WHITE if k == 0 else ink.lerp(bg, 0.4))


func _pill(ci: CanvasItem, r: Rect2, fill: Color, border: Color) -> void:
	if _pill_box == null:
		_pill_box = StyleBoxFlat.new()
		_pill_box.anti_aliasing = true
		_pill_box.set_border_width_all(2)
	_pill_box.bg_color = fill
	_pill_box.border_color = border
	_pill_box.set_corner_radius_all(int(r.size.y * 0.5))
	ci.draw_style_box(_pill_box, r)

func _draw_search(ci: CanvasItem, r: Rect2, query: String) -> void:
	if _box == null:
		_box = StyleBoxFlat.new()
	var sb := _box
	sb.bg_color = Color.WHITE
	sb.border_color = ink.lerp(bg, 0.7)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(int(r.size.y * 0.5))
	sb.anti_aliasing = true
	sb.shadow_color = Color(0, 0, 0, 0.08)
	sb.shadow_size = 6
	ci.draw_style_box(sb, r)
	var c := Vector2(r.position.x + 40.0, r.get_center().y)
	ci.draw_arc(c - Vector2(2, 2), 11.0, 0.0, TAU, 24, ink.lerp(bg, 0.45), 3.0, true)
	ci.draw_line(c + Vector2(6, 6), c + Vector2(14, 14), ink.lerp(bg, 0.45), 3.5, true)
	if not query.is_empty():
		ci.draw_string(_face(false, 0), Vector2(r.position.x + 74.0, r.get_center().y + 11.0), query,
			HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 100.0, 30, ink)


## The message box, empty: what it asks for, and its Send.
func _draw_reply(ci: CanvasItem, r: Rect2) -> void:
	_pill(ci, r, Color.WHITE, ink.lerp(bg, 0.7))
	ci.draw_string(_face(false, 0), Vector2(r.position.x + 28.0, r.get_center().y + 11.0), "Say something…",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 30, ink.lerp(bg, 0.6))
	var send := Rect2(r.end.x - 150.0, r.position.y + 10.0, 140.0, r.size.y - 20.0)
	_pill(ci, send, accent, accent)
	ci.draw_string(_face(false, 2), Vector2(send.position.x, send.get_center().y + 9.0), "Send", HORIZONTAL_ALIGNMENT_CENTER,
		send.size.x, 26, Color.WHITE)


## A picture nobody painted: a pale wash with a few soft overlapping blobs of related colors, the shape
## of a photograph's color and none of its content. Painted small and stretched so the blobs blur
## smoothly. Deterministic in [param seed].
static func blobs(ci: CanvasItem, r: Rect2, seed: int) -> void:
	var key := "%d|%d" % [seed, int(r.size.x / r.size.y * 100.0)]
	if not _blob_cache.has(key):
		if _blob_cache.size() > 64:
			_blob_cache = {}
		_blob_cache[key] = ImageTexture.create_from_image(_blob_image(r.size, seed))
	ci.draw_texture_rect(_blob_cache[key], r, false)


static var _blob_cache := {}
const BLOB_W := 96

static func _blob_image(size: Vector2, seed: int) -> Image:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var w := BLOB_W
	var h := maxi(8, int(BLOB_W * size.y / size.x))
	var hue := rng.randf()
	var wash := Color.from_hsv(hue, 0.12, 0.95)
	var span := float(mini(w, h))
	var blobs: Array = []
	for b in rng.randi_range(4, 6):
		# neighboring hues, so the blobs belong together (a complement muddies where they meet)
		var hh := fposmod(hue + rng.randf_range(-0.16, 0.16), 1.0)
		blobs.append({"col": Color.from_hsv(hh, rng.randf_range(0.4, 0.65), rng.randf_range(0.72, 0.92)),
			"c": Vector2(rng.randf_range(-0.1, 1.1) * w, rng.randf_range(-0.1, 1.1) * h),
			"r": span * rng.randf_range(0.35, 0.7),
			"s": Vector2(rng.randf_range(0.8, 1.5), rng.randf_range(0.7, 1.2)),
			"p": [rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU],
			"a": rng.randf_range(0.7, 0.9)})
	var img := Image.create(w, h, false, Image.FORMAT_RGB8)
	for y in h:
		for x in w:
			var col := wash
			for bl in blobs:
				var v: Vector2 = (Vector2(x, y) - bl["c"]) / bl["s"]
				var ang := v.angle()
				var ph: Array = bl["p"]
				var rr: float = bl["r"] * (1.0 + 0.16 * sin(ang + ph[0]) + 0.09 * sin(2.0 * ang + ph[1])
					+ 0.05 * sin(3.0 * ang + ph[2]))
				var k := 1.0 - smoothstep(0.15, 1.0, v.length() / rr)
				if k > 0.0:
					col = col.lerp(bl["col"], k * float(bl["a"]))
			img.set_pixel(x, y, col)
	return img


## A line of placeholder writing: wavy strokes in runs the length of words, so it has the
## shape of text and none of its content. Deterministic in [param seed].
static func squiggle(ci: CanvasItem, at: Vector2, w: float, h: float, col: Color, seed: int) -> void:
	var r := RandomNumberGenerator.new()
	r.seed = seed
	var x := 0.0
	var amp := h * 0.42
	while x < w - 8.0:
		var run := minf(r.randf_range(34.0, 130.0) * (h / 10.0 if h > 10.0 else 1.0), w - x)
		if run < 12.0:
			break
		var pts := PackedVector2Array()
		var ph := r.randf() * TAU
		var fq := r.randf_range(0.16, 0.26) * (10.0 / maxf(h, 6.0))
		var steps := maxi(3, int(run / 5.0))
		for i in steps + 1:
			var px := x + run * float(i) / float(steps)
			var env := sin(PI * float(i) / float(steps)) * 0.4 + 0.6
			pts.append(at + Vector2(px, sin(px * fq + ph) * amp * env))
		ci.draw_polyline(pts, col, maxf(2.0, h * 0.42), true)
		x += run + r.randf_range(12.0, 20.0) * maxf(1.0, h / 12.0)
