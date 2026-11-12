extends SceneTree

## mask_marker_tool - headless CLI: insert one marker into a mask session file at a given time.
##
## Used by the assistant dispatch flow (src/app/assistant.gd): a feedback record carries the time its note was
## written at, so a fix can plant a marker demonstrating a new effect there. MaskSession is a plain RefCounted, so
## no app boot is needed: it loads the session, edits its marker list and re-saves.
##
## Usage (run from the project root):
##   godot --headless --path . --script src/masking/mask_marker_tool.gd -- \
##       <session.json path, res:// or absolute> <time seconds> [field=value ...]
##
## The new marker continues the one governing at that time (`add_marker`); each field=value pair overrides one of
## MaskSession.VECTOR_FIELDS, e.g. effect_a=14 fx_contrast=0.6 view_mode=1 duration=0.5 kind=0. An unknown field
## name is rejected.
##
## An editor still open on the same session autosaves its own copy on the next edit and clobbers the marker: reopen
## the session first.

func _init() -> void:
	var argv := OS.get_cmdline_user_args()
	if argv.size() < 2:
		printerr("usage: mask_marker_tool.gd <session.json> <time> [field=value ...]")
		quit(1)
		return
	var path: String = argv[0]
	if not path.begins_with("res://") and not path.is_absolute_path():
		path = "res://" + path
	var abs_path: String = ProjectSettings.globalize_path(path) if path.begins_with("res://") else path
	if not FileAccess.file_exists(abs_path):
		printerr("no such session file: ", abs_path)
		quit(1)
		return
	var session: MaskSession = MaskSession.load(abs_path)
	if session == null:
		printerr("failed to parse session: ", abs_path)
		quit(1)
		return
	var t := float(argv[1])
	var overrides := {}
	for raw in argv.slice(2):
		var eq: int = raw.find("=")
		if eq <= 0:
			printerr("bad field=value (want field=value): ", raw)
			quit(1)
			return
		var key: String = raw.substr(0, eq)
		if not MaskSession.VECTOR_FIELDS.has(key):
			printerr("unknown field (see MaskSession.VECTOR_FIELDS): ", key)
			quit(1)
			return
		overrides[key] = float(raw.substr(eq + 1))
	var m: Dictionary = session.add_marker(t)
	for key in overrides:
		m[key] = overrides[key]
	if not session.save(abs_path):
		printerr("failed to save session: ", abs_path)
		quit(1)
		return
	print("inserted marker at t=%.3f in %s" % [t, abs_path])
	quit(0)
