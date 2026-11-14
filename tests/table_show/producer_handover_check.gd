extends SceneTree

## producer_handover_check - one producer per episode ([method TableProducer.of]), carried across its note opened again
## ([method TableProducer.hand_over], [member ReadingPanel.reopening]). No agent runs: a run under way is a producer marked
## running with a job of its own.
##
##   godot --headless --path . --script tests/table_show/producer_handover_check.gd
##
## - The producer making an episode is the one asked for it (the control: with none making it, each ask is a new one; another
##   episode has its own).
## - Handed over, it goes on making what it was asked: taken up, it is never stopped; left untaken, it stops and is let go (the
##   control). One with nothing under way stops at once.
## - The Table card takes up the producer making its episode: a panel built anew over the note holds the same producer, still
##   running, and the card it replaced going leaves it so (the control: a card going while its note is not opened again stops
##   what it holds) - whichever goes first. Another episode opened stops it (the control: the same one opened again does not).

const ROOT := "user://producer_handover_check"

var _fails := 0
var _panels: Array = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var settings := root.get_node_or_null("Settings")
	if settings != null:
		settings.set("_read_only", true)
	var was := TableEpisode.root
	TableEpisode.root = ROOT
	for check in [_one_per_episode, _handed_over, _taken_up_by_the_card]:
		var done: Variant = (check as Callable).call()
		_ok(done == true, "%s ran to its end (not: a script error - see above)" % (check as Callable).get_method())
	for p in _panels:
		(p as Node).free()
	TableEpisode.root = was
	_rmrf(ProjectSettings.globalize_path(ROOT))
	print("producer_handover_check: %s" % ("ALL OK" if _fails == 0 else "%d FAILED" % _fails))
	quit(0 if _fails == 0 else 1)


func _ok(cond: bool, what: String) -> void:
	print(("  ok    " if cond else "  FAIL  ") + what)
	if not cond:
		_fails += 1


## [param p] marked as making its episode: running, with a job of its own (an id the queue does not hold, so nothing lands).
func _making(p: TableProducer) -> void:
	p.running = true
	p._jobs["table"] = "producer_handover_check"
	TableProducer._live[p.episode.dir] = p


func _one_per_episode() -> bool:
	var ep := TableEpisode.open("handover", 1)
	_ok(TableProducer.of(ep) != TableProducer.of(ep), "control: with none making it, each ask is a new producer")
	var p := TableProducer.of(ep)
	_making(p)
	_ok(TableProducer.of(TableEpisode.open("handover", 1)) == p, "the producer making an episode is the one asked for it")
	_ok(TableProducer.of(TableEpisode.open("handover", 2)) != p, "control: another episode has its own")
	p.stop()
	_ok(not p.running and TableProducer.of(ep) != p, "stopped, it is let go: the next ask is a new one")
	return true


func _handed_over() -> bool:
	var ep := TableEpisode.open("handover", 3)
	var p := TableProducer.of(ep)
	var first := RefCounted.new()
	var second := RefCounted.new()
	p.holder = first
	_making(p)
	p.hand_over()
	_ok(p.holder == null and p.running and p.busy() and TableProducer.of(ep) == p,
		"handed over, it goes on making what it was asked, and is the one asked for its episode")
	p.holder = second
	p.unclaimed()
	_ok(p.running and p.busy(), "taken up by the card the note came up with, it is never stopped")
	p.hand_over()
	p.unclaimed()
	_ok(not p.running and not p.busy() and TableProducer.of(ep) != p, "control: left untaken, it stops and is let go")
	var idle := TableProducer.of(TableEpisode.open("handover", 4))
	idle.hand_over()
	_ok(not idle.running and TableProducer.of(TableEpisode.open("handover", 4)) != idle,
		"one with nothing under way stops at once")
	return true


## A reading panel built by hand, as the app builds one around a table show's note, with its Table card on episode [param seed].
func _panel(seed: int) -> Array:
	var ed: Object = load("res://src/reading/reading_panel.gd").new()
	ed.workspace = "table"
	ed._build_panel()
	ed._doc._sync = false
	ed._doc._fields = {"title": "Handover"}
	_panels.append(ed)
	var card: Object = ed._block_cards["table"]
	card._knobs["show"] = "handover"
	card._knobs["seed"] = seed
	card._open_episode()
	return [ed, card]


func _taken_up_by_the_card() -> bool:
	# the note opened again: the new panel is built while the old one is still up, and the old card goes after
	var a := _panel(5)
	var p: TableProducer = a[1]._producer
	_ok(p.holder == a[1], "the card holds the producer of its episode")
	_making(p)
	a[0].reopening = true
	var b := _panel(5)
	_ok(b[1]._producer == p and p.holder == b[1], "a panel built anew over the note takes up the producer making its episode")
	a[1]._exit_tree()
	_ok(p.running and p.busy() and p.holder == b[1], "the card it replaced going leaves it making what it was asked")
	# ...and the other way round: the old card goes first, handing it over, and the new one takes it up
	b[0].reopening = true
	b[1]._exit_tree()
	_ok(p.running and p.holder == null, "a card going while its note is opened again hands it over, still making")
	var c := _panel(5)
	_ok(c[1]._producer == p and p.holder == c[1] and p.running, "the card the note comes up with takes it up")
	# the same episode opened again keeps it; another stops it
	c[1]._open_episode()
	_ok(c[1]._producer == p and p.running, "control: the same episode opened again goes on being made")
	c[1]._knobs["seed"] = 6
	c[1]._open_episode()
	_ok(not p.running and not p.busy() and c[1]._producer != p, "another episode opened stops it")
	# a card going while its note is not opened again stops what it holds
	var q: TableProducer = c[1]._producer
	_making(q)
	c[1]._exit_tree()
	_ok(not q.running and not q.busy(), "control: a card going while its note is not opened again stops what it holds")
	return true


func _rmrf(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for d in DirAccess.get_directories_at(path):
		_rmrf(path.path_join(d))
	for f in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(f))
	DirAccess.remove_absolute(path)
