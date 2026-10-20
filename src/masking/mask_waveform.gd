extends RefCounted
class_name MaskWaveform

## MaskWaveform - the clip's sound drawn and measured, a part of [MaskEditor]: the timeline's
## waveform strip rendered once from the prepared audio ([method ensure],
## [method load_strip]), re-rendered crisp over the visible window under zoom
## ([method poll_hi]), and the sound's envelope read off the same image ([method env_at]) -
## what the umbra and the clown's paint breathe with.
##
## WHAT IT IS HANDED is written out: every `editor.` below is something it reads of the editor (the
## session, the timeline it draws on, the waveform's own process and path).
##
## Hi-res waveform window (see poll_hi): the base strip is one
## 4096px showwavespic over the WHOLE clip - ~4px/s on a long video, mush when
## the timeline is zoomed well in. When the on-screen pixels-per-second
## outresolves the base, the VISIBLE window (padded) is re-rendered at the
## same recipe on an audio slice, async and debounced, and the timeline draws
## it over the base for that span. Progressive: the base shows (soft) until
## the crisp slice lands.

## The [MaskEditor] this is a part of: everything read through it is something this part
## is handed, and the list of them is what it depends on.
var editor: MaskEditor

const _WAVEHI_PATH := "user://wave_hi.png"
var _wavehi_span := Vector2.ZERO   # [start, end] seconds the in-flight/loaded render covers
var _wavehi_want := Vector2.ZERO   # latest desired window - the debounce reference
var _wavehi_settle := 0.0          # seconds the desired window has held still
var _audio_env := PackedFloat32Array()   # per-column amplitude from the waveform image (resonance)

# --- the waveform, and the sound's envelope read off it ---------------------------------------

## timeline just draws nothing until _process() notices the PNG exists.
func ensure() -> void:
	# "waveform_sqrt": the filename carries the rendering recipe, so clips whose
	# cache predates a recipe change regenerate instead of loading the stale look.
	# sqrt scaling lifts small amplitudes into visibility - a linear plot of
	# ordinary speech/music sat near the axis and was barely visible on the strip.
	# 4096px wide so it still resolves when the timeline is zoomed well in.
	editor._waveform_path = editor.session.audio_path.get_base_dir().path_join("waveform_sqrt.png")
	var abs_wave := ProjectSettings.globalize_path(editor._waveform_path)
	if FileAccess.file_exists(abs_wave):
		load_strip(abs_wave)
		return
	editor._waveform_pid = Subprocess.start("ffmpeg", args_for(abs_wave), "waveform")


func args_for(abs_out: String) -> PackedStringArray:
	return PackedStringArray([
		"-y", "-loglevel", "error", "-i", ProjectSettings.globalize_path(editor.session.audio_path),
		"-filter_complex", "showwavespic=s=4096x160:colors=white:scale=sqrt",
		"-frames:v", "1", abs_out])


## Load the waveform image once and derive BOTH consumers from it: the timeline's
## strip texture, and the resonance envelope (per-column occupancy = amplitude).
## One file, one recipe - so the wisps breathe with exactly the wave the user sees
## on the strip, and live/export read identical values (file-deterministic; no
## real-time analyzer to drift between the two).
func load_strip(abs_path: String) -> void:
	var img := Image.load_from_file(abs_path)
	if img == null:
		return
	if editor._timeline != null:
		editor._timeline.waveform_texture = ImageTexture.create_from_image(img)
	var w := img.get_width()
	var h := img.get_height()
	_audio_env = PackedFloat32Array()
	_audio_env.resize(w)
	for x in w:
		var count := 0
		for y in range(0, h, 2):    # every 2nd row - envelope precision, half the cost
			if img.get_pixel(x, y).a > 0.1:
				count += 1
		# showwavespic draws a symmetric column; its filled fraction IS the (sqrt-
		# scaled) amplitude. 0.9 headroom so full-scale audio still reaches ~1.0.
		_audio_env[x] = clampf(float(count) / (float(h) * 0.5 * 0.9), 0.0, 1.0)


## Keep the timeline's waveform crisp under zoom. Every frame: harvest a
## finished slice render, then decide whether the current view needs a new
## one - only when the view outresolves the base strip, only after the view
## has held still a beat (never mid-drag), and only one ffmpeg at a time.
## Deliberately regenerates on demand instead of pre-baking LODs: the slice
## render is a sub-second ffmpeg pass over a PCM window, and most sessions
## never zoom past the base strip at all.
func poll_hi(dt: float) -> void:
	if editor.session == null or editor._timeline == null or editor._tview == null \
			or editor.session.duration <= 0.0 or editor._waveform_path.is_empty():
		return
	if editor._wavehi_pid > 0 and not Subprocess.alive(editor._wavehi_pid):
		editor._wavehi_pid = -1
		var img := Image.load_from_file(ProjectSettings.globalize_path(_WAVEHI_PATH))
		if img != null:
			editor._timeline.wavehi_texture = ImageTexture.create_from_image(img)
			editor._timeline.wavehi_span = _wavehi_span
			editor._timeline.queue_redraw()
	var span := editor._tview.visible_span()
	if span <= 0.0 or editor._timeline.size.x <= 0.0:
		return
	var base_pps := 4096.0 / editor.session.duration
	var pps := editor._timeline.size.x / span
	if pps <= base_pps * 1.4:
		return   # the base strip still resolves this zoom
	var pad := span * 0.5
	var want := Vector2(
		clampf(editor._tview.view_start - pad, 0.0, editor.session.duration),
		clampf(editor._tview.view_start + span + pad, 0.0, editor.session.duration))
	# Already covered at sufficient resolution? (The loaded slice may be wider
	# than the view - panning inside it costs nothing.)
	var cur: Vector2 = editor._timeline.wavehi_span
	if cur.y > cur.x and cur.x <= editor._tview.view_start + 0.001 \
			and cur.y >= editor._tview.view_start + span - 0.001 \
			and 4096.0 / (cur.y - cur.x) >= pps * 0.9:
		_wavehi_settle = 0.0
		return
	# Debounce: the desired window must hold still before ffmpeg fires, so a
	# zoom gesture spawns one render at its end, not one per wheel tick.
	if absf(want.x - _wavehi_want.x) > span * 0.05 or absf(want.y - _wavehi_want.y) > span * 0.05:
		_wavehi_want = want
		_wavehi_settle = 0.0
		return
	_wavehi_settle += dt
	if _wavehi_settle < 0.35 or editor._wavehi_pid > 0:
		return
	_wavehi_settle = 0.0
	_wavehi_span = want
	# -ss/-t BEFORE -i: input seeking on PCM is sample-exact and skips the
	# decode of everything outside the window.
	editor._wavehi_pid = Subprocess.start("ffmpeg", PackedStringArray([
		"-y", "-loglevel", "error",
		"-ss", str(want.x), "-t", str(want.y - want.x),
		"-i", ProjectSettings.globalize_path(editor.session.audio_path),
		"-filter_complex", "showwavespic=s=4096x160:colors=white:scale=sqrt",
		"-frames:v", "1", ProjectSettings.globalize_path(_WAVEHI_PATH)]))


## The audio envelope at clip-time `t` (0 when unavailable), lightly smoothed so
## the wisps swell rather than flicker frame-to-frame.
func env_at(t: float) -> float:
	if _audio_env.is_empty() or editor.session == null or editor.session.duration <= 0.0:
		return 0.0
	var n := _audio_env.size()
	var i := clampi(int(t / editor.session.duration * float(n)), 1, n - 2)
	return (_audio_env[i - 1] + _audio_env[i] + _audio_env[i + 1]) / 3.0
