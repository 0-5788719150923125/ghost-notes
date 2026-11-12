extends RefCounted
class_name VoiceField

## VoiceField - the belt as a field of interfering sources.
##
## Every seed on the belt is a source at its own coordinate, radiating an influence that falls off with
## distance at its own rate. A candidate voice sits somewhere in that field and is modulated by what
## reaches it: far from the belt the influences vanish and the voice is free; among several seeds the
## modulation is strong and structured.
##
## How influence combines is selectable (see COMBINE): superposition is a chord, product a gate, max a
## spotlight, ring a beat. Amplitudes are signed and continuous: a seed the belt likes less than average
## subtracts. Each source also carries a wave vector, so `cos(theta_i)` spans [-1, +1] with where the
## candidate stands - two seeds reinforce here, partially cancel a step away and null a step further, so
## distance and angle matter, not just membership.
##
## Everything derives from what a seed has (traits, genome, lineage, acceptance); no per-seed constant is
## rolled or tuned. Deterministic per (belt contents, position): no wall clock.

## The combination rules. Each takes the per-source contributions and returns one Vector3.
const COMBINE := ["sum", "product", "max", "ring"]

## Genome deltas are folded into the 3-axis frame through a fixed hyperplane bank so the 16 genes
## contribute without any one dominating. Baked from a constant seed: the frame must not move between
## runs, or a saved belt changes shape.
const PLANE_SEED := 0x5EED_F1E1
## Genome contributes at this weight relative to the trait axes: the traits are what a listener can
## name, so they lead.
const GENOME_WEIGHT := 0.45
## How sharply acceptance turns into polarity. tanh, so it is continuous and bounded: a seed at the
## belt mean radiates nothing, above it attracts, below it repels.
const POLARITY_GAIN := 1.2
## Below this a source is not summed (and, for `product`, must not gate everything to nothing).
const AMP_FLOOR := 0.004
## Total radiated amplitude a belt may carry, however many seeds are on it (a shared budget as in
## ProsodyWalk's modulators): a growing belt does not get louder and more homogeneous.
const FIELD_BUDGET := 2.4

static var _planes: Array = []


## The 3 legible axes, the same grouping the HUD compass uses:
##   X brightness - pitch, lilt, and song (a sung voice reads as lifted)
##   Y damage     - grit, air, breath: smooth vs abraded
##   Z drive      - pace, drawl, tract: urgent vs drawn-out
## Genome deltas fold in through the baked planes at GENOME_WEIGHT.
##
## Three axes, not the full 25: a random offset's projection onto a source's wave vector has a standard
## deviation of about 0.58 in 3-D and 0.20 in 25-D, where nearly every pair of directions is close to
## orthogonal, `cos(theta)` sits near zero and angle stops discriminating.
static func frame(v: PackedFloat32Array) -> Vector3:
	_bake()
	var n := Voice.TRAIT_KEYS.size()
	var g := func(i: int) -> float:
		return float(v[i]) if i < v.size() else 0.0
	# TRAIT_KEYS: pitch0 lilt1 tract2 pace3 breath4 grit5 drawl6 air7 song8
	var out := Vector3(
		(g.call(0) + g.call(1) + 0.7 * g.call(8)) * 0.55,
		(g.call(5) + g.call(7) + g.call(4)) * 0.55,
		(g.call(3) + g.call(6) + g.call(2)) * 0.55)
	for k in _planes.size():
		var d: float = g.call(n + k)
		if absf(d) > 0.0:
			out += (_planes[k] as Vector3) * (d * GENOME_WEIGHT)
	return out


static func _bake() -> void:
	if not _planes.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = PLANE_SEED
	for _i in Voice.ProsodyWalk.PRIOR.size():
		_planes.append(Vector3(rng.randfn(0.0, 1.0), rng.randfn(0.0, 1.0),
			rng.randfn(0.0, 1.0)).normalized())


## One source, everything derived.
##
##   pos    - where the seed sits, in the frame above
##   amp    - signed: tanh of how far its acceptance beats the belt mean, so a disliked seed subtracts
##   range  - the seed's own `ring * (1 - damp)` (how far its resonance carries, how hard it absorbs),
##            normalized against the belt's scale; the gene ranges give a ~40x span
##   k      - wave vector: direction is the seed's own bearing, magnitude its strongest lineage
##            modulator's rate, so the phase depends on the candidate's angle and not only distance
##   phase  - that modulator's own phase
static func source(traits: Dictionary, genome: Dictionary, lineage: Array,
		acceptance: float, seed_vec: PackedFloat32Array,
		reach_norm: float, scale: float) -> Dictionary:
	var pos := frame(seed_vec)
	var ring: float = float(genome.get("ring", 0.6))
	var damp: float = float(genome.get("damp", 0.35))
	var reach: float = maxf(ring * (1.0 - damp), 0.02)
	var rate := 0.5
	var phase := 0.0
	var best := 0.0
	for m in Voice.ProsodyWalk._lineage_mods(lineage):
		if float(m.depth) > best:
			best = float(m.depth)
			rate = float(m.rate)
			phase = float(m.phase)
	var dir := pos.normalized() if pos.length() > 0.0001 else Vector3(1.0, 0.0, 0.0)
	return {
		"pos": pos,
		"amp": tanh((acceptance - 1.0) * POLARITY_GAIN),
		"range": maxf(scale * reach / maxf(reach_norm, 0.0001), 0.05),
		"k": dir * (TAU * rate / maxf(scale, 0.0001)),
		"phase": phase,
		"key": hash(str(lineage)),
	}


## Evaluate the field at `p`. Returns the modulation vector, its energy, and the proximity and
## center-frequency the reception filter wants - one field, so what a player hears and what a
## candidate feels agree.
static func evaluate(sources: Array, p: Vector3, mode := "sum") -> Dictionary:
	# stable order: eviction reorders the belt, but a field is a property of the set of sources
	var srcs := sources.duplicate()
	srcs.sort_custom(func(a, b): return int(a.key) < int(b.key))
	var contrib: Array = []
	var atot := 0.0
	for s in srcs:
		var d: Vector3 = p - (s.pos as Vector3)
		var dist := d.length()
		var a: float = float(s.amp) * exp(-dist / float(s.range))
		if absf(a) < AMP_FLOOR:
			continue
		atot += absf(a)
		contrib.append({
			"a": a,
			"th": (s.k as Vector3).dot(d) + float(s.phase),
			"u": (-d).normalized() if dist > 0.0001 else Vector3.ZERO,
			"dist": dist,
		})
	if contrib.is_empty():
		return {"vec": Vector3.ZERO, "energy": 0.0, "prox": 0.0, "freq": 400.0}
	# the shared budget: scale the whole set down rather than letting it stack
	var trim: float = 1.0 if atot <= FIELD_BUDGET else FIELD_BUDGET / atot
	var vec := Vector3.ZERO
	match mode:
		"product":
			# Gating: each source multiplies what came before, so one on a null silences the belt.
			var m := 1.0
			for c in contrib:
				m *= 1.0 + float(c.a) * trim * cos(float(c.th))
			var dirp := Vector3.ZERO
			for c in contrib:
				dirp += (c.u as Vector3) * absf(float(c.a))
			vec = dirp.normalized() * (m - 1.0)
		"max":
			# Spotlight: the strongest source wins outright.
			var bestc: Dictionary = contrib[0]
			for c in contrib:
				if absf(float(c.a)) > absf(float(bestc.a)):
					bestc = c
			vec = (bestc.u as Vector3) * (float(bestc.a) * trim * cos(float(bestc.th)))
		"ring":
			# Beats: only the pairwise products survive, so a lone seed radiates nothing.
			for i in contrib.size():
				for j in range(i + 1, contrib.size()):
					var ci: Dictionary = contrib[i]
					var cj: Dictionary = contrib[j]
					var amp: float = float(ci.a) * float(cj.a) * trim * trim
					vec += ((ci.u as Vector3) + (cj.u as Vector3)).normalized() \
						* (amp * cos(float(ci.th) - float(cj.th)))
		_:
			# Superposition, the default: `cos` has zero spatial mean, so this perturbs without biasing
			# toward the belt's centroid.
			for c in contrib:
				vec += (c.u as Vector3) * (float(c.a) * trim * cos(float(c.th)))
	# reception: proximity is how much total amplitude arrives, the center
	# frequency the amplitude-weighted geometric blend of the sources reached
	var prox := clampf(atot * trim, 0.0, 1.0)
	var flog := 0.0
	var fw := 0.0
	for i in contrib.size():
		var w: float = absf(float(contrib[i].a))
		fw += w
		flog += w * log(maxf(120.0 / maxf(float(contrib[i].dist), 0.05), 60.0))
	var freq: float = exp(flog / maxf(fw, 0.0001)) if fw > 0.0 else 400.0
	return {"vec": vec, "energy": vec.length(), "prox": prox,
		"freq": clampf(freq, 90.0, 3000.0)}
