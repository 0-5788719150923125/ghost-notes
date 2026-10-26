extends SceneTree

## coarticulation_check - the mouth a Likeness's voice wants ([Visemes]): every phone pulls toward its
## class's shape with a dominance that falls off round its center (Cohen and Massaro, 1993), and the
## mouth is the pulls' weighted mean.
##
##   godot --headless --path . --script tests/likeness/coarticulation_check.gd
##
## A FAST "AA M AA" CLOSES THE LIPS AT M'S CENTER: the lips' strong, quick hold wins its moment over the
## open vowels round it, so the jaw there is near M's own and far from the vowels'. The control sets M's
## dominance to nothing, and the jaw there must stay open.
##
## THE VOICE'S SYMBOLS FIND THEIR CLASSES: ghost's ARPAbet (stress digits and all) and Piper's IPA, and
## a mark or a pause is no class. A silence between phones is a rest.
##
## THE TWO MOUTHS DRAWN ([Visemes.strongest]) - at M's center M's own, and in fast speech never a jump:
## stepped a tenth of a millisecond at a time, each phone's share of the drawn mouth moves by little (in
## fast speech one mouth gives way to the next in some 15 ms, so a millisecond's step is no test of a
## jump), since the two strongest pulls are each less the third's. The control is the plain two
## strongest, which must jump as a third overtakes one, however small the step.
##
## THE SPLATS' MOUTH MOVES SMOOTHLY FRAME BY FRAME ([Visemes.mix], 2026-10-24: the two strongest, played on a
## head of splats, morphed "at EXACTLY the same time every phoneme changes"): on the quick phrase at 30 frames a
## second, from every phase, no sound's share moves more than 0.4 from one frame to the next, and at M's center
## in the fast "AA M AA" the lips' share is still most of it. The control is the two strongest at the same
## frames, which must move a share by more than 0.6 - the jump the check is for.
##
## THE LEARNED MOUTH IS READ AS IT WAS TRAINED ([LikenessPlan], actor.py's `contexts`): a made network of one
## neuron that opens the jaw by tanh of how much of "open" fills the window - a window full of it gives
## tanh(1), half of it tanh(0.5), silence nothing; and the inputs of a moment's every window sum to one.
##
## THEIR OWN MOUTH FOR EACH SOUND ([LikenessMedium.own_mouths], a head of splats): pushed by Articulation, never
## past how far their own lips part, nor a score past their own top (see `_own_mouths`), nor folding the face's
## triangles past FOLD_MOST (see `_unfolded`; its control, the turn unheld).
##
## THE BREATH GOES ON FROM WHERE IT WAS ([LikenessPlan.breath]): over speech with pauses long and short, it
## never moves more than a little in a millisecond - and it does move (its control: it spans most of its
## range, so the check is no flat line's).

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
	# the classes
	_ok(Visemes.class_of("M") == "pbm" and Visemes.class_of("AA1") == "open" and Visemes.class_of("m") == "pbm"
		and Visemes.class_of("ɑ") == "open" and Visemes.class_of("ð") == "th" and Visemes.class_of("tʃ") == "sh",
		"a phone found the wrong class")
	_ok(Visemes.class_of(",") == "" and Visemes.class_of(" ") == "", "a mark or a space found a class")
	var gap := Visemes.timeline([{"p": "AA", "t0": 0.0, "t1": 0.1}, {"p": "AA", "t0": 0.5, "t1": 0.6}])
	_ok(gap.size() == 3 and String(gap[1]["c"]) == "rest", "a silence between phones is not a rest: %s" % str(gap))
	# a shape per class: the jaw (index 0) wide for the vowel, shut for the lips
	var n := 3
	var targets := {}
	for k in Visemes.REGISTRY:
		targets[k] = PackedFloat32Array([0.3, 0.3, 0.3])
	targets["open"] = PackedFloat32Array([0.8, 0.0, 0.0])
	targets["pbm"] = PackedFloat32Array([0.02, 0.9, 0.0])
	targets["rest"] = PackedFloat32Array([0.05, 0.5, 0.0])
	# a fast "AA M AA": 90 ms a phone
	var phones := [{"p": "AA", "t0": 0.0, "t1": 0.09}, {"p": "M", "t0": 0.09, "t1": 0.18}, {"p": "AA", "t0": 0.18, "t1": 0.27}]
	var line := Visemes.timeline(phones)
	var at_m := Visemes.blend_at(0.135, line, targets, n)
	var at_aa := Visemes.blend_at(0.045, line, targets, n)
	_ok(at_m[0] < 0.25, "the jaw at M's center is %.3f open - the lips do not close in fast speech" % at_m[0])
	_ok(at_aa[0] > 0.5, "the jaw at the first vowel is only %.3f open" % at_aa[0])
	_ok(at_m[1] > 0.6, "the lips at M's center press %.3f - not shut" % at_m[1])
	# THE CONTROL: M with no hold, and the jaw at its center stays the vowels'
	var rows: Dictionary = Visemes.REGISTRY.duplicate(true)
	(rows["pbm"] as Dictionary)["strength"] = 0.0
	var weak := Visemes.blend_at(0.135, line, targets, n, 0, rows)
	_ok(weak[0] > 0.5, "with M's dominance at nothing the jaw at its center still closed (%.3f): the check cannot fail" % weak[0])
	# FAR FROM EVERY PHONE, THE REST
	var far := Visemes.blend_at(5.0, line, targets, n)
	_ok(absf(far[0] - 0.05) < 1e-3, "far from every phone the mouth is not at rest: %s" % str(far))
	# A PURE FUNCTION: asked from anywhere in the line, the same mouth
	var from_start := Visemes.blend_at(0.2, line, targets, n, 0)
	var from_end := Visemes.blend_at(0.2, line, targets, n, line.size())
	_ok(from_start == from_end, "the mouth at a moment depends on where the search began")
	# THE TWO MOUTHS DRAWN
	var top := Visemes.strongest(0.135, line)
	_ok(String(top[0][1]) == "pbm" and float(top[0][2]) > 0.6, "the mouth drawn at M's center is not M's: %s" % str(top))
	var quick: Array = []
	var t0 := 0.0
	for p in ["S", "AH", "M", "IY", "V", "N", "IH", "NG", "Z", "AO", "B", "ER"]:
		quick.append({"p": p, "t0": t0, "t1": t0 + 0.055})
		t0 += 0.055
	var ql := Visemes.timeline(quick)
	var worst := 0.0
	var plain := 0.0
	var was := {}
	var was_plain := {}
	for i in int(t0 * 10000.0):
		var t := float(i) * 0.0001
		var now := _shares(Visemes.strongest(t, ql))
		var all := Visemes.pulls(t, ql)
		all.sort_custom(func(a: Array, b: Array) -> bool: return float(a[2]) > float(b[2]))
		var now_plain := _shares(all.slice(0, 2), true)
		if i > 0:
			worst = maxf(worst, _jump(was, now))
			plain = maxf(plain, _jump(was_plain, now_plain))
		was = now
		was_plain = now_plain
	_ok(worst < 0.02, "a phone's share of the drawn mouth jumped %.3f in a tenth of a millisecond" % worst)
	_ok(plain > 0.15, "the plain two strongest jumped only %.3f: the check cannot fail" % plain)
	# THE SPLATS' MOUTH, FRAME BY FRAME
	var m_at := Visemes.mix(0.135, line)
	_ok(float(m_at.get("pbm", 0.0)) > 0.7, "the lips' share at M's center in fast speech is only %.3f" % float(m_at.get("pbm", 0.0)))
	var frame_mix := 0.0
	var frame_two := 0.0
	for ph in 10:
		var was_m := {}
		var was_two := {}
		var tf := float(ph) / 300.0
		while tf < t0:
			var m := Visemes.mix(tf, ql)
			var two := {}
			for q in Visemes.strongest(tf, ql):
				two[String(q[1])] = float(two.get(String(q[1]), 0.0)) + float(q[2])
			if not was_m.is_empty():
				frame_mix = maxf(frame_mix, _jump(was_m, m))
				frame_two = maxf(frame_two, _jump(was_two, two))
			was_m = m
			was_two = two
			tf += 1.0 / 30.0
	_ok(frame_mix < 0.4, "a sound's share of the splats' mouth moved %.3f from one frame to the next" % frame_mix)
	_ok(frame_two > 0.6, "the two strongest moved a share only %.3f a frame: the check cannot fail" % frame_two)
	# THE LEARNED MOUTH, as trained
	var plan := LikenessPlan.new()
	plan._classes = ["rest", "open"]
	plan._offsets = PackedFloat32Array([0.0])
	plan._window = 0.06
	plan._mean = PackedFloat32Array([0.0, 0.0])
	plan._sd = PackedFloat32Array([1.0, 1.0])
	plan._members = [{"w1": PackedFloat32Array([0.0, 1.0]), "b1": PackedFloat32Array([0.0]),
		"w2": PackedFloat32Array([1.0, 0.0]), "b2": PackedFloat32Array([0.0, 0.0]), "hidden": 1}]
	plan.set_voice([{"p": "AA", "t0": 1.0, "t1": 1.5}])
	var full := plan._predict(plan._inputs(1.2))
	var half := plan._predict(plan._inputs(1.5))
	var none := plan._predict(plan._inputs(3.0))
	_ok(absf(full[0] - tanh(1.0)) < 1e-4 and absf(half[0] - tanh(0.5)) < 1e-3 and absf(none[0]) < 1e-6,
		"the learned mouth is not read as it was trained: %.4f, %.4f, %.4f (want %.4f, %.4f, 0)" % [full[0], half[0], none[0], tanh(1.0), tanh(0.5)])
	var shares := plan._inputs(1.47)
	var sum := 0.0
	for i in shares:
		sum += float(shares[i])
	_ok(absf(sum - 1.0) < 1e-4, "a moment's window shares sum to %.4f, not one" % sum)
	# THE BREATH
	var talk := LikenessPlan.new()
	var said: Array = []
	var at := 0.8
	for k in 60:
		said.append({"p": "AA", "t0": at, "t1": at + 0.12})
		at += 0.12 + (0.6 if k % 9 == 8 else (0.25 if k % 4 == 3 else 0.0))
	talk.set_voice(said)
	var lo_b := 1.0
	var hi_b := 0.0
	var step := 0.0
	var last := talk.breath(0.0)
	for i in range(1, int(at * 1000.0) + 2000):
		var b := talk.breath(float(i) * 0.001)
		step = maxf(step, absf(b - last))
		lo_b = minf(lo_b, b)
		hi_b = maxf(hi_b, b)
		last = b
	_ok(step < 0.01, "the breath jumped %.3f in a millisecond" % step)
	_ok(hi_b - lo_b > 0.3, "the breath only spans %.2f: the check is a flat line's" % (hi_b - lo_b))
	_own_mouths()
	_unfolded()
	print("coarticulation_check: %s (%d checks, %d failure%s)" % ["ALL OK" if _fails == 0 else "FAILED", _checks, _fails, "" if _fails == 1 else "s"])
	quit(1 if _fails > 0 else 0)


## THEIR OWN MOUTH FOR EACH SOUND ([method LikenessMedium.own_mouths]): on a made face (the forehead's top at 0, the
## chin 100 below, the inner lips 2 apart - parted 0.02 of its height) whose expression is the jaw's score alone, a
## sound that parts the lips 3 more, pushed 3 times, stops where their own lips part most (0.08), and its jaw
## score is pushed as far; one that closes them stops at their least (0.004); pushed once, a sound is their own
## move; the rest moves nothing; a score never goes past their own top. THE CONTROL: with their range anything, the
## same push opens it past their most.
func _own_mouths() -> void:
	var s := SplatHead.new()
	s.verts = 479
	s.scores = 52
	s.canon.resize(479 * 3)
	s.canon[10 * 3 + 1] = 0.0
	s.canon[152 * 3 + 1] = 100.0
	s.canon[13 * 3 + 1] = 60.0
	s.canon[14 * 3 + 1] = 62.0
	s.basis.resize(52 * 479 * 3)
	var jaw := SplatHead.SCORES.find("jawOpen")
	s.expressions = 1
	s.expr_mean.resize(52)
	s.expr_basis.resize(52)
	s.expr_basis[jaw] = 1.0
	s.expr_scale = PackedFloat32Array([1.0])
	var still: Array = []
	for i in 479:
		still.append([0.0, 0.0, 0.0])
	var open := still.duplicate(true)
	open[14] = [0.0, 3.0, 0.0]
	var shut := still.duplicate(true)
	shut[14] = [0.0, -1.5, 0.0]
	var blend: Array = []
	blend.resize(52)
	blend.fill(0.0)
	var opened := blend.duplicate()
	opened[jaw] = 0.1
	var mouths := {"gap": [0.004, 0.08], "sounds": {"rest": {"points": still, "blend": blend},
		"open": {"points": open, "blend": opened}, "pbm": {"points": shut, "blend": blend}}}
	var base := PackedFloat32Array()
	base.resize(52)
	var got := LikenessMedium.own_mouths(s, base, mouths, 3.0, {jaw: 0.5})
	var parted := func(c: String) -> float: return LikenessMedium.lips_parted(got["faces"][c])
	_ok(absf(parted.call("open") - 0.08) < 1e-4, "a sound pushed past their most parts the lips %.4f, not 0.08" % parted.call("open"))
	_ok(absf(float(got["exprs"]["open"][0]) - 0.2) < 1e-4, "its jaw score is %.3f, not pushed as far (0.2)" % float(got["exprs"]["open"][0]))
	_ok(absf(parted.call("pbm") - 0.004) < 1e-4, "a sound that closes the lips stops at %.4f, not their least" % parted.call("pbm"))
	_ok(absf(parted.call("rest") - 0.02) < 1e-6, "the rest moves the lips")
	var once := LikenessMedium.own_mouths(s, base, mouths, 1.0, {jaw: 0.5})
	_ok(absf(LikenessMedium.lips_parted(once["faces"]["open"]) - 0.05) < 1e-4, "pushed once, a sound is not their own move")
	(mouths["sounds"]["open"]["blend"] as Array)[jaw] = 0.5
	var high := LikenessMedium.own_mouths(s, base, mouths, 3.0, {jaw: 0.3})
	_ok(absf(float(high["exprs"]["open"][0]) - 0.3) < 1e-4, "a score went past their own top: %.3f" % float(high["exprs"]["open"][0]))
	mouths["gap"] = [0.0, 1.0]
	var free := LikenessMedium.own_mouths(s, base, mouths, 3.0, {jaw: 0.5})
	_ok(LikenessMedium.lips_parted(free["faces"]["open"]) > 0.1, "CONTROL: with their range anything, the push did not open it past their most")
	s.free()


## A SOUND'S MOUTH NEVER FOLDS THE FACE ([method LikenessMedium.unfolded]): a triangle whose corner its move lifts 5 a
## push, 10 from the others, turns atan(w / 2) - pushed 3 it would turn 56 degrees, so it stops where it turns
## FOLD_MOST (w = 2 tan 40 = 1.678); pushed once (27 degrees) it is as pushed; a triangle the move does not touch
## never stops it.
func _unfolded() -> void:
	var tris := PackedInt32Array([0, 1, 2, 3, 4, 5])
	var face := PackedFloat32Array([0, 0, 0, 10, 0, 0, 0, 10, 0, 20, 0, 0, 30, 0, 0, 20, 10, 0])
	var move := PackedFloat32Array([0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0])
	var most := 2.0 * tan(deg_to_rad(LikenessMedium.FOLD_MOST))
	var at3 := LikenessMedium.unfolded(tris, face, move, 3.0)
	_ok(at3 <= most + 1e-4 and at3 > most - 3.0 / 256.0 - 1e-4, "pushed 3, a folding mouth stops at %.3f, not %.3f" % [at3, most])
	_ok(absf(LikenessMedium.unfolded(tris, face, move, 1.0) - 1.0) < 1e-6, "pushed once, within the fold, it is as pushed")
	var turned := rad_to_deg(atan(3.0 * 5.0 / 10.0))
	_ok(turned > LikenessMedium.FOLD_MOST, "CONTROL: pushed 3 it would turn %.0f degrees, past %.0f" % [turned, LikenessMedium.FOLD_MOST])
	var flat := PackedFloat32Array(move)
	flat[8] = 0.0
	flat[17] = 50.0
	flat.resize(18)
	var other := PackedInt32Array([0, 1, 2])
	_ok(absf(LikenessMedium.unfolded(other, face, flat, 3.0) - 3.0) < 1e-6, "a triangle the move does not touch never stops it")


## Each phone's share of a mix of pulls (`[[k, class, weight]]`), by its place in the line - [param
## norm] makes the weights sum to 1 first.
static func _shares(mix: Array, norm := false) -> Dictionary:
	var total := 0.0
	for p in mix:
		total += float(p[2])
	var out := {}
	for p in mix:
		out[int(p[0])] = float(out.get(int(p[0]), 0.0)) + float(p[2]) / (total if norm and total > 0.0 else 1.0)
	return out


## The most any phone's share moved from [param a] to [param b].
static func _jump(a: Dictionary, b: Dictionary) -> float:
	var most := 0.0
	for k in a.keys() + b.keys():
		most = maxf(most, absf(float(a.get(k, 0.0)) - float(b.get(k, 0.0))))
	return most
