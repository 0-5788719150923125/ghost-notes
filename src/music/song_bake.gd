extends Node
class_name SongBake

## SongBake - a composed Sound made into a file, and a song file read for its patterns, off the app's thread
## (next/music.md, "Rendering"). One job at a time, each ending on [signal done]:
##
## - [method bake]: each sung line of the score - every voice's ([method lines_of]) - sung by the
##   voice host ([method VoiceHost.sing]) in its singer (a kept voice read by name: its reader, blend and Tone, [method
##   singer_of]), kept in `<folder>/takes/` under a hash of what made it (the singer, the style, the words and their
##   notes), so a line not changed is never sung again (a take no line names any more is removed); then the score
##   rendered by the music host (hosts/music/render.py, which keeps each part's stem under a hash of its own) into
##   `<folder>/mix.wav`.
## - [method analyze]: hosts/music/analyze.py reads a song into `<folder>/reference.json` - its grid, key, chords,
##   form, drums and melody; never its sound.
##
## The hosts run as child programs (Subprocess, polled a frame at a time); the voice host is this node's own child,
## started the first time a phrase is sung. What it is doing is said on [signal said], a line at a time.

## What the job is doing, a line for a card's status.
signal said(text: String)
## A job ended: [param job] "bake", "analyze" or "save", [param path] the mix, the reference or the file saved,
## [param why] when it failed.
signal done(job: String, ok: bool, path: String, why: String)
## A mix being saved as another format ([method save_as]) is [param fraction] of the way (0-1).
signal saving(fraction: float)
## A line sung for a bake: its take and where its voice starts in it (a stream hears it at once).
signal take_sung(wav: String, start: float)

const ENV := "music_venv"
const VENV := "user://music_venv"
const RENDER := "res://hosts/music/render.py"
const ANALYZE := "res://hosts/music/analyze.py"
const MIX := "mix.wav"
const REFERENCE := "reference.json"
## What the mix was made from (`{hash, at}`), beside it: never named after the mix, whose own name with `.json` is its
## subtitles' (the words sung and when, [method Subtitles.sidecar_for]).
const MADE := "made.json"
## Raised when a phrase kept would be sung differently from the same notes: every kept take is sung again.
const TAKES := 3
## Seconds between looks at a running host's log for a line to say.
const LOOK := 0.5

var _job := ""              # "", "sing", "render", "analyze"
var _score := {}
var _folder := ""           # absolute
var _lines: Array = []      # every line sung ([method lines_of])
var _queue: Array = []      # lines still to sing: [{l, out, meta}]
var _takes: Array = []      # each line's take {wav, at, voice}, or null until sung
var _asking := -1           # the request being sung
var _asking_i := -1         # ...the line it is
var _host: VoiceHost = null
var _host_up := false
var _host_dead := false          # the voice host could not start or stopped
var _pid := -1
var _run := {}              # the host program running: {job, out, log, path}
var _env_wait := ""         # the job waiting for the music environment ("render" / "analyze"), and its spec
var _spec := {}
var _look := 0.0
var _said := ""
var _listing := -1        # the voices asked of the host, for the singers ([method list_singers])
var _listed := Callable()
var _save := {}           # a mix being saved as another format: {pid, dest, log, progress, seconds}


func _ready() -> void:
	set_process(false)


func _exit_tree() -> void:
	stop()


## Whether a job is under way.
func busy() -> bool:
	return not _job.is_empty()


## The job under way: "analyze" (a song read), "sing" (lines sung), "render" (the parts made and mixed), or "".
func job() -> String:
	return _job


## The job under way stopped: its host program ended, nothing written further.
func stop() -> void:
	if _pid > 0:
		Subprocess.stop(_pid)
	_pid = -1
	if _host != null and _asking >= 0:
		_host.cancel([_asking])
	_asking = -1
	_queue.clear()
	_job = ""
	_env_wait = ""
	set_process(false)


## [param score] ([method Composer.score]) made into `<folder>/mix.wav`: its phrases sung (those not kept), then
## rendered. Ends on [signal done] `bake`.
func bake(score: Dictionary, folder: String) -> void:
	stop()
	_score = score
	_folder = ProjectSettings.globalize_path(folder)
	DirAccess.make_dir_recursive_absolute(_folder.path_join("takes"))
	_takes.clear()
	_queue.clear()
	_lines = lines_of(score)
	for l in _lines.size():
		var line: Dictionary = _lines[l]
		var p: Dictionary = line["phrase"]
		var out := take_of(_folder, line["voice"], p)
		var meta := out.get_basename() + ".json"
		var kept: Variant = JSON.parse_string(FileAccess.get_file_as_string(meta)) if FileAccess.file_exists(meta) else null
		if FileAccess.file_exists(out) and kept is Dictionary:
			_takes.append({"wav": out, "at": float(p["at"]) + float((kept as Dictionary).get("start", 0.0)), "voice": line["key"]})
		else:
			_takes.append(null)
			_queue.append({"l": l, "out": out, "meta": meta})
	_job = "sing"
	set_process(true)
	if _queue.is_empty():
		_render()
		return
	_say("singing %d of %d lines" % [_queue.size(), _lines.size()])
	_voice_host()
	if _host_up:
		_sing_next()


## Kokoro's readers listed by the voice host (started if it is not) into [VoiceReaders], then [param then] called: who
## may sing.
func list_singers(then: Callable) -> void:
	_listed = then
	_voice_host()
	if _host_up and _listing < 0:
		_listing = _host.list_voices()


## The mix at [param src] saved at [param dest] as its extension says: WAV copied, FLAC, MP3 and OGG encoded by FFmpeg on
## its own, how far along on [signal saving] (FFmpeg's own progress, against the mix's length). Ends on [signal done]
## `save`. Returns "" once started, else why it could not be.
func save_as(src: String, dest: String) -> String:
	var ext := dest.get_extension().to_lower()
	if ext == "wav" or ext.is_empty():
		var to := dest if not ext.is_empty() else dest + ".wav"
		var ok := DirAccess.copy_absolute(src, to) == OK
		done.emit("save", ok, to, "" if ok else "could not write " + to)
		return ""
	var ff := Provision.tool_path("ffmpeg", "ffmpeg")
	if ff.is_empty():
		Provision.ensure("ffmpeg")
		return "FFmpeg is being installed, to write %s: export again in a moment." % ext.to_upper()
	var codec := {"flac": ["-c:a", "flac"], "mp3": ["-c:a", "libmp3lame", "-q:a", "2"], "ogg": ["-c:a", "libvorbis", "-q:a", "6"]}
	var base := ProjectSettings.globalize_path(src).get_base_dir()
	var progress := base.path_join("save_progress.txt")
	DirAccess.remove_absolute(progress)
	var args := PackedStringArray(["-y", "-v", "error", "-progress", progress, "-nostats", "-i", src])
	args.append_array(PackedStringArray(codec.get(ext, [])))
	args.append(dest)
	var log := base.path_join("save.log")
	var pid := Subprocess.start_logged(ff, args, log, "music save")
	if pid <= 0:
		return "FFmpeg could not start"
	# the mix's length from its size: 16-bit stereo at 44.1 kHz after a 44-byte header (render.py writes it so)
	var f := FileAccess.open(src, FileAccess.READ)
	var seconds := float(f.get_length() - 44) / (44100.0 * 4.0) if f != null else 0.0
	_save = {"pid": pid, "dest": dest, "log": log, "progress": progress, "seconds": seconds}
	set_process(true)
	return ""


## How far a save is, 0-1, from FFmpeg's progress file.
func _saved_fraction() -> float:
	var text := FileAccess.get_file_as_string(String(_save["progress"]))
	var best := 0.0
	for line in text.split("\n"):
		if line.begins_with("out_time_us=") or line.begins_with("out_time_ms="):
			best = maxf(best, line.substr(12).to_float() / 1_000_000.0)
	return clampf(best / maxf(float(_save["seconds"]), 0.01), 0.0, 1.0)


## The voice host, this node's own, started the first time it is wanted: what a stream ([SongStream]) sings its lines
## through too, one line at a time, as a bake does.
func voice() -> VoiceHost:
	_voice_host()
	return _host


## Whether the voice host is up to sing.
func voice_up() -> bool:
	return _host_up


## Whether the voice host can still sing: up, starting, or not yet asked - not failed.
func voice_alive() -> bool:
	return not _host_dead


## The voice host, this node's own child, started the first time it is wanted.
func _voice_host() -> void:
	if _host == null:
		_host = VoiceHost.new()
		add_child(_host)
		_host.host_ready.connect(func(_b: PackedStringArray) -> void:
			_host_up = true
			if _listed.is_valid() and _listing < 0:
				_listing = _host.list_voices()
			_sing_next())
		_host.synthesized.connect(_on_sung)
		_host.failed.connect(_on_host_failed)
		_host.progress.connect(func(_stage: String, msg: String) -> void: _say(msg))
	if not _host_up:
		_host.start()



## A song file read for its patterns into `<folder>/reference.json`; [param lines] the lyrics' lines (`{text}` each) so
## the reference says where each is sung. Ends on [signal done] `analyze`.
func analyze(song: String, lines: Array, folder: String) -> void:
	stop()
	_folder = ProjectSettings.globalize_path(folder)
	DirAccess.make_dir_recursive_absolute(_folder)
	_job = "analyze"
	_spec = {"song": ProjectSettings.globalize_path(song), "out": _folder, "lines": lines}
	set_process(true)
	_start_host("analyze")


func _process(delta: float) -> void:
	if not _save.is_empty():
		if Subprocess.alive(int(_save["pid"])):
			saving.emit(_saved_fraction())
		else:
			var dest := String(_save["dest"])
			var ok := FileAccess.file_exists(dest)
			var why := "" if ok else FileAccess.get_file_as_string(String(_save["log"])).strip_edges().right(200)
			_save = {}
			set_process(not _job.is_empty())
			done.emit("save", ok, dest, why)
	if not _env_wait.is_empty():
		_start_host(_env_wait)
		return
	if _pid <= 0:
		return
	_look += delta
	if _look >= LOOK:
		_look = 0.0
		var tail := FileAccess.get_file_as_string(String(_run["log"])).strip_edges()
		var last := tail.substr(tail.rfind("\n") + 1) if not tail.is_empty() else ""
		if not last.is_empty() and not last.begins_with("Traceback") and not last.begins_with(" "):
			_say(last)
	if Subprocess.alive(_pid):
		return
	_pid = -1
	_land()


func _sing_next() -> void:
	if _job != "sing" or _asking >= 0:
		return
	if _queue.is_empty():
		_render()
		return
	var q: Dictionary = _queue[0]
	_asking_i = int(q["l"])
	var line: Dictionary = _lines[_asking_i]
	var left := 0
	for t in _takes:
		if t == null:
			left += 1
	var who := String((line["voice"] as Dictionary).get("role", ""))
	_say("singing: \"%s\"%s (%d left)" % [String((line["phrase"] as Dictionary)["text"]), (" (%s)" % who) if not who.is_empty() else "", left])
	var singer := singer_of((line["voice"] as Dictionary).get("singer", {}))
	_asking = _host.sing((line["phrase"] as Dictionary)["words"], String(singer.get("voice", "kokoro")), String(q["out"]),
		params_of(singer), (line["voice"] as Dictionary).get("style", {}))


func _on_sung(id: int, msg: Dictionary) -> void:
	if id == _listing:
		_listing = -1
		for v in msg.get("voices", []):
			if v is Dictionary and String((v as Dictionary).get("backend", "")) == "kokoro" and (v as Dictionary).get("readers") is Array:
				VoiceReaders.offer(String(v["id"]), v["readers"], String(v.get("readers_about", "")))
		if _listed.is_valid():
			_listed.call()
		_listed = Callable()
		return
	if id != _asking or _job != "sing":
		return
	var q: Dictionary = _queue.pop_front()
	var f := FileAccess.open(String(q["meta"]), FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({"start": float(msg.get("start", 0.0)), "duration": float(msg.get("duration", 0.0))}))
		f.close()
	var line: Dictionary = _lines[int(q["l"])]
	_takes[int(q["l"])] = {"wav": String(q["out"]), "at": float((line["phrase"] as Dictionary)["at"]) + float(msg.get("start", 0.0)),
		"voice": line["key"]}
	_asking = -1
	take_sung.emit(String(q["out"]), float(msg.get("start", 0.0)))
	_sing_next()


func _on_host_failed(stage: String, why: String) -> void:
	if stage in ["deps", "host"]:
		_host_dead = true
		_host_up = false
	if _job != "sing" or not (stage in ["sing", "deps", "host"]):
		return
	var job := _job
	stop()
	done.emit("bake" if job == "sing" else job, false, "", "the voice could not sing: " + why)


func _render() -> void:
	# takes no line of this score names any more go: every change to a line leaves its last take behind otherwise
	var named := {}
	for t in _takes:
		if t != null:
			named[String((t as Dictionary)["wav"]).get_file().get_basename()] = true
	var dir := _folder.path_join("takes")
	for f in DirAccess.get_files_at(dir):
		if not named.has(f.get_basename()):
			DirAccess.remove_absolute(dir.path_join(f))
	_job = "render"
	var takes: Array = _takes.filter(func(t: Variant) -> bool: return t != null)
	_spec = Composer.render_spec(_score, takes, _folder, MIX)
	_start_host("render")


## The music host for [param job], once its environment is installed (asked again each frame until it is).
func _start_host(job: String) -> void:
	_env_wait = ""
	if not Provision.unsupported(ENV).is_empty():
		_fail(job, "the music environment cannot be installed here: " + Provision.unsupported(ENV))
		return
	if not Provision.ensure(ENV):
		_env_wait = job
		var st := Provision.state(ENV)
		_say("installing the music environment (%s)%s" % [String(Deps.entry(ENV).get("size", "")),
			(": " + String(st.get("phase", ""))) if not String(st.get("phase", "")).is_empty() else ""])
		return
	if job == "analyze":
		var ff := Provision.tool_path("ffmpeg", "ffmpeg")
		if ff.is_empty():
			if not Provision.ensure("ffmpeg"):
				_env_wait = job
				_say("installing FFmpeg, to read the song")
				return
			ff = Provision.tool_path("ffmpeg", "ffmpeg")
		_spec["ffmpeg"] = ff
	var py := Deps.venv_bin(VENV, "python")
	var host := BundledHosts.path(RENDER if job == "render" else ANALYZE)
	if not FileAccess.file_exists(py) or host.is_empty():
		_fail(job, "the music environment is not installed")
		return
	var spec_path := _folder.path_join(job + ".json")
	var f := FileAccess.open(spec_path, FileAccess.WRITE)
	if f == null:
		_fail(job, "could not write " + spec_path)
		return
	f.store_string(JSON.stringify(_spec))
	f.close()
	DirAccess.remove_absolute(_folder.path_join("done.json"))
	var log := _folder.path_join(job + ".log")
	_pid = Subprocess.start_logged(py, PackedStringArray(["-I", host, spec_path]), log, "music " + job)
	if _pid <= 0:
		_fail(job, "the music host could not start")
		return
	_run = {"job": job, "log": log}
	_say("rendering the parts" if job == "render" else "listening to the song")


func _land() -> void:
	var job := String(_run.get("job", ""))
	var done_path := _folder.path_join("done.json")
	var res: Variant = JSON.parse_string(FileAccess.get_file_as_string(done_path)) if FileAccess.file_exists(done_path) else null
	if not (res is Dictionary) or not bool((res as Dictionary).get("ok", false)):
		var why := String((res as Dictionary).get("error", "")) if res is Dictionary else ""
		if why.is_empty():
			why = FileAccess.get_file_as_string(String(_run["log"])).strip_edges().right(300)
		_fail(job, why)
		return
	_job = ""
	set_process(false)
	if job == "render":
		_say("made in %.1f s" % float((res as Dictionary).get("took", 0.0)))
		write_sidecar(_score, String((res as Dictionary)["mix"]))
		done.emit("bake", true, String((res as Dictionary)["mix"]), "")
	else:
		_say("read in %.1f s" % float((res as Dictionary).get("took", 0.0)))
		done.emit("analyze", true, String((res as Dictionary)["reference"]), "")


func _fail(job: String, why: String) -> void:
	_job = ""
	_env_wait = ""
	set_process(false)
	done.emit("bake" if job in ["render", "sing"] else job, false, "", why)


func _say(text: String) -> void:
	if text == _said:
		return
	_said = text
	said.emit(text)


## The sidecar beside a mix ([method Subtitles.sidecar_for]; read by [method Spectrum.begin]): the words sung, the song's
## own grid and its seed - what a file of the song tells the show it plays under, live or in an export.
static func write_sidecar(score: Dictionary, mix: String) -> void:
	var grid := grid_of(score)
	var f := FileAccess.open(mix.get_basename() + ".json", FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({"words": words_of(score), "seed": seed_of(score), "grid": {
			"beats": Array(grid["beats"]), "bar": grid["bar"], "beat": grid["beat"], "sections": Array(grid["sections"])}}))
		f.close()


## Every word sung in [param score], in the song's own seconds, each line a sentence: what the subtitles show - each
## section's leading voice's ([method Composer._mark_leads]), each word naming its `line` ([method lines_of]).
static func words_of(score: Dictionary) -> Array:
	var words: Array = []
	var lines: Array = lines_of(score).filter(func(l: Dictionary) -> bool: return bool((l["phrase"] as Dictionary).get("lead", false)))
	lines.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["phrase"]["at"]) < float(b["phrase"]["at"]))
	for k in lines.size():
		var p: Dictionary = lines[k]["phrase"]
		for w in p["words"]:
			var notes: Array = w["notes"]
			if notes.is_empty():
				continue
			var last: Dictionary = notes[notes.size() - 1]
			words.append({"text": String(w["text"]), "t0": float(p["at"]) + float(notes[0]["t"]),
				"t1": float(p["at"]) + float(last["t"]) + float(last["len"]), "sentence": k, "line": String(lines[k]["id"])})
	return words


## The song's own grid ([member Spectrum.known]): a beat a beat, the beats a bar, a section's start a section, in its own
## seconds.
static func grid_of(score: Dictionary) -> Dictionary:
	var beats := PackedFloat32Array()
	var beat := float(score.get("beat", 0.5))
	var start := float(score.get("start", 0.0))
	var meter := int(score.get("meter", Composer.METER))
	for k in int(score.get("bars", 0)) * meter:
		beats.append(start + k * beat)
	var secs := PackedFloat32Array()
	for sec in score.get("sections", []):
		secs.append(float(sec["start"]))
	return {"beats": beats, "bar": meter, "beat": beat, "sections": secs}


## The song's seed for the show: its score's, so the same song is the same show heard as it is made or from its file,
## and a song rolled is another. 52 bits, which a sidecar's JSON number holds exactly.
static func seed_of(score: Dictionary) -> int:
	return JSON.stringify(score).sha1_text().substr(0, 13).hex_to_int()


## Every line sung in [param score], voice by voice, a muted voice's left out - `[{id, voice, key, i, phrase}]` (`voice`
## the score's voice it is of, `key` that voice's part, `id` "key:i"); a line its section's lead has `lead` on its phrase.
static func lines_of(score: Dictionary) -> Array:
	var out: Array = []
	for v in score.get("voices", []):
		if not (v is Dictionary) or (v as Dictionary).is_empty() or bool((v as Dictionary).get("mute", false)):
			continue
		var key := String((v as Dictionary).get("key", "vocal"))
		var phrases: Array = (v as Dictionary).get("phrases", [])
		for i in phrases.size():
			out.append({"id": "%s:%d" % [key, i], "voice": v, "key": key, "i": i, "phrase": phrases[i]})
	return out


## What the voice host is asked to sing in [param singer] ([method singer_of]): its reader, its blend or a formant voice's
## own, its Tone's size.
static func params_of(singer: Dictionary) -> Dictionary:
	var params := {"speaker": int(singer.get("speaker", 0))}
	if not String(singer.get("blend", "")).is_empty():
		params["blend"] = String(singer["blend"])
	if singer.get("formant") is Dictionary:
		params["formant"] = (singer["formant"] as Dictionary).duplicate(true)
	if absf(float(singer.get("semis", 0.0))) > 0.001:
		params["semis"] = float(singer["semis"])
	return params


## Where the take of [param phrase] of [param vocal] (a score's voice) is kept in [param folder]'s takes,
## whether or not it is there yet: a hash of who sings, how, and the phrase's words and notes.
static func take_of(folder: String, vocal: Dictionary, phrase: Dictionary) -> String:
	var h := _take_hash(singer_of(vocal.get("singer", {})), vocal.get("style", {}), phrase["words"])
	return ProjectSettings.globalize_path(folder).path_join("takes").path_join(h + ".wav")


## Who sings: the score's singer, a voice kept in the library read by its name (`kept`: its reader, its blend or a formant
## voice's own, and its Tone's shift, `semis`, which the voice makes a change of size). A kept voice is read once a library
## version.
static func singer_of(singer: Variant) -> Dictionary:
	var s: Dictionary = singer if singer is Dictionary else {}
	if not String(s.get("kept", "")).is_empty():
		var v := _kept_voice(String(s["kept"]))
		if String(v.get("voice", "")) == FormantVoice.ID:
			var sung := {"voice": FormantVoice.ID, "formant": v.get("formant", {}) if v.get("formant") is Dictionary else {}}
			var size := Delivery.tone_semis(int(v.get("tone", 0)))
			if absf(size) > 0.001:
				sung["semis"] = size
			return sung
		if String(v.get("voice", "")).begins_with("kokoro"):
			var out := {"voice": String(v["voice"]), "speaker": int(v.get("speaker", 0)), "blend": String(v.get("blend", ""))}
			var semis := Delivery.tone_semis(int(v.get("tone", 0)))
			if absf(semis) > 0.001:
				out["semis"] = semis
			return out
	return {"voice": String(s.get("voice", Composer.SINGER["voice"])), "speaker": int(s.get("speaker", Composer.SINGER["speaker"])),
		"blend": String(s.get("blend", ""))}


static var _kept_read := {}     # name -> its kept voice, while the library is at _kept_version
static var _kept_version := -1


static func _kept_voice(name: String) -> Dictionary:
	if _kept_version != VoiceLibrary.version:
		_kept_read.clear()
		_kept_version = VoiceLibrary.version
	if not _kept_read.has(name):
		var e := VoiceLibrary.read(name)
		_kept_read[name] = e.get("voice", {}) if e.get("voice") is Dictionary else {}
	return _kept_read[name]


static func _take_hash(singer: Dictionary, style: Variant, words: Array) -> String:
	return JSON.stringify({"singer": singer, "style": style, "words": words, "v": TAKES}).sha1_text().substr(0, 16)


## The mix a bake leaves in [param folder].
static func mix_of(folder: String) -> String:
	return ProjectSettings.globalize_path(folder).path_join(MIX)


## The reference an analysis leaves in [param folder], {} where there is none.
static func reference_of(folder: String) -> Dictionary:
	var path := ProjectSettings.globalize_path(folder).path_join(REFERENCE)
	var got: Variant = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
	return got if got is Dictionary else {}
