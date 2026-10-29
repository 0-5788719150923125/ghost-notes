extends VBoxContainer
class_name EpisodeStepRows

## EpisodeStepRows - the rows of the steps the note's other cards add ([EpisodeSteps]), under the steps of the
## card that lists them: a row a step - its name, what it says (✓ what it made, … what its writer is doing,
## ✗ why it failed, – what it waits for) and its ⟳ - built again when the steps listed change. Every card that
## draws them as rows of their own uses these (Proof's, the Actor's, the Letter's, the YouTube card's own);
## Cards' card lays them into its one list of steps.

## A step's ⟳ was pressed: the card makes it again, and says why not when it cannot.
signal redo(step: EpisodeStep)

var steps: EpisodeSteps
## What a ⟳ says it waits for while the episode has no words.
var waits := " - once the episode's words are written"

var _rows := {}       # a step's key -> {step, state: Label, redo: Button}
var _built := ""      # the steps the rows were built for


func _init(of: EpisodeSteps, waits_for := " - once the episode's words are written") -> void:
	steps = of
	waits = waits_for
	add_theme_constant_override("separation", 4)


## The row of the step [param key]: `{step, state, redo}`, {} while it has none.
func row(key: String) -> Dictionary:
	return _rows.get(key, {})


func has_row(key: String) -> bool:
	return _rows.has(key)


## THE ROWS FOR [param feed]'S EPISODE: built again when the steps listed change, then each says where its
## step stands. A ⟳ is offered once the episode has words, while its step is not being made, and unless the
## card holds them all ([param held]: it is making its own).
func refresh(feed: EpisodeFeed, held := false) -> void:
	var key := steps.key(feed)
	if key != _built:
		_built = key
		_build(steps.listed(feed))
	var words := feed != null and not feed.words().is_empty()
	for k in _rows:
		var r: Dictionary = _rows[k]
		var step: EpisodeStep = r["step"]
		var st := step.state(feed)
		var lead := String({"ready": "✓", "running": "…", "queued": "…", "failed": "✗"}.get(st, "–"))
		var said := step.said(feed)
		(r["state"] as Label).text = lead + (" " + said if not said.is_empty() else "")
		(r["state"] as Label).tooltip_text = (r["state"] as Label).text
		var made := not step.made(feed).is_empty()
		(r["redo"] as Button).disabled = held or step.busy(feed) or not words
		(r["redo"] as Button).tooltip_text = (step.again if made else step.first) + ("" if words else waits)


func _build(listed: Array) -> void:
	for c in get_children():
		remove_child(c)
		c.queue_free()
	_rows = {}
	for s in listed:
		var step: EpisodeStep = s
		var r := HBoxContainer.new()
		r.add_theme_constant_override("separation", 6)
		add_child(r)
		var name_l := Label.new()
		name_l.text = step.label
		name_l.custom_minimum_size.x = 64.0
		name_l.add_theme_font_size_override("font_size", 12)
		r.add_child(name_l)
		var state := Label.new()
		state.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		state.clip_text = true
		state.add_theme_font_size_override("font_size", 11)
		state.mouse_filter = Control.MOUSE_FILTER_STOP
		r.add_child(state)
		var again := Button.new()
		again.text = "⟳"
		again.flat = true
		again.pressed.connect(func() -> void: redo.emit(step))
		r.add_child(again)
		_rows[step.key] = {"step": step, "state": state, "redo": again}
