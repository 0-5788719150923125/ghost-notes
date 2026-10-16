extends SceneTree

## text_walk_check - what a reading reads: the note's own words, or what a component hands it.
##
##   godot --headless --path . --script tests/reading/text_walk_check.gd
##
## A NOTE'S OWN WALK reads the note: its words pass through, its title is announced, and a tablet
## chapter is read off its screen (no title, the marks out). CARDS' WALK reads the EPISODE, never
## the brief: the words, the cast's text and the fingerprint are the episode's script, its table
## marks are not spoken, no title is announced, and with no episode up there is nothing to read.
## Two-sided: the brief is handed in every time and must never come back out of Cards' walk, and
## the plain note must come back out of the note's walk unchanged - a walk that returned a constant
## would pass neither.
##
## READ-ONLY: the episode lives under `CardEpisode.root` set to a folder of this gate's own, and is
## thrown away through `CardEpisode.discard`. The walks are loaded by path after the tree is up:
## named here, they would be compiled with this gate before the autoloads their scripts name exist.

var _fails: Array = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var walk_script := load("res://src/reading/text_walk.gd") as GDScript
	var episode_walk := load("res://src/cards/episode_walk.gd") as GDScript
	var episodes := load("res://src/cards/card_episode.gd") as GDScript

	print("-- the note's own walk")
	var own: RefCounted = walk_script.new()
	var note := "A plain chapter.\n\nIt has two paragraphs."
	_ok(own.body(note) == note, "the note's walk changed the note it was handed")
	var said: Dictionary = own.spoken(note, "The Title")
	_ok(said["body"] == note and said["title"] == "The Title", "a plain chapter is read as written, its title announced")
	var tablet := "<!-- url: example.com -->\nA page about stars."
	var read: Dictionary = own.spoken(tablet, "The Title")
	_ok(read["title"] == "" and not String(read["body"]).contains("url:"),
		"a tablet chapter is read off its screen: no title, no marks (got %s)" % str(read))
	_ok(own.cast_text("the text") == "the text", "the cast comes from the note's own text")
	_ok(own.test_passage("fallback") == "fallback", "the note's walk auditions with the panel's own passage")
	_ok(own.reads_source(), "an edit to the note leaves the note's reading out of date")

	print("-- Cards' walk")
	var root_was: String = episodes.get("root")
	var discard_was: Callable = episodes.get("discard")
	episodes.set("root", "user://text_walk_check")
	episodes.set("discard", func(path: String) -> void: _remove(path))
	var ep: RefCounted = episodes.call("open", "walk", 1)
	DirAccess.make_dir_recursive_absolute(ep.get("dir"))
	var script := "<!-- table: draw 1 -->\nThe first card is the Fool."
	var f := FileAccess.open(ep.call("file_of", "script"), FileAccess.WRITE)
	f.store_string(script)
	f.close()
	var cards: RefCounted = episode_walk.new(func() -> RefCounted: return ep)
	var brief := "THE BRIEF: tarot, 78 cards."
	_ok(cards.body(brief) == script, "Cards' walk read %s, not the episode's script" % cards.body(brief).left(40))
	_ok(cards.cast_text(brief) == script, "the cast comes from the episode, not the brief")
	var spoken: Dictionary = cards.spoken(script, "The Title")
	_ok(spoken["title"] == "" and not String(spoken["body"]).contains("table:")
		and String(spoken["body"]).contains("Fool"),
		"the episode is read without its table marks or a title (got %s)" % str(spoken))
	_ok(cards.test_passage("fallback") != "fallback", "Cards auditions a voice with its own passage")
	_ok(not cards.reads_source(), "an edit to the brief changed the reading of the episode up now")
	var none: RefCounted = episode_walk.new(func() -> RefCounted: return null)
	_ok(none.body(brief) == "" and none.cast_text(brief) == "",
		"CONTROL: with no episode up there is nothing to read - and never the brief")
	_remove(ProjectSettings.globalize_path("user://text_walk_check"))
	episodes.set("root", root_was)
	episodes.set("discard", discard_was)

	if _fails.is_empty():
		print("text_walk_check: ALL OK")
		quit(0)
		return
	for x in _fails:
		print("text_walk_check: FAIL - ", x)
	quit(1)


func _ok(cond: bool, msg: String) -> void:
	print(("  ok    " if cond else "  FAIL  ") + msg)
	if not cond:
		_fails.append(msg)


func _remove(path: String) -> void:
	var at := ProjectSettings.globalize_path(path)
	if not DirAccess.dir_exists_absolute(at):
		return
	for d in DirAccess.get_directories_at(at):
		_remove(at.path_join(d))
	for x in DirAccess.get_files_at(at):
		DirAccess.remove_absolute(at.path_join(x))
	DirAccess.remove_absolute(at)
