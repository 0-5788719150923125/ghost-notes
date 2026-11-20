extends Node
class_name SongStream

## SongStream - a composed Sound heard as it is made (next/music.md), the reading's sliding window ([ReadingStream]) for a
## song: the music host (hosts/music/host.py, kept running) makes the song WINDOW seconds at a time, AHEAD seconds ahead
## of what is heard, each part read from its kept stem where it has one and made where it has none; the voice host sings
## the lines ahead in order, VOICE_AHEAD seconds of them, every take kept as a bake keeps it ([SongBake.take_of]). What
## comes back is decoded on a worker and pushed into the session's one stream.
##
## THE BAND WAITS FOR THE SINGER: a line not yet sung when it is nearly due is waited for where its bar begins - the bar
## before it played again without the voice, as a band vamps, until its take comes (at most VAMP_MOST bars a line; then,
## or with no voice to sing it, it goes without and its words leave the subtitles). What is heard is a list of segments
## (a window, or a vamp holding the song where it waits), so the rail and the subtitles hold while the band waits and the
## show's beat runs on. Stopped, the lines ahead of where it would start are sung once the voice host is up, and a take a
## bake sings is heard as soon as it lands.
##
## It conducts the transport ([method Spectrum.conduct]): Play, pause, Stop, the rail's position and length, and a seek -
## the stream begun again from there (nothing behind the playhead is kept to seek within). A score handed while it plays
## ([method update]: a roll, a part changed) is the song from where the stream has been made to: what is queued and not
## yet pushed is let go, and the new song is heard a few seconds after the press. It hands the show the song's own grid
## ([member Spectrum.known]) and re-bases the subtitles on what has been heard, every frame.
##
## The stream itself is the panel's to open and close ([member begin_stream], [member end_stream]: main's), as a
## reading's is, under the song's own seed ([method SongBake.seed_of]) - its export's. Nothing heavy runs here: a
## window's samples become frames on a worker.

## What it is doing, a line.
signal said(text: String)
## A line's take is there now (sung here or by a bake).
signal sung

const ENV := "music_venv"
const VENV := "user://music_venv"
const HOST := "res://hosts/music/host.py"
const RATE := 44100
## Seconds a window holds, and how far ahead of the ear the song is made.
const WINDOW := 6.0
const AHEAD := 14.0
## Seconds ahead the voice's lines are sung (a line's window waits for its take until it is nearly due).
const VOICE_AHEAD := 45.0
## A line not yet sung is waited for once what is made ahead of the ear is shorter than this (seconds): the band vamps.
const DUE := 4.0
## The most bars the band vamps waiting for one line, and the most seconds the stream's start waits silent for its first.
const VAMP_MOST := 8
const START_WAIT := 10.0
## Seconds made before the first sample is heard.
const PREROLL := 1.5
## Seconds of the old song still heard after a score changes, while the host makes the new one: the queue is cut there,
## not emptied, so a roll is no gap of silence.
const KEEP := 6.0

## (fp: int, sr: int, words: Array) -> Dictionary {playback, subtitles}: the session's stream opened and the show put up
## (main's). Invalid, nothing is heard.
var begin_stream: Callable
## () -> void: the stream closed and the show taken down (main's).
var end_stream: Callable

var _bake: SongBake = null      # whose voice host sings the lines
var _score := {}
var _grid := {}                  # the score's grid, handed the show every frame
var _folder := ""
var _epoch := 0                  # bumped by every load: what comes back for an older one is let go

var _pid := -1
var _stdio: FileAccess = null
var _stderr: FileAccess = null
var _rx := ""
var _erx := ""
var _host := "idle"              # idle | provisioning | starting | up | dead
var _next_id := 1
var _pending := {}               # id -> {op, epoch, t0, t1}
var _ready_load := -1            # the epoch whose load the host has answered

var _from := 0.0                 # the song second the stream began at
var _asked := 0.0                # song seconds asked for, from _from
var _asking := 0                 # windows asked and not yet landed
var _inflight := 0.0             # seconds of them
var _seq := 0                    # each window's place in what is heard
var _landing: Array = []         # windows being decoded: [{task, box, epoch, meta}]
var _queue: Array = []           # windows landed, in order: [{seq, t0, t1, hold, frames, started}]
var _segments: Array = []        # what is pushed, in order: [{at (frame), t0, hold (the song second a vamp holds, else -1)}]
var _vamps := {}                 # phrase index -> bars vamped waiting for it
var _missed := {}                # phrases gone without their take (their words off the subtitles)
var _began_ms := 0
var _pushed := 0                 # frames pushed since the stream began
var _ring := 0
var _playback: AudioStreamGeneratorPlayback = null
var _subtitles: Node = null
var _open := false               # the stream is open (begun and not ended)
var _want_play := false          # Play is pressed
var _prerolling := false         # held silent until PREROLL of it is pushed
## Windows of the song now (the last score loaded) come back from the host.
var landed := 0

var _takes := {}                 # phrase index -> {wav, at}
var _singing := ""               # the take being sung (its path), "" for none
var _failed := {}                # takes the voice host could not sing: not waited for, not asked again
var _sing_id := -1


## [param score] ([method Composer.score]) to stream from [param folder] (the Sound's own, where its takes and stems are
## kept), its voice sung by [param bake]'s host.
func setup(score: Dictionary, folder: String, bake: SongBake) -> void:
	_score = score
	_grid = SongBake.grid_of(score)
	_folder = ProjectSettings.globalize_path(folder)
	_bake = bake
	_bake.take_sung.connect(_on_take)
	DirAccess.make_dir_recursive_absolute(_folder.path_join("stream"))
	DirAccess.make_dir_recursive_absolute(_folder.path_join("takes"))
	_read_takes()
	conduct()


func _ready() -> void:
	set_process(true)


func _exit_tree() -> void:
	Spectrum.release_conductor(self)
	close()
	if _pid > 0:
		if _host == "up":
			_send({"op": "shutdown"})
		Subprocess.stop(_pid)
	_pid = -1


## This stream as what the transport drives.
func conduct() -> void:
	Spectrum.conduct(self, {
		"play": play, "pause": pause, "stop": stop_song,
		"playing": func() -> bool: return _want_play and _open and not Spectrum.paused,
		"can_play": func() -> bool: return not _score.is_empty(),
		"can_stop": func() -> bool: return _open,
		"position": position, "length": func() -> float: return float(_score.get("length", 0.0)),
		"seek": seek,
	})


## The song second being heard now: where a vamp waits, the second it holds.
func position() -> float:
	var seg := _segment()
	if seg.is_empty():
		return _from
	if float(seg["hold"]) >= 0.0:
		return float(seg["hold"])
	return float(seg["t0"]) + float(_heard() - int(seg["at"])) / RATE


## The song second of what is playing now - a vamp's own bar while it waits (the show's beat runs on it).
func _rendered() -> float:
	var seg := _segment()
	return _from if seg.is_empty() else float(seg["t0"]) + float(_heard() - int(seg["at"])) / RATE


## Frames heard since the stream began.
func _heard() -> int:
	if _playback == null:
		return 0
	return maxi(0, _pushed - maxi(0, _ring - int(_playback.get_frames_available())))


## The segment being heard ({} before the first).
func _segment() -> Dictionary:
	if not _open or _segments.is_empty():
		return {}
	var heard := _heard()
	var seg: Dictionary = _segments[0]
	for s in _segments:
		if int(s["at"]) > heard:
			break
		seg = s
	return seg


## The song second where what is pushed ends (where a vamp waits, the second it holds).
func _pushed_to() -> float:
	if _segments.is_empty():
		return _from
	var last: Dictionary = _segments[_segments.size() - 1]
	return float(last["hold"]) if float(last["hold"]) >= 0.0 else float(last["t0"]) + float(_pushed - int(last["at"])) / RATE


## Seconds made ahead of the ear: pushed and not heard, landed, and asked.
func _ahead() -> float:
	var frames := _pushed - _heard()
	for q in _queue:
		frames += (q["frames"] as PackedVector2Array).size()
	return float(frames) / RATE + _inflight


func play() -> void:
	_want_play = true
	if not _open:
		_begin(_from)  # heard once PREROLL of it is made ([method _push])
		return
	Spectrum.set_stream_paused(false)


func pause() -> void:
	_prerolling = false
	Spectrum.set_stream_paused(true)


## Stop: the stream ended, the song back at its start.
func stop_song() -> void:
	_want_play = false
	close()
	_from = 0.0


## The song heard from second [param t]: the stream begun again there, paused where it was paused.
func seek(t: float) -> void:
	var was := _want_play and (not Spectrum.paused or _prerolling)
	_from = clampf(t, 0.0, maxf(float(_score.get("length", 0.0)) - 0.5, 0.0))
	if _open:
		close()
		_want_play = was
		_begin(_from)
		_prerolling = was


## A new score for the song while it plays (a roll, a part changed): the host loads it, what is queued past KEEP seconds
## ahead of the ear is let go, and the song is made again from there.
func update(score: Dictionary) -> void:
	_score = score
	_grid = SongBake.grid_of(score)
	_read_takes()
	_vamps.clear()
	_missed.clear()
	if not _open:
		return
	var end := _pushed_to()
	var ahead := float(_pushed - _heard()) / RATE
	var kept: Array = []
	for q in _queue:
		if ahead >= KEEP:
			break
		kept.append(q)
		ahead += float((q["frames"] as PackedVector2Array).size()) / RATE
		end = float(q["hold"]) if float(q["hold"]) >= 0.0 else float(q["t1"])
	_queue = kept
	_epoch += 1
	_asking = 0
	_inflight = 0.0
	_asked = end - _from
	_load()
	_show_words()


## The stream ended: what is queued let go, the show taken down.
func close() -> void:
	if _open and end_stream.is_valid():
		end_stream.call()
	_open = false
	_playback = null
	_subtitles = null
	_queue.clear()
	_segments.clear()
	_asking = 0
	_inflight = 0.0
	_asked = 0.0
	_epoch += 1
	Spectrum.known = {}


func _begin(from: float) -> void:
	_from = from
	_asked = 0.0
	_asking = 0
	_inflight = 0.0
	_pushed = 0
	_queue.clear()
	_segments.clear()
	_vamps.clear()
	_missed.clear()
	_began_ms = Time.get_ticks_msec()
	_epoch += 1
	if not begin_stream.is_valid():
		return
	Spectrum.lead_in = 0.0
	Spectrum.tail = 0.0
	var got: Dictionary = begin_stream.call(SongBake.seed_of(_score), RATE, SongBake.words_of(_score))
	_playback = got.get("playback") as AudioStreamGeneratorPlayback
	_subtitles = got.get("subtitles")
	if _playback == null:
		return
	_ring = int(_playback.get_frames_available())
	_open = true
	conduct()
	# held until PREROLL of it is made: a stream that starts empty is heard starting late
	Spectrum.set_stream_paused(true)
	_prerolling = _want_play
	_load()


# --- the host -----------------------------------------------------------------------------------------

func _load() -> void:
	if _host != "up":
		_start_host()
		return
	var spec := Composer.render_spec(_score, _known_takes(), _folder, "mix.wav", true)
	var id := _send({"op": "load", "spec": spec})
	_pending[id] = {"op": "load", "epoch": _epoch}


## The music host started, once its environment is installed (asked again each frame until it is).
func _start_host() -> void:
	if _host in ["starting", "up"]:
		return
	if not Provision.unsupported(ENV).is_empty():
		_host = "dead"
		said.emit("⚠  the music environment cannot be installed here: " + Provision.unsupported(ENV))
		return
	if not Provision.ensure(ENV):
		if _host != "provisioning":
			said.emit("installing the music environment (%s)" % String(Deps.entry(ENV).get("size", "")))
		_host = "provisioning"
		return
	var py := Deps.venv_bin(VENV, "python")
	var script := BundledHosts.path(HOST)
	if not FileAccess.file_exists(py) or script.is_empty():
		_host = "dead"
		said.emit("⚠  the music environment is not installed")
		return
	var info := Subprocess.start_with_pipe(py, ["-u", script], "music host")
	if info.is_empty():
		_host = "dead"
		said.emit("⚠  the music host could not start")
		return
	_pid = int(info.get("pid", -1))
	_stdio = info.get("stdio")
	_stderr = info.get("stderr")
	_host = "starting"


func _send(msg: Dictionary) -> int:
	var id := _next_id
	_next_id += 1
	msg["id"] = id
	if _stdio != null:
		_stdio.store_string(JSON.stringify(msg) + "\n")
		_stdio.flush()
	return id


func _drain() -> void:
	if _stdio != null and _stdio.get_length() > _stdio.get_position():
		_rx += _stdio.get_as_text()
	while true:
		var nl := _rx.find("\n")
		if nl < 0:
			break
		var line := _rx.substr(0, nl).strip_edges()
		_rx = _rx.substr(nl + 1)
		if not line.is_empty():
			_handle(line)
	if _stderr != null and _stderr.get_length() > _stderr.get_position():
		_erx += _stderr.get_as_text()
		while true:
			var nl := _erx.find("\n")
			if nl < 0:
				break
			var line := _erx.substr(0, nl)
			_erx = _erx.substr(nl + 1)
			if not line.strip_edges().is_empty():
				print("ghost/music: " + line)


func _handle(line: String) -> void:
	var msg: Variant = JSON.parse_string(line)
	if not (msg is Dictionary):
		return
	var m: Dictionary = msg
	if String(m.get("event", "")) == "ready":
		_host = "up"
		if _open:
			_load()
		return
	var meta: Dictionary = _pending.get(int(m.get("id", -1)), {})
	_pending.erase(int(m.get("id", -1)))
	if meta.is_empty():
		return
	if not bool(m.get("ok", false)):
		said.emit("⚠  the music host: %s" % String(m.get("error", "")))
		if String(meta["op"]) == "window" and int(meta["epoch"]) == _epoch:
			_asking = maxi(_asking - 1, 0)
			_inflight = maxf(0.0, _inflight - (float(meta["t1"]) - float(meta["t0"])))
		return
	match String(meta["op"]):
		"load":
			if int(meta["epoch"]) == _epoch:
				_ready_load = _epoch
				landed = 0
				said.emit("")
		"window":
			if int(meta["epoch"]) != _epoch:
				return
			var path := String(m["wav"])
			var box := {}
			var task := WorkerThreadPool.add_task(func() -> void: box["frames"] = _frames_of(path), true)  # heard as it is made
			_landing.append({"task": task, "box": box, "epoch": _epoch, "meta": meta})


## A window's samples as frames: the host's raw float32, left and right interleaved.
static func _frames_of(path: String) -> PackedVector2Array:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return PackedVector2Array()
	var raw := f.get_buffer(f.get_length()).to_float32_array()
	f.close()
	DirAccess.remove_absolute(path)
	var out := PackedVector2Array()
	out.resize(raw.size() / 2)
	for i in out.size():
		out[i] = Vector2(raw[2 * i], raw[2 * i + 1])
	return out


# --- the window -----------------------------------------------------------------------------------------

func _process(_delta: float) -> void:
	_drain()
	if _host == "provisioning":
		_start_host()
	if _pid > 0 and _host in ["starting", "up"] and not Subprocess.alive(_pid) and not Subprocess.closing():
		_host = "dead"
		said.emit("⚠  the music host stopped - see the ghost/music lines in the log")
	_landed()
	_sing()
	if not _open or _playback == null:
		return
	_ask()
	_push()
	var heard := position()
	Spectrum.known = _grid
	Spectrum.known_origin = Spectrum.current.time - _rendered()
	if _subtitles != null and is_instance_valid(_subtitles):
		_subtitles.set("time_base", Spectrum.current.time - heard)
	if heard >= float(_score.get("length", 0.0)) - 0.05 and _queue.is_empty() and _asked + _from >= float(_score.get("length", 0.0)):
		stop_song()


## Windows asked of the host while what is made ahead of the ear is short of AHEAD, each ending on a bar. A line not
## yet sung is waited for where its bar begins: the windows go up to there, and once what is made ahead is short of DUE
## the bar before it is played again without the voice until its take comes (VAMP_MOST bars at most; the stream's start,
## not on a bar, waits silent up to START_WAIT); past that, or with no voice to sing it, it goes without.
func _ask() -> void:
	if _ready_load != _epoch or _host != "up":
		return
	var length := float(_score.get("length", 0.0))
	while _from + _asked < length - 0.001 and _ahead() < AHEAD and _asking < 2:
		var made_to := _from + _asked
		var t1 := minf(_bar_at(made_to + WINDOW, true), length)
		var wait := _unready(made_to, t1)
		if not wait.is_empty():
			var i := int(wait["i"])
			var at := maxf(_bar_at(float(wait["at"]), false), made_to)
			if float(wait["at"]) < made_to - 0.05:
				_miss(i)  # begun before what is made: it cannot be sung from its start
				continue
			if at > made_to + 0.01:
				t1 = at
			elif _ahead() >= DUE:
				return
			elif not _on_bar(made_to):
				if _pushed == 0 and _queue.is_empty() and _inflight <= 0.0 and _voice_alive() \
						and Time.get_ticks_msec() - _began_ms < int(START_WAIT * 1000.0):
					return
				_miss(i)
				continue
			elif int(_vamps.get(i, 0)) < VAMP_MOST and _voice_alive():
				_vamps[i] = int(_vamps.get(i, 0)) + 1
				var v0 := maxf(made_to - _bar_len(), float(_score.get("start", 0.0)))
				_window(v0, v0 + _bar_len(), made_to)
				continue
			else:
				_miss(i)
				continue
		_window(made_to, t1, -1.0)
		_asked = t1 - _from


## A window of the song asked of the host: [param t0]..[param t1], or, where [param hold] is a song second, a vamp - that
## stretch again without the voice, faded in from what was made last, holding the song at [param hold].
func _window(t0: float, t1: float, hold: float) -> void:
	_seq += 1
	var msg := {"op": "window", "t0": t0, "t1": t1,
		"out": _folder.path_join("stream").path_join("w%d_%d.f32" % [_epoch, _seq])}
	if hold >= 0.0:
		msg["voice"] = false
		msg["follows"] = true
	var id := _send(msg)
	_pending[id] = {"op": "window", "epoch": _epoch, "t0": t0, "t1": t1, "seq": _seq, "hold": hold}
	_asking += 1
	_inflight += t1 - t0


func _bar_len() -> float:
	return float(_score.get("beat", 0.5)) * int(_score.get("meter", Composer.METER))


## The bar line at or after (or before) song second [param t].
func _bar_at(t: float, after: bool) -> float:
	var start := float(_score.get("start", 0.0))
	var k := (t - start) / _bar_len()
	return start + (ceilf(k - 1e-4) if after else floorf(k + 1e-4)) * _bar_len()


func _on_bar(t: float) -> bool:
	var k := (t - float(_score.get("start", 0.0))) / _bar_len()
	return absf(k - roundf(k)) < 1e-3


func _landed() -> void:
	var still: Array = []
	for l in _landing:
		if not WorkerThreadPool.is_task_completed(int(l["task"])):
			still.append(l)
			continue
		WorkerThreadPool.wait_for_task_completion(int(l["task"]))
		if int(l["epoch"]) != _epoch:
			continue
		var meta: Dictionary = l["meta"]
		_asking = maxi(_asking - 1, 0)
		_inflight = maxf(0.0, _inflight - (float(meta["t1"]) - float(meta["t0"])))
		landed += 1
		_queue.append({"seq": int(meta["seq"]), "t0": float(meta["t0"]), "t1": float(meta["t1"]), "hold": float(meta["hold"]),
			"frames": (l["box"] as Dictionary).get("frames", PackedVector2Array()), "started": false})
	_landing = still
	_queue.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["seq"]) < int(b["seq"]))


func _push() -> void:
	if _playback == null:
		return
	while _segments.size() > 1 and int(_segments[1]["at"]) <= _heard():
		_segments.pop_front()
	while not _queue.is_empty():
		var head: Dictionary = _queue[0]
		var frames: PackedVector2Array = head["frames"]
		var room := int(_playback.get_frames_available())
		if room <= 0:
			return
		if not bool(head["started"]):
			head["started"] = true
			_segments.append({"at": _pushed, "t0": float(head["t0"]), "hold": float(head["hold"])})
		if frames.size() <= room:
			_playback.push_buffer(frames)
			_pushed += frames.size()
			_queue.pop_front()
		else:
			_playback.push_buffer(frames.slice(0, room))
			_pushed += room
			head["frames"] = frames.slice(room)
			break
	if _prerolling and _pushed >= int(PREROLL * RATE):
		_prerolling = false
		Spectrum.set_stream_paused(false)


# --- the voice ------------------------------------------------------------------------------------------

func _phrases() -> Array:
	var v: Dictionary = _score.get("vocal", {})
	return v.get("phrases", []) if not bool(v.get("mute", false)) else []


## Every line's kept take, read from the takes folder (a bake's and this stream's are one set).
func _read_takes() -> void:
	_takes.clear()
	var v: Dictionary = _score.get("vocal", {})
	var phrases := _phrases()
	for i in phrases.size():
		var wav := SongBake.take_of(_folder, v, phrases[i])
		var meta := wav.get_basename() + ".json"
		if FileAccess.file_exists(wav) and FileAccess.file_exists(meta):
			var got: Variant = JSON.parse_string(FileAccess.get_file_as_string(meta))
			if got is Dictionary:
				_takes[i] = {"wav": wav, "at": float(phrases[i]["at"]) + float((got as Dictionary).get("start", 0.0))}


## The takes folder changed under it (a bake sang lines): what is kept there is read again and the host told.
func takes_changed() -> void:
	_read_takes()
	if _host == "up":
		_send({"op": "takes", "takes": _known_takes()})


func _known_takes() -> Array:
	var out: Array = []
	for i in _takes:
		out.append(_takes[i])
	return out


## The first line sung in [param t0]..[param t1] with no take yet, `{i, at}`, {} for none (a line that could not be
## sung, or has gone without, is waited for no more).
func _unready(t0: float, t1: float) -> Dictionary:
	var phrases := _phrases()
	var v: Dictionary = _score.get("vocal", {})
	for i in phrases.size():
		var p: Dictionary = phrases[i]
		var at := float(p["at"])
		if at >= t1 + 0.5 or at + _phrase_length(p) <= t0 or _takes.has(i) or _missed.has(i):
			continue
		if _failed.has(SongBake.take_of(_folder, v, p)):
			continue
		return {"i": i, "at": at}
	return {}


## Line [param i] goes without its take: its words leave the subtitles.
func _miss(i: int) -> void:
	_missed[i] = true
	_show_words()


## The subtitles' words: every line that is sung or still to be.
func _show_words() -> void:
	if _subtitles == null or not is_instance_valid(_subtitles):
		return
	var words: Array = SongBake.words_of(_score)
	if not _missed.is_empty():
		words = words.filter(func(w: Dictionary) -> bool: return not _missed.has(int(w["sentence"])))
	_subtitles.set("words", words)


func _voice_alive() -> bool:
	return _bake != null and _bake.voice_alive()


static func _phrase_length(p: Dictionary) -> float:
	var end := 0.0
	for w in p["words"]:
		for n in w["notes"]:
			end = maxf(end, float(n["t"]) + float(n["len"]))
	return end


## The next line within VOICE_AHEAD of the ear sung, one at a time, nearest first.
func _sing() -> void:
	if not _singing.is_empty() or _bake == null or _bake.busy():
		return
	# stopped, it sings ahead of where it would start only once the voice host is up (never started just for that)
	if not _open and not _bake.voice_up():
		return
	var phrases := _phrases()
	var now := position()
	for i in phrases.size():
		var p: Dictionary = phrases[i]
		var at := float(p["at"])
		# a line whose stretch is made already is not heard: the window went without it
		if _takes.has(i) or at + _phrase_length(p) < maxf(now, _from + _asked) or at > now + VOICE_AHEAD:
			continue
		if _missed.has(i) or _failed.has(SongBake.take_of(_folder, _score["vocal"], p)):
			continue
		var host := _bake.voice()
		if not _bake.voice_up():
			return
		if not host.synthesized.is_connected(_on_sung):
			host.synthesized.connect(_on_sung)
			host.failed.connect(_on_failed)
		var v: Dictionary = _score["vocal"]
		var singer := SongBake.singer_of(v.get("singer", {}))
		var params := {"speaker": int(singer.get("speaker", 0))}
		if not String(singer.get("blend", "")).is_empty():
			params["blend"] = String(singer["blend"])
		_singing = SongBake.take_of(_folder, v, p)
		_sing_id = host.sing(p["words"], String(singer.get("voice", "kokoro")), _singing, params, v.get("style", {}))
		return


func _on_failed(stage: String, why: String) -> void:
	if stage != "sing" or _singing.is_empty():
		return
	_failed[_singing] = true
	_singing = ""
	_sing_id = -1
	said.emit("⚠  a line could not be sung: %s" % why)


## A take a bake sang ([signal SongBake.take_sung]): every line of the score now that it serves.
func _on_take(wav: String, start: float) -> void:
	_serve(wav, start)


## Every line of the score now whose take is [param wav] given it, and the host told.
func _serve(wav: String, start: float) -> void:
	var phrases := _phrases()
	var v: Dictionary = _score.get("vocal", {})
	for i in phrases.size():
		if SongBake.take_of(_folder, v, phrases[i]) == wav:
			_takes[i] = {"wav": wav, "at": float(phrases[i]["at"]) + start}
	if _host == "up":
		_send({"op": "takes", "takes": _known_takes()})
	sung.emit()


## A take sung: its timing kept beside it, and every line of the score now that it serves (a line sung
## again is one take; a score changed while it was sung may have none).
func _on_sung(id: int, msg: Dictionary) -> void:
	if id != _sing_id or _singing.is_empty():
		return
	var wav := _singing
	_singing = ""
	_sing_id = -1
	if not bool(msg.get("ok", true)) or not FileAccess.file_exists(wav):
		return
	var f := FileAccess.open(wav.get_basename() + ".json", FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({"start": float(msg.get("start", 0.0)), "duration": float(msg.get("duration", 0.0))}))
		f.close()
	_serve(wav, float(msg.get("start", 0.0)))
