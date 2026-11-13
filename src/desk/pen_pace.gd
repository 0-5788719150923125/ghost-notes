extends RefCounted
class_name PenPace

## PenPace - when a pen writing by itself draws what the voice says (an episode at the desk, [EpisodeDesk]; next/desk.md),
## pure: one write's ink against its voice's words, in three steps.
##
## 1. WHAT GOES WITH WHICH WORDS ([method align]): the write's labels - a drawing's `<text>`, a line's words, a formula's
##    digits, letters and signs - matched to the words that say them all at once, in order: of every order-keeping match,
##    the one worth most, a label's words said whole worth most, a digit or a letter least, and a later match costing a little
##    more than an earlier one (a drawing is said as it is drawn: the first mention after the last is the one). The map it
##    gives runs from how many of the write's words are said to how much of its ink is drawn: each part - from a matched label to the next, what comes before the first from the write's first word -
##    drawn from its word over as many words as an easy pace takes ([constant PACE_EASY], at [constant WORD_GUESS] a word),
##    and none more, so a part said quickly is not stretched over the talk that follows it.
## 2. WHEN ([method path]): on that map, the pen keeps at least [constant AHEAD_LEAST] and at most [constant AHEAD_MOST]
##    words ahead of the voice, taking the evenest way the band allows ([method taut]), never quicker than [constant
##    PACE_MOST] its hand's pace (a line of words [constant PACE_MOST_WORDS], read along as it is written): where the band asks
##    more, it falls behind and catches up as it can. It never crawls: where the evenest way is slower than [constant
##    PACE_LEAST], it draws at that pace and then waits. Words not heard yet lead it nowhere, and a way made again as more
##    come goes on from where the pen is.
## 3. WHAT GIVES ([method rests]): where the pen would still be more than [constant LAG_OK] behind a word as it is said, the
##    voice rests for it at the end of the sentence before - never inside a sentence, never longer than [constant REST_MOST]
##    with a silence written there, and never longer than the pen can use. What no rest helps is let trail: a write with more
##    ink than its words carry is the writer's to shorten.
##
## [method audit] measures a pen against its voice: how far behind and ahead of the words it gets, its pace, how often the
## pace jumps, and how long it crawls.

## The band (words): the pen at least this far and at most this far ahead of the voice on the map.
const AHEAD_LEAST := 0.0
const AHEAD_MOST := 3.0
## The pen's quickest, against its hand's own pace ([method Ink.schedule]'s): a drawing's, a line of words', and the slowest
## it draws at while it draws; and the easy pace a part is given words for on the map, at a voice of this many seconds a word.
const PACE_MOST := 3.0
const PACE_MOST_WORDS := 4.0
const PACE_LEAST := 0.6
const PACE_EASY := 1.5
const WORD_GUESS := 0.45
## The way's grid (seconds).
const STEP := 0.05
## Behind a word as it is said by more than this (seconds), the voice rests for the pen at the sentence end before, at most
## this long there ([method rests]).
const LAG_OK := 0.8
const REST_MOST := 2.5
## Matching ([method align]): each word of a label said whole worth this (a short label - a digit, a letter, [method
## short] - this); the first two words of a longer label; the first word of a label of words; and the cost of a match at
## the write's last word (an earlier one less, by how far through its words it is).
const WORTH_WORD := 2.0
const WORTH_SHORT := 0.5
const WORTH_TWO := 1.5
const WORTH_FIRST := 0.8
const LATE_COST := 0.3
## A formula's signs by their glyphs' names, as a label says them ([method label_words]).
const SIGNS := {"plus": "+", "equal": "=", "minus": "−", "multiply": "×"}


# --- what goes with which words ---------------------------------------------------------------

## The map from how many of a write's [param words] are said (normalized, [method TabletScript.norm]) to how much of its ink
## is drawn (0 to 1): its [param labels], each its ink beginning at [param starts] (in order), matched to the words all at
## once ([method matches]); each part drawn from its word over the words its share of [param ink] (seconds at the hand's
## pace) takes at [constant PACE_EASY] - none more than to the next part's word - and then held; from `(0, 0)` to `(words,
## 1)`. Never falling. With no [param ink], straight between the matches.
static func align(labels: PackedStringArray, starts: PackedFloat32Array, words: PackedStringArray, ink := 0.0) -> PackedVector2Array:
	var n := float(words.size())
	var parts := PackedVector2Array([Vector2.ZERO])
	for h in matches(labels, starts, words):
		var at := Vector2(float(h[1]), float(starts[int(h[0])]))
		if at.x == 0.0 and parts.size() == 1:
			parts[0] = at
		elif at.x > parts[parts.size() - 1].x and at.y >= parts[parts.size() - 1].y:
			parts.append(at)
	var out := PackedVector2Array()
	for j in parts.size():
		var here := parts[j]
		var next := parts[j + 1] if j + 1 < parts.size() else Vector2(n, 1.0)
		out.append(here)
		if ink > 0.0:
			var takes := (next.y - here.y) * ink / (PACE_EASY * WORD_GUESS)
			if takes < next.x - here.x - 0.25:
				out.append(Vector2(here.x + maxf(takes, 0.25), next.y))
	if out[out.size() - 1].x < n:
		out.append(Vector2(n, 1.0))
	elif out[out.size() - 1].y < 1.0:
		out[out.size() - 1] = Vector2(n, 1.0)
	return out


## The labels matched to the words, in order: `[label, word]` each - of every order-keeping way to match them, the one worth
## most ([constant WORTH_WORD]...), a match costing [constant LATE_COST] for how far through the words it is. Empty where the
## labels and their starts do not agree.
static func matches(labels: PackedStringArray, starts: PackedFloat32Array, words: PackedStringArray) -> Array:
	var n := words.size()
	var m := labels.size()
	if m == 0 or n == 0 or starts.size() != m:
		return []
	var none := PackedFloat32Array()
	none.resize(n + 1)
	var table: Array = [none]                           # best worth with the labels before j, their words all before e
	var came: Array = []                                # for table[j + 1][e]: the word label j is matched at, -1 none
	for j in m:
		var said := label_words(labels[j])
		var little := short(labels[j])
		var was: PackedFloat32Array = table[j]
		var ends := PackedFloat32Array()
		ends.resize(n + 1)
		ends.fill(-1.0e9)
		var from := PackedInt32Array()
		from.resize(n + 1)
		from.fill(-1)
		for p in n:
			var hit := _match(said, little, words, p)
			if hit.x <= 0.0 or p + int(hit.y) > n:
				continue
			var worth := was[p] + hit.x - LATE_COST * float(p) / float(n)
			if worth > ends[p + int(hit.y)]:
				ends[p + int(hit.y)] = worth
				from[p + int(hit.y)] = p
		var now := PackedFloat32Array()
		now.resize(n + 1)
		var back := PackedInt32Array()
		back.resize(n + 1)
		var best := -1.0e9
		var best_at := -1
		for e in n + 1:
			if ends[e] > best:
				best = ends[e]
				best_at = from[e]
			if best > was[e] + 1e-6:
				now[e] = best
				back[e] = best_at
			else:
				now[e] = was[e]
				back[e] = -1
		table.append(now)
		came.append(back)
	var out: Array = []
	var e := n
	for j in range(m - 1, -1, -1):
		var p: int = (came[j] as PackedInt32Array)[e]
		if p >= 0:
			out.append([j, p])
			e = p
	out.reverse()
	return out


## What label words [param said] (short: [param little]) are worth matched at word [param p] of [param words], and how many
## words they take: `Vector2(worth, words)`, zero where they do not match there.
static func _match(said: PackedStringArray, little: bool, words: PackedStringArray, p: int) -> Vector2:
	if said.is_empty():
		return Vector2.ZERO
	if _says(words, p, said):
		return Vector2((WORTH_SHORT if little and said.size() == 1 else WORTH_WORD) * float(said.size()), float(said.size()))
	if said.size() > 2 and _says(words, p, said.slice(0, 2)):
		return Vector2(WORTH_TWO, 2.0)
	if said.size() > 1 and words[p] == said[0]:
		return Vector2(WORTH_FIRST, 1.0)
	return Vector2.ZERO


static func _says(words: PackedStringArray, p: int, said: PackedStringArray) -> bool:
	if p + said.size() > words.size():
		return false
	for q in said.size():
		if words[p + q] != said[q]:
			return false
	return true


## The words a label is said in, each as the reading has a spoken word ([method TabletScript.norm]): its TeX's commands and
## marks out, a sign as its word, numbers in words ([method TextNorm.normalize]).
static func label_words(tex: String) -> PackedStringArray:
	var s := RegEx.create_from_string("\\\\[A-Za-z]+").sub(tex, " ", true)
	for pair in [["=", " equals "], ["+", " plus "], ["×", " times "], ["−", " minus "]]:
		s = s.replace(String(pair[0]), String(pair[1]))
	for ch in ["$", "_", "^", "{", "}"]:
		s = s.replace(ch, " ")
	var out := PackedStringArray()
	for w in TextNorm.normalize(s).split(" ", false):
		var n := TabletScript.norm(w)
		if not n.is_empty():
			out.append(n)
	return out


## Is [param label] short - a number or a single letter or mark, once TeX's marks are out - and so said in many places it does
## not name?
static func short(label: String) -> bool:
	var bare := RegEx.create_from_string("[^A-Za-z0-9]").sub(RegEx.create_from_string("\\\\[A-Za-z]+").sub(label, "", true), "", true)
	return bare.length() <= 1 or bare.is_valid_int()


## How much of the ink the map [param map] has drawn when [param said] words are said: straight between its points, 0
## before them and 1 after.
static func on_map(map: PackedVector2Array, said: float) -> float:
	if map.is_empty():
		return 0.0
	if said <= map[0].x:
		return map[0].y if said >= map[0].x else 0.0
	for k in range(1, map.size()):
		if said <= map[k].x:
			return lerpf(map[k - 1].y, map[k].y, (said - map[k - 1].x) / maxf(map[k].x - map[k - 1].x, 1e-6))
	return 1.0


## How many words the map [param map] has said when [param drawn] of the ink is drawn: the fewest.
static func words_for(map: PackedVector2Array, drawn: float) -> float:
	for k in range(1, map.size()):
		if drawn <= map[k].y + 1e-6:
			if map[k].y - map[k - 1].y < 1e-6:
				return map[k - 1].x
			return lerpf(map[k - 1].x, map[k].x, clampf((drawn - map[k - 1].y) / (map[k].y - map[k - 1].y), 0.0, 1.0))
	return map[map.size() - 1].x


# --- when ------------------------------------------------------------------------------------

## The pen's way through one write, from [param start] (the soonest it may begin, [param drawn] of it drawn by then - a way
## made again goes on from where the pen is): how far through its ink it is every [constant STEP] seconds (`grid`, from `t0`),
## and when it is done (`done`; where words are not heard yet, when it has done all they allow, `whole` false). [param map] is
## [method align]'s; [param said] each of the write's own words' times (`Vector2(begins, ends)`, INF not heard yet); [param
## before] when each word before the write's first begins, nearest first; [param ink] the write's seconds at its hand's
## pace, and [param most] the quickest it is drawn at against that.
static func path(map: PackedVector2Array, said: Array, before: PackedFloat32Array, ink: float, start: float, drawn := 0.0,
		most := PACE_MOST) -> Dictionary:
	var n := said.size()
	var known := 0
	while known < n and (said[known] as Vector2).y < INF:
		known += 1
	var whole := known == n
	var cap := float(n) if whole else float(known)
	var lows := PackedVector2Array()
	var highs := PackedVector2Array()
	# ...begun as early as [constant AHEAD_MOST] words before its first, the pen free
	for b in range(before.size() - 1, -1, -1):
		if before[b] < INF:
			highs.append(Vector2(before[b], on_map(map, minf(AHEAD_MOST - float(b + 1), cap))))
	var last := Vector2(start, 0.0)
	for k in known:
		var w: Vector2 = said[k]
		for side in 2:
			var t := w.x if side == 0 else w.y
			var at := float(k + side)
			var low := Vector2(t, on_map(map, minf(at + AHEAD_LEAST, cap)))
			lows.append(low)
			highs.append(Vector2(t, on_map(map, minf(at + AHEAD_MOST, cap))))
			if whole and low.y >= 1.0 - 1e-6 and last.y < 1.0:
				last = low
	if last.y < 1.0 and not lows.is_empty():
		last = lows[lows.size() - 1]
	var goal := maxf(last.y, drawn)
	var knots := taut(Vector2(start, drawn), lows, highs, Vector2(last.x, goal)) if last.x > start \
		else PackedVector2Array([Vector2(start, drawn)])
	var step := most / maxf(ink, 0.01) * STEP
	var least := PACE_LEAST / maxf(ink, 0.01) * STEP
	# ...from exactly where the pen is (its knots are single floats: a time read a hair past the first would be a step on)
	var grid := PackedFloat32Array([drawn])
	var t := start
	var p := drawn
	while grid.size() < 400000 and not (t >= last.x and p >= goal - 1e-5):
		t += STEP
		p = clampf(_on(knots, t, goal), p, p + step)
		grid.append(p)
	# ...never a crawl: where it would draw slower than PACE_LEAST, it draws at that and then waits - no further ahead than
	# the band lets it be, and never behind where it was
	var k := 1
	while k < grid.size():
		if grid[k] - grid[k - 1] <= 1e-7 or grid[k] - grid[k - 1] >= least:
			k += 1
			continue
		var a := k - 1
		var b := k
		while b < grid.size() and grid[b] - grid[b - 1] > 1e-7 and grid[b] - grid[b - 1] < least:
			b += 1
		var top := grid[b - 1]
		var q := grid[a]
		for j in range(a + 1, b):
			q = minf(minf(q + least, top), maxf(_band(highs, start + float(j) * STEP), grid[j]))
			grid[j] = maxf(q, grid[j])
		k = b
	return {"t0": start, "grid": grid, "done": start + float(grid.size() - 1) * STEP, "whole": whole}


## The most the band lets the pen have drawn at [param t]: the ceilings [param highs] straight between them, no bound before
## the first or after the last.
static func _band(highs: PackedVector2Array, t: float) -> float:
	var sorted := highs
	if sorted.is_empty() or t < sorted[0].x:
		return INF
	for k in range(1, sorted.size()):
		if t <= sorted[k].x:
			return lerpf(sorted[k - 1].y, sorted[k].y, (t - sorted[k - 1].x) / maxf(sorted[k].x - sorted[k - 1].x, 1e-6))
	return INF


## How far through the way [param way] ([method path]'s) the pen is at [param t] - before it, where it starts.
static func at(way: Dictionary, t: float) -> float:
	var grid: PackedFloat32Array = way.get("grid", PackedFloat32Array())
	if grid.is_empty():
		return 0.0
	var x := (t - float(way["t0"])) / STEP
	if x <= 0.0:
		return grid[0]
	var k := floori(x)
	if k + 1 >= grid.size():
		return grid[grid.size() - 1]
	return lerpf(grid[k], grid[k + 1], x - float(k))


## When the way [param way] has drawn [param drawn] of the ink: INF where it never does.
static func reach(way: Dictionary, drawn: float) -> float:
	var grid: PackedFloat32Array = way.get("grid", PackedFloat32Array())
	for k in grid.size():
		if grid[k] >= drawn - 1e-5:
			return float(way["t0"]) + float(k) * STEP
	return INF


static func _on(knots: PackedVector2Array, t: float, goal: float) -> float:
	if t <= knots[0].x:
		return knots[0].y
	for k in range(1, knots.size()):
		if t < knots[k].x:
			return lerpf(knots[k - 1].y, knots[k].y, (t - knots[k - 1].x) / maxf(knots[k].x - knots[k - 1].x, 1e-6))
	return maxf(knots[knots.size() - 1].y, goal)


## The evenest way through a corridor: from [param from] (`Vector2(time, share)`) to [param last], a line bent only where it
## must be to stay at or above each of [param lows] and at or below each of [param highs] - a string pulled taut between
## them, so its pace changes as seldom and as little as they allow. Its knots, in time order; never falling.
static func taut(from: Vector2, lows: PackedVector2Array, highs: PackedVector2Array, last: Vector2) -> PackedVector2Array:
	var ev: Array = []                       # [time, at least, at most], in time order
	for p in lows:
		if p.x > from.x and p.x < last.x:
			ev.append([p.x, p.y, INF])
	for p in highs:
		if p.x > from.x and p.x < last.x:
			ev.append([p.x, -INF, p.y])
	ev.sort_custom(func(x: Array, y: Array) -> bool: return float(x[0]) < float(y[0]))
	ev.append([last.x, last.y, last.y])
	var out := PackedVector2Array([from])
	var cur := from
	var i := 0
	while i < ev.size():
		var lo := 0.0
		var lo_k := -1
		var hi := INF
		var hi_k := -1
		var bent := false
		for j in range(i, ev.size()):
			var dt := float(ev[j][0]) - cur.x
			if dt <= 1e-6:
				continue
			var s_lo := (float(ev[j][1]) - cur.y) / dt
			var s_hi := maxf((float(ev[j][2]) - cur.y) / dt, 0.0)
			if s_lo > hi:
				# ...steeper than an earlier ceiling lets it be: along to that ceiling, and bent up there
				cur = Vector2(float(ev[hi_k][0]), cur.y + hi * (float(ev[hi_k][0]) - cur.x))
				i = hi_k + 1
				bent = true
				break
			if s_hi < lo:
				# ...shallower than an earlier floor needs: up to that floor, and bent down there
				cur = Vector2(float(ev[lo_k][0]), cur.y + lo * (float(ev[lo_k][0]) - cur.x))
				i = lo_k + 1
				bent = true
				break
			if s_lo >= lo:
				lo = s_lo
				lo_k = j
			if s_hi < hi:
				hi = s_hi
				hi_k = j
		if not bent:
			break
		out.append(cur)
	if out[out.size() - 1].x < last.x:
		out.append(last)
	return out


# --- what gives ------------------------------------------------------------------------------

## The rests the voice takes for a show's pens, word -> seconds after it: each write ([param writes]: `{map, own (its own
## words' indices among the spoken), ink, after, most}`, in the order they are written) planned on the words at [param word]
## seconds apart, the voice's pause after a stop [param pause], its silences [param quiet] (word -> seconds before it) and
## the rests given so far; where the pen would be more than [constant LAG_OK] behind a word as it is said, a rest at the last
## sentence end before it ([param ends], word -> whether it ends a sentence), as long as it lacks and at most [constant
## REST_MOST] there with a silence already written there, and the write planned again. A rest is only as long as the pen
## uses: in a pause it draws no further than its lead ([constant AHEAD_MOST]), so a rest past that is cut back to what helped
## and that stop given no more. A word no rest before it can help is let trail, and the words after it are looked at still.
static func rests(writes: Array, spoken_n: int, ends: Array, quiet: Dictionary, word: float, pause: float) -> Dictionary:
	var given := {}
	var free := -INF
	for w in writes:
		var own: PackedInt32Array = (w as Dictionary)["own"]
		if own.is_empty():
			continue
		var floor_word := maxi(int(w["after"]) - int(AHEAD_MOST), 0)
		var spent := {}                 # stops whose rest the pen cannot use more of
		var from := 0                   # the first of its words still looked at: one no rest can help is let trail
		var planned := _planned(w, spoken_n, ends, quiet, given, word, pause, floor_word, free)
		for _try in 400:
			var worst := _late_word(w, planned, from)
			if worst < 0:
				break
			var lag := _late(w, planned, worst)
			var stop := -1
			for g in range(own[worst] - 1, -1, -1):
				if g < own[0] - int(AHEAD_MOST) * 3:
					break
				if bool(ends[g]) and not spent.has(g) and float(given.get(g, 0.0)) + float(quiet.get(g + 1, 0.0)) < REST_MOST - 0.05:
					stop = g
					break
			if stop < 0:
				from = worst + 1
				continue
			var had := float(given.get(stop, 0.0))
			given[stop] = minf(had + lag, REST_MOST - float(quiet.get(stop + 1, 0.0)))
			planned = _planned(w, spoken_n, ends, quiet, given, word, pause, floor_word, free)
			var helped := lag - _late(w, planned, worst)
			if helped < float(given[stop]) - had - 0.05:
				given[stop] = had + maxf(helped, 0.0)
				spent[stop] = true
				planned = _planned(w, spoken_n, ends, quiet, given, word, pause, floor_word, free)
		free = float((planned[0] as Dictionary).get("done", free)) + 0.4
	return given


## Write [param w]'s way as [method rests] plans it, on the voice's times with the rests [param given] so far: `[way, said]`.
static func _planned(w: Dictionary, spoken_n: int, ends: Array, quiet: Dictionary, given: Dictionary, word: float, pause: float,
		floor_word: int, free: float) -> Array:
	var own: PackedInt32Array = w["own"]
	var times := _times(spoken_n, ends, quiet, given, word, pause)
	var said: Array = []
	for k in own:
		said.append(Vector2(times[k], times[k] + word * 0.9))
	var before := PackedFloat32Array()
	for b in int(AHEAD_MOST):
		var g := own[0] - 1 - b
		before.append(times[g] if g >= 0 else INF)
	return [path(w["map"], said, before, float(w["ink"]), maxf(times[floor_word], free), 0.0, float(w.get("most", PACE_MOST))), said]


## How long after write [param w]'s own word [param k] is said its pen has drawn what goes with it, on [param planned]
## ([method _planned]).
static func _late(w: Dictionary, planned: Array, k: int) -> float:
	return reach(planned[0], on_map(w["map"], float(k + 1))) - ((planned[1] as Array)[k] as Vector2).y


## The first of write [param w]'s own words from [param from] its pen is more than [constant LAG_OK] behind, -1 for none.
static func _late_word(w: Dictionary, planned: Array, from: int) -> int:
	for k in range(from, (w["own"] as PackedInt32Array).size()):
		if _late(w, planned, k) > LAG_OK:
			return k
	return -1


## When each spoken word begins, the words [param word] seconds apart, a pause of [param pause] after each that ends a
## sentence ([param ends]), and the silences [param quiet] and rests [param given] in front of the words they come before.
static func _times(n: int, ends: Array, quiet: Dictionary, given: Dictionary, word: float, pause: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(n)
	var t := 0.0
	for k in n:
		t += float(quiet.get(k, 0.0))
		out[k] = t
		t += word + (pause if k < ends.size() and bool(ends[k]) else 0.0) + float(given.get(k, 0.0))
	return out


# --- the audit ---------------------------------------------------------------------------------

## A pen against its voice, from how far through the write it is at times [param times] ([param drawn], each) and the
## write's own words' times [param said] on its map [param map]: `behind` - the most it is behind a word as it is said (the
## time from the word's end to its ink drawn; below 0, ahead throughout); `ahead` - the most words its ink is ahead of the
## voice; `pace` and `fastest` - its usual and quickest pace while it draws, against its hand's ([param ink] seconds);
## `jumps` - how often its pace more than doubles or halves from one half second to the next while it draws; `crawl` - the
## seconds it draws at under a third of its hand's pace. A stop - a lift between parts - is no jump; a jump is its pace more
## than doubling or halving while it goes on drawing.
static func audit(map: PackedVector2Array, said: Array, times: PackedFloat32Array, drawn: PackedFloat32Array, ink: float) -> Dictionary:
	var behind := -INF
	for k in said.size():
		var w: Vector2 = said[k]
		if w.y == INF:
			continue
		var want := on_map(map, float(k + 1))
		var got := INF
		for s in times.size():
			if drawn[s] >= want - 1e-4:
				got = times[s]
				break
		behind = maxf(behind, got - w.y)
	var ahead := 0.0
	var paces := PackedFloat32Array()
	var crawl := 0.0
	var fastest_at := 0.0
	var fastest := 0.0
	for s in times.size():
		var heard := 0.0
		for k in said.size():
			var w: Vector2 = said[k]
			if w.x >= times[s]:
				break
			heard = float(k) + clampf((times[s] - w.x) / maxf(w.y - w.x, 0.01), 0.0, 1.0)
		ahead = maxf(ahead, words_for(map, drawn[s]) - heard)
		if s > 0:
			var v := (drawn[s] - drawn[s - 1]) * ink / maxf(times[s] - times[s - 1], 1e-4)
			paces.append(v)
			if v > fastest:
				fastest = v
				fastest_at = times[s]
			if v > 0.02 and v < 1.0 / 3.0:
				crawl += times[s] - times[s - 1]
	# ...over half seconds, while it draws
	var halves := PackedFloat32Array()
	var dt := (times[times.size() - 1] - times[0]) / maxf(float(times.size() - 1), 1.0) if times.size() > 1 else 0.1
	var per := maxi(roundi(0.5 / maxf(dt, 0.01)), 1)
	for s in range(0, paces.size() - per + 1, per):
		var sum := 0.0
		for q in per:
			sum += paces[s + q]
		halves.append(sum / float(per))
	var jumps := 0
	for h in range(1, halves.size()):
		var a := halves[h - 1]
		var b := halves[h]
		if minf(a, b) > 0.15 and maxf(a, b) > 2.0 * minf(a, b):
			jumps += 1
	var moving := PackedFloat32Array()
	for v in paces:
		if v > 0.02:
			moving.append(v)
	moving.sort()
	return {"behind": behind, "ahead": ahead, "pace": moving[moving.size() / 2] if not moving.is_empty() else 0.0,
		"fastest": moving[moving.size() - 1] if not moving.is_empty() else 0.0, "fastest_at": fastest_at, "jumps": jumps,
		"crawl": crawl}
