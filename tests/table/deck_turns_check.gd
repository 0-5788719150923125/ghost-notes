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
##   - THE SHUFFLE ENDS ON THE WAY THE NEXT CARD IS DRAWN: the top, just before the first card, faces
##     as that card does - reversed or upright - whatever the shuffle did.
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
			medium._moves = [
				{"kind": "wash", "t0": 0.3, "dur": 26.0, "pause": 3.0, "seed": 4321, "plan": medium._shuffles._wash_plan(4321, 26.0)},
				{"kind": "cut", "t0": 29.3, "dur": 1.7, "pause": 3.0, "seed": 5},
				{"kind": "overhand", "t0": 34.0, "dur": 2.6, "pause": 3.0, "seed": 9},
				{"kind": "riffle", "t0": 39.6, "dur": 2.4, "pause": 3.0, "seed": 3},
				{"kind": "cut", "t0": 45.0, "dur": 1.7, "pause": 1000.0, "seed": 11}]
		else:
			medium._plan_moves()
		moves = medium._moves
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


## Just before the first card, the top faces as that card does.
func _ends_on_the_next_card() -> void:
	var worst := 0
	var n := 0
	for s in range(1, SEEDS + 1):
		for reversed in [false, true]:
			# (a seed of its own: the medium keeps the doc it has for the same show and seed)
			var r := _ready_reading(100 + s + (1000 if reversed else 0), reversed)
			var te: float = r["te"]
			medium._plan_moves()
			var face := _facing(te - 0.01)
			n += 1
			if bool(face[medium._plan.deck_n - 1]) == reversed:
				worst += 1
	_ok(worst == 0, "the shuffle ends on the way the next card is drawn, reversed or not (%d of %d wrong)" % [worst, n])
