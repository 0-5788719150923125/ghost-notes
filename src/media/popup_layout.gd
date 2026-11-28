extends BookLayout
class_name PopupLayout

## PopupLayout - a chapter set as a pop-up book, one scene a spread, for [PopupMedium].
##
## A scene opens at a picture mark that follows words (the chapter's first marks open the first): its pop-ups
## (`<!-- popup: -->`) stand on that spread ([member pieces], farthest back first, at most [constant MOST_PIECES]), its
## picture (`<!-- image: -->`) stands behind them as the scenery ([member backs]), a floor (`<!-- image (floor): -->`,
## seen from above) is printed across the top of both pages under them, and its words are set below, split over
## the two pages at the line nearest half their height. Words that outrun a spread go on to one with nothing standing.
## The chapter title heads the first spread's words. What follows the unread line ([method Manuscript.unread_part]) is
## set smaller on spreads of its own at the back ([member back_from]): never read, so never followed.
##
## Page space is the book's ([constant BookLayout.PAGE]); a spread is pages 2s and 2s + 1.

## Where a scene's words start, as a share of the page's height: above is the pop-up's and the printed picture's.
const TEXT_TOP := 0.62
## The words' size on a scene's pages, the title's, and the back matter's.
const POPUP_FS := 38
const POPUP_TITLE_FS := 58
const BACK_FS := 23
## A printed picture ends this far above the words.
const ART_GAP := 46.0
## Pop-ups one spread stands: more would not fold flat inside it.
const MOST_PIECES := 3
## A scene of at most this many lines keeps them all on its left page.
const SPLIT_LEAST := 5

## Per spread, what stands on it: `[{key, prompt}]`, farthest back first; [] for a spread with none.
var pieces: Array = []
## Per spread, the scenery standing behind its pieces: `{key, prompt}`, or {} for none.
var backs: Array = []
## Per spread, the scene it shows (its index among the scenes), or -1 (words run on, or the back).
var scene_of: Array = []
## Per spread, the script's brief for it (`<!-- spread: -->`, what its paper engineer makes in layers), "" for none.
var briefs: Array = []
## The first spread of back matter (what follows the unread line), or -1 for none.
var back_from := -1
## How many of the first words are the title's: the story's own words begin after them.
var title_words := 0

var _limit := 0.0            # where the line being set must end: the split, or the page's foot
var _text_top := 0.0
var _back := false


func build(source: String, image_size: Callable, title_override := "") -> void:
	_images_at = image_size
	_hes_re = RegEx.new()
	_hes_re.compile(Manuscript.HESITATION)
	pages = []
	words = []
	pieces = []
	backs = []
	scene_of = []
	briefs = []
	back_from = -1
	_back = false
	body_fs = POPUP_FS
	title = title_override if not title_override.is_empty() else _title_of(source)
	var scenes := scenes_of(_take_cover(Manuscript.blocks(Manuscript.read_part(source))))
	title_words = tokens(title).size() if not title.is_empty() else 0
	if scenes.is_empty():
		scenes = [{"art": [], "pops": [], "brief": [], "text": []}]
	for i in scenes.size():
		_scene(scenes[i], i == 0, i)
	var back := Manuscript.blocks(Manuscript.unread_part(source))
	if not back.is_empty():
		_back_matter(back)
	_finish()


## [param blocks] ([method Manuscript.blocks]) as scenes: `[{art, pops, brief, text}]`. A picture mark after words opens the
## next scene; a pop-up is one of its `pops`, a spread's brief its `brief`, any other picture its `art`.
static func scenes_of(blocks: Array) -> Array:
	var out: Array = []
	var cur := {}
	for b in blocks:
		var kind := String((b as Dictionary)["kind"])
		if kind == "image":
			if cur.is_empty() or not (cur["text"] as Array).is_empty():
				cur = {"art": [], "pops": [], "brief": [], "text": []}
				out.append(cur)
			(cur["pops" if bool(b.get("popup", false)) else ("brief" if bool(b.get("brief", false)) else "art")] as Array).append(b)
			continue
		if cur.is_empty():
			cur = {"art": [], "pops": [], "brief": [], "text": []}
			out.append(cur)
		(cur["text"] as Array).append(b)
	return out


func spreads() -> int:
	return pages.size() / 2


# --- a scene's spread ------------------------------------------------------------

func _scene(sc: Dictionary, first: bool, index: int) -> void:
	var s := _spread_open()
	scene_of[s] = index
	var brief: Array = sc.get("brief", [])
	briefs[s] = String((brief[0] as Dictionary)["prompt"]) if not brief.is_empty() else ""
	var pops: Array = sc["pops"]
	if pops.size() > MOST_PIECES:
		push_warning("ghost: a pop-up spread stands %d pop-ups at most; %d are left lying" % [MOST_PIECES,
			pops.size() - MOST_PIECES])
	var stand: Array = []
	for b in pops.slice(0, MOST_PIECES):
		stand.append({"key": String(b["key"]), "prompt": String(b["prompt"])})
	pieces[s] = stand
	var art: Array = sc["art"]
	var floor: Array = art.filter(func(b: Dictionary) -> bool: return String(b.get("placement", "")) == "floor")
	var scenery: Array = art.filter(func(b: Dictionary) -> bool: return String(b.get("placement", "")) != "floor")
	if not scenery.is_empty():
		backs[s] = {"key": String(scenery[0]["key"]), "prompt": String(scenery[0]["prompt"])}
	if not floor.is_empty():
		var b: Dictionary = floor[0]
		var h := PAGE.y * TEXT_TOP - ART_GAP
		for side in 2:
			(pages[s * 2 + side]["images"] as Array).append({"rect": Rect2(0.0, 0.0, PAGE.x, h),
				"key": String(b.get("key", "")), "prompt": String(b.get("prompt", "")), "full": false, "span": side,
				"sketch": bool(b.get("sketch", false))})
	# Measured on one endless column, then set again split at the line nearest half its height.
	var split := _split_at(_measure(sc, first))
	_limit = split
	_set_text(sc, first)


## Open the next spread at its left page, its right page made beside it; the words start at the top of the text.
func _spread_open() -> int:
	if pages.size() % 2 == 1:
		_new_page("blank")
	_new_page("text")
	_new_page("text")
	pieces.append([])
	backs.append({})
	scene_of.append(-1)
	briefs.append("")
	_p = pages.size() - 2
	_y = _top()
	_limit = _page_foot()
	_floats = []
	return pages.size() / 2 - 1


## The scene's words (and the title, on the first) as set from where the column stands.
func _set_text(sc: Dictionary, first: bool) -> void:
	var no_indent := true
	if first and not title.is_empty():
		var f := face(0)
		var c := column(_p)
		var fs := POPUP_TITLE_FS
		while fs > 30 and f.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > c.y - c.x:
			fs -= 2
		# Words, not a label: the title is read first, and the highlight follows it.
		_set_line_words(title, fs, 0, true)
		_y += _lh(body_fs) * 0.35
	for b in sc["text"]:
		_speaker = String(b.get("speaker", ""))
		match String(b["kind"]):
			"heading":
				_space(0.4)
				_heading(String(b["text"]), int(b.get("level", 1)))
				no_indent = true
			"rule":
				_rule()
				no_indent = true
			"para":
				_space(PARA_GAP * 0.6)
				_paragraph(String(b["text"]), not no_indent, Manuscript.is_scene_line(String(b["text"])))
				no_indent = false


## Every line of the scene as set on one endless column from the top of the text: `[[top, bottom], ...]`, nothing kept.
func _measure(sc: Dictionary, first: bool) -> Array:
	var w0 := words.size()
	var pg: Dictionary = pages[_p]
	var pw0 := (pg["words"] as Array).size()
	var pl0 := (pg["labels"] as Array).size()
	var y0 := _y
	_limit = INF
	_set_text(sc, first)
	var lines: Array = []
	for i in range(w0, words.size()):
		var w: Dictionary = words[i]
		var lh := _lh(int(w["fs"]))
		var top := (w["rect"] as Rect2).position.y - lh * 0.08
		if lines.is_empty() or absf(float((lines[lines.size() - 1] as Array)[0]) - top) > 1.0:
			lines.append([top, top + lh])
	words.resize(w0)
	pg["words"] = (pg["words"] as Array).slice(0, pw0)
	pg["labels"] = (pg["labels"] as Array).slice(0, pl0)
	_y = y0
	_p = pages.size() - 2
	return lines


## Where the left page's words end so the two pages hold about as much: just past a line near half the scene's
## height - the end of a paragraph where one falls within a quarter of it, else the line whose foot is nearest. A scene
## of a few lines is never split (one line a page reads as a mistake): its words stay on the left page.
func _split_at(lines: Array) -> float:
	if lines.size() <= SPLIT_LEAST:
		return _page_foot()
	var top := float((lines[0] as Array)[0])
	var height := float((lines[lines.size() - 1] as Array)[1]) - top
	var half := height * 0.5
	var best := 0
	var best_para := -1
	for i in lines.size() - 1:
		var off := absf(float((lines[i] as Array)[1]) - top - half)
		if off < absf(float((lines[best] as Array)[1]) - top - half):
			best = i
		# a paragraph ends where the next line starts after a gap
		var ends := float((lines[i + 1] as Array)[0]) > float((lines[i] as Array)[1]) + 1.0
		if ends and off <= height * 0.25 and (best_para < 0
				or off < absf(float((lines[best_para] as Array)[1]) - top - half)):
			best_para = i
	var at := best_para if best_para >= 0 else best
	return minf(float((lines[at] as Array)[1]) + 0.5, _page_foot())


## Words past the left page's split go to the right page; past the right page's foot, to a spread with nothing standing.
func _open_page(_first := false) -> void:
	if _p % 2 == 0 and _p + 1 < pages.size():
		_p += 1
	else:
		_spread_open()
	_y = _top()
	_limit = _page_foot()


# --- the back --------------------------------------------------------------------

## What follows the unread line, on spreads of its own, smaller and set ragged from the top margin.
func _back_matter(blocks: Array) -> void:
	_back = true
	body_fs = BACK_FS
	back_from = _spread_open()
	for b in blocks:
		_speaker = String(b.get("speaker", ""))
		match String(b["kind"]):
			"heading":
				_space(0.6)
				_heading(String(b["text"]), int(b.get("level", 1)))
			"rule":
				_rule()
			"para":
				_space(PARA_GAP * 0.7)
				_paragraph(String(b["text"]), false, false)
			"image":
				pass


## A word too wide for the column (a source's address) is broken after a slash, dot or dash, so it wraps.
func tokens(text: String) -> Array:
	var out := super.tokens(text)
	if not _back:
		return out
	var c := column(maxi(_p, 0))
	var room := (c.y - c.x) * 0.96
	var split: Array = []
	for t in out:
		var tx := String((t as Dictionary)["text"])
		var em := int((t as Dictionary)["emph"])
		if face(em).get_string_size(tx, HORIZONTAL_ALIGNMENT_LEFT, -1, body_fs).x <= room:
			split.append(t)
			continue
		# greedy: a piece ends at its last slash, dot or dash before it would outgrow the line (mid-word if it has none)
		var piece := ""
		var brk := -1
		for ch in tx:
			if not piece.is_empty() and face(em).get_string_size(piece + ch, HORIZONTAL_ALIGNMENT_LEFT, -1, body_fs).x > room:
				var cut := brk + 1 if brk >= 0 else piece.length()
				split.append({"text": piece.substr(0, cut), "emph": em})
				piece = piece.substr(cut)
				brk = -1
			piece += ch
			if ch in ["/", ".", "-", "_", "?", "&"]:
				brk = piece.length() - 1
		if not piece.is_empty():
			split.append({"text": piece, "emph": em})
	return split


# --- hooks -----------------------------------------------------------------------

func _top() -> float:
	return MARGIN_TOP if _back else PAGE.y * TEXT_TOP


func _bottom() -> float:
	return _limit


func _page_foot() -> float:
	return PAGE.y - MARGIN_BOTTOM * 0.7


## Sources are set ragged: an address justified opens rivers.
func _justify() -> bool:
	return not _back


func _finish() -> void:
	if pages.size() % 2 == 1:
		_new_page("blank")
	while pieces.size() < spreads():
		pieces.append([])
	while backs.size() < spreads():
		backs.append({})
	while scene_of.size() < spreads():
		scene_of.append(-1)
	while briefs.size() < spreads():
		briefs.append("")
	for pg in pages:
		(pg as Dictionary)["folio"] = 0
