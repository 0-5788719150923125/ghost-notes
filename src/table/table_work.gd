extends RefCounted
class_name TableWork

## TableWork - work at the table, played: a part of [TableMedium] (next/table_work.md). The set dresser's
## working parts ([Motions]: joints, points, states, what runs all the time, what smokes) and the
## puppeteer's acts (`acts.json` in the episode), posed at every moment of the show.
##
## A pure function of show time, as everything on the table is ([method tick]): a part's turn, a vessel's
## fill, a tool's place are worked out from the time and the schedule, never stepped, so a render, a
## scrub and a tool's picture of the same moment agree. What persists persists by the schedule: an act's
## end is where the next act on the same part begins ([method schedule] keeps each one's `from`).
##
## When each act runs is the reading's ([method schedule]): an act belongs to a beat - the intro, a
## card's work (the `work K` mark, [TableActions]), or the close - and runs under that beat's words, in
## order: each from where the last ended, or from the word the reader marked it at (`<!-- act: name -->`,
## [CardReading]); an act that is "under" fills the time its beat leaves it; acts that would run past the
## beat's last word are quickened, never cut, except that separate collection trips keep their minimum
## duration. A word cue waits for the preceding act to finish. A begun act never moves when the plan is
## made again as a live reading's words arrive ([member _begun]).
##
## Nothing an agent wrote runs as code: the laws are [Motions]'s closed forms and a formula is
## [Formula]'s. A lit thing is never moved whole: its flames are the light's, lit where it stood (a track
## that would is refused, and said so).

## The [TableMedium] this is a part of.
var medium: TableMedium
## What is built on this table ([TableAssembly]; null where the table has no `assembly`), and what the table wrote of it.
var assembly: TableAssembly
var assembly_spec := {}
## What is painted here ([TablePaint], next/painted_surface.md): every part with a `skin`, the designs on
## them (the episode's `skin.json`, as parsed - [member skin_doc]) and the acts that paint them.
var paint: TablePaint
var skin_doc := {}
## The show's tuning ([TableTune]), made safe: what it tells of the numbers a person judged; a row's default where it tells none.
var tune := {}
## ...and the picture the designs were made from (`face_ref.png`; null none) and the surface it is of
## (`face.json`'s `on`, "thing/part"): where each operation's paint is still wanted ([PaintLayers]) -
## never laid itself, every mark a tool's (next/painted_surface.md, "The painting is the design").
var skin_ref: Image = null
var skin_ref_on := ""
## The episode's folder, where the painter at the table kept what it laid (`paint/elements.json` - TablePaint._from_host); "" none.
var skin_dir := ""
## A game played on this table ([TableGame]; null where there is none), what it was handed and where its pictures are.
var game: TableGame
var game_spec := {}
var game_dir := ""
var game_seed := 0
## What is written that TeX laid out ([TableInk]): the episode's `ink.json` as parsed (`{}` before the
## ink step), and the seed the hand that writes it is drawn from.
var ink_doc := {}
var ink_seed := 0

## A frame poses only what can have changed ([method _settled]): every part after a jump in show time
## longer than QUIET_JUMP (seconds - a scrub, a seek), and a part from QUIET_EDGE before a move of it to
## twice that after it, so its last value is drawn.
const QUIET_JUMP := 0.25
const QUIET_EDGE := 0.05
## How far over what is under it a thing a move leaves may be before `act` says it is left in the air (meters, [method _aloft_said]).
const ALOFT_GAP := 0.02
## How long a law that says where a tool is (an aim, a circle) takes to bring it there from where it was,
## at an act's start (seconds): a hand moves the pestle into the bowl before it grinds.
const BLEND_IN := 0.8
## ...lifted on the way as a hand lifts it, over whatever rim it goes into (meters, at the middle of the move) - not at
## all from nearer than BLEND_NEAR.x, wholly from further than BLEND_NEAR.y (meters).
const BLEND_LIFT := 0.1
const BLEND_NEAR := Vector2(0.01, 0.05)
## ...and lifted a hand's whole BLEND_LIFT however clear its way, turned more than BLEND_TURN.y on the
## way there - from nothing at BLEND_TURN.x (radians): what turns sweeps where its way does not go.
const BLEND_TURN := Vector2(0.35, 1.0)
## How far a point against a vessel's wall may be from its inside, toward its axis, and still be in it (meters, [method _against_inside]).
const INSIDE_NEAR := 0.008
## How heavy what is set down is ([method set_down]): the share of a thing's box that is its stuff - a
## whole thing mostly hollow (a jar, a pot), a part of one mostly solid (a stopper, a pestle).
const HOLLOW := 0.25
const SOLID := 0.6
## A liquid boils, and is heard to, past this much `boil` ([method boiling]).
const BOIL_HEARD := 0.02
## How far above a pressed point its ray starts (meters): above the point, below a vessel's rim.
const PRESS_FROM := 0.06
## The check of an act ([method check]): where its rehearsal begins (seconds; every picture of the work
## rehearses from there too, [TablePreview], so what one baked the next takes up - [method
## TablePhysics.carry]), the moments it is looked at, the most points of a moving thing tried, and how
## far through the table's top a point may go before it is through it (meters).
const REHEARSAL := 10.0
const CHECK_STEPS := 24
const CHECK_POINTS := 260
const THROUGH_TOP := 0.002
## A thing's shade on the cloth follows it ([method _tick_shades]): gone while it is lifted more than this
## or tipped more than this (meters, radians) - set down elsewhere, it lies where it is set; and a moving
## part carries its thing's shade only when it is at least this share of the thing seen from above.
const SHADE_LIFT := 0.003
const SHADE_TIP := 0.05
const SHADE_SHARE := 0.5
## The creatures seen as they are heard ([method Soundscape.seen_calls]): how far into a video their
## huffs are looked for (seconds), and where a huff's puff of smoke rises - past the table's far edge,
## this far behind it (meters) at its nearest and how much further when it is far.
const HUFFS_UNTIL := 3600.0
const HUFF_BEHIND := Vector2(0.06, 0.35)
## A place found through another thing's moves ([method _thing_world]) - a pestle ground round a mortar
## that is itself carried - is followed this many things deep; past it, a thing is where it stood.
const PLACE_DEPTH := 3
## A moving thing within this much of where it was built (meters, radians) is home, as it was built
## ([method check]): what it stands in there is the set dresser's, never the act's.
const HOME_NEAR := 0.01
const HOME_TURN := 0.09
## ...and the room it stood in as built, grown this much (meters), is its own slot: a vial set back down into its
## rack goes home through no wall of the rack.
const SLOT_GROW := 0.002
## A pinch falls from what holds it: a sprinkle naming a thing the same act moves falls within this much
## of it (meters), or [method check] says how far off it falls ([method _sprinkles_said]).
const PINCH_NEAR := 0.03
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
## What a hand lays down rests: before the same thing's next move, LAID_REST seconds - a hand lets go and
## takes it up again, never one curve through the table. Laid: set `down`, or brought by its last move to
## where its lowest point is within LAID_NEAR of the table's top ([method _laid_by]). A thing lowered in
## the air (a jar coming down over a pot, to pour) goes straight on.
const LAID_REST := 1.2
const LAID_NEAR := 0.03
## What posing an entry finds and keeps on it - a carry's room, how far it is set down, its way over what
## is in it and its rise, a path's, a pour's or a dip's plan, a tool's way in - kept for the next plan
## where nothing it rests on changed, with where it began and ended ([method _timelines]).
const FOUND := ["_down", "_clear", "_clear_path", "_room", "_rise", "_pour", "_dip", "_entry"]
## Held up between moves ([method _held_up]): how long a hand's unsteadiness takes to come on after a
## move and to die away before the next (seconds), and how near anything a thing is touching it (meters).
const HOLD_IN := 0.6
const TOUCHING := 0.004
## How far into what it is pressed onto a tool may go and still be meeting it, not passing through it ([method check]):
## its head on a bowl's sloping wall as it goes round (meters).
const PRESS_INTO := 0.006
## The scale the work's meshes are cast on in ([method _ray_mesh]): centimeters.
const RAY_SCALE := 100.0
## A carry clears what stands in its way ([method _clearance]): its lowest point this far over the highest
## thing under it (meters), looked at in this many places through this stretch of the move - where the
## hand's lift is at least this share of its highest ([method Hands.lift_at]) - from this far up
## (meters); a carry shorter than CLEAR_FROM (meters) is a nudge, and the most a hand lifts (meters).
const CLEAR_GAP := 0.02
const CLEAR_SAMPLES := 12
const CLEAR_SPAN := Vector2(0.1, 0.8)
const CLEAR_SHAPE := 0.3
const CLEAR_FROM_Y := 2.0
const CLEAR_FROM := 0.05
const CLEAR_MOST := 0.35
## ...looked down on in a grid this many points each way over what it covers ([method _probes_of]).
const CLEAR_GRID := 6
## What stands this close round a thing (meters) it rises clear of before it goes, or comes down among last ([method _rise_among]).
const AMONG := 0.015
## Room for it ([method _room]): a thing a move leaves where another already stands is set the nearest
## place beside it that is clear - looked for in rings ROOM_STEP apart out to ROOM_MOST (meters), clear
## when none of its surface (ROOM_POINTS of its points, each solid) is further into another solid than
## ROOM_DEEP (meters), and set ROOM_SPARE further out than that.
const ROOM_STEP := 0.01
const ROOM_MOST := 0.2
const ROOM_POINTS := 60
const ROOM_DEEP := 0.002
## ...and set this much further out than the first place clear (meters).
const ROOM_SPARE := 0.005
## A drink ([method _drink_at]): the share of its stretch each way, how far from the lens it is held along
## the lens's axis (meters), how far clear of the frame's foot all of it then is (meters), how far it is
## tipped toward the lens (degrees: under a full cup's brink), how high it rises at the least on its way
## (meters), and the least its stretch takes (seconds).
const DRINK_UP := 0.36
const DRINK_FAR := 0.18
const DRINK_CLEAR := 0.02
const DRINK_TIP := 9.0
const DRINK_LIFT := 0.07
const DRINK_LEAST := 6.0
## ...how far over what is built it passes, whatever it is (meters).
const DRINK_OVER := 0.04
## What rises from what is at the lens is not seen (a cup at the mouth: its steam would cross the whole picture): from how near it fades, and to how near it is gone (meters).
const PLUME_LENS := Vector2(0.55, 0.3)
## ...and cooler steam rises slower, lives less and is smaller, at the least by these shares of its own ([method _tick_plume]).
const STEAM_COOL_RISE := 0.55
const STEAM_COOL_LIFE := 0.6
const STEAM_COOL_SIZE := 0.7
## A pour ([method _pour_at]): the share of its stretch that brings the vessel over the mouth, and the
## share at its end that turns it back level; the shares of its inside its brink is found at ([method
## _pour_plan]); the least it is lifted on its way there (meters); how far a vessel's pivot must be from
## its opening to be a handle turned away (meters); and how far its body keeps clear of the mouth's rim
## (meters).
const POUR_BRING := 0.3
## ...tipped this share of its `tip` as it comes in, so its body swings away from the mouth before it is over it
const POUR_PRE := 0.3
## ...of its bringing, the share spent carrying it level to over the mouth (the rest lowers it onto the
## mouth, tipping); a lip held over a mouth this many of its radii up, between these (meters), unless
## `over` says; and the head over its lip a stream is aimed for (meters): a careful pour's.
const POUR_OVER := 0.65
const POUR_OVER_R := 1.5
const POUR_OVER_LEAST := 0.008
const POUR_OVER_MOST := 0.02
const POUR_HEAD := 0.004
## A dip ([method _dip_at]): where its stretch ends bringing it over the mouth, lowering it in, holding it
## under, drawing it up (the rest levels it); how high over the rim it is brought and drawn up to, and
## how near the floor it is lowered (meters); and the tips tried for going in, up to the most (degrees).
const DIP_PHASES := Vector4(0.25, 0.45, 0.55, 0.88)
## ...and of a pour's or a dip's way there, the share it is lifted before it turns.
const BRING_TURN_FROM := 0.2
const DIP_ABOVE := 0.02
const DIP_FLOOR := 0.012
const DIP_TIPS := 12
const DIP_TIP_MOST := 60.0
## ...the depths each is tried at, the points of its surface it is tried by at most, and how far from the far wall its bowl keeps
## (meters).
const DIP_DEPTHS := 6
const DIP_POINTS := 160
const DIP_WALL := 0.008
const POUR_BACK := 0.25
const POUR_SHARES := 20
## ...of its tipping, the least and the most share that follows its liquid's brink (its share is the
## share of the turn the brink makes): the rest turns it on to its `tip`, so what does not flow - grains,
## powder, loose pieces - slides out over the lip too.
const POUR_WET := Vector2(0.3, 0.9)
## ...and how much higher its lip is held, at most, rather than tipped early (meters).
const POUR_HIGHER := 0.015
const POUR_LIFT := 0.03
const POUR_HANDLE := 0.02
const POUR_GAP := 0.005

var things: Array = []        # [{name, node, rest, works: [i], lit, box (the thing's own), mesh (world, lazily)}]
var works: Array = []         # [{thing, name, node, w (Props._worker's work), kind, mats, color, glow}]
## A part with copies is one part to the puppeteer (a stack of slips, a bed of coals): by its name alone
## every copy is worked - a state on each, a move as one body - and by "name K" its K-th copy alone, in
## the order they were built ([method _part_of]).
var groups: Array = []        # [{thing, name, members: [work index], middle (the copies', in the first's space)}]
var _group_of := {}           # work index -> its group, for a copy
var acts: Array = []          # the episode's acts, made safe (Motions.sanitize_acts)
var notes := PackedStringArray()
var runs: Array = []          # when each act runs: [{i, t0, t1}]
var _chan := {}               # channel -> [{t0, t1, track, from, end, i}] in order of t0
var _rest := {}               # channel -> its value before anything acts on it
var _runs_of := {}            # channel -> the laws its part follows all the time
var _plumes: Array = []
var _writing := {}            # work -> what is written on it ([method _order_writing]): one write's words, or a page of them, and once drawn their skin
var _drunk := {}              # a liquid's work -> how full the drinks so far leave it ([method _drunk_from])
var _aloft_of := {}           # a channel and where a move left it -> whether it touches nothing there ([method _held_up])
var _parent_work := {}        # work index -> the work it is a part of, or -1 ([method _within])
## What posing found in the last plan ([method _timelines]): an entry's name ([method _found_key]) ->
## [its run's t0, t1, what it found ([constant FOUND])] - and the runs it was found under.
var _sheet_bends := {}        # a sheet that bends -> its meshes' [SheetBend]s, made as it is first drawn
var _laid_of: Array = []      # act -> the channels it leaves laid down ([method _laid_by]), found once for the acts
var _found_before := {}
var _still_of := {}           # "t3"/"w12" -> whether it is where it was built at every moment ([method _still])
var _runs_before: Array = []
var _solids_ref: Array = []   # the physics' solids, their fields ([method _foot]) - the twin's the bake's own, this work's copies of them
var _liquids_ref: Array = []  # ...and its vessels, each `{solid, vessel, full_v}` ([method _pour_plan])
## What the physics moves, not the acts ([TablePhysics]): each hinge that hangs free and swings by its
## weight and what lies on it - a balance's beam - and each part hung from one, kept level (`{from: the
## hinge, at: where it hangs, axis}`, its node's own space)...
var swings := {}
var hung := {}
## ...and, on the bake's own twin, where it has them as it bakes: each swinging hinge's angle (degrees),
## each part it moves as a rigid body ([RigidParts]) and each whole thing - the work itself asks the
## bake's frames ([method TablePhysics.swing_of], [method TablePhysics.thing_pose_of]).
var swung := {}
var posed := {}
var posed_things := {}
var _first_drawn := {}        # each part's node as first drawn ([method drawn_report])
## While an act is checked ([method check]), a part the work picks up is where the acts put it, never
## where the physics stopped it: what the puppeteer is told passes through something is what its acts
## would put through it.
var _planned := false
var _steady := false          # while that is found: nothing drifts
var _air = null               # the acts' cue bursts (Effects.Air), or null
var _cues: Array = []         # [{act, at, every, where, name}]
var _paint_bursts: Array = [] # what the painting throws: "dust" (a powder's puffs), "mist" (a spray's) - [TablePaint]
var _timed: Array = []        # every material on the table that follows show time: a liquid's surface, copies glowing apart
var _huffs: Array = []        # the creatures' huffs, heard and seen ([method Soundscape.seen_calls])
var _sound := {}              # the table's sound, its creatures' huffs seen ([method _build_cues])
var _moved := {}              # pose channel -> true: a thing or part some act of the episode moves ([method build]) -
                              # never what the schedule has placed so far, which a live reading's words grow
var _soft_table := {}         # ...of them, the table's own: what changes from its start, a liquid, what is loose ([method build])
var _quiet_spans := {}        # work -> the stretches it may change in, this plan, or null: any time ([method _settled])
var _drawn_of := {}           # work -> [what the physics had it as, its fill, whether whole] when it was last drawn
var _full := true             # the next frame poses every part ([method tick])
var _pose_order := PackedInt32Array()   # every work, each after the part it hangs from ([method _order_of_posing])
var _last_t := -INF
var _last_planned := false
var _last_outrun := false
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
## What is in things ([TablePhysics], next/table_physics.md): the liquids, the grains and the loose things,
## and the solids they meet - baked over show time from the schedule this keeps.
var physics: TablePhysics = null
## A probe's: whether each frame's cost is kept by section ([method _spent]), and what it came to.
var profiling := false
var profile := {}


# --- building -----------------------------------------------------------------------------------

## A new table: everything the last one worked is let go.
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
	if assembly != null:
		assembly.clear()
	assembly = null
	assembly_spec = {}
	if game != null:
		game.clear()
	game = null
	game_spec = {}
	if paint != null:
		paint.clear()
	assembly_notes = PackedStringArray()
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
	_soft_table = {}
	_quiet_spans = {}
	_drawn_of = {}
	_full = true
	_moved = {}
	_begun = {}
	_last_now = -INF
	since = 0.0
	_plan_key = ""
	_spot = Vector3.INF
	_depth = 0


## Thing [param t], built as [param b] ([method Props.build]) and stood as [param node]: its working
## parts kept, and its liquids, so they can be worked ([method TableThings.put] hands every thing here)
## - and its shade on the cloth ([param shades]: the contact shade and the slab that casts its foot's),
## which goes with it.
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
	if not (b.get("skins", []) as Array).is_empty():
		_painter().take(ti, b)
	if physics == null:
		physics = TablePhysics.new()
		physics.work = self
	physics.take(ti, t, b, node, first)


## The acts of this episode ([param raw], `acts.json` as parsed, or null) for a reading of [param beats]
## beats (a card's each, or a show's with no cards), made safe and found on the table - and everything
## the table works by itself: what runs, what smokes, the liquids' surfaces, and a puff of smoke past the
## far edge wherever the place's creatures ([param sound]'s, [Soundscape]) are heard to huff. Called once
## every thing stands.
func build(raw: Variant, beats: int, sound: Dictionary = {}) -> void:
	_root = Node3D.new()
	_root.name = "Work"
	medium._root3.add_child(_root)
	_sound = sound
	# What is built here, stood over the things as they stand ([TableAssembly]): before the acts are taken, which it answers for
	if not assembly_spec.is_empty():
		var noted := notes.size()
		assembly = TableAssembly.new(self, assembly_spec)
		assembly.stand()
		assembly_notes = notes.slice(noted)
	if not game_spec.is_empty():
		game = TableGame.new(self, game_spec, game_dir, game_seed)
		game.stand()
	if paint != null:
		paint.set_designs(skin_doc)
	_take_acts(raw, beats)
	if assembly != null:
		assembly.perform(acts)
	# What each part is before anything acts on it, and what it follows all the time
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
	_fit_acts()
	# Each thing's body, what a loose part of it is in when it is in it: the thing without its loose parts
	# - a mortar's bowl, not the corner its pestle lies in
	for ti in things.size():
		(things[ti] as Dictionary)["body"] = _body_of(ti)
	# What a tool goes into: a part that changes from its start, or a liquid, or what is loose - the table's own, kept apart from
	# what the acts add ([method _fit_acts]), so the acts can be bound again ([method rebind])
	_soft_table = {}
	for wi in works.size():
		var start: Dictionary = ((works[wi] as Dictionary)["w"] as Dictionary).get("start", {})
		# ...and what is loose: a tool pushes it about, never passes through it ([TablePhysics])
		if start.has("fill") or start.has("grow") or start.has("shown") or bool(((works[wi] as Dictionary)["w"] as Dictionary).get("loose", false)):
			_soft_table[wi] = true
		for m in (works[wi] as Dictionary)["mats"]:
			var kd: Variant = (m as ShaderMaterial).get_shader_parameter("kind")
			if kd != null and int(kd) == 13:
				_soft_table[wi] = true
	for wi in _soft_table:
		_soft[wi] = true
	# What is painted, and by which acts: each element's program and pictures, and each act that paints its length at a hand's pace
	if paint != null:
		paint.prepare()
	for ti in things.size():
		_rest["t%d:pose" % ti] = _world_rest_thing(ti)
	for wi in works.size():
		_rest["w%d:pose" % wi] = _world_of((works[wi] as Dictionary)["node"])
	# A part's copies moved as one, from where the first stands, about the middle of them all
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
	_build_cues()
	_plan_key = ""
	plan_cues()
	# Ready for the physics' own thread ([TablePhysics]): each thing's place as it stood, its surface, the
	# work's spot, which part is in which - nothing the bake reads may need a node
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
	for wi in works.size():
		_part_mesh_of(wi)
	work_spot()
	if physics != null:
		physics.build()
		for n in physics.notes:
			notes.append(n)


## The same table, other acts ([param raw], `acts.json` as parsed): what the acts decide is made again -
## the acts, their cues' bursts, what the work moves - and nothing of the table is; the physics keeps
## what it has baked and is planned again from the first moment the new acts change ([method
## TablePhysics.rebind], [method _timelines]). What a puppeteer's every `act` does ([TablePreview]), so
## no table is stood and built again for each (next/framework_audit.md).
func rebind(raw: Variant, beats: int) -> void:
	runs = []
	_chan = {}
	# ...and nothing found for the acts before: an act written again keeps its name, and may keep its times
	_laid_of = []
	_found_before = {}
	_runs_before = []
	_moved = {}
	_begun = {}
	_last_now = -INF
	_plan_key = ""
	_cues = []
	if _air != null:
		if _air.root != null and is_instance_valid(_air.root):
			_air.root.queue_free()
		_air.release()
	_air = null
	if paint != null:
		paint.set_designs(skin_doc)
	_take_acts(raw, beats)
	if assembly != null:
		assembly.perform(acts)
	_fit_acts()
	if paint != null:
		paint.prepare()
	_build_cues()
	plan_cues()
	if physics != null:
		physics.rebind()


## What standing the assembly had to say ([member assembly]), said again as the notes are made again.
var assembly_notes := PackedStringArray()


## The acts [param raw] made safe for [param beats] beats and found on the table: [member acts], [member notes], what each writes.
func _take_acts(raw: Variant, beats: int) -> void:
	var made := Motions.sanitize_acts(raw if raw != null else {}, beats)
	notes = made["notes"]
	if assembly != null:
		notes.append_array(assembly_notes)
	_aloft_of = {}
	_drunk = {}
	acts = []
	for a in made["acts"]:
		var act: Dictionary = (a as Dictionary).duplicate(true)
		var kept: Array = []
		var tracks_of: Array = act["tracks"]
		for t in (act["tracks"] as Array).duplicate():
			if String((t as Dictionary)["law"]) == "drink":
				_drunk_from(act, t as Dictionary, tracks_of)
		for t in tracks_of:
			var tr: Dictionary = t
			if String(tr["law"]) == "paint":
				tr["_act"] = String(act["name"])
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
		# ...a write by a pen seen brings the pen with it: its nib on the ink as it goes down ([method _pen_nib])
		for tr in kept.duplicate():
			if String((tr as Dictionary)["law"]) == "write" and (tr as Dictionary).has("with"):
				var pen := _pen_track(act, tr as Dictionary)
				if not pen.is_empty():
					kept.append(pen)
		# ...and the water a brush is rinsed in clouds with what is rinsed out of it ([method TablePaint.cloud_at])
		for tr in kept.duplicate():
			if String((tr as Dictionary)["law"]) == "paint" and (tr as Dictionary).has("rinse"):
				var cloud := _cloud_of(tr as Dictionary)
				if not cloud.is_empty():
					kept.append(cloud)
		act["tracks"] = _trips(act, kept)
		acts.append(act)
	_order_writing()


## What is written on each sheet, in the order it is written: the acts' writes taken a sheet at a time by
## beat, then as listed. One write of words is the sheet's alone, fitted to it ([method
## SheetWriting.node]); more than one, or a formula or a drawing, is a page ([method SheetWriting.page])
## - write K of N taking the sheet's `written` from K/N to (K+1)/N, and its picture made here, on the
## worker the table is built on, never on the frame that first shows it.
func _order_writing() -> void:
	for wr in _writing.values():
		if (wr as Dictionary).has("node") and is_instance_valid((wr as Dictionary)["node"]):
			((wr as Dictionary)["node"] as Node).queue_free()
	_writing = {}
	var order: Array = range(acts.size())
	order.sort_custom(func(a: int, b: int) -> bool:
		var ra := _beat_rank((acts[a] as Dictionary).get("beat"))
		var rb := _beat_rank((acts[b] as Dictionary).get("beat"))
		return ra < rb or (ra == rb and a < b))
	var on := {}
	var named := {}       # work -> the act that wrote each of its writes, in order
	var points: Array = []
	for i in order:
		for t in ((acts[i] as Dictionary)["tracks"] as Array):
			var tr: Dictionary = t
			if String(tr.get("law", "")) == "point":
				points.append([String((acts[i] as Dictionary)["name"]), tr])
			if String(tr.get("law", "")) == "write" and tr.has("_wi"):
				if not on.has(int(tr["_wi"])):
					on[int(tr["_wi"])] = []
					named[int(tr["_wi"])] = []
				(on[int(tr["_wi"])] as Array).append(tr)
				(named[int(tr["_wi"])] as Array).append(String((acts[i] as Dictionary)["name"]))
	for wi in on:
		var list: Array = on[wi]
		var n := list.size()
		for k in n:
			(list[k] as Dictionary)["value"] = float(k + 1) / float(n)
			# ...and which of the sheet's writes it is, for the pen that writes it ([method _pen_nib])
			(list[k] as Dictionary)["_sheet"] = int(wi)
			(list[k] as Dictionary)["_k"] = k
			(list[k] as Dictionary)["_n"] = n
		var first: Dictionary = list[0]
		var wr := {"text": first["text"], "hand": first["hand"], "ink": first["ink"]}
		# (...a page also wherever a pen seen writes, which follows the page's layout)
		if n > 1 or not TableInk.item_of_track(first).is_empty() or list.any(func(t: Dictionary) -> bool: return t.has("with")):
			var items: Array = []
			var unset := 0
			for tr in list:
				# ...a line crossed out: the earlier write it names on this sheet, by its act
				if (tr as Dictionary).has("strike"):
					var target := (named[wi] as Array).find(String((tr as Dictionary)["strike"]))
					if target < 0 or target >= items.size():
						notes.append("%s: nothing written on it before is called \"%s\", so nothing is crossed out (its writes: %s)" % [
							String((works[wi] as Dictionary)["name"]), String((tr as Dictionary)["strike"]), ", ".join(PackedStringArray(named[wi]))])
					items.append({"strike": target if target >= 0 and target < items.size() else -1})
					continue
				var it := TableInk.item_of_track(tr as Dictionary)
				if it.is_empty():
					items.append({"text": String((tr as Dictionary)["text"]), "hand": String((tr as Dictionary)["hand"])})
					continue
				var rec := TableInk.record_in(ink_doc, it)
				if rec.is_empty():
					unset += 1
					items.append({"text": " ", "hand": String((tr as Dictionary)["hand"])})
				else:
					items.append({"rec": rec})
			var sheet: Dictionary = ((works[wi] as Dictionary)["w"] as Dictionary)["sheet"]
			wr["page"] = SheetWriting.page(items, SheetWriting.room_of(sheet), ink_seed, ink_doc.get("fonts", {}) if ink_doc.get("fonts") is Dictionary else {})
			var name := String((works[wi] as Dictionary)["name"])
			# (...none laid out at all is the ink step still to come, which is no fault: only what TeX refused is said)
			if unset > 0 and not ink_doc.is_empty():
				notes.append("%s: TeX could not set %d of its %d writes, so they are left blank - write them so they set" % [name, unset, n])
			if bool((wr["page"] as Dictionary)["shrunk"]):
				notes.append("%s: its %d writes run off the sheet, so they are written smaller to fit - write the rest on another sheet" % [name, n])
			var laid: Array = ((wr["page"] as Dictionary)["layout"] as Dictionary)["items"]
			for k in mini(laid.size(), (named[wi] as Array).size()):
				(laid[k] as Dictionary)["act"] = String(named[wi][k])
		_writing[wi] = wr
	# What each point points at, found on its page now the pages are laid ([method _point_nib]) - or said, while it can be put right
	for pair in points:
		if (pair[1] as Dictionary).has("_ch") and not (pair[1] as Dictionary).has("_tip"):
			_tool_ends(pair[1] as Dictionary)
		var why := _find_pointed(pair[1] as Dictionary)
		if not why.is_empty():
			notes.append("%s: %s" % [String(pair[0]), why])


## The pen that writes [param tr] (its `with`, "thing" or "thing/part"), as a track of act [param act] on
## the pen's own pose - its nib where the ink goes down ([method _pen_nib]) - or `{}`, said, where there
## is no such pen.
func _pen_track(act: Dictionary, tr: Dictionary) -> Dictionary:
	var said := String(tr["with"])
	var cut := said.find("/")
	var pen := {"law": "pen", "thing": said.substr(0, cut) if cut >= 0 else said, "between": tr.get("between", Vector2(0.0, 1.0)),
		"_write": tr}
	if cut >= 0:
		pen["part"] = said.substr(cut + 1)
	var why := _resolve(pen)
	if not why.is_empty():
		notes.append("%s: its pen - %s" % [String(act["name"]), why])
		return {}
	pen.erase("_copies")
	_tool_ends(pen)
	return pen


## A held tool's ends, found once as the table is built and kept on its track [param tr] (`_tip`, `_grip`:
## its node's space) - by a painter of its own ([method TablePaint.tool_of]: its points `tip` and `grip`,
## else the ends of its length), so the bake's twin, which poses it on another thread, never reads the
## tool's nodes while the app's thread moves them.
func _tool_ends(tr: Dictionary) -> void:
	var tool := TablePaint.new(self).tool_of(String(tr["_ch"]), tr)
	tr["_tip"] = tool.get("tip", Vector3.ZERO)
	tr["_grip"] = tool.get("grip", Vector3.UP * 0.1)
	# ...a whole thing held by a point one of its parts names (a pen's nib on its body): that point, in the thing's own space
	if tr.has("_ti") and not tr.has("_wi"):
		var ti := int(tr["_ti"])
		var inv := _world_of((things[ti] as Dictionary)["node"]).affine_inverse()
		for wi in (things[ti] as Dictionary)["works"]:
			var pts: Dictionary = ((works[wi] as Dictionary)["w"] as Dictionary).get("points", {})
			for k in pts:
				if String(k).to_lower() in ["tip", "grip"]:
					tr["_" + String(k).to_lower()] = inv * (_world_of((works[wi] as Dictionary)["node"]) * (pts[k] as Vector3))


## What point [param tr] points at, found on its page: its sheet (`on`) and the box there of what it names
## (`at`: a formula's part written as `\pin{name}{...}`, a drawing's element by its id, or the act that
## wrote the line), kept as `_pointed` - "" found, else why not, naming what can be pointed at.
func _find_pointed(tr: Dictionary) -> String:
	tr.erase("_pointed")
	var on := String(tr["on"])
	var cut := on.find("/")
	var ti := _thing_named(on.substr(0, cut) if cut >= 0 else on)
	if ti < 0:
		return "it points at \"%s\", and no thing on the table is called that" % on
	var wi := -1
	if cut >= 0:
		wi = int(_part_of(ti, on.substr(cut + 1))["wi"])
	else:
		for w in (things[ti] as Dictionary)["works"]:
			if ((works[w] as Dictionary)["w"] as Dictionary).has("sheet"):
				wi = int(w)
				break
	if wi < 0 or not _writing.has(wi) or not (_writing[wi] as Dictionary).has("page"):
		return "it points at \"%s\", where nothing is written by then" % on
	var at := String(tr["at"]).strip_edges()
	var names := PackedStringArray()
	for it in (((_writing[wi] as Dictionary)["page"] as Dictionary)["layout"] as Dictionary)["items"]:
		var d: Dictionary = it
		for nm in (d["anchors"] as Dictionary):
			names.append(String(nm))
			if String(nm).to_lower() == at.to_lower():
				tr["_pointed"] = {"sheet": wi, "box": (d["anchors"] as Dictionary)[nm]}
				return ""
		if d.has("act"):
			names.append(String(d["act"]))
			if String(d["act"]).to_lower() == at.to_lower():
				tr["_pointed"] = {"sheet": wi, "box": Rect2(float(d["x"]), float(d["y"]), float(d["w"]), float(d["h"]))}
				return ""
	return "nothing written on \"%s\" is called \"%s\" (what can be pointed at there: %s)" % [on, at, ", ".join(names) if not names.is_empty() else "nothing yet"]


## Where a pen's nib is at show time [param T] as it writes ([param tr], a write's pen, [method
## _pen_track]): `{sheet, at (the page's TeX points), lift (meters)}` - or `{}`. It follows the sheet's
## own `written`, so it is always where the ink is going down: coming down to the first stroke in the
## write's lead, on each stroke as far along it as the ink is, lifted between strokes, and lifted clear
## to the right of what it wrote in the tail ([constant SheetWriting.PEN_LEAD]).
func _pen_nib(tr: Dictionary, T: float) -> Dictionary:
	var w: Dictionary = tr["_write"]
	var wi := int(w.get("_sheet", -1))
	if wi < 0 or not _writing.has(wi) or not (_writing[wi] as Dictionary).has("page"):
		return {}
	var laid: Array = (((_writing[wi] as Dictionary)["page"] as Dictionary)["layout"] as Dictionary)["items"]
	var k := int(w["_k"])
	if k >= laid.size():
		return {}
	var it: Dictionary = laid[k]
	var g := clampf(float(value("w%d:written" % wi, T)) * float(w["_n"]) - float(k), 0.0, 1.0)
	var lead := float(it["lead"])
	var ink := float(it["ink"])
	var first := _stroke_point(it, 0.0)
	var last := _stroke_point(it, float(it["seconds"]))
	if g < lead:
		return {"sheet": wi, "at": first["at"], "lift": lerpf(Pen.REST_LIFT, 0.0, smoothstep(0.0, 1.0, g / maxf(lead, 1e-6)))}
	if g <= lead + ink:
		var at := _stroke_point(it, (g - lead) / maxf(ink, 1e-6) * float(it["seconds"]))
		return {"sheet": wi, "at": at["at"], "lift": float(at["lift"])}
	var s := smoothstep(0.0, 1.0, (g - lead - ink) / maxf(1.0 - lead - ink, 1e-6))
	return {"sheet": wi, "at": (last["at"] as Vector2).lerp(Pen.rest_near(last["at"]), s), "lift": lerpf(0.0, Pen.REST_LIFT, s)}


## Where the hand's nib is [param t] seconds into item [param it]'s writing ([method SheetWriting.page]'s layout): `{at (the page's TeX
## points), lift}` - on its strokes as [method Pen.on_strokes] has it, and along a line of words in a hand.
static func _stroke_point(it: Dictionary, t: float) -> Dictionary:
	var strokes: Array = it.get("strokes", [])
	if strokes.is_empty():
		# words in a hand: line by line, left to right, as their picture is put down
		var lines := maxi(int(it.get("lines", 1)), 1)
		var f := clampf(t / maxf(float(it["seconds"]), 1e-6), 0.0, 0.999) * float(lines)
		var li := floori(f)
		return {"at": Vector2(float(it["x"]) + (f - float(li)) * float(it["w"]), float(it["y"]) + (float(li) + 0.78) * float(it["h"]) / float(lines)),
			"lift": 0.0}
	var nib := Pen.on_strokes(strokes, t)
	return {"at": Vector2(float(it.get("ox", 0.0)), float(it.get("oy", 0.0))) + (nib["at"] as Vector2), "lift": float(nib["lift"])}


## Where a point holds the nib [param tau] of [param d] seconds into its act: along [method Pen.point_path] of what it
## points at, swept once the hand has brought it there ([constant BLEND_IN]). `{sheet, at, lift}`, or `{}` for a point that
## found nothing ([method _find_pointed]).
func _point_nib(tr: Dictionary, tau: float, d: float) -> Dictionary:
	if not (tr.get("_pointed") is Dictionary):
		return {}
	var pointed: Dictionary = tr["_pointed"]
	return {"sheet": int(pointed["sheet"]), "at": Pen.pointing(Pen.point_path(pointed["box"]), tau - BLEND_IN, d - BLEND_IN),
		"lift": Pen.POINT_LIFT}


## A point of sheet [param wi]'s page ([param at], TeX points from the head of its room) in the table's
## space at show time [param T], [param lift] meters off the paper - on the sheet as it lies, bent and
## folded, wherever it has been moved to.
func _page_world(wi: int, at: Vector2, lift: float, T: float) -> Vector3:
	var sheet: Dictionary = ((works[wi] as Dictionary)["w"] as Dictionary)["sheet"]
	var scale := float((((_writing[wi] as Dictionary)["page"] as Dictionary)["layout"] as Dictionary)["scale"])
	var room := SheetWriting.room_of(sheet)
	var w := float(sheet["w"])
	var l := float(sheet["l"])
	var x := float(sheet["x0"]) - room.x * 0.5 + at.x * scale
	var z := float(sheet["z0"]) + l * 0.5 - room.y * 0.5 + at.y * scale
	var y := float(sheet["thick"]) + SheetWriting.ABOVE + Props.sheet_lift(x - float(sheet["x0"]), z - float(sheet["z0"]), w, l,
		float(sheet["bend"]), float(sheet["fold"]))
	var place: Transform3D = sheet["place"]
	var world := _work_world(wi, T)
	return world * (place * Vector3(x, y, z)) + (world.basis * place.basis * Vector3.UP).normalized() * lift


## The pen held by its tip with its nib at [param nib] (`{sheet, at, lift}`) at show time [param T], [param before] where it
## was [constant Pen.MOTION_DT] earlier: its tip and grip as a tool's are found ([method _tool_ends]), its body leaning from
## the nib as a writer's hand holds it ([method Pen.lean]) and drifting while it is lifted ([method Pen.drift]) - [param x0]
## its rest.
func _held_by_tip(tr: Dictionary, nib: Dictionary, before: Dictionary, T: float, x0: Transform3D) -> Transform3D:
	var wi := int(nib["sheet"])
	var lift := float(nib["lift"])
	var seed := int(tr.get("_hand", 0))
	var A := _page_world(wi, nib["at"], lift, T)
	var motion := Vector3.ZERO
	if not before.is_empty() and int(before["sheet"]) == wi:
		motion = (A - _page_world(wi, before["at"], float(before["lift"]), T - Pen.MOTION_DT)) / Pen.MOTION_DT
	var pt: Vector2 = (((_writing[wi] as Dictionary)["page"] as Dictionary)["layout"] as Dictionary)["pt"]
	var up := Pen.lean(Pen.UP, T, seed, (nib["at"] as Vector2).x / maxf(pt.x, 1e-6), motion)
	return Pen.held(x0, tr.get("_tip", Vector3.ZERO), tr.get("_grip", Vector3.UP * 0.1), A + Pen.drift(T, seed, lift), up)


## What is written, for the bake's twin ([TablePhysics]): each page's layout - made once and never
## written again - in dictionaries of its own, so the pen and what points are posed alike on the twin, and
## the app's thread, which adds each page's skin to the work's own when it is first drawn, shares nothing
## it writes with the bake.
func pages_for_twin() -> Dictionary:
	var out := {}
	for wi in _writing:
		if (_writing[wi] as Dictionary).has("page"):
			out[wi] = {"page": {"layout": ((_writing[wi] as Dictionary)["page"] as Dictionary)["layout"]}}
	return out


## Where beat [param b] comes in the reading: the intro first, the close last, a numbered beat in its place.
static func _beat_rank(b: Variant) -> int:
	if b is String and String(b) == "intro":
		return 0
	if b is String and String(b) == "close":
		return 1 << 30
	return int(b) if (b is int or b is float or (b is String and String(b).is_valid_int())) else 1 << 29


## How much water cloud track [param tr] ([method _cloud_of]) clouds, milliliters: its vessel's as the
## physics found it drawn, or a glass's ([constant TablePaint.WATER_ML]).
func _water_ml(tr: Dictionary) -> float:
	if physics != null:
		for L in physics.liquids:
			if int((L as Dictionary)["wi"]) == int(tr.get("_wi", -2)) and float((L as Dictionary)["built_v"]) > 0.0:
				return float((L as Dictionary)["built_v"]) * 1e6
	return TablePaint.WATER_ML


## The water paint track [param tr] rinses its brush in, as a track of its own on the water's color - or
## empty where what it names holds no liquid with a name.
func _cloud_of(tr: Dictionary) -> Dictionary:
	var rinse := String(tr.get("rinse", ""))
	var ti := _thing_named(rinse.get_slice("/", 0))
	if ti < 0:
		return {}
	var want := rinse.get_slice("/", 1).to_lower() if rinse.contains("/") else ""
	var liquid := int(Props.MATERIALS["liquid"]["code"])
	for wv in (things[ti] as Dictionary)["works"]:
		var wk: Dictionary = works[int(wv)]
		var nm := String(wk["name"])
		if nm.is_empty() or (not want.is_empty() and nm.to_lower() != want):
			continue
		for m in wk["mats"]:
			var kd: Variant = (m as ShaderMaterial).get_shader_parameter("kind")
			if kd != null and int(kd) == liquid:
				var track := {"thing": String((things[ti] as Dictionary)["name"]), "part": nm, "state": "tint", "law": "cloud", "_with": tr}
				return track if _resolve(track).is_empty() else {}
	return {}


## What drink [param tr] of act [param act] takes: as much of what is in it as it says goes while it is out
## of sight, by a `to` on each liquid's fill, added to [param tracks], one drink after another. A stretch
## too short for a hand to get there and back is made long enough, if the act has a length of its own.
func _drunk_from(act: Dictionary, tr: Dictionary, tracks: Array) -> void:
	var w: Vector2 = tr["between"]
	if act.get("length") is float and float(act["length"]) * (w.y - w.x) < DRINK_LEAST:
		act["length"] = DRINK_LEAST / (w.y - w.x)
	var ti := _thing_named(String(tr.get("thing", "")))
	if ti < 0:
		return
	var liquid := int(Props.MATERIALS["liquid"]["code"])
	var found := false
	for wv in (things[ti] as Dictionary)["works"]:
		var wi := int(wv)
		var w_d: Dictionary = (works[wi] as Dictionary)["w"]
		var is_liquid := false
		for m in (works[wi] as Dictionary)["mats"]:
			var kd: Variant = (m as ShaderMaterial).get_shader_parameter("kind")
			if kd != null and int(kd) == liquid:
				is_liquid = true
		if not is_liquid or String(w_d.get("name", "")).is_empty():
			continue
		found = true
		var now: float = float(_drunk.get(wi, float((w_d.get("start", {}) as Dictionary).get("fill", 1.0))))
		_drunk[wi] = now * (1.0 - float(tr["sip"]))
		tracks.append({"thing": tr["thing"], "part": String(w_d["name"]), "law": "to", "state": "fill", "value": float(_drunk[wi]), "ease": "both",
			"between": Vector2(lerpf(w.x, w.y, DRINK_UP + 0.03), lerpf(w.x, w.y, 1.0 - DRINK_UP - 0.03))})
	if not found:
		notes.append("%s: \"%s\" has no liquid with a `name` in it: it is drunk from, and nothing goes down" % [String(act["name"]), String(tr.get("thing", ""))])


## What the acts come to on this table: a part that runs never turned again, each move its own hand, what the work moves.
func _fit_acts() -> void:
	_still_of = {}
	# A part that runs is not turned again by an act: a turn on it would run it twice as fast
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
	# Each move its own hand ([Hands]). Equal animation data is not a physical attachment: two jars can take the same path
	# independently. A seated cork rides its jar through the physics' seat constraint, not a second kinematic weld.
	for a in acts:
		var tracks: Array = a["tracks"]
		for k in tracks.size():
			var tr: Dictionary = tracks[k]
			var hs := hash([medium._plan.seed_value, String(a["name"]), k])
			tr["_hand"] = hs
			for end in ["tip", "grip"]:
				if tr.get(end) is Dictionary:
					(tr[end] as Dictionary)["_hand"] = hs
	# What the work moves, from every act, scheduled or not: a loose part an act will pick up lies where it
	# was put until then - a live reading places an act only as its words are heard, so a part riding its
	# thing until then would jump back to its corner
	for a in acts:
		for t in a["tracks"]:
			var ch := String((t as Dictionary).get("_ch", ""))
			if ch.ends_with(":pose"):
				_moved[ch] = true
	# What a tool goes into: the table's own ([member _soft_table]) and a part an act makes change - fills, grows, comes and goes (a
	# heap of herbs ground down): a pestle pressed into it goes into it, never through it
	_soft = _soft_table.duplicate()
	for a in acts:
		for t in a["tracks"]:
			var tr: Dictionary = t
			if String(tr.get("_ch", "")).get_slice(":", 1) in ["fill", "grow", "shown"]:
				_soft[int(tr["_wi"])] = true


## The bursts the acts' cues throw, and the creatures' huffs as they are heard ([member _sound]) - a rebind's made again.
func _build_cues() -> void:
	# The bursts an act's cues throw
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
	# The creatures, seen as they are heard: their huffs' times from the sound's own plan
	_huffs = Soundscape.seen_calls(_sound, medium._plan.seed_value, 0.0, HUFFS_UNTIL) if _sound.get("creatures") is Array else []
	if not _huffs.is_empty():
		fxs.append({"kind": "burst", "name": "huffs", "on": "huffs", "look": "smoke", "count": 10, "size": 24.0,
			"speed": 0.35, "spread": 35.0, "life": 2.6, "glow": 0.0, "colors": ["#8f8b86", "#a6a29c"]})
		moments.append("huffs")
	# The puffs a powder raises as it is patted on and swept off ([TablePaint])
	_paint_bursts = []
	if paint != null and paint.raises("mist"):
		_paint_bursts.append("mist")
		fxs.append({"kind": "burst", "name": "paint mist", "on": "paint mist", "look": "mist", "count": 120, "size": 0.9,
			"speed": 0.5, "spread": 22.0, "life": 1.2, "glow": 0.0, "colors": ["#f4f8ff", "#e8eef4"]})
		moments.append("paint mist")
	if paint != null and paint.raises("dust"):
		_paint_bursts.append("dust")
		# (one faint cloud of many soft puffs laid over each other, never a few bright ones, nor puffs that
		# wander in loops: it billows out a little and sinks)
		fxs.append({"kind": "burst", "name": "paint dust", "on": "paint dust", "look": "powder", "count": 20, "size": 9.0,
			"speed": 0.08, "spread": 150.0, "life": 3.0, "glow": 0.0, "colors": ["#f4efe8", "#e6dfd6"]})
		moments.append("paint dust")
	if not fxs.is_empty():
		var made_fx := Effects.sanitize(fxs, [], [], moments)
		if not made_fx.is_empty():
			_air = Effects.build(made_fx, medium._air_stage(), hash([medium._plan.seed_value, "work cues"]))
			_root.add_child(_air.root)


## Where [param track]'s law acts, found on the table: its `_ch` (a channel - `w3:angle`, `t1:pose`...) - "" when
## found, else why not. A sprinkle has none: the physics lets its grains fall.
func _resolve(track: Dictionary) -> String:
	var law := String(track["law"])
	if law == "assemble":
		# its steps are the assembly's, on no channel of the work's
		if assembly == null:
			return "this table has no `assembly` for it to work on"
		return ""
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
	var pose := law in ["circle", "aim", "carry", "pour", "dip", "drink", "paint", "pen", "point"] or (law == "path" and _path_moves(track))
	if pose and part.is_empty() and assembly != null and assembly.holds_stock(String((things[ti] as Dictionary)["name"])):
		return "\"%s\" holds the assembly's pieces, which are not its parts: it stays where it stands" % String(track["thing"])
	var state := String(track.get("state", ""))
	if part.is_empty():
		if not pose:
			# a state with no part: every part of the thing that can take it
			return "a %s names no part of \"%s\" - name one (its parts: %s)" % [law, String(track["thing"]), _part_names(ti)]
		if bool((things[ti] as Dictionary)["lit"]):
			return "\"%s\" holds a flame, which stays where it was lit: it is never moved whole" % String(track["thing"])
		track["_ch"] = "t%d:pose" % ti
		track["_ti"] = ti
		return _painted(track)
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
	# A loose thing's size is its own: ground, it breaks, never shrinks with `grow` while the pestle goes round over it
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
		return _painted(track)
	match kind:
		"hinge":
			track["_ch"] = "w%d:angle" % wi
		"slide":
			track["_ch"] = "w%d:offset" % wi
		_:
			return "\"%s\" of \"%s\" has no hinge or slide for a %s to turn, and the track names no `state`" % [part, String(track["thing"]), law]
	return ""


## A paint track [param track] found on what it paints ([method TablePaint.resolve]) - "" for any other law.
func _painted(track: Dictionary) -> String:
	if String(track["law"]) != "paint":
		return ""
	if String(track.get("_ch", "")).begins_with("g"):
		return "a part's copies paint nothing together: name one (\"%s 1\")" % String(track.get("part", ""))
	return _painter().resolve(track)


## The table's painting, made when first asked ([TablePaint]).
func _painter() -> TablePaint:
	if paint == null:
		paint = TablePaint.new(self)
	return paint


## A thing is one only as far as something holds it together (next/table_physics.md, "Primitives"): a
## hand moving a thing whole grips what is fixed to it - its own unjointed geometry - and what stands free
## in it or on it (a `free` joint: a jar, a cork, a ladle on its rest) rides that as a body of its own, or
## does not. A thing with nothing fixed to it - four jars side by side with no tray under them - is the
## hand's trips: act [param act_name]'s whole moves of it (its [param tracks]) made by its free parts
## one at a time, each to its own place in the arrangement. Each trip keeps the original move's
## duration; the act grows to make room, and the reading's scheduler cannot quicken it below that
## duration. A part of one of them moved with it in the same stretch (a cork fetched with its jar) goes
## in its jar's trip.
func _trips(act: Dictionary, tracks: Array) -> Array:
	var act_name := String(act["name"])
	var by_thing := {}
	for k in tracks.size():
		var tr: Dictionary = tracks[k]
		if tr.has("_ti") and String(tr["law"]) in ["carry", "path"] and not _grippable(int(tr["_ti"])):
			if not by_thing.has(int(tr["_ti"])):
				by_thing[int(tr["_ti"])] = []
			(by_thing[int(tr["_ti"])] as Array).append(k)
	if by_thing.is_empty():
		return tracks
	var out: Array = []
	var gone := {}
	var trips := 1
	for ti in by_thing:
		var ks: Array = by_thing[ti]
		var parts := _trip_parts(int(ti))
		var names := PackedStringArray()
		for wi in parts:
			names.append(String((works[wi] as Dictionary)["name"]))
		if parts.is_empty():
			notes.append("%s: \"%s\" has nothing fixed to it and no free part to carry: a hand finds nothing of it to move" % [act_name, String((things[ti] as Dictionary)["name"])])
			for k in ks:
				gone[k] = true
			continue
		notes.append("%s: \"%s\" has nothing that holds its %d parts together (%s) - moved one at a time, with time for each trip" % [
			act_name, String((things[ti] as Dictionary)["name"]), parts.size(), ", ".join(names)])
		trips = maxi(trips, parts.size())
		var lo := INF
		var hi := -INF
		for k in ks:
			var w := _window(tracks[k])
			lo = minf(lo, w.x)
			hi = maxf(hi, w.y)
		var span := maxf(hi - lo, 1e-3)
		var share := span / float(parts.size())
		# ...and its parts' own moves in that stretch, made in their trip
		var riders := {}
		for k in tracks.size():
			var tr: Dictionary = tracks[k]
			if ks.has(k) or not tr.has("_wi") or not String(tr.get("_ch", "")).ends_with(":pose"):
				continue
			var w := _window(tr)
			if w.y <= lo or w.x >= hi:
				continue
			for pi in parts.size():
				if _node_within((works[int(tr["_wi"])] as Dictionary)["node"], (works[parts[pi]] as Dictionary)["node"]):
					riders[k] = pi
					gone[k] = true
		for pi in parts.size():
			var wi := int(parts[pi])
			var a := lo + share * float(pi)
			var remap := func(u: float) -> float: return a + (u - lo) * (share / span)
			for k in ks:
				var tr: Dictionary = (tracks[k] as Dictionary).duplicate(true)
				tr.erase("_ti")
				tr["part"] = String((works[wi] as Dictionary)["name"])
				tr["_wi"] = wi
				tr["_ch"] = "w%d:pose" % wi
				tr["_trip"] = int(ti)
				if String(tr["law"]) == "carry":
					var w: Vector2 = tr["between"]
					tr["between"] = Vector2(remap.call(w.x), remap.call(w.y))
				else:
					for key in tr["keys"]:
						(key as Dictionary)["at"] = remap.call(float((key as Dictionary)["at"]))
				out.append(tr)
			for k in riders:
				if int(riders[k]) != pi:
					continue
				var tr: Dictionary = (tracks[k] as Dictionary).duplicate(true)
				if tr.get("between") is Vector2:
					var w: Vector2 = tr["between"]
					tr["between"] = Vector2(remap.call(clampf(w.x, lo, hi)), remap.call(clampf(w.y, lo, hi)))
				elif tr.get("keys") is Array:
					for key in tr["keys"]:
						(key as Dictionary)["at"] = remap.call(clampf(float((key as Dictionary)["at"]), lo, hi))
				out.append(tr)
		for k in ks:
			gone[k] = true
	var kept: Array = []
	for k in tracks.size():
		if not gone.has(k):
			kept.append(tracks[k])
	if trips > 1:
		act["length"] = float(act["length"]) * float(trips)
		act["_min_length"] = act["length"]
	return kept + out


## Whether a hand moving thing [param ti] whole grips anything of it: any of it drawn that is in none of its free or loose parts.
func _grippable(ti: int) -> bool:
	var th: Dictionary = things[ti]
	var free: Array = []
	for wi in th["works"]:
		var wk: Dictionary = works[wi]
		if String(wk["kind"]) == "free" or bool((wk["w"] as Dictionary).get("loose", false)):
			free.append(wk["node"])
	for m in th["meshes"]:
		var mi := m as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		if free.any(func(n: Node3D) -> bool: return _node_within(mi, n)):
			continue
		return true
	return false


## THING [param ti]'s parts a hand carries one by one: each free part of it in no other free part of it, not loose.
func _trip_parts(ti: int) -> Array:
	var th: Dictionary = things[ti]
	var free: Array = []
	for wi in th["works"]:
		var wk: Dictionary = works[wi]
		if String(wk["kind"]) == "free" and not bool((wk["w"] as Dictionary).get("loose", false)) and not _group_of.has(wi):
			free.append(wi)
	var out: Array = []
	for wi in free:
		var inner := false
		for o in free:
			if o != wi and _node_within((works[wi] as Dictionary)["node"], (works[o] as Dictionary)["node"]):
				inner = true
				break
		if not inner:
			out.append(wi)
	return out


## Whether [param n] is [param of] or hangs from it.
static func _node_within(n: Node, of: Node) -> bool:
	return n == of or of.is_ancestor_of(n)


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


## What is in things outrun: whether a live show at [param t] is past the last frame [member physics]
## has baked and the work has held loose work [param wi] since that frame - then it is where the work has
## it, never where the bake last saw it. A live reading's bake can fall behind the reading, and a plan
## changed as its words arrive is baked again from the change.
func _outran(wi: int, t: float) -> bool:
	return _outran_ch(["w%d:pose" % wi, "g%d:pose" % int(_group_of.get(wi, -1))], t)


## ...of whatever channels [param chans] move: a part's, its group's, a whole thing's.
func _outran_ch(chans: Array, t: float) -> bool:
	var baked := physics.baked_to()
	if t <= baked:
		return false
	for ch in chans:
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


## A place a law names ([method Motions._place]) in meters in the table's space: [x, y, z] centimeters
## from the middle of the reading, the work's spot (`work`, [method work_spot]), or a thing's point by name
## (`thing.point`; `top`, `middle` and `base` of any thing too) where the thing is at show time [param T]
## - a mortar carried to the middle is ground in there ([method _thing_world]); where it stood, for NAN.
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


## The work's spot ([method TablePlan.work_spot]): the middle of the picture, clear of the cards' places
## and of everything standing on the table - where a thing is brought to be worked. Found once.
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


## Thing [param ti] where it is at show time [param T], in the table's space: moved by the work, or as it
## stood (for NAN, or a thing nothing moves). A pure function of the schedule - never the node as it was
## last posed. On the bake's twin, a thing an act moves is where the bake has it, a rigid body ([member
## posed_things]).
func _thing_world(ti: int, T: float) -> Transform3D:
	if not is_nan(T) and posed_things.has(ti):
		return posed_things[ti]
	var ch := "t%d:pose" % ti
	if is_nan(T) or not _chan.has(ch) or _depth > PLACE_DEPTH:
		return _world_rest_thing(ti)
	_depth += 1
	var x: Transform3D = value(ch, T)
	_depth -= 1
	return x


## Work [param wi] where it is at show time [param T]: a free part moved by the work where it was moved
## (riding its thing when it was left in it, [method _ridden]), any other part where the part it is a part
## of has it - or its thing - turned on its own joint ([method _joint]): a balance's pan where its beam
## has tipped it, so a lump laid on the pan moves with it. A part the physics moves as a rigid body is
## where the bake has it, on the bake's twin ([member posed]).
func _work_world(wi: int, T: float) -> Transform3D:
	if not is_nan(T) and posed.has(wi):
		return posed[wi]
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
	return _base_world(wi, T) if is_nan(T) else _base_world(wi, T) * _joint(wi, T)


## Work [param wi] where the part it is a part of (or its thing) has it at show time [param T], before its own joint.
func _base_world(wi: int, T: float) -> Transform3D:
	var wk: Dictionary = works[wi]
	var at_rest: Transform3D = _rest["w%d:pose" % wi] if _rest.has("w%d:pose" % wi) else _world_of(wk["node"])
	var pw := int(_parent_work.get(wi, -1))
	if pw >= 0 and _rest.has("w%d:pose" % pw):
		return _work_world(pw, T) * (_rest["w%d:pose" % pw] as Transform3D).affine_inverse() * at_rest
	var ti := int(wk["thing"])
	return _thing_world(ti, T) * _world_rest_thing(ti).affine_inverse() * at_rest


## Work [param wi]'s joint at show time [param t], in its node's own space: a hinge turned about its pivot
## by its angle, a slide moved along its axis - a hinge that swings free by its own weight where the
## physics has it - and a part hung from a swinging hinge turned back about where it hangs, so it hangs
## level as the beam tips (a balance's pans).
func _joint(wi: int, t: float) -> Transform3D:
	var wk: Dictionary = works[wi]
	var jt: Dictionary = (wk["w"] as Dictionary).get("joint", {}) if (wk["w"] as Dictionary).get("joint") is Dictionary else {}
	match String(wk["kind"]):
		"hinge":
			var b := Basis(jt["axis"] as Vector3, deg_to_rad(_angle(wi, t)))
			var pv: Vector3 = jt["pivot"]
			return Transform3D(b, pv - b * pv)
		"slide":
			var o := float(value("w%d:offset" % wi, t)) * 0.01
			var rg: Variant = jt.get("range")
			if rg is Vector2:
				o = clampf(o, (rg as Vector2).x * 0.01, (rg as Vector2).y * 0.01)
			return Transform3D(Basis.IDENTITY, (jt["axis"] as Vector3) * o)
	if hung.has(wi):
		var h: Dictionary = hung[wi]
		var b := Basis(h["axis"] as Vector3, -deg_to_rad(_angle(int(h["from"]), t)))
		return Transform3D(b, (h["at"] as Vector3) - b * (h["at"] as Vector3))
	return Transform3D.IDENTITY


## Hinge [param wi]'s angle at show time [param t] (degrees), held to its range: where its acts turn it - or, one that
## swings by its own weight ([member swings]), where the physics has swung it.
func _angle(wi: int, t: float) -> float:
	var a := 0.0
	if swings.has(wi):
		if physics != null:
			var s: Variant = physics.swing_of(wi, t)
			a = float(s) if s != null else float(swings[wi])
		else:
			a = float(swung.get(wi, swings[wi]))
	else:
		a = float(value("w%d:angle" % wi, t))
	var rg: Variant = (((works[wi] as Dictionary)["w"] as Dictionary).get("joint", {}) as Dictionary).get("range")
	if rg is Vector2:
		a = clampf(a, (rg as Vector2).x, (rg as Vector2).y)
	return a


## A loose part rides its thing: a free part let go in its own thing (a pestle left in its mortar), or
## standing in it as built and not yet picked up, goes with the thing when the thing is moved after -
## [param x], its place as the work left it, carried as the thing has been since; one laid down anywhere
## else stays where it was laid. While a track holds it, it is where the track has it.
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
	# Not yet picked up, it is where it was built: in its thing (a pestle standing in its bowl), it goes
	# where the thing is carried
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
## centimeters above it - the thing where it is at show time [param T], its surface carried there - or as
## it was where nothing is below it.
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


## Thing [param ti]'s surface as it stood, for a ray to meet: made once, whatever the work has posed it at since.
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
	th["mesh_box"] = _faces_box(faces)
	return tm


## Free part [param wi]'s surface as it was built (the table's space), for a ray to meet where the part
## is at a moment ([method _top_under]) - a thing's own mesh leaves its free parts out, so a jar fetched
## on its own, or a ladle on its rest, would stand in nothing a hand carried over or set down onto. Its
## own free parts left out; null for a loose part or one that is not free.
func _part_mesh_of(wi: int) -> TriangleMesh:
	var wk: Dictionary = works[wi]
	if wk.has("mesh"):
		return wk["mesh"]
	wk["mesh"] = null
	if String(wk["kind"]) != "free" or bool((wk["w"] as Dictionary).get("loose", false)):
		return null
	var node: Node3D = wk["node"]
	var inner: Array = []
	for o in works.size():
		if o != wi and String((works[o] as Dictionary)["kind"]) == "free" and _node_within((works[o] as Dictionary)["node"], node):
			inner.append((works[o] as Dictionary)["node"])
	var to_rest := (_rest["w%d:pose" % wi] as Transform3D) * _world_of(node).affine_inverse()
	var faces := PackedVector3Array()
	var stack: Array = [node]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n != node and inner.has(n):
			continue
		stack.append_array(n.get_children())
		var mi := n as MeshInstance3D
		if mi == null or mi.mesh == null or _is_soft(mi):
			continue
		var xf := to_rest * _world_of(mi)
		for q in mi.mesh.get_faces():
			faces.append(xf * q)
	if not faces.is_empty():
		wk["mesh"] = _ray_mesh(faces)
		wk["mesh_box"] = _faces_box(faces)
	return wk["mesh"]


## A mesh rays are cast on, from [param faces] (meters): kept in centimeters ([constant RAY_SCALE]).
## Godot's ray and triangle test takes a triangle whose edges' product is under its epsilon (0.00001) for
## one the ray runs along - in meters, a lathe's slivers round its axis and a bowl's two-centimeter floor
## would be missed. Cast on with [method _ray].
## What [param faces] fill (meters): a ray mesh's box ([method _meshes_at]).
static func _faces_box(faces: PackedVector3Array) -> AABB:
	var box := AABB(faces[0], Vector3.ZERO)
	for q in faces:
		box = box.expand(q)
	return box


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

## Which act each cue starts (next/editing.md step 2: words do not name the work's place in line):
## [param cues] as [method CardReading.parse] gives them, each named for the act it starts - its own name
## where an act is called that, else the next act not yet cued that lays the layer it names (an act made
## from a painting is named by its place in line, which a repaint changes; its layers keep their names).
## A cue naming neither is left as it is, and starts nothing: the problem a Timeline says ([method
## TableEpisode.timeline]). -> the cues, each a copy, `name` the act's.
static func resolve_cues(cues: Array, acts: Array) -> Array:
	var named := {}
	for a in acts:
		named[String((a as Dictionary).get("name", ""))] = true
	var out: Array = []
	var after := -1          # the act the last layer cue started: a later one starts an act after it
	var claimed := {}
	for c in cues:
		var cd: Dictionary = (c as Dictionary).duplicate()
		var nm := String(cd.get("name", ""))
		if not named.has(nm):
			for i in range(maxi(after, 0), acts.size()):
				var a: Dictionary = acts[i]
				if not claimed.has(i) and (a.get("layers", []) as Array).has(nm):
					cd["name"] = String(a["name"])
					cd["layer"] = nm
					claimed[i] = true
					after = i
					break
		out.append(cd)
	return out


## When each act runs, from the reading's placed schedule [param sched] (`[{a, t0, s}]`, [method
## ReadingFollower.place]), its walk [param parse] ([method CardReading.parse]) and when each spoken word
## was said ([param said0], [param said1] - [constant ReadingFollower.NO_TIME] where not yet; [param est],
## each word's estimated time from the top, gives the pace of what is not yet heard). [param now]: what
## has begun by then never moves.
##
## Nothing begins on a guess: an act cued at a word not yet heard waits for it, and so does every act
## that follows it in its beat. The words of a live reading arrive a sentence at a time, and a guess at
## the rest from the plan's estimate would put every act cued in the beat before the beat began. What is
## still guessed - where a beat ends, for quickening its acts and for one "under" - is guessed from the
## last word heard, at the pace the voice has kept ([method _guessed]). What the plan in force has begun
## is begun, whatever the words say after; an act placed only once its moment has passed begins now,
## never part way through; and acts keep their declared order even on different parts - a word cue is the
## earliest start, never permission to bypass an earlier act (opening a jar must finish before taking a
## pinch from it).
func schedule(sched: Array, parse: Dictionary, said0: PackedFloat32Array, said1: PackedFloat32Array,
		est: PackedFloat32Array, now: float) -> void:
	if game != null:
		game.schedule(sched)
	if acts.is_empty():
		return
	var c0 := Time.get_ticks_usec() if profiling else 0
	# What is playing is begun: the plan in force had it under way, and seen
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
	# Each beat's span: from its mark's move to the last word of the passage after it
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
		# It begins when its mark's move is done - the shuffle begun, the card laid, the spread settled - or,
		# before the mark is placed, never
		var e: Dictionary = placed.get(a, {})
		var b0 := INF
		if not e.is_empty():
			b0 = float(e["t0"]) + float(a["dur"]) * float(e["s"])
		var b1 := float(w1.call(si1 - 1)) if si1 > si0 else b0 + 2.0
		# ...and its last silence is its own ([CardReading], a quiet its words end on): the work goes on through it
		b1 += float(a.get("tail", 0.0))
		spans[beat] = Vector2(b0, maxf(b1, b0 + 1.0))
	# Each cue as the act it starts ([method resolve_cues]): an act's own name, or a painted layer's
	var cues := resolve_cues(parse.get("cues", []), acts)
	var cued := {}
	for c in cues:
		var cd: Dictionary = c
		# ...a cue in a silence is timed from the word the silence follows: the next word is not said until the silence is over, and
		# what was cued to begin in it would wait out the whole of it
		if cd.has("quiet"):
			var heard_to := int(cd["si"]) - 1
			if heard_to < 0:
				# ...and before any word at all, from when its beat begins
				cued[String(cd["name"])] = -INF
			else:
				var ended := said1[heard_to] if heard_to < said1.size() and said1[heard_to] != ReadingFollower.NO_TIME else INF
				cued[String(cd["name"])] = ended + float(cd["quiet"]) if ended != INF else INF
		else:
			cued[String(cd["name"])] = float(w0.call(int(cd["si"])))
	# ...and a cue at the word a silence comes before may begin as the silence does, the hand free by
	# then: a silence is written for the work to be watched, and a paint act's end is kept from the guess
	# made as it began, so the act cued after it would otherwise wait out the whole silence. Where the
	# guess held, the act before ends at that word and nothing moves.
	# (...and the word each act is cued at, for the act before it to be sized by while that word is still to come)
	var cue_si := {}
	var cue_into := {}     # ...a cue in a silence: how far into it, after the word the silence follows
	for c in cues:
		cue_si[String((c as Dictionary)["name"])] = int((c as Dictionary)["si"])
		if (c as Dictionary).has("quiet"):
			cue_into[String((c as Dictionary)["name"])] = float((c as Dictionary)["quiet"])
	var early := {}
	var before_quiet := {}
	for q in parse.get("quiets", []):
		before_quiet[int((q as Dictionary)["si"])] = true
	for c in cues:
		var cd: Dictionary = c
		var si := int(cd["si"])
		# (...a cue inside the silence too - one at its end, the next passage's first act, is one)
		if (cd.has("quiet") or before_quiet.has(si)) and si > 0 and si - 1 < said1.size() and said1[si - 1] != ReadingFollower.NO_TIME:
			early[String(cd["name"])] = said1[si - 1]
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
				var at := float(cued[nm])
				if early.has(nm):
					at = minf(at, maxf(float(early[nm]), t0))
				t0 = maxf(t0, maxf(at, span.x))
			var parts := _channels_of(a)
			# ...one hand paints one thing at a time: an act that paints waits for the last to be done with its tool, whichever it was (a
			# paint act is never hurried far, [constant TablePaint.LEAST])
			if _paints(a):
				parts = parts.duplicate()
				parts.append(PAINT_HAND)
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
			var t1 := t0 + maxf(float(a["length"]) * quick, float(a.get("_min_length", 0.0)))
			if bool(a["under"]):
				# the time the beat leaves it: up to the next act the reader cued, or the beat's end less what
				# the acts after it take
				var until := span.y
				var after := 0.0
				var shared := float(a.get("_natural", 0.0))    # what builds, and what builds after it before anything cued: each its share
				var fixed_all := float(a.get("_fixed", 0.0))
				for k in range(j + 1, mine.size()):
					var b: Dictionary = acts[mine[k]]
					if cued.has(String(b["name"])) and float(cued[String(b["name"])]) < INF:
						until = minf(until, float(cued[String(b["name"])]))
						break
					# ...or as far as its word is guessed to come, where it is not heard yet: an act cued at a later
					# word cannot begin before that word, so the acts after it take no share of this one's time -
					# shared with them, a painting act would be sized to a fraction of its passage and put down long
					# before the next word. The guess only ends this act; nothing is begun by it.
					if cue_si.has(String(b["name"])) and int(cue_si[String(b["name"])]) > 0:
						until = minf(until, float(guess.call(int(cue_si[String(b["name"])]) - 1)) + float(cue_into.get(String(b["name"]), 0.0)))
						break
					shared += float(b.get("_natural", 0.0))
					fixed_all += float(b.get("_fixed", 0.0))
					after += maxf(1.5, float(b.get("_min_length", 0.0))) if bool(b["under"]) else maxf(float(b["length"]) * quick, float(b.get("_min_length", 0.0)))
					# ...its rest too, where the one before laid down what it takes up
					for ch in _laid_by(mine[k - 1]):
						if _channels_of(b).has(ch):
							after += TableTune.value(tune, "laid_rest")
							break
				t1 = maxf(t0 + 1.0, until - after)
				if a.has("_natural") and shared > 0.0 and until < INF:
					t1 = t0 + (until - t0) * float(a["_natural"]) / shared
					# ...and the time to spare given to the work, never to its trips: what an act's trips and moves
					# take (`_fixed`, [method TablePaint.plan_of]) is never slowed, so a share of the spare by the
					# whole length would give an act of few strokes and many trips more than its strokes could be
					# slowed to fill. Each act's work slowed alike.
					var work_all := shared - fixed_all
					if work_all > 0.0 and until - t0 > shared:
						var own := float(a.get("_fixed", 0.0))
						t1 = t0 + own + (until - t0 - fixed_all) * (float(a["_natural"]) - own) / work_all
				t1 = maxf(t1, t0 + float(a.get("_min_length", 0.0)))
				if t1 == INF:
					t1 = t0 + Motions.UNDER_GUESS
			# ...and once begun, how long it runs: an act of fixed length, and an act that paints - a paint
			# act's every stroke is laid out over its whole length, so each sentence's new guess at the word
			# that ends it would move every stroke from its first, and the bake would go back to the act's
			# start every sentence while the show waited for it
			if _begun.has(nm) and (not bool(a["under"]) or _paints(a)):
				t1 = float((_begun[nm] as Array)[1])
			if t0 <= now:
				_begun[nm] = [t0, t1]
			out.append({"i": i, "t0": t0, "t1": t1})
			for ch in parts:
				busy[ch] = maxf(float(busy.get(ch, -INF)), t1)
			# ...and what it laid down rests before that hand takes it up again
			for ch in _laid_by(i):
				busy[ch] = maxf(float(busy.get(ch, -INF)), t1 + TableTune.value(tune, "laid_rest"))
			t = t1
	_last_now = now
	out.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return float(x["t0"]) < float(y["t0"]))
	var key := str(out.map(func(r: Dictionary) -> Vector3: return Vector3(float(r["i"]), float(r["t0"]), float(r["t1"]))))
	if key == _plan_key:
		return
	_plan_key = key
	runs = out
	_spent("plan: placing the acts", c0)
	if assembly != null:
		assembly.lay(runs, acts, now)
	_timelines()


## The one hand that paints, as the schedule keeps it busy ([method schedule]).
const PAINT_HAND := "hand:paint"


## Whether act [param a] paints ([TablePaint]).
static func _paints(a: Dictionary) -> bool:
	for t in a.get("tracks", []):
		if String((t as Dictionary).get("law", "")) == "paint":
			return true
	return false


## The channels act [param i] leaves laid down ([constant LAID_REST]): each whose last track in it is set
## `down`, or a path ending with what it moves at the table - its lowest point as built, and each path's
## way up or down since, followed through the acts in their order (a carry sent elsewhere leaves it
## unknown, and it is not counted). Found once for the acts.
func _laid_by(i: int) -> Array:
	if _laid_of.size() != acts.size():
		_laid_of = []
		var low := {}
		for a in acts:
			var last := {}        # channel -> [where in its act it ends, its last track]
			for t in (a as Dictionary)["tracks"]:
				var tr: Dictionary = t
				var ch := String(tr.get("_ch", ""))
				if not ch.ends_with(":pose"):
					continue
				var w := _window(tr)
				if not last.has(ch) or w.y >= float((last[ch] as Array)[0]):
					last[ch] = [w.y, tr]
				if not low.has(ch):
					low[ch] = _lowest_built(ch, tr)
				if String(tr["law"]) == "path" and not (tr["keys"] as Array).is_empty():
					low[ch] = float(low[ch]) + (((tr["keys"] as Array).back() as Dictionary).get("by", Vector3.ZERO) as Vector3).y * 0.01
				else:
					low[ch] = NAN
			var laid: Array = []
			for ch in last:
				var tr: Dictionary = (last[ch] as Array)[1]
				if bool(tr.get("down", false)) or (String(tr["law"]) == "path" and float(low[ch]) <= LAID_NEAR):
					laid.append(ch)
			_laid_of.append(laid)
	return _laid_of[i] if i < _laid_of.size() else []


## How high what track [param tr] moves stands at its lowest as built (meters, the table's top 0), or NAN for a set of copies.
func _lowest_built(ch: String, tr: Dictionary) -> float:
	var rest: Transform3D = _rest.get(ch, Transform3D.IDENTITY)
	if tr.has("_ti"):
		return (rest * ((things[int(tr["_ti"])] as Dictionary)["box"] as AABB)).position.y
	if tr.has("_gi") or not tr.has("_wi"):
		return NAN
	return (rest * (((works[int(tr["_wi"])] as Dictionary)["w"] as Dictionary).get("box", AABB()) as AABB)).position.y


## When a word not yet heard will end, guessed (a Callable of its spoken index, seconds): from the last
## word heard, as far on as the plan's estimate ([param est]) puts it, at the pace the voice has kept
## against that estimate over what it has said - INF where nothing gives a guess. Never when an act
## begins: only where a beat ends.
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
		# ...one hand on what is being built: its acts go one after another
		var chs: Array = ["assembly" if String(tr.get("law", "")) == "assemble" else String(tr.get("_ch", ""))]
		for ch in chs:
			if not String(ch).is_empty() and not out.has(ch):
				out.append(ch)
	return out


## A schedule of its own, for a picture of the work with no reading under it ([TablePreview]): every act
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
	var rests := {}           # channel -> when what lies there may be taken up again ([constant LAID_REST])
	for beat in order:
		for i in acts.size():
			var a: Dictionary = acts[i]
			if String(a["beat"]) != String(beat):
				continue
			var len := float(a["_natural"]) if a.has("_natural") else (Motions.UNDER_GUESS if bool(a["under"]) else float(a["length"]))
			for ch in _channels_of(a):
				t = maxf(t, float(rests.get(ch, -INF)))
			out.append({"i": i, "t0": t, "t1": t + len})
			times[String(a["name"])] = [t, t + len]
			t += len
			for ch in _laid_by(i):
				rests[ch] = t + TableTune.value(tune, "laid_rest")
	# ...the same rehearsal as stands, nothing made again: each act a call checks would rebuild every channel's timeline
	var key := "rehearsed %f" % from
	if key == _plan_key and out == runs:
		return times
	runs = out
	_plan_key = key
	if assembly != null:
		assembly.lay(runs, acts, -INF)
	_timelines()
	return times


## The rehearsal every picture of the work is taken on ([method check], [TablePreview]): from [constant REHEARSAL].
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


## Each channel's timeline, from [member runs]: every act's tracks, each with where its channel was as it
## began (`from`) and where it left it (`end`) - the end of one the start of the next. A track holds its
## channel over its own stretch of its act (`s0`..`s1`: its `between`, or a path's first and last keys), so
## an act can carry a thing over, tip it, and carry it back, one track after another on the same part.
func _timelines() -> void:
	_chan = {}
	_quiet_spans = {}
	_full = true
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
				var it := {"ch": String(tr["_ch"]), "track": tr, "t0": t0, "t1": t1, "i": int(r["i"]), "act": String(a["name"]), "order": order,
					"s0": t0 + w.x * (t1 - t0), "s1": t0 + w.y * (t1 - t0)}
				items.append(it)
			order += 1
	items.sort_custom(func(x: Dictionary, y: Dictionary) -> bool:
		return float(x["s0"]) < float(y["s0"]) or (float(x["s0"]) == float(y["s0"]) and (float(x["t0"]) < float(y["t0"]) or (float(x["t0"]) == float(y["t0"]) and int(x["order"]) < int(y["order"])))))
	# What posing found, kept from the plan before ([member _found_before]): a live reading makes a plan a
	# sentence, and each would work out again where every carry so far comes to rest and how it is set
	# down - its room, how far it settles, a pour's plan - on the app's thread. What ends before the first
	# moment this plan is not the last one ([method _same_until]) is posed as it was, and keeps it.
	var same_until := _same_until(_runs_before, runs)
	var c := Time.get_ticks_usec() if profiling else 0
	# Twice: an end can lie where another thing has been moved to by then (a pestle ground round a mortar
	# carried to the middle), and the first pass has not yet laid that thing's later moves down
	for pass_i in 2:
		var now := {}
		var until := {}           # channel -> when what last held it lets it go
		for it in items:
			var e: Dictionary = it
			var ch := String(e["ch"])
			for key in FOUND:
				e.erase(key)
			# ...and, ended before it, where it began and ended: posed as it was, nothing of it is worked out again
			if float(e["s1"]) < same_until:
				var was: Variant = _found_before.get(_found_key(e))
				if was != null and float((was as Array)[0]) == float(e["t0"]) and float((was as Array)[1]) == float(e["t1"]):
					e.merge((was as Array)[2] as Dictionary, true)
					e["from"] = (was as Array)[3]
					e["end"] = (was as Array)[4]
					until[ch] = maxf(float(until.get(ch, -INF)), float(e["s1"]))
					now[ch] = e["end"]
					if pass_i == 0:
						_add(ch, e)
					continue
			e["from"] = now.get(ch, _run_value(ch, float(e["s0"])))
			# A loose part begins where its thing has carried it since it was let go in it (or since it was built in it) -
			# one of a set of copies keeps its own place in the set's frame
			if pass_i == 1 and ch.begins_with("w") and ch.ends_with(":pose") and not _group_of.has(int(ch.substr(1, ch.find(":") - 1))) \
					and float(until.get(ch, -INF)) < float(e["s0"]) - CHAIN_GAP:
				e["from"] = _work_world(int(ch.substr(1, ch.find(":") - 1)), float(e["s0"]) - 1e-4)
			until[ch] = maxf(float(until.get(ch, -INF)), float(e["s1"]))
			e["end"] = _eval(e, float(e["s1"]) - float(e["t0"]), float(e["s1"]))
			now[ch] = e["end"]
			if pass_i == 0:
				_add(ch, e)
	c = _spent("plan: each move's ends", c)
	_chains()
	_found_before = {}
	for it in items:
		var found := {}
		for key in FOUND:
			if (it as Dictionary).has(key):
				found[key] = (it as Dictionary)[key]
		_found_before[_found_key(it)] = [float((it as Dictionary)["t0"]), float((it as Dictionary)["t1"]), found,
			(it as Dictionary)["from"], (it as Dictionary)["end"]]
	_runs_before = runs
	# ...a carry's way over what is in it found again on its run's slopes ([method _clearance])
	for ch in _chan:
		for e in _chan[ch]:
			(e as Dictionary).erase("_clear")
			(e as Dictionary).erase("_clear_path")
	c = _spent("plan: chains", c)
	# When each element is laid, from where its act now runs ([TablePaint])
	if paint != null:
		var painting: Array = []
		for ch in _chan:
			for e in _chan[ch]:
				if String(((e as Dictionary)["track"] as Dictionary)["law"]) == "paint":
					painting.append(e)
		paint.spans(painting)
	plan_cues()
	c = _spent("plan: cues", c)
	if physics != null:
		physics.replan()
	_spent("plan: handed to the bake", c)


## The first moment (show seconds) at which plan [param now] is not plan [param was]: the soonest start of a run either has that
## the other has not at the same times - everything before it is posed alike in both. -INF with nothing to go by.
static func _same_until(was: Array, now: Array) -> float:
	if was.is_empty():
		return -INF
	var before := {}
	for r in was:
		before[int((r as Dictionary)["i"])] = [float((r as Dictionary)["t0"]), float((r as Dictionary)["t1"])]
	var out := INF
	var seen := {}
	for r in now:
		var i := int((r as Dictionary)["i"])
		var t0 := float((r as Dictionary)["t0"])
		var t1 := float((r as Dictionary)["t1"])
		seen[i] = true
		var b: Variant = before.get(i)
		if b == null:
			out = minf(out, t0)
		elif float((b as Array)[0]) != t0 or float((b as Array)[1]) != t1:
			out = minf(out, minf(t0, float((b as Array)[0])))
	for i in before:
		if not seen.has(i):
			out = minf(out, float((before[i] as Array)[0]))
	return out


## An entry's name among the plans: its channel, its act and which of the act's tracks it is.
static func _found_key(e: Dictionary) -> String:
	return "%s|%s|%d" % [e["ch"], e["act"], int(e["order"])]


## One move through its places: a run of carries and paths on one thing or part, each begun as the last
## ended (a vial carried "the low way" past three things, a waypoint a carry), goes on through every place
## it passes and stops only where it holds or turns back, and at the run's ends - each a cubic through
## them all ([method Motions.slopes]), the slope at each of its places kept on its entry as `_m` (meters a
## second). A run of one carry keeps its own ease.
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


## A channel's value at show time [param t].
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
		# A part that runs goes on running from where an act let it go: a clock set by hand keeps time after
		if last["end"] is float and _runs_of.has(ch):
			return float(last["end"]) + float(_run_value(ch, t)) - float(_run_value(ch, float(last["s1"])))
		# A hand holding a thing up is never still ([method _held_up])
		if last["end"] is Transform3D:
			var up := _held_up(ch, last, next, t)
			if up > 0.0:
				var dr: Array = Hands.drift(t, int((last["track"] as Dictionary).get("_hand", 0)), up * Hands.HOLD_SWAY)
				var end: Transform3D = last["end"]
				return Transform3D((dr[1] as Basis) * end.basis, end.origin + (dr[0] as Vector3))
		return last["end"]
	return _eval(last, t - float(last["t0"]), t)


## Held up between its moves: how much of a hand's unsteadiness ([method Hands.drift]) a thing or part has
## at [param t], the move [param e] on channel [param ch] having left it where it touches nothing - a
## pestle lifted out of its mortar and held aside, a vial held over a pot - coming on as the move ends
## and dying away before [param next] begins, so a move still begins where it was sent. None for what
## was set `down` or rests on or against anything, or what the physics holds (a loose thing let go
## falls), and none in the twin the physics bakes by (it touches nothing, so nothing it meets would
## tell). The bake holds a rigid part so too, swaying alike ([method TablePhysics._held_aloft]).
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


## Whether channel [param ch]'s thing or part, posed [param x] at show time [param T], touches nothing:
## no point of its own surface within [constant TOUCHING] of the table's top or of any solid but its own,
## where each is then. Its surface, never its box: a round lid set on its crock has its box's corners out
## in the air past the rim.
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
	for sd in _solids_ref:
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
	for sd in _solids_ref:
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
		if String(tr["law"]) == "cloud":
			return _painter().cloud_at(tr["_with"], e["from"], tau, d, _water_ml(tr))
		return Motions.tint(tr, e["from"], tau, d, T) if String(tr["law"]) == "to" else e["from"]
	return Motions.scalar(tr, float(e["from"]), tau, d, T)


## A pose at [param tau] of [param d] seconds into its act: where the part or the thing is, in the table's
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
			# ...back where it was built, as it was built, unless turned: a stopper laid on its side goes back in upright
			var r_to := Basis.from_euler((tr["turn"] as Vector3) * (PI / 180.0)) if tr.has("turn") else (r_from if tr.has("to") else Basis.IDENTITY)
			if not tr.has("to"):
				r_to = _home_of(tr, float(e["t0"]) + w.y * d).basis.orthonormalized() * r_to
			# ...where there is room for it ([method _room]), as it will stand there - set down on what is under it first
			var pc := Time.get_ticks_usec() if profiling else 0
			if not e.has("_room"):
				var end0 := _rebuilt(r_to.orthonormalized(), to, q0, x0)
				if tr.get("down", false):
					end0.origin.y += _settle(tr, end0, float(e["t0"]) + w.y * d)
				e["_room"] = _room(tr, end0, float(e["t0"]) + w.y * d)
				_spent("carry: room and set-down", pc)
			to += e["_room"]
			# on through where the carry before it left it and where the one after takes it up ([method _chains])
			var m: PackedVector3Array = e.get("_m", PackedVector3Array())
			var h := (w.y - w.x) * d
			var ma := m[0] * h if m.size() == 2 else Vector3.ZERO
			var mb := m[1] * h if m.size() == 2 else Vector3.ZERO
			# As a hand carries it ([Hands]): minimum jerk, bowed a little to one side, lifted early and lowered late,
			# leaning with the hand's pull, and never quite still while it is off the table
			var seed := int(tr.get("_hand", 0))
			var lift := float(tr["lift"]) * 0.01
			# ...and over what stands in its way, however low its lift was written ([method _clearance]) - looked for only once it is
			# on its way: at either end it is where it is set ([method Hands.carried] - no lift, no bow, no lean, no drift), and every
			# plan made works out where each carry ends, on the app's thread, a sentence at a time
			var going := lin > 0.0 and lin < 1.0
			if going and not e.has("_clear"):
				pc = Time.get_ticks_usec() if profiling else 0
				e["_clear"] = _clearance(tr, p_from, to, ma, mb, r_from, r_to, q0, x0, seed, float(e["t0"]) + (w.x + w.y) * 0.5 * d)
				_spent("carry: way over", pc)
			lift = maxf(lift, float(e.get("_clear", 0.0)))
			# ...up clear of what stands close round it before it goes, and down among what stands close where it goes last ([method
			# _rise_among], [method Hands.carried])
			if going and not e.has("_rise"):
				pc = Time.get_ticks_usec() if profiling else 0
				e["_rise"] = Vector2(_rise_among(tr, from, float(e["t0"]) + w.x * d),
					_rise_among(tr, _rebuilt(r_to.orthonormalized(), to, q0, x0), float(e["t0"]) + w.y * d))
				_spent("carry: rise among", pc)
			var rise: Vector2 = e.get("_rise", Vector2.ZERO)
			lift = maxf(lift, maxf(rise.x, rise.y) + CLEAR_GAP)
			var p := Hands.carried(p_from, to, ma, mb, lift, lin, seed, rise)
			var r := Basis(Quaternion(r_from).slerp(Quaternion(r_to.orthonormalized()), s))
			r = Hands.lean(func(x: float) -> Vector3: return Hands.carried(p_from, to, ma, mb, lift, x, seed, rise), lin, h) * r
			var dr: Array = Hands.drift(T, seed, Hands.held(lin))
			out = _rebuilt((dr[1] as Basis) * r, p + (dr[0] as Vector3), q0, x0)
			# Set down on what is under it: how far is found once, where it ends, and taken over the way there
			if tr.get("down", false):
				if not e.has("_down"):
					pc = Time.get_ticks_usec() if profiling else 0
					e["_down"] = _settle(tr, _rebuilt(r_to.orthonormalized(), to, q0, x0), float(e["t0"]) + w.y * d)
					_spent("carry: room and set-down", pc)
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
			# Its place goes on through its keys ([method _chains]: their slopes, a second's, to the act's whole), or eases
			# from each to the next - bowed between them as a hand goes ([method _path_at])
			var where := func(x: float) -> Vector3: return _path_at(keys, mk, p_from, d, x, seed)
			var p: Vector3 = where.call(u)
			# ...ending where there is room for it ([method _room]), the whole of its way bent there
			var win_p := _window(tr)
			if not e.has("_room"):
				var kl: Dictionary = keys[keys.size() - 1]
				var rl := Basis.from_euler((kl.get("turn", Vector3.ZERO) as Vector3) * (PI / 180.0)) * r_from
				e["_room"] = _room(tr, _rebuilt(rl, _path_at(keys, mk, p_from, d, win_p.y, seed), q0, x0), float(e["t0"]) + win_p.y * d)
			p += (e["_room"] as Vector3) * Hands.timing(clampf((u - win_p.x) / maxf(win_p.y - win_p.x, 1e-6), 0.0, 1.0))
			# ...and over what stands in its way between its keys ([method _path_clearance])
			# ...looked for only between its first key and its last, where it lifts ([method Hands.lift_at] is none at a key)
			if u > float((keys[0] as Dictionary)["at"]) and u < float((keys[keys.size() - 1] as Dictionary)["at"]) and not e.has("_clear_path"):
				var pc := Time.get_ticks_usec() if profiling else 0
				e["_clear_path"] = _path_clearance(e, tr, keys, mk, p_from, r_from, d, q0, x0, seed)
				_spent("path: way over", pc)
			var cl: PackedFloat32Array = e.get("_clear_path", PackedFloat32Array())
			for i in range(mini(keys.size() - 1, cl.size())):
				var u0 := float((keys[i] as Dictionary)["at"])
				var u1 := float((keys[i + 1] as Dictionary)["at"])
				if cl[i] > 0.0 and u > u0 and u < u1:
					p.y += cl[i] * Hands.lift_at((u - u0) / maxf(u1 - u0, 1e-6))
			# ...leaning with the hand's pull, never quite still while it is held off the table
			r = Hands.lean(where, u, d) * r
			var win := _window(tr)
			var dr: Array = Hands.drift(T, seed, Hands.held((u - win.x) / maxf(win.y - win.x, 1e-6)))
			out = _rebuilt((dr[1] as Basis) * r, p + (dr[0] as Vector3), q0, x0)
		"drink":
			out = _drink_at(e, tr, u, d, T, from, x0, q0)
		"paint":
			out = _painter().pose(e, tr, tau, d, T, from, x0)
		"pour":
			out = _pour_at(e, tr, u, d, T, from, x0, q0)
		"dip":
			out = _dip_at(e, tr, u, d, T, from, x0, q0)
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
		# A pen seen: its nib on the ink as it goes down, or by what it points at, leaning as a hand holds it
		"pen", "point":
			var writes := String(tr["law"]) == "pen"
			var nib := _pen_nib(tr, T) if writes else _point_nib(tr, tau, d)
			if not nib.is_empty() and _writing.has(int(nib["sheet"])):
				var before := _pen_nib(tr, T - Pen.MOTION_DT) if writes else _point_nib(tr, tau - Pen.MOTION_DT, d)
				out = _held_by_tip(tr, nib, before, T, x0)
	if String(tr["law"]) in ["aim", "circle", "pen", "point"] and tau < BLEND_IN:
		# A hand brings it there first: from where it was to where the law has it, over the first moment - lifted
		# in an arc, so it goes over a rim rather than through it, early, as a hand lifts a tool before it reaches
		var lin := tau / BLEND_IN
		var s := Hands.timing(lin)
		# ...lifted as far as what is under its way asks, as a carry is ([method _clearance], [method _entry_lift]) - never a set
		# height: from over its mortar, a pestle goes straight down into it; from beside it, it goes over the rim
		var lift := _entry_lift(e, tr, from, d, x0, q0) * Hands.lift_at(lin) * smoothstep(BLEND_NEAR.x, BLEND_NEAR.y, from.origin.distance_to(out.origin))
		# Resuming work inside one vessel needs no trip over its rim: a ladle left leaning in a pot and taken up to stir
		# is not raised out of it by this generic entry arc.
		var contact := _point_local(wi, String((tr["tip"] as Dictionary)["point"])) if String(tr["law"]) == "aim" and wi >= 0 else x0.affine_inverse() * q0
		if _same_inside(from * contact, out * contact, T, wi):
			lift = 0.0
		# ...as a carry goes: about the part's own middle, never its node's origin, and lifted before it turns ([method _turn_share])
		# - a big turn with a hand's whole lift. A tool turned about an origin far from its middle and lifted only as the way
		# asked would sweep through the table.
		var rel_from := from * x0.affine_inverse()
		var rel_to := out * x0.affine_inverse()
		var q_from := Quaternion(rel_from.basis.orthonormalized())
		var q_to := Quaternion(rel_to.basis.orthonormalized())
		if lift > 0.0 or not _same_inside(from * contact, out * contact, T, wi):
			lift = maxf(lift, BLEND_LIFT * Hands.lift_at(lin) * smoothstep(BLEND_TURN.x, BLEND_TURN.y, q_from.angle_to(q_to)))
		var r := Basis(q_from.slerp(q_to, Hands.timing(_turn_share(lin))))
		out = _rebuilt(r, (rel_from * q0).lerp(rel_to * q0, s) + Vector3.UP * lift, q0, x0)
	var j := Motions.jitter_of(tr, tau)
	if j != Vector3.ZERO:
		out.origin += j
	return out


## How high a hand lifts a tool it brings to its work (meters, the lift at the middle of the way): entry
## [param e]'s law where it has the tool once it is there ([constant BLEND_IN] in), from [param from] -
## what clearing the way there asks ([method _clearance]), found once an entry. ([param tr]: its track,
## [param d] its act's length, [param x0] and [param q0] the part as built.)
func _entry_lift(e: Dictionary, tr: Dictionary, from: Transform3D, d: float, x0: Transform3D, q0: Vector3) -> float:
	if e.has("_entry"):
		return float(e["_entry"])
	e["_entry"] = BLEND_LIFT
	var T := float(e["t0"]) + BLEND_IN
	var there := _pose(e, BLEND_IN, d, T)
	var rel_from := from * x0.affine_inverse()
	var rel_to := there * x0.affine_inverse()
	var pc := Time.get_ticks_usec() if profiling else 0
	var need := _clearance(tr, rel_from * q0, rel_to * q0, Vector3.ZERO, Vector3.ZERO, rel_from.basis.orthonormalized(),
		rel_to.basis.orthonormalized(), q0, x0, int(tr.get("_hand", 0)), float(e["t0"]))
	_spent("entry: way over", pc)
	e["_entry"] = need
	return need


## Whether two contact points are inside the same vessel, in the table's space. Used only for a tool's entry transition;
## a tool coming from outside still lifts over the rim, and collisions still constrain its whole surface.
func _same_inside(a: Vector3, b: Vector3, t: float, own: int) -> bool:
	for L in _liquids_ref:
		var sd: Dictionary = _solids_ref[int((L as Dictionary)["solid"])]
		if own >= 0 and _within(int(sd["wi"]), own) == 1:
			continue
		# Read this work's poses, never the mutable solids' xf: live and bake run on different threads.
		var pose := (_thing_world(int(sd["oi"]), t) if String(sd["owner"]) == "t" else _work_world(int(sd["oi"]), t)) * (sd["local"] as Transform3D)
		var inv := pose.affine_inverse()
		var vessel: Vessel = (L as Dictionary)["vessel"]
		if _against_inside(vessel, inv * a) and _against_inside(vessel, inv * b):
			return true
	return false


## Whether point [param p] (a vessel's own space) is in [param vessel]'s inside - or against its wall, a few millimeters short of it
## ([constant INSIDE_NEAR]): a pestle leaning in its mortar has its tip against the wall, where the inside, inset from it, is not.
static func _against_inside(vessel: Vessel, p: Vector3) -> bool:
	if vessel.contains(p):
		return true
	var xz := Vector2(p.x, p.z)
	if xz.length() < 1e-5:
		return false
	var q := xz - xz.normalized() * minf(INSIDE_NEAR, xz.length())
	return vessel.contains(Vector3(q.x, p.y, q.y))


## How high a hand lifts a tool it brings to where a law has it, [param s] of the way there from [param
## far] meters off: as far as it has to go - never a step from no lift at all to the whole of one, which a
## law's place moving 2 cm would throw a tool up in a frame.
static func blend_lift(s: float, far: float) -> float:
	return BLEND_LIFT * Hands.lift_at(s) * smoothstep(BLEND_NEAR.x, BLEND_NEAR.y, far)


## A path's place at [param u] through its act ([param d] seconds): through its [param keys] from [param
## p_from] - on through them with slopes [param mk] (meters a second, [method _chains]) or eased from each
## to the next - and bowed between each two a little to one side, as a hand goes ([method Hands.bow],
## [param seed]).
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


## A drink at [param u] of its act, [param d] seconds long: up off the table and toward the lens until all of it has left the frame, held there while what is drunk goes, and back exactly where it stood, turned as it
## was. It is the hand that knows where the mouth is ([method _to_the_mouth]): nothing written says, so a drink is the same one word on any table under any lens.
func _drink_at(e: Dictionary, tr: Dictionary, u: float, d: float, T: float, from: Transform3D, x0: Transform3D, q0: Vector3) -> Transform3D:
	var w: Vector2 = tr["between"]
	var lin := clampf((u - w.x) / maxf(w.y - w.x, 1e-6), 0.0, 1.0)
	var rel := from * x0.affine_inverse()
	var p_from := rel * q0
	var r_from := rel.basis.orthonormalized()
	var seed := int(tr.get("_hand", 0))
	var mouth := _to_the_mouth(tr, x0, q0)
	var r_at := Basis(medium._plan.cam_base.basis.x.normalized(), deg_to_rad(DRINK_TIP)) * r_from
	# ...over what stands in its way ([method _clearance]), as a carry goes
	if lin > 0.0 and lin < 1.0 and not e.has("_clear"):
		e["_clear"] = _clearance(tr, p_from, mouth, Vector3.ZERO, Vector3.ZERO, r_from, r_at, q0, x0, seed, float(e["t0"]) + (w.x + w.y) * 0.5 * d)
		# ...and over what has been built: the bricks are in another world from what an act moves, and a cup taken up late in the show would go through the model
		if assembly != null and assembly.log != null:
			e["_clear"] = maxf(float(e["_clear"]), lift_over(p_from, mouth, seed, assembly.built_reach(), q0.y - _lowest_under(tr, x0)))
	var lift := maxf(DRINK_LIFT, float(e.get("_clear", 0.0)))
	var p := mouth
	var s := 1.0
	if lin < DRINK_UP:
		var x := lin / DRINK_UP
		p = Hands.carried(p_from, mouth, Vector3.ZERO, Vector3.ZERO, lift, x, seed)
		s = Hands.timing(x)
	elif lin > 1.0 - DRINK_UP:
		var x := (lin - (1.0 - DRINK_UP)) / DRINK_UP
		p = Hands.carried(mouth, p_from, Vector3.ZERO, Vector3.ZERO, lift, x, seed + 1)
		s = 1.0 - Hands.timing(x)
	var r := Basis(Quaternion(r_from).slerp(Quaternion(r_at.orthonormalized()), s))
	var dr: Array = Hands.drift(T, seed, Hands.held(lin))
	return _rebuilt((dr[1] as Basis) * r, p + (dr[0] as Vector3), q0, x0)


## How high the foot of what track [param tr] moves stands, where [param x0] builds it (meters).
func _lowest_under(tr: Dictionary, x0: Transform3D) -> float:
	var box: AABB
	if tr.has("_ti"):
		box = _world_rest_thing(int(tr["_ti"])) * ((things[int(tr["_ti"])] as Dictionary)["box"] as AABB)
	else:
		box = x0 * (((works[int(tr["_wi"])] as Dictionary)["w"] as Dictionary)["box"] as AABB)
	return box.position.y


## The least lift that takes a move from [param a] to [param b] over what [param built] says stands there ([method TableAssembly.built_reach]), the thing's foot [param foot] under the point moved. Looked at along the way,
## with a little more each time until it clears: none, for a way that never comes over it.
static func lift_over(a: Vector3, b: Vector3, seed: int, built: Dictionary, foot: float) -> float:
	var at: Vector2 = built["at"]
	var reach := float(built["reach"]) + DRINK_OVER
	var need := float(built["top"]) + DRINK_OVER
	var lift := 0.0
	for _try in 24:
		var clear := true
		for k in range(1, 40):
			var p := Hands.carried(a, b, Vector3.ZERO, Vector3.ZERO, lift, float(k) / 40.0, seed)
			if Vector2(p.x, p.z).distance_to(at) < reach and p.y - foot < need:
				clear = false
				break
		if clear:
			return lift
		lift += 0.02
	return lift


## Where what is drunk from is held, its pivot [param q0] being where [param x0] builds it: close under the lens, all of it past the frame's foot however big it is. The lens sees as far down as its field does, so
## at [constant DRINK_FAR] along its axis the thing's middle goes as far below that as it reaches, measured square to the frame's edge.
func _to_the_mouth(tr: Dictionary, x0: Transform3D, q0: Vector3) -> Vector3:
	var box: AABB
	if tr.has("_ti"):
		box = _world_rest_thing(int(tr["_ti"])) * ((things[int(tr["_ti"])] as Dictionary)["box"] as AABB)
	else:
		box = x0 * (((works[int(tr["_wi"])] as Dictionary)["w"] as Dictionary)["box"] as AABB)
	var cam: Transform3D = medium._plan.cam_base
	var k := tan(deg_to_rad(medium._plan.fov * 0.5))
	var reach := box.size.length() * 0.5 + DRINK_CLEAR
	var at := cam.origin + cam.basis * Vector3(0.0, -(DRINK_FAR * k + reach * sqrt(1.0 + k * k)), -DRINK_FAR)
	return at - (box.get_center() - q0)


## Where carry [param tr] takes its pivot [param q0] (show time [param T]): its `to`, `by` past it - or by that much
## from where it was built.
func _carried_to(tr: Dictionary, q0: Vector3, T: float) -> Vector3:
	# ...one of a thing's parts carried in turn ([method _trips]) goes to its own place in the arrangement, as it stood in its
	# thing, turned as the thing is turned
	var off := Vector3.ZERO
	if tr.has("_trip") and tr.has("to"):
		var r := Basis.from_euler((tr["turn"] as Vector3) * (PI / 180.0)) if tr.has("turn") else Basis.IDENTITY
		off = r * (q0 - _world_rest_thing(int(tr["_trip"])).origin)
	return place_of(tr.get("to"), q0, T) + (tr["by"] as Vector3) * 0.01 + off if tr.has("to") else _home_of(tr, T) * q0 + (tr["by"] as Vector3) * 0.01


## Home, for carry [param tr] with no `to` (show time [param T]): for a thing, where it was built; for a
## part, where it was built in its thing, the thing as it stands now - a pestle put back goes into its
## mortar where the mortar is, never into the air or the wall where the mortar had stood. As a move from
## where it was built.
func _home_of(tr: Dictionary, T: float) -> Transform3D:
	if tr.has("_ti"):
		return Transform3D.IDENTITY
	var wi := int(tr.get("_wi", -1))
	if tr.has("_gi"):
		wi = int(((groups[int(tr["_gi"])] as Dictionary)["members"] as Array)[0])
	if wi < 0:
		return Transform3D.IDENTITY
	var ti := int((works[wi] as Dictionary)["thing"])
	var home := _thing_world(ti, T) * _world_rest_thing(ti).affine_inverse()
	# ...on the bake's twin, into the part it is a part of where that part really is: a rigid body the physics set down a
	# centimeter from where the acts put it ([member posed]) takes its stopper back where it is
	var pw := int(_parent_work.get(wi, -1))
	if pw >= 0 and posed.has(pw):
		var real: Transform3D = posed[pw]
		posed.erase(pw)
		var planned := _work_world(pw, T)
		posed[pw] = real
		home = real * planned.affine_inverse() * home
	return home


## How high a carry must lift to clear what stands under its way (meters, the lift at its highest):
## carry [param tr]'s thing or part, from pivot [param p_from] to [param to] turned from [param r_from] to
## [param r_to] ([param ma], [param mb], [param seed]: its way as [method Hands.carried] has it), looked
## at through the middle of its move where the hand has lifted it - its lowest point kept [constant
## CLEAR_GAP] over the highest thing under it there, at show time [param T]. A hand lifts a thing over
## what is in its way: the written lift is the least it rises, never what it must.
func _clearance(tr: Dictionary, p_from: Vector3, to: Vector3, ma: Vector3, mb: Vector3, r_from: Basis, r_to: Basis, q0: Vector3,
		x0: Transform3D, seed: int, T: float) -> float:
	var skip := int(tr.get("_ti", -1))
	var box: AABB = (things[skip] as Dictionary)["box"] if skip >= 0 else (((works[int(tr["_wi"])] as Dictionary)["w"] as Dictionary).get("box", AABB()) as AABB)
	if box.size == Vector3.ZERO or p_from.distance_to(to) < CLEAR_FROM:
		return 0.0
	var need := 0.0
	var meshes := _meshes_at(skip, T, int(tr.get("_wi", -1)))
	for k in CLEAR_SAMPLES:
		var u := lerpf(CLEAR_SPAN.x, CLEAR_SPAN.y, float(k) / float(CLEAR_SAMPLES - 1))
		var shape := Hands.lift_at(u)
		if shape < CLEAR_SHAPE:
			continue
		var r := Basis(Quaternion(r_from.orthonormalized()).slerp(Quaternion(r_to.orthonormalized()), Hands.timing(u)))
		var x := _rebuilt(r, Hands.carried(p_from, to, ma, mb, 0.0, u, seed), q0, x0)
		var pl := _probes_of(x, box)
		var probes: Array = pl[0]
		var low := float(pl[1])
		var top := _top_under(probes, skip, T, int(tr.get("_wi", -1)), meshes)
		if top > -INF:
			need = maxf(need, (top + CLEAR_GAP - low) / shape)
	return minf(need, CLEAR_MOST)


## How high track [param tr]'s thing or part, posed [param x] at show time [param T], must rise straight before it goes across - or
## come down straight after - to clear what stands close round it (meters, its lowest point over the highest thing within
## [constant AMONG] of what it covers, and [constant CLEAR_GAP] more): a jar in a row, a vial in its rack. Nothing close, none.
func _rise_among(tr: Dictionary, x: Transform3D, T: float) -> float:
	var skip := int(tr.get("_ti", -1))
	var box: AABB = (things[skip] as Dictionary)["box"] if skip >= 0 else (((works[int(tr["_wi"])] as Dictionary)["w"] as Dictionary).get("box", AABB()) as AABB)
	if box.size == Vector3.ZERO:
		return 0.0
	var pl := _probes_of(x, box.grow(AMONG))
	var top := _top_under(pl[0], skip, T, int(tr.get("_wi", -1)))
	var low := float(_probes_of(x, box)[1])
	return maxf(top + CLEAR_GAP - low, 0.0) if top > -INF and top > low + 0.002 else 0.0


## Where to look under box [param box] posed [param x]: `[points across the whole of what it covers,
## its lowest point's height]` - a grid [constant CLEAR_GRID] by CLEAR_GRID over it, never its corners
## alone: an open jar's rim is a ring four millimeters wide, and a box's corners and middle could look
## down into another jar's hollow at its floor.
static func _probes_of(x: Transform3D, box: AABB) -> Array:
	var lo := Vector3(INF, INF, INF)
	var hi := Vector3(-INF, -INF, -INF)
	for i in 8:
		var c := x * box.get_endpoint(i)
		lo = lo.min(c)
		hi = hi.max(c)
	var probes: Array = []
	for i in CLEAR_GRID:
		for k in CLEAR_GRID:
			probes.append(Vector3(lerpf(lo.x, hi.x, float(i) / float(CLEAR_GRID - 1)), lo.y, lerpf(lo.z, hi.z, float(k) / float(CLEAR_GRID - 1))))
	return [probes, lo.y]


## How high each stretch of a path must rise over what stands under its way (meters, at its middle): path
## entry [param e] of track [param tr], its [param keys] from pivot [param p_from] turned [param r_from],
## its slopes [param mk] ([method _chains]), [param d] seconds. A path's keys are where the puppeteer
## sends it, and a hand going from one to the next goes over what is in between, as a carry's does
## ([method _clearance]) - a stretch shorter across than [constant CLEAR_FROM] (a lift, a lowering) is
## its own.
func _path_clearance(e: Dictionary, tr: Dictionary, keys: Array, mk: PackedVector3Array, p_from: Vector3, r_from: Basis, d: float,
		q0: Vector3, x0: Transform3D, seed: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(maxi(keys.size() - 1, 0))
	var skip := int(tr.get("_ti", -1))
	var box: AABB = (things[skip] as Dictionary)["box"] if skip >= 0 else (((works[int(tr["_wi"])] as Dictionary)["w"] as Dictionary).get("box", AABB()) as AABB)
	if box.size == Vector3.ZERO:
		return out
	for i in range(keys.size() - 1):
		var k0: Dictionary = keys[i]
		var k1: Dictionary = keys[i + 1]
		var a := (k0.get("by", Vector3.ZERO) as Vector3) * 0.01
		var b := (k1.get("by", Vector3.ZERO) as Vector3) * 0.01
		if Vector2(b.x - a.x, b.z - a.z).length() < CLEAR_FROM:
			continue
		var need := 0.0
		for k in CLEAR_SAMPLES:
			var s := lerpf(CLEAR_SPAN.x, CLEAR_SPAN.y, float(k) / float(CLEAR_SAMPLES - 1))
			var shape := Hands.lift_at(s)
			if shape < CLEAR_SHAPE:
				continue
			var u := lerpf(float(k0["at"]), float(k1["at"]), s)
			var ra := Basis.from_euler((k0.get("turn", Vector3.ZERO) as Vector3) * (PI / 180.0)) * r_from
			var rb := Basis.from_euler((k1.get("turn", Vector3.ZERO) as Vector3) * (PI / 180.0)) * r_from
			var r := Basis(Quaternion(ra.orthonormalized()).slerp(Quaternion(rb.orthonormalized()), Hands.timing(s)))
			var x := _rebuilt(r, _path_at(keys, mk, p_from, d, u, seed), q0, x0)
			var pl := _probes_of(x, box)
			var probes: Array = pl[0]
			var low := float(pl[1])
			var top := _top_under(probes, skip, float(e["t0"]) + u * d, int(tr.get("_wi", -1)))
			if top > -INF:
				need = maxf(need, (top + CLEAR_GAP - low) / shape)
		out[i] = minf(need, CLEAR_MOST)
	return out


## A pour ([constant Motions.LAWS] `pour`) at [param u] through its act ([param d] seconds; show time
## [param T]): the vessel its track [param tr] moves, from [param from], brought over the mouth of what it
## pours into, its lip [param tr]'s `over` above it, its handle turned away and tipped toward it as far as
## its body needs, at most [constant POUR_PRE] of the way (the first [constant POUR_BRING] of its
## stretch, over what stands between), then turned about that lip across the view along its brink - share
## by share of its inside as the stretch goes, so what flows flows steadily - and back level, its lip
## rising as it comes back (the last [constant POUR_BACK]). Turned about its lip, the lip stays where it
## was put, and what flows leaves there, over the mouth: a hand pours so. The physics says what flows,
## and how much.
func _pour_at(e: Dictionary, tr: Dictionary, u: float, d: float, T: float, from: Transform3D, x0: Transform3D, q0: Vector3) -> Transform3D:
	var w: Vector2 = tr["between"]
	var lin := clampf((u - w.x) / maxf(w.y - w.x, 1e-6), 0.0, 1.0)
	var rel := from * x0.affine_inverse()
	var p_from := rel * q0
	var r_from := rel.basis.orthonormalized()
	if not e.has("_pour"):
		e["_pour"] = _pour_plan(tr, p_from, r_from, q0, float(e["t0"]) + w.x * d)
	var plan: Dictionary = e["_pour"]
	if plan.is_empty():
		return from
	var r_level: Basis = plan["level"]
	var lip: Vector3 = plan["lip"]
	var at: Vector3 = plan["at"]
	var axis: Vector3 = plan["axis"]
	var pre := float(plan["pre"])
	var seed := int(tr.get("_hand", 0))
	var above := at + Vector3.UP * float(plan["rise"])
	if lin < POUR_BRING * POUR_OVER:
		# ...brought over it level, as a hand carries what is full, over what is between ([method _clearance]) - its lip over the
		# mouth, high enough that its body clears it
		var s := lin / (POUR_BRING * POUR_OVER)
		var p_at := above - r_level * lip
		if not e.has("_clear"):
			e["_clear"] = _clearance(tr, p_from, p_at, Vector3.ZERO, Vector3.ZERO, r_from, r_level, q0, x0, seed, float(e["t0"]) + w.x * d)
		var lift := maxf(float(e["_clear"]), POUR_LIFT)
		var p := Hands.carried(p_from, p_at, Vector3.ZERO, Vector3.ZERO, lift, s, seed)
		var r := Basis(Quaternion(r_from).slerp(Quaternion(r_level), Hands.timing(_turn_share(s))))
		var dr: Array = Hands.drift(T, seed, Hands.held(s))
		return _rebuilt((dr[1] as Basis) * r, p + (dr[0] as Vector3), q0, x0)
	if lin < POUR_BRING:
		# ...then lowered onto it, tipping toward it about its lip as it comes down - so its body swings away from the mouth, and
		# whatever comes over the lip already falls into it
		var sd := Hands.timing((lin - POUR_BRING * POUR_OVER) / (POUR_BRING * (1.0 - POUR_OVER)))
		var r := Basis(axis, pre * sd) * r_level
		var dr: Array = Hands.drift(T, seed, 0.5)
		return _rebuilt(r, above.lerp(at, sd) - r * lip + (dr[0] as Vector3), q0, x0)
	var s2 := (lin - POUR_BRING) / (1.0 - POUR_BRING)
	var back := 1.0 - POUR_BACK
	var angle := 0.0
	var lip_at := at
	var brink: PackedFloat32Array = plan["brink"]
	var wet_end := maxf(pre, brink[POUR_SHARES])
	var most := maxf(wet_end, float(plan.get("tip", brink[POUR_SHARES])))
	# ...the tipping's time shared by the turn each part makes: the brink's as much of it as its turn is of the whole (a full jug's
	# most of it; a dry dish's, whose brink ends 26 degrees over, a little)
	var wet := clampf((wet_end - pre) / maxf(most - pre, 1e-6), POUR_WET.x, POUR_WET.y) if most > wet_end + 1e-4 else 1.0
	if s2 < back * wet:
		# ...along its brink, share by share as the stretch goes - a little eased in and out - and never less than it came in at
		var q := Hands.timing(s2 / (back * wet), 0.0) * float(POUR_SHARES)
		var j := mini(int(q), POUR_SHARES - 1)
		angle = maxf(pre, lerpf(brink[j], brink[j + 1], q - float(j)))
	elif s2 < back:
		# ...then on to its most, so what does not flow follows what does
		var sw := Hands.timing((s2 - back * wet) / (back * (1.0 - wet)))
		angle = lerpf(wet_end, most, sw)
	else:
		# ...and back level from where its tipping ended, its lip rising as it comes back so its body clears the mouth
		var sb := Hands.timing((s2 - back) / POUR_BACK)
		angle = most * (1.0 - sb)
		lip_at = at + Vector3.UP * float(plan["rise"]) * sb
	var r := Basis(axis, angle) * r_level
	# ...its lip held where it was put: the hand's unsteadiness only a share of a careful move's
	var dr: Array = Hands.drift(T, seed, 0.5)
	return _rebuilt(r, lip_at - r * lip + (dr[0] as Vector3), q0, x0)


## What a pour does ([method _pour_at]), found once: track [param tr]'s vessel, its pivot [param p_from]
## and turn [param r_from] as it begins (from as built), the pivot as built [param q0], show time [param
## T] - `{level: its turn brought level with its handle away from the mouth, lip: its lip from the pivot
## as built, at: where the lip is held, axis: what it turns about}`, or empty: it holds no vessel, or
## names nothing to pour into.
func _pour_plan(tr: Dictionary, p_from: Vector3, r_from: Basis, q0: Vector3, T: float) -> Dictionary:
	var vs_sd: Dictionary = {}
	var vs: Vessel = null
	var best := -1.0
	for L in _liquids_ref:
		var sd: Dictionary = _solids_ref[int((L as Dictionary)["solid"])]
		var mine := (tr.has("_ti") and int(sd["thing"]) == int(tr["_ti"])) or (tr.has("_wi") and _within(int(sd["wi"]), int(tr["_wi"])) == 1)
		if mine and float((L as Dictionary)["full_v"]) > best:
			best = float((L as Dictionary)["full_v"])
			vs_sd = sd
			vs = (L as Dictionary)["vessel"]
	var mouth := _mouth_of(String(tr.get("into", "")), T)
	if vs == null or mouth.is_empty():
		return {}
	var rest: Transform3D = vs_sd["rest"]
	# Brought level: its opening turned straight up, the least turn from how it is held
	var axis0 := (rest.basis * Vector3.UP).normalized()
	var r_level := Basis(Quaternion(r_from * axis0, Vector3.UP)) * r_from
	var rim_mid := Vector3.ZERO
	for q in vs.rim:
		rim_mid += rest * q
	rim_mid /= float(maxi(vs.rim.size(), 1))
	var m: Vector3 = mouth["at"]
	var way := Vector3(m.x - (p_from.x + (r_level * (rim_mid - q0)).x), 0.0, 0.0)
	var dir := Vector3(signf(way.x) if absf(way.x) > 0.005 else -1.0, 0.0, 0.0)
	# ...its handle away from the mouth: what it is held by (its pivot) turned about its opening to the far side, across the view
	var handle := r_level * (q0 - rim_mid)
	handle.y = 0.0
	if handle.length() > POUR_HANDLE:
		var turn := Basis(Vector3.UP, handle.normalized().signed_angle_to(-dir, Vector3.UP))
		r_level = turn * r_level
	# ITS LIP: the rim's outer edge furthest toward the mouth
	var k_best := 0
	var most := -INF
	for k in vs.lip.size():
		var o := (r_level * (rest * vs.lip[k] - rim_mid)).dot(dir)
		if o > most:
			most = o
			k_best = k
	var lip := rest * vs.lip[k_best] - q0
	var axis := Vector3.UP.cross(dir).normalized()
	var tip := deg_to_rad(float(tr.get("tip", 120.0)))
	# Its brink, share by share: the least tip at which what fills that share of its inside reaches the
	# lip's crest - tipped along it, a full vessel's flow is steady, never a gush (a gush throws its
	# stream past a small mouth)
	var brink := PackedFloat32Array()
	for j in POUR_SHARES + 1:
		var f := maxf(1.0 - float(j) / float(POUR_SHARES), 0.02)
		var found := tip
		for a in range(0, 171, 2):
			var th := deg_to_rad(float(a))
			var up := ((Basis(axis, th) * r_level * rest.basis).inverse() * Vector3.UP).normalized()
			if vs.level(up, f) >= vs.rim[k_best].dot(up) - 0.0003:
				found = th
				break
		brink.append(minf(found, tip))
	# Held over the mouth: `over` above its rim - as low as its width allows, left out - and short of its
	# middle by the stream's throw: over a crest what flows leaves at about sqrt(2/3 g head) and is carried
	# sideways as it falls, sqrt(4/3 head fall) - then high enough that the vessel's body clears the rim
	# beside it as it tips from where it comes in to its most ([method _pour_clear])
	var mr := float(mouth["r"])
	var over := float(tr.get("over", -1.0)) * 0.01 if float(tr.get("over", -1.0)) >= 0.0 else clampf(mr * POUR_OVER_R, POUR_OVER_LEAST, POUR_OVER_MOST)
	var throw := sqrt(4.0 / 3.0 * POUR_HEAD * over)
	var at := m + Vector3.UP * over - dir * minf(throw, mr * 0.8)
	# ...its body clear of the mouth's rim beside it, all of it ([method _pour_clear]): tipped from where it comes in to its most,
	# held there - and on the way down onto it, tipping as it comes, from as high as it was brought level
	var own: Array = []
	for sd in _solids_ref:
		if (tr.has("_ti") and int((sd as Dictionary)["thing"]) == int(tr["_ti"])) or (tr.has("_wi") and _within(int((sd as Dictionary)["wi"]), int(tr["_wi"])) == 1):
			own.append(sd)
	# ...tipped as it comes in only as far as its body needs to swing clear of the mouth: a tall jug well,
	# a shallow ladle hardly - and held a little higher rather than tipped early: past its brink as it
	# comes in, a full vessel gushes before it is over the mouth
	var pre := tip * POUR_PRE
	for kk in 7:
		var th := tip * POUR_PRE * float(kk) / 6.0
		var r := Basis(axis, th) * r_level
		if _pour_clear(own, r, at - r * lip, q0, m, mr) <= POUR_HIGHER:
			pre = th
			break
	var raise := 0.0
	for k in 4:
		var r := Basis(axis, lerpf(pre, tip, float(k) / 3.0)) * r_level
		raise = maxf(raise, _pour_clear(own, r, at - r * lip, q0, m, mr))
	# ...its stream aimed for the height it falls from now
	var fall := over + raise
	at = m + Vector3.UP * fall - dir * minf(sqrt(4.0 / 3.0 * POUR_HEAD * fall), mr * 0.8)
	var rise := 0.0
	for k in 4:
		var sk := float(k) / 4.0
		var r := Basis(axis, pre * sk) * r_level
		rise = maxf(rise, _pour_clear(own, r, at - r * lip, q0, m, mr) / (1.0 - sk))
	return {"level": r_level, "lip": lip, "at": at, "axis": axis, "pre": pre, "rise": rise, "mouth": m, "brink": brink, "tip": tip}


## How much higher a vessel (the solids [param own] of what moves it) turned [param r] with its pivot at [param p] must be for
## its body to clear the mouth at [param m] of radius [param mr] (meters) by [constant POUR_GAP]: its surface's points within
## the mouth's reach beside it.
func _pour_clear(own: Array, r: Basis, p: Vector3, q0: Vector3, m: Vector3, mr: float) -> float:
	var low := INF
	for sd in own:
		var f: ShapeField = (sd as Dictionary).get("field")
		if f == null:
			continue
		var rest: Transform3D = (sd as Dictionary)["rest"]
		for q in f.surface_points():
			var w := p + r * (rest * q - q0)
			if Vector2(w.x - m.x, w.z - m.z).length() < mr + POUR_GAP * 2.0:
				low = minf(low, w.y)
	return maxf(m.y + POUR_GAP - low, 0.0) if low < INF else 0.0


## A dip ([constant Motions.LAWS] `dip`) at [param u] through its act ([param d] seconds; show time
## [param T]): the vessel its track [param tr] moves, from [param from], brought over the mouth of what
## holds the liquid, its handle out over the rim the way it already points, tipped only as far as its
## handle needs to clear the rim ([method _dip_plan]); lowered straight in until it is near the floor,
## held while it fills, drawn up slowly at that tip - so what it cannot hold falls back in - and brought
## level once it is out.
func _dip_at(e: Dictionary, tr: Dictionary, u: float, d: float, T: float, from: Transform3D, x0: Transform3D, q0: Vector3) -> Transform3D:
	var w: Vector2 = tr["between"]
	var lin := clampf((u - w.x) / maxf(w.y - w.x, 1e-6), 0.0, 1.0)
	var rel := from * x0.affine_inverse()
	var p_from := rel * q0
	var r_from := rel.basis.orthonormalized()
	if not e.has("_dip"):
		e["_dip"] = _dip_plan(tr, p_from, r_from, q0, float(e["t0"]) + w.x * d)
	var plan: Dictionary = e["_dip"]
	if plan.is_empty():
		return from
	var mid: Vector3 = plan["mid"]
	var r_level: Basis = plan["level"]
	var top: Vector3 = plan["top"]
	var low: Vector3 = plan["low"]
	var seed := int(tr.get("_hand", 0))
	var r_down := Basis(plan["axis"] as Vector3, deg_to_rad(_dip_tip(plan, top.y))) * r_level
	var c := top
	if lin < DIP_PHASES.x:
		# ...brought there as a hand carries it, over what is between, tipped as it will go in
		var s := lin / DIP_PHASES.x
		var p_at := top - r_down * mid
		if not e.has("_clear"):
			e["_clear"] = _clearance(tr, p_from, p_at, Vector3.ZERO, Vector3.ZERO, r_from, r_down, q0, x0, seed, float(e["t0"]) + w.x * d)
		var p := Hands.carried(p_from, p_at, Vector3.ZERO, Vector3.ZERO, maxf(float(e["_clear"]), POUR_LIFT), s, seed)
		var rb := Basis(Quaternion(r_from).slerp(Quaternion(r_down), Hands.timing(_turn_share(s))))
		var dr: Array = Hands.drift(T, seed, Hands.held(s))
		return _rebuilt((dr[1] as Basis) * rb, p + (dr[0] as Vector3), q0, x0)
	elif lin < DIP_PHASES.y:
		c = top.lerp(low, Hands.timing((lin - DIP_PHASES.x) / (DIP_PHASES.y - DIP_PHASES.x)))
	elif lin < DIP_PHASES.z:
		c = low
	elif lin < DIP_PHASES.w:
		c = low.lerp(top, Hands.timing((lin - DIP_PHASES.z) / (DIP_PHASES.w - DIP_PHASES.z)))
	# ...tipped at each depth no more than its walls ask, so it comes up as level as it can, and level at last
	var tip := _dip_tip(plan, c.y)
	if lin >= DIP_PHASES.w:
		tip *= 1.0 - Hands.timing((lin - DIP_PHASES.w) / (1.0 - DIP_PHASES.w))
	var r := Basis(plan["axis"] as Vector3, deg_to_rad(tip)) * r_level
	var dr: Array = Hands.drift(T, seed, 0.5)
	return _rebuilt(r, c - r * mid + (dr[0] as Vector3), q0, x0)


## What a dip does ([method _dip_at]), found once: track [param tr]'s vessel, its pivot [param p_from] and
## turn [param r_from] as it begins (from as built), the pivot as built [param q0], show time [param T] -
## `{level, down: its turn level and tipped to go in, mid: its rim's middle from the pivot as built, top:
## where that middle is held over the mouth, low: and down near the floor}`, or empty. The least tip at
## each depth: tipped in steps until its body - every solid of what moves - clears the other's walls by
## [constant POUR_GAP], at depths from over the rim down to [constant DIP_FLOOR] over its floor - as deep
## as any tip goes - with its bowl as far across from the rim its handle goes over as goes deepest and
## least tipped.
func _dip_plan(tr: Dictionary, p_from: Vector3, r_from: Basis, q0: Vector3, T: float) -> Dictionary:
	var vs_sd: Dictionary = {}
	var vs: Vessel = null
	var best := -1.0
	var own: Array = []
	for sd in _solids_ref:
		if (tr.has("_ti") and int((sd as Dictionary)["thing"]) == int(tr["_ti"])) or (tr.has("_wi") and _within(int((sd as Dictionary)["wi"]), int(tr["_wi"])) == 1):
			own.append(sd)
	for L in _liquids_ref:
		var sd: Dictionary = _solids_ref[int((L as Dictionary)["solid"])]
		if own.has(sd) and float((L as Dictionary)["full_v"]) > best:
			best = float((L as Dictionary)["full_v"])
			vs_sd = sd
			vs = (L as Dictionary)["vessel"]
	var into := _vessel_into(String(tr.get("into", "")), T)
	if vs == null or into.is_empty():
		return {}
	var rest: Transform3D = vs_sd["rest"]
	var axis0 := (rest.basis * Vector3.UP).normalized()
	var r_level := Basis(Quaternion(r_from * axis0, Vector3.UP)) * r_from
	var rim_mid := Vector3.ZERO
	for q in vs.rim:
		rim_mid += rest * q
	rim_mid /= float(maxi(vs.rim.size(), 1))
	var mid := rim_mid - q0
	var m: Vector3 = into["at"]
	# ...its handle out over the rim whichever way it already points - a rim goes all round; turned to
	# point back the way it came, a tool would swing round lying on its rest and sweep into the table - or,
	# with no handle, the way it came
	var handle := r_level * (q0 - rim_mid)
	handle.y = 0.0
	var out := p_from + r_level * mid - m
	out.y = 0.0
	var hdir := handle.normalized() if handle.length() > POUR_HANDLE else (out.normalized() if out.length() > 0.005 else Vector3.RIGHT)
	var tip_axis := hdir.cross(Vector3.UP).normalized()
	var pts := PackedVector3Array()
	for sd in own:
		var f: ShapeField = (sd as Dictionary).get("field")
		if f == null:
			continue
		for q in f.surface_points():
			pts.append(((sd as Dictionary)["rest"] as Transform3D) * q - rim_mid)
	var lowest := func(r: Basis) -> float:
		var lo := INF
		for q in pts:
			lo = minf(lo, (r * q).y)
		return lo
	var tf: ShapeField = (into["sd"] as Dictionary)["field"]
	var tinv: Transform3D = (into["xf"] as Transform3D).affine_inverse()
	# (its surface met by every few of its points: the plan is made once, on the app's thread too)
	var few := PackedVector3Array()
	for k in range(0, pts.size(), maxi(1, pts.size() / DIP_POINTS)):
		few.append(pts[k])
	var clear := func(r: Basis, c: Vector3) -> bool:
		for q in few:
			if tf.sample(tinv * (c + r * q)).x < POUR_GAP:
				return false
		return true
	# ...as far across as it goes: the further its bowl from the rim its handle goes over, the less it must tip to go in
	var reach := 0.0
	for q in vs.rim:
		var o := r_level * (rest * q - rim_mid)
		reach = maxf(reach, Vector2(o.x, o.z).length())
	var across := maxf(float(into["r"]) - reach - DIP_WALL, 0.0)
	var top_y := float(into["rim"]) + DIP_ABOVE - minf(lowest.call(r_level), 0.0)
	var pick: Dictionary = {}
	for kx in 4:
		var xz := m - hdir * across * float(kx) / 3.0
		# The least tip at each depth, from over the rim down toward the floor: it goes in no further than some tip clears
		var hs := PackedFloat32Array()
		var tips := PackedFloat32Array()
		var floor_c := float(into["floor"]) + DIP_FLOOR
		for j in DIP_DEPTHS + 1:
			var found := -1.0
			var c_y := 0.0
			for k in DIP_TIPS + 1:
				var r := Basis(tip_axis, deg_to_rad(DIP_TIP_MOST) * float(k) / float(DIP_TIPS)) * r_level
				c_y = lerpf(top_y, floor_c - lowest.call(r), float(j) / float(DIP_DEPTHS))
				if bool(clear.call(r, Vector3(xz.x, c_y, xz.z))):
					found = DIP_TIP_MOST * float(k) / float(DIP_TIPS)
					break
			if found < 0.0:
				break
			hs.append(c_y)
			tips.append(found)
		if hs.is_empty():
			continue
		# ...the deepest, and of those alike the least tipped where it leaves the liquid
		var deep := hs[hs.size() - 1]
		if pick.is_empty() or deep < float(pick["deep"]) - 0.003 or (absf(deep - float(pick["deep"])) <= 0.003 and tips[tips.size() / 2] < (pick["tips"] as PackedFloat32Array)[(pick["tips"] as PackedFloat32Array).size() / 2]):
			pick = {"xz": xz, "hs": hs, "tips": tips, "deep": deep}
	if pick.is_empty():
		return {}
	var hs_p: PackedFloat32Array = pick["hs"]
	var xz_p: Vector3 = pick["xz"]
	return {"level": r_level, "mid": mid, "axis": tip_axis, "hs": hs_p, "tips": pick["tips"],
		"top": Vector3(xz_p.x, hs_p[0], xz_p.z), "low": Vector3(xz_p.x, hs_p[hs_p.size() - 1], xz_p.z)}


## How far a thing brought somewhere has turned at [param s] of its way there: lifted before it turns - none of it for the first
## [constant BRING_TURN_FROM] of the way, so a long thing lying down never sweeps the table as it turns.
static func _turn_share(s: float) -> float:
	return clampf((s - BRING_TURN_FROM) / (1.0 - BRING_TURN_FROM), 0.0, 1.0)


## A dip's tip at height [param y] of its rim's middle ([param plan]'s `hs` and `tips`, from the top down): the least that clears
## there, between the depths it was found at (degrees).
static func _dip_tip(plan: Dictionary, y: float) -> float:
	var hs: PackedFloat32Array = plan["hs"]
	var tips: PackedFloat32Array = plan["tips"]
	if y >= hs[0]:
		return tips[0]
	for j in range(1, hs.size()):
		if y >= hs[j]:
			return lerpf(tips[j - 1], tips[j], (hs[j - 1] - y) / maxf(hs[j - 1] - hs[j], 1e-6))
	return tips[tips.size() - 1]


## What holds the liquid a dip names ([param into]: a thing, a part, or "thing/part") at show time
## [param T]: `{sd: its vessel's solid, xf: where that solid is, at: its rim's middle, rim: its rim's
## lowest height, floor: its inside's lowest (the table's space, meters)}` - its biggest inside - or empty.
func _vessel_into(into: String, T: float) -> Dictionary:
	var name := into.strip_edges()
	if name.is_empty():
		return {}
	var wi := _work_named(name)
	var ti := -1
	if wi < 0:
		var low := name.to_lower()
		for k in works.size():
			if _part_label(k).to_lower() == low or String((works[k] as Dictionary)["name"]).to_lower() == low:
				wi = k
				break
	if wi < 0:
		ti = _thing_named(name)
	if wi < 0 and ti < 0:
		return {}
	var best := -1.0
	var out := {}
	for L in _liquids_ref:
		var sd: Dictionary = _solids_ref[int((L as Dictionary)["solid"])]
		var mine := _within(int(sd["wi"]), wi) == 1 if wi >= 0 else int(sd["thing"]) == ti
		# ...the inside that holds a liquid before one that is empty (a pot on a brazier: the pot, never the brazier's pan)
		var rank := float((L as Dictionary)["full_v"]) + (1.0 if float((L as Dictionary).get("v0", 0.0)) > 1e-9 else 0.0)
		if not mine or rank <= best:
			continue
		best = rank
		var vs: Vessel = (L as Dictionary)["vessel"]
		var xf: Transform3D = (_thing_world(int(sd["oi"]), T) if String(sd["owner"]) == "t" else _work_world(int(sd["oi"]), T)) * (sd["local"] as Transform3D)
		var mid := Vector3.ZERO
		var rim := INF
		for q in vs.rim:
			var p := xf * q
			mid += p
			rim = minf(rim, p.y)
		mid /= float(maxi(vs.rim.size(), 1))
		var fl := INF
		for k in range(0, vs.points.size(), 8):
			fl = minf(fl, (xf * vs.points[k]).y)
		var rad := INF
		for q in vs.rim:
			rad = minf(rad, Vector2((xf * q).x - mid.x, (xf * q).z - mid.z).length())
		out = {"sd": sd, "xf": xf, "at": mid, "rim": rim, "floor": fl, "r": rad}
	return out


## The mouth of what a pour names ([param into]: a thing, a part - "vial 1" or "rack/vial 1" - or a point
## "thing.point") at show time [param T]: `{at: the middle of its rim (the table's space), r: its radius
## (meters)}` - a point's, 1 cm across - or empty, naming nothing on the table.
func _mouth_of(into: String, T: float) -> Dictionary:
	var name := into.strip_edges()
	if name.is_empty():
		return {}
	var wi := _work_named(name)
	var ti := -1
	if wi < 0:
		var low := name.to_lower()
		for k in works.size():
			if _part_label(k).to_lower() == low or String((works[k] as Dictionary)["name"]).to_lower() == low:
				wi = k
				break
	if wi < 0:
		ti = _thing_named(name)
	if wi < 0 and ti < 0:
		if name.contains("."):
			var p := place_of(name, Vector3.INF, T)
			return {"at": p, "r": 0.01} if p != Vector3.INF else {}
		return {}
	# ...its inside's rim where it is now: of the part, or of the thing's biggest inside
	var best := -1.0
	var out := {}
	for L in _liquids_ref:
		var sd: Dictionary = _solids_ref[int((L as Dictionary)["solid"])]
		var mine := _within(int(sd["wi"]), wi) == 1 if wi >= 0 else int(sd["thing"]) == ti
		if not mine or float((L as Dictionary)["full_v"]) <= best:
			continue
		best = float((L as Dictionary)["full_v"])
		var vs: Vessel = (L as Dictionary)["vessel"]
		var xf: Transform3D = (_thing_world(int(sd["oi"]), T) if String(sd["owner"]) == "t" else _work_world(int(sd["oi"]), T)) * (sd["local"] as Transform3D)
		var mid := Vector3.ZERO
		var top := -INF
		for q in vs.rim:
			var p := xf * q
			mid += p
			top = maxf(top, p.y)
		mid /= float(maxi(vs.rim.size(), 1))
		var rad := 0.0
		for q in vs.rim:
			rad = maxf(rad, Vector2((xf * q).x - mid.x, (xf * q).z - mid.z).length())
		out = {"at": Vector3(mid.x, top, mid.z), "r": rad}
	if out.is_empty():
		var p := place_of((String((things[ti] as Dictionary)["name"]) if ti >= 0 else String((things[int((works[wi] as Dictionary)["thing"])] as Dictionary)["name"])) + ".top", Vector3.INF, T)
		return {"at": p, "r": 0.01} if p != Vector3.INF else {}
	return out


## The highest surface of any thing but [param skip] under any of [param probes] (meters, the table's space) at show time
## [param T], or -INF where nothing is: the table's own top is what a carry goes along, never in its way.
func _top_under(probes: Array, skip: int, T: float, skip_wi := -1, meshes: Variant = null) -> float:
	var top := -INF
	for m in (meshes if meshes != null else _meshes_at(skip, T, skip_wi)) as Array:
		var tm: TriangleMesh = (m as Array)[0]
		var back: Transform3D = (m as Array)[1]
		var down := (back.basis * Vector3.DOWN).normalized()
		for c in probes:
			if not _over(m, c):
				continue
			var hit: Dictionary = _ray(tm, back * Vector3((c as Vector3).x, CLEAR_FROM_Y, (c as Vector3).z), down)
			if not hit.is_empty():
				top = maxf(top, (back.affine_inverse() * (hit["position"] as Vector3)).y)
	return top


## Whether a ray straight down through point [param c] can meet [method _meshes_at]'s mesh [param m]: its
## box where it is spans the point across - so a set-down's rays are not each cast at every mesh on the table.
static func _over(m: Array, c: Vector3) -> bool:
	var b: AABB = m[2]
	return c.x >= b.position.x - 0.001 and c.x <= b.end.x + 0.001 and c.z >= b.position.z - 0.001 and c.z <= b.end.z + 0.001


## Whether a thing ([param owner] "t", [param oi] its index) or part ("w") is where it was built at every
## moment: no act moves it, nor the parts it hangs from, nor its thing, none of them runs, swings or hangs
## from a swing - so where a search finds it needs nothing worked out ([method _room], [method
## _meshes_at]: of a table's three hundred solids, most). The app's work only - the bake's twin has where
## the physics has things ([member posed]), and asks every one. Found once an act's set ([member _still_of]).
func _still(owner: String, oi: int) -> bool:
	if not posed.is_empty() or not posed_things.is_empty():
		return false
	var key := owner + str(oi)
	if _still_of.has(key):
		return _still_of[key]
	var out := true
	var ti := oi
	if owner == "w":
		var c := oi
		while c >= 0 and out:
			for k in ["pose", "angle", "offset"]:
				if _moved.has("w%d:%s" % [c, k]) or _runs_of.has("w%d:%s" % [c, k]):
					out = false
			if _moved.has("g%d:pose" % int(_group_of.get(c, -1))) or swings.has(c) or hung.has(c):
				out = false
			c = int(_parent_work.get(c, -1))
		ti = int((works[oi] as Dictionary)["thing"])
	if _moved.has("t%d:pose" % ti) or _runs_of.has("t%d:pose" % ti):
		out = false
	_still_of[key] = out
	return out


## What a ray down meets at show time [param T]: `[[its mesh, the table's space back to where it was
## built, its box there]]` - every thing but [param skip], and every free part where it is then ([method
## _part_mesh_of]), but the one moved ([param skip_wi]) and what is in it, or the thing moved whole's own.
## Posed once for all a search's points ([method _top_under], [method _settle]), not once a point of a foot.
func _meshes_at(skip: int, T: float, skip_wi := -1) -> Array:
	var out: Array = []
	for tj in things.size():
		if tj == skip:
			continue
		var tm := _mesh_of(tj)
		if tm != null:
			var back := Transform3D.IDENTITY if _still("t", tj) else _world_rest_thing(tj) * _thing_world(tj, T).affine_inverse()
			out.append([tm, back, back.affine_inverse() * ((things[tj] as Dictionary)["mesh_box"] as AABB)])
	for wi in works.size():
		var tm: Variant = (works[wi] as Dictionary).get("mesh")
		if tm == null or int((works[wi] as Dictionary)["thing"]) == skip or (skip_wi >= 0 and _within(wi, skip_wi) != 0):
			continue
		var back := Transform3D.IDENTITY if _still("w", wi) else (_rest["w%d:pose" % wi] as Transform3D) * _work_world(wi, T).affine_inverse()
		out.append([tm, back, back.affine_inverse() * ((works[wi] as Dictionary)["mesh_box"] as AABB)])
	return out


## Room for it: how far to one side (meters, level) track [param tr]'s thing or part, its move ending at
## [param end] at show time [param T], is set so that it stands in nothing - the nearest place, in rings
## out from where it was sent ([constant ROOM_STEP]), where none of its own surface is [constant
## ROOM_DEEP] into a solid as the plan has that solid then; nothing where it was sent is clear, or
## nothing near is. What it is a part of or was built in is never in its way: a cork goes back into its
## jar, a pestle into its mortar, a ladle onto its rest. Measured on the solids' own fields ([member
## _solids_ref]), so a cup dipped into a bowl's hollow is clear of the bowl, where any box round the bowl
## is not. The puppeteer says where, the hand finds room (next/table_physics.md, "Primitives"): two acts
## that send things to the same spot do not hold each other back.
func _room(tr: Dictionary, end: Transform3D, T: float) -> Vector3:
	if _solids_ref.is_empty():
		return Vector3.ZERO
	# ...counted while profiling (a gate's: a plan made again keeps what it found, [constant FOUND])
	if profiling:
		profile["rooms found"] = int(profile.get("rooms found", 0)) + 1
	var ch := String(tr["_ch"])
	var moved := end * (_rest.get(ch, Transform3D.IDENTITY) as Transform3D).affine_inverse()
	var own_t := int(tr.get("_ti", -1))
	var own_w := int(tr.get("_wi", -1))
	if tr.has("_gi"):
		own_w = int(((groups[int(tr["_gi"])] as Dictionary)["members"] as Array)[0])
	var home_t := own_t
	if home_t < 0 and own_w >= 0:
		home_t = int((works[own_w] as Dictionary)["thing"])
	var mine := PackedVector3Array()
	var others: Array = []
	for sd in _solids_ref:
		var d: Dictionary = sd
		if not d.has("field"):
			continue
		var wi := int(d["wi"])
		var is_mine := (own_t >= 0 and int(d["thing"]) == own_t and (wi < 0 or not _moved.has("w%d:pose" % wi))) or (own_w >= 0 and _within(wi, own_w) == 1)
		if is_mine:
			var pose: Transform3D = moved * (_world_rest_thing(int(d["oi"])) if String(d["owner"]) == "t" else (_rest["w%d:pose" % int(d["oi"])] as Transform3D)) * (d["local"] as Transform3D)
			var sp := (d["field"] as ShapeField).surface_points()
			for k in range(0, sp.size(), maxi(1, sp.size() / ROOM_POINTS)):
				mine.append(pose * sp[k])
			continue
		# ...never what it is a part of, or was built in: its thing's own body, the parts it hangs from
		if int(d["thing"]) == home_t and (String(d["owner"]) == "t" or (own_w >= 0 and _within(own_w, wi) != 0)):
			continue
		var at: Transform3D = (d["rest"] as Transform3D) if _still(String(d["owner"]), int(d["oi"])) \
			else (_thing_world(int(d["oi"]), T) if String(d["owner"]) == "t" else _work_world(int(d["oi"]), T)) * (d["local"] as Transform3D)
		others.append([d["field"], at.affine_inverse(), at * (d["box"] as AABB)])
	if mine.is_empty() or others.is_empty():
		return Vector3.ZERO
	var reach := AABB(mine[0], Vector3.ZERO)
	for q in mine:
		reach = reach.expand(q)
	var near: Array = []
	for o in others:
		if ((o as Array)[2] as AABB).intersects(reach.grow(ROOM_MOST)):
			near.append(o)
	var count_in := func(off: Vector3) -> int:
		var n := 0
		for q in mine:
			var p: Vector3 = q + off
			for o in near:
				if ((o as Array)[2] as AABB).grow(0.001).has_point(p) and ((o as Array)[0] as ShapeField).sample(((o as Array)[1] as Transform3D) * p).x < -ROOM_DEEP:
					n += 1
					break
		return n
	if int(count_in.call(Vector3.ZERO)) == 0:
		return Vector3.ZERO
	var ring := ROOM_STEP
	while ring <= ROOM_MOST + 1e-6:
		var n := maxi(8, int(ceil(TAU * ring / ROOM_STEP)))
		for k in n:
			var off := Vector3(cos(TAU * float(k) / float(n)), 0.0, sin(TAU * float(k) / float(n))) * ring
			if int(count_in.call(off)) == 0:
				# ...and a little further: a hand setting a thing beside another leaves it room, its bow and sway a few millimeters
				return off * ((ring + ROOM_SPARE) / ring)
		ring += ROOM_STEP
	return Vector3.ZERO


## How far a thing set down rises or falls to rest on what is under it (carry's `down`, [constant
## Motions.LAWS]): [param tr]'s thing or part, posed [param x], its lowest point brought onto the table's
## top or onto the highest thing under it where that thing is at show time [param T] (meters).
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
	# Its foot, never its box: what it stands on is what is under its own lowest surface - a round
	# mortar's box corners stand out past its base, over the edge of what is beside it
	var foot := _foot(tr, x)
	if not foot.is_empty():
		probes = foot
		low = INF
		for c in foot:
			low = minf(low, (c as Vector3).y)
	var under := 0.0
	var own_wi := int(tr.get("_wi", -1))
	# ...each thing, and each free part where it is then ([method _part_mesh_of]: a jar set down beside another fetched on its
	# own), posed once, then met by every point of the foot
	var meshes := _meshes_at(skip, T, own_wi)
	for c in probes:
		var from := Vector3((c as Vector3).x, top + 0.02, (c as Vector3).z)
		for m in meshes:
			if not _over(m, c):
				continue
			var back: Transform3D = (m as Array)[1]
			var hit: Dictionary = _ray((m as Array)[0], back * from, (back.basis * Vector3.DOWN).normalized())
			if not hit.is_empty():
				var y := (back.affine_inverse() * (hit["position"] as Vector3)).y
				if y < top:
					under = maxf(under, y)
	return under - low + SET_GAP


## Where track [param tr]'s thing or part stands, posed [param x]: the points of its own surfaces within [constant FOOT]
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

## Everything the work moves, at show time [param t]: whole things, then their parts, then what smokes and
## pours and bursts, and every liquid's surface.
func tick(t: float) -> void:
	if assembly != null:
		assembly.tick(t)
	if game != null:
		game.tick(t)
	if things.is_empty():
		return
	var c := Time.get_ticks_usec() if profiling else 0
	# What is in things, baked as far as this moment - first, since a thing an act moves is drawn where the bake has it
	if physics != null:
		physics.tick(t)
	c = _spent("physics drawn", c)
	# What moved this frame: -1 - a thing, or a part. A node takes what hangs from it, in the picture, and what the bake has elsewhere
	# is posed against it again (below)
	var stirred := {}
	for ti in things.size():
		var ch := "t%d:pose" % ti
		if not _moved.has(ch):
			continue
		var th: Dictionary = things[ti]
		var node: Node3D = th["node"]
		# ...where the bake has it, a rigid body ([method TablePhysics._make_rigid]) - the acts' own pose while an act is
		# checked, or where the bake has not got to while the work moves it
		var baked: Variant = physics.thing_pose_of(ti, t) if physics != null and not _planned and not _outran_ch([ch], t) else null
		var x := _parent_world(node).affine_inverse() * ((baked as Transform3D) if baked != null else (value(ch, t) as Transform3D))
		if not node.transform.is_equal_approx(x):
			stirred[-1 - ti] = true
		node.transform = x
	c = _spent("things posed", c)
	# ...and its loose parts and the parts it picks up posed by it ([method _pose_work]) - only what can
	# have changed ([method _settled]): of a table's three hundred parts a frame finds a few moving. After
	# a jump in time, a new plan or a check, every one.
	var full := _full or absf(t - _last_t) > QUIET_JUMP or _planned != _last_planned \
		or (physics != null and physics._outrun != _last_outrun)
	_full = false
	_last_t = t
	_last_planned = _planned
	_last_outrun = physics._outrun if physics != null else false
	# ...and whatever hangs from what moved: a free part's node hangs from its thing's, and is where the
	# bake has it only as it is posed against that node. [method _settled] asks of the moves written on the
	# thing, and its body moves outside them too - let go and falling, swaying in a hold, catching up - so
	# a part at rest would be dragged along in the picture, the bake never moving it, until the next pose
	# took it back. Parents first, so each is posed against where its parent is now.
	for wi in _order_of_posing():
		var wk: Dictionary = works[wi]
		var pw := int(_parent_work.get(wi, -1))
		var above: bool = stirred.has(-1 - int(wk["thing"])) or (pw >= 0 and stirred.has(pw))
		if full or (above and String(wk["kind"]) == "free") or not _settled(wi, t):
			var node: Node3D = wk["node"]
			var was: Transform3D = node.transform
			_pose_work(wi, t)
			if above or not node.transform.is_equal_approx(was):
				stirred[wi] = true
		elif above:
			stirred[wi] = true
	c = _spent("parts posed", c)
	_tick_shades()
	c = _spent("shades", c)
	for p in _plumes:
		_tick_plume(p, t)
	if _air != null:
		_air.tick(t)
	for m in _timed:
		(m as ShaderMaterial).set_shader_parameter("show_time", t)
	_spent("plumes and air", c)
	if paint != null:
		paint.tick(t, func(ch: String) -> Array: return _chan.get(ch, []))
	if _first_drawn.is_empty():
		for wi in works.size():
			_first_drawn[wi] = _world_of((works[wi] as Dictionary)["node"])


## Every work, each after the part it hangs from ([method tick]: a part is posed against where its parent is), found once.
func _order_of_posing() -> PackedInt32Array:
	if _pose_order.size() == works.size():
		return _pose_order
	var depth_of := func(wi: int) -> int:
		var d := 0
		var c := int(_parent_work.get(wi, -1))
		while c >= 0:
			d += 1
			c = int(_parent_work.get(c, -1))
		return d
	var list: Array = []
	for wi in works.size():
		list.append([int(depth_of.call(wi)), wi])
	list.sort()
	_pose_order = PackedInt32Array()
	for e in list:
		_pose_order.append(int((e as Array)[1]))
	return _pose_order


## A frame's cost by what took it, while [member profiling] (a probe's): microseconds by section.
func _spent(section: String, since: int) -> int:
	if not profiling:
		return 0
	var now := Time.get_ticks_usec()
	profile[section] = int(profile.get(section, 0)) + now - since
	return now


## Every part drawn off where it first stood at [param t], and how it is posed: whether an act holds it
## then, what the bake has it as (a rigid body's held, asleep, host and touch; a loose thing's), and the
## bake's pose against the work's - a feedback capture's record of what the live viewer drew. Each row
## says the table's own clock (`now`): after a scrub it is neither the report's `time` nor the rail's.
func drawn_report(t: float) -> Array:
	var out: Array = []
	for wi in _first_drawn:
		var wk: Dictionary = works[wi]
		var x := _world_of(wk["node"])
		var x0: Transform3D = _first_drawn[wi]
		var d := x.origin.distance_to(x0.origin)
		var turn := rad_to_deg(Quaternion(x0.basis.orthonormalized()).angle_to(Quaternion(x.basis.orthonormalized())))
		if d < 0.005 and turn < 3.0:
			continue
		var ch := "w%d:pose" % wi
		var acting := false
		for e in _chan.get(ch, []):
			acting = acting or (float((e as Dictionary)["s0"]) <= t and float((e as Dictionary)["s1"]) >= t)
		var r := {"part": String(wk["name"]), "thing": String((things[int(wk["thing"])] as Dictionary)["name"]), "kind": String(wk["kind"]),
			"moved_cm": snappedf(d * 100.0, 0.1), "turned_deg": snappedf(turn, 0.1), "act_now": acting, "outran": _outran(wi, t),
			"planned": _planned, "now": snappedf(t, 0.01)}
		if physics != null:
			r["baked_to"] = physics.baked_to()
			if physics._rigid_of.has(wi):
				var bi := int(physics._rigid_of[wi])
				# ...the body itself only where the bake runs on this thread: a live bake's own is being written as this reads it, and
				# its frame says what a picture can - how far it was off its hand, and what held it back
				if physics._sync:
					var b: Dictionary = physics.rigid.bodies[bi]
					var hs := int(b["host"])
					var tc := int(b["touch"])
					r["body"] = {"held": b["held"] != null, "asleep": bool(b["asleep"]), "host": physics._solid_label(hs) if hs >= 0 else str(hs),
						"touch": physics._solid_label(tc) if tc >= 0 else str(tc)}
				else:
					var fr: Variant = physics.frame_at(t)
					if fr != null:
						var by := physics.held_by(fr as Dictionary, bi)
						r["body"] = {"off_hand_cm": snappedf(physics.held_off(fr as Dictionary, bi) * 100.0, 0.1),
							"held_back_by": physics._solid_label(by) if by >= 0 else ""}
			r["loose"] = physics._loose_of.has(wi)
			var bp: Variant = physics.pose_of(wi, t)
			if bp != null:
				r["bake_off_work_cm"] = snappedf((bp as Transform3D).origin.distance_to(_work_world(wi, t).origin) * 100.0, 0.1)
		out.append(r)
	# ...and each liquid that holds other than it began with, as the bake has it
	if physics != null:
		var now: Variant = physics.frame_at(t)
		var began: Variant = physics.frame_at(0.0)
		if now is Dictionary and began is Dictionary:
			var lq: PackedFloat32Array = (now as Dictionary)["liq"]
			var lq0: PackedFloat32Array = (began as Dictionary)["liq"]
			for li in physics.liquids.size():
				if li * 16 + 8 < lq.size() and li * 16 < lq0.size() and absf(lq[li * 16] - lq0[li * 16]) > 1e-6:
					out.append({"liquid": physics._liquid_label(li), "ml": snappedf(lq[li * 16] * 1e6, 0.1), "began_ml": snappedf(lq0[li * 16] * 1e6, 0.1),
						"surface_cm": snappedf(lq[li * 16 + 5] * 100.0, 0.01), "pouring_ml_s": snappedf(lq[li * 16 + 8] * 1e6, 0.1), "baked_to": physics.baked_to(), "now": snappedf(t, 0.01)})
	return out


## Each thing's shade on the cloth where the thing is now: gone while it is lifted or tipped, under it
## where it is set down - a thing moved whole, or one whose moving part is most of it seen from above (a
## pestle that is its own thing; a mortar's pestle leaves the mortar's shade alone). The one place the
## work reads back what it posed: the shade follows the pose, never the other way.
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
		# A free part that is most of the thing carries the shade as the thing would
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


## Whether work [param wi] is drawn as it is at [param t] already ([method tick]): no channel it is posed
## by - its own, its copies', the parts it hangs from, its thing's when it is free - has a move at
## [param t] (a little either side, so a move's last value is drawn), none of them runs all the time, it
## swings, hangs from a swing or is written on by no one - and what the physics has it as (a body's
## pose, a loose thing's, whether it is whole, a liquid's fill) is what was drawn last.
func _settled(wi: int, t: float) -> bool:
	if not _quiet_spans.has(wi):
		_quiet_spans[wi] = _spans_for(wi)
	var spans: Variant = _quiet_spans[wi]
	if spans == null:
		return false
	for sp in (spans as PackedVector2Array):
		if t >= sp.x and t <= sp.y:
			return false
	if physics == null:
		return true
	var was: Array = _drawn_of.get(wi, [])
	if was.is_empty():
		return false
	if physics._rigid_of.has(wi) or physics._loose_of.has(wi):
		var bp: Variant = physics.pose_of(wi, t)
		if typeof(bp) != typeof(was[0]) or (bp is Transform3D and not (bp as Transform3D).is_equal_approx(was[0])):
			return false
		if physics._loose_of.has(wi) and physics.whole(wi, t) != bool(was[2]):
			return false
		# ...and a sheet's bend, its pose still
		if physics.bends(wi):
			return false
	if (physics.liquid_volume(wi, t) > 1e-9) != bool(was[1]):
		return false
	return true


## SHEET [param wi] bent by [param off] ([method TablePhysics.bend_of]), its meshes made ready the first time it is asked.
func _bend_sheet(wi: int, off: Variant) -> void:
	if not _sheet_bends.has(wi):
		var list: Array = []
		var node: Node3D = (works[wi] as Dictionary)["node"]
		var built: Transform3D = physics.loose_built(wi) * _world_of(node).affine_inverse()
		var stack: Array = [node]
		while not stack.is_empty():
			var n: Node = stack.pop_back()
			stack.append_array(n.get_children())
			var mi := n as MeshInstance3D
			if mi != null and mi.mesh != null:
				var bend := SheetBend.of(mi, built * _world_of(mi), physics.sheet_points(wi))
				if bend != null:
					list.append(bend)
		_sheet_bends[wi] = list
	for b in (_sheet_bends[wi] as Array):
		(b as SheetBend).apply(off)


## The stretches of show time over which work [param wi] may change as the work poses it ([method _settled]) - or null when it may at
## any time (a part that runs, swings, hangs from a swing or is written on).
func _spans_for(wi: int) -> Variant:
	if swings.has(wi) or hung.has(wi) or _writing.has(wi):
		return null
	var wk: Dictionary = works[wi]
	var chans: Array = []
	for k in ["pose", "fill", "grow", "shown", "tint", "glow", "boil", "written", "angle", "offset"]:
		chans.append("w%d:%s" % [wi, k])
	if _group_of.has(wi):
		chans.append("g%d:pose" % int(_group_of[wi]))
	var c := int(_parent_work.get(wi, -1))
	while c >= 0:
		chans.append_array(["w%d:pose" % c, "w%d:angle" % c, "w%d:offset" % c])
		if swings.has(c):
			return null
		c = int(_parent_work.get(c, -1))
	if String(wk["kind"]) == "free":
		chans.append("t%d:pose" % int(wk["thing"]))
	var out := PackedVector2Array()
	for ch in chans:
		if _runs_of.has(ch):
			return null
		for e in _chan.get(ch, []):
			out.append(Vector2(float((e as Dictionary)["s0"]) - QUIET_EDGE, float((e as Dictionary)["s1"]) + QUIET_EDGE * 2.0))
	return out


## Work [param wi] as it is at [param t]: its joint, its fill and growth, whether it shows, its color and glow.
func _pose_work(wi: int, t: float) -> void:
	var wk: Dictionary = works[wi]
	var w: Dictionary = wk["w"]
	var node: Node3D = wk["node"]
	var base: Vector3 = w.get("base", Vector3.ZERO)
	var fill := float(value("w%d:fill" % wi, t))
	var grow := float(value("w%d:grow" % wi, t))
	# A liquid the physics keeps is as full as it is, its surface cut level ([TablePhysics]): never scaled
	var kept := physics.liquid_volume(wi, t) if physics != null else -1.0
	if kept >= 0.0:
		fill = 1.0 if kept > 1e-9 else 0.0
	var s := Transform3D.IDENTITY
	if kept < 0.0 and (not is_equal_approx(fill, 1.0) or not is_equal_approx(grow, 1.0)):
		var k := maxf(grow, 0.0005)
		s = Transform3D(Basis.from_scale(Vector3(k, k * maxf(fill, 0.0005), k)), base) * Transform3D(Basis.IDENTITY, -base)
	var j := Transform3D.IDENTITY
	if String(wk["kind"]) == "free":
		# moved by the work where the work moved it - a copy as its set is moved, from where the set stood, and a part
		# left in its thing riding it ([method _work_world]) - or where the physics has it, held or let go: a LOOSE thing,
		# or a part the work picks up, a rigid body ([TablePhysics])
		var baked: Variant = physics.pose_of(wi, t) if physics != null and not _outran(wi, t) and not (_planned and not bool(w.get("loose", false))) else null
		if baked != null:
			j = _parent_world(node).affine_inverse() * (baked as Transform3D)
		elif _part_moves(wi):
			j = _parent_world(node).affine_inverse() * _work_world(wi, t)
	else:
		j = _joint(wi, t)
	node.transform = j * s
	node.visible = float(value("w%d:shown" % wi, t)) > 0.5 and grow > 0.001 and fill > 0.001
	# ...a sheet as it is bent ([SheetBend]) - as a hand or the acts' own pose has it, straight
	if physics != null and bool(w.get("loose", false)) and physics.bends(wi):
		_bend_sheet(wi, physics.bend_of(wi, t) if not _outran(wi, t) and not _planned else null)
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
				# ...and how clouded what is in it is, by what is rinsed in it ([method TablePaint.cloud_at]: the rest of its alpha)
				mat.set_shader_parameter("murk", 1.0 - (tint as Color).a)
			mat.set_shader_parameter("glow", glow)
			mat.set_shader_parameter("boil", boil)
	if _writing.has(wi):
		_written(wi, t)
	# ...and what the physics had it as, for the next frame to ask whether anything of it changed ([method _settled])
	if physics != null:
		_drawn_of[wi] = [physics.pose_of(wi, t) if (physics._rigid_of.has(wi) or physics._loose_of.has(wi)) else null,
			kept > 1e-9, physics.whole(wi, t) if physics._loose_of.has(wi) else true]


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


## Words written on sheet [param wi] ([SheetWriting]) as far as the pen has got at [param t] - drawn the first time any
## of them is.
func _written(wi: int, t: float) -> void:
	var wr: Dictionary = _writing[wi]
	var got := float(value("w%d:written" % wi, t))
	if not wr.has("node"):
		if got <= 0.0:
			return
		var wk: Dictionary = works[wi]
		if wr.has("page"):
			wr["node"] = SheetWriting.page_node((wk["w"] as Dictionary)["sheet"], wr["page"], Color.html(String(wr["ink"])))
		else:
			wr["node"] = SheetWriting.node((wk["w"] as Dictionary)["sheet"], String(wr["text"]), String(wr["hand"]), Color.html(String(wr["ink"])),
				ink_seed + wi)
		(wk["node"] as Node3D).add_child(wr["node"])
	((wr["node"] as MeshInstance3D).material_override as ShaderMaterial).set_shader_parameter("written", got)


# --- what the work sounds like ([WorkSounds]) ----------------------------------------------------------

## What is set down from show time [param t0] up to [param t1]: each carry `down` that ends then, `{t, at (the table's
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


## What is pressed onto something at show time [param t] - a pestle's tip in its mortar, as an `aim` or a `circle`
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


## What boils at show time [param t] ([constant Motions.STATES] `boil`): `[{wi, boil, at (its surface's middle, the
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

## A plume of work [param wi]'s `emits`: a pool of puffs ([constant Motions.MAX_PUFFS] at most), each born
## in turn from its point and rising - in closed form, the k-th puff born at k over its rate - and as
## thick as the part's `emit` says (so how hard it smokes can change and stay a function of time). A
## trail, never tufts: puffs are born at least half a puff's size apart as they rise, and a plume asked
## for fewer is fainter, never broken.
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
	var box_w: AABB = (works[wi] as Dictionary)["w"]["box"]
	return {"wi": wi, "e": e, "look": look, "layer": layer, "rate": rate, "thick": thick, "life": life, "n": n, "slots": slots, "lives": lives,
		"across": maxf(box_w.size.x, box_w.size.z), "kin": _works_of_thing_with(wi),
		"point": _point_local(wi, at) if not at.is_empty() else Vector3(((works[wi] as Dictionary)["w"]["box"] as AABB).get_center().x,
			((works[wi] as Dictionary)["w"]["box"] as AABB).end.y, ((works[wi] as Dictionary)["w"]["box"] as AABB).get_center().z),
		"color": Color.html(String(e["color"])).srgb_to_linear()}


## The works of the thing that work [param wi] is part of.
func _works_of_thing_with(wi: int) -> Array:
	for th in things:
		if ((th as Dictionary)["works"] as Array).has(wi):
			return (th as Dictionary)["works"]
	return [wi]


## How much of its steam a plume gives at [param t], by how hot what it rises from is ([method Motions.temperature]): all of it while that boils, and all of what does not cool.
func _plume_heat(p: Dictionary, t: float) -> float:
	if not bool((p["look"] as Dictionary).get("cools", false)):
		return 1.0
	for wi in p["kin"]:
		if float(value("w%d:boil" % int(wi), t)) > 0.01:
			return 1.0
	return Motions.steam_share(Motions.temperature(p["e"], float(p["across"]), t + since))


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
	var heat := _plume_heat(p, t)
	var strength := float(value("w%d:emit" % wi, t)) * heat
	var from := _world_of((works[wi] as Dictionary)["node"]) * (p["point"] as Vector3)
	if medium._plan.cam_base.origin != Vector3.ZERO:
		strength *= smoothstep(PLUME_LENS.y, PLUME_LENS.x, from.distance_to(medium._plan.cam_base.origin))
	p["strength"] = strength
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
		var vel := Vector3(side.x, float(look["rise"]) * lerpf(0.7, 1.25, _hash01(k, 4)) * lerpf(STEAM_COOL_RISE, 1.0, heat), side.z)
		var particle := {"born": born, "pos": from + Vector3(_hash01(k, 5) - 0.5, 0.0, _hash01(k, 6) - 0.5) * 0.01, "vel": vel}
		mm.set_instance_transform(slot, Effects.particle_xform(particle, wind))
		# as thick as it smokes when it is born: the sprite fades by its color's alpha
		var c: Color = p["color"]
		mm.set_instance_color(slot, Color(c.r, c.g, c.b, clampf(strength, 0.0, 1.0) * float(p["thick"])))
		lives[slot] = Vector2(born, life * lerpf(0.75, 1.2, _hash01(k, 7)) * lerpf(STEAM_COOL_LIFE, 1.0, heat))
		mm.set_instance_custom_data(slot, Color(lives[slot].x, lives[slot].y, _hash01(k, 8),
			float(look["size"]) * 0.001 * lerpf(0.7, 1.3, _hash01(k, 9)) * lerpf(STEAM_COOL_SIZE, 1.0, heat)))
	p["slots"] = slots
	p["lives"] = lives


static func _hash01(k: int, salt: int) -> float:
	var h := hash([k, salt, "puff"])
	return float(h & 0xFFFFFF) / float(0x1000000)


## The cues' moments, when the schedule is made: each burst at its act's moment, at its point as it is then.
func plan_cues() -> void:
	if _air == null:
		return
	var moments := {}
	for c in _cues:
		moments[String(c["name"])] = []
	if paint != null:
		for look in ["dust", "mist"]:
			if not _paint_bursts.has(look):
				continue
			var puffs: Array = []
			for dd in paint.dust(look):
				puffs.append({"t": float(dd["t"]), "dur": 0.12 if look == "dust" else 0.3, "from": "point", "card": -1,
					"path": [[float(dd["t"]), Transform3D(dd["basis"] as Basis, dd["p"] as Vector3)]]})
			moments["paint " + look] = puffs
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

## The table's working parts in words, for the puppeteer ([PuppeteerTools]): each thing, whether it may be
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
		if not _grippable(ti):
			lines.append("    COLLECTION, with no fixed carrier: name the individual part you need in each move. A whole-collection move takes one trip per part, in sequence.")
		for wi in th["works"]:
			var gi := int(_group_of.get(wi, -1))
			var members: Array = (groups[gi] as Dictionary)["members"] if gi >= 0 else []
			if gi >= 0 and int(members[0]) != int(wi):
				continue
			var wk: Dictionary = works[wi]
			var w: Dictionary = wk["w"]
			var bits := PackedStringArray()
			# A part with copies: worked as one by its name, a copy alone by its number - each where it is now
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
				var cold := Motions.steam_stops_at(w["emits"], maxf((w["box"] as AABB).size.x, (w["box"] as AABB).size.z))
				if not is_inf(cold):
					bits.append("left alone it has gone cold and stopped about %d minutes into the video" % roundi(cold / 60.0))
			if w.has("sheet"):
				bits.append("a sheet, blank: words can be written on it (`write`)")
			if bool(w.get("edge", false)):
				bits.append("a BLADE: what soft loose thing it is brought down through, it cuts")
			if bool(w.get("loose", false)) and _cuttable(wi):
				bits.append("soft: a blade cuts it")
			if bool(w.get("loose", false)) and _brittle(wi):
				bits.append("it breaks: a tool's point pressed down onto it (`press`), going round over it, grinds it to pieces and powder")
			# On its side as built: a stopper laid down in its tray would otherwise go into its vial's mouth sideways
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
	if assembly != null:
		lines.append(assembly.report())
	# What can be painted, its design element by element, and what paints ([TablePaint])
	if paint != null:
		lines.append_array(paint.report())
	return "\n".join(lines)


## What act [param name] does, in numbers, after a rehearsal ([method rehearse]): how long, how far each moving
## thing travels and how fast at the most, and anything passing through anything - a moving thing's points
## inside another thing, or through the table's top - with the moment it happens. `{text, through}`.
func check(name: String) -> Dictionary:
	var times := rehearsed()
	_planned = true
	if not times.has(name):
		_planned = false
		return {"text": "no act called \"%s\" could be played (%s)" % [name, "; ".join(notes) if not notes.is_empty() else "none was kept"], "through": 0}
	var span: Array = times[name]
	var t0 := float(span[0])
	var t1 := float(span[1])
	var act: Dictionary = {}
	for a in acts:
		if String((a as Dictionary)["name"]) == name:
			act = a
	# What moves in it, and the meshes that do not - a part's copies moved as one together
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
	# ...and what it paints, and what no act paints yet ([TablePaint])
	if paint != null:
		lines.append_array(paint.said(act, t0, t1))
		var left := paint.unpainted()
		if not left.is_empty() and paint.said(act, t0, t1).size() > 0:
			lines.append("No act lays these elements yet: %s." % ", ".join(Array(left).map(func(x: String) -> String: return "\"%s\"" % x)))
	# ...and each pour it makes, judged by where what it poured went
	var pours: Array = []
	if physics != null:
		for tr in act["tracks"]:
			var td: Dictionary = tr
			if String(td.get("law", "")) != "pour" or not (td.has("_ti") or td.has("_wi")):
				continue
			pours.append({"label": String((things[int(td["_ti"])] as Dictionary)["name"]) if td.has("_ti") else _part_label(int(td["_wi"])),
				"from": physics.solids_of_mover(int(td.get("_ti", -1)), int(td.get("_wi", -1))), "into": String(td.get("into", ""))})
	var physics_said := physics.report(t0, t1, pours) if physics != null else PackedStringArray()
	if movers.is_empty():
		if assembly != null and TableAssembly._has_ops(act):
			lines.append_array(assembly.log.report_of(name))
		else:
			lines.append("Nothing in it moves from its place: it changes what things are (their fill, size, color, glow).")
		lines.append_array(physics_said)
		tick(t1)
		_planned = false
		return {"text": "\n".join(lines), "through": 0}
	var still := TriangleMesh.new()
	var faces := PackedVector3Array()
	var by_thing: Array = []     # each thing's faces, as they stand: a painting tool's own `still` leaves out what it goes into
	tick(t0)
	for th in things:
		var tf := PackedVector3Array()
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
				tf.append(xf * q)
		by_thing.append(tf)
		faces.append_array(tf)
	if not faces.is_empty():
		still = _ray_mesh(faces)
	var through := 0
	for mv in movers:
		var node: Node3D = (mv["nodes"] as Array)[0]
		var pts := PackedVector3Array()
		var owners: Array = []
		var meshes: Array = []
		# ...never what lies loose in it or stands free in it: a part of its own body (a dish's stone, a jar's cork, a mortar's
		# pestle) goes where the physics takes it, never where the hand does, so it is not counted with the dish
		var apart: Array = []
		for n in mv["nodes"]:
			for wj in works.size():
				var wn: Node = (works[wj] as Dictionary)["node"]
				if wn != n and (n as Node).is_ancestor_of(wn) and (String((works[wj] as Dictionary)["kind"]) == "free" \
						or bool(((works[wj] as Dictionary)["w"] as Dictionary).get("loose", false))):
					apart.append(wn)
		for n in mv["nodes"]:
			if n is MeshInstance3D:
				meshes.append(n)
			for c in (n as Node).find_children("*", "MeshInstance3D", true, false):
				var free_of := false
				for a in apart:
					free_of = free_of or a == c or (a as Node).is_ancestor_of(c)
				if not free_of:
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
		# A part that starts seated in something - a vial in its rack, a ladle in its pot, a stopper in its
		# bottle, as the set dresser built it or an earlier act left it - may come out of it: a point inside
		# something as the act begins is not counted until it has once come out, and after that going in
		# anywhere is.
		var seated := PackedByteArray()
		seated.resize(pts.size())
		var seated_n := 0
		# A tool pressed onto a thing meets it, never passes through it: a pestle's head ground round a mortar's
		# floor touches its sloping wall as it goes
		var pressed := _pressed_by(act, mv)
		# ...and what a painting tool goes into, it is never looked for inside at all ([method TablePaint.touches]): measured by the
		# solids' fields, a palette's cream and the cradle under a face's rim still read points "passing through" where the
		# triangles had it inside and the field did not
		var still_of := still
		var has_faces := not faces.is_empty()
		if not (pressed.get("free", []) as Array).is_empty():
			var kept := PackedVector3Array()
			for ti in by_thing.size():
				if not (pressed["free"] as Array).has(ti):
					kept.append_array(by_thing[ti])
			has_faces = not kept.is_empty()
			still_of = _ray_mesh(kept) if has_faces else TriangleMesh.new()
		for s in CHECK_STEPS + 1:
			var t := lerpf(t0, t1, float(s) / float(CHECK_STEPS))
			tick(t)
			var mid := _world_of(node).origin
			if last != Vector3.INF:
				var step := mid.distance_to(last)
				travel += step
				fastest = maxf(fastest, step / ((t1 - t0) / float(CHECK_STEPS)))
			last = mid
			# Back where it was built it is as the set dresser built it: a vial put back in its rack is home
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
				var in_thing := not in_top and has_faces and not slot.has_point(p) and _inside(still_of, p) \
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
	lines.append_array(_sprinkles_said(act, t0, t1))
	lines.append_array(_aloft_said(act))
	lines.append_array(physics_said)
	_planned = false
	tick(t1)
	return {"text": "\n".join(lines), "through": through}


## What [param act] leaves in the air: each thing or part its last move on it leaves with its lowest
## point more than [constant ALOFT_GAP] over what is under it, standing in no vessel and set `down`
## nowhere - said, with what then happens: a hand holds a thing in the air only while its next move
## follows at once ([constant TablePhysics.HOLD_MOST]), and a live reading places a move only when its
## words come, so it is set down where it is first. A rehearsal plays the acts back to back and never
## shows it.
func _aloft_said(act: Dictionary) -> PackedStringArray:
	var out := PackedStringArray()
	var last := {}
	for tr in act["tracks"]:
		var ch := String((tr as Dictionary).get("_ch", ""))
		if ch.ends_with(":pose"):
			last[ch] = tr
	for ch in last:
		var tr: Dictionary = last[ch]
		if bool(tr.get("down", false)):
			continue
		var e: Dictionary = {}
		for x in _chan.get(ch, []):
			if String((x as Dictionary).get("act", "")) == String(act["name"]) and (x as Dictionary)["track"] == tr:
				e = x
		if e.is_empty() or not (e.get("end") is Transform3D):
			continue
		var end: Transform3D = e["end"]
		var T := float(e["s1"])
		var ti := int(tr.get("_ti", -1))
		var wi := int(tr.get("_wi", -1))
		var box: AABB = (things[ti] as Dictionary)["box"] if ti >= 0 else (((works[wi] as Dictionary)["w"] as Dictionary).get("box", AABB()) as AABB) if wi >= 0 else AABB()
		if box.size == Vector3.ZERO:
			continue
		var pl := _probes_of(end, box)
		var top := maxf(_top_under(pl[0], ti, T, wi), 0.0)
		var gap := float(pl[1]) - top
		if gap <= ALOFT_GAP:
			continue
		# ...standing in a vessel, it leans there: a ladle left in its pot
		var low_p := end * Vector3(box.get_center().x, box.position.y, box.get_center().z)
		if _same_inside(low_p, low_p, T, wi):
			continue
		out.append("- %s ENDS IN THE AIR, %.0f cm over what is under it: a hand holds it there only if its next move follows at once (within %.0f s) - a live reading places a move only when its words come, so otherwise it is set down where it is first, and its next move takes it up from there. End the move set `down` where it rests (or in the vessel it works in), unless the next act takes it straight on." % [
			_track_label(tr), gap * 100.0, TablePhysics.HOLD_MOST])
	return out


## What track [param tr] moves, as the puppeteer knows it.
func _track_label(tr: Dictionary) -> String:
	if int(tr.get("_wi", -1)) >= 0:
		return "%s's %s" % [String((things[int((works[int(tr["_wi"])] as Dictionary)["thing"])] as Dictionary)["name"]), _part_label(int(tr["_wi"]))]
	if int(tr.get("_ti", -1)) >= 0:
		return String((things[int(tr["_ti"])] as Dictionary)["name"])
	return String(tr.get("thing", "it"))


## Each sprinkle of [param act] (run [param t0] to [param t1]) naming a thing the act moves, falling
## further than [constant PINCH_NEAR] from it at the middle of its stretch: where it falls from, and how
## far off.
func _sprinkles_said(act: Dictionary, t0: float, t1: float) -> PackedStringArray:
	var out := PackedStringArray()
	for tr in act["tracks"]:
		var d: Dictionary = tr
		if String(d["law"]) != "sprinkle" or String(d.get("thing", "")).is_empty():
			continue
		var ti := _thing_named(String(d["thing"]))
		if ti < 0:
			continue
		var w := _window(d)
		var t := lerpf(t0, t1, (w.x + w.y) * 0.5)
		# ...how far it falls from what the act moves of that thing, as it is then: the thing whole, or each moved part of it -
		# each of its solids' own boxes, in its own space (the thing's box takes in what lay across it as built: a pestle over a
		# mortar's mouth; and a field reads no further than its band)
		var at := place_of(d.get("at", ""), place_of(String(d["thing"]) + ".top", Vector3.ZERO, t), t)
		var off := INF
		var moved_any := false
		for other in act["tracks"]:
			var ch := String((other as Dictionary).get("_ch", ""))
			if not ch.ends_with(":pose"):
				continue
			var wi := int((other as Dictionary).get("_wi", -1))
			var moved: Transform3D
			if ch == "t%d:pose" % ti:
				moved = _thing_world(ti, t) * _world_rest_thing(ti).affine_inverse()
			elif wi >= 0 and int((works[wi] as Dictionary)["thing"]) == ti:
				moved = _work_world(wi, t) * (_rest["w%d:pose" % wi] as Transform3D).affine_inverse()
			else:
				continue
			moved_any = true
			if physics == null:
				continue
			for sd in _solids_ref:
				var sdd: Dictionary = sd
				if int(sdd["thing"]) != ti or (wi >= 0 and int(sdd["wi"]) != wi) or (wi < 0 and sdd.has("body")):
					continue
				var q: Vector3 = (moved * (sdd["rest"] as Transform3D)).affine_inverse() * at
				var b: AABB = sdd["box"]
				off = minf(off, Vector3(maxf(maxf(b.position.x - q.x, q.x - b.end.x), 0.0), maxf(maxf(b.position.y - q.y, q.y - b.end.y), 0.0),
					maxf(maxf(b.position.z - q.z, q.z - b.end.z), 0.0)).length())
		if not moved_any or off == INF:
			continue
		if off > PINCH_NEAR:
			out.append("- THE SPRINKLE OF %s falls from [%.1f, %.1f, %.1f] cm, %.0f cm from \"%s\" as this act holds it then: what falls out of a thing falls from it. Bring \"%s\" over where it should go and tip it there - what is in it pours by itself - or let the pinch fall from a point of it." % [
				String(d.get("material", "grains")), (at.x - Tables.ORIGIN.x) * 100.0, at.y * 100.0, (at.z - Tables.ORIGIN.y) * 100.0, off * 100.0,
				String(d["thing"]), String(d["thing"])])
	return out


## The things a mover [param mv] of [param act] is pressed onto (a law's `press`, its tip's or its grip's): `{tis: their
## numbers, own: the mover's own works, free: those it meets at any depth}` - none pressed, empty.
func _pressed_by(act: Dictionary, mv: Dictionary) -> Dictionary:
	var tis: Array = []
	var own: Array = []
	var free: Array = []
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
		# ...a painting tool, what it paints and the pots, water and towel it goes to ([method TablePaint.touches]) - at any depth:
		# where it goes is the paint law's, which the puppeteer cannot move clear; the law's own gate holds it to the surface
		# (tests/table/paint_check.gd)
		if String(tr.get("law", "")) == "paint" and paint != null:
			for ti in paint.touches(tr):
				if not tis.has(ti):
					tis.append(ti)
				if not free.has(ti):
					free.append(ti)
	return {} if tis.is_empty() else {"tis": tis, "own": own, "free": free}


## Whether [param p] (the table's space) is no deeper than [constant PRESS_INTO] inside any of the things a tool is
## pressed onto ([param pressed], [method _pressed_by]) at show time [param t] - where it meets them - or inside one it meets
## at any depth (its `free`), the tool's own solids aside.
func _pressed_into(pressed: Dictionary, p: Vector3, t: float) -> bool:
	if physics == null:
		return false
	for sd in _solids_ref:
		var d: Dictionary = sd
		if not (pressed["tis"] as Array).has(int(d["thing"])) or (pressed["own"] as Array).has(int(d["wi"])) or not d.has("field"):
			continue
		var pose: Transform3D = (_thing_world(int(d["oi"]), t) if String(d["owner"]) == "t" else _work_world(int(d["oi"]), t)) * (d["local"] as Transform3D)
		if not (pose * (d["box"] as AABB)).grow(PRESS_INTO).has_point(p):
			continue
		var f := (d["field"] as ShapeField).sample(pose.affine_inverse() * p).x
		if f < 0.0 and (f > -PRESS_INTO or (pressed.get("free", []) as Array).has(int(d["thing"]))):
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
