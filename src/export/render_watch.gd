extends RefCounted
class_name RenderWatch

## RenderWatch - a render stops itself once its frames are no longer being drawn, and leaves the exporter the reason.
##
## Movie Maker writes one frame every engine iteration, drawn or not. Where the window cannot draw, the frame written is a copy
## of the last one drawn while the audio and the show clock go on, and nothing after can tell: the AVI is whole, the MP4 the
## right length, ffmpeg content. Godot says so only in its closing report, whose frame count is frames DRAWN. Under X11 (Xvfb
## included) Godot draws every iteration even with its window marked hidden; it is Wayland that stops: a compositor stops
## asking a window nobody can see to repaint (the screen locked, the window covered, minimized or on another desktop), and
## Godot suspends it.
##
## The True Tarot export of 2026-11-23 (the Intel laptop, its render fallen back from Xvfb to a window on the desktop, the
## screen then locked): 3,468 frames drawn of 53,811 written, everything after 0:56 a still, saved as a success.
##
## [method step] is fed `Engine.get_frames_drawn()` once a frame from `_process`, which runs once an iteration as Movie Maker
## writes once an iteration: an iteration that drew nothing shows as a count that has not moved by the next call. Past
## [constant LIMIT] seconds of those in all, what the render would go on writing is not the show, and it stops.
##
## No other script is named here: the export probe copies this file into a project of its own
## (tests/export/export_follow_probe.gd).

## Seconds of video written undrawn, in all, before the render is stopped: room for an odd frame, while a frozen render is
## stopped within a moment of freezing.
const LIMIT := 0.25

## Seconds of video written undrawn so far.
var missed := 0.0
## The show time of the first of them, -1 while there is none.
var first_at := -1.0
var _last := -1


## One iteration: [param drawn] is `Engine.get_frames_drawn()`, [param dt] the frame's step (1/fps under `--fixed-fps`) and
## [param t] the show time. True once: on the frame the limit is crossed.
func step(drawn: int, dt: float, t: float) -> bool:
	var was := _last
	_last = drawn
	if was < 0 or drawn != was:
		return false
	# the iteration that did not draw was the one before this
	if first_at < 0.0:
		first_at = maxf(t - dt, 0.0)
	var before := missed
	missed += dt
	# (fifteen sixtieths add up to a hair under a quarter: the limit is met to within a microsecond)
	return before < LIMIT - 1e-6 and missed >= LIMIT - 1e-6


## Leave [param text] at [param path] for the exporter (the render's `--fault-file`): written whole, then renamed into place,
## so a reader never catches half of it.
static func write_fault(path: String, text: String) -> void:
	if path.is_empty():
		return
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(text)
	f.close()
	DirAccess.rename_absolute(tmp, path)


## What a render left at [param path], "" when it left nothing.
static func read_fault(path: String) -> String:
	if path.is_empty() or not FileAccess.file_exists(path):
		return ""
	return FileAccess.get_file_as_string(path).strip_edges()


## Clear [param path] before a render starts, so an earlier render's reason is never read as this one's.
static func clear_fault(path: String) -> void:
	if not path.is_empty() and FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
