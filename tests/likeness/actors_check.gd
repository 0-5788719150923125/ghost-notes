extends SceneTree

## actors_check - the Actors library and the runner that builds an actor (next/likeness.md, "The
## library", "The steps"): what waits, what is stale, what ⟳ throws away, the order Generate makes
## things in - all in a library moved aside ([method Actors.use_for_test]), so nothing of the author's
## is touched.
##
##   godot --headless --path . --script tests/likeness/actors_check.gd
##
## THE STEPS ARE MADE BY THE GATE ([member ActorBuilder.make_with]): each writes its outputs as made-up
## files, and the runner stamps them, so the order, the waiting and the staleness are the runner's own
## and no program runs.
##
## A STEP WAITS FOR ITS INPUT: ▶ on the survey of a video never probed makes the probe first; asked
## alone (the CONTROL: a step started without its input), it starts nothing.
## GENERATE'S ORDER: each video's probe before its survey before its shots, every video's shots before
## the sets, the sets before the audit, the audit before the actor's visemes and motion and the set's
## stills, the stills before the rig and At rest, and the rig and the visemes before the library. THEIR
## VOICE: each video's probe before its Hear, every video's Hear before the Utterances, the Utterances
## before the Voice; ▶ on the Voice makes those three and nothing of their picture, and the voice's
## lessons changed make the Voice stale and only it.
## TWO RENDERERS: a run for the 2D renderer makes none of the head of splats, and the actor does not play
## as one; a run for the gaussian renderer then makes each video's Head frames, their Head rig and Head (ONE HEAD
## FOR EVERY SET, learned from every video), then the set's Frames, Face rig, Avatar and Fit in order, and
## nothing else - the steps the two share are made once (THE CONTROL: the 2D run did make the 2D's library).
## THE STILL DRAWN ON: the one picked, else the one At rest found most at ease, else the first; stills
## made again forget the pick (an index into the old ones).
## A CHANGED INPUT MARKS STALE: a setting a step reads makes it stale, and only it, until it is made
## again - then what was made from it. ⟳ THROWS A STEP AWAY and makes it again; what is made from it
## directly is stale (and what is made from those, once they are made again). A video unticked makes
## the sets stale. A STILL PICKED changes nothing that is made but the body fitted to a still (the Fit: the
## Avatar it is fitted from stays made): the library is the set's.
## A RESTART CHANGES NOTHING: the actor read again from its file finds every step as it was, its videos
## held in an order their ids do not sort in (2026-10-21: `actor.json` was written sorted, read back in
## another order than the stamps were made in, and the user's built set went stale after a restart -
## the sets, the audit and every step of the set made again).
## A VIDEO'S FILE MOVED to another of their folders keeps its id, and nothing made from it is stale (THE CONTROL:
## a copy beside a file still there is a video of its own).
## NOTHING OUTSIDE THE TEST ROOT: the author's library is as it was.

const ROOT := "user://actors_check"

var _fails := 0
var _checks := 0
var _made: Array = []
var _ever: Array = []          # every step made, through every run
var _actor: ActorFolder


func _init() -> void:
	_run.call_deferred()


func _ok(cond: bool, what: String) -> void:
	_checks += 1
	if not cond:
		_fails += 1
		print("  FAIL: " + what)


func _run() -> void:
	var real := _listing(ActorsRoot.real())
	Actors.use_for_test(ROOT)
	# TWO VIDEOS IN A FOLDER (made: a few bytes is a video to the library, which reads only their names)
	var folder := ProjectSettings.globalize_path(ROOT).path_join("footage_in")
	DirAccess.make_dir_recursive_absolute(folder)
	for n in ["@someone - First talk (1080p, h264).mp4", "Second talk.mkv", "notes.txt"]:
		var f := FileAccess.open(folder.path_join(n), FileAccess.WRITE)
		f.store_string("not really a video " + n)
		f.close()
	_actor = Actors.create("A Person")
	_ok(_actor.dir.begins_with(ProjectSettings.globalize_path(ROOT)), "the actor is not in the test root: %s" % _actor.dir)
	_ok(ActorSources.add_folder(_actor, folder) == 2, "the folder's two videos were not found (a .txt is no video)")
	# ...held in an order their ids do not sort in, as a folder's are (added by name; an id is a hash)
	var held: Dictionary = _actor.data["videos"]
	var ids := held.keys()
	ids.sort()
	ids.reverse()
	for vid in ids:
		var row: Variant = held[vid]
		held.erase(vid)
		held[vid] = row
	_actor.save()
	var vids := _actor.ticked()
	_ok(vids.size() == 2, "the folder's videos are not ticked")
	_ok(ActorSources.title_of_file("@someone - First talk (1080p, h264).mp4") == "@someone - First talk",
		"a downloader's tag stays in a title")
	_ok(ActorSources.same_title("@someone - First talk", "First Talk"), "a title is not matched without its channel")
	var b := ActorBuilder.new(_actor)
	b.make_with = _make
	var v0 := "v:" + String(vids[0])
	# THE CONTROL: the survey asked for alone, with no probe under it, starts nothing
	b.start(["survey"])
	_spin(b)
	_ok(not _made.has("survey|" + v0), "a survey started with no probe under it")
	# ...and ▶ makes what it needs first
	_made = []
	b.start(ActorSteps.with_needs("survey"))
	_spin(b)
	_ok(_before("probe|" + v0, "survey|" + v0), "▶ on the survey did not probe first: %s" % str(_made))
	# GENERATE, whole
	_made = []
	b.start()
	_spin(b)
	var sid := _actor.chosen_set()
	_ok(not sid.is_empty(), "no set was chosen once the sets were made")
	var s := "s:" + sid
	for v in vids:
		var sc := "v:" + String(v)
		_ok(_ever.find("survey|" + sc) >= 0 and _ever.find("survey|" + sc) < _ever.find("shots|" + sc),
			"a video's shots came before its survey")
		_ok(_before("shots|" + sc, "sets|"), "the sets came before a video's shots")
	_ok(_before("sets|", "audit|"), "the audit came before the sets")
	_ok(_before("audit|", "stills|" + s) and _before("audit|", "visemes|") and _before("audit|", "motion|"),
		"the stills, the visemes or the motion came before the audit")
	_ok(_before("stills|" + s, "rig|" + s) and _before("rig|" + s, "library|" + s) and _before("visemes|", "library|" + s),
		"the rig or the library came out of order")
	_ok(_before("stills|" + s, "rest|" + s), "At rest came before the stills")
	_ok(_made.has("motion|") and _made.has("library|" + s), "Generate left steps unmade: %s" % str(_made))
	for v in vids:
		var sc := "v:" + String(v)
		_ok(_ever.find("probe|" + sc) >= 0 and _ever.find("probe|" + sc) < _ever.find("hear|" + sc)
			and _before("hear|" + sc, "utterances|"),
			"a video was heard before its probe, or the utterances cut before it was heard: %s" % str(_made))
	_ok(_before("utterances|", "voice|"), "the voice was taught before its utterances were cut: %s" % str(_made))
	_ok(_actor.playable(), "a fully made actor is not playable")
	_ok(not _made.has("fetch|" + v0), "a folder video was fetched")
	# A RESTART CHANGES NOTHING: read again from its file, the actor finds every step as it was
	var moved := _restarted()
	_ok(moved.is_empty(), "read again from its file, the actor found %s" % str(moved))
	# A CHANGED SETTING: the survey is stale, and only it until it is made again
	_actor.forget()
	(_actor.data["settings"] as Dictionary)["survey_interval"] = 0.25
	_actor.save()
	_actor.forget()
	_ok(_actor.state_of("survey", v0) == "stale", "a changed setting left the survey %s" % _actor.state_of("survey", v0))
	_ok(_actor.state_of("shots", v0) == "made", "the shots were stale before the survey was made again")
	_ok(_actor.playable(), "a stale step stopped the actor playing - stale is still used")
	_made = []
	b.start(["survey"])
	_spin(b)
	_actor.forget()
	_ok(_actor.state_of("survey", v0) == "made" and _actor.state_of("shots", v0) == "stale",
		"the survey made again did not make its shots stale (survey %s, shots %s)" % [_actor.state_of("survey", v0), _actor.state_of("shots", v0)])
	# GENERATE MAKES WHAT IS STALE, in order, and nothing that is not
	_made = []
	b.start()
	_spin(b)
	_actor.forget()
	_ok(_made.has("shots|" + v0) and _made.has("sets|") and not _made.has("probe|" + v0),
		"Generate after a change made %s" % str(_made))
	_ok(_actor.state_of("rig", s) == "made", "Generate left the rig %s" % _actor.state_of("rig", s))
	# THEIR VOICE ON ITS OWN: the lessons changed make the Voice stale, and only it; ▶ on it makes it and
	# nothing of their picture (THE CONTROL: the Hear, made, is not made again)
	(_actor.data["settings"] as Dictionary)["voice_epochs"] = 300
	_actor.save()
	_actor.forget()
	_ok(_actor.state_of("voice", "") == "stale" and _actor.state_of("utterances", "") == "made"
		and _actor.state_of("hear", v0) == "made", "the voice's lessons changed left the voice %s, the utterances %s" % [
		_actor.state_of("voice", ""), _actor.state_of("utterances", "")])
	_made = []
	b.start(ActorSteps.with_needs("voice"))
	_spin(b)
	_ok(_made == ["voice|"], "▶ on the stale voice made %s" % str(_made))
	_ok(ActorSteps.with_needs("voice").all(func(st: String) -> bool: return ActorSteps.is_voice(st) or st in ["fetch", "probe"]),
		"the voice is made from steps of their picture: %s" % str(ActorSteps.with_needs("voice")))
	# TWO RENDERERS: the 2D run made none of the head of splats; a gaussian run makes it, and only it
	_ok(_ever.has("library|" + s), "control: the 2D run did not make the 2D's library")
	_ok(not _ever.has("frames|" + s) and not _ever.has("avatar|" + s), "a 2D run made the head of splats: %s" % str(_ever))
	_ok(_actor.playable("", "2d") and not _actor.playable("", "gaussian"), "with no head of splats the actor plays as one")
	_made = []
	b.renderer = "gaussian"
	b.start()
	_spin(b)
	_actor.forget()
	var heads: Array = []
	for v in _actor.ticked():
		heads.append("head_frames|v:" + String(v))
	_ok(_made == heads + ["head_rig|", "head|", "frames|" + s, "face|" + s, "avatar|" + s, "fit|" + s],
		"a gaussian run after a 2D one made %s" % str(_made))
	# A VIDEO WITH NO SHOT OF THEIRS IN ANY SET has no moments for their head: its Head frames is moot, and made
	# with no token (THE CONTROL: one with a shot is not)
	_ok(_actor.moot("head_frames", "v:no-such-video") and _actor.token_of("head_frames", "v:no-such-video").is_empty()
		and not _actor.moot("head_frames", "v:" + String(_actor.ticked()[0])),
		"a video with no shot was not moot, or one with a shot was")
	_ok(_actor.playable("", "gaussian"), "a head of splats made does not play")
	_ok(ActorSteps.serves("motion", "gaussian") and ActorSteps.serves("motion", "2d") and not ActorSteps.serves("library", "gaussian")
		and not ActorSteps.serves("avatar", "2d"), "a step serves the wrong renderer")
	# A ROW FROM THE STATES A WORKER WORKS OUT (`states_of`, on a folder of its own) is the row worked out here
	var worked := ActorBuilder.states_of(ActorFolder.open(_actor.id))
	var apart: Array = []
	for st in ActorSteps.ORDER:
		if JSON.stringify(b.row_of(st)) != JSON.stringify(b.row_of(st, worked)):
			apart.append(st)
	_ok(apart.is_empty() and worked.size() == ActorSteps.ORDER.size(), "rows from the worker's states differ: %s" % str(apart))
	b.renderer = "2d"
	# THE STILL DRAWN ON: the first, then the one most at rest, then the one picked
	var stills_at := _actor.set_dir(sid).path_join("stills.json")
	_write(stills_at, JSON.stringify({"stills": [{}, {}, {}, {}]}))
	_ok(_actor.still_of(sid) == 0, "with nothing at rest and nothing picked the still is %d" % _actor.still_of(sid))
	_write(_actor.set_dir(sid).path_join("rest.json"), JSON.stringify({"rest": [3, 9, 1]}))
	_ok(_actor.still_of(sid) == 3 and _actor.rest_of(sid) == [3, 1], "the still most at rest was not drawn on (%d, at rest %s)" % [
		_actor.still_of(sid), str(_actor.rest_of(sid))])
	# A STILL PICKED changes nothing that is made
	_actor.set_still(sid, 1)
	_actor.save()
	_actor.forget()
	_ok(_actor.still_of(sid) == 1, "the still picked was not drawn on")
	_ok(_actor.state_of("library", s) == "made" and _actor.state_of("rig", s) == "made", "picking a still made the set stale")
	_ok(_actor.state_of("avatar", s) == "made", "picking a still left the avatar %s" % _actor.state_of("avatar", s))
	_ok(_actor.state_of("fit", s) == "stale", "picking a still left the body fitted to another %s" % _actor.state_of("fit", s))
	# ⟳: the step thrown away and made again, what is made from it stale
	_made = []
	var stills_file := _actor.set_dir(sid).path_join("stills.json")
	FileAccess.open(stills_file, FileAccess.WRITE).store_string("the old stills")
	b.make_with = func(step: String, scope: String) -> String:
		if step == "stills":
			_ok(not FileAccess.file_exists(stills_file), "⟳ did not throw the stills away before making them again")
		return _make(step, scope)
	b.redo("stills")
	_spin(b)
	_actor.forget()
	_ok(_made == ["stills|" + s], "⟳ on the stills made %s" % str(_made))
	_ok(not (_actor.data["stills"] as Dictionary).has(sid), "the stills made again kept the pick of the old ones")
	_ok(_actor.state_of("rig", s) == "stale", "the stills made again left the rig %s" % _actor.state_of("rig", s))
	# ...and what is made from those, once they are made again: one step at a time, never all at once
	_ok(_actor.state_of("library", s) == "made", "the library went stale before the rig was made again")
	# A VIDEO UNTICKED: the sets are stale
	b.make_with = _make
	(_actor.video(String(vids[1])) as Dictionary)["ticked"] = false
	_actor.save()
	_actor.forget()
	_ok(_actor.state_of("sets", "") == "stale", "unticking a video left the sets %s" % _actor.state_of("sets", ""))
	# A VIDEO'S FILE MOVED to another of their folders: the same video, nothing made from it stale
	var mv := String(vids[0])
	var old_path := String(_actor.video(mv)["path"])
	var before_move := _actor.state_of("survey", "v:" + mv)
	var more := ProjectSettings.globalize_path(ROOT).path_join("footage_more")
	DirAccess.make_dir_recursive_absolute(more)
	DirAccess.rename_absolute(old_path, more.path_join(old_path.get_file()))
	var count := _actor.videos().size()
	var added := ActorSources.add_folder(_actor, more)
	_actor.save()
	_actor.forget()
	_ok(added == 0 and _actor.videos().size() == count and String(_actor.video(mv)["path"]) == more.path_join(old_path.get_file())
		and _actor.state_of("survey", "v:" + mv) == before_move and before_move == "made",
		"a moved video was not the same one (%d added, its survey %s, before %s)" % [added, _actor.state_of("survey", "v:" + mv), before_move])
	# THE CONTROL: a copy beside the file, which is still there, is a video of its own
	var copy_from := String(_actor.video(String(vids[1]))["path"])
	DirAccess.copy_absolute(copy_from, more.path_join(copy_from.get_file()))
	_ok(ActorSources.rescan(_actor) == 1, "CONTROL: a copy beside its original was taken for it")
	# EVERY STEP A PROGRAM MAKES IS LANDED BY ITS MAIN FILE (a step without one would be "done" and never stamped,
	# so made again for ever); THE CONTROL: a step that runs no program needs none
	var unlanded: Array = []
	for st in ActorSteps.ORDER:
		var runs := String(Registry.field(ActorSteps.REGISTRY, st, "runs", ""))
		if (runs == "python" or runs == "train") and not ActorBuilder.MAIN.has(st):
			unlanded.append(st)
	_ok(unlanded.is_empty() and not ActorBuilder.MAIN.has("fetch"), "steps a program makes with no main file: %s" % str(unlanded))
	# THE LIBRARY: listed by name, opened by id
	var listed := Actors.list()
	_ok(listed.size() == 1 and String(listed[0]["name"]) == "A Person", "the library lists %s" % str(listed))
	_ok(Actors.open(_actor.id) != null and Actors.open("nobody") == null, "an actor opened by a wrong id, or not by its own")
	# NOTHING OUTSIDE THE TEST ROOT
	# (an app building an actor meanwhile writes there too: the message names what changed)
	var now := _listing(ActorsRoot.real())
	var changed: Array = []
	for p in now.keys() + real.keys():
		if now.get(p, -1) != real.get(p, -1) and not changed.has(p):
			changed.append(p)
	_ok(changed.is_empty(), "the author's library changed: %s" % ", ".join(PackedStringArray(changed.slice(0, 3))))
	Actors._remove_tree(ProjectSettings.globalize_path(ROOT))
	print("actors_check: %s (%d checks, %d failure%s)" % ["ALL OK" if _fails == 0 else "FAILED", _checks, _fails, "" if _fails == 1 else "s"])
	quit(1 if _fails > 0 else 0)


## The author's library, out of reach of the seam.
class ActorsRoot:
	static func real() -> String:
		return ProjectSettings.globalize_path(Actors.ROOT)


## A step "made": its outputs written as made-up files - and the sets and the audit with one set.
func _make(step: String, scope: String) -> String:
	_made.append(step + "|" + scope)
	_ever.append(step + "|" + scope)
	var dir := _actor.scope_dir(scope)
	DirAccess.make_dir_recursive_absolute(dir)
	for f in ActorSteps.outputs(step):
		var p := dir.path_join(String(f))
		if String(f).get_extension().is_empty():
			DirAccess.make_dir_recursive_absolute(p)
			continue
		var text := "made"
		DirAccess.make_dir_recursive_absolute(p.get_base_dir())
		if String(f) == "sets.json" or String(f) == "audit.json":
			# a usable shot of each video: their head is read from every one ("One head")
			var shots: Array = []
			for v in _actor.ticked():
				shots.append({"vid": String(v), "start": 1.0, "end": 61.0, "usable": 50.0})
			text = JSON.stringify({"sets": [{"id": "set-made", "usable": 5.0, "minutes": 6.0, "shots": shots, "size": [64, 36]}]})
		var fa := FileAccess.open(p, FileAccess.WRITE)
		fa.store_string(text)
		fa.close()
	return ""


static func _write(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()


## Every step whose state is not the same in the actor read again from its file (a restart).
func _restarted() -> Array:
	_actor.forget()
	var again := ActorFolder.open(_actor.id)
	var out: Array = []
	for step in ActorSteps.ORDER:
		for sc in _actor.scopes_of(step):
			if _actor.state_of(step, sc) != again.state_of(step, sc):
				out.append("%s|%s %s, not %s" % [step, sc, again.state_of(step, sc), _actor.state_of(step, sc)])
	return out


## Tick the runner until it stops.
func _spin(b: ActorBuilder) -> void:
	for i in 200:
		b.tick()
		if not b.running and not b.busy():
			return


func _before(a: String, b: String) -> bool:
	return _made.has(a) and _made.has(b) and _made.find(a) < _made.find(b)


## Every file under [param dir] with its time - the author's library, to see it untouched.
func _listing(dir: String) -> Dictionary:
	var out := {}
	var d := DirAccess.open(dir)
	if d == null:
		return out
	for f in d.get_files():
		out[dir.path_join(f)] = FileAccess.get_modified_time(dir.path_join(f))
	for sub in d.get_directories():
		out.merge(_listing(dir.path_join(sub)))
	return out
