extends SceneTree

## assembly_bake_check: the bricks are real bodies ([AssemblyBake], [AssemblyWorld], next/assembly.md "Real bodies"). A real record from
## a real second process over a real hollow tub: what falls falls at gravity, nothing is flung, nothing is left in the air through a
## stop, no piece lies in another or goes through a wall, every hit is at something moving there and its loudness follows how hard it
## was, a press goes exactly home, the same record comes out twice, and one goes on from what was written. What is pulled turns as it
## comes up and goes straight on into the carry; what is in hand says for how long and with how much room.
##
## Controls: a straight lift and a stop reads as stopping; a fall at the wrong gravity reads as wrong; boxes laid into each other read
## as overlapping; a moment with nothing moving has nothing to hear; another seed is another record; a changed step is a new name.
##
## Run: timeout 600 godot --headless --path . --script tests/table/assembly_bake_check.gd

const Bake := preload("res://src/table/assembly_bake.gd")
const DIR := "res://dist/assembly_bakes/check"
const COLORS := {"red": "#b3261e", "tan": "#c9b185", "gray": "#8b8d8f"}
const TUB_AT := Vector2(-0.26, 0.0)
const TUB_R := 0.12
const TUB_H := 0.09
const PILE_AT := Vector2(0.17, 0.1)

var _fails := 0


func _init() -> void:
	_run.call_deferred()


func _ok(cond: bool, what: String) -> void:
	print(("  ok    " if cond else "  FAIL  ") + what)
	if not cond:
		_fails += 1


func _run() -> void:
	var whole := _bake("whole", _acts(), 7)
	if whole.is_empty():
		_ok(false, "the record could not be made")
		quit(1)
		return
	var log: Assembly = whole["log"]
	var track: AssemblyTrack = whole["track"]
	_ok(track.stock_ready and track.baked_to == log.steps.size(), "the record reached every step: %d of %d" % [track.baked_to, log.steps.size()])
	_stock(log, track)
	_falls(log, track)
	_nothing_flung(track)
	_stops_at_rest(log, track)
	_no_overlap(log, track)
	_walls_hold(log, track)
	_pressed_home(log, track)
	_in_hand(log, track)
	_heard(log, track)
	_same_twice(whole)
	_goes_on()
	print("assembly_bake_check: %s (%d failure%s)" % ["ALL OK" if _fails == 0 else "FAILED", _fails, "" if _fails == 1 else "s"])
	quit(1 if _fails > 0 else 0)


static func _acts() -> Array:
	return [
		{"name": "digging", "ops": [{"do": "dig", "in": "the tub", "seconds": 9.0}, {"do": "pause", "seconds": 3.0}]},
		{"name": "building", "ops": [
			{"do": "put", "part": "brick 2x4 red", "at": [2, 2], "from": "the pile"},
			{"do": "put", "part": "brick 2x4 tan", "at": [2, 2], "from": "the tub"},
			{"do": "try", "part": "brick 2x2 gray", "at": [8, 8], "from": "the pile"},
			{"do": "look", "part": "plate 2x2 tan", "from": "the tub", "seconds": 2.0}]},
		{"name": "turned", "ops": [{"do": "turn", "by": 30}, {"do": "put", "part": "plate 2x4 gray", "at": [2, 2], "from": "the tub"}]},
		{"name": "down", "ops": [{"do": "wreck", "into": "the tub"}]},
	]


## An assembly over a made-up table: a plate, a really hollow tub of what is mixed, a pile on the table.
func _make(seed_value: int) -> Assembly:
	var a := Assembly.new()
	var mix := {"brick": 2.0, "plate": 1.0}
	var all := {"red": 1.0, "tan": 1.0, "gray": 1.0}
	a.spec = {"colors": COLORS, "base": {"size": [16, 16], "color": "gray", "turn": 0.0}, "stock": [
		{"name": "the tub", "thing": "the tub", "fill": 0.8, "count": 90, "colors": all, "kinds": mix},
		{"name": "the pile", "at": [PILE_AT.x * 100.0, PILE_AT.y * 100.0], "radius": 7.0, "count": 16, "colors": all, "kinds": mix}]}
	a.seed_value = seed_value
	var cell := AssemblyHeap.CELL
	var n := int(ceil(TUB_R * 2.0 / cell)) + 2
	var from := TUB_AT - Vector2(TUB_R, TUB_R)
	var ground := PackedFloat32Array()
	ground.resize(n * n)
	for j in n:
		for i in n:
			ground[j * n + i] = 0.003 if (from + Vector2(i, j) * cell).distance_to(TUB_AT) < TUB_R - 0.004 else NAN
	var tub := AssemblyHeap.inside("the tub", from, n, n, ground, TUB_H)
	tub.thing = "the tub"
	tub.deep = 0.06
	var tub_box := AABB(Vector3(TUB_AT.x - TUB_R, 0.0, TUB_AT.y - TUB_R), Vector3(TUB_R * 2.0, TUB_H, TUB_R * 2.0))
	a.world = {"base_at": Vector3.ZERO, "yaw": 0.0, "lens": Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-30.0)), Vector3(0.0, 0.55, 0.55)), "fov": 40.0, "obstacles": [{"name": "the tub", "box": tub_box}],
		"heaps": {"the tub": tub, "the pile": AssemblyHeap.pile("the pile", PILE_AT, 0.07), "aside": AssemblyHeap.pile("aside", Vector2(0.15, -0.08), 0.04)}}
	return a


## A tub as a thing is one, an open shell with a floor: a mesh and nothing but.
static func _tub_faces() -> PackedVector3Array:
	var out := PackedVector3Array()
	var sides := 40
	var c := Vector3(TUB_AT.x, 0.0, TUB_AT.y)
	for s in sides:
		var a0 := TAU * float(s) / float(sides)
		var a1 := TAU * float(s + 1) / float(sides)
		for r in [TUB_R, TUB_R + 0.004]:
			var p0 := c + Vector3(cos(a0), 0.0, sin(a0)) * float(r)
			var p1 := c + Vector3(cos(a1), 0.0, sin(a1)) * float(r)
			var up := Vector3(0.0, TUB_H, 0.0)
			out.append_array(PackedVector3Array([p0, p1, p1 + up, p0, p1 + up, p0 + up]))
		var floor_up := Vector3(0.0, 0.003, 0.0)
		out.append_array(PackedVector3Array([c + floor_up, c + Vector3(cos(a1), 0.0, sin(a1)) * TUB_R + floor_up, c + Vector3(cos(a0), 0.0, sin(a0)) * TUB_R + floor_up]))
	return out


## A record made and read back: `{log, track, names, dir}`, or `{}`.
func _bake(name: String, acts: Array, seed_value: int, keep := false) -> Dictionary:
	var a := _make(seed_value)
	a.perform(acts)
	var dir := ProjectSettings.globalize_path(DIR).path_join(name)
	if not keep and DirAccess.dir_exists_absolute(dir):
		for f in DirAccess.get_files_at(dir):
			DirAccess.remove_absolute(dir.path_join(f))
	DirAccess.make_dir_recursive_absolute(dir)
	var names := a.step_names(hash([seed_value, "check"]))
	var req := TableAssembly.request_of(a, a.spec, [{"faces": _tub_faces(), "sound": "metal", "thing": "the tub"}], dir, names)
	var path := dir.path_join("request.bin")
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_buffer(var_to_bytes(req))
	f.close()
	var out: Array = []
	var code := OS.execute(OS.get_executable_path(), PackedStringArray(["--headless", "--path", ProjectSettings.globalize_path("res://"), "--log-file", dir.path_join("log.txt"),
		"--fixed-fps", str(AssemblyWorld.TICKS), "--script", "res://src/table/assembly_bake.gd", "--", path]), out, true)
	if code != 0:
		print(out)
		return {}
	var track := AssemblyTrack.new(a.pieces.size())
	track.add_stock((bytes_to_var(FileAccess.get_file_as_bytes(dir.path_join("stock.seg"))) as Dictionary)["rest"])
	var k := 0
	var hops := 0
	while k < names.size():
		var file := dir.path_join("%016x.seg" % names[k])
		if FileAccess.file_exists(file):
			var seg: Dictionary = bytes_to_var(FileAccess.get_file_as_bytes(file))
			track.add_stretch(seg)
			for st in seg["steps"]:
				a.take_record(int((st as Dictionary)["k"]), st as Dictionary)
			hops += 1
			k = int(seg["to"])
		else:
			k += 1
	var o := "\n".join(PackedStringArray(out))
	return {"log": a, "track": track, "names": names, "dir": dir, "said": o, "hops": hops}


func _plate_at(log: Assembly, track: AssemblyTrack, tau: float) -> Transform3D:
	return log.base_xf(track.yaw_at(tau, 0.0))


func _end_of(track: AssemblyTrack) -> float:
	var out := 0.0
	for k in track.steps:
		out = maxf(out, float((track.steps[k] as Dictionary)["t1"]))
	return out


## The stock lies as it fell: in its tub, on what is under it, and not one in the air.
func _stock(log: Assembly, track: AssemblyTrack) -> void:
	var out := 0
	var high := 0.0
	var low := INF
	var tilted := 0
	var in_tub := 0
	for id in log.pieces.size():
		var x := track._start_of(id)
		if String((log.pieces[id] as Dictionary)["stock"]) != "the tub":
			continue
		in_tub += 1
		if Vector2(x.origin.x, x.origin.z).distance_to(TUB_AT) > TUB_R:
			out += 1
		high = maxf(high, x.origin.y)
		low = minf(low, x.origin.y)
		if absf((x.basis * Vector3.UP).dot(Vector3.UP)) < 0.95:
			tilted += 1
	_ok(in_tub > 80, "the tub holds what it was filled with: %d" % in_tub)
	_ok(out == 0, "all of it inside the walls it fell between: %d out" % out)
	# ...the world allows a millimeter's sinking, and its floor here is a sheet 3 mm over the table
	_ok(low >= -0.002 and high < TUB_H, "on its floor, under its rim: %.3f to %.3f" % [low, high])
	_ok(tilted > in_tub / 4, "lying as things that fell lie, not stacked flat: %d of %d tilted" % [tilted, in_tub])


## How fast what falls goes on getting faster, the middle of every long fall: gravity, from nothing but where things were. A fall is
## a run of keys going down ever faster, past what any hand's move reaches, ended by a hit.
static func _gravity_of(keys: Array) -> float:
	var seen: Array = []
	for k in keys:
		var a: PackedFloat32Array = k
		var run: Array = []
		var i := 8
		while i < a.size():
			var dt := a[i] - a[i - 8]
			var v := (a[i + 2] - a[i - 6]) / maxf(dt, 1e-5)
			if dt > 1e-3 and dt < 0.08 and v < -0.35 and (run.is_empty() or v <= float((run[run.size() - 1] as Array)[1]) + 0.02):
				run.append([(a[i] + a[i - 8]) * 0.5, v])
			else:
				if run.size() >= 4:
					var first: Array = run[0]
					var last: Array = run[run.size() - 1]
					seen.append((float(first[1]) - float(last[1])) / maxf(float(last[0]) - float(first[0]), 1e-4))
				run = []
			i += 8
	if seen.size() < 3:
		return NAN
	seen.sort()
	return float(seen[seen.size() / 2])


## What falls, falls at the world's gravity.
func _falls(log: Assembly, track: AssemblyTrack) -> void:
	var g := _gravity_of(track.keys)
	_ok(not is_nan(g) and absf(g - 9.81) < 2.0, "what falls falls at gravity: %.2f m/s2" % g)
	# control: a thing falling at a third of that reads as low gravity
	var slow := PackedFloat32Array()
	for i in 40:
		var t := float(i) / 60.0
		slow.append_array(PackedFloat32Array([t, 0.0, 1.0 - 0.5 * t - 0.5 * 3.2 * t * t, 0.0, 0.0, 0.0, 0.0, 1.0]))
	# ...a run ended by a stop, three times over
	var again := slow.duplicate()
	for j in [1.0, 2.0]:
		for i in 40:
			var t := float(i) / 60.0
			again.append_array(PackedFloat32Array([t + float(j) * 2.0, 0.0, 1.0 - 0.5 * t - 0.5 * 3.2 * t * t, 0.0, 0.0, 0.0, 0.0, 1.0]))
	again.append_array(PackedFloat32Array([8.0, 0.0, 5.0, 0.0, 0.0, 0.0, 0.0, 1.0]))
	_ok(absf(_gravity_of([again]) - 3.2) < 0.5, "control: low gravity reads as low gravity: %.2f" % _gravity_of([again]))


## Nothing is flung: a hit no harder than a real drop, and no piece faster than a hand or a fall can make it.
func _nothing_flung(track: AssemblyTrack) -> void:
	var hardest := 0.0
	var n := track.ev_t.size()
	for i in n:
		if track.ev_kind[i].begins_with("hit/"):
			hardest = maxf(hardest, track.ev[i * 6 + 3])
	_ok(hardest < 3.5, "the hardest hit is a drop's, nothing flung: %.2f m/s" % hardest)
	_ok(hardest > 0.3, "control: and things really do hit: %.2f" % hardest)
	var fastest := 0.0
	for k in track.keys:
		var a: PackedFloat32Array = k
		var i := 8
		while i < a.size():
			var dt := a[i] - a[i - 8]
			if dt > 0.004:
				fastest = maxf(fastest, Vector3(a[i + 1] - a[i - 7], a[i + 2] - a[i - 6], a[i + 3] - a[i - 5]).length() / dt)
			i += 8
	_ok(fastest < 3.2, "no piece moves faster than a fall or a hand: %.2f m/s" % fastest)


## A stop is at rest: the record stops, so whatever is moving then hangs where it is for as long as the stop lasts.
func _stops_at_rest(log: Assembly, track: AssemblyTrack) -> void:
	var worst := 0.0
	var stops := 0
	var somewhere := 0.0
	for k in track.steps:
		var st: Dictionary = track.steps[k]
		for s in st["stops"]:
			var a: Array = s
			if float(a[1]) + float(a[3]) <= 0.0:
				continue
			stops += 1
			var at := float(st["t0"]) + float(a[0])
			var hand: Dictionary = st.get("hand", {})
			for id in track.moved_between(at - 0.04, at):
				if at < 0.05 or (int(hand.get("id", -1)) == int(id) and float(a[0]) <= float(hand["to"])):
					continue
				var plate := _plate_at(log, track, at)
				var d := track.pose_of(int(id), at, plate).origin.distance_to(track.pose_of(int(id), at - 0.033, plate).origin)
				worst = maxf(worst, d / 0.033)
		# ...against how fast things go between them
		for tau in [float(st["t0"]) + 0.8, float(st["t0"]) + 1.2]:
			for id in track.moved_between(float(tau) - 0.04, float(tau)):
				var plate := _plate_at(log, track, float(tau))
				somewhere = maxf(somewhere, track.pose_of(int(id), float(tau), plate).origin.distance_to(track.pose_of(int(id), float(tau) - 0.033, plate).origin) / 0.033)
	_ok(stops > 10, "the record stops: %d times" % stops)
	_ok(worst < 0.2, "nothing is moving as it stops, so nothing hangs through one: at most %.3f m/s" % worst)
	_ok(somewhere > 0.3, "control: between them things really do move: %.2f m/s" % somewhere)


## How far two boxes lie in each other (meters; 0 when they do not): by the separating axes.
static func _sunk(a: Transform3D, ha: Vector3, b: Transform3D, hb: Vector3) -> float:
	var ax := [a.basis.x.normalized(), a.basis.y.normalized(), a.basis.z.normalized()]
	var bx := [b.basis.x.normalized(), b.basis.y.normalized(), b.basis.z.normalized()]
	var axes: Array = ax + bx
	for u in ax:
		for v in bx:
			var c: Vector3 = (u as Vector3).cross(v as Vector3)
			if c.length() > 1e-3:
				axes.append(c.normalized())
	var d := b.origin - a.origin
	var least := INF
	for ax_any in axes:
		var n: Vector3 = ax_any
		var ra := absf(n.dot(ax[0])) * ha.x + absf(n.dot(ax[1])) * ha.y + absf(n.dot(ax[2])) * ha.z
		var rb := absf(n.dot(bx[0])) * hb.x + absf(n.dot(bx[1])) * hb.y + absf(n.dot(bx[2])) * hb.z
		var over := ra + rb - absf(n.dot(d))
		if over <= 0.0:
			return 0.0
		least = minf(least, over)
	return least


## No piece lies in another: each as tall as its studs, as the world has it, wherever a dig left them.
func _no_overlap(log: Assembly, track: AssemblyTrack) -> void:
	var boxes: Array = []
	var end := _end_of(track)
	var plate := _plate_at(log, track, end)
	for id in log.pieces.size():
		var q: Dictionary = log.pieces[id]
		var tall := float((Assembly.KINDS[String(q["kind"])] as Dictionary)["h"]) * Assembly.PLATE + Assembly.STUD_H
		var half := Vector3(float(q["w"]) * Assembly.STUD * 0.5, tall * 0.5, float(q["d"]) * Assembly.STUD * 0.5)
		var x := track.pose_of(id, end, plate)
		boxes.append([Transform3D(x.basis, x * Vector3(0.0, tall * 0.5, 0.0)), half])
	var worst := 0.0
	for i in boxes.size():
		var bi: Array = boxes[i]
		for j in range(i + 1, boxes.size()):
			var bj: Array = boxes[j]
			if (bi[0] as Transform3D).origin.distance_to((bj[0] as Transform3D).origin) < 0.09:
				worst = maxf(worst, _sunk(bi[0], bi[1], bj[0], bj[1]))
	_ok(worst < 0.002, "no piece lies in another at the end of it all: at most %.2f mm" % (worst * 1000.0))
	var near := Transform3D(Basis.IDENTITY, Vector3(0.01, 0.0, 0.0))
	_ok(_sunk(Transform3D.IDENTITY, Vector3.ONE * 0.01, near, Vector3.ONE * 0.01) > 0.005, "control: two boxes laid in each other read as that")
	_ok(_sunk(Transform3D.IDENTITY, Vector3.ONE * 0.01, Transform3D(Basis.IDENTITY, Vector3(0.03, 0.0, 0.0)), Vector3.ONE * 0.01) == 0.0, "control: and apart, as apart")


## A wall is a wall: nothing crosses the tub's side below its rim, in or out.
func _walls_hold(log: Assembly, track: AssemblyTrack) -> void:
	var through := 0
	var crossed := 0
	var under := 0
	for id in log.pieces.size():
		var a: PackedFloat32Array = track.keys[id]
		var i := 8
		while i < a.size():
			var r0 := Vector2(a[i - 7], a[i - 5]).distance_to(TUB_AT)
			var r1 := Vector2(a[i + 1], a[i + 3]).distance_to(TUB_AT)
			if (r0 < TUB_R) != (r1 < TUB_R):
				crossed += 1
				# ...its height where it crosses, whatever the line between two keys
				var y := lerpf(a[i - 6], a[i + 2], (TUB_R - r0) / (r1 - r0))
				if y < TUB_H - 0.012:
					through += 1
					print("    through at piece %d, tau %.2f to %.2f: r %.3f to %.3f, y %.3f" % [id, a[i - 8], a[i], r0, r1, y])
			if a[i + 2] < -0.002:
				under += 1
			i += 8
	_ok(through == 0, "nothing goes through a tub's wall: %d of %d crossings" % [through, crossed])
	_ok(crossed > 0, "control: things do come out of it, over the rim: %d" % crossed)
	_ok(under == 0, "nothing goes through the table: %d" % under)


## What is pressed home is exactly home: on the lattice, goes with the plate, and comes away with the wreck.
func _pressed_home(log: Assembly, track: AssemblyTrack) -> void:
	var seated := 0
	var off := 0
	var worst := 0.0
	var turned := 0.0
	for id in log.pieces.size():
		for s in track.seats[id]:
			var a: Array = s
			seated += 1
			if float(a[1]) == INF:
				off -= 1
			var on := float(a[0]) + 0.01
			var at := track.pose_of(id, on, _plate_at(log, track, on))
			worst = maxf(worst, at.origin.distance_to(_plate_at(log, track, on) * (a[2] as Transform3D).origin))
	for k in track.turns:
		turned = maxf(turned, absf(float((k as Array)[3]) - float((k as Array)[2])))
	_ok(seated == 3, "three pieces pressed home: %d" % seated)
	_ok(off == 0, "and the wreck took every one of them: %d left" % -off)
	_ok(worst < 0.001, "on the lattice exactly: %.4f m off" % worst)
	_ok(absf(turned - deg_to_rad(30.0)) < 1e-3, "the plate turned: %.3f" % turned)


## What is heard is what happened: every hit where something was really moving at that moment; a stop has none; how hard is how loud;
## a carry through clear air is silent; a press home clicks.
func _heard(log: Assembly, track: AssemblyTrack) -> void:
	var hits := 0
	var unexplained := 0
	var clicks := 0
	var by_kind := {}
	for i in track.ev_t.size():
		var kinds := track.ev_kind[i].split("/")
		by_kind[track.ev_kind[i]] = int(by_kind.get(track.ev_kind[i], 0)) + 1
		if kinds[0] == "click":
			clicks += 1
		if kinds[0] != "hit":
			continue
		hits += 1
		var at := Vector3(track.ev[i * 6], track.ev[i * 6 + 1], track.ev[i * 6 + 2])
		var tau := track.ev_t[i]
		var moving := false
		var plate := _plate_at(log, track, tau)
		for id in track.moved_between(tau - 0.05, tau + 0.05):
			var p0 := track.pose_of(int(id), tau - 0.05, plate).origin
			var p1 := track.pose_of(int(id), tau + 0.05, plate).origin
			# ...where it is at that moment: a brick falling at 2 m/s is 10 cm from where it landed a twentieth of a second before
			if track.pose_of(int(id), tau, plate).origin.distance_to(at) < 0.1 and p0.distance_to(p1) > 1e-4:
				moving = true
				break
		if not moving:
			unexplained += 1
	_ok(hits > 50, "a dig and a wreck are many real hits: %d, %s" % [hits, str(by_kind)])
	_ok(unexplained == 0, "each at a piece really moving there, then: %d not" % unexplained)
	_ok(clicks == 3, "each press home clicks: %d" % clicks)
	_ok(by_kind.has("hit/metal"), "a piece against the tin rings as tin: %s" % str(by_kind.keys()))
	_ok(by_kind.has("hit/hand"), "a piece against the hand is a soft thing: %s" % str(by_kind.keys()))
	_ok(WorkSounds.hit_level(1.0, 1.5, "plastic") > 8.0 * WorkSounds.hit_level(0.15, 1.5, "plastic"), "a hard hit is far louder than a gentle one: %.5f, %.5f" % [WorkSounds.hit_level(1.0, 1.5, "plastic"), WorkSounds.hit_level(0.15, 1.5, "plastic")])
	_ok(WorkSounds.hit_level(1.0, 1.5, "hand") < WorkSounds.hit_level(1.0, 1.5, "plastic") * 0.5, "against a hand, softer")
	# ...a stop is silent, the record holds nothing there: control, a moment of nothing has nothing
	var quiet_at := -1.0
	for k in track.steps:
		if String((log.steps[int(k)] as Dictionary)["do"]) == "pause":
			quiet_at = float((track.steps[k] as Dictionary)["t0"])
	_ok(quiet_at > 0.0 and track.events_between(quiet_at, quiet_at).is_empty(), "control: a stop has nothing to hear")
	# ...a piece carried through the air is silent, the last of a put from over its place to home
	var put: Dictionary = {}
	for k in track.steps:
		if String((log.steps[int(k)] as Dictionary)["do"]) == "put":
			put = track.steps[k]
			break
	var stops: Array = put["stops"]
	var hover := float(put["t0"]) + float((stops[1] as Array)[0])
	var hits_after := 0
	for i in track.events_between(hover + 0.05, float(put["t1"])):
		if track.ev_kind[i].begins_with("hit/"):
			hits_after += 1
	_ok(hits_after == 0, "a piece lowered into its place through clear air hits nothing: %d" % hits_after)


## What is pulled is pulled, and what is in hand says so ([method AssemblyBake._pull], [Fingers]): every piece taken has a stretch in
## hand with no room at either end and its record exact at both. A pull turns as it comes up and never comes to rest on its way to
## the next move. Control: a straight lift and a stop is called one.
func _in_hand(log: Assembly, track: AssemblyTrack) -> void:
	var hands := 0
	var well := true
	var turned_most := 0.0
	var turned_least := INF
	var slowest := INF
	for k in track.steps:
		var st: Dictionary = track.steps[k]
		var do := String((log.steps[int(k)] as Dictionary)["do"])
		if not st.has("hand"):
			_ok(do not in ["put", "try", "look"], "a %s takes a piece, so has a hand" % do)
			continue
		var hand: Dictionary = st["hand"]
		hands += 1
		var knots: Array = hand["knots"]
		well = well and float(hand["to"]) > float(hand["from"]) and float((knots[0] as Array)[1]) == 0.0 and float((knots[knots.size() - 1] as Array)[1]) == 0.0
		for i in range(1, knots.size()):
			well = well and float((knots[i] as Array)[0]) >= float((knots[i - 1] as Array)[0]) - 1e-4
		var id := int(hand["id"])
		var t0 := float(st["t0"]) + float(hand["from"])
		var a := track.pose_of(id, t0, _plate_at(log, track, t0))
		var b := track.pose_of(id, t0 + 0.3, _plate_at(log, track, t0 + 0.3))
		var turn := rad_to_deg(a.basis.get_rotation_quaternion().angle_to(b.basis.get_rotation_quaternion()))
		turned_most = maxf(turned_most, turn)
		turned_least = minf(turned_least, turn)
		# ...from the draw into the carry, up to half way across, it goes on going
		var run_from := t0 + float(Bake.GRIP_TAKES.y) + 0.05
		var run_to := float(st["t0"]) + float((knots[2] as Array)[0])
		slowest = minf(slowest, _least_speed(func(at: float) -> Vector3: return track.pose_of(id, at, _plate_at(log, track, at)).origin, run_from, run_to))
	_ok(hands >= 4, "every piece taken has its time in hand: %d" % hands)
	_ok(well, "with no room at either end of it, and its room in order")
	_ok(turned_least > 2.0, "a pull turns a piece as it comes up, every one: %.0f to %.0f degrees in its first 0.3 s" % [turned_least, turned_most])
	_ok(slowest > 0.015, "and it never stops on its way from the draw into the carry: %.3f m/s at the least" % slowest)
	var up_then_go := func(at: float) -> Vector3:
		return Vector3(0.0, 0.1 * Hands.smooth(at / 0.5), 0.0) + Vector3(0.2 * Hands.smooth((at - 0.5) / 1.0), 0.0, 0.0)
	_ok(_least_speed(up_then_go, 0.1, 1.0) < 0.015, "control: up, stop and off, as it was, is called one: %.3f m/s" % _least_speed(up_then_go, 0.1, 1.0))
	# ...and what is held up is held somewhere of its own, off the middle of the frame and in it
	var lens: Transform3D = log.world["lens"]
	var fov := float(log.world["fov"])
	var spots: Array = []
	for k in track.steps:
		var st: Dictionary = track.steps[k]
		if String((log.steps[int(k)] as Dictionary)["do"]) != "look" or not st.has("hand"):
			continue
		var at := float(st["t0"]) + float(((st["stops"] as Array)[1] as Array)[0])
		spots.append(track.pose_of(int((st["hand"] as Dictionary)["id"]), at, _plate_at(log, track, at)).origin)
	_ok(not spots.is_empty(), "something is held up to be looked at: %d" % spots.size())
	for p in spots:
		var v: Vector3 = lens.affine_inverse() * (p as Vector3)
		var high := tan(deg_to_rad(fov * 0.5)) * -v.z
		var sx: float = v.x / (high * float(Bake.VIEW_ASPECT))
		var sy := v.y / high
		_ok(absf(sx) < 0.95 and absf(sy) < 0.95, "it is in the frame: %.2f, %.2f of the way to its edges" % [sx, sy])
		_ok(absf(sx) > 0.12, "and not in its middle: %.2f across" % sx)


## The least speed along [param where] (a Callable of time) from [param a] to [param b] (m/s).
static func _least_speed(where: Callable, a: float, b: float) -> float:
	var least := INF
	var t := a
	while t + 0.02 < b:
		least = minf(least, (where.call(t + 0.02) as Vector3).distance_to(where.call(t) as Vector3) / 0.02)
		t += 0.02
	return least


## The same thing twice, to the byte: what the show is, and so what an export is. Another seed, another record.
func _same_twice(first: Dictionary) -> void:
	var again := _bake("again", _acts(), 7)
	var other := _bake("other", _acts(), 8)
	if again.is_empty() or other.is_empty():
		_ok(false, "the other records could not be made")
		return
	var a: AssemblyTrack = first["track"]
	var b: AssemblyTrack = again["track"]
	var c: AssemblyTrack = other["track"]
	var same := a.keys.size() == b.keys.size()
	for id in mini(a.keys.size(), b.keys.size()):
		if (a.keys[id] as PackedFloat32Array) != (b.keys[id] as PackedFloat32Array):
			same = false
			break
	_ok(same, "the same steps and seed make the same record, every piece's every key")
	_ok(a.ev_t == b.ev_t, "and the same sounds at the same moments: %d, %d" % [a.ev_t.size(), b.ev_t.size()])
	var differ := false
	for id in mini(a.keys.size(), c.keys.size()):
		if (a.keys[id] as PackedFloat32Array) != (c.keys[id] as PackedFloat32Array):
			differ = true
			break
	_ok(differ, "control: another seed is another record")


## A record goes on from what is written: a new act costs what comes after it, and a changed step what comes after that.
func _goes_on() -> void:
	var short: Array = _acts().slice(0, 2)
	var one := _bake("on", short, 7)
	if one.is_empty():
		_ok(false, "the first of it could not be made")
		return
	var dir := String(one["dir"])
	var had := DirAccess.get_files_at(dir)
	var times := {}
	for f in had:
		if String(f).ends_with(".seg"):
			times[f] = FileAccess.get_file_as_bytes(dir.path_join(f)).size()
	var more: Array = short.duplicate(true)
	more.append(_acts()[3])
	var two := _bake("on", more, 7, true)
	if two.is_empty():
		_ok(false, "the rest of it could not be made")
		return
	var log: Assembly = two["log"]
	var track: AssemblyTrack = two["track"]
	_ok(track.baked_to == log.steps.size(), "it reaches the new end: %d of %d" % [track.baked_to, log.steps.size()])
	var first_step := int((one["log"] as Assembly).steps.size())
	_ok(String(FileAccess.get_file_as_string(dir.path_join("log.txt"))).contains("from step %d" % first_step), "and began where the last one had stopped, at step %d" % first_step)
	for f in times:
		_ok(FileAccess.get_file_as_bytes(dir.path_join(String(f))).size() == int(times[f]), "what was written stays: %s" % String(f))
	# ...where it goes on, nothing jumps
	var at := float((track.steps[first_step - 1] as Dictionary)["t1"])
	var plate := log.base_xf(track.yaw_at(at, 0.0))
	var jumped := 0.0
	for id in log.pieces.size():
		jumped = maxf(jumped, track.pose_of(id, at - 0.01, plate).origin.distance_to(track.pose_of(id, at + 0.01, plate).origin))
	_ok(jumped < 0.02, "and nothing jumps where it took up again: %.4f m" % jumped)
	var a := _make(7)
	a.perform(short)
	var b := _make(7)
	var edited: Array = short.duplicate(true)
	((edited[0] as Dictionary)["ops"] as Array)[0] = {"do": "dig", "in": "the tub", "seconds": 4.0}
	b.perform(edited)
	var na := a.step_names(1)
	var nb := b.step_names(1)
	_ok(na[0] != nb[0] and na[na.size() - 1] != nb[nb.size() - 1], "control: a step changed is a new name, for it and all after it")
