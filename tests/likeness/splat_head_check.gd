extends SceneTree

## splat_head_check - a head of splats is drawn as its numbers say ([SplatHead], `splat_head.gdshader`;
## next/likeness.md, "A head of splats"):
##
##   tests/run_quiet.sh splat_head_check
##
## NOT `--headless`: every claim is a rendered frame read back.
##
## A MADE AVATAR: one triangle and the head, 40 splats on them with random places, sizes (each much longer
## one way than another, so a turn shows), turns, colours and covers. Drawn by the shader, it must be what
## the same rules give pixel by pixel in GDScript: each splat's centre its frame's origin plus the unit times
## its place turned into the frame, its axes the frame's turned by its own, its footprint the top-left 2x2 of
## its covariance plus the low pass, cut at three sigmas along its axes; its alpha its cover times the
## falloff, at most 0.99, none under 1/255; the splats blended over in the order drawn. The trainer's rules
## (hosts/avatar/raster.py, held to its own reference by test_raster.py) are these.
##
## THE CONTROL: the same rules with every splat's turn transposed must NOT match - the comparison sees a
## turn. A second control moves the face: posed elsewhere, the triangle's splats must move with it.
##
## A SPLAT CHANGES WITH THE EXPRESSION: given one expression's shifts of place and colour, drawn at 0.8 of it,
## it must be the rules with 0.8 of each shift - its place moved, its colour's logit moved - taken only by a
## splat on a triangle, less the farther it stands from it (train.py's Splats.shift_weight); THE CONTROL: drawn
## at none, it must not.
##
## A BODY AND A LEANING TORSO: with a bone beside the face (a third of the splats on it) and the face carried by a
## torso turned and moved, it must be the rules with the face's frames carried so; a bone not seen must have its
## splats drawn clear. THE CONTROLS: the bone shown and not shown must differ, and so must the lean and none.
##
## THE BODY BENDS (train.py's `second_of`): the bone moved, and its splats each holding half of the still (a second
## influence, frame -1), each must stand half way between where the bone took it and where it stood - the rules
## so; THE CONTROL: the same move with no second influence must draw otherwise.

const SIZE := 96
const N := 40
## The made bone: where it stands, its axes and its unit.
const BONE_AT := Vector3(62, 30, 4)
const BONE_UNIT := 3.0

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
	var made := _avatar()
	var h: Dictionary = made[0]
	var arr: Dictionary = made[1]
	var shift := Vector3(48, 48, 0)
	var got := await _render(h, arr, shift)
	var want := _reference(h, arr, shift, false)
	var d := _diff(got, want)
	_ok(d.x < 1.5 and d.y < 24.0, "the shader's splats are not the rules': mean %.2f/255, worst %.1f/255" % [d.x, d.y])
	var turned := _diff(got, _reference(h, arr, shift, true))
	_ok(turned.x > 4.0, "CONTROL: with every turn transposed the rules still match (mean %.2f/255)" % turned.x)
	# the face moved: the shader follows it, and the old picture no longer matches
	var moved := Vector3(40, 52, 0)
	var got2 := await _render(h, arr, moved)
	var d2 := _diff(got2, _reference(h, arr, moved, false))
	_ok(d2.x < 1.5, "posed elsewhere, the shader's splats are not the rules': mean %.2f/255" % d2.x)
	_ok(_diff(got2, want).x > 4.0, "CONTROL: posed elsewhere, the picture did not move")
	# AN EXPRESSION'S SHIFTS: 0.8 of each, and none (the control)
	_shifts(h, arr)
	var ex := await _render(h, arr, shift, 0.8)
	var de := _diff(ex, _reference(h, arr, shift, false, 0.8))
	_ok(de.x < 1.5, "at 0.8 of an expression, the shader's splats are not the rules': mean %.2f/255" % de.x)
	var none := await _render(h, arr, shift, 0.0)
	_ok(_diff(none, _reference(h, arr, shift, false, 0.8)).x > 4.0, "CONTROL: with no expression the shifts still showed")
	# A BODY: a bone, a lean of the torso, the bone shown and not
	var made2 := _avatar(true)
	var h2: Dictionary = made2[0]
	var arr2: Dictionary = made2[1]
	var lean := Transform2D(deg_to_rad(6.0), Vector2(3, -2))
	var body := await _render(h2, arr2, shift, 0.0, lean, 1)
	var db := _diff(body, _reference(h2, arr2, shift, false, 0.0, lean, 1))
	_ok(db.x < 1.5, "a bone and a leaning torso: the shader's splats are not the rules': mean %.2f/255" % db.x)
	var hidden := await _render(h2, arr2, shift, 0.0, lean, 0)
	_ok(_diff(hidden, _reference(h2, arr2, shift, false, 0.0, lean, 0)).x < 1.5, "a bone not seen: its splats were drawn")
	# two drawings by the shader alike but for the bone's splats differ nowhere else: any difference is them
	var apart := _diff(hidden, body)
	_ok(apart.x > 0.2 and apart.y > 20.0, "CONTROL: a bone shown and not shown drew alike (mean %.2f/255, most %.1f/255)" % [apart.x, apart.y])
	_ok(_diff(body, _reference(h2, arr2, shift, false, 0.0, Transform2D.IDENTITY, 1)).x > 2.0,
		"CONTROL: the torso's lean moved nothing")
	# THE BODY BENDS: the bone moved, its splats half held by the still
	var move := Transform2D(deg_to_rad(-20.0), Vector2(-14, 10))
	var free := await _render(h2, arr2, shift, 0.0, Transform2D.IDENTITY, 1, move)
	var second := PackedFloat32Array()
	for i in N:
		second.append(1.0 + 0.98 * 0.5 if (arr2["bind"] as PackedInt32Array)[i] == 2 else 0.0)
	arr2["second"] = second
	var held := await _render(h2, arr2, shift, 0.0, Transform2D.IDENTITY, 1, move)
	var dh := _diff(held, _reference(h2, arr2, shift, false, 0.0, Transform2D.IDENTITY, 1, move))
	_ok(dh.x < 1.5, "the bone moved and its splats half held by the still: the shader's are not the rules': mean %.2f/255" % dh.x)
	var bent := _diff(held, free)
	_ok(bent.x > 0.2 and bent.y > 20.0, "CONTROL: held by the still or not, the moved bone's splats drew alike (mean %.2f/255, most %.1f/255)"
		% [bent.x, bent.y])
	print("    the splats against the rules: mean %.2f/255, worst %.1f/255 (transposed turns: %.2f); at 0.8 of an expression %.2f/255; with a bone and a lean %.2f/255"
		% [d.x, d.y, turned.x, de.x, db.x])
	print("splat_head_check: %s (%d checks, %d failure%s)" % ["ALL OK" if _fails == 0 else "FAILED", _checks, _fails,
		"" if _fails == 1 else "s"])
	quit(1 if _fails > 0 else 0)


## The made avatar: [header, arrays] as [method SplatHead.take] takes them.
func _avatar(with_bone := false) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var canon := PackedFloat32Array([-18, -16, 0, 20, -12, 3, -2, 22, -2])
	var basis := PackedFloat32Array()
	basis.resize(52 * 9)
	var bind := PackedInt32Array()
	var place := PackedFloat32Array()
	var log_scale := PackedFloat32Array()
	var turn := PackedFloat32Array()
	var colour := PackedFloat32Array()
	var cover := PackedFloat32Array()
	for i in N:
		bind.append(i % 3 if with_bone else i % 2)
		for a in 3:
			place.append(rng.randfn(0.0, 0.5 if i % 2 == 0 else 1.6))
		var s := rng.randf_range(0.08, 0.3) if i % 2 == 0 else rng.randf_range(0.4, 1.4)
		log_scale.append_array(PackedFloat32Array([log(s * 2.5), log(s * 0.6), log(s)]))
		var q := Quaternion(rng.randfn(), rng.randfn(), rng.randfn(), rng.randfn()).normalized()
		turn.append_array(PackedFloat32Array([q.w, q.x, q.y, q.z]))
		colour.append_array(PackedFloat32Array([rng.randf(), rng.randf(), rng.randf()]))
		cover.append(rng.randf_range(0.4, 0.95))
	var h := {"splats": N, "verts": 3, "scores": 52, "head_unit": 4.0, "crop": [0, 0, SIZE], "size": SIZE,
		"bones": 1 if with_bone else 0}
	var arr := {"bind": bind, "place": place, "log_scale": log_scale, "turn": turn, "colour": colour,
		"cover": cover, "canon": canon, "basis": basis, "tris": PackedInt32Array([0, 1, 2])}
	return [h, arr]


## One expression's shifts for every splat: of its place (in its frame's units) and of its colour's logit.
func _shifts(h: Dictionary, arr: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var pd := PackedFloat32Array()
	var cd := PackedFloat32Array()
	for i in N:
		for c in 3:
			pd.append(rng.randfn(0.0, 0.6 if i % 2 == 0 else 1.0))
			cd.append(rng.randfn(0.0, 1.5))
	h["expressions"] = 1
	arr["place_d"] = pd
	arr["colour_d"] = cd


## The made bone's axes: turned 25 degrees in the picture.
static func _bone_axes() -> Basis:
	return Basis(Vector3(0, 0, 1), deg_to_rad(25.0))


func _render(h: Dictionary, arr: Dictionary, shift: Vector3, expr := 0.0, torso := Transform2D.IDENTITY,
		shown := 1, move := Transform2D.IDENTITY) -> Image:
	var vp := SubViewport.new()
	vp.size = Vector2i(SIZE, SIZE)
	vp.disable_3d = true
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var bg := ColorRect.new()
	bg.color = Color.BLACK
	bg.size = Vector2(SIZE, SIZE)
	vp.add_child(bg)
	var head := SplatHead.new()
	head.take(h, arr)
	var blend := PackedFloat32Array()
	blend.resize(52)
	head.pose_face(head.face_of(blend), 1.0, Basis.IDENTITY, shift, torso)
	if int(h.get("bones", 0)) > 0:
		head.pose_bones(PackedVector3Array([BONE_AT]), [_bone_axes()], PackedFloat32Array([BONE_UNIT]),
			[move], PackedByteArray([shown]))
	head.upload()
	head.set_expr(PackedFloat32Array([expr]))
	vp.add_child(head)
	root.add_child(vp)
	for i in 4:
		await process_frame
	var got := vp.get_texture().get_image()
	got.convert(Image.FORMAT_RGB8)
	vp.queue_free()
	return got


## THE RULES IN GDSCRIPT: every pixel, the splats blended over in order, each placed and shaped as
## splat_head.gdshader places it - or, [param transposed], with its turn transposed (the control).
func _reference(h: Dictionary, arr: Dictionary, shift: Vector3, transposed: bool, expr := 0.0,
		torso := Transform2D.IDENTITY, shown := 1, move := Transform2D.IDENTITY) -> Image:
	var canon: PackedFloat32Array = arr["canon"]
	var p0 := SplatHead._carried(torso, Vector3(canon[0], canon[1], canon[2]) + shift)
	var p1 := SplatHead._carried(torso, Vector3(canon[3], canon[4], canon[5]) + shift)
	var p2 := SplatHead._carried(torso, Vector3(canon[6], canon[7], canon[8]) + shift)
	var e1 := (p1 - p0).normalized()
	var nn := (p1 - p0).cross(p2 - p0).normalized()
	var e2 := nn.cross(e1)
	var frames := [[(p0 + p1 + p2) / 3.0, Basis(e1, e2, nn), ((p1 - p0).length() + (p2 - p1).length() + (p0 - p2).length()) / 3.0],
		[SplatHead._carried(torso, shift), Basis(SplatHead._turned(torso, Vector3.RIGHT), SplatHead._turned(torso, Vector3.UP),
			SplatHead._turned(torso, Vector3.BACK)), float(h["head_unit"])],
		[SplatHead._carried(move, BONE_AT), Basis(SplatHead._turned(move, _bone_axes().x), SplatHead._turned(move,
			_bone_axes().y), SplatHead._turned(move, _bone_axes().z)), BONE_UNIT * sqrt(absf(move.determinant()))]]
	var shapes: Array = []
	for i in N:
		if (arr["bind"] as PackedInt32Array)[i] == 2 and shown == 0:
			continue
		var f: Array = frames[(arr["bind"] as PackedInt32Array)[i]]
		var place: PackedFloat32Array = arr["place"]
		var ls: PackedFloat32Array = arr["log_scale"]
		var tq: PackedFloat32Array = arr["turn"]
		var q := Quaternion(tq[i * 4 + 1], tq[i * 4 + 2], tq[i * 4 + 3], tq[i * 4]).normalized()
		var own := Basis(q)
		if transposed:
			own = own.transposed()
		var ax: Basis = f[1]
		var unit := float(f[2])
		var at := Vector3(place[i * 3], place[i * 3 + 1], place[i * 3 + 2])
		var col: PackedFloat32Array = arr["colour"]
		var tint := Vector3(col[i * 3], col[i * 3 + 1], col[i * 3 + 2])
		if int(h.get("expressions", 0)) > 0:
			var pd: PackedFloat32Array = arr["place_d"]
			var cd: PackedFloat32Array = arr["colour_d"]
			var on_triangle := (arr["bind"] as PackedInt32Array)[i] < 1
			var w := (1.0 - smoothstep(1.0, 2.0, at.length())) if on_triangle else 0.0
			at += w * expr * Vector3(pd[i * 3], pd[i * 3 + 1], pd[i * 3 + 2])
			for c in 3:
				var x := clampf(tint[c], 1e-4, 1.0 - 1e-4)
				tint[c] = 1.0 / (1.0 + exp(-(log(x / (1.0 - x)) + w * expr * cd[i * 3 + c])))
		var mean: Vector3 = f[0] + unit * (ax * at)
		# a second influence: where it stood in the still, moved by the other bone or not at all (frame -1 here)
		var sec: float = (arr["second"] as PackedFloat32Array)[i] if arr.has("second") else 0.0
		if sec > 0.5:
			var w := fposmod(sec, 1.0) / 0.98
			var rest := move.affine_inverse() * Vector2(mean.x, mean.y)
			var blended := Vector2(mean.x, mean.y).lerp(rest, w)
			mean = Vector3(blended.x, blended.y, mean.z)
		var r := ax * own
		var s := unit * Vector3(exp(ls[i * 3]), exp(ls[i * 3 + 1]), exp(ls[i * 3 + 2]))
		var m := Basis(r.x * s.x, r.y * s.y, r.z * s.z)
		var cov := m * m.transposed()
		var sa := cov.x.x + 0.3
		var sb := cov.x.y
		var sc := cov.y.y + 0.3
		var det := maxf(sa * sc - sb * sb, 1e-12)
		var mid := 0.5 * (sa + sc)
		var disc := sqrt(maxf(mid * mid - det, 0.0))
		var l1 := mid + disc
		var l2 := maxf(mid - disc, 1e-6)
		var v1 := Vector2(sb, l1 - sa).normalized() if absf(sb) > 1e-9 else (Vector2(1, 0) if sa >= sc else Vector2(0, 1))
		shapes.append({"mean": Vector2(mean.x, mean.y), "conic": Vector3(sc, -sb, sa) / det, "v1": v1,
			"r1": 3.0 * sqrt(l1), "r2": 3.0 * sqrt(l2), "cover": (arr["cover"] as PackedFloat32Array)[i],
			"col": tint})
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGB8)
	for y in SIZE:
		for x in SIZE:
			var c := Vector3.ZERO
			var px := Vector2(x + 0.5, y + 0.5)
			for sh in shapes:
				var d: Vector2 = px - sh["mean"]
				var v1: Vector2 = sh["v1"]
				if absf(d.dot(v1)) > float(sh["r1"]) or absf(d.dot(Vector2(-v1.y, v1.x))) > float(sh["r2"]):
					continue
				var k: Vector3 = sh["conic"]
				var power := -0.5 * (k.x * d.x * d.x + 2.0 * k.y * d.x * d.y + k.z * d.y * d.y)
				var alpha := minf(0.99, float(sh["cover"]) * exp(power))
				if power > 0.0 or alpha < 1.0 / 255.0:
					continue
				c = c * (1.0 - alpha) + (sh["col"] as Vector3) * alpha
			img.set_pixel(x, y, Color(c.x, c.y, c.z))
	return img


## The mean and the largest absolute difference of two pictures, in 1/255s.
static func _diff(a: Image, b: Image) -> Vector2:
	var total := 0.0
	var worst := 0.0
	for y in SIZE:
		for x in SIZE:
			var p := a.get_pixel(x, y)
			var q := b.get_pixel(x, y)
			var e := (absf(p.r - q.r) + absf(p.g - q.g) + absf(p.b - q.b)) / 3.0
			total += e
			worst = maxf(worst, e)
	return Vector2(total / (SIZE * SIZE) * 255.0, worst * 255.0)
