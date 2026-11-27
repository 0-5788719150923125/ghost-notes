extends RefCounted
class_name StudioSounds

## StudioSounds - the studio heard (next/studio.md, "The sound"): each act's sound made from its contact lanes by the music host
## (hosts/music/contact.py, on its own process), kept by the hash of what it was asked in [member root], read into frames on a
## worker, and played at the show time the act was placed at, over a quiet room tone (the silence between is never digital).
##
## A pure function of show time ([method tick]): begun again where the show jumps, what is sounding picks up where it would be,
## so a render hears what the live show heard. A sound not made yet is silent until it is. Levels are the host's, absolute:
## nothing here normalizes an act.
##
## AN ACT'S SOUND IS MADE IN WINDOWS ([method make_all]): an act longer than [constant WINDOW] is a run of windows, each made from
## its stretch of the act's motion with the motion before it settling the filters ([constant PRE]), each laid over the next at equal
## power ([constant OVERLAP]) - so a hand that goes on for minutes is heard as soon as its first window is made, the rest made as
## the show comes to them, and none of it depends on how long the act turns out to be. Where an act ends is the medium's to say
## ([method place] `end`): the window sounding then dies away over the hand's lift ([constant RELEASE]), and those after are never
## laid. Only the windows near the show are held as frames ([constant AHEAD], [constant BEHIND]); the rest stay on the disk.
##
## [method want] hands it the acts' sounds (`{key: spec}`), [method place] when each begins; [method pump] each frame starts what
## must be made or read; [method level_at] is what the camera's meters show. Two kinds use it: the medium, which plays (it reads
## each sound into frames, and makes one still missing as it is wanted), and the Studio's rows on the Medium card, which make
## every sound missing on their own as soon as it is (the Pipeline's: [member reads] off; a row's ⟳ asks for another take). A sound
## one of them is making the other waits for ([member _inflight]), never makes twice.

const ENV := "music_venv"
const VENV := "user://music_venv"
const SCRIPT := "res://hosts/music/contact.py"
const ROOT := "user://studio_sounds"
## The rate the host makes at (contact.py RATE), how far ahead of the show the sound is kept, how far the show may jump before it
## begins again there, the player's buffer (s), and how many sounds are made at once.
const RATE := 44100
const LEAD := 0.15
const RESET := 0.35
const BUFFER := 0.5
const AT_ONCE := 2
## The room's own tone under everything: its level (RMS, full scale), how long its loop is and how long its seam is eased (s).
const ROOM := 0.00045
const ROOM_LOOP := 7.0
const ROOM_SEAM := 0.8
## The meters' window (s).
const METER := 0.05
## An act's sound's windows: how long each is, how far before it the motion it is made from begins, and how long it is laid
## over the next (s); and how long an act's sound dies away once it ends - the hand lifting.
const WINDOW := 8.0
const PRE := 0.6
const OVERLAP := 0.25
const RELEASE := 0.45
## The windows held as frames: those within [constant AHEAD] seconds after the show and [constant BEHIND] before it; and how many
## windows one process makes.
const AHEAD := 20.0
const BEHIND := 4.0
const BATCH := 4

## Where the sounds are kept: moved aside under test, so a gate never writes the author's.
static var root := ROOT
## The sounds being made now, by whoever makes them: a key -> true.
static var _inflight := {}

## Whether it reads each sound into frames (to play it), or only knows it is made (to list it).
var reads := true
## When the show's last sound ends and how long its outro is (s): from a beat after it, everything heard here goes down to silence
## with the picture ([method ShowOpening.fade_out]). INF until the medium knows it.
var fade_from := INF
var outro := 0.0
## Whether it makes every sound it is handed that is missing, or only those asked for ([method ask]).
var auto := true
var _asked := {}                 # a sound's key -> true: asked to be made though [member auto] is off
var _made_files := {}            # a sound's key -> true: made, where it is not read
var _on_disk := {}               # a sound's key -> true: known made (its file there), read or not
var now := 0.0                   # the show's time, as the medium last said it: what is read and kept near

var status := ""                 # what it is doing, said where a person can read it
var _specs := {}                 # a sound's key -> what it is asked (contact.py's spec, lanes as plain arrays)
var _clips := {}                 # a sound's key -> its frames, once read
var _reading := {}               # a sound's key -> {task, box}: its WAV being read on a worker
var _making := {}                # a sound's key -> {pid, done, wav}: being made on the host
var _failed := {}                # a sound's key -> why it could not be made (not asked again this session)
var _placed: Array = []          # {key, t0, len, end}, in the order they begin
var _room := PackedVector2Array()
var _room_task := -1
var _room_box := {}
var _player: AudioStreamPlayer = null
var _pb: AudioStreamGeneratorPlayback = null
var _at := NAN
var still := StillClock.new()


## What each act sounds like: [param specs] `{key: spec}` ([method key_of]). What is kept is read; what is not is made.
func want(specs: Dictionary) -> void:
	_specs = specs
	var made := 0
	for k in specs:
		if ready_for(k):
			made += 1
	status = "" if made == specs.size() else "making the studio's sounds: %d of %d" % [made, specs.size()]


## When each sound begins: [param placed] `[{key, t0, end}]` - `end` (show time, INF while unknown) where its act ends: from there
## it dies away over [constant RELEASE]. Each is held to how long its sound is ([method length_of]).
func place(placed: Array) -> void:
	_placed = []
	for p in placed:
		var q := (p as Dictionary).duplicate()
		q["len"] = length_of(String(q["key"]))
		if not q.has("end"):
			q["end"] = INF
		_placed.append(q)
	_placed.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["t0"]) < float(b["t0"]))


## How long sound [param key] runs (s): its spec's own length and tail (0 for one not handed).
func length_of(key: String) -> float:
	var sp: Dictionary = _specs.get(key, {})
	return float(sp.get("secs", 0.0)) + float(sp.get("tail", 0.0))


## The host's own code, as a number: a sound is kept by what it was asked AND what made it, so a change to the synthesizer
## makes every sound again.
static var _stamp := -1

## A sound's key: the hash of what it is asked and of the host that makes it.
static func key_of(spec: Dictionary) -> String:
	if _stamp < 0:
		var text := ""
		for f in [SCRIPT, "res://hosts/music/dsp.py"]:
			text += FileAccess.get_file_as_string(BundledHosts.path(f)) if not BundledHosts.path(f).is_empty() else ""
		_stamp = absi(text.hash())
	return "%08x" % (hash([JSON.stringify(spec), _stamp]) & 0xffffffff)


## An act's sound ([method StudioActs.make]'s `sound`) as the host is handed it: every lane plain numbers, rounded to what is
## heard (a tenth of a millimeter, a thousandth of a newton).
static func spec_of(sound: Dictionary) -> Dictionary:
	var out := sound.duplicate(true)
	var contacts: Array = []
	for c in sound.get("contacts", []):
		var cc := (c as Dictionary).duplicate(true)
		var lanes := {}
		for k in (c as Dictionary)["lanes"]:
			var src: PackedFloat32Array = (c as Dictionary)["lanes"][k]
			var step := 0.001 if k == "force" else 0.0001
			var arr: Array = []
			arr.resize(src.size())
			for i in src.size():
				arr[i] = snappedf(src[i], step)
			lanes[k] = arr
		cc["lanes"] = lanes
		contacts.append(cc)
	out["contacts"] = contacts
	var hits: Array = []
	for h in sound.get("hits", []):
		var hh := (h as Dictionary).duplicate(true)
		hh["t"] = snappedf(float(hh["t"]), 0.00001)
		hh["speed"] = snappedf(float(hh["speed"]), 0.0001)
		hh["at"] = (hh["at"] as Array).map(func(v: Variant) -> float: return snappedf(float(v), 0.0001))
		hits.append(hh)
	out["hits"] = hits
	return out


## Where sound [param key] is kept.
static func wav_of(key: String) -> String:
	return root.path_join(key + ".wav")


## Each frame: what is made read, what must be made started (a few at once), what was read taken.
func pump() -> void:
	if _room.is_empty() and _room_task < 0:
		_room_box = {}
		var box := _room_box
		_room_task = WorkerThreadPool.add_task(func() -> void: box["frames"] = room_tone())
	if _room_task >= 0 and WorkerThreadPool.is_task_completed(_room_task):
		WorkerThreadPool.wait_for_task_completion(_room_task)
		_room_task = -1
		_room = _room_box.get("frames", PackedVector2Array())
	for k in _reading.keys():
		var job: Dictionary = _reading[k]
		if WorkerThreadPool.is_task_completed(int(job["task"])):
			WorkerThreadPool.wait_for_task_completion(int(job["task"]))
			_reading.erase(k)
			var frames: PackedVector2Array = (job["box"] as Dictionary).get("frames", PackedVector2Array())
			if not frames.is_empty():
				_clips[k] = frames
				want(_specs)
	# a batch made: each of its windows read where it is near, or known made
	var done_jobs := {}
	for k in _making.keys():
		var m: Dictionary = _making[k]
		if Subprocess.alive(int(m["pid"])):
			continue
		_making.erase(k)
		_inflight.erase(k)
		var res: Variant = done_jobs.get(String(m["done"]))
		if res == null:
			res = JSON.parse_string(FileAccess.get_file_as_string(String(m["done"]))) if FileAccess.file_exists(String(m["done"])) else {}
			done_jobs[String(m["done"])] = res
		var one: Variant = ((res as Dictionary).get("made", {}) as Dictionary).get(ProjectSettings.globalize_path(wav_of(k))) if res is Dictionary else null
		if one is Dictionary and bool((one as Dictionary).get("ok", false)):
			_on_disk[k] = true
			if not reads:
				_made_files[k] = true
				_asked.erase(k)
		else:
			var e := String((one as Dictionary).get("error", "")) if one is Dictionary else ""
			_failed[k] = e if not e.is_empty() else "the host stopped (its log: %s)" % String(m["log"])
			status = "a studio sound could not be made: " + String(_failed[k])
	for d in done_jobs:
		DirAccess.remove_absolute(String(d))
		DirAccess.remove_absolute(String(d).trim_suffix(".done.json") + ".spec.json")
	if reads:
		_keep_near()
	# what must be made, soonest first, a batch at a time
	var batch: Array = []
	var pids := {}
	for k in _making:
		pids[int((_making[k] as Dictionary)["pid"])] = true
	var procs := pids.size()
	for k in _order():
		if _on_disk.has(k) or _made_files.has(k) or _making.has(k) or _failed.has(k) or _inflight.has(k):
			continue
		if FileAccess.file_exists(wav_of(k)):
			_on_disk[k] = true
			if not reads:
				_made_files[k] = true
			continue
		if procs >= AT_ONCE or not (auto or _asked.has(k)):
			continue
		batch.append(k)
		if batch.size() >= BATCH:
			_make(batch)
			procs += 1
			batch = []
	if not batch.is_empty() and procs < AT_ONCE:
		_make(batch)


## Every sound handed, those placed first by when they begin from just before the show on, then the rest as handed: what is made
## first.
func _order() -> Array:
	var out: Array = []
	var seen := {}
	var later: Array = []
	for p in _placed:
		var k := String((p as Dictionary)["key"])
		if seen.has(k) or not _specs.has(k):
			continue
		seen[k] = true
		if float(p["t0"]) + float(p["len"]) < now - 1.0:
			later.append(k)
		else:
			out.append(k)
	out.append_array(later)
	for k in _specs:
		if not seen.has(k):
			out.append(k)
	return out


## The windows near the show read into frames; those far from it let go (read again when the show comes back to them).
func _keep_near() -> void:
	var near := {}
	for p in _placed:
		var t0 := float((p as Dictionary)["t0"])
		var t1 := minf(t0 + float(p["len"]), float(p["end"]) + RELEASE)
		if t1 >= now - BEHIND and t0 <= now + AHEAD:
			near[String(p["key"])] = true
	for k in _clips.keys():
		if not near.has(k):
			_clips.erase(k)
	for k in near:
		if _clips.has(k) or _reading.has(k) or _failed.has(k):
			continue
		if _on_disk.has(k) or FileAccess.file_exists(wav_of(k)):
			_on_disk[k] = true
			_read(k)


## Sound [param key]'s WAV read into frames on a worker - or, where it does not read, known made.
func _read(key: String) -> void:
	if not reads:
		_made_files[key] = true
		_asked.erase(key)
		return
	var box := {}
	var wav := wav_of(key)
	var task := WorkerThreadPool.add_task(func() -> void: box["frames"] = SoundEffects.frames_of(wav))
	_reading[key] = {"task": task, "box": box}


## Sounds [param keys] made on one of the music host's own processes (a batch), the music environment installed first if it must be.
func _make(keys: Array) -> void:
	var fail := ""
	if not writable():
		fail = "this session is read-only: a sound is made when the note plays"
	elif not Provision.unsupported(ENV).is_empty():
		fail = "the music environment cannot be installed here: " + Provision.unsupported(ENV)
	elif not Provision.ensure(ENV):
		status = "installing the music environment (%s)" % String(Deps.entry(ENV).get("size", ""))
		return
	var py := Deps.venv_bin(VENV, "python")
	var script := BundledHosts.path(SCRIPT)
	if fail.is_empty() and (not FileAccess.file_exists(py) or script.is_empty()):
		fail = "the music environment is not installed"
	if not fail.is_empty():
		for k in keys:
			_failed[String(k)] = fail
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(root))
	var stem := ProjectSettings.globalize_path(wav_of(String(keys[0]))).get_basename()
	var batch: Array = []
	for k in keys:
		var spec := (_specs[String(k)] as Dictionary).duplicate()
		spec["seed"] = String(k).hex_to_int() % 99991
		spec["out"] = ProjectSettings.globalize_path(wav_of(String(k)))
		batch.append(spec)
	var f := FileAccess.open(stem + ".spec.json", FileAccess.WRITE)
	if f == null:
		for k in keys:
			_failed[String(k)] = "could not write " + stem + ".spec.json"
		return
	f.store_string(JSON.stringify({"batch": batch, "done": stem + ".done.json"}))
	f.close()
	var pid := Subprocess.start_logged(py, PackedStringArray(["-I", script, stem + ".spec.json"]), stem + ".log", "studio")
	if pid <= 0:
		for k in keys:
			_failed[String(k)] = "the music host could not start"
		return
	for k in keys:
		_making[String(k)] = {"pid": pid, "done": stem + ".done.json", "log": stem + ".log"}
		_inflight[String(k)] = true


## Whether this session may make sounds where they are kept: a read-only one (a gate, an export) uses only those already
## made, unless [member root] was moved aside for it.
static func writable() -> bool:
	if root != ROOT:
		return true
	var tree := Engine.get_main_loop() as SceneTree
	var st: Node = tree.root.get_node_or_null("Settings") if tree != null and tree.root != null else null
	return st != null and not bool(st.call("is_read_only"))


## Whether sound [param key] is as ready as it will be: made, or known not to be makeable.
func ready_for(key: String) -> bool:
	return _on_disk.has(key) or _clips.has(key) or _made_files.has(key) or _failed.has(key)


## Whether sound [param key] can be heard now: read into frames, or known not to be makeable.
func heard(key: String) -> bool:
	return _clips.has(key) or _failed.has(key)


## Sound [param key] asked to be made, though nothing makes it on its own ([member auto] off); [param again] forgets that it failed.
func ask(key: String, again := false) -> void:
	_asked[key] = true
	if again:
		_failed.erase(key)


## Every sound handed that is missing, asked to be made.
func ask_missing() -> void:
	for k in _specs:
		if not ready_for(k):
			ask(k, true)


## Where sound [param key] stands, as a Pipeline row says it ([constant PipelineRow.STATES]): made, running, queued, failed or missing.
func state_of(key: String) -> String:
	if _clips.has(key) or _made_files.has(key) or _on_disk.has(key) or (not reads and FileAccess.file_exists(wav_of(key))):
		return "made"
	if _failed.has(key):
		return "failed"
	if _making.has(key) or _inflight.has(key):
		return "running"
	if auto or _asked.has(key):
		return "queued"
	return "missing"


## Why sound [param key] could not be made, "" where nothing went wrong.
func why(key: String) -> String:
	return String(_failed.get(key, ""))


## Whether it is making anything.
func busy() -> bool:
	return not _making.is_empty() or (not auto and _asked.keys().any(func(k: String) -> bool: return not ready_for(k)))


## The acts [param acts] ([StudioScript]'s) made into motion and sound on the set [param geo]: `{made, keys, starts, specs}` - each
## act's motion ([method StudioActs.make], an act that goes on made [param horizons]`[i]` seconds long, else its own default), its
## sound's windows (their keys, and where each begins in the act, s) and every window as the host is handed it. Pure; a worker
## runs it.
static func make_all(acts: Array, geo: Dictionary, horizons := {}) -> Dictionary:
	var made: Array = []
	var keys: Array = []
	var starts: Array = []
	var specs := {}
	for a in acts:
		var i := int((a as Dictionary).get("i", made.size()))
		# (an act that goes on is made at least a window long: a shorter one would have no window to sound in)
		var m := StudioActs.make(a, geo, maxf(float(horizons.get(i, OPEN_LEAST)), WINDOW + OVERLAP + 0.5))
		var win := windows_of(m["sound"], bool(m.get("open", false)))
		var ks := PackedStringArray()
		var st := PackedFloat32Array()
		for w in win:
			var spec := spec_of(w["sound"])
			var k := key_of(spec)
			ks.append(k)
			st.append(float(w["at"]))
			specs[k] = spec
		made.append(m)
		keys.append(ks)
		starts.append(st)
	return {"made": made, "keys": keys, "starts": starts, "specs": specs}


## An act's sound ([method StudioActs.make]'s) as its windows: `[{at, sound}]`, `at` where the window begins in the act (s). One
## that fits a window is itself; a longer one is cut every [constant WINDOW] seconds, each window its stretch of the lanes from
## [constant PRE] before it, and the hits from then until it ends, laid [constant OVERLAP] over the next. An OPEN act's windows
## stop where its motion does (a window is made only once all of it is there); a timed act's last one keeps its tail.
static func windows_of(sound: Dictionary, open: bool) -> Array:
	var secs := float(sound["secs"])
	if not open and secs <= WINDOW + OVERLAP:
		return [{"at": 0.0, "sound": sound}]
	var lr := float(sound.get("lane_rate", Gesture.RATE))
	var out: Array = []
	var k := 0
	while true:
		var a := float(k) * WINDOW
		var last := not open and a + WINDOW + OVERLAP >= secs
		var b := secs if last else a + WINDOW + OVERLAP
		if open and b > secs - 0.05:
			break
		var pre := minf(PRE, a)
		var i0 := int(floor((a - pre) * lr))
		var i1 := int(ceil(b * lr)) + 2
		var w := {"secs": b - a, "tail": float(sound.get("tail", 0.0)) if last else 0.0, "skip": pre,
			"fade": [OVERLAP if k > 0 else 0.004, 0.03 if last else OVERLAP], "lane_rate": lr, "contacts": [], "hits": []}
		for c in sound.get("contacts", []):
			var cc := (c as Dictionary).duplicate()
			var lanes := {}
			for key in (c as Dictionary)["lanes"]:
				var src: PackedFloat32Array = (c as Dictionary)["lanes"][key]
				lanes[key] = src.slice(mini(i0, src.size() - 1), mini(i1, src.size()))
			cc["lanes"] = lanes
			(w["contacts"] as Array).append(cc)
		for h in sound.get("hits", []):
			var t := float((h as Dictionary)["t"])
			if t >= a - pre and t < b:
				var hh := (h as Dictionary).duplicate()
				hh["t"] = t - (a - pre)
				(w["hits"] as Array).append(hh)
		out.append({"at": a, "sound": w})
		if last:
			break
		k += 1
	return out


## How long an act that goes on is made before the medium knows more (s).
const OPEN_LEAST := 60.0


## Whether every sound asked for is ready.
func ready() -> bool:
	for k in _specs:
		if not ready_for(k):
			return false
	return true


# --- playing -----------------------------------------------------------------------------------------------------------

## The show at [param t]: the sound kept [constant LEAD] ahead of it in a player under [param host] (made the first time),
## begun again where the show jumped and held while the show stands still.
func tick(t: float, host: Node) -> void:
	if _player == null:
		var gen := AudioStreamGenerator.new()
		gen.mix_rate = RATE
		gen.buffer_length = BUFFER
		_player = AudioStreamPlayer.new()
		_player.name = "StudioSounds"
		_player.stream = gen
		host.add_child(_player)
	if still.still(t):
		_player.stream_paused = true
		return
	_player.stream_paused = false
	if not _player.playing or is_nan(_at) or t < _at - LEAD - RESET or t > _at + RESET:
		_player.stop()
		_player.play()
		_pb = _player.get_stream_playback()
		_at = t
	var n := mini(int((t + LEAD - _at) * float(RATE)), _pb.get_frames_available())
	if n > 0:
		_pb.push_buffer(render(_at, n))
		_at += float(n) / float(RATE)


## [param n] samples from show time [param t0]: every placed sound sounding then, and the room under it, faded with the outro. Pure.
func render(t0: float, n: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(n)
	var s0 := int(round(t0 * RATE))
	if not _room.is_empty():
		var rn := _room.size()
		for i in n:
			out[i] = _room[posmod(s0 + i, rn)]
	for p in _placed:
		var clip: PackedVector2Array = _clips.get(String(p["key"]), PackedVector2Array())
		if clip.is_empty():
			continue
		var c0 := int(round(float(p["t0"]) * RATE))
		var a := maxi(s0, c0)
		var b := mini(s0 + n, c0 + clip.size())
		var end := float(p["end"])
		# where its act ends, the hand lifting: from there it dies away, and nothing of it is heard after
		var e0 := int(round(end * RATE)) if end < INF else 1 << 60
		var e1 := e0 + int(RELEASE * RATE)
		b = mini(b, e1)
		for s in range(a, b):
			if s < e0:
				out[s - s0] += clip[s - c0]
			else:
				var g := 1.0 - float(s - e0) / float(e1 - e0)
				out[s - s0] += clip[s - c0] * (g * g)
	# the outro: down with the picture, eased across the block
	var g0 := ShowOpening.fade_out(t0, fade_from, outro)
	var g1 := ShowOpening.fade_out(t0 + float(n) / float(RATE), fade_from, outro)
	if g0 < 1.0 or g1 < 1.0:
		for i in n:
			out[i] *= lerpf(g0, g1, float(i) / float(maxi(n, 1)))
	return out


## What the meters show at show time [param t]: each ear's level over the last [constant METER] seconds (dBFS).
func level_at(t: float) -> Vector2:
	var n := int(METER * RATE)
	var buf := render(t - METER, n)
	var l := 0.0
	var r := 0.0
	for v in buf:
		l += v.x * v.x
		r += v.y * v.y
	return Vector2(linear_to_db(sqrt(l / float(n)) + 1e-9), linear_to_db(sqrt(r / float(n)) + 1e-9))


## Let go: the player stopped and taken off its host, every job left to finish on its own.
func stop() -> void:
	if _player != null and is_instance_valid(_player):
		_player.stop()
		_player.queue_free()
	_player = null
	for k in _reading:
		WorkerThreadPool.wait_for_task_completion(int((_reading[k] as Dictionary)["task"]))
	_reading = {}
	# a sound still being made goes on in its own process; another may wait for it no longer
	for k in _making:
		_inflight.erase(k)
	if _room_task >= 0:
		WorkerThreadPool.wait_for_task_completion(_room_task)
		_room_task = -1


## The room's tone: pink noise, darkened, quiet, a loop whose seam is eased into its start. Pure; a worker makes it.
static func room_tone() -> PackedVector2Array:
	var n := int(ROOM_LOOP * RATE)
	var seam := int(ROOM_SEAM * RATE)
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261126
	var raw := PackedVector2Array()
	raw.resize(n + seam)
	var st := [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
	var lp := Vector2.ZERO
	var sum := 0.0
	for i in n + seam:
		var w := Vector2(rng.randfn(), rng.randfn())
		# Paul Kellet's economy pink, each ear its own
		st[0] = 0.99765 * st[0] + w.x * 0.0990460
		st[1] = 0.96300 * st[1] + w.x * 0.2965164
		st[2] = 0.57000 * st[2] + w.x * 1.0526913
		st[3] = 0.99765 * st[3] + w.y * 0.0990460
		st[4] = 0.96300 * st[4] + w.y * 0.2965164
		st[5] = 0.57000 * st[5] + w.y * 1.0526913
		var p := Vector2(st[0] + st[1] + st[2] + w.x * 0.1848, st[3] + st[4] + st[5] + w.y * 0.1848)
		lp = lp.lerp(p, 0.18)
		raw[i] = lp
		sum += lp.x * lp.x
	var k := ROOM / sqrt(sum / float(n + seam))
	var out := PackedVector2Array()
	out.resize(n)
	for i in n:
		var v := raw[i]
		if i < seam:
			var f := float(i) / float(seam)
			v = raw[n + i] * sqrt(1.0 - f) + v * sqrt(f)
		out[i] = v * k
	return out
