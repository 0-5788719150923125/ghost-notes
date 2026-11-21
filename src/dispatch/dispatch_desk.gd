extends RefCounted
class_name DispatchDesk

## DispatchDesk - the Dispatch desk's own desk, as a prop on its Props card ([DispatchProps]; next/dispatch.md): its top built as a
## table's is ([Tables]: boards of wood, their grain and seams, an edge), the pad laid on it, and what holds it up - two pedestals of
## drawers, one pedestal and a pair of legs, or four legs on an apron - each a property a person sets or Roll draws ([Roll],
## [constant FIELDS]). Kept unrolled, it is the desk the hollow has always had. Its size and where its pad lies are the scene's
## ([constant DispatchSet.DESK_W], [constant DispatchSet.BLOTTER]), so whatever stands on it stands where it did.
##
## Built out of any tree, in the set's space ([method build]); built alone for its picture and its 3D view ([method made]).

## What a desk can be told: its wood (color, grain, polish, wear), how wide its boards are (0 one slab), its edge and how thick its
## top is, the pad on it and its color, what holds it up, how many drawers a pedestal has, and their handles' kind and metal.
const FIELDS := {
	"wood": {"label": "Wood", "blurb": "The wood's color.", "type": "color", "default": "#2a1810",
		"roll": ["#2a1810", "#3b2414", "#5a3820", "#6e4a2a", "#8a6440", "#24160e", "#4a3a2c", "#7a3e22"]},
	"grain": {"label": "Grain", "blurb": "How fine the wood's grain is.", "type": "float", "min": 0.4, "max": 4.0, "step": 0.1, "default": 1.4,
		"roll": [0.8, 2.4]},
	"polish": {"label": "Polish", "blurb": "How much the top shines.", "type": "float", "min": 0.0, "max": 1.0, "step": 0.05, "default": 0.1,
		"roll": [0.0, 0.3]},
	"wear": {"label": "Wear", "blurb": "How worn the top is.", "type": "float", "min": 0.0, "max": 1.0, "step": 0.05, "default": 0.4,
		"roll": [0.1, 0.75]},
	"boards": {"label": "Boards", "blurb": "How wide its boards are (cm); 0 one slab.", "type": "float", "min": 0.0, "max": 40.0, "step": 1.0,
		"default": 19.0, "roll": [10.0, 32.0]},
	"edge": {"label": "Edge", "blurb": "How its top's edge is cut.", "type": "enum", "options": ["square", "eased", "bevel", "bullnose", "ogee", "bead"],
		"default": "eased", "roll": ["square", "eased", "bevel", "bullnose", "ogee", "bead"]},
	"thick": {"label": "Top", "blurb": "How thick its top is (cm).", "type": "float", "min": 2.0, "max": 8.0, "step": 0.5, "default": 4.5,
		"roll": [3.0, 6.5]},
	"pad": {"label": "Pad", "blurb": "What lies on it under the keyboard.", "type": "enum", "options": ["felt", "velvet", "linen", "none"],
		"default": "felt", "roll": ["felt", "felt", "velvet", "linen", "none"]},
	"pad_color": {"label": "Pad color", "blurb": "The pad's color.", "type": "color", "default": "#2c4a33",
		"roll": ["#2c4a33", "#1f3550", "#5a2020", "#2e2e30", "#4a3a22", "#3d4a2a"]},
	"base": {"label": "Base", "blurb": "What holds it up.", "type": "enum", "options": ["pedestals", "pedestal", "legs"],
		"labels": {"pedestals": "Two pedestals", "pedestal": "A pedestal and legs", "legs": "Four legs"},
		"default": "pedestals", "roll": ["pedestals", "pedestals", "pedestal", "legs"]},
	"drawers": {"label": "Drawers", "blurb": "How many drawers a pedestal has.", "type": "int", "min": 1, "max": 5, "step": 1, "default": 3,
		"roll": [2, 4]},
	"handles": {"label": "Handles", "blurb": "The drawers' handles.", "type": "enum", "options": ["bar", "knob"], "default": "bar",
		"roll": ["bar", "knob"]},
	"metal": {"label": "Metal", "blurb": "The handles' metal.", "type": "color", "default": "#8c8f94",
		"roll": ["#8c8f94", "#b08d4a", "#3a3a3c", "#a87b5a"]},
}
## A pedestal (m): how wide, how far in from the desk's end, and how far its drawers' fronts stand before the desk's front; a leg's
## side and how far in from the corners legs stand; the apron's height.
const PEDESTAL := 0.48
const PEDESTAL_IN := 0.03
const LEG := 0.055
const LEG_IN := 0.04
const APRON := 0.09
## How far what holds the top up reaches into it (m): never short of its underside, whatever its thickness, or the room shows
## through the slit.
const UNDER_INTO := 0.003
## How far above the floor the modesty panel at the back starts (m).
const PANEL_FOOT := 0.225


## What a desk kept as [param spec] (`{seed, <its fields set>}`, [method Roll.own_or_drawn]) is, every field.
static func values_of(spec: Dictionary) -> Dictionary:
	return Roll.own_or_drawn(FIELDS, spec)


## The desk of [param v] ([method values_of]), its grain drawn from [param seed]: under one node, in the set's space.
static func build(v: Dictionary, seed: int) -> Node3D:
	var root := Node3D.new()
	root.name = "Desk"
	var w := DispatchSet.DESK_W
	var d := DispatchSet.DESK_D
	var y := DispatchSet.DESK_Y
	var mid := Vector2(0.0, (DispatchSet.NEAR + DispatchSet.FAR) * 0.5)
	var wood := Color.html(String(v["wood"]))
	var mat := {"kind": "wood", "color": "#" + wood.to_html(false), "color2": "#" + wood.darkened(0.52).to_html(false),
		"polish": float(v["polish"]), "pattern": 0.6, "grain": float(v["grain"]), "wear": float(v["wear"])}
	var top := {"shape": "rect", "size": [w * 100.0, d * 100.0], "thickness": float(v["thick"]), "edge": String(v["edge"]),
		"material": "the desk", "boards": {"width": float(v["boards"]), "turn": 0.0}}
	var layers: Array = []
	if String(v["pad"]) != "none":
		var pad := DispatchSet.BLOTTER
		var blot := pad.get_center()
		var pad_color := Color.html(String(v["pad_color"]))
		layers.append({"name": "the blotter", "what": "a worn blotter", "outline": "rect", "size": [pad.size.x * 100.0, pad.size.y * 100.0],
			"at": [(blot.x - mid.x - Tables.TOP_AT.x) * 100.0, (blot.y - mid.y - Tables.TOP_AT.y) * 100.0], "turn": DispatchSet.BLOTTER_TURN,
			"fabric": String(v["pad"]), "pattern": {"kind": "plain", "colors": ["#" + pad_color.to_html(false)]},
			"border": {"width": 2.6, "inset": 0.0, "color": "#3b2a1c"}})
	var spec := Tables.sanitize(top, layers, {"the desk": Props.sanitize_material(mat, "#2a1810")}, [])
	var built := Tables.build(spec, seed)
	var furniture: Node3D = built["node"]
	furniture.position = Vector3(mid.x - Tables.ORIGIN.x - Tables.TOP_AT.x, y, mid.y - Tables.ORIGIN.y - Tables.TOP_AT.y)
	root.add_child(furniture)
	var frame := DispatchSet._std(wood.darkened(0.27), 0.55)
	var metal := DispatchSet._std(Color.html(String(v["metal"])), 0.3, 0.85)
	var near := DispatchSet.NEAR
	var far := DispatchSet.FAR
	var under := _under(v)
	# the modesty panel at the back, from a hand above the floor up into the top
	var panel_h := under - PANEL_FOOT
	match String(v["base"]):
		"pedestals":
			for side in [-1.0, 1.0]:
				_pedestal(root, side, v, frame, metal)
			DispatchSet.put(root, DispatchSet.box(Vector3(w - 1.0, panel_h, 0.025)), frame, Vector3(0, PANEL_FOOT + panel_h * 0.5, far + 0.08))
		"pedestal":
			_pedestal(root, 1.0, v, frame, metal)
			for z in [near - LEG_IN - LEG * 0.5, far + LEG_IN + LEG * 0.5]:
				_leg(root, Vector2(-w * 0.5 + LEG_IN + LEG * 0.5, z), frame, under)
			DispatchSet.put(root, DispatchSet.box(Vector3(w - 0.6, panel_h, 0.025)), frame, Vector3(-0.24, PANEL_FOOT + panel_h * 0.5, far + 0.08))
		_:
			for sx in [-1.0, 1.0]:
				for z in [near - LEG_IN - LEG * 0.5, far + LEG_IN + LEG * 0.5]:
					_leg(root, Vector2(sx * (w * 0.5 - LEG_IN - LEG * 0.5), z), frame, under)
			# the apron under the top, round all four sides, hung from its underside
			var inner := Vector2(w - 2.0 * LEG_IN, d - 2.0 * LEG_IN)
			var ay := under - APRON * 0.5
			DispatchSet.put(root, DispatchSet.box(Vector3(inner.x, APRON, 0.02)), frame, Vector3(0, ay, near - LEG_IN - 0.01))
			DispatchSet.put(root, DispatchSet.box(Vector3(inner.x, APRON, 0.02)), frame, Vector3(0, ay, far + LEG_IN + 0.01))
			for sx in [-1.0, 1.0]:
				DispatchSet.put(root, DispatchSet.box(Vector3(0.02, APRON, inner.y)), frame, Vector3(sx * (w * 0.5 - LEG_IN - 0.01), ay, mid.y))
	return root


## Where what holds the top of [param v] up reaches to (m): a little into the top, past its underside.
static func _under(v: Dictionary) -> float:
	return DispatchSet.DESK_Y - float(v["thick"]) / 100.0 + UNDER_INTO


## A pedestal of drawers on [param side] of the desk (-1 its left end, 1 its right), as [param v] has them.
static func _pedestal(root: Node3D, side: float, v: Dictionary, frame: Material, metal: Material) -> void:
	var w := DispatchSet.DESK_W
	var near := DispatchSet.NEAR
	var mid_z := (near + DispatchSet.FAR) * 0.5
	var ped := Vector3(PEDESTAL, _under(v), DispatchSet.DESK_D - 0.08)
	var x := side * (w * 0.5 - ped.x * 0.5 - PEDESTAL_IN)
	DispatchSet.put(root, DispatchSet.rbox(ped, 0.01), frame, Vector3(x, ped.y * 0.5, mid_z))
	var n := int(v["drawers"])
	var pitch := 0.63 / float(n)
	for k in n:
		var at := 0.12 + float(k) * pitch
		var front := pitch - 0.02
		DispatchSet.put(root, DispatchSet.rbox(Vector3(PEDESTAL - 0.04, front, 0.012), 0.004), frame,
			Vector3(side * (w * 0.5 - 0.27), at + 0.05 + (front - 0.19) * 0.5, near - 0.035))
		var hy := at + 0.08 + (front - 0.19) * 0.5
		if String(v["handles"]) == "knob":
			var knob := SphereMesh.new()
			knob.radius = 0.011
			knob.height = 0.022
			DispatchSet.put(root, knob, metal, Vector3(side * (w * 0.5 - 0.27), hy, near - 0.022))
		else:
			DispatchSet.put(root, DispatchSet.cyl(0.006, 0.006, 0.07, 8), metal, Vector3(side * (w * 0.5 - 0.27), hy, near - 0.022), Vector3(0, 0, 90))


## A leg standing at [param at] (x, z): square, a little narrower at its foot, up to [param under] ([method _under]).
static func _leg(root: Node3D, at: Vector2, frame: Material, under: float) -> void:
	var h := under
	var leg := CylinderMesh.new()
	leg.top_radius = LEG * 0.62
	leg.bottom_radius = LEG * 0.48
	leg.height = h
	leg.radial_segments = 4
	leg.rings = 1
	var m := DispatchSet.put(root, leg, frame, Vector3(at.x, h * 0.5, at.y), Vector3(0, 45, 0))
	m.name = "Leg"


## The desk of [param v] built alone, for its picture and its 3D view: `{node, size}` - its node out of any tree, its bounds in the
## node's own space.
static func made(v: Dictionary, seed: int) -> Dictionary:
	var node := build(v, seed)
	var mid_z := (DispatchSet.NEAR + DispatchSet.FAR) * 0.5
	var box := AABB(Vector3(-DispatchSet.DESK_W * 0.5, 0.0, mid_z - DispatchSet.DESK_D * 0.5),
		Vector3(DispatchSet.DESK_W, DispatchSet.DESK_Y + float(v["thick"]) * 0.01, DispatchSet.DESK_D))
	return {"node": node, "size": box}


## What the desk of [param v] is, in a line.
static func line_of(v: Dictionary) -> String:
	var base := String((FIELDS["base"]["labels"] as Dictionary).get(String(v["base"]), String(v["base"]))).to_lower()
	var pad := "no pad" if String(v["pad"]) == "none" else "a %s pad" % String(v["pad"])
	var boards := "one slab" if float(v["boards"]) <= 0.0 else "%d cm boards" % roundi(float(v["boards"]))
	return "%s, %s, %s" % [base, boards, pad]
