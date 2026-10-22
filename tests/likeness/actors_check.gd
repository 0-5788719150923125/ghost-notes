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
## stills, the stills before the rig, and the rig and the visemes before the library.
## A CHANGED INPUT MARKS STALE: a setting a step reads makes it stale, and only it, until it is made
## again - then what was made from it. ⟳ THROWS A STEP AWAY and makes it again; what is made from it
## directly is stale (and what is made from those, once they are made again). A video unticked makes
## the sets stale. A STILL PICKED changes nothing that is made: the library is the set's.
## A RESTART CHANGES NOTHING: the actor read again from its file finds every step as it was, its videos
## held in an order their ids do not sort in (2026-10-21: `actor.json` was written sorted, read back in
## another order than the stamps were made in, and the user's built set went stale after a restart -
## the sets, the audit and every step of the set made again).
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
	_ok(_made.has("motion|") and _made.has("library|" + s), "Generate left steps unmade: %s" % str(_made))
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
	# A STILL PICKED changes nothing that is made
	_actor.set_still(sid, 1)
	_actor.save()
	_actor.forget()
	_ok(_actor.state_of("library", s) == "made" and _actor.state_of("rig", s) == "made", "picking a still made the set stale")
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
	_ok(_actor.state_of("rig", s) == "stale", "the stills made again left the rig %s" % _actor.state_of("rig", s))
	# ...and what is made from those, once they are made again: one step at a time, never all at once
	_ok(_actor.state_of("library", s) == "made", "the library went stale before the rig was made again")
	# A VIDEO UNTICKED: the sets are stale
	b.make_with = _make
	(_actor.video(String(vids[1])) as Dictionary)["ticked"] = false
	_actor.save()
	_actor.forget()
	_ok(_actor.state_of("sets", "") == "stale", "unticking a video left the sets %s" % _actor.state_of("sets", ""))
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
		if String(f) == "sets.json" or String(f) == "audit.json":
			text = JSON.stringify({"sets": [{"id": "set-made", "usable": 5.0, "minutes": 6.0, "shots": [], "size": [64, 36]}]})
		var fa := FileAccess.open(p, FileAccess.WRITE)
		fa.store_string(text)
		fa.close()
	return ""


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
