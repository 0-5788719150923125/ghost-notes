extends RefCounted
class_name MaskUrlImport

## MaskUrlImport - a link where a file path is expected: Masking's YouTube (or any http) import,
## a part of [MaskEditor]. [method download] downloads the link with yt-dlp, polled and never
## blocking, and hands the file it made back to [method MaskEditor.open_source].
##
## WHAT IT IS HANDED is written out: every `editor.` below is something it reads of the editor
## (the import's state, which the editor's frame loop polls, the status line, where masks live).
##
## open_source() routes any http(s) source here. yt-dlp lives in ghost's own
## environment (`ytdlp_venv`, see [Provision]), with Deno beside it for YouTube's
## download challenges; the first import waits while it is built, then
##   <env python> -u -m yt_dlp <url>  ->  masks/_downloads/<title>_<id>.<ext>
## is polled like prep (never blocking), and the downloaded file re-enters
## open_source() so the normal ffmpeg->theora prep takes over unchanged. YouTube
## breaking old yt-dlp versions is the norm, not the exception: the environment is
## updated with the rest of ghost's dependencies, and a failed download updates it
## once more and retries.

## The [MaskEditor] this is a part of: everything read through it is something this part
## is handed, and the list of them is what it depends on.
var editor: MaskEditor

## Ghost's OWN python venv - yt-dlp lives here, never the repo's venvs or the
## system site-packages. user:// keeps it out of res:// (the editor's file
## scanner must never crawl a venv) and out of git entirely.
const YT_VENV_DIR := "user://ytdlp_venv"
const YT_DL_DIR := MaskEditor.MASKS_DIR + "/_downloads"   # inside /masks/ = already gitignored
var _yt_url := ""
var _yt_log := ""          # absolute path; the current step's combined stdout/stderr
var _yt_started := 0.0     # unix time the download step began (newest-file fallback)
var _yt_retried := false   # one automatic update-and-retry per import (stale yt-dlp)

# --- YouTube / URL import: paste a URL where a file path is expected --------------------------

static func is_url(path: String) -> bool:
	return path.begins_with("http://") or path.begins_with("https://")


## The video id, for cache hits and output matching (ported from nutube's
## YouTubeSource.id_from_url). "" for URLs that don't look like YouTube - yt-dlp
## handles plenty of other sites; those just skip the id-keyed cache.
static func _youtube_id(url: String) -> String:
	var u := url.strip_edges()
	if u.contains("watch?v="):
		u = u.get_slice("watch?v=", 1)
	elif u.contains("youtu.be/"):
		u = u.get_slice("youtu.be/", 1)
	elif u.contains("/shorts/"):
		u = u.get_slice("/shorts/", 1)
	else:
		return ""
	for sep in ["?", "&", "#", "/"]:
		u = u.get_slice(sep, 0)
	return u


func _yt_bin(tool_name: String) -> String:
	return Deps.venv_bin(YT_VENV_DIR, tool_name)


func _yt_dl_dir() -> String:
	return ProjectSettings.globalize_path(YT_DL_DIR if OS.has_feature("editor")
		else MaskEditor._masks_dir() + "/_downloads")


## Resolve a binary. [Deps] owns this for the whole app - a GUI-launched Godot
## doesn't inherit a shell PATH, and the answer has to be the same one
## [Subprocess] and the home screen's Environment panel get.
static func _which(prog: String) -> String:
	return Deps.resolve(prog)


func download(url: String) -> void:
	if editor._yt_state != "idle":
		editor._set_status("⏳  Another download is already running…")
		return
	_yt_url = url
	_yt_retried = false
	editor._yt_echoed = {}
	DirAccess.make_dir_recursive_absolute(_yt_dl_dir())
	print("ghost yt: import requested - ", url)
	var cached := _yt_find_download()
	if not cached.is_empty():
		# Says so in the log too - otherwise a cache hit runs NO python at all
		# and an empty console reads as "capture is broken", not "nothing ran".
		print("ghost yt: using cached download - ", cached)
		editor._set_status("✓  Already downloaded - opening the cached copy")
		editor.open_source(cached)
		return
	var why := Provision.unsupported(MaskEditor.YT_ENV)
	if not why.is_empty():
		editor._set_status("⚠  URL import is not available on this machine: " + why)
		return
	editor._yt_state = "provisioning"
	editor._yt_step_started = Time.get_unix_time_from_system()
	wait_for_env()


## Download once the environment is ready; until then show what its install is doing,
## and stop with the install's own reason if it cannot be had. Polled from _process.
func wait_for_env() -> void:
	if Provision.ensure(MaskEditor.YT_ENV):
		editor._yt_state = "idle"
		_yt_download()
		return
	var s := Provision.state(MaskEditor.YT_ENV)
	if not bool(s.get("running", false)) and (s.has("error") or not Provision.can_install()):
		editor._yt_state = "idle"
		editor._set_status("⚠  " + Deps.hint(MaskEditor.YT_ENV))
		return
	editor._set_status("⏳  Preparing URL import - " + Provision.describe(MaskEditor.YT_ENV, s))


func _yt_download() -> void:
	_yt_started = Time.get_unix_time_from_system()
	editor._yt_step_started = _yt_started
	# No codec constraints in the format pick - the prep transcodes to theora
	# regardless, so "best up to 1080p" is all that matters. --restrict-filenames
	# keeps the output shell-and-slug-safe; the title lands in the session slug.
	# Runs as `python -u -m yt_dlp`, NOT the yt-dlp entry script: with stdout
	# going to a file, python block-buffers it and the "[download] 42%" lines
	# only landed in the log kilobytes at a time - the progress readout below
	# read an empty file for minutes (the "black screen" report). -u makes the
	# log stream line-by-line, same reason exporter's ffmpeg uses -progress.
	var args := PackedStringArray([
		"-u", "-m", "yt_dlp",
		"-f", "bv*[height<=1080]+ba/b[height<=1080]",
		"--no-playlist", "--restrict-filenames", "--newline",
		# Under 100K/s yt-dlp assumes YouTube's anti-bot throttle and re-extracts
		# instead of crawling for an hour; fragmented formats also parallelize.
		"--throttled-rate", "100K", "--concurrent-fragments", "4"])
	# YouTube's nsig/PO-token challenges need a JavaScript runtime, and with NONE
	# the download still "works", just at the punitive fallback throttle (~40KB/s:
	# the "0% to 1% took three minutes" report). The environment carries Deno for
	# exactly this; on a machine with no Deno build, whatever runtime the machine
	# has stands in. By explicit path - a GUI-launched Godot's PATH is not a
	# shell's, so auto-detection can't be trusted either.
	var deno := _yt_bin("deno")
	if FileAccess.file_exists(deno):
		args.append_array(PackedStringArray(["--js-runtimes", "deno:" + deno]))
	else:
		for rt in ["deno", "node"]:
			var rt_bin := _which(rt)
			if not rt_bin.is_empty():
				args.append("--js-runtimes")
				args.append(rt + ":" + rt_bin)
	args.append_array(PackedStringArray([
		"-o", _yt_dl_dir().path_join("%(title).40s_%(id)s.%(ext)s"),
		_yt_url]))
	# The exact command, in the log: whether --js-runtimes was engaged is the
	# first thing to check when a download crawls (no runtime = YouTube's
	# ~40KB/s anti-bot throttle).
	print("ghost yt: exec ", _yt_bin("python"), " ", " ".join(args))
	Provision.hold(MaskEditor.YT_ENV, "clip download")
	editor._yt_pid = _yt_spawn_logged(_yt_bin("python"), args)
	editor._yt_state = "downloading" if editor._yt_pid > 0 else "idle"
	# Status lands IMMEDIATELY, success or not - the first cut only reported
	# failure here, so a clean start showed nothing until the download finished.
	editor._set_status("⏳  Downloading…  connecting" if editor._yt_pid > 0
		else "⚠  Could not start yt-dlp")


## OS.create_process can't redirect output, and both the progress readout and any
## failure diagnosis live in it - so stdout+stderr go to a log file this instance
## then tails ([method Subprocess.start_logged], no shell on any platform).
func _yt_spawn_logged(cmd: String, args: PackedStringArray) -> int:
	_yt_log = _yt_dl_dir().path_join(".yt.log")
	return Subprocess.start_logged(cmd, args, _yt_log, "clip download")


## The log's last 4KB. This is polled EVERY FRAME while a download runs (the
## same cadence _read_prep_pct polls ffmpeg's progress file), and a long
## --newline download writes tens of thousands of lines - reading the whole
## file each frame would grow linearly with the download. The freshest
## progress line always lives in the tail window.
func tail_window() -> String:
	if _yt_log.is_empty() or not FileAccess.file_exists(_yt_log):
		return ""
	var f := FileAccess.open(_yt_log, FileAccess.READ)
	if f == null:
		return ""
	var sz := f.get_length()
	if sz > 4096:
		f.seek(sz - 4096)
	return f.get_buffer(mini(int(sz), 4096)).get_string_from_utf8()


## The freshest yt-dlp "[download]  42.3% of 10.5MiB at 2.1MiB/s ETA 00:04"
## line, as display text - percent, size, speed and ETA ride along verbatim.
func pct() -> String:
	var best := ""
	for line in tail_window().split("\n"):
		if line.begins_with("[download]") and line.contains("%"):
			best = line.substr(10).strip_edges()
	return best


func _yt_log_tail() -> String:
	var lines := tail_window().strip_edges().split("\n")
	return String(lines[lines.size() - 1]).substr(0, 160) if lines.size() > 0 else ""


## The downloaded file for the current URL: id-matched when the URL is YouTube,
## else the newest completed media file since the download began. Excludes
## yt-dlp's own .part/.ytdl intermediates and the log.
func _yt_find_download() -> String:
	var dir := DirAccess.open(_yt_dl_dir())
	if dir == null:
		return ""
	var id := _youtube_id(_yt_url)
	var best := ""
	var best_mtime := 0
	for f in dir.get_files():
		if f.ends_with(".part") or f.ends_with(".ytdl") or f.begins_with("."):
			continue
		var p := _yt_dl_dir().path_join(f)
		if not id.is_empty():
			if f.contains(id):
				return p
			continue
		var mt := FileAccess.get_modified_time(p)
		if mt >= int(_yt_started) and mt > best_mtime:
			best_mtime = mt
			best = p
	return best


## Everything a finished step logged - minus the [download] progress spam -
## echoes into godot's own log via print(), which is what the in-app console
## (chrome's >_ toggle) tails. yt-dlp's diagnostics (throttling, missing JS
## runtime, geo blocks, format errors) otherwise die unseen in
## masks/_downloads/.yt.log, unreadable from a compiled app.
func _yt_echo_log(label: String) -> void:
	if _yt_log.is_empty() or not FileAccess.file_exists(_yt_log):
		return
	var kept := PackedStringArray()
	for line in FileAccess.get_file_as_string(_yt_log).split("\n"):
		var s := line.strip_edges()
		if not s.is_empty() and not s.begins_with("[download]"):
			kept.append(s)
	if kept.size() > 40:
		kept = kept.slice(kept.size() - 40)
	if kept.size() > 0:
		print("ghost yt [", label, "]:\n  ", "\n  ".join(kept))


## The download just exited (see _process) - advance the machine. Success is
## judged by what it was supposed to produce (the file) - the same evidence-over-
## status-code stance as _finish_session's duration check.
func step_done() -> void:
	var state := editor._yt_state
	editor._yt_state = "idle"
	Provision.release(MaskEditor.YT_ENV, "clip download")
	_yt_echo_log(state)
	var file := _yt_find_download()
	if not file.is_empty():
		editor._set_status("✓  Downloaded " + file.get_file())
		editor.open_source(file)
	elif not _yt_retried:
		# The single most common failure mode is a stale yt-dlp (YouTube changed,
		# old extractor broke) - update the environment once, then retry.
		_yt_retried = true
		editor._set_status("⚠  Download failed - updating yt-dlp and retrying…")
		Provision.update(MaskEditor.YT_ENV)
		editor._yt_state = "provisioning"
		editor._yt_step_started = Time.get_unix_time_from_system()
	else:
		editor._set_status("⚠  Download failed: " + _yt_log_tail())
