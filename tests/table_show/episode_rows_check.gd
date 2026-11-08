extends SceneTree

## episode_rows_check - an episode of a table show, as rows of the note's Pipeline card ([EpisodeCard.Section];
## next/pipeline.md; the user, 2026-11-02: "every distinct regeneration action should just be a part of the pipeline list").
##
##   godot --headless --path . --script tests/table_show/episode_rows_check.gd
##
## EVERY STEP THE EPISODE HAS IS A ROW (THE CONTROL: the fixture has steps) and no menu stands anywhere on the card or the list; a
## card's rows stand under its name. EVERY ⟳ SAYS ONE THING, each its own.
## WHAT THROWS OTHER FINISHED WORK AWAY SAYS SO: Plan asks first, naming what goes - the stray click the menu had guarded -
## and a new Cloth does not (THE CONTROL), for its depth is remade with it, nor the Close, for the script is only the readings put
## together. And only when that work exists (THE CONTROL: the same row, on an episode with nothing made after it, asks nothing).
## A ⟳ ONLY WHAT CAN START: one whose inputs are not made is not offered, saying so (it had been passed by without a word).
## While the episode is being made every ⟳ waits. Pressed and answered, the step and what was made from it go.
## WHAT IT TAKES WITH IT IS WORKED OUT ONCE, the same as [method TableEpisode.dependents] says for every step (THE CONTROL: a
## card's painting takes its reading), and read again only when the episode's files change (THE CONTROL: a new file).

const ROOT := "user://episode_rows_check"

var _fails := 0
var _ed: Object
var _show: Object
var _pipe: Object
var _ep: Object


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var settings := root.get_node_or_null("Settings")
	if settings != null:
		settings.set("_read_only", true)
	var episodes: GDScript = load("res://src/table_show/table_episode.gd")
	var was: String = episodes.root
	episodes.root = ROOT
	_ed = load("res://src/reading/reading_panel.gd").new()
	_ed.workspace = "table"
	_ed._build_panel()
	_ed._doc._sync = false
	_ed._doc._fields = {"title": "Rows"}
	_show = _ed._block_cards["table"]
	_pipe = _ed.pipeline()
	_show._knobs["show"] = "rows"
	_show._knobs["seed"] = 5
	_show._open_episode()
	_ep = _show._episode
	_check()
	_ed.free()
	episodes.root = was
	_rmrf(ProjectSettings.globalize_path(ROOT))
	print("episode_rows_check: %s" % ("ALL OK" if _fails == 0 else "%d FAILED" % _fails))
	quit(0 if _fails == 0 else 1)


func _ok(cond: bool, what: String) -> void:
	print(("  ok    " if cond else "  FAIL  ") + what)
	if not cond:
		_fails += 1


## [param steps], made: their files, as the episode finds them.
func _write(steps: Array) -> void:
	for s in steps:
		var path: String = _ep.file_of(String(s))
		DirAccess.make_dir_recursive_absolute(path.get_base_dir())
		var f := FileAccess.open(path, FileAccess.WRITE)
		f.store_string("{}" if path.ends_with(".json") else "Some words here.")
		f.close()


func _redo(key: String) -> Button:
	return _pipe.row(key)["redo"]


func _check() -> void:
	_ep.write_json("plan", {"episode_title": "Rows", "spread": {"positions": [{"name": "Past"}, {"name": "Future"}]}})
	_write(["image:surface", "image:backdrop"])
	_pipe.refresh()
	# EVERY STEP IS A ROW
	var missing := []
	var all: Array = _ep.steps()
	for s in all:
		if _pipe.row(String(s)).is_empty():
			missing.append(s)
	_ok(all.size() > 10 and missing.is_empty(), "every one of the episode's %d steps is a row (not: %s)" % [all.size(), str(missing)])
	_ok(_menus(_show) == 0 and _menus(_pipe) == 0, "no menu on the card or the list")
	_ok(_pipe.group_names().has("Card 1") and _pipe.group_names().has("Table"), "a card's rows stand under its name: %s" % str(_pipe.group_names()))
	var says := {}
	for key in ["plan", "image:surface", "image:backdrop", "table", "say:intro", "design:1", "image:card:1", "say:1", "say:close"]:
		says[_redo(key).tooltip_text] = true
	_ok(says.size() == 9, "every ⟳ says one thing, each its own: %s" % str(says.keys()))
	_ok(_redo("draw").modulate.a == 0.0 and _redo("script").modulate.a == 0.0,
		"a step that cannot be made again by itself has none: the draw is the seed's, the script its readings'")

	# WHAT IT THROWS AWAY
	_ok(not _pipe.asks_first("say:intro") and not _redo("say:intro").tooltip_text.contains("throws away"),
		"control: with nothing made from it yet, its ⟳ asks nothing - the same row asks once there is")
	_ep.write_json("draw", {"cards": [{"name": "The Tower", "key": "tower"}, {"name": "The Moon", "key": "moon"}], "deck_n": 78})
	_write(["design:1", "image:back", "table", "image:height", "image:card:1", "check:1", "say:intro", "say:1", "say:2",
		"say:close", "script"])
	_pipe.refresh()
	var plan := _redo("plan")
	_ok(_pipe.asks_first("plan") and plan.tooltip_text.contains("Card 1 Design") and plan.tooltip_text.contains("more"),
		"Plan throws the episode away: it asks, saying what (%s)" % plan.tooltip_text.replace("\n", " "))
	_ok(_pipe.asks_first("image:card:1") and _redo("image:card:1").tooltip_text.contains("Card 1 Reading"),
		"a painting throws its reading away, and says so")
	_ok(_pipe.asks_first("say:intro"), "the intro, asking nothing a moment ago, now has readings to take with it")
	_ok(not _pipe.asks_first("image:surface") and not _pipe.asks_first("image:backdrop"),
		"control: a new cloth or room keeps the table, and its depth is remade with it: it does not ask")
	_ok(not _pipe.asks_first("say:close"), "control: the close takes only the script, which is the readings put together: it does not ask")

	# A ⟳ ONLY WHAT CAN START
	DirAccess.remove_absolute(_ep.file_of("say:1"))
	_pipe.refresh()
	_ok(_redo("say:2").disabled and _redo("say:2").tooltip_text.contains("once what it is made from is made") and not _redo("say:intro").disabled,
		"one whose inputs are not made is not offered, saying so (the control: the intro, whose are, is)")
	_write(["say:1"])
	_pipe.refresh()

	# WHILE IT IS MADE
	_ok(not plan.disabled, "made and idle, its ⟳ is offered")
	_show._producer.running = true
	_pipe.refresh()
	_ok(plan.disabled and _redo("say:close").disabled, "while the episode is being made, every ⟳ waits")
	_show._producer.running = false

	# ONCE, AND THE SAME
	var map: Dictionary = _ep.all_dependents()
	var differs := []
	for s in map:
		var a: Array = (map[s] as Array).duplicate()
		var b: Array = _ep.dependents(String(s)).duplicate()
		a.sort()
		b.sort()
		if a != b:
			differs.append(s)
	_ok(differs.is_empty() and (map["image:card:1"] as Array).has("say:1"),
		"what each takes with it, worked out at once, is what TableEpisode.dependents says of every step (a painting takes its reading)")
	var kept: Dictionary = _show._facts()
	_pipe.refresh()
	_ok(is_same(_show._facts(), kept), "unchanged, the episode's files are not read again")
	_write(["acts"])
	_ok(not is_same(_show._facts(), kept), "the control: a new file, and they are")
	DirAccess.remove_absolute(_ep.file_of("acts"))

	# PRESSED AND ANSWERED
	_pipe.refresh()
	_redo("image:card:1").pressed.emit()
	_ok(_ep.has("image:card:1") and _pipe.asking != null, "pressed: it asks, nothing thrown away yet")
	_pipe.asking.canceled.emit()
	_ok(_ep.has("image:card:1") and _ep.has("say:1"), "no: all still there")
	_redo("image:card:1").pressed.emit()
	_pipe.asking.confirmed.emit()
	_ok(not _ep.has("image:card:1") and not _ep.has("say:1") and _ep.has("design:1") and _ep.has("image:surface"),
		"yes: the painting and what was made from it go; what it was made from stays")
	_pipe.refresh()
	_ok(_show._section.told.contains("read-only"), "a read-only process makes nothing, and says so over the rows")


func _menus(node: Node) -> int:
	var n := 1 if node is MenuButton else 0
	for c in node.get_children():
		n += _menus(c)
	return n


func _rmrf(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for f in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(f))
	for d in DirAccess.get_directories_at(path):
		_rmrf(path.path_join(d))
	DirAccess.remove_absolute(path)
