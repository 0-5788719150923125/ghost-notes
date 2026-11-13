extends Node

## Spectrum - the audio front end (autoload).
##
## Owns the [AudioStreamPlayer] and the [AudioEffectSpectrumAnalyzer] on the Master bus. Every frame it
## samples the analyzer across log-spaced bands, packs the result into a typed [AudioFeatures] on
## [member current], and owns the session clock. Scenes read [member current]; they never see the
## analyzer.
##
## Two backends: the live analyzer (default) and a baked timeline ([SpectrumBake], `--use-bake`) read
## from pre-computed frames for deterministic Movie Maker exports.

## Number of log-spaced bands in [member AudioFeatures.bands].
const BAND_COUNT := AudioFeatures.BAND_COUNT
const FREQ_MIN := 30.0
const FREQ_MAX := 16000.0

## dB window mapped onto 0..1. Magnitudes quieter than -DB_FLOOR read as 0.
const DB_FLOOR := 60.0

## Frames per second the offline bake is sampled at (must match bake_runner.gd).
const BAKE_FPS := 30
const Bake := preload("res://src/audio/bake.gd")

## Named-band frequency splits (Hz), low edge inclusive.
const NAMED := {
	"bass": [30.0, 150.0],
	"low_mid": [150.0, 500.0],
	"mid": [500.0, 2000.0],
	"high": [2000.0, 6000.0],
	"treble": [6000.0, 16000.0],
}

## The latest frame. Read this from anywhere; it is replaced every frame.
var current: AudioFeatures = AudioFeatures.new()

## A stable hash of the loaded audio's path - scenes seed from this so the same
## song always renders the same video. 0 when nothing is loaded.
var song_hash: int = 0
## A clock supplied from outside, in seconds; negative means "use the audio player" (every normal
## session and every render). It lets the whole schedule be replayed with no audio device and no
## encoder. It is one branch in `_process`, so everything derived below it (energy, beat, tempo, flux,
## movement) runs unchanged. See tests/show/show_timeline_probe.gd.
var virtual_clock: float = -1.0
## The render clock: in an export, show time is counted from frames rather than asked of the audio
## player. True only in a render.
##
## Movie Maker writes one video frame per engine iteration with no device pacing anything, and
## `get_playback_position()` can stall and resume, which would freeze the output picture while the
## audio plays on. Under `--fixed-fps` a frame is exactly 1/fps of show time, so counting frames is
## the definition of the clock. A/V cannot drift under it: Movie Maker writes audio at the same fixed
## rate as frames. Live playback keeps asking the player, which is the authority on where the sound is.
var render_clock := false
var _render_t := 0.0
var _sig: HarmonicSignature = null       # rolling perceptual harmonic descriptor + content seed
var _sig_fast: HarmonicSignature = null  # short-memory twin for the Echo re-localizer: recognizing
                                         # that the audio moved (a loop seam) must not wait out the
                                         # seconds of context the seeding descriptor integrates

## Emitted when a loaded song reaches its end (not in idle mode). Manual loops, Auto stops at its start
## and stays in its note. Looping streams never end, so this never fires for them.
signal song_finished

var _player: AudioStreamPlayer
var _analyzer: AudioEffectSpectrumAnalyzerInstance
var _tap: AudioEffectCapture          # the LIVE_TAP recorder (see the const)
var _tap_ring := PackedFloat32Array()
var _tap_pos := 0
var _tap_filled := 0
## The bookend: held silence before the content and after it, so the opening words are not spoken
## behind a dark screen. [member lead_in] holds playback for that many seconds while the session clock
## runs; [member tail] keeps the session alive that long after the audio ends, before
## [signal song_finished] is emitted.
##
## [member current].time is one continuous timeline across the hold, playback and tail: `_hold` during
## the hold, `lead_in + playback_position` while playing, `lead_in + length + _tail_t` during the tail.
## The bookend fade, Echo's cursor, the subtitle time base and the exporter's progress all read it.
## Delaying `play()` instead would fade in twice. Silence is not written into the file because the
## session seed comes from the audio's fingerprint (padding would change the show and invalidate the
## bake cache), and auto mode's song belongs to the user.
var lead_in := 0.0
var tail := 0.0

## Whether the loaded audio already contains the bookend silence. Auto and manual play a song that
## must not be rewritten, so the hold is performed here at playback time. A reading renders its own
## take and writes the silence into the PCM, so the ambience pad swells during the intro and the
## analyzer hears it. When true the clock needs no offset and playback is not held, but [member
## lead_in] and [member tail] are still set because the fade windows read them.
var bookend_baked := false

## Seconds over which the audio is ramped in and out alongside the picture. Applied to the Master bus,
## not the player: the analyzer runs before the bus volume, so the ramp is heard and recorded without
## dimming what the scenes see.
var fade_audio := true

## The conductor (next/notes.md, "The transport"): whatever plays the show's audio when it is not a
## plain file (a live reading), and so whatever the transport's play, pause, stop and
## rail drive. One at a time, registered by its owner ([method conduct]), released by it ([method
## release_conductor]), and forgotten once the owner is freed.
##
## The hooks, each optional: `play`, `pause`, `stop` () -> void; `playing`, `can_play`, `can_stop` ()
## -> bool; `position`, `length` () -> float, seconds of content (a length of 0 is nothing to scrub
## yet); `seek` (float) -> void. With none registered, a loaded file is its own conductor.
var _conductor := {}
var _conductor_owner: WeakRef = null

## Pause stops all of show time: the player, the held lead-in and the tail. The Director, scenes,
## media and karaoke advance by this clock, so they stop with it.
var paused := false
## Waiting, not paused ([method set_waiting]): show time held where it is while something the picture
## draws catches up (a table's physics baked on a thread of its own, behind a live reading). The player
## and the bookends stop as for a pause; the transport still says playing; a pause and a wait are each
## let go on their own. who -> true.
var _waits := {}
## How far ahead each part that makes its picture ahead is ready ([method set_ready]): who -> seconds past now.
var _ready_of := {}

var _hold := 0.0                # counts up through the lead-in
var _held := false              # lead-in running: the player has NOT been started yet
var _tail_t := 0.0              # counts up through the tail
var _tailing := false           # audio has ended; running out the tail before signaling
var _bus_db := 0.0              # master trim we applied, so it can be put back exactly
var _last_time := 0.0           # last published clock, held when the player stops mid-session

var _has_audio := false
var _idle_time := 0.0
var _override_path := ""        # the note's song (main._begin_song); wins over CLI/default
var _loaded_path := ""          # the resolved path actually loaded (for re-launch/export)

# Baked backend: a pre-computed per-frame spectrum timeline (one PackedFloat32Array of BAND_COUNT per
# frame), used by the export render (--use-bake). Live sessions leave it off.
var _baked := false
var _baked_frames: Array = []

# Smoothing / beat state.
var _energy_avg := 0.0          # slow moving average, for onset comparison
var _beat := 0.0
var _onset_high := false        # tempo: were we above the onset threshold last frame (edge detect)
var _last_beat_t := -1.0        # tempo: playback time of the previous beat onset
var _beat_period := 0.5         # tempo: smoothed seconds between onsets (~120 BPM default)

# Spectral-flux / movement state (drives audio-triggered scene changes).
var _prev_bands := PackedFloat32Array()
var _flux_fast := 0.0           # short EMA of flux - the current "agitation"
var _flux_slow := 0.0           # long EMA - the passage's baseline

# Per-band smoothing (anti-jitter). Lerp factor toward the new value each frame.
const SMOOTH := 0.4
var _sm_bands := PackedFloat32Array()
var _sm_named := {}
var _band_lo := PackedFloat32Array()   # precomputed per-band edges
var _band_hi := PackedFloat32Array()


func _ready() -> void:
	_setup_analyzer()
	_precompute_bands()
	_player = AudioStreamPlayer.new()
	_player.bus = "Master"
	_player.finished.connect(_on_player_finished)
	add_child(_player)
	#Audio is loaded in begin(), when main decides (a direct boot, or a note with a song opens).


## Load the chosen audio and start playback. Called once the session begins: with the note's song, or
## with "" on a direct boot (falls back to --audio, then res://audio/song.wav). Safe to re-point.
func begin(path := "") -> void:
	paused = false
	if not path.is_empty():
		_override_path = path
	_load_audio()
	if _has_audio:
		#A render counts its own time (see `render_clock`); read here from the same flag the app uses.
		render_clock = OS.get_cmdline_user_args().has("--export")
		if render_clock:
			print("ghost: render clock - show time counted from frames, not the audio player")
		var bake_file := _arg_value("--bake-file")
		if not bake_file.is_empty():
			#Pre-built cache (the export render's normal path): load and start, no in-process baking.
			_baked_frames = Bake.load_cache(bake_file, BAND_COUNT)
			_baked = not _baked_frames.is_empty()
			if _baked:
				print("ghost: loaded bake file - %d frames" % _baked_frames.size())
			else:
				push_warning("ghost: bake file missing/empty: %s" % bake_file)
		elif OS.get_cmdline_user_args().has("--use-bake"):
			_bake()                              # direct-CLI fallback (bakes in-process)
		#A reading's take writes its own bookend into its PCM and records it in its sidecar. Believe the
		#file over the request, or a file that already opens with silence would be held twice.
		_adopt_baked_bookend()
		#The lead-in holds the first sample, not the session: the clock runs at once so scenes animate and
		#the picture fades up through the hold. _process starts playback when the hold is spent.
		_hold = 0.0
		_tail_t = 0.0
		_tailing = false
		_held = lead_in > 0.001 and not bookend_baked
		if not _held:
			_player.play()


# Pre-analyze the loaded song into a spectrum timeline (export render only). Blocks until done; Movie
# Maker only starts recording once it is ready. Cached per song.
func _bake() -> void:
	var cache := _bake_cache_path()
	_baked_frames = Bake.load_cache(cache, BAND_COUNT)
	if not _baked_frames.is_empty():
		print("ghost: loaded cached bake - %d frames" % _baked_frames.size())
	else:
		_baked_frames = Bake.bake(_loaded_path, BAKE_FPS, BAND_COUNT, FREQ_MIN, FREQ_MAX, DB_FLOOR)
		if not _baked_frames.is_empty():
			Bake.save_cache(cache, _baked_frames, BAND_COUNT)
			print("ghost: baked spectrum - %d frames (cached)" % _baked_frames.size())
	_baked = not _baked_frames.is_empty()
	if not _baked:
		push_warning("ghost: bake failed; the render will fall back to the live analyzer")


# Cache key: the song's path + byte size (so replacing the file invalidates it).
func _bake_cache_path() -> String:
	var p := _loaded_path
	if p.begins_with("res://") or p.begins_with("user://"):
		p = ProjectSettings.globalize_path(p)
	var sz := 0
	if FileAccess.file_exists(p):
		var fa := FileAccess.open(p, FileAccess.READ)
		if fa != null:
			sz = fa.get_length()
			fa.close()
	return "user://bake_%d.spec" % hash(p + "_" + str(sz))


## Generator ring size (seconds) for streamed sessions - see begin_stream().
const STREAM_BUFFER := 4.0

## Diagnostic: record the Master bus (everything the mixer hears) into a rolling ring, written to
## user://synth/live_tap.wav on quit, to tell whether an artifact is inside the mix or after it (audio
## driver / OS). Off by default; `--live-tap` arms it for one run without touching this constant.
const LIVE_TAP := false
const TAP_SECONDS := 120.0            # rolling window: the LAST two minutes

var _streaming := false


## Begin a streamed session: no file - the caller pushes PCM into the returned generator playback as it
## produces it ([VoiceStream]), and the analyzer bus hears it like a song. `fp` stands in for the file
## fingerprint as the session seed source (derived from the caller's own content, so the same input
## replays the same show). The audio path and length are unknown: the caller answers for them as it
## conducts.
func begin_stream(fp: int, sr: int) -> AudioStreamGeneratorPlayback:
	var held := paused
	stop()
	paused = held
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = sr
	gen.buffer_length = STREAM_BUFFER
	_player.stream = gen
	song_hash = fp
	_loaded_path = ""
	_streaming = true
	_has_audio = true
	#play() first, then the caller pushes its prebuffer in the same frame, so pushed sample N plays at
	#N / sr and timing maps cannot drift.
	_player.play()
	#...held where the session is paused: a reading sought to while paused begins its new stream paused (ReadingStream.seek_now)
	_player.stream_paused = paused
	return _player.get_stream_playback()


## True while the session is a streamed take (a reading said live).
func is_streaming() -> bool:
	return _streaming


## Did audio actually load for this session? An export render checks this: with no audio, song_finished
## cannot fire.
func has_audio() -> bool:
	return _has_audio


## Can this session be scrubbed at all? A file can be seeked; a generator cannot (nothing behind the
## playhead still exists), so the scrubber hides itself.
func seekable() -> bool:
	if not conductor().is_empty():
		return _hook("seek").is_valid() and scrub_length() > 0.0
	return _has_audio and not _streaming and _content_length() > 0.0


## Where the scrub bar should sit, and how long the thing is. A stream's player position resets on
## restart, so the session that owns the audio answers instead when it can (the conductor's `position`
## and `length`).
func scrub_position() -> float:
	var h := _hook("position")
	return float(h.call()) if h.is_valid() else current.time


func scrub_length() -> float:
	var h := _hook("length")
	return float(h.call()) if h.is_valid() else song_length()


## Move the playhead to [param t] on the session clock - the clock [member current].time runs on,
## bookend included, so a caller can hand back a position it read from there.
##
## This does not re-derive the visuals. Everything that reads the clock follows at once (the baked
## spectrum lookup, the karaoke, the bookend fade), but the [Director] is a simulation whose scene
## choice, hold schedule and RNG evolve from the events it has seen: after a seek the show carries on
## from the scene that is up. ([Echo] pulls it back toward the content by re-localizing against the
## harmonic signature, as a drift rather than a guarantee.)
func seek(t: float) -> void:
	var h := _hook("seek")
	if h.is_valid():
		h.call(t)
		return
	if not conductor().is_empty():
		return
	seek_file(t)


## The file's own seek, [param t] on the session clock: what [method seek] does where nothing conducts,
## and what a conductor playing a file of its own asks for ([method ReadingStream.seek]). Nothing for a stream.
func seek_file(t: float) -> void:
	if not _has_audio or _streaming or _content_length() <= 0.0:
		return
	var content := _content_length()
	var want := clampf(t, 0.0, lead_in + content + tail)
	_tailing = false
	_tail_t = 0.0
	if not bookend_baked and want < lead_in:
		#Landed inside the held silence: hold there rather than starting the audio early.
		_held = true
		_hold = want
		_player.stop()
		return
	_held = false
	var pos := clampf(want - _clock_offset(), 0.0, maxf(0.0, content - 0.05))
	if not _player.playing:
		_player.play(pos)
		#...a fresh playback, which the player does not hold where the session is paused - held again, set
		#both ways since the player skips a value it already has
		var hold := paused or not _waits.is_empty()
		_player.stream_paused = not hold
		_player.stream_paused = hold
	else:
		_player.seek(pos)


## A render begun [param t] seconds in (`--from`; [Stitch]): its frame-counted clock starts there and
## the take plays from there, so Movie Maker records only the stretch from [param t].
func render_from(t: float) -> void:
	_held = false
	_render_t = maxf(0.0, t - _clock_offset())
	if _player.playing:
		_player.seek(_render_t)
	else:
		_player.play(_render_t)


## Restart the loaded song from the top without touching session state (no reseed, no reload; the
## fingerprint and analyzers carry on). Manual mode loops with this; whether the visuals restart is the
## storyboard's own business (its `loop` / `tail` fields).
func replay() -> void:
	if _has_audio and _player != null and _player.stream != null:
		_player.play()


## Pause the show where it is - the player and the bookend clock together (see `paused`). A streaming
## caller finds no room to push more audio until it resumes.
func set_paused(on: bool) -> void:
	paused = on
	if _player != null:
		_player.stream_paused = on or not _waits.is_empty()


## Show time held for [param who] while [param on]: what the picture needs and has not got yet ([member
## _waits]). Never in a render, whose clock is its own.
func set_waiting(who: String, on: bool) -> void:
	if on == _waits.has(who) or (on and render_clock):
		return
	if on:
		_waits[who] = true
	else:
		_waits.erase(who)
	if _player != null:
		_player.stream_paused = paused or not _waits.is_empty()


## Whether show time is held for something that is catching up ([method set_waiting]).
func waiting() -> bool:
	return not _waits.is_empty()


## How far ahead [param who] is ready to draw (seconds past now - [method ShowFeed.ready_ahead]), said
## every frame by what makes its picture ahead; a negative figure takes it off.
func set_ready(who: String, seconds: float) -> void:
	if seconds < 0.0:
		_ready_of.erase(who)
	else:
		_ready_of[who] = seconds


## How far ahead the show is ready to play (seconds past the playhead): the least of what the conductor
## has made (its `ahead` hook) and what every part that draws ahead has ([method set_ready]); -1 when
## nothing says. The transport shows it as buffered.
func ready_ahead() -> float:
	var h := _hook("ahead")
	var said := false
	var least := INF
	if h.is_valid():
		var a := float(h.call())
		if a >= 0.0:
			said = true
			least = a
	for k in _ready_of:
		said = true
		least = minf(least, float(_ready_of[k]))
	return least if said else -1.0


## The panels' name for [method set_paused].
func set_stream_paused(on: bool) -> void:
	set_paused(on)


func stream_paused() -> bool:
	return paused


# --- the conductor and the transport (next/notes.md, "The transport") ---------------------

## Register [param owner] as what the transport drives, with [param hooks] (see `_conductor`). Replaces
## any other: there is one clock.
func conduct(owner: Object, hooks: Dictionary) -> void:
	_conductor_owner = weakref(owner)
	_conductor = hooks.duplicate()


## Let go, if [param owner] is the conductor; safe to call when it is not.
func release_conductor(owner: Object) -> void:
	if _conductor_owner != null and _conductor_owner.get_ref() == owner:
		_conductor_owner = null
		_conductor = {}


## The conductor's hooks, {} when none is registered or its owner has been freed (which releases it).
func conductor() -> Dictionary:
	if _conductor_owner != null and _conductor_owner.get_ref() == null:
		_conductor_owner = null
		_conductor = {}
	return _conductor


func _hook(name: String) -> Callable:
	var c: Variant = conductor().get(name)
	return c if c is Callable and (c as Callable).is_valid() else Callable()


## Is the show timed - is there anything for the transport to play? A conductor, or a loaded file or
## stream. An untimed note shows no transport.
func timed() -> bool:
	return not conductor().is_empty() or _has_audio


## Is the show playing right now (not paused, not stopped)?
func transport_playing() -> bool:
	var h := _hook("playing")
	if h.is_valid():
		return bool(h.call())
	if not conductor().is_empty():
		return false
	#Not `_player.playing` alone: setting stream_paused turns that false at once, the held bookends play
	#with the player stopped, and a wait is playing, held ([method set_waiting])
	return _has_audio and not paused and (_player.playing or _held or _tailing or not _waits.is_empty())


## Can Play do anything now? A reading with no voice loaded cannot start.
func transport_can_play() -> bool:
	var h := _hook("can_play")
	if h.is_valid():
		return bool(h.call())
	return not conductor().is_empty() or _has_audio


## Is there anything for Stop to end? A conductor says (`can_stop`), else: it is playing or has
## something on the rail. A loaded file can always go back to its start.
func transport_can_stop() -> bool:
	var h := _hook("can_stop")
	if h.is_valid():
		return bool(h.call())
	if not conductor().is_empty():
		return transport_playing() or scrub_length() > 0.0
	return _has_audio


func transport_play() -> void:
	var h := _hook("play")
	if h.is_valid():
		h.call()
		return
	if conductor().is_empty() and _has_audio:
		set_paused(false)


func transport_pause() -> void:
	var h := _hook("pause")
	if h.is_valid():
		h.call()
		return
	if conductor().is_empty() and _has_audio:
		set_paused(true)


## Stop: a conductor's own stop (a reading ends and hands the stage back); a file goes back to
## its start and waits there, paused.
func transport_stop() -> void:
	var h := _hook("stop")
	if h.is_valid():
		h.call()
		return
	if conductor().is_empty() and _has_audio:
		seek(0.0)
		set_paused(true)


func transport_toggle() -> void:
	if transport_playing():
		transport_pause()
	else:
		transport_play()


## Stop playback and reset to a clean, songless state, so the next begin() starts fresh.
func stop() -> void:
	paused = false
	_waits = {}
	if _player != null:
		_player.stream_paused = false
		_player.stop()
		_player.volume_db = 0.0      # a mid-fade session end must not mute the next
	_has_audio = false
	_idle_time = 0.0
	_last_time = 0.0
	_override_path = ""
	_streaming = false
	song_hash = 0
	current = AudioFeatures.new()
	#Put the master back where it was: the bookend trims a global bus, so a session that ended mid-fade
	#would hand the next one a quiet mixer.
	_held = false
	_tailing = false
	_hold = 0.0
	_tail_t = 0.0
	if absf(_bus_db) > 0.0001:
		_bus_db = 0.0
		AudioServer.set_bus_volume_db(0, 0.0)


func _on_player_finished() -> void:
	if not _has_audio:
		return
	#Run the tail out before telling anyone the song ended: the export quits on this signal (main.gd), so
	#the deferral is the outro. Movie Maker records the audio bus, so the held silence stays locked to
	#the picture.
	if tail > 0.001 and not bookend_baked and not _tailing:
		_tailing = true
		_tail_t = 0.0
		return
	song_finished.emit()


## Read the loaded take's sidecar and adopt the bookend it was rendered with, if any. A take that
## carries `bookend` was padded at render time and its word timings are already shifted, so this sets
## `bookend_baked` rather than reconciling two offsets.
func _adopt_baked_bookend() -> void:
	bookend_baked = false
	if _loaded_path.is_empty():
		return
	var side := _loaded_path.get_basename() + ".json"
	if not FileAccess.file_exists(side):
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(side))
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var bk = (parsed as Dictionary).get("bookend")
	if typeof(bk) != TYPE_DICTIONARY:
		return
	lead_in = maxf(0.0, float((bk as Dictionary).get("in", 0.0)))
	tail = maxf(0.0, float((bk as Dictionary).get("out", 0.0)))
	bookend_baked = lead_in > 0.001 or tail > 0.001


## How far the session clock runs ahead of the player's own position. Zero when the bookend is baked
## into the file.
func _clock_offset() -> float:
	return 0.0 if bookend_baked else lead_in


## The show time of a stream's first sample: pushed frame N is heard at this plus N / rate - where a
## sound made to go with the picture ([Soundscape]) starts its clock.
func stream_origin() -> float:
	return _clock_offset()


## The audio's own length, without the bookend - what the player is actually playing.
func _content_length() -> float:
	if _streaming:
		return 0.0
	if _has_audio and _player != null and _player.stream != null:
		return _player.stream.get_length()
	return 0.0


## Ramp the master bus in over the lead-in and out over the tail, so the sound arrives and leaves with
## the picture. Equal-power rather than linear: a linear ramp on a sustained bed dips audibly mid-way.
func _apply_bookend_gain(t: float) -> void:
	if not _has_audio:
		return
	var g := 1.0
	if lead_in > 0.001:
		g = minf(g, clampf(t / lead_in, 0.0, 1.0))
	if tail > 0.001:
		var total := song_length()
		if total > 0.0:
			g = minf(g, clampf((total - t) / tail, 0.0, 1.0))
	var want := -80.0 if g <= 0.0005 else linear_to_db(sqrt(g))
	if absf(want - _bus_db) < 0.05:
		return
	_bus_db = want
	AudioServer.set_bus_volume_db(0, want)


## The filesystem path of the song actually loaded (or "" if idle); the exporter re-passes it to the
## Movie Maker render.
func audio_path() -> String:
	return _loaded_path


## Length of the loaded song in seconds (0 when idle / unknown); the exporter compares it with the
## playback position ([member current].time) to know it is near the end.
func song_length() -> float:
	#The whole timeline, bookend included, because that is the clock `current.time` runs on: the fade,
	#Echo's arc roll and the exporter's percentage compare against it.
	var content := _content_length()
	if content <= 0.0:
		return 0.0                       # streaming and not yet measured: unknown
	if bookend_baked:
		return content                   # the file already spans the bookend
	return lead_in + content + tail


## The current perceptual harmonic descriptor (12 chroma + coarse shape, normalized), for smooth
## content-driven modulation of a scene's dynamics. Empty until the analyzer is up.
func harmonic_signature() -> PackedFloat32Array:
	return _sig.vector() if _sig != null else PackedFloat32Array()

## The fast descriptor (same shape, ~0.7 s of context instead of 2.5 s) for listeners that must notice
## a content change quickly, like the [Echo] re-localizer, at the cost of jitter.
func harmonic_signature_fast() -> PackedFloat32Array:
	return _sig_fast.vector() if _sig_fast != null else PackedFloat32Array()

## A coarse content seed (SimHash bucket) from the harmonics right now: the same for the same music
## even re-encoded or cut up. `bits` sets bucket width (fewer = wider, more robust). For discrete
## choices (which scene / behavior).
func harmonic_bucket(bits := 10) -> int:
	return _sig.bucket(bits) if _sig != null else 0

## The full content seed from the live harmonics.
func harmonic_seed() -> int:
	return _sig.seed() if _sig != null else 0


## A live harmonic-derived seed bias, meant to be XOR-mixed into any seed expression: it biases the
## existing seed (session identity, scene index, history stay) so the harmonics steer the sampled
## randomness. Read it at the moment a thing is instanced. Coarse and smoothed, so it survives
## re-encoding and a cut-out segment carries its own.
func seed_bias() -> int:
	if _sig == null:
		return 0
	return _sig.bucket(12) * 0x2545F4914F6CDD1D   # spread the coarse harmonic bucket across the bits


func _exit_tree() -> void:
	_write_tap()


## Dump the LIVE_TAP ring (oldest -> newest) as a WAV at the bus mix rate: the actual mixer output.
func _write_tap() -> void:
	if _tap == null or _tap_filled == 0:
		return
	var rate := int(AudioServer.get_mix_rate())
	var n := _tap_filled
	var start := (_tap_pos - n + _tap_ring.size()) % _tap_ring.size()
	var bytes := PackedByteArray()
	bytes.resize(n * 2)
	for i in n:
		var v := clampf(_tap_ring[(start + i) % _tap_ring.size()], -1.0, 1.0)
		bytes.encode_s16(i * 2, int(v * 32767.0))
	DirAccess.make_dir_recursive_absolute("user://synth")
	var f := FileAccess.open("user://synth/live_tap.wav", FileAccess.WRITE)
	f.store_buffer("RIFF".to_ascii_buffer())
	f.store_32(36 + bytes.size())
	f.store_buffer("WAVE".to_ascii_buffer())
	f.store_buffer("fmt ".to_ascii_buffer())
	f.store_32(16)
	f.store_16(1)
	f.store_16(1)
	f.store_32(rate)
	f.store_32(rate * 2)
	f.store_16(2)
	f.store_16(16)
	f.store_buffer("data".to_ascii_buffer())
	f.store_32(bytes.size())
	f.store_buffer(bytes)
	f.close()
	print("ghost: live tap written -> %s (%.1fs @ %d Hz)" % [
		ProjectSettings.globalize_path("user://synth/live_tap.wav"),
		float(n) / float(rate), rate])


# Install the analyzer on the Master bus and grab its instance.
func _setup_analyzer() -> void:
	var bus := AudioServer.get_bus_index("Master")
	var fx := AudioEffectSpectrumAnalyzer.new()
	fx.buffer_length = 0.1   # short window - tighter reaction to transients
	AudioServer.add_bus_effect(bus, fx)
	var idx := AudioServer.get_bus_effect_count(bus) - 1
	_analyzer = AudioServer.get_bus_effect_instance(bus, idx)
	if LIVE_TAP or OS.get_cmdline_user_args().has("--live-tap"):
		_tap = AudioEffectCapture.new()
		_tap.buffer_length = 0.5
		AudioServer.add_bus_effect(bus, _tap)
		_tap_ring.resize(int(TAP_SECONDS * AudioServer.get_mix_rate()))
		print("ghost: LIVE TAP armed - last %ds of the Master bus -> synth/live_tap.wav on quit (mix %d Hz, out latency %.1f ms, device '%s')"
			% [int(TAP_SECONDS), int(AudioServer.get_mix_rate()),
				AudioServer.get_output_latency() * 1000.0, AudioServer.get_output_device()])


# Log-spaced band edges, computed once.
func _precompute_bands() -> void:
	_band_lo.resize(BAND_COUNT)
	_band_hi.resize(BAND_COUNT)
	var ratio := FREQ_MAX / FREQ_MIN
	var centers := PackedFloat32Array()
	centers.resize(BAND_COUNT)
	for i in BAND_COUNT:
		_band_lo[i] = FREQ_MIN * pow(ratio, float(i) / float(BAND_COUNT))
		_band_hi[i] = FREQ_MIN * pow(ratio, float(i + 1) / float(BAND_COUNT))
		centers[i] = sqrt(_band_lo[i] * _band_hi[i])     # geometric center (log-spaced)
	_sig = HarmonicSignature.new(centers)
	_sig_fast = HarmonicSignature.new(centers, 0.7)


func _process(delta: float) -> void:
	# drain the LIVE_TAP capture into the rolling ring (mono-averaged)
	if _tap != null:
		while _tap.get_frames_available() > 0:
			var got := _tap.get_buffer(mini(_tap.get_frames_available(), 4096))
			if got.is_empty():
				break
			for v in got:
				_tap_ring[_tap_pos] = (v.x + v.y) * 0.5
				_tap_pos = (_tap_pos + 1) % _tap_ring.size()
			_tap_filled = mini(_tap_filled + got.size(), _tap_ring.size())

	var f := AudioFeatures.new()

	#--- the bookend clock (see lead_in / tail) ---
	#Held silence counts as session time so the picture can fade up through it, but the bands stay zero
	#(scenes idle and the Director holds one shot). A pause holds it where it is (see `paused`).
	if _held:
		if not paused and _waits.is_empty():
			_hold += delta
		if _hold >= lead_in:
			_player.play()
			_held = false
	elif _tailing:
		if not paused and _waits.is_empty():
			_tail_t += delta
		if _tail_t >= tail:
			_tailing = false
			song_finished.emit()

	if virtual_clock >= 0.0:
		#A clock from outside (see `virtual_clock`). Everything below runs as in a render. The held lead-in
		#and the tail are silence here too: bands fill only where the player would be playing.
		f.time = virtual_clock
		var pos := virtual_clock - _clock_offset()
		if pos >= 0.0 and pos < _content_length():
			if _baked:
				_fill_bands_baked(f)
			else:
				_fill_bands(f)
	elif _has_audio and _player.playing:
		#The render clock: accumulated fixed-fps time, not the player's position (see `render_clock`).
		if render_clock:
			_render_t += delta
			f.time = _clock_offset() + _render_t
		else:
			f.time = _clock_offset() + _player.get_playback_position()
		if _baked:
			_fill_bands_baked(f)
		else:
			_fill_bands(f)
	elif _held or _tailing:
		#Bookend silence: continuous with the playing branch above, only quiet.
		f.time = _hold if _held else lead_in + _content_length() + _tail_t
	elif _has_audio:
		#A loaded session never falls back to the idle clock: the player can stop while audio is loaded (past
		#the end, or a seek onto the last fraction of a second), and reverting to `_idle_time` would restart
		#the clock from zero. Hold the last position; the tail and the finish signal own what happens next.
		f.time = _last_time
	else:
		_idle_time += delta
		f.time = _idle_time
		# bands stay zero; scenes idle-animate on f.time
	_last_time = f.time
	if fade_audio:
		_apply_bookend_gain(f.time)

	# Overall energy: mean of the spectrum, lightly smoothed.
	var sum := 0.0
	for v in f.bands:
		sum += v
	var raw_energy := sum / float(max(1, f.bands.size()))
	f.energy = raw_energy

	# Beat: pulse when energy jumps above its slow average.
	_energy_avg = lerpf(_energy_avg, raw_energy, 0.08)
	var onset := raw_energy > _energy_avg * 1.4 + 0.02
	#Tempo: on the rising edge of an onset, measure the interval since the last one and fold it into a
	#smoothed beat period. Implausible gaps (~30..270 BPM) are rejected.
	if onset and not _onset_high:
		if _last_beat_t >= 0.0:
			var ibi := f.time - _last_beat_t
			if ibi > 0.22 and ibi < 2.0:
				_beat_period = lerpf(_beat_period, ibi, 0.2)
		_last_beat_t = f.time
	_onset_high = onset
	if onset:
		_beat = 1.0
	else:
		_beat = maxf(0.0, _beat - delta * 4.0)
	f.beat = _beat
	f.beat_period = _beat_period

	_compute_movement(f)
	current = f

	#Roll the perceptual harmonic descriptor and its content seed, so scenes can be seeded from the
	#harmonics rather than the file (HarmonicSignature, next/harmonic_seeding.md).
	if _sig != null:
		_sig.update(f.bands, f.bass + f.low_mid, f.mid, f.high + f.treble, f.flux, delta)
	if _sig_fast != null:
		_sig_fast.update(f.bands, f.bass + f.low_mid, f.mid, f.high + f.treble, f.flux, delta)


# Spectral flux plus a sliding-window movement score: flux is how much new frequency content arrived
# this frame; movement is the short-term flux against the passage's own baseline, so it spikes at
# section changes and stays low through a steady groove.
func _compute_movement(f: AudioFeatures) -> void:
	var flux := 0.0
	if _prev_bands.size() == f.bands.size() and f.bands.size() > 0:
		for i in f.bands.size():
			flux += maxf(0.0, f.bands[i] - _prev_bands[i])
		flux /= float(f.bands.size())
	_prev_bands = f.bands.duplicate()
	f.flux = flux

	_flux_fast = lerpf(_flux_fast, flux, 0.18)
	_flux_slow = lerpf(_flux_slow, flux, 0.012)
	# How far the recent agitation sits above the running baseline.
	var ratio := _flux_fast / (_flux_slow + 0.0008)
	f.movement = clampf((ratio - 1.3) * 0.7, 0.0, 1.0)


# Sample the analyzer into f.bands and the named fields, EMA-smoothed against the previous frame.
func _fill_bands(f: AudioFeatures) -> void:
	if _sm_bands.size() != BAND_COUNT:
		_sm_bands.resize(BAND_COUNT)
	f.bands.resize(BAND_COUNT)
	for i in BAND_COUNT:
		var raw := _band_energy(_band_lo[i], _band_hi[i])
		_sm_bands[i] = lerpf(_sm_bands[i], raw, SMOOTH)
		f.bands[i] = _sm_bands[i]
	f.bass = _smooth_named("bass", NAMED.bass)
	f.low_mid = _smooth_named("low_mid", NAMED.low_mid)
	f.mid = _smooth_named("mid", NAMED.mid)
	f.high = _smooth_named("high", NAMED.high)
	f.treble = _smooth_named("treble", NAMED.treble)


# Baked counterpart of _fill_bands: read the band frame at the current playback time and apply the
# same EMA smoothing. Named bands are aggregated from the 64 baked bands.
func _fill_bands_baked(f: AudioFeatures) -> void:
	if _sm_bands.size() != BAND_COUNT:
		_sm_bands.resize(BAND_COUNT)
	f.bands.resize(BAND_COUNT)
	#The bake is of the file, so it is indexed by the file's position: the session clock less the held
	#lead-in.
	var idx := clampi(int((f.time - _clock_offset()) * BAKE_FPS), 0, _baked_frames.size() - 1)
	var raw: PackedFloat32Array = _baked_frames[idx]
	for i in BAND_COUNT:
		_sm_bands[i] = lerpf(_sm_bands[i], raw[i], SMOOTH)
		f.bands[i] = _sm_bands[i]
	f.bass = _named_baked("bass", raw, NAMED.bass)
	f.low_mid = _named_baked("low_mid", raw, NAMED.low_mid)
	f.mid = _named_baked("mid", raw, NAMED.mid)
	f.high = _named_baked("high", raw, NAMED.high)
	f.treble = _named_baked("treble", raw, NAMED.treble)


# A named band averaged from the baked log bands over its frequency range, smoothed.
func _named_baked(key: String, raw: PackedFloat32Array, pair: Array) -> float:
	var ratio := FREQ_MAX / FREQ_MIN
	var b0 := clampi(int(BAND_COUNT * log(float(pair[0]) / FREQ_MIN) / log(ratio)), 0, BAND_COUNT - 1)
	var b1 := clampi(int(BAND_COUNT * log(float(pair[1]) / FREQ_MIN) / log(ratio)), 0, BAND_COUNT - 1)
	var s := 0.0
	for b in range(b0, b1 + 1):
		s += raw[b]
	var rawv := s / float(maxi(1, b1 - b0 + 1))
	var prev: float = _sm_named.get(key, 0.0)
	var v := lerpf(prev, rawv, SMOOTH)
	_sm_named[key] = v
	return v


# A named band, EMA-smoothed like the spectrum.
func _smooth_named(key: String, pair: Array) -> float:
	var raw := _band_energy(pair[0], pair[1])
	var prev: float = _sm_named.get(key, 0.0)
	var v := lerpf(prev, raw, SMOOTH)
	_sm_named[key] = v
	return v


# One band: magnitude over a frequency range, mapped from dB to 0..1.
func _band_energy(lo: float, hi: float) -> float:
	var mag := _analyzer.get_magnitude_for_frequency_range(
		lo, hi, AudioEffectSpectrumAnalyzerInstance.MAGNITUDE_MAX)
	var db := linear_to_db(mag.length())
	return clampf((db + DB_FLOOR) / DB_FLOOR, 0.0, 1.0)


# Resolve a stream from `--audio <path>` or res://audio/song.wav and load it.
func _load_audio() -> void:
	var path := _audio_path_from_args()
	var stream: AudioStream = null

	if not path.is_empty():
		stream = _load_external(path)
		if stream == null:
			push_warning("ghost: could not load audio at %s" % path)
	if stream == null and ResourceLoader.exists("res://audio/song.wav"):
		path = "res://audio/song.wav"
		stream = load(path)

	if stream != null:
		_player.stream = stream
		_has_audio = true
		song_hash = _fingerprint(path)
		_loaded_path = path
	else:
		print("ghost: no audio loaded - scenes will idle-animate.")


# A content fingerprint of the audio file, so the seed matches the same sound whatever the file's name
# or location. Samples up to ~768 KB from the start, middle and end plus the byte length. Falls back to
# the path hash if the bytes can't be read. (A perceptual signature that also matches re-encodes is
# planned; see next/roadmap.md.)
func _fingerprint(path: String) -> int:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return hash(path)
	var size := f.get_length()
	var chunk := 262144
	var acc := PackedByteArray()
	acc.append_array(f.get_buffer(chunk))                 # start
	if size > chunk * 2:
		f.seek(size / 2)
		acc.append_array(f.get_buffer(chunk))             # middle
	if size > chunk:
		f.seek(maxi(0, size - chunk))
		acc.append_array(f.get_buffer(chunk))             # end
	f.close()
	return hash(acc) ^ int(size * 0x9E3779B1)


# Value following a `--flag` in the user args, or "".
func _arg_value(flag: String) -> String:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == flag and i + 1 < args.size():
			return args[i + 1]
	return ""


func _audio_path_from_args() -> String:
	if not _override_path.is_empty():
		return _override_path
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--audio" and i + 1 < args.size():
			return args[i + 1]
	return ""


# External (non-res://) files via the runtime loaders, by extension.
func _load_external(path: String) -> AudioStream:
	var lower := path.to_lower()
	if lower.ends_with(".wav"):
		return AudioStreamWAV.load_from_file(path)
	if lower.ends_with(".mp3"):
		return AudioStreamMP3.load_from_file(path)
	if lower.ends_with(".ogg") or lower.ends_with(".oga"):
		return AudioStreamOggVorbis.load_from_file(path)
	if lower.ends_with(".flac"):
		return _load_flac(path)
	if ResourceLoader.exists(path):
		return load(path)
	return null


# Godot has no runtime FLAC loader, so transcode to a temp WAV with ffmpeg. Degrades gracefully while
# FFmpeg is not there yet.
func _load_flac(path: String) -> AudioStream:
	var tmp := ProjectSettings.globalize_path("user://ghost_flac.wav")
	var code := Deps.execute("ffmpeg", ["-y", "-loglevel", "error", "-i", path, tmp])
	if code == 0 and FileAccess.file_exists(tmp):
		return AudioStreamWAV.load_from_file(tmp)
	Provision.ensure("ffmpeg")
	push_warning("ghost: FLAC playback needs FFmpeg to decode %s - %s" % [path, Deps.hint("ffmpeg")])
	return null
