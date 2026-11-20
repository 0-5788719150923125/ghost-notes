extends Node

## text_refine_look_probe - Refine… as the app shows it, as a picture: a window as wide as the Body's editor, and the chat
## window opened beside it ([TextRefine]) on a conversation of a few turns (the writer's words, its changes, what each cost,
## a turn stopped, one under way). In a folder of its own; nothing runs and nothing is held.
##
##   GHOST_PROBE_GPU=1 tests/run_boot_probe.sh tests/ui/text_refine_look_probe.gd 60 [--out=<dir>]
##
## Writes `refine.png` (the two side by side) and `small.png` (a 1280 x 720 window) under the out folder.

const ROOT := "user://text_refine_look_probe"

var _out := "dist/text_refine_look"


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--out="):
			_out = String(a).trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(_out)
	TextRefine.root = ROOT
	for size in [Vector2i(1920, 1080), Vector2i(1280, 720)]:
		get_tree().root.size = size
		await get_tree().process_frame
		await _shot(size, "refine.png" if size.x == 1920 else "small.png")
	get_tree().quit()


func _shot(screen: Vector2i, file: String) -> void:
	var host := Window.new()
	host.title = "Body - a note.md"
	host.min_size = Vector2i(760, 440)
	var ed := TextEdit.new()
	ed.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ed.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	ed.text = "<!-- speaker: Mo -->\nThe cat brooded on the mat.\nIt was a rainy day, and the window shook.\n\nThe end."
	ed.add_theme_font_size_override("font_size", 16)
	host.add_child(ed)
	add_child(host)
	TextField.pop_up(host, self, Vector2(0.82, 0.82))
	var chat := WriterChat.at(TextRefine.folder_for("", "look_%d" % screen.x))
	chat.turns = [
		{"you": "Make the opening darker - the cat shouldn't just sit.", "agent": "claude", "model": "opus", "effort": "high", "events": [
			{"said": "I'll give the cat something heavier to do, and leave the rest."},
			{"tool": "edit", "old": "The cat sat on the mat.", "new": "The cat brooded on the mat.", "count": 1}],
			"reply": "Changed **sat** to **brooded** in the first line. Nothing else moved.",
			"usage": {"fresh": 6, "cached": 1976, "made": 2092, "out": 109, "usd": 0.0049}, "error": ""},
		{"you": "Hand the last line to Mo, and make the weather worse.", "agent": "claude", "model": "opus", "effort": "high", "events": [
			{"tool": "edit", "old": "It was a sunny day.", "new": "It was a rainy day, and the window shook.", "count": 1},
			{"tool": "edit", "old": "\nThe end.", "new": "\n<!-- speaker: Mo -->\nThe end.", "count": 1}],
			"reply": "The day is rainy now, with the window shaking, and a `<!-- speaker: Mo -->` cue hands the last line to Mo.",
			"usage": {"fresh": 6, "cached": 6542, "made": 323, "out": 185, "usd": 0.0071}, "error": ""},
		{"you": "Rewrite it as a sonnet.", "agent": "claude", "model": "opus", "effort": "high", "events": [], "reply": "",
			"usage": {}, "error": "stopped"},
		{"you": "Actually, just tighten the second line.", "agent": "claude", "model": "opus", "effort": "high", "events": [
			{"said": "Reading it again first."}], "reply": "", "usage": {}, "error": "", "running": true},
	]
	var w := TextRefine.new(chat, "Body")
	add_child(w)
	w.open_beside(host)
	for i in 8:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := _out.path_join(file)
	img.save_png(path)
	print("text_refine_look_probe: wrote %s (host %s+%s, refine %s+%s)" % [path, host.position, host.size, w.position, w.size])
	w.queue_free()
	host.queue_free()
	await get_tree().process_frame
