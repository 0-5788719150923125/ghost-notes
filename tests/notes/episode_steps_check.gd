extends SceneTree

## episode_steps_check - the steps the note's other cards add, as the card that lists them runs them
## ([EpisodeSteps]; 2026-10-28: every card that listed them kept a copy of this, and the Letter's none).
##
##   godot --headless --path . --script tests/notes/episode_steps_check.gd
##
## WHAT IS LISTED: a step the card offering it wants, for an episode kept somewhere (THE CONTROLS: one not
## wanted, an episode with no folder, none at all). GENERATE WAITS FOR THE CARD'S OWN STEPS: asked while they
## run, nothing is made and the ask is kept (the control); once they are done the step is made - here its
## prompt is empty, so it fails at once with no agent - each listed step told who lists it and what makes its
## episode. MISSING until made from the episode's words as they are, and its name with it. STOP clears the ask
## for the episode shown, never for another (the control), and stops a job. A CARD FREED UNDER THEM offers
## nothing.
## Each step here is the gate's own and starts no agent; what it keeps is under a scratch folder.

const ROOT := "user://episode_steps_check"

var _fails := 0


func _init() -> void:
	# deferred: a step reads AgentJobs, up once the tree is
	_run.call_deferred()


func _run() -> void:
	_check()
	_rmrf(ProjectSettings.globalize_path(ROOT))
	print("episode_steps_check: %s" % ("ALL OK" if _fails == 0 else "%d FAILED" % _fails))
	quit(0 if _fails == 0 else 1)


func _ok(cond: bool, what: String) -> void:
	print(("  ok    " if cond else "  FAIL  ") + what)
	if not cond:
		_fails += 1


func _check() -> void:
	var step = _script("""extends "res://src/notes/episode_step.gd"
var on := true
func _init() -> void:
	key = "stub"
	label = "Stub"
func wanted() -> bool:
	return on
""").new()
	var feed = _feed("one", "Some words.")
	var other = _feed("two", "Other words.")
	var steps = load("res://src/notes/episode_steps.gd").new("the Stub card", func() -> Array: return [step],
		"Generate, or an export")

	# WHAT IS LISTED
	_ok(steps.listed(feed) == [step] and steps.key(feed) == "stub", "a step wanted, for an episode kept somewhere, is listed")
	step.on = false
	var unwanted: Array = steps.listed(feed)
	step.on = true
	_ok(unwanted.is_empty() and steps.listed(_feed("", "Some words.")).is_empty() and steps.listed(null).is_empty(),
		"control: one not wanted, an episode with no folder or none at all lists nothing")

	# GENERATE WAITS FOR THE CARD'S OWN STEPS
	steps.asked = true
	steps.tick(feed, true)
	_ok(steps.asked and step.state(feed) == "missing" and step.host == "the Stub card" and step.shown == feed
		and step.host_makes == "Generate, or an export",
		"control: while the card's own steps run, nothing is made and the ask is kept - the step told where it is listed")
	_ok(steps.missing(feed) and steps.names(feed, true) == PackedStringArray(["stub"]), "not made: missing, and named")
	steps.tick(feed, false)
	_ok(not steps.asked and step.state(feed) == "failed" and String(step.said(feed)).contains("prompt"),
		"once they are done it is made (%s)" % step.said(feed))

	# MADE FROM THE WORDS AS THEY ARE
	step._errors.clear()
	_ok(step._write(feed, {"from": feed.stamp()}).is_empty() and not steps.missing(feed)
		and steps.names(feed, true).is_empty() and steps.names(feed) == PackedStringArray(["stub"]),
		"made from the episode's words: no longer missing, and named only when every one is asked for")

	# STOP
	steps.asked = true
	steps.stop(other, feed)
	_ok(steps.asked, "control: stopping another episode than the one shown keeps what Generate asked")
	step._jobs[feed.folder()] = {"id": "text-episode-steps-check", "feed": feed, "stamp": feed.stamp()}
	_ok(steps.busy(feed) and not steps.busy(other), "a job making it for one episode is busy for that one alone")
	steps.stop(feed, feed)
	_ok(not steps.asked and not steps.busy(feed), "stopping the one shown clears the ask and stops its job")

	# A CARD FREED UNDER THEM
	var holder = _script("""extends RefCounted
var held: Array = []
func offered() -> Array:
	return held
""").new()
	holder.held = [step]
	var gone = load("res://src/notes/episode_steps.gd").new("the Gone card", Callable(holder, "offered"))
	var before: Array = gone.offered()
	holder = null
	_ok(before == [step] and gone.offered().is_empty() and gone.listed(feed).is_empty(),
		"what a card freed under them offered is gone with it (control: offered while it was up)")


## An episode of the gate's own, kept in [param name] under the scratch folder ("" for none), saying [param words].
func _feed(name: String, words: String) -> Object:
	var f = _script("""extends "res://src/notes/episode_feed.gd"
var dir := ""
var said := ""
func folder() -> String:
	return dir
func words() -> String:
	return said
""").new()
	f.dir = ProjectSettings.globalize_path(ROOT).path_join(name) if not name.is_empty() else ""
	f.said = words
	return f


func _script(source: String) -> GDScript:
	var g := GDScript.new()
	g.source_code = source
	g.reload()
	return g


func _rmrf(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for f in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(f))
	for d in DirAccess.get_directories_at(path):
		_rmrf(path.path_join(d))
	DirAccess.remove_absolute(path)
