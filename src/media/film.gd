extends GhostScene
class_name FilmScene

## FilmScene - a panel of real footage, cut into the comic among the drawn ones.
##
## A [GhostScene] like any other: the comic casts it into a panel as it casts a spectrum ring, and
## the render target, the freeze and the camera know nothing about video.
##
## It plays a window, not a film: what exists on disk is [constant Films.WINDOW] seconds of the clip
## at a time, and this plays whichever window covers the position the show clock asks for, tracking
## where it is in the film while playing a file that starts at zero.
##
## Two players cross from one window to the next: when the playhead nears the end of a window the
## next is opened alongside, primed and swapped to. Windows overlap by [constant Films.LEAD]
## seconds so the outgoing player still has frames while the incoming one settles.
##
## A window is placed once when it opens and then plays; it is not re-seeked per frame (a decoder
## flush each time) but watched for drift, since a panel frozen while the camera looked elsewhere
## has a stopped clock while the show's kept running.
##
## Not in the Director's catalog (never minted by [Director.mint_scene]): there is nothing to show
## unless something was imported, and a scene that is sometimes absent would make the running order
## depend on the library. The comic casts it directly; see [ComicMedium._film_at].

## How far the clip may drift from the show clock, in seconds, before it is pulled back. Below
## this a correction (a seek lands on a keyframe) is more visible than a few frames of lag.
const DRIFT_TOLERANCE := 0.35

## Seconds of hold before the first drift correction: VideoStreamPlayer reports a stream_position
## of 0 for a frame or two after `play()`.
const SETTLE := 0.5

## How close to the end of a window the playhead gets before the next is opened alongside. Inside
## [constant Films.LEAD], so the swap happens while the outgoing window still has overlap to play.
const HANDOVER := 3.0

var clip: Dictionary = {}
## The show clock this panel opened at, and the clock it has been handed since. Passed in rather
## than read from Spectrum so an export render places the footage as the live session did.
var _show_t := 0.0
var _since_open := 0.0
## The window each player is playing, and the players themselves. `_next` is null except
## across a handover.
var _win := -1
var _next_win := -1
var _player: VideoStreamPlayer = null
var _next: VideoStreamPlayer = null
var _tint := Color(1, 1, 1, 1)


## Give this scene its footage. Called before the scene enters the tree: the first window is
## opened in _ready.
func set_clip(c: Dictionary, show_time: float) -> void:
	clip = c
	_show_t = show_time


func build_params(_rng: RandomNumberGenerator) -> Dictionary:
	render_kind = "canvas"
	# The page's ink is warm and the paper is not white: a light warm multiply seats the footage.
	_tint = Color(1.0, 0.985, 0.955, 1.0)
	return {}


func _ready() -> void:
	super._ready()
	if clip.is_empty():
		return
	_open(Films.window_index(Films.position_at(clip, _show_t)))


## Where the show says this panel should be, in seconds into the film.
func film_position() -> float:
	return Films.position_at(clip, _show_t)


## Build a player for one window and start it at the right place inside it.
func _open(index: int) -> void:
	if not Films.window_ready(clip, index):
		return
	_win = index
	_player = _make_player(index)
	# Ask for the next window now, not near the boundary: cutting runs at about twice realtime on
	# hard footage. The show clock only moves forward, so it is the window the next film panel wants.
	Films.request_window(clip, Films.next_window(clip, index))
	# Deferred: VideoStreamPlayer refuses a stream_position set on the frame it starts playing.
	call_deferred("_seek_current")


func _make_player(index: int) -> VideoStreamPlayer:
	var p := VideoStreamPlayer.new()
	p.stream = load(ProjectSettings.globalize_path(Films.window_path(clip, index)))
	p.loop = false            # a window is a slice of a film, not the film; see _advance
	p.volume = 0.0            # the show has a soundtrack; a panel does not
	p.expand = true
	# Zero-sized and invisible: the player is a decoder; its texture is drawn in _draw through the
	# scene's own view transform.
	p.size = Vector2.ZERO
	p.visible = false
	add_child(p)
	p.play()
	return p


func _seek_current() -> void:
	if _player == null or not is_instance_valid(_player) or not _player.is_playing():
		return
	_player.stream_position = Films.window_local(film_position())


func update(f: AudioFeatures, delta: float) -> void:
	_show_t += delta
	_since_open += delta
	# Someone with a frame has to notice a finished cut; while a panel is live this is it.
	Films.pump()
	_advance()
	# The audio reaches the picture faintly, as a little breathing on the tint rather than a shake.
	if f != null:
		var e := clampf(float(f.energy), 0.0, 1.0)
		_tint = Color(1.0, 0.985, 0.955).lerp(Color(1.0, 1.0, 1.0), e * 0.6)
	queue_redraw()


## Keep the right window playing at the right place: open a window if the panel started without
## one, hand over at a boundary, and correct drift within a window.
func _advance() -> void:
	var pos := film_position()
	var want := Films.window_index(pos)
	# The clip loops, so the window after the last is the first.
	if not Films.window_exists(clip, want):
		want = 0
		pos = 0.0
	# Started cold: a panel that outlived its clip's cache; ask, and open when it lands.
	if _player == null or not is_instance_valid(_player):
		Films.request_window(clip, want)
		if Films.window_ready(clip, want):
			_since_open = 0.0
			_open(want)
		return
	# Handover: open the next window alongside once the playhead is inside the overlap, then swap
	# when the position belongs to it.
	if want != _win:
		if _next != null and is_instance_valid(_next) and _next_win == want:
			_swap()
		else:
			_prime(want)          # the handover was missed - open it late rather than never
			# No next window on disk yet: hold on the outgoing window's overlap rather than
			# showing paper; it runs out after Films.LEAD.
			return
	elif Films.window_local(pos) > Films.WINDOW - HANDOVER:
		# The cut was started when this window opened; this only spins the decoder up.
		_prime(Films.next_window(clip, _win))
	if _since_open > SETTLE:
		# Where it should be against where it is: the gap opens whenever the panel was frozen
		# (the show's clock ran on, the decoder's did not).
		var local := Films.window_local(pos)
		if absf(local - float(_player.stream_position)) > DRIFT_TOLERANCE:
			_player.stream_position = local


## Have the next window decoding alongside, ready to be swapped to.
func _prime(index: int) -> void:
	if _next != null and is_instance_valid(_next) and _next_win == index:
		return
	if not Films.request_window(clip, index):
		return
	if _next != null and is_instance_valid(_next):
		_next.queue_free()
	_next_win = index
	_next = _make_player(index)


func _swap() -> void:
	if _player != null and is_instance_valid(_player):
		_player.queue_free()
	_player = _next
	_win = _next_win
	_next = null
	_next_win = -1
	_since_open = 0.0
	call_deferred("_seek_current")


## Never exits on its own. The Director's clock cuts away from it like any other panel.
func finished() -> bool:
	return false


## The panel rectangle and nothing else.
##
## No [method GhostScene.begin_draw] and not [method GhostScene.view_half_px]: that is a deliberate
## overdraw bound (a 1.06 margin, measured about the origin so a pan inflates it) which suits a
## generated scene that must cover the frame, but footage has edges and every pixel of overdraw is
## cropped off them. The film is drawn in the panel's own coordinates: the viewport rect, top-left
## origin, no camera transform (the comic's camera already flies over the page).
func _draw() -> void:
	var panel := size
	var tex: Texture2D = null
	if _player != null and is_instance_valid(_player):
		tex = _player.get_video_texture()
	if tex == null or tex.get_size().x <= 0.0:
		# A frame or two before the first decode, or forever if the file went bad: paper, not black.
		draw_rect(Rect2(Vector2.ZERO, panel), Color(0.88, 0.865, 0.83), true)
		return
	# Cover, on whichever axis needs the least: the footage fills the panel and overflows on one
	# axis, symmetrically, by the smallest amount that covers (no black bars inside a comic frame).
	var src := tex.get_size()
	var k := maxf(panel.x / src.x, panel.y / src.y)
	var dst := src * k
	draw_texture_rect(tex, Rect2((panel - dst) * 0.5, dst), false, _tint)
