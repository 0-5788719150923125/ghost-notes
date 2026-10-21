extends SceneTree

## mask_tracks_check - MASKING'S TRACKS AND ITS TRANSPORT ([MaskTracks], [method MaskEditor.transport_hooks];
## next/structure.md, steps 25 and 26), on a clip of its own:
##
##   godot --headless --path . --script res://tests/masking/mask_tracks_check.gd
##
##   - THE LANES ARE THE SESSION'S: the main clip's lane and one per track, built again after each edit;
##   - A SPLIT CUTS AT THE PLAYHEAD: a track split there is two lanes edge to edge - the right half's in
##     point is the playhead's place in its source - and the main clip split there ends at the playhead,
##     its tail a track picking up where it stopped. A playhead outside a track's span splits nothing
##     (the control: the split's arithmetic is what is checked, not that a split happened);
##   - A DELETE TAKES ITS LANE AND ITS PLAYERS, and the players stay one per track - and the old lanes
##     go at once: they had drawn on for the rest of the frame, each reading its track by an index now
##     past the end (an out-of-bounds error per lane, which check.sh fails behind the pass);
##   - A TRACK PLAYS ONLY IN ITS WINDOW ([method MaskTracks.sync]): active with the playhead over it,
##     paused and inactive past it;
##   - THE SHARED TRANSPORT CONDUCTS THE CLIP: the shell is handed the editor's hooks, their length is the
##     clip's, a seek moves the master clock, Stop goes back to the in point and waits there;
##   - A CLIP WHOSE SOUND LOADS ON THE WORKER STARTS when the sound lands: its start is held for the
##     sound, never cancelled by the pause that shows its first frame (it had been, and such a clip
##     opened paused);
##   - THE TIMELINE STANDS ABOVE THE RAIL: the marker strip, the lanes and the video are lifted by the room
##     the shell's transport takes - and by none under a shell with no transport (the control: where they
##     always stood).
##
## The fixture is a 4 s clip and its sound, made by ffmpeg under user:// once; the session is the gate's own.

const DIR := "user://mask_tracks_check"
const CLIP_SECONDS := 4
const ROOM := 44.0

var _fails: PackedStringArray = []


## A shell that keeps what it is handed: the transport's hooks, and a room of its choosing.
class Stand:
	extends Shell
	var hooks := {}
	var room := 0.0

	func conduct_transport(_owner: Object, h: Dictionary) -> void:
		hooks = h

	func release_transport(_owner: Object) -> void:
		hooks = {}

	func transport_room() -> float:
		return room


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	var session := _fixture()
	if session.is_empty():
		print("mask_tracks_check: could not build the fixture (is ffmpeg on PATH?)")
		quit(2)
		return
	var stand := Stand.new()
	stand.room = ROOM
	root.add_child(stand)
	# loaded by path, untyped: a --script gate compiles before the autoloads, and the editor names one
	var ed: Node = load("res://src/masking/mask_editor.gd").new()
	root.add_child(ed)
	# a frame first: under _initialize nothing is inside the tree yet, and the editor finds its shell there
	await _frames(1)
	ed.open_source(session)
	await _frames(30)

	print("the shared transport")
	var hooks: Dictionary = stand.hooks
	_ok(hooks.has_all(["play", "pause", "stop", "playing", "can_play", "can_stop", "position", "length", "seek"]),
		"the shell was handed the editor's transport hooks (%s)" % ", ".join(PackedStringArray(hooks.keys())))
	if hooks.is_empty():
		_finish()
		return
	_ok(is_equal_approx(float(hooks["length"].call()), ed.session.duration), "its length is the clip's (%.2f)" % float(hooks["length"].call()))
	hooks["seek"].call(2.5)
	await _frames(4)
	_ok(absf(ed.playhead() - 2.5) < 0.1 and absf(float(hooks["position"].call()) - ed.playhead()) < 0.001,
		"a seek moves the master clock (%.2f), and the position read is the clock's" % ed.playhead())
	hooks["play"].call()
	await _frames(3)
	_ok(bool(hooks["playing"].call()), "play plays")
	hooks["stop"].call()
	await _frames(4)
	_ok(not bool(hooks["playing"].call()) and absf(ed.playhead() - ed.session.clip_in) < 0.1,
		"stop goes back to the in point (%.2f) and waits there" % ed.playhead())

	print("the timeline stands above the rail")
	_ok(is_equal_approx(ed.bottom_lift(), ROOM), "lifted by the room the transport takes (%.0f)" % ed.bottom_lift())
	_ok(is_equal_approx(ed._timeline.offset_bottom, -90.0 - ROOM), "the marker strip over it (%.0f)" % ed._timeline.offset_bottom)
	_ok(is_equal_approx(ed._lanes_col.offset_bottom, -90.0 - ROOM), "the lanes over the strip (%.0f)" % ed._lanes_col.offset_bottom)
	stand.room = 0.0
	await _frames(2)
	_ok(is_equal_approx(ed._lanes_col.offset_bottom, -90.0) and is_equal_approx(ed._video_area.offset_bottom, -90.0 - float(ed._tracks.get_script().get_script_constant_map()["_LANE_H"])),
		"the control: under a shell with no transport they stand where they always did (%.0f, %.0f)"
		% [ed._lanes_col.offset_bottom, ed._video_area.offset_bottom])

	print("the lanes, a split, a delete")
	_ok(ed._lanes_col.get_child_count() == 1, "the main clip's lane alone (%d)" % ed._lanes_col.get_child_count())
	ed.session.tracks.append({"video_path": ed.session.video_path, "source_path": ed.session.video_path,
		"duration": float(CLIP_SECONDS), "clip_in": 0.0, "clip_out": 2.5, "offset": 1.0,
		"x": 0.68, "y": 0.04, "w": 0.28, "h": 0.28, "volume": 1.0})
	ed._tracks.build_view(0)
	ed._tracks.refresh_lanes()
	await _frames(2)
	_ok(ed._lanes_col.get_child_count() == 2 and ed._tracks.runtime.size() == 1, "a track: its own lane and players (%d lanes)" % ed._lanes_col.get_child_count())
	ed._on_scrub(0.5)
	await _frames(4)
	ed._tracks._split_track(0)
	_ok(ed.session.tracks.size() == 1, "the control: a playhead before the track's span splits nothing (%d tracks)" % ed.session.tracks.size())
	ed._on_scrub(2.0)
	await _frames(4)
	var at: float = ed.playhead()
	ed._tracks._split_track(0)
	await _frames(2)
	var tracks: Array = ed.session.tracks
	var left: Dictionary = tracks[0]
	var right: Dictionary = tracks[-1] if tracks.size() > 1 else {}
	var left_end := float(left["offset"]) + float(left["clip_out"]) - float(left["clip_in"])
	_ok(ed.session.tracks.size() == 2 and not right.is_empty() and absf(left_end - float(right["offset"])) < 0.001
		and absf(float(right["clip_in"]) - (at - 1.0)) < 0.001 and is_equal_approx(float(right["clip_out"]), 2.5),
		"a track split at the playhead (%.2f): two halves edge to edge, the right one from its place in the source" % at)
	_ok(ed._lanes_col.get_child_count() == 3 and ed._tracks.runtime.size() == 2, "...each a lane, each with players (%d lanes, %d)"
		% [ed._lanes_col.get_child_count(), ed._tracks.runtime.size()])
	ed._on_scrub(3.0)
	await _frames(4)
	at = ed.playhead()
	ed._tracks._split_main()
	await _frames(2)
	var tail: Dictionary = (ed.session.tracks as Array)[-1]
	_ok(ed.session.tracks.size() == 3 and absf(ed.session.clip_out - at) < 0.001 and absf(float(tail["offset"]) - at) < 0.001
		and absf(float(tail["clip_in"]) - at) < 0.001, "the main clip split at the playhead (%.2f) ends there; its tail picks up as a track" % at)
	ed._tracks._delete_track(1)
	await _frames(2)
	_ok(ed.session.tracks.size() == 2 and ed._tracks.runtime.size() == 2 and ed._lanes_col.get_child_count() == 3,
		"a delete takes its lane and its players (%d tracks, %d players, %d lanes)"
		% [ed.session.tracks.size(), ed._tracks.runtime.size(), ed._lanes_col.get_child_count()])

	print("a track plays only in its window")
	ed._on_scrub(1.5)
	await _frames(4)
	ed._tracks.sync()
	var first: Dictionary = (ed._tracks.runtime as Array)[0]
	_ok(bool(first.get("active", false)), "with the playhead over it (1.5 in 1.0..%.1f), it is active" % left_end)
	ed._on_scrub(3.5)
	await _frames(4)
	ed._tracks.sync()
	_ok(not bool(first.get("active", true)) and (first["player"] as VideoStreamPlayer).paused, "past it, paused and inactive")
	ed.queue_free()
	await _frames(2)

	print("a clip whose sound loads on the worker")
	var held: Node = load("res://src/masking/mask_editor.gd").new()
	root.add_child(held)
	await _frames(1)
	held.open_source(_held_fixture())
	var threaded: bool = held._audio_thread != null
	var waited := 0
	while held._audio_thread != null and waited < 600:
		await process_frame
		waited += 1
	await _frames(3)
	_ok(threaded and bool(held._playing), "it starts once the sound lands (loaded on the worker: %s, playing: %s)" % [threaded, held._playing])
	_finish(held)


func _finish(ed: Node = null) -> void:
	if ed != null:
		ed.queue_free()
	print("")
	if _fails.is_empty():
		print("mask_tracks_check: ALL OK")
		quit(0)
	else:
		for f in _fails:
			print("mask_tracks_check: FAIL - ", f)
		quit(1)


func _ok(cond: bool, what: String) -> void:
	print(("  ok    " if cond else "  FAIL  ") + what)
	if not cond:
		_fails.append(what)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


## The same clip with its sound as a WAV alone - no `.ogg` beside it, so the editor loads it on a worker -
## and a session of its own.
func _held_fixture() -> String:
	var audio := DIR + "/held.wav"
	var abs_audio := ProjectSettings.globalize_path(audio)
	if not FileAccess.file_exists(abs_audio):
		DirAccess.copy_absolute(ProjectSettings.globalize_path(DIR + "/clip.wav"), abs_audio)
	DirAccess.remove_absolute(abs_audio.get_basename() + ".ogg")   # the editor derives one for next time
	var session := MaskSession.new()
	session.video_path = DIR + "/clip.ogv"
	session.audio_path = audio
	session.duration = float(CLIP_SECONDS)
	var path := DIR + "/held.json"
	return path if session.save(ProjectSettings.globalize_path(path)) else ""


## The clip, its sound and the gate's own session; the session's path, or "" when ffmpeg is missing.
func _fixture() -> String:
	var video := DIR + "/clip.ogv"
	var audio := DIR + "/clip.wav"
	var abs_video := ProjectSettings.globalize_path(video)
	var abs_audio := ProjectSettings.globalize_path(audio)
	if not FileAccess.file_exists(abs_video):
		OS.execute("ffmpeg", ["-y", "-loglevel", "error", "-f", "lavfi",
			"-i", "testsrc=size=320x180:rate=25:duration=%d" % CLIP_SECONDS,
			"-c:v", "libtheora", "-q:v", "6", "-g", "25", "-f", "ogg", abs_video], [])
		if not FileAccess.file_exists(abs_video):
			return ""
	if not FileAccess.file_exists(abs_audio):
		OS.execute("ffmpeg", ["-y", "-loglevel", "error", "-f", "lavfi", "-i", "sine=frequency=220:duration=%d" % CLIP_SECONDS,
			"-c:a", "pcm_s16le", "-ar", "44100", "-ac", "2", "-f", "wav", abs_audio], [])
		OS.execute("ffmpeg", ["-y", "-loglevel", "error", "-i", abs_audio, "-c:a", "libvorbis", "-q:a", "5", "-f", "ogg",
			abs_audio.get_basename() + ".ogg"], [])
	var session := MaskSession.new()
	session.video_path = video
	session.audio_path = audio
	session.duration = float(CLIP_SECONDS)
	var path := DIR + "/session.json"
	# A fresh session every run: the editor saves its own on the way out, splits and all.
	return path if session.save(ProjectSettings.globalize_path(path)) else ""
