extends SceneTree

## popup_check - that a pop-up book is set, stood, folded and read the way [PopupLayout], [PopupMedium] and [PopupWalk] say.
##
## Held: a scene opens at a picture after words and takes a spread of its own, which says which scene it shows; its
## pop-ups stand on it in the order written, at most three; its picture stands behind them as its scenery, and a floor
## picture is printed across both pages; its words are set below the pop-up band, split over the two pages within a line
## or two of even (a scene of a few lines kept whole on its left page, a paragraph's end passed over where the rest would not
## fit the right page); the title is the first spread's first words and
## counted; the cover is the book's and printed on no page; what follows the unread line is set at the back, every word
## inside its page. The crease: open flat it stands upright, square to both feet at every opening, leaning forward as
## the spread closes and nothing standing once it has. A piece's footprint: a V's ridge toward the reader, a box's front
## facing the reader, and any piece at any height asked kept inside the page, off the words and folding flat inside the
## page. The voice rests where each scene opens, longest after the title. A spread's brief is its own and never painted. The
## paper engineer is told every scene's words, brief and pictures; the layers it stands are each their own picture, painted as
## what they are (once), told when made smaller, at most five; a layer is refined only once painted; five cut-outs stand back
## to front; its prompt renders whole. The cover opens over its time and closes never
## before the last word, shut a while before the end.
##
## Controls that must fail: a novel's layout of the same chapter sets words above the pop-up's band, and feet square to
## the spine never rise.
##
## Run: godot --headless --path . --script tests/media/popup_check.gd

var fails := 0
var checks := 0

const DOC := """---
title: The Paper Town
---

<!-- image (cover): a paper town on a hill -->

<!-- image: a river valley at dusk -->
<!-- popup: a lighthouse -->
<!-- popup: a fishing boat -->

The first scene is long enough to run over more than one page of the spread, so that its lines must be split between the left page and the right one, and it goes on a while longer still, sentence after sentence, until the split has something real to weigh. It keeps going past the point where a single page would hold it comfortably, and then it stops.

A second paragraph closes the first scene with a few more words.

<!-- image (floor): cobblestones -->
<!-- popup: a market stall -->
<!-- popup: a bicycle -->
<!-- popup: a cat -->
<!-- popup: a dog that will be left lying -->

The second scene is short.

<!-- spread: a bridge over a river -->

The third scene cites a source (Leavitt et al., 2015) and ends.

<!-- unread -->

## References

Leavitt, P. A., Covarrubias, R., Perez, Y. A., & Fryberg, S. A. (2015). "Frozen in time": The impact of Native American media representations on identity and self-understanding. *Journal of Social Issues, 71*(1), 39-53. https://doi.org/10.1111/josi.12095/a-long-address-that-will-not-fit-on-one-line-of-the-page-at-all
"""


func _init() -> void:
	_layout()
	_crease()
	_footprints()
	_rests()
	_timing()
	_guide()
	_engineer()
	if fails == 0:
		print("popup_check: ALL OK (%d checks)" % checks)
	else:
		print("popup_check: %d FAILED of %d" % [fails, checks])
	quit(1 if fails > 0 else 0)


func _ok(cond: bool, what: String) -> void:
	checks += 1
	if not cond:
		fails += 1
		print("FAIL: " + what)


func _layout() -> void:
	var lay := PopupLayout.new()
	lay.build(DOC, func(_k: String) -> Vector2: return Vector2.ZERO)
	_ok(lay.spreads() == 4 and lay.back_from == 3, "three scenes and the back are not four spreads, the back last (%d, back %d)" % [lay.spreads(), lay.back_from])
	_ok(lay.pieces.size() == lay.spreads() and lay.backs.size() == lay.spreads() and lay.scene_of == [0, 1, 2, -1],
		"not every spread says what stands on it and which scene it shows: %s" % str(lay.scene_of))
	if lay.pieces.size() < 4:
		return
	var p0: Array = lay.pieces[0]
	_ok(p0.size() == 2 and String(p0[0]["prompt"]) == "a lighthouse" and String(p0[1]["prompt"]) == "a fishing boat",
		"the first spread's pop-ups are not the lighthouse then the boat: %s" % str(p0))
	_ok((lay.pieces[1] as Array).size() == 3, "a spread stands more or fewer than three when four are written")
	_ok((lay.pieces[3] as Array).is_empty() and (lay.backs[3] as Dictionary).is_empty(), "something stands on the sources")
	_ok(lay.briefs == ["", "", "a bridge over a river", ""] and (lay.pieces[2] as Array).is_empty(),
		"a spread's brief is not its own, or stands as a piece: %s" % str(lay.briefs))
	_ok(String((lay.backs[0] as Dictionary).get("prompt", "")) == "a river valley at dusk", "the scene's picture is not its scenery")
	_ok((lay.backs[1] as Dictionary).is_empty(), "a floor stands as scenery")
	var printed_first := 0
	var floor_spans: Array = []
	for side in 2:
		printed_first += ((lay.pages[side] as Dictionary)["images"] as Array).size()
		for im in (lay.pages[2 + side] as Dictionary)["images"]:
			floor_spans.append(int((im as Dictionary).get("span", -1)))
	_ok(printed_first == 0, "the scenery is printed flat on the page")
	_ok(floor_spans == [0, 1], "the floor does not lie across both pages: %s" % str(floor_spans))
	_ok(String(lay.cover.get("prompt", "")) == "a paper town on a hill", "the cover is not the book's cover: %s" % str(lay.cover))
	_ok(lay.title_words == 3, "the title's words are not counted before the story's (%d)" % lay.title_words)
	_ok(not lay.words.is_empty() and String(lay.words[0]["text"]) == "The" and int(lay.words[0]["page"]) == 0,
		"the title is not the first spread's first words")
	var top := BookLayout.PAGE.y * PopupLayout.TEXT_TOP
	var lines := [{}, {}]
	var above := 0
	var outside := 0
	var short_pages := {}
	var back_words := 0
	for w in lay.words:
		var r: Rect2 = w["rect"]
		var page := int(w["page"])
		if page < lay.back_from * 2 and r.position.y < top - 2.0:
			above += 1
		if r.position.x < 0.0 or r.end.x > BookLayout.PAGE.x or r.end.y > BookLayout.PAGE.y:
			outside += 1
		if page < 2:
			lines[page][int(r.position.y)] = true
		if page >= 4 and page < 6:
			short_pages[page] = true
		if page >= lay.back_from * 2:
			back_words += 1
	_ok(above == 0, "%d scene words are set above the words' top, under the pop-up" % above)
	_ok(outside == 0, "%d words run off their page" % outside)
	var nl := (lines[0] as Dictionary).size()
	var nr := (lines[1] as Dictionary).size()
	_ok(nl > 0 and nr > 0 and absi(nl - nr) <= 2, "the first scene's words are not split over both pages (%d, %d lines)" % [nl, nr])
	_ok(short_pages.keys() == [4], "a scene of two lines is split over its pages: %s" % str(short_pages.keys()))
	_ok(back_words > 10, "the sources are not set at the back")
	# a paragraph's end near the middle is passed over where what follows it would not fit on the right page
	var lorem := "lorem ipsum dolor sit amet consectetur adipiscing elit sed do eiusmod tempor incididunt labore dolore magna aliqua".split(" ")
	var pa := PackedStringArray()
	for i in 28:
		pa.append(lorem[i % lorem.size()])
	var pb := PackedStringArray()
	for i in 70:
		pb.append(lorem[(i + 3) % lorem.size()])
	# four lines, then thirteen: split at the paragraph's end, the right page would overflow by four
	var split_doc := "<!-- spread: a field -->\n\n" + " ".join(pa) + ".\n\n" + " ".join(pb) + ".\n"
	var tight := PopupLayout.new()
	tight.build(split_doc, func(_k: String) -> Vector2: return Vector2.ZERO)
	var tight_pages := {}
	for w in tight.words:
		tight_pages[int(w["page"])] = true
	_ok(tight.spreads() == 1 and tight_pages.keys().size() == 2,
		"a scene that fits a spread spills onto another, split where the right page cannot hold the rest (%d spreads)" % tight.spreads())
	# control: the novel sets the same chapter's words where the pop-up stands
	var novel := BookLayout.new()
	novel.build(DOC, func(_k: String) -> Vector2: return Vector2.ZERO)
	var novel_above := 0
	for w in novel.words:
		if (w["rect"] as Rect2).position.y < top - 2.0:
			novel_above += 1
	_ok(novel_above > 0, "control: a novel's layout sets nothing above the pop-up's band, so the check above holds nothing")


func _crease() -> void:
	var left := Vector3(-1.0, 0.0, 0.0)
	var open := PopupMedium.crease(left, Vector3(1.0, 0.0, 0.0))
	_ok(open.distance_to(Vector3.UP) < 1e-4, "open flat, a piece does not stand upright: %s" % str(open))
	var s := sin(deg_to_rad(PopupMedium.FOLD))
	var k := cos(deg_to_rad(PopupMedium.FOLD))
	var last_lean := -1.0
	var rigid := true
	var leaning := true
	for i in range(1, 18):
		var a := PI * float(i) / 18.0
		var right := Vector3(cos(a), sin(a), 0.0)
		var c := PopupMedium.crease(left, right)
		if c == Vector3.ZERO:
			continue
		if absf(c.dot(left * s - Vector3(0.0, 0.0, k))) > 1e-4 or absf(c.dot(right * s - Vector3(0.0, 0.0, k))) > 1e-4:
			rigid = false
		var lean := c.angle_to(Vector3.UP)
		if lean < last_lean - 1e-4 or c.z < -1e-4:
			leaning = false
		last_lean = lean
	_ok(rigid, "a crease is not square to its feet at every opening: the card would stretch")
	_ok(leaning, "as the leaf rises, the pieces do not lean steadily forward (their ridges toward the reader)")
	_ok(PopupMedium.crease(left, Vector3(-1.0, 0.001, 0.0)) == Vector3.ZERO, "a closed spread still stands its pieces")
	# control: feet square to the spine never rise (the crease runs along the spine)
	var square := PopupMedium.crease(left, Vector3(cos(0.3), sin(0.3), 0.0), 90.0)
	_ok(square == Vector3.ZERO or absf(square.z) > 0.99, "control: feet square to the spine rise, so the fold angle holds nothing")


## A V's ridge comes toward the reader; a box's front faces the reader; every piece, at any height asked, stands inside the
## page and off the words and folds flat inside the page.
func _footprints() -> void:
	var words_z := (PopupLayout.TEXT_TOP - 0.5) * BookMedium.PAGE_H - 0.02
	var v := PopupMedium.footprint(PopupMedium.V.merged({"z": 0.0, "height": 0.3}), 1.0, words_z)
	var feet: PackedVector2Array = v["feet"]
	_ok(feet.size() == 3 and feet[1].is_equal_approx(Vector2.ZERO) and feet[0].y < 0.0 and feet[2].y < 0.0
		and feet[0].x < 0.0 and feet[2].x > 0.0, "a V's ridge is not toward the reader: %s" % str(feet))
	var box := PopupMedium.footprint({"z": 0.0, "height": 0.3, "folds": [0.25, 0.75], "turns": [-80.0, 0.0, 80.0], "at": 1}, 2.0, words_z)
	var bf: PackedVector2Array = box["feet"]
	_ok(bf.size() == 4 and absf(bf[1].y - bf[2].y) < 1e-4 and bf[0].y < bf[1].y and bf[3].y < bf[2].y,
		"a box's front does not face the reader, its sides running back: %s" % str(bf))
	var s := sin(deg_to_rad(PopupMedium.FOLD))
	var k := cos(deg_to_rad(PopupMedium.FOLD))
	var shapes := [PopupMedium.V, {"folds": [0.25, 0.75], "turns": [-80.0, 0.0, 80.0], "at": 1},
		{"folds": [0.2, 0.4, 0.6, 0.8], "turns": [30.0, -30.0, 30.0, -30.0, 30.0], "at": 2}, {"folds": [0.5], "turns": [-6.0, 6.0], "at": 1}]
	var bad := 0
	for shape in shapes:
		for z in [-0.4, -0.1, 0.12]:
			var fp := PopupMedium.footprint((shape as Dictionary).merged({"z": z, "height": 5.0}), 1.6, words_z)
			var h := float(fp["height"])
			for p in (fp["feet"] as PackedVector2Array):
				if absf(p.x) > PopupMedium.REACH_X + 1e-4 or p.y < PopupMedium.BACK_Z - 1e-4 or p.y > words_z + 1e-4 \
						or absf(p.x) + h * k > PopupMedium.SHUT_X + 1e-4 or p.y + h * s > PopupMedium.SHUT_Z + 1e-4:
					bad += 1
	_ok(bad == 0, "%d feet of pieces asked too tall stand outside the page, on the words, or fold out past the page" % bad)
	# every default slot stands its V whole, in front of the scenery
	for n in PopupMedium.SLOTS:
		for sl in PopupMedium.SLOTS[n]:
			var fp := PopupMedium.footprint(PopupMedium.V.merged({"z": sl[0], "height": sl[1]}), 1.0, words_z)
			_ok(is_equal_approx(float(fp["height"]), float(sl[1])) and (fp["feet"] as PackedVector2Array)[0].y > float(PopupMedium.SCENERY["z"]),
				"slot %s of %d does not stand whole in front of the scenery (%.3f)" % [str(sl), n, float(fp["height"])])


func _rests() -> void:
	var body := String(PopupWalk.new().spoken(DOC, "The Paper Town")["body"])
	var rx := RegEx.create_from_string("<!--\\s*hesitation:\\s*([0-9.]+)\\s*-->\\s*(\\S+)")
	var got: Array = []
	for m in rx.search_all(body):
		got.append([float(m.get_string(1)), m.get_string(2)])
	_ok(got.size() == 3 and got[0][1] == "The" and is_equal_approx(float(got[0][0]), PopupWalk.OPEN_REST)
		and is_equal_approx(float(got[1][0]), PopupWalk.TURN_REST) and is_equal_approx(float(got[2][0]), PopupWalk.TURN_REST),
		"the voice does not rest where each scene opens, longest after the title: %s" % str(got))
	_ok(not body.contains("Leavitt") and not body.contains("References"), "the sources or a citation are read aloud")


## The cover opens smoothly from its start, and closes never before the last word and shut a while before the end.
func _timing() -> void:
	_ok(PopupMedium.opened_at(9.0, 10.0, 4.0) == 0.0 and PopupMedium.opened_at(14.5, 10.0, 4.0) == 1.0
		and absf(PopupMedium.opened_at(12.0, 10.0, 4.0) - 0.5) < 1e-6, "the cover does not open over its time")
	var length := 240.0
	_ok(is_equal_approx(PopupMedium.close_start(length, 220.0), length - PopupMedium.SHUT_HOLD - PopupMedium.CLOSING),
		"a long outro does not close a while before the end")
	_ok(PopupMedium.close_start(length, 236.0) >= 236.0, "the cover closes before the last word has been said")
	_ok(PopupMedium.TURN_EARLY < PopupWalk.TURN_REST and PopupMedium.TURN_EARLY > BookMedium.TURN_TIME,
		"the leaf does not turn inside the voice's rest for it")


func _guide() -> void:
	var asked := Medium.pictures_of("popup", DOC)
	var placements: Array = []
	for im in asked:
		placements.append(String((im as Dictionary)["placement"]))
	_ok(placements.count("spread") == 1 and placements.count("popup") == 6 and placements.count("cover") == 1
		and placements.count("floor") == 1 and placements.count("brief") == 0,
		"the pop-up book does not ask for its scenery, floor, cover and pop-ups, or paints a brief: %s" % str(placements))
	_ok(Illustrations.placement_guide(Illustrations.SPREAD).contains("middle third"), "the scenery is not kept off its fold")
	_ok(Illustrations.placement_guide(Illustrations.FLOOR).contains("ABOVE"), "a floor is not asked for from above")
	_ok(Illustrations.placement_guide(Illustrations.COVER).contains("TOP FIFTH"), "a cover is not kept clear for its title")
	var g := Illustrations.placement_guide(Illustrations.POPUP)
	_ok(g.contains("MAGENTA") and g.contains("cut") and g.contains("EYE LEVEL"), "a pop-up is not asked for at eye level on a flat magenta ground")


func _engineer() -> void:
	var tools := PopupTools.new()
	tools.body = func() -> String: return DOC
	var painted := []
	var states := {}
	tools.paint = func(im: Dictionary) -> String:
		painted.append(im)
		states[String(im["key"])] = "queued"
		return ""
	tools.state = func(key: String) -> String: return String(states.get(key, "missing"))
	var redone := []
	tools.redo = func(im: Dictionary, ask: String) -> String:
		redone.append([String(im["key"]), ask])
		return ""
	var listed := tools.scenes_text(DOC)
	_ok(listed.contains("SCENE 0") and listed.contains("Brief: a bridge over a river") and listed.contains("Layers: none yet.")
		and listed.contains("The script's own picture (cut-out): \"a lighthouse\"") and listed.contains("(floor): \"cobblestones\""),
		"the engineer is not told every scene's words, brief and pictures: %s" % listed.left(500))
	var v := PopupMedium.V
	var said := tools._stand(DOC, {"scene": 2, "back": {"picture": "a river and hills", "aspect": 2.4},
		"pieces": [v.merged({"picture": "a stone bridge", "z": -0.1, "height": 5.0}), v.merged({"picture": "a heron", "z": 0.12, "height": 0.2})]})
	var placed: Array = painted.map(func(im: Dictionary) -> String: return String(im["placement"]))
	_ok(painted.size() == 3 and placed == ["spread", "popup", "popup"] and String(said.get("text", "")).contains("being painted")
		and String(said.get("text", "")).contains("made smaller"),
		"standing new layers does not paint each as what it is, or say a layer was made smaller: %s %s" % [str(placed), str(said)])
	var pics := PopupDesign.pictures_of(tools.design)
	_ok(pics.size() == 3 and PopupDesign.layered(PopupDesign.scene_of(tools.design, 2)) and not PopupDesign.layered(PopupDesign.scene_of(tools.design, 0))
		and String(pics[1]["key"]) == PopupDesign.key_of("piece", "a stone bridge"), "the design's layers are not its own pictures: %s" % str(pics))
	painted.clear()
	tools._stand(DOC, {"scene": 2, "pieces": [v.merged({"picture": "a stone bridge", "z": -0.1, "height": 0.3})]})
	_ok(painted.is_empty(), "a picture already asked for is painted again: %s" % str(painted))
	var six := []
	for k in 6:
		six.append({"picture": "a stone %d" % k})
	_ok(tools._stand(DOC, {"scene": 2, "pieces": six}).has("error"), "a spread stands more cut-outs than it may")
	_ok(tools._stand(DOC, {"scene": 9}).has("error"), "a scene that is not there is stood")
	_ok(tools._refine(DOC, {"scene": 2, "layer": "0", "ask": "seen straight on"}).has("error"), "a layer not painted yet is refined")
	states[PopupDesign.key_of("piece", "a stone bridge")] = "ready"
	var r := tools._refine(DOC, {"scene": 2, "layer": "0", "ask": "seen straight on"})
	_ok(not r.has("error") and redone.size() == 1 and String(redone[0][1]) == "seen straight on", "a painted layer is not refined with its ask: %s" % str(r))
	_ok(PopupMedium.slot(4, 5, 1.0)["z"] > PopupMedium.slot(0, 5, 1.0)["z"] and float(PopupMedium.slot(4, 5, 1.0)["height"]) < float(PopupMedium.slot(0, 5, 1.0)["height"]),
		"five cut-outs do not stand back to front, the nearest smallest")
	Rules.clear()
	var vars := {"title": "The Paper Town", "scenes": tools.scenes_text(DOC), "most": PopupDesign.MOST, "fold": 72, "words_z": "0.16", "style": "carved prints"}
	var sys := Rules.say("popup/engineer.system", vars)
	var ask := Rules.say("popup/engineer.prompt", vars)
	_ok(Rules.missing.is_empty() and not sys.contains("{{") and not ask.contains("{{") and ask.contains("Brief: a bridge") and sys.contains("carved prints"),
		"the engineer's prompt does not render whole: %s" % str(Rules.missing))
