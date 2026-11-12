extends RefCounted
class_name BookLayout

## BookLayout - a chapter typeset into the pages of a printed novel, for [BookMedium].
##
## The whole chapter is set once, up front, into pages of a fixed trim; the narration is then
## followed across them by a highlight. A small typesetter that knows nothing of audio, cameras or
## 3D: its output is plain data (word boxes, image rects, labels) that [BookMedium.PageCanvas]
## draws and the highlight indexes into.
##
## Justified paragraphs with a first-line indent (none after a heading, scene line or picture),
## scene lines centered in italics, the chapter title sunk down the opening page, folios at the
## foot, inline pictures as half-page bands, full-page pictures on a page of their own while the
## text flows past.
##
## Page space is pixels on a [constant PAGE]-sized sheet, y down. Page i is the left page of
## spread i/2 when i is even and the right one when odd, so the inner (spine) margin faces the
## other page.

const PAGE := Vector2(1100, 1650)
const MARGIN_TOP := 138.0
const MARGIN_BOTTOM := 176.0
const MARGIN_INNER := 116.0
const MARGIN_OUTER := 128.0
const BODY_FS := 33
## Line pitch as a multiple of the body size.
const LEADING := 1.46
## No first-line indent: a paragraph is marked by the blank line alone (PARA_GAP). Above 0 indents.
const INDENT_EM := 0.0
## A blank line between paragraphs.
const PARA_GAP := 1.0
## How far justification may stretch a space before a line is set ragged instead (avoids two
## words at the margins with a river between them beside a picture).
const MAX_STRETCH := 2.6
## ...and how far a space may tighten to take one more word, as a share of its width.
const SQUEEZE := 0.2
const TITLE_FS := 60
const TITLE_SINK := 300.0
const FOLIO_FS := 22
## An image with no picture yet is typeset at this aspect (width / height).
const DEFAULT_ASPECT := 4.0 / 3.0

## The serif families asked for, best first. SystemFont walks the list, so a machine with none of
## them gets DejaVu or FreeSerif rather than the UI sans.
const SERIFS := ["EB Garamond", "Crimson Pro", "Crimson Text", "Libre Baskerville", "Literata",
	"Source Serif 4", "Georgia", "Palatino Linotype", "Noto Serif", "Liberation Serif",
	"DejaVu Serif", "FreeSerif", "serif"]

## `[{side, kind, words: [int], images: [{rect, key, prompt, full}], labels: [{text, pos, fs,
## emph, align_w}], folio}]` - `kind` is "text", "image" or "blank".
var pages: Array = []
## Every word of the chapter in reading order: `{page, rect, base, text, norm, emph, fs}`.
## `base` is the baseline origin draw_string wants; `rect` is the box a highlight covers.
var words: Array = []
var title := ""
## The body size. A variable so a layout in another hand ([NotebookLayout]) can set its own.
var body_fs := BODY_FS
## Whose voice reads the block being set; every word records it (a notebook inks by it).
var _speaker := ""

var _faces := {}
var _p := -1                 # the page being filled
var _y := 0.0
var _floats: Array = []      # Rect2 on the current page that text must avoid
var _pending_full: Array = []
var _pending_float: Array = []
var _images_at := Callable()
var _norm_re: RegEx
var _hes_re: RegEx


## The face for an emphasis level (0 plain, 1 italic, 2 bold, 3 both): real faces where the
## system has them, found by SystemFont's own flags.
func face(level: int) -> Font:
	if _faces.has(level):
		return _faces[level]
	var f := SystemFont.new()
	f.font_names = PackedStringArray(SERIFS)
	f.font_italic = (level & 1) != 0
	f.font_weight = 700 if (level & 2) != 0 else 400
	f.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	f.hinting = TextServer.HINTING_LIGHT
	f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_AUTO
	_faces[level] = f
	return f


## Normalized spelling for matching spoken words to printed ones: lower case, letters and
## digits only, so quotes, dashes and apostrophes never decide a match.
func norm(s: String) -> String:
	if _norm_re == null:
		_norm_re = RegEx.new()
		_norm_re.compile("[^\\p{L}\\p{N}]")
	return _norm_re.sub(s.to_lower(), "", true)


## Typeset [param source] (a chapter's markdown). [param image_size] answers the pixel size
## of a picture key, or Vector2.ZERO when there is none yet.
##
## [param title_override] is the chapter title when [param source] has no frontmatter of its
## own - which is how a document arrives from the Generative panel in sync mode.
func build(source: String, image_size: Callable, title_override := "") -> void:
	_images_at = image_size
	_hes_re = RegEx.new()
	_hes_re.compile(Manuscript.HESITATION)
	pages = []
	words = []
	_pending_full = []
	_pending_float = []
	title = title_override if not title_override.is_empty() else _title_of(source)
	var blocks: Array = Manuscript.blocks(source)
	# Page 0 is the left of the first spread and a chapter opens on the right: an opening full-page
	# picture takes that page as a frontispiece; otherwise the left page is the blank verso.
	var first := 0
	if not blocks.is_empty() and String(blocks[0]["kind"]) == "image" \
			and String(blocks[0].get("placement", "")) == "full":
		_image_page(blocks[0])
		first = 1
	else:
		_blank_page()
	_open_page(true)
	var no_indent := true
	if not title.is_empty():
		_title_block()
	for bi in range(first, blocks.size()):
		var b: Dictionary = blocks[bi]
		_speaker = String(b.get("speaker", ""))
		match String(b["kind"]):
			"heading":
				_space(0.6)
				_heading(String(b["text"]), int(b.get("level", 1)))
				no_indent = true
			"rule":
				# A section break: the quiet ornament under the chapter title, one blank line either side
				# (the next paragraph adds its own); never alone at the foot of a page, so it goes to the next.
				_rule()
				no_indent = true
			"image":
				if String(b.get("placement", "")) == "sketch":
					_sketch(b)
				elif String(b.get("placement", "")) == "full":
					_pending_full.append(b)
					# A picture that opens a scene comes first, as a section break does: when little of the page is
					# left, the page ends here and the picture takes the next; otherwise the text runs on and the
					# picture follows at the next page turn.
					if _y > _top() + 1.0 and _bottom() - _y < (_bottom() - _top()) * 0.45:
						_open_page()
				else:
					_float(b)
				no_indent = true
			"para":
				var text := String(b["text"])
				if Manuscript.is_scene_line(text):
					# Kept with what follows: a scene line alone at the foot of a page would open a scene on the next.
					if _y + _lh(body_fs) * 4.2 > _bottom():
						_open_page()
					# One blank line above and below; the next paragraph adds its own PARA_GAP.
					_space(PARA_GAP)
					_paragraph(text, false, true)
					no_indent = true
				else:
					_space(PARA_GAP)
					_paragraph(text, not no_indent, false)
					no_indent = false
	# Pictures still owed at the end get their pages, and a lone last page gets a facing one.
	while not _pending_full.is_empty():
		_image_page(_pending_full.pop_front())
	if pages.size() % 2 == 1:
		_blank_page()
	_finish()


func spreads() -> int:
	return pages.size() / 2


static func _title_of(source: String) -> String:
	return FrontMatter.field_of(source, "title")


# --- pages ------------------------------------------------------------------

func _side(p: int) -> int:
	return p % 2


## The text block's horizontal extent on page [param p]: the inner margin faces the spine.
func column(p: int) -> Vector2:
	if _side(p) == 0:
		return Vector2(MARGIN_OUTER, PAGE.x - MARGIN_INNER)
	return Vector2(MARGIN_INNER, PAGE.x - MARGIN_OUTER)


func _new_page(kind: String) -> Dictionary:
	var pg := {"side": pages.size() % 2, "kind": kind, "words": [], "images": [],
		"labels": [], "folio": pages.size() + 1}
	pages.append(pg)
	return pg


func _blank_page() -> void:
	var pg := _new_page("blank")
	pg["folio"] = 0


## A page given wholly to a picture: a plate inset from the trim, the picture cropped to fill it.
func _image_page(b: Dictionary) -> void:
	var pg := _new_page("image")
	pg["folio"] = 0
	var inset := 74.0
	pg["images"].append({"rect": Rect2(Vector2(inset, inset), PAGE - Vector2(inset, inset) * 2.0),
		"key": String(b.get("key", "")), "prompt": String(b.get("prompt", "")), "full": true})


## Open a fresh text page, first paying any full-page pictures owed. A picture waits for a page on
## its preferred side, but never more than one page.
func _open_page(first := false) -> void:
	if not first:
		var waited := 0
		while not _pending_full.is_empty():
			var b: Dictionary = _pending_full[0]
			var want := 0 if String(b.get("side", "right")) == "left" else 1
			if pages.size() % 2 == want or waited >= 1:
				_image_page(_pending_full.pop_front())
				waited = 0
			else:
				break
			waited += 1
	_new_page("text")
	_p = pages.size() - 1
	_y = _top()
	_floats = []
	var owed := _pending_float
	_pending_float = []
	for b in owed:
		_float(b)


## Where a text page's first line starts.
func _top() -> float:
	return MARGIN_TOP


func _bottom() -> float:
	return PAGE.y - MARGIN_BOTTOM


func _lh(fs: int) -> float:
	return float(fs) * LEADING


func _space(lines: float) -> void:
	if _y > _top() + 1.0:
		_y += _lh(body_fs) * lines


## The free span of the text block for a line whose box is [y0, y1]: the column minus any
## float it runs beside.
func _span_at(y0: float, y1: float) -> Vector2:
	var c := column(_p)
	for r in _floats:
		var rr: Rect2 = r
		if y1 <= rr.position.y or y0 >= rr.end.y:
			continue
		if rr.get_center().x > (c.x + c.y) * 0.5:
			c.y = minf(c.y, rr.position.x)
		else:
			c.x = maxf(c.x, rr.end.x)
	return c


# --- blocks -----------------------------------------------------------------

func _title_block() -> void:
	var pg: Dictionary = pages[_p]
	var f := face(0)
	var c := column(_p)
	var fs := TITLE_FS
	# The title is set in one line if it fits and shrinks to fit if it does not.
	while fs > 30 and f.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > c.y - c.x:
		fs -= 2
	var y := MARGIN_TOP + TITLE_SINK
	# Words, not a label: the title is read aloud first, and the highlight follows it.
	_y = y - _lh(fs) * 0.72
	_set_line_words(title, fs, 0, true)
	y = _y - _lh(fs) * 0.28
	pg["labels"].append({"text": "~", "pos": Vector2(c.x, y + fs * 1.1), "fs": body_fs, "emph": 0,
		"align_w": c.y - c.x, "tone": 0.55})
	_y = y + fs * 1.1 + _lh(body_fs) * 2.2


## A section break: the ornament under the chapter title with one blank line either side (the
## next paragraph adds its own). Never alone at the foot of a page: it goes to the next one.
func _rule() -> void:
	if _y + _lh(body_fs) * 3.0 > _bottom():
		_open_page()
	_space(PARA_GAP)
	_label_centered("~", body_fs, 0.55)


func _heading(text: String, level: int) -> void:
	var fs := int(body_fs * (1.5 if level <= 1 else 1.25))
	_keep_with_next(_lh(fs))
	_set_line_words(text, fs, 0, true, {"heading": true})
	_y += _lh(body_fs) * 0.4


## A heading is kept with what it heads: set only where the gap after it and two lines of its
## text fit below it on the same page, else it opens the next. [param h] is the heading's height.
## "Fit" means room a line can use: a picture band across the lower page leaves the height but
## not the width.
func _keep_with_next(h: float) -> void:
	var lh := _lh(body_fs)
	var y := _y + h + lh * PARA_GAP
	for _k in 2:
		var span := _span_at(y, y + lh)
		if y + lh > _bottom() or span.y - span.x < float(body_fs) * 5.0:
			_open_page()
			return
		y += lh


func _label_centered(text: String, fs: int, tone := 0.8) -> void:
	if _y + _lh(fs) > _bottom():
		_open_page()
	var c := column(_p)
	_y += _lh(fs)
	(pages[_p]["labels"] as Array).append({"text": text, "pos": Vector2(c.x, _y - _lh(fs) * 0.28),
		"fs": fs, "emph": 0, "align_w": c.y - c.x, "tone": tone})


## An inline picture as a half-page band: the full width of the text block and about half its
## height, at the foot of the page it belongs to if there is room below the text already set,
## else at the head of the next page. One band a page, so a page is never all picture.
const BAND_H := 0.46
const BAND_GAP := 34.0

func _float(b: Dictionary) -> void:
	var c := column(_p)
	var w := c.y - c.x
	var h := (_bottom() - _top()) * BAND_H
	if not _floats.is_empty():
		_pending_float.append(b)
		return
	var at_top := _y <= _top() + 1.0
	var top := _top()
	if at_top:
		_y = _top() + h + BAND_GAP
	elif _bottom() - h - BAND_GAP - _y >= _lh(body_fs) * 2.0:
		top = _bottom() - h
	else:
		_pending_float.append(b)
		return
	var rect := Rect2(c.x, top, w, h)
	(pages[_p]["images"] as Array).append({"rect": rect, "key": String(b.get("key", "")),
		"prompt": String(b.get("prompt", "")), "full": false, "sketch": bool(b.get("sketch", false))})
	# The band keeps text off itself and its gutter; text above a foot band flows to the next page.
	_floats.append(rect.grow_individual(0.0, 0.0 if at_top else BAND_GAP, 0.0,
		BAND_GAP if at_top else 0.0))


## Inline markdown -> `[{text, emph}]`. Asterisks and edge underscores toggle emphasis and are
## never printed; hesitation marks are dropped (heard, not read); a macro prints its default,
## as it is spoken.
func tokens(text: String) -> Array:
	text = _hes_re.sub(text, " ", true)
	text = TextNorm._expand_macros(text)
	var out: Array = []
	var state := 0
	for raw in text.split(" ", false):
		var tok := String(raw)
		var clean := ""
		var em := -1
		var n := tok.length()
		var i := 0
		while i < n:
			var ch := tok[i]
			if ch == "*":
				var r := 1
				while i + r < n and tok[i + r] == "*":
					r += 1
				state ^= (1 if r == 1 else (2 if r == 2 else 3))
				i += r
				continue
			if ch == "_" and (clean.is_empty() or i == n - 1 or not _is_wordy(tok, i)):
				state ^= 1
				i += 1
				continue
			if em < 0:
				em = state
			clean += ch
			i += 1
		if clean.is_empty():
			continue
		out.append({"text": clean, "emph": maxi(em, 0)})
	return out


## True when the underscore at [param i] sits between two word characters (snake_case),
## which is text rather than markup.
func _is_wordy(tok: String, i: int) -> bool:
	if i <= 0 or i >= tok.length() - 1:
		return false
	return tok[i - 1].is_valid_identifier() and tok[i + 1].is_valid_identifier()


## Set one paragraph. Greedy line fill against the free span at each line, justified except
## the last line; a scene line is centered and italic.
func _paragraph(text: String, indent: bool, scene: bool) -> void:
	var toks := tokens(text)
	if toks.is_empty():
		return
	var fs := body_fs
	var lh := _lh(fs)
	var sp := face(0).get_string_size(" ", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var widths: Array = []
	for t in toks:
		widths.append(face(int(t["emph"])).get_string_size(String(t["text"]),
			HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x)
	var i := 0
	var first := true
	# A lead-IN set in the margin beside the first line (a notebook's timestamp), read first.
	var lead := _margin_lead(toks)
	while i < toks.size():
		if _y + lh > _bottom():
			_open_page()
		var span := _span_at(_y, _y + lh)
		if lead > 0:
			_set_margin(toks, widths, lead, _baseline(_y, lh), fs, lh)
			i = lead
			lead = 0
		var x0 := span.x + (float(fs) * INDENT_EM if (first and indent) else 0.0)
		var avail := span.y - x0
		# Too narrow to set a line beside a float: drop below it.
		if avail < float(fs) * 5.0:
			_y += lh * 0.5
			continue
		var j := i
		var used := 0.0
		while j < toks.size():
			var add := float(widths[j]) + (sp if j > i else 0.0)
			# A word that fits once the line's spaces tighten a little goes on this line.
			if j > i and used + add - float(j - i) * sp * SQUEEZE > avail:
				break
			used += add
			j += 1
		var last := j >= toks.size()
		var gap := sp
		if used > avail and j - i > 1:
			gap = sp - (used - avail) / float(j - i - 1)
			used = avail
		elif not last and not scene and j - i > 1 and _justify():
			var stretch := (avail - used) / float(j - i - 1)
			if stretch + sp <= sp * MAX_STRETCH:
				gap = sp + stretch
		var x := x0
		if scene:
			x = span.x + (span.y - span.x - used) * 0.5
		var base_y := _baseline(_y, lh)
		for k in range(i, j):
			var t: Dictionary = toks[k]
			var w := float(widths[k])
			var em := int(t["emph"]) | (1 if scene else 0)
			if scene and em != int(t["emph"]):
				w = face(em).get_string_size(String(t["text"]), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			var off := _ink_offset(words.size(), _y, x - x0)
			words.append({"page": _p, "text": String(t["text"]), "norm": norm(String(t["text"])),
				"emph": em, "fs": fs, "base": Vector2(x, base_y) + off, "speaker": _speaker,
				"rect": Rect2(x + off.x, _y + lh * 0.08 + off.y, w, lh * 0.86)})
			(pages[_p]["words"] as Array).append(words.size() - 1)
			x += w + gap
		_y += lh
		i = j
		first = false


## Set [param text] as words on lines of its own, centered or from the column's left edge. A
## heading is spoken, so it has to be words the reading highlight can follow, not a label.
## [param extra] is merged into every word (a notebook marks its headings underlined).
func _set_line_words(text: String, fs: int, emph: int, center: bool, extra := {}) -> void:
	var toks := tokens(text)
	if toks.is_empty():
		return
	var lh := _lh(fs)
	var sp := face(emph).get_string_size(" ", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var widths: Array = []
	for t in toks:
		widths.append(face(emph | int(t["emph"])).get_string_size(String(t["text"]),
			HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x)
	var i := 0
	while i < toks.size():
		if _y + lh > _bottom():
			_open_page()
		var c := column(_p)
		var j := i
		var used := 0.0
		while j < toks.size():
			var add := float(widths[j]) + (sp if j > i else 0.0)
			if j > i and used + add > c.y - c.x:
				break
			used += add
			j += 1
		var x0 := c.x + ((c.y - c.x - used) * 0.5 if center else 0.0)
		var x := x0
		var base_y := _baseline(_y, lh)
		for k in range(i, j):
			var t: Dictionary = toks[k]
			var w := float(widths[k])
			var off := _ink_offset(words.size(), _y, x - x0)
			var wd := {"page": _p, "text": String(t["text"]), "norm": norm(String(t["text"])),
				"emph": emph | int(t["emph"]), "fs": fs, "base": Vector2(x, base_y) + off,
				"speaker": _speaker,
				"rect": Rect2(x + off.x, _y + lh * 0.08 + off.y, w, lh * 0.86)}
			wd.merge(extra)
			words.append(wd)
			(pages[_p]["words"] as Array).append(words.size() - 1)
			x += w + sp
		_y += lh
		i = j


# --- hooks a layout in another hand overrides ------------------------------------------

## Everything is set. A layout with something to work out from the finished pages does it here.
func _finish() -> void:
	pass


## A drawing made on the page. A printed book has no hand to make one, so it is set like any
## inline picture; [NotebookLayout] draws it into the writing.
func _sketch(b: Dictionary) -> void:
	_float(b)


## Justify every line but a paragraph's last. Print does; handwriting does not.
func _justify() -> bool:
	return true


## The baseline of a line whose box starts at [param y] and is [param lh] tall.
func _baseline(y: float, lh: float) -> float:
	return y + lh * 0.72


## How far word [param _i] strays from where the typesetter put it, [param _dx] along its
## line. Type does not stray.
func _ink_offset(_i: int, _line_y: float, _dx: float) -> Vector2:
	return Vector2.ZERO


## How many of a paragraph's opening tokens are set in the margin rather than the column. None,
## in a book.
func _margin_lead(_toks: Array) -> int:
	return 0


## Set tokens [0, n) of a paragraph in the margin beside its first line, appending them to
## [member words]. Only reached when [method _margin_lead] answers more than 0.
func _set_margin(_toks: Array, _widths: Array, _n: int, _base_y: float, _fs: int, _lh: float) -> void:
	pass
