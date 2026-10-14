extends RefCounted
class_name TableCardPose

## TableCardPose - where each drawn card is at a moment of the show: taken from the deck or the
## box, dealt, laid, turned, held up to be read, a jumper's flight, a card searched for in the box,
## and how it rests when another comes down on it. A part of [TableMedium].
##
## NO STATE OF ITS OWN. [method card_pose] is card i at show time t, read off the episode's plan
## ([TablePlan]), the schedule the reading laid down, and where the box's cards are filed; the
## medium's frame loop applies what it answers to the meshes. So a pose is the same whenever it is
## asked - live, in an export, after a scrub, or ahead of time on another thread - which is what
## makes it safe to compute in any order (next/structure.md, "Many kinds of show, and rounds").
##
## WHAT IT IS HANDED is written out: every `medium.` below is something it reads of the table -
## mostly the plan (`medium._plan`), the timing constants a show shares, and where the box and the
## deck are now. [method card_pose], [method looks], [method held_span], [method searched_xf],
## [method search_looks] and [method jump_riffle] are what the table asks of it.

## The [TableMedium] this is a part of: everything read through it is something this part
## is handed, and the list of them is what it depends on.
var medium: TableMedium

const PRESENT := Vector2(-0.087, 0.012)
## A card with its text on either face ([constant CardTable.TEXTS]) is held up alone, in the middle
## and a little nearer: there is no page beside it.
const PRESENT_ALONE := Vector2(0.0, 0.006)
const PRESENT_ALONE_DIST := 0.205
## ...and it is turned over to show that text: first this long after it is up, held there this long.
const BACK_LOOK := Vector2(3.5, 5.5)
const BACK_HOLD := Vector2(5.0, 8.0)
const SLIDE_END := 1.0        # the top card slides off toward the reader
const FLIP_END := 1.9         # ...lifts and turns over
const PAGE_IN := Vector2(2.6, 3.4)
const LAY_PAGE_OUT := 0.5
const LAY_MOVE := Vector2(0.15, 1.45)
const JUMP_REST := 3.3
const JUMP_PAGE := Vector2(4.2, 5.0)
const SWEEP_FLAT := 0.25
## ...after it is slid out from under whatever lies on it ([method _slid_out]), in the first of that.
const SHOW_SLIDE := 0.45
const SLIDE_STEP := 0.004
const SLIDE_MOST := 0.2
const SHOW_PAGE := Vector2(0.9, 1.6)
const SEARCH_RISE := 0.62
const SEARCH_RISE_LEAST := 0.4
const SEARCH_TIP := 0.2
const SEARCH_TURN := 0.75
const SEARCH_LOOKS_LYING := 2
## A card pulled from the box rises this far above the rim before it turns to the camera.
const PULL_CLEAR := 0.02
## A card laid down arcs this high over the cloth on its way (meters) - and is lifted higher while the
## box stands in its way ([method _lay_lift]): sampled in LAY_SAMPLES steps, the lift eased away over
## LAY_EASE of the way after the box and over the last LAY_LAND of it.
const LAY_ARC := 0.05
const LAY_LIFT_MAX := 0.3
const LAY_SAMPLES := 32
const LAY_EASE := 0.08
const LAY_LAND := 0.04
## A card's edge may lie this far over the box's rim (meters) before the arc lifts it: the last of its
## descent, tilted still, reaches a few millimeters past where it lies, and the spread leaves the box
## more than this (TablePositions.DECK_CLEAR).
const BOX_GRAZE := 0.008
## A held card is turned over now and then, to look at its back ([method _look_of]): the chance a
## card is at all, the chance of each look after that, the seconds between looks, how long a turn
## takes (each its own), and how long its back is looked at - drawn evenly in its logarithm, so most
## looks are short and now and then one is long (a fixed-feeling 1.1-1.8 s was reported as "the
## exact same length, always"). Most cards are never turned: 4-5 looks in one draw was too many.
const TURN_CHANCE := 0.25
const LOOK_AGAIN := 0.25
const LOOK_GAP := Vector2(25.0, 45.0)
const TURN_HOLD := Vector2(0.6, 5.0)
## THE PIROUETTE (the user's, 2026-10-05: "the kind of trick a person might do in their own hands
## to show off"): the chance a look ends in one - over to the back and held there a few seconds,
## then on round the SAME way, five half turns more, to face on again three whole turns from where
## it started - the hold, and how long the twirl takes. Rare, and once a card at most: the plain
## half turn is the common look.
const PIROUETTE_CHANCE := 0.1

# --- posing everything ------------------------------------------------------------------------

## Where the [param which]-th card a search looks at waits: its place in the box (`_box["search"]`) - or,
## where a tin's flat deck has no place of its own for it, off the middle of what lies there.
func _search_seat(which: int) -> Transform3D:
	var inner: AABB = medium._box["inner"]
	var seats: Array = medium._box.get("search", [])
	if seats.is_empty():
		return Transform3D(Basis.IDENTITY, Vector3(inner.get_center().x, inner.position.y + 0.004, inner.get_center().z))
	return seats[which % seats.size()]


## How many cards one search looks at ([constant SEARCH_LOOKS]; [constant SEARCH_LOOKS_LYING] where the
## box's cards lie): they share the one rest the voice takes for a search ([constant TableActions.RUMMAGE]).
func search_looks() -> int:
	return TableMedium.SEARCH_LOOKS if absf(_search_seat(0).basis.y.normalized().y) < 0.7 else SEARCH_LOOKS_LYING


## HOW FAR OF ITS HEIGHT [param v] a card on edge at [param seat] is drawn up to be looked at
## ([constant SEARCH_RISE]) - less, down to [constant SEARCH_RISE_LEAST], while the picture's top edge
## would cut into its painting, an eighth of the card down from its top: a box at the back of the table
## stands near the frame's top, and a front that cannot be seen is the look wasted. [param up] is the
## way it rises and [param axis] what it leans back about.
func _search_rise(seat: Transform3D, up: Vector3, v: float, axis: Vector3) -> float:
	var hinge := seat.origin + up * v * 0.5
	var tip := Basis(axis, SEARCH_TIP)
	var rise := SEARCH_RISE
	while rise > SEARCH_RISE_LEAST:
		var at: Variant = CardTable.project(medium._plan.cam_base, medium._cam.fov, hinge + tip * (up * v * (rise - 0.125)))
		if at != null and (at as Vector2).y > 0.0:
			break
		rise = maxf(SEARCH_RISE_LEAST, rise - 0.02)
	return rise


## A LYING CARD TURNED UP TO THE EYE, its FACE showing and the right way up: turned over about its long
## side from where it lay face down, its far edge [constant SEARCH_TURN] up from lying.
static func _turned_up() -> Basis:
	var a := PI * 0.5 - SEARCH_TURN
	return Basis(Vector3(-1.0, 0.0, 0.0), Vector3(0.0, -sin(a), -cos(a)), Vector3(0.0, -cos(a), sin(a)))


## The card a search is looking at, the [param which]-th it has looked at, [param beat] (0 to 1) of
## the way through its look ([method _pose_rummage]).
func searched_xf(which: int, beat: float) -> Transform3D:
	var inner: AABB = medium._box["inner"]
	var world: AABB = medium._box["world"]
	var size := CardTable.card_size(medium._plan.look)
	var seat := _search_seat(which)
	var lift := smoothstep(0.05, 0.38, beat) * (1.0 - smoothstep(0.62, 0.95, beat))
	var look := smoothstep(0.18, 0.44, beat) * (1.0 - smoothstep(0.56, 0.82, beat))
	var n := seat.basis.y.normalized()
	if absf(n.y) < 0.7:
		# ON EDGE: up along its own plane, then leaned about the line where it leaves the file - its
		# top away from the eye, which looks down on it, so the side it shows the eye turns up to it
		var up := (Vector3.UP - n * n.y).normalized()
		var v := size.y if bool(medium._box.get("upright", true)) else size.x
		var hinge := seat.origin + up * v * 0.5
		var shown := n if n.dot(medium._plan.cam_base.origin - seat.origin) > 0.0 else -n
		var axis := shown.cross(up).normalized()
		var tip := Basis(axis, SEARCH_TIP * look)
		return Transform3D(tip * seat.basis, hinge + tip * (seat.origin + up * v * _search_rise(seat, up, v, axis) * lift - hinge))
	# LYING, face down: lifted clear of the rim, turned over toward the eye and the right way round, and
	# turned back as it is laid down - up sooner and held longer than a card on edge, a turn over being
	# half a turn each way. High enough to turn with its low edge a centimeter over the rim -
	# and no higher than the picture: a box at the back of the table stands near the frame's top, and
	# the card's far edge went out of it (2026-10-12) - the picture's top edge may cut the card's border,
	# an eighth of it, never its painting. Never lower than it takes to turn the card over clear of its
	# pile.
	var half := sin(SEARCH_TURN) * size.y * 0.5
	var reach := cos(SEARCH_TURN) * size.y * 0.5
	# toward the eye, and never through the wall: held low, in a box near the frame's top, the card's
	# near edge is under the rim, and a pile by the front wall brought it out through the cardboard
	var toward := minf(world.size.z * 0.15, inner.end.z - 0.004 - reach - seat.origin.z)
	var least := seat.origin.y + half + 0.005
	var clear := maxf(maxf(world.end.y, inner.end.y) + half + 0.01, least)
	while clear > least:
		var edge: Variant = CardTable.project(medium._plan.cam_base, medium._cam.fov,
			Vector3(seat.origin.x, clear + half * 0.75, seat.origin.z + toward - reach * 0.75))
		if edge != null and (edge as Vector2).y > 0.0:
			break
		clear = maxf(least, clear - 0.004)
	lift = smoothstep(0.03, 0.25, beat) * (1.0 - smoothstep(0.75, 0.97, beat))
	look = smoothstep(0.12, 0.4, beat) * (1.0 - smoothstep(0.6, 0.88, beat))
	var basis := seat.basis.orthonormalized().slerp(_turned_up(), look)
	# ON ITS WAY OVER A CARD STANDS ON A CORNER, lower than it is held: it is carried as high as keeps
	# its lowest corner where the held card's low edge would be, so it never turns down into its pile
	var low := (size.x * absf(basis.x.y) + size.y * absf(basis.z.y)) * 0.5
	var up := maxf((clear - seat.origin.y) * lift, (clear - half - 0.002 - seat.origin.y) * lift + low)
	# ...and reaches further toward the eye than it does held: no nearer the front wall than that corner
	# allows, and never moved off its pile for it
	var near := (size.x * absf(basis.x.z) + size.y * absf(basis.z.z)) * 0.5
	var come := minf(toward * look, maxf(0.0, inner.end.z - 0.004 - near - seat.origin.z))
	return Transform3D(basis, seat.origin + Vector3(0.0, up, come))


## CARD [param k] AT [param t], from its timeline [param ev] ([method _times]): `{xf, visible, up (held
## up), page (how far its booklet page is open), since (when its last event began)}`. The state the
## events before the one under way left it in - lying (its quarter turns, turned over or not) or held
## up - and the event under way posed from it. A card no event has reached waits in its source: unseen
## in a deck, standing in its place in a box's file.
func card_pose(k: int, t: float, ev: Array, wj: Dictionary) -> Dictionary:
	var out := {"xf": Transform3D.IDENTITY, "visible": false, "up": false, "page": 0.0, "since": 0.0}
	var cur := -1
	for i in ev.size():
		if t >= float((ev[i] as Dictionary)["t0"]) and float((ev[i] as Dictionary)["t0"]) < INF:
			cur = i
	if cur < 0:
		if medium._filed() and k < (medium._box["at_k"] as Array).size():
			out["visible"] = true
			out["xf"] = (medium._box["at_k"] as Array)[k]
		return out
	out["visible"] = true
	# the state the events before the current one left - a card laid sideways can be untapped upright
	var cards: Array = medium._plan.pay.get("cards", [])
	var least := -1 if k < cards.size() and TablePositions.lies_sideways(cards[k]) else 0
	var quarter := 0
	var over := false
	var up_at := INF
	var up_ev := -1
	for i in cur:
		var e: Dictionary = ev[i]
		var s := maxf(float(e["s"]), 0.05)
		match String(e["k"]):
			"arrive":
				if String(e["how"]) in ["draw", "jumper"]:
					up_at = float(e["t0"]) + (float(e["off"]) + (TableMedium.JUMP_RISE if String(e["how"]) == "jumper" else TableMedium.RISE_END)) * s
					up_ev = i
			"show":
				up_at = float(e["t0"]) + (float(e["off"]) + TableMedium.SHOW_RISE) * s
				up_ev = i
			"turn":
				match String(e["how"]):
					"tap":
						quarter += 1
					"untap":
						quarter = maxi(quarter - 1, least)
					"flip":
						over = not over
	var e: Dictionary = ev[cur]
	var s := maxf(float(e["s"]), 0.05)
	var t0 := float(e["t0"])
	var u := (t - t0) / s - float(e["off"])
	out["since"] = t0
	# WHERE IT LIES, on whatever lay there first ([method _rest_lift]) - for a card picked up, as it lay
	# at that moment
	var lying := medium._slot_xf(k, quarter, over)
	var lay_t := minf(t, t0 + float(e["off"]) * s) if String(e["k"]) == "show" else t
	lying.origin.y += _rest_lift(k, lay_t)
	# when the card held up now goes down: the next event's start, if it is a lay
	var until := INF
	if cur + 1 < ev.size() and String((ev[cur + 1] as Dictionary)["k"]) == "lay":
		until = float((ev[cur + 1] as Dictionary)["t0"])
	match String(e["k"]):
		"arrive":
			var how := String(e["how"])
			if u < 0.0 and how != "fan":
				# the card before is still going down: this one waits in its source
				out["xf"] = _source_xf(k)
				return out
			match how:
				"draw":
					var at := t0 + (float(e["off"]) + TableMedium.RISE_END) * s
					out["xf"] = _take_xf(k, u, _present_xf(k, t, at, until), TableMedium.RISE_END)
					out["up"] = true
					if u >= PAGE_IN.x:
						out["page"] = TableMedium._ease(clampf((u - PAGE_IN.x) / (PAGE_IN.y - PAGE_IN.x), 0.0, 1.0))
				"jumper":
					var at := t0 + (float(e["off"]) + TableMedium.JUMP_RISE) * s
					var pres := _present_xf(k, t, at, until)
					if not wj.is_empty():
						# out of a wash: in it, as one of its cards, until it is thrown
						if t < float(wj["eject"]):
							out["visible"] = false
							return out
						out["xf"] = _wash_jump_xf(u, t, t0 + JUMP_REST * s, pres, wj)
					else:
						out["xf"] = _jump_xf(k, u, pres)
					out["up"] = true
					if u >= JUMP_PAGE.x:
						out["page"] = TableMedium._ease(clampf((u - JUMP_PAGE.x) / (JUMP_PAGE.y - JUMP_PAGE.x), 0.0, 1.0))
				"deal":
					out["xf"] = _take_xf(k, u, lying, TableMedium.DEAL_END)
				"fan":
					var v := u - TableActions.FAN_EACH * float(e.get("i", 0))
					if v < 0.0:
						# still in its source: one of the deck's own until it leaves (a box's stands in its file)
						out["xf"] = _source_xf(k)
						out["visible"] = medium._filed()
					else:
						out["xf"] = _sweep_xf(k, v, lying)
		"show":
			var at := t0 + (float(e["off"]) + TableMedium.SHOW_RISE) * s
			var pres := _present_xf(k, t, at, until)
			# out from under a card lying on it first, along the cloth; then up
			var clear := _slid_out(k, lying, t0 + float(e["off"]) * s)
			var slid := 0.0 if clear.is_equal_approx(lying) else SHOW_SLIDE
			if u < 0.0:
				out["xf"] = lying
			elif u < slid:
				out["xf"] = lying.interpolate_with(clear, TableMedium._ease(u / slid))
			elif u < TableMedium.SHOW_RISE:
				var f := TableMedium._ease((u - slid) / (TableMedium.SHOW_RISE - slid))
				var xf := clear.interpolate_with(pres, f)
				xf.origin.y += sin(PI * f) * 0.025
				out["xf"] = xf
			else:
				out["xf"] = pres
			out["up"] = u >= 0.0
			if u >= SHOW_PAGE.x:
				out["page"] = TableMedium._ease(clampf((u - SHOW_PAGE.x) / (SHOW_PAGE.y - SHOW_PAGE.x), 0.0, 1.0))
		"lay":
			# the card held up goes down into its place
			var from := _present_xf(k, t0, up_at, t0)
			var lay_u := (t - t0) / s
			if lay_u < TableMedium.LAY_END:
				var f := TableMedium._ease(clampf((lay_u - LAY_MOVE.x) / (LAY_MOVE.y - LAY_MOVE.x), 0.0, 1.0))
				var xf := from.interpolate_with(lying, f)
				xf.origin.y += _lay_lift(from, lying, f)
				if lay_u > LAY_MOVE.y:
					xf.origin.y += (1.0 - clampf((lay_u - LAY_MOVE.y) / (TableMedium.LAY_END - LAY_MOVE.y), 0.0, 1.0)) * 0.002
				out["xf"] = xf
				if lay_u < LAY_PAGE_OUT:
					out["page"] = 1.0 - TableMedium._ease(lay_u / LAY_PAGE_OUT)
			else:
				out["xf"] = lying
		"turn":
			var how := String(e["how"])
			var to := medium._slot_xf(k, quarter + (1 if how == "tap" else (-1 if how == "untap" and quarter > least else 0)),
				not over if how == "flip" else over)
			to.origin.y += _rest_lift(k, t)
			var span := TableMedium.FLIP_END_LAY if how == "flip" else TableMedium.TURN_END
			var f := TableMedium._ease(clampf(u / span, 0.0, 1.0))
			var xf := lying.interpolate_with(to, f)
			xf.origin.y += sin(PI * f) * (0.03 if how == "flip" else 0.003)
			out["xf"] = xf if u > 0.0 else lying
	if up_ev >= 0 and String(e["k"]) == "lay":
		out["since"] = float((ev[up_ev] as Dictionary)["t0"])
	return out


## WHEN THE CARD WHOSE TIMELINE IS [param ev] WAS LAST SET DOWN, as of [param t]: the moment it lands -
## counted from the start of its way down, so what it comes to rest on is settled before it arrives -
## or INF while it is in its source or in a hand. A card being picked up still lies until it has slid
## out ([constant SHOW_SLIDE]): what lies on it stays up until then.
func _down_at(ev: Array, t: float) -> float:
	var down := INF
	for item in ev:
		var e: Dictionary = item
		var t0 := float(e["t0"])
		if t0 == INF or t < t0:
			break
		var s := maxf(float(e["s"]), 0.05)
		var off := float(e["off"])
		match String(e["k"]):
			"arrive":
				match String(e["how"]):
					"fan":
						down = t0 + (off + TableActions.FAN_EACH * float(e.get("i", 0)) + TableMedium.FAN_MOVE) * s
					"deal":
						down = t0 + (off + TableMedium.DEAL_END) * s
					_:
						down = INF
			"show":
				if t >= t0 + (off + SHOW_SLIDE) * s:
					down = INF
			"lay":
				down = t0 + TableMedium.LAY_END * s
	return down


## HOW MUCH HIGHER CARD [param k] LIES at [param t] than its place alone says: ON every card set down
## before it that it overlaps, a card's thickness above the highest of them. The spread's own heights
## are a hair apart in the order the cards are dealt, which a card picked up and put back breaks: in
## the Libra reading (true-tarot 871516, the user: the second card "was pulled THROUGH the 1st") a
## waterfall's first card went back down under the second, through it. What lies on what follows from
## when each was set down ([method _down_at]), so a card put back lies on top.
func _rest_lift(k: int, t: float) -> float:
	if medium._laps_of(k).is_empty() or k >= medium._all_events.size():
		return 0.0
	var downs := PackedFloat32Array()
	var order: Array = []
	for j in mini(medium._all_events.size(), medium._plan.slots.size()):
		downs.append(_down_at(medium._all_events[j], t))
		if downs[j] < INF:
			order.append(j)
	if downs[k] == INF:
		return 0.0
	order.sort_custom(func(a: int, b: int) -> bool: return downs[a] < downs[b] or (downs[a] == downs[b] and a < b))
	var high := {}
	for j in order:
		var h := float((medium._plan.slots[j]["pos"] as Vector3).y)
		for i in medium._laps_of(j):
			if high.has(i):
				h = maxf(h, float(high[i]) + TableMedium.CARD_T)
		high[j] = h
		if j == k:
			break
	return float(high[k]) - float((medium._plan.slots[k]["pos"] as Vector3).y)


## CARD [param k] SLID OUT from under the cards lying on it at [param t] (set down after it, over its
## place), from [param lying]: along the cloth, the shortest way that clears them all without running
## into a card lying beside it, the deck or the cloth's edge - straight away from them when that is as
## short as any. It was lifted straight up through them (the user, 2026-10-11: "it may have looked even
## better to slide the 2nd card out to the right"). [param lying] itself when nothing lies on it, or
## there is no way out.
func _slid_out(k: int, lying: Transform3D, t: float) -> Transform3D:
	var laps := medium._laps_of(k)
	if laps.is_empty() or k >= medium._all_events.size():
		return lying
	var mine := _down_at(medium._all_events[k], t)
	var over: Array = []
	var beside: Array = []
	var from := Vector2.ZERO
	for j in mini(medium._all_events.size(), medium._plan.slots.size()):
		if j == k:
			continue
		var down := _down_at(medium._all_events[j], t)
		if down == INF:
			continue
		var place := {"pos": medium._plan.slots[j]["pos"], "yaw": float(medium._plan.slots[j]["yaw"])}
		if not laps.has(j):
			beside.append(place)
		elif down > mine:
			over.append(place)
			from += Vector2((place["pos"] as Vector3).x, (place["pos"] as Vector3).z)
	if over.is_empty() or mine == INF:
		return lying
	var yaw := float(medium._plan.slots[k]["yaw"])
	var at := Vector2(lying.origin.x, lying.origin.z)
	var away := (at - from / float(over.size())).normalized()
	if away == Vector2.ZERO:
		away = Vector2.RIGHT
	var keep := TablePositions.deck_keep(medium._deck_base, medium._box_keep(), medium._box_center())
	var cloth := Rect2(TablePositions.CLOTH_MIDDLE - TablePositions.CLOTH * 0.5, TablePositions.CLOTH).grow(-TablePositions.HEM)
	if not cloth.encloses(CardTable.footprint(lying.origin, yaw, TableMedium.CARD)):
		cloth = cloth.grow(1.0)      # a place given past the hem: the hem is no wall to it
	var best := INF
	var way := Vector2.ZERO
	for turn in [0.0, 0.4, -0.4, 0.8, -0.8, 1.2, -1.2, 1.6, -1.6, 2.0, -2.0, 2.4, -2.4, 2.8, -2.8]:
		var dir := away.rotated(turn)
		var d := SLIDE_STEP
		while d < minf(best, SLIDE_MOST):
			var p := at + dir * d
			var moved := {"pos": Vector3(p.x, 0.0, p.y), "yaw": yaw}
			var foot := CardTable.footprint(moved["pos"], yaw, TableMedium.CARD)
			if foot.intersects(keep) or not cloth.encloses(foot) \
					or beside.any(func(b: Dictionary) -> bool: return TablePositions.overlaps(moved, b)):
				break
			if not over.any(func(b: Dictionary) -> bool: return TablePositions.overlaps(moved, b)):
				best = d
				way = dir
				break
			d += SLIDE_STEP
	if best == INF:
		return lying
	return Transform3D(lying.basis, lying.origin + Vector3(way.x, 0.0, way.y) * (best + SLIDE_STEP))


## HOW HIGH A CARD LAID DOWN IS LIFTED at [param f] of its way (0..1, eased) from [param from] (held up)
## to [param to] (lying): the usual [constant LAY_ARC]'s arc, or - when the straight way there carries
## the card across the box the cards are kept in - enough to hold its lowest edge [constant PULL_CLEAR]
## over the box's top for every step it is over it, kept there until it has passed the rim and eased
## down after (the card's footprint, turned as it is at each step; [constant LAY_SAMPLES] steps), and
## gone by the time it lies. Feedback 0010: a card laid behind the box went down through it.
func _lay_lift(from: Transform3D, to: Transform3D, f: float) -> float:
	var lift := sin(PI * f) * LAY_ARC
	if medium._box.is_empty():
		return lift
	var world: AABB = medium._box["world"]
	var rim := Rect2(world.position.x, world.position.z, world.size.x, world.size.z).grow(-BOX_GRAZE)
	var step := 1.0 / float(LAY_SAMPLES)
	for s in range(1, LAY_SAMPLES):
		var fs := float(s) * step
		var xf := from.interpolate_with(to, fs)
		var b := xf.basis
		# half the card's extent along each world axis, turned as it is
		var half := Vector3(
			TableMedium.CARD.x * absf(b.x.x) + TableMedium.CARD.y * absf(b.z.x) + TableMedium.CARD_T * absf(b.y.x),
			TableMedium.CARD.x * absf(b.x.y) + TableMedium.CARD.y * absf(b.z.y) + TableMedium.CARD_T * absf(b.y.y),
			TableMedium.CARD.x * absf(b.x.z) + TableMedium.CARD.y * absf(b.z.z) + TableMedium.CARD_T * absf(b.y.z)) * 0.5
		if not Rect2(xf.origin.x - half.x, xf.origin.z - half.z, half.x * 2.0, half.z * 2.0).intersects(rim):
			continue
		var need := world.end.y + PULL_CLEAR + half.y - xf.origin.y
		# held for the step either side, eased away over LAY_EASE after
		var held := 1.0 - smoothstep(0.0, LAY_EASE, absf(f - fs) - step)
		lift = maxf(lift, need * held)
	# set down: nothing is left of it where the card lies
	return minf(lift, LAY_LIFT_MAX) * smoothstep(1.0, 1.0 - LAY_LAND, f)


## WHERE CARD [param k] WAITS before it is taken: on top of the deck, or standing in the box's file (on
## top of a tin's flat deck).
func _source_xf(k: int) -> Transform3D:
	if medium._filed() and k < (medium._box["at_k"] as Array).size():
		return (medium._box["at_k"] as Array)[k]
	return medium._deck_top_xf(k)


## CARD [param k] TAKEN FROM ITS SOURCE to [param to], [param u] seconds into a taking of [param span]
## seconds - a draw's own phases ([method _draw_xf]) at its pace: off the top of the deck and turned
## over, or pulled straight up out of the box's file ([method _pull_xf]); then on to [param to].
func _take_xf(k: int, u: float, to: Transform3D, span: float) -> Transform3D:
	var r := u * TableMedium.RISE_END / maxf(span, 0.05)
	if medium._filed():
		return _pull_xf(k, r, to)
	return _draw_xf(k, r, to)


## A card PULLED FROM THE BOX at [param r] (a draw's phases): still in the file while the hand finds it,
## then up along its own plane until it clears the rim, then on to [param to].
func _pull_xf(k: int, r: float, to: Transform3D) -> Transform3D:
	var at: Transform3D = (medium._box["at_k"] as Array)[k]
	if r < TableMedium.SQUARE:
		return at
	var inner: AABB = medium._box["inner"]
	var v := CardTable.card_size(medium._plan.look).y if bool(medium._box.get("upright", true)) else CardTable.card_size(medium._plan.look).x
	if String(medium._plan.staging.get("contents", "file")) != "file":
		v = 0.0
	var raised := Transform3D(at.basis, Vector3(at.origin.x, maxf(inner.end.y, (medium._box["world"] as AABB).end.y) + v * 0.5 + PULL_CLEAR, at.origin.z))
	if r < FLIP_END:
		return at.interpolate_with(raised, TableMedium._ease((r - TableMedium.SQUARE) / (FLIP_END - TableMedium.SQUARE)))
	if r < TableMedium.RISE_END:
		return raised.interpolate_with(to, TableMedium._ease((r - FLIP_END) / (TableMedium.RISE_END - FLIP_END)))
	return to


## A card IN A WATERFALL at [param v] seconds of its own slide ([constant FAN_MOVE]): off the deck and
## along the cloth to [param to], low, turning face up as it goes - or pulled up out of the box first.
func _sweep_xf(k: int, v: float, to: Transform3D) -> Transform3D:
	if medium._filed():
		return _pull_xf(k, v * TableMedium.RISE_END / TableMedium.FAN_MOVE, to)
	var from := medium._deck_top_xf(k)
	if v >= TableMedium.FAN_MOVE:
		return to
	var f := TableMedium._ease(clampf(v / TableMedium.FAN_MOVE, 0.0, 1.0))
	# OFF THE DECK FLAT, then turning over (SWEEP_FLAT of the way): turning from the first, it crossed
	# the card leaving a beat behind it
	var xf := Transform3D(from.basis.orthonormalized().slerp(to.basis.orthonormalized(), smoothstep(SWEEP_FLAT, 1.0, f)),
		from.origin.lerp(to.origin, f))
	# TURNING OVER, its lower edge keeps to the line it travels: skimming at its middle's height, the
	# tilted card cut into the deck it left and into the card it came to lie on
	var b := xf.basis
	xf.origin.y += sin(PI * f) * 0.018 + (TableMedium.CARD.x * absf(b.x.y) + TableMedium.CARD.y * absf(b.z.y)) * 0.5
	return xf


## Card [param k] held up to the camera on the left: floating, turning a little on its axes as a
## card in a hand does, and now and then turned over to look at its back ([method _turn_of]) -
## between [param up_at], when it is fully up, and [param until], when it goes down.
func _present_xf(k: int, t: float, up_at := INF, until := INF) -> Transform3D:
	var c := medium._plan.cam_base.basis
	var b := Basis(-c.x, -c.z, -c.y)
	var rng_k := float(hash([medium._plan.seed_value, k]) & 0xFF) / 255.0
	var yaw := deg_to_rad(lerpf(4.0, 10.0, rng_k)) + sin(t * 0.5 + rng_k * 6.0) * deg_to_rad(3.2) \
		+ sin(t * 0.21 + rng_k * 2.0) * deg_to_rad(1.8)
	var roll := deg_to_rad(lerpf(-2.5, 2.5, fmod(rng_k * 7.3, 1.0))) + sin(t * 0.37 + 1.0) * deg_to_rad(1.3)
	var tilt := sin(t * 0.29 + rng_k * 4.0) * deg_to_rad(2.6)
	if medium._plan.alone:
		# held alone in the middle: square to the lens, the hand's sway smaller
		yaw *= 0.45
	b = Basis(c.y, yaw + _turn_of(k, t, up_at, until)) * Basis(c.x, tilt) * Basis(c.z, roll) * b
	if medium._reversed(k):
		b = Basis(c.z, PI) * b
	var at := PRESENT_ALONE if medium._plan.alone else PRESENT
	var off := Vector3(at.x + sin(t * 0.7 + rng_k) * 0.0012, at.y + sin(t * 0.9 + 1.3) * 0.0015,
		-(PRESENT_ALONE_DIST if medium._plan.alone else TableMedium.PRESENT_DIST))
	return Transform3D(b, medium._plan.cam_base * off)


## How far card [param k] is turned over at [param t] (0 face on, PI showing its back - a whole
## turn more is the same pose): a look at its back ([method _look_of]), first some seconds after it
## is up and now and then another ([constant LOOK_AGAIN]) - never while it is coming up or about to
## go down, and for most cards never.
func _turn_of(k: int, t: float, up_at: float, until: float) -> float:
	if up_at == INF or t < up_at:
		return 0.0
	for l in looks(k, up_at, until):
		var at := float((l as Dictionary)["at"])
		var look: Dictionary = (l as Dictionary)["look"]
		if t < at:
			return 0.0
		if t - at < float(look["total"]):
			return _look_angle(look, t - at)
	return 0.0


## EVERY LOOK AT CARD [param k]'s BACK while it is held - up at [param up_at], going down at
## [param until] - in order: `[{at, look}]` ([method _look_of]). What [method _turn_of] poses, and
## what the air's pirouettes are timed by, from one place.
func looks(k: int, up_at: float, until: float) -> Array:
	var out: Array = []
	if up_at == INF:
		return out
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([medium._plan.seed_value, k, "turn"])
	var at := 0.0
	var forced := k == medium._spin_card()
	if String(medium._plan.staging["text"]) == "back":
		# ITS TEXT IS ON ITS BACK: turned over to show it every time, a few seconds after it is up, and
		# held there long enough to read
		var back := RandomNumberGenerator.new()
		back.seed = hash([medium._plan.seed_value, k, "back"])
		var turn := back.randf_range(TableMedium.TURN.x, TableMedium.TURN.y)
		var look := {"way": 1.0 if back.randf() < 0.5 else -1.0, "turn": turn,
			"hold": back.randf_range(BACK_HOLD.x, BACK_HOLD.y), "twirl": 0.0, "back": back.randf_range(TableMedium.TURN.x, TableMedium.TURN.y)}
		look["total"] = float(look["turn"]) + float(look["hold"]) + float(look["back"])
		at = up_at + back.randf_range(BACK_LOOK.x, BACK_LOOK.y)
		if at + float(look["total"]) > until - 1.0:
			# a short passage: turned over at once, and back as it ends
			at = up_at + 0.4
			look["hold"] = maxf(until - 1.0 - at - turn - float(look["back"]), 0.0)
			look["total"] = float(look["turn"]) + float(look["hold"]) + float(look["back"])
			if look["hold"] <= 0.5:
				return out
		out.append({"at": at, "look": look})
		if rng.randf() > LOOK_AGAIN and not forced:
			return out
		at += float(look["total"]) + rng.randf_range(LOOK_GAP.x, LOOK_GAP.y)
	else:
		if rng.randf() > TURN_CHANCE and not forced:
			return out
		at = up_at + rng.randf_range(5.0, 9.0)
	var spun := false
	for i in 64:
		var look := _look_of(rng, not spun, forced)
		spun = spun or float(look["twirl"]) > 0.0
		if forced and float(look["twirl"]) > 0.0 and at + float(look["total"]) > until - 1.0:
			# THE TWIRL A BURST MARKS fits in somewhere while the card is held, or it is not done
			at = maxf(up_at + 1.5, until - 1.0 - float(look["total"]))
		if at + float(look["total"]) > until - 1.0:
			return out
		out.append({"at": at, "look": look})
		if rng.randf() > LOOK_AGAIN:
			return out
		at += float(look["total"]) + rng.randf_range(LOOK_GAP.x, LOOK_GAP.y)
	return out


## WHEN CARD [param k] IS HELD UP: from the moment it faces the camera to the moment it goes down (INF
## when it is never laid) - `Vector2(INF, INF)` for a card never held up - as [method _air_moments]
## reads them off [param tm] ([method _times]).
func held_span(k: int, tm: Dictionary) -> Vector2:
	var ev: Array = (tm["events"] as Array)[k] if k < (tm["events"] as Array).size() else []
	for i in ev.size():
		var e: Dictionary = ev[i]
		var td := float(e["t0"])
		if td == INF:
			continue
		var s := maxf(float(e["s"]), 0.05)
		var off := float(e["off"])
		var kind := String(e["k"])
		var how := String(e.get("how", ""))
		var up_at := INF
		if kind == "arrive" and how in ["draw", "jumper"]:
			up_at = td + (off + (TableMedium.JUMP_RISE if how == "jumper" else TableMedium.RISE_END)) * s
		elif kind == "show":
			up_at = td + (off + TableMedium.SHOW_RISE) * s
		if up_at < INF:
			var tl := float((ev[i + 1] as Dictionary)["t0"]) if i + 1 < ev.size() and String((ev[i + 1] as Dictionary)["k"]) == "lay" else INF
			return Vector2(up_at, tl)
	return Vector2(INF, INF)


## ONE LOOK AT A HELD CARD'S BACK, drawn: which way it turns (`way`, 1 or -1 - a hand turns a card
## either way), how long the turn over takes (`turn`), how long the back is held (`hold`), then
## either how long the turn back takes (`back`) or, for a PIROUETTE, the twirl on round (`twirl`) -
## the other 0; `total` its seconds. A card that has already pirouetted does not again
## ([param may_spin] false).
static func _look_of(rng: RandomNumberGenerator, may_spin := true, force := false) -> Dictionary:
	var way := 1.0 if rng.randf() < 0.5 else -1.0
	var turn := rng.randf_range(TableMedium.TURN.x, TableMedium.TURN.y)
	var spin := (rng.randf() < PIROUETTE_CHANCE or force) and may_spin
	var hold := rng.randf_range(TableMedium.PIROUETTE_HOLD.x, TableMedium.PIROUETTE_HOLD.y) if spin \
		else exp(rng.randf_range(log(TURN_HOLD.x), log(TURN_HOLD.y)))
	var twirl := rng.randf_range(TableMedium.TWIRL.x, TableMedium.TWIRL.y) if spin else 0.0
	var back := 0.0 if spin else rng.randf_range(TableMedium.TURN.x, TableMedium.TURN.y)
	return {"way": way, "turn": turn, "hold": hold, "twirl": twirl, "back": back,
		"total": turn + hold + twirl + back}


## How far a held card is turned (radians) [param v] seconds into [param look] ([method _look_of]):
## over to its back and held there; then back the way it came - or, in a pirouette, on round the
## same way: a flick that winds down onto its face, three whole turns from where it started.
static func _look_angle(look: Dictionary, v: float) -> float:
	var way := float(look["way"])
	var turn := float(look["turn"])
	var hold := float(look["hold"])
	if v < turn:
		return way * PI * TableMedium._ease(v / turn)
	if v < turn + hold:
		return way * PI
	var twirl := float(look["twirl"])
	if twirl > 0.0:
		# quick out of the hold, long to wind down (still at both ends)
		return way * (PI + 5.0 * PI * TableMedium._ease(pow(clampf((v - turn - hold) / twirl, 0.0, 1.0), 0.7)))
	return way * PI * (1.0 - TableMedium._ease((v - turn - hold) / float(look["back"])))


## A drawn card at [param u] seconds into its draw.
func _draw_xf(k: int, u: float, pres: Transform3D) -> Transform3D:
	var top := medium._deck_top_xf(k)
	if u < TableMedium.SQUARE:
		return top
	if u < SLIDE_END:
		var e := TableMedium._ease((u - TableMedium.SQUARE) / (SLIDE_END - TableMedium.SQUARE))
		var xf := top
		xf.origin += Vector3(0, 0.004 * e, 0.05 * e)
		return xf
	var slid := top
	slid.origin += Vector3(0, 0.004, 0.05)
	var lifted := slid.origin + Vector3(0, 0.085, 0.035)
	if u < FLIP_END:
		var e := TableMedium._ease((u - SLIDE_END) / (FLIP_END - SLIDE_END))
		var b := slid.basis * Basis(Vector3(0, 0, 1), PI * e)
		return Transform3D(b, slid.origin.lerp(lifted, e))
	var flipped := Transform3D(slid.basis * Basis(Vector3(0, 0, 1), PI), lifted)
	if u < TableMedium.RISE_END:
		return flipped.interpolate_with(pres, TableMedium._ease((u - FLIP_END) / (TableMedium.RISE_END - FLIP_END)))
	return pres


## Deck slot [param i] in a jumper's riffle at [param v] (its action's seconds) - eased in over the
## first moments from [param was], wherever the shuffle left that slot.
func jump_riffle(i: int, v: float, was: Transform3D) -> Transform3D:
	var xf := medium._shuffles.riffle(i, v, TableMedium.JUMP_RIFFLE, hash([medium._plan.seed_value, "jumper-riffle"]))
	return was.interpolate_with(xf, TableMedium._ease(v / 0.35)) if v < 0.35 else xf


## Where a jumper rides before it springs: on top of the riffle's right half, one card above its
## top card (so it moves with the half), from the top of the deck as the riffle begins.
func _jump_ride(k: int, v: float) -> Transform3D:
	var top := medium._shuffles.riffle(TableMedium.DECK_N - 1, v, TableMedium.JUMP_RIFFLE, hash([medium._plan.seed_value, "jumper-riffle"]))
	top.origin += top.basis.y.normalized() * TableMedium.DECK_T
	top.basis = top.basis * Basis(Vector3.UP, PI if medium._reversed(k) else 0.0)
	return medium._deck_top_xf(k).interpolate_with(top, TableMedium._ease(v / 0.35)) if v < 0.35 else top


## THE JUMPER OUT OF A WASH at [param u] seconds into its action ([param t] show time): thrown as
## the wash's card it was ([method _flight_xf]) - the drawn card's own mesh, a spread card's
## thickness - lying face up where it fell until [param rest_at], then picked up and shown.
func _wash_jump_xf(u: float, t: float, rest_at: float, pres: Transform3D, wj: Dictionary) -> Transform3D:
	var c := int(wj["card"])
	var base := float(wj["base"])
	if u < JUMP_REST:
		return _as_drawn(medium._shuffles.wash(c, t - base, wj["m"]))
	var lying := _as_drawn(medium._shuffles.wash(c, rest_at - base, wj["m"]))
	if u < TableMedium.JUMP_RISE:
		var e := TableMedium._ease((u - JUMP_REST) / (TableMedium.JUMP_RISE - JUMP_REST))
		var xf := lying.interpolate_with(pres, e)
		xf.origin.y += sin(PI * e) * 0.03
		return xf
	return pres


## A deck mesh's pose [param xf] for a drawn card's mesh: the same card, the same thickness (a drawn
## card's mesh is [constant CARD_T] thick, a deck slot's [constant DECK_T]).
static func _as_drawn(xf: Transform3D) -> Transform3D:
	xf.basis.y = xf.basis.y * (TableMedium.DECK_T / TableMedium.CARD_T)
	return xf


## A jumper at [param u] seconds into its action: riding a riffle's half, springing off it as the
## halves fall, flying to land face up, lying there a moment, then picked up and shown.
func _jump_xf(k: int, u: float, pres: Transform3D) -> Transform3D:
	var land := Transform3D(Basis(Vector3.UP, 0.6 + (PI if medium._reversed(k) else 0.0)) * TableMedium._face_up(),
		medium._plan.jump_land + Vector3(0, TableMedium.CARD_T * 0.5, 0))
	if u < TableMedium.JUMP_FLY.x:
		return _jump_ride(k, u)
	if u < TableMedium.JUMP_FLY.y:
		var top := _jump_ride(k, TableMedium.JUMP_FLY.x)
		var e := clampf((u - TableMedium.JUMP_FLY.x) / (TableMedium.JUMP_FLY.y - TableMedium.JUMP_FLY.x), 0.0, 1.0)
		var pos := top.origin.lerp(land.origin, e) + Vector3(0, sin(PI * e) * 0.13, 0)
		var b := Basis(Vector3.UP, 0.6 * e + 1.3 * PI * e) * top.basis * Basis(Vector3(0, 0, 1), 3.0 * PI * e)
		# ...COMING DOWN AS IT LIES: the tumble alone ends a third of a turn off the card's landing (it
		# snapped round as it touched the cloth), so what is left over is taken up along the flight
		var end := Basis(Vector3.UP, 0.6 + 1.3 * PI) * top.basis.orthonormalized() * Basis(Vector3(0, 0, 1), 3.0 * PI)
		var left := Quaternion(land.basis * end.orthonormalized().inverse())
		return Transform3D(Basis(Quaternion.IDENTITY.slerp(left, e)) * b, pos)
	var settle := land
	settle.origin += Vector3(0.006, 0, 0.004) * clampf((u - TableMedium.JUMP_FLY.y) / 0.4, 0.0, 1.0)
	if u < JUMP_REST:
		return settle
	if u < TableMedium.JUMP_RISE:
		var e := TableMedium._ease((u - JUMP_REST) / (TableMedium.JUMP_RISE - JUMP_REST))
		var xf := settle.interpolate_with(pres, e)
		xf.origin.y += sin(PI * e) * 0.03
		return xf
	return pres
