extends SceneTree

## The gate of the work, heard ([WorkSounds]; next/table_physics.md, "Sounds of the work"), with no renderer: a bench's sound made
## offline and measured.
##
##   godot --headless --path . --script res://tests/table/work_sounds_check.gd
##
## - A thing set down is heard as it lands: a glass jar set down sounds at that moment and not before it; an iron pot sounds louder;
##   a paper slip is not heard. The control: the jar carried and held up, never set `down`, makes no sound.
## - Grinding is heard only while it touches: a pestle going round pressed into its mortar scrapes; lifted clear between its rounds,
##   it is silent.
## - Grinding is a scrape, low and rough: most of its energy is under 1 kHz, its loudness in 20 ms pieces varies as a scrape's does,
##   and it is quieter than 0.0055 RMS. The control: steady noise through a band at 2.2 kHz is neither low nor rough by the same
##   measures.
## - What breaks is heard as it breaks: a piece the physics breaks off crunches at that moment, and forty broken off in 0.4 s stay
##   under the levels below. The control: the moment before it, nothing.
## - A boil bubbles, steam does not: a pot brought to the boil bubbles from then; before, it is silent.
## - A paused show holds its sound: the show's time standing still, the player is held where it is; going on, it plays. The control:
##   one tick at the same time (a frame the clock did not tick over) does not hold it.
## - A simmer is a quiet fizz, a rolling boil bubbles: at `boil` 0.2 its bubbles ([Boil]) come ten or more a second, every one
##   ringing above 2 kHz (a millimeter's), and none louder than a third of a rolling boil's biggest; at a rolling boil, over 150 a
##   second, some under 800 Hz. The control: the rolling boil's do ring under 2 kHz, so the simmer's test can fail. The bubbles
##   heard are the bubbles drawn: each the sound hears breaking is among those the table shows on the surface just before it breaks
##   ([method Boil.showing]).
## - Subdued: nothing peaks past [constant WorkSounds.PEAK_MOST], and no 0.4 s of it is louder than a third of the voice's speaking
##   level ([constant VoiceFX.PAD_VOICE_REF]).

var _fails := 0


func _init() -> void:
	_run.call_deferred()


func _ok(cond: bool, what: String) -> void:
	if not cond:
		_fails += 1
		print("  FAIL: " + what)


func _run() -> void:
	await process_frame
	var done: Variant = _bench()
	_ok(done == true, "the bench stopped part way (a script error - see above)")
	done = _simmer()
	_ok(done == true, "the simmer stopped part way (a script error - see above)")
	print("work_sounds_check: %s (%d failure%s)" % ["ALL OK" if _fails == 0 else "FAILED", _fails, "" if _fails == 1 else "s"])
	quit(1 if _fails > 0 else 0)


## How much of [param x]'s energy is under 1 kHz: what two one-pole filters there keep of it.
static func _low_share(x: PackedFloat32Array) -> float:
	var a := 1.0 - exp(-TAU * 1000.0 / float(WorkSounds.RATE))
	var y1 := 0.0
	var y2 := 0.0
	var lo := 0.0
	var all := 0.0
	for v in x:
		y1 += a * (v - y1)
		y2 += a * (y1 - y2)
		lo += y2 * y2
		all += v * v
	return lo / maxf(all, 1e-18)


## How much [param x]'s loudness varies from one 20 ms piece to the next: their RMS's spread over its mean.
static func _roughness(x: PackedFloat32Array) -> float:
	var w := int(0.02 * WorkSounds.RATE)
	var ls := PackedFloat32Array()
	for k in range(0, x.size() - w, w):
		var e := 0.0
		for i in range(k, k + w):
			e += x[i] * x[i]
		ls.append(sqrt(e / float(w)))
	var mean := 0.0
	for l in ls:
		mean += l
	mean /= maxf(float(ls.size()), 1.0)
	var sd := 0.0
	for l in ls:
		sd += (l - mean) * (l - mean)
	return sqrt(sd / maxf(float(ls.size()), 1.0)) / maxf(mean, 1e-12)


static func _medium() -> TableMedium:
	var m := TableMedium.new()
	m._root3 = Node3D.new()
	m._props = Node3D.new()
	m._root3.add_child(m._props)
	m._wind = {}
	return m


static func _stand(m: TableMedium, spec: Dictionary, name: String, cm: Vector2) -> void:
	var safe := Props.sanitize(spec, [])
	var thing: Dictionary = {}
	for t in safe["things"]:
		if String((t as Dictionary)["name"]) == name:
			thing = t
	var b := Props.build(thing, safe["materials"], 5)
	var node: Node3D = b["node"]
	node.transform = Transform3D(Basis.IDENTITY, Vector3(Tables.ORIGIN.x + cm.x * 0.01, 0.0, Tables.ORIGIN.y + cm.y * 0.01))
	m._props.add_child(node)
	m._work.take(thing, b, node)


const SPEC := {"things": [
	{"name": "jar", "parts": [{"shape": "lathe", "profile": [[0, 0], [3, 0], [3, 8], [2.6, 8], [2.6, 0.4], [0, 0.4]], "material": "glass"}]},
	{"name": "pot", "parts": [
		{"shape": "lathe", "profile": [[0, 0], [7, 0], [9, 4], [9.4, 7], [8.8, 7], [8.4, 4], [6.6, 0.6], [0, 0.6]], "material": "iron"},
		{"name": "brew", "shape": "lathe", "profile": [[0, 0.6], [6.6, 0.6], [8.4, 4], [8.6, 5], [0, 5]], "material": "brew"}]},
	{"name": "slip", "parts": [{"shape": "sheet", "outline": "rect", "size": [6, 9], "material": "paper"}]},
	{"name": "mortar", "parts": [
		{"name": "bowl", "shape": "lathe", "profile": [[0, 0], [5, 0], [6, 5], [6.5, 5.3], [5.4, 5], [4.3, 1.2], [0, 1.2]],
			"material": "stone", "points": {"floor": [0, 1.2, 0]}}]},
	{"name": "pestle", "parts": [
		{"name": "pestle", "shape": "lathe", "profile": [[0, 0], [1.1, 0, 0.5], [0.8, 4], [0.9, 12], [0, 12.4]], "smooth": true,
			"material": "stone", "joint": {"kind": "free"}, "points": {"tip": [0, 0, 0], "grip": [0, 12, 0]}}]}],
	"materials": {"glass": {"kind": "glass", "color": "#9ab0c0"}, "iron": {"kind": "metal", "color": "#3a3a3a"},
		"brew": {"kind": "liquid", "color": "#4a3a8a"}, "paper": {"kind": "paper", "color": "#efe6d2"},
		"stone": {"kind": "stone", "color": "#8a8580"}}}

const GRIND := {"thing": "pestle", "part": "pestle", "law": "aim",
	"tip": {"point": "tip", "around": "mortar.floor", "radius": 1.5, "period": 1.5, "press": "mortar", "gap": 0.3},
	"grip": {"point": "grip", "around": "mortar.floor", "lift": 13, "radius": 3.5, "period": 1.5}}


func _bench() -> bool:
	var m := _medium()
	_stand(m, SPEC, "jar", Vector2(30, -10))
	_stand(m, SPEC, "pot", Vector2(-30, -15))
	_stand(m, SPEC, "slip", Vector2(30, 10))
	_stand(m, SPEC, "mortar", Vector2(0, -5))
	_stand(m, SPEC, "pestle", Vector2(12, -5))
	m._work.build({"acts": [
		{"name": "jar-down", "beat": 1, "length": 2, "tracks": [{"thing": "jar", "law": "carry", "to": [20, 0, 0], "lift": 6, "down": true}]},
		{"name": "pot-down", "beat": 1, "length": 2, "tracks": [{"thing": "pot", "law": "carry", "to": [-20, 0, -10], "lift": 4, "down": true}]},
		{"name": "slip-down", "beat": 1, "length": 2, "tracks": [{"thing": "slip", "law": "carry", "to": [20, 0, 15], "lift": 6, "down": true}]},
		{"name": "jar-held", "beat": 1, "length": 2, "tracks": [{"thing": "jar", "law": "carry", "to": [20, 10, 0], "lift": 2}]},
		{"name": "grind", "beat": 1, "length": 4, "tracks": [GRIND]},
		{"name": "lift", "beat": 1, "length": 2, "tracks": [{"thing": "pestle", "part": "pestle", "law": "path",
			"keys": [{"at": 0.0}, {"at": 0.3, "by": [0, 6, 0]}, {"at": 1.0, "by": [0, 6, 0]}]}]},
		{"name": "grind-again", "beat": 1, "length": 3, "tracks": [GRIND]},
		{"name": "boil", "beat": 1, "length": 4, "tracks": [{"thing": "pot", "part": "brew", "law": "to", "state": "boil", "value": 1.0, "between": [0.0, 0.2]}]}]}, 1)
	_ok((m._work.acts as Array).size() == 8, "the bench's acts were not all kept: %s" % "; ".join(m._work.notes))
	m._work.runs = [{"i": 0, "t0": 2.0, "t1": 4.0}, {"i": 1, "t0": 6.0, "t1": 8.0}, {"i": 2, "t0": 10.0, "t1": 12.0},
		{"i": 3, "t0": 14.0, "t1": 16.0}, {"i": 4, "t0": 18.0, "t1": 22.0}, {"i": 5, "t0": 22.0, "t1": 24.0},
		{"i": 6, "t0": 24.0, "t1": 27.0}, {"i": 7, "t0": 29.0, "t1": 33.0}]
	m._work._timelines()
	# a piece broken off, as the bake would say it - and a lump crushed to forty pieces in a moment
	m._work.physics.breaks.append({"t": 13.0, "at": Vector3(Tables.ORIGIN.x, 0.04, Tables.ORIGIN.y - 0.05), "size": 0.003})
	for k in 40:
		m._work.physics.breaks.append({"t": 17.2 + float(k) * 0.01, "at": Vector3(Tables.ORIGIN.x, 0.04, Tables.ORIGIN.y - 0.05), "size": 0.004})
	var ws := WorkSounds.new(m._work)
	var s := ws.render(34 * WorkSounds.RATE)
	var peak := func(a: float, b: float) -> float:
		var p := 0.0
		for i in range(int(a * WorkSounds.RATE), mini(int(b * WorkSounds.RATE), s.size())):
			p = maxf(p, maxf(absf(s[i].x), absf(s[i].y)))
		return p
	var rms := func(a: float, b: float) -> float:
		var e := 0.0
		var n := 0
		for i in range(int(a * WorkSounds.RATE), mini(int(b * WorkSounds.RATE), s.size())):
			e += s[i].x * s[i].x + s[i].y * s[i].y
			n += 2
		return sqrt(e / maxf(n, 1))
	# set down
	var jar := float(peak.call(3.98, 4.3))
	_ok(float(peak.call(3.0, 3.97)) < 1e-5 and jar > 0.003, "the glass jar set down at 4 s: %.4f before it lands, %.4f as it does" % [float(peak.call(3.0, 3.97)), jar])
	var pot := float(peak.call(7.98, 8.5))
	_ok(pot > jar, "the iron pot set down peaks at %.4f, the glass jar at %.4f" % [pot, jar])
	_ok(float(peak.call(11.98, 12.5)) < 0.001, "the paper slip set down is heard: %.4f" % float(peak.call(11.98, 12.5)))
	_ok(float(peak.call(15.5, 17.0)) < 1e-5, "the control: the jar held up, never set down, sounds %.4f" % float(peak.call(15.5, 17.0)))
	# a piece broken off
	_ok(float(peak.call(12.6, 12.99)) < 1e-5 and float(peak.call(12.99, 13.2)) > 0.002, "a piece broken off at 13 s: %.5f before, %.4f as it breaks" % [float(peak.call(12.6, 12.99)), float(peak.call(12.99, 13.2))])
	# grinding, only while it touches
	var grit := float(rms.call(19.0, 21.5))
	var lifted := float(rms.call(22.8, 23.8))
	_ok(grit > 0.002 and lifted < 1e-4, "the pestle grinding pressed into the mortar: %.4f; lifted clear of it: %.5f" % [grit, lifted])
	_ok(float(rms.call(25.0, 26.5)) > 0.002, "the pestle back at it scrapes only %.4f" % float(rms.call(25.0, 26.5)))
	# ...low and rough, and quieter than it was
	var scrape := PackedFloat32Array()
	for i in range(int(19.0 * WorkSounds.RATE), int(21.5 * WorkSounds.RATE)):
		scrape.append(s[i].x + s[i].y)
	var low := _low_share(scrape)
	var rough := _roughness(scrape)
	_ok(low > 0.5 and rough > 0.3 and grit < 0.0055, "the grinding is %.0f%% under 1 kHz (more than 50%%), its 20 ms loudness varies by %.2f (more than 0.3), at %.4f RMS (under 0.0055)" % [
		low * 100.0, rough, grit])
	var hiss := PackedFloat32Array()
	var b := [0.0, 0.0]
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var fc := 2.0 * sin(PI * 2200.0 / float(WorkSounds.RATE))
	for i in scrape.size():
		b[0] = float(b[0]) + fc * float(b[1])
		b[1] = float(b[1]) + fc * (rng.randf_range(-1.0, 1.0) - float(b[0]) - float(b[1]))
		hiss.append(float(b[1]))
	_ok(_low_share(hiss) < 0.5 and _roughness(hiss) < 0.3, "the control: steady noise in a band at 2.2 kHz reads %.0f%% under 1 kHz and varies by %.2f" % [
		_low_share(hiss) * 100.0, _roughness(hiss)])
	print("  grinding: %.0f%% under 1 kHz, roughness %.2f" % [low * 100.0, rough])
	# a boil
	var before := float(peak.call(27.8, 28.9))
	var boiling := float(peak.call(30.0, 33.0))
	_ok(before < 1e-5 and boiling > 0.002, "the pot before its boil: %.5f; at the boil: %.4f" % [before, boiling])
	# subdued
	var loudest := 0.0
	var t := 0.0
	while t < 33.6:
		loudest = maxf(loudest, float(rms.call(t, t + 0.4)))
		t += 0.2
	_ok(float(peak.call(0.0, 34.0)) <= WorkSounds.PEAK_MOST and loudest <= VoiceFX.PAD_VOICE_REF / 3.0,
		"the work peaks at %.4f (no more than %.3f) and its loudest 0.4 s is %.4f RMS (no more than %.3f)" % [float(peak.call(0.0, 34.0)),
		WorkSounds.PEAK_MOST, loudest, VoiceFX.PAD_VOICE_REF / 3.0])
	print("  levels: jar %.4f, pot %.4f, grinding %.4f RMS, boiling %.4f, loudest 0.4 s %.4f RMS" % [jar, pot, grit, boiling, loudest])
	# a paused show
	var host := Node.new()
	root.add_child(host)
	var live := WorkSounds.new(m._work)
	live.tick(30.0, host)
	live.tick(30.0, host)
	var once := live._player.stream_paused
	live.tick(30.0, host)
	var held := live._player.stream_paused
	live.tick(30.02, host)
	_ok(not once and held and not live._player.stream_paused, "paused: one tick still holds the sound %s, two %s, the show going on %s" % [once, held, live._player.stream_paused])
	live.stop()
	host.free()
	m._root3.free()
	m.free()
	return true


func _simmer() -> bool:
	var at := func(b: float) -> Callable: return func(_t: float) -> float: return b
	var simmer := Boil.bubbles(3, 0.0, 10.0, at.call(0.2), Boil.ACROSS)
	var rolling := Boil.bubbles(3, 0.0, 10.0, at.call(2.0), Boil.ACROSS)
	var lowest := func(list: Array) -> float:
		var f := INF
		for bb in list:
			f = minf(f, Boil.pitch(float((bb as Dictionary)["r"])))
		return f
	var biggest := func(list: Array) -> float:
		var r := 0.0
		for bb in list:
			r = maxf(r, float((bb as Dictionary)["r"]))
		return r
	_ok(float(lowest.call(rolling)) < 2000.0, "the control: a rolling boil's bubbles ring no lower than %.0f Hz" % float(lowest.call(rolling)))
	_ok(simmer.size() >= 100 and float(lowest.call(simmer)) > 2000.0, "a simmer (boil 0.2): %d bubbles in 10 s, the lowest ringing at %.0f Hz" % [
		simmer.size(), float(lowest.call(simmer))])
	_ok(rolling.size() >= 1500 and float(lowest.call(rolling)) < 800.0, "a rolling boil: %d bubbles in 10 s, the lowest at %.0f Hz" % [
		rolling.size(), float(lowest.call(rolling))])
	_ok(sqrt(float(biggest.call(simmer)) / Boil.R_ROLLING) < sqrt(float(biggest.call(rolling)) / Boil.R_ROLLING) / 1.5,
		"a simmer's biggest bubble is as loud as a rolling boil's")
	# ...the same bubbles drawn and heard
	var seen := 0
	var heard := Boil.bubbles(3, 5.0, 6.0, at.call(1.0), Boil.ACROSS)
	for bb in heard:
		var tb := float((bb as Dictionary)["t"])
		for sb in Boil.showing(3, tb - 0.01, at.call(1.0), Boil.ACROSS, 64):
			if is_equal_approx(float((sb as Dictionary)["r"]), float((bb as Dictionary)["r"])) and ((sb as Dictionary)["at"] as Vector2).is_equal_approx((bb as Dictionary)["at"]):
				seen += 1
				break
	_ok(not heard.is_empty() and seen == heard.size(), "of %d bubbles heard breaking, only %d were drawn on the surface just before" % [heard.size(), seen])
	return true
