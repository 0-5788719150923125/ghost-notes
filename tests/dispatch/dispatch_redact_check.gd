extends SceneTree

## dispatch_redact_check - that REDACTED WORDS ON THE DISPATCH DESK'S TERMINAL ([constant DispatchScript.REDACT]) are a
## mosaic of flat hexagons, in pixels (`shaders/dispatch_redact.gdshader`, [method DispatchScreens.redactions]):
##
## - EVERY HEXAGON IS ONE COLOR, and that color is THE AVERAGE OF WHAT LIES UNDER IT - the same lines drawn with nothing
##   redacted, averaged over the hexagon and its rect (THE CONTROL: in that plain picture the same hexagons are not one
##   color - the instrument sees the letters the mosaic hides);
## - the hexagons are not all one color (they carry where the letters were), and nothing outside the mosaic changes;
## - A RUN TYPED A KEY AT A TIME GROWS BY HEXAGONS: every hexagon of the shorter run that its right edge does not cut
##   keeps its color in the longer;
## - THE CURSOR IS DRAWN OVER THE MOSAIC (typing a redacted word never hides it).
##
##   tests/run_quiet.sh dispatch_redact_check [-- --png <path>]
##
## NOT `--headless`: every claim is a measurement of a rendered terminal.

const NAME := "NAME ........ "
const WORDS := "DOE, JANE QUINCY"
const AFTER := "PLATE ....... "
const PLATE := "XKC 4417"

var _fails := 0
var _checks := 0
var _screens: DispatchScreens


func _init() -> void:
	_run.call_deferred()


func _ok(cond: bool, what: String) -> void:
	_checks += 1
	if not cond:
		_fails += 1
		print("  FAIL: " + what)


func _run() -> void:
	_screens = DispatchScreens.new()
	root.add_child(_screens)
	_screens.build(PackedStringArray(["A"]))
	var hidden := PackedStringArray(["> open 1", NAME + DispatchScript.redacted("<!-- redact: %s -->" % WORDS),
		AFTER + DispatchScript.redacted("<!-- redact: %s -->" % PLATE), "STATUS ...... CONTAINED"])
	var plain := PackedStringArray(["> open 1", NAME + WORDS, AFTER + PLATE, "STATUS ...... CONTAINED"])
	var mosaic := await _render(hidden, false)
	var bare := await _render(plain, false)
	var args := OS.get_cmdline_user_args()
	var at := args.find("--png")
	if at >= 0 and at + 1 < args.size():
		mosaic.save_png(args[at + 1])
	var rects := _screens.redactions(hidden)
	_ok(rects.size() == 2 and _screens.redactions(plain).is_empty(), "a rect over each redacted run, none over plain words (%d)" % rects.size())
	# EVERY HEXAGON ONE COLOR, THE AVERAGE OF WHAT LIES UNDER IT
	var colors: Array = []
	var worst_spread := 0.0
	var worst_mean := 0.0
	var least_bare := INF
	for r in rects:
		var cells := _cells(r)
		for key in cells:
			var px: Array = cells[key]["inner"]
			var all: Array = cells[key]["all"]
			if px.size() < 20:
				continue
			var lo := Color(1, 1, 1)
			var hi := Color(0, 0, 0)
			var bare_lo := 1.0
			var bare_hi := 0.0
			for p in px:
				var c := mosaic.get_pixelv(p)
				lo = Color(minf(lo.r, c.r), minf(lo.g, c.g), minf(lo.b, c.b))
				hi = Color(maxf(hi.r, c.r), maxf(hi.g, c.g), maxf(hi.b, c.b))
				var b := bare.get_pixelv(p).g
				bare_lo = minf(bare_lo, b)
				bare_hi = maxf(bare_hi, b)
			worst_spread = maxf(worst_spread, maxf(hi.g - lo.g, maxf(hi.r - lo.r, hi.b - lo.b)))
			var mean := 0.0
			for p in all:
				mean += bare.get_pixelv(p).g
			mean /= float(all.size())
			var drawn := mosaic.get_pixelv(px[px.size() / 2]).g
			worst_mean = maxf(worst_mean, absf(drawn - mean))
			colors.append(snappedf(drawn, 1.0 / 255.0))
			if bare_hi - bare_lo > 0.0:
				least_bare = minf(least_bare, bare_hi - bare_lo) if bare_hi - bare_lo > 0.2 else least_bare
	_ok(colors.size() >= 10, "the mosaic has too few whole hexagons to judge (%d)" % colors.size())
	_ok(worst_spread <= 2.0 / 255.0, "a hexagon is not one color: its pixels spread %.4f" % worst_spread)
	_ok(worst_mean <= 0.03, "a hexagon's color is not the average of what lies under it: off by %.4f" % worst_mean)
	_ok(least_bare < INF, "the control: in the plain picture no hexagon holds a letter - the instrument cannot see one")
	var distinct := {}
	for c in colors:
		distinct[c] = true
	_ok(distinct.size() >= 4, "the hexagons are nearly all one color (%d colors) - they no longer carry where the letters were" % distinct.size())
	# NOTHING OUTSIDE THE MOSAIC CHANGES
	var same := true
	for y in range(0, DispatchScreens.TERM_SIZE.y, 3):
		for x in range(0, DispatchScreens.TERM_SIZE.x, 3):
			var p := Vector2i(x, y)
			var inside := false
			for r in rects:
				inside = inside or (r as Rect2).grow(1.5).has_point(Vector2(p) + Vector2(0.5, 0.5))
			if not inside and not mosaic.get_pixelv(p).is_equal_approx(bare.get_pixelv(p)):
				same = false
	_ok(same, "a pixel outside the mosaic changed")
	# A RUN TYPED A KEY AT A TIME GROWS BY HEXAGONS
	var short_lines := PackedStringArray(["> search " + DispatchScript.redacted("<!-- redact: doe, ja -->")])
	var long_lines := PackedStringArray(["> search " + DispatchScript.redacted("<!-- redact: doe, jane -->")])
	var short_img := await _render(short_lines, false)
	var long_img := await _render(long_lines, false)
	var short_rect: Rect2 = _screens.redactions(short_lines)[0]
	var kept := 0
	var moved := 0
	var cells := _cells(short_rect)
	for key in cells:
		var px: Array = cells[key]["inner"]
		# whole, and over the shorter run's own letters - its pad on the right may lie over the next letter in the longer
		if px.size() < 20 or not bool(cells[key]["whole_x"]) or float(cells[key]["right"]) > short_rect.end.x - DispatchScreens.MOSAIC_PAD:
			continue
		var p: Vector2i = px[px.size() / 2]
		if absf(short_img.get_pixelv(p).g - long_img.get_pixelv(p).g) <= 2.0 / 255.0:
			kept += 1
		else:
			moved += 1
	_ok(kept >= 2 and moved == 0, "typing on, the hexagons already there changed (%d kept, %d changed)" % [kept, moved])
	# THE CURSOR OVER THE MOSAIC
	var typing := await _render(long_lines, true)
	var cw := (load(DispatchScreens.MONO) as Font).get_string_size("M", HORIZONTAL_ALIGNMENT_LEFT, -1, DispatchScreens.TERM_FONT).x
	var cur := Vector2i(int(DispatchScreens.TERM_MARGIN.x + cw * float(String(long_lines[0]).length()) + 3.0),
		int(DispatchScreens.TERM_MARGIN.y - float(DispatchScreens.TERM_FONT) * 0.3))
	var long_rect: Rect2 = _screens.redactions(long_lines)[0]
	_ok(long_rect.has_point(Vector2(cur)) and _near(typing.get_pixelv(cur), DispatchScreens.PHOSPHOR),
		"the cursor is hidden under the mosaic (%s at %s, inside %s)" % [typing.get_pixelv(cur), cur, long_rect.has_point(Vector2(cur))])
	print("dispatch_redact_check: %s (%d checks, %d failure%s)" % ["ALL OK" if _fails == 0 else "FAILED", _checks, _fails, "" if _fails == 1 else "s"])
	quit(1 if _fails > 0 else 0)


## Are [param a] and [param b] the same color, but for a byte's rounding?
static func _near(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) <= 2.0 / 255.0 and absf(a.g - b.g) <= 2.0 / 255.0 and absf(a.b - b.b) <= 2.0 / 255.0


## The terminal showing [param lines], read back.
func _render(lines: PackedStringArray, cursor: bool) -> Image:
	_screens.show_terminal({"lines": lines, "asleep": false, "cursor": cursor})
	for i in 4:
		await process_frame
	return _screens.terminal.get_texture().get_image()


## THE HEXAGONS OF [param r], as the shader lays them: per cell, `all` (every pixel whose center is in the hexagon and the
## rect - what it averages), `inner` (those a pixel away from any edge - what must be one color), `whole_x` (the rect's
## sides do not cut it) and `right`, its right corner's x.
func _cells(r: Rect2) -> Dictionary:
	var s := DispatchScreens.MOSAIC_CELL
	var hw := 0.8660254 * s
	var origin := Vector2(r.position.x + hw, r.get_center().y)
	var out := {}
	for y in range(floori(r.position.y), ceili(r.end.y)):
		for x in range(floori(r.position.x), ceili(r.end.x)):
			var p := Vector2(x, y) + Vector2(0.5, 0.5)
			if not r.has_point(p):
				continue
			var c := _hex(p - origin, s)
			if not out.has(c):
				var cx := origin.x + c.x
				out[c] = {"all": [], "inner": [], "whole_x": cx - hw >= r.position.x - 0.01 and cx + hw <= r.end.x + 0.01, "right": cx + hw}
			(out[c]["all"] as Array).append(Vector2i(x, y))
			var interior := r.grow(-1.5).has_point(p)
			for d in [Vector2(1.5, 0), Vector2(-1.5, 0), Vector2(0, 1.5), Vector2(0, -1.5), Vector2(1.1, 1.1), Vector2(-1.1, -1.1), Vector2(1.1, -1.1), Vector2(-1.1, 1.1)]:
				interior = interior and _hex(p + d - origin, s) == c
			if interior:
				(out[c]["inner"] as Array).append(Vector2i(x, y))
	return out


## The shader's `hex_center`: the center of the pointy-top hexagon holding [param p], from the lattice's origin.
static func _hex(p: Vector2, s: float) -> Vector2:
	var q := (0.57735027 * p.x - p.y / 3.0) / s
	var r := (0.66666667 * p.y) / s
	var cube := Vector3(q, -q - r, r)
	var rc := cube.round()
	var d := (rc - cube).abs()
	if d.x > d.y and d.x > d.z:
		rc.x = -rc.y - rc.z
	elif d.y > d.z:
		rc.y = -rc.x - rc.z
	else:
		rc.z = -rc.x - rc.y
	return Vector2(s * (1.7320508 * rc.x + 0.8660254 * rc.z), s * 1.5 * rc.z)
