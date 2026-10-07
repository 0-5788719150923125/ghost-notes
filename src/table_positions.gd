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
## camera and deck ([method TarotTable.layout_of]), which are a function of its seed, so a plan or a
## dealer is told exactly what the table will do. A set of positions with any trouble is not used:
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


## THE SEEDED SPREAD, as the table has always laid it: a preset picked per episode from [param rng],
## within reach of the camera, clear of the deck, each card a hair off true as a hand lays them -
## for the episode's layout [param lay] ([method TarotTable.layout_of]: its camera and its deck).
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
	var off := TarotTable.clear_of(out, CARD, deck_keep(deck))
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
		var foot := TarotTable.footprint(s["pos"], float(s["yaw"]), CARD)
		if not _frame_trouble(foot, lay).is_empty():
			return false
	return true


## The rectangle (x by z) round the deck kept at [param deck] that no card may lie in.
static func deck_keep(deck: Vector3) -> Rect2:
	return Rect2(deck.x - CARD.x * 0.5 - DECK_CLEAR, deck.z - CARD.y * 0.5 - DECK_CLEAR,
		CARD.x + DECK_CLEAR * 2.0, CARD.y + DECK_CLEAR * 2.0)


## THE POSITIONS THE CARDS WERE GIVEN, as slots (`[{pos, yaw}]`) - each card's `position` carrying
## `x` and `z` (a plan's, or a dealer's laid over it) - or [] when any card has none or the set has a
## trouble ([method troubles]): the table then lays its preset.
static func given(cards: Array, seed: int) -> Array:
	var out: Array = []
	for i in cards.size():
		var p: Variant = (cards[i] as Dictionary).get("position", {}) if cards[i] is Dictionary else {}
		if not (p is Dictionary) or not _numeric((p as Dictionary).get("x")) or not _numeric((p as Dictionary).get("z")):
			return []
		out.append(slot_of(p as Dictionary, i))
	if out.is_empty() or not troubles(out, seed).is_empty():
		return []
	return out


## A position as a slot: `{pos, yaw (radians), face}`, lifted a hair per card as a laid card is.
static func slot_of(p: Dictionary, i: int) -> Dictionary:
	return {"pos": Vector3(float(p["x"]), (float(i) + 1.0) * 0.0002, float(p["z"])),
		"yaw": deg_to_rad(float(p.get("yaw", 0.0))), "face": String(p.get("face", "up"))}


## WHAT IS WRONG WITH THESE SLOTS for episode [param seed], card by card - `["card 2: off the cloth
## at the back", ...]` - empty when every card lies on the cloth, inside the camera's frame and clear
## of the deck. Cards may lie over each other - a pile, a fan, the pyramid's rows do - and
## [method notes] says which.
static func troubles(slots: Array, seed: int) -> PackedStringArray:
	var out := PackedStringArray()
	var lay := TarotTable.layout_of(seed)
	var keep := deck_keep(lay["deck"])
	var feet: Array = []
	for i in slots.size():
		var s: Dictionary = slots[i]
		feet.append(TarotTable.footprint(s["pos"], float(s["yaw"]), CARD))
	for i in slots.size():
		var why := trouble_of(slots[i], feet[i], lay, keep)
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
		var at: Variant = TarotTable.project(lay["camera"], float(lay["fov"]), Vector3(corner.x, 0.0, corner.y))
		if at == null or (at as Vector2).x < FRAME_MARGIN or (at as Vector2).x > 1.0 - FRAME_MARGIN \
				or (at as Vector2).y < FRAME_MARGIN or (at as Vector2).y > 1.0 - FRAME_MARGIN:
			return PackedStringArray(["partly out of the camera's frame"])
	return PackedStringArray()


## What a dealer is told about the table it lays on, for episode [param seed]: the cloth, where the
## deck is kept, and the stretch of cloth the camera sees.
static func describe(seed: int) -> String:
	var lay := TarotTable.layout_of(seed)
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
			var at: Variant = TarotTable.project(lay["camera"], float(lay["fov"]), Vector3(x / 100.0, 0.0, z / 100.0))
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
