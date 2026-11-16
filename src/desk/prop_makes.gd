extends RefCounted
class_name PropMakes

## PropMakes - the parts a scene gives a prop to play (a role: the desk's mug, its cup of pencils), and the make chosen to play
## one, built. What a role does is the scene's - a mug is lifted to the mouth and set down in its ring of old coffee - and any make
## of it is built in the role's frame so that holds: its foot on y = 0, centered, its front toward +z, its height within the
## role's ([method made]). A scene that works a role asks this for its make and never for a particular shape.
##
## A choice is `{}` (the scene's own, drawn from its number), `{recipe, seed}` (the role's recipe drawn from another number,
## [method DeskLook.spec_of]) or `{kept}` (a prop kept in the library by that name, [ThingLibrary]; where the library has none,
## the scene's own). The Dex offers them ([MakeShelf]); the scene keeps the choice in its note.

## The roles: `recipe` the [constant DeskLook.THINGS] kind that makes one, `find` the words the Dex is first filtered by when one
## is chosen, `tall` its height (cm, least and most) - a kept prop outside it is scaled into it, so what the scene does with it
## still fits.
const ROLES := {
	"mug": {"label": "The mug", "blurb": "A mug drunk from: lifted to the mouth and set down again in its ring of old coffee.",
		"recipe": "mug", "find": "mug", "tall": [7.0, 13.0]},
	"pencil_cup": {"label": "The cup of pencils", "blurb": "A cup holding a few pencils, standing on the desk.",
		"recipe": "pencil_cup", "find": "cup", "tall": [8.0, 22.0]},
}
## How many of a role's recipe the Dex draws to choose from.
const DRAWS := 24


## Role [param role]'s make for [param choice], built ([method Props.build]'s answer, meters: its foot on y = 0, centered, its
## front toward +z) and fitted to the role; [param seed] the scene's own number for it. {} where nothing can be built. Touches no
## tree: a scene builds on a worker.
static func made(role: String, choice: Dictionary, seed: int) -> Dictionary:
	var row: Dictionary = ROLES.get(role, {})
	var recipe := String(row.get("recipe", role))
	if not choice.has("kept"):
		return DeskLook.made(recipe, int(choice.get("seed", seed)) if choice.has("recipe") else seed)
	var e := ThingLibrary.read(String(choice["kept"]))
	if e.is_empty():
		return DeskLook.made(recipe, seed)
	var safe := Props.sanitize({"things": [e["thing"]], "materials": e["materials"]}, ["#888888"])
	if (safe["things"] as Array).is_empty():
		return DeskLook.made(recipe, seed)
	var t: Dictionary = (safe["things"] as Array)[0]
	var b := Props.build(t, safe["materials"], hash([seed, "made", String(choice["kept"])]))
	return fitted(b, float(t.get("scale", 1.0)), row.get("tall", []) as Array)


## Built thing [param b] at its own scale [param own], made [param tall] tall where it is not (cm, least and most): its node,
## size, foot, outline and wicks scaled as one.
static func fitted(b: Dictionary, own: float, tall: Array) -> Dictionary:
	if not (b.get("node") is Node3D):
		return b
	var size: AABB = b["size"]
	var k := own
	var h := size.size.y * own * 100.0
	if tall.size() == 2 and h > 0.0:
		k *= clampf(h, float(tall[0]), float(tall[1])) / h
	if is_equal_approx(k, 1.0):
		return b
	var out := b.duplicate()
	(b["node"] as Node3D).scale *= k
	out["size"] = AABB(size.position * k, size.size * k)
	for key in ["foot", "outline"]:
		if b.get(key) is PackedVector2Array:
			var scaled := PackedVector2Array()
			for p in (b[key] as PackedVector2Array):
				scaled.append(p * k)
			out[key] = scaled
	if b.get("wicks") is Array:
		out["wicks"] = (b["wicks"] as Array).map(func(w: Variant) -> Variant: return (w as Vector3) * k if w is Vector3 else w)
	out["sized"] = k
	return out


## Role [param role]'s make for [param choice] as written before it is built: `{thing, materials}` - the spec its picture and its
## 3D view are made from - or {} where there is none.
static func spec(role: String, choice: Dictionary, seed: int) -> Dictionary:
	var recipe := String((ROLES.get(role, {}) as Dictionary).get("recipe", role))
	if choice.has("kept"):
		var e := ThingLibrary.read(String(choice["kept"]))
		if not e.is_empty():
			return {"thing": e["thing"], "materials": e["materials"]}
	var sp := DeskLook.spec_of(recipe, int(choice.get("seed", seed)) if choice.has("recipe") else seed)
	var things: Array = sp.get("things", []) if sp.get("things") is Array else []
	if things.is_empty():
		return {}
	return {"thing": things[0], "materials": sp.get("materials", {}) if sp.get("materials") is Dictionary else {}}


## What [param choice] is called, for role [param role]: the scene's own, a recipe's draw, or the kept prop's name.
static func name_of(role: String, choice: Dictionary) -> String:
	var noun := String(((ROLES.get(role, {}) as Dictionary).get("label", role))).trim_prefix("The ")
	if choice.has("kept"):
		return String(choice["kept"])
	if choice.has("recipe"):
		return "%s no. %d" % [noun, int(choice.get("seed", 0))]
	return "%s drawn for this scene" % noun


## Whether [param choice] is one a role can be handed: none, a draw of its recipe, or a kept prop by name.
static func valid(choice: Variant) -> bool:
	if not (choice is Dictionary):
		return false
	var c: Dictionary = choice
	if c.is_empty():
		return true
	if c.has("kept"):
		return c["kept"] is String and not String(c["kept"]).strip_edges().is_empty()
	return c.has("recipe") and (c.get("seed") is float or c.get("seed") is int)
