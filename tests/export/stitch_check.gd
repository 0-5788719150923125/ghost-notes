extends SceneTree

## stitch_check - a stretch of an export rendered again and put back in its place ([Stitch]; next/editing.md step 13).
##
##   godot --headless --path . --script res://tests/export/stitch_check.gd
##
## On videos made by ffmpeg with the export's keyframe settings (a 12 s "old" export with sound, and a "new" 4 s stretch of
## another picture), the stitch's own argv run for real:
##   - the stretch asked for, 5.3-7.1 s, is widened to the keyframes about it, 4-8 s;
##   - the stitched video is as long as the old, every picture before and after the stretch bit for bit the old one's (copied,
##     never encoded again), the stretch's the new one's, and the sound the old one's whole track;
##   - controls: the old video's own pictures in the stretch differ from what was stitched there; the old video stitched with
##     its own middle changes nothing.

const DIR := "user://stitch_check"
const FPS := 10

var _fails := 0
var _dir := ""


func _initialize() -> void:
	_dir = ProjectSettings.globalize_path(DIR)
	_rmrf(_dir)
	DirAccess.make_dir_recursive_absolute(_dir)
	var old := _dir.path_join("old.mp4")
	var fresh := _dir.path_join("stretch.mp4")
	_make(old, "testsrc=size=160x90:rate=%d" % FPS, 12.0, true)
	_make(fresh, "testsrc2=size=160x90:rate=%d" % FPS, 4.0, false)
	var sp := Stitch.span(5.3, 7.1, 12.0)
	_ok(sp == Vector2(4.0, 8.0), "a stretch asked for is widened to the keyframes about it: %s" % str(sp))
	var out := _stitch(old, fresh, sp, "stitched.mp4")
	var o := _hashes(old)
	var s := _hashes(fresh)
	var n := _hashes(out)
	var a0 := int(sp.x) * FPS
	var a1 := int(sp.y) * FPS
	_ok(n.size() == o.size() and n.size() == 120, "as long as the old video (%d pictures of %d)" % [n.size(), o.size()])
	_ok(n.slice(0, a0) == o.slice(0, a0) and n.slice(a1) == o.slice(a1), "every picture before and after the stretch is the old one's, bit for bit")
	_ok(n.slice(a0, a1) == s.slice(0, a1 - a0), "the stretch's pictures are the new ones")
	_ok(n.slice(a0, a1) != o.slice(a0, a1), "the control: the old video's own pictures there differ")
	_ok(_audio_seconds(out) > 11.5 and absf(_audio_seconds(out) - _audio_seconds(old)) < 0.1, "the sound is the old one's whole track (%.2f s)" % _audio_seconds(out))
	# control: the old video's own middle stitched back changes nothing
	var middle := _dir.path_join("middle.mp4")
	OS.execute("ffmpeg", ["-y", "-loglevel", "error", "-ss", "%.3f" % sp.x, "-i", old, "-frames:v", str(int((sp.y - sp.x) * FPS)), "-map", "0:v", "-c", "copy", middle])
	var same := _stitch(old, middle, sp, "same.mp4")
	_ok(_hashes(same) == o, "the control: the old video stitched with its own middle is unchanged")
	_rmrf(_dir)
	if _fails == 0:
		print("stitch_check: ALL OK")
		quit(0)
		return
	print("stitch_check: %d FAILED" % _fails)
	quit(1)


## An "export": [param src] for [param secs], encoded with the export's keyframe settings.
func _make(path: String, src: String, secs: float, sound: bool) -> void:
	var args := ["-y", "-loglevel", "error", "-f", "lavfi", "-i", src]
	if sound:
		args += ["-f", "lavfi", "-i", "sine=frequency=330:sample_rate=48000"]
	args += ["-t", str(secs), "-c:v", "libx264", "-preset", "veryfast", "-pix_fmt", "yuv420p",
		"-g", str(int(FPS * Stitch.GOP_S)), "-keyint_min", str(int(FPS * Stitch.GOP_S))]
	if sound:
		args += ["-c:a", "aac", "-b:a", "128k"]
	args.append(path)
	OS.execute("ffmpeg", args)


## The stitch, step by step, with [Stitch]'s own argv.
func _stitch(old: String, stretch: String, sp: Vector2, name: String) -> String:
	var head := _dir.path_join("head.mp4")
	var tail := _dir.path_join("tail.mp4")
	var pic := _dir.path_join("pic.mp4")
	var parts: Array = []
	var ha := Stitch.head_args(old, sp.x, FPS, head)
	if not ha.is_empty():
		OS.execute("ffmpeg", Array(ha))
		parts.append(head)
	OS.execute("ffmpeg", Array(Stitch.picture_args(stretch, pic)))
	parts.append(pic)
	var ta := Stitch.tail_args(old, sp.y, 12.0, tail)
	if not ta.is_empty():
		OS.execute("ffmpeg", Array(ta))
		parts.append(tail)
	var list := _dir.path_join("list.txt")
	var f := FileAccess.open(list, FileAccess.WRITE)
	f.store_string(Stitch.list_text(parts))
	f.close()
	var out := _dir.path_join(name)
	OS.execute("ffmpeg", Array(Stitch.join_args(list, old, out)))
	return out


## Each decoded picture's md5, in order.
func _hashes(path: String) -> Array:
	var got: Array = []
	OS.execute("ffmpeg", ["-loglevel", "error", "-i", path, "-map", "0:v", "-f", "framemd5", "-"], got)
	var out: Array = []
	for line in String("".join(got)).split("\n"):
		if line.begins_with("#") or line.strip_edges().is_empty():
			continue
		out.append(line.get_slice(",", line.get_slice_count(",") - 1).strip_edges())
	return out


func _audio_seconds(path: String) -> float:
	var got: Array = []
	OS.execute("ffprobe", ["-v", "error", "-select_streams", "a:0", "-show_entries", "stream=duration", "-of", "csv=p=0", path], got)
	return float(String("".join(got)).strip_edges())


func _rmrf(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for d in DirAccess.get_directories_at(path):
		_rmrf(path.path_join(d))
	for f in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(f))
	DirAccess.remove_absolute(path)


func _ok(cond: bool, msg: String) -> void:
	print(("  ok    " if cond else "  FAIL  ") + msg)
	if not cond:
		_fails += 1
