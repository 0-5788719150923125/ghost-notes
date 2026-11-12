extends PipelineSection
class_name ActorPipeline

## ActorPipeline - a person's steps as a section of the note's Pipeline card ([PipelineCard]; every step of the Actor card,
## the voice's alone of the Voice training card - [method ActorSteps.voice_chain]), a row each ([ActorSteps]): ✓ made, ⚠ stale,
## its share while it runs, ▶ to make it and what it needs, ⟳ to make it again, after asking. Handed the folder and its
## builder ([method show_actor]); what it has to say goes out as [signal said].
##
## Nothing here waits on the disk: the steps' states are worked out on a worker, on a folder of its own
## ([method ActorBuilder.states_of]), and only when what they are made from changed ([method _rows_key]); the runs are
## laid over them every refresh, which is cheap, so a running row moves every refresh.

signal said(text: String)

## Called before ▶ or ⟳ starts the builder: the Actor card hands it who labels.
var before_start: Callable

var _steps: Array = []
var _keep := Callable()
var _generate := Callable()
var _line_of := Callable()
var _make_tip := ""
var _actor: ActorFolder = null
var _builder: ActorBuilder = null
var _rows_seen := ""
## The steps' states, worked out on a worker ([method _work_rows]): its task, what it found, what the rows are drawn
## from, whether it goes again once done, and whether the rows show the latest.
var _rows_task := -1
var _rows_found := {}
var _rows_held := {}
var _rows_again := false
var _rows_drawn := false
var _was_busy := false           # the rows were drawn with a run under way: drawn once more when it ends, however it ended
var _drawn: Array = []


## A section called [param named] of the rows of [param steps], in their order, of the card [param by]: Generate is its
## [param generate], the line over the rows [param line_of], and the ▶ on its heading says [param make_tip].
var _kept := {}               # step -> whether what it made before its last ⟳ is kept ([method ActorBuilder.kept_back])

func _init(named := "", steps: Array = [], by: Object = null, generate := Callable(), line_of := Callable(), make_tip_said := "") -> void:
	title = named
	_steps = steps
	owner = by
	_generate = generate
	_line_of = line_of
	_make_tip = make_tip_said


func shown() -> bool:
	return _actor != null and _builder != null


## The person's worker, waited for before its card goes: it writes into this section.
func wait() -> void:
	if _rows_task >= 0:
		WorkerThreadPool.wait_for_task_completion(_rows_task)
	_rows_task = -1


## The person shown: [param a] and its builder ([param b]), or nulls for none.
func show_actor(a: ActorFolder, b: ActorBuilder) -> void:
	_actor = a
	_builder = b
	_rows_seen = ""
	_rows_held = {}
	_drawn = []


## The rows listed: those [param keep] says yes to (`(step) -> bool`).
func show_only(keep: Callable) -> void:
	_keep = keep
	_rows_seen = ""
	_rows_drawn = false


func busy() -> bool:
	return _builder != null and (_builder.running or _builder.busy())


func make() -> void:
	if _generate.is_valid():
		_generate.call()


func make_tip() -> String:
	return _make_tip


func line() -> String:
	return String(_line_of.call()) if _line_of.is_valid() else ""


func stop() -> void:
	if _builder != null:
		_builder.stop()


## Whether a step here has something to make. Before the worker has answered, it may well.
func missing() -> bool:
	if _drawn.is_empty():
		return true
	for r in _drawn:
		if (r as PipelineRow).state in ["missing", "stale", "failed"]:
			return true
	return false


## The steps' rows: the states worked out again when what they are made from changed, and the runs laid over them.
func rows() -> Array:
	if _actor == null or _builder == null:
		return []
	var key := _rows_key()
	if key != _rows_seen:
		_rows_seen = key
		_work_rows()
	_take_rows()
	var now := busy()
	if not _rows_held.is_empty() and (now or not _rows_drawn or _was_busy):
		_rows_drawn = true
		_was_busy = now
		_drawn = _fill_rows(now)
	return _drawn


func _make(step: String) -> void:
	if _builder == null:
		return
	if before_start.is_valid():
		before_start.call()
	_builder.start(ActorSteps.with_needs(step))
	said.emit("Making %s, and whatever it needs first." % String(Registry.field(ActorSteps.REGISTRY, step, "label", step)))


func _redo(step: String) -> void:
	if _builder == null:
		return
	_kept = {}
	if before_start.is_valid():
		before_start.call()
	_builder.redo(step)


## What the steps' states are made from: the actor's data (videos ticked, settings, the set in use) and every stamp
## file a row reads. What runs and what failed are laid over them every refresh ([method ActorBuilder.row_of]).
func _rows_key() -> String:
	var parts := PackedStringArray([str(JSON.stringify(_actor.data).hash())])
	var scopes: Array = [""]
	for v in _actor.ticked():
		scopes.append("v:" + String(v))
	if not _actor.chosen_set().is_empty():
		scopes.append("s:" + _actor.chosen_set())
	for sc in scopes:
		var p := _actor.scope_dir(String(sc)).path_join(ActorFolder.STAMPS)
		parts.append("%d|%d" % [FileAccess.get_modified_time(p), FileAccess.get_size(p)] if FileAccess.file_exists(p) else "-")
	return ",".join(parts)


## The steps' states worked out on a worker, on a folder of its own ([method ActorBuilder.states_of]): one at a time -
## asked again while it works, it goes again once done.
func _work_rows() -> void:
	_kept = {}            # (what is kept one back is asked again with the states, never at every refresh)
	if _rows_task >= 0:
		_rows_again = true
		return
	var id := _actor.id
	_rows_task = WorkerThreadPool.add_task(func() -> void:
		var f := ActorFolder.open(id)
		_rows_found = {"id": id, "states": ActorBuilder.states_of(f) if f != null else {}})


## What the worker found, once it is done: the rows drawn from it (for the actor shown alone).
func _take_rows() -> void:
	if _rows_task < 0 or not WorkerThreadPool.is_task_completed(_rows_task):
		return
	WorkerThreadPool.wait_for_task_completion(_rows_task)
	_rows_task = -1
	if _actor != null and String(_rows_found.get("id", "")) == _actor.id:
		_rows_held = _rows_found["states"]
		_rows_drawn = false
	_rows_found = {}
	if _rows_again:
		_rows_again = false
		_work_rows()


func _fill_rows(now_busy: bool) -> Array:
	var out: Array = []
	for s in _steps:
		var step := String(s)
		if _keep.is_valid() and not bool(_keep.call(step)):
			continue
		var name := String(Registry.field(ActorSteps.REGISTRY, step, "label", step))
		var row := _builder.row_of(step, _rows_held)
		var st := String(row["state"])
		var count := ""
		if ActorSteps.per(step) == "video" and int(row["total"]) > 1:
			count = "%d/%d " % [int(row["made"]), int(row["total"])]
		var r := PipelineRow.new(step, name)
		match st:
			"made":
				r.state = "made"
				r.said = count + String(row["said"])
			"stale":
				r.state = "stale"
				r.said = count + "stale - made from inputs that changed; still used until made again"
			"running":
				var p := float(row["progress"])
				r.state = "running"
				r.said = count + ("%d%% " % int(p * 100.0) if p >= 0.0 else "") + String(row["said"])
				r.wraps = true
			"failed":
				r.state = "failed"
				r.said = String(row["error"])
			"waiting":
				r.state = "missing"
				r.said = "waits for the sets"
			"moot":
				r.state = "none"
				r.said = "read in place" if step == "fetch" else "no captions link"
			"unavailable":
				r.state = "none"
				r.said = String(row["said"])
			_:
				r.state = "missing"
				r.said = count
		var blurb := String(Registry.field(ActorSteps.REGISTRY, step, "blurb", ""))
		r.tip = (r.said + "\n\n" + blurb) if not r.said.is_empty() else blurb
		r.go = "Make this step - and whatever it needs first - where it is missing or stale."
		r.go_open = not now_busy and st != "running" and st != "unavailable"
		r.make = _make.bind(step)
		r.again = "Make %s again from scratch" % name
		r.open = not now_busy and (st == "made" or st == "stale" or st == "failed")
		r.asks = ("What %s made is kept one back (its ✎ puts it back). Everything made from it is marked stale (⚠): it is still "
			+ "used until it is made again too - Generate does that.") % name
		r.redo = _redo.bind(step)
		# ✎ where one is kept back: what the step made before its last ⟳, put back (next/editing.md step 12)
		if not _kept.has(step):
			_kept[step] = _builder.kept_back(step)
		if bool(_kept[step]):
			r.edit_tip = "Put back what %s made before its last ⟳: what stands now is kept one back in its place." % name
			r.edit = func() -> void:
				_kept = {}
				var err := _builder.put_back(step)
				said.emit(("Not put back: " + err) if not err.is_empty() else "%s is as it was before its last ⟳." % name)
		out.append(r)
	return out
