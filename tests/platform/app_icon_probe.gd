extends SceneTree

## app_icon_probe - for looking at [AppIcon]'s ghosts: what other machines draw, and this machine's
## at every size and on every platform's mask. No renderer (ThorVG draws on the processor).
##
##   godot --headless --log-file dist/app_icon_probe.log --path . --script res://tests/platform/app_icon_probe.gd -- [out dir] [count]
##
## Writes, into the out dir (dist/app_icons by default):
## - `sheet.png`: [count] ghosts (36) on a dark panel, this machine's first, ringed.
## - `this_machine.png`: this machine's at 256 down to 16 on a dark and a light panel; then a phone's
##   view of a build seeded alike - Android's adaptive icon in a circle and a squircle, its themed
##   (monochrome) icon, and iOS's under its rounded mask.
## - `this_machine.svg`: the SVG the window's icon is drawn from.

const DARK := Color("#232629")
const LIGHT := Color("#eff0f1")
const CELL := 168
const ICON := 128


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0] if args.size() > 0 else "res://dist/app_icons"
	var count := int(args[1]) if args.size() > 1 else 36
	var dir := ProjectSettings.globalize_path(out)
	DirAccess.make_dir_recursive_absolute(dir)

	var mine := AppIcon.machine_seed()
	var seeds: Array[PackedByteArray] = [mine]
	for i in count - 1:
		seeds.append(AppIcon.seed_of("sample %d" % i))
	_sheet(seeds).save_png(dir.path_join("sheet.png"))
	_this_machine(mine).save_png(dir.path_join("this_machine.png"))
	var f := FileAccess.open(dir.path_join("this_machine.svg"), FileAccess.WRITE)
	f.store_string(AppIcon.svg_of(AppIcon.design_of(mine)))
	f.close()
	print("app_icon_probe: this machine draws ", AppIcon.design_of(mine))
	print("app_icon_probe: wrote ", dir)
	quit(0)


func _sheet(seeds: Array[PackedByteArray]) -> Image:
	var cols := 6
	var rows := ceili(seeds.size() / float(cols))
	var sheet := Image.create_empty(cols * CELL, rows * CELL, false, Image.FORMAT_RGBA8)
	sheet.fill(DARK)
	for i in seeds.size():
		var at := Vector2i((i % cols) * CELL, (i / cols) * CELL)
		if i == 0:
			_ring(sheet, Rect2i(at + Vector2i(6, 6), Vector2i(CELL - 12, CELL - 12)), Color("#8ab4f8"))
		var img := AppIcon.image_of(AppIcon.design_of(seeds[i]), ICON)
		_put(sheet, img, at + Vector2i((CELL - ICON) / 2, (CELL - ICON) / 2))
	return sheet


func _this_machine(seed: PackedByteArray) -> Image:
	var design := AppIcon.design_of(seed)
	var sizes := [256, 128, 64, 48, 32, 24, 16]
	var gap := 24
	var width := gap
	for s: int in sizes:
		width += s + gap
	var band := 256 + gap * 2
	var phone := 192
	var img := Image.create_empty(maxi(width, gap + 4 * (phone + gap)), band * 2 + phone + gap * 2, false, Image.FORMAT_RGBA8)
	img.fill(DARK)
	img.fill_rect(Rect2i(0, band, img.get_width(), band), LIGHT)
	var x := gap
	for s: int in sizes:
		var icon := AppIcon.image_of(design, s)
		_put(img, icon, Vector2i(x, gap + (256 - s) / 2))
		_put(img, icon, Vector2i(x, band + gap + (256 - s) / 2))
		x += s + gap

	# A phone's view of the same seed: Android shows the middle 72 of the adaptive icon's 108.
	var pack := AppIcon.packaged(seed)
	var adaptive: Image = pack["android_background"].duplicate()
	_put(adaptive, pack["android_foreground"], Vector2i.ZERO)
	var shown := adaptive.get_region(Rect2i(72, 72, 288, 288))
	shown.resize(phone, phone, Image.INTERPOLATE_LANCZOS)
	var themed := Image.create_empty(432, 432, false, Image.FORMAT_RGBA8)
	themed.fill(Color("#d8e2ff"))
	var mono: Image = pack["android_monochrome"]
	var tint := Color("#2f4578")
	for py in 432:
		for px in 432:
			var a := mono.get_pixel(px, py).a
			if a > 0.0:
				themed.set_pixel(px, py, themed.get_pixel(px, py).lerp(tint, a))
	themed = themed.get_region(Rect2i(72, 72, 288, 288))
	themed.resize(phone, phone, Image.INTERPOLATE_LANCZOS)
	var ios: Image = pack["ios"].duplicate()
	ios.resize(phone, phone, Image.INTERPOLATE_LANCZOS)
	var y := band * 2 + gap
	x = gap
	for shot: Array in [[shown, "circle"], [shown, "squircle"], [themed, "circle"], [ios, "rounded"]]:
		_put(img, _masked(shot[0], shot[1]), Vector2i(x, y))
		x += phone + gap
	return img


## [param img] cut to a launcher's shape, its edge a pixel soft.
func _masked(img: Image, shape: String) -> Image:
	var out := img.duplicate() as Image
	out.convert(Image.FORMAT_RGBA8)
	var n := out.get_width()
	var r := n * 0.5
	for py in n:
		for px in n:
			var p := Vector2(px + 0.5 - r, py + 0.5 - r) / r
			var d := 0.0
			match shape:
				"circle":
					d = p.length() - 1.0
				"squircle":
					d = pow(pow(absf(p.x), 4.0) + pow(absf(p.y), 4.0), 0.25) - 1.0
				"rounded":
					var k := 0.45
					var q := Vector2(absf(p.x), absf(p.y)) - Vector2(1.0 - k, 1.0 - k)
					d = Vector2(maxf(q.x, 0.0), maxf(q.y, 0.0)).length() - k
			var cover := clampf(0.5 - d * r, 0.0, 1.0)
			var c := out.get_pixel(px, py)
			c.a *= cover
			out.set_pixel(px, py, c)
	return out


func _put(dst: Image, src: Image, at: Vector2i) -> void:
	var s := src
	if s.get_format() != dst.get_format():
		s = src.duplicate() as Image
		s.convert(dst.get_format())
	dst.blend_rect(s, Rect2i(Vector2i.ZERO, s.get_size()), at)


func _ring(dst: Image, r: Rect2i, c: Color) -> void:
	for w in 3:
		var q := r.grow(-w)
		dst.fill_rect(Rect2i(q.position, Vector2i(q.size.x, 1)), c)
		dst.fill_rect(Rect2i(q.position + Vector2i(0, q.size.y - 1), Vector2i(q.size.x, 1)), c)
		dst.fill_rect(Rect2i(q.position, Vector2i(1, q.size.y)), c)
		dst.fill_rect(Rect2i(q.position + Vector2i(q.size.x - 1, 0), Vector2i(1, q.size.y)), c)
