extends SceneTree

## table_surroundings_check - a table's sound and lasting air as Environment elements, and back ([TableSurroundings], [Surroundings]'s
## `own`), with no renderer.
##
##   godot --headless --path . --script res://tests/table/table_surroundings_check.gd
##
## - Every part of a table's sound is an element of its kind (a creature each), and written back unchanged is the same sound, its
##   `why` kept; changed, the change reaches exactly that part (the control: the level changed is heard changed); taken away, the part
##   goes.
## - The lasting air (a fog, motes of every look) is an element each, a burst and what the wind carries none; written back unchanged
##   it is the same effects in the same order. Amount 2 is twice the motes as made (the control: 1 as made); a color changed is that
##   color alone, the first color kept keeps the list.
## - Set aside, an element is the table's `environment_aside` and nothing plays it; used again it plays again and the list goes.
## - An element from the Dex stands at a table where its kind does: fireflies beyond the table as many as their kind, a fog beyond the
##   table with all it is told, rain heard on what it falls on.
## - A table's element kept and used on any note: a creature keeps its calls (the control: one with no words of its own chirps);
##   motes at a place that note has not got stand where their kind does. A host's as written is never drawn: an unset property is its
##   default for any number (the control: a plain element's is drawn by its number). The ride is not offered on the Dex; a creature
##   and flies are.

const PALETTE := ["#2a1f1a", "#c9a227", "#7a3b2e"]

var _fails := 0


func _init() -> void:
	_sound()
	_air()
	_aside()
	_from_dex()
	_portable()
	print("table_surroundings_check: %s (%d failure%s)" % ["ALL OK" if _fails == 0 else "FAILED", _fails, "" if _fails == 1 else "s"])
	quit(1 if _fails > 0 else 0)


func _ok(cond: bool, what: String) -> void:
	if not cond:
		_fails += 1
		print("  FAIL: " + what)


func _table() -> Dictionary:
	return {
		"sound": {"why": "a cabin at sea", "wind": {"through": "rigging", "level": 0.45, "from": "left", "strength": 0.3, "gusts": 0.5, "every": 20.0},
			"water": {"kind": "hull", "size": 0.3, "from": "back", "distance": 0.5}, "rain": {"on": "roof", "strength": 0.6},
			"fire": {"size": 0.4, "from": "right", "distance": 0.2}, "stream": {"size": 0.2, "distance": 0.7},
			"insects": {"kind": "cicadas", "strength": 0.34}, "ride": {"level": 0.35},
			"creatures": [{"name": "a cat asleep on a chair", "size": 0.4, "breath": 0.6, "calls": ["purr", "snore"], "count": 1, "rate": 3.0,
				"side": 0.5, "near": 0.8, "awake": [0.1, 0.3], "over": 600.0},
				{"name": "frogs at the pond", "size": 0.5, "calls": ["croak"], "count": 4, "rate": 12.0, "side": -0.6, "near": 0.2}]},
		"light": {"wind": {"strength": 0.4, "gusts": 0.3}},
		"effects": [
			{"name": "harbor fog", "kind": "fog", "where": "beyond the table", "density": 0.4, "rolls": 0.5, "drift": 0.2, "height": 30, "grain": 20},
			{"name": "spark", "kind": "burst", "look": "stars", "on": "close"},
			{"name": "flies", "kind": "motes", "look": "fly", "where": "beyond the table", "count": 3, "colors": ["#16130f", "#2a2016"], "size": 4.0},
			{"name": "petals", "kind": "drift", "look": "petals"},
			{"name": "dust", "kind": "motes", "look": "dust", "where": "over the cloth", "count": 40, "glow": 0.3, "speed": 0.2}],
	}


func _els_of(t: Dictionary) -> Array:
	return TableSurroundings.elements_of(t, 7, PALETTE)


func _fx(t: Dictionary) -> Array:
	return Effects.sanitize(t.get("effects", []), PALETTE, CardTable.AIR.keys(), CardTable.MOMENTS.keys())


func _index_of(els: Array, kind: String) -> int:
	for i in els.size():
		if String((els[i] as Dictionary)["kind"]) == kind:
			return i
	return -1


func _sound() -> void:
	var t := _table()
	var els := _els_of(t)
	var kinds := els.map(func(e: Dictionary) -> String: return String(e["kind"]))
	for k in ["wind", "sea", "rain", "fire", "stream", "insects", "ride"]:
		_ok(kinds.count(k) == 1, "the sound's %s is one element (%s)" % [k, str(kinds)])
	_ok(kinds.count("creature") == 2, "each creature is an element of its own")
	_ok(els.all(func(e: Dictionary) -> bool: return e.has("own")), "each is the table's as written")
	var back := TableSurroundings.with_elements(t, els, 7, PALETTE)
	_ok(JSON.stringify(Soundscape.sanitize(back["sound"]), "", true) == JSON.stringify(Soundscape.sanitize(t["sound"]), "", true),
		"written back unchanged, it is the same sound:\n    %s\n    %s" % [JSON.stringify(Soundscape.sanitize(back["sound"]), "", true),
			JSON.stringify(Soundscape.sanitize(t["sound"]), "", true)])
	_ok(String((back["sound"] as Dictionary).get("why", "")) == "a cabin at sea", "its why kept")
	# a change reaches that part alone
	var changed := els.duplicate(true)
	(changed[_index_of(changed, "wind")] as Dictionary)["level"] = 0.9
	var heard := Soundscape.sanitize(TableSurroundings.with_elements(t, changed, 7, PALETTE)["sound"])
	_ok(is_equal_approx(float((heard["wind"] as Dictionary)["level"]), 0.9), "the control: the wind's level changed is heard changed")
	_ok(is_equal_approx(float((heard["wind"] as Dictionary)["from"]), float((Soundscape.sanitize(t["sound"])["wind"] as Dictionary)["from"])),
		"and where it is heard from stays")
	var without := els.duplicate(true)
	without.remove_at(_index_of(without, "rain"))
	_ok(not Soundscape.sanitize(TableSurroundings.with_elements(t, without, 7, PALETTE)["sound"]).has("rain"), "taken away, the rain goes")
	# insects told no amount stay as they always sang
	var ins: Dictionary = els[_index_of(els, "insects")]
	_ok(not ins.has("amount"), "insects told no amount are told none")
	_ok(not (Soundscape.sanitize(back["sound"])["insects"] as Dictionary).has("amount"), "and written back sing as they always did")


func _air() -> void:
	var t := _table()
	var els := _els_of(t)
	var kinds := els.map(func(e: Dictionary) -> String: return String(e["kind"]))
	_ok(kinds.count("haze") == 1 and kinds.count("flies") == 1 and kinds.count("dust") == 1,
		"a fog is a haze, motes the kind their look is (%s)" % str(kinds))
	_ok(not kinds.has("burst") and not kinds.has("drift"), "a burst and what the wind carries are no element")
	var back := TableSurroundings.with_elements(t, els, 7, PALETTE)
	_ok(JSON.stringify(_fx(back), "", true) == JSON.stringify(_fx(t), "", true),
		"written back unchanged, the same effects in the same order:\n    %s\n    %s" % [JSON.stringify(_fx(back)), JSON.stringify(_fx(t))])
	var more := els.duplicate(true)
	(more[_index_of(more, "dust")] as Dictionary)["amount"] = 2.0
	var counts := _fx(TableSurroundings.with_elements(t, more, 7, PALETTE)).filter(func(f: Dictionary) -> bool: return String(f.get("look", "")) == "dust")
	_ok(counts.size() == 1 and int((counts[0] as Dictionary)["count"]) == 80, "Amount 2 is twice the motes as made (%s)" % str(counts))
	var as_made := _fx(back).filter(func(f: Dictionary) -> bool: return String(f.get("look", "")) == "dust")
	_ok(int((as_made[0] as Dictionary)["count"]) == 40, "the control: Amount 1 is as many as made")
	var flies: Dictionary = _fx(back).filter(func(f: Dictionary) -> bool: return String(f.get("look", "")) == "fly")[0]
	_ok((flies["colors"] as Array).size() == 2, "the first color kept keeps the list")
	var recolor := els.duplicate(true)
	(recolor[_index_of(recolor, "flies")] as Dictionary)["color"] = "#ff0000"
	var re: Dictionary = _fx(TableSurroundings.with_elements(t, recolor, 7, PALETTE)).filter(func(f: Dictionary) -> bool: return String(f.get("look", "")) == "fly")[0]
	_ok((re["colors"] as Array).size() == 1 and Color.html(String((re["colors"] as Array)[0])).is_equal_approx(Color.html("#ff0000")),
		"a color changed is that color alone (%s)" % str(re["colors"]))
	var fewer := els.duplicate(true)
	fewer.remove_at(_index_of(fewer, "haze"))
	var left := _fx(TableSurroundings.with_elements(t, fewer, 7, PALETTE))
	_ok(left.size() == 4 and left.all(func(f: Dictionary) -> bool: return String(f["kind"]) != "fog"), "taken away, the fog goes and the rest stay")


func _aside() -> void:
	var t := _table()
	var els := _els_of(t)
	var off := els.duplicate(true)
	(off[_index_of(off, "fire")] as Dictionary)["off"] = true
	(off[_index_of(off, "dust")] as Dictionary)["off"] = true
	var set_aside := TableSurroundings.with_elements(t, off, 7, PALETTE)
	_ok((set_aside.get(TableSurroundings.ASIDE, []) as Array).size() == 2, "set aside, they are the table's environment_aside")
	_ok(not Soundscape.sanitize(set_aside["sound"]).has("fire"), "and nothing plays the fire")
	_ok(_fx(set_aside).filter(func(f: Dictionary) -> bool: return String(f.get("look", "")) == "dust").is_empty(), "nor the dust")
	var read := _els_of(set_aside)
	_ok(read.filter(func(e: Dictionary) -> bool: return e.get("off") == true).size() == 2, "read again, both are set aside")
	var on := read.duplicate(true)
	for e in on:
		(e as Dictionary).erase("off")
	var used := TableSurroundings.with_elements(set_aside, on, 7, PALETTE)
	_ok(Soundscape.sanitize(used["sound"]).has("fire") and not used.has(TableSurroundings.ASIDE), "used again, the fire plays and the list goes")


func _from_dex() -> void:
	var t := {"sound": {}, "effects": []}
	var flies := Surroundings.element({"kind": "fireflies", "seed": 3})
	var fog := Surroundings.element(((Surroundings.offers()["look:ground"] as Dictionary)["element"]))
	var rain := Surroundings.element({"kind": "rain", "seed": 4, "on": "leaves"})
	var made := TableSurroundings.with_elements(t, [flies, fog, rain], 7, PALETTE)
	var fx := _fx(made)
	var ff: Array = fx.filter(func(f: Dictionary) -> bool: return String(f.get("look", "")) == "firefly")
	_ok(ff.size() == 1 and String((ff[0] as Dictionary)["where"]) == "beyond the table"
		and int((ff[0] as Dictionary)["count"]) == Surroundings.mote_count(flies, Surroundings.values_of(flies)),
		"fireflies stand beyond the table, as many as their kind (%s)" % str(ff))
	var fogs: Array = fx.filter(func(f: Dictionary) -> bool: return String(f["kind"]) == "fog")
	_ok(fogs.size() == 1 and String((fogs[0] as Dictionary)["where"]) == "beyond the table" and (fogs[0] as Dictionary).has("settle"),
		"a fog stands beyond the table with all it is told")
	_ok(String((Soundscape.sanitize(made["sound"]).get("rain", {}) as Dictionary).get("on", "")) == "leaves", "rain is heard on what it falls on")


func _portable() -> void:
	var els := _els_of(_table())
	var cat: Dictionary = els.filter(func(e: Dictionary) -> bool: return String(e["kind"]) == "creature")[0]
	var heard := Surroundings.sound_of({"elements": [cat]})
	_ok(((heard["creatures"] as Array)[0] as Dictionary)["calls"] == ["purr", "snore"], "a kept creature keeps its calls on any note")
	var plain := Surroundings.sound_of({"elements": [Surroundings.element({"kind": "creature", "seed": 1})]})
	_ok(((plain["creatures"] as Array)[0] as Dictionary)["calls"] == ["chirp"], "the control: a creature with no words of its own chirps")
	var dust: Dictionary = els.filter(func(e: Dictionary) -> bool: return String(e["kind"]) == "dust")[0]
	var fx := Surroundings.effects_of({"elements": [dust]}, Color.BLACK)
	_ok(fx.size() == 1 and String((fx[0] as Dictionary)["where"]) == "near", "motes at a place a desk has not got stand where their kind does (%s)" % str(fx))
	var a := cat.duplicate(true)
	a.erase("near")
	var b := a.duplicate(true)
	b["seed"] = 999
	_ok(Surroundings.values_of(a)["near"] == Surroundings.values_of(b)["near"]
		and is_equal_approx(float(Surroundings.values_of(a)["near"]), 0.5), "a host's as written is never drawn: its default for any number")
	var p1 := Surroundings.element({"kind": "creature", "seed": 1})
	var p2 := Surroundings.element({"kind": "creature", "seed": 2})
	_ok(Surroundings.values_of(p1) != Surroundings.values_of(p2), "the control: a plain element's unset properties are drawn by its number")
	var offered := Surroundings.offers()
	_ok(not offered.has("kind:ride") and offered.has("kind:creature") and offered.has("kind:flies"),
		"the ride is not offered on the Dex; a creature and flies are")
