extends SceneTree

## dispatch_redact_check - that REDACTED WORDS ON THE DISPATCH DESK ([constant DispatchScript.REDACT]) are hidden OVER THE
## FRAME, as an editor hides a name after the shoot ([DispatchCensor], `shaders/dispatch_redact.gdshader`): the terminal
## drawn as the desk draws it, on a quad bulged as the desk's glass is, seen by a camera off to one side, and the censor
## drawn over that picture:
##
## - NO LETTER OF THE REDACTED WORDS REACHES THE FRAME: every pixel they light (the frame with them against the frame with
##   them blanked - THE CONTROL: there are such pixels) lies inside a box;
## - EVERY SHARD IS ONE COLOR, THE AVERAGE OF THE FRAME UNDER IT (THE CONTROL: in the frame without the censor the same
##   shards are not one color), its shape the cracks' ([method DispatchCensor.shard], line for line with the shader); the
##   shards are not all one color; nothing outside the boxes changes;
## - THE BOXES ARE THE FRAME'S: runs on lines next to each other are one box, runs a line apart two (THE CONTROL: plain
##   lines, none); a box is upright round the words as the camera sees them and larger than them, and never short of
##   them while the camera moves - it trails a beat behind a sudden move (wider than at rest just after, back within its
##   waver half a second later) and wavers at rest, a function of show time alone (the same moment, the same box).
##
##   tests/run_quiet.sh dispatch_redact_check
##   tests/run_quiet.sh -- tests/dispatch/dispatch_redact_check.gd --png <path>   (the frame, and <path>_bare.png without)
##
## NOT `--headless`: the claims about pixels are measurements of a rendered frame.

const SIZE := Vector2i(1280, 720)
const EYE := Vector3(0.06, 0.025, 0.40)
const CURVE := 0.12

var _fails := 0
var _checks := 0
var _screens: DispatchScreens
var _vp: SubViewport
var _cam: Camera3D
var _glass: MeshInstance3D
var _censor: DispatchCensor


func _init() -> void:
	_run.call_deferred()


func _ok(cond: bool, what: String) -> void:
	_checks += 1
	if not cond:
		_fails += 1
		print("  FAIL: " + what)


static func _r(words: String) -> String:
	return DispatchScript.redacted("<!-- redact: %s -->" % words)


func _run() -> void:
	_screens = DispatchScreens.new()
	root.add_child(_screens)
	_screens.build(PackedStringArray(["A"]))
	_vp = SubViewport.new()
	_vp.size = SIZE
	_vp.own_world_3d = true
	_vp.transparent_bg = false
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.03, 0.03, 0.035)
	_cam = Camera3D.new()
	_cam.fov = 33.0
	_cam.environment = env
	_vp.add_child(_cam)
	_cam.current = true
	_cam.look_at_from_position(EYE, Vector3.ZERO, Vector3.UP)
	_glass = MeshInstance3D.new()
	_glass.mesh = DispatchSet.quad(DispatchSet.SCREEN)
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/dispatch_screen.gdshader")
	m.set_shader_parameter("has_face", true)
	m.set_shader_parameter("face", _screens.terminal.get_texture())
	m.set_shader_parameter("tint", DispatchScreens.PHOSPHOR.lerp(Color.WHITE, 0.2))
	for k in DispatchMedium.TERMINAL_GLASS:
		m.set_shader_parameter(String(k), DispatchMedium.TERMINAL_GLASS[k])
	_glass.material_override = m
	_vp.add_child(_glass)
	_censor = DispatchCensor.new()
	_vp.add_child(_censor)
	_ok(is_equal_approx(float(DispatchMedium.TERMINAL_GLASS["curve"]), CURVE), "the gate's bulge is the desk's")
	# each run last on its line: blanking one with spaces would move what follows it (the terminal's face kerns)
	var lines := PackedStringArray(["> open 1", "NAME ........ " + _r("DOE, JANE QUINCY"), "BIRTH ....... 01/02/1970",
		"PLATE ....... " + _r("XKC 4417"), "STATUS ...... CONTAINED", "",
		"  1  38   AKRON, OH   " + _r("DOE, JANE Q"), "  2  54   TULSA, OK   " + _r("DOE, JANE M"),
		"  3  19   BEND, OR    " + _r("DOE, JANE T")])
	var blank := PackedStringArray()
	var plain := PackedStringArray()
	for line in lines:
		var drawn := DispatchScript.unredacted(String(line))
		var text := String(drawn["text"])
		plain.append(text)
		for sp in drawn["spans"]:
			var run: Vector2i = sp
			text = text.substr(0, run.x) + " ".repeat(run.y - run.x) + text.substr(run.y)
		blank.append(text)
	var runs := _screens.redactions(lines)
	# THE BOXES ARE THE FRAME'S
	var groups := DispatchCensor.groups(runs)
	_ok(runs.size() == 5 and groups.size() == 3, "runs on lines next to each other are one box, a line apart two (%d runs, %d boxes)" % [runs.size(), groups.size()])
	_ok(_screens.redactions(plain).is_empty(), "the control: plain lines have no runs")
	var censored := await _frame(lines, true, 3.0)
	var bare := await _frame(lines, false, 3.0)
	var blanked := await _frame(blank, false, 3.0)
	var args := OS.get_cmdline_user_args()
	var at := args.find("--png")
	if at >= 0 and at + 1 < args.size():
		censored.save_png(args[at + 1])
		bare.save_png(args[at + 1].get_basename() + "_bare.png")
	var boxes: Array = _censor.boxes
	_ok(boxes.size() == 3, "a box over each group (%d)" % boxes.size())
	var larger := true
	for r in runs:
		var words := DispatchCensor.seen(r["rect"], _glass, CURVE, _cam)
		var held := false
		for b in boxes:
			held = held or (b["rect"] as Rect2).grow(-3.0).encloses(words)
		larger = larger and held
	_ok(larger, "a box holds the words as the camera sees them, with room round them")
	# NO LETTER OF THE REDACTED WORDS REACHES THE FRAME
	var ink := 0
	var loose := 0
	for y in SIZE.y:
		for x in SIZE.x:
			var a := bare.get_pixel(x, y)
			var b := blanked.get_pixel(x, y)
			if maxf(absf(a.r - b.r), maxf(absf(a.g - b.g), absf(a.b - b.b))) > 0.2:
				ink += 1
				if not _inside(boxes, Vector2(x, y) + Vector2(0.5, 0.5), 0.0):
					loose += 1
	_ok(ink >= 300, "the control: the redacted words light the frame (%d px) - the instrument sees them" % ink)
	_ok(loose == 0, "no letter of the redacted words reaches the frame: %d of their %d px outside the boxes" % [loose, ink])
	# EVERY SHARD ONE COLOR, THE AVERAGE OF THE FRAME UNDER IT
	var colors := {}
	var whole := 0
	var worst_spread := 0.0
	var worst_mean := 0.0
	var lettered := 0
	for bx in boxes:
		var shards := _shards(bx)
		for id in shards:
			var inner: Array = shards[id]["inner"]
			var all: Array = shards[id]["all"]
			if inner.size() < 20:
				continue
			whole += 1
			var lo := Color(1, 1, 1)
			var hi := Color(0, 0, 0)
			var bare_lo := 1.0
			var bare_hi := 0.0
			for p in inner:
				var c := censored.get_pixelv(p)
				lo = Color(minf(lo.r, c.r), minf(lo.g, c.g), minf(lo.b, c.b))
				hi = Color(maxf(hi.r, c.r), maxf(hi.g, c.g), maxf(hi.b, c.b))
				var g := bare.get_pixelv(p).g
				bare_lo = minf(bare_lo, g)
				bare_hi = maxf(bare_hi, g)
			worst_spread = maxf(worst_spread, maxf(hi.g - lo.g, maxf(hi.r - lo.r, hi.b - lo.b)))
			if bare_hi - bare_lo > 0.2:
				lettered += 1
			var mean := Color(0, 0, 0)
			for p in all:
				mean += bare.get_pixelv(p)
			mean /= float(all.size())
			var drawn := censored.get_pixelv(inner[inner.size() / 2])
			worst_mean = maxf(worst_mean, maxf(absf(drawn.g - mean.g), maxf(absf(drawn.r - mean.r), absf(drawn.b - mean.b))))
			colors[snappedf(drawn.g, 1.0 / 255.0)] = true
	_ok(whole >= 8, "too few whole shards to judge (%d)" % whole)
	_ok(worst_spread <= 2.0 / 255.0, "a shard is not one color: its pixels spread %.4f" % worst_spread)
	_ok(worst_mean <= 0.05, "a shard's color is not the average of the frame under it: off by %.4f" % worst_mean)
	_ok(lettered >= 3, "the control: in the frame without the censor, the shards hold letters (%d of %d)" % [lettered, whole])
	_ok(colors.size() >= 4, "the shards are nearly all one color (%d colors)" % colors.size())
	var same := true
	for y in range(0, SIZE.y, 2):
		for x in range(0, SIZE.x, 2):
			if not _inside(boxes, Vector2(x, y) + Vector2(0.5, 0.5), 1.5) and not censored.get_pixel(x, y).is_equal_approx(bare.get_pixel(x, y)):
				same = false
	_ok(same, "a pixel outside the boxes changed")
	# THE TRACKER: never short of the words, a beat behind a sudden move, wavering at rest, a function of show time
	var tr := DispatchCensor.new()
	var rest_x := PackedFloat32Array()
	var held_all := true
	var within := true
	for f in 60:
		var now := 10.0 + float(f) / 60.0
		tr.cover(runs, _glass, CURVE, _cam, now)
		held_all = held_all and _holds(tr, groups)
		var b0: Rect2 = tr.boxes[0]["rect"]
		var e0 := DispatchCensor.seen(groups[0]["rect"], _glass, CURVE, _cam)
		within = within and e0.grow(e0.size.y * DispatchCensor.WAVER + 1.0).encloses(b0)
		rest_x.append(b0.position.x)
	var again := DispatchCensor.new()
	again.cover(runs, _glass, CURVE, _cam, 10.0 + 59.0 / 60.0)
	_ok((again.boxes[0]["rect"] as Rect2).is_equal_approx(tr.boxes[0]["rect"]), "at rest, the same moment is the same box")
	_ok(rest_x[rest_x.size() - 1] != rest_x[0] or rest_x[30] != rest_x[0], "the box wavers at rest")
	_ok(within, "a box at rest stays within its waver of the words")
	var w_rest := (tr.boxes[0]["rect"] as Rect2).size.x
	var before := DispatchCensor.seen(groups[0]["rect"], _glass, CURVE, _cam)
	_cam.look_at_from_position(EYE + Vector3(0.025, 0.0, 0.0), Vector3(0.025, 0.0, 0.0) * 0.4, Vector3.UP)
	var after := DispatchCensor.seen(groups[0]["rect"], _glass, CURVE, _cam)
	var jump := absf(after.position.x - before.position.x)
	tr.cover(runs, _glass, CURVE, _cam, 11.0)
	held_all = held_all and _holds(tr, groups)
	var w_jump := (tr.boxes[0]["rect"] as Rect2).size.x
	for f in range(1, 31):
		tr.cover(runs, _glass, CURVE, _cam, 11.0 + float(f) / 60.0)
		held_all = held_all and _holds(tr, groups)
	var settled: Rect2 = tr.boxes[0]["rect"]
	_ok(jump >= 20.0 and w_jump >= w_rest + jump * 0.5,
		"a sudden move: the box trails a beat behind (%.1f px wide at rest, %.1f just after a %.1f px move)" % [w_rest, w_jump, jump])
	_ok(after.grow(after.size.y * DispatchCensor.WAVER + 1.0).encloses(settled), "half a second after the move, the box is back round the words")
	_ok(held_all, "a box was short of its words while the camera moved")
	tr.free()
	again.free()
	print("dispatch_redact_check: %s (%d checks, %d failure%s)" % ["ALL OK" if _fails == 0 else "FAILED", _checks, _fails, "" if _fails == 1 else "s"])
	quit(1 if _fails > 0 else 0)


## Does every box of [param c] hold its group's words as the camera sees them now?
func _holds(c: DispatchCensor, groups: Array) -> bool:
	if c.boxes.size() != groups.size():
		return false
	for i in groups.size():
		var e := DispatchCensor.seen(groups[i]["rect"], _glass, CURVE, _cam)
		if not (c.boxes[i]["rect"] as Rect2).grow(0.01).encloses(e):
			return false
	return true


static func _inside(boxes: Array, p: Vector2, grow: float) -> bool:
	for b in boxes:
		if (b["rect"] as Rect2).grow(grow).has_point(p):
			return true
	return false


## The frame with the terminal showing [param lines], the censor over it or not, read back.
func _frame(lines: PackedStringArray, censored: bool, now: float) -> Image:
	_screens.show_terminal({"lines": lines, "asleep": false, "cursor": false})
	if censored:
		_censor.cover(_screens.redactions(lines), _glass, CURVE, _cam, now)
	_censor.visible = censored and not _censor.boxes.is_empty()
	for i in 4:
		await process_frame
	return _vp.get_texture().get_image()


## THE SHARDS OF BOX [param b] as the shader cuts them: per shard, `all` (every pixel whose center is in it - what it
## averages) and `inner` (those 1.5 px from any crack or edge - what must be one color).
func _shards(b: Dictionary) -> Dictionary:
	var q: Rect2 = b["rect"]
	var lines: PackedVector3Array = _censor._cracks[int(b["key"])]["lines"]
	var scale := Vector2(float(b["aspect"]), 1.0) / q.size
	var out := {}
	for y in range(floori(q.position.y), ceili(q.end.y)):
		for x in range(floori(q.position.x), ceili(q.end.x)):
			var p := Vector2(x, y) + Vector2(0.5, 0.5)
			if not q.has_point(p):
				continue
			var id := DispatchCensor.shard(lines, (p - q.position) * scale)
			if not out.has(id):
				out[id] = {"all": [], "inner": []}
			(out[id]["all"] as Array).append(Vector2i(x, y))
			var interior := q.grow(-1.5).has_point(p)
			for d in [Vector2(1.5, 0), Vector2(-1.5, 0), Vector2(0, 1.5), Vector2(0, -1.5), Vector2(1.1, 1.1), Vector2(-1.1, -1.1), Vector2(1.1, -1.1), Vector2(-1.1, 1.1)]:
				interior = interior and DispatchCensor.shard(lines, (p + d - q.position) * scale) == id
			if interior:
				(out[id]["inner"] as Array).append(Vector2i(x, y))
	return out
