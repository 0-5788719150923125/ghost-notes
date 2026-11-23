extends RefCounted
class_name Cameras

## Cameras - the cameras a show can cut between, as a list (the Camera card's Cameras, [CameraCard]): each entry one camera
## of a [constant REGISTRY] sort with its own settings, as the Props card lists props. The list is in priority order: where two
## cameras both want a moment, the one higher in the list has it. A sort left off the list is never used.
##
## A camera here is a behavior, never a place: what it wants a moment for and how it frames it is the format's to work out
## from what it is handed ([TableGame] reads a game's turns, throws, marches and long narration). Each entry is
## `{sort, ...fields}`; a field unset stands at its row's default ([method value]).
##
## Gate: tests/motion/cameras_check.gd.

## Every sort of camera. `fields` are its settings, as [SchemaForm] draws them.
const REGISTRY := {
	"dice": {"label": "Dice", "blurb": "Eases in on the dice as they land, from over the shoulder of whoever threw them, and back out once the words go on.",
		"fields": {
			"far": {"label": "Distance (cm)", "type": "float", "min": 15.0, "max": 120.0, "step": 1.0, "default": 48.0,
				"blurb": "How far from the dice it comes to rest."},
			"holds": {"label": "Holds (s)", "type": "float", "min": 0.0, "max": 8.0, "step": 0.1, "default": 1.6,
				"blurb": "How long it stays on the dice after they stop."},
			"miniature": {"label": "Miniature", "type": "float", "min": 0.0, "max": 1.0, "step": 0.05, "default": 0.4,
				"blurb": "How much it looks like a tilt-shift photograph of a model: a narrow band in focus where it looks, everything nearer and farther soft. 0 sharp throughout."},
		}},
	"march": {"label": "Marching", "blurb": "Low and close on the model, beside a figure as it walks across it: what the party sees as it goes, under the words.",
		"fields": {
			"low": {"label": "Height (cm)", "type": "float", "min": 1.0, "max": 30.0, "step": 0.5, "default": 4.5,
				"blurb": "How high over the ground the lens is: 3-5 is a figure's own eye line."},
			"back": {"label": "Behind (cm)", "type": "float", "min": 5.0, "max": 80.0, "step": 1.0, "default": 20.0,
				"blurb": "How far behind and beside the walkers it follows."},
			"side": {"label": "Beside", "type": "float", "min": -1.0, "max": 1.0, "step": 0.05, "default": 0.45,
				"blurb": "How far round to their side it stands: 0 straight behind, 1 square to their right, -1 their left."},
			"lens": {"label": "Lens (°)", "type": "float", "min": 12.0, "max": 70.0, "step": 1.0, "default": 38.0,
				"blurb": "How much it takes in, up the frame."},
			"lingers": {"label": "Lingers (s)", "type": "float", "min": 0.0, "max": 20.0, "step": 0.5, "default": 3.0,
				"blurb": "How long it stays with them once they arrive."},
			"miniature": {"label": "Miniature", "type": "float", "min": 0.0, "max": 1.0, "step": 0.05, "default": 0.45,
				"blurb": "How much it looks like a tilt-shift photograph of a model: a narrow band in focus where it looks, everything nearer and farther soft. 0 sharp throughout."},
		}},
	"seat": {"label": "Their seat", "blurb": "Moves round the table to whoever's turn it is and looks from where they sit, over their shoulder: their roll seen from their side.",
		"fields": {
			"height": {"label": "Height (cm)", "type": "float", "min": 15.0, "max": 120.0, "step": 1.0, "default": 46.0,
				"blurb": "How high over the table: a person sitting has their eyes about 45 cm over it."},
			"back": {"label": "Behind (cm)", "type": "float", "min": 0.0, "max": 80.0, "step": 1.0, "default": 22.0,
				"blurb": "How far back from the table's edge it stands."},
			"lens": {"label": "Lens (°)", "type": "float", "min": 12.0, "max": 70.0, "step": 1.0, "default": 30.0,
				"blurb": "How much it takes in, up the frame."},
			"holds": {"label": "Holds (s)", "type": "float", "min": 2.0, "max": 60.0, "step": 0.5, "default": 22.0,
				"blurb": "The longest it stays at a seat with no new turn: after it, back to the table as a whole."},
			"miniature": {"label": "Miniature", "type": "float", "min": 0.0, "max": 1.0, "step": 0.05, "default": 0.5,
				"blurb": "How much it looks like a tilt-shift photograph of a model: a narrow band in focus where it looks, everything nearer and farther soft. 0 sharp throughout."},
		}},
	"drift": {"label": "Drifting", "blurb": "Circles the model slowly while nothing else wants the moment: long narration over the land itself.",
		"fields": {
			"height": {"label": "Height (cm)", "type": "float", "min": 5.0, "max": 200.0, "step": 1.0, "default": 60.0,
				"blurb": "How high over the table it circles."},
			"reach": {"label": "Distance (cm)", "type": "float", "min": 20.0, "max": 400.0, "step": 1.0, "default": 165.0,
				"blurb": "How far from the model's middle."},
			"speed": {"label": "Speed (°/s)", "type": "float", "min": 0.1, "max": 12.0, "step": 0.1, "default": 1.6,
				"blurb": "How fast it goes round."},
			"after": {"label": "After (s)", "type": "float", "min": 0.0, "max": 60.0, "step": 0.5, "default": 6.0,
				"blurb": "How long nothing else must want the moment before it starts."},
			"miniature": {"label": "Miniature", "type": "float", "min": 0.0, "max": 1.0, "step": 0.05, "default": 0.7,
				"blurb": "How much it looks like a tilt-shift photograph of a model: a narrow band in focus where it looks, everything nearer and farther soft. 0 sharp throughout."},
			"lens": {"label": "Lens (°)", "type": "float", "min": 12.0, "max": 70.0, "step": 1.0, "default": 34.0,
				"blurb": "How much it takes in, up the frame."},
		}},
}
## The list a note with no Cameras of its own has: every sort, the dice first.
const DEFAULT := ["dice", "march", "seat", "drift"]
## How long a cut between two cameras takes (seconds): every change of camera is a move, never a jump.
const EASE := 1.8
## The fastest a cut moves the eye in a straight line, at its quickest (meters a second): a longer move takes longer than
## [constant EASE]. Going round the table rather than across it, the eye travels a share more.
const SPEED := 0.65


## The list [param raw] made safe: each entry a known sort, its fields within their rows, a field at its default dropped. An
## empty list stands for [constant DEFAULT] only where [param fill] says so.
static func sanitize(raw: Variant, fill := false) -> Array:
	var out: Array = []
	if raw is Array:
		for e in raw:
			if not (e is Dictionary) or not REGISTRY.has(String((e as Dictionary).get("sort", ""))):
				continue
			var sort := String(e["sort"])
			var entry := {"sort": sort}
			var fields: Dictionary = Registry.field(REGISTRY, sort, "fields", {})
			for k in fields:
				var v: Variant = (e as Dictionary).get(k)
				if not (v is float or v is int):
					continue
				var row: Dictionary = fields[k]
				var f := clampf(float(v), float(row["min"]), float(row["max"]))
				if not is_equal_approx(f, float(row["default"])):
					entry[k] = f
			out.append(entry)
	if out.is_empty() and fill:
		for s in DEFAULT:
			out.append({"sort": s})
	return out


## A field of [param entry]: what it sets, or its row's default.
static func value(entry: Dictionary, key: String) -> float:
	var fields: Dictionary = Registry.field(REGISTRY, String(entry.get("sort", "")), "fields", {})
	var v: Variant = entry.get(key)
	if v is float or v is int:
		return float(v)
	return float((fields.get(key, {}) as Dictionary).get("default", 0.0))


## Where [param sort] stands in [param list] (0 the first, wins every moment it wants), or -1 where it is not on it.
static func rank(list: Array, sort: String) -> int:
	for i in list.size():
		if String((list[i] as Dictionary).get("sort", "")) == sort:
			return i
	return -1


## The entry of [param sort] in [param list], or {} where it is not on it.
static func entry_of(list: Array, sort: String) -> Dictionary:
	var i := rank(list, sort)
	return list[i] if i >= 0 else {}


## A shot `{eye, at, fov}` (meters, degrees) as a camera transform.
static func transform_of(shot: Dictionary) -> Transform3D:
	var eye: Vector3 = shot["eye"]
	var at: Vector3 = shot["at"]
	var d := at - eye
	if d.length() < 0.0001:
		d = Vector3(0, -1, -0.01)
	var up := Vector3.UP if absf(d.normalized().dot(Vector3.UP)) < 0.995 else Vector3.BACK
	return Transform3D(Basis.looking_at(d, up), eye)


## [param a] toward [param b] by [param w]: round [param center] rather than through it, so a move from one seat to another
## goes round the table and never through what stands on it. Where it looks at, its height and its lens go straight.
static func blend(a: Dictionary, b: Dictionary, w: float, center := Vector3.ZERO) -> Dictionary:
	if w <= 0.0:
		return a
	if w >= 1.0:
		return b
	var ea: Vector3 = a["eye"] - center
	var eb: Vector3 = b["eye"] - center
	var ra := Vector2(ea.x, ea.z).length()
	var rb := Vector2(eb.x, eb.z).length()
	var aa := atan2(ea.x, ea.z)
	var ab := atan2(eb.x, eb.z)
	var ang := lerp_angle(aa, ab, w)
	var r := lerpf(ra, rb, w)
	# ...a move between two far sides of the table rises a little over it, as a hand-held camera would carry
	var arc := absf(angle_difference(aa, ab)) / PI
	var y := lerpf(ea.y, eb.y, w) + arc * 4.0 * w * (1.0 - w) * 0.12
	var eye := center + Vector3(sin(ang) * r, y, cos(ang) * r)
	return {"eye": eye, "at": (a["at"] as Vector3).lerp(b["at"], w), "fov": lerpf(float(a["fov"]), float(b["fov"]), w),
		"mini": lerpf(float(a.get("mini", 0.0)), float(b.get("mini", 0.0)), w)}
