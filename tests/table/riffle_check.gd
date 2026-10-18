extends SceneTree

## riffle_check - A RIFFLE'S CARDS FALL IN CLUMPS (the user, 2026-10-17: the deck of 78 riffled "left,
## right, left, right, in perfect unison through the whole shuffle"; real cards stick together - "3 from
## the left, 2 from the right, 1 from the left, 3 from the right, 5 from the left"). Over hundreds of
## seeded riffles of a tarot's 78 ([method TableShuffle._riffle_plan]):
##
##   godot --headless --path . --script tests/table/riffle_check.gd
##
##   - A RIFFLE IS A RIFFLE: every slot lands once, and each half keeps its own order;
##   - THE CUT IS NEAR THE MIDDLE, NOT AT IT: it varies, and never lands past RIFFLE_CUT's reach;
##   - THE CARDS FALL IN CLUMPS: runs from one half average two to four cards, under half of them are
##     single cards, no run outgrows RIFFLE_CLUMP while the other half still holds cards, and one
##     riffle is clumpier than the next. Two-sided: the old riffle (each half's cards in turn, kept here
##     as the control) must fail the same measure;
##   - A CLUMP FALLS AS ONE: its cards share their moment, the clumps fall in order, the first at the
##     start of the drop and the last at its end;
##   - and the same seed is the same riffle, for every size of deck down to none.

const N := 78
const SEEDS := 400

var _fails := 0


func _initialize() -> void:
	_riffles()
	_small_decks()
	print("riffle_check: %s (%d failure%s)" % ["ALL OK" if _fails == 0 else "FAILED", _fails, "" if _fails == 1 else "s"])
	quit(0 if _fails == 0 else 1)


func _ok(cond: bool, what: String) -> void:
	if not cond:
		_fails += 1
		print("  FAIL  " + what)


## The runs of riffle [param to] cut at [param cut]: how many places in a row, bottom to top, were
## landed in from one half - in order.
static func _runs(to: PackedInt32Array, cut: int) -> Array:
	var from := PackedInt32Array()
	from.resize(to.size())
	for i in to.size():
		from[to[i]] = 0 if i < cut else 1
	var out: Array = []
	for j in to.size():
		if j == 0 or from[j] != from[j - 1]:
			out.append(0)
		out[out.size() - 1] = int(out[out.size() - 1]) + 1
	return out


## Whether runs [param all] (every riffle's, in one list) look like cards that stick: their mean
## length, and the share of single cards among them, within bounds - said, when not.
func _clumpy(all: Array, who: String) -> bool:
	var total := 0
	var singles := 0
	for r in all:
		total += int(r)
		singles += 1 if int(r) == 1 else 0
	var mean := float(total) / maxf(float(all.size()), 1.0)
	var single_share := float(singles) / maxf(float(all.size()), 1.0)
	var ok := mean >= 2.0 and mean <= 4.0 and single_share < 0.5
	print("  %s: runs average %.2f cards, %.0f%% single cards" % [who, mean, single_share * 100.0])
	return ok


## The riffle this one replaced: the halves cut exactly and let go of one card each in turn.
static func _alternating(n: int) -> PackedInt32Array:
	var to := PackedInt32Array()
	to.resize(n)
	var half := int(n * 0.5)
	for i in n:
		var left := i < half
		to[i] = mini(2 * (i if left else i - half) + (0 if left else 1), n - 1)
	return to


func _riffles() -> void:
	var lo := ceili(float(N) * (TableShuffle.RIFFLE_CUT.x - TableShuffle.RIFFLE_CUT.y))
	var hi := floori(float(N) * (TableShuffle.RIFFLE_CUT.x + TableShuffle.RIFFLE_CUT.y))
	var cuts := {}
	var cut_sum := 0
	var all_runs: Array = []
	var means: Array = []
	var moments_sum := 0
	for seed in range(1, SEEDS + 1):
		var plan := TableShuffle._riffle_plan(seed, N)
		var again := TableShuffle._riffle_plan(seed, N)
		_ok(plan["to"] == again["to"] and plan["at"] == again["at"] and plan["cut"] == again["cut"],
			"riffle %d is not a function of its seed" % seed)
		var to: PackedInt32Array = plan["to"]
		var at: PackedFloat32Array = plan["at"]
		var nth: PackedInt32Array = plan["nth"]
		var cut := int(plan["cut"])
		# A RIFFLE IS A RIFFLE
		var seen := {}
		for i in N:
			seen[to[i]] = true
		_ok(seen.size() == N, "riffle %d lands %d places for %d cards" % [seed, seen.size(), N])
		var kept := true
		for i in range(1, N):
			if i != cut and to[i] <= to[i - 1]:
				kept = false
		_ok(kept, "riffle %d does not keep each half's order" % seed)
		# THE CUT
		_ok(cut >= lo and cut <= hi, "riffle %d is cut at %d, past %d..%d" % [seed, cut, lo, hi])
		cuts[cut] = true
		cut_sum += cut
		# THE CLUMPS
		var runs := _runs(to, cut)
		all_runs.append_array(runs)
		var longest := 0
		for r in runs.slice(0, runs.size() - 1):
			longest = maxi(longest, int(r))
		_ok(longest <= TableShuffle.RIFFLE_CLUMP, "riffle %d lets go of %d cards at once while the other half still held some"
			% [seed, longest])
		means.append(float(N) / float(runs.size()))
		# A CLUMP FALLS AS ONE
		var moments := 1
		var in_order := is_zero_approx(at[0]) and is_equal_approx(at[N - 1], 1.0) and nth[0] == 0
		for j in range(1, N):
			if nth[j] == 0:
				moments += 1
				in_order = in_order and at[j] > at[j - 1]
			else:
				in_order = in_order and nth[j] == nth[j - 1] + 1 and at[j] == at[j - 1]
		_ok(in_order, "riffle %d's clumps do not fall as one, in order, over the whole drop" % seed)
		_ok(moments == runs.size(), "riffle %d falls in %d moments for %d runs" % [seed, moments, runs.size()])
		moments_sum += moments
	_ok(cuts.size() >= 5, "the cut lands in only %d places over %d riffles" % [cuts.size(), SEEDS])
	var mean_cut := float(cut_sum) / float(SEEDS)
	_ok(absf(mean_cut - N * 0.5) < 1.5, "the cut averages %.1f of %d, off the middle" % [mean_cut, N])
	_ok(_clumpy(all_runs, "the riffle"), "the riffle's cards do not fall in clumps")
	means.sort()
	_ok(float(means[means.size() - 1]) - float(means[0]) > 0.5,
		"every riffle is as clumpy as the next (runs average %.2f to %.2f)" % [means[0], means[means.size() - 1]])
	print("  a riffle of %d lets go %.1f times on average; the cut spans %d places" % [N, float(moments_sum) / float(SEEDS), cuts.size()])
	# TWO-SIDED: the riffle this replaced is a riffle, and the measure must call it unclumped
	var old := _alternating(N)
	var old_seen := {}
	for i in N:
		old_seen[old[i]] = true
	_ok(old_seen.size() == N, "control: the old riffle is not a riffle")
	_ok(not _clumpy(_runs(old, int(N * 0.5)), "control, the old riffle"), "control: the clump measure passes the old riffle, one card each in turn")


func _small_decks() -> void:
	for n in [0, 1, 2, 3, 5, 22]:
		for seed in range(1, 41):
			var plan := TableShuffle._riffle_plan(seed, n)
			var to: PackedInt32Array = plan["to"]
			var seen := {}
			for i in n:
				seen[to[i]] = true
			_ok(to.size() == n and seen.size() == n, "a riffle of %d cards (seed %d) lands %d places" % [n, seed, seen.size()])
