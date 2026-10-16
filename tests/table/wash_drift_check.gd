extends Node

## WHAT LIES ON THE CLOTH UNDER A REAL WASH ([method Drifts.laid]'s `sweeps`, the table's
## [method TableShuffle.sweeps]): petals lying where the deck is washed, judged off their planned tracks
## against the cards' own, over washes of the real plan. The user, 2026-10-14: the petals were "riding"
## cards around the wash, "which is pretty strange", and slid off the cards "yet remain attached to them
## - even though they are way out to the side". So, every step of every piece the cards met:
##
##   - none is CARRIED BY NOTHING: on the cloth and out of every card's reach it only slows, at the
##     cloth's grip at least, and never turns;
##   - none is HELD UP beside a card: a face's height, steady, out of every card's reach;
##   - none LEAPS: no step on the cloth or a face over 25 mm in 1/40 s (a shove once put one out the
##     far side of a card, a card's width in a step);
##   - none lies UNDER a card on the cloth, or in the deck (the first report: cards clipped through them);
##   - RIDES ARE RARE AND SHORT: a piece is carried on a moving card's face a small share of the time
##     (lying on a card that lies still is no ride: a wide, thin heap covers more of the cloth - 2026-10-15),
##     and most rides carry it a few centimeters - and yet the wash moves them: they are shoved, they
##     ride, they are flicked.
##
## THE CONTROL: tracks made to do what was reported, on the same washes' cards - one carried along the
## cloth beside a card, one held at a face's height beside it, one carried on it the whole way (carried
## on a moving card nearly all the time, and a long ride) - each caught by the check it was made for.
##
##   tests/run_boot_probe.sh tests/table/wash_drift_check.gd 300
##
## A BOOT probe (the medium reaches the Director); no GPU - the tracks are numbers. It takes about
## 180 s alone (2026-10-15: six washes of the real plan), so its backstop is 300.

const SEEDS := [11, 12, 13, 14, 15, 16]
const WASH_S := 22.0
## A step longer than this (meters, in 1/40 s) on the cloth or a face is a leap.
const LEAP := 0.025
## The most of the time a piece the cards met may spend carried on the face of a card that moves, and
## how far the longest tenth of the rides may carry it (meters).
const CARRIED := 0.03
const RIDE_FAR := 0.15

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
	var script := CardReading.compose([{"kind": "shuffle", "card": 0, "text": "Shuffle the deck."},
		{"kind": "draw", "card": 1, "text": "One."}, {"kind": "spread", "card": 0, "text": "Done."}])
	var cards: Array = [{"key": "c0", "name": "Card", "numeral": "0", "reversed": false, "jumper": false,
		"position": {}, "booklet": {}, "art": ""}]
	subs.document = {"source": script, "title": "Wash Drift Check",
		"table": {"show": "wash-drift-check", "seed": 3, "dir": "", "plan": {"look": {"candles": 2}}, "cards": cards}}
	medium._ensure_doc()
	medium._shuffle_room = INF
	var tot := _judged()
	var pieces := 0
	var moved := 0
	var flicked := 0
	var control: Dictionary = {}
	for sd: int in SEEDS:
		var mv := {"kind": "wash", "t0": 0.0, "dur": WASH_S, "pause": 1000.0, "seed": 500 + sd}
		mv["plan"] = medium._shuffles._wash_plan(500 + sd, WASH_S)
		medium._moves = [mv]
		var sw: Dictionary = (medium._shuffles.sweeps(10.0, INF, func(_t: float) -> Vector3: return Vector3.ZERO, "wash-drift %d" % sd) as Array)[0]
		var root := Node3D.new()
		add_child(root)
		var pop := Drifts.build(Drifts.sanitize({"look": "petals", "every": 600, "shake": 0, "settle": 1.0, "grip": 1.0, "lying": 60}),
			_stage(), sd, root)
		Drifts.at(pop, 40.0)
		Drifts.laid(pop, [], [sw])
		var m := float(pop["size"]) * 0.5
		for lv in pop["lives"]:
			for sg in (lv as Dictionary)["segs"]:
				var d: Dictionary = sg
				if String(d["kind"]) != "shoved":
					continue
				pieces += 1
				var pos: PackedVector3Array = d["pos"]
				var base := (d["from"] as Vector3).y
				var s0 := int(roundf((float(d["t"]) - float(sw["t"])) * float(d["hz"])))
				_judge(sw, pos, s0, base, m, tot)
				var far := 0.0
				var high := 0.0
				for o: Vector3 in pos:
					far = maxf(far, Vector2(o.x - pos[0].x, o.z - pos[0].z).length())
					high = maxf(high, o.y - base)
				moved += 1 if far > 0.01 else 0
				flicked += 1 if high > 0.004 else 0
		if control.is_empty():
			control = _control(sw, float(pop["rest_y"]), m)
		root.queue_free()
	var on_face := float(tot["face"]) / maxf(float(tot["samples"]), 1.0)
	var carried := float(tot["moving"]) / maxf(float(tot["samples"]), 1.0)
	var rides: Array = tot["rides"]
	rides.sort()
	var tenth: float = rides[rides.size() * 9 / 10] if not rides.is_empty() else 0.0
	print("  %d pieces met by %d washes, %d moved, %d flicked; on a card's face %.1f%% of the time, carried on one moving %.1f%%; %d rides (most %.0f mm, the longest tenth past %.0f mm)"
		% [pieces, SEEDS.size(), moved, flicked, on_face * 100.0, carried * 100.0, rides.size(), (rides.back() if not rides.is_empty() else 0.0) * 1000.0, tenth * 1000.0])
	_ok(pieces >= 30, "the washes met %d pieces lying on the cloth" % pieces)
	_ok(int(tot["carried"]) == 0, "no piece is carried by nothing: clear of every card on the cloth, %d steps sped up or turned" % tot["carried"])
	_ok(int(tot["held"]) == 0, "no piece is held up beside a card: %d steps a face high with none in reach" % tot["held"])
	_ok(int(tot["leaps"]) == 0, "no piece leaps: %d steps over %.0f mm (the longest %.1f mm)" % [tot["leaps"], LEAP * 1000.0, float(tot["leap"]) * 1000.0])
	_ok(int(tot["under"]) == 0, "no piece lies under a card or in the deck: %d steps" % tot["under"])
	_ok(carried <= CARRIED, "rides are rare: a piece is carried on a moving card %.1f%% of the time (at most %.0f%%)" % [carried * 100.0, CARRIED * 100.0])
	_ok(tenth <= RIDE_FAR, "rides are short: the longest tenth carry a piece past %.0f mm (at most %.0f)" % [tenth * 1000.0, RIDE_FAR * 1000.0])
	_ok(moved * 2 >= pieces and rides.size() >= 5 and flicked >= 5,
		"the wash moves them: %d of %d moved, %d rides, %d flicked" % [moved, pieces, rides.size(), flicked])
	# THE CONTROL: each made track caught by its own check
	_ok(not control.is_empty(), "the control found a card on the cloth that moves")
	if not control.is_empty():
		_ok(int((control["beside"] as Dictionary)["carried"]) > 0, "the control: a piece carried along the cloth beside a card is caught (%d steps)"
			% (control["beside"] as Dictionary)["carried"])
		_ok(int((control["up"] as Dictionary)["held"]) > 0, "the control: a piece held a face high beside a card is caught (%d steps)"
			% (control["up"] as Dictionary)["held"])
		var gl: Dictionary = control["glued"]
		var gl_carried := float(gl["moving"]) / maxf(float(gl["samples"]), 1.0)
		_ok(gl_carried > CARRIED * 10.0, "the control: a piece carried on a card the whole way is carried on a moving card (%.0f%% of the time)" % (gl_carried * 100.0))
		var glued: Array = (control["glued"] as Dictionary)["rides"]
		_ok(not glued.is_empty() and float(glued.max()) > RIDE_FAR, "the control: a piece carried on a card the whole way is a long ride (%.0f mm)"
			% (float(glued.max()) * 1000.0 if not glued.is_empty() else 0.0))
	print("wash_drift_check: %s" % ("ALL OK" if _fails == 0 else "%d FAILED" % _fails))
	get_tree().quit(0 if _fails == 0 else 1)


## The air the pieces lie in: a still one, over a table a meter across with the wash in its middle.
func _stage() -> Dictionary:
	var cam := Transform3D(Basis.looking_at(Vector3(0.0, -0.45, -0.6), Vector3.UP), Vector3(0.0, 0.45, 0.55))
	return {"regions": CardTable.AIR, "camera": cam, "fov": 42.0, "aspect": 16.0 / 9.0,
		"occluders": [AABB(Vector3(-0.5, -0.75, -0.35), Vector3(1.0, 0.75, 0.7))],
		"wind": Winds.plan({"from": "left", "strength": 0.0, "gusts": 0.0, "every": 60}, 3)}


func _judged() -> Dictionary:
	return {"samples": 0, "face": 0, "moving": 0, "carried": 0, "held": 0, "leaps": 0, "leap": 0.0, "under": 0, "rides": []}


## Every step of a piece's track [param pos] (1/40 s apart, the first at substep [param s0] of wash
## [param sw]; [param base] its height lying on the cloth, [param m] half its size) against the cards
## there, counted into [param tot].
func _judge(sw: Dictionary, pos: PackedVector3Array, s0: int, base: float, m: float, tot: Dictionary) -> void:
	var half := Vector2(TablePositions.CARD.x, TablePositions.CARD.y) * 0.5
	var n := int(sw["cards"])
	var st := Drifts.CARD_STRIDE
	var last := (int(sw["frames"]) - 1) * Drifts.SUBSTEPS
	var hz := float(sw["hz"]) * float(Drifts.SUBSTEPS)
	var grip := Drifts.CLOTH_GRIP / hz
	var riding := false
	var ride_from := Vector2.ZERO
	var clear := PackedFloat32Array([0.0, 0.0, 0.0])
	var out_was := 0.0
	for i in range(1, pos.size()):
		var cur := Drifts._cards_at(sw, mini(s0 + i, last))
		var p := Vector2(pos[i].x, pos[i].z)
		var h := pos[i].y - base
		# how far outside every card spread on the cloth (negative: over one), and every card on it at all
		var out := INF
		var near := INF
		var inside := INF
		var over := -1
		for j in n:
			var sp := cur[j * st + 3]
			if sp < 0.0:
				continue
			var l := Drifts._local(p, Vector2(cur[j * st], cur[j * st + 1]), cur[j * st + 2])
			var o := maxf(absf(l.x) - half.x, absf(l.y) - half.y)
			near = minf(near, o)
			inside = minf(inside, o)
			if sp >= 0.5:
				if o < out:
					over = j
				out = minf(out, o)
		clear = PackedFloat32Array([clear[1], clear[2], near])
		tot["samples"] = int(tot["samples"]) + 1
		var step := p.distance_to(Vector2(pos[i - 1].x, pos[i - 1].z))
		if step > LEAP and h < 0.003 and pos[i - 1].y - base < 0.003:
			tot["leaps"] = int(tot["leaps"]) + 1
		tot["leap"] = maxf(float(tot["leap"]), step if h < 0.003 else 0.0)
		# UNDER: on the cloth, its middle well inside a card that lies there
		if h < 0.0002 and inside < -0.002:
			tot["under"] = int(tot["under"]) + 1
		# ON A FACE: up, and over a card
		var up := h > 0.0002 and out <= 0.0
		if up:
			tot["face"] = int(tot["face"]) + 1
			# ...and CARRIED, the card under it moving
			var was := Drifts._cards_at(sw, mini(s0 + i - 1, last))
			if Vector2(cur[over * st] - was[over * st], cur[over * st + 1] - was[over * st + 1]).length() > 0.0002:
				tot["moving"] = int(tot["moving"]) + 1
			if not riding:
				ride_from = p
			riding = true
		if riding and (not up or i == pos.size() - 1):
			(tot["rides"] as Array).append(p.distance_to(ride_from))
			riding = false
		# HELD UP beside a card: a face high, steady, and no card in reach
		if i >= 2 and h > 0.00025 and absf(pos[i].y - pos[i - 1].y) < 0.00005 and absf(pos[i - 1].y - pos[i - 2].y) < 0.00005 \
				and out > m and out_was > m:
			tot["held"] = int(tot["held"]) + 1
		out_was = out
		# CARRIED BY NOTHING: lying on the cloth (not a hair over it: in the air the cloth does not slow it)
		# and out of every card's reach three steps running, moving - and not slowing at the cloth's grip,
		# or turning
		if i >= 2 and clear[0] > m + 0.002 and clear[1] > m + 0.002 and clear[2] > m + 0.002 and absf(h) < 1e-6 \
				and absf(pos[i - 1].y - base) < 1e-6 and absf(pos[i - 2].y - base) < 1e-6:
			var v := (p - Vector2(pos[i - 1].x, pos[i - 1].z)) * hz
			var v0 := (Vector2(pos[i - 1].x, pos[i - 1].z) - Vector2(pos[i - 2].x, pos[i - 2].z)) * hz
			if v0.length() > 0.05 and v.length() > 0.01 and (v.length() > v0.length() - grip * 0.5 or absf(v.angle_to(v0)) > 0.4):
				tot["carried"] = int(tot["carried"]) + 1


## TRACKS MADE TO DO WHAT WAS REPORTED, on the card of wash [param sw] that goes furthest on the cloth in
## a second and a half: lying on the cloth beside it, carried along with it; held a face high beside it;
## and carried on it the whole way - each judged as a piece's track is.
func _control(sw: Dictionary, rest_y: float, m: float) -> Dictionary:
	var n := int(sw["cards"])
	var st := Drifts.CARD_STRIDE
	var last := (int(sw["frames"]) - 1) * Drifts.SUBSTEPS
	var span := int(1.5 * float(sw["hz"]) * float(Drifts.SUBSTEPS))
	# the cards that move furthest in a span...
	var moves: Array = []
	var s := 0
	while s + span <= last:
		var a := Drifts._cards_at(sw, s)
		var b := Drifts._cards_at(sw, s + span)
		for j in n:
			if a[j * st + 3] < 0.5 or b[j * st + 3] < 0.5:
				continue
			var d := Vector2(b[j * st] - a[j * st], b[j * st + 1] - a[j * st + 1]).length()
			if d >= 0.2:
				moves.append([d, j, s])
		s += 10
	if moves.is_empty():
		return {}
	moves.sort_custom(func(x: Array, y: Array) -> bool: return float(x[0]) > float(y[0]))
	# ...and of them, the one with a side the cloth beside it stays clearest of every other card on
	# (a deck of 78 lies thick: beside the furthest mover there is mostly another card)
	var half := Vector2(TablePositions.CARD.x, TablePositions.CARD.y) * 0.5
	var pick := Vector3i(-1, -1, 1)
	var most := -1
	for e: Array in moves.slice(0, 60):
		for side: int in [1, -1]:
			var at := Vector2(float(side) * (half.x + m + 0.012), 0.0)
			var clear := 0
			for k in 9:
				var c := Drifts._cards_at(sw, int(e[2]) + span * k / 8)
				var w := Drifts._world(at, Vector2(c[int(e[1]) * st], c[int(e[1]) * st + 1]), c[int(e[1]) * st + 2])
				clear += 1 if _clear_of(c, n, int(e[1]), w, half, m) else 0
			if clear > most:
				most = clear
				pick = Vector3i(int(e[1]), int(e[2]), side)
	var beside := Vector2(float(pick.z) * (half.x + m + 0.012), 0.0)
	var tracks := {"beside": [beside, 0.0], "up": [beside, 0.0007], "glued": [Vector2.ZERO, 0.0007]}
	var out := {}
	for k: String in tracks:
		var at: Vector2 = (tracks[k] as Array)[0]
		var lift := float((tracks[k] as Array)[1])
		var pos := PackedVector3Array()
		for i in span:
			var c := Drifts._cards_at(sw, pick.y + i)
			var w := Drifts._world(at, Vector2(c[pick.x * st], c[pick.x * st + 1]), c[pick.x * st + 2])
			pos.append(Vector3(w.x, rest_y + lift, w.y))
		var tot := _judged()
		_judge(sw, pos, pick.y, rest_y, m, tot)
		out[k] = tot
	return out


## Whether [param w] is clear of every card in [param c] on the cloth but [param but], by more than
## a piece's reach [param m] and a little.
func _clear_of(c: PackedFloat32Array, n: int, but: int, w: Vector2, half: Vector2, m: float) -> bool:
	var st := Drifts.CARD_STRIDE
	for j in n:
		if j == but or c[j * st + 3] < 0.0:
			continue
		var yaw := c[j * st + 2]
		var d := w - Vector2(c[j * st], c[j * st + 1])
		if absf(d.dot(Vector2(cos(yaw), -sin(yaw)))) < half.x + m + 0.003 and absf(d.dot(Vector2(sin(yaw), cos(yaw)))) < half.y + m + 0.003:
			return false
	return true
