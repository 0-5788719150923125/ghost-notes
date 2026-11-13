extends SceneTree

## Does a pen keep with its voice ([PenPace]; next/desk.md) - matched, paced and rested as the audit asks - on writes made here,
## with no episode, voice or renderer? Each item names its control, which must fail the assertion.
##
## - What goes with which words ([method PenPace.matches], [method PenPace.align]): rows said as they are not written ("5: q1",
##   said "Step five") are matched at their spoken numbers, the first mention after the last match - not a later one (control:
##   a row never said is not matched); a part said quickly is drawn over the words an easy pace takes and then held (control:
##   with no ink to size it, it is stretched to the next part's word).
## - When ([method PenPace.path]): a write's way keeps within its band - never behind a word as it is said, never more than
##   [constant PenPace.AHEAD_MOST] words ahead - at no more than its quickest, and draws a sparse write without crawling
##   (control: the evenest way alone, [method PenPace.taut], crawls); a way made again starts exactly where the pen is.
## - What gives ([method PenPace.rests]): a write too dense for its words is given rests, each at a sentence's end and no longer
##   than [constant PenPace.REST_MOST]; a word no rest can help is let trail and the sentences after it are still rested
##   (control: with no stop before them, nothing is given).
## - The audit ([method PenPace.audit]) counts a pace that halves while drawing as a jump and a stop as none, and a slow stretch
##   as a crawl (control: an even pace counts neither).
##
##   godot --headless --path . --script res://tests/desk/pen_pace_check.gd

var _fails := 0


func _init() -> void:
	_matched()
	_sized()
	_banded()
	_rested()
	_audited()
	print("pen_pace_check: %s (%d failures)" % ["ALL OK" if _fails == 0 else "FAILED", _fails])
	quit(1 if _fails > 0 else 0)


func _ok(cond: bool, what: String) -> void:
	if not cond:
		_fails += 1
		print("  FAIL: " + what)


## [param text] as the reading's spoken words, and which of them end a sentence.
static func _said(text: String) -> Array:
	var words := PackedStringArray()
	var ends: Array = []
	for w in text.split(" ", false):
		words.append(TabletScript.norm(w))
		ends.append(w.ends_with(".") or w.ends_with("?") or w.ends_with("!"))
	return [words, ends]


## Steady word times: [param n] words [param word] seconds apart from [param t], a pause of [param pause] after each that ends
## a sentence.
static func _times(n: int, ends: Array, word: float, pause := 0.3, t := 0.0) -> Array:
	var out: Array = []
	for k in n:
		out.append(Vector2(t, t + word * 0.9))
		t += word + (pause if bool(ends[k]) else 0.0)
	return out


func _matched() -> void:
	var said: Array = _said("One zero one one, in [q] zero. Steps one to four, right, onto the blank. Step five, left. Step six, write zero. Step seven, left. One one zero zero: three plus one is four, in eight steps.")
	var words: PackedStringArray = said[0]
	var labels := PackedStringArray(["0: $q_0$", "1", "0", "4: $q_0$", "1", "0", "5: $q_1$", "6: $q_2$", "7: $q_1$", "8: H", "9: $q_4$"])
	var starts := PackedFloat32Array()
	for k in labels.size():
		starts.append(float(k) / float(labels.size()))
	var at := {}
	for h in PenPace.matches(labels, starts, words):
		at[int(h[0])] = int(h[1])
	_ok(int(at.get(6, -1)) == words.find("five") and int(at.get(7, -1)) == words.find("six") and int(at.get(8, -1)) == words.find("seven"),
		"rows said as \"Step five\" are matched at their numbers (%s)" % str(at))
	_ok(int(at.get(3, -1)) == words.find("four"), "the first mention after the last match, not the later \"four\" (%d)" % int(at.get(3, -1)))
	_ok(not at.has(10), "CONTROL: a row never said is not matched")


func _sized() -> void:
	var said: Array = _said("Here is the tape we draw, and then we talk for a long while about something else entirely before the head comes.")
	var words: PackedStringArray = said[0]
	var labels := PackedStringArray(["tape", "head"])
	var starts := PackedFloat32Array([0.0, 0.5])
	var map := PenPace.align(labels, starts, words, 6.0)
	var tape := words.find("tape")
	var head := words.find("head")
	# ...the tape's part (half of 6 s of ink, at an easy pace) takes a few words, not all the talk to the head
	var held := PenPace.on_map(map, float(tape) + 5.0) >= 0.5 - 1e-4 and PenPace.on_map(map, float(head) - 1.0) <= 0.5 + 1e-4
	_ok(held, "a part said quickly is drawn over the words an easy pace takes, then held (%s)" % str(map))
	var straight := PenPace.align(labels, starts, words)
	_ok(PenPace.on_map(straight, float(tape) + 5.0) < 0.5 - 0.05, "CONTROL: with no ink to size it, it is stretched to the next part's word")


func _banded() -> void:
	var said: Array = _said("We write the heading now. Then we say a few more words about it. And that is all for this one line.")
	var words: PackedStringArray = said[0]
	var ends: Array = said[1]
	var times := _times(words.size(), ends, 0.45, 0.3, 10.0)
	var map := PenPace.align(PackedStringArray(["heading"]), PackedFloat32Array([0.0]), words, 4.0)
	var way := PenPace.path(map, times, PackedFloat32Array([9.0, 8.5, 8.0]), 4.0, 8.0)
	var times_s := PackedFloat32Array()
	var drawn := PackedFloat32Array()
	var t := 8.0
	while t < float((times[times.size() - 1] as Vector2).y) + 1.0:
		times_s.append(t)
		drawn.append(PenPace.at(way, t))
		t += 0.1
	var got := PenPace.audit(map, times, times_s, drawn, 4.0)
	# ...behind within the audit's own sampling
	_ok(float(got["behind"]) <= 0.1 + 1e-3 and float(got["ahead"]) <= PenPace.AHEAD_MOST + 0.05 and float(got["fastest"]) <= PenPace.PACE_MOST + 0.05,
		"a write keeps within its band at no more than its quickest (behind %.2f s, ahead %.1f words, fastest %.1f)" % [got["behind"], got["ahead"], got["fastest"]])
	_ok(float(got["crawl"]) < 0.3, "and a sparse write is drawn without crawling (%.1f s)" % got["crawl"])
	# ...the evenest way alone, the band's floor and ceiling as they are, crawls
	var lows := PackedVector2Array()
	var highs := PackedVector2Array()
	for k in times.size():
		lows.append(Vector2((times[k] as Vector2).y, PenPace.on_map(map, float(k + 1))))
		highs.append(Vector2((times[k] as Vector2).y, PenPace.on_map(map, float(k + 1) + PenPace.AHEAD_MOST)))
	var knots := PenPace.taut(Vector2(8.0, 0.0), lows, highs, Vector2(float((times[times.size() - 1] as Vector2).y), 1.0))
	var slow := 0.0
	for k in range(1, knots.size()):
		var pace := (knots[k].y - knots[k - 1].y) * 4.0 / maxf(knots[k].x - knots[k - 1].x, 1e-4)
		if pace > 0.02 and pace < 1.0 / 3.0:
			slow += knots[k].x - knots[k - 1].x
	_ok(slow > 1.0, "CONTROL: the evenest way alone crawls (%.1f s)" % slow)
	var again := PenPace.path(map, times, PackedFloat32Array(), 4.0, 12.0, 0.37)
	_ok(absf(PenPace.at(again, 12.0) - 0.37) < 1e-5 and (again["grid"] as PackedFloat32Array)[1] - 0.37 <= PenPace.PACE_MOST / 4.0 * PenPace.STEP + 1e-5,
		"a way made again starts exactly where the pen is (%.4f)" % PenPace.at(again, 12.0))


func _rested() -> void:
	# ...a dense drawing over two short sentences, then a long run of short sentences
	var text := "Here it is. And so on. First a. Then b. Then c. Then d. Then e. Then f. Then g. Then h."
	var said: Array = _said(text)
	var words: PackedStringArray = said[0]
	var ends: Array = said[1]
	var own := PackedInt32Array()
	for k in words.size():
		own.append(k)
	var map := PackedVector2Array([Vector2.ZERO, Vector2(float(words.size()), 1.0)])
	var given := PenPace.rests([{"map": map, "own": own, "ink": 60.0, "after": 0, "most": PenPace.PACE_MOST}], words.size(), ends, {},
		0.4, 0.3)
	var at_ends := true
	var longest := 0.0
	for k in given:
		at_ends = at_ends and bool(ends[int(k)])
		longest = maxf(longest, float(given[k]))
	_ok(not given.is_empty() and at_ends and longest <= PenPace.REST_MOST + 1e-4,
		"a write too dense for its words is given rests at sentence ends, none past %.1f s (%s)" % [PenPace.REST_MOST, str(given)])
	_ok(given.has(words.size() - 3) or given.has(words.size() - 5), "and the sentences late in it are still rested")
	var flat := _said("one long sentence with no stop at all in it until the very end of what is said here")
	var none_own := PackedInt32Array()
	for k in (flat[0] as PackedStringArray).size():
		none_own.append(k)
	var no_stop: Dictionary = PenPace.rests([{"map": map, "own": none_own, "ink": 60.0, "after": 0, "most": PenPace.PACE_MOST}],
		(flat[0] as PackedStringArray).size(), flat[1], {}, 0.4, 0.3)
	_ok(no_stop.size() <= 1, "CONTROL: with no stop before its words, nothing inside them is given (%s)" % str(no_stop))


func _audited() -> void:
	var map := PackedVector2Array([Vector2.ZERO, Vector2(10.0, 1.0)])
	var said: Array = []
	for k in 10:
		said.append(Vector2(float(k), float(k) + 0.9))
	var times := PackedFloat32Array()
	var lurch := PackedFloat32Array()
	var even := PackedFloat32Array()
	var p := 0.0
	for s in 100:
		times.append(float(s) * 0.1)
		# ...quick for a second, slow for a second, stopped for a second, over and over
		var phase := (s / 10) % 3
		p += 0.02 if phase == 0 else (0.002 if phase == 1 else 0.0)
		lurch.append(minf(p, 1.0))
		even.append(float(s) * 0.01)
	var bad := PenPace.audit(map, said, times, lurch, 10.0)
	var good := PenPace.audit(map, said, times, even, 10.0)
	_ok(int(bad["jumps"]) >= 3 and float(bad["crawl"]) > 1.0, "a pace that halves while drawing is a jump, a slow stretch a crawl (%d, %.1f s)" % [bad["jumps"], bad["crawl"]])
	_ok(int(good["jumps"]) == 0 and float(good["crawl"]) == 0.0, "CONTROL: an even pace counts neither (%d, %.1f s)" % [good["jumps"], good["crawl"]])
