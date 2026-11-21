extends Node

## Not a gate. Every page the dispatch desk's tablet shows in a note, set as the desk sets it ([member
## TabletPage.placeholders] off) and drawn whole, top to foot, one PNG a page - to look at a page's layout without
## playing the night.
##
##   GHOST_PROBE_GPU=1 tests/run_boot_probe.sh tests/dispatch/tablet_pages_probe.gd 120 \
##       --note <a note .md> --out <dir>/p [--only 3,4] [--scale 0.5]
##
## A picture already painted for the note is drawn; one not painted yet is the page's soft placeholder. `--scale` shrinks
## what is written. Prints each page's address, height and how far the desk could scroll it.

var _note := ""
var _out := "user://tablet_pages/p"
var _only: Array = []
var _scale := 0.5


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	for k in args.size() - 1:
		match args[k]:
			"--note":
				_note = args[k + 1]
			"--out":
				_out = args[k + 1]
			"--only":
				for n in args[k + 1].split(",", false):
					_only.append(int(n))
			"--scale":
				_scale = float(args[k + 1])
	if _note.is_empty():
		push_error("tablet_pages_probe: --note <file> is needed")
		get_tree().quit(2)
		return
	DirAccess.make_dir_recursive_absolute(_out.get_base_dir())
	var body := Manuscript.strip_frontmatter(FileAccess.get_file_as_string(_note))
	var doc: Dictionary = DispatchScript.parse(body).get("tablet", {})
	var pages: Array = doc.get("pages", [])
	var size := Vector2(DispatchScreens.TABLET_SIZE)
	var view := size.y - TabletChrome.TOP
	for pi in pages.size():
		if not _only.is_empty() and not _only.has(pi):
			continue
		var tp := TabletPage.new()
		tp.placeholders = false
		tp.build(doc, pi, size.x, view * 2.4, view)
		var h := ceili(minf(tp.height, 16000.0))
		var vp := SubViewport.new()
		vp.size = Vector2i(int(size.x), h)
		vp.render_target_update_mode = SubViewport.UPDATE_ONCE
		vp.transparent_bg = false
		var canvas := _Canvas.new()
		canvas.page = tp
		canvas.h = float(h)
		vp.add_child(canvas)
		add_child(vp)
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var img := vp.get_texture().get_image()
		if img != null and _scale != 1.0:
			img.resize(int(size.x * _scale), int(float(h) * _scale), Image.INTERPOLATE_LANCZOS)
		var path := "%s_%02d.png" % [_out, pi]
		if img != null:
			img.save_png(path)
		print("page %d  %s  %d px tall, scrolls %d px  -> %s" % [pi, String((pages[pi] as Dictionary)["url"]), int(tp.height),
			int(maxf(tp.height - view, 0.0)), path])
		vp.queue_free()
	get_tree().quit()


class _Canvas extends Node2D:
	var page: TabletPage
	var h := 0.0
	var _tex := {}

	func _draw() -> void:
		page.draw(self, 0.0, 0.0, 0.0, h, {}, 30.0, _texture)

	func _texture(key: String) -> Texture2D:
		if _tex.has(key):
			return _tex[key]
		var t: Texture2D = null
		var path := Illustrations.path_for(key)
		if not path.is_empty():
			var img := Image.load_from_file(path)
			if img != null and not img.is_empty():
				t = ImageTexture.create_from_image(img)
		_tex[key] = t
		return t
