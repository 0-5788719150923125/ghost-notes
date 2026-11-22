extends Node

## CartoonTool - a cartoon's agents run from the command line (next/cartoon.md): the same [CartoonProducer] the Cartoon card runs, on
## the note at a path, each step it is asked for waited for and said as it lands, then the app quits. It writes what the card would
## (puppets and sets on the library's shelves, the storyboard in the note's folder), so it is a tool, never a gate.
##
##   godot --headless --path . -- --cartoon PATH [--make] [--rig NAME] [--again NAME] [--paint NAME] [--direct] [--python PY]
##       [--trace NAME] [--land FILE] [--writer claude|codex|grok] [--model M]
##
## `--make` makes whatever is not made yet; `--rig` makes a character's sheet, painting only the drawings it lacks, and `--again` all of
## them anew; `--land` lands a director's reply kept in FILE as a run's would be (checked, its cameras framed, written) - after the
## code that frames them changed; `--trace` traces where a set's characters walk on it (its ground line); `--python` runs the puppet host on that interpreter (its environment elsewhere).

var _producer: CartoonProducer = null
var _t0 := 0


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var note := ""
	var asked: Array = []
	var writer := ""
	var model := ""
	for i in args.size():
		var v := String(args[i + 1]) if i + 1 < args.size() else ""
		match String(args[i]):
			"--cartoon": note = v
			"--python": RiggerTools.python = v
			"--writer": writer = v
			"--model": model = v
			"--make": asked.append(["make", ""])
			"--rig": asked.append(["rig", v])
			"--again": asked.append(["again", v])
			"--paint": asked.append(["paint", v])
			"--trace": asked.append(["trace", v])
			"--land": asked.append(["land", v])
			"--direct": asked.append(["direct", ""])
	if not FileAccess.file_exists(note):
		print("cartoon_tool: no note at %s" % note)
		get_tree().quit(1)
		return
	var block: Dictionary = NoteStore.blocks_of(note).get(CartoonCard.KEY, {})
	_producer = CartoonProducer.new(note, NoteUpload.folder_of(note), block)
	if not writer.is_empty():
		_producer.writer["agent"] = writer
	_producer.writer["model"] = model
	for a in asked:
		var why := ""
		match String(a[0]):
			"make": why = _producer.make_missing()
			"rig": why = _start_rig(String(a[1]))
			"again": why = _start_rig(String(a[1]), true)
			"paint": why = _start_paint(String(a[1]))
			"trace": why = _start_trace(String(a[1]))
			"land": why = _producer.land(FileAccess.get_file_as_string(String(a[1])))
			"direct": why = _producer.direct()
		if not why.is_empty():
			print("cartoon_tool: %s - %s" % [a[0], why])
	_t0 = Time.get_ticks_msec()


func _start_rig(name: String, again := false) -> String:
	for c in _producer.cast():
		if String(c["name"]) == name:
			return _producer.sheet(c, true) if again else _producer.make(c)
	return "no character %s in the note's cast" % name


func _start_paint(name: String) -> String:
	for s in _producer.sets():
		if String(s["name"]) == name:
			return _producer.paint(s)
	return "no set %s in the note's sets" % name


func _start_trace(name: String) -> String:
	for s in _producer.sets():
		if String(s["name"]) == name:
			return _producer.trace(s)
	return "no set %s in the note's sets" % name


func _process(_delta: float) -> void:
	if _producer == null:
		return
	_producer.pump()
	if Engine.get_process_frames() % 600 == 0:
		print("cartoon_tool: %d s, working on %s" % [(Time.get_ticks_msec() - _t0) / 1000, ", ".join(_producer._work.keys())])
	if _producer.busy():
		return
	for key in _producer._errors:
		print("cartoon_tool: %s failed - %s" % [key, _producer._errors[key]])
	print("cartoon_tool: done in %d s; storyboard %s" % [(Time.get_ticks_msec() - _t0) / 1000, "written" if _producer.boarded() else "not written"])
	set_process(false)
	get_tree().quit(0 if _producer._errors.is_empty() else 1)
