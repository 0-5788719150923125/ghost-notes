extends RefCounted
class_name Films

## Films - the library of imported video clips a comic panel can be filled with.
##
## Owns the library (the clips, their import, and the two dials over them: which clips exist and how
## often a page reaches for one), not the playback ([FilmScene]) or the deciding (the comic medium).
##
## The clock is virtual: [method position_at] answers "where would this clip be if it had been looping
## since the show started", and a panel seeks there when it opens. A clip reads as one film running all
## along with no background decoding, and the answer is a pure function of the show clock, so an export
## renders the same frames as the live session.
##
## One film panel at a time: two panels sampling one clip at the same instant would show the same
## picture, so the comic never runs more than one film panel on a page ([member ComicMedium._film_at]).

## Where a clip's prepared windows live, one subdirectory per clip. A clip belongs to the library and
## survives every session.
const DIR := "user://films"

## Import prepares nothing. Ogg Theora is the only format [VideoStreamPlayer] decodes natively, so a
## clip must be transcoded, but only a window of it is ever wanted: a film panel is on screen for
## seconds and the show clock decides where it starts. What is prepared is [constant WINDOW] seconds
## around the position actually wanted, extracted on demand and cached; an import is a probe only.
##
## The original file is a dependency, not consumed once: move or delete it and the clip stops working
## ([method clips] drops entries whose source has gone).
const WINDOW := 15.0
## Overlap carried past the end of each window, so a panel at the boundary has frames to play while
## the next window loads and a seek near the end has somewhere to land.
const LEAD := 4.0
## Longest edge of a prepared window, in pixels (and the theora quality).
##
## Set by the panel, not the encoder: a comic panel's render target is the stage's short side
## (`ComicMedium._size_targets`, 1080 on a 1080p window) and the camera fills the frame with that panel,
## so a 640 cap is a visible 1.7x upscale. The cap only stops a 4K source being re-encoded at 4K.
## Timed on a 1920x1080 clip: no downscale at q6 runs at 0.43x realtime, 1440 at 0.91x. Slower than
## realtime is affordable only because windows are cut in parallel (see PIPELINE).
const MAX_EDGE := 1920
const Q := "6"
## How many windows of one clip are kept on disk before the oldest are dropped. The show clock is the
## audio clock, so replaying a song asks for the same windows and is cut entirely from cache. A window
## is a few megabytes.
const CACHE_WINDOWS := 48
## How many windows are cut at once. The wanted window advances at 1x realtime and one cut runs at about
## 0.43x on a 1080p source, so one at a time never keeps up; four in flight cover 4 x 15 s of film in the
## ~35 s one takes (about 1.7x). libtheora is single-threaded, so these are four cores; they run only
## while film is in use.
const PIPELINE := 4
## `-g 25` keeps a keyframe about every second, so the seek in [FilmScene] lands quickly.
const GOP := "25"

## The frequency dial's range: a probability per page, not per panel (only one film panel is allowed at a
## time): at 1.0 every page has one, at 0 none.
##
## It does not compete with the scene catalog: a film is an independent draw made when the page turns,
## and only then does the rest of the page go to the Director.
##
## The default is chosen so footage appears soon enough to see: over 400 pages (3.3 panels on average)
## 0.3 puts film on 27% of pages and 8% of panels, 0.5 on 46% of pages and 14% of panels (about every
## seventh cut), and the comic is still overwhelmingly drawn.
const FREQ_MIN := 0.0
const FREQ_MAX := 1.0
const FREQ_DEFAULT := 0.5

## Anything shorter is a glitch, not a film (a clip shorter than a panel's time on screen would visibly
## restart while read).
const MIN_DURATION := 1.0


## A library and a frequency supplied by a probe, standing in for the stored ones: the library lives in
## [Settings], which a test probe must not write (see Settings.allow_writes_for_test). The only seam;
## nothing else reads it. `_test_active` is a flag of its own rather than "the list is non-empty",
## because an empty library is a state worth testing and must not mean "use the real ones".
static var _test_active := false
static var _test_clips: Array = []
static var _test_frequency := -1.0


static func use_for_test(list: Array, freq := 1.0) -> void:
	_test_active = true
	_test_clips = list
	_test_frequency = freq


## Every imported clip: `[{source, name, duration, slug}]`, in import order. Clips whose source has gone
## missing are dropped on read: windows are cut from the original on demand, so such a clip would be
## picked and draw nothing (see [constant WINDOW]).
static func clips() -> Array:
	if _test_active:
		return _test_clips
	var out: Array = []
	for row in (Settings.read("films", "clips", []) as Array):
		if not (row is Dictionary):
			continue
		var c: Dictionary = row
		if FileAccess.file_exists(String(c.get("source", ""))):
			out.append(c)
	return out


static func _store(list: Array) -> void:
	Settings.write("films", "clips", list)


## Forget a clip and delete the windows cut from it (they live under a directory that exists only for
## this entry). The original is never touched: it is the viewer's own file.
static func remove(i: int) -> void:
	var list := clips()
	if i < 0 or i >= list.size():
		return
	var c: Dictionary = list[i]
	_clear_windows(c)
	var dir := ProjectSettings.globalize_path(clip_dir(c))
	if DirAccess.dir_exists_absolute(dir):
		DirAccess.remove_absolute(dir)
	list.remove_at(i)
	_store(list)


## How often a page reaches for a clip, 0..1. Zero, or an empty library, means no film.
static func frequency() -> float:
	if _test_frequency >= 0.0:
		return _test_frequency
	return clampf(float(Settings.read("films", "frequency", FREQ_DEFAULT)), FREQ_MIN, FREQ_MAX)


static func set_frequency(v: float) -> void:
	Settings.write("films", "frequency", clampf(v, FREQ_MIN, FREQ_MAX))


## Where the clip is now, in seconds, as if it had been looping since time zero. The show clock is the
## argument so the live session and an export pass the same one and the answer is reproducible.
static func position_at(clip: Dictionary, show_time: float) -> float:
	var dur := float(clip.get("duration", 0.0))
	if dur <= MIN_DURATION:
		return 0.0
	# Guard the negative: a bookend hold runs the clock below zero at the head of a render, and
	# VideoStreamPlayer refuses a negative seek.
	return fposmod(show_time, dur)


## The clip to use for a page, or `{}` when the library is empty. Seeded, so a session replays the same
## footage in the same panels.
static func pick(seed_value: int) -> Dictionary:
	var list := clips()
	if list.is_empty():
		return {}
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return list[rng.randi() % list.size()]


# --- windows ------------------------------------------------------------------
#
# A window is [constant WINDOW] seconds of a clip, cut from the original on demand and cached. Windows
# tile the clip from zero, so which one covers a position is arithmetic and two panels asking for the
# same moment ask for the same file.

## Where this clip's windows live.
static func clip_dir(clip: Dictionary) -> String:
	return DIR.path_join(String(clip.get("slug", "clip")))


## Which window covers `pos` (seconds into the clip).
static func window_index(pos: float) -> int:
	return int(floor(maxf(pos, 0.0) / WINDOW))


## Where `pos` sits inside its window: what [FilmScene] seeks the player to (a window's own timeline
## starts at zero).
static func window_local(pos: float) -> float:
	return maxf(pos, 0.0) - float(window_index(pos)) * WINDOW


## The window length is in the name: window 3 means "45s to 64s" only while window is 15, so changing
## the constant turns every cached file into a cache miss (one re-cut) instead of footage of the wrong
## minute.
static func window_path(clip: Dictionary, index: int) -> String:
	return clip_dir(clip).path_join("w%04d_%ds.ogv" % [maxi(index, 0), int(WINDOW)])


## Is this window cut and ready to play?
static func window_ready(clip: Dictionary, index: int) -> bool:
	return FileAccess.file_exists(ProjectSettings.globalize_path(window_path(clip, index)))


## Does this window exist at all? A clip shorter than one window has only window 0, and asking for
## window 3 must not start an ffmpeg run that produces an empty file forever.
static func window_exists(clip: Dictionary, index: int) -> bool:
	return index >= 0 and float(index) * WINDOW < float(clip.get("duration", 0.0))


## Running window cuts, keyed by the window's path so two requests for one window are one ffmpeg
## process. Static because a window belongs to the clip, not to the panel that asked first.
static var _jobs := {}


## Ask for a window. Returns true if it is already playable; false means "not yet", and a cut has been
## started if none was running. Cheap to call every frame (two early exits: a file check and a
## dictionary lookup).
static func request_window(clip: Dictionary, index: int) -> bool:
	if not window_exists(clip, index):
		return false
	if window_ready(clip, index):
		return true
	var dest := window_path(clip, index)
	if _jobs.has(dest):
		return false
	# A hard cap on concurrent cuts: PIPELINE is how many may run at once, and every page and every
	# FilmScene asks again. libtheora pins a core each.
	if _jobs.size() >= PIPELINE:
		return false
	if not Deps.has("ffmpeg"):
		return false
	var abs := ProjectSettings.globalize_path(dest)
	DirAccess.make_dir_recursive_absolute(abs.get_base_dir())
	# A `.part` with nothing running behind it is the wreckage of a killed run: clear it so the window
	# can be cut again. A cut is one pass, never resumed.
	if FileAccess.file_exists(abs + ".part"):
		DirAccess.remove_absolute(abs + ".part")
	var start := float(index) * WINDOW
	# `-ss` before `-i` is the fast seek (to the keyframe, not decoding from the top) and has been
	# accurate since ffmpeg 2.1 (it decodes and discards to the exact point), which the clock depends on.
	var args := PackedStringArray([
		"-y", "-loglevel", "error",
		"-ss", "%.3f" % start, "-i", String(clip.get("source", "")),
		"-t", "%.3f" % (WINDOW + LEAD), "-an",
		# Never upscales: the box is capped at the source's own size.
		"-vf", "scale=w='min(%d,iw)':h='min(%d,ih)'" % [MAX_EDGE, MAX_EDGE]
			+ ":force_original_aspect_ratio=decrease:force_divisible_by=2",
		"-c:v", "libtheora", "-q:v", Q, "-g", GOP,
		"-f", "ogg", abs + ".part"])
	var pid := Subprocess.start("ffmpeg", args, "film window")
	if pid <= 0:
		return false
	_jobs[dest] = pid
	return false


## Notice finished cuts. Call from anywhere with a frame: [FilmScene] does while a panel is live, and the
## Generative panel while an import is warming. Never blocks on a cut: the subprocess runs whether or not
## anyone is pumping.
static func pump() -> void:
	if _jobs.is_empty():
		return
	for dest in _jobs.keys():
		var pid: int = int(_jobs[dest])
		if Subprocess.alive(pid):
			continue
		Subprocess.forget(pid)
		_jobs.erase(dest)
		var abs := ProjectSettings.globalize_path(String(dest))
		# Written as `.part` and promoted: a half-written media file at its real name is scanned by the
		# editor's importer (a truncated one can wedge it in a seek loop) and would be a window that
		# exists, plays a fragment, and is never cut again.
		if FileAccess.file_exists(abs + ".part"):
			if FileAccess.file_exists(abs):
				DirAccess.remove_absolute(abs)
			DirAccess.rename_absolute(abs + ".part", abs)
			_trim_cache(String(dest).get_base_dir())


## Is a cut running for this clip right now? The UI says so rather than looking idle.
static func busy(clip: Dictionary) -> bool:
	var dir := clip_dir(clip)
	for dest in _jobs.keys():
		if String(dest).begins_with(dir):
			return true
	return false


## Drop the oldest windows of one clip once there are more than [constant CACHE_WINDOWS], by
## modification time (last cut, close enough, and needs no state).
static func _trim_cache(dir: String) -> void:
	var abs := ProjectSettings.globalize_path(dir)
	var d := DirAccess.open(abs)
	if d == null:
		return
	var files: Array = []
	for f in d.get_files():
		if String(f).ends_with(".ogv"):
			files.append({"f": String(f),
				"t": FileAccess.get_modified_time(abs.path_join(String(f)))})
	if files.size() <= CACHE_WINDOWS:
		return
	files.sort_custom(func(a, b): return int(a.t) < int(b.t))
	for i in files.size() - CACHE_WINDOWS:
		DirAccess.remove_absolute(abs.path_join(String(files[i].f)))


static func _clear_windows(clip: Dictionary) -> void:
	var abs := ProjectSettings.globalize_path(clip_dir(clip))
	var d := DirAccess.open(abs)
	if d == null:
		return
	for f in d.get_files():
		DirAccess.remove_absolute(abs.path_join(String(f)))


# --- import -------------------------------------------------------------------

## Add a clip to the library. Returns "" on success, or why it could not be added. An import is a
## probe: it reads the duration, writes the entry and returns; the first window is asked for on the way
## out as a head start, in the background.
static func add(source: String) -> String:
	if not FileAccess.file_exists(source):
		return "there is no file at that path"
	if not Deps.has("ffprobe") or not Deps.has("ffmpeg"):
		Provision.ensure("ffmpeg")
		return Deps.hint("ffmpeg")
	var duration := _probe_duration(source)
	if duration <= MIN_DURATION:
		return "could not read a duration from that file (is it a video?)"
	var slug := _slug(source)
	var list := clips()
	for c in list:
		if String((c as Dictionary).get("source", "")) == source:
			return "that clip is already in the library"
	var entry := {"source": source, "name": source.get_file().get_basename(),
		"duration": duration, "slug": slug, "aspect": _probe_aspect(source)}
	list.append(entry)
	_store(list)
	# A head start only: which window is wanted is not knowable here.
	request_window(entry, 0)
	return ""


## Can the show play this clip at `show_time` right now - and if not, start cutting so it can next time.
## The caller asks every time it wants the clip and has an answer ready for false. The comic casts an
## ordinary scene instead, so a window not cut yet is a page without footage, never a blank panel; film
## appears as often as the machine can prepare it.
static func warm(clip: Dictionary, show_time: float) -> bool:
	var i := window_index(position_at(clip, show_time))
	var ready := request_window(clip, i)
	# And the ones after it: cutting is slower than the clock it is chasing (see PIPELINE), so asking
	# only for the window needed now is a race lost every time.
	var at := i
	for _n in PIPELINE - 1:
		at = next_window(clip, at)
		if at == i:
			break                    # a clip shorter than the pipeline: it wrapped
		request_window(clip, at)
	return ready


## The window after `index`, wrapping - a clip loops, so past the last window is the first.
static func next_window(clip: Dictionary, index: int) -> int:
	return index + 1 if window_exists(clip, index + 1) else 0


## A filename-safe, collision-resistant name for a source path (the hash stops a second `clip.mp4` from
## another folder overwriting the first one's transcode).
static func _slug(source: String) -> String:
	var base := source.get_file().get_basename().to_lower()
	var out := ""
	for i in base.length():
		var c := base[i]
		out += c if (c >= "a" and c <= "z") or (c >= "0" and c <= "9") else "_"
	out = out.substr(0, 40).strip_edges()
	return "%s_%d" % [out if not out.is_empty() else "clip", hash(source) & 0xFFFFFF]


## Seconds of video in `path`, or 0. Three ways, in order of trust (a container can lack the duration in
## its format header, its stream header, or both; the last resort counts the packets). Lifted from
## mask_editor._probe_duration.
static func _probe_duration(path: String) -> float:
	var d := _ffprobe_float(["-show_entries", "format=duration"], path)
	if d > 0.0:
		return d
	d = _ffprobe_float(["-select_streams", "v:0", "-show_entries", "stream=duration"], path)
	if d > 0.0:
		return d
	var out: Array = []
	Deps.execute("ffprobe", ["-v", "error", "-select_streams", "v:0", "-count_packets",
		"-show_entries", "stream=nb_read_packets,r_frame_rate", "-of", "default=nw=1", path], out)
	if out.size() > 0:
		var packets := 0.0
		var fps := 0.0
		for line in String(out[0]).split("\n"):
			var s := line.strip_edges()
			if s.begins_with("nb_read_packets="):
				packets = s.substr(16).to_float()
			elif s.begins_with("r_frame_rate="):
				var fr := s.substr(13).split("/")
				if fr.size() == 2 and fr[1].to_float() > 0.0:
					fps = fr[0].to_float() / fr[1].to_float()
				else:
					fps = s.substr(13).to_float()
		if packets > 0.0 and fps > 0.0:
			return packets / fps
	return 0.0


## The clip's shape, width over height. Kept on the entry because it decides which panel the film goes
## in: cover crops the spare axis, so a clip in a panel of roughly its own shape loses almost nothing.
## See ComicMedium._choose_film.
static func _probe_aspect(path: String) -> float:
	var out: Array = []
	if Deps.execute("ffprobe", ["-v", "error", "-select_streams", "v:0",
			"-show_entries", "stream=width,height", "-of", "csv=p=0:s=x", path], out) != 0:
		return 0.0
	if out.is_empty():
		return 0.0
	var wh := String(out[0]).strip_edges().split("x")
	if wh.size() < 2 or wh[1].to_float() <= 0.0:
		return 0.0
	return wh[0].to_float() / wh[1].to_float()


## Probed shapes for clips stored before `aspect` was kept. Once per clip per process: ffprobe blocks,
## and this is reached from a page turn.
static var _aspect_cache := {}


## The clip's aspect, 0 when it cannot be determined (callers treat it as "no preference").
static func aspect_of(clip: Dictionary) -> float:
	var a := float(clip.get("aspect", 0.0))
	if a > 0.0:
		return a
	var src := String(clip.get("source", ""))
	if src.is_empty():
		return 0.0
	if not _aspect_cache.has(src):
		_aspect_cache[src] = _probe_aspect(src)
	return float(_aspect_cache[src])


static func _ffprobe_float(entries: Array, path: String) -> float:
	var args: Array = ["-v", "error"]
	args.append_array(entries)
	args.append_array(["-of", "default=noprint_wrappers=1:nokey=1", path])
	var out: Array = []
	if Deps.execute("ffprobe", args, out) != 0 or out.is_empty():
		return 0.0
	return String(out[0]).strip_edges().to_float()
