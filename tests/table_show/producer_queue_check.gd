extends Node

## Regeneration requests join an episode's active run without canceling jobs or resetting their bookkeeping.
## The real scheduler waits for upstream remakes even through an unchanged intermediate input, deduplicates requests,
## rebuilds the script after the requested reading, and preserves blocked requests for retry or Stop.
## Jobs are held at the producer boundary; no agent runs and every file belongs to this gate.
##
##   tests/run_boot_probe.sh tests/table_show/producer_queue_check.gd 120

const ROOT := "user://producer_queue_check"
var _fails := 0


class HeldProducer extends TableProducer:
	var started: Array = []
	var inputs := {}

	func _init(ep: TableEpisode) -> void:
		super(ep, {"writer": "claude", "brief": "A table show"})

	func _make(step: String) -> void:
		if LOCAL.has(step):
			super._make(step)
			return
		started.append(step)
		_from[step] = episode.made_from(step)
		inputs[step] = _from[step].duplicate(true)
		_jobs[step] = "producer_queue_check_%s_%d" % [step, started.size()]

	func complete(step: String, text: String) -> void:
		_jobs.erase(step)
		if step == "table":
			episode.write_json(step, {"things": [], "revision": text})
		elif step == "acts":
			episode.write_json(step, {"acts": [], "revision": text})
		else:
			episode.write_text(step, text)
		_made(step, "gate")
		tick()


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	AgentJobs.allow_for_tool(false)
	var was := TableEpisode.root
	TableEpisode.root = ROOT
	_clean(ProjectSettings.globalize_path(ROOT))
	_ordered()
	_active_reader()
	_failed_input()
	_missing_input()
	_widened()
	_stale_generation()
	TableEpisode.root = was
	_clean(ProjectSettings.globalize_path(ROOT))
	print("producer_queue_check: %s" % ("ALL OK" if _fails == 0 else "%d FAILED" % _fails))
	get_tree().quit(0 if _fails == 0 else 1)


func _episode(seed_value: int) -> TableEpisode:
	var ep := TableEpisode.open("queue", seed_value)
	ep.write_json("plan", {"episode_title": "Queue", "spread": {"positions": [{"name": "One"}]},
		"staging": {"source": "none"}, "work_intro": "Turn the tile"})
	ep.write_json("draw", {"cards": []})
	ep.write_json("table", {"things": []})
	ep.write_json("acts", {"acts": []})
	for step in ep.steps():
		if not ep.has(String(step)):
			ep.write_text(String(step), "Original words.")
		ep.note_made(String(step), "gate")
	for step in ["table", "acts", "say:1"]:
		ep.set_kept(step, true)
	return ep


func _ordered() -> void:
	var ep := _episode(1)
	var p := HeldProducer.new(ep)
	var intro := ep.digest("say:intro")
	p.start(["table"], true, "Keep storage reachable.")
	var active: String = p._jobs["table"]
	p._tries["table"] = 2
	p._errors["unrelated"] = "Keep this error."
	p.start(["say:1"], true, "Use the revised work.")
	_ok(not ep.needs("say:1").has("table") and not ep.needs("say:1").has("acts") and p.started == ["table"],
		"a reading waits for Set through its unchanged intro and Work inputs")
	p.start(["acts"], true, "Use the revised set.")
	p.start(["acts"], true, "A duplicate request.")
	p.start(["table"], true)
	_ok(p._jobs.get("table") == active and p._tries["table"] == 2 and p._errors.has("unrelated"),
		"further requests leave the active job, retry count and unrelated errors intact")
	_ok(p.again.size() == 3 and p.only.size() == 3 and p.asked["table"] == "Keep storage reachable."
		and p.asked["acts"] == "Use the revised set.", "requests and their notes are deduplicated")
	_ok(p.state_of("acts") == "queued" and p.state_of("say:1") == "queued"
		and ep.read_text("say:1") == "Original words.", "queued requests are visible while existing outputs stay in place")
	p.complete("table", "new set")
	_ok(p.started == ["table", "acts"] and p.inputs["acts"]["table"] == ep.digest("table"),
		"Work starts only after Set lands and captures the new table")
	p.complete("acts", "new work")
	_ok(p.started == ["table", "acts", "say:1"] and ep.digest("say:intro") == intro,
		"the requested reading waits for Work even though its intermediate intro is unchanged")
	p.complete("say:1", "Fresh reading.")
	_ok(not p.running and not p.busy() and p.again.is_empty() and ep.read_text("script").contains("Fresh reading."),
		"the requested reading lands and its script rebuilds before the queue finishes")
	_ok(not ep.versions("table").is_empty() and not ep.versions("acts").is_empty() and ep.kept("say:1"),
		"explicit requests override locks, preserve versions and leave the locks in place")
	p.stop()


func _failed_input() -> void:
	var ep := _episode(2)
	var p := HeldProducer.new(ep)
	p.start(["table"], true)
	p.start(["acts"], true)
	p._jobs.erase("table")
	p._errors["table"] = "Set failed."
	p.tick()
	_ok(p.started == ["table"] and not p.running and p.state_of("table") == "failed"
		and p.state_of("acts") == "queued" and TableProducer.of(ep) == p,
		"a failed Set leaves Work queued instead of using the previous table, including on reopen")
	p.start(["table"], true)
	p.complete("table", "retried set")
	_ok(p.started == ["table", "table", "acts"], "retrying the failed input retains and releases the dependent request")
	p.stop()
	p.tick()
	_ok(p.again.is_empty() and p._jobs.is_empty() and not p.running and p.state_of("acts") == "ready",
		"Stop clears queued requests and active jobs, with no work starting afterward")


func _active_reader() -> void:
	var ep := _episode(5)
	var p := HeldProducer.new(ep)
	p.start(["acts"], true)
	var table := ep.digest("table")
	p.start(["table"], true)
	_ok(p.started == ["acts"] and p.state_of("table") == "queued" and ep.digest("table") == table,
		"an upstream remake waits while active Work still uses its previous table")
	p.complete("acts", "finished work")
	_ok(p.started == ["acts", "table"], "the upstream remake starts once its active dependent finishes")
	p.stop()


func _missing_input() -> void:
	var ep := _episode(3)
	DirAccess.remove_absolute(ep.file_of("acts"))
	var p := HeldProducer.new(ep)
	_ok(not p.can_queue("say:intro"), "control: an absent input nobody has requested cannot be used")
	p.start(["table"], true)
	p.start(["acts"], true)
	_ok(p.can_queue("say:intro"), "a missing input already queued allows its dependent to be queued")
	p.start(["say:intro"], true)
	_ok(p.started == ["table"] and p.state_of("say:intro") == "queued", "a queued missing input is still awaited")
	p.stop()


func _widened() -> void:
	var ep := _episode(4)
	var p := HeldProducer.new(ep)
	p.start(["table"], true, "Keep the original request.")
	p.start(["acts"], true)
	var active: String = p._jobs["table"]
	p.start()
	_ok(p.only.is_empty() and p.again.has("acts") and p._jobs.get("table") == active
		and p.asked["table"] == "Keep the original request.", "Generate widens the run without losing requests, jobs or notes")
	p.stop()


func _stale_generation() -> void:
	var ep := _episode(6)
	var p := HeldProducer.new(ep)
	_ok(not p.needs_work(), "a fresh episode needs no generation")
	ep.set_kept("script", true)
	var script := ep.digest("script")
	ep.write_json("acts", {"acts": [], "revision": "changed work"})
	ep.note_made("acts", "gate")
	ep.write_text("say:1", "The revised passage.")
	ep.note_made("say:1", "gate")
	_ok(ep.complete() and ep.stale("say:intro") and ep.stale("say:close") and ep.stale("script") and p.needs_work(),
		"complete files with stale unlocked Intro and Close still need Generate")
	p.start()
	_ok(p.started == ["say:intro"], "Generate starts the stale Intro before the other passages")
	p.complete("say:intro", "The revised intro.")
	_ok(p.started == ["say:intro", "say:close"], "Generate preserves a kept reading and refreshes the stale Close")
	p.complete("say:close", "The revised close.")
	_ok(not p.running and ep.digest("script") == script and ep.stale("script") and not p.needs_work(),
		"the control: locked Script remains preserved, as does a kept stale reading")
	ep.set_kept("script", false)
	_ok(p.needs_work(), "unlocking stale Script is immediately actionable")
	p.start()
	_ok(not p.running and not ep.stale("script") and not p.needs_work()
		and ep.read_text("script").contains("The revised intro.") and ep.read_text("script").contains("The revised close.")
		and not ep.versions("script").is_empty(), "Generate rebuilds only Script locally from the latest passages, preserving its previous version")
	ep.set_kept("script", true)
	p.start(["say:close"], true)
	p.complete("say:close", "The close, said once more.")
	ep.set_kept("script", false)
	p.start(["say:close"], true)
	p.complete("say:close", "The final close.")
	_ok(not ep.stale("script") and ep.read_text("script").contains("The final close."),
		"an unlocked Script also rebuilds automatically after a single passage's explicit regeneration")
	p.stop()


func _ok(condition: bool, what: String) -> void:
	print(("  ok    " if condition else "  FAIL  ") + what)
	if not condition:
		_fails += 1


func _clean(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for entry in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(entry))
	for entry in DirAccess.get_directories_at(path):
		_clean(path.path_join(entry))
	DirAccess.remove_absolute(path)
