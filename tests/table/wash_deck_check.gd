extends Node

## THE WASH WASHES THE DECK ([TableShuffle], [method TablePlan.deck_count]). The user, 2026-10-14:
## in a wash "the cards NOT being moved are still slowly drifting/sliding away from each other... the
## cards just slide along the table, gently, as if on ice... Cards should settle, when they are not
## being moved by the washing directly (or pushed by other cards...)"; and "when the cards are
## collected - the deck is slowly growing in a strange way. It is as if the number of cards on the
## table/in the wash does not match the number of cards needed in the deck when stacked"; and, of the
## fix, "The agents define how many cards a deck will use, so be sure to use the actual card amount".
## So, over washes of the real plan:
##
##   - THE DECK IS THE EPISODE'S: as many cards as the draw's deck held (`deck_n`), else the deck the
##     producer chose, else a box's drawn and left-in cards - never fewer than the cards drawn, and a
##     made-up episode a tarot's; the deck stands that many cards high, and a wash spreads every one;
##   - A CARD IS ONE CARD'S HEIGHT wherever it lies: the deck keeps its height as the palm comes down
##     on it, and the gathered pile stands as high as the cards landed in it, card by card, to the
##     deck's height;
##   - A CARD SWEPT IN GOES UNDER THE PILE (the same day: "a person swiping-in cards to collect them
##     from the table wash would be sweeping them into the bottom of the deck" - they had all gone on
##     top): of two cards gathered in different sweeps, the later lies lower in the deck gathered;
##   - CARDS LEFT ALONE LIE STILL: a card no palm is near and no moving card touches, once any slide it
##     had has run out, does not move;
##   - A HEAP IS NO TALLER THAN ITS CARDS: no card in a wash stands far over the deck's own height;
##   - A HEAP STAYS LOW AS IT IS MIXED (2026-10-15: cards "floating a half inch or an inch above the
##     table, because they are 'stacked' upon dozens of other cards... those stacks would topple and
##     the cards would splay further"): no card lies 10 mm over the cloth, and 99 in 100 under 6 mm -
##     while a card is not left alone as it topples off a heap ([constant TableShuffle.SPLAY_DEPTH]).
##
## THE CONTROLS: the gather laying each card on top ([member TableShuffle._sweep_under] off) is caught
## going the other way; a track made to creep as the heap's slump made it (12 mm/s) is caught; the pile posed
## as the old deck's (26 meshes standing for three cards each, every one swelling as it landed) stands
## off its cards' height; cards rested without the cards on them holding them down tower over the
## cloth ([member TableShuffle._hold]); the wash as it was - no card splaying ([member TableShuffle._splay])
## and a big deck spread no wider ([member TableShuffle._roomy]) - lies on heaps 15 mm and more tall.
##
##   tests/run_boot_probe.sh tests/table/wash_deck_check.gd 1200
##
## A BOOT probe (the medium reaches the Director); no GPU - the tracks and rests are numbers.

const SEEDS := [21, 22, 23]
const WASH_S := 28.0
## A palm presses cards whose middle is this near its own (meters: half its length and a card's
## half-diagonal, with room).
const PALM_REACH := 0.17
## Steps a card must be left alone before a slide counts: any it had has run out by then.
const COAST := 8
## A step (meters, 1/20 s) longer than this is a slide.
const STILL := 0.00005
## How far over the deck's own height a card in a wash may stand (meters: a card tipped off the top of
## a heap).
const TOWER := 0.012
## The highest a card may lie over the cloth as a wash is mixed (meters) - and 99 in 100 under 0.6 of
## that: a heap is a few cards thick where it is thickest.
const MIXED_MOST := 0.01

var _fails := 0
var medium: TableMedium
var subs: Subtitles


func _ready() -> void:
	_run.call_deferred()


func _ok(cond: bool, what: String) -> void:
	print(("  ok    " if cond else "  FAIL  ") + what)
	if not cond:
		_fails += 1


func _run() -> void:
	var stage := SubViewport.new()
	stage.size = Vector2i(640, 360)
	stage.own_world_3d = true
	add_child(stage)
	Director.detach()
	medium = Medium.make("table") as TableMedium
	medium.mount(stage)
	Director.attach(stage, medium)
	Director.hold(true)
	subs = preload("res://src/show/subtitles.gd").new()
	add_child(subs)
	medium.bind_captions(subs)
	_counts()
	_episode({}, 5)
	var plans: Array = []
	for sd: int in SEEDS:
		plans.append(medium._shuffles._wash_plan(600 + sd, WASH_S))
	_heights(plans)
	_swept(plans)
	_still(plans)
	_heaps(plans)
	Director.hold(false)
	Director.detach()
	print("wash_deck_check: %s" % ("ALL OK" if _fails == 0 else "%d FAILED" % _fails))
	get_tree().quit(0 if _fails == 0 else 1)


## Episode [param seed] - three cards drawn, its table [param more] laid over a plain one - loaded (an
## episode is built again only when its seed, folder or script change).
func _episode(more: Dictionary, seed: int) -> void:
	var cards: Array = []
	for k in 3:
		cards.append({"key": "c%d" % k, "name": "Card %d" % k, "numeral": str(k), "reversed": false, "jumper": false,
			"position": {}, "booklet": {}, "art": ""})
	var table := {"show": "wash-deck-check", "seed": seed, "dir": "", "plan": {"look": {"candles": 2}}, "cards": cards}
	table.merge(more, true)
	subs.document = {"source": CardReading.compose([{"kind": "shuffle", "card": 0, "text": "Shuffle."}]),
		"title": "Wash Deck Check", "table": table}
	medium._ensure_doc()
	medium._shuffles.shuffle_room = INF


## THE DECK IS THE EPISODE'S: its count, its meshes, its height and a wash's cards.
func _counts() -> void:
	var listed: Array = []
	for k in 40:
		listed.append({"key": "d%d" % k, "name": "Deck Card %d" % k})
	var left: Array = []
	for k in 30:
		left.append({"key": "l%d" % k, "name": "Left Card %d" % k})
	var cases: Array = [
		["the draw's own count", {"deck_n": 22}, 22],
		["the deck the producer chose", {"plan": {"look": {"candles": 2}, "deck": listed}}, 40],
		["a box's drawn and left-in cards", {"left": left}, 33],
		["never fewer than the cards drawn", {"deck_n": 1}, 3],
		["a made-up episode's", {}, TableMedium.DECK_FALLBACK],
	]
	for k in cases.size():
		var c: Array = cases[k]
		_episode(c[1], 101 + k)
		var want := int(c[2])
		var top := medium._rest_xf(medium._plan.deck_n - 1).origin.y - medium._cur_base.y + TableMedium.DECK_T * 0.5
		_ok(medium._plan.deck_n == want and medium._deck.size() == want and absf(top - float(want) * TableMedium.DECK_T) < 1e-6,
			"the deck is %s: %d cards, %d meshes, %.1f mm high (want %d)" % [c[0], medium._plan.deck_n, medium._deck.size(), top * 1000.0, want])
	_episode({"deck_n": 22}, 120)
	var plan: Dictionary = medium._shuffles._wash_plan(9, 12.0)
	_ok((plan["tracks"] as Array).size() == 22, "a wash of a deck of 22 spreads all 22 (%d)" % (plan["tracks"] as Array).size())
	_ok(is_equal_approx(TableShuffle.WASH_LAYER, TableMedium.DECK_T), "a card spread on the cloth stands as high as one in the deck (%.2f mm, %.2f mm)"
		% [TableShuffle.WASH_LAYER * 1000.0, TableMedium.DECK_T * 1000.0])


## How high the cards stand at the deck's middle (meters over the table's top, as the deck stands) when [param v] seconds
## into wash [param m], how many cards cover it - all of them, and those landed in the pile - and how
## many not landed lie anywhere in the pile's place: `[height, covering, landed, strays]`.
func _stack(m: Dictionary, v: float) -> Array:
	var plan: Dictionary = m["plan"]
	var ins: PackedFloat32Array = plan["in"]
	var top := 0.0
	var cover := 0
	var landed := 0
	var strays := 0
	for i in (plan["tracks"] as Array).size():
		var xf: Transform3D = medium._shuffles.wash(i, v, m)
		var b := xf.basis
		var o := xf.origin - medium._cur_base
		var d := Vector2(-o.x, -o.z)
		if v < ins[i] and TableShuffle._cards_overlap(Vector2(o.x, o.z), TableShuffle._wash_at(plan, i, v).w, Vector2.ZERO, 0.0):
			strays += 1
		if absf(d.dot(Vector2(b.x.x, b.x.z).normalized())) > TableMedium.CARD.x * 0.5 \
				or absf(d.dot(Vector2(b.z.x, b.z.z).normalized())) > TableMedium.CARD.y * 0.5:
			continue
		cover += 1
		landed += 1 if v >= ins[i] else 0
		var up := b.y.normalized()
		var face := o + up * (b.y.length() * TableMedium.DECK_T * 0.5)
		top = maxf(top, face.y + (up.x * face.x + up.z * face.z) / up.y)
	return [top, cover, landed, strays]


## A CARD IS ONE CARD'S HEIGHT: the deck under the palm, and the pile as it is gathered - against the
## old deck's pile, every card swelling to three as it landed (the control).
func _heights(plans: Array) -> void:
	var drop := 0.0
	var off := 0.0
	var off_old := 0.0
	var judged := 0
	var lifted := 0.0
	var end_off := 0.0
	for p in plans:
		var plan: Dictionary = p
		var m := {"kind": "wash", "t0": 0.0, "dur": WASH_S, "pause": 1000.0, "seed": 0, "plan": plan}
		var n := (plan["tracks"] as Array).size()
		var ins: PackedFloat32Array = plan["in"]
		# the deck as the palm comes down on it, while every card still covers its middle
		var top0 := float(_stack(m, 0.0)[0])
		var v := 0.0
		while v <= TableShuffle.WASH_FLATTEN + 0.2:
			var st := _stack(m, v)
			if int(st[1]) == n:
				drop = maxf(drop, top0 - float(st[0]))
			v += 1.0 / 60.0
		# the pile as it is gathered: wherever only cards landed in it lie in its place, it stands as high
		# as those cards - as the old deck's did not (each of its cards swelling from a card and a hair
		# to three cards' height over 0.6 s from landing). Cards are swept in UNDER it, often a few lying
		# one on another together: its edge rides up on them a moment, and it lies tipped on the last of
		# them until they are squared in
		var k := 0
		var g0 := float(plan["gather"])
		while g0 + float(k) / 30.0 <= WASH_S:
			var t := g0 + float(k) / 30.0
			k += 1
			var st := _stack(m, t)
			if int(st[1]) != int(st[2]) or int(st[2]) < 3:
				continue
			var want := float(st[2]) * TableMedium.DECK_T
			lifted = maxf(lifted, float(st[0]) - want)
			if int(st[3]) > 0:
				continue
			var old := 0.0
			for i in n:
				if t >= ins[i]:
					old += lerpf(TableShuffle.WASH_LAYER, 3.0 * TableShuffle.WASH_LAYER, clampf((t - ins[i]) / 0.6, 0.0, 1.0))
			off = maxf(off, absf(float(st[0]) - want))
			off_old = maxf(off_old, absf(old - want))
			judged += 1
		end_off = maxf(end_off, absf(float(_stack(m, WASH_S)[0]) - float(n) * TableMedium.DECK_T))
	print("  the deck drops %.2f mm under the palm; the pile stands %.2f mm off its landed cards' height at most (%d frames; the old deck's %.1f mm), %.1f mm over with a card slid in under its edge; squared, %.2f mm off the deck's"
		% [drop * 1000.0, off * 1000.0, judged, off_old * 1000.0, lifted * 1000.0, end_off * 1000.0])
	_ok(drop < 0.0005, "the deck keeps its height as the palm comes down on it (%.2f mm lower)" % (drop * 1000.0))
	_ok(judged > 100 and off < 0.004, "the gathered pile stands as high as the cards landed in it, card by card - within a few cards, tipped on what was swept in under its edge (%.2f mm off at most)" % (off * 1000.0))
	_ok(lifted < 0.012, "cards swept in under its edge tip it up a moment by their own height (%.1f mm)" % (lifted * 1000.0))
	_ok(off_old > 0.005, "control: the old deck's pile, each card swelling to three as it landed, is not (%.1f mm off)" % (off_old * 1000.0))
	_ok(end_off < 0.0002, "gathered and squared, it stands the deck's own height (%.2f mm off)" % (end_off * 1000.0))


## Of every two cards [param plan] gathers in different sweeps, the share lying the way they were swept:
## the later under the earlier in the deck it squares.
func _under_share(plan: Dictionary) -> Vector2i:
	var order: Array = plan["order"]
	var ins: PackedFloat32Array = plan["in"]
	var at := {}
	for k in order.size():
		at[int(order[k])] = k
	var right := 0
	var pairs := 0
	for a: int in at:
		for b: int in at:
			if ins[a] < ins[b] and ins[b] < INF:
				pairs += 1
				right += 1 if int(at[b]) < int(at[a]) else 0
	return Vector2i(right, pairs)


## A CARD SWEPT IN GOES UNDER THE PILE - against the gather laying each on top (the control).
func _swept(plans: Array) -> void:
	var right := 0
	var pairs := 0
	for p in plans:
		var r := _under_share(p as Dictionary)
		right += r.x
		pairs += r.y
	medium._shuffles._sweep_under = false
	var c := _under_share(medium._shuffles._wash_plan(600 + int(SEEDS[0]), WASH_S))
	medium._shuffles._sweep_under = true
	var share := float(right) / maxf(float(pairs), 1.0)
	var share_c := float(c.x) / maxf(float(c.y), 1.0)
	print("  of %d pairs gathered in different sweeps, %.0f%% lie the later under the earlier (laid on top instead: %.0f%%)"
		% [pairs, share * 100.0, share_c * 100.0])
	_ok(pairs > 1000 and share > 0.85, "a card swept in goes under the pile: the later of two gathered lies lower (%.0f%%)" % (share * 100.0))
	_ok(share_c < 0.3, "control: laid on top instead, the later lies higher (%.0f%% lower)" % (share_c * 100.0))


## Every card-step of [param plan]'s mixing that its card was LEFT ALONE - no palm pressing near it,
## no card that moved touching it, for COAST steps - and how far it went: `[card, step, meters]`.
## [param tracks] are the plan's, or made ones.
func _alone(plan: Dictionary, tracks: Array) -> Array:
	var out: Array = []
	var n := tracks.size()
	var steps := (tracks[0] as PackedVector4Array).size()
	var mix: Vector2 = plan["mix"]
	var log: Array = plan["hands"]
	var alone := PackedInt32Array()
	alone.resize(n)
	for st in range(1, steps):
		var t := float(st) / TableShuffle.WASH_HZ
		if t < mix.x + 0.5 or t >= float(plan["gather"]):
			alone.fill(0)
			continue
		var palms: Array = []
		for e in log:
			var g: Dictionary = (e as Array)[1]
			for tt: float in [t - 1.0 / TableShuffle.WASH_HZ, t]:
				var a := TableShuffle._gesture_at(g, tt)
				if a.z > 0.0:
					palms.append(Vector2(a.x, a.y))
		var moved := PackedFloat32Array()
		moved.resize(n)
		for i in n:
			var q: Vector4 = (tracks[i] as PackedVector4Array)[st]
			var q0: Vector4 = (tracks[i] as PackedVector4Array)[st - 1]
			moved[i] = Vector2(q.x - q0.x, q.z - q0.z).length() + absf(wrapf(q.w - q0.w, -PI, PI)) * 0.06
		for i in n:
			var q: Vector4 = (tracks[i] as PackedVector4Array)[st]
			var mid := Vector2(q.x, q.z)
			var free := not TableShuffle._off_cloth(plan, i, t) and not TableShuffle._off_cloth(plan, i, t - 1.0 / TableShuffle.WASH_HZ)
			for p: Vector2 in palms:
				if free and p.distance_to(mid) < PALM_REACH:
					free = false
			for j in n:
				if not free:
					break
				if j == i or moved[j] <= STILL:
					continue
				var qj: Vector4 = (tracks[j] as PackedVector4Array)[st]
				var qj0: Vector4 = (tracks[j] as PackedVector4Array)[st - 1]
				if TableShuffle._cards_overlap(mid, q.w, Vector2(qj.x, qj.z), qj.w) or TableShuffle._cards_overlap(mid, q.w, Vector2(qj0.x, qj0.z), qj0.w):
					free = false
			# ...nor while its heap has lately risen past SPLAY_DEPTH under it: it topples
			if free and _perched(tracks[i] as PackedVector4Array, st):
				free = false
			alone[i] = alone[i] + 1 if free else 0
			if alone[i] > COAST:
				out.append([i, st, moved[i]])
	return out


## Whether the card [param track] is of has, at step [param st] or in the steps before it that a topple
## takes ([constant TableShuffle.SPLAY_WINDOW] and its slide to a stop), come to lie deeper than
## [constant TableShuffle.SPLAY_DEPTH] - its place in the order the cards lie is its height in the
## track (a card in the air lies over the whole deck, and is not on a heap).
func _perched(track: PackedVector4Array, st: int) -> bool:
	var back := int(ceil((TableShuffle.SPLAY_WINDOW + 0.3) * TableShuffle.WASH_HZ))
	var n := medium._plan.deck_n
	for k in range(maxi(st - back, 1), st + 1):
		var d := roundi((track[k].y - TableShuffle.WASH_FLOOR) / TableShuffle.WASH_LAYER)
		var d0 := roundi((track[k - 1].y - TableShuffle.WASH_FLOOR) / TableShuffle.WASH_LAYER)
		if d > TableShuffle.SPLAY_DEPTH and d > d0 and d <= n:
			return true
	return false


## CARDS LEFT ALONE LIE STILL - against a card made to creep as the heap's slump made it (the control).
func _still(plans: Array) -> void:
	var steps := 0
	var slid := 0
	var most := 0.0
	var control := 0
	for w in plans.size():
		var plan: Dictionary = plans[w]
		var seen := _alone(plan, plan["tracks"])
		steps += seen.size()
		for e: Array in seen:
			if float(e[2]) > STILL:
				slid += 1
				most = maxf(most, float(e[2]))
		if w == 0 and not seen.is_empty():
			# the control: the card left alone longest, its track made to creep off at 12 mm/s from there on
			var counts := {}
			for e: Array in seen:
				counts[int(e[0])] = int(counts.get(int(e[0]), 0)) + 1
			var c := int(counts.keys()[0])
			for key in counts:
				if int(counts[key]) > int(counts[c]):
					c = int(key)
			var made: Array = (plan["tracks"] as Array).duplicate()
			var tr: PackedVector4Array = (made[c] as PackedVector4Array).duplicate()
			var from := -1
			for e: Array in seen:
				if int(e[0]) == c:
					from = int(e[1])
					break
			for st in range(from, tr.size()):
				tr[st] += Vector4(0.012 / TableShuffle.WASH_HZ * float(st - from + 1), 0.0, 0.0, 0.0)
			made[c] = tr
			for e: Array in _alone(plan, made):
				if int(e[0]) == c and float(e[2]) > STILL:
					control += 1
	print("  %d card-steps left alone over %d washes: %d slid (the most %.2f mm in a step)" % [steps, plans.size(), slid, most * 1000.0])
	_ok(steps > 500, "the washes leave cards alone a while (%d card-steps)" % steps)
	_ok(slid == 0, "a card left alone lies still: no palm near and no moving card touching, it does not move (%d steps slid)" % slid)
	_ok(control > 10, "control: a card made to creep off as a slumping heap's did is caught (%d steps)" % control)


## A HEAP IS NO TALLER THAN ITS CARDS - and rested without the cards on them holding them down (the
## control), cards tower over the cloth. And A HEAP STAYS LOW AS IT IS MIXED: its cards splay - against
## the same wash with none splaying (the control), where cards stood on chains of cards 30 deep.
func _heaps(plans: Array) -> void:
	var tallest := 0.0
	var steepest := 0.0
	var n := 0
	var mixed := PackedFloat32Array()
	for p in plans:
		var plan: Dictionary = p
		n = (plan["tracks"] as Array).size()
		var last := ((plan["tracks"] as Array)[0] as PackedVector4Array).size() - 1
		for st in range(1, last, 6):
			for r: Vector3 in medium._shuffles._wash_rest(plan, st):
				tallest = maxf(tallest, r.x - TableMedium.CLOTH_TOP)
				steepest = maxf(steepest, Vector2(r.y, r.z).length())
		mixed.append_array(_mixed_heights(plan))
	var deck := float(n) * TableMedium.DECK_T
	medium._shuffles._hold = false
	medium._shuffles._rest_steps = {}
	medium._shuffles._rest_lifts = {}
	var towering := 0.0
	var plan0: Dictionary = plans[0]
	var last0 := ((plan0["tracks"] as Array)[0] as PackedVector4Array).size() - 1
	for st in range(1, last0, 6):
		for r: Vector3 in medium._shuffles._wash_rest(plan0, st):
			towering = maxf(towering, r.x - TableMedium.CLOTH_TOP)
	medium._shuffles._hold = true
	medium._shuffles._rest_steps = {}
	medium._shuffles._rest_lifts = {}
	print("  the deck stands %.1f mm; in its washes the tallest card's middle %.1f mm, the steepest tilt %.1f deg; not held down, %.0f mm"
		% [deck * 1000.0, tallest * 1000.0, rad_to_deg(atan(steepest)), towering * 1000.0])
	_ok(tallest < deck + TOWER, "no card in a wash stands far over the deck's own height (%.1f mm, the deck %.1f)" % [tallest * 1000.0, deck * 1000.0])
	_ok(towering > deck + 0.05, "control: rested without the cards on them holding them down, cards tower over it (%.0f mm)" % (towering * 1000.0))
	# AS IT IS MIXED: how high the cards lie over the cloth, against the wash as it was - no card
	# splaying, the deck spread no wider for being big
	medium._shuffles._splay = false
	medium._shuffles._roomy = false
	var piled := _mixed_heights(medium._shuffles._wash_plan(600 + int(SEEDS[0]), WASH_S))
	medium._shuffles._splay = true
	medium._shuffles._roomy = true
	medium._shuffles._rest_steps = {}
	medium._shuffles._rest_lifts = {}
	mixed.sort()
	piled.sort()
	var most := mixed[mixed.size() - 1]
	var p99 := mixed[mixed.size() * 99 / 100]
	print("  as the washes mix, the cards lie %.1f mm over the cloth at most, 99%% under %.1f mm (the wash as it was: %.1f mm, 99%% under %.1f)"
		% [most * 1000.0, p99 * 1000.0, piled[piled.size() - 1] * 1000.0, piled[piled.size() * 99 / 100] * 1000.0])
	_ok(most < MIXED_MOST and p99 < MIXED_MOST * 0.6, "a heap stays low as it is mixed: no card %.0f mm over the cloth (%.1f mm), 99%% under %.0f mm (%.1f mm)"
		% [MIXED_MOST * 1000.0, most * 1000.0, MIXED_MOST * 600.0, p99 * 1000.0])
	_ok(piled[piled.size() - 1] > MIXED_MOST * 1.5 and piled[piled.size() * 99 / 100] > MIXED_MOST,
		"control: the wash as it was, no card splaying and the deck spread no wider, lies on heaps far taller (%.1f mm, 99%% under %.1f)"
		% [piled[piled.size() - 1] * 1000.0, piled[piled.size() * 99 / 100] * 1000.0])


## How high over the cloth each card of [param plan] lies as it is mixed (meters, every 0.15 s from a
## second after the spread until the gather): the fan-out off the deck and the pile are tall as they
## should be.
func _mixed_heights(plan: Dictionary) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var mix: Vector2 = plan["mix"]
	for st in range(int(ceil((mix.x + 1.0) * TableShuffle.WASH_HZ)), int(float(plan["gather"]) * TableShuffle.WASH_HZ), 3):
		var v := float(st) / TableShuffle.WASH_HZ
		var rests: Array = medium._shuffles._wash_rest(plan, st)
		for i in rests.size():
			if not TableShuffle._off_cloth(plan, i, v):
				out.append((rests[i] as Vector3).x - TableShuffle.WASH_FLOOR)
	return out
