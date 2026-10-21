extends RefCounted
class_name ReadingFollower

## ReadingFollower - where the voice is in a document, and when each of its words was said.
##
## A medium that PERFORMS a reading - a hand on a tablet, cards at a table - knows its document
## as a list of the words it will speak, and learns the voice only as the words arrive (the
## Subtitles overlay's growing `words`, each with its `t0`/`t1`). This lines the two up: every
## spoken word of the document gets the time it began and ended, and [method place] turns a list
## of actions anchored to "after word n" into a schedule that fits the rests the voice left for
## them. The tablet worked this out first; the matching here is its matching.
##
## THE MATCH IS SEQUENTIAL WITH A RESYNC WINDOW, against the SPOKEN words only: each voice word
## is looked for a few words ahead of the last match, so a word the voice spells differently (a
## number read out, a dash) costs one word, never the pointer. A voice word that is the START of
## a document word ("e" of "e.g.") leaves the rest to be matched by the words that follow it.
##
## A READING STARTED MID-WAY (a scrub) begins at [member start_si]: everything before it was said
## long ago, so those words get times in the far past, spaced as a voice would have said them,
## and every action anchored there has already happened by the first frame.
##
## A ONE-LETTER VOICE WORD STARTS THE NEXT WORD it begins: the page's "[c]'s" is one word, `cs`, and
## the voice says it as two, "c" and "'s". Looked for ahead instead, the "c" matched the next `c`
## seven words on, the words between were never heard, and a desk waiting on one of them stood still
## for the last eleven minutes of a lesson (2026-10-20, "What Can One Row of Neurons Imitate?").
##
## A WORD THE VOICE WENT PAST is said all the same: [member said0] / [member said1] give it its share
## of the time between the words either side that were matched, and the words past the last match
## the voice's words after it that matched nothing, one each - so a medium that waits on a word's
## time ([DeskMedium]) waits only for what the voice has not reached.

## A word's time is unknown only at exactly this; every other value, negative included, is a time.
const NO_TIME := -1.0
## The past a mid-way start's earlier words are placed in.
const START_PAST := -100000.0
## A word's length where nothing heard gives one (seconds).
const A_WORD := 0.4

## subtitle word index -> spoken index (or -1 for a word that matched nothing)
var map: Array = []
## spoken index -> when it began / ended (NO_TIME until heard)
var st0 := PackedFloat32Array()
var st1 := PackedFloat32Array()
## spoken index -> when it was said, as [member st0] / [member st1], a word the voice went past
## unmatched with it (see the class note): NO_TIME only for what the voice has not reached
var said0 := PackedFloat32Array()
var said1 := PackedFloat32Array()
## The spoken index a mid-way start begins at, -1 for a reading from the top.
var start_si := -1

var _norms := PackedStringArray()
var _j := 0
var _rem := ""
var _loose: Array = []              # [t0, t1] of each voice word since the last one matched
var _gaps := {}                     # spoken index -> [t0, t1] of the voice's loose words just before it


## Start over against [param norms] (the document's spoken words, normalized - see
## [method TabletScript.norm]). [param est] is each spoken word's estimated time along the
## reading, used only to space the past of a mid-way start at [param from_si].
func reset(norms: PackedStringArray, from_si := -1, est := PackedFloat32Array()) -> void:
	_norms = norms
	map = []
	_j = 0
	_rem = ""
	_loose = []
	_gaps = {}
	var n := norms.size()
	st0 = PackedFloat32Array()
	st0.resize(n)
	st0.fill(NO_TIME)
	st1 = st0.duplicate()
	start_si = from_si
	if from_si > 0:
		_j = from_si
		for j in mini(from_si, n):
			var e := est[j] if j < est.size() else float(j) * A_WORD
			st0[j] = START_PAST + e
			st1[j] = st0[j] + 0.3
	said0 = st0.duplicate()
	said1 = st1.duplicate()


## Take in every voice word not yet seen. A list that SHRANK is a new reading - start over.
func extend(words: Array) -> void:
	if words.size() < map.size():
		reset(_norms, start_si)
	if words.size() == map.size():
		return
	for i in range(map.size(), words.size()):
		var w: Dictionary = words[i]
		var n := TabletScript.norm(String(w.get("text", "")))
		var got := -1
		if n.is_empty():
			got = _j - 1
		elif not _rem.is_empty() and _rem.begins_with(n):
			got = _j - 1
			_rem = _rem.substr(n.length())
		else:
			for k in range(_j, mini(_j + 12, _norms.size())):
				var ln := _norms[k]
				if ln == n or (n.begins_with(ln) and ln.length() >= 2 and k == _j):
					got = k
					_rem = ""
					break
				if ln.begins_with(n) and (n.length() >= 2 or k == _j):
					got = k
					_rem = ln.substr(n.length())
					break
			if got >= 0:
				_j = got + 1
				if not _loose.is_empty():
					_gaps[got] = [float(_loose[0][0]), float(_loose.back()[1])]
		map.append(got)
		if got >= 0:
			st1[got] = float(w.get("t1", 0.0))
			if st0[got] == NO_TIME:
				st0[got] = float(w.get("t0", 0.0))
			_loose = []
		else:
			_loose.append([float(w.get("t0", 0.0)), float(w.get("t1", 0.0))])
	_fill()


## [member said0] / [member said1] from what is matched: a run of words never matched before the last
## one that was spread evenly over what the voice said in its place - its loose words there ("seven" for
## "7"), else the time between its neighbors (a run at the very start ends at the first word matched,
## a word apart) - and the words after the last match given the voice's loose words after it, one
## each, once anything is matched: words before it may be no part of the page.
func _fill() -> void:
	said0 = st0.duplicate()
	said1 = st1.duplicate()
	var last := known_last()
	if last >= 0:
		for j in mini(_loose.size(), st0.size() - 1 - last):
			said0[last + 1 + j] = float(_loose[j][0])
			said1[last + 1 + j] = float(_loose[j][1])
	var k := 0
	while k < last:
		if st0[k] != NO_TIME:
			k += 1
			continue
		var a := k
		while st0[k] == NO_TIME:
			k += 1
		var to := st0[k]
		var from := said1[a - 1] if a > 0 else to - float(k - a) * A_WORD
		var said: Array = _gaps.get(k, [])
		if said.size() == 2:
			from = float(said[0])
			to = float(said[1])
		var step := maxf(to - from, 0.0) / float(k - a)
		for j in range(a, k):
			said0[j] = from + step * float(j - a)
			said1[j] = said0[j] + step


## The last spoken index whose end is known, -1 for none.
func known_last() -> int:
	for i in range(st1.size() - 1, -1, -1):
		if st1[i] != NO_TIME:
			return i
	return -1


## The spoken word being read at the overlay's [param cursor] (its eased word position) and how
## far through it: `{si, frac}`, or empty before anything has been matched.
func reading(cursor: float) -> Dictionary:
	if map.is_empty():
		return {}
	var i := clampi(int(floor(cursor)), 0, map.size() - 1)
	var k := i
	while k > 0 and int(map[k]) < 0:
		k -= 1
	var si := int(map[k])
	if si < 0:
		return {}
	return {"si": si, "frac": clampf(cursor - float(i), 0.0, 1.0) if k == i else 1.0}


## THE SCHEDULE. Place every group of actions in the gap the voice left for it: `actions` are
## `{after, dur, ...}` (anchored after spoken word `after`, in order), and the result is
## `[{a, t0, s}]` - each action, when it starts, and the speed it is performed at (1, or less
## than 1 when the gap is short). A group runs at its own pace and FINISHES [param tail] before
## the next word, so any slack is spent before it starts: the hand rests, then acts, then the
## voice goes on. A gap shorter than the group squeezes it rather than talking over it. A group
## whose words have not arrived yet is left for a later call. [param opening] is when a group
## before the first word may begin.
func place(actions: Array, opening: float, lead: float, tail: float) -> Array:
	var out: Array = []
	var n_s := st0.size()
	var known := known_last()
	var i := 0
	while i < actions.size():
		var n := int((actions[i] as Dictionary)["after"])
		var group: Array = []
		while i < actions.size() and int((actions[i] as Dictionary)["after"]) == n:
			group.append(actions[i])
			i += 1
		if n > 0 and known < 0 or n - 1 > known:
			break
		var prev := START_PAST if start_si > 0 else opening - lead
		for k in range(mini(n - 1, n_s - 1), -1, -1):
			if st1[k] != NO_TIME:
				prev = st1[k]
				break
		var next := INF
		for k in range(n, n_s):
			if st0[k] != NO_TIME:
				next = st0[k]
				break
		var total := 0.0
		for a in group:
			total += float((a as Dictionary)["dur"])
		var start := prev + lead
		var s := 1.0
		if next < INF:
			var room := next - tail - start
			if room >= total:
				start = next - tail - total
			else:
				s = maxf(room, total * 0.25) / total
		var t := start
		for a in group:
			out.append({"a": a, "t0": t, "s": s})
			t += float((a as Dictionary)["dur"]) * s
	return out
