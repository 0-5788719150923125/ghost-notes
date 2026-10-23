extends SceneTree

## voice_party_check - that the party math READS what it is handed and writes none of it.
##
## Run: godot --headless --path . --script tests/voice/voice_party_check.gd
##
## [VoiceParty] is the Synthesis lab's belt and candidate as numbers, and a belt entry is the
## player's save: [method SynthEditor._persist] writes the belt as it stands. The genome getter
## once completed a recorded seed's partial genome IN the entry, so drawing the Collection rewrote
## the save. So:
##
##   A PARTIAL GENOME COMES BACK WHOLE AND STAYS PARTIAL WHERE IT IS KEPT: what member_genome
##   returns holds every gene the PRIOR names - the measured ones as measured, the rest the
##   PRIOR's - and the entry still holds exactly the genes it was given. Two-sided by itself:
##   the getter that wrote the entry passes the first half and fails the second, one that does
##   not complete the genome the other way round.
##   NOTHING IS WRITTEN: every function, on belts of 0, 1, 3 and 6 entries (frozen, lineage-born,
##   partial and descended genomes), three candidates and three drifts, leaves the belt, the
##   candidate and the field it was handed byte for byte as they were.
##   THE SAME QUESTION, THE SAME ANSWER: every call made again, the global generator reseeded
##   in between, answers byte for byte the same - nothing here draws from it.
##
## THE CONTROLS: the byte comparison must see one gene completed in a copy of a belt, or
## "unchanged" proves nothing; and the global generator must really move between the two
## rounds, or "the same answer" proves nothing.

var _fails := 0
## Fields handed to temper_traits and ensemble_traits that came back changed.
var _fields_written := 0


func _init() -> void:
	_check_partial_genome()
	_check_reads_only()
	if _fails == 0:
		print("voice_party_check: ALL OK")
	else:
		print("voice_party_check: %d FAILURE(S)" % _fails)
	quit(_fails)


func _ok(cond: bool, msg: String) -> void:
	print(("  ok    " if cond else "  FAIL  ") + msg)
	if not cond:
		_fails += 1


func _entry(k: int, kind: String) -> Dictionary:
	var lin: Array = [100000 + k * 7919]
	if kind == "child":
		lin.append(k * 31 + 5)
		lin.append(k * 17 + 3)
	var genome := {}
	match kind:
		"frozen":
			genome = Voice.ProsodyWalk._lineage_genome(lin)
			for key in genome:
				genome[key] = float(genome[key]) * (1.0 + 0.1 * sin(float(k + key.length())))
		"partial":
			genome = {"heat": 1.2 + 0.05 * k, "breath_span": 8.0 + k}
	var rng := RandomNumberGenerator.new()
	rng.seed = int(lin[0]) * 3 + k
	return {"lineage": lin, "traits": Voice.Spec.sample(rng).traits, "genome": genome,
		"loc": {"prox": 0.1 * k, "freq": 300.0 + k}, "scene": "",
		"m": {"s": 12.5 * k, "acts": 1 + k % 3, "restores": 0, "evolves": k,
			"catches": k % 2, "r": 0.3 + 0.4 * k, "d": 0.35, "t": 0}}


func _belts() -> Array:
	return [[], [_entry(1, "partial")],
		[_entry(2, "wild"), _entry(3, "partial"), _entry(4, "child")],
		[_entry(5, "frozen"), _entry(6, "wild"), _entry(7, "partial"),
			_entry(8, "child"), _entry(9, "frozen"), _entry(10, "partial")]]


func _cands() -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	return [
		{"traits": Voice.Spec.sample(rng).traits, "lineage": [424242], "genome": {}},
		{"traits": Voice.Spec.sample(rng).traits, "lineage": [139595, 777],
			"genome": Voice.ProsodyWalk._lineage_genome([31337])},
		{"traits": {}, "lineage": [55555, 1, 2], "genome": {"heat": 1.5}},
	]


func _check_partial_genome() -> void:
	var e := _entry(3, "partial")
	var kept: Dictionary = (e.genome as Dictionary).duplicate()
	var g := VoiceParty.member_genome(e)
	var whole := true
	for key in Voice.ProsodyWalk.PRIOR:
		var want: float = float(kept[key]) if kept.has(key) else float(Voice.ProsodyWalk.PRIOR[key])
		whole = whole and g.has(key) and is_equal_approx(float(g[key]), want)
	_ok(whole, "a partial genome comes back whole: %d measured genes, %d from the PRIOR" % [
		kept.size(), Voice.ProsodyWalk.PRIOR.size() - kept.size()])
	_ok(var_to_bytes(e.genome) == var_to_bytes(kept),
		"...and the entry keeps the %d it was given (it has %d)" % [kept.size(), (e.genome as Dictionary).size()])


## Every function the editor calls, on one belt, candidate and drift; their answers in order.
func _ask(belt: Array, cand: Dictionary, drift: float) -> Array:
	var out: Array = []
	var field := VoiceParty.field_at(cand, belt, drift)
	var held := var_to_bytes(field)
	var party := VoiceParty.party_vector(belt)
	var sv := VoiceParty.seed_vector(cand.traits, cand.lineage, cand.genome)
	out.append_array([field, party, sv, VoiceParty.seed_vector(cand.traits, cand.lineage),
		VoiceParty.background_traits(belt), VoiceParty.reel_power(belt),
		VoiceParty.field_sources(belt), VoiceParty.field_mode(cand.lineage),
		VoiceParty.candidate_difficulty(cand, belt),
		VoiceParty.relative_fit(cand.traits, cand.lineage, cand.genome, belt),
		VoiceParty.bearing_of(sv, party), VoiceParty.cosine(sv, party),
		VoiceParty.relative_norm([0.1, 0.5, -0.3]), VoiceParty.field_bias(field.vec),
		VoiceParty.temper_traits({"pitch": 1.0, "grit": 1.0, "air": 1.0, "song": 1.0}, drift, belt, field),
		VoiceParty.temper_traits(cand.traits, drift, belt, field)])
	for e in belt:
		out.append_array([VoiceParty.member_genome(e), VoiceParty.seed_value(e),
			VoiceParty.acceptance(e, belt), VoiceParty.closeness(e, cand),
			VoiceParty.member_bearing(e, party)])
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(str(cand.lineage))
		var ens := VoiceParty.ensemble_traits(e, rng, belt, field)
		out.append_array([ens, VoiceParty.sustain_bank(ens.traits, ens.contributions)])
	if var_to_bytes(field) != held:
		_fields_written += 1
	return out


func _check_reads_only() -> void:
	var calls := 0
	var written: Array = []
	var differs: Array = []
	var moved := false
	var bi := 0
	for belt0 in _belts():
		var ci := 0
		for cand0 in _cands():
			for drift in [0.0, 0.4, 2.5]:
				var belt: Array = (belt0 as Array).duplicate(true)
				var cand: Dictionary = (cand0 as Dictionary).duplicate(true)
				var before := var_to_bytes([belt, cand])
				seed(1)
				var first := var_to_bytes(_ask(belt, cand, drift))
				var a := randi()
				seed(987654321)
				var second := var_to_bytes(_ask(belt, cand, drift))
				moved = moved or randi() != a
				calls += 1
				if var_to_bytes([belt, cand]) != before:
					written.append("belt %d cand %d drift %.1f" % [bi, ci, drift])
				if first != second:
					differs.append("belt %d cand %d drift %.1f" % [bi, ci, drift])
			ci += 1
		bi += 1
	_ok(written.is_empty() and _fields_written == 0,
		"%d belts x candidates x drifts asked: nothing handed in was written %s" % [
		calls, "" if written.is_empty() and _fields_written == 0 else str(written) + " fields %d" % _fields_written])
	_ok(differs.is_empty(), "...and each answered the same under another global seed %s" % [
		"" if differs.is_empty() else str(differs)])
	# THE CONTROLS
	var belt: Array = _belts()[3]
	var copy: Array = belt.duplicate(true)
	(copy[2].genome as Dictionary)["verve"] = Voice.ProsodyWalk.PRIOR["verve"]
	_ok(var_to_bytes(copy) != var_to_bytes(belt), "control: one gene completed in a copy is seen")
	_ok(moved, "control: the global generator moved between the two rounds")
