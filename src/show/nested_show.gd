extends Node
class_name NestedShow

## NestedShow - another note's show played inside this one, live (a Dispatch desk's terminal, `play (terminal): NOTE`): its own
## Director ([member Director.nested]) walking that note's seed's scenes, or its storyboard, in that note's medium, drawn into a
## viewport of its own with a world of its own - as the comic draws scenes into its panels - and hearing that note's song
## ([member Spectrum.nested]: its baked frames read on the host's clock, its sound in the room), its words over the whole frame of the
## show it plays in (its song's sidecar, in its own Look's way of showing them - the credits where it names none). Nothing is rendered
## ahead: what the note is now is what plays.
##
## It is handed what the host found of the note (`{song, stream, frames, storyboard, medium, reveal, secs}`: its song's file and the
## song loaded, that song's bake, its storyboard in its loaded form or {}, its medium's key, how its words are shown, its length -
## [method prepared]). The host moves its clock ([method play_at]) and shows its
## picture ([method texture]); the clock gone back past where it was starts it again from there, and a jump forward is the
## Director's own seek, as the session's is.

## The size it is drawn at: a 4:3 screen's.
const SIZE := Vector2i(960, 720)
const _ShowScript := preload("res://src/show/director.gd")
const _SongScript := preload("res://src/audio/spectrum.gd")
## How far back the clock may go before the show starts again from there (s), and how many frames its host may not ask for it
## before its song falls silent.
const BACK := 0.5
const QUIET_AFTER := 3

var _note := {}
var _vp: SubViewport = null
var _song: _SongScript = null
var _show: _ShowScript = null
var _medium: Medium = null
var _subs: Subtitles = null
var _at := -INF                   # the clock as last stepped to
var _asked := 0                   # the frame its host last asked for it ([method play_at])


## The note [param note] (`{song, stream, frames, storyboard, medium, secs}`, `stream` its song loaded), to be played.
func _init(note: Dictionary) -> void:
	name = "Nested show"
	_note = note


## [param note] (what was found of it) with its song loaded (`stream`) and its bake read (`frames`): slow - a worker's, or a render's
## own.
static func prepared(note: Dictionary) -> Dictionary:
	var out := note.duplicate()
	var path := String(note.get("song", ""))
	var stream: AudioStream = null
	match path.get_extension().to_lower():
		"wav":
			stream = AudioStreamWAV.load_from_file(path)
		"mp3":
			stream = AudioStreamMP3.load_from_file(path)
		"ogg":
			stream = AudioStreamOggVorbis.load_from_file(path)
	out["stream"] = stream
	out["frames"] = SpectrumBake.load_cache(String(note.get("bake", "")), AudioFeatures.BAND_COUNT)
	if float(out.get("secs", 0.0)) <= 0.0 and stream != null:
		out["secs"] = stream.get_length()
	return out


## Its picture: what its viewport draws (null before it is begun).
func texture() -> Texture2D:
	return _vp.get_texture() if _vp != null else null


## How long it plays (s).
func length() -> float:
	return float(_note.get("secs", 0.0))


## Its show at [param t] seconds in, a frame of [param dt] on: begun where it is not, started again where the clock went back,
## drawn while [param shown]; its sound heard while [param heard] (held while [param held]).
func play_at(t: float, dt: float, shown: bool, heard: bool, held: bool) -> void:
	_asked = Engine.get_process_frames()
	if _show == null or t < _at - BACK:
		_begin()
	if _vp != null:
		_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS if shown else SubViewport.UPDATE_DISABLED
	_song.follow(t, heard, held)
	if held or (shown and is_equal_approx(t, _at)):
		return
	_song.virtual_clock = maxf(t, 0.0)
	_song._process(dt)
	_show.step(dt)
	_at = t


## Its song, its show and its medium let go.
func stop() -> void:
	_end()


func _exit_tree() -> void:
	_end()


## Its song falls silent once its host stops asking for it (a show stopped under it, its host gone quiet): never heard on its own.
func _process(_delta: float) -> void:
	if _song != null and Engine.get_process_frames() - _asked > QUIET_AFTER:
		_song.follow(0.0, false, false)


# --- inside ------------------------------------------------------------------------------------------------------------

## A show begun from nothing: the viewport, the song heard from its bake, the Director with the note's medium (its storyboard,
## where it keeps one) attached to it - the first scene made there.
func _begin() -> void:
	_end()
	_vp = SubViewport.new()
	_vp.name = "Screen"
	_vp.size = SIZE
	_vp.own_world_3d = true
	_vp.transparent_bg = false
	_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_vp)
	_song = _SongScript.new()
	_song.name = "Song"
	_song.nested = true
	_song.set_process(false)
	add_child(_song)
	_song.hear_baked(String(_note.get("song", "")), _note.get("stream") as AudioStream, _note.get("frames", []))
	_show = _ShowScript.new()
	_show.name = "Director"
	_show.nested = true
	_show.song = _song
	_show.set_process(false)
	_show.intro_hold = 0.0
	_show.outro_hold = 0.0
	var key := String(_note.get("medium", "auto"))
	_show.medium = key if Medium.REGISTRY.has(key) and Medium.mode_of(key).is_empty() else "full"
	add_child(_show)
	var board: Dictionary = _note.get("storyboard", {}) if _note.get("storyboard") is Dictionary else {}
	if not board.is_empty():
		_show.load_board(board, "")
	_medium = Medium.make(_show.medium)
	_medium.mount(_vp)
	_show.attach(_vp, _medium)
	_at = -INF
	# its words, over the whole frame of the show it is played in (never its small screen), on its own clock
	var side := Subtitles.sidecar_for(String(_note.get("song", "")))
	if not side.is_empty():
		_subs = Subtitles.new()
		_subs.name = "Its words"
		if _subs.load_sidecar(side):
			var song := _song
			_subs.clock = func() -> float: return song.virtual_clock if is_instance_valid(song) else 0.0
			_subs.song = _song
			_subs.reveal = String(_note.get("reveal", "credits"))
			add_child(_subs)
		else:
			_subs.free()
			_subs = null


func _end() -> void:
	if _subs != null and is_instance_valid(_subs):
		_subs.queue_free()
	_subs = null
	if _show != null and is_instance_valid(_show):
		_show.detach()
		_show.queue_free()
	_show = null
	if _medium != null and is_instance_valid(_medium):
		_medium.queue_free()
	_medium = null
	if _song != null and is_instance_valid(_song):
		_song.follow(0.0, false, false)
		_song.queue_free()
	_song = null
	if _vp != null and is_instance_valid(_vp):
		_vp.queue_free()
	_vp = null
	_at = -INF
