extends RefCounted
class_name PropMakes

## PropMakes - the parts a scene gives a prop to play (a role: the desk's mug, its terminal, a phone), and the make chosen to play
## one, built (next/working_props.md). What a role does is the scene's - a mug is lifted to the mouth, a terminal shows its program on
## its screen - and any make of it is built in the role's frame so that holds: its foot on y = 0, centered, its front toward +z, its
## height within the role's ([method made]). A scene works a make through its rig ([PropRig]: its faces, lights and named parts),
## never by its shapes.
##
## A role's own make is a recipe drawn from the scene's number (`recipe`, [method DeskLook.spec_of]) or a prop shipped with the app
## (`own`, a `.prop.json` as Export writes one). A choice is `{}` (the role's own), `{recipe, seed}` (its recipe drawn from another
## number) or `{kept}` (a prop kept in the library by that name, [ThingLibrary]). A make missing a face the scene fills (`faces`) cannot
## play the role: the role's own plays it. The Dex offers makes ([MakeShelf]); the scene keeps the choice in its note.

## The roles: `recipe` the [constant DeskLook.THINGS] kind that draws one, or `own` the prop it is shipped as; `find` the words the
## Dex is first filtered by when one is chosen; `tall` its height (cm, least and most) - a make outside it is scaled into it, so what
## the scene does with it still fits; `faces` what the scene shows on it, by name; `feeds` what the scene feeds it, by name, its
## parts following each as their `runs` say ([Motions] `follow`).
const ROLES := {
	"mug": {"label": "The mug", "blurb": "A mug drunk from: lifted to the mouth and set down again in its ring of old coffee.",
		"recipe": "mug", "find": "mug", "tall": [7.0, 13.0], "faces": [], "feeds": {}},
	"pencil_cup": {"label": "The cup of pencils", "blurb": "A cup holding a few pencils, standing on the desk.",
		"recipe": "pencil_cup", "find": "cup", "tall": [8.0, 22.0], "faces": [], "feeds": {}},
	"terminal": {"label": "The terminal", "blurb": "A computer whose screen shows the council's program.",
		"own": "res://data/props/terminal.prop.json", "find": "computer", "tall": [30.0, 60.0], "faces": ["screen"],
		"feeds": {"lit": "how much of the screen is lit, 0 dark to 1 a panel full of text"}},
	"keyboard": {"label": "The keyboard", "blurb": "The keyboard typed at, before the terminal, its cable coiled into the case.",
		"own": "res://data/props/keyboard.prop.json", "find": "keyboard", "tall": [1.5, 6.0], "faces": [], "feeds": {}},
	"phone": {"label": "A phone", "blurb": "Each of the desk's phones: lifted to the ear, opened, rung, read; its name on its tape.",
		"own": "res://data/props/phone.prop.json", "find": "phone", "tall": [1.5, 4.0], "faces": ["inner", "outer", "tape"],
		"feeds": {"open": "how open its lid is, 0 shut to 1 open"}},
	"radar": {"label": "The radar", "blurb": "The round scope its sweep and blips are drawn on, and its gain knob.",
		"own": "res://data/props/radar.prop.json", "find": "radar", "tall": [18.0, 45.0], "faces": ["scope"],
		"feeds": {"gain": "the gain the script turns it to, one to ten"}},
	"receiver": {"label": "The receiver", "blurb": "The shortwave receiver: its dial at the frequency, the needle swinging with the static, the scope's trace.",
		"own": "res://data/props/receiver.prop.json", "find": "radio", "tall": [18.0, 45.0], "faces": ["dial", "scope"],
		"feeds": {"signal": "how strong what it hears is, 0 to 1"}},
	"printer": {"label": "The printer", "blurb": "The printer whose paper feeds off the desk's end, its head running across as it prints.",
		"own": "res://data/props/printer.prop.json", "find": "printer", "tall": [8.0, 25.0], "faces": [],
		"feeds": {"head": "where the head is across its rail, -0.5 to 0.5"}},
	"feed": {"label": "The security monitor", "blurb": "The little monitor the security cameras' pictures play on.",
		"own": "res://data/props/security_monitor.prop.json", "find": "monitor", "tall": [12.0, 35.0], "faces": ["screen"],
		"feeds": {"glow": "how brightly its picture lights the desk"}},
	"satellite": {"label": "The satellite's monitor", "blurb": "The flat monitor on its arm, the view straight down from orbit on it.",
		"own": "res://data/props/flat_monitor.prop.json", "find": "monitor", "tall": [12.0, 35.0], "faces": ["screen"],
		"feeds": {"glow": "how brightly its picture lights the desk"}},
	"tv": {"label": "The television", "blurb": "The small television: a live picture of the desk, a clip, static.",
		"own": "res://data/props/tv.prop.json", "find": "television", "tall": [20.0, 58.0], "faces": ["screen"],
		"feeds": {"glow": "how brightly its picture lights the desk"}},
	"tv_stand": {"label": "The television's stand", "blurb": "What the television stands on, high enough to be seen over the radar.",
		"own": "res://data/props/tv_stand.prop.json", "find": "crate", "tall": [15.0, 35.0], "faces": [], "feeds": {}},
	"lamp": {"label": "The lamp", "blurb": "The desk lamp, its light on the keyboard, switched off by the script's lamp.",
		"own": "res://data/props/lamp.prop.json", "find": "lamp", "tall": [30.0, 60.0], "faces": [],
		"feeds": {"lit": "how much of its light is on, 0 to 1"}},
	"switch": {"label": "The switch box", "blurb": "The switch thrown to GOOD or BAD.",
		"own": "res://data/props/switch.prop.json", "find": "switch", "tall": [5.0, 15.0], "faces": [],
		"feeds": {"side": "which way it is thrown, -1 GOOD to 1 BAD"}},
	"handbook": {"label": "The handbook", "blurb": "The fat binder labeled HANDBOOK.",
		"own": "res://data/props/handbook.prop.json", "find": "binder", "tall": [3.0, 12.0], "faces": [], "feeds": {}},
	"stamp": {"label": "The rubber stamp", "blurb": "A rubber stamp beside its pad.",
		"own": "res://data/props/stamp.prop.json", "find": "stamp", "tall": [3.0, 12.0], "faces": [], "feeds": {}},
	"tracker": {"label": "The GPS tracker", "blurb": "A small tracker, its light blinking.",
		"own": "res://data/props/tracker.prop.json", "find": "tracker", "tall": [1.0, 5.0], "faces": [], "feeds": {}},
	"chart": {"label": "The chart", "blurb": "The chart of the council's hours, taped down.",
		"own": "res://data/props/chart.prop.json", "find": "chart", "tall": [0.05, 2.0], "faces": ["chart"], "feeds": {}},
	"clock": {"label": "The flip clock", "blurb": "The clock whose cards turn over to the hour the script tells.",
		"own": "res://data/props/clock.prop.json", "find": "clock", "tall": [4.0, 15.0], "faces": ["cards"], "feeds": {}},
	"tablet": {"label": "The tablet", "blurb": "The tablet picked up and read, its pages on its screen.",
		"own": "res://data/props/tablet.prop.json", "find": "tablet", "tall": [0.5, 3.0], "faces": ["screen"], "feeds": {}},
}
## How many of a role's recipe the Dex draws to choose from.
const DRAWS := 24

static var _owns := {}           # a role's `own` path -> its prop as read ([method own_of])
static var _owns_lock := Mutex.new()


## Role [param role]'s make for [param choice], built ([method Props.build]'s answer, meters: its foot on y = 0, centered, its
## front toward +z) and fitted to the role; [param seed] the scene's own number for it. {} where nothing can be built. Touches no
## tree: a scene builds on a worker.
static func made(role: String, choice: Dictionary, seed: int) -> Dictionary:
	var row: Dictionary = ROLES.get(role, {})
	var kept := choice.has("kept") and not ThingLibrary.read(String(choice["kept"])).is_empty() \
		and fits(role, ThingLibrary.read(String(choice["kept"]))["thing"])
	if not kept and row.has("recipe"):
		return DeskLook.made(String(row["recipe"]), int(choice.get("seed", seed)) if choice.has("recipe") else seed)
	var sp := spec(role, choice, seed)
	if sp.is_empty():
		return {}
	var safe := Props.sanitize({"things": [sp["thing"]], "materials": sp["materials"]}, ["#888888"])
	if (safe["things"] as Array).is_empty():
		return {}
	var t: Dictionary = (safe["things"] as Array)[0]
	var b := Props.build(t, safe["materials"], hash([seed, "made", String(choice["kept"]) if kept else role]))
	# a kept make is fitted to the role; the role's own is built at its own size
	return fitted(b, float(t.get("scale", 1.0)), row.get("tall", []) as Array) if kept else b


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
## 3D view are made from - or {} where there is none. A kept make that cannot play the role ([method fits]) is the role's own.
static func spec(role: String, choice: Dictionary, seed: int) -> Dictionary:
	var row: Dictionary = ROLES.get(role, {})
	if choice.has("kept"):
		var e := ThingLibrary.read(String(choice["kept"]))
		if not e.is_empty() and fits(role, e["thing"]):
			return {"thing": e["thing"], "materials": e["materials"]}
	if row.has("own"):
		var o := own_of(role)
		return {"thing": o["thing"], "materials": o["materials"]} if not o.is_empty() else {}
	var recipe := String(row.get("recipe", role))
	var sp := DeskLook.spec_of(recipe, int(choice.get("seed", seed)) if choice.has("recipe") else seed)
	var things: Array = sp.get("things", []) if sp.get("things") is Array else []
	if things.is_empty():
		return {}
	return {"thing": things[0], "materials": sp.get("materials", {}) if sp.get("materials") is Dictionary else {}}


## The prop role [param role] is shipped as (its `own`), read and bounded once ([method ThingLibrary.sanitized]): `{name, line,
## thing, materials, hash}`, or {} where it has none.
static func own_of(role: String) -> Dictionary:
	var path := String((ROLES.get(role, {}) as Dictionary).get("own", ""))
	if path.is_empty():
		return {}
	_owns_lock.lock()
	if not _owns.has(path):
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
		_owns[path] = ThingLibrary.sanitized(d) if d is Dictionary else {}
	var e: Dictionary = (_owns[path] as Dictionary).duplicate(true)
	_owns_lock.unlock()
	return e


## Whether [param thing] (as written) can play role [param role]: it has every face the scene shows something on.
static func fits(role: String, thing: Dictionary) -> bool:
	var has := faces_of(thing.get("parts", []) if thing.get("parts") is Array else [])
	for f in (ROLES.get(role, {}) as Dictionary).get("faces", []):
		if not has.has(String(f)):
			return false
	return true


## The names of the faces among [param parts] and their groups, as written.
static func faces_of(parts: Array) -> PackedStringArray:
	var out := PackedStringArray()
	for p in parts:
		if not (p is Dictionary):
			continue
		var d: Dictionary = p
		if d.get("parts") is Array:
			out.append_array(faces_of(d["parts"]))
		elif String(d.get("shape", "")) == "face" and d.get("name") is String:
			out.append(String(d["name"]))
	return out


## What [param choice] is called, for role [param role]: the scene's own, a recipe's draw, or the kept prop's name.
static func name_of(role: String, choice: Dictionary) -> String:
	var row: Dictionary = ROLES.get(role, {})
	var noun := String(row.get("label", role)).trim_prefix("The ").trim_prefix("A ")
	if choice.has("kept"):
		return String(choice["kept"])
	if choice.has("recipe"):
		return "%s no. %d" % [noun, int(choice.get("seed", 0))]
	return ("%s drawn for this scene" % noun) if row.has("recipe") else String(row.get("label", role))


## Whether role [param role] has a recipe its makes can be drawn from.
static func drawn(role: String) -> bool:
	return (ROLES.get(role, {}) as Dictionary).has("recipe")


## Whether [param choice] is one role [param role] can be handed ([method valid]): a draw only of a role with a recipe.
static func valid_for(role: String, choice: Variant) -> bool:
	return ROLES.has(role) and valid(choice) and (not (choice as Dictionary).has("recipe") or drawn(role))


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
