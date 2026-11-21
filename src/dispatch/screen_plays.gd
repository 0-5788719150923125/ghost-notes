extends RefCounted
class_name ScreenPlays

## ScreenPlays - what a screen plays when a script says `play (terminal): WHAT` ([DispatchScript]), found by what it names: another
## NOTE by its title, played live inside the desk ([NestedShow]: its own scenes and song, nothing rendered ahead), or a VIDEO FILE by
## its path, decoded as it plays ([ScreenFilm]).
##
## A note plays as its own show is made: its song as it stands (the file it plays, or its composed mix - made again first, here, where
## the song has changed since it was made or it was never made: nobody opens that note to make it) - or silent, timed
## by its storyboard, where it has no sound (a cartoon, next/cartoon.md) - its words as its
## Look shows them (the credits where it names none), heard through that song's bake ([SpectrumBake], taken by the bake runner once, where it has none, as an export takes it), in its medium (one
## that plays scenes: Auto, Full frame, Comic), walking its storyboard where it keeps one. A video file has its size, rate and length
## probed and its sound taken out into a WAV, once, kept under `user://screen_films/`. Both are begun on their own the first time a
## script names them ([method record_of]), and what is being taken is kept here, so a note opened again finds it ([method pump]).

const Bake := preload("res://src/audio/bake.gd")
## Where a video file's sound and what it says of itself are kept.
const FILES := "user://screen_films"
const JSON_NAME := "film.json"
const SOUND := "sound.wav"
## The extensions read as a video file.
const EXTS := ["mp4", "mkv", "webm", "mov", "avi", "ogv", "m4v"]
## How often the notes' titles are read again while a title is not found (s).
const RESCAN := 5.0
## Raised when how a file is read changes: every file is read again.
const VERSION := 1

## What is being taken: `what` -> `{step, pid, ...}`. Static, so it outlives the card that asked.
static var _jobs := {}
static var _failed := {}
static var _titles := {}
static var _titles_at := -INF
static var _songs := {}        # a note's path -> {key, score, hash, current}: its composed song as it stands ([method _song_now])


## What [param what] names, as a screen plays it: `{what, kind ("note" or "file"), ready, secs, why}` and, ready, what plays it - a
## note's `{note, song, bake, medium, storyboard}`, a file's `{video, sound, size, fps}`. Not ready, what it waits for is begun (a
## note's bake, a file's reading), and `why` says what stands in the way.
static func record_of(what: String) -> Dictionary:
	if is_file(what):
		return _file_record(what)
	return _note_record(what)


## Whether [param what] names a video file (a path, or a name with a video's extension) rather than a note's title.
static func is_file(what: String) -> bool:
	return what.begins_with("/") or what.begins_with("~") or what.begins_with("user://") or EXTS.has(what.get_extension().to_lower())


## Whether anything is being taken for [param what].
static func busy(what: String) -> bool:
	return _jobs.has(what)


# --- a note --------------------------------------------------------------------------------------------------------------

static func _note_record(what: String) -> Dictionary:
	var out := {"what": what, "kind": "note", "ready": false, "secs": 0.0, "why": ""}
	var note := note_of(what)
	if note.is_empty():
		out["why"] = "there is no note titled %s" % what
		return out
	out["note"] = note
	var med := medium_of(note)
	out["medium"] = med
	if not NoteStoryboard.plays_scenes(med):
		out["why"] = "it is shown as %s - a note played on a screen is one shown in scenes (Auto, Full frame, Comic)" % Registry.label(Medium.REGISTRY, med)
		return out
	out["title"] = what
	var making := _mix_now(what, note)
	if not making.is_empty():
		out["why"] = making
		return out
	var song := song_of(note)
	if song.is_empty():
		# a note with no sound plays silent, timed by its storyboard
		var board := storyboard_of(note)
		if board.is_empty():
			out["why"] = "its song is not made yet (Generate on its own Pipeline card), and it keeps no storyboard to play silent"
			return out
		out["song"] = ""
		out["storyboard"] = board
		out["reveal"] = reveal_of(note)
		out["secs"] = Storyboard.silent_length(board)
		out["ready"] = true
		return out
	out["song"] = song
	out["bake"] = ProjectSettings.globalize_path(Bake.cache_path(song))
	out["storyboard"] = storyboard_of(note)
	out["reveal"] = reveal_of(note)
	out["secs"] = Exporter.wav_seconds(song) if song.get_extension().to_lower() == "wav" else 0.0
	if not FileAccess.file_exists(String(out["bake"])):
		if _failed.has(what):
			out["why"] = String(_failed[what])
			return out
		if not _jobs.has(what):
			_bake(what, song, String(out["bake"]))
		out["why"] = "its song is being heard (a bake, once)"
		return out
	if float(out["secs"]) <= 0.0:
		out["secs"] = float(_size_of(String(out["bake"]))) / float(Bake.CLI_BANDS * 4 * Bake.CLI_FPS)
	out["ready"] = true
	return out


## The note titled [param title] (in any case), its path; "" where there is none.
static func note_of(title: String) -> String:
	var want := title.strip_edges().to_lower()
	var now := Time.get_ticks_msec() / 1000.0
	if not _titles.has(want) and now - _titles_at > RESCAN:
		_titles_at = now
		_titles = {}
		for n in NoteStore.list():
			var t := String((n as Dictionary)["title"]).strip_edges().to_lower()
			if not _titles.has(t):
				_titles[t] = String((n as Dictionary)["path"])
	var p := String(_titles.get(want, ""))
	return p if not p.is_empty() and FileAccess.file_exists(p) else ""


## What stands in the way of the composed song of the note at [param note] (played for [param what]) as it stands: "" where its mix is
## made from the song as it is now, where it has no composed song, or where this process writes nothing (a render, a gate: it plays
## what is there); else the mix is made again ([method _make]), and this says so. Nobody opens the other note to make it.
static func _mix_now(what: String, note: String) -> String:
	var blocks := NoteStore.blocks_of(note)
	var snd: Dictionary = blocks.get("sound", {}) if blocks.get("sound") is Dictionary else {}
	if snd.is_empty() or String(snd.get("source", "composed")) != "composed" or Settings.is_read_only():
		return ""
	if _jobs.has(what) and String((_jobs[what] as Dictionary)["step"]) == "mix":
		return "its song is being made, as it stands now"
	if _failed.has(what):
		return String(_failed[what])
	var folder := NoteUpload.folder_of(note).path_join(SoundCard.FOLDER)
	var now := _song_now(note, snd, folder)
	if bool(now["current"]):
		return ""
	_make(what, now, folder)
	return "its song is being made, as it stands now" if _jobs.has(what) else String(_failed.get(what, ""))


## The composed song [param snd] of the note at [param note] as it stands (`{key, score, hash, current}`: its score, its stamp
## ([method SoundCard.stamp]), and whether the mix in [param folder] was made from it): worked out again only when the note, its
## reference, the mix, what the mix was made from or the kept voices change.
static func _song_now(note: String, snd: Dictionary, folder: String) -> Dictionary:
	var dir := ProjectSettings.globalize_path(folder)
	var mix := SongBake.mix_of(folder)
	var key := "%d|%d|%d|%d|%d" % [FileAccess.get_modified_time(note), FileAccess.get_modified_time(dir.path_join(SongBake.REFERENCE)),
		FileAccess.get_modified_time(dir.path_join(SongBake.MADE)), FileAccess.get_modified_time(mix), VoiceLibrary.version]
	var kept: Dictionary = _songs.get(note, {})
	if String(kept.get("key", "")) == key:
		return kept
	var r: Variant = snd.get("reference")
	var ref := SongBake.reference_of(folder) if r is Dictionary and not String((r as Dictionary).get("path", "")).is_empty() else {}
	var words := String(FrontMatter.split(FileAccess.get_file_as_string(note)).get("body", ""))
	var score := SoundCard.score_of(snd, words, ref, Singers.kept())
	var hash := SoundCard.stamp(score)
	var made_path := dir.path_join(SongBake.MADE)
	var made: Variant = JSON.parse_string(FileAccess.get_file_as_string(made_path)) if FileAccess.file_exists(made_path) else null
	var current := FileAccess.file_exists(mix) and made is Dictionary and String((made as Dictionary).get("hash", "")) == hash
	kept = {"key": key, "score": score, "hash": hash, "current": current}
	_songs[note] = kept
	return kept


## The mix of a composed song made again from [param now] ([method _song_now]) into [param folder], as its Sound card's Generate makes
## it ([SongBake]: the lines not kept sung, the parts rendered, its words' sidecar beside it), and marked made from it.
static func _make(what: String, now: Dictionary, folder: String) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		_failed[what] = "its song is out of date, and there is nothing here to make it again"
		return
	var bake := SongBake.new()
	var score: Dictionary = now["score"]
	var hash := String(now["hash"])
	bake.done.connect(func(job: String, ok: bool, _path: String, why: String) -> void:
		if job != "bake":
			return
		if ok:
			SoundCard.mark_made(folder, hash)
		else:
			_failed[what] = "its song could not be made: %s" % why
		_jobs.erase(what)
		bake.queue_free())
	bake.ready.connect(func() -> void: bake.bake(score, folder), CONNECT_ONE_SHOT)
	_jobs[what] = {"what": what, "step": "mix", "pid": -1}
	tree.root.add_child.call_deferred(bake)


## The song of the note at [param note] as its Sound card made it: the composed mix, or the file it plays; "" where none is made.
static func song_of(note: String) -> String:
	var blocks := NoteStore.blocks_of(note)
	var snd: Dictionary = blocks.get("sound", {}) if blocks.get("sound") is Dictionary else {}
	var old: Dictionary = blocks.get("song", {}) if blocks.get("song") is Dictionary else {}
	var path := ""
	if not snd.is_empty() and String(snd.get("source", "composed")) == "composed":
		path = SongBake.mix_of(NoteUpload.folder_of(note).path_join(SoundCard.FOLDER))
	elif not snd.is_empty():
		path = String(snd.get("path", ""))
	elif not old.is_empty():
		path = String(old.get("path", ""))
	if path.is_empty():
		return ""
	path = ProjectSettings.globalize_path(path)
	return path if FileAccess.file_exists(path) else ""


## The medium the note at [param note] is shown in (its Medium block's format; Auto where it has none).
static func medium_of(note: String) -> String:
	var blocks := NoteStore.blocks_of(note)
	var med: Dictionary = blocks.get("medium", {}) if blocks.get("medium") is Dictionary else {}
	var f := String(med.get("format", "auto"))
	return f if Medium.REGISTRY.has(f) else "auto"


## How the note at [param note] shows its words when it is played on a screen: as its Look card keeps it (its `look:` block's
## `subtitles`), else the credits - rolling over the whole frame, the screen too small for them.
static func reveal_of(note: String) -> String:
	var blocks := NoteStore.blocks_of(note)
	var look: Dictionary = blocks.get("look", {}) if blocks.get("look") is Dictionary else {}
	var r := String(look.get("subtitles", ""))
	return r if Subtitles.REVEALS.has(r) else "credits"


## The storyboard the note at [param note] keeps, in its loaded form ([method Storyboard.from_data]); {} where it keeps none (its
## seed chooses).
static func storyboard_of(note: String) -> Dictionary:
	var r := NoteStoryboard.read(NoteUpload.folder_of(note))
	var data: Dictionary = r.get("data", {})
	if not bool(r.get("ok", false)) or (data.get("sequence", []) as Array).is_empty():
		return {}
	var sb := Storyboard.from_data(data, Storyboard.IN_NOTE)
	return sb if bool(sb.get("ok", false)) else {}


## The song at [param song] heard once into its bake at [param cache], by the bake runner (a process of its own, as an export's).
static func _bake(what: String, song: String, cache: String) -> void:
	var args := Subprocess.own_log("screen_bake") + PackedStringArray(["--headless"])
	args.append_array(Boot.project_args())
	if OS.has_feature("editor"):
		args.append_array(PackedStringArray(["--script", "res://src/audio/bake_runner.gd"]))
	args.append_array(PackedStringArray(["--", "--bake-song", song, "--bake-out", cache]))
	var pid := Subprocess.start(OS.get_executable_path(), args, "screen bake")
	if pid <= 0:
		_failed[what] = "its song could not be heard (the bake would not start)"
		return
	_jobs[what] = {"what": what, "step": "bake", "pid": pid, "cache": cache}


# --- a video file --------------------------------------------------------------------------------------------------------

static func _file_record(what: String) -> Dictionary:
	var out := {"what": what, "kind": "file", "ready": false, "secs": 0.0, "why": ""}
	var f := file_of(what)
	if not FileAccess.file_exists(f):
		out["why"] = "there is no file at %s" % f
		return out
	var dir := ProjectSettings.globalize_path(FILES).path_join(f.md5_text().substr(0, 12))
	var kept: Variant = JSON.parse_string(FileAccess.get_file_as_string(dir.path_join(JSON_NAME))) if FileAccess.file_exists(dir.path_join(JSON_NAME)) else null
	if kept is Dictionary and String((kept as Dictionary).get("from", "")) == _stamp(f):
		var k: Dictionary = kept
		out["video"] = f
		out["sound"] = dir.path_join(SOUND) if bool(k.get("heard", false)) else ""
		out["secs"] = float(k.get("secs", 0.0))
		out["fps"] = float(k.get("fps", 30.0))
		var wh: Array = k.get("size", [640, 480])
		out["size"] = Vector2i(int(wh[0]), int(wh[1])) if wh.size() >= 2 else Vector2i(640, 480)
		out["ready"] = float(out["secs"]) > 0.0
		return out
	if _failed.has(what):
		out["why"] = String(_failed[what])
		return out
	if not _jobs.has(what):
		_read_file(what, f, dir)
	out["why"] = "it is being read (its size and its sound, once)"
	return out


## The video file [param what] names, absolute ("~" its owner's home).
static func file_of(what: String) -> String:
	if what.begins_with("~"):
		return OS.get_environment("HOME").path_join(what.substr(1).trim_prefix("/"))
	return ProjectSettings.globalize_path(what)


static func _stamp(f: String) -> String:
	return "%d:%s:%d:%d" % [VERSION, f, FileAccess.get_modified_time(f), _size_of(f)]


## A video file read: its size, frame rate and length probed, its sound taken out.
static func _read_file(what: String, f: String, dir: String) -> void:
	if not Deps.has("ffmpeg"):
		Provision.ensure("ffmpeg")
		_failed[what] = Deps.hint("ffmpeg")
		return
	DirAccess.make_dir_recursive_absolute(dir)
	var job := {"what": what, "step": "probe", "src": f, "dir": dir, "probe": dir.path_join("probe.json")}
	job["pid"] = Subprocess.start_logged("ffprobe", PackedStringArray(["-v", "error", "-select_streams", "v:0", "-show_entries",
		"stream=width,height,r_frame_rate:format=duration", "-of", "json", f]), String(job["probe"]), "film probe")
	job["sound_pid"] = Subprocess.start("ffmpeg", PackedStringArray(["-y", "-nostdin", "-loglevel", "quiet", "-i", f,
		"-map", "0:a:0", "-vn", "-ac", "2", "-ar", "44100", "-c:a", "pcm_s16le", dir.path_join(SOUND)]), "film sound")
	if int(job["pid"]) <= 0:
		_failed[what] = "could not start ffprobe"
		return
	_jobs[what] = job


static func _file_landed(job: Dictionary) -> void:
	var sp := int(job.get("sound_pid", -1))
	if sp > 0 and Subprocess.alive(sp):
		job["pid"] = sp
		job.erase("sound_pid")
		return
	var got: Variant = JSON.parse_string(FileAccess.get_file_as_string(String(job["probe"])))
	var streams: Array = (got as Dictionary).get("streams", []) if got is Dictionary else []
	_jobs.erase(String(job["what"]))
	if streams.is_empty():
		_failed[String(job["what"])] = "it has no picture FFmpeg can read"
		return
	var st: Dictionary = streams[0]
	var rate := String(st.get("r_frame_rate", "30/1")).split("/")
	var fps := float(rate[0]) / maxf(1.0, float(rate[1])) if rate.size() == 2 else 30.0
	var dir := String(job["dir"])
	var film := {"from": _stamp(String(job["src"])), "secs": float(((got as Dictionary).get("format", {}) as Dictionary).get("duration", 0.0)),
		"size": [int(st.get("width", 640)), int(st.get("height", 480))], "fps": clampf(fps, 1.0, 60.0), "heard": _size_of(dir.path_join(SOUND)) > 44}
	var out := FileAccess.open(dir.path_join(JSON_NAME), FileAccess.WRITE)
	if out != null:
		out.store_string(JSON.stringify(film, "\t"))
		out.close()


# --- what is being taken ---------------------------------------------------------------------------------------------------

## What ended, landed. Called each frame by whoever lists them.
static func pump() -> void:
	for w in _jobs.keys():
		var job: Dictionary = _jobs[w]
		var pid := int(job.get("pid", -1))
		if pid > 0 and Subprocess.alive(pid):
			continue
		match String(job["step"]):
			"bake":
				_jobs.erase(w)
				if not FileAccess.file_exists(String(job["cache"])):
					_failed[w] = "its song could not be heard (the bake left nothing)"
			"probe":
				_file_landed(job)


static func _size_of(path: String) -> int:
	if path.is_empty() or not FileAccess.file_exists(path):
		return 0
	var f := FileAccess.open(path, FileAccess.READ)
	return f.get_length() if f != null else 0
