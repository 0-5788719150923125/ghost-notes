extends Node

## Not a gate, and it spends quota: a real game, played (next/tabletop.md): real agents plan the night, prepare it and play its opening stretches through the real tools, with real players asked, on a stand-in table so nothing is painted. To read what comes of a brief and the rules, in words, before anything is drawn. Into a folder of its own: never the author's episodes.
##
##   tests/run_boot_probe.sh tests/table_show/game_play_probe.gd 3000 --brief <file.md> --out <dir> [--scenes 2] [--seed 7] [--writer-effort high]
##
## Run from a shell that is not itself inside an agent CLI: `env -u CLAUDECODE -u CLAUDE_CODE_ENTRYPOINT ...`.

var producer: TableProducer
var episode: TableEpisode
var out := ""
var want: Array = []
var began := 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var brief_path := ""
	var scenes := 2
	var seed_value := 7
	var effort := "high"
	for i in args.size() - 1:
		match args[i]:
			"--brief":
				brief_path = args[i + 1]
			"--out":
				out = args[i + 1]
			"--scenes":
				scenes = int(args[i + 1])
			"--seed":
				seed_value = int(args[i + 1])
			"--writer-effort":
				effort = args[i + 1]
	if brief_path.is_empty() or out.is_empty():
		push_error("game_play_probe: --brief and --out")
		get_tree().quit(2)
		return
	DirAccess.make_dir_recursive_absolute(out)
	AgentJobs.allow_for_tool(true)
	TableEpisode.root = out
	var src := FileAccess.get_file_as_string(brief_path)
	var voices := Manuscript._rx("(?m)^      ([A-Z][A-Za-z ]+):\\s*$").search_all(src).map(func(m: RegExMatch) -> String: return m.get_string(1))
	var body := Manuscript.strip_frontmatter(src)
	var title := body.get_slice("\n", 0).trim_prefix("# ").strip_edges()
	print("game_play_probe: at the table: %s" % str(voices))
	episode = TableEpisode.open("game-play", seed_value)
	DirAccess.make_dir_recursive_absolute(episode.dir)
	producer = TableProducer.new(episode, {"title": title, "byline": "", "uploads_as": "", "brief": TablePrompts.brief(body), "deck": [], "chooses": false, "voices": voices, "seats": {},
		"writer": "claude", "writer_model": "", "writer_effort": effort, "painter": "codex", "painter_model": "", "painter_effort": "", "players": "claude", "players_model": "", "players_effort": "low"})
	want = ["plan", "draw", "prep", "say:intro"]
	for k in range(1, scenes + 1):
		want.append("say:%d" % k)
	# ...a table that stands in: nothing is made from it in words
	episode.write_json("table", {"things": []})
	began = Time.get_ticks_msec()
	producer.start(want)
	set_process(true)


func _process(_d: float) -> void:
	if producer == null:
		return
	AgentJobs.pump()
	producer.tick()
	var left := want.filter(func(s: String) -> bool: return not episode.has(s))
	var errors := PackedStringArray()
	for s in want:
		var e := producer.error_of(String(s))
		if not e.is_empty():
			errors.append("%s: %s" % [s, e])
	if left.is_empty() or not errors.is_empty() or (not producer.running and producer._jobs.is_empty()):
		producer.stop()
		_report(errors)
		producer = null
		get_tree().quit(0 if errors.is_empty() else 1)


func _report(errors: PackedStringArray) -> void:
	print("game_play_probe: done in %d s" % ((Time.get_ticks_msec() - began) / 1000))
	for e in errors:
		print("game_play_probe: ERROR %s" % e)
	print("game_play_probe: folder %s" % episode.dir)
	var f := FileAccess.open(out.path_join("transcript.txt"), FileAccess.WRITE)
	if f == null:
		return
	for s in want:
		if String(s).begins_with("say:") and episode.has(String(s)):
			var heard := FileAccess.get_file_as_string(episode.dir.path_join("heard_%s.txt" % String(s).trim_prefix("say:")))
			f.store_string("--- %s ---\n%s\n\n" % [s, heard])
	f.close()
