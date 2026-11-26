extends SceneTree

## ornament_compile_check - an ornament written by an agent compiled and drawn by the real renderer ([Ornaments], [OrnamentTools];
## next/surfaces.md). Needs a GPU.
##
##   tests/run_quiet.sh -- res://tests/table/ornament_compile_check.gd
##
## shader errors: 2
##
## - Every prop shader compiles with the ornament's and the texture's hooks in it (the opaque, the glass and the lens).
## - A body that draws compiles into a variant with every uniform its shader has, and the renderer finds nothing wrong with it.
## - A body that does not compile is told back at its own line (control: the same body called right compiles).
## - Its swatch is built and photographed as any prop is: the picture is no flat field.
## - A pitted dark stone turned in its 3D view to show its underside, where steep pit walls face away from the eye, shows no white glint
##   (its bumped normals kept facing the eye); the control: a polished chrome ball still shows its highlight, so the count sees one.
## - A texture's body likewise: it compiles into a variant, with an ornament's beside it; one that does not is told at its own line
##   (control: called right, it compiles); its swatch is photographed, no flat field.

const GOOD := "vec2 q = rot(p, 0.3);\nfloat d = sd_spiral(q, 0.09, 2.5);\nfloat h = stroke(d, 0.035);\nreturn vec2(h, h);"
const BROKEN := "float d = sd_spiral(p, 0.09);\nreturn vec2(d, d);"
const MENDED := "float d = sd_spiral(p, 0.09, 2.0);\nreturn vec2(d, d);"
const TEX := "vec3 to;\nvec3 c = near_cell(p, to);\nfloat h = c.x * c.x * 1.3;\nreturn vec3(h, (0.5 - h) * 0.3, step(0.8, c.z));"
const TEX_BROKEN := "vec3 c = cellsid(p, 2.0);\nreturn vec3(c.x);"
const TEX_MENDED := "vec3 c = cellsid(p * 2.0);\nreturn vec3(c.x);"
const DIR := "user://ornament_compile_check"

var _fails := 0


func _initialize() -> void:
	_run.call_deferred()


## One prop, as a section hands it to the 3D view.
class Fixed extends PropSection:
	var thing: Dictionary
	var mats: Dictionary

	func prop_of(_key: String) -> Dictionary:
		return {"name": "it", "thing": thing, "materials": mats, "hash": ThingLibrary.hash_of(thing, mats)}

	func model_of(_key: String) -> Dictionary:
		return await PropStudio.model(thing, mats, ThingLibrary.hash_of(thing, mats))


## How many pixels near white [param thing] shows in its 3D view ([PropViewer]: as a person sees it, multisampled) turned by [param turn].
func _white_in_view(thing: Dictionary, mats: Dictionary, turn: Vector2) -> int:
	var sec := Fixed.new()
	sec.thing = thing
	sec.mats = mats
	var viewer := PropViewer.new()
	get_root().add_child(viewer)
	viewer.open(sec, "it", "it")
	for i in 90:
		await process_frame
	viewer.set_straight()
	viewer.turn_by(turn)
	for i in 20:
		await process_frame
	var img: Image = viewer._vp.get_texture().get_image()
	var n := 0
	if img != null:
		for y in img.get_height():
			for x in img.get_width():
				if img.get_pixel(x, y).get_luminance() > 0.9:
					n += 1
	viewer.queue_free()
	return n


## How far apart the darkest and the brightest of [param img] are, sampled every eighth pixel.
func _spread(img: Image) -> float:
	var lo := 1.0
	var hi := 0.0
	for y in range(0, img.get_height(), 8):
		for x in range(0, img.get_width(), 8):
			var v := img.get_pixel(x, y).get_luminance()
			lo = minf(lo, v)
			hi = maxf(hi, v)
	return hi - lo


func _ok(cond: bool, what: String) -> void:
	if not cond:
		_fails += 1
		print("  FAIL: " + what)


func _run() -> void:
	for p in ["res://shaders/prop.gdshader", "res://shaders/prop_glass.gdshader", "res://shaders/prop_lens.gdshader"]:
		var sh := Shader.new()
		sh.code = (load(p) as Shader).code
		_ok(sh.get_shader_uniform_list().size() > 0, "%s compiles with the ornament's hook" % p)
	var base: Shader = load("res://shaders/prop.gdshader")
	var plain := Shader.new()
	plain.code = base.code
	var variant := Ornaments.shader_for(base, GOOD)
	_ok(variant != base and variant.get_shader_uniform_list().size() == plain.get_shader_uniform_list().size(),
		"a body that draws compiles into a variant with every uniform (%d of %d)" % [variant.get_shader_uniform_list().size(), plain.get_shader_uniform_list().size()])
	_ok(Ornaments.compile_errors(GOOD).is_empty(), "the renderer finds nothing wrong with it: %s" % Ornaments.compile_errors(GOOD))
	var why := Ornaments.compile_errors(BROKEN)
	_ok(why.contains("line 1 of your code") and why.contains("sd_spiral"), "a body that does not compile is told at its own line: %s" % why)
	_ok(Ornaments.compile_errors(MENDED).is_empty(), "the control: the same body called right compiles")
	var sw := OrnamentLibrary.swatch(GOOD)
	var paths: Array = await PropStudio.views(sw["thing"], sw["materials"], GOOD.sha256_text().left(16), ProjectSettings.globalize_path(DIR))
	var img: Image = Image.load_from_file(String(paths[0])) if not paths.is_empty() else null
	var spread := 0.0
	if img != null:
		var lo := 1.0
		var hi := 0.0
		for y in range(0, img.get_height(), 8):
			for x in range(0, img.get_width(), 8):
				var v := img.get_pixel(x, y).get_luminance()
				lo = minf(lo, v)
				hi = maxf(hi, v)
		spread = hi - lo
	_ok(img != null and spread > 0.2, "its swatch is photographed, no flat field (spread %.2f)" % spread)
	for p in paths:
		DirAccess.remove_absolute(String(p))
	var tv := Ornaments.shader_for(base, GOOD, TEX)
	_ok(tv != base and tv.get_shader_uniform_list().size() == plain.get_shader_uniform_list().size(),
		"a texture's body compiles into a variant, an ornament's beside it (%d of %d)" % [tv.get_shader_uniform_list().size(), plain.get_shader_uniform_list().size()])
	_ok(Ornaments.compile_errors(TEX, Ornaments.TEXTURE).is_empty(), "the renderer finds nothing wrong with the texture: %s" % Ornaments.compile_errors(TEX, Ornaments.TEXTURE))
	var twhy := Ornaments.compile_errors(TEX_BROKEN, Ornaments.TEXTURE)
	_ok(twhy.contains("line 1 of your code") and twhy.contains("cellsid"), "a texture that does not compile is told at its own line: %s" % twhy)
	_ok(Ornaments.compile_errors(TEX_MENDED, Ornaments.TEXTURE).is_empty(), "the control: the texture called right compiles")
	var tsw := OrnamentLibrary.swatch(TEX, OrnamentLibrary.TEXTURE)
	var tpaths: Array = await PropStudio.views(tsw["thing"], tsw["materials"], TEX.sha256_text().left(16), ProjectSettings.globalize_path(DIR))
	var timg: Image = Image.load_from_file(String(tpaths[0])) if not tpaths.is_empty() else null
	_ok(timg != null and _spread(timg) > 0.2, "the texture's swatch is photographed, no flat field (spread %.2f)" % (_spread(timg) if timg != null else 0.0))
	for p in tpaths:
		DirAccess.remove_absolute(String(p))
	var coal := {"name": "coal", "parts": [{"shape": "ball", "size": [6, 4, 5], "lumpy": 0.8, "facets": true, "material": "coal"}]}
	var coal_mats := {"coal": {"kind": "stone", "color": "#161616", "color2": "#2e2e30", "polish": 0.0, "texture": "pitted", "bumps": 1.0, "texture_size": 0.22}}
	var glints := await _white_in_view(coal, coal_mats, Vector2(0, -180))
	var chrome := {"name": "ball", "parts": [{"shape": "ball", "size": [5, 5, 5], "material": "chrome"}]}
	var shine := await _white_in_view(chrome, {"chrome": {"kind": "metal", "color": "#e8e8ec", "polish": 1.0, "wear": 0.0}}, Vector2.ZERO)
	_ok(glints == 0 and shine > 0, "a pitted stone's underside in its 3D view shows no white glint (%d), a chrome ball its highlight (%d)" % [glints, shine])
	DirAccess.remove_absolute(ProjectSettings.globalize_path(DIR))
	print("ornament_compile_check: %s (%d failure%s)" % ["ALL OK" if _fails == 0 else "FAILED", _fails, "" if _fails == 1 else "s"])
	quit(1 if _fails > 0 else 0)
