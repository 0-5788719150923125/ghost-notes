extends RefCounted
class_name TableShuffle

## TableShuffle - every move the deck makes between readings, and where each of its cards is
## during one: the riffle, the overhand, the cut, the wash that spreads the whole deck over the
## cloth and gathers it again, a jumper thrown clear. A part of [TableMedium].
##
## A PURE FUNCTION OF THE TIME INTO THE SHUFFLE, like everything the table shows: [method
## shuffle_xf] is deck slot i at u seconds, [method deck_turns] the way round each card lies,
## and nothing here is advanced frame by frame - a scrub and an export land in the middle of a
## wash and find every card where a live session has it.
##
## WHAT IT IS HANDED is written out: every `medium.` below is something the shuffle reads of the table
## it is part of (where the deck stands, how much room the cloth leaves, what stands on it, the
## seed, the moves the schedule laid down), and none of it is written here but [member
## TableMedium._moves], which this fills in on first ask. Its own state is what it works out and
## keeps: a wash's plan, the way each card began, the rest each card comes to.
##
## THE TABLE ASKS SEVEN THINGS of it, the names without an underscore: [method shuffle_xf],
## [method shuffle_wander], [method move_at], [method deck_turns], [method riffle], [method wash],
## [method wash_jump]. Everything else is how those are answered.

## The [TableMedium] this is a part of: everything read through it is something this part
## is handed, and the list of them is what it depends on.
var medium: TableMedium

const CLOTH := TablePositions.CLOTH
## HOW A READER SHUFFLES: in RUNS - several riffles, a string of cuts, a few overhand passes,
## one at a tempo - and then nothing for a while, the deck squared under their hands while they
## talk. A run per kind: how likely it is chosen, how many moves, each move's length and the gap
## inside the run. The wash (the deck spread and swirled across the cloth) is its own event: rare,
## long, and once at most.
const RUNS := {
	"riffle": {"weight": 3.0, "n": [2, 4], "dur": [2.2, 2.7], "gap": [0.2, 0.55]},
	"overhand": {"weight": 2.0, "n": [2, 5], "dur": [2.1, 2.6], "gap": [0.05, 0.3]},
	"cut": {"weight": 2.0, "n": [2, 5], "dur": [1.15, 1.5], "gap": [0.05, 0.25]},
	"wash": {"weight": 0.9, "n": [1, 1], "dur": [26.0, 32.0], "gap": [0.0, 0.0]},
}
## How many packets an overhand pass peels off the held cards.
const OVERHAND_PACKETS := 5
## The share of the deck that lies the other way round, face down (the share CardDeck.shuffled
## turns up reversed). Shuffles carry each card's way with it; the one that ends on top is the way
## the next card drawn comes up.
const DECK_TURNED := 0.32
## The pause after a run: mostly a few seconds, now and then a long linger - median ~3 s.
const IDLE_LOG := Vector2(1.1, 0.55)
const IDLE_RANGE := Vector2(1.6, 18.0)
## The chance a run is followed by a long linger instead.
const LINGER_CHANCE := 0.15
## A wash is sampled at this rate once, when it is planned, and posed by lookup.
const WASH_HZ := 20.0
## THE FAN-OUT CALMED (the user, 2026-10-08: as the cards fan out they "wobble and vibrate, which
## is a thing cards shouldn't do"): under the palm, each card's tilt is the mean of its resting tilt
## over CALM_REACH steps of CALM_HZ either side - a card sliding off another's edge tipped in a frame
## (576 deg/s, measured) and back - and it is set down on its highest support at that tilt, so it
## never floats nor dips. Calm until the cards are out, easing to the bare rest over CALM_SETTLE.
const CALM_HZ := 20.0
const CALM_REACH := 2
const CALM_SETTLE := 0.5
## The least time a wash needs to spread, mix a little and gather (seconds): with less before the
## first card, the deck is not washed at all.
const WASH_ROOM := 9.0
const FLOOR_GAP := 0.0001
const WASH_T := 0.0003
const STACK_GAP := 0.0001
## A spread card lying on the cloth: its middle this high. And one card's place in a pile.
const WASH_FLOOR := TableMedium.CLOTH_TOP + FLOOR_GAP + WASH_T * 0.5
const WASH_LAYER := WASH_T + STACK_GAP
## How long the deck takes to flatten under the palm (seconds) - to its cards' own thickness, so
## the first cards slide off a low stack, not a deck's height.
const WASH_FLATTEN := 0.35
## THE HANDS IN A WASH (2026-10-05, the user: "cards barely move... the movements are very small,
## very localized... It would be much more common for cards to sweep back, and forth, back, and
## forth in various directions, crossing large regions of the table, creating chaos along their
## path"): each palm had worked a 6 cm circle, and the cards under it went round that circle and
## back - 4 cm the longest straight run, 11 cm the farthest a card got. How often a palm scrubs,
## swirls or fetches ([method _wash_gesture]), how long a scrub's pass is (meters), and how often a
## palm rests a moment between gestures.
const WASH_GESTURES := {"scrub": 0.65, "swirl": 0.15, "fetch": 0.2}
const WASH_SCRUB := Vector2(0.2, 0.4)
const WASH_REST := 0.12
## A palm flat on the cards: half its width and half its length (meters), its length along the
## forearm from the reader's shoulder (to the side and toward the reader, about the deck's place).
## It comes down and lifts over WASH_TOUCH seconds, keeps its middle WASH_APART from the other
## palm's when it can, and fetches a card lying out past WASH_STRAY of the spread's reach.
const PALM := Vector2(0.045, 0.08)
const WASH_SHOULDER := Vector2(0.19, 0.46)
const WASH_TOUCH := 0.12
const WASH_APART := 0.14
const WASH_STRAY := 0.85
## Where on a card a palm takes hold (meters across and along it, from its middle), and a card's
## turning inertia over its mass (meters squared: a 70 x 120 mm sheet).
const GRIP_AT := [Vector2.ZERO, Vector2(-0.022, -0.04), Vector2(0.022, -0.04), Vector2(-0.022, 0.04),
	Vector2(0.022, 0.04)]
const CARD_I := (0.07 * 0.07 + 0.12 * 0.12) / 12.0
## HOW CARDS SLIDE in a wash (centers: each wash samples its own feel round them). How hard a palm
## can pull a card it presses whole (m/s each second - far past what the cloth holds back, so the
## card goes with it) - where another card lies over it, WASH_COVERED of that; the drag between two
## cards lying one on the other (per second: loose, and added when a palm presses the top one); how
## much of the difference in their speeds a card sliding into another gives it as they meet; how fast
## a loose card slows (m/s each second, WASH_ON_CARD of that on another card) and stops turning
## (radians/s each second); and the fastest a hand drags a card (m/s) or turns one (radians/s).
## A MEETING IS A NUDGE, NOT A BOUNCE (the user: cards must not "repel each other in a way that makes
## them almost bouncy"): the card run into takes a sixth of the difference in their speeds, where
## they touch - well short of evening them, so nothing ever comes back the way it went - and a hand
## turns a card a few radians a second at most. The chaos along a sweep is the drag's.
const WASH_GRIP := 40.0
const WASH_COVERED := 0.25
const WASH_DRAG := Vector2(5.0, 40.0)
const WASH_KNOCK := 0.16
const WASH_SLIDE := 3.0
const WASH_ON_CARD := 0.55
const WASH_SPIN := 40.0
const HAND_SPEED := 1.2
const WASH_TURN_MAX := 3.5
## A heap slumps ([method _wash_slump]): a loose card this many cards up creeps off it, this fast
## (m/s) for each card higher.
const SLUMP_FROM := 3
const SLUMP := 0.012
## A CARD STRUCK HARD IS THROWN OUT OF THE SPREAD (2026-10-06, the user: "when a lot of repulsion is
## applied, a card can get ejected... I would expect some ejections to land face-down, and thus NOT
## be drawn"): a meeting faster than EJECT_SPEED (m/s, their speeds apart) may throw the card run
## into - surer the harder, up to EJECT_CHANCE - a hop of EJECT_REACH (meters) along the blow, onto
## the cloth and in the picture, clear of everything that stands. It lands face down: a deck card's
## face is never painted, so only a drawn card - a jumper - may come down face up. A card is thrown
## only with nothing lying on it and no palm on it, at most EJECT_MOST a wash, and none in the last
## EJECT_ROOM seconds of the mixing (it is down before the gather). Its hop's height (meters) and
## how long it takes (seconds).
const EJECT_SPEED := 0.5
const EJECT_CHANCE := 0.35
const EJECT_REACH := Vector2(0.1, 0.28)
const EJECT_MOST := 2
const EJECT_ROOM := 1.5
const EJECT_HOP := Vector2(0.012, 0.035)
const EJECT_TIME := Vector2(0.35, 0.55)
## A JUMPER OUT OF A WASH: when the first card is a jumper and the deck is being washed as its moment
## comes, the jumper is the card a hard blow throws out - over, face up, clear of the rest - this far
## into its action (its own seconds), and lies there until it is picked up as from a riffle; the hands
## stop as it flies and gather the rest once it is up. Its hop (meters) and flight (seconds), how long
## the gather takes, and the least mixing before it (a wash only just spread has nothing to throw).
const JUMP_EJECT := 0.35
const JUMP_HOP := Vector2(0.075, 0.095)
const JUMP_FLIGHT := Vector2(0.45, 0.6)
const JUMP_GATHER := 4.2
const JUMP_MIX := 3.0
var _rest_plan: Dictionary = {}     # the wash plan [member _rest_steps] are of
var _rest_steps := {}               # plan step -> every card at rest there ([method _wash_rest])
var _rest_lifts := {}               # ...and how far a steep card is lifted so its posed corners clear ([method _wash_rise])
var _collide := true                  # cards go round what stands (off only for a gate's control)
var _flip0 := PackedByteArray()      # per card, as the deck lies at the shuffle's start: the other way round ([method _deck_flip0])
var _flip_key := ""                  # what [member _flip0] was made for...
var _flip_moves: Array = []          # ...and the chain of moves it was made on

# --- the shuffle ------------------------------------------------------------------------------

## The resting spot after each shuffle move drifts a few millimeters. It is computed from the
## move's seed and eased over that move, so repeated cuts do not snap to an identical spot.
func shuffle_wander(u: float) -> Vector3:
	move_at(u)
	var from := Vector3.ZERO
	for m in medium._moves:
		var d: Dictionary = m
		var start := float(d["t0"])
		if u < start:
			break
		var rng := RandomNumberGenerator.new()
		rng.seed = hash([int(d["seed"]), "resting place"])
		var to := Vector3(rng.randf_range(-0.004, 0.004), 0.0, rng.randf_range(-0.004, 0.004))
		if u < start + float(d["dur"]):
			return from.lerp(to, TableMedium._ease(clampf((u - start) / maxf(float(d["dur"]), 0.01), 0.0, 1.0)))
		from = to
	return from


## Deck slot [param i] at [param u] seconds into the shuffle, posed about where the deck is
## ([member _cur_base]). The shuffle is a chain of RUNS (see [constant RUNS], [method move_at]).
##
## THE DECK'S MESHES ARE INTERCHANGEABLE: every move ends with slot i's mesh in some other slot
## j, and the next move starts it in slot i again. They are identical cards, and a slot's small
## offset belongs to the slot, so the hand-over is invisible.
func shuffle_xf(i: int, u: float) -> Transform3D:
	var m := move_at(u)
	if m.is_empty():
		return medium._rest_xf(i)
	var v := u - float(m["t0"])
	var dur := float(m["dur"])
	match String(m["kind"]):
		"riffle":
			return riffle(i, v, dur, int(m["seed"]))
		"overhand":
			return _overhand(i, v, dur, int(m["seed"]))
		"cut":
			return _cut(i, v, dur, int(m["seed"]))
		"wash":
			return wash(i, v, m)
	return medium._rest_xf(i)


## THE DECK'S CARDS LIE THE WAY THEY LIE (2026-10-10, the user: "when shuffling, the orientation of the
## very top card never changes" - and, once in a while, "then it reverts wrongly"). The deck's meshes
## are interchangeable ([method shuffle_xf]), so a card's way round was not a thing of its own: the
## top slot was turned for the next card drawn, always, whichever mesh a cut brought up, and a mesh
## that had flown away turned was upright again the moment its move ended. Now every card has its way
## ([constant DECK_TURNED] of them lie turned about), a move carries it from slot to slot
## ([method _move_goes]: where each slot goes, and which cards the move turns over, a wash's), and
## the card that comes to the top by the shuffle's end is the way the next card drawn comes up - made
## so by the way the deck began ([method _deck_flip0]), the one card chosen back to its start.
## [method _chain_at] is the deck between moves: where each slot's card began, and how often it has
## been turned about since.

## Where each slot of the deck goes in [param m], and which of its cards the move turned about:
## `{to: slot -> slot, turned}`.
func _move_goes(m: Dictionary) -> Dictionary:
	var to := PackedInt32Array()
	var turned := PackedByteArray()
	to.resize(TableMedium.DECK_N)
	turned.resize(TableMedium.DECK_N)
	match String(m["kind"]):
		"riffle":
			for i in TableMedium.DECK_N:
				to[i] = _riffle_to(i)
		"overhand":
			for i in TableMedium.DECK_N:
				to[i] = _overhand_to(i).x
		"cut":
			var rng := RandomNumberGenerator.new()
			rng.seed = int(m["seed"])
			var a := _cut_split(rng)
			for i in TableMedium.DECK_N:
				to[i] = (i - a) if i >= a else (TableMedium.DECK_N - a + i)
		"wash":
			var plan := _wash_fit(m)
			var order: Array = plan.get("order", [])
			if order.is_empty():
				for i in TableMedium.DECK_N:
					to[i] = i
			else:
				# a card the wash threw out for good (the jumper) is the deck's top, hidden
				for i in TableMedium.DECK_N:
					to[i] = TableMedium.DECK_N - 1
				for slot in order.size():
					to[int(order[slot])] = slot
				turned = (plan["turned"] as PackedByteArray).duplicate()
		_:
			for i in TableMedium.DECK_N:
				to[i] = i
	return {"to": to, "turned": turned}


## What [member _moves] key [method _chain_at] made its states for: they change with the room the
## shuffle has, and the wash that is cut short to fit it.
func _chain_key() -> String:
	return "%s|%s|%s" % [medium._shuffle_room, medium._jump_room, medium._jump_scale]


## The deck at the START of move [param idx] (and so in the pause before it): `{src, turn}` - for
## each slot, which card of the deck's start lies there, and whether it has been turned about an odd
## number of times since. Kept on each move, for the frames after.
func _chain_at(idx: int) -> Dictionary:
	var key := _chain_key()
	var n := mini(idx, medium._moves.size())
	var src0 := PackedInt32Array()
	var turn0 := PackedByteArray()
	src0.resize(TableMedium.DECK_N)
	turn0.resize(TableMedium.DECK_N)
	for i in TableMedium.DECK_N:
		src0[i] = i
	var state := {"src": src0, "turn": turn0}
	var from := 0
	for j in range(n, 0, -1):
		var d: Dictionary = medium._moves[j - 1]
		if String(d.get("chain_key", "")) == key:
			state = d["after"]
			from = j
			break
	for j in range(from, n):
		var m: Dictionary = medium._moves[j]
		var go := _move_goes(m)
		var to: PackedInt32Array = go["to"]
		var turned: PackedByteArray = go["turned"]
		var was_src: PackedInt32Array = state["src"]
		var was_turn: PackedByteArray = state["turn"]
		var src := PackedInt32Array()
		var turn := PackedByteArray()
		src.resize(TableMedium.DECK_N)
		turn.resize(TableMedium.DECK_N)
		for i in TableMedium.DECK_N:
			src[to[i]] = was_src[i]
			turn[to[i]] = was_turn[i] ^ turned[i]
		state = {"src": src, "turn": turn}
		m["after"] = state
		m["chain_key"] = key
	return state


## The first move that has not ended by [param u] seconds into the shuffle - the one under way, or
## the next - and so the state of the deck then ([method _chain_at]).
func _move_index_at(u: float) -> int:
	move_at(u)
	for i in medium._moves.size():
		var d: Dictionary = medium._moves[i]
		if float(d["t0"]) + float(d["dur"]) > u:
			return i
	return medium._moves.size()


## How each card of the deck lies at the shuffle's start: [constant DECK_TURNED] of them the other
## way round, seeded - and the one card that is on top when the shuffle ends chosen back to its
## start, so its way is the way the next card drawn comes up (for the jumper's wash, once it is
## gathered, with the jumper's card gone from it).
func _deck_flip0(te: float, ts: float, tm: Dictionary, wj: Dictionary) -> PackedByteArray:
	var key := "%s|%s|%s|%s" % [te, ts, wj.get("end", ""), _chain_key()]
	if key == _flip_key and is_same(_flip_moves, medium._moves) and _flip0.size() == TableMedium.DECK_N:
		return _flip0
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([medium._plan.seed_value, "deck-turned"])
	var f0 := PackedByteArray()
	f0.resize(TableMedium.DECK_N)
	for c in TableMedium.DECK_N:
		f0[c] = 1 if rng.randf() < DECK_TURNED else 0
	if te < INF and not medium._cards.is_empty():
		var at := te - ts - 0.001
		var idx := _move_index_at(at)
		var st := _chain_at(idx)
		var slot := TableMedium.DECK_N - 1
		var want := medium._top_deck_reversed(te - 0.001, tm)
		var turned := 0
		if not wj.is_empty():
			# the jumper's wash: the pile's top is the last card the wash lays, once it is down
			var order: Array = (wj["plan"] as Dictionary).get("order", [])
			if not order.is_empty():
				slot = int(order[order.size() - 1])
				turned = (wj["plan"] as Dictionary)["turned"][slot]
			want = medium._top_deck_reversed(float(wj["end"]), tm)
		elif idx < medium._moves.size() and at >= float((medium._moves[idx] as Dictionary)["t0"]):
			# a move still under way when the shuffle ends: its cards go to their slots, turned
			# as they were
			turned = (_move_goes(medium._moves[idx]) as Dictionary)["turned"][slot]
		var lies := int((st["turn"] as PackedByteArray)[slot]) ^ turned
		f0[(st["src"] as PackedInt32Array)[slot]] = (1 if want else 0) ^ lies
	_flip0 = f0
	_flip_key = key
	_flip_moves = medium._moves
	return f0


## The turn (radians about the card's own vertical) each deck slot's mesh carries at [param t] on top
## of its move's pose: its card's way round, and - as the shuffle ends - a turn the move's pose had
## in it handed over, so the card is not seen to turn back ([method wash]'s cards turned half way
## round are squared a quarter turn at most, the rest of the turn is here). Past the end of the
## shuffle only the top slot's turn is the table's own ([method _pose]).
func deck_turns(t: float, ts: float, te: float, tm: Dictionary, wj: Dictionary, jump_s: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(TableMedium.DECK_N)
	var f0 := _deck_flip0(te, ts, tm, wj)
	# the deck from the shuffle's end on is the deck as the last move left it
	var at := minf(t - ts, te - ts - 0.001)
	var idx := _move_index_at(at)
	var st := _chain_at(idx)
	var src: PackedInt32Array = st["src"]
	var turn: PackedByteArray = st["turn"]
	var open := idx < medium._moves.size() and at >= float((medium._moves[idx] as Dictionary)["t0"])
	var turned := PackedByteArray()
	if open:
		turned = (_move_goes(medium._moves[idx]) as Dictionary)["turned"]
	if turned.is_empty():
		turned.resize(TableMedium.DECK_N)
	if not wj.is_empty() and t >= float(wj["end"]):
		# the jumper's wash is gathered: each slot is the card the pile has there
		var plan: Dictionary = wj["plan"]
		var order: Array = plan.get("order", [])
		for slot in TableMedium.DECK_N:
			var c := int(order[slot]) if slot < order.size() else int(plan.get("jumper", slot))
			out[slot] = PI * float((f0[src[c]] ^ turn[c]) ^ int((plan["turned"] as PackedByteArray)[c]))
		return out
	# the weight of the hand-over: the shuffle's pose settles into the rest over this
	var w := 0.0
	if wj.is_empty() and t > te and te < INF:
		w = TableMedium._ease(clampf((t - te) / (TableMedium.SQUARE if jump_s == 0.0 else jump_s * 0.35), 0.0, 1.0))
	for i in TableMedium.DECK_N:
		out[i] = PI * (float(f0[src[i]] ^ turn[i]) + float(turned[i]) * w)
	return out


## The move under way at [param u], or empty in a pause. RUNS, NOT A LOTTERY: a reader does not
## pick a new shuffle for every move - they riffle three times running, cut four times, and then
## leave the deck alone for a few seconds (now and then for a long while) while they talk. So a
## run is one kind at one tempo, and the pause after it is drawn from a long-tailed spread. A wash
## comes at most once, and never first. Moves are made as far as they are needed, in order, from
## their own seeded stream - so the chain is the same however a reading gets to a moment.
func move_at(u: float) -> Dictionary:
	while medium._moves.is_empty() or float((medium._moves[-1] as Dictionary)["t0"]) + float((medium._moves[-1] as Dictionary)["dur"]) \
			+ float((medium._moves[-1] as Dictionary)["pause"]) < u:
		var t0 := 0.15
		var last := ""
		var washed := false
		for m in medium._moves:
			washed = washed or String((m as Dictionary)["kind"]) == "wash"
		if not medium._moves.is_empty():
			var p: Dictionary = medium._moves[-1]
			t0 = float(p["t0"]) + float(p["dur"]) + float(p["pause"])
			last = String(p["kind"])
		# the run's kind: weighted, never the same as the last run, no second wash, no wash first -
		# and a jumper's wash held back until its time ([method _jumper_wash])
		var held_back := medium._wash_held and not washed
		var total := 0.0
		var pool: Array = []
		for k in RUNS:
			if k == last or (k == "wash" and (washed or medium._moves.is_empty() or held_back)):
				continue
			pool.append(k)
			total += float((RUNS[k] as Dictionary)["weight"])
		var pick := medium._move_rng.randf() * total
		var kind := String(pool[0])
		for k in pool:
			pick -= float((RUNS[k] as Dictionary)["weight"])
			if pick <= 0.0:
				kind = String(k)
				break
		# its time: the run after this one would begin past it
		if held_back and not medium._moves.is_empty() and t0 >= medium._wash_from - 6.0:
			kind = "wash"
		var run: Dictionary = RUNS[kind]
		var n := medium._move_rng.randi_range(int(run["n"][0]), int(run["n"][1]))
		var tempo := medium._move_rng.randf_range(float(run["dur"][0]), float(run["dur"][1]))
		for i in n:
			var gap := medium._move_rng.randf_range(float(run["gap"][0]), float(run["gap"][1]))
			if i == n - 1:
				# the pause after a run: a few seconds, or now and then a long linger
				gap = clampf(exp(medium._move_rng.randfn(IDLE_LOG.x, IDLE_LOG.y)), IDLE_RANGE.x, IDLE_RANGE.y)
				if medium._move_rng.randf() < LINGER_CHANCE:
					gap = medium._move_rng.randf_range(9.0, IDLE_RANGE.y)
			var move := {"kind": kind, "t0": t0, "dur": tempo * medium._move_rng.randf_range(0.95, 1.05),
				"pause": gap, "seed": medium._move_rng.randi()}
			if kind == "wash" and medium._wash_held:
				move["dur"] = clampf(medium._wash_until - t0, float(run["dur"][0]), 44.0)
			if kind == "wash":
				move["plan"] = _wash_plan(int(move["seed"]), float(move["dur"]))
			medium._moves.append(move)
			t0 += float(move["dur"]) + gap
		if medium._moves.size() > 400:
			break
	for m in medium._moves:
		var d: Dictionary = m
		if u >= float(d["t0"]) and u < float(d["t0"]) + float(d["dur"]):
			return d
	return {}


## Where a riffle puts deck slot [param i]: the halves interleave, the right half's card on top.
static func _riffle_to(i: int) -> int:
	var half := int(TableMedium.DECK_N * 0.5)
	var left := i < half
	return mini(2 * (i if left else i - half) + (0 if left else 1), TableMedium.DECK_N - 1)


func riffle(i: int, v: float, dur: float, seed: int) -> Transform3D:
	var half := int(TableMedium.DECK_N * 0.5)
	var left := i < half
	var k := i if left else i - half
	var side := -1.0 if left else 1.0
	var j := _riffle_to(i)
	var split_end := 0.5
	var drop0 := 0.55
	var drop1 := dur - 0.6
	var fall := 0.11
	var held_rot := Basis(Vector3(0, 0, 1), side * deg_to_rad(9.0)) * Basis(Vector3.UP, side * deg_to_rad(6.0))
	var held := Transform3D(held_rot, medium._cur_base + Vector3(side * 0.052, 0.016 + (float(k) + 0.5) * TableMedium.DECK_T, 0.004))
	if v < split_end:
		return medium._rest_xf(i).interpolate_with(held, TableMedium._ease(v / split_end))
	var tj := drop0 + (drop1 - drop0) * float(j) / float(TableMedium.DECK_N - 1)
	if v < tj:
		return held
	var messy := _messy(j, seed)
	if v < tj + fall:
		return held.interpolate_with(messy, (v - tj) / fall)
	var sq := clampf((v - drop1 - fall) / maxf(dur - drop1 - fall, 0.05), 0.0, 1.0)
	return messy.interpolate_with(medium._rest_xf(j), TableMedium._ease(sq))


## Where an overhand shuffle puts deck slot [param i], and the packet it is peeled off in (-1: not
## among the held cards, it stays): packets peel off the TOP of the held cards and land in turn on
## the deck, the top packet first, so the held cards' order is reversed packet by packet.
static func _overhand_to(i: int) -> Vector2i:
	var k0 := int(TableMedium.DECK_N * 0.42)
	if i < k0:
		return Vector2i(i, -1)
	var held_n := TableMedium.DECK_N - k0
	var from_top := TableMedium.DECK_N - 1 - i
	var p := mini(OVERHAND_PACKETS - 1, int(float(from_top) * float(OVERHAND_PACKETS) / float(held_n)))
	var lo := int(ceil(float(p) * float(held_n) / float(OVERHAND_PACKETS)))
	var hi := int(ceil(float(p + 1) * float(held_n) / float(OVERHAND_PACKETS)))
	var in_packet := (TableMedium.DECK_N - 1 - lo) - i          # 0 = the packet's top card
	return Vector2i(k0 + lo + (hi - lo - 1 - in_packet), p)


func _overhand(i: int, v: float, dur: float, seed: int) -> Transform3D:
	var k0 := int(TableMedium.DECK_N * 0.42)
	if i < k0:
		return medium._rest_xf(i)
	var packets := OVERHAND_PACKETS
	var lift_end := 0.45
	var casc0 := 0.5
	var casc1 := dur - 0.45
	var held := Transform3D(Basis(Vector3.UP, deg_to_rad(-7.0)),
		medium._cur_base + Vector3(0.07, 0.032 + (float(i - k0) + 0.5) * TableMedium.DECK_T, 0.012))
	if v < lift_end:
		return medium._rest_xf(i).interpolate_with(held, TableMedium._ease(v / lift_end))
	var to := _overhand_to(i)
	var p := to.y
	var j := to.x
	var tp := casc0 + (casc1 - casc0) * float(p) / float(packets)
	var pd := (casc1 - casc0) / float(packets) * 0.85
	if v < tp:
		return held
	var messy := _messy(j, seed)
	if v < tp + pd:
		var e := TableMedium._ease((v - tp) / pd)
		var xf := held.interpolate_with(messy, e)
		xf.origin.y += sin(PI * e) * 0.012
		return xf
	var sq := clampf((v - casc1) / maxf(dur - casc1, 0.05), 0.0, 1.0)
	return messy.interpolate_with(medium._rest_xf(j), TableMedium._ease(sq))


## Where a cut of the move seeded [param rng] (its first draw) is made: the first slot of the packet
## that is lifted off.
static func _cut_split(rng: RandomNumberGenerator) -> int:
	return rng.randi_range(int(TableMedium.DECK_N * 0.3), int(TableMedium.DECK_N * 0.7))


## A CUT, quick enough to be done several times running: the top packet (from a point of the
## move's own) is lifted off and set down beside the deck, the rest is put on top of it, and the
## deck is drawn back to its place. Each cut in a run goes to its own side.
func _cut(i: int, v: float, dur: float, seed: int) -> Transform3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var a := _cut_split(rng)
	var side := -1.0 if rng.randf() < 0.5 else 1.0
	var aside := Vector3(side * rng.randf_range(0.08, 0.095), 0.0, rng.randf_range(-0.012, 0.018))
	var top := i >= a
	# where each card ends: the old top packet underneath, the old bottom on it
	var j := (i - a) if top else (TableMedium.DECK_N - a + i)
	var out := Vector2(0.0, 0.36) * dur          # the top packet goes aside
	var over := Vector2(0.4, 0.74) * dur         # the rest goes on top of it
	var back := Vector2(0.8, 1.0) * dur          # the whole deck back to its place
	var spot := func(slot: int, off: Vector3) -> Transform3D:
		var r := medium._rest_xf(slot)
		r.origin += off
		return r
	if v >= back.x:
		var e := TableMedium._ease((v - back.x) / (back.y - back.x))
		return (spot.call(j, aside) as Transform3D).interpolate_with(medium._rest_xf(j), e)
	if top:
		if v < out.x:
			return medium._rest_xf(i)
		var e := TableMedium._ease(clampf((v - out.x) / (out.y - out.x), 0.0, 1.0))
		var xf := medium._rest_xf(i).interpolate_with(spot.call(j, aside), e)
		xf.origin.y += sin(PI * e) * 0.022
		return xf
	if v < over.x:
		return medium._rest_xf(i)
	var e2 := TableMedium._ease(clampf((v - over.x) / (over.y - over.x), 0.0, 1.0))
	var xf2 := medium._rest_xf(i).interpolate_with(spot.call(j, aside), e2)
	xf2.origin.y += sin(PI * e2) * 0.028
	return xf2


## A WASH, posed from its plan (see [method _wash_plan]): card [param i] at [param v] seconds in -
## where the plan has it, resting on what is under it ([method _wash_rest]), a card's own thickness
## once spread ([constant WASH_T]: a deck mesh stands for three); in the air if it is thrown
## ([method _flight_xf]).
func wash(i: int, v: float, m: Dictionary) -> Transform3D:
	var plan := _wash_fit(m)
	if plan.is_empty():
		return medium._rest_xf(i)
	var fl := _flight_of(plan, i, v)
	if not fl.is_empty():
		return _flight_xf(plan, fl, v)
	var q := _wash_at(plan, i, v)
	var th := lerpf(TableMedium.DECK_T, WASH_T, _wash_spread_at(plan, i, v))
	var r: Vector3 = (_wash_rest_at(plan, v) as Array)[i]
	var b := _tipped(q.w, Vector2(r.y, r.z))
	var rise := _wash_rise(plan, v, i)
	# the jumper, down: over about its long side, face up on what it lies on
	if int(plan.get("jumper", -1)) == i and v >= float((plan["jumper_flight"] as Dictionary)["t1"]):
		b = b * Basis(Vector3(0.0, 0.0, 1.0), PI)
	return Transform3D(b * Basis.from_scale(Vector3(1.0, th / TableMedium.DECK_T, 1.0)), medium._cur_base + Vector3(q.x, r.x + rise, q.z))


## Card [param i]'s track at [param v] seconds into the wash, between the plan's steps: x, z and its
## turn. (Its y is its place in the order the cards lie, [method _wash_rest_at] reads it at a step.)
static func _wash_at(plan: Dictionary, i: int, v: float) -> Vector4:
	var track: PackedVector4Array = (plan["tracks"] as Array)[i]
	var f := clampf(v * WASH_HZ, 0.0, float(track.size() - 1))
	var a := int(floor(f))
	return track[a].lerp(track[mini(a + 1, track.size() - 1)], f - float(a))


## The throw card [param i] is in at [param v] - from the moment it leaves its place until it is
## down - or empty.
static func _flight_of(plan: Dictionary, i: int, v: float) -> Dictionary:
	for f in (plan.get("airborne", {}) as Dictionary).get(i, []):
		var fd: Dictionary = f
		if v > float(fd["t0"]) and v < float(fd["t1"]):
			return fd
	return {}


## Whether card [param i] is off the cloth at [param v]: in the air, or the jumper once picked up.
static func _off_cloth(plan: Dictionary, i: int, v: float) -> bool:
	return not _flight_of(plan, i, v).is_empty() or (int(plan.get("jumper", -1)) == i and v > float(plan["gather"]))


## A THROWN CARD at [param v] seconds into the wash: off its place with a pop, along its way and
## turning, and down onto whatever is where it comes down; a jumper turns over on the way.
func _flight_xf(plan: Dictionary, f: Dictionary, v: float) -> Transform3D:
	var i := int(f["card"])
	var up := bool(f["up"])
	var u := clampf((v - float(f["t0"])) / maxf(float(f["t1"]) - float(f["t0"]), 0.01), 0.0, 1.0)
	if not f.has("r0"):
		f["r0"] = (_wash_rest_at(plan, float(f["t0"])) as Array)[i]
		f["r1"] = (_wash_rest_at(plan, float(f["t1"])) as Array)[i]
	var r0: Vector3 = f["r0"]
	var r1: Vector3 = f["r1"]
	var g := _flight_ground(f, v)
	var y := lerpf(r0.x, r1.x, TableMedium._ease(u)) + float(f["hop"]) * sqrt(maxf(sin(PI * u), 0.0))
	var h: Vector2 = f["axis"]
	var axis := Vector3(h.x, 0.0, h.y)
	var turned: Basis
	if up:
		# over about h, from lying as it lay to lying face up as it comes down ([method wash]): the
		# flat turn, eased off the slope it left and onto the one it lands on
		var flat := Basis(axis, -PI * TableMedium._ease((u - 0.08) / 0.8)) * Basis(Vector3.UP, g.z)
		var off := Quaternion(_tipped(float(f["yaw0"]), Vector2(r0.y, r0.z)) * Basis(Vector3.UP, float(f["yaw0"])).inverse())
		var land := _tipped(float(f["lie"]), Vector2(r1.y, r1.z)) * Basis(Vector3(0.0, 0.0, 1.0), PI)
		var onto := Quaternion(land * (Basis(axis, -PI) * Basis(Vector3.UP, float(f["yaw1"]))).inverse())
		turned = Basis(Quaternion.IDENTITY.slerp(onto, TableMedium._ease((u - 0.8) / 0.2)) * Quaternion.IDENTITY.slerp(off, 1.0 - TableMedium._ease(u / 0.2))) * flat
	else:
		var slope := Vector2(r0.y, r0.z) * (1.0 - TableMedium._ease(u / 0.2)) + Vector2(r1.y, r1.z) * TableMedium._ease((u - 0.8) / 0.2)
		turned = Basis(axis, float(f["wobble"]) * sin(PI * u)) * _tipped(g.z, slope)
	var xf := Transform3D(turned * Basis.from_scale(Vector3(1.0, WASH_T / TableMedium.DECK_T, 1.0)), Vector3(g.x, y, g.y))
	# CLEAR OF WHAT IT PASSES OVER: turning about its middle, an edge would dip into the cloth or a
	# card - so it rides up over that edge, as a card does
	xf.origin.y += _flight_clear(plan, i, v, xf)
	xf.origin += medium._cur_base
	return xf


## How far a thrown card posed at [param xf] (about the deck's place) must rise to be clear of the
## cloth and of every card resting under it at [param v] ([method _wash_rest_at]): its lower face
## against their faces wherever they cross, while it lies within 60 degrees of flat; its lowest
## corner against the highest of them near it, while it is turned further over.
func _flight_clear(plan: Dictionary, i: int, v: float, xf: Transform3D) -> float:
	var b := xf.basis
	var half := Vector3(TableMedium.CARD.x * 0.5, TableMedium.DECK_T * 0.5, TableMedium.CARD.y * 0.5)
	var drop := absf(b.x.y) * half.x + absf(b.y.y) * half.y + absf(b.z.y) * half.z
	var need := TableMedium.CLOTH_TOP + FLOOR_GAP - (xf.origin.y - drop)
	var rests: Array = _wash_rest_at(plan, v)
	var n := b.y.normalized()
	var flat := absf(n.y) > 0.5
	# the lower face: its middle, its normal, and its outline on the cloth
	var face := xf.origin - b.y * (TableMedium.DECK_T * 0.5) * signf(n.y)
	var foot := PackedVector2Array()
	for s in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		var p: Vector3 = face + b.x * (half.x * (s as Vector2).x) + b.z * (half.z * (s as Vector2).y)
		foot.append(Vector2(p.x, p.z))
	var mid := Vector2(xf.origin.x, xf.origin.z)
	var reach := Vector2(TableMedium.CARD.x, TableMedium.CARD.y).length()
	for j in rests.size():
		if j == i or _off_cloth(plan, j, v):
			continue
		var q := _wash_at(plan, j, v)
		var mj := Vector2(q.x, q.z)
		if mj.distance_to(mid) > reach:
			continue
		var r: Vector3 = rests[j]
		var g := Vector2(r.y, r.z)
		var top := lerpf(TableMedium.DECK_T, WASH_T, _wash_spread_at(plan, j, v)) * 0.5 + STACK_GAP
		var rise := _wash_rise(plan, v, j)
		if not flat:
			need = maxf(need, r.x + rise + g.length() * reach * 0.5 + top - (xf.origin.y - drop))
			continue
		for piece in Geometry2D.intersect_polygons(foot, _card_foot(mj, q.w, g)):
			for p: Vector2 in piece:
				var low := face.y - (n.x * (p.x - face.x) + n.z * (p.y - face.z)) / n.y
				need = maxf(need, r.x + rise + g.dot(p - mj) + top - low)
	return maxf(need, 0.0)


## A card turned [param yaw] about the vertical and tipped to lie on a plane rising [param slope]
## (meters per meter across x and z): its long and short sides follow the plane, its face is square to it.
static func _tipped(yaw: float, slope: Vector2) -> Basis:
	var flat := Basis(Vector3.UP, yaw)
	if slope == Vector2.ZERO:
		return flat
	var x := flat.x + Vector3.UP * slope.dot(Vector2(flat.x.x, flat.x.z))
	var z := flat.z + Vector3.UP * slope.dot(Vector2(flat.z.x, flat.z.z))
	var up := z.cross(x).normalized()
	# THE LONG SIDE KEPT TRUE to the plane's own line under it, the short side squared to it: the
	# card's corners on a steep slope (a card slid up onto the gathered deck tips 20 degrees) stray
	# least from where its rest was reckoned, its long side's arm being the longer
	z = z.normalized()
	return Basis(up.cross(z).normalized(), up, z)


## CARDS IN A WASH REST ON ONE ANOTHER (the user: they rest "upon each other with a gentle tilt").
## Every card - in the deck, spread, or gathered in the pile - from the bottom of the order the plan
## has them lying in, up, is a rigid card resting on whatever is under it: the cloth beneath its
## corners and the faces of the cards under it, wherever they cross it ([method _rest_on]). So it
## tips: on a card at one end, on the cloth at the other, and over the deck's edge as it slides off
## it; and a card swept onto the pile rides up onto it rather than through it. A card is its own
## thickness (a deck slot's in the deck and the pile, [constant WASH_T] spread); deck slots lie
## flush, the bottom one sunk into the cloth as the squared deck is, spread cards a hair apart and a
## hair over it.
##
## THE CORNERS POSED DRAW IN. A card tipped twenty degrees pulls its corners in along the slope, and
## the flat yaw rectangle the rest is reckoned on sits outside the mesh. Two deck slots squared on
## the pile, a fraction out of parallel, cleared that rectangle and still passed through each other
## by a tenth of a millimeter (one frame of wash-check). The rest itself stays the flat one - it is
## the lowest plane, and what the step gate measures. A steep card is then lifted, in
## [member _rest_lifts], by however much its posed corners would sink into the cloth or a card under
## it. Under a few degrees the draw-in is less than the gates allow, and nothing is lifted.
##
## AT THE MOMENT ITSELF, [param v] seconds into the wash, the cards where their tracks have them
## between the plan's steps - two steps' rests blended pass a card sliding onto another through its
## edge for a frame - in the order of the step that ends the moment (a pair parting keeps its order
## a step after it parts, so a pair touching at the moment is in the order it touches in). Kept for
## the frames that ask again. Each card `Vector3(height of its middle, slope
## across x, slope across z)`; a card in the air rests on nothing and nothing on it. Under the palm,
## as the cards fan out, each tilt is calmed ([constant CALM_HZ]); [param bare] is the rest without.
func _wash_rest_at(plan: Dictionary, v: float, bare := false) -> Array:
	if not is_same(plan, _rest_plan):
		_rest_plan = plan
		_rest_steps = {}
		_rest_lifts = {}
	var key := int(round(v * 4000.0))
	key = -key - 1 if bare else key
	if _rest_steps.has(key):
		return _rest_steps[key]
	if _rest_steps.size() > 40:
		_rest_steps = {}
		_rest_lifts = {}
	# THE FAN-OUT'S TILTS, calmed: each card's bare tilt averaged over a window on a fixed grid (so
	# the frames after reuse it), between the two grid points round the moment
	var calm := 0.0 if bare or not medium.wash_calm else \
		1.0 - clampf((v - float((plan["mix"] as Vector2).x)) / CALM_SETTLE, 0.0, 1.0)
	var calmed: Array = []
	if calm > 0.0:
		var g := v * CALM_HZ
		var g0 := int(floor(g))
		var bares: Array = []
		for k in range(g0 - CALM_REACH, g0 + CALM_REACH + 2):
			bares.append(_wash_rest_at(plan, float(k) / CALM_HZ, true))
		for i in (plan["tracks"] as Array).size():
			var a := Vector2.ZERO
			var b := Vector2.ZERO
			for k in CALM_REACH * 2 + 1:
				var r0: Vector3 = (bares[k] as Array)[i]
				var r1: Vector3 = (bares[k + 1] as Array)[i]
				a += Vector2(r0.y, r0.z)
				b += Vector2(r1.y, r1.z)
			calmed.append(a.lerp(b, g - float(g0)) / float(CALM_REACH * 2 + 1))
	var tracks: Array = plan["tracks"]
	var n := tracks.size()
	var last := (tracks[0] as PackedVector4Array).size() - 1
	var f := clampf(v * WASH_HZ, 0.0, float(last))
	var b := mini(int(ceil(f - 0.0001)), last)
	var q: Array = []
	var at: Array = []
	var order: Array = []
	for i in n:
		at.append(_wash_at(plan, i, v))
		q.append((tracks[i] as PackedVector4Array)[b].y)
		order.append(i)
	order.sort_custom(func(x: int, y: int) -> bool:
		return float(q[x]) < float(q[y]) or (float(q[x]) == float(q[y]) and x < y))
	var out: Array = []
	out.resize(n)
	var under: Array = []      # [corners, middle, rest, thickness, spread, turn] of every card resting so far
	var reach := Vector2(TableMedium.CARD.x, TableMedium.CARD.y).length()
	for i in order:
		var qi: Vector4 = at[i]
		if _off_cloth(plan, i, v):
			out[i] = Vector3(WASH_FLOOR, 0.0, 0.0)
			continue
		var s := _wash_spread_at(plan, i, v)
		var th := lerpf(TableMedium.DECK_T, WASH_T, s)
		var low := lerpf(0.0, TableMedium.CLOTH_TOP + FLOOR_GAP, s) + th * 0.5
		var mid := Vector2(qi.x, qi.z)
		var corners := _card_corners(mid, qi.w)
		var pts := PackedVector2Array()
		var hs := PackedFloat32Array()
		for c in corners:
			pts.append(c - mid)
			hs.append(low)
		for u in under:
			var umid: Vector2 = u[1]
			if umid.distance_squared_to(mid) > reach * reach:
				continue
			var ur: Vector3 = u[2]
			var ug := Vector2(ur.y, ur.z)
			var lift := float(u[3]) * 0.5 + STACK_GAP * maxf(s, float(u[4])) + th * 0.5
			# SQUARED ONE ON THE OTHER (the deck, the pile): held up at its own corners - above the face
			# under it over the whole card, so above it wherever they cross
			if umid.distance_squared_to(mid) < 0.006 * 0.006 and absf(wrapf(qi.w - float(u[5]), -PI * 0.5, PI * 0.5)) < 0.12:
				for c in 4:
					hs[c] = maxf(hs[c], ur.x + ug.dot(corners[c] - umid) + lift)
				continue
			for piece in Geometry2D.intersect_polygons(corners, u[0]):
				for p in piece:
					pts.append(p - mid)
					hs.append(ur.x + ug.dot(p - umid) + lift)
		var rest := Vector3(hs[0], 0.0, 0.0) if pts.size() == 4 and hs[0] == hs[1] and hs[1] == hs[2] and hs[2] == hs[3] \
			else _rest_on(pts, hs)
		if calm > 0.0:
			# its calmed tilt, set down on the highest of its supports at that tilt
			var gc := Vector2(rest.y, rest.z).lerp(calmed[i], calm)
			var h := -INF
			for k in pts.size():
				h = maxf(h, hs[k] - gc.dot(pts[k]))
			rest = Vector3(h, gc.x, gc.y)
		out[i] = rest
		under.append([corners, mid, rest, th, s, qi.w])
	# A STEEP CARD'S MESH draws in off the flat rectangle just rested ([method _card_foot]). Lift it
	# so those corners stay above the cloth and above every card under them. Shallow cards skip it.
	if not bare:
		var lifts := PackedFloat32Array()
		lifts.resize(n)
		var feet: Array = []
		feet.resize(n)
		for i in order:
			if _off_cloth(plan, i, v):
				continue
			var base: Vector3 = out[i]
			var slope := Vector2(base.y, base.z)
			var qi: Vector4 = at[i]
			var mid := Vector2(qi.x, qi.z)
			var s := _wash_spread_at(plan, i, v)
			var th := lerpf(TableMedium.DECK_T, WASH_T, s)
			var foot := _card_foot(mid, qi.w, slope)
			feet[i] = foot
			if _foot_flat(slope):
				continue
			var low := lerpf(0.0, TableMedium.CLOTH_TOP + FLOOR_GAP, s) + th * 0.5
			var extra := 0.0
			for c in foot:
				extra = maxf(extra, low - (base.x + slope.dot(c - mid)))
			for j in order:
				if j == i:
					break
				var fj: Variant = feet[j]
				if fj == null:
					continue
				var qj: Vector4 = at[j]
				var mj := Vector2(qj.x, qj.z)
				if mj.distance_squared_to(mid) > reach * reach:
					continue
				var bj: Vector3 = out[j]
				var sj := _wash_spread_at(plan, j, v)
				var gap_h := lerpf(TableMedium.DECK_T, WASH_T, sj) * 0.5 + STACK_GAP * maxf(s, sj) + th * 0.5
				var ug := Vector2(bj.y, bj.z)
				for piece in Geometry2D.intersect_polygons(foot, fj):
					for p in piece:
						var need: float = bj.x + lifts[j] + ug.dot(p - mj) + gap_h
						extra = maxf(extra, need - (base.x + slope.dot(p - mid)))
			lifts[i] = maxf(extra, 0.0)
		_rest_lifts[key] = lifts
	_rest_steps[key] = out
	return out


## [method _wash_rest_at] at the plan's step [param k].
func _wash_rest(plan: Dictionary, k: int) -> Array:
	return _wash_rest_at(plan, float(k) / WASH_HZ)


## How far card [param i] is lifted at [param v] so its posed corners clear ([member _rest_lifts]).
## The rest itself stays the flat plane. [method _wash_rest_at] fills the lift; ask it first.
func _wash_rise(plan: Dictionary, v: float, i: int) -> float:
	var key := int(round(v * 4000.0))
	var lifts: Variant = _rest_lifts.get(key, null)
	if lifts == null:
		return 0.0
	return (lifts as PackedFloat32Array)[i]


## A card's four corners on the cloth, its middle at [param mid], turned [param yaw].
static func _card_corners(mid: Vector2, yaw: float) -> PackedVector2Array:
	var ax := Vector2(cos(yaw), -sin(yaw)) * TableMedium.CARD.x * 0.5
	var az := Vector2(sin(yaw), cos(yaw)) * TableMedium.CARD.y * 0.5
	return PackedVector2Array([mid - ax - az, mid + ax - az, mid + ax + az, mid - ax + az])


## Under this steepness (about three degrees) a tipped corner draws in by less than the thickness
## the wash gates allow, and [method _card_foot] keeps the flat rectangle.
static func _foot_flat(slope: Vector2) -> bool:
	return slope.length_squared() < 0.0025


## [method _card_corners] as [method _tipped] poses them: drawn in along [param slope], so a rest
## reckoned on them is a rest of the mesh. Shallow tilts stay the flat rectangle ([method _foot_flat]).
static func _card_foot(mid: Vector2, yaw: float, slope: Vector2) -> PackedVector2Array:
	if _foot_flat(slope):
		return _card_corners(mid, yaw)
	var b := _tipped(yaw, slope)
	var out := PackedVector2Array()
	for sv in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		var s: Vector2 = sv
		var p := b.x * (TableMedium.CARD.x * 0.5 * s.x) + b.z * (TableMedium.CARD.y * 0.5 * s.y)
		out.append(mid + Vector2(p.x, p.z))
	return out


## THE LOWEST A RIGID CARD CAN LIE on supports [param hs] high at [param pts] (about its middle):
## the plane above every one of them that is lowest at the middle - which is where a card settles,
## its weight being at its middle. It is the face, above the middle, of the hull over the
## supports, walked to from the highest of them: tip from that point toward the middle until a
## second holds it, swing about those two until a third does, and over the edge the middle lies
## beyond while it lies outside the three. Every step moves the plane only as far as the first
## support it meets, so no support ever ends up above it. `Vector3(height at the middle, slope
## across x, slope across z)`.
static func _rest_on(pts: PackedVector2Array, hs: PackedFloat32Array) -> Vector3:
	var n := pts.size()
	var top := 0
	for k in n:
		if hs[k] > hs[top]:
			top = k
	var h := hs[top]
	var g := Vector2.ZERO
	if pts[top].length() < 1e-7:
		return Vector3(h, 0.0, 0.0)
	# tip about the highest support, lowering the middle, until a second meets the plane
	var e := pts[top].normalized()
	var t := INF
	var second := -1
	for k in n:
		var de := e.dot(pts[top] - pts[k])
		if de > 1e-7 and (hs[top] - hs[k]) / de < t:
			t = (hs[top] - hs[k]) / de
			second = k
	if second < 0:
		return Vector3(h, 0.0, 0.0)
	g = e * t
	h = hs[top] - g.dot(pts[top])
	var held: Array = [top, second]
	for it in 12:
		if held.size() == 2:
			var pa: Vector2 = pts[held[0]]
			var dir: Vector2 = pts[held[1]] - pa
			if dir.length() < 1e-7:
				break
			var across := Vector2(-dir.y, dir.x).normalized()
			var side := across.dot(-pa)
			if absf(side) < 1e-7:
				break
			if side < 0.0:
				across = -across
			# swing about the two, lowering the middle's side, until a third meets the plane
			var s := INF
			var third := -1
			for k in n:
				var dn := across.dot(pts[k] - pa)
				if dn > 1e-7 and k != held[0] and k != held[1]:
					var sk := maxf(h + g.dot(pts[k]) - hs[k], 0.0) / dn
					if sk < s:
						s = sk
						third = k
			if third < 0:
				break
			g -= across * s
			h += s * across.dot(pa)
			held.append(third)
		# three hold it: settled if the middle lies among them, else over the edge it lies beyond
		var p0: Vector2 = pts[held[0]]
		var p1: Vector2 = pts[held[1]]
		var p2: Vector2 = pts[held[2]]
		var area := (p1 - p0).cross(p2 - p0)
		if absf(area) < 1e-10:
			held.remove_at(2)
			break
		var l0 := p1.cross(p2) / area
		var l1 := p2.cross(p0) / area
		var l2 := p0.cross(p1) / area
		var least := minf(l0, minf(l1, l2))
		if least >= -1e-6:
			break
		held.remove_at(0 if l0 == least else (1 if l1 == least else 2))
	return Vector3(h, g.x, g.y)


## A wash's plan for the time it has: the whole of it, or - when the first card comes before it
## would finish - one that mixes for less and gathers in time. The spreading and the hands are the
## same up to there (their own dice), so it is the same wash, cut short; without it the spread
## went back into the deck in [constant SQUARE]. With too little room to spread, mix and gather at
## all, there is no wash: the deck waits, squared, for the first card (empty). When the first card
## is a jumper that comes while this wash is mixing, the wash runs on into it ([method _jumper_plan]).
func _wash_fit(m: Dictionary) -> Dictionary:
	var jp := _jumper_plan(m)
	if not jp.is_empty():
		return jp
	var room := medium._shuffle_room - float(m["t0"])
	if room >= float(m["dur"]) - 0.05:
		return m["plan"]
	if room < WASH_ROOM:
		return {}
	var d := snappedf(room, 0.25)
	if float(m.get("cut_dur", -1.0)) != d:
		m["cut_dur"] = d
		m["cut"] = _wash_plan(int(m["seed"]), d, m["plan"])
	return m["cut"]


## A JUMPER OUT OF A WASH: when the first card is a jumper ([member _jump_room] into the shuffle, its
## action at [member _jump_scale]) and wash [param m] is mixing as it comes, the wash planned on
## through it - mixing until the jumper is thrown [constant JUMP_EJECT] into its action, still while
## it lies there, gathered once it is up ([constant JUMP_RISE]). Empty for any other wash, one only
## just spread ([constant JUMP_MIX]) or already gathering, or one with no card it could throw.
func _jumper_plan(m: Dictionary) -> Dictionary:
	if medium._jump_room < 0.0 or String(m.get("kind", "")) != "wash" or not m.has("plan"):
		return {}
	var into := medium._jump_room - float(m["t0"])
	var mix: Vector2 = (m["plan"] as Dictionary)["mix"]
	var s := maxf(medium._jump_scale, 0.05)
	var at := into + JUMP_EJECT * s
	if into < mix.x + JUMP_MIX or at > mix.y:
		return {}
	var key := "%.3f|%.3f" % [into, s]
	if String(m.get("jump_key", "")) != key:
		m["jump_key"] = key
		var pick := into + TableMedium.JUMP_RISE * s
		var plan := _wash_plan(int(m["seed"]), pick + JUMP_GATHER + 0.6, m["plan"],
			{"at": at, "pick": pick, "reversed": medium._reversed(0)})
		m["jump"] = plan if int(plan["jumper"]) >= 0 else {}
	return m["jump"]


## THE JUMPER'S WASH as the table poses it, from the shuffle's start [param ts]: the wash move, its
## plan, the card thrown, and when (show time) the wash began, the card leaves it and lands, and the
## wash ends - or empty when the jumper does not come out of a wash.
func wash_jump(ts: float) -> Dictionary:
	if medium._jump_room < 0.0:
		return {}
	var m := move_at(medium._jump_room - 0.001)
	if m.is_empty():
		return {}
	var plan := _jumper_plan(m)
	if plan.is_empty():
		return {}
	var f: Dictionary = plan["jumper_flight"]
	var at := ts + float(m["t0"])
	return {"m": m, "plan": plan, "card": int(plan["jumper"]), "base": at, "eject": at + float(f["t0"]),
		"land": at + float(f["t1"]), "end": at + float(plan["dur"])}


## How spread out card [param i] is at [param v]: 0 a deck slot's thickness, flush in the deck, 1 a
## card's own on the cloth - thinned as the deck is flattened ([constant WASH_FLATTEN]), thickened
## as it lands in the pile.
func _wash_spread_at(plan: Dictionary, i: int, v: float) -> float:
	var t_out := float((plan["out"] as PackedFloat32Array)[i])
	var t_in := float((plan["in"] as PackedFloat32Array)[i])
	return clampf((v - t_out) / WASH_FLATTEN, 0.0, 1.0) * (1.0 - clampf((v - t_in) / 0.6, 0.0, 1.0))


## [param at] (a card's middle, about the deck's place) moved out from anything standing on the
## table, by the least that keeps a card's whole reach clear of it; unchanged when clear.
func _clear_of_standing(at: Vector2) -> Vector2:
	var reach := Vector2(TableMedium.CARD.x, TableMedium.CARD.y).length() * 0.5 + 0.01
	var off := Vector2(medium._plan.mid.x, medium._plan.mid.z)
	var p := at
	for i in medium._standing.size():
		var c: Vector2 = medium._standing_c[i]
		var d := (p + off).distance_to(c)
		var need := medium._standing_r[i] + reach
		if d < need:
			var away := ((p + off) - c).normalized() if d > 1e-6 else Vector2(0.0, 1.0)
			p += away * (need - d)
	return p


## Whether a card's reach swept from [param a] to [param b] (about the deck's place) keeps clear of
## everything standing on the table.
func _path_clear(a: Vector2, b: Vector2) -> bool:
	var reach := Vector2(TableMedium.CARD.x, TableMedium.CARD.y).length() * 0.5
	var off := Vector2(medium._plan.mid.x, medium._plan.mid.z)
	for i in medium._standing.size():
		var c: Vector2 = medium._standing_c[i]
		var q := Geometry2D.get_closest_point_to_segment(c, a + off, b + off)
		if q.distance_to(c) < medium._standing_r[i] + reach:
			return false
	return true


## NOTHING PASSES THROUGH WHAT STANDS ON THE TABLE. A card going from [param from] to
## [param want] (about the deck's place), turned [param yaw], is moved there a few millimeters at a
## time, and each time it has run into something it is pushed back out - away from that thing's
## middle, the way it came - so it slides along it, and never jumps through to its far side. Wedged
## between two things, where a push out of one is a push into the other, it stays where it was.
func _card_clear(from: Vector2, want: Vector2, yaw: float) -> Vector2:
	if medium._standing.is_empty() or not _collide:
		return want
	var off := Vector2(medium._plan.mid.x, medium._plan.mid.z)
	var reach := Vector2(TableMedium.CARD.x, TableMedium.CARD.y).length() * 0.5
	var travel := from.distance_to(want)
	var near := false
	for i in medium._standing.size():
		if (want + off).distance_to(medium._standing_c[i]) < medium._standing_r[i] + reach + travel + 0.01:
			near = true
			break
	if not near:
		return want
	var steps := maxi(1, ceili(travel / 0.006))
	var p := from
	for s in steps:
		p += (want - from) / float(steps)
		for i in medium._standing.size():
			var c: Vector2 = medium._standing_c[i]
			if (p + off).distance_to(c) > medium._standing_r[i] + reach:
				continue
			p += _push_out(_card_poly(p + off, yaw), medium._standing[i], (p + off) - c)
	# clear of every one at once
	for round in 4:
		var clear := true
		for i in medium._standing.size():
			var c: Vector2 = medium._standing_c[i]
			if (p + off).distance_to(c) > medium._standing_r[i] + reach:
				continue
			var push := _push_out(_card_poly(p + off, yaw), medium._standing[i], (p + off) - c)
			if push != Vector2.ZERO:
				p += push
				clear = false
		if clear:
			return p
	return from


## A card lying at [param at] turned [param yaw]: its four corners (x by z).
static func _card_poly(at: Vector2, yaw: float) -> PackedVector2Array:
	var ax := Vector2(cos(yaw), -sin(yaw)) * TableMedium.CARD.x * 0.5
	var az := Vector2(sin(yaw), cos(yaw)) * TableMedium.CARD.y * 0.5
	return PackedVector2Array([at - ax - az, at + ax - az, at + ax + az, at - ax + az])


## How far to move convex [param a] along [param dir] so it no longer overlaps convex [param b] -
## the least such move, by separating axes; along the shortest way out when [param dir] is
## nothing. Zero when they do not overlap.
static func _push_out(a: PackedVector2Array, b: PackedVector2Array, dir: Vector2) -> Vector2:
	var d := dir.normalized() if dir.length() > 1e-6 else Vector2.ZERO
	var need := INF
	var least := INF
	var least_ax := Vector2.ZERO
	for poly in [a, b]:
		var p: PackedVector2Array = poly
		for i in p.size():
			var e := p[(i + 1) % p.size()] - p[i]
			if e.length_squared() < 1e-12:
				continue
			var ax := Vector2(-e.y, e.x).normalized()
			var ra := TableMedium._span(a, ax)
			var rb := TableMedium._span(b, ax)
			var o := minf(ra.y, rb.y) - maxf(ra.x, rb.x)
			if o <= 0.0:
				return Vector2.ZERO
			if o < least:
				least = o
				least_ax = ax * (1.0 if ra.x + ra.y > rb.x + rb.y else -1.0)
			var k := d.dot(ax)
			if absf(k) > 1e-4:
				# moving a along d by s shifts it by s * k on this axis: past b's far side, or its near one
				var sep := (rb.y - ra.x) / k if k > 0.0 else (rb.x - ra.y) / k
				if sep >= 0.0:
					need = minf(need, sep)
	if need < INF:
		return d * (need + 0.0004)
	return least_ax * (least + 0.0004)


## Whether two cards lying on the table overlap: their turned rectangles, by separating axes.
static func _cards_overlap(a: Vector2, ya: float, b: Vector2, yb: float) -> bool:
	var d := b - a
	var far := 2.0 * Vector2(TableMedium.CARD.x, TableMedium.CARD.y).length() * 0.5
	if d.length_squared() > far * far:
		return false
	if d.length_squared() < TableMedium.CARD.x * TableMedium.CARD.x:
		return true
	# each card's two axes in turn (written out: a wash asks this some hundred thousand times)
	var a0 := Vector2(cos(ya), -sin(ya))
	var a1 := Vector2(sin(ya), cos(ya))
	var b0 := Vector2(cos(yb), -sin(yb))
	var b1 := Vector2(sin(yb), cos(yb))
	return not (_parted(d, a0, a0, a1, b0, b1) or _parted(d, a1, a0, a1, b0, b1)
		or _parted(d, b0, a0, a1, b0, b1) or _parted(d, b1, a0, a1, b0, b1))


## Whether two cards [param d] apart, turned to axes [param a0] [param a1] and [param b0]
## [param b1], are parted along [param v]: their reaches along it fall short of the gap.
static func _parted(d: Vector2, v: Vector2, a0: Vector2, a1: Vector2, b0: Vector2, b1: Vector2) -> bool:
	var h := TableMedium.CARD * 0.5
	var ra := h.x * absf(a0.dot(v)) + h.y * absf(a1.dot(v))
	var rb := h.x * absf(b0.dot(v)) + h.y * absf(b1.dot(v))
	return absf(d.dot(v)) > ra + rb


## THE WASH, planned once and sampled at [constant WASH_HZ] - because it is a SIMULATION, not a
## pose: two flat palms work the cloth and drag the cards under them along, and a pose that is a
## function of time alone cannot remember where a palm left a card. Planned from the move's seed,
## so it is the same every time it is posed.
##
##   out      the deck is pushed out across the cloth, top cards first (~2 s)
##   mix      most of the wash: the palms scrub back and forth across the spread, swirl wide and
##            fetch strays back through the middle ([method _wash_gesture]); a card a palm holds
##            goes its way ([method _wash_palm]), slides on when it lets go, and drags and turns
##            every card it passes over ([method _wash_drag]); a card struck hard is thrown out of
##            the spread, face down ([method _eject])
##   gather   six to eight sweeps, each taking the next share of the cards by direction, onto the
##            pile - some missed and fetched by a later one
##   square   the pile is squared into the deck, in the order it lies
##
## A JUMPER'S WASH ([param jump]: `{at, pick, reversed}`, seconds into the wash): the mixing stops at
## `at` and the jumper is thrown - over, face up, clear of every card - and lies there, the others
## sliding on round it, until it is picked up at `pick`; then the hands gather the rest. It leaves
## the deck: `jumper` names its card, -1 when no card could be thrown anywhere it may land.
##
## THE ORDER CHANGES, NEVER THROUGH A CARD: two cards that come to overlap lie the way they met -
## the one sliding in goes on top (never over a card already above it: no stacking loops) - and
## keep that order while they touch; once apart, their next meeting decides again. Each track is
## per card, x / z about the deck's place, y its place in the order the cards lie (what
## [method _wash_rest] rests them in, bottom up), w the card's turn; `flights` are the throws
## ([method _flight_xf]).
func _wash_plan(seed: int, dur: float, base: Dictionary = {}, jump: Dictionary = {}) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed, "wash"])
	var n := TableMedium.DECK_N
	var steps := int(ceil(dur * WASH_HZ)) + 1
	var dt := 1.0 / WASH_HZ
	var out_end := minf(2.4, dur * 0.2)
	var square := 0.6
	# MANY SMALL SWEEPS: the pile is a few cards at a time, gathered one after another - never the
	# whole spread arriving at once
	var swipes := rng.randi_range(6, 8)
	var gather := clampf(dur * 0.24, 4.0, 7.0)
	var mix_end := maxf(out_end, dur - square - gather)
	var gather_t0 := mix_end
	var jumping := not jump.is_empty()
	if jumping:
		mix_end = float(jump["at"])
		gather_t0 = maxf(float(jump["pick"]), mix_end)
		gather = maxf(dur - square - gather_t0, 1.0)
	# WIDE: the cards go well out across the cloth, a few of them a long way
	var rx := rng.randf_range(0.24, 0.29)
	var rz := rng.randf_range(0.12, 0.15)
	var pos := PackedVector2Array()
	var yaw := PackedFloat32Array()
	var start := PackedVector2Array()
	var aim := PackedVector2Array()
	var t_out := PackedFloat32Array()
	for i in n:
		var jit: Vector3 = medium._plan.slot_jit[i] if i < medium._plan.slot_jit.size() else Vector3.ZERO
		start.append(Vector2(jit.x, jit.y))
		# out to somewhere a card can get to: by a way clear of everything standing on the table (a
		# few tries, then the nearest spot clear of them)
		var target := Vector2.ZERO
		for attempt in 6:
			var r := sqrt(rng.randf()) * 0.85
			if rng.randf() < 0.18:
				r = rng.randf_range(0.95, 1.3)    # flung out further than the rest
			var ang := rng.randf() * TAU
			target = Vector2(cos(ang) * rx * r, sin(ang) * rz * r - 0.01)
			if _path_clear(Vector2(jit.x, jit.y), target):
				break
		aim.append(_clear_of_standing(target))
		pos.append(Vector2(jit.x, jit.y))
		yaw.append(jit.z)
		t_out.append(float(n - 1 - i) / float(n) * 0.9)
	var spin0 := PackedFloat32Array()
	for i in n:
		spin0.append(rng.randf_range(-1.1, 1.1))
	var was := pos.duplicate()             # where each card was at the step before, and its turn
	var was_yaw := yaw.duplicate()
	# HOW EACH CARD IS MOVING while it slides (x / z a second, and its turn a second), how hard a palm
	# held it at the last step, and whether a sweep of the gather moves it instead (or it lies in the
	# pile)
	var vel := PackedVector2Array()
	var spin := PackedFloat32Array()
	var held := PackedFloat32Array()
	var kin := PackedByteArray()
	vel.resize(n)
	spin.resize(n)
	held.resize(n)
	kin.resize(n)
	var hands := _wash_hands(seed, out_end, rx, rz)
	# the sweeps, one after another across the gather
	var sweep_len := gather / float(swipes)
	var caught := PackedInt32Array()       # the sweep that brings each card in
	caught.resize(n)
	# plain Arrays while they grow: appending to `tracks[i] as PackedVector4Array` appends to a COPY
	var tracks: Array = []
	for i in n:
		tracks.append([])
	var t_in := PackedFloat32Array()       # when a card is in the pile for good
	t_in.resize(n)
	var from_p := PackedVector2Array()     # a sweep under way: where the card was, where it goes
	var to_p := PackedVector2Array()
	from_p.resize(n)
	to_p.resize(n)
	var from_yaw := PackedFloat32Array()
	var to_yaw := PackedFloat32Array()
	from_yaw.resize(n)
	to_yaw.resize(n)
	var begun := {}
	var land_order: Array = []
	var planned_sweeps := false
	# who lies on whom: pair (i * 64 + j, i < j) -> +1 i on top, -1 j on top, for pairs that overlap
	var rel := {}
	var under: Array = []                  # card -> the cards it lies directly on
	for i in n:
		under.append([])
	var over: Array = []                   # card -> the cards lying on it, at the step before
	for i in n:
		over.append([])
	var layer := PackedInt32Array()
	layer.resize(n)
	var moved := PackedFloat32Array()
	moved.resize(n)
	var stirred := PackedByteArray()       # moved or turned this step: only then can it meet or part
	stirred.resize(n)
	var restacked := true                  # who lies on whom changed this step
	var parted := {}                       # pairs a step apart, keeping their order that step
	# THE THROWS: every flight, the one each card is in at this step (-1 on the cloth), the jumper's
	# card once it is picked up (out of the wash for good), and the hard blows of late (one of them
	# throws the jumper)
	var flights: Array = []
	var flying := PackedInt32Array()
	flying.resize(n)
	var landed := PackedByteArray()
	landed.resize(n)
	var taken := PackedByteArray()
	taken.resize(n)
	var jumper := -1
	var jumper_flight := {}
	var tried := false
	var blown: Array = []                  # [t, card, impact, the blow's way]
	# THE SAME WASH, CUT SHORT ([param base], the whole of it): up to where this one stops mixing, the
	# spreading and the palms are the same, so its tracks and throws are copied rather than made
	# again, and the cards - where they lay, how they were sliding, and who on whom - are taken up
	# from there
	var s_from := 0
	if not base.is_empty() and is_equal_approx(float((base["mix"] as Vector2).x), out_end) \
			and mix_end <= float((base["mix"] as Vector2).y):
		s_from = clampi(int(ceil(mix_end * WASH_HZ)), 2, ((base["tracks"] as Array)[0] as PackedVector4Array).size() - 1)
		for f in base.get("flights", []):
			if float((f as Dictionary)["t0"]) < float(s_from) * dt:
				flights.append(_flight_copy(f as Dictionary))
		var t_prev := float(s_from - 1) * dt
		for i in n:
			var tr: PackedVector4Array = (base["tracks"] as Array)[i]
			var copied: Array = []
			for st in s_from:
				copied.append(tr[st])
			tracks[i] = copied
			var q: Vector4 = tr[s_from - 1]
			var q0: Vector4 = tr[s_from - 2]
			pos[i] = Vector2(q.x, q.z)
			was[i] = pos[i]
			yaw[i] = q.w
			was_yaw[i] = q.w
			vel[i] = Vector2(q.x - q0.x, q.z - q0.z) * WASH_HZ
			spin[i] = (q.w - q0.w) * WASH_HZ
		for i in n:
			if _in_flight(flights, i, t_prev):
				vel[i] = Vector2.ZERO
				spin[i] = 0.0
				continue
			for j in range(i + 1, n):
				if not _in_flight(flights, j, t_prev) and _cards_overlap(pos[i], yaw[i], pos[j], yaw[j]):
					var yi := ((base["tracks"] as Array)[i] as PackedVector4Array)[s_from - 1].y
					var yj := ((base["tracks"] as Array)[j] as PackedVector4Array)[s_from - 1].y
					rel[i * 64 + j] = 1 if yi > yj else -1
					(under[i if yi > yj else j] as Array).append(j if yi > yj else i)
		for i in n:
			for j in under[i]:
				(over[int(j)] as Array).append(i)
	var thrown := flights.size()
	var last_pos := pos.duplicate()        # where each card was at the step before (for meetings between steps)
	var last_yaw := yaw.duplicate()
	for step in range(s_from, steps):
		medium._breathe()
		var t := float(step) * dt
		last_pos = pos.duplicate()
		last_yaw = yaw.duplicate()
		# WHO IS IN THE AIR: a card from the moment it is thrown until it is down - and, the step it
		# comes down, where its flight ends, on top of whatever it comes down on
		flying.fill(-1)
		landed.fill(0)
		for fi in flights.size():
			var f: Dictionary = flights[fi]
			if t > float(f["t0"]) and t < float(f["t1"]):
				flying[int(f["card"])] = fi
			elif t >= float(f["t1"]) and t - dt < float(f["t1"]):
				var c := int(f["card"])
				landed[c] = 1
				pos[c] = f["to"]
				yaw[c] = float(f["lie"])
				vel[c] = Vector2.ZERO
				spin[c] = 0.0
		# THE JUMPER, DOWN, lies still where it fell - on top of anything - until it is picked up
		var lying := jumper if jumper >= 0 and t >= float(jumper_flight["t1"]) and t < gather_t0 else -1
		if jumper >= 0 and t >= gather_t0:
			taken[jumper] = 1
		if t < out_end:
			# OUT: the palm comes down on the deck and it flattens ([constant WASH_FLATTEN]); then each
			# card slides from it to its place on the cloth, turning as it goes
			kin.fill(1)
			for i in n:
				var e := TableMedium._ease(clampf((t - WASH_FLATTEN * 0.5 - t_out[i]) / minf(1.1, out_end * 0.4), 0.0, 1.0))
				pos[i] = start[i].lerp(aim[i], e)
				yaw[i] = (medium._plan.slot_jit[i] as Vector3).z + spin0[i] * e if i < medium._plan.slot_jit.size() else spin0[i] * e
		elif t < gather_t0:
			# MIX: the cloth slows what slides, cards drag what they lie on, the palms bring what they
			# press to their speed (last, so what a palm holds goes its way), and every card moves.
			# Once the jumper is thrown the palms are still, and what slides runs on and stops.
			kin.fill(0)
			for i in n:
				if flying[i] >= 0 or taken[i] == 1 or i == lying:
					kin[i] = 1
			_wash_rub(hands, vel, spin, under, kin, dt)
			_wash_drag(hands, pos, vel, spin, held, kin, rel, dt)
			held.fill(0.0)
			if t < mix_end:
				for h in 2:
					_wash_palm(hands, h, t, dt, mix_end, pos, yaw, vel, spin, over, held, kin)
			_wash_move(hands, pos, yaw, vel, spin, kin, dt)
			_wash_slump(pos, under, layer, held, kin, dt)
		else:
			if not planned_sweeps:
				planned_sweeps = true
				# who each sweep takes: the sweeps go round the pile, each taking the next SHARE of
				# the cards by direction - so every sweep has cards to bring in, wherever the hands
				# left them (fixed directions sent whole sweeps past empty cloth). A card is
				# missed now and then and a later sweep fetches it. Each lands squared on the pile:
				# a stiff card left with its middle at the pile's edge pivots there, and every card
				# on it leans with it.
				var by_angle: Array = []
				for i in n:
					if taken[i] == 0:
						by_angle.append([atan2(pos[i].y, pos[i].x), i])
				by_angle.sort_custom(func(x: Array, y: Array) -> bool: return float(x[0]) < float(y[0]))
				var ng := by_angle.size()
				var first_card := rng.randi_range(0, n - 1)
				var share := PackedInt32Array()
				share.resize(n)
				for r in ng:
					share[int((by_angle[(first_card + r) % ng] as Array)[1])] = mini(swipes - 1, int(float(r) * float(swipes) / float(ng)))
				for i in n:
					if taken[i] == 1:
						caught[i] = -1
						t_in[i] = INF
						continue
					var k2 := share[i]
					while k2 < swipes - 1 and rng.randf() < 0.15:
						k2 += 1          # missed: a later sweep fetches it
					caught[i] = k2
				# the pile's order is the order they arrive in
				var order: Array = []
				for i in n:
					if taken[i] == 0:
						order.append([caught[i], pos[i].length(), i])
				order.sort_custom(func(x: Array, y: Array) -> bool:
					if int(x[0]) != int(y[0]):
						return int(x[0]) < int(y[0])
					return float(x[1]) > float(y[1]))
				for o in order:
					land_order.append(int(o[2]))
			var g := t - gather_t0
			kin.fill(0)
			for i in n:
				if taken[i] == 1 or flying[i] >= 0:
					kin[i] = 1
					continue
				# in the pile for good: nothing slides it again
				if t_in[i] > 0.0 and t >= t_in[i]:
					kin[i] = 1
				# the sweep reaches the outermost cards first and pushes them in ahead of it
				var k := caught[i]
				var s0 := float(k) * sweep_len
				var u1 := s0 + sweep_len * 0.82
				if not begun.has(i):
					var r := clampf(pos[i].length() / maxf(rx, rz), 0.0, 1.0)
					var u0 := s0 + (1.0 - r) * 0.28
					if g < u0:
						continue
					begun[i] = u0
					from_p[i] = pos[i]
					from_yaw[i] = yaw[i]
					# into the pile, squared as it lands, near enough: the pile is built, not tidied
					var slot := land_order.find(i)
					var jit2: Vector3 = medium._plan.slot_jit[slot] if slot >= 0 and slot < medium._plan.slot_jit.size() else Vector3.ZERO
					to_p[i] = Vector2(jit2.x, jit2.y) + Vector2(rng.randf_range(-0.0025, 0.0025), rng.randf_range(-0.0025, 0.0025))
					# the nearest of the two ways a card lies (its yaw, or half a turn from it): a card
					# the palms turned over lands the way it was turned, it is not turned back
					to_yaw[i] = jit2.z + PI * roundf((from_yaw[i] - jit2.z) / PI) + rng.randf_range(-0.05, 0.05)
					t_in[i] = gather_t0 + u1
				var b0 := float(begun[i])
				if g > u1 + dt:
					continue
				var e2 := TableMedium._ease(clampf((g - b0) / maxf(u1 - b0, 0.05), 0.0, 1.0))
				pos[i] = from_p[i].lerp(to_p[i], e2)
				yaw[i] = lerp_angle(from_yaw[i], to_yaw[i], e2)
				kin[i] = 1
			# WHAT NO SWEEP HAS REACHED YET SLIDES ON: the palms lift, and a card they let go of
			# mid-pass runs on and stops, rather than freezing where the gather began
			for i in n:
				if kin[i] == 1:
					vel[i] = Vector2.ZERO
					spin[i] = 0.0
			held.fill(0.0)
			_wash_rub(hands, vel, spin, under, kin, dt)
			_wash_drag(hands, pos, vel, spin, held, kin, rel, dt)
			_wash_move(hands, pos, yaw, vel, spin, kin, dt)
		# A CARD IN THE AIR is where its flight has it; the jumper, down, stays where it fell
		for i in n:
			if i == lying:
				vel[i] = Vector2.ZERO
				spin[i] = 0.0
			if flying[i] >= 0:
				var fg := _flight_ground(flights[flying[i]], t)
				pos[i] = Vector2(fg.x, fg.y)
				yaw[i] = fg.z
				vel[i] = Vector2.ZERO
				spin[i] = 0.0
		# THE JUMPER IS THROWN as the mixing stops: the card a hard blow struck last, or the one sliding
		# fastest - over onto its face, clear of every card ([method _eject])
		if jumping and not tried and t >= mix_end:
			tried = true
			var picks: Array = []
			for i in n:
				if flying[i] >= 0 or not (over[i] as Array).is_empty():
					continue
				var hit := 0.0
				var way := vel[i]
				for b in blown:
					if int((b as Array)[1]) == i and t - float((b as Array)[0]) < 0.8 and float((b as Array)[2]) > hit:
						hit = float((b as Array)[2])
						way = (b as Array)[3]
				if way.length() < 0.02:
					way = pos[i] + Vector2(0.0, 0.01)
				picks.append([hit * 4.0 + vel[i].length() + pos[i].length(), i, way.normalized(), hit])
			picks.sort_custom(func(x: Array, y: Array) -> bool: return float(x[0]) > float(y[0]))
			for p in picks:
				var i := int((p as Array)[1])
				var fl := _eject(i, pos[i], yaw[i], (p as Array)[2], Vector2(0.15, 0.28), t, hash([seed, "jumper", i]), true,
					pos, yaw, flights, bool(jump.get("reversed", false)))
				if fl.is_empty():
					continue
				fl["blow"] = (p as Array)[3]
				flights.append(fl)
				jumper = i
				jumper_flight = fl
				vel[i] = Vector2.ZERO
				spin[i] = 0.0
				break
		# NOTHING PASSES THROUGH WHAT STANDS ON THE TABLE: every card goes from where it was to where
		# this step put it, and whatever it runs into stops it - it slides along it instead, at the
		# speed it really went. A thrown card's way was chosen clear.
		for i in n:
			if flying[i] >= 0 or taken[i] == 1 or (i == lying and landed[i] == 0):
				moved[i] = pos[i].distance_to(was[i])
				stirred[i] = 1 if flying[i] >= 0 or taken[i] == 1 else 0
				was[i] = pos[i]
				was_yaw[i] = yaw[i]
				continue
			# a card lying still has nowhere new to be (one just come down meets what it lies on)
			if kin[i] == 0 and vel[i] == Vector2.ZERO and spin[i] == 0.0 and landed[i] == 0 and pos[i] == was[i]:
				moved[i] = 0.0
				stirred[i] = 0
				continue
			pos[i] = _card_clear(was[i], pos[i], yaw[i])
			moved[i] = pos[i].distance_to(was[i])
			stirred[i] = 1 if moved[i] > 0.0 or yaw[i] != was_yaw[i] or landed[i] == 1 else 0
			if kin[i] == 0:
				vel[i] = (pos[i] - was[i]) * WASH_HZ
			was[i] = pos[i]
			was_yaw[i] = yaw[i]
		# WHO LIES ON WHOM: pairs that came apart forget their order; a pair that has just met lies
		# the way it met, the card sliding in on top (in the deck, the higher slot on top). A card in
		# the air, or the jumper, lies on nothing and nothing on it.
		var far2 := Vector2(TableMedium.CARD.x, TableMedium.CARD.y).length_squared()
		var blows: Array = []
		for i in n:
			var pi_: Vector2 = pos[i]
			var off_i := flying[i] >= 0 or taken[i] == 1
			for j in range(i + 1, n):
				var key := i * 64 + j
				if off_i or flying[j] >= 0 or taken[j] == 1:
					parted.erase(key)
					if rel.has(key):
						var top0 := i if int(rel[key]) > 0 else j
						(under[top0] as Array).erase(j if top0 == i else i)
						rel.erase(key)
						restacked = true
					continue
				# two cards that both lay still lie as they did - once the first step has said how
				if step > s_from and stirred[i] == 0 and stirred[j] == 0 and not parted.has(key):
					continue
				var d2 := pi_.distance_squared_to(pos[j])
				var apart := d2 > far2 or (d2 > TableMedium.CARD.x * TableMedium.CARD.x and not _cards_overlap(pi_, yaw[i], pos[j], yaw[j]))
				# ...or touching only between the steps ([method _wash_rest_at] poses between them)
				var between := apart and d2 < far2 * 1.6 and moved[i] + moved[j] > 0.004 and _cards_overlap((last_pos[i] + pi_) * 0.5,
					lerp_angle(last_yaw[i], yaw[i], 0.5), (last_pos[j] + pos[j]) * 0.5, lerp_angle(last_yaw[j], yaw[j], 0.5))
				if apart and not between:
					# a pair keeps its order the step it parts
					if rel.has(key):
						if not parted.has(key):
							parted[key] = true
							continue
						var top := i if int(rel[key]) > 0 else j
						(under[top] as Array).erase(j if top == i else i)
						rel.erase(key)
						restacked = true
					parted.erase(key)
					continue
				if between:
					parted[key] = true
				else:
					parted.erase(key)
				if rel.has(key):
					continue
				var i_top := moved[i] > moved[j] + 1e-6 if absf(moved[i] - moved[j]) > 1e-6 else false
				# A CARD CLIMBS ONE CARD, NOT A HEAP: one lying two or more above it it runs in under
				if i_top and layer[j] >= layer[i] + 2:
					i_top = false
				elif not i_top and layer[i] >= layer[j] + 2:
					i_top = true
				# a card coming down lies on what it comes down on; nothing covers the jumper
				if landed[i] != landed[j]:
					i_top = landed[i] == 1
				if i == lying or j == lying:
					i_top = i == lying
				# never over a card already above it, however far down the stack: no loops
				if i_top and _lies_on(under, j, i):
					i_top = false
				elif not i_top and _lies_on(under, i, j):
					i_top = true
				rel[key] = 1 if i_top else -1
				(under[i if i_top else j] as Array).append(j if i_top else i)
				restacked = true
				# A CARD RUN INTO IS NUDGED where the other first touches it - on its way, turned if
				# struck off its middle ([constant WASH_KNOCK]); a hard blow may throw it
				if kin[i] == 0 and kin[j] == 0:
					var top := i if i_top else j
					var bot := j if i_top else i
					var impact := (vel[top] - vel[bot]).length()
					var way := vel[top].normalized() if vel[top].length() > 1e-4 else (pos[bot] - pos[top]).normalized()
					var c := _touch(pos[bot], yaw[bot], pos[top])
					var dv := (vel[top] - vel[bot]) * float(hands["knock"])
					_wash_push(vel, spin, bot, c - pos[bot], dv)
					_wash_push(vel, spin, top, c - pos[top], -dv)
					if impact >= EJECT_SPEED * 0.6:
						blows.append([impact, top, bot, way])
						blown.append([t, bot, impact, way])
		while not blown.is_empty() and t - float((blown[0] as Array)[0]) > 1.0:
			blown.pop_front()
		# A HARD BLOW THROWS THE CARD IT STRIKES out of the spread, face down - the harder, the surer
		if not blows.is_empty() and t >= out_end and t < mix_end - EJECT_ROOM and thrown < EJECT_MOST:
			blows.sort_custom(func(x: Array, y: Array) -> bool: return float(x[0]) > float(y[0]))
			for bl in blows:
				var impact := float((bl as Array)[0])
				if impact < EJECT_SPEED or thrown >= EJECT_MOST:
					break
				var top := int((bl as Array)[1])
				var bot := int((bl as Array)[2])
				if held[bot] > 0.2 or not (over[bot] as Array).is_empty() or _lain_on(under, bot, top) \
						or _thrown_lately(flights, bot, t):
					continue
				var die := float(hash([seed, "throw", step, bot]) & 0xFFFF) / 65535.0
				if die >= EJECT_CHANCE * clampf((impact - EJECT_SPEED) / 0.3, 0.0, 1.0):
					continue
				var fl := _eject(bot, pos[bot], yaw[bot], (bl as Array)[3], EJECT_REACH, t, hash([seed, "throw-way", step, bot]),
					false, pos, yaw, flights)
				if fl.is_empty():
					continue
				fl["blow"] = impact
				flights.append(fl)
				thrown += 1
				# it pops up onto the edge that struck it, and is off
				var key := mini(top, bot) * 64 + maxi(top, bot)
				if rel.has(key):
					(under[top] as Array).erase(bot)
					(under[bot] as Array).append(top)
					rel[key] = 1 if bot < top else -1
					restacked = true
				vel[bot] = Vector2.ZERO
				spin[bot] = 0.0
		# THE ORDER THE CARDS LIE IN: each one above the highest card it lies on
		if restacked:
			restacked = false
			layer.fill(-1)
			for i in n:
				_layer_of(i, under, layer)
			for i in n:
				(over[i] as Array).clear()
			for i in n:
				for j in under[i]:
					(over[int(j)] as Array).append(i)
		for i in n:
			var y := WASH_FLOOR + float(layer[i]) * WASH_LAYER
			if flying[i] >= 0 or taken[i] == 1:
				y = WASH_FLOOR + float(n + 1) * WASH_LAYER
			(tracks[i] as Array).append(Vector4(pos[i].x, y, pos[i].y, yaw[i]))
	# SQUARE: from wherever the pile left each card to its place in the deck - its place being where
	# it lies in the pile, so none passes through another as the deck is squared - turned the short
	# way round to the nearer of the deck's two ways (a quarter turn at most). A card the wash turned
	# half way round stays turned: `turned` names those, and the deck carries them on
	# ([method deck_turns]).
	var turned := PackedByteArray()
	turned.resize(n)
	var order: Array = []
	for i in n:
		if taken[i] == 0:
			order.append(i)
	order.sort_custom(func(a: int, b: int) -> bool: return layer[a] < layer[b] or (layer[a] == layer[b] and a < b))
	var last := steps - 1
	var sq0 := int(floor((dur - square) * WASH_HZ))
	for i in n:
		tracks[i] = PackedVector4Array(tracks[i] as Array)
	for slot in order.size():
		var i := int(order[slot])
		var jit3: Vector3 = medium._plan.slot_jit[slot] if slot < medium._plan.slot_jit.size() else Vector3.ZERO
		var tr: PackedVector4Array = tracks[i]
		var from: Vector4 = tr[mini(sq0, tr.size() - 1)]
		var half := roundf((from.w - jit3.z) / PI)
		turned[i] = posmod(int(half), 2)
		var to := Vector4(jit3.x, WASH_FLOOR + float(slot) * WASH_LAYER, jit3.y, jit3.z + PI * half)
		for st in range(sq0, tr.size()):
			var e3 := TableMedium._ease(float(st - sq0) / maxf(float(last - sq0), 1.0))
			tr[st] = from.lerp(to, e3)
		tracks[i] = tr
	var airborne := {}
	for f in flights:
		var c := int((f as Dictionary)["card"])
		if not airborne.has(c):
			airborne[c] = []
		(airborne[c] as Array).append(f)
	# EVERY CARD IS ITS OWN THICKNESS from the moment the palm comes down on the deck until it is in
	# the pile for good ([method _wash_spread_at]): the deck flattens as it is spread, and the pile
	# BUILDS TO THE DECK'S HEIGHT as it is gathered - each card thickened as it lands - or as it is
	# squared at the latest. Thickened all at once as the pile was squared, the gathered pile stood a
	# quarter of the deck's height and then "suddenly just grows by 2x or 3x" (the user, 2026-10-08).
	var thin_at := PackedFloat32Array()
	var thick_at := PackedFloat32Array()
	for i in n:
		thin_at.append(0.0)
		var piled := t_in[i] if t_in[i] > 0.0 and t_in[i] < INF else dur - square
		thick_at.append(INF if taken[i] == 1 else minf(piled, dur - square))
	return {"tracks": tracks, "out": thin_at, "in": thick_at, "order": order, "turned": turned, "mix": Vector2(out_end, mix_end),
		"gather": gather_t0, "dur": dur, "hands": hands["log"], "flights": flights, "airborne": airborne,
		"jumper": jumper, "jumper_flight": jumper_flight}


## Whether card [param i] is in the air at [param t] in [param flights].
static func _in_flight(flights: Array, i: int, t: float) -> bool:
	for f in flights:
		var fd: Dictionary = f
		if int(fd["card"]) == i and t > float(fd["t0"]) and t < float(fd["t1"]):
			return true
	return false


## Whether card [param i] was thrown in the last few seconds before [param t] - a card lands and lies
## a moment before anything throws it again.
static func _thrown_lately(flights: Array, i: int, t: float) -> bool:
	for f in flights:
		var fd: Dictionary = f
		if int(fd["card"]) == i and t - float(fd["t1"]) < 2.0:
			return true
	return false


## Whether any card but [param but] lies on card [param i].
static func _lain_on(under: Array, i: int, but: int) -> bool:
	for c in under.size():
		if c != but and (under[c] as Array).has(i):
			return true
	return false


## A flight to carry into a plan of its own: its pose's cached rests are that plan's.
static func _flight_copy(f: Dictionary) -> Dictionary:
	var out := f.duplicate()
	out.erase("r0")
	out.erase("r1")
	return out


## The point of a card lying at [param at] turned [param yaw] nearest [param p] - where a card sliding
## in from there first touches it.
static func _touch(at: Vector2, yaw: float, p: Vector2) -> Vector2:
	var ax := Vector2(cos(yaw), -sin(yaw))
	var az := Vector2(sin(yaw), cos(yaw))
	var d := p - at
	return at + ax * clampf(d.dot(ax), -TableMedium.CARD.x * 0.5, TableMedium.CARD.x * 0.5) + az * clampf(d.dot(az), -TableMedium.CARD.y * 0.5, TableMedium.CARD.y * 0.5)


## A CARD THROWN OUT OF THE SPREAD: card [param i], lying at [param at] turned [param yaw] (about the
## deck's place), struck along [param way] at [param t] - a hop out along the blow, [param reach]
## meters (least, most), onto the cloth and wholly in the picture, its way and where it lands clear
## of what stands and of where a card in [param flights] comes down. Face down,
## wobbling as it goes; or, the jumper ([param up]), higher and over onto its face - its top away
## from the reader, or toward them [param reversed] - and down on as few of the cards where they lie
## ([param pos], [param yaws]) as it can. A few tries round the blow: the flight
## (`{card, t0, t1, from, to, yaw0, yaw1, lie, hop, axis, up, wobble}` - `lie` the turn of the card
## as it lies when down - see [method _flight_xf]), or empty when none lands anywhere it may.
func _eject(i: int, at: Vector2, yaw: float, way: Vector2, reach: Vector2, t: float, salt: int, up: bool,
		pos: PackedVector2Array, yaws: PackedFloat32Array, flights: Array, reversed := false) -> Dictionary:
	var r := RandomNumberGenerator.new()
	r.seed = salt
	var hop := r.randf_range(JUMP_HOP.x, JUMP_HOP.y) if up else r.randf_range(EJECT_HOP.x, EJECT_HOP.y)
	var time := r.randf_range(JUMP_FLIGHT.x, JUMP_FLIGHT.y) if up else r.randf_range(EJECT_TIME.x, EJECT_TIME.y)
	var wobble := r.randf_range(0.12, 0.35) * (1.0 if r.randf() < 0.5 else -1.0)
	var best := {}
	var best_on := 0
	for attempt in 12:
		var d := way.rotated(r.randf_range(-0.45, 0.45) * (1.0 + float(attempt) * 0.45)).normalized()
		var to := at + d * r.randf_range(reach.x, reach.y) * (1.0 - 0.04 * float(attempt))
		var h := Vector2(-d.y, d.x)
		var yaw1 := yaw + r.randf_range(-1.3, 1.3)
		var lie := yaw1
		if up:
			# turned over about h, its top lands pointing `top`: so before the turn it points top
			# mirrored in h - and it lies along `top`
			var top := Vector2(0.0, 1.0 if reversed else -1.0).rotated(r.randf_range(-0.5, 0.5))
			var m := h * (2.0 * top.dot(h)) - top
			yaw1 = yaw + wrapf(atan2(-m.x, -m.y) - yaw, -PI, PI)
			lie = atan2(-top.x, -top.y)
		if not _may_land(i, at, to, lie, up, flights):
			continue
		var fl := {"card": i, "t0": t, "t1": ceilf((t + time) * WASH_HZ - 0.001) / WASH_HZ, "from": at, "to": to,
			"yaw0": yaw, "yaw1": yaw1, "lie": lie, "hop": hop, "axis": h, "up": up, "wobble": wobble}
		if not up:
			return fl
		# the jumper comes down on the fewest cards it can - on none, where there is room
		var on := 0
		for j in pos.size():
			if j != i and pos[j].distance_to(to) < Vector2(TableMedium.CARD.x, TableMedium.CARD.y).length() \
					and _cards_overlap(pos[j], yaws[j], to, lie):
				on += 1
		if on == 0:
			return fl
		if best.is_empty() or on < best_on:
			best = fl
			best_on = on
	return best


## Whether card [param i] thrown from [param from] may come down at [param to] turned [param yaw]
## (about the deck's place): its way clear of what stands, the card wholly on the cloth and in the
## picture - the jumper ([param up]) well inside it - off everything standing, and off where any
## card in [param flights] comes down.
func _may_land(i: int, from: Vector2, to: Vector2, yaw: float, up: bool, flights: Array) -> bool:
	if not _path_clear(from, to):
		return false
	var off := Vector2(medium._plan.mid.x, medium._plan.mid.z)
	var card := _card_poly(to + off, yaw)
	var cloth := Rect2(-CLOTH.x * 0.5 + 0.01, -0.02 - CLOTH.y * 0.5 + 0.01, CLOTH.x - 0.02, CLOTH.y - 0.02)
	var frame := Rect2(0.1, 0.1, 0.8, 0.8) if up else Rect2(0.03, 0.03, 0.94, 0.94)
	for c: Vector2 in card:
		if not cloth.has_point(c) or Tables.sdf(medium._top_o, c) > -Tables.EDGE:
			return false
		var sc: Variant = CardTable.project(medium._plan.cam_base, medium._cam.fov, Vector3(c.x, WASH_FLOOR, c.y))
		if sc == null or not frame.has_point(sc as Vector2):
			return false
	for foot in medium._standing:
		if TableMedium._convex_overlap(card, foot, TableMedium.FOOT_MARGIN):
			return false
	for f in flights:
		var fd: Dictionary = f
		if int(fd["card"]) != i and TableMedium._convex_overlap(card, _card_poly((fd["to"] as Vector2) + off, float(fd["lie"])), 0.01):
			return false
	return true


## Where a thrown card is over the cloth at [param t] (about the deck's place), `Vector3(x, z, its
## turn)`: fast off the blow, slowing as it comes down.
static func _flight_ground(f: Dictionary, t: float) -> Vector3:
	var u := clampf((t - float(f["t0"])) / maxf(float(f["t1"]) - float(f["t0"]), 0.01), 0.0, 1.0)
	var p := 1.0 - (1.0 - u) * (1.0 - u)
	var at := (f["from"] as Vector2).lerp(f["to"] as Vector2, p)
	return Vector3(at.x, at.y, lerpf(float(f["yaw0"]), float(f["yaw1"]), TableMedium._ease(u)))


## How many cards card [param i] lies on, one on another at the deepest: its layer in the pile, kept in
## [param layer] (-1 for one not walked yet). Who lies on whom never loops, so the walk ends.
static func _layer_of(i: int, under: Array, layer: PackedInt32Array) -> int:
	if layer[i] >= 0:
		return layer[i]
	var l := 0
	for j in under[i]:
		l = maxi(l, _layer_of(int(j), under, layer) + 1)
	layer[i] = l
	return l


## Whether card [param a] lies, however far down, on card [param b] - walking down what each lies on.
static func _lies_on(under: Array, a: int, b: int) -> bool:
	var seen := {}
	var todo: Array = [a]
	while not todo.is_empty():
		var c := int(todo.pop_back())
		for d in under[c]:
			if int(d) == b:
				return true
			if not seen.has(d):
				seen[d] = true
				todo.append(d)
	return false


## THE HANDS OF A WASH: their own dice - so a wash cut short ([method _wash_fit]) has the same hands
## up to where it was cut - and their own FEEL, each wash sampled round the centers ([constant
## WASH_GRIP] and on): how firmly a palm holds, how cards drag and slide, how briskly these hands
## move. Each palm: its gesture under way, when it next comes down, its size, and how it holds
## each card this pass; and every gesture the palms made, in order ([palm, gesture]).
func _wash_hands(seed: int, t0: float, rx: float, rz: float) -> Dictionary:
	var r := RandomNumberGenerator.new()
	r.seed = hash([seed, "wash-palms"])
	var palms: Array = []
	for h in 2:
		var grip := PackedFloat32Array()
		grip.resize(TableMedium.DECK_N)
		palms.append({"g": {}, "next": t0 + r.randf_range(0.0, 0.4), "pass": -1, "grip": grip,
			"size": PALM * r.randf_range(0.9, 1.12)})
	var touched := PackedFloat32Array()
	touched.resize(TableMedium.DECK_N)
	return {"r": r, "palms": palms, "rx": rx, "rz": rz, "touched": touched, "log": [],
		"grip": WASH_GRIP * r.randf_range(0.85, 1.15), "drag": WASH_DRAG * r.randf_range(0.8, 1.25),
		"slide": WASH_SLIDE * r.randf_range(0.85, 1.2), "spin": WASH_SPIN * r.randf_range(0.8, 1.25),
		"knock": WASH_KNOCK * r.randf_range(0.75, 1.25),
		"pace": r.randf_range(0.85, 1.15)}


## PALM [param h] for the step from [param t]. Lifted between gestures, it comes down on its next
## ([method _wash_gesture]) where the cards are. At each of [constant GRIP_AT]'s points it presses, a
## card is brought to the palm's speed - as far as the palm's friction there allows ([constant
## WASH_GRIP]): a card pressed whole goes with it, one caught at an end swings round behind it, one
## only brushed slips. Where another card lies over it the palm hardly touches it ([constant
## WASH_COVERED]), so a card half under another is pulled out by its free half. Each pass the palm
## takes hold afresh - the heel of a hand bears on some cards and skims others - so a scrub carries
## a different few each way, and what it carried out it often leaves there. A card in the air
## ([param kin]) it does not touch.
func _wash_palm(hands: Dictionary, h: int, t: float, dt: float, t_end: float, pos: PackedVector2Array,
		yaw: PackedFloat32Array, vel: PackedVector2Array, spin: PackedFloat32Array, over: Array,
		held: PackedFloat32Array, kin: PackedByteArray) -> void:
	var p: Dictionary = (hands["palms"] as Array)[h]
	var r: RandomNumberGenerator = hands["r"]
	var g: Dictionary = p["g"]
	if not g.is_empty() and t >= float(g["t1"]):
		# lifted: a moment's reach to the next place, now and then a rest
		p["next"] = float(g["t1"]) + (r.randf_range(0.5, 1.2) if r.randf() < WASH_REST else r.randf_range(0.08, 0.3))
		g = {}
		p["g"] = g
	if g.is_empty():
		if t < float(p["next"]) or t > t_end - 0.5:
			return
		g = _wash_gesture(hands, h, t, pos, t_end)
		p["g"] = g
		p["pass"] = -1
		if g.is_empty():
			p["next"] = t + 0.25
			return
		(hands["log"] as Array).append([h, g])
	var a := _gesture_at(g, t)
	var b := _gesture_at(g, t + dt)
	var press := minf(a.z, b.z)
	if press <= 0.0:
		return
	var grip: PackedFloat32Array = p["grip"]
	var k := _gesture_pass(g, t)
	if k != int(p["pass"]):
		p["pass"] = k
		for i in grip.size():
			var u := r.randf()
			# held (it goes with the palm), dragged (it slides along slower, and falls behind), or
			# brushed (it stays): how the palm's friction there compares with the cloth's
			grip[i] = 1.0 if u < 0.45 else (r.randf_range(0.1, 0.2) if u < 0.75 else r.randf_range(0.02, 0.07))
	var at := Vector2(a.x, a.y)
	var v := (Vector2(b.x, b.y) - at) / dt
	var size: Vector2 = p["size"]
	# the hand lies along the forearm, from the reader's shoulder on its side
	var along := (at - Vector2(WASH_SHOULDER.x * (-1.0 if h == 0 else 1.0), WASH_SHOULDER.y)).normalized()
	var across := Vector2(-along.y, along.x)
	var reach := size.y * 1.05 + Vector2(TableMedium.CARD.x, TableMedium.CARD.y).length() * 0.5
	var most := float(hands["grip"]) * dt / float(GRIP_AT.size())
	var touched: PackedFloat32Array = hands["touched"]
	for i in pos.size():
		if kin[i] == 1 or pos[i].distance_squared_to(at) > reach * reach:
			continue
		var ax := Vector2(cos(yaw[i]), -sin(yaw[i]))
		var az := Vector2(sin(yaw[i]), cos(yaw[i]))
		var hold := press * grip[i]
		for q in GRIP_AT:
			var o: Vector2 = q
			var rr := ax * o.x + az * o.y
			var d := pos[i] + rr - at
			var e := Vector2(d.dot(across) / size.x, d.dot(along) / size.y).length()
			if e >= 1.05:
				continue
			var w := hold * (1.0 - smoothstep(0.75, 1.05, e))
			# where another card lies over it, the palm presses that one instead
			for k2 in over[i]:
				if _card_has(pos[int(k2)], yaw[int(k2)], pos[i] + rr):
					w *= WASH_COVERED
					break
			held[i] = maxf(held[i], w)
			_wash_push(vel, spin, i, rr, v - vel[i] - Vector2(rr.y, -rr.x) * spin[i], most * w)
		if held[i] > 0.2:
			touched[i] = t


## Whether a card lying at [param at] turned [param yaw] covers the point [param pt] (x by z).
static func _card_has(at: Vector2, yaw: float, pt: Vector2) -> bool:
	var d := pt - at
	return absf(d.dot(Vector2(cos(yaw), -sin(yaw)))) <= TableMedium.CARD.x * 0.5 and absf(d.dot(Vector2(sin(yaw), cos(yaw)))) <= TableMedium.CARD.y * 0.5


## Card [param i]'s point [param rr] (from its middle) brought [param dv] nearer the speed it is
## pushed toward - no more than [param most] m/s of the card's own speed changed (a friction's
## limit; the card slips past it): it moves and turns as a flat card would, pushed there, so a push
## through its middle only moves it and one at an end turns it too.
static func _wash_push(vel: PackedVector2Array, spin: PackedFloat32Array, i: int, rr: Vector2, dv: Vector2,
		most: float = INF) -> void:
	var rp := Vector2(rr.y, -rr.x)
	var j := dv - rp * (rp.dot(dv) / (CARD_I + rr.length_squared()))
	if j.length() > most:
		j *= most / j.length()
	vel[i] += j
	spin[i] += rp.dot(j) / CARD_I


## THE CLOTH SLOWS EVERY LOOSE CARD by the same each second, as cloth does - a card let go mid-pass
## runs on a little and stops, sooner on cloth than on another card - and its turning stops too.
static func _wash_rub(hands: Dictionary, vel: PackedVector2Array, spin: PackedFloat32Array, under: Array,
		kin: PackedByteArray, dt: float) -> void:
	var slide := float(hands["slide"]) * dt
	var turn := float(hands["spin"]) * dt
	for i in vel.size():
		if kin[i] == 1 or (vel[i] == Vector2.ZERO and spin[i] == 0.0):
			continue
		var sp := vel[i].length()
		if sp > 0.0:
			var mu := slide * (1.0 if (under[i] as Array).is_empty() else WASH_ON_CARD)
			vel[i] *= maxf(0.0, sp - mu) / sp
		spin[i] = signf(spin[i]) * maxf(0.0, absf(spin[i]) - turn)


## CARDS DRAG CARDS: two lying one on the other pull each toward the other's speed where they touch
## - hard when a palm pressed the top one at the last step ([constant WASH_DRAG], [param held]), so a
## card scrubbed across the spread drags and turns what it passes over and leaves a wake of cards
## knocked askew. Before the palms, so what a palm holds goes its way whatever lies under it.
func _wash_drag(hands: Dictionary, pos: PackedVector2Array, vel: PackedVector2Array, spin: PackedFloat32Array,
		held: PackedFloat32Array, kin: PackedByteArray, rel: Dictionary, dt: float) -> void:
	var far := Vector2(TableMedium.CARD.x, TableMedium.CARD.y).length()
	var drag: Vector2 = hands["drag"]
	for key in rel:
		var i := int(key) >> 6
		var j := int(key) & 63
		if kin[i] == 1 or kin[j] == 1:
			continue
		if vel[i] == Vector2.ZERO and vel[j] == Vector2.ZERO and spin[i] == 0.0 and spin[j] == 0.0:
			continue
		var top := i if int(rel[key]) > 0 else j
		var bot := j if top == i else i
		var k := (drag.x + drag.y * held[top]) * (1.0 - clampf(pos[top].distance_to(pos[bot]) / far, 0.0, 1.0))
		if k <= 0.0:
			continue
		var c := (pos[top] + pos[bot]) * 0.5
		var rt := c - pos[top]
		var rb := c - pos[bot]
		var dv := ((vel[top] + Vector2(rt.y, -rt.x) * spin[top]) - (vel[bot] + Vector2(rb.y, -rb.x) * spin[bot])) \
			* (0.5 * (1.0 - exp(-k * dt)))
		_wash_push(vel, spin, bot, rb, dv)
		_wash_push(vel, spin, top, rt, -dv)


## A HEAP SLUMPS: a loose card lying [constant SLUMP_FROM] or more cards up creeps off the cards
## under it, away from their middle, the higher the faster ([constant SLUMP]) - a heap of real cards
## spreads under the hands, and a stiff card balanced on one tips steeply.
static func _wash_slump(pos: PackedVector2Array, under: Array, layer: PackedInt32Array, held: PackedFloat32Array,
		kin: PackedByteArray, dt: float) -> void:
	for i in pos.size():
		if kin[i] == 1 or held[i] > 0.2 or layer[i] < SLUMP_FROM or (under[i] as Array).is_empty():
			continue
		var c := Vector2.ZERO
		for j in under[i]:
			c += pos[int(j)]
		c /= float((under[i] as Array).size())
		var away := pos[i] - c
		if away.length() < 1e-4:
			continue
		pos[i] += away.normalized() * SLUMP * float(layer[i] - SLUMP_FROM + 1) * dt


## THE CARDS MOVE, one step: none faster than a hand ([constant HAND_SPEED]), and one going out past
## the spread's edge is turned back, the harder the farther out, as a hand would.
func _wash_move(hands: Dictionary, pos: PackedVector2Array, yaw: PackedFloat32Array, vel: PackedVector2Array,
		spin: PackedFloat32Array, kin: PackedByteArray, dt: float) -> void:
	var rx := float(hands["rx"])
	var rz := float(hands["rz"])
	for i in pos.size():
		if kin[i] == 1 or (vel[i] == Vector2.ZERO and spin[i] == 0.0):
			continue
		var sp := vel[i].length()
		if sp > HAND_SPEED:
			vel[i] *= HAND_SPEED / sp
		spin[i] = clampf(spin[i], -WASH_TURN_MAX, WASH_TURN_MAX)
		var q := Vector2(pos[i].x / rx, (pos[i].y + 0.01) / rz)
		var l := q.length()
		if l > 1.0:
			var nrm := Vector2(q.x / rx, q.y / rz).normalized()
			var vn := vel[i].dot(nrm)
			if vn > 0.0:
				vel[i] -= nrm * vn * clampf((l - 1.0) / 0.15, 0.0, 1.0)
		pos[i] += vel[i] * dt
		yaw[i] += spin[i] * dt


## A PALM'S NEXT GESTURE, from [param t]. It comes down on a card - mostly one on its own side of the
## spread, and one the hands have left alone a while - and the best of a few tries keeps clear of
## the other palm ([constant WASH_APART]). How often each ([constant WASH_GESTURES]):
##
##   scrub   passes back and forth, each across a good part of the spread ([constant WASH_SCRUB]),
##           its line turning and drifting a little between them
##   swirl   wide rounds, often the other way round from the other palm's
##   fetch   out to the card lying farthest out, and back through the middle with it
##
## A scrub or a fetch is its turning points `pts` at times `ts`, pressed `press` on each pass; a
## swirl its middle `c` (drifting `v`), radii `a` and `b` turned `rot`, where round it `ph`, how
## fast `om` and how hard `press`. Empty when there is no time left for one.
func _wash_gesture(hands: Dictionary, h: int, t: float, pos: PackedVector2Array, t_end: float) -> Dictionary:
	var r: RandomNumberGenerator = hands["r"]
	var rx := float(hands["rx"])
	var rz := float(hands["rz"])
	var pace := float(hands["pace"])
	var side := -1.0 if h == 0 else 1.0
	var touched: PackedFloat32Array = hands["touched"]
	var other: Dictionary = ((hands["palms"] as Array)[1 - h] as Dictionary)["g"]
	var best := {}
	var best_apart := -1.0
	for attempt in 6:
		# where it comes down
		var ws := PackedFloat32Array()
		var total := 0.0
		for i in pos.size():
			var w := (1.0 / (1.0 + exp(-side * pos[i].x / 0.07)) + 0.08) * (0.3 + clampf((t - touched[i]) / 2.5, 0.0, 1.0))
			ws.append(w)
			total += w
		var pick := r.randf() * total
		var land := pos[pos.size() - 1]
		for i in pos.size():
			pick -= ws[i]
			if pick <= 0.0:
				land = pos[i]
				break
		# the card lying farthest out, for a fetch
		var stray := -1
		var out_most := WASH_STRAY
		for i in pos.size():
			var k := Vector2(pos[i].x / rx, (pos[i].y + 0.01) / rz).length() * (1.15 if pos[i].x * side > 0.0 else 1.0)
			if k > out_most:
				out_most = k
				stray = i
		var u := r.randf() * (float(WASH_GESTURES["scrub"]) + float(WASH_GESTURES["swirl"]) + float(WASH_GESTURES["fetch"]))
		var g := {}
		if u < float(WASH_GESTURES["swirl"]):
			var a := rx * r.randf_range(0.28, 0.5)
			var b := rz * r.randf_range(0.5, 0.85)
			var rot := r.randf_range(-0.4, 0.4)
			var om := r.randf_range(3.2, 5.5) * pace
			if String(other.get("kind", "")) == "swirl" and r.randf() < 0.65:
				om *= -signf(float(other["om"]))
			elif r.randf() < 0.5:
				om = -om
			var ph := r.randf() * TAU
			var c := land - Vector2(cos(ph) * a, sin(ph) * b).rotated(rot)
			c = Vector2(clampf(c.x, -rx * 0.92 + a, rx * 0.92 - a), clampf(c.y, -rz * 0.92 + b - 0.01, rz * 0.92 - b - 0.01))
			var t1 := minf(t + r.randf_range(0.75, 1.5) * TAU / absf(om), t_end - 0.1)
			if t1 - t < 0.5:
				continue
			g = {"kind": "swirl", "t0": t, "t1": t1, "c": c, "v": Vector2.from_angle(r.randf() * TAU) * r.randf_range(0.0, 0.02),
				"a": a, "b": b, "rot": rot, "ph": ph, "om": om, "press": r.randf_range(0.6, 1.0)}
		else:
			var pts := PackedVector2Array()
			var ts := PackedFloat32Array([t])
			var press := PackedFloat32Array()
			if u < float(WASH_GESTURES["swirl"]) + float(WASH_GESTURES["fetch"]) and stray >= 0:
				# FETCH: onto the stray's outer edge, in through the middle and on a little past it, and
				# now and then a lighter half-pass back
				var p0 := pos[stray] + (pos[stray] + Vector2(0.0, 0.01)).normalized() * 0.02
				var p1 := _wash_into(Vector2(r.randf_range(-0.35, 0.35) * rx, r.randf_range(-0.35, 0.35) * rz - 0.01), rx, rz, 0.9)
				p1 = _wash_into(p1 + (p1 - p0).normalized() * r.randf_range(0.0, 0.08), rx, rz, 0.92)
				pts.append(p0)
				pts.append(p1)
				press.append(r.randf_range(0.8, 1.0))
				if r.randf() < 0.4:
					pts.append(p1.lerp(p0, r.randf_range(0.35, 0.6)))
					press.append(r.randf_range(0.4, 0.7))
			else:
				# SCRUB: from the card, toward somewhere a good way across the spread, then back and
				# forth along that line - turning and drifting a little each pass
				var p := _wash_into(land + Vector2(r.randf_range(-0.025, 0.025), r.randf_range(-0.02, 0.02)), rx, rz, 0.92)
				var to := _wash_into(Vector2(r.randf_range(-1.0, 1.0) * rx, r.randf_range(-1.0, 1.0) * rz - 0.01), rx, rz, 0.9)
				var dir := (to - p).normalized() if p.distance_to(to) > 0.08 else Vector2.from_angle(r.randf() * TAU)
				var span := r.randf_range(WASH_SCRUB.x, WASH_SCRUB.y)
				pts.append(p)
				for pass_ in r.randi_range(2, 6):
					var d := dir.rotated(r.randf_range(-0.3, 0.3)) * (1.0 if pass_ % 2 == 0 else -1.0)
					var q := _wash_into(p + d * span * r.randf_range(0.75, 1.1) + Vector2(-d.y, d.x) * r.randf_range(-0.035, 0.035), rx, rz, 0.92)
					if p.distance_to(q) < 0.06:
						break
					pts.append(q)
					press.append(r.randf_range(0.6, 1.0))
					p = q
			# each pass in its own time, at a hand's pace for its length
			for k in range(1, pts.size()):
				var tt := ts[k - 1] + pts[k - 1].distance_to(pts[k]) / (r.randf_range(0.32, 0.58) * pace)
				if tt > t_end - 0.1:
					break
				ts.append(tt)
			if ts.size() < 2:
				continue
			pts.resize(ts.size())
			press.resize(ts.size() - 1)
			g = {"kind": "scrub", "t0": t, "t1": ts[ts.size() - 1], "pts": pts, "ts": ts, "press": press}
		var apart := _palms_apart(g, other)
		if apart > best_apart:
			best = g
			best_apart = apart
		if apart >= WASH_APART:
			break
	return best


## Gesture [param g] at [param t]: (x, z, how hard it presses - nothing outside it, coming down and
## lifting over [constant WASH_TOUCH]). A scrub's pass eases out to a stop at each end.
static func _gesture_at(g: Dictionary, t: float) -> Vector3:
	var t0 := float(g["t0"])
	var t1 := float(g["t1"])
	if t < t0 or t > t1:
		return Vector3.ZERO
	var touch := clampf((t - t0) / WASH_TOUCH, 0.0, 1.0) * clampf((t1 - t) / WASH_TOUCH, 0.0, 1.0)
	if String(g["kind"]) == "swirl":
		var u := t - t0
		var ph := float(g["ph"]) + float(g["om"]) * u
		var p := (g["c"] as Vector2) + (g["v"] as Vector2) * u + Vector2(cos(ph) * float(g["a"]), sin(ph) * float(g["b"])).rotated(float(g["rot"]))
		return Vector3(p.x, p.y, touch * float(g["press"]))
	var ts: PackedFloat32Array = g["ts"]
	var pts: PackedVector2Array = g["pts"]
	var k := _gesture_pass(g, t)
	var p2 := pts[k].lerp(pts[k + 1], TableMedium._ease((t - ts[k]) / maxf(ts[k + 1] - ts[k], 0.001)))
	return Vector3(p2.x, p2.y, touch * (g["press"] as PackedFloat32Array)[k])


## Which pass of gesture [param g] is under way at [param t]: a scrub's leg, a swirl's half-round.
static func _gesture_pass(g: Dictionary, t: float) -> int:
	if String(g["kind"]) == "swirl":
		return int(absf(float(g["om"])) * (t - float(g["t0"])) / PI)
	var ts: PackedFloat32Array = g["ts"]
	var k := 0
	while k < ts.size() - 2 and t > ts[k + 1]:
		k += 1
	return k


## How near gesture [param g] comes to the other palm's [param other] while both press (INF when
## they never do at once).
static func _palms_apart(g: Dictionary, other: Dictionary) -> float:
	if g.is_empty() or other.is_empty():
		return INF
	var least := INF
	var t := maxf(float(g["t0"]), float(other["t0"]))
	var t1 := minf(float(g["t1"]), float(other["t1"]))
	while t <= t1:
		var a := _gesture_at(g, t)
		var b := _gesture_at(other, t)
		if a.z > 0.0 and b.z > 0.0:
			least = minf(least, Vector2(a.x, a.y).distance_to(Vector2(b.x, b.y)))
		t += 0.1
	return least


## [param p] brought in to the spread's edge, scaled by [param k], when it lies out past it.
static func _wash_into(p: Vector2, rx: float, rz: float, k: float) -> Vector2:
	var q := Vector2(p.x / rx, (p.y + 0.01) / rz)
	var l := q.length()
	if l <= k:
		return p
	q *= k / l
	return Vector2(q.x * rx, q.y * rz - 0.01)


## A card just landed on the deck, not yet squared.
func _messy(j: int, seed: int) -> Transform3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed, j, "messy"])
	var xf := medium._rest_xf(j)
	xf.origin += Vector3(rng.randf_range(-0.003, 0.003), 0.0, rng.randf_range(-0.003, 0.003))
	xf.basis = Basis(Vector3.UP, rng.randf_range(-0.07, 0.07)) * xf.basis
	return xf
