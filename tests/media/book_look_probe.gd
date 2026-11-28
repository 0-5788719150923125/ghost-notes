extends Node

## Not a gate: drives a real book-medium session over a chapter with a synthetic word timeline and writes PNGs.
##
##   GHOST_PROBE_GPU=1 tests/run_boot_probe.sh tests/media/book_look_probe.gd 400 \
##       --out /tmp/book/b --doc <chapter.md> --times 2,20,60 --pages 0,1,2,3
##
## `--times` are the show seconds to photograph (the session steps there continuously); `--pages` also writes the
## flat page textures; `--word S` is seconds per word. `--camera X` sets Director.camera for the run (not saved).
## `--medium notebook` drives the notebook instead (`--medium popup` the pop-up book); `--sketch <png>` stands in for
## every `<!-- sketch: -->` as `--image` does for pictures, and `--popup <png>` (a cut-out on transparency) for every
## `<!-- popup: -->`, `--cover <png>` for the cover's picture. The words are timed from what the voice reads ([method
## TextWalk.spoken]): no sources, no citations. `--length S` gives the show a length (bookends included) and `--intro S`
## its intro, as a take would: the medium then sees its end coming (a pop-up book closes its cover before it). `--design
## <popup.json>` stands a pop-up book's spreads as that design says.
##
## It asserts only that a frame is not uniform.

const W := 1280
const H := 720
const DT := 1.0 / 30.0

var _out := "user://book"
var _doc := "/home/crow/repos/rift/books/north-star/chapters/40-pauses-and-clauses.md"
var _times: Array = [3.0, 30.0]
var _pages: Array = []
var _word := 0.26
var _flat := 0
var _image := ""        # a PNG to stand in for every illustration (via Illustrations' test seam)
var _turns := 0         # photograph the middle of this many leaf turns
var _medium := "book"
var _sketch := ""       # a PNG to stand in for every sketch
var _popup := ""        # a PNG to stand in for every pop-up
var _cover := ""        # a PNG to stand in for the cover's picture
var _length := 0.0      # the show's length, 0 for none known
var _intro := 2.0       # seconds before the first word
var _design := ""       # a pop-up book's design (popup.json) to stand its spreads by


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if i + 1 >= args.size():
			break
		match args[i]:
			"--out": _out = args[i + 1]
			"--doc": _doc = args[i + 1]
			"--word": _word = float(args[i + 1])
			"--camera": Director.camera = float(args[i + 1])
			"--image": _image = args[i + 1]
			"--sketch": _sketch = args[i + 1]
			"--popup": _popup = args[i + 1]
			"--cover": _cover = args[i + 1]
			"--length": _length = float(args[i + 1])
			"--intro": _intro = float(args[i + 1])
			"--design": _design = args[i + 1]
			"--medium": _medium = args[i + 1]
			"--turns": _turns = int(args[i + 1])
			"--settle": _settle = int(args[i + 1])
			"--times":
				_times = []
				for s in String(args[i + 1]).split(","):
					_times.append(float(s))
			"--pages":
				_pages = []
				for s in String(args[i + 1]).split(","):
					_pages.append(int(s))
	var body := FileAccess.get_file_as_string(_doc)
	if not _image.is_empty() or not _sketch.is_empty() or not _popup.is_empty() or not _cover.is_empty():
		var idx := {}
		for im in Manuscript.images(body):
			var f := _sketch if bool(im.get("sketch", false)) else (_popup if bool(im.get("popup", false)) else _image)
			if String(im.get("placement", "")) == "cover" and not _cover.is_empty():
				f = _cover
			if not f.is_empty():
				idx[String(im["key"])] = {"versions": [{"file": f, "sig": ""}], "current": 0}
		Illustrations.use_for_test({"index": idx}, true)
	var stage := SubViewport.new()
	stage.size = Vector2i(W, H)
	stage.own_world_3d = true
	stage.transparent_bg = false
	stage.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(stage)
	Director.detach()
	var medium: Medium = Medium.make(_medium)
	medium.mount(stage)
	Director.attach(stage, medium)
	Director.hold(true)
	if _length > 0.0:
		var pf := ProbeFeed.new()
		pf.length = _length
		pf.intro_hold = _intro
		pf.camera = Director.camera
		medium.feed = pf

	var subs: Subtitles = preload("res://src/show/subtitles.gd").new()
	subs.words = _timeline(body)
	# the voices' inks, as the Generative panel hands them over (book_document)
	var inks := {}
	var voices: Variant = (FrontMatter.read_block(body).data as Dictionary).get("voice", {}).get("voices", {})
	if voices is Dictionary:
		for who in voices:
			if voices[who] is Dictionary and not String(voices[who].get("ink", "")).is_empty():
				inks[who] = String(voices[who]["ink"])
	subs.document = {"source": body, "inks": inks}
	if not _design.is_empty():
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(_design))
		if d is Dictionary:
			subs.document["popup"] = d
	add_child(subs)
	if medium.bind_captions(subs):
		subs.overlay_hidden = true
	print("book_look_probe: %d synthetic words, %.0fs" % [subs.words.size(),
		float((subs.words.back() as Dictionary)["t1"]) if not subs.words.is_empty() else 0.0])

	var t := 0.0
	Spectrum.virtual_clock = 0.0
	_times.sort()
	for want in _times:
		while t < float(want):
			t += DT
			Spectrum.virtual_clock = t
			Spectrum.current.time = t
			medium.advance(Spectrum.current, DT, 1.0)
			await get_tree().process_frame
			var bk := medium as BookMedium
			# The end of a turn, frame by frame: the last frames of the leaf and the first after it lies down.
			if _settle > 0 and bk._turn_t >= BookMedium.TURN_TIME - 3.0 * DT:
				await get_tree().process_frame
				stage.get_texture().get_image().save_png("%s_end_%02d.png" % [_out, _settle_i])
				_settle_i += 1
			elif _settle > 0 and _was_turning and bk._turn_t < 0.0:
				for f in 4:
					if f > 0:
						t += DT
						Spectrum.virtual_clock = t
						Spectrum.current.time = t
						medium.advance(Spectrum.current, DT, 1.0)
					await get_tree().process_frame
					stage.get_texture().get_image().save_png("%s_end_%02d.png" % [_out, _settle_i])
					_settle_i += 1
				print("book_look_probe: turn ended at t=%.2f, %d frames written" % [t, _settle_i])
				_settle -= 1
			_was_turning = bk._turn_t >= 0.0
			if _turns > 0 and bk._turn_t >= 0.8 and bk._turn_t < 0.8 + DT:
				await get_tree().process_frame
				var ti := stage.get_texture().get_image()
				ti.save_png("%s_turn_t%04d.png" % [_out, int(t)])
				print("book_look_probe: mid-turn at t=%.1f %s" % [t, bk.debug_line()])
				_turns -= 1
		await get_tree().process_frame
		var img := stage.get_texture().get_image()
		var path := "%s_t%04d.png" % [_out, int(want)]
		img.save_png(path)
		var st := _spread(img)
		if st < 0.02:
			_flat += 1
		print("book_look_probe: t=%.1f %s -> %s (spread %.3f)" % [want,
			(medium as BookMedium).debug_line(), path, st])
	for p in _pages:
		var bv := medium as BookMedium
		var c: BookMedium.PageCanvas = bv._canvases[0]
		bv._slot_page[0] = int(p)
		c.page = int(p)
		c.position = Vector2(bv._page_pad() if int(p) % 2 == 0 else 0.0, bv._page_pad_top())
		c.hl = {}
		c.queue_redraw()
		(bv._vps[0] as SubViewport).render_target_update_mode = SubViewport.UPDATE_ONCE
		for _i in 3:
			await get_tree().process_frame
		var pimg := (bv._vps[0] as SubViewport).get_texture().get_image()
		pimg.save_png("%s_page%02d.png" % [_out, int(p)])
		bv._slot_state[0] = ""
	print("book_look_probe: done, %d flat" % _flat)
	Spectrum.virtual_clock = -1.0
	Director.hold(false)
	Director.detach()
	stage.queue_free()
	for _i in 3:
		await get_tree().process_frame
	get_tree().quit(1 if _flat > 0 else 0)


## Every printed word, spoken at a steady pace with a rest at each sentence end - the shape of
## a real take's sidecar, without a voice host.
var _settle := 0
var _settle_i := 0
var _was_turning := false


func _timeline(body: String) -> Array:
	var walk: TextWalk = PopupWalk.new() if _medium == "popup" else TextWalk.new()
	var title := FrontMatter.field_of(body, "title")
	var said := String(walk.spoken(body, title)["body"])
	# each word in reading order, a rest (a hesitation's seconds, as the walk wrote it) added before the word it opens
	var text := (title + " . " if not title.is_empty() else "") + Manuscript.strip_frontmatter(said)
	var rest := RegEx.create_from_string("<!--\\s*hesitation\\s*:\\s*([0-9.]+)\\s*-->")
	text = rest.sub(text, " @rest:$1 ", true)
	text = Manuscript._rx(Manuscript.COMMENT).sub(text, " ", true).replace("\n", " ").replace("\t", " ")
	var out: Array = []
	var t := _intro
	var si := 0
	for raw in text.split(" ", false):
		var word := String(raw).strip_edges()
		if word.begins_with("@rest:"):
			t += float(word.substr(6))
			continue
		if word == "." or word.is_empty() or word.begins_with("#"):
			continue
		out.append({"text": word, "t0": t, "t1": t + _word * 0.85, "sentence": si, "emph": 0})
		t += _word
		var tail := word.rstrip("\"'”’)*_")
		if tail.ends_with(".") or tail.ends_with("?") or tail.ends_with("!"):
			si += 1
			t += 0.45
	return out


func _spread(img: Image) -> float:
	var lo := 1.0
	var hi := 0.0
	for y in range(0, img.get_height(), 24):
		for x in range(0, img.get_width(), 24):
			var l := img.get_pixel(x, y).get_luminance()
			lo = minf(lo, l)
			hi = maxf(hi, l)
	return hi - lo


## A show's clock with a length, for a probe with no song: the session's virtual clock, a known end, an intro.
class ProbeFeed:
	extends ShowFeed
	var length := 0.0

	func show_time() -> float:
		return maxf(Spectrum.virtual_clock, 0.0)

	func show_length() -> float:
		return length

	func lead() -> float:
		return intro_hold
