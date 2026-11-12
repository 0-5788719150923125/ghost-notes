extends RefCounted
class_name TablePhysics

## TablePhysics - WHAT IS IN THINGS, and what happens to it: a part of [TableWork] (next/table_physics.md). The user,
## 2026-10-28, of the first alchemy episode: "The liquids are not liquids"; the vial's snow should be "particles ...
## With physics and collision"; the tipped dish's crystals "do not move and tumble, and they do not fall into the
## cauldron"; and the mortar should grind what goes into it to nothing. So on every table:
##
##   - every LIQUID in a hollow part keeps its volume in that part's inside ([Vessel]) and its surface level in the
##     table's space; it sloshes as its vessel is carried, turns as it is stirred, pours over the rim where it stands
##     above it - a weir's flow, its stream PARCELS falling under gravity into whatever catches them - and rings
##     where anything enters it ([member ripples]);
##   - every GRAINS part is laid into the inside it is drawn in, and every LOOSE part is a body of spheres
##     ([Particles]) - asleep on what holds it until something tips, jolts, strikes or presses it;
##   - every other part of every thing is a SOLID ([ShapeField]) that moves as its thing or part moves.
##
## BAKED, AND PLAYED AS A FUNCTION OF TIME: the world is stepped once over show time at [constant FPS] and kept frame by
## frame ([member frames]); a picture looks its moment up. The schedule a live reading makes changes only where nothing
## has begun, so a new plan ([method replan]) is baked again from the last checkpoint before the first act it moved.
## In the app and a render the bake runs on a thread of its own, with a TWIN of the work's kinematics - the same data,
## its own recursion, nothing that touches a node - handed each new plan, never sharing one while it changes; a render
## and a preview wait for it (a picture is never ahead of the bake), a live picture never does.
##
## TWO THREADS SHARE NOTHING THAT EITHER WRITES (2026-11-01, a live show's crash: signal 11 in [method _draw_liquids], reading
## the twin's channels as the bake took a new plan and freed the old - and, played live by a probe, `double free or corruption`
## a minute in). A Godot Dictionary or Array written on one thread while another reads it can be moved under the read, a key
## added for the first time is such a write, a member given on two threads at once lets its old value go twice, and a PACKED ARRAY
## HELD IN A DICTIONARY IS THE SAME ARRAY, never a copy. So the app's thread reads only the FRAMES, under the lock (made whole and
## never written again, every array in one its own - its woken bodies too, `wk`), what was made before the bake's thread began and
## is never written after (every key the bake finds later is there from the build, empty; a field's surface points made then), and
## its own: the work's channels and copies of the solids ([member TableWork._solids_ref]), the picture's lumps and textures
## ([member _drawn_mm], [member _wave_tex]), the sprinkles as it knows them ([member _sprinkles_drawn], [member _sprinkles_seen]),
## its timings ([member drawn_profile]). The twin is handed copies of the plan's entries ([method _entries_of]), on which posing
## keeps what it finds. Probe it played as the app plays it: tests/table/episode_bake_probe.gd `--live`.
##
## A BAKE GOES ON TO THE NEXT TABLE (2026-10-28, the-quiet-crucible 707668: the puppeteer's Work ran 90 minutes and
## took 3 of its 30 looks - each `act` stood a table of its own and baked it from its first frame, ~16 ms a frame, the
## draft 105 s long, on the app's own thread; it would not close for two minutes): a table stood again over the same
## table with other acts takes what the last one baked ([method carry], [method adopt]) as far as the two plans agree,
## channel by channel, and bakes on from there. A preview bakes on a worker ([method bake_until], [method halt]).
##
## THE WORLD IS THE TABLE'S, NEVER THE ACTS' (2026-11-01, next/framework_audit.md: 841899's puppeteer spent 78 of its 105 minutes
## in our tools, a whole-show bake for every act that moved something nothing had moved): every free part and every movable thing
## is a body, dormant until taken up ([RigidParts]); nothing a frame does looks at a later act further than a hand's pause
## ([method _held_aloft]); so a new draft - a puppeteer's next `act`, bound to the table it stood for the last ([method rebind]) -
## is baked again only from the first moment it changes ([method replan]), by an act's name, its time and what it does.

## The bake's frames a second, how far ahead of the picture a live bake runs (seconds), and how often it keeps a
## checkpoint (frames) - with how many it keeps beside the first: the latest [constant CHECKS_NEAR] one after another
## (a live bake's horizon), the older spread out, so a plan changed far back goes back a few seconds, never to the start.
const FPS := 60
const HORIZON := 20.0
const CHECK_EVERY := 60
const CHECKS_KEPT := 40
const CHECKS_NEAR := 24
## How long after an act its report looks (seconds): what it set falling has landed ([method report]).
const REPORT_AFTER := 1.0
## A part let go further than this from where its act left it (meters) is said so ([method report]).
const LET_GO_OFF := 0.01
## ...and one held back further than this from where its hand has it (meters, [method report]).
const HELD_BACK := 0.01
## A bake carried to another table is taken up to this long before the first moment the plans differ (seconds): a
## solid may move a frame or two either side of its stretch ([method _may_move], [method _moves_at]).
const CARRY_MARGIN := 0.25
## How long before its first act a past is baked from (seconds, [member _t0]).
const PAST_LEAD := 1.0
## How far past the last frame baked a live show may run before the log says what is in things is behind (seconds).
const OUTRUN := 0.5
## A LIVE SHOW WAITS FOR THE BAKE ([method behind]): from when the bake is less than WAIT_UNDER ahead of it until it is
## WAIT_AHEAD ahead again (seconds) - a stall that bakes a stretch, never one a frame.
const WAIT_UNDER := 0.05
## A PART'S SEAT ([method _seat]): what of its thing it touches as built, this near (meters); held this near it and this little
## turned from how it sat, it never meets it; let go this near and this little turned, it sits as built.
const SEAT_TOUCH := 0.003
const SEAT_REACH := 0.03
const SEAT_TURN := 0.6
const SEAT_NEAR := 0.015
const SEAT_TILT := 0.35
## ...and one that comes to rest this near its seat by itself (meters, radians) is in it, and welded there.
const SEAT_SNUG := 0.002
const SEAT_SNUG_TILT := 0.05
## ...and a move carries it WITH its seat that begins and ends with it seated and never takes it further from it on the way than
## this (meters, radians): two hands' bows and sways apart, never a cork drawn out and put back.
const SEAT_RIDE := Vector2(0.03, 0.5)
const WAIT_AHEAD := 3.0
## Two holds of a thing less than this apart (seconds) are one: a hand never lets go between one move and the next.
const HOLD_GAP := 0.25
## How far down from a place a report looks for what it lies on (meters): a thing's middle stands a few centimeters over it - and how
## far over a vessel what lies on it or in it may stand (meters, [method _mover_box]).
const LOOK_DOWN := 0.04
const ON_IT := 0.04
## THE LONGEST A HAND HOLDS A THING IN THE AIR between its moves (seconds), when let go there it would fall: a pause - a mortar held
## over the pot while the other hand puts the pestle back, never the 15 s of words before a stir - past it, it is set down where it
## is ([method _held_aloft]). (At 1 s, 841899's mortar, held over the cauldron after its pour for the 2.5 s the pestle took, was set
## down on the cauldron's rim and tumbled into the brazier's pan.)
const HOLD_MOST := 3.0
## A HAND NEVER LETS GO WHERE WHAT IT HOLDS WOULD COME DOWN BADLY ([method _lands_ill]; 2026-11-01, feedback 0004-0007: the mortar, level over
## the cauldron after its pour, its next act 4.6 s on, let go and set down on the rim - it tipped over the rim onto the table and trembled
## there. 3 s had been this constant's answer to the same fall at 1 s: the rule was wrong, not the number). Past a pause, let go, it must
## not tumble: turned past [constant LAND_TILT] and come down past [constant LAND_DROP], tried for [constant LAND_TRIAL] seconds, and not
## standing in a vessel at the end (a ladle turns as far coming to lean on a pot's rim, and comes down a centimeter). Otherwise the hand
## goes on holding it - for its next move if that comes within [constant HOLD_ILL] seconds, and while one is still to come - or puts it
## back where it last rested, over [constant BACK_TIME] seconds.
const LAND_TILT := 0.44
const LAND_DROP := 0.03
const LAND_TRIAL := 3.0
const HOLD_ILL := 8.0
const BACK_TIME := 1.6
## How far a hand putting a thing back lifts it on the way (meters).
const BACK_LIFT := 0.03
## A hand done with a thing whose lowest point is this far under a vessel's rim (meters) lets it lean in that vessel
## ([method _stands_in]).
const STANDS_IN := 0.025
## LET GO, WOULD IT FALL ([method _would_fall])? Tried for [constant LAND_TRIAL] seconds; it falls when its lowest point goes further down than
## FALL_LEAST (meters) - a ladle put back on its rest settles a millimeter; a jar a carry left 4 cm over the table, or a feather
## held up to be shown, falls.
const FALL_LEAST := 0.02
## The least a thin thing's spheres rest at over the table and the solids (meters, [member Particles.rc]).
const CONTACT_LEAST := 0.0004
## A frame's word for a loose thing yet to be a body ([method _wake_loose]), where 1 is one whole and 0 one broken - and for
## one LYING AGAIN where it came to rest ([method _rest_loose]).
const LYING := 2
const RESTED := 3
## A LOOSE THING ASLEEP this long (seconds), whole and held by nothing, lies again where it came to rest, its spheres freed.
const RELEASE_AFTER := 2.0
## WHAT A BLADE CUTS: loose things of these kinds of material ([constant Props.MATERIALS]) - a root, a candle, a sheet of
## paper, cloth, leather ([method Particles._cut_through]).
const CUTS := ["plant", "wax", "paper", "leather", "fabric"]
## WHAT A SHEET OF GIVES AS IT IS MET ([method Particles.make_soft]): a feather, a leaf, a page, a rag - never a scale of bone or a leaf of beaten metal.
const BENDS := ["plant", "paper", "fabric"]
## ...and a soft thing shorter than this (meters) is too small to slice: a seed, a petal.
const SLICE_LEAST := 0.03
## The most grains one grains part is laid as, and how full a cubic packing of spheres is.
const GRAINS_MOST := 240
const PACKED := 0.52
## THE LIQUIDS: the most vessels a table's are reckoned in; the first sloshing mode's root (an upright cylinder's,
## w0^2 = g xi / R tanh(xi h / R)), how much of a slosh a period loses, how long a swirl lasts (seconds), how hard a tool
## turns it; how long a stream's parcel may fall (seconds).
const LIQUID_MOST := 40
const XI := 1.8412
const SLOSH_DAMP := 0.05
const SWIRL_LIFE := 3.0
const SWIRL_PULL := 3.0
const PARCEL_LIFE := 2.5
## ...looked along its way a frame at a time in steps of this (meters): half a thin wall ([method _solid_on_way]).
const PARCEL_STEP := 0.0015
## A STREAM drawn: its thinnest and thickest (meters).
const STREAM_R := Vector2(0.0004, 0.004)
## RIPPLES and SPLASHES: how high a ring rises for what struck it (meters a kilogram-meter-a-second, and its least and
## most); a splash's drops - one for every SPLASH_MASS (kilograms) of the thing that entered, if it entered faster than
## SPLASH_SPEED (meters a second), thrown up at SPLASH_UP of that speed, no more than DROPS_EACH: a stone dropped from a
## hand's height throws a few a centimeter or two, and a resin tear, a slip or a pinch of anything none; how long a
## splash's drops fly at most (seconds), and how many drops are drawn at once.
const RING_GAIN := 6.0
const RING := Vector2(0.0002, 0.0025)
const SPLASH_MASS := 0.002
const SPLASH_SPEED := 0.5
const SPLASH_UP := 0.35
const DROPS_EACH := 8
const DROP_LIFE := 0.7
const DROPS := 64
## How many of the table's first frames draw the copies that have the GPU build what a stream and the drops need ([method
## _drawn_nodes]) before they are freed: a frame or two can pass before a table's first is drawn.
const WARM_TICKS := 4
## A SOLID'S SURFACE, by its kind of material ([constant Props.MATERIALS]): its friction, static and kinetic, against
## what rests on it - met with that thing's own as their geometric mean. Polished metal and glass are slick: a resin tear
## dropped on a bronze pestle lying across its mortar slides off it into the bowl (the-quiet-crucible 841899: it "lands
## ON TOP of the pestle, and just sits there"), where stone and cloth hold it.
const SURFACES := {"metal": Vector2(0.35, 0.25), "glass": Vector2(0.35, 0.25), "crystal": Vector2(0.35, 0.25),
	"ceramic": Vector2(0.45, 0.35), "bone": Vector2(0.4, 0.3), "wax": Vector2(0.4, 0.3), "stone": Vector2(0.6, 0.45),
	"wood": Vector2(0.5, 0.4), "paper": Vector2(0.6, 0.5), "leather": Vector2(0.6, 0.5), "fabric": Vector2(0.7, 0.55),
	"plant": Vector2(0.6, 0.5), "powder": Vector2(0.7, 0.55)}
const SURFACE_ELSE := Vector2(0.5, 0.4)
## How deep what falls into a liquid dents its surface for the ring it makes ([member ripples]' `size`) - the dent's
## depth, a share of it.
const DENT := 0.8
## A bubble this big (meters, its radius) breaking rings a liquid's surface ([Boil]): a simmer's are smaller, and only drawn.
const BUBBLE_RINGS := 0.002
## HOW A LIQUID STIRS ([method _agitation]): the least of any, and how much a radian a second of its swirl adds.
const AGITATION_LEAST := 0.2
const AGITATION_SWIRL := 0.25
## A TOOL'S VORTEX ([method _liquids_step]): as a share of the surface's radius, the least its core is.
const SWIRL_CORE := 0.25
## The most bubbles a liquid's surface is drawn with at once ([method _draw_liquids]): the biggest.
const BUBBLES_DRAWN := 16
## A grain drawn: how much larger than its sphere its lump is, so a heap reads whole.
const LUMP := 1.25
const GRAVITY := 9.81
## A HINGE THAT HANGS SWINGS ([method _find_swings]): its weight hangs below its pivot at least this far (meters), no
## further to the side than below; its pivot's own drag (a share of its swing lost a second), how much of its speed it
## keeps off a stop, its substeps a frame; still below this (radians a second, and radians a second squared of what
## pulls it) for this long (seconds), it rests - and how fine a part's mass is sampled at most (cells along a side).
const SWING_HANG := 0.0005
const SWING_DAMP := 0.8
const SWING_BOUNCE := 0.25
const SWING_STEPS := 4
const SWING_STILL := Vector2(0.004, 0.02)
const SWING_REST := 0.5
const MASS_CELLS := 24
## WHAT STANDS IN A LIQUID RAISES IT ([method _level_of]): a body's matter met by at most this many points, and a moving
## vessel's inside by every this many of its own.
const MATTER_POINTS := 300
const INSIDE_STEP := 4

const _LIQUID := preload("res://shaders/prop_liquid.gdshader")
## A LIQUID THIS CLEAR IS SEEN THROUGH (prop_liquid_clear.gdshader), and clouds as what is rinsed in it builds up
## ([method TablePaint.cloud_at]): water had been drawn as opaque as a brew - "the water starts opaque white" (2026-11-07). A brew,
## ink or wine below it keeps the opaque body.
const CLEAR_LIQUID := 0.5
const _LIQUID_CLEAR := preload("res://shaders/prop_liquid_clear.gdshader")

## The work this is a part of - HELD WEAKLY: the work holds this, and two RefCounted that hold each other are never freed
## (every table a preview stood had been kept, its meshes, frames and checkpoints with it - found 2026-10-28 with the app
## at 11.7 GB during a puppeteer's run) - and the twin of its kinematics the bake reads.
var work: TableWork:
	get:
		return null if _work_ref == null else _work_ref.get_ref() as TableWork
	set(w):
		_work_ref = null if w == null else weakref(w)
var twin: TableWork
## A PROBE THAT PLAYS AS THE APP PLAYS (tests/table/episode_bake_probe.gd `--live`): the bake on a thread of its own, as a live
## show's is, though a test's process waits on the caller's ([method render_waits]).
static var threaded := false
var _work_ref: WeakRef = null
var sim := Particles.new()
## THE PARTS THE WORK PICKS UP, as rigid bodies ([method _make_rigid]), and each one's work -> its body.
var rigid := RigidParts.new()
var _rigid_of := {}

var solids: Array = []        # [{field, owner ("t"/"w"), oi, local (the owner's node -> the part's space), box, thing, wi, shown (a work whose `shown` says it is there)}]
var liquids: Array = []       # [{solid, vessel, wi, node, mat, name, thing, color, built_v, full_v, plugs, made}]
var grains: Array = []        # [{name, thing, wi, ids, mm, solid}]
var loose: Array = []         # [{wi, thing, body, n0, name, mm}]
var _matter := {}             # a table material's name -> its matter row in [member sim]
var _vessel_of := {}          # solid -> its liquid
var _loose_of := {}           # work -> its loose entry
var _bo_n := 0                # how many points the sheets that bend have, all told: what a frame keeps of each ([method bend_of])
var _lying_at := {}           # a cell of Particles.AWAKE_CELL -> the loose entries that lie near it, as built
var _hold_spans := {}         # loose work -> the stretches the work holds it, this plan ([method _held_at])
var _with_seat_of := {}       # a part's move and its seat -> whether the move carries it with its seat ([method _with_seat])
var _wet_ids: Variant = null  # this frame's spheres in each liquid ([method _wet_now]); null as built

var frames: Array = []        # {x, r, alive, bp, bi, liq, hit} a frame
var parcels: Array = []       # [{t0, p, v, vol, from, t1, into}]
var ripples: Array = []       # [{t, liquid, at, size}]
var pieces: Array = []        # [{li, body, D, planes, key}]: each piece a blade cut, as it was cut ([method _cut])
var _piece_at := {}           # body -> its latest piece
var _piece_nodes := {}        # a piece's key -> its node, made the first time it is drawn
var splashes: Array = []      # [{t, at, color, size, k}]
var breaks: Array = []        # [{t, at, size}]: each piece broken off, as it breaks ([WorkSounds] hears it)
var _liq: Array = []          # the liquids' own state as it is baked
var _held := {}               # a held move (a loose thing's, a rigid part's) -> it re-based on where the physics had it as it began
var _swing: Array = []        # [{wi, pivot, axis, c, m, i0, hung: [{wi, at, m}], own: {solid: true}, under: {solid: hung k}, a, w, ...}]
var _swing_at := {}           # a swinging hinge's work -> its place in [member _swing]
var _ck: Array = []           # checkpoints
var _k := 0                   # frames baked
var _runs_seen: Array = []    # the plan last baked
var _chan_seen := {}          # ...its channels ([method replan])
var _owner_pose := {}         # "t3"/"w7" -> [last t, its pose]
var _intervals := {}          # "t3"/"w7" -> [[s0, s1], ...] when it may move
var _spans: Variant = null    # every stretch anything on the table may move in, in order (Vector2s), once a plan
var _sprinkles: Array = []    # [{act, track, grains, owner, key, done}] - the bake's: every key made with it, only written after
var _sync := true
var _thread: Thread = null
var _lock := Mutex.new()
var _sem: Semaphore = null
var _quit := false
var _want := 0.0
var _pending: Variant = null
var _root: Node3D
var _drawn: Variant = null    # the frame last drawn
var _streams: Array = []      # [ImmediateMesh nodes]
var _drops: MultiMeshInstance3D = null
var _clear_at := 0.0          # where the bake was restarted from
## WHERE THE BAKE BEGINS in show time (seconds, never after 0): its first frame's moment. A reading started mid-way (a scrub)
## places what was done before its first words at times before 0 ([method TableWork.schedule]), and the bake begins there, so
## what is in things on the first frame shown is what those acts left - never as it was built (the-quiet-crucible 841899,
## 2026-10-31, scrubbed to the feather: "it totally breaks physics, every time ... there is a piece of some ingredient sitting
## on top of the recipe card" - the tear carried to the mortar at -70 s was never baked, and lay where its carry left it).
var _t0 := 0.0
var _layout := 0              # what this table's physics is made of, as a number ([method _layout_of])
var _carried: Variant = null  # a bake from a table stood before, until the first plan is taken ([method adopt])
var _halt := false              # a bake given up ([method halt])
var _outrun := false            # a live show past the last frame baked, as last said
var _behind := false            # a live show waiting for the bake ([method behind])
var notes := PackedStringArray()
## A probe's: whether each stepped frame's cost is kept by section ([method _spent]), and what it came to.
var profiling := false
var profile := {}
## ...and the picture's own, drawn on the app's thread ([method tick]): kept apart, since the bake's thread writes [member profile]
## as it steps while the picture draws.
var profiling_drawn := false
var drawn_profile := {}
var _liquid_of_work := {}     # work -> the liquid it is ([method liquid_volume])
var _woke := PackedInt32Array()     # the bodies woken so far, in the order they woke: what a frame keeps ([method _record])
var _rank_of := PackedInt32Array()  # body -> its place in [member _woke], or -1 - the bake's own: anyone else reads a frame's `wk`
var _drawn_parts: Array = []  # the frame's particles as last drawn: [alive, owner, broken, cut, body, places, radii]
## WHAT THE PICTURE DRAWS WITH, ITS OWN ([method _drawn_tables]): a lump owner (a grain set, or 1000 + a loose thing) -> its
## MultiMesh, and each loose thing's work. The bake's thread writes into the grains' and loose things' own Dictionaries as it goes
## (a loose thing woken takes keys it never had), and a Dictionary given a key while another thread reads it may be moved under
## the read - so the app's thread reads none of them, and none of the twin's ([member twin]): only the frames, under the lock.
var _drawn_mm := {}
var _loose_wi := PackedInt32Array()
## THE SPRINKLES AS THE APP'S THREAD KNOWS THEM ([method _drawn_tables]): each one's key, act and track, copied as the acts are
## taken up - what [method replan] reads, never the bake's own.
var _sprinkles_drawn: Array = []
## When each sprinkle fell in the plan last handed over (its key -> its stretch, [method replan]): the app's thread's own - the
## sprinkle's Dictionary is the bake's, which writes how much of it has fallen as it goes
var _sprinkles_seen := {}
var _wave_tex := {}           # liquid -> [its ripples' texture, the frame's bytes it was last written from] ([method _wave_texture])
var _warm: Array = []         # a stream and the drops drawn at nothing's size as the table stands, then freed ([method _drawn_nodes])
var _warm_ticks := 0
var _turn_of: Array = []      # each particle's own turn, drawn ([method _draw_particles])
## Where the last plan taken up began to be baked again (seconds of show): what a new plan cost.
var resumed_at := 0.0
## HOW FAR AHEAD OF THE PICTURE A LIVE BAKE RUNS (seconds): [constant HORIZON] while the show plays - and, while it is paused, as
## far as its medium asks ([member TableMedium.BUFFER]): baked while nobody watches, it plays without the bake beside it.
var reach := HORIZON


# --- what is on the table -------------------------------------------------------------------------------

## THING [param ti] ([param t] as made safe, [param b] as [method Props.build] built it, standing as [param node]), its
## works numbered from [param first]: its solids, liquids, grains and loose parts, kept.
func take(ti: int, t: Dictionary, b: Dictionary, node: Node3D, first: int) -> void:
	var wnode := {}
	for k in (b.get("works", []) as Array).size():
		wnode[((b["works"] as Array)[k] as Dictionary)["node"]] = first + k
	var mats: Dictionary = work.materials
	for s in b.get("solids", []):
		var sd: Dictionary = s
		var part: Dictionary = sd["part"]
		var own := _owner_of(sd["holder"], node, wnode)
		var local: Transform3D = (own["local"] as Transform3D) * (sd["xform"] as Transform3D)
		var entry := {"part": part, "owner": own["owner"], "oi": own["oi"], "local": local, "box": sd["box"], "thing": ti,
			"wi": own.get("wi", -1), "meshes": sd.get("meshes", []), "holder": sd["holder"], "xform": sd["xform"], "loose": own.get("loose", -1)}
		if _is_liquid(part, mats):
			entry["liquid_part"] = true
		# A BLADE ([method Particles._cut_through]): what it comes down through, it cuts
		if bool(part.get("edge", false)):
			entry["edge"] = true
		solids.append(entry)
	for g in b.get("grains", []):
		var gd: Dictionary = g
		var own := _owner_of(gd["holder"], node, wnode)
		var gwi := int(own.get("wi", -1))
		grains.append({"part": gd["part"], "owner": own["owner"], "oi": own["oi"], "local": (own["local"] as Transform3D) * (gd["xform"] as Transform3D),
			"thing": ti, "wi": gwi, "name": String(((gd["part"] as Dictionary).get("work", {}) as Dictionary).get("name", "grains")),
			"holder": gd["holder"]})


## Whether [param part] is of the liquid material.
static func _is_liquid(part: Dictionary, mats: Dictionary) -> bool:
	var m: Variant = mats.get(String(part.get("material", "")))
	return m is Dictionary and String((m as Dictionary).get("kind", "")) == "liquid"


## Where a part hanging in [param holder] is carried from: its nearest working node (a work of the thing) or the thing's
## own [param node] - and its place in that node's space.
func _owner_of(holder: Node3D, node: Node3D, wnode: Dictionary) -> Dictionary:
	var xf := Transform3D.IDENTITY
	var n: Node = holder
	var loose_wi := -1
	var owner := {}
	while n != null and n != node:
		if wnode.has(n) and owner.is_empty():
			var wi := int(wnode[n])
			owner = {"owner": "w", "oi": wi, "wi": wi, "local": xf}
		if wnode.has(n) and bool(((work.works[int(wnode[n])] as Dictionary)["w"] as Dictionary).get("loose", false)):
			loose_wi = int(wnode[n])
		if owner.is_empty():
			xf = (n as Node3D).transform * xf
		n = n.get_parent()
	if owner.is_empty():
		owner = {"owner": "t", "oi": -1, "local": xf}
	owner["loose"] = loose_wi
	return owner


## EVERYTHING READY, once every thing stands and the acts are found ([method TableWork.build]): the twin, the solids'
## fields, the vessels and their liquids, the grains laid, the loose bodies made - and, in the app, the bake's thread.
func build() -> void:
	_root = work._root
	for i in solids.size():
		(solids[i] as Dictionary)["oi"] = int((solids[i] as Dictionary)["thing"]) if String((solids[i] as Dictionary)["owner"]) == "t" else int((solids[i] as Dictionary)["oi"])
	for g in grains:
		(g as Dictionary)["oi"] = int((g as Dictionary)["thing"]) if String((g as Dictionary)["owner"]) == "t" else int((g as Dictionary)["oi"])
	_make_twin()
	# THE SOLIDS: every part but a liquid, a loose thing's own, or a part of nothing (an empty mesh)
	var kept: Array = []
	var liquid_parts: Array = []
	var loose_parts := {}
	for s in solids:
		var sd: Dictionary = s
		if bool(sd.get("liquid_part", false)):
			liquid_parts.append(sd)
			continue
		if int(sd["loose"]) >= 0:
			if not loose_parts.has(int(sd["loose"])):
				loose_parts[int(sd["loose"])] = []
			(loose_parts[int(sd["loose"])] as Array).append(sd)
			continue
		sd["field"] = ShapeField.of(sd["part"], sd["box"])
		# ...its surface's points made now, before any bake runs beside the picture: both ask them ([RigidParts] as a body meets it,
		# the work as a plan sets a thing down by it), and the first asking was a race ([method ShapeField.surface_points])
		(sd["field"] as ShapeField).surface_points()
		sd["mu"] = _surface_friction(String((sd["part"] as Dictionary).get("material", "")))
		sd["rest"] = _pose_owner(sd, 0.0) * (sd["local"] as Transform3D)
		# ...and whether it is a thin tool ([constant Particles.THIN_TOOL]): thin two ways, not one - a handle, not a board
		var sz: Vector3 = (sd["box"] as AABB).size * (sd["rest"] as Transform3D).basis.get_scale()
		var sides := [sz.x, sz.y, sz.z]
		sides.sort()
		sd["thin"] = float(sides[1]) < Particles.THIN_TOOL
		sd["shown_ch"] = "w%d:shown" % int(sd["wi"]) if int(sd["wi"]) >= 0 else ""
		kept.append(sd)
	solids = kept
	# ...whose fields the work and its twin set things down by ([method TableWork._foot])
	work._solids_ref = solids
	twin._solids_ref = solids
	for si in solids.size():
		var sd: Dictionary = solids[si]
		sd["xf"] = sd["rest"]
		sd["xf0"] = sd["rest"]
		sd["xf00"] = sd["rest"]
		sd["inv"] = (sd["rest"] as Transform3D).affine_inverse()
		sd["wbox"] = ((sd["rest"] as Transform3D) * (sd["box"] as AABB)).grow(0.001)
		sd["moving"] = false
		sd["jolt"] = 0.0
		sd["dt"] = 1.0 / float(FPS)
		sd["on"] = true
		# ...and EVERY KEY THE BAKE FINDS LATER, empty: its points where it stands ([RigidParts]), its matter and its mass - a key
		# first given on the bake's thread moves the Dictionary under any read on the app's, so none is given after now
		sd["wpts"] = null
		sd["wpts_xf"] = Transform3D()
		sd["matter_pts"] = null
		sd["mass"] = null
	_make_liquids(liquid_parts)
	# ...and the vessels a pour finds its lip and its mouth by ([method TableWork._pour_plan])
	work._liquids_ref = liquids
	twin._liquids_ref = liquids
	_make_grains()
	_make_loose(loose_parts)
	_find_swings()
	_make_rigid()
	_built_displaced()
	_find_sprinkles()
	_frames_reset()
	_layout = _layout_of()
	_drawn_tables()
	_drawn_nodes()
	# ...and THE WORK'S OWN SOLIDS, each a copy: what it sets things down by and lifts them over is how each was built (its field,
	# where it stood), while the bake writes into its own as it goes - the points it meets a body by, its mass - keys a solid never
	# had, given while the app's thread read it
	var own: Array = []
	for sd in solids:
		own.append((sd as Dictionary).duplicate())
	work._solids_ref = own
	# (a table built aside to be played - [member TableMedium.live_build] - bakes on its own thread as one built where it stands does)
	var live: bool = work.medium != null and work.medium.get("live_build") == true
	_sync = work.medium == null or (bool(work.medium.aside) and not live) or (not work.medium.is_inside_tree() and not live) or (render_waits() and not threaded)
	if not _sync:
		_sem = Semaphore.new()
		_thread = Thread.new()
		_thread.start(_run)


## THE SAME TABLE, OTHER ACTS ([method TableWork.rebind]): nothing of the world is built again - it is the table's - only what the
## acts decide is taken up again: the twin's view of the acts, the sprinkles (kept by name), and every answer kept for the last
## plan. What was baked stays; the plan the work hands next ([method replan]) is baked again from the first moment it changes.
func rebind() -> void:
	twin.acts = work.acts
	twin.paint = work.paint.twin_for(twin) if work.paint != null else null
	twin._moved = work._moved
	twin._soft = work._soft
	_find_sprinkles()
	_drawn_tables()
	_intervals = {}
	_owner_pose = {}
	_hold_spans = {}
	_with_seat_of = {}
	_spans = null


## The picture's own tables ([member _drawn_mm]), made as the grains and loose things are, before any bake runs beside it.
func _drawn_tables() -> void:
	_drawn_mm = {}
	for gi in grains.size():
		_drawn_mm[gi] = ((grains[gi] as Dictionary)["mm"] as MultiMeshInstance3D).multimesh
	_loose_wi = PackedInt32Array()
	for li in loose.size():
		_drawn_mm[1000 + li] = ((loose[li] as Dictionary)["mm"] as MultiMeshInstance3D).multimesh
		_loose_wi.append(int((loose[li] as Dictionary)["wi"]))
	_sprinkles_drawn = []
	for sp in _sprinkles:
		_sprinkles_drawn.append({"key": (sp as Dictionary)["key"], "act": (sp as Dictionary)["act"], "track": (sp as Dictionary)["track"]})


## Whether this process's pictures wait for the physics, never ahead of the bake: a render (an export's Movie Maker, its
## `--export`) or a test - read off the command line as [method Settings.is_probe_launch] reads it, since a gate run with
## `--script` compiles this before the autoloads are up.
static func render_waits() -> bool:
	if not Engine.get_write_movie_path().is_empty() or OS.get_cmdline_user_args().has("--export"):
		return true
	var args := OS.get_cmdline_args()
	for i in args.size():
		if args[i].begins_with("res://tests/") and args[i].ends_with(".tscn"):
			return true
		if args[i] == "--script" and i + 1 < args.size() and args[i + 1].trim_prefix("res://").begins_with("tests/"):
			return true
	return false


## THE TWIN of the work's kinematics: the same things, works, acts and plan; its own depth; nothing in it touches a node.
func _make_twin() -> void:
	twin = TableWork.new()
	twin.medium = work.medium
	twin.things = work.things
	twin.works = work.works
	twin.groups = work.groups
	twin._group_of = work._group_of
	twin.acts = work.acts
	twin._rest = work._rest
	twin._runs_of = work._runs_of
	twin._moved = work._moved
	twin._soft = work._soft
	twin.since = work.since
	twin.tune = work.tune          # the show's tuning ([TableTune]): the bake paces its hands as the live table does
	twin._spot = work._spot
	twin._chan = _entries_of(work._chan)
	twin.runs = work.runs
	twin.materials = work.materials
	twin._parent_work = work._parent_work
	twin.swings = work.swings
	twin.hung = work.hung
	twin.paint = work.paint.twin_for(twin) if work.paint != null else null


## The pose of the node solid [param sd] hangs from at show time [param t], by the twin.
func _pose_owner(sd: Dictionary, t: float) -> Transform3D:
	if String(sd["owner"]) == "t":
		return twin._thing_world(int(sd["oi"]), t)
	return twin._work_world(int(sd["oi"]), t)


## THE LIQUIDS: each liquid part in the inside of the hollow part of its thing that holds it - drawn from now on as that
## inside, cut at its surface - and every other hollow part a liquid can be poured or dipped into, empty.
func _make_liquids(parts: Array) -> void:
	var mats: Dictionary = work.materials
	var vessels := {}         # solid -> Vessel
	var order: Array = []
	for si in solids.size():
		var f: ShapeField = (solids[si] as Dictionary)["field"]
		if f.hollow() and not bool((work.things[int((solids[si] as Dictionary)["thing"])] as Dictionary)["lit"]):
			order.append(si)
	# those holding a liquid or grains first, then those that move, then the rest - as many as are reckoned
	var rank := func(si: int) -> int:
		var sd: Dictionary = solids[si]
		var holds := 0
		for lp in parts:
			if int((lp as Dictionary)["thing"]) == int(sd["thing"]):
				holds = 2
		for g in grains:
			if int((g as Dictionary)["thing"]) == int(sd["thing"]):
				holds = maxi(holds, 2)
		# ...or loose things: a jar's lumps ride it only as its inside (one left out of the vessels reckoned had its lumps
		# left behind as it was carried)
		if int(sd["wi"]) >= 0:
			for c in work.works.size():
				if int(work._parent_work.get(c, -1)) == int(sd["wi"]) and bool(((work.works[c] as Dictionary)["w"] as Dictionary).get("loose", false)):
					holds = 2
					break
		# ...then A THING'S PARTS (a mortar, a vial, a jar), then the hollows of whole things - the table's alone, never what an act
		# moves: every whole thing ranked with the parts once it was a body, and 841899's mortar lost its inside to a recipe tin's
		if String(sd["owner"]) == "w":
			holds = maxi(holds, 1)
		return holds
	# ...ties by where each stands in the list: the same table reckons the same insides
	var key := {}
	for si in order:
		key[si] = int(rank.call(si)) * 100000 - int(si)
	order.sort_custom(func(a: int, b: int) -> bool: return int(key[a]) > int(key[b]))
	for si in order.slice(0, LIQUID_MOST):
		var v := Vessel.of((solids[si] as Dictionary)["field"])
		if v != null:
			vessels[si] = v
	# each liquid part in its vessel: the smallest inside that holds its middle
	var taken := {}
	for lp in parts:
		var ld: Dictionary = lp
		var best := -1
		var best_v := INF
		for si in vessels:
			var sd: Dictionary = solids[si]
			if int(sd["thing"]) != int(ld["thing"]) or taken.has(si):
				continue
			var vs: Vessel = vessels[si]
			var into_part := _in_part(ld, sd, (ld["box"] as AABB).get_center())
			if vs.contains(into_part) and vs.volume < best_v:
				best = si
				best_v = vs.volume
		if best < 0:
			notes.append("the liquid in \"%s\" is in no vessel's inside: it stays as it was drawn" % String((work.things[int(ld["thing"])] as Dictionary)["name"]))
			continue
		taken[best] = true
		_add_liquid(best, vessels[best], ld, mats)
	for si in vessels:
		if not taken.has(si) and liquids.size() < LIQUID_MOST:
			_add_liquid(si, vessels[si], {}, mats)


## Point [param p] of part [param from] (its own space) in part [param to]'s own space - both of one thing, as they stand.
func _in_part(from: Dictionary, to: Dictionary, p: Vector3) -> Vector3:
	var a := _pose_owner(from, 0.0) * (from["local"] as Transform3D)
	var b := _pose_owner(to, 0.0) * (to["local"] as Transform3D)
	return b.affine_inverse() * (a * p)


## A LIQUID in vessel [param si] ([param vs]): the liquid part [param ld] drawn in it (its meshes rebuilt as the inside,
## its material turned to [code]prop_liquid[/code] - the same material, so the work's tint, glow and boil still reach
## it), or none yet - an inside a pour or a dip may fill.
func _add_liquid(si: int, vs: Vessel, ld: Dictionary, mats: Dictionary) -> void:
	var sd: Dictionary = solids[si]
	var scale := absf((sd["rest"] as Transform3D).basis.determinant())
	var full := vs.volume * scale
	var entry := {"flow": _flow_of(si, vs, scale), "solid": si, "vessel": vs, "wi": -1, "nodes": [], "mats": [], "thing": int(sd["thing"]), "name": "", "full_v": full,
		"built_v": 0.0, "color": Color(0.5, 0.5, 0.6), "plugs": [], "made": not ld.is_empty()}
	var v0 := 0.0
	if not ld.is_empty():
		entry["wi"] = int(ld["wi"])
		entry["name"] = String(((ld["part"] as Dictionary).get("work", {}) as Dictionary).get("name", "liquid"))
		var m: Variant = mats.get(String((ld["part"] as Dictionary).get("material", "")))
		if m is Dictionary:
			entry["color"] = Color.html(String((m as Dictionary).get("color", "#5060a0")))
		# AS FULL AS IT WAS DRAWN: the share of the inside under its top, upright
		var top := _in_part(ld, sd, Vector3((ld["box"] as AABB).get_center().x, (ld["box"] as AABB).end.y, (ld["box"] as AABB).get_center().z))
		var up := ((sd["rest"] as Transform3D).basis.inverse() * Vector3.UP).normalized()
		var share := vs.share_under(up, top.dot(up))
		entry["built_v"] = share * full
		var start: Dictionary = ((ld["part"] as Dictionary).get("work", {}) as Dictionary).get("start", {})
		v0 = share * full * float(start.get("fill", 1.0))
		for mi in ld["meshes"]:
			var mesh := mi as MeshInstance3D
			if mesh == null:
				continue
			mesh.mesh = _inside_mesh(vs, mesh, sd)
			var mat := mesh.material_override as ShaderMaterial
			if mat != null:
				_liquid_shader(mat)
				_cavity_uniforms(mat, vs, mesh, sd)
				(entry["mats"] as Array).append(mat)
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			(entry["nodes"] as Array).append(mesh)
			# AS IT STANDS before a frame is baked (a set dresser's picture, the first moment): its surface where it was drawn
			if mat != null:
				var c_w := (sd["rest"] as Transform3D) * vs.surface_middle(up, vs.level(up, share))
				var mw := work._world_of(mesh)
				mat.set_shader_parameter("surface_at", mw.affine_inverse() * c_w)
				mat.set_shader_parameter("surface_up", (mw.basis.transposed() * Vector3.UP).normalized())
			mesh.visible = v0 > 1e-9 or share * full * float(start.get("fill", 1.0)) > 1e-9
	# STOPPERED: a part of its thing across its mouth, that a work can take away (or that never goes)
	for pj in solids.size():
		if pj == si or int((solids[pj] as Dictionary)["thing"]) != int(sd["thing"]):
			continue
		var pd: Dictionary = solids[pj]
		var c := _in_part(pd, sd, (pd["box"] as AABB).get_center())
		var r_top := vs.radius_at(vs.top_y - 0.001) if vs.field.kind == "lathe" else 0.0
		if absf(c.y - vs.top_y) < 0.012 and Vector2(c.x, c.z).length() < maxf(r_top, 0.003) and (pd["box"] as AABB).size.y < 0.04:
			(entry["plugs"] as Array).append(pj)
	entry["v0"] = v0
	# where an empty inside's liquid is drawn, kept apart: the bake's thread writes the solids, never these
	entry["holder"] = sd["holder"]
	entry["xform"] = sd["xform"]
	entry["rest"] = sd["rest"]
	entry["waves"] = SurfaceWaves.of(vs)
	_vessel_of[si] = liquids.size()
	liquids.append(entry)
	_liq.append({"v": v0, "d": Vector2.ZERO, "dd": Vector2.ZERO, "swirl": 0.0, "angle": 0.0, "c1": Vector3.INF, "c2": Vector3.INF,
		"color": entry["color"], "f": -1.0, "hit": Vector4.ZERO, "w": (entry["waves"] as SurfaceWaves).fresh(), "dipped": -1, "core": 0.0, "was": Vector2(-1.0, 0.0)})


## THE INSIDE HANDED TO A LIQUID'S SHADER ([method Vessel.shader_tables]): [param mesh]'s space carried into vessel
## [param vs]'s own (solid [param sd]'s part space, [method _mesh_in_vessel]), its tables.
func _cavity_uniforms(mat: ShaderMaterial, vs: Vessel, mesh: MeshInstance3D, sd: Dictionary) -> void:
	var tb := vs.shader_tables()
	var to_vessel := _mesh_in_vessel(mesh, sd)
	mat.set_shader_parameter("cavity_xf", Projection(to_vessel))
	mat.set_shader_parameter("cavity_scale", tb["scale"])
	mat.set_shader_parameter("cavity_pivot", tb["pivot"])
	mat.set_shader_parameter("cavity_y", tb["y"])
	mat.set_shader_parameter("cavity_mid", tb["mid"])
	mat.set_shader_parameter("cavity_r", tb["r"])
	mat.set_shader_parameter("cavity_a", tb["a"])
	mat.set_shader_parameter("cavity_known", true)


## [param mesh]'s space in vessel solid [param sd]'s part space - the two move together, so it is taken through the node the
## solid hangs from as it stands now, never against the solid as built: an inside made as a vessel is first filled, away from
## where it was built (841899's ladle, first dipped in its pot), had been built and drawn that whole way off, a ghost of the
## ladle's bowl over the balance going round with every stir.
func _mesh_in_vessel(mesh: MeshInstance3D, sd: Dictionary) -> Transform3D:
	var on: Node3D = (work.things[int(sd["oi"])] as Dictionary)["node"] if String(sd["owner"]) == "t" \
		else (work.works[int(sd["oi"])] as Dictionary)["node"]
	return (sd["local"] as Transform3D).affine_inverse() * work._world_of(on).affine_inverse() * work._world_of(mesh)


## The inside of [param vs] as a mesh in [param mesh]'s own space (the vessel [param sd]'s part space carried there).
func _inside_mesh(vs: Vessel, mesh: MeshInstance3D, sd: Dictionary) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var spec := vs.part_spec()
	var geos := Props._shaped(spec, rng)
	if geos.is_empty():
		return mesh.mesh as ArrayMesh
	var g: Props.Tris = (geos[0] as Dictionary)["geo"]
	if vs.field.kind == "extrude":
		g.lift(vs.floor_y)
	# the vessel's part space -> this mesh's space
	var to := _mesh_in_vessel(mesh, sd).affine_inverse()
	var nb := to.basis.inverse().transposed()
	for i in g.v.size():
		g.v[i] = to * vs.warp_point(g.v[i])
		g.n[i] = (nb * g.n[i]).normalized()
	return g.mesh()


## THE GRAINS: each part's grains laid into the inside of the hollow part of its thing it is drawn in, up to its `fill`
## - or, in none, heaped where it is drawn - each grain asleep on what holds it.
func _make_grains() -> void:
	var mats: Dictionary = work.materials
	for gi in grains.size():
		var g: Dictionary = grains[gi]
		var part: Dictionary = g["part"]
		var mi := _matter_of(String(part.get("material", "")), mats)
		var at_w := _pose_owner(g, 0.0) * (g["local"] as Transform3D)
		var host := -1
		var vs: Vessel = null
		for li in liquids.size():
			var sd: Dictionary = solids[int((liquids[li] as Dictionary)["solid"])]
			if int(sd["thing"]) != int(g["thing"]):
				continue
			var p := (sd["rest"] as Transform3D).affine_inverse() * at_w.origin
			var cand: Vessel = (liquids[li] as Dictionary)["vessel"]
			if cand.contains(p) and (vs == null or cand.volume < vs.volume):
				vs = cand
				host = int((liquids[li] as Dictionary)["solid"])
		var want := float(part.get("grain", 0.3)) * 0.005
		var spots := PackedVector3Array()
		if vs != null:
			var sd: Dictionary = solids[host]
			var xf: Transform3D = sd["rest"]
			var up := (xf.basis.inverse() * Vector3.UP).normalized()
			var fill := float(part.get("fill", 0.4))
			var filled := vs.volume * fill
			var rad := maxf(want, pow(filled * PACKED / (float(GRAINS_MOST) * 4.18879), 1.0 / 3.0))
			rad = clampf(rad, Particles.POWDER, Particles.SPHERE.y)
			var s := vs.level(up, fill)
			spots = _pack(vs, rad, s, up, xf, gi)
			g["radius"] = rad
		else:
			var n := clampi(int(part.get("amount", 0)) if int(part.get("amount", 0)) > 0 else 60, 1, GRAINS_MOST)
			var rad := clampf(want, Particles.POWDER, Particles.SPHERE.y)
			spots = _heap(at_w.origin, rad, n, gi)
			g["radius"] = rad
		var ids := PackedInt32Array()
		var host_xf: Transform3D = (solids[host] as Dictionary)["rest"] if host >= 0 else Transform3D.IDENTITY
		for p in spots:
			var i := sim.add(p, float(g["radius"]), mi, gi, host, host_xf)
			if i >= 0:
				ids.append(i)
		g["ids"] = ids
		g["solid"] = host
		var m: Variant = mats.get(String(part.get("material", "")))
		g["mm"] = _lumps(ids.size(), m if m is Dictionary else {}, gi)


## SPHERES OF [param rad] PACKED into vessel [param vs]'s inside up to [param s] along [param up] (its part space), each
## clear of its walls and a layer offset from the one under it - in the table's space ([param xf]).
func _pack(vs: Vessel, rad: float, s: float, up: Vector3, xf: Transform3D, salt: int) -> PackedVector3Array:
	var out := PackedVector3Array()
	var step := rad * 2.0
	var lo := Vector3(INF, INF, INF)
	var hi := Vector3(-INF, -INF, -INF)
	for p in vs.points:
		lo = Vector3(minf(lo.x, p.x), minf(lo.y, p.y), minf(lo.z, p.z))
		hi = Vector3(maxf(hi.x, p.x), maxf(hi.y, p.y), maxf(hi.z, p.z))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([salt, "grains"])
	var layer := 0
	var y := lo.y + rad * 0.5
	while y < hi.y and out.size() < GRAINS_MOST:
		var off := (rad if layer % 2 == 1 else 0.0)
		var x := lo.x + off
		while x <= hi.x:
			var z := lo.z + off
			while z <= hi.z:
				var p := Vector3(x, y, z) + Vector3(rng.randf_range(-0.15, 0.15), 0.0, rng.randf_range(-0.15, 0.15)) * rad
				if p.dot(up) <= s - rad * 0.3 and _clear_in(vs, p, rad):
					out.append(xf * p)
					if out.size() >= GRAINS_MOST:
						return out
				z += step
			x += step
		y += step * 0.86
		layer += 1
	return out


## Whether a sphere of [param rad] at [param p] lies in [param vs]'s inside, clear of its walls.
func _clear_in(vs: Vessel, p: Vector3, rad: float) -> bool:
	if not vs.contains(p):
		return false
	var d := vs.field.sample(p).x
	return d > rad * 0.9


## A HEAP of [param n] spheres of [param rad] about [param at] (the table's space): a cone a layer at a time, the
## widest at the bottom, as a poured heap lies.
func _heap(at: Vector3, rad: float, n: int, salt: int) -> PackedVector3Array:
	var out := PackedVector3Array()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([salt, "heap"])
	var base := maxi(int(ceil(pow(float(n) * 1.6, 1.0 / 3.0) * 1.4)), 1)
	var layer := 0
	while out.size() < n and layer < 40:
		var ring := maxi(base - layer, 1)
		var y := at.y + rad + float(layer) * rad * 1.7
		for i in range(-ring, ring + 1):
			for k in range(-ring, ring + 1):
				if Vector2(i, k).length() > float(ring) + 0.01 or out.size() >= n:
					continue
				var j := Vector3(rng.randf_range(-0.2, 0.2), 0.0, rng.randf_range(-0.2, 0.2)) * rad
				out.append(Vector3(at.x + float(i) * rad * 2.0, y, at.z + float(k) * rad * 2.0) + j)
		layer += 1
	return out


## THE LOOSE THINGS: each loose work's parts the spheres that will fill them - a body of them once anything comes to it
## ([method _wake_loose]), till then lying as it was built.
func _make_loose(parts: Dictionary) -> void:
	var mats: Dictionary = work.materials
	for wi in parts:
		var list: Array = parts[wi]
		var n0: Transform3D = work._rest.get("w%d:pose" % int(wi), Transform3D.IDENTITY)
		var spheres := PackedVector3Array()
		var mat_name := ""
		var rad := Particles.SPHERE.y
		var longest := 0.0
		for sd in list:
			var box: AABB = (sd as Dictionary)["box"]
			var xf := n0 * ((sd as Dictionary)["local"] as Transform3D)
			var size: Vector3 = box.size * xf.basis.get_scale()
			rad = minf(rad, Particles.sphere_for(size))
			longest = maxf(longest, maxf(size.x, maxf(size.y, size.z)))
			if mat_name.is_empty():
				mat_name = String(((sd as Dictionary)["part"] as Dictionary).get("material", ""))
		# spaced wider in what no blade will cut ([constant Particles.BODY_SPREAD]): not soft, or too small to slice
		var m0: Variant = mats.get(mat_name)
		var soft := String((m0 as Dictionary).get("kind", "") if m0 is Dictionary else "") in CUTS
		var spread := 1.0 if soft and longest >= SLICE_LEAST else Particles.BODY_SPREAD
		# A SHEET RESTS AT ITS OWN THICKNESS ([member Particles.rc]), its spheres a layer close enough that what it lies across
		# meets it
		var contact := 0.0
		var bends := false
		for sd in list:
			var box: AABB = (sd as Dictionary)["box"]
			var xf := n0 * ((sd as Dictionary)["local"] as Transform3D)
			var f := ShapeField.of((sd as Dictionary)["part"], box)
			if f.kind == "sheet":
				contact = maxf(contact, maxf(f.thick * 0.5 * xf.basis.get_scale().y, CONTACT_LEAST))
				spread = 1.0
				# ...AND ONE OF WHAT GIVES BENDS ([method Particles.make_soft]): a body of one part, as a heap's copies are not
				bends = list.size() == 1 and String((m0 as Dictionary).get("kind", "") if m0 is Dictionary else "") in BENDS
		for sd in list:
			var box: AABB = (sd as Dictionary)["box"]
			var xf := n0 * ((sd as Dictionary)["local"] as Transform3D)
			var f := ShapeField.of((sd as Dictionary)["part"], box)
			var local_rad := rad / maxf(xf.basis.get_scale().x, 1e-4)
			spheres.append_array(Particles.fill_shape(f, box, local_rad, xf, Particles.SOFT_MOST if bends else Particles.BODY_MOST, spread))
		if spheres.is_empty():
			continue
		var mi := _matter_of(mat_name, mats)
		var li := loose.size()
		var box := AABB(spheres[0], Vector3.ZERO)
		for p in spheres:
			box = box.expand(p)
		var m: Variant = mats.get(mat_name)
		loose.append({"wi": int(wi), "thing": int((work.works[int(wi)] as Dictionary)["thing"]), "body": -1, "n0": n0, "built": n0,
			"spheres": spheres, "box": box.grow(rad), "mi": mi, "full": false,
			"name": work._part_label(int(wi)), "mm": _lumps(Particles.BODY_MOST * 6, m if m is Dictionary else {}, 500 + li, true),
			"rad": rad, "contact": contact,
			# ...every key the bake gives it as it wakes and comes to rest, as it is before then: none given after now
			"calm": 0.0, "rest": null, "rest_host": -1, "rest_hxf": null, "rest_hrel": null, "rest_up": null, "mass": 0.0,
			"soft": bends, "rest_off": null, "bo_at": _bo_n})
		if bends:
			_bo_n += spheres.size()
		_loose_of[int(wi)] = li
	_lying_cells()


## The cells of what is awake each loose thing lying would be near ([method _wake_near_loose]), where it lies.
func _lying_cells() -> void:
	_lying_at = {}
	for li in loose.size():
		var L: Dictionary = loose[li]
		var near := (L["box"] as AABB).grow(float(L["rad"]) + Particles.AWAKE_CELL)
		var lo := Particles._cell(near.position, Particles.AWAKE_CELL)
		var hi := Particles._cell(near.end, Particles.AWAKE_CELL)
		for cx in range(lo.x, hi.x + 1):
			for cy in range(lo.y, hi.y + 1):
				for cz in range(lo.z, hi.z + 1):
					var cell := Vector3i(cx, cy, cz)
					if not _lying_at.has(cell):
						_lying_at[cell] = []
					(_lying_at[cell] as Array).append(li)


## A LOOSE THING COMES TO BE A BODY, at show time [param t], where the work has it then: once the work holds it, its
## holder moves, or a moving solid or anything awake comes near it. Lying untouched it costs nothing - a dense table's
## loose things had been made bodies until the solver held no more, and the rest lay rigid, never falling, never
## colliding, never crushed (the-quiet-crucible 119515: of 125, 114 - its dragon's blood, its pumpkin seeds, its nails
## and its dragon's scale among them; the user, 2026-10-29: "The ingredients also have no collision, they don't rest
## on the bottom of the mortar, and they appear to be floating a bit"). Whether it became one.
func _wake_loose(li: int, t: float) -> bool:
	var L: Dictionary = loose[li]
	if int(L["body"]) >= 0:
		return true
	var spheres: PackedVector3Array = L["spheres"]
	# ...ROOM FOR IT, now: what has come to rest gives its spheres back ([method _rest_loose]), so one turned away is asked again
	if sim.room() < spheres.size():
		if not bool(L["full"]):
			print("ghost: %s lies as it was built: the physics holds no more" % String(L["name"]))
		L["full"] = true
		return false
	L["full"] = false
	# ...from where it came to rest, as what holds it stands now - or where the work has it
	var now := twin._work_world(int(L["wi"]), t)
	if L.get("rest") != null:
		var hs := int(L["rest_host"])
		now = ((solids[hs] as Dictionary)["xf"] as Transform3D) * (L["rest_hrel"] as Transform3D) if hs >= 0 and hs < solids.size() else L["rest"]
	var moved := now * (L["built"] as Transform3D).affine_inverse()
	var at := PackedVector3Array()
	var mid := Vector3.ZERO
	for p in spheres:
		at.append(moved * p)
		mid += moved * p
	mid /= float(spheres.size())
	var host := _host_at(mid, int(L["thing"]))
	var host_xf: Transform3D = (solids[host] as Dictionary)["xf"] if host >= 0 else Transform3D.IDENTITY
	var bi := sim.add_body(at, float(L["rad"]), int(L["mi"]), 1000 + li, host, host_xf, float(L.get("contact", 0.0)))
	if bi < 0:
		L["full"] = true
		return false
	L["body"] = bi
	L["n0"] = now
	L["rest"] = null
	L["calm"] = 0.0
	# ...A SHEET THAT BENDS, bent as it lay
	if bool(L["soft"]):
		sim.make_soft(bi)
		if L["rest_off"] != null:
			var bd: Dictionary = sim.bodies[bi]
			var ids: PackedInt32Array = bd["ids"]
			var off: PackedVector3Array = bd["off"]
			var lay: PackedVector3Array = L["rest_off"]
			for k in mini(ids.size(), lay.size()):
				off[k] = moved.basis * lay[k]
				sim.x[ids[k]] = moved * (spheres[k] + lay[k])
			bd["off"] = off
	return true


## WHAT COMES NEAR A LOOSE THING YET TO BE A BODY makes it one ([method _wake_loose]): a moving solid - its holder
## carried, a pestle brought to it - or anything awake.
func _wake_near_loose(t: float) -> void:
	# what moves, and the lying things in the cells of what is awake ([member _lying_at]): the rest are never looked at
	var moving: Array = []
	var any_moving := false
	for si in solids.size():
		var sd: Dictionary = solids[si]
		if not bool(sd["moving"]):
			continue
		any_moving = true
		# ...a part the work picks up only held, or going somewhere: settling, it stirs nothing ([constant RigidParts.STIRS])
		if sd.has("body"):
			var b: Dictionary = rigid.bodies[int(sd["body"])]
			if b["held"] == null and float(b.get("stir", 0.0)) < RigidParts.STIRS:
				continue
		moving.append([si, (sd["wbox"] as AABB).grow(0.01)])
	var near_awake := {}
	for cell in sim.awake_cells:
		for li in _lying_at.get(cell, []):
			near_awake[li] = true
	if not any_moving and near_awake.is_empty():
		return
	for li in loose.size():
		var L: Dictionary = loose[li]
		if int(L["body"]) >= 0:
			continue
		var box: AABB = L["box"]
		# ONE LYING AGAIN goes where what holds it goes, unwoken - unless it tips or jolts under it ([method _rest_loose])
		var hs := int(L.get("rest_host", -1)) if L.get("rest") != null else -1
		if hs >= 0 and hs < solids.size():
			var hd: Dictionary = solids[hs]
			box = ((hd["xf"] as Transform3D) * (L["rest_hxf"] as Transform3D).affine_inverse()) * box
			if bool(hd["moving"]) and ((hd["xf"] as Transform3D).basis.y.normalized().angle_to(L["rest_up"] as Vector3) > Particles.WAKE_TILT \
					or float(hd.get("jolt", 0.0)) > Particles.WAKE_JOLT):
				_wake_loose(li, t)
				continue
		var near := near_awake.has(li) and sim.awake_in(box)
		if not near:
			for e in moving:
				if int((e as Array)[0]) != hs and ((e as Array)[1] as AABB).intersects(box):
					near = true
					break
		if near:
			_wake_loose(li, t)


## A LOOSE THING AT REST LIES AGAIN (841899, replayed: every loose thing anything had come near stayed a body to the end of
## the show, the solver was full by its middle - "lies as it was built: the physics holds no more" - and a jar's lumps, never
## made bodies, were left where they lay as their jar was carried off): a body asleep [constant RELEASE_AFTER] seconds, whole,
## held by nothing and in no liquid, gives its spheres back, its place kept where it came to rest as what it rests on holds it
## - and anything coming to it makes it a body again there ([method _wake_loose]).
func _rest_loose(dt: float) -> void:
	var moved := false
	for li in loose.size():
		var L: Dictionary = loose[li]
		var bi := int(L["body"])
		if bi < 0:
			continue
		var b: Dictionary = sim.bodies[bi]
		var ids: PackedInt32Array = b["ids"]
		if not bool(b["intact"]) or b["held"] != null or _piece_at.has(bi) or ids.is_empty() or not sim.body_asleep(bi) \
				or sim.wet[ids[0]] >= 0:
			L["calm"] = 0.0
			continue
		L["calm"] = float(L.get("calm", 0.0)) + dt
		if float(L["calm"]) < RELEASE_AFTER:
			continue
		var pose := sim.body_pose(bi) * (L["n0"] as Transform3D)
		var hs := sim.host[ids[0]]
		# ...held by what it is AT: a sleeper's host found through its neighbors can be a jar carried off without it
		if hs >= 0 and hs < solids.size():
			var hd: Dictionary = solids[hs]
			if (hd["field"] as ShapeField).sample((hd["inv"] as Transform3D) * (sim.bodies[bi] as Dictionary)["c"]).x > float(L["rad"]) * 2.0 + 0.01:
				hs = -1
		var hxf: Transform3D = (solids[hs] as Dictionary)["xf"] if hs >= 0 and hs < solids.size() else Transform3D.IDENTITY
		if bool(L["soft"]):
			L["rest_off"] = _bent_built(L, b)
		L["rest"] = pose
		L["rest_host"] = hs if hs < solids.size() else -1
		L["rest_hxf"] = hxf
		L["rest_hrel"] = hxf.affine_inverse() * pose
		L["rest_up"] = hxf.basis.y.normalized()
		L["mass"] = _body_mass(bi)
		var box := AABB()
		var first := true
		var moved_by := pose * (L["built"] as Transform3D).affine_inverse()
		for p in (L["spheres"] as PackedVector3Array):
			box = AABB(moved_by * p, Vector3.ZERO) if first else box.expand(moved_by * p)
			first = false
		L["box"] = box.grow(float(L["rad"]))
		for i in ids:
			if sim.alive[i] == 1:
				sim.alive[i] = 0
				sim.asleep[i] = 0
		# ...AND ITS BODY LETS GO OF THEM: the solver gives a dead sphere's place to the next made, and a body still naming the
		# spheres it gave back had shape-matched the next thing made in them toward its own old shape - a resin tear let go
		# over its mortar flew off the table at the solver's fastest, and a lump laid on a balance's pan leapt 33 cm
		b["ids"] = PackedInt32Array()
		b["rest"] = PackedVector3Array()
		b.erase("links")
		L["body"] = -1
		L["calm"] = 0.0
		moved = true
	if moved:
		_lying_cells()


## How sheet [param L], body [param b], is bent, from as it was built: what a frame keeps ([method bend_of]).
func _bent_built(L: Dictionary, b: Dictionary) -> PackedVector3Array:
	var back := ((L["n0"] as Transform3D) * (L["built"] as Transform3D).affine_inverse()).basis.inverse()
	var out := PackedVector3Array()
	for q in (b["off"] as PackedVector3Array):
		out.append(back * q)
	return out


## The solid a thing at [param p] (the table's space) rests on or in, where the solids are now: a vessel's inside that
## holds it, else the nearest solid within a few centimeters - of [param ti] first - else -1 (the table).
func _host_at(p: Vector3, ti: int) -> int:
	for li in liquids.size():
		var sd: Dictionary = solids[int((liquids[li] as Dictionary)["solid"])]
		if ((liquids[li] as Dictionary)["vessel"] as Vessel).contains((sd["xf"] as Transform3D).affine_inverse() * p):
			return int((liquids[li] as Dictionary)["solid"])
	var best := -1
	var bd := 0.03
	for si in solids.size():
		var sd: Dictionary = solids[si]
		if not (sd["wbox"] as AABB).grow(0.03).has_point(p):
			continue
		var d := (sd["field"] as ShapeField).sample((sd["inv"] as Transform3D) * p).x - (0.01 if int(sd["thing"]) == ti else 0.0)
		if d < bd:
			bd = d
			best = si
	return best


## How a solid of table material [param name] holds what rests on it: its surface's own friction, static and kinetic
## ([constant SURFACES]), met with a particle's own ([Particles]).
func _surface_friction(name: String) -> Vector2:
	var m: Variant = work.materials.get(name)
	return SURFACES.get(String((m as Dictionary).get("kind", "")) if m is Dictionary else "", SURFACE_ELSE)


## The matter row of table material [param name] ([param mats]): its class's, or what the set dresser wrote.
func _matter_of(name: String, mats: Dictionary) -> int:
	if _matter.has(name):
		return int(_matter[name])
	var m: Dictionary = mats.get(name, {}) if mats.get(name) is Dictionary else {}
	var row: Dictionary = Props.MATERIALS.get(String(m.get("kind", "painted")), Props.MATERIALS["painted"])
	var fr := Particles.FRICTION
	if String(m.get("kind", "")) in ["powder", "plant"]:
		fr = Vector2(0.6, 0.45)
	elif String(m.get("kind", "")) in ["glass", "crystal", "metal"]:
		fr = Vector2(0.45, 0.3)
	var i := sim.add_matter(float(m.get("density", row["density"])), float(row["strength"]), float(m.get("dissolves", row["dissolves"])), fr,
		String(m.get("kind", "")) in CUTS)
	_matter[name] = i
	return i


## A MULTIMESH of [param n] lumps of material [param m] (its own look, [method Props.material]): how grains and the pieces
## of a broken thing are drawn.
func _lumps(n: int, m: Dictionary, salt: int, faceted := false) -> MultiMeshInstance3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([salt, "lump"])
	var kind := String(m.get("kind", "powder"))
	var g: Props.Tris = Props._ball(Vector3(2.0, 1.7, 2.0), 0.45, faceted or kind in ["crystal", "stone", "ceramic"], rng)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.instance_count = maxi(n, 1)
	mm.visible_instance_count = 0
	mm.mesh = g.mesh()
	var node := MultiMeshInstance3D.new()
	node.multimesh = mm
	node.material_override = Props.material(m if not m.is_empty() else Props.sanitize_material({"kind": "powder"}, "#e8e8ee"), {}, 6.0, 2.0, salt)
	_root.add_child(node)
	return node


## THE SPRINKLES of the acts: grains let fall from a point ([constant Motions.LAWS] `sprinkle`) - each a grains part of its
## own, made here on the table's thread, so what falls is drawn as its material.
func _find_sprinkles() -> void:
	var mats: Dictionary = work.materials
	# ...EACH KEPT BY ITS ACT'S NAME AND TRACK, never by where it is in the list: acts written again (a puppeteer's next `act`) find
	# their own, a new one is added at the end, and one taken out is let fall no more - the grains and checkpoints already made
	# keep their places ([method rebind])
	var by_key := {}
	for si in _sprinkles.size():
		by_key[String((_sprinkles[si] as Dictionary)["key"])] = si
		(_sprinkles[si] as Dictionary)["act"] = -1
	for ai in work.acts.size():
		var tracks: Array = (work.acts[ai] as Dictionary)["tracks"]
		for k in tracks.size():
			var tr: Dictionary = tracks[k]
			if String(tr["law"]) != "sprinkle":
				continue
			var key := "%s#%d" % [String((work.acts[ai] as Dictionary)["name"]), k]
			if by_key.has(key) and _same_value(JSON.stringify((_sprinkles[int(by_key[key])] as Dictionary)["track"]), JSON.stringify(tr)):
				(_sprinkles[int(by_key[key])] as Dictionary)["act"] = ai
				continue
			if by_key.has(key):
				key += "@%d" % _sprinkles.size()
			var mname := String(tr.get("material", ""))
			var m: Variant = mats.get(mname)
			var gi := grains.size()
			grains.append({"name": "%s let fall" % (mname if not mname.is_empty() else "grains"), "thing": -1, "wi": -1, "ids": PackedInt32Array(),
				"solid": -1, "mm": _lumps(int(tr.get("amount", 24)), m if m is Dictionary else {}, 900 + gi)})
			_sprinkles.append({"act": ai, "track": tr, "grains": gi, "owner": gi, "key": key, "done": 0})
			# its matter made now, never as its first grain falls: a checkpoint restored on another table names it
			_matter_of(mname, mats)


# --- the plan ---------------------------------------------------------------------------------------------

## Whether the bake reads channel [param ch]: a pose, a joint's angle or offset, whether a part is there, a fill.
static func _bakes(ch: String) -> bool:
	return ch.ends_with(":pose") or ch.ends_with(":angle") or ch.ends_with(":offset") or ch.ends_with(":shown") or ch.ends_with(":fill")


## THE FIRST MOMENT a channel's moves [param b] differ from what they were, [param a] ([method replan]): where the first move
## that is not the same begins - or, the same move from the same place and the same start whose place goes by its time alone
## ([method _length_free]), ending elsewhere, where the sooner end is. INF: nothing differs.
func _changed_from(a: Array, b: Array) -> float:
	for k in maxi(a.size(), b.size()):
		if k >= a.size():
			return float((b[k] as Dictionary)["s0"])
		if k >= b.size():
			return float((a[k] as Dictionary)["s0"])
		var ea: Dictionary = a[k]
		var eb: Dictionary = b[k]
		var s0 := minf(float(ea["s0"]), float(eb["s0"]))
		# ...and WHAT IT DOES: an act written again (a puppeteer's next `act`) keeps its name and its time and moves otherwise
		if String(ea.get("act", ea["i"])) != String(eb.get("act", eb["i"])) or int(ea.get("order", -1)) != int(eb.get("order", -1)) \
				or not is_equal_approx(float(ea["s0"]), float(eb["s0"])) or not is_equal_approx(float(ea["t0"]), float(eb["t0"])) \
				or not _same_value(ea.get("from"), eb.get("from")) or ea.get("track") != eb.get("track"):
			return s0
		var slopes_same: bool = ea.get("_m", PackedVector3Array()) == eb.get("_m", PackedVector3Array())
		if is_equal_approx(float(ea["s1"]), float(eb["s1"])) and is_equal_approx(float(ea["t1"]), float(eb["t1"])) and slopes_same:
			continue
		if slopes_same and _length_free(ea["track"]):
			return minf(float(ea["s1"]), float(eb["s1"]))
		return s0
	return INF


## Whether two values a channel starts a move from are the same: a pose, a number or a color.
static func _same_value(x: Variant, y: Variant) -> bool:
	if x is Transform3D and y is Transform3D:
		return (x as Transform3D).is_equal_approx(y)
	if (x is float or x is int) and (y is float or y is int):
		return is_equal_approx(float(x), float(y))
	return x == y


## WHETHER A MOVE'S PLACE GOES BY ITS TIME ALONE, never by how long its act is: a round or an aim gone round by its period, a
## swing, a turn, a clock - over its whole act, with no formula that might read its length.
static func _length_free(tr: Dictionary) -> bool:
	if not String(tr.get("law", "")) in ["circle", "aim", "swing", "turn", "clock"]:
		return false
	var w: Variant = tr.get("between")
	if w is Vector2 and not (w as Vector2).is_equal_approx(Vector2(0.0, 1.0)):
		return false
	for part in [tr, tr.get("tip", {}), tr.get("grip", {})]:
		var d: Dictionary = part
		if d.has("keys"):
			return false
		for key in ["period", "lift", "radius", "amount", "rate", "start", "roll"]:
			if d.get(key) is String:
				return false
	return true

## A NEW PLAN ([method TableWork._timelines]): handed to the twin, and baked again from THE FIRST MOMENT IT CHANGES WHAT IS
## BAKED - never from where an act it moved began. A live reading hands one over with each sentence, and a stir that runs as
## long as its words leave it has a new end every time: baked again from its start, the bake fell further behind each sentence
## and a live show waited 37 s at a time for it (841899, 2026-10-30). Only the channels the bake reads count (where things and
## parts are, their joints, whether a solid is there, a fill - never a brew's boil or a tint), entry by entry, and a move whose
## place goes by its time alone (a round, a swing) and only ends elsewhere is changed from where the sooner end is.
func replan() -> void:
	var from := INF
	var old: Dictionary = _chan_seen
	var now_chan: Dictionary = work._chan
	for ch in now_chan:
		if _bakes(String(ch)):
			from = minf(from, _hold_changed(String(ch), old.get(ch, []), now_chan[ch], _changed_from(old.get(ch, []), now_chan[ch])))
	for ch in old:
		if not now_chan.has(ch) and _bakes(String(ch)):
			from = minf(from, _changed_from(old[ch], []))
	# ...and when each sprinkle falls, against when it fell in the plan before
	# (the app's own list of them, [member _sprinkles_seen]: a sprinkle's Dictionary is the bake's, which writes into it as it falls)
	for sp in _sprinkles_drawn:
		var sd: Dictionary = sp
		var was: Vector2 = _sprinkles_seen.get(String(sd["key"]), Vector2(INF, INF))
		var now := _sprinkle_span_in(sd, work.runs)
		if not now.is_equal_approx(was) and not (is_inf(now.x) and is_inf(was.x)):
			from = minf(from, minf(was.x, now.x))
		_sprinkles_seen[String(sd["key"])] = now
	_runs_seen = (work.runs as Array).duplicate(true)
	_chan_seen = now_chan
	var job := {"chan": _entries_of(work._chan), "runs": work.runs, "from": from}
	_lock.lock()
	if _pending != null and float((_pending as Dictionary)["from"]) < from:
		job["from"] = (_pending as Dictionary)["from"]
	_pending = job
	_lock.unlock()
	if _sem != null:
		_sem.post()


## THE TWIN'S OWN ENTRIES of channels [param chan] (each a copy; what they hold - a track, a pose - is never written again): posing
## an entry keeps what it found on it (a carry's way over what is in it, its room, how far it sets down), and the app's thread
## and the bake's both pose - on one entry, each wrote keys into a Dictionary the other was reading.
static func _entries_of(chan: Dictionary) -> Dictionary:
	var out := {}
	for ch in chan:
		var list: Array = []
		for e in chan[ch]:
			list.append((e as Dictionary).duplicate())
		out[ch] = list
	return out


## ...OR SOONER, where a change at [param f] on channel [param ch] (plans [param a], then [param b]) has the hand HOLD what the move
## before it left, which the last plan had it let go of ([method _holds_across]): its next move brought within a pause - baked
## again from that move's end, or what an export holds lies wherever it fell (feedback 0004). Never the other way: what the last
## plan held a pause longer than this one would is a thing that hovered a moment - and going back for it had the show wait while
## the bake went back over what it had shown (841899: a stir placed 14 s after the ladle's move took the bake back 10 s). A move
## placed where a hold already stood in for it ([method _to_come]) turns nothing.
func _hold_changed(ch: String, a: Array, b: Array, f: float) -> float:
	if f == INF:
		return f
	var last: Dictionary = {}
	for e in b:
		if float((e as Dictionary)["s1"]) <= f:
			last = e
	if last.is_empty():
		return f
	var was: Dictionary = {}
	for e in a:
		if float((e as Dictionary)["s0"]) > float(last["s1"]):
			was = e
			break
	var now: Dictionary = {}
	for e in b:
		if float((e as Dictionary)["s0"]) > float(last["s1"]):
			now = e
			break
	var to_come := _to_come_in(ch, last)
	return minf(f, float(last["s1"])) if _holds_across(last, now, to_come) and not _holds_across(last, was, to_come) else f


## [method _to_come] by the work's acts, for a plan on the app's thread ([method replan]): whether an act after [param last]'s moves
## channel [param ch] at all - placed or not, as the bake's twin asks it of what it was handed.
func _to_come_in(ch: String, last: Dictionary) -> bool:
	for ai in range(int(last.get("i", -1)) + 1, work.acts.size()):
		for tr in (work.acts[ai] as Dictionary)["tracks"]:
			if String((tr as Dictionary).get("_ch", "")) == ch:
				return true
	return false


## Show time at bake frame [param k].
func _t_of(k: int) -> float:
	return _t0 + float(k) / float(FPS)


## The bake frame at show time [param t] (the one it lies in).
func _k_of(t: float) -> int:
	return int(floor((t - _t0) * float(FPS) + 1e-6))


## The plan handed over taken up: the twin's, and the bake gone back to the last checkpoint before what it moved. WHERE
## EACH HELD MOVE BEGAN ([member _held]) IS KEPT: what the plan changed lies past the bake, or the bake goes back to a
## checkpoint, which holds its own. (841899 played live: a plan made again as a sentence's words came, the bake half way
## through the ladle's way to the pot, began that move again from where the ladle was by then - its way and its turn
## taken twice, it went over the pot and came down upside-down past it.)
func _take_plan() -> void:
	_lock.lock()
	var job: Variant = _pending
	_pending = null
	_lock.unlock()
	if job == null:
		return
	twin._chan = (job as Dictionary)["chan"]
	twin.runs = (job as Dictionary)["runs"]
	_intervals = {}
	_owner_pose = {}
	_hold_spans = {}
	_with_seat_of = {}
	_spans = null
	# ...FROM THE FIRST ACT, BEFORE 0 WHERE IT IS ([member _t0]): an earlier past is baked from as built - what was done before
	# the first act changed nothing
	var first := 0.0
	for r in twin.runs:
		first = minf(first, float((r as Dictionary)["t0"]))
	var origin := minf(floor((first - PAST_LEAD) * float(FPS)) / float(FPS), 0.0) if first < 0.0 else 0.0
	if origin < _t0:
		_t0 = origin
		_carried = null
		_restore(_ck[0])
		_lock.lock()
		frames.resize(0)
		_lock.unlock()
	if _carried != null:
		var c: Dictionary = _carried
		_carried = null
		if _take_carried(c):
			resumed_at = _t_of(_k)
			return
	var from := float((job as Dictionary)["from"])
	if from == INF:
		return
	if _t_of(_k) > from:
		var ck: Dictionary = _ck[0]
		for c in _ck:
			if _t_of(int((c as Dictionary)["k"])) <= from:
				ck = c
		_restore(ck)
	resumed_at = _t_of(_k)
	# ...AND WHAT WAS BAKED PAST THE CHANGE IS GONE: kept, it was the last plan's, drawn as this one's and counted as baked -
	# the live viewer showed what the export never would, and said it was caught up (what lies between the checkpoint and the
	# change is baked again the same)
	_lock.lock()
	var keep := maxi(_k, _k_of(from))
	if frames.size() > keep:
		frames.resize(keep)
	_lock.unlock()


func _frames_reset() -> void:
	frames = []
	_k = 0
	_ck = []
	parcels = []
	ripples = []
	splashes = []
	breaks = []
	pieces = []
	_piece_at = {}
	_runs_seen = (work.runs as Array).duplicate(true)
	_chan_seen = work._chan
	_woke = PackedInt32Array()
	_rank_of.resize(rigid.bodies.size())
	_rank_of.fill(-1)
	_checkpoint()


func _checkpoint() -> void:
	var liq: Array = []
	for s in _liq:
		liq.append((s as Dictionary).duplicate(true))
	_ck.append({"k": _k, "sim": sim.snapshot(), "liq": liq, "np": parcels.size(), "nr": ripples.size(), "ns": splashes.size(), "npc": pieces.size(),
		"sprinkled": _sprinkles.map(func(s: Dictionary) -> int: return int(s.get("done", 0))),
		"sprinkled_ids": _sprinkles.map(func(s: Dictionary) -> PackedInt32Array: return (grains[int(s["grains"])] as Dictionary)["ids"]),
		"held": _held.duplicate(true), "loose": loose.map(func(L: Dictionary) -> Array: return [L["body"], L["n0"], L["full"], L.get("rest"),
			L.get("rest_host", -1), L.get("rest_hrel"), L["box"], L.get("calm", 0.0), L.get("rest_hxf"), L.get("rest_up"), L.get("mass", 0.0), L.get("rest_off")]),
		"swing": _swing.map(func(s: Dictionary) -> Array: return [s["a"], s["w"], s["rest"], s["still"], s["sig"], s.get("b1"), s.get("b2")]),
		"rigid": rigid.snapshot(), "body_solids": _body_solids(), "woke": _woke.size()})
	if _ck.size() > CHECKS_KEPT + 1:
		# THINNED: of all but the first and the latest few, the one whose going leaves the shortest gap goes, the older on a tie
		var drop := 1
		var least := 1 << 62
		for i in range(1, _ck.size() - CHECKS_NEAR):
			var gap := int((_ck[i + 1] as Dictionary)["k"]) - int((_ck[i - 1] as Dictionary)["k"])
			if gap < least:
				least = gap
				drop = i
		_ck.remove_at(drop)


## Each rigid body's solids as they stand: solid -> [xf, xf0, xf00, moving, jolt, stirs, presses] ([method _restore]).
func _body_solids() -> Dictionary:
	var out := {}
	for si in solids.size():
		var d: Dictionary = solids[si]
		if d.has("body"):
			out[si] = [d["xf"], d["xf0"], d["xf00"], d["moving"], d["jolt"], d.get("stirs", false), d.get("presses", false)]
	return out


func _restore(ck: Dictionary) -> void:
	_k = int(ck["k"])
	sim.restore(ck["sim"])
	# ...each swinging hinge as it was, before its solids are put where it had them
	var sw: Array = ck.get("swing", [])
	for k in mini(sw.size(), _swing.size()):
		var s: Dictionary = _swing[k]
		var was: Array = sw[k]
		s["a"] = was[0]
		s["w"] = was[1]
		s["rest"] = was[2]
		s["still"] = was[3]
		s["sig"] = was[4]
		s["b1"] = was[5]
		s["b2"] = was[6]
		s["moved"] = false
		twin.swung[int(s["wi"])] = rad_to_deg(float(s["a"]))
	# ...and each rigid body where it was, and the bodies woken by then the only ones a frame keeps
	rigid.restore(ck.get("rigid", []))
	var nw := mini(int(ck.get("woke", 0)), _woke.size())
	for j in range(nw, _woke.size()):
		_rank_of[_woke[j]] = -1
	_woke.resize(nw)
	_posed_now()
	_liq = []
	for s in ck["liq"]:
		_liq.append((s as Dictionary).duplicate(true))
	var t := _t_of(_k)
	parcels = parcels.filter(func(p: Dictionary) -> bool: return float(p["t0"]) < t)
	for p in parcels:
		if float((p as Dictionary)["t1"]) >= t:
			(p as Dictionary)["t1"] = INF
			(p as Dictionary)["into"] = -2
	ripples = ripples.filter(func(r: Dictionary) -> bool: return float(r["t"]) < t)
	splashes = splashes.filter(func(s: Dictionary) -> bool: return float(s["t"]) < t)
	_lock.lock()
	breaks = breaks.filter(func(b: Dictionary) -> bool: return float(b["t"]) < t)
	_lock.unlock()
	pieces = pieces.slice(0, int(ck.get("npc", 0)))
	_piece_at = {}
	for k in pieces.size():
		_piece_at[int((pieces[k] as Dictionary)["body"])] = k
	var done: Array = ck["sprinkled"]
	var done_ids: Array = ck.get("sprinkled_ids", [])
	for i in _sprinkles.size():
		(_sprinkles[i] as Dictionary)["done"] = int(done[i]) if i < done.size() else 0
		# ...and the grains each had let fall by then, which the solver's own were restored to
		if i < done_ids.size():
			(grains[int((_sprinkles[i] as Dictionary)["grains"])] as Dictionary)["ids"] = done_ids[i]
	# WHERE THE WORK HELD EACH LOOSE THING FROM, as it was: begun again, a carry under way had been held from where the
	# thing was at the checkpoint
	_held = (ck.get("held", {}) as Dictionary).duplicate(true)
	# ...and which loose things were bodies by then, each from where it became one
	var lb: Array = ck.get("loose", [])
	for li in loose.size():
		var L: Dictionary = loose[li]
		var was: Array = lb[li] if li < lb.size() else [-1, L["built"], false]
		L["body"] = int(was[0])
		L["n0"] = was[1]
		L["full"] = bool(was[2])
		if was.size() > 10:
			L["rest"] = was[3]
			L["rest_host"] = was[4]
			L["rest_hrel"] = was[5]
			L["box"] = was[6]
			L["calm"] = was[7]
			L["rest_hxf"] = was[8]
			L["rest_up"] = was[9]
			L["mass"] = was[10]
		L["rest_off"] = was[11] if was.size() > 11 else null
	_lying_cells()
	_ck = _ck.filter(func(c: Dictionary) -> bool: return int(c["k"]) <= _k)
	# THE SOLIDS WHERE THEY WERE two frames and one before - the next frame moves them on to this one, as a bake from the
	# start would have - and what each is to meet there (a solid at rest is never reckoned again until it moves)
	# ...A BODY'S OWN as they were, and the two frames before: begun again with them standing still, what rode a carried jar
	# was carried on otherwise than a bake from the start carries it, and its snow fell elsewhere
	var kept: Dictionary = ck.get("body_solids", {})
	for si in solids.size():
		var d: Dictionary = solids[si]
		if d.has("body"):
			var bx := rigid.motion(int(d["body"])) * (d["rest"] as Transform3D)
			var was: Array = kept.get(si, [bx, bx, bx, false, 0.0, false, false])
			d["xf"] = was[0]
			d["xf0"] = was[1]
			d["xf00"] = was[2]
			d["inv"] = (d["xf"] as Transform3D).affine_inverse()
			d["wbox"] = ((d["xf"] as Transform3D) * (d["box"] as AABB)).grow(0.001)
			d["moving"] = was[3]
			d["jolt"] = was[4]
			d["stirs"] = was[5]
			d["presses"] = was[6]
			d["on"] = _shown(d, t)
			continue
		d["xf0"] = _pose_owner(d, maxf(t - 2.0 / float(FPS), _t0)) * (d["local"] as Transform3D)
		d["xf"] = _pose_owner(d, maxf(t - 1.0 / float(FPS), _t0)) * (d["local"] as Transform3D)
		d["xf00"] = d["xf0"]
		d["inv"] = (d["xf"] as Transform3D).affine_inverse()
		d["wbox"] = ((d["xf"] as Transform3D) * (d["box"] as AABB)).grow(0.001)
		d["moving"] = false
		d["jolt"] = 0.0
		d["on"] = _shown(d, t)
	_clear_at = t


## A BAKE FROM A TABLE STOOD BEFORE ([method carry]), taken up as far as it was baked on the plan just taken - the
## checkpoint before the first moment the two differ - or false, the bake begun as it would be: its table not this one,
## or nothing of it before that moment.
func _take_carried(c: Dictionary) -> bool:
	if int(c["layout"]) != _layout or not is_equal_approx(float(c.get("t0", 0.0)), _t0):
		return false
	var upto := minf(_changed_at(c["plan"], _plan_of()) - CARRY_MARGIN, _t_of(int(c["k"])))
	var ck: Dictionary = {}
	for x in c["ck"]:
		var xd: Dictionary = x
		if _t_of(int(xd["k"])) <= upto and (ck.is_empty() or int(xd["k"]) > int(ck["k"])):
			ck = xd
	if ck.is_empty() or int(ck["k"]) <= _k:
		return false
	_lock.lock()
	frames = (c["frames"] as Array).slice(0, int(ck["k"]))
	_lock.unlock()
	# ...the bodies in the order they woke there, which its frames are kept by ([method _record])
	_woke = (c.get("woke", PackedInt32Array()) as PackedInt32Array).duplicate()
	_rank_of.fill(-1)
	for j in _woke.size():
		_rank_of[_woke[j]] = j
	parcels = c["parcels"]
	ripples = c["ripples"]
	splashes = c["splashes"]
	breaks = c.get("breaks", [])
	pieces = c.get("pieces", [])
	_ck = (c["ck"] as Array).duplicate()
	_restore(ck)
	return true


## WHAT THIS BAKE HAS MADE, for a table stood again over the same table ([method adopt]; [TablePreview]): its frames,
## checkpoints and what fell, the plan it was baked on, and what it is made of - or what it was handed itself and has
## not yet taken up.
func carry() -> Dictionary:
	if _carried != null:
		return _carried
	_lock.lock()
	var out := {"layout": _layout, "t0": _t0, "k": _k, "frames": frames.slice(0, _k), "ck": _ck.duplicate(), "woke": _woke.duplicate(), "parcels": parcels.duplicate(),
		"ripples": ripples.duplicate(), "splashes": splashes.duplicate(), "breaks": breaks.duplicate(), "pieces": pieces.duplicate(), "plan": _plan_of()}
	_lock.unlock()
	return out


## A bake [param c] another table made ([method carry]), taken up with the first plan as far as the plans agree.
func adopt(c: Dictionary) -> void:
	_carried = c


## A BAKE GIVEN UP: [method bake_until] stops, and what is asked after is as far as it got - for a preview given back
## while it baked on a worker.
func halt() -> void:
	_halt = true


## THE PLAN THE TWIN HOLDS, as the bake reads it: each channel's entries in order - where each begins, and a hash of all
## it holds (its track, stretch, ends, slopes) - each sprinkle's the same, and what every act together decides from the
## start (what is moved and what is soft: a part an act will move rides its thing no longer, [method TableWork._work_world]).
func _plan_of() -> Dictionary:
	var chan := {}
	for ch in twin._chan:
		var list: Array = []
		for e in twin._chan[ch]:
			var d: Dictionary = (e as Dictionary).duplicate()
			d.erase("i")
			list.append([float(d["s0"]), hash(d)])
		chan[ch] = list
	var sprinkled: Array = []
	for s in _sprinkles:
		var sp := _sprinkle_span(s)
		sprinkled.append([sp.x, hash([(s as Dictionary)["track"], sp])])
	# ...and nothing the acts decide for the whole show: what they move is in their channels, and the world is the table's, never
	# the acts' ([method _goes]) - what is soft the work's clearance reads (a heap a pestle goes into), never the bake
	return {"chan": chan, "sprinkles": sprinkled, "all": 0}


## The first moment two plans ([method _plan_of]) differ - 0 when they differ from the start, INF when never.
static func _changed_at(a: Dictionary, b: Dictionary) -> float:
	if int(a["all"]) != int(b["all"]):
		return 0.0
	var at := _first_unlike(a["sprinkles"], b["sprinkles"])
	var chans := {}
	for ch in a["chan"]:
		chans[ch] = true
	for ch in b["chan"]:
		chans[ch] = true
	for ch in chans:
		at = minf(at, _first_unlike((a["chan"] as Dictionary).get(ch, []), (b["chan"] as Dictionary).get(ch, [])))
	return at


## Where two lists of `[begins, hash]` first part: the earlier beginning of the first pair unlike, or INF.
static func _first_unlike(x: Array, y: Array) -> float:
	for j in maxi(x.size(), y.size()):
		if j < x.size() and j < y.size() and x[j] == y[j]:
			continue
		var t := INF
		if j < x.size():
			t = minf(t, float((x[j] as Array)[0]))
		if j < y.size():
			t = minf(t, float((y[j] as Array)[0]))
		return t
	return INF


## WHAT THIS TABLE'S PHYSICS IS MADE OF, as a number: its solids, liquids, grains, loose things and sprinkles as built, the
## solver as it stands, and what the work's channels rest at and run by. Two tables alike in it bake alike under one plan
## - and no node or object is in it, whose hash would be its own.
func _layout_of() -> int:
	var sol: Array = []
	for sd in solids:
		var d: Dictionary = sd
		sol.append([d["part"], d["box"], d["rest"], d["local"], d["thing"], d["wi"], d["owner"], d["oi"]])
	var liq: Array = []
	for L in liquids:
		var d: Dictionary = L
		liq.append([d["solid"], d["wi"], d["name"], d["thing"], d["full_v"], d["built_v"], d["made"], d["plugs"], d["v0"]])
	var gr: Array = []
	for g in grains:
		var d: Dictionary = g
		gr.append([d["name"], d["thing"], d["wi"], d["ids"], d.get("radius", 0.0), d["solid"]])
	var lo: Array = []
	for L in loose:
		var d: Dictionary = L
		lo.append([d["wi"], d["thing"], d["body"], d["n0"], d["rad"]])
	var spr: Array = []
	for s in _sprinkles:
		spr.append((s as Dictionary)["track"])
	return hash([sol, liq, gr, lo, spr, sim.snapshot(), sim.matter, _liq, twin._rest, twin._runs_of, twin._spot, twin.since, FPS,
		_rigid_of.keys(), _swing_at.keys()])


# --- the bake ---------------------------------------------------------------------------------------------

## THE BAKE'S THREAD: frames as far ahead of the picture as [member _want], the plan taken up as it comes.
func _run() -> void:
	while true:
		_sem.wait()
		if _quit:
			return
		while not _quit:
			_take_plan()
			_lock.lock()
			var want := _want
			_lock.unlock()
			if _t_of(_k) > want:
				break
			_bake_frame()


## Baked on the caller's thread through show time [param t] (a render, a gate - and a preview, on a worker of its own
## while the app's thread waits: [method TablePreview._bake]) - or as far as it got when [method halt]ed.
func bake_until(t: float, breathe := false) -> void:
	_take_plan()
	var last := int(ceil((maxf(t, _t0) - _t0) * float(FPS)))
	while _k <= last and not _halt:
		_bake_frame()
		# ...and on a worker, a moment given up a frame, as a table built aside breathes ([method TableMedium._breathe])
		if breathe:
			OS.delay_usec(0)


func _bake_frame() -> void:
	var f := _frame(_k)
	_lock.lock()
	if _k < frames.size():
		frames[_k] = f
	else:
		frames.append(f)
	_lock.unlock()
	_k += 1
	if _k % CHECK_EVERY == 0:
		_checkpoint()


## FRAME [param k]: the solids where the plan has them, the liquids, what is held, a step of the grains and loose things,
## and what it all comes to - or, when nothing moves and nothing is moving, the frame before.
func _frame(k: int) -> Dictionary:
	var t := _t_of(k)
	var dt := 1.0 / float(FPS)
	var busy := _flowing()
	for i in sim.n:
		if sim.alive[i] == 1 and sim.asleep[i] == 0:
			busy = true
			break
	for s in _liq:
		if (s as Dictionary)["d"] != Vector2.ZERO or absf(float((s as Dictionary)["swirl"])) > 0.005:
			busy = true
		# ...and a stream's landing dying away: kept by a quiet frame, its last bubbles went on to the end of the show
		if ((s as Dictionary)["hit"] as Vector4).w > 0.0:
			busy = true
		# ...and its surface still moving
		if bool(((s as Dictionary)["w"] as Dictionary)["on"]):
			busy = true
	busy = busy or _sprinkling(t) or _liquid_fills(t) or _swinging() or rigid.busy() or _rings_boiling(t)
	if profiling:
		_why(t)
	# NOTHING MOVES AND NOTHING IS MOVING: the frame before, with nothing reckoned
	if not busy and not _may_move(t) and k > 0 and k - 1 < frames.size():
		return frames[k - 1]
	var c0 := Time.get_ticks_usec() if profiling else 0
	# ...what swings by its weight first: where it has swung to is where its solids are
	_swings_step(t, dt)
	busy = _solids_at(t) or busy
	_spent("solids", c0)
	# ...or what the work holds of the loose things and of the parts it picks up: carried, it moves though nothing else does
	if not busy:
		for L in loose:
			if _held_at(int((L as Dictionary)["wi"]), t):
				busy = true
				break
	if not busy:
		for b in rigid.bodies:
			if _held_at(int((b as Dictionary)["wi"]), t):
				busy = true
				break
	if not busy and k > 0 and k - 1 < frames.size():
		return frames[k - 1]
	# ...and what the work picks up, held or let go, among the solids where they are now
	var c := Time.get_ticks_usec() if profiling else 0
	if not rigid.bodies.is_empty():
		_rigid_step(t, dt)
	c = _spent("rigid", c)
	_parcels_step(t, dt)
	c = _spent("parcels", c)
	var world := _liquids_step(t, dt)
	c = _spent("liquids", c)
	_wake_near_loose(t)
	_held_step(t, dt)
	_sprinkle_step(t, dt)
	c = _spent("held", c)
	sim.step(dt, world)
	c = _spent("particles", c)
	_events(t)
	_rest_loose(dt)
	c = _spent("events", c)
	var rec := _record(t)
	_spent("record", c)
	return rec


## WHY A FRAME IS STEPPED, counted by each reason that holds ([member profiling]).
func _why(t: float) -> void:
	var why := PackedStringArray()
	for i in sim.n:
		if sim.alive[i] == 1 and sim.asleep[i] == 0:
			why.append("grain or loose awake")
			break
	for s in _liq:
		if (s as Dictionary)["d"] != Vector2.ZERO or absf(float((s as Dictionary)["swirl"])) > 0.005:
			why.append("liquid sloshing")
		if ((s as Dictionary)["hit"] as Vector4).w > 0.0:
			why.append("stream landing")
		if bool(((s as Dictionary)["w"] as Dictionary)["on"]):
			why.append("surface waves")
	if _flowing():
		why.append("stream falling")
	if _sprinkling(t):
		why.append("sprinkling")
	if _liquid_fills(t):
		why.append("liquid filling")
	if _swinging():
		why.append("swinging")
	if rigid.busy():
		why.append("rigid busy")
	if _rings_boiling(t):
		why.append("boiling")
	if _may_move(t):
		why.append("an act may move")
	for w in why:
		profile["why: " + w] = int(profile.get("why: " + w, 0)) + 1
	profile["frames asked"] = int(profile.get("frames asked", 0)) + 1


## A FRAME'S COST BY WHAT TOOK IT, while [member profiling] (a probe's): microseconds by section, and the frames stepped.
func _spent(section: String, since: int) -> int:
	if not profiling:
		return 0
	var now := Time.get_ticks_usec()
	profile[section] = int(profile.get(section, 0)) + now - since
	return now


## Whether a stream is still falling.
func _flowing() -> bool:
	for i in range(_recent(_t_of(_k)), parcels.size()):
		if float((parcels[i] as Dictionary)["t1"]) == INF:
			return true
	return false


## The first of the parcels that may still be falling at [param t]: made no longer ago than one lives. They are made in
## the order of their time, so the ones before it are all done - of a whole show's (a pot lapping over its own rim makes
## thousands), only the last few are looked at.
func _recent(t: float) -> int:
	var i := parcels.size()
	while i > 0 and float((parcels[i - 1] as Dictionary)["t0"]) >= t - PARCEL_LIFE - 0.1:
		i -= 1
	return i


## Whether anything on the table may move at [param t]: within a stretch of any act that carries, turns or takes away a
## thing or a part (or a frame either side of one) - or while a hinge swings.
func _may_move(t: float) -> bool:
	if _swinging() or rigid.busy():
		return true
	if _spans == null:
		var all: Array = []
		for ch in twin._chan:
			var c := String(ch)
			if not (c.ends_with(":pose") or c.ends_with(":shown") or c.ends_with(":angle") or c.ends_with(":offset")):
				continue
			for e in twin._chan[ch]:
				all.append(Vector2(float((e as Dictionary)["s0"]) - 0.1, float((e as Dictionary)["s1"]) + 0.1))
		all.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
		var merged: Array = []
		for v in all:
			if not merged.is_empty() and (v as Vector2).x <= (merged.back() as Vector2).y:
				merged[merged.size() - 1] = Vector2((merged.back() as Vector2).x, maxf((merged.back() as Vector2).y, (v as Vector2).y))
			else:
				merged.append(v)
		_spans = merged
	for v in _spans:
		if t < (v as Vector2).x:
			return false
		if t <= (v as Vector2).y:
			return true
	return false


## EACH SOLID WHERE THE PLAN HAS IT at [param t]: whether any moved.
func _solids_at(t: float) -> bool:
	var any := false
	var dt := 1.0 / float(FPS)
	for sd in solids:
		var d: Dictionary = sd
		# A RIGID BODY'S OWN are where it is ([method _rigid_step])
		if d.has("body"):
			d["on"] = _shown(d, t)
			continue
		var key := ("t%d" if String(d["owner"]) == "t" else "w%d") % int(d["oi"])
		var pose: Transform3D
		if _moves_at(key, d, t):
			pose = _cached_pose(key, d, t)
		else:
			pose = _cached_pose(key, d, NAN)
		var xf := pose * (d["local"] as Transform3D)
		d["xf00"] = d["xf0"]
		d["xf0"] = d["xf"]
		d["xf"] = xf
		var moved := not (xf as Transform3D).is_equal_approx(d["xf0"])
		d["moving"] = moved
		d["dt"] = dt
		if moved or not (d["xf0"] as Transform3D).is_equal_approx(d["xf00"]):
			d["inv"] = xf.affine_inverse()
			d["wbox"] = (xf * (d["box"] as AABB)).grow(0.001)
			var a := (xf.origin - 2.0 * (d["xf0"] as Transform3D).origin + (d["xf00"] as Transform3D).origin) / (dt * dt)
			d["jolt"] = Particles.jolt_of(a)
		else:
			d["jolt"] = 0.0
		d["on"] = _shown(d, t)
		any = any or moved
	return any


## Whether solid [param d] is there to meet at [param t]: a part a work takes away (a stopper drawn out) is not, AND NEITHER IS ONE
## NOT YET BROUGHT, WHATEVER HAS BEEN HEARD OF THE ACT THAT BRINGS IT - no act on it yet is what it started as, never "there"
## (841899, feedback 0013: a vial's cork, `shown` 0 until the act after the pour, stood unseen in the vial's neck whenever that act's
## words had not reached a live plan, and all 27 ml of the ladle's pour stopped on it; the whole plan baked at once had filled the vial).
func _shown(d: Dictionary, t: float) -> bool:
	var ch := String(d["shown_ch"])
	return ch.is_empty() or float(twin.value(ch, t)) > 0.5


## Whether the node [param key] may move at [param t]: within a stretch of its own channels' - its pose, its joint's - or
## those of each part it is a part of, or its thing's; or as a hinge it hangs from swings. (Its own pose and its thing's
## alone had been asked: a beam turned on its hinge, and its pan with it, stood still in the physics.)
func _moves_at(key: String, d: Dictionary, t: float) -> bool:
	for k in d.get("swings", []):
		if bool((_swing[int(k)] as Dictionary)["moved"]):
			return true
	for k in d.get("bodies", []):
		if bool((rigid.bodies[int(k)] as Dictionary)["moved"]):
			return true
	if not _intervals.has(key):
		var chs: Array = []
		if String(d["owner"]) == "t":
			chs = ["t%d:pose" % int(d["oi"])]
		else:
			var c := int(d["oi"])
			while c >= 0:
				chs.append_array(["w%d:pose" % c, "w%d:angle" % c, "w%d:offset" % c, "g%d:pose" % int(twin._group_of.get(c, -1))])
				c = int(twin._parent_work.get(c, -1))
			chs.append("t%d:pose" % int((twin.works[int(d["oi"])] as Dictionary)["thing"]))
		var spans: Array = []
		for ch in chs:
			for e in twin._chan.get(ch, []):
				spans.append(Vector2(float((e as Dictionary)["s0"]) - 0.05, float((e as Dictionary)["s1"]) + 0.05))
		_intervals[key] = spans
	for s in _intervals[key]:
		if t >= (s as Vector2).x and t <= (s as Vector2).y:
			return true
	return false


func _cached_pose(key: String, d: Dictionary, t: float) -> Transform3D:
	if is_nan(t):
		if _owner_pose.has(key):
			return (_owner_pose[key] as Array)[1]
		t = _t_of(_k)
	var p := _pose_owner(d, t)
	_owner_pose[key] = [t, p]
	return p


## THE LIQUIDS a frame on: their levels, sloshes, swirls and what pours over their rims - and the world the grains meet.
func _liquids_step(t: float, dt: float) -> Dictionary:
	var lw: Array = []
	var cw := Time.get_ticks_usec() if profiling else 0
	_wet_ids = _wet_now()
	_spent("liquid: wet", cw)
	for li in liquids.size():
		var L: Dictionary = liquids[li]
		var S: Dictionary = _liq[li]
		var sd: Dictionary = solids[int(L["solid"])]
		var vs: Vessel = L["vessel"]
		var xf: Transform3D = sd["xf"]
		var binv := xf.basis.inverse()
		var scale := absf(xf.basis.determinant())
		# WHAT THE WORK FILLS OR EMPTIES IT BY, as if by magic (a `to` on its fill)
		var wi := int(L["wi"])
		if wi >= 0 and twin._chan.has("w%d:fill" % wi):
			var f := float(twin.value("w%d:fill" % wi, t))
			if float(S["f"]) >= 0.0:
				S["v"] = float(S["v"]) + (f - float(S["f"])) * float(L["built_v"])
			S["f"] = f
		S["v"] = clampf(float(S["v"]), 0.0, float(L["full_v"]))
		# ...AND ITS COLOR AS THE WORK TINTS IT: what is poured or dipped out of it carries the color it is now
		if wi >= 0 and twin._chan.has("w%d:tint" % wi):
			var tint: Variant = twin.value("w%d:tint" % wi, t)
			if tint is Color:
				S["color"] = tint
		# AN EMPTY ONE, at rest: nothing in it to level, slosh, turn or pour - only where it is (of a table's two dozen
		# insides most are empty, and their surfaces had been most of a frame)
		if float(S["v"]) <= 1e-10 and (S["d"] as Vector2) == Vector2.ZERO and (S["dd"] as Vector2) == Vector2.ZERO:
			S["c1"] = Vector3.INF
			S["c2"] = Vector3.INF
			S["q"] = 0.0
			S["swirl"] = 0.0
			S["n"] = Vector3.UP
			S["c"] = xf.origin
			if bool((S["w"] as Dictionary)["on"]):
				S["w"] = (L["waves"] as SurfaceWaves).fresh()
			lw.append({"vessel": vs, "xf": xf, "inv": sd["inv"], "n": Vector3.UP, "c": xf.origin, "axis": xf.origin, "swirl": 0.0,
				"volume": 0.0, "solid": int(L["solid"])})
			continue
		# A LIQUID AT REST STAYS AT REST: its vessel still, its surface level, calm and unwaved, nothing pouring from it, filling it
		# or ringing it, nothing moving or awake in it - its last frame's answer, nothing reckoned. (Of 841899's twelve liquids most
		# stood in bottles nobody touched, and reckoning them was 4.6 ms of every frame the bake stepped, next/framework_audit.md.)
		if _calm(li, t):
			lw.append(S["lw"])
			continue
		var cl := Time.get_ticks_usec() if profiling else 0
		var up := (binv * Vector3.UP).normalized()
		var s := _level_of(li, up, xf, scale)
		cl = _spent("liquid: level", cl)
		var c_l := vs.surface_middle(up, s)
		var c_w := xf * c_l
		# SLOSH: the surface's tilt, a damped oscillator at its first mode driven by how its middle is pushed about
		var c1: Vector3 = S["c1"]
		var c2: Vector3 = S["c2"]
		var a := Vector3.ZERO
		if c1 != Vector3.INF and c2 != Vector3.INF:
			a = (c_w - 2.0 * c1 + c2) / (dt * dt)
		S["c2"] = c1
		S["c1"] = c_w
		var R := maxf(vs.surface_radius(up, s) * pow(scale, 1.0 / 3.0), 0.003)
		var hd := maxf(vs.depth(up, s) * pow(scale, 1.0 / 3.0), 0.001)
		var w0 := sqrt(GRAVITY * XI / R * tanh(XI * hd / R))
		var d: Vector2 = S["d"]
		var dd: Vector2 = S["dd"]
		var drive := Vector2(a.x, a.z) / GRAVITY
		for sub in 2:
			var h := dt * 0.5
			var acc := -2.0 * SLOSH_DAMP * w0 * dd - w0 * w0 * (d - drive)
			dd += acc * h
			d += dd * h
		d = d.limit_length(0.35)
		# ...AND A VESSEL WITH PART OF ITS RIM UNDER A LIQUID HAS THAT LIQUID'S SURFACE ([method _dips]): nothing of its own to slosh
		if (d.length() < 1e-5 and dd.length() < 1e-4) or int(S["dipped"]) >= 0:
			d = Vector2.ZERO
			dd = Vector2.ZERO
		S["d"] = d
		S["dd"] = dd
		var n_w := (Vector3.UP + Vector3(d.x, 0.0, d.y)).normalized()
		cl = _spent("liquid: slosh", cl)
		# A TOOL IN IT TURNS IT
		for sj in solids.size():
			var o: Dictionary = solids[sj]
			if not bool(o["moving"]) or sj == int(L["solid"]) or float(S["v"]) <= 1e-9:
				continue
			var ob: AABB = o["wbox"]
			var q := Vector3(ob.get_center().x, ob.position.y + minf(ob.size.y * 0.15, 0.01), ob.get_center().z)
			if (q - c_w).dot(n_w) > 0.0 or not vs.contains(sd["inv"] * q):
				continue
			var q0 := ((o["xf0"] as Transform3D) * (o["inv"] as Transform3D)) * q
			var vq := (q - q0) / dt
			var rel := Vector3(q.x - c_w.x, 0.0, q.z - c_w.z)
			if rel.length() > 0.002:
				# ...AS A VORTEX ABOUT WHERE IT GOES ([member Particles] `core`): turned as one about the axis by a tool at the middle's speed over its nearness to the axis, a whole surface
				# went round at 4 radians a second, and what floated at its edge at half a meter a second (841899, feedback 0012: a "whiplash effect")
				var core := maxf(rel.length(), R * SWIRL_CORE)
				var target := rel.cross(vq).y / (core * core)
				S["swirl"] = lerpf(float(S["swirl"]), target, minf(1.0, SWIRL_PULL * dt))
				S["core"] = lerpf(float(S["core"]), core, minf(1.0, SWIRL_PULL * dt))
		S["swirl"] = float(S["swirl"]) * exp(-dt / SWIRL_LIFE)
		S["angle"] = float(S["angle"]) + float(S["swirl"]) * dt
		cl = _spent("liquid: swirl", cl)
		# OVER THE RIM where it stands above it - unless something stoppers it
		var sealed := false
		for pj in L["plugs"]:
			sealed = sealed or bool((solids[int(pj)] as Dictionary)["on"])
		S["q"] = 0.0
		if not sealed and float(S["v"]) > 1e-10 and int(S["dipped"]) < 0:
			var n_l := (binv * n_w).normalized()
			var of := vs.overflow(n_l, c_l.dot(n_l))
			var q := float(of["q"]) * scale
			var out := minf(q * dt, float(S["v"]))
			var k := int(of["at"])
			var lip := xf * vs.lip[k] if k >= 0 else xf.origin
			# ...UNLESS ITS LIP IS UNDER ANOTHER LIQUID: sunk in it, it is that liquid, full, and nothing pours (a ladle stood in
			# its pot had poured sixty parcels a second out of its lip at the pot's floor, every one back into the pot)
			if out > 1e-12 and _under_liquid(lip, li) < 0:
				S["v"] = float(S["v"]) - out
				S["q"] = out / dt
				var way := (xf.basis * (vs.lip[k] - vs.rim[k])).normalized()
				way = Vector3(way.x, minf(way.y, 0.0), way.z).normalized()
				var head := maxf(float(of["head"]), 0.0) * pow(scale, 1.0 / 3.0)
				var carried := (lip - ((sd["xf0"] as Transform3D) * vs.lip[k])) / dt
				parcels.append({"t0": t, "p": lip, "v": way * sqrt(GRAVITY * head * 0.667) + carried, "vol": out, "from": li, "t1": INF,
					"into": -2, "color": S["color"]})
		cl = _spent("liquid: rim", cl)
		# ITS SURFACE MOVED by what crosses it ([SurfaceWaves])
		_waves_step(li, binv * Vector3.UP, s, dt, t)
		cl = _spent("liquid: waves", cl)
		S["lw"] = {"agit": _agitation(li, t, float(S["swirl"])), "flow": L["flow"], "t": t, "core": float(S["core"]), "vessel": vs, "xf": xf, "inv": sd["inv"], "n": n_w, "c": c_w, "axis": c_w, "swirl": S["swirl"], "volume": S["v"],
			"solid": int(L["solid"]), "waves": L["waves"], "w": S["w"], "dip": _dip(li), "r2": R * R * 0.5}
		lw.append(S["lw"])
		S["r2"] = R * R * 0.5
		S["n"] = n_w
		S["c"] = c_w
		# A SURFACE UNDER ANOTHER LIQUID'S IS NONE: a ladle's bowl under the brew is the brew there, and its own surface, drawn
		# under the brew's, showed through it as a second, broken one (841899, at the ladle's spoon: "weird glitching artifacts
		# in the water")
		var over := _under_liquid(c_w + Vector3.UP * 0.001, li)
		S["sunk"] = over >= 0 and float((liquids[over] as Dictionary)["full_v"]) > float(L["full_v"])
		_spent("liquid: sunk", cl)
	var cd := Time.get_ticks_usec() if profiling else 0
	_dips(dt)
	_spent("liquid: dips", cd)
	var vessels: Array = []
	for L in liquids:
		vessels.append({"solid": int((L as Dictionary)["solid"]), "vessel": (L as Dictionary)["vessel"]})
	return {"solids": solids, "liquids": lw, "top": 0.0, "vessels": vessels}


## HOW LIQUID [param li] STIRS AT [param t], its boil and its swirl, 0 to 1 ([method Particles.current]) - never still: the least [constant AGITATION_LEAST], what the air and a table do.
func _agitation(li: int, t: float, swirl: float) -> float:
	var wi := int((liquids[li] as Dictionary)["wi"])
	var boil := 0.0
	if wi >= 0:
		var ch := "w%d:boil" % wi
		if twin._chan.has(ch) or float(twin._rest.get(ch, 0.0)) > 0.0:
			boil = float(twin.value(ch, t))
	return clampf(AGITATION_LEAST + (1.0 - AGITATION_LEAST) * sqrt(Boil.share(boil)) + absf(swirl) * AGITATION_SWIRL, 0.0, 1.0)


## HOW LIQUID IN SOLID [param si] MOVES, drawn once from where it stands ([method Particles.current]): `[kx, kz, phase, speed]` for each of two current's waves and two swell's -
## each as long as the vessel's own size makes it, so a vial's and a cauldron's are their own, a current's coming round in half a minute and a swell's in about two seconds.
func _flow_of(si: int, vs: Vessel, scale: float) -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(["liquid flow", si])
	var wide := maxf(sqrt(vs.volume * scale / (PI * maxf((vs.top_y - vs.floor_y) * pow(scale, 1.0 / 3.0), 1e-4))), 0.005)
	var out := PackedFloat32Array()
	for m in 4:
		var long := wide * rng.randf_range(2.2, 3.6) if m < 2 else wide * rng.randf_range(1.6, 2.6)
		var a := rng.randf_range(0.0, TAU)
		var k := TAU / long
		var period := rng.randf_range(24.0, 38.0) if m < 2 else rng.randf_range(1.7, 2.8)
		out.append_array([cos(a) * k, sin(a) * k, rng.randf_range(0.0, TAU), TAU / period * (1.0 if rng.randf() < 0.5 else -1.0)])
	return out


## WHETHER LIQUID [param li] IS AT REST at [param t] ([method _liquids_step]): it has been reckoned before; its vessel has not moved
## these two frames; its surface is level and calm (no slosh, no swirl, no wave) and nothing pours from it, lands in it or rings it
## boiling; the work fills it by no `to` now; and nothing moving stands in its vessel's room, nor anything awake in it.
func _calm(li: int, t: float) -> bool:
	var S: Dictionary = _liq[li]
	var L: Dictionary = liquids[li]
	# ...and holds what it held when it was last reckoned: a ladle held still under its surface fills from it, and its level falls
	if not S.has("lw") or float(S["v"]) <= 1e-10 or not is_equal_approx(float(S["v"]), float((S["lw"] as Dictionary)["volume"])):
		return false
	var si := int(L["solid"])
	var sd: Dictionary = solids[si]
	if bool(sd["moving"]) or not (sd["xf"] as Transform3D).is_equal_approx(sd["xf0"]) or not (sd["xf0"] as Transform3D).is_equal_approx(sd["xf00"]):
		return false
	if (S["d"] as Vector2) != Vector2.ZERO or (S["dd"] as Vector2) != Vector2.ZERO or absf(float(S["swirl"])) > 1e-4 \
			or float(S["q"]) > 0.0 or bool((S["w"] as Dictionary)["on"]) or ((S["hit"] as Vector4).w > 0.0):
		return false
	var wi := int(L["wi"])
	if wi >= 0:
		for e in twin._chan.get("w%d:fill" % wi, []):
			if t >= float((e as Dictionary)["s0"]) - 0.05 and t <= float((e as Dictionary)["s1"]) + 0.05:
				return false
		var ch := "w%d:boil" % wi
		if (twin._chan.has(ch) or float(twin._rest.get(ch, 0.0)) > 0.0) and Boil.radii(float(twin.value(ch, t))).y >= BUBBLE_RINGS:
			return false
	# ...NOTHING COMES TO IT: no moving solid in its vessel's room, nothing awake in it
	var room: AABB = (sd["wbox"] as AABB).grow(0.01)
	for o in solids:
		if bool((o as Dictionary)["moving"]) and ((o as Dictionary)["wbox"] as AABB).intersects(room) and o != sd:
			return false
	var wet: Variant = _wet_ids.get(li) if _wet_ids is Dictionary else null
	if wet is PackedInt32Array:
		for i in (wet as PackedInt32Array):
			if i < sim.n and sim.asleep[i] == 0:
				return false
	for i in range(_recent(t), parcels.size()):
		if float((parcels[i] as Dictionary)["t1"]) == INF:
			var pp: Vector3 = _parcel_at(parcels[i], t - float((parcels[i] as Dictionary)["t0"]))
			if room.grow(0.05).has_point(pp):
				return false
	return true


## LIQUID [param li]'s LEVEL along [param up] (its vessel's own space, posed [param xf], [param scale] its volume's): the
## surface that leaves under it the liquid AND WHAT STANDS IN IT - each body's own matter, each vessel's whole inside whether
## it is full or not (what is in it is in the column, and the air in it holds the liquid out), the loose things' and the
## grains' spheres - less what stood in it as it was built, so it stands as the set dresser drew it. A ladle dipped leaves the
## brew where it was, a stone dropped in raises it, and what is lifted out takes its share with it. (the-quiet-crucible
## 841899, the user: "the ladle is placed into the liquid - and this causes the amount of liquid to DECREASE. That is
## backwards" - the 39 ml that flowed into the ladle's bowl had left the brew's column, and the brew fell 2 mm.) Over its
## rim, it stands above it, and pours.
func _level_of(li: int, up: Vector3, xf: Transform3D, scale: float) -> float:
	var L: Dictionary = liquids[li]
	var vs: Vessel = L["vessel"]
	var full := maxf(float(L["full_v"]), 1e-12)
	var v := float((_liq[li] as Dictionary)["v"])
	var s := vs.level(up, v / full)
	var under := _displacers(li)
	if (under[0] as PackedFloat32Array).is_empty() and float(L.get("d0", 0.0)) == 0.0:
		return s
	for k in 2:
		var y := (xf * vs.surface_middle(up, s)).y
		var want := v + _under(under, y) - float(L.get("d0", 0.0))
		s = vs.level(up, clampf(want / full, 0.0, 1.0))
		if want > full:
			var r := maxf(vs.surface_radius(up, s), 0.002)
			s += (want - full) / maxf(scale, 1e-9) / (PI * r * r)
	return s


## WHAT STOOD IN EACH LIQUID AS IT WAS BUILT, under its surface as drawn (`d0`, cubic meters): it stands where the set dresser
## drew it, and whatever comes or goes after moves it ([method _level_of]).
func _built_displaced() -> void:
	_wet_ids = null
	for li in liquids.size():
		var L: Dictionary = liquids[li]
		if float(L["v0"]) <= 1e-10:
			continue
		var sd: Dictionary = solids[int(L["solid"])]
		var vs: Vessel = L["vessel"]
		var xf: Transform3D = sd["rest"]
		var up := (xf.basis.inverse() * Vector3.UP).normalized()
		var y := (xf * vs.surface_middle(up, vs.level(up, float(L["v0"]) / maxf(float(L["full_v"]), 1e-12)))).y
		L["d0"] = _under(_displacers(li), y)


## WHAT STANDS IN LIQUID [param li]'s INSIDE, wherever its surface is: `[heights, volumes]` (the table's space; meters, cubic
## meters) of the points of each body's matter ([method _matter_points]), of each moving vessel's inside ([member
## Vessel.points], every [constant INSIDE_STEP]-th) and of the loose things' and grains' spheres, that lie within it.
func _displacers(li: int) -> Array:
	var L: Dictionary = liquids[li]
	var own := int(L["solid"])
	var sa: Dictionary = solids[own]
	var box: AABB = sa["wbox"]
	var inv: Transform3D = sa["inv"]
	var vs: Vessel = L["vessel"]
	var hs := PackedFloat32Array()
	var ws := PackedFloat32Array()
	# ...a body that has not stirred is the solid it was before it was one, and stood as the liquid was built ([method _dormant]): a pot's own wall, a body since every thing is one, was
	# read as standing in a ladle dipped beside it - so only the bodies stirred are asked, not every solid on the table
	var stirred := PackedInt32Array()
	for rb in rigid.bodies:
		if not bool((rb as Dictionary).get("dormant", false)):
			stirred.append_array((rb as Dictionary)["solids"])
	for si in stirred:
		if si == own:
			continue
		var sd: Dictionary = solids[si]
		if not bool(sd.get("on", true)) or not (sd["wbox"] as AABB).intersects(box):
			continue
		var xf: Transform3D = sd["xf"]
		var det := absf(xf.basis.determinant())
		var mp: Array = _matter_points(si)
		var w := float(mp[1]) * det
		for q in (mp[0] as PackedVector3Array):
			var p := xf * q
			if box.has_point(p) and vs.contains(inv * p):
				hs.append(p.y)
				ws.append(w)
		var vi := int(_vessel_of.get(si, -1))
		if vi >= 0 and vi != li:
			var vb: Vessel = (liquids[vi] as Dictionary)["vessel"]
			var n := vb.points.size()
			var wv := vb.volume * det * float(INSIDE_STEP) / float(maxi(n, 1))
			for k in range(0, n, INSIDE_STEP):
				var p := xf * vb.points[k]
				if box.has_point(p) and vs.contains(inv * p):
					hs.append(p.y)
					ws.append(wv)
	# ...the spheres in it: as the solver last found them ([member Particles.wet]), or - as built, before it has - all in its box
	var ids: Variant = _wet_ids.get(li) if _wet_ids != null else null
	if ids == null and _wet_ids != null:
		return [hs, ws]
	for i in (ids if ids != null else range(sim.n)):
		if sim.alive[i] == 1 and box.has_point(sim.x[i]) and vs.contains(inv * sim.x[i]):
			hs.append(sim.x[i].y)
			ws.append(4.0 / 3.0 * PI * pow(sim.r[i], 3.0))
	return [hs, ws]


## Whether solid [param sd] is a DORMANT body's ([RigidParts]): as built, untouched - exactly a solid that is no body.
func _dormant(sd: Dictionary) -> bool:
	return sd.has("body") and bool((rigid.bodies[int(sd["body"])] as Dictionary).get("dormant", false))


## Each liquid's spheres, as the solver last found them in it: liquid -> PackedInt32Array ([method _displacers]).
func _wet_now() -> Dictionary:
	var out := {}
	for i in sim.n:
		if sim.alive[i] == 1 and i < sim.wet.size() and sim.wet[i] >= 0:
			var li := sim.wet[i]
			if not out.has(li):
				out[li] = PackedInt32Array()
			(out[li] as PackedInt32Array).append(i)
	return out


## The volume of [param under] ([method _displacers]) below height [param y].
static func _under(under: Array, y: float) -> float:
	var hs: PackedFloat32Array = under[0]
	var ws: PackedFloat32Array = under[1]
	var out := 0.0
	for k in hs.size():
		if hs[k] < y:
			out += ws[k]
	return out


## SOLID [param si]'s MATTER as points (its own space) and the volume each stands for (its own space's cubic meters): its
## field sampled as [method _mass_of] samples it, at most [constant MATTER_POINTS] of them.
func _matter_points(si: int) -> Array:
	var sd: Dictionary = solids[si]
	if sd.get("matter_pts") != null:
		return sd["matter_pts"]
	var f: ShapeField = sd["field"]
	var box: AABB = sd["box"]
	var cell := maxf(minf(box.size.x, minf(box.size.y, box.size.z)) / 3.0, 0.0008)
	var n := Vector3i(clampi(int(ceil(box.size.x / cell)), 2, MASS_CELLS), clampi(int(ceil(box.size.y / cell)), 2, MASS_CELLS),
		clampi(int(ceil(box.size.z / cell)), 2, MASS_CELLS))
	var step := box.size / Vector3(n)
	var pts := PackedVector3Array()
	for i in n.x:
		for j in n.y:
			for k in n.z:
				var q := box.position + step * Vector3(i + 0.5, j + 0.5, k + 0.5)
				if f.sample(q).x < 0.0:
					pts.append(q)
	var every := maxi(1, int(ceil(float(pts.size()) / float(MATTER_POINTS))))
	var kept := PackedVector3Array()
	for k in range(0, pts.size(), every):
		kept.append(pts[k])
	var out := [kept, step.x * step.y * step.z * float(pts.size()) / float(maxi(kept.size(), 1))]
	sd["matter_pts"] = out
	return out


## LIQUID [param li]'s SURFACE ([SurfaceWaves]) a frame of [param dt] on, its level [param s] along [param up] (its vessel's
## own space): each solid crossing it pushes up the cells it comes into and lets down those it leaves - a share of a cell
## at a time, by its field where the surface is - and the ripples run, come back off the walls and die. Tipped far (a
## pour), it is let be.
func _waves_step(li: int, up: Vector3, s: float, dt: float, t := 0.0) -> void:
	var L: Dictionary = liquids[li]
	var S: Dictionary = _liq[li]
	var W: SurfaceWaves = L["waves"]
	var st: Dictionary = S["w"]
	if up.normalized().y < 0.7:
		if bool(st["on"]):
			S["w"] = W.fresh()
		return
	var u := up.normalized()
	W.remask(L["vessel"], u, s)
	var vsi := int(L["solid"])
	var xf: Transform3D = (solids[vsi] as Dictionary)["xf"]
	var inv: Transform3D = (solids[vsi] as Dictionary)["inv"]
	# the surface's own box in the table's space, a sphere's width above and below
	var span := AABB(xf * W.point(0, u, s), Vector3.ZERO)
	for c in [W.n - 1, W.n * (W.n - 1), W.n * W.n - 1]:
		span = span.expand(xf * W.point(int(c), u, s))
	span = span.grow(0.01)
	var occ: Dictionary = st["occ"]
	for sj in solids.size():
		if sj == vsi:
			continue
		var o: Dictionary = solids[sj]
		# WHAT HAS NOT MOVED has not changed what it holds of the surface - unless it is taken away; and what a solid holds as
		# it is first found moving there is where the surface began, never a push (a ladle standing in its pot from the start
		# had heaved the surface up round it as it first stirred)
		var seen := occ.has(sj)
		var quiet := not bool(o["moving"])
		if quiet and not seen:
			continue
		var was: Dictionary = occ.get(sj, {})
		var near := bool(o["on"]) and (o["wbox"] as AABB).intersects(span)
		if quiet and near:
			continue
		var now := {}
		if near:
			# the cells under its box, by its field at the surface
			var b: AABB = inv * (o["wbox"] as AABB)
			var i0 := clampi(int(floor((b.position.x - W.o.x) / W.cell)), 0, W.n - 1)
			var i1 := clampi(int(floor((b.end.x - W.o.x) / W.cell)), 0, W.n - 1)
			var j0 := clampi(int(floor((b.position.z - W.o.y) / W.cell)), 0, W.n - 1)
			var j1 := clampi(int(floor((b.end.z - W.o.y) / W.cell)), 0, W.n - 1)
			var oi: Transform3D = o["inv"]
			var f: ShapeField = o["field"]
			for j in range(j0, j1 + 1):
				for i in range(i0, i1 + 1):
					var c := j * W.n + i
					if W.mask[c] == 0:
						continue
					var d := f.sample(oi * (xf * W.point(c, u, s))).x
					var share := clampf(0.5 - d / W.cell, 0.0, 1.0)
					if share > 0.0:
						now[c] = share
		if seen:
			for c in now:
				var dv := float(now[c]) - float(was.get(c, 0.0))
				if absf(dv) > 1e-4:
					W.push(st, int(c), SurfaceWaves.WAKE * dv)
			for c in was:
				if not now.has(c):
					W.push(st, int(c), -SurfaceWaves.WAKE * float(was[c]))
		# kept while it is near, even holding none of it (-1: seen, crossing nothing)
		if near:
			occ[sj] = now if not now.is_empty() else {-1: 0.0}
		else:
			occ.erase(sj)
	st["occ"] = occ
	# ...AND WHAT BOILS IN IT ([Boil]): each bubble big enough to be seen breaking rings it where it breaks - the bubbles the table
	# draws and the work's sound hears
	for bb in _bubbles_in(li, t - dt, t):
		var r := float((bb as Dictionary)["r"])
		if r < BUBBLE_RINGS:
			continue
		var half := float(W.n) * W.cell * 0.5
		var at2: Vector2 = (bb as Dictionary)["at"]
		var x := W.o.x + half + at2.x * half
		var z := W.o.y + half + at2.y * half
		W.dent(st, Vector3(x, (s - u.x * x - u.z * z) / maxf(u.y, 0.05), z), r * DENT, maxf(W.cell, r * 3.0))
	W.step(st, dt)


## LIQUID [param li]'s bubbles breaking from [param t0] to [param t1] ([Boil]), as its work boils it - none where it does not.
func _bubbles_in(li: int, t0: float, t1: float) -> Array:
	var wi := int((liquids[li] as Dictionary)["wi"])
	if wi < 0:
		return []
	var ch := "w%d:boil" % wi
	if not twin._chan.has(ch) and float(twin._rest.get(ch, 0.0)) <= 0.0:
		return []
	var W: SurfaceWaves = (liquids[li] as Dictionary)["waves"]
	return Boil.bubbles(wi, t0, t1, func(T: float) -> float: return float(twin.value(ch, T)), float(W.n) * W.cell)


## Whether a liquid boils hard enough at [param t] that its bubbles ring its surface ([constant BUBBLE_RINGS]): the bake is not
## quiet then.
func _rings_boiling(t: float) -> bool:
	for li in liquids.size():
		var wi := int((liquids[li] as Dictionary)["wi"])
		if wi < 0:
			continue
		var ch := "w%d:boil" % wi
		if not twin._chan.has(ch) and float(twin._rest.get(ch, 0.0)) <= 0.0:
			continue
		if Boil.radii(float(twin.value(ch, t))).y >= BUBBLE_RINGS and float((_liq[li] as Dictionary)["v"]) > 1e-9:
			return true
	return false


## How a turning liquid's surface curves (meters a square meter out from its middle, ω² / 2g): a stirred pot's stands low in
## the middle and up its wall, its level kept - ω² / 2g (r² - R² / 2), R its surface's radius ([Particles], the shader).
func _dip(li: int) -> float:
	var w := float((_liq[li] as Dictionary)["swirl"])
	return w * w / (2.0 * GRAVITY)


## A DENT in liquid [param li]'s surface at [param at] (the table's space) as big as ring [param size] (meters): where
## something has fallen in.
func _dent(li: int, at: Vector3, size: float) -> void:
	var L: Dictionary = liquids[li]
	var W: SurfaceWaves = L["waves"]
	var inv: Transform3D = (solids[int(L["solid"])] as Dictionary)["inv"]
	W.dent((_liq[li] as Dictionary)["w"], inv * at, size * DENT, maxf(W.cell, size * 6.0))


## A VESSEL UNDER A LIQUID HAS ITS LEVEL - a ladle in its pot, a cup pushed under, a jar sunk: where the liquid's surface stands above the dipped
## vessel's rim, in the liquid's own inside, it flows over that rim as a weir does (the flow it would pour out by, [method Vessel.overflow]), in or out, until it
## stands as high inside as out. The inside of anything is filled so, and empties again by tipping. (the-quiet-crucible 707668: the ladle "dips into the finished
## brew, draws up a measure" - and came up empty, so its pour into the vial poured nothing.) SO LONG AS ANY OF ITS RIM IS UNDER, THE TWO ARE ONE SURFACE
## ([member _liq]'s `dipped`): it neither sloshes nor pours (841899, feedback 0009, 0011: "Every time I've seen the ladle go into the pot, the liquid level
## decreases": let go, the ladle tipped against the wall with part of its rim under the brew - the sloshing of a surface 6 cm across stood it over the rim's other
## side, at 400 to 1,100 ml a second, refilled as fast from the side under, and most of what it poured was spilled at the pot's wall: 955 ml to 273 over the show).
func _dips(dt: float) -> void:
	var dipped := {}
	for bi in liquids.size():
		var LB: Dictionary = liquids[bi]
		var SB: Dictionary = _liq[bi]
		var sb: Dictionary = solids[int(LB["solid"])]
		if not bool(sb["on"]):
			continue
		var xb: Transform3D = sb["xf"]
		var ib := xb.affine_inverse()
		var vb: Vessel = LB["vessel"]
		var up := (xb.basis.inverse() * Vector3.UP).normalized()
		for ai in liquids.size():
			var LA: Dictionary = liquids[ai]
			var SA: Dictionary = _liq[ai]
			if ai == bi or int(LA["solid"]) == int(LB["solid"]) or float(SA["v"]) <= 1e-9:
				continue
			var sa: Dictionary = solids[int(LA["solid"])]
			# ...AND WHAT CANNOT HAVE CHANGED, asked again only if it was dipped: the pairs of a table's two dozen insides were a stir's every frame, and all but one stand still
			if int(SB["dipped"]) != ai and not bool(sb["moving"]) and not bool(sa["moving"]) and (SA["was"] as Vector2) == Vector2(float(SA["v"]), (SA["c"] as Vector3).y if SA.has("c") else 0.0):
				continue
			if not bool(sa["on"]) or not (sa["wbox"] as AABB).intersects(sb["wbox"]):
				continue
			# its surface along the up the dipped vessel sees, in that vessel's own space
			var s := (ib * (SA["c"] as Vector3)).dot(up)
			var of := vb.overflow(up, s)
			if float(of["q"]) <= 0.0 or not (LA["vessel"] as Vessel).contains((sa["inv"] as Transform3D) * (xb * vb.rim[int(of["at"])])):
				continue
			dipped[bi] = ai
			var want := vb.share_under(up, s) * float(LB["full_v"]) - float(SB["v"])
			var most := float(of["q"]) * absf(xb.basis.determinant()) * dt
			# ...in as it stands lower inside, out as it stands higher, neither past the other's level or past what there is
			var dv := minf(minf(most, want), float(SA["v"])) if want > 0.0 else maxf(maxf(-most, want), -float(SB["v"]))
			if absf(dv) <= 1e-12:
				continue
			SA["v"] = float(SA["v"]) - dv
			SB["v"] = float(SB["v"]) + dv
			if dv > 0.0 and (not bool(LB["made"]) or float(SB["v"]) <= dv * 1.01):
				SB["color"] = (SB["color"] as Color).lerp(SA["color"], clampf(dv / float(SB["v"]), 0.0, 1.0))
	for bi in liquids.size():
		var SB: Dictionary = _liq[bi]
		SB["dipped"] = int(dipped.get(bi, -1))
		SB["was"] = Vector2(float(SB["v"]), (SB["c"] as Vector3).y if SB.has("c") else 0.0)


## Whether a liquid's fill is being changed by the work at [param t].
func _liquid_fills(t: float) -> bool:
	for L in liquids:
		var wi := int((L as Dictionary)["wi"])
		if wi < 0:
			continue
		for e in twin._chan.get("w%d:fill" % wi, []):
			if t >= float((e as Dictionary)["s0"]) and t <= float((e as Dictionary)["s1"]) + 0.05:
				return true
	return false


## THE STREAMS' PARCELS a frame on: each falling until it meets a liquid's surface in its vessel (it fills it, and rings
## it), something solid (spilled), or nothing.
func _parcels_step(t: float, dt: float) -> void:
	for pi in range(_recent(t), parcels.size()):
		var pd: Dictionary = parcels[pi]
		if float(pd["t1"]) != INF:
			continue
		var tau := t - float(pd["t0"])
		var at := _parcel_at(pd, tau)
		var was := _parcel_at(pd, maxf(tau - dt, 0.0))
		if tau > PARCEL_LIFE or at.y < -0.6:
			pd["t1"] = t
			pd["into"] = -1
			continue
		# INTO A LIQUID - or an empty inside: crossing its surface (its floor) within it
		var landed := false
		for li in liquids.size():
			if li == int(pd["from"]) and tau < 0.05:
				continue
			var L: Dictionary = liquids[li]
			var S: Dictionary = _liq[li]
			var sd: Dictionary = solids[int(L["solid"])]
			var vs: Vessel = L["vessel"]
			var inv: Transform3D = sd["inv"]
			if not vs.contains(inv * at) and not vs.contains(inv * was):
				continue
			var xf: Transform3D = sd["xf"]
			var up := (xf.basis.inverse() * Vector3.UP).normalized()
			var share := float(S["v"]) / maxf(float(L["full_v"]), 1e-12)
			var s := vs.level(up, share)
			if (inv * at).dot(up) <= s + 0.0005:
				S["v"] = minf(float(S["v"]) + float(pd["vol"]), float(L["full_v"]))
				var mix := float(pd["vol"]) / maxf(float(S["v"]), 1e-12)
				S["color"] = (S["color"] as Color).lerp(pd["color"], clampf(mix, 0.0, 1.0)) if not bool(L["made"]) or float(S["v"]) <= float(pd["vol"]) * 1.01 else S["color"]
				S["hit"] = Vector4(at.x, at.y, at.z, clampf(float(pd["vol"]) / dt * 2000.0, 0.0, 0.0012))
				pd["t1"] = t
				pd["into"] = li
				landed = true
				break
		if landed:
			continue
		# ...or something solid - but its own vessel's rim, which it leaves from, only once it has fallen clear of it - LOOKED FOR
		# ALL ALONG ITS WAY, never only where the frame leaves it: at a stream's pace a parcel stepped over a pot's 3 mm wall
		# between two frames (841899's dip: what went "into the brazier pan" had gone through the cauldron's wall)
		var before := _solid_on_way(was, at, int((liquids[int(pd["from"])] as Dictionary)["solid"]) if tau < 0.15 else -1)
		if before != Vector3.INF:
			pd["t1"] = t
			pd["into"] = -1
			# ...AND WHAT STRIKES A VESSEL'S INSIDE RUNS DOWN INTO IT, never lost: a ladle drawn up out of its pot spills over the
			# pot's inner wall, and its spill had been counted gone (841899's dip: 8.5 ml "SPILLED" of a pot it never left)
			var skip_l := int(pd["from"]) if tau < 0.15 else -1
			# ...asked a little back along its way too: right at a wall, a point lies in the inside's inset, outside it
			var into := _inside_of(before, skip_l)
			if into < 0:
				into = _inside_of(before.lerp(was, 0.5), skip_l)
			if into < 0:
				into = _inside_of(was, skip_l)
			if into >= 0:
				var S: Dictionary = _liq[into]
				S["v"] = minf(float(S["v"]) + float(pd["vol"]), float((liquids[into] as Dictionary)["full_v"]))
				pd["into"] = into
	# a stream that has stopped landing rings no more
	for S in _liq:
		var h: Vector4 = (S as Dictionary)["hit"]
		(S as Dictionary)["hit"] = Vector4(h.x, h.y, h.z, h.w * 0.85) if h.w > 1e-5 else Vector4.ZERO


static func _parcel_at(p: Dictionary, tau: float) -> Vector3:
	return (p["p"] as Vector3) + (p["v"] as Vector3) * tau + Vector3.DOWN * (0.5 * GRAVITY * tau * tau)


## The liquid whose surface stands over [param p] (the table's space) in its own inside, other than [param skip]; or -1.
func _under_liquid(p: Vector3, skip: int) -> int:
	for li in liquids.size():
		var S: Dictionary = _liq[li]
		if li == skip or float(S["v"]) <= 1e-9 or not S.has("c"):
			continue
		var sd: Dictionary = solids[int((liquids[li] as Dictionary)["solid"])]
		if not (sd["wbox"] as AABB).has_point(p) or not ((liquids[li] as Dictionary)["vessel"] as Vessel).contains((sd["inv"] as Transform3D) * p):
			continue
		if (p - (S["c"] as Vector3)).dot(S["n"] as Vector3) < 0.0:
			return li
	return -1


## WHERE A WAY FROM [param a] TO [param b] (the table's space) FIRST MEETS SOMETHING SOLID but solid [param skip], or the table's
## top: the last place on it before - or Vector3.INF, where it meets nothing. Looked along in steps of [constant PARCEL_STEP],
## against the solids its way's box crosses.
func _solid_on_way(a: Vector3, b: Vector3, skip: int) -> Vector3:
	var way := AABB(a, Vector3.ZERO).expand(b)
	var near := PackedInt32Array()
	for si in solids.size():
		var d: Dictionary = solids[si]
		if si != skip and bool(d["on"]) and (d["wbox"] as AABB).intersects(way):
			near.append(si)
	var steps := clampi(int(ceil(a.distance_to(b) / PARCEL_STEP)), 1, 24)
	var last := a
	for k in range(1, steps + 1):
		var q := a.lerp(b, float(k) / float(steps))
		if q.y <= 0.0005:
			return last
		for si in near:
			var d: Dictionary = solids[si]
			if (d["wbox"] as AABB).has_point(q) and (d["field"] as ShapeField).sample((d["inv"] as Transform3D) * q).x < 0.0:
				return last
		last = q
	return Vector3.INF


## The liquid whose vessel's inside holds [param p] (the table's space), other than [param skip]; or -1.
func _inside_of(p: Vector3, skip: int) -> int:
	for li in liquids.size():
		if li == skip:
			continue
		var sd: Dictionary = solids[int((liquids[li] as Dictionary)["solid"])]
		if bool(sd.get("on", true)) and (sd["wbox"] as AABB).has_point(p) and ((liquids[li] as Dictionary)["vessel"] as Vessel).contains((sd["inv"] as Transform3D) * p):
			return li
	return -1


func _in_solid(p: Vector3, skip := -1) -> bool:
	for si in solids.size():
		if si == skip:
			continue
		var d: Dictionary = solids[si]
		if not bool(d["on"]) or not (d["wbox"] as AABB).has_point(p):
			continue
		if (d["field"] as ShapeField).sample((d["inv"] as Transform3D) * p).x < 0.0:
			return true
	return false


## WHAT THE WORK HOLDS: a loose thing an act carries goes where the act has it, from where it really is - its first
## moment re-based on where the physics left it.
func _held_step(t: float, dt: float) -> void:
	for li in loose.size():
		var L: Dictionary = loose[li]
		var wi := int(L["wi"])
		# one taken up is a body from then on
		if int(L["body"]) < 0 and (not _held_at(wi, t) or not _wake_loose(li, t)):
			continue
		var b: Dictionary = sim.bodies[int(L["body"])]
		var n0: Transform3D = L["n0"]
		var now := sim.body_pose(int(L["body"])) * n0
		# ...HELD UP BETWEEN ITS MOVES as a rigid part is ([method _held_aloft]), when a later move takes it up again and let go it
		# would fall: 841899's phoenix feather, fetched "and held up in the middle of the bench" till it was laid in the cauldron,
		# was dropped on the table as its fetch ended
		var held: Variant = _held_pose(wi, t, now) if _held_at(wi, t) else _held_aloft(-1, wi, t, li)
		if held == null:
			b["held"] = null
			continue
		var was: Variant = _held_pose(wi, t - dt, now) if _held_at(wi, t - dt) else _held_aloft(-1, wi, t - dt, li)
		b["held"] = (held as Transform3D) * n0.affine_inverse()
		b["held_from"] = (was as Transform3D) * n0.affine_inverse() if was != null else sim.body_pose(int(L["body"]))


## The channel a hand moves [param wi] by: a part's pose - or, less than 0, a whole thing's, -1 less its number ([method
## _make_rigid]: a thing an act moves is a body too).
func _ch_of(wi: int) -> String:
	return "w%d:pose" % wi if wi >= 0 else "t%d:pose" % (-1 - wi)


## ...and where its node stood as built (the table's space).
func _rest_of(wi: int) -> Transform3D:
	return work._rest[_ch_of(wi)]


## Whether the work holds loose work [param wi] at [param t] - by itself or with its group: its stretches found once a
## plan ([member _hold_spans]), those less than [constant HOLD_GAP] apart one hold - a hand never lets go between one move
## and the next (a stopper had dropped 2 cm in the 65 ms between two of its tracks). A whole thing is [method _ch_of]'s.
## THE SOLIDS OF WHAT [param wi]'s paint act lays it on at show time [param t] ([TablePaint]): none while no paint act holds it.
func _painted_by(wi: int, t: float) -> PackedInt32Array:
	var out := PackedInt32Array()
	for e in twin._chan.get(_ch_of(wi), []):
		var ed: Dictionary = e
		var tr: Dictionary = ed["track"]
		if String(tr["law"]) != "paint" or t < float(ed.get("s0", ed["t0"])) or t > float(ed.get("s1", ed["t1"])):
			continue
		# ...what it paints, and the pots, the water and the towel it goes to ([method TablePaint.touches])
		var tis: PackedInt32Array = twin.paint.touches(tr) if twin.paint != null else PackedInt32Array([twin._thing_named(String(tr.get("press", "")))])
		for si in solids.size():
			var ti := int((solids[si] as Dictionary).get("thing", -1))
			if ti >= 0 and tis.has(ti) and not out.has(si):
				out.append(si)
	return out


func _held_at(wi: int, t: float) -> bool:
	if not _hold_spans.has(wi):
		var all: Array = []
		var chans: Array = [_ch_of(wi)]
		var gi := int(twin._group_of.get(wi, -1))
		if gi >= 0:
			chans.append("g%d:pose" % gi)
		for ch in chans:
			for e in twin._chan.get(ch, []):
				all.append(Vector2(float((e as Dictionary)["s0"]), float((e as Dictionary)["s1"])))
		all.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
		var spans := PackedVector2Array()
		for v in all:
			if not spans.is_empty() and (v as Vector2).x - spans[spans.size() - 1].y < HOLD_GAP:
				spans[spans.size() - 1] = Vector2(spans[spans.size() - 1].x, maxf(spans[spans.size() - 1].y, (v as Vector2).y))
			else:
				spans.append(v)
		_hold_spans[wi] = spans
	for sp in (_hold_spans[wi] as PackedVector2Array):
		if t >= sp.x and t < sp.y:
			return true
	return false


## Where the work holds loose work [param wi] at [param t] (its node's pose, the table's space), or null when nothing
## does - each move begun from where the physics has it, [param now].
func _held_pose(wi: int, t: float, now: Transform3D) -> Variant:
	var own := _ch_of(wi)
	for e in twin._chan.get(own, []):
		var ed: Dictionary = e
		if t < float(ed["s0"]) or t >= float(ed["s1"]):
			continue
		var key := str(ed.get("t0")) + "|" + own + "|" + str(ed.get("s0"))
		if not _held.has(key):
			var e2 := ed.duplicate()
			e2["from"] = now
			# ...its way over what is in it found from there ([method TableWork._clearance])
			e2.erase("_clear")
			e2.erase("_pour")
			e2.erase("_dip")
			# ...and a tool's way to its work ([method TableWork._entry_lift]) from where it is, never from where the plan had it
			# (841899's pestle, set down in its mortar, rose 6 cm again on the lift planned from where it had been left in the air)
			e2.erase("_entry")
			_held[key] = e2
		var e3: Dictionary = _held[key]
		return twin._eval(e3, t - float(e3["t0"]), t)
	var gi := int(twin._group_of.get(wi, -1))
	# ...BETWEEN TWO MOVES a hand holds it where the last one left it ([method _held_at])
	var last := -1.0
	for e in twin._chan.get(own, []):
		if float((e as Dictionary)["s1"]) <= t and float((e as Dictionary)["s1"]) > t - HOLD_GAP:
			last = float((e as Dictionary)["s1"])
	if last >= 0.0 and gi < 0:
		return _held_pose(wi, last - 1e-4, now)
	if gi >= 0:
		var gch := "g%d:pose" % gi
		for e in twin._chan.get(gch, []):
			var ed: Dictionary = e
			if t < float(ed["s0"]) or t >= float(ed["s1"]):
				continue
			var key := str(ed.get("t0")) + "|" + gch + "|" + str(ed.get("s0")) + "|" + str(wi)
			if not _held.has(key):
				_held[key] = [twin.value(gch, float(ed["s0"])), now]
			var g0: Transform3D = (_held[key] as Array)[0]
			var p0: Transform3D = (_held[key] as Array)[1]
			return (twin.value(gch, t) as Transform3D) * g0.affine_inverse() * p0
	return null


# --- what the work picks up -------------------------------------------------------------------------------

## WHAT THE WORK PICKS UP, each a rigid body ([RigidParts]): a free part some act moves that is not loose - its own solids
## and those of every part of it with no joint of its own, their mass, middle and inertia, and their surfaces - asleep as
## it was built on what holds it. (Each had gone exactly where its acts said, through whatever was there: a pestle put back
## into its mortar's wall, a stopper laid sideways, a lid that never settled.) AND EVERY WHOLE THING AN ACT MOVES, of its
## own solids and those of every part of it that moves only as it does ([method _rides_thing]) - the user, 2026-10-30, of
## 841899's mortar tipped through the cauldron: "why can we not just add collision to most if not all objects, so that they
## naturally respect physical boundaries?": a thing carried had gone where its act said, through whatever was there, and
## the act's check, a few hundred of its corners at 25 moments, never saw a thin rim go into it.
func _make_rigid() -> void:
	for wi in work.works.size():
		var wk: Dictionary = work.works[wi]
		if String(wk["kind"]) != "free" or bool((wk["w"] as Dictionary).get("loose", false)) or not _goes(wi) \
				or not work._rest.has("w%d:pose" % wi):
			continue
		_add_body(wi, _solids_of(_unjointed([wi])))
	# ...AND EVERY THING THAT MAY BE MOVED WHOLE - all but what holds a flame - whether or not an act moves it (as [method _goes])
	for ti in work.things.size():
		if bool((work.things[ti] as Dictionary).get("lit", false)) or not work._rest.has("t%d:pose" % ti):
			continue
		var own := PackedInt32Array()
		for si in solids.size():
			var sd: Dictionary = solids[si]
			if int(sd["thing"]) == ti and not sd.has("body") and (String(sd["owner"]) == "t" or _rides_thing(int(sd["wi"]))):
				own.append(si)
		_add_body(-1 - ti, own)
	_posed_now()
	# ...and which of them moves each solid: the body of a part it is a part of, or of the thing it is a part of
	for sd in solids:
		var d: Dictionary = sd
		var on: Array = []
		var c := int(work._parent_work.get(int(d["wi"]), -1)) if int(d["wi"]) >= 0 else -1
		while c >= 0:
			if _rigid_of.has(c):
				on.append(int(_rigid_of[c]))
			c = int(work._parent_work.get(c, -1))
		if not d.has("body") and _rigid_of.has(-1 - int(d["thing"])):
			on.append(int(_rigid_of[-1 - int(d["thing"])]))
		d["bodies"] = on


## Whether part [param wi] moves only as its thing does: neither it nor any part it hangs from has a joint of its own or is
## a body of its own. A FREE PART IS A THING OF ITS OWN standing in its thing or on it, never welded into it ([method _goes]):
## four jars side by side, carried whole, had been one rigid body (the-quiet-crucible 841899, 2026-10-31).
func _rides_thing(wi: int) -> bool:
	var c := wi
	while c >= 0:
		var k := String((work.works[c] as Dictionary)["kind"])
		if _rigid_of.has(c) or k != "":
			return false
		c = int(work._parent_work.get(c, -1))
	return true


## Whether free part [param wi] is a body of its own: EVERY FREE PART IS, whatever the acts do - riding what holds it up as a thing
## set on another does. It had been one only if some act, at any time, moved it or what it stood in (2026-11-01, next/
## framework_audit.md): a jar no act fetched was an immovable solid and the same jar a body the moment a later act did - so a
## ladle that knocked it was held back by it or knocked it, by what came minutes after; and every new act that moved something
## new changed the world itself, so nothing baked before it could be kept.
func _goes(_wi: int) -> bool:
	return true


## A RIGID BODY of solids [param own], keyed [param key] (a part's work, or a whole thing's, [method _ch_of]): their mass,
## middle and inertia, their surfaces, asleep as built on what holds them - its number, or -1 when there is nothing to it.
func _add_body(key: int, own: PackedInt32Array) -> int:
	if own.is_empty():
		return -1
	var m := 0.0
	var c := Vector3.ZERO
	var masses: Array = []
	for si in own:
		var ms := _mass_of(si)
		masses.append(ms)
		m += float(ms["m"])
		c += (ms["c"] as Vector3) * float(ms["m"])
	if m <= 0.0:
		return -1
	c /= m
	# its inertia about its own middle: each solid's about its own, moved there
	var ix := Vector3.ZERO
	var iy := Vector3.ZERO
	var iz := Vector3.ZERO
	for ms in masses:
		var ib: Basis = (ms as Dictionary)["i"]
		var r: Vector3 = ((ms as Dictionary)["c"] as Vector3) - c
		var mk := float((ms as Dictionary)["m"])
		var r2 := r.length_squared()
		ix += ib.x + Vector3(r2 - r.x * r.x, -r.x * r.y, -r.x * r.z) * mk
		iy += ib.y + Vector3(-r.y * r.x, r2 - r.y * r.y, -r.y * r.z) * mk
		iz += ib.z + Vector3(-r.z * r.x, -r.z * r.y, r2 - r.z * r.z) * mk
	var pts := PackedVector3Array()
	var rests: Array = []
	for si in own:
		var sd: Dictionary = solids[si]
		rests.append(sd["rest"])
		for q in (sd["field"] as ShapeField).surface_points():
			pts.append((sd["rest"] as Transform3D) * q)
	var host := _rigid_host(own, c, pts)
	var mu := _surface_friction(String(((solids[own[0]] as Dictionary)["part"] as Dictionary).get("material", "")))
	var bi := rigid.add(key, own, rests, m, Basis(ix, iy, iz), c, pts, mu, host,
		(solids[host] as Dictionary)["rest"] if host >= 0 else Transform3D.IDENTITY)
	_rigid_of[key] = bi
	for si in own:
		(solids[si] as Dictionary)["body"] = bi
		# ...and what its steps say of it, as it is read before its first ([RigidParts] sets them each step): never a key first given
		# on the bake's thread
		(solids[si] as Dictionary)["stirs"] = false
		(solids[si] as Dictionary)["presses"] = true
	# ...ITS SEAT: what of its own thing a part was built touching (a cork, its jar's neck), [constant SEAT_TOUCH] near - NEVER
	# A PART OF ITS OWN: a jar is not seated in the cork in its neck (seated on each other, 841899's jar and cork were welded
	# together where they stood, and the jar was never fetched)
	var seat := PackedInt32Array()
	if key >= 0:
		var ti := int((solids[own[0]] as Dictionary)["thing"])
		for si in solids.size():
			var sd: Dictionary = solids[si]
			if int(sd["thing"]) != ti or own.has(si) or work._within(int(sd["wi"]), key) != 0:
				continue
			# ...AND WHAT HOLDS IT UP: touching it where its surface faces up - a jar is not seated in the stopper pressing on its
			# lip, whatever part of whom each is
			var inv := (sd["rest"] as Transform3D).affine_inverse()
			for q in pts:
				var f: Vector4 = (sd["field"] as ShapeField).sample(inv * q)
				if f.x < SEAT_TOUCH and ((sd["rest"] as Transform3D).basis * Vector3(f.y, f.z, f.w)).normalized().y > RigidParts.HELD_UP:
					seat.append(si)
					break
	(rigid.bodies[bi] as Dictionary)["seat"] = seat
	return bi


## What a body of solids [param own] (its middle [param c], its surface [param pts], the table's space as built) rests on as
## built: an inside it stands in, not its own; else the solid nearest under its lowest point, within a few millimeters;
## else the table's top (-1).
func _rigid_host(own: PackedInt32Array, c: Vector3, pts: PackedVector3Array) -> int:
	for li in liquids.size():
		var ls := int((liquids[li] as Dictionary)["solid"])
		if own.has(ls):
			continue
		if ((liquids[li] as Dictionary)["vessel"] as Vessel).contains(((solids[ls] as Dictionary)["rest"] as Transform3D).affine_inverse() * c):
			return ls
	var low := c
	for p in pts:
		if p.y < low.y:
			low = p
	var best := -1
	var bd := 0.004
	for si in solids.size():
		if own.has(si):
			continue
		var sd: Dictionary = solids[si]
		# (never grown by less than nothing: the best so far is below 0 once the point is found inside a solid, and a
		# thin solid's box shrunk by it had a negative size - "AABB size is negative", 841899's 2026-10-31 build)
		if not (sd["wbox"] as AABB).grow(maxf(bd, 0.0)).has_point(low):
			continue
		var d := (sd["field"] as ShapeField).sample((sd["inv"] as Transform3D) * low).x
		if d < bd:
			bd = d
			best = si
	return best


## EACH RIGID BODY A FRAME ON, at show time [param t]: where the work holds each now (each move begun where the bake has
## it, or held up between its moves, [method _held_aloft]), then their steps among the solids - and the twin told where
## they went.
func _rigid_step(t: float, dt: float) -> void:
	for bi in rigid.bodies.size():
		var b: Dictionary = rigid.bodies[bi]
		var wi := int(b["wi"])
		# ...A DORMANT ONE ([RigidParts]), untouched as built and taken up by no act now: nothing of it to reckon - the solver says
		# whether something comes to it
		if bool(b.get("dormant", false)) and not _held_at(wi, t):
			b["seat_skip"] = PackedInt32Array()
			continue
		var n0 := _rest_of(wi)
		var now := rigid.motion(bi) * n0
		var moving := _held_at(wi, t)
		var held: Variant = _held_pose(wi, t, now) if moving else _held_aloft(bi, wi, t)
		b["seat_skip"] = PackedInt32Array()
		# A PART IN ITS SEAT GOES WITH ITS SEAT, unless its own move takes it out ([method _with_seat]): a cork carried with its
		# jar, however its keys were written, or let go seated in its neck - welded there, eased onto it, and woken by nothing
		# but a hand taking it out
		var seat := _seated(b, wi, now)
		var weld := false
		if seat >= 0:
			if held != null:
				weld = moving and _with_seat(wi, seat, t)
			else:
				# ...welded already, let go there by a hand this moment, or come to rest snug in it by itself - never pulled in
				# from where it fell
				weld = (rigid.welded(bi) and int(b["weld"]) == seat) or b["held"] != null or not _off_seat(seat, wi, now, SEAT_SNUG, SEAT_SNUG_TILT)
		if weld:
			if not rigid.welded(bi) or int(b["weld"]) != seat:
				_weld(bi, seat)
			continue
		if rigid.welded(bi):
			rigid.unweld(bi)
		if held == null:
			if b["held"] != null:
				b["held"] = null
				# ...A HAND LETS GO GENTLY: lowered onto what takes it, never dropped
				rigid.guide(bi)
			continue
		# ...EASED INTO ITS SEAT OR OUT OF IT BY A HAND, it never meets its seat: the hand knows a fit the set dresser made to
		# the millimeter, which the solver's points are coarser than ([method _seat])
		var skip := PackedInt32Array()
		for si in b.get("seat", PackedInt32Array()):
			if not _off_seat(si, wi, now, SEAT_REACH, SEAT_TURN):
				skip.append(si)
		# ...AND A TOOL PAINTING A SURFACE IS LAID ON IT, never pushed off it ([TablePaint]): a brush's hairs and a sponge's face meet
		# what they paint as the hand means them to, and the bake leaves the tool where its law puts it
		if moving:
			skip.append_array(_painted_by(wi, t))
		b["seat_skip"] = skip
		var was: Variant = null
		if b["held"] != null:
			was = _held_pose(wi, t - dt, now) if _held_at(wi, t - dt) else _held_aloft(bi, wi, t - dt)
		b["held"] = (held as Transform3D) * n0.affine_inverse()
		b["held_from"] = (was as Transform3D) * n0.affine_inverse() if was != null else rigid.motion(bi)
	rigid.step(dt, {"solids": solids, "top": 0.0, "spheres": {"x": sim.x, "r": sim.r, "alive": sim.alive, "n": sim.n, "touch": sim.touch,
		"host": sim.host, "asleep": sim.asleep}})
	_posed_now()


## IN ITS SEAT - a stopper in its jar's neck, a lid on its crock, a vial in its rack, a ladle on its rest: the seat (what of its
## own thing rigid part body [param b] was built touching) it sits on now within [constant SEAT_NEAR] and [constant SEAT_TILT]
## of how it sat there as built (its node at [param now]), the nearest - or -1.
func _seated(b: Dictionary, wi: int, now: Transform3D) -> int:
	var seats: PackedInt32Array = b.get("seat", PackedInt32Array())
	if seats.is_empty():
		return -1
	var built := _rest_of(wi)
	var best := -1
	var least := INF
	for si in seats:
		var sd: Dictionary = solids[si]
		if not bool(sd.get("on", true)) or _off_seat(si, wi, now, SEAT_NEAR, SEAT_TILT):
			continue
		var d := ((sd["xf"] as Transform3D).affine_inverse() * now).origin.distance_to(((sd["rest"] as Transform3D).affine_inverse() * built).origin)
		if d < least:
			least = d
			best = si
	return best


## WELDED TO ITS SEAT: rigid part body [param bi] sits on solid [param si] exactly as it was built there, eased onto it, asleep
## on it and woken by nothing but a hand ([method RigidParts.weld]) - a fit the set dresser made is a rest, and the solver's
## points are coarser than a cork's cap on a lip 5 mm wide. (841899: the frankincense cork, set down in its jar, fell through the
## neck into it; the brimstone's cork, put back a few millimeters off its seat, went in sideways and stuck there; and both, let
## go seated after their jars were fetched, were woken as the jars settled and trembled 3 mm about their necks for seconds.)
func _weld(bi: int, si: int) -> void:
	var sd: Dictionary = solids[si]
	var wi := int((rigid.bodies[bi] as Dictionary)["wi"])
	# ...its motion from as built, in its seat's space, as it was built: the seat's own motion
	var rel := (sd["rest"] as Transform3D).affine_inverse()
	rigid.weld(bi, si, rel, sd["xf"])


## WHETHER RIGID PART [param wi]'s MOVE AT [param t] CARRIES IT WITH SEAT [param si], never out of it: through the whole move,
## as the plan has the part and the seat, it stays within [constant SEAT_NEAR] and [constant SEAT_TILT] of how it sat there as
## built. A cork carried with its jar rides it so whatever its keys say - 841899's sulfur cork, its last key half a centimeter
## above its jar's, had a hand of its own and wandered through the neck - and a cork drawn out of its jar is a move of its own.
func _with_seat(wi: int, si: int, t: float) -> bool:
	var own := _ch_of(wi)
	var e: Dictionary = {}
	for x in twin._chan.get(own, []):
		# ...the move under way - or the one just ended, which the hand still holds it by for HOLD_GAP ([method _held_at])
		if t >= float((x as Dictionary)["s0"]) and t < float((x as Dictionary)["s1"]) + HOLD_GAP:
			e = x
	if e.is_empty():
		return false
	var key := "%s|%s|%s|%d" % [own, str(e.get("t0")), str(e.get("s0")), si]
	if _with_seat_of.has(key):
		return bool(_with_seat_of[key])
	var sd: Dictionary = solids[si]
	# Compare the commands before automatic clearance: a jar's foot must clear obstacles its cork already stands above.
	# Those two corrected paths can be centimeters apart. Only an actual seat permits this shared motion; equal paths
	# on separate jars never create a connection. The seat constraint, rather than a second kinematic weld, carries it.
	if sd.has("body"):
		var carrier := int((rigid.bodies[int(sd["body"])] as Dictionary)["wi"])
		for move in twin._chan.get(_ch_of(carrier), []):
			if not is_equal_approx(float(move["s0"]), float(e["s0"])) or not is_equal_approx(float(move["s1"]), float(e["s1"])):
				continue
			var a: Dictionary = (e["track"] as Dictionary).duplicate()
			var b: Dictionary = (move["track"] as Dictionary).duplicate()
			for field in ["thing", "part", "_wi", "_ti", "_ch", "_hand", "_trip", "about"]:
				a.erase(field)
				b.erase(field)
			if a == b:
				_with_seat_of[key] = true
				return true
	var built := (sd["rest"] as Transform3D).affine_inverse() * _rest_of(wi)
	var with := true
	for k in 9:
		var T := lerpf(float(e["s0"]), float(e["s1"]) - 1e-4, float(k) / 8.0)
		var part: Transform3D = twin._eval(e, T - float(e["t0"]), T)
		var rel := _planned_solid(si, T).affine_inverse() * part
		# ...seated where the move begins and ends, as its keys have it - and on the way never further off than two hands'
		# bows and sways could carry it (a cork's own hand and its jar's bowed 1.7 cm apart, 841899's sulfur)
		var ends := k == 0 or k == 8
		if rel.origin.distance_to(built.origin) > (SEAT_NEAR if ends else SEAT_RIDE.x) \
				or Quaternion(rel.basis.orthonormalized()).angle_to(Quaternion(built.basis.orthonormalized())) > (SEAT_TILT if ends else SEAT_RIDE.y):
			with = false
			break
	_with_seat_of[key] = with
	return with


## Solid [param si] where the plan has it at show time [param T] (the table's space): moved with the body it is a part of by
## that body's own moves, else where it was built.
func _planned_solid(si: int, T: float) -> Transform3D:
	var sd: Dictionary = solids[si]
	if sd.has("body"):
		var key := int((rigid.bodies[int(sd["body"])] as Dictionary)["wi"])
		var ch := _ch_of(key)
		if twin._chan.has(ch):
			return (twin.value(ch, T) as Transform3D) * _rest_of(key).affine_inverse() * (sd["rest"] as Transform3D)
	return sd["rest"]


## Whether rigid part [param wi], its node at [param now], is further than [param near] meters or [param turn] radians from how it
## sat on solid [param si] as built.
func _off_seat(si: int, wi: int, now: Transform3D, near: float, turn: float) -> bool:
	var sd: Dictionary = solids[si]
	var was := (sd["rest"] as Transform3D).affine_inverse() * _rest_of(wi)
	var is_now := (sd["xf"] as Transform3D).affine_inverse() * now
	return is_now.origin.distance_to(was.origin) > near \
		or Quaternion(is_now.basis.orthonormalized()).angle_to(Quaternion(was.basis.orthonormalized())) > turn


## HELD UP BETWEEN ITS MOVES ([method TableWork._held_up]): where the hand holds rigid part [param wi] (body [param bi]) at
## [param t], between two of its moves, when the first left it where it would fall - where that move left it, swaying as the
## work sways it - or null, and the hand lets it go, gently ([method RigidParts.guide]): it rests where it is, held up from
## below ([method RigidParts.supported]), or stands in a vessel and leans there ([method _stands_in]), or no move takes it up
## again. Asked once a move, as it ends. (841899 played live: the ladle stood down into its pot, the words before the stir longer than the
## puppeteer's rehearsal, was let go a quarter second after its move and fell into the pot - where the work, the act's check
## and the rehearsal all had the hand holding it until the stir.)
func _held_aloft(bi: int, wi: int, t: float, li := -1) -> Variant:
	if twin._group_of.has(wi):
		return null
	var own := _ch_of(wi)
	var last: Dictionary = {}
	var next: Dictionary = {}
	for e in twin._chan.get(own, []):
		var ed: Dictionary = e
		if float(ed["s1"]) <= t:
			last = ed
		elif float(ed["s0"]) > t:
			next = ed
			break
	# ...ONLY ACROSS A HAND'S PAUSE ([constant HOLD_MOST]): its next move begins that soon after this one ends, or the hand lets it
	# go now, gently - it is set down where it is, into the vessel under it or onto what is under it, and the next move takes it up
	# from there. A hand nobody sees holding a thing still in the air is a thing floating (2026-11-01, feedback 0001-0002: the
	# ladle over the cauldron and the pestle over its mortar, each held for the words before the next act, 15 s); and how long
	# that is was never the puppeteer's to know - a live reading places an act only once its word is heard. So nothing here looks
	# further ahead than a pause.
	# ...and THROUGH ITS OWN ACT: between two tracks of one act, the hand is still at work with it (a cup held under the water
	# between its dip and its drawing up)
	# ...AND WHILE ITS NEXT ACT IS STILL TO COME, a pause at most (2026-11-01, feedback 0004: the pour's end came before the word its way
	# home is cued at was heard - a live reading places an act only then - where an export, its words all known, held it)
	if last.is_empty() or bool((last["track"] as Dictionary).get("down", false)):
		return null
	var key := str(last.get("t0")) + "|" + own + "|" + str(last.get("s0"))
	# ...ONLY WHAT WOULD FALL: what rests where it is - held up from below, its middle over what holds it - is let go, and so is
	# what stands in a vessel, to lean there as a ladle left in its pot leans on the rim; touching is not resting (841899: the
	# ladle held over the cauldron after its dip grazed the rim, and the ladle held over the vial after its pour grazed the vial
	# - each let go as "touching", each fell; and the ladle stood upright in the brew was held there, swaying, for 14 s)
	if not _held.has("aloft|" + key):
		_held["aloft|" + key] = _loose_would_fall(li) if li >= 0 else _would_fall(bi, key)
	var ended := float(last["s1"])
	var to_come := next.is_empty() and _to_come(own, last)
	if not bool(_held["aloft|" + key]):
		# ...BUT WHAT STANDS IN A VESSEL, TAKEN UP AGAIN IN A MOMENT, IS NOT DROPPED FOR THE MOMENT (841899, ladle-in-1 and its stir 1.6 s apart: let go 15 cm up, it
		# fell against the wall and lay down, and was hauled upright again 6.6 cm in 0.6 s). No hand lets go of what it is about to stir with.
		if not bool(_held.get("stands|" + key, false)) or not _holds_across(last, next, to_come) or (next.is_empty() and t - ended > HOLD_MOST):
			return null
	var back_at := INF
	if not _holds_across(last, next, to_come) or (next.is_empty() and t - ended > HOLD_MOST):
		# ...PAST A PAUSE: let go, unless it would come down badly - then held for a move that soon, or while one is to come, or put back
		if li >= 0 or not _lands_ill(key):
			return null
		if next.is_empty():
			if to_come and t - ended <= HOLD_ILL:
				pass
			else:
				back_at = ended + (HOLD_ILL if to_come else HOLD_MOST)
		elif float(next["s0"]) - ended > HOLD_ILL:
			back_at = ended + HOLD_MOST
		if t >= back_at + BACK_TIME:
			return null
	# ...where the move left it, as the bake had the move go ([method _held_pose])
	var s1 := ended - 1e-4
	var end: Transform3D = twin._eval(_held[key], s1 - float(last["t0"]), s1) if _held.has(key) else last["end"]
	if t > back_at:
		return _put_back(own, last, key, end, (t - back_at) / BACK_TIME)
	var up := smoothstep(0.0, TableWork.HOLD_IN, t - float(last["s1"])) * (smoothstep(0.0, TableWork.HOLD_IN, float(next["s0"]) - t) if not next.is_empty() else 1.0)
	var dr: Array = Hands.drift(t, int((last["track"] as Dictionary).get("_hand", 0)), up * Hands.HOLD_SWAY)
	return Transform3D((dr[1] as Basis) * end.basis, end.origin + (dr[0] as Vector3))


## WOULD WHAT MOVE [param key] LEFT COME DOWN BADLY, let go where it is? - as its trial found ([method _would_fall], kept for the move), it
## tumbled: a mortar over a cauldron's rim tips off it; a ladle over its pot leans there, and a rod over the table lies down
## flat, and those are let go.
func _lands_ill(key: String) -> bool:
	return bool(_held.get("ill|" + key, false))


## WHERE A HAND PUTS BACK WHAT IT CANNOT LET GO, [param u] of the way ([constant BACK_TIME]): from [param end], where move [param last] on
## channel [param own] left it, to where it last rested - where the move that took it up began (the bake's own place for it,
## [method _held_pose]), through any moves since that left it in the air.
func _put_back(own: String, last: Dictionary, key: String, end: Transform3D, u: float) -> Transform3D:
	if not _held.has("back|" + key):
		var list: Array = twin._chan.get(own, [])
		var took: Dictionary = last
		for k in range(list.size() - 1, -1, -1):
			var e: Dictionary = list[k]
			if float(e["s0"]) > float(last["s0"]):
				continue
			took = e
			if k == 0 or bool(((list[k - 1] as Dictionary)["track"] as Dictionary).get("down", false)):
				break
		var key0 := str(took.get("t0")) + "|" + own + "|" + str(took.get("s0"))
		_held["back|" + key] = ((_held[key0] as Dictionary)["from"] if _held.get(key0) is Dictionary else took["from"]) as Transform3D
	var rest: Transform3D = _held["back|" + key]
	var seed := int((last["track"] as Dictionary).get("_hand", 0))
	var lin := clampf(u, 0.0, 1.0)
	var r := Basis(Quaternion(end.basis.orthonormalized()).slerp(Quaternion(rest.basis.orthonormalized()), Hands.timing(lin)))
	return Transform3D(r, Hands.carried(end.origin, rest.origin, Vector3.ZERO, Vector3.ZERO, BACK_LIFT, lin, seed))


## WHETHER A HAND HOLDS WHAT MOVE [param last] LEFT, until move [param next] on the same thing (empty: none placed yet - [param
## to_come], a later act moves it all the same, its word not yet heard): never what it set down; across a pause ([constant
## HOLD_MOST]) or within one act; and while one is to come, for a pause ([method _held_aloft]). What a plan's change turns here is
## baked again from the end of [param last] ([method replan]).
static func _holds_across(last: Dictionary, next: Dictionary, to_come: bool) -> bool:
	if bool((last["track"] as Dictionary).get("down", false)):
		return false
	if next.is_empty():
		return to_come
	return float(next["s0"]) - float(last["s1"]) <= HOLD_MOST or String(next.get("act", "")) == String(last.get("act", "")) \
		or is_equal_approx(float(next["t0"]), float(last["t0"]))


## Whether an act after the one that left channel [param own] with move [param last] moves it again and is not placed yet - a live
## reading places an act only once its word is heard (the acts are in the order the reader cues them).
func _to_come(own: String, last: Dictionary) -> bool:
	var placed := {}
	for r in twin.runs:
		placed[int((r as Dictionary)["i"])] = true
	for ai in range(int(last.get("i", -1)) + 1, twin.acts.size()):
		if placed.has(ai):
			continue
		for tr in (twin.acts[ai] as Dictionary)["tracks"]:
			if String((tr as Dictionary).get("_ch", "")) == own:
				return true
	return false


## WOULD IT FALL, LET GO? - loose thing [param li], a body of spheres: any of them further over what is under it than
## [constant FALL_LEAST] (the table's top, or a solid found going down from it), its lowest the least - the rigid trial's own
## measure ([method _would_fall]), found by looking down.
func _loose_would_fall(li: int) -> bool:
	var L: Dictionary = loose[li]
	if int(L["body"]) < 0:
		return false
	var least := INF
	for i in ((sim.bodies[int(L["body"])] as Dictionary)["ids"] as PackedInt32Array):
		if sim.alive[i] != 1:
			continue
		least = minf(least, _drop_under(sim.x[i], sim.r[i]))
	return least > FALL_LEAST and least < INF


## How far a sphere at [param p] of radius [param r] falls before it meets the table's top or a solid under it (meters), looked at
## down to [constant FALL_LEAST] and a step past it.
func _drop_under(p: Vector3, r: float) -> float:
	var to_top := p.y - r
	var step := 0.003
	var d := 0.0
	while d < minf(to_top, FALL_LEAST + step):
		var q := p - Vector3(0.0, d, 0.0)
		for sd in solids:
			if not bool((sd as Dictionary).get("on", true)) or not ((sd as Dictionary)["wbox"] as AABB).grow(r).has_point(q):
				continue
			if ((sd as Dictionary)["field"] as ShapeField).sample(((sd as Dictionary)["inv"] as Transform3D) * q).x < r:
				return d
		d += step
	return to_top


## WOULD IT FALL, LET GO? Rigid body [param bi] let go where it is now and tried alone for [constant LAND_TRIAL] seconds ([method
## RigidParts.trial]): it falls when its lowest point goes down more than [constant FALL_LEAST], or is still going down at the end, or
## it turns past [constant LAND_TILT] - off a hand holding it up in the air, off an edge, over a rim - and otherwise comes to rest about
## where it is: on what holds it up, sitting on a rim. What it found is kept for the move ([param key], [method _lands_ill]). What stands in a vessel ([method _stands_in]) is caught by it, and leans there. A hand lets go of all of that, gently, and
## holds only what would fall. ONE TEST FOR EVERY SHAPE (next/table_physics.md, "Primitives"): the rule it took the place of - held up
## from below with its middle over what holds it ([method RigidParts.supported]) - missed a shape (the-quiet-
## crucible 841899, 2026-10-31: the ladle put back on its rest and its block was read as not held up, and the hand held it there,
## swaying, for two and a half minutes - the user: "this ladle will not settle, it's moving around on its block").
func _would_fall(bi: int, key: String) -> bool:
	# ...what stands in a vessel is caught by it, and leans there: a ladle left in its pot
	if _stands_in(bi):
		_held["stands|" + key] = true
		return false
	# ...tried long enough to see it: tipping over a rim begins slowly - 841899's mortar, tried for 1.2 s, had turned 13 degrees and dropped
	# 8 mm, was judged at rest there, and a moment later was on the table
	var tr := rigid.trial(bi, LAND_TRIAL, 1.0 / float(FPS))
	_held["ill|" + key] = float(tr["turned"]) > LAND_TILT and float(tr["drop"]) > LAND_DROP and not _stands_in_at(bi, tr["pose"])
	return float(tr["drop"]) > FALL_LEAST or bool(tr["falling"])


## WHETHER RIGID BODY [param bi] STANDS IN A VESSEL: its lowest point inside another's inside, [constant STANDS_IN] or more
## under that vessel's rim - a ladle left in its pot, a pestle in its mortar, a stirring rod in a jar - so a hand that is done
## with it lets it lean there ([method _held_aloft]).
func _stands_in(bi: int) -> bool:
	return _stands_in_at(bi, rigid.motion(bi))


## ...posed [param d] (the rigid motion from where it was built).
func _stands_in_at(bi: int, d: Transform3D) -> bool:
	var b: Dictionary = rigid.bodies[bi]
	var low := Vector3.INF
	for q in (b["pts"] as PackedVector3Array):
		var p := d * q
		if p.y < low.y:
			low = p
	if low == Vector3.INF:
		return false
	var own: PackedInt32Array = b["solids"]
	for L in liquids:
		var si := int((L as Dictionary)["solid"])
		var sd: Dictionary = solids[si]
		if own.has(si) or not bool(sd.get("on", true)) or not (sd["wbox"] as AABB).has_point(low):
			continue
		var vs: Vessel = (L as Dictionary)["vessel"]
		if not vs.contains((sd["inv"] as Transform3D) * low):
			continue
		var rim := INF
		for r in vs.rim:
			rim = minf(rim, ((sd["xf"] as Transform3D) * r).y)
		if rim - low.y >= STANDS_IN:
			return true
	return false


## The twin told where each rigid body is now: its node's pose, which every part of it hangs from ([member TableWork.posed],
## a whole thing's [member TableWork.posed_things]).
func _posed_now() -> void:
	for bi in rigid.bodies.size():
		var wi := int((rigid.bodies[bi] as Dictionary)["wi"])
		if wi >= 0:
			twin.posed[wi] = rigid.motion(bi) * _rest_of(wi)
		else:
			twin.posed_things[-1 - wi] = rigid.motion(bi) * _rest_of(wi)


# --- what swings ------------------------------------------------------------------------------------------

## THE HINGES THAT HANG FREE, and what hangs from them (the user, 2026-10-29, of a balance whose beam the puppeteer tipped
## while the lump laid on its pan stayed where it was: "the weight never transfers to the scale. So we definitely need
## physics there"): a hinge on a level axis whose own weight hangs below its pivot - a balance's beam, a pendulum, a sign
## on its hook - swings by that weight and by what lies on it, and no act turns it. A part of it with no joint of its own
## whose middle hangs below the pivot hangs from its top, level, as a balance's pans hang from the beam's ends: its weight
## and what lies in it pull at where it hangs, wherever in it they lie. Empty, each rests as it was built.
func _find_swings() -> void:
	for wi in work.works.size():
		var wk: Dictionary = work.works[wi]
		if String(wk["kind"]) != "hinge" or work._runs_of.has("w%d:angle" % wi) or not work._rest.has("w%d:pose" % wi):
			continue
		var jt: Dictionary = (wk["w"] as Dictionary)["joint"]
		var rest: Transform3D = work._rest["w%d:pose" % wi]
		var axis := (rest.basis * (jt["axis"] as Vector3)).normalized()
		if absf(axis.y) > 0.5:
			continue
		var pivot := rest * (jt["pivot"] as Vector3)
		# its own: itself and every part of it with no joint, but those that hang
		var mine: Array = [wi]
		var hangs: Array = []
		for c in work.works.size():
			if int(work._parent_work.get(c, -1)) != wi or String((work.works[c] as Dictionary)["kind"]) != "":
				continue
			var cb := _box_of(_unjointed([c]))
			if cb.size == Vector3.ZERO:
				continue
			# ...from its top, never higher than the pivot: a pan's strands meet the beam's end at the beam's own height (a
			# strand's own thickness above it had hung both pans over the pivot, and the empty balance fell to its stop)
			if cb.get_center().y < pivot.y:
				hangs.append([c, Vector3(cb.get_center().x, minf(cb.end.y, pivot.y), cb.get_center().z)])
			else:
				mine.append(c)
		var own := {}
		var m := 0.0
		var c_sum := Vector3.ZERO
		var i0 := 0.0
		var away: Array = hangs.map(func(h: Array) -> int: return int(h[0]))
		for si in _solids_of(_unjointed(mine, away)):
			own[si] = true
			var ms := _mass_of(si)
			var arm := (ms["c"] as Vector3) - pivot
			m += float(ms["m"])
			c_sum += (ms["c"] as Vector3) * float(ms["m"])
			i0 += axis.dot((ms["i"] as Basis) * axis) + float(ms["m"]) * (arm - axis * arm.dot(axis)).length_squared()
		if m <= 0.0:
			continue
		var d := c_sum / m - pivot
		d -= axis * d.dot(axis)
		var drop := -d.y
		if drop < SWING_HANG or drop < sqrt(maxf(d.length_squared() - drop * drop, 0.0)):
			continue
		var inv := rest.affine_inverse()
		var under := {}
		var hung: Array = []
		for k in hangs.size():
			var c := int(hangs[k][0])
			var top: Vector3 = hangs[k][1]
			var mk := 0.0
			for si in _solids_of(_unjointed([c])):
				under[si] = k
				mk += float(_mass_of(si)["m"])
			hung.append({"wi": c, "at": inv * top, "m": mk})
			var crest: Transform3D = work._rest["w%d:pose" % c]
			work.hung[c] = {"from": wi, "at": crest.affine_inverse() * top, "axis": (crest.basis.inverse() * axis).normalized()}
		var rg: Variant = jt.get("range")
		var s := {"wi": wi, "pivot": jt["pivot"], "axis": (jt["axis"] as Vector3).normalized(), "c": inv * (c_sum / m), "m": m, "i0": i0,
			"hung": hung, "own": own, "under": under, "a": 0.0, "w": 0.0, "rest": false, "still": 0.0, "sig": 0, "moved": false,
			"range": Vector2(deg_to_rad((rg as Vector2).x), deg_to_rad((rg as Vector2).y)) if rg is Vector2 else Vector2(-PI, PI) * 0.95}
		# TRUED AS BUILT: empty, it rests where it was built, as a balance's nut sets it level - whatever its making leaves
		# it leaning by (two pans a tenth of a millimeter apart in their arms had tipped an empty balance to its stop)
		var none := PackedFloat32Array()
		none.resize(hung.size())
		s["tare"] = -_swing_pull(s, twin._base_world(wi, 0.0), Vector3(0.0, -GRAVITY, 0.0), [[], none], 0.0).x
		s["rest"] = true
		_swing_at[wi] = _swing.size()
		_swing.append(s)
		work.swings[wi] = rad_to_deg(float(s["a"]))
		twin.swung[wi] = rad_to_deg(float(s["a"]))
		for a in work.acts:
			for tr in (a as Dictionary)["tracks"]:
				if String((tr as Dictionary).get("_ch", "")) == "w%d:angle" % wi:
					notes.append("%s: %s swings by its own weight and what is laid on it - no act turns it" % [String((a as Dictionary)["name"]), work._part_label(wi)])
	# ...and which of them moves each solid
	for sd in solids:
		var d: Dictionary = sd
		var on: Array = []
		var c := int(d["wi"])
		while c >= 0:
			if _swing_at.has(c):
				on.append(int(_swing_at[c]))
			if work.hung.has(c):
				on.append(int(_swing_at[int((work.hung[c] as Dictionary)["from"])]))
			c = int(work._parent_work.get(c, -1))
		d["swings"] = on


## [param list]'s works and every part of them with no joint of its own, all the way down - but [param away]'s.
func _unjointed(list: Array, away: Array = []) -> Array:
	var out: Array = list.duplicate()
	var k := 0
	while k < out.size():
		for c in work.works.size():
			if int(work._parent_work.get(c, -1)) == int(out[k]) and String((work.works[c] as Dictionary)["kind"]) == "" and not out.has(c) \
					and not away.has(c):
				out.append(c)
		k += 1
	return out


## The solids of the works [param list].
func _solids_of(list: Array) -> PackedInt32Array:
	var out := PackedInt32Array()
	for si in solids.size():
		if list.has(int((solids[si] as Dictionary)["wi"])):
			out.append(si)
	return out


## The box the solids of works [param list] fill as built (the table's space).
func _box_of(list: Array) -> AABB:
	var box := AABB()
	var first := true
	for si in _solids_of(list):
		var b: AABB = ((solids[si] as Dictionary)["rest"] as Transform3D) * ((solids[si] as Dictionary)["box"] as AABB)
		box = b if first else box.merge(b)
		first = false
	return box


## SOLID [param si]'s MASS as built: `{m}` kilograms, its middle `c` (the table's space), its inertia `i` about that middle (a
## Basis, the table's space, kilogram square meters) - its field sampled over its box, each cell inside a share of its
## material's density. Too thin for the cells, it is its box a third full.
func _mass_of(si: int) -> Dictionary:
	var sd: Dictionary = solids[si]
	if sd.get("mass") != null:
		return sd["mass"]
	var f: ShapeField = sd["field"]
	var box: AABB = sd["box"]
	var xf: Transform3D = sd["rest"]
	var mat: Variant = work.materials.get(String((sd["part"] as Dictionary).get("material", "")))
	var md: Dictionary = mat if mat is Dictionary else {}
	var rho := float(md.get("density", (Props.MATERIALS.get(String(md.get("kind", "painted")), Props.MATERIALS["painted"]) as Dictionary)["density"])) * 1000.0
	var cell := maxf(minf(box.size.x, minf(box.size.y, box.size.z)) / 3.0, 0.0008)
	var n := Vector3i(clampi(int(ceil(box.size.x / cell)), 2, MASS_CELLS), clampi(int(ceil(box.size.y / cell)), 2, MASS_CELLS),
		clampi(int(ceil(box.size.z / cell)), 2, MASS_CELLS))
	var step := box.size / Vector3(n)
	var pts := PackedVector3Array()
	for i in n.x:
		for j in n.y:
			for k in n.z:
				var q := box.position + step * Vector3(i + 0.5, j + 0.5, k + 0.5)
				if f.sample(q).x < 0.0:
					pts.append(xf * q)
	var dv := absf(xf.basis.determinant()) * step.x * step.y * step.z
	var out := {}
	if pts.is_empty():
		var size: Vector3 = box.size * xf.basis.get_scale()
		var m := rho * size.x * size.y * size.z / 3.0
		out = {"m": m, "c": xf * box.get_center(), "i": Basis.from_scale(Vector3(size.y * size.y + size.z * size.z,
			size.x * size.x + size.z * size.z, size.x * size.x + size.y * size.y) * (m / 12.0))}
	else:
		var c := Vector3.ZERO
		for p in pts:
			c += p
		c /= float(pts.size())
		var mi := rho * dv
		var ix := Vector3.ZERO
		var iy := Vector3.ZERO
		var iz := Vector3.ZERO
		for p in pts:
			var r := p - c
			var r2 := r.length_squared()
			ix += Vector3(r2 - r.x * r.x, -r.x * r.y, -r.x * r.z) * mi
			iy += Vector3(-r.y * r.x, r2 - r.y * r.y, -r.y * r.z) * mi
			iz += Vector3(-r.z * r.x, -r.z * r.y, r2 - r.z * r.z) * mi
		out = {"m": mi * float(pts.size()), "c": c, "i": Basis(ix, iy, iz)}
	sd["mass"] = out
	return out


## What pulls swinging hinge [param s] at angle [param a] (radians): its frame where its thing has it, before its joint
## [param b]; the pull of weight there [param g] (gravity, less the frame's own acceleration as it is carried); what lies on
## it [param loads] ([method _loads_on]) - its torque about its axis and its inertia about it, `(torque, inertia)`.
func _swing_pull(s: Dictionary, b: Transform3D, g: Vector3, loads: Array, a: float) -> Vector2:
	var r := Basis(s["axis"] as Vector3, a)
	var p0: Vector3 = s["pivot"]
	var pv := b * p0
	var ax := (b.basis * (s["axis"] as Vector3)).normalized()
	var cw := b * (p0 + r * ((s["c"] as Vector3) - p0))
	var tq := ax.dot((cw - pv).cross(g * float(s["m"]))) + float(s.get("tare", 0.0)) * g.length() / GRAVITY
	var inertia := float(s["i0"])
	var hung: Array = s["hung"]
	var on_hung: PackedFloat32Array = loads[1]
	for k in hung.size():
		var arm := b * (p0 + r * (((hung[k] as Dictionary)["at"] as Vector3) - p0)) - pv
		var mk := float((hung[k] as Dictionary)["m"]) + on_hung[k]
		tq += ax.dot(arm.cross(g * mk))
		inertia += mk * (arm - ax * arm.dot(ax)).length_squared()
	for l in loads[0]:
		var arm: Vector3 = ((l as Array)[0] as Vector3) - pv
		tq += ax.dot(arm.cross(g * float((l as Array)[1])))
		inertia += float((l as Array)[1]) * (arm - ax * arm.dot(ax)).length_squared()
	return Vector2(tq, inertia)


## Swinging hinge [param s] on [param h] seconds, pulled [param pull] (`(torque, inertia)`): its speed, its pivot's drag, its
## angle and its stops. Returns how hard it is pulled to turn (radians a second squared) - none against a stop it is
## pressed onto and still at.
func _swing_on(s: Dictionary, pull: Vector2, h: float) -> float:
	var acc := pull.x / maxf(pull.y, 1e-9)
	var w := (float(s["w"]) + acc * h) * exp(-SWING_DAMP * h)
	var a := float(s["a"]) + w * h
	var rg: Vector2 = s["range"]
	if a <= rg.x:
		a = rg.x
		w = -w * SWING_BOUNCE if w < 0.0 else w
		if acc < 0.0 and absf(w) < SWING_STILL.x:
			acc = 0.0
	elif a >= rg.y:
		a = rg.y
		w = -w * SWING_BOUNCE if w > 0.0 else w
		if acc > 0.0 and absf(w) < SWING_STILL.x:
			acc = 0.0
	s["a"] = a
	s["w"] = w
	return acc


## EACH SWINGING HINGE A FRAME ON, at show time [param t]: pulled by its weight, by what lies on it now and by its frame's
## own carrying - at rest, it stays so until what lies on it changes or it is carried.
func _swings_step(t: float, dt: float) -> void:
	for s in _swing:
		var sd: Dictionary = s
		var wi := int(sd["wi"])
		var b := twin._base_world(wi, t)
		var b1: Variant = sd.get("b1")
		var acc := Vector3.ZERO
		if b1 != null and sd.get("b2") != null:
			acc = ((b.origin - 2.0 * (b1 as Transform3D).origin + (sd["b2"] as Transform3D).origin) / (dt * dt)).limit_length(30.0)
		var carried := b1 != null and not b.is_equal_approx(b1)
		sd["b2"] = b1 if b1 != null else b
		sd["b1"] = b
		var loads := _loads_on(sd)
		var sig := hash([roundi(_load_mass(loads[0]) * 1e4), Array(loads[1]).map(func(x: float) -> int: return roundi(x * 1e4))])
		sd["moved"] = false
		if bool(sd["rest"]) and not carried and sig == int(sd["sig"]):
			continue
		sd["rest"] = false
		sd["sig"] = sig
		var was := float(sd["a"])
		var g := Vector3(0.0, -GRAVITY, 0.0) - acc
		var turn := 0.0
		for k in SWING_STEPS:
			turn = _swing_on(sd, _swing_pull(sd, b, g, loads, float(sd["a"])), dt / float(SWING_STEPS))
		sd["moved"] = absf(float(sd["a"]) - was) > 1e-7
		if absf(float(sd["w"])) < SWING_STILL.x and absf(turn) < SWING_STILL.y and not carried:
			sd["still"] = float(sd["still"]) + dt
			if float(sd["still"]) >= SWING_REST:
				sd["rest"] = true
				sd["w"] = 0.0
		else:
			sd["still"] = 0.0
		twin.swung[wi] = rad_to_deg(float(sd["a"]))


## WHAT LIES ON SWINGING HINGE [param s] now: `[[[where, kilograms] on its own solids], [kilograms in each part hung from
## it]]` - a sleeper on what it sleeps on, one awake on what holds it up, a loose thing whole by any sphere of it, and a
## liquid in it.
func _loads_on(s: Dictionary) -> Array:
	var own: Array = []
	var hung := PackedFloat32Array()
	hung.resize((s["hung"] as Array).size())
	var on_own: Dictionary = s["own"]
	var on_hung: Dictionary = s["under"]
	var by_body := {}
	for i in sim.n:
		if sim.alive[i] == 0:
			continue
		var si := sim.host[i] if sim.asleep[i] == 1 else sim.touch[i]
		if si < 0 or (not on_own.has(si) and not on_hung.has(si)):
			continue
		if sim.body[i] >= 0:
			if not by_body.has(sim.body[i]):
				by_body[sim.body[i]] = si
			continue
		var m := 1.0 / maxf(sim.w[i], 1e-12)
		if on_hung.has(si):
			hung[int(on_hung[si])] += m
		else:
			own.append([sim.x[i], m])
	for bi in by_body:
		var si := int(by_body[bi])
		if on_hung.has(si):
			hung[int(on_hung[si])] += _body_mass(int(bi))
		else:
			own.append([(sim.bodies[int(bi)] as Dictionary)["c"], _body_mass(int(bi))])
	# ...a loose thing lying again on it ([method _rest_loose])
	for L in loose:
		var ld: Dictionary = L
		if int(ld["body"]) >= 0 or ld.get("rest") == null:
			continue
		var rh := int(ld.get("rest_host", -1))
		if not on_own.has(rh) and not on_hung.has(rh):
			continue
		if on_hung.has(rh):
			hung[int(on_hung[rh])] += float(ld.get("mass", 0.0))
		else:
			own.append([(((solids[rh] as Dictionary)["xf"] as Transform3D) * (ld["rest_hrel"] as Transform3D)).origin, float(ld.get("mass", 0.0))])
	# ...a part the work picks up, let go on it
	for b in rigid.bodies:
		var bd: Dictionary = b
		var si := int(bd["host"]) if bool(bd["asleep"]) else int(bd["touch"])
		if bd["held"] != null or si < 0 or (not on_own.has(si) and not on_hung.has(si)):
			continue
		if on_hung.has(si):
			hung[int(on_hung[si])] += float(bd["m"])
		else:
			own.append([bd["c"], float(bd["m"])])
	for li in liquids.size():
		var ls := int((liquids[li] as Dictionary)["solid"])
		if li >= _liq.size() or (not on_own.has(ls) and not on_hung.has(ls)):
			continue
		var m := float((_liq[li] as Dictionary)["v"]) * 1000.0
		if m <= 0.0:
			continue
		if on_hung.has(ls):
			hung[int(on_hung[ls])] += m
		else:
			own.append([((solids[ls] as Dictionary)["xf"] as Transform3D) * ((solids[ls] as Dictionary)["box"] as AABB).get_center(), m])
	return [own, hung]


static func _load_mass(own: Array) -> float:
	var m := 0.0
	for l in own:
		m += float((l as Array)[1])
	return m


## Whether any hinge is swinging.
func _swinging() -> bool:
	for s in _swing:
		if not bool((s as Dictionary)["rest"]):
			return true
	return false


## SWINGING HINGE [param wi]'s ANGLE at show time [param t] as baked (degrees), or null - not one, or nothing baked yet.
func swing_of(wi: int, t: float) -> Variant:
	var k := int(_swing_at.get(wi, -1))
	if k < 0:
		return null
	var f: Variant = frame_at(t)
	if f == null:
		return null
	var sw: PackedFloat32Array = (f as Dictionary).get("sw", PackedFloat32Array())
	return sw[k] if k < sw.size() else null


## Whether a sprinkle is letting grains fall at [param t].
func _sprinkling(t: float) -> bool:
	for s in _sprinkles:
		var sp := _sprinkle_span(s)
		if t >= sp.x and t <= sp.y:
			return true
	return false


func _sprinkle_span(s: Dictionary) -> Vector2:
	return _sprinkle_span_in(s, twin.runs)


## When sprinkle [param s] falls under the plan [param list] (its runs) - never, for one whose act is gone.
func _sprinkle_span_in(s: Dictionary, list: Array) -> Vector2:
	var ai := int(s["act"])
	if ai < 0:
		return Vector2(INF, INF)
	for r in list:
		if int((r as Dictionary)["i"]) == ai:
			var w := TableWork._window(s["track"])
			var t0 := float(r["t0"])
			var t1 := float(r["t1"])
			return Vector2(t0 + w.x * (t1 - t0), t0 + w.y * (t1 - t0))
	return Vector2(INF, INF)


## SPRINKLED GRAINS let fall from their point, as many by now as the stretch has let fall.
func _sprinkle_step(t: float, _dt: float) -> void:
	var mats: Dictionary = twin.materials
	for s in _sprinkles:
		var sd: Dictionary = s
		var sp := _sprinkle_span(sd)
		if t < sp.x or sp.x == INF:
			continue
		var tr: Dictionary = sd["track"]
		var n := int(tr.get("amount", 24))
		var due := mini(n, int(ceil(clampf((t - sp.x) / maxf(sp.y - sp.x, 1e-3), 0.0, 1.0) * float(n))))
		var done := int(sd.get("done", 0))
		if due <= done:
			continue
		var at := twin.place_of(tr.get("at", ""), twin.place_of(String(tr.get("thing", "")) + ".top", Vector3.ZERO, t), t)
		var rad := clampf(float(tr.get("grain", 0.3)) * 0.005, Particles.POWDER, Particles.SPHERE.y)
		var spread := float(tr.get("spread", 1.0)) * 0.01
		var mi := _matter_of(String(tr.get("material", "")), mats)
		for k in range(done, due):
			var j := Vector3(Hands.share(k, 1) - 0.5, 0.0, Hands.share(k, 2) - 0.5) * spread
			var i := sim.add(at + j, rad, mi, int(sd.get("owner", -1)), -2)
			if i >= 0 and int(sd.get("grains", -1)) >= 0:
				# a packed array is a value: grown, and put back
				var g: Dictionary = grains[int(sd["grains"])]
				var ids: PackedInt32Array = g["ids"]
				ids.append(i)
				g["ids"] = ids
		sd["done"] = due


## WHAT THE STEP SAID: things entering a liquid ring it, all of a frame's together - and a heavy thing entering fast
## splashes it, ONE THING AT A TIME: by its own mass and speed, never what the frame's grains add up to (the-quiet-crucible
## 707668's iron filings, tipped in a little at a time, summed to 37 splashes in five seconds and 64 drops in the air at
## once, 6 cm over the brew - the user: "the splash was far too intense: it splattered everywhere, which isn't really what
## you want hot liquid to do"). A grain weighs what it is drawn as, not the sphere that stands for a clump of them: fine
## stuff rings a surface and throws nothing.
func _events(t: float) -> void:
	var by := {}
	var each := {}
	for e in sim.events:
		var ed: Dictionary = e
		if String(ed["kind"]) == "cut":
			_cut(ed)
			continue
		if String(ed["kind"]) == "break" and ed.has("at"):
			_lock.lock()
			breaks.append({"t": t, "at": ed["at"], "size": float(ed["size"])})
			_lock.unlock()
			continue
		if String(ed["kind"]) != "enter":
			continue
		var li := int(ed["liquid"])
		if not by.has(li):
			by[li] = {"at": Vector3.ZERO, "m": 0.0, "n": 0}
		var b: Dictionary = by[li]
		b["at"] = (b["at"] as Vector3) + (ed["at"] as Vector3)
		b["m"] = float(b["m"]) + float(ed["strength"])
		b["n"] = int(b["n"]) + 1
		var i := int(ed["i"])
		var bi := sim.body[i]
		var key := bi if bi >= 0 else -1 - i
		if not each.has(key):
			each[key] = {"li": li, "at": ed["at"], "m": _body_mass(bi) if bi >= 0 else _grain_mass(i), "v": 0.0, "n": 0}
		each[key]["v"] = maxf(float(each[key]["v"]), float(ed["strength"]) * sim.w[i])
		each[key]["n"] = int(each[key]["n"]) + 1
	# ...as it first goes in: a thing whose spheres were in already splashed as it entered
	for key in each.keys():
		if int(key) >= 0:
			var wet := 0
			for i in (sim.bodies[int(key)] as Dictionary)["ids"]:
				wet += 1 if sim.alive[i] == 1 and sim.wet[i] == int(each[key]["li"]) else 0
			if wet > int(each[key]["n"]):
				each.erase(key)
	for li in by:
		var b: Dictionary = by[li]
		var at: Vector3 = (b["at"] as Vector3) / float(int(b["n"]))
		var size := clampf(float(b["m"]) * RING_GAIN, RING.x, RING.y)
		ripples.append({"t": t, "liquid": int(li), "at": at, "size": size})
		_dent(int(li), at, size)
	for key in each:
		var d: Dictionary = each[key]
		var count := mini(int(float(d["m"]) / SPLASH_MASS), DROPS_EACH) if float(d["v"]) >= SPLASH_SPEED else 0
		if count >= 1:
			splashes.append({"t": t, "at": d["at"], "count": count, "up": float(d["v"]) * SPLASH_UP,
				"color": (_liq[int(d["li"])] as Dictionary)["color"], "k": ripples.size()})


## A BLADE'S CUT ([method Particles._cut_through]): its two sides, each a piece of the loose thing it was cut from, drawn
## as that thing's mesh kept behind every cut it has had ([MeshCut]) - each cut a plane in the thing's own space, so a
## piece cut again keeps its first cut too.
func _cut(e: Dictionary) -> void:
	var bi := int(e["body"])
	var was: Transform3D = e["was"]
	var li := -1
	var d := Transform3D.IDENTITY
	var planes: Array = []
	if _piece_at.has(bi):
		var old: Dictionary = pieces[int(_piece_at[bi])]
		li = int(old["li"])
		d = was * (old["D"] as Transform3D)
		planes = (old["planes"] as Array).duplicate()
	else:
		for k in loose.size():
			if int((loose[k] as Dictionary)["body"]) == bi:
				li = k
		if li < 0:
			return
		d = was * ((loose[li] as Dictionary)["n0"] as Transform3D)
	var local: Plane = d.affine_inverse() * (e["plane"] as Plane)
	for side in [[bi, local], [int(e["new"]), -local]]:
		var ps := planes.duplicate()
		ps.append(side[1])
		var key := hash([li, ps.map(func(p: Plane) -> Array: return [p.normal.snapped(Vector3.ONE * 1e-4), snappedf(p.d, 1e-5)])])
		_piece_at[int(side[0])] = pieces.size()
		pieces.append({"li": li, "body": int(side[0]), "D": d, "planes": ps, "key": key})


## Loose thing [param bi]'s mass (kilograms): its spheres' still whole.
func _body_mass(bi: int) -> float:
	var m := 0.0
	for i in (sim.bodies[bi] as Dictionary)["ids"]:
		if sim.alive[i] == 1:
			m += 1.0 / maxf(sim.w[i], 1e-12)
	return m


## Grain [param i]'s mass (kilograms) as large as its part draws a grain - the sphere it is may stand for a clump.
func _grain_mass(i: int) -> float:
	var r := sim.r[i]
	var o := sim.owner[i]
	if o >= 0 and o < grains.size() and (grains[o] as Dictionary).get("part") is Dictionary:
		r = minf(r, float(((grains[o] as Dictionary)["part"] as Dictionary).get("grain", 0.3)) * 0.005)
	return sim.rho[i] * 1000.0 * 4.0 / 3.0 * PI * r * r * r


## The frame as it stands: every particle, each loose thing's pose and wholeness, each liquid.
func _record(_t: float) -> Dictionary:
	var bp := PackedVector3Array()
	var bi := PackedByteArray()
	var bo := PackedVector3Array()
	bo.resize(_bo_n)
	for L in loose:
		var lb := int((L as Dictionary)["body"])
		# one yet to be a body lies as it was built ([method pose_of]: none)
		var rested: Variant = (L as Dictionary).get("rest")
		var rh := int((L as Dictionary).get("rest_host", -1))
		if rested != null and rh >= 0 and rh < solids.size():
			rested = ((solids[rh] as Dictionary)["xf"] as Transform3D) * ((L as Dictionary)["rest_hrel"] as Transform3D)
		var pose: Transform3D = sim.body_pose(lb) * ((L as Dictionary)["n0"] as Transform3D) if lb >= 0 else (rested if rested != null else (L as Dictionary)["built"])
		bp.append_array([pose.basis.x, pose.basis.y, pose.basis.z, pose.origin])
		bi.append((RESTED if rested != null else LYING) if lb < 0 else (1 if bool((sim.bodies[lb] as Dictionary)["intact"]) else 0))
		# ...and a sheet's bend
		if bool((L as Dictionary)["soft"]):
			var at := int((L as Dictionary)["bo_at"])
			var off: Variant = _bent_built(L, sim.bodies[lb]) if lb >= 0 and (sim.bodies[lb] as Dictionary).has("links") else (L as Dictionary)["rest_off"]
			if off != null:
				for k in mini((off as PackedVector3Array).size(), ((L as Dictionary)["spheres"] as PackedVector3Array).size()):
					bo[at + k] = (off as PackedVector3Array)[k]
	var liq := PackedFloat32Array()
	var sunk := PackedByteArray()
	var waves: Array = []
	var dips := PackedVector2Array()
	var last_waves: Array = (frames[_k - 1] as Dictionary).get("waves", []) if _k > 0 and _k - 1 < frames.size() else []
	for li in _liq.size():
		var S: Dictionary = _liq[li]
		var st: Dictionary = S["w"]
		# its surface as bytes - none at rest, and the last frame's own where it has not moved since
		var wb: Variant = (liquids[li]["waves"] as SurfaceWaves).bytes(st) if bool(st["on"]) else null
		if wb != null and li < last_waves.size() and last_waves[li] != null and last_waves[li] == wb:
			wb = last_waves[li]
		waves.append(wb)
		dips.append(Vector2(_dip(li), float(S.get("r2", 0.0))))
		var n: Vector3 = S.get("n", Vector3.UP)
		var c: Vector3 = S.get("c", Vector3.ZERO)
		var col: Color = S["color"]
		var h: Vector4 = S["hit"]
		liq.append_array([float(S["v"]), n.x, n.y, n.z, c.x, c.y, c.z, float(S["angle"]), float(S.get("q", 0.0)), col.r, col.g, col.b,
			h.x, h.y, h.z, h.w])
		sunk.append(1 if bool(S.get("sunk", false)) and float(S["v"]) > 1e-10 else 0)
	# EVERYTHING THE PICTURE DRAWS is in the frame, made here, never read from the bake as it goes on: the streams in the air,
	# the rings on each surface, the drops of each splash
	# ...each array a copy of its own: one held in a Dictionary is the solver's own array, and every frame had been the latest
	# - or, where the solver moved nothing this frame, the last frame's own copies
	var last: Dictionary = frames[_k - 1] if _k > 0 and _k - 1 < frames.size() else {}
	var same := not sim.moved and not last.is_empty() and sprinkled_none(_t)
	# ...and what did not change since the last frame is the last frame's, whatever moved: a size, whether it is, what made
	# it and the body it is in change only as things break, dissolve or come to be
	var sw := PackedFloat32Array()
	for s in _swing:
		sw.append(rad_to_deg(float((s as Dictionary)["a"])))
	# ...ONLY THE BODIES WOKEN SO FAR, in the order they woke ([member _woke]): a dormant one is where it was built, and of a table's
	# hundred and fifty bodies a frame of a stir moves a few - every body's pose every frame had been 120 MB of a show's bake
	for rb in rigid.bodies.size():
		if _rank_of[rb] < 0 and not bool((rigid.bodies[rb] as Dictionary).get("dormant", false)):
			_rank_of[rb] = _woke.size()
			_woke.append(rb)
	var rp := PackedVector3Array()
	# ...and how far each held one is from where its hand has it, and what it last met: one held back ([method report])
	var rd := PackedFloat32Array()
	var rt := PackedInt32Array()
	for rb in _woke:
		var b: Dictionary = rigid.bodies[rb]
		var pose := rigid.motion(rb) * _rest_of(int(b["wi"]))
		rp.append_array([pose.basis.x, pose.basis.y, pose.basis.z, pose.origin])
		rd.append(RigidParts._span(b, rigid.motion(rb), b["held"]) if b["held"] != null else 0.0)
		rt.append(int(b.get("by", -1)))
	# ...AND WHICH THEY ARE, the frame's own COPY (the frame before's while no body woke): read from the app's thread, a body's place
	# is never looked up in what the bake keeps on changing - a plan taken up puts back the bodies woken since its checkpoint, and
	# the frames kept between it and the change had drawn those where they were built. A copy: a packed array held in a Dictionary
	# is the same array, and the frames had held [member _woke] itself, grown and cut as the bake went on (physics_check
	# `_frame_names_bodies`)
	return {"sw": sw, "bo": _kept(last, "bo", bo), "rp": _kept(last, "rp", rp), "rd": _kept(last, "rd", rd), "rt": _kept(last, "rt", rt), "rpn": _woke.size(),
		"wk": _kept(last, "wk", _woke),
		"x": last["x"] if same else sim.x.duplicate(), "r": _kept(last, "r", sim.r), "alive": _kept(last, "alive", sim.alive),
		"owner": _kept(last, "owner", sim.owner), "body": _kept(last, "body", sim.body), "bp": bp, "bi": bi, "liq": liq,
		"streams": _streams_at(_t), "rings": _rings_at(_t), "drops": _drops_at(_t), "cut": _cuts_now(), "waves": waves, "dips": dips, "sunk": sunk}


## The last frame's [param key] if [param now] is the same, else a copy of [param now].
static func _kept(last: Dictionary, key: String, now: Variant) -> Variant:
	if last.has(key) and last[key] == now:
		return last[key]
	return now.duplicate()


## EVERY PIECE A BLADE HAS CUT, where it is now: `[[key, loose thing, its planes, its pose (the table's space)]]` - and,
## its key -1 past the last, which bodies are pieces (a PackedByteArray by body), whose spheres are never drawn as lumps.
func _cuts_now() -> Array:
	var out: Array = []
	var cut := PackedByteArray()
	cut.resize(sim.bodies.size())
	for bi in sim.bodies.size():
		if bool((sim.bodies[bi] as Dictionary).get("cut", false)) and _piece_at.has(bi):
			var pc: Dictionary = pieces[int(_piece_at[bi])]
			out.append([int(pc["key"]), int(pc["li"]), pc["planes"], sim.body_pose(bi) * (pc["D"] as Transform3D)])
			cut[bi] = 1
	out.append([-1, cut])
	return out


## Whether no sprinkle let a grain fall at [param t] (a grain made then is in the solver, not yet in any frame).
func sprinkled_none(t: float) -> bool:
	return not _sprinkling(t)


## THE STREAMS in the air at [param t]: each run of parcels left one frame after another `{pts, rad, color}` - the youngest
## first, from the lip down.
func _streams_at(t: float) -> Array:
	var runs: Array = []
	var cur: Array = []
	var last_t := -INF
	var last_from := -1
	for pi in range(_recent(t), parcels.size()):
		var pd: Dictionary = parcels[pi]
		if float(pd["t0"]) > t or float(pd["t1"]) <= t:
			continue
		if not cur.is_empty() and (int(pd["from"]) != last_from or float(pd["t0"]) - last_t > 1.6 / float(FPS)):
			runs.append(cur)
			cur = []
		cur.append(pd)
		last_t = float(pd["t0"])
		last_from = int(pd["from"])
	if not cur.is_empty():
		runs.append(cur)
	var out: Array = []
	for run in runs:
		var pts := PackedVector3Array()
		var rad := PackedFloat32Array()
		for k in range((run as Array).size() - 1, -1, -1):
			var pd: Dictionary = run[k]
			var tau := t - float(pd["t0"])
			pts.append(_parcel_at(pd, tau))
			var sp := ((pd["v"] as Vector3) + Vector3.DOWN * GRAVITY * tau).length()
			rad.append(clampf(sqrt(float(pd["vol"]) * float(FPS) / (PI * maxf(sp, 0.05))), STREAM_R.x, STREAM_R.y))
		if pts.size() >= 2:
			out.append({"pts": pts, "rad": rad, "color": (run[0] as Dictionary)["color"]})
	return out


## THE RINGS on each liquid at [param t]: `[[{at, t, size}...] a liquid]`, the latest first, at most 12 each.
func _rings_at(t: float) -> Array:
	var out: Array = []
	for li in liquids.size():
		out.append([])
	for k in range(ripples.size() - 1, -1, -1):
		var rd: Dictionary = ripples[k]
		if float(rd["t"]) > t:
			continue
		if t - float(rd["t"]) > 1.6:
			break
		var list: Array = out[int(rd["liquid"])]
		if list.size() < 12:
			list.append(rd)
	return out


## THE SPLASHES' DROPS in the air at [param t]: each splash a few drops thrown up and out, falling back - `[[place, size,
## color]...]`.
func _drops_at(t: float) -> Array:
	var out: Array = []
	for k in range(splashes.size() - 1, -1, -1):
		var sp: Dictionary = splashes[k]
		var tau := t - float(sp["t"])
		if tau < 0.0:
			continue
		if tau > DROP_LIFE:
			break
		for j in int(sp["count"]):
			if out.size() >= DROPS:
				return out
			var a := TAU * Hands.share(int(sp["k"]) * 31 + j, 3)
			var up := lerpf(0.7, 1.0, Hands.share(int(sp["k"]) * 31 + j, 4)) * float(sp["up"])
			var vel := Vector3(cos(a) * up * 0.35, up, sin(a) * up * 0.35)
			var p := (sp["at"] as Vector3) + vel * tau + Vector3.DOWN * (0.5 * GRAVITY * tau * tau)
			if p.y < (sp["at"] as Vector3).y - 0.002:
				continue
			out.append([p, lerpf(0.0012, 0.0028, Hands.share(int(sp["k"]) * 31 + j, 5)), sp["color"]])
	return out


# --- the picture ------------------------------------------------------------------------------------------

## THE PHYSICS AT SHOW TIME [param t]: the bake asked to keep ahead (or, where a picture waits for it, run to [param t]),
## and its frame drawn - grains and pieces, the liquids' surfaces, the streams, the splashes.
func tick(t: float) -> void:
	# ...the copies drawn so the GPU had what the picture's own nodes need ([method _drawn_nodes]), let go once drawn
	if not _warm.is_empty():
		_warm_ticks += 1
		if _warm_ticks > WARM_TICKS:
			for n in _warm:
				if is_instance_valid(n):
					(n as Node).queue_free()
			_warm = []
	if _sync:
		bake_until(t)
	else:
		_lock.lock()
		_want = t + reach
		var behind := _t_of(_k) <= _want
		var at := _t_of(frames.size())
		_lock.unlock()
		if behind:
			_sem.post()
		# OUTRUN: the show past the last frame baked draws that frame (a loose thing the work has moved since is where the
		# work has it, [method TableWork._outran]) - said once a stretch, so a log says when what is in things lagged
		if (t > at + OUTRUN) != _outrun:
			_outrun = not _outrun
			print("ghost: what is in things %s (the show at %.1f s, baked to %.1f s)" % ["is behind the show" if _outrun else "caught up", t, at])
	var f: Variant = frame_at(t)
	if f == null:
		return
	var fd: Dictionary = f
	# the same frame as last drawn (a quiet stretch keeps one): nothing of it to draw again - by identity, never by value
	var c := Time.get_ticks_usec() if profiling_drawn else 0
	if not is_same(fd, _drawn):
		_draw_particles(fd)
		c = _drawn_spent("drawn: particles", c)
		_draw_streams(fd)
		_draw_drops(fd)
		_draw_pieces(fd)
		c = _drawn_spent("drawn: streams, drops, pieces", c)
		_drawn = fd
	_draw_liquids(fd, t)
	_drawn_spent("drawn: liquids", c)


## The picture's cost by section ([member drawn_profile]), while [member profiling_drawn].
func _drawn_spent(section: String, since: int) -> int:
	if not profiling_drawn:
		return 0
	var now := Time.get_ticks_usec()
	drawn_profile[section] = int(drawn_profile.get(section, 0)) + now - since
	return now


## The baked frame at [param t], or null when none is yet.
func frame_at(t: float) -> Variant:
	_lock.lock()
	var out: Variant = null
	if not frames.is_empty():
		out = frames[clampi(_k_of(t), 0, frames.size() - 1)]
	_lock.unlock()
	return out


## THE PIECES BROKEN OFF from [param t0] to [param t1] (show seconds), as the bake has them: `[{t, at, size}]`.
func breaks_in(t0: float, t1: float) -> Array:
	var out: Array = []
	_lock.lock()
	for b in breaks:
		if float((b as Dictionary)["t"]) >= t0 and float((b as Dictionary)["t"]) < t1:
			out.append(b)
	_lock.unlock()
	return out


## How far the bake has gone (show seconds): the last frame there is.
func baked_to() -> float:
	_lock.lock()
	var n := frames.size()
	_lock.unlock()
	return _t_of(n - 1)


## Where loose work [param wi]'s node is at [param t] (the table's space) - or a part the work picks up, a rigid body - or
## null.
func pose_of(wi: int, t: float) -> Variant:
	if _rigid_of.has(wi):
		var fr: Variant = frame_at(t)
		if fr == null:
			return null
		var k := _frame_rank(fr as Dictionary, int(_rigid_of[wi]))
		# ...one not woken by then is where it was built
		if k < 0:
			return _rest_of(wi)
		var rp: PackedVector3Array = (fr as Dictionary).get("rp", PackedVector3Array())
		if k * 4 + 3 >= rp.size():
			return null
		return Transform3D(Basis(rp[k * 4], rp[k * 4 + 1], rp[k * 4 + 2]), rp[k * 4 + 3])
	if not _loose_of.has(wi):
		return null
	var f: Variant = frame_at(t)
	if f == null:
		return null
	var li := int(_loose_of[wi])
	var bp: PackedVector3Array = (f as Dictionary)["bp"]
	if li * 4 + 3 >= bp.size() or ((f as Dictionary)["bi"] as PackedByteArray)[li] == LYING:
		return null
	# (one lying again where it came to rest, RESTED, is there)
	return Transform3D(Basis(bp[li * 4], bp[li * 4 + 1], bp[li * 4 + 2]), bp[li * 4 + 3])


## Loose work [param wi]'s pose as it was built (the table's space).
func loose_built(wi: int) -> Transform3D:
	return (loose[int(_loose_of[wi])] as Dictionary)["built"]


## WHETHER LOOSE WORK [param wi] IS A SHEET THAT BENDS ([method Particles.make_soft]).
func bends(wi: int) -> bool:
	return _loose_of.has(wi) and bool((loose[int(_loose_of[wi])] as Dictionary)["soft"])


## Sheet [param wi]'s points as it was built (the table's space), what its bend is told by ([SheetBend]). Made once, as the bake is begun.
func sheet_points(wi: int) -> PackedVector3Array:
	return (loose[int(_loose_of[wi])] as Dictionary)["spheres"]


## HOW SHEET [param wi] IS BENT AT [param t]: each of its points off where it would be in its own shape (from as it was built, meters) - null where no frame says. The frame's alone: any thread may ask.
func bend_of(wi: int, t: float) -> Variant:
	var f: Variant = frame_at(t)
	if f == null:
		return null
	var L: Dictionary = loose[int(_loose_of[wi])]
	var at := int(L["bo_at"])
	return ((f as Dictionary)["bo"] as PackedVector3Array).slice(at, at + (L["spheres"] as PackedVector3Array).size())


## Body [param bi]'s place among frame [param fr]'s bodies (its `wk`, the bodies woken by then), or -1: dormant then, where it
## was built. The frame's alone - any thread may ask.
func _frame_rank(fr: Dictionary, bi: int) -> int:
	var k := (fr.get("wk", PackedInt32Array()) as PackedInt32Array).find(bi)
	return k if k >= 0 and k < int(fr.get("rpn", 0)) else -1


## How far body [param bi] was from where its hand had it in frame [param fr] (meters; 0 not held), and what held it back then (a
## solid, or -1 for nothing) - a frame keeps only the bodies woken by then ([method _record]).
func held_off(fr: Dictionary, bi: int) -> float:
	var k := _frame_rank(fr, bi)
	var rd: PackedFloat32Array = fr.get("rd", PackedFloat32Array())
	return rd[k] if k >= 0 and k < rd.size() else 0.0


func held_by(fr: Dictionary, bi: int) -> int:
	var k := _frame_rank(fr, bi)
	var rt: PackedInt32Array = fr.get("rt", PackedInt32Array())
	return rt[k] if k >= 0 and k < rt.size() else -1


## WHETHER A LIVE SHOW AT [param t] WAITS FOR THE BAKE: its thread is less than [constant WAIT_UNDER] ahead, until it is
## [constant WAIT_AHEAD] ahead again. Drawn behind its bake, a thing an act moves was where its act sends it, through whatever
## was there, and the rest stood where the bake had last got to, and slid on as it caught up - "even when the video is paused"
## (841899, 2026-10-30). Never on the caller's thread (a render, a preview, a gate), which bakes to the moment it asks.
func behind(t: float) -> bool:
	if _sync:
		return false
	var ahead := baked_to() - t
	_behind = ahead < (WAIT_AHEAD if _behind else WAIT_UNDER)
	return _behind


## Where whole thing [param ti]'s node is at [param t] (the table's space), a rigid body - or null: no act moves it.
func thing_pose_of(ti: int, t: float) -> Variant:
	return pose_of(-1 - ti, t) if _rigid_of.has(-1 - ti) else null


## Whether loose work [param wi] is still whole at [param t] (broken, it is drawn as its pieces).
func whole(wi: int, t: float) -> bool:
	if not _loose_of.has(wi):
		return true
	var f: Variant = frame_at(t)
	if f == null:
		return true
	var bi: PackedByteArray = (f as Dictionary)["bi"]
	var li := int(_loose_of[wi])
	return li >= bi.size() or bi[li] != 0


## Whether work [param wi] is a liquid the physics keeps, and how full it is at [param t] (cubic meters), or -1.
func liquid_volume(wi: int, t: float) -> float:
	# ...the liquid each work is, found once (asked of every part every frame a live show draws)
	if _liquid_of_work.is_empty() and not liquids.is_empty():
		for li in liquids.size():
			var w := int((liquids[li] as Dictionary)["wi"])
			if w >= 0 and not _liquid_of_work.has(w):
				_liquid_of_work[w] = li
		_liquid_of_work[-2] = -1
	var li := int(_liquid_of_work.get(wi, -1))
	if li < 0 or ((liquids[li] as Dictionary)["nodes"] as Array).is_empty():
		return -1.0
	var f: Variant = frame_at(t)
	if f == null:
		return float((liquids[li] as Dictionary)["v0"])
	return float(((f as Dictionary)["liq"] as PackedFloat32Array)[li * 16])


func _draw_particles(f: Dictionary) -> void:
	var x: PackedVector3Array = f["x"]
	var r: PackedFloat32Array = f["r"]
	var alive: PackedByteArray = f["alive"]
	var owner: PackedInt32Array = f["owner"]
	var bi: PackedByteArray = f["bi"]
	var body: PackedInt32Array = f["body"]
	# a piece a blade cut is drawn as its own mesh ([method _draw_pieces]), never as lumps
	var cut: PackedByteArray = ((f.get("cut", []) as Array).back() as Array)[1] if not (f.get("cut", []) as Array).is_empty() else PackedByteArray()
	# ...ONLY WHAT MOVED, while nothing was born, died, broke or was cut since the frame last drawn: every instance in its place,
	# so a particle where it was is where it is drawn (2,000 grains set again every frame of a stir, every one still, had been 2.7
	# ms of a live show's frame - next/framework_audit.md)
	var same: bool = not _drawn_parts.is_empty() and alive == _drawn_parts[0] and owner == _drawn_parts[1] and bi == _drawn_parts[2] \
		and cut == _drawn_parts[3] and body == _drawn_parts[4]
	var last_x: PackedVector3Array = _drawn_parts[5] if same else PackedVector3Array()
	var last_r: PackedFloat32Array = _drawn_parts[6] if same else PackedFloat32Array()
	if _turn_of.size() < x.size():
		var from := _turn_of.size()
		_turn_of.resize(x.size())
		for i in range(from, x.size()):
			_turn_of[i] = Basis.from_euler(Vector3(Hands.share(i, 7), Hands.share(i, 8), Hands.share(i, 9)) * TAU)
	var counts := {}
	for i in x.size():
		if alive[i] == 0:
			continue
		var o := owner[i]
		var mm: MultiMesh = null
		if o >= 1000:
			var li := o - 1000
			if li < bi.size() and bi[li] == 1:
				continue
			if i < body.size() and body[i] >= 0 and body[i] < cut.size() and cut[body[i]] == 1:
				continue
			mm = _drawn_mm.get(o)
		elif o >= 0:
			mm = _drawn_mm.get(o)
		if mm == null:
			continue
		var k := int(counts.get(o, 0))
		if k >= mm.instance_count:
			continue
		counts[o] = k + 1
		if same and x[i] == last_x[i] and r[i] == last_r[i]:
			continue
		var s := r[i] * LUMP * 100.0 * 0.5
		mm.set_instance_transform(k, Transform3D((_turn_of[i] as Basis).scaled(Vector3(s, s, s)), x[i]))
	_drawn_parts = [alive, owner, bi, cut, body, x, r]
	for o in _drawn_mm:
		(_drawn_mm[o] as MultiMesh).visible_instance_count = int(counts.get(o, 0))


func _draw_liquids(f: Dictionary, t: float) -> void:
	var liq: PackedFloat32Array = f["liq"]
	for li in liquids.size():
		if li * 16 + 15 >= liq.size():
			continue
		var rings: Array = (f.get("rings", []) as Array)[li] if li < (f.get("rings", []) as Array).size() else []
		var L: Dictionary = liquids[li]
		var v := liq[li * 16]
		var nodes: Array = L["nodes"]
		if nodes.is_empty():
			if v <= 1e-9:
				continue
			_make_inside_node(li)
			nodes = L["nodes"]
		var n_w := Vector3(liq[li * 16 + 1], liq[li * 16 + 2], liq[li * 16 + 3])
		var c_w := Vector3(liq[li * 16 + 4], liq[li * 16 + 5], liq[li * 16 + 6])
		var col := Color(liq[li * 16 + 9], liq[li * 16 + 10], liq[li * 16 + 11])
		var hit := Vector4(liq[li * 16 + 12], liq[li * 16 + 13], liq[li * 16 + 14], liq[li * 16 + 15])
		var rings_at: Array = rings
		var sunk: PackedByteArray = f.get("sunk", PackedByteArray())
		for k in nodes.size():
			var mesh: MeshInstance3D = nodes[k]
			mesh.visible = v > 1e-9 and not (li < sunk.size() and sunk[li] == 1)
			if not mesh.visible:
				continue
			var mw := work._world_of(mesh)
			var inv := mw.affine_inverse()
			var mat := mesh.material_override as ShaderMaterial
			if mat == null:
				continue
			mat.set_shader_parameter("surface_at", inv * c_w)
			mat.set_shader_parameter("surface_up", (mw.basis.transposed() * n_w).normalized())
			mat.set_shader_parameter("swirl", liq[li * 16 + 7])
			mat.set_shader_parameter("show_time", t)
			var ra := PackedVector4Array()
			var rs := PackedFloat32Array()
			for rd in rings_at:
				var p := inv * ((rd as Dictionary)["at"] as Vector3)
				ra.append(Vector4(p.x, p.y, p.z, float((rd as Dictionary)["t"])))
				rs.append(float((rd as Dictionary)["size"]))
			while ra.size() < 12:
				ra.append(Vector4(0.0, 0.0, 0.0, -100.0))
				rs.append(0.0)
			mat.set_shader_parameter("ring_at", ra)
			mat.set_shader_parameter("ring_size", rs)
			mat.set_shader_parameter("ring_count", rings_at.size())
			var hp := inv * Vector3(hit.x, hit.y, hit.z)
			mat.set_shader_parameter("stream_at", Vector4(hp.x, hp.y, hp.z, hit.w))
			if not bool(L["made"]):
				mat.set_shader_parameter("color", col)
			# ITS SHAPE: its ripples' heights, and its curve as it turns
			var tex: Variant = _wave_texture(li, (f.get("waves", []) as Array)[li] if li < (f.get("waves", []) as Array).size() else null)
			mat.set_shader_parameter("wave_on", tex != null)
			if tex != null:
				var W: SurfaceWaves = L["waves"]
				mat.set_shader_parameter("wave_heights", tex)
				mat.set_shader_parameter("wave_o", W.o)
				mat.set_shader_parameter("wave_span", W.cell * float(W.n))
				mat.set_shader_parameter("wave_quantum", SurfaceWaves.QUANTUM)
			var dp: PackedVector2Array = f.get("dips", PackedVector2Array())
			mat.set_shader_parameter("dip", dp[li].x if li < dp.size() else 0.0)
			mat.set_shader_parameter("dip_r2", dp[li].y if li < dp.size() else 0.0)
			# ITS BUBBLES ([Boil]), each where it breaks, as the work's sound hears it: (x, z) from the surface's middle in the
			# mesh's space, its radius and how far it is from rising to breaking (past 1, its ring running out)
			var bubbles := PackedVector4Array()
			var wi := int(L["wi"])
			# ...by the WORK's channels, this thread's own: the twin's are the bake's, handed a new plan a sentence ([method
			# _take_plan]) - read from here as it took one, the old plan was freed under the read (a crash, 2026-11-01)
			if wi >= 0 and (work._chan.has("w%d:boil" % wi) or float(work._rest.get("w%d:boil" % wi, 0.0)) > 0.0):
				var W2: SurfaceWaves = L["waves"]
				var half := float(W2.n) * W2.cell * 0.5
				var ch := "w%d:boil" % wi
				var sc := mw.basis.get_scale().x
				for bb in Boil.showing(wi, t, func(T: float) -> float: return float(work.value(ch, T)), half * 2.0, BUBBLES_DRAWN):
					var at2: Vector2 = (bb as Dictionary)["at"]
					var wpos := c_w + (mw.basis.x.normalized() * at2.x + mw.basis.z.normalized() * at2.y) * half
					var mp := inv * wpos - inv * c_w
					bubbles.append(Vector4(mp.x, mp.z, float((bb as Dictionary)["r"]) / maxf(sc, 1e-3), float((bb as Dictionary)["phase"])))
			var nb := bubbles.size()
			while bubbles.size() < BUBBLES_DRAWN:
				bubbles.append(Vector4.ZERO)
			mat.set_shader_parameter("bubble", bubbles)
			mat.set_shader_parameter("bubble_count", nb)


## Liquid [param li]'s ripples [param bytes] (a frame's, [method SurfaceWaves.bytes]) as a texture its shader reads - made
## once, written again only as a frame brings other heights - or null, at rest.
func _wave_texture(li: int, bytes: Variant) -> Variant:
	if bytes == null:
		return null
	var was: Array = _wave_tex.get(li, [])
	if not was.is_empty() and is_same(was[1], bytes):
		return was[0]
	var W: SurfaceWaves = (liquids[li] as Dictionary)["waves"]
	var img := Image.create_from_data(W.n, W.n, false, Image.FORMAT_R8, bytes)
	var tex: ImageTexture = was[0] if not was.is_empty() else null
	if tex != null:
		tex.update(img)
	else:
		tex = ImageTexture.create_from_image(img)
	_wave_tex[li] = [tex, bytes]
	return tex


## A LIQUID'S MATERIAL [param mat] turned to the liquid's shader: seen through when it is as clear as [constant CLEAR_LIQUID], drawn
## under the glass round it (its glass and it are both seen through, and the nearer of the two is not always the one drawn last).
static func _liquid_shader(mat: ShaderMaterial) -> void:
	var clarity: Variant = mat.get_shader_parameter("clarity")
	var clear := clarity != null and float(clarity) >= CLEAR_LIQUID
	mat.shader = _LIQUID_CLEAR if clear else _LIQUID
	mat.render_priority = -1 if clear else 0


## The inside of empty vessel [param li], made as a liquid is first poured or dipped into it.
func _make_inside_node(li: int) -> void:
	var L: Dictionary = liquids[li]
	var holder: Node3D = L["holder"]
	var mesh := MeshInstance3D.new()
	holder.add_child(mesh)
	mesh.transform = L["xform"]
	# ...placed by the WORK's copy of its solid ([member TableWork._solids_ref]): this is the app's thread, and the bake's own solid
	# takes keys as what it meets is found - the ladle's, as it first came up full (a live show's `double free`, 2026-11-01)
	var sd: Dictionary = work._solids_ref[int(L["solid"])] if int(L["solid"]) < work._solids_ref.size() else solids[int(L["solid"])]
	mesh.mesh = _inside_mesh(L["vessel"], mesh, sd)
	var mat := Props.material(Props.sanitize_material({"kind": "liquid", "color": "#" + (L["color"] as Color).to_html(false)}, "#5060a0"), {}, 10.0, 5.0, li)
	_liquid_shader(mat)
	_cavity_uniforms(mat, L["vessel"], mesh, sd)
	mesh.material_override = mat
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	(L["nodes"] as Array).append(mesh)
	(L["mats"] as Array).append(mat)


## THE STREAMS of frame [param f], each a tube through its parcels.
func _draw_streams(f: Dictionary) -> void:
	var runs: Array = f.get("streams", [])
	while _streams.size() < runs.size():
		_streams.append(_new_stream())
	for si in _streams.size():
		var mi: MeshInstance3D = _streams[si]
		var mesh: ImmediateMesh = mi.mesh
		mesh.clear_surfaces()
		mi.visible = si < runs.size()
		if not mi.visible:
			continue
		var run: Dictionary = runs[si]
		var c: Color = run["color"]
		(mi.material_override as StandardMaterial3D).albedo_color = Color(c.r, c.g, c.b, 0.6)
		_tube(mesh, run["pts"], run["rad"])


## A stream's node: a tube drawn afresh each frame it falls ([method _tube]), in a glassy material of its own.
func _new_stream() -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = ImmediateMesh.new()
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness = 0.05
	mat.metallic_specular = 0.9
	mat.rim_enabled = true
	mat.rim = 0.4
	mat.rim_tint = 0.6
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visible = false
	_root.add_child(mi)
	return mi


## THE PICTURE'S OWN NODES, MADE AS THE TABLE IS ([method build]) - never the first time something drips: a stream's tube and
## a splash's drops are drawn in materials of their own, and made as the ladle first came out of the brew, the GPU built their
## shaders then - a picture frozen 3.3 s with the voice going on, as each viewing reached it (841899, 2026-11-01: "every time the
## ladle is pulled out of the liquid ... a solid 3-4 seconds of completely-frozen screen, while the audio still plays"; measured
## by tests/table/episode_bake_probe.gd `--live` on a GPU, 116 ms of it the table's). So they are made here, and a copy of each in
## the same material is drawn at nothing's size where the camera looks for the table's first [constant WARM_TICKS] frames, then
## freed: what the GPU needs for them is built as the table stands, while it is still being shown.
func _drawn_nodes() -> void:
	if _root == null:
		return
	if _drops == null:
		_make_drops()
	if _streams.is_empty():
		_streams.append(_new_stream())
	var at: Vector3 = work._spot if work._spot.is_finite() else Vector3.ZERO
	var tiny := Vector3.ONE * 1e-5
	var stream := MeshInstance3D.new()
	stream.mesh = ImmediateMesh.new()
	stream.material_override = (_streams[0] as MeshInstance3D).material_override
	stream.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_tube(stream.mesh as ImmediateMesh, PackedVector3Array([at, at - Vector3(0.0, 1e-5, 0.0)]), PackedFloat32Array([1e-5, 1e-5]))
	_root.add_child(stream)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.instance_count = 1
	mm.mesh = _drops.multimesh.mesh
	mm.set_instance_transform(0, Transform3D(Basis.from_scale(tiny), at))
	mm.set_instance_color(0, Color.BLACK)
	var drops := MultiMeshInstance3D.new()
	drops.multimesh = mm
	drops.material_override = _drops.material_override
	drops.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_root.add_child(drops)
	_warm = [stream, drops]
	_warm_ticks = 0


static func _tube(mesh: ImmediateMesh, pts: PackedVector3Array, rad: PackedFloat32Array) -> void:
	var sides := 8
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings: Array = []
	for i in pts.size():
		var along := (pts[mini(i + 1, pts.size() - 1)] - pts[maxi(i - 1, 0)]).normalized()
		if along.length() < 0.5:
			along = Vector3.DOWN
		var side := along.cross(Vector3.FORWARD if absf(along.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
		var other := along.cross(side)
		var ring: Array = []
		for j in sides:
			var a := TAU * float(j) / float(sides)
			var nn := side * cos(a) + other * sin(a)
			ring.append([pts[i] + nn * rad[i], nn])
		rings.append(ring)
	for i in rings.size() - 1:
		for j in sides:
			var j1 := (j + 1) % sides
			for vtx in [rings[i][j], rings[i + 1][j], rings[i + 1][j1], rings[i][j], rings[i + 1][j1], rings[i][j1]]:
				mesh.surface_set_normal(vtx[1])
				mesh.surface_add_vertex(vtx[0])
	mesh.surface_end()


## THE PIECES A BLADE CUT in frame [param f]: each where it is, made the first time it is seen ([method _piece_node]).
func _draw_pieces(f: Dictionary) -> void:
	var seen := {}
	for c in f.get("cut", []):
		var key := int((c as Array)[0])
		if key == -1:
			continue
		if not _piece_nodes.has(key):
			_piece_nodes[key] = _piece_node(int(c[1]), c[2])
		var node: Node3D = _piece_nodes[key]
		if node == null:
			continue
		node.transform = c[3]
		node.visible = true
		seen[key] = true
	for key in _piece_nodes:
		if not seen.has(key) and _piece_nodes[key] != null:
			(_piece_nodes[key] as Node3D).visible = false


## A PIECE of loose thing [param li], kept behind [param planes] (its own space): its meshes cut, each cut faced
## ([MeshCut]) - its words too, if it was written on.
func _piece_node(li: int, planes: Array) -> Node3D:
	var wn: Node3D = (work.works[_loose_wi[li]] as Dictionary)["node"]
	var holder := Node3D.new()
	holder.name = "piece"
	_root.add_child(holder)
	for m in wn.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi.mesh == null:
			continue
		var xf := mi.transform
		var p := mi.get_parent()
		while p != null and p != wn and p is Node3D:
			xf = (p as Node3D).transform * xf
			p = p.get_parent()
		var skin: Material = mi.material_override
		var mats: Array = []
		for s in mi.mesh.get_surface_count():
			mats.append(skin if skin != null else mi.mesh.surface_get_material(s))
		var cut := MeshCut.cut(mi.mesh, xf, planes, mats, MeshCut.inside_of(mats[0] if not mats.is_empty() else null))
		if cut == null:
			continue
		var out := MeshInstance3D.new()
		out.mesh = cut
		out.layers = mi.layers
		out.cast_shadow = mi.cast_shadow
		holder.add_child(out)
	return holder


## THE SPLASHES' DROPS of frame [param f].
func _draw_drops(f: Dictionary) -> void:
	if _drops == null:
		_make_drops()
	var mm: MultiMesh = _drops.multimesh
	var drops: Array = f.get("drops", [])
	for k in drops.size():
		var d: Array = drops[k]
		var size := float(d[1])
		mm.set_instance_transform(k, Transform3D(Basis.IDENTITY.scaled(Vector3(size, size, size)), d[0]))
		mm.set_instance_color(k, d[2])
	mm.visible_instance_count = drops.size()


## The splashes' drops: [constant DROPS] spheres, each its own color, none shown.
func _make_drops() -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.instance_count = DROPS
	mm.visible_instance_count = 0
	var sphere := SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1.0
	sphere.radial_segments = 8
	sphere.rings = 4
	mm.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.08
	mat.metallic_specular = 0.9
	_drops = MultiMeshInstance3D.new()
	_drops.multimesh = mm
	_drops.material_override = mat
	_drops.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_root.add_child(_drops)


# --- telling the puppeteer --------------------------------------------------------------------------------

## WHAT IS IN THING [param ti] AS IT STANDS, in words for the puppeteer: its liquids (how much, of how much), its grains,
## its loose things.
func contents_of(ti: int) -> PackedStringArray:
	var out := PackedStringArray()
	for li in liquids.size():
		var L: Dictionary = liquids[li]
		if int(L["thing"]) != ti:
			continue
		if bool(L["made"]):
			out.append("its %s: a liquid, %.0f ml in an inside of %.0f ml - it pours over the rim when tipped far enough" % [String(L["name"]),
				float(L["v0"]) * 1e6, float(L["full_v"]) * 1e6])
	for g in grains:
		if int((g as Dictionary)["thing"]) == ti:
			out.append("its %s: grains (%d), loose in %s - they spill when it is tipped" % [String((g as Dictionary)["name"]),
				((g as Dictionary)["ids"] as PackedInt32Array).size(), "its inside" if int((g as Dictionary)["solid"]) >= 0 else "a heap"])
	var names := PackedStringArray()
	for l in loose:
		if int((l as Dictionary)["thing"]) == ti:
			names.append(String((l as Dictionary)["name"]))
	if not names.is_empty():
		out.append("loose (they slide, tumble and fall when what holds them tips, and a pestle breaks them): %s" % ", ".join(names))
	return out


## WHAT THE PHYSICS DID between [param t0] and [param t1] (an act's run, baked through): what poured from what and where
## it went, what grains and loose things left what and where they are now, what sank, floated, dissolved and broke - and,
## for a vessel tipped that poured nothing, how far it would have to go.
func report(t0: float, t1: float, pours: Array = []) -> PackedStringArray:
	bake_until(t1 + REPORT_AFTER)
	var out := PackedStringArray()
	var f0: Variant = frame_at(t0)
	var f1: Variant = frame_at(t1 + REPORT_AFTER)
	if f0 == null or f1 == null:
		return out
	# WHAT WAS MEANT, AGAINST WHAT HAPPENED: each pour the act makes, judged by where what left its vessel went
	for pr in pours:
		var said := _pour_said(pr as Dictionary, t0, t1, f0, f1)
		if not said.is_empty():
			out.append(said)
	# LIQUIDS: what left, and where it went
	for li in liquids.size():
		var L: Dictionary = liquids[li]
		var left := 0.0
		var went := {}
		for p in parcels:
			var pd: Dictionary = p
			if int(pd["from"]) != li or float(pd["t0"]) < t0 or float(pd["t0"]) > t1:
				continue
			left += float(pd["vol"])
			went[int(pd["into"])] = float(went.get(int(pd["into"]), 0.0)) + float(pd["vol"])
		var name := _liquid_label(li)
		if left > 1e-8:
			var bits := PackedStringArray()
			for into in went:
				if int(into) >= 0:
					bits.append("%.1f ml into %s" % [float(went[into]) * 1e6, _liquid_label(int(into))])
				elif int(into) == -1:
					bits.append("%.1f ml SPILLED (it missed: bring the lip over what catches it)" % (float(went[into]) * 1e6))
				else:
					bits.append("%.1f ml still falling" % (float(went[into]) * 1e6))
			out.append("- %s: %.1f ml poured out over its rim - %s." % [name, left * 1e6, ", ".join(bits)])
		else:
			var tip := _most_tip(li, t0, t1)
			if tip > deg_to_rad(25.0) and float(((f0 as Dictionary)["liq"] as PackedFloat32Array)[li * 16]) > 1e-8:
				var need := _tip_needed(li, float(((f0 as Dictionary)["liq"] as PackedFloat32Array)[li * 16]))
				var sealed := false
				for pj in L["plugs"]:
					sealed = true
				out.append("- %s: tipped %.0f degrees, and NOTHING POURED - %s." % [name, rad_to_deg(tip),
					"it is stoppered" if sealed and need < 180.0 else ("it reaches its rim only past %.0f degrees" % rad_to_deg(need) if need < PI else "it never reaches its rim")])
		var gain := float(((f1 as Dictionary)["liq"] as PackedFloat32Array)[li * 16]) - float(((f0 as Dictionary)["liq"] as PackedFloat32Array)[li * 16])
		if gain > 2e-7 and left <= 1e-8:
			out.append("- %s: %.1f ml more in it by the end." % [name, gain * 1e6])
	# GRAINS: where they went
	for gi in grains.size():
		var g: Dictionary = grains[gi]
		var moved := 0
		var into := {}
		var gone := 0
		var x0: PackedVector3Array = (f0 as Dictionary)["x"]
		var x1: PackedVector3Array = (f1 as Dictionary)["x"]
		var a0: PackedByteArray = (f0 as Dictionary)["alive"]
		var a1: PackedByteArray = (f1 as Dictionary)["alive"]
		for i in g["ids"]:
			if i >= x1.size():
				continue
			if i < a0.size() and a0[i] == 1 and a1[i] == 0:
				gone += 1
				continue
			if a1[i] == 0 or i >= x0.size():
				continue
			if x0[i].distance_to(x1[i]) > 0.01:
				moved += 1
				var w := _where(x1[i])
				into[w] = int(into.get(w, 0)) + 1
		if moved + gone > 0:
			var bits := PackedStringArray()
			for w in into:
				bits.append("%d %s" % [int(into[w]), w])
			if gone > 0:
				bits.append("%d dissolved" % gone)
			out.append("- the %s (%d grains): %d moved - %s." % [String(g["name"]), (g["ids"] as PackedInt32Array).size(), moved + gone, ", ".join(bits)])
	# LOOSE THINGS: where each is now, and whether it broke
	for li in loose.size():
		var L: Dictionary = loose[li]
		var bp0: PackedVector3Array = (f0 as Dictionary)["bp"]
		var bp1: PackedVector3Array = (f1 as Dictionary)["bp"]
		# ...WHERE ITS MIDDLE IS, never its node's origin: a heap's copy has it where the heap was built, centimeters off and swung
		# wherever the thing turns
		var mid: Vector3 = (((work.works[int(L["wi"])] as Dictionary)["w"] as Dictionary).get("box", AABB()) as AABB).get_center()
		var p0 := Transform3D(Basis(bp0[li * 4], bp0[li * 4 + 1], bp0[li * 4 + 2]), bp0[li * 4 + 3]) * mid
		var p1 := Transform3D(Basis(bp1[li * 4], bp1[li * 4 + 1], bp1[li * 4 + 2]), bp1[li * 4 + 3]) * mid
		var broke := ((f1 as Dictionary)["bi"] as PackedByteArray)[li] == 0 and ((f0 as Dictionary)["bi"] as PackedByteArray)[li] != 0
		var pieces := 0
		var fine := 0
		var owner1: PackedInt32Array = (f1 as Dictionary)["owner"]
		var r1: PackedFloat32Array = (f1 as Dictionary)["r"]
		var al1: PackedByteArray = (f1 as Dictionary)["alive"]
		for i in owner1.size():
			if owner1[i] == 1000 + li and al1[i] == 1:
				pieces += 1
				if r1[i] < Particles.POWDER * 1.5:
					fine += 1
		# ...or CUT, by a blade: the pieces it is in now, and where they lie
		var cut0 := 0
		var cut1 := 0
		var lie := {}
		for c in (f0 as Dictionary).get("cut", []):
			if int((c as Array)[0]) != -1 and int(c[1]) == li:
				cut0 += 1
		for c in (f1 as Dictionary).get("cut", []):
			if int((c as Array)[0]) != -1 and int(c[1]) == li:
				cut1 += 1
				var w := _where((c[3] as Transform3D).origin)
				lie[w] = int(lie.get(w, 0)) + 1
		if cut1 > cut0:
			var bits := PackedStringArray()
			for w in lie:
				bits.append("%d %s" % [int(lie[w]), w])
			out.append("- %s: CUT into %d pieces - %s." % [String(L["name"]), cut1, ", ".join(bits)])
			continue
		# ...BROKEN, WHERE ITS PIECES ARE: the body it was is left where it broke (841899's puppeteer was told its ground
		# frankincense was "on the table" while every piece lay in the cauldron, and the act that put it there went in as it was)
		if ((f1 as Dictionary)["bi"] as PackedByteArray)[li] == 0:
			var x0: PackedVector3Array = (f0 as Dictionary)["x"]
			var x1: PackedVector3Array = (f1 as Dictionary)["x"]
			var owner0: PackedInt32Array = (f0 as Dictionary)["owner"]
			var moved_n := 0
			var lie_p := {}
			for i in owner1.size():
				if owner1[i] != 1000 + li or al1[i] != 1:
					continue
				var w := _where(x1[i])
				lie_p[w] = int(lie_p.get(w, 0)) + 1
				if i >= x0.size() or owner0[i] != owner1[i] or x0[i].distance_to(x1[i]) > 0.01:
					moved_n += 1
			if broke or moved_n > 0:
				var bits := PackedStringArray()
				for w in lie_p:
					bits.append("%d %s" % [int(lie_p[w]), w])
				out.append("- %s: %s into %d pieces, %d of them ground to powder - %s." % [String(L["name"]), "BROKEN" if broke else "broken",
					pieces, fine, ", ".join(bits)])
			continue
		if p0.distance_to(p1) > 0.01:
			out.append("- %s: now %s." % [String(L["name"]), _where(p1)])
	# PARTS A HAND LET GO: where each came to rest, against where its act left it (841899's stopper, put back on its side, fell
	# into its jar - and the act's check said nothing)
	for bi in rigid.bodies.size():
		var b: Dictionary = rigid.bodies[bi]
		var wi := int(b["wi"])
		var ch := _ch_of(wi)
		var end := -INF
		for e in twin._chan.get(ch, []):
			var s1 := float((e as Dictionary)["s1"])
			if s1 >= t0 and s1 <= t1 + 0.05:
				end = maxf(end, s1)
		# ...never one a hand still holds up until its next move ([method _held_aloft]): it was not let go
		if end == -INF or _held_at(wi, t1 + REPORT_AFTER) or _held_aloft(bi, wi, t1 + REPORT_AFTER) != null:
			continue
		var now: Variant = pose_of(wi, t1 + REPORT_AFTER)
		if now == null:
			continue
		var mid: Vector3 = (work._rest[ch] as Transform3D).affine_inverse() * (b["c0"] as Vector3)
		var meant: Transform3D = twin.value(ch, end - 1e-4)
		var off := (meant * mid).distance_to((now as Transform3D) * mid)
		# ...AGAINST WHAT HOLDS IT: one that rides what it rests in went where that went (a cork put back in its jar's neck, the jar
		# then carried home with it - "came to rest 90 cm from where the act left it", 841899)
		var hs := int(b["host"])
		if hs >= 0 and hs < solids.size():
			var h_end := _solid_at(solids[hs], end)
			var h_now := _solid_at(solids[hs], t1 + REPORT_AFTER)
			off = minf(off, (h_end.affine_inverse() * meant * mid).distance_to(h_now.affine_inverse() * (now as Transform3D) * mid))
		if off > LET_GO_OFF:
			# ...LEFT STANDING IN A VESSEL, it leans there: the hand let it go on purpose ([method _held_aloft]), and nothing is to fix
			var in_vessel := _inside_of((now as Transform3D) * mid, _vessel_of.get(int((b["solids"] as PackedInt32Array)[0]), -1) if not (b["solids"] as PackedInt32Array).is_empty() else -1)
			if in_vessel >= 0:
				out.append("- %s: left standing in %s, it leans there as the hand let it go, %.1f cm from where the act left it." % [
					_body_label(bi), _liquid_label(in_vessel), off * 100.0])
				continue
			out.append("- %s: let go, it came to rest %.1f cm from where the act left it - now %s. Set it `down` where it can rest, turned the way it stands there." % [
				_body_label(bi), off * 100.0, _body_where(bi, now as Transform3D)])
	# WHAT A HAND COULD NOT TAKE WHERE ITS ACT SENDS IT: nothing an act moves goes through anything ([method _make_rigid]), so
	# a move that would is held back by what is in its way - said, with what stopped it, as far short as it came the most
	# ...each frame read once, every body's lag in it (a body a frame had read every frame: 150 bodies over a 12 s act, 108,000 looks)
	var fps := float(FPS)
	var nb := rigid.bodies.size()
	var most := PackedFloat32Array()
	most.resize(nb)
	var most_at := PackedFloat32Array()
	most_at.resize(nb)
	var most_by := PackedInt32Array()
	most_by.resize(nb)
	most_by.fill(-1)
	var last_fr: Variant = null
	for k in range(int(floor(t0 * fps)), int(ceil(t1 * fps)) + 1):
		var fr: Variant = frame_at(float(k) / fps)
		if fr == null or is_same(fr, last_fr):
			continue
		last_fr = fr
		var rd: PackedFloat32Array = (fr as Dictionary).get("rd", PackedFloat32Array())
		var rt: PackedInt32Array = (fr as Dictionary).get("rt", PackedInt32Array())
		var wk: PackedInt32Array = (fr as Dictionary).get("wk", PackedInt32Array())
		for j in mini(int((fr as Dictionary).get("rpn", 0)), mini(rd.size(), wk.size())):
			var bi := wk[j]
			# ...ONLY WHERE SOMETHING HELD IT: a body that met nothing that frame is behind its hand only as a hand's own pace leaves it
			# (841899's frankincense jar, 18 cm over the table and 5 cm behind its fast hand, was told it was "HELD BACK by the table's
			# top" - nothing it met had a name, and none was read as the top)
			if rd[j] > most[bi] and j < rt.size() and rt[j] != -1:
				most[bi] = rd[j]
				most_at[bi] = float(k) / fps
				most_by[bi] = rt[j]
	for bi in nb:
		if most[bi] > HELD_BACK:
			out.append("- %s: HELD BACK by %s - it stopped %.1f cm short of where the act takes it, %.1f s in. Nothing an act moves passes through anything: lift it over what is in its way, or bring it round." % [
				_body_label(bi), _solid_label(most_by[bi]), most[bi] * 100.0, most_at[bi] - t0])
	if not out.is_empty():
		out.insert(0, "WHAT THE PHYSICS DID (liquids pour where they stand above a rim, loose things fall and tumble, a pestle pressed into them crushes them):")
	return out


## A POUR JUDGED ([method report]): [param pr] `{label: what poured, from: PackedInt32Array (the solids of what poured), into:
## the name it was poured into}` over [param t0]-[param t1] (frames [param f0], [param f1]) - everything that left the insides
## of what poured (its liquid's parcels, its grains, its broken or loose pieces) counted IN what it was meant for, or MISSED it,
## by the part each went into. (2026-11-01, 841899: a mortar's powder "tipped into the brew" went into the brazier's pan beside
## the pot, and `act` said "63 in the copper cauldron on its brazier" - the agent read a miss as a hit.) "" when nothing left it.
func _pour_said(pr: Dictionary, t0: float, t1: float, f0: Variant, f1: Variant) -> String:
	var from: PackedInt32Array = pr.get("from", PackedInt32Array())
	var targets := _targets_of(String(pr.get("into", "")))
	if from.is_empty():
		return ""
	var hit := 0.0
	var missed := {}           # where -> how much
	var unit := ""
	# ...ITS LIQUID: each parcel that left it, by where it went
	var ml_hit := 0.0
	var ml_missed := {}
	for p in parcels:
		var pd: Dictionary = p
		if float(pd["t0"]) < t0 or float(pd["t0"]) > t1 or int(pd["from"]) < 0 or not from.has(int((liquids[int(pd["from"])] as Dictionary)["solid"])):
			continue
		var into := int(pd["into"])
		if targets.has(into):
			ml_hit += float(pd["vol"])
		else:
			var w := ("into " + _liquid_label(into)) if into >= 0 else ("spilled" if into == -1 else "still falling")
			ml_missed[w] = float(ml_missed.get(w, 0.0)) + float(pd["vol"])
	# ...WHAT IS LOOSE IN IT OR ON IT (grains, pieces, loose things): each that lay in its inside or on it as the act began - within
	# its box and a few centimeters over it (a stone taller than a shallow dish stands out of its inside) - and is out of it now, by
	# where it is
	var x0: PackedVector3Array = (f0 as Dictionary)["x"]
	var x1: PackedVector3Array = (f1 as Dictionary)["x"]
	var a0: PackedByteArray = (f0 as Dictionary)["alive"]
	var a1: PackedByteArray = (f1 as Dictionary)["alive"]
	var on0 := _mover_box(from, t0)
	var on1 := _mover_box(from, t1 + REPORT_AFTER)
	var n_hit := 0
	var n_missed := {}
	for i in mini(x0.size(), x1.size()):
		if i >= a0.size() or i >= a1.size() or a0[i] != 1:
			continue
		var was := _inside_liquid(x0[i])
		if not ((was >= 0 and from.has(int((liquids[was] as Dictionary)["solid"]))) or on0.has_point(x0[i])):
			continue
		if a1[i] != 1:
			n_hit += 1 if targets.has(was) else 0
			continue
		var now := _inside_liquid(x1[i])
		if (now >= 0 and from.has(int((liquids[now] as Dictionary)["solid"]))) or on1.has_point(x1[i]):
			continue
		if targets.has(now):
			n_hit += 1
		else:
			var w := _where(x1[i])
			n_missed[w] = int(n_missed.get(w, 0)) + 1
	var bits := PackedStringArray()
	var any_missed := not ml_missed.is_empty() or not n_missed.is_empty()
	if ml_hit + _sum(ml_missed) > 1e-8:
		var mb := PackedStringArray()
		for w in ml_missed:
			mb.append("%.1f ml %s" % [float(ml_missed[w]) * 1e6, w])
		bits.append("%.1f ml went in%s" % [ml_hit * 1e6, (", " + ", ".join(mb)) if not mb.is_empty() else ""])
	var n_out := n_hit
	for w in n_missed:
		n_out += int(n_missed[w])
	if n_out > 0:
		var nb := PackedStringArray()
		for w in n_missed:
			nb.append("%d %s" % [int(n_missed[w]), w])
		bits.append("%d of the %d pieces that left it went in%s" % [n_hit, n_out, (", " + ", ".join(nb)) if not nb.is_empty() else ""])
	if bits.is_empty():
		return "- POUR of %s into \"%s\": NOTHING LEFT IT - tip it further (`tip`), or give it longer." % [String(pr.get("label", "it")), String(pr.get("into", ""))]
	if targets.is_empty():
		return "- POUR of %s into \"%s\" (nothing of that name holds anything): %s." % [String(pr.get("label", "it")), String(pr.get("into", "")), "; ".join(bits)]
	return "- POUR of %s into \"%s\": %s%s." % [String(pr.get("label", "it")), String(pr.get("into", "")), "MISSED - " if any_missed else "", "; ".join(bits)]


## The box solids [param from] fill at [param t] as baked, and [constant ON_IT] over it: what lies in it or on it ([method _pour_said]).
func _mover_box(from: PackedInt32Array, t: float) -> AABB:
	var box := AABB()
	var any := false
	for si in from:
		var sd: Dictionary = solids[si]
		var b := _solid_at(sd, t) * (sd["box"] as AABB)
		box = b if not any else box.merge(b)
		any = true
	if not any:
		return AABB()
	box = box.grow(0.003)
	box.size.y += ON_IT
	return box


static func _sum(d: Dictionary) -> float:
	var t := 0.0
	for k in d:
		t += float(d[k])
	return t


## The solids of what a track moves: thing [param ti] whole, or part [param wi] and what goes where it goes (a stopper in its jar).
func solids_of_mover(ti: int, wi: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	for si in solids.size():
		var sd: Dictionary = solids[si]
		if (ti >= 0 and int(sd["thing"]) == ti) or (wi >= 0 and work._within(int(sd["wi"]), wi) == 1):
			out.append(si)
	return out


## THE INSIDES A POUR INTO [param into] IS MEANT FOR: the liquids (each an inside, filled or not) named so - a liquid's own name
## ("brew"), the part that holds it ("vial 1", "cauldron"), its thing (every inside of it that holds a liquid, else every inside),
## or "thing/part".
func _targets_of(into: String) -> Array:
	var name := into.strip_edges().to_lower()
	var part := name.get_slice("/", 1) if name.contains("/") else name
	var out: Array = []
	var of_thing: Array = []
	for li in liquids.size():
		var L: Dictionary = liquids[li]
		var sd: Dictionary = solids[int(L["solid"])]
		var thing := String((work.things[int(L["thing"])] as Dictionary)["name"]).to_lower()
		var holder := work._part_label(int(sd["wi"])).to_lower() if int(sd["wi"]) >= 0 else ""
		var holder_name := String((work.works[int(sd["wi"])] as Dictionary)["name"]).to_lower() if int(sd["wi"]) >= 0 else ""
		if String(L["name"]).to_lower() == part or (not holder.is_empty() and (holder == part or holder_name == part)):
			out.append(li)
		elif thing == name or (name.contains("/") and thing == name.get_slice("/", 0)):
			of_thing.append(li)
	if out.is_empty() and not of_thing.is_empty():
		# ...a thing named whole: the insides that hold a liquid as built (a pot, never its brazier's pan), else all of them
		for li in of_thing:
			if float((liquids[int(li)] as Dictionary).get("v0", 0.0)) > 1e-9:
				out.append(li)
		if out.is_empty():
			out = of_thing
	return out


## Rigid body [param bi] as the puppeteer knows it: a whole thing, or a thing's part.
func _body_label(bi: int) -> String:
	var wi := int((rigid.bodies[bi] as Dictionary)["wi"])
	if wi < 0:
		return String((work.things[-1 - wi] as Dictionary)["name"])
	return "%s's %s" % [String((work.things[int((work.works[wi] as Dictionary)["thing"])] as Dictionary)["name"]), work._part_label(wi)]


## Solid [param si] as the puppeteer knows it - or the table's top, or the loose things under a body.
func _solid_label(si: int) -> String:
	if si == RigidParts.LOOSE:
		return "the loose things under it"
	if si < 0 or si >= solids.size():
		return "the table's top"
	# ...named from the work's copy, which any thread may read ([member TableWork._solids_ref])
	var sd: Dictionary = work._solids_ref[si] if si < work._solids_ref.size() else solids[si]
	var thing := String((work.things[int(sd["thing"])] as Dictionary)["name"])
	return thing if int(sd["wi"]) < 0 else "%s's %s" % [thing, work._part_label(int(sd["wi"]))]


## Liquid [param li] as the puppeteer knows it: its own name and the part that holds it ("the copper cauldron's brew"), or, an
## inside with no liquid of its name, THE PART whose inside it is - a thing may hold two (a cauldron and its brazier's pan), and
## named by the thing alone they read alike.
func _liquid_label(li: int) -> String:
	var L: Dictionary = liquids[li]
	var thing := String((work.things[int(L["thing"])] as Dictionary)["name"])
	var nm := String(L["name"])
	return "%s's %s" % [thing, nm] if not nm.is_empty() else "the inside of %s" % _solid_label(int(L["solid"]))


## WHERE [param p] IS, in words the puppeteer can act on: in a liquid, or in the inside of THE PART that holds it (never the thing
## alone: 2026-11-01, 841899's ground frankincense in the brazier's pan beside the cauldron was told "in the copper cauldron on its
## brazier", and a miss read as a hit); else on what is under it, looked for straight down ([constant LOOK_DOWN]) - the table's
## top or a part; else in the air. (A thing's middle 1.2 cm up had read "in the air" where it lay on the table.)
func _where(p: Vector3, skip := PackedInt32Array()) -> String:
	var li := _inside_liquid(p, skip)
	if li >= 0:
		var S: Dictionary = _liq[li]
		var under := float(S["v"]) > 1e-9 and (p - (S.get("c", p) as Vector3)).dot(S.get("n", Vector3.UP) as Vector3) < 0.0
		return ("in %s" % _liquid_label(li)) if under else "in the inside of %s" % _solid_label(int((liquids[li] as Dictionary)["solid"]))
	var si := _solid_under(p, skip)
	if si >= 0:
		return "on %s" % _solid_label(si)
	return "on the table" if p.y < LOOK_DOWN else "in the air"


## WHERE RIGID BODY [param bi] LIES, posed [param now] (its node's pose): in the inside its middle is in, else on what is under
## its lowest point - never in or on itself (a mortar's middle is in its own inside: "now in the bronze mortar and pestle").
func _body_where(bi: int, now: Transform3D) -> String:
	var b: Dictionary = rigid.bodies[bi]
	var motion := now * _rest_of(int(b["wi"])).affine_inverse()
	var own: PackedInt32Array = b["solids"]
	var mid := motion * (b["c0"] as Vector3)
	if _inside_liquid(mid, own) >= 0:
		return _where(mid, own)
	var low := Vector3(0.0, INF, 0.0)
	for q in (b["pts"] as PackedVector3Array):
		var w := motion * q
		if w.y < low.y:
			low = w
	return _where(low + Vector3.UP * 0.004, own) if low.y < INF else _where(mid, own)


## The liquid whose vessel's inside holds [param p], the smallest such, none of solids [param skip] - or -1.
func _inside_liquid(p: Vector3, skip := PackedInt32Array()) -> int:
	var best := -1
	var least := INF
	for li in liquids.size():
		var L: Dictionary = liquids[li]
		if skip.has(int(L["solid"])):
			continue
		var sd: Dictionary = solids[int(L["solid"])]
		if (L["vessel"] as Vessel).contains((sd["inv"] as Transform3D) * p) and float(L["full_v"]) < least:
			least = float(L["full_v"])
			best = li
	return best


## The solid nearest under [param p], looked for straight down as far as [constant LOOK_DOWN] - or -1 when there is none that near
## (what is under it then is the table's top, or nothing).
func _solid_under(p: Vector3, skip := PackedInt32Array()) -> int:
	var step := 0.002
	var d := 0.0
	while d <= minf(LOOK_DOWN, maxf(p.y, 0.0)):
		var q := p - Vector3(0.0, d, 0.0)
		for si in solids.size():
			var sd: Dictionary = solids[si]
			if skip.has(si) or not bool(sd.get("on", true)) or not (sd["wbox"] as AABB).grow(0.003).has_point(q):
				continue
			if (sd["field"] as ShapeField).sample((sd["inv"] as Transform3D) * q).x < 0.003:
				return si
		d += step
	return -1


## The most liquid [param li]'s vessel is tipped between [param t0] and [param t1] (radians from upright).
func _most_tip(li: int, t0: float, t1: float) -> float:
	var sd: Dictionary = solids[int((liquids[li] as Dictionary)["solid"])]
	var most := 0.0
	for k in 25:
		var t := lerpf(t0, t1, float(k) / 24.0)
		most = maxf(most, _solid_at(sd, t).basis.y.normalized().angle_to(Vector3.UP))
	return most


## Solid [param sd] at show time [param t] as baked: a rigid body's from the frame then - the twin has a body only where the
## bake is now (a flask tipped and set back was told it had never tipped) - anything else where the twin has it then.
func _solid_at(sd: Dictionary, t: float) -> Transform3D:
	if sd.has("body"):
		var key := int((rigid.bodies[int(sd["body"])] as Dictionary)["wi"])
		var pose: Variant = pose_of(key, t)
		if pose != null:
			return (pose as Transform3D) * _rest_of(key).affine_inverse() * (sd["rest"] as Transform3D)
	return _pose_owner(sd, t) * (sd["local"] as Transform3D)


## How far liquid [param li]'s vessel must be tipped before [param v] cubic meters of it reach its rim (radians; PI or more:
## never).
func _tip_needed(li: int, v: float) -> float:
	var L: Dictionary = liquids[li]
	var vs: Vessel = L["vessel"]
	var share := v / maxf(float(L["full_v"]), 1e-12)
	for k in 91:
		var th := PI * float(k) / 90.0
		var up := Vector3(sin(th), cos(th), 0.0)
		var s := vs.level(up, share)
		if float(vs.overflow(up, s)["head"]) > 0.0:
			return th
	return PI


## Everything let go: the thread stopped (what is asked after bakes on its caller's thread), the nodes freed with the
## work's.
func clear() -> void:
	if _thread != null:
		_quit = true
		_sem.post()
		_thread.wait_to_finish()
	_thread = null
	_sem = null
	_quit = false
	_sync = true
