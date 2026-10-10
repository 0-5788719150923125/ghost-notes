extends RefCounted
class_name TablePositions

## TablePositions - where cards lie on the table, as DATA (next/notes.md step 9, "Positions are
## data"). A position is `{x, z, yaw, face}` on the cloth - meters, x to the reader's right and z
## toward the reader; yaw in degrees; face "up" or "down" - written by the producer's plan (a spread
## position may carry coordinates beside its name and question), or placed by a dealer through its
## tools ([DealerTools], `layout.json` in the episode). Today's seeded shapes - a row, an arc, two
## rows, a pyramid - are PRESETS that make them ([method seeded]).
##
## EVERY POSITION IS CHECKED THE SAME WAY, whoever wrote it ([method troubles]): on the cloth, inside
## the camera's frame, clear of the deck, and clear of every other card - against the episode's own
## camera and deck ([method CardTable.layout_of]), which are a function of its seed, so a plan or a
## dealer is told exactly what the table will do. Once the table is set, ON ITS TOP too ([Tables]: a
## round or oval top may not reach every corner of the cloth) - checked again as it is built. A set of positions with any trouble is not used:
## the table falls back to its preset.
##
## Free of autoload names, so a SceneTree gate and a toolset can ask it.

## THE CARD'S FACE, meters - one place for it (the table's own `CARD` is this).
const CARD := Vector2(0.07, 0.12)
## The cloth: its size and where its middle lies on the table (x, z).
const CLOTH := Vector2(1.2, 0.72)
const CLOTH_MIDDLE := Vector2(0.0, -0.02)
## How much of the cloth's edge a card keeps off - laid on the very hem it reads as dropped.
const HEM := 0.02
## The space kept round the deck, meters.
const DECK_CLEAR := 0.012
## How far inside the picture's edges a card must lie, as a share of the frame: inside it, no more.
const FRAME_MARGIN := 0.0
## The presets, the layouts the readers' videos actually use - rows, never a cross (measured: rows of
## three to ten, often two).
const PRESETS := ["row", "arc", "rows", "pyramid"]
## How often a row or an arc of six or more is laid as two rows instead - half that at five (a long row
## also crowds the deck, which is then put aside: [constant TableMedium.DECK_CROWD]).
const SPLIT_LONG := 0.5
## HOW A CARD LIES AND WITH WHAT, as a plan's position says it ([method staged]): `comes` - drawn (taken
## and held up), dealt (put straight down), swept (out in one waterfall with the swept positions next
## to it); `lies` - upright, or sideways (a quarter turn, as a tapped card); `on` - it lies on the card
## before it, shifted back so that card's name still shows (a stack, as a player keeps lands).
const COMES := ["drawn", "dealt", "swept"]
const LIES := ["upright", "sideways"]
## A stacked card lies this far behind the one under it (meters): its name, printed in the band at the
## foot of the face, stays in sight. A swept card lies this far along from the one before, and turns
## this much more in an arc.
const STACK_STEP := 0.024
const SWEEP_STEP := 0.03
const SWEEP_TURN := 0.07
## The gap between two piles on the cloth, meters.
const PILE_GAP := 0.018
## A quarter turn, as a tapped card lies: clockwise seen from above, as a player turns one.
const SIDEWAYS := -PI * 0.5


## THE SEEDED SPREAD, as the table has always laid it: a preset picked per episode from [param rng],
## within reach of the camera, clear of the deck, each card a hair off true as a hand lays them -
## for the episode's layout [param lay] ([method CardTable.layout_of]: its camera and its deck).
## `[{pos: Vector3, yaw: radians}]`. The draws from [param rng] are the table's own, in its own order,
## so an episode made before keeps its spread - unless a card of it lay partly outside the camera's
## frame: an arc or a row of seven or eight reached the front corners (measured: 2.6% of such
## spreads), and is laid as two rows instead, with the same hand's offsets and no draw of its own.
static func seeded(n: int, rng: RandomNumberGenerator, lay: Dictionary) -> Array:
	var deck: Vector3 = lay["deck"]
	var out: Array = []
	if n <= 0:
		return out
	var gap := CARD.x * rng.randf_range(1.12, 1.3)
	var kinds := ["row", "arc"]
	if n >= 5:
		kinds.append("rows")
	if n == 3 or n == 6:
		kinds.append("pyramid")
	var kind := String(kinds[rng.randi_range(0, kinds.size() - 1)])
	if n * gap > 0.66:
		kind = "rows"
	# A LONG ROW SPLIT IN TWO, now and then (the user, 2026-10-08: "At 6 cards, that row is quite long"),
	# on a die of its own so every draw after lands where it did
	elif kind in ["row", "arc"] and n >= 5:
		var split := RandomNumberGenerator.new()
		split.seed = hash([rng.seed, "tarot-long-row"])
		if split.randf() < SPLIT_LONG * (0.5 if n == 5 else 1.0):
			kind = "rows"
	var pos: Array = []
	match kind:
		"rows":
			pos = _rows(n, gap)
		"pyramid":
			var rows := [[0], [1, 2]] if n == 3 else [[0], [1, 2], [3, 4, 5]]
			var z0 := -0.21 if n == 6 else -0.15
			for r in rows.size():
				var row: Array = rows[r]
				for k in row.size():
					pos.append(Vector3((float(k) - float(row.size() - 1) * 0.5) * gap, 0.0,
						z0 + float(r) * CARD.y * 0.92))
		"arc":
			var bend := rng.randf_range(0.18, 0.32)
			for i in n:
				var x := (float(i) - float(n - 1) * 0.5) * gap
				pos.append(Vector3(x, 0.0, -0.08 + bend * x * x * 3.0 - 0.02))
		_:
			for i in n:
				pos.append(Vector3((float(i) - float(n - 1) * 0.5) * gap, 0.0, -0.085))
	# the hand's offsets, drawn once whatever the spread ends up as
	var hand: Array = []
	for i in n:
		hand.append([Vector3(rng.randf_range(-0.003, 0.003), (float(i) + 1.0) * 0.0002, rng.randf_range(-0.003, 0.003)),
			deg_to_rad(rng.randf_range(-2.5, 2.5))])
	out = _laid(pos, hand, kind == "arc", deck)
	# IN THE FRAME, every card whole - or two rows, which always are (measured)
	if kind != "rows" and not _in_frame(out, lay):
		out = _laid(_rows(n, gap), hand, false, deck)
	return out


## THE STAGED SPREAD: [param cards]' positions (`comes`, `lies`, `on`, [constant COMES]) laid as piles -
## a card alone, a stack, a waterfall - in a row (two rows when one would not fit), clear of the deck
## and in the camera's frame for the episode's layout [param lay] - and, with a [param box] the cards
## are kept in, off its whole column (a long row that will not fit beside it is two). A spread with none of them is the
## seeded preset itself ([method seeded]), draw for draw. `[{pos, yaw, face}]`.
static func staged(cards: Array, rng: RandomNumberGenerator, lay: Dictionary, box := Vector2.ZERO) -> Array:
	var n := cards.size()
	var piles := piles_of(cards)
	if piles.size() == n and not _any_sideways(cards) and box == Vector2.ZERO:
		return seeded(n, rng, lay)
	var deck: Vector3 = lay["deck"]
	var arc := rng.randf() < 0.5
	# each pile's cards about the pile's own middle, and how much cloth it takes (x by z)
	var shapes: Array = []
	for pile in piles:
		var offs: Array = []
		var lo := Vector2(INF, INF)
		var hi := Vector2(-INF, -INF)
		for j in (pile["cards"] as Array).size():
			var i := int((pile["cards"] as Array)[j])
			var yaw := SIDEWAYS if lies_sideways(cards[i]) else 0.0
			var at := Vector2.ZERO
			match String(pile["kind"]):
				"stack":
					at = Vector2(0.0, -STACK_STEP * float(j))
				"sweep":
					at = Vector2(SWEEP_STEP * float(j), (absf(float(j) - float((pile["cards"] as Array).size() - 1) * 0.5) * 0.006) if arc else 0.0)
					if arc:
						yaw += -SWEEP_TURN * (float(j) - float((pile["cards"] as Array).size() - 1) * 0.5)
			offs.append({"at": at, "yaw": yaw})
			var half := Vector2(CARD.x, CARD.y) * 0.5 if absf(sin(yaw)) < 0.5 else Vector2(CARD.y, CARD.x) * 0.5
			lo = Vector2(minf(lo.x, at.x - half.x), minf(lo.y, at.y - half.y))
			hi = Vector2(maxf(hi.x, at.x + half.x), maxf(hi.y, at.y + half.y))
		var mid := (lo + hi) * 0.5
		for o in offs:
			(o as Dictionary)["at"] = ((o as Dictionary)["at"] as Vector2) - mid
		shapes.append({"offs": offs, "size": hi - lo})
	# the hand's offsets, one per card
	var hand: Array = []
	for i in n:
		hand.append([Vector3(rng.randf_range(-0.002, 0.002), (float(i) + 1.0) * 0.0002, rng.randf_range(-0.002, 0.002)),
			deg_to_rad(rng.randf_range(-2.0, 2.0))])
	# A BOX STANDS TALL, and a card tucked behind it is hidden by it and has to be carried over it: the
	# spread keeps off its whole column, back to the cloth's far edge, so a row that will not fit beside
	# it becomes two (feedback 0010: a seventh card laid down behind the box)
	var keep := deck_keep(deck, box)
	if box != Vector2.ZERO:
		var far := CLOTH_MIDDLE.y - CLOTH.y * 0.5
		keep = Rect2(keep.position.x, far, keep.size.x, keep.end.y - far)
	for rows in [1, 2]:
		var out := _piles_laid(piles, shapes, hand, rows, n)
		var off := CardTable.clear_of(out, CARD, keep)
		for sl in out:
			(sl as Dictionary)["pos"] = ((sl as Dictionary)["pos"] as Vector3) + Vector3(off.x, 0.0, off.y)
		if rows == 2 or _in_frame(out, lay):
			return out
	return []


## The piles [param cards] make: `[{kind: single|stack|sweep, cards: [index...]}]` - a card `on` the one
## before joins its pile as a stack; swept cards next to each other are one waterfall.
static func piles_of(cards: Array) -> Array:
	var out: Array = []
	for i in cards.size():
		var p := _position(cards[i])
		var comes := String(p.get("comes", "drawn"))
		if i > 0 and bool(p.get("on", false)) and not out.is_empty():
			var last: Dictionary = out[-1]
			if String(last["kind"]) != "sweep":
				last["kind"] = "stack"
				(last["cards"] as Array).append(i)
				continue
		if comes == "swept" and not out.is_empty() and String((out[-1] as Dictionary)["kind"]) == "sweep" \
				and int(((out[-1] as Dictionary)["cards"] as Array)[-1]) == i - 1:
			((out[-1] as Dictionary)["cards"] as Array).append(i)
			continue
		out.append({"kind": "sweep" if comes == "swept" else "single", "cards": [i]})
	return out


## Does card [param c]'s position lie it sideways?
static func lies_sideways(c: Variant) -> bool:
	return String(_position(c).get("lies", "upright")) == "sideways"


static func _any_sideways(cards: Array) -> bool:
	return cards.any(func(c: Variant) -> bool: return lies_sideways(c))


static func _position(c: Variant) -> Dictionary:
	var p: Variant = (c as Dictionary).get("position", {}) if c is Dictionary else {}
	return p if p is Dictionary else {}


## The piles laid in [param rows] rows across the cloth, each card where its pile puts it: one row a
## little behind the cloth's middle, as the preset's; two from the preset's first row toward the reader.
static func _piles_laid(piles: Array, shapes: Array, hand: Array, rows: int, n: int) -> Array:
	var out: Array = []
	out.resize(n)
	var per := int(ceil(float(piles.size()) / float(rows)))
	var back := -0.085 if rows == 1 else -0.165 - CARD.y * 0.5
	for r in rows:
		var members := range(r * per, mini((r + 1) * per, piles.size()))
		var width := 0.0
		var depth := 0.0
		for q in members:
			width += ((shapes[q] as Dictionary)["size"] as Vector2).x
			depth = maxf(depth, ((shapes[q] as Dictionary)["size"] as Vector2).y)
		width += PILE_GAP * float(maxi(members.size() - 1, 0))
		var x := -width * 0.5
		var z := back if rows == 1 else back + depth * 0.5
		for q in members:
			var sz: Vector2 = (shapes[q] as Dictionary)["size"]
			var cx := x + sz.x * 0.5
			var offs: Array = (shapes[q] as Dictionary)["offs"]
			for j in offs.size():
				var i := int(((piles[q] as Dictionary)["cards"] as Array)[j])
				var at: Vector2 = (offs[j] as Dictionary)["at"]
				var h: Array = hand[i]
				out[i] = {"pos": Vector3(cx + at.x, 0.0, z + at.y) + (h[0] as Vector3),
					"yaw": float((offs[j] as Dictionary)["yaw"]) + float(h[1]), "face": "up"}
			x += sz.x + PILE_GAP
		back += depth + PILE_GAP
	return out


static func _laid(pos: Array, hand: Array, turned: bool, deck: Vector3) -> Array:
	var out: Array = []
	for i in pos.size():
		var p: Vector3 = (pos[i] as Vector3) + ((hand[i] as Array)[0] as Vector3)
		var yaw := float((hand[i] as Array)[1])
		if turned:
			yaw += -p.x * 0.6
		out.append({"pos": p, "yaw": yaw})
	# CLEAR OF THE DECK: two rows of eight or a tight arc reach the deck's corner of the table, and
	# were laid through it - the whole spread steps back, or aside, by the least that clears it
	var off := CardTable.clear_of(out, CARD, deck_keep(deck))
	for sl in out:
		(sl as Dictionary)["pos"] = ((sl as Dictionary)["pos"] as Vector3) + Vector3(off.x, 0.0, off.y)
	return out


static func _rows(n: int, gap: float) -> Array:
	var pos: Array = []
	var top := int(ceil(n / 2.0))
	for i in n:
		var row := 0 if i < top else 1
		var k: int = i if row == 0 else i - top
		var cnt: int = top if row == 0 else n - top
		pos.append(Vector3((float(k) - float(cnt - 1) * 0.5) * gap, 0.0, -0.165 + float(row) * CARD.y * 1.12))
	return pos


static func _in_frame(slots: Array, lay: Dictionary) -> bool:
	for s in slots:
		var foot := CardTable.footprint(s["pos"], float(s["yaw"]), CARD)
		if not _frame_trouble(foot, lay).is_empty():
			return false
	return true


## The rectangle (x by z) round the deck kept at [param deck] that no card may lie in - or round the box
## the cards are kept in there, [param box] across and deep ([method box_at]).
static func deck_keep(deck: Vector3, box := Vector2.ZERO) -> Rect2:
	if box != Vector2.ZERO:
		var mid := box_at(deck)
		return Rect2(mid.x - box.x * 0.5 - DECK_CLEAR, mid.z - box.y * 0.5 - DECK_CLEAR,
			box.x + DECK_CLEAR * 2.0, box.y + DECK_CLEAR * 2.0)
	return Rect2(deck.x - CARD.x * 0.5 - DECK_CLEAR, deck.z - CARD.y * 0.5 - DECK_CLEAR,
		CARD.x + DECK_CLEAR * 2.0, CARD.y + DECK_CLEAR * 2.0)


## WHERE THE BOX THE CARDS ARE KEPT IN STANDS, for a deck kept at [param deck]: a little behind it and
## farther out, so a box as big as [constant CardTable.BOX_MAX] stands in the picture, beside the spread.
static func box_at(deck: Vector3) -> Vector3:
	return Vector3(deck.x + signf(deck.x) * 0.03, 0.0, deck.z - 0.04)


## THE POSITIONS THE CARDS WERE GIVEN, as slots (`[{pos, yaw}]`) - each card's `position` carrying
## `x` and `z` (a plan's, or a dealer's laid over it) - or [] when any card has none or the set has a
## trouble ([method troubles]) - [param top], the table's top made safe, when it is set: the table
## then lays its preset.
static func given(cards: Array, seed: int, top: Dictionary = {}, box := Vector2.ZERO) -> Array:
	var out: Array = []
	for i in cards.size():
		var p: Variant = (cards[i] as Dictionary).get("position", {}) if cards[i] is Dictionary else {}
		if not (p is Dictionary) or not _numeric((p as Dictionary).get("x")) or not _numeric((p as Dictionary).get("z")):
			return []
		out.append(slot_of(p as Dictionary, i))
	if out.is_empty() or not troubles(out, seed, top, box).is_empty():
		return []
	return out


## A position as a slot: `{pos, yaw (radians), face}`, lifted a hair per card as a laid card is.
static func slot_of(p: Dictionary, i: int) -> Dictionary:
	return {"pos": Vector3(float(p["x"]), (float(i) + 1.0) * 0.0002, float(p["z"])),
		"yaw": deg_to_rad(float(p.get("yaw", 0.0))), "face": String(p.get("face", "up"))}


## WHAT IS WRONG WITH THESE SLOTS for episode [param seed], card by card - `["card 2: off the cloth
## at the back", ...]` - empty when every card lies on the cloth, inside the camera's frame and clear
## of the deck - and on [param top] ([Tables]), when the table is set. Cards may lie over each other -
## a pile, a fan, the pyramid's rows do - and [method notes] says which.
static func troubles(slots: Array, seed: int, top: Dictionary = {}, box := Vector2.ZERO) -> PackedStringArray:
	var out := PackedStringArray()
	var lay := CardTable.layout_of(seed)
	var keep := deck_keep(lay["deck"], box)
	var feet: Array = []
	for i in slots.size():
		var s: Dictionary = slots[i]
		feet.append(CardTable.footprint(s["pos"], float(s["yaw"]), CARD))
	for i in slots.size():
		var why := trouble_of(slots[i], feet[i], lay, keep)
		if not top.is_empty():
			for c in corners(slots[i]):
				if not Tables.inside(top, c, HEM):
					why.append("off the edge of the table's top")
					break
		if not why.is_empty():
			out.append("card %d: %s" % [i + 1, ", ".join(why)])
	return out


## Which cards lie over which - not a trouble, a fact a dealer is told ("card 3 lies over card 2").
static func notes(slots: Array) -> PackedStringArray:
	var out := PackedStringArray()
	for i in slots.size():
		for j in i:
			if overlaps(slots[i], slots[j]):
				out.append("card %d lies over card %d" % [i + 1, j + 1])
	return out


## One card's own troubles (not the other cards'): off the cloth, out of the frame, over the deck.
static func trouble_of(slot: Dictionary, foot: Rect2, lay: Dictionary, keep: Rect2) -> PackedStringArray:
	var why := PackedStringArray()
	var cloth := Rect2(CLOTH_MIDDLE - CLOTH * 0.5, CLOTH).grow(-HEM)
	if not cloth.encloses(foot):
		var sides := PackedStringArray()
		if foot.position.x < cloth.position.x:
			sides.append("the left")
		if foot.end.x > cloth.end.x:
			sides.append("the right")
		if foot.position.y < cloth.position.y:
			sides.append("the back")
		if foot.end.y > cloth.end.y:
			sides.append("the front")
		why.append("off the cloth at " + " and ".join(sides))
	why.append_array(_frame_trouble(foot, lay))
	# a spread stepped clear of the deck touches it exactly: a millimeter is not over it
	if foot.grow(-0.001).intersects(keep):
		why.append("over the deck")
	return why


static func _frame_trouble(foot: Rect2, lay: Dictionary) -> PackedStringArray:
	for corner in [foot.position, Vector2(foot.end.x, foot.position.y), foot.end, Vector2(foot.position.x, foot.end.y)]:
		var at: Variant = CardTable.project(lay["camera"], float(lay["fov"]), Vector3(corner.x, 0.0, corner.y))
		if at == null or (at as Vector2).x < FRAME_MARGIN or (at as Vector2).x > 1.0 - FRAME_MARGIN \
				or (at as Vector2).y < FRAME_MARGIN or (at as Vector2).y > 1.0 - FRAME_MARGIN:
			return PackedStringArray(["partly out of the camera's frame"])
	return PackedStringArray()


## What a dealer is told about the table it lays on, for episode [param seed]: the cloth, where the
## deck is kept, and the stretch of cloth the camera sees.
static func describe(seed: int) -> String:
	var lay := CardTable.layout_of(seed)
	var deck: Vector3 = lay["deck"]
	var lines := PackedStringArray()
	lines.append("The cloth is %.2f m across (x from %.2f to %.2f) and %.2f m deep (z from %.2f at the back to %.2f at the front, toward the reader). A card is %.2f m wide and %.2f m tall, lying with its long side running back to front at yaw 0."
		% [CLOTH.x, CLOTH_MIDDLE.x - CLOTH.x * 0.5, CLOTH_MIDDLE.x + CLOTH.x * 0.5, CLOTH.y,
			CLOTH_MIDDLE.y - CLOTH.y * 0.5, CLOTH_MIDDLE.y + CLOTH.y * 0.5, CARD.x, CARD.y])
	lines.append("The deck is kept at x %.2f, z %.2f; keep every card clear of it." % [deck.x, deck.z])
	var seen := Rect2()
	var first := true
	for x in range(-60, 61, 2):
		for z in range(-38, 35, 2):
			var at: Variant = CardTable.project(lay["camera"], float(lay["fov"]), Vector3(x / 100.0, 0.0, z / 100.0))
			if at != null and (at as Vector2).x > FRAME_MARGIN and (at as Vector2).x < 1.0 - FRAME_MARGIN \
					and (at as Vector2).y > FRAME_MARGIN and (at as Vector2).y < 1.0 - FRAME_MARGIN:
				var pt := Vector2(x / 100.0, z / 100.0)
				seen = Rect2(pt, Vector2.ZERO) if first else seen.expand(pt)
				first = false
	lines.append("The camera sees roughly x %.2f to %.2f and z %.2f to %.2f (narrower at the back)."
		% [seen.position.x, seen.end.x, seen.position.y, seen.end.y])
	return "\n".join(lines)


## DO TWO LAID CARDS OVERLAP? As turned rectangles, not their boxes - a card in an arc is turned, and
## its box reaches past a neighbor it does not touch. Separating axes: two rectangles are apart when
## some edge's direction parts their shadows. Cards that merely touch (within a millimeter) do not.
static func overlaps(a: Dictionary, b: Dictionary) -> bool:
	var ca := corners(a)
	var cb := corners(b)
	for axis in [_axis(float(a["yaw"]), 0), _axis(float(a["yaw"]), 1), _axis(float(b["yaw"]), 0), _axis(float(b["yaw"]), 1)]:
		var ra := _shadow(ca, axis)
		var rb := _shadow(cb, axis)
		if ra.y <= rb.x + 0.001 or rb.y <= ra.x + 0.001:
			return false
	return true


## A laid card's four corners on the table (x, z).
static func corners(slot: Dictionary) -> PackedVector2Array:
	var pos: Vector3 = slot["pos"]
	var c := Vector2(pos.x, pos.z)
	var across := _axis(float(slot["yaw"]), 0) * CARD.x * 0.5
	var along := _axis(float(slot["yaw"]), 1) * CARD.y * 0.5
	return PackedVector2Array([c - across - along, c + across - along, c + across + along, c - across + along])


## A card's own directions on the table: across it (0) and along it (1), turned by [param yaw] about
## the up axis as the table turns it.
static func _axis(yaw: float, which: int) -> Vector2:
	return Vector2(cos(yaw), -sin(yaw)) if which == 0 else Vector2(sin(yaw), cos(yaw))


static func _shadow(pts: PackedVector2Array, axis: Vector2) -> Vector2:
	var lo := INF
	var hi := -INF
	for q in pts:
		var d := q.dot(axis)
		lo = minf(lo, d)
		hi = maxf(hi, d)
	return Vector2(lo, hi)


static func _numeric(v: Variant) -> bool:
	return typeof(v) in [TYPE_INT, TYPE_FLOAT]
