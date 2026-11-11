extends RefCounted
class_name DispatchSet

## DispatchSet - THE DESK AND EVERYTHING ON IT, built (next/dispatch.md): one heavy dark desk with a worn green blotter
## in a hollow under the ground, seen from the chair - the terminal (a deep beige CRT on a flat desktop case with a floppy
## slot, a narrow keyboard on a coiled cable), the dozen flip phones in two rows with their names on masking tape, the
## round green radar scope, the shortwave receiver with its dial at 20.1, needle meter and speaker, a small oscilloscope on
## it and headphones hung on it, its two wires running up into the dark; the dot-matrix printer feeding its paper off the
## desk's end into a heap on the floor; the three small screens (a security monitor, a flat satellite monitor, a little
## television with rabbit ears); the switch box, GOOD above and BAD below; the chart taped down, the handbook, the mug in
## its ring, the gooseneck lamp, the patch panel and its cables, the GPS tracker; and the empty chair.
##
## BUILT BY CODE, every one ([DispatchMedium]'s note): each has a job in the script. In meters, the desk's top at
## [constant DESK_Y], its near edge (the chair's) at +z, x across from the chair. What moves is a node of its own,
## handed back in the members below for the medium to pose; what shows something is a quad the medium hands a texture.

## THE DESK: its top's height, its width and depth, where its near and far edges are.
const DESK_Y := 0.76
const DESK_W := 2.4
const DESK_D := 0.95
const NEAR := 0.40
const FAR := -0.55
## THE CHAIR: the seated eye (a little higher than a seated eye: the handoff's "from the chair, a little higher").
const EYE := Vector3(0.0, 1.24, 0.80)
## THE PHONES: closed, a phone's width, length and thickness (m); the rows - the first phone's middle, the step along a
## row and between the rows; where a phone laid open on the desk lies (the first, and the step).
const PHONE := Vector3(0.05, 0.022, 0.096)
const PHONE_AT := Vector2(-1.04, -0.08)
const PHONE_STEP := Vector2(0.105, 0.155)
const ROW := 6
const HELD_AT := Vector2(-0.94, 0.318)
const HELD_STEP := 0.135
## How many phones may lie open on the desk at once, side by side.
const HELD_SLOTS := 3
## The lid opens this far (degrees) about its hinge.
const LID_OPEN := 158.0
## THE TERMINAL: the case (w, h, d) and where it stands; the monitor's body and its screen's size (the glass, 4:3).
const CASE := Vector3(0.44, 0.115, 0.40)
const CASE_AT := Vector2(0.0, -0.24)
const CRT := Vector3(0.38, 0.35, 0.38)
const SCREEN := Vector2(0.29, 0.2175)
const KEYBOARD_AT := Vector2(0.0, 0.14)
## THE KEYS ([method _keys]): a unit's pitch (m, a little under the standard 19.05 mm - a narrow keyboard), the gap between
## two keys, how far a top is in from its foot, how deep its dish; each row's keys as [units, letter | modifier | gap];
## and each row's top height at its back and front (m) - the number row tallest and leaning most toward the typist.
const KEY_U := 0.0185
const KEY_GAP := 0.0012
const KEY_INSET := 0.0024
const KEY_DISH := 0.0007
const KEY_ROWS := [
	[[1.0, "letter"], [1.0, "letter"], [1.0, "letter"], [1.0, "letter"], [1.0, "letter"], [1.0, "letter"], [1.0, "letter"],
		[1.0, "letter"], [1.0, "letter"], [1.0, "letter"], [1.0, "letter"], [1.0, "letter"], [1.0, "letter"], [2.0, "modifier"]],
	[[1.5, "modifier"], [1.0, "letter"], [1.0, "letter"], [1.0, "letter"], [1.0, "letter"], [1.0, "letter"], [1.0, "letter"],
		[1.0, "letter"], [1.0, "letter"], [1.0, "letter"], [1.0, "letter"], [1.0, "letter"], [1.0, "letter"], [1.5, "letter"]],
	[[1.75, "modifier"], [1.0, "letter"], [1.0, "letter"], [1.0, "letter"], [1.0, "letter"], [1.0, "letter"], [1.0, "letter"],
		[1.0, "letter"], [1.0, "letter"], [1.0, "letter"], [1.0, "letter"], [1.0, "letter"], [2.25, "modifier"]],
	[[2.25, "modifier"], [1.0, "letter"], [1.0, "letter"], [1.0, "letter"], [1.0, "letter"], [1.0, "letter"], [1.0, "letter"],
		[1.0, "letter"], [1.0, "letter"], [1.0, "letter"], [1.0, "letter"], [2.75, "modifier"]],
	[[1.5, "modifier"], [1.0, "gap"], [1.5, "modifier"], [7.0, "letter"], [1.5, "modifier"], [1.0, "gap"], [1.5, "modifier"]],
]
const KEY_PROFILE := [Vector2(0.0118, 0.0098), Vector2(0.0104, 0.0092), Vector2(0.0094, 0.0090), Vector2(0.0090, 0.0094),
	Vector2(0.0090, 0.0096)]
## THE RADAR, THE RECEIVER, THE PRINTER, THE SCREENS, THE SWITCH, THE MUG: where each stands (x, z) on the desk.
const RADAR_AT := Vector2(0.50, 0.02)
const RADAR_R := 0.115
## THE RADAR'S GAIN KNOB: its radius at its base (m), the printed scale round it (a square this wide, [DispatchScreens]'s
## `gain` face), and how far its pointer turns from one to ten (degrees, over the top).
const GAIN_KNOB_R := 0.012
const GAIN_FACE := 0.044
const GAIN_SWING := 270.0
## THE LAMP lit.
const LAMP_ENERGY := 2.6
const RECEIVER_AT := Vector2(1.02, -0.33)
const PRINTER_AT := Vector2(-0.93, -0.36)
const FEED_AT := Vector2(-0.50, -0.40)
const SATELLITE_AT := Vector2(0.35, -0.42)
const TV_AT := Vector2(0.71, -0.44)
const LAMP_AT := Vector2(-0.33, -0.30)
## THE HEAP of printed paper on the floor beside the desk's left end, and how high it already is (knee-high).
const HEAP_AT := Vector2(-1.42, -0.30)
## How far each end of the desk's things may stand off its authored place (m, outward, and back or forward), and each big
## thing turn off its own (degrees), desk by desk.
const JITTER := 0.025
const JITTER_TURN := 5.0
## THE SMALL THINGS, packed in this order ([method _pack]): each its footprint (m), where it may go - `side` the radio's
## things', the phones', or either; `x` how far across from the middle, `z` how far back (+z the chair's edge) - where the
## authored desk had it (the radio's side +x), and `flat`: nothing stands on it, a root may cross it. THE MUG stays at arm's
## reach beside the keyboard, 25 to 40 cm in from the edge (the author: "nobody puts a mug that close to them").
const PACK := {
	"handbook": {"size": Vector2(0.30, 0.30), "side": "radio", "x": Vector2(0.72, 1.0), "z": Vector2(-0.02, 0.22), "home": Vector2(0.92, 0.18)},
	"mug": {"size": Vector2(0.11, 0.10), "side": "either", "x": Vector2(0.27, 0.62), "z": Vector2(-0.02, 0.15), "home": Vector2(-0.38, 0.06)},
	"switch": {"size": Vector2(0.11, 0.09), "side": "either", "x": Vector2(0.24, 0.44), "z": Vector2(0.12, 0.30), "home": Vector2(0.30, 0.26)},
	"cup": {"size": Vector2(0.08, 0.08), "side": "either", "x": Vector2(0.24, 0.40), "z": Vector2(-0.30, -0.06), "home": Vector2(-0.22, -0.20)},
	"stamp": {"size": Vector2(0.18, 0.08), "side": "either", "x": Vector2(0.05, 0.5), "z": Vector2(0.22, 0.33), "home": Vector2(-0.13, 0.33)},
	"tracker": {"size": Vector2(0.06, 0.05), "side": "either", "x": Vector2(0.2, 0.95), "z": Vector2(-0.12, 0.33), "home": Vector2(0.66, 0.30)},
	"chart": {"size": Vector2(0.22, 0.16), "side": "either", "x": Vector2(0.0, 0.45), "z": Vector2(0.24, 0.31), "home": Vector2(0.10, 0.31), "flat": true},
}
## Room left round each small thing (m).
const PACK_MARGIN := 0.02

const HEAP_H := 0.44
const SHEET := Vector2(0.38, 0.28)
## THE ROOM: the hollow's floor, ceiling and walls.
const CEILING := 3.4
const ROOM := Vector3(3.2, 0.0, 2.6)

## THE ROOT OF EVERYTHING, and its parts the medium poses.
var root: Node3D
var phones: Array = []            # each {label, node, lid, inner, outer, tape, home: Transform3D}
var terminal_screen: MeshInstance3D
var terminal_glow: OmniLight3D
var radar_screen: MeshInstance3D
var radar_glow: OmniLight3D
var gain_knob: Node3D             # the radar's gain knob, turned about its axis ([method gain_angle])
var scope_screen: MeshInstance3D
var needle: Node3D
var dial: MeshInstance3D
var printer_head: Node3D
var paper: MeshInstance3D         # the sheet coming up out of the printer, printed
var heap: Node3D                  # the printed paper's heap on the floor
var heap_top: MeshInstance3D
var screens := {}                 # feed / satellite / tv -> {mesh, glow, center}
var lever: Node3D                 # the switch's toggle
var mug: Node3D
var mug_home := Transform3D()
var lamp: SpotLight3D
var tracker_led: MeshInstance3D
var chair: Node3D
var footprints: Array = []        # Rect2s of what stands on the desk (x, z), for the roots to go round - nothing flat
var spots := {}                   # what the camera can turn to ([constant DispatchMedium.SPOTS] keys) -> {aim, eye, fov}

## THE DESK'S LAYOUT, DRAWN FROM ITS NUMBER (2026-11-06, the author: "I feel like the "Dispatch Desk" card barely does
## anything, when we change the seed value ... Is there any way we could give this something like the journaling-mode
## desk's treatment, so that the props could be reorganized around the desk? I'm finding the placement of the mug
## particularly bad right now: nobody puts a mug that close to them"). [member flip]: which side the radio's things stand
## (the radar, the receiver, the television on its crate) and which the phones, the printer and its heap - the desk
## mirrored, each turn with it; each big thing a little off its place and turned ([method _lay_out]); and the small things
## packed where there is room ([method _pack], as the letter's desk packs its things, [DeskLook]): the mug at arm's reach
## beside the keyboard and never at the edge, the switch by the keyboard, the handbook, the chart taped near the edge, the
## pencil cup, the stamp, the tracker. Whatever a mark works and wherever the camera turns follows them ([method _spots]).
var flip := 1.0
var at := {}                      # a thing -> where it stands (x, z)
var turn := {}                    # a thing -> how it is turned (degrees about up)

var _labels: PackedStringArray
var _seed := 1
var _flat: Array = []             # what lies flat (the chart): nothing else is packed onto it
var _tex := {}
var _mats := {}


## Build the desk for [param labels] (the phones', in order) and [param seed], out of the tree (on a worker, as the table's
## is: nothing here may need the tree); [param tex] holds what [DispatchScreens] draws for it ([method DispatchScreens.textures]) -
## the phones' tape (an atlas, a cell a phone), the chart, the handbook's spine, the receiver's dial, the switch's words.
func build(labels: PackedStringArray, seed: int, tex: Dictionary) -> Node3D:
	_labels = labels
	_seed = seed
	_tex = tex
	var tape: Texture2D = tex["tape"]
	var chart: Texture2D = tex["chart"]
	var spine: Texture2D = tex["spine"]
	var dial_face: Texture2D = tex["dial"]
	root = Node3D.new()
	root.name = "DispatchSet"
	_lay_out()
	_materials()
	_room()
	_desk()
	_terminal()
	_phones(tape)
	_radar()
	_receiver(dial_face)
	_printer()
	_monitors()
	_things_back()
	_pack()
	_switch()
	_things(chart, spine)
	_chair()
	_spots()
	return root


# --- the layout -------------------------------------------------------------------------------------------------------

## THE BIG THINGS' PLACES for this desk ([member at], [member turn]): the authored desk's ([constant RADAR_AT] and the rest -
## the radio's things at the right), mirrored or not, each end a little off as one and each thing turned a little. The
## terminal and keyboard stand where they stand.
func _lay_out() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = hash([_seed, "layout"])
	flip = -1.0 if r.randf() < 0.5 else 1.0
	at = {"case": CASE_AT, "keyboard": KEYBOARD_AT}
	turn = {"case": 0.0, "keyboard": 0.0}
	var base := {"radar": [RADAR_AT, -14.0], "receiver": [RECEIVER_AT, -30.0], "printer": [PRINTER_AT, 90.0],
		"feed": [FEED_AT, 12.0], "satellite": [SATELLITE_AT, -6.0], "tv": [TV_AT, -18.0], "lamp": [LAMP_AT, 0.0],
		"phones": [PHONE_AT, 0.0], "held": [HELD_AT, 0.0], "heap": [HEAP_AT, 0.0], "patch": [Vector2(0.10, -0.50), 0.0]}
	# EACH END OF THE DESK MOVES AS ONE, outward and back or forward a little - what stands close together stays as close;
	# the screens along the back move only back and forth
	var groups := {"radio": ["radar", "receiver", "tv"], "phones": ["phones", "printer", "feed", "lamp", "held", "heap"],
		"back": ["satellite", "patch"]}
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
	# the printer feeds toward the desk's end it stands at
	turn["printer"] = 90.0 * flip


## Where [param k] stands on the desk (x, z).
func at_of(k: String) -> Vector2:
	return at.get(k, Vector2.ZERO)


## Where [param k] stands, in the world, on the desk's top.
func desk_at(k: String) -> Vector3:
	return _desk_pos(at_of(k))


## THE SMALL THINGS PACKED WHERE THERE IS ROOM: each in turn, the biggest first, tried at places drawn in its own region
## ([constant PACK]: which side - the radio's, the phones', either - how far across and how far back) until one is clear of
## everything standing (and a margin), of where a phone laid open lies, and of the chair's own reach in front of the
## keyboard; else where the authored desk had it. Turned at random a little, the handbook its spine to the chair.
func _pack() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = hash([_seed, "pack"])
	var held := held_rect()
	var reach := Rect2(-0.26, 0.26, 0.52, 0.2)
	for k in PACK:
		var row: Dictionary = PACK[k]
		var size: Vector2 = row["size"]
		var place := Vector2(float(row["home"].x) * flip, float(row["home"].y))
		for _try in 60:
			var side := String(row["side"])
			var sgn := flip if side == "radio" else (-flip if side == "phones" else (1.0 if r.randf() < 0.5 else -1.0))
			var xs: Vector2 = row["x"]
			var zs: Vector2 = row["z"]
			var cand := Vector2(sgn * r.randf_range(xs.x, xs.y), r.randf_range(zs.x, zs.y))
			var box := Rect2(cand - size * 0.5, size)
			if box.grow(PACK_MARGIN).intersects(held) or box.intersects(reach) and not bool(row.get("flat", false)):
				continue
			var clear := true
			for f in footprints + _flat:
				if box.grow(PACK_MARGIN).intersects(f as Rect2):
					clear = false
					break
			if clear and absf(cand.x) + size.x * 0.5 < DESK_W * 0.5 - 0.03 and cand.y + size.y * 0.5 < NEAR - 0.02:
				place = cand
				break
		at[k] = place
		turn[k] = r.randf_range(-12.0, 12.0)
		if k == "handbook":
			var to := Vector2(EYE.x, EYE.z) - place
			turn[k] = rad_to_deg(atan2(-to.y, -to.x)) + r.randf_range(-8.0, 8.0)
		if not bool(row.get("flat", false)):
			footprints.append(Rect2(place - size * 0.5, size))
		else:
			_flat.append(Rect2(place - size * 0.5, size))


## WHERE A PHONE LAID OPEN LIES (x, z): the whole of the first [constant HELD_SLOTS] laid open as they lie - the base and
## the lid opened out past its hinge, each turned as [method held_xf] lays it - and a centimeter round. (feedback 0038, "This
## phone is clipping through the root here": it had been a strip round the bases, and an open lid reaches 14 cm past one.)
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

func _materials() -> void:
	_mats["beige"] = _std(Color(0.78, 0.73, 0.62), 0.5)
	_mats["beige_dark"] = _std(Color(0.62, 0.58, 0.49), 0.6)
	_mats["key"] = _std(Color(0.80, 0.76, 0.67), 0.45)
	_mats["key_gray"] = _std(Color(0.52, 0.51, 0.49), 0.5)
	_mats["black"] = _std(Color(0.035, 0.035, 0.04), 0.4)
	_mats["dark"] = _std(Color(0.10, 0.10, 0.11), 0.5)
	_mats["gray"] = _std(Color(0.36, 0.37, 0.39), 0.45, 0.35)
	_mats["metal"] = _std(Color(0.55, 0.56, 0.58), 0.3, 0.85)
	_mats["olive"] = _std(Color(0.24, 0.26, 0.20), 0.55)
	_mats["wood_dark"] = _std(Color(0.12, 0.07, 0.045), 0.55)
	_mats["cable"] = _std(Color(0.08, 0.08, 0.085), 0.6)
	_mats["cable_blue"] = _std(Color(0.10, 0.28, 0.72), 0.45)
	_mats["cable_yellow"] = _std(Color(0.85, 0.70, 0.10), 0.45)
	_mats["paper"] = _std(Color(0.88, 0.87, 0.82), 0.9)
	_mats["tape"] = _std(Color(0.88, 0.82, 0.62), 0.85)
	_mats["led_green"] = _emit(Color(0.2, 1.0, 0.35), 3.0)
	_mats["led_red"] = _emit(Color(1.0, 0.18, 0.12), 2.0)
	_mats["fabric"] = _std(Color(0.10, 0.10, 0.11), 0.95)
	_mats["earth"] = _earth()


static func _std(c: Color, rough: float, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	return m


static func _emit(c: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energy
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

## A ROUNDED BOX [param size] (m) with its edges rounded [param r], its middle at its origin: a cube's faces cut in a grid
## and laid on the rounded box (the point's nearest on the box shrunk by r, pushed back out by r along the way to it),
## as [Props]' block is made.
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
	# the first and last fifth of the steps go round the edge, the rest across the flat
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


## A TUBE along [param path] (m), [param radius] round (or [param radii], one a point), [param sides] round: a cable, a
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
	return st.commit()


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


func _foot(at: Vector2, size: Vector2, turn := 0.0) -> void:
	var s := size.rotated(deg_to_rad(turn)).abs() if turn != 0.0 else size
	footprints.append(Rect2(at - s * 0.5, s))


# --- the room ---------------------------------------------------------------------------------------------------------

## THE HOLLOW: an earthen floor, ceiling and walls round the desk, mostly lost in the dark.
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

## THE DESK: its top built as the card table's is ([Tables]: dark boards, their grain and seams), a worn green blotter laid
## on it, and two pedestals under it.
func _desk() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = hash([_seed, "dispatch desk"])
	# AN OLD WORN TOP, ITS LACQUER DULLED (2026-11-06: at polish 0.45 the lamp laid a warm sheen over the whole top, and the
	# mug's shadow, left with the screens' cool sheen alone, read as a clear pale disc under it - "a transparent circle")
	var mat := {"kind": "wood", "color": "#2a1810", "color2": "#140a06", "polish": 0.22, "pattern": 0.6, "grain": 1.4, "wear": 0.4}
	var top := {"shape": "rect", "size": [DESK_W * 100.0, DESK_D * 100.0], "thickness": 4.5, "edge": "eased", "material": "the desk",
		"boards": {"width": 19.0, "turn": 0.0}}
	var mid := Vector2(0.0, (NEAR + FAR) * 0.5)
	# the blotter's place, from the reading's middle as the table measures it
	var blot := Vector2(0.0, 0.17)
	var lay := {"name": "the blotter", "what": "a worn green blotter", "outline": "rect", "size": [66.0, 44.0],
		"at": [(blot.x - mid.x - Tables.TOP_AT.x) * 100.0, (blot.y - mid.y - Tables.TOP_AT.y) * 100.0], "turn": -1.5,
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
		# its drawers' faces and pulls, toward the chair
		for k in 3:
			var y := 0.12 + float(k) * 0.21
			put(root, rbox(Vector3(0.44, 0.19, 0.012), 0.004), wood, Vector3(side * (DESK_W * 0.5 - 0.27), y + 0.05, NEAR - 0.035))
			put(root, cyl(0.006, 0.006, 0.07, 8), _mats["metal"], Vector3(side * (DESK_W * 0.5 - 0.27), y + 0.08, NEAR - 0.022), Vector3(0, 0, 90))
	# the modesty panel behind the kneehole
	put(root, box(Vector3(DESK_W - 1.0, DESK_Y - 0.25, 0.025)), wood, Vector3(0, DESK_Y * 0.5 + 0.1, FAR + 0.08))


# --- the terminal -----------------------------------------------------------------------------------------------------

## THE TERMINAL, the cover's: a flat beige desktop case with a floppy slot and a power button, the deep CRT on it - its
## bezel round the glass, its body tapering back, the little power lamp in the bezel's corner - and the narrow keyboard
## on its coiled cable. The glass ([member terminal_screen]) is the medium's to hand a texture.
func _terminal() -> void:
	var t := Node3D.new()
	t.name = "Terminal"
	t.position = _desk_pos(CASE_AT)
	root.add_child(t)
	var beige: Material = _mats["beige"]
	put(t, rbox(CASE, 0.012), beige, Vector3(0, CASE.y * 0.5, 0))
	var front := CASE.z * 0.5
	# the floppy slot, its eject button, and the power button
	put(t, rbox(Vector3(0.16, 0.026, 0.006), 0.003), _mats["beige_dark"], Vector3(-0.09, CASE.y * 0.52, front + 0.001))
	put(t, box(Vector3(0.13, 0.004, 0.004)), _mats["black"], Vector3(-0.095, CASE.y * 0.54, front + 0.004))
	put(t, rbox(Vector3(0.016, 0.008, 0.006), 0.002), _mats["beige_dark"], Vector3(-0.025, CASE.y * 0.42, front + 0.003))
	put(t, rbox(Vector3(0.03, 0.03, 0.01), 0.004), _mats["beige_dark"], Vector3(0.16, CASE.y * 0.5, front + 0.003))
	put(t, box(Vector3(0.006, 0.004, 0.003)), _mats["led_green"], Vector3(0.12, CASE.y * 0.5, front + 0.002))
	# a seam round the case's front
	put(t, box(Vector3(CASE.x - 0.02, 0.003, 0.003)), _mats["beige_dark"], Vector3(0, CASE.y * 0.18, front + 0.0005))
	# THE MONITOR on its swivel foot
	var mon := Node3D.new()
	mon.position = Vector3(0, CASE.y, -0.01)
	t.add_child(mon)
	put(mon, cyl(0.10, 0.12, 0.018, 28), beige, Vector3(0, 0.009, 0))
	put(mon, cyl(0.06, 0.07, 0.03, 20), beige, Vector3(0, 0.03, 0))
	var mid_y := 0.045 + CRT.y * 0.5
	# the bezel, a rounded slab, and the body tapering back behind it
	put(mon, rbox(Vector3(CRT.x, CRT.y, 0.07), 0.02), beige, Vector3(0, mid_y, CRT.z * 0.5 - 0.035))
	# a four-sided frustum on its side, narrow end back: turned a quarter about its own axis so its faces are square to
	# the bezel, then tipped back
	var body := put(mon, cyl(0.10, 0.215, 0.30, 4), beige, Vector3(0, mid_y, CRT.z * 0.5 - 0.07 - 0.15))
	body.basis = Basis(Vector3.RIGHT, -PI * 0.5) * Basis(Vector3.UP, PI * 0.25)
	# the glass, set into the bezel - its recess dark round it
	put(mon, rbox(Vector3(SCREEN.x + 0.03, SCREEN.y + 0.03, 0.01), 0.008), _mats["dark"], Vector3(0, mid_y + 0.012, CRT.z * 0.5 - 0.001))
	terminal_screen = put(mon, quad(SCREEN), null, Vector3(0, mid_y + 0.012, CRT.z * 0.5 + 0.0075))
	terminal_screen.name = "Screen"
	put(mon, cyl(0.004, 0.004, 0.004, 10), _mats["led_green"], Vector3(CRT.x * 0.5 - 0.035, mid_y - CRT.y * 0.5 + 0.022, CRT.z * 0.5 + 0.001), Vector3(90, 0, 0))
	put(mon, rbox(Vector3(0.018, 0.012, 0.006), 0.003), _mats["beige_dark"], Vector3(CRT.x * 0.5 - 0.06, mid_y - CRT.y * 0.5 + 0.022, CRT.z * 0.5 + 0.002))
	terminal_glow = OmniLight3D.new()
	terminal_glow.light_color = Color(0.78, 1.0, 0.86)
	terminal_glow.light_energy = 0.0
	terminal_glow.omni_range = 1.6
	terminal_glow.omni_attenuation = 1.6
	terminal_glow.position = Vector3(0, mid_y, CRT.z * 0.5 + 0.18)
	mon.add_child(terminal_glow)
	_foot(CASE_AT, Vector2(CASE.x, CASE.z))
	# THE KEYBOARD: narrow and beige, a standard layout in sculpted keys ([method _keys]); its cable coiled back to the case
	var kb := Node3D.new()
	kb.name = "Keyboard"
	kb.position = _desk_pos(KEYBOARD_AT)
	kb.rotation_degrees = Vector3(0, 0.8, 0)
	root.add_child(kb)
	var kbs := Vector3(KEY_U * 15.0 + 0.026, 0.024, KEY_U * 5.0 + 0.042)
	var tilt := Node3D.new()
	tilt.rotation_degrees = Vector3(4.0, 0, 0)
	kb.add_child(tilt)
	put(tilt, rbox(kbs, 0.008), beige, Vector3(0, kbs.y * 0.5, 0))
	# the keys stand in a shallow well in the case's top, a little nearer its back edge
	put(tilt, box(Vector3(KEY_U * 15.0 + 0.004, 0.002, KEY_U * 5.0 + 0.004)), _mats["beige_dark"], Vector3(0, kbs.y - 0.0008, -0.004))
	var kmi := MeshInstance3D.new()
	kmi.name = "Keys"
	kmi.mesh = _keys()
	kmi.position = Vector3(0, kbs.y, -0.004)
	var kmat := StandardMaterial3D.new()
	kmat.vertex_color_use_as_albedo = true
	kmat.roughness = 0.5
	kmi.material_override = kmat
	tilt.add_child(kmi)
	_foot(KEYBOARD_AT, Vector2(kbs.x, kbs.z))
	# the coiled cable: from the keyboard's back, a coil on the desk, up into the case's front
	var path := PackedVector3Array()
	var a := Vector3(0.0, DESK_Y + 0.012, KEYBOARD_AT.y - kbs.z * 0.5)
	var b := Vector3(0.16, DESK_Y + 0.02, CASE_AT.y + CASE.z * 0.5)
	for i in 120:
		var u := float(i) / 119.0
		var p := a.lerp(b, u)
		var ang := u * TAU * 11.0
		var coil := 0.008 * sin(u * PI)
		p += Vector3(cos(ang) * coil, sin(ang) * coil + 0.008 * sin(u * PI), 0.0)
		p.x += 0.07 * sin(u * PI)
		path.append(p)
	put(root, tube(path, 0.0022, 6), _mats["beige_dark"], Vector3.ZERO)


## THE KEYBOARD'S KEYS, one mesh (they never move): a standard compact layout (2026-11-06, the author: "The keys are the
## wrong shape, they are layed-out in a nonstandard fashion ... Some of the keys at the top-right of the current keyboard
## are just floating there, detached completely") - five rows of fifteen units on the [constant KEY_U] pitch ([constant
## KEY_ROWS]: the number row and Backspace; Tab to the backslash; Caps Lock to Enter; the Shifts; Ctrl, Alt, the bar, Alt,
## Ctrl), each key a sculpted cap - its skirt tapering from its foot to a smaller dished top, the rows leaning toward the
## typist as a cylindrical profile does ([constant KEY_PROFILE]) - the letters beige and what is not a letter gray. In the
## keyboard's frame: x across, +z toward the typist, y up from the case's top.
static func _keys() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var letter := Color(0.82, 0.78, 0.69)
	var modifier := Color(0.56, 0.54, 0.51)
	for j in KEY_ROWS.size():
		var row: Array = KEY_ROWS[j]
		var x := -KEY_U * 7.5
		var z := (float(j) - 2.0) * KEY_U
		var prof: Vector2 = KEY_PROFILE[j]
		for key in row:
			var k: Array = key
			var w := float(k[0]) * KEY_U
			if String(k[1]) != "gap":
				_keycap(st, Vector3(x + w * 0.5, 0.0, z), w, prof, letter if String(k[1]) == "letter" else modifier)
			x += w
	st.generate_normals()
	return st.commit()


## ONE KEYCAP into [param st]: a foot [param w] wide and [constant KEY_U] deep (less the gap between keys), its top
## [constant KEY_INSET] in from it at each side and dished a little; [param prof] its top's height at the back and at the
## front (m) - the row's lean.
static func _keycap(st: SurfaceTool, at: Vector3, w: float, prof: Vector2, c: Color) -> void:
	var foot := _key_outline(w - KEY_GAP, KEY_U - KEY_GAP, 0.0015)
	var top := _key_outline(w - KEY_GAP - KEY_INSET * 2.0, KEY_U - KEY_GAP - KEY_INSET * 2.2, 0.002)
	var n := foot.size()
	var lo := PackedVector3Array()
	var hi := PackedVector3Array()
	for i in n:
		lo.append(at + Vector3(foot[i].x, 0.0, foot[i].y))
		# the top leans: higher at the back (-z) than the front, as the row's profile says
		var u := clampf((top[i].y / (KEY_U * 0.5)) * 0.5 + 0.5, 0.0, 1.0)
		hi.append(at + Vector3(top[i].x, lerpf(prof.x, prof.y, u), top[i].y - KEY_INSET * 0.15))
	st.set_color(c)
	for i in n:
		var i2 := (i + 1) % n
		var out := Vector3(lo[i].x + lo[i2].x - 2.0 * at.x, 0.0, lo[i].z + lo[i2].z - 2.0 * at.z)
		_tri(st, lo[i], lo[i2], hi[i2], out)
		_tri(st, lo[i], hi[i2], hi[i], out)
	# the top, dished: a fan round its middle, a little lower than its rim
	var mid := Vector3.ZERO
	for p in hi:
		mid += p
	mid = mid / float(n) - Vector3(0, KEY_DISH, 0)
	for i in n:
		_tri(st, mid, hi[i], hi[(i + 1) % n], Vector3.UP)


## A key's outline, a rectangle [param w] by [param d] with its corners cut [param cut]: eight points round it (x, z).
static func _key_outline(w: float, d: float, cut: float) -> PackedVector2Array:
	var hw := w * 0.5
	var hd := d * 0.5
	return PackedVector2Array([Vector2(-hw + cut, -hd), Vector2(hw - cut, -hd), Vector2(hw, -hd + cut), Vector2(hw, hd - cut),
		Vector2(hw - cut, hd), Vector2(-hw + cut, hd), Vector2(-hw, hd - cut), Vector2(-hw, -hd + cut)])


## A triangle into [param st] facing [param out] (Godot's front faces wind clockwise: the corners put in that order).
static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, out: Vector3) -> void:
	if (b - a).cross(c - a).dot(out) > 0.0:
		st.add_vertex(a)
		st.add_vertex(c)
		st.add_vertex(b)
	else:
		st.add_vertex(a)
		st.add_vertex(b)
		st.add_vertex(c)


# --- the phones -------------------------------------------------------------------------------------------------------

## THE PHONES, two rows of six (or as many as there are labels): each a flip phone lying lid up, a strip of masking tape
## across its lid with its name on it ([param tape], a cell a label), its lid a node of its own on its hinge with a screen
## inside it and a small one outside. Each phone's body is a node the medium poses from its place in the row ([member
## phones]' `home`).
func _phones(tape: Texture2D) -> void:
	var colors := [Color(0.08, 0.08, 0.09), Color(0.42, 0.43, 0.46), Color(0.07, 0.10, 0.18), Color(0.18, 0.18, 0.2), Color(0.30, 0.06, 0.06)]
	var r := RandomNumberGenerator.new()
	r.seed = hash([_seed, "phones"])
	var tape_mat := StandardMaterial3D.new()
	tape_mat.albedo_texture = tape
	tape_mat.roughness = 0.85
	var n := _labels.size()
	for i in n:
		var row := i / ROW
		var col := i % ROW
		var at := _phone_spot(col, row)
		var body_mat := _std(colors[r.randi_range(0, colors.size() - 1)], r.randf_range(0.3, 0.55), 0.15)
		var node := Node3D.new()
		node.name = "Phone %s" % _labels[i]
		var home := Transform3D(Basis(Vector3.UP, deg_to_rad(r.randf_range(-6.0, 6.0))),
			Vector3(at.x + r.randf_range(-0.006, 0.006), DESK_Y, at.y + r.randf_range(-0.006, 0.006)))
		node.transform = home
		root.add_child(node)
		# the base: the keypad half, its hinge at the far end (-z)
		var h := PHONE.y * 0.5
		var base := put(node, rbox(Vector3(PHONE.x, h, PHONE.z), 0.008, 4), body_mat, Vector3(0, h * 0.5, 0))
		base.name = "Base"
		# the keypad, seen only when open
		var pad := put(node, quad(Vector2(PHONE.x * 0.78, PHONE.z * 0.62)), _keypad_mat(), Vector3(0, h + 0.0004, 0.006), Vector3(-90, 0, 0))
		pad.name = "Keypad"
		# the lid on its hinge at the base's far end; closed it lies on the base, its screen face down
		var hinge := Node3D.new()
		hinge.name = "Hinge"
		hinge.position = Vector3(0, h, -PHONE.z * 0.5)
		node.add_child(hinge)
		var lid := put(hinge, rbox(Vector3(PHONE.x, h, PHONE.z), 0.008, 4), body_mat, Vector3(0, h * 0.5, PHONE.z * 0.5))
		lid.name = "Lid"
		# inside the lid (face down when shut): the main screen; outside: the little one, and the tape across it
		var inner := put(hinge, quad(Vector2(PHONE.x * 0.78, PHONE.z * 0.5)), null, Vector3(0, -0.0003, PHONE.z * 0.55), Vector3(90, 0, 0))
		inner.name = "Inner"
		var outer := put(hinge, quad(Vector2(PHONE.x * 0.5, PHONE.z * 0.2)), null, Vector3(0, h + 0.0004, PHONE.z * 0.78), Vector3(-90, 0, 0))
		outer.name = "Outer"
		var tq := quad(Vector2(PHONE.x * 1.06, PHONE.z * 0.3))
		var tmi := put(hinge, tq, tape_mat, Vector3(0, h + 0.0007, PHONE.z * 0.42), Vector3(-90, 0, r.randf_range(-4.0, 4.0)))
		tmi.name = "Tape"
		# the tape's cell of the atlas
		var cell := DispatchScreens.tape_cell(i, n)
		var tm := tape_mat.duplicate() as StandardMaterial3D
		tm.uv1_scale = Vector3(cell.size.x, cell.size.y, 1.0)
		tm.uv1_offset = Vector3(cell.position.x, cell.position.y, 0.0)
		tmi.material_override = tm
		# the antenna nub at the hinge
		put(hinge, cyl(0.0035, 0.004, 0.012, 8), body_mat, Vector3(PHONE.x * 0.32, h + 0.004, 0.004))
		phones.append({"label": _labels[i], "node": node, "hinge": hinge, "lid": lid, "inner": inner, "outer": outer,
			"tape": tmi, "home": home, "body": body_mat})
	_foot((_phone_spot(0, 0) + _phone_spot(ROW - 1, 1)) * 0.5, Vector2(PHONE_STEP.x * float(ROW) + 0.02, PHONE_STEP.y + PHONE.z + 0.03))


## Where the phone in column [param col], row [param row] lies (x, z): the rows run from the desk's end in toward the middle.
func _phone_spot(col: int, row: int) -> Vector2:
	var o := at_of("phones")
	return Vector2(o.x + flip * float(col) * PHONE_STEP.x, o.y + float(row) * PHONE_STEP.y)


## A PHONE'S KEYPAD: the face [DispatchScreens] draws once ([constant DispatchScreens.KEYPAD_SIZE]: Send, End, the twelve
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

## THE RADAR: a squat olive housing, its round scope tipped back toward the chair, a hood round the glass and two knobs
## under it - the left the gain ([member gain_knob], the medium's to turn), its white pointer at three and the scale one to
## ten printed round it. The glass ([member radar_screen]) is the medium's.
func _radar() -> void:
	var t := Node3D.new()
	t.name = "Radar"
	t.position = desk_at("radar")
	t.rotation_degrees = Vector3(0, turn["radar"], 0)
	root.add_child(t)
	var olive: Material = _mats["olive"]
	var body := Vector3(0.30, 0.24, 0.30)
	put(t, rbox(body, 0.015), olive, Vector3(0, body.y * 0.5, 0))
	var face := Node3D.new()
	face.position = Vector3(0, 0.14, body.z * 0.5 + 0.05)
	face.rotation_degrees = Vector3(-18.0, 0, 0)
	t.add_child(face)
	put(face, rbox(Vector3(0.28, 0.27, 0.04), 0.012), olive, Vector3(0, 0, 0.0))
	put(face, box(Vector3(0.24, 0.24, 0.1)), olive, Vector3(0, -0.02, -0.06))
	# the hood: a ring round the glass, standing out of the face
	var hood := TorusMesh.new()
	hood.inner_radius = RADAR_R - 0.001
	hood.outer_radius = RADAR_R + 0.011
	hood.rings = 48
	hood.ring_segments = 12
	put(face, hood, _mats["black"], Vector3(0, 0.01, 0.026), Vector3(90, 0, 0))
	radar_screen = put(face, quad(Vector2(RADAR_R * 2.0, RADAR_R * 2.0)), null, Vector3(0, 0.01, 0.0215))
	radar_screen.name = "Scope"
	put(face, cyl(GAIN_KNOB_R - 0.001, GAIN_KNOB_R, 0.02, 16), _mats["black"], Vector3(0.07, -0.118, 0.028), Vector3(90, 0, 0))
	gain_knob = Node3D.new()
	gain_knob.name = "Gain"
	gain_knob.position = Vector3(-0.07, -0.118, 0.028)
	gain_knob.rotation.z = gain_angle(DispatchScript.GAIN_REST)
	face.add_child(gain_knob)
	put(gain_knob, cyl(GAIN_KNOB_R - 0.001, GAIN_KNOB_R, 0.02, 16), _mats["black"], Vector3.ZERO, Vector3(90, 0, 0))
	put(gain_knob, box(Vector3(0.0016, 0.0085, 0.001)), _mats["paper"], Vector3(0, 0.0058, 0.0103))
	if _tex.has("gain"):
		var scale := StandardMaterial3D.new()
		scale.albedo_texture = _tex["gain"]
		scale.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		scale.roughness = 0.8
		put(face, quad(Vector2(GAIN_FACE, GAIN_FACE)), scale, Vector3(-0.07, -0.118, 0.0206))
	radar_glow = OmniLight3D.new()
	radar_glow.light_color = Color(0.55, 1.0, 0.62)
	radar_glow.light_energy = 0.06
	radar_glow.omni_range = 0.7
	radar_glow.position = Vector3(0, 0.14, 0.32)
	t.add_child(radar_glow)
	_foot(at_of("radar"), Vector2(0.32, 0.34))


## HOW FAR THE GAIN KNOB IS TURNED at [param level] (radians about its axis, counter-clockwise as the chair sees it, its
## pointer straight up at 0): one at the lower left, round over the top, ten at the lower right.
static func gain_angle(level: float) -> float:
	var u := (level - float(DispatchScript.GAIN_LEAST)) / float(DispatchScript.GAIN_MOST - DispatchScript.GAIN_LEAST)
	return deg_to_rad(GAIN_SWING * (0.5 - u))


# --- the receiver -----------------------------------------------------------------------------------------------------

## THE RECEIVER: a shortwave radio, gray and black - its big tuning dial ([param dial_face], 20.1 under the cursor), a
## needle meter (its needle, [member needle], the medium's), a speaker grille, knobs - a small oscilloscope on top of it
## (its trace, [member scope_screen]), a pair of headphones hung on its corner, and two wires running up from its back
## into the dark toward the roof.
func _receiver(dial_face: Texture2D) -> void:
	var t := Node3D.new()
	t.name = "Receiver"
	t.position = desk_at("receiver")
	t.rotation_degrees = Vector3(0, turn["receiver"], 0)
	root.add_child(t)
	var body := Vector3(0.34, 0.15, 0.24)
	put(t, rbox(body, 0.008), _mats["gray"], Vector3(0, body.y * 0.5, 0))
	var fz := body.z * 0.5 + 0.002
	put(t, box(Vector3(body.x - 0.012, body.y - 0.012, 0.004)), _mats["black"], Vector3(0, body.y * 0.5, fz))
	# the dial's window and its face
	var dmat := StandardMaterial3D.new()
	dmat.albedo_texture = dial_face
	dmat.emission_enabled = true
	dmat.emission_texture = dial_face
	dmat.emission = Color(1.0, 0.85, 0.55)
	dmat.emission_energy_multiplier = 0.55
	dial = put(t, quad(Vector2(0.16, 0.08)), dmat, Vector3(-0.07, body.y * 0.58, fz + 0.003))
	put(t, cyl(0.026, 0.028, 0.025, 24), _mats["dark"], Vector3(-0.07, body.y * 0.2, fz + 0.012), Vector3(90, 0, 0))
	# the needle meter
	var meter := put(t, quad(Vector2(0.07, 0.045)), _emit(Color(0.95, 0.88, 0.62), 0.5), Vector3(0.10, body.y * 0.68, fz + 0.003))
	meter.name = "Meter"
	needle = Node3D.new()
	needle.position = Vector3(0.10, body.y * 0.68 - 0.018, fz + 0.005)
	t.add_child(needle)
	put(needle, box(Vector3(0.0012, 0.036, 0.0008)), _mats["black"], Vector3(0, 0.018, 0))
	# the speaker grille: rows of slots
	for k in 6:
		put(t, box(Vector3(0.07, 0.003, 0.002)), _mats["dark"], Vector3(0.10, body.y * 0.42 - float(k) * 0.009, fz + 0.002))
	for k in 3:
		put(t, cyl(0.008, 0.009, 0.014, 14), _mats["metal"], Vector3(0.04 + float(k) * 0.035, body.y * 0.13, fz + 0.007), Vector3(90, 0, 0))
	# THE OSCILLOSCOPE on top of it
	var sc := Vector3(0.20, 0.13, 0.22)
	var scope := Node3D.new()
	scope.position = Vector3(-0.04, body.y, -0.005)
	t.add_child(scope)
	put(scope, rbox(sc, 0.01), _mats["beige_dark"], Vector3(0, sc.y * 0.5, 0))
	put(scope, box(Vector3(0.10, 0.08, 0.006)), _mats["black"], Vector3(-0.035, sc.y * 0.55, sc.z * 0.5 + 0.001))
	scope_screen = put(scope, quad(Vector2(0.088, 0.068)), null, Vector3(-0.035, sc.y * 0.55, sc.z * 0.5 + 0.0045))
	for k in 4:
		put(scope, cyl(0.007, 0.008, 0.012, 12), _mats["dark"], Vector3(0.05 + float(k % 2) * 0.03, sc.y * (0.7 - float(k / 2) * 0.35), sc.z * 0.5 + 0.006), Vector3(90, 0, 0))
	# THE HEADPHONES hung on the scope's corner: a band over it, the cups hanging either side
	var hp := Node3D.new()
	hp.position = Vector3(0.105, body.y + sc.y + 0.005, 0.03)
	hp.rotation_degrees = Vector3(0, 90, -8)
	t.add_child(hp)
	var band := PackedVector3Array()
	for i in 17:
		var a := PI * float(i) / 16.0
		band.append(Vector3(cos(a) * 0.075, sin(a) * 0.03 - 0.0, 0))
	put(hp, tube(band, 0.006, 8), _mats["dark"], Vector3(0, 0.0, 0))
	for side in [-1.0, 1.0]:
		put(hp, cyl(0.035, 0.035, 0.03, 20), _mats["dark"], Vector3(side * 0.075, -0.035, 0), Vector3(0, 0, 90))
	# the headphones' cord down to the receiver
	put(t, tube(sag_path(Vector3(0.18, body.y + sc.y - 0.06, 0.03), Vector3(0.16, body.y * 0.25, fz), 0.02, 0.0, 16), 0.002), _mats["cable"], Vector3.ZERO)
	# THE TWO WIRES up into the dark, from its back toward the roof
	for k in 2:
		var p := PackedVector3Array()
		var a0 := Vector3(-0.1 + float(k) * 0.08, body.y * 0.7, -body.z * 0.5)
		for i in 40:
			var u := float(i) / 39.0
			p.append(a0 + Vector3(0.05 * sin(u * 3.0 + float(k)), u * (CEILING - DESK_Y - 0.2), -u * 0.5 - 0.06 * sin(u * PI)))
		put(t, tube(p, 0.0018, 5), _mats["cable"], Vector3.ZERO)
	_foot(at_of("receiver"), Vector2(0.38, 0.30))


# --- the printer ------------------------------------------------------------------------------------------------------

## THE PRINTER at the desk's left end, turned so its paper comes up out of it toward the end and falls off it: a beige
## dot-matrix printer, its platen knob, its head on its rail ([member printer_head]), the continuous paper with its
## sprocket holes coming up printed ([member paper], the medium's texture) and folding down over the desk's end into a
## knee-high heap of fanfold on the floor ([member heap]).
func _printer() -> void:
	var t := Node3D.new()
	t.name = "Printer"
	t.position = desk_at("printer")
	t.rotation_degrees = Vector3(0, turn["printer"], 0)
	root.add_child(t)
	var body := Vector3(0.42, 0.12, 0.30)
	put(t, rbox(body, 0.014), _mats["beige"], Vector3(0, body.y * 0.5, 0.02))
	# its smoked cover and the slot the paper comes up through
	put(t, rbox(Vector3(0.38, 0.03, 0.12), 0.01), _std(Color(0.12, 0.10, 0.08, 0.85), 0.2), Vector3(0, body.y + 0.01, -0.03))
	put(t, cyl(0.016, 0.016, 0.02, 16), _mats["dark"], Vector3(body.x * 0.5 + 0.01, body.y * 0.6, -0.04), Vector3(0, 0, 90))
	put(t, box(Vector3(0.012, 0.006, 0.003)), _mats["led_green"], Vector3(0.15, body.y * 0.55, 0.02 + body.z * 0.5 + 0.001))
	printer_head = Node3D.new()
	printer_head.position = Vector3(0, body.y + 0.005, -0.03)
	t.add_child(printer_head)
	put(printer_head, rbox(Vector3(0.04, 0.03, 0.04), 0.006), _mats["dark"], Vector3(0, 0, 0))
	# THE PAPER: up out of the slot, leaning back, then over and down the desk's end (in the printer's own frame its
	# back is -z, which faces the desk's end)
	paper = MeshInstance3D.new()
	paper.name = "Paper"
	paper.mesh = _paper_strip()
	paper.position = Vector3(0, body.y + 0.005, -0.06)
	t.add_child(paper)
	# THE HEAP on the floor below the desk's end: folded sheets, a little askew each
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
	_foot(at_of("printer"), Vector2(0.32, 0.44))


## The paper's strip, in the printer's frame from the slot: up and leaning back, then over the desk's end and down to
## the heap - a mesh whose UV runs along it (0 at the slot) so its printed lines move along it as it feeds.
func _paper_strip() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var path := PackedVector3Array()
	# up 18 cm leaning back, a curl, then down past the desk's end (the printer stands 0.36 in from the end) to the floor
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
			# down past the desk's end (it is 0.27 from the printer) onto the heap's top, a little bowed out as paper falls
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

## THE THREE SCREENS along the desk's back: the security monitor (a small black-and-white CRT in a dark metal box), the
## satellite's flat monitor on its stand, and the little television with its rabbit ears. Each glass a quad the medium
## hands its picture, with a glow of its own.
func _monitors() -> void:
	# the feed
	var f := Node3D.new()
	f.name = "Feed"
	f.position = desk_at("feed")
	f.rotation_degrees = Vector3(0, turn["feed"], 0)
	root.add_child(f)
	var fb := Vector3(0.25, 0.21, 0.25)
	put(f, rbox(fb, 0.01), _mats["dark"], Vector3(0, fb.y * 0.5, 0))
	var fm := put(f, quad(Vector2(0.18, 0.135)), null, Vector3(0, fb.y * 0.55, fb.z * 0.5 + 0.002))
	put(f, box(Vector3(0.01, 0.006, 0.003)), _mats["led_red"], Vector3(0.09, 0.025, fb.z * 0.5 + 0.001))
	var fg := _glow(f, Vector3(0, fb.y * 0.55, fb.z * 0.5 + 0.2), Color(0.72, 0.8, 0.9))
	fg.omni_range = 1.5
	screens["feed"] = {"mesh": fm, "glow": fg, "node": f}
	_foot(at_of("feed"), Vector2(0.28, 0.28))
	# the satellite's flat monitor
	var s := Node3D.new()
	s.name = "Satellite"
	s.position = desk_at("satellite")
	s.rotation_degrees = Vector3(0, turn["satellite"], 0)
	root.add_child(s)
	put(s, cyl(0.07, 0.08, 0.012, 24), _mats["black"], Vector3(0, 0.006, 0))
	put(s, box(Vector3(0.03, 0.14, 0.02)), _mats["black"], Vector3(0, 0.07, -0.01))
	put(s, rbox(Vector3(0.36, 0.235, 0.025), 0.006), _mats["black"], Vector3(0, 0.25, 0.005))
	var sm := put(s, quad(Vector2(0.33, 0.206)), null, Vector3(0, 0.25, 0.0185))
	screens["satellite"] = {"mesh": sm, "glow": _glow(s, Vector3(0, 0.25, 0.25), Color(0.7, 0.8, 1.0)), "node": s}
	_foot(at_of("satellite"), Vector2(0.36, 0.16))
	# the little television, up on a crate and two books so the chair sees it over the radar, its rabbit ears
	var tv := Node3D.new()
	tv.name = "TV"
	tv.position = desk_at("tv")
	tv.rotation_degrees = Vector3(0, turn["tv"], 0)
	root.add_child(tv)
	var crate := Vector3(0.31, 0.2, 0.26)
	put(tv, box(crate), _std(Color(0.30, 0.22, 0.14), 0.85), Vector3(0, crate.y * 0.5, 0))
	for k in 3:
		put(tv, box(Vector3(crate.x + 0.004, 0.012, crate.z + 0.004)), _std(Color(0.22, 0.16, 0.1), 0.85), Vector3(0, 0.03 + float(k) * 0.07, 0))
	put(tv, box(Vector3(0.30, 0.035, 0.24)), _std(Color(0.3, 0.12, 0.08), 0.7), Vector3(0, crate.y + 0.0175, 0))
	put(tv, box(Vector3(0.28, 0.03, 0.22)), _std(Color(0.12, 0.2, 0.3), 0.7), Vector3(0.01, crate.y + 0.05, 0))
	var tb := Vector3(0.27, 0.23, 0.25)
	var tv_y := crate.y + 0.065
	put(tv, rbox(tb, 0.02), _std(Color(0.22, 0.17, 0.12), 0.5), Vector3(0, tv_y + tb.y * 0.5, 0))
	put(tv, rbox(Vector3(0.19, 0.15, 0.01), 0.02), _mats["black"], Vector3(-0.025, tv_y + tb.y * 0.52, tb.z * 0.5 + 0.001))
	var tm := put(tv, quad(Vector2(0.17, 0.13)), null, Vector3(-0.025, tv_y + tb.y * 0.52, tb.z * 0.5 + 0.007))
	for k in 2:
		put(tv, cyl(0.009, 0.01, 0.012, 12), _mats["dark"], Vector3(0.1, tv_y + 0.13 - float(k) * 0.05, tb.z * 0.5 + 0.005), Vector3(90, 0, 0))
	for side in [-1.0, 1.0]:
		var ear := PackedVector3Array([Vector3(0, tv_y + tb.y, -0.02), Vector3(side * 0.13, tv_y + tb.y + 0.30, -0.08)])
		put(tv, tube(ear, 0.0018, 5), _mats["metal"], Vector3.ZERO)
		put(tv, cyl(0.004, 0.004, 0.006, 8), _mats["metal"], ear[1])
	put(tv, cyl(0.02, 0.024, 0.012, 16), _mats["dark"], Vector3(0, tv_y + tb.y + 0.006, -0.02))
	screens["tv"] = {"mesh": tm, "glow": _glow(tv, Vector3(-0.025, tv_y + tb.y * 0.5, 0.3), Color(0.6, 0.75, 1.0)), "node": tv}
	_foot(at_of("tv"), Vector2(0.32, 0.28))


func _glow(parent: Node3D, at: Vector3, c: Color) -> OmniLight3D:
	var g := OmniLight3D.new()
	g.light_color = c
	g.light_energy = 0.0
	g.omni_range = 1.0
	g.omni_attenuation = 1.5
	g.position = at
	parent.add_child(g)
	return g


# --- the switch, and the things ---------------------------------------------------------------------------------------

## THE SWITCH BOX: small, gray metal, one toggle ([member lever], tipped up for GOOD and down for BAD), GOOD on a strip of
## tape above it and BAD below; its wire running back into the terminal.
func _switch() -> void:
	var t := Node3D.new()
	t.name = "Switch"
	t.position = desk_at("switch")
	t.rotation_degrees = Vector3(0, turn["switch"], 0)
	root.add_child(t)
	var b := Vector3(0.09, 0.055, 0.07)
	put(t, rbox(b, 0.004), _mats["gray"], Vector3(0, b.y * 0.5, 0))
	# the toggle stands out of the top, toward the chair: tipped toward the chair is down (BAD), away is up (GOOD)
	put(t, cyl(0.007, 0.008, 0.006, 16), _mats["metal"], Vector3(0, b.y + 0.003, 0.0))
	lever = Node3D.new()
	lever.position = Vector3(0, b.y + 0.005, 0.0)
	t.add_child(lever)
	put(lever, cyl(0.0022, 0.003, 0.03, 10), _mats["metal"], Vector3(0, 0.015, 0))
	put(lever, cyl(0.0035, 0.0035, 0.004, 10), _mats["metal"], Vector3(0, 0.031, 0))
	var good: Texture2D = _tex["GOOD"]
	var bad: Texture2D = _tex["BAD"]
	for pair in [[good, -0.022], [bad, 0.022]]:
		var m := StandardMaterial3D.new()
		m.albedo_texture = pair[0]
		m.roughness = 0.85
		put(t, quad(Vector2(0.05, 0.016)), m, Vector3(0, b.y + 0.0006, float(pair[1])), Vector3(-90, 0, 0))
	var sw := at_of("switch")
	put(root, tube(sag_path(Vector3(sw.x - 0.02 * signf(sw.x), DESK_Y + 0.02, sw.y - 0.03),
		Vector3(CASE_AT.x + 0.18 * signf(sw.x), DESK_Y + 0.05, CASE_AT.y - CASE.z * 0.5 + 0.02), 0.06, DESK_Y + 0.003, 30), 0.0025), _mats["cable"], Vector3.ZERO)


## THE THINGS AT THE DESK'S BACK, standing before the small things are packed round them: the gooseneck lamp ([member
## lamp]) on the phones' side, its neck bowing over toward the keyboard, and the patch panel with its blue and yellow
## cables tangled out of it.
func _things_back() -> void:
	var lp := at_of("lamp")
	var lb := _desk_pos(lp)
	put(root, cyl(0.065, 0.075, 0.025, 28), _mats["dark"], lb + Vector3(0, 0.0125, 0))
	var neck := PackedVector3Array()
	var head := Vector3(lp.x + 0.04 * flip, DESK_Y + 0.42, lp.y + 0.32)
	for i in 24:
		var u := float(i) / 23.0
		var p := lb.lerp(head, u)
		p.y = lb.y + 0.02 + (head.y - lb.y) * sin(u * PI * 0.62) / sin(PI * 0.62)
		neck.append(p)
	put(root, tube(neck, 0.0065, 8), _mats["metal"], Vector3.ZERO)
	var shade := put(root, cyl(0.022, 0.06, 0.09, 24), _mats["dark"], head, Vector3(-30, 0, -40 * flip))
	shade.name = "Shade"
	lamp = SpotLight3D.new()
	lamp.light_color = Color(1.0, 0.82, 0.58)
	lamp.light_energy = LAMP_ENERGY
	lamp.spot_range = 2.8
	lamp.spot_angle = 66.0
	lamp.spot_angle_attenuation = 1.8
	lamp.shadow_enabled = true
	lamp.shadow_bias = 0.02
	lamp.shadow_normal_bias = 1.0
	# a gooseneck's shade is a hand wide: what it casts is soft-edged - and never clean of its own warm light, for the room
	# bounces it back in; a shadow empty of it was left lit by the screens' cool glows alone (which cast none), and the
	# mug's read as a clear pale disc under it
	lamp.shadow_blur = ShadowFilter.blur(6.0)
	lamp.shadow_opacity = 0.62
	root.add_child(lamp)
	var aim_from := head + Vector3(0, -0.02, 0)
	# (looking at the keyboard - set by its basis: a node out of the tree has no global transform to look_at from)
	lamp.transform = Transform3D(Basis.looking_at(Vector3(0.0, DESK_Y, 0.10) - aim_from, Vector3.UP), aim_from)
	_foot(lp, Vector2(0.16, 0.16))
	# the patch panel on its side at the desk's back, its cables tangled out of it
	var pa := at_of("patch")
	var pp := _desk_pos(pa)
	put(root, box(Vector3(0.44, 0.045, 0.05)), _mats["black"], pp + Vector3(0, 0.0225, 0))
	var r := RandomNumberGenerator.new()
	r.seed = hash([_seed, "patch"])
	for k in 12:
		var a := pp + Vector3(-0.19 + float(k) * 0.034, 0.03, 0.026)
		var b := Vector3(r.randf_range(-0.55, 0.65) * flip, DESK_Y + 0.004, r.randf_range(-0.55, -0.44))
		if k % 3 == 0:
			b = Vector3(r.randf_range(-0.2, 0.3) * flip, DESK_Y + 0.004, FAR - 0.02)
		var mat: Material = _mats["cable_blue"] if k % 2 == 0 else _mats["cable_yellow"]
		put(root, tube(sag_path(a, b, -0.02, DESK_Y + 0.003, 18), 0.0024, 6), mat, Vector3.ZERO)
	_foot(pa, Vector2(0.46, 0.08))


## THE SMALL THINGS, where [method _pack] put them: the mug ([member mug], the medium's to lift) with an old ring of dried
## coffee showing beside its foot (opaque and matte, [method _coffee_ring]), the chart taped down ([param chart]), the handbook ([param spine] its spine's label), the
## GPS tracker blinking green ([member tracker_led]), a pencil cup, a rubber stamp and its pad.
func _things(chart: Texture2D, spine: Texture2D) -> void:
	# THE RING OF DRIED COFFEE: a thin, uneven, dull ring where a mug's foot dried on the lacquer, and an older arc beside it -
	# OPAQUE and matte, lit and shadowed as the desk is (2026-11-06, the author: "under the mug, there is a transparent circle
	# ... If it was supposed to be a coaster, it shouldn't be transparent": a translucent disc over the top caught none of the
	# lamp's light and read as glass; a decal drew its footprint pale) - a little off the mug's foot, so it shows beside it.
	var mp := at_of("mug")
	var off := Vector2.from_angle(float(hash([_seed, "ring"]) % 628) / 100.0) * 0.014
	# THE MUG AND THE PENCIL CUP ARE THE LETTER DESK'S (feedback 0037: "We've already created mugs elsewhere, for the
	# journal-writing mode - we should probably just reuse the pencils and mugs we already have ... we want to remain DRY"):
	# made by [method DeskLook.made], as that desk makes them
	mug = Node3D.new()
	mug.name = "Mug"
	mug_home = Transform3D(Basis(Vector3.UP, deg_to_rad(-120.0 + float(turn["mug"]) * 3.0)), _desk_pos(mp))
	mug.transform = mug_home
	root.add_child(mug)
	var mug_made := DeskLook.made("mug", hash([_seed, "mug"]))
	var mug_rad := 0.04
	if not mug_made.is_empty():
		mug.add_child(mug_made["node"])
		mug_rad = (mug_made["size"] as AABB).size.z * 0.5
	var ring := MeshInstance3D.new()
	ring.name = "CoffeeRing"
	ring.mesh = _coffee_ring(hash([_seed, "ring shape"]))
	ring.material_override = _std(Color(0.30, 0.20, 0.13), 0.95)
	ring.position = _desk_pos(mp + off, 0.0004)
	ring.scale = Vector3.ONE * (mug_rad / 0.0375)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(ring)
	# the chart, taped down near the desk's edge
	var cp := at_of("chart")
	var ct := float(turn["chart"]) * 0.4
	var cm := StandardMaterial3D.new()
	cm.albedo_texture = chart
	cm.roughness = 0.9
	put(root, quad(Vector2(0.21, 0.15)), cm, _desk_pos(cp, 0.0012), Vector3(-90, ct, 0))
	for c in [Vector2(-0.1, -0.072), Vector2(0.1, -0.072), Vector2(-0.1, 0.072), Vector2(0.1, 0.072)]:
		put(root, quad(Vector2(0.03, 0.012)), _mats["tape"], _desk_pos(cp + (c as Vector2).rotated(-deg_to_rad(ct)), 0.0016), Vector3(-90, ct + 40.0 * signf(c.x * c.y), 0))
	# (the chart is flat: no footprint - a root may lie across it)
	# the handbook: a fat binder lying down, its spine toward the chair
	var hb := Node3D.new()
	hb.position = desk_at("handbook")
	hb.rotation_degrees = Vector3(0, turn["handbook"], 0)
	root.add_child(hb)
	var cover := _std(Color(0.10, 0.14, 0.26), 0.6)
	put(hb, box(Vector3(0.24, 0.006, 0.30)), cover, Vector3(0, 0.003, 0))
	put(hb, box(Vector3(0.24, 0.006, 0.30)), cover, Vector3(0, 0.069, 0))
	put(hb, box(Vector3(0.225, 0.06, 0.285)), _mats["paper"], Vector3(0.005, 0.036, 0))
	var sm := StandardMaterial3D.new()
	sm.albedo_texture = spine
	sm.roughness = 0.6
	put(hb, box(Vector3(0.012, 0.072, 0.30)), cover, Vector3(-0.12, 0.036, 0))
	put(hb, quad(Vector2(0.22, 0.06)), sm, Vector3(-0.1265, 0.036, 0), Vector3(0, -90, 0))
	# the GPS tracker: a small black puck, its light blinking green
	var gp := desk_at("tracker")
	put(root, rbox(Vector3(0.05, 0.016, 0.035), 0.006), _mats["black"], gp + Vector3(0, 0.008, 0), Vector3(0, 30.0 + float(turn["tracker"]), 0))
	tracker_led = put(root, cyl(0.002, 0.002, 0.002, 8), _mats["led_green"], gp + Vector3(0.012, 0.017, 0.004))
	# the pencil cup, the letter desk's: hollow, its pencils standing in it
	var cup_made := DeskLook.made("pencil_cup", hash([_seed, "cup"]))
	if not cup_made.is_empty():
		var cup: Node3D = cup_made["node"]
		cup.name = "PencilCup"
		cup.position = desk_at("cup")
		cup.rotation.y = deg_to_rad(float(turn["cup"]) * 10.0)
		root.add_child(cup)
	# the rubber stamp and its ink pad
	var st := Node3D.new()
	st.position = desk_at("stamp")
	st.rotation_degrees = Vector3(0, turn["stamp"], 0)
	root.add_child(st)
	put(st, rbox(Vector3(0.09, 0.016, 0.06), 0.004), _std(Color(0.1, 0.1, 0.12), 0.4, 0.4), Vector3(-0.02, 0.008, 0))
	put(st, box(Vector3(0.05, 0.012, 0.03)), _mats["dark"], Vector3(0.055, 0.006, 0.0))
	put(st, cyl(0.009, 0.012, 0.055, 12), _mats["wood_dark"], Vector3(0.055, 0.04, 0.0))


## THE OLD COFFEE RING's shape, flat on the desk: a thin rim round where a mug stood - wider and narrower by turns, a gap
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


## THE CHAIR the viewer sits in: an empty office chair, seen only from behind it (the live picture on the television).
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


# --- where the camera looks -------------------------------------------------------------------------------------------

## THE SPOTS the camera turns to ([constant DispatchMedium.SPOTS]): for each, what it aims at, where the eye is (the chair's,
## leaned toward it), and how wide the lens is (degrees, vertical).
func _spots() -> void:
	var y := DESK_Y
	var mon_y := y + CASE.y + 0.045 + CRT.y * 0.5 + 0.012
	spots["home"] = {"aim": Vector3(0.0, y + 0.17, -0.16), "eye": EYE, "fov": 54.0}
	spots["terminal"] = {"aim": Vector3(0.0, mon_y, CASE_AT.y + CRT.z * 0.5 - 0.01), "eye": Vector3(0.0, mon_y + 0.07, 0.44), "fov": 33.0}
	spots["keyboard"] = {"aim": Vector3(0.0, y + 0.03, KEYBOARD_AT.y), "eye": EYE + Vector3(0, -0.05, -0.15), "fov": 36.0}
	var ph := (_phone_spot(0, 0) + _phone_spot(ROW - 1, 1)) * 0.5
	spots["phones"] = {"aim": Vector3(ph.x + 0.0, y + 0.01, 0.0), "eye": EYE + Vector3(-0.30 * flip, -0.02, -0.12), "fov": 38.0}
	var ra := at_of("radar")
	spots["radar"] = {"aim": Vector3(ra.x - 0.02 * flip, y + 0.15, ra.y + 0.13), "eye": EYE + Vector3(0.18 * flip, -0.04, -0.12), "fov": 34.0}
	var rc := at_of("receiver")
	spots["receiver"] = {"aim": Vector3(rc.x - 0.02 * flip, y + 0.14, rc.y), "eye": EYE + Vector3(0.42 * flip, 0.02, -0.10), "fov": 30.0}
	# the printer, and its paper falling off the desk's end to the heap on the floor
	var pr := at_of("printer")
	spots["printer"] = {"aim": Vector3(pr.x - 0.29 * flip, y - 0.18, pr.y + 0.14), "eye": EYE + Vector3(-0.42 * flip, 0.06, -0.02), "fov": 54.0}
	# the small things, wherever they were packed: the eye leans a little toward the side each is on
	for pair in [["chart", 0.0, 0.03, -0.04, -0.18, 28.0], ["handbook", 0.05, -0.08, -0.04, -0.12, 32.0],
			["switch", 0.04, 0.10, -0.06, -0.22, 24.0], ["mug", 0.08, 0.10, -0.04, -0.12, 34.0]]:
		var k := String(pair[0])
		var p := at_of(k)
		var side := signf(p.x) if absf(p.x) > 0.05 else 1.0
		spots[k] = {"aim": Vector3(p.x, y + float(pair[1]), p.y), "eye": EYE + Vector3(absf(float(pair[2])) * side, float(pair[3]), float(pair[4])),
			"fov": float(pair[5])}
	for k in screens:
		var sc: Dictionary = screens[k]
		var mesh: MeshInstance3D = sc["mesh"]
		var node: Node3D = sc["node"]
		var c := node.transform * mesh.position
		var nrm := node.transform.basis * Vector3.BACK
		spots[k] = {"aim": c, "eye": c + nrm * 0.55 + Vector3(0, 0.06, 0) + (EYE - c).normalized() * 0.05, "fov": 26.0}
	for k in ["feed", "satellite", "tv"]:
		var s: Dictionary = spots[k]
		# never further from the chair than a lean takes it
		var e: Vector3 = s["eye"]
		s["eye"] = EYE + (e - EYE).limit_length(0.42)


## Where phone [param i] is in its row (world).
func phone_home(i: int) -> Transform3D:
	return (phones[i] as Dictionary)["home"]


## Where a phone laid open on the desk lies, the [param k]th laid down.
func held_xf(k: int) -> Transform3D:
	var h := at_of("held")
	var spot := h + Vector2(flip * float(k) * HELD_STEP, 0.0)
	return Transform3D(Basis(Vector3.UP, deg_to_rad((-22.0 + float(k) * 13.0) * flip)), Vector3(spot.x, DESK_Y, spot.y))
