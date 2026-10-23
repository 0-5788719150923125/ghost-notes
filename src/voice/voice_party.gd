extends RefCounted
class_name VoiceParty

## VoiceParty - the Synthesis lab's party math: the belt of kept seeds and the candidate on the
## line, as numbers. A seed as a vector in the shared trait and genome space, how much the belt
## accepts each member, the party's acceptance-weighted center and blend, how well a candidate
## fits the party and how hard it is to catch, the interference field the belt makes and where
## the candidate stands in it, the trust region a fresh draw is tempered into, a throw's traits
## composed from several members, and the sustain bank that composition sings with.
##
## PURE: functions of what they are handed - nothing of who asks. A BELT is an Array of entries
## (`{lineage, traits, genome, loc, scene, m}`, the editor's save). A CANDIDATE is `{traits,
## lineage, genome}`, the voice on the line; an empty genome is its lineage's own. DRIFT is the
## freedom the line's distance buys ([method SynthEditor._drift_free]). A FIELD is what
## [method field_at] returns, handed on to what it colors. A throw sets its new candidate a piece at
## a time, so each call site in the editor names the half-made candidate it hands in. Called by
## [SynthEditor]; tests/voice/ensemble_check.gd and voice_party_check.gd hold it.

# The trust region: a fresh draw is normalized RELATIVE to the pool being
# harmonized with (the party's center; the curated default when the belt is
# empty). A candidate landing beyond the radius is pulled back onto it -
# extremes stay reachable by DRIFTING (the cage widens the region), they just
# stop being a routine dice roll onto a broken voice (grit x air x pitch all
# at the far edge at once synthesized as clicks and static, not character).
const TEMPER_RADIUS := 0.85
# How hard the interference field pushes a candidate, and the hard ceiling on
# any one axis. The field colors a voice; it must never relocate one, or it
# becomes a fourth attractor and every catch near the belt converges.
const FIELD_LIFT := 0.55
const FIELD_MAX := 0.25
# How many belt members beyond the dominant parent may color a throw, and how
# far each may pull it. Bounded so a combination is always a perturbation of one
# recognizable parent rather than a march toward the belt's mean.
const ENSEMBLE_MAX := 2
const ENSEMBLE_W := 0.45


# ---- a seed: its vector, its genome, its standing ----------------------------------------------


## A seed as a vector: its traits plus its genome (as deltas off the PRIOR),
## the space the constellation colors attune in. An explicit genome (frozen
## or mid-anneal adrenochrome) takes precedence over lineage derivation.
static func seed_vector(traits: Dictionary, lineage: Array, genome: Dictionary = {}) -> PackedFloat32Array:
	var v := PackedFloat32Array()
	for key in Voice.TRAIT_KEYS:
		v.append(float(traits.get(key, 0.0)))
	var g: Dictionary = genome if not genome.is_empty() \
		else Voice.ProsodyWalk._lineage_genome(lineage)
	for key in Voice.ProsodyWalk.PRIOR:
		var prior: float = float(Voice.ProsodyWalk.PRIOR[key])
		# normalize by the gene's OWN SPREAD, not by the magnitude of its prior.
		# Dividing by |prior| made a gene's weight in this space inversely
		# proportional to how big its numbers happen to be: `hesit_bias` (prior
		# 0.25) counted 38x more per unit than `breath_span` (prior 9.5), and
		# measured 31% of all variance on its own, with effective dimensionality
		# ~7.6 of 25. Every distance, every bearing, every acceptance-weighted
		# center and the catch card's kinship color were all mostly reading one
		# arbitrary gene. G_BOUNDS is the range the gene is actually sampled and
		# clamped over, so it is the honest unit.
		var b: Array = Voice.ProsodyWalk.G_BOUNDS.get(key, [])
		var spread: float = (float(b[1]) - float(b[0])) if b.size() == 2 else maxf(absf(prior), 0.001)
		v.append((float(g.get(key, prior)) - prior) / maxf(spread, 0.001))
	return v


## A seed's genome: the frozen adrenochrome if it carries one, else derived
## from the lineage as always. Read only: a genome that is complete is handed
## back as it is stored, and one that is not is handed back COMPLETED in a copy -
## the entry is the belt's save, and a getter that filled it in wrote the save.
static func member_genome(e: Dictionary) -> Dictionary:
	if e.has("genome") and not (e.genome as Dictionary).is_empty():
		# a stored genome may be PARTIAL - an echoed (recorded) seed carries
		# only its MEASURED genes, and older saves may predate newer genes.
		# Backfill from the PRIOR (the same contract ProsodyWalk applies to a
		# frozen adrenochrome) so every consumer - the tooltip, the hook's
		# annealing members - always sees a complete genome.
		var g: Dictionary = e.genome
		if g.has_all(Voice.ProsodyWalk.PRIOR.keys()):
			return g
		var full := g.duplicate()
		for key in Voice.ProsodyWalk.PRIOR:
			if not full.has(key):
				full[key] = Voice.ProsodyWalk.PRIOR[key]
		return full
	return Voice.ProsodyWalk._lineage_genome(e.lineage)


## What a seed has earned: its reward, and the time it has been held.
static func seed_value(e: Dictionary) -> float:
	return 20.0 * float(e.m.get("r", 0.0)) + e.m.s / 30.0


## How much the belt accepts one member: its value per play against the belt's.
static func acceptance(e: Dictionary, belt: Array) -> float:
	var own: float = seed_value(e) / maxf(1.0, float(e.m.acts))
	var total := 0.0
	var plays := 0
	for other in belt:
		total += seed_value(other)
		plays += int(other.m.acts)
	var mean := total / maxf(1.0, float(plays))
	return own / maxf(mean, 0.001)


# ---- the party: its center, its blend, its pull ------------------------------------------------


## The population-average background: the voice before any seed exists.
static func background_traits(belt: Array) -> Dictionary:
	var t := {}
	if belt.is_empty():
		return t
	var total := 0.0
	for e in belt:
		total += 0.1 + acceptance(e, belt)
	for key in Voice.TRAIT_KEYS:
		var v := 0.0
		for e in belt:
			v += float((e.traits as Dictionary).get(key, 0.0)) * (0.1 + acceptance(e, belt))
		t[key] = v / maxf(total, 0.001)
	return t


## The party's center: acceptance-weighted mean of the belt's vectors.
static func party_vector(belt: Array) -> PackedFloat32Array:
	var dims := Voice.TRAIT_KEYS.size() + Voice.ProsodyWalk.PRIOR.size()
	var v := PackedFloat32Array()
	v.resize(dims)
	if belt.is_empty():
		return v
	var total := 0.0
	for e in belt:
		var w := 0.1 + acceptance(e, belt)
		total += w
		var sv := seed_vector(e.traits, e.lineage)
		for i in dims:
			v[i] += sv[i] * w
	for i in dims:
		v[i] /= maxf(total, 0.001)
	return v


## Accumulated information is POWER on the line: a seasoned belt (hold time +
## earned reward = what the party has LEARNED) resonates with a hooked catch
## and retrieves it faster - in EVERY mode; knowledge is not a mode. This is
## the reel's side of the fight: power against the creature's runs.
static func reel_power(belt: Array) -> float:
	var knowledge := 0.0
	for e in belt:
		knowledge += e.m.s + 20.0 * float(e.m.get("r", 0.0))
	return clampf(0.9 + knowledge / 600.0, 0.9, 2.2)


# ---- a candidate against the party -------------------------------------------------------------


## How hard a candidate is to catch, 0 kin .. 1 wild: its distance to the nearest member, the
## traits and the genome weighed alike. An empty belt is a firm 0.35.
static func candidate_difficulty(cand: Dictionary, belt: Array) -> float:
	if belt.is_empty():
		return 0.35
	var traits: Dictionary = cand.traits
	var genome: Dictionary = cand.genome
	var cg: Dictionary = genome if not genome.is_empty() \
		else Voice.ProsodyWalk._lineage_genome(cand.lineage)
	var best := 1.0
	for e in belt:
		var dt := 0.0
		for key in Voice.TRAIT_KEYS:
			var dv: float = float(traits.get(key, 0.0)) \
				- float((e.traits as Dictionary).get(key, 0.0))
			dt += dv * dv
		dt = sqrt(dt / Voice.TRAIT_KEYS.size()) / 0.9
		var eg: Dictionary = member_genome(e)
		var dg := 0.0
		for key in Voice.ProsodyWalk.PRIOR:
			var prior: float = float(Voice.ProsodyWalk.PRIOR[key])
			dg += absf(float(cg.get(key, prior)) - float(eg.get(key, prior))) \
				/ maxf(absf(prior), 0.001)
		dg = (dg / Voice.ProsodyWalk.PRIOR.size()) / 0.35
		best = minf(best, 0.5 * clampf(dt, 0.0, 1.0) + 0.5 * clampf(dg, 0.0, 1.0))
	return clampf(best, 0.0, 1.0)


## How close a belt member sits to a candidate (cosine in the shared
## trait+genome space) - the HUD draws members as tiny planets only when this
## is genuinely high; the cosmos stays sparse.
static func closeness(e: Dictionary, cand: Dictionary) -> float:
	return cosine(
		seed_vector(e.traits, e.lineage, member_genome(e)),
		seed_vector(cand.traits, cand.lineage, cand.genome))


## Any candidate's fit (given explicit traits/genome, e.g. the mid-anneal
## adrenochrome), RELATIVE to the party's own spread: raw cosines cluster too
## tightly to see, so the scale stretches over what the bag actually contains.
static func relative_fit(traits: Dictionary, lineage: Array, genome: Dictionary, belt: Array) -> float:
	if belt.is_empty():
		return 0.6
	var party := party_vector(belt)
	var sims: Array = [cosine(seed_vector(traits, lineage, genome), party)]
	for e in belt:
		sims.append(cosine(seed_vector(e.traits, e.lineage, member_genome(e)), party))
	var norm := relative_norm(sims)
	return norm[0]


## The candidate's bearing FROM the party, as a 3D vector for the HUD compass -
## direction is otherwise near-impossible to reason about in an 8D trait space.
## The eight trait axes collapse onto three legible ones the ear can name:
##   X = brightness  (pitch, lilt)      - how high/lively vs low/flat
##   Y = damage      (grit, air, breath) - the FRAY axes: smooth vs abraded
##   Z = drive       (pace, drawl, tract) - clipped/urgent vs drawn-out
## Each is the candidate-minus-party offset summed over its group, softened into
## roughly [-1, 1]. With an empty belt the party is the origin, so the compass
## simply reads the voice's own place - still a direction worth seeing.
static func bearing_of(cand: PackedFloat32Array, party: PackedFloat32Array) -> Vector3:
	var off := func(i: int) -> float:
		return float(cand[i]) - float(party[i]) if i < cand.size() and i < party.size() else 0.0
	# indices in Voice.TRAIT_KEYS order: pitch0 lilt1 tract2 pace3 breath4 grit5 drawl6 air7
	var gx: float = off.call(0) + off.call(1)
	var gy: float = off.call(5) + off.call(7) + off.call(4)
	var gz: float = off.call(3) + off.call(6) + off.call(2)
	return Vector3(clampf(gx * 0.7, -1.0, 1.0),
		clampf(gy * 0.55, -1.0, 1.0), clampf(gz * 0.55, -1.0, 1.0))


## A belt member's bearing in the SHARED party frame - the same frame for every
## member, so the planets' colors and their shadow directions are mutually
## consistent and do NOT depend on which candidate is currently being fished
## (that is why the shadows "point in directions, consistently, no matter which
## one we're anchored to"). Only an Accept, which moves the party, re-orients
## the whole sky.
static func member_bearing(e: Dictionary, party: PackedFloat32Array) -> Vector3:
	return bearing_of(seed_vector(e.traits, e.lineage, member_genome(e)), party)


static func cosine(a: PackedFloat32Array, b: PackedFloat32Array) -> float:
	var dot := 0.0
	var na := 0.0
	var nb := 0.0
	for i in mini(a.size(), b.size()):
		dot += a[i] * b[i]
		na += a[i] * a[i]
		nb += b[i] * b[i]
	if na < 0.000001 or nb < 0.000001:
		return 0.0
	return dot / (sqrt(na) * sqrt(nb))


## Min-max stretch a list to [0,1]; a degenerate spread parks everyone at 0.6
## (no information = no alarm).
static func relative_norm(values: Array) -> Array:
	var lo := 1e9
	var hi := -1e9
	for v in values:
		lo = minf(lo, float(v))
		hi = maxf(hi, float(v))
	var out: Array = []
	if hi - lo < 0.05:
		for _v in values:
			out.append(0.6)
		return out
	for v in values:
		out.append((float(v) - lo) / (hi - lo))
	return out


# ---- the interference field --------------------------------------------------------------------


## THE INTERFERENCE FIELD (see [VoiceField]) - the belt as sources in space.
##
## Built fresh from the belt because acceptance moves as you listen. `scale` is
## the belt's own median pairwise distance, so ranges are expressed in the units
## of THIS belt rather than a constant: a tight belt has a tight field.
static func field_sources(belt: Array) -> Array:
	if belt.is_empty():
		return []
	var vecs: Array = []
	var reach: Array = []
	for e in belt:
		var g: Dictionary = member_genome(e)
		vecs.append(seed_vector(e.traits, e.lineage, g))
		reach.append(maxf(float(g.get("ring", 0.6)) * (1.0 - float(g.get("damp", 0.35))), 0.02))
	var dists: Array = []
	for i in vecs.size():
		for j in range(i + 1, vecs.size()):
			dists.append((VoiceField.frame(vecs[i]) - VoiceField.frame(vecs[j])).length())
	dists.sort()
	reach.sort()
	var scale: float = dists[dists.size() / 2] if not dists.is_empty() else 1.0
	var rnorm: float = reach[reach.size() / 2]
	var out: Array = []
	for i in belt.size():
		var e: Dictionary = belt[i]
		out.append(VoiceField.source(e.traits, member_genome(e), e.lineage,
			acceptance(e, belt), vecs[i], rnorm, maxf(scale, 0.05)))
	return out


## Which combination rule a voice's water obeys. Derived from the lineage
## root, so it is a property you fish for and inherit rather than a setting -
## and so the four rules in [VoiceField.COMBINE] are all actually reachable in
## play instead of one being hardcoded.
static func field_mode(lineage: Array) -> String:
	if lineage.is_empty():
		return "sum"
	var i := absi(hash([lineage[0], "field"])) % VoiceField.COMBINE.size()
	return String(VoiceField.COMBINE[i])


## Where the candidate stands: its own place, pushed outward along its bearing
## from the party by however far the line has been carried. The odometer stays a
## scalar radius - the fight math, the HUD arc and the caption are all defined
## on it as a magnitude - but it moves a real POSITION through a real field,
## which is what makes distance change the voice instead of only the caption.
static func field_at(cand: Dictionary, belt: Array, drift: float) -> Dictionary:
	var srcs := field_sources(belt)
	if srcs.is_empty():
		return {"vec": Vector3.ZERO, "energy": 0.0, "prox": 0.0, "freq": 400.0}
	var here := VoiceField.frame(seed_vector(cand.traits, cand.lineage, cand.genome))
	var party := VoiceField.frame(party_vector(belt))
	var u := (here - party)
	u = u.normalized() if u.length() > 0.0001 else Vector3(0.0, 0.0, 1.0)
	return VoiceField.evaluate(srcs, here + u * drift, field_mode(cand.lineage))


## Lift a field vector back into trait deltas - the frame's transpose. Bounded
## hard: the field COLORS a candidate, it never relocates one.
static func field_bias(vec: Vector3) -> Dictionary:
	var b := {}
	var put := func(key: String, v: float) -> void:
		b[key] = clampf(v * 0.55 * FIELD_LIFT, -FIELD_MAX, FIELD_MAX)
	put.call("pitch", vec.x)
	put.call("lilt", vec.x)
	put.call("song", vec.x * 0.7)
	put.call("grit", vec.y)
	put.call("air", vec.y)
	put.call("breath", vec.y)
	put.call("pace", vec.z)
	put.call("drawl", vec.z)
	put.call("tract", vec.z)
	return b


# ---- a throw: tempered, composed, sung ---------------------------------------------------------


## Normalize a candidate's trait vector against the pool it must harmonize
## with: the party's acceptance-weighted center ({} = the curated default when
## the belt is empty) anchors a trust region of TEMPER_RADIUS (RMS over the
## trait axes); a draw beyond it is pulled back onto the boundary, direction
## intact. Drifting widens the region - foreignness is EARNED by the cage,
## not rolled. [param field] is where the line stands ([method field_at]).
static func temper_traits(t: Dictionary, drift: float, belt: Array, field: Dictionary) -> Dictionary:
	# The cage's CENTER moves with the field, it does not just widen. Previously
	# distance only inflated a trust region still bolted to the belt's center of
	# mass, so a candidate thirty lightyears out was still normalized toward the
	# same point as one sitting on top of the belt - which is most of why
	# drifting stopped changing anything. Now the field displaces the center, so
	# where you stand decides what "ordinary" even means; far out the field dies,
	# the center returns to the plain centroid, and the old behavior is the
	# limit case rather than the only case.
	var center := background_traits(belt)
	var bias := field_bias(field.vec)
	for key in bias:
		center[key] = clampf(float(center.get(key, 0.0)) + float(bias[key]), -1.0, 1.0)
	var radius := TEMPER_RADIUS * (1.0 + 0.8 * drift)
	var dist := 0.0
	for key in Voice.TRAIT_KEYS:
		var dv := float(t.get(key, 0.0)) - float(center.get(key, 0.0))
		dist += dv * dv
	dist = sqrt(dist / Voice.TRAIT_KEYS.size())
	if dist <= radius:
		return t
	var scale := radius / dist
	var out := {}
	for key in Voice.TRAIT_KEYS:
		var c := float(center.get(key, 0.0))
		out[key] = clampf(c + (float(t.get(key, 0.0)) - c) * scale, -1.0, 1.0)
	return out


## A throw's traits as a COMBINATION of belt members, not a copy of one.
## Returns `{traits, contributions}`: the child's traits, and who contributed and
## how much (`[{traits, w}]`), so the sustain bank can be built from the same
## combination rather than re-rolling one ([method sustain_bank]).
##
## [method SynthEditor._pick_parent] picks exactly one seed and the child was a
## jittered copy of it, so the belt SELECTED rather than COMPOSED: adding a singer
## to the belt did not let other lines pick up singing, it only added a lottery
## ticket, and a third seed could not modulate a mode a second one had
## contributed. The acceptance-weighted blend that IS the composition
## ([method background_traits]) already existed and was never used to derive a throw.
##
## The form is `dominant + sum_i w_i * (member_i - dominant)`, which has the
## properties this needs:
##   - one seed on the belt, or no contributors drawn: identical to before
##   - w > 0 pulls the child toward that member - a non-singing line can take
##     on song from a singer on the belt, partway, and a third contributor can
##     push it further
##   - w < 0 pushes the child AWAY from that member. Combination that can
##     SUBTRACT is the whole point: averaging toward the belt is how a
##     collection collapses onto one voice, and a signed weight is what keeps
##     variance alive while still composing.
##   - bounded, and always an interpolation around the dominant, so no
##     combination can run away
##
## The DOMINANT keeps its lineage, so identity, the genome, the seed's scene
## and "restoring a seed returns to its place" are all unchanged - the others
## contribute traits only.
##
## How many contribute is gated by the FIELD ([param field], [method field_at]):
## sitting among the belt draws more of it in, drifting away leaves the dominant
## alone. Same "near = modulated, far = stable" rule the field itself follows, so
## the two mechanics agree.
##
## WHO contributes is a function of [param rng]'s seed (the editor's is the throw's
## lineage): the order the members are offered in is a draw of its own, seeded beside
## the weights' and taking nothing from [param rng], so the weights are drawn exactly
## where they were when the order came from the global generator - which made the same
## lineage compose differently on every throw.
static func ensemble_traits(dominant: Dictionary, rng: RandomNumberGenerator, belt: Array,
		field: Dictionary) -> Dictionary:
	var contributions: Array = []
	var base: Dictionary = (dominant.traits as Dictionary)
	var out := {}
	for key in Voice.TRAIT_KEYS:
		out[key] = float(base.get(key, 0.0))
	if belt.size() < 2:
		return {"traits": out, "contributions": contributions}
	var energy: float = clampf(float(field.energy), 0.0, 1.0)
	var reach: float = clampf(0.25 + 0.55 * energy, 0.0, 0.9)
	var pool: Array = []
	for e in belt:
		if e.lineage != dominant.lineage:
			pool.append(e)
	var order := RandomNumberGenerator.new()
	order.seed = hash("ensemble order") ^ int(rng.seed)
	for i in range(pool.size() - 1, 0, -1):          # Fisher-Yates, on its own generator
		var j := order.randi_range(0, i)
		var swap: Variant = pool[i]
		pool[i] = pool[j]
		pool[j] = swap
	var taken := 0
	for e in pool:
		if taken >= ENSEMBLE_MAX or rng.randf() > reach:
			break
		taken += 1
		# signed and bounded; acceptance decides how much say a member has, its
		# SIGN decides whether the child leans into it or away from it
		var w: float = rng.randf_range(-ENSEMBLE_W, ENSEMBLE_W) \
			* clampf(0.35 + acceptance(e, belt), 0.0, 1.6)
		contributions.append({"traits": (e.traits as Dictionary).duplicate(), "w": w})
		for key in Voice.TRAIT_KEYS:
			var m: float = float((e.traits as Dictionary).get(key, 0.0))
			out[key] = clampf(float(out[key]) + w * (m - float(out[key])), -1.0, 1.0)
	return {"traits": out, "contributions": contributions}


## The sustain bank for a combination: the voice's own cycle plus one per
## contributor ([method ensemble_traits]), each at the SIGNED weight it
## contributed with.
##
## Blending the `song` scalar alone only changes how MUCH a voice sings. The
## bank is what makes a combination sing DIFFERENTLY: each contributor brings
## its own period and phase, the periods are incommensurate, and a negative
## weight suppresses positions the dominant would have held. So two belts with
## identical average `song` hold different words, and adding a third seed
## rearranges the cadence instead of merely turning it up.
static func sustain_bank(traits: Dictionary, contributions: Array) -> Array:
	var bank: Array = []
	var own := Voice.Spec.sustain_cycle(traits)
	bank.append([own[0], own[1], 1.0])
	for c in contributions:
		var cyc := Voice.Spec.sustain_cycle(c.traits)
		bank.append([cyc[0], cyc[1], float(c.w)])
	return bank
