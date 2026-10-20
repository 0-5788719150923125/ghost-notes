extends RefCounted
class_name Rides

## Rides - WHAT THE TABLE IS ABOARD when the reading is somewhere that moves: a train, a car, a cart
## behind horses, a boat, a plane. The set dresser writes it as the table's `ride` ([method describe],
## [method sanitize]). The user, 2026-10-19: "the script will mention that we are on a moving thing ...
## there was no clear indication that the train was moving. If a real person were REALLY filming a table
## from the angle we film from ... you might expect to see a bit of vibration in the camera position. Not
## slow, gentle movement - not a head-bob, because the camera is mounted - but vibration, interspersed
## with "bumps" ... one might expect props themselves to vibrate or move a bit as well."
##
## ONE RIDE MOVES EVERYTHING, planned once from the seed ([method plan]) as the wind is ([Winds]):
##   - its BUZZ, the fine vibration through the floor (a band of it, [constant ON]'s `band`),
##   - its KNOCKS, the wheels over the rail joints - each axle under the car in turn, da-da ... da-da,
##     as often as the speed takes it - and its PATTER, the cobbles or the road's grain, small jolts
##     close together,
##   - its BUMPS, a harder jolt now and then (the points, a pothole, a wave slapping the hull, turbulence),
##   - its SWAY, the slow push of a bend or the car's swaying, the ROLL of a deck on the swell (which
##     leans the floor against true up), and its TURNS, the way it heads wandering over minutes.
## The camera, what stands on the table that the set dresser said moves ([constant MOVES], a part's
## `move`), the flames and the sound ([Soundscape]) all read the same plan, so a jolt is seen in the
## lens, the flowers and the candle's flame at once, and heard as it is seen.
##
## EVERYTHING IS A FUNCTION OF SHOW TIME, never stepped: each moving thing is an oscillator (its own
## frequency and damping), and its answer to the ride is a sum in closed form - a damped ring for every
## jolt still sounding in it ([method _ring]), the steady answer to each slow sway ([method _tone]), and,
## for the buzz, the narrow band a lightly damped thing makes of a broad shaking (Rice's sum of a few
## close tones, its strength from Miles' equation - [method _buzz_of]). So a render, a scrub and the set
## dresser's picture see the same flower leaning the same way.
##
## THE CAMERA IS MOUNTED, and steadied: it moves WITH the table, so what it shows is only its mount's give -
## a faint buzz and a quick nod at a jolt that settles in a few frames, as a phone on a small tripod with
## its stabilizer on films it ([method camera], [constant MOUNT]). NEVER THE SLOW MOTION: the sway, the
## roll and the turns are left out of the lens. Slow motion of the whole frame (a tenth of a hertz to
## about one) is what makes a viewer seasick, and a mounted camera rides it with the table anyway; they
## show in what hangs, pours, burns and points instead.

## THE RIDES: what each does, as an agent reads it, and its character at `rough` 1 and `speed` 1 -
## `buzz`, the vibration's rms (m/s²) over its `band` (Hz); `joint`, meters between rail joints (0 none)
## and `axles`, where the wheels that knock over one stand along the car (meters); `knock`, how hard a
## wheel knocks (m/s, the jolt's change of speed); `patter`, small jolts a second and how hard (m/s);
## `bumps`, the hard jolts a minute and how hard (the least and the most, m/s); `sway`, the slow push's
## rms (m/s²); `roll`, how far the deck leans on the swell (degrees) and the swell's period (seconds);
## `turns`, how far the heading wanders (degrees); `top`, its full speed (m/s).
const ON := {
	"rails": {"about": "a train - a carriage, a dining car, a sleeper: a steady rumble through the floor, the wheels knocking over the rail joints two by two, a sway now and then and a harder jolt over the points",
		"buzz": 0.3, "band": Vector2(1.5, 25.0), "joint": 25.0, "axles": [0.0, 2.5, 17.5, 20.0], "knock": 0.014,
		"patter": Vector2(0.0, 0.0), "bumps": 1.2, "bump": Vector2(0.04, 0.12), "sway": 0.12, "roll": Vector2(0.0, 0.0),
		"turns": 6.0, "top": 30.0},
	"road": {"about": "a car, a bus, a van, a camper on a road: the road's grain and the engine's hum through the floor, a pothole now and then, the lean of a bend",
		"buzz": 0.35, "band": Vector2(2.0, 30.0), "joint": 0.0, "axles": [], "knock": 0.0,
		"patter": Vector2(1.5, 0.006), "bumps": 1.0, "bump": Vector2(0.05, 0.16), "sway": 0.25, "roll": Vector2(0.0, 0.0),
		"turns": 12.0, "top": 25.0},
	"track": {"about": "a cart, a wagon, a carriage behind horses, on cobbles or a dirt track: a constant jolting, the wheels over every stone, and a hard bump now and then",
		"buzz": 0.4, "band": Vector2(1.0, 14.0), "joint": 0.0, "axles": [], "knock": 0.0,
		"patter": Vector2(3.0, 0.016), "bumps": 2.5, "bump": Vector2(0.06, 0.18), "sway": 0.3, "roll": Vector2(0.0, 0.0),
		"turns": 12.0, "top": 4.0},
	"water": {"about": "a boat or a ship: the slow roll and pitch of the swell, which leans every flame and swings whatever hangs, a shudder when a wave slaps the hull, an engine's hum under way",
		"buzz": 0.08, "band": Vector2(4.0, 40.0), "joint": 0.0, "axles": [], "knock": 0.0,
		"patter": Vector2(0.0, 0.0), "bumps": 1.5, "bump": Vector2(0.03, 0.1), "sway": 0.05, "roll": Vector2(5.0, 8.0),
		"turns": 8.0, "top": 8.0},
	"air": {"about": "an airplane or an airship: the engines' drone, a fine shiver, and the drops and jolts of turbulence now and then",
		"buzz": 0.25, "band": Vector2(3.0, 40.0), "joint": 0.0, "axles": [], "knock": 0.0,
		"patter": Vector2(0.4, 0.008), "bumps": 1.0, "bump": Vector2(0.06, 0.3), "sway": 0.08, "roll": Vector2(1.0, 14.0),
		"turns": 4.0, "top": 220.0},
}

## WHAT A PART CAN DO when the table moves (a part's or a group's `move`, [method sanitize_move]), as an
## agent reads it, and how: `hold`, where it is held when no `at` says (`foot`, the middle of its lowest
## point; `top`; `middle`); its frequency (Hz, or from its reach - [method responder]); `damp`, the share of
## critical damping (low rings long); `wind`, the drag length (meters: how lightly it is blown - smaller
## blows harder; 0 the wind does not reach it).
const MOVES := {
	"sway": {"about": "it stands held at its foot and bends with every jolt, then rings back: a flower or a stalk in a vase, a feather or a quill standing in a pot, a dried grass, a twig - held where it leaves its vase, or at its lowest point",
		"hold": "foot", "damp": 0.07, "wind": 2.0},
	"tremble": {"about": "a thin, light piece that shivers at the least jolt or breath: a petal, a leaf on its stalk, a feather's vane, a page's lifted corner, a tassel - held at its lowest point unless `at` says",
		"hold": "foot", "damp": 0.05, "wind": 0.6},
	"swing": {"about": "it hangs from a point and swings as a pendulum does: a pendulum on its stand, a charm or a crystal on a cord, a pocket watch hung from a stand - held at its top, or its highest point",
		"hold": "top", "damp": 0.04, "wind": 6.0},
	"needle": {"about": "it turns on a pivot and keeps pointing one way while what holds it moves: a compass's needle - it wobbles on its pivot, swings at a jolt and settles back as the ride turns under it, always toward the same north - held at its middle",
		"hold": "middle", "damp": 0.18, "wind": 0.0},
	"rock": {"about": "a loose, heavy thing lying on its own foot: only the hardest jolts rock it a little and set it down again, sometimes a little turned - a stone, a crystal lying on its side, an egg, a die, a bottle",
		"hold": "foot", "damp": 0.22, "wind": 0.0},
	"slosh": {"about": "the surface of a liquid in its vessel: it shivers with every jolt, tips as the floor sways and rings back level - the coffee in a cup, wine in a glass, ink in a well, water in a bowl; one flat part, the liquid's top, held at its middle",
		"hold": "middle", "damp": 0.06, "wind": 0.0},
}

## A NEEDLE: how fast it swings back toward its north (Hz), how much a jolt swings it (radians per m/s of
## the jolt across the table), how much it shivers on its pivot at the buzz (radians rms per m/s² rms),
## and how far it wobbles on its pivot, the share of its swing it tilts.
const NEEDLE := 0.85
const NEEDLE_KICK := 1.2
const NEEDLE_BUZZ := 0.1
const NEEDLE_TILT := 0.12
## A ROCK: the least jolt that rocks one (m/s, at `amount` 0.5 - a lighter thing rocks at less), how far
## it rocks per m/s past that (radians), its rocking's frequency (Hz), and the most it rocks and the most
## it turns on its foot when set down again (degrees, each time, and in all from where it was put).
const ROCK_FROM := 0.035
const ROCK_GAIN := 1.2
const ROCK_HZ := 6.0
const ROCK_MOST := 4.0
const ROCK_TURN := Vector2(0.3, 2.5)
const ROCK_TURN_MOST := 8.0
## A LIQUID'S SURFACE: the share of its motion its first sloshing mode - the whole surface tipping - carries
## (the rest is ripples, too small to see here).
const SLOSH := 0.35
## How much of a jolt straight up a moving thing feels as a push to one side (each its own side): what is
## not balanced over its foot - a flower's head, a needle's heavier end - tips at an upward knock too.
const UPWARD := 0.35
## THE CAMERA'S MOUNT ([method camera]): its frequency (Hz) and damping (a stabilizer's: heavy, so a jolt
## nods the frame and settles in a few frames rather than ringing), how far it turns per m/s² of push
## (radians: a faint buzz is a fraction of a pixel, a hard jolt a few), the share of that it shows across
## (yaw and roll) beside up and down (pitch), the most it turns (radians: a quarter of a degree), and
## THE LENS'S SHARE of all of it - 1 as measured, 0 a camera that never moves.
const MOUNT := Vector2(4.5, 0.35)
const MOUNT_GAIN := 0.0029
const MOUNT_ACROSS := Vector2(0.35, 0.25)
const MOUNT_MOST := 0.0045
const CAMERA := 1.0
## A FLAME ([method flame]): how fast its gas follows a push (Hz) and its damping - a flame leans after a
## jolt within a few hundredths of a second and never rings.
const FLAME := Vector2(6.0, 0.6)
## THE SLOW SWAY: its tones' frequencies (Hz, the least and the most), how many, and how much of it runs
## along the table (forward and back: braking, a gradient) beside across it.
const SWAY_HZ := Vector2(0.12, 0.8)
const SWAYS := 3
const SWAY_ALONG := 0.35
## THE TURNS' periods (seconds, the least and the most): the heading wanders over minutes.
const TURN_PERIOD := Vector2(50.0, 180.0)
## THE BUZZ, as each moving thing answers it: the tones in its narrow band ([method _buzz_of]).
const BUZZ_TONES := 6
## The longest a jolt is still followed in a thing's ring (seconds) - a big one, and a knock or a patter's.
const MEMORY := 24.0
const MEMORY_SMALL := 3.0
## The most moving things one table follows (the rest stand as built).
const MAX_MOVERS := 64


## THE VOCABULARY, as an agent reads it ([CardPrompts.set_dresser], `insert: rides`).
static func describe() -> String:
	var lines := PackedStringArray()
	lines.append("THE RIDE (`ride`): {\"on\", \"rough\" 0-1, \"speed\" 0-1, \"why\"} - what the table is aboard, when the reading is somewhere that moves. Leave it out for a table standing still. on:")
	for k in ON:
		lines.append("- %s: %s" % [k, String((ON[k] as Dictionary)["about"])])
	lines.append("rough: how hard it shakes - 0 smooth (a modern express on welded rail, a calm sea, a new road), 1 hard (an old branch line, a rutted track, a rough sea); 0.4 when left out. speed: how fast it goes - 0 standing (its engine running), 1 its full speed; 0.6 when left out. A boat moored in a harbor rocks gently at speed 0.")
	lines.append("The camera is fixed to the table and rides with it: what the viewer sees of the ride is a faint buzz in the frame and a quick jolt at a bump - and whatever on the table would really move with it, each given a `move` (MOVING PARTS, under the shapes). The ride is heard only when the sound has a `ride`.")
	return "\n".join(lines)


## A part's `move`, in the agent's words (MOVING PARTS in [method Props.describe]).
static func describe_moves() -> String:
	var lines := PackedStringArray()
	lines.append("MOVING PARTS: a part or a GROUP can `move` with what moves the table - its `ride` - and with its wind: {\"kind\", \"at\" [x, y, z] (where it is held, in centimeters in its own space - left out, as the kind says), \"amount\" 0-1 (how freely it moves: 0 stiff or heavy, 1 light and loose; 0.5 when left out)}, or the kind alone (\"move\": \"sway\"). Kinds:")
	for k in MOVES:
		lines.append("- %s: %s" % [k, String((MOVES[k] as Dictionary)["about"])])
	lines.append("Give the move to a GROUP to move all of it as one - a flower's stem, its leaves and its head together - and a part inside it can move again (its petals tremble while the flower sways). What moves stands as built on a table that stands still in still air; a sway, a tremble or a swing stirs in the table's wind too. A part with a flame never moves. Most things stand still: give a move only to what would really move, and only on a table that moves or has a wind.")
	return "\n".join(lines)


## WHATEVER AN AGENT WROTE as `ride`, made safe: `{}` when nothing was written. What had to change is said
## in [param notes].
static func sanitize(raw: Variant, notes: PackedStringArray = PackedStringArray()) -> Dictionary:
	if raw == null:
		return {}
	if not (raw is Dictionary):
		notes.append("the ride was not an object {on, rough, speed, why} - the table stands still")
		return {}
	var d: Dictionary = raw
	if d.is_empty():
		return {}
	var on := String(d.get("on", "")).strip_edges().to_lower() if d.get("on") is String else ""
	if not ON.has(on):
		notes.append("the ride's `on`: \"%s\" is not one of %s - the table stands still" % [str(d.get("on", "")), ", ".join(PackedStringArray(ON.keys()))])
		return {}
	return {"on": on, "rough": Props._num(d.get("rough"), 0.4, 0.0, 1.0), "speed": Props._num(d.get("speed"), 0.6, 0.0, 1.0),
		"why": Props._text(d.get("why", ""), 200)}


## A PART'S `move` made safe: `{}` for none, else `{kind, at (centimeters, or null: as its kind holds it),
## amount}`. What had to change is said in [param notes].
static func sanitize_move(raw: Variant, notes: PackedStringArray = PackedStringArray()) -> Dictionary:
	if raw == null:
		return {}
	var d: Dictionary = {"kind": raw} if raw is String else (raw if raw is Dictionary else {})
	var kind := String(d.get("kind", "")).strip_edges().to_lower() if d.get("kind") is String else ""
	if kind.is_empty() or kind in ["none", "still"]:
		return {}
	if not MOVES.has(kind):
		notes.append("a part's `move`: \"%s\" is not one of %s - it stands still" % [kind, ", ".join(PackedStringArray(MOVES.keys()))])
		return {}
	var at: Variant = null
	if d.get("at") is Array and (d["at"] as Array).size() == 3:
		at = Props._vec3(d["at"], Vector3.ZERO, Props.MAX_SIZE)
	return {"kind": kind, "at": at, "amount": Props._num(d.get("amount"), 0.5, 0.0, 1.0)}


## THE RIDE IN A LINE, for the set dresser's answer and an episode's archive. "" for none.
static func summary(ride: Dictionary) -> String:
	if ride.is_empty():
		return ""
	var r := float(ride["rough"])
	var s := float(ride["speed"])
	return "on %s, %s, %s" % [String(ride["on"]), "smooth" if r < 0.25 else ("rough" if r > 0.7 else "a little rough"),
		"standing" if s < 0.05 else ("at a crawl" if s < 0.25 else ("at full speed" if s > 0.85 else "under way"))]


# --- the plan ------------------------------------------------------------------------------------------

## THE RIDE PLANNED for [param ride] (made safe; `{}` plans none) on [param seed]: its buzz's strength and
## band, its knocks (the period a wheel takes from one rail joint to the next, and the axles' times within
## it), its patter's rate, every bump over [constant Lights.HORIZON] (its time, and its jolt in the table's
## space - x across, y up, z toward the reader, m/s), the sway's tones, the roll's and the turns'. Pure:
## the same ride and seed, the same plan.
static func plan(ride: Dictionary, seed: int) -> Dictionary:
	if ride.is_empty():
		return {}
	var row: Dictionary = ON[String(ride["on"])]
	var rough := float(ride["rough"])
	var speed := float(ride["speed"])
	var r := RandomNumberGenerator.new()
	r.seed = hash([seed, "ride"])
	var going := 0.2 + 0.8 * speed
	var water := String(ride["on"]) == "water"
	var buzz := float(row["buzz"]) * (0.25 + 0.75 * rough) * (lerpf(0.6, 1.0, speed) if water else going)
	# THE KNOCKS: a wheel crosses a joint every `joint` meters, each axle under the car in its turn
	var v := float(row["top"]) * speed
	var period := float(row["joint"]) / v if float(row["joint"]) > 0.0 and v > 0.05 else 0.0
	var axles := PackedFloat32Array()
	for a in row["axles"]:
		axles.append(float(a) / v if v > 0.05 else 0.0)
	var knock := float(row["knock"]) * (0.2 + 0.8 * rough) * (0.3 + 0.7 * speed)
	var pat: Vector2 = row["patter"]
	var patter := Vector2(pat.x * (0.25 + 0.75 * speed), pat.y * (0.3 + 0.7 * rough)) if speed > 0.02 else Vector2.ZERO
	# THE BUMPS: a hard jolt now and then, more of them the rougher and the faster
	var starts := PackedFloat32Array()
	var kicks := PackedVector3Array()
	var rate := float(row["bumps"]) * (0.3 + rough) * (0.3 + 0.7 * speed if not water else 0.5 + 0.5 * rough) / 60.0
	var bump: Vector2 = row["bump"]
	var t := r.randf_range(4.0, 12.0)
	while rate > 1e-4 and t < Lights.HORIZON:
		t += -log(maxf(r.randf(), 1e-6)) / rate
		var k := r.randf_range(bump.x, bump.y) * (0.5 + 0.5 * rough) * (0.5 + 0.5 * speed if not water else 1.0)
		# mostly up and down; a share of it to the side, now one way, now the other
		var side := r.randf_range(0.2, 0.7)
		var a := r.randf() * TAU
		starts.append(t)
		kicks.append(Vector3(cos(a) * side, 1.0, sin(a) * side * SWAY_ALONG * 2.0).normalized() * k)
	var sways: Array = []
	var sw := float(row["sway"]) * (0.3 + 0.7 * rough) * (0.3 + 0.7 * speed if not water else 1.0)
	for i in SWAYS:
		var f := r.randf_range(SWAY_HZ.x, SWAY_HZ.y)
		var along := r.randf_range(-SWAY_ALONG, SWAY_ALONG)
		sways.append({"w": TAU * f, "ph": r.randf() * TAU, "dir": Vector2(1.0, along).normalized(), "a": sw * sqrt(2.0 / float(SWAYS))})
	var roll: Vector2 = row["roll"]
	var rolls: Array = []
	if roll.x > 0.0:
		var deg := roll.x * (0.15 + 0.85 * rough)
		# side to side, and a pitch fore and aft a little faster and half as far
		rolls.append({"w": TAU / (roll.y * r.randf_range(0.85, 1.15)), "ph": r.randf() * TAU, "dir": Vector2(1.0, 0.0), "a": deg_to_rad(deg)})
		rolls.append({"w": TAU / (roll.y * r.randf_range(0.55, 0.75)), "ph": r.randf() * TAU, "dir": Vector2(0.0, 1.0), "a": deg_to_rad(deg * 0.5)})
	var turns: Array = []
	for i in 2:
		turns.append({"w": TAU / r.randf_range(TURN_PERIOD.x, TURN_PERIOD.y), "ph": r.randf() * TAU,
			"a": deg_to_rad(float(row["turns"]) * (0.4 + 0.6 * speed) * (0.6 if i == 0 else 0.4))})
	# the camera's mount buzzes on dice of its own
	var mount := _tones(r, TAU * MOUNT.x, MOUNT.y, 3)
	return {"on": String(ride["on"]), "rough": rough, "speed": speed, "buzz": buzz, "band": row["band"], "period": period,
		"axles": axles, "knock": knock, "patter": patter, "starts": starts, "kicks": kicks, "sways": sways, "rolls": rolls,
		"turns": turns, "mount": mount, "salt": hash([seed, "ride buzz"])}


## WHETHER [param p] MOVES ANYTHING: a ride was written.
static func moves(p: Dictionary) -> bool:
	return not p.is_empty()


## THE BUZZ'S STRENGTH at [param f] Hz ((m/s²)² a hertz): flat over the ride's band, falling off steeply
## either side of it.
static func density(p: Dictionary, f: float) -> float:
	var band: Vector2 = p["band"]
	var s0 := pow(float(p["buzz"]), 2.0) / maxf(band.y - band.x, 1.0)
	return s0 / (1.0 + pow(band.x / maxf(f, 0.01), 4.0)) / (1.0 + pow(f / band.y, 4.0))


## THE JOLTS between [param t0] and [param t1], in the order they come: `[[t, jolt (Vector3, m/s), what]]`
## - what is 0 a bump, 1 a knock, 2 a patter. What [method _rings] sums and the sound strikes.
static func jolts(p: Dictionary, t0: float, t1: float) -> Array:
	var out: Array = []
	if p.is_empty() or t1 <= t0:
		return out
	var starts: PackedFloat32Array = p["starts"]
	var kicks: PackedVector3Array = p["kicks"]
	for i in range(starts.bsearch(t0), starts.bsearch(t1)):
		out.append([starts[i], kicks[i], 0])
	out.append_array(_small(p, t0, t1))
	out.sort_custom(func(x: Array, y: Array) -> bool: return float(x[0]) < float(y[0]))
	return out


## The knocks and the patter between [param t0] and [param t1], as [method jolts] gives them, unsorted.
static func _small(p: Dictionary, t0: float, t1: float) -> Array:
	var out: Array = []
	var period := float(p["period"])
	var salt := int(p["salt"])
	if period > 0.0 and float(p["knock"]) > 0.0:
		var axles: PackedFloat32Array = p["axles"]
		var span := axles[axles.size() - 1] if not axles.is_empty() else 0.0
		for n in range(floori((t0 - span) / period), floori(t1 / period) + 1):
			for k in axles.size():
				var t := float(n) * period + axles[k]
				if t < t0 or t >= t1:
					continue
				# each knock its own, a little harder or softer, a hair to one side
				var h := _hash01(salt, n * 8 + k)
				var s := float(p["knock"]) * (0.7 + 0.6 * h)
				out.append([t, Vector3((_hash01(salt + 1, n * 8 + k) - 0.5) * 0.4, 1.0, 0.0) * s, 1])
	var pat: Vector2 = p["patter"]
	if pat.x > 0.0 and pat.y > 0.0:
		for n in range(floori(t0 * pat.x) - 1, floori(t1 * pat.x) + 1):
			var t := (float(n) + _hash01(salt + 2, n)) / pat.x
			if t < t0 or t >= t1:
				continue
			var s := pat.y * (0.3 + 1.4 * pow(_hash01(salt + 3, n), 2.0))
			var a := _hash01(salt + 4, n) * TAU
			out.append([t, Vector3(cos(a) * 0.45, 1.0, sin(a) * 0.3) * s, 2])
	return out


## A number 0-1 from [param salt] and [param n], the same every time.
static func _hash01(salt: int, n: int) -> float:
	return float(hash([salt, n]) & 0xFFFFFF) / 16777216.0


## THE SLOW PUSH at [param t] (m/s², the table's xz): the sway's tones, and the floor's lean on the swell
## as the push it makes (a deck leaning to the right is gravity pushing to the right).
static func push(p: Dictionary, t: float) -> Vector2:
	var out := Vector2.ZERO
	if p.is_empty():
		return out
	for s in p["sways"]:
		out += (s["dir"] as Vector2) * float(s["a"]) * sin(float(s["w"]) * t + float(s["ph"]))
	return out + tilt(p, t) * 9.81


## HOW FAR THE FLOOR LEANS from true level at [param t] (radians, the table's xz: the way it leans down).
static func tilt(p: Dictionary, t: float) -> Vector2:
	var out := Vector2.ZERO
	if p.is_empty():
		return out
	for s in p["rolls"]:
		out += (s["dir"] as Vector2) * float(s["a"]) * sin(float(s["w"]) * t + float(s["ph"]))
	return out


## HOW FAR THE RIDE HAS TURNED from the way it headed at the start, at [param t] (radians, about the up).
static func heading(p: Dictionary, t: float) -> float:
	var out := 0.0
	if p.is_empty():
		return out
	for s in p["turns"]:
		out += float(s["a"]) * (sin(float(s["w"]) * t + float(s["ph"])) - sin(float(s["ph"])))
	return out


## HOW HARD IT IS JOLTING at [param t], 0 to 1: the jolts of the last fraction of a second, a bump's
## worth at the most - what makes a flame jump.
static func jolting(p: Dictionary, t: float) -> float:
	if p.is_empty():
		return 0.0
	var top := Vector2(ON[String(p["on"])]["bump"]).y
	var out := 0.0
	for j in jolts(p, t - 0.4, t):
		out += (j[1] as Vector3).length() * exp(-(t - float(j[0])) / 0.12)
	return clampf(out / top, 0.0, 1.0)


# --- what answers it ----------------------------------------------------------------------------------

## ONE MOVING THING, made ready to answer [param p]'s ride (`{}`: the table stands still, and only the wind
## moves it): its kind (`move`, made safe), how far it reaches from where it is held (meters - a sway's or a
## swing's length, a slosh's radius, a rock's foot), and [param salt], whose dice give it its own buzz. Its
## frequency comes from that reach: a stalk sways slower the taller it is, a pendulum swings as its length
## says, a cup's coffee rocks at its first sloshing mode.
static func responder(p: Dictionary, move: Dictionary, reach: float, salt: int) -> Dictionary:
	var kind := String(move["kind"])
	var row: Dictionary = MOVES[kind]
	var free := pow(2.0, (float(move.get("amount", 0.5)) - 0.5) * 3.0)
	var L := maxf(reach, 0.004)
	var f := 1.0
	var k := 0.0
	match kind:
		"sway":
			f = clampf(1.1 / sqrt(L), 1.0, 8.0) / sqrt(free)
			k = 1.0 / (L * pow(TAU * f, 2.0))
		"tremble":
			f = clampf(1.6 / sqrt(L), 3.0, 16.0) / sqrt(free)
			k = 1.0 / (L * pow(TAU * f, 2.0)) * 2.0
		"swing":
			f = sqrt(9.81 / L) / TAU
			k = 1.0 / 9.81
		"needle":
			f = NEEDLE / sqrt(free)
			k = 0.0
		"rock":
			f = ROCK_HZ
			k = 0.0
		"slosh":
			f = sqrt(9.81 * 1.84 / L) / TAU
			k = SLOSH / 9.81
	var z := float(row["damp"])
	var w := TAU * f
	var r := RandomNumberGenerator.new()
	r.seed = salt
	var a := r.randf() * TAU
	var out := {"kind": kind, "w": w, "z": z, "k": k * (free if kind in ["sway", "tremble"] else 1.0), "free": free, "reach": L,
		# the slow push and the deck's lean move all of a liquid: it settles level, its surface square to them
		"slow": 1.0 / 9.81 if kind == "slosh" else k * (free if kind in ["sway", "tremble"] else 1.0),
		"up": Vector2(cos(a), sin(a)), "drag": float(row["wind"]) / free, "salt": salt}
	if kind == "rock":
		out["from"] = ROCK_FROM / free
	# the buzz, as this thing makes it: its own tones about its own frequency, on each axis
	var sd := _buzz_of(p, f, z) * float(out["k"]) if not p.is_empty() else 0.0
	if kind == "needle" and not p.is_empty():
		sd = NEEDLE_BUZZ * float(p["buzz"]) * sqrt(free)
	out["buzz"] = sd
	out["tones"] = _tones(r, w, z, 3)
	return out


## THE BUZZ'S ANSWER in a thing ringing at [param f] Hz with damping [param z]: the rms of its motion per
## unit of steady push (Miles' equation - sqrt(pi/2 f Q S(f)), Q the sharpness of its ring).
static func _buzz_of(p: Dictionary, f: float, z: float) -> float:
	return sqrt(PI * 0.5 * f / (2.0 * maxf(z, 0.01)) * density(p, f))


## [param n] axes' narrow bands of tones about [param w] (rad/s), spread as wide as the damping [param z]
## lets a ring wander: each `[w, phase]` x [constant BUZZ_TONES].
static func _tones(r: RandomNumberGenerator, w: float, z: float, n: int) -> Array:
	var out: Array = []
	for ax in n:
		var ws := PackedFloat32Array()
		var ph := PackedFloat32Array()
		for i in BUZZ_TONES:
			ws.append(maxf(w * 0.3, w + z * w * r.randfn(0.0, 1.0)))
			ph.append(r.randf() * TAU)
		out.append([ws, ph])
	return out


## One axis of a narrow band at [param t]: unit rms.
static func _band_at(tones: Array, ax: int, t: float) -> float:
	var ws: PackedFloat32Array = (tones[ax] as Array)[0]
	var ph: PackedFloat32Array = (tones[ax] as Array)[1]
	var s := 0.0
	for i in ws.size():
		s += cos(ws[i] * t + ph[i])
	return s * sqrt(2.0 / float(ws.size()))


## A DAMPED RING: what a jolt of [param dv] (m/s) does to an oscillator of [param w] (rad/s) and damping
## [param z] that leans [param k] per m/s² of steady push, [param tau] seconds after it.
static func _ring(w: float, z: float, k: float, dv: float, tau: float) -> float:
	if tau < 0.0:
		return 0.0
	var wd := w * sqrt(maxf(1.0 - z * z, 0.01))
	return k * w * w * dv / wd * exp(-z * w * tau) * sin(wd * tau)


## THE STEADY ANSWER of an oscillator of [param w] and [param z] that leans [param k] per m/s² of push, to
## a push [param a] sin([param wt] t + [param ph]).
static func _tone(w: float, z: float, k: float, a: float, wt: float, ph: float, t: float) -> float:
	var re := w * w - wt * wt
	var im := 2.0 * z * w * wt
	return k * w * w * a / sqrt(re * re + im * im) * sin(wt * t + ph - atan2(im, re))


## Every jolt still ringing in an oscillator of [param w], [param z] at [param t]: summed along the table's
## x (across), up and z, as `Vector3(across, up, along)` of the ring each would make - its jolt scaled by
## [param k] - and whether any was a bump. [param small] false leaves the knocks and the patter out.
static func _rings(p: Dictionary, w: float, z: float, k: float, t: float, small := true) -> Vector3:
	var out := Vector3.ZERO
	var mem := minf(5.0 / maxf(z * w, 1e-3), MEMORY)
	var starts: PackedFloat32Array = p["starts"]
	var kicks: PackedVector3Array = p["kicks"]
	for i in range(starts.bsearch(t - mem), starts.bsearch(t)):
		out += kicks[i] * _ring(w, z, k, 1.0, t - starts[i])
	if small:
		for j in _small(p, t - minf(mem, MEMORY_SMALL), t):
			out += (j[1] as Vector3) * _ring(w, z, k, 1.0, t - float(j[0]))
	return out


## HOW A MOVING THING [param r] ([method responder]) STANDS at [param t], in the table's space: `lean`, the
## way its top (a hanging thing's weight, a liquid's surface - see below) is tipped (radians, the table's
## xz), and `turn`, how far it has turned about the up (radians). [param p] is the ride's plan, [param wind]
## the table's ([method Winds.plan]; it moves a thing only when it blows - [method Winds.blows]) and
## [param at] where the thing is (the table's space, meters), for the eddies there.
##
## A STANDING OR HANGING THING LAGS what moves it: pushed one way, its top (or its weight) goes the other.
## A LIQUID's surface stands square to what pulls it - true down and the push together - so it tips the way
## the push goes (its far side up as the floor brakes toward the reader). A NEEDLE keeps to its north while
## the ride turns under it, swings at a jolt and wobbles on its pivot. A ROCK moves only at a jolt past what
## its weight holds ([constant ROCK_FROM]), rocks on the edge of its foot and is set down again, turned by a
## degree or two each time, never far from where it was put ([constant ROCK_TURN_MOST]).
static func pose(p: Dictionary, wind: Dictionary, r: Dictionary, t: float, at: Vector3) -> Dictionary:
	var kind := String(r["kind"])
	var w := float(r["w"])
	var z := float(r["z"])
	var k := float(r["k"])
	var lean := Vector2.ZERO
	var turn := 0.0
	var tones: Array = r["tones"]
	var riding := not p.is_empty()
	match kind:
		"sway", "tremble", "swing", "slosh":
			if riding:
				# THE FORCE ON IT, as it answers: the floor's jolts and sway pushed one way leave it behind
				# (minus), and a deck leaning on the swell pulls it downhill
				var rg := _rings(p, w, z, k, t)
				var up: Vector2 = r["up"]
				var felt := -(Vector2(rg.x, rg.z) + up * rg.y * UPWARD)
				var slow := float(r["slow"])
				for s in p["sways"]:
					felt -= (s["dir"] as Vector2) * _tone(w, z, slow, float(s["a"]), float(s["w"]), float(s["ph"]), t)
				for s in p["rolls"]:
					felt += (s["dir"] as Vector2) * _tone(w, z, slow, float(s["a"]) * 9.81, float(s["w"]), float(s["ph"]), t)
				felt += Vector2(_band_at(tones, 0, t), _band_at(tones, 1, t)) * float(r["buzz"])
				# what stands or hangs goes with it; a liquid's surface stands square to it, tipping the
				# other way - level in the world while the deck rolls under it
				lean = felt if kind != "slosh" else -felt
			if Winds.blows(wind) and float(r["drag"]) > 0.0:
				var air := Winds.air_at(wind, t, at)
				var v := Vector2(air.x, air.z)
				lean += v * v.length() / float(r["drag"]) * (k if kind != "swing" else 1.0 / 9.81)
		"needle":
			if riding:
				# north stays where it is while the ride turns: the needle turns back by as much, a little late
				var turned := 0.0
				for s in p["turns"]:
					turned += _tone(w, z, 1.0, float(s["a"]), float(s["w"]), float(s["ph"]), t) - float(s["a"]) * sin(float(s["ph"]))
				# a jolt swings it (about NEEDLE_KICK radians a m/s at its first swing)
				var rg := _rings(p, w, z, NEEDLE_KICK / w, t)
				var up: Vector2 = r["up"]
				var kick := (rg.x + rg.z * 0.6 + rg.y * UPWARD * up.x) * float(r["free"])
				turn = -turned + kick + _band_at(tones, 2, t) * float(r["buzz"])
				# ...and wobbles on its pivot as it swings
				lean = (Vector2(_band_at(tones, 0, t), _band_at(tones, 1, t)) * float(r["buzz"]) + Vector2(rg.z, rg.x)) * NEEDLE_TILT
		"rock":
			if riding:
				var pr := _rocked(p, r, t)
				lean = pr["lean"]
				turn = pr["turn"]
	return {"lean": lean, "turn": turn}


## A ROCK at [param t]: every jolt past what holds it, walked from the first ([method pose]) - the rocking
## of those still ringing, and the turns it was set down with, eased in as it settles.
static func _rocked(p: Dictionary, r: Dictionary, t: float) -> Dictionary:
	var starts: PackedFloat32Array = p["starts"]
	var kicks: PackedVector3Array = p["kicks"]
	var w := float(r["w"])
	var z := float(r["z"])
	var least := float(r["from"])
	var most := deg_to_rad(ROCK_MOST)
	var lean := Vector2.ZERO
	var turn := 0.0
	var rest := 0.0
	var dice := RandomNumberGenerator.new()
	for i in range(0, starts.bsearch(t)):
		var kv: Vector3 = kicks[i]
		var up: Vector2 = r["up"]
		var h := Vector2(kv.x, kv.z) + up * kv.y * UPWARD
		var past := h.length() - least
		if past <= 0.0:
			continue
		dice.seed = hash([int(r["salt"]), i])
		var tau := t - starts[i]
		var a := minf(past * ROCK_GAIN, most)
		lean += -h.normalized() * a * exp(-z * w * tau) * sin(w * tau)
		# set down turned a little - back toward where it was put, once it has wandered
		var d := deg_to_rad(dice.randf_range(ROCK_TURN.x, ROCK_TURN.y)) * minf(1.0, past / least + 0.3)
		var s := 1.0 if dice.randf() < 0.5 else -1.0
		if absf(rest + s * d) > deg_to_rad(ROCK_TURN_MOST):
			s = -s
		rest += s * d
		turn += s * d * smoothstep(0.05, 0.35, tau)
	return {"lean": lean, "turn": turn}


## THE CAMERA'S GIVE at [param t]: how far its mount has turned it (radians - `x` pitch, nodding down at an
## upward jolt; `y` yaw; `z` roll), the buzz and the jolts only ([constant MOUNT]: the slow motion never
## reaches the lens). Zero for a table that stands still.
static func camera(p: Dictionary, t: float) -> Vector3:
	if p.is_empty() or CAMERA <= 0.0:
		return Vector3.ZERO
	var w := TAU * MOUNT.x
	var z := MOUNT.y
	var rg := _rings(p, w, z, MOUNT_GAIN, t)
	var sd := _buzz_of(p, MOUNT.x, z) * MOUNT_GAIN
	var tones: Array = p["mount"]
	var out := Vector3(-rg.y + _band_at(tones, 0, t) * sd,
		(rg.x + _band_at(tones, 1, t) * sd) * MOUNT_ACROSS.x,
		(rg.x * 0.7 + rg.z * 0.3 + _band_at(tones, 2, t) * sd) * MOUNT_ACROSS.y) * CAMERA
	# never past what a mount gives: a soft stop
	return Vector3(_soft(out.x), _soft(out.y), _soft(out.z))


static func _soft(x: float) -> float:
	return MOUNT_MOST * tanh(x / MOUNT_MOST)


## A FLAME ON A TABLE THAT RIDES, at [param t]: how its upright is moved (the table's xz, the tangent of its
## lean: x across, y toward the reader) - toward the push, as hot gas rises against what pulls it, and level
## in the world as the deck rolls - followed within a few hundredths of a second, jolts and all.
static func flame(p: Dictionary, t: float) -> Vector2:
	if p.is_empty():
		return Vector2.ZERO
	var w := TAU * FLAME.x
	var z := FLAME.y
	var k := 1.0 / 9.81
	var rg := _rings(p, w, z, k, t, false)
	var out := Vector2(rg.x, rg.z)
	for s in p["sways"]:
		out += (s["dir"] as Vector2) * _tone(w, z, k, float(s["a"]), float(s["w"]), float(s["ph"]), t)
	return out - tilt(p, t)
