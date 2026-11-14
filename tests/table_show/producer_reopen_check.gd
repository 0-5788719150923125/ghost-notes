extends Node

## producer_reopen_check - Generate goes on through a table show's note opened again, through the real main scene, with a notes
## folder and episodes of the gate's own (`NoteStore.root`, `TableEpisode.root`). No agent runs: an episode being made is its
## producer marked running with a job of its own.
##
##   tests/run_boot_probe.sh tests/table_show/producer_reopen_check.gd 180
##
## - Desk picked on the Medium card opens the note again (the control: a panel built anew), and its Table card takes up the
##   producer still making the episode, with Generate walking on; Table picked back, the same again.
## - The note left for the list stops what was being made (the control: going is not opening again).

const ROOT := "user://producer_reopen_check"
const EPISODES := "user://producer_reopen_check_episodes"

var _main: Node
var _fails := 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	_clean()
	NoteStore.root = ROOT
	NoteStore.discard = func(p: String) -> int: return DirAccess.remove_absolute(p)
	TableEpisode.root = EPISODES
	DirAccess.make_dir_recursive_absolute(ROOT)
	var path := ProjectSettings.globalize_path(ROOT).path_join("reopen.md")
	FrontMatter.create(path, {"table": {"show": "reopen", "seed": 7}}, "A show at a table.\n", "", FrontMatter.KEY, {"title": "Reopen"})
	_main = preload("res://scenes/main.tscn").instantiate()
	add_child(_main)
	await _frames(20)
	_main.open_note(path)
	await _frames(20)
	var editor := _main._generative as ReadingPanel
	var card: Object = editor._block_cards.get("table") if editor != null else null
	_ok(card != null and card._episode != null, "the table show's note opens on its episode")
	if card == null:
		return _report()
	var p: TableProducer = card._producer
	p.running = true
	p._jobs["table"] = "producer_reopen_check"
	TableProducer._live[p.episode.dir] = p
	editor.pipeline().generate()
	_ok(editor.pipeline().walking(), "Generate walks, waiting on the episode being made")
	for fmt in ["desk", "table"]:
		var medium := _medium_card(editor)
		_ok(medium != null and medium._keys.has(fmt), "the Medium card offers %s" % fmt)
		if medium == null:
			return _report()
		medium._pick(medium._keys.find(fmt))
		await _frames(20)
		var next := _main._generative as ReadingPanel
		var took: Object = next._block_cards.get("table") if next != null else null
		_ok(next != null and next != editor and took != null and took != card,
			"%s picked: the note opens again, a panel built anew (control)" % fmt)
		if took == null:
			return _report()
		_ok(took._producer == p and p.holder == took and p.running and p.busy(),
			"...whose Table card takes up the producer still making the episode")
		_ok(next.pipeline().walking(), "...and Generate walks on")
		editor = next
		card = took
	_main._end_session()
	await _frames(10)
	_ok(not p.running and not p.busy(), "the note left for the list stops what was being made (control: going is not opening again)")
	_report()


func _medium_card(editor: ReadingPanel) -> MediumCard:
	var c: Variant = editor._block_cards.get(MediumCard.KEY)
	return c as MediumCard if c is MediumCard else null


func _ok(cond: bool, what: String) -> void:
	print(("  ok    " if cond else "  FAIL  ") + what)
	if not cond:
		_fails += 1


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _report() -> void:
	NoteStore.discard = Callable()
	TableEpisode.root = TableEpisode.ROOT
	_clean()
	print("producer_reopen_check: %s" % ("ALL OK" if _fails == 0 else "%d FAILED" % _fails))
	get_tree().quit(0 if _fails == 0 else 1)


func _clean() -> void:
	for dir in [ROOT, EPISODES]:
		_rmrf(ProjectSettings.globalize_path(dir))


func _rmrf(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for d in DirAccess.get_directories_at(path):
		_rmrf(path.path_join(d))
	for f in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(f))
	DirAccess.remove_absolute(path)
