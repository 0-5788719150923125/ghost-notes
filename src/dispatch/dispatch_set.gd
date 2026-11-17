extends RefCounted
class_name DispatchSet

## DispatchSet - the desk and everything on it, built (next/dispatch.md): one heavy dark desk with a worn green blotter in
## a hollow under the ground, seen from the chair - the terminal (a beige CRT on a flat case, a narrow keyboard on a
## coiled cable), a dozen flip phones in two rows with their names on masking tape, the round green radar scope, the
## shortwave receiver (dial at 20.1, needle meter, speaker, a small oscilloscope on it, headphones, two wires up into the
## dark), the dot-matrix printer feeding its paper off the desk's end into a heap, three small screens (a security
## monitor, a flat satellite monitor on an arm, a little television), the switch box (GOOD above, BAD below), the chart, the
## handbook, the mug, the gooseneck lamp, the patch panel, the GPS tracker; and the empty chair. Where the script uses them,
## a small flip clock and a tablet lying dark beside the keyboard ([method build]'s `wants`).
##
## Every thing on it is a prop played by a role ([PropMakes], next/working_props.md): its make - the role's own, shipped in
## `data/props/`, or one chosen and kept in the note ([member makes]) - built off the tree and placed here, its working
## parts played through its rig ([member rigs], [PropRig]: its faces, lights and named parts). What is the desk's own is built
## here: the room, the desk, the chair, the satellite monitor's arm, and what runs between things (cables, wires, the printer's
## paper and its heap, the ring of old coffee), each laid from a make's named points. In meters: the desk's top at
## [constant DESK_Y], its near edge (the chair's) at +z, x across from the chair. What shows something is a make's face the medium
## hands a picture.

## The worn green blotter on the desk's top (x, z: m) and its turn (degrees): a flat thing taped down lies wholly off it, on
## the desk's own top ([method _misfit]) - laid across its edge it would be taped to both and lie under it.
const BLOTTER := Rect2(-0.33, -0.05, 0.66, 0.44)
const BLOTTER_TURN := -1.5
## The desk: its top's height, its width and depth, where its near and far edges are.
const DESK_Y := 0.76
const DESK_W := 2.4
const DESK_D := 0.95
const NEAR := 0.40
const FAR := -0.55
## The chair: the seated eye, a little higher than a seated eye.
const EYE := Vector3(0.0, 1.24, 0.80)
## The phones: closed, a phone's width, length and thickness (m); the rows - the first phone's middle, the step along a
## row and between the rows; where a phone laid open on the desk lies (the first, and the step).
const PHONE := Vector3(0.05, 0.022, 0.096)
const PHONE_AT := Vector2(-1.04, -0.08)
const PHONE_STEP := Vector2(0.105, 0.155)
const ROW := 6
const HELD_AT := Vector2(-0.94, 0.318)
const HELD_STEP := 0.135
## How many phones may lie open on the desk at once, side by side, and how far each is turned off the last (degrees).
const HELD_SLOTS := 3
const HELD_FAN := 6.0
## The lid opens this far (degrees) about its hinge.
const LID_OPEN := 158.0
## The terminal: where its case stands and its keyboard, and the case's size, which the cable and the switch's wire are laid
## by where a make names no point for them.
const CASE := Vector3(0.44, 0.115, 0.40)
const CASE_AT := Vector2(0.0, -0.24)
const KEYBOARD_AT := Vector2(0.0, 0.14)
## Where each of the radar, receiver, printer, screens and lamp stands (x, z) on the desk: each clear of the others
## however the desk turns and shifts them ([constant JITTER]).
const RADAR_AT := Vector2(0.50, 0.02)
## How far under the radar's glass its close-up aims (m), so the knobs under the scope are in it too.
const RADAR_LOOK_LOW := 0.03
## The scale printed round the radar's gain knob ([DispatchScreens]'s `gain` face, on the make's `scale` face): the knob's radius
## and the face's width it is drawn for (m), and how far its numbers run round from one to ten (degrees, over the top) - as the
## radar's own make turns its knob ([method gain_angle]).
const GAIN_KNOB_R := 0.012
const GAIN_FACE := 0.044
const GAIN_SWING := 270.0
const RECEIVER_AT := Vector2(1.02, -0.33)
const PRINTER_AT := Vector2(-0.96, -0.36)
const FEED_AT := Vector2(-0.53, -0.42)
const TV_AT := Vector2(0.66, -0.47)
const LAMP_AT := Vector2(-0.32, -0.26)
## The satellite's monitor on its arm ([method _satellite]): the panel where its make gives none, the most its two segments reach, the step
## its clamp's place along the back edge is looked for at, and where it may hold the panel's middle - how far out from the
## desk's middle, how far back (+z the chair's edge) and how high over the desk's top (m), all on the phones' side.
const SAT_PANEL := Vector3(0.36, 0.235, 0.025)
const ARM_LEN := 0.30
const ARM_CLAMP_STEP := 0.02
## How far below the arm's head its post stops (m), and what each meter of the arm's reach costs where it chooses (a short arm,
## close behind the panel, before a long one).
const ARM_DROP := 0.10
const ARM_REACH_COST := 1.5
const ARM_X := [0.66, 0.74, 0.82, 0.90]
const ARM_Z := [-0.52, -0.47, -0.42]
const ARM_H := [0.34, 0.38, 0.42, 0.46]
## The stage's width for its height ([method in_frame]).
const FRAME_ASPECT := 16.0 / 9.0
## The heap of printed paper on the floor beside the desk's left end, and how high it is (knee-high).
const HEAP_AT := Vector2(-1.42, -0.30)
## How far each end of the desk's things may stand off its authored place (m, outward, and back or forward), and each big
## thing turn off its own (degrees), desk by desk.
const JITTER := 0.025
const JITTER_TURN := 5.0
## The small things, packed in this order ([method _pack]), each by the box its own meshes fill turned as it stands
## ([method bounds]): where it may go - `side` the radio's things', the phones', or either; `x` how far across from the
## middle, `z` how far back (+z the chair's edge) - and how it turns about up: `turn` drawn between (degrees), or `face`
## its local direction turned to the chair, give or take `give`. `flat`: nothing stands on it, a root may cross it, and it lies
## wholly off the blotter ([constant BLOTTER]); `low`: it
## may lie in the chair's reach before the keyboard and over the desk's near edge a little ([constant LOW_OVER]);
## `want`: built only where the script uses it; `anywhere`: tried anywhere on the desk once half its tries found no room in
## its region; `spare`: left off a desk with no room for it. What the camera reads is packed first. The mug stays at arm's reach beside the keyboard, 25 to 40 cm in from the edge.
const PACK := {
	"handbook": {"side": "radio", "x": Vector2(0.72, 1.0), "z": Vector2(-0.02, 0.22), "face": Vector2(-1.0, 0.0), "give": 8.0},
	"clock": {"side": "phones", "x": Vector2(0.20, 0.52), "z": Vector2(-0.14, 0.12), "face": Vector2(0.0, 1.0), "give": 6.0, "want": true, "anywhere": true},
	"chart": {"side": "either", "x": Vector2(0.43, 0.95), "z": Vector2(0.10, 0.32), "turn": Vector2(-3.0, 3.0), "flat": true, "anywhere": true},
	"tablet": {"side": "radio", "x": Vector2(0.20, 0.85), "z": Vector2(0.04, 0.32), "turn": Vector2(-7.2, 7.2), "want": true, "anywhere": true, "low": true},
	"mug": {"side": "either", "x": Vector2(0.20, 0.62), "z": Vector2(-0.02, 0.15), "turn": Vector2(-156.0, -84.0)},
	"switch": {"side": "either", "x": Vector2(0.18, 0.50), "z": Vector2(-0.02, 0.30), "turn": Vector2(-12.0, 12.0), "anywhere": true},
	"tracker": {"side": "either", "x": Vector2(0.2, 0.95), "z": Vector2(-0.12, 0.33), "turn": Vector2(18.0, 42.0), "anywhere": true},
	"cup": {"side": "either", "x": Vector2(0.24, 0.40), "z": Vector2(-0.30, -0.06), "turn": Vector2(-120.0, 120.0), "spare": true},
	"stamp": {"side": "either", "x": Vector2(0.05, 1.0), "z": Vector2(0.22, 0.33), "turn": Vector2(-12.0, 12.0), "spare": true},
}
## Room left round each small thing (m), and how many places each is tried at; where none is clear, the least bad tried
## (a spare thing is left off).
const PACK_MARGIN := 0.015
## A flat thing's room (the chart, taped down): to the desk's edge, and against what stands round it.
const FLAT_MARGIN := 0.005
## How far a low thing may lie out over the desk's near edge (m).
const LOW_OVER := 0.02
## The desk's roles ([PropMakes]), each with the salt its own make is drawn with from the desk's number ([method _rig]):
## renaming one redraws every desk's.
const MAKE_SALTS := {"mug": "mug", "pencil_cup": "cup", "terminal": "terminal", "keyboard": "keyboard", "phone": "phone",
	"radar": "radar", "receiver": "receiver", "printer": "printer", "feed": "feed", "satellite": "satellite", "tv": "tv",
	"tv_stand": "tv_stand", "lamp": "lamp", "switch": "switch", "handbook": "handbook", "stamp": "stamp", "tracker": "tracker",
	"chart": "chart", "clock": "clock", "tablet": "tablet"}
## What of each thing the camera reads, by its make's faces ([member _faces]): what is packed is kept from hiding them.
const READ := {"terminal": ["screen"], "radar": ["scope", "scale"], "receiver": ["dial", "meter", "scope"], "feed": ["screen"],
	"satellite": ["screen"], "tv": ["screen"], "switch": ["good", "bad"], "handbook": ["spine"], "chart": ["chart"], "clock": ["cards"]}
## The material each phone's make wears in a color of its own ([constant PHONE_COLORS], drawn phone by phone).
const PHONE_TINT := "body"
const PHONE_COLORS := [Color(0.08, 0.08, 0.09), Color(0.42, 0.43, 0.46), Color(0.07, 0.10, 0.18), Color(0.18, 0.18, 0.2), Color(0.30, 0.06, 0.06)]
const PACK_TRIES := 300
## What the camera turns to keeps in sight ([method _sights]): of each face read (a label, a dial, a screen, the clock's
## cards), at most this share hidden by a nearer thing packed in front of it, seen from the chair and from its own spot...
const HIDE_MOST := 0.04
## ...or of a thing only watched, never read, this much.
const HIDE_MOST_OF := {"mug": 0.3}
## A mesh that is a cable or a wire - laid here, or a make's rod (a `tube`: an antenna, a lamp's neck) - no part of the box its
## thing fills ([method bounds]).
const THIN := &"thin"

## The tablet held to be read low over the desk's near edge (x, height above the desk, z), tipped toward the chair this far
## from flat.
const TABLET_HELD := Vector3(0.0, 0.11, 0.36)
const TABLET_TILT := 50.0

const HEAP_H := 0.44
const SHEET := Vector2(0.38, 0.28)
## The room: the hollow's floor, ceiling and walls.
const CEILING := 3.4
const ROOM := Vector3(3.2, 0.0, 2.6)

## The root of everything, and its parts the medium poses.
var root: Node3D
var rigs := {}                    # a thing -> its make's rig ([PropRig]): every thing but the phones, which are each their own
var phones: Array = []            # each {label, node, rig, inner, outer, tape, home: Transform3D}
var terminal_screen: MeshInstance3D   # the faces the medium hands pictures ([PropRig.face]; null where a make has none)
var radar_screen: MeshInstance3D
var scope_screen: MeshInstance3D
var dial: MeshInstance3D
var paper: MeshInstance3D         # the sheet coming up out of the printer, printed
var heap: Node3D                  # the printed paper's heap on the floor
var heap_top: MeshInstance3D
var screens := {}                 # feed / satellite / tv -> {mesh, rig, node}
var mug: Node3D
var mug_home := Transform3D()
var lamp: Light3D                 # the lamp's light (its make's `lamp`), lit by the medium's feed
var chair: Node3D
var clock_face: MeshInstance3D    # the flip clock's cards (null without a clock)
var tablet: Node3D                # the tablet, posed by the medium (null without one)
var tablet_screen: MeshInstance3D
var tablet_home := Transform3D()
var footprints: Array = []        # Rect2s of what stands on the desk (x, z), for the roots to go round - nothing flat
var clear: Array = []             # AABBs of what fills the air by the desk, which no root goes through: the paper, its heap
var bodies := {}                  # a thing -> the box its meshes fill, in the set's space ([method bounds])
var things := {}                  # a thing -> its node, as built
var makes := {}                   # the makes chosen for the desk's parts in place of its own ({role: choice}, [DispatchProps])
var misfit := {}                  # a small thing -> how badly it fits where it was packed ([method _misfit]; 0: it fits)
var spots := {}                   # what the camera can turn to ([constant DispatchMedium.SPOTS] keys) -> {aim, eye, fov}

## The desk's layout, drawn from its number. [member flip]: which side the radio's things stand (the radar, the receiver,
## the television on its crate) and which the phones, the printer and its heap - the desk mirrored, each turn with it;
## each big thing a little off its place and turned ([method _lay_out]); and the small things packed where there is room
## ([method _pack], as the letter's desk packs its things, [DeskLook]): the mug at arm's reach beside the keyboard and
## never at the edge, the switch by the keyboard, the handbook, the chart near the edge, the pencil cup, the stamp, the
## tracker. Nothing packed stands in another thing, or between the chair and what the camera turns to ([method _sights]).
## Whatever a mark works and wherever the camera turns follows them ([method spot_of]).
var flip := 1.0
var at := {}                      # a thing -> where it stands (x, z)
var turn := {}                    # a thing -> how it is turned (degrees about up)

var _labels: PackedStringArray
var _seed := 1
var _faces := {}                  # a thing the camera turns to -> what of it must be seen ([method _sights]): Node3Ds
var _parts := {}                  # a thing -> its parts as it stands ([method _parts_of]): what is packed keeps clear of them
var _blocks := {}                 # a thing -> each of its meshes' boxes as it stands: what a line to a face may pass through
var _wants := {}                  # the things built only where the script uses them: clock, tablet
var _tex := {}
var _mats := {}
var _sat_panel := SAT_PANEL       # the satellite's make: its panel's size and its glass's, which the arm is reckoned by
var _sat_glass := Vector2(0.33, 0.206)


## Build the desk for phones [param labels] (their names, in order) and desk number [param seed], out of the tree (on a worker,
## as the table's is: nothing here may need the tree); [param tex] holds what [DispatchScreens] draws for it ([method
## DispatchScreens.textures]): the chart, the dial, the keypad, the gain scale. [param wants]: the things built only where the
## script uses them (`clock`, `tablet`).
func build(labels: PackedStringArray, seed: int, tex: Dictionary, wants := {}) -> Node3D:
	_labels = labels
	_seed = seed
	_wants = wants
	_tex = tex
	root = Node3D.new()
	root.name = "DispatchSet"
	_lay_out()
	_materials()
	_room()
	_desk()
	_terminal()
	_phones()
	_radar()
	_receiver()
	_printer()
	_things_back()
	_monitors()
	_things()
	_chair()
	for k in DispatchMedium.SPOTS:
		var s := spot_of(String(k))
		if not s.is_empty():
			spots[k] = s
	for k in bodies:
		if bool((PACK.get(k, {}) as Dictionary).get("flat", false)):
			continue
		# what stands on the desk, never what is held over it (the satellite's panel on its arm)
		var foot := Rect2()
		for part in _parts[k]:
			var b: AABB = (part as Dictionary)["box"]
			if b.position.y <= DESK_Y + 0.02:
				var r := Rect2(b.position.x, b.position.z, b.size.x, b.size.z)
				foot = r if not foot.has_area() else foot.merge(r)
		if foot.has_area():
			footprints.append(foot)
	return root


## Every thing's working parts at show time [param t] ([PropRig.pose]), each fed what [param feeds] holds for it by its key
## ([member rigs]); a phone is posed with its own ([member phones]' `rig`).
func pose(t: float, feeds: Dictionary) -> void:
	for k in rigs:
		(rigs[k] as PropRig).pose(t, feeds.get(k, {}))


# --- the layout -------------------------------------------------------------------------------------------------------

## The big things' places for this desk ([member at], [member turn]): the authored desk's ([constant RADAR_AT] and the
## rest, the radio's things at the right), mirrored or not, each end a little off as one and each thing turned a little.
## The terminal and keyboard stay put.
func _lay_out() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = hash([_seed, "layout"])
	flip = -1.0 if r.randf() < 0.5 else 1.0
	at = {"case": CASE_AT, "keyboard": KEYBOARD_AT}
	turn = {"case": 0.0, "keyboard": 0.0}
	var base := {"radar": [RADAR_AT, -14.0], "receiver": [RECEIVER_AT, -30.0], "printer": [PRINTER_AT, 90.0],
		"feed": [FEED_AT, 12.0], "tv": [TV_AT, -18.0], "lamp": [LAMP_AT, 0.0],
		"phones": [PHONE_AT, 0.0], "held": [HELD_AT, 0.0], "heap": [HEAP_AT, 0.0], "patch": [Vector2(0.02, -0.50), 0.0]}
	# each end of the desk moves as one, outward and back or forward a little, so what stands close together stays close;
	# the screens along the back move only back and forth
	var groups := {"radio": ["radar", "receiver", "tv"], "phones": ["phones", "printer", "feed", "lamp", "held", "heap"],
		"back": ["patch"]}
	var shifts := {}
	for g in groups:
		var out := r.randf_range(0.0, JITTER) if g != "back" else 0.0
		shifts[g] = Vector2(out, r.randf_range(-JITTER, JITTER) * (0.6 if g == "back" else 1.0))
	for k in base:
		var b: Array = base[k]
		var p: Vector2 = b[0]
		var shift := Vector2.ZERO
		for g in groups:
			if k in (groups[g] as Array):
				shift = shifts[g]
		var placed := Vector2(p.x * flip, p.y)
		at[k] = placed + Vector2(signf(placed.x) * shift.x, shift.y)
		turn[k] = float(b[1]) * flip + (r.randf_range(-JITTER_TURN, JITTER_TURN) if k not in ["printer", "phones", "held", "heap"] else 0.0)
	turn["printer"] = 90.0 * flip


## Where [param k] stands on the desk (x, z).
func at_of(k: String) -> Vector2:
	return at.get(k, Vector2.ZERO)


## Where [param k] stands, in the world, on the desk's top.
func desk_at(k: String) -> Vector3:
	return _desk_pos(at_of(k))


## The small things packed where there is room ([param made]: each built at the origin, unturned), in [constant PACK]'s
## order: each tried at places and turns drawn in its own region until one fits ([method _misfit]), else the least bad of
## them, then put in the set.
func _pack(made: Dictionary) -> void:
	var r := RandomNumberGenerator.new()
	r.seed = hash([_seed, "pack"])
	var held := held_rect()
	var reach := Rect2(-0.26, 0.26, 0.52, 0.2)
	for k in PACK:
		if not made.has(k):
			continue
		var row: Dictionary = PACK[k]
		var node: Node3D = made[k]
		var shape := _shape(node)
		var sights := _sights()
		var best := INF
		var best_xf := Transform3D()
		for t in PACK_TRIES:
			var side := String(row["side"])
			var sgn := flip if side == "radio" else (-flip if side == "phones" else (1.0 if r.randf() < 0.5 else -1.0))
			var xs: Vector2 = row["x"]
			var zs: Vector2 = row["z"]
			var cand := Vector2(sgn * r.randf_range(xs.x, xs.y), r.randf_range(zs.x, zs.y))
			if t >= PACK_TRIES / 2 and bool(row.get("anywhere", false)):
				cand = Vector2(r.randf_range(-DESK_W * 0.5, DESK_W * 0.5), r.randf_range(FAR, NEAR))
			var xf := Transform3D(Basis(Vector3.UP, deg_to_rad(_yaw(row, cand, r))), _desk_pos(cand))
			var bad := _misfit(k, node, shape, xf, held, reach, sights)
			if bad < best:
				best = bad
				best_xf = xf
			if bad <= 0.0:
				break
		misfit[k] = best
		if best > 0.0 and bool(row.get("spare", false)):
			at.erase(k)
			turn.erase(k)
			node.free()
			continue
		node.transform = best_xf
		at[k] = Vector2(best_xf.origin.x, best_xf.origin.z)
		turn[k] = rad_to_deg(best_xf.basis.get_euler().y)
		root.add_child(node)
		_body(k, node, true)


## A small thing's turn at [param place] (degrees about up), drawn from [param r]: between its row's `turn`, or its `face`
## turned to the chair, give or take its `give`. Turned by a about up, a direction (sin b, cos b) in (x, z) goes to
## (sin (a + b), cos (a + b)).
func _yaw(row: Dictionary, place: Vector2, r: RandomNumberGenerator) -> float:
	if row.has("face"):
		var a: Vector2 = row["face"]
		var to := Vector2(EYE.x, EYE.z) - place
		var give := float(row["give"])
		return rad_to_deg(atan2(to.x, to.y) - atan2(a.x, a.y)) + r.randf_range(-give, give)
	var t: Vector2 = row["turn"]
	return r.randf_range(t.x, t.y)


## How badly small thing [param k] ([param node], its [param shape]) fits standing as [param xf] - 0 where it fits: on the
## desk, off where a phone laid open lies ([param held]) and out of the chair's reach before the keyboard ([param reach]);
## its outline and a margin clear of every part of every thing standing ([method _meets]); and hiding no more of a face the
## camera turns to than it allows ([param sights], [method _sights]) nor hidden more itself. Off the desk outweighs standing
## in a thing, and that outweighs anything hidden.
func _misfit(k: String, node: Node3D, shape: Dictionary, xf: Transform3D, held: Rect2, reach: Rect2, sights: Array) -> float:
	var box := _box_at(shape, xf)
	node.transform = xf
	at[k] = Vector2(xf.origin.x, xf.origin.z)
	turn[k] = rad_to_deg(xf.basis.get_euler().y)
	var flat := bool(PACK[k].get("flat", false))
	var low := bool(PACK[k].get("low", false))
	var margin := FLAT_MARGIN if flat else PACK_MARGIN
	var foot := Rect2(box.position.x, box.position.z, box.size.x, box.size.z)
	var bad := 0.0
	var edge := NEAR + LOW_OVER if low else NEAR - margin
	if foot.position.x < -DESK_W * 0.5 + 0.03 or foot.end.x > DESK_W * 0.5 - 0.03 or foot.end.y > edge:
		bad += 10000.0
	if foot.grow(margin).intersects(held) or not (flat or low) and foot.intersects(reach):
		bad += 10000.0
	# a flat thing lies wholly off the blotter (its turn's few millimeters counted)
	if flat and foot.intersects(BLOTTER.grow(BLOTTER.size.x * 0.5 * absf(sin(deg_to_rad(BLOTTER_TURN))) + FLAT_MARGIN)):
		bad += 10000.0
	var part := _part_at(shape, xf)
	var room := box.grow(margin)
	var grown := Geometry2D.offset_polygon(part["outline"], margin)
	var outline: PackedVector2Array = grown[0] if not grown.is_empty() else part["outline"]
	for o in bodies:
		if room.intersects(bodies[o]) and _meets(outline, float(part["lo"]) - margin, float(part["hi"]) + margin, _parts[o]):
			bad += 1000.0
	var blocks := _blocks_at(shape, xf)
	for s in sights:
		bad += maxf(hidden(blocks, s) - float(s["most"]), 0.0)
	if _faces.has(k):
		var eyes := [EYE, spot_of(k).get("eye", EYE)]
		for f in _faces[k]:
			var pts := _face_points(f, box if f == node else null)
			for eye in eyes:
				var s := _sight(pts, eye, k)
				for o in bodies:
					bad += maxf(hidden(_blocks[o], s) - float(s["most"]), 0.0)
	return bad


## What the camera turns to, as it must be seen: each face ([member _faces]) of each thing standing, from the chair and from
## the thing's own spot ([method spot_of]) - [method _sight]s.
func _sights() -> Array:
	var out: Array = []
	for k in _faces:
		if not bodies.has(k):
			continue
		var eyes := [EYE, spot_of(k).get("eye", EYE)]
		for f in _faces[k]:
			var pts := _face_points(f, bodies[k] if f == things.get(k) else null)
			for eye in eyes:
				out.append(_sight(pts, eye, k))
	return out


## Where a face ([param f]) is looked at, in the set's space: a grid over it where it is flat (a screen, a label), else over
## the top and the chair's side of [param box] (the box it fills where null).
func _face_points(f: Node3D, box: Variant = null) -> PackedVector3Array:
	var out := PackedVector3Array()
	var mi := f as MeshInstance3D
	if mi != null and _flat(mi):
		var size: Vector2 = mi.get_meta("size") if mi.has_meta("size") else (mi.mesh as QuadMesh).size
		var xf := bounds_xf(f)
		for i in 5:
			for j in 3:
				out.append(xf * Vector3((0.2 * i - 0.4) * size.x, (0.35 * j - 0.35) * size.y, 0.0))
		return out
	var b: AABB = box if box is AABB else bounds(f)
	for i in 5:
		for j in 3:
			var u := 0.1 + 0.2 * i
			var v := 0.15 + 0.35 * j
			out.append(Vector3(lerpf(b.position.x, b.end.x, u), b.end.y, lerpf(b.position.z, b.end.z, v)))
			out.append(Vector3(lerpf(b.position.x, b.end.x, u), lerpf(b.position.y, b.end.y, v), b.end.z))
	return out


## A face's [param points], thing [param k]'s, as [param eye] sees them: `{k, eye, points, seen, most}`, `seen` the angles
## across and up they span ([method _seen]), `most` how much of it may be hidden ([constant HIDE_MOST_OF]).
static func _sight(points: PackedVector3Array, eye: Vector3, k: String) -> Dictionary:
	return {"k": k, "eye": eye, "points": points, "seen": _seen(points, eye), "most": float(HIDE_MOST_OF.get(k, HIDE_MOST))}


## [param points] as [param eye] sees them, looking toward -z: the angles across and up they span (radians).
static func _seen(points: PackedVector3Array, eye: Vector3) -> Rect2:
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for p in points:
		var d := p - eye
		var a := Vector2(atan2(d.x, -d.z), atan2(d.y, Vector2(d.x, d.z).length()))
		lo = lo.min(a)
		hi = hi.max(a)
	return Rect2(lo, hi - lo)


## How much of a face ([param s], a [method _sight]) a thing made of [param blocks] ([method _block]) hides: the share of its
## points whose line from the eye passes through one of the blocks on the way - each its mesh's own box, turned as the mesh
## is - of the blocks standing wholly before that eye.
static func hidden(blocks: Array, s: Dictionary) -> float:
	var eye: Vector3 = s["eye"]
	var near: Array = []
	for b in blocks:
		var w: AABB = (b as Dictionary)["world"]
		if w.end.z > eye.z - 0.02:
			continue
		var corners := PackedVector3Array()
		for i in 8:
			corners.append(w.get_endpoint(i))
		if _seen(corners, eye).intersects(s["seen"]):
			near.append(b)
	if near.is_empty():
		return 0.0
	var pts: PackedVector3Array = s["points"]
	var n := 0
	for p in pts:
		var to := p.lerp(eye, 0.01)
		for b in near:
			var inv: Transform3D = (b as Dictionary)["inv"]
			if ((b as Dictionary)["box"] as AABB).intersects_segment(inv * eye, inv * to) != null:
				n += 1
				break
	return float(n) / maxf(float(pts.size()), 1.0)


## The box [param node]'s meshes fill, in the set's space, whether it is in the set yet or not: every vertex of each, a
## cable's and a wire's left out ([constant THIN]). A node with no mesh is a point where it stands.
func bounds(node: Node3D) -> AABB:
	var xf := bounds_xf(node)
	var pts := _gather(node, xf)
	if pts.is_empty():
		return AABB(xf.origin, Vector3.ZERO)
	var b := AABB(pts[0], Vector3.ZERO)
	for p in pts:
		b = b.expand(p)
	return b


## [param node]'s transform in the set's space, whether it is in the set yet or not.
func bounds_xf(node: Node3D) -> Transform3D:
	var xf := node.transform
	var p := node.get_parent()
	while p != null and p != root and p is Node3D:
		xf = (p as Node3D).transform * xf
		p = p.get_parent()
	return xf


## Every vertex under [param n] (its own meshes and its children's), placed by [param xf], but a thin mesh's.
static func _gather(n: Node3D, xf: Transform3D) -> PackedVector3Array:
	var pts := PackedVector3Array()
	var mi := n as MeshInstance3D
	if mi != null and mi.mesh != null and not mi.mesh.has_meta(THIN):
		pts = xf * mi.mesh.get_faces()
	for c in n.get_children():
		var c3 := c as Node3D
		if c3 != null:
			pts.append_array(_gather(c3, xf * c3.transform))
	return pts


## [param node]'s own shape, at the origin unturned: the outline of its vertices seen from above, how high they reach and
## each mesh's own box ([method _mesh_boxes]) - what [method _box_at] and [method _blocks_at] turn and move.
static func _shape(node: Node3D) -> Dictionary:
	var pts := _gather(node, Transform3D.IDENTITY)
	var boxes: Array = []
	_mesh_boxes(node, Transform3D.IDENTITY, boxes)
	if pts.is_empty():
		return {"outline": PackedVector2Array([Vector2.ZERO]), "lo": 0.0, "hi": 0.0, "boxes": boxes}
	var flat := PackedVector2Array()
	var lo := INF
	var hi := -INF
	for p in pts:
		flat.append(Vector2(p.x, p.z))
		lo = minf(lo, p.y)
		hi = maxf(hi, p.y)
	return {"outline": Geometry2D.convex_hull(flat), "lo": lo, "hi": hi, "boxes": boxes}


## Each mesh under [param n] placed by [param xf] as a block ([method _block]), a flat one's and a thin one's left out: the
## smaller of its own box turned as it is - square to its part where a make's mesh says where its part stands in it (its
## `xform` meta, [method Props.build]) - and the box its vertices fill square to [param xf]'s frame (a shape turned on its own
## axis, as the terminal's four-sided body is, fills its own box only half).
static func _mesh_boxes(n: Node3D, xf: Transform3D, out: Array) -> void:
	var mi := n as MeshInstance3D
	if mi != null and mi.mesh != null and not mi.mesh.has_meta(THIN) and not _flat(mi):
		var own := mi.mesh.get_aabb()
		var own_xf := xf
		if mi.has_meta("xform"):
			var px: Transform3D = mi.get_meta("xform")
			var local := px.affine_inverse() * mi.mesh.get_faces()
			if not local.is_empty():
				own = AABB(local[0], Vector3.ZERO)
				for q in local:
					own = own.expand(q)
				own_xf = xf * px
		var pts := xf * mi.mesh.get_faces()
		var square := AABB(pts[0], Vector3.ZERO) if not pts.is_empty() else AABB()
		for p in pts:
			square = square.expand(p)
		out.append(_block(square, Transform3D.IDENTITY) if square.get_volume() < own.get_volume() else _block(own, own_xf))
	for c in n.get_children():
		var c3 := c as Node3D
		if c3 != null:
			_mesh_boxes(c3, xf * c3.transform, out)


## Whether [param mi] is flat on something already: a make's face (its `size` meta, [method Props.build]) or a quad.
static func _flat(mi: MeshInstance3D) -> bool:
	return mi.has_meta("size") or mi.mesh is QuadMesh


## A mesh's own box [param box] placed by [param xf]: `{box, xf, inv}` and `world`, the box it fills square to the set.
static func _block(box: AABB, xf: Transform3D) -> Dictionary:
	return {"box": box, "xf": xf, "inv": xf.affine_inverse(), "world": xf * box}


## A [method _shape]'s blocks turned about up and moved by [param xf].
static func _blocks_at(shape: Dictionary, xf: Transform3D) -> Array:
	var out: Array = []
	for b in shape["boxes"]:
		out.append(_block(b["box"], xf * (b["xf"] as Transform3D)))
	return out


## The box a [method _shape] fills turned about up and moved by [param xf].
static func _box_at(shape: Dictionary, xf: Transform3D) -> AABB:
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for q in shape["outline"]:
		var w := xf * Vector3(q.x, 0.0, q.y)
		lo = lo.min(Vector2(w.x, w.z))
		hi = hi.max(Vector2(w.x, w.z))
	return AABB(Vector3(lo.x, xf.origin.y + float(shape["lo"]), lo.y),
		Vector3(hi.x - lo.x, float(shape["hi"]) - float(shape["lo"]), hi.y - lo.y))


## A [method _shape] turned about up and moved by [param xf]: its outline from above in the set's space and how high it
## reaches, `{outline, lo, hi, box}` - one part ([method _parts_of]).
static func _part_at(shape: Dictionary, xf: Transform3D) -> Dictionary:
	var outline := PackedVector2Array()
	for q in shape["outline"]:
		var w := xf * Vector3(q.x, 0.0, q.y)
		outline.append(Vector2(w.x, w.z))
	return {"outline": outline, "lo": xf.origin.y + float(shape["lo"]), "hi": xf.origin.y + float(shape["hi"]),
		"box": _box_at(shape, xf)}


## Whether [param outline], from [param lo] to [param hi] high, meets any of [param parts] ([method _parts_of]).
static func _meets(outline: PackedVector2Array, lo: float, hi: float, parts: Array) -> bool:
	for part in parts:
		var pd: Dictionary = part
		if float(pd["hi"]) < lo or float(pd["lo"]) > hi:
			continue
		if not Geometry2D.intersect_polygons(outline, pd["outline"]).is_empty():
			return true
	return false


## [param node]'s parts, as it stands: each mesh's outline from above, how high it reaches and its box ([method _part_at]),
## a flat one's (a screen, a label: on something already) and a thin one's left out; or the whole of it as one part where
## [param whole] (a small thing, a row of phones).
func _parts_of(node: Node3D, whole: bool) -> Array:
	var xf := bounds_xf(node)
	if whole:
		var pts := _gather(node, xf)
		return [] if pts.is_empty() else [_part_of(pts)]
	var out: Array = []
	_mesh_parts(node, xf, out)
	return out


static func _mesh_parts(n: Node3D, xf: Transform3D, out: Array) -> void:
	var mi := n as MeshInstance3D
	if mi != null and mi.mesh != null and not mi.mesh.has_meta(THIN) and not _flat(mi):
		var pts := xf * mi.mesh.get_faces()
		if not pts.is_empty():
			out.append(_part_of(pts))
	for c in n.get_children():
		var c3 := c as Node3D
		if c3 != null:
			_mesh_parts(c3, xf * c3.transform, out)


## One part round [param pts] (in the set's space): their outline from above, how high they reach, their box.
static func _part_of(pts: PackedVector3Array) -> Dictionary:
	var flat := PackedVector2Array()
	var b := AABB(pts[0], Vector3.ZERO)
	for p in pts:
		flat.append(Vector2(p.x, p.z))
		b = b.expand(p)
	return {"outline": Geometry2D.convex_hull(flat), "lo": b.position.y, "hi": b.end.y, "box": b}


## [param node] stands on the desk as thing [param k]: it, the box its meshes fill, its parts ([method _parts_of]; one part
## where [param whole]) and each mesh's box kept ([member things], [member bodies]).
func _body(k: String, node: Node3D, whole := false) -> void:
	things[k] = node
	bodies[k] = bounds(node)
	_parts[k] = _parts_of(node, whole)
	var blocks: Array = []
	_mesh_boxes(node, bounds_xf(node), blocks)
	_blocks[k] = blocks


## Where a phone laid open lies (x, z): the whole of the first [constant HELD_SLOTS] laid open as they lie - the base and
## the lid opened out past its hinge (up to 14 cm past the base), each turned as [method held_xf] lays it - and a
## centimeter round.
func held_rect() -> Rect2:
	var lid := -PHONE.z * 0.5 - PHONE.z * absf(cos(deg_to_rad(180.0 - LID_OPEN)))
	var corners: Array[Vector3] = [Vector3(-PHONE.x * 0.5, 0, PHONE.z * 0.5), Vector3(PHONE.x * 0.5, 0, PHONE.z * 0.5),
		Vector3(-PHONE.x * 0.5, 0, lid), Vector3(PHONE.x * 0.5, 0, lid)]
	var first := held_xf(0) * corners[0]
	var out := Rect2(Vector2(first.x, first.z), Vector2.ZERO)
	for k in HELD_SLOTS:
		var xf := held_xf(k)
		for c in corners:
			var w := xf * c
			out = out.expand(Vector2(w.x, w.z))
	return out.grow(0.01)


# --- materials --------------------------------------------------------------------------------------------------------

## What the desk's own is made of: the cables, the arm, the chair, the heap's paper, the pedestals and the hollow's earth.
func _materials() -> void:
	_mats["beige_dark"] = _std(Color(0.62, 0.58, 0.49), 0.6)
	_mats["black"] = _std(Color(0.035, 0.035, 0.04), 0.4)
	_mats["dark"] = _std(Color(0.10, 0.10, 0.11), 0.5)
	_mats["metal"] = _std(Color(0.55, 0.56, 0.58), 0.3, 0.85)
	_mats["wood_dark"] = _std(Color(0.12, 0.07, 0.045), 0.55)
	_mats["cable"] = _std(Color(0.08, 0.08, 0.085), 0.6)
	_mats["cable_blue"] = _std(Color(0.10, 0.28, 0.72), 0.45)
	_mats["cable_yellow"] = _std(Color(0.85, 0.70, 0.10), 0.45)
	_mats["paper"] = _std(Color(0.88, 0.87, 0.82), 0.9)
	_mats["fabric"] = _std(Color(0.10, 0.10, 0.11), 0.95)
	_mats["earth"] = _earth()


static func _std(c: Color, rough: float, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	return m


## The hollow's earth: dark, rough, its grain from noise.
func _earth() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	var n := FastNoiseLite.new()
	n.seed = _seed
	n.frequency = 0.04
	n.fractal_octaves = 5
	var tex := NoiseTexture2D.new()
	tex.noise = n
	tex.seamless = true
	tex.width = 512
	tex.height = 512
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.035, 0.028, 0.022))
	ramp.set_color(1, Color(0.13, 0.10, 0.075))
	tex.color_ramp = ramp
	m.albedo_texture = tex
	var nrm := NoiseTexture2D.new()
	nrm.noise = n
	nrm.seamless = true
	nrm.as_normal_map = true
	nrm.bump_strength = 6.0
	nrm.width = 512
	nrm.height = 512
	m.normal_enabled = true
	m.normal_texture = nrm
	m.roughness = 0.95
	m.uv1_triplanar = true
	m.uv1_scale = Vector3(0.6, 0.6, 0.6)
	return m


# --- geometry helpers -------------------------------------------------------------------------------------------------

## A rounded box [param size] (m) with its edges rounded [param r], its middle at its origin: a cube's faces cut in a grid
## and laid on the rounded box (the point's nearest on the box shrunk by r, pushed back out by r along the way to it), as
## [Props]' block is made.
static func rbox(size: Vector3, r: float, n := 6) -> ArrayMesh:
	var h := size * 0.5
	r = minf(r, minf(h.x, minf(h.y, h.z)) * 0.98)
	var inner := h - Vector3(r, r, r)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var faces := [[Vector3.RIGHT, Vector3.UP, Vector3.BACK], [Vector3.LEFT, Vector3.UP, Vector3.FORWARD],
		[Vector3.UP, Vector3.BACK, Vector3.RIGHT], [Vector3.DOWN, Vector3.FORWARD, Vector3.RIGHT],
		[Vector3.BACK, Vector3.UP, Vector3.LEFT], [Vector3.FORWARD, Vector3.UP, Vector3.RIGHT]]
	for f in faces:
		var nrm: Vector3 = f[0]
		var u: Vector3 = f[1]
		var v: Vector3 = f[2]
		var grid: Array = []
		for j in n + 1:
			var row: Array = []
			for i in n + 1:
				var a := _rb_step(float(i) / float(n), h, r, v)
				var b := _rb_step(float(j) / float(n), h, r, u)
				var q := Vector3(nrm.x * h.x, nrm.y * h.y, nrm.z * h.z) + v * a + u * b
				var c := q.clamp(-inner, inner)
				var d := q - c
				var nn := d.normalized() if d.length() > 1e-9 else nrm
				row.append([c + nn * r if d.length() > 1e-9 else q, nn, Vector2(float(i) / n, 1.0 - float(j) / n)])
			grid.append(row)
		for j in n:
			for i in n:
				var p00: Array = grid[j][i]
				var p10: Array = grid[j][i + 1]
				var p01: Array = grid[j + 1][i]
				var p11: Array = grid[j + 1][i + 1]
				# clockwise from outside: Godot's front faces
				for t in [p00, p11, p01, p00, p10, p11]:
					st.set_normal(t[1])
					st.set_uv(t[2])
					st.add_vertex(t[0])
	return st.commit()


## Where the [param k] (0-1) way across a face lands along [param axis]: crowded into the rounded edges.
static func _rb_step(k: float, h: Vector3, r: float, axis: Vector3) -> float:
	var half := absf(axis.dot(h))
	var flat := half - r
	if k < 0.2:
		return -half + r * (1.0 - cos(k / 0.2 * PI * 0.5))
	if k > 0.8:
		return half - r * (1.0 - cos((1.0 - k) / 0.2 * PI * 0.5))
	return -flat + 2.0 * flat * (k - 0.2) / 0.6


## A mesh instance of [param mesh] in [param mat] at [param at] under [param parent].
static func put(parent: Node3D, mesh: Mesh, mat: Material, at: Vector3, rot := Vector3.ZERO) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.material_override = mat
	m.position = at
	m.rotation_degrees = rot
	parent.add_child(m)
	return m


static func box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b


static func cyl(r_top: float, r_bottom: float, h: float, sides := 24) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = r_top
	c.bottom_radius = r_bottom
	c.height = h
	c.radial_segments = sides
	c.rings = 1
	return c


static func quad(size: Vector2) -> QuadMesh:
	var q := QuadMesh.new()
	q.size = size
	return q


## A tube along [param path] (m), [param radius] round (or [param radii], one a point), [param sides] round: a cable, a
## wire, a coil.
static func tube(path: PackedVector3Array, radius: float, sides := 8, radii := PackedFloat32Array()) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := path.size()
	if n < 2:
		return st.commit()
	var rings: Array = []
	var up := Vector3.UP
	for i in n:
		var t := (path[mini(i + 1, n - 1)] - path[maxi(i - 1, 0)]).normalized()
		if absf(t.dot(up)) > 0.95:
			up = Vector3.RIGHT
		var bx := t.cross(up).normalized()
		var by := bx.cross(t).normalized()
		up = by
		var rr := radii[i] if i < radii.size() else radius
		var ring: Array = []
		for k in sides + 1:
			var a := TAU * float(k) / float(sides)
			var d := bx * cos(a) + by * sin(a)
			ring.append([path[i] + d * rr, d])
		rings.append(ring)
	for i in n - 1:
		for k in sides:
			var a: Array = rings[i][k]
			var b: Array = rings[i][k + 1]
			var c: Array = rings[i + 1][k]
			var d: Array = rings[i + 1][k + 1]
			for p in [a, d, c, a, b, d]:
				st.set_normal(p[1])
				st.add_vertex(p[0])
	var m := st.commit()
	m.set_meta(THIN, true)
	return m


## A cable's path: from [param a] to [param b], sagging [param sag] and lying on the desk where it would ([param floor_y]),
## [param n] points.
static func sag_path(a: Vector3, b: Vector3, sag: float, floor_y: float, n := 24) -> PackedVector3Array:
	var out := PackedVector3Array()
	for i in n + 1:
		var u := float(i) / float(n)
		var p := a.lerp(b, u)
		p.y -= sag * 4.0 * u * (1.0 - u)
		p.y = maxf(p.y, floor_y)
		out.append(p)
	return out


func _desk_pos(at: Vector2, up := 0.0) -> Vector3:
	return Vector3(at.x, DESK_Y + up, at.y)


# --- the room ---------------------------------------------------------------------------------------------------------

## The hollow: an earthen floor, ceiling and walls round the desk, mostly lost in the dark.
func _room() -> void:
	var earth: Material = _mats["earth"]
	var w := ROOM.x * 2.0
	var d := ROOM.z * 2.0
	put(root, box(Vector3(w, 0.1, d)), earth, Vector3(0, -0.05, -0.6))
	put(root, box(Vector3(w, 0.2, d)), earth, Vector3(0, CEILING + 0.1, -0.6))
	put(root, box(Vector3(w, CEILING, 0.3)), earth, Vector3(0, CEILING * 0.5, -0.6 - ROOM.z - 0.15))
	put(root, box(Vector3(0.3, CEILING, d)), earth, Vector3(-ROOM.x - 0.15, CEILING * 0.5, -0.6))
	put(root, box(Vector3(0.3, CEILING, d)), earth, Vector3(ROOM.x + 0.15, CEILING * 0.5, -0.6))
	put(root, box(Vector3(w, CEILING, 0.3)), earth, Vector3(0, CEILING * 0.5, -0.6 + ROOM.z + 0.15))


# --- the desk ---------------------------------------------------------------------------------------------------------

## The desk: its top built as the card table's is ([Tables]: dark boards, their grain and seams), a worn green blotter laid
## on it, and two pedestals under it.
func _desk() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = hash([_seed, "dispatch desk"])
	var mat := {"kind": "wood", "color": "#2a1810", "color2": "#140a06", "polish": 0.22, "pattern": 0.6, "grain": 1.4, "wear": 0.4}
	var top := {"shape": "rect", "size": [DESK_W * 100.0, DESK_D * 100.0], "thickness": 4.5, "edge": "eased", "material": "the desk",
		"boards": {"width": 19.0, "turn": 0.0}}
	var mid := Vector2(0.0, (NEAR + FAR) * 0.5)
	var blot := BLOTTER.get_center()
	var lay := {"name": "the blotter", "what": "a worn green blotter", "outline": "rect", "size": [BLOTTER.size.x * 100.0, BLOTTER.size.y * 100.0],
		"at": [(blot.x - mid.x - Tables.TOP_AT.x) * 100.0, (blot.y - mid.y - Tables.TOP_AT.y) * 100.0], "turn": BLOTTER_TURN,
		"fabric": "felt", "pattern": {"kind": "plain", "colors": ["#2c4a33"]},
		"border": {"width": 2.6, "inset": 0.0, "color": "#3b2a1c"}}
	var spec := Tables.sanitize(top, [lay], {"the desk": Props.sanitize_material(mat, "#2a1810")}, [])
	var built := Tables.build(spec, _seed)
	var furniture: Node3D = built["node"]
	furniture.position = Vector3(mid.x - Tables.ORIGIN.x - Tables.TOP_AT.x, DESK_Y, mid.y - Tables.ORIGIN.y - Tables.TOP_AT.y)
	root.add_child(furniture)
	var wood: Material = _mats["wood_dark"]
	for side in [-1.0, 1.0]:
		var ped := Vector3(0.48, DESK_Y - 0.05, DESK_D - 0.08)
		put(root, rbox(ped, 0.01), wood, Vector3(side * (DESK_W * 0.5 - ped.x * 0.5 - 0.03), ped.y * 0.5, mid.y))
		for k in 3:
			var y := 0.12 + float(k) * 0.21
			put(root, rbox(Vector3(0.44, 0.19, 0.012), 0.004), wood, Vector3(side * (DESK_W * 0.5 - 0.27), y + 0.05, NEAR - 0.035))
			put(root, cyl(0.006, 0.006, 0.07, 8), _mats["metal"], Vector3(side * (DESK_W * 0.5 - 0.27), y + 0.08, NEAR - 0.022), Vector3(0, 0, 90))
	put(root, box(Vector3(DESK_W - 1.0, DESK_Y - 0.25, 0.025)), wood, Vector3(0, DESK_Y * 0.5 + 0.1, FAR + 0.08))


# --- the makes ----------------------------------------------------------------------------------------------------------

## Role [param role]'s make on this desk, built and rigged ([method PropMakes.made], [PropRig]): the one [member makes] chooses,
## else the role's own, drawn from the desk's number and the role's salt ([constant MAKE_SALTS]). Its node stands at the origin,
## its foot on y = 0, its front toward +z; its rods are thin ([constant THIN]). Touches no tree.
func _rig(role: String) -> PropRig:
	var choice: Variant = makes.get(role, {})
	var b := PropMakes.made(role, choice if PropMakes.valid(choice) else {}, hash([_seed, String(MAKE_SALTS.get(role, role))]))
	if not (b.get("node") is Node3D):
		b = {"node": Node3D.new(), "size": AABB()}
	var rig := PropRig.new(b)
	rig.node.name = role.to_pascal_case()
	for mi in rig.node.find_children("*", "MeshInstance3D", true, false):
		if String((mi as MeshInstance3D).get_meta("shape", "")) == "tube" and (mi as MeshInstance3D).mesh != null:
			(mi as MeshInstance3D).mesh.set_meta(THIN, true)
	return rig


## Role [param role]'s make stood on the desk at [param at] (the set's space), turned [param yaw] degrees about up: in [member
## rigs] and in the set.
func _place(role: String, at: Vector3, yaw: float) -> PropRig:
	var rig := _rig(role)
	rig.node.transform = Transform3D(Basis(Vector3.UP, deg_to_rad(yaw)), at)
	root.add_child(rig.node)
	rigs[role] = rig
	return rig


## Where thing [param k]'s make has point [param name] (the set's space), or [param fallback] where it names none.
func _point(k: String, name: String, fallback: Vector3) -> Vector3:
	var rig: PropRig = rigs.get(k)
	var p: Variant = rig.point(name) if rig != null else null
	return bounds_xf(rig.node) * (p as Vector3) if p is Vector3 else fallback


## The faces of thing [param k]'s make the camera reads ([constant READ]) that it has.
func _read(k: String) -> Array:
	var out: Array = []
	var rig: PropRig = rigs.get(k)
	for f in READ.get(k, []):
		if rig != null and rig.face(String(f)) != null:
			out.append(rig.face(String(f)))
	return out


## The desk's own number for [param k]'s picture ([constant MAKE_SALTS]) - what [DispatchProps] pictures it as.
static func own_seed(k: String, seed: int) -> int:
	return hash([seed, String(MAKE_SALTS.get(k, k))])


# --- the terminal -----------------------------------------------------------------------------------------------------

## The terminal and its keyboard, their makes ([PropMakes] `terminal`, `keyboard`) standing where the desk keeps them, and the
## keyboard's coiled cable laid from the keyboard's `cable` point to the terminal's. The glass ([member terminal_screen]) is the
## medium's to hand a picture.
func _terminal() -> void:
	var t := _place("terminal", _desk_pos(CASE_AT), 0.0)
	terminal_screen = t.face("screen")
	_body("terminal", t.node)
	_faces["terminal"] = _read("terminal")
	var kb := _place("keyboard", _desk_pos(KEYBOARD_AT), 0.8)
	_body("keyboard", kb.node)
	# the coiled cable: from the keyboard's back, a coil on the desk, up into the case's front
	var path := PackedVector3Array()
	var a := _point("keyboard", "cable", Vector3(0.0, DESK_Y + 0.012, KEYBOARD_AT.y - 0.067))
	var b := _point("terminal", "cable", Vector3(0.16, DESK_Y + 0.02, CASE_AT.y + CASE.z * 0.5))
	for i in 120:
		var u := float(i) / 119.0
		var p := a.lerp(b, u)
		var ang := u * TAU * 11.0
		var coil := 0.008 * sin(u * PI)
		p += Vector3(cos(ang) * coil, sin(ang) * coil + 0.008 * sin(u * PI), 0.0)
		p.x += 0.07 * sin(u * PI)
		path.append(p)
	put(root, tube(path, 0.0022, 6), _mats["beige_dark"], Vector3.ZERO)


# --- the phones -------------------------------------------------------------------------------------------------------

## The phones, two rows of six (or as many as there are labels): each the phone's make ([PropMakes] `phone`) lying lid up, its
## name handed to its `tape` face, its `body` in a color of its own ([constant PHONE_TINT]); its lid opens as the medium feeds it
## (`open`). Each phone's node is posed by the medium from its place in the row ([member phones]' `home`).
func _phones() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = hash([_seed, "phones"])
	var n := _labels.size()
	# one make built, each phone a copy of it with its own materials ([method PropRig.copy])
	var made := _rig("phone") if n > 0 else null
	for i in n:
		var row := i / ROW
		var col := i % ROW
		var at := _phone_spot(col, row)
		var tint: Color = PHONE_COLORS[r.randi_range(0, PHONE_COLORS.size() - 1)]
		var polish := 1.0 - r.randf_range(0.3, 0.55)
		var rig := made if i == n - 1 else made.copy()
		var node := rig.node
		node.name = "Phone %s" % _labels[i]
		var home := Transform3D(Basis(Vector3.UP, deg_to_rad(r.randf_range(-6.0, 6.0))),
			Vector3(at.x + r.randf_range(-0.006, 0.006), DESK_Y, at.y + r.randf_range(-0.006, 0.006)))
		node.transform = home
		root.add_child(node)
		rig.say("tape", _labels[i])
		for mi in node.find_children("*", "MeshInstance3D", true, false):
			var mat := (mi as MeshInstance3D).material_override as ShaderMaterial
			if mat != null and String((mi as MeshInstance3D).get_meta("material", "")) == PHONE_TINT:
				mat.set_shader_parameter("color", tint)
				mat.set_shader_parameter("polish", polish)
		var pad := rig.face("keypad")
		if pad != null and _tex.has("keypad"):
			pad.material_override = _keypad_mat()
		phones.append({"label": _labels[i], "node": node, "rig": rig, "inner": rig.face("inner"), "outer": rig.face("outer"),
			"tape": rig.face("tape"), "home": home})
	# the rows stand as one, so nothing is packed or grows between them; each phone is seen
	var row_box := AABB()
	_faces["phones"] = []
	for i in phones.size():
		var node: Node3D = (phones[i] as Dictionary)["node"]
		var b := bounds(node)
		row_box = b if i == 0 else row_box.merge(b)
		if (phones[i] as Dictionary)["tape"] != null:
			(_faces["phones"] as Array).append((phones[i] as Dictionary)["tape"])
	if not phones.is_empty():
		bodies["phones"] = row_box
		var pts := PackedVector3Array()
		for ph in phones:
			var node: Node3D = (ph as Dictionary)["node"]
			pts.append_array(_gather(node, node.transform))
		_parts["phones"] = [_part_of(pts)]
		var blocks: Array = []
		for ph in phones:
			var node: Node3D = (ph as Dictionary)["node"]
			_mesh_boxes(node, node.transform, blocks)
		_blocks["phones"] = blocks


## Where the phone in column [param col], row [param row] lies (x, z): the rows run from the desk's end in toward the middle.
func _phone_spot(col: int, row: int) -> Vector2:
	var o := at_of("phones")
	return Vector2(o.x + flip * float(col) * PHONE_STEP.x, o.y + float(row) * PHONE_STEP.y)


## A phone's keypad: the face [DispatchScreens] draws once ([constant DispatchScreens.KEYPAD_SIZE]: Send, End, the twelve
## keys), lit a little as a phone's keys are.
func _keypad_mat() -> Material:
	if _mats.has("keypad"):
		return _mats["keypad"]
	var m := StandardMaterial3D.new()
	m.roughness = 0.5
	if _tex.has("keypad"):
		m.albedo_texture = _tex["keypad"]
		m.emission_enabled = true
		m.emission_texture = _tex["keypad"]
		m.emission = Color(0.18, 0.22, 0.18)
	else:
		m.albedo_color = Color(0.4, 0.42, 0.44)
	_mats["keypad"] = m
	return m


# --- the radar --------------------------------------------------------------------------------------------------------

## The radar's make ([PropMakes] `radar`) where the desk keeps it, turned to the chair: its glass ([member radar_screen]) the
## medium's, its gain knob turned as the medium feeds it (`gain`), and the scale printed round the knob on its `scale` face.
func _radar() -> void:
	var t := _place("radar", desk_at("radar"), turn["radar"])
	radar_screen = t.face("scope")
	var sf := t.face("scale")
	if sf != null and _tex.has("gain"):
		var scale := StandardMaterial3D.new()
		scale.albedo_texture = _tex["gain"]
		scale.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		scale.roughness = 0.8
		sf.material_override = scale
	_body("radar", t.node)
	_faces["radar"] = _read("radar")


## How far the radar's own gain knob is turned at [param level] (radians, counterclockwise as the chair sees it, its pointer
## straight up at 0): one at the lower left, round over the top, ten at the lower right - where the scale round it is printed.
static func gain_angle(level: float) -> float:
	var u := (level - float(DispatchScript.GAIN_LEAST)) / float(DispatchScript.GAIN_MOST - DispatchScript.GAIN_LEAST)
	return deg_to_rad(GAIN_SWING * (0.5 - u))


# --- the receiver -----------------------------------------------------------------------------------------------------

## The receiver's make ([PropMakes] `receiver`): its `dial` face printed with the frequency ([DispatchScreens]' dial, lit from
## behind), its needle swinging as the medium feeds it (`signal`), its oscilloscope's trace ([member scope_screen]) the medium's;
## and two wires run up from its `antenna` points into the dark.
func _receiver() -> void:
	var t := _place("receiver", desk_at("receiver"), turn["receiver"])
	dial = t.face("dial")
	if dial != null and _tex.has("dial"):
		var dmat := StandardMaterial3D.new()
		dmat.albedo_texture = _tex["dial"]
		dmat.emission_enabled = true
		dmat.emission_texture = _tex["dial"]
		dmat.emission = Color(1.0, 0.85, 0.55)
		dmat.emission_energy_multiplier = 0.55
		dial.material_override = dmat
	scope_screen = t.face("scope")
	for k in 2:
		var named: Variant = t.point("antenna %d" % (k + 1))
		var a0: Vector3 = named if named is Vector3 else Vector3(-0.1 + float(k) * 0.08, 0.105, -0.12)
		var p := PackedVector3Array()
		for i in 40:
			var u := float(i) / 39.0
			p.append(a0 + Vector3(0.05 * sin(u * 3.0 + float(k)), u * (CEILING - DESK_Y - 0.2), -u * 0.5 - 0.06 * sin(u * PI)))
		put(t.node, tube(p, 0.0018, 5), _mats["cable"], Vector3.ZERO)
	_body("receiver", t.node)
	_faces["receiver"] = _read("receiver")


# --- the printer ------------------------------------------------------------------------------------------------------

## The printer's make ([PropMakes] `printer`) at the desk's left end, turned so its paper comes up out of its `slot` toward the
## end and falls off it; its head runs across as the medium feeds it (`head`). The continuous paper with its sprocket holes
## ([member paper], the medium's texture) folds down over the desk's end into a knee-high heap of fanfold on the floor ([member
## heap]).
func _printer() -> void:
	var t := _place("printer", desk_at("printer"), turn["printer"])
	# The paper: up out of the slot, leaning back, then over and down the desk's end (in the printer's own frame its back is
	# -z, which faces the desk's end)
	paper = MeshInstance3D.new()
	paper.name = "Paper"
	paper.mesh = _paper_strip()
	var slot: Variant = t.point("slot")
	paper.position = slot if slot is Vector3 else Vector3(0, 0.125, -0.06)
	t.node.add_child(paper)
	heap = Node3D.new()
	heap.name = "Heap"
	heap.position = Vector3(at_of("heap").x, 0.0, at_of("heap").y)
	root.add_child(heap)
	var r := RandomNumberGenerator.new()
	r.seed = hash([_seed, "heap"])
	var layers := int(HEAP_H / 0.012)
	for k in layers:
		var y := float(k) * 0.012
		var m := put(heap, box(Vector3(SHEET.x, 0.012, SHEET.y)), _mats["paper"], Vector3(r.randf_range(-0.015, 0.015), y + 0.006, r.randf_range(-0.012, 0.012)),
			Vector3(0, 90 + r.randf_range(-4.0, 4.0), 0))
		m.name = "Layer %d" % k
	heap_top = put(heap, box(Vector3(SHEET.x, 0.012, SHEET.y)), _mats["paper"], Vector3(0, HEAP_H + 0.006, 0), Vector3(0, 90, 0))
	_body("printer", t.node)
	# what no root grows through ([DispatchRoots]): the paper over the desk, the paper falling past its end, and the heap
	var over := PackedVector3Array()
	var past := PackedVector3Array()
	for q in _gather(paper, bounds_xf(paper)):
		if absf(q.x) <= DESK_W * 0.5:
			over.append(q)
		else:
			past.append(q)
	for pts in [over, past]:
		if not (pts as PackedVector3Array).is_empty():
			var b := AABB((pts as PackedVector3Array)[0], Vector3.ZERO)
			for q in (pts as PackedVector3Array):
				b = b.expand(q)
			clear.append(b)
	clear.append(bounds(heap))


## The paper's strip, in the printer's frame from the slot: up and leaning back, then over the desk's end and down to the
## heap - a mesh whose UV runs along it (0 at the slot) so its printed lines move along it as it feeds.
func _paper_strip() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var path := PackedVector3Array()
	var drop := DESK_Y + 0.12 - HEAP_H
	for i in 40:
		var u := float(i) / 39.0
		var p: Vector3
		if u < 0.35:
			var v := u / 0.35
			p = Vector3(0, v * 0.17, -v * 0.07)
		elif u < 0.55:
			var v := (u - 0.35) / 0.2
			var a := v * PI * 0.5
			p = Vector3(0, 0.17 + sin(a) * 0.05, -0.07 - (1.0 - cos(a)) * 0.05 - v * 0.28)
		else:
			var v := (u - 0.55) / 0.45
			var to := -absf(at_of("printer").x - at_of("heap").x)
			p = Vector3(0, 0.22 - v * (drop + 0.22), lerpf(-0.40, to, v) - sin(v * PI) * 0.05)
		path.append(p)
	var len := 0.0
	var lens := PackedFloat32Array([0.0])
	for i in range(1, path.size()):
		len += path[i].distance_to(path[i - 1])
		lens.append(len)
	var hw := SHEET.x * 0.5
	for i in path.size() - 1:
		var a := path[i]
		var b := path[i + 1]
		var ua := lens[i] / len
		var ub := lens[i + 1] / len
		var t := (b - a).normalized()
		var nrm := t.cross(Vector3.RIGHT).normalized()
		for q in [[a, -hw, ua], [b, -hw, ub], [b, hw, ub], [a, -hw, ua], [b, hw, ub], [a, hw, ua]]:
			st.set_normal(nrm)
			st.set_uv(Vector2(0.5 + float(q[1]) / SHEET.x, float(q[2])))
			st.add_vertex((q[0] as Vector3) + Vector3(float(q[1]), 0, 0))
	return st.commit()


# --- the small screens ------------------------------------------------------------------------------------------------

## The three screens along the desk's back, each a make ([PropMakes] `feed`, `tv` on its `tv_stand`, `satellite`) whose `screen`
## the medium hands its picture, its glow on the desk fed (`glow`): the security monitor, the little television up on its stand so
## the chair sees it over the radar, and the satellite's flat monitor on its arm ([method _satellite]).
func _monitors() -> void:
	var f := _place("feed", desk_at("feed"), turn["feed"])
	screens["feed"] = {"mesh": f.face("screen"), "rig": f, "node": f.node}
	_body("feed", f.node)
	_faces["feed"] = _read("feed")
	# the little television, up on its stand so the chair sees it over the radar: the set stands as one thing
	var stand := _place("tv_stand", desk_at("tv"), turn["tv"])
	var tv := _rig("tv")
	tv.node.position = Vector3(0.0, (stand.built.get("size", AABB()) as AABB).end.y, 0.0)
	stand.node.add_child(tv.node)
	rigs["tv"] = tv
	screens["tv"] = {"mesh": tv.face("screen"), "rig": tv, "node": tv.node}
	_body("tv", stand.node)
	_faces["tv"] = _read("tv")
	_satellite()


## The satellite's flat monitor on an arm, low over the printer and the security monitor at the phones' end of the desk: its
## clamp on the desk's back edge where it is free nearest behind the panel, a short post, two segments bent up at the elbow
## and a head holding the panel, turned to the chair. Of the places it may hold it ([constant ARM_X], [constant ARM_Z],
## [constant ARM_H]) it takes the one where most of its glass is seen - from the chair and from its own close-up - hiding
## none of the faces round it, clamp, arm and panel clear of everything standing and the arm short ([method _arm_misfit]).
func _satellite() -> void:
	var panel := _rig("satellite")
	var pb: AABB = panel.built.get("size", AABB())
	if pb.has_volume():
		_sat_panel = pb.size
	if panel.face("screen") != null:
		_sat_glass = panel.face_size("screen")
	var side := -flip
	var r := RandomNumberGenerator.new()
	r.seed = hash([_seed, "satellite arm"])
	var sights := _sights()
	var free: Array = []
	var cx := 0.12
	while cx < DESK_W * 0.5 - 0.04:
		var at_edge := Vector2(side * cx, FAR + 0.04)
		if not _clamp_in(at_edge):
			free.append(at_edge)
		cx += ARM_CLAMP_STEP
	var best := INF
	var best_xf := Transform3D()
	var best_clamp := Vector2(side * 0.3, FAR + 0.04)
	for x in ARM_X:
		for z in ARM_Z:
			for h in ARM_H:
				var c := Vector3(side * float(x), DESK_Y + float(h), float(z))
				var b := Basis.looking_at(c - EYE, Vector3.UP).rotated(Vector3.UP, deg_to_rad(r.randf_range(-JITTER_TURN, JITTER_TURN)))
				var xf := Transform3D(b, c)
				var head := xf * Vector3(0, 0, -_sat_panel.z * 0.5 - 0.05)
				var clamp := best_clamp
				var near := INF
				for f in free:
					var dd := (f as Vector2).distance_to(Vector2(head.x, head.z))
					if dd < near:
						near = dd
						clamp = f
				var bad := _arm_misfit(xf, clamp, sights, best) + r.randf() * 0.01
				if bad < best:
					best = bad
					best_xf = xf
					best_clamp = clamp
	at["satellite"] = best_clamp
	var s := Node3D.new()
	s.name = "Satellite"
	root.add_child(s)
	# the panel's make held by its middle where the arm holds it
	panel.node.transform = best_xf * Transform3D(Basis.IDENTITY, -(panel.built.get("size", AABB()) as AABB).get_center())
	s.add_child(panel.node)
	rigs["satellite"] = panel
	_arm(s, _arm_fold(best_xf, best_clamp), best_clamp, best_xf)
	screens["satellite"] = {"mesh": panel.face("screen"), "rig": panel, "node": panel.node}
	_body("satellite", s)
	_faces["satellite"] = _read("satellite")


## The arm under [param parent], its [param joints] ([method _arm_joints]) from its clamp at [param clamp] to the panel standing
## as [param xf]: the clamp gripping the desk's back edge (a block on its top, a jaw under it, a plate down its back), the
## post, a beam to the elbow with a gas spring under it, a lighter beam on to the head, and the head's knuckle and link into
## the plate behind the panel.
func _arm(parent: Node3D, joints: Array, clamp: Vector2, xf: Transform3D) -> void:
	var black: Material = _mats["black"]
	var metal: Material = _mats["metal"]
	var foot := _desk_pos(clamp)
	put(parent, box(Vector3(0.06, 0.03, 0.07)), black, foot + Vector3(0, 0.015, 0))
	put(parent, box(Vector3(0.06, 0.012, 0.07)), black, foot + Vector3(0, -0.051, 0))
	put(parent, box(Vector3(0.06, 0.07, 0.012)), black, Vector3(foot.x, DESK_Y - 0.018, FAR - 0.006))
	put(parent, cyl(0.008, 0.008, 0.03, 10), metal, foot + Vector3(0, -0.07, 0))
	if joints.is_empty():
		return
	var top: Vector3 = joints[0]
	var elbow: Vector3 = joints[1]
	var head: Vector3 = joints[2]
	put(parent, cyl(0.017, 0.017, top.y - DESK_Y - 0.03, 16), metal, Vector3(foot.x, (top.y + DESK_Y + 0.03) * 0.5, foot.z))
	put(parent, cyl(0.022, 0.022, 0.03, 16), black, top)
	_rod(parent, top, elbow, black, Vector2(0.034, 0.026))
	_rod(parent, top.lerp(elbow, 0.15) + Vector3(0, -0.02, 0), top.lerp(elbow, 0.8) + Vector3(0, -0.02, 0), metal, Vector2(0.01, 0.01))
	put(parent, cyl(0.022, 0.022, 0.045, 16), black, elbow)
	_rod(parent, elbow, head, black, Vector2(0.028, 0.022))
	put(parent, cyl(0.016, 0.016, 0.04, 12), black, head)
	_rod(parent, head, xf * Vector3(0, 0, -_sat_panel.z * 0.5 - 0.01), metal, Vector2(0.018, 0.018))


## Where the arm bends to hold a panel standing as [param xf] from its clamp at [param clamp]: the post's top (a little below
## the head), the elbow and the head behind the panel - or [] where it does not reach. Its segments are long enough that the
## elbow always bends: up over the line between them, as a monitor arm's does, leaning [param back] (away from the chair) or
## toward it.
func _arm_joints(xf: Transform3D, clamp: Vector2, back := true) -> Array:
	var head := xf * Vector3(0, 0, -_sat_panel.z * 0.5 - 0.05)
	var top := Vector3(clamp.x, head.y - ARM_DROP, clamp.y)
	var span := head - top
	var d := span.length()
	if d > ARM_LEN * 2.0 or d < 0.05:
		return []
	var len := maxf(ARM_LEN * 0.4, d * 0.62)
	var dir := span / d
	var up := (Vector3.UP - dir * dir.y).normalized()
	var across := Vector3(span.z, 0.0, -span.x).normalized()
	if (across.z > 0.0) == back:
		across = -across
	var bend := (up * 0.8 + across * 0.35).normalized()
	bend = (bend - dir * bend.dot(dir)).normalized()
	var elbow := (top + head) * 0.5 + bend * sqrt(maxf(len * len - d * d * 0.25, 0.0))
	return [top, elbow, head]


## The arm's [param joints] meeting anything standing or off the desk's top (where the roots hang): how many points along it
## do, a point every few centimeters.
func _arm_in(joints: Array) -> int:
	var n := 0
	for i in 2:
		var a: Vector3 = joints[i]
		var b: Vector3 = joints[i + 1]
		for k in 9:
			var p := a.lerp(b, float(k) / 8.0)
			if p.z < FAR or absf(p.x) > DESK_W * 0.5:
				n += 1
				continue
			var sq := PackedVector2Array([Vector2(p.x - 0.02, p.z - 0.02), Vector2(p.x + 0.02, p.z - 0.02), Vector2(p.x + 0.02, p.z + 0.02),
				Vector2(p.x - 0.02, p.z + 0.02)])
			for o in bodies:
				if (bodies[o] as AABB).grow(0.02).has_point(p) and _meets(sq, p.y - 0.02, p.y + 0.02, _parts[o]):
					n += 1
	return n


## Whether a clamp at [param clamp] (and its post) meets anything standing.
func _clamp_in(clamp: Vector2) -> bool:
	var sq := PackedVector2Array([clamp + Vector2(-0.03 - PACK_MARGIN, -0.04), clamp + Vector2(0.03 + PACK_MARGIN, -0.04),
		clamp + Vector2(0.03 + PACK_MARGIN, 0.035 + PACK_MARGIN), clamp + Vector2(-0.03 - PACK_MARGIN, 0.035 + PACK_MARGIN)])
	for o in bodies:
		if _meets(sq, DESK_Y, DESK_Y + 0.5, _parts[o]):
			return true
	return false


## The arm's joints for a panel standing as [param xf]: the elbow folded back unless only the other way is clear ([method
## _arm_in]); [] where it does not reach.
func _arm_fold(xf: Transform3D, clamp: Vector2) -> Array:
	var back := _arm_joints(xf, clamp, true)
	if back.is_empty() or _arm_in(back) == 0:
		return back
	var front := _arm_joints(xf, clamp, false)
	return front if _arm_in(front) == 0 else back


## How badly the satellite's panel stands as [param xf] on its arm from [param clamp]: out of the arm's reach, or panel or
## arm in something standing, outweigh the share of its glass hidden - from the chair and from its close-up - or out of the
## chair's picture ([method in_frame]), what it hides of each face in [param sights] past what that face allows, and how
## far the arm reaches ([constant ARM_REACH_COST]). Past [param beat] it stops counting.
func _arm_misfit(xf: Transform3D, clamp: Vector2, sights: Array, beat := INF) -> float:
	var joints := _arm_fold(xf, clamp)
	if joints.is_empty():
		return 10000.0
	var bad := 0.0
	var panel := _block(AABB(-_sat_panel * 0.5, _sat_panel), xf)
	var corners := PackedVector3Array()
	var flat := PackedVector2Array()
	for i in 8:
		var w: Vector3 = xf * (panel["box"] as AABB).get_endpoint(i)
		corners.append(w)
		flat.append(Vector2(w.x, w.z))
	var lo := INF
	var hi := -INF
	for w in corners:
		lo = minf(lo, w.y)
		hi = maxf(hi, w.y)
	var grown := Geometry2D.offset_polygon(Geometry2D.convex_hull(flat), PACK_MARGIN)
	var room := (panel["world"] as AABB).grow(PACK_MARGIN)
	for o in bodies:
		if room.intersects(bodies[o]) and _meets(grown[0], lo - PACK_MARGIN, hi + PACK_MARGIN, _parts[o]):
			bad += 1000.0
	bad += 1000.0 * _arm_in(joints)
	# a short arm, low behind the panel
	bad += ((joints[2] as Vector3) - (joints[0] as Vector3)).length() * ARM_REACH_COST
	if bad >= beat:
		return bad
	var pts := PackedVector3Array()
	for i in 5:
		for j in 3:
			pts.append(xf * Vector3((0.2 * i - 0.4) * _sat_glass.x, (0.35 * j - 0.35) * _sat_glass.y, _sat_panel.z * 0.5 + 0.001))
	for eye in [EYE, _glass_eye(xf * Vector3(0, 0, _sat_panel.z * 0.5), xf.basis.z)]:
		var mine := _sight(pts, eye, "satellite")
		for o in bodies:
			bad += hidden(_blocks[o], mine)
	bad += 1.0 - in_frame(pts, spot_of("home"))
	for sg in sights:
		bad += maxf(hidden([panel], sg) - float(sg["most"]), 0.0)
	return bad


## The share of [param points] inside the picture a camera at [param spot] ([method spot_of]) takes, its lens [constant
## FRAME_ASPECT] wide for its height.
static func in_frame(points: PackedVector3Array, spot: Dictionary) -> float:
	var eye: Vector3 = spot["eye"]
	var f := ((spot["aim"] as Vector3) - eye).normalized()
	var right := f.cross(Vector3.UP).normalized()
	var up := right.cross(f)
	var t := tan(deg_to_rad(float(spot["fov"]) * 0.5))
	var n := 0
	for p in points:
		var v := p - eye
		var z := v.dot(f)
		if z > 0.0 and absf(v.dot(up)) <= t * z and absf(v.dot(right)) <= t * FRAME_ASPECT * z:
			n += 1
	return float(n) / maxf(float(points.size()), 1.0)


## A beam from [param a] to [param b] under [param parent], [param size] across and high: one of the arm's segments.
func _rod(parent: Node3D, a: Vector3, b: Vector3, mat: Material, size: Vector2) -> void:
	var len := a.distance_to(b)
	if len < 0.001:
		return
	var m := put(parent, rbox(Vector3(size.x, size.y, len), minf(size.x, size.y) * 0.3), mat, (a + b) * 0.5)
	m.basis = Basis.looking_at(b - a, Vector3.UP if absf((b - a).normalized().y) < 0.95 else Vector3.BACK)


## Where the camera leans to look at a screen whose glass is at [param c], facing [param nrm]: before it and a little above,
## never further from the chair than a lean takes it.
static func _glass_eye(c: Vector3, nrm: Vector3) -> Vector3:
	var e := c + nrm * 0.55 + Vector3(0, 0.06, 0) + (EYE - c).normalized() * 0.05
	return EYE + (e - EYE).limit_length(0.42)


# --- the switch, and the things ---------------------------------------------------------------------------------------

## The things at the desk's back, standing before the small things are packed round them: the lamp's make ([PropMakes] `lamp`)
## on the phones' side, its `base` where the desk keeps it and its neck bowing over toward the keyboard (mirrored on a desk drawn
## the other way round, its light ([member lamp]) aimed as it was made), lit as the medium feeds it (`lit`); and the patch panel
## with its blue and yellow cables.
func _things_back() -> void:
	var lp := at_of("lamp")
	var lt := _rig("lamp")
	var mirror := Basis.from_scale(Vector3(flip, 1.0, 1.0))
	var basis := Basis(Vector3.UP, deg_to_rad(turn["lamp"])) * mirror
	var base: Variant = lt.point("base")
	lt.node.transform = Transform3D(basis, _desk_pos(lp) - basis * (base as Vector3 if base is Vector3 else Vector3.ZERO))
	root.add_child(lt.node)
	rigs["lamp"] = lt
	lamp = lt.light("lamp")
	# a light under a mirrored node is set square in the set, aimed where the mirrored make aims it
	if flip < 0.0:
		for l in lt.lights():
			var ln := l as Light3D
			var w := bounds_xf(ln)
			var aim := (w.basis * Vector3.FORWARD).normalized()
			ln.get_parent().remove_child(ln)
			root.add_child(ln)
			ln.transform = Transform3D(Basis.looking_at(aim, Vector3.UP if absf(aim.dot(Vector3.UP)) < 0.98 else Vector3.BACK), w.origin)
	_body("lamp", lt.node)
	var pa := at_of("patch")
	var pp := _desk_pos(pa)
	var panel := put(root, box(Vector3(0.44, 0.045, 0.05)), _mats["black"], pp + Vector3(0, 0.0225, 0))
	var r := RandomNumberGenerator.new()
	r.seed = hash([_seed, "patch"])
	for k in 12:
		var a := pp + Vector3(-0.19 + float(k) * 0.034, 0.03, 0.026)
		var b := Vector3(r.randf_range(-0.55, 0.65) * flip, DESK_Y + 0.004, r.randf_range(-0.55, -0.44))
		if k % 3 == 0:
			b = Vector3(r.randf_range(-0.2, 0.3) * flip, DESK_Y + 0.004, FAR - 0.02)
		var mat: Material = _mats["cable_blue"] if k % 2 == 0 else _mats["cable_yellow"]
		put(root, tube(sag_path(a, b, -0.02, DESK_Y + 0.003, 18), 0.0024, 6), mat, Vector3.ZERO)
	_body("patch", panel)


## The small things, each a make ([PropMakes]) built at the origin and then packed ([method _pack]): the handbook, the mug
## ([member mug], the medium's to lift), the switch (thrown as the medium feeds it, `side`), a pencil cup, a rubber stamp and its
## pad, the GPS tracker blinking by itself, the chart taped down (its `chart` face printed with the council's hours); the tablet
## and the flip clock where the script uses them. Then what lies by them: a ring of dried coffee beside the mug's foot ([method
## _coffee_ring]) and the switch's wire back into the terminal.
func _things() -> void:
	var made := {}
	for k in ["handbook", "switch", "stamp", "tracker", "chart"]:
		var rig := _rig(k)
		rigs[k] = rig
		made[k] = rig.node
		_faces[k] = _read(k)
	var cf: MeshInstance3D = (rigs["chart"] as PropRig).face("chart")
	if cf != null and _tex.has("chart"):
		var cm := StandardMaterial3D.new()
		cm.albedo_texture = _tex["chart"]
		cm.roughness = 0.9
		cf.material_override = cm
	mug = Node3D.new()
	mug.name = "Mug"
	var mr := _rig("mug")
	rigs["mug"] = mr
	mug.add_child(mr.node)
	var mug_rad := maxf((mr.built["size"] as AABB).size.z * 0.5, 0.01) if mr.built.get("size") is AABB else 0.04
	made["mug"] = mug
	_faces["mug"] = [mug]
	var cup := _rig("pencil_cup")
	rigs["pencil_cup"] = cup
	cup.node.name = "PencilCup"
	made["cup"] = cup.node
	if _wants.has("tablet"):
		var tb := _rig("tablet")
		rigs["tablet"] = tb
		tablet = tb.node
		tablet_screen = tb.face("screen")
		made["tablet"] = tablet
	if _wants.has("clock"):
		var cl := _rig("clock")
		rigs["clock"] = cl
		clock_face = cl.face("cards")
		if clock_face != null:
			clock_face.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		made["clock"] = cl.node
		_faces["clock"] = _read("clock")
	_pack(made)
	# a spare thing left off a desk with no room for it plays nothing
	if not at.has("cup"):
		rigs.erase("pencil_cup")
	for k in ["handbook", "switch", "stamp", "tracker", "chart"]:
		if not at.has(k):
			rigs.erase(k)
	mug_home = mug.transform
	if tablet != null:
		tablet_home = tablet.transform
	# the ring of dried coffee: a thin, uneven, dull ring where a mug's foot dried on the lacquer, and an older arc beside
	# it - opaque and matte, lit and shadowed as the desk is (a translucent disc catches none of the lamp's light and
	# reads as glass) - a little off the mug's foot, so it shows beside it
	var mp := at_of("mug")
	var off := Vector2.from_angle(float(hash([_seed, "ring"]) % 628) / 100.0) * 0.014
	var ring := MeshInstance3D.new()
	ring.name = "CoffeeRing"
	ring.mesh = _coffee_ring(hash([_seed, "ring shape"]))
	ring.material_override = _std(Color(0.30, 0.20, 0.13), 0.95)
	ring.position = _desk_pos(mp + off, 0.0004)
	ring.scale = Vector3.ONE * (mug_rad / 0.0375)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(ring)
	var sw := at_of("switch")
	var side := "wire right" if sw.x > 0.0 else "wire left"
	var from := _point("switch", "wire", Vector3(sw.x - 0.02 * signf(sw.x), DESK_Y + 0.02, sw.y - 0.03))
	var into := _point("terminal", side, Vector3(CASE_AT.x + 0.18 * signf(sw.x), DESK_Y + 0.05, CASE_AT.y - CASE.z * 0.5 + 0.02))
	put(root, tube(sag_path(from, into, 0.06, DESK_Y + 0.003, 30), 0.0025), _mats["cable"], Vector3.ZERO)


## The old coffee ring's shape, flat on the desk: a thin rim round where a mug stood - wider and narrower by turns, a gap
## where it dried away - and the arc of an older one a little off it, from [param seed].
static func _coffee_ring(seed: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	var r := RandomNumberGenerator.new()
	r.seed = seed
	var gap_at := r.randf() * TAU
	var arcs := [[Vector2.ZERO, 0.0375, 0.0, TAU, 1.0], [Vector2(r.randf_range(-0.014, 0.014), r.randf_range(-0.014, 0.014)), 0.0365,
		r.randf() * TAU, r.randf_range(1.6, 2.6), 0.6]]
	var ph := r.randf() * TAU
	for arc in arcs:
		var c: Vector2 = arc[0]
		var rad := float(arc[1])
		var a0 := float(arc[2])
		var span := float(arc[3])
		var weight := float(arc[4])
		var n := int(96.0 * span / TAU)
		for i in n:
			var t0 := a0 + span * float(i) / float(n)
			var t1 := a0 + span * float(i + 1) / float(n)
			var gone := false
			if weight >= 1.0:
				gone = absf(angle_difference(t0, gap_at)) < 0.25
			if gone:
				continue
			var w0 := _rim_width(t0, ph, weight)
			var w1 := _rim_width(t1, ph, weight)
			var ri0 := rad + 0.0012 * sin(t0 * 3.0 + ph)
			var ri1 := rad + 0.0012 * sin(t1 * 3.0 + ph)
			var p := [Vector2.from_angle(t0) * ri0 + c, Vector2.from_angle(t0) * (ri0 + w0) + c,
				Vector2.from_angle(t1) * ri1 + c, Vector2.from_angle(t1) * (ri1 + w1) + c]
			# wound clockwise from above (Godot's front)
			for k in [0, 2, 1, 1, 2, 3]:
				var q: Vector2 = p[k]
				st.add_vertex(Vector3(q.x, 0.0, q.y))
	return st.commit()


## How wide the rim is at angle [param t] (m): thin, swelling and thinning round the ring, an older one thinner.
static func _rim_width(t: float, ph: float, weight: float) -> float:
	var w := 0.0022 + 0.0016 * (0.5 + 0.5 * sin(t * 2.0 + ph * 0.7)) + 0.0006 * sin(t * 7.0 + ph)
	if weight < 1.0:
		w *= weight * (0.5 + 0.5 * sin(t * 1.3 + ph))
	return maxf(w, 0.0004)


## The chair the viewer sits in: an empty office chair, seen only from behind it (the live picture on the television).
func _chair() -> void:
	chair = Node3D.new()
	chair.name = "Chair"
	chair.position = Vector3(EYE.x, 0.0, EYE.z + 0.08)
	root.add_child(chair)
	var fab: Material = _mats["fabric"]
	put(chair, rbox(Vector3(0.50, 0.08, 0.48), 0.03), fab, Vector3(0, 0.47, 0))
	put(chair, rbox(Vector3(0.48, 0.55, 0.07), 0.03), fab, Vector3(0, 0.82, 0.25), Vector3(-8, 0, 0))
	put(chair, cyl(0.025, 0.025, 0.36, 12), _mats["metal"], Vector3(0, 0.25, 0))
	for k in 5:
		var a := TAU * float(k) / 5.0
		put(chair, box(Vector3(0.03, 0.03, 0.30)), _mats["dark"], Vector3(sin(a) * 0.15, 0.06, cos(a) * 0.15), Vector3(0, rad_to_deg(a), 0))
	for side in [-1.0, 1.0]:
		put(chair, box(Vector3(0.04, 0.03, 0.30)), _mats["dark"], Vector3(side * 0.26, 0.66, 0.02))
		put(chair, box(Vector3(0.025, 0.18, 0.025)), _mats["dark"], Vector3(side * 0.26, 0.56, 0.06))


# --- the tablet held --------------------------------------------------------------------------------------------------

## The tablet held to be read: low over the desk's near edge ([constant TABLET_HELD]), its screen tipped toward the chair
## ([constant TABLET_TILT]).
func tablet_held_xf() -> Transform3D:
	return Transform3D(Basis(Vector3.RIGHT, deg_to_rad(TABLET_TILT)), Vector3(TABLET_HELD.x, DESK_Y + TABLET_HELD.y, TABLET_HELD.z))


# --- where the camera looks -------------------------------------------------------------------------------------------

## The spot the camera turns to for [param k] ([constant DispatchMedium.SPOTS]; {} where this desk has none): what it aims
## at, where the eye is (the chair's, leaned toward it), and how wide the lens is (degrees, vertical). Read from where
## things stand now, so the packer asks it of a place it tries ([method _misfit]).
func spot_of(k: String) -> Dictionary:
	var y := DESK_Y
	match k:
		"home":
			return {"aim": Vector3(0.0, y + 0.17, -0.16), "eye": EYE, "fov": 54.0}
		"terminal":
			# square on its glass, wherever its make has it
			var glass := bounds_xf(terminal_screen).origin if terminal_screen != null else Vector3(0.0, y + 0.35, CASE_AT.y + 0.18)
			return {"aim": glass, "eye": Vector3(glass.x, glass.y + 0.07, 0.44), "fov": 33.0}
		"keyboard":
			return {"aim": Vector3(0.0, y + 0.03, KEYBOARD_AT.y), "eye": EYE + Vector3(0, -0.05, -0.15), "fov": 36.0}
		"phones":
			var ph := (_phone_spot(0, 0) + _phone_spot(ROW - 1, 1)) * 0.5
			return {"aim": Vector3(ph.x + 0.0, y + 0.01, 0.0), "eye": EYE + Vector3(-0.30 * flip, -0.02, -0.12), "fov": 38.0}
		"radar":
			# a little under its glass, wherever its make has it: the scope and the knobs under it, the gain's scale whole
			var ra := at_of("radar")
			var scope := bounds_xf(radar_screen).origin if radar_screen != null else Vector3(ra.x - 0.02 * flip, y + 0.18, ra.y + 0.13)
			return {"aim": scope - Vector3(0.0, RADAR_LOOK_LOW, 0.0), "eye": EYE + Vector3(0.18 * flip, -0.04, -0.12), "fov": 34.0}
		"receiver":
			var rc := at_of("receiver")
			return {"aim": Vector3(rc.x - 0.02 * flip, y + 0.14, rc.y), "eye": EYE + Vector3(0.42 * flip, 0.02, -0.10), "fov": 30.0}
		"printer":
			var pr := at_of("printer")
			return {"aim": Vector3(pr.x - 0.29 * flip, y - 0.18, pr.y + 0.14), "eye": EYE + Vector3(-0.42 * flip, 0.06, -0.02), "fov": 54.0}
		"chart", "handbook", "switch", "mug":
			if not at.has(k):
				return {}
			var lean: Array = {"chart": [0.0, 0.03, -0.04, -0.18, 28.0], "handbook": [0.05, -0.08, -0.04, -0.12, 32.0],
				"switch": [0.04, 0.10, -0.06, -0.22, 24.0], "mug": [0.08, 0.10, -0.04, -0.12, 34.0]}[k]
			var p := at_of(k)
			var side := signf(p.x) if absf(p.x) > 0.05 else 1.0
			return {"aim": Vector3(p.x, y + float(lean[0]), p.y), "eye": EYE + Vector3(absf(float(lean[1])) * side, float(lean[2]), float(lean[3])),
				"fov": float(lean[4])}
		"clock":
			if clock_face == null:
				return {}
			# close on its cards from the chair's own line to it, so what the chair sees past, this sees past
			var c := bounds(clock_face).get_center()
			return {"aim": c, "eye": EYE.lerp(c, 0.6) + Vector3(0, 0.02, 0), "fov": 26.0}
		"tablet":
			if tablet == null:
				return {}
			# down into the tablet held low over the desk, its screen filling most of the picture
			var c := tablet_held_xf().origin
			return {"aim": c + Vector3(0, 0.01, 0), "eye": EYE + Vector3(0, -0.05, -0.08), "fov": 32.0}
		"feed", "satellite", "tv":
			if not screens.has(k) or (screens[k] as Dictionary)["mesh"] == null:
				return {}
			var xf := bounds_xf((screens[k] as Dictionary)["mesh"])
			return {"aim": xf.origin, "eye": _glass_eye(xf.origin, (xf.basis * Vector3.BACK).normalized()), "fov": 26.0}
	return {}


## Where phone [param i] is in its row (world).
func phone_home(i: int) -> Transform3D:
	return (phones[i] as Dictionary)["home"]


## Where a phone laid open on the desk lies, the [param k]th laid down: on the phones' side, in toward the middle one after
## another, its keypad toward the chair and its screen beyond - turned to face the chair, each a few degrees off the last
## ([constant HELD_FAN]) so they lie as a hand drops them.
func held_xf(k: int) -> Transform3D:
	var h := at_of("held")
	var spot := h + Vector2(flip * float(k) * HELD_STEP, 0.0)
	var toward := atan2(EYE.x - spot.x, EYE.z - spot.y)
	return Transform3D(Basis(Vector3.UP, toward + deg_to_rad((float(k) - 1.0) * HELD_FAN * flip)), Vector3(spot.x, DESK_Y, spot.y))
