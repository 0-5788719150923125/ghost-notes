extends SceneTree

## The gate of [AppIcon] - the ghost drawn for a machine's window and a build's package. No renderer:
## ThorVG draws on the processor.
##
##   godot --headless --path . --script res://tests/platform/app_icon_check.gd
##
## - THE SAME SEED DRAWS THE SAME GHOST, design, SVG and pixels - against another seed, whose pixels
##   differ.
## - EVERY ROW IS DRAWN by some seed of a fixed hundred (every body, pose, eyes, mouth, prop, style),
##   and the hues fill every twelfth of the wheel - against the same hundred made of one seed, which
##   leaves rows undrawn and eleven twelfths empty.
## - EVERY GHOST DRAWS: none of the hundred comes out blank or failed. A row ThorVG cannot read may
##   draw nothing - or crash the engine outright (a stray `<` in a row did), which fails this gate
##   loudly where it would have crashed every launch whose seed picks the row.
## - EACH PLATFORM'S LAYER IS WHAT IT SAYS: the backdrop and the square are opaque (iOS refuses an
##   icon with alpha) and the backdrop holds no ghost (as dark as its gradient; against the square,
##   whose ghost is light); the monochrome is white wherever it is drawn, as solid as the figure but
##   for its face, and its face is cut out (against the figure measured against itself, which cuts
##   nothing; gray content under the mask comes out a faint white, which the solidity catches); the figure and the
##   monochrome lie inside Android's safe circle, 66 of the adaptive icon's 108 (against the whole
##   icon, whose backdrop does not).
## - EVERY GHOST STANDS IN THE MIDDLE (the user, 2026-10-31: "quite a few of the ghosts are
##   off-center"): each body drawn alone, turned either way, has its box's middle on the frame's -
##   against the drift body told its middle is (0, 0), which its tail pulls off.
## - NO PROP COVERS A FACE: of the hundred, no prop's pixel falls in the box round the eyes, mouth
##   and cheeks (the face the monochrome cuts, widened by the cheeks) - against a prop perched on the
##   eyes. And each prop's `box` is what it draws - against another prop's box.
## - THE PACKAGE has every icon at its size, each in a file of its own.
## - THIS MACHINE'S SEED is its id salted (not the id's bare hash) and the same each time asked.

const SEEDS := 100
## Android's safe zone: a circle 66 across in the adaptive icon's 108.
const SAFE := 66.0 / 108.0

var _fails := 0


func _init() -> void:
	_run.call_deferred()


func _ok(cond: bool, what: String) -> void:
	if not cond:
		_fails += 1
		print("  FAIL: " + what)


func _run() -> void:
	var seeds: Array[PackedByteArray] = []
	for i in SEEDS:
		seeds.append(AppIcon.seed_of("gate %d" % i))
	for check: Callable in [_same_seed, _every_row.bind(seeds), _every_ghost_draws.bind(seeds),
			_layers.bind(seeds), _centered, _face_clear.bind(seeds), _prop_boxes, _package, _machine]:
		var done: Variant = check.call()
		_ok(done == true, "%s stopped part way (a script error - see above)" % check.get_method())
	print("app_icon_check: %s (%d failure%s)" % ["ALL OK" if _fails == 0 else "FAILED", _fails, "" if _fails == 1 else "s"])
	quit(1 if _fails > 0 else 0)


func _same_seed() -> bool:
	var a := AppIcon.seed_of("the same")
	var d1 := AppIcon.design_of(a)
	var d2 := AppIcon.design_of(AppIcon.seed_of("the same"))
	_ok(d1 == d2, "one seed drew two designs")
	_ok(AppIcon.svg_of(d1) == AppIcon.svg_of(d2), "one design wrote two SVGs")
	var p1 := AppIcon.image_of(d1, 64).get_data()
	_ok(p1 == AppIcon.image_of(d2, 64).get_data(), "one design drew two pictures")
	# The control: another seed's picture differs, so the comparison above can tell.
	var other := AppIcon.image_of(AppIcon.design_of(AppIcon.seed_of("another")), 64).get_data()
	_ok(p1 != other, "CONTROL: two seeds drew the same picture - the comparison cannot tell them apart")
	return true


func _every_row(seeds: Array[PackedByteArray]) -> bool:
	var missing := _undrawn(seeds)
	_ok(missing.is_empty(), "rows no seed of %d draws: %s" % [seeds.size(), missing])
	var spread := _hue_twelfths(seeds)
	_ok(spread == 12, "the hues fill %d of the wheel's twelfths" % spread)
	# The control: one seed a hundred times draws one of each table and one hue.
	var same: Array[PackedByteArray] = []
	for i in seeds.size():
		same.append(seeds[0])
	_ok(not _undrawn(same).is_empty(), "CONTROL: one seed repeated drew every row - the count is blind")
	_ok(_hue_twelfths(same) == 1, "CONTROL: one seed repeated filled %d twelfths" % _hue_twelfths(same))
	return true


func _undrawn(seeds: Array[PackedByteArray]) -> Array:
	var tables := {"body": AppIcon.BODIES, "pose": AppIcon.POSES, "eyes": AppIcon.EYES,
		"mouth": AppIcon.MOUTHS, "prop": AppIcon.PROPS, "style": AppIcon.STYLES}
	var seen := {}
	for s in seeds:
		var d := AppIcon.design_of(s)
		for t: String in tables:
			seen["%s:%s" % [t, d[t]]] = true
	var missing := []
	for t: String in tables:
		for key: String in tables[t]:
			if not seen.has("%s:%s" % [t, key]):
				missing.append("%s:%s" % [t, key])
	return missing


func _hue_twelfths(seeds: Array[PackedByteArray]) -> int:
	var filled := {}
	for s in seeds:
		filled[int(float(AppIcon.design_of(s)["hue"]) * 12.0)] = true
	return filled.size()


func _every_ghost_draws(seeds: Array[PackedByteArray]) -> bool:
	var blank := 0
	for s in seeds:
		var img := AppIcon.image_of(AppIcon.design_of(s), 64)
		if img.get_width() != 64 or _alpha_share(img, 0.5) < 0.2:
			blank += 1
	_ok(blank == 0, "%d of %d ghosts came out blank or failed" % [blank, seeds.size()])
	return true


func _layers(seeds: Array[PackedByteArray]) -> bool:
	const N := 128
	var see_through := 0
	var ghost_in_backdrop := 0
	var no_ghost_in_square := 0
	var not_white := 0
	var uncut := 0
	var faint := 0
	var out_of_safe := 0
	var whole_in_safe := 0
	for s in seeds:
		var d := AppIcon.design_of(s)
		var back := AppIcon.image_of(d, N, "backdrop")
		var square := AppIcon.image_of(d, N, "square")
		var figure := AppIcon.image_of(d, N, "figure")
		var mono := AppIcon.image_of(d, N, "mono")
		if _alpha_share(back, 0.999) < 1.0 or _alpha_share(square, 0.999) < 1.0:
			see_through += 1
		if _brightest(back) > 0.75:
			ghost_in_backdrop += 1
		if _brightest(square) < 0.8:
			no_ghost_in_square += 1
		if not _white_where_drawn(mono):
			not_white += 1
		if _cut(figure, mono) == 0:
			uncut += 1
		if _solid(figure, mono) < 0.8:
			faint += 1
		if _past_safe(figure) > 0 or _past_safe(mono) > 0:
			out_of_safe += 1
		if _past_safe(AppIcon.image_of(d, N, "whole")) == 0:
			whole_in_safe += 1
	_ok(see_through == 0, "%d backdrops or squares let something show through" % see_through)
	_ok(ghost_in_backdrop == 0, "%d backdrops hold something as light as a ghost" % ghost_in_backdrop)
	_ok(no_ghost_in_square == 0, "CONTROL: %d squares hold nothing light - the backdrop's test is blind" % no_ghost_in_square)
	_ok(not_white == 0, "%d monochrome icons are drawn in something other than white" % not_white)
	_ok(uncut == 0, "%d monochrome icons have no face cut out" % uncut)
	_ok(faint == 0, "%d monochrome icons are fainter than their figure" % faint)
	var f := AppIcon.image_of(AppIcon.design_of(seeds[0]), N, "figure")
	_ok(_cut(f, f) == 0, "CONTROL: a figure measured against itself shows a cut - the measure is blind")
	_ok(out_of_safe == 0, "%d figures reach past Android's safe circle" % out_of_safe)
	_ok(whole_in_safe == 0, "CONTROL: %d whole icons lie inside the safe circle - the measure is blind" % whole_in_safe)
	return true


## The share of pixels at least [param least] opaque.
func _alpha_share(img: Image, least: float) -> float:
	var data := _rgba(img)
	var n := 0
	var floor := int(least * 255.0)
	for i in range(3, data.size(), 4):
		if data[i] >= floor:
			n += 1
	return float(n) / float(data.size() / 4)


func _brightest(img: Image) -> float:
	var data := _rgba(img)
	var most := 0
	for i in range(0, data.size(), 4):
		most = maxi(most, maxi(data[i], maxi(data[i + 1], data[i + 2])))
	return most / 255.0


func _white_where_drawn(img: Image) -> bool:
	var data := _rgba(img)
	for i in range(0, data.size(), 4):
		if data[i + 3] >= 128 and (data[i] < 240 or data[i + 1] < 240 or data[i + 2] < 240):
			return false
	return true


## Pixels the figure draws whole that the monochrome leaves clear: its face.
func _cut(figure: Image, mono: Image) -> int:
	var a := _rgba(figure)
	var b := _rgba(mono)
	var n := 0
	for i in range(3, a.size(), 4):
		if a[i] == 255 and b[i] < 64:
			n += 1
	return n


## The share of what the figure draws whole that the monochrome draws whole too.
func _solid(figure: Image, mono: Image) -> float:
	var a := _rgba(figure)
	var b := _rgba(mono)
	var whole := 0
	var kept := 0
	for i in range(3, a.size(), 4):
		if a[i] == 255:
			whole += 1
			if b[i] >= 250:
				kept += 1
	return float(kept) / float(maxi(whole, 1))


## Pixels drawn outside Android's safe circle (a pixel's grace for the edge's softness).
func _past_safe(img: Image) -> int:
	var data := _rgba(img)
	var size := img.get_width()
	var r := size * SAFE * 0.5 + 1.0
	var c := size * 0.5
	var n := 0
	for i in range(3, data.size(), 4):
		if data[i] > 12:
			var p := (i - 3) / 4
			if Vector2(p % size + 0.5 - c, p / size + 0.5 - c).length() > r:
				n += 1
	return n


func _rgba(img: Image) -> PackedByteArray:
	if img.get_format() == Image.FORMAT_RGBA8:
		return img.get_data()
	var copy := img.duplicate() as Image
	copy.convert(Image.FORMAT_RGBA8)
	return copy.get_data()


func _centered() -> bool:
	const N := 640
	var worst := 0.0
	for body: String in AppIcon.BODIES:
		for mirror in [false, true]:
			worst = maxf(worst, _off_middle(_alone(body, mirror), N))
	# Within half a pixel of a 128 icon.
	_ok(worst <= 0.5 * N / 128.0, "a body stands %.1f px of %d off the frame's middle" % [worst, N])
	var told := _alone("drift", false)
	told["middle"] = [0.0, 0.0]
	_ok(_off_middle(told, N) > 4.0 * N / 128.0, "CONTROL: the drift body told the wrong middle still stands in the middle - the measure is blind")
	return true


## A design of [param body] alone: no arms, no prop, no lean.
func _alone(body: String, mirror: bool) -> Dictionary:
	var d := AppIcon.design_of(AppIcon.seed_of("alone"))
	d.merge({"body": body, "middle": AppIcon.BODIES[body]["middle"], "perch": AppIcon.BODIES[body]["perch"],
		"pose": "float", "prop": "none", "tilt": 0.0, "mirror": mirror}, true)
	return d


## How far the middle of what the design draws (its figure, scaled about the frame's middle) is
## from the frame's middle, in pixels of an [param n] image.
func _off_middle(d: Dictionary, n: int) -> float:
	var img := AppIcon.image_of(d, n, "figure_square")
	var r := img.get_used_rect()
	return (Vector2(r.position) + Vector2(r.size) * 0.5).distance_to(Vector2(n, n) * 0.5)


func _face_clear(seeds: Array[PackedByteArray]) -> bool:
	var covered := 0
	var with_prop := 0
	for s in seeds:
		var d := AppIcon.design_of(s)
		if d["prop"] == "none":
			continue
		with_prop += 1
		if _over_face(d) > 0:
			covered += 1
	_ok(with_prop >= 50, "only %d of the hundred carry a prop" % with_prop)
	_ok(covered == 0, "%d props cover their ghost's face" % covered)
	var on_eyes := AppIcon.design_of(seeds[0])
	on_eyes.merge({"prop": "note", "tilt": 0.0, "mirror": false, "pose": "float"}, true)
	on_eyes["perch"] = [0.0, float(AppIcon.BODIES[on_eyes["body"]]["eyes"]) + 6.0]
	_ok(_over_face(on_eyes) > 0, "CONTROL: a note perched on the eyes covers nothing - the measure is blind")
	return true


## Pixels of the prop inside the face's box: the face is what the monochrome cuts out of the figure
## (eyes, mouth), widened to the cheeks; the prop is where the figure differs from the same without it.
func _over_face(d: Dictionary) -> int:
	const N := 256
	var bare := d.duplicate()
	bare["prop"] = "none"
	var fig := _rgba(AppIcon.image_of(bare, N, "figure_square"))
	var mono := _rgba(AppIcon.image_of(bare, N, "mono_square"))
	var lo := Vector2i(N, N)
	var hi := Vector2i(-1, -1)
	for i in range(3, fig.size(), 4):
		if fig[i] == 255 and mono[i] < 64:
			var p := (i - 3) / 4
			lo = Vector2i(mini(lo.x, p % N), mini(lo.y, p / N))
			hi = Vector2i(maxi(hi.x, p % N), maxi(hi.y, p / N))
	if hi.x < 0:
		return 0
	# The cheeks lie past the eyes: a ghost's unit is N / 128 * 0.8 * SIZE pixels.
	var unit := N / 128.0 * 0.8 * AppIcon.SIZE
	lo -= Vector2i(int(9.0 * unit), int(2.0 * unit))
	hi += Vector2i(int(9.0 * unit), int(2.0 * unit))
	var with_prop := _rgba(AppIcon.image_of(d, N, "figure_square"))
	var n := 0
	for y in range(maxi(lo.y, 0), mini(hi.y + 1, N)):
		for x in range(maxi(lo.x, 0), mini(hi.x + 1, N)):
			var i := (y * N + x) * 4
			for k in 4:
				if absi(with_prop[i + k] - fig[i + k]) > 24:
					n += 1
					break
	return n


func _prop_boxes() -> bool:
	var keys := []
	for key: String in AppIcon.PROPS:
		if AppIcon.PROPS[key].has("box"):
			keys.append(key)
			var miss := _box_miss(key, AppIcon.PROPS[key]["box"])
			_ok(miss <= 0.5, "the %s's box is %.1f off what it draws" % [key, miss])
	_ok(keys.size() >= 2, "fewer than two props have a box")
	_ok(_box_miss(keys[0], AppIcon.PROPS[keys[1]]["box"]) > 1.0,
		"CONTROL: the %s measured against the %s's box fits it - the measure is blind" % [keys[0], keys[1]])
	return true


## The most any edge of [param box] is off what the prop draws, outlined, in its own frame's units.
func _box_miss(key: String, box: Array) -> float:
	const SCALE := 10.0
	var art := str(AppIcon.PROPS[key]["svg"]).replace("{paint}", "fill=\"#000\" stroke=\"#000\" stroke-width=\"4.4\" stroke-linejoin=\"round\"")
	var img := Image.new()
	img.load_svg_from_string("<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"128\" height=\"128\" viewBox=\"0 0 128 128\"><g transform=\"translate(64,64)\">%s</g></svg>" % art, SCALE)
	var r := img.get_used_rect()
	var drawn := [r.position.x / SCALE - 64.0, r.position.y / SCALE - 64.0, r.end.x / SCALE - 64.0, r.end.y / SCALE - 64.0]
	var most := 0.0
	for k in 4:
		most = maxf(most, absf(float(drawn[k]) - float(box[k])))
	return most


func _package() -> bool:
	var icons := AppIcon.packaged(AppIcon.seed_of("a build"))
	var files := {}
	for key: String in AppIcon.PACKAGED:
		var row: Dictionary = AppIcon.PACKAGED[key]
		var img: Image = icons.get(key)
		_ok(img != null and img.get_width() == int(row["size"]) and img.get_height() == int(row["size"]),
			"the package's %s is not %d square" % [key, int(row["size"])])
		_ok(str(row["file"]).ends_with(".png"), "the package's %s is not a .png" % key)
		files[row["file"]] = true
	_ok(files.size() == AppIcon.PACKAGED.size(), "two packaged icons share a file")
	return true


func _machine() -> bool:
	var mine := AppIcon.machine_seed()
	_ok(mine.size() == 32, "this machine's seed is %d bytes" % mine.size())
	_ok(mine == AppIcon.machine_seed(), "this machine's seed changed between two asks")
	_ok(mine != OS.get_unique_id().sha256_buffer(), "this machine's seed is its id's bare hash, unsalted")
	_ok(not AppIcon.apply(), "a headless run set a window icon - the dummy display has none")
	return true
