extends SceneTree

## delivery_check - that a script's delivery (next/delivery.md, [DeliveryBank]) reaches the words it says and no others, as it
## says: every bank row read with no word left over; degrees, numbers, ramps and repeats read as the grammar says; a stretch to
## its paragraph's end eased in and let go after, a closed one and `[words]{terms}` exact; a word's act on the last word, or on
## every word for those that say so; a shape and a ramp moving the way they name; the slots reused past their count; a
## note's own named delivery said by its name; the rest at a seam as long as the word before it says.
##
## The controls, each run beside what it holds: a script with no delivery moves no word, the words before a stretch are
## never moved, a word nobody knows moves nothing and is reported.
##
## A delivery as its Lab keeps it (a spec, [method DeliveryBank.spec_of]): every bank row read into one and back says the same; an
## axis of several points moves through them across the stretch, straight between each; an act's own contour rides on its act.
## Each kind of rest after its own axis: a sentence's end by `ends`, a paragraph's by `paragraphs` (never the other), a hesitation
## by `hesitations` (taken out, doubled, where it is spliced and where the voice is told), each exact in seconds whatever the
## dial (controls: a hesitation outside the delivery, semitones never read as seconds, a rate in seconds unknown).
## What a note says of its deliveries ([method DeliveryBank.defs_for]): one tuned is said its way (by a synonym too), one set aside
## moves nothing and is named (an act set aside is said nowhere, inside another delivery too), one said stronger is its degree
## times that, an act drawn its own way is drawn so inside another delivery; the names a mark says are found ([method
## DeliveryBank.names_in]); what an agent is told leaves out what is set aside and names the note's own (controls: a note that
## says nothing of a delivery reads it as the bank does).
##
## Run: godot --headless --path . --script tests/voice/delivery_check.gd

var fails := 0
var checks := 0


func _init() -> void:
	_rows()
	_grammar()
	_stretches()
	_words()
	_shapes()
	_slots()
	_defined()
	_seams()
	_specs()
	_tuned()
	if fails == 0:
		print("delivery_check: ALL OK (%d checks)" % checks)
	else:
		print("delivery_check: %d FAILURE(S) of %d checks" % [fails, checks])
	quit(1 if fails > 0 else 0)


func _ok(cond: bool, msg: String) -> void:
	checks += 1
	if not cond:
		fails += 1
		print("delivery_check: FAIL  " + msg)


func _plan(text: String) -> Dictionary:
	return ReadingPlan.make(text, "", {"reader": "Narrator", "hesitate": true, "bare": 1.0, "outro": 0.0})


## Every token of a plan, in order: [text, token].
func _tokens(plan: Dictionary) -> Array:
	var out := []
	for c in plan["chunks"]:
		for t in (c as Dictionary)["tokens"]:
			out.append([String((t as Dictionary)["text"]), t])
	return out


func _x(t: Dictionary, axis: String, neutral: float) -> float:
	return float((t.get("x", {}) as Dictionary).get(axis, neutral))


func _acts(t: Dictionary) -> Array:
	var out := []
	for a in t.get("acts", []):
		out.append(String(a[0]))
	return out


func _rows() -> void:
	for k in DeliveryBank.BANK:
		var row: Dictionary = DeliveryBank.BANK[k]
		_ok(row.has("label") and row.has("blurb") and DeliveryBank.FAMILIES.has(String(row.get("family", ""))),
			"bank row %s is not a row of a family" % k)
		var d := DeliveryBank.row(k)
		_ok((d["unknown"] as Array).is_empty(), "bank row %s says words no delivery knows: %s" % [k, str(d["unknown"])])
		_ok(k == "steady" or k == "narrator" or not DeliveryBank.is_empty(d), "bank row %s moves nothing" % k)
	for table in [DeliveryBank.AXES, DeliveryBank.DEGREES, DeliveryBank.SHAPES, DeliveryBank.ACTS, DeliveryBank.FAMILIES]:
		for k in table:
			_ok((table[k] as Dictionary).has("label") and not String((table[k] as Dictionary).get("blurb", "")).is_empty(),
				"%s has no label or blurb" % k)
	# a name is one thing: a synonym never shadows another row's own name
	var own := {}
	for table in [DeliveryBank.BANK, DeliveryBank.ACTS, DeliveryBank.SHAPES]:
		for k in table:
			_ok(not own.has(k), "%s is the name of two things" % k)
			own[k] = true
	for table in [DeliveryBank.BANK, DeliveryBank.ACTS, DeliveryBank.SHAPES]:
		for k in table:
			for a in (table[k] as Dictionary).get("aka", []):
				_ok(not own.has(String(a)), "%s, a synonym of %s, is another row's own name" % [a, k])
	_ok(DeliveryBank.listed().contains("excited") and DeliveryBank.listed().contains("drawn"),
		"the list an agent is told leaves the bank out")
	# ...what each act sounds like, and the numbers it shows read as they are shown
	for k in DeliveryBank.ACTS:
		var told := String((DeliveryBank.ACTS[k] as Dictionary).get("told", ""))
		_ok(not told.is_empty() and DeliveryBank.listed().contains("%s (%s)" % [k, told]), "an agent is not told what %s sounds like" % k)
	var shown := DeliveryBank.parse("ends 1.5, commas 0.6, hesitations 0, pauses 1.2, paragraphs 2s, rate 1.2, pitch +2st, volume -4dB")
	_ok((shown["unknown"] as Array).is_empty() and (shown["secs"] as Dictionary).has("paragraphs") and (shown["axes"] as Dictionary).has("ends"),
		"the numbers an agent is shown do not read as shown: %s" % str(shown["unknown"]))


func _grammar() -> void:
	var near := func(a: float, b: float) -> bool: return absf(a - b) < 1e-4
	var d := DeliveryBank.parse("rate 1.2, pitch +3st, volume -6dB, pauses 50%")
	_ok(near.call(float(d["axes"]["rate"]), log(1.2)) and near.call(float(d["axes"]["pitch"]), 3.0)
			and near.call(float(d["axes"]["volume"]), -6.0) and near.call(float(d["axes"]["pauses"]), log(0.5)),
		"numbers are not read in their units: %s" % str(d["axes"]))
	d = DeliveryBank.parse("rate 1..1.4")
	_ok((d["ramps"] as Dictionary).has("rate") and near.call(float(d["ramps"]["rate"]["points"][1][1]), log(1.4))
			and int(d["ramps"]["rate"]["q"]) == 2, "a rate ramp is not read, or does not brake: %s" % str(d["ramps"]))
	var once := float(DeliveryBank.parse("excited")["axes"]["pitch"])
	_ok(near.call(float(DeliveryBank.parse("very excited")["axes"]["pitch"]), once * 1.75)
			and near.call(float(DeliveryBank.parse("excited a little")["axes"]["pitch"]), once * 0.5)
			and near.call(float(DeliveryBank.parse("excited 0.6")["axes"]["pitch"]), once * 0.6)
			and near.call(float(DeliveryBank.parse("extremely excited")["axes"]["pitch"]), once * 2.0),
		"a degree does not scale its term")
	_ok(near.call(float(DeliveryBank.parse("faster faster")["axes"]["rate"]), 2.0 * log(1.15)),
		"a word said twice is not said twice over")
	_ok(near.call(float(DeliveryBank.parse("quicker")["axes"]["rate"]), log(1.15)), "a synonym is not its row")
	_ok(near.call(float(DeliveryBank.parse("furious")["axes"]["pitch"]), 2.0 * float(DeliveryBank.parse("angry")["axes"]["pitch"])),
		"a row written in another's terms is not that row")
	d = DeliveryBank.parse("drawn 0.7s, held, hit hard, building")
	_ok(_acts_named(d) == ["drawn", "held"] and is_equal_approx(float(d["acts"][0][1]), 0.7 / DeliveryBank.DRAWN_SECONDS)
			and int(d["emph"]) == 2 and String(d["shape"]) == "building", "acts, a stress and a shape are not read: %s" % str(d))
	d = DeliveryBank.parse("excited, brisker words, wibble")
	_ok((d["unknown"] as Array) == ["brisker words", "wibble"] and (d["axes"] as Dictionary).has("pitch"),
		"an unknown word is not reported, or costs the known ones: %s" % str(d["unknown"]))
	_ok(DeliveryBank.is_empty(DeliveryBank.parse("")) and DeliveryBank.is_empty(DeliveryBank.parse("steady")),
		"nothing, or the voice's own, moves something")
	# clamped where it is sent, and only what moves is sent
	var x := DeliveryBank.outer({"rate": log(9.0), "pitch": 40.0, "volume": 0.0001})
	_ok(is_equal_approx(float(x["rate"]), 2.0) and is_equal_approx(float(x["pitch"]), 14.0) and not x.has("volume"),
		"axis values are not clamped, or a value that does not move is sent: %s" % str(x))


func _acts_named(d: Dictionary) -> Array:
	var out := []
	for a in d["acts"]:
		out.append(String(a[0]))
	return out


func _stretches() -> void:
	var plain := _tokens(_plan("One two three. Four five six seven eight."))
	var any := false
	for p in plain:
		any = any or (p[1] as Dictionary).has("x") or (p[1] as Dictionary).has("acts")
	_ok(not any, "a script with no delivery moved a word (the control)")
	var toks := _tokens(_plan("Calm words here.\n\n<!-- delivery: faster -->\nOne two three four five six seven eight nine ten.\n\nAfter that, quiet, steady, and far along to the very end."))
	var r := {}
	for p in toks:
		r[p[0]] = _x(p[1], "rate", 1.0)
	_ok(float(r["calm"]) == 1.0 and float(r["here"]) == 1.0, "the words before a stretch were moved (the control): %s" % str(r))
	_ok(float(r["one"]) > 1.0 and float(r["one"]) < float(r["four"]) and is_equal_approx(float(r["ten"]), 1.15),
		"a stretch did not ease in to all of it: %s" % str(r))
	_ok(float(r["after"]) > 1.0 and float(r["after"]) < 1.15 and float(r["end"]) == 1.0,
		"a stretch did not let go after its paragraph: %s" % str(r))
	# closed: exact, from its first word to its last, eased neither way
	toks = _tokens(_plan("One two <!-- delivery: faster -->three four five<!-- /delivery --> six seven."))
	r = {}
	for p in toks:
		r[p[0]] = _x(p[1], "rate", 1.0)
	_ok(float(r["two"]) == 1.0 and is_equal_approx(float(r["three"]), 1.15) and is_equal_approx(float(r["five"]), 1.15)
			and float(r["six"]) == 1.0, "a closed stretch is not exact: %s" % str(r))
	# a stretch inside one adds to it
	toks = _tokens(_plan("<!-- delivery: faster, sudden -->\nOne two <!-- delivery: faster -->three<!-- /delivery --> four."))
	r = {}
	for p in toks:
		r[p[0]] = _x(p[1], "rate", 1.0)
	_ok(absf(float(r["three"]) - 1.15 * 1.15) < 0.002 and absf(float(r["four"]) - 1.15) < 0.002,
		"a stretch inside another does not add to it: %s" % str(r))
	# steady ends one; another to its paragraph's end replaces it
	toks = _tokens(_plan("<!-- delivery: faster, sudden -->\nOne two three four. <!-- delivery: steady --> Five six seven eight nine ten eleven twelve."))
	r = {}
	for p in toks:
		r[p[0]] = _x(p[1], "rate", 1.0)
	_ok(is_equal_approx(float(r["four"]), 1.15) and float(r["twelve"]) == 1.0, "steady does not end a delivery: %s" % str(r))


func _words() -> void:
	var toks := _tokens(_plan("A frog, [and]{drawn, held} five arrows. [Get down now]{shouting} he said. [So very]{none, hit} true."))
	var t := {}
	for p in toks:
		t[p[0]] = p[1]
	_ok(_acts(t["and"]) == ["drawn", "held"] and _acts(t["frog"]).is_empty() and _acts(t["five"]).is_empty(),
		"a word's acts do not reach it alone: %s" % str(t["and"]))
	_ok(is_equal_approx(_x(t["get"], "pitch", 0.0), 8.0) and is_equal_approx(_x(t["now"], "pitch", 0.0), 8.0)
			and _x(t["he"], "pitch", 0.0) == 0.0 and _x(t["arrows"], "pitch", 0.0) == 0.0,
		"the bracketed words are not all of it, or it reaches past them: %s %s" % [str(t["get"].get("x")), str(t["he"].get("x"))])
	_ok(_acts(t["so"]) == ["none"] and _acts(t["very"]) == ["none"] and int(t["so"].get("emph", 0)) == 1
			and int(t["very"].get("emph", 0)) == 1, "an act every word takes did not reach every word")
	# a contour goes on the last word alone
	toks = _tokens(_plan("You [ate all]{scoop} of it?"))
	t = {}
	for p in toks:
		t[p[0]] = p[1]
	_ok(_acts(t["all"]) == ["scoop"] and _acts(t["ate"]).is_empty(), "a contour is not on its stretch's last word alone")


func _shapes() -> void:
	var toks := _tokens(_plan("<!-- delivery: excited, building -->\nOne two three four five six seven eight nine ten."))
	var p := []
	for q in toks:
		p.append(_x(q[1], "pitch", 0.0))
	var rising := true
	for i in range(1, p.size()):
		rising = rising and float(p[i]) >= float(p[i - 1])
	_ok(rising and float(p[0]) < 0.6 and float(p[p.size() - 1]) > 2.5, "building does not build: %s" % str(p))
	toks = _tokens(_plan("<!-- delivery: speeding up -->\nOne two three four five six seven eight nine ten.<!-- delivery: sudden -->"))
	var r := []
	for q in toks:
		r.append(_x(q[1], "rate", 1.0))
	var faster := true
	for i in range(1, r.size()):
		faster = faster and float(r[i]) >= float(r[i - 1]) - 1e-6
	_ok(faster and float(r[r.size() - 1]) > 1.2, "speeding up does not speed up: %s" % str(r))
	toks = _tokens(_plan("<!-- delivery: excited, fading -->\nOne two three four five six seven eight nine ten."))
	_ok(_x(toks[0][1], "pitch", 0.0) > _x(toks[9][1], "pitch", 0.0), "fading does not fade")


func _slots() -> void:
	var words := PackedStringArray()
	for i in 80:
		words.append("[word]{faster}" if i % 2 == 0 else "plain")
	var toks := _tokens(_plan(" ".join(words) + "."))
	var moved := 0
	var wrong := 0
	for i in toks.size():
		var fast := _x(toks[i][1], "rate", 1.0) > 1.0
		moved += 1 if fast else 0
		wrong += 1 if fast != (String(toks[i][0]) == "word") else 0
	_ok(moved == 40 and wrong == 0, "past the slots' count, words are moved that should not be or not moved (%d moved, %d wrong)" % [moved, wrong])


func _defined() -> void:
	var plan := _plan("<!-- delivery: giddy = excited, speeding up -->\n\nPlain words first.\n\n<!-- delivery: giddy -->\nThen the rest of it all comes out at once in a rush.\n\n<!-- delivery: wibbly -->\nAnd a word nobody knows.")
	var toks := _tokens(plan)
	var t := {}
	for p in toks:
		t[p[0]] = p[1]
	_ok(_x(t["first"], "pitch", 0.0) == 0.0 and _x(t["rush"], "pitch", 0.0) > 2.0 and _x(t["rush"], "rate", 1.0) > 1.2,
		"a note's own named delivery is not said by its name")
	_ok(String(plan["note"]).contains("wibbly"), "a word nobody knows is not reported: %s" % plan["note"])


func _seams() -> void:
	var s := {"pause": 1.0, "pause_sentence": 1.0, "pause_paragraph": 1.0}
	var plain: Array = _plan("One thing. Another thing.")["chunks"]
	var tight: Array = _plan("<!-- delivery: tighter, sudden -->\nOne thing. Another thing.")["chunks"]
	var loose: Array = _plan("<!-- delivery: looser, sudden -->\nOne thing. Another thing.")["chunks"]
	var g0 := Delivery.gap_before(plain, 1, s)
	_ok(Delivery.gap_before(tight, 1, s) < g0 and Delivery.gap_before(loose, 1, s) > g0,
		"the rest at a seam does not follow the word before it: %.3f / %.3f / %.3f" % [Delivery.gap_before(tight, 1, s), g0, Delivery.gap_before(loose, 1, s)])
	# each kind of rest its own: a sentence's end by `ends`, a paragraph's by `paragraphs`, never the other
	var two := "One thing. Another thing.\n\nA new paragraph."
	var p0: Array = _plan(two)["chunks"]
	var ends: Array = _plan("<!-- delivery: ends 2, sudden -->\n" + two)["chunks"]
	var paras: Array = _plan("<!-- delivery: paragraphs 2, sudden -->\n" + two)["chunks"]
	var e0 := Delivery.gap_before(p0, 1, s)
	var q0 := Delivery.gap_before(p0, 2, s)
	_ok(Delivery.gap_before(ends, 1, s) > e0 + 0.05 and is_equal_approx(Delivery.gap_before(ends, 2, s), q0)
			and Delivery.gap_before(paras, 2, s) > q0 + 0.05 and is_equal_approx(Delivery.gap_before(paras, 1, s), e0),
		"a sentence's rest and a paragraph's do not each follow their own axis: ends %.3f/%.3f, paragraphs %.3f/%.3f (plain %.3f/%.3f)"
		% [Delivery.gap_before(ends, 1, s), Delivery.gap_before(ends, 2, s), Delivery.gap_before(paras, 1, s), Delivery.gap_before(paras, 2, s), e0, q0])
	# seconds are exact, whatever the dial
	var exact: Array = _plan("<!-- delivery: ends 1.5s, sudden -->\n" + two)["chunks"]
	var slow := {"pause": 1.0, "pause_sentence": 3.0, "pause_paragraph": 1.0}
	_ok(absf(Delivery.gap_before(exact, 1, s) + Delivery.SENTENCE_DWELL - 1.5) < 1e-3
			and absf(Delivery.gap_before(exact, 1, slow) - Delivery.gap_before(exact, 1, s)) < 1e-3,
		"a sentence's rest in seconds is not that long whatever the dial: %.3f" % (Delivery.gap_before(exact, 1, s) + Delivery.SENTENCE_DWELL))
	var d := DeliveryBank.parse("paragraphs 2s, pitch 3st, pauses 0.5s")
	_ok(is_equal_approx(float(d["secs"]["paragraphs"]), 0.5) and is_equal_approx(float(d["secs"]["commas"]), 0.5)
			and is_equal_approx(float(d["axes"]["pitch"]), 3.0) and (d["unknown"] as Array).is_empty()
			and not (DeliveryBank.parse("rate 2s")["unknown"] as Array).is_empty(),
		"seconds are not read as a rest's (the later standing, `pauses` every kind), or semitones read as seconds, or a rate in seconds taken (control): %s" % str(d))
	# a hesitation as long as the delivery round it says: out, doubled, in seconds; untouched outside it (control)
	var held := func(text: String) -> Array:
		var out: Array = []
		for c in _plan(text)["chunks"]:
			for h in (c as Dictionary)["holds"]:
				out.append(float((h as Dictionary)["sec"]))
			for t in (c as Dictionary)["tokens"]:
				if (t as Dictionary).has("rest_after"):
					out.append(-float((t as Dictionary)["rest_after"]))
		return out
	var base: Array = held.call("We went down, and <!-- hesitation --> there it was.")
	var gone: Array = held.call("[We went down, and <!-- hesitation --> there it was.]{hesitations 0}")
	var twice: Array = held.call("[We went down, and <!-- hesitation --> there it was.]{hesitations 2}")
	var secs: Array = held.call("[We went down, and <!-- hesitation --> there it was.]{hesitations 0.3s}")
	var other: Array = held.call("[We went down,]{hesitations 0} and <!-- hesitation --> there it was.")
	_ok(base.size() == 2 and base[0] > 0.1 and is_equal_approx(-float(base[1]), float(base[0])),
		"a hesitation is not spliced and told: %s" % str(base))
	_ok(gone.all(func(v: float) -> bool: return v == 0.0) or gone == [0.0],
		"a hesitation a delivery takes out is still spliced or told: %s" % str(gone))
	_ok(twice.size() == 2 and is_equal_approx(float(twice[0]), 2.0 * float(base[0])) and is_equal_approx(-float(twice[1]), float(twice[0])),
		"a hesitation a delivery doubles is not doubled where it is spliced and where it is told: %s" % str(twice))
	_ok(secs.size() == 2 and is_equal_approx(float(secs[0]), 0.3), "a hesitation in seconds is not that long: %s" % str(secs))
	_ok(other == base, "a hesitation outside the delivery is moved by it (control): %s" % str(other))
	# the rests made here never reach the host, so a change to one asks no take again; a comma's (the host's) does
	var said := func(text: String) -> Array:
		var c: Dictionary = (_plan(text)["chunks"] as Array)[0]
		return Delivery.host_tokens(c["tokens"])
	var plain_said: Array = said.call("We went down, and there it was.")
	_ok(said.call("[We went down, and there it was.]{ends 2, paragraphs 0.5, hesitations 0}") == plain_said
			and said.call("[We went down, and there it was.]{commas 2}") != plain_said,
		"a rest made here reaches the host, or a comma's does not (control)")


func _specs() -> void:
	var near := func(a: float, b: float) -> bool: return absf(a - b) < 1e-3
	for k in DeliveryBank.BANK:
		var spec := DeliveryBank.spec_of_name(String(k))
		var back := DeliveryBank.from_spec(spec)
		var row := DeliveryBank.row(String(k))
		# as they are sent: a row past an axis's limits is held to them either way
		var sent_row := DeliveryBank.outer(row["axes"])
		var sent_back := DeliveryBank.outer(back["axes"])
		var same := true
		for axis in sent_row:
			same = same and (sent_back.has(axis) and near.call(float(sent_back[axis]), float(sent_row[axis])) \
				or (back["ramps"] as Dictionary).has(axis))
		for axis in row["ramps"]:
			for x in [0.0, 0.3, 0.7, 1.0]:
				var held := float(row["axes"].get(axis, 0.0))
				same = same and near.call(DeliveryBank.ramp_at(axis, back["ramps"][axis], x), DeliveryBank.ramp_at(axis, row["ramps"][axis], x) + held)
		same = same and (back["acts"] as Array).size() == (row["acts"] as Array).size() and String(back["shape"]) == String(row["shape"]) \
			and int(back["emph"]) == int(row["emph"])
		_ok(same, "bank row %s read into a spec and back is not the row: %s" % [k, str(spec)])
	# several points: through each, straight between
	var d := DeliveryBank.from_spec({"axes": {"pitch": [[0.0, 0.0], [0.5, 4.0], [1.0, 1.0]], "rate": [[0.0, 1.2]]}})
	_ok(near.call(float(d["axes"]["rate"]), log(1.2)) and (d["ramps"] as Dictionary).has("pitch")
			and near.call(DeliveryBank.ramp_at("pitch", d["ramps"]["pitch"], 0.25), 2.0)
			and near.call(DeliveryBank.ramp_at("pitch", d["ramps"]["pitch"], 0.5), 4.0)
			and near.call(DeliveryBank.ramp_at("pitch", d["ramps"]["pitch"], 0.75), 2.5),
		"a curve of several points does not run through them: %s" % str(d))
	var toks := _tokens(ReadingPlan.make("One two three four five six seven eight nine ten.", "", {"reader": "Narrator", "hesitate": true,
		"bare": 1.0, "outro": 0.0, "deliveries": {"tuned": {"hill": {"axes": {"pitch": [[0.0, 0.0], [0.5, 4.0], [1.0, 0.0]]}}}}}))
	var plain := _tokens(ReadingPlan.make("[One two three four five six seven eight nine ten.]{hill}", "", {"reader": "Narrator",
		"hesitate": true, "bare": 1.0, "outro": 0.0}))
	var hill := _tokens(ReadingPlan.make("[One two three four five six seven eight nine ten.]{hill}", "", {"reader": "Narrator",
		"hesitate": true, "bare": 1.0, "outro": 0.0, "deliveries": {"tuned": {"hill": {"axes": {"pitch": [[0.0, 0.0], [0.5, 4.0], [1.0, 0.0]]}}}}}))
	var mid := _x(hill[5][1], "pitch", 0.0)
	_ok(mid > 2.5 and _x(hill[0][1], "pitch", 0.0) < 1.0 and _x(hill[9][1], "pitch", 0.0) < 1.0,
		"a hill across a stretch does not rise to its middle and come down: %s" % str(hill.map(func(t: Array) -> float: return _x(t[1], "pitch", 0.0))))
	_ok(toks.all(func(t: Array) -> bool: return not (t[1] as Dictionary).has("x")),
		"a tuned delivery moves words the script never says it on (control)")
	_ok(plain.all(func(t: Array) -> bool: return not (t[1] as Dictionary).has("x")),
		"a name nobody tuned moves something (control)")
	# an act's own contour rides on its act to the words
	var own := [["stress<", 0.0], [0.5, 2.5], [1.0, 0.0]]
	var drawn := _tokens(ReadingPlan.make("A frog, [and]{drawn} five arrows.", "", {"reader": "Narrator", "hesitate": true, "bare": 1.0,
		"outro": 0.0, "deliveries": {"tuned": {"drawn": {"acts": {"drawn": 1.0}, "contours": {"drawn": own}}}}}))
	var acts: Array = (drawn[2][1] as Dictionary).get("acts", [])
	_ok(acts.size() == 1 and (acts[0] as Array).size() == 3 and str(acts[0][2]) == str(own),
		"an act's own contour does not reach its word: %s" % str(acts))
	_ok(DeliveryBank.line_of(DeliveryBank.spec_of("rate 1.15, pitch 0..4st, drawn")).contains("rate 1.15x")
			and DeliveryBank.line_of(DeliveryBank.spec_of("pitch 0..4st")).contains("→"), "a spec's line does not say what it moves")


func _tuned() -> void:
	var near := func(a: float, b: float) -> bool: return absf(a - b) < 1e-3
	var tuned := {"excited": {"axes": {"pitch": [[0.0, 5.0]]}}}
	var defs := DeliveryBank.defs_for({"tuned": tuned})
	_ok(near.call(float(DeliveryBank.parse("excited", defs)["axes"]["pitch"]), 5.0)
			and near.call(float(DeliveryBank.parse("very excited", defs)["axes"]["pitch"]), 5.0 * 1.75),
		"a tuned delivery is not said its way, or its degree does not scale it")
	defs = DeliveryBank.defs_for({"tuned": {"faster": {"axes": {"rate": [[0.0, 1.5]]}}}})
	_ok(near.call(float(DeliveryBank.parse("quicker", defs)["axes"]["rate"]), log(1.5)), "a synonym of a tuned delivery is the bank's")
	_ok(near.call(float(DeliveryBank.parse("excited", {})["axes"]["pitch"]), float(DeliveryBank.row("excited")["axes"]["pitch"])),
		"a note that says nothing of a delivery does not read it as the bank does (control)")
	defs = DeliveryBank.defs_for({"off": ["excited", "drawn"]})
	var d := DeliveryBank.parse("excited, held", defs)
	_ok((d["axes"] as Dictionary).is_empty() and (d["aside"] as Array).has("excited") and (d["acts"] as Array).size() == 1,
		"a delivery set aside moves something, or is not named: %s" % str(d))
	_ok((DeliveryBank.parse("drawn, held", defs)["acts"] as Array).size() == 1, "an act set aside is still said")
	var with_drawn := ""
	for k in DeliveryBank.BANK:
		if String(DeliveryBank.BANK[k]["terms"]).contains("drawn"):
			with_drawn = String(k)
			break
	if not with_drawn.is_empty():
		_ok(not str(DeliveryBank.parse(with_drawn, defs)["acts"]).contains("drawn"), "an act set aside is said inside %s" % with_drawn)
		var own := [[0.0, 0.0], [0.5, 1.0]]
		var drawn_own := DeliveryBank.defs_for({"tuned": {"drawn": {"acts": {"drawn": 1.0}, "contours": {"drawn": own}}}})
		var inside: Array = DeliveryBank.parse(with_drawn, drawn_own)["acts"]
		_ok(inside.any(func(a: Array) -> bool: return String(a[0]) == "drawn" and a.size() == 3),
			"an act drawn its own way is not drawn so inside %s: %s" % [with_drawn, str(inside)])
	defs = DeliveryBank.defs_for({"strength": {"excited": 0.5}})
	_ok(near.call(float(DeliveryBank.parse("excited", defs)["axes"]["pitch"]), 0.5 * float(DeliveryBank.row("excited")["axes"]["pitch"])),
		"a delivery said weaker is not its degree times that")
	_ok(DeliveryBank.names_in("very excited, rate 1.2, drawn 0.5s, giddy, quicker, building", {"giddy": true})
			== PackedStringArray(["excited", "drawn", "giddy", "faster"]), "the names a mark says are not found: %s"
			% str(DeliveryBank.names_in("very excited, rate 1.2, drawn 0.5s, giddy, quicker, building", {"giddy": true})))
	var told := DeliveryBank.listed({"off": ["excited"], "about": {"giddy": "breathless and quick"}})
	_ok(not told.contains("excited,") and not told.contains(", excited") and told.contains("giddy (breathless and quick)")
			and told.contains("Set aside here, never to be written: excited"), "what an agent is told does not follow the note: %s" % told)
	_ok(DeliveryBank.listed().contains("excited"), "what an agent is told of no note leaves the bank out (control)")

