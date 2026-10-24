extends Node

## NOT a gate. An actor played LIVE in a real boot: the real main scene opens a note carrying an
## Actor, the real voice host reads it, and the stage is photographed as it plays -
## the path the app's ▶ takes, which the look probe (a set handed to the medium by hand) never ran.
##
##   GHOST_PROBE_GPU=1 GHOST_PROBE_MUTE=1 tests/run_boot_probe.sh tests/likeness/likeness_live_probe.gd 300 \
##       --actors user://actors_live_probe --actor <id> --out <dir> --play 20 [--stamp 1] [--bake 1] [--voice <id>]
##
## `--actors` is a library of the probe's own (a copy: opening an actor rescans its sources and saves
## it); the notes are made in a folder of the probe's own (`NoteStore.root`). It first presses Play on
## a note with no words (what the reading says then), then plays a note with words, printing each
## second what the medium holds, photographing the frame at `--times`, and timing each part of a frame
## (the machine's load is in those numbers: read the least).
##
## Run on the author's built set through a copy of symlinks (`cp -as`), so nothing of theirs is written:
## the actor's small json files copied whole, `"set"` pointed at the built one. With `--stamp 1` the
## copy's still, rig, library and motion (put there by hand, from actor.py run on their footage) are
## stamped made, as Generate would have. With `--bake 1` the reading's own export take is made after
## playing - its sound and its phones, `take.wav` and `take.json` in --out - for the look probe to draw
## frame by frame (`--take`), and the take's own files are taken away again. `--voice` reads the note in that
## voice (an actor's own: `actor-<id>`), the default one's otherwise; `--bookends <intro>,<outro>` gives the note
## those holds (its `bookends:` block), `--words <file>` reads that note's body (its frontmatter left out) in
## place of the probe's own sentences, and each second's line says how bright the actor is drawn and the last
## of the text's words the voice's timings have reached. `--renderer gaussian` plays them as a head of splats (the
## copy's `avatar/`, put there by hand, stamped made by `--stamp 1` with the set's other steps).

const WORDS := "Hello there. This is a short test of the likeness, read in my own voice. " \
	+ "The quick brown fox jumps over the lazy dog. Maybe we should move on, but please, bear with me."

var _main: Node
var _out := "user://likeness_live"
var _play := 20.0
## A plain reading (a Voice alone) on the same words: the control the actor's own cost is read against.
var _plain := false
var _stamp := false
var _bake := false
var _times: Array = [2.0, 4.0, 6.0, 9.0, 12.0, 16.0]
var _voice := ""
var _bookends := ""
var _words := WORDS
var _renderer := "2d"


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var actors := ""
	var actor := ""
	for i in args.size() - 1:
		match args[i]:
			"--actors": actors = args[i + 1]
			"--actor": actor = args[i + 1]
			"--out": _out = args[i + 1]
			"--play": _play = float(args[i + 1])
			"--plain": _plain = args[i + 1] == "1"
			"--stamp": _stamp = args[i + 1] == "1"
			"--bake": _bake = args[i + 1] == "1"
			"--voice": _voice = args[i + 1]
			"--bookends": _bookends = args[i + 1]
			"--renderer": _renderer = args[i + 1]
			"--words": _words = String(FrontMatter.split(FileAccess.get_file_as_string(args[i + 1])).body)
			"--times":
				_times = []
				for s in String(args[i + 1]).split(","):
					_times.append(float(s))
	if actors.is_empty() or actor.is_empty():
		print("likeness_live_probe: FAILED - give --actors (a copy) and --actor")
		get_tree().quit(2)
		return
	Actors.root = actors
	NoteStore.root = "user://likeness_live_notes"
	if _stamp:
		var a := Actors.open(actor)
		var sid := a.chosen_set()
		for st in ["visemes", "motion"]:
			a.put_stamp(st, "", "stamped by the probe")
		for st in ["stills", "rig", "library", "frames", "face", "avatar", "fit"]:
			a.put_stamp(st, "s:" + sid, "stamped by the probe")
		print("stamped the copy's set %s: playable %s" % [sid, a.playable()])
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	_main = preload("res://scenes/main.tscn").instantiate()
	add_child(_main)
	await _frames(30)
	# ▶ WITH NO WORDS: what the author saw
	var panel := await _open(NoteStore.create("live likeness empty", "", {"actor": {"id": actor}}))
	if panel == null:
		return
	_cards(panel)
	panel.transport_hooks()["play"].call()
	await _frames(10)
	print("play with no words -> status: '%s'; live %s" % [panel._status.text, panel._stream.live()])
	_main._chrome._home_button.pressed.emit()
	await _frames(30)
	var blocks := {"voice": {}} if _plain else {"actor": {"id": actor, "renderer": _renderer}}
	if not _voice.is_empty():
		blocks["voice"] = {"voices": {Manuscript.NARRATOR: {"voice": _voice}}}
	if not _bookends.is_empty():
		var hold := _bookends.split(",")
		blocks["bookends"] = {"intro": float(hold[0]), "outro": float(hold[1])}
	panel = await _open(NoteStore.create("live likeness words", _words.strip_edges() + "\n", blocks))
	print("reading in %s" % panel._cast._selected_voice_id())
	if panel == null:
		return
	if not _plain:
		_cards(panel)
		_card_costs()
	panel.transport_hooks()["play"].call()
	print("play with words -> status: '%s'" % panel._status.text)
	var t0 := Time.get_ticks_msec()
	var shot := 0
	var said := -1
	while (Time.get_ticks_msec() - t0) / 1000.0 < _play:
		await get_tree().create_timer(0.25).timeout
		var t := (Time.get_ticks_msec() - t0) / 1000.0
		var m: Medium = _main._medium
		var lm := m as LikenessMedium
		if int(t) != said:
			said = int(t)
			var subs: Node = _main._subtitles
			print("t %4.1f  fps %d  process %.1f ms  show %.2f  bright %.2f  timed %s  medium %s  ready %s  why '%s'  library %s  words %d  phones %d  status '%s'" % [t,
				Engine.get_frames_per_second(), Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, Director.show_time(),
				lm.modulate.r if lm != null else -1.0,
				("%d/%d" % [lm._follower.known_last(), lm._spoken_n]) if lm != null and lm._follower != null else "-",
				m.get_script().get_global_name() if m != null else "none",
				lm._ready_set if lm != null else false, lm._why if lm != null else "",
				lm._library_tex != null if lm != null else false,
				(subs.words as Array).size() if subs != null else -1,
				(subs.get("phones") as Array).size() if subs != null and subs.get("phones") is Array else -1,
				panel._status.text])
		if shot < _times.size() and t >= float(_times[shot]) and _main._stage != null:
			# THE WINDOW, cut to the frame: the stage's own texture reads back black while its governor
			# draws it once a few frames
			var img: Image = get_viewport().get_texture().get_image()
			if img != null:
				img = img.get_region(Rect2i((_main._stage_view as Control).get_global_rect()))
			var p := ProjectSettings.globalize_path(_out).path_join("live_%02d.png" % shot)
			if img != null:
				img.save_png(p)
				print("   shot %s (%dx%d)" % [p, img.get_width(), img.get_height()])
			else:
				print("   shot: the stage reads back null (no GPU?)")
			shot += 1
	_diag(_main._medium as LikenessMedium)
	_costs(_main._medium as LikenessMedium)
	panel.transport_hooks()["stop"].call()
	await _frames(10)
	if _bake:
		var take := await panel._render_take()
		var here := ProjectSettings.globalize_path(_out)
		if take.is_empty():
			print("bake: no take was made")
		else:
			DirAccess.copy_absolute(take, here.path_join("take.wav"))
			DirAccess.copy_absolute(take.get_basename() + ".json", here.path_join("take.json"))
			DirAccess.remove_absolute(take)
			DirAccess.remove_absolute(take.get_basename() + ".json")
			var side: Variant = ActorFolder.read_json(here.path_join("take.json"))
			print("bake: %s - %d phones, %d words" % [here.path_join("take.wav"),
				((side as Dictionary).get("phones", []) as Array).size() if side is Dictionary else -1,
				((side as Dictionary).get("words", []) as Array).size() if side is Dictionary else -1])
	print("likeness_live_probe: done")
	get_tree().quit(0)


## Open [param note] as the notes list does, and wait for its voice: its reading panel, or null (and quit).
func _open(note: String) -> ReadingPanel:
	_main._list._open(note)
	await _frames(20)
	var panel: ReadingPanel = _main._generative as ReadingPanel
	if panel == null:
		print("likeness_live_probe: FAILED - the note opened no reading")
		get_tree().quit(1)
		return null
	var waited := 0.0
	while waited < 120.0 and (panel._host == null or not panel._host.is_up() or panel._cast.voice_pick.selected < 0):
		await get_tree().create_timer(0.5).timeout
		waited += 0.5
	print("voice host up: %s after %.1f s; medium '%s'" % [panel._host != null and panel._host.is_up(), waited,
		Director.resolved_medium()])
	return panel


## WHAT THE MEDIUM DRAWS WITH: its fade, its layer and where it stands, and the stage it is on.
func _diag(lm: LikenessMedium) -> void:
	if lm == null:
		return
	var st: SubViewport = _main._stage
	print("diag: medium modulate %s visible %s in tree %s; brightness %.3f (show %.2f, live_fade %.2f, tail %.2f)" % [
		lm.modulate, lm.is_visible_in_tree(), lm.is_inside_tree(), lm._brightness(lm.feed.show_time()),
		lm.feed.show_time(), lm.feed.live_fade, lm.feed.tail()])
	print("diag: stage %s size %s update %d" % [st, st.size if st != null else Vector2i.ZERO,
		st.render_target_update_mode if st != null else -1])
	var l := lm._layer
	print("diag: layer visible %s pos %s scale %s points %d uvs %d colors %d indices %d still %s" % [
		l.is_visible_in_tree(), l.position, l.scale, l.points.size(), l.uvs.size(), l.colors.size(), l.indices.size(),
		l.tex.get_size() if l.tex != null else "none"])
	var win := get_viewport().get_texture().get_image()
	if win != null:
		win.save_png(ProjectSettings.globalize_path(_out).path_join("window.png"))
		print("diag: window %s" % win.get_size())


## WHERE A FRAME'S TIME GOES: each part of [method LikenessMedium.draw_at], timed at the moments the show
## plays next (in microseconds, the least and the median of 30).
func _costs(lm: LikenessMedium) -> void:
	if lm == null or not lm._ready_set:
		return
	var parts := {"head": [], "eyes": [], "mouth": [], "pose": [], "bones": [], "target+vertices": [], "draw_at": []}
	for k in 30:
		var t := lm._now + float(k) / 30.0
		var c := Time.get_ticks_usec()
		var hd := lm._plan.motion(t)
		parts["head"].append(Time.get_ticks_usec() - c)
		c = Time.get_ticks_usec()
		var ey := lm._plan.eyes(t)
		parts["eyes"].append(Time.get_ticks_usec() - c)
		c = Time.get_ticks_usec()
		var mo := lm._plan.mouth(t)
		parts["mouth"].append(Time.get_ticks_usec() - c)
		c = Time.get_ticks_usec()
		var posed := lm._face.pose(hd)
		parts["pose"].append(Time.get_ticks_usec() - c)
		c = Time.get_ticks_usec()
		var bn := lm._face.bones(posed, hd, lm._plan.breath(t), lm._plan.lifts(t), lm._plan.hands(t))
		parts["bones"].append(Time.get_ticks_usec() - c)
		c = Time.get_ticks_usec()
		lm._face.vertices(posed, lm._face.target(posed, mo, ey), bn)
		parts["target+vertices"].append(Time.get_ticks_usec() - c)
		c = Time.get_ticks_usec()
		lm.draw_at(t)
		parts["draw_at"].append(Time.get_ticks_usec() - c)
	for k in parts:
		var v: Array = parts[k]
		v.sort()
		print("cost %-16s least %6d us  median %6d us  (%d)" % [k, v[0] if not v.is_empty() else -1,
			v[v.size() / 2] if not v.is_empty() else -1, v.size()])


## WHAT THE TWO CARDS COST THE MAIN THREAD, four times a second: each one's refresh, the least of 5.
func _card_costs() -> void:
	var ac := _find(_main, ActorCard) as ActorCard
	for pair in [["actor card refresh", func() -> void: ac._refresh()],
			["  step rows", func() -> void:
				ac._actor.forget()
				for st in ac._rows:
					ac._builder.row_of(String(st))],
			["  sets", func() -> void: ac._actor.forget(); ac._sets_seen = ""; ac._fill_sets()],
			["  stills", func() -> void: ac._stills_seen = ""; ac._fill_stills()],
			["  library", func() -> void: ac._library_seen = ""; ac._fill_library()],
			["  playable", func() -> void: ac._actor.forget(); ac._actor.playable()],
			["  likeness status", func() -> void: ac._actor.forget(); ac.likeness_status()]]:
		var least := 1 << 30
		for i in 5:
			var c := Time.get_ticks_usec()
			(pair[1] as Callable).call()
			least = mini(least, Time.get_ticks_usec() - c)
		print("cost %-22s least %6d us" % [pair[0], least])


## What the Actor card says of them, and what it hands a render.
func _cards(_panel: ReadingPanel) -> void:
	var ac := _find(_main, ActorCard) as ActorCard
	print("actor card: %s; document %s" % [ac.likeness_status() if ac != null else "(no card)", ac.document() if ac != null else {}])


func _find(n: Node, script: Script) -> Node:
	if is_instance_of(n, script):
		return n
	for c in n.get_children():
		var got := _find(c, script)
		if got != null:
			return got
	return null


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
