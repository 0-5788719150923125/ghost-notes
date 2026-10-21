extends RefCounted
class_name TableThings

## TableThings - THE THINGS ON THE TABLE: where each one stands, and what stands where. A part of
## [TableMedium] (next/structure.md, step 24).
##
## What the set dresser described for the episode (`table.json` in its folder, made safe by
## [method CardTable.sanitize_table]), or the look's candles alone until it has - each built
## ([Props]) by the medium, then stood here: the draped laid where they were written, the written
## where the set dresser put them on the blueprint ([method stand_at]), and the rest found room in the
## zone they name ([method stand]), a group together. Where nothing may stand is a function of the
## plan and the box ([method off_limits]); what stood is kept ([member on_table], [member standing]) for
## the light, the wash and the blueprint to read.
##
## IT HOLDS ITS OWN STATE (what stood, the episode's habit, the layers' outlines) and reads the rest
## through [member medium]: the plan, the camera, the table's top, the box, the light it lights its
## wicks with, and what moves with the ride ([method TableMedium._take_movers]).

## The [TableMedium] this is a part of: everything read through it is something this part
## is handed, and the list of them is what it depends on.
var medium: TableMedium

## How far apart things stand on the table (meters): any two, and two of one group.
const THING_GAP := 0.014
const GROUP_GAP := 0.004
## HOW A READER SETS OUT THEIR THINGS, a habit drawn per episode (the user, 2026-10-08: "props are
## most often placed in a kind of arc along the top, with more or less equal spacing"; a real reader
## "will often have an entire table of stuff", much of it cut by the frame's edge, and "push the props
## to the left and right edges, such that the middle of the table remains more free"). Patterns
## guided toward, never enforced ([method _habit_of]): how far each group's spot wanders off its
## zone's middle (meters, x and z), how far the things are pushed out to the sides at the most, and
## the least share of a thing's picture the frame may keep when it cuts it. Lit things first seek a
## whole view; when that fails, their body may cross a side edge while every flame stays visible.
const AIM_WANDER := Vector2(0.08, 0.05)
const EDGE_PUSH := 0.2
const SEEN_LEAST := 0.55
## A THING ACROSS A CLOTH'S EDGE - half on the cloth, half on the bare top - reads as set down
## carelessly (the user, 2026-10-08), unless it is large: a book, a tray may lie across a hem. So a
## spot whose foot crosses a layer's edge scores this much worse (as many meters from its aim, over 4),
## and a thing wider than STRADDLE_BIG only a third of it.
const STRADDLE := 0.5
const STRADDLE_BIG := 0.18
## THE READER'S WORKSPACE (the user, 2026-10-10: a low thing stood "at the bottom and in the middle -
## just in front of the speaker ... when there are open areas elsewhere"): the strip of the cloth
## nearest the reader, in front of where the cards are shuffled and laid, is where their hands work.
## A spot there scores this much worse (as many meters from its aim, over 4), a low thing's too - the
## near ground a low thing may lie on ([method stand]) is for a crowded table, not the first choice.
## Soft: a table with no other room still stands its thing there. WORKSPACE_HALF is the strip's
## half-width from the middle of the reading; it begins where [method off_limits]'s middle ends.
const WORKSPACE := 2.0
const WORKSPACE_HALF := 0.25
const WORKSPACE_FROM := 0.14
## A THING WRITTEN WHERE IT STANDS (the user, 2026-10-18: "do the planning and desired placements
## up-front, then verify with screenshots at the end"): the set dresser lays its things out on a
## blueprint and writes each one's `at`, `turn` and `scale` ([method stand_at]). It stands exactly
## there unless that spot is one where nothing may stand - off the top, where the cards go, in another
## thing, or a flame in front of the middle - and then at the nearest spot that is not, NUDGE_STEP by
## NUDGE_STEP out to NUDGE_MOST (meters); with none so near, it is left off. Things written where they
## stand keep WRITTEN_GAP apart: the set dresser spaces them itself.
const NUDGE_MOST := CardTable.NUDGE_MOST
const NUDGE_STEP := 0.005
const WRITTEN_GAP := 0.003
## How far a card sliding across the cloth keeps from a thing's foot (meters).
const FOOT_MARGIN := 0.004

var standing: Array = []             # what stands on the table: convex feet (x by z), for a wash to go round
var standing_c := PackedVector2Array()   # ...their middles
var standing_r := PackedFloat32Array()   # ...and how far they reach from them
var _habit := {}                     # how this episode's reader sets out their things (_habit_of)
var _layer_os: Array = []             # the layers' outlines (Tables.layer_outline), for a foot across a hem
var on_table: Array = []               # what stood: [{name, group, place, node, outline, bb, rect, foot, lit, flames, meshes, written, moved, why}]
var unstood: Array = []              # things written where they stand that found no room near it: [{name, written, why}]


# --- the things on the table ------------------------------------------------------------------


## A NEW TABLE, nothing on it yet: what stood is forgotten, and the outlines of [param layers] (the
## cloths laid on the medium's top, [method Tables.layer_outline]) kept for a foot across a hem.
func clear(layers: Variant) -> void:
	_layer_os = []
	for l in (layers if layers is Array else []):
		if l is Dictionary and String((l as Dictionary).get("outline", "rect")) != "top":
			_layer_os.append(Tables.layer_outline(l, medium._top))
	standing = []
	standing_c = PackedVector2Array()
	standing_r = PackedFloat32Array()
	on_table = []
	unstood = []


## WHERE EACH THING STANDS. A thing written where it stands (`at`) stands there ([method stand_at]),
## in the order written. Any other goes in the zone the set dresser named, and things that share
## a group stand together: the group's tallest first, as near its zone's middle as there is room,
## the rest round it - the shorter ones toward the reader - so a group reads as arranged, not
## lined up. The biggest groups choose first. A thing with no room is tried smaller, then left
## off the table.
func place(things: Array, built: Array, rng: RandomNumberGenerator) -> void:
	var keep_out := off_limits()
	_habit = _habit_of(medium._plan.seed_value)
	# THE DRAPED FIRST: where they lie is written, and the rest stand clear of them
	for i in things.size():
		if Props.draped(things[i]):
			_drape(things[i], built[i], keep_out)
	# ...THEN THE WRITTEN, each where the set dresser put it on the blueprint
	for i in things.size():
		if Props.draped(things[i]) or not (things[i] as Dictionary).has("at"):
			continue
		var g := String((things[i] as Dictionary).get("group", ""))
		if not stand_at(things[i], built[i], g if not g.is_empty() else "#%d" % i, keep_out):
			print("ghost: card table - no room for %s near where it was written" % String((things[i] as Dictionary).get("name", "a thing")))
			((built[i] as Dictionary)["node"] as Node).free()
	var groups := {}
	for i in things.size():
		if Props.draped(things[i]) or (things[i] as Dictionary).has("at"):
			continue
		var g := String((things[i] as Dictionary).get("group", ""))
		var key := g if not g.is_empty() else "#%d" % i
		if not groups.has(key):
			groups[key] = []
		(groups[key] as Array).append(i)
	var area := func(members: Array) -> float:
		var s := 0.0
		for i in members:
			var box: AABB = (built[i] as Dictionary)["size"]
			s += box.size.x * box.size.z
		return s
	var order: Array = groups.keys()
	order.sort_custom(func(a: Variant, b: Variant) -> bool: return float(area.call(groups[a])) > float(area.call(groups[b])))
	for key in order:
		var members: Array = groups[key]
		members.sort_custom(func(a: int, b: int) -> bool:
			return ((built[a] as Dictionary)["size"] as AABB).size.y > ((built[b] as Dictionary)["size"] as AABB).size.y)
		var anchor := {}
		for i in members:
			var stood := stand(things[i], built[i], String(key), anchor, keep_out, rng)
			if stood.is_empty():
				print("ghost: card table - no room for %s" % String((things[i] as Dictionary).get("name", "a thing")))
				((built[i] as Dictionary)["node"] as Node).free()
			elif anchor.is_empty():
				anchor = stood


## THIS EPISODE'S HABIT ([constant AIM_WANDER]), from its own die so no other draw moves: `push` - how
## far out to the sides its things lean (0 keeps the zones' own middles, as before; often well out, so
## the middle stays free), and `wander`, `side` - each group's own step off its zone's middle and the side
## a "back" group leans to, by the group's name.
static func _habit_of(seed: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed, "tarot-things-habit"])
	return {"push": pow(rng.randf(), 0.7), "salt": rng.randi()}


## Where group [param group] of zone [param zone] aims, the deck kept at [param deck]: the zone's middle,
## pushed out to its side by the habit and wandered off by the group's own step.
func _habit_aim(zone: String, group: String, deck: Vector3) -> Vector2:
	var aim := CardTable.zone_aim(zone, deck)
	if _habit.is_empty():
		return aim
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([int(_habit["salt"]), group])
	var step := Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0)) * AIM_WANDER
	var side := signf(aim.x) if absf(aim.x) > 0.01 else (-1.0 if rng.randf() < 0.5 else 1.0)
	# a "back" thing leans out less (it stands where the frame is narrowest), by the deck not at all
	var push := float(_habit["push"]) * EDGE_PUSH * (0.0 if zone == "by the deck" else (0.8 if absf(aim.x) < 0.01 else 1.0))
	return aim + step + Vector2(side * push, 0.0)


## How much worse a spot is for a foot [param bb] (x by z) that crosses a layer's edge ([constant STRADDLE]).
func _straddle(bb: Rect2) -> float:
	var pts := [bb.position, bb.end, Vector2(bb.position.x, bb.end.y), Vector2(bb.end.x, bb.position.y), bb.get_center()]
	for o in _layer_os:
		var inside := 0
		for q in pts:
			inside += 1 if Tables.sdf(o, q) < 0.0 else 0
		if inside > 0 and inside < pts.size():
			return STRADDLE * (1.0 / 3.0 if maxf(bb.size.x, bb.size.y) > STRADDLE_BIG else 1.0)
	return 0.0


## THING [param t] (its strand laid `drape`) with the ground it falls over: this top's edge ([method
## Tables.sdf]), the middle of the reading its path is written from, and the floor.
func grounded(t: Dictionary) -> Dictionary:
	var out := t.duplicate(true)
	var o := medium._top_o
	var ground := {"sdf": func(p: Vector2) -> float: return Tables.sdf(o, p),
		"normal": func(p: Vector2) -> Vector2: return Tables.normal(o, p),
		"origin": Tables.ORIGIN, "drop": Tables.DROP_MOST}
	for p in out["parts"]:
		(p as Dictionary)["ground"] = ground
	return out


## A STRAND DRAPED ACROSS THE TABLE ([param t], built as [param b] in the table's own space): laid where it was
## written - unless it runs where the cards go ([param keep_out]), when it is left off - and the stretches of
## the table it covers kept out for the things that stand after it.
func _drape(t: Dictionary, b: Dictionary, keep_out: Array) -> void:
	var node: Node3D = b["node"]
	var line := PackedVector2Array()
	for m in b["meshes"]:
		var arr := ((m as MeshInstance3D).mesh as ArrayMesh).surface_get_arrays(0)
		var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		for i in range(0, vs.size(), 7):
			if vs[i].y > -0.01:
				line.append(Vector2(vs[i].x, vs[i].z))
	var pieces: Array = []
	var cell := 0.06
	var cells := {}
	for q in line:
		var c := Vector2i(floori(q.x / cell), floori(q.y / cell))
		if not cells.has(c):
			cells[c] = Rect2(q, Vector2.ZERO)
		cells[c] = (cells[c] as Rect2).expand(q)
	for c in cells:
		pieces.append((cells[c] as Rect2).grow(0.004))
	for r in pieces:
		for k in keep_out:
			if (r as Rect2).intersects(k as Rect2):
				print("ghost: card table - %s runs where the cards go; left off" % String(t.get("name", "a strand")))
				node.free()
				return
	var bb := Rect2()
	for r in pieces:
		bb = (r as Rect2) if bb.size == Vector2.ZERO else bb.merge(r as Rect2)
	var flat := b.duplicate()
	flat["foot"] = PackedVector2Array()
	put(t, flat, {"at": Vector2.ZERO, "rect": Rect2(), "bb": bb, "outline": PackedVector2Array()}, Basis(), "")
	keep_out.append_array(pieces)


## Where nothing may stand: everywhere the cards go - the spread, the deck, the middle where the
## deck is shuffled, where a jumper lands - as rectangles on the table (x by z).
func off_limits() -> Array:
	var out: Array = []
	for sl in medium._plan.slots:
		out.append(CardTable.footprint((sl as Dictionary)["pos"], float((sl as Dictionary)["yaw"]), TableMedium.CARD).grow(0.03))
	out.append(Rect2(medium._plan.deck_base.x - 0.08, medium._plan.deck_base.z - 0.1, 0.16, 0.2))
	if medium._plan.aside_card >= 0:
		out.append(Rect2(medium._plan.deck_far.x - 0.08, medium._plan.deck_far.z - 0.1, 0.16, 0.2))
	# the middle, where the deck is shuffled - and, whatever the source, where the spread lies
	out.append(shuffle_rect())
	if medium._plan.cards_from == "box":
		# nothing stands where the box would, nor where a pulled card rises past it
		out.append(TablePositions.deck_keep(medium._plan.deck_base, medium._plan.box_keep(), medium._plan.box_center()))
		if medium._box_part.stood.has("lid"):
			var world: AABB = medium._box_part.stood["world"]
			var side := signf(medium._plan.deck_base.x)
			var x := world.get_center().x + side * (world.size.x + 0.025)
			out.append(Rect2(x - world.size.x * 0.5 - 0.025, world.position.z + 0.08 - 0.025,
				world.size.x + 0.05, world.size.z + 0.05))
		return out
	out.append(Rect2(medium._plan.jump_land.x - 0.07, medium._plan.jump_land.z - 0.09, 0.14, 0.18))
	return out


## The middle of the table, where the deck is shuffled (x by z).
func shuffle_rect() -> Rect2:
	return Rect2(medium._plan.mid.x - 0.22, medium._plan.mid.z - 0.14, 0.44, 0.28)


## THE TABLE'S BLUEPRINT, as [TableBlueprint] draws it for the set dresser: everything that decides where
## a thing may stand, in the table's own space (meters; x to the reader's right, z toward the reader) -
## the top's outline and its layers' ([method Tables.top_outline]), the spread's cards (`{pos, yaw}`), the
## deck, where nothing may stand ([method off_limits]), the shuffle, the reader's workspace, the line flames
## stand behind, the camera - and each thing as it stood: its foot, which way its front faces, its height,
## where it was written and how far it was moved, and why; and each written thing that found no room.
func blueprint() -> Dictionary:
	var cards: Array = []
	for sl in medium._plan.slots:
		cards.append({"pos": Vector2(((sl as Dictionary)["pos"] as Vector3).x, ((sl as Dictionary)["pos"] as Vector3).z),
			"yaw": float((sl as Dictionary)["yaw"])})
	var layers: Array = []
	for l in ((medium._furniture.get("spec", {}) as Dictionary).get("layers", []) as Array):
		if l is Dictionary:
			layers.append({"name": String((l as Dictionary).get("name", "")), "o": Tables.layer_outline(l, medium._top)})
	var things: Array = []
	for th in on_table:
		var d: Dictionary = th
		var node: Node3D = d["node"]
		var front := node.transform.basis * Vector3(0.0, 0.0, 1.0)
		things.append({"name": String(d["name"]), "foot": d["outline"], "bb": d["bb"], "at": Vector2(node.position.x, node.position.z),
			"front": Vector2(front.x, front.z).normalized(), "height": (d["box"] as AABB).end.y, "lit": int(d["lit"]),
			"written": d.get("written"), "moved": float(d.get("moved", 0.0)), "why": String(d.get("why", "")),
			"rect": d["rect"], "box": String(d["group"]) == "#the box"})
	return {"top": medium._top_o, "layers": layers, "cards": cards, "card": TableMedium.CARD, "deck": Vector2(medium._plan.deck_base.x, medium._plan.deck_base.z),
		"keep_out": off_limits(), "shuffle": shuffle_rect(),
		"workspace": Rect2(medium._plan.mid.x - WORKSPACE_HALF, medium._plan.mid.z + WORKSPACE_FROM, WORKSPACE_HALF * 2.0, 1.0),
		"flames_behind": medium._plan.mid.z, "camera": medium._plan.cam_base, "fov": medium._cam.fov, "things": things,
		"unstood": unstood.duplicate(true)}


## ONE THING STOOD: the best free spot for [param t] (built as [param b]) on a grid over the table,
## at full size or, failing that, a little smaller. Every spot is ON THE TABLE, off everywhere the
## cards go, clear of what already stands (by [constant THING_GAP], or [constant GROUP_GAP] within
## its own group), IN THE SHOT (its projected box never cut by the frame's top, with at least
## [constant SEEN_LEAST] visible). A lit thing first seeks a whole view; if none fits, its sides
## may be cut while every flame stays in view. Between groups, things do not overlap in the picture.
## Aimed where the episode's habit puts its zone ([method _habit_aim]),
## and kept off a cloth's edge where it can be ([method _straddle]). A lit thing stands only behind the middle (in front of the
## cards its flame blew out the card held up to the lens) and looks for dark cloth. The spot
## chosen ({at, k, group, height}), or empty when there is none.
func stand(t: Dictionary, b: Dictionary, group: String, anchor: Dictionary, keep_out: Array,
		rng: RandomNumberGenerator, edge_light := false) -> Dictionary:
	var box: AABB = b["size"]
	var lit := not (b["wicks"] as Array).is_empty()
	var yaw := deg_to_rad(float(t.get("turn", 0.0)) + rng.randf_range(-8.0, 8.0))
	var zone := String(t.get("place", "back"))
	var aim := _habit_aim(zone, group, medium._plan.deck_base)
	var front := (medium._plan.deck_base.z + 0.03) if zone in ["by the deck", "left", "right"] else medium._plan.mid.z + 0.03
	# a LOW thing may lie nearer the reader, where it hides no card and nothing behind it
	if box.size.y < 0.04:
		front = 0.2
	if lit:
		front = minf(front, medium._plan.mid.z)
	var outline: PackedVector2Array = b["outline"]
	var top_center: Vector2 = medium._top_o["center"]
	var top_half: Vector2 = medium._top_o["half"]
	var shot := Rect2(0.0, 0.0, 1.0, 1.0)
	var workspace := Rect2(medium._plan.mid.x - WORKSPACE_HALF, medium._plan.mid.z + WORKSPACE_FROM, WORKSPACE_HALF * 2.0, 1.0)
	for k in [1.0, 0.88, 0.76]:
		var basis := Basis(Vector3.UP, yaw).scaled(Vector3(k, k, k))
		var shape := PackedVector2Array()
		for q in outline:
			var w := basis * Vector3(q.x, 0.0, q.y)
			shape.append(Vector2(w.x, w.z))
		var lo := Vector2(INF, INF)
		var hi := Vector2(-INF, -INF)
		for q in shape:
			lo = lo.min(q)
			hi = hi.max(q)
		var corners := PackedVector3Array()
		for cx in [box.position.x, box.end.x]:
			for cy in [box.position.y, box.end.y]:
				for cz in [box.position.z, box.end.z]:
					corners.append(basis * Vector3(cx, cy, cz))
		var best := {}
		var best_score := -INF
		var cam_inv := medium._plan.cam_base.affine_inverse()
		var lens := Vector2(tan(deg_to_rad(medium._cam.fov * 0.5)) * (16.0 / 9.0), tan(deg_to_rad(medium._cam.fov * 0.5)))
		var z := top_center.y - top_half.y
		while z <= front:
			var x := top_center.x - top_half.x
			while x <= top_center.x + top_half.x:
				medium._breathe()
				var at := Vector2(x + rng.randf_range(-0.004, 0.004), z + rng.randf_range(-0.004, 0.004))
				x += 0.02
				var bb := Rect2(lo + at, hi - lo)
				# The actual top, including its side margins, is available. Its outline below keeps
				# every foot safely in from the rim; the picture test decides what the viewer sees.
				if Tables.sdf(medium._top_o, bb.position) > -Tables.THING_EDGE or Tables.sdf(medium._top_o, bb.end) > -Tables.THING_EDGE \
						or Tables.sdf(medium._top_o, Vector2(bb.position.x, bb.end.y)) > -Tables.THING_EDGE \
						or Tables.sdf(medium._top_o, Vector2(bb.end.x, bb.position.y)) > -Tables.THING_EDGE:
					continue
				# the outline itself only where the boxes meet: most spots are judged by box alone
				var placed := PackedVector2Array()
				var clear := true
				for r in keep_out:
					if (r as Rect2).intersects(bb):
						if placed.is_empty():
							placed = Geo.moved(shape, at)
						if Geo.within(placed, Geo.of_rect(r as Rect2), 0.0):
							clear = false
							break
				if not clear:
					continue
				for th in on_table:
					var gap := GROUP_GAP if String((th as Dictionary)["group"]) == group else THING_GAP
					if ((th as Dictionary)["bb"] as Rect2).grow(gap).intersects(bb):
						if placed.is_empty():
							placed = Geo.moved(shape, at)
						if Geo.within(placed, (th as Dictionary)["outline"], gap):
							clear = false
							break
				if not clear:
					continue
				var rect := CardTable.screen_rect(corners, Vector3(at.x, 0.0, at.y), cam_inv, lens)
				var seen := rect.intersection(shot)
				# Never cut by the frame's TOP: that reads as a thing standing in the room. Lit things
				# seek a whole view first; everything may run off a side if enough of it remains visible.
				if rect.position.y < 0.02:
					continue
				if seen.get_area() < rect.get_area() * SEEN_LEAST:
					continue
				if lit:
					if rect.end.y > 0.97:
						continue
					if not edge_light and (rect.position.x < 0.02 or rect.end.x > 0.98):
						continue
					if edge_light:
						var wick_seen := true
						for wick in b["wicks"]:
							var flame: Variant = CardTable.project(medium._plan.cam_base, medium._cam.fov,
								basis * (wick as Vector3) + Vector3(at.x, 0.0, at.y))
							if flame == null or (flame as Vector2).x < 0.02 or (flame as Vector2).x > 0.98:
								wick_seen = false
								break
						if not wick_seen:
							continue
				# not in front of another in the picture: apart between groups, and within one only a
				# little in front - a group seen one thing through another read as a stack
				var hidden := 0.0
				for th in on_table:
					var other: Rect2 = ((th as Dictionary)["rect"] as Rect2).intersection(shot)
					if String((th as Dictionary)["group"]) != group:
						if other.grow(0.008).intersects(seen):
							clear = false
							break
					elif other.intersects(seen):
						hidden = maxf(hidden, other.intersection(seen).get_area() / maxf(minf(other.get_area(), seen.get_area()), 1e-6))
				if not clear or hidden > 0.3:
					continue
				var score := -hidden * 2.0
				if anchor.is_empty():
					score -= at.distance_to(aim) * 4.0
				else:
					var ap: Vector2 = anchor["at"]
					score -= at.distance_to(ap) * 6.0
					# a shorter thing in a group stands toward the reader, a taller one behind
					if box.size.y * k < float(anchor["height"]):
						score += clampf((at.y - ap.y) * 4.0, -0.2, 0.2)
				if lit:
					# by dark cloth, where it can burn as the key: by pale, its light is held down
					score -= 0.8 * maxf(0.0, medium._light_part.heat_cell(Vector3(at.x, 0.0, at.y)) * TableMedium.KEY_ENERGY / TableMedium.HEAT - 1.0)
				score -= _straddle(bb)
				if bb.intersects(workspace):
					score -= WORKSPACE
				score += rng.randf() * 0.05
				if score > best_score:
					best_score = score
					best = {"at": at, "rect": rect, "bb": bb, "outline": placed if not placed.is_empty() else Geo.moved(shape, at)}
			z += 0.02
		if not best.is_empty():
			put(t, b, best, basis, group)
			return {"at": best["at"], "height": box.size.y * k, "k": k}
	if lit and not edge_light:
		return stand(t, b, group, anchor, keep_out, rng, true)
	return {}


## ONE THING STOOD WHERE IT WAS WRITTEN ([constant NUDGE_MOST]): [param t]'s `at`, turned by its `turn`
## and sized by its `scale` - exactly, with no hand's jitter: the spot is the set dresser's. A spot where
## it may not stand ([method _spot_trouble]) moves it to the nearest where it may, the move and its
## reason kept for the blueprint; false, and kept in [member unstood], when none is within reach. Whether
## the camera sees it whole, or sees it in front of another thing, is the set dresser's to judge.
func stand_at(t: Dictionary, b: Dictionary, group: String, keep_out: Array) -> bool:
	var box: AABB = b["size"]
	var lit := not (b["wicks"] as Array).is_empty()
	var k := float(t.get("scale", 1.0))
	var basis := Basis(Vector3.UP, deg_to_rad(float(t.get("turn", 0.0)))).scaled(Vector3(k, k, k))
	var cm: Array = t["at"]
	var want := Tables.ORIGIN + Vector2(float(cm[0]), float(cm[1])) * 0.01
	var shape := Geo.turned(b["outline"], basis)
	var why := ""
	var spot := Vector2(INF, INF)
	var r := 0.0
	while r <= NUDGE_MOST + 1e-6 and spot.x == INF:
		var n := 1 if r == 0.0 else maxi(8, ceili(TAU * r / NUDGE_STEP))
		for i in n:
			medium._breathe()
			var at := want + Vector2(cos(TAU * i / n), sin(TAU * i / n)) * r
			var trouble := _spot_trouble(Geo.moved(shape, at), lit, at, keep_out)
			if trouble.is_empty():
				spot = at
				break
			if r == 0.0:
				why = trouble
		r += NUDGE_STEP
	if spot.x == INF:
		unstood.append({"name": String(t.get("name", "")), "written": want, "why": why})
		return false
	var corners := PackedVector3Array()
	for cx in [box.position.x, box.end.x]:
		for cy in [box.position.y, box.end.y]:
			for cz in [box.position.z, box.end.z]:
				corners.append(basis * Vector3(cx, cy, cz))
	var lens := Vector2(tan(deg_to_rad(medium._cam.fov * 0.5)) * (16.0 / 9.0), tan(deg_to_rad(medium._cam.fov * 0.5)))
	var placed := Geo.moved(shape, spot)
	put(t, b, {"at": spot, "outline": placed, "bb": Geo.bounds(placed),
		"rect": CardTable.screen_rect(corners, Vector3(spot.x, 0.0, spot.y), medium._plan.cam_base.affine_inverse(), lens),
		"written": want, "moved": spot.distance_to(want), "why": why}, basis, group)
	return true


## Why a foot [param placed] (convex, on the table) may not stand where it is, "" when it may: a flame
## in front of the middle ([param lit], its middle at [param at]; see [method stand]), off the top
## ([constant Tables.THING_EDGE] in from its edge), where the cards go ([param keep_out]), or in what
## already stands ([constant WRITTEN_GAP]).
func _spot_trouble(placed: PackedVector2Array, lit: bool, at: Vector2, keep_out: Array) -> String:
	if lit and at.y > medium._plan.mid.z:
		return "a flame in front of the middle of the table blows out the card held up to the lens"
	for q in placed:
		if Tables.sdf(medium._top_o, q) > -Tables.THING_EDGE:
			return "it ran off the table's edge"
	var bb := Geo.bounds(placed)
	for r in keep_out:
		if (r as Rect2).intersects(bb) and Geo.within(placed, Geo.of_rect(r as Rect2), 0.0):
			return "it stood where the cards go"
	for th in on_table:
		if ((th as Dictionary)["bb"] as Rect2).grow(WRITTEN_GAP).intersects(bb) \
				and Geo.within(placed, (th as Dictionary)["outline"], WRITTEN_GAP):
			return "it stood in %s" % String((th as Dictionary)["name"])
	return ""


## Thing [param t] stood at the chosen spot: in the scene, its wicks lit, a soft shade where it meets
## the cloth, its foot kept for the cards to go round (see [method _card_clear]).
func put(t: Dictionary, b: Dictionary, spot: Dictionary, basis: Basis, group: String) -> void:
	var at: Vector2 = spot["at"]
	var node: Node3D = b["node"]
	node.transform = Transform3D(basis, Vector3(at.x, 0.0, at.y))
	medium._props.add_child(node)
	var wicks: Array = b["wicks"]
	# The wax and holder immediately under a flame cannot shadow themselves: they printed a
	# hard disc at the base. Separate accessories several centimeters away (a dish of dye beside
	# the candle, for example) must still catch and cast that candle's light.
	var own := (TableMedium.CANDLE_LAYER << medium._lights.size()) if not wicks.is_empty() else TableMedium.THING_LAYER
	for m in b["meshes"]:
		var mesh := m as MeshInstance3D
		mesh.layers = own if wicks.is_empty() or TableLight.near_wick(mesh, wicks) else TableMedium.THING_LAYER
	var glows: Array = b.get("glows", [])
	var first := medium._lights.size()
	if not wicks.is_empty():
		var flames: Array = []
		for i in wicks.size():
			var wick: Vector3 = node.transform * (wicks[i] as Vector3)
			var f := medium._light_part.add_flame(wick, own, glows[i] if i < glows.size() else null)
			f["open"] = Props.open_to_air(wick, node, b["meshes"])
			flames.append(f)
		medium._light_part.light_flames(flames, own)
	var foot := Geo.moved(Geo.turned(b["foot"], basis), at)
	if foot.size() >= 3:
		# A moving shoebox gets its own moving soft shade. A fixed decal projects onto
		# its walls as it passes, and a fixed shadow slab leaves a ghost at its destination.
		if not (group == "#the box" and String(medium._plan.staging.get("box_style", "open")) == "shoebox"):
			medium._light_part.contact_shadow(foot)
			medium._light_part.foot_shadow(foot, own)
		var grown := Geo.grown(foot, FOOT_MARGIN)
		standing.append(grown)
		var c := Vector2.ZERO
		for q in grown:
			c += q
		c /= float(grown.size())
		var r := 0.0
		for q in grown:
			r = maxf(r, q.distance_to(c))
		standing_c.append(c)
		standing_r.append(r)
	medium._take_movers(b, node)
	on_table.append({"name": String(t.get("name", "")), "group": group, "place": String(t.get("place", "back")),
		"node": node, "outline": spot["outline"], "bb": spot["bb"], "rect": spot["rect"], "foot": foot,
		"box": node.transform * (b["size"] as AABB), "lit": wicks.size(), "lights": range(first, medium._lights.size()),
		"meshes": b["meshes"], "written": spot.get("written"), "moved": float(spot.get("moved", 0.0)),
		"why": String(spot.get("why", ""))})
