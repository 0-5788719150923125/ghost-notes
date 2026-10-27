extends VBoxContainer
class_name ActorStepRows

## ActorStepRows - a person's steps on a card that builds them (every step on the Actor card; the voice's alone
## on the Voice training card, [method ActorSteps.voice_chain]), a row each ([ActorSteps]): ✓ made, ⚠ stale, its
## share while it runs, ▶ to make it and what it needs, ⟳ to make it again, after asking. Handed the folder and
## its builder ([method show_actor]); what it has to say goes out as [signal said].
##
## NOTHING HERE WAITS ON THE DISK (the user, 2026-10-23: "We shouldn't be blocking the main thread for ANY
## operation"): the steps' states are worked out on a worker, on a folder of its own ([method
## ActorBuilder.states_of]), and only when what they are made from changed ([method _rows_key]) - every scope's
## state of every step took 10-20 ms four times a second under a playing show, and seconds once a video was
## ticked; the runs are laid over them every refresh, which is cheap - so a running row moves every refresh.

signal said(text: String)

## Called before ▶ or ⟳ starts the builder: the Actor card hands it who labels.
var before_start: Callable

var _actor: ActorFolder = null
var _builder: ActorBuilder = null
var _rows := {}               # step -> {state: Label, make: Button, redo: Button, row}
var _rows_seen := ""
## The steps' states, worked out on a worker ([method _work_rows]): its task, what it found, what the rows are drawn
## from, whether it goes again once done, and whether the rows show the latest.
var _rows_task := -1
var _rows_found := {}
var _rows_held := {}
var _rows_again := false
var _rows_drawn := false


## The rows of [param steps], in their order.
func _init(steps: Array = []) -> void:
	add_theme_constant_override("separation", 0)
	for step in steps:
		var r := HBoxContainer.new()
		r.add_theme_constant_override("separation", 4)
		add_child(r)
		var name_l := Label.new()
		name_l.text = String(Registry.field(ActorSteps.REGISTRY, step, "label", step))
		name_l.custom_minimum_size.x = 64.0
		name_l.add_theme_font_size_override("font_size", 12)
		name_l.tooltip_text = String(Registry.field(ActorSteps.REGISTRY, step, "blurb", ""))
		name_l.mouse_filter = Control.MOUSE_FILTER_STOP
		r.add_child(name_l)
		var state := Label.new()
		state.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		state.clip_text = true
		state.add_theme_font_size_override("font_size", 11)
		state.mouse_filter = Control.MOUSE_FILTER_STOP
		r.add_child(state)
		var make := Button.new()
		make.text = "▶"
		make.flat = true
		make.tooltip_text = "Make this step - and whatever it needs first - where it is missing or stale."
		make.pressed.connect(_make.bind(step))
		r.add_child(make)
		var redo := Button.new()
		redo.text = "⟳"
		redo.flat = true
		redo.tooltip_text = "Make this step again from scratch: what is made from it is marked stale."
		redo.pressed.connect(_redo.bind(step))
		r.add_child(redo)
		_rows[step] = {"state": state, "make": make, "redo": redo, "row": r}


## A worker still working the states out is waited for, before these rows go: it writes into them.
func _exit_tree() -> void:
	wait()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		wait()


func wait() -> void:
	if _rows_task >= 0:
		WorkerThreadPool.wait_for_task_completion(_rows_task)
	_rows_task = -1


## THE PERSON SHOWN: [param a] and its builder ([param b]), or nulls for none.
func show_actor(a: ActorFolder, b: ActorBuilder) -> void:
	_actor = a
	_builder = b
	_rows_seen = ""


## The rows shown: those [param keep] says yes to (`(step) -> bool`), the others hidden.
func show_only(keep: Callable) -> void:
	for step in _rows:
		((_rows[step] as Dictionary)["row"] as Control).visible = bool(keep.call(String(step)))
	_rows_seen = ""


## A REFRESH: the states worked out again when what they are made from changed, and the runs laid over them;
## [param busy] while a run is under way (nothing is offered then).
func refresh(busy: bool) -> void:
	if _actor == null or _builder == null:
		return
	var key := _rows_key()
	if key != _rows_seen:
		_rows_seen = key
		_work_rows()
	_take_rows()
	if not _rows_held.is_empty() and (busy or not _rows_drawn):
		_rows_drawn = true
		_fill_rows(busy)


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
	var label := String(Registry.field(ActorSteps.REGISTRY, step, "label", step))
	var ask := ConfirmationDialog.new()
	ask.title = "Make %s again" % label
	ask.dialog_text = ("Throw away what %s made and make it again?\n\nEverything made from it is marked stale (⚠): "
		+ "it is still used until it is made again too - Generate does that.") % label
	ask.dialog_autowrap = true
	ask.ok_button_text = "Make again"
	ask.confirmed.connect(func() -> void:
		ask.queue_free()
		if before_start.is_valid():
			before_start.call()
		_builder.redo(step))
	ask.canceled.connect(ask.queue_free)
	add_child(ask)
	ask.popup_centered(Vector2i(460, 0))


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


## THE STEPS' STATES WORKED OUT ON A WORKER, on a folder of its own ([method ActorBuilder.states_of]): one at a
## time - asked again while it works, it goes again once done.
func _work_rows() -> void:
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


func _fill_rows(busy: bool) -> void:
	for step in _rows:
		var r: Dictionary = _rows[step]
		var row := _builder.row_of(String(step), _rows_held)
		var st := String(row["state"])
		var count := ""
		if ActorSteps.per(String(step)) == "video" and int(row["total"]) > 1:
			count = "%d/%d " % [int(row["made"]), int(row["total"])]
		var shown := ""
		match st:
			"made":
				shown = "✓ " + count + String(row["said"])
			"stale":
				shown = "⚠ " + count + "stale - made from inputs that changed; still used until made again"
			"running":
				var p := float(row["progress"])
				shown = "… " + count + ("%d%% " % int(p * 100.0) if p >= 0.0 else "") + String(row["said"])
			"failed":
				shown = "✗ " + String(row["error"])
			"waiting":
				shown = "waits for the sets"
			"moot":
				shown = "– read in place" if step == "fetch" else "– no captions link"
			"unavailable":
				shown = "– " + String(row["said"])
			_:
				shown = "– " + count
		(r["state"] as Label).text = shown
		(r["state"] as Label).tooltip_text = shown + "\n\n" + String(Registry.field(ActorSteps.REGISTRY, step, "blurb", ""))
		(r["make"] as Button).disabled = busy or st == "running" or st == "unavailable"
		(r["redo"] as Button).disabled = busy or not (st == "made" or st == "stale" or st == "failed")
