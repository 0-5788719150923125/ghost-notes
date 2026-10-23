extends Node

## THE DECK'S CARDS LIE THE WAY THEY LIE (2026-10-10, the user, of the shuffle: "the orientation of
## the very top card never changes. That is unexpected. For example, if the deck is cut - you would
## expect that top card's orientation to change, at least some of the time. But worse: there are
## instances where the orientation DOES change after shuffling, but then it 'reverts' wrongly, back
## to the original orientation"). The top slot was turned for the next card drawn, always, whichever
## mesh a move brought up; and a wash squared every card back upright the short way round. Posed
## from show time, the deck's meshes:
##
##   - CARRY THEIR WAY THROUGH A MOVE: for every move (riffle, overhand, cut, a wash that turned
##     cards half way round) each slot's card, just before the move ends, faces the way the slot it
##     goes to faces just after - nothing reverts at the hand-over. Two-sided: asked of the slot
##     itself, not where the card went, the cards disagree (the measure can tell);
##   - SHUFFLES CHANGE THE TOP CARD'S WAY: over many shuffles, the card on top between moves faces
##     both ways, and a cut now and then brings up a card that faces the other way;
##   - A WASH TURNS CARDS: planned washes have cards that lie half a turn round when gathered, and
##     the pile is squared to that, a quarter turn at most;
##   - THE SHUFFLE ENDS ON THE WAY THE NEXT CARD IS DRAWN: the top, as the deck settles before the first
##     card, faces as that card does - reversed or upright - whatever the shuffle did;
##   - A MOVE THE FIRST CARD CUTS OFF IS FINISHED, NOT UNDONE (2026-10-18, true-tarot 288024: "a card
##     'pops' to the top, clipping through the other cards from below"): the deck settles along the rest
##     of the move's own path, and no more cards pass each other than the move itself makes them -
##     two-sided: eased back to where each began, they pass by the thousand;
##   - THE FIRST CARD IS THE DECK'S OWN TOP CARD until the hand takes it ("or appearing out of
##     nowhere"): unseen before, then itself where the top card lay, the deck a card shorter.
##
##   tests/run_boot_probe.sh tests/table/deck_turns_check.gd 420
##
## A BOOT probe (the medium reaches the Director); no GPU - poses are transforms.

const SEEDS := 8

var _fails := 0
var medium: TableMedium
var subs: Subtitles


func _ready() -> void:
	_run.call_deferred()


func _ok(cond: bool, what: String) -> void:
	print(("  ok    " if cond else "  FAIL  ") + what)
	if not cond:
		_fails += 1


## Whether a deck mesh lies upright (its top edge away from the reader) or turned about.
static func _upright(xf: Transform3D) -> bool:
	return xf.basis.z.z > 0.0


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
	_control()
	_turned_washes()
	_chains()
	_ends_on_the_next_card()
	_finished()
	_handed_off()
	Director.hold(false)
	Director.detach()
	print("deck_turns_check: %s" % ("ALL OK" if _fails == 0 else "%d FAILED" % _fails))
	get_tree().quit(0 if _fails == 0 else 1)


## A reading that shuffles for a long while (a hundred and fifty words, so the first card is a
## minute away) and draws one card, [param reversed] or not; the medium made ready for it.
func _ready_reading(seed: int, reversed: bool) -> Dictionary:
	var words := ""
	for i in 150:
		words += "slow "
	var script := CardReading.compose([{"kind": "shuffle", "card": 0, "text": "Shuffle the deck, " + words + "slowly."},
		{"kind": "draw", "card": 1, "text": "One."}, {"kind": "spread", "card": 0, "text": "Done."}])
	var cards: Array = [{"key": "c0", "name": "Card", "numeral": "0", "reversed": reversed, "jumper": false,
		"position": {}, "booklet": {}, "art": ""}]
	var doc := {"show": "turns-check", "seed": seed, "dir": "", "plan": {"look": {"candles": 2}}, "cards": cards}
	subs.words = load("res://tests/table/table_look_probe.gd").timeline(CardReading.parse(script), 0.36, Director.intro_hold)
	subs.document = {"source": script, "title": "Turns Check", "table": doc}
	medium._ensure_doc()
	medium._follow.extend(subs.words)
	medium._sched = medium._follow.place(medium._plan.parse["actions"], maxf(Director.intro_hold, 0.6), TableMedium.LEAD, TableMedium.TAIL)
	var tm: Dictionary = medium._times()
	return {"ts": float(tm["shuffle"]), "te": float((tm["first"] as Array)[0]), "tm": tm}


## The deck's meshes posed at show time [param t]: whether each lies upright.
func _facing(t: float) -> Array:
	medium._now = t
	medium._pose(t)
	var out: Array = []
	for i in medium._plan.deck_n:
		out.append(_upright((medium._deck[i] as MeshInstance3D).transform))
	return out


## The measure can tell a turned card from an upright one, and a cut's cards from each other.
func _control() -> void:
	var xf := Transform3D(Basis(Vector3.UP, 0.02), Vector3.ZERO)
	_ok(_upright(xf) and not _upright(Transform3D(xf.basis * Basis(Vector3.UP, PI), Vector3.ZERO)),
		"control: the measure tells a card turned half way round from an upright one")


## Washes turn cards - and gather them turned.
func _turned_washes() -> void:
	_ready_reading(1, false)
	var turned_n := 0
	var worst := 0.0
	for s in 6:
		var dur := 26.0 + float(s)
		var plan: Dictionary = medium._shuffles._wash_plan(900 + s, dur)
		var turned: PackedByteArray = plan["turned"]
		var order: Array = plan["order"]
		for slot in order.size():
			var i := int(order[slot])
			turned_n += int(turned[i])
			# squared: the card's last yaw is the deck slot's own, or half a turn from it
			var last: PackedVector4Array = (plan["tracks"] as Array)[i]
			var jit: Vector3 = medium._plan.slot_jit[slot]
			var off := fposmod(last[last.size() - 1].w - jit.z, TAU)
			var want := PI if int(turned[i]) == 1 else 0.0
			worst = maxf(worst, absf(wrapf(off - want, -PI, PI)))
	_ok(turned_n > 0, "washes turn cards half way round, and gather them turned (%d of %d)" % [turned_n, 6 * medium._plan.deck_n])
	_ok(worst < 0.01, "and the pile is squared to the way each lies (%.3f rad at most)" % worst)


## Every move hands its cards over the way they lie, and the top card's way changes over a shuffle.
func _chains() -> void:
	var same_slot_differs := 0
	var handed := 0
	var checked := 0
	var tops := {}
	var changed := 0
	var by_kind := {}
	for s in range(1, SEEDS + 1):
		var r := _ready_reading(s, s % 2 == 0)
		var ts: float = r["ts"]
		var te: float = r["te"]
		var moves: Array
		if s == 1:
			# a wash in the chain: spread, mixed and gathered, then a cut, an overhand pass, a riffle
			medium._shuffles.moves = [
				{"kind": "wash", "t0": 0.3, "dur": 26.0, "pause": 3.0, "seed": 4321, "plan": medium._shuffles._wash_plan(4321, 26.0)},
				{"kind": "cut", "t0": 29.3, "dur": 1.7, "pause": 3.0, "seed": 5},
				{"kind": "overhand", "t0": 34.0, "dur": 2.6, "pause": 3.0, "seed": 9},
				{"kind": "riffle", "t0": 39.6, "dur": 2.4, "pause": 3.0, "seed": 3},
				{"kind": "cut", "t0": 45.0, "dur": 1.7, "pause": 1000.0, "seed": 11}]
		else:
			medium._plan_moves()
		moves = medium._shuffles.moves
		medium._now = te - 0.5
		medium._pose(te - 0.5)     # the room the shuffle has
		var last_top := -1
		for m in moves:
			var d: Dictionary = m
			var end := float(d["t0"]) + float(d["dur"])
			if end + 0.1 > te - ts - 3.0:
				break
			var goes: Dictionary = medium._shuffles._move_goes(d)
			var to: PackedInt32Array = goes["to"]
			var before := _facing(ts + end - 0.002)
			var after := _facing(ts + end + 0.1)
			var kind := String(d["kind"])
			if not by_kind.has(kind):
				by_kind[kind] = [0, 0]
			for i in medium._plan.deck_n:
				checked += 1
				(by_kind[kind] as Array)[1] += 1
				if before[i] == after[to[i]]:
					handed += 1
					(by_kind[kind] as Array)[0] += 1
				if before[i] != after[i]:
					same_slot_differs += 1
			var top: int = 1 if after[medium._plan.deck_n - 1] else 0
			tops[top] = true
			if last_top >= 0 and top != last_top:
				changed += 1
			last_top = top
	for k in by_kind:
		var v: Array = by_kind[k]
		_ok(v[0] == v[1], "a %s hands every card over the way it lies (%d of %d)" % [k, v[0], v[1]])
	_ok(checked > 0 and handed == checked, "no card reverts as a move ends (%d of %d hand-overs)" % [handed, checked])
	_ok(same_slot_differs > 0, "control: asked of the slot, not where the card went, the cards disagree (%d)" % same_slot_differs)
	_ok(tops.size() == 2, "the card on top faces both ways over the shuffles (%d ways)" % tops.size())
	_ok(changed > 0, "and a move now and then brings up a card that faces the other way (%d times)" % changed)


## As the shuffle settles, the card on top faces as the first card does - the one a move cut off by the
## first card leaves there ([method _finished]).
func _ends_on_the_next_card() -> void:
	var worst := 0
	var n := 0
	for s in range(1, SEEDS + 1):
		for reversed in [false, true]:
			# (a seed of its own: the medium keeps the doc it has for the same show and seed)
			var r := _ready_reading(100 + s + (1000 if reversed else 0), reversed)
			var te: float = r["te"]
			medium._plan_moves()
			var face := _facing(te + TableMedium.SQUARE - 0.01)
			var hi := 0
			for i in medium._plan.deck_n:
				if (medium._deck[i] as MeshInstance3D).transform.origin.y > (medium._deck[hi] as MeshInstance3D).transform.origin.y:
					hi = i
			n += 1
			if bool(face[hi]) == reversed:
				worst += 1
	_ok(worst == 0, "the shuffle ends on the way the next card is drawn, reversed or not (%d of %d wrong)" % [worst, n])


## How many times two of the deck's cards lying over each other change places in the stack between
## [param a] and [param b] (each deck mesh's transform, a frame apart): one rising past the other.
func _passes(a: Array, b: Array) -> int:
	var n := 0
	var reach := TableMedium.CARD.x * 0.8
	for i in a.size():
		for j in range(i + 1, a.size()):
			var pa: Vector3 = (a[i] as Transform3D).origin
			var pb: Vector3 = (a[j] as Transform3D).origin
			var qa: Vector3 = (b[i] as Transform3D).origin
			var qb: Vector3 = (b[j] as Transform3D).origin
			if Vector2(pa.x - pb.x, pa.z - pb.z).length() > reach or Vector2(qa.x - qb.x, qa.z - qb.z).length() > reach:
				continue
			if signf(pa.y - pb.y) != signf(qa.y - qb.y):
				n += 1
	return n


func _deck_now() -> Array:
	var out: Array = []
	for i in medium._plan.deck_n:
		out.append((medium._deck[i] as MeshInstance3D).transform)
	return out


## A MOVE THE FIRST CARD CUTS OFF IS FINISHED, NOT UNDONE (true-tarot 288024, the user, 2026-10-18: "At
## the end of the shuffle, a card 'pops' to the top, clipping through the other cards from below"): with a
## riffle, an overhand pass or a cut under way as the first card comes, the deck settles along the rest of
## the move's own path - no card passes another that the move itself, played on at its own pace, would
## not. Two-sided: each card eased straight back to the slot it began the move in - the old squaring -
## carries cards up past the cards over them by the thousand. (The moves' own paths are not clean: an
## overhand's packets drop through the edges of the cards still held, and a riffle's halves lift through
## each other - measured here, and not this check's to hold.)
func _finished() -> void:
	var dt := 1.0 / 60.0
	var passes := {}
	var own := {}
	var old := {}
	var tops_ok := 0
	var n := 0
	for kind in ["overhand", "cut", "riffle"]:
		passes[kind] = 0
		own[kind] = 0
		old[kind] = 0
		for into in [0.3, 0.55, 0.8]:
			var r := _ready_reading(300 + n, n % 2 == 1)
			var ts: float = r["ts"]
			var te: float = r["te"]
			var dur := 2.4
			medium._shuffles.moves = [{"kind": kind, "t0": te - ts - dur * into, "dur": dur, "pause": 1000.0, "seed": 17 + n}]
			n += 1
			var t := te - 0.05
			medium._now = t
			medium._pose(t)
			var prev := _deck_now()
			var was := prev
			# (as it settles the deck is posed slot by slot again - its cards alike, the hand-over unseen)
			while t < te + TableMedium.SQUARE - dt * 1.5:
				t += dt
				medium._now = t
				medium._pose(t)
				var now := _deck_now()
				passes[kind] = int(passes[kind]) + _passes(prev, now)
				prev = now
			# the rest of the move at its own pace
			var m: Dictionary = medium._shuffles.moves[0]
			var v := te - ts - float(m["t0"])
			var walked: Array = []
			while v < dur - dt * 1.5:
				var row: Array = []
				for i in medium._plan.deck_n:
					row.append(medium._shuffles._move_xf(i, v, m))
				if not walked.is_empty():
					own[kind] = int(own[kind]) + _passes(walked, row)
				walked = row
				v += dt * 0.25
			# the old squaring: from the move as it was cut off, eased straight back to each card's slot
			var tc := te
			var before: Array = []
			for i in medium._plan.deck_n:
				before.append(medium._shuffles.shuffle_xf(i, te - ts))
			while tc < te + TableMedium.SQUARE:
				tc += dt
				var f := TableMedium._ease(clampf((tc - te) / TableMedium.SQUARE, 0.0, 1.0))
				var eased: Array = []
				for i in medium._plan.deck_n:
					eased.append(medium._shuffles.shuffle_xf(i, te - ts).interpolate_with(medium._rest_xf(i), f))
				old[kind] = int(old[kind]) + _passes(before, eased)
				before = eased
			# the top, settled, faces the way the first card comes up - and did on its way there
			var face_end := _facing(te + TableMedium.SQUARE - 0.01)
			var hi := -1
			var hy := -INF
			for i in medium._plan.deck_n:
				var y := (medium._deck[i] as MeshInstance3D).transform.origin.y
				if y > hy:
					hy = y
					hi = i
			var settled := _facing(te + TableMedium.SQUARE + 0.05)
			if bool(face_end[hi]) != bool(medium._reversed(0)) and bool(settled[medium._plan.deck_n - 1]) != bool(medium._reversed(0)):
				tops_ok += 1
	for kind in passes:
		_ok(int(passes[kind]) <= int(own[kind]), "a %s the first card cuts off is finished along its own path: cards pass each other %d times, the move itself %d" % [
			kind, int(passes[kind]), int(own[kind])])
		_ok(int(old[kind]) > 3 * maxi(int(own[kind]), 1), "control: each card eased back to where it began the %s, cards pass each other %d times" % [kind, int(old[kind])])
	_ok(tops_ok == n, "and the card it leaves on top faces as the first card comes up, before it settles and after (%d of %d)" % [tops_ok, n])


## THE FIRST CARD IS THE DECK'S OWN TOP CARD until the hand takes it: not to be seen before, the deck's
## top card in its place; then the card itself, where that card lay and turned as it was, and the deck a
## card shorter. It used to be a card of its own laid over the whole deck from the moment the shuffle
## ended - seen to appear on the top as the shuffle's last cards came down (2026-10-18).
func _handed_off() -> void:
	var good := 0
	var n := 0
	for s in 6:
		var r := _ready_reading(400 + s, s % 2 == 1)
		var te: float = r["te"]
		medium._plan_moves()
		var leave := medium._leaves(0)
		n += 1
		var hidden := true
		var t := te - 0.1
		while t < leave - 0.02:
			medium._now = t
			medium._pose(t)
			hidden = hidden and not (medium._cards[0] as MeshInstance3D).visible
			t += 0.05
		medium._now = leave - 0.001
		medium._pose(leave - 0.001)
		var top: MeshInstance3D = medium._deck[medium._plan.deck_n - 1]
		var was := top.transform
		var shown_before := top.visible
		medium._now = leave + 0.001
		medium._pose(leave + 0.001)
		var card: MeshInstance3D = medium._cards[0]
		var at := card.transform
		var same := Vector2(at.origin.x - was.origin.x, at.origin.z - was.origin.z).length() < 0.0005 \
			and absf(at.origin.y - was.origin.y) < TableMedium.CARD_T \
			and (at.basis.z.normalized()).dot(was.basis.z.normalized()) > 0.999
		if hidden and shown_before and card.visible and not top.visible and same:
			good += 1
		else:
			print("    seed %d: hidden before %s, top shown before %s, card shown %s, top hidden after %s, same place %s" % [
				400 + s, hidden, shown_before, card.visible, not top.visible, same])
	_ok(good == n, "the first card is the deck's top card until it is taken, then itself where that card lay (%d of %d)" % [good, n])
