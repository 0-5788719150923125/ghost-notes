extends RefCounted
class_name TableBox

## TableBox - the box the deck is kept in, when an episode has one: stood in its own place on the
## table, the deck's unseen cards filed in it in uneven piles or on edge (the drawn ones on top),
## the small things kept with them, and the cards a search lifts or draws part of the way up.
##
## A PART OF THE TABLE, cut along its banners (next/structure.md, step 14): it builds the box once
## per episode and HOLDS what it built - [member box] (its node, its inside, where each card is
## filed, where a search looks), [member file], [member searched] - which the poses read through
## the medium's `_box_part`; everything else of the table it reads through `medium`.

## The [TableMedium] this is a part of: everything read through it is something this part
## is handed, and the list of them is what it depends on.
var medium: TableMedium

## THE BOX THE CARDS ARE KEPT IN: how thick its walls are taken to be (meters), and the cards filed in
## it - their pitch (a card and the air beside it), and how far the last of them lean into the gap.
const BOX_WALL := 0.006
const FILE_PITCH := 0.0011
const FILE_LEAN := 0.35
## A SEARCH OF THE BOX ([method _pose_rummage]): how many of its cards may be looked at
## ([constant SEATS], each in a place of its own), how far of its height a card on edge is drawn up out
## of the file (and the least, where the picture's top edge would cut its painting: [method _search_rise]),
## how far its face is then leaned back to the eye, and how far from lying a card lifted
## off a pile is turned up, face to the eye. How many cards one search looks at: on edge, and lying -
## a lying card is turned over to be seen and back, which takes longer.
const SEATS := 9
## How full a shoebox of piles is: this share of what its piles could hold to the rim.
const SHOEBOX_SHARE := 0.6
## How much of the depth of an open box of cards on edge they fill at least: the producer's list of
## fourteen undrawn cards stood in a front corner of a box twenty centimeters deep (feedback 0020:
## "barely any cards in the box"), so the rest of the stock is filed behind them as a shoebox's is.
const OPEN_FILE_SHARE := 0.5
var stood := {}                        # the box the cards are kept in, stood: {node, at, inner (AABB, world), upright, lie}
var files: Array = []                 # the cards filed in it: MultiMeshInstance3D, one per printing
var objects: Array = []          # optional small keepsakes inside the box
var searched: Array = []            # the box's own cards a search looks at, one in each place (`stood["search"]`)
var looking: MeshInstance3D         # the one being looked at at the moment posed, or null

# --- the things on the table ------------------------------------------------------------------

## THE BOX THE CARDS ARE KEPT IN, for a show whose cards come from one ([member _cards_from] `box`): the set
## dresser's thing that `holds_cards` - taken out of [param things] and [param built] - or, when it made
## none, a plain box of the deck's own stock. An open box stands by the deck; a shoebox settles across
## the center. Both are scaled to their allotted space, with their contents built inside ([method
## _build_file]). A box on a table whose cards come from a deck is a thing like any other.
func build(things: Array, built: Array) -> void:
	for f in files:
		(f as Node).queue_free()
	files = []
	for c in searched:
		(c as Node).queue_free()
	searched = []
	looking = null
	for o in objects:
		(o as Node).queue_free()
	objects = []
	stood = {}
	if medium._plan.cards_from != "box":
		return
	var t := {}
	var b := {}
	for i in things.size():
		if bool((things[i] as Dictionary).get("holds_cards", false)):
			t = things[i]
			b = built[i]
			things.remove_at(i)
			built.remove_at(i)
			break
	var shoebox := String(medium._plan.staging.get("box_style", "open")) == "shoebox"
	if t.is_empty():
		var stock := CardTable.color(String((medium._plan.look.get("frame", {}) as Dictionary).get("stock", "#c9b38a")))
		t = {"name": "the box the cards are kept in", "place": "by the deck", "holds_cards": true, "parts": [
			{"shape": "extrude", "outline": "rect", "size": [22.0, 33.0] if shoebox else [9.6, 17.0],
				"height": 11.0 if shoebox else 9.0, "wall": 0.5, "material": "card box"}]}
		var mats := {"card box": Props.sanitize_material({"kind": "paper", "color": "#" + stock.darkened(0.25).to_html(false)}, "#a08060")}
		b = Props.build(Props.sanitize({"things": [t], "materials": mats}, [])["things"][0], mats, hash([medium._plan.seed_value, "card box"]))
	var size: AABB = b["size"]
	if size.size.x <= 0.0 or size.size.z <= 0.0:
		return
	var across := size.size.z > size.size.x
	var turn := (PI * 0.5 if across else 0.0) if shoebox else (0.0 if across or is_equal_approx(size.size.x, size.size.z) else PI * 0.5)
	var w := size.size.z if turn != 0.0 else size.size.x
	var d := size.size.x if turn != 0.0 else size.size.z
	var most := CardTable.SHOEBOX_MAX if shoebox else CardTable.BOX_MAX
	var k := minf(1.0, minf(most.x / w, minf(most.z / d, most.y / maxf(size.size.y, 0.001))))
	var basis := Basis(Vector3.UP, turn).scaled(Vector3(k, k, k))
	var want := medium._box_center() if shoebox else TablePositions.box_at(medium._deck_base)
	# its own place in the room kept for it, the open box's toward the spread
	var place := RandomNumberGenerator.new()
	place.seed = hash([medium._plan.seed_value, "box place"])
	want = TablePositions.box_stand(want, Vector2(w, d) * k, Vector2(most.x, most.z),
		0.0 if shoebox else -signf(want.x), place)
	var mid := basis * size.get_center()
	var at := Vector2(want.x - mid.x, want.z - mid.z)
	var shape := TableMedium._translated(TableMedium._turned(b["outline"], basis), at)
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for q in shape:
		lo = lo.min(q)
		hi = hi.max(q)
	var corners := PackedVector3Array()
	for cx in [size.position.x, size.end.x]:
		for cy in [size.position.y, size.end.y]:
			for cz in [size.position.z, size.end.z]:
				corners.append(basis * Vector3(cx, cy, cz))
	var lens := Vector2(tan(deg_to_rad(medium._cam.fov * 0.5)) * (16.0 / 9.0), tan(deg_to_rad(medium._cam.fov * 0.5)))
	var rect := TableMedium._screen_rect_fast(corners, Vector3(at.x, 0.0, at.y), medium._plan.cam_base.affine_inverse(), lens)
	medium._put(t, b, {"at": at, "outline": shape, "bb": Rect2(lo, hi - lo), "rect": rect}, basis, "#the box")
	var world := Transform3D(basis, Vector3(at.x, 0.0, at.y)) * size
	var inner := AABB(world.position + Vector3(BOX_WALL, BOX_WALL, BOX_WALL),
		world.size - Vector3(BOX_WALL * 2.0, BOX_WALL, BOX_WALL * 2.0))
	stood = {"node": b["node"], "inner": inner, "world": world, "local_bounds": size,
		"rest": (b["node"] as Node3D).transform}
	# The box walls are real occluders. Its contact decal only darkens the cloth at
	# the foot; it cannot cast the long shadow away from a candle or lamp.
	if shoebox:
		var lid := Node3D.new()
		var mat := StandardMaterial3D.new()
		mat.albedo_color = CardTable.color(String((medium._plan.look.get("frame", {}) as Dictionary).get("stock", "#c9b38a"))).darkened(0.3)
		mat.roughness = 0.9
		var lx := size.size.x + 0.016
		var lz := size.size.z + 0.016
		_lid_piece(lid, mat, Vector3(lx, 0.003, lz), Vector3.ZERO)
		for sx in [-1.0, 1.0]:
			_lid_piece(lid, mat, Vector3(0.003, 0.028, lz), Vector3(sx * (lx - 0.003) * 0.5, -0.0155, 0.0))
		for sz in [-1.0, 1.0]:
			_lid_piece(lid, mat, Vector3(lx - 0.006, 0.028, 0.003), Vector3(0.0, -0.0155, sz * (lz - 0.003) * 0.5))
		(b["node"] as Node3D).add_child(lid)
		stood["lid"] = lid
		stood["lid_rest"] = Vector3(size.get_center().x, size.end.y + 0.009, size.get_center().z)
		stood["shadow"] = medium._light_part.contact_shadow(shape)
		stood["lid_shadow"] = medium._light_part.contact_shadow(shape)
	_build_file()
	_build_box_objects()
	if shoebox:
		# A card passing close to these walls throws a large, stair-stepped shadow
		# across them in the positional atlas. The box keeps its soft tabletop shade.
		for card in medium._cards:
			(card as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


static func _lid_piece(parent: Node3D, mat: Material, dimensions: Vector3, at: Vector3) -> void:
	var part := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	part.mesh = mesh
	part.material_override = mat
	part.position = at
	part.layers = TableMedium.THING_LAYER
	part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(part)


## THE CARDS IN THE BOX: an open box of cards on edge and a shoebox fill out their printings with
## physical copies ([constant OPEN_FILE_SHARE], [constant CardTable.SHOEBOX_FILL]) so each reads as a
## collection accumulated over time. The drawn
## cards have their own places near the accessible top. Cards lying in piles are laid by
## [method _pile_places]. Undrawn cards share one MultiMesh per printing and card ([method _unseen_kinds]).
func _build_file() -> void:
	var inner: AABB = stood["inner"]
	var content := String(medium._plan.staging.get("contents", "file"))
	var size := CardTable.card_size(medium._plan.look)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([medium._plan.seed_value, "card file"])
	var under_lid := stood.has("lid")
	var upright := content == "file" and inner.size.x >= size.x * 1.03 and inner.size.y >= size.y * (1.03 if under_lid else 0.6)
	var lie := content == "file" and not upright and inner.size.x >= size.y * 1.03 and inner.size.y >= size.x * (1.03 if under_lid else 0.6)
	stood["upright"] = upright
	stood["lie"] = lie
	stood["at_k"] = []
	if content == "file" and not upright and not lie:
		# a shallow tin: the deck lies flat on its floor
		stood["flat"] = true
		return
	var v := size.y if upright else size.x
	# ON EDGE, FACE TO THE READER, as a collection stands in its owner's box: whoever looks through it
	# looks at the fronts (the user, 2026-10-13), and a card comes up out of the file showing what every
	# card left in it shows - a front ([method _unseen_fronts]). The file stood back to the camera while
	# the cards nobody drew had no front to show: face on, it was a box of border strips, and the drawn
	# card came up a picture out of it (2026-10-12: "the card changed to something else").
	var stand := Basis(Vector3(1, 0, 0), PI * 0.5) * TableMedium._face_up()
	if lie:
		stand = stand * Basis(Vector3.UP, PI * 0.5)
	var shoebox := stood.has("lid")
	var piled := content == "piles" or (shoebox and content == "loose")
	var rise := TableMedium.CARD_T * 1.02 if shoebox else TableMedium.CARD_T + 0.00025
	var want := CardTable.SHOEBOX_FILL
	if piled:
		var plots := TablePositions.box_plots(inner, size)
		want = clampi(int(float(plots.x * plots.y) * (inner.size.y - 0.004) / rise * SHOEBOX_SHARE),
			medium._cards.size(), CardTable.SHOEBOX_FILL)
	var pad := shoebox
	if not shoebox and not piled and content == "file":
		want = int(inner.size.z * OPEN_FILE_SHARE / FILE_PITCH)
		pad = true
	var undrawn := _file_inventory(want, pad)
	var count := medium._cards.size() + undrawn.size()
	stood["count"] = count
	var fill := minf(1.0, float(count) * FILE_PITCH / maxf(inner.size.z, FILE_PITCH))
	var tail := mini(6, count / 4)
	var xfs: Array = []
	if piled:
		xfs = _pile_places(inner, size, count, rise, rng)
	for i in count if not piled else 0:
		if shoebox:
			if content == "file":
				var rows := maxi(1, int(floor(inner.size.x / (size.x + 0.006))))
				var row := i % rows
				var layer := i / rows
				var pitch := minf(TableMedium.CARD_T * 1.02, (inner.size.z - size.x * 0.1) / float(maxi(int(ceil(float(count) / rows)), 1)))
				var x := inner.position.x + inner.size.x * (float(row) + 0.5) / float(rows)
				var z := inner.end.z - pitch * (float(layer) + 0.5) - 0.004
				xfs.append(Transform3D(stand, Vector3(x, inner.position.y + v * 0.5, z)))
				continue
		if content == "loose":
			var radius := size.length() * 0.5
			var dx := maxf(inner.size.x * 0.5 - radius - 0.003, 0.0)
			var dz := maxf(inner.size.z * 0.5 - radius - 0.003, 0.0)
			xfs.append(Transform3D(Basis(Vector3.UP, rng.randf_range(-PI, PI)),
				Vector3(inner.get_center().x + rng.randf_range(-dx, dx),
					inner.position.y + 0.001 + 0.004 * float(i) / float(maxi(count, 1)),
					inner.get_center().z + rng.randf_range(-dz, dz))))
			continue
		# from the front wall back; the last few lean back into the gap
		var z := inner.end.z - FILE_PITCH * (float(i) + 0.5)
		var lean := 0.0
		if fill < 0.96 and i >= count - tail:
			lean = FILE_LEAN * float(i - (count - tail) + 1) / float(tail)
		var bottom := Vector3(inner.get_center().x + rng.randf_range(-0.002, 0.002), inner.position.y, z)
		var b := Basis(Vector3(1, 0, 0), -lean) * Basis(Vector3.UP, deg_to_rad(rng.randf_range(-1.2, 1.2))) * stand
		xfs.append(Transform3D(b, bottom + Basis(Vector3(1, 0, 0), -lean) * Vector3(0.0, v * 0.5, 0.0)))
	# THE DRAWN CARDS' PLACES in the file, away from the leaning tail
	var free: Array = range(0, count - tail)
	if shoebox:
		free = range(maxi(0, count - maxi(medium._cards.size() * 4, 24)), count)
	for k in medium._cards.size() if not piled else 0:
		var j := int(free.pop_at(rng.randi_range(0, free.size() - 1)))
		(stood["at_k"] as Array).append(xfs[j])
		xfs[j] = null
	# THE PLACES A SEARCH LOOKS: cards of the file's own, front to back, each drawn up out of its place
	# and let back into it - or lying cards' places, a card's thickness up (the piles' are their tops)
	if not piled:
		var seats: Array = []
		var lying := content == "loose"
		for n in mini(SEATS, free.size() / 4):
			# toward the back of the file, where the front wall hides none of a card coming up
			var j := int(free.pop_at(rng.randi_range(free.size() / 3, free.size() - 1)))
			var seat: Transform3D = xfs[j]
			xfs[j] = null
			if lying:
				# on top of the heap, each over the last
				seat.origin.y = inner.position.y + 0.006 + TableMedium.CARD_T * 1.1 * float(n)
			seats.append(seat)
		if not lying:
			seats.sort_custom(func(a: Transform3D, b: Transform3D) -> bool: return a.origin.z > b.origin.z)
		stood["search"] = seats
		stood["search_kept"] = true
	# one MultiMesh per printing and card, its cards shared out among them - and their places kept
	# (`filed`): a MultiMesh hands no instance's transform back under the dummy renderer of a headless run
	var per := {}
	for n in medium._backs:
		per[n] = []
	stood["filed"] = []
	for xf in xfs:
		if xf != null and not undrawn.is_empty():
			var name: String = undrawn.pop_at(rng.randi_range(0, undrawn.size() - 1))
			(per[name] as Array).append(xf)
			(stood["filed"] as Array).append(xf)
	for n in per:
		var kinds := medium._unseen_kinds(String(n))
		for which in kinds.size():
			var list: Array = []
			for i in (per[n] as Array).size():
				if i % kinds.size() == which:
					list.append((per[n] as Array)[i])
			if list.is_empty():
				continue
			var mesh := medium._mesh_for((medium._backs[n] as Dictionary)["canvas"].look).duplicate() as ArrayMesh
			# each a card nobody drew, its own front and back
			mesh.surface_set_material(0, (kinds[which] as Array)[0])
			mesh.surface_set_material(1, (kinds[which] as Array)[1])
			mesh.surface_set_material(2, medium._edge_mat)
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = mesh
			mm.instance_count = list.size()
			for i in list.size():
				mm.set_instance_transform(i, list[i])
			var inst := MultiMeshInstance3D.new()
			inst.multimesh = mm
			if shoebox:
				inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			medium._root3.add_child(inst)
			files.append(inst)
	_keep_searched(shoebox)


## THE CARDS A SEARCH LOOKS AT ARE THE BOX'S OWN, one kept in each of its places (`stood["search"]`, when
## `search_kept`): there before the search and after it, each a different card nobody drew, front and
## back ([method _unseen_all], through every printing in turn). A card that was not on its pile a moment
## before appeared on it as the look began, the top card's text changing under the eye (2026-10-12).
func _keep_searched(shoebox: bool) -> void:
	if not bool(stood.get("search_kept", false)):
		return
	var kinds := medium._unseen_all()
	var seats: Array = stood.get("search", [])
	for i in seats.size():
		var card := MeshInstance3D.new()
		card.mesh = medium._mesh_for(medium._plan.look)
		card.set_surface_override_material(0, (kinds[i % kinds.size()] as Array)[0])
		card.set_surface_override_material(1, (kinds[i % kinds.size()] as Array)[1])
		card.set_surface_override_material(2, medium._edge_mat)
		if shoebox:
			card.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		card.transform = seats[i]
		medium._root3.add_child(card)
		searched.append(card)


## THE CARDS LYING IN PILES in the box ([method TablePositions.box_piles]: a collection kept in piles, or
## in a shoebox left as it fell), all [param count] of them. THE DRAWN CARDS WAIT ON TOP OF THE PILES
## (`at_k`), the first to be drawn uppermost where two share a pile, so every card is taken off a pile
## and none out from under another. A card put back goes on a pile none is drawn from (`return_at`, and
## the way that pile lies, `return_turn`), one on the last. Eight cards used to float loose at the rim
## over the piles for the drawing, a spot in the air beside them for the returns (the user, 2026-10-11:
## "the loose cards on top is a strange look"). Returns the places left for the cards nobody draws.
func _pile_places(inner: AABB, size: Vector2, count: int, pitch: float, rng: RandomNumberGenerator) -> Array:
	var mess := 1.0 if String(medium._plan.staging.get("contents", "file")) == "loose" else TablePositions.PILES_NEAT
	var piles := TablePositions.box_piles(inner, size, count, pitch, mess, rng)
	var stocked: Array = []
	for i in piles.size():
		if not ((piles[i] as Dictionary)["cards"] as Array).is_empty():
			stocked.append(i)
	var back := -1
	if stocked.size() > 1:
		back = int(stocked.pop_at(rng.randi_range(0, stocked.size() - 1)))
		var held := 0
		for i in stocked:
			held += ((piles[i] as Dictionary)["cards"] as Array).size()
		if held < medium._cards.size():
			stocked.append(back)
	elif stocked.size() == 1:
		back = int(stocked[0])
	if back >= 0:
		var top: Transform3D = ((piles[back] as Dictionary)["cards"] as Array)[-1]
		stood["return_at"] = top.origin + Vector3(0.0, pitch, 0.0)
		stood["return_turn"] = atan2(-top.basis.x.z, top.basis.x.x)
	for i in range(stocked.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swap: int = stocked[i]
		stocked[i] = stocked[j]
		stocked[j] = swap
	# WHAT A SEARCH LOOKS AT: THE TOP CARD OF A PILE NOTHING IS DRAWN FROM, kept there (`search_kept`,
	# [method _keep_searched]) - as many piles as can be spared, the draws keeping two where there are
	# three, and cards enough. With none to spare (the returns' pile is drawn from, or there is one
	# pile), a card's thickness over a pile as it was built, and no card kept for it.
	var seats: Array = []
	var spare := clampi(stocked.size() - (2 if stocked.size() > 2 else 1), 0, SEATS)
	if stocked.has(back):
		spare = 0
	while spare > 0:
		var left := 0
		for i in stocked.size() - spare:
			left += ((piles[stocked[i]] as Dictionary)["cards"] as Array).size()
		if left >= medium._cards.size():
			break
		spare -= 1
	for n in spare:
		seats.append(((piles[int(stocked.pop_back())] as Dictionary)["cards"] as Array).pop_back())
	stood["search_kept"] = not seats.is_empty()
	if seats.is_empty():
		for i in stocked:
			if i != back or stocked.size() == 1:
				var top: Transform3D = ((piles[i] as Dictionary)["cards"] as Array)[-1]
				seats.append(top.translated(Vector3(0.0, pitch, 0.0)))
	var turn := 0
	for k in medium._cards.size():
		var from: Array = []
		for tries in stocked.size():
			from = (piles[stocked[(turn + tries) % stocked.size()]] as Dictionary)["cards"]
			if not from.is_empty():
				turn += tries + 1
				break
		(stood["at_k"] as Array).append(from.pop_back() if not from.is_empty()
			else Transform3D(Basis.IDENTITY, inner.get_center()))
	var rest: Array = []
	for p in piles:
		rest.append_array((p as Dictionary)["cards"])
	stood["search"] = seats
	return rest


## A few ordinary small keepsakes rest in the open space at the back of the container.
## They are not cards, so they never enter the draw or the file's inventory.
func _build_box_objects() -> void:
	var inner: AABB = stood["inner"]
	stood["objects_rest"] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([medium._plan.seed_value, "box keepsakes"])
	for item in medium._plan.staging.get("keepsakes", []) if medium._plan.staging.get("keepsakes") is Array else []:
		var kind := String(item)
		var mesh: PrimitiveMesh
		var color := Color(0.72, 0.65, 0.49)
		match kind:
			"coin", "button":
				var round_mesh := CylinderMesh.new()
				round_mesh.top_radius = 0.008 if kind == "coin" else 0.006
				round_mesh.bottom_radius = round_mesh.top_radius
				round_mesh.height = 0.0015 if kind == "coin" else 0.0025
				mesh = round_mesh
				color = Color(0.68, 0.54, 0.29) if kind == "coin" else Color(0.47, 0.35, 0.3)
			"marble":
				var round_mesh := SphereMesh.new()
				round_mesh.radius = 0.006
				round_mesh.height = 0.012
				mesh = round_mesh
				color = Color(0.21, 0.47, 0.56)
			"ticket":
				var paper := BoxMesh.new()
				paper.size = Vector3(0.024, 0.0007, 0.014)
				mesh = paper
				color = Color(0.78, 0.72, 0.58)
			_:
				continue
		var obj := MeshInstance3D.new()
		obj.mesh = mesh
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		mat.roughness = 0.55 if kind == "marble" else 0.85
		obj.material_override = mat
		var x := inner.get_center().x + rng.randf_range(-0.28, 0.28) * inner.size.x
		var z := inner.position.z + inner.size.z * rng.randf_range(0.07, 0.13)
		obj.position = Vector3(x, inner.position.y + (0.006 if kind == "marble" else 0.002), z)
		obj.rotation.y = rng.randf_range(-0.25, 0.25)
		medium._root3.add_child(obj)
		objects.append(obj)
		(stood["objects_rest"] as Array).append(obj.transform)


## The planned cards still in the box, by printing. A shoebox repeats those printings to fill
## the physical container - [param want] cards with the drawn ones - without asking the producer to
## enumerate every unseen card.
func _file_inventory(want := CardTable.SHOEBOX_FILL, pad := stood.has("lid")) -> Array:
	var plan: Dictionary = medium._plan.pay.get("plan", {}) if medium._plan.pay.get("plan") is Dictionary else {}
	var names: Array = []
	var deck: Array = plan.get("deck", []) if plan.get("deck") is Array else []
	if not deck.is_empty():
		for card in deck:
			if card is Dictionary:
				names.append(CardTable.series_of(medium._plan.look, card as Dictionary))
	else:
		var inventory: Dictionary = plan.get("inventory", {}) if plan.get("inventory") is Dictionary else {}
		var counts: Dictionary = inventory.get("printings", {}) if inventory.get("printings") is Dictionary else {}
		for name in counts:
			for i in maxi(0, int(counts[name])):
				names.append(String(name))
	if names.is_empty():
		for card in medium._plan.pay.get("cards", []) if medium._plan.pay.get("cards") is Array else []:
			if card is Dictionary:
				names.append(CardTable.series_of(medium._plan.look, card as Dictionary))
	if pad and not names.is_empty():
		var printings := names.duplicate()
		while names.size() < want:
			names.append(printings[names.size() % printings.size()])
	for card in medium._plan.pay.get("cards", []) if medium._plan.pay.get("cards") is Array else []:
		if not (card is Dictionary) or names.is_empty():
			continue
		var name := CardTable.series_of(medium._plan.look, card as Dictionary)
		var at := names.find(name)
		names.remove_at(at if at >= 0 else 0)
	return names


## The cards come out of a box they are filed in (on edge, not lying flat in a tin).
func filed_on_edge() -> bool:
	return not stood.is_empty() and not bool(stood.get("flat", false)) and (stood.get("at_k", []) as Array).size() > 0
