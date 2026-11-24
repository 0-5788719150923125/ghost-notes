extends RefCounted
class_name ScreenFilm

## ScreenFilm - a film played on a screen in a scene (a Dispatch desk's terminal, its little monitors): its picture a texture of the
## frame at a moment of the film, its sound heard in step. A pure function of the film's time: a scrub lands on the frame there, and a
## render shows the frame a live show showed.
##
## The picture is decoded by FFmpeg, piped as raw frames into a thread of its own from the moment asked for ([constant AHEAD] frames
## ahead of it at most); the app's thread only puts the frame due into the texture. A moment behind what is decoded, or far past it,
## starts the decoder again there. A render ([param wait] in [method frame_at]) waits for the frame due; live, the last frame stays up
## until it comes.
##
## The sound is a WAV beside the film, loaded on a worker, played by a player of its own under the node its scene hands it ([method
## hear]), sought where it strays from the film's time by more than [constant DRIFT].
##
## A film is `{video, sound, secs, size, fps}` (absolute paths, seconds, pixels, frames a second) - what [NoteFilm] makes of a note or
## reads of a video file.

## Frames decoded ahead of the one due, at most; how far past what is decoded a moment may be before the decoder starts again there
## (frames); how long a render waits for a frame (ms).
const AHEAD := 30
const JUMP := 45
const WAIT_MOST := 8000
## The largest a picture is decoded at (px): a screen in a scene is never larger in the frame.
const LARGEST := Vector2i(960, 720)
## How far the sound may stray from the film's time before it is sought (s).
const DRIFT := 0.12
## How far it may stray in a render before it is sought (s): only a jump.
const MOVIE_JUMP := 0.5

var video := ""
var sound := ""
var secs := 0.0
var fps := 30.0
var size := Vector2i.ZERO

var _tex: ImageTexture = null
var _shown := -1                 # the frame in the texture
var _thread: Thread = null
var _lock := Mutex.new()
var _frames := {}                # frame index -> Image, decoded
var _from := -1                  # the earliest frame it can still give: where the decoder began, or the last taken
var _hi := -1                    # the last frame it decoded
var _due := 0                    # the frame due now, which the decoder keeps ahead of
var _quit := false
var _pid := -1
var _player: AudioStreamPlayer = null
var _stream: AudioStreamWAV = null
var _loading := -1               # the sound's load on a worker
var _loaded: Array = []          # ...what it loaded


## The film [param film] (`{video, sound, secs, size, fps}`).
func _init(film: Dictionary) -> void:
	video = String(film.get("video", ""))
	sound = String(film.get("sound", ""))
	secs = float(film.get("secs", 0.0))
	fps = maxf(float(film.get("fps", 30.0)), 1.0)
	var s: Variant = film.get("size", Vector2i(640, 480))
	var want := Vector2i(s) if s is Vector2i else (Vector2i(int((s as Array)[0]), int((s as Array)[1])) if s is Array and (s as Array).size() >= 2 else Vector2i(640, 480))
	var k := minf(1.0, minf(float(LARGEST.x) / float(maxi(want.x, 1)), float(LARGEST.y) / float(maxi(want.y, 1))))
	size = Vector2i(maxi(2, int(want.x * k) / 2 * 2), maxi(2, int(want.y * k) / 2 * 2))


## Whether it has a picture to play.
func playable() -> bool:
	return not video.is_empty() and FileAccess.file_exists(video) and secs > 0.0


## How many frames it has.
func frames() -> int:
	return maxi(1, int(ceil(secs * fps)))


## The frame at [param t] seconds into the film (its first before it, its last after it), as a texture - the one up until the frame
## due is decoded, unless [param wait] (a render: the frame due, waited for). Null before any frame is decoded.
func frame_at(t: float, wait := false) -> Texture2D:
	if not playable():
		return null
	var i := index_at(t)
	if i == _shown and _tex != null:
		return _tex
	var img := image_at(t, wait)
	if img == null:
		return _tex
	if _tex == null or Vector2i(_tex.get_size()) != img.get_size():
		_tex = ImageTexture.create_from_image(img)
	else:
		_tex.update(img)
	_shown = i
	return _tex


## The frame's index at [param t] seconds into the film.
func index_at(t: float) -> int:
	return clampi(int(floor(maxf(t, 0.0) * fps)), 0, frames() - 1)


## The frame at [param t] seconds into the film as decoded ([method frame_at]'s), null where it is not decoded yet (waited for where
## [param wait]).
func image_at(t: float, wait := false) -> Image:
	if not playable():
		return null
	var i := index_at(t)
	_lock.lock()
	var behind := _thread == null or i < _from or i > _hi + JUMP
	_due = i
	_lock.unlock()
	if behind:
		_start(i)
	var img := _take(i)
	if img == null and wait:
		var waited := 0
		while img == null and waited < WAIT_MOST:
			OS.delay_msec(4)
			waited += 4
			img = _take(i)
	return img


## Its sound at [param t] seconds into the film under [param host] while [param on] (silent while not), held while [param paused]:
## started there, sought where it strays. [param wait]: loaded here and now (a render), never waited for live.
func hear(t: float, host: Node, on: bool, paused := false, wait := false) -> void:
	if sound.is_empty() or not FileAccess.file_exists(sound):
		return
	if _stream == null:
		_load_sound(wait)
		if _stream == null:
			return
	if _player == null:
		_player = AudioStreamPlayer.new()
		_player.name = "Film sound"
		_player.stream = _stream
		host.add_child(_player)
	var inside := on and t >= 0.0 and t < _stream.get_length()
	if not inside:
		if _player.playing:
			_player.stop()
		return
	_player.stream_paused = paused
	if paused:
		return
	if not _player.playing:
		_player.play(t)
		return
	# a Movie Maker render mixes one frame of sound a frame: the wall clock since the last mix means nothing there, and only a jump
	# (a loop round) is sought
	var movie := not Engine.get_write_movie_path().is_empty()
	var at := _player.get_playback_position() + (0.0 if movie else AudioServer.get_time_since_last_mix())
	if absf(at - t) > (MOVIE_JUMP if movie else DRIFT):
		_player.seek(t)


## Stop decoding and hearing it, and let go of what it holds.
func stop() -> void:
	_end_decoder()
	if _loading >= 0:
		WorkerThreadPool.wait_for_task_completion(_loading)
		_loading = -1
	if _player != null and is_instance_valid(_player):
		_player.stop()
		_player.queue_free()
	_player = null


# --- the decoder ---------------------------------------------------------------------------------------------------------

## The decoder begun again at frame [param i].
func _start(i: int) -> void:
	_end_decoder()
	_lock.lock()
	_frames = {}
	_from = i
	_hi = i - 1
	_due = i
	_quit = false
	_lock.unlock()
	var info := Subprocess.start_with_pipe("ffmpeg", args_for(video, float(i) / fps, fps, size), "film frames")
	_pid = int(info.get("pid", -1))
	var pipe: FileAccess = info.get("stdio")
	if _pid <= 0 or pipe == null:
		return
	_thread = Thread.new()
	_thread.start(_decode.bind(pipe, i))


## What FFmpeg is told: from [param from] seconds of [param path], at [param rate] frames a second and [param px] pixels, raw RGBA
## frames out of its standard output, its sound left.
static func args_for(path: String, from: float, rate: float, px: Vector2i) -> PackedStringArray:
	return PackedStringArray(["-nostdin", "-loglevel", "error", "-ss", "%.3f" % maxf(from, 0.0), "-i", path, "-an",
		"-vf", "fps=%s,scale=%d:%d:flags=bilinear" % [str(rate), px.x, px.y], "-pix_fmt", "rgba", "-f", "rawvideo", "pipe:1"])


## The decoder's thread: each frame read whole off [param pipe] from frame [param i] on, kept as an Image, no further than [constant
## AHEAD] past the one due; done at the pipe's end or when told to quit.
func _decode(pipe: FileAccess, i: int) -> void:
	var need := size.x * size.y * 4
	var buf := PackedByteArray()
	var k := i
	while true:
		_lock.lock()
		var quit := _quit
		var ahead := k - _due
		_lock.unlock()
		if quit:
			break
		if ahead > AHEAD:
			OS.delay_msec(5)
			continue
		var got := pipe.get_buffer(need - buf.size())
		if got.is_empty():
			if pipe.eof_reached() or pipe.get_error() != OK:
				break
			OS.delay_msec(2)
			continue
		buf.append_array(got)
		if buf.size() < need:
			continue
		var img := Image.create_from_data(size.x, size.y, false, Image.FORMAT_RGBA8, buf)
		buf = PackedByteArray()
		_lock.lock()
		_frames[k] = img
		_hi = k
		_lock.unlock()
		k += 1


## Frame [param i] if it is decoded (those before it dropped), else null.
func _take(i: int) -> Image:
	_lock.lock()
	var img: Image = _frames.get(i)
	if img != null:
		for key in _frames.keys():
			if int(key) < i:
				_frames.erase(key)
		_from = i
	_lock.unlock()
	return img


func _end_decoder() -> void:
	_lock.lock()
	_quit = true
	_lock.unlock()
	if _pid > 0:
		Subprocess.stop(_pid)
		_pid = -1
	if _thread != null:
		_thread.wait_to_finish()
		_thread = null


# --- the sound -----------------------------------------------------------------------------------------------------------

## The sound loaded: on a worker live (taken once it lands), here when [param wait].
func _load_sound(wait: bool) -> void:
	if _loading < 0 and _loaded.is_empty():
		var box := _loaded
		var path := sound
		_loading = WorkerThreadPool.add_task(func() -> void: box.append(AudioStreamWAV.load_from_file(path)))
	if _loading >= 0 and (wait or WorkerThreadPool.is_task_completed(_loading)):
		WorkerThreadPool.wait_for_task_completion(_loading)
		_loading = -1
	if not _loaded.is_empty():
		_stream = _loaded[0] as AudioStreamWAV
		_loaded.clear()
		if _stream == null:
			push_warning("ghost: the film's sound %s could not be read" % sound)
			sound = ""
