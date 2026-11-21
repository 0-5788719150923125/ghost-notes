extends Node

## nested_show_check - another note's show played inside this one ([NestedShow], [member Director.nested], [member Spectrum.nested]),
## on a fixture song of its own (silence with a sidecar of words) and frames made here.
##
##   tests/run_boot_probe.sh tests/show/nested_show_check.gd 120
##
## - Begun at a moment, it has its own Director, song and viewport: a scene of its own in its own viewport; the session's Director is
##   still the show that is up, nothing added to the Master bus (the control: a session's Spectrum adds its analyzer there).
## - Its clock is the one handed; a clock gone back past BACK starts a seeded show again (a new Director) and walks a written one there
##   (the same Director), one going on keeps it, and one a little behind the last holds it where it is (the control: on again, it
##   goes on); its Director and song are stepped by its host alone (the control: a Director told not to process before it enters
##   the tree is set processing as it does).
## - Its song plays while it is asked for and heard, holds while held, and falls silent once its host stops asking (Stop under it),
##   the control: asked every frame, it plays on; stopped, nothing of it is left.
## - Its words are over the frame it is played in, on its own clock, in the credits where the note names no way of showing them.
## - The credits: one speed all the way, each line where the roll is when it is said, a long break empty roll, never a slower one
##   (the control: rolled line to line, the break crawls); a line said too soon for that speed set just below the one before it;
##   up from before the first word to after the last through a long pause (the control: karaoke shows nothing there).

const FixtureAudio := preload("res://tests/fixture_audio.gd")
const NESTED := "res://src/show/nested_show.gd"

var _fails: Array = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var song := _song_with_words()
	var frames: Array = []
	for i in 12 * 30:
		var f := PackedFloat32Array()
		f.resize(AudioFeatures.BAND_COUNT)
		f.fill(0.6 if i % 15 < 3 else 0.2)
		frames.append(f)
	var nested_script: GDScript = load(NESTED)
	var note: Dictionary = nested_script.call("prepared", {"song": song, "bake": "", "medium": "full", "storyboard": {}, "reveal": "credits", "secs": 12.0})
	note["frames"] = frames
	var effects := AudioServer.get_bus_effect_count(0)
	var show: Node = nested_script.new(note)
	add_child(show)
	show.call("play_at", 1.0, 1.0 / 30.0, true, true, false)
	await get_tree().process_frame
	var inner = show.get("_show")
	var vp: SubViewport = show.get("_vp")
	var scenes := vp.find_children("*", "GhostScene", true, false) if vp != null else []
	_ok(inner != null and inner != Director and bool(inner.nested) and not scenes.is_empty() and vp.own_world_3d,
		"begun, it has a Director of its own and a scene in a viewport of its own (%d)" % scenes.size())
	var kept := AudioServer.get_bus_effect_count(0) == effects
	var session: Node = (load("res://src/audio/spectrum.gd") as GDScript).new()
	add_child(session)
	var added := AudioServer.get_bus_effect_count(0) > effects
	session.free()
	while AudioServer.get_bus_effect_count(0) > effects:
		AudioServer.remove_bus_effect(0, AudioServer.get_bus_effect_count(0) - 1)
	_ok(ShowFeed.playing() == Director and kept and added,
		"the session's Director is still the show that is up, and nothing is added to the Master bus (the control: a session's song adds its analyzer)")
	_ok(absf(float(inner.show_time()) - 1.0) < 0.01, "its clock is the one handed (%.3f)" % float(inner.show_time()))
	show.call("play_at", 2.0, 1.0 / 30.0, true, true, false)
	var same: bool = show.get("_show") == inner
	show.call("play_at", 0.5, 1.0 / 30.0, true, true, false)
	_ok(same and show.get("_show") != inner and absf(float(show.get("_show").show_time()) - 0.5) < 0.01,
		"a clock going on keeps its show; gone back, it starts again from there")
	_ok(not show.get("_show").is_processing() and not show.get("_song").is_processing(),
		"its Director and song are stepped by its host alone, never on their own")
	var loose: Node = (load("res://src/show/director.gd") as GDScript).new()
	loose.set_process(false)
	add_child(loose)
	_ok(loose.is_processing(), "the control: a Director told not to process before it enters the tree is set processing as it does")
	loose.free()
	# a clock read a little behind the last (a reading's, re-based as its audio is mixed) holds it where it is
	show.call("play_at", 1.0, 1.0 / 30.0, true, true, false)
	var at_one := float(show.get("_show").show_time())
	show.call("play_at", 0.98, 1.0 / 30.0, true, true, false)
	var behind := float(show.get("_show").show_time())
	show.call("play_at", 1.02, 1.0 / 30.0, true, true, false)
	_ok(is_equal_approx(behind, at_one) and absf(float(show.get("_show").show_time()) - 1.02) < 0.001,
		"a clock a little behind the last holds it where it is (%.3f), and on again it goes on (the control, %.3f)" % [behind, float(show.get("_show").show_time())])
	# a written show gone back (round again on a loop) is walked there: the same Director, the entry then
	var board := Storyboard.from_data({"loop": true, "bookend": false, "sequence": [
		{"scene": "stage", "hold": 2.0, "cast": []}, {"scene": "stage", "hold": 2.0, "cast": []}]}, "loop")
	var written: Node = nested_script.new(nested_script.call("prepared", {"song": "", "title": "loop", "medium": "full", "storyboard": board, "secs": 4.0}))
	add_child(written)
	var t := 0.0
	while t < 2.5:
		written.call("play_at", t, 1.0 / 30.0, true, true, false)
		t += 1.0 / 30.0
	var walker = written.get("_show")
	var second := int(walker.get("_manual_i"))
	written.call("play_at", 0.3, 1.0 / 30.0, true, true, false)
	_ok(second == 1 and written.get("_show") == walker and int(walker.get("_manual_i")) == 0,
		"a written show gone back is walked there by its own Director (entry %d -> %d)" % [second, int(walker.get("_manual_i"))])
	written.free()
	# its song: heard while asked, held while held, silent once nobody asks
	var player: AudioStreamPlayer = show.get("_song").get("_player")
	_ok(player.playing, "its song plays while it is asked for and heard")
	show.call("play_at", 0.6, 1.0 / 30.0, true, true, true)
	_ok(player.stream_paused, "...holds while the show is held")
	for i in 6:
		show.call("play_at", 0.6 + float(i) / 30.0, 1.0 / 30.0, true, true, false)
		await get_tree().process_frame
	var asked_on := player.playing and not player.stream_paused
	for i in 6:
		await get_tree().process_frame
	_ok(asked_on and not player.playing, "asked every frame it plays on (the control), and it falls silent once its host stops asking")
	# its words
	var subs: Subtitles = show.get("_subs")
	show.call("play_at", 3.0, 1.0 / 30.0, true, true, false)
	_ok(subs != null and subs.get_parent() == show and subs.reveal == "credits" and absf(subs.now() - 3.0) < 0.05 and subs.words.size() == 6,
		"its words are over the frame it plays in, on its own clock, in the credits")
	show.call("stop")
	_ok(show.get("_show") == null and show.get("_song") == null and show.get("_subs") == null, "stopped, nothing of it is left")
	show.queue_free()
	_credits()
	await get_tree().process_frame
	if _fails.is_empty():
		print("nested_show_check: ALL OK")
		get_tree().quit(0)
		return
	for f in _fails:
		print("nested_show_check: FAIL  " + String(f))
	get_tree().quit(1)


## The credits' speed, where their lines lie, and their presence.
func _credits() -> void:
	# lines said every 2 to 2.6 s, then a break of 22 s, then two more; one line said too soon after the one before it
	var times := PackedFloat32Array([2.0, 4.1, 6.5, 9.1, 31.0, 33.5, 34.0])
	var needs := PackedFloat32Array()
	for i in times.size() - 1:
		needs.append(1.55)
	var pace := Subtitles.credits_pace(times, needs)
	var places := Subtitles.credits_places(times, needs, pace)
	var on_time := true
	for i in 6:
		on_time = on_time and is_equal_approx(places[i], times[i] * pace)
	var apart := true
	for i in times.size() - 1:
		apart = apart and places[i + 1] - places[i] >= needs[i] - 1e-4
	var break_rows := places[4] - places[3]
	_ok(pace > 1.55 / 2.65 and pace <= 1.55 / 2.0 + 1e-4 and on_time and apart and break_rows > 15.0,
		"one speed for the roll, each line where it is when said, a 22 s break empty roll (%.1f rows), never a slower one (pace %.2f)" % [break_rows, pace])
	_ok(places[6] > times[6] * pace and is_equal_approx(places[6] - places[5], 1.55),
		"a line said too soon after another for that speed is set just below it, never over it (the control: its own time would be)")
	# the control: interpolating line to line, the roll would crawl through the break
	var crawl := 1.55 / (times[4] - times[3])
	_ok(crawl < pace * 0.2, "the control: rolled line to line, the break would roll at a fifth of the speed or less (%.3f of %.2f)" % [crawl, pace])
	var subs := Subtitles.new()
	subs.words = [{"text": "One", "t0": 2.0, "t1": 2.5, "sentence": 0}, {"text": "two", "t0": 12.0, "t1": 12.5, "sentence": 1}]
	subs.clock = func() -> float: return 0.0
	subs.reveal = "credits"
	var up := subs._presence_target(1.0) > 0.5 and subs._presence_target(7.0) > 0.5 and subs._presence_target(30.0) < 0.5
	subs.reveal = "karaoke"
	var karaoke_gap := subs._presence_target(7.0) < 0.5
	subs.free()
	_ok(up and karaoke_gap, "the credits are up from before the first word through a long pause to after the last (the control: karaoke is not)")


## A silent fixture song with a sidecar of six words in two lines, beside it in user://fixtures.
func _song_with_words() -> String:
	var src := FixtureAudio.silence(12.0)
	var dst := src.get_base_dir().path_join("nested_song.wav")
	if not FileAccess.file_exists(dst):
		DirAccess.copy_absolute(src, dst)
	var words := [{"text": "Welcome", "t0": 1.0, "t1": 1.5, "sentence": 0}, {"text": "random", "t0": 1.6, "t1": 2.0, "sentence": 0},
		{"text": "user", "t0": 2.1, "t1": 2.8, "sentence": 0}, {"text": "To", "t0": 4.0, "t1": 4.2, "sentence": 1},
		{"text": "my", "t0": 4.3, "t1": 4.5, "sentence": 1}, {"text": "soliloquy", "t0": 4.6, "t1": 5.6, "sentence": 1}]
	var f := FileAccess.open(dst.get_basename() + ".json", FileAccess.WRITE)
	f.store_string(JSON.stringify({"words": words}))
	f.close()
	return dst


func _ok(cond: bool, what: String) -> void:
	if not cond:
		_fails.append(what)
