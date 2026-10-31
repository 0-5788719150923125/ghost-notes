extends SceneTree

## app_icon_tool - headless CLI: write the icons a package carries ([const AppIcon.PACKAGED]) for one
## seed. scripts/build.sh runs it before exporting and the export presets name the files it writes,
## so a phone's launcher shows the build's own ghost - an app cannot draw a new one there at runtime.
##
## Usage (from the project root):
##   godot --headless --path . --script res://src/platform/app_icon_tool.gd -- <out dir> <seed text>
##
## The seed is any text (build.sh hands it the commit); the same text writes the same icons.

func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2 or args[1].strip_edges().is_empty():
		printerr("app_icon_tool: usage: -- <out dir> <seed text>")
		quit(2)
		return
	var dir := ProjectSettings.globalize_path(args[0])
	var seed := AppIcon.seed_of(args[1].strip_edges())
	if DirAccess.make_dir_recursive_absolute(dir) != OK:
		printerr("app_icon_tool: cannot make ", dir)
		quit(1)
		return
	var icons := AppIcon.packaged(seed)
	for key: String in AppIcon.PACKAGED:
		var img: Image = icons[key]
		var path := dir.path_join(str(AppIcon.PACKAGED[key]["file"]))
		if img.is_empty() or img.save_png(path) != OK:
			printerr("app_icon_tool: could not write ", path)
			quit(1)
			return
	print("app_icon_tool: %d icons in %s, the ghost %s" % [icons.size(), dir, AppIcon.design_of(seed)])
	quit(0)
