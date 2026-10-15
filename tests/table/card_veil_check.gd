extends SceneTree

## card_veil_check - that a BORDERLESS card's type reads over whatever painting lies under it, measured in
## the pixels its face draws ([CardFaces.Face], [method CardTable.veil_of]; the user, 2026-10-14: "Be
## careful with how text is written onto such a card, since color will matter quite a lot there, for
## visibility"). cards_check holds the plan; this holds the plan to what the canvas draws.
##
##   tests/run_quiet.sh card_veil_check
##
## NOT `--headless`: every claim is a measurement of a drawn face.
##
## Decks' colors - five real episodes', the default, a mid gray under black, white on a mid green - each
## printed borderless and drawn over three paintings: black and white, the two every veil is planned
## against, and a field of the type's own ink, which hides type laid on it bare. Held:
##
##   - THE GROUND IS THE PLANNED ONE: beside the name and the numeral, from the top of each band to its
##     foot, the face shows the painting under the veil as [method CardTable.veil_of] planned it, mixed in
##     sRGB as [method CardTable.veil_contrast] assumes - so the bound cards_check holds every deck to is
##     the bound the pixels keep. Two-sided: the same veil mixed in linear light misses those pixels.
##   - THE TYPE READS: the name's and the numeral's letters against that ground at TEXT_CONTRAST at least,
##     in the ink planned; a front's details against theirs at PANEL_CONTRAST.
##   - THE VEIL IS WHY: past its fade the painting is bare, and there the type's ink against a painting of
##     its own color reads not at all.

## [stock, ink] as the producer wrote them (sanitize_look makes the ink readable on the stock).
const DECKS := [["#14213a", "#efe4c8"], ["#2b0f2e", "#e3c77a"], ["#eab4a5", "#253637"], ["#35461c", "#f2ead2"],
	["#cfc6dc", "#1b1430"], ["#efe6d2", "#1d1a2b"], ["#808080", "#000000"], ["#6b8e4e", "#ffffff"]]
## A short name, so the band's ends beside it are ground; and a numeral.
const CARD := {"key": "sun", "name": "Sun", "numeral": "XIX",
	"booklet": {"keywords": ["warmth", "candor"], "upright": "A plain day, seen plainly."}}
## How far a pixel may stand from the color predicted for it (8-bit steps), and how far the linear mix
## must miss where it differs from the sRGB one by more than SPLIT.
const NEAR := 2.5 / 255.0
const SPLIT := 10.0 / 255.0

var _fails := 0
var _checks := 0


func _init() -> void:
	_run.call_deferred()


func _ok(cond: bool, what: String) -> void:
	_checks += 1
	if not cond:
		_fails += 1
		print("  FAIL: " + what)


func _run() -> void:
	var faces: Array = []
	for d in DECKS:
		var look := CardTable.sanitize_look({"frame": {"style": "borderless", "stock": d[0], "ink": d[1]}, "title_face": "roman"})
		var stock := CardTable.color(String(look["frame"]["stock"]))
		var ink := CardTable.color(String(look["frame"]["ink"]))
		var name_veil := CardTable.veil_of(ink, stock, CardTable.TEXT_CONTRAST, CardTable.VEIL_HEAVIEST)
		var panel_veil := CardTable.veil_of(ink, stock, CardTable.PANEL_CONTRAST, CardTable.PANEL_HEAVIEST)
		for paint in [Color.BLACK, Color.WHITE, name_veil["ink"]]:
			for details in [false, true]:
				faces.append({"deck": d, "look": look, "paint": paint, "details": details,
					"veil": panel_veil if details else name_veil, "num_veil": name_veil,
					"vp": _face(look, paint, details)})
	for i in 4:
		await process_frame
	var split := 0
	for f in faces:
		var img: Image = (f["vp"] as SubViewport).get_texture().get_image()
		_ok(img != null and not img.is_empty(), "no pixels read back - is this running under --headless?")
		if img == null or img.is_empty():
			break
		split += _judge(f, img)
	_ok(split >= 12, "control: only %d grounds where an sRGB and a linear mix differ - the check cannot tell them apart" % split)
	print("card_veil_check: %s (%d checks, %d failure%s; %d grounds told sRGB from linear)" % ["ALL OK" if _fails == 0 else "FAILED",
		_checks, _fails, "" if _fails == 1 else "s", split])
	quit(1 if _fails > 0 else 0)


## A borderless face of [param look] over a flat painting of [param paint].
func _face(look: Dictionary, paint: Color, details: bool) -> SubViewport:
	var img := Image.create(64, 96, false, Image.FORMAT_RGBA8)
	img.fill(paint)
	var face := CardFaces.Face.new()
	face.look = look
	face.card = CARD
	face.art = ImageTexture.create_from_image(img)
	face.details = details
	var vp := CardFaces.viewport(root, face, CardFaces.face_px(look))
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	return vp


## Everything held of one drawn face. Returns how many of its grounds an sRGB and a linear mix tell apart.
func _judge(f: Dictionary, img: Image) -> int:
	var look: Dictionary = f["look"]
	var paint: Color = f["paint"]
	var what := "%s on %s over %s%s" % [f["deck"][1], f["deck"][0], paint.to_html(false), " (details)" if f["details"] else ""]
	var sz := Vector2(CardFaces.face_px(look))
	var boxes := CardFaces.type_boxes(look)
	var split := 0
	var lines: Array = [["numeral", f["num_veil"], CardTable.TEXT_CONTRAST]]
	lines.append(["panel", f["veil"], CardTable.PANEL_CONTRAST] if f["details"] else ["name", f["veil"], CardTable.TEXT_CONTRAST])
	for line in lines:
		var band: Rect2 = boxes[line[0]]
		var v: Dictionary = line[1]
		var want := paint.lerp(v["veil"], float(v["alpha"]))
		var linear := paint.srgb_to_linear().lerp((v["veil"] as Color).srgb_to_linear(), float(v["alpha"])).linear_to_srgb()
		# THE GROUND: down the band's left end, clear of the type (which starts 12 px in on a panel, and a
		# short name is centered far from it), from its top to its foot
		var ground := Color()
		for y in [band.position.y + 2.0, band.get_center().y, band.end.y - 2.0]:
			var got := img.get_pixelv(Vector2i(int(band.position.x + 3.0), int(y)))
			ground = got
			_ok(_dist(got, want) <= NEAR, "%s, %s: the ground at y %d is %s, planned %s" % [what, line[0], int(y), got.to_html(false), want.to_html(false)])
			if _dist(want, linear) > SPLIT:
				split += 1
				_ok(_dist(got, linear) > SPLIT * 0.5, "%s, %s: the ground matches a LINEAR mix too - the instrument cannot tell" % [what, line[0]])
		# THE TYPE: the letters' cores, found by the ink planned for them (the keyline round them is the
		# veil's color at full strength, and may stand further from the ground than the ink does)
		var area := Rect2i(int(band.position.x + 8.0), int(band.position.y), int(band.size.x - 16.0), int(band.size.y))
		if line[0] == "panel":
			area.size.y = int(sz.y * 0.05)  # the name, at the panel's head - above the rule under it
		var near := INF
		var at := Color()
		for y in range(area.position.y, area.end.y):
			for x in range(area.position.x, area.end.x):
				var c := img.get_pixel(x, y)
				if _dist(c, v["ink"]) < near:
					near = _dist(c, v["ink"])
					at = c
		_ok(near <= NEAR * 2.0, "%s, %s: no letter is in the ink planned, %s - the nearest is %s" % [what, line[0],
			(v["ink"] as Color).to_html(false), at.to_html(false)])
		var stands := CardTable.contrast(at, ground)
		_ok(stands >= float(line[2]) - 0.05, "%s, %s: its letters stand %.2f from their ground, under %.1f" % [what, line[0], stands, line[2]])
	# THE VEIL IS WHY: the painting bare, past the name's veil and its fade - and type of its color on it
	var name_band: Rect2 = boxes["panel" if f["details"] else "name"]
	var clear := int(name_band.position.y - sz.y * (CardFaces.VEIL_PAD + CardFaces.VEIL_FADE) - 6.0)
	var bare := img.get_pixel(int(sz.x * 0.5), clear)
	_ok(_dist(bare, paint) <= NEAR, "%s: past the veil the painting is %s, not %s" % [what, bare.to_html(false), paint.to_html(false)])
	if paint == (f["num_veil"] as Dictionary)["ink"]:
		_ok(CardTable.contrast(bare, (f["num_veil"] as Dictionary)["ink"]) < 1.1,
			"%s: control: the type's own ink reads on a painting of its color, bare - this painting proves nothing" % what)
	return split


func _dist(a: Color, b: Color) -> float:
	return maxf(absf(a.r - b.r), maxf(absf(a.g - b.g), absf(a.b - b.b)))
