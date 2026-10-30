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
## ...lifted on the way as a hand lifts it, over whatever rim it goes into (meters, at the middle of the move) - not at
## all from nearer than BLEND_NEAR.x, wholly from further than BLEND_NEAR.y (meters).
const BLEND_LIFT := 0.1
const BLEND_NEAR := Vector2(0.01, 0.05)
## HOW HEAVY WHAT IS SET DOWN IS ([method set_down]): the share of a thing's box that is its stuff - a whole thing
## mostly hollow (a jar, a pot), a part of one mostly solid (a stopper, a pestle).
const HOLLOW := 0.25
const SOLID := 0.6
## A liquid boils, and is heard to, past this much `boil` ([method boiling]).
const BOIL_HEARD := 0.02
## How far above a pressed point its ray starts (meters): above the point, below a vessel's rim.
const PRESS_FROM := 0.06
## THE CHECK OF AN ACT ([method check]): where its rehearsal begins (seconds; every picture of the work rehearses from
## there too, [TablePreview], so what one baked the next takes up - [method TablePhysics.carry]), the moments it is
## looked at, the most points of a moving thing tried, and how far through the table's top a point may go before it is
## through it (meters).
const REHEARSAL := 10.0
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
## ...and what it stands on is under the points of its surface this near its lowest (meters, [method _foot]).
const FOOT := 0.003
## A loose part let go within this much of its own thing's box (meters) is IN it, and rides it ([method _ridden]).
const RIDE_GROW := 0.01
## The voice's pace against the plan's estimate is measured once it has said this much of the estimate (seconds)
## ([method _guessed]); before that, the estimate's own.
const GUESS_FROM := 10.0
## A carry or path begun within this long of the last one's end on the same thing goes on from it, one move ([method
## _chains]) (seconds).
const CHAIN_GAP := 0.05
## HELD UP between moves ([method _held_up]): how long a hand's unsteadiness takes to come on after a move and to die
## away before the next (seconds), and how near anything a thing is touching it (meters).
const HOLD_IN := 0.6
const TOUCHING := 0.004
## How far into what it is pressed onto a tool may go and still be meeting it, not passing through it ([method check]):
## its head on a bowl's sloping wall as it goes round (meters).
const PRESS_INTO := 0.006
## The scale the work's meshes are cast on in ([method _ray_mesh]): centimeters.
const RAY_SCALE := 100.0

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
var _writing := {}            # work -> the words written on it, as its last `write` says, and once drawn their skin
var _aloft_of := {}           # a channel and where a move left it -> whether it touches nothing there ([method _held_up])
var _parent_work := {}        # work index -> the work it is a part of, or -1 ([method _within])
var _solids_ref: Array = []   # the physics' solids, their fields - this work's and its twin's ([method _foot])
var _steady := false          # while that is found: nothing drifts
var _air = null               # the acts' cue bursts (Effects.Air), or null
var _cues: Array = []         # [{act, at, every, where, name}]
var _timed: Array = []        # every material on the table that follows show time: a liquid's surface, copies glowing apart
var _huffs: Array = []        # the creatures' huffs, heard and seen ([method Soundscape.seen_calls])
var _moved := {}              # pose channel -> true: a thing or part some act of the episode moves ([method build]) -
                              # never what the schedule has placed so far, which a live reading's words grow
var _soft := {}               # work index -> true: a part that changes (fills, grows, comes and goes) or is a liquid -
                              # what a tool goes into, never a surface it is pressed onto or kept out of
var _root: Node3D
var _begun := {}              # act name -> [t0, t1]: begun, and never moved again
var _last_now := -INF         # when the plan in force was made ([method schedule])
## How far into the reading the show began (seconds; [member TablePlan.since]): a part that runs all the time keeps the
## reading's time - a clock scrubbed to the middle shows the middle's.
var since := 0.0
var _plan_key := ""
var _spot := Vector3.INF      # the work's spot, once found ([method work_spot])
var _depth := 0               # how deep a place is being found through another thing's moves ([method _thing_world])
## The table's materials, made safe ([method Props.sanitize]): what each part is made of, as the physics reads it.
var materials := {}
## WHAT IS IN THINGS ([TablePhysics], next/table_physics.md): the liquids, the grains and the loose things, and the
## solids they meet - baked over show time from the schedule this keeps.
var physics: TablePhysics = null


# --- building -----------------------------------------------------------------------------------

## A NEW TABLE: everything the last one worked is let go.
func clear() -> void:
	if _root != null and is_instance_valid(_root):
		_root.queue_free()
	_root = null
	if _air != null:
		_air.release()
	_air = null
	if physics != null:
		physics.clear()
	physics = null
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
	_cues = []
	_timed = []
	_huffs = []
	_soft = {}
	_moved = {}
	_begun = {}
	_last_now = -INF
	since = 0.0
	_plan_key = ""
	_spot = Vector3.INF
	_depth = 0


## Thing [param t], built as [param b] ([method Props.build]) and stood as [param node]: its working parts
## kept, and its liquids, so they can be worked ([method TableThings.put] hands every thing here) - and its
## shade on the cloth ([param shades]: the contact shade and the slab that casts its foot's), which goes with it.
func take(t: Dictionary, b: Dictionary, node: Node3D, shades: Array = []) -> void:
	var ti := things.size()
	var first := works.size()
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
		var apart: Variant = mat.get_shader_parameter("apart") if mat != null else null
		if (kd != null and int(kd) == 13) or (apart != null and float(apart) > 0.0):
			_timed.append(mat)
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
	if physics == null:
		physics = TablePhysics.new()
		physics.work = self
	physics.take(ti, t, b, node, first)


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
	_writing = {}
	_aloft_of = {}
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
		for tr in kept:
			if String((tr as Dictionary)["law"]) == "write":
				_writing[int(tr["_wi"])] = {"text": tr["text"], "hand": tr["hand"], "ink": tr["ink"]}
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
		_rest["w%d:written" % wi] = 0.0
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
	# EACH MOVE ITS OWN HAND ([Hands]): a seed a track, from the episode's and the act's - a tool's two ends share theirs
	for a in acts:
		var tracks: Array = a["tracks"]
		for k in tracks.size():
			var tr: Dictionary = tracks[k]
			var hs := hash([medium._plan.seed_value, String(a["name"]), k])
			tr["_hand"] = hs
			for end in ["tip", "grip"]:
				if tr.get(end) is Dictionary:
					(tr[end] as Dictionary)["_hand"] = hs
	# WHAT THE WORK MOVES, from every act, scheduled or not: a loose part an act will pick up lies where it was put
	# until then - it had ridden its thing until its act was placed, and a live reading places an act only as its
	# words are heard (the pestle went to the middle of the bench with its mortar, and jumped back to its corner)
	for a in acts:
		for t in a["tracks"]:
			var ch := String((t as Dictionary).get("_ch", ""))
			if ch.ends_with(":pose"):
				_moved[ch] = true
	# EACH THING'S BODY, what a loose part of it is IN when it is in it: the thing without its loose parts - a mortar's
	# bowl, not the corner its pestle lies in
	for ti in things.size():
		(things[ti] as Dictionary)["body"] = _body_of(ti)
	# WHAT A TOOL GOES INTO: a part that changes - in an act or from its start - or a liquid
	for a in acts:
		for t in a["tracks"]:
			var tr: Dictionary = t
			if String(tr.get("_ch", "")).get_slice(":", 1) in ["fill", "grow", "shown"]:
				_soft[int(tr["_wi"])] = true
	for wi in works.size():
		var start: Dictionary = ((works[wi] as Dictionary)["w"] as Dictionary).get("start", {})
		# ...and what is loose: a tool pushes it about, never passes through it ([TablePhysics])
		if start.has("fill") or start.has("grow") or start.has("shown") or bool(((works[wi] as Dictionary)["w"] as Dictionary).get("loose", false)):
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
	# THE BURSTS an act's cues throw
	var fxs: Array = []
	var moments: Array = []
	for a in acts:
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
	# READY FOR THE PHYSICS' OWN THREAD ([TablePhysics]): each thing's place as it stood, its surface, the work's spot, which
	# part is in which - nothing the bake reads may need a node
	for ti in things.size():
		(things[ti] as Dictionary)["rest_world"] = _world_rest_thing(ti)
	var of_node := {}
	for wi in works.size():
		of_node[(works[wi] as Dictionary)["node"]] = wi
	for wi in works.size():
		var n: Node = ((works[wi] as Dictionary)["node"] as Node).get_parent()
		while n != null and not of_node.has(n):
			n = n.get_parent()
		_parent_work[wi] = int(of_node[n]) if n != null else -1
	for ti in things.size():
		_mesh_of(ti)
	work_spot()
	if physics != null:
		physics.build()
		for n in physics.notes:
			notes.append(n)


## Where [param track]'s law acts, found on the table: its `_ch` (a channel - `w3:angle`, `t1:pose`...) - "" when
## found, else why not. A sprinkle has none: the physics lets its grains fall.
func _resolve(track: Dictionary) -> String:
	var law := String(track["law"])
	if law == "sprinkle":
		# grains let fall from a point: the physics' ([TablePhysics]), on no channel of the work's
		if not String(track.get("thing", "")).is_empty() and _thing_named(String(track["thing"])) < 0:
			return "no thing on the table is called \"%s\"" % String(track["thing"])
		if not track.has("at") and String(track.get("thing", "")).is_empty():
			return "a sprinkle names neither a thing nor where it falls from (`at`)"
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
	if law == "write" and not ((works[wi] as Dictionary)["w"] as Dictionary).has("sheet"):
		track.erase("_copies")
		return "\"%s\" of \"%s\" is not a sheet: only a sheet (a slip, a label, a page) is written on" % [part, String(track["thing"])]
	# A LOOSE THING'S SIZE IS ITS OWN: ground, it breaks (the-quiet-crucible 119515's dragon's blood and pumpkin seeds were
	# shrunk with `grow` while the pestle went round over them - the user: "They didn't crush: they just scaled down a bit")
	if state == "grow" and bool(((works[wi] as Dictionary)["w"] as Dictionary).get("loose", false)):
		track.erase("_copies")
		return ("\"%s\" of \"%s\" is loose: its size is its own, never grown or shrunk - to grind it, bring a tool's point down " +
			"onto it, pressed into what holds it (an `aim` whose point `press`es the mortar, going round over it), and it breaks " +
			"into pieces and powder by itself") % [part, String(track["thing"])]
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


## WHAT IS IN THINGS OUTRUN: whether a live show at [param t] is past the last frame [member physics] has baked and the
## work has held loose work [param wi] since that frame - then it is where the work has it, never where the bake last saw
## it. A live reading's bake can fall behind the reading, and a plan changed as its words arrive is baked again from the
## change: the-quiet-crucible 707668's slip, carried over the cauldron, "poofed" back to the middle of the table where the
## bake had last set it down, and the mortar was set down on it.
func _outran(wi: int, t: float) -> bool:
	var baked := physics.baked_to()
	if t <= baked:
		return false
	for ch in ["w%d:pose" % wi, "g%d:pose" % int(_group_of.get(wi, -1))]:
		for e in _chan.get(ch, []):
			if float((e as Dictionary)["s1"]) >= baked and float((e as Dictionary)["s0"]) <= t:
				return true
	return false


## Whether work [param wi] is moved in any act: on its own, or with its copies.
func _part_moves(wi: int) -> bool:
	return _moved.has("w%d:pose" % wi) or _moved.has("g%d:pose" % int(_group_of.get(wi, -1)))


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
	if th.has("rest_world"):
		return th["rest_world"]
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
		if _moved.has(own) or _moved.has(gch):
			_depth += 1
			var x: Transform3D = value(own, T) if _chan.has(own) else _rest[own]
			if _moved.has(gch):
				x = (value(gch, T) as Transform3D) * (_rest[gch] as Transform3D).affine_inverse() * x
			x = _ridden(wi, x, T)
			_depth -= 1
			return x
	var at_rest: Transform3D = _rest["w%d:pose" % wi] if _rest.has("w%d:pose" % wi) else _world_of(wk["node"])
	return _thing_world(ti, T) * _world_rest_thing(ti).affine_inverse() * at_rest


## A LOOSE PART RIDES ITS THING: a free part let go IN its own thing (a pestle left in its mortar), or standing in it
## as built and not yet picked up, goes with the thing when the thing is moved after - [param x], its place as the
## work left it, carried as the thing has been since; one laid down anywhere else stays where it was laid. While a
## track holds it, it is where the track has it.
func _ridden(wi: int, x: Transform3D, T: float) -> Transform3D:
	var ti := int((works[wi] as Dictionary)["thing"])
	if not _chan.has("t%d:pose" % ti):
		return x
	var own := "w%d:pose" % wi
	var ch := own if _moved.has(own) else "g%d:pose" % int(_group_of.get(wi, -1))
	var let_go := NAN
	for e in _chan.get(ch, []):
		if float((e as Dictionary)["s0"]) > T:
			break
		if T < float((e as Dictionary)["s1"]):
			return x
		let_go = float((e as Dictionary)["s1"])
	# NOT YET PICKED UP, it is where it was built: in its thing (a pestle standing in its bowl), it goes where the thing
	# is carried - it had stayed in the air where the bowl stood, and its first act swept it 30 cm in a moment
	var then := _thing_world(ti, let_go) if not is_nan(let_go) else _world_rest_thing(ti)
	var now := _thing_world(ti, T)
	if then.is_equal_approx(now):
		return x
	# IN IT: standing in its body - over it, and down below its top (a pestle's middle stands above a mortar's rim)
	var w: Dictionary = (works[wi] as Dictionary)["w"]
	var part: AABB = (then.affine_inverse() * x) * (w.get("box", AABB()) as AABB)
	var body: AABB = ((things[ti] as Dictionary).get("body", (things[ti] as Dictionary)["box"]) as AABB).grow(RIDE_GROW)
	var mid := part.get_center()
	if mid.x < body.position.x or mid.x > body.end.x or mid.z < body.position.z or mid.z > body.end.z \
			or part.position.y > body.end.y or part.end.y < body.position.y:
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
	var y := _surface_under(target, p, T)
	return p if is_nan(y) else Vector3(p.x, y + gap * 0.01, p.z)


## The height of thing [param target]'s surface under [param p] (meters, the table's space) at show time [param T],
## or NAN where nothing of it is under it.
func _surface_under(target: String, p: Vector3, T := NAN) -> float:
	var ti := _thing_named(target)
	if ti < 0:
		return NAN
	var tm := _mesh_of(ti)
	if tm == null:
		return NAN
	# the ray in the thing's own place as it stood, where its surface was taken
	var back := _world_rest_thing(ti) * _thing_world(ti, T).affine_inverse()
	var hit: Dictionary = _ray(tm, back * (p + Vector3(0.0, PRESS_FROM, 0.0)), (back.basis * Vector3.DOWN).normalized())
	if hit.is_empty():
		return NAN
	return (back.affine_inverse() * (hit["position"] as Vector3)).y


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
	if th["mesh"] != null or bool(th.get("meshless", false)):
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
		# known to have none: never measured again (the physics' thread asks, and may touch no node)
		th["meshless"] = true
		return null
	var tm := _ray_mesh(faces)
	th["mesh"] = tm
	return tm


## A MESH RAYS ARE CAST ON, from [param faces] (meters): kept in centimeters ([constant RAY_SCALE]). Godot's ray and
## triangle test takes a triangle whose edges' product is under its epsilon (0.00001) for one the ray runs along - in
## meters, a lathe's slivers round its axis, a bowl's floor two centimeters across: a pestle pressed into a mortar's
## middle fell through its floor to the table, and a thing set down there sank to the bottom of its base. Cast on with
## [method _ray].
static func _ray_mesh(faces: PackedVector3Array) -> TriangleMesh:
	var big := PackedVector3Array()
	big.resize(faces.size())
	for i in faces.size():
		big[i] = faces[i] * RAY_SCALE
	var tm := TriangleMesh.new()
	tm.create_from_faces(big)
	return tm


## The first of [method _ray_mesh]'s mesh [param tm] a ray from [param from] along [param dir] meets (meters): its
## `position`, or empty.
static func _ray(tm: TriangleMesh, from: Vector3, dir: Vector3) -> Dictionary:
	var hit: Dictionary = tm.intersect_ray(from * RAY_SCALE, dir)
	if hit.is_empty():
		return hit
	return {"position": (hit["position"] as Vector3) / RAY_SCALE, "normal": hit.get("normal", Vector3.UP)}


# --- when each act runs ---------------------------------------------------------------------------

## WHEN EACH ACT RUNS, from the reading's placed schedule [param sched] (`[{a, t0, s}]`, [method
## ReadingFollower.place]), its walk [param parse] ([method CardReading.parse]) and when each spoken word was
## said ([param said0], [param said1] - [constant ReadingFollower.NO_TIME] where not yet; [param est], each
## word's estimated time from the top, gives the pace of what is not yet heard). [param now]: what has begun by
## then never moves.
##
## NOTHING BEGINS ON A GUESS (the-quiet-crucible 181083, live: "absolute chaos ... the green dish moved on top of
## the crucible, then floated back to its position ... tipped-over"): an act cued at a word not yet heard waits for
## it, and so does every act that follows it in its beat. The words of a live reading arrive a sentence at a time,
## and the guess for the rest had been the plan's estimate from the top - 0.4 s a word, two minutes behind a hushed
## voice by the work - so every act cued in the beat lay before the beat began, all of them began together at its
## start, quickened, and were held there as begun: three moves of the moonlight's jar at once, the shell fetched,
## tipped over the pot and put away in the same seconds. An export knows every word from its first frame and never
## guessed, and a scrub's estimates lie AFTER its words (its show time starts again at 0), so neither showed it.
## What is still guessed - where a beat ends, for quickening its acts and for one "under" - is guessed from the
## last word heard, at the pace the voice has kept ([method _guessed]). What the plan in force has begun is
## begun, whatever the words say after; an act placed only once its moment has passed begins now, never part way
## through; and no two acts move one part at once - an act begins when the acts before it on its parts end.
func schedule(sched: Array, parse: Dictionary, said0: PackedFloat32Array, said1: PackedFloat32Array,
		est: PackedFloat32Array, now: float) -> void:
	if acts.is_empty():
		return
	# WHAT IS PLAYING IS BEGUN: the plan in force had it under way, and seen
	for r in runs:
		var nm := String((acts[int((r as Dictionary)["i"])] as Dictionary)["name"])
		if float(r["t0"]) <= now and not _begun.has(nm):
			_begun[nm] = [float(r["t0"]), float(r["t1"])]
	var actions: Array = parse.get("actions", [])
	var n_spoken := (parse.get("spoken", PackedStringArray()) as PackedStringArray).size()
	var guess := _guessed(said0, said1, est, n_spoken)
	var w0 := func(si: int) -> float:
		if si < 0 or si >= n_spoken:
			return INF
		if si < said0.size() and said0[si] != ReadingFollower.NO_TIME:
			return said0[si]
		return INF
	var w1 := func(si: int) -> float:
		if si < 0 or si >= n_spoken:
			return INF
		if si < said1.size() and said1[si] != ReadingFollower.NO_TIME:
			return said1[si]
		return guess.call(si)
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
	var busy := {}            # channel -> when the last act placed on it ends
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
			# from where the last ended, or at its word - and not before that word is heard
			var t0 := t
			if cued.has(nm):
				t0 = maxf(float(cued[nm]), span.x)
			var parts := _channels_of(a)
			for ch in parts:
				t0 = maxf(t0, float(busy.get(ch, -INF)))
			if _begun.has(nm):
				t0 = float((_begun[nm] as Array)[0])
			elif t0 < now and _last_now > -INF and t0 >= _last_now:
				# due since the last plan was made, and placed only now: it begins now (a first plan, or one made again
				# for a table built again mid-show, has a past that is past)
				t0 = now
			if t0 == INF:
				t = INF
				continue
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
				if t1 == INF:
					t1 = t0 + Motions.UNDER_GUESS
			if _begun.has(nm) and not bool(a["under"]):
				t1 = float((_begun[nm] as Array)[1])
			if t0 <= now:
				_begun[nm] = [t0, t1]
			out.append({"i": i, "t0": t0, "t1": t1})
			for ch in parts:
				busy[ch] = maxf(float(busy.get(ch, -INF)), t1)
			t = t1
	_last_now = now
	out.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return float(x["t0"]) < float(y["t0"]))
	var key := str(out.map(func(r: Dictionary) -> Vector3: return Vector3(float(r["i"]), float(r["t0"]), float(r["t1"]))))
	if key == _plan_key:
		return
	_plan_key = key
	runs = out
	_timelines()


## WHEN A WORD NOT YET HEARD WILL END, guessed (a Callable of its spoken index, seconds): from the last word heard, as
## far on as the plan's estimate ([param est]) puts it, at the pace the voice has kept against that estimate over
## what it has said - INF where nothing gives a guess. Never when an act begins: only where a beat ends.
static func _guessed(said0: PackedFloat32Array, said1: PackedFloat32Array, est: PackedFloat32Array, n: int) -> Callable:
	var last := -1
	for si in range(mini(said1.size(), n) - 1, -1, -1):
		if said1[si] != ReadingFollower.NO_TIME:
			last = si
			break
	var first := -1
	for si in mini(said0.size(), n):
		# a mid-way start's words before it were said long ago (negative times): the pace is the voice's since
		if said0[si] != ReadingFollower.NO_TIME and said0[si] >= 0.0:
			first = si
			break
	var pace := 1.0
	if first >= 0 and last > first and last < est.size() and est[last] - est[first] > GUESS_FROM:
		pace = clampf((said1[last] - said0[first]) / (est[last] - est[first]), 0.5, 3.0)
	return func(si: int) -> float:
		if si < 0 or si >= est.size():
			return INF
		if last < 0 or last >= est.size():
			return est[si] + ReadingFollower.A_WORD
		return said1[last] + maxf(est[si] - est[last], 0.0) * pace


## The channels act [param a] works: each track's.
static func _channels_of(a: Dictionary) -> PackedStringArray:
	var out := PackedStringArray()
	for t in a["tracks"]:
		var tr: Dictionary = t
		var chs: Array = [String(tr.get("_ch", ""))]
		for ch in chs:
			if not String(ch).is_empty() and not out.has(ch):
				out.append(ch)
	return out


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


## THE REHEARSAL every picture of the work is taken on ([method check], [TablePreview]): from [constant REHEARSAL].
func rehearsed() -> Dictionary:
	return rehearse(REHEARSAL)


## How far into a rehearsal (its [param times], [method rehearse]) a check of acts [param names] bakes what is in things
## ([method TablePhysics.report]): the end of the last of them and what it set falling - 0 for none.
func checks_reach(times: Dictionary, names: Array) -> float:
	var t := 0.0
	for nm in names:
		if times.has(String(nm)):
			t = maxf(t, float((times[String(nm)] as Array)[1]) + TablePhysics.REPORT_AFTER)
	return t


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
			if not String(tr.get("_ch", "")).is_empty():
				items.append({"ch": String(tr["_ch"]), "track": tr, "t0": t0, "t1": t1, "i": int(r["i"]), "order": order,
					"s0": t0 + w.x * (t1 - t0), "s1": t0 + w.y * (t1 - t0)})
			order += 1
	items.sort_custom(func(x: Dictionary, y: Dictionary) -> bool:
		return float(x["s0"]) < float(y["s0"]) or (float(x["s0"]) == float(y["s0"]) and (float(x["t0"]) < float(y["t0"]) or (float(x["t0"]) == float(y["t0"]) and int(x["order"]) < int(y["order"])))))
	# TWICE: an end can lie where another thing has been moved to by then (a pestle ground round a mortar
	# carried to the middle), and the first pass has not yet laid that thing's later moves down
	for pass_i in 2:
		var now := {}
		var until := {}           # channel -> when what last held it lets it go
		for it in items:
			var e: Dictionary = it
			var ch := String(e["ch"])
			e.erase("_down")
			e["from"] = now.get(ch, _run_value(ch, float(e["s0"])))
			# A LOOSE PART BEGINS WHERE ITS THING HAS CARRIED IT since it was let go in it (or since it was built in it) -
			# one of a set of copies keeps its own place in the set's frame
			if pass_i == 1 and ch.begins_with("w") and ch.ends_with(":pose") and not _group_of.has(int(ch.substr(1, ch.find(":") - 1))) \
					and float(until.get(ch, -INF)) < float(e["s0"]) - CHAIN_GAP:
				e["from"] = _work_world(int(ch.substr(1, ch.find(":") - 1)), float(e["s0"]) - 1e-4)
			until[ch] = maxf(float(until.get(ch, -INF)), float(e["s1"]))
			e["end"] = _eval(e, float(e["s1"]) - float(e["t0"]), float(e["s1"]))
			now[ch] = e["end"]
			if pass_i == 0:
				_add(ch, e)
	_chains()
	plan_cues()
	if physics != null:
		physics.replan()


## ONE MOVE THROUGH ITS PLACES: a run of carries and paths on one thing or part, each begun as the last ended (a vial
## carried "the low way" past three things, a waypoint a carry), goes on through every place it passes and stops only
## where it holds or turns back, and at the run's ends - each a cubic through them all ([method Motions.slopes]), the
## slope at each of its places kept on its entry as `_m` (meters a second). A run of one carry keeps its own ease.
func _chains() -> void:
	for ch in _chan:
		if not String(ch).ends_with(":pose"):
			continue
		var run: Array = []
		for e in _chan[ch]:
			var law := String(((e as Dictionary)["track"] as Dictionary)["law"])
			if not law in ["carry", "path"] or (not run.is_empty() and absf(float(e["s0"]) - float((run.back() as Dictionary)["s1"])) > CHAIN_GAP):
				_through(run)
				run = []
			if law in ["carry", "path"]:
				run.append(e)
		_through(run)


## The slopes of run [param run] ([method _chains]) at each of its places, kept on its entries.
func _through(run: Array) -> void:
	if run.is_empty():
		return
	var at := PackedFloat32Array()
	var v := PackedVector3Array()
	var idx: Array = []           # per entry, the index of each of its places in the run's
	for e in run:
		var tr: Dictionary = (e as Dictionary)["track"]
		var x0: Transform3D = _rest.get(String(tr["_ch"]), Transform3D.IDENTITY)
		var q0 := _pivot(tr)
		var p_from := ((e["from"] as Transform3D) * x0.affine_inverse()) * q0
		var places: Array = []
		if String(tr["law"]) == "carry":
			places = [[float(e["s0"]), p_from], [float(e["s1"]), _carried_to(tr, q0, float(e["s1"]))]]
		else:
			for k in tr["keys"]:
				places.append([float(e["t0"]) + float((k as Dictionary)["at"]) * (float(e["t1"]) - float(e["t0"])),
					p_from + ((k as Dictionary).get("by", Vector3.ZERO) as Vector3) * 0.01])
		var mine: Array = []
		for j in places.size():
			# where one ends and the next begins is one place
			if j == 0 and not at.is_empty() and absf(float(places[0][0]) - at[at.size() - 1]) <= CHAIN_GAP:
				mine.append(at.size() - 1)
				continue
			at.append(float(places[j][0]))
			v.append(places[j][1])
			mine.append(at.size() - 1)
		idx.append(mine)
	var m := Motions.slopes(at, v)
	for k in run.size():
		var own := PackedVector3Array()
		for i in idx[k]:
			own.append(m[int(i)])
		var any := false
		for x in own:
			any = any or x != Vector3.ZERO
		if any:
			(run[k] as Dictionary)["_m"] = own
		else:
			(run[k] as Dictionary).erase("_m")


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


## A channel's value with nothing acting on it at show time [param T]: what it started as, under what it runs - in
## the reading's time ([member since]).
func _run_value(ch: String, T: float) -> Variant:
	var v: Variant = _rest.get(ch, 0.0)
	var rt := T + since
	for law in _runs_of.get(ch, []):
		if v is Color:
			v = Motions.tint(law, v, rt, 1.0, rt)
		elif v is float:
			v = Motions.scalar(law, float(v), rt, 1.0, rt)
	return v


## A CHANNEL'S VALUE at show time [param t].
func value(ch: String, t: float) -> Variant:
	var list: Array = _chan.get(ch, [])
	var last: Dictionary = {}
	var next: Dictionary = {}
	for e in list:
		if float((e as Dictionary)["s0"]) <= t:
			last = e
		else:
			next = e
			break
	if last.is_empty():
		return _run_value(ch, t)
	if t >= float(last["s1"]):
		# A PART THAT RUNS GOES ON RUNNING from where an act let it go: a clock set by hand keeps time after
		if last["end"] is float and _runs_of.has(ch):
			return float(last["end"]) + float(_run_value(ch, t)) - float(_run_value(ch, float(last["s1"])))
		# A HAND HOLDING A THING UP IS NEVER STILL ([method _held_up])
		if last["end"] is Transform3D:
			var up := _held_up(ch, last, next, t)
			if up > 0.0:
				var dr: Array = Hands.drift(t, int((last["track"] as Dictionary).get("_hand", 0)), up * Hands.HOLD_SWAY)
				var end: Transform3D = last["end"]
				return Transform3D((dr[1] as Basis) * end.basis, end.origin + (dr[0] as Vector3))
		return last["end"]
	return _eval(last, t - float(last["t0"]), t)


## HELD UP BETWEEN ITS MOVES: how much of a hand's unsteadiness ([method Hands.drift]) a thing or part has at [param t],
## the move [param e] on channel [param ch] having left it where it touches nothing - a pestle lifted out of its mortar
## and held aside, a vial held over a pot - coming on as the move ends and dying away before [param next] begins, so a
## move still begins where it was sent. The user, 2026-10-29: "when the actor is holding the pestle in the air, it is
## perfectly still: but you would expect it to be gently bobbing/moving, since a hand cannot remain perfectly still".
## None for what was set `down` or rests on or against anything, or what the physics holds (a loose thing let go falls),
## and none in the twin the physics bakes by (it touches nothing, so nothing it meets would tell).
func _held_up(ch: String, e: Dictionary, next: Dictionary, t: float) -> float:
	if physics == null or _steady or bool((e["track"] as Dictionary).get("down", false)):
		return 0.0
	var key := ch + str(((e["end"] as Transform3D).origin * 1000.0).round())
	if not _aloft_of.has(key):
		# its touching found where nothing drifts - nor asks again while it is found
		_aloft_of[key] = false
		_steady = true
		_aloft_of[key] = _aloft(ch, e["end"], float(e["s1"]))
		_steady = false
	if not bool(_aloft_of[key]):
		return 0.0
	var up := smoothstep(0.0, HOLD_IN, t - float(e["s1"]))
	if not next.is_empty():
		up *= smoothstep(0.0, HOLD_IN, float(next["s0"]) - t)
	return up


## Whether channel [param ch]'s thing or part, posed [param x] at show time [param T], touches nothing: no point of its
## own surface within [constant TOUCHING] of the table's top or of any solid but its own, where each is then. ITS
## SURFACE, NEVER ITS BOX: a round lid set on its crock has its box's corners out in the air past the rim, and was held
## up, swaying, to the end of the show (the-quiet-crucible 841899: "moving about wildly on top of the pot, never
## stopping").
func _aloft(ch: String, x: Transform3D, T: float) -> bool:
	var own_t := -1
	var own_w := -1
	var idx := int(ch.substr(1, ch.find(":") - 1))
	if ch.begins_with("t"):
		own_t = idx
	elif ch.begins_with("w"):
		own_w = idx
		if bool(((works[idx] as Dictionary)["w"] as Dictionary).get("loose", false)):
			return false
	else:
		return false
	# its own solids' surfaces where it is posed: the node a solid hangs from carried as the channel's node is
	var rest: Transform3D = _rest.get(ch, Transform3D.IDENTITY)
	var moved := x * rest.affine_inverse()
	var pts: Array = []
	var span := AABB()
	for sd in physics.solids:
		var d: Dictionary = sd
		if not d.has("field") or not (int(d["thing"]) == own_t or (own_w >= 0 and _within(int(d["wi"]), own_w) == 1)):
			continue
		var pose: Transform3D = moved * (_thing_world(int(d["oi"]), NAN) if String(d["owner"]) == "t" else _work_world(int(d["oi"]), NAN)) * (d["local"] as Transform3D)
		for q in (d["field"] as ShapeField).surface_points():
			var p := pose * (q as Vector3)
			if p.y < TOUCHING:
				return false
			span = AABB(p, Vector3.ZERO) if pts.is_empty() else span.expand(p)
			pts.append(p)
	if pts.is_empty():
		return false
	for sd in physics.solids:
		var d: Dictionary = sd
		if int(d["thing"]) == own_t or (own_w >= 0 and _within(int(d["wi"]), own_w) != 0) or not d.has("field"):
			continue
		var pose: Transform3D = (_thing_world(int(d["oi"]), T) if String(d["owner"]) == "t" else _work_world(int(d["oi"]), T)) * (d["local"] as Transform3D)
		if not (pose * (d["box"] as AABB)).grow(TOUCHING).intersects(span):
			continue
		var inv := pose.affine_inverse()
		for p in pts:
			if (d["field"] as ShapeField).sample(inv * (p as Vector3)).x < TOUCHING:
				return false
	return true


## Work [param wi] to work [param own]: 1 when it is that work or a part in it that goes where it goes (a stopper in its
## jar), -1 a part in it that the work moves on its own (taken out, it is wherever it was put), 0 another.
func _within(wi: int, own: int) -> int:
	if wi < 0:
		return 0
	if wi == own:
		return 1
	var up := int(_parent_work.get(wi, -1))
	while up >= 0 and up != own:
		up = int(_parent_work.get(up, -1))
	if up != own:
		return 0
	return -1 if _moved.has("w%d:pose" % wi) else 1


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


## A POSE at [param tau] of [param d] seconds into its act: where the part or the thing is, in the table's
## space - as a held tool goes, from where it was ([param e]'s `from`).
func _pose(e: Dictionary, tau: float, d: float, T: float) -> Transform3D:
	var tr: Dictionary = e["track"]
	var from: Transform3D = e["from"]
	var ch := String(tr["_ch"])
	var x0: Transform3D = _rest.get(ch, Transform3D.IDENTITY)
	var wi := int(tr.get("_wi", -1))
	var q0 := _pivot(tr)
	var rel := from * x0.affine_inverse()
	var p_from := rel * q0
	var r_from := rel.basis.orthonormalized()
	var u := clampf(tau / maxf(d, 1e-6), 0.0, 1.0)
	var vars := {"t": tau, "u": u, "d": d, "T": T, "n": 0.0}
	var out := from
	match String(tr["law"]):
		"carry":
			var w: Vector2 = tr["between"]
			var lin := clampf((u - w.x) / maxf(w.y - w.x, 1e-6), 0.0, 1.0)
			var s := Hands.timing(lin)
			var to := _carried_to(tr, q0, T)
			# ...BACK WHERE IT WAS BUILT, AS IT WAS BUILT, unless turned: a stopper laid on its side goes back in upright (the
			# the-quiet-crucible 841899: the sulfur's cork went back into its jar on its side)
			var r_to := Basis.from_euler((tr["turn"] as Vector3) * (PI / 180.0)) if tr.has("turn") else (r_from if tr.has("to") else Basis.IDENTITY)
			if not tr.has("to"):
				r_to = _home_of(tr, float(e["t0"]) + w.y * d).basis.orthonormalized() * r_to
			# on through where the carry before it left it and where the one after takes it up ([method _chains])
			var m: PackedVector3Array = e.get("_m", PackedVector3Array())
			var h := (w.y - w.x) * d
			var ma := m[0] * h if m.size() == 2 else Vector3.ZERO
			var mb := m[1] * h if m.size() == 2 else Vector3.ZERO
			# AS A HAND CARRIES IT ([Hands]): minimum jerk, bowed a little to one side, lifted early and lowered late,
			# leaning with the hand's pull, and never quite still while it is off the table
			var seed := int(tr.get("_hand", 0))
			var lift := float(tr["lift"]) * 0.01
			var p := Hands.carried(p_from, to, ma, mb, lift, lin, seed)
			var r := Basis(Quaternion(r_from).slerp(Quaternion(r_to.orthonormalized()), s))
			r = Hands.lean(func(x: float) -> Vector3: return Hands.carried(p_from, to, ma, mb, lift, x, seed), lin, h) * r
			var dr: Array = Hands.drift(T, seed, Hands.held(lin))
			out = _rebuilt((dr[1] as Basis) * r, p + (dr[0] as Vector3), q0, x0)
			# SET DOWN on what is under it: how far is found once, where it ends, and taken over the way there
			if tr.get("down", false):
				if not e.has("_down"):
					e["_down"] = _settle(tr, _rebuilt(r_to.orthonormalized(), to, q0, x0), float(e["t0"]) + w.y * d)
				out.origin.y += float(e["_down"]) * s
		"path":
			var keys: Array = tr["keys"]
			var seed := int(tr.get("_hand", 0))
			var mk: PackedVector3Array = e.get("_m", PackedVector3Array())
			var r := r_from
			for i in range(keys.size() - 1):
				var k0: Dictionary = keys[i]
				var k1: Dictionary = keys[i + 1]
				if u >= float(k0["at"]) and u <= float(k1["at"]):
					var s := Hands.timing((u - float(k0["at"])) / maxf(float(k1["at"]) - float(k0["at"]), 1e-6))
					var ra := Basis.from_euler((k0.get("turn", Vector3.ZERO) as Vector3) * (PI / 180.0)) * r_from
					var rb := Basis.from_euler((k1.get("turn", Vector3.ZERO) as Vector3) * (PI / 180.0)) * r_from
					r = Basis(Quaternion(ra.orthonormalized()).slerp(Quaternion(rb.orthonormalized()), s))
					break
				if u > float(k1["at"]):
					r = Basis.from_euler((k1.get("turn", Vector3.ZERO) as Vector3) * (PI / 180.0)) * r_from
			if u < float((keys[0] as Dictionary)["at"]):
				r = Basis.from_euler(((keys[0] as Dictionary).get("turn", Vector3.ZERO) as Vector3) * (PI / 180.0)) * r_from
			# ITS PLACE GOES ON THROUGH ITS KEYS ([method _chains]: their slopes, a second's, to the act's whole), or eases
			# from each to the next - bowed between them as a hand goes ([method _path_at])
			var where := func(x: float) -> Vector3: return _path_at(keys, mk, p_from, d, x, seed)
			var p: Vector3 = where.call(u)
			# ...leaning with the hand's pull, never quite still while it is held off the table
			r = Hands.lean(where, u, d) * r
			var win := _window(tr)
			var dr: Array = Hands.drift(T, seed, Hands.held((u - win.x) / maxf(win.y - win.x, 1e-6)))
			out = _rebuilt((dr[1] as Basis) * r, p + (dr[0] as Vector3), q0, x0)
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
		# in an arc, so it goes over a rim rather than through it, early, as a hand lifts a tool before it reaches
		var lin := tau / BLEND_IN
		var s := Hands.timing(lin)
		var lift := blend_lift(lin, from.origin.distance_to(out.origin))
		out = from.interpolate_with(out, s)
		out.origin.y += lift
	var j := Motions.jitter_of(tr, tau)
	if j != Vector3.ZERO:
		out.origin += j
	return out


## HOW HIGH A HAND LIFTS A TOOL it brings to where a law has it, [param s] of the way there from [param far] meters
## off: as far as it has to go - a step from no lift at all to the whole of one, as the law's place moved 2 cm off,
## threw 181083's pestle 6 cm up in a frame as it began to grind.
static func blend_lift(s: float, far: float) -> float:
	return BLEND_LIFT * Hands.lift_at(s) * smoothstep(BLEND_NEAR.x, BLEND_NEAR.y, far)


## A PATH'S PLACE at [param u] through its act ([param d] seconds): through its [param keys] from [param p_from] - on
## through them with slopes [param mk] (meters a second, [method _chains]) or eased from each to the next - and bowed
## between each two a little to one side, as a hand goes ([method Hands.bow], [param seed]).
static func _path_at(keys: Array, mk: PackedVector3Array, p_from: Vector3, d: float, u: float, seed: int) -> Vector3:
	var ps := PackedVector3Array()
	var ats := PackedFloat32Array()
	for k in keys:
		ats.append(float((k as Dictionary)["at"]))
		ps.append(p_from + ((k as Dictionary).get("by", Vector3.ZERO) as Vector3) * 0.01)
	if u <= ats[0]:
		return ps[0]
	if u >= ats[ats.size() - 1]:
		return ps[ps.size() - 1]
	var i := 0
	while i < ats.size() - 2 and u > ats[i + 1]:
		i += 1
	var lin := (u - ats[i]) / maxf(ats[i + 1] - ats[i], 1e-6)
	var p := ps[i].lerp(ps[i + 1], Hands.timing(lin))
	if mk.size() == keys.size():
		var ms := PackedVector3Array()
		for m in mk:
			ms.append(m * d)
		p = Motions.through(ats, ps, ms, u)
	return p + Hands.bow(ps[i], ps[i + 1], lin, hash([seed, i]))


## The point a pose track [param tr] moves its thing or part by, where it stood as built (the table's space, meters):
## a group's middle, a part's pivot or middle - a thing's own origin.
func _pivot(tr: Dictionary) -> Vector3:
	var x0: Transform3D = _rest.get(String(tr["_ch"]), Transform3D.IDENTITY)
	var wi := int(tr.get("_wi", -1))
	var pivot_local := Vector3.ZERO
	if tr.has("_gi"):
		pivot_local = (groups[int(tr["_gi"])] as Dictionary)["middle"]
	elif wi >= 0:
		var w: Dictionary = (works[wi] as Dictionary)["w"]
		pivot_local = (w["joint"] as Dictionary).get("pivot", w.get("middle", Vector3.ZERO)) if w.get("joint") is Dictionary else w.get("middle", Vector3.ZERO)
	return x0 * pivot_local


## Where carry [param tr] takes its pivot [param q0] (show time [param T]): its `to`, `by` past it - or by that much
## from where it was built.
func _carried_to(tr: Dictionary, q0: Vector3, T: float) -> Vector3:
	return place_of(tr.get("to"), q0, T) + (tr["by"] as Vector3) * 0.01 if tr.has("to") else _home_of(tr, T) * q0 + (tr["by"] as Vector3) * 0.01


## HOME, for carry [param tr] with no `to` (show time [param T]): for a thing, where it was built; for a part, where it was
## built IN ITS THING, the thing as it stands now - a pestle put back goes into its mortar where the mortar is, never into
## the air or the wall where the mortar had stood (the-quiet-crucible 841899). As a move from where it was built.
func _home_of(tr: Dictionary, T: float) -> Transform3D:
	if tr.has("_ti"):
		return Transform3D.IDENTITY
	var wi := int(tr.get("_wi", -1))
	if tr.has("_gi"):
		wi = int(((groups[int(tr["_gi"])] as Dictionary)["members"] as Array)[0])
	if wi < 0:
		return Transform3D.IDENTITY
	var ti := int((works[wi] as Dictionary)["thing"])
	return _thing_world(ti, T) * _world_rest_thing(ti).affine_inverse()


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
	# ITS FOOT, NEVER ITS BOX: what it stands on is what is under its own lowest surface - a round mortar's box corners stand
	# out past its base, over the edge of what is beside it, and it was set down 9 mm up on that (the-quiet-crucible 841899:
	# its pestle, put back where it was built in it, went into its wall)
	var foot := _foot(tr, x)
	if not foot.is_empty():
		probes = foot
		low = INF
		for c in foot:
			low = minf(low, (c as Vector3).y)
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
			var hit: Dictionary = _ray(tm, back * from, (back.basis * Vector3.DOWN).normalized())
			if not hit.is_empty():
				var y := (back.affine_inverse() * (hit["position"] as Vector3)).y
				if y < top:
					under = maxf(under, y)
	return under - low + SET_GAP


## WHERE TRACK [param tr]'s THING OR PART STANDS, posed [param x]: the points of its own surfaces within [constant FOOT]
## of its lowest ([method ShapeField.surface_points]) - none where the physics' solids are not to hand.
func _foot(tr: Dictionary, x: Transform3D) -> Array:
	if _solids_ref.is_empty():
		return []
	var ch := String(tr["_ch"])
	var moved := x * (_rest.get(ch, Transform3D.IDENTITY) as Transform3D).affine_inverse()
	var own_t := int(tr.get("_ti", -1))
	var own_w := int(tr.get("_wi", -1))
	if tr.has("_gi"):
		own_w = int(((groups[int(tr["_gi"])] as Dictionary)["members"] as Array)[0])
	var pts: Array = []
	var low := INF
	for sd in _solids_ref:
		var d: Dictionary = sd
		if not d.has("field"):
			continue
		var mine := (own_t >= 0 and int(d["thing"]) == own_t and (int(d["wi"]) < 0 or not _moved.has("w%d:pose" % int(d["wi"])))) \
			or (own_w >= 0 and _within(int(d["wi"]), own_w) == 1)
		if not mine:
			continue
		var pose: Transform3D = moved * (_world_rest_thing(int(d["oi"])) if String(d["owner"]) == "t" else (_rest["w%d:pose" % int(d["oi"])] as Transform3D)) * (d["local"] as Transform3D)
		for q in (d["field"] as ShapeField).surface_points():
			var p := pose * (q as Vector3)
			pts.append(p)
			low = minf(low, p.y)
	var out: Array = []
	for p in pts:
		if (p as Vector3).y <= low + FOOT:
			out.append(p)
	return out


## A point of an aim ([param end]) where its law has it: round its middle, at its place, or along its keys
## from [param rest] - pressed onto what it names.
func _end_at(end: Dictionary, rest: Vector3, tau: float, d: float, T: float) -> Vector3:
	var c := place_of(end.get("around"), rest, T) if end.has("around") else rest
	var fixed: Variant = place_of(end["at"], rest, T) if end.has("at") else null
	var p := Motions.point_at(end, c, fixed, rest, tau, d, T)
	if end.has("press"):
		p = _press(String(end["press"]), p, float(end.get("gap", 0.15)), T)
	return p


## Thing [param ti]'s BODY in its own space: the box of its meshes but its free parts' ([method _ridden]) - its whole box
## when it is nothing else.
func _body_of(ti: int) -> AABB:
	var th: Dictionary = things[ti]
	var loose: Array = []
	for wi in th["works"]:
		if String((works[wi] as Dictionary)["kind"]) == "free":
			loose.append((works[wi] as Dictionary)["node"])
	var body := AABB()
	var any := false
	for m in th["meshes"]:
		var mi := m as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		var under := false
		for n in loose:
			under = under or n == mi or (n as Node).is_ancestor_of(mi)
		if under:
			continue
		var xf := Transform3D.IDENTITY
		var q: Node = mi
		while q != null and q != th["node"] and q is Node3D:
			xf = (q as Node3D).transform * xf
			q = q.get_parent()
		var bb := xf * mi.get_aabb()
		body = bb if not any else body.merge(bb)
		any = true
	return body if any else th["box"]


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
		if not _moved.has(ch):
			continue
		var th: Dictionary = things[ti]
		var node: Node3D = th["node"]
		node.transform = _parent_world(node).affine_inverse() * (value(ch, t) as Transform3D)
	# WHAT IS IN THINGS, baked as far as this moment: its loose parts posed by it ([method _pose_work])
	if physics != null:
		physics.tick(t)
	for wi in works.size():
		_pose_work(wi, t)
	_tick_shades()
	for p in _plumes:
		_tick_plume(p, t)
	if _air != null:
		_air.tick(t)
	for m in _timed:
		(m as ShaderMaterial).set_shader_parameter("show_time", t)


## EACH THING'S SHADE ON THE CLOTH where the thing is now: gone while it is lifted or tipped, under it where it
## is set down - a thing moved whole, or one whose moving part is most of it seen from above (a pestle that is
## its own thing; a mortar's pestle leaves the mortar's shade alone). The one place the work reads back what it
## posed: the shade follows the pose, never the other way.
func _tick_shades() -> void:
	for ti in things.size():
		var th: Dictionary = things[ti]
		var shades: Array = th["shades"]
		var moves := _moved.has("t%d:pose" % ti)
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
	# A LIQUID THE PHYSICS KEEPS is as full as it is, its surface cut level ([TablePhysics]): never scaled
	var kept := physics.liquid_volume(wi, t) if physics != null else -1.0
	if kept >= 0.0:
		fill = 1.0 if kept > 1e-9 else 0.0
	var s := Transform3D.IDENTITY
	if kept < 0.0 and (not is_equal_approx(fill, 1.0) or not is_equal_approx(grow, 1.0)):
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
			# and a part left in its thing riding it ([method _work_world]) - or, LOOSE, where the physics has it, held
			# or let go ([TablePhysics])
			var loose: Variant = physics.pose_of(wi, t) if physics != null and bool(w.get("loose", false)) and not _outran(wi, t) else null
			if loose != null:
				j = _parent_world(node).affine_inverse() * (loose as Transform3D)
			elif _part_moves(wi):
				j = _parent_world(node).affine_inverse() * _work_world(wi, t)
	node.transform = j * s
	node.visible = float(value("w%d:shown" % wi, t)) > 0.5 and grow > 0.001 and fill > 0.001
	# a loose thing ground to pieces is drawn as its pieces
	if node.visible and physics != null and bool(w.get("loose", false)) and not physics.whole(wi, t):
		node.visible = false
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
	if _writing.has(wi):
		_written(wi, t)


## Whether work [param wi] is of a material a blade cuts ([constant TablePhysics.CUTS]).
func _cuttable(wi: int) -> bool:
	var mats: Array = (works[wi] as Dictionary)["mats"]
	if mats.is_empty() or (mats[0] as ShaderMaterial).get_shader_parameter("kind") == null:
		return false
	var code := int((mats[0] as ShaderMaterial).get_shader_parameter("kind"))
	for k in TablePhysics.CUTS:
		if int((Props.MATERIALS[k] as Dictionary)["code"]) == code:
			return true
	return false


## Whether loose work [param wi] is of matter that breaks under a pressing tool ([constant Props.MATERIALS]' `strength`).
func _brittle(wi: int) -> bool:
	var mats: Array = (works[wi] as Dictionary)["mats"]
	if mats.is_empty() or (mats[0] as ShaderMaterial).get_shader_parameter("kind") == null:
		return false
	var code := int((mats[0] as ShaderMaterial).get_shader_parameter("kind"))
	for k in Props.MATERIALS:
		if int((Props.MATERIALS[k] as Dictionary)["code"]) == code:
			return float((Props.MATERIALS[k] as Dictionary)["strength"]) > 0.0
	return false


## WORDS WRITTEN ON SHEET [param wi] ([SheetWriting]) as far as the pen has got at [param t] - drawn the first time any
## of them is.
func _written(wi: int, t: float) -> void:
	var wr: Dictionary = _writing[wi]
	var got := float(value("w%d:written" % wi, t))
	if not wr.has("node"):
		if got <= 0.0:
			return
		var wk: Dictionary = works[wi]
		wr["node"] = SheetWriting.node((wk["w"] as Dictionary)["sheet"], String(wr["text"]), String(wr["hand"]), Color.html(String(wr["ink"])))
		(wk["node"] as Node3D).add_child(wr["node"])
	((wr["node"] as MeshInstance3D).material_override as ShaderMaterial).set_shader_parameter("written", got)


# --- what the work sounds like ([WorkSounds]) ----------------------------------------------------------

## WHAT IS SET DOWN from show time [param t0] up to [param t1]: each carry `down` that ends then, `{t, at (the table's
## space), mass (kilograms, about), kind (its material's), size (meters, its widest)}`.
func set_down(t0: float, t1: float) -> Array:
	var out: Array = []
	for ch in _chan:
		if not String(ch).ends_with(":pose"):
			continue
		for e in _chan[ch]:
			var tr: Dictionary = (e as Dictionary)["track"]
			var land := float((e as Dictionary)["s1"])
			if land < t0 or land >= t1 or String(tr["law"]) != "carry" or not bool(tr.get("down", false)):
				continue
			out.append(_heft(tr, land))
	return out


## How heavy what track [param tr] moves is, what it is made of and how big, where it is at [param T] ([method set_down]).
## A whole thing is reckoned mostly hollow (a jar, a pot), a part mostly solid (a stopper, a pestle).
func _heft(tr: Dictionary, T: float) -> Dictionary:
	var box: AABB
	var at: Vector3
	var code := 0
	var solid := HOLLOW
	var n := 1
	if tr.has("_ti"):
		var ti := int(tr["_ti"])
		var th: Dictionary = things[ti]
		box = _world_rest_thing(ti) * (th["box"] as AABB)
		at = _thing_world(ti, T) * (th["box"] as AABB).get_center()
		for m in th["meshes"]:
			var mat := (m as MeshInstance3D).material_override as ShaderMaterial if m is MeshInstance3D else null
			if mat != null and mat.get_shader_parameter("kind") != null:
				code = int(mat.get_shader_parameter("kind"))
				break
	else:
		var wi := int(tr.get("_wi", -1))
		if tr.has("_gi"):
			var members: Array = (groups[int(tr["_gi"])] as Dictionary)["members"]
			wi = int(members[0])
			n = members.size()
		var wk: Dictionary = works[wi]
		box = _work_world(wi, NAN) * ((wk["w"] as Dictionary).get("box", AABB()) as AABB)
		at = _work_world(wi, T) * ((wk["w"] as Dictionary).get("middle", Vector3.ZERO) as Vector3)
		solid = SOLID
		var mats: Array = wk["mats"]
		if not mats.is_empty() and (mats[0] as ShaderMaterial).get_shader_parameter("kind") != null:
			code = int((mats[0] as ShaderMaterial).get_shader_parameter("kind"))
	var kind := "painted"
	for k in Props.MATERIALS:
		if int((Props.MATERIALS[k] as Dictionary)["code"]) == code:
			kind = String(k)
	var density := float((Props.MATERIALS[kind] as Dictionary)["density"]) * 1000.0
	return {"t": T, "at": at, "kind": kind, "size": maxf(box.size.x, maxf(box.size.y, box.size.z)),
		"mass": box.size.x * box.size.y * box.size.z * density * solid * float(n)}


## WHAT IS PRESSED ONTO SOMETHING at show time [param t] - a pestle's tip in its mortar, as an `aim` or a `circle`
## `press`es it: `[{wi, at (its pressed point, the table's space), touch (meters over the surface, past the gap it is
## held at; INF where none of it is under), kind (what it is pressed onto), size (meters, how wide that is)}]`.
func pressed(t: float) -> Array:
	var out: Array = []
	for ch in _chan:
		if not String(ch).begins_with("w") or not String(ch).ends_with(":pose"):
			continue
		for e in _chan[ch]:
			var tr: Dictionary = (e as Dictionary)["track"]
			if t < float((e as Dictionary)["s0"]) or t >= float((e as Dictionary)["s1"]):
				continue
			var ends: Array = []
			if String(tr["law"]) == "aim":
				ends = [tr["tip"], tr["grip"]]
			elif String(tr["law"]) == "circle":
				ends = [tr]
			var wi := int(tr["_wi"])
			var w: Dictionary = (works[wi] as Dictionary)["w"]
			var pts: Dictionary = w.get("points", {})
			for end in ends:
				var ed: Dictionary = end
				# an aim presses its named point; a circle, the foot of what it carries round
				var local: Variant = pts.get(String(ed.get("point", ""))) if String(tr["law"]) == "aim" else w.get("base", Vector3.ZERO)
				if not ed.has("press") or not (local is Vector3):
					continue
				var p := _work_world(wi, t) * (local as Vector3)
				var y := _surface_under(String(ed["press"]), p, t)
				var ti := _thing_named(String(ed["press"]))
				var code := 0
				for m in (things[ti] as Dictionary)["meshes"]:
					var mat := (m as MeshInstance3D).material_override as ShaderMaterial if m is MeshInstance3D else null
					if mat != null and mat.get_shader_parameter("kind") != null:
						code = int(mat.get_shader_parameter("kind"))
						break
				var kind := "stone"
				for k in Props.MATERIALS:
					if int((Props.MATERIALS[k] as Dictionary)["code"]) == code:
						kind = String(k)
				var tb: AABB = _world_rest_thing(ti) * ((things[ti] as Dictionary)["box"] as AABB)
				out.append({"wi": wi, "at": p, "touch": INF if is_nan(y) else maxf(p.y - y - float(ed.get("gap", 0.15)) * 0.01, 0.0), "kind": kind,
					"size": maxf(tb.size.x, tb.size.z)})
	return out


## WHAT BOILS at show time [param t] ([constant Motions.STATES] `boil`): `[{wi, boil, at (its surface's middle, the
## table's space), size (meters across)}]` - those boiling at all.
func boiling(t: float) -> Array:
	var out: Array = []
	for wi in works.size():
		var ch := "w%d:boil" % wi
		if not _chan.has(ch) and not _runs_of.has(ch) and float(_rest.get(ch, 0.0)) <= 0.0:
			continue
		var b := float(value(ch, t))
		if b <= BOIL_HEARD:
			continue
		var box: AABB = ((works[wi] as Dictionary)["w"] as Dictionary).get("box", AABB())
		var top := _work_world(wi, t) * Vector3(box.get_center().x, box.end.y, box.get_center().z)
		out.append({"wi": wi, "boil": b, "at": top, "size": maxf(box.size.x, box.size.z)})
	return out


# --- what smokes and pours -----------------------------------------------------------------------------

## A PLUME of work [param wi]'s `emits`: a pool of puffs ([constant Motions.MAX_PUFFS] at most), each born in
## turn from its point and rising - in closed form, the k-th puff born at k over its rate - and as thick as the
## part's `emit` says (so how hard it smokes can change and stay a function of time). A TRAIL, NEVER TUFTS: puffs
## are born at least half a puff's size apart as they rise, and a plume asked for fewer is fainter, never broken
## (the-quiet-crucible 181083: 1.4 puffs a second asked, half of them dropped by the dice, rose as tufts - the
## user: "normal heat would produce consistent steam trails").
func _plume(wi: int, e: Dictionary) -> Dictionary:
	var look: Dictionary = Motions.EMITS[String(e["kind"])]
	var trail := float(look["rise"]) / (float(look["size"]) * 0.001 * 0.5)
	var rate := maxf(float(e["rate"]), trail)
	var thick := clampf(float(e["rate"]) / rate, Motions.TRAIL_THIN, 1.0)
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
	return {"wi": wi, "e": e, "look": look, "layer": layer, "rate": rate, "thick": thick, "life": life, "n": n, "slots": slots, "lives": lives,
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
		if hidden or strength <= 0.005:
			mm.set_instance_custom_data(slot, Color(-1.0e6, 0.01, 0.0, 0.0))
			lives[slot] = Vector2(-1.0e6, 0.01)
			continue
		var born := float(k) / rate
		var side := Vector3(_hash01(k, 2) - 0.5, 0.0, _hash01(k, 3) - 0.5) * 0.02
		var vel := Vector3(side.x, float(look["rise"]) * lerpf(0.7, 1.25, _hash01(k, 4)), side.z)
		var particle := {"born": born, "pos": from + Vector3(_hash01(k, 5) - 0.5, 0.0, _hash01(k, 6) - 0.5) * 0.01, "vel": vel}
		mm.set_instance_transform(slot, Effects.particle_xform(particle, wind))
		# as thick as it smokes when it is born: the sprite fades by its color's alpha
		var c: Color = p["color"]
		mm.set_instance_color(slot, Color(c.r, c.g, c.b, clampf(strength, 0.0, 1.0) * float(p["thick"])))
		lives[slot] = Vector2(born, life * lerpf(0.75, 1.2, _hash01(k, 7)))
		mm.set_instance_custom_data(slot, Color(lives[slot].x, lives[slot].y, _hash01(k, 8),
			float(look["size"]) * 0.001 * lerpf(0.7, 1.3, _hash01(k, 9))))
	p["slots"] = slots
	p["lives"] = lives


static func _hash01(k: int, salt: int) -> float:
	var h := hash([k, salt, "puff"])
	return float(h & 0xFFFFFF) / float(0x1000000)


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
			if w.has("sheet"):
				bits.append("a sheet, blank: words can be written on it (`write`)")
			if bool(w.get("edge", false)):
				bits.append("a BLADE: what soft loose thing it is brought down through, it cuts")
			if bool(w.get("loose", false)) and _cuttable(wi):
				bits.append("soft: a blade cuts it")
			if bool(w.get("loose", false)) and _brittle(wi):
				bits.append("it breaks: a tool's point pressed down onto it (`press`), going round over it, grinds it to pieces and powder")
			# ON ITS SIDE AS BUILT (the-quiet-crucible 119515's stopper, laid down in its tray, went into its vial's mouth
			# sideways - the user: "it is attached sideways")
			if String(wk["kind"]) == "free" and _rest.has("w%d:pose" % wi) \
					and (_rest["w%d:pose" % wi] as Transform3D).basis.y.normalized().angle_to(Vector3.UP) > deg_to_rad(45.0):
				# a carry's `turn` is from as it was built: the one that brings its own up to the world's
				var up := Basis(Quaternion((_rest["w%d:pose" % wi] as Transform3D).basis.y.normalized(), Vector3.UP)).get_euler() * (180.0 / PI)
				bits.append("lies on its side as built: a carry's `turn` [%.0f, %.0f, %.0f] stands it upright, as it was made to stand" % [up.x, up.y, up.z])
			if bool(w.get("loose", false)):
				bits.insert(0, "LOOSE")
			var nm := String(wk["name"])
			lines.append("    - %s: %s" % [("part \"%s\"" % nm) if not nm.is_empty() else "an unnamed part", "; ".join(bits) if not bits.is_empty() else "it only changes (fill, grow, tint, glow, shown)"])
		# ...and what is in it, as the physics has it
		if physics != null:
			for c in physics.contents_of(ti):
				lines.append("    - %s" % c)
	return "\n".join(lines)


## WHAT ACT [param name] DOES, in numbers, after a rehearsal ([method rehearse]): how long, how far each moving
## thing travels and how fast at the most, and ANYTHING PASSING THROUGH ANYTHING - a moving thing's points
## inside another thing, or through the table's top - with the moment it happens. `{text, through}`.
func check(name: String) -> Dictionary:
	var times := rehearsed()
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
	var physics_said := physics.report(t0, t1) if physics != null else PackedStringArray()
	if movers.is_empty():
		lines.append("Nothing in it moves from its place: it changes what things are (their fill, size, color, glow).")
		lines.append_array(physics_said)
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
		still = _ray_mesh(faces)
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
		# A TOOL PRESSED ONTO A THING meets it, never passes through it: a pestle's head ground round a mortar's floor
		# touches its sloping wall as it goes (the-quiet-crucible 119515's puppeteer, told its pestle passed through the
		# mortar, lifted it clear of what it was grinding - and shrank the lumps instead)
		var pressed := _pressed_by(act, mv)
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
				var in_thing := not in_top and not faces.is_empty() and not slot.has_point(p) and _inside(still, p) \
					and not (not pressed.is_empty() and _pressed_into(pressed, p, t))
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
	lines.append_array(physics_said)
	tick(t1)
	return {"text": "\n".join(lines), "through": through}


## The things a mover [param mv] of [param act] is pressed onto (a law's `press`, its tip's or its grip's): `{tis: their
## numbers, own: the mover's own works}` - none pressed, empty.
func _pressed_by(act: Dictionary, mv: Dictionary) -> Dictionary:
	var tis: Array = []
	var own: Array = []
	for t in act["tracks"]:
		var tr: Dictionary = t
		if not String(tr.get("_ch", "")).ends_with(":pose") or not tr.has("_wi"):
			continue
		if not (mv["nodes"] as Array).has((works[int(tr["_wi"])] as Dictionary)["node"]):
			continue
		own.append(int(tr["_wi"]))
		for end in [tr, tr.get("tip", {}), tr.get("grip", {})]:
			if end is Dictionary and (end as Dictionary).has("press"):
				var ti := _thing_named(String((end as Dictionary)["press"]))
				if ti >= 0 and not tis.has(ti):
					tis.append(ti)
	return {} if tis.is_empty() else {"tis": tis, "own": own}


## Whether [param p] (the table's space) is no deeper than [constant PRESS_INTO] inside any of the things a tool is
## pressed onto ([param pressed], [method _pressed_by]) at show time [param t] - where it meets them - the tool's own
## solids aside.
func _pressed_into(pressed: Dictionary, p: Vector3, t: float) -> bool:
	if physics == null:
		return false
	for sd in physics.solids:
		var d: Dictionary = sd
		if not (pressed["tis"] as Array).has(int(d["thing"])) or (pressed["own"] as Array).has(int(d["wi"])) or not d.has("field"):
			continue
		var pose: Transform3D = (_thing_world(int(d["oi"]), t) if String(d["owner"]) == "t" else _work_world(int(d["oi"]), t)) * (d["local"] as Transform3D)
		if not (pose * (d["box"] as AABB)).grow(PRESS_INTO).has_point(p):
			continue
		var f := (d["field"] as ShapeField).sample(pose.affine_inverse() * p).x
		if f < 0.0 and f > -PRESS_INTO:
			return true
	return false


## Whether [param p] is inside [param tm]: an odd count of its surfaces straight above it.
static func _inside(tm: TriangleMesh, p: Vector3) -> bool:
	var o := p
	var n := 0
	for i in 12:
		var hit: Dictionary = _ray(tm, o, Vector3.UP)
		if hit.is_empty():
			break
		n += 1
		o = (hit["position"] as Vector3) + Vector3.UP * 0.0002
	return n % 2 == 1
