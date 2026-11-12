extends SceneTree

## The gate of the painting laid in layers ([PaintLayers]; next/painted_surface.md, "The painting is the design"), on a picture made
## here: a white oval with a purple disc, an orange streak across the disc, and a black line.
##
##   godot --headless --path . --script res://tests/table/paint_layers_check.gd
##
## - A foundation first: the first layer is the white, over the whole surface.
## - Widest tool first: each layer's tool no wider than the one before's (the foundation aside).
## - Orange on the purple: an orange layer comes after a purple one, and the streak is orange at the end.
## - It finishes: next to nothing of the surface is left off the picture. Control: the sponge alone leaves the line and the streak.
## - A tool goes only where it fits: no point of the white is left darker than the picture's white by a spill. Control: the picture has
##   dark there to be spilt onto (the line runs beside the white).
## - A coat laid area by area: on a broad plain surface, the hand comes back to a square it had left (after 30 dabs elsewhere) at most
##   half as often as the same dabs taken round and round out from the middle. Control: those come back, ring after ring.
## - Built up as it was laid: what a point holds after the first mark that reaches it is a thin film, well short of what all its marks
##   come to. Control: shown from that first mark at what they all come to, it holds nearly all of it at once.

const W := 60.0
const H := 80.0
const PX := 4.0
## The squares a coat's hand is watched coming back to (millimeters), after this many dabs elsewhere.
const TILE := 50.0
const AWAY := 30
const WHITE := Color("#f6f3ec")
const PURPLE := Color("#4b2a3c")
const ORANGE := Color("#c8561e")
const BLACK := Color("#121214")
const PAINTS := [{"name": "white", "color": WHITE}, {"name": "purple", "color": PURPLE}, {"name": "orange", "color": ORANGE},
	{"name": "black", "color": BLACK}]
const TOOLS := [{"name": "sponge", "kind": "dab", "width": 14.0}, {"name": "round", "kind": "stroke", "width": 4.0},
	{"name": "liner", "kind": "stroke", "width": 1.0}]

var failures := 0


func _ok(cond: bool, msg: String) -> void:
	if not cond:
		failures += 1
		print("  FAIL: " + msg)


func _init() -> void:
	var pic := _picture()
	var res := PaintLayers.plan(pic, Vector2(W, H), Color("#c89e80"), PAINTS, TOOLS)
	var layers: Array = res["layers"]
	print("  %d layers, off %.1f on average, %.1f%% left: %s" % [layers.size(), float(res["off"]), float(res["left"]) * 100.0,
		", ".join(layers.map(func(l: Dictionary) -> String: return "%s %s %.0f%%" % [l["tool"], l["paint"], float(l["alpha"]) * 100.0]))])
	_ok(not layers.is_empty() and String((layers[0] as Dictionary)["paint"]) == "white" and bool((layers[0] as Dictionary).get("base", false)),
		"the first layer is not the white foundation: %s" % [layers[0] if not layers.is_empty() else "none"])
	var widths := {"sponge": 14.0, "round": 4.0, "liner": 1.0}
	var narrowing := true
	for i in range(2, layers.size()):
		if float(widths[String((layers[i] as Dictionary)["tool"])]) > float(widths[String((layers[i - 1] as Dictionary)["tool"])]):
			narrowing = false
	_ok(narrowing, "a layer's tool is wider than the one before it")
	var first_purple := -1
	var last_orange := -1
	for i in layers.size():
		var nm := String((layers[i] as Dictionary)["paint"])
		if nm == "purple" and first_purple < 0:
			first_purple = i
		if nm == "orange":
			last_orange = i
	var canvas: Image = res["canvas"]
	var streak := canvas.get_pixel(int(30.0 * PaintLayers.PX), int(30.0 * PaintLayers.PX))
	_ok(first_purple >= 0 and last_orange > first_purple and _near(streak, ORANGE),
		"orange did not go on over the purple (purple first at %d, orange last at %d; the streak is %s)" % [first_purple, last_orange, streak.to_html(false)])
	_ok(float(res["left"]) < 0.04, "%.1f%% of the surface is left off the picture" % (float(res["left"]) * 100.0))
	var alone := PaintLayers.plan(pic, Vector2(W, H), Color("#c89e80"), PAINTS, [TOOLS[0]])
	_ok(float(alone["left"]) > float(res["left"]) * 2.0 + 0.02, "THE CONTROL: the sponge alone left only %.1f%%" % (float(alone["left"]) * 100.0))
	# ...no spill: the white beside the line is still white
	var beside := canvas.get_pixel(int(46.0 * PaintLayers.PX), int(60.0 * PaintLayers.PX))
	_ok(_near(beside, WHITE), "the white beside the line is %s, spilt on" % beside.to_html(false))
	_ok(_near(pic.get_pixel(int(48.0 * PX), int(60.0 * PX)), BLACK), "THE CONTROL: the picture has no line beside that white to spill")
	# ...a coat laid area by area, and built up as it was laid
	var size := Vector2(100.0, 130.0)
	var plain := Image.create(int(size.x * PX), int(size.y * PX), false, Image.FORMAT_RGBA8)
	plain.fill(WHITE)
	var pl := PaintLayers.begin(plain, size, Color("#c89e80"), [WHITE], WHITE)
	var r := 5.0
	var coat := pl.lay({"id": "coat", "manner": "stipple", "paint": WHITE, "r": r, "base": true, "rect": Rect2(Vector2.ZERO, size), "frame": size, "seed": 3})
	var dabs: Array = []
	for st in (coat["program"] as Dictionary)["strokes"]:
		dabs.append(((st as Dictionary)["pts"] as PackedVector2Array)[0])
	var apart := r * 2.0 * PaintLayers.DAB_APART
	var back := _returns(dabs, TILE)
	var ringed := _returns(Skins._grown(dabs, apart), TILE)
	_ok(dabs.size() > 40 and back * 2 <= ringed, "a coat's hand comes back %d times to a %d mm square it had left (round and round, %d; %d dabs)" % [back, int(TILE), ringed, dabs.size()])
	var built: Image = (coat["built"] as Array)[0]
	var built_last: Image = (coat["built"] as Array).back()
	var firsts := []
	var lasts := []
	for y in range(0, built.get_height(), 3):
		for x in range(0, built.get_width(), 3):
			var c := built.get_pixel(x, y)
			var last := built_last.get_pixel(x, y).a
			if last > 0.5:
				firsts.append(c.r)
				lasts.append(last)
	firsts.sort()
	lasts.sort()
	var first_mid := float(firsts[firsts.size() / 2]) if not firsts.is_empty() else 1.0
	var last_mid := float(lasts[lasts.size() / 2]) if not lasts.is_empty() else 0.0
	_ok(first_mid < 0.6 and first_mid < last_mid - 0.25, "after the first mark a point holds %.2f of its paint (after them all, %.2f)" % [first_mid, last_mid])
	_ok(last_mid > 0.85, "THE CONTROL: shown from its first mark at what they all come to, a point holds only %.2f" % last_mid)
	print("  a coat of %d dabs: back %d times to a square it had left (round and round, %d); a point holds %.2f after its first mark, %.2f after them all" % [
		dabs.size(), back, ringed, first_mid, last_mid])
	print("paint_layers_check: %s" % ("passed" if failures == 0 else "FAILED (%d failures)" % failures))
	quit(0 if failures == 0 else 1)


## The picture: a white oval, a purple disc on it, an orange streak across the disc, a black line down the right.
static func _picture() -> Image:
	var img := Image.create(int(W * PX), int(H * PX), false, Image.FORMAT_RGBA8)
	for y in img.get_height():
		for x in img.get_width():
			var p := Vector2(float(x) + 0.5, float(y) + 0.5) / PX
			var c := Color(0, 0, 0, 0)
			if Vector2((p.x - W * 0.5) / (W * 0.48), (p.y - H * 0.5) / (H * 0.48)).length() <= 1.0:
				c = WHITE
				if p.distance_to(Vector2(30.0, 30.0)) <= 12.0:
					c = PURPLE
				if absf(p.y - 30.0) <= 1.6 and absf(p.x - 30.0) <= 14.0:
					c = ORANGE
				if absf(p.x - 48.0) <= 0.8 and p.y > 45.0 and p.y < 70.0:
					c = BLACK
			img.set_pixel(x, y, c)
	return img


## How many times dabs [param pts], in turn, come back to a square [param tile] millimeters wide that they had left for [constant AWAY] dabs
## or more (to and fro across a square's edge as an area is worked is no coming back).
static func _returns(pts: Array, tile: float) -> int:
	var seen := {}
	var back := 0
	for j in pts.size():
		var q: Vector2 = pts[j]
		var t := Vector2i(floori(q.x / tile), floori(q.y / tile))
		if seen.has(t) and j - int(seen[t]) > AWAY:
			back += 1
		seen[t] = j
	return back


static func _near(a: Color, b: Color) -> bool:
	return PaintLayers.lab(a.srgb_to_linear().r, a.srgb_to_linear().g, a.srgb_to_linear().b).distance_to(
		PaintLayers.lab(b.srgb_to_linear().r, b.srgb_to_linear().g, b.srgb_to_linear().b)) < PaintLayers.NEED
