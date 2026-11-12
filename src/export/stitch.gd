extends RefCounted
class_name Stitch

## Stitch - a stretch of an export rendered again and put back in its place (next/editing.md step 13; next/cloud_render.md's
## `--from` and stitch, on this machine): a late fix renders its stretch, not the whole video.
##
## An export's keyframes stand every [constant GOP_S] seconds exactly (the encoder's keyframe interval and its least are both
## that, see [method Exporter._start_transcode]), so a stretch widened to those seconds ([method span]) begins and ends where
## the old video's pictures stand on their own. The stretch is rendered there (`--from`/`--until`) and encoded with the same
## settings; the old video's head and tail are copied, never decoded, the three joined by ffmpeg's concat demuxer, and the old
## video's whole audio laid under them as one track. What it replaces is kept beside it ([method kept_name]). Every step is
## one ffmpeg run whose argv is built here, so a gate holds them.

## An export's keyframe interval, seconds: what the encoder is told ([method Exporter._start_transcode]).
const GOP_S := 2.0


## The stretch as rendered: [param t0] to [param t1] (seconds of the video) widened to the keyframes about them, within
## [param length]. Vector2(start, end).
static func span(t0: float, t1: float, length: float) -> Vector2:
	var a := floorf(maxf(t0, 0.0) / GOP_S) * GOP_S
	var b := minf(ceilf(maxf(t1, t0) / GOP_S) * GOP_S, length)
	return Vector2(a, maxf(b, minf(a + GOP_S, length)))


## The old video's pictures before [param t0], copied: [] when there are none. Counted in pictures ([param fps] a second),
## never cut by time: copying to `-t` keeps the next keyframe and a picture after it. An export's keyframe groups are closed,
## so the first [param t0] x fps in decoding order are exactly the pictures before it.
static func head_args(old: String, t0: float, fps: float, out: String) -> PackedStringArray:
	if t0 <= 0.0:
		return PackedStringArray()
	return PackedStringArray(["-y", "-loglevel", "error", "-i", old, "-frames:v", str(roundi(t0 * fps)), "-map", "0:v", "-c", "copy", out])


## The old video's pictures from [param t1] on, copied - [param t1] a keyframe, so the copy starts on it: [] at the end.
static func tail_args(old: String, t1: float, length: float, out: String) -> PackedStringArray:
	if t1 >= length - 1e-3:
		return PackedStringArray()
	return PackedStringArray(["-y", "-loglevel", "error", "-ss", "%.3f" % t1, "-i", old, "-map", "0:v", "-c", "copy", out])


## The stretch's pictures alone, copied (its own sound is the old one's, laid under the whole).
static func picture_args(stretch: String, out: String) -> PackedStringArray:
	return PackedStringArray(["-y", "-loglevel", "error", "-i", stretch, "-map", "0:v", "-c", "copy", out])


## What the concat demuxer reads: each part, in order.
static func list_text(parts: Array) -> String:
	var lines := PackedStringArray()
	for p in parts:
		lines.append("file '%s'" % String(p).replace("'", "'\\''"))
	return "\n".join(lines) + "\n"


## The parts joined (the list at [param list]) under [param old]'s whole sound, copied, into [param out].
static func join_args(list: String, old: String, out: String) -> PackedStringArray:
	return PackedStringArray(["-y", "-loglevel", "error", "-f", "concat", "-safe", "0", "-i", list, "-i", old,
		"-map", "0:v", "-map", "1:a?", "-c", "copy", "-movflags", "+write_colr+faststart", out])


## Where the video a stitch replaces is kept: beside it, its name saying so.
static func kept_name(path: String) -> String:
	return "%s.before_%s.%s" % [path.get_basename(), Time.get_datetime_string_from_system(false, true).replace(":", "").replace(" ", "_"), path.get_extension()]
