extends SceneTree

## back_frame_probe - LOOK at a card's back with its frame drawn round the painting (feedback 0006: the arch
## window's border sat off the painting's rectangle). Draws the real painting of an episode's back under its
## real look and writes the face as a PNG.
##
##   tests/run_quiet.sh back_frame_probe -- <episode dir> <out.png>
##
## NOT `--headless`: pixels. Read-only: the episode is only read.

func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var dir := String(args[0]) if args.size() > 0 else ""
	var out := String(args[1]) if args.size() > 1 else "back_frame.png"
	var plan: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(dir.path_join("plan.json")))
	var look := CardTable.sanitize_look(plan.get("look", {}))
	var face := CardFaces.Face.new()
	face.look = look
	face.back = true
	face.art = ImageTexture.create_from_image(Image.load_from_file(dir.path_join("back.png")))
	var vp := CardFaces.viewport(root, face, CardFaces.face_px(look))
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	for i in 4:
		await process_frame
	vp.get_texture().get_image().save_png(out)
	print("back_frame_probe: wrote ", out)
	quit(0)
