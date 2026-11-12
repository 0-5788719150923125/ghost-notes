extends SceneTree

## The gate of an episode's direction ([Direction] at the table: [method TableProducer._take_direction], [method
## TableProducer.with_direction]; next/direction.md). No writer runs: the producer's steps are called as Generate calls them.
##
##   godot --headless --path . --script res://tests/table_show/direction_step_check.gd
##
## - a new episode takes the direction up: Generate on an episode with no plan writes the card's words into it as its first step, the
##   author's, and the plan is made from it. The control: given none, an episode has no such step, and nothing waits on one.
## - every agent behind it is told it, above the brief: the system prompt of every text job carries the episode's direction and the
##   words that put it first (the control: an episode with none is told nothing more).
## - a made episode keeps its own: the card changed for the next episode leaves a planned one's as it was. Taken up again (its row's
##   ⟳), the new words stand and the plan made from the old goes stale; an episode made before there were directions never does.

var _fails := 0
const ROOT := "user://direction_step_check"


func _init() -> void:
	_run.call_deferred()


func _ok(cond: bool, what: String) -> void:
	if not cond:
		_fails += 1
		print("  FAIL: " + what)


func _run() -> void:
	await process_frame
	for check in [_taken_up, _told, _kept]:
		var done: Variant = (check as Callable).call()
		_ok(done == true, "%s stopped part way (a script error - see above)" % (check as Callable).get_method())
	_wipe(ProjectSettings.globalize_path(ROOT))
	print("direction_step_check: %s (%d failure%s)" % ["ALL OK" if _fails == 0 else "FAILED", _fails, "" if _fails == 1 else "s"])
	quit(1 if _fails > 0 else 0)


func _wipe(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for d in DirAccess.get_directories_at(path):
		_wipe(path.path_join(d))
	for f in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(f))
	DirAccess.remove_absolute(path)


func _episode(seed: int) -> TableEpisode:
	TableEpisode.root = ROOT
	var ep := TableEpisode.open("direction-show", seed)
	_wipe(ep.dir)
	return ep


const SAID := "Explain a Turing machine: a tape, a head, a table of rules."


func _taken_up() -> bool:
	var ep := _episode(1)
	var prod := TableProducer.new(ep, {"title": "Theorem-Grooving", "brief": "a desk", "direction": SAID})
	prod._take_direction()
	_ok(ep.direction() == SAID and ep.steps()[0] == "direction" and ep.needs("plan") == ["direction"],
		"a new episode takes the direction up as its first step, and its plan is made from it (%s)" % str(ep.steps().slice(0, 3)))
	_ok(String(ep.record("direction").get("by", "")) == "author", "it is the author's (%s)" % str(ep.record("direction")))
	var bare := _episode(2)
	TableProducer.new(bare, {"title": "Theorem-Grooving", "brief": "a desk", "direction": "  "})._take_direction()
	_ok(not bare.has("direction") and bare.steps()[0] == "plan" and bare.needs("plan").is_empty(),
		"CONTROL: an episode given no direction has no such step, and nothing waits on one")
	return true


func _told() -> bool:
	var ep := _episode(3)
	var prod := TableProducer.new(ep, {"direction": SAID})
	prod._take_direction()
	var sys := prod.with_direction("You are the producer.")
	_ok(sys.begins_with("You are the producer.") and sys.contains(SAID) and sys.contains("follow the direction"),
		"every agent behind it is told the direction, and that it comes first")
	var bare := _episode(4)
	_ok(TableProducer.new(bare, {}).with_direction("You are the producer.") == "You are the producer.",
		"CONTROL: an episode with none is told nothing more")
	return true


func _kept() -> bool:
	var ep := _episode(5)
	TableProducer.new(ep, {"direction": SAID})._take_direction()
	ep.write_json("plan", {"episode_title": "What a Tape Can Do"})
	ep.note_made("plan", "producer", ep.made_from("plan"))
	var next := TableProducer.new(ep, {"direction": "Explain the halting problem."})
	next._take_direction()
	_ok(ep.direction() == SAID and not ep.stale("plan"), "a made episode keeps its own when the card changes for the next")
	next.again = ["direction"]
	next._make("direction")
	_ok(ep.direction() == "Explain the halting problem." and ep.stale("plan"),
		"taken up again, the new words stand and the plan made from the old goes stale")
	var old := _episode(6)
	old.write_json("plan", {"episode_title": "Made Before"})
	old.note_made("plan", "producer", old.made_from("plan"))
	_ok(not old.stale("plan") and not old.has("direction"), "an episode made before there were directions never goes stale for one")
	return true
