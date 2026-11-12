extends Node

## scene_mix_check - that the running order is random-like, not a rotation through the catalog.
##
## Over K distinct scene kinds a random draw repeats one after about sqrt(pi*K/2) cuts (the birthday
## number, roughly 9 at K = 52); a rotation repeats first at K + 1. That number separates the two and is
## what this asserts. Alongside it, the mean position at which the ten kinds in NEW_KINDS first appear
## is compared with the mean for every older kind: the same under an honest scheduler, so it checks
## fairness (a scheduler favoring the start or end of the catalog array would fail).
##
## The selection under test is Director._pick_index() itself, driven as _next_entry and _swap drive it.
##
## Run: tests/run_boot_probe.sh tests/scenes/scene_mix_check.gd 180

const SESSIONS := 40
const CUTS := 140

## The ten kinds added in dfa51d57, kept as a literal so the check keeps measuring those scenes.
const NEW_KINDS := ["canopy", "chladni", "cloth", "contour_map", "falling_sand", "glyphs",
	"murmuration", "neural_field", "tidepool", "wallpaper"]

var _fails: Array = []


func _ready() -> void:
	# Snapshot the live autoload and put it back afterwards: a probe must not leave the Director
	# mid-session with a scrambled history.
	var s_seed = Director._session_seed
	var s_swaps = Director._swaps
	var s_index = Director._index
	var s_last: Dictionary = Director._kind_last.duplicate()
	var s_jump = Director._jump_next
	var s_lock = Director._locked

	var kinds := {}
	for e in SceneRoster.SCENES:
		kinds[String(e.script.resource_path)] = true
	var k := kinds.size()
	var expect := sqrt(PI * float(k) / 2.0)

	var first_rep := 0.0
	var new_pos := 0.0
	var new_n := 0
	var old_pos := 0.0
	var old_n := 0
	var swept := 0
	var adjacent := 0
	var near := 0
	var first_seq: Array = []

	for s in SESSIONS:
		Director._jump_next = -1
		Director._locked = -1
		Director._index = -1
		Director._swaps = 0
		Director._kind_last = {}
		Director._session_seed = 0x5bd1e995 ^ (s * 0x9E3779B1)

		var seq: Array = []
		for _c in CUTS:
			var i: int = Director._pick_index()
			var path := String(SceneRoster.SCENES[i].script.resource_path)
			Director._kind_last[path] = Director._swaps
			Director._index = i
			Director._swaps += 1
			seq.append(path.get_file().get_basename())
		if s == 0:
			first_seq = seq.duplicate()

		var seen := {}
		var rep := CUTS
		var firsts := {}
		for j in seq.size():
			var kind: String = seq[j]
			if seen.has(kind) and rep == CUTS:
				rep = j
			seen[kind] = true
			if not firsts.has(kind):
				firsts[kind] = j
	# The other failure a first-repeat target could be met by overshooting into: a draw so flat
	# that a kind comes straight back (two behaviors of one scene back to back).
			if j > 0 and String(seq[j - 1]) == kind:
				adjacent += 1
			if j > 1 and String(seq[j - 2]) == kind:
				near += 1
		first_rep += float(rep)
		if rep > k:
			swept += 1
		for kind in firsts.keys():
			var at := float(firsts[kind])
			if NEW_KINDS.has(String(kind)):
				new_pos += at
				new_n += 1
			else:
				old_pos += at
				old_n += 1

	var mean_rep := first_rep / float(SESSIONS)
	var mean_new := new_pos / maxf(1.0, float(new_n))
	var mean_old := old_pos / maxf(1.0, float(old_n))
	print("scene_mix_check: %d kinds, %d sessions x %d cuts" % [k, SESSIONS, CUTS])
	print("scene_mix_check: first repeat at cut %.1f (a random draw repeats at ~%.1f, a full sweep at %d)"
		% [mean_rep, expect, k + 1])
	print("scene_mix_check: full sweeps before any repeat: %d of %d sessions" % [swept, SESSIONS])
	print("scene_mix_check: mean first appearance - new kinds %.1f, older kinds %.1f" % [mean_new, mean_old])
	print("scene_mix_check: same kind back-to-back %d, and one cut apart %d, of %d cuts"
		% [adjacent, near, SESSIONS * CUTS])

	# A rotation is the failure. A generous anti-repeat bias is fine (a scheduler should lean away from
	# what it just showed), but not a sweep: three times the birthday number still leaves the order
	# visibly shuffled, while a sweep sits at one more than the kind count.
	if mean_rep > expect * 3.0:
		_fails.append("first repeat at cut %.1f against a random-draw expectation of %.1f - the catalog is being rotated through, not sampled"
			% [mean_rep, expect])
	if swept > SESSIONS / 10:
		_fails.append("%d of %d sessions showed EVERY kind before repeating any - that is a rotation by definition"
			% [swept, SESSIONS])
	# Two-sided: the first-repeat target could also be met by flattening the draw until the catalog
	# chatters, so the anti-repeat guarantee is asserted against it.
	if adjacent > 0:
		_fails.append("%d cuts showed the same scene KIND twice in a row" % adjacent)
	if near > SESSIONS * CUTS / 50:
		_fails.append("%d of %d cuts brought a kind back one cut later - the draw has gone flat"
			% [near, SESSIONS * CUTS])
	# Fairness: the newest scenes must not crowd the front (or back) of the running order.
	if absf(mean_new - mean_old) > 0.25 * float(CUTS):
		_fails.append("new kinds first appear at cut %.1f and older kinds at %.1f - the running order is biased by when a scene was added"
			% [mean_new, mean_old])

	# Determinism must not change: one session seed gives one running order every play, or an export
	# stops matching the preview it was auditioned against. Replay a measured seed and compare cut for cut.
	var again: Array = []
	Director._jump_next = -1
	Director._locked = -1
	Director._index = -1
	Director._swaps = 0
	Director._kind_last = {}
	Director._session_seed = 0x5bd1e995 ^ (0 * 0x9E3779B1)
	for _c in CUTS:
		var i2: int = Director._pick_index()
		var p2 := String(SceneRoster.SCENES[i2].script.resource_path)
		Director._kind_last[p2] = Director._swaps
		Director._index = i2
		Director._swaps += 1
		again.append(p2.get_file().get_basename())
	if again != first_seq:
		var at := -1
		for j in mini(again.size(), first_seq.size()):
			if again[j] != first_seq[j]:
				at = j
				break
		_fails.append("the same session seed produced a DIFFERENT running order, first differing at cut %d - the show is no longer reproducible" % at)
	else:
		print("scene_mix_check: replay of one seed reproduced all %d cuts exactly" % CUTS)

	Director._session_seed = s_seed
	Director._swaps = s_swaps
	Director._index = s_index
	Director._kind_last = s_last
	Director._jump_next = s_jump
	Director._locked = s_lock

	if _fails.is_empty():
		print("scene_mix_check: ALL OK")
		get_tree().quit()
		return
	print("scene_mix_check: %d FAILURE(S)" % _fails.size())
	for f in _fails:
		print("   ", f)
	get_tree().quit(1)
