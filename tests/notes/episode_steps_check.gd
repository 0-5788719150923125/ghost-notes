extends SceneTree

## episode_steps_check - what one card makes from the episode another makes, as a section of the note's Pipeline card
## ([EpisodeSteps], [PipelineSection]; next/pipeline.md).
##
##   godot --headless --path . --script tests/notes/episode_steps_check.gd
##
## WHAT IS LISTED: a step the card offering it wants, for an episode kept somewhere (THE CONTROLS: one not wanted, an episode
## with no folder, none at all), and the section is shown only while something is. THE EPISODE IS THE PANEL'S TO SAY: each
## tick says it to the steps listed. IT MAKES WHAT IS MISSING - here its prompt is empty, so it fails at once with no agent, and
## says so on its row. Its row: ✓ what it made, its ⟳ waiting for the words (THE CONTROL: words, and it is offered), and a
## step made from words since written again is stale and says what makes it again - the feed's own words for it. STOP stops a
## job; an episode left stops what is being made of it and no other (THE CONTROL). A CARD FREED UNDER THEM offers nothing.
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
	first = "Make it now"
	again = "Make it again"
func wanted() -> bool:
	return on
""").new()
	var feed = _feed("one", "Some words.")
	var other = _feed("two", "Other words.")
	var shown = [feed]
	var steps = load("res://src/notes/episode_steps.gd").new("Stub card", func() -> Array: return [step])
	steps.episode = func() -> Object: return shown[0]

	# WHAT IS LISTED
	_ok(steps.listed(feed) == [step] and steps.shown(), "a step wanted, for an episode kept somewhere, is listed, and the section shown")
	step.on = false
	var unwanted: Array = steps.listed(feed)
	var hid: bool = not steps.shown()
	step.on = true
	_ok(unwanted.is_empty() and hid and steps.listed(_feed("", "Some words.")).is_empty() and steps.listed(null).is_empty(),
		"control: one not wanted, an episode with no folder or none at all lists nothing, and no section")

	# THE EPISODE IS THE PANEL'S TO SAY
	steps.tick()
	_ok(step.shown == feed, "each tick says the episode shown to the steps listed")
	var r: PipelineRow = steps.rows()[0]
	_ok(r.key == "stub" and r.label == "Stub" and r.state == "missing" and r.open and r.again == "Make it now",
		"its row: not made, its ⟳ offered, and saying what it does (%s)" % r.again)
	_ok(steps.missing() and steps.names(feed, true) == PackedStringArray(["stub"]), "not made: missing, and named")

	# WORDS NOT WRITTEN: ITS ⟳ WAITS
	var empty = _feed("three", "")
	shown[0] = empty
	var waits: PipelineRow = steps.rows()[0]
	_ok(not waits.open and waits.again.contains("once there are words"), "with no words, its ⟳ waits and says so")
	shown[0] = feed

	# GENERATE
	steps.make()
	steps.tick()
	r = steps.rows()[0]
	_ok(step.state(feed) == "failed" and r.state == "failed" and r.said.contains("prompt"), "Generate makes it - here refused, said on its row (%s)" % r.said)

	# MADE FROM THE WORDS AS THEY ARE
	step._errors.clear()
	_ok(step._write(feed, {"from": feed.stamp()}).is_empty() and not steps.missing() and steps.names(feed, true).is_empty()
		and steps.names(feed) == PackedStringArray(["stub"]),
		"made from the episode's words: no longer missing, and named only when every one is asked for")
	r = steps.rows()[0]
	_ok(r.state == "made" and r.again == "Make it again" and r.open, "its row: made, and its ⟳ says it makes it again")
	feed.said = "Words written again."
	r = steps.rows()[0]
	_ok(r.state == "stale" and r.said.contains("so does Generate"), "words written again: stale, saying what makes it (%s)" % r.said)
	feed.said = "Some words."
	feed.by = "Generate, or an export that goes up"
	feed.said = "Words written again."
	_ok(String(steps.rows()[0].said).contains("so does Generate, or an export that goes up"), "...in the feed's own words")
	feed.said = "Some words."

	# STOP, AND AN EPISODE LEFT
	step._jobs[feed.folder()] = {"id": "text-episode-steps-check", "feed": feed, "stamp": feed.stamp()}
	_ok(steps.busy() and step.busy(feed) and not step.busy(other), "a job making it for one episode is busy for that one alone")
	r = steps.rows()[0]
	_ok(not r.open and (r.state == "queued" or r.state == "running"), "while it is made, its ⟳ waits")
	steps.episode_left(other)
	_ok(step.busy(feed), "control: another episode left stops nothing of this one")
	steps.episode_left(feed)
	_ok(not step.busy(feed), "this one left: its job stops")
	step._jobs[feed.folder()] = {"id": "text-episode-steps-check-2", "feed": feed, "stamp": feed.stamp()}
	steps.stop()
	_ok(not steps.busy(), "Stop stops it")
	step._jobs[feed.folder()] = {"id": "text-episode-steps-check-3", "feed": feed, "stamp": feed.stamp()}
	steps.leave()
	_ok(not steps.busy(), "the panel going stops it too")

	# A CARD FREED UNDER THEM
	var holder = _script("""extends RefCounted
var held: Array = []
func offered() -> Array:
	return held
""").new()
	holder.held = [step]
	var gone = load("res://src/notes/episode_steps.gd").new("Gone card", Callable(holder, "offered"))
	var before: Array = gone.offered()
	holder = null
	_ok(before == [step] and gone.offered().is_empty() and gone.listed(feed).is_empty(),
		"what a card freed under them offered is gone with it (control: offered while it was up)")


## An episode of the gate's own, kept in [param name] under the scratch folder ("" for none), saying [param words].
func _feed(name: String, words: String) -> Object:
	var f = _script("""extends "res://src/notes/episode_feed.gd"
var dir := ""
var said := ""
var by := "Generate"
func folder() -> String:
	return dir
func words() -> String:
	return said
func made_by() -> String:
	return by
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
