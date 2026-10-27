extends RefCounted
class_name TableWork

## TableWork - WORK AT THE TABLE, played: a part of [TableMedium] (next/table_work.md). The set dresser's
## working parts ([Motions]: joints, points, states, what runs all the time, what smokes) and the
## puppeteer's acts (`acts.json` in the episode), posed at every moment of the show.
##
## A PURE FUNCTION OF SHOW TIME, as everything on the table is ([method tick]): a part's turn, a vessel's
## fill, a tool's place are worked out from the time and the schedule, never stepped - so a render, a scrub
## and a tool's picture of the same moment agree. What persists persists by the schedule: an act's end is
## where the next act on the same part begins ([method schedule] keeps each one's `from`).
##
## WHEN EACH ACT RUNS is the reading's ([method schedule]): an act belongs to a BEAT - the intro, a card's
## work (the `work K` mark, [TableActions]), or the close - and runs under that beat's words, in order: each
## from where the last ended, or from the word the reader marked it at (`<!-- act: name -->`,
## [CardReading]); an act that is "under" fills the time its beat leaves it; acts that would run past the
## beat's last word are quickened, never cut. A begun act never moves when the plan is made again as a live
## reading's words arrive ([member _begun]).
##
## NOTHING AN AGENT WROTE RUNS AS CODE: the laws are [Motions]'s closed forms and a formula is [Formula]'s.
## A LIT THING IS NEVER MOVED WHOLE: its flames are the light's, lit where it stood (a track that would is
## refused, and said so).

## The [TableMedium] this is a part of.
var medium: TableMedium

## How long a law that says where a tool is (an aim, a circle) takes to bring it there from where it was,
## at an act's start (seconds): a hand moves the pestle into the bowl before it grinds.
const BLEND_IN := 0.8
## ...lifted on the way as a hand lifts it, over whatever rim it goes into (meters, at the middle of the move).
const BLEND_LIFT := 0.1
## How far above a pressed point its ray starts (meters): above the point, below a vessel's rim.
const PRESS_FROM := 0.06
## A stream's radius where it leaves a lip and where it lands (meters).
const STREAM_R := Vector2(0.0028, 0.0016)
## THE CHECK OF AN ACT ([method check]): the moments it is looked at, the most points of a moving thing tried,
## and how far through the table's top a point may go before it is through it (meters).
const CHECK_STEPS := 24
const CHECK_POINTS := 260
const THROUGH_TOP := 0.002
## A THING'S SHADE ON THE CLOTH FOLLOWS IT ([method _tick_shades]): gone while it is lifted more than this or
## tipped more than this (meters, radians) - set down elsewhere, it lies where it is set; and a moving part
## carries its thing's shade only when it is at least this share of the thing seen from above.
const SHADE_LIFT := 0.003
const SHADE_TIP := 0.05
const SHADE_SHARE := 0.5
## THE CREATURES SEEN AS THEY ARE HEARD ([method Soundscape.seen_calls]): how far into a video their huffs are
## looked for (seconds), and where a huff's puff of smoke rises - past the table's far edge, this far behind it
## (meters) at its nearest and how much further when it is far.
const HUFFS_UNTIL := 3600.0
const HUFF_BEHIND := Vector2(0.06, 0.35)
## A PLACE FOUND THROUGH ANOTHER THING'S MOVES ([method _thing_world]) - a pestle ground round a mortar that is
## itself carried - is followed this many things deep; past it, a thing is where it stood.
const PLACE_DEPTH := 3
## A moving thing within this much of where it was built (meters, radians) is HOME, as it was built ([method check]):
## what it stands in there is the set dresser's, never the act's.
const HOME_NEAR := 0.01
const HOME_TURN := 0.09
## ...and the room it stood in as built, grown this much (meters), is its own slot: a vial set back down into its
## rack goes home through no wall of the rack.
const SLOT_GROW := 0.002
## A thing set down rests this far above what it is set on (meters): on it, never in it.
const SET_GAP := 0.0005
## A loose part let go within this much of its own thing's box (meters) is IN it, and rides it ([method _ridden]).
const RIDE_GROW := 0.01

var things: Array = []        # [{name, node, rest, works: [i], lit, box (the thing's own), mesh (world, lazily)}]
var works: Array = []         # [{thing, name, node, w (Props._worker's work), kind, mats, color, glow}]
## A PART WITH COPIES IS ONE PART to the puppeteer (a stack of slips, a bed of coals): by its name alone every
## copy is worked - a state on each, a move as one body - and by "name K" its K-th copy alone, in the order they
## were built ([method _part_of]). Each copy had been a part of the same name, and a name found the first: a
## stack's bottom slip lifted alone, into the four above it, and nothing a puppeteer wrote could say otherwise.
var groups: Array = []        # [{thing, name, members: [work index], middle (the copies', in the first's space)}]
var _group_of := {}           # work index -> its group, for a copy
var acts: Array = []          # the episode's acts, made safe (Motions.sanitize_acts)
var notes := PackedStringArray()
var runs: Array = []          # when each act runs: [{i, t0, t1}]
var _chan := {}               # channel -> [{t0, t1, track, from, end, i}] in order of t0
var _rest := {}               # channel -> its value before anything acts on it
var _runs_of := {}            # channel -> the laws its part follows all the time
var _plumes: Array = []
var _streams: Array = []
var _air = null               # the acts' cue bursts (Effects.Air), or null
var _cues: Array = []         # [{act, at, every, where, name}]
var _liquids: Array = []      # every liquid's material on the table: its surface follows show time
var _huffs: Array = []        # the creatures' huffs, heard and seen ([method Soundscape.seen_calls])
var _soft := {}               # work index -> true: a part that changes (fills, grows, comes and goes) or is a liquid -
                              # what a tool goes into, never a surface it is pressed onto or kept out of
var _root: Node3D
var _begun := {}              # act name -> [t0, t1]: begun, and never moved again
var _plan_key := ""
var _spot := Vector3.INF      # the work's spot, once found ([method work_spot])
var _depth := 0               # how deep a place is being found through another thing's moves ([method _thing_world])


# --- building -----------------------------------------------------------------------------------

## A NEW TABLE: everything the last one worked is let go.
func clear() -> void:
	if _root != null and is_instance_valid(_root):
		_root.queue_free()
	_root = null
	if _air != null:
		_air.release()
	_air = null
	things = []
	works = []
	groups = []
	_group_of = {}
	acts = []
	notes = PackedStringArray()
	runs = []
	_chan = {}
	_rest = {}
	_runs_of = {}
	_plumes = []
	_streams = []
	_cues = []
	_liquids = []
	_huffs = []
	_soft = {}
	_begun = {}
	_plan_key = ""
	_spot = Vector3.INF
	_depth = 0


## Thing [param t], built as [param b] ([method Props.build]) and stood as [param node]: its working parts
## kept, and its liquids, so they can be worked ([method TableThings.put] hands every thing here) - and its
## shade on the cloth ([param shades]: the contact shade and the slab that casts its foot's), which goes with it.
func take(t: Dictionary, b: Dictionary, node: Node3D, shades: Array = []) -> void:
	var ti := things.size()
	var held: Array = []
	for sh in shades:
		if sh is Node3D:
			held.append({"node": sh, "at": (sh as Node3D).position})
	var entry := {"name": String(t.get("name", "")), "node": node, "rest": node.transform, "works": [],
		"lit": not (b.get("wicks", []) as Array).is_empty(), "box": b.get("size", AABB()), "mesh": null,
		"meshes": b.get("meshes", []), "shades": held}
	for m in b.get("meshes", []):
		var mat := (m as MeshInstance3D).material_override as ShaderMaterial if m is MeshInstance3D else null
		var kd: Variant = mat.get_shader_parameter("kind") if mat != null else null
		if kd != null and int(kd) == 13:
			_liquids.append(mat)
	for wv in b.get("works", []):
		var wd: Dictionary = wv
		var w: Dictionary = wd["work"]
		var node_w: Node3D = wd["node"]
		var mats: Array = []
		for mi in node_w.find_children("*", "MeshInstance3D", true, false):
			var mat := (mi as MeshInstance3D).material_override as ShaderMaterial
			if mat != null:
				mats.append(mat)
		var color := Color(0.5, 0.5, 0.5)
		if not mats.is_empty() and (mats[0] as ShaderMaterial).get_shader_parameter("color") is Color:
			color = (mats[0] as ShaderMaterial).get_shader_parameter("color")
		var wi := works.size()
		works.append({"thing": ti, "name": String(w.get("name", "")), "node": node_w, "w": w,
			"kind": String((w.get("joint", {}) as Dictionary).get("kind", "")), "mats": mats, "color": color})
		(entry["works"] as Array).append(wi)
	var by_name := {}
	for wi in entry["works"]:
		var nm := String((works[wi] as Dictionary)["name"]).to_lower()
		if not nm.is_empty():
			if not by_name.has(nm):
				by_name[nm] = []
			(by_name[nm] as Array).append(wi)
	for nm in by_name:
		var members: Array = by_name[nm]
		if members.size() > 1:
			for wi in members:
				_group_of[wi] = groups.size()
			groups.append({"thing": ti, "name": String((works[members[0]] as Dictionary)["name"]), "members": members, "middle": Vector3.ZERO})
	things.append(entry)


## THE ACTS of this episode ([param raw], `acts.json` as parsed, or null) for a reading of [param beats]
## beats (a card's each, or a show's with no cards), made safe and found on the table - and everything the table works by itself: what runs, what
## smokes, the liquids' surfaces, and a puff of smoke past the far edge wherever the place's creatures
## ([param sound]'s, [Soundscape]) are heard to huff. Called once every thing stands.
func build(raw: Variant, beats: int, sound: Dictionary = {}) -> void:
	_root = Node3D.new()
	_root.name = "Work"
	medium._root3.add_child(_root)
	var made := Motions.sanitize_acts(raw if raw != null else {}, beats)
	notes = made["notes"]
	acts = []
	for a in made["acts"]:
		var act: Dictionary = (a as Dictionary).duplicate(true)
		var kept: Array = []
		for t in act["tracks"]:
			var tr: Dictionary = t
			var why := _resolve(tr)
			if not why.is_empty():
				notes.append("%s: %s" % [String(act["name"]), why])
				continue
			# ...a part's copies each worked alike - a move moves them as one, on their group's own channel
			for cw in tr.get("_copies", []):
				var c := tr.duplicate(true)
				c.erase("_copies")
				c["_wi"] = int(cw)
				c["_ch"] = "w%d:%s" % [int(cw), String(tr["_ch"]).get_slice(":", 1)]
				kept.append(c)
			tr.erase("_copies")
			kept.append(tr)
		if kept.is_empty():
			notes.append("%s: none of its tracks found anything on the table to move" % String(act["name"]))
			continue
		act["tracks"] = kept
		acts.append(act)
	# WHAT EACH PART IS BEFORE ANYTHING ACTS ON IT, and what it follows all the time
	for wi in works.size():
		var wk: Dictionary = works[wi]
		var w: Dictionary = wk["w"]
		var start: Dictionary = w.get("start", {})
		_rest["w%d:fill" % wi] = float(start.get("fill", 1.0))
		_rest["w%d:grow" % wi] = float(start.get("grow", 1.0))
		_rest["w%d:shown" % wi] = float(start.get("shown", 1.0))
		_rest["w%d:glow" % wi] = float(start.get("glow", 0.0))
		_rest["w%d:emit" % wi] = float(start.get("emit", 1.0))
		_rest["w%d:boil" % wi] = float(start.get("boil", 0.0))
		_rest["w%d:angle" % wi] = 0.0
		_rest["w%d:offset" % wi] = 0.0
		_rest["w%d:tint" % wi] = Color.html(String(start["tint"])) if start.has("tint") else wk["color"]
		for law in w.get("runs", []):
			var ch := _run_channel(wi, law as Dictionary)
			if ch.is_empty():
				continue
			if not _runs_of.has(ch):
				_runs_of[ch] = []
			(_runs_of[ch] as Array).append(law)
		if w.get("emits") is Dictionary:
			_plumes.append(_plume(wi, w["emits"]))
	# A PART THAT RUNS IS NOT TURNED AGAIN by an act (the first real puppeteer wrote a clock's three hands into every
	# one of its 31 acts, where its set dresser's had not been kept): a turn on it would run it twice as fast
	for a in acts:
		var kept: Array = []
		for t in a["tracks"]:
			var tr: Dictionary = t
			if String(tr["law"]) in ["turn", "clock"] and _runs_of.has(String(tr.get("_ch", ""))):
				notes.append("%s: %s already runs all the time (its `runs`) - its %s is left out" % [String(a["name"]), _part_label(int(tr["_wi"])), String(tr["law"])])
				continue
			kept.append(tr)
		a["tracks"] = kept
	acts = acts.filter(func(a: Dictionary) -> bool: return not (a["tracks"] as Array).is_empty())
	# WHAT A TOOL GOES INTO: a part that changes - in an act or from its start - or a liquid
	for a in acts:
		for t in a["tracks"]:
			var tr: Dictionary = t
			if String(tr["law"]) == "pour":
				_soft[int(tr["_from"])] = true
				_soft[int(tr["_into"])] = true
			elif String(tr.get("_ch", "")).get_slice(":", 1) in ["fill", "grow", "shown"]:
				_soft[int(tr["_wi"])] = true
	for wi in works.size():
		var start: Dictionary = ((works[wi] as Dictionary)["w"] as Dictionary).get("start", {})
		if start.has("fill") or start.has("grow") or start.has("shown"):
			_soft[wi] = true
		for m in (works[wi] as Dictionary)["mats"]:
			var kd: Variant = (m as ShaderMaterial).get_shader_parameter("kind")
			if kd != null and int(kd) == 13:
				_soft[wi] = true
	for ti in things.size():
		_rest["t%d:pose" % ti] = _world_rest_thing(ti)
	for wi in works.size():
		_rest["w%d:pose" % wi] = _world_of((works[wi] as Dictionary)["node"])
	# A PART'S COPIES MOVED AS ONE, from where the first stands, about the middle of them all
	for gi in groups.size():
		var g: Dictionary = groups[gi]
		var x0 := _world_of((works[int((g["members"] as Array)[0])] as Dictionary)["node"])
		_rest["g%d:pose" % gi] = x0
		var box := AABB()
		for k in (g["members"] as Array).size():
			var wk: Dictionary = works[int((g["members"] as Array)[k])]
			var b: AABB = (x0.affine_inverse() * _world_of(wk["node"])) * ((wk["w"] as Dictionary).get("box", AABB()) as AABB)
			box = b if k == 0 else box.merge(b)
		g["middle"] = box.get_center()
	# THE STREAMS a pour makes, and THE BURSTS an act's cues throw
	var fxs: Array = []
	var moments: Array = []
	for a in acts:
		for t in a["tracks"]:
			if String((t as Dictionary)["law"]) == "pour":
				(t as Dictionary)["_stream"] = _streams.size()
				_streams.append(_stream(t as Dictionary))
		for ci in (a["cues"] as Array).size():
			var c: Dictionary = (a["cues"] as Array)[ci]
			var nm := "cue %d" % _cues.size()
			var fx: Dictionary = (c["burst"] as Dictionary).duplicate(true)
			fx["kind"] = "burst"
			fx["name"] = nm
			fx["on"] = nm
			fxs.append(fx)
			moments.append(nm)
			_cues.append({"act": String(a["name"]), "cue": c, "name": nm})
	# THE CREATURES, SEEN as they are heard: their huffs' times from the sound's own plan
	_huffs = Soundscape.seen_calls(sound, medium._plan.seed_value, 0.0, HUFFS_UNTIL) if sound.get("creatures") is Array else []
	if not _huffs.is_empty():
		fxs.append({"kind": "burst", "name": "huffs", "on": "huffs", "look": "smoke", "count": 10, "size": 24.0,
			"speed": 0.35, "spread": 35.0, "life": 2.6, "glow": 0.0, "colors": ["#8f8b86", "#a6a29c"]})
		moments.append("huffs")
	if not fxs.is_empty():
		var made_fx := Effects.sanitize(fxs, [], [], moments)
		if not made_fx.is_empty():
			_air = Effects.build(made_fx, medium._air_stage(), hash([medium._plan.seed_value, "work cues"]))
			_root.add_child(_air.root)
	_plan_key = ""
	plan_cues()


## Where [param track]'s law acts, found on the table: its `_ch` (a channel - `w3:angle`, `t1:pose`...),
## or for a pour its two vessels' fills - "" when found, else why not.
func _resolve(track: Dictionary) -> String:
	var law := String(track["law"])
	if law == "pour":
		var a := _work_named(String(track["from"]))
		var b := _work_named(String(track["into"]))
		if a < 0 or b < 0:
			return "pour names \"%s\" and \"%s\" - each must be a thing's named part, \"thing/part\"" % [String(track["from"]), String(track["into"])]
		track["_from"] = a
		track["_into"] = b
		return ""
	var ti := _thing_named(String(track["thing"]))
	if ti < 0:
		return "no thing on the table is called \"%s\"" % String(track["thing"])
	var part := String(track.get("part", ""))
	var pose := law in ["circle", "aim", "carry"] or (law == "path" and _path_moves(track))
	var state := String(track.get("state", ""))
	if part.is_empty():
		if not pose:
			# a state with no part: every part of the thing that can take it
			return "a %s names no part of \"%s\" - name one (its parts: %s)" % [law, String(track["thing"]), _part_names(ti)]
		if bool((things[ti] as Dictionary)["lit"]):
			return "\"%s\" holds a flame, which stays where it was lit: it is never moved whole" % String(track["thing"])
		track["_ch"] = "t%d:pose" % ti
		track["_ti"] = ti
		return ""
	var found := _part_of(ti, part)
	var wi := int(found["wi"])
	var gi := int(found["gi"])
	if wi < 0:
		return "\"%s\" has no part called \"%s\" that works (its working parts: %s)" % [String(track["thing"]), part, _part_names(ti)]
	var kind := String((works[wi] as Dictionary)["kind"])
	track["_wi"] = wi
	if gi >= 0:
		track["_copies"] = ((groups[gi] as Dictionary)["members"] as Array).slice(1)
	if not state.is_empty():
		track["_ch"] = "w%d:%s" % [wi, state]
		return ""
	if pose:
		if kind != "free":
			track.erase("_copies")
			return "\"%s\" of \"%s\" is %s, not free: it cannot be carried, aimed or circled (move the whole thing, or give the part a free joint)" % [part, String(track["thing"]), "a " + kind if not kind.is_empty() else "not jointed"]
		if gi >= 0:
			track.erase("_copies")
			track["_ch"] = "g%d:pose" % gi
			track["_gi"] = gi
		else:
			track["_ch"] = "w%d:pose" % wi
		return ""
	match kind:
		"hinge":
			track["_ch"] = "w%d:angle" % wi
		"slide":
			track["_ch"] = "w%d:offset" % wi
		_:
			return "\"%s\" of \"%s\" has no hinge or slide for a %s to turn, and the track names no `state`" % [part, String(track["thing"]), law]
	return ""


## Whether a path's keys move a free part (`by`, `turn`) rather than a number.
static func _path_moves(track: Dictionary) -> bool:
	for k in track.get("keys", []):
		if (k as Dictionary).has("by") or (k as Dictionary).has("turn"):
			return true
	return false


## The channel a part's running law [param law] drives, or "".
func _run_channel(wi: int, law: Dictionary) -> String:
	if law.has("state"):
		return "w%d:%s" % [wi, String(law["state"])]
	match String((works[wi] as Dictionary)["kind"]):
		"hinge":
			return "w%d:angle" % wi
		"slide":
			return "w%d:offset" % wi
	return ""


func _thing_named(name: String) -> int:
	var low := name.strip_edges().to_lower()
	for i in things.size():
		if String((things[i] as Dictionary)["name"]).to_lower() == low:
			return i
	for i in things.size():
		if String((things[i] as Dictionary)["name"]).to_lower().contains(low) and not low.is_empty():
			return i
	return -1


## Thing [param ti]'s working part called [param part]: `{wi, gi}` - a part with copies named alone is all of
## them ([member groups]: `gi` its group, `wi` its first copy), and "name K" (or "name #K") its K-th copy alone,
## `gi` -1; `wi` -1 when it names none.
func _part_of(ti: int, part: String) -> Dictionary:
	var low := part.strip_edges().to_lower()
	for wi in (things[ti] as Dictionary)["works"]:
		if String((works[wi] as Dictionary)["name"]).to_lower() == low:
			return {"wi": wi, "gi": int(_group_of.get(wi, -1))}
	var j := low.length()
	while j > 0 and low.unicode_at(j - 1) >= 48 and low.unicode_at(j - 1) <= 57:
		j -= 1
	if j > 0 and j < low.length():
		var k := int(low.substr(j))
		var base := low.substr(0, j).strip_edges().trim_suffix("#").strip_edges()
		for g in groups:
			var members: Array = (g as Dictionary)["members"]
			if int(g["thing"]) == ti and String(g["name"]).to_lower() == base and k >= 1 and k <= members.size():
				return {"wi": int(members[k - 1]), "gi": -1}
	return {"wi": -1, "gi": -1}


func _work_of(ti: int, part: String) -> int:
	return int(_part_of(ti, part)["wi"])


## Work [param wi]'s name as a puppeteer writes it: a copy's with its number.
func _part_label(wi: int) -> String:
	var nm := String((works[wi] as Dictionary)["name"])
	var gi := int(_group_of.get(wi, -1))
	return nm if gi < 0 else "%s %d" % [nm, ((groups[gi] as Dictionary)["members"] as Array).find(wi) + 1]


## Whether work [param wi] is moved in any act: on its own, or with its copies.
func _part_moves(wi: int) -> bool:
	return _chan.has("w%d:pose" % wi) or _chan.has("g%d:pose" % int(_group_of.get(wi, -1)))


## "thing/part" -> the part's work, or -1.
func _work_named(s: String) -> int:
	var at := s.rfind("/")
	if at < 0:
		return -1
	var ti := _thing_named(s.substr(0, at))
	return _work_of(ti, s.substr(at + 1)) if ti >= 0 else -1


func _part_names(ti: int) -> String:
	var out := PackedStringArray()
	for wi in (things[ti] as Dictionary)["works"]:
		var n := String((works[wi] as Dictionary)["name"])
		if not n.is_empty():
			out.append(n)
	return ", ".join(out) if not out.is_empty() else "none"


# --- where things are ---------------------------------------------------------------------------------

## [param node]'s transform in the table's own space - walked up by hand, as a table built aside is not
## in the tree ([member TableMedium.aside]).
func _world_of(node: Node3D) -> Transform3D:
	var xf := node.transform
	var p := node.get_parent()
	while p != null and p != medium._root3 and p is Node3D:
		xf = (p as Node3D).transform * xf
		p = p.get_parent()
	return xf


## Where [param node]'s parent is in the table's space.
func _parent_world(node: Node3D) -> Transform3D:
	var p := node.get_parent()
	return _world_of(p as Node3D) if p is Node3D and p != medium._root3 else Transform3D.IDENTITY


## Thing [param ti] as it stood, in the table's space.
func _world_rest_thing(ti: int) -> Transform3D:
	var th: Dictionary = things[ti]
	return _parent_world(th["node"]) * (th["rest"] as Transform3D)


## A PLACE A LAW NAMES ([method Motions._place]) in meters in the table's space: [x, y, z] centimeters from the
## middle of the reading, the work's spot (`work`, [method work_spot]), or a thing's point by name
## (`thing.point`; `top`, `middle` and `base` of any thing too) WHERE THE THING IS AT SHOW TIME [param T] - a
## mortar carried to the middle is ground in there ([method _thing_world]); where it stood, for NAN.
## [param fallback] when it names nothing on the table.
func place_of(v: Variant, fallback: Vector3, T := NAN) -> Vector3:
	if v is Vector3:
		var c: Vector3 = v
		return Vector3(Tables.ORIGIN.x + c.x * 0.01, c.y * 0.01, Tables.ORIGIN.y + c.z * 0.01)
	if not (v is String):
		return fallback
	var s := String(v)
	if Motions.SPOTS.has(s.strip_edges().to_lower()):
		return work_spot()
	var at := s.rfind(".")
	if at < 0:
		return fallback
	var ti := _thing_named(s.substr(0, at))
	if ti < 0:
		return fallback
	var pt := s.substr(at + 1).strip_edges().to_lower()
	for wi in (things[ti] as Dictionary)["works"]:
		var pts: Dictionary = ((works[wi] as Dictionary)["w"] as Dictionary).get("points", {})
		for k in pts:
			if String(k).to_lower() == pt:
				return _work_world(int(wi), T) * (pts[k] as Vector3)
	var th: Dictionary = things[ti]
	var box: AABB = _thing_world(ti, T) * (th["box"] as AABB)
	var mid := box.get_center()
	match pt:
		"top":
			return Vector3(mid.x, box.end.y, mid.z)
		"base":
			return Vector3(mid.x, box.position.y, mid.z)
	return mid


## THE WORK'S SPOT ([method TablePlan.work_spot]): the middle of the picture, clear of the cards' places and of
## everything standing on the table - where a thing is brought to be worked. Found once.
func work_spot() -> Vector3:
	if _spot != Vector3.INF:
		return _spot
	var feet: Array = []
	for ti in things.size():
		var th: Dictionary = things[ti]
		var b: AABB = _world_rest_thing(ti) * (th["box"] as AABB)
		feet.append(Rect2(b.position.x, b.position.z, b.size.x, b.size.z))
	_spot = medium._plan.work_spot(medium._top_o, feet)
	return _spot


## THING [param ti] WHERE IT IS AT SHOW TIME [param T], in the table's space: moved by the work, or as it stood
## (for NAN, or a thing nothing moves). A pure function of the schedule - never the node as it was last posed.
func _thing_world(ti: int, T: float) -> Transform3D:
	var ch := "t%d:pose" % ti
	if is_nan(T) or not _chan.has(ch) or _depth > PLACE_DEPTH:
		return _world_rest_thing(ti)
	_depth += 1
	var x: Transform3D = value(ch, T)
	_depth -= 1
	return x


## WORK [param wi] WHERE IT IS AT SHOW TIME [param T]: a free part moved by the work where it was moved (riding
## its thing when it was left in it, [method _ridden]), any other part where its thing has it.
func _work_world(wi: int, T: float) -> Transform3D:
	var wk: Dictionary = works[wi]
	var ti := int(wk["thing"])
	if not is_nan(T) and _depth <= PLACE_DEPTH and String(wk["kind"]) == "free":
		var own := "w%d:pose" % wi
		var gch := "g%d:pose" % int(_group_of.get(wi, -1))
		if _chan.has(own) or _chan.has(gch):
			_depth += 1
			var x: Transform3D = value(own, T) if _chan.has(own) else _rest[own]
			if _chan.has(gch):
				x = (value(gch, T) as Transform3D) * (_rest[gch] as Transform3D).affine_inverse() * x
			x = _ridden(wi, x, T)
			_depth -= 1
			return x
	return _thing_world(ti, T) * _world_rest_thing(ti).affine_inverse() * (_rest.get("w%d:pose" % wi, _world_of(wk["node"])) as Transform3D)


## A LOOSE PART RIDES ITS THING: a free part let go IN its own thing (a pestle left in its mortar) goes with the
## thing when the thing is moved after - [param x], its place as the work left it, carried as the thing has been
## since; one laid down anywhere else stays where it was laid. While a track holds it, it is where the track has it.
func _ridden(wi: int, x: Transform3D, T: float) -> Transform3D:
	var ti := int((works[wi] as Dictionary)["thing"])
	if not _chan.has("t%d:pose" % ti):
		return x
	var own := "w%d:pose" % wi
	var ch := own if _chan.has(own) else "g%d:pose" % int(_group_of.get(wi, -1))
	var let_go := NAN
	for e in _chan.get(ch, []):
		if float((e as Dictionary)["s0"]) > T:
			break
		if T < float((e as Dictionary)["s1"]):
			return x
		let_go = float((e as Dictionary)["s1"])
	if is_nan(let_go):
		return x
	var then := _thing_world(ti, let_go)
	var now := _thing_world(ti, T)
	if then.is_equal_approx(now):
		return x
	var w: Dictionary = (works[wi] as Dictionary)["w"]
	var mid := then.affine_inverse() * (x * (w.get("middle", Vector3.ZERO) as Vector3))
	if not ((things[ti] as Dictionary)["box"] as AABB).grow(RIDE_GROW).has_point(mid):
		return x
	return now * then.affine_inverse() * x


## A work's own point by name, in its node's space - or its middle.
func _point_local(wi: int, name: String) -> Vector3:
	var w: Dictionary = (works[wi] as Dictionary)["w"]
	var pts: Dictionary = w.get("points", {})
	for k in pts:
		if String(k).to_lower() == name.to_lower():
			return pts[k]
	return w.get("middle", Vector3.ZERO)


## [param p] (meters, the table's space) kept on thing [param target]'s surface below it, [param gap]
## centimeters above it - the thing where it is at show time [param T], its surface carried there - or as it was
## where nothing is below it.
func _press(target: String, p: Vector3, gap: float, T := NAN) -> Vector3:
	var ti := _thing_named(target)
	if ti < 0:
		return p
	var tm := _mesh_of(ti)
	if tm == null:
		return p
	# the ray in the thing's own place as it stood, where its surface was taken
	var back := _world_rest_thing(ti) * _thing_world(ti, T).affine_inverse()
	var hit: Dictionary = tm.intersect_ray(back * (p + Vector3(0.0, PRESS_FROM, 0.0)), (back.basis * Vector3.DOWN).normalized())
	if hit.is_empty():
		return p
	var y := (back.affine_inverse() * (hit["position"] as Vector3)).y
	return Vector3(p.x, y + gap * 0.01, p.z)


## Whether [param mi] is part of something a tool goes into ([member _soft]): a heap being ground, a liquid.
func _is_soft(mi: Node) -> bool:
	for wi in _soft:
		var n: Node3D = (works[int(wi)] as Dictionary)["node"]
		if n == mi or n.is_ancestor_of(mi):
			return true
	return false


## Thing [param ti]'s surface AS IT STOOD, for a ray to meet: made once, whatever the work has posed it at since.
func _mesh_of(ti: int) -> TriangleMesh:
	var th: Dictionary = things[ti]
	if th["mesh"] != null:
		return th["mesh"]
	var faces := PackedVector3Array()
	var to_rest := _world_rest_thing(ti) * _world_of(th["node"]).affine_inverse()
	# ...without its loose parts, which are what is pressed onto it (a mortar's own pestle)
	var loose: Array = []
	for wi in th["works"]:
		if String((works[wi] as Dictionary)["kind"]) == "free":
			loose.append((works[wi] as Dictionary)["node"])
	for m in th["meshes"]:
		var mi := m as MeshInstance3D
		if mi == null or mi.mesh == null or _is_soft(mi):
			continue
		if loose.any(func(n: Node3D) -> bool: return n == mi or n.is_ancestor_of(mi)):
			continue
		var xf := to_rest * _world_of(mi)
		for q in mi.mesh.get_faces():
			faces.append(xf * q)
	if faces.is_empty():
		return null
	var tm := TriangleMesh.new()
	tm.create_from_faces(faces)
	th["mesh"] = tm
	return tm


# --- when each act runs ---------------------------------------------------------------------------

## WHEN EACH ACT RUNS, from the reading's placed schedule [param sched] (`[{a, t0, s}]`, [method
## ReadingFollower.place]), its walk [param parse] ([method CardReading.parse]) and when each spoken word was
## said ([param said0], [param said1] - [constant ReadingFollower.NO_TIME] where not yet - else [param est],
## a word's estimated time). [param now]: what has begun by then never moves.
func schedule(sched: Array, parse: Dictionary, said0: PackedFloat32Array, said1: PackedFloat32Array,
		est: PackedFloat32Array, now: float) -> void:
	if acts.is_empty():
		return
	var actions: Array = parse.get("actions", [])
	var n_spoken := (parse.get("spoken", PackedStringArray()) as PackedStringArray).size()
	var w0 := func(si: int) -> float:
		if si < 0 or si >= n_spoken:
			return INF
		if si < said0.size() and said0[si] != ReadingFollower.NO_TIME:
			return said0[si]
		return est[si] if si < est.size() else INF
	var w1 := func(si: int) -> float:
		if si < 0 or si >= n_spoken:
			return INF
		if si < said1.size() and said1[si] != ReadingFollower.NO_TIME:
			return said1[si]
		return (est[si] + 0.4) if si < est.size() else INF
	# EACH BEAT'S SPAN: from its mark's move to the last word of the passage after it
	var placed := {}
	for e in sched:
		placed[(e as Dictionary)["a"]] = e
	var spans := {}
	for i in actions.size():
		var a: Dictionary = actions[i]
		var kind := String(a["kind"])
		var beat := ""
		if not TableActions.source_of(kind).is_empty():
			beat = "intro"
		elif kind == "work":
			beat = str(int(a.get("card", 0)))
		elif kind == "spread":
			beat = "close"
		if beat.is_empty():
			continue
		var si0 := int(a["after"])
		var si1 := int((actions[i + 1] as Dictionary)["after"]) if i + 1 < actions.size() else n_spoken
		# IT BEGINS WHEN ITS MARK'S MOVE IS DONE - the shuffle begun, the card laid, the spread settled - or,
		# before the mark is placed, never
		var e: Dictionary = placed.get(a, {})
		var b0 := INF
		if not e.is_empty():
			b0 = float(e["t0"]) + float(a["dur"]) * float(e["s"])
		var b1 := float(w1.call(si1 - 1)) if si1 > si0 else b0 + 2.0
		spans[beat] = Vector2(b0, maxf(b1, b0 + 1.0))
	var cued := {}
	for c in parse.get("cues", []):
		cued[String((c as Dictionary)["name"])] = float(w0.call(int((c as Dictionary)["si"])))
	var out: Array = []
	for beat in spans:
		var span: Vector2 = spans[beat]
		var mine: Array = []
		for i in acts.size():
			if String((acts[i] as Dictionary)["beat"]) == String(beat):
				mine.append(i)
		if mine.is_empty() or span.x == INF:
			continue
		# what the fixed ones take, quickened to fit the beat when they would run past its last word
		var fixed := 0.0
		var unders := 0
		for i in mine:
			if bool((acts[i] as Dictionary)["under"]):
				unders += 1
			else:
				fixed += float((acts[i] as Dictionary)["length"])
		var room := span.y - span.x
		var quick := 1.0 if fixed <= 0.0 or fixed + 1.5 * float(unders) <= room else maxf(0.5, (room - 1.5 * float(unders)) / fixed)
		var t := span.x
		for j in mine.size():
			var i: int = mine[j]
			var a: Dictionary = acts[i]
			var nm := String(a["name"])
			var t0 := t
			if cued.has(nm) and float(cued[nm]) < INF:
				t0 = maxf(float(cued[nm]), span.x)
			var t1 := t0 + float(a["length"]) * quick
			if bool(a["under"]):
				# the time the beat leaves it: up to the next act the reader cued, or the beat's end less what
				# the acts after it take
				var until := span.y
				var after := 0.0
				for k in range(j + 1, mine.size()):
					var b: Dictionary = acts[mine[k]]
					if cued.has(String(b["name"])) and float(cued[String(b["name"])]) < INF:
						until = minf(until, float(cued[String(b["name"])]))
						break
					after += 1.5 if bool(b["under"]) else float(b["length"]) * quick
				t1 = maxf(t0 + 1.0, until - after)
			if _begun.has(nm):
				t0 = float((_begun[nm] as Array)[0])
				if not bool(a["under"]):
					t1 = float((_begun[nm] as Array)[1])
			if t0 <= now:
				_begun[nm] = [t0, t1]
			out.append({"i": i, "t0": t0, "t1": t1})
			t = t1
	out.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return float(x["t0"]) < float(y["t0"]))
	var key := str(out.map(func(r: Dictionary) -> Vector3: return Vector3(float(r["i"]), float(r["t0"]), float(r["t1"]))))
	if key == _plan_key:
		return
	_plan_key = key
	runs = out
	_timelines()


## A SCHEDULE OF ITS OWN, for a picture of the work with no reading under it ([TablePreview]): every act
## one after another from [param from] (seconds), at its own length, beat by beat in the reading's order.
## `{name: [t0, t1]}`.
func rehearse(from: float) -> Dictionary:
	var order: Array = ["intro"]
	var n := 0
	for a in acts:
		if String((a as Dictionary)["beat"]).is_valid_int():
			n = maxi(n, int((a as Dictionary)["beat"]))
	for k in range(1, n + 1):
		order.append(str(k))
	order.append("close")
	var out: Array = []
	var times := {}
	var t := from
	for beat in order:
		for i in acts.size():
			var a: Dictionary = acts[i]
			if String(a["beat"]) != String(beat):
				continue
			var len := Motions.UNDER_GUESS if bool(a["under"]) else float(a["length"])
			out.append({"i": i, "t0": t, "t1": t + len})
			times[String(a["name"])] = [t, t + len]
			t += len
	runs = out
	_plan_key = "rehearsed %f" % from
	_timelines()
	return times


## EACH CHANNEL'S TIMELINE, from [member runs]: every act's tracks, each with where its channel was as it
## began (`from`) and where it left it (`end`) - the end of one the start of the next. A track holds its
## channel over ITS OWN STRETCH of its act (`s0`..`s1`: its `between`, or a path's first and last keys), so an
## act can carry a thing over, tip it, and carry it back, one track after another on the same part.
func _timelines() -> void:
	_chan = {}
	var items: Array = []
	for r in runs:
		var a: Dictionary = acts[int(r["i"])]
		var t0 := float(r["t0"])
		var t1 := float(r["t1"])
		var order := 0
		for t in a["tracks"]:
			var tr: Dictionary = t
			var w := _window(tr)
			var sides: Array = ["_from", "_into"] if String(tr["law"]) == "pour" else [""]
			for side in sides:
				var ch := ("w%d:fill" % int(tr[side])) if not String(side).is_empty() else String(tr["_ch"])
				items.append({"ch": ch, "side": side, "track": tr, "t0": t0, "t1": t1, "i": int(r["i"]), "order": order,
					"s0": t0 + w.x * (t1 - t0), "s1": t0 + w.y * (t1 - t0)})
			order += 1
	items.sort_custom(func(x: Dictionary, y: Dictionary) -> bool:
		return float(x["s0"]) < float(y["s0"]) or (float(x["s0"]) == float(y["s0"]) and (float(x["t0"]) < float(y["t0"]) or (float(x["t0"]) == float(y["t0"]) and int(x["order"]) < int(y["order"])))))
	# TWICE: an end can lie where another thing has been moved to by then (a pestle ground round a mortar
	# carried to the middle), and the first pass has not yet laid that thing's later moves down
	for pass_i in 2:
		var now := {}
		for it in items:
			var e: Dictionary = it
			var ch := String(e["ch"])
			e.erase("_down")
			e["from"] = now.get(ch, _run_value(ch, float(e["s0"])))
			if String(e.get("side", "")).is_empty():
				e.erase("side")
				e["end"] = _eval(e, float(e["s1"]) - float(e["t0"]), float(e["s1"]))
			else:
				e["end"] = _pour_fill(e["track"], String(e["side"]), float(e["from"]), 1.0)
			now[ch] = e["end"]
			if pass_i == 0:
				_add(ch, e)
	plan_cues()


## The stretch of its act track [param tr] holds its channel over, 0..1: its `between`, a path's keys, or all.
static func _window(tr: Dictionary) -> Vector2:
	if tr.get("between") is Vector2:
		return tr["between"]
	if String(tr["law"]) == "path" and tr.get("keys") is Array and not (tr["keys"] as Array).is_empty():
		var keys: Array = tr["keys"]
		return Vector2(float((keys[0] as Dictionary)["at"]), maxf(float((keys[keys.size() - 1] as Dictionary)["at"]), float((keys[0] as Dictionary)["at"]) + 0.01))
	return Vector2(0.0, 1.0)


func _add(ch: String, entry: Dictionary) -> void:
	if not _chan.has(ch):
		_chan[ch] = []
	(_chan[ch] as Array).append(entry)


## A channel's value with nothing acting on it at show time [param T]: what it started as, under what it runs.
func _run_value(ch: String, T: float) -> Variant:
	var v: Variant = _rest.get(ch, 0.0)
	for law in _runs_of.get(ch, []):
		if v is Color:
			v = Motions.tint(law, v, T, 1.0, T)
		elif v is float:
			v = Motions.scalar(law, float(v), T, 1.0, T)
	return v


## A CHANNEL'S VALUE at show time [param t].
func value(ch: String, t: float) -> Variant:
	var list: Array = _chan.get(ch, [])
	var last: Dictionary = {}
	for e in list:
		if float((e as Dictionary)["s0"]) <= t:
			last = e
		else:
			break
	if last.is_empty():
		return _run_value(ch, t)
	if t >= float(last["s1"]):
		# A PART THAT RUNS GOES ON RUNNING from where an act let it go: a clock set by hand keeps time after
		if last["end"] is float and _runs_of.has(ch):
			return float(last["end"]) + float(_run_value(ch, t)) - float(_run_value(ch, float(last["s1"])))
		return last["end"]
	if last.has("side"):
		return _pour_fill(last["track"], String(last["side"]), float(last["from"]), _pour_s(last["track"], (t - float(last["t0"])) / maxf(float(last["t1"]) - float(last["t0"]), 1e-6)))
	return _eval(last, t - float(last["t0"]), t)


## Entry [param e]'s law at [param tau] seconds into its act (show time [param T]).
func _eval(e: Dictionary, tau: float, T: float) -> Variant:
	var tr: Dictionary = e["track"]
	var d := maxf(float(e["t1"]) - float(e["t0"]), 1e-3)
	var ch := String(tr["_ch"])
	if ch.ends_with(":pose"):
		return _pose(e, tau, d, T)
	if e["from"] is Color:
		return Motions.tint(tr, e["from"], tau, d, T) if String(tr["law"]) == "to" else e["from"]
	return Motions.scalar(tr, float(e["from"]), tau, d, T)


## How far a pour has flowed at [param u] of its act: its `between`, eased.
static func _pour_s(tr: Dictionary, u: float) -> float:
	var w: Vector2 = tr.get("between", Vector2(0.0, 1.0))
	return Motions.eased((u - w.x) / maxf(w.y - w.x, 1e-6))


## A pour's [param side] ("_from" or "_into") vessel's fill, from [param from], [param s] of the way through.
static func _pour_fill(tr: Dictionary, side: String, from: float, s: float) -> float:
	if side == "_from":
		return clampf(from - float(tr["amount"]) * s, 0.0, 1.0)
	return clampf(from + float(tr["gain"]) * s, 0.0, 2.0)


## A POSE at [param tau] of [param d] seconds into its act: where the part or the thing is, in the table's
## space - as a held tool goes, from where it was ([param e]'s `from`).
func _pose(e: Dictionary, tau: float, d: float, T: float) -> Transform3D:
	var tr: Dictionary = e["track"]
	var from: Transform3D = e["from"]
	var ch := String(tr["_ch"])
	var x0: Transform3D = _rest.get(ch, Transform3D.IDENTITY)
	var wi := int(tr.get("_wi", -1))
	var pivot_local := Vector3.ZERO
	if tr.has("_gi"):
		pivot_local = (groups[int(tr["_gi"])] as Dictionary)["middle"]
	elif wi >= 0:
		var w: Dictionary = (works[wi] as Dictionary)["w"]
		pivot_local = (w["joint"] as Dictionary).get("pivot", w.get("middle", Vector3.ZERO)) if w.get("joint") is Dictionary else w.get("middle", Vector3.ZERO)
	var q0 := x0 * pivot_local
	var rel := from * x0.affine_inverse()
	var p_from := rel * q0
	var r_from := rel.basis.orthonormalized()
	var u := clampf(tau / maxf(d, 1e-6), 0.0, 1.0)
	var vars := {"t": tau, "u": u, "d": d, "T": T, "n": 0.0}
	var out := from
	match String(tr["law"]):
		"carry":
			var w: Vector2 = tr["between"]
			var s := Motions.eased((u - w.x) / maxf(w.y - w.x, 1e-6))
			var to := place_of(tr.get("to"), q0, T) + (tr["by"] as Vector3) * 0.01 if tr.has("to") else q0 + (tr["by"] as Vector3) * 0.01
			var r_to := Basis.from_euler((tr["turn"] as Vector3) * (PI / 180.0)) if tr.has("turn") else r_from
			var p := p_from.lerp(to, s) + Vector3(0.0, float(tr["lift"]) * 0.01 * sin(PI * s), 0.0)
			var r := Basis(Quaternion(r_from).slerp(Quaternion(r_to.orthonormalized()), s))
			out = _rebuilt(r, p, q0, x0)
			# SET DOWN on what is under it: how far is found once, where it ends, and taken over the way there
			if tr.get("down", false):
				if not e.has("_down"):
					e["_down"] = _settle(tr, _rebuilt(r_to.orthonormalized(), to, q0, x0), float(e["t0"]) + w.y * d)
				out.origin.y += float(e["_down"]) * s
		"path":
			var keys: Array = tr["keys"]
			var p := p_from
			var r := r_from
			var at := func(i: int) -> Array:
				var k: Dictionary = keys[i]
				var kp := p_from + (k.get("by", Vector3.ZERO) as Vector3) * 0.01
				var kr := Basis.from_euler((k.get("turn", Vector3.ZERO) as Vector3) * (PI / 180.0)) * r_from
				return [kp, kr]
			var first: Array = at.call(0)
			p = first[0]
			r = first[1]
			for i in range(keys.size() - 1):
				var k0: Dictionary = keys[i]
				var k1: Dictionary = keys[i + 1]
				if u >= float(k0["at"]) and u <= float(k1["at"]):
					var s := Motions.eased((u - float(k0["at"])) / maxf(float(k1["at"]) - float(k0["at"]), 1e-6))
					var a: Array = at.call(i)
					var b: Array = at.call(i + 1)
					p = (a[0] as Vector3).lerp(b[0], s)
					r = Basis(Quaternion((a[1] as Basis).orthonormalized()).slerp(Quaternion((b[1] as Basis).orthonormalized()), s))
					break
				if u > float(k1["at"]):
					var b: Array = at.call(i + 1)
					p = b[0]
					r = b[1]
			out = _rebuilt(r, p, q0, x0)
		"circle":
			var c := place_of(tr.get("around"), q0, T)
			var p := Motions.point_at(tr, c, null, q0, tau, d, T)
			if tr.has("press"):
				p = _press(String(tr["press"]), p, float(tr.get("gap", 0.15)), T)
			out = _rebuilt(r_from, p, q0, x0)
		"aim":
			var tip: Dictionary = tr["tip"]
			var grip: Dictionary = tr["grip"]
			var tip_l := _point_local(wi, String(tip["point"])) if wi >= 0 else Vector3.ZERO
			var grip_l := _point_local(wi, String(grip["point"])) if wi >= 0 else Vector3.UP * 0.1
			var a0 := x0 * tip_l
			var g0 := x0 * grip_l
			var A := _end_at(tip, a0, tau, d, T)
			var G := _end_at(grip, g0, tau, d, T)
			var v0 := (g0 - a0).normalized()
			var v := (G - A).normalized()
			var r := Basis(Quaternion(v0, v)) if v0.length() > 0.5 and v.length() > 0.5 and v0.dot(v) > -0.999 else Basis.IDENTITY
			var roll := deg_to_rad(Motions.num(tr.get("roll", 0.0), vars))
			if absf(roll) > 1e-6 and v.length() > 0.5:
				r = Basis(v, roll) * r
			out = Transform3D(r, A - r * a0) * x0
	if String(tr["law"]) in ["aim", "circle"] and tau < BLEND_IN:
		# A HAND BRINGS IT THERE FIRST: from where it was to where the law has it, over the first moment - lifted
		# in an arc, so it goes over a rim rather than through it
		var s := Motions.eased(tau / BLEND_IN)
		var lift := BLEND_LIFT * sin(PI * s) if from.origin.distance_to(out.origin) > 0.02 else 0.0
		out = from.interpolate_with(out, s)
		out.origin.y += lift
	var j := Motions.jitter_of(tr, tau)
	if j != Vector3.ZERO:
		out.origin += j
	return out


## HOW FAR A THING SET DOWN rises or falls to rest on what is under it (carry's `down`, [constant Motions.LAWS]):
## [param tr]'s thing or part, posed [param x], its lowest point brought onto the table's top or onto the highest
## thing under it where that thing is at show time [param T] (meters). The first real puppeteer laid a stopper, a
## lid and a pestle down by hand-worked heights, and was told each passed through the table.
func _settle(tr: Dictionary, x: Transform3D, T: float) -> float:
	var skip := int(tr.get("_ti", -1))
	var box: AABB = (things[skip] as Dictionary)["box"] if skip >= 0 else (((works[int(tr["_wi"])] as Dictionary)["w"] as Dictionary).get("box", AABB()) as AABB)
	var low := INF
	var top := -INF
	var probes: Array = [x * box.get_center()]
	for i in 8:
		var c := x * box.get_endpoint(i)
		low = minf(low, c.y)
		top = maxf(top, c.y)
		probes.append(c)
	var under := 0.0
	for c in probes:
		var from := Vector3((c as Vector3).x, top + 0.02, (c as Vector3).z)
		for tj in things.size():
			if tj == skip:
				continue
			var tm := _mesh_of(tj)
			if tm == null:
				continue
			var back := _world_rest_thing(tj) * _thing_world(tj, T).affine_inverse()
			var hit: Dictionary = tm.intersect_ray(back * from, (back.basis * Vector3.DOWN).normalized())
			if not hit.is_empty():
				var y := (back.affine_inverse() * (hit["position"] as Vector3)).y
				if y < top:
					under = maxf(under, y)
	return under - low + SET_GAP


## A point of an aim ([param end]) where its law has it: round its middle, at its place, or along its keys
## from [param rest] - pressed onto what it names.
func _end_at(end: Dictionary, rest: Vector3, tau: float, d: float, T: float) -> Vector3:
	var c := place_of(end.get("around"), rest, T) if end.has("around") else rest
	var fixed: Variant = place_of(end["at"], rest, T) if end.has("at") else null
	var p := Motions.point_at(end, c, fixed, rest, tau, d, T)
	if end.has("press"):
		p = _press(String(end["press"]), p, float(end.get("gap", 0.15)), T)
	return p


## The world transform of a part turned [param r] and moved so that its rest point [param q0] is at [param p].
static func _rebuilt(r: Basis, p: Vector3, q0: Vector3, x0: Transform3D) -> Transform3D:
	return Transform3D(r, p - r * q0) * x0


# --- posing ---------------------------------------------------------------------------------------

## EVERYTHING THE WORK MOVES, at show time [param t]: whole things, then their parts, then what smokes and
## pours and bursts, and every liquid's surface.
func tick(t: float) -> void:
	if things.is_empty():
		return
	for ti in things.size():
		var ch := "t%d:pose" % ti
		if not _chan.has(ch):
			continue
		var th: Dictionary = things[ti]
		var node: Node3D = th["node"]
		node.transform = _parent_world(node).affine_inverse() * (value(ch, t) as Transform3D)
	for wi in works.size():
		_pose_work(wi, t)
	_tick_shades()
	for p in _plumes:
		_tick_plume(p, t)
	for s in _streams:
		_tick_stream(s, t)
	if _air != null:
		_air.tick(t)
	for m in _liquids:
		(m as ShaderMaterial).set_shader_parameter("show_time", t)


## EACH THING'S SHADE ON THE CLOTH where the thing is now: gone while it is lifted or tipped, under it where it
## is set down - a thing moved whole, or one whose moving part is most of it seen from above (a pestle that is
## its own thing; a mortar's pestle leaves the mortar's shade alone). The one place the work reads back what it
## posed: the shade follows the pose, never the other way.
func _tick_shades() -> void:
	for ti in things.size():
		var th: Dictionary = things[ti]
		var shades: Array = th["shades"]
		var moves := _chan.has("t%d:pose" % ti)
		for wi in th["works"]:
			moves = moves or _part_moves(int(wi))
		if shades.is_empty() or not moves:
			continue
		var rest := _world_rest_thing(ti)
		var now := _world_of(th["node"])
		var box: AABB = th["box"]
		var area := maxf(box.size.x * box.size.z, 1e-8)
		var probe := box.get_center()
		# A FREE PART THAT IS MOST OF THE THING carries the shade as the thing would
		for wi in th["works"]:
			var wk: Dictionary = works[wi]
			if String(wk["kind"]) != "free" or not _part_moves(int(wi)):
				continue
			var wb: AABB = (wk["w"] as Dictionary)["box"]
			if wb.size.x * wb.size.z >= area * SHADE_SHARE:
				now = _world_of(wk["node"])
				rest = _parent_world(wk["node"])
				probe = wb.get_center()
		var p0 := rest * Vector3(probe.x, box.position.y, probe.z)
		var p1 := now * Vector3(probe.x, box.position.y, probe.z)
		var up := (now.basis * Vector3.UP).normalized()
		var shown := p1.y - p0.y < SHADE_LIFT and up.angle_to((rest.basis * Vector3.UP).normalized()) < SHADE_TIP
		var d := Vector3(p1.x - p0.x, 0.0, p1.z - p0.z)
		for sh in shades:
			var n: Node3D = (sh as Dictionary)["node"]
			if not is_instance_valid(n):
				continue
			n.visible = shown
			n.position = ((sh as Dictionary)["at"] as Vector3) + d


## Work [param wi] as it is at [param t]: its joint, its fill and growth, whether it shows, its color and glow.
func _pose_work(wi: int, t: float) -> void:
	var wk: Dictionary = works[wi]
	var w: Dictionary = wk["w"]
	var node: Node3D = wk["node"]
	var base: Vector3 = w.get("base", Vector3.ZERO)
	var fill := float(value("w%d:fill" % wi, t))
	var grow := float(value("w%d:grow" % wi, t))
	var s := Transform3D.IDENTITY
	if not is_equal_approx(fill, 1.0) or not is_equal_approx(grow, 1.0):
		var k := maxf(grow, 0.0005)
		s = Transform3D(Basis.from_scale(Vector3(k, k * maxf(fill, 0.0005), k)), base) * Transform3D(Basis.IDENTITY, -base)
	var j := Transform3D.IDENTITY
	var jt: Dictionary = w.get("joint", {})
	match String(wk["kind"]):
		"hinge":
			var a := deg_to_rad(float(value("w%d:angle" % wi, t)))
			var rg: Variant = jt.get("range")
			if rg is Vector2:
				a = clampf(a, deg_to_rad((rg as Vector2).x), deg_to_rad((rg as Vector2).y))
			var axis: Vector3 = jt["axis"]
			var pv: Vector3 = jt["pivot"]
			var b := Basis(axis, a)
			j = Transform3D(b, pv - b * pv)
		"slide":
			var o := float(value("w%d:offset" % wi, t)) * 0.01
			var rg: Variant = jt.get("range")
			if rg is Vector2:
				o = clampf(o, (rg as Vector2).x * 0.01, (rg as Vector2).y * 0.01)
			j = Transform3D(Basis.IDENTITY, (jt["axis"] as Vector3) * o)
		"free":
			# moved by the work where the work moved it - a copy as its set is moved, from where the set stood,
			# and a part left in its thing riding it ([method _work_world])
			if _chan.has("w%d:pose" % wi) or _chan.has("g%d:pose" % int(_group_of.get(wi, -1))):
				j = _parent_world(node).affine_inverse() * _work_world(wi, t)
	node.transform = j * s
	node.visible = float(value("w%d:shown" % wi, t)) > 0.5 and grow > 0.001 and fill > 0.001
	var mats: Array = wk["mats"]
	if not mats.is_empty():
		var tint: Variant = value("w%d:tint" % wi, t)
		var glow := float(value("w%d:glow" % wi, t))
		var boil := float(value("w%d:boil" % wi, t))
		for m in mats:
			var mat := m as ShaderMaterial
			if tint is Color:
				mat.set_shader_parameter("color", tint)
			mat.set_shader_parameter("glow", glow)
			mat.set_shader_parameter("boil", boil)


# --- what smokes and pours -----------------------------------------------------------------------------

## A PLUME of work [param wi]'s `emits`: a pool of puffs ([constant Motions.MAX_PUFFS] at most), each born in
## turn from its point and rising - in closed form, the k-th puff born at k over twice its rate, and kept
## only when the dice and the part's `emit` say (so how hard it smokes can change and stay a function of time).
func _plume(wi: int, e: Dictionary) -> Dictionary:
	var look: Dictionary = Motions.EMITS[String(e["kind"])]
	var rate := float(e["rate"]) * 2.0
	var life := float(look["life"])
	var n := mini(Motions.MAX_PUFFS, int(ceil(rate * life * 1.25)) + 2)
	var layer := Effects._sprites(n, Effects.SMOKE_SHADER, _root)
	var mat: ShaderMaterial = layer["mat"]
	mat.set_shader_parameter("posed", false)
	mat.set_shader_parameter("shape", int(Effects.SHAPES["puff"]))
	mat.set_shader_parameter("glow", 0.0)
	mat.set_shader_parameter("gravity", Vector3(0.0, 0.03, 0.0))
	mat.set_shader_parameter("drag", 1.2)
	mat.set_shader_parameter("grow", float(look["grow"]))
	mat.set_shader_parameter("waver", 0.012)
	mat.set_shader_parameter("twinkle", 0.0)
	var mm: MultiMesh = layer["mm"]
	var slots := PackedInt64Array()
	slots.resize(n)
	# ...and each puff's birth and life as given it: a headless run's MultiMesh hands back nothing it was given
	var lives := PackedVector2Array()
	lives.resize(n)
	for i in n:
		slots[i] = -1
		lives[i] = Vector2(-1.0e6, 0.01)
		mm.set_instance_custom_data(i, Color(-1.0e6, 0.01, 0.0, 0.0))
	var at := String(e.get("at", ""))
	return {"wi": wi, "e": e, "look": look, "layer": layer, "rate": rate, "life": life, "n": n, "slots": slots, "lives": lives,
		"point": _point_local(wi, at) if not at.is_empty() else Vector3(((works[wi] as Dictionary)["w"]["box"] as AABB).get_center().x,
			((works[wi] as Dictionary)["w"]["box"] as AABB).end.y, ((works[wi] as Dictionary)["w"]["box"] as AABB).get_center().z),
		"color": Color.html(String(e["color"])).srgb_to_linear()}


func _tick_plume(p: Dictionary, t: float) -> void:
	var mm: MultiMesh = (p["layer"] as Dictionary)["mm"]
	var mat: ShaderMaterial = (p["layer"] as Dictionary)["mat"]
	var wind: Dictionary = medium._wind if Winds.blows(medium._wind) else {}
	mat.set_shader_parameter("show_time", t)
	if not wind.is_empty():
		var c := Winds.carried(wind, t)
		var v := Winds.velocity_at(wind, t)
		mat.set_shader_parameter("air_carried", Vector3(c.x, 0.0, c.y))
		mat.set_shader_parameter("air_vel", Vector3(v.x, 0.0, v.y))
	var rate := float(p["rate"])
	var life := float(p["life"])
	var n := int(p["n"])
	var slots: PackedInt64Array = p["slots"]
	var lives: PackedVector2Array = p["lives"]
	var wi := int(p["wi"])
	var hidden := not ((works[wi] as Dictionary)["node"] as Node3D).visible
	var strength := float(value("w%d:emit" % wi, t))
	var from := _world_of((works[wi] as Dictionary)["node"]) * (p["point"] as Vector3)
	var k_hi := int(floor(t * rate))
	var k_lo := maxi(int(ceil((t - life * 1.2) * rate)), k_hi - n + 1)
	var look: Dictionary = p["look"]
	for k in range(k_lo, k_hi + 1):
		var slot := posmod(k, n)
		if slots[slot] == k:
			continue
		slots[slot] = k
		var h := _hash01(k, 1)
		if hidden or h >= strength * 0.5:
			mm.set_instance_custom_data(slot, Color(-1.0e6, 0.01, 0.0, 0.0))
			lives[slot] = Vector2(-1.0e6, 0.01)
			continue
		var born := float(k) / rate
		var side := Vector3(_hash01(k, 2) - 0.5, 0.0, _hash01(k, 3) - 0.5) * 0.02
		var vel := Vector3(side.x, float(look["rise"]) * lerpf(0.7, 1.25, _hash01(k, 4)), side.z)
		var particle := {"born": born, "pos": from + Vector3(_hash01(k, 5) - 0.5, 0.0, _hash01(k, 6) - 0.5) * 0.01, "vel": vel}
		mm.set_instance_transform(slot, Effects.particle_xform(particle, wind))
		mm.set_instance_color(slot, p["color"])
		lives[slot] = Vector2(born, life * lerpf(0.75, 1.2, _hash01(k, 7)))
		mm.set_instance_custom_data(slot, Color(lives[slot].x, lives[slot].y, _hash01(k, 8),
			float(look["size"]) * 0.001 * lerpf(0.7, 1.3, _hash01(k, 9))))
	p["slots"] = slots
	p["lives"] = lives


static func _hash01(k: int, salt: int) -> float:
	var h := hash([k, salt, "puff"])
	return float(h & 0xFFFFFF) / float(0x1000000)


## A POUR'S STREAM: a thin rope of what is poured, from the lip to the surface it falls on, shown while it flows.
func _stream(tr: Dictionary) -> Dictionary:
	var mi := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = STREAM_R.x
	cyl.bottom_radius = STREAM_R.y
	cyl.height = 1.0
	cyl.radial_segments = 10
	mi.mesh = cyl
	var mat := StandardMaterial3D.new()
	var from := int(tr["_from"])
	var c: Color = Color.html(String(tr["color"])) if tr.has("color") else (works[from] as Dictionary)["color"]
	mat.albedo_color = c
	mat.roughness = 0.08
	mat.metallic_specular = 0.7
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visible = false
	_root.add_child(mi)
	return {"track": tr, "node": mi}


func _tick_stream(s: Dictionary, t: float) -> void:
	var tr: Dictionary = s["track"]
	var node: MeshInstance3D = s["node"]
	var list: Array = _chan.get("w%d:fill" % int(tr["_from"]), [])
	var flowing := false
	for e in list:
		if (e as Dictionary)["track"] == tr and t >= float(e["t0"]) and t < float(e["t1"]):
			var u := (t - float(e["t0"])) / maxf(float(e["t1"]) - float(e["t0"]), 1e-6)
			var w: Vector2 = tr.get("between", Vector2(0.0, 1.0))
			flowing = u > w.x + 0.01 and u < w.y - 0.01
	node.visible = flowing
	if not flowing:
		return
	var into := int(tr["_into"])
	var iw: Dictionary = (works[into] as Dictionary)["w"]
	var base: Vector3 = iw.get("base", Vector3.ZERO)
	var land := _world_of((works[into] as Dictionary)["node"]) * Vector3(base.x, (iw["box"] as AABB).end.y, base.z)
	var lip := place_of(tr.get("lip"), _world_of((works[int(tr["_from"])] as Dictionary)["node"]) * (iw.get("middle", Vector3.ZERO) as Vector3), t)
	var dir := lip - land
	var len := dir.length()
	if len < 0.005:
		node.visible = false
		return
	var y := dir / len
	var x := y.cross(Vector3.FORWARD if absf(y.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
	var z := x.cross(y)
	node.transform = Transform3D(Basis(x, y * len, z), (lip + land) * 0.5)


## THE CUES' MOMENTS, when the schedule is made: each burst at its act's moment, at its point as it is then.
func plan_cues() -> void:
	if _air == null:
		return
	var moments := {}
	for c in _cues:
		moments[String(c["name"])] = []
	if not _huffs.is_empty():
		# each where its body is: to its side, past the far edge, further when it is far
		var bounds: AABB = medium._furniture.get("bounds", AABB(Vector3(-0.95, -0.05, -0.4), Vector3(1.9, 0.05, 0.85)))
		var huffs: Array = []
		for h in _huffs:
			var hd: Dictionary = h
			var p := Vector3(bounds.get_center().x + float(hd["side"]) * bounds.size.x * 0.4, 0.03,
				bounds.position.z - lerpf(HUFF_BEHIND.y, HUFF_BEHIND.x, float(hd["near"])))
			huffs.append({"t": float(hd["t"]), "dur": 0.25, "from": "point", "card": -1,
				"path": [[float(hd["t"]), Transform3D(Basis.IDENTITY, p)]]})
		moments["huffs"] = huffs
	for r in runs:
		var a: Dictionary = acts[int(r["i"])]
		for c in _cues:
			if String(c["act"]) != String(a["name"]):
				continue
			var cue: Dictionary = c["cue"]
			var t0 := float(r["t0"])
			var t1 := float(r["t1"])
			var at: Array = []
			if cue.has("every"):
				var step := float(cue["every"])
				var tt := t0 + step * 0.5
				while tt < t1 and at.size() < 60:
					at.append(tt)
					tt += step
			else:
				at.append(lerpf(t0, t1, float(cue["at"])))
			for tt in at:
				var p := place_of(cue["where"], Vector3.ZERO, tt)
				(moments[String(c["name"])] as Array).append({"t": tt, "dur": 0.15, "from": "point", "card": -1,
					"path": [[tt, Transform3D(Basis.IDENTITY, p)]]})
	_air.plan(moments)


# --- telling the agents -----------------------------------------------------------------------------

## THE TABLE'S WORKING PARTS in words, for the puppeteer ([PuppeteerTools]): each thing, whether it may be
## moved whole, and its named parts - their joints, points, states and what they run and emit.
func parts_report() -> String:
	var lines := PackedStringArray()
	var spot := work_spot()
	lines.append("THE WORK'S SPOT, \"work\" in any place a law takes (`to`, `around`, `at`): [%.0f, 0, %.0f] cm - %s." % [
		(spot.x - Tables.ORIGIN.x) * 100.0, (spot.z - Tables.ORIGIN.y) * 100.0, String(Motions.SPOTS["work"])])
	for ti in things.size():
		var th: Dictionary = things[ti]
		var box: AABB = _world_rest_thing(ti) * (th["box"] as AABB)
		var mid := box.get_center()
		lines.append("- \"%s\": stands at [%.0f, %.0f] cm, %.0f x %.0f x %.0f cm%s" % [String(th["name"]),
			(mid.x - Tables.ORIGIN.x) * 100.0, (mid.z - Tables.ORIGIN.y) * 100.0, box.size.x * 100.0, box.size.y * 100.0, box.size.z * 100.0,
			" - it holds a flame and is never moved whole" if bool(th["lit"]) else ""])
		for wi in th["works"]:
			var gi := int(_group_of.get(wi, -1))
			var members: Array = (groups[gi] as Dictionary)["members"] if gi >= 0 else []
			if gi >= 0 and int(members[0]) != int(wi):
				continue
			var wk: Dictionary = works[wi]
			var w: Dictionary = wk["w"]
			var bits := PackedStringArray()
			# A PART WITH COPIES: worked as one by its name, a copy alone by its number - each where it is now
			if gi >= 0:
				var nm0 := String(wk["name"])
				var at := PackedStringArray()
				for k in mini(members.size(), 8):
					var mk: Dictionary = works[int(members[k])]
					var c := _work_world(int(members[k]), NAN) * (((mk["w"] as Dictionary).get("box", AABB()) as AABB).get_center())
					at.append("%d [%.1f, %.1f, %.1f]" % [k + 1, (c.x - Tables.ORIGIN.x) * 100.0, c.y * 100.0, (c.z - Tables.ORIGIN.y) * 100.0])
				bits.append("%d copies - \"%s\" works them all as one, \"%s 1\" to \"%s %d\" one alone; each copy's middle: %s%s" % [members.size(), nm0, nm0, nm0, members.size(),
					", ".join(at), ", ..." if members.size() > 8 else ""])
			if not String(wk["kind"]).is_empty():
				var jt: Dictionary = w["joint"]
				bits.append("%s joint%s" % [String(wk["kind"]), (" range %s" % str(jt["range"])) if jt.has("range") else ""])
			var pts: Dictionary = w.get("points", {})
			if not pts.is_empty():
				var names := PackedStringArray()
				for k in pts:
					var pw := _work_world(int(wi), NAN) * (pts[k] as Vector3)
					names.append("%s [%.1f, %.1f, %.1f]" % [String(k), (pw.x - Tables.ORIGIN.x) * 100.0, pw.y * 100.0, (pw.z - Tables.ORIGIN.y) * 100.0])
				bits.append(("points (of copy 1) " if gi >= 0 else "points ") + ", ".join(names))
			if w.has("start"):
				bits.append("starts " + JSON.stringify(w["start"]))
			if w.has("runs"):
				bits.append("runs " + ", ".join(PackedStringArray((w["runs"] as Array).map(func(l: Dictionary) -> String: return String(l["law"])))))
			if w.has("emits"):
				bits.append("emits " + String((w["emits"] as Dictionary)["kind"]))
			var nm := String(wk["name"])
			lines.append("    - %s: %s" % [("part \"%s\"" % nm) if not nm.is_empty() else "an unnamed part", "; ".join(bits) if not bits.is_empty() else "it only changes (fill, grow, tint, glow, shown)"])
	return "\n".join(lines)


## WHAT ACT [param name] DOES, in numbers, after a rehearsal ([method rehearse]): how long, how far each moving
## thing travels and how fast at the most, and ANYTHING PASSING THROUGH ANYTHING - a moving thing's points
## inside another thing, or through the table's top - with the moment it happens. `{text, through}`.
func check(name: String) -> Dictionary:
	var times := rehearse(10.0)
	if not times.has(name):
		return {"text": "no act called \"%s\" could be played (%s)" % [name, "; ".join(notes) if not notes.is_empty() else "none was kept"], "through": 0}
	var span: Array = times[name]
	var t0 := float(span[0])
	var t1 := float(span[1])
	var act: Dictionary = {}
	for a in acts:
		if String((a as Dictionary)["name"]) == name:
			act = a
	# WHAT MOVES IN IT, and the meshes that do not - a part's copies moved as one together
	var movers: Array = []          # [{nodes, label}]
	for tr in act["tracks"]:
		var ch := String((tr as Dictionary).get("_ch", ""))
		if not ch.ends_with(":pose"):
			continue
		if ch.begins_with("t"):
			var ti := int((tr as Dictionary)["_ti"])
			movers.append({"nodes": [(things[ti] as Dictionary)["node"]], "label": String((things[ti] as Dictionary)["name"]), "rest": _world_rest_thing(ti),
				"slot": _world_rest_thing(ti) * ((things[ti] as Dictionary)["box"] as AABB)})
			continue
		var wi := int((tr as Dictionary)["_wi"])
		var of := String((things[(works[wi] as Dictionary)["thing"]] as Dictionary)["name"])
		if ch.begins_with("g"):
			var g: Dictionary = groups[int((tr as Dictionary)["_gi"])]
			var nodes: Array = (g["members"] as Array).map(func(m: int) -> Node3D: return (works[m] as Dictionary)["node"])
			var slot := AABB()
			for k in (g["members"] as Array).size():
				var mk := int((g["members"] as Array)[k])
				var b: AABB = (_rest["w%d:pose" % mk] as Transform3D) * (((works[mk] as Dictionary)["w"] as Dictionary).get("box", AABB()) as AABB)
				slot = b if k == 0 else slot.merge(b)
			movers.append({"nodes": nodes, "label": "%s's %s (all %d, as one)" % [of, String(g["name"]), nodes.size()],
				"rest": _rest["w%d:pose" % int((g["members"] as Array)[0])], "slot": slot})
		else:
			movers.append({"nodes": [(works[wi] as Dictionary)["node"]], "label": "%s's %s" % [of, _part_label(wi)], "rest": _rest["w%d:pose" % wi],
				"slot": (_rest["w%d:pose" % wi] as Transform3D) * (((works[wi] as Dictionary)["w"] as Dictionary).get("box", AABB()) as AABB)})
	var lines := PackedStringArray()
	lines.append("\"%s\" (beat %s) runs %.1f s%s." % [name, String(act["beat"]), t1 - t0, " here (\"under\": as long as its words leave it)" if bool(act["under"]) else ""])
	if movers.is_empty():
		lines.append("Nothing in it moves from its place: it changes what things are (their fill, size, color, glow).")
		tick(t1)
		return {"text": "\n".join(lines), "through": 0}
	var still := TriangleMesh.new()
	var faces := PackedVector3Array()
	tick(t0)
	for th in things:
		for m in (th as Dictionary)["meshes"]:
			var mi := m as MeshInstance3D
			if mi == null or mi.mesh == null:
				continue
			var under_mover := false
			for mv in movers:
				for n in mv["nodes"]:
					if n == mi or (n as Node).is_ancestor_of(mi):
						under_mover = true
			if under_mover or not mi.visible or _is_soft(mi):
				continue
			var xf := _world_of(mi)
			for q in mi.mesh.get_faces():
				faces.append(xf * q)
	if not faces.is_empty():
		still.create_from_faces(faces)
	var through := 0
	for mv in movers:
		var node: Node3D = (mv["nodes"] as Array)[0]
		var pts := PackedVector3Array()
		var owners: Array = []
		var meshes: Array = []
		for n in mv["nodes"]:
			if n is MeshInstance3D:
				meshes.append(n)
			for c in (n as Node).find_children("*", "MeshInstance3D", true, false):
				meshes.append(c)
		var share := maxi(1, meshes.size())
		for mi in meshes:
			var m := mi as MeshInstance3D
			if m.mesh == null:
				continue
			var f := m.mesh.get_faces()
			var step := maxi(1, f.size() * share / CHECK_POINTS)
			for i in range(0, f.size(), step):
				pts.append(f[i])
				owners.append(m)
		var travel := 0.0
		var fastest := 0.0
		var last := Vector3.INF
		var first_hit := ""
		var hits := 0
		var below := 0
		# A PART THAT STARTS SEATED in something - a vial in its rack, a ladle in its pot, a stopper in its bottle,
		# as the set dresser built it or an earlier act left it - may come out of it: a point inside something as
		# the act begins is not counted until it has once come out, and after that going in anywhere is. (The
		# first real puppeteer was told its rack's vial passed through something "0.0 s in" on 12 acts of 69.)
		var seated := PackedByteArray()
		seated.resize(pts.size())
		var seated_n := 0
		for s in CHECK_STEPS + 1:
			var t := lerpf(t0, t1, float(s) / float(CHECK_STEPS))
			tick(t)
			var mid := _world_of(node).origin
			if last != Vector3.INF:
				var step := mid.distance_to(last)
				travel += step
				fastest = maxf(fastest, step / ((t1 - t0) / float(CHECK_STEPS)))
			last = mid
			# BACK WHERE IT WAS BUILT it is as the set dresser built it: a vial put back in its rack is home
			var now_xf := _world_of(node)
			var home_xf: Transform3D = mv["rest"]
			var home := now_xf.origin.distance_to(home_xf.origin) < HOME_NEAR \
				and Quaternion(now_xf.basis.orthonormalized()).angle_to(Quaternion(home_xf.basis.orthonormalized())) < HOME_TURN
			var slot: AABB = (mv["slot"] as AABB).grow(SLOT_GROW)
			var cache := {}
			for i in pts.size():
				var m: MeshInstance3D = owners[i]
				if not cache.has(m):
					cache[m] = _world_of(m)
				var p: Vector3 = (cache[m] as Transform3D) * pts[i]
				var in_top := p.y < -THROUGH_TOP and Tables.inside(medium._top, Vector2(p.x, p.z), 0.0)
				# ...and the room it stood in as built is its own slot: going back into it is going home
				var in_thing := not in_top and not faces.is_empty() and not slot.has_point(p) and _inside(still, p)
				if (s == 0 or home) and (in_top or in_thing):
					if seated[i] == 0 and s == 0:
						seated_n += 1
					seated[i] = 1
				if seated[i] == 1:
					if not (in_top or in_thing):
						seated[i] = 0
					continue
				if in_top:
					below += 1
					if first_hit.is_empty():
						first_hit = "through the table's top %.1f s in" % (t - t0)
				elif in_thing:
					hits += 1
					if first_hit.is_empty():
						first_hit = "inside something else %.1f s in, at [%.1f, %.1f, %.1f] cm" % [t - t0, (p.x - Tables.ORIGIN.x) * 100.0, p.y * 100.0, (p.z - Tables.ORIGIN.y) * 100.0]
		through += hits + below
		lines.append("- %s travels %.0f cm, at most %.0f cm a second. %s%s" % [String(mv["label"]), travel * 100.0, fastest * 100.0,
			("PASSES THROUGH: %d of its points at the moments looked at - first %s. Fix it: move it clear, `press` it onto the surface, or lift it." % [hits + below, first_hit])
				if hits + below > 0 else "Nothing passes through anything.",
			(" It starts seated in something (%d of its points, as it was built or left): coming out of it is not counted." % seated_n) if seated_n > 0 else ""])
	tick(t1)
	return {"text": "\n".join(lines), "through": through}


## Whether [param p] is inside [param tm]: an odd count of its surfaces straight above it.
static func _inside(tm: TriangleMesh, p: Vector3) -> bool:
	var o := p
	var n := 0
	for i in 12:
		var hit: Dictionary = tm.intersect_ray(o, Vector3.UP)
		if hit.is_empty():
			break
		n += 1
		o = (hit["position"] as Vector3) + Vector3.UP * 0.0002
	return n % 2 == 1
