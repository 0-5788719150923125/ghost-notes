extends SceneTree

## Does the BELT COMPOSE, or only select?
##
## The question this answers, in the user's words: if the first seed does not
## sing, can a second one added to the belt bring that mode in, and can a third
## modulate it further? Before the ensemble, a throw was a jittered copy of
## exactly ONE parent, so the answer was no - adding a singer only added a
## lottery ticket, and no third seed could touch a mode a second had brought.
##
## Asked of the code the editor throws with, [method VoiceParty.ensemble_traits]
## and [method VoiceParty.sustain_bank] - pure, so it runs headless without
## booting the game. A weight is the function's own draw, so what a belt CAN
## make is read over many seeds of its generator.
##
## THE CONTROLS, one a claim: a belt of one seed has nothing to compose with, so
## it must NOT reach a singing child; a contributor that is the voice itself only
## turns its cycle up, so its held positions must be the SAME; and a contributor's
## order must still be drawn - it must differ from lineage to lineage - or "the
## same lineage composes the same way" proves nothing.
##
## Run: godot --headless --path . --script tests/voice/ensemble_check.gd

## The most a field lets in (`reach` 0.8): a weight's draw decides, not the gate.
const NEAR := {"vec": Vector3.ZERO, "energy": 1.0, "prox": 0.0, "freq": 400.0}
const SEEDS := 300


func _init() -> void:
	var fails := 0
	fails += _check_inherit()
	fails += _check_third_modulates()
	fails += _check_subtracts()
	fails += _check_bounded()
	fails += _check_no_collapse()
	fails += _check_sustain_positions()
	fails += _check_order_is_the_lineage()
	if fails == 0:
		print("ensemble_check: ALL OK")
	else:
		print("ensemble_check: %d FAILURE(S)" % fails)
	quit(fails)


## A belt entry the way the editor keeps one, every member equally accepted.
func _seed(root: int, traits: Dictionary) -> Dictionary:
	return {"lineage": [root], "traits": traits, "genome": {}, "scene": "",
		"m": {"s": 0.0, "acts": 1, "restores": 0, "evolves": 0, "catches": 0, "r": 0.5, "d": 0.35}}


## The child's song for a belt whose first entry leads, the weights drawn by `s`.
func _child_song(belt: Array, s: int, field: Dictionary = NEAR) -> float:
	var rng := RandomNumberGenerator.new()
	rng.seed = s
	var r := VoiceParty.ensemble_traits(belt[0], rng, belt, field)
	return float((r.traits as Dictionary).song)


func _reach(belt: Array) -> Vector2:
	var lo := INF
	var hi := -INF
	for s in SEEDS:
		var song := _child_song(belt, s)
		lo = minf(lo, song)
		hi = maxf(hi, song)
	return Vector2(lo, hi)


## A non-singing dominant, one singer on the belt: the child must be able to
## come out singing (song > 0) for some draw. THE CONTROL: the dominant alone.
func _check_inherit() -> int:
	var best := _reach([_seed(1, {"song": -0.6}), _seed(2, {"song": 0.9})]).y
	var alone := _reach([_seed(1, {"song": -0.6})]).y
	var ok: bool = best > 0.0 and alone <= 0.0
	print("ensemble_check: non-singer (-0.60) + singer (0.90) -> best reachable song %.2f; alone %.2f %s" % [
		best, alone, "ok - the mode can be inherited" if ok else "FAIL - cannot cross zero, or crosses it alone"])
	return 0 if ok else 1


## A third contributor must be able to move it FURTHER than the second alone.
func _check_third_modulates() -> int:
	var two := _reach([_seed(1, {"song": -0.6}), _seed(2, {"song": 0.9})]).y
	var three := _reach([_seed(1, {"song": -0.6}), _seed(2, {"song": 0.9}), _seed(3, {"song": 0.8})]).y
	var ok: bool = three > two + 0.05
	print("ensemble_check: second seed -> %.2f, third pushes it to %.2f %s" % [
		two, three, "ok - further modulation" if ok else "FAIL - third contributes nothing"])
	return 0 if ok else 1


## And it must be able to move it DOWN. Combination that can only ever add is
## how a collection converges on one voice.
func _check_subtracts() -> int:
	var span := _reach([_seed(1, {"song": 0.5}), _seed(2, {"song": 0.9})])
	var ok: bool = span.x < 0.5 and span.y > 0.5
	print("ensemble_check: singer (0.50) with a singer (0.90) -> %.2f .. %.2f %s" % [
		span.x, span.y, "ok - signed weights subtract" if ok else "FAIL - cannot reduce"])
	return 0 if ok else 1


## A combination is a perturbation of one parent: at most ENSEMBLE_MAX members
## contribute, each weight inside ENSEMBLE_W times the most acceptance can give it.
func _check_bounded() -> int:
	var belt: Array = []
	for i in 6:
		belt.append(_seed(10 + i, {"song": 0.3 * i - 0.8}))
	var most := 0
	var heaviest := 0.0
	for s in SEEDS:
		var rng := RandomNumberGenerator.new()
		rng.seed = s
		var c: Array = VoiceParty.ensemble_traits(belt[0], rng, belt, NEAR).contributions
		most = maxi(most, c.size())
		for k in c:
			heaviest = maxf(heaviest, absf(float(k.w)))
	var ok: bool = most == VoiceParty.ENSEMBLE_MAX and heaviest <= VoiceParty.ENSEMBLE_W * 1.6
	print("ensemble_check: six seeds -> at most %d contributors (max %d), heaviest |w| %.3f (bound %.3f) %s" % [
		most, VoiceParty.ENSEMBLE_MAX, heaviest, VoiceParty.ENSEMBLE_W * 1.6,
		"ok - bounded" if ok else "FAIL - unbounded, or never full"])
	return 0 if ok else 1


## The guard: composing must NOT be averaging. Over many random belts the
## children's spread has to stay comparable to the parents' - if it collapses,
## every catch drifts toward the belt mean and the game stops making new voices.
func _check_no_collapse() -> int:
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var parents: Array = []
	var kids: Array = []
	for i in 4000:
		var belt: Array = [_seed(1, {"song": rng.randf_range(-1.0, 1.0)})]
		for k in 1 + rng.randi() % 3:
			belt.append(_seed(2 + k, {"song": rng.randf_range(-1.0, 1.0)}))
		parents.append(float(belt[0].traits.song))
		kids.append(_child_song(belt, i,
			{"vec": Vector3.ZERO, "energy": rng.randf(), "prox": 0.0, "freq": 400.0}))
	var ok: bool = _sd(kids) > _sd(parents) * 0.8
	print("ensemble_check: parent spread %.3f -> child spread %.3f (need > 80%%) %s" % [
		_sd(parents), _sd(kids), "ok - composes without collapsing" if ok else "FAIL - regresses to the mean"])
	return 0 if ok else 1


## THE POINT OF THE BANK: contributors must change WHERE a voice sings, not
## only how much. Two banks with the same total weight must hold a different
## SET of syllables - if adding a seed only scaled the drive, the held
## positions would be identical and the belt would just be a volume knob.
## THE CONTROL: a contributor with the voice's own cycle holds the same places.
func _check_sustain_positions() -> int:
	var own := {"song": 0.8, "drawl": 0.2}
	var other := {"drawl": 0.7, "pace": -0.2, "lilt": 0.3, "grit": -0.1}
	var solo := _peaks(own, [])
	var b := _peaks(own, [{"traits": other, "w": 0.5}])
	var c := _peaks(own, [{"traits": other, "w": -0.5}])
	var same := _peaks(own, [{"traits": own, "w": 0.5}])
	var ab := _jaccard(solo, b)
	var ac := _jaccard(solo, c)
	var bc := _jaccard(b, c)
	var control := _jaccard(solo, same)
	# same MEAN drive by construction (the added cycles are zero-mean), so any
	# difference here is positional, not a level change
	var ok: bool = ab < 0.85 and ac < 0.85 and bc < 0.85 and control >= 0.85
	print("ensemble_check: held-position overlap - solo vs +w %.2f, solo vs -w %.2f, +w vs -w %.2f; itself %.2f %s" % [
		ab, ac, bc, control, "ok - contributors move WHERE it sings" if ok else "FAIL - same positions, only louder"])
	print("                held syllables: solo %s | +w %s | -w %s" % [
		str(solo).substr(0, 40), str(b).substr(0, 40), str(c).substr(0, 40)])
	return 0 if ok else 1


## WHO CONTRIBUTES IS THE LINEAGE'S: the members' order was the GLOBAL generator's
## shuffle, so the same lineage composed differently on every throw. The same seed
## under two different global states must make the same combination.
func _check_order_is_the_lineage() -> int:
	var belt: Array = []
	for i in 6:
		var e := _seed(100 + i, {"song": 0.3 * i - 0.8, "pitch": 0.2 * i - 0.5})
		e.m.r = 0.2 + 0.3 * i
		belt.append(e)
	var differ := 0
	var firsts := {}
	for s in 40:
		var made: Array = []
		for g in [1, 987654]:
			seed(g)
			for _i in g % 7:
				randi()
			var rng := RandomNumberGenerator.new()
			rng.seed = hash(str([s, 7]))
			made.append(var_to_str(VoiceParty.ensemble_traits(belt[0], rng, belt, NEAR)))
		if made[0] != made[1]:
			differ += 1
		var once := RandomNumberGenerator.new()
		once.seed = hash(str([s, 7]))
		var c: Array = VoiceParty.ensemble_traits(belt[0], once, belt, NEAR).contributions
		if not c.is_empty():
			firsts[var_to_str(c[0].traits)] = true
	var ok: bool = differ == 0 and firsts.size() > 1
	print("ensemble_check: 40 lineages under two global states -> %d composed differently; %d members came first %s" % [
		differ, firsts.size(), "ok - the order is the lineage's" if ok else "FAIL - the global generator decides, or the order is fixed"])
	return 0 if ok else 1


## Which of the first 60 syllables clear the sustain bar, for a voice and its contributors.
func _peaks(traits: Dictionary, contributions: Array) -> Array:
	var spec := Voice.Spec.from_traits(traits)
	spec.sustain_bank = VoiceParty.sustain_bank(traits, contributions)
	var out: Array = []
	for i in 60:
		# same drive form as plan(): cycle plus a mid prominence
		if 0.62 * Voice.Spec.sustain_wave(spec, i) + 0.55 * 0.6 > Voice.SUSTAIN_BAR:
			out.append(i)
	return out


func _jaccard(a: Array, b: Array) -> float:
	var inter := 0
	for v in a:
		if b.has(v):
			inter += 1
	var uni: int = a.size() + b.size() - inter
	return float(inter) / maxf(float(uni), 1.0)


func _sd(a: Array) -> float:
	var m := 0.0
	for v in a:
		m += float(v)
	m /= float(a.size())
	var s := 0.0
	for v in a:
		s += (float(v) - m) * (float(v) - m)
	return sqrt(s / float(a.size()))
